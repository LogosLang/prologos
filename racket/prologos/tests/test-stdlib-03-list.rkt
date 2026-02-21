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
         "../driver.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../macros.rkt")

;; Compute the lib directory path
(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

;; Helper: run prologos code with namespace system active
(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
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
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
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
;; prologos.data.list — Sprint 1.1 New Functions
;; ========================================

;; --- reduce (left fold) ---

(test-case "list/reduce-empty"
  ;; reduce add 0 [] = 0
  (check-equal?
   (last (run-ns "(ns lst100)\n(require [prologos.data.list :refer [List nil reduce]])\n(require [prologos.data.nat :refer [add]])\n(eval (reduce Nat Nat add zero (nil Nat)))"))
   "0N : Nat"))

(test-case "list/reduce-single"
  ;; reduce add 0 [5] = 5
  (check-equal?
   (last (run-ns "(ns lst101)\n(require [prologos.data.list :refer [List nil cons reduce]])\n(require [prologos.data.nat :refer [add]])\n(eval (reduce Nat Nat add zero (cons Nat (suc (suc (suc (suc (suc zero))))) (nil Nat))))"))
   "5N : Nat"))

(test-case "list/reduce-multi"
  ;; reduce add 0 [1,2,3] = 6
  (check-equal?
   (last (run-ns "(ns lst102)\n(require [prologos.data.list :refer [List nil cons reduce]])\n(require [prologos.data.nat :refer [add]])\n(eval (reduce Nat Nat add zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))"))
   "6N : Nat"))

;; --- tail ---

;; NOTE: tail tests re-enabled — Option (List A) is well-typed now (List A : Type 0)

(test-case "list/tail-empty"
  (check-equal?
   (last (run-ns "(ns lst103)\n(require [prologos.data.list :refer [List nil tail length]])\n(require [prologos.data.option :refer [unwrap-or]])\n(eval (length Nat (unwrap-or (List Nat) (nil Nat) (tail Nat (nil Nat)))))"))
   "0N : Nat"))

(test-case "list/tail-nonempty"
  (check-equal?
   (last (run-ns "(ns lst104)\n(require [prologos.data.list :refer [List nil cons tail length]])\n(require [prologos.data.option :refer [unwrap-or]])\n(eval (length Nat (unwrap-or (List Nat) (nil Nat) (tail Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))))"))
   "2N : Nat"))

;; --- reverse ---

(test-case "list/reverse-empty"
  ;; reverse [] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst105)\n(require [prologos.data.list :refer [List nil reverse length]])\n(eval (length Nat (reverse Nat (nil Nat))))"))
   "0N : Nat"))

(test-case "list/reverse-single"
  ;; reverse [5] = [5], head = 5
  (check-equal?
   (last (run-ns "(ns lst106)\n(require [prologos.data.list :refer [List nil cons reverse head]])\n(eval (head Nat zero (reverse Nat (cons Nat (suc (suc (suc (suc (suc zero))))) (nil Nat)))))"))
   "5N : Nat"))

(test-case "list/reverse-multi"
  ;; reverse [1,2,3], head = 3
  (check-equal?
   (last (run-ns "(ns lst107)\n(require [prologos.data.list :refer [List nil cons reverse head]])\n(eval (head Nat zero (reverse Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "3N : Nat"))

;; --- sum ---

(test-case "list/sum-empty"
  ;; sum [] = 0
  (check-equal?
   (last (run-ns "(ns lst108)\n(require [prologos.data.list :refer [List nil sum]])\n(eval (sum (nil Nat)))"))
   "0N : Nat"))

(test-case "list/sum-multi"
  ;; sum [1,2,3] = 6
  (check-equal?
   (last (run-ns "(ns lst109)\n(require [prologos.data.list :refer [List nil cons sum]])\n(eval (sum (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))"))
   "6N : Nat"))

;; --- product ---

(test-case "list/product-empty"
  ;; product [] = 1
  (check-equal?
   (last (run-ns "(ns lst110)\n(require [prologos.data.list :refer [List nil product]])\n(eval (product (nil Nat)))"))
   "1N : Nat"))

(test-case "list/product-multi"
  ;; product [2,3] = 6
  (check-equal?
   (last (run-ns "(ns lst111)\n(require [prologos.data.list :refer [List nil cons product]])\n(eval (product (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))"))
   "6N : Nat"))

;; --- any? ---

(test-case "list/any?-empty"
  ;; any? zero? [] = false
  (check-equal?
   (last (run-ns "(ns lst112)\n(require [prologos.data.list :refer [List nil any?]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (any? Nat zero? (nil Nat)))"))
   "false : Bool"))

(test-case "list/any?-found"
  ;; any? zero? [1, 0, 2] = true
  (check-equal?
   (last (run-ns "(ns lst113)\n(require [prologos.data.list :refer [List nil cons any?]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (any? Nat zero? (cons Nat (suc zero) (cons Nat zero (cons Nat (suc (suc zero)) (nil Nat))))))"))
   "true : Bool"))

(test-case "list/any?-not-found"
  ;; any? zero? [1, 2] = false
  (check-equal?
   (last (run-ns "(ns lst114)\n(require [prologos.data.list :refer [List nil cons any?]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (any? Nat zero? (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))"))
   "false : Bool"))

;; --- all? ---

(test-case "list/all?-empty"
  ;; all? zero? [] = true (vacuously)
  (check-equal?
   (last (run-ns "(ns lst115)\n(require [prologos.data.list :refer [List nil all?]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (all? Nat zero? (nil Nat)))"))
   "true : Bool"))

(test-case "list/all?-all-pass"
  ;; all? zero? [0, 0] = true
  (check-equal?
   (last (run-ns "(ns lst116)\n(require [prologos.data.list :refer [List nil cons all?]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (all? Nat zero? (cons Nat zero (cons Nat zero (nil Nat)))))"))
   "true : Bool"))

(test-case "list/all?-some-fail"
  ;; all? zero? [0, 1] = false
  (check-equal?
   (last (run-ns "(ns lst117)\n(require [prologos.data.list :refer [List nil cons all?]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (all? Nat zero? (cons Nat zero (cons Nat (suc zero) (nil Nat)))))"))
   "false : Bool"))

;; --- find ---

(test-case "list/find-empty"
  ;; find zero? [] = none, unwrap-or to 5
  (check-equal?
   (last (run-ns "(ns lst118)\n(require [prologos.data.list :refer [List nil find]])\n(require [prologos.data.nat :refer [zero?]])\n(require [prologos.data.option :refer [unwrap-or]])\n(eval (unwrap-or Nat (suc (suc (suc (suc (suc zero))))) (find Nat zero? (nil Nat))))"))
   "5N : Nat"))

(test-case "list/find-found"
  ;; find zero? [1, 0, 2] = some 0
  (check-equal?
   (last (run-ns "(ns lst119)\n(require [prologos.data.list :refer [List nil cons find]])\n(require [prologos.data.nat :refer [zero?]])\n(require [prologos.data.option :refer [unwrap-or]])\n(eval (unwrap-or Nat (suc (suc (suc (suc (suc zero))))) (find Nat zero? (cons Nat (suc zero) (cons Nat zero (cons Nat (suc (suc zero)) (nil Nat)))))))"))
   "0N : Nat"))

(test-case "list/find-not-found"
  ;; find zero? [1, 2] = none, unwrap-or to 5
  (check-equal?
   (last (run-ns "(ns lst120)\n(require [prologos.data.list :refer [List nil cons find]])\n(require [prologos.data.nat :refer [zero?]])\n(require [prologos.data.option :refer [unwrap-or]])\n(eval (unwrap-or Nat (suc (suc (suc (suc (suc zero))))) (find Nat zero? (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))))"))
   "5N : Nat"))

;; --- nth ---

(test-case "list/nth-valid"
  ;; nth 1 [3, 5, 7] = some 5
  (check-equal?
   (last (run-ns "(ns lst121)\n(require [prologos.data.list :refer [List nil cons nth]])\n(require [prologos.data.option :refer [unwrap-or]])\n(eval (unwrap-or Nat zero (nth Nat (suc zero) (cons Nat (suc (suc (suc zero))) (cons Nat (suc (suc (suc (suc (suc zero))))) (cons Nat (suc (suc (suc (suc (suc (suc (suc zero))))))) (nil Nat)))))))"))
   "5N : Nat"))

(test-case "list/nth-out-of-bounds"
  ;; nth 5 [1,2] = none, unwrap-or to 0
  (check-equal?
   (last (run-ns "(ns lst122)\n(require [prologos.data.list :refer [List nil cons nth]])\n(require [prologos.data.option :refer [unwrap-or]])\n(eval (unwrap-or Nat zero (nth Nat (suc (suc (suc (suc (suc zero))))) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))))"))
   "0N : Nat"))

(test-case "list/nth-empty"
  ;; nth 0 [] = none, unwrap-or to 0
  (check-equal?
   (last (run-ns "(ns lst123)\n(require [prologos.data.list :refer [List nil nth]])\n(require [prologos.data.option :refer [unwrap-or]])\n(eval (unwrap-or Nat zero (nth Nat zero (nil Nat))))"))
   "0N : Nat"))

;; --- last (Prologos function) ---

(test-case "list/last-empty"
  ;; last [] = none, unwrap-or to 0
  (check-equal?
   (last (run-ns "(ns lst124)\n(require [prologos.data.list :refer [List nil last]])\n(require [prologos.data.option :refer [unwrap-or]])\n(eval (unwrap-or Nat zero (last Nat (nil Nat))))"))
   "0N : Nat"))

(test-case "list/last-nonempty"
  ;; last [1,2,3] = some 3
  (check-equal?
   (last (run-ns "(ns lst125)\n(require [prologos.data.list :refer [List nil cons last]])\n(require [prologos.data.option :refer [unwrap-or]])\n(eval (unwrap-or Nat zero (last Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "3N : Nat"))

;; --- replicate ---

(test-case "list/replicate-zero"
  ;; replicate 0 x = [], length 0
  (check-equal?
   (last (run-ns "(ns lst126)\n(require [prologos.data.list :refer [List replicate length]])\n(eval (length Nat (replicate Nat zero (suc (suc (suc zero))))))"))
   "0N : Nat"))

(test-case "list/replicate-positive"
  ;; replicate 3 5 = [5,5,5], sum = 15
  (check-equal?
   (last (run-ns "(ns lst127)\n(require [prologos.data.list :refer [List replicate sum]])\n(eval (sum (replicate Nat (suc (suc (suc zero))) (suc (suc (suc (suc (suc zero))))))))"))
   "15N : Nat"))

;; --- range ---

(test-case "list/range-zero"
  ;; range 0 = [], length 0
  (check-equal?
   (last (run-ns "(ns lst128)\n(require [prologos.data.list :refer [List range length]])\n(eval (length Nat (range zero)))"))
   "0N : Nat"))

(test-case "list/range-one"
  ;; range 1 = [0], length = 1
  (check-equal?
   (last (run-ns "(ns lst129)\n(require [prologos.data.list :refer [List range length]])\n(eval (length Nat (range (suc zero))))"))
   "1N : Nat"))

(test-case "list/range-multi"
  ;; range 4 = [0,1,2,3], sum = 6
  (check-equal?
   (last (run-ns "(ns lst130)\n(require [prologos.data.list :refer [List range sum]])\n(eval (sum (range (suc (suc (suc (suc zero)))))))"))
   "6N : Nat"))

;; --- concat ---

;; concat tests: re-enabled — List A : Type 0 now (native constructors, no Church encoding)

(test-case "list/concat-empty"
  ;; concat [] = []
  (check-equal?
   (last (run-ns "(ns lst131)\n(require [prologos.data.list :refer [List nil cons concat length]])\n(eval (length Nat (concat Nat (nil (List Nat)))))"))
   "0N : Nat"))

(test-case "list/concat-multi"
  ;; concat [[1,2],[3]] = [1,2,3], sum = 6
  (check-equal?
   (last (run-ns "(ns lst132)\n(require [prologos.data.list :refer [List nil cons concat sum]])\n(eval (sum (concat Nat (cons (List Nat) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))) (cons (List Nat) (cons Nat (suc (suc (suc zero))) (nil Nat)) (nil (List Nat)))))))"))
   "6N : Nat"))

;; --- concat-map ---

(test-case "list/concat-map-empty"
  ;; concat-map f [] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst133)\n(require [prologos.data.list :refer [List nil cons singleton concat-map length]])\n(eval (length Nat (concat-map Nat Nat (fn (x : Nat) (singleton Nat x)) (nil Nat))))"))
   "0N : Nat"))

(test-case "list/concat-map-duplicate"
  ;; concat-map (\x -> [x, x]) [1, 2] = [1,1,2,2], sum = 6
  (check-equal?
   (last (run-ns "(ns lst134)\n(require [prologos.data.list :refer [List nil cons concat-map sum]])\n(eval (sum (concat-map Nat Nat (fn (x : Nat) (cons Nat x (cons Nat x (nil Nat)))) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))))"))
   "6N : Nat"))

;; --- take ---

(test-case "list/take-zero"
  ;; take 0 [1,2,3] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst135)\n(require [prologos.data.list :refer [List nil cons take length]])\n(eval (length Nat (take Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "0N : Nat"))

(test-case "list/take-within"
  ;; take 2 [1,2,3] = [1,2], sum = 3
  (check-equal?
   (last (run-ns "(ns lst136)\n(require [prologos.data.list :refer [List nil cons take sum]])\n(eval (sum (take Nat (suc (suc zero)) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "3N : Nat"))

(test-case "list/take-exceeds"
  ;; take 5 [1,2] = [1,2], sum = 3
  (check-equal?
   (last (run-ns "(ns lst137)\n(require [prologos.data.list :refer [List nil cons take sum]])\n(eval (sum (take Nat (suc (suc (suc (suc (suc zero))))) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))))"))
   "3N : Nat"))

;; --- drop ---

(test-case "list/drop-zero"
  ;; drop 0 [1,2,3] = [1,2,3], sum = 6
  (check-equal?
   (last (run-ns "(ns lst138)\n(require [prologos.data.list :refer [List nil cons drop sum]])\n(eval (sum (drop Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "6N : Nat"))

(test-case "list/drop-within"
  ;; drop 1 [1,2,3] = [2,3], sum = 5
  (check-equal?
   (last (run-ns "(ns lst139)\n(require [prologos.data.list :refer [List nil cons drop sum]])\n(eval (sum (drop Nat (suc zero) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "5N : Nat"))

(test-case "list/drop-exceeds"
  ;; drop 5 [1,2] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst140)\n(require [prologos.data.list :refer [List nil cons drop length]])\n(eval (length Nat (drop Nat (suc (suc (suc (suc (suc zero))))) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))))"))
   "0N : Nat"))

;; --- split-at ---

(test-case "list/split-at-first"
  ;; split-at 2 [1,2,3], first part sum = 3
  (check-equal?
   (last (run-ns "(ns lst141)\n(require [prologos.data.list :refer [List nil cons split-at sum]])\n(eval (sum (first (split-at Nat (suc (suc zero)) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))))"))
   "3N : Nat"))

(test-case "list/split-at-second"
  ;; split-at 2 [1,2,3], second part sum = 3
  (check-equal?
   (last (run-ns "(ns lst142)\n(require [prologos.data.list :refer [List nil cons split-at sum]])\n(eval (sum (second (split-at Nat (suc (suc zero)) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))))"))
   "3N : Nat"))

;; --- take-while ---

(test-case "list/take-while-all-pass"
  ;; take-while zero? [0,0,0] = [0,0,0], length 3
  (check-equal?
   (last (run-ns "(ns lst143)\n(require [prologos.data.list :refer [List nil cons take-while length]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (length Nat (take-while Nat zero? (cons Nat zero (cons Nat zero (cons Nat zero (nil Nat)))))))"))
   "3N : Nat"))

(test-case "list/take-while-some-pass"
  ;; take-while zero? [0, 0, 1, 0] = [0, 0], length 2
  (check-equal?
   (last (run-ns "(ns lst144)\n(require [prologos.data.list :refer [List nil cons take-while length]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (length Nat (take-while Nat zero? (cons Nat zero (cons Nat zero (cons Nat (suc zero) (cons Nat zero (nil Nat))))))))"))
   "2N : Nat"))

(test-case "list/take-while-none-pass"
  ;; take-while zero? [1, 2] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst145)\n(require [prologos.data.list :refer [List nil cons take-while length]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (length Nat (take-while Nat zero? (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))))"))
   "0N : Nat"))

;; --- drop-while ---

(test-case "list/drop-while-all-pass"
  ;; drop-while zero? [0,0,0] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst146)\n(require [prologos.data.list :refer [List nil cons drop-while length]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (length Nat (drop-while Nat zero? (cons Nat zero (cons Nat zero (cons Nat zero (nil Nat)))))))"))
   "0N : Nat"))

(test-case "list/drop-while-some-pass"
  ;; drop-while zero? [0, 0, 1, 2] = [1, 2], sum = 3
  (check-equal?
   (last (run-ns "(ns lst147)\n(require [prologos.data.list :refer [List nil cons drop-while sum]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (sum (drop-while Nat zero? (cons Nat zero (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))))))"))
   "3N : Nat"))

(test-case "list/drop-while-none-pass"
  ;; drop-while zero? [1, 2, 3] = [1, 2, 3], sum = 6
  (check-equal?
   (last (run-ns "(ns lst148)\n(require [prologos.data.list :refer [List nil cons drop-while sum]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (sum (drop-while Nat zero? (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "6N : Nat"))

;; --- partition ---

(test-case "list/partition-first"
  ;; partition zero? [0, 1, 0, 2], first = zeros, length 2
  (check-equal?
   (last (run-ns "(ns lst149)\n(require [prologos.data.list :refer [List nil cons partition length]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (length Nat (first (partition Nat zero? (cons Nat zero (cons Nat (suc zero) (cons Nat zero (cons Nat (suc (suc zero)) (nil Nat)))))))))"))
   "2N : Nat"))

(test-case "list/partition-second"
  ;; partition zero? [0, 1, 0, 2], second = non-zeros, sum = 3
  (check-equal?
   (last (run-ns "(ns lst150)\n(require [prologos.data.list :refer [List nil cons partition sum]])\n(require [prologos.data.nat :refer [zero?]])\n(eval (sum (second (partition Nat zero? (cons Nat zero (cons Nat (suc zero) (cons Nat zero (cons Nat (suc (suc zero)) (nil Nat)))))))))"))
   "3N : Nat"))

;; --- zip-with ---

(test-case "list/zip-with-empty"
  ;; zip-with add [] [] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst151)\n(require [prologos.data.list :refer [List nil zip-with length]])\n(require [prologos.data.nat :refer [add]])\n(eval (length Nat (zip-with Nat Nat Nat add (nil Nat) (nil Nat))))"))
   "0N : Nat"))

(test-case "list/zip-with-same-length"
  ;; zip-with add [1,2] [3,4] = [4,6], sum = 10
  (check-equal?
   (last (run-ns "(ns lst152)\n(require [prologos.data.list :refer [List nil cons zip-with sum]])\n(require [prologos.data.nat :refer [add]])\n(eval (sum (zip-with Nat Nat Nat add (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))) (cons Nat (suc (suc (suc zero))) (cons Nat (suc (suc (suc (suc zero)))) (nil Nat))))))"))
   "10N : Nat"))

(test-case "list/zip-with-diff-length"
  ;; zip-with add [1,2,3] [10] = [11], sum = 11
  (check-equal?
   (last (run-ns "(ns lst153)\n(require [prologos.data.list :refer [List nil cons zip-with sum]])\n(require [prologos.data.nat :refer [add]])\n(eval (sum (zip-with Nat Nat Nat add (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))) (cons Nat (suc (suc (suc (suc (suc (suc (suc (suc (suc (suc zero)))))))))) (nil Nat)))))"))
   "11N : Nat"))

;; --- zip ---

(test-case "list/zip-length"
  ;; zip [1,2] [3,4], length = 2
  (check-equal?
   (last (run-ns "(ns lst154)\n(require [prologos.data.list :refer [List nil cons zip length]])\n(eval (length (Sigma [_ <Nat>] Nat) (zip Nat Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))) (cons Nat (suc (suc (suc zero))) (cons Nat (suc (suc (suc (suc zero)))) (nil Nat))))))"))
   "2N : Nat"))

(test-case "list/zip-head-first"
  ;; zip [1,2] [3,4], first element of head pair = 1
  (check-equal?
   (last (run-ns "(ns lst155)\n(require [prologos.data.list :refer [List nil cons zip head]])\n(eval (first (head (Sigma [_ <Nat>] Nat) (pair zero zero) (zip Nat Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))) (cons Nat (suc (suc (suc zero))) (cons Nat (suc (suc (suc (suc zero)))) (nil Nat)))))))"))
   "1N : Nat"))

;; --- unzip ---

(test-case "list/unzip-firsts"
  ;; unzip [(1,2), (3,4)], first list sum = 4
  (check-equal?
   (last (run-ns "(ns lst156)\n(require [prologos.data.list :refer [List nil cons unzip sum]])\n(eval (sum (first (unzip Nat Nat (cons (Sigma [_ <Nat>] Nat) (pair (suc zero) (suc (suc zero))) (cons (Sigma [_ <Nat>] Nat) (pair (suc (suc (suc zero))) (suc (suc (suc (suc zero))))) (nil (Sigma [_ <Nat>] Nat))))))))"))
   "4N : Nat"))

(test-case "list/unzip-seconds"
  ;; unzip [(1,2), (3,4)], second list sum = 6
  (check-equal?
   (last (run-ns "(ns lst157)\n(require [prologos.data.list :refer [List nil cons unzip sum]])\n(eval (sum (second (unzip Nat Nat (cons (Sigma [_ <Nat>] Nat) (pair (suc zero) (suc (suc zero))) (cons (Sigma [_ <Nat>] Nat) (pair (suc (suc (suc zero))) (suc (suc (suc (suc zero))))) (nil (Sigma [_ <Nat>] Nat))))))))"))
   "6N : Nat"))

;; --- intersperse ---

(test-case "list/intersperse-empty"
  ;; intersperse 0 [] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst158)\n(require [prologos.data.list :refer [List nil intersperse length]])\n(eval (length Nat (intersperse Nat zero (nil Nat))))"))
   "0N : Nat"))

(test-case "list/intersperse-single"
  ;; intersperse 0 [1] = [1], length 1
  (check-equal?
   (last (run-ns "(ns lst159)\n(require [prologos.data.list :refer [List nil cons intersperse length]])\n(eval (length Nat (intersperse Nat zero (cons Nat (suc zero) (nil Nat)))))"))
   "1N : Nat"))

(test-case "list/intersperse-multi"
  ;; intersperse 0 [1,2,3] = [1,0,2,0,3], length = 5
  (check-equal?
   (last (run-ns "(ns lst160)\n(require [prologos.data.list :refer [List nil cons intersperse length]])\n(eval (length Nat (intersperse Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "5N : Nat"))

;; --- halve ---

(test-case "list/halve-empty"
  ;; halve [] = ([], []), first length 0
  (check-equal?
   (last (run-ns "(ns lst161)\n(require [prologos.data.list :refer [List nil halve length]])\n(eval (length Nat (first (halve Nat (nil Nat)))))"))
   "0N : Nat"))

(test-case "list/halve-odd"
  ;; halve [1,2,3] — alternating: first = [1,3] (length 2)
  (check-equal?
   (last (run-ns "(ns lst162)\n(require [prologos.data.list :refer [List nil cons halve length]])\n(eval (length Nat (first (halve Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))))"))
   "2N : Nat"))

(test-case "list/halve-even"
  ;; halve [1,2,3,4] — second = [2,4] (length 2)
  (check-equal?
   (last (run-ns "(ns lst163)\n(require [prologos.data.list :refer [List nil cons halve length]])\n(eval (length Nat (second (halve Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (cons Nat (suc (suc (suc (suc zero)))) (nil Nat)))))))))"))
   "2N : Nat"))

;; --- merge ---

(test-case "list/merge-both-empty"
  ;; merge le? [] [] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst164)\n(require [prologos.data.list :refer [List nil merge length]])\n(require [prologos.data.nat :refer [le?]])\n(eval (length Nat (merge Nat le? (nil Nat) (nil Nat))))"))
   "0N : Nat"))

(test-case "list/merge-sorted"
  ;; merge le? [1,3] [2,4] = [1,2,3,4], sum = 10
  (check-equal?
   (last (run-ns "(ns lst165)\n(require [prologos.data.list :refer [List nil cons merge sum]])\n(require [prologos.data.nat :refer [le?]])\n(eval (sum (merge Nat le? (cons Nat (suc zero) (cons Nat (suc (suc (suc zero))) (nil Nat))) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc (suc zero)))) (nil Nat))))))"))
   "10N : Nat"))

;; --- sort ---

(test-case "list/sort-empty"
  ;; sort le? [] = [], length 0
  (check-equal?
   (last (run-ns "(ns lst166)\n(require [prologos.data.list :refer [List nil sort length]])\n(require [prologos.data.nat :refer [le?]])\n(eval (length Nat (sort Nat le? (nil Nat))))"))
   "0N : Nat"))

(test-case "list/sort-single"
  ;; sort le? [3] = [3], sum = 3
  (check-equal?
   (last (run-ns "(ns lst167)\n(require [prologos.data.list :refer [List nil cons sort sum]])\n(require [prologos.data.nat :refer [le?]])\n(eval (sum (sort Nat le? (cons Nat (suc (suc (suc zero))) (nil Nat)))))"))
   "3N : Nat"))

(test-case "list/sort-already-sorted"
  ;; sort le? [1,2,3] = [1,2,3], head = 1
  (check-equal?
   (last (run-ns "(ns lst168)\n(require [prologos.data.list :refer [List nil cons sort head]])\n(require [prologos.data.nat :refer [le?]])\n(eval (head Nat zero (sort Nat le? (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "1N : Nat"))

(test-case "list/sort-unsorted"
  ;; sort le? [3,1,2] = [1,2,3], head = 1
  (check-equal?
   (last (run-ns "(ns lst169)\n(require [prologos.data.list :refer [List nil cons sort head]])\n(require [prologos.data.nat :refer [le?]])\n(eval (head Nat zero (sort Nat le? (cons Nat (suc (suc (suc zero))) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))))"))
   "1N : Nat"))

;; --- Additional verification tests ---

(test-case "list/reverse-sum-preserved"
  ;; reverse preserves sum: sum (reverse [1,2,3]) = 6
  (check-equal?
   (last (run-ns "(ns lst170)\n(require [prologos.data.list :refer [List nil cons reverse sum]])\n(eval (sum (reverse Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "6N : Nat"))

(test-case "list/sort-unsorted-sum"
  ;; sort preserves sum: sum (sort [3,1,2]) = 6
  (check-equal?
   (last (run-ns "(ns lst171)\n(require [prologos.data.list :refer [List nil cons sort sum]])\n(require [prologos.data.nat :refer [le?]])\n(eval (sum (sort Nat le? (cons Nat (suc (suc (suc zero))) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))))))"))
   "6N : Nat"))

(test-case "list/intersperse-sum"
  ;; intersperse 10 [1,2,3] = [1,10,2,10,3], sum = 26
  (check-equal?
   (last (run-ns "(ns lst172)\n(require [prologos.data.list :refer [List nil cons intersperse sum]])\n(eval (sum (intersperse Nat (suc (suc (suc (suc (suc (suc (suc (suc (suc (suc zero)))))))))) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))))"))
   "26N : Nat"))

(test-case "list/replicate-length"
  ;; replicate 4 0 = [0,0,0,0], length = 4
  (check-equal?
   (last (run-ns "(ns lst173)\n(require [prologos.data.list :refer [List replicate length]])\n(eval (length Nat (replicate Nat (suc (suc (suc (suc zero)))) zero)))"))
   "4N : Nat"))

(test-case "list/range-length"
  ;; range 5 has length 5
  (check-equal?
   (last (run-ns "(ns lst174)\n(require [prologos.data.list :refer [List range length]])\n(eval (length Nat (range (suc (suc (suc (suc (suc zero))))))))"))
   "5N : Nat"))

(test-case "list/range-head"
  ;; range 3 = [0,1,2], head = 0
  (check-equal?
   (last (run-ns "(ns lst175)\n(require [prologos.data.list :refer [List range head]])\n(eval (head Nat (suc (suc (suc zero))) (range (suc (suc (suc zero))))))"))
   "0N : Nat"))

;; ========================================
;; Public/Private: auto-export and defn-/def-/data-
;; ========================================

(test-case "auto-export: defn without provide auto-exports"
  ;; defn auto-exports. Module B can refer to the name.
  (check-equal?
   (last (run-ns-pair
     "(ns test.auto-export.mod-a)\n(defn add-one : (-> Nat Nat) [n] (suc n))"
     "(ns test.auto-export.mod-b)\n(require [test.auto-export.mod-a :refer [add-one]])\n(eval (add-one (suc zero)))"))
   "2N : Nat"))

(test-case "auto-export: def without provide auto-exports"
  (check-equal?
   (last (run-ns-pair
     "(ns test.auto-export.def-a)\n(def my-two : Nat (suc (suc zero)))"
     "(ns test.auto-export.def-b)\n(require [test.auto-export.def-a :refer [my-two]])\n(eval my-two)"))
   "2N : Nat"))

(test-case "auto-export: defn- is private (not exported)"
  (check-exn
   #rx"does not export"
   (lambda ()
     (run-ns-pair
       "(ns test.priv.defn-a)\n(defn- helper : (-> Nat Nat) [n] (suc n))"
       "(ns test.priv.defn-b)\n(require [test.priv.defn-a :refer [helper]])\n(eval (helper zero))"))))

(test-case "auto-export: def- is private (not exported)"
  (check-exn
   #rx"does not export"
   (lambda ()
     (run-ns-pair
       "(ns test.priv.def-a)\n(def- secret : Nat (suc zero))"
       "(ns test.priv.def-b)\n(require [test.priv.def-a :refer [secret]])\n(eval secret)"))))

(test-case "auto-export: data auto-exports type and constructors"
  ;; data without provide → type and constructors are auto-exported.
  (check-not-exn
   (lambda ()
     (run-ns-pair
       "(ns test.auto-export.data-a)\n(data Color red green blue)"
       "(ns test.auto-export.data-b)\n(require [test.auto-export.data-a :refer [Color red green blue]])\n(check red : Color)"))))

(test-case "auto-export: data- is private (type and constructors not exported)"
  (check-exn
   #rx"does not export"
   (lambda ()
     (run-ns-pair
       "(ns test.priv.data-a)\n(data- InternalType foo bar)"
       "(ns test.priv.data-b)\n(require [test.priv.data-a :refer [InternalType]])\n(eval foo)"))))

(test-case "auto-export: explicit provide overrides auto-exports"
  ;; When provide is present, only provided names are accessible.
  (check-exn
   #rx"does not export"
   (lambda ()
     (run-ns-pair
       "(ns test.override.mod-a)\n(provide pub-fn)\n(defn pub-fn : (-> Nat Nat) [n] (suc n))\n(defn hidden-fn : (-> Nat Nat) [n] (suc (suc n)))"
       "(ns test.override.mod-b)\n(require [test.override.mod-a :refer [hidden-fn]])\n(eval (hidden-fn zero))"))))

(test-case "auto-export: defn- usable locally within the same module"
  ;; A private defn- is usable within its own module (single module test).
  (check-equal?
   (last (run-ns
     "(ns test.priv.local)\n(defn- helper : (-> Nat Nat) [n] (suc n))\n(eval (helper (suc zero)))"))
   "2N : Nat"))

(test-case "auto-export: deftype auto-exports"
  ;; deftype auto-exports. Verify the auto-exports list directly.
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    (process-string "(ns test.auto-export.deftype)\n(deftype Endo (-> Nat Nat))")
    (define ctx (current-ns-context))
    (check-not-false ctx)
    (check-not-false (member 'Endo (ns-context-auto-exports ctx))
                     "deftype Endo in auto-exports")))

(test-case "auto-export: library modules work without provide"
  ;; Verify that real library modules (which had provide removed) still export correctly.
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)])
    (install-module-loader!)
    (define mod (load-module 'prologos.data.nat #f))
    (define exports (module-info-exports mod))
    ;; All previously-provided names should still be exported via auto-export
    (check-not-false (member 'add exports) "auto-exports add")
    (check-not-false (member 'mult exports) "auto-exports mult")
    (check-not-false (member 'double exports) "auto-exports double")
    (check-not-false (member 'zero? exports) "auto-exports zero?")))

(test-case "auto-export: private defn- not in auto-exports list"
  ;; Verify that defn- doesn't add to auto-exports.
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)])
    (install-module-loader!)
    (process-string "(ns test.priv.check)\n(defn pub-fn : (-> Nat Nat) [n] (suc n))\n(defn- priv-fn : (-> Nat Nat) [n] (suc (suc n)))")
    (define ctx (current-ns-context))
    (check-not-false ctx "ns-context should be set")
    (define auto-exp (ns-context-auto-exports ctx))
    (check-not-false (member 'pub-fn auto-exp) "pub-fn in auto-exports")
    (check-false (member 'priv-fn auto-exp) "priv-fn NOT in auto-exports")))
