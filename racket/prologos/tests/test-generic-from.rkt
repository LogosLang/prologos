#lang racket/base

;;;
;;; Tests for Generic from-integer / from-rational (Phase 2b)
;;;

(require rackunit
         racket/string
         "../syntax.rkt"
         "../prelude.rkt"
         "../surface-syntax.rkt"
         "../posit-impl.rkt"
         "../parser.rkt"
         "../driver.rkt"
         "../global-env.rkt")

;; Helper: run through process-string (sexp mode)
(define (run s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)])
    (car (process-string s))))

;; ========================================
;; from-integer: identity cases
;; ========================================

(test-case "from-integer/int-identity"
  (check-equal? (run "(eval (from-integer Int 42))") "42 : Int"))

(test-case "from-integer/int-to-rat"
  (check-equal? (run "(eval (from-integer Rat 42))") "42 : Rat"))

;; ========================================
;; from-integer: to Posit
;; ========================================

(test-case "from-integer/int-to-posit32"
  (define result (run "(eval (from-integer Posit32 42))"))
  (check-true (string-contains? result "posit32")
              (format "expected posit32, got: ~a" result))
  (check-true (string-contains? result (number->string (posit32-encode 42)))))

(test-case "from-integer/int-to-posit8"
  (define result (run "(eval (from-integer Posit8 1))"))
  (check-true (string-contains? result "posit8")))

(test-case "from-integer/int-to-posit16"
  (define result (run "(eval (from-integer Posit16 100))"))
  (check-true (string-contains? result "posit16")))

(test-case "from-integer/int-to-posit64"
  (define result (run "(eval (from-integer Posit64 42))"))
  (check-true (string-contains? result "posit64")))

;; ========================================
;; from-rational: identity case
;; ========================================

(test-case "from-rational/rat-identity"
  (check-equal? (run "(eval (from-rational Rat 3/7))") "3/7 : Rat"))

;; ========================================
;; from-rational: to Posit
;; ========================================

(test-case "from-rational/rat-to-posit32"
  (define result (run "(eval (from-rational Posit32 3/7))"))
  (check-true (string-contains? result "posit32")
              (format "expected posit32, got: ~a" result))
  (check-true (string-contains? result (number->string (posit32-encode 3/7)))))

(test-case "from-rational/rat-to-posit8"
  (define result (run "(eval (from-rational Posit8 1/2))"))
  (check-true (string-contains? result "posit8")))

;; ========================================
;; Type inference
;; ========================================

(test-case "from-integer/infer-posit32"
  (check-true (string-contains? (run "(infer (from-integer Posit32 42))") "Posit32")))

(test-case "from-rational/infer-posit32"
  (check-true (string-contains? (run "(infer (from-rational Posit32 1/2))") "Posit32")))

(test-case "from-integer/infer-rat"
  (check-true (string-contains? (run "(infer (from-integer Rat 42))") "Rat")))
