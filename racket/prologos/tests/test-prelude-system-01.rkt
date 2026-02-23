#lang racket/base

;;;
;;; PROLOGOS PRELUDE SYSTEM TESTS
;;; Verifies that `ns foo` auto-imports the prelude (Nat, Bool, List, Option,
;;; Result, Pair, traits, instances) without explicit require statements.
;;; Also tests :no-prelude opt-out, own-definition shadowing, and
;;; prelude-dependency circularity guard.
;;;

(require rackunit
         racket/path
         racket/string
         racket/list
         "test-support.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../macros.rkt"
         "../metavar-store.rkt"
         "../errors.rkt")

;; Helper: run prologos code with namespace system active
;; Includes trait/impl registries for generic function resolution.
(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    (process-string s)))

;; Helper: check that a run-ns result contains an error
(define (result-has-error? results)
  (and (list? results)
       (ormap prologos-error? results)))


;; ================================================================
;; Tier 0: Foundation — Nat ops available without require
;; ================================================================

(test-case "prelude: nat add available"
  (check-equal?
   (run-ns "(ns test.pre1)\n(eval (add zero zero))")
   '("0N : Nat")))


(test-case "prelude: nat mult available"
  (check-equal?
   (run-ns "(ns test.pre2)\n(eval (mult (suc (suc zero)) (suc (suc (suc zero)))))")
   '("6N : Nat")))


(test-case "prelude: nat pred available"
  (check-equal?
   (run-ns "(ns test.pre3)\n(eval (pred (suc (suc zero))))")
   '("1N : Nat")))


(test-case "prelude: nat zero? available"
  (check-equal?
   (run-ns "(ns test.pre4)\n(eval (zero? zero))")
   '("true : Bool")))


;; ================================================================
;; Tier 0: Foundation — Bool ops
;; ================================================================

(test-case "prelude: bool not available"
  (check-equal?
   (run-ns "(ns test.pre5)\n(eval (not true))")
   '("false : Bool")))


(test-case "prelude: bool and available"
  (check-equal?
   (run-ns "(ns test.pre6)\n(eval (and true false))")
   '("false : Bool")))


;; ================================================================
;; Tier 0: Foundation — Pair ops
;; ================================================================

(test-case "prelude: pair swap available"
  ;; pair constructor is built-in (implicit type args), swap from prelude
  (check-equal?
   (run-ns "(ns test.pre7)\n(eval (swap Nat Bool (pair zero true)))")
   '("[pair true 0N] : [Sigma Bool Nat]")))


;; ================================================================
;; Tier 0: Foundation — Ordering
;; ================================================================

(test-case "prelude: ordering constructors available"
  (check-equal?
   (run-ns "(ns test.pre8)\n(check lt-ord : Ordering)")
   '("OK"))
  (check-equal?
   (run-ns "(ns test.pre9)\n(check eq-ord : Ordering)")
   '("OK"))
  (check-equal?
   (run-ns "(ns test.pre10)\n(check gt-ord : Ordering)")
   '("OK")))


;; ================================================================
;; Tier 0: Foundation — prologos::core (id, const, compose)
;; ================================================================

(test-case "prelude: core id available"
  (check-equal?
   (run-ns "(ns test.pre12)\n(eval (id Nat zero))")
   '("0N : Nat")))


(test-case "prelude: core const available"
  (check-equal?
   (run-ns "(ns test.pre13)\n(eval (const Nat Bool zero true))")
   '("0N : Nat")))


;; ================================================================
;; Tier 1: Containers — List
;; ================================================================

(test-case "prelude: list cons/nil available"
  (check-equal?
   (run-ns "(ns test.pre14)\n(check (cons Nat zero (nil Nat)) : (List Nat))")
   '("OK")))


(test-case "prelude: list map available"
  ;; map/filter/length are now generic (from collection-fns);
  ;; they auto-resolve Seqable/Buildable dicts without explicit type args.
  (check-equal?
   (run-ns "(ns test.pre15)\n(eval (length (map (fn (x : Nat) (suc x)) (cons Nat zero (nil Nat)))))")
   '("1N : Nat")))


(test-case "prelude: list filter available"
  (check-equal?
   (run-ns "(ns test.pre16)\n(eval (length (filter zero? (cons Nat zero (cons Nat (suc zero) (nil Nat))))))")
   '("1N : Nat")))


(test-case "prelude: list length available"
  (check-equal?
   (run-ns "(ns test.pre17)\n(eval (length (cons Nat zero (cons Nat (suc zero) (nil Nat)))))")
   '("2N : Nat")))


(test-case "prelude: list reverse available"
  (check-equal?
   (run-ns "(ns test.pre18)\n(eval (length (reverse Nat (cons Nat zero (cons Nat (suc zero) (nil Nat))))))")
   '("2N : Nat")))
