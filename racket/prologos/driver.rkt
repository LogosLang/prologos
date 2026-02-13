#lang racket/base

;;;
;;; PROLOGOS DRIVER
;;; Processes top-level commands (def, check, eval, infer).
;;; Manages the global definition environment.
;;; Provides module loading for the namespace system.
;;;

(require racket/match
         racket/port
         racket/set
         racket/path
         racket/list
         racket/string
         "prelude.rkt"
         "syntax.rkt"
         "reduction.rkt"
         "typing-core.rkt"
         "source-location.rkt"
         "surface-syntax.rkt"
         "errors.rkt"
         "parser.rkt"
         "elaborator.rkt"
         "pretty-print.rkt"
         "typing-errors.rkt"
         "global-env.rkt"
         "macros.rkt"
         "sexp-readtable.rkt"
         "reader.rkt"
         "namespace.rkt"
         "metavar-store.rkt"
         "zonk.rkt"
         "multi-dispatch.rkt")

(provide process-command
         process-file
         process-string
         load-module
         install-module-loader!
         prologos-lib-dir)

;; ========================================
;; Standard library path (computed from this module's location)
;; ========================================
;; driver.rkt lives at prologos/driver.rkt, lib/ is at prologos/lib/
(define prologos-lib-dir
  (let ([mod-path (variable-reference->module-path-index (#%variable-reference))])
    (define resolved (resolved-module-path-name (module-path-index-resolve mod-path)))
    (simplify-path (build-path (path-only resolved) "lib"))))

;; ========================================
;; Sprint 9: Recover a name map from the meta store for error formatting.
;; ========================================
;; Searches the meta store for the first meta with a meta-source-info
;; containing a name-map, and returns it. Falls back to '() if none found.
(define (recover-name-map)
  (for/fold ([result '()])
            ([(id info) (in-hash (current-meta-store))])
    (if (null? result)
        (let ([src (meta-info-source info)])
          (if (and (meta-source-info? src) (meta-source-info-name-map src))
              (meta-source-info-name-map src)
              result))
        result)))

;; ========================================
;; Sprint 10: Check if an elaborated type contains expr-hole
;; Used to detect types with holes from bare-param defn.
;; When a type has holes, is-type will fail, but check will still work.
;; ========================================
(define (type-contains-hole? e)
  (match e
    [(expr-hole) #t]
    [(expr-Pi _ a b) (or (type-contains-hole? a) (type-contains-hole? b))]
    [(expr-Sigma a b) (or (type-contains-hole? a) (type-contains-hole? b))]
    [(expr-app f x) (or (type-contains-hole? f) (type-contains-hole? x))]
    [(expr-lam _ a b) (or (type-contains-hole? a) (type-contains-hole? b))]
    [_ #f]))

;; Check if an elaborated type contains unsolved metas (level-meta, mult-meta, or expr-meta).
;; When a type has unsolved metas (from implicit parameter inference), is-type may fail
;; because infer-level can't handle universe level mismatches caused by Church encoding
;; (e.g., Option (List A) where List A : Type 1 but Option expects Type 0).
;; These types will be properly checked during the body type-check phase.
(define (type-contains-meta? e)
  (match e
    [(expr-meta _) #t]
    [(expr-Type l) (level-meta? l)]
    [(expr-Pi m a b) (or (mult-meta? m) (type-contains-meta? a) (type-contains-meta? b))]
    [(expr-Sigma a b) (or (type-contains-meta? a) (type-contains-meta? b))]
    [(expr-app f x) (or (type-contains-meta? f) (type-contains-meta? x))]
    [(expr-lam m a b) (or (mult-meta? m) (type-contains-meta? a) (type-contains-meta? b))]
    [_ #f]))

;; Sprint 10: For bare-param defn, the type has holes. We skip is-type and
;; just run check(body, type) — the holes act as wildcards, accepting any type.
;; The stored type retains holes which display as `_`.

;; ========================================
;; Process a single top-level command
;; ========================================
;; Returns a result string, or a prologos-error.
;; Side effect: may update current-global-env for 'def'.
;;
;; When a namespace context is active, def stores names both as
;; bare symbols (for local use) and as fully-qualified names (for export).
(define (process-command surf)
  (reset-meta-store!)  ;; clear metavariables from previous command
  (define expanded (expand-top-level surf))
  (if (prologos-error? expanded)
      expanded
      (cond
        [(surf-def? expanded)
         ;; Special handling for def: split elaboration for recursive support.
         ;; We elaborate the type first, pre-register it in the global env,
         ;; then elaborate the body (so self-references resolve).
         (process-def expanded)]
        [(surf-def-group? expanded)
         ;; Multi-body defn: process each clause def, register dispatch table
         (process-def-group expanded)]
        [else
         ;; All other forms: elaborate fully, then process
          (let ([elab-result (elaborate-top-level expanded)])
            (if (prologos-error? elab-result)
                elab-result
                (match elab-result
                  ;; (check expr type)
                  [(list 'check expr type)
                   (let ([chk (check/err ctx-empty expr type)])
                     (if (prologos-error? chk) chk
                         "OK"))]

                  ;; (eval expr)
                  [(list 'eval expr)
                   (let ([ty (infer/err ctx-empty expr)])
                     (if (prologos-error? ty) ty
                         (let ([val (nf (zonk-final expr))]
                               [ty-nf (nf (zonk-final ty))])
                           (format "~a : ~a" (pp-expr val) (pp-expr ty-nf)))))]

                  ;; (infer expr)
                  [(list 'infer expr)
                   (let ([ty (infer/err ctx-empty expr)])
                     (if (prologos-error? ty) ty
                         (pp-expr (zonk-final ty))))]

                  [_ (prologos-error srcloc-unknown (format "Unknown command: ~a" elab-result))])))])))

;; Process a def command with split elaboration for recursive support.
;; 1. Elaborate type first
;; 2. Pre-register (cons type #f) in global env
;; 3. Elaborate body (self-reference now resolves to fvar)
;; 4. Type-check body against type
;; 5. Update global env with real value
(define (process-def expanded)
  (define name (surf-def-name expanded))
  (define type-surf (surf-def-type expanded))
  (define body-surf (surf-def-body expanded))
  (cond
    ;; Sprint 10: Type-inferred def (no type annotation)
    [(not type-surf)
     (define body (elaborate body-surf))
     (cond
       [(prologos-error? body) body]
       [else
        (define inferred-type (infer/err ctx-empty body))
        (cond
          [(prologos-error? inferred-type) inferred-type]
          [else
           (define ty-ok (is-type/err ctx-empty inferred-type))
           (cond
             [(prologos-error? ty-ok) ty-ok]
             [else
              ;; Check for failed constraints (Sprint 5)
              (define failed (all-failed-constraints))
              (cond
                [(not (null? failed))
                 ;; Sprint 9: structured constraint failure with provenance
                 (define c (car failed))
                 (define prov (constraint-source c))
                 (define names (recover-name-map))
                 (define error-loc
                   (cond
                     [(and (constraint-provenance? prov)
                           (meta-source-info? (constraint-provenance-meta-source prov)))
                      (meta-source-info-loc (constraint-provenance-meta-source prov))]
                     [(constraint-provenance? prov) (constraint-provenance-loc prov)]
                     [else srcloc-unknown]))
                 (define lhs-str (pp-expr (zonk-final (constraint-lhs c)) names))
                 (define rhs-str (pp-expr (zonk-final (constraint-rhs c)) names))
                 (conflicting-constraints-error
                   error-loc
                   (format "Type error in ~a: cannot satisfy constraint" name)
                   lhs-str rhs-str
                   error-loc error-loc)]
                [else
                 (define zonked-body (zonk-final body))
                 (define zonked-type (zonk-final inferred-type))
                 (current-global-env
                  (global-env-add (current-global-env) name zonked-type zonked-body))
                 (when (current-ns-context)
                   (define fqn (qualify-name name
                                 (ns-context-current-ns (current-ns-context))))
                   (current-global-env
                    (global-env-add (current-global-env) fqn zonked-type zonked-body)))
                 (format "~a : ~a defined." name (pp-expr zonked-type))])])])])]
    ;; Existing annotated path (type annotation present)
    [else
     ;; 1. Elaborate type
     (define type (elaborate type-surf))
     (cond
       [(prologos-error? type) type]
       [else
        ;; 2. Check type is well-formed
        ;; Sprint 10: Skip is-type for types with holes (bare-param defn).
        ;; Holes act as wildcards in check and are retained in the stored type.
        ;; Also skip for types with unsolved metas (implicit param inference).
        (define ty-ok (if (or (type-contains-hole? type)
                              (type-contains-meta? type))
                          #t
                          (is-type/err ctx-empty type)))
        (cond
          [(prologos-error? ty-ok) ty-ok]
          [else
           ;; 3. Pre-register for recursive references
           (current-global-env
            (global-env-add-type-only (current-global-env) name type))
           (when (current-ns-context)
             (define fqn (qualify-name name
                           (ns-context-current-ns (current-ns-context))))
             (current-global-env
              (global-env-add-type-only (current-global-env) fqn type)))
           ;; Check if this is a data type or constructor definition.
           ;; Both are opaque with native constructors — the Church-encoded bodies
           ;; can't be type-checked against the new Type 0 annotation.
           (define-values (_pfx short-name-for-check) (split-qualified-name name))
           (define data-type-def?
             (or (lookup-type-ctors name)
                 (and short-name-for-check (lookup-type-ctors short-name-for-check))
                 (lookup-ctor name)
                 (and short-name-for-check (lookup-ctor short-name-for-check))))
           ;; For data type definitions, skip body elaboration/checking entirely.
           ;; The type is opaque (stored with value = #f), so the Church-encoded
           ;; body is never used at runtime. The type annotation is all we need.
           (cond
             [data-type-def?
              (let ([zonked-type (zonk-final type)])
                (current-global-env
                 (global-env-add-type-only (current-global-env) name zonked-type))
                (when (current-ns-context)
                  (define fqn (qualify-name name
                                (ns-context-current-ns (current-ns-context))))
                  (current-global-env
                   (global-env-add-type-only (current-global-env) fqn zonked-type)))
                (format "~a : ~a defined." name (pp-expr zonked-type)))]
             [else
              ;; 4. Elaborate body (self-reference now resolves)
              (define body (elaborate body-surf))
              (cond
                [(prologos-error? body)
                 ;; Remove pre-registered entry on elaboration failure
                 (current-global-env (hash-remove (current-global-env) name))
                 body]
                [else
                 ;; 5. Check body against type (use type which has metas instead of holes)
                 ;; Sprint 9: pass recovered name map for de Bruijn recovery in errors
                 (define chk (check/err ctx-empty body type srcloc-unknown (recover-name-map)))
                 (cond
                   [(prologos-error? chk)
                    ;; Remove pre-registered entry on type-check failure
                    (current-global-env (hash-remove (current-global-env) name))
                    chk]
                   [else
                    ;; 5.5. Check for failed constraints (Sprint 5)
                    (define failed (all-failed-constraints))
                    (cond
                      [(not (null? failed))
                       ;; Remove pre-registered entry on constraint failure
                       (current-global-env (hash-remove (current-global-env) name))
                       ;; Sprint 9: structured constraint failure with provenance
                       (define c (car failed))
                       (define prov (constraint-source c))
                       (define names (recover-name-map))
                       (define error-loc
                         (cond
                           [(and (constraint-provenance? prov)
                                 (meta-source-info? (constraint-provenance-meta-source prov)))
                            (meta-source-info-loc (constraint-provenance-meta-source prov))]
                           [(constraint-provenance? prov) (constraint-provenance-loc prov)]
                           [else srcloc-unknown]))
                       (define lhs-str (pp-expr (zonk-final (constraint-lhs c)) names))
                       (define rhs-str (pp-expr (zonk-final (constraint-rhs c)) names))
                       (conflicting-constraints-error
                         error-loc
                         (format "Type error in ~a: cannot satisfy constraint" name)
                         lhs-str rhs-str
                         error-loc error-loc)]
                      [else
                       ;; 6. Apply structural reduce marks (before zonk, so eq? identity holds),
                       ;;    then zonk-final (defaults unsolved level-metas to lzero)
                       (define zonked-body (zonk-final body))
                       (define zonked-type (zonk-final type))
                       (current-global-env
                        (global-env-add (current-global-env) name zonked-type zonked-body))
                       (when (current-ns-context)
                         (define fqn (qualify-name name
                                       (ns-context-current-ns (current-ns-context))))
                         (current-global-env
                          (global-env-add (current-global-env) fqn zonked-type zonked-body)))
                       (format "~a : ~a defined." name (pp-expr zonked-type))])])])])])])]))

;; ========================================
;; Process a multi-body defn group
;; ========================================
;; Each clause is a surf-def with an internal name (name/N).
;; 1. Pre-register all clause types (for cross-clause recursion)
;; 2. Process each clause's body
;; 3. Register dispatch table in multi-defn registry
(define (process-def-group group)
  (define name (surf-def-group-name group))
  (define defs (surf-def-group-defs group))
  (define arities (surf-def-group-arities group))
  (define docstring (surf-def-group-docstring group))
  ;; Build arity-map from arities
  (define arity-map
    (for/fold ([m (hasheq)])
              ([arity (in-list arities)])
      (hash-set m arity (string->symbol (format "~a/~a" name arity)))))
  ;; Register the dispatch table
  (register-multi-defn! name arities arity-map docstring)
  ;; Also register with namespace qualification if applicable
  (when (current-ns-context)
    (define fqn (qualify-name name (ns-context-current-ns (current-ns-context))))
    (define fqn-arity-map
      (for/fold ([m (hasheq)])
                ([arity (in-list arities)])
        (hash-set m arity (qualify-name
                           (string->symbol (format "~a/~a" name arity))
                           (ns-context-current-ns (current-ns-context))))))
    (register-multi-defn! fqn arities fqn-arity-map docstring))
  ;; Process each clause def through process-def (handles type checking, registration)
  (define results
    (for/list ([def (in-list defs)])
      (reset-meta-store!)
      (process-def def)))
  ;; Check for errors
  (define first-err (findf prologos-error? results))
  (if first-err first-err
      (format "~a defined (arities: ~a)."
              name (string-join (map number->string (sort arities <)) ", "))))

;; ========================================
;; Read all syntax objects from a port
;; ========================================
(define (read-all-syntax port [source "<port>"])
  (port-count-lines! port)
  (let loop ([acc '()])
    (define stx (prologos-sexp-read-syntax source port))
    (if (eof-object? stx)
        (reverse acc)
        (loop (cons stx acc)))))

;; Read all syntax objects using the whitespace-significant reader
(define (read-all-syntax-ws port [source "<port>"])
  (port-count-lines! port)
  (prologos-read-syntax-all source port))

;; ========================================
;; Process all commands from a string
;; ========================================
(define (process-string s)
  (define port (open-input-string s))
  ;; Read raw syntax, apply pre-parse expansion, then parse
  (define raw-stxs (read-all-syntax port "<string>"))
  (define expanded-stxs (preparse-expand-all raw-stxs))
  (define surfs (map parse-datum expanded-stxs))
  (for/list ([surf (in-list surfs)])
    (if (prologos-error? surf)
        surf
        (process-command surf))))

;; ========================================
;; Process all commands from a file
;; ========================================
(define (process-file path)
  (define port (open-input-file path))
  ;; Use WS reader for .prologos files, sexp reader otherwise
  (define path-str (if (string? path) path (path->string path)))
  (define raw-stxs
    (if (regexp-match? #rx"\\.prologos$" path-str)
        (read-all-syntax-ws port path-str)
        (read-all-syntax port path-str)))
  (close-input-port port)
  (define expanded-stxs (preparse-expand-all raw-stxs))
  (define surfs (map parse-datum expanded-stxs))
  (for/list ([surf (in-list surfs)])
    (if (prologos-error? surf)
        surf
        (process-command surf))))

;; ========================================
;; Module Loading
;; ========================================

;; Load a module from a namespace symbol.
;; Returns a module-info, or raises an error.
;;
;; Steps:
;;   1. Check module registry cache
;;   2. Check for circular dependencies
;;   3. Resolve namespace to file path
;;   4. Process the file in a fresh environment
;;   5. Build module-info from resulting definitions
;;   6. Register in module registry
(define (load-module ns-sym base-dir)
  ;; 1. Check cache
  (define cached (lookup-module ns-sym))

  ;; Return early if cached — but still import env into caller
  (cond
    [cached
     ;; Import ALL of the cached module's definitions into the caller's global env.
     ;; Without this, modules loaded in nested parameterize scopes (which start
     ;; with fresh empty envs) can't see definitions from previously-cached modules.
     (for ([(k v) (in-hash (module-info-env-snapshot cached))])
       (current-global-env
        (hash-set (current-global-env) k v)))
     cached]
    [else
     ;; 2. Check for circular dependencies
     (when (set-member? (current-loading-set) ns-sym)
       (error 'require "Circular dependency detected: ~a" ns-sym))

     ;; 3. Resolve to file path
     (define file-path
       (resolve-ns-path ns-sym base-dir))
     (unless file-path
       (error 'require "Cannot find module: ~a (searched lib paths: ~a)"
              ns-sym (current-lib-paths)))

     ;; 4. Process the file in a fresh environment
     (define mod-env #f)
     (define mod-ns-ctx #f)
     (define mod-preparse-reg #f)
     (define mod-ctor-reg #f)
     (define mod-type-meta #f)
     (define mod-multi-defn-reg #f)

     (parameterize ([current-global-env (hasheq)]
                    [current-ns-context #f]
                    [current-meta-store (make-hasheq)]
                    [current-level-meta-store (make-hasheq)]
                    [current-mult-meta-store (make-hasheq)]
                    [current-constraint-store '()]
                    [current-wakeup-registry (make-hasheq)]
                    [current-preparse-registry (current-preparse-registry)]
                    [current-ctor-registry (current-ctor-registry)]
                    [current-type-meta (current-type-meta)]
                    [current-multi-defn-registry (current-multi-defn-registry)]
                    [current-loading-set (set-add (current-loading-set) ns-sym)])
       ;; Read and process the file
       ;; Use WS reader for .prologos files, sexp reader otherwise
       (define port (open-input-file file-path))
       (define file-str (path->string file-path))
       (define raw-stxs
         (if (regexp-match? #rx"\\.prologos$" file-str)
             (read-all-syntax-ws port file-str)
             (read-all-syntax port file-str)))
       (close-input-port port)
       (define expanded-stxs (preparse-expand-all raw-stxs))
       (define surfs (map parse-datum expanded-stxs))
       (for ([surf (in-list surfs)])
         (unless (prologos-error? surf)
           (define result (process-command surf))
           (when (prologos-error? result)
             (error 'require "Error loading module ~a: ~a"
                    ns-sym (prologos-error-message result)))))

       ;; Capture the resulting environment, namespace context, and registries
       (set! mod-env (current-global-env))
       (set! mod-ns-ctx (current-ns-context))
       (set! mod-preparse-reg (current-preparse-registry))
       (set! mod-ctor-reg (current-ctor-registry))
       (set! mod-type-meta (current-type-meta))
       (set! mod-multi-defn-reg (current-multi-defn-registry)))

     ;; Propagate preparse registry changes (deftype/defmacro) to the caller.
     ;; This ensures type aliases and macros defined in loaded modules are
     ;; available to subsequent code in the requiring module.
     (current-preparse-registry mod-preparse-reg)

     ;; Propagate constructor metadata (for reduce) to the caller.
     (current-ctor-registry mod-ctor-reg)
     (current-type-meta mod-type-meta)

     ;; Propagate multi-defn dispatch tables to the caller.
     (current-multi-defn-registry mod-multi-defn-reg)

     ;; 5. Build module-info
     (define exports
       (if (and mod-ns-ctx (ns-context-exports mod-ns-ctx))
           (let ([exp (ns-context-exports mod-ns-ctx)])
             (cond
               ;; :all — export everything defined in the namespace
               [(and (pair? exp) (eq? (car exp) ':all))
                (for/list ([(k _) (in-hash mod-env)]
                           #:when (let-values ([(prefix name) (split-qualified-name k)])
                                    (and prefix (eq? prefix ns-sym))))
                  (let-values ([(_ name) (split-qualified-name k)])
                    name))]
               [else exp]))
           ;; No provide — export nothing (or we could default to all?)
           '()))

     (define mi (module-info ns-sym
                             exports
                             mod-env
                             file-path
                             (hasheq)
                             (hasheq)))

     ;; 6. Register
     (register-module! ns-sym mi)

     ;; 7. Import ALL of module's definitions into the CALLER's global env.
     ;; This includes transitive dependencies (from modules the loaded module
     ;; itself required), which are needed for reduction/evaluation — function
     ;; bodies may reference cross-module globals that must be unfoldable.
     (for ([(k v) (in-hash mod-env)])
       (current-global-env
        (hash-set (current-global-env) k v)))

     mi]))

;; ========================================
;; Install the module loader callback
;; ========================================
;; Call this at startup to wire up the namespace system.
;; Also sets the standard library path if not already configured.
(define (install-module-loader!)
  (current-module-loader load-module)
  (when (null? (current-lib-paths))
    (current-lib-paths (list prologos-lib-dir))))

;; Auto-install on module load
(install-module-loader!)
