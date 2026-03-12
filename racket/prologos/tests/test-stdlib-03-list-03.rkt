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
               [mi (module-info ns-sym exports (current-global-env) #f (hasheq) (hasheq) (hasheq) (hasheq))])
          (register-module! ns-sym mi))))
    ;; Reset for second module
    (current-global-env (hasheq))
    (current-ns-context #f)
    (process-string s2)))


(test-case "list/take-within"
  ;; take 2 [1,2,3] = [1,2], sum = 3
  (check-equal?
   (last (run-ns "(ns lst136)\n(imports [prologos::data::list :refer [List nil cons take sum]])\n(eval (sum (take Nat (suc (suc zero)) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "3N : Nat"))


(test-case "list/take-exceeds"
  ;; take 5 [1,2] = [1,2], sum = 3
  (check-equal?
   (last (run-ns "(ns lst137)\n(imports [prologos::data::list :refer [List nil cons take sum]])\n(eval (sum (take Nat (suc (suc (suc (suc (suc zero))))) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))))"))
   "3N : Nat"))


;; --- drop ---

(test-case "list/drop-zero"
  ;; drop 0 [1,2,3] = [1,2,3], sum = 6
  (check-equal?
   (last (run-ns "(ns lst138)\n(imports [prologos::data::list :refer [List nil cons drop sum]])\n(eval (sum (drop Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "6N : Nat"))


(test-case "list/drop-within"
  ;; drop 1 [1,2,3] = [2,3], sum = 5
  (check-equal?
   (last (run-ns "(ns lst139)\n(imports [prologos::data::list :refer [List nil cons drop sum]])\n(eval (sum (drop Nat (suc zero) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "5N : Nat"))


(test-case "list/drop-exceeds"
  ;; drop 5 [1,2] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst140)\n(imports [prologos::data::list :refer [List nil cons drop length]])\n(eval (length Nat (drop Nat (suc (suc (suc (suc (suc zero))))) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))))"))
   "0N : Nat"))


;; --- split-at ---

(test-case "list/split-at-first"
  ;; split-at 2 [1,2,3], first part sum = 3
  (check-equal?
   (last (run-ns "(ns lst141)\n(imports [prologos::data::list :refer [List nil cons split-at sum]])\n(eval (sum (fst (split-at Nat (suc (suc zero)) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))))"))
   "3N : Nat"))


(test-case "list/split-at-second"
  ;; split-at 2 [1,2,3], second part sum = 3
  (check-equal?
   (last (run-ns "(ns lst142)\n(imports [prologos::data::list :refer [List nil cons split-at sum]])\n(eval (sum (snd (split-at Nat (suc (suc zero)) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))))"))
   "3N : Nat"))


;; --- take-while ---

(test-case "list/take-while-all-pass"
  ;; take-while zero? [0,0,0] = [0,0,0], length 3
  (check-equal?
   (last (run-ns "(ns lst143)\n(imports [prologos::data::list :refer [List nil cons take-while length]])\n(imports [prologos::data::nat :refer [zero?]])\n(eval (length Nat (take-while Nat zero? (cons Nat zero (cons Nat zero (cons Nat zero (nil Nat)))))))"))
   "3N : Nat"))


(test-case "list/take-while-some-pass"
  ;; take-while zero? [0, 0, 1, 0] = [0, 0], length 2
  (check-equal?
   (last (run-ns "(ns lst144)\n(imports [prologos::data::list :refer [List nil cons take-while length]])\n(imports [prologos::data::nat :refer [zero?]])\n(eval (length Nat (take-while Nat zero? (cons Nat zero (cons Nat zero (cons Nat (suc zero) (cons Nat zero (nil Nat))))))))"))
   "2N : Nat"))


(test-case "list/take-while-none-pass"
  ;; take-while zero? [1, 2] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst145)\n(imports [prologos::data::list :refer [List nil cons take-while length]])\n(imports [prologos::data::nat :refer [zero?]])\n(eval (length Nat (take-while Nat zero? (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))))"))
   "0N : Nat"))


;; --- drop-while ---

(test-case "list/drop-while-all-pass"
  ;; drop-while zero? [0,0,0] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst146)\n(imports [prologos::data::list :refer [List nil cons drop-while length]])\n(imports [prologos::data::nat :refer [zero?]])\n(eval (length Nat (drop-while Nat zero? (cons Nat zero (cons Nat zero (cons Nat zero (nil Nat)))))))"))
   "0N : Nat"))


(test-case "list/drop-while-some-pass"
  ;; drop-while zero? [0, 0, 1, 2] = [1, 2], sum = 3
  (check-equal?
   (last (run-ns "(ns lst147)\n(imports [prologos::data::list :refer [List nil cons drop-while sum]])\n(imports [prologos::data::nat :refer [zero?]])\n(eval (sum (drop-while Nat zero? (cons Nat zero (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))))))"))
   "3N : Nat"))


(test-case "list/drop-while-none-pass"
  ;; drop-while zero? [1, 2, 3] = [1, 2, 3], sum = 6
  (check-equal?
   (last (run-ns "(ns lst148)\n(imports [prologos::data::list :refer [List nil cons drop-while sum]])\n(imports [prologos::data::nat :refer [zero?]])\n(eval (sum (drop-while Nat zero? (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "6N : Nat"))


;; --- partition ---

(test-case "list/partition-first"
  ;; partition zero? [0, 1, 0, 2], first = zeros, length 2
  (check-equal?
   (last (run-ns "(ns lst149)\n(imports [prologos::data::list :refer [List nil cons partition length]])\n(imports [prologos::data::nat :refer [zero?]])\n(eval (length Nat (fst (partition Nat zero? (cons Nat zero (cons Nat (suc zero) (cons Nat zero (cons Nat (suc (suc zero)) (nil Nat)))))))))"))
   "2N : Nat"))


(test-case "list/partition-second"
  ;; partition zero? [0, 1, 0, 2], second = non-zeros, sum = 3
  (check-equal?
   (last (run-ns "(ns lst150)\n(imports [prologos::data::list :refer [List nil cons partition sum]])\n(imports [prologos::data::nat :refer [zero?]])\n(eval (sum (snd (partition Nat zero? (cons Nat zero (cons Nat (suc zero) (cons Nat zero (cons Nat (suc (suc zero)) (nil Nat)))))))))"))
   "3N : Nat"))


;; --- zip-with ---

(test-case "list/zip-with-empty"
  ;; zip-with add [] [] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst151)\n(imports [prologos::data::list :refer [List nil zip-with length]])\n(imports [prologos::data::nat :refer [add]])\n(eval (length Nat (zip-with Nat Nat Nat add (nil Nat) (nil Nat))))"))
   "0N : Nat"))


(test-case "list/zip-with-same-length"
  ;; zip-with add [1,2] [3,4] = [4,6], sum = 10
  (check-equal?
   (last (run-ns "(ns lst152)\n(imports [prologos::data::list :refer [List nil cons zip-with sum]])\n(imports [prologos::data::nat :refer [add]])\n(eval (sum (zip-with Nat Nat Nat add (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))) (cons Nat (suc (suc (suc zero))) (cons Nat (suc (suc (suc (suc zero)))) (nil Nat))))))"))
   "10N : Nat"))


(test-case "list/zip-with-diff-length"
  ;; zip-with add [1,2,3] [10] = [11], sum = 11
  (check-equal?
   (last (run-ns "(ns lst153)\n(imports [prologos::data::list :refer [List nil cons zip-with sum]])\n(imports [prologos::data::nat :refer [add]])\n(eval (sum (zip-with Nat Nat Nat add (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))) (cons Nat (suc (suc (suc (suc (suc (suc (suc (suc (suc (suc zero)))))))))) (nil Nat)))))"))
   "11N : Nat"))
