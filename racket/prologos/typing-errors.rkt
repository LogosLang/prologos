#lang racket/base

;;;
;;; PROLOGOS TYPING-ERRORS
;;; Error-accumulating wrappers around the core type checker.
;;; The core kernel functions (infer, check, etc.) are preserved unchanged
;;; for Maude cross-validation. These wrappers add structured error reporting.
;;;

(require racket/match
         "prelude.rkt"
         "syntax.rkt"
         "reduction.rkt"
         "typing-core.rkt"
         "source-location.rkt"
         "errors.rkt"
         "pretty-print.rkt"
         "global-env.rkt")

(provide infer/err
         check/err
         is-type/err)

;; ========================================
;; Infer with error reporting
;; ========================================
;; Returns (or/c Expr? prologos-error?)
(define (infer/err ctx e [loc srcloc-unknown])
  (let ([result (infer ctx e)])
    (if (expr-error? result)
        (inference-failed-error loc
                                "Could not infer type"
                                (pp-expr e))
        result)))

;; ========================================
;; Check with error reporting
;; ========================================
;; Returns (or/c #t prologos-error?)
(define (check/err ctx e t [loc srcloc-unknown])
  (if (check ctx e t)
      #t
      ;; Try to infer the actual type for a helpful error message
      (let ([actual (infer ctx e)])
        (type-mismatch-error
         loc
         "Type mismatch"
         (pp-expr t)
         (if (expr-error? actual) "<could not infer>" (pp-expr actual))
         (pp-expr e)))))

;; ========================================
;; Is-type with error reporting
;; ========================================
;; Returns (or/c #t prologos-error?)
(define (is-type/err ctx e [loc srcloc-unknown])
  (if (is-type ctx e)
      #t
      (not-a-type-error loc
                         "Expression is not a valid type"
                         (pp-expr e))))
