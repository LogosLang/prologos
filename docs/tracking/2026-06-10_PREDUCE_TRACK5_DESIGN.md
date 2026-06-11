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
| D | Design through critique | ✅ | iters 34-35; DESIGN COMPLETE (Q3 re-scoped Phase 1: the .pnet/2 section writer is greenfield) |
| 1 | Serialize-time projection (the two sections) | ✅ | iter 36: pnet-sections.rkt (the container's first realization; sibling .pnetx siting) + origin provenance (INTERNED markers — the eq-set value-equality lesson) + the asserted projection |
| 2 | Load-time re-pour + invalidation | ✅ | iter 37: re-pour + mtime gate + driver wiring (PREDUCE_PNETX); quiesce-then-project; the residue finding (DEFERRED) + residue-tolerant amendment; first real .pnetx written (2.5KB ground content) |
| 3 | The cross-file A/B (the multiplication measurement) | ✅ | iter 39: warm ≈ cold (339/338, 1538/1558ms) — the PRE-REGISTERED outcome; the multiplier is ι coverage (Track 3) |

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

## §6 Questions — RESOLVED (iter 35; 3-column + mini-audits)

**Q1 → TRIPLES-ONLY.** Catalogue: digest→cid entries are per-session
meaningless. Challenge: do canonical NAMES need cross-session stability? NO —
the SM2 three-key separation answers it: the content-hash is THE key;
canonicals are per-session allocation order BY DESIGN (min-alloc); persisting
them would create a false-identity coupling the keys were separated to prevent.

**Q2 → the origin GAP is REAL (mini-audited).** Provenance sets today carry
only 'intern/'intern-node/'effect-occurrence — NO origin module. Phase 1 item:
`current-intern-origin` (a parameter the driver sets per file; folded into the
provenance set at intern as `(cons 'origin id)`); the projection filters on it.
Until set, origin='unknown classes are NOT projected (pessimistic — the same
admission posture as everything else in this series).

**Q3 → the .pnet/2 SECTION WRITER DOES NOT EXIST YET (mini-audited).** The 0.3
freeze is a SPEC; pnet-serialize.rkt's serialize-module-state (:498) is the
legacy whole-tuple writer with no tagged sections. HONESTLY RE-SCOPED: Phase 1
includes realizing the .pnet/2 tagged-section writer/reader pair — this track
builds the container's FIRST producer AND consumer (which is also exactly why
the SM6 lock named the first-of-kind risk). The legacy tuple path is untouched
(sections append; old readers skip unknown tags per the container spec).

## §7 VAG (adversarial, 3-column — iter 35)

| Decision | Catalogue | Challenge |
|---|---|---|
| Pure-read projection | no serializer-side mutation ✓ | CHALLENGED: is read-at-serialize a hidden consult-order dependency (cells mid-quiescence)? Serialization runs at module close AFTER the file's last quiescence — the read sees the fixpoint; assert quiescent-at-serialize in the writer (cheap, structural). |
| Pessimistic origin filter | unknown ⇒ not projected | CHALLENGED: pessimism is now used FOUR times in this series — habit check: each instance gates ADMISSION to an identity-bearing domain where wrong inclusion is unsound and exclusion is only slow. The pattern is the domain's, not a reflex. |
| Triples-only | three-key separation ✓ | (resolved above — the challenge IS Q1) |
| Sections append to legacy .pnet | forward-compatible ✓ | CHALLENGED: belt-and-suspenders (two formats)? NO — the tuple is the EXISTING format; sections are additive payloads in the spec'd container; nothing dual-paths (a reader without section support simply has no e-class warm-start — degraded, not divergent). |

**DESIGN COMPLETE** (iter 35). Phase 1: the tagged-section writer/reader +
origin provenance + the projection; Phase 2: re-pour + invalidation; Phase 3:
warm-vs-cold.
