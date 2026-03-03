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


;; --- find ---

(test-case "list/find-empty"
  ;; find zero? [] = none, unwrap-or to 5
  (check-equal?
   (last (run-ns "(ns lst118)\n(imports [prologos::data::list :refer [List nil find]])\n(imports [prologos::data::nat :refer [zero?]])\n(imports [prologos::data::option :refer [unwrap-or]])\n(eval (unwrap-or Nat (suc (suc (suc (suc (suc zero))))) (find Nat zero? (nil Nat))))"))
   "5N : Nat"))


(test-case "list/find-found"
  ;; find zero? [1, 0, 2] = some 0
  (check-equal?
   (last (run-ns "(ns lst119)\n(imports [prologos::data::list :refer [List nil cons find]])\n(imports [prologos::data::nat :refer [zero?]])\n(imports [prologos::data::option :refer [unwrap-or]])\n(eval (unwrap-or Nat (suc (suc (suc (suc (suc zero))))) (find Nat zero? (cons Nat (suc zero) (cons Nat zero (cons Nat (suc (suc zero)) (nil Nat)))))))"))
   "0N : Nat"))


(test-case "list/find-not-found"
  ;; find zero? [1, 2] = none, unwrap-or to 5
  (check-equal?
   (last (run-ns "(ns lst120)\n(imports [prologos::data::list :refer [List nil cons find]])\n(imports [prologos::data::nat :refer [zero?]])\n(imports [prologos::data::option :refer [unwrap-or]])\n(eval (unwrap-or Nat (suc (suc (suc (suc (suc zero))))) (find Nat zero? (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))))"))
   "5N : Nat"))


;; --- nth ---

(test-case "list/nth-valid"
  ;; nth 1 [3, 5, 7] = some 5
  (check-equal?
   (last (run-ns "(ns lst121)\n(imports [prologos::data::list :refer [List nil cons nth]])\n(imports [prologos::data::option :refer [unwrap-or]])\n(eval (unwrap-or Nat zero (nth Nat (suc zero) (cons Nat (suc (suc (suc zero))) (cons Nat (suc (suc (suc (suc (suc zero))))) (cons Nat (suc (suc (suc (suc (suc (suc (suc zero))))))) (nil Nat)))))))"))
   "5N : Nat"))


(test-case "list/nth-out-of-bounds"
  ;; nth 5 [1,2] = none, unwrap-or to 0
  (check-equal?
   (last (run-ns "(ns lst122)\n(imports [prologos::data::list :refer [List nil cons nth]])\n(imports [prologos::data::option :refer [unwrap-or]])\n(eval (unwrap-or Nat zero (nth Nat (suc (suc (suc (suc (suc zero))))) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))))"))
   "0N : Nat"))


(test-case "list/nth-empty"
  ;; nth 0 [] = none, unwrap-or to 0
  (check-equal?
   (last (run-ns "(ns lst123)\n(imports [prologos::data::list :refer [List nil nth]])\n(imports [prologos::data::option :refer [unwrap-or]])\n(eval (unwrap-or Nat zero (nth Nat zero (nil Nat))))"))
   "0N : Nat"))


;; --- last (Prologos function) ---

(test-case "list/last-empty"
  ;; last [] = none, unwrap-or to 0
  (check-equal?
   (last (run-ns "(ns lst124)\n(imports [prologos::data::list :refer [List nil last]])\n(imports [prologos::data::option :refer [unwrap-or]])\n(eval (unwrap-or Nat zero (last Nat (nil Nat))))"))
   "0N : Nat"))


(test-case "list/last-nonempty"
  ;; last [1,2,3] = some 3
  (check-equal?
   (last (run-ns "(ns lst125)\n(imports [prologos::data::list :refer [List nil cons last]])\n(imports [prologos::data::option :refer [unwrap-or]])\n(eval (unwrap-or Nat zero (last Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "3N : Nat"))


;; --- replicate ---

(test-case "list/replicate-zero"
  ;; replicate 0 x = [], length 0
  (check-equal?
   (last (run-ns "(ns lst126)\n(imports [prologos::data::list :refer [List replicate length]])\n(eval (length Nat (replicate Nat zero (suc (suc (suc zero))))))"))
   "0N : Nat"))


(test-case "list/replicate-positive"
  ;; replicate 3 5 = [5,5,5], sum = 15
  (check-equal?
   (last (run-ns "(ns lst127)\n(imports [prologos::data::list :refer [List replicate sum]])\n(eval (sum (replicate Nat (suc (suc (suc zero))) (suc (suc (suc (suc (suc zero))))))))"))
   "15N : Nat"))


;; --- range ---

(test-case "list/range-zero"
  ;; range 0 = [], length 0
  (check-equal?
   (last (run-ns "(ns lst128)\n(imports [prologos::data::list :refer [List range length]])\n(eval (length Nat (range zero)))"))
   "0N : Nat"))


(test-case "list/range-one"
  ;; range 1 = [0], length = 1
  (check-equal?
   (last (run-ns "(ns lst129)\n(imports [prologos::data::list :refer [List range length]])\n(eval (length Nat (range (suc zero))))"))
   "1N : Nat"))


(test-case "list/range-multi"
  ;; range 4 = [0,1,2,3], sum = 6
  (check-equal?
   (last (run-ns "(ns lst130)\n(imports [prologos::data::list :refer [List range sum]])\n(eval (sum (range (suc (suc (suc (suc zero)))))))"))
   "6N : Nat"))


;; --- concat ---

;; concat tests: re-enabled — List A : Type 0 now (native constructors, no Church encoding)

(test-case "list/concat-empty"
  ;; concat [] = []
  (check-equal?
   (last (run-ns "(ns lst131)\n(imports [prologos::data::list :refer [List nil cons concat length]])\n(eval (length Nat (concat Nat (nil (List Nat)))))"))
   "0N : Nat"))


(test-case "list/concat-multi"
  ;; concat [[1,2],[3]] = [1,2,3], sum = 6
  (check-equal?
   (last (run-ns "(ns lst132)\n(imports [prologos::data::list :refer [List nil cons concat sum]])\n(eval (sum (concat Nat (cons (List Nat) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))) (cons (List Nat) (cons Nat (suc (suc (suc zero))) (nil Nat)) (nil (List Nat)))))))"))
   "6N : Nat"))


;; --- concat-map ---

(test-case "list/concat-map-empty"
  ;; concat-map f [] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst133)\n(imports [prologos::data::list :refer [List nil cons singleton concat-map length]])\n(eval (length Nat (concat-map Nat Nat (fn (x : Nat) (singleton Nat x)) (nil Nat))))"))
   "0N : Nat"))


(test-case "list/concat-map-duplicate"
  ;; concat-map (\x -> [x, x]) [1, 2] = [1,1,2,2], sum = 6
  (check-equal?
   (last (run-ns "(ns lst134)\n(imports [prologos::data::list :refer [List nil cons concat-map sum]])\n(eval (sum (concat-map Nat Nat (fn (x : Nat) (cons Nat x (cons Nat x (nil Nat)))) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))))"))
   "6N : Nat"))


;; --- take ---

(test-case "list/take-zero"
  ;; take 0 [1,2,3] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst135)\n(imports [prologos::data::list :refer [List nil cons take length]])\n(eval (length Nat (take Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "0N : Nat"))
