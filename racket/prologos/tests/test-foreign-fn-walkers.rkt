#lang racket/base

;;; test-foreign-fn-walkers.rkt — `expr-foreign-fn` is not a closed leaf.
;;;
;;; Every AST walker in the compiler had an arm reading
;;;
;;;     ;; Foreign function (opaque leaf — no Prologos sub-expressions)
;;;     [(expr-foreign-fn _ _ _ _ _ _ _ _) e]
;;;
;;; and the parenthetical was false. `reduction.rkt`'s partial-application arm
;;; APPENDS whnf'd argument expressions into the `args` field and returns the
;;; updated node when arity has not been reached — so a node reachable under a
;;; binder can hold an open term that `subst` then refuses to descend, and that
;;; `shift` never renumbers.
;;;
;;; This is the `expr-champ` shape from `pipeline.md` § "Exhaustive Walkers": a
;;; comment asserting an invariant that nothing enforces. There it cost beta
;;; silently dropping arguments and variable capture, across a container family
;;; where one member was fixed and its siblings were not — with a green suite
;;; throughout.
;;;
;;; It was filed as LATENT and probed as not reproducible end-to-end:
;;; substitution happens on the enclosing `expr-app` before `whnf` ever builds
;;; the partial, so no source program reaches it today. That makes it a
;;; tripwire, and a tripwire is worth arming rather than describing — the
;;; invariant is one reduction-order change away from being load-bearing.
;;;
;;; These tests go at the walkers directly, because the whole difficulty is
;;; that no source program gets there. A behavioural test would pass with the
;;; bug in place, which is exactly how it survived.

(require rackunit
         "../syntax.rkt"
         "../substitution.rkt"
         (only-in "../pretty-print.rkt" uses-bvar0?)
         (only-in "../zonk.rkt" zonk))

;; A partially-applied 2-ary foreign whose single accumulated argument is the
;; term under test. This is the shape reduction.rkt:2176 constructs.
(define (partial-with arg)
  (expr-foreign-fn 'f void 2 (list arg) (list values values) values #f 'f))

(define (args-of e) (expr-foreign-fn-args e))

(test-case "foreign-fn/shift renumbers an accumulated open argument"
  ;; The capture case. Left unshifted, the argument's de Bruijn index goes on
  ;; pointing at whatever binder it lands under after the enclosing term moves.
  (define e (partial-with (expr-bvar 0)))
  (define shifted (shift 1 0 e))
  (check-true (expr-foreign-fn? shifted))
  (check-equal? (args-of shifted) (list (expr-bvar 1))
                "the accumulated argument was not renumbered"))

(test-case "foreign-fn/shift respects the cutoff"
  ;; A bvar below the cutoff is bound INSIDE the term being shifted and must
  ;; not move. Getting this wrong is as bad as not shifting at all.
  (check-equal? (args-of (shift 1 1 (partial-with (expr-bvar 0))))
                (list (expr-bvar 0)))
  (check-equal? (args-of (shift 1 1 (partial-with (expr-bvar 1))))
                (list (expr-bvar 2))))

(test-case "foreign-fn/subst replaces an accumulated open argument"
  ;; The dropped-argument case: `subst` returning the node untouched means the
  ;; substitution silently does not happen, and the result is a term still
  ;; mentioning a variable that no longer exists.
  (define e (partial-with (expr-bvar 0)))
  (define out (subst 0 (expr-fvar 'replacement) e))
  (check-true (expr-foreign-fn? out))
  (check-equal? (args-of out) (list (expr-fvar 'replacement))
                "the accumulated argument was not substituted"))

(test-case "foreign-fn/uses-bvar0? sees an accumulated open argument"
  ;; Answering #f here tells the Pi-printing path a binder is unused, so it
  ;; prints a non-dependent arrow for a dependent type.
  (check-true (uses-bvar0? (partial-with (expr-bvar 0))))
  (check-false (uses-bvar0? (partial-with (expr-bvar 1))))
  (check-false (uses-bvar0? (partial-with (expr-fvar 'x)))))

(test-case "foreign-fn/zonk descends accumulated arguments"
  ;; An unzonked meta inside `args` survives into a value, where nothing else
  ;; is expecting one.
  (check-true (expr-foreign-fn? (zonk (partial-with (expr-fvar 'x))))))

(test-case "foreign-fn/a closed node is returned EQ, not rebuilt"
  ;; Sharing preservation, which is why the arms test `andmap eq?` rather than
  ;; always reconstructing. `shift` with delta 0 being the identity is a
  ;; documented performance property of this file (GitHub #58 P1); rebuilding
  ;; every foreign node on every walk would quietly undo part of it.
  (define closed (partial-with (expr-fvar 'x)))
  (check-eq? (shift 1 0 closed) closed)
  (check-eq? (subst 0 (expr-fvar 'y) closed) closed)
  (define empty (expr-foreign-fn 'f void 2 '() (list values values) values #f 'f))
  (check-eq? (shift 1 0 empty) empty)
  (check-eq? (subst 0 (expr-fvar 'y) empty) empty))

(test-case "foreign-fn/every accumulated argument is walked, not just the first"
  ;; A 3-ary foreign with two arguments in hand. Walking only `(car args)` is
  ;; the plausible half-fix.
  (define e (expr-foreign-fn 'g void 3 (list (expr-bvar 0) (expr-bvar 0))
                             (list values values values) values #f 'g))
  (check-equal? (args-of (shift 2 0 e)) (list (expr-bvar 2) (expr-bvar 2))))
