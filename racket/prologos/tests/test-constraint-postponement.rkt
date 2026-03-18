#lang racket/base

;;;
;;; Tests for Sprint 5: Constraint Postponement and Dependent Unification
;;;
;;; Tests the three-valued unification, constraint store infrastructure,
;;; wakeup mechanism, and multi-param implicit inference.
;;;

(require rackunit
         racket/path
         racket/list
         "test-support.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../metavar-store.rkt"
         "../unify.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../macros.rkt"
         "../zonk.rkt")

;; ========================================
;; Unit tests: unify-ok? helper
;; ========================================

(test-case "unify-ok?/#t"
  (check-true (unify-ok? #t)))

(test-case "unify-ok?/postponed"
  (check-true (unify-ok? 'postponed)))

(test-case "unify-ok?/#f"
  (check-false (unify-ok? #f)))

;; ========================================
;; Unit tests: constraint store
;; ========================================

(test-case "constraint-store/add-constraint"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-hole) "test"))
    (define c (add-constraint! m (expr-Nat) ctx-empty "test"))
    (check-equal? (constraint-status c) 'postponed)
    (check-equal? (length (all-postponed-constraints)) 1)
    (check-equal? (length (all-failed-constraints)) 0)))

(test-case "constraint-store/collect-meta-ids"
  (with-fresh-meta-env
    (define m1 (fresh-meta ctx-empty (expr-hole) "a"))
    (define m2 (fresh-meta ctx-empty (expr-hole) "b"))
    ;; Expression with two metas: (app m1 m2)
    (define expr (expr-app m1 m2))
    (define ids (collect-meta-ids expr))
    (check-equal? (length ids) 2)))

(test-case "constraint-store/collect-meta-ids-follows-solved"
  (with-fresh-meta-env
    (parameterize ([current-retry-unify #f])  ;; disable wakeup for this test
      (define m1 (fresh-meta ctx-empty (expr-hole) "a"))
      (define m2 (fresh-meta ctx-empty (expr-hole) "b"))
      ;; Solve m1 to contain m2
      (solve-meta! (expr-meta-id m1) m2)
      ;; Now collect-meta-ids on m1 should find m2 (transitively)
      (define ids (collect-meta-ids m1))
      (check-not-false (memq (expr-meta-id m2) ids) "should find m2 through solved m1"))))

(test-case "constraint-store/reset"
  (with-fresh-meta-env
    (define m (fresh-meta ctx-empty (expr-hole) "test"))
    (add-constraint! m (expr-Nat) ctx-empty "test")
    (check-equal? (length (all-postponed-constraints)) 1)
    (reset-constraint-store!)
    (check-equal? (length (all-postponed-constraints)) 0)))

;; ========================================
;; Unit tests: wakeup mechanism
;; ========================================

(test-case "wakeup/solving-meta-retries-constraint"
  (with-fresh-meta-env
    (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
      ;; Create a meta and a postponed constraint: ?m vs Nat
      (define m (fresh-meta ctx-empty (expr-Type (lzero)) "test"))
      (define mid (expr-meta-id m))
      ;; Create an applied-meta term: (app ?m zero) — non-pattern, will postpone
      (define flex-term (expr-app m (expr-zero)))
      (define result (unify ctx-empty flex-term (expr-Nat)))
      (check-equal? result 'postponed)
      (check-equal? (length (all-postponed-constraints)) 1)
      ;; Now solve ?m to (fn [x] Nat) — i.e., a constant function returning Nat
      ;; This should trigger wakeup and retry the constraint:
      ;; zonk((app ?m zero)) → (app (fn [x] Nat) zero) → whnf → Nat
      ;; unify(Nat, Nat) → #t → constraint becomes 'solved
      (solve-meta! mid (expr-lam 'mw (expr-hole) (expr-Nat)))
      (check-equal? (length (all-postponed-constraints)) 0)
      (check-equal? (length (all-failed-constraints)) 0))))

(test-case "wakeup/constraint-fails-on-retry"
  (with-fresh-meta-env
    (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
      ;; Create a meta and postpone: (app ?m zero) vs Bool
      (define m (fresh-meta ctx-empty (expr-Type (lzero)) "test"))
      (define mid (expr-meta-id m))
      (define flex-term (expr-app m (expr-zero)))
      (define result (unify ctx-empty flex-term (expr-Bool)))
      (check-equal? result 'postponed)
      ;; Solve ?m to (fn [x] Nat) — now (app (fn [x] Nat) zero) → Nat
      ;; But the constraint expected Bool, so Nat ≠ Bool → failed
      (solve-meta! mid (expr-lam 'mw (expr-hole) (expr-Nat)))
      (check-equal? (length (all-postponed-constraints)) 0)
      (check-equal? (length (all-failed-constraints)) 1))))

;; ========================================
;; Unit tests: three-valued unify
;; ========================================

(test-case "unify/flex-app-non-pattern-postpones"
  (with-fresh-meta-env
    (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
      (define m (fresh-meta ctx-empty (expr-Type (lzero)) "test"))
      ;; (app ?m zero) — zero is not a bvar, pattern check fails → postpone
      (define flex-term (expr-app m (expr-zero)))
      (check-equal? (unify ctx-empty flex-term (expr-Nat)) 'postponed))))

(test-case "unify/flex-app-with-bvar-solves"
  (with-fresh-meta-env
    (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
      (define m (fresh-meta ctx-empty (expr-Type (lzero)) "test"))
      ;; (app ?m (bvar 0)) — bvar is a pattern arg → should solve
      (define flex-term (expr-app m (expr-bvar 0)))
      (check-equal? (unify ctx-empty flex-term (expr-Nat)) #t)
      (check-true (meta-solved? (expr-meta-id m))))))

;; ========================================
;; Integration tests: multi-param implicit inference
;; ========================================

;; Helper: run prologos code with namespace system active
(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry])
    (install-module-loader!)
    (process-string s)))

;; Helper: run code and return the last result line
(define (run-last s)
  (last (run-ns s)))

(test-case "implicit/compose-three-args"
  ;; compose double pred 3 → pred 3 = 2, double 2 = 4
  (check-equal?
   (run-last "(ns cp1)\n(imports [prologos::core :refer [compose]])\n(imports [prologos::data::nat :refer [double pred]])\n(eval (compose double pred 3N))")
   "4N : Nat"))

(test-case "implicit/apply-two-args"
  ;; apply double 3 → double 3 = 6
  (check-equal?
   (run-last "(ns cp2)\n(imports [prologos::core :refer [apply]])\n(imports [prologos::data::nat :refer [double]])\n(eval (apply double 3N))")
   "6N : Nat"))

(test-case "implicit/flip-three-args"
  ;; flip sub 2 5 → sub 5 2 = 3
  (check-equal?
   (run-last "(ns cp3)\n(imports [prologos::core :refer [flip]])\n(imports [prologos::data::nat :refer [sub]])\n(eval (flip sub 2N 5N))")
   "3N : Nat"))

(test-case "implicit/const-regression"
  ;; const zero true → zero (regression test)
  (check-equal?
   (run-last "(ns cp4)\n(imports [prologos::core :refer [const]])\n(eval (const zero true))")
   "0N : Nat"))

(test-case "implicit/id-regression"
  ;; id zero → zero (regression test)
  (check-equal?
   (run-last "(ns cp5)\n(imports [prologos::core :refer [id]])\n(eval (id zero))")
   "0N : Nat"))

(test-case "implicit/compose-bool-result"
  ;; compose not not true → not (not true) = not false = true
  (check-equal?
   (run-last "(ns cp6)\n(imports [prologos::core :refer [compose]])\n(imports [prologos::data::bool :refer [not]])\n(eval (compose not not true))")
   "true : Bool"))

(test-case "implicit/on-combinator"
  ;; on nat-eq? double 2N 3N → nat-eq? (double 2N) (double 3N) → nat-eq? 4 6 → false
  (check-equal?
   (run-last "(ns cp7)\n(imports [prologos::core :refer [on]])\n(imports [prologos::data::nat :refer [double nat-eq?]])\n(eval (on nat-eq? double 2N 3N))")
   "false : Bool"))

;; ========================================
;; Backward compatibility
;; ========================================

(test-case "implicit/explicit-type-args-still-work"
  ;; map Nat Nat suc [1, 2] — explicit type args
  (check-equal?
   (run-last "(ns cp8)\n(imports [prologos::data::list :refer [List nil cons map length]])\n(eval (length Nat (map Nat Nat (fn (x : Nat) (suc x)) (cons Nat zero (cons Nat (suc zero) (nil Nat))))))")
   "2N : Nat"))

(test-case "implicit/stdlib-nat-still-works"
  ;; add 2 3 = 5
  (check-equal?
   (run-last "(ns cp9)\n(imports [prologos::data::nat :refer [add]])\n(eval (add 2N 3N))")
   "5N : Nat"))

(test-case "implicit/stdlib-bool-still-works"
  ;; not true = false
  (check-equal?
   (run-last "(ns cp10)\n(imports [prologos::data::bool :refer [not]])\n(eval (not true))")
   "false : Bool"))
