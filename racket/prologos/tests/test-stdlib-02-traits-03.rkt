#lang racket/base

;;;
;;; Tests for prologos trait and pattern matching features:
;;;   match, Eq trait, Ord trait, elem, recursive-defn,
;;;   native constructors, implicit arguments, structural PM.
;;;
;;; Split from test-stdlib.rkt (part 2 of 3)
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


;; ========================================
;; Recursive Types — Inline data definition
;; ========================================

(test-case "data/recursive-natlist"
  ;; Monomorphic recursive type
  (check-equal?
   (last (run-ns "(ns rd1)\n(data (NatList) (nil) (cons Nat NatList))\n(check nil : NatList)"))
   "OK")
  (check-equal?
   (last (run-ns "(ns rd2)\n(data (NatList) (nil) (cons Nat NatList))\n(check (cons zero nil) : NatList)"))
   "OK"))


(test-case "data/recursive-parameterized"
  ;; Parameterized recursive type
  (check-equal?
   (last (run-ns "(ns rd3)\n(data (List (A : (Type 0))) (nil) (cons A (List A)))\n(check (nil Nat) : (List Nat))"))
   "OK")
  (check-equal?
   (last (run-ns "(ns rd4)\n(data (List (A : (Type 0))) (nil) (cons A (List A)))\n(check (cons Nat zero (nil Nat)) : (List Nat))"))
   "OK"))


(test-case "data/recursive-nested-cons"
  ;; Build a 3-element list
  (check-equal?
   (last (run-ns "(ns rd5)\n(data (List (A : (Type 0))) (nil) (cons A (List A)))\n(check (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat)))) : (List Nat))"))
   "OK"))


(test-case "data/recursive-fold-sum"
  ;; Sum [1, 2, 3] → 6 via recursive match
  (check-equal?
   (last (run-ns "(ns rd6)\n(imports [prologos::data::nat :refer [add]])\n(data (List (A : (Type 0))) (nil) (cons A (List A)))\n(def my-sum : (-> (List Nat) Nat) (fn (xs : (List Nat)) (match xs (nil -> zero) (cons a rest -> (add a (my-sum rest))))))\n(eval (my-sum (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))"))
   "6N : Nat"))


(test-case "data/recursive-match-sum"
  ;; Match on recursive type — structural (not fold): need explicit recursion
  (check-equal?
   (last (run-ns "(ns rd7)\n(imports [prologos::data::nat :refer [add]])\n(data (List (A : (Type 0))) (nil) (cons A (List A)))\n(def my-sum : (-> (List Nat) Nat) (fn (xs : (List Nat)) (match xs (nil -> zero) (cons x rest -> (add x (my-sum rest))))))\n(def my-list : (List Nat) (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))\n(eval (my-sum my-list))"))
   "6N : Nat"))


(test-case "data/recursive-match-empty"
  ;; Match on empty list — structural match, nil branch returns 3
  (check-equal?
   (last (run-ns "(ns rd8)\n(data (List (A : (Type 0))) (nil) (cons A (List A)))\n(eval (the Nat (match (nil Nat) (nil -> (suc (suc (suc zero)))) (cons x rest -> zero))))"))
   "3N : Nat"))


;; ========================================
;; List module — prologos::data::list
;; ========================================

(test-case "list/type-check"
  ;; List type and constructor types
  (check-equal?
   (last (run-ns "(ns lst1)\n(imports [prologos::data::list :refer [List nil cons]])\n(check (nil Nat) : (List Nat))"))
   "OK")
  (check-equal?
   (last (run-ns "(ns lst2)\n(imports [prologos::data::list :refer [List nil cons]])\n(check (cons Nat zero (nil Nat)) : (List Nat))"))
   "OK"))


(test-case "list/foldr-sum"
  ;; foldr add zero [1,2,3] = 6
  (check-equal?
   (last (run-ns "(ns lst3)\n(imports [prologos::data::list :refer [List nil cons foldr]])\n(imports [prologos::data::nat :refer [add]])\n(eval (foldr Nat Nat add zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat))))))"))
   "6N : Nat"))


(test-case "list/foldr-product"
  ;; foldr mult 1 [2,3] = 6
  (check-equal?
   (last (run-ns "(ns lst4)\n(imports [prologos::data::list :refer [List nil cons foldr]])\n(imports [prologos::data::nat :refer [mult]])\n(eval (foldr Nat Nat mult (suc zero) (cons Nat (suc (suc zero)) (cons Nat (suc (suc (suc zero))) (nil Nat)))))"))
   "6N : Nat"))


(test-case "list/foldr-empty"
  ;; foldr f z [] = z
  (check-equal?
   (last (run-ns "(ns lst5)\n(imports [prologos::data::list :refer [List nil cons foldr]])\n(imports [prologos::data::nat :refer [add]])\n(eval (foldr Nat Nat add (suc (suc (suc (suc (suc zero))))) (nil Nat)))"))
   "5N : Nat"))


(test-case "list/length-empty"
  (check-equal?
   (last (run-ns "(ns lst6)\n(imports [prologos::data::list :refer [List nil length]])\n(eval (length Nat (nil Nat)))"))
   "0N : Nat"))


(test-case "list/length-three"
  (check-equal?
   (last (run-ns "(ns lst7)\n(imports [prologos::data::list :refer [List nil cons length]])\n(eval (length Nat (cons Nat zero (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))))"))
   "3N : Nat"))


(test-case "list/map-suc"
  ;; map (fn x . suc x) [0, 1] then sum = 1 + 2 = 3
  (check-equal?
   (last (run-ns "(ns lst8)\n(imports [prologos::data::list :refer [List nil cons map foldr]])\n(imports [prologos::data::nat :refer [add]])\n(eval (foldr Nat Nat add zero (map Nat Nat (fn (x : Nat) (suc x)) (cons Nat zero (cons Nat (suc zero) (nil Nat))))))"))
   "3N : Nat"))


(test-case "list/map-empty"
  ;; map f [] = [], length = 0
  (check-equal?
   (last (run-ns "(ns lst9)\n(imports [prologos::data::list :refer [List nil map length]])\n(eval (length Nat (map Nat Nat (fn (x : Nat) (suc x)) (nil Nat))))"))
   "0N : Nat"))


(test-case "list/filter-keep-zeros"
  ;; filter zero? [0, 1, 0] → length 2
  (check-equal?
   (last (run-ns "(ns lst10)\n(imports [prologos::data::list :refer [List nil cons filter length]])\n(imports [prologos::data::nat :refer [zero?]])\n(eval (length Nat (filter Nat zero? (cons Nat zero (cons Nat (suc zero) (cons Nat zero (nil Nat)))))))"))
   "2N : Nat"))


(test-case "list/filter-drop-all"
  ;; filter zero? [1, 2] → length 0
  (check-equal?
   (last (run-ns "(ns lst11)\n(imports [prologos::data::list :refer [List nil cons filter length]])\n(imports [prologos::data::nat :refer [zero?]])\n(eval (length Nat (filter Nat zero? (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))))))"))
   "0N : Nat"))


(test-case "list/append"
  ;; [1,2] ++ [3] → sum = 6
  (check-equal?
   (last (run-ns "(ns lst12)\n(imports [prologos::data::list :refer [List nil cons append foldr]])\n(imports [prologos::data::nat :refer [add]])\n(eval (foldr Nat Nat add zero (append Nat (cons Nat (suc zero) (cons Nat (suc (suc zero)) (nil Nat))) (cons Nat (suc (suc (suc zero))) (nil Nat)))))"))
   "6N : Nat"))


(test-case "list/append-empty-left"
  ;; [] ++ [1] → sum = 1
  (check-equal?
   (last (run-ns "(ns lst13)\n(imports [prologos::data::list :refer [List nil cons append foldr]])\n(imports [prologos::data::nat :refer [add]])\n(eval (foldr Nat Nat add zero (append Nat (nil Nat) (cons Nat (suc zero) (nil Nat)))))"))
   "1N : Nat"))


(test-case "list/append-empty-right"
  ;; [1] ++ [] → sum = 1
  (check-equal?
   (last (run-ns "(ns lst14)\n(imports [prologos::data::list :refer [List nil cons append foldr]])\n(imports [prologos::data::nat :refer [add]])\n(eval (foldr Nat Nat add zero (append Nat (cons Nat (suc zero) (nil Nat)) (nil Nat))))"))
   "1N : Nat"))
