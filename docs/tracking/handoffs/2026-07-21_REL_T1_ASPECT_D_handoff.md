# Handoff — Rel Track 1, Aspect D (D.0/1): efficient fact representation + query optimization — **RESEARCH (Stage 0/1)**

**Date**: 2026-07-21 · **Handoff for**: a fresh session opening as a **research
conversation** (Stage 0/1), not an implementation. Per `HANDOFF_PROTOCOL.org`.
**ON-DISK IS AUTHORITATIVE.**

> **Hot-load protocol reminder** (`HANDOFF_PROTOCOL.org`): read this handoff §1–§6 FIRST,
> then the Always-Load set, then EVERY session-specific doc **in full** — then **summarize
> your understanding back to the owner and let them validate it BEFORE starting work.**

---

## §1 — Current Work State (PRECISE)

- **Series / Track**: Rel Series → **Track 1, Relational Language Usability**.
- **HEAD**: `d239dd9d` · **Suite** GREEN **8966 / 468 / 0** · Branch `main` (ahead of
  origin; don't push unless directed).
- **Working tree**: pre-existing **OWNER WIP only** (modified standups/examples, deleted
  `MASTER_ROADMAP.md`/`LANGUAGE_VISION.md`, untracked LATTICE_/LAVAMOAT_/pldi files).
  **LEAVE ALONE; stage ONLY your files; NO Co-Authored-By** (`CLAUDE.local.md`).
- **Design doc**: `docs/tracking/2026-07-19_REL_T1_RELATIONAL_USABILITY_DESIGN.md`
  (§3 "Aspect D scope note" is the charter; §2 Progress Tracker row **D.0/1**).
- **Series Master**: `docs/tracking/2026-07-19_REL_MASTER.md`.

| Aspect | Status |
|---|---|
| **A** NAF/guard correctness | ✅ COMPLETE (A.1 · A.2-core · A.2b · A.3 · A.4 · SC) |
| **B** typed solution rows | ✅ COMPLETE (B0 `949d3be7` · B1 `be20e7e0` · B2 `68291d62`) |
| **C** typed logic vars + schema validation | ✅ **CLOSED** at C.a `b33474aa` · C.b.1 `6d793906` · C.b.2 `c6b8e81f` · C.c `357035d5`; C.d → **UCS Track 6** (`ee3f7c22`) |
| **D.0/1** efficient fact rep + query-opt | ⬜ **← THIS SESSION (research)** |
| POL polish · X.close (PIR) | ⬜ after D |

**Scope (design §3, owner 2026-07-19)** — verbatim intent: a *"deeper, possibly frontier
research agenda (best-of query-optimization + data representation for performative fact
queries)."* **Stage 0/1 research + a design artifact IS in scope this track**;
**implementation** is picked up here **or spun out** as a separate design/impl track
(owner's call at design time). It *"grounds the eventual move of the off-network fact store
… on-network."*

**Owner's framing for this session** (2026-07-21): open as a **research conversation** —
a *deeper re-examination* of the question (not just adopting the 2026-03 conclusions) —
**and** think about *how to approach integrating findings as engineering efforts now or
down the road*.

**NEXT IMMEDIATE TASK**: read §2's list, then **co-design the research framing with the
owner** (what question are we actually answering, at what scale regime, against what
baseline). Do NOT jump to a design; Stage 0 is survey + problem definition.

---

## §2 — Documents to Hot-Load (ORDERED)

**Always-load** (skim if fresh): `CLAUDE.md` + `CLAUDE.local.md`; `MEMORY.md` +
[[rel-t1-relational-usability]] + [[demo-dependency-resolver-track]];
`DESIGN_METHODOLOGY.org` (**Stage 0/1** — this session is research, not Stage 4);
`DESIGN_PRINCIPLES.org`; `CRITIQUE_METHODOLOGY.org`; `HANDOFF_PROTOCOL.org`;
`MASTER_ROADMAP.org`; series master `2026-07-19_REL_MASTER.md`.
Rules auto-load — **internalize `on-network.md` + `structural-thinking.md` (the SRE lattice
lens is load-bearing here: a fact table IS a lattice question) + `propagator-design.md`**.

**Session-specific — READ IN FULL, IN THIS ORDER:**

1. **This handoff** (§1–§6).
2. **The charter**: design doc §3 "Aspect D scope note" + §2 tracker row D.0/1. Short.
3. **THE SEED (owner's pointer)** — `docs/standups/standup-2026-03-11.org` §"Relational
   Fact Data Representation Discussion", **lines 506–696**. ⚠ **Standups are WRITE-ONCE /
   READ-ONLY — never modify.** Lands on: *the schema is the Rosetta Stone* (a compile-time
   bijection position↔key: store positional, author/query keyed, zero runtime cost);
   a representation table (flat vector / PVec / CHAMP / generated struct); **keyed goal
   patterns** (`(employees {:dept "Eng" :name name})`) desugaring to positional; schema as
   the CSV/SQL/JSON interop contract; and **5 open questions** (keyed goal patterns · bulk
   import `:source` · retroactive schema · **wide-row indexing** · the Hickey schema/select
   split).
4. **The committed distillation of that conversation** — `docs/tracking/2026-03-06_1400_RELATIONAL_FACT_DESIGN.md`
   (213 lines). Lands on flat-vector primary (§3.1, *"identical to how Datalog engines
   (Souffle, Flix) store tuples"*), CHAMP as schema-less fallback (§3.2), hybrid dispatch
   (§3.3), + 5 open questions (§6) incl. **§6.4 Indexing Strategy**.
5. **⭐ The owner's ACTUAL performance thesis — the single most on-point in-repo doc, and
   the scope note does NOT name it**: `docs/tracking/principles/RELATIONAL_LANGUAGE_VISION.org`
   §"Empirical Performance: In-Memory Logic vs. SQLite" (~:696) · §"Prologos's Unique
   Advantages for Data Querying" (~:715–768) · §"Scaling Regimes" (~:863–890). Carries the
   sub-ms-in-memory vs ~30ms-SQLite claim with 4 structural reasons, the SQLite-prerequisite
   framing, three named scale regimes, and **three architectural equations**: *tabling =
   materialized views · propagators = incremental view maintenance · ATMS = provenance /
   lineage (provenance semirings)*. This is the strongest bridge from our substrate to the
   DB-systems literature.
6. **⭐ The most concrete actionable query-opt program (also unnamed by the scope note)** —
   `docs/research/2026-03-16_BEYOND_PROLOG.md` **§2**: argument indexing · goal reordering ·
   determinism inference · compile-time mode checking · propagator cell selection. It states
   outright that Prologos lacks first-argument indexing. **Its premise is STILL TRUE at
   HEAD** — the `+/-/?` mode lattice exists on `param-info` but is unexploited.
7. **The Datalog/tabling axis** — `docs/research/2026-03-16_NEXT_GEN_LOGIC_PROGRAMMING.md`
   §"Advanced Tabling: Beyond SLG" (subsumptive tabling · mode-directed tabling · **magic
   sets, rated HIGH impact**) + §7.5 "Kan Extensions and Query Optimization".
8. **The RPF scope list** — `docs/tracking/2026-06-28_DEPENDENCY_RESOLVER_DEMO_DESIGN.md`
   §11. ⚠ See §4.1: **RPF is not a track**; it is a 5-item bullet list.
9. Latest dailies `docs/tracking/standups/2026-07-19_dailies.md` (STATE head + the Aspect-C
   arc) — for where the track just came from.

**Gather that produced §4** (raw output if a specific file:line is needed):
`wf_bf2bee13-398`.

---

## §3 — Settled Priors (do NOT re-derive; DO re-examine)

These are *inherited positions*, not locked decisions — the owner explicitly wants a
**deeper re-examination**. Know them so you build on them rather than rediscovering them.

1. **The schema is the Rosetta Stone** (2026-03): a schema declares a bijection
   position↔named-key, so storage can be positional/compact while the surface offers keyed
   authoring + keyed query patterns, erased at compile time. Zero runtime cost for the
   ergonomics.
2. **Flat vectors (or per-schema generated structs) as primary storage**; CHAMP/PVec for
   *user-facing* collections, not the hot fact path. Rationale: rows are small (3–15 fields),
   fixed-width, and hammered by unification, which wants O(1) indexed access.
3. **⭐ NEW since that conversation — the invariant is now ENFORCED.** Rel T1 **C.c**
   (`357035d5`) added a blocking `schema ⟹ facts-only` registration gate: a schema'd
   relation *cannot* have rule clauses. The "schema = a table of ground rows" abstraction the
   2026-03 design **assumed** is now **structurally guaranteed**. Aspect D inherits a much
   firmer footing than the seed conversation had.
4. **Also new since the seed**: CIU T6 F1 records/`Map` + the schema SEAL; Aspect B typed
   solution rows (row keys = query-var names `Κ′`); `param-info` is now **3 fields
   `(name mode type)`** (the `type` slot added by C.a). Any design assuming the old 2-field
   `param-info` is stale.
5. **The three architectural equations** (vision doc): tabling ≈ materialized views;
   propagators ≈ incremental view maintenance; ATMS ≈ provenance/lineage. Adopt or refute
   them explicitly — they are the bridge to the DB literature.
6. **RPF's 5-item scope** (the thing Aspect D is the research phase *of*): persistent
   fact-grained cell across queries · migrate off the `current-relation-store` parameter ·
   incremental re-load + tabling-memo invalidation · **S(-1) fact retraction** · indexing +
   flat-vector storage.

---

## §4 — Surprises & Code Reality (HIGHEST-VALUE SECTION — verified @ `d239dd9d`)

The gather measured the actual engine. Several findings **reframe the research question**.
Coordinates DRIFT — re-grep before trusting any file:line.

### 4.1 The framing itself is off in three places

- **"RPF-track adjacency" — RPF IS NOT A TRACK.** No Series row, no Track row, no design
  doc. It exists solely as a 5-item bullet list in the DEMO design §11. Treat it as a *name
  + scope list*, not an artifact to survey. **Aspect D is effectively RPF's Stage-0/1 phase.**
  (RPF's designated wedge, DEMO P3, is ⬜ NOT STARTED and blocked behind P1 → Numerics.)
- **"the off-network fact store … name-grained-replace merge" conflates TWO artifacts.**
  The authoritative store is the *parameter* (`relations.rkt:894`) which has **no merge at
  all** (bare `hash-set`, :571). The name-grained-replace merge belongs to a **separate,
  already-existing CELL** — well-known **cell-id 2** (`propagator.rkt:627`, merge at
  :628-634, registered :1054, written per-query at `relations.rkt:3105`).
  **⇒ The on-network question is NOT "give it a cell." The cell exists.** It is a
  **granularity/lattice** question: decompose the opaque `relation-info` blob into
  **fact-grained components with a set-union (join) merge** instead of per-key replace.
- **The scope note omits the two most useful prior-art docs** (see §2 items 5 and 6).

### 4.2 There is no index anywhere — and four separate scan sites

- Facts are **row-major lists of raw AST expr nodes** (`fact-row (terms)` :543 → list in
  `variant-info` :549 → list in `relation-info` :557). No columnar layout, no per-column
  storage, no row IDs. Terms are stored as **raw AST**, normalized **lazily at every
  comparison** (:979-981, :393-399) — so a columnar/typed-array rep is *not* a drop-in: it
  moves the normalization boundary to registration, which interacts with the per-row schema
  `check` pass already running at defr time (`driver.rkt:493-509`).
- **`build-discrimination-data` is NOT an index.** It is the **forward** map
  `position → (alternative-idx → expected-value)`. Answering the query-relevant question
  ("which rows have value *v* at position *k*?") is a full scan. **A real index is the
  inverted `value → set-of-rows`, and it does not exist.**
- **FOUR independent scan sites** — a representation change touches all of them:
  Tier-1 (`relations.rkt:3025`), DFS `solve-app-goal` (:1538), **explain/provenance carries
  its own copy** (:1875), and the table consumer (:2792).
- Tier-1 is an unconditional O(#rows × arity) scan **with no early exit even when the query
  pins a ground key** (:3009-3047), and its applicability is narrow (single variant,
  facts-only, ≥1 var must bind — fully-ground/boolean queries fall through to slower paths).
- DFS is O(#variants × #rows × arity) **per goal, per backtrack point**, no ground-arg
  pre-filter (:1531-1552).

### 4.3 The single biggest current cost — and the cheapest available win

**`build-discrimination-data` is rebuilt FROM SCRATCH on every query install**
(`relations.rkt:805` ← :2583-2584), once per variant per goal. That is O(#rows × arity)
hash-inserts **plus** O(#rows × arity) `normalize-solver-value` calls **per query**, *on top
of* the scan the query then performs. No memo, no cache, no registration-time precompute.
**A registration-time (or cell-derived) precompute is the cheapest win on the board** and
should be an explicit design option.

### 4.4 Dead code — do NOT design against it

- **The discrimination TREE is entirely unused**: `variant-discrimination-tree`,
  `build-discrimination-tree`, `position-discriminates?` have **zero callers** in production
  *and* tests. Exported and dead. A proposal to "extend the existing discrimination tree"
  would be extending dead code.
- **`relation-info-tabled?` is a dead field** — always `#f`, zero reads. The real tabling
  gate is `solver-config-tabling` + presence of a solver context (:2540-2543).
- **Free-argument discrimination is dead work on the value path**: `viability-cid` has
  exactly ONE read (:2590, install-time). The fire-once propagators fire and write it, but
  nothing reads it afterwards, so the narrowing never prunes. Two in-file comments assert
  behavior the code does not implement.

### 4.5 Scaling walls in the on-network path

- **One ATMS assumption + one worldview BIT per fact row**, plus one fire-once propagator
  per (row × output arg) (:2643-2694, bit at :2677). N rows ⇒ N assumptions, an N-bit bignum
  mask on **every** tagged read/write, N×arity propagator installs per query.
- **`:auto` threshold is 256** (`solver.rkt:75`): any fact table under 256 rows runs the
  **DFS linear scan** by default; the on-network engine engages only at ≥256 alternatives —
  precisely where its per-row bitmask cost is worst.
- **A.2b/A.4 DFS-routing** means body-local-rule-bearing and guard-bearing queries **never**
  reach the on-network path. **⇒ Aspect D must state explicitly whether it targets the
  on-network path (currently a narrow slice, gated behind BSP-LE Track 3) or the DFS path
  (where nearly all real queries land).**
- **Fact-NAF is quadratic by construction**: `naf-per-binding-mask` runs a full recursive DFS
  `solve-goal` per candidate binding (:186 in the fold at :184-195) ⇒ N × O(N).
- **Tabling is INTRA-QUERY only**: the solver context is built fresh per query (:3109) and
  the cached network template is an empty net never written (:3058-3064). **Nothing memoized
  survives a query** — repeated identical queries redo all scanning. And the table *consumer*
  is itself a linear `equal?` scan over all accumulated answers (:2792-2803).

### 4.6 The lattice picture (SRE lens — load-bearing)

- **`relation-store-merge` is NOT SRE-registered** anywhere: no declared lattice, no
  `bot?`/`contradicts?`, invisible to the SRE property sweep. (Contrast: the ATMS table cells
  *are* registered.) Any Aspect D lattice claim starts from an **undeclared domain**.
- **The cell's comment contradicts its code**: `propagator.rkt:623` claims *"hash-union
  (monotone accumulation, CALM-safe)"* but :631-632 is **per-key last-write-wins** — neither
  commutative nor value-monotone. This is exactly the ambiguity the PPN 4C Phase 1e-α η-split
  was created to eliminate; `relation-store-merge` escaped it.
- **⭐ TWO LATTICES POINTING IN OPPOSITE DIRECTIONS**: facts/answers **accumulate** (join —
  dedup-append / hash-union) while query narrowing **intersects** (meet — set-intersect on
  clause viability, a locally-defined un-hoisted lambda). **A columnar/indexed design must
  serve both a growing join lattice (the data) and a shrinking meet lattice (the query's
  viable set).** This is the central structural question.
- **The on-network precedent exists**: Phase 8.4's `solver-context-table-registry-cid`
  (`atms.rkt`) — ONE registry cell (`rel-name → table-cell-id`, per-key new-wins) + ONE
  answer cell per tabled relation (dedup-append). The **answer merge is a genuine
  join-semilattice; the registry merge is not** — that split is exactly what the fact-store
  research must make explicit. (Note: the rule doc's "Phase 8 dissolved `table-store`" is
  only *partly* true — the wrapper still backs the user-facing `TableStore` primitive and
  wf-engine's off-network `current-wf-table-store`, i.e. there are **≥3** off-network
  fact-ish stores, one of which wraps *its own private prop-network* — the exact
  "separate wrapper struct" red flag from `on-network.md`.)
- **The code already names the target**: the discrimination data is documented as
  construction-time Phase-0 scaffolding whose self-hosted replacement is *"a derivation
  propagator watching the relation-store cell."*

### 4.7 ⚠ There is no baseline — this is a Phase-0 deliverable

**NO FACT-SCALE BENCHMARK EXISTS.** The largest fact block anywhere in the repo is **17
rows**; the dedicated `solve-adversarial` comparative benchmark's biggest relation is **13
rows**. **Every published solver perf number is measured in the regime where a linear scan
is optimal.** Aspect D cannot honor the "benchmark after infrastructure phases" +
feature-microbench obligations without **first authoring a scaled fact-relation benchmark +
dataset**. Ready instruments: the deterministic, ambient-immune counters `solver_backtracks`
(:1524) and `solver_unifies` (:1220) on the PERF-COUNTERS line — both directly proportional
to scan volume.

### 4.8 External-literature scoping (negative results)

- **Worst-case-optimal join prior art is essentially ABSENT** in-repo: `leapfrog`,
  `triejoin`, `generic join`, `AGM bound` = **zero hits**. Genuinely new survey territory.
- **"Columnar" in-repo is about GPU/LLVM backend *cell state*, not fact tables** (15 of 17
  hits are the PReduce/LLVM sweep). **"Join order" has one hit and it is a false positive** —
  no join-ordering / cardinality-estimation prior art exists.
- **But a directly transferable blueprint is mis-filed under PReduce**: **GDlog/GPUlog**
  ("Optimizing Datalog for the GPU", arXiv 2311.02206) — dense HISA row-major store + sorted
  index + open-addressing hash of *references, not tuples* + semi-naive delta + kernel-boundary
  BSP; **35–45× over Soufflé**. That is a fact-representation + join-execution design worth
  mining.

---

## §5 — Open Questions (the research agenda)

**Inherited (2026-03 seed, §6 of the distillation + the standup's 5):** keyed goal patterns
& desugaring · bulk import (`:source` CSV/SQL/JSON) · retroactive schema on schema-less facts ·
**wide-row / multi-column indexing** · the Hickey schema/select split (≈ SQL projection).
⚠ The DEMO-track `:from` runtime fact loading has **no implementation** in `driver.rkt`.

**Raised by the code reality (§4) — arguably the more important set:**
1. **Which engine do we optimize?** DFS (where ~all real queries land, given threshold=256 +
   A.2b/A.4 routing) or the on-network path (narrow today, blocked behind BSP-LE Track 3)?
   Or: does Aspect D *change the dispatch* rather than the representation?
2. **What is the lattice of a fact table**, and how do the **join** (data accumulates) and
   **meet** (query viability narrows) lattices compose in one design? What does the Hasse
   diagram say the parallel decomposition is (per `structural-thinking.md`)?
3. **Granularity**: what is the right cell decomposition — per-relation? per-fact? columnar
   per-(relation,position)? — and what merge makes it a genuine join-semilattice (vs today's
   un-registered per-key replace)?
4. **Is an index a derived cell?** The code already proposes "a derivation propagator watching
   the relation-store cell." Is the index a *derived, incrementally-maintained view* (which
   would make the tabling≈materialized-views / propagators≈IVM equations literal)?
5. **Retraction**: RPF item #4 puts fact retraction at **S(-1)** (non-monotone). How does that
   interact with a monotone index?
6. **Scale regime**: which of the vision doc's three regimes are we designing for? The answer
   determines whether this is "fix the per-query rebuild + add first-arg indexing" (weeks) or
   "columnar + WCOJ + semi-naive" (a track of its own).
7. **Integration path** (owner's explicit ask): which findings become engineering **now**
   (e.g. §4.3's registration-time precompute; deleting §4.4's dead code) vs **later** (a spun-out
   RPF/impl track)? Recommend a staging.

**Deferred / adjacent**: BSP-LE Track 3 (on-network body-local + guard + worldview-preserving
tabling) gates the on-network path; UCS Track 6 (`?x:Int` domain constraints) is orthogonal;
Polish + X.close (the Stage-5 PIR) remain in Rel T1 after D.

---

## §6 — Process Notes

- **This is Stage 0/1 (research), not Stage 4.** Follow `DESIGN_METHODOLOGY.org` Stage 0/1:
  survey prior art → define the problem → *then* a design artifact. Do **not** open with an
  implementation plan; the owner wants the research conversation first.
- **Deliverable shape**: a Stage-0/1 **research + design artifact** (a doc). Implementation is
  explicitly **pick-up-here-or-spin-out — the owner's call at design time**. Ask; don't assume.
- **The standup is READ-ONLY.** `docs/standups/` is write-once (`CLAUDE.local.md`). Read lines
  506–696; never edit.
- **Phase-0 obligation**: no fact-scale benchmark/dataset exists (§4.7). Authoring one is a
  prerequisite for any perf claim — reserve it explicitly.
- **Coordinates DRIFT** — every file:line here was verified at `d239dd9d`; re-grep. Several
  *inherited docs* carry stale coordinates (the DEMO design §D3 has 4; the standup cites
  `fact-row` at :69, now :543; `param-info` gained a 3rd field in C.a).
- **Don't design against dead code** (§4.4): the discrimination tree, `tabled?`, and free-arg
  viability narrowing are all inert.
- **SRE lattice lens is mandatory** for any lattice/representation proposal
  (`structural-thinking.md` — the 6 questions, incl. the Hasse-diagram optimality argument).
  Any new cell/merge must be **SRE-registered** (today's `relation-store-merge` is not).
- **Owner co-designs in PROSE** (Q_N labels, not AskUserQuestion chips) —
  [[design-dialogue-preference]]. Conversational cadence: checkpoint at boundaries.
- **Grounding-audit workflow** is the default opener for a grounding-heavy sub-phase
  (`.claude/workflows/grounding-audit.js`) — but this session opens as a *conversation*; the
  §4 grounding is already done (`wf_bf2bee13-398`).
- A tracked design that completes **gets a PIR** (Rel T1's `X.close`); the track does not flip
  ✅ until it lands.
