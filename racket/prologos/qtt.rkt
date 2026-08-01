#lang racket/base

;;;
;;; PROLOGOS QTT
;;; Quantitative Type Theory: multiplicity tracking layered on top of core typing.
;;; Direct translation of prologos-qtt.maude.
;;;
;;; The QTT layer tracks how each variable is used (0, 1, or ω times)
;;; and verifies that actual usage is compatible with declared multiplicities.
;;;
;;; UsageCtx: a list of multiplicities parallel to Context, where position k
;;; records how many times bvar(k) has been used.
;;;
;;; inferQ(ctx, e) -> TypeUsage(type, usage)  or tu-error
;;; checkQ(ctx, e, T) -> BoolUsage(bool, usage)
;;;

(require racket/match
         racket/list
         "prelude.rkt"
         "syntax.rkt"
         "substitution.rkt"
         "reduction.rkt"
         "unify.rkt"
         "typing-core.rkt"
         "sign-refinement.rkt"  ;; Numerics N5de: refined-name?/refined-name->base
         "metavar-store.rkt"
         "elab-speculation-bridge.rkt"
         "global-env.rkt"
         (only-in "sre-core.rkt" make-sre-domain register-domain!)  ;; PPN 4C Phase 2
         (only-in "merge-fn-registry.rkt" register-merge-fn!/lattice))  ;; PPN 4C Phase 2

(provide
 ;; Usage context operations
 zero-usage single-usage add-usage join-usage scale-usage
 uhead utail ulen
 check-all-usages
 ;; Result types
 (struct-out tu) (struct-out tu-error) (struct-out bu)
 ;; QTT inference and checking
 inferQ checkQ checkQ-top
 ;; QTT P4: diagnostic support for typing-errors' multiplicity message —
 ;; defined beside the rules it mirrors so the two cannot drift
 explain-qtt-failure)

;; ========================================
;; Usage Context: plain list of multiplicities
;; ========================================

;; Create a zero-usage context of length n
(define (zero-usage n)
  (make-list n 'm0))

;; Create a usage with m1 at position k, m0 elsewhere, length n
(define (single-usage k n)
  (for/list ([i (in-range n)])
    (if (= i k) 'm1 'm0)))

;; Pointwise addition of usage contexts
(define (add-usage u1 u2)
  (cond
    [(and (null? u1) (null? u2)) '()]
    [(null? u1) u2]
    [(null? u2) u1]
    [else (cons (mult-add (car u1) (car u2))
                (add-usage (cdr u1) (cdr u2)))]))

;; Pointwise JOIN of usage contexts — the ALTERNATION combinator.
;;
;; Use this, NOT `add-usage`, when combining the branches of an eliminator that
;; runs exactly ONE of them (boolrec, the four posit if-nars, a match's arms).
;; `add-usage` stays correct for everything sequential — including an
;; eliminator's SCRUTINEE, which always runs. The canonical shape at an
;; alternation site is therefore
;;     (add-usage u-scrutinee (join-usage u-branch1 u-branch2))
;; and NOT a flat 3-way join. See `mult-join` (prelude.rkt) for why alternation
;; needs its own operator and why the swap is monotone-permissive.
;;
;; The two null shortcuts are cloned from `add-usage` deliberately and are sound
;; here for a DIFFERENT reason: there, a missing tail is all-m0 because m0 is the
;; additive IDENTITY; here it is sound because m0 is the lattice BOTTOM. Those
;; coincide for this order, so the same code is right both times — but the
;; reasoning does not transfer to any other table, so re-derive it if `mult-join`
;; ever changes.
;;
;; ⚠ NEITHER operator errors on length divergence — both silently PAD. A usage
;; vector that was not truncated back to the ambient ctx depth therefore produces
;; no error here; it surfaces far away as `check-all-usages` returning #f on a
;; length mismatch, i.e. as a spurious "Multiplicity violation". Callers that
;; combine vectors from DIFFERENT context depths (an eliminator whose arms bind a
;; per-arm number of fields) must truncate first and assert equal lengths
;; themselves — `join-usage` cannot catch it for them.
(define (join-usage u1 u2)
  (cond
    [(and (null? u1) (null? u2)) '()]
    [(null? u1) u2]
    [(null? u2) u1]
    [else (cons (mult-join (car u1) (car u2))
                (join-usage (cdr u1) (cdr u2)))]))

;; Do two branches of an eliminator AGREE about every LINEAR resource?
;;
;; This is what makes multiplicities LINEAR-PER-PATH rather than affine-per-path
;; (owner ruling, 2026-07-30 — see docs/tracking/2026-07-30_QTT_PATTERN_MATCHING_DESIGN.md
;; §1). `mult-join` is the honest lub of `mult-leq`, so `m0 ⊔ m1 = m1`, which on
;; its own would accept a linear resource consumed on SOME paths and dropped on
;; others. In a language with no implicit destructor that is not a laxer
;; discipline, it is a leak: dropping a `Handle` on a branch does not close it.
;; Verified on the real API before this guard existed —
;;   (boolrec … [fio-close h] unit c)   with h :1   type-checked clean.
;;
;; The guard is deliberately SEPARATE from the join rather than folded into it as
;; `m0 ⊔ m1 = mw`, because that table is not the lub of the tree's own order: it
;; would cost `m0` its identity status and silently invalidate `join-usage`'s
;; null shortcuts, and it would encode "dropped on a path" as "used many times".
;; Keeping the lattice honest and the discipline explicit separates the two.
;;
;; Fires ONLY at positions whose DECLARED multiplicity is m1:
;;   - m0 disagreement is already caught by `compatible m0 m1` downstream;
;;   - mw positions are unrestricted by definition and must stay free, or this
;;     would reject ordinary code en masse.
;; Equality (not merely "not one m0 and one m1") so that m1-vs-mw disagreement is
;; caught precisely here too, rather than downstream as a bare `compatible` fail.
;;
;; DECLINES (returns #t) on length divergence rather than rejecting: the vectors
;; are only meaningful when both are trimmed back to the ambient ctx depth, and a
;; bookkeeping slip must not manifest as a spurious linearity error. `ctx-extend`
;; front-conses, so usage index 0 is `ctx`'s car — the same parallelism
;; `check-all-usages` walks.
(define (branches-agree-on-linear? ctx u1 u2)
  (let loop ([c ctx] [a u1] [b u2])
    (cond
      [(or (null? c) (null? a) (null? b)) #t]
      [(and (eq? (cdar c) 'm1) (not (eq? (car a) (car b)))) #f]
      [else (loop (cdr c) (cdr a) (cdr b))])))

;; Is a LINEAR resource actually at stake in this accumulated usage? I.e. is
;; there a ctx position declared m1 that some branch has already consumed?
;;
;; QTT P6 (2026-07-31). Used to decide whether an UNANALYSABLE eliminator arm
;; can be safely ignored. It can, when nothing linear is in play — but when
;; another arm has consumed a linear resource and one arm cannot be analysed,
;; linear-per-path is UNDECIDABLE for that resource, and the honest answer is to
;; refuse rather than to guess "the skipped arm probably agreed".
;;
;; Only the "some surviving arm consumed it" direction needs this guard. The
;; mirror case — the SKIPPED arm consumes it and the surviving ones do not — is
;; already caught downstream: the surviving arms join to m0 at that position, and
;; `compatible m1 m0` then fails as "declared linear but is not used".
;; Returns the TYPE of the first such resource, or #f. `linear-at-stake?` is the
;; boolean face; the explainer wants the type so it can name what is at risk.
(define (first-linear-at-stake ctx usage)
  (let loop ([c ctx] [u usage])
    (cond
      [(or (null? c) (null? u)) #f]
      [(and (eq? (cdar c) 'm1) (not (eq? (car u) 'm0))) (caar c)]
      [else (loop (cdr c) (cdr u))])))

(define (linear-at-stake? ctx usage)
  (and (first-linear-at-stake ctx usage) #t))

;; THE alternation combinator for eliminator branches: the join, gated on
;; agreement. Returns the combined usage, or #f when the branches disagree about
;; a linear resource.
;;
;; This exists so the two operations CANNOT be separated. The guard and the join
;; must co-occur at every alternation site; leaving them as two calls made that a
;; discipline a future eliminator could forget — and forgetting silently restores
;; affine-per-path for that construct alone, with a green suite. Bundling them
;; makes it correct-by-construction instead: there is no way to join branch
;; usages without the linear check.
;;
;; Structural reading (worth keeping when typing eventually moves on-network):
;; the guard says the join must be EXACT at linear positions — u1 ⊔ u2 = u1 = u2
;; there. That is a side condition on the lattice operation, not an ad-hoc
;; comparison, and it is expressible as such wherever the join is expressed.
;;
;; `join-usage` remains available and exported for its own unit tests, but
;; ALTERNATION SITES SHOULD CALL THIS, not `join-usage` directly.
(define (join-branches ctx u1 u2)
  (and (branches-agree-on-linear? ctx u1 u2)
       (join-usage u1 u2)))

;; Validate and strip the first `bc` binder entries from a usage vector, using
;; the declared multiplicities at the front of `ext-ctx`. This is the lambda
;; arm's `(compatible declared (uhead u))` / `(utail u)` idiom (see checkQ's
;; expr-lam arm) iterated `bc` times, for eliminator arms that bind several
;; pattern fields at once.
;;
;; Returns the trimmed usage, or #f if a bound field violates its multiplicity
;; (e.g. a linear field duplicated inside the arm body).
;;
;; ⚠ Trimming is not optional bookkeeping: `join-usage`/`add-usage` silently PAD
;; on length divergence, so an untrimmed vector produces no error here and
;; instead surfaces far away as `check-all-usages` failing on a length mismatch —
;; i.e. as a spurious "Multiplicity violation" pointing at the wrong thing.
(define (strip-binders ext-ctx u bc)
  (let loop ([c ext-ctx] [u u] [k bc])
    (cond
      [(zero? k) u]
      [(or (null? c) (null? u)) #f]
      [(compatible (cdar c) (car u)) (loop (cdr c) (cdr u) (sub1 k))]
      [else #f])))

;; Scalar multiplication of usage context
(define (scale-usage m u)
  (map (lambda (x) (mult-mul m x)) u))

;; ============================================================
;; PPN 4C Phase 2: :usage facet SRE domain registration (A9)
;; ============================================================
;;
;; D2 framework per §6.9.2:
;;   Aspirational (original): commutative, associative, idempotent
;;     under same-vector (as if join-semilattice)
;;   Declared (γ): none initially; let inference inform
;;   Inference result (empirical, 2026-04-19): confirm comm + assoc;
;;     REFUTE idempotence — (add-usage '(m1) '(m1)) = '(mw), not '(m1)
;;   Delta: ACCEPT as design — :usage is a commutative MONOID (QTT
;;     semiring addition: m0+m1=m1, m1+m1=mw), not a join-semilattice.
;;     Each write contributes incrementally; cell accumulation is
;;     linear, not order-independent in the lattice sense.
;;     This is analogous to :context's accepted non-commutativity —
;;     monoidal structure, quantale-adjacent, not a simple lattice.
;;     R5 contingency: counted as 1 bug-found (accepted design); still
;;     within K=2 absorption.
;;
;; AMENDED 2026-07-30: the finding above stands for the CELL MERGE and for
;; SEQUENTIAL composition, which is all it was ever about — a cell accumulating
;; usage really is a monoid, and `add-usage` remains this domain's registered
;; merge. What the D2 note did not consider is ALTERNATION: an eliminator that
;; runs exactly one of its branches combines them with a JOIN, not with
;; addition. `:usage` therefore carries BOTH structures — a tensor
;; (`add-usage`, registered below) and a join (`join-usage`, above) — and the
;; refuted idempotence was refuted for the tensor only.
;;   The join is deliberately ARM-LOCAL and is NOT registered as a second SRE
;; relation: it is a typing-rule combinator for eliminator branches, not a
;; merge for concurrent writes to a cell. If a future design wants alternation
;; on-network (speculative branches merging into one usage cell), that is when
;; the domain gains a second relation — and this note is the pointer.

(define usage-merge-registry
  (lambda (rel-name)
    (case rel-name
      [(equality) add-usage]
      [else (error 'usage-merge-registry "no merge for relation: ~a" rel-name)])))

(define (usage-bot? v) (and (list? v) (null? v)))
(define (usage-contradicts? v) #f)  ;; no top-like contradiction state in usage vectors

(define usage-sre-domain
  (make-sre-domain
   #:name 'usage
   #:merge-registry usage-merge-registry
   #:contradicts? usage-contradicts?
   #:bot? usage-bot?
   #:bot-value '()))

(register-domain! usage-sre-domain)
(register-merge-fn!/lattice add-usage #:for-domain 'usage)

;; Head and tail
(define (uhead u) (car u))
(define (utail u) (cdr u))

;; Length
(define (ulen u) (length u))

;; ========================================
;; Check that actual usages are compatible with declared multiplicities
;; ========================================
(define (check-all-usages ctx usage)
  (cond
    [(and (null? ctx) (null? usage)) #t]
    [(or (null? ctx) (null? usage)) #f]
    [else
     (let ([decl-mult (cdar ctx)]   ; multiplicity from context binding
           [actual (car usage)])
       (and (compatible decl-mult actual)
            (check-all-usages (cdr ctx) (cdr usage))))]))

;; ========================================
;; Result types for QTT inference and checking
;; ========================================
(struct tu (type usage) #:transparent)       ; type + usage
(struct tu-error () #:transparent)           ; inference failed
(struct bu (ok? usage) #:transparent)        ; bool + usage

;; tu-type and tu-usage are auto-generated by the struct definition.
;; For tu-error, use (match r [(tu t u) ...] [(tu-error) ...]) patterns.

;; Helper
(define (cdar x) (cdr (car x)))

;; Helper: try inferQ for f, fall back to checkQ with expected-type if inferQ fails.
;; This handles both named functions (inferQ works) and lambdas (need checkQ).
(define (inferQ-or-checkQ ctx f expected-f-type)
  (let ([r (inferQ ctx f)])
    (match r
      [(tu _ _) r]
      [(tu-error)
       (let ([rc (checkQ ctx f expected-f-type)])
         (match rc
           [(bu #t u) (tu expected-f-type u)]
           [_ (tu-error)]))])))

;; ========================================
;; QTT inference: inferQ(ctx, e) -> TypeUsage
;; ========================================
(define (inferQ ctx e)
  (define n (ctx-len ctx))
  (match e
    ;; ---- Variable: bvar(K) uses position K exactly once ----
    [(expr-bvar k)
     (if (< k n)
         (tu (shift (+ k 1) 0 (lookup-type k ctx))
             (single-usage k n))
         (tu-error))]

    ;; ---- Free variable: look up global environment ----
    ;; Global references do not consume local linear resources.
    ;; Numerics N5de: nominal-erased refined numeric types are built-in types (: Type 0).
    [(expr-fvar (? refined-name? _)) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-fvar name)
     (let ([ty (global-env-lookup-type name)])
       (if ty
           (tu ty (zero-usage n))
           (tu-error)))]

    ;; ---- Constants: zero usage ----
    [(expr-Type l) (tu (expr-Type (lsuc l)) (zero-usage n))]
    [(expr-Nat) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-Bool) (tu (expr-Type (lzero)) (zero-usage n))]
    ;; CIU T6 F1a.2 p0 (bug fix): an UNSOLVED meta reaching inferQ in a
    ;; type-argument position (e.g. bare {}'s key-domain meta through
    ;; map-empty's inferQ) must not tu-error — it made `def m0 := {}` die as a
    ;; spurious "Multiplicity violation" (checkQ-top's generic reporter).
    ;; Mirrors checkQ's blanket expr-meta pass; type args are erased (m0-scaled)
    ;; by their consumers, so Type-0 + zero usage is the honest answer.
    [(expr-meta _ _) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-zero) (tu (expr-Nat) (zero-usage n))]
    [(expr-nat-val _) (tu (expr-Nat) (zero-usage n))]
    [(expr-true) (tu (expr-Bool) (zero-usage n))]
    [(expr-false) (tu (expr-Bool) (zero-usage n))]
    [(expr-Unit) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-unit) (tu (expr-Unit) (zero-usage n))]
    [(expr-Nil) (tu (expr-Type (lzero)) (zero-usage n))]
    ;; nil value: type is Nil (the nullable type).
    ;; Note: when List's nil constructor is loaded, the elaborator produces (expr-fvar 'nil)
    ;; instead — this case only fires for bare Nil usage without List loaded.
    [(expr-nil) (tu (expr-Nil) (zero-usage n))]
    [(expr-Int) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-int _) (tu (expr-Int) (zero-usage n))]
    [(expr-Rat) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-rat _) (tu (expr-Rat) (zero-usage n))]
    [(expr-Posit8) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-posit8 _) (tu (expr-Posit8) (zero-usage n))]
    ;; Posit16
    [(expr-Posit16) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-posit16 _) (tu (expr-Posit16) (zero-usage n))]
    ;; Posit32
    [(expr-Posit32) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-posit32 _) (tu (expr-Posit32) (zero-usage n))]
    ;; Float (Numerics N3)
    [(expr-Float32) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-float32 _) (tu (expr-Float32) (zero-usage n))]
    [(expr-Float64) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-float64 _) (tu (expr-Float64) (zero-usage n))]
    ;; Posit64
    [(expr-Posit64) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-posit64 _) (tu (expr-Posit64) (zero-usage n))]
    ;; Quire types and values (zero-usage: type formers and literals)
    [(expr-Quire8) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-quire8-val _) (tu (expr-Quire8) (zero-usage n))]
    [(expr-Quire16) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-quire16-val _) (tu (expr-Quire16) (zero-usage n))]
    [(expr-Quire32) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-quire32-val _) (tu (expr-Quire32) (zero-usage n))]
    [(expr-Quire64) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-quire64-val _) (tu (expr-Quire64) (zero-usage n))]

    ;; Unapplied type constructor (HKT) — zero usage, kind from kind table
    [(expr-tycon _) (tu (infer ctx e) (zero-usage n))]

    ;; ---- Type formers: Pi, Sigma, Eq ----
    ;; Type formers inhabit Type. Usage comes from sub-terms.
    ;; For top-level QTT checking of closed terms, these will have zero usage.
    [(expr-Pi m a b)
     (let ([r1 (inferQ ctx a)])
       (match r1
         [(tu _ u1)
          (let ([r2 (inferQ (ctx-extend ctx a m) b)])
            (match r2
              [(tu _ u2)
               (tu (expr-Type (lzero)) (add-usage u1 (utail u2)))]
              [_ (tu-error)]))]
         [_ (tu-error)]))]
    [(expr-Sigma a b)
     (let ([r1 (inferQ ctx a)])
       (match r1
         [(tu _ u1)
          (let ([r2 (inferQ (ctx-extend ctx a 'mw) b)])
            (match r2
              [(tu _ u2)
               (tu (expr-Type (lzero)) (add-usage u1 (utail u2)))]
              [_ (tu-error)]))]
         [_ (tu-error)]))]
    [(expr-Eq ty e1 e2)
     (let* ([r1 (inferQ ctx ty)]
            [r2 (inferQ ctx e1)]
            [r3 (inferQ ctx e2)])
       (match* (r1 r2 r3)
         [((tu _ u1) (tu _ u2) (tu _ u3))
          (tu (expr-Type (lzero)) (add-usage u1 (add-usage u2 u3)))]
         [(_ _ _) (tu-error)]))]
    [(expr-union l r)
     (let ([rl (inferQ ctx l)]
           [rr (inferQ ctx r)])
       (match* (rl rr)
         [((tu _ u1) (tu _ u2))
          (tu (expr-Type (lzero)) (add-usage u1 u2))]
         [(_ _) (or (and (tu-error? rl) rl) (and (tu-error? rr) rr) (tu-error))]))]

    ;; ---- Suc: usage from the argument ----
    [(expr-suc e1)
     (let ([r (inferQ ctx e1)])
       (match r
         [(tu (expr-Nat) u) (tu (expr-Nat) u)]
         [_ (tu-error)]))]

    ;; ---- Annotation: ann(e, T) ----
    [(expr-ann e1 t)
     ;; Numerics N5de: ascription to a refined numeric type = erased narrowing cast (mirror typing-core).
     (let ([tw (whnf t)])
       (cond
         [(and (expr-fvar? tw) (refined-name? (expr-fvar-name tw)))
          (let ([r (checkQ ctx e1 (if (eq? (refined-name->base (expr-fvar-name tw)) 'Int) (expr-Int) (expr-Rat)))])
            (match r [(bu #t u) (tu t u)] [_ (tu-error)]))]
         [(is-type ctx t)
          (let ([r (checkQ ctx e1 t)])
            (match r [(bu #t u) (tu t u)] [_ (tu-error)]))]
         [else (tu-error)]))]

    ;; ---- Application ----
    ;; Usage = U_func + pi * U_arg
    [(expr-app e1 e2)
     (cond
       ;; Issue #71 (Stage-2 twin of typing-core): a saturated multi-hole section
       ;; → whnf-reduce then inferQ the lambda-free concrete form. Same guard.
       [(saturated-hole-section-app? e) (inferQ ctx (whnf e))]
       [else
     (match e1
       ;; Special case: app(lam(m, dom, body), arg) — beta-typed application
       ;; This supports let-expansion: (let x := v body) = app(lam(m, dom, body), v)
       [(expr-lam m dom body)
        (let ([arg-dom (if (or (expr-hole? dom) (expr-typed-hole? dom))
                           ;; Infer arg type for hole domain
                           (let ([ri (inferQ ctx e2)])
                             (match ri [(tu t _) t] [_ #f]))
                           dom)])
          (if (not arg-dom)
              (tu-error)
              (let ([r2 (checkQ ctx e2 arg-dom)])
                (match r2
                  [(bu #t u2)
                   (let ([r-body (inferQ (ctx-extend ctx arg-dom m) body)])
                     (match r-body
                       [(tu body-ty u-body)
                        (tu (subst 0 e2 body-ty)
                            (add-usage (scale-usage m u2) (utail u-body)))]
                       [_ (tu-error)]))]
                  [_ (tu-error)]))))]
       ;; General case: infer function type, check argument
       [_
        (let ([r1 (inferQ ctx e1)])
          (match r1
            [(tu t1 u1)
             (match (whnf t1)
               [(expr-Pi m a b)
                (let ([r2 (checkQ ctx e2 a)])
                  (match r2
                    [(bu #t u2)
                     (tu (subst 0 e2 b) (add-usage u1 (scale-usage m u2)))]
                    [_ (tu-error)]))]
               [_ (tu-error)])]
            [_ (tu-error)]))])])]

    ;; ---- fst ----
    [(expr-fst e1)
     (let ([r (inferQ ctx e1)])
       (match r
         [(tu t u)
          (match (whnf t)
            [(expr-Sigma a _) (tu a u)]
            [_ (tu-error)])]
         [_ (tu-error)]))]

    ;; ---- snd ----
    [(expr-snd e1)
     (let ([r (inferQ ctx e1)])
       (match r
         [(tu t u)
          (match (whnf t)
            [(expr-Sigma _ b) (tu (subst 0 (expr-fst e1) b) u)]
            [_ (tu-error)])]
         [_ (tu-error)]))]

    ;; ---- Vec eliminators (QTT P5, 2026-07-30) ----
    ;; Usage passes the SUBJECT's usage through unchanged — exactly the fst/snd
    ;; projection stance directly above. The discarded part of the vector (the
    ;; tail for vhead, the head for vtail, every other element for vindex) is
    ;; weakening that is invisible to variable-level usage accounting, just as
    ;; `fst` discarding a pair's second component is. That is the codebase's
    ;; existing position on projection, not a new laxity introduced here.
    ;;
    ;; The TYPE is delegated to typing-core's own infer arms (`vhead`/`vtail`/
    ;; `vindex`) — the no-drift twin pattern: one derivation, two consumers.
    ;; A/n are type-level indices and contribute nothing.

    [(expr-vhead a n0 v)
     (let ([ty (infer ctx e)])
       (if (expr-error? ty)
           (tu-error)
           (match (checkQ ctx v (expr-Vec a (expr-suc n0)))
             [(bu #t u) (tu ty u)]
             [_ (tu-error)])))]

    [(expr-vtail a n0 v)
     (let ([ty (infer ctx e)])
       (if (expr-error? ty)
           (tu-error)
           (match (checkQ ctx v (expr-Vec a (expr-suc n0)))
             [(bu #t u) (tu ty u)]
             [_ (tu-error)])))]

    ;; vindex additionally consumes its INDEX: `i` is a runtime Fin value that
    ;; selects the element, so its usage is added to the vector's. (A linear
    ;; vector indexed twice therefore errors — conservative and sound.)
    [(expr-vindex a n0 i v)
     (let ([ty (infer ctx e)])
       (if (expr-error? ty)
           (tu-error)
           (match* ((checkQ ctx i (expr-Fin n0)) (checkQ ctx v (expr-Vec a n0)))
             [((bu #t u-i) (bu #t u-v)) (tu ty (add-usage u-i u-v))]
             [(_ _) (tu-error)])))]

    ;; ---- Foreign function value (QTT P5) ----
    ;; A foreign function is a Racket procedure plus marshalling metadata; the
    ;; only field that can hold Prologos expressions is `args`, the accumulator
    ;; for curried partial application. At every position reachable from
    ;; elaboration `args` is '() — captured variables live OUTSIDE the node, as
    ;; arguments of an enclosing `expr-app` — so this folds to zero usage. The
    ;; fold is written out anyway rather than hardcoding zero, so a value that
    ;; did carry args would still have them counted.
    ;;
    ;; ⚠ TYPE CAVEAT, shared with the typing twin: `global-env-lookup-type`
    ;; returns the FULL registered Pi, which is arity-wrong for a node that has
    ;; already accumulated args (it should be the remainder after (length args)
    ;; applications). typing-core's infer arm has the identical flaw, so this
    ;; matches its twin rather than silently diverging — filed in DEFERRED.md
    ;; rather than fixed here, because fixing it means fixing both.
    [(expr-foreign-fn _ _ _ args _ _ _ _)
     (let ([ty (infer ctx e)])
       (if (expr-error? ty)
           (tu-error)
           (let loop ([as args] [acc (zero-usage n)])
             (cond
               [(null? as) (tu ty acc)]
               [else (match (inferQ ctx (car as))
                       [(tu _ ua) (loop (cdr as) (add-usage acc ua))]
                       [_ (tu-error)])]))))]

    ;; ---- natrec ----
    ;; Usage = U_target + U_base + ω·U_step   (motive is type-level)
    ;;
    ;; NOT a join across base/step — they are not mutually exclusive
    ;; alternatives, so the P1 branch-join treatment does not apply here. But
    ;; `add-usage` alone was ALSO wrong: `step` has type
    ;; Π(n:Nat). motive(n) → motive(suc n) and is applied 0..n times, while its
    ;; usage was added exactly ONCE. A linear value captured in the step was
    ;; counted m1 however many times it was consumed.
    ;;
    ;; ω-SCALING IS NOT A NEW RULE — it is the app rule, finally applied here.
    ;; `(add-usage u1 (scale-usage m u2))` is what the general application arm
    ;; does with every argument: scale by the binder's multiplicity. This arm
    ;; SYNTHESIZES an mw Pi for `step` and then failed to scale by it. Spelled as
    ;; an ordinary function with `step` at ω, the app rule would have produced
    ;; the right answer for free.
    ;;
    ;; It catches BOTH failure directions at once, because m1 demands
    ;; exactly-once and mw is neither: over-application (n>1) and the
    ;; zero-iteration leak (n=0, the step never runs and a linear is never
    ;; consumed). Erasure is safe — mult-mul mw m0 = m0 — so an erased capture
    ;; stays erased, and a CLOSED step is unaffected (all-m0 scales to all-m0).
    ;; Escape hatch for code this rejects: thread the resource through the
    ;; motive/accumulator instead of capturing it, which keeps the step closed.
    [(expr-natrec mot base step target)
     (let ([step-type
            ;; Π(n:Nat). motive(n) → motive(suc(n))
            (expr-Pi 'mw (expr-Nat)
              (expr-Pi 'mw (expr-app (shift 1 0 mot) (expr-bvar 0))
                (expr-app (shift 2 0 mot) (expr-suc (expr-bvar 1)))))])
       (let ([r4 (checkQ ctx target (expr-Nat))])
         (match r4
           [(bu #t u4)
            (let ([r2 (checkQ ctx base (expr-app mot (expr-zero)))])
              (match r2
                [(bu #t u2)
                 (let ([r3 (checkQ ctx step step-type)])
                   (match r3
                     [(bu #t u3)
                      (tu (expr-app mot target)
                          (add-usage u4 (add-usage u2 (scale-usage 'mw u3))))]
                     [_ (tu-error)]))]
                [_ (tu-error)]))]
           [_ (tu-error)])))]

    ;; ---- boolrec ----
    ;; Usage = U_target + (U_true-case ⊔ U_false-case)   (motive is type-level)
    ;; boolrec(motive, true-case, false-case, target)
    ;;
    ;; The target ADDS (it always runs); the two branches JOIN (exactly one
    ;; runs). Before 2026-07-30 both were added, which rejected
    ;;   spec both Box -1> Bool -> Box / defn both [b c] (if c b b)
    ;; even though `b` is used exactly once on every execution path — m1+m1 = mw.
    ;; See `mult-join` (prelude.rkt) for the one-cell difference and why the swap
    ;; cannot reject any program it previously accepted.
    [(expr-boolrec mot tc fc target)
     (let ([r4 (checkQ ctx target (expr-Bool))])
       (match r4
         [(bu #t u4)
          (let ([r2 (checkQ ctx tc (expr-app mot (expr-true)))])
            (match r2
              [(bu #t u2)
               (let ([r3 (checkQ ctx fc (expr-app mot (expr-false)))])
                 (match r3
                   [(bu #t u3)
                    (let ([uj (join-branches ctx u2 u3)])
                      (if uj
                          (tu (expr-app mot target) (add-usage u4 uj))
                          (tu-error)))]
                   [_ (tu-error)]))]
              [_ (tu-error)]))]
         [_ (tu-error)]))]

    ;; ---- Int binary operations ----
    ;; Binary ops: Int -> Int -> Int
    [(expr-int-add a b)
     (let ([r1 (checkQ ctx a (expr-Int))]
           [r2 (checkQ ctx b (expr-Int))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Int) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-int-sub a b)
     (let ([r1 (checkQ ctx a (expr-Int))]
           [r2 (checkQ ctx b (expr-Int))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Int) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-int-mul a b)
     (let ([r1 (checkQ ctx a (expr-Int))]
           [r2 (checkQ ctx b (expr-Int))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Int) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-int-div a b)
     (let ([r1 (checkQ ctx a (expr-Int))]
           [r2 (checkQ ctx b (expr-Int))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Int) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-int-mod a b)
     (let ([r1 (checkQ ctx a (expr-Int))]
           [r2 (checkQ ctx b (expr-Int))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Int) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]

    ;; Unary Int ops: Int -> Int
    [(expr-int-neg a)
     (let ([r (inferQ ctx a)])
       (match r [(tu (expr-Int) u) (tu (expr-Int) u)] [_ (tu-error)]))]
    [(expr-int-abs a)
     (let ([r (inferQ ctx a)])
       (match r [(tu (expr-Int) u) (tu (expr-Int) u)] [_ (tu-error)]))]

    ;; Int comparisons: Int -> Int -> Bool
    [(expr-int-lt a b)
     (let ([r1 (checkQ ctx a (expr-Int))]
           [r2 (checkQ ctx b (expr-Int))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Bool) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-int-le a b)
     (let ([r1 (checkQ ctx a (expr-Int))]
           [r2 (checkQ ctx b (expr-Int))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Bool) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-int-eq a b)
     (let ([r1 (checkQ ctx a (expr-Int))]
           [r2 (checkQ ctx b (expr-Int))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Bool) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]

    ;; Int conversion: Nat -> Int
    [(expr-from-nat e1)
     (let ([r (checkQ ctx e1 (expr-Nat))])
       (match r [(bu #t u) (tu (expr-Int) u)] [_ (tu-error)]))]

    ;; ---- Rat binary operations ----
    ;; Binary ops: Rat -> Rat -> Rat
    [(expr-rat-add a b)
     (let ([r1 (checkQ ctx a (expr-Rat))]
           [r2 (checkQ ctx b (expr-Rat))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Rat) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-rat-sub a b)
     (let ([r1 (checkQ ctx a (expr-Rat))]
           [r2 (checkQ ctx b (expr-Rat))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Rat) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-rat-mul a b)
     (let ([r1 (checkQ ctx a (expr-Rat))]
           [r2 (checkQ ctx b (expr-Rat))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Rat) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-rat-div a b)
     (let ([r1 (checkQ ctx a (expr-Rat))]
           [r2 (checkQ ctx b (expr-Rat))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Rat) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]

    ;; Unary Rat ops: Rat -> Rat
    [(expr-rat-neg a)
     (let ([r (inferQ ctx a)])
       (match r [(tu (expr-Rat) u) (tu (expr-Rat) u)] [_ (tu-error)]))]
    [(expr-rat-abs a)
     (let ([r (inferQ ctx a)])
       (match r [(tu (expr-Rat) u) (tu (expr-Rat) u)] [_ (tu-error)]))]

    ;; Rat comparisons: Rat -> Rat -> Bool
    [(expr-rat-lt a b)
     (let ([r1 (checkQ ctx a (expr-Rat))]
           [r2 (checkQ ctx b (expr-Rat))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Bool) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-rat-le a b)
     (let ([r1 (checkQ ctx a (expr-Rat))]
           [r2 (checkQ ctx b (expr-Rat))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Bool) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-rat-eq a b)
     (let ([r1 (checkQ ctx a (expr-Rat))]
           [r2 (checkQ ctx b (expr-Rat))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Bool) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]

    ;; Rat conversion: Int -> Rat
    [(expr-from-int e1)
     (let ([r (checkQ ctx e1 (expr-Int))])
       (match r [(bu #t u) (tu (expr-Rat) u)] [_ (tu-error)]))]

    ;; Rat projections: Rat -> Int
    [(expr-rat-numer a)
     (let ([r (inferQ ctx a)])
       (match r [(tu (expr-Rat) u) (tu (expr-Int) u)] [_ (tu-error)]))]
    [(expr-rat-denom a)
     (let ([r (inferQ ctx a)])
       (match r [(tu (expr-Rat) u) (tu (expr-Int) u)] [_ (tu-error)]))]

    ;; ---- Generic arithmetic operators ----
    ;; Binary arithmetic: infer both args, return same type
    [(expr-generic-add a b)
     (let ([r1 (inferQ ctx a)]
           [r2 (inferQ ctx b)])
       (match* (r1 r2)
         [((tu t1 u1) (tu t2 u2))
          (let ([j (numeric-join t1 t2)])          ;; N5de: base via numeric-join (mixed refined+bare OK); sign via transfer
            (if (and j (concrete-numeric-type? j))
                (tu (refine-arith t1 t2 j sign-transfer-add) (add-usage u1 u2))
                (tu-error)))]
         [(_ _) (tu-error)]))]
    [(expr-generic-sub a b)
     (let ([r1 (inferQ ctx a)]
           [r2 (inferQ ctx b)])
       (match* (r1 r2)
         [((tu t1 u1) (tu t2 u2))
          (let ([j (numeric-join t1 t2)])
            (if (and j (concrete-numeric-type? j))
                (tu (refine-arith t1 t2 j sign-transfer-sub) (add-usage u1 u2))
                (tu-error)))]
         [(_ _) (tu-error)]))]
    [(expr-generic-mul a b)
     (let ([r1 (inferQ ctx a)]
           [r2 (inferQ ctx b)])
       (match* (r1 r2)
         [((tu t1 u1) (tu t2 u2))
          (let ([j (numeric-join t1 t2)])
            (if (and j (concrete-numeric-type? j))
                (tu (refine-arith t1 t2 j sign-transfer-mul) (add-usage u1 u2))
                (tu-error)))]
         [(_ _) (tu-error)]))]
    [(expr-generic-div a b)
     (let ([r1 (inferQ ctx a)]
           [r2 (inferQ ctx b)])
       (match* (r1 r2)
         [((tu t1 u1) (tu t2 u2))
          (let ([j (numeric-join t1 t2)])
            (if (and j (divisible-numeric-type? j))
                (tu (refine-arith t1 t2 j sign-transfer-div) (add-usage u1 u2))
                (tu-error)))]
         [(_ _) (tu-error)]))]

    ;; Binary comparison: infer both args, return Bool
    [(expr-generic-lt a b)
     (let ([r1 (inferQ ctx a)]
           [r2 (inferQ ctx b)])
       (match* (r1 r2)
         [((tu t1 u1) (tu t2 u2))
          (let ([j (numeric-join t1 t2)])
            (if (and j (concrete-numeric-type? j))
                (tu (expr-Bool) (add-usage u1 u2))
                (tu-error)))]
         [(_ _) (tu-error)]))]
    [(expr-generic-le a b)
     (let ([r1 (inferQ ctx a)]
           [r2 (inferQ ctx b)])
       (match* (r1 r2)
         [((tu t1 u1) (tu t2 u2))
          (let ([j (numeric-join t1 t2)])
            (if (and j (concrete-numeric-type? j))
                (tu (expr-Bool) (add-usage u1 u2))
                (tu-error)))]
         [(_ _) (tu-error)]))]
    [(expr-generic-gt a b)
     (let ([r1 (inferQ ctx a)]
           [r2 (inferQ ctx b)])
       (match* (r1 r2)
         [((tu t1 u1) (tu t2 u2))
          (let ([j (numeric-join t1 t2)])
            (if (and j (concrete-numeric-type? j))
                (tu (expr-Bool) (add-usage u1 u2))
                (tu-error)))]
         [(_ _) (tu-error)]))]
    [(expr-generic-ge a b)
     (let ([r1 (inferQ ctx a)]
           [r2 (inferQ ctx b)])
       (match* (r1 r2)
         [((tu t1 u1) (tu t2 u2))
          (let ([j (numeric-join t1 t2)])
            (if (and j (concrete-numeric-type? j))
                (tu (expr-Bool) (add-usage u1 u2))
                (tu-error)))]
         [(_ _) (tu-error)]))]
    [(expr-generic-eq a b)
     (let ([r1 (inferQ ctx a)]
           [r2 (inferQ ctx b)])
       (match* (r1 r2)
         [((tu t1 u1) (tu t2 u2))
          (let ([j (numeric-join t1 t2)])
            (if (and j (concrete-numeric-type? j))
                (tu (expr-Bool) (add-usage u1 u2))
                (tu-error)))]
         [(_ _) (tu-error)]))]
    [(expr-generic-mod a b)
     (let ([r1 (inferQ ctx a)]
           [r2 (inferQ ctx b)])
       (match* (r1 r2)
         [((tu t1 u1) (tu t2 u2))
          (let ([j (numeric-join t1 t2)])          ;; N5de: mod unrefined — result is the base
            (if (and j (concrete-numeric-type? j))
                (tu j (add-usage u1 u2))
                (tu-error)))]
         [(_ _) (tu-error)]))]

    ;; Unary: infer arg, return same type
    [(expr-generic-negate a)
     (let ([r (inferQ ctx a)])
       (match r
         [(tu t u) (let ([bt (base-numeric-type t)])
                     (if (negatable-numeric-type? bt) (tu (refine-arith1 t bt sign-transfer-neg) u) (tu-error)))]
         [_ (tu-error)]))]
    [(expr-generic-abs a)
     (let ([r (inferQ ctx a)])
       (match r
         [(tu t u) (let ([bt (base-numeric-type t)])
                     (if (concrete-numeric-type? bt) (tu (refine-arith1 t bt sign-transfer-abs) u) (tu-error)))]
         [_ (tu-error)]))]

    ;; Generic conversion: from-integer TargetType val, from-rational TargetType val
    ;; target-type is erased (it's a type), usage comes from the arg
    [(expr-generic-from-int target-type arg)
     (let ([r (checkQ ctx arg (expr-Int))])
       (match r
         [(bu #t u) (if (from-int-target-type? target-type)
                        (tu target-type u)
                        (tu-error))]
         [_ (tu-error)]))]
    [(expr-generic-from-rat target-type arg)
     (let ([r (checkQ ctx arg (expr-Rat))])
       (match r
         [(bu #t u) (if (from-rat-target-type? target-type)
                        (tu target-type u)
                        (tu-error))]
         [_ (tu-error)]))]

    ;; ---- Posit8 binary operations ----
    ;; Binary ops: Posit8 -> Posit8 -> Posit8
    [(expr-p8-add a b)
     (let ([r1 (checkQ ctx a (expr-Posit8))]
           [r2 (checkQ ctx b (expr-Posit8))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Posit8) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-p8-sub a b)
     (let ([r1 (checkQ ctx a (expr-Posit8))]
           [r2 (checkQ ctx b (expr-Posit8))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Posit8) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-p8-mul a b)
     (let ([r1 (checkQ ctx a (expr-Posit8))]
           [r2 (checkQ ctx b (expr-Posit8))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Posit8) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-p8-div a b)
     (let ([r1 (checkQ ctx a (expr-Posit8))]
           [r2 (checkQ ctx b (expr-Posit8))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Posit8) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]

    ;; Unary Posit8 ops: Posit8 -> Posit8
    [(expr-p8-neg a)
     (let ([r (inferQ ctx a)])
       (match r [(tu (expr-Posit8) u) (tu (expr-Posit8) u)] [_ (tu-error)]))]
    [(expr-p8-abs a)
     (let ([r (inferQ ctx a)])
       (match r [(tu (expr-Posit8) u) (tu (expr-Posit8) u)] [_ (tu-error)]))]
    [(expr-p8-sqrt a)
     (let ([r (inferQ ctx a)])
       (match r [(tu (expr-Posit8) u) (tu (expr-Posit8) u)] [_ (tu-error)]))]

    ;; Posit8 comparisons: Posit8 -> Posit8 -> Bool
    [(expr-p8-lt a b)
     (let ([r1 (checkQ ctx a (expr-Posit8))]
           [r2 (checkQ ctx b (expr-Posit8))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Bool) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-p8-le a b)
     (let ([r1 (checkQ ctx a (expr-Posit8))]
           [r2 (checkQ ctx b (expr-Posit8))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Bool) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-p8-eq a b)
     (let ([r1 (checkQ ctx a (expr-Posit8))]
           [r2 (checkQ ctx b (expr-Posit8))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Bool) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]

    ;; Posit8 conversion: Nat -> Posit8
    [(expr-p8-from-nat e1)
     (let ([r (checkQ ctx e1 (expr-Nat))])
       (match r [(bu #t u) (tu (expr-Posit8) u)] [_ (tu-error)]))]

    ;; Phase 3f: Cross-family conversions for Posit8
    [(expr-p8-to-rat e1)
     (let ([r (checkQ ctx e1 (expr-Posit8))])
       (match r [(bu #t u) (tu (expr-Rat) u)] [_ (tu-error)]))]
    [(expr-p8-from-rat e1)
     (let ([r (checkQ ctx e1 (expr-Rat))])
       (match r [(bu #t u) (tu (expr-Posit8) u)] [_ (tu-error)]))]
    [(expr-p8-from-int e1)
     (let ([r (checkQ ctx e1 (expr-Int))])
       (match r [(bu #t u) (tu (expr-Posit8) u)] [_ (tu-error)]))]

    ;; Posit8 NaR eliminator: p8-if-nar(A, nar-case, normal-case, val)
    [(expr-p8-if-nar ty nar-case normal-case val)
     (let ([r4 (checkQ ctx val (expr-Posit8))])
       (match r4
         [(bu #t u4)
          (let ([r2 (checkQ ctx nar-case ty)])
            (match r2
              [(bu #t u2)
               (let ([r3 (checkQ ctx normal-case ty)])
                 (match r3
                   [(bu #t u3)
                    (let ([uj (join-branches ctx u2 u3)])
                      (if uj (tu ty (add-usage u4 uj)) (tu-error)))]
                   [_ (tu-error)]))]
              [_ (tu-error)]))]
         [_ (tu-error)]))]

    ;; ---- Posit16 binary operations ----
    ;; Binary ops: Posit16 -> Posit16 -> Posit16
    [(expr-p16-add a b)
     (let ([r1 (checkQ ctx a (expr-Posit16))]
           [r2 (checkQ ctx b (expr-Posit16))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Posit16) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-p16-sub a b)
     (let ([r1 (checkQ ctx a (expr-Posit16))]
           [r2 (checkQ ctx b (expr-Posit16))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Posit16) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-p16-mul a b)
     (let ([r1 (checkQ ctx a (expr-Posit16))]
           [r2 (checkQ ctx b (expr-Posit16))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Posit16) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-p16-div a b)
     (let ([r1 (checkQ ctx a (expr-Posit16))]
           [r2 (checkQ ctx b (expr-Posit16))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Posit16) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]

    ;; Unary Posit16 ops: Posit16 -> Posit16
    [(expr-p16-neg a)
     (let ([r (inferQ ctx a)])
       (match r [(tu (expr-Posit16) u) (tu (expr-Posit16) u)] [_ (tu-error)]))]
    [(expr-p16-abs a)
     (let ([r (inferQ ctx a)])
       (match r [(tu (expr-Posit16) u) (tu (expr-Posit16) u)] [_ (tu-error)]))]
    [(expr-p16-sqrt a)
     (let ([r (inferQ ctx a)])
       (match r [(tu (expr-Posit16) u) (tu (expr-Posit16) u)] [_ (tu-error)]))]

    ;; Posit16 comparisons: Posit16 -> Posit16 -> Bool
    [(expr-p16-lt a b)
     (let ([r1 (checkQ ctx a (expr-Posit16))]
           [r2 (checkQ ctx b (expr-Posit16))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Bool) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-p16-le a b)
     (let ([r1 (checkQ ctx a (expr-Posit16))]
           [r2 (checkQ ctx b (expr-Posit16))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Bool) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-p16-eq a b)
     (let ([r1 (checkQ ctx a (expr-Posit16))]
           [r2 (checkQ ctx b (expr-Posit16))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Bool) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]

    ;; Posit16 conversion: Nat -> Posit16
    [(expr-p16-from-nat e1)
     (let ([r (checkQ ctx e1 (expr-Nat))])
       (match r [(bu #t u) (tu (expr-Posit16) u)] [_ (tu-error)]))]

    ;; Phase 3f: Cross-family conversions for Posit16
    [(expr-p16-to-rat e1)
     (let ([r (checkQ ctx e1 (expr-Posit16))])
       (match r [(bu #t u) (tu (expr-Rat) u)] [_ (tu-error)]))]
    [(expr-p16-from-rat e1)
     (let ([r (checkQ ctx e1 (expr-Rat))])
       (match r [(bu #t u) (tu (expr-Posit16) u)] [_ (tu-error)]))]
    [(expr-p16-from-int e1)
     (let ([r (checkQ ctx e1 (expr-Int))])
       (match r [(bu #t u) (tu (expr-Posit16) u)] [_ (tu-error)]))]

    ;; Posit16 NaR eliminator: p16-if-nar(A, nar-case, normal-case, val)
    [(expr-p16-if-nar ty nar-case normal-case val)
     (let ([r4 (checkQ ctx val (expr-Posit16))])
       (match r4
         [(bu #t u4)
          (let ([r2 (checkQ ctx nar-case ty)])
            (match r2
              [(bu #t u2)
               (let ([r3 (checkQ ctx normal-case ty)])
                 (match r3
                   [(bu #t u3)
                    (let ([uj (join-branches ctx u2 u3)])
                      (if uj (tu ty (add-usage u4 uj)) (tu-error)))]
                   [_ (tu-error)]))]
              [_ (tu-error)]))]
         [_ (tu-error)]))]

    ;; ---- Float32/Float64 ops (Numerics N3b) ----
    [(expr-f32-add a b)
     (let ([r1 (checkQ ctx a (expr-Float32))] [r2 (checkQ ctx b (expr-Float32))])
       (match* (r1 r2) [((bu #t u1) (bu #t u2)) (tu (expr-Float32) (add-usage u1 u2))] [(_ _) (tu-error)]))]
    [(expr-f32-sub a b)
     (let ([r1 (checkQ ctx a (expr-Float32))] [r2 (checkQ ctx b (expr-Float32))])
       (match* (r1 r2) [((bu #t u1) (bu #t u2)) (tu (expr-Float32) (add-usage u1 u2))] [(_ _) (tu-error)]))]
    [(expr-f32-mul a b)
     (let ([r1 (checkQ ctx a (expr-Float32))] [r2 (checkQ ctx b (expr-Float32))])
       (match* (r1 r2) [((bu #t u1) (bu #t u2)) (tu (expr-Float32) (add-usage u1 u2))] [(_ _) (tu-error)]))]
    [(expr-f32-div a b)
     (let ([r1 (checkQ ctx a (expr-Float32))] [r2 (checkQ ctx b (expr-Float32))])
       (match* (r1 r2) [((bu #t u1) (bu #t u2)) (tu (expr-Float32) (add-usage u1 u2))] [(_ _) (tu-error)]))]
    [(expr-f32-neg a)
     (let ([r (inferQ ctx a)]) (match r [(tu (expr-Float32) u) (tu (expr-Float32) u)] [_ (tu-error)]))]
    [(expr-f32-abs a)
     (let ([r (inferQ ctx a)]) (match r [(tu (expr-Float32) u) (tu (expr-Float32) u)] [_ (tu-error)]))]
    [(expr-f32-sqrt a)
     (let ([r (inferQ ctx a)]) (match r [(tu (expr-Float32) u) (tu (expr-Float32) u)] [_ (tu-error)]))]
    [(expr-f32-lt a b)
     (let ([r1 (checkQ ctx a (expr-Float32))] [r2 (checkQ ctx b (expr-Float32))])
       (match* (r1 r2) [((bu #t u1) (bu #t u2)) (tu (expr-Bool) (add-usage u1 u2))] [(_ _) (tu-error)]))]
    [(expr-f32-le a b)
     (let ([r1 (checkQ ctx a (expr-Float32))] [r2 (checkQ ctx b (expr-Float32))])
       (match* (r1 r2) [((bu #t u1) (bu #t u2)) (tu (expr-Bool) (add-usage u1 u2))] [(_ _) (tu-error)]))]
    [(expr-f32-eq a b)
     (let ([r1 (checkQ ctx a (expr-Float32))] [r2 (checkQ ctx b (expr-Float32))])
       (match* (r1 r2) [((bu #t u1) (bu #t u2)) (tu (expr-Bool) (add-usage u1 u2))] [(_ _) (tu-error)]))]
    [(expr-f64-add a b)
     (let ([r1 (checkQ ctx a (expr-Float64))] [r2 (checkQ ctx b (expr-Float64))])
       (match* (r1 r2) [((bu #t u1) (bu #t u2)) (tu (expr-Float64) (add-usage u1 u2))] [(_ _) (tu-error)]))]
    [(expr-f64-sub a b)
     (let ([r1 (checkQ ctx a (expr-Float64))] [r2 (checkQ ctx b (expr-Float64))])
       (match* (r1 r2) [((bu #t u1) (bu #t u2)) (tu (expr-Float64) (add-usage u1 u2))] [(_ _) (tu-error)]))]
    [(expr-f64-mul a b)
     (let ([r1 (checkQ ctx a (expr-Float64))] [r2 (checkQ ctx b (expr-Float64))])
       (match* (r1 r2) [((bu #t u1) (bu #t u2)) (tu (expr-Float64) (add-usage u1 u2))] [(_ _) (tu-error)]))]
    [(expr-f64-div a b)
     (let ([r1 (checkQ ctx a (expr-Float64))] [r2 (checkQ ctx b (expr-Float64))])
       (match* (r1 r2) [((bu #t u1) (bu #t u2)) (tu (expr-Float64) (add-usage u1 u2))] [(_ _) (tu-error)]))]
    [(expr-f64-neg a)
     (let ([r (inferQ ctx a)]) (match r [(tu (expr-Float64) u) (tu (expr-Float64) u)] [_ (tu-error)]))]
    [(expr-f64-abs a)
     (let ([r (inferQ ctx a)]) (match r [(tu (expr-Float64) u) (tu (expr-Float64) u)] [_ (tu-error)]))]
    [(expr-f64-sqrt a)
     (let ([r (inferQ ctx a)]) (match r [(tu (expr-Float64) u) (tu (expr-Float64) u)] [_ (tu-error)]))]
    [(expr-f64-lt a b)
     (let ([r1 (checkQ ctx a (expr-Float64))] [r2 (checkQ ctx b (expr-Float64))])
       (match* (r1 r2) [((bu #t u1) (bu #t u2)) (tu (expr-Bool) (add-usage u1 u2))] [(_ _) (tu-error)]))]
    [(expr-f64-le a b)
     (let ([r1 (checkQ ctx a (expr-Float64))] [r2 (checkQ ctx b (expr-Float64))])
       (match* (r1 r2) [((bu #t u1) (bu #t u2)) (tu (expr-Bool) (add-usage u1 u2))] [(_ _) (tu-error)]))]
    [(expr-f64-eq a b)
     (let ([r1 (checkQ ctx a (expr-Float64))] [r2 (checkQ ctx b (expr-Float64))])
       (match* (r1 r2) [((bu #t u1) (bu #t u2)) (tu (expr-Bool) (add-usage u1 u2))] [(_ _) (tu-error)]))]

    ;; ---- Cross-width Float conversions (Numerics N3e-rest): arg Float32 OR Float64 ----
    [(expr-float-finite a)
     (let ([r (inferQ ctx a)])
       (match r [(tu ta u) #:when (let ([w (whnf ta)]) (or (expr-Float32? w) (expr-Float64? w))) (tu (expr-Bool) u)] [_ (tu-error)]))]
    [(expr-float-to-rat a)
     (let ([r (inferQ ctx a)])
       (match r [(tu ta u) #:when (let ([w (whnf ta)]) (or (expr-Float32? w) (expr-Float64? w))) (tu (expr-Rat) u)] [_ (tu-error)]))]
    [(expr-float-to-int a)
     (let ([r (inferQ ctx a)])
       (match r [(tu ta u) #:when (let ([w (whnf ta)]) (or (expr-Float32? w) (expr-Float64? w))) (tu (expr-Int) u)] [_ (tu-error)]))]
    [(expr-float-to-float32 a)
     (let ([r (inferQ ctx a)])
       (match r [(tu ta u) #:when (let ([w (whnf ta)]) (or (expr-Float32? w) (expr-Float64? w))) (tu (expr-Float32) u)] [_ (tu-error)]))]

    ;; ---- Posit32 binary operations ----
    ;; Binary ops: Posit32 -> Posit32 -> Posit32
    [(expr-p32-add a b)
     (let ([r1 (checkQ ctx a (expr-Posit32))]
           [r2 (checkQ ctx b (expr-Posit32))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Posit32) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-p32-sub a b)
     (let ([r1 (checkQ ctx a (expr-Posit32))]
           [r2 (checkQ ctx b (expr-Posit32))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Posit32) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-p32-mul a b)
     (let ([r1 (checkQ ctx a (expr-Posit32))]
           [r2 (checkQ ctx b (expr-Posit32))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Posit32) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-p32-div a b)
     (let ([r1 (checkQ ctx a (expr-Posit32))]
           [r2 (checkQ ctx b (expr-Posit32))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Posit32) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]

    ;; Unary Posit32 ops: Posit32 -> Posit32
    [(expr-p32-neg a)
     (let ([r (inferQ ctx a)])
       (match r [(tu (expr-Posit32) u) (tu (expr-Posit32) u)] [_ (tu-error)]))]
    [(expr-p32-abs a)
     (let ([r (inferQ ctx a)])
       (match r [(tu (expr-Posit32) u) (tu (expr-Posit32) u)] [_ (tu-error)]))]
    [(expr-p32-sqrt a)
     (let ([r (inferQ ctx a)])
       (match r [(tu (expr-Posit32) u) (tu (expr-Posit32) u)] [_ (tu-error)]))]

    ;; Posit32 comparisons: Posit32 -> Posit32 -> Bool
    [(expr-p32-lt a b)
     (let ([r1 (checkQ ctx a (expr-Posit32))]
           [r2 (checkQ ctx b (expr-Posit32))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Bool) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-p32-le a b)
     (let ([r1 (checkQ ctx a (expr-Posit32))]
           [r2 (checkQ ctx b (expr-Posit32))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Bool) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-p32-eq a b)
     (let ([r1 (checkQ ctx a (expr-Posit32))]
           [r2 (checkQ ctx b (expr-Posit32))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Bool) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]

    ;; Posit32 conversion: Nat -> Posit32
    [(expr-p32-from-nat e1)
     (let ([r (checkQ ctx e1 (expr-Nat))])
       (match r [(bu #t u) (tu (expr-Posit32) u)] [_ (tu-error)]))]

    ;; Phase 3f: Cross-family conversions for Posit32
    [(expr-p32-to-rat e1)
     (let ([r (checkQ ctx e1 (expr-Posit32))])
       (match r [(bu #t u) (tu (expr-Rat) u)] [_ (tu-error)]))]
    [(expr-p32-from-rat e1)
     (let ([r (checkQ ctx e1 (expr-Rat))])
       (match r [(bu #t u) (tu (expr-Posit32) u)] [_ (tu-error)]))]
    [(expr-p32-from-int e1)
     (let ([r (checkQ ctx e1 (expr-Int))])
       (match r [(bu #t u) (tu (expr-Posit32) u)] [_ (tu-error)]))]

    ;; Posit32 NaR eliminator: p32-if-nar(A, nar-case, normal-case, val)
    [(expr-p32-if-nar ty nar-case normal-case val)
     (let ([r4 (checkQ ctx val (expr-Posit32))])
       (match r4
         [(bu #t u4)
          (let ([r2 (checkQ ctx nar-case ty)])
            (match r2
              [(bu #t u2)
               (let ([r3 (checkQ ctx normal-case ty)])
                 (match r3
                   [(bu #t u3)
                    (let ([uj (join-branches ctx u2 u3)])
                      (if uj (tu ty (add-usage u4 uj)) (tu-error)))]
                   [_ (tu-error)]))]
              [_ (tu-error)]))]
         [_ (tu-error)]))]

    ;; ---- Posit64 binary operations ----
    ;; Binary ops: Posit64 -> Posit64 -> Posit64
    [(expr-p64-add a b)
     (let ([r1 (checkQ ctx a (expr-Posit64))]
           [r2 (checkQ ctx b (expr-Posit64))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Posit64) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-p64-sub a b)
     (let ([r1 (checkQ ctx a (expr-Posit64))]
           [r2 (checkQ ctx b (expr-Posit64))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Posit64) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-p64-mul a b)
     (let ([r1 (checkQ ctx a (expr-Posit64))]
           [r2 (checkQ ctx b (expr-Posit64))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Posit64) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-p64-div a b)
     (let ([r1 (checkQ ctx a (expr-Posit64))]
           [r2 (checkQ ctx b (expr-Posit64))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Posit64) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]

    ;; Unary Posit64 ops: Posit64 -> Posit64
    [(expr-p64-neg a)
     (let ([r (inferQ ctx a)])
       (match r [(tu (expr-Posit64) u) (tu (expr-Posit64) u)] [_ (tu-error)]))]
    [(expr-p64-abs a)
     (let ([r (inferQ ctx a)])
       (match r [(tu (expr-Posit64) u) (tu (expr-Posit64) u)] [_ (tu-error)]))]
    [(expr-p64-sqrt a)
     (let ([r (inferQ ctx a)])
       (match r [(tu (expr-Posit64) u) (tu (expr-Posit64) u)] [_ (tu-error)]))]

    ;; Posit64 comparisons: Posit64 -> Posit64 -> Bool
    [(expr-p64-lt a b)
     (let ([r1 (checkQ ctx a (expr-Posit64))]
           [r2 (checkQ ctx b (expr-Posit64))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Bool) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-p64-le a b)
     (let ([r1 (checkQ ctx a (expr-Posit64))]
           [r2 (checkQ ctx b (expr-Posit64))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Bool) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-p64-eq a b)
     (let ([r1 (checkQ ctx a (expr-Posit64))]
           [r2 (checkQ ctx b (expr-Posit64))])
       (match* (r1 r2)
         [((bu #t u1) (bu #t u2)) (tu (expr-Bool) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]

    ;; Posit64 conversion: Nat -> Posit64
    [(expr-p64-from-nat e1)
     (let ([r (checkQ ctx e1 (expr-Nat))])
       (match r [(bu #t u) (tu (expr-Posit64) u)] [_ (tu-error)]))]

    ;; Phase 3f: Cross-family conversions for Posit64
    [(expr-p64-to-rat e1)
     (let ([r (checkQ ctx e1 (expr-Posit64))])
       (match r [(bu #t u) (tu (expr-Rat) u)] [_ (tu-error)]))]
    [(expr-p64-from-rat e1)
     (let ([r (checkQ ctx e1 (expr-Rat))])
       (match r [(bu #t u) (tu (expr-Posit64) u)] [_ (tu-error)]))]
    [(expr-p64-from-int e1)
     (let ([r (checkQ ctx e1 (expr-Int))])
       (match r [(bu #t u) (tu (expr-Posit64) u)] [_ (tu-error)]))]

    ;; Posit64 NaR eliminator: p64-if-nar(A, nar-case, normal-case, val)
    [(expr-p64-if-nar ty nar-case normal-case val)
     (let ([r4 (checkQ ctx val (expr-Posit64))])
       (match r4
         [(bu #t u4)
          (let ([r2 (checkQ ctx nar-case ty)])
            (match r2
              [(bu #t u2)
               (let ([r3 (checkQ ctx normal-case ty)])
                 (match r3
                   [(bu #t u3)
                    (let ([uj (join-branches ctx u2 u3)])
                      (if uj (tu ty (add-usage u4 uj)) (tu-error)))]
                   [_ (tu-error)]))]
              [_ (tu-error)]))]
         [_ (tu-error)]))]

    ;; ---- Quire FMA operations ----
    ;; quireW-fma(q, a, b): usage = U_q + U_a + U_b
    [(expr-quire8-fma q a b)
     (let ([r1 (checkQ ctx q (expr-Quire8))]
           [r2 (checkQ ctx a (expr-Posit8))]
           [r3 (checkQ ctx b (expr-Posit8))])
       (match* (r1 r2 r3)
         [((bu #t u1) (bu #t u2) (bu #t u3))
          (tu (expr-Quire8) (add-usage u1 (add-usage u2 u3)))]
         [(_ _ _) (tu-error)]))]
    [(expr-quire16-fma q a b)
     (let ([r1 (checkQ ctx q (expr-Quire16))]
           [r2 (checkQ ctx a (expr-Posit16))]
           [r3 (checkQ ctx b (expr-Posit16))])
       (match* (r1 r2 r3)
         [((bu #t u1) (bu #t u2) (bu #t u3))
          (tu (expr-Quire16) (add-usage u1 (add-usage u2 u3)))]
         [(_ _ _) (tu-error)]))]
    [(expr-quire32-fma q a b)
     (let ([r1 (checkQ ctx q (expr-Quire32))]
           [r2 (checkQ ctx a (expr-Posit32))]
           [r3 (checkQ ctx b (expr-Posit32))])
       (match* (r1 r2 r3)
         [((bu #t u1) (bu #t u2) (bu #t u3))
          (tu (expr-Quire32) (add-usage u1 (add-usage u2 u3)))]
         [(_ _ _) (tu-error)]))]
    [(expr-quire64-fma q a b)
     (let ([r1 (checkQ ctx q (expr-Quire64))]
           [r2 (checkQ ctx a (expr-Posit64))]
           [r3 (checkQ ctx b (expr-Posit64))])
       (match* (r1 r2 r3)
         [((bu #t u1) (bu #t u2) (bu #t u3))
          (tu (expr-Quire64) (add-usage u1 (add-usage u2 u3)))]
         [(_ _ _) (tu-error)]))]

    ;; ---- Quire TO operations ----
    ;; quireW-to(q): usage = U_q
    [(expr-quire8-to q)
     (let ([r (checkQ ctx q (expr-Quire8))])
       (match r [(bu #t u) (tu (expr-Posit8) u)] [_ (tu-error)]))]
    [(expr-quire16-to q)
     (let ([r (checkQ ctx q (expr-Quire16))])
       (match r [(bu #t u) (tu (expr-Posit16) u)] [_ (tu-error)]))]
    [(expr-quire32-to q)
     (let ([r (checkQ ctx q (expr-Quire32))])
       (match r [(bu #t u) (tu (expr-Posit32) u)] [_ (tu-error)]))]
    [(expr-quire64-to q)
     (let ([r (checkQ ctx q (expr-Quire64))])
       (match r [(bu #t u) (tu (expr-Posit64) u)] [_ (tu-error)]))]

    ;; Symbol
    [(expr-Symbol) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-symbol _) (tu (expr-Symbol) (zero-usage n))]
    ;; Keyword
    [(expr-Keyword) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-keyword _) (tu (expr-Keyword) (zero-usage n))]
    ;; Path
    [(expr-Path) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-path _ _) (tu (expr-Path) (zero-usage n))]
    ;; Dynamic path operations
    [(expr-get-in target paths)
     (let ([r1 (inferQ ctx target)]
           [r2 (inferQ ctx paths)])
       (match* (r1 r2)
         [((tu _ u1) (tu _ u2))
          (tu (fresh-meta ctx-empty (expr-hole)
                (meta-source-info #f 'get-in-result "result type of dynamic get-in" #f '()))
              (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-update-in target paths fn)
     ;; CIU T6 F1b.3: DELEGATE the type to typing-core (the map-keys/vals
     ;; precedent) — this twin previously returned the TARGET's type unchanged,
     ;; a pre-existing divergence from the D20/D24 record degrades (the F1b.3
     ;; audit's C4 refutation); usage stays local.
     (let ([r1 (inferQ ctx target)]
           [r2 (inferQ ctx paths)]
           [r3 (inferQ ctx fn)])
       (match* (r1 r2 r3)
         [((tu _ u1) (tu _ u2) (tu _ u3))
          (tu (infer ctx e) (add-usage u1 (add-usage u2 u3)))]
         [(_ _ _) (tu-error)]))]
    ;; Char
    [(expr-Char) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-char _) (tu (expr-Char) (zero-usage n))]
    ;; String
    [(expr-String) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-string _) (tu (expr-String) (zero-usage n))]
    ;; Record/tuple type formation (CIU T6 F1): Type 0; usage = sum over field-type usages
    [(expr-Record _ fields _)
     (let loop ([fs fields] [acc (zero-usage n)])
       (if (null? fs)
           (tu (expr-Type (lzero)) acc)
           (match (inferQ ctx (record-field-type (cdr (car fs))))
             [(tu _ u) (loop (cdr fs) (add-usage acc u))]
             [_ (tu-error)])))]
    ;; Map
    [(expr-Map k v)
     (let ([r1 (inferQ ctx k)]
           [r2 (inferQ ctx v)])
       (match* (r1 r2)
         [((tu _ u1) (tu _ u2))
          (tu (expr-Type (lzero)) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-champ _) (tu (expr-Map (expr-hole) (expr-hole)) (zero-usage n))]

    ;; ---- Standalone lambda in INFER position ----
    ;; Rel T1 X.close Batch C. `inferQ` previously had a lam arm ONLY inside the
    ;; beta-redex case (`(expr-app (expr-lam …) _)`, :301), so a lambda reached
    ;; in infer position — e.g. as a map VALUE, `def m := {:f [fn [y : Nat] …]}`
    ;; — fell to the catch-all, returned `tu-error`, and `checkQ-top` reported
    ;; the generic **"Multiplicity violation"**: a message with no relation to
    ;; the actual problem. That is the 3rd instance of the un-arm'd-node class
    ;; (after `def m0 := {}` / CIU T6 F1a.2 and `def x := solve (…)` / POL.5).
    ;; A BARE `def f := [fn …]` never showed it because the def seam is CHECK
    ;; mode, where lambdas are canonical (checkQ's arm at :2257).
    ;;
    ;; typing-core's `infer` HAS the mirror arm (typing-core.rkt:1021) — the
    ;; asymmetry between the twins was the defect. Here:
    ;;   TYPE  — delegated to `infer` (qtt's documented "no drift twin" pattern,
    ;;           as `expr-map-assoc`/`expr-validate` already do); an
    ;;           un-inferable domain surfaces as typing-core's own `expr-error`.
    ;;   USAGE — mirrors checkQ's lam arm: check the body in the extended ctx,
    ;;           read the bound variable's usage off the head, solve a
    ;;           multiplicity meta to what was observed, verify the declared
    ;;           multiplicity permits it, and return the tail.
    ;; A genuine multiplicity failure here is still reported as one — the fix
    ;; removes the FALSE positive, not the real check.
    [(expr-lam lm dom body)
     (cond
       ;; No domain to extend the context with — genuinely un-inferable
       ;; (mirrors typing-core's `[(expr-hole? dom) (expr-error)]`). Check
       ;; position still handles these via checkQ's arm.
       [(or (expr-hole? dom) (expr-typed-hole? dom)) (tu-error)]
       [else
        (let ([ty (infer ctx e)])
          (if (expr-error? ty)
              (tu-error)
              (match (inferQ (ctx-extend ctx dom lm) body)
                [(tu _ u)
                 (let ([actual (uhead u)])
                   (when (and (mult-meta? lm)
                              (not (mult-meta-solved? (mult-meta-id lm))))
                     (solve-mult-meta! (mult-meta-id lm) actual))
                   (if (or (mult-meta? lm) (compatible lm actual))
                       (tu ty (utail u))
                       (tu-error)))]
                [_ (tu-error)])))])]
    [(expr-map-empty k v)
     (let ([r1 (inferQ ctx k)]
           [r2 (inferQ ctx v)])
       (match* (r1 r2)
         [((tu _ u1) (tu _ u2))
          ;; CIU T6 F1a.2 p1b: a Record v-slot (the record/dyn-row literal seed)
          ;; delegates the TYPE to infer (the S4 pattern) — the seed's type IS
          ;; the row, and checkQ-top's fallback must see it (not (Map ?km row),
          ;; whose meta K the pure α key-gate rightly refuses).
          (tu (if (expr-Record? v) (infer ctx e) (expr-Map k v))
              (scale-usage 'm0 (add-usage u1 u2)))]  ;; type args are erased
         [(_ _) (tu-error)]))]
    [(expr-map-assoc m k v)
     (let ([r1 (inferQ ctx m)]
           [r2 (inferQ ctx k)]
           [r3 (inferQ ctx v)])
       (match* (r1 r2 r3)
         [((tu _ u1) (tu _ u2) (tu _ u3))
          ;; CIU T6 F1 (S4): delegate the TYPE to typing-core unconditionally (records GROW —
          ;; the old (tu-type r1) returned the un-extended type = the §6 divergence bug class);
          ;; usage stays local.
          (tu (infer ctx e) (add-usage u1 (add-usage u2 u3)))]
         [(_ _ _) (tu-error)]))]
    [(expr-map-get m k _a)
     (let ([r1 (inferQ ctx m)]
           [r2 (inferQ ctx k)])
       (match* (r1 r2)
         [((tu t1 u1) (tu _ u2))
          ;; map-get returns the value type V from Map K V
          (match t1
            ;; P2.b slice 4 (audit R8/C20): the Map leg now DELEGATES the type
            ;; to typing-core like its siblings — the local `vt` return was the
            ;; one site where a fork in infer's result silently failed to reach
            ;; the QTT pass (the infer/inferQ-twins class the F1 comment below
            ;; records as already bitten). Usage stays local.
            [(expr-Map _ _) (tu (infer ctx e) (add-usage u1 u2))]
            ;; CIU T6 F1 (s2): record/schema/selection — delegate result type to typing-core
            [(? expr-Record?) (tu (infer ctx e) (add-usage u1 u2))]
            [(expr-fvar name)
             #:when (or (lookup-schema-by-name name) (lookup-selection-by-name name))
             (let ([result-type (infer ctx e)])
               (tu result-type (add-usage u1 u2)))]
            [_ (tu-error)])]
         [(_ _) (tu-error)]))]
    [(expr-get c k _a)
     (let ([r1 (inferQ ctx c)]
           [r2 (inferQ ctx k)])
       (match* (r1 r2)
         [((tu t1 u1) (tu _ u2))
          ;; get: infer result type from typing-core, track usage from both args
          (let ([result-type (infer ctx e)])
            (tu result-type (add-usage u1 u2)))]
         [(_ _) (tu-error)]))]

    ;; CIU T6 F1b.5-s2: validate — the expr-get delegate pattern: subject
    ;; usage at natural multiplicity; type from typing-core's infer arm.
    ;; Plan exprs are BAKED CLOSED (elaborated in empty env — no free vars
    ;; into user context), so they contribute no usage. No checkQ arm needed
    ;; (checkQ's conversion fallback covers check position).
    [(expr-validate _ _ _ subject _)
     (match (inferQ ctx subject)
       [(tu _ u) (tu (infer ctx e) u)]
       [_ (tu-error)])]
    ;; CIU T6 D4.P3a: select — the same expr-get delegate pattern (the
    ;; cdb535ac "no drift twin" model): subject usage at natural multiplicity;
    ;; TYPE delegated to typing-core's infer arm. Branches are static data —
    ;; no exprs, no usage. No checkQ arm needed (the conversion fallback
    ;; covers check position). A missing arm here is the LYING "Multiplicity
    ;; violation" (pipeline.md § infer/inferQ are twins).
    [(expr-select subject _ _)
     (match (inferQ ctx subject)
       [(tu _ u) (tu (infer ctx e) u)]
       [_ (tu-error)])]
    [(expr-nil-safe-get m k)
     (let ([r1 (inferQ ctx m)]
           [r2 (inferQ ctx k)])
       (match* (r1 r2)
         [((tu t1 u1) (tu _ u2))
          ;; nil-safe-get: infer type from typing-core, track usage from both args
          (let ([result-type (infer ctx e)])
            (tu result-type (add-usage u1 u2)))]
         [(_ _) (tu-error)]))]
    [(expr-nil-check arg)
     (let ([r (inferQ ctx arg)])
       (match r
         [(tu _ u) (tu (expr-Bool) u)]
         [_ (tu-error)]))]
    [(expr-map-dissoc m k)
     ;; CIU T6 F1b.3: DELEGATE the type (was: the SUBJECT's type unchanged — a
     ;; pre-existing divergence that made def-bound dissoc results fail QTT
     ;; with a miscategorized Multiplicity violation; audit C4 refutation).
     (let ([r1 (inferQ ctx m)]
           [r2 (inferQ ctx k)])
       (match* (r1 r2)
         [((tu _ u1) (tu _ u2))
          (tu (infer ctx e) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-map-size m)
     (let ([r (inferQ ctx m)])
       (match r
         [(tu _ u) (tu (expr-Nat) u)]
         [_ (tu-error)]))]
    [(expr-map-has-key m k)
     (let ([r1 (inferQ ctx m)]
           [r2 (inferQ ctx k)])
       (match* (r1 r2)
         [((tu _ u1) (tu _ u2))
          (tu (expr-Bool) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-map-keys m)
     (let ([r (inferQ ctx m)])
       (match r
         [(tu _ u) (tu (infer ctx (expr-map-keys m)) u)]
         [_ (tu-error)]))]
    [(expr-map-vals m)
     (let ([r (inferQ ctx m)])
       (match r
         [(tu _ u) (tu (infer ctx (expr-map-vals m)) u)]
         [_ (tu-error)]))]

    ;; ---- Set type and operations ----
    [(expr-Set a)
     (let ([r (inferQ ctx a)])
       (match r
         [(tu _ u) (tu (expr-Type (lzero)) u)]
         [_ (tu-error)]))]
    [(expr-hset _) (tu (expr-Set (expr-hole)) (zero-usage n))]
    [(expr-set-empty a)
     (let ([r (inferQ ctx a)])
       (match r
         [(tu _ u) (tu (expr-Set a) (scale-usage 'm0 u))]  ;; type arg is erased
         [_ (tu-error)]))]
    [(expr-set-insert s a)
     (let ([r1 (inferQ ctx s)]
           [r2 (inferQ ctx a)])
       (match* (r1 r2)
         [((tu t1 u1) (tu _ u2))
          (match (whnf t1)
            [(expr-Set a-ty)
             (if (check ctx a a-ty)
                 (tu (expr-Set a-ty) (add-usage u1 u2))
                 (tu-error))]
            [_ (tu-error)])]
         [(_ _) (tu-error)]))]
    [(expr-set-member s a)
     (let ([r1 (inferQ ctx s)]
           [r2 (inferQ ctx a)])
       (match* (r1 r2)
         [((tu t1 u1) (tu _ u2))
          (match (whnf t1)
            [(expr-Set a-ty)
             (if (check ctx a a-ty)
                 (tu (expr-Bool) (add-usage u1 u2))
                 (tu-error))]
            [_ (tu-error)])]
         [(_ _) (tu-error)]))]
    [(expr-set-delete s a)
     (let ([r1 (inferQ ctx s)]
           [r2 (inferQ ctx a)])
       (match* (r1 r2)
         [((tu t1 u1) (tu _ u2))
          (match (whnf t1)
            [(expr-Set a-ty)
             (if (check ctx a a-ty)
                 (tu (expr-Set a-ty) (add-usage u1 u2))
                 (tu-error))]
            [_ (tu-error)])]
         [(_ _) (tu-error)]))]
    [(expr-set-size s)
     (let ([r (inferQ ctx s)])
       (match r
         [(tu _ u) (tu (expr-Nat) u)]
         [_ (tu-error)]))]
    [(expr-set-union s1 s2)
     (let ([r1 (inferQ ctx s1)]
           [r2 (inferQ ctx s2)])
       (match* (r1 r2)
         [((tu t1 u1) (tu _ u2))
          (match (whnf t1)
            [(expr-Set a-ty)
             (if (check ctx s2 (expr-Set a-ty))
                 (tu (expr-Set a-ty) (add-usage u1 u2))
                 (tu-error))]
            [_ (tu-error)])]
         [(_ _) (tu-error)]))]
    [(expr-set-intersect s1 s2)
     (let ([r1 (inferQ ctx s1)]
           [r2 (inferQ ctx s2)])
       (match* (r1 r2)
         [((tu t1 u1) (tu _ u2))
          (match (whnf t1)
            [(expr-Set a-ty)
             (if (check ctx s2 (expr-Set a-ty))
                 (tu (expr-Set a-ty) (add-usage u1 u2))
                 (tu-error))]
            [_ (tu-error)])]
         [(_ _) (tu-error)]))]
    [(expr-set-diff s1 s2)
     (let ([r1 (inferQ ctx s1)]
           [r2 (inferQ ctx s2)])
       (match* (r1 r2)
         [((tu t1 u1) (tu _ u2))
          (match (whnf t1)
            [(expr-Set a-ty)
             (if (check ctx s2 (expr-Set a-ty))
                 (tu (expr-Set a-ty) (add-usage u1 u2))
                 (tu-error))]
            [_ (tu-error)])]
         [(_ _) (tu-error)]))]
    ;; set-to-list: Set A → List A
    [(expr-set-to-list s)
     (let ([r (inferQ ctx s)])
       (match r
         [(tu _ u) (tu (infer ctx (expr-set-to-list s)) u)]
         [_ (tu-error)]))]

    ;; ---- PVec type and operations ----
    [(expr-PVec a)
     (let ([r (inferQ ctx a)])
       (match r
         [(tu _ u) (tu (expr-Type (lzero)) u)]
         [_ (tu-error)]))]
    [(expr-rrb _) (tu (expr-PVec (expr-hole)) (zero-usage n))]
    [(expr-pvec-empty a)
     (let ([r (inferQ ctx a)])
       (match r
         [(tu _ u) (tu (expr-PVec a) (scale-usage 'm0 u))]  ;; type arg is erased
         [_ (tu-error)]))]
    [(expr-pvec-push v x)
     (let ([r1 (inferQ ctx v)]
           [r2 (inferQ ctx x)])
       (match* (r1 r2)
         [((tu t1 u1) (tu _ u2))
          ;; CIU T6 F1a-col-3: a tuple subject makes push type-CHANGING (the row grows) —
          ;; delegate the type to infer (the §6 divergence class / S4 pattern), usage local.
          ;; PVec subjects keep the exact echo (result type = subject type).
          (if (expr-Record? (whnf t1))
              (tu (infer ctx e) (add-usage u1 u2))
              (tu t1 (add-usage u1 u2)))]
         [(_ _) (tu-error)]))]
    ;; CIU T6 F1a-col-2: list-literal twin — same delegation; usage from elems
    ;; (the chain re-elaborates the same source elements; counting BOTH would
    ;; double-count usage, so the chain contributes none).
    [(expr-list-literal elems chain)
     (let ([result-type (infer ctx e)])
       (if (expr-error? result-type)
           (tu-error)
           (let loop ([es elems] [u (zero-usage n)])
             (if (null? es)
                 (tu result-type u)
                 (match (inferQ ctx (car es))
                   [(tu _ ue) (loop (cdr es) (add-usage u ue))]
                   [_ (tu-error)])))))]
    ;; CIU T6 F1a.2 p1b (D18): map-literal twin — type delegates to infer
    ;; (keys-unify + ⋃vals lives there once); usage sums keys + vals; the chain
    ;; re-elaborates the same source entries, so it contributes NO usage
    ;; (the col-2 double-count lesson).
    [(expr-map-literal keys vals chain)
     (let ([result-type (infer ctx e)])
       (if (expr-error? result-type)
           (tu-error)
           (let loop ([es (append keys vals)] [u (zero-usage n)])
             (if (null? es)
                 (tu result-type u)
                 (match (inferQ ctx (car es))
                   [(tu _ ue) (loop (cdr es) (add-usage u ue))]
                   [_ (tu-error)])))))]
    ;; CIU T6 F1a-col: literal-extent node — type delegates to infer (the
    ;; homogeneity/tuple decision lives there once); usage sums the elements.
    [(expr-pvec-literal elems)
     (let ([result-type (infer ctx e)])
       (if (expr-error? result-type)
           (tu-error)
           (let loop ([es elems] [u (zero-usage n)])
             (if (null? es)
                 (tu result-type u)
                 (match (inferQ ctx (car es))
                   [(tu _ ue) (loop (cdr es) (add-usage u ue))]
                   [_ (tu-error)])))))]
    [(expr-pvec-nth v i)
     (let ([r1 (inferQ ctx v)]
           [r2 (inferQ ctx i)])
       (match* (r1 r2)
         [((tu t1 u1) (tu _ u2))
          ;; pvec-nth returns the ELEMENT TYPE, not PVec
          (match (whnf t1)
            [(expr-PVec a) (tu a (add-usage u1 u2))]
            ;; CIU T6 F1a-col-3: tuple — delegate the positional projection to infer
            ;; (record-project lives there once); usage local.
            [(? expr-Record?) (tu (infer ctx e) (add-usage u1 u2))]
            [_ (tu-error)])]
         [(_ _) (tu-error)]))]
    [(expr-pvec-update v i x)
     (let ([r1 (inferQ ctx v)]
           [r2 (inferQ ctx i)]
           [r3 (inferQ ctx x)])
       (match* (r1 r2 r3)
         [((tu t1 u1) (tu _ u2) (tu _ u3))
          ;; CIU T6 F1a-col-3: tuple → type-changing (per-position replace / degrade) —
          ;; delegate to infer (§6 divergence class); PVec keeps the echo.
          (if (expr-Record? (whnf t1))
              (tu (infer ctx e) (add-usage u1 (add-usage u2 u3)))
              (tu t1 (add-usage u1 (add-usage u2 u3))))]
         [(_ _ _) (tu-error)]))]
    [(expr-pvec-length v)
     (let ([r (inferQ ctx v)])
       (match r
         [(tu _ u) (tu (expr-Nat) u)]
         [_ (tu-error)]))]
    [(expr-pvec-pop v)
     (let ([r (inferQ ctx v)])
       (match r
         ;; CIU T6 F1a-col-3: tuple → the row SHRINKS — delegate (§6 class); PVec echoes.
         [(tu t1 u)
          (if (expr-Record? (whnf t1))
              (tu (infer ctx e) u)
              (tu t1 u))]
         [_ (tu-error)]))]
    [(expr-pvec-concat v1 v2)
     (let ([r1 (inferQ ctx v1)]
           [r2 (inferQ ctx v2)])
       (match* (r1 r2)
         [((tu t1 u1) (tu _ u2))
          ;; CIU T6 F1a-col-3: tuple → row append / degrade — delegate (§6 class).
          (if (expr-Record? (whnf t1))
              (tu (infer ctx e) (add-usage u1 u2))
              (tu t1 (add-usage u1 u2)))]
         [(_ _) (tu-error)]))]
    [(expr-pvec-slice v lo hi)
     (let ([r1 (inferQ ctx v)]
           [r2 (inferQ ctx lo)]
           [r3 (inferQ ctx hi)])
       (match* (r1 r2 r3)
         [((tu t1 u1) (tu _ u2) (tu _ u3))
          ;; CIU T6 F1a-col-3: tuple → sub-row / degrade — delegate (§6 class).
          (if (expr-Record? (whnf t1))
              (tu (infer ctx e) (add-usage u1 (add-usage u2 u3)))
              (tu t1 (add-usage u1 (add-usage u2 u3))))]
         [(_ _ _) (tu-error)]))]
    ;; pvec-to-list : PVec A → List A
    [(expr-pvec-to-list v)
     (let ([r (inferQ ctx v)])
       (match r
         [(tu (expr-PVec a) u) (tu (expr-app (list-type-fvar) a) u)]
         ;; CIU T6 F1a-col-3: tuple → delegate to infer ((List ⋃positions)). MUST come
         ;; before the resolution fallback below, which would silently ECHO the row
         ;; itself as the "List" result type (wrong type, no error).
         [(tu t1 u) #:when (expr-Record? (whnf t1))
          (tu (infer ctx e) u)]
         [(tu _ u) (tu (tu-type r) u)]  ;; fallback if type not fully resolved
         [_ (tu-error)]))]
    ;; pvec-from-list : List A → PVec A
    ;; Infer the argument, match List A (qualified or unqualified), produce PVec A
    [(expr-pvec-from-list v)
     (let ([r (inferQ ctx v)])
       (match r
         [(tu _ u) (tu (infer ctx (expr-pvec-from-list v)) u)]
         [_ (tu-error)]))]

    ;; pvec-fold : (B → A → B) → B → PVec A → B
    ;; Uses checkQ for f when inferQ fails (e.g., f is a lambda).
    [(expr-pvec-fold f init vec)
     (let ([rv (inferQ ctx vec)]
           [ri (inferQ ctx init)])
       (match* (rv ri)
         [((tu tv uv) (tu tb ui))
          (match (whnf tv)
            [(expr-PVec a)
             (let* ([ef (expr-Pi 'mw tb (expr-Pi 'mw (shift 1 0 a) (shift 2 0 tb)))]
                    [rf (inferQ-or-checkQ ctx f ef)])
               (match rf
                 [(tu _ uf) (tu tb (add-usage (add-usage (scale-usage 'mw uf) ui) uv))]
                 [_ (tu-error)]))]
            ;; CIU T6 F1a-col-3: fold over a tuple — uniform view (typing-core mirror)
            [(? closed-nat-row? rec)
             (let* ([v (record-value-bound ctx rec "tuple-fold")]
                    [ef (expr-Pi 'mw tb (expr-Pi 'mw (shift 1 0 v) (shift 2 0 tb)))]
                    [rf (inferQ-or-checkQ ctx f ef)])
               (match rf
                 [(tu _ uf) (tu tb (add-usage (add-usage (scale-usage 'mw uf) ui) uv))]
                 [_ (tu-error)]))]
            [_ (tu-error)])]
         [(_ _) (tu-error)]))]

    ;; pvec-map : (A → B) → PVec A → PVec B
    [(expr-pvec-map f vec)
     (let ([result-type (infer ctx (expr-pvec-map f vec))]
           [rv (inferQ ctx vec)])
       (match rv
         [(tu tv uv)
          (match (whnf tv)
            [(expr-PVec a)
             (let* ([rf (inferQ-or-checkQ ctx f (expr-Pi 'mw a (shift 1 0 result-type)))])
               (match rf
                 [(tu _ uf) (tu result-type (add-usage (scale-usage 'mw uf) uv))]
                 [_ (tu-error)]))]
            ;; CIU T6 F1a-col-3: map over a tuple — f consumes ⋃positions; the
            ;; position-preserving result type comes from infer (the map-map-vals
            ;; qtt-mirror pattern).
            [(? closed-nat-row? rec)
             (let ([rf (inferQ-or-checkQ ctx f
                         (expr-Pi 'mw (record-value-bound ctx rec "tuple-map") (shift 1 0 result-type)))])
               (match rf
                 [(tu _ uf) (tu result-type (add-usage (scale-usage 'mw uf) uv))]
                 [_ (tu-error)]))]
            [_ (tu-error)])]
         [_ (tu-error)]))]
    ;; pvec-filter : (A → Bool) → PVec A → PVec A
    [(expr-pvec-filter pred vec)
     (let ([rv (inferQ ctx vec)])
       (match rv
         [(tu tv uv)
          (match (whnf tv)
            [(expr-PVec a)
             (let ([rp (inferQ-or-checkQ ctx pred (expr-Pi 'mw a (expr-Bool)))])
               (match rp
                 [(tu _ up) (tu (expr-PVec a) (add-usage (scale-usage 'mw up) uv))]
                 [_ (tu-error)]))]
            ;; CIU T6 F1a-col-3: filter on a tuple → (PVec ⋃positions) degrade
            ;; (typing-core mirror)
            [(? closed-nat-row? rec)
             (let* ([v (record-value-bound ctx rec "tuple-filter")]
                    [rp (inferQ-or-checkQ ctx pred (expr-Pi 'mw v (expr-Bool)))])
               (match rp
                 [(tu _ up) (tu (expr-PVec v) (add-usage (scale-usage 'mw up) uv))]
                 [_ (tu-error)]))]
            [_ (tu-error)])]
         [_ (tu-error)]))]
    ;; set-fold : (B → A → B) → B → Set A → B
    [(expr-set-fold f init set)
     (let ([rs (inferQ ctx set)]
           [ri (inferQ ctx init)])
       (match* (rs ri)
         [((tu ts us) (tu tb ui))
          (match ts
            [(expr-Set a)
             (let* ([ef (expr-Pi 'mw tb (expr-Pi 'mw (shift 1 0 a) (shift 2 0 tb)))]
                    [rf (inferQ-or-checkQ ctx f ef)])
               (match rf
                 [(tu _ uf) (tu tb (add-usage (add-usage (scale-usage 'mw uf) ui) us))]
                 [_ (tu-error)]))]
            [_ (tu-error)])]
         [(_ _) (tu-error)]))]
    ;; set-filter : (A → Bool) → Set A → Set A
    [(expr-set-filter pred set)
     (let ([rs (inferQ ctx set)])
       (match rs
         [(tu ts us)
          (match ts
            [(expr-Set a)
             (let ([rp (inferQ-or-checkQ ctx pred (expr-Pi 'mw a (expr-Bool)))])
               (match rp
                 [(tu _ up) (tu (expr-Set a) (add-usage (scale-usage 'mw up) us))]
                 [_ (tu-error)]))]
            [_ (tu-error)])]
         [_ (tu-error)]))]
    ;; map-fold-entries : (B → K → V → B) → B → Map K V → B
    [(expr-map-fold-entries f init map)
     (let ([rm (inferQ ctx map)]
           [ri (inferQ ctx init)])
       (match* (rm ri)
         [((tu tm um) (tu tb ui))
          (match tm
            [(expr-Map k v)
             (let* ([ef (expr-Pi 'mw tb
                          (expr-Pi 'mw (shift 1 0 k)
                            (expr-Pi 'mw (shift 2 0 v) (shift 3 0 tb))))]
                    [rf (inferQ-or-checkQ ctx f ef)])
               (match rf
                 [(tu _ uf) (tu tb (add-usage (add-usage (scale-usage 'mw uf) ui) um))]
                 [_ (tu-error)]))]
            ;; CIU T6 F1 (s3): fold over a record — uniform view (K=Keyword, V=⋃fields)
            [(? expr-Record? rec)
             (let* ([v (record-value-bound ctx rec "dyn-row-fold")]
                    [ef (expr-Pi 'mw tb
                          (expr-Pi 'mw (shift 1 0 (expr-Keyword))
                            (expr-Pi 'mw (shift 2 0 v) (shift 3 0 tb))))]
                    [rf (inferQ-or-checkQ ctx f ef)])
               (match rf
                 [(tu _ uf) (tu tb (add-usage (add-usage (scale-usage 'mw uf) ui) um))]
                 [_ (tu-error)]))]
            [_ (tu-error)])]
         [(_ _) (tu-error)]))]
    ;; map-filter-entries : (K → V → Bool) → Map K V → Map K V
    [(expr-map-filter-entries pred map)
     (let ([rm (inferQ ctx map)])
       (match rm
         [(tu tm um)
          (match tm
            [(expr-Map k v)
             (let ([rp (inferQ-or-checkQ ctx pred
                         (expr-Pi 'mw k (expr-Pi 'mw (shift 1 0 v) (expr-Bool))))])
               (match rp
                 [(tu _ up) (tu (expr-Map k v) (add-usage (scale-usage 'mw up) um))]
                 [_ (tu-error)]))]
            ;; CIU T6 F1 (s3): filter on a record → dictionary view (mirrors typing-core)
            [(? expr-Record? rec)
             (let* ([v (record-value-bound ctx rec "dyn-row-filter")]
                    [rp (inferQ-or-checkQ ctx pred
                          (expr-Pi 'mw (expr-Keyword) (expr-Pi 'mw (shift 1 0 v) (expr-Bool))))])
               (match rp
                 [(tu _ up) (tu (expr-Map (expr-Keyword) v) (add-usage (scale-usage 'mw up) um))]
                 [_ (tu-error)]))]
            [_ (tu-error)])]
         [_ (tu-error)]))]
    ;; map-map-vals : (V → W) → Map K V → Map K W
    [(expr-map-map-vals f map)
     (let ([result-type (infer ctx (expr-map-map-vals f map))]
           [rm (inferQ ctx map)])
       (match rm
         [(tu tm um)
          (match tm
            [(expr-Map k v)
             (let ([rf (inferQ-or-checkQ ctx f (expr-Pi 'mw v (shift 1 0 result-type)))])
               (match rf
                 [(tu _ uf) (tu result-type (add-usage (scale-usage 'mw uf) um))]
                 [_ (tu-error)]))]
            ;; CIU T6 F1 (s3): map-vals over a record — f consumes ⋃fields; type from infer
            [(? expr-Record? rec)
             (let ([rf (inferQ-or-checkQ ctx f
                         (expr-Pi 'mw (record-value-bound ctx rec "dyn-row-map-vals") (shift 1 0 result-type)))])
               (match rf
                 [(tu _ uf) (tu result-type (add-usage (scale-usage 'mw uf) um))]
                 [_ (tu-error)]))]
            [_ (tu-error)])]
         [_ (tu-error)]))]

    ;; ---- Transient Builders ----
    ;; Generic transient/persist: dispatch on inferred type, combine usage
    [(expr-transient coll)
     (let ([r (inferQ ctx coll)])
       (match r
         [(tu tc u) (match (whnf tc)
                      [(expr-PVec a) (tu (expr-TVec a) u)]
                      [(expr-Map k v) (tu (expr-TMap k v) u)]
                      [(expr-Set a) (tu (expr-TSet a) u)]
                      ;; CIU T6 F1a-col-3: tuple → uniform transient view (typing-core mirror)
                      [(? closed-nat-row? rec) (tu (expr-TVec (record-value-bound ctx rec "tuple-transient")) u)]
                      [_ (tu-error)])]
         [_ (tu-error)]))]
    [(expr-persist coll)
     (let ([r (inferQ ctx coll)])
       (match r
         [(tu tc u) (match tc
                      [(expr-TVec a) (tu (expr-PVec a) u)]
                      [(expr-TMap k v) (tu (expr-Map k v) u)]
                      [(expr-TSet a) (tu (expr-Set a) u)]
                      [_ (tu-error)])]
         [_ (tu-error)]))]
    ;; Panic: msg is runtime-relevant (mw), type is error (needs checking context)
    [(expr-panic msg)
     (let ([r (inferQ ctx msg)])
       (match r
         [(tu _ u) (tu (expr-error) u)]
         [_ (tu-error)]))]
    [(expr-TVec a)
     (let ([r (inferQ ctx a)])
       (match r
         [(tu _ u) (tu (expr-Type (lzero)) u)]
         [_ (tu-error)]))]
    [(expr-TMap k v)
     (let ([r1 (inferQ ctx k)]
           [r2 (inferQ ctx v)])
       (match* (r1 r2)
         [((tu _ u1) (tu _ u2))
          (tu (expr-Type (lzero)) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-TSet a)
     (let ([r (inferQ ctx a)])
       (match r
         [(tu _ u) (tu (expr-Type (lzero)) u)]
         [_ (tu-error)]))]
    [(expr-trrb _) (tu (expr-TVec (expr-hole)) (zero-usage n))]
    [(expr-tchamp _) (tu (expr-TMap (expr-hole) (expr-hole)) (zero-usage n))]
    [(expr-thset _) (tu (expr-TSet (expr-hole)) (zero-usage n))]
    [(expr-transient-vec v)
     (let ([r (inferQ ctx v)])
       (match r
         [(tu tv u) (match tv
                      [(expr-PVec a) (tu (expr-TVec a) u)]
                      [_ (tu-error)])]
         [_ (tu-error)]))]
    [(expr-persist-vec t)
     (let ([r (inferQ ctx t)])
       (match r
         [(tu tt u) (match tt
                      [(expr-TVec a) (tu (expr-PVec a) u)]
                      [_ (tu-error)])]
         [_ (tu-error)]))]
    [(expr-transient-map m)
     (let ([r (inferQ ctx m)])
       (match r
         [(tu tm u) (match tm
                      [(expr-Map k v) (tu (expr-TMap k v) u)]
                      [_ (tu-error)])]
         [_ (tu-error)]))]
    [(expr-persist-map t)
     (let ([r (inferQ ctx t)])
       (match r
         [(tu tt u) (match tt
                      [(expr-TMap k v) (tu (expr-Map k v) u)]
                      [_ (tu-error)])]
         [_ (tu-error)]))]
    [(expr-transient-set s)
     (let ([r (inferQ ctx s)])
       (match r
         [(tu ts u) (match ts
                      [(expr-Set a) (tu (expr-TSet a) u)]
                      [_ (tu-error)])]
         [_ (tu-error)]))]
    [(expr-persist-set t)
     (let ([r (inferQ ctx t)])
       (match r
         [(tu tt u) (match tt
                      [(expr-TSet a) (tu (expr-Set a) u)]
                      [_ (tu-error)])]
         [_ (tu-error)]))]
    [(expr-tvec-push! t x)
     (let ([r1 (inferQ ctx t)]
           [r2 (inferQ ctx x)])
       (match* (r1 r2)
         [((tu _ u1) (tu _ u2))
          (tu (tu-type r1) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-tvec-update! t i x)
     (let ([r1 (inferQ ctx t)]
           [r2 (inferQ ctx i)]
           [r3 (inferQ ctx x)])
       (match* (r1 r2 r3)
         [((tu _ u1) (tu _ u2) (tu _ u3))
          (tu (tu-type r1) (add-usage u1 (add-usage u2 u3)))]
         [(_ _ _) (tu-error)]))]
    [(expr-tmap-assoc! t k v)
     (let ([r1 (inferQ ctx t)]
           [r2 (inferQ ctx k)]
           [r3 (inferQ ctx v)])
       (match* (r1 r2 r3)
         [((tu _ u1) (tu _ u2) (tu _ u3))
          (tu (tu-type r1) (add-usage u1 (add-usage u2 u3)))]
         [(_ _ _) (tu-error)]))]
    [(expr-tmap-dissoc! t k)
     (let ([r1 (inferQ ctx t)]
           [r2 (inferQ ctx k)])
       (match* (r1 r2)
         [((tu _ u1) (tu _ u2))
          (tu (tu-type r1) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-tset-insert! t a)
     (let ([r1 (inferQ ctx t)]
           [r2 (inferQ ctx a)])
       (match* (r1 r2)
         [((tu _ u1) (tu _ u2))
          (tu (tu-type r1) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-tset-delete! t a)
     (let ([r1 (inferQ ctx t)]
           [r2 (inferQ ctx a)])
       (match* (r1 r2)
         [((tu _ u1) (tu _ u2))
          (tu (tu-type r1) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]

    ;; ---- PropNetwork type constructors ----
    [(expr-net-type) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-cell-id-type) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-prop-id-type) (tu (expr-Type (lzero)) (zero-usage n))]
    ;; Runtime wrappers — zero usage (opaque Racket values)
    [(expr-prop-network _) (tu (expr-net-type) (zero-usage n))]
    [(expr-cell-id _) (tu (expr-cell-id-type) (zero-usage n))]
    [(expr-prop-id _) (tu (expr-prop-id-type) (zero-usage n))]

    ;; ---- PropNetwork operations ----
    ;; net-new : Int -> PropNetwork
    [(expr-net-new fuel)
     (let ([r1 (checkQ ctx fuel (expr-Int))])
       (match r1
         [(bu #t u) (tu (expr-net-type) u)]
         [_ (tu-error)]))]

    ;; net-new-cell : PropNetwork -> A -> (A -> A -> A) -> [PropNetwork * CellId]
    ;; Use checkQ for merge (not inferQ) because inferQ can't handle standalone lambdas.
    ;; The merge type A -> A -> A is computed from init's inferred type, with proper
    ;; de Bruijn shifts under Pi binders (init-ty may contain bvars in polymorphic contexts).
    [(expr-net-new-cell net init merge)
     (let ([r1 (inferQ ctx net)]
           [r2 (inferQ ctx init)])
       (match* (r1 r2)
         [((tu _ u1) (tu init-ty u2))
          ;; Build merge type: A -> A -> A with proper shifts under Pi binders
          (define merge-ty (expr-Pi mw init-ty
                             (expr-Pi mw (shift 1 0 init-ty)
                               (shift 2 0 init-ty))))
          (let ([r3 (checkQ ctx merge merge-ty)])
            (match r3
              [(bu #t u3)
               (tu (expr-Sigma (expr-net-type) (expr-cell-id-type))
                   (add-usage u1 (add-usage u2 u3)))]
              [_ (tu-error)]))]
         [(_ _) (tu-error)]))]

    ;; net-new-cell-widen : PropNetwork -> A -> (A A -> A) -> (A A -> A) -> (A A -> A) -> [PropNetwork * CellId]
    ;; Use checkQ for all function args (merge, widen, narrow) since inferQ can't handle standalone lambdas.
    [(expr-net-new-cell-widen net init merge widen-fn narrow-fn)
     (let ([r1 (inferQ ctx net)]
           [r2 (inferQ ctx init)])
       (match* (r1 r2)
         [((tu _ u1) (tu init-ty u2))
          (define fn-ty (expr-Pi mw init-ty
                          (expr-Pi mw (shift 1 0 init-ty)
                            (shift 2 0 init-ty))))
          (let ([r3 (checkQ ctx merge fn-ty)]
                [r4 (checkQ ctx widen-fn fn-ty)]
                [r5 (checkQ ctx narrow-fn fn-ty)])
            (match* (r3 r4 r5)
              [((bu #t u3) (bu #t u4) (bu #t u5))
               (tu (expr-Sigma (expr-net-type) (expr-cell-id-type))
                   (add-usage u1 (add-usage u2 (add-usage u3 (add-usage u4 u5)))))]
              [(_ _ _) (tu-error)]))]
         [(_ _) (tu-error)]))]

    ;; net-cell-read : PropNetwork -> CellId -> A
    [(expr-net-cell-read net cell)
     (let ([r1 (inferQ ctx net)]
           [r2 (inferQ ctx cell)])
       (match* (r1 r2)
         [((tu _ u1) (tu _ u2))
          (tu (infer ctx e) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]

    ;; net-cell-write : PropNetwork -> CellId -> A -> PropNetwork
    [(expr-net-cell-write net cell val)
     (let ([r1 (inferQ ctx net)]
           [r2 (inferQ ctx cell)]
           [r3 (inferQ ctx val)])
       (match* (r1 r2 r3)
         [((tu _ u1) (tu _ u2) (tu _ u3))
          (tu (expr-net-type) (add-usage u1 (add-usage u2 u3)))]
         [(_ _ _) (tu-error)]))]

    ;; net-add-prop : PropNetwork -> [List CellId] -> [List CellId] -> fn -> [PropNetwork * PropId]
    [(expr-net-add-prop net ins outs fn)
     (let ([r1 (inferQ ctx net)]
           [r2 (inferQ ctx ins)]
           [r3 (inferQ ctx outs)]
           [r4 (inferQ ctx fn)])
       (match* (r1 r2 r3 r4)
         [((tu _ u1) (tu _ u2) (tu _ u3) (tu _ u4))
          (tu (expr-Sigma (expr-net-type) (expr-prop-id-type))
              (add-usage u1 (add-usage u2 (add-usage u3 u4))))]
         [(_ _ _ _) (tu-error)]))]

    ;; net-run : PropNetwork -> PropNetwork
    [(expr-net-run net)
     (let ([r1 (inferQ ctx net)])
       (match r1
         [(tu _ u) (tu (expr-net-type) u)]
         [_ (tu-error)]))]

    ;; net-snapshot : PropNetwork -> PropNetwork
    [(expr-net-snapshot net)
     (let ([r1 (inferQ ctx net)])
       (match r1
         [(tu _ u) (tu (expr-net-type) u)]
         [_ (tu-error)]))]

    ;; net-contradict? : PropNetwork -> Bool
    [(expr-net-contradiction net)
     (let ([r1 (inferQ ctx net)])
       (match r1
         [(tu _ u) (tu (expr-Bool) u)]
         [_ (tu-error)]))]

    ;; ---- UnionFind type constructor ----
    [(expr-uf-type) (tu (expr-Type (lzero)) (zero-usage n))]
    ;; Runtime wrapper
    [(expr-uf-store _) (tu (expr-uf-type) (zero-usage n))]

    ;; ---- UnionFind operations ----

    ;; uf-empty : UnionFind
    [(expr-uf-empty) (tu (expr-uf-type) (zero-usage n))]

    ;; uf-make-set : UnionFind -> Nat -> A -> UnionFind
    [(expr-uf-make-set store id val)
     (let ([r1 (inferQ ctx store)]
           [r2 (inferQ ctx id)]
           [r3 (inferQ ctx val)])
       (match* (r1 r2 r3)
         [((tu _ u1) (tu _ u2) (tu _ u3))
          (tu (expr-uf-type) (add-usage u1 (add-usage u2 u3)))]
         [(_ _ _) (tu-error)]))]

    ;; uf-find : UnionFind -> Nat -> [Nat * UnionFind]
    [(expr-uf-find store id)
     (let ([r1 (inferQ ctx store)]
           [r2 (inferQ ctx id)])
       (match* (r1 r2)
         [((tu _ u1) (tu _ u2))
          (tu (expr-Sigma (expr-Nat) (expr-uf-type)) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]

    ;; uf-union : UnionFind -> Nat -> Nat -> UnionFind
    [(expr-uf-union store id1 id2)
     (let ([r1 (inferQ ctx store)]
           [r2 (inferQ ctx id1)]
           [r3 (inferQ ctx id2)])
       (match* (r1 r2 r3)
         [((tu _ u1) (tu _ u2) (tu _ u3))
          (tu (expr-uf-type) (add-usage u1 (add-usage u2 u3)))]
         [(_ _ _) (tu-error)]))]

    ;; uf-value : UnionFind -> Nat -> A (type-unsafe)
    [(expr-uf-value store id)
     (let ([r1 (inferQ ctx store)]
           [r2 (inferQ ctx id)])
       (match* (r1 r2)
         [((tu _ u1) (tu _ u2))
          (tu (infer ctx e) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]

    ;; ---- Tabling type constructor + wrapper ----
    [(expr-table-store-type) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-table-store-val _) (tu (expr-table-store-type) (zero-usage n))]

    ;; ---- Tabling operations ----

    ;; table-new : PropNetwork -> TableStore
    [(expr-table-new net)
     (let ([r1 (inferQ ctx net)])
       (match r1
         [(tu _ u) (tu (expr-table-store-type) u)]
         [_ (tu-error)]))]

    ;; table-register : TableStore -> Keyword -> Keyword -> [TableStore * CellId]
    [(expr-table-register s n m)
     (let ([r1 (inferQ ctx s)]
           [r2 (inferQ ctx n)]
           [r3 (inferQ ctx m)])
       (match* (r1 r2 r3)
         [((tu _ u1) (tu _ u2) (tu _ u3))
          (tu (infer ctx e) (add-usage u1 (add-usage u2 u3)))]
         [(_ _ _) (tu-error)]))]

    ;; table-add : TableStore -> Keyword -> A -> TableStore
    [(expr-table-add s n a)
     (let ([r1 (inferQ ctx s)]
           [r2 (inferQ ctx n)]
           [r3 (inferQ ctx a)])
       (match* (r1 r2 r3)
         [((tu _ u1) (tu _ u2) (tu _ u3))
          (tu (expr-table-store-type) (add-usage u1 (add-usage u2 u3)))]
         [(_ _ _) (tu-error)]))]

    ;; table-answers : TableStore -> Keyword -> _ (type-unsafe)
    [(expr-table-answers s n)
     (let ([r1 (inferQ ctx s)]
           [r2 (inferQ ctx n)])
       (match* (r1 r2)
         [((tu _ u1) (tu _ u2))
          (tu (infer ctx e) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]

    ;; table-freeze : TableStore -> Keyword -> TableStore
    [(expr-table-freeze s n)
     (let ([r1 (inferQ ctx s)]
           [r2 (inferQ ctx n)])
       (match* (r1 r2)
         [((tu _ u1) (tu _ u2))
          (tu (expr-table-store-type) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]

    ;; table-complete? : TableStore -> Keyword -> Bool
    [(expr-table-complete s n)
     (let ([r1 (inferQ ctx s)]
           [r2 (inferQ ctx n)])
       (match* (r1 r2)
         [((tu _ u1) (tu _ u2))
          (tu (expr-Bool) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]

    ;; table-run : TableStore -> TableStore
    [(expr-table-run s)
     (let ([r1 (inferQ ctx s)])
       (match r1
         [(tu _ u) (tu (expr-table-store-type) u)]
         [_ (tu-error)]))]

    ;; table-lookup : TableStore -> Keyword -> A -> Bool
    [(expr-table-lookup s n a)
     (let ([r1 (inferQ ctx s)]
           [r2 (inferQ ctx n)]
           [r3 (inferQ ctx a)])
       (match* (r1 r2 r3)
         [((tu _ u1) (tu _ u2) (tu _ u3))
          (tu (expr-Bool) (add-usage u1 (add-usage u2 u3)))]
         [(_ _ _) (tu-error)]))]

    ;; ---- Relational language (Phase 7) ----
    ;; Type constructors → zero usage
    [(expr-solver-type) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-goal-type) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-derivation-type) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-cut) (tu (expr-goal-type) (zero-usage n))]
    [(expr-answer-type t)
     (if t
         (let ([r (inferQ ctx t)])
           (match r
             [(tu _ u) (tu (expr-Type (lzero)) u)]
             [_ (tu-error)]))
         (tu (expr-Type (lzero)) (zero-usage n)))]
    [(expr-relation-type pts)
     (let ([rs (map (lambda (p) (inferQ ctx p)) pts)])
       (define usages (for/list ([r (in-list rs)])
                        (match r [(tu _ u) u] [_ (zero-usage n)])))
       (tu (expr-Type (lzero)) (foldl add-usage (zero-usage n) usages)))]
    [(expr-solver-config _) (tu (expr-solver-type) (zero-usage n))]
    [(expr-logic-var _ _) (tu (expr-hole) (zero-usage n))]
    ;; Compound relational nodes — sum sub-expression usages
    [(expr-defr nm sc vs)
     (define su (if sc (match (inferQ ctx sc) [(tu _ u) u] [_ (zero-usage n)]) (zero-usage n)))
     (define vus (for/list ([v (in-list vs)])
                   (match (inferQ ctx v) [(tu _ u) u] [_ (zero-usage n)])))
     (tu (expr-hole) (foldl add-usage su vus))]
    [(expr-defr-variant ps bd)
     (define us (map (lambda (b) (inferQ ctx b)) bd))
     (define usages (map (lambda (r) (match r [(tu _ u) u] [_ '()])) us))
     (tu (expr-hole) (foldl add-usage (zero-usage n) usages))]
    [(expr-rel ps cls)
     (define cus (for/list ([c (in-list cls)])
                   (match (inferQ ctx c) [(tu _ u) u] [_ (zero-usage n)])))
     (tu (expr-hole) (foldl add-usage (zero-usage n) cus))]
    [(expr-clause gs)
     (define gus (for/list ([g (in-list gs)])
                   (match (inferQ ctx g) [(tu _ u) u] [_ (zero-usage n)])))
     (tu (expr-goal-type) (foldl add-usage (zero-usage n) gus))]
    [(expr-fact-block rs)
     (define rus (for/list ([r (in-list rs)])
                   (match (inferQ ctx r) [(tu _ u) u] [_ (zero-usage n)])))
     (tu (expr-goal-type) (foldl add-usage (zero-usage n) rus))]
    [(expr-fact-row ts)
     (define tus (for/list ([t (in-list ts)])
                   (match (inferQ ctx t) [(tu _ u) u] [_ (zero-usage n)])))
     (tu (expr-hole) (foldl add-usage (zero-usage n) tus))]
    [(expr-goal-app nm as)
     ;; POL.5 (Rel T1, 2026-07-24): the goal HEAD is a RELATIONAL identifier —
     ;; a raw symbol resolved via the relation store, not a functional binding —
     ;; so its inferQ hits the [_ (tu-error)] fallback. The typing-core twin arm
     ;; DISCARDS the name's infer entirely; propagating the failure here poisoned
     ;; every `def x := solve (…)` into a spurious "Multiplicity violation"
     ;; (checkQ-top's generic reporter — same bug class as the F1a.2 `def m0 := {}`
     ;; fix). The head contributes ZERO usage when un-inferQ-able; args normally.
     (let ([rn (inferQ ctx nm)])
       (define u0 (match rn [(tu _ u) u] [_ (zero-usage n)]))
       (define nus (for/list ([a (in-list as)])
                     (match (inferQ ctx a) [(tu _ u) u] [_ (zero-usage n)])))
       (tu (expr-goal-type) (foldl add-usage u0 nus)))]
    [(expr-unify-goal l r)
     (let ([r1 (inferQ ctx l)] [r2 (inferQ ctx r)])
       (match* (r1 r2)
         [((tu _ u1) (tu _ u2)) (tu (expr-goal-type) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-is-goal v ex)
     (let ([r1 (inferQ ctx v)] [r2 (inferQ ctx ex)])
       (match* (r1 r2)
         [((tu _ u1) (tu _ u2)) (tu (expr-goal-type) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    [(expr-not-goal g)
     (let ([r (inferQ ctx g)])
       (match r [(tu _ u) (tu (expr-goal-type) u)] [_ (tu-error)]))]
    [(expr-guard cond goal)
     (let ([r1 (inferQ ctx cond)] [r2 (inferQ ctx goal)])
       (match* (r1 r2)
         [((tu _ u1) (tu _ u2)) (tu (expr-goal-type) (add-usage u1 u2))]
         [(_ _) (tu-error)]))]
    ;; Solve/Explain → typed solution rows (Rel T1 Aspect B, B1). Usage from the
    ;; goal (+ solver/overrides for -with); the TYPE is the shared solve-row-type
    ;; twin of the typing-core arms (query-var keys, schema-projected field types).
    [(expr-solve g)
     (let ([r (inferQ ctx g)])
       (match r [(tu _ u) (tu (solve-row-type g 'pvec) u)] [_ (tu-error)]))]
    [(expr-solve-with sv ov g)
     (define su (if sv (match (inferQ ctx sv) [(tu _ u) u] [_ (zero-usage n)]) (zero-usage n)))
     (define ou (if ov (match (inferQ ctx ov) [(tu _ u) u] [_ (zero-usage n)]) (zero-usage n)))
     (let ([rg (inferQ ctx g)])
       (match rg
         [(tu _ ug) (tu (solve-row-type g 'pvec) (add-usage su (add-usage ou ug)))]
         [_ (tu-error)]))]
    [(expr-solve-one g)
     (let ([r (inferQ ctx g)])
       (match r [(tu _ u) (tu (solve-row-type g 'bare) u)] [_ (tu-error)]))]
    [(expr-explain g)
     (let ([r (inferQ ctx g)])
       (match r [(tu _ u) (tu (solve-row-type g 'pvec 'dyn) u)] [_ (tu-error)]))]
    [(expr-explain-with sv ov g)
     (define su (if sv (match (inferQ ctx sv) [(tu _ u) u] [_ (zero-usage n)]) (zero-usage n)))
     (define ou (if ov (match (inferQ ctx ov) [(tu _ u) u] [_ (zero-usage n)]) (zero-usage n)))
     (let ([rg (inferQ ctx g)])
       (match rg
         [(tu _ ug) (tu (solve-row-type g 'pvec 'dyn) (add-usage su (add-usage ou ug)))]
         [_ (tu-error)]))]

    ;; ---- J eliminator ----
    ;; Usage from proof, base, motive arguments
    ;; Usage = U_proof + U_base.
    ;;
    ;; ⚠ THE BASE'S USAGE WAS DROPPED ENTIRELY until QTT P7 (2026-07-31): this arm
    ;; verified the base with typing-core's BOOLEAN `check`, which computes no
    ;; usage, and returned `u5` (the proof's usage) alone. So a linear value
    ;; consumed inside J's base was invisible — an under-count to ZERO, strictly
    ;; worse than the under-count-to-one this commit fixes elsewhere. Using
    ;; `checkQ` performs the same type check AND yields the usage.
    ;;
    ;; ADDED, not mw-scaled: unlike a fold's function argument, J's base is
    ;; applied exactly ONCE (reduction.rkt's J rule), so it is ordinary
    ;; sequential composition.
    [(expr-J mot base left right proof)
     (let ([r5 (inferQ ctx proof)])
       (match r5
         [(tu t5 u5)
          (match (whnf t5)
            [(expr-Eq t t1 t2)
             ;; base type: Π(a:A). motive(a, a, refl)
             (let ([base-type
                    (expr-Pi 'mw t
                      (expr-app (expr-app (expr-app (shift 1 0 mot) (expr-bvar 0))
                                          (expr-bvar 0))
                                (expr-refl)))])
               (if (and (unify-ok? (unify ctx t1 left))
                        (unify-ok? (unify ctx t2 right)))
                   (match (checkQ ctx base base-type)
                     [(bu #t ub)
                      (tu (expr-app (expr-app (expr-app mot left) right) proof)
                          (add-usage u5 ub))]
                     [_ (tu-error)])
                   (tu-error)))]
            [_ (tu-error)])]
         [_ (tu-error)]))]

    ;; ---- Vec/Fin type constructors: zero usage for types ----
    [(expr-Vec _ _) (tu (expr-Type (lzero)) (zero-usage n))]
    [(expr-Fin _) (tu (expr-Type (lzero)) (zero-usage n))]

    ;; ---- N4: numeric literal in infer position → DEFAULT type (Int if integral else Rat); zero usage ----
    [(expr-num-lit _ integral? origin _) (tu (num-lit-default-type origin integral?) (zero-usage n))]

    ;; ---- Fallback ----
    [_ (tu-error)]))

;; ========================================
;; QTT checking: checkQ(ctx, e, T) -> BoolUsage
;; ========================================
(define (checkQ ctx e t)
  (define n (ctx-len ctx))
  (define t-whnf (whnf t))
  (match* (e t-whnf)
    ;; ---- suc: check against Nat ----
    [((expr-suc e1) (expr-Nat))
     (let ([r (checkQ ctx e1 (expr-Nat))])
       (match r
         [(bu #t u) (bu #t u)]
         [_ (bu #f (zero-usage n))]))]
    ;; ---- nat-val: always Nat, zero usage ----
    [((expr-nat-val _) (expr-Nat)) (bu #t (zero-usage n))]

    ;; ---- Panic: inhabits any type, count msg usage ----
    [((expr-panic msg) _)
     (let ([r (checkQ ctx msg (expr-String))])
       (match r
         [(bu #t u) (bu #t u)]
         [_ (bu #f (zero-usage n))]))]

    ;; ---- Vec / Fin constructors: CHECK-only, by necessity ----
    ;; QTT P5 (2026-07-30). These four MUST be checkQ arms, not inferQ arms:
    ;; typing-core has no `infer` case for any of them (they are check-only
    ;; there too), so without an arm here the conversion fallback delegates to
    ;; inferQ, hits its `[_ (tu-error)]` catch-all, and EVERY annotated Vec/Fin
    ;; def dies as a generic "Multiplicity violation" — the lying-diagnostic
    ;; class, naming a subsystem that is working perfectly.
    ;;
    ;; The usage split follows the runtime/type-level split in each struct, and
    ;; that split is not guesswork: whnf's computation rules
    ;;   [(expr-vhead _ _ (expr-vcons _ _ hd _)) (whnf hd)]
    ;;   [(expr-vtail _ _ (expr-vcons _ _ _ tl)) (whnf tl)]
    ;; DISCARD the type and length fields and consume only head/tail, so the
    ;; indices are erased and contribute NO usage while head/tail contribute
    ;; their own. Type-side validation is left to typing-core's own arms (the
    ;; no-drift twin pattern) — these arms compute USAGE.

    ;; vnil(A) : Vec(A, zero) — A is type-level, so no usage at all.
    [((expr-vnil _) (expr-Vec _ _)) (bu #t (zero-usage n))]

    ;; vcons(A, n, head, tail) : Vec(A, suc n) — head and tail each consumed ONCE.
    ;; add-usage, not join: both are stored, so both happen (this is sequential
    ;; composition, not alternation). A linear value consed into a vector is
    ;; therefore consumed exactly once, which is what makes Vec linear-safe.
    [((expr-vcons a1 n1 hd tl) (expr-Vec _ _))
     (match* ((checkQ ctx hd a1) (checkQ ctx tl (expr-Vec a1 n1)))
       [((bu #t u-hd) (bu #t u-tl)) (bu #t (add-usage u-hd u-tl))]
       [(_ _) (bu #f (zero-usage n))])]

    ;; fzero(n) : Fin(suc n) — n is the type-level bound; nothing runs.
    [((expr-fzero _) (expr-Fin _)) (bu #t (zero-usage n))]

    ;; fsuc(n, i) : Fin(suc n) — `i` is the runtime predecessor, `n` the bound.
    ;; Mirrors the `suc` arm above, which counts its argument's usage.
    [((expr-fsuc n1 i) (expr-Fin _))
     (match (checkQ ctx i (expr-Fin n1))
       [(bu #t u) (bu #t u)]
       [_ (bu #f (zero-usage n))])]

    ;; ---- Reduce (pattern match): the arms ALTERNATE ----
    ;; usage = U_scrutinee + JOIN over arms of (arm-body usage, binders stripped)
    ;;
    ;; Until 2026-07-30 there was NO arm here: `contains-unsupported-qtt?`
    ;; (driver.rkt) returned #t for expr-reduce and the driver SKIPPED
    ;; checkQ-top entirely, so every `match` and every multi-clause `defn` — the
    ;; language's PRIMARY dispatch form — escaped multiplicity checking. The
    ;; stdlib's only linear API (fio's `-1>` handles) is match-implemented, so its
    ;; linearity was declared and never checked. Demonstrated at the time:
    ;;   defn dup       [b] (pair b b)                     → correctly rejected
    ;;   defn dup-match [b] match b (mk-box n -> (pair b b)) → ACCEPTED, 0 errors
    ;;
    ;; TYPE work is not redone here — arm bodies are CHECKED against the expected
    ;; type, and the per-arm binder ctx comes from typing-core's `reduce-arm-ctx`,
    ;; the very derivation `check-reduce-structural` uses. One derivation, two
    ;; consumers (pipeline.md § "infer / inferQ Are Twins").
    ;;
    ;; PERMISSIVE FALLBACK, and its LIMIT (QTT P6, 2026-07-31).
    ;;
    ;; When the scrutinee's type carries no constructor metadata (the Church-fold
    ;; path — live, despite typing-core's comment claiming otherwise) or a
    ;; constructor's type cannot be found, the arm's field multiplicities cannot
    ;; be derived. Such an arm binds its fields at `mw` and, if its own checkQ
    ;; then fails, contributes NO usage rather than failing the whole match —
    ;; because failing would reject code over a mere lookup gap.
    ;;
    ;; ⚠ THAT TRADE HAS A HARD LIMIT, and P6 enforces it. The earlier version of
    ;; this comment claimed the fallback "cannot invent a violation, only miss
    ;; one", that "outer variables stay tracked either way", and that "the
    ;; baseline is no checking whatsoever". All three were false: the accumulated
    ;; usage is the join over SURVIVING arms only, so a linear consumed solely
    ;; inside a skipped arm reads m0 and surfaces as a WRONG-CAUSE "declared :1
    ;; but is not used"; and P5 deleted the driver guard, so the baseline is now
    ;; full checking. Worse, the skip swallowed nested violations: an arm whose
    ;; own body contained a linear-per-path disagreement failed, was skipped, and
    ;; the disagreement vanished — a real leak AND a real double-free both
    ;; type-checked clean (probe /tmp/qtt-p6-g.prologos; the Bool-scrutinee
    ;; control was correctly rejected in the same run).
    ;;
    ;; So the fallback now stops exactly where it stops being safe: if any arm was
    ;; skipped AND a linear resource is at stake in the surviving arms'
    ;; accumulated usage, linear-per-path is UNDECIDABLE and the match is refused.
    ;; When nothing linear is in play the permissive path is untouched — this
    ;; rejects only what it can show it cannot verify, and says so in the message
    ;; rather than reporting a generic violation.
    [((expr-reduce scrutinee arms _) expected-type)
     (let ([scrut-type (infer ctx scrutinee)])
       (cond
         [(expr-error? scrut-type) (bu #f (zero-usage n))]
         [else
          (let*-values ([(tc targs) (reduce-scrutinee-decompose scrut-type)])
            (let ([r-scrut (checkQ ctx scrutinee scrut-type)])
              (match r-scrut
                [(bu #t u-scrut)
                 (let loop ([as arms] [acc #f] [skipped? #f])
                   (cond
                     [(null? as)
                      ;; No arm contributed (empty/unanalysable match): the
                      ;; scrutinee's own usage still stands.
                      ;;
                      ;; QTT P6: but if any arm was SKIPPED as unanalysable and a
                      ;; linear resource is at stake, linear-per-path cannot be
                      ;; verified for it — refuse instead of accepting. Checked
                      ;; HERE, at the end, rather than at the skip: an arm skipped
                      ;; BEFORE the consuming arm is reached would otherwise slip
                      ;; through, so the test must see the final accumulator.
                      (let ([final (or acc (zero-usage n))])
                        (if (and skipped? (linear-at-stake? ctx final))
                            (bu #f (zero-usage n))
                            (bu #t (add-usage u-scrut final))))]
                     [else
                      (let* ([arm (car as)]
                             [bc (expr-reduce-arm-binding-count arm)]
                             [body (expr-reduce-arm-body arm)]
                             [strict-ctx (and tc (reduce-arm-ctx ctx arm tc targs))]
                             [ext-ctx
                              (or strict-ctx
                                  ;; fallback: unknown fields bound unrestricted
                                  (for/fold ([c ctx]) ([_ (in-range bc)])
                                    (ctx-extend c (expr-hole) 'mw)))]
                             [r (checkQ ext-ctx body (shift bc 0 expected-type))]
                             [trimmed
                              (match r
                                [(bu #t u-arm) (strip-binders ext-ctx u-arm bc)]
                                [_ #f])])
                        (cond
                          ;; A well-derived arm that fails IS a real violation.
                          [(and strict-ctx (not trimmed)) (bu #f (zero-usage n))]
                          ;; An unanalysable arm contributes nothing, but is
                          ;; RECORDED — see the end-of-loop check.
                          [(not trimmed) (loop (cdr as) acc #t)]
                          ;; Length divergence would silently pad at the join.
                          [(not (= (length trimmed) n)) (bu #f (zero-usage n))]
                          [else
                           ;; Linear-per-path: every arm must make the SAME
                           ;; consumption decision about each linear resource.
                           ;; Folded against the running accumulator — sound
                           ;; because disagreeing with the accumulated value
                           ;; means disagreeing with some earlier arm.
                           (let ([uj (if acc (join-branches ctx acc trimmed) trimmed)])
                             (if uj
                                 (loop (cdr as) uj skipped?)
                                 (bu #f (zero-usage n))))]))]))]
                [_ (bu #f (zero-usage n))])))]))]

    ;; ---- Let (beta-redex): propagate the expected type into the body ----
    ;; `(app (lam m dom body) arg)` is the desugared `let`. typing-core's `check`
    ;; has this arm (see its "Let pattern (beta-redex)" case) precisely so the
    ;; body is CHECKED rather than inferred; checkQ lacked the twin, so a
    ;; let-bound body fell through to the conversion fallback → `inferQ` →
    ;; app-of-lam → `inferQ` on the body. That was harmless while reduce was
    ;; skipped wholesale, but with the arm above in place a `let`-bound `match`
    ;; would reach inferQ, which has no reduce arm, and report a spurious
    ;; "Multiplicity violation". Mirrors the app-of-lam usage rule in inferQ:
    ;; the argument's usage is scaled by the binder's multiplicity.
    [((expr-app (expr-lam m dom body) arg) expected-type)
     (let* ([arg-dom (if (or (expr-hole? dom) (expr-typed-hole? dom))
                         (let ([ri (inferQ ctx arg)])
                           (match ri [(tu ty _) ty] [_ #f]))
                         dom)])
       (cond
         [(not arg-dom) (bu #f (zero-usage n))]
         [else
          (match (checkQ ctx arg arg-dom)
            [(bu #t u-arg)
             (match (checkQ (ctx-extend ctx arg-dom m) body
                            (shift 1 0 expected-type))
               [(bu #t u-body)
                (bu #t (add-usage (scale-usage m u-arg) (utail u-body)))]
               [_ (bu #f (zero-usage n))])]
            [_ (bu #f (zero-usage n))])]))]

    ;; ---- Lambda: check against Pi ----
    ;; Sprint 7: mult-meta-aware — resolve mult-metas from Pi context or usage
    [((expr-lam m a body) (expr-Pi m2 t-dom b))
     (let* ([effective-m (cond
                           [(mult-meta? m) (if (mult-meta? m2) 'mw m2)]
                           [(mult-meta? m2) m]
                           [else m])]
            [mults-ok (or (mult-meta? m) (mult-meta? m2) (eq? m m2))])
       (cond
         [(not mults-ok)
          (bu #f (zero-usage n))]
         [(and (not (expr-hole? a)) (not (unify-ok? (unify ctx a t-dom))))
          (bu #f (zero-usage n))]
         [else
          ;; Use Pi domain when lambda domain is a hole (mirrors type checker behavior)
          (define ctx-dom (if (expr-hole? a) t-dom a))
          (let ([r (checkQ (ctx-extend ctx ctx-dom effective-m) body b)])
            (match r
              [(bu #t u)
               (let ([actual-usage (uhead u)])
                 ;; Sprint 7: solve mult-metas to observed usage
                 (when (and (mult-meta? m) (not (mult-meta-solved? (mult-meta-id m))))
                   (solve-mult-meta! (mult-meta-id m) actual-usage))
                 (when (and (mult-meta? m2) (not (mult-meta-solved? (mult-meta-id m2))))
                   (solve-mult-meta! (mult-meta-id m2) actual-usage))
                 (if (compatible effective-m actual-usage)
                     (bu #t (utail u))
                     (bu #f (zero-usage n))))]
              [_ (bu #f (zero-usage n))]))]))]

    ;; ---- Pair: check against Sigma ----
    [((expr-pair e1 e2) (expr-Sigma a b))
     (let ([r1 (checkQ ctx e1 a)])
       (match r1
         [(bu #t u1)
          (let ([r2 (checkQ ctx e2 (subst 0 e1 b))])
            (match r2
              [(bu #t u2) (bu #t (add-usage u1 u2))]
              [_ (bu #f (zero-usage n))]))]
         [_ (bu #f (zero-usage n))]))]

    ;; ---- refl: check against Eq ----
    [((expr-refl) (expr-Eq _ e1 e2))
     (bu (unify-ok? (unify ctx e1 e2)) (zero-usage n))]

    ;; ---- Holes: optimistically succeed with zero usage ----
    ;; Holes (_, ??name) don't consume resources — mirrors typing-core check behavior.
    [((expr-hole) _) (bu #t (zero-usage n))]
    [((expr-typed-hole _) _) (bu #t (zero-usage n))]

    ;; ---- Open: α-semantic wildcard (PPN 4C T-2, 2026-04-23) ----
    ;; Open unifies in both directions with zero resource usage.

    ;; ---- Meta expression: optimistically succeed with zero usage ----
    ;; A metavariable (from implicit arg insertion) doesn't consume resources.
    [((expr-meta _ _) _) (bu #t (zero-usage n))]

    ;; ---- N4: context-typed numeric literal — mirror typing-core check: resolve alpha
    ;; ---- from the expected type + validate representability. Zero resource usage.
    [((expr-num-lit exact-val integral? _origin alpha) T)
     (cond
       [(concrete-numeric-type? T)
        (bu (and (num-lit-representable? exact-val integral? T)
                 (unify-ok? (unify ctx alpha T)))
            (zero-usage n))]
       [(expr-meta? T)
        (bu (unify-ok? (unify ctx alpha T)) (zero-usage n))]
       [else (bu #f (zero-usage n))])]

    ;; ---- Symbol literal: check against Symbol type ----
    [((expr-symbol _) (expr-Symbol)) (bu #t (zero-usage n))]

    ;; ---- Keyword literal: check against Keyword type ----
    [((expr-keyword _) (expr-Keyword)) (bu #t (zero-usage n))]

    ;; ---- Char literal: check against Char type ----
    [((expr-char _) (expr-Char)) (bu #t (zero-usage n))]

    ;; ---- String literal: check against String type ----
    [((expr-string _) (expr-String)) (bu #t (zero-usage n))]

    ;; ---- Map constructors: check against Map type ----
    [((expr-champ _) (expr-Map _ _)) (bu #t (zero-usage n))]
    [((expr-map-empty k v) (expr-Map _ _))
     (let ([r1 (inferQ ctx k)]
           [r2 (inferQ ctx v)])
       (match* (r1 r2)
         [((tu _ u1) (tu _ u2))
          (bu #t (scale-usage 'm0 (add-usage u1 u2)))]  ;; type args are erased
         [(_ _) (bu #f (zero-usage n))]))]
    ;; map-assoc checked against Map K V — propagate expected type
    [((expr-map-assoc m k v) (expr-Map kt vt))
     (let ([rm (checkQ ctx m (expr-Map kt vt))]
           [rk (checkQ ctx k kt)]
           [rv (checkQ ctx v vt)])
       (match* (rm rk rv)
         [((bu #t u1) (bu #t u2) (bu #t u3))
          (bu #t (add-usage u1 (add-usage u2 u3)))]
         [(_ _ _) (bu #f (zero-usage n))]))]

    ;; ---- Map constructors: check against Schema type (fvar) ----
    ;; Schema types are opaque fvar types backed by maps; QTT tracks usage normally.
    ;; CIU T6 F1b.4a (D22.8): the champ twin RETIRED LOUD (mirror of
    ;; typing-core — runtime maps seal via validate, F1b.5; fails closed).
    [((expr-champ _) (expr-fvar name))
     #:when (lookup-schema-by-name name)
     (bu #f (zero-usage n))]
    [((expr-map-empty _ _) (expr-fvar name))
     #:when (lookup-schema-by-name name)
     ;; Type args of map-empty are erased (m0) — zero usage, same as (expr-champ)
     (bu #t (zero-usage n))]
    [((expr-map-assoc m k v) (expr-fvar name))
     #:when (lookup-schema-by-name name)
     ;; Check submap against same schema type; infer key/value usage
     (let ([rm (checkQ ctx m (expr-fvar name))]
           [rk (inferQ ctx k)]
           [rv (inferQ ctx v)])
       (match* (rm rk rv)
         [((bu #t u1) (tu _ u2) (tu _ u3))
          (bu #t (add-usage u1 (add-usage u2 u3)))]
         [(_ _ _) (bu #f (zero-usage n))]))]
    ;; ---- Map constructors: check against Selection type (fvar) ----
    ;; Selection types delegate to parent schema at value level.
    ;; CIU T6 F1b.4a (D22.8): the champ twin RETIRED LOUD (mirror of
    ;; typing-core; runtime maps seal via validate, F1b.5; fails closed).
    [((expr-champ _) (expr-fvar name))
     #:when (lookup-selection-by-name name)
     (bu #f (zero-usage n))]
    [((expr-map-empty _ _) (expr-fvar name))
     #:when (lookup-selection-by-name name)
     (bu #t (zero-usage n))]
    [((expr-map-assoc m k v) (expr-fvar name))
     #:when (lookup-selection-by-name name)
     ;; Selection types delegate to parent schema at value level for QTT.
     (let ([rm (checkQ ctx m (expr-fvar name))]
           [rk (inferQ ctx k)]
           [rv (inferQ ctx v)])
       (match* (rm rk rv)
         [((bu #t u1) (tu _ u2) (tu _ u3))
          (bu #t (add-usage u1 (add-usage u2 u3)))]
         [(_ _ _) (bu #f (zero-usage n))]))]

    ;; ---- Set constructors: check against Set type ----
    [((expr-hset _) (expr-Set _)) (bu #t (zero-usage n))]
    [((expr-set-empty a) (expr-Set _))
     (let ([r (inferQ ctx a)])
       (match r
         [(tu _ u) (bu #t (scale-usage 'm0 u))]  ;; type arg is erased
         [_ (bu #f (zero-usage n))]))]
    [((expr-set-insert s a) (expr-Set a-ty))
     (let ([rs (checkQ ctx s (expr-Set a-ty))]
           [ra (checkQ ctx a a-ty)])
       (match* (rs ra)
         [((bu #t u1) (bu #t u2))
          (bu #t (add-usage u1 u2))]
         [(_ _) (bu #f (zero-usage n))]))]

    ;; ---- PVec constructors: check against PVec type ----
    [((expr-rrb _) (expr-PVec _)) (bu #t (zero-usage n))]
    [((expr-pvec-empty a) (expr-PVec _))
     (let ([r (inferQ ctx a)])
       (match r
         [(tu _ u) (bu #t (scale-usage 'm0 u))]  ;; type arg is erased
         [_ (bu #f (zero-usage n))]))]
    [((expr-pvec-push v x) (expr-PVec a))
     (let ([rv (checkQ ctx v (expr-PVec a))]
           [rx (checkQ ctx x a)])
       (match* (rv rx)
         [((bu #t u1) (bu #t u2))
          (bu #t (add-usage u1 u2))]
         [(_ _) (bu #f (zero-usage n))]))]
    ;; CIU T6 F1a-col-2: list literal vs (List A) — each element against A in
    ;; CHECK mode. Load-bearing: operator values / sections (int+, [_ * 2]) only
    ;; elaborate with an expected type (issue-#76 class); the inferQ fallback
    ;; would run them in INFER mode and fail (test-prim-op-firstclass).
    [((expr-list-literal elems _) expected)
     #:when (match (whnf expected)
              [(expr-app f _) (equal? f (list-type-fvar))]
              [_ #f])
     (match (whnf expected)
       [(expr-app _ a)
        (let loop ([es elems] [u (zero-usage n)])
          (if (null? es)
              (bu #t u)
              (match (checkQ ctx (car es) a)
                [(bu #t ue) (loop (cdr es) (add-usage u ue))]
                [_ (bu #f (zero-usage n))])))])]
    ;; CIU T6 F1a.2 p1b (D18): map literal vs (Map K V) — keys against K, values
    ;; against V in CHECK mode (the issue-#76 operator-value class).
    [((expr-map-literal keys vals _) (expr-Map kt vt))
     (let loop ([es (map (lambda (k) (cons k kt)) keys)] [u (zero-usage n)]
                [rest (map (lambda (v) (cons v vt)) vals)])
       (cond
         [(and (null? es) (null? rest)) (bu #t u)]
         [(null? es) (loop rest u '())]
         [else
          (match (checkQ ctx (caar es) (cdar es))
            [(bu #t ue) (loop (cdr es) (add-usage u ue) rest)]
            [_ (bu #f (zero-usage n))])]))]
    ;; CIU T6 F1a-col: literal vs (PVec A) — each element against A (C2 mirror)
    [((expr-pvec-literal elems) (expr-PVec a))
     (let loop ([es elems] [u (zero-usage n)])
       (if (null? es)
           (bu #t u)
           (match (checkQ ctx (car es) a)
             [(bu #t ue) (loop (cdr es) (add-usage u ue))]
             [_ (bu #f (zero-usage n))])))]
    ;; pvec-fold : check f, init, vec — result type is expected-type
    [((expr-pvec-fold f init vec) expected-type)
     (let ([rv (inferQ ctx vec)]
           [ri (checkQ ctx init expected-type)])
       (match* (rv ri)
         [((tu tv uv) (bu #t ui))
          (match (whnf tv)
            [(expr-PVec a)
             (let* ([ef (expr-Pi 'mw expected-type
                          (expr-Pi 'mw (shift 1 0 a) (shift 2 0 expected-type)))]
                    [rf (inferQ-or-checkQ ctx f ef)])
               (match rf
                 [(tu _ uf) (bu #t (add-usage (add-usage (scale-usage 'mw uf) ui) uv))]
                 [_ (bu #f (zero-usage n))]))]
            ;; CIU T6 F1a-col-3: fold over a tuple in CHECK mode — uniform view
            ;; (the issue-#76 class: checked positions must not fall to inferQ)
            [(? closed-nat-row? rec)
             (let* ([v (record-value-bound ctx rec "tuple-fold")]
                    [ef (expr-Pi 'mw expected-type
                          (expr-Pi 'mw (shift 1 0 v) (shift 2 0 expected-type)))]
                    [rf (inferQ-or-checkQ ctx f ef)])
               (match rf
                 [(tu _ uf) (bu #t (add-usage (add-usage (scale-usage 'mw uf) ui) uv))]
                 [_ (bu #f (zero-usage n))]))]
            [_ (bu #f (zero-usage n))])]
         [(_ _) (bu #f (zero-usage n))]))]
    ;; pvec-map : check against PVec B
    [((expr-pvec-map f vec) expected-type)
     (let ([rv (inferQ ctx vec)])
       (match rv
         [(tu tv uv)
          (match* ((whnf tv) (whnf expected-type))
            [((expr-PVec a) (expr-PVec b))
             (let ([rf (inferQ-or-checkQ ctx f (expr-Pi 'mw a (shift 1 0 b)))])
               (match rf
                 [(tu _ uf)
                  (bu (check ctx (expr-pvec-map f vec) expected-type)
                      (add-usage (scale-usage 'mw uf) uv))]
                 [_ (bu #f (zero-usage n))]))]
            ;; CIU T6 F1a-col-3: tuple source checked against (PVec B) — f consumes
            ;; ⋃positions (typing-core check-arm mirror; issue-#76 class)
            [((? closed-nat-row? rec) (expr-PVec b))
             (let ([rf (inferQ-or-checkQ ctx f
                         (expr-Pi 'mw (record-value-bound ctx rec "tuple-map") (shift 1 0 b)))])
               (match rf
                 [(tu _ uf)
                  (bu (check ctx (expr-pvec-map f vec) expected-type)
                      (add-usage (scale-usage 'mw uf) uv))]
                 [_ (bu #f (zero-usage n))]))]
            [(_ _) (bu #f (zero-usage n))])]
         [_ (bu #f (zero-usage n))]))]
    ;; pvec-filter : check against PVec A
    [((expr-pvec-filter pred vec) expected-type)
     (let ([rv (inferQ ctx vec)])
       (match rv
         [(tu tv uv)
          (match (whnf tv)
            [(expr-PVec a)
             (let ([rp (inferQ-or-checkQ ctx pred (expr-Pi 'mw a (expr-Bool)))])
               (match rp
                 [(tu _ up)
                  (bu (check ctx (expr-pvec-filter pred vec) expected-type)
                      (add-usage (scale-usage 'mw up) uv))]
                 [_ (bu #f (zero-usage n))]))]
            ;; CIU T6 F1a-col-3: tuple — pred consumes ⋃positions; the result check
            ;; delegates (the (PVec ⋃) degrade meets the annotation via the α)
            [(? closed-nat-row? rec)
             (let* ([v (record-value-bound ctx rec "tuple-filter")]
                    [rp (inferQ-or-checkQ ctx pred (expr-Pi 'mw v (expr-Bool)))])
               (match rp
                 [(tu _ up)
                  (bu (check ctx (expr-pvec-filter pred vec) expected-type)
                      (add-usage (scale-usage 'mw up) uv))]
                 [_ (bu #f (zero-usage n))]))]
            [_ (bu #f (zero-usage n))])]
         [_ (bu #f (zero-usage n))]))]
    ;; set-fold : check
    [((expr-set-fold f init set) expected-type)
     (let ([rs (inferQ ctx set)]
           [ri (checkQ ctx init expected-type)])
       (match* (rs ri)
         [((tu ts us) (bu #t ui))
          (match ts
            [(expr-Set a)
             (let* ([ef (expr-Pi 'mw expected-type
                          (expr-Pi 'mw (shift 1 0 a) (shift 2 0 expected-type)))]
                    [rf (inferQ-or-checkQ ctx f ef)])
               (match rf
                 [(tu _ uf) (bu #t (add-usage (add-usage (scale-usage 'mw uf) ui) us))]
                 [_ (bu #f (zero-usage n))]))]
            [_ (bu #f (zero-usage n))])]
         [(_ _) (bu #f (zero-usage n))]))]
    ;; set-filter : check against Set A
    [((expr-set-filter pred set) expected-type)
     (let ([rs (inferQ ctx set)])
       (match rs
         [(tu ts us)
          (match ts
            [(expr-Set a)
             (let ([rp (inferQ-or-checkQ ctx pred (expr-Pi 'mw a (expr-Bool)))])
               (match rp
                 [(tu _ up)
                  (bu (check ctx (expr-set-filter pred set) expected-type)
                      (add-usage (scale-usage 'mw up) us))]
                 [_ (bu #f (zero-usage n))]))]
            [_ (bu #f (zero-usage n))])]
         [_ (bu #f (zero-usage n))]))]
    ;; map-fold-entries : check
    [((expr-map-fold-entries f init map) expected-type)
     (let ([rm (inferQ ctx map)]
           [ri (checkQ ctx init expected-type)])
       (match* (rm ri)
         [((tu tm um) (bu #t ui))
          (match tm
            [(expr-Map k v)
             (let* ([ef (expr-Pi 'mw expected-type
                          (expr-Pi 'mw (shift 1 0 k)
                            (expr-Pi 'mw (shift 2 0 v) (shift 3 0 expected-type))))]
                    [rf (inferQ-or-checkQ ctx f ef)])
               (match rf
                 [(tu _ uf) (bu #t (add-usage (add-usage (scale-usage 'mw uf) ui) um))]
                 [_ (bu #f (zero-usage n))]))]
            ;; CIU T6 F1 (s3): fold over a record — uniform view (K=Keyword, V=⋃fields)
            [(? expr-Record? rec)
             (let* ([ef (expr-Pi 'mw expected-type
                          (expr-Pi 'mw (shift 1 0 (expr-Keyword))
                            (expr-Pi 'mw (shift 2 0 (record-value-bound ctx rec "dyn-row-fold"))
                                     (shift 3 0 expected-type))))]
                    [rf (inferQ-or-checkQ ctx f ef)])
               (match rf
                 [(tu _ uf) (bu #t (add-usage (add-usage (scale-usage 'mw uf) ui) um))]
                 [_ (bu #f (zero-usage n))]))]
            [_ (bu #f (zero-usage n))])]
         [(_ _) (bu #f (zero-usage n))]))]
    ;; map-filter-entries : check against Map K V
    [((expr-map-filter-entries pred map) expected-type)
     (let ([rm (inferQ ctx map)])
       (match rm
         [(tu tm um)
          (match tm
            [(expr-Map k v)
             (let ([rp (inferQ-or-checkQ ctx pred
                         (expr-Pi 'mw k (expr-Pi 'mw (shift 1 0 v) (expr-Bool))))])
               (match rp
                 [(tu _ up)
                  (bu (check ctx (expr-map-filter-entries pred map) expected-type)
                      (add-usage (scale-usage 'mw up) um))]
                 [_ (bu #f (zero-usage n))]))]
            ;; CIU T6 F1 (s3): filter on a record — pred consumes the uniform view;
            ;; the final type check delegates to typing-core (dictionary-view result)
            [(? expr-Record? rec)
             (let* ([v (record-value-bound ctx rec "dyn-row-filter")]
                    [rp (inferQ-or-checkQ ctx pred
                          (expr-Pi 'mw (expr-Keyword) (expr-Pi 'mw (shift 1 0 v) (expr-Bool))))])
               (match rp
                 [(tu _ up)
                  (bu (check ctx (expr-map-filter-entries pred map) expected-type)
                      (add-usage (scale-usage 'mw up) um))]
                 [_ (bu #f (zero-usage n))]))]
            [_ (bu #f (zero-usage n))])]
         [_ (bu #f (zero-usage n))]))]
    ;; map-map-vals : check against Map K W
    [((expr-map-map-vals f map) expected-type)
     (let ([rm (inferQ ctx map)])
       (match rm
         [(tu tm um)
          (match* (tm (whnf expected-type))
            [((expr-Map k2 v) (expr-Map k w))
             (let ([rf (inferQ-or-checkQ ctx f (expr-Pi 'mw v (shift 1 0 w)))])
               (match rf
                 [(tu _ uf)
                  (bu (and (unify-ok? (unify ctx k k2))
                           (check ctx (expr-map-map-vals f map) expected-type))
                      (add-usage (scale-usage 'mw uf) um))]
                 [_ (bu #f (zero-usage n))]))]
            ;; CIU T6 F1 (s3): record source vs Map result — keys are Keyword;
            ;; f consumes ⋃fields; final check delegates to typing-core
            [((? expr-Record? rec) (expr-Map k w))
             (let ([rf (inferQ-or-checkQ ctx f
                         (expr-Pi 'mw (record-value-bound ctx rec "dyn-row-map-vals") (shift 1 0 w)))])
               (match rf
                 [(tu _ uf)
                  (bu (and (unify-ok? (unify ctx k (expr-Keyword)))
                           (check ctx (expr-map-map-vals f map) expected-type))
                      (add-usage (scale-usage 'mw uf) um))]
                 [_ (bu #f (zero-usage n))]))]
            [(_ _) (bu #f (zero-usage n))])]
         [_ (bu #f (zero-usage n))]))]

    ;; ---- Transient Builder constructors: check against transient types ----
    [((expr-trrb _) (expr-TVec _)) (bu #t (zero-usage n))]
    [((expr-tchamp _) (expr-TMap _ _)) (bu #t (zero-usage n))]
    [((expr-thset _) (expr-TSet _)) (bu #t (zero-usage n))]
    [((expr-persist-vec t) (expr-PVec a))
     (let ([r (checkQ ctx t (expr-TVec a))])
       (match r
         [(bu #t u) (bu #t u)]
         [_ (bu #f (zero-usage n))]))]
    [((expr-persist-map t) (expr-Map k v))
     (let ([r (checkQ ctx t (expr-TMap k v))])
       (match r
         [(bu #t u) (bu #t u)]
         [_ (bu #f (zero-usage n))]))]
    [((expr-persist-set t) (expr-Set a))
     (let ([r (checkQ ctx t (expr-TSet a))])
       (match r
         [(bu #t u) (bu #t u)]
         [_ (bu #f (zero-usage n))]))]
    [((expr-tvec-push! t x) (expr-TVec a))
     (let ([rt (checkQ ctx t (expr-TVec a))]
           [rx (checkQ ctx x a)])
       (match* (rt rx)
         [((bu #t u1) (bu #t u2))
          (bu #t (add-usage u1 u2))]
         [(_ _) (bu #f (zero-usage n))]))]
    [((expr-tmap-assoc! t k v) (expr-TMap kt vt))
     (let ([rt (checkQ ctx t (expr-TMap kt vt))]
           [rk (checkQ ctx k kt)]
           [rv (checkQ ctx v vt)])
       (match* (rt rk rv)
         [((bu #t u1) (bu #t u2) (bu #t u3))
          (bu #t (add-usage u1 (add-usage u2 u3)))]
         [(_ _ _) (bu #f (zero-usage n))]))]
    [((expr-tset-insert! t a) (expr-TSet a-ty))
     (let ([rt (checkQ ctx t (expr-TSet a-ty))]
           [ra (checkQ ctx a a-ty)])
       (match* (rt ra)
         [((bu #t u1) (bu #t u2))
          (bu #t (add-usage u1 u2))]
         [(_ _) (bu #f (zero-usage n))]))]

    ;; ---- PropNetwork runtime wrappers: check against type constructors ----
    [((expr-prop-network _) (expr-net-type)) (bu #t (zero-usage n))]
    [((expr-cell-id _) (expr-cell-id-type)) (bu #t (zero-usage n))]
    [((expr-prop-id _) (expr-prop-id-type)) (bu #t (zero-usage n))]

    ;; ---- UnionFind runtime wrapper ----
    [((expr-uf-store _) (expr-uf-type)) (bu #t (zero-usage n))]

    ;; ---- Tabling runtime wrapper ----
    [((expr-table-store-val _) (expr-table-store-type)) (bu #t (zero-usage n))]

    ;; ---- Relational runtime wrapper ----
    [((expr-solver-config _) (expr-solver-type)) (bu #t (zero-usage n))]

    ;; ---- Union type: checkQ(G, e, A | B) ----
    ;; Phase 5: speculative rollback with network fork/restore.
    ;; CIU T6 F1a.2 p0 (bug fix, p3 perf-refit): a term whose INFERRED type is
    ;; the WHOLE union (a dynamic ⋃ projection) can never re-derive it branch-
    ;; wise — both branches fail and every bare-union-typed def died as a
    ;; spurious "Multiplicity violation". The branch split stays EXACTLY as it
    ;; always was (left rollback-probed, right bare — zero new hot-path cost;
    ;; the p0 version rollback-wrapped the right branch and paid a meta-snapshot
    ;; + fork on every successful right-branch check, a measured +7% on typing-
    ;; dominated programs). The whole-union conversion runs only on the BOTH-
    ;; FAIL path; a failed bare right branch rarely solves metas (branch types
    ;; are concrete), and the attempt itself re-unifies — accepted posture,
    ;; pinned by the p0 tests.
    [(_ (expr-union l r))
     (let ([rl (with-speculative-rollback
                 (lambda () (checkQ ctx e l))
                 (lambda (r) (and (bu? r) (bu-ok? r)))
                 "union-checkQ-left")])
       (or rl
           (let ([rr (checkQ ctx e r)])
             (if (and (bu? rr) (bu-ok? rr))
                 rr
                 (match (inferQ ctx e)
                   [(tu t1 u)
                    #:when (and (not (expr-error? t1))
                                (unify-ok? (unify ctx (expr-union l r) t1)))
                    (bu #t u)]
                   [_ (bu #f (zero-usage n))])))))]

    ;; ---- Conversion fallback ----
    ;; Phase 3e: added cumulativity + within-family subtyping (consistent with check)
    [(_ _)
     (let ([r (inferQ ctx e)])
       (match r
         [(tu t1 u)
          (if (and (not (expr-error? t1))
                   (or (unify-ok? (unify ctx t t1))
                       (match* ((whnf t) (whnf t1))
                         [((expr-Type l1) (expr-Type l2))
                          (level<=? l2 l1)]
                         ;; CIU T6 F1 (B2): reach the Record<:Map subsumption from the QTT pass
                         ;; too (checkQ's fallback is a DUPLICATE of check's — mirror the arm).
                         [((? expr-Map? mt) (? expr-Record? rec))
                          (record-<:-map? ctx rec (expr-Map-k-type mt) (expr-Map-v-type mt))]
                         ;; CIU T6 F1a-col-3 (B2 completion): the Tuple→PVec and Tuple→List
                         ;; α arms were missing here — ground cases were rescued by the unify
                         ;; classifier above, but a meta element type ((PVec ?A)) reached from
                         ;; the QTT pass could not solve ?A. Mirror check's fallback exactly.
                         [((? expr-PVec? pt) (? expr-Record? rec))
                          (record-<:-pvec? ctx rec (expr-PVec-elem-type pt))]
                         [((expr-app lf la) (? expr-Record? rec))
                          #:when (equal? lf (list-type-fvar))
                          (record-<:-elem? ctx rec la)]
                         ;; CIU T6 F1b.4a (D22): the row-vs-schema/selection
                         ;; discharge twins + the schema-actual up-shift twins
                         ;; (shared predicates from typing-core — mirror-drift cap).
                         [((expr-fvar sname) (? expr-Record? rec))
                          #:when (lookup-schema-by-name sname)
                          ;; F1b.4e twins: per-field + residual (shared predicates)
                          (record-seals-schema? ctx rec (lookup-schema-by-name sname))]
                         [((expr-fvar selname) (? expr-Record? rec))
                          #:when (lookup-selection-by-name selname)
                          (record-seals-selection? ctx rec (lookup-selection-by-name selname))]
                         [((? expr-Map? mt) (expr-fvar sname))
                          #:when (lookup-schema-by-name sname)
                          (record-<:-map? ctx (schema->row (lookup-schema-by-name sname))
                                          (expr-Map-k-type mt) (expr-Map-v-type mt))]
                         [((? expr-Record? t-rec) (expr-fvar sname))
                          #:when (and (lookup-schema-by-name sname)
                                      (record-width-applicable?
                                       t-rec (schema->row (lookup-schema-by-name sname))))
                          (record-width-discharge?
                           ctx t-rec (schema->row (lookup-schema-by-name sname)))]
                         ;; CIU T6 F1b.3 (D21): the width-discharge twin (shared
                         ;; predicates from typing-core — the mirror-drift cap).
                         ;; Returns a plain BOOLEAN into this or-chain (the bu
                         ;; wrap is outside), unlike the union arm's bu threading.
                         [((? expr-Record? t-rec) (? expr-Record? t1-rec))
                          #:when (record-width-applicable? t-rec t1-rec)
                          (record-width-discharge? ctx t-rec t1-rec)]
                         [(t-w t1-w) (subtype? t1-w t-w)])))
              (bu #t u)
              (bu #f (zero-usage n)))]
         [_ (bu #f (zero-usage n))]))]))

;; ========================================
;; Top-level QTT check: verify all usages in a closed term
;; ========================================
(define (checkQ-top ctx e t)
  (let ([r (checkQ ctx e t)])
    (match r
      [(bu #t u) (check-all-usages ctx u)]
      [_ #f])))

;; ========================================
;; QTT P4 (2026-07-30): explain a multiplicity failure
;; ========================================
;; Consumed by typing-errors' `checkQ-top/err`, which until now filled
;; `multiplicity-error`'s three rendered fields with the string LITERALS
;; "declared" and "actual" plus the entire pretty-printed body as the
;; "Variable". The fields and their rendering already existed — only real values
;; were missing.
;;
;; DEFINED HERE, NOT IN typing-errors.rkt, on purpose: explaining the failure
;; means reproducing the very tests that produced it — the lambda arm's
;; `(compatible effective-m (uhead u))`, and each eliminator's per-branch
;; expected types (`(expr-app mot (expr-true))` for boolrec, a `shift`ed expected
;; type for reduce). Re-deriving those in the error module is the twin drift
;; `pipeline.md` § "infer / inferQ Are Twins" documents. Same rationale as
;; typing-core exporting `select-project` / `seal-missing-required` for the
;; typing-errors hints: one derivation, two consumers.
;;
;; CONTRACT: runs ONLY on an already-failing `checkQ-top`, is pure, and returns
;; #f whenever it cannot PROVE a specific cause — the caller then keeps the
;; generic message. It must never assert a cause it did not establish.
;;
;; Returns one of:
;;   (list 'binder type declared actual) — a binder's usage ≠ its declaration
;;   (list 'branch type m-a m-b)         — branches disagree at a LINEAR position
;;   #f

;; First position where two branch usages disagree and the declared multiplicity
;; is linear. Mirrors `branches-agree-on-linear?` (which answers yes/no); this
;; reports WHICH. Returns (list 'branch type m-a m-b) or #f.
(define (first-linear-disagreement ctx u1 u2)
  (let loop ([c ctx] [a u1] [b u2])
    (cond
      [(or (null? c) (null? a) (null? b)) #f]
      [(and (eq? (cdar c) 'm1) (not (eq? (car a) (car b))))
       (list 'branch (caar c) (car a) (car b))]
      [else (loop (cdr c) (cdr a) (cdr b))])))

;; Branch-level explanation: recompute each branch's usage using the SAME
;; expected type its typing arm uses, then diff. Covers the eliminators that
;; carry the linear-per-path guard; anything else yields #f (generic message).
(define (explain-branch-disagreement ctx e t)
  (define (two a ta b tb)
    (match* ((checkQ ctx a ta) (checkQ ctx b tb))
      [((bu #t ua) (bu #t ub)) (first-linear-disagreement ctx ua ub)]
      [(_ _) #f]))
  (match e
    [(expr-boolrec mot tc fc _)
     (two tc (expr-app mot (expr-true)) fc (expr-app mot (expr-false)))]
    [(expr-p8-if-nar ty nar norm _)  (two nar ty norm ty)]
    [(expr-p16-if-nar ty nar norm _) (two nar ty norm ty)]
    [(expr-p32-if-nar ty nar norm _) (two nar ty norm ty)]
    [(expr-p64-if-nar ty nar norm _) (two nar ty norm ty)]
    [(expr-reduce scrutinee arms _)
     ;; Arms bind a per-arm field count, so each usage is trimmed back to the
     ;; ambient depth before comparison — the same discipline the checkQ arm
     ;; applies, and the reason a raw comparison would be meaningless.
     ;;
     ;; ⚠ THIS LOOP MIRRORS THE checkQ expr-reduce ARM AND MUST MOVE WITH IT.
     ;; They were ALREADY out of sync before QTT P6: this one bailed on
     ;; `(and tc …)`, abandoning the Church-fold path entirely, while the checker
     ;; carried a permissive fallback there — so the explainer could not describe
     ;; the very case the checker was deciding. Both now use the same
     ;; strict-ctx / mw-fallback / skipped? shape. A test pins the message so a
     ;; future divergence fails loudly instead of silently reverting to the
     ;; generic "Multiplicity violation".
     (let ([scrut-type (infer ctx scrutinee)])
       (and (not (expr-error? scrut-type))
            (let-values ([(tc targs) (reduce-scrutinee-decompose scrut-type)])
              (let loop ([as arms] [acc #f] [skipped? #f])
                (cond
                  [(null? as)
                   ;; QTT P6: an arm we could not analyse, plus a linear resource
                   ;; some other arm consumed ⇒ linear-per-path is undecidable.
                   (and skipped? acc
                        (let ([ty (first-linear-at-stake ctx acc)])
                          (and ty (list 'unanalysable ty))))]
                  [else
                   (let* ([arm (car as)]
                          [bc (expr-reduce-arm-binding-count arm)]
                          [strict-ctx (and tc (reduce-arm-ctx ctx arm tc targs))]
                          [ext (or strict-ctx
                                   (for/fold ([c ctx]) ([_ (in-range bc)])
                                     (ctx-extend c (expr-hole) 'mw)))]
                          [u (match (checkQ ext (expr-reduce-arm-body arm)
                                            (shift bc 0 t))
                               [(bu #t ua) (strip-binders ext ua bc)]
                               [_ #f])])
                     (cond
                       ;; An arm that failed but WAS analysable is not a skip —
                       ;; the checker hard-fails on it, and the real cause is
                       ;; nested inside, so recurse rather than mislabel it as
                       ;; unanalysable. (Without this, the Bool control in the
                       ;; P6 battery reported "cannot be analysed" about a
                       ;; perfectly analysable `match`.)
                       [(and (not u) strict-ctx)
                        (or (explain-branch-disagreement
                             ext (expr-reduce-arm-body arm) (shift bc 0 t))
                            (loop (cdr as) acc skipped?))]
                       [(not u) (loop (cdr as) acc #t)]
                       [(not acc) (loop (cdr as) u skipped?)]
                       [(first-linear-disagreement ctx acc u) => values]
                       [else (loop (cdr as) (join-usage acc u) skipped?)]))]))))) ]
    [_ #f]))

(define (explain-qtt-failure ctx e t)
  (match* (e (whnf t))
    [((expr-lam m dom body) (expr-Pi m2 t-dom cod))
     (let* ([eff (cond [(mult-meta? m) (if (mult-meta? m2) 'mw m2)]
                       [(mult-meta? m2) m]
                       [else m])]
            [d (if (expr-hole? dom) t-dom dom)]
            [ext (ctx-extend ctx d eff)])
       (match (checkQ ext body cod)
         ;; The body checks cleanly, so the failure is THIS binder's own usage —
         ;; exactly the lambda arm's test, re-run to read off the actual value.
         [(bu #t u)
          (and (not (compatible eff (uhead u)))
               (list 'binder d eff (uhead u)))]
         ;; The body itself fails: the cause is deeper.
         [_ (explain-qtt-failure ext body cod)]))]
    [(_ t-whnf) (explain-branch-disagreement ctx e t-whnf)]))
