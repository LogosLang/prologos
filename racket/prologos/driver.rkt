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
         "qtt.rkt"
         "multi-dispatch.rkt"
         "foreign.rkt"
         "trait-resolution.rkt"
         "warnings.rkt"
         "relations.rkt"
         "stratified-eval.rkt"
         "performance-counters.rkt"
         "elab-speculation-bridge.rkt"
         "elaborator-network.rkt"
         "type-lattice.rkt"
         "propagator.rkt"
         "champ.rkt"
         "unify.rkt"
         "atms.rkt"
         "capability-inference.rkt"
         "cap-type-bridge.rkt")

(provide process-command
         process-file
         process-string
         load-module
         install-module-loader!
         prologos-lib-dir
         rewrite-specializations
         ;; Phase 6: Foreign capability gating helpers (for testing)
         extract-foreign-caps
         extract-caps-from-brace-params)

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
;; Hash removal: Always reads from CHAMP.
(define (recover-name-map)
  (define mi-box (current-prop-meta-info-box))
  (champ-fold (unbox mi-box)
              (lambda (k v acc)
                (if (null? acc)
                    (let ([src (meta-info-source v)])
                      (if (and (meta-source-info? src) (meta-source-info-name-map src))
                          (meta-source-info-name-map src)
                          acc))
                    acc))
              '()))

;; ========================================
;; Sprint 10: Check if an elaborated type contains expr-hole
;; Used to detect types with holes from bare-param defn.
;; When a type has holes, is-type will fail, but check will still work.
;; ========================================
(define (type-contains-hole? e)
  (match e
    [(expr-hole) #t]
    [(expr-typed-hole _) #t]
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

;; Check if an expression contains node types that the QTT module
;; doesn't handle yet: expr-reduce (structural PM), Vec, Fin constructors/eliminators.
;; Other expression types (boolrec, Posit8, fvar, Pi/Sigma/Eq)
;; are now handled by qtt.rkt directly.
(define (contains-unsupported-qtt? e)
  (match e
    [(expr-reduce _ _ _) #t]
    [(expr-vnil _) #t]
    [(expr-vcons _ _ _ _) #t]
    [(expr-vhead _ _ _) #t]
    [(expr-vtail _ _ _) #t]
    [(expr-vindex _ _ _ _) #t]
    [(expr-fzero _) #t]
    [(expr-fsuc _ _) #t]
    [(expr-foreign-fn _ _ _ _ _ _) #t]
    [(expr-app f x) (or (contains-unsupported-qtt? f) (contains-unsupported-qtt? x))]
    [(expr-lam _ a b) (or (contains-unsupported-qtt? a) (contains-unsupported-qtt? b))]
    [(expr-Pi _ a b) (or (contains-unsupported-qtt? a) (contains-unsupported-qtt? b))]
    [(expr-Sigma a b) (or (contains-unsupported-qtt? a) (contains-unsupported-qtt? b))]
    [(expr-pair a b) (or (contains-unsupported-qtt? a) (contains-unsupported-qtt? b))]
    [(expr-fst e) (contains-unsupported-qtt? e)]
    [(expr-snd e) (contains-unsupported-qtt? e)]
    [(expr-ann e t) (or (contains-unsupported-qtt? e) (contains-unsupported-qtt? t))]
    [(expr-suc e) (contains-unsupported-qtt? e)]
    [(expr-natrec m b s t) (or (contains-unsupported-qtt? m) (contains-unsupported-qtt? b)
                               (contains-unsupported-qtt? s) (contains-unsupported-qtt? t))]
    [(expr-boolrec m tc fc t) (or (contains-unsupported-qtt? m) (contains-unsupported-qtt? tc)
                                  (contains-unsupported-qtt? fc) (contains-unsupported-qtt? t))]
    [(expr-J m b l r p) (or (contains-unsupported-qtt? m) (contains-unsupported-qtt? b)
                            (contains-unsupported-qtt? l) (contains-unsupported-qtt? r)
                            (contains-unsupported-qtt? p))]
    [_ #f]))

;; Sprint 10: For bare-param defn, the type has holes. We skip is-type and
;; just run check(body, type) — the holes act as wildcards, accepting any type.
;; The stored type retains holes which display as `_`.

;; ========================================
;; Call-site specialization rewriting (HKT-8)
;; ========================================
;; After zonk-final, rewrite calls to generic functions with registered
;; specializations. E.g., (new-lattice-cell Bool dict net) → (new-lattice-cell--Bool--specialized net)
;; Strips implicit type args and dict params, replacing with direct specialized call.

;; Extract a type-constructor key from a ground type expression.
;; Returns a symbol suitable for lookup-specialization, or #f if not ground.
(define (extract-type-key expr)
  (match expr
    [(expr-Bool)         'Bool]
    [(expr-Nat)          'Nat]
    [(expr-tycon name)   name]
    [(expr-fvar name)    name]
    ;; For applied type constructors like (List Nat), extract the head
    [(expr-app f _)      (extract-type-key f)]
    ;; Built-in compound types
    [(expr-PVec _)       'PVec]
    [(expr-Set _)        'Set]
    [(expr-Map _ _)      'Map]
    [_                   #f]))

;; Build an application chain: (build-app-chain head '(a1 a2 a3)) → (app (app (app head a1) a2) a3)
(define (build-app-chain head args)
  (foldl (lambda (arg acc) (expr-app acc arg)) head args))

;; Rewrite call sites of generic functions to use registered specializations.
;; Walks the expression tree, looking for application chains headed by an fvar
;; with a spec that has where-constraints + implicit-binders. When the type arg
;; is ground and a specialization is registered, replaces:
;;   (generic-fn TypeArg DictArg ... explicit-args)
;; with:
;;   (specialized-fn explicit-args)
(define (rewrite-specializations e)
  ;; Fast path: if no specializations registered, return unchanged
  (if (hash-empty? (current-specialization-registry))
      e
      (rewrite-spec e)))

(define (rewrite-spec e)
  (match e
    ;; Application: check if this chain matches a specializable call
    [(expr-app _ _)
     (let-values ([(head args) (decompose-app-for-spec e)])
       (cond
         ;; Head is a named function — check for specialization
         [(and head (expr-fvar? head))
          (define fn-name (expr-fvar-name head))
          (define spec (lookup-spec fn-name))
          (cond
            [(and spec (spec-entry? spec)
                  (not (null? (spec-entry-where-constraints spec))))
             ;; This function has where-constraints → candidate for specialization
             (define n-implicit (length (spec-entry-implicit-binders spec)))
             (define n-where (length (spec-entry-where-constraints spec)))
             (define n-to-strip (+ n-implicit n-where))
             (cond
               [(and (>= (length args) n-to-strip)
                     (> n-implicit 0))
                ;; First arg should be the type arg
                (define type-arg (car args))
                (define type-key (extract-type-key type-arg))
                (cond
                  [(and type-key (lookup-specialization fn-name type-key))
                   => (lambda (entry)
                        ;; Found specialization! Strip type+dict args, use specialized name
                        (define explicit-args (drop args n-to-strip))
                        (define specialized-head (expr-fvar (specialization-entry-specialized-name entry)))
                        ;; Recurse into the explicit args
                        (build-app-chain specialized-head
                                        (map rewrite-spec explicit-args)))]
                  [else
                   ;; No specialization found — recurse into all args
                   (build-app-chain (rewrite-spec head)
                                    (map rewrite-spec args))])]
               [else
                ;; Not enough args for stripping — recurse
                (build-app-chain (rewrite-spec head)
                                  (map rewrite-spec args))])]
            [else
             ;; No spec or no where-constraints — recurse
             (build-app-chain (rewrite-spec head)
                              (map rewrite-spec args))])]
         [else
          ;; Non-fvar head (lambda application, etc.) — recurse into subexpressions
          (expr-app (rewrite-spec (expr-app-func e))
                    (rewrite-spec (expr-app-arg e)))]))]
    ;; Structural recursion into all expression types
    [(expr-lam m ty body)
     (expr-lam m (rewrite-spec ty) (rewrite-spec body))]
    [(expr-Pi m a b)
     (expr-Pi m (rewrite-spec a) (rewrite-spec b))]
    [(expr-Sigma a b)
     (expr-Sigma (rewrite-spec a) (rewrite-spec b))]
    [(expr-pair a b)
     (expr-pair (rewrite-spec a) (rewrite-spec b))]
    [(expr-fst x) (expr-fst (rewrite-spec x))]
    [(expr-snd x) (expr-snd (rewrite-spec x))]
    [(expr-ann x t) (expr-ann (rewrite-spec x) (rewrite-spec t))]
    [(expr-suc x) (expr-suc (rewrite-spec x))]
    [(expr-natrec m b s t)
     (expr-natrec (rewrite-spec m) (rewrite-spec b) (rewrite-spec s) (rewrite-spec t))]
    [(expr-boolrec m tc fc t)
     (expr-boolrec (rewrite-spec m) (rewrite-spec tc) (rewrite-spec fc) (rewrite-spec t))]
    [(expr-J m b l r p)
     (expr-J (rewrite-spec m) (rewrite-spec b) (rewrite-spec l) (rewrite-spec r) (rewrite-spec p))]
    ;; Net/propagator nodes
    [(expr-net-new-cell net init merge)
     (expr-net-new-cell (rewrite-spec net) (rewrite-spec init) (rewrite-spec merge))]
    ;; Leaves — return unchanged
    [_ e]))

;; Decompose an application chain into (head . args-list).
;; Returns (values head args) where head is the innermost non-app expression.
(define (decompose-app-for-spec e)
  (let loop ([expr e] [args '()])
    (match expr
      [(expr-app f a) (loop f (cons a args))]
      [_ (values expr args)])))


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
  ;; Phase D: Initialize ATMS for dependency-directed error tracking.
  ;; The ATMS box is always available — init-speculation-tracking! creates a
  ;; fresh ATMS per command. This is cheap (empty ATMS = ~3 hasheq allocations).
  (when (not (current-command-atms))
    (current-command-atms (box (atms-empty))))
  (init-speculation-tracking!)
  (parameterize ([current-nf-cache (make-hash)]         ;; per-command nf memoization
                 [current-whnf-cache (make-hash)]       ;; per-command whnf memoization
                 [current-reduction-fuel (box 1000000)]  ;; 1M step limit
                 [current-nat-value-cache (make-hash)]  ;; per-command nat-value memoization
                 [current-coercion-warnings '()]         ;; per-command coercion warnings
                 [current-deprecation-warnings '()]      ;; per-command deprecation warnings
                 [current-capability-warnings '()]       ;; per-command capability warnings
                 [current-capability-constraint-map (make-hasheq)])  ;; per-command capability constraints
  (define result
  (let ()
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
          (let ([elab-result (time-phase! elaborate (elaborate-top-level expanded))])
            (if (prologos-error? elab-result)
                elab-result
                (match elab-result
                  ;; (check expr type)
                  [(list 'check expr type)
                   ;; GDE-1: Record check annotation as ATMS context assumption.
                   (add-context-assumption!
                    'check-type-annotation
                    (format "check : ~a" (pp-expr type)))
                   (let ([chk (time-phase! type-check (check/err ctx-empty expr type))])
                     (if (prologos-error? chk) chk
                         "OK"))]

                  ;; (eval expr)
                  [(list 'eval expr)
                   (let ([ty (time-phase! type-check (infer/err ctx-empty expr))])
                     (if (prologos-error? ty) ty
                         (begin
                           ;; Trait resolution: handled by propagator cell-path in solve-meta!
                           (let ([te (check-unresolved-trait-constraints)])
                             (if (not (null? te))
                                 (car te)
                                 (begin
                                   (let ([val (time-phase! reduce
                                                (nf (rewrite-specializations
                                                     (time-phase! zonk (zonk-final expr)))))]
                                         [ty-nf (time-phase! reduce (nf (time-phase! zonk (zonk-final ty))))])
                                     ;; Check for panic at runtime
                                     (if (expr-panic? val)
                                         (prologos-error #f
                                           (format "panic: ~a"
                                             (if (expr-string? (expr-panic-msg val))
                                                 (expr-string-val (expr-panic-msg val))
                                                 (pp-expr (expr-panic-msg val)))))
                                         (format "~a : ~a" (pp-expr val) (pp-expr ty-nf))))))))))]

                  ;; (infer expr)
                  [(list 'infer expr)
                   (let ([ty (time-phase! type-check (infer/err ctx-empty expr))])
                     (if (prologos-error? ty) ty
                         (begin
                           ;; Trait resolution: handled by propagator cell-path in solve-meta!
                           (let ([te (check-unresolved-trait-constraints)])
                             (if (not (null? te))
                                 (car te)
                                 (begin
                                   (pp-expr (time-phase! zonk (zonk-final ty)))))))))]

                  ;; (expand datum) — show preparse expansion
                  [(list 'expand datum)
                   (pp-datum (preparse-expand-single datum))]

                  ;; (expand-1 datum) — show single-step preparse expansion
                  [(list 'expand-1 datum)
                   (pp-datum (preparse-expand-1 datum))]

                  ;; (expand-full datum) — show all preparse transforms with labels
                  [(list 'expand-full datum)
                   (let ([steps (preparse-expand-full datum)])
                     (string-join
                      (map (lambda (step)
                             (format "~a: ~a" (car step) (pp-datum (cdr step))))
                           steps)
                      "\n"))]

                  ;; (parse surf) — show parsed surface AST
                  [(list 'parse surf)
                   (format "~s" surf)]

                  ;; (elaborate expr) — show elaborated core AST
                  [(list 'elaborate expr)
                   (pp-expr (zonk-final expr))]

                  ;; (defr name expr) — named relation definition (Phase 7)
                  ;; Type-infer the relation, register in global env + relation store
                  [(list 'defr name expr)
                   (let ([ty (time-phase! type-check (infer/err ctx-empty expr))])
                     (if (prologos-error? ty) ty
                         (begin
                           ;; Trait resolution: handled by propagator cell-path in solve-meta!
                           (let ([te (check-unresolved-trait-constraints)])
                             (if (not (null? te))
                                 (car te)
                                 (begin
                                   (let ([zonked-body (time-phase! zonk (zonk-final expr))]
                                       [zonked-type (time-phase! zonk (zonk-final ty))])
                                   (current-global-env
                                    (global-env-add (current-global-env) name zonked-type zonked-body))
                                   (when (current-ns-context)
                                     (define fqn (qualify-name name
                                                   (ns-context-current-ns (current-ns-context))))
                                     (current-global-env
                                      (global-env-add (current-global-env) fqn zonked-type zonked-body)))
                                   ;; Convert zonked defr body to runtime relation-info
                                   ;; and register in the global relation store
                                   (when (expr-defr? zonked-body)
                                     (define rel-info (expr-defr->relation-info zonked-body))
                                     (current-relation-store
                                      (relation-register (current-relation-store) rel-info))
                                     (bump-relation-store-version!))
                                   (format "~a : ~a defined." name (pp-expr zonked-type)))))))))]

                  ;; (subtype sub-key super-key) — declaration already processed in elaborator
                  [(list 'subtype sub-key super-key)
                   (format "subtype ~a <: ~a registered." sub-key super-key)]

                  ;; (selection name-fqn name-short schema-name) — selection declaration
                  ;; Install the selection name as a type in the global env.
                  [(list 'selection name-fqn name-short schema-name)
                   ;; Install under both FQN and short name
                   (current-global-env
                    (global-env-add-type-only (current-global-env) name-fqn (expr-Type 0)))
                   (unless (eq? name-fqn name-short)
                     (current-global-env
                      (global-env-add-type-only (current-global-env) name-short (expr-Type 0))))
                   (format "selection ~a from ~a registered." name-short schema-name)]

                  ;; (capability name-fqn name-short cap-type) — capability declaration
                  ;; Install the capability name as a type in the global env.
                  ;; Nullary caps: cap-type = (expr-Type 0).
                  ;; Dependent caps: cap-type = Pi(p :0 T, ... (expr-Type 0)).
                  [(list 'capability name-fqn name-short cap-type)
                   ;; Install under both FQN and short name
                   (current-global-env
                    (global-env-add-type-only (current-global-env) name-fqn cap-type))
                   (unless (eq? name-fqn name-short)
                     (current-global-env
                      (global-env-add-type-only (current-global-env) name-short cap-type)))
                   (format "capability ~a registered." name-short)]

                  ;; (cap-closure name) — transitive capability closure query
                  [(list 'cap-closure name)
                   (define result (run-capability-inference))
                   (define closure (capability-closure result name))
                   (if (set-empty? closure)
                       (format "~a: pure (no capabilities required)" name)
                       (format "~a requires: ~a"
                               name
                               (string-join
                                (sort (map symbol->string (set->list closure)) string<?)
                                ", ")))]

                  ;; (cap-audit name cap-name) — provenance trail query
                  [(list 'cap-audit name cap-name)
                   (define result (run-capability-inference))
                   (define closure (capability-closure result name))
                   (cond
                     [(not (set-member? closure cap-name))
                      (format "~a does not require ~a" name cap-name)]
                     [else
                      (define trail (capability-audit-trail result name cap-name))
                      (if (null? trail)
                          (format "~a directly declares ~a" name cap-name)
                          (format "~a requires ~a because:\n~a"
                                  name cap-name
                                  (string-join
                                   (map (lambda (edge)
                                          (format "  ~a calls ~a" (first edge) (second edge)))
                                        trail)
                                   "\n")))])]

                  ;; (cap-verify name) — authority root subsumption check
                  [(list 'cap-verify name)
                   (define vresult (verify-authority-root name))
                   (cond
                     [(authority-root-ok? vresult)
                      (format "~a: authority root verification passed." name)]
                     [(authority-root-failure? vresult)
                      (define missing (authority-root-failure-missing vresult))
                      (define traces (authority-root-failure-traces vresult))
                      (define missing-str
                        (string-join
                         (sort (map symbol->string (set->list missing)) string<?)
                         ", "))
                      (define trace-lines
                        (for/list ([trace (in-list traces)])
                          (define cap-name (first trace))
                          (define trail (second trace))
                          (if (null? trail)
                              (format "  ~a: directly declared" cap-name)
                              (format "  ~a: ~a"
                                      cap-name
                                      (string-join
                                       (map (lambda (edge)
                                              (format "~a → ~a" (first edge) (second edge)))
                                            trail)
                                       " → ")))))
                      (format "error[E2002]: authority root `~a` does not cover required capabilities\n  Missing: {~a}\n  Capability traces:\n~a"
                              name
                              missing-str
                              (string-join trace-lines "\n"))])]

                  ;; (cap-bridge name) — cross-domain bridge analysis
                  [(list 'cap-bridge name)
                   (define bridge-result (build-cross-domain-network))
                   (define type-closures (cap-type-bridge-result-type-closures bridge-result))
                   (define cap-closures (cap-type-bridge-result-cap-closures bridge-result))
                   (define overdeclared-set (cap-audit-overdeclared bridge-result name))
                   ;; Type from the env (original)
                   (define entry (hash-ref (current-global-env) name #f))
                   (define type-str
                     (if (and entry (pair? entry))
                         (format "~a" (car entry))
                         "<unknown>"))
                   ;; Capabilities from type decomposition (α direction)
                   (define type-caps (hash-ref cap-closures name (seteq)))
                   (define type-caps-str
                     (if (set-empty? type-caps)
                         "∅ (pure)"
                         (string-join (sort (map symbol->string (set->list type-caps)) string<?) ", ")))
                   ;; Capabilities from call-graph inference
                   (define inferred-caps (hash-ref cap-closures name (seteq)))
                   (define inferred-str
                     (if (set-empty? inferred-caps)
                         "∅ (pure)"
                         (string-join (sort (map symbol->string (set->list inferred-caps)) string<?) ", ")))
                   ;; Overdeclared
                   (define overdeclared-str
                     (if (set-empty? overdeclared-set)
                         "none"
                         (string-join (sort (map symbol->string (set->list overdeclared-set)) string<?) ", ")))
                   (string-join
                    (list (format "cap-bridge ~a:" name)
                          (format "  Type: ~a" type-str)
                          (format "  Capabilities (from type): {~a}" type-caps-str)
                          (format "  Capabilities (inferred):  {~a}" inferred-str)
                          (format "  Overdeclared:             {~a}" overdeclared-str))
                    "\n")]

                  [_ (prologos-error srcloc-unknown (format "Unknown command: ~a" elab-result))])))]))))
  ;; Append warnings to result string (if any)
  (define coercion-warns (reverse (current-coercion-warnings)))
  (define deprecation-warns (reverse (current-deprecation-warnings)))
  (define capability-warns (reverse (current-capability-warnings)))
  (define all-warning-strs
    (append (map format-coercion-warning coercion-warns)
            (map format-deprecation-warning deprecation-warns)
            (map format-capability-warning capability-warns)))
  (if (or (null? all-warning-strs) (prologos-error? result))
      result
      (string-join
       (cons result all-warning-strs)
       "\n"))))

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
     (define body (time-phase! elaborate (elaborate body-surf)))
     (cond
       [(prologos-error? body) body]
       [else
        (define inferred-type (time-phase! type-check (infer/err ctx-empty body)))
        (cond
          [(prologos-error? inferred-type) inferred-type]
          [else
           (define ty-ok (is-type/err ctx-empty inferred-type))
           (cond
             [(prologos-error? ty-ok) ty-ok]
             [else
              ;; Trait resolution: handled by propagator cell-path in solve-meta!
              ;; Check for unresolved trait constraints (error reporting)
              (define trait-errors (check-unresolved-trait-constraints))
              ;; Phase 4: Check for unresolved capability constraints
              (define cap-errors (check-unresolved-capability-constraints))
              (cond
                [(not (null? trait-errors))
                 (car trait-errors)]  ;; Return the first unresolved trait error
                [(not (null? cap-errors))
                 (car cap-errors)]    ;; Return the first unresolved capability error
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
                 ;; zonk-final FIRST, then specialize, then QTT on zonked terms
                 (define zonked-body (rewrite-specializations (time-phase! zonk (zonk-final body))))
                 (define zonked-type (time-phase! zonk (zonk-final inferred-type)))
                 ;; Skip QTT for expressions with unsupported node types (Vec/Fin)
                 (define qtt-ok
                   (if (contains-unsupported-qtt? zonked-body)
                       #t
                       (time-phase! qtt (checkQ-top/err ctx-empty zonked-body zonked-type))))
                 (cond
                   [(prologos-error? qtt-ok) qtt-ok]
                   [else
                    (current-global-env
                     (global-env-add (current-global-env) name zonked-type zonked-body))
                    (when (current-ns-context)
                      (define fqn (qualify-name name
                                    (ns-context-current-ns (current-ns-context))))
                      (current-global-env
                       (global-env-add (current-global-env) fqn zonked-type zonked-body)))
                    (format "~a : ~a defined." name (pp-expr zonked-type))])])])])])])]
    ;; Existing annotated path (type annotation present)
    [else
     ;; 1. Elaborate type
     (define type (time-phase! elaborate (elaborate type-surf)))
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
           ;; GDE-1: Record user type annotation as ATMS context assumption.
           ;; This enables error messages like "because: user annotated x : Nat".
           (add-context-assumption!
            'def-type-annotation
            (format "~a : ~a" name (pp-expr type)))
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
                 (and short-name-for-check (lookup-ctor short-name-for-check))
                 ;; Schema types: opaque like data types, body not checked
                 (lookup-schema name)
                 (and short-name-for-check (lookup-schema short-name-for-check))))
           ;; For data type definitions, skip body elaboration/checking entirely.
           ;; The type is opaque (stored with value = #f), so the Church-encoded
           ;; body is never used at runtime. The type annotation is all we need.
           (cond
             [data-type-def?
              (let ([zonked-type (time-phase! zonk (zonk-final type))])
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
              (define body (time-phase! elaborate (elaborate body-surf)))
              (cond
                [(prologos-error? body)
                 ;; Remove pre-registered entry on elaboration failure
                 (current-global-env (hash-remove (current-global-env) name))
                 (when (current-ns-context)
                   (current-global-env
                    (hash-remove (current-global-env)
                     (qualify-name name (ns-context-current-ns (current-ns-context))))))
                 body]
                [else
                 ;; 5. Check body against type (use type which has metas instead of holes)
                 ;; Sprint 9: pass recovered name map for de Bruijn recovery in errors
                 (define chk (time-phase! type-check (check/err ctx-empty body type srcloc-unknown (recover-name-map))))
                 (cond
                   [(prologos-error? chk)
                    ;; Remove pre-registered entry on type-check failure
                    (current-global-env (hash-remove (current-global-env) name))
                    (when (current-ns-context)
                      (current-global-env
                       (hash-remove (current-global-env)
                        (qualify-name name (ns-context-current-ns (current-ns-context))))))
                    chk]
                   [else
                    ;; Phase C: resolve trait-constraint metas to dictionary expressions
                    ;; Trait resolution: handled by propagator cell-path in solve-meta!
                    ;; Phase C.6: Check for unresolved trait constraints
                    (define trait-errors-ann (check-unresolved-trait-constraints))
                    ;; Phase 4: Check for unresolved capability constraints
                    (define cap-errors-ann (check-unresolved-capability-constraints))
                    (cond
                      [(not (null? trait-errors-ann))
                       (current-global-env (hash-remove (current-global-env) name))
                       (when (current-ns-context)
                         (current-global-env
                          (hash-remove (current-global-env)
                           (qualify-name name (ns-context-current-ns (current-ns-context))))))
                       (car trait-errors-ann)]
                      [(not (null? cap-errors-ann))
                       (current-global-env (hash-remove (current-global-env) name))
                       (when (current-ns-context)
                         (current-global-env
                          (hash-remove (current-global-env)
                           (qualify-name name (ns-context-current-ns (current-ns-context))))))
                       (car cap-errors-ann)]
                      [else
                    ;; 5.5. Check for failed constraints (Sprint 5)
                    (define failed (all-failed-constraints))
                    (cond
                      [(not (null? failed))
                       ;; Remove pre-registered entry on constraint failure
                       (current-global-env (hash-remove (current-global-env) name))
                       (when (current-ns-context)
                         (current-global-env
                          (hash-remove (current-global-env)
                           (qualify-name name (ns-context-current-ns (current-ns-context))))))
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
                       ;; 6. zonk-final (resolves mult-metas to concrete values,
                       ;; defaults unsolved level-metas to lzero, mult-metas to mw).
                       ;; Then rewrite call sites to use registered specializations.
                       (define zonked-body (rewrite-specializations (time-phase! zonk (zonk-final body))))
                       (define zonked-type (time-phase! zonk (zonk-final type)))
                       ;; 6.5. QTT multiplicity check (on zonked terms with concrete mults).
                       ;; Skip for expressions containing unsupported node types (Vec/Fin).
                       (define qtt-ok
                         (if (contains-unsupported-qtt? zonked-body)
                             #t  ;; skip QTT for unsupported expression types
                             (time-phase! qtt (checkQ-top/err ctx-empty zonked-body zonked-type
                                             srcloc-unknown (recover-name-map)))))
                       (cond
                         [(prologos-error? qtt-ok)
                          ;; Remove pre-registered entry on QTT failure
                          (current-global-env (hash-remove (current-global-env) name))
                          (when (current-ns-context)
                            (current-global-env
                             (hash-remove (current-global-env)
                              (qualify-name name (ns-context-current-ns (current-ns-context))))))
                          qtt-ok]
                         [else
                          (current-global-env
                           (global-env-add (current-global-env) name zonked-type zonked-body))
                          (when (current-ns-context)
                            (define fqn (qualify-name name
                                          (ns-context-current-ns (current-ns-context))))
                            (current-global-env
                             (global-env-add (current-global-env) fqn zonked-type zonked-body)))
                          (format "~a : ~a defined."
                                  name (pp-expr zonked-type))])]
                      )])])])])])])]))

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
      (hash-set m arity (string->symbol (format "~a::~a" name arity)))))
  ;; Register the dispatch table
  (register-multi-defn! name arities arity-map docstring)
  ;; Also register with namespace qualification if applicable
  (when (current-ns-context)
    (define fqn (qualify-name name (ns-context-current-ns (current-ns-context))))
    (define fqn-arity-map
      (for/fold ([m (hasheq)])
                ([arity (in-list arities)])
        (hash-set m arity (qualify-name
                           (string->symbol (format "~a::~a" name arity))
                           (ns-context-current-ns (current-ns-context))))))
    (register-multi-defn! fqn arities fqn-arity-map docstring))
  ;; Process each clause def through process-def (handles type checking, registration)
  ;; Re-init meta store + speculation tracking per clause
  (define results
    (for/list ([def (in-list defs)])
      (reset-meta-store!)
      (init-speculation-tracking!)
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
  (define pt (phase-timings 0.0 0.0 0.0 0.0 0.0 0.0 0.0))
  (define pv (provenance-counters 0 0 0 0 0 0 0))
  (define mem-before (measure-memory-before))
  (define-values (results pc)
    (parameterize ([current-phase-timings pt]
                   [current-provenance-counters pv])
      (with-perf-counters
        (for/list ([surf (in-list surfs)])
          (if (prologos-error? surf)
              surf
              (process-command surf))))))
  (when pc (print-perf-report! pc))
  (print-phase-report! pt)
  (print-provenance-report! pv)
  (print-memory-report! (measure-memory-after mem-before))
  results)

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
  (define pt (phase-timings 0.0 0.0 0.0 0.0 0.0 0.0 0.0))
  (define pv (provenance-counters 0 0 0 0 0 0 0))
  (define mem-before (measure-memory-before))
  (define-values (results pc)
    (parameterize ([current-phase-timings pt]
                   [current-provenance-counters pv])
      (with-perf-counters
        (for/list ([surf (in-list surfs)])
          (if (prologos-error? surf)
              surf
              (process-command surf))))))
  (when pc (print-perf-report! pc))
  (print-phase-report! pt)
  (print-provenance-report! pv)
  (print-memory-report! (measure-memory-after mem-before))
  results)

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
       (error 'imports "Circular dependency detected: ~a" ns-sym))

     ;; 3. Resolve to file path
     (define file-path
       (resolve-ns-path ns-sym base-dir))
     (unless file-path
       (error 'imports "Cannot find module: ~a (searched lib paths: ~a)"
              ns-sym (current-lib-paths)))

     ;; 4. Process the file in a fresh environment
     (define mod-env #f)
     (define mod-ns-ctx #f)
     (define mod-preparse-reg #f)
     (define mod-ctor-reg #f)
     (define mod-type-meta #f)
     (define mod-multi-defn-reg #f)
     (define mod-spec-store #f)
     (define mod-subtype-reg #f)
     (define mod-coercion-reg #f)
     (define mod-capability-reg #f)
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
                    [current-subtype-registry (current-subtype-registry)]
                    [current-coercion-registry (current-coercion-registry)]
                    [current-capability-registry (current-capability-registry)]
                    [current-spec-store (hasheq)]  ;; fresh — specs are module-local
                    [current-propagated-specs (seteq)]  ;; fresh propagated tracking
                    [current-loading-set (set-add (current-loading-set) ns-sym)]
                    ;; Phase 8b: fresh propagator network per module
                    [current-prop-net-box #f]
                    [current-prop-id-map-box #f]
                    ;; Phase A: fresh meta-info CHAMP per module
                    [current-prop-meta-info-box #f]
                    ;; Phase B: fresh auxiliary meta CHAMPs per module
                    [current-level-meta-champ-box #f]
                    [current-mult-meta-champ-box #f]
                    [current-sess-meta-champ-box #f]
                    ;; Phase D: fresh ATMS per module
                    [current-command-atms #f]
)
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
             (error 'imports "Error loading module ~a: ~a"
                    ns-sym (prologos-error-message result)))))

       ;; Capture the resulting environment, namespace context, and registries
       (set! mod-env (current-global-env))
       (set! mod-ns-ctx (current-ns-context))
       (set! mod-preparse-reg (current-preparse-registry))
       (set! mod-ctor-reg (current-ctor-registry))
       (set! mod-type-meta (current-type-meta))
       (set! mod-multi-defn-reg (current-multi-defn-registry))
       (set! mod-spec-store (current-spec-store))
       (set! mod-subtype-reg (current-subtype-registry))
       (set! mod-coercion-reg (current-coercion-registry))
       (set! mod-capability-reg (current-capability-registry)))

     ;; Propagate preparse registry changes (deftype/defmacro) to the caller.
     ;; This ensures type aliases and macros defined in loaded modules are
     ;; available to subsequent code in the requiring module.
     (current-preparse-registry mod-preparse-reg)

     ;; Propagate constructor metadata (for reduce) to the caller.
     (current-ctor-registry mod-ctor-reg)
     (current-type-meta mod-type-meta)

     ;; Propagate multi-defn dispatch tables to the caller.
     (current-multi-defn-registry mod-multi-defn-reg)

     ;; Phase E: Propagate subtype and coercion registries.
     (current-subtype-registry mod-subtype-reg)
     (current-coercion-registry mod-coercion-reg)

     ;; Capability registry: propagate capability declarations from loaded modules.
     (current-capability-registry mod-capability-reg)

     ;; Note: spec store is NOT globally propagated — it's carried in module-info
     ;; for selective propagation via process-imports-spec.

     ;; 5. Build module-info
     ;; Export determination priority:
     ;;   1. Explicit `provide` overrides everything (backward compat)
     ;;   2. Auto-exports from public def/defn/data/deftype/defmacro
     ;;   3. No provide and no auto-exports → export nothing
     (define exports
       (cond
         ;; Explicit provide present and non-empty
         [(and mod-ns-ctx
               (not (null? (ns-context-exports mod-ns-ctx))))
          (let ([exp (ns-context-exports mod-ns-ctx)])
            (cond
              ;; :all — export everything defined in the namespace
              [(and (pair? exp) (eq? (car exp) ':all))
               (for/list ([(k _) (in-hash mod-env)]
                          #:when (let-values ([(prefix name) (split-qualified-name k)])
                                   (and prefix (eq? prefix ns-sym))))
                 (let-values ([(_ name) (split-qualified-name k)])
                   name))]
              [else exp]))]
         ;; No explicit provide — use auto-exports if available
         [(and mod-ns-ctx
               (not (null? (ns-context-auto-exports mod-ns-ctx))))
          (reverse (ns-context-auto-exports mod-ns-ctx))]
         ;; No provide and no auto-exports — export nothing
         [else '()]))

     (define mi (module-info ns-sym
                             exports
                             mod-env
                             file-path
                             (hasheq)
                             (hasheq)
                             mod-spec-store))

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
  (current-foreign-handler handle-foreign)
  ;; Install spec propagation handler: imports module specs into current spec store.
  ;; This enables implicit arg insertion for HKT generic functions (which have
  ;; where-constraints that the elaborator needs specs to count correctly).
  (current-spec-propagation-handler
    (lambda (mod names)
      (define mod-specs (module-info-specs mod))
      (for ([name (in-list (if (and (pair? names) (eq? (car names) ':all))
                                (hash-keys mod-specs)
                                names))])
        (define spec-entry (hash-ref mod-specs name #f))
        (when spec-entry
          (current-spec-store
            (hash-set (current-spec-store) name spec-entry))
          ;; Mark as propagated so own-module defs can override silently
          (current-propagated-specs
            (set-add (current-propagated-specs) name))))))
  (when (null? (current-lib-paths))
    (current-lib-paths (list prologos-lib-dir))))

;; ========================================
;; Foreign Import Handler
;; ========================================
;; datum = (foreign racket "module-path" [:as module-alias] (name1 [:as alias1] : type1...) ...)
;; Parses each declaration, dynamic-requires the Racket binding, builds
;; an expr-foreign-fn value, and registers it in the global environment.
;;
;; Supports :as aliasing at two levels:
;;   Module-level: (foreign racket "mod" :as rkt (add1 : Nat -> Nat))
;;                 → registers as rkt/add1
;;   Symbol-level: (foreign racket "mod" (add1 :as increment : Nat -> Nat))
;;                 → registers as increment
;;   Combined:     (foreign racket "mod" :as rkt (add1 :as increment : Nat -> Nat))
;;                 → registers as rkt/increment

(define (handle-foreign datum)
  (unless (and (list? datum) (>= (length datum) 4)
               (eq? (cadr datum) 'racket)
               (string? (caddr datum)))
    (error 'foreign "Expected: (foreign racket \"module\" [:as alias] [:requires (Cap ...)] (name [:as alias] : type) ...)"))
  (define module-path-str (caddr datum))
  (define rest (cdddr datum))

  ;; Check for optional module-level :as alias
  ;; WS reader produces 'as (keyword stripped), sexp reader produces ':as
  (define-values (module-alias rest1)
    (if (and (>= (length rest) 2)
             (memq (car rest) '(:as as))
             (symbol? (cadr rest)))
        (values (cadr rest) (cddr rest))
        (values #f rest)))

  ;; Check for optional capability annotations.
  ;; Two formats:
  ;;   :requires (Cap1 Cap2 ...) — explicit keyword (works in both sexp and WS mode)
  ;;   ($brace-params name :0 Cap ...) — WS reader's brace-params
  (define-values (foreign-caps decls)
    (extract-foreign-caps rest1))

  (when (null? decls)
    (error 'foreign "No declarations after module alias ~a" (or module-alias "")))

  (for ([decl (in-list decls)])
    (handle-foreign-decl module-path-str decl module-alias foreign-caps)))

;; Extract capability annotations from remaining foreign tokens.
;; Returns: (values cap-names remaining-decls)
;; cap-names: list of capability type symbols
;; remaining-decls: list with capability annotations removed
(define (extract-foreign-caps tokens)
  (let loop ([toks tokens] [caps '()] [decls '()])
    (cond
      [(null? toks) (values caps (reverse decls))]
      ;; :requires (Cap1 Cap2 ...) — keyword form
      [(and (>= (length toks) 2)
            (memq (car toks) '(:requires requires))
            (list? (cadr toks)))
       (define cap-names
         (for/list ([c (in-list (cadr toks))]
                    #:when (and (symbol? c) (capability-type? c)))
           c))
       (loop (cddr toks) (append caps cap-names) decls)]
      ;; ($brace-params ...) — WS reader brace-params, extract capability types
      [(and (list? (car toks))
            (pair? (car toks))
            (eq? (caar toks) '$brace-params))
       (define bp-body (cdar toks))
       ;; Parse brace-params: (name :mult Type name2 :mult Type2 ...)
       ;; Extract type names that are capability types
       (define cap-names (extract-caps-from-brace-params bp-body))
       (loop (cdr toks) (append caps cap-names) decls)]
      [else
       (loop (cdr toks) caps (cons (car toks) decls))])))

;; Extract capability type names from brace-params body.
;; Format: (name :mult Type name2 :mult Type2 ...) or (name Type ...) (default mult)
;; Returns list of symbols that are capability types.
(define (extract-caps-from-brace-params bp-body)
  (let loop ([elems bp-body] [caps '()])
    (cond
      [(null? elems) caps]
      ;; Skip multiplicity annotations (:0, :1, :w)
      [(and (symbol? (car elems))
            (memq (car elems) '(:0 :1 :w m0 m1 mw)))
       (loop (cdr elems) caps)]
      ;; Capability type name?
      [(and (symbol? (car elems))
            (capability-type? (car elems)))
       (loop (cdr elems) (cons (car elems) caps))]
      ;; Skip other elements (parameter names, non-capability types)
      [else (loop (cdr elems) caps)])))

;; Process a single foreign declaration: (name [:as alias] : type-tokens...)
;; e.g., (add1 : Nat -> Nat)            — no alias
;;       (add1 :as increment : Nat -> Nat) — symbol alias
;;
;; module-alias: optional symbol prefix (e.g., 'rkt → registers as rkt/name)
;; foreign-caps: list of capability type symbols required by this foreign block
(define (handle-foreign-decl module-path-str decl [module-alias #f] [foreign-caps '()])
  (unless (and (list? decl) (>= (length decl) 3)
               (or (symbol? (car decl)) (string? (car decl))))
    (error 'foreign "Expected: (name [:as alias] : type), got: ~a" decl))

  ;; Normalize: if Racket name is a string (for names with <, > chars
  ;; that the WS reader can't tokenize), convert to symbol
  (define raw-racket-name
    (if (string? (car decl))
        (string->symbol (car decl))
        (car decl)))

  ;; Parse symbol-level alias: (name :as alias : type...) or (name : type...)
  (define-values (racket-name local-name type-tokens)
    (cond
      ;; (name :as alias : type...) — symbol-level alias
      [(and (>= (length decl) 5)
            (memq (cadr decl) '(:as as))
            (symbol? (caddr decl))
            (eq? (cadddr decl) ':))
       (values raw-racket-name (caddr decl) (cddddr decl))]
      ;; (name : type...) — no alias
      [(eq? (cadr decl) ':)
       (values raw-racket-name raw-racket-name (cddr decl))]
      [else
       (error 'foreign "Expected: (name : type) or (name :as alias : type), got: ~a" decl)]))

  ;; Compute final Prologos registration name
  ;; With module-alias 'rkt and local-name 'increment → 'rkt/increment
  ;; Without module-alias, local-name 'increment → 'increment
  (define prologos-name
    (if module-alias
        (string->symbol
         (string-append (symbol->string module-alias) "/" (symbol->string local-name)))
        local-name))

  ;; Build a type sexp from the tokens: (Nat -> Nat -> Bool) → (-> Nat (-> Nat Bool))
  (define type-sexp (foreign-type-tokens->sexp type-tokens))

  ;; Parse and elaborate the type
  (reset-meta-store!)
  (define type-surf (parse-datum type-sexp))
  (when (prologos-error? type-surf)
    (error 'foreign "Failed to parse type for ~a: ~a" racket-name type-surf))
  (define type-expr (elaborate type-surf))
  (when (prologos-error? type-expr)
    (error 'foreign "Failed to elaborate type for ~a: ~a" racket-name type-expr))

  ;; Zonk the type to resolve any metas
  (define zonked-type (zonk-final type-expr))

  ;; If foreign capabilities declared, prepend :0 Pi binders.
  ;; (Pi (c :0 ReadCap) (Pi (x :w String) String)) — capability proof precedes real args.
  ;; This makes capability requirements visible to:
  ;;   - Phase 4 lexical resolution (insert-implicits resolves :0 cap binders)
  ;;   - Phase 5 inference (extract-capability-requirements walks Pi chain)
  (define full-type
    (if (null? foreign-caps)
        zonked-type
        (foldr (lambda (cap-name rest-type)
                 (expr-Pi 'm0 (expr-fvar cap-name) rest-type))
               zonked-type
               foreign-caps)))

  ;; dynamic-require the Racket function using its ORIGINAL Racket name
  (define rkt-mod-path (string->symbol module-path-str))
  (define rkt-proc
    (with-handlers ([exn:fail? (lambda (e)
                                 (error 'foreign "Cannot import ~a from ~a: ~a"
                                        racket-name module-path-str (exn-message e)))])
      (dynamic-require rkt-mod-path racket-name)))

  ;; Parse type to get marshalling info — use the original type (without capability Pi binders)
  ;; because marshalling only applies to the runtime argument types, not erased capabilities
  (define parsed-type (parse-foreign-type zonked-type))
  (define-values (marshal-in marshal-out) (make-marshaller-pair parsed-type))
  (define arity (length (car parsed-type)))

  ;; Build the foreign-fn value with the Prologos name
  (define val (expr-foreign-fn prologos-name rkt-proc arity '() marshal-in marshal-out))

  ;; Register in global env with full type (including capability Pi binders)
  (current-global-env
   (global-env-add (current-global-env) prologos-name full-type val))

  ;; Also register FQN if in a namespace
  (when (current-ns-context)
    (define fqn (qualify-name prologos-name (ns-context-current-ns (current-ns-context))))
    (current-global-env
     (global-env-add (current-global-env) fqn full-type val))
    ;; Auto-export the foreign binding
    (ns-context-add-auto-export (current-ns-context) prologos-name)))

;; Convert foreign type tokens to a parseable sexp.
;; Transforms infix (Nat -> Nat -> Bool) to prefix (-> Nat (-> Nat Bool)).
;; Supports uncurried syntax: (Nat Nat -> Bool) → (-> Nat (-> Nat Bool))
;; where multiple tokens before the last -> are expanded into separate domains.
;; The last segment is never expanded (multi-token = type application, e.g. List Nat).
(define (foreign-type-tokens->sexp tokens)
  (cond
    ;; Single token: bare type like Nat, Bool, Unit
    [(= (length tokens) 1) (car tokens)]
    ;; Multi-token with ->: split on arrows, expand uncurried segments
    [(memq '-> tokens)
     (define parts (split-on-arrow tokens))
     ;; Expand multi-token non-final segments (uncurried syntax).
     ;; (Nat Nat -> Bool) splits to ((Nat Nat) Bool), expand to (Nat Nat Bool).
     ;; Last segment stays as-is (multi-token = type application like List Nat).
     (define expanded
       (let ([non-final (drop-right parts 1)]
             [final     (last parts)])
         (append
          (append-map (lambda (p) (if (list? p) p (list p))) non-final)
          (list final))))
     (define (build parts)
       (cond
         [(= (length parts) 1) (car parts)]
         [else (list '-> (car parts) (build (cdr parts)))]))
     (build expanded)]
    ;; No arrows: just a single type expression (shouldn't happen with well-formed input)
    [else (error 'foreign "Cannot parse foreign type tokens: ~a" tokens)]))

;; Split a flat list on '-> symbols.
;; (Nat -> Nat -> Bool) → (Nat Nat Bool)
(define (split-on-arrow tokens)
  (let loop ([toks tokens] [current '()] [segments '()])
    (cond
      [(null? toks)
       (reverse (cons (if (= (length current) 1)
                          (car current)
                          (reverse current))
                      segments))]
      [(eq? (car toks) '->)
       (loop (cdr toks)
             '()
             (cons (if (= (length current) 1)
                       (car current)
                       (reverse current))
                   segments))]
      [else
       (loop (cdr toks) (cons (car toks) current) segments)])))

;; Auto-install on module load
(install-module-loader!)

;; Phase 8b: Install propagator network callbacks into metavar-store.
;; This breaks the circular dependency: metavar-store → elaborator-network → type-lattice → reduction → metavar-store.
(install-prop-network-callbacks!
 make-elaboration-network
 elab-fresh-meta
 elab-cell-write
 elab-cell-read
 elab-add-unify-constraint)

;; P5b: Install multiplicity cell callbacks
(current-prop-fresh-mult-cell elab-fresh-mult-cell)
(current-prop-mult-cell-write elab-mult-cell-write)

;; P1-G2: Install contradiction check callback
(current-prop-has-contradiction?
 (lambda ()
   (define net-box (current-prop-net-box))
   (and net-box
        (let ([enet (unbox net-box)])
          (net-contradiction? (elab-network-prop-net enet))))))

;; Phase E2: Install propagator-driven constraint wakeup.
;; When solve-meta! writes to a cell, the propagator network is run to
;; quiescence, handling transitive constraint propagation automatically.
;; The net-box stores elab-network (wrapping prop-network), so we provide
;; unwrap/rewrap callbacks to extract and re-insert the inner prop-network.
(current-prop-run-quiescence run-to-quiescence)
(current-prop-unwrap-net elab-network-prop-net)
(current-prop-rewrap-net
 (lambda (enet pnet*)
   (struct-copy elab-network enet [prop-net pnet*])))

;; Phase E1: Install meta-solution callback for propagator-aware merge.
;; This allows type-lattice-merge to follow solved metas (read-only) when
;; the propagator network merges cell values. Breaks no circular deps because
;; meta-solution is a pure read from propagator cell or CHAMP store.
(install-lattice-meta-solution-fn! meta-solution)

;; Phase C: Install incremental trait resolution callback.
;; When a type-arg meta is solved, this callback checks if the associated
;; trait constraint becomes resolvable (all type-args ground) and if so,
;; resolves it immediately via the existing monomorphic/parametric lookup.
(install-trait-resolve-callback!
 (lambda (dict-meta-id tc-info)
   (define trait-name (trait-constraint-info-trait-name tc-info))
   (define type-args
     (map (lambda (e) (normalize-for-resolution (zonk e)))
          (trait-constraint-info-type-arg-exprs tc-info)))
   (when (andmap ground-expr? type-args)
     (define dict-expr
       (or (try-monomorphic-resolve trait-name type-args)
           (try-parametric-resolve trait-name type-args)))
     (when dict-expr
       (solve-meta! dict-meta-id dict-expr)))))

;; ========================================
;; CLI entry point — process .prologos files
;; ========================================
;; Phase 7c: enables `racket driver.rkt file.prologos` for benchmarking.
;; Emits PERF-COUNTERS, PHASE-TIMINGS, MEMORY-STATS to stderr.
(module+ main
  (require racket/cmdline)
  (define files
    (command-line
     #:program "prologos-driver"
     #:args files files))
  (for ([f (in-list files)])
    (process-file f)))
