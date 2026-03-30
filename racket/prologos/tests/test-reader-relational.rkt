#lang racket/base

;;;
;;; Tests for reader.rkt — Relational Language Tokens
;;; Phase 7b: ||, &>, mode prefix tokens
;;;

(require rackunit
         "../parse-reader.rkt")

;; ========================================
;; Helpers (same as test-reader.rkt)
;; ========================================

(define (tok-type tokens i)
  (token-type (list-ref tokens i)))

(define (tok-val tokens i)
  (token-value (list-ref tokens i)))

;; ========================================
;; || (fact-block separator)
;; ========================================

(test-case "tokenize: || → $facts-sep"
  (define toks (tokenize-string "||"))
  ;; newline + symbol + eof
  (check-equal? (tok-type toks 1) 'symbol)
  (check-equal? (tok-val toks 1) '$facts-sep))

(test-case "tokenize: | alone → $pipe (unchanged)"
  (define toks (tokenize-string "| foo"))
  (check-equal? (tok-type toks 1) 'symbol)
  (check-equal? (tok-val toks 1) '$pipe))

(test-case "tokenize: |> → $pipe-gt (unchanged)"
  (define toks (tokenize-string "|> foo"))
  (check-equal? (tok-type toks 1) 'symbol)
  (check-equal? (tok-val toks 1) '$pipe-gt))

;; ========================================
;; &> (clause separator)
;; ========================================

(test-case "tokenize: &> → $clause-sep"
  (define toks (tokenize-string "&>"))
  (check-equal? (tok-type toks 1) 'symbol)
  (check-equal? (tok-val toks 1) '$clause-sep))

(test-case "tokenize: & alone → error"
  (check-exn exn:fail?
    (lambda () (tokenize-string "& foo"))))

;; ========================================
;; Mode prefixes (already work as ident symbols)
;; ========================================

(test-case "tokenize: ?x → symbol ?x"
  (define toks (tokenize-string "?x"))
  (check-equal? (tok-type toks 1) 'symbol)
  (check-equal? (tok-val toks 1) '?x))

(test-case "tokenize: +x → symbol +x"
  (define toks (tokenize-string "+x"))
  (check-equal? (tok-type toks 1) 'symbol)
  (check-equal? (tok-val toks 1) '+x))

(test-case "tokenize: -x → symbol -x"
  (define toks (tokenize-string "-x"))
  (check-equal? (tok-type toks 1) 'symbol)
  (check-equal? (tok-val toks 1) '-x))

;; ========================================
;; Mixed relational context
;; ========================================

(test-case "tokenize: || followed by data"
  ;; || "alice" "bob"
  (define toks (tokenize-string "|| \"alice\" \"bob\""))
  (check-equal? (tok-val toks 1) '$facts-sep)
  (check-equal? (tok-type toks 2) 'string)
  (check-equal? (tok-val toks 2) "alice"))

(test-case "tokenize: &> followed by parens"
  ;; &> (parent x y)
  (define toks (tokenize-string "&> (parent x y)"))
  (check-equal? (tok-val toks 1) '$clause-sep)
  (check-equal? (tok-type toks 2) 'lparen))
