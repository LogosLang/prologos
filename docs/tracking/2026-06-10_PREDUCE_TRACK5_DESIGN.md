# PReduce Track 5 Design — .pnet E-Class Sections (cross-session persistence)

**Status**: DESIGN OPENING (2026-06-10, autonomy loop iteration 34).
**Inherits, all frozen**: PCE/1 + .pnet/2 tagged-section container (Track 0.3,
owner-signed); the SM6 §7.2/§7.4 locks (ground-admission day one; the
question-keyed store schema); the iter-33 selectivity finding (ingestion can be
FREE — cross-file reuse starts from zero standing overhead, which is what makes
this track the named win condition).
**Named first-of-kind risk (the SM6 lock's own words)**: these are the FIRST
genuine cell-state-derived .pnet sections — everything persisted today is
parameter snapshots. The projection discipline below is the risk's mitigation.

## Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| D | Design through critique | 🔄 | opened iter 34 |
| 1 | Serialize-time projection (the two sections) | ⬜ | §2 |
| 2 | Load-time re-pour + invalidation | ⬜ | §3-§4 |
| 3 | The cross-file A/B (the multiplication measurement) | ⬜ | §5 |

## §1 What persists (two payloads, both ground-only day one)

**Section A — per-module e-class content** (tag `'preduce-eclasses`): for each
GROUND-regime class whose provenance is origin-module-local: content-hash →
{canonical form, best (cost . form), regime tag}. Tier-1 declarative content
only (expr forms are PCE-admissible by construction; inadmissible classes are
simply not projected — the iter-26 admission discipline reused).
**Section B — the question-keyed store** (tag `'preduce-rewrites`): the SM6
schema verbatim — its validity does NOT borrow module mtime (the lock's
verified warning about pnet-serialize's whole-file path:mtime); it carries the
cost-criterion-id and the reserved worldview slot in the key.

## §2 The projection (serialize-time; the first-of-kind discipline)

At serialize-module!: READ the hashcons + store cells, project the declarative
core (digest → form/cost/regime triples; descriptors are NOT persisted — node
re-interning rebuilds them cheaper than deserializing closures), FILTER by
regime='ground AND origin-module (provenance), and emit the two tagged
sections. The projection is a PURE READ of cells — no new cell state, no
serializer-side mutation; .pnet/2's tagged-section container means readers
that predate these tags skip them (forward-compatible by the 0.3 freeze).

## §3 Load-time re-pour

At module load (where the kernel seed pours): section A entries re-intern into
the per-file hashcons (eclass-intern with the persisted cost; the digest match
is the hashcons hit by construction — the persisted content-hash IS the intern
key); section B merges into the store cell (keep-better — a stale worse entry
loses to a fresh better one automatically; the lattice does the reconciliation).

## §4 Invalidation

Section A: whole-module mtime (the SM6 lock's explicit day-one bound — the
wv0-at-birth ≠ context-free conflation is BOUNDED by it, not solved; the
context-digest key upgrade stays the named follow-on). Section B: NOT mtime —
the question key is content-defined (the class's alt-set digest), so a changed
source produces different questions naturally; stale entries are unreachable,
not wrong (cache-lattice semantics; eviction = section omission at rewrite
thresholds, a Phase 2 knob).

## §5 The cross-file A/B (the multiplication measurement)

The workload that COULD NOT exist within one session: compile module M (cold) →
recompile M (warm, sections present) → the warm run's reduce phase should drop
by the memoized share. Corpus: the acceptance file split into a library module +
a consumer + the recompile cycle, plus ppn-track4c warm-vs-cold. The honest
pre-registration: if warm ≈ cold, the persisted share is too small at current
hook coverage — recorded as such, with the ingestion-coverage expansion (ι at
Track 3) as the next multiplier, NOT silently widened scope here.

## §6 Open questions (for the critique round)

1. Does section A persist hashcons REGISTRY entries (digest→cid is per-session
   meaningless) or content triples only (re-intern allocates fresh cells)? The
   sketch says triples-only — challenge whether canonical NAMES need stability
   across sessions (SM2's three-key separation says NO: the KEY is the
   content-hash; canonicals are per-session allocation order).
2. Serialize-time cost: the projection scans the full hashcons per module —
   acceptable at current scale; the per-module provenance filter needs the
   origin recorded at intern time (a provenance set member today? verify).
3. Where does serialize-module! live and what is its extension surface
   (pnet-serialize.rkt's section writer — the 0.3 container's first new
   producer)?
