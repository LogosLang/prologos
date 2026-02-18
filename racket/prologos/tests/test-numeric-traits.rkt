#lang racket/base

;;;
;;; Tests for Phase 3d: Numeric Traits
;;; Add, Sub, Mul, Div, Neg, Abs, Eq, Ord, FromInt, FromRat
;;; Num and Fractional bundles
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../trait-resolution.rkt")

;; ========================================
;; Helpers
;; ========================================

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

(define (run-ns s)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    (process-string s)))

(define (run-ns-last s) (last (run-ns s)))

(define (run-ns-strings s)
  (filter string? (run-ns s)))

;; ========================================
;; A. Direct dict calling — arithmetic traits
;; ========================================

(test-case "add/nat-direct"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.core.add-trait :refer [Add Add-add]])\n"
    "(eval (Add-add Nat Nat--Add--dict (inc zero) (inc (inc zero))))\n")))
  (check-true (string-contains? (format "~a" r) "3")))

(test-case "add/int-direct"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.core.add-trait :refer [Add Add-add]])\n"
    "(require [prologos.core.add-instances :refer []])\n"
    "(eval (Add-add Int Int--Add--dict (int 3) (int 4)))\n")))
  (check-true (string-contains? (format "~a" r) "7 : Int")))

(test-case "add/rat-direct"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.core.add-trait :refer [Add Add-add]])\n"
    "(require [prologos.core.add-instances :refer []])\n"
    "(eval (Add-add Rat Rat--Add--dict (rat 1/3) (rat 2/3)))\n")))
  (check-true (string-contains? (format "~a" r) "1 : Rat")))

(test-case "sub/nat-direct"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.core.sub-trait :refer [Sub Sub-sub]])\n"
    "(eval (Sub-sub Nat Nat--Sub--dict (inc (inc (inc zero))) (inc zero)))\n")))
  (check-true (string-contains? (format "~a" r) "2")))

(test-case "sub/int-direct"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.core.sub-trait :refer [Sub Sub-sub]])\n"
    "(require [prologos.core.sub-instances :refer []])\n"
    "(eval (Sub-sub Int Int--Sub--dict (int 10) (int 3)))\n")))
  (check-true (string-contains? (format "~a" r) "7 : Int")))

(test-case "mul/nat-direct"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.core.mul-trait :refer [Mul Mul-mul]])\n"
    "(eval (Mul-mul Nat Nat--Mul--dict (inc (inc zero)) (inc (inc (inc zero)))))\n")))
  (check-true (string-contains? (format "~a" r) "6")))

(test-case "mul/rat-direct"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.core.mul-trait :refer [Mul Mul-mul]])\n"
    "(require [prologos.core.mul-instances :refer []])\n"
    "(eval (Mul-mul Rat Rat--Mul--dict (rat 3/7) (rat 2/3)))\n")))
  (check-true (string-contains? (format "~a" r) "2/7 : Rat")))

(test-case "div/int-direct"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.core.div-trait :refer [Div Div-div]])\n"
    "(eval (Div-div Int Int--Div--dict (int 10) (int 3)))\n")))
  (check-true (string-contains? (format "~a" r) "3 : Int")))

(test-case "div/rat-direct"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.core.div-trait :refer [Div Div-div]])\n"
    "(require [prologos.core.div-instances :refer []])\n"
    "(eval (Div-div Rat Rat--Div--dict (rat 5/3) (rat 2/3)))\n")))
  (check-true (string-contains? (format "~a" r) "5/2 : Rat")))

(test-case "neg/int-direct"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.core.neg-trait :refer [Neg Neg-neg]])\n"
    "(eval (Neg-neg Int Int--Neg--dict (int 5)))\n")))
  (check-true (string-contains? (format "~a" r) "-5 : Int")))

(test-case "neg/rat-direct"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.core.neg-trait :refer [Neg Neg-neg]])\n"
    "(require [prologos.core.neg-instances :refer []])\n"
    "(eval (Neg-neg Rat Rat--Neg--dict (rat 5/3)))\n")))
  (check-true (string-contains? (format "~a" r) "-5/3 : Rat")))

(test-case "abs/int-direct"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.core.abs-trait :refer [Abs Abs-abs]])\n"
    "(eval (Abs-abs Int Int--Abs--dict (int -7)))\n")))
  (check-true (string-contains? (format "~a" r) "7 : Int")))

(test-case "abs/rat-direct"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.core.abs-trait :refer [Abs Abs-abs]])\n"
    "(require [prologos.core.abs-instances :refer []])\n"
    "(eval (Abs-abs Rat Rat--Abs--dict (rat -7/3)))\n")))
  (check-true (string-contains? (format "~a" r) "7/3 : Rat")))

;; ========================================
;; B. Where-clause auto-resolution
;; ========================================

(test-case "where/add-int-auto-resolution"
  (define results (run-ns-strings (string-append
    "(ns t)\n"
    "(require [prologos.core.add-trait :refer [Add Add-add]])\n"
    "(require [prologos.core.add-instances :refer []])\n"
    "(spec generic-add A A -> A where (Add A))\n"
    "(defn generic-add [x y] where (Add A)\n"
    "  (Add-add A $Add-A x y))\n"
    "(eval (generic-add (int 10) (int 20)))\n")))
  (check-true (string-contains? (last results) "30 : Int")))

(test-case "where/add-rat-auto-resolution"
  (define results (run-ns-strings (string-append
    "(ns t)\n"
    "(require [prologos.core.add-trait :refer [Add Add-add]])\n"
    "(require [prologos.core.add-instances :refer []])\n"
    "(spec generic-add A A -> A where (Add A))\n"
    "(defn generic-add [x y] where (Add A)\n"
    "  (Add-add A $Add-A x y))\n"
    "(eval (generic-add (rat 1/3) (rat 2/3)))\n")))
  (check-true (string-contains? (last results) "1 : Rat")))

(test-case "where/add-nat-auto-resolution"
  (define results (run-ns-strings (string-append
    "(ns t)\n"
    "(require [prologos.core.add-trait :refer [Add Add-add]])\n"
    "(spec generic-add A A -> A where (Add A))\n"
    "(defn generic-add [x y] where (Add A)\n"
    "  (Add-add A $Add-A x y))\n"
    "(eval (generic-add zero (inc zero)))\n")))
  (check-true (string-contains? (last results) "1 : Nat")))

(test-case "where/mul-int-auto-resolution"
  (define results (run-ns-strings (string-append
    "(ns t)\n"
    "(require [prologos.core.mul-trait :refer [Mul Mul-mul]])\n"
    "(require [prologos.core.mul-instances :refer []])\n"
    "(spec generic-mul A A -> A where (Mul A))\n"
    "(defn generic-mul [x y] where (Mul A)\n"
    "  (Mul-mul A $Mul-A x y))\n"
    "(eval (generic-mul (int 3) (int 7)))\n")))
  (check-true (string-contains? (last results) "21 : Int")))

(test-case "where/neg-int-auto-resolution"
  (define results (run-ns-strings (string-append
    "(ns t)\n"
    "(require [prologos.core.neg-trait :refer [Neg Neg-neg]])\n"
    "(require [prologos.core.neg-instances :refer []])\n"
    "(spec generic-neg A -> A where (Neg A))\n"
    "(defn generic-neg [x] where (Neg A)\n"
    "  (Neg-neg A $Neg-A x))\n"
    "(eval (generic-neg (int 42)))\n")))
  (check-true (and (not (null? results))
                   (string-contains? (last results) "-42"))
              (format "Expected -42 in results: ~a" results)))

(test-case "where/neg-rat-auto-resolution"
  (define results (run-ns-strings (string-append
    "(ns t)\n"
    "(require [prologos.core.neg-trait :refer [Neg Neg-neg]])\n"
    "(require [prologos.core.neg-instances :refer []])\n"
    "(spec generic-neg A -> A where (Neg A))\n"
    "(defn generic-neg [x] where (Neg A)\n"
    "  (Neg-neg A $Neg-A x))\n"
    "(eval (generic-neg (rat 3/5)))\n")))
  (check-true (and (not (null? results))
                   (string-contains? (last results) "-3/5"))
              (format "Expected -3/5 in results: ~a" results)))

;; ========================================
;; C. Eq/Ord numeric instances
;; ========================================

(test-case "eq/int-equal"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.core.eq-trait :refer [Eq Eq-eq?]])\n"
    "(require [prologos.core.eq-numeric-instances :refer []])\n"
    "(eval (Eq-eq? Int Int--Eq--dict (int 3) (int 3)))\n")))
  (check-true (string-contains? (format "~a" r) "true")))

(test-case "eq/int-unequal"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.core.eq-trait :refer [Eq Eq-eq?]])\n"
    "(require [prologos.core.eq-numeric-instances :refer []])\n"
    "(eval (Eq-eq? Int Int--Eq--dict (int 3) (int 4)))\n")))
  (check-true (string-contains? (format "~a" r) "false")))

(test-case "eq/rat-equal"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.core.eq-trait :refer [Eq Eq-eq?]])\n"
    "(require [prologos.core.eq-numeric-instances :refer []])\n"
    "(eval (Eq-eq? Rat Rat--Eq--dict (rat 1/2) (rat 1/2)))\n")))
  (check-true (string-contains? (format "~a" r) "true")))

(test-case "eq/rat-unequal"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.core.eq-trait :refer [Eq Eq-eq?]])\n"
    "(require [prologos.core.eq-numeric-instances :refer []])\n"
    "(eval (Eq-eq? Rat Rat--Eq--dict (rat 1/2) (rat 1/3)))\n")))
  (check-true (string-contains? (format "~a" r) "false")))

(test-case "ord/int-lt"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.core.ord-trait :refer [Ord Ord-compare]])\n"
    "(require [prologos.core.ord-numeric-instances :refer []])\n"
    "(eval (Ord-compare Int Int--Ord--dict (int 3) (int 5)))\n")))
  (check-true (string-contains? (format "~a" r) "lt-ord")))

(test-case "ord/int-eq"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.core.ord-trait :refer [Ord Ord-compare]])\n"
    "(require [prologos.core.ord-numeric-instances :refer []])\n"
    "(eval (Ord-compare Int Int--Ord--dict (int 5) (int 5)))\n")))
  (check-true (string-contains? (format "~a" r) "eq-ord")))

(test-case "ord/int-gt"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.core.ord-trait :refer [Ord Ord-compare]])\n"
    "(require [prologos.core.ord-numeric-instances :refer []])\n"
    "(eval (Ord-compare Int Int--Ord--dict (int 7) (int 5)))\n")))
  (check-true (string-contains? (format "~a" r) "gt-ord")))

(test-case "ord/rat-lt"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.core.ord-trait :refer [Ord Ord-compare]])\n"
    "(require [prologos.core.ord-numeric-instances :refer []])\n"
    "(eval (Ord-compare Rat Rat--Ord--dict (rat 1/3) (rat 2/3)))\n")))
  (check-true (string-contains? (format "~a" r) "lt-ord")))

;; ========================================
;; D. Conversion traits
;; ========================================

(test-case "fromint/int-identity"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.core.fromint-trait :refer [FromInt FromInt-from-integer]])\n"
    "(eval (FromInt-from-integer Int Int--FromInt--dict (int 42)))\n")))
  (check-true (string-contains? (format "~a" r) "42 : Int")))

(test-case "fromint/rat-conversion"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.core.fromint-trait :refer [FromInt FromInt-from-integer]])\n"
    "(eval (FromInt-from-integer Rat Rat--FromInt--dict (int 42)))\n")))
  (check-true (string-contains? (format "~a" r) "42 : Rat")))

(test-case "fromrat/rat-identity"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.core.fromrat-trait :refer [FromRat FromRat-from-rational]])\n"
    "(eval (FromRat-from-rational Rat Rat--FromRat--dict (rat 3/7)))\n")))
  (check-true (string-contains? (format "~a" r) "3/7 : Rat")))

;; ========================================
;; E. Bundle tests
;; ========================================

(test-case "num-bundle/int-add"
  ;; Use Num bundle with Int — all 8 constraints should resolve
  (define results (run-ns-strings (string-append
    "(ns t)\n"
    "(require [prologos.core.numeric-bundles :refer [Num]])\n"
    "(require [prologos.core.add-instances :refer []])\n"
    "(require [prologos.core.sub-instances :refer []])\n"
    "(require [prologos.core.mul-instances :refer []])\n"
    "(require [prologos.core.neg-instances :refer []])\n"
    "(require [prologos.core.abs-instances :refer []])\n"
    "(require [prologos.core.eq-numeric-instances :refer []])\n"
    "(require [prologos.core.ord-numeric-instances :refer []])\n"
    "(require [prologos.core.add-trait :refer [Add-add]])\n"
    "(spec num-add A A -> A where (Num A))\n"
    "(defn num-add [x y] where (Num A)\n"
    "  (Add-add A $Add-A x y))\n"
    "(eval (num-add (int 10) (int 20)))\n")))
  (check-true (string-contains? (last results) "30 : Int")))

(test-case "num-bundle/rat-add"
  ;; Use Num bundle with Rat
  (define results (run-ns-strings (string-append
    "(ns t)\n"
    "(require [prologos.core.numeric-bundles :refer [Num]])\n"
    "(require [prologos.core.add-instances :refer []])\n"
    "(require [prologos.core.sub-instances :refer []])\n"
    "(require [prologos.core.mul-instances :refer []])\n"
    "(require [prologos.core.neg-instances :refer []])\n"
    "(require [prologos.core.abs-instances :refer []])\n"
    "(require [prologos.core.eq-numeric-instances :refer []])\n"
    "(require [prologos.core.ord-numeric-instances :refer []])\n"
    "(require [prologos.core.add-trait :refer [Add-add]])\n"
    "(spec num-add A A -> A where (Num A))\n"
    "(defn num-add [x y] where (Num A)\n"
    "  (Add-add A $Add-A x y))\n"
    "(eval (num-add (rat 1/4) (rat 3/4)))\n")))
  (check-true (string-contains? (last results) "1 : Rat")))

(test-case "num-bundle/nat-fails"
  ;; Nat should fail Num bundle (lacks Neg, Abs, FromInt)
  (define results (run-ns (string-append
    "(ns t)\n"
    "(require [prologos.core.numeric-bundles :refer [Num]])\n"
    "(require [prologos.core.add-trait :refer [Add-add]])\n"
    "(spec num-add A A -> A where (Num A))\n"
    "(defn num-add [x y] where (Num A)\n"
    "  (Add-add A $Add-A x y))\n"
    "(eval (num-add zero (inc zero)))\n")))
  ;; Should produce a no-instance-error for one of: Neg, Abs, or FromInt
  (check-true (ormap (lambda (r) (no-instance-error? r)) results)
              (format "Expected no-instance-error for Nat, got: ~a" results)))

(test-case "fractional-bundle/rat"
  ;; Fractional with Rat — all 10 constraints resolve
  (define results (run-ns-strings (string-append
    "(ns t)\n"
    "(require [prologos.core.numeric-bundles :refer [Fractional]])\n"
    "(require [prologos.core.add-instances :refer []])\n"
    "(require [prologos.core.sub-instances :refer []])\n"
    "(require [prologos.core.mul-instances :refer []])\n"
    "(require [prologos.core.div-instances :refer []])\n"
    "(require [prologos.core.neg-instances :refer []])\n"
    "(require [prologos.core.abs-instances :refer []])\n"
    "(require [prologos.core.eq-numeric-instances :refer []])\n"
    "(require [prologos.core.ord-numeric-instances :refer []])\n"
    "(require [prologos.core.div-trait :refer [Div-div]])\n"
    "(spec frac-div A A -> A where (Fractional A))\n"
    "(defn frac-div [x y] where (Fractional A)\n"
    "  (Div-div A $Div-A x y))\n"
    "(eval (frac-div (rat 5/3) (rat 2/3)))\n")))
  (check-true (string-contains? (last results) "5/2 : Rat")))

;; ========================================
;; F. Backward compatibility
;; ========================================

(test-case "backward-compat/nat-add-still-works"
  ;; The global add from prologos.data.nat should still work
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.data.nat :refer [add]])\n"
    "(eval (add zero (inc zero)))\n")))
  (check-true (string-contains? (format "~a" r) "1")))

(test-case "backward-compat/nat-sub-still-works"
  ;; The global sub from prologos.data.nat should still work
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos.data.nat :refer [sub]])\n"
    "(eval (sub (inc (inc (inc zero))) (inc zero)))\n")))
  (check-true (string-contains? (format "~a" r) "2")))
