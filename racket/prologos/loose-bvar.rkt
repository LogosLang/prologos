#lang racket/base

;;;
;;; loose-bvar.rkt — GitHub #58 Layer 2: the substitution short-circuit.
;;;
;;; `loose-bvar-range e` = 1 + (max index of a de Bruijn variable occurring FREE
;;; in e), or 0 when e is closed. With it:
;;;
;;;   (shift delta cutoff e) is the IDENTITY  when  (loose-bvar-range e) <= cutoff
;;;   (subst k s e)          is the IDENTITY  when  (loose-bvar-range e) <= k
;;;
;;; because in both cases no variable e contains is one the operation could touch.
;;;
;;; WHY A NUMERIC RANGE RATHER THAN A BOOLEAN PREDICATE. This is the load-bearing
;;; design point, and it is also why `contains-open-container?` (reduction.rkt:559)
;;; cannot be reused here. The question "does e contain a bvar with index >=
;;; cutoff?" DEPENDS ON CUTOFF, so its answer cannot be memoized per term. The
;;; numeric max is the cutoff-independent form, so it memoizes — and memoization
;;; is the whole fix, not an optimization on top of it.
;;;
;;; WHY THIS RESTORES LINEAR SCALING. The memo is filled BOTTOM-UP: computing a
;;; node's range consults its children through the memo, so each node is computed
;;; exactly once ever. A tail-recursive accumulator conses one node onto a term
;;; whose range is already memoized, so each step's range costs O(1) rather than
;;; O(size). That is what turns the O(N^2) walk into O(N).
;;;
;;; SOUNDNESS, AND THE DIRECTION THAT MATTERS. Over-estimating the range is SAFE
;;; (we simply decline to short-circuit and walk as before). Under-estimating is
;;; a SILENT WRONG ANSWER — the guard would skip a subtree that genuinely needed
;;; shifting, which is exactly the failure class of the 2026-07-24 substitution
;;; containment defect. Every design choice below is therefore biased toward
;;; over-estimation, and the structure is chosen so that a node kind we have
;;; never seen CANNOT be under-estimated:
;;;
;;;   - Explicit arms exist ONLY where the answer differs from "max over all
;;;     sub-expressions" — i.e. the bvar base case and the BINDER forms, which
;;;     must discharge indices bound by the binder itself.
;;;   - Everything else falls to a GENERIC reflective walk over the struct's
;;;     fields (all expr structs are #:transparent). A newly added AST node is
;;;     therefore handled correctly BY CONSTRUCTION, with no checklist entry.
;;;     This is the `.claude/rules/pipeline.md` § "Exhaustive Walkers: prefer the
;;;     STRUCTURAL answer to the checklist" discipline applied at design time
;;;     rather than retrofitted.
;;;
;;; The binder inventory (lam / Pi / Sigma / reduce-arm) is `shift`'s own, which
;;; substitution.rkt's `shift` establishes as authoritative. A walker that routes
;;; depth MUST cover exactly these; a depth-blind generic walk over a binder form
;;; CAPTURES.
;;;
;;; ON AGREEING WITH `shift` RATHER THAN WITH THE IDEAL SEMANTICS. The guard's
;;; correctness obligation is "never claim closed when `shift` would have changed
;;; something" — it is defined relative to SHIFT'S ARMS, not to an idealized
;;; notion of free variables. The generic walk descends everywhere shift descends
;;; and then some (into lists, vectors, boxes and hash values), so its estimate is
;;; a sound upper bound on shift's reach by construction. In particular the
;;; runtime containers (expr-champ / expr-hset / expr-rrb + transients) are closed
;;; leaves for `shift`; we do NOT hard-code that assumption here — the generic
;;; walk simply looks, and finds nothing to report when ruling (D) holds. If (D)
;;; is ever revisited, this file needs no change.
;;;

(require racket/match
         "syntax.rkt")

(provide loose-bvar-range
         loose-bvar-range-cached
         loose-bvar-range/reference
         clear-loose-bvar-cache!)

;; ============================================================
;; Memo
;; ============================================================

;; Weak + eq?-keyed. Weak so dead terms are collected; eq?-keyed so a lookup
;; costs pointer identity rather than a structural hash.
;;
;; eq? keying is SOUND, not merely fast: no expr struct is #:mutable
;; (`grep -c '#:mutable' syntax.rkt` = 0), so a term's loose-bvar range is a pure
;; function of its identity. This is the same argument `nbe-scan-cache`
;; (reduction.rkt:3727) already ships.
;;
;; ⚠ COUPLING, recorded deliberately (grounding-audit capture-gap G1): `expr-meta`
;; is a CLOSED LEAF in both walkers (substitution.rkt:49, :542), so a term
;; containing an unsolved meta reports 0 here. That is sound TODAY precisely
;; because shift/subst are the identity on metas. But a meta's SOLUTION lives
;; off-node in metavar-store and is filled in mid-command while the expr node's
;; identity stays fixed — so if the still-open META half of the containment
;; defect (DEFERRED.md) ever teaches these walkers to follow meta solutions, this
;; memo becomes STALE-BY-CONSTRUCTION and must be invalidated on solve. The two
;; work items are hard-coupled; do not land that one without revisiting this.
(define range-memo (make-weak-hasheq))

(define (clear-loose-bvar-cache!)
  (set! range-memo (make-weak-hasheq)))

;; COMPUTE + memoize. Costs a full walk on a first encounter, so call it only
;; where the answer will be REUSED — see substitution.rkt's `shift-arg`.
;;
;; ⚠ It stores ONLY the term it was asked about. The descent below uses
;; `range-of`, which CONSULTS the memo but never writes to it. Memoizing every
;; subnode instead was measured at **441 ns/node vs 131 ns/node** — a 3.4x tax
;; paid on every substitution argument in the compiler, for entries almost none
;; of which are ever read again. Storing only the queried term keeps the property
;; that matters: in an accumulator, s_{i+1}'s child IS s_i, which was itself a
;; queried term, so the descent hits the memo immediately and stays O(1).
(define (loose-bvar-range e)
  (cond
    [(hash-ref range-memo e #f) => values]
    [else
     (define r (compute-range e))
     (hash-set! range-memo e r)
     r]))

;; Consult-then-compute, WITHOUT storing. The recursive workhorse.
(define (range-of e)
  (or (hash-ref range-memo e #f) (compute-range e)))

;; CONSULT ONLY — returns the memoized range, or #f if we have never computed it.
;; Never walks, so it is safe to call on a per-node hot path.
;;
;; This split is the resolution of the phase's central measurement problem. A
;; whole-tree property costs a whole-tree walk, so a guard that COMPUTES can
;; never pay for itself on a term walked once — it just walks twice, which cost
;; ~25% of full-suite wall time when `shift` computed at every node. But the
;; guard must still run inside `shift`'s recursion, because the win that restores
;; linear scaling is pruning a closed accumulator that appears EMBEDDED in a
;; larger term, not merely skipping it at the top.
;;
;; Consulting resolves both: one-shot walks pay a single failed pointer lookup
;; per node and nothing else, while the terms that actually repeat — the
;; substitution arguments, seeded by `shift-arg` — are in the memo and prune
;; instantly wherever they appear.
(define (loose-bvar-range-cached e)
  (hash-ref range-memo e #f))

;; ============================================================
;; The computation
;; ============================================================

;; Discharge `n` binders' worth of indices: a variable free at index j inside n
;; binders is free at index j - n outside. Floored at 0 (fully bound).
(define (under n r) (if (> r n) (- r n) 0))

(define (compute-range e)
  (match e
    ;; --- base case ---
    [(expr-bvar k) (add1 k)]

    ;; --- HOT SHAPES ---
    ;; These carry no depth semantics — the generic walk below would compute the
    ;; identical answer. They exist purely for speed, and the speed is
    ;; load-bearing: the generic walk costs ~131 ns/node against `shift`'s own
    ;; ~17 ns/node, because it goes through `struct-info` + an accessor loop
    ;; where `shift` uses a compiled match (`.claude/rules/pipeline.md` records
    ;; the same ~6.9x from the SUB hot scan). Since `shift-arg` runs this over
    ;; every substitution argument, a reflective-only walk taxed the whole
    ;; compiler ~24% of suite wall time.
    ;;
    ;; Per pipeline.md § Exhaustive Walkers, arms on a hot path are legitimate
    ;; ONLY alongside (a) the generic fallback below, so coverage stays total by
    ;; construction, and (b) `loose-bvar-range/reference` as a differential
    ;; oracle, test-pinned over a battery. Both are in place. Adding or omitting
    ;; an arm here can therefore make this SLOWER but never WRONG.
    [(expr-app f a) (max (range-of f) (range-of a))]
    [(expr-fvar _) 0]
    [(expr-nat-val _) 0]
    [(expr-nil) 0]
    [(expr-Nat) 0]
    [(expr-int _) 0]
    [(expr-string _) 0]
    [(expr-keyword _) 0]
    [(expr-true) 0]
    [(expr-false) 0]
    [(expr-zero) 0]
    [(expr-meta _ _) 0]          ; closed leaf in both walkers — see the memo note
    [(expr-suc a) (range-of a)]
    [(expr-fst a) (range-of a)]
    [(expr-snd a) (range-of a)]
    [(expr-pair a b) (max (range-of a) (range-of b))]
    [(expr-ann a b) (max (range-of a) (range-of b))]

    ;; --- binder forms: shift's own authoritative inventory ---
    ;; The type/domain position is NOT under the binder; the body/codomain is.
    [(expr-lam _ t body)
     (max (range-of t) (under 1 (range-of body)))]
    [(expr-Pi _ dom cod)
     (max (range-of dom) (under 1 (range-of cod)))]
    [(expr-Sigma t1 t2)
     (max (range-of t1) (under 1 (range-of t2)))]

    ;; Reduce: the scrutinee is non-binding; each arm binds `binding-count`.
    ;; This arm matters disproportionately — substitution.rkt:988 shifts the
    ;; substitution argument once PER ARM, so it carries most of the walks in a
    ;; multi-clause `defn`.
    [(expr-reduce scrut arms _)
     (for/fold ([acc (range-of scrut)]) ([arm (in-list arms)])
       (max acc (under (expr-reduce-arm-binding-count arm)
                       (range-of (expr-reduce-arm-body arm)))))]

    ;; --- everything else: generic, total, cannot silently miss a node kind ---
    ;; NOTE: this MUST go to `fields-range` (which descends into e's FIELDS), not
    ;; to `generic-range` (which dispatches on a VALUE). `generic-range` sends any
    ;; expr? straight back to `loose-bvar-range`, and at this point e's memo entry
    ;; does not exist yet — so routing e itself through it is an infinite loop.
    ;; Cost me one hung test run; the two functions are deliberately separate.
    [_ (fields-range e)]))

;; Walk the FIELDS of a struct. Never re-dispatches on the struct itself, so
;; recursion strictly descends.
;;
;; ⚠ PERFORMANCE, and it is load-bearing rather than incidental. The obvious
;; spelling here is `struct->vector`, which ALLOCATES a fresh vector per node.
;; That is not a small constant: this walker runs over every node of every term
;; shifted, and the first cut of this file — which used struct->vector — cost
;; **374 ns/node**, making a one-shot range computation 150 us on a 401-node term
;; versus 7.5 us for the shift it was supposed to save. It regressed the full
;; suite by ~25% (198.6 s -> 240.9 s) even though every micro looked good.
;; `.claude/rules/pipeline.md` § Exhaustive Walkers already records the same
;; measurement from the SUB hot scan ("struct->vector allocates per node —
;; measured 6.9x").
;;
;; So we fetch the fields through the struct type's ACCESSOR procedure instead,
;; with the per-type lookup memoized. Zero allocation per node, and — this is the
;; point — we keep the fully-generic shape, so a newly added AST node is still
;; handled by construction. Speed did NOT cost us the structural guarantee.
;;
;; All expr structs are #:transparent with no supertypes, so a single
;; init+auto field count and one accessor is the whole story.
(define struct-type-cache (make-hasheq))

(define (struct-field-info st)
  (hash-ref! struct-type-cache st
             (lambda ()
               (let-values ([(_name init-cnt auto-cnt acc _mut _imm _sup _sk)
                             (struct-type-info st)])
                 (cons (+ init-cnt auto-cnt) acc)))))

(define (fields-range v)
  (cond
    [(struct? v)
     (define-values (st _skipped?) (struct-info v))
     (cond
       [st
        (define info (struct-field-info st))
        (define n (car info))
        (define acc (cdr info))
        (let loop ([i 0] [m 0])
          (if (= i n) m (loop (add1 i) (max m (generic-range (acc v i))))))]
       ;; Inspector does not expose this type — same reach as shift, which does
       ;; not descend into opaque payloads either.
       [else 0])]
    [else 0]))

;; Dispatch on an arbitrary VALUE sitting in some field. Descends through the
;; collection shapes an AST field might use. Anything unrecognised contributes 0,
;; which is correct because `shift` does not descend into those payloads either
;; (see the header note on agreeing with shift rather than the ideal semantics).
;;
;; Deliberately MORE total than shift: shift never looks inside vectors, boxes or
;; hashes, so descending into them can only over-estimate, never under-estimate.
(define (generic-range v)
  (cond
    [(expr? v) (range-of v)]              ; consult-then-compute, never stores
    [(pair? v) (max (generic-range (car v)) (generic-range (cdr v)))]
    [(null? v) 0]
    [(vector? v)
     (for/fold ([acc 0]) ([x (in-vector v)]) (max acc (generic-range x)))]
    [(box? v) (generic-range (unbox v))]
    [(hash? v)
     (for/fold ([acc 0]) ([(k x) (in-hash v)])
       (max acc (generic-range k) (generic-range x)))]
    [(struct? v) (fields-range v)]     ; e.g. expr-reduce-arm, which is not an expr?
    [else 0]))

;; ============================================================
;; Differential oracle (test-only)
;; ============================================================

;; A deliberately naive, UNMEMOIZED, fully-reflective reference implementation.
;; It shares no code with the memoized path above except `under`, so a contract
;; test asserting `loose-bvar-range` == `loose-bvar-range/reference` over a
;; battery is a genuine differential — it catches both a wrong explicit arm and a
;; stale memo entry.
;;
;; Per `.claude/rules/pipeline.md` § Exhaustive Walkers: "retain the reflective
;; walk, export it, and write a contract test asserting armed == reflective."
(define (loose-bvar-range/reference e)
  (define (walk v)
    (cond
      [(expr-bvar? v) (add1 (expr-bvar-index v))]
      [(expr-lam? v) (max (walk (expr-lam-type v)) (under 1 (walk (expr-lam-body v))))]
      [(expr-Pi? v) (max (walk (expr-Pi-domain v)) (under 1 (walk (expr-Pi-codomain v))))]
      [(expr-Sigma? v) (max (walk (expr-Sigma-fst-type v)) (under 1 (walk (expr-Sigma-snd-type v))))]
      [(expr-reduce? v)
       (for/fold ([acc (walk (expr-reduce-scrutinee v))])
                 ([arm (in-list (expr-reduce-arms v))])
         (max acc (under (expr-reduce-arm-binding-count arm)
                         (walk (expr-reduce-arm-body arm)))))]
      [(pair? v) (max (walk (car v)) (walk (cdr v)))]
      [(null? v) 0]
      [(vector? v) (for/fold ([a 0]) ([x (in-vector v)]) (max a (walk x)))]
      [(box? v) (walk (unbox v))]
      [(hash? v) (for/fold ([a 0]) ([(k x) (in-hash v)]) (max a (walk k) (walk x)))]
      [(struct? v)
       (define fs (struct->vector v))
       (for/fold ([a 0]) ([i (in-range 1 (vector-length fs))]) (max a (walk (vector-ref fs i))))]
      [else 0]))
  (walk e))
