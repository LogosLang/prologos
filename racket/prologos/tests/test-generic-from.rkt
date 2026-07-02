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
  (car (process-string s)))

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
  (check-true (string-contains? result "Posit32")
              (format "expected Posit32, got: ~a" result))
  ;; Numerics N2: posit displays as ~<decimal>. from-integer 42 → ~42.
  (check-true (string-contains? result "42.0")))

(test-case "from-integer/int-to-posit8"
  (define result (run "(eval (from-integer Posit8 1))"))
  (check-true (string-contains? result "Posit8")))

(test-case "from-integer/int-to-posit16"
  (define result (run "(eval (from-integer Posit16 100))"))
  (check-true (string-contains? result "Posit16")))

(test-case "from-integer/int-to-posit64"
  (define result (run "(eval (from-integer Posit64 42))"))
  (check-true (string-contains? result "Posit64")))

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
  (check-true (string-contains? result "Posit32")
              (format "expected Posit32, got: ~a" result))
  ;; N6c: shortest decimal of posit32(3/7) displays bare (sigil-free).
  (check-true (string-contains? result (posit-shortest-decimal 32 (posit32-encode 3/7)))))

(test-case "from-rational/rat-to-posit8"
  (define result (run "(eval (from-rational Posit8 1/2))"))
  (check-true (string-contains? result "Posit8")))

;; ========================================
;; Type inference
;; ========================================

(test-case "from-integer/infer-posit32"
  (check-true (string-contains? (run "(infer (from-integer Posit32 42))") "Posit32")))

(test-case "from-rational/infer-posit32"
  (check-true (string-contains? (run "(infer (from-rational Posit32 1/2))") "Posit32")))

(test-case "from-integer/infer-rat"
  (check-true (string-contains? (run "(infer (from-integer Rat 42))") "Rat")))
