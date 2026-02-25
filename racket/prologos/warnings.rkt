#lang racket/base

;;;
;;; PROLOGOS WARNINGS
;;; Informational warnings (non-fatal) emitted during type checking.
;;; Accumulated via a parameterized list and displayed after command processing.
;;;

(provide current-coercion-warnings
         emit-coercion-warning!
         format-coercion-warning
         ;; Deprecation warnings
         current-deprecation-warnings
         deprecation-warning
         deprecation-warning?
         deprecation-warning-name
         deprecation-warning-message
         emit-deprecation-warning!
         format-deprecation-warning)

;; ========================================
;; Coercion warnings
;; ========================================

;; Accumulator for coercion warnings (list of warning structs).
;; Reset per-command in driver.rkt.
(define current-coercion-warnings (make-parameter '()))

;; A coercion warning: from-type-str and to-type-str are human-readable names.
(struct coercion-warning (from-type-str to-type-str) #:transparent)

;; Emit a coercion warning (exact → approximate).
;; from-str, to-str: strings like "Int", "Posit32"
(define (emit-coercion-warning! from-str to-str)
  (current-coercion-warnings
   (cons (coercion-warning from-str to-str)
         (current-coercion-warnings))))

;; Format a coercion warning for display.
(define (format-coercion-warning w)
  (format "warning: implicit coercion from ~a to ~a (loss of exactness)"
          (coercion-warning-from-type-str w)
          (coercion-warning-to-type-str w)))

;; ========================================
;; Deprecation warnings
;; ========================================

;; Accumulator for deprecation warnings (list of warning structs).
;; Reset per-command in driver.rkt.
(define current-deprecation-warnings (make-parameter '()))

;; A deprecation warning: name is the deprecated function/spec name (symbol),
;; message is an optional string (e.g., "use foo-v2 instead") or #f.
(struct deprecation-warning (name message) #:transparent)

;; Emit a deprecation warning.
(define (emit-deprecation-warning! name msg)
  (current-deprecation-warnings
   (cons (deprecation-warning name msg)
         (current-deprecation-warnings))))

;; Format a deprecation warning for display.
(define (format-deprecation-warning w)
  (format "warning: ~a is deprecated~a"
          (deprecation-warning-name w)
          (if (deprecation-warning-message w)
              (format " — ~a" (deprecation-warning-message w))
              "")))
