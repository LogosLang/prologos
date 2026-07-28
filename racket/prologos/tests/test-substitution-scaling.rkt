#lang racket/base

;;;
;;; Tests for GitHub #58 — O(N^2) substitution blow-up.
;;; Design: docs/tracking/2026-07-27_SUBSTITUTION_QUADRATIC_BLOWUP_DESIGN.md
;;;
;;; These are FAILING-TEST-FIRST gates. Every `eq?` assertion below returns #f at
;;; `09d3566c` (pre-fix) and #t after the corresponding phase lands. They test the
;;; MECHANISM (does the walker avoid rebuilding a tree it cannot change?) rather
;;; than a timing proxy, so they are exact, deterministic, and ambient-immune.
;;;
;;; Why eq?-identity rather than a node counter: wiring the existing `perf-inc-*`
;;; macro into shift/subst measured a 2.6x pessimization of the walker (parameter
;;; read = 43ns/op vs the walker's own 26ns/node), and the cheap alternatives are
;;; module-global rather than thread-local, so they would silently interleave
;;; under the parallel batch runner. See the design doc S4 "Rejected".
;;;
;;; NOTE: the `equal?` assertions here are SEMANTICS INVARIANTS — they pass both
;;; before and after, and exist so that a short-circuit that is too aggressive
;;; (skipping a subtree that DID need shifting) fails loudly. That direction is
;;; the silent-wrong-answer class from the SUB arc; guard it explicitly.
;;;

(require rackunit
         "../prelude.rkt"
         "../syntax.rkt"
         "../substitution.rkt"
         "../loose-bvar.rkt")

;; ========================================
;; Term builders
;; ========================================

;; A CLOSED cons-spine of M elements — no loose de Bruijn indices anywhere.
;; This is the shape a tail-recursive accumulator presents to `subst`.
;; It MUST be an app-spine `List`: the runtime containers (expr-champ / expr-hset /
;; expr-rrb + transients) are closed leaves in both walkers, so a PVec/Map
;; accumulator would measure nothing and read as "the bug is gone".
(define (closed-chain M)
  (for/fold ([acc (expr-nil)]) ([i (in-range M)])
    (expr-app (expr-app (expr-fvar 'cons) (expr-nat-val (modulo i 7))) acc)))

;; The same spine but with a loose bvar at the deep end — shift MUST descend.
(define (open-chain M [idx 0])
  (for/fold ([acc (expr-bvar idx)]) ([i (in-range M)])
    (expr-app (expr-app (expr-fvar 'cons) (expr-nat-val (modulo i 7))) acc)))

;; ========================================
;; G2 — delta = 0 is the identity  (P1 gate)
;; ========================================

(test-case "G2: (shift 0 0 e) returns its input eq?-identical — closed term"
  (define e (closed-chain 40))
  (check-eq? (shift 0 0 e) e))

(test-case "G2: (shift 0 0 e) returns its input eq?-identical — OPEN term"
  ;; The delta=0 identity does not depend on closedness: shift's only effect is
  ;; (expr-bvar (+ k delta)), and (+ k 0) = k. The Redex model already asserts
  ;; this property (redex/properties.rkt:144-148 "shift-identity").
  (define e (open-chain 40))
  (check-eq? (shift 0 0 e) e))

(test-case "G2: (shift 0 c e) is the identity at every cutoff"
  (define e (open-chain 12 3))
  (for ([c (in-range 0 6)])
    (check-eq? (shift 0 c e) e)))

(test-case "G2: delta=0 through a binder — the reduce-arm nullary-clause path"
  ;; substitution.rkt:988 passes the arm's binding-count as delta; that is 0 for
  ;; EVERY nullary constructor clause (| nil -> ...), so this path is hot.
  (define e (expr-lam 'mw (expr-Nat) (open-chain 20 1)))
  (check-eq? (shift 0 0 e) e))

;; ========================================
;; G1 — a term with a KNOWN range short-circuits  (P3 gate)
;;
;; The guard inside `shift` is CONSULT-ONLY: it prunes a subtree whose range is
;; already memoized and never computes one, because computing a whole-tree
;; property on a term walked once costs a second walk and buys nothing (measured:
;; ~25% of full-suite wall time when `shift` computed at every node).
;;
;; Production seeds the memo at exactly the sites where the answer gets reused —
;; `shift-arg`, substitution.rkt's wrapper on the four places `subst` re-shifts
;; its argument. These tests model that by calling `loose-bvar-range` first,
;; which is precisely what `shift-arg` does. G4 below then checks the same
;; property END-TO-END through `subst`, with no manual seeding — that is the
;; user-visible contract, and the one the issue is actually about.
;; ========================================

(test-case "G1: a CLOSED term with a known range short-circuits, eq?-identical"
  (define e (closed-chain 40))
  (void (loose-bvar-range e))            ; what shift-arg does in production
  (check-eq? (shift 1 0 e) e))

(test-case "G1: known-range CLOSED term short-circuits at every delta/cutoff"
  (define e (closed-chain 25))
  (void (loose-bvar-range e))
  (for* ([d (in-range 1 4)] [c (in-range 0 4)])
    (check-eq? (shift d c e) e)))

(test-case "G1: cutoff above the term's loose range also short-circuits"
  ;; loose range of (open-chain M 2) is 3, so any cutoff >= 3 is the identity.
  (define e (open-chain 20 2))
  (check-equal? (loose-bvar-range e) 3)
  (check-eq? (shift 1 3 e) e)
  (check-eq? (shift 1 9 e) e))

(test-case "G1: an UNSEEDED term is still correct — the guard is an optimization"
  ;; Consult-only means a cold term is simply walked. That must not change the
  ;; ANSWER, only the sharing. This pins the guard as semantically invisible.
  (clear-loose-bvar-cache!)
  (define e (closed-chain 12))
  (check-equal? (shift 1 0 e) e)
  (check-equal? (shift 3 2 e) e))

;; ========================================
;; G4 — subst does not rebuild a closed argument  (P3 gate)
;; ========================================

(test-case "G4: subst keeps a closed argument eq? across a lam binder"
  (define arg (closed-chain 40))
  (define body (expr-lam 'mw (expr-Nat) (expr-bvar 1)))
  (define r (subst 0 arg body))
  (check-eq? (expr-lam-body r) arg))

(test-case "G4: subst keeps a closed argument eq? across Pi and Sigma"
  (define arg (closed-chain 30))
  (check-eq? (expr-Pi-codomain (subst 0 arg (expr-Pi 'mw (expr-Nat) (expr-bvar 1)))) arg)
  (check-eq? (expr-Sigma-snd-type (subst 0 arg (expr-Sigma (expr-Nat) (expr-bvar 1)))) arg))

(test-case "G4: subst keeps a closed argument eq? across a reduce ARM"
  ;; substitution.rkt:988 — the 4th shift site, INSIDE a map over arms, so an
  ;; A-arm match costs A walks. The issue's enumeration misses this one.
  (define arg (closed-chain 30))
  (define e (expr-reduce (expr-bvar 0)
                         (list (expr-reduce-arm 'nil 0 (expr-bvar 0))
                               (expr-reduce-arm 'cons 2 (expr-bvar 2)))
                         #f))
  (define r (subst 0 arg e))
  (define arms (expr-reduce-arms r))
  ;; nil arm: binding-count 0 -> the substituted occurrence is the arg itself
  (check-eq? (expr-reduce-arm-body (car arms)) arg)
  ;; cons arm: binding-count 2 -> shifted by 2, but arg is CLOSED so still eq?
  (check-eq? (expr-reduce-arm-body (cadr arms)) arg))

;; ========================================
;; G3 + soundness — a short-circuit that is TOO aggressive must fail loudly
;; ========================================

(test-case "G3: shifting a closed term is semantically the identity"
  (define e (closed-chain 40))
  (check-equal? (shift 5 0 e) e))

(test-case "SOUND: an OPEN term still shifts correctly (no over-eager skip)"
  (check-equal? (shift 1 0 (open-chain 3 0)) (open-chain 3 1))
  (check-equal? (shift 2 0 (open-chain 3 1)) (open-chain 3 3))
  (check-equal? (shift 1 0 (open-chain 5 4)) (open-chain 5 5)))

(test-case "SOUND: bvar exactly AT the cutoff shifts; below it does not"
  (check-equal? (shift 1 2 (expr-bvar 2)) (expr-bvar 3))
  (check-equal? (shift 1 2 (expr-bvar 1)) (expr-bvar 1)))

(test-case "SOUND: a loose bvar under a binder is still reached"
  ;; bvar 1 inside a lam refers OUTSIDE the lam — loose range 2, so a cutoff of
  ;; 0 or 1 must descend. An off-by-one in the range computation shows up here.
  (check-equal? (shift 1 0 (expr-lam 'mw (expr-Nat) (expr-bvar 1)))
                (expr-lam 'mw (expr-Nat) (expr-bvar 2)))
  (check-equal? (shift 1 1 (expr-lam 'mw (expr-Nat) (expr-bvar 1)))
                (expr-lam 'mw (expr-Nat) (expr-bvar 1))))

(test-case "SOUND: reduce arms shift by cutoff + binding-count"
  (define e (expr-reduce (expr-bvar 0)
                         (list (expr-reduce-arm 'cons 2 (expr-bvar 2)))
                         #f))
  ;; bvar 2 under 2 binders is loose (refers outside) -> shifts to bvar 3
  (check-equal? (shift 1 0 e)
                (expr-reduce (expr-bvar 1)
                             (list (expr-reduce-arm 'cons 2 (expr-bvar 3)))
                             #f)))

(test-case "SOUND: subst still substitutes into an OPEN argument correctly"
  (define arg (expr-bvar 0))
  (check-equal? (subst 0 arg (expr-lam 'mw (expr-Nat) (expr-bvar 1)))
                (expr-lam 'mw (expr-Nat) (expr-bvar 1))))

;; ========================================
;; Differential battery — the guarded walker must agree with the semantics at
;; every armed field position and at every binder depth.
;;
;; This is the `pipeline.md` Exhaustive-Walkers discipline applied here: the
;; short-circuit is an optimization, so it must be provably invisible. Plant a
;; loose bvar in each field of each multi-field node and confirm the result is
;; unchanged from the un-short-circuited semantics (spelled out by hand).
;; ========================================

(define (planted idx)
  ;; one representative of each structural family, each carrying a loose bvar
  (list (expr-app (expr-bvar idx) (expr-nat-val 1))
        (expr-app (expr-nat-val 1) (expr-bvar idx))
        (expr-pair (expr-bvar idx) (expr-nil))
        (expr-fst (expr-bvar idx))
        (expr-snd (expr-bvar idx))
        (expr-suc (expr-bvar idx))
        (expr-lam 'mw (expr-bvar idx) (expr-nat-val 1))
        (expr-lam 'mw (expr-Nat) (expr-bvar (add1 idx)))
        (expr-Pi 'mw (expr-bvar idx) (expr-nat-val 1))
        (expr-Pi 'mw (expr-Nat) (expr-bvar (add1 idx)))
        (expr-Sigma (expr-bvar idx) (expr-nat-val 1))
        (expr-Sigma (expr-Nat) (expr-bvar (add1 idx)))
        (expr-ann (expr-bvar idx) (expr-Nat))
        (expr-union (expr-bvar idx) (expr-Nat))))

(test-case "DIFFERENTIAL: a planted loose bvar is reached in every armed position"
  ;; If the short-circuit is correct, shifting by 1 at cutoff 0 changes EVERY one
  ;; of these (they all contain a loose bvar), i.e. none may come back eq?.
  (for ([e (in-list (planted 0))])
    (check-false (eq? (shift 1 0 e) e)
                 (format "short-circuit wrongly skipped a term with a loose bvar: ~a" e))))

(test-case "DIFFERENTIAL: the same shapes with NO loose bvar all short-circuit"
  ;; Same shapes, but every bvar is bound by the node's own binder, so the terms
  ;; are closed and must come back eq?-identical.
  (define closed-shapes
    (list (expr-app (expr-nat-val 1) (expr-nat-val 2))
          (expr-pair (expr-nil) (expr-nil))
          (expr-fst (expr-nat-val 1))
          (expr-suc (expr-nat-val 1))
          (expr-lam 'mw (expr-Nat) (expr-bvar 0))       ; bound by its own lam
          (expr-Pi 'mw (expr-Nat) (expr-bvar 0))        ; bound by its own Pi
          (expr-Sigma (expr-Nat) (expr-bvar 0))         ; bound by its own Sigma
          (expr-ann (expr-nat-val 1) (expr-Nat))
          (expr-union (expr-Nat) (expr-Bool))))
  (for ([e (in-list closed-shapes)])
    (void (loose-bvar-range e))          ; seed, as `shift-arg` does in production
    (check-eq? (shift 1 0 e) e
               (format "closed term was rebuilt instead of short-circuited: ~a" e))
    ;; and the range must actually be 0 — otherwise the eq? above passed for the
    ;; wrong reason (e.g. a bogus range that happened to be <= the cutoff).
    (check-equal? (loose-bvar-range e) 0
                  (format "expected a closed term to have range 0: ~a" e))))

(test-case "DIFFERENTIAL: nested binder depths route the cutoff correctly"
  ;; lam(lam(bvar N)) — the inner bvar is loose iff N >= 2.
  (for ([n (in-range 0 5)])
    (define e (expr-lam 'mw (expr-Nat) (expr-lam 'mw (expr-Nat) (expr-bvar n))))
    (define expected
      (expr-lam 'mw (expr-Nat) (expr-lam 'mw (expr-Nat)
                                         (expr-bvar (if (>= n 2) (add1 n) n)))))
    (check-equal? (shift 1 0 e) expected
                  (format "depth routing wrong for bvar ~a" n))))

;; ========================================
;; ORACLE — the memoized/armed range must equal the naive reflective reference.
;;
;; `.claude/rules/pipeline.md` § Exhaustive Walkers: "retain the reflective walk,
;; export it, and write a contract test asserting armed == reflective over a
;; battery that plants the target condition in EVERY armed field position (plus
;; bound-vs-free binder cases and one cold-fallback node)."
;;
;; loose-bvar-range/reference shares no code with the memoized path except the
;; `under` helper, so a divergence here catches BOTH a wrong explicit arm and a
;; stale memo entry — in the test, not in production.
;; ========================================

(define (oracle-battery)
  (append
   ;; every armed field position, loose bvar planted in each
   (planted 0) (planted 1) (planted 3)
   ;; bound-vs-free at each binder
   (list (expr-lam 'mw (expr-Nat) (expr-bvar 0))        ; bound
         (expr-lam 'mw (expr-Nat) (expr-bvar 1))        ; free
         (expr-Pi 'mw (expr-Nat) (expr-bvar 0))
         (expr-Pi 'mw (expr-Nat) (expr-bvar 1))
         (expr-Sigma (expr-Nat) (expr-bvar 0))
         (expr-Sigma (expr-Nat) (expr-bvar 1))
         ;; nested binders — the depth-routing cases
         (expr-lam 'mw (expr-Nat) (expr-lam 'mw (expr-Nat) (expr-bvar 0)))
         (expr-lam 'mw (expr-Nat) (expr-lam 'mw (expr-Nat) (expr-bvar 1)))
         (expr-lam 'mw (expr-Nat) (expr-lam 'mw (expr-Nat) (expr-bvar 2)))
         (expr-lam 'mw (expr-Nat) (expr-lam 'mw (expr-Nat) (expr-bvar 5)))
         ;; reduce: per-arm binding-count discharge, incl. the nullary arm
         (expr-reduce (expr-bvar 0)
                      (list (expr-reduce-arm 'nil 0 (expr-bvar 0))
                            (expr-reduce-arm 'cons 2 (expr-bvar 2))
                            (expr-reduce-arm 'other 3 (expr-bvar 7)))
                      #f)
         (expr-reduce (expr-nil) (list (expr-reduce-arm 'nil 0 (expr-nil))) #f)
         ;; a COLD-FALLBACK node — no explicit arm, must route through the
         ;; generic field walk identically in both implementations
         (expr-Eq (expr-Nat) (expr-bvar 2) (expr-nil))
         (expr-vcons (expr-Nat) (expr-zero) (expr-bvar 4) (expr-vnil (expr-Nat)))
         ;; closed and deep
         (closed-chain 30)
         (open-chain 30 2))))

(test-case "ORACLE: memoized range == naive reflective reference, whole battery"
  (for ([e (in-list (oracle-battery))])
    (check-equal? (loose-bvar-range e) (loose-bvar-range/reference e)
                  (format "range disagreement on ~a" e))))

(test-case "ORACLE: memo is stable — a second call agrees with the first"
  ;; Guards the memo itself: a term's range must not change once cached, and
  ;; clearing the cache must reproduce the same answer.
  (for ([e (in-list (oracle-battery))])
    (define first-call (loose-bvar-range e))
    (check-equal? (loose-bvar-range e) first-call)
    (clear-loose-bvar-cache!)
    (check-equal? (loose-bvar-range e) first-call
                  (format "range changed after cache clear on ~a" e))))

(test-case "ORACLE: the guard never fires when a loose bvar is in range"
  ;; The unsafe direction, stated directly: if reference says there IS a free
  ;; bvar at or above the cutoff, shift MUST NOT return its input eq?.
  (for* ([e (in-list (oracle-battery))] [cutoff (in-range 0 4)])
    (when (> (loose-bvar-range/reference e) cutoff)
      (check-false (eq? (shift 1 cutoff e) e)
                   (format "guard skipped a term with a free bvar >= ~a: ~a" cutoff e)))))
