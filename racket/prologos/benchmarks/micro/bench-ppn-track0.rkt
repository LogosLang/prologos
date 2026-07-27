#lang racket/base

;;;
;;; PPN Track 0 Lattice Design Benchmarks: RETIRED at 1A-iii-b per
;;; §7.7 β1 + §7.9 refined ε1 (deprecated ATMS internal API retirement).
;;;
;;; ============================================================
;;; 1A-iii-b β1 RETIREMENT (2026-05-17)
;;; ============================================================
;;;
;;; This file's E-series benchmarks measured deprecated `atms-*` API
;;; performance (atms-empty / atms-assume / atms-amb / atms-retract /
;;; atms-write-cell) as comparison points for PPN Track 0 lattice design
;;; decisions. Under 1A-iii-b retirement, all 13 deprecated atms-*
;;; functions + the `atms` struct + atms-believed field + atms-empty +
;;; supported-value/tms-cell structs + assumption-id-hash are retired
;;; (per §7.7 α1+α3 + §7.9 refined ε1).
;;;
;;; HISTORICAL DATA preserved in git history at commit `8399b35d` (last
;;; commit before 1A-iii-b retirement at HEAD `2a0af127` baseline).
;;;
;;; POST-1A-iii-b INFRASTRUCTURE (use these for modern measurements):
;;;   - Modern solver-context API (atms.rkt:solver-* operations) replaces
;;;     deprecated atms-* internal API.
;;;   - PPN Track 0 architectural conclusions preserved in:
;;;       docs/tracking/2026-03-26_PPN_TRACK0_DESIGN.md
;;;       docs/tracking/2026-03-26_PPN_TRACK0_PIR.md
;;;
;;; RATIONALE (per §7.7 β1): "Retire BOTH bench files with ε2-style
;;; annotations — measured legacy ATMS internal patterns from pre-
;;; solver-context era; obsolete-pattern-only; modern tracks have current
;;; benches in modern API; duplication risk if migrated."
;;;
;;; ============================================================

(displayln "============================================================")
(displayln "bench-ppn-track0.rkt: RETIRED at 1A-iii-b per §7.7 β1")
(displayln "============================================================")
(displayln "")
(displayln "This benchmark file's E-series measured deprecated ATMS")
(displayln "internal API performance (atms-empty / atms-assume / atms-amb /")
(displayln "atms-retract / atms-write-cell) as PPN Track 0 comparison points.")
(displayln "")
(displayln "All 13 deprecated atms-* functions retired at 1A-iii-b.")
(displayln "Historical bench code preserved in git history at commit `8399b35d`.")
(displayln "")
(displayln "Modern equivalents: solver-context API in atms.rkt (Phase 5.6).")
(displayln "Architectural conclusions preserved in:")
(displayln "  docs/tracking/2026-03-26_PPN_TRACK0_DESIGN.md")
(displayln "  docs/tracking/2026-03-26_PPN_TRACK0_PIR.md")
