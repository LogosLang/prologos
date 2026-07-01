#lang racket/base

;;;
;;; Tests for exponent literal syntax (Numerics N1).
;;;
;;; Bare exponent literals lex (WS mode) to EXACT values, bypassing the
;;; decimal-literal -> Posit32 path:
;;;   1e10    -> exact Int   (10000000000)
;;;   1.5e-3  -> exact Rat   (3/2000)
;;;   -1.5e-3 -> exact Rat   (-3/2000)
;;; Bare decimals WITHOUT an exponent (3.14) are UNCHANGED (still Posit32 = N4).
;;;
;;; SCOPE: WS-only. The sexp path (Racket reader) still yields Posit32 for
;;; exponent literals; that reconciliation is deferred to N4 (D7). The sexp
;;; divergence is asserted below so it is captured, not silent.
;;;

(require racket/string
         racket/file
         rackunit
         "test-support.rkt"
         "../syntax.rkt"
         "../surface-syntax.rkt"
         "../parse-reader.rkt"
         "../parser.rkt"
         "../driver.rkt"
         "../posit-impl.rkt")

;; Token accessors (token struct not exported; accessors are)
(define tok-type token-type)
(define tok-val token-value)

(define (number-tok tokens)
  (findf (lambda (t) (eq? (tok-type t) 'number)) tokens))

;; ========================================
;; Reader: tokenization -> 'number token with EXACT value
;; ========================================

(test-case "exp-literal/tokenize-1e10"
  (define tok (number-tok (tokenize-string "1e10")))
  (check-not-false tok "1e10 should produce a number token")
  (check-equal? (tok-val tok) 10000000000 "1e10 -> exact integer"))

(test-case "exp-literal/tokenize-1.5e-3"
  (define tok (number-tok (tokenize-string "1.5e-3")))
  (check-not-false tok "1.5e-3 should produce a number token (not decimal-literal)")
  (check-equal? (tok-val tok) 3/2000 "1.5e-3 -> exact rational 3/2000"))

(test-case "exp-literal/tokenize-neg-1.5e-3"
  (define tok (number-tok (tokenize-string "-1.5e-3")))
  (check-not-false tok "-1.5e-3 should produce a number token")
  (check-equal? (tok-val tok) -3/2000 "-1.5e-3 -> exact rational -3/2000"))

(test-case "exp-literal/tokenize-capital-E"
  (define tok (number-tok (tokenize-string "1E3")))
  (check-not-false tok "1E3 should produce a number token")
  (check-equal? (tok-val tok) 1000 "1E3 -> exact integer 1000"))

(test-case "exp-literal/tokenize-plus-sign"
  (define tok (number-tok (tokenize-string "2e+3")))
  (check-not-false tok "2e+3 should produce a number token")
  (check-equal? (tok-val tok) 2000 "2e+3 -> exact integer 2000"))

;; ========================================
;; Reader: WS round-trip -> plain exact datum (no $decimal-literal sentinel)
;; ========================================

(test-case "exp-literal/ws-roundtrip-int"
  (check-equal? (read-all-forms-string "eval 1e10")
                '((eval 10000000000))))

(test-case "exp-literal/ws-roundtrip-rat"
  (check-equal? (read-all-forms-string "eval 1.5e-3")
                '((eval 3/2000))))

;; ========================================
;; End-to-end (WS string, cell pipeline = REPL/L3 path) -> Int / Rat
;; ========================================

(test-case "exp-literal/ws-eval-1e10-Int"
  (check-equal? (run-ns-ws-last "1e10") "10000000000 : Int"))

(test-case "exp-literal/ws-eval-1.5e-3-Rat"
  (check-equal? (run-ns-ws-last "1.5e-3") "0.0015 : Rat"))

(test-case "exp-literal/ws-eval-neg-1.5e-3-Rat"
  (check-equal? (run-ns-ws-last "-1.5e-3") "-0.0015 : Rat"))

(test-case "exp-literal/ws-eval-2e3-Int"
  (check-equal? (run-ns-ws-last "2e3") "2000 : Int"))

(test-case "exp-literal/ws-eval-integral-exponent-Int"
  ;; 10e-1 = 1 exactly -> integral -> Int
  (check-equal? (run-ns-ws-last "10e-1") "1 : Int"))

;; ========================================
;; Regression: non-exponent literals UNCHANGED
;; ========================================

(test-case "exp-literal/bare-decimal-polymorphic-N4"
  ;; N4: bare 3.14 (no exponent) is now a polymorphic literal → unconstrained Rat
  (define r (run-ns-ws-last "3.14"))
  (check-true (string-contains? r "Rat") "bare 3.14 → Rat (N4 polymorphic)"))

(test-case "exp-literal/regress-int"
  (check-equal? (run-ns-ws-last "42") "42 : Int"))

(test-case "exp-literal/regress-rat"
  (check-equal? (run-ns-ws-last "3/7") "3/7 : Rat"))

(test-case "exp-literal/regress-tilde-exponent-Posit32"
  ;; ~1.5e-3 (tilde already accepted exponents) stays Posit32
  (define r (run-ns-ws-last "~1.5e-3"))
  (check-true (string-contains? r "Posit32") "~1.5e-3 stays Posit32"))

;; ========================================
;; Non-regression: exp-literal must NOT capture arrows / identifiers
;; (it only fires when a real exponent follows)
;; ========================================

(test-case "exp-literal/regress-arrow"
  ;; -> must not be eaten as a number
  (define tok (number-tok (tokenize-string "->")))
  (check-false tok "-> must not produce a number token"))

(test-case "exp-literal/regress-session-arrow"
  ;; -0> stays a session arrow (priority 99), not a number
  (define tok (number-tok (tokenize-string "-0>")))
  (check-false tok "-0> must not produce a number token"))

(test-case "exp-literal/regress-ident-minus"
  ;; x-1e3 stays a single identifier — exp-literal must NOT capture the -1e3
  (check-false (number-tok (tokenize-string "x-1e3"))
               "x-1e3 must not produce a number token (stays an identifier)"))

;; ========================================
;; N4 reconciled the sexp path: a sexp exponent reads as an inexact number →
;; surf-num-lit (polymorphic). 1e10 is integral → unconstrained Int.
;; ========================================

(test-case "exp-literal/sexp-integral-exp-N4-Int"
  (define r (run-ns-last "(eval 1e10)"))
  (check-true (string-contains? r "Int")
              "sexp 1e10 → Int (N4 handles the sexp path N1 deferred)"))

;; ========================================
;; Level 3: WS file via process-file.
;; NOTE: process-file mutates global state the run-ns-* fixture relies on, so this
;; runs LAST — it would otherwise poison subsequent run-ns-* test-cases.
;; ========================================

(test-case "exp-literal/L3-process-file"
  (define tmp (make-temporary-file "n1-~a.prologos"))
  (call-with-output-file tmp
    (lambda (out) (write-string "ns t\n\n1e10\n1.5e-3\n" out))
    #:exists 'truncate/replace)
  (define results (process-file tmp))
  (delete-file tmp)
  (check-true (and (member "10000000000 : Int" results) #t)
              "L3: 1e10 -> Int in a real .prologos file")
  (check-true (and (member "0.0015 : Rat" results) #t)
              "L3: 1.5e-3 -> Rat in a real .prologos file"))
