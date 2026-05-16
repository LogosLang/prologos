#lang racket/base
;;;
;;; specialized-cells.rkt — D.4 1B-ii thin convenience layer (Shape 2)
;;;
;;; Per docs/tracking/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md
;;; §9.2.A + §9.2.0.5 Q-1B-ii-γ resolution: cell-meta struct + registration
;;; API + dispatch logic live in propagator.rkt; this module provides:
;;; - Re-exports of `specialized-cell-meta` + `net-register-specialized-cell`
;;; - Convenience constructors for the two specialized-cell patterns
;;;   Phase 1B/1C ships (monotone-counter + cold-general)
;;;
;;; Future PReduce / OE / SH Series tracks adding specialized cells extend
;;; this module with new convenience constructors without modifying
;;; propagator.rkt. The cell-meta struct + dispatch stay in propagator.rkt.
;;;

(require "propagator.rkt")

(provide
 (struct-out specialized-cell-meta)
 net-register-specialized-cell
 make-monotone-counter-meta
 make-cold-general-meta)

;; Convenience constructor for hot+monotone-counter cells with an on-write
;; check (e.g., the fuel-cost-cell pattern: cost crosses budget → contradiction).
;;
;; on-write-check: (old new net → boolean) — predicate that runs inline at
;;   write-time; if returns truthy, contradiction is written structurally
;;   (the cell-id becomes the network's contradiction cell).
;;
;; fires-on defaults to 'threshold-crossing — dependent propagators are
;; notified only when on-write-check fires (signaling threshold crossed).
;; Skips dep enqueuing on the common case (cost grows but doesn't cross).
(define (make-monotone-counter-meta on-write-check)
  (specialized-cell-meta 'hot 'monotone-counter 'threshold-crossing
                         on-write-check
                         #f))

;; Convenience constructor for cold+general cells (write-rarely, no
;; specialized dispatch needed; e.g., fuel-budget-cell). The cell takes
;; the existing slow path of net-cell-write (no fast-path optimization)
;; — the meta exists so the cell is registered as a specialized cell in
;; the framework's accounting, but dispatch falls through unchanged.
(define (make-cold-general-meta)
  (specialized-cell-meta 'cold 'general 'any-change #f #f))
