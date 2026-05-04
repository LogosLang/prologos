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
         racket/list  ;; for findf
         racket/string  ;; Phase 10b: for ctor-short-name
         "syntax.rkt"
         ;; Phase 2b refactor: backend-agnostic primitives via preduce-core.
         ;; The b-* accessors dispatch through (current-backend); the entry
         ;; point `preduce` parameterizes it to backend-racket.
         "preduce-core.rkt"
         "preduce-backend-racket.rkt"
         (only-in "propagator.rkt"
                  current-bsp-fire-round?)
         (only-in "sre-core.rkt" make-sre-domain register-domain!)
         (only-in "merge-fn-registry.rkt" register-merge-fn!/lattice)
         (only-in "reduction.rkt" nf)  ;; for preduce-or-nf diagnostic helper
         (only-in "global-env.rkt" global-env-lookup-value)
         ;; Phase 10b: user-defined ctor lookup
         (only-in "macros.rkt"
                  lookup-ctor
                  ctor-meta-field-types
                  ctor-meta-params)
         ;; Phase 11b: container ops
         (only-in "champ.rkt"
                  champ-empty champ-lookup champ-insert champ-delete
                  champ-size champ-has-key? champ-keys champ-vals)
         (only-in "rrb.rkt"
                  rrb-empty rrb-size rrb-get rrb-set rrb-push rrb-pop
                  rrb-concat rrb-slice rrb-to-list rrb-from-list))

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
 preduce-value-domain

 ;; Phase 10b: user-defined-ctor stuck-value tag
 (struct-out preduce-user-ctor))

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

    ;; ----- Phase 2 literals + Phase 5 refl + Phase 7 atomic literals -----
    [(? expr-int?)     (alloc-value-cell net e)]
    [(? expr-true?)    (alloc-value-cell net e)]
    [(? expr-false?)   (alloc-value-cell net e)]
    [(? expr-nat-val?) (alloc-value-cell net e)]
    [(? expr-zero?)    (alloc-value-cell net e)]
    [(? expr-refl?)    (alloc-value-cell net e)]  ;; Phase 5: refl is a value
    [(? expr-string?)  (alloc-value-cell net e)]  ;; Phase 7
    [(? expr-char?)    (alloc-value-cell net e)]  ;; Phase 7
    [(? expr-keyword?) (alloc-value-cell net e)]  ;; Phase 7
    [(? expr-symbol?)  (alloc-value-cell net e)]  ;; Phase 7
    [(? expr-path?)    (alloc-value-cell net e)]  ;; Phase 7
    [(? expr-rat?)     (alloc-value-cell net e)]  ;; Phase 8 (literal)
    [(? expr-posit8?)  (alloc-value-cell net e)]  ;; Phase 8 (literal)
    [(? expr-posit16?) (alloc-value-cell net e)]  ;; Phase 8 (literal)
    [(? expr-posit32?) (alloc-value-cell net e)]  ;; Phase 8 (literal)
    [(? expr-posit64?) (alloc-value-cell net e)]  ;; Phase 8 (literal)
    [(? expr-quire8-val?)  (alloc-value-cell net e)]  ;; Phase 8 (literal)
    [(? expr-quire16-val?) (alloc-value-cell net e)]  ;; Phase 8 (literal)
    [(? expr-quire32-val?) (alloc-value-cell net e)]  ;; Phase 8 (literal)
    [(? expr-quire64-val?) (alloc-value-cell net e)]  ;; Phase 8 (literal)

    ;; ----- Phase 11: container value-tokens (held opaque) -----
    ;; expr-champ wraps a Racket CHAMP map; expr-hset wraps a CHAMP-backed
    ;; set; expr-rrb wraps a Racket RRB-tree pvec. Container OPS
    ;; (Phase 11b) operate on these wrappers.
    [(? expr-champ?) (alloc-value-cell net e)]
    [(? expr-hset?)  (alloc-value-cell net e)]
    [(? expr-rrb?)   (alloc-value-cell net e)]

    ;; ----- Phase 11b: Map ops -----
    [(expr-map-empty _ _) (alloc-value-cell net (expr-champ champ-empty))]
    [(expr-map-assoc m k v) (compile-map-assoc net env m k v)]
    [(expr-map-get m k)     (compile-map-get net env m k)]
    [(expr-map-dissoc m k)  (compile-map-dissoc net env m k)]
    [(expr-map-size m)      (compile-map-1arg net env m
                              (lambda (c) (expr-nat-val (champ-size c))))]
    [(expr-map-has-key m k) (compile-map-2arg-bool net env m k
                              (lambda (c k*) (if (champ-has-key? c (equal-hash-code k*) k*)
                                                 (expr-true) (expr-false))))]
    [(expr-map-keys m) (compile-map-1arg net env m
                         (lambda (c) (racket-list->prologos-list (champ-keys c))))]
    [(expr-map-vals m) (compile-map-1arg net env m
                         (lambda (c) (racket-list->prologos-list (champ-vals c))))]

    ;; ----- Phase 11b: Set ops -----
    [(expr-set-empty _) (alloc-value-cell net (expr-hset champ-empty))]
    [(expr-set-insert s a) (compile-set-insert net env s a)]
    [(expr-set-member s a) (compile-set-2arg-bool net env s a
                             (lambda (c a*) (if (champ-has-key? c (equal-hash-code a*) a*)
                                                (expr-true) (expr-false))))]
    [(expr-set-delete s a) (compile-set-delete net env s a)]
    [(expr-set-size s)     (compile-set-1arg net env s
                             (lambda (c) (expr-nat-val (champ-size c))))]
    [(expr-set-union s1 s2)     (compile-set-binop net env s1 s2 set-op-union)]
    [(expr-set-intersect s1 s2) (compile-set-binop net env s1 s2 set-op-intersect)]
    [(expr-set-diff s1 s2)      (compile-set-binop net env s1 s2 set-op-diff)]
    [(expr-set-to-list s) (compile-set-1arg net env s
                            (lambda (c) (racket-list->prologos-list (champ-keys c))))]

    ;; ----- Phase 11b: PVec ops -----
    [(expr-pvec-empty _) (alloc-value-cell net (expr-rrb rrb-empty))]
    [(expr-pvec-push v x)     (compile-pvec-push net env v x)]
    [(expr-pvec-nth v i)      (compile-pvec-nth net env v i)]
    [(expr-pvec-update v i x) (compile-pvec-update net env v i x)]
    [(expr-pvec-length v)     (compile-pvec-1arg net env v
                                (lambda (r) (expr-nat-val (rrb-size r))))]
    [(expr-pvec-pop v)        (compile-pvec-1arg net env v
                                (lambda (r) (expr-rrb (rrb-pop r))))]
    [(expr-pvec-concat v1 v2) (compile-pvec-binop net env v1 v2
                                (lambda (r1 r2) (expr-rrb (rrb-concat r1 r2))))]
    [(expr-pvec-slice v lo hi) (compile-pvec-slice net env v lo hi)]
    [(expr-pvec-to-list v) (compile-pvec-1arg net env v
                             (lambda (r) (racket-list->prologos-list (rrb-to-list r))))]

    ;; ----- Phase 13: logic-engine value-tokens (held opaque) -----
    ;; Post-elaboration, these appear as value tokens (cell-ids, prop-ids,
    ;; ATMS handles, etc.) — reducer treats as values that don't unfold.
    [(? expr-cell-id?)            (alloc-value-cell net e)]
    [(? expr-cell-id-type?)       (alloc-value-cell net e)]
    [(? expr-prop-id-type?)       (alloc-value-cell net e)]
    [(? expr-uf-type?)            (alloc-value-cell net e)]
    [(? expr-atms-type?)          (alloc-value-cell net e)]
    [(? expr-assumption-id-type?) (alloc-value-cell net e)]
    [(? expr-assumption-id-val?)  (alloc-value-cell net e)]
    [(? expr-table-store-type?)   (alloc-value-cell net e)]
    [(? expr-solver-type?)        (alloc-value-cell net e)]
    [(? expr-goal-type?)          (alloc-value-cell net e)]
    [(? expr-derivation-type?)    (alloc-value-cell net e)]
    [(? expr-schema-type?)        (alloc-value-cell net e)]
    [(? expr-answer-type?)        (alloc-value-cell net e)]
    [(? expr-relation-type?)      (alloc-value-cell net e)]
    [(? expr-net-type?)           (alloc-value-cell net e)]

    ;; ----- Phase 14: tail edges -----
    ;; Open + cut held opaque. Numeric coercion ops (from-int, from-nat)
    ;; implemented per reduction.rkt iota rules. expr-panic (and other
    ;; complex tail nodes — broadcast-get, explain, all-different) raise
    ;; preduce-unsupported (deferred to Phase 14c — they touch logic-
    ;; engine effects or runtime exception machinery).
    [(? expr-Open?) (alloc-value-cell net e)]
    [(? expr-cut?)  (alloc-value-cell net e)]

    [(expr-from-int n)
     (define-values (cid-in net1) (compile-expr n env net))
     (define-values (cid-out net2)
       (b-alloc net1 preduce-bot))
     (define net3
       (b-install-fire-once net2 (list cid-in) (list cid-out)
         (lambda (nn)
           (define v (b-read nn cid-in))
           (cond
             [(preduce-bot? v) nn]
             [(expr-int? v) (b-write nn cid-out (expr-rat (expr-int-val v)))]
             [else (error 'preduce "from-int operand not Int: ~v" v)]))))
     (values cid-out net3)]

    [(expr-from-nat n)
     (define-values (cid-in net1) (compile-expr n env net))
     (define-values (cid-out net2)
       (b-alloc net1 preduce-bot))
     (define net3
       (b-install-fire-once net2 (list cid-in) (list cid-out)
         (lambda (nn)
           (define v (b-read nn cid-in))
           (cond
             [(preduce-bot? v) nn]
             [(expr-nat-val? v) (b-write nn cid-out (expr-int (expr-nat-val-n v)))]
             [(expr-zero? v)    (b-write nn cid-out (expr-int 0))]
             [else (error 'preduce "from-nat operand not Nat: ~v" v)]))))
     (values cid-out net3)]

    ;; ----- Phase 12: generic / trait-dispatched arithmetic -----
    ;;
    ;; ARCHITECTURAL HURDLE (postponed per user direction): full
    ;; expr-generic-* reduction requires trait dispatch via
    ;; resolve-generic-narrowing (reduction.rkt:996+), which depends on
    ;; the PPN 4C trait-resolution machinery (current-trait-registry,
    ;; current-impl-registry, etc.). The PPN 4C work is in-flight; until
    ;; it stabilizes, PReduce-lite holds expr-generic-* nodes opaque.
    ;;
    ;; In well-typed Prologos programs the elaborator rewrites generic
    ;; ops to their concrete monomorphic counterpart (e.g. (generic-add
    ;; (int 2) (int 3)) → (int-add (int 2) (int 3))), so expr-generic-*
    ;; rarely survives elaboration. Programs that DO leave generic ops
    ;; in their elaborated AST will see preduce return the unreduced
    ;; expr-generic-* term where nf would resolve it — a known
    ;; differential gap, deferred to Phase 12b.
    [(or (? expr-generic-add?) (? expr-generic-sub?) (? expr-generic-mul?)
         (? expr-generic-div?) (? expr-generic-mod?) (? expr-generic-eq?)
         (? expr-generic-lt?)  (? expr-generic-le?)  (? expr-generic-gt?)
         (? expr-generic-ge?)  (? expr-generic-negate?) (? expr-generic-abs?)
         (? expr-generic-from-int?) (? expr-generic-from-rat?))
     (alloc-value-cell net e)]

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
     (define-values (cid-out net2)
       (b-alloc net1 preduce-bot))
     (define fire-fn (make-suc-fire cid-in cid-out))
     (define net3
       (b-install-fire-once net2 (list cid-in) (list cid-out) fire-fn))
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
        (define-values (cid-out net2)
       (b-alloc net1 preduce-bot))
        (define net3
       (b-install-fire-once net2 (list cid-in) (list cid-out)
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
        (define-values (cid-out net2)
       (b-alloc net1 preduce-bot))
        (define net3
       (b-install-fire-once net2 (list cid-in) (list cid-out)
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
    ;; Phase 10b first: if `name` is a registered user-defined constructor
    ;; with arity 0 and no type params, treat the bare fvar as a stuck
    ;; nullary ctor value (e.g. `syrup-null`, `nil-of-T-instantiated`).
    ;; The data-declaration machinery stores ctor defs with placeholder
    ;; body `(Type 0)`, which would erroneously inline through the
    ;; global-env path below; the ctor-registry check pre-empts that.
    ;;
    ;; Look up name in the global env (default path). The def's value
    ;; AST is compiled in EMPTY env (top-level definitions don't see
    ;; surrounding bvars). Recursion detection via current-fvar-stack:
    ;; if name is already being compiled, raise unsupported (recursion
    ;; is Phase 4 — needs the topology stratum to break the compile-
    ;; time loop).
    [(expr-fvar name)
     (cond
       ;; Phase 10b: nullary user-defined ctor → stuck value
       [(let ([meta (lookup-ctor-meta name)])
          (and meta
               (= 0 (length (ctor-meta-field-types meta)))
               (= 0 (length (ctor-meta-params meta)))))
        (alloc-value-cell net (preduce-user-ctor (ctor-short-name name) '()))]
       [else
        (when (memq name (current-fvar-stack))
          (raise-unsupported!
           'expr-fvar 'phase-4-recursive-fvar
           (format "PReduce-lite Phase 3: recursive fvar ~a — recursion needs \
the topology stratum (Phase 4)" name)))
        (define value-ast (global-env-lookup-value name))
        (unless value-ast
          (error 'preduce "expr-fvar ~a not found in global env" name))
        (parameterize ([current-fvar-stack (cons name (current-fvar-stack))])
          (compile-expr value-ast '() net))])]

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
     (define ctor-decomp (try-decompose-user-ctor-app e))
     (define f-static (and (not ctor-decomp) (statically-reducible-lam f)))
     (cond
       ;; Phase 10b: fully-applied user-defined constructor → stuck value.
       ;; Compile each field arg to a cell-id; wrap as preduce-user-ctor.
       ;; classify-ctor (in make-reduce-fire) recognizes it and dispatches.
       [ctor-decomp
        (define short-name (car ctor-decomp))
        (define field-args (cdr ctor-decomp))
        (define-values (rev-field-cids net*)
          (for/fold ([acc-cids '()] [n net])
                    ([fa (in-list field-args)])
            (define-values (cid-fa n*) (compile-expr fa env n))
            (values (cons cid-fa acc-cids) n*)))
        (alloc-value-cell net*
          (preduce-user-ctor short-name (reverse rev-field-cids)))]
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
        (define-values (cid-out net3)
       (b-alloc net2 preduce-bot))
        (define net4
       (b-install-fire-once net3 (list cid-f) (list cid-out)
                                        (make-app-fire cid-f cid-arg cid-out)))
        (values cid-out net4)])]

    ;; ----- Phase 5: Bool eliminator (boolrec) -----
    [(expr-boolrec _motive tc fc target)
     (define-values (cid-target net1) (compile-expr target env net))
     (define-values (cid-out net2)
       (b-alloc net1 preduce-bot))
     (define net3
       (b-install-fire-once net2 (list cid-target) (list cid-out)
         (make-boolrec-fire cid-target cid-out tc fc env)))
     (values cid-out net3)]

    ;; ----- Phase 5: Nat eliminator (natrec) -----
    [(expr-natrec _motive base step target)
     (define-values (cid-target net1) (compile-expr target env net))
     (define-values (cid-out net2)
       (b-alloc net1 preduce-bot))
     (define net3
       (b-install-fire-once net2 (list cid-target) (list cid-out)
         (make-natrec-fire cid-target cid-out _motive base step env)))
     (values cid-out net3)]

    ;; ----- Phase 5: J (Eq eliminator, refl-only iota) -----
    [(expr-J _motive base left _right proof)
     (define-values (cid-proof net1) (compile-expr proof env net))
     (define-values (cid-out net2)
       (b-alloc net1 preduce-bot))
     (define net3
       (b-install-fire-once net2 (list cid-proof) (list cid-out)
         (make-j-fire cid-proof cid-out base left env)))
     (values cid-out net3)]

    ;; ----- Phase 6: Vec eliminators + constructors -----
    ;;
    ;; vnil(A) and vcons(A,n,h,t) are values (held opaque). vhead/vtail
    ;; are eliminators with iota:
    ;;   vhead _ _ (vcons _ _ h _) → h
    ;;   vtail _ _ (vcons _ _ _ t) → t
    ;; Static fast-path: when the vec arg is literally vcons, project
    ;; directly. Otherwise fire-once on the vec cell.
    [(expr-vnil _)  (alloc-value-cell net e)]
    [(expr-vcons _ _ _ _)
     ;; vcons holds sub-exprs that may need reduction. Compile the
     ;; head + tail; the cons cell carries a preduce-vcons value with
     ;; component cell-ids (so vhead/vtail can project).
     (match e
       [(expr-vcons type len head tail)
        (define-values (cid-h net1) (compile-expr head env net))
        (define-values (cid-t net2) (compile-expr tail env net1))
        (alloc-value-cell net2 (preduce-vcons type len cid-h cid-t))])]

    [(expr-vhead _ _ vec)
     (cond
       [(expr-vcons? vec)
        (compile-expr (expr-vcons-head vec) env net)]
       [(expr-ann? vec)
        (compile-expr (expr-vhead #f #f (expr-ann-term vec)) env net)]
       [else
        (define-values (cid-v net1) (compile-expr vec env net))
        (define-values (cid-out net2)
       (b-alloc net1 preduce-bot))
        (define net3
       (b-install-fire-once net2 (list cid-v) (list cid-out)
            (make-vproj-fire cid-v cid-out 'head)))
        (values cid-out net3)])]

    [(expr-vtail _ _ vec)
     (cond
       [(expr-vcons? vec)
        (compile-expr (expr-vcons-tail vec) env net)]
       [(expr-ann? vec)
        (compile-expr (expr-vtail #f #f (expr-ann-term vec)) env net)]
       [else
        (define-values (cid-v net1) (compile-expr vec env net))
        (define-values (cid-out net2)
       (b-alloc net1 preduce-bot))
        (define net3
       (b-install-fire-once net2 (list cid-v) (list cid-out)
            (make-vproj-fire cid-v cid-out 'tail)))
        (values cid-out net3)])]

    ;; ----- Phase 10: expr-reduce — general constructor pattern match -----
    ;;
    ;; Compile scrutinee → cid; install fire-once that, when scrutinee
    ;; resolves to a known constructor value, finds the matching arm by
    ;; ctor-name, compiles the arm body with the constructor's field
    ;; values bound as bvars, and identity-bridges the result to cid-out.
    ;;
    ;; Phase 10 minimal scope: built-in constructors (true, false, zero,
    ;; suc, nat-val, refl, nil, vnil, vcons, fzero, fsuc, pair). User-
    ;; defined constructors (registered via `data` or `defr`) require
    ;; ctor-meta lookup and are deferred to Phase 10b if needed.
    [(expr-reduce scrutinee arms _structural?)
     (define-values (cid-target net1) (compile-expr scrutinee env net))
     (define-values (cid-out net2)
       (b-alloc net1 preduce-bot))
     (define net3
       (b-install-fire-once net2 (list cid-target) (list cid-out)
         (make-reduce-fire cid-target cid-out arms env)))
     (values cid-out net3)]

    ;; ----- Phase 6: Fin family (held opaque as values) -----
    ;; Fin n is a type; fzero / fsuc are values. No eliminator in Phase 6
    ;; (the elaborator turns Fin pattern matching into expr-reduce, Phase 10).
    [(expr-fzero _) (alloc-value-cell net e)]
    [(expr-fsuc _ inner)
     (define-values (cid-in net1) (compile-expr inner env net))
     ;; The fsuc value is opaque; we don't unfold inner inline. We just
     ;; allocate a cell with the original fsuc shape + the compiled
     ;; inner cell-id to allow downstream usage to recurse via cell.
     ;; Simplest: hold opaque (fsuc inner) where inner is the value.
     (define-values (cid-out net2)
       (b-alloc net1 preduce-bot))
     (define net3
       (b-install-fire-once net2 (list cid-in) (list cid-out)
         (lambda (n)
           (define iv (b-read n cid-in))
           (if (preduce-bot? iv) n
               (b-write n cid-out (expr-fsuc #f iv))))))
     (values cid-out net3)]

    ;; ----- All other nodes: deferred to later phases -----
    [_
     (raise-unsupported!
      (expr-kind e)
      'phase-6-or-later
      (format "PReduce-lite Phase 5: AST node ~a is not yet supported. \
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
    (define f-val (b-read net cid-f))
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
       (define net2
         (parameterize ([current-bsp-fire-round? #f])
           (b-install-fire-once
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
    (define v (b-read net cid-in))
    (if (preduce-bot? v) net
        (b-write net cid-out v))))

;; ============================================================
;; Phase 5 helpers — eliminators
;; ============================================================

;; make-boolrec-fire — Bool eliminator iota: dispatches on target.
(define (make-boolrec-fire cid-target cid-out tc fc env)
  (lambda (net)
    (define v (b-read net cid-target))
    (cond
      [(preduce-bot? v) net]
      [(expr-true? v)  (compile-and-bridge tc env net cid-out)]
      [(expr-false? v) (compile-and-bridge fc env net cid-out)]
      [else
       (error 'preduce "boolrec target reduced to non-Bool value: ~v" v)])))

;; make-natrec-fire — Nat eliminator iota:
;;   zero / nat-val 0 → base
;;   suc n / nat-val k>0 → (step (k-1) (natrec _ base step (k-1)))
(define (make-natrec-fire cid-target cid-out motive base step env)
  (lambda (net)
    (define v (b-read net cid-target))
    (cond
      [(preduce-bot? v) net]
      [(or (expr-zero? v) (and (expr-nat-val? v) (= (expr-nat-val-n v) 0)))
       (compile-and-bridge base env net cid-out)]
      [(expr-nat-val? v)
       (define k-1 (expr-nat-val (- (expr-nat-val-n v) 1)))
       (define recursive-call (expr-natrec motive base step k-1))
       (define unfolded (expr-app (expr-app step k-1) recursive-call))
       (compile-and-bridge unfolded env net cid-out)]
      [(expr-suc? v)
       (define n (expr-suc-pred v))
       (define recursive-call (expr-natrec motive base step n))
       (define unfolded (expr-app (expr-app step n) recursive-call))
       (compile-and-bridge unfolded env net cid-out)]
      [else
       (error 'preduce "natrec target reduced to non-Nat value: ~v" v)])))

;; make-j-fire — Eq eliminator iota: when proof = refl, result = (app base left).
(define (make-j-fire cid-proof cid-out base left env)
  (lambda (net)
    (define v (b-read net cid-proof))
    (cond
      [(preduce-bot? v) net]
      [(expr-refl? v)
       (compile-and-bridge (expr-app base left) env net cid-out)]
      [else
       (error 'preduce "J proof reduced to non-refl value: ~v" v)])))

;; compile-and-bridge — shared helper for eliminators. Compiles `e` in
;; env, then installs an identity propagator from its result cell to
;; cid-out. Done under (parameterize ([current-bsp-fire-round? #f]) …)
;; so the new propagators auto-schedule (mirrors the dynamic-β discipline).
(define (compile-and-bridge e env net cid-out)
  (define-values (cid-e net1)
    (parameterize ([current-bsp-fire-round? #f])
      (compile-expr e env net)))
  (define net2
    (parameterize ([current-bsp-fire-round? #f])
      (b-install-fire-once
       net1 (list cid-e) (list cid-out)
       (make-identity-fire cid-e cid-out))))
  net2)

;; ============================================================
;; Phase 10 helpers — expr-reduce general constructor pattern match
;; ============================================================

;; classify-builtin-ctor : preduce-value → (values ctor-name field-cids) | #f
;;   For built-in constructors, returns the short ctor name + a list of
;;   cell-ids for the constructor's field values (already alloc'd in net).
;;   The fields list is empty for nullary constructors (true, false,
;;   zero, refl, nil, vnil) and one element for unary (suc, nat-val,
;;   fzero, fsuc, pair, vcons).
;;
;;   For nat-val k > 0: classify as 'suc with field cid pointing to a
;;   newly-allocated cell holding (nat-val (k-1)) — mirrors the
;;   nat-val unfold pattern in make-natrec-fire.
;;
;;   Returns #f if the value isn't a recognized constructor.
(define (classify-builtin-ctor v net)
  (cond
    [(expr-true? v)        (values 'true '() net)]
    [(expr-false? v)       (values 'false '() net)]
    [(expr-zero? v)        (values 'zero '() net)]
    [(expr-refl? v)        (values 'refl '() net)]
    [(expr-nil? v)         (values 'nil '() net)]
    [(expr-vnil? v)        (values 'vnil '() net)]
    [(expr-fzero? v)       (values 'fzero '() net)]
    [(expr-suc? v)
     ;; (suc n) — n is the field. Allocate a cell for it.
     (define-values (cid-n net*) (alloc-value-cell net (expr-suc-pred v)))
     (values 'suc (list cid-n) net*)]
    [(expr-nat-val? v)
     (define n (expr-nat-val-n v))
     (cond
       [(= n 0) (values 'zero '() net)]
       [else
        ;; (nat-val k) with k>0 acts as (suc (nat-val k-1))
        (define-values (cid-pred net*) (alloc-value-cell net (expr-nat-val (- n 1))))
        (values 'suc (list cid-pred) net*)])]
    [(preduce-pair? v)
     (values 'pair (list (preduce-pair-fst-cid v) (preduce-pair-snd-cid v)) net)]
    [(preduce-vcons? v)
     (values 'vcons (list (preduce-vcons-head-cid v) (preduce-vcons-tail-cid v)) net)]
    [(expr-fsuc? v)
     (define-values (cid-inner net*) (alloc-value-cell net (expr-fsuc-inner v)))
     (values 'fsuc (list cid-inner) net*)]
    ;; Phase 10b: user-defined ctor value carries its short name + field cids
    ;; directly; no further allocation needed.
    [(preduce-user-ctor? v)
     (values (preduce-user-ctor-short-name v)
             (preduce-user-ctor-field-cids v)
             net)]
    [else (values #f '() net)]))

;; make-reduce-fire — fires when the scrutinee cell resolves; matches
;; the value against arms by short ctor-name; compiles the matching
;; arm's body with the field cell-ids prepended to env.
(define (make-reduce-fire cid-target cid-out arms env)
  (lambda (net)
    (define v (b-read net cid-target))
    (cond
      [(preduce-bot? v) net]
      [else
       (define-values (ctor field-cids net*) (classify-builtin-ctor v net))
       (cond
         [(not ctor)
          (error 'preduce
                 "expr-reduce: scrutinee not a recognized constructor: ~v" v)]
         [else
          (define matching-arm
            (findf (lambda (arm)
                     (eq? (expr-reduce-arm-ctor-name arm) ctor))
                   arms))
          (cond
            [(not matching-arm)
             (error 'preduce
                    "expr-reduce: no arm for constructor ~a (arms: ~v)"
                    ctor (map expr-reduce-arm-ctor-name arms))]
            [else
             (define bc (expr-reduce-arm-binding-count matching-arm))
             (unless (= bc (length field-cids))
               (error 'preduce
                      "expr-reduce: arm ~a expects ~a binders, ctor has ~a fields"
                      ctor bc (length field-cids)))
             (define body (expr-reduce-arm-body matching-arm))
             ;; Bind fields as bvars: arm body's bvar 0 = first field, bvar 1 = second, etc.
             ;; Bvars are de-Bruijn from innermost; the first binder introduced is bvar 0.
             ;; Field order convention: (suc n) has n as bvar 0; (pair a b) has b as bvar 0,
             ;; a as bvar 1 (innermost-first).
             (define new-env (append (reverse field-cids) env))
             (compile-and-bridge body new-env net* cid-out)])])])))

;; ============================================================
;; Phase 11b helpers — container ops
;; ============================================================
;;
;; All container ops follow the same shape: compile each input expr to
;; a cell, install fire-once propagator on the inputs, fire-fn reads,
;; checks the input is the expected wrapped value (expr-champ /
;; expr-hset / expr-rrb), invokes the underlying Racket op, writes the
;; output. Mirrors reduction.rkt's iota-rule semantics.

(define (racket-list->prologos-list elems)
  ;; Mirror of reduction.rkt's racket-list->prologos-list.
  (foldr (lambda (e acc)
           (expr-app (expr-app (expr-fvar 'cons) e) acc))
         (expr-nil)
         elems))

;; --- Map ops ---

(define (compile-map-1arg net env m apply-fn)
  ;; Generic 1-arg op on a map. apply-fn takes the unwrapped CHAMP and
  ;; returns the result expr.
  (define-values (cid-m net1) (compile-expr m env net))
  (define-values (cid-out net2)
       (b-alloc net1 preduce-bot))
  (define net3
       (b-install-fire-once net2 (list cid-m) (list cid-out)
      (lambda (n)
        (define mv (b-read n cid-m))
        (cond
          [(preduce-bot? mv) n]
          [(expr-champ? mv) (b-write n cid-out (apply-fn (expr-champ-racket-champ mv)))]
          [else (error 'preduce "expected expr-champ for map op, got: ~v" mv)]))))
  (values cid-out net3))

(define (compile-map-2arg-bool net env m k apply-fn)
  ;; 2-arg op (map, key) → Bool. Doesn't allocate fresh map.
  (define-values (cid-m net1) (compile-expr m env net))
  (define-values (cid-k net2) (compile-expr k env net1))
  (define-values (cid-out net3)
       (b-alloc net2 preduce-bot))
  (define net4
       (b-install-fire-once net3 (list cid-m cid-k) (list cid-out)
      (lambda (n)
        (define mv (b-read n cid-m))
        (define kv (b-read n cid-k))
        (cond
          [(or (preduce-bot? mv) (preduce-bot? kv)) n]
          [(expr-champ? mv) (b-write n cid-out
                                            (apply-fn (expr-champ-racket-champ mv) kv))]
          [else (error 'preduce "expected expr-champ, got: ~v" mv)]))))
  (values cid-out net4))

(define (compile-map-assoc net env m k v)
  (define-values (cid-m net1) (compile-expr m env net))
  (define-values (cid-k net2) (compile-expr k env net1))
  (define-values (cid-v net3) (compile-expr v env net2))
  (define-values (cid-out net4)
       (b-alloc net3 preduce-bot))
  (define net5
       (b-install-fire-once net4 (list cid-m cid-k cid-v) (list cid-out)
      (lambda (n)
        (define mv (b-read n cid-m))
        (define kv (b-read n cid-k))
        (define vv (b-read n cid-v))
        (cond
          [(or (preduce-bot? mv) (preduce-bot? kv) (preduce-bot? vv)) n]
          [(expr-champ? mv)
           (b-write n cid-out
             (expr-champ (champ-insert (expr-champ-racket-champ mv)
                                       (equal-hash-code kv) kv vv)))]
          [else (error 'preduce "expected expr-champ for map-assoc, got: ~v" mv)]))))
  (values cid-out net5))

(define (compile-map-get net env m k)
  (define-values (cid-m net1) (compile-expr m env net))
  (define-values (cid-k net2) (compile-expr k env net1))
  (define-values (cid-out net3)
       (b-alloc net2 preduce-bot))
  (define net4
       (b-install-fire-once net3 (list cid-m cid-k) (list cid-out)
      (lambda (n)
        (define mv (b-read n cid-m))
        (define kv (b-read n cid-k))
        (cond
          [(or (preduce-bot? mv) (preduce-bot? kv)) n]
          [(expr-champ? mv)
           (define result (champ-lookup (expr-champ-racket-champ mv)
                                        (equal-hash-code kv) kv))
           (cond
             [(eq? result 'none) (b-write n cid-out (expr-error))]
             [else (b-write n cid-out result)])]
          [else (error 'preduce "expected expr-champ for map-get, got: ~v" mv)]))))
  (values cid-out net4))

(define (compile-map-dissoc net env m k)
  (define-values (cid-m net1) (compile-expr m env net))
  (define-values (cid-k net2) (compile-expr k env net1))
  (define-values (cid-out net3)
       (b-alloc net2 preduce-bot))
  (define net4
       (b-install-fire-once net3 (list cid-m cid-k) (list cid-out)
      (lambda (n)
        (define mv (b-read n cid-m))
        (define kv (b-read n cid-k))
        (cond
          [(or (preduce-bot? mv) (preduce-bot? kv)) n]
          [(expr-champ? mv)
           (b-write n cid-out
             (expr-champ (champ-delete (expr-champ-racket-champ mv)
                                       (equal-hash-code kv) kv)))]
          [else (error 'preduce "expected expr-champ for map-dissoc, got: ~v" mv)]))))
  (values cid-out net4))

;; --- Set ops ---

(define (compile-set-1arg net env s apply-fn)
  (define-values (cid-s net1) (compile-expr s env net))
  (define-values (cid-out net2)
       (b-alloc net1 preduce-bot))
  (define net3
       (b-install-fire-once net2 (list cid-s) (list cid-out)
      (lambda (n)
        (define sv (b-read n cid-s))
        (cond
          [(preduce-bot? sv) n]
          [(expr-hset? sv) (b-write n cid-out (apply-fn (expr-hset-racket-champ sv)))]
          [else (error 'preduce "expected expr-hset for set op, got: ~v" sv)]))))
  (values cid-out net3))

(define (compile-set-2arg-bool net env s a apply-fn)
  (define-values (cid-s net1) (compile-expr s env net))
  (define-values (cid-a net2) (compile-expr a env net1))
  (define-values (cid-out net3)
       (b-alloc net2 preduce-bot))
  (define net4
       (b-install-fire-once net3 (list cid-s cid-a) (list cid-out)
      (lambda (n)
        (define sv (b-read n cid-s))
        (define av (b-read n cid-a))
        (cond
          [(or (preduce-bot? sv) (preduce-bot? av)) n]
          [(expr-hset? sv) (b-write n cid-out
                                           (apply-fn (expr-hset-racket-champ sv) av))]
          [else (error 'preduce "expected expr-hset, got: ~v" sv)]))))
  (values cid-out net4))

(define (compile-set-insert net env s a)
  (compile-set-2arg-bool net env s a
    (lambda (c av) (expr-hset (champ-insert c (equal-hash-code av) av #t)))))

(define (compile-set-delete net env s a)
  (compile-set-2arg-bool net env s a
    (lambda (c av) (expr-hset (champ-delete c (equal-hash-code av) av)))))

(define (compile-set-binop net env s1 s2 op)
  (define-values (cid-1 net1) (compile-expr s1 env net))
  (define-values (cid-2 net2) (compile-expr s2 env net1))
  (define-values (cid-out net3)
       (b-alloc net2 preduce-bot))
  (define net4
       (b-install-fire-once net3 (list cid-1 cid-2) (list cid-out)
      (lambda (n)
        (define v1 (b-read n cid-1))
        (define v2 (b-read n cid-2))
        (cond
          [(or (preduce-bot? v1) (preduce-bot? v2)) n]
          [(and (expr-hset? v1) (expr-hset? v2))
           (b-write n cid-out (expr-hset (op (expr-hset-racket-champ v1)
                                                    (expr-hset-racket-champ v2))))]
          [else (error 'preduce "expected expr-hset operands, got: ~v ~v" v1 v2)]))))
  (values cid-out net4))

;; CHAMP-set ops via fold (CHAMP doesn't have native union/intersect/diff).
(define (set-op-union c1 c2)
  ;; insert all keys from c2 into c1
  (for/fold ([acc c1]) ([k (in-list (champ-keys c2))])
    (champ-insert acc (equal-hash-code k) k #t)))

(define (set-op-intersect c1 c2)
  ;; keep keys of c1 that are also in c2
  (for/fold ([acc champ-empty]) ([k (in-list (champ-keys c1))]
                                  #:when (champ-has-key? c2 (equal-hash-code k) k))
    (champ-insert acc (equal-hash-code k) k #t)))

(define (set-op-diff c1 c2)
  ;; keep keys of c1 that are NOT in c2
  (for/fold ([acc champ-empty]) ([k (in-list (champ-keys c1))]
                                  #:unless (champ-has-key? c2 (equal-hash-code k) k))
    (champ-insert acc (equal-hash-code k) k #t)))

;; --- PVec ops ---

(define (compile-pvec-1arg net env v apply-fn)
  (define-values (cid-v net1) (compile-expr v env net))
  (define-values (cid-out net2)
       (b-alloc net1 preduce-bot))
  (define net3
       (b-install-fire-once net2 (list cid-v) (list cid-out)
      (lambda (n)
        (define vv (b-read n cid-v))
        (cond
          [(preduce-bot? vv) n]
          [(expr-rrb? vv) (b-write n cid-out (apply-fn (expr-rrb-racket-rrb vv)))]
          [else (error 'preduce "expected expr-rrb for pvec op, got: ~v" vv)]))))
  (values cid-out net3))

(define (compile-pvec-binop net env v1 v2 apply-fn)
  (define-values (cid-1 net1) (compile-expr v1 env net))
  (define-values (cid-2 net2) (compile-expr v2 env net1))
  (define-values (cid-out net3)
       (b-alloc net2 preduce-bot))
  (define net4
       (b-install-fire-once net3 (list cid-1 cid-2) (list cid-out)
      (lambda (n)
        (define u1 (b-read n cid-1))
        (define u2 (b-read n cid-2))
        (cond
          [(or (preduce-bot? u1) (preduce-bot? u2)) n]
          [(and (expr-rrb? u1) (expr-rrb? u2))
           (b-write n cid-out (apply-fn (expr-rrb-racket-rrb u1)
                                                (expr-rrb-racket-rrb u2)))]
          [else (error 'preduce "expected expr-rrb operands, got: ~v ~v" u1 u2)]))))
  (values cid-out net4))

(define (compile-pvec-push net env v x)
  (define-values (cid-v net1) (compile-expr v env net))
  (define-values (cid-x net2) (compile-expr x env net1))
  (define-values (cid-out net3)
       (b-alloc net2 preduce-bot))
  (define net4
       (b-install-fire-once net3 (list cid-v cid-x) (list cid-out)
      (lambda (n)
        (define vv (b-read n cid-v))
        (define xv (b-read n cid-x))
        (cond
          [(or (preduce-bot? vv) (preduce-bot? xv)) n]
          [(expr-rrb? vv) (b-write n cid-out
                                          (expr-rrb (rrb-push (expr-rrb-racket-rrb vv) xv)))]
          [else (error 'preduce "expected expr-rrb for pvec-push, got: ~v" vv)]))))
  (values cid-out net4))

(define (nat-or-int-to-fixnum v)
  (cond
    [(expr-nat-val? v) (expr-nat-val-n v)]
    [(expr-int? v) (expr-int-val v)]
    [(expr-zero? v) 0]
    [else #f]))

(define (compile-pvec-nth net env v i)
  (define-values (cid-v net1) (compile-expr v env net))
  (define-values (cid-i net2) (compile-expr i env net1))
  (define-values (cid-out net3)
       (b-alloc net2 preduce-bot))
  (define net4
       (b-install-fire-once net3 (list cid-v cid-i) (list cid-out)
      (lambda (n)
        (define vv (b-read n cid-v))
        (define iv (b-read n cid-i))
        (cond
          [(or (preduce-bot? vv) (preduce-bot? iv)) n]
          [(expr-rrb? vv)
           (define idx (nat-or-int-to-fixnum iv))
           (cond
             [(not idx) (error 'preduce "pvec-nth index not numeric: ~v" iv)]
             [else
              (with-handlers ([exn:fail? (lambda (_) (b-write n cid-out (expr-error)))])
                (b-write n cid-out (rrb-get (expr-rrb-racket-rrb vv) idx)))])]
          [else (error 'preduce "expected expr-rrb for pvec-nth, got: ~v" vv)]))))
  (values cid-out net4))

(define (compile-pvec-update net env v i x)
  (define-values (cid-v net1) (compile-expr v env net))
  (define-values (cid-i net2) (compile-expr i env net1))
  (define-values (cid-x net3) (compile-expr x env net2))
  (define-values (cid-out net4)
       (b-alloc net3 preduce-bot))
  (define net5
       (b-install-fire-once net4 (list cid-v cid-i cid-x) (list cid-out)
      (lambda (n)
        (define vv (b-read n cid-v))
        (define iv (b-read n cid-i))
        (define xv (b-read n cid-x))
        (cond
          [(or (preduce-bot? vv) (preduce-bot? iv) (preduce-bot? xv)) n]
          [(expr-rrb? vv)
           (define idx (nat-or-int-to-fixnum iv))
           (cond
             [(not idx) (error 'preduce "pvec-update index not numeric: ~v" iv)]
             [else
              (b-write n cid-out (expr-rrb (rrb-set (expr-rrb-racket-rrb vv) idx xv)))])]
          [else (error 'preduce "expected expr-rrb for pvec-update, got: ~v" vv)]))))
  (values cid-out net5))

(define (compile-pvec-slice net env v lo hi)
  (define-values (cid-v net1) (compile-expr v env net))
  (define-values (cid-lo net2) (compile-expr lo env net1))
  (define-values (cid-hi net3) (compile-expr hi env net2))
  (define-values (cid-out net4)
       (b-alloc net3 preduce-bot))
  (define net5
       (b-install-fire-once net4 (list cid-v cid-lo cid-hi) (list cid-out)
      (lambda (n)
        (define vv (b-read n cid-v))
        (define lov (b-read n cid-lo))
        (define hiv (b-read n cid-hi))
        (cond
          [(or (preduce-bot? vv) (preduce-bot? lov) (preduce-bot? hiv)) n]
          [(expr-rrb? vv)
           (define lo-i (nat-or-int-to-fixnum lov))
           (define hi-i (nat-or-int-to-fixnum hiv))
           (cond
             [(or (not lo-i) (not hi-i)) (error 'preduce "pvec-slice indices not numeric")]
             [else
              (b-write n cid-out (expr-rrb (rrb-slice (expr-rrb-racket-rrb vv) lo-i hi-i)))])]
          [else (error 'preduce "expected expr-rrb for pvec-slice, got: ~v" vv)]))))
  (values cid-out net5))

;; ============================================================
;; Phase 6 helpers — Vec
;; ============================================================

;; preduce-vcons — Vec cons value, carries component cell-ids for
;; head/tail projection (parallel to preduce-pair for pair projection).
(struct preduce-vcons (type len head-cid tail-cid) #:transparent)

;; make-vproj-fire — vhead/vtail projection on a non-static vec cell.
(define (make-vproj-fire cid-in cid-out which)
  (lambda (net)
    (define v (b-read net cid-in))
    (cond
      [(preduce-bot? v) net]
      [(preduce-vcons? v)
       (define component-cid
         (case which
           [(head) (preduce-vcons-head-cid v)]
           [(tail) (preduce-vcons-tail-cid v)]))
       (define cv (b-read net component-cid))
       (cond
         [(preduce-bot? cv) net]
         [else (b-write net cid-out cv)])]
      [else
       (error 'preduce "expected vcons value for v~a, got: ~v" which v)])))

;; ============================================================
;; Phase 2 helpers
;; ============================================================

;; preduce-pair carries the cell-ids of its components. Stored as the
;; cell value for a pair construction; recognized by fst/snd projection
;; propagators.
(struct preduce-pair (fst-cid snd-cid) #:transparent)

;; ============================================================
;; Phase 10b — user-defined constructor values
;; ============================================================
;;
;; A fully-applied user-defined data constructor (registered via `data`
;; declarations in macros.rkt) is represented as a stuck value carrying
;; the constructor's SHORT name + the cell-ids of its field arguments.
;; This is the user-ctor analogue of preduce-pair / preduce-vcons:
;; opaque to further reduction, but recognized by classify-ctor so
;; expr-reduce can dispatch on it.
;;
;; short-name : symbol (e.g. 'syrup-tagged, 'pst-unresolved)
;; field-cids : (listof cell-id) — same order as the data declaration's
;;   field-types list. Type-arg cells (for parameterized types) are NOT
;;   included; only value fields.
(struct preduce-user-ctor (short-name field-cids) #:transparent)

;; Strip an FQN qualifier from a constructor name. Mirrors
;; reduction.rkt's ctor-short-name. Examples:
;;   'prologos::ocapn::syrup::syrup-tagged → 'syrup-tagged
;;   'syrup-tagged                          → 'syrup-tagged
(define (ctor-short-name fqn)
  (define parts (string-split (symbol->string fqn) "::"))
  (string->symbol (last parts)))

;; Look up a ctor's meta by name, trying FQN then short-name fallback.
;; Returns ctor-meta or #f.
(define (lookup-ctor-meta name)
  (or (lookup-ctor name)
      (lookup-ctor (ctor-short-name name))))

;; Decompose a user-defined-ctor application into
;; (cons short-name field-arg-exprs) iff the expression IS a fully-
;; applied registered user constructor. Returns #f otherwise.
;;
;; Handles curried expr-app chains; for parametrized types the chain
;; may include type args at the front, which are stripped when the
;; total arg count matches arity + n-type-params.
;;
;; Examples (elaborator output):
;;   (expr-app (expr-app (expr-fvar 'syrup-tagged) "set") syrup-null-arg)
;;     → '(syrup-tagged "set"-arg syrup-null-arg)
;;   (expr-app (expr-app (expr-fvar 'cons) Int) (expr-app ... 1 nil))
;;     → '(cons 1-arg nil-arg)   ;; type arg Int dropped
;;
;; Bare nullary ctor references (just expr-fvar) are handled in the
;; expr-fvar case directly, not here.
(define (try-decompose-user-ctor-app e)
  (define-values (head all-args)
    (let loop ([e e] [acc '()])
      (match e
        [(expr-app f a) (loop f (cons a acc))]
        [_              (values e acc)])))
  (cond
    [(not (expr-fvar? head)) #f]
    [else
     (define name (expr-fvar-name head))
     (define meta (lookup-ctor-meta name))
     (cond
       [(not meta) #f]
       [else
        (define n-fields (length (ctor-meta-field-types meta)))
        (define n-params (length (ctor-meta-params meta)))
        (define n-args   (length all-args))
        (cond
          ;; Full application without type args (typical at-the-source form)
          [(and (> n-fields 0) (= n-args n-fields))
           (cons (ctor-short-name name) all-args)]
          ;; Full application with explicit type args prepended
          [(and (> n-fields 0) (= n-args (+ n-fields n-params)))
           (cons (ctor-short-name name) (drop all-args n-params))]
          ;; Partial application, over-application, or 0-field ctor: not here
          [else #f])])]))

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
  (define-values (cid-out net3)
       (b-alloc net2 preduce-bot))
  (define net4
       (b-install-fire-once net3 (list cid-a cid-b) (list cid-out)
                                  (make-fire cid-a cid-b cid-out)))
  (values cid-out net4))

;; Build a fire function for a binary int op. The op is given as a
;; closed Racket procedure on two integers, returning the result expr.
(define (make-int-binary-fire op-name op cid-a cid-b cid-out)
  (lambda (net)
    (define va (b-read net cid-a))
    (define vb (b-read net cid-b))
    (cond
      [(or (preduce-bot? va) (preduce-bot? vb)) net]
      [else
       (define ca (coerce-to-int va))
       (define cb (coerce-to-int vb))
       (cond
         [(and ca cb)
          (b-write net cid-out (op (expr-int-val ca) (expr-int-val cb)))]
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
    (define v (b-read net cid-in))
    (cond
      [(preduce-bot? v) net]
      [(expr-nat-val? v)
       (b-write net cid-out (expr-nat-val (+ (expr-nat-val-n v) 1)))]
      [(expr-zero? v)
       (b-write net cid-out (expr-nat-val 1))]
      [else
       ;; Stuck — write (expr-suc v) as the result.
       (b-write net cid-out (expr-suc v))])))

;; --- Pair projection fire-fn (for non-static cases) ---

(define (make-projection-fire cid-in cid-out which)
  (lambda (net)
    (define v (b-read net cid-in))
    (cond
      [(preduce-bot? v) net]
      [(preduce-pair? v)
       (define component-cid
         (case which
           [(fst) (preduce-pair-fst-cid v)]
           [(snd) (preduce-pair-snd-cid v)]))
       (define component-val (b-read net component-cid))
       (cond
         [(preduce-bot? component-val) net]  ;; component not ready; wait
         [else (b-write net cid-out component-val)])]
      [else
       (error 'preduce "expected pair value for ~a projection, got: ~v" which v)])))

;; Allocate a fresh cell with the given value as its initial state.
;; Returns (values cid net'). Used by Phase 1's opaque-value rule and
;; by Phase 2's literal cases.
;;
;; Phase 2b: now delegates to (b-alloc) which dispatches via the
;; current-backend parameter. Same return shape — (values cid net').
(define (alloc-value-cell net value)
  (b-alloc net value))

;; ============================================================
;; Top-level entry points
;; ============================================================

;; preduce : expr → expr
;;   Reduce expr to WHNF via the propagator network.
;;   Raises exn:fail:preduce-unsupported if expr contains nodes not
;;   yet covered by the current phase.
(define (preduce expr)
  (parameterize ([current-backend
                  (backend-racket-with-lattice preduce-merge
                                               preduce-bot
                                               (current-preduce-fuel))])
    (define net0 (b-fresh-net))
    (define-values (result-cid net1) (compile-expr expr '() net0))
    (define net-final (b-run-to-quiescence net1))
    (define result-value (b-read net-final result-cid))
    (cond
      [(preduce-bot? result-value)
       (error 'preduce
              "result cell unfilled — fire functions did not produce a value")]
      [(preduce-top? result-value)
       (error 'preduce
              "contradiction in result cell — non-deterministic input or bug")]
      [else result-value])))

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
