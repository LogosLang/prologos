#lang racket/base

;;;
;;; PROLOGOS ERRORS
;;; Structured error types for type checking, parsing, and elaboration.
;;; Each error carries a source location and enough context for readable messages.
;;;

(require racket/match
         racket/string
         "source-location.rkt")

(provide
 ;; Error structs
 (struct-out prologos-error)
 (struct-out type-mismatch-error)
 (struct-out unbound-variable-error)
 (struct-out multiplicity-error)
 (struct-out not-a-type-error)
 (struct-out not-a-function-error)
 (struct-out parse-error)
 (struct-out session-error)
 (struct-out inference-failed-error)
 (struct-out arity-error)
 ;; Predicates
 prologos-error?
 ;; Formatting
 format-error)

;; ========================================
;; Error Hierarchy
;; ========================================

;; Base error: source location + message
(struct prologos-error (srcloc message) #:transparent)

;; Type mismatch: expected one type, got another
(struct type-mismatch-error prologos-error (expected actual expr) #:transparent)

;; Unbound variable reference
(struct unbound-variable-error prologos-error (name) #:transparent)

;; Multiplicity violation (QTT)
(struct multiplicity-error prologos-error (variable declared actual) #:transparent)

;; Expression used as a type but is not a valid type
(struct not-a-type-error prologos-error (expr) #:transparent)

;; Expected a function type in application position
(struct not-a-function-error prologos-error (expr type) #:transparent)

;; Parser error: malformed syntax
(struct parse-error prologos-error (datum) #:transparent)

;; Session type error
(struct session-error prologos-error (channel detail) #:transparent)

;; Type inference failed (could not synthesize a type)
(struct inference-failed-error prologos-error (expr) #:transparent)

;; Wrong number of arguments
(struct arity-error prologos-error (form expected got) #:transparent)

;; ========================================
;; Error Formatting
;; ========================================

(define (format-error err)
  (define loc-str (format-srcloc (prologos-error-srcloc err)))
  (define msg (prologos-error-message err))
  (match err
    [(type-mismatch-error _ _ expected actual expr)
     (string-join
      (list (format "Error at ~a" loc-str)
            (format "  ~a" msg)
            (format "  Expected: ~a" (format-val expected))
            (format "  Got:      ~a" (format-val actual))
            (if expr (format "  In expression: ~a" (format-val expr)) ""))
      "\n")]
    [(unbound-variable-error _ _ name)
     (string-join
      (list (format "Error at ~a" loc-str)
            (format "  Unbound variable: ~a" name))
      "\n")]
    [(multiplicity-error _ _ variable declared actual)
     (string-join
      (list (format "Error at ~a" loc-str)
            (format "  ~a" msg)
            (format "  Variable: ~a" variable)
            (format "  Declared multiplicity: ~a" declared)
            (format "  Actual usage: ~a" actual))
      "\n")]
    [(not-a-type-error _ _ expr)
     (string-join
      (list (format "Error at ~a" loc-str)
            (format "  ~a" msg)
            (format "  Expression: ~a" (format-val expr)))
      "\n")]
    [(not-a-function-error _ _ expr type)
     (string-join
      (list (format "Error at ~a" loc-str)
            (format "  ~a" msg)
            (format "  Expression: ~a" (format-val expr))
            (format "  Has type: ~a" (format-val type)))
      "\n")]
    [(parse-error _ _ datum)
     (string-join
      (list (format "Error at ~a" loc-str)
            (format "  ~a" msg)
            (if datum (format "  Near: ~a" datum) ""))
      "\n")]
    [(session-error _ _ channel detail)
     (string-join
      (list (format "Error at ~a" loc-str)
            (format "  ~a" msg)
            (format "  Channel: ~a" channel)
            (if detail (format "  ~a" detail) ""))
      "\n")]
    [(inference-failed-error _ _ expr)
     (string-join
      (list (format "Error at ~a" loc-str)
            (format "  ~a" msg)
            (format "  Expression: ~a" (format-val expr)))
      "\n")]
    [(arity-error _ _ form expected got)
     (string-join
      (list (format "Error at ~a" loc-str)
            (format "  ~a" msg)
            (format "  Form: ~a" form)
            (format "  Expected ~a arguments, got ~a" expected got))
      "\n")]
    [_ ;; base prologos-error
     (string-join
      (list (format "Error at ~a" loc-str)
            (format "  ~a" msg))
      "\n")]))

;; Format a value for display in error messages.
;; Uses write~ style for now; pretty-print will override this later.
(define (format-val v)
  (cond
    [(string? v) v]
    [else (format "~a" v)]))
