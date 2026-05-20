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
 make-cold-general-meta
 make-warm-general-meta)  ;; PPN 4C Phase 2A.0 (2026-05-19)

;; Convenience constructor for hot+monotone-counter cells with an on-write
;; check (e.g., the fuel-cost-cell pattern: cost crosses budget → contradiction).
;;
;; merge-fn: (old new → merged) — the merge function for this cell's lattice
;;   value. Cached on the meta struct (per D.4 1V-2 Item #1 / §11.X.2 α1) for
;;   fast-path dispatch in net-cell-write (eliminates per-call champ-lookup).
;;   Per F17: callers must pass merge-fn explicitly (no longer optional).
;; on-write-check: (old new net → boolean) — predicate that runs inline at
;;   write-time; if returns truthy, contradiction is written structurally
;;   (the cell-id becomes the network's contradiction cell).
;;
;; fires-on defaults to 'threshold-crossing — dependent propagators are
;; notified only when on-write-check fires (signaling threshold crossed).
;; Skips dep enqueuing on the common case (cost grows but doesn't cross).
(define (make-monotone-counter-meta merge-fn on-write-check)
  (specialized-cell-meta 'hot 'monotone-counter 'threshold-crossing
                         on-write-check
                         #f
                         merge-fn))

;; Convenience constructor for cold+general cells (write-rarely, no
;; specialized dispatch needed; e.g., fuel-budget-cell). The cell takes
;; the existing slow path of net-cell-write (no fast-path optimization)
;; — the meta exists so the cell is registered as a specialized cell in
;; the framework's accounting, but dispatch falls through unchanged.
;;
;; merge-fn: optional (defaults to #f) — for symmetry with monotone-counter
;; meta and forward-compatibility with future specialized cell patterns. On
;; the slow path, the registry is the source-of-truth (per γ1 dual-storage
;; rationale + F13); meta's merge-fn is unused for cold+general cells today.
(define (make-cold-general-meta [merge-fn #f])
  (specialized-cell-meta 'cold 'general 'any-change #f #f merge-fn))

;; PPN 4C Phase 2A.0 (2026-05-19) — warm+general cells for stratum-request
;; accumulators (S(-1) retraction, L2 resolution). These cells accumulate
;; work via writes from propagators during BSP rounds; the corresponding
;; stratum handler reads + processes between rounds; BSP outer-loop
;; auto-clears via the handler's `#:reset-value`.
;;
;; Tier 'warm: not hot like fuel-cell-id (no direct-ref cache on prop-net-warm);
;; not cold like fuel-budget-cell-id (written more than once-per-init).
;; Storage 'general: hashmap/set/list value, not specialized fixnum.
;; Fires-on 'any-change: handler runs whenever pending state is non-empty
;; (no threshold-crossing optimization; standard cell-write notification).
;;
;; merge-fn: callers must pass explicitly (set-union, list-append, hash-union, etc.).
;; Cached on the meta struct per §4.6 framework + D.4 1V-2 Item #1 pattern.
;;
;; Forward-compatibility: if a stratum-request cell becomes hot (e.g.,
;; PReduce e-class extraction work-queue), promote to `make-monotone-counter-meta`
;; pattern OR allocate a direct-ref cache on prop-net-warm (4th+ instance
;; of cross-track template per §4.6 framework). Cell-meta declaration is
;; the upgrade vocabulary; no caller-API change.
(define (make-warm-general-meta merge-fn)
  (specialized-cell-meta 'warm 'general 'any-change #f #f merge-fn))
