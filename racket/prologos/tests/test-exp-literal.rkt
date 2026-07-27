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
  ;; N6b: non-integral exponent lexemes carry the $exp-literal sentinel (the
  ;; token identity is erased at tokenize, so the lexeme check preserves
  ;; notation origin — like $rat-literal for `/`); integral exps stay bare.
  (check-equal? (read-all-forms-string "eval 1.5e-3")
                '((eval ($exp-literal 3/2000)))))

;; ========================================
;; End-to-end (WS string, cell pipeline = REPL/L3 path) -> Int / Rat
;; ========================================

(test-case "exp-literal/ws-eval-1e10-Int"
  (check-equal? (run-ns-ws-last "1e10") "10000000000 : Int"))

(test-case "exp-literal/ws-eval-1.5e-3-Posit32"
  ;; N6b: non-integral exponents default Posit32 (exponent origin via $exp-literal)
  (check-equal? (run-ns-ws-last "1.5e-3") "0.0015 : Posit32"))

(test-case "exp-literal/ws-eval-neg-1.5e-3-Posit32"
  (check-equal? (run-ns-ws-last "-1.5e-3") "-0.0015 : Posit32"))

(test-case "exp-literal/ws-eval-2e3-Int"
  (check-equal? (run-ns-ws-last "2e3") "2000 : Int"))

(test-case "exp-literal/ws-eval-integral-exponent-Int"
  ;; 10e-1 = 1 exactly -> integral -> Int
  (check-equal? (run-ns-ws-last "10e-1") "1 : Int"))

;; ========================================
;; Regression: non-exponent literals UNCHANGED
;; ========================================

(test-case "exp-literal/bare-decimal-polymorphic"
  ;; N6b: bare 3.14 is a polymorphic literal, decimal origin → Posit32 default
  (define r (run-ns-ws-last "3.14"))
  (check-true (string-contains? r "Posit32") "bare 3.14 → Posit32 (N6b decimal default)"))

(test-case "exp-literal/regress-int"
  (check-equal? (run-ns-ws-last "42") "42 : Int"))

(test-case "exp-literal/regress-rat"
  (check-equal? (run-ns-ws-last "3/7") "3/7 : Rat"))

(test-case "exp-literal/regress-pNN-exponent-Posit64 (N6c: ~ removed)"
  ;; exponent-composed pNN literal takes the explicit width
  (define r (run-ns-ws-last "1.5e-3p64"))
  (check-true (string-contains? r "Posit64") "1.5e-3p64 is Posit64"))

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
;; Sexp path (internal IR): a sexp exponent reads as an INEXACT flonum —
;; indistinguishable from a decimal (1e10 ≡ 1.0's shape) → decimal origin →
;; Posit32 (N6b). This is the documented sexp/WS exponent asymmetry: WS is
;; authoritative (WS 1e10 → Int, asserted above); sexp mode cannot recover
;; exponent notation from Racket's reader.
;; ========================================

(test-case "exp-literal/sexp-integral-exp-decimal-origin"
  (define r (run-ns-last "(eval 1e10)"))
  (check-true (string-contains? r "Posit32")
              "sexp 1e10 → Posit32 (decimal origin; documented sexp/WS asymmetry)"))

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
  (check-true (and (member "0.0015 : Posit32" results) #t)
              "L3: 1.5e-3 -> Posit32 in a real .prologos file (N6b)"))
