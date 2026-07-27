#lang racket/base

;;;
;;; BSP-LE Track 2 ATMS Performance Benchmarks: RETIRED at 1A-iii-b per
;;; §7.7 β1 + §7.9 refined ε1 (deprecated ATMS internal API retirement).
;;;
;;; ============================================================
;;; 1A-iii-b β1 RETIREMENT (2026-05-17)
;;; ============================================================
;;;
;;; This file's benchmarks measured Tier 2 deprecated `atms-*` API
;;; performance (atms-empty / atms-assume / atms-amb / atms-with-worldview /
;;; atms-read-cell / atms-write-cell). Under 1A-iii-b retirement, all 13
;;; deprecated atms-* functions + the `atms` struct + atms-believed field +
;;; atms-empty constructor + supported-value/tms-cell structs +
;;; assumption-id-hash are retired (per §7.7 α1+α3 + §7.9 refined ε1).
;;;
;;; HISTORICAL DATA preserved in git history at commit `8399b35d` (last
;;; commit before 1A-iii-b retirement at HEAD `2a0af127` baseline).
;;;
;;; POST-1A-iii-b INFRASTRUCTURE (use these for modern measurements):
;;;   - Modern solver-context API (atms.rkt:solver-* operations) replaces
;;;     deprecated atms-* internal API.
;;;   - BSP-LE Track 2 + 2B PIRs preserve the architectural conclusions:
;;;       docs/tracking/2026-04-10_BSP_LE_TRACK2_PIR.md
;;;       docs/tracking/2026-04-16_BSP_LE_TRACK2B_PIR.md
;;;
;;; RATIONALE (per §7.7 β1): "Retire BOTH bench files with ε2-style
;;; annotations — measured legacy ATMS internal patterns from pre-
;;; solver-context era; obsolete-pattern-only; modern tracks have current
;;; benches in modern API; duplication risk if migrated."
;;;
;;; ============================================================

(displayln "============================================================")
(displayln "bench-bsp-le-track2.rkt: RETIRED at 1A-iii-b per §7.7 β1")
(displayln "============================================================")
(displayln "")
(displayln "This benchmark file measured Tier 2 deprecated ATMS internal")
(displayln "API performance (atms-empty / atms-assume / atms-amb /")
(displayln "atms-read-cell / atms-write-cell / atms-with-worldview).")
(displayln "")
(displayln "All 13 deprecated atms-* functions retired at 1A-iii-b.")
(displayln "Historical bench code preserved in git history at commit `8399b35d`.")
(displayln "")
(displayln "Modern equivalents: solver-context API in atms.rkt (Phase 5.6).")
(displayln "Architectural conclusions preserved in:")
(displayln "  docs/tracking/2026-04-10_BSP_LE_TRACK2_PIR.md")
(displayln "  docs/tracking/2026-04-16_BSP_LE_TRACK2B_PIR.md")
