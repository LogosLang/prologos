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
         format-process-cap-warning
         ;; Phase 2c: Warning cell infrastructure
         current-warnings-prop-net-box
         current-warnings-prop-cell-write
         current-warnings-prop-cell-read
         current-coercion-warnings-cell-id
         current-deprecation-warnings-cell-id
         current-capability-warnings-cell-id
         register-warning-cells!
         init-warning-cells!
         ;; Track 3 Phase 4: cell-primary readers
         read-coercion-warnings
         read-deprecation-warnings
         read-capability-warnings)

(require "infra-cell.rkt"        ;; merge-list-append
         "propagator.rkt"        ;; Track 7 Phase 2: net-new-cell, net-cell-read, net-cell-write
         "metavar-store.rkt")    ;; Track 7 Phase 2: current-persistent-registry-net-box

;; ========================================
;; Phase 2c: Propagator-First Migration — Warning Cell Infrastructure
;; ========================================
;; Callback parameters for network access (set by driver.rkt).
(define current-warnings-prop-net-box (make-parameter #f))
(define current-warnings-prop-cell-write (make-parameter #f))
(define current-warnings-prop-cell-read (make-parameter #f))  ;; Track 3 Phase 4: (enet cell-id → value)
;; Cell-id parameters for each warning accumulator.
(define current-coercion-warnings-cell-id (make-parameter #f))
(define current-deprecation-warnings-cell-id (make-parameter #f))
(define current-capability-warnings-cell-id (make-parameter #f))

;; Helper: write a warning to a list cell in the persistent network.
;; Track 7 Phase 2: targets persistent registry network directly.
(define (warnings-cell-write! cid value)
  (define prn-box (current-persistent-registry-net-box))
  (when (and prn-box cid)
    (set-box! prn-box (net-cell-write (unbox prn-box) cid value))))

;; Track 7 Phase 2: Initialize warning cells in the persistent registry network.
;; Called ONCE from init-persistent-registry-network!.
(define (init-warning-cells! prn-box)
  (when prn-box
    (define net0 (unbox prn-box))
    (define-values (net1 cw-cid) (net-new-cell net0 (current-coercion-warnings) merge-list-append))
    (current-coercion-warnings-cell-id cw-cid)
    (define-values (net2 dw-cid) (net-new-cell net1 (current-deprecation-warnings) merge-list-append))
    (current-deprecation-warnings-cell-id dw-cid)
    (define-values (net3 capw-cid) (net-new-cell net2 (current-capability-warnings) merge-list-append))
    (current-capability-warnings-cell-id capw-cid)
    (set-box! prn-box net3)))

;; Legacy: per-command warning cell creation.
;; Track 7 Phase 2: no-op — cells now in persistent network.
(define (register-warning-cells! net-box new-cell-fn)
  (void))

;; Track 7 Phase 2: cell-primary read from persistent registry network.
(define (warnings-cell-read-safe cid)
  (define prn-box (current-persistent-registry-net-box))
  (if (and cid prn-box)
      (with-handlers ([exn:fail? (λ (_) 'not-found)])
        (net-cell-read (unbox prn-box) cid))
      'not-found))

;; Track 3 Phase 4: cell-primary readers for warning accumulators
(define (read-coercion-warnings)
  (define v (warnings-cell-read-safe (current-coercion-warnings-cell-id)))
  (if (eq? v 'not-found) (current-coercion-warnings) v))

(define (read-deprecation-warnings)
  (define v (warnings-cell-read-safe (current-deprecation-warnings-cell-id)))
  (if (eq? v 'not-found) (current-deprecation-warnings) v))

(define (read-capability-warnings)
  (define v (warnings-cell-read-safe (current-capability-warnings-cell-id)))
  (if (eq? v 'not-found) (current-capability-warnings) v))

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
  (define w (coercion-warning from-str to-str))
  (current-coercion-warnings (cons w (current-coercion-warnings)))
  ;; Phase 2c: dual-write to cell
  (warnings-cell-write! (current-coercion-warnings-cell-id) (list w)))

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
  (define w (deprecation-warning name msg))
  (current-deprecation-warnings (cons w (current-deprecation-warnings)))
  ;; Phase 2c: dual-write to cell
  (warnings-cell-write! (current-deprecation-warnings-cell-id) (list w)))

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
  (define w (capability-warning name mult))
  (current-capability-warnings (cons w (current-capability-warnings)))
  ;; Phase 2c: dual-write to cell
  (warnings-cell-write! (current-capability-warnings-cell-id) (list w)))

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
  (define w (process-cap-warning code name msg))
  (current-capability-warnings (cons w (current-capability-warnings)))
  ;; Phase 2c: dual-write to cell (shared with capability warnings)
  (warnings-cell-write! (current-capability-warnings-cell-id) (list w)))

;; Format a process capability warning for display.
(define (format-process-cap-warning w)
  (format "~a: ~a — ~a"
          (process-cap-warning-code w)
          (process-cap-warning-name w)
          (process-cap-warning-message w)))
