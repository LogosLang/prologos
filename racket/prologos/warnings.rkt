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
         ;; Track 6 Phase 7c: elaboration guard for dual-write elimination
         current-warnings-in-elaboration?
         sync-warning-cells-to-params!
         ;; Track 3 Phase 4: cell-primary readers
         read-coercion-warnings
         read-deprecation-warnings
         read-capability-warnings)

(require "infra-cell.rkt")  ;; merge-list-append

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

;; Helper: dual-write a warning to a list cell.
;; value should be a list with one element — the cell's merge function
;; (merge-list-append) will append it to existing warnings.
(define (warnings-cell-write! cid value)
  (define net-box (current-warnings-prop-net-box))
  (define write-fn (current-warnings-prop-cell-write))
  (when (and net-box write-fn cid)
    (set-box! net-box (write-fn (unbox net-box) cid value))))

;; Create warning cells in the propagator network.
;; Called per-command after reset-meta-store!, since the network is fresh.
;; Initializes each cell from the current legacy parameter content.
(define (register-warning-cells! net-box new-cell-fn)
  (when (and net-box new-cell-fn)
    (current-warnings-prop-net-box net-box)
    (define enet0 (unbox net-box))
    (define-values (enet1 cw-cid) (new-cell-fn enet0 (current-coercion-warnings) merge-list-append))
    (current-coercion-warnings-cell-id cw-cid)
    (define-values (enet2 dw-cid) (new-cell-fn enet1 (current-deprecation-warnings) merge-list-append))
    (current-deprecation-warnings-cell-id dw-cid)
    (define-values (enet3 capw-cid) (new-cell-fn enet2 (current-capability-warnings) merge-list-append))
    (current-capability-warnings-cell-id capw-cid)
    (set-box! net-box enet3)))

;; Track 6 Phase 7c: elaboration guard for dual-write elimination.
;; Set to #t inside process-command's inner parameterize (same scope as macros guard).
(define current-warnings-in-elaboration? (make-parameter #f))

;; Track 6 Phase 7c: sync cell values back to parameters at end of successful process-command.
;; Direct cell read bypassing any guard, since this runs after the inner parameterize exits.
(define (sync-warning-cells-to-params!)
  (define net-box (current-warnings-prop-net-box))
  (define read-fn (current-warnings-prop-cell-read))
  (define (sync! cid param-setter)
    (when (and cid net-box read-fn)
      (with-handlers ([exn:fail? void])
        (param-setter (read-fn (unbox net-box) cid)))))
  (sync! (current-coercion-warnings-cell-id) current-coercion-warnings)
  (sync! (current-deprecation-warnings-cell-id) current-deprecation-warnings)
  (sync! (current-capability-warnings-cell-id) current-capability-warnings))

;; Track 3 Phase 4: cell-primary read helper for warnings.
;; Simpler than macros-cell-read-safe — no elaboration guard needed because
;; warning reads only occur inside process-command (driver.rkt).
(define (warnings-cell-read-safe cid)
  (define net-box (current-warnings-prop-net-box))
  (define read-fn (current-warnings-prop-cell-read))
  (if (and cid net-box read-fn)
      (with-handlers ([exn:fail? (λ (_) 'not-found)])
        (read-fn (unbox net-box) cid))
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
  ;; Track 6 Phase 7c: cell-only during elaboration; param-only outside.
  (if (current-warnings-in-elaboration?)
      (warnings-cell-write! (current-coercion-warnings-cell-id) (list w))
      (current-coercion-warnings (cons w (current-coercion-warnings)))))

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
  ;; Track 6 Phase 7c: cell-only during elaboration; param-only outside.
  (if (current-warnings-in-elaboration?)
      (warnings-cell-write! (current-deprecation-warnings-cell-id) (list w))
      (current-deprecation-warnings (cons w (current-deprecation-warnings)))))

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
  ;; Track 6 Phase 7c: cell-only during elaboration; param-only outside.
  (if (current-warnings-in-elaboration?)
      (warnings-cell-write! (current-capability-warnings-cell-id) (list w))
      (current-capability-warnings (cons w (current-capability-warnings)))))

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
  ;; Track 6 Phase 7c: cell-only during elaboration; param-only outside.
  (if (current-warnings-in-elaboration?)
      (warnings-cell-write! (current-capability-warnings-cell-id) (list w))
      (current-capability-warnings (cons w (current-capability-warnings)))))

;; Format a process capability warning for display.
(define (format-process-cap-warning w)
  (format "~a: ~a — ~a"
          (process-cap-warning-code w)
          (process-cap-warning-name w)
          (process-cap-warning-message w)))
