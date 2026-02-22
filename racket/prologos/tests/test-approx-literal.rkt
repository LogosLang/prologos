#lang racket/base

;;;
;;; Tests for ~ approximate literal syntax
;;;
;;; ~N converts an exact value to its nearest Posit32 representation.
;;; ~42 → (posit32 (posit32-encode 42))
;;; ~3/7 → (posit32 (posit32-encode 3/7))
;;;

(require racket/string
         rackunit
         "../syntax.rkt"
         "../prelude.rkt"
         "../surface-syntax.rkt"
         "../reader.rkt"
         "../parser.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../posit-impl.rkt")

;; Helper: run through process-string (sexp mode)
(define (run s)
  (parameterize ([current-global-env (hasheq)])
    (process-string s)))

;; Token accessors via struct->vector (token struct is not exported)
(define (tok-type t) (vector-ref (struct->vector t) 1))
(define (tok-val t) (vector-ref (struct->vector t) 2))

;; ========================================
;; Reader: WS mode tokenization
;; ========================================

(test-case "tilde reader: tokenize ~42"
  (define tokens (tokenize-string "~42"))
  (define approx-tok (findf (lambda (t) (eq? (tok-type t) 'approx-literal)) tokens))
  (check-not-false approx-tok "should produce approx-literal token")
  (check-equal? (tok-val approx-tok) 42 "value should be 42"))

(test-case "tilde reader: tokenize ~3/7"
  (define tokens (tokenize-string "~3/7"))
  (define approx-tok (findf (lambda (t) (eq? (tok-type t) 'approx-literal)) tokens))
  (check-not-false approx-tok "should produce approx-literal token")
  (check-equal? (tok-val approx-tok) 3/7 "value should be 3/7"))

(test-case "tilde reader: tokenize ~0"
  (define tokens (tokenize-string "~0"))
  (define approx-tok (findf (lambda (t) (eq? (tok-type t) 'approx-literal)) tokens))
  (check-not-false approx-tok "should produce approx-literal token")
  (check-equal? (tok-val approx-tok) 0 "value should be 0"))

;; ========================================
;; Reader: WS mode full round-trip
;; ========================================

(test-case "tilde reader: WS round-trip produces $approx-literal"
  (check-equal? (read-all-forms-string "eval ~42")
                '((eval ($approx-literal 42))))
  (check-equal? (read-all-forms-string "eval ~3/7")
                '((eval ($approx-literal 3/7)))))

;; ========================================
;; Parser: $approx-literal → surf-approx-literal
;; ========================================

(test-case "parser: $approx-literal produces surf-approx-literal"
  (define stx (datum->syntax #f '($approx-literal 42)))
  (define result (parse-datum stx))
  (check-true (surf-approx-literal? result) "should be surf-approx-literal")
  (check-equal? (surf-approx-literal-val result) 42 "value should be 42"))

(test-case "parser: $approx-literal with fraction"
  (define stx (datum->syntax #f '($approx-literal 3/7)))
  (define result (parse-datum stx))
  (check-true (surf-approx-literal? result) "should be surf-approx-literal")
  (check-equal? (surf-approx-literal-val result) 3/7 "value should be 3/7"))

;; ========================================
;; End-to-end: sexp mode via process-string
;; ========================================

(test-case "approx-literal surface: ~42 infers as Posit32"
  ;; posit32-encode(42) = 1698693120
  (check-equal? (run "(eval ~42)")
                '("[posit32 1698693120] : Posit32")))

(test-case "approx-literal surface: ~0 produces Posit32 zero"
  (check-equal? (run "(eval ~0)")
                '("[posit32 0] : Posit32")))

(test-case "approx-literal surface: ~1 produces Posit32 one"
  ;; posit32-encode(1) = 1073741824
  (check-equal? (run "(eval ~1)")
                '("[posit32 1073741824] : Posit32")))

(test-case "approx-literal surface: ~3/7 produces Posit32"
  ;; posit32-encode(3/7) = 901176174
  (check-equal? (run "(eval ~3/7)")
                '("[posit32 901176174] : Posit32")))

(test-case "approx-literal surface: ~100 produces Posit32"
  ;; posit32-encode(100) = 1782579200
  (check-equal? (run "(eval ~100)")
                '("[posit32 1782579200] : Posit32")))

(test-case "approx-literal surface: check ~42 against Posit32"
  (check-equal? (run "(check ~42 <Posit32>)")
                '("OK")))

(test-case "approx-literal surface: ~N in arithmetic"
  ;; ~1 + ~1 = ~2
  ;; posit32-encode(2) = 1207959552
  (check-equal? (run "(eval (p32+ ~1 ~1))")
                '("[posit32 1207959552] : Posit32")))

(test-case "approx-literal surface: def with ~N"
  (parameterize ([current-global-env (hasheq)])
    (let ([result (process-string "(def x <Posit32> ~42)\n(eval x)")])
      (check-equal? (length result) 2)
      (check-true (string-contains? (car result) "x : Posit32 defined"))
      (check-equal? (cadr result) "[posit32 1698693120] : Posit32"))))

(test-case "approx-literal surface: ~N in function body"
  (parameterize ([current-global-env (hasheq)])
    (let ([result (process-string "(defn add42 [x <Posit32>] <Posit32>\n  (p32+ x ~42))\n(eval (add42 ~1))")])
      (check-equal? (length result) 2)
      ;; 1 + 42 = 43
      (check-equal? (cadr result)
                    (format "[posit32 ~a] : Posit32" (posit32-encode 43))))))

;; ========================================
;; Decimal literal syntax: ~3.14
;; ========================================

(test-case "tilde reader: tokenize ~3.14 (decimal)"
  (define tokens (tokenize-string "~3.14"))
  (define approx-tok (findf (lambda (t) (eq? (tok-type t) 'approx-literal)) tokens))
  (check-not-false approx-tok "should produce approx-literal token")
  (check-equal? (tok-val approx-tok) 157/50 "~3.14 should be exact rational 157/50"))

(test-case "tilde reader: tokenize ~0.5 (decimal)"
  (define tokens (tokenize-string "~0.5"))
  (define approx-tok (findf (lambda (t) (eq? (tok-type t) 'approx-literal)) tokens))
  (check-not-false approx-tok "should produce approx-literal token")
  (check-equal? (tok-val approx-tok) 1/2 "~0.5 should be exact rational 1/2"))

(test-case "tilde reader: tokenize ~100.001 (decimal)"
  (define tokens (tokenize-string "~100.001"))
  (define approx-tok (findf (lambda (t) (eq? (tok-type t) 'approx-literal)) tokens))
  (check-not-false approx-tok "should produce approx-literal token")
  (check-equal? (tok-val approx-tok) 100001/1000 "~100.001 should be exact rational 100001/1000"))

(test-case "tilde reader: WS round-trip produces $approx-literal for decimal"
  (check-equal? (read-all-forms-string "eval ~3.14")
                '((eval ($approx-literal 157/50)))))

(test-case "approx-literal surface: ~3.14 infers as Posit32"
  (check-equal? (run "(eval ~3.14)")
                (list (format "[posit32 ~a] : Posit32" (posit32-encode 157/50)))))

(test-case "approx-literal surface: ~0.5 infers as Posit32"
  (check-equal? (run "(eval ~0.5)")
                (list (format "[posit32 ~a] : Posit32" (posit32-encode 1/2)))))

;; ========================================
;; Verification: encoding correctness
;; ========================================

(test-case "approx-literal: encoding matches posit32-encode"
  ;; Verify that ~N produces the same bit pattern as posit32-encode(N)
  (check-equal? (posit32-encode 42) 1698693120)
  (check-equal? (posit32-encode 0) 0)
  (check-equal? (posit32-encode 1) 1073741824)
  (check-equal? (posit32-encode 3/7) 901176174)
  (check-equal? (posit32-encode 100) 1782579200))
