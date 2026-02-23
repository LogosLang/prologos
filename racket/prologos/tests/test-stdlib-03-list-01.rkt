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


;; ========================================
;; prologos::data::list — Sprint 1.1 New Functions
;; ========================================

;; --- reduce (left fold) ---

(test-case "list/reduce-empty"
  ;; reduce add 0 [] = 0
  (check-equal?
   (last (run-ns "(ns lst100)\n(require [prologos::data::list :refer [List nil reduce]])\n(require [prologos::data::nat :refer [add]])\n(eval (reduce Nat Nat add zero (nil Nat)))"))
   "0N : Nat"))


(test-case "list/reduce-single"
  ;; reduce add 0 [5] = 5
  (check-equal?
   (last (run-ns "(ns lst101)\n(require [prologos::data::list :refer [List nil cons reduce]])\n(require [prologos::data::nat :refer [add]])\n(eval (reduce Nat Nat add zero (cons Nat (suc (suc (suc (suc (suc zero))))) (nil Nat))))"))
   "5N : Nat"))


(test-case "list/reduce-multi"
  ;; reduce add 0 [1,2,3] = 6
  (check-equal?
   (last (run-ns "(ns lst102)\n(require [prologos::data::list :refer [List nil cons reduce]])\n(require [prologos::data::nat :refer [add]])\n(eval (reduce Nat Nat add zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))"))
   "6N : Nat"))


;; --- tail ---

;; NOTE: tail tests re-enabled — Option (List A) is well-typed now (List A : Type 0)

(test-case "list/tail-empty"
  (check-equal?
   (last (run-ns "(ns lst103)\n(require [prologos::data::list :refer [List nil tail length]])\n(require [prologos::data::option :refer [unwrap-or]])\n(eval (length Nat (unwrap-or (List Nat) (nil Nat) (tail Nat (nil Nat)))))"))
   "0N : Nat"))


(test-case "list/tail-nonempty"
  (check-equal?
   (last (run-ns "(ns lst104)\n(require [prologos::data::list :refer [List nil cons tail length]])\n(require [prologos::data::option :refer [unwrap-or]])\n(eval (length Nat (unwrap-or (List Nat) (nil Nat) (tail Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))))"))
   "2N : Nat"))


;; --- reverse ---

(test-case "list/reverse-empty"
  ;; reverse [] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst105)\n(require [prologos::data::list :refer [List nil reverse length]])\n(eval (length Nat (reverse Nat (nil Nat))))"))
   "0N : Nat"))


(test-case "list/reverse-single"
  ;; reverse [5] = [5], head = 5
  (check-equal?
   (last (run-ns "(ns lst106)\n(require [prologos::data::list :refer [List nil cons reverse head]])\n(eval (head Nat zero (reverse Nat (cons Nat (suc (suc (suc (suc (suc zero))))) (nil Nat)))))"))
   "5N : Nat"))


(test-case "list/reverse-multi"
  ;; reverse [1,2,3], head = 3
  (check-equal?
   (last (run-ns "(ns lst107)\n(require [prologos::data::list :refer [List nil cons reverse head]])\n(eval (head Nat zero (reverse Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "3N : Nat"))


;; --- sum ---

(test-case "list/sum-empty"
  ;; sum [] = 0
  (check-equal?
   (last (run-ns "(ns lst108)\n(require [prologos::data::list :refer [List nil sum]])\n(eval (sum (nil Nat)))"))
   "0N : Nat"))


(test-case "list/sum-multi"
  ;; sum [1,2,3] = 6
  (check-equal?
   (last (run-ns "(ns lst109)\n(require [prologos::data::list :refer [List nil cons sum]])\n(eval (sum (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))"))
   "6N : Nat"))


;; --- product ---

(test-case "list/product-empty"
  ;; product [] = 1
  (check-equal?
   (last (run-ns "(ns lst110)\n(require [prologos::data::list :refer [List nil product]])\n(eval (product (nil Nat)))"))
   "1N : Nat"))


(test-case "list/product-multi"
  ;; product [2,3] = 6
  (check-equal?
   (last (run-ns "(ns lst111)\n(require [prologos::data::list :refer [List nil cons product]])\n(eval (product (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))"))
   "6N : Nat"))


;; --- any? ---

(test-case "list/any?-empty"
  ;; any? zero? [] = false
  (check-equal?
   (last (run-ns "(ns lst112)\n(require [prologos::data::list :refer [List nil any?]])\n(require [prologos::data::nat :refer [zero?]])\n(eval (any? Nat zero? (nil Nat)))"))
   "false : Bool"))


(test-case "list/any?-found"
  ;; any? zero? [1, 0, 2] = true
  (check-equal?
   (last (run-ns "(ns lst113)\n(require [prologos::data::list :refer [List nil cons any?]])\n(require [prologos::data::nat :refer [zero?]])\n(eval (any? Nat zero? (cons Nat (suc zero) (cons Nat zero (cons Nat (suc (suc zero)) (nil Nat))))))"))
   "true : Bool"))


(test-case "list/any?-not-found"
  ;; any? zero? [1, 2] = false
  (check-equal?
   (last (run-ns "(ns lst114)\n(require [prologos::data::list :refer [List nil cons any?]])\n(require [prologos::data::nat :refer [zero?]])\n(eval (any? Nat zero? (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))"))
   "false : Bool"))


;; --- all? ---

(test-case "list/all?-empty"
  ;; all? zero? [] = true (vacuously)
  (check-equal?
   (last (run-ns "(ns lst115)\n(require [prologos::data::list :refer [List nil all?]])\n(require [prologos::data::nat :refer [zero?]])\n(eval (all? Nat zero? (nil Nat)))"))
   "true : Bool"))


(test-case "list/all?-all-pass"
  ;; all? zero? [0, 0] = true
  (check-equal?
   (last (run-ns "(ns lst116)\n(require [prologos::data::list :refer [List nil cons all?]])\n(require [prologos::data::nat :refer [zero?]])\n(eval (all? Nat zero? (cons Nat zero (cons Nat zero (nil Nat)))))"))
   "true : Bool"))


(test-case "list/all?-some-fail"
  ;; all? zero? [0, 1] = false
  (check-equal?
   (last (run-ns "(ns lst117)\n(require [prologos::data::list :refer [List nil cons all?]])\n(require [prologos::data::nat :refer [zero?]])\n(eval (all? Nat zero? (cons Nat zero (cons Nat (suc zero) (nil Nat)))))"))
   "false : Bool"))
