#lang racket/base
;; ============================================================================
;; keyword-ops.rkt — Racket-side Keyword utilities (passthrough marshalling).
;;
;; CIU T6 F1b.5-s1 (D27, owner Q2). Keyword is a foreign PASSTHROUGH type — the
;; Racket function receives the expr-keyword IR value directly (NOT a Racket
;; keyword), so racket/base's own keyword->string/symbol->string cannot be used
;; on it. These IR-unwrap shims (the path-ops.rkt pattern) give the language a
;; Keyword→String and a Keyword ordering, which the stdlib otherwise lacks (no
;; Keyword Eq/Ord instance) — enabling the deterministic errors-to-list render.
;; ============================================================================

(require "syntax.rkt")

(provide kw-name kw-lte)

;; kw-name : Keyword -> String   (returns a Racket string; marshalled to expr-string)
(define (kw-name kw)
  (unless (expr-keyword? kw)
    (error 'keyword-name "expected a Keyword value, got ~a" kw))
  (symbol->string (expr-keyword-name kw)))

;; kw-lte : Keyword -> Keyword -> Bool   (total order on keyword names)
(define (kw-lte a b)
  (unless (and (expr-keyword? a) (expr-keyword? b))
    (error 'keyword-lte "expected Keyword values, got ~a and ~a" a b))
  (string<=? (symbol->string (expr-keyword-name a))
             (symbol->string (expr-keyword-name b))))
