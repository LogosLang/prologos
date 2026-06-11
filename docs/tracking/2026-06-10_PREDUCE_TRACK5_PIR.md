# PReduce Track 5 PIR — .pnet E-Class Sections

**Date**: 2026-06-10 · loop iterations 34-39 · against the 16-question checklist.

## §1-§2 Objectives / Delivered
Cross-session e-class persistence per the SM6/0.3 locks. Delivered: the .pnet/2
container's FIRST realization (pnet-sections.rkt — sibling .pnetx; degraded-
never-fatal), origin provenance (interned markers), the pure-read projection,
the re-pour (digest match = hashcons hit by construction; keep-better store
reconciliation), mtime invalidation, PREDUCE_PNETX driver wiring, the
warm-vs-cold A/B. ~30 new checks.

## §3 Timeline
Six iterations: design 2, container+projection 1, re-pour+wiring 1 (with the
residue investigation), gate adjudication 1, the A/B + close 1.

## §4 Deferred (named)
The prn worklist-residue fix (runner removes unfireable ids — propagator-core
surgery, DEFERRED with census plan); in-file .pnet/2 unification (when
pnet-serialize migrates wholesale); section eviction thresholds; the
context-digest key upgrade (SM6's named follow-on).

## §5-§8 Went well / wrong / lucky / surprised
WELL: the container + projection + re-pour landed in two iterations on locked
specs; the iter-26 admission discipline and the keep-better lattice both
reused verbatim. WRONG: the origin-as-cons-pair seteq lesson (#19, racing test
caught instantly); the save hook's str.replace-all landing in three functions;
the hard quiescence assert demanding the unachievable. LUCKY: the probe
infrastructure (one -e script) found the residue in minutes. SURPRISED: the
prn is PERMANENTLY non-quiescent by the null-worklist definition — a substrate
truth nobody had occasion to observe before a consumer asserted it.

## §9 Architecture hold-up
Held — and the track's best moment was architectural: the hard assert's
one-day life FOUND a real substrate defect before being amended to the
achievable contract (residue-tolerant; cell state at fireable fixpoint).

## §10-§11 Enables / Debt
Warm-start compilation exists end-to-end; Track 3's ι coverage multiplies what
it carries; the SH/Zig lowering has a real serialized e-graph format to
consume. DEBT: the residue (deferred); hex round-trip cost on big sections
(unmeasured); the silent-degrade save (observability vs robustness — a counter
would serve both).

## §12-§14 Differently / Wrong assumptions / Learned
DIFFERENTLY: probe-first on any hard assert against long-lived networks.
WRONG ASSUMPTION: "run-to-quiescence ⇒ net-quiescent?" — false on the prn.
LEARNED: persistence's hard parts were identity (solved by PCE day one) and
QUIESCENCE SEMANTICS (the surprise); the I/O was trivial.

## §15 Right problem?
Yes — and the honest verdict mirrors Track 4's: machinery COMPLETE and proven
(round-trips, re-pour hits, mtime gates all green); warm ≈ cold AT CURRENT
COVERAGE (pre-registered outcome). The series' payoff chain now reads, fully
instrumented: free ingestion (iter 33) + working persistence (here) + working
extraction (Track 4) AWAIT COVERAGE (ι, Track 3) — one multiplier, three
ready consumers.

## §16 Longitudinal
#19 (eq-stable set members) joins the iter-9 alts fix as the comparator
family's 2nd point — CODIFY-CANDIDATE ripened. "Probe-first on asserts" is
new (1 point). The falsify-the-workload pattern (Track 4) recurred at the A/B
design here (the pre-registration WAS the falsification discipline applied
prospectively — pattern CONFIRMED as prospective practice).

## Metrics
6 iterations · 4 code commits · ~30 checks · the first .pnetx: 2.5KB ground
content · warm-vs-cold: 339/338ms + 1538/1558ms (≈, pre-registered).

## Key files
pnet-sections.rkt · preduce-pnet.rkt · eclass-graph.rkt (origin) · driver.rkt
(PNETX wiring) · tests/test-preduce-pnet.rkt · the Track 5 design doc.
