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
         format-deprecation-warning
         ;; Capability warnings (W2001)
         current-capability-warnings
         capability-warning
         capability-warning?
         capability-warning-name
         capability-warning-multiplicity
         emit-capability-warning!
         format-capability-warning
         ;; Process capability warnings (W2002, W2003)
         process-cap-warning
         process-cap-warning?
         process-cap-warning-code
         process-cap-warning-name
         process-cap-warning-message
         emit-process-cap-warning!
         format-process-cap-warning)

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

;; ========================================
;; Capability warnings (W2001)
;; ========================================

;; Accumulator for capability warnings (list of warning structs).
;; Reset per-command in driver.rkt.
(define current-capability-warnings (make-parameter '()))

;; A capability warning: name is the capability type name (symbol),
;; multiplicity is the declared multiplicity ('mw typically).
;; W2001: Unrestricted (:w) on a capability — consider :0 (authority proof) or :1 (authority transfer).
(struct capability-warning (name multiplicity) #:transparent)

;; Emit a capability warning.
(define (emit-capability-warning! name mult)
  (current-capability-warnings
   (cons (capability-warning name mult)
         (current-capability-warnings))))

;; Format a capability warning for display.
(define (format-capability-warning w)
  (format "W2001: Unrestricted :w on capability ~a — consider :0 (authority proof) or :1 (authority transfer)."
          (capability-warning-name w)))

;; ========================================
;; Process capability warnings (W2002, W2003)
;; ========================================

;; W2002: Dead authority — process declares a capability binder but never uses it.
;; W2003: Ambient authority — process header uses :w multiplicity on a cap.
;; These are accumulated in the same current-capability-warnings list (shared accumulator).
(struct process-cap-warning (code name message) #:transparent)

;; Emit a process capability warning.
(define (emit-process-cap-warning! code name msg)
  (current-capability-warnings
   (cons (process-cap-warning code name msg)
         (current-capability-warnings))))

;; Format a process capability warning for display.
(define (format-process-cap-warning w)
  (format "~a: ~a — ~a"
          (process-cap-warning-code w)
          (process-cap-warning-name w)
          (process-cap-warning-message w)))
