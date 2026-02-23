#lang racket/base

;;;
;;; Tests for coercion warnings (Phase 3c)
;;;
;;; Verifies that cross-family coercion (exact → approximate) emits
;;; informational warnings, and that same-family coercion does not.
;;;

(require racket/string
         rackunit
         "../syntax.rkt"
         "../prelude.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../posit-impl.rkt")

;; Helper: run through process-string (sexp mode)
(define (run s)
  (parameterize ([current-global-env (hasheq)])
    (process-string s)))

;; ========================================
;; Cross-family: should emit warnings
;; ========================================

(test-case "warning/int+p32-has-warning"
  ;; Int + Posit32 → should warn about Int→Posit32
  (define result (car (run "(eval (+ 42 ~1.0))")))
  (check-true (string-contains? result "warning:")
              "Cross-family coercion should emit warning")
  (check-true (string-contains? result "Int")
              "Warning should mention source type")
  (check-true (string-contains? result "Posit32")
              "Warning should mention target type")
  (check-true (string-contains? result "loss of exactness")
              "Warning should mention loss of exactness"))

(test-case "warning/rat+p32-has-warning"
  (define result (car (run "(eval (+ 1/2 ~0.5))")))
  (check-true (string-contains? result "warning:")
              "Rat + Posit32 should warn")
  (check-true (string-contains? result "Rat")))

(test-case "warning/nat+p32-has-warning"
  (define result (car (run "(eval (+ 3N ~1.0))")))
  (check-true (string-contains? result "warning:")
              "Nat + Posit32 should warn")
  (check-true (string-contains? result "Nat")))

(test-case "warning/int-lt-p32-has-warning"
  ;; Comparison also warns
  (define result (car (run "(eval (lt 3 ~4.0))")))
  (check-true (string-contains? result "warning:")))

;; ========================================
;; Same-family: should NOT emit warnings
;; ========================================

(test-case "warning/same-int-no-warning"
  ;; Int + Int → no warning
  (define result (car (run "(eval (+ 3 4))")))
  (check-false (string-contains? result "warning:")
               "Same-type Int should not warn"))

(test-case "warning/same-rat-no-warning"
  (define result (car (run "(eval (+ 1/2 3/7))")))
  (check-false (string-contains? result "warning:")
               "Same-type Rat should not warn"))

(test-case "warning/same-p32-no-warning"
  (define result (car (run "(eval (+ ~1.0 ~2.0))")))
  (check-false (string-contains? result "warning:")
               "Same-type Posit32 should not warn"))

(test-case "warning/nat+int-no-warning"
  ;; Nat + Int → within exact family, no warning
  (define result (car (run "(eval (+ 3N 4))")))
  (check-false (string-contains? result "warning:")
               "Nat+Int (within exact) should not warn"))

(test-case "warning/int+rat-no-warning"
  ;; Int + Rat → within exact family, no warning
  (define result (car (run "(eval (+ 3 1/2))")))
  (check-false (string-contains? result "warning:")
               "Int+Rat (within exact) should not warn"))

(test-case "warning/p8+p32-no-warning"
  ;; Posit8 + Posit32 → within posit family, no warning
  (define result (car (run "(eval (+ (from-integer <Posit8> 2) ~3.0))")))
  (check-false (string-contains? result "warning:")
               "Posit8+Posit32 (within posit) should not warn"))

;; ========================================
;; Warning format
;; ========================================

(test-case "warning/format-structure"
  ;; Verify the warning is on a separate line after the result
  (define result (car (run "(eval (+ 42 ~1.0))")))
  (define lines (string-split result "\n"))
  (check-equal? (length lines) 2 "Should have result line + warning line")
  ;; First line is the result
  (check-true (string-contains? (car lines) "Posit32")
              "First line should be the result")
  ;; Second line is the warning
  (check-true (string-prefix? (cadr lines) "warning:")
              "Second line should start with 'warning:'"))

;; ========================================
;; Infer mode also shows warnings
;; ========================================

(test-case "warning/infer-cross-family"
  ;; infer (+ 42 ~1.0) should show warning
  (define result (car (run "(infer (+ 42 ~1.0))")))
  (check-true (string-contains? result "Posit32") "Should infer Posit32")
  (check-true (string-contains? result "warning:") "Should have warning"))

(test-case "warning/infer-same-type-no-warning"
  ;; infer (+ 3 4) should not show warning
  (define result (car (run "(infer (+ 3 4))")))
  (check-false (string-contains? result "warning:") "Same type should not warn"))
