#lang racket/base

;;;
;;; Tests for prologos list operations and auto-export:
;;;   List reduce, tail, reverse, sum, product, any?, all?, find,
;;;   nth, last, replicate, range, concat, take, drop, split-at,
;;;   take-while, drop-while, partition, zip-with, zip, unzip,
;;;   intersperse, halve, merge, sort, and auto-export/private tests.
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
         "../macros.rkt")

;; Helper: run prologos code with namespace system active
(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    (process-string s)))

;; Helper: run two prologos module strings sequentially,
;; sharing the module registry so the second can require the first.
;; Returns the results from the second module.
(define (run-ns-pair s1 s2)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    ;; Process the first module (sets up ns-context, registers module)
    (process-string s1)
    ;; Capture the module info from the first module's namespace
    (let ([ctx (current-ns-context)])
      (when ctx
        (let* ([ns-sym (ns-context-current-ns ctx)]
               [exports (cond
                          [(not (null? (ns-context-exports ctx)))
                           (ns-context-exports ctx)]
                          [(not (null? (ns-context-auto-exports ctx)))
                           (reverse (ns-context-auto-exports ctx))]
                          [else '()])]
               [mi (module-info ns-sym exports (current-global-env) #f (hasheq) (hasheq) (hasheq))])
          (register-module! ns-sym mi))))
    ;; Reset for second module
    (current-global-env (hasheq))
    (current-ns-context #f)
    (process-string s2)))


(test-case "list/merge-both-empty"
  ;; merge le? [] [] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst164)\n(require [prologos::data::list :refer [List nil merge length]])\n(require [prologos::data::nat :refer [le?]])\n(eval (length Nat (merge Nat le? (nil Nat) (nil Nat))))"))
   "0N : Nat"))


(test-case "list/merge-sorted"
  ;; merge le? [1,3] [2,4] = [1,2,3,4], sum = 10
  (check-equal?
   (last (run-ns "(ns lst165)\n(require [prologos::data::list :refer [List nil cons merge sum]])\n(require [prologos::data::nat :refer [le?]])\n(eval (sum (merge Nat le? (cons Nat (suc zero) (cons Nat (suc (suc (suc zero))) (nil Nat))) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc (suc zero)))) (nil Nat))))))"))
   "10N : Nat"))


;; --- sort ---

(test-case "list/sort-empty"
  ;; sort le? [] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst166)\n(require [prologos::data::list :refer [List nil sort length]])\n(require [prologos::data::nat :refer [le?]])\n(eval (length Nat (sort Nat le? (nil Nat))))"))
   "0N : Nat"))


(test-case "list/sort-single"
  ;; sort le? [3] = [3], sum = 3
  (check-equal?
   (last (run-ns "(ns lst167)\n(require [prologos::data::list :refer [List nil cons sort sum]])\n(require [prologos::data::nat :refer [le?]])\n(eval (sum (sort Nat le? (cons Nat (suc (suc (suc zero))) (nil Nat)))))"))
   "3N : Nat"))


(test-case "list/sort-already-sorted"
  ;; sort le? [1,2,3] = [1,2,3], head = 1
  (check-equal?
   (last (run-ns "(ns lst168)\n(require [prologos::data::list :refer [List nil cons sort head]])\n(require [prologos::data::nat :refer [le?]])\n(eval (head Nat zero (sort Nat le? (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "1N : Nat"))


(test-case "list/sort-unsorted"
  ;; sort le? [3,1,2] = [1,2,3], head = 1
  (check-equal?
   (last (run-ns "(ns lst169)\n(require [prologos::data::list :refer [List nil cons sort head]])\n(require [prologos::data::nat :refer [le?]])\n(eval (head Nat zero (sort Nat le? (cons Nat (suc (suc (suc zero))) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))))"))
   "1N : Nat"))


;; --- Additional verification tests ---

(test-case "list/reverse-sum-preserved"
  ;; reverse preserves sum: sum (reverse [1,2,3]) = 6
  (check-equal?
   (last (run-ns "(ns lst170)\n(require [prologos::data::list :refer [List nil cons reverse sum]])\n(eval (sum (reverse Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "6N : Nat"))


(test-case "list/sort-unsorted-sum"
  ;; sort preserves sum: sum (sort [3,1,2]) = 6
  (check-equal?
   (last (run-ns "(ns lst171)\n(require [prologos::data::list :refer [List nil cons sort sum]])\n(require [prologos::data::nat :refer [le?]])\n(eval (sum (sort Nat le? (cons Nat (suc (suc (suc zero))) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))))"))
   "6N : Nat"))
