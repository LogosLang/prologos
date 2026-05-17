#lang racket/base

;;;
;;; PPN Track 4C Pre-0 Benchmarks: RETIRED at 1C-iv-a per §10.0.1 Q-1C-ε ε2
;;; + §10.0.6 D-1C-iv-4 (Cell/Propagator/Scheduler Orthogonality consolidation).
;;;
;;; ============================================================
;;; D.4 1C-iv-a ε2 RETIREMENT (2026-05-16)
;;; ============================================================
;;;
;;; This file's M7/M8/M13 + A-series + E-series + R-series microbenches
;;; measured Pre-0 baselines for the struct-copy-fuel + inline-check + macro-
;;; access patterns. Under D.4 CANONICAL (cell-as-canonical; struct-field
;;; `prop-net-hot-fuel` retired at 1C-iv-b; macro `prop-network-fuel` retired
;;; at 1C-iv-b), these microbenches measure obsolete patterns that no longer
;;; exist in production.
;;;
;;; HISTORICAL BASELINE DATA preserved at:
;;;   racket/prologos/data/benchmarks/tropical-pre0-baseline-2026-04-26.txt
;;;
;;; POST-D.4 MICROBENCHES (use these for current measurements):
;;;   - benchmarks/micro/bench-specialized-cell-spike.rkt
;;;       (§13.6 falsification spike; W1-W5 measurements)
;;;   - benchmarks/micro/bench-tropical-fuel.rkt
;;;       (Phase 1B M10/M12/R4 capture; tropical quantale primitive)
;;;
;;; ORIGINAL BENCH CODE preserved in git history at commit `bc9bc79a` (last
;;; commit before 1C-iv-a retirement).
;;;
;;; RATIONALE (per §10.0.1 Q-1C-ε ε2): "ε1 (migrate to cell-API) would create
;;; semantic confusion — sections named 'M7 struct-copy decrement' would
;;; silently measure cell-write cost. Retirement is the principled response
;;; — these benches measured Pre-0 baselines, which are now reference data
;;; (preserved in the .txt baseline file)."
;;;
;;; ============================================================

(displayln "============================================================")
(displayln "bench-ppn-track4c.rkt: RETIRED at 1C-iv-a per §10.0.1 ε2")
(displayln "============================================================")
(displayln "")
(displayln "This benchmark file measured Pre-0 baselines under D.4-incompatible")
(displayln "patterns (struct-field fuel, prop-network-fuel macro). Both retired")
(displayln "at 1C-iv-b.")
(displayln "")
(displayln "Historical baseline data:")
(displayln "  racket/prologos/data/benchmarks/tropical-pre0-baseline-2026-04-26.txt")
(displayln "")
(displayln "Post-D.4 microbenches:")
(displayln "  - benchmarks/micro/bench-specialized-cell-spike.rkt (§13.6 spike)")
(displayln "  - benchmarks/micro/bench-tropical-fuel.rkt (Phase 1B M10/M12/R4)")
(displayln "")
(displayln "Original bench code preserved in git history at commit bc9bc79a.")
