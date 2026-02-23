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


;; --- zip ---

(test-case "list/zip-length"
  ;; zip [1,2] [3,4], length = 2
  (check-equal?
   (last (run-ns "(ns lst154)\n(require [prologos::data::list :refer [List nil cons zip length]])\n(eval (length (Sigma [_ <Nat>] Nat) (zip Nat Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))) (cons Nat (suc (suc (suc zero))) (cons Nat (suc (suc (suc (suc zero)))) (nil Nat))))))"))
   "2N : Nat"))


(test-case "list/zip-head-first"
  ;; zip [1,2] [3,4], first element of head pair = 1
  (check-equal?
   (last (run-ns "(ns lst155)\n(require [prologos::data::list :refer [List nil cons zip head]])\n(eval (first (head (Sigma [_ <Nat>] Nat) (pair zero zero) (zip Nat Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))) (cons Nat (suc (suc (suc zero))) (cons Nat (suc (suc (suc (suc zero)))) (nil Nat)))))))"))
   "1N : Nat"))


;; --- unzip ---

(test-case "list/unzip-firsts"
  ;; unzip [(1,2), (3,4)], first list sum = 4
  (check-equal?
   (last (run-ns "(ns lst156)\n(require [prologos::data::list :refer [List nil cons unzip sum]])\n(eval (sum (first (unzip Nat Nat (cons (Sigma [_ <Nat>] Nat) (pair (suc zero) (suc (suc zero))) (cons (Sigma [_ <Nat>] Nat) (pair (suc (suc (suc zero))) (suc (suc (suc (suc zero))))) (nil (Sigma [_ <Nat>] Nat))))))))"))
   "4N : Nat"))


(test-case "list/unzip-seconds"
  ;; unzip [(1,2), (3,4)], second list sum = 6
  (check-equal?
   (last (run-ns "(ns lst157)\n(require [prologos::data::list :refer [List nil cons unzip sum]])\n(eval (sum (second (unzip Nat Nat (cons (Sigma [_ <Nat>] Nat) (pair (suc zero) (suc (suc zero))) (cons (Sigma [_ <Nat>] Nat) (pair (suc (suc (suc zero))) (suc (suc (suc (suc zero))))) (nil (Sigma [_ <Nat>] Nat))))))))"))
   "6N : Nat"))


;; --- intersperse ---

(test-case "list/intersperse-empty"
  ;; intersperse 0 [] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst158)\n(require [prologos::data::list :refer [List nil intersperse length]])\n(eval (length Nat (intersperse Nat zero (nil Nat))))"))
   "0N : Nat"))


(test-case "list/intersperse-single"
  ;; intersperse 0 [1] = [1], length 1
  (check-equal?
   (last (run-ns "(ns lst159)\n(require [prologos::data::list :refer [List nil cons intersperse length]])\n(eval (length Nat (intersperse Nat zero (cons Nat (suc zero) (nil Nat)))))"))
   "1N : Nat"))


(test-case "list/intersperse-multi"
  ;; intersperse 0 [1,2,3] = [1,0,2,0,3], length = 5
  (check-equal?
   (last (run-ns "(ns lst160)\n(require [prologos::data::list :refer [List nil cons intersperse length]])\n(eval (length Nat (intersperse Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "5N : Nat"))


;; --- halve ---

(test-case "list/halve-empty"
  ;; halve [] = ([], []), first length 0
  (check-equal?
   (last (run-ns "(ns lst161)\n(require [prologos::data::list :refer [List nil halve length]])\n(eval (length Nat (first (halve Nat (nil Nat)))))"))
   "0N : Nat"))


(test-case "list/halve-odd"
  ;; halve [1,2,3] — alternating: first = [1,3] (length 2)
  (check-equal?
   (last (run-ns "(ns lst162)\n(require [prologos::data::list :refer [List nil cons halve length]])\n(eval (length Nat (first (halve Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))))"))
   "2N : Nat"))


(test-case "list/halve-even"
  ;; halve [1,2,3,4] — second = [2,4] (length 2)
  (check-equal?
   (last (run-ns "(ns lst163)\n(require [prologos::data::list :refer [List nil cons halve length]])\n(eval (length Nat (second (halve Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (cons Nat (suc (suc (suc (suc zero)))) (nil Nat)))))))))"))
   "2N : Nat"))


;; --- merge ---

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
