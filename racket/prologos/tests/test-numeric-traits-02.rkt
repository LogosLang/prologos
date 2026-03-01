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
         "test-support.rkt"
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
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    (process-string s)))

(define (run-ns-last s) (last (run-ns s)))

(define (run-ns-strings s)
  (filter string? (run-ns s)))


(test-case "where/neg-rat-auto-resolution"
  (define results (run-ns-strings (string-append
    "(ns t)\n"
    "(require [prologos::core::arithmetic :refer [Neg Neg-neg]])\n"
    "(require [prologos::core::arithmetic :refer []])\n"
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
    "(require [prologos::core::eq :refer [Eq Eq-eq?]])\n"
    "(require [prologos::core::eq :refer []])\n"
    "(eval (Eq-eq? Int Int--Eq--dict (int 3) (int 3)))\n")))
  (check-true (string-contains? (format "~a" r) "true")))


(test-case "eq/int-unequal"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos::core::eq :refer [Eq Eq-eq?]])\n"
    "(require [prologos::core::eq :refer []])\n"
    "(eval (Eq-eq? Int Int--Eq--dict (int 3) (int 4)))\n")))
  (check-true (string-contains? (format "~a" r) "false")))


(test-case "eq/rat-equal"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos::core::eq :refer [Eq Eq-eq?]])\n"
    "(require [prologos::core::eq :refer []])\n"
    "(eval (Eq-eq? Rat Rat--Eq--dict (rat 1/2) (rat 1/2)))\n")))
  (check-true (string-contains? (format "~a" r) "true")))


(test-case "eq/rat-unequal"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos::core::eq :refer [Eq Eq-eq?]])\n"
    "(require [prologos::core::eq :refer []])\n"
    "(eval (Eq-eq? Rat Rat--Eq--dict (rat 1/2) (rat 1/3)))\n")))
  (check-true (string-contains? (format "~a" r) "false")))


(test-case "ord/int-lt"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos::core::ord :refer [Ord Ord-compare]])\n"
    "(require [prologos::core::ord :refer []])\n"
    "(eval (Ord-compare Int Int--Ord--dict (int 3) (int 5)))\n")))
  (check-true (string-contains? (format "~a" r) "lt-ord")))


(test-case "ord/int-eq"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos::core::ord :refer [Ord Ord-compare]])\n"
    "(require [prologos::core::ord :refer []])\n"
    "(eval (Ord-compare Int Int--Ord--dict (int 5) (int 5)))\n")))
  (check-true (string-contains? (format "~a" r) "eq-ord")))


(test-case "ord/int-gt"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos::core::ord :refer [Ord Ord-compare]])\n"
    "(require [prologos::core::ord :refer []])\n"
    "(eval (Ord-compare Int Int--Ord--dict (int 7) (int 5)))\n")))
  (check-true (string-contains? (format "~a" r) "gt-ord")))


(test-case "ord/rat-lt"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos::core::ord :refer [Ord Ord-compare]])\n"
    "(require [prologos::core::ord :refer []])\n"
    "(eval (Ord-compare Rat Rat--Ord--dict (rat 1/3) (rat 2/3)))\n")))
  (check-true (string-contains? (format "~a" r) "lt-ord")))


;; ========================================
;; D. Conversion traits
;; ========================================

(test-case "fromint/int-identity"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos::core::conversions :refer [FromInt FromInt-from-integer]])\n"
    "(eval (FromInt-from-integer Int Int--FromInt--dict (int 42)))\n")))
  (check-true (string-contains? (format "~a" r) "42 : Int")))


(test-case "fromint/rat-conversion"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos::core::conversions :refer [FromInt FromInt-from-integer]])\n"
    "(eval (FromInt-from-integer Rat Rat--FromInt--dict (int 42)))\n")))
  (check-true (string-contains? (format "~a" r) "42 : Rat")))


(test-case "fromrat/rat-identity"
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos::core::conversions :refer [FromRat FromRat-from-rational]])\n"
    "(eval (FromRat-from-rational Rat Rat--FromRat--dict (rat 3/7)))\n")))
  (check-true (string-contains? (format "~a" r) "3/7 : Rat")))


;; ========================================
;; E. Bundle tests
;; ========================================

(test-case "num-bundle/int-add"
  ;; Use Num bundle with Int — all 8 constraints should resolve
  (define results (run-ns-strings (string-append
    "(ns t)\n"
    "(require [prologos::core::algebra :refer [Num]])\n"
    "(require [prologos::core::arithmetic :refer []])\n"
    "(require [prologos::core::arithmetic :refer []])\n"
    "(require [prologos::core::arithmetic :refer []])\n"
    "(require [prologos::core::arithmetic :refer []])\n"
    "(require [prologos::core::arithmetic :refer []])\n"
    "(require [prologos::core::eq :refer []])\n"
    "(require [prologos::core::ord :refer []])\n"
    "(require [prologos::core::arithmetic :refer [Add-add]])\n"
    "(spec num-add A A -> A where (Num A))\n"
    "(defn num-add [x y] where (Num A)\n"
    "  (Add-add A $Add-A x y))\n"
    "(eval (num-add (int 10) (int 20)))\n")))
  (check-true (string-contains? (last results) "30 : Int")))


(test-case "num-bundle/rat-add"
  ;; Use Num bundle with Rat
  (define results (run-ns-strings (string-append
    "(ns t)\n"
    "(require [prologos::core::algebra :refer [Num]])\n"
    "(require [prologos::core::arithmetic :refer []])\n"
    "(require [prologos::core::arithmetic :refer []])\n"
    "(require [prologos::core::arithmetic :refer []])\n"
    "(require [prologos::core::arithmetic :refer []])\n"
    "(require [prologos::core::arithmetic :refer []])\n"
    "(require [prologos::core::eq :refer []])\n"
    "(require [prologos::core::ord :refer []])\n"
    "(require [prologos::core::arithmetic :refer [Add-add]])\n"
    "(spec num-add A A -> A where (Num A))\n"
    "(defn num-add [x y] where (Num A)\n"
    "  (Add-add A $Add-A x y))\n"
    "(eval (num-add (rat 1/4) (rat 3/4)))\n")))
  (check-true (string-contains? (last results) "1 : Rat")))


(test-case "num-bundle/nat-fails"
  ;; Nat should fail Num bundle (lacks Neg, Abs, FromInt)
  (define results (run-ns (string-append
    "(ns t)\n"
    "(require [prologos::core::algebra :refer [Num]])\n"
    "(require [prologos::core::arithmetic :refer [Add-add]])\n"
    "(spec num-add A A -> A where (Num A))\n"
    "(defn num-add [x y] where (Num A)\n"
    "  (Add-add A $Add-A x y))\n"
    "(eval (num-add zero (suc zero)))\n")))
  ;; Should produce a no-instance-error for one of: Neg, Abs, or FromInt
  (check-true (ormap (lambda (r) (no-instance-error? r)) results)
              (format "Expected no-instance-error for Nat, got: ~a" results)))


(test-case "fractional-bundle/rat"
  ;; Fractional with Rat — all 10 constraints resolve
  (define results (run-ns-strings (string-append
    "(ns t)\n"
    "(require [prologos::core::algebra :refer [Fractional]])\n"
    "(require [prologos::core::arithmetic :refer []])\n"
    "(require [prologos::core::arithmetic :refer []])\n"
    "(require [prologos::core::arithmetic :refer []])\n"
    "(require [prologos::core::arithmetic :refer []])\n"
    "(require [prologos::core::arithmetic :refer []])\n"
    "(require [prologos::core::arithmetic :refer []])\n"
    "(require [prologos::core::eq :refer []])\n"
    "(require [prologos::core::ord :refer []])\n"
    "(require [prologos::core::arithmetic :refer [Div-div]])\n"
    "(spec frac-div A A -> A where (Fractional A))\n"
    "(defn frac-div [x y] where (Fractional A)\n"
    "  (Div-div A $Div-A x y))\n"
    "(eval (frac-div (rat 5/3) (rat 2/3)))\n")))
  (check-true (string-contains? (last results) "5/2 : Rat")))


;; ========================================
;; F. Backward compatibility
;; ========================================

(test-case "backward-compat/nat-add-still-works"
  ;; The global add from prologos::data::nat should still work
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos::data::nat :refer [add]])\n"
    "(eval (add zero (suc zero)))\n")))
  (check-true (string-contains? (format "~a" r) "1")))


(test-case "backward-compat/nat-sub-still-works"
  ;; The global sub from prologos::data::nat should still work
  (define r (run-ns-last (string-append
    "(ns t)\n"
    "(require [prologos::data::nat :refer [sub]])\n"
    "(eval (sub (suc (suc (suc zero))) (suc zero)))\n")))
  (check-true (string-contains? (format "~a" r) "2")))
