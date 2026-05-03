#lang racket/base

;;;
;;; preduce.rkt — PReduce-lite, the propagator-network-based reducer
;;;
;;; PM Track 9 first concrete realization. Translates an elaborated
;;; Prologos AST into a propagator network whose run-to-quiescence
;;; produces the WHNF of the input expression.
;;;
;;; Design priority order (load-bearing, see design doc § 1):
;;;   1. Correctness  — produce results equal? to nf for every supported node
;;;   2. Simplicity   — eager optimization explicitly out of scope
;;;   3. Performance  — not a goal of PReduce-lite; full Track 9 closes the gap
;;;
;;; "Lite" means: no incrementality, no e-graph merges, no equality
;;; saturation, no speculative reduction, no tropical-quantale fuel.
;;; The cell-value lattice is the simplest possible (discrete with bot);
;;; each cell is written once.
;;;
;;; Phased rollout: 16 phases covering the full reducer surface.
;;;   Phase 1 (THIS): skeleton — lattice, domain registration, parameters,
;;;                   error type, compile-expr dispatcher, opaque-value
;;;                   rule for type-formers, top-level entry points.
;;;                   No reduction-active AST cases yet.
;;;   Phase 2+:       reduction cases land per the design doc's tracker.
;;;
;;; Out-of-scope nodes raise exn:fail:preduce-unsupported (hard error,
;;; per the correctness-favoring policy in design doc § 3 + § 8.5).
;;; The diagnostic `(preduce-or-nf e)` helper catches and dispatches
;;; to nf for exploratory REPL use only — never wired into typing-core.
;;;
;;; Cross-references:
;;;   - docs/tracking/2026-05-02_PREDUCE_LITE_DESIGN.md (this design)
;;;   - docs/tracking/2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md (origin)
;;;   - racket/prologos/reduction.rkt (the existing tree-walker we eventually replace)
;;;

(require racket/match
         "syntax.rkt"
         (only-in "propagator.rkt"
                  make-prop-network
                  net-new-cell
                  net-cell-read
                  net-cell-write
                  net-add-propagator
                  net-add-fire-once-propagator
                  run-to-quiescence
                  current-bsp-fire-round?)
         (only-in "sre-core.rkt" make-sre-domain register-domain!)
         (only-in "merge-fn-registry.rkt" register-merge-fn!/lattice)
         (only-in "reduction.rkt" nf)  ;; for preduce-or-nf diagnostic helper
         (only-in "global-env.rkt" global-env-lookup-value))

(provide
 ;; Entry points
 preduce
 preduce-or-nf

 ;; Parameters
 current-use-preduce?
 current-preduce-fuel

 ;; Errors
 (struct-out exn:fail:preduce-unsupported)
 preduce-unsupported-node-error?

 ;; Lattice
 preduce-bot
 preduce-top
 preduce-bot?
 preduce-top?
 preduce-merge

 ;; Domain (for cross-module references in tests)
 preduce-value-domain)

;; ============================================================
;; Discrete value lattice
;; ============================================================
;;
;; Lattice: ⊥  →  any value (incomparable)  →  ⊤
;; Merge:   first write sets the value; subsequent equal writes are
;;          idempotent; subsequent unequal writes produce ⊤
;;          (contradiction — indicates a bug or non-deterministic input).
;; Bot:     'preduce-bot — sentinel for "cell not yet computed."
;; Top:     'preduce-top — sentinel for "contradiction."
;;
;; This is the simplest valid join-semilattice for the use case:
;; deterministic reduction means every cell is written at most once,
;; so the lattice is essentially "uninitialized memory that, once set,
;; stays." The e-graph generalization (full Track 9) replaces this
;; with a richer lattice supporting equivalence merges.

(define preduce-bot 'preduce-bot)
(define preduce-top 'preduce-top)

(define (preduce-bot? v) (eq? v preduce-bot))
(define (preduce-top? v) (eq? v preduce-top))

(define (preduce-merge a b)
  (cond
    [(eq? a preduce-bot) b]
    [(eq? b preduce-bot) a]
    [(eq? a preduce-top) preduce-top]
    [(eq? b preduce-top) preduce-top]
    [(equal? a b) a]
    [else preduce-top]))

;; ============================================================
;; SRE domain registration
;; ============================================================

(define preduce-value-domain
  (make-sre-domain
   #:name 'preduce-value
   #:merge-registry (lambda (r)
                      (case r
                        [(equality) preduce-merge]
                        [else (error 'preduce-value-merge
                                     "no merge for relation: ~a" r)]))
   #:contradicts? preduce-top?
   #:bot? preduce-bot?
   #:bot-value preduce-bot
   #:classification 'value))

(register-domain! preduce-value-domain)
(register-merge-fn!/lattice preduce-merge #:for-domain 'preduce-value)

;; ============================================================
;; Parameters
;; ============================================================

;; Default #f: the existing nf path is unchanged. Phase 16 flips this
;; to #t after the full-coverage differential gate (Phase 15) passes.
(define current-use-preduce? (make-parameter #f))

;; Imperative fuel counter (named scaffolding; tropical-lattice fuel
;; per PPN 4C M2 is the v2 retirement target). Bounds the number of
;; topology operations / propagator firings before bailing out.
(define current-preduce-fuel (make-parameter 1000000))

;; ============================================================
;; Error type
;; ============================================================

(struct exn:fail:preduce-unsupported exn:fail (node-kind phase)
  #:extra-constructor-name make-preduce-unsupported
  #:transparent)

(define (preduce-unsupported-node-error? v)
  (exn:fail:preduce-unsupported? v))

(define (raise-unsupported! node-kind phase msg)
  (raise (make-preduce-unsupported
          msg
          (current-continuation-marks)
          node-kind phase)))

(define (expr-kind e)
  ;; struct->vector on (expr-int 5) returns #(struct:expr-int 5),
  ;; so the first element is the symbol 'struct:expr-int. Strip the
  ;; "struct:" prefix for a clean error-message identifier.
  (cond
    [(struct? e)
     (define v (struct->vector e))
     (define tag (vector-ref v 0))
     (define s (symbol->string tag))
     (if (regexp-match? #rx"^struct:" s)
         (string->symbol (substring s 7))
         tag)]
    [else 'non-struct]))

;; ============================================================
;; compile-expr — translation
;; ============================================================
;;
;; compile-expr : expr × env × net → (values cell-id net)
;;
;; env : (Listof cell-id), innermost-first per de Bruijn convention.
;;       (expr-bvar 0) reads (list-ref env 0); the outermost binder
;;       has the highest bvar index.
;;
;; net : the prop-network being built (immutable; threaded through).
;;
;; Returns: (values result-cid net') — result-cid's value (after
;;          run-to-quiescence) is the WHNF of expr.
;;
;; Phase 1: handles only the opaque-value rule (type formers and
;; nullary type atoms held as values). All other nodes raise
;; exn:fail:preduce-unsupported.

(define (compile-expr e env net)
  (match e
    ;; ----- Phase 1 opaque-value rule -----
    ;;
    ;; Type formers and nullary type atoms reduce to themselves. We
    ;; allocate a cell whose initial value IS the AST node, no
    ;; propagator needed. Subsequent reads find the value already in
    ;; place at WHNF.
    [(or (? expr-Pi?) (? expr-Sigma?) (? expr-Type?)
         (? expr-Vec?) (? expr-Eq?) (? expr-Fin?)
         (? expr-Nat?) (? expr-Int?) (? expr-Rat?)
         (? expr-Bool?) (? expr-String?) (? expr-Char?)
         (? expr-Keyword?) (? expr-Symbol?) (? expr-Path?)
         (? expr-Unit?) (? expr-Nil?))
     (alloc-value-cell net e)]

    ;; ----- Phase 2 literals -----
    [(? expr-int?)     (alloc-value-cell net e)]
    [(? expr-true?)    (alloc-value-cell net e)]
    [(? expr-false?)   (alloc-value-cell net e)]
    [(? expr-nat-val?) (alloc-value-cell net e)]
    [(? expr-zero?)    (alloc-value-cell net e)]

    ;; ----- Phase 2: annotation erasure -----
    ;; (expr-ann e _) reduces by erasing the type annotation.
    [(expr-ann inner _)
     (compile-expr inner env net)]

    ;; ----- Phase 2: bound variable -----
    ;; bvars resolve to their binder's cell-id. The binder will be
    ;; introduced by Phase 3+ (lambdas); in Phase 2 a bvar in a
    ;; well-formed program never appears at the top level, but the
    ;; case is here so future phases compose without re-touching this
    ;; dispatch. Out-of-range bvars indicate either an ill-formed
    ;; AST or a phase-coverage gap.
    [(expr-bvar i)
     (when (or (< i 0) (>= i (length env)))
       (error 'preduce
              "expr-bvar ~a out of range (env depth ~a) — likely a free variable in a top-level expression"
              i (length env)))
     (values (list-ref env i) net)]

    ;; ----- Phase 2: int arithmetic -----
    ;;
    ;; Each binary int op compiles its two operands, allocates a result
    ;; cell, and installs a fire-once propagator. The propagator reads
    ;; both inputs, performs Nat→Int coercion if needed (mirrors
    ;; reduction.rkt's reduce-int-binary at line ~999), and writes
    ;; the result. Comparisons produce Bool; arithmetic produces Int.
    [(expr-int-add a b) (compile-int-binary net env e a b int-add-fire)]
    [(expr-int-sub a b) (compile-int-binary net env e a b int-sub-fire)]
    [(expr-int-mul a b) (compile-int-binary net env e a b int-mul-fire)]
    [(expr-int-div a b) (compile-int-binary net env e a b int-div-fire)]
    [(expr-int-mod a b) (compile-int-binary net env e a b int-mod-fire)]
    [(expr-int-eq  a b) (compile-int-binary net env e a b int-eq-fire)]
    [(expr-int-lt  a b) (compile-int-binary net env e a b int-lt-fire)]
    [(expr-int-le  a b) (compile-int-binary net env e a b int-le-fire)]

    ;; ----- Phase 2: expr-suc — successor on Nat -----
    ;;
    ;; Reduces to the next nat-val if the inner is concrete; otherwise
    ;; stays as (expr-suc inner-value). Native nat-val collapse mirrors
    ;; reduction.rkt:1436.
    [(expr-suc inner)
     (define-values (cid-in net1) (compile-expr inner env net))
     (define-values (net2 cid-out)
       (net-new-cell net1 preduce-bot preduce-merge #:domain 'preduce-value))
     (define fire-fn (make-suc-fire cid-in cid-out))
     (define-values (net3 _)
       (net-add-fire-once-propagator net2 (list cid-in) (list cid-out) fire-fn))
     (values cid-out net3)]

    ;; ----- Phase 2: pair construction + projections -----
    ;;
    ;; Pair construction allocates a cell whose value is a tagged
    ;; tuple carrying the cell-ids of the two components. The pair
    ;; "value" never needs further reduction; its components are at
    ;; cells fst-cid / snd-cid which reduce independently.
    ;;
    ;; Projection at compile-expr time KNOWS the component cell-ids
    ;; (we just compiled them), so fst returns fst-cid directly and
    ;; snd returns snd-cid. No propagator needed — the data flow is
    ;; resolved structurally at compile time. (Pairs read through
    ;; bvars / dynamic dispatch are deferred to Phase 3+ when β
    ;; lands and bvars can carry pair-typed values.)
    [(expr-pair a b)
     (define-values (cid-a net1) (compile-expr a env net))
     (define-values (cid-b net2) (compile-expr b env net1))
     (alloc-value-cell net2 (preduce-pair cid-a cid-b))]

    [(expr-fst inner)
     ;; If inner is statically a pair construction, return fst directly.
     (cond
       [(expr-pair? inner)
        (compile-expr (expr-pair-fst inner) env net)]
       [(expr-ann? inner)
        ;; Erase ann and retry.
        (compile-expr (expr-fst (expr-ann-term inner)) env net)]
       [else
        ;; Compile inner; install fire-once propagator that reads the
        ;; pair-value from cid-in and forwards the fst component's
        ;; current value to cid-out. Required for pairs that come
        ;; through bvars / dynamic dispatch (Phase 3+).
        (define-values (cid-in net1) (compile-expr inner env net))
        (define-values (net2 cid-out)
          (net-new-cell net1 preduce-bot preduce-merge #:domain 'preduce-value))
        (define-values (net3 _)
          (net-add-fire-once-propagator net2 (list cid-in) (list cid-out)
                                        (make-projection-fire cid-in cid-out 'fst)))
        (values cid-out net3)])]

    [(expr-snd inner)
     (cond
       [(expr-pair? inner)
        (compile-expr (expr-pair-snd inner) env net)]
       [(expr-ann? inner)
        (compile-expr (expr-snd (expr-ann-term inner)) env net)]
       [else
        (define-values (cid-in net1) (compile-expr inner env net))
        (define-values (net2 cid-out)
          (net-new-cell net1 preduce-bot preduce-merge #:domain 'preduce-value))
        (define-values (net3 _)
          (net-add-fire-once-propagator net2 (list cid-in) (list cid-out)
                                        (make-projection-fire cid-in cid-out 'snd)))
        (values cid-out net3)])]

    ;; ----- Phase 3: lambda as value -----
    ;;
    ;; The lambda allocates a cell whose value is a preduce-lam tagged
    ;; struct carrying the body AST and the captured env (the cid list
    ;; at compilation point — the lambda closes over surrounding scope).
    ;; The body is NOT compiled here; it's compiled when the lambda is
    ;; applied (β-reduction). For first-class lambda values that are
    ;; never applied (passed as args, stored, etc.), the cell holds
    ;; the lambda value as-is.
    [(expr-lam mw type body)
     (alloc-value-cell net (preduce-lam mw type body env))]

    ;; ----- Phase 3: free variable (fvar) — inline the def -----
    ;;
    ;; Look up name in the global env. The def's value AST is compiled
    ;; in EMPTY env (top-level definitions don't see surrounding bvars).
    ;; Recursion detection via current-fvar-stack: if name is already
    ;; being compiled, raise unsupported (recursion is Phase 4 — needs
    ;; topology stratum to break the compile-time loop).
    [(expr-fvar name)
     (when (memq name (current-fvar-stack))
       (raise-unsupported!
        'expr-fvar 'phase-4-recursive-fvar
        (format "PReduce-lite Phase 3: recursive fvar ~a — recursion needs \
the topology stratum (Phase 4)" name)))
     (define value-ast (global-env-lookup-value name))
     (unless value-ast
       (error 'preduce "expr-fvar ~a not found in global env" name))
     (parameterize ([current-fvar-stack (cons name (current-fvar-stack))])
       (compile-expr value-ast '() net))]

    ;; ----- Phase 3: application — static β only -----
    ;;
    ;; Three patterns for the function position, all resolved STATICALLY
    ;; at compile-expr time:
    ;;   (a) (expr-app (expr-lam _ _ body) arg) → static β: compile arg,
    ;;       compile body in env extended with arg's cid.
    ;;   (b) (expr-app (expr-fvar name) arg) → unfold fvar to its value
    ;;       AST, then dispatch as (a) if it's a lambda. (Recursion is
    ;;       guarded; mutual / self recursion → Phase 4.)
    ;;   (c) (expr-app (expr-ann inner _) arg) → erase ann, retry.
    ;; All other shapes (e.g., the function position is itself an
    ;; application chain that doesn't statically reduce to a lambda)
    ;; raise unsupported and route to Phase 4 (dynamic β via topology).
    [(expr-app f arg)
     (define f-static (statically-reducible-lam f))
     (cond
       [f-static
        ;; Static β (Phase 3): compile arg, then body in extended env.
        (define-values (cid-arg net1) (compile-expr arg env net))
        (compile-expr (expr-lam-body f-static) (cons cid-arg env) net1)]
       [else
        ;; ----- Phase 4: dynamic β -----
        ;; The function position is not statically a lambda. Compile both
        ;; sides; install a fire-once propagator on the function-position
        ;; cell. When the function value is concrete (a preduce-lam), the
        ;; propagator compiles the body in the appropriate env (captured
        ;; env extended with arg-cid) and threads the result via an
        ;; identity propagator to cid-out.
        ;;
        ;; The body compilation happens INSIDE the fire-fn but is wrapped
        ;; in (parameterize ([current-bsp-fire-round? #f]) ...) so the
        ;; new propagators auto-schedule on the worklist for next round
        ;; (otherwise net-add-propagator's scheduling logic skips during
        ;; fire — see propagator.rkt:1513-1515). This sidesteps needing
        ;; a separate preduce-topology cell + handler at the cost of
        ;; brief BSP-discipline circumvention; the new propagators ARE
        ;; only fired in the NEXT round (after this round's writes
        ;; merge), so the discipline is preserved at the BSP level.
        (define-values (cid-f net1) (compile-expr f env net))
        (define-values (cid-arg net2) (compile-expr arg env net1))
        (define-values (net3 cid-out)
          (net-new-cell net2 preduce-bot preduce-merge #:domain 'preduce-value))
        (define-values (net4 _)
          (net-add-fire-once-propagator net3 (list cid-f) (list cid-out)
                                        (make-app-fire cid-f cid-arg cid-out)))
        (values cid-out net4)])]

    ;; ----- All other nodes: deferred to later phases -----
    [_
     (raise-unsupported!
      (expr-kind e)
      'phase-4-or-later
      (format "PReduce-lite Phase 3: AST node ~a is not yet supported. \
Programs using this node should run via the existing nf reducer until \
the relevant phase lands."
              (expr-kind e)))]))

;; ============================================================
;; Phase 3 helpers
;; ============================================================

;; preduce-lam — first-class lambda value carried in cells.
(struct preduce-lam (mult type body captured-env) #:transparent)

;; current-fvar-stack — names of fvars currently being compiled.
;; Used to detect recursive fvar references and route them to Phase 4.
(define current-fvar-stack (make-parameter '()))

;; statically-reducible-lam : expr → expr-lam | #f
;;   Returns the underlying lambda AST if `f` is statically a lambda
;;   (literal lam, ann-wrapped lam, fvar to a lam-bodied def). Otherwise
;;   #f. Used by static-β dispatch in expr-app.
;;
;;   Recursion guard: an fvar whose name is already on the fvar stack
;;   returns #f (cannot statically inline; routes to Phase 4).
(define (statically-reducible-lam f)
  (cond
    [(expr-lam? f) f]
    [(expr-ann? f) (statically-reducible-lam (expr-ann-term f))]
    [(expr-fvar? f)
     (define name (expr-fvar-name f))
     (cond
       [(memq name (current-fvar-stack)) #f]  ;; recursion — Phase 4
       [else
        (define v (global-env-lookup-value name))
        (cond
          [(and v (statically-reducible-lam-no-fvar-cycle v name)) => values]
          [else #f])])]
    [else #f]))

;; Helper: like statically-reducible-lam but pushes name onto the stack
;; for cycle detection during recursive descent.
(define (statically-reducible-lam-no-fvar-cycle v name)
  (parameterize ([current-fvar-stack (cons name (current-fvar-stack))])
    (statically-reducible-lam v)))

;; ============================================================
;; Phase 4 helpers — dynamic β
;; ============================================================

;; make-app-fire — fire-once propagator for dynamic β.
;;
;; Triggers when cid-f resolves. Reads the function value; if it's a
;; preduce-lam, compiles the body in (cons cid-arg captured-env) and
;; installs an identity propagator from body-result-cid to cid-out.
;;
;; The body compilation is wrapped to disable the BSP-fire-round flag,
;; allowing newly-installed propagators to auto-schedule (see comment
;; in expr-app dispatch above). This is correctness-preserving: the
;; new propagators don't fire in the CURRENT round (the network update
;; is returned as the fire-fn result and merged at round end), they
;; fire in the NEXT round once their input cells have values.
(define (make-app-fire cid-f cid-arg cid-out)
  (lambda (net)
    (define f-val (net-cell-read net cid-f))
    (cond
      [(preduce-bot? f-val) net]
      [(preduce-lam? f-val)
       (define body (preduce-lam-body f-val))
       (define captured-env (preduce-lam-captured-env f-val))
       (define new-env (cons cid-arg captured-env))
       (define-values (cid-body net1)
         (parameterize ([current-bsp-fire-round? #f])
           (compile-expr body new-env net)))
       ;; Bridge the body's result cell to the application's result cell
       ;; via an identity propagator.
       (define-values (net2 _)
         (parameterize ([current-bsp-fire-round? #f])
           (net-add-fire-once-propagator
            net1 (list cid-body) (list cid-out)
            (make-identity-fire cid-body cid-out))))
       net2]
      [else
       (error 'preduce
              "expected lambda value at app function position, got: ~v" f-val)])))

;; make-identity-fire — forwards a value from cid-in to cid-out when
;; cid-in resolves. Used to bridge body-result cells to application-
;; result cells in dynamic β.
(define (make-identity-fire cid-in cid-out)
  (lambda (net)
    (define v (net-cell-read net cid-in))
    (if (preduce-bot? v) net
        (net-cell-write net cid-out v))))

;; ============================================================
;; Phase 2 helpers
;; ============================================================

;; preduce-pair carries the cell-ids of its components. Stored as the
;; cell value for a pair construction; recognized by fst/snd projection
;; propagators.
(struct preduce-pair (fst-cid snd-cid) #:transparent)

;; --- Int arithmetic helpers ---

;; Nat→Int coercion. Mirrors try-coerce-to-int from reduction.rkt.
(define (coerce-to-int v)
  (cond
    [(expr-int? v) v]
    [(expr-nat-val? v) (expr-int (expr-nat-val-n v))]
    [(expr-zero? v) (expr-int 0)]
    [else #f]))  ;; not coercible

(define (compile-int-binary net env _orig a b make-fire)
  (define-values (cid-a net1) (compile-expr a env net))
  (define-values (cid-b net2) (compile-expr b env net1))
  (define-values (net3 cid-out)
    (net-new-cell net2 preduce-bot preduce-merge #:domain 'preduce-value))
  (define-values (net4 _)
    (net-add-fire-once-propagator net3 (list cid-a cid-b) (list cid-out)
                                  (make-fire cid-a cid-b cid-out)))
  (values cid-out net4))

;; Build a fire function for a binary int op. The op is given as a
;; closed Racket procedure on two integers, returning the result expr.
(define (make-int-binary-fire op-name op cid-a cid-b cid-out)
  (lambda (net)
    (define va (net-cell-read net cid-a))
    (define vb (net-cell-read net cid-b))
    (cond
      [(or (preduce-bot? va) (preduce-bot? vb)) net]
      [else
       (define ca (coerce-to-int va))
       (define cb (coerce-to-int vb))
       (cond
         [(and ca cb)
          (net-cell-write net cid-out (op (expr-int-val ca) (expr-int-val cb)))]
         [else
          (error 'preduce
                 "int-~a operands not numeric: ~v + ~v" op-name va vb)])])))

(define (int-add-fire ca cb co) (make-int-binary-fire 'add (lambda (x y) (expr-int (+ x y))) ca cb co))
(define (int-sub-fire ca cb co) (make-int-binary-fire 'sub (lambda (x y) (expr-int (- x y))) ca cb co))
(define (int-mul-fire ca cb co) (make-int-binary-fire 'mul (lambda (x y) (expr-int (* x y))) ca cb co))
(define (int-div-fire ca cb co) (make-int-binary-fire 'div (lambda (x y) (expr-int (quotient x y))) ca cb co))
(define (int-mod-fire ca cb co) (make-int-binary-fire 'mod (lambda (x y) (expr-int (remainder x y))) ca cb co))
(define (int-eq-fire  ca cb co) (make-int-binary-fire 'eq  (lambda (x y) (if (= x y) (expr-true) (expr-false))) ca cb co))
(define (int-lt-fire  ca cb co) (make-int-binary-fire 'lt  (lambda (x y) (if (< x y) (expr-true) (expr-false))) ca cb co))
(define (int-le-fire  ca cb co) (make-int-binary-fire 'le  (lambda (x y) (if (<= x y) (expr-true) (expr-false))) ca cb co))

;; --- Suc fire-fn ---

(define (make-suc-fire cid-in cid-out)
  (lambda (net)
    (define v (net-cell-read net cid-in))
    (cond
      [(preduce-bot? v) net]
      [(expr-nat-val? v)
       (net-cell-write net cid-out (expr-nat-val (+ (expr-nat-val-n v) 1)))]
      [(expr-zero? v)
       (net-cell-write net cid-out (expr-nat-val 1))]
      [else
       ;; Stuck — write (expr-suc v) as the result.
       (net-cell-write net cid-out (expr-suc v))])))

;; --- Pair projection fire-fn (for non-static cases) ---

(define (make-projection-fire cid-in cid-out which)
  (lambda (net)
    (define v (net-cell-read net cid-in))
    (cond
      [(preduce-bot? v) net]
      [(preduce-pair? v)
       (define component-cid
         (case which
           [(fst) (preduce-pair-fst-cid v)]
           [(snd) (preduce-pair-snd-cid v)]))
       (define component-val (net-cell-read net component-cid))
       (cond
         [(preduce-bot? component-val) net]  ;; component not ready; wait
         [else (net-cell-write net cid-out component-val)])]
      [else
       (error 'preduce "expected pair value for ~a projection, got: ~v" which v)])))

;; Allocate a fresh cell with the given value as its initial state.
;; Returns (values cid net'). Used by Phase 1's opaque-value rule and
;; by Phase 2's literal cases.
(define (alloc-value-cell net value)
  (define-values (net* cid)
    (net-new-cell net value preduce-merge #:domain 'preduce-value))
  (values cid net*))

;; ============================================================
;; Top-level entry points
;; ============================================================

;; preduce : expr → expr
;;   Reduce expr to WHNF via the propagator network.
;;   Raises exn:fail:preduce-unsupported if expr contains nodes not
;;   yet covered by the current phase.
(define (preduce expr)
  (define net0 (make-prop-network (current-preduce-fuel)))
  (define-values (result-cid net1) (compile-expr expr '() net0))
  (define net-final (run-to-quiescence net1))
  (define result-value (net-cell-read net-final result-cid))
  (cond
    [(preduce-bot? result-value)
     (error 'preduce
            "result cell unfilled — fire functions did not produce a value")]
    [(preduce-top? result-value)
     (error 'preduce
            "contradiction in result cell — non-deterministic input or bug")]
    [else result-value]))

;; preduce-or-nf : expr → expr
;;   Diagnostic helper for exploratory REPL use ONLY. Catches the
;;   unsupported-node error and dispatches to the existing nf reducer.
;;   NEVER wire this into typing-core or the test suite — that re-
;;   introduces the graceful-degradation correctness traps the design
;;   doc § 12 VAG explicitly rejects.
(define (preduce-or-nf expr)
  (with-handlers ([preduce-unsupported-node-error?
                   (lambda (_) (nf expr))])
    (preduce expr)))
