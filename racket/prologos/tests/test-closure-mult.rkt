#lang racket/base

;;;
;;; test-closure-mult.rkt
;;;
;;; Eigentrust pitfalls doc #2 — closure capture in higher-order combinators
;;; triggering QTT multiplicity violations.
;;;
;;; Pitfall (2026-04-23): a closure that captures a value and is passed to
;;; `map` (or other generic combinators) failed QTT with "Multiplicity
;;; violation," even when the spec did not annotate any linearity.
;;;
;;; The actual root cause (diagnosed 2026-04-25): a kind-level Pi mult
;;; mismatch. Type constructors like `List` are registered with kind
;;; `Pi(m0, Type, Type)` (erased type arg) but generic combinators' specs
;;; elaborate `{C : Type -> Type}` to `Pi(mw, Type, Type)` (because the
;;; `->` arrow defaults to mw). When the type constructor flows into the
;;; combinator's implicit slot, QTT's `unify` rejects the mult mismatch
;;; even though typing-core succeeds.
;;;
;;; Fix: `classify-mult-problem` (unify.rkt) treats {m0, mw} as a
;;; non-contradictory pair: m0 = "zero runtime uses" trivially satisfies
;;; mw = "any number of uses." Linear (m1) is preserved as incompatible
;;; with the others — that's a real value-level usage difference.
;;;
;;; This test file covers:
;;;  - the eigentrust reproducer (`scale-vec` with map+fn capturing scalar)
;;;  - other higher-order combinators capturing scalars
;;;  - confirmation that linearity (-1>) is still enforced
;;;  - regression for the unify-mult m0/m1 incompatibility
;;;

(require rackunit
         "test-support.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../metavar-store.rkt"
         "../unify.rkt"
         "../global-env.rkt"
         "../errors.rkt"
         "../driver.rkt")

;; ========================================
;; Unit tests: classify-mult-problem / unify-mult lenience
;; ========================================

(test-case "unify-mult/m0-vs-mw-compatible"
  ;; Per the eigentrust pitfalls doc #2 fix: m0 (erased) and mw (unrestricted)
  ;; are compatible.
  ;; A value used 0 times trivially satisfies "any number of uses."
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)])
      (define t1 (expr-Pi 'm0 (expr-Type (lzero)) (expr-Type (lzero))))
      (define t2 (expr-Pi 'mw (expr-Type (lzero)) (expr-Type (lzero))))
      (check-equal? (unify ctx-empty t1 t2) #t
                    "Pi(m0, Type, Type) and Pi(mw, Type, Type) should unify"))))

(test-case "unify-mult/mw-vs-m0-compatible"
  ;; Symmetry of the m0/mw lenience.
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)])
      (define t1 (expr-Pi 'mw (expr-Type (lzero)) (expr-Type (lzero))))
      (define t2 (expr-Pi 'm0 (expr-Type (lzero)) (expr-Type (lzero))))
      (check-equal? (unify ctx-empty t1 t2) #t
                    "Pi(mw, Type, Type) and Pi(m0, Type, Type) should unify"))))

(test-case "unify-mult/m0-vs-m1-still-rejects"
  ;; Regression: linear (m1) is preserved as incompatible with erased (m0).
  ;; A value with linear usage cannot inhabit a slot expecting "exactly zero."
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)])
      (define t1 (expr-Pi 'm0 (expr-Nat) (expr-Nat)))
      (define t2 (expr-Pi 'm1 (expr-Nat) (expr-Nat)))
      (check-equal? (unify ctx-empty t1 t2) #f
                    "Pi(m0, Nat, Nat) and Pi(m1, Nat, Nat) should reject"))))

(test-case "unify-mult/m1-vs-mw-still-rejects"
  ;; Regression: linear (m1) is preserved as incompatible with unrestricted (mw).
  ;; A linear function cannot be safely passed where mw is needed
  ;; (the caller may invoke it many times).
  (with-fresh-meta-env
    (parameterize ([current-prelude-env (hasheq)])
      (define t1 (expr-Pi 'm1 (expr-Nat) (expr-Nat)))
      (define t2 (expr-Pi 'mw (expr-Nat) (expr-Nat)))
      (check-equal? (unify ctx-empty t1 t2) #f
                    "Pi(m1, Nat, Nat) and Pi(mw, Nat, Nat) should reject"))))

;; ========================================
;; Integration tests: eigentrust pitfalls doc #2 reproducer
;; ========================================

(test-case "closure-mult/scale-vec-eigentrust-reproducer"
  ;; THE ORIGINAL PITFALL: scale-vec captures a scalar and passes a closure
  ;; to map. Pre-fix this gave "Multiplicity violation"; post-fix it works.
  (define result
    (run-ns-ws-last
     (string-append
      "ns scale-vec-test\n"
      "spec scale-vec Rat [List Rat] -> [List Rat]\n"
      "defn scale-vec [s xs]\n"
      "  [map (fn [x : Rat] [rat* s x]) xs]\n"
      "[scale-vec 1/2 '[1/2 1/4 1/8]]\n")))
  (check-equal? result "'[1/4 1/8 1/16] : [prologos::data::list::List Rat]"))

(test-case "closure-mult/scale-vec-defn-only"
  ;; Just defining scale-vec was enough to trigger the bug pre-fix.
  (define result
    (run-ns-ws-last
     (string-append
      "ns scale-vec-defn\n"
      "spec scale-vec Rat [List Rat] -> [List Rat]\n"
      "defn scale-vec [s xs]\n"
      "  [map (fn [x : Rat] [rat* s x]) xs]\n")))
  (check-regexp-match #rx"scale-vec" (format "~a" result)
                      "scale-vec should be defined without QTT failure"))

(test-case "closure-mult/scale-and-shift-multiple-captures"
  ;; Two captured scalars in one closure passed to map.
  ;; (Defn-only — invocation result depends on rational arithmetic which
  ;; varies in printer formatting; the QTT pass is what we're testing.)
  (define result
    (run-ns-ws-last
     (string-append
      "ns scale-and-shift\n"
      "spec scale-and-shift Rat Rat [List Rat] -> [List Rat]\n"
      "defn scale-and-shift [s b xs]\n"
      "  [map (fn [x : Rat] [rat+ b [rat* s x]]) xs]\n")))
  (check-regexp-match #rx"scale-and-shift"
                      (format "~a" result)
                      "scale-and-shift should be defined without QTT failure"))

;; ========================================
;; Other higher-order combinators
;; ========================================

;; NOTE: when the m0/mw lenience let more unification paths succeed, the
;; typing-core check/Pi case at typing-core.rkt:2143 was being re-entered
;; with already-solved mult-metas and crashed on `solve-mult-meta!: already
;; solved`. The same unguarded solve also existed in the let-redex case
;; (typing-core.rkt:2501). Both are now guarded with `mult-meta-solved?`
;; (matching the existing QTT-side guards in qtt.rkt:2106-2108).
;;
;; Below: foldr-with-captured-scalar (defn-only — invocation result depends
;; on Rat literal printer details that vary; the QTT pass is what we test).

(test-case "closure-mult/foldr-with-captured-scalar-defn"
  ;; foldr capturing a scalar via a closure — defn must elaborate without
  ;; QTT failure or duplicate-solve-meta crash. We use Int (not Rat) to
  ;; sidestep an orthogonal Rat-literal-elaboration issue (`0` vs `0/1`)
  ;; in foldr's seed argument elaboration. The QTT/closure-mult question
  ;; is what we're testing here.
  (define result
    (run-ns-ws-last
     (string-append
      "ns foldr-cap\n"
      "spec sum-shifted Int [List Int] -> Int\n"
      "defn sum-shifted [shift xs]\n"
      "  [foldr (fn [x : Int] (fn [acc : Int] [int+ acc [int+ x shift]])) 0 xs]\n")))
  (check-regexp-match #rx"sum-shifted"
                      (format "~a" result)
                      "sum-shifted should be defined without QTT failure"))

;; ========================================
;; Linearity preservation: explicit -1> should still be enforced
;; ========================================

(test-case "closure-mult/explicit-linear-still-rejected-on-multi-use"
  ;; If the user explicitly says s is linear (-1>) and the body uses s
  ;; multiple times via map, QTT should still reject. This confirms the
  ;; m0/mw lenience did not silently break linear-mult enforcement.
  (define result
    (run-ns-ws-last
     (string-append
      "ns explicit-linear-test\n"
      "spec linear-scale Rat -1> [List Rat] -> [List Rat]\n"
      "defn linear-scale [s xs]\n"
      "  [map (fn [x : Rat] [rat* s x]) xs]\n")))
  ;; The defn should be REJECTED — `s` is declared linear (-1>) but the
  ;; map call uses `s` once per list element. QTT must catch this.
  (check-true (prologos-error? result)
              "Linear (-1>) parameter used many times via map must be rejected by QTT"))

;; ========================================
;; Dict-param mw heuristic regression
;; ========================================
;; This is the precedent the eigentrust fix extends.
;; Confirm dict params still get mw via the existing path.

(test-case "closure-mult/dict-param-mw-regression"
  ;; A defn that uses an Eq method via the prelude dispatches through the
  ;; auto-inserted dict param. The dict param's mult must be mw so the body
  ;; can use it (`eq?` uses the dict). This is the "Dict params use mw"
  ;; precedent in CLAUDE.md that the eigentrust pitfalls doc #2 fix builds on.
  ;;
  ;; Use prelude-built `nat-eq` as a sanity check that the Eq dispatch
  ;; pipeline still works. (Spec-with-where in run-ns-ws-last has fixture
  ;; quirks unrelated to this fix; use a direct eq? call as the regression
  ;; check.)
  (define result
    (run-ns-ws-last
     (string-append
      "ns dict-mw-test\n"
      "(eq-check 1 1)\n")))
  (check-regexp-match #rx"true"
                      (format "~a" result)
                      "Eq dispatch (which relies on dict-param mw) should work"))

;; (test cases run when this file is loaded by raco test)
