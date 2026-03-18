#lang racket/base

;;;
;;; Tests for prologos list operations:
;;;   merge, sort, reverse-sum, sort-sum verification.
;;;
;;; Split from test-stdlib.rkt (part 3 of 3)
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
         "../metavar-store.rkt")

;; ========================================
;; Shared Fixture (modules loaded once)
;; ========================================

(define shared-preamble
  "(ns test)
(imports [prologos::data::list :refer [List nil cons merge length sum sort head reverse]])
(imports [prologos::data::nat :refer [le?]])
")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry))))

(define (run s)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg])
    (process-string s)))

(define (run-last s) (last (run s)))


(test-case "list/merge-both-empty"
  ;; merge le? [] [] = [], length 0
  (check-equal?
   (run-last "(eval (length Nat (merge Nat le? (nil Nat) (nil Nat))))")
   "0N : Nat"))


(test-case "list/merge-sorted"
  ;; merge le? [1,3] [2,4] = [1,2,3,4], sum = 10
  (check-equal?
   (run-last "(eval (sum (merge Nat le? (cons Nat (suc zero) (cons Nat (suc (suc (suc zero))) (nil Nat))) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc (suc zero)))) (nil Nat))))))")
   "10N : Nat"))


;; --- sort ---

(test-case "list/sort-empty"
  ;; sort le? [] = [], length 0
  (check-equal?
   (run-last "(eval (length Nat (sort Nat le? (nil Nat))))")
   "0N : Nat"))


(test-case "list/sort-single"
  ;; sort le? [3] = [3], sum = 3
  (check-equal?
   (run-last "(eval (sum (sort Nat le? (cons Nat (suc (suc (suc zero))) (nil Nat)))))")
   "3N : Nat"))


(test-case "list/sort-already-sorted"
  ;; sort le? [1,2,3] = [1,2,3], head = 1
  (check-equal?
   (run-last "(eval (head Nat zero (sort Nat le? (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))")
   "1N : Nat"))


(test-case "list/sort-unsorted"
  ;; sort le? [3,1,2] = [1,2,3], head = 1
  (check-equal?
   (run-last "(eval (head Nat zero (sort Nat le? (cons Nat (suc (suc (suc zero))) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))))")
   "1N : Nat"))


;; --- Additional verification tests ---

(test-case "list/reverse-sum-preserved"
  ;; reverse preserves sum: sum (reverse [1,2,3]) = 6
  (check-equal?
   (run-last "(eval (sum (reverse Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))")
   "6N : Nat"))


(test-case "list/sort-unsorted-sum"
  ;; sort preserves sum: sum (sort [3,1,2]) = 6
  (check-equal?
   (run-last "(eval (sum (sort Nat le? (cons Nat (suc (suc (suc zero))) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))))")
   "6N : Nat"))
