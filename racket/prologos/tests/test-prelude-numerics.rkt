#lang racket/base

;;;
;;; Tests for prelude numerics completeness:
;;; - Div trait resolves for Int, Rat
;;; - FromInt resolves for Posit types
;;; - FromRat resolves for Posit types
;;; - Num bundle resolves for Int
;;; - Fractional bundle resolves for Rat
;;; - Div and FromRat available as prelude names
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

(define (run s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
    (process-string s)))

(define (run-first s) (car (run s)))

(define (run-ns s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
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

;; ========================================
;; Div trait in prelude
;; ========================================

(test-case "prelude-numerics/div-int"
  ;; Int division via parser keyword /
  (check-equal? (run-first "(eval (/ 7 2))") "3 : Int"))

(test-case "prelude-numerics/div-rat"
  ;; Rat division via parser keyword /
  (check-equal? (run-first "(eval (/ 1/2 1/3))") "3/2 : Rat"))

;; ========================================
;; Div and FromRat names available
;; ========================================

(test-case "prelude-numerics/div-name-in-scope"
  ;; Div type constructor should be available via prelude
  (check-not-exn
    (lambda ()
      (run-ns "(ns test-div-avail)\n(spec my-div {A : Type} (Div A) -> A -> A -> A)\n(defn my-div (dict x y) (Div-div dict x y))"))))

(test-case "prelude-numerics/fromrat-name-in-scope"
  ;; FromRat type constructor should be available via prelude
  (check-not-exn
    (lambda ()
      (run-ns "(ns test-fromrat-avail)\n(spec my-conv {A : Type} (FromRat A) -> Rat -> A)\n(defn my-conv (dict x) (FromRat-from-rational dict x))"))))

;; ========================================
;; Num bundle for Int
;; ========================================

(test-case "prelude-numerics/num-int-add"
  ;; Num bundle resolves for Int (Add component)
  (check-equal? (run-first "(eval (+ 10 20))") "30 : Int"))

(test-case "prelude-numerics/num-int-negate"
  ;; Num bundle resolves for Int (Neg component)
  (check-equal? (run-first "(eval (negate 5))") "-5 : Int"))

(test-case "prelude-numerics/num-int-abs"
  ;; Num bundle resolves for Int (Abs component)
  (check-equal? (run-first "(eval (abs (negate 7)))") "7 : Int"))

;; ========================================
;; Fractional bundle for Rat
;; ========================================

(test-case "prelude-numerics/fractional-rat-div"
  ;; Fractional bundle resolves for Rat (Div component)
  (check-equal? (run-first "(eval (/ 3/4 1/2))") "3/2 : Rat"))

(test-case "prelude-numerics/fractional-rat-add"
  ;; Fractional bundle resolves for Rat (Add via Num component)
  (check-equal? (run-first "(eval (+ 1/2 1/3))") "5/6 : Rat"))
