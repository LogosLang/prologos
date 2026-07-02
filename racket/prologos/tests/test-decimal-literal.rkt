#lang racket/base

;;;
;;; Tests for bare decimal literal syntax (Phase 1d)
;;;
;;; N4: Bare decimals (3.14, 0.5) are POLYMORPHIC numeric literals (surf-num-lit) —
;;; they carry an exact value and resolve their type from context; unconstrained →
;;; Posit32 for decimals (N6b). pNN literals + explicit rationals stay concrete.
;;;

(require racket/string
         rackunit
         "../syntax.rkt"
         "../prelude.rkt"
         "../surface-syntax.rkt"
         "../parse-reader.rkt"
         "../parser.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../posit-impl.rkt")

;; Helper: run through process-string (sexp mode)
(define (run s)
  (process-string s))

;; Token accessors via struct->vector (token struct is not exported)
(define tok-type token-type)
(define tok-val token-value)

;; ========================================
;; Reader: tokenization
;; ========================================

(test-case "decimal-literal/tokenize-3.14"
  ;; 3.14 should produce decimal-literal token, not number
  (define tokens (tokenize-string "3.14"))
  (define dec-tok (findf (lambda (t) (eq? (tok-type t) 'decimal-literal)) tokens))
  (check-not-false dec-tok "should produce decimal-literal token")
  (check-equal? (tok-val dec-tok) 157/50 "3.14 should be exact rational 157/50"))

(test-case "decimal-literal/tokenize-0.5"
  (define tokens (tokenize-string "0.5"))
  (define dec-tok (findf (lambda (t) (eq? (tok-type t) 'decimal-literal)) tokens))
  (check-not-false dec-tok "should produce decimal-literal token")
  (check-equal? (tok-val dec-tok) 1/2 "0.5 should be exact rational 1/2"))

(test-case "decimal-literal/tokenize-1.0"
  (define tokens (tokenize-string "1.0"))
  (define dec-tok (findf (lambda (t) (eq? (tok-type t) 'decimal-literal)) tokens))
  (check-not-false dec-tok "should produce decimal-literal token")
  (check-equal? (tok-val dec-tok) 1 "1.0 should be exact rational 1"))

;; ========================================
;; Reader: WS round-trip
;; ========================================

(test-case "decimal-literal/ws-roundtrip"
  ;; 3.14 should produce ($decimal-literal 157/50)
  (check-equal? (read-all-forms-string "eval 3.14")
                '((eval ($decimal-literal 157/50)))))

(test-case "decimal-literal/ws-roundtrip-0.5"
  (check-equal? (read-all-forms-string "eval 0.5")
                '((eval ($decimal-literal 1/2)))))

;; ========================================
;; Parser: $decimal-literal → surf-approx-literal
;; ========================================

(test-case "decimal-literal/parser-sentinel"
  (define stx (datum->syntax #f '($decimal-literal 157/50)))
  (define result (parse-datum stx))
  (check-true (surf-num-lit? result) "should be surf-num-lit (N4 polymorphic)")
  (check-equal? (surf-num-lit-val result) 157/50 "value should be 157/50")
  (check-false (surf-num-lit-integral? result) "3.14 is not integral"))

(test-case "decimal-literal/parser-sentinel-half"
  (define stx (datum->syntax #f '($decimal-literal 1/2)))
  (define result (parse-datum stx))
  (check-true (surf-num-lit? result) "should be surf-num-lit (N4 polymorphic)")
  (check-equal? (surf-num-lit-val result) 1/2 "value should be 1/2"))

;; ========================================
;; End-to-end: bare decimal → polymorphic (unconstrained → Rat/Int)
;; ========================================

(test-case "decimal-literal/eval-3.14"
  ;; N6b: unconstrained decimal → Posit32 (decimal notation = approximate intent)
  (check-true (string-contains? (car (run "(eval 3.14)")) ": Posit32")
              "3.14 → Posit32 (N6b decimal default)"))

(test-case "decimal-literal/eval-0.5"
  (check-equal? (run "(eval 0.5)") '("0.5 : Posit32")))

(test-case "decimal-literal/eval-1.0"
  ;; N6b: integral VALUE but decimal NOTATION → Posit32 (origin wins)
  (check-equal? (run "(eval 1.0)") '("1.0 : Posit32")))

(test-case "decimal-literal/check-type"
  ;; 3.14 still type-checks against Posit32 (context-typed via the check arm)
  (check-equal? (run "(check 3.14 <Posit32>)")
                '("OK")))

(test-case "decimal-literal/infer"
  ;; N6b: unconstrained 3.14 infers as Posit32 (decimal-origin default)
  (define result (car (run "(infer 3.14)")))
  (check-true (string-contains? result "Posit32") "3.14 infers as Posit32 (N6b default)"))

;; ========================================
;; Unchanged: rationals stay Rat
;; ========================================

(test-case "decimal-literal/rational-unchanged"
  ;; 3/7 should still be Rat, not Posit32
  (define result (car (run "(infer 3/7)")))
  (check-true (string-contains? result "Rat") "3/7 should still be Rat"))

;; ========================================
;; Unchanged: ~N still works
;; ========================================

(test-case "decimal-literal/pNN-markers (N6c: ~ removed)"
  ;; pNN literals are the explicit-width posit form; sexp ~N now errors.
  (check-exn exn:fail? (lambda () (run "(eval ~3.14)")))
  (check-exn exn:fail? (lambda () (run "(eval ~42)"))))

;; ========================================
;; Arithmetic with bare decimals
;; ========================================

(test-case "decimal-literal/p32-add"
  ;; N4: bare decimals are polymorphic; ascribe (or use ~ markers) to feed a width op.
  ;; (Bare literal DIRECTLY to a width-specific op resolves to Rat/Int, not the op type —
  ;; deferred to N4c; ascription `(the Posit32 ...)` context-types correctly via Option B.)
  (check-equal? (run "(eval (p32+ (the Posit32 1.0) (the Posit32 2.0)))")
                '("3.0 : Posit32")))

;; ========================================
;; List literal with bare decimals
;; ========================================

(test-case "decimal-literal/list-ws-reader"
  ;; In WS mode, '[1.0 2.0 3.0] should produce list-literal with $decimal-literal sentinels
  (define forms (read-all-forms-string "'[1.0 2.0 3.0]"))
  (check-equal? (length forms) 1)
  (define form (car forms))
  ;; Should be ($list-literal ($decimal-literal 1) ($decimal-literal 2) ($decimal-literal 3))
  (check-true (pair? form) "form should be a list")
  (check-equal? (car form) '$list-literal "head should be $list-literal")
  (check-true (andmap (lambda (e) (and (pair? e) (eq? (car e) '$decimal-literal)))
                      (cdr form))
              "all elements should be $decimal-literal sentinels"))
