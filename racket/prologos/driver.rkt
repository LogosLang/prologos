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
         "cap-type-bridge.rkt"
         "sessions.rkt"           ;; Phase S3: session types (for driver integration)
         "processes.rkt"          ;; Phase S3: process types (for driver integration)
         "typing-sessions.rkt"    ;; Phase S3: type-proc judgment
         "session-runtime.rkt"    ;; Phase S7c: rt-execute-process (spawn execution)
         "effect-executor.rkt"    ;; AD-F2: rt-execute-process-auto (architecture dispatch)
         "global-constraints.rkt") ;; Phase 3c: current-narrow-var-constraints

(provide process-command
         process-file
         process-string
         process-string-ws
         load-module
         install-module-loader!
         prologos-lib-dir
         rewrite-specializations
         ;; Phase 6: Foreign capability gating helpers (for testing)
         extract-foreign-caps
         extract-caps-from-brace-params
         ;; IO-H: Post-compilation capability inference
         run-post-compilation-inference!)

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

;; Replace expr-hole with fresh metavariables in a type expression.
;; This allows holes in type annotations (e.g., return type of pattern-compiled
;; functions) to be solved via unification during type checking.
(define (holes-to-metas e)
  (match e
    [(expr-hole) (fresh-meta ctx-empty (expr-Type 0) "type-hole")]
    [(expr-typed-hole _) e]
    [(expr-Pi m a b) (expr-Pi m (holes-to-metas a) (holes-to-metas b))]
    [(expr-Sigma a b) (expr-Sigma (holes-to-metas a) (holes-to-metas b))]
    [(expr-app f x) (expr-app (holes-to-metas f) (holes-to-metas x))]
    [(expr-lam m a b) (expr-lam m (holes-to-metas a) (holes-to-metas b))]
    [_ e]))

;; After zonk-final, replace any remaining unsolved metas with holes.
;; Prevents dangling meta references in stored types (metas are cleared
;; between commands by reset-meta-store!).
(define (unsolved-metas-to-holes e)
  (match e
    [(expr-meta _) (expr-hole)]
    [(expr-Pi m a b) (expr-Pi m (unsolved-metas-to-holes a) (unsolved-metas-to-holes b))]
    [(expr-Sigma a b) (expr-Sigma (unsolved-metas-to-holes a) (unsolved-metas-to-holes b))]
    [(expr-app f x) (expr-app (unsolved-metas-to-holes f) (unsolved-metas-to-holes x))]
    [(expr-lam m a b) (expr-lam m (unsolved-metas-to-holes a) (unsolved-metas-to-holes b))]
    [_ e]))

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
;; ========================================
;; S5c: Process capability usage analysis
;; ========================================

;; Check if a core process body structurally uses any boundary operation
;; (proc-open, proc-connect, proc-listen) that references a capability.
;; Returns a set of cap-type expressions used in boundary ops.
(define (proc-body-used-caps proc-body)
  (match proc-body
    [(proc-open _path _sess cap-type cont)
     (set-union (if cap-type (set cap-type) (set)) (proc-body-used-caps cont))]
    [(proc-connect _addr _sess cap-type cont)
     (set-union (if cap-type (set cap-type) (set)) (proc-body-used-caps cont))]
    [(proc-listen _port _sess cap-type cont)
     (set-union (if cap-type (set cap-type) (set)) (proc-body-used-caps cont))]
    [(proc-send _e _c cont) (proc-body-used-caps cont)]
    [(proc-recv _c _binding _t cont) (proc-body-used-caps cont)]
    [(proc-sel _c _l cont) (proc-body-used-caps cont)]
    [(proc-case _c branches)
     (for/fold ([s (set)]) ([b (in-list branches)])
       (set-union s (proc-body-used-caps (cdr b))))]
    [(proc-new _s cont) (proc-body-used-caps cont)]
    [(proc-par left right)
     (set-union (proc-body-used-caps left) (proc-body-used-caps right))]
    [(proc-solve _t cont) (proc-body-used-caps cont)]
    [_ (set)]))

;; Emit W2002 warnings for capability binders that are never used in boundary ops.
;; Also emit W2003 for :w caps in process headers.
(define (check-process-cap-warnings name caps proc-body)
  (define used-caps (proc-body-used-caps proc-body))
  (for ([cap (in-list caps)])
    (define cap-name (first cap))
    (define cap-mult (second cap))
    (define cap-type (third cap))
    ;; W2003: ambient authority — :w cap in process header
    (when (eq? cap-mult 'mw)
      (emit-process-cap-warning! 'W2003 cap-name
        (format "ambient authority :w on ~a in process ~a — consider :0 or :1" cap-name name)))
    ;; W2002: dead authority — cap declared but not used in any boundary op
    (when (and (not (set-member? used-caps cap-type))
              (not (eq? cap-mult 'mw)))  ;; Don't double-warn if W2003 already fired
      (emit-process-cap-warning! 'W2002 cap-name
        (format "capability ~a declared but unused in process ~a" cap-name name)))))

;; Returns a result string, or a prologos-error.
;; Side effect: may update current-global-env for 'def'.
;;
;; When a namespace context is active, def stores names both as
;; bare symbols (for local use) and as fully-qualified names (for export).
(define (process-command surf)
  (reset-meta-store!)  ;; clear metavariables from previous command
  ;; Phase 2a/2b/2c: Create macros registry cells in the fresh network.
  (register-macros-cells! (current-prop-net-box) (current-prop-new-infra-cell))
  ;; Phase 2c: Create warning cells in the fresh network.
  (register-warning-cells! (current-prop-net-box) (current-prop-new-infra-cell))
  ;; Phase 3a: Create per-definition cells in the fresh network.
  (register-global-env-cells! (current-prop-net-box) (current-prop-new-infra-cell))
  ;; Phase D: Initialize ATMS for dependency-directed error tracking.
  ;; The ATMS box is always available — init-speculation-tracking! creates a
  ;; fresh ATMS per command. This is cheap (empty ATMS = ~3 hasheq allocations).
  (when (not (current-command-atms))
    (current-command-atms (box (atms-empty))))
  (init-speculation-tracking!)
  (parameterize ([current-global-env-prop-net-box (current-prop-net-box)]  ;; Phase 3a: activate cell writes (auto-reverts)
                 [current-nf-cache (make-hash)]         ;; per-command nf memoization
                 [current-whnf-cache (make-hash)]       ;; per-command whnf memoization
                 [current-reduction-fuel (box 1000000)]  ;; 1M step limit
                 [current-nat-value-cache (make-hash)]  ;; per-command nat-value memoization
                 [current-narrow-var-constraints (hasheq)] ;; Phase 3c: per-command constraint chain
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
         ;; IO-D5: Provision SysCap into scope for top-level expressions.
         ;; Top-level (REPL/interactive) acts as a powerbox — the user IS the authority.
          (let ([elab-result (time-phase! elaborate
                  (parameterize ([current-capability-scope
                                  (cons (cons 0 (expr-fvar 'SysCap))
                                        (current-capability-scope))])
                    (elaborate-top-level expanded)))])
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
                           ;; HasMethod resolution: search-based, runs after type checking
                           (resolve-hasmethod-constraints!)
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
                           ;; HasMethod resolution: search-based, runs after type checking
                           (resolve-hasmethod-constraints!)
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

                  ;; Phase 3b: Trait introspection commands
                  ;; (instances-of TraitName) — list all type instances
                  [(list 'instances-of trait-name)
                   (define impl-reg (current-impl-registry))
                   (define param-reg (current-param-impl-registry))
                   ;; Collect monomorphic instances from impl registry
                   (define mono-instances
                     (for/list ([(key entry) (in-hash impl-reg)]
                                #:when (eq? (impl-entry-trait-name entry) trait-name))
                       (impl-entry-type-args entry)))
                   ;; Collect parametric instances
                   (define param-instances
                     (hash-ref param-reg trait-name '()))
                   (define param-type-args
                     (map (lambda (pe)
                            (param-impl-entry-type-pattern pe))
                          param-instances))
                   (if (and (null? mono-instances) (null? param-type-args))
                       (format "No instances found for trait ~a" trait-name)
                       (string-append
                        (format "Instances of ~a:\n" trait-name)
                        (string-join
                         (append
                          (map (lambda (ta)
                                 (format "  ~a" (string-join (map (lambda (t) (format "~a" t)) ta) " ")))
                               mono-instances)
                          (map (lambda (tp)
                                 (format "  ~a (parametric)" (string-join (map (lambda (t) (format "~a" t)) tp) " ")))
                               param-type-args))
                         "\n")))]

                  ;; (methods-of TraitName) — list all methods
                  [(list 'methods-of trait-name)
                   (define tm (lookup-trait trait-name))
                   (if (not tm)
                       (format "No trait found: ~a" trait-name)
                       (let ([methods (trait-meta-methods tm)])
                         (if (null? methods)
                             (format "Trait ~a has no methods." trait-name)
                             (string-append
                              (format "Methods of ~a:\n" trait-name)
                              (string-join
                               (map (lambda (m)
                                      (format "  ~a : ~a"
                                              (trait-method-name m)
                                              (pp-datum (trait-method-type-datum m))))
                                    methods)
                               "\n")))))]

                  ;; (satisfies? TypeName TraitName) — check if type implements trait
                  [(list 'satisfies? type-name trait-name)
                   (define impl-reg (current-impl-registry))
                   (define param-reg (current-param-impl-registry))
                   ;; Check monomorphic: look for key "TypeName--TraitName"
                   (define mono-key
                     (string->symbol (format "~a--~a" type-name trait-name)))
                   (define mono? (hash-has-key? impl-reg mono-key))
                   ;; Check parametric instances
                   (define param?
                     (let ([entries (hash-ref param-reg trait-name '())])
                       (ormap (lambda (pe)
                                (let ([pattern (param-impl-entry-type-pattern pe)])
                                  (and (pair? pattern)
                                       (eq? (car pattern) type-name))))
                              entries)))
                   (if (or mono? param?)
                       (format "~a satisfies ~a: true" type-name trait-name)
                       (format "~a satisfies ~a: false" type-name trait-name))]

                  ;; (defr name expr) — named relation definition (Phase 7)
                  ;; Type-infer the relation, register in global env + relation store
                  [(list 'defr name expr)
                   (let ([ty (time-phase! type-check (infer/err ctx-empty expr))])
                     (if (prologos-error? ty) ty
                         (begin
                           ;; Trait resolution: handled by propagator cell-path in solve-meta!
                           ;; HasMethod resolution: search-based, runs after type checking
                           (resolve-hasmethod-constraints!)
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
                                (sort (map cap-entry->string (set->list closure)) string<?)
                                ", ")))]

                  ;; (cap-audit name cap-name) — provenance trail query
                  [(list 'cap-audit name cap-name)
                   (define result (run-capability-inference))
                   (define closure (capability-closure result name))
                   (cond
                     [(not (closure-has-cap-name? closure cap-name))
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
                         (sort (map cap-entry->string (set->list missing)) string<?)
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
                   (define looked-up-type (global-env-lookup-type name))
                   (define type-str
                     (if looked-up-type
                         (format "~a" looked-up-type)
                         "<unknown>"))
                   ;; Capabilities from type decomposition (α direction)
                   (define type-caps (hash-ref cap-closures name (set)))
                   (define type-caps-str
                     (if (set-empty? type-caps)
                         "∅ (pure)"
                         (string-join (sort (map cap-entry->string (set->list type-caps)) string<?) ", ")))
                   ;; Capabilities from call-graph inference
                   (define inferred-caps (hash-ref cap-closures name (set)))
                   (define inferred-str
                     (if (set-empty? inferred-caps)
                         "∅ (pure)"
                         (string-join (sort (map cap-entry->string (set->list inferred-caps)) string<?) ", ")))
                   ;; Overdeclared
                   (define overdeclared-str
                     (if (set-empty? overdeclared-set)
                         "none"
                         (string-join (sort (map cap-entry->string (set->list overdeclared-set)) string<?) ", ")))
                   (string-join
                    (list (format "cap-bridge ~a:" name)
                          (format "  Type: ~a" type-str)
                          (format "  Capabilities (from type): {~a}" type-caps-str)
                          (format "  Capabilities (inferred):  {~a}" inferred-str)
                          (format "  Overdeclared:             {~a}" overdeclared-str))
                    "\n")]

                  ;; Phase S3: Session type declaration
                  ;; Register the session name as a type in the global env
                  [(list 'session name sess-body)
                   ;; Install as a type-level binding (like capability/selection)
                   (current-global-env
                    (global-env-add-type-only (current-global-env) name (expr-Type 0)))
                   (when (current-ns-context)
                     (define fqn (qualify-name name
                                   (ns-context-current-ns (current-ns-context))))
                     (current-global-env
                      (global-env-add-type-only (current-global-env) fqn (expr-Type 0))))
                   (format "session ~a defined." name)]

                  ;; Phase S3+S5a: Process definition
                  ;; Type-check the process against its session type.
                  ;; S5a: Build gamma from capability bindings.
                  [(list 'defproc name sess-ty channels caps proc-body)
                   (cond
                     ;; If session type annotation present, look up or use directly
                     [sess-ty
                      ;; Look up session type from registry if it's a variable reference
                      (define sess-entry
                        (cond
                          [(expr-fvar? sess-ty)
                           (define entry (lookup-session (expr-fvar-name sess-ty)))
                           (and entry (session-entry-session-type entry))]
                          [else #f]))
                      (define resolved-sess (or sess-entry #f))
                      (cond
                        [resolved-sess
                         ;; Build channel context: self -> session type
                         (define delta (chan-ctx-add chan-ctx-empty 'self resolved-sess))
                         ;; S5a: Build gamma from capability bindings
                         ;; Each cap is (list name mult type-expr)
                         (define gamma-with-caps
                           (for/fold ([g ctx-empty]) ([cap (in-list caps)])
                             (ctx-extend g (third cap) (second cap))))
                         (define type-ok?
                           (time-phase! type-check (type-proc gamma-with-caps delta proc-body)))
                         (cond
                           [type-ok?
                            ;; S5c: Check for dead/ambient authority warnings
                            (when (pair? caps)
                              (check-process-cap-warnings name caps proc-body))
                            ;; Register in global env
                            (current-global-env
                             (global-env-add-type-only (current-global-env) name (expr-Type 0)))
                            (when (current-ns-context)
                              (define fqn (qualify-name name
                                            (ns-context-current-ns (current-ns-context))))
                              (current-global-env
                               (global-env-add-type-only (current-global-env) fqn (expr-Type 0))))
                            ;; S7c: Register in process registry for spawn
                            (register-process! name
                              (process-entry name resolved-sess proc-body caps srcloc-unknown))
                            (when (current-ns-context)
                              (define fqn (qualify-name name
                                            (ns-context-current-ns (current-ns-context))))
                              (register-process! fqn
                                (process-entry fqn resolved-sess proc-body caps srcloc-unknown)))
                            (format "defproc ~a : ~a type-checked." name (pp-session resolved-sess))]
                           [else
                            (prologos-error #f
                              (format "Process ~a does not implement session protocol ~a"
                                      name (pp-session resolved-sess)))])]
                        [else
                         ;; No resolved session — register without type-checking for now
                         (current-global-env
                          (global-env-add-type-only (current-global-env) name (expr-Type 0)))
                         ;; S7c: Register in process registry (no resolved session for execution)
                         (register-process! name
                           (process-entry name #f proc-body caps srcloc-unknown))
                         (format "defproc ~a defined (session type not resolved for checking)." name)])]
                     [else
                      ;; No session type annotation — just register
                      ;; S5c: Check for dead/ambient authority warnings
                      (when (pair? caps)
                        (check-process-cap-warnings name caps proc-body))
                      (current-global-env
                       (global-env-add-type-only (current-global-env) name (expr-Type 0)))
                      ;; S7c: Register in process registry (no session type for execution)
                      (register-process! name
                        (process-entry name #f proc-body caps srcloc-unknown))
                      (format "defproc ~a defined." name)])]

                  ;; Phase S3+S5a: Anonymous process — type-check if session type present
                  [(list 'proc sess-ty channels caps proc-body)
                   (cond
                     [sess-ty
                      ;; Look up session type
                      (define sess-entry
                        (cond
                          [(expr-fvar? sess-ty)
                           (define entry (lookup-session (expr-fvar-name sess-ty)))
                           (and entry (session-entry-session-type entry))]
                          [else #f]))
                      (define resolved-sess (or sess-entry #f))
                      (cond
                        [resolved-sess
                         (define delta (chan-ctx-add chan-ctx-empty 'self resolved-sess))
                         (define gamma-with-caps
                           (for/fold ([g ctx-empty]) ([cap (in-list caps)])
                             (ctx-extend g (third cap) (second cap))))
                         (define type-ok?
                           (time-phase! type-check (type-proc gamma-with-caps delta proc-body)))
                         (if type-ok?
                             (format "anonymous process : ~a type-checked." (pp-session resolved-sess))
                             (prologos-error #f
                               (format "Anonymous process does not implement session protocol ~a"
                                       (pp-session resolved-sess))))]
                        [else (format "anonymous process elaborated.")])]
                     [else (format "anonymous process elaborated.")])]

                  ;; Phase S3: dual — session duality result
                  [(list 'dual name dual-sess)
                   (format "dual ~a = ~a" name (pp-session dual-sess))]

                  ;; Phase S6: Strategy declaration
                  [(list 'strategy name props)
                   (format "strategy ~a defined." name)]

                  ;; Phase S7c: Spawn — execute a process
                  [(list 'spawn proc-name sess-ty proc-body caps)
                   (cond
                     [sess-ty
                      ;; Look up session type if it's a reference
                      (define resolved-sess
                        (cond
                          [(expr-fvar? sess-ty)
                           (define entry (lookup-session (expr-fvar-name sess-ty)))
                           (and entry (session-entry-session-type entry))]
                          [else sess-ty]))
                      (cond
                        [resolved-sess
                         (define result (rt-execute-process-auto proc-body resolved-sess))
                         (define status (rt-exec-result-status result))
                         (case status
                           [(ok)
                            (format "~aprocess~a executed. Protocol completed."
                                    (if proc-name (format "~a: " proc-name) "")
                                    (format " : ~a" (pp-session resolved-sess)))]
                           [(contradiction)
                            (prologos-error #f
                              (format "~aprocess execution failed: protocol violation (~a)"
                                      (if proc-name (format "~a " proc-name) "")
                                      (pp-session resolved-sess)))]
                           [else
                            (format "~aprocess execution: ~a"
                                    (if proc-name (format "~a: " proc-name) "")
                                    status)])]
                        [else
                         (prologos-error #f
                           (format "Cannot spawn ~a: session type not resolved"
                                   (or proc-name "anonymous process")))])]
                     [else
                      (prologos-error #f
                        (format "Cannot spawn ~a: no session type"
                                (or proc-name "anonymous process")))])]

                  ;; Phase S7d: Spawn-with — execute a process with strategy
                  [(list 'spawn-with proc-name sess-ty proc-body caps props)
                   (cond
                     [sess-ty
                      (define resolved-sess
                        (cond
                          [(expr-fvar? sess-ty)
                           (define entry (lookup-session (expr-fvar-name sess-ty)))
                           (and entry (session-entry-session-type entry))]
                          [else sess-ty]))
                      (cond
                        [resolved-sess
                         (define fuel (hash-ref props ':fuel 50000))
                         (define result (rt-execute-process-auto proc-body resolved-sess fuel))
                         (define status (rt-exec-result-status result))
                         (case status
                           [(ok)
                            (format "~aprocess~a executed. Protocol completed."
                                    (if proc-name (format "~a: " proc-name) "")
                                    (format " : ~a" (pp-session resolved-sess)))]
                           [(contradiction)
                            (prologos-error #f
                              (format "~aprocess execution failed: protocol violation (~a)"
                                      (if proc-name (format "~a " proc-name) "")
                                      (pp-session resolved-sess)))]
                           [else
                            (format "~aprocess execution: ~a"
                                    (if proc-name (format "~a: " proc-name) "")
                                    status)])]
                        [else
                         (prologos-error #f
                           (format "Cannot spawn ~a: session type not resolved"
                                   (or proc-name "anonymous process")))])]
                     [else
                      (prologos-error #f
                        (format "Cannot spawn ~a: no session type"
                                (or proc-name "anonymous process")))])]

                  [_ (prologos-error srcloc-unknown (format "Unknown command: ~a" elab-result))])))]))))
  ;; Append warnings to result string (if any)
  (define coercion-warns (reverse (current-coercion-warnings)))
  (define deprecation-warns (reverse (current-deprecation-warnings)))
  (define capability-warns (reverse (current-capability-warnings)))
  (define all-warning-strs
    (append (map format-coercion-warning coercion-warns)
            (map format-deprecation-warning deprecation-warns)
            (map (lambda (w)
                   (cond
                     [(process-cap-warning? w) (format-process-cap-warning w)]
                     [else (format-capability-warning w)]))
                 capability-warns)))
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
  ;; Phase 3b: Record dependencies during elaboration/type-checking.
  (parameterize ([current-elaborating-name name])
  (cond
    ;; Sprint 10: Type-inferred def (no type annotation)
    [(not type-surf)
     ;; IO-D5: If this is `main`, provision SysCap into capability scope.
     ;; main is the powerbox — it holds all authority implicitly.
     (define body (time-phase! elaborate
       (parameterize ([current-capability-scope
                       (if (eq? name 'main)
                           (cons (cons 0 (expr-fvar 'SysCap))
                                 (current-capability-scope))
                           (current-capability-scope))])
         (elaborate body-surf))))
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
              ;; HasMethod resolution: search-based, runs after type checking
              (resolve-hasmethod-constraints!)
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
        (define has-holes? (type-contains-hole? type))
        (define ty-ok (if (or has-holes? (type-contains-meta? type))
                          #t
                          (is-type/err ctx-empty type)))
        (cond
          [(prologos-error? ty-ok) ty-ok]
          [else
           ;; Replace holes with metas so they can be solved via unification
           (define type* (if has-holes? (holes-to-metas type) type))
           ;; GDE-1: Record user type annotation as ATMS context assumption.
           ;; This enables error messages like "because: user annotated x : Nat".
           (add-context-assumption!
            'def-type-annotation
            (format "~a : ~a" name (pp-expr type*)))
           ;; 3. Pre-register for recursive references
           (current-global-env
            (global-env-add-type-only (current-global-env) name type*))
           (when (current-ns-context)
             (define fqn (qualify-name name
                           (ns-context-current-ns (current-ns-context))))
             (current-global-env
              (global-env-add-type-only (current-global-env) fqn type*)))
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
              ;; IO-D5: If this is `main`, provision SysCap into capability scope.
              (define body (time-phase! elaborate
                (parameterize ([current-capability-scope
                                (if (eq? name 'main)
                                    (cons (cons 0 (expr-fvar 'SysCap))
                                          (current-capability-scope))
                                    (current-capability-scope))])
                  (elaborate body-surf))))
              (cond
                [(prologos-error? body)
                 ;; Remove pre-registered entry on elaboration failure
                 ;; Phase 3a: remove from both layers (per-file + legacy) for safety
                 (current-definition-cells-content (hash-remove (current-definition-cells-content) name))
                 (current-global-env (hash-remove (current-global-env) name))
                 (when (current-ns-context)
                   (define fail-fqn (qualify-name name (ns-context-current-ns (current-ns-context))))
                   (current-definition-cells-content (hash-remove (current-definition-cells-content) fail-fqn))
                   (current-global-env (hash-remove (current-global-env) fail-fqn)))
                 body]
                [else
                 ;; 5. Check body against type (use type* which has metas instead of holes)
                 ;; Sprint 9: pass recovered name map for de Bruijn recovery in errors
                 (define chk (time-phase! type-check (check/err ctx-empty body type* srcloc-unknown (recover-name-map))))
                 (cond
                   [(prologos-error? chk)
                    ;; Remove pre-registered entry on type-check failure
                    ;; Phase 3a: remove from both layers
                    (current-definition-cells-content (hash-remove (current-definition-cells-content) name))
                    (current-global-env (hash-remove (current-global-env) name))
                    (when (current-ns-context)
                      (define chk-fqn (qualify-name name (ns-context-current-ns (current-ns-context))))
                      (current-definition-cells-content (hash-remove (current-definition-cells-content) chk-fqn))
                      (current-global-env (hash-remove (current-global-env) chk-fqn)))
                    chk]
                   [else
                    ;; Phase C: resolve trait-constraint metas to dictionary expressions
                    ;; Trait resolution: handled by propagator cell-path in solve-meta!
                    ;; HasMethod resolution: search-based, runs after type checking
                    (resolve-hasmethod-constraints!)
                    ;; Phase C.6: Check for unresolved trait constraints
                    (define trait-errors-ann (check-unresolved-trait-constraints))
                    ;; Phase 4: Check for unresolved capability constraints
                    (define cap-errors-ann (check-unresolved-capability-constraints))
                    (cond
                      [(not (null? trait-errors-ann))
                       ;; Phase 3a: remove from both layers
                       (current-definition-cells-content (hash-remove (current-definition-cells-content) name))
                       (current-global-env (hash-remove (current-global-env) name))
                       (when (current-ns-context)
                         (define te-fqn (qualify-name name (ns-context-current-ns (current-ns-context))))
                         (current-definition-cells-content (hash-remove (current-definition-cells-content) te-fqn))
                         (current-global-env (hash-remove (current-global-env) te-fqn)))
                       (car trait-errors-ann)]
                      [(not (null? cap-errors-ann))
                       ;; Phase 3a: remove from both layers
                       (current-definition-cells-content (hash-remove (current-definition-cells-content) name))
                       (current-global-env (hash-remove (current-global-env) name))
                       (when (current-ns-context)
                         (define ce-fqn (qualify-name name (ns-context-current-ns (current-ns-context))))
                         (current-definition-cells-content (hash-remove (current-definition-cells-content) ce-fqn))
                         (current-global-env (hash-remove (current-global-env) ce-fqn)))
                       (car cap-errors-ann)]
                      [else
                    ;; 5.5. Check for failed constraints (Sprint 5)
                    (define failed (all-failed-constraints))
                    (cond
                      [(not (null? failed))
                       ;; Remove pre-registered entry on constraint failure
                       ;; Phase 3a: remove from both layers
                       (current-definition-cells-content (hash-remove (current-definition-cells-content) name))
                       (current-global-env (hash-remove (current-global-env) name))
                       (when (current-ns-context)
                         (define cf-fqn (qualify-name name (ns-context-current-ns (current-ns-context))))
                         (current-definition-cells-content (hash-remove (current-definition-cells-content) cf-fqn))
                         (current-global-env (hash-remove (current-global-env) cf-fqn)))
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
                       ;; Convert any unsolved metas back to holes (prevents dangling refs).
                       (define zonked-body (rewrite-specializations (time-phase! zonk (zonk-final body))))
                       (define zonked-type-raw (time-phase! zonk (zonk-final type*)))
                       (define zonked-type (if has-holes? (unsolved-metas-to-holes zonked-type-raw) zonked-type-raw))
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
                          ;; Phase 3a: remove from both layers
                          (current-definition-cells-content (hash-remove (current-definition-cells-content) name))
                          (current-global-env (hash-remove (current-global-env) name))
                          (when (current-ns-context)
                            (define qtt-fqn (qualify-name name (ns-context-current-ns (current-ns-context))))
                            (current-definition-cells-content (hash-remove (current-definition-cells-content) qtt-fqn))
                            (current-global-env (hash-remove (current-global-env) qtt-fqn)))
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
                      )])])])])])])])))  ;; extra ) closes Phase 3b parameterize

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
      (register-macros-cells! (current-prop-net-box) (current-prop-new-infra-cell))
      (register-warning-cells! (current-prop-net-box) (current-prop-new-infra-cell))
      (register-global-env-cells! (current-prop-net-box) (current-prop-new-infra-cell))
      (init-speculation-tracking!)
      (parameterize ([current-global-env-prop-net-box (current-prop-net-box)])
        (process-def def))))
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
;; Post-Compilation Capability Inference (IO-H)
;; ========================================
;;
;; After all definitions in a module/REPL batch are processed, run capability
;; inference and raise an error for authority roots whose declarations don't
;; cover their inferred closures.
;;
;; Fast path: skips if no capability types have been registered (most programs).
;;
;; SECURITY INVARIANT: An underdeclared transitive capability is a security
;; violation — it means a function has authority it didn't declare. This MUST
;; be a hard error, never a warning. The whole point of capability-secure
;; design is that authority is explicit; silent leaks defeat the purpose.

(define (run-post-compilation-inference!)
  ;; Fast path: skip if no capability types exist
  (when (not (hash-empty? (current-capability-registry)))
    (define result (run-capability-inference))
    (current-module-cap-result result)
    ;; Check all entries in the global env for authority roots.
    ;; An authority root is a function whose type declares capability requirements
    ;; (i.e., has :0 binders with capability-type domains).
    (define closures (cap-inference-result-closures result))
    (define violations '())  ;; accumulate all violations before erroring
    (for ([(name entry) (in-hash (global-env-snapshot))])
      (when (and (pair? entry) (car entry))
        (define declared-caps (extract-capability-requirements (car entry)))
        (when (not (set-empty? declared-caps))
          ;; This is an authority root — verify that declared caps subsume closure
          ;; Both declared-caps and closure are sets of cap-entry
          (define closure (hash-ref closures name (set)))
          ;; Find capabilities in closure NOT covered by any declared cap
          (define missing
            (for/set ([cap (in-set closure)]
                      #:unless (for/or ([dcap (in-set declared-caps)])
                                 (cap-entry-covers? dcap cap)))
              cap))
          (unless (set-empty? missing)
            (set! violations
                  (cons (cons name missing) violations))))))
    ;; Raise a single error listing all violations
    (unless (null? violations)
      (define msgs
        (for/list ([v (in-list (sort violations
                                     string<?
                                     #:key (lambda (p) (symbol->string (car p)))))])
          (define name (car v))
          (define missing (cdr v))
          (format "  `~a` requires undeclared: {~a}"
                  name
                  (string-join
                   (sort (map cap-entry->string (set->list missing)) string<?)
                   ", "))))
      (error 'capability-check
             "E2004: capability security violation — authority roots with undeclared transitive capabilities:\n~a"
             (string-join msgs "\n")))))

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
  ;; Emit formatted error diagnostics to stderr when enabled (test runner integration)
  (when (current-emit-error-diagnostics)
    (for ([r (in-list results)])
      (when (prologos-error? r)
        (emit-error-diagnostic r))))
  ;; IO-H: Run capability inference after all definitions are processed
  (run-post-compilation-inference!)
  (when pc (print-perf-report! pc))
  (print-phase-report! pt)
  (print-provenance-report! pv)
  (print-memory-report! (measure-memory-after mem-before))
  results)

;; ========================================
;; Process all commands from a WS-mode string
;; ========================================
;; Like process-string, but uses the WS reader (indentation-sensitive).
;; This is the path that .prologos files use — the primary design target.
(define (process-string-ws s)
  (define port (open-input-string s))
  ;; Use WS reader (indentation -> nested lists)
  (define raw-stxs (read-all-syntax-ws port "<ws-string>"))
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
  ;; Emit formatted error diagnostics to stderr when enabled (test runner integration)
  (when (current-emit-error-diagnostics)
    (for ([r (in-list results)])
      (when (prologos-error? r)
        (emit-error-diagnostic r))))
  ;; IO-H: Run capability inference after all definitions are processed
  (run-post-compilation-inference!)
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
  ;; Emit formatted error diagnostics to stderr when enabled (test runner integration)
  (when (current-emit-error-diagnostics)
    (for ([r (in-list results)])
      (when (prologos-error? r)
        (emit-error-diagnostic r))))
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
                    ;; Phase 3a: Module loading uses legacy hasheq path.
                    ;; Set prop-net-box to #f so global-env-add writes to
                    ;; current-global-env (Layer 2), not definition-cells (Layer 1).
                    [current-global-env-prop-net-box #f]
                    [current-definition-cells-content (hasheq)]
                    [current-definition-cell-ids (hasheq)]
                    [current-definition-dependencies (hasheq)]  ;; Phase 3b
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

       ;; IO-H: Run capability inference after module definitions are processed
       (run-post-compilation-inference!)

       ;; Capture the resulting environment, namespace context, and registries.
       ;; Use global-env-snapshot to merge both layers: per-definition cells
       ;; (Layer 1) and legacy hasheq (Layer 2). During module loading,
       ;; reset-meta-store! may create a prop-net despite parameterize setting
       ;; current-prop-net-box to #f, so some definitions may end up in Layer 1.
       (set! mod-env (global-env-snapshot))
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
          ;; Phase 2c: dual-write spec-store to cell
          (macros-cell-write! (current-spec-store-cell-id) (hasheq name spec-entry))
          ;; Mark as propagated so own-module defs can override silently
          (current-propagated-specs
            (set-add (current-propagated-specs) name))
          ;; Phase 2c: dual-write propagated-specs to cell (set merge)
          (macros-cell-write! (current-propagated-specs-cell-id) (seteq name))))))
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
  (register-macros-cells! (current-prop-net-box) (current-prop-new-infra-cell))
  (register-warning-cells! (current-prop-net-box) (current-prop-new-infra-cell))
  (register-global-env-cells! (current-prop-net-box) (current-prop-new-infra-cell))
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
  ;; For .rkt file paths, resolve relative to the prologos source directory.
  ;; For collection paths like "racket/base", convert to symbol.
  (define rkt-mod-path
    (if (regexp-match? #rx"\\.rkt$" module-path-str)
        (simplify-path (build-path prologos-lib-dir ".." module-path-str))
        (string->symbol module-path-str)))
  (define rkt-proc
    (with-handlers ([exn:fail? (lambda (e)
                                 (error 'foreign "Cannot import ~a from ~a: ~a"
                                        racket-name module-path-str (exn-message e)))])
      (dynamic-require rkt-mod-path racket-name)))

  ;; Parse type to get marshalling info — use the original type (without capability Pi binders)
  ;; because marshalling only applies to the runtime argument types, not erased capabilities
  (define parsed-type (parse-foreign-type zonked-type))
  (define-values (marshal-in marshal-out) (make-marshaller-pair parsed-type))
  (define base-arity (length (car parsed-type)))

  ;; IO-D5: Account for erased capability arguments in the foreign function.
  ;; The elaborator inserts :0 cap proofs as leading arguments. At runtime,
  ;; these erased args are passed through but must be dropped before calling
  ;; the actual Racket function. We increase the arity to include cap args,
  ;; add identity marshallers for them, and wrap the proc to drop them.
  (define n-caps (length foreign-caps))
  (define full-arity (+ base-arity n-caps))
  (define full-marshal-in
    (if (zero? n-caps)
        marshal-in
        (append (make-list n-caps (lambda (x) x))  ;; identity for erased cap proofs
                marshal-in)))
  (define effective-proc
    (if (zero? n-caps)
        rkt-proc
        (lambda args
          (apply rkt-proc (drop args n-caps)))))

  ;; Build the foreign-fn value with the Prologos name
  (define val (expr-foreign-fn prologos-name effective-proc full-arity '() full-marshal-in marshal-out))

  ;; Register in global env with full type (including capability Pi binders)
  (current-global-env
   (global-env-add (current-global-env) prologos-name full-type val))

  ;; Also register FQN if in a namespace
  (when (current-ns-context)
    (define fqn (qualify-name prologos-name (ns-context-current-ns (current-ns-context))))
    (current-global-env
     (global-env-add (current-global-env) fqn full-type val))
    ;; Auto-export the foreign binding (must update current-ns-context —
    ;; ns-context-add-auto-export returns a new struct, does not mutate)
    (current-ns-context
     (ns-context-add-auto-export (current-ns-context) prologos-name))))

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

;; Phase 1a: Install infrastructure cell creation callback.
(current-prop-new-infra-cell elab-new-infra-cell)

;; Phase 2a: Install macros cell-write callback (constant — doesn't depend on net-box).
;; net-box is installed per-command via register-macros-cells!, since it's created
;; fresh in reset-meta-store!.
(current-macros-prop-cell-write elab-cell-write)

;; Phase 2c: Install warnings cell-write callback.
(current-warnings-prop-cell-write elab-cell-write)

;; Phase 3a: Install global-env cell callbacks.
(current-global-env-prop-cell-write elab-cell-write)
(current-global-env-prop-new-cell elab-new-infra-cell)

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

;; Phase 4c: Install structural decomposition meta-lookup callback.
;; When a compound type is decomposed into sub-cells, bare metas (expr-meta id)
;; should reuse the meta's existing propagator cell. This callback maps
;; (expr-meta id) → cell-id, enabling sub-cell propagation to solve metas.
(current-structural-meta-lookup
 (lambda (e)
   (and (expr-meta? e)
        (prop-meta-id->cell-id (expr-meta-id e)))))

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

;; Phase 1d: Install incremental hasmethod resolution callback.
;; When a dependency meta (type-arg or trait-var) is solved, this callback checks
;; if the hasmethod constraint becomes resolvable and if so, resolves it immediately.
;; This makes hasmethod resolution reactive — no need for explicit batch pass.
(install-hasmethod-resolve-callback!
 (lambda (meta-id hm-info)
   ;; Guard: skip if already solved (prevents re-entrant double-solve).
   ;; Re-entrancy can happen: solving dict-meta → solve-meta! → retry-hasmethod →
   ;; re-enters this callback → solves meta-id → outer call must not re-solve.
   (unless (meta-solved? meta-id)
     (define method-name (hasmethod-constraint-info-method-name hm-info))
     (define type-args
       (map (lambda (e) (normalize-for-resolution (zonk e)))
            (hasmethod-constraint-info-type-arg-exprs hm-info)))
     (when (andmap ground-expr? type-args)
       ;; Strategy 1: P (trait var) is already ground
       (define trait-expr (zonk (hasmethod-constraint-info-trait-var-expr hm-info)))
       (define known-trait-name (and (ground-expr? trait-expr) (trait-expr->name trait-expr)))
       ;; Strategy 2: P is not ground — search all traits for the method name
       (define resolved-trait-name
         (or known-trait-name
             (find-trait-with-method method-name type-args)))
       (when resolved-trait-name
         (define tm (lookup-trait resolved-trait-name))
         (when tm
           (define methods (trait-meta-methods tm))
           (define method-idx
             (for/or ([m (in-list methods)] [i (in-naturals)])
               (and (eq? (trait-method-name m) method-name) i)))
           (when method-idx
             ;; Resolve the dict via standard impl resolution
             (define dict-expr
               (or (try-monomorphic-resolve resolved-trait-name type-args)
                   (try-parametric-resolve resolved-trait-name type-args)))
             (when dict-expr
               ;; Solve the trait variable P if it's still a meta
               (define trait-var-expr (hasmethod-constraint-info-trait-var-expr hm-info))
               (when (and (expr-meta? trait-var-expr)
                          (not (meta-solved? (expr-meta-id trait-var-expr))))
                 (solve-meta! (expr-meta-id trait-var-expr) (expr-fvar resolved-trait-name)))
               ;; Optionally solve the dict meta if present
               (define dict-meta-id (hasmethod-constraint-info-dict-meta-id hm-info))
               (when (and dict-meta-id (not (meta-solved? dict-meta-id)))
                 (solve-meta! dict-meta-id dict-expr))
               ;; Project the method and solve the evidence meta.
               ;; Re-check: meta-id may have been solved by re-entrant resolution above.
               (unless (meta-solved? meta-id)
                 (define projected (project-method dict-expr tm method-idx))
                 (solve-meta! meta-id projected))))))))))

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
