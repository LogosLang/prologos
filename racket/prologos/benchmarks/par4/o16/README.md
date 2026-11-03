# PAR 4 O-16 evidence: what a budget counts

Posed in [D.2 §15, O-16](../../../../../docs/tracking/tracks/PAR/PAR_4/2026-10-15_PAR_4_D2_DESIGN.md). Written 2026-10-19 at
`38072887` on `par4-arena-executors`. The production code is identical to main `a01f3fc7`.

| file | what |
|---|---|
| `o16-budget-units.rkt` | read-only probe on the real `propagator.rkt`. Seven fixtures (chain, P0's S-6 fan-in, diamond, a union cycle, a 2-cycle climbing to height 8, 64 independent copies, a divergent 2-cycle), each run under BSP and the drain, in forward and reversed install order. Per run: fires, strict changes, depth (BSP: rounds that changed state) or depth label (drain), and **B-min**, the least fuel that does not exhaust (found by bisection; exhaustion is monotone in the fuel). Kleene depth is computed independently, at spec level |
| `o16-budget-units.out` | its output (Racket 9.3; no timing, so the suite lock is not needed) |

Run it from `racket/prologos/`: `racket benchmarks/par4/o16/o16-budget-units.rkt`. It takes about 1 min, almost all of it
the module load.

**What it shows** (MEASUREMENT on these fixtures):
- Under BSP, fires, changes and B-min are the same in both install orders on every fixture, and BSP's depth equals the
  Kleene depth on all six converging fixtures.
- Under the drain, fires, changes and B-min depend on install order and differ from BSP. On the union cycle, B-min is
  13 under BSP and 12 / 10 under the drain's two orders; on the climb, 19 against 12. The S-6 fan-in makes 1 change
  under BSP and 16 under the drain in reversed order (P0 §5's number, reproduced).
- The partial state at exhaustion (divergent fixture, fuel 41) is {a 21, b 21} under BSP, and {a 41, b 40} or
  {a 40, b 41} under the drain.
- The drain's depth label never falls below the Kleene depth (0 violations in 12 converging runs). It exceeds it on
  the union cycle in forward order (6 vs 4) and on the climb (9 vs 8).

**Power rows**:
- A mutant label rule without the `+1` is caught (label 0 vs depth 8).
- The divergent fixture exhausts at fuel 4096 under every schedule.
- The chain exhausts at fuel 1.
- The order-independence check for BSP has power, because the same comparison finds order dependence in the drain's
  columns.

**Proxy caveat**: the drain stands in for DIRECT at K = 1; both are chaotic (Gauss–Seidel) iteration. DIRECT itself is
not built, so the drain's columns are evidence about the *class* of schedule, not measurements of DIRECT.
