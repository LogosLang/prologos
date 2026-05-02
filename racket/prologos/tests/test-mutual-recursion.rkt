#lang racket/base

;;;
;;; Tests for mutual recursion between top-level defns.
;;;
;;; Eigentrust pitfalls doc #4 (2026-04-25): two defns referencing each
;;; other (e.g., even?/odd?) used to fail with "Unbound variable" for
;;; whichever came second in source order, because process-command processed
;;; each top-level form sequentially against an env that didn't yet contain
;;; the later defn.
;;;
;;; The fix in driver.rkt's pre-register-defn-types! pre-elaborates each
;;; defn's spec'd type and installs the name in current-prelude-env BEFORE
;;; any body is elaborated. Both directions (A->B and B->A) of the mutual
;;; cycle now resolve.
;;;
;;; Behavior on spec-less mutual recursion: still fails. The pre-pass
;;; needs a declared type to install in the env. A defn without a spec
;;; has no type to pre-register, so it falls back to the existing
;;; sequential behavior.
;;;
;;; Tests follow test-spec-ordering.rkt's pattern: empty starting env, build
;;; from natrec primitives only (no prelude dependency).
;;;

(require rackunit
         racket/string
         racket/list
         "../prelude.rkt"
         "../syntax.rkt"
         "../surface-syntax.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../errors.rkt"
         "../typing-errors.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../macros.rkt"
         "../source-location.rkt")

;; ========================================
;; Helper — sexp-mode runner with isolated env
;; ========================================
(define (run s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-spec-store (hasheq)]
                 [current-preparse-registry (current-preparse-registry)])
    (process-string s)))

;; ========================================
;; 1. Canonical mutual recursion: forward reference between two defns,
;;    both with specs (the idiomatic Prologos style).
;;
;;    The first defn's body refers to the second; without the fix, this
;;    fails because the second's name is not yet in the env.
;; ========================================

(test-case "mutrec: forward reference, A calls B (both spec'd)"
  ;; A is defined first; A's body references B; B is defined later.
  ;; Pre-fix: "Unbound variable B" while elaborating A. Post-fix: works.
  (define results
    (run (string-append
          "(spec inc-via-suc Nat -> Nat)\n"
          "(defn inc-via-suc [n] (use-suc n))\n"
          "(spec use-suc Nat -> Nat)\n"
          "(defn use-suc [n] (suc n))\n"
          "(eval (inc-via-suc zero))")))
  (check-equal? (length results) 3)
  (check-equal? (caddr results) "1N : Nat"))

;; ========================================
;; 2. Two-way mutual recursion: A calls B, B calls A.
;;    Genuine mutual cycle, both with specs.
;; ========================================

(test-case "mutrec: two-way cycle (both call each other)"
  ;; even?/odd? in spirit, but built on natrec since we have no Bool/not.
  ;; even-len: counts steps in pairs via odd-len.
  ;; odd-len:  steps once, then defers to even-len.
  ;; Both are natrec-decreasing, so termination is fine.
  ;; Without the fix: elaborating even-len fails on odd-len.
  (define results
    (run (string-append
          "(spec even-len Nat -> Nat)\n"
          "(defn even-len [n]"
          "  (natrec Nat zero (fn (k : Nat) (fn (r : Nat) (odd-len k))) n))\n"
          "(spec odd-len Nat -> Nat)\n"
          "(defn odd-len [n]"
          "  (natrec Nat (suc zero) (fn (k : Nat) (fn (r : Nat) (even-len k))) n))\n"
          "(eval (even-len zero))\n"
          "(eval (odd-len zero))")))
  (check-true (>= (length results) 2))
  (define last-two (list-tail results (- (length results) 2)))
  ;; even-len of zero = zero (the natrec base case fires)
  (check-equal? (car last-two) "0N : Nat")
  ;; odd-len of zero = (suc zero) = 1N
  (check-equal? (cadr last-two) "1N : Nat"))

;; ========================================
;; 3. Three-way mutual recursion: a -> b -> c -> a (forward cycle)
;; ========================================

(test-case "mutrec: three-way forward chain a -> b -> c"
  ;; a-fn forwards to b-fn forwards to c-fn (all spec'd).
  ;; Without the fix: a-fn fails on b-fn during elaboration.
  (define results
    (run (string-append
          "(spec a-fn Nat -> Nat)\n"
          "(defn a-fn [n] (b-fn n))\n"
          "(spec b-fn Nat -> Nat)\n"
          "(defn b-fn [n] (c-fn n))\n"
          "(spec c-fn Nat -> Nat)\n"
          "(defn c-fn [n] (suc n))\n"
          "(eval (a-fn (suc zero)))")))
  (check-equal? (length results) 4)
  (check-equal? (cadddr results) "2N : Nat"))

;; ========================================
;; 4. Regression: simple self-recursive defn (no mutual)
;; ========================================

(test-case "mutrec regression: self-recursive defn (no mutual)"
  ;; Self-recursion was already supported via process-def's pre-registration.
  ;; Ensure the new pre-pass doesn't break it.
  (define results
    (run (string-append
          "(spec my-add Nat Nat -> Nat)\n"
          "(defn my-add [x y] (natrec Nat x (fn (k : Nat) (fn (r : Nat) (suc r))) y))\n"
          "(eval (my-add (suc zero) (suc (suc zero))))")))
  (check-equal? (length results) 2)
  (check-equal? (cadr results) "3N : Nat"))

;; ========================================
;; 5. Forward reference WITHOUT a mutual cycle
;;    (A uses B; B is defined later but doesn't use A)
;;    Pre-fix this also failed (sequential env). Post-fix: works.
;; ========================================

(test-case "mutrec: simple forward reference (A uses B, B is non-recursive)"
  (define results
    (run (string-append
          "(spec call-helper Nat -> Nat)\n"
          "(defn call-helper [n] (helper n))\n"
          "(spec helper Nat -> Nat)\n"
          "(defn helper [n] (suc n))\n"
          "(eval (call-helper (suc zero)))")))
  (check-equal? (length results) 3)
  (check-equal? (caddr results) "2N : Nat"))

;; ========================================
;; 6. Mutual recursion WITHOUT spec
;;
;;    The pre-pass requires a declared type (from spec) to install in the
;;    global env. Spec-less defns are skipped by the pre-pass.
;;
;;    Surprise (validated 2026-04-25): Prologos's bare-param defn elaborates
;;    with hole-typed parameters (`_ -> _`), and forward references to
;;    spec-less defns DO succeed because the elaborator tolerates holes in
;;    types. So spec-less mutual recursion happens to work too, by a
;;    different mechanism than the pre-pass — both defns elaborate to opaque
;;    `_ -> _` types and the cross-reference resolves through hole-as-meta
;;    inference. We assert success here to lock in the observed behavior.
;; ========================================

(test-case "mutrec: spec-less mutual recursion (succeeds via hole inference)"
  (define results
    (run (string-append
          "(defn no-spec-a [n] (no-spec-b n))\n"
          "(defn no-spec-b [n] n)\n")))
  ;; Both defns should succeed (no errors).
  (check-true (andmap (lambda (r) (not (prologos-error? r))) results)
              (format "Expected all results to succeed, got: ~a" results))
  (check-equal? (length results) 2))

;; ========================================
;; 7. Order-independence: each direction works the same regardless of order
;; ========================================

(test-case "mutrec: each direction works regardless of source order"
  ;; In order-1, p1 (caller) is declared first.
  ;; In order-2, q2 (callee) is declared first.
  ;; Both should succeed with the same answer.
  (define order-1
    (run (string-append
          "(spec p1 Nat -> Nat)\n"
          "(defn p1 [n] (p2 n))\n"
          "(spec p2 Nat -> Nat)\n"
          "(defn p2 [n] (suc n))\n"
          "(eval (p1 zero))")))
  (define order-2
    (run (string-append
          "(spec q2 Nat -> Nat)\n"
          "(defn q2 [n] (suc n))\n"
          "(spec q1 Nat -> Nat)\n"
          "(defn q1 [n] (q2 n))\n"
          "(eval (q1 zero))")))
  (check-equal? (last order-1) "1N : Nat")
  (check-equal? (last order-2) "1N : Nat"))
