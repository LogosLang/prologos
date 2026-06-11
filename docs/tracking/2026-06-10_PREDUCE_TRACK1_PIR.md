# PReduce Track 1 PIR — E-Class Cell Substrate

**Date**: 2026-06-10 · **Commits**: `2c48d6b8`..`fc5c55a1` (16 commits, branch `preduce-autonomy`)
**Context**: the FIRST track implemented by the autonomous loop (charter
`docs/tracking/preduce-autonomy/CHARTER.md`); per-iteration record in the LEDGER.
Written against POST_IMPLEMENTATION_REVIEW.org's 16 questions as a live checklist.

## §1 Stated objectives
D.1's Track 1 scope: realize the SM1/SM2 locks as running substrate — the extended
attribute map, the e-class product cell + 'eclass-refine relation, PCE/1 identity,
hashcons + union, congruence, the SM4 ordering substrate, and SM5's Track-1
effect-safety floor. Plus the charter §5.8 measurement obligations.

## §2 Delivered
Everything in D.1 §9's inventory (see that section for the full commit trail):
facet substrate · shape-P (~420× flat) · pce.rkt + golden vectors · eclass-cell +
relation · eclass-graph green slice · #:after/keep-pending · congruence engine +
reactive wiring · effect-safety floor · acceptance file · two §5.8 instruments
(profile-reduction-share, bench-shape-p) + the denominator reconciliation.
Tests: +6 files / ~190 new checks, all green; suite 8531.

## §3 Timeline
One working day (2026-06-10), loop iterations 2-14 — roughly: SM1.1 a+b ~3 iterations
(incl. two gate-caught regressions), flake audit 1, acceptance 1, pce 1,
cell+relation 1, green slice 1, #:after 1, congruence 2, effect floor 1, close 1.
Cadence: one scoped unit per iteration; full-suite gate per code commit.

## §4 Deferred (all named, none silent)
SM3 rule-registry universe cell (THE bridge unit before Track 2; also the
typing-domain flake's structural fix) · D5 probe (needs whnf-cache observer hook —
design note in ledger iter 10) · keep-pending behavioral test (first consumer =
rule dispatch) · production :eclass-link writers (Track 2 ingestion) · fine-grained
Track 1 NTT model (see §15) · .pnet e-class sections (Track 5) · the pre-existing
(cons pos ':term) component-path mismatch (ledgered, separate item).

## §5 What went well
- The gates did co-design's verification half: TWO real regressions caught at the
  suite (wake-duty scoping; over-fire×fire-once), one fix hypothesis REFUTED by
  controlled experiment, one test-author error caught (stale-side construction).
- The green slice + congruence cascade ran first-try green — the D.1 lock quality
  (six panel rounds + owner decisions) translated directly into implementable code.
- PCE/1's kind separation paid off immediately: iteration 13's effect keys composed
  with iteration 7's persistence guard with zero new mechanism.

## §6 What went wrong
- The unscoped bot-filter broke legacy :type wake-duty (the audit FLAGGED the
  untraced bots; I implemented before tracing — the gate caught it).
- Shape-P v1's "sound superset" reasoning was wrong (over-fire consumes fire-once
  shots). Cost: one extra gate cycle; benefit: a codification-grade lesson.
- The census sweep was done one-file-per-gate-round instead of class-at-once
  (diagnostic protocol applied late; 3 gate cycles instead of 1).
- The batch-flake fix hypothesis (restore-list conformance) was refuted; the flake
  remains tracked-not-fixed.

## §7 Where we got lucky
- The min-join canonical's ASYMMETRIC staleness (first-allocated never changes) fell
  out of the design unplanned — it bounds congruence watcher work for free.
- bool-logic's tiny profile surfaced the self-vs-tree attribution gap EARLY, before
  the denominator was declared.

## §8 What surprised us
- The owner's 50-60% reduction-share figure and the profiler's 25-37% were BOTH
  right — phase-accounting vs whole-process denominators (reduce_ms ≈75% on
  ppn-track4c). Lesson: a denominator dispute is usually a definition dispute.
- `:opaque` was silently dropped from SM1.1a (the §4.1/§6 split in D.1 hid it);
  found only when iteration 13 consumed the §6 lock text directly.

## §9 Architecture hold-up
Held. Everything on-network (registry/index/request cells; the occurrence index is
the one boxed exception, named below). Cell/propagator/scheduler orthogonality
respected (shape-P at the cell layer; congruence handler at topology tier; no
scheduler coupling). CALM discipline: every merge ACI; sound-if-stale argued, not
assumed; racing-union fixpoint proven order-independent.

## §10 What this enables
Track 2's arithmetic seed has every prerequisite except SM3's registry: terms can
be interned, unioned, congruence-closed, cost-extracted (argmin best), effect-safely
guarded, and linked from typing positions. Rules become "intern RHS class + union
with LHS class" + dispatch.

## §11 Technical debt (named)
- `eclass-intern-effectful`'s occurrence-index BOX (off-network; should be a cell —
  migrate when Track 2 ingestion wires real call sites).
- The head-classification registries are module-level boxes (same shape as the
  registries SM3 absorbs — intentionally temporary).
- Duplicate union-relate installs across congruence rounds (idempotent but
  wasteful; revisit if D5/extraction data shows it matters).

## §12 What we'd do differently
Trace flagged-unknowns BEFORE implementing against them (both §6 regressions had
their warning in the audit output); sweep assertion CLASSES on the first gate hit.

## §13 Wrong assumptions
"Over-fire is CALM-safe" (true only for refireable dependents); "the superset
delta-path is sound" (same root); "the batch flake is a restore-list gap" (refuted).

## §14 What we learned about the problem
E-graphs fit the propagator substrate with LESS adaptation than the design priced
in: union IS a relate install; congruence IS a fan-in watcher + topology handler;
extraction IS the argmin component of an ACI product. The genuinely novel parts were
the soundness boundaries (effects, staleness), not the e-graph mechanics.

## §15 Are we solving the right problem?
Yes, with one open question for the owner at this doorbell: the §8 closure agreement
promised a FINE-GRAINED Track 1 NTT model in the track doc; the substrate landed
against the COARSE model + the correspondence table, and every propagator passed the
Network Reality Check concretely (net-add-propagator/net-cell-write/trace all
verifiable in tests). Proposal: write the fine NTT model as Track 2's design opener
(where rule dispatch makes it load-bearing) rather than retrofitting it here.
OWNER-PROVISIONAL until ruled.

## §16 Longitudinal (10 most recent PIRs: PPN 2B/3/4/4B, SRE 2G/2D/2H, BSP-LE 2/2B, Tropical Addendum)
The recurring patterns those PIRs distilled (per DEVELOPMENT_LESSONS.org) all
appeared HERE and were all caught in-flight rather than at PIR time: two-context
boundary (the batch flake — pattern #7's 7th+ data point), belt-and-suspenders
(avoided — the bot-filter was scoped, not dualized), validated≠deployed (shape-P
deployed same-commit), dedicated-test-phase (+~190 checks during, not after),
NTT-model gap (named openly in §15 instead of discovered later). NEW longitudinal
candidates from this track: (a) "changed-path precision is a soundness contract
wherever fire-once dependents exist" (2 data points: iter 4 + the design-time
application at iter 12 — codify in propagator-design.md NOW); (b) "audit the
assertion CLASS on first census hit" (1 point, watching); (c) "denominator disputes
are definition disputes — record both lenses" (1 point, watching).

## Metrics
16 commits · 6 new test files (~190 checks) · 2 new instruments · suite 8380→8531 ·
bench-ab at close: large benchmarks ±2.5% (neutral as designed — nothing consumes
the substrate yet), sub-second deltas noise-dominated (pattern-matching +9.6%
watch-listed for next-phase re-check) · microbench: shape-P 11/128/811µs → ~2µs flat.

## Key files
`eclass-cell.rkt` · `eclass-graph.rkt` · `pce.rkt` · `typing-propagators.rkt`
(facets) · `propagator.rkt` (shape-P, #:after, cells 20-21) ·
`tests/test-{preduce-facets,pce,eclass-cell,eclass-graph,stratum-ordering}.rkt` ·
`examples/2026-06-10-preduce-track1.prologos` · instruments under `tools/` +
`benchmarks/micro/bench-shape-p.rkt`.
