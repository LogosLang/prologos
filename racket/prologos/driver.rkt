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
         "zonk.rkt")

(provide process-command
         process-file
         process-string
         load-module
         install-module-loader!)

;; ========================================
;; Apply structural reduce marks from type checker
;; ========================================
;; Walk the expression tree and reconstruct any expr-reduce nodes
;; that were marked as needing structural PM (by check-reduce) with
;; structural? = #t.
(define (apply-structural-marks e)
  (match e
    [(expr-reduce scrut arms structural?)
     (define new-structural? (or structural? (structural-reduce? e)))
     (define new-scrut (apply-structural-marks scrut))
     (define new-arms
       (map (lambda (arm)
              (expr-reduce-arm
               (expr-reduce-arm-ctor-name arm)
               (expr-reduce-arm-binding-count arm)
               (apply-structural-marks (expr-reduce-arm-body arm))))
            arms))
     (expr-reduce new-scrut new-arms new-structural?)]
    [(expr-lam m t body)
     (expr-lam m (apply-structural-marks t) (apply-structural-marks body))]
    [(expr-Pi m dom cod)
     (expr-Pi m (apply-structural-marks dom) (apply-structural-marks cod))]
    [(expr-app f a)
     (expr-app (apply-structural-marks f) (apply-structural-marks a))]
    [(expr-ann e1 t1)
     (expr-ann (apply-structural-marks e1) (apply-structural-marks t1))]
    [(expr-suc e1) (expr-suc (apply-structural-marks e1))]
    [(expr-natrec mot base step target)
     (expr-natrec (apply-structural-marks mot) (apply-structural-marks base)
                  (apply-structural-marks step) (apply-structural-marks target))]
    [(expr-boolrec mot tc fc target)
     (expr-boolrec (apply-structural-marks mot) (apply-structural-marks tc)
                   (apply-structural-marks fc) (apply-structural-marks target))]
    [(expr-Sigma t1 t2)
     (expr-Sigma (apply-structural-marks t1) (apply-structural-marks t2))]
    [(expr-pair e1 e2)
     (expr-pair (apply-structural-marks e1) (apply-structural-marks e2))]
    [(expr-fst e1) (expr-fst (apply-structural-marks e1))]
    [(expr-snd e1) (expr-snd (apply-structural-marks e1))]
    [(expr-Eq t e1 e2)
     (expr-Eq (apply-structural-marks t) (apply-structural-marks e1)
              (apply-structural-marks e2))]
    [(expr-J mot base left right proof)
     (expr-J (apply-structural-marks mot) (apply-structural-marks base)
             (apply-structural-marks left) (apply-structural-marks right)
             (apply-structural-marks proof))]
    [_ e]))  ;; atoms, fvar, bvar, zero, etc.

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
      (if (surf-def? expanded)
          ;; Special handling for def: split elaboration for recursive support.
          ;; We elaborate the type first, pre-register it in the global env,
          ;; then elaborate the body (so self-references resolve).
          (process-def expanded)
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
                         (let ([val (nf (zonk-final (apply-structural-marks expr)))]
                               [ty-nf (nf (zonk-final ty))])
                           (format "~a : ~a" (pp-expr val) (pp-expr ty-nf)))))]

                  ;; (infer expr)
                  [(list 'infer expr)
                   (let ([ty (infer/err ctx-empty expr)])
                     (if (prologos-error? ty) ty
                         (pp-expr (zonk-final ty))))]

                  [_ (prologos-error srcloc-unknown (format "Unknown command: ~a" elab-result))]))))))

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
  ;; 1. Elaborate type
  (define type (elaborate type-surf))
  (cond
    [(prologos-error? type) type]
    [else
     ;; 2. Check type is well-formed
     (define ty-ok (is-type/err ctx-empty type))
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
        ;; 4. Elaborate body (self-reference now resolves)
        (define body (elaborate body-surf))
        (cond
          [(prologos-error? body)
           ;; Remove pre-registered entry on elaboration failure
           (current-global-env (hash-remove (current-global-env) name))
           body]
          [else
           ;; 5. Check body against type
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
                 (define marked-body (apply-structural-marks body))
                 (define zonked-body (zonk-final marked-body))
                 (define zonked-type (zonk-final type))
                 (define final-body zonked-body)
                 (current-global-env
                  (global-env-add (current-global-env) name zonked-type final-body))
                 (when (current-ns-context)
                   (define fqn (qualify-name name
                                 (ns-context-current-ns (current-ns-context))))
                   (current-global-env
                    (global-env-add (current-global-env) fqn zonked-type final-body)))
                 (format "~a : ~a defined." name (pp-expr zonked-type))])])])])]))

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
  ;; Read raw syntax, apply pre-parse expansion, then parse
  (define raw-stxs (read-all-syntax port path))
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
  (when cached (begin cached))
  (when cached cached)

  ;; Actually return early if cached
  (cond
    [cached cached]
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
       (set! mod-type-meta (current-type-meta)))

     ;; Propagate preparse registry changes (deftype/defmacro) to the caller.
     ;; This ensures type aliases and macros defined in loaded modules are
     ;; available to subsequent code in the requiring module.
     (current-preparse-registry mod-preparse-reg)

     ;; Propagate constructor metadata (for reduce) to the caller.
     (current-ctor-registry mod-ctor-reg)
     (current-type-meta mod-type-meta)

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
(define (install-module-loader!)
  (current-module-loader load-module))

;; Auto-install on module load
(install-module-loader!)
