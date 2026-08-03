#lang racket/base

;;;
;;; Tests for negative numeric literal support
;;; Covers sexp-mode parser fix (Phase A) and WS-mode reader fix (Phase B).
;;;

(require rackunit
         racket/string
         racket/list
         "test-support.rkt"
         "../parse-reader.rkt"
         "../driver.rkt")

;; ========================================
;; Helpers
;; ========================================

(define (tok-type tokens i)
  (token-type (list-ref tokens i)))

(define (tok-val tokens i)
  (token-value (list-ref tokens i)))

(define (check-contains actual substr [msg #f])
  (define actual-str (if (string? actual) actual (format "~a" actual)))
  (check-true (string-contains? actual-str substr)
              (or msg (format "Expected ~s to contain ~s" actual-str substr))))

;; ========================================
;; 1. Sexp-Mode Negative Literals (Phase A)
;; ========================================

(test-case "neg-lit/sexp: bare negative integer"
  (check-equal?
   (run-ns-last
    (string-append
     "(ns neg-sexp1)\n"
     "(eval -42)\n"))
   "-42 : Int"))

(test-case "neg-lit/sexp: bare negative integer -1"
  (check-equal?
   (run-ns-last
    (string-append
     "(ns neg-sexp2)\n"
     "(eval -1)\n"))
   "-1 : Int"))

(test-case "neg-lit/sexp: zero still works"
  (check-equal?
   (run-ns-last
    (string-append
     "(ns neg-sexp3)\n"
     "(eval 0)\n"))
   "0 : Int"))

(test-case "neg-lit/sexp: positive still works"
  (check-equal?
   (run-ns-last
    (string-append
     "(ns neg-sexp4)\n"
     "(eval 42)\n"))
   "42 : Int"))

(test-case "neg-lit/sexp: bare negative rational"
  ;; -3/7 is already parsed correctly in sexp mode (matches exact-rational branch)
  (check-equal?
   (run-ns-last
    (string-append
     "(ns neg-sexp5)\n"
     "(eval -3/7)\n"))
   "-3/7 : Rat"))

(test-case "neg-lit/sexp: arithmetic with bare negative"
  (check-equal?
   (run-ns-last
    (string-append
     "(ns neg-sexp6)\n"
     "(eval (int+ -3 5))\n"))
   "2 : Int"))

;; ========================================
;; 2. WS-Mode Tokenizer (Phase B)
;; ========================================

(test-case "neg-lit/tokenize: negative integer -42"
  (define toks (tokenize-string "-42"))
  (check-equal? (tok-type toks 1) 'number)
  (check-equal? (tok-val toks 1) -42))

(test-case "neg-lit/tokenize: negative integer -1"
  (define toks (tokenize-string "-1"))
  (check-equal? (tok-type toks 1) 'number)
  (check-equal? (tok-val toks 1) -1))

(test-case "neg-lit/tokenize: negative fraction -3/7"
  (define toks (tokenize-string "-3/7"))
  (check-equal? (tok-type toks 1) 'number)
  (check-equal? (tok-val toks 1) -3/7))

(test-case "neg-lit/tokenize: negative decimal -3.14"
  (define toks (tokenize-string "-3.14"))
  (check-equal? (tok-type toks 1) 'decimal-literal)
  (check-equal? (tok-val toks 1) -157/50))

(test-case "neg-lit/tokenize: negative Nat -3N errors"
  (check-exn exn:fail?
    (lambda () (tokenize-string "-3N"))))

;; ========================================
;; 3. WS Reader Roundtrip (Phase B)
;; ========================================

(test-case "neg-lit/roundtrip: eval -42"
  (check-equal? (read-all-forms-string "eval -42")
                '((eval -42))))

(test-case "neg-lit/roundtrip: eval -3/7"
  ;; Slash-containing number lexemes are wrapped in a $rat-literal sentinel
  ;; by the WS reader so that `0/1`, `1/1`, etc. retain Rat-ness even when
  ;; string->number would simplify them to integers. (See eigentrust pitfalls
  ;; doc #3 and tests/test-rat-literal-in-list.rkt.)
  (check-equal? (read-all-forms-string "eval -3/7")
                '((eval ($rat-literal -3/7)))))

(test-case "neg-lit/roundtrip: def x -5"
  (check-equal? (read-all-forms-string "def x -5")
                '((def x -5))))

;; ========================================
;; 4. Negative Approximate Literals (Phase B.2)
;; ========================================

(test-case "neg-lit/tokenize: ~N forms are rejected with a migration hint (N6c)"
  ;; ~ approximate literals were removed; negatives included. The tokenizer no
  ;; longer RAISES — it emits a `tilde-number` token that the parser turns into
  ;; one per-command error, so the rest of the file survives.
  (for ([src (in-list (list "~-42" "~-3.14" "~-3/7" "~-3N"))])
    (define toks (tokenize-string src))
    (check-true (for/or ([t (in-list toks)]) (eq? (compat-token-type t) 'tilde-number))
                (format "~a should tokenize to a tilde-number marker, got: ~v" src toks))))

;; ========================================
;; 5. Non-Regression: Arrows Still Work
;; ========================================

(test-case "neg-lit/arrows: -> unchanged"
  (define toks (tokenize-string "->"))
  (check-equal? (tok-val toks 1) '->))

(test-case "neg-lit/arrows: -0> unchanged"
  (define toks (tokenize-string "-0>"))
  (check-equal? (tok-val toks 1) '-0>))

(test-case "neg-lit/arrows: -1> unchanged"
  (define toks (tokenize-string "-1>"))
  (check-equal? (tok-val toks 1) '-1>))

(test-case "neg-lit/arrows: -w> unchanged"
  (define toks (tokenize-string "-w>"))
  (check-equal? (tok-val toks 1) '-w>))

;; ========================================
;; 6. Non-Regression: Minus as Identifier
;; ========================================

(test-case "neg-lit/ident: - standalone (space after)"
  ;; `- ` with a space means the `-` is an identifier, not a negative prefix
  (define toks (tokenize-string "- 3"))
  ;; First non-newline token should be symbol `-`
  (check-equal? (tok-type toks 1) 'symbol)
  (check-equal? (tok-val toks 1) '-))

(test-case "neg-lit/ident: -foo stays identifier"
  (define toks (tokenize-string "-foo"))
  (check-equal? (tok-type toks 1) 'symbol)
  (check-equal? (tok-val toks 1) '-foo))

;; ========================================
;; 7. End-to-End: WS-Mode Eval
;; ========================================

(test-case "neg-lit/e2e: decimal -3.14 is polymorphic (N6b: Posit32 default)"
  ;; -3.14 → $decimal-literal(-157/50) → surf-num-lit 'decimal → unconstrained Posit32
  (check-contains
   (run-ns-last
    (string-append
     "(ns neg-e2e-dec)\n"
     "(eval ($decimal-literal -157/50))\n"))
   "Posit32"))
