# Efficient Fact Representation + Query Optimization — Stage-0/1 Research Artifact

**Rel Track 1, Aspect D (D.0/1)** · 2026-07-23 · HEAD `9bff07ff` (code byte-identical to
grounding SHA `d239dd9d`; the two commits since are docs-only) · Suite GREEN 8966/468/0

**Status**: Stage 0/1 (survey → problem definition → staging). This is a RESEARCH artifact,
not a Stage-3 design. Implementation is staged: a cheap-wins slice stays in Rel T1 (§7 NOW);
the substantive build spins out as a follow-on REL track (§11 charter seed) — owner ruling,
2026-07-22.

**Provenance**: 56-agent research sweep (`wf_ed1f77a6-aa9`): 6 in-repo grounding facets +
7 first-round external literature surveys + an adversarial completeness critic that forced
8 round-2 gap-fill surveys + 15 substrate mappings, each adversarially attacked before
synthesis. Load-bearing repo claims main-session re-verified at HEAD. **Coordinates DRIFT**
— every file:line below was verified at `9bff07ff`; re-grep before trusting.

**Measurement caveat**: the timing numbers in §2.5 are single-warm-run measurements
(directional, not `bench-ab` statistical rigor). The deterministic counters are exact.

**Reading guide**: §1 the adopted frame · §2 problem definition (measured) · §3 regime /
engine / baseline resolutions · §4 literature map · §5 structural (lattice) analysis ·
§6 what the critiques killed · §7 staging ladder · §8 benchmark spec · §9 truth-maintenance
· §10 roadmap adjudications · §11 Rel T2 charter seed · §12 open questions · §13 citations.

---

## 1. The adopted frame (owner decisions, 2026-07-22)

Recorded as DECIDED (from the framing co-design conversation; re-openable but not to be
silently re-litigated):

- **F1 — Engine-neutral, strictly propagator-based fact store.** One store layer — cells +
  monotone merges — consumed by BOTH the DFS engine and the on-network solver through a
  defined read surface. Query-*optimization* tuning may live in solver configs; the *store*
  is shared. Per the Cell/Propagator/Scheduler orthogonality rule, "tunable" means
  cell-level storage-strategy declarations + propagator fire-patterns, never scheduler
  coupling.
- **F2 — Scale target: Regime 1, design point ~100K–1M rows**, real-world multi-table data,
  driven by the DEMO through-line (dependency-resolver; movie/transportation datasets).
  The *current* corpus is ≤16 rows; the target regime must be **created** via bulk import
  (F5) and measured via the Phase-0 benchmark (§8).
- **F3 — Baselines: in-process SQLite (prepared statements) vs Soufflé vs HEAD**, built
  incrementally with the microbench suite + A/B discipline; measurement feeds design.
- **F4 — Deliverables**: this artifact + a cheap-wins slice landed in Rel T1 (§7 NOW) + a
  charter seed for a follow-on REL track (§11) that subsumes the RPF bullet list. "RPF" is
  not a series/track name; the follow-on effort is a REL track.
- **F5 — Bulk import is a real demo target** (`:source`/`:from`; CSV, SQLite, JSON records),
  co-designed with representation (§3.2), possibly with its own track-scale scope.
- **F6 — Algebraic posture**: formal correctness required; engineering pragmatism biased;
  deeper SRE/lattice-first routes on the table where they are competitive (PUnify
  precedent). The three vision equations get explicit adjudication (§5.6), not citation.
- **F7 — Relationship to the 2026-03 seed**: build FROM the seed conversation
  (`standup-2026-03-11.org:506-696` + `2026-03-06_1400_RELATIONAL_FACT_DESIGN.md`) with
  fresh eyes — critique it, keep what holds (§3.3).

---

## 2. Problem definition — the engine at HEAD

### 2.1 Fact storage and the five scan sites

A relation is a `relation-info` (relations.rkt:557) of `variant-info`s (:549, fields
`params clauses facts`). Facts are a Racket **list** of `fact-row`s, and each `fact-row`
(:543) wraps its terms in a **linked list** — not the flat vector the 2026-03 design
recommended as "primary representation." Consumers use `list-ref` / `in-list` / `length`
in hot loops (e.g. typing-core.rkt:3625-3626 does `list-ref` at position p inside a
per-position loop ⇒ a full column scan is O(rows × cols²), not O(rows × cols)).

Fact matching is **linear scan at five distinct sites**, none consulting an index:

1. `tier-1-direct-fact-return` (relations.rkt:3022-3025) — the fast path; scans every row,
   **no early exit** even on a ground point query.
2. `solve-app-goal` (:1541-1554) — the DFS path; `append-map` over variants → rows →
   left-to-right `unify-terms`; **no ground-arg pre-filter**; per goal, per backtrack point.
3. `explain-app-goal` (:1877-1891) — its own copy of the scan.
4. `install-clause-propagators-inner` (:2602-2695) — the on-network install walks every row.
5. `build-discrimination-data` (:613-651) — itself an O(N·arity) scan.

Downstream, results are materialized **row-wise as CHAMP maps** — one trie per answer, K
`equal-hash-code` computations each (reduction.rkt:243-254) — the representation the
2026-03 design argued against, sitting on the output path.

### 2.2 Not-an-index: the discrimination machinery

`build-discrimination-data` is often mistaken for an index. It is a **forward** map
`position → (alternative-idx → expected-value)` (:598-599). Answering the query-relevant
question — "which rows have value *v* at position *k*?" — is still a full scan of the map
(:868-879, plus a second O(N) pass to recover wildcard rows :875-878). A real index is the
**inverted** `value → set-of-row-indices`; it does not exist anywhere in the tree.

Worse: the forward map is **rebuilt from scratch on every goal invocation**
(`install-discrimination-propagators` :805 ← `install-clause-propagators-inner`
:2583-2584). `relation-register` (:570-571) is a bare `hash-set` and computes nothing —
its own comment at :569 ("computes discrimination map at registration time") is **false at
HEAD**.

### 2.3 Dead code and doc/code drift

Do not design against these; they are inert (all grep-verified, production + tests):

- The Phase-1b **discrimination TREE** (:665-793, ~130 lines) — a greedy multi-column
  best-position index-selection value, the only such algorithm in the repo — has **zero
  callers**; its own comment demotes it to "a data value for analysis/self-hosting."
- `relation-info-tabled?` — **doubly dead**: zero readers AND both construction sites
  hardcode `#f` (:920, :947). The documented `:tabled false` opt-out does nothing.
- Free-arg viability narrowing — `viability-cid` is written by fire-once propagators but
  read exactly **once, at install time** (:2590); arguments that become ground during
  propagation never prune. The meet direction is structurally inert (see §5.2).
- The `+/-/?` **mode lattice** on `param-info` and the C.a `type` slot (`b33474aa`) are
  both **stored and never read** in production. Two incompatible mode alphabets
  (`'in`/`'out` from the parser; `'ground`/`'output` from the elaborator) coexist
  undetected precisely because nothing branches on them.
- Comment/code contradictions: cell-2's merge comment claims "hash-union (monotone
  accumulation, CALM-safe)" (propagator.rkt:623) over a per-key **last-write-wins** body
  (:628-634); :567/:585/:2577 claim registration-time + broadcast where the code is
  per-query + fire-once.

### 2.4 Routing and the ATMS cost

Engine dispatch (stratified-eval.rkt:263-267): the on-network path engages only when
`(facts + clauses) ≥ solver-config-threshold`, default **256** (solver.rkt:76). Two Rel T1
scaffolding gates (`reachable-has-body-local-rule?`, `reachable-has-guard?` — retirement
owner BSP-LE Track 3) force rule- and guard-bearing queries to DFS regardless. Since every
fact block in the repo is ≤16 rows (max: `parity-adversarial.prologos:70`), **every real
query today runs the DFS linear scan**; the on-network path is untested at any scale where
indexing matters.

When the on-network path does engage: **one ATMS assumption + one worldview bit per fact
row** (`solver-assume` :2645-2649; bit :2675), one fire-once propagator per (row × bound
arg) (:2686-2692). At N rows / arity k: N assumptions, an N-bit worldview mask — **bignum
past 62 rows**, after which every `bitwise-and` allocates — and N·k installs per query.
Additional confirmed walls: fact-NAF is quadratic (`naf-per-binding-mask` runs a full DFS
solve per candidate binding); tabling answer accumulation is **Θ(A²)**
(`table-answer-merge` = `remove-duplicates ∘ append`, atms.rkt:100, no empty
short-circuit) and tables are keyed by predicate **name only** (no variant tabling);
tabling is **intra-query** (the solver context is forked fresh per query :3102-3105 and
discarded at dissolution :3150 — nothing survives).

### 2.5 The measured cost structure

Decompose one goal query: **(a)** setup (fork network from cached empty template + write
the whole store into cell-2); **(b)** the scan, Θ(N·k); **(c)** the discrimination rebuild,
Θ(N·arity); **(d)** on-network branching, Θ(N) assumptions + bignum mask + Θ(N·k) installs;
**(e)** result materialization, Θ(answers·K) with per-cell hashing.

Measured at HEAD (single warm run; 2-column ground-first-arg point query, last-row hit):

| N rows | Tier-1 scan (b) | Discrimination rebuild (c) |
|---:|---:|---:|
| 100 | 0.0070 ms | 0.0258 ms |
| 1,000 | 0.0883 ms | 0.3694 ms |
| 6,000 | 0.3599 ms | 1.8368 ms |
| 20,000 | 1.2494 ms | **11.4014 ms** |

The scan is cleanly linear at ≈0.062 µs/row; the rebuild is **superlinear** and dominates
the on-network install path at every measured N ≥ 1,000. Extrapolating the fast path
(estimate, linear): sub-millisecond breaks at ≈16K rows; ≈30 ms at ≈480K rows; **≈62 ms at
1M rows** — i.e. at the F2 target's ceiling, the *fastest current path* is ~2× slower than
the vision doc's own 30 ms SQLite figure, and the on-network path is structurally unable
to operate (10⁵-bit bignum masks).

**Headline**: at the F2 scale, the dominant costs are (c) the gratuitously repeated
rebuild and (d) per-row ATMS branching — **neither of which any storage-layout change
addresses**. Tuple layout is the fifth-most-important problem on this list.

### 2.6 The five levers (independent; ascending ambition)

- **(a) Remove gratuitous waste** — hoist the rebuild to registration; add ground-key early
  exit; normalize-at-ingest; delete dead code. Behavior-preserving; pays at every scale.
- **(b) Add asymptotic structure** — registration-time inverted `value → row-set` index on
  `+`-moded/first-arg positions (BEYOND_PROLOG §2: "the single highest-impact optimisation
  … Prologos currently lacks it entirely" — premise re-verified TRUE at HEAD). Where the
  mode lattice finally earns its keep.
- **(c) Change the representation** — typed flat/columnar storage. C.c (`357035d5`)
  guarantees schema ⟹ facts-only and `check-relation-schema-rows` (driver.rkt:484-510)
  certifies per-column type homogeneity — schema'd relations are *closed, ground, typed
  tables*, exactly columnar's precondition. Larger; interacts with the ATMS row-bit
  problem.
- **(d) Change the execution model** — WCOJ/semi-naive/magic sets. Research-grade; named
  and scoped here, owned by the follow-on track and its RESEARCH-OPEN ladder.
- **(e) Change where the work happens** — compile-time specialization vs runtime. §4.5
  dead-end #5 (Kohn ICDE 2018) bounds this hard at small N; on-network specialization only.

---

## 3. Regime, engine, baseline — resolved

### 3.1 Scale regime (F2) and its consequences

The vision names three regimes by row count only (RELATIONAL_LANGUAGE_VISION.org:861-889;
no latency boundaries attached). F2 pins the design point at Regime 1's upper half:
**100K–1M rows, multi-table joins, real data**. Consequences, now design-blocking rather
than observations:

1. **Per-row ATMS assumptions cannot survive contact with the target** (§2.4). Ground
   imported facts must become worldview-transparent — assumption granularity coarsened to
   per-source / per-import-batch, or ground base facts carry **no** assumption (speculation
   enters with rules, NAF, and hypothetical `:assume` — not with a CSV row). This is the
   deep research question (§5.4, R2).
2. **Fact-NAF at N×O(N) and Θ(A²) answer accumulation are disqualified** at 100K.
3. **Intra-query-only tabling inverts the thesis** — "we win by not paying per-query
   overhead" cannot coexist with redoing a 1M-row scan per repeated query. Cross-query
   persistence is mandatory.
4. **The small-N regime does not disappear**: the language will still run 16-row tables
   constantly. The store must be adaptive — the literature's answer for small N
   (interpreter + zero setup + lazy structures, §4.4) *is* the answer for our small tables,
   with structure engaging as N grows. No cliff, no per-query setup tax.

### 3.2 Bulk import and representation are ONE design

`:source`/`:from` has **zero hits** repo-wide (only an unrelated `#:source-dir`,
driver.rkt:2414); a standalone RFC-4180 CSV FFI exists with no path to a relation
(io-ffi.rkt:44-49, 187-320). This absence is *why* the corpus has no scale.

The audit's warning that columnar is "not a drop-in" (terms are raw AST, normalized lazily
at every comparison, :979-981/:393-399) is an artifact of the **authoring** path. An
imported row never was AST — it arrives as data, is schema-checked once at load
(driver.rkt:493-509 already runs per-row `check` at defr time), and can be laid down
directly in the target representation. **The import path is the easiest place to introduce
a new representation**; the `||` authoring path converts into it at registration as the
special case. Add C.c and the pieces align: **schema'd + imported relations are exactly the
typed, ground, fixed-width tables that indexed/columnar storage wants.** The follow-on
track co-designs store + import; it does not sequence them.

### 3.3 The 2026-03 seed, re-examined (F7)

What HOLDS (adopt): the **schema-as-Rosetta-Stone bijection** (storage positional, surface
keyed, erased at compile time) — the bijection exists as data at HEAD (ordered
`schema-field` list, macros.rkt:781/788) and is the single most reusable asset for any
columnar layout. **Flat vectors over PVec/CHAMP for the hot fact path** — still right; the
engine actually shipped something *worse* than the recommendation (linked lists). **Schema
as the CSV/SQL/JSON interop contract** — now load-bearing under F5.

What needs CORRECTION or completion: (i) key→index lookup is a **linear** `for/first`
(`schema-lookup-field`, typing-core.rkt:526-529) — no precomputed key→position hash exists;
the bijection must be materialized. (ii) **Keyed goal patterns are entirely unimplemented**
(elaborator.rkt:3002-3008 elaborates goal args positionally, zero schema consultation) —
and they matter for *efficiency*, not just ergonomics: a keyed pattern is exactly the
bound-columns metadata an index probe wants. (iii) The standup's final storage
recommendation (per-schema **generated structs**) was dropped in the committed distillation
— an information loss; the option returns to the table in the follow-on track. (iv) The
seed's framing ("make unification against a row fast") missed the actual cost structure —
the per-query rebuild and the missing inverted index dominate layout by orders of
magnitude (§2.5). The seed answered "what shape is a row"; Aspect D's answer is "the row
shape is lever (c), and levers (a)/(b) come first."

### 3.4 Engine (F1) and baselines (F3)

Engine-neutral store, strictly propagator-based: the store is cells + lawful merges; DFS
reads it via `net-cell-read` (a read is scheduler-independent by construction); the
on-network engine consumes the same cells natively. This dissolves the "which engine?"
fork — both engines get the representation + indexes; the ATMS-granularity redesign (R2)
is what later makes the on-network path viable at scale.

Baselines and what each proves: **in-process SQLite, prepared statements, warm** — the
honest interactive-query bar (falsifies or grounds the vision thesis; the ~30 ms figure is
a cold-pipeline anecdote, §9); **Soufflé** — the Datalog fixpoint/recursion bar (with the
Flix result, §4.3, calibrating what "respectable" means for a language-integrated engine);
**HEAD** — the honest delta for every A/B.

---

## 4. The literature map

### 4.1 Five orthogonal axes

The single most common error in this space (stated explicitly by Abadi/Madden/Hachem,
SIGMOD 2008) is conflating axes. A working engine is a *point in the product*:

- **Axis A — Representation**: row (NSM) vs column (DSM) vs hybrid (PAX/Arrow); encoded vs
  raw; mutable vs persistent. Governs cache/bandwidth behavior.
- **Axis B — Join algorithm**: binary/goal-at-a-time vs variable-at-a-time (WCOJ). Governs
  worst-case complexity.
- **Axis C — Plan/optimizer**: how steps are ordered; the 2020–2026 story is the
  cost-based hybrid sliding between binary and WCOJ inside one plan.
- **Axis D — Incrementality**: batch vs delta-maintained (semi-naive / differential).
  Governs whether accumulated state is re-touched.
- **Axis E — Algebra**: AGM / factorization / FAQ — bounds output and representation size
  before any algorithm runs.

The crosscut that dominates *us* is not an axis: it is **N**. Our regime spans 16 rows
(today) to 1M (F2 target), and most of the sophistication inverts sign at the small end
(§4.4).

### 4.2 Per-axis state of the art (compressed; citations §13)

**A**: Layout alone buys ~nothing — the C-Store ablation decomposes the win as late
materialization ~2.6×, compression ~2.0×, invisible join ~1.5-1.75×, block processing
1.05-1.5×; stripped of those, the column store *lost* to the row store. Both newest
production engines (Photon, Velox) chose interpreted vectorization over codegen for
engineering reasons. FastLanes achieves "SIMD-like" speed with pure 64-bit scalar code —
the most transferable encoding result for a Racket host. The persistent-substrate corner:
CHAMP's own paper warns HAMT iteration/equality lag arrays (its fix: 1.3-6.7× iteration,
3-25× equality); **nobody has measured vectorized execution over 32-wide persistent-trie
leaves** — a genuine open gap we would be first to map. The DB shape for persistent
columnar is **main + delta** (immutable read-optimized main, small write delta, background
merge) — structurally an LSM, and the shape of DD's arrangements.

**B**: AGM bounds output size; NPRR/Generic Join/LFTJ match it; binary plans are
Ω(N^{1-1/k}) worse in theory. In practice: **Generic Join loses to DuckDB's binary hash
join by ~3.3× geomean on the acyclic JOB**; Free Join (Generalized Hash Tries + the COLT
lazy trie) recovers to 2.94× *faster* geomean. **Skew, not cyclicity, is when WCOJ wins**
(Free Join's own honest finding). Trie construction cost is excluded from the WCOJ formula
and is where the win gets eaten.

**C**: The winner is the cost-based hybrid (Umbra: multi-way join only where intermediates
grow — up to 2 orders on cyclic workloads, zero regression on TPC-H/JOB). Yannakakis is
already optimal on acyclic queries, which bounds WCOJ's applicability. Cardinality
estimation dominates plan quality (Leis VLDB 2015).

**D**: DD arrangements = shared, LSM-structured, multiversioned indexes; DDlog
auto-incrementalizes Datalog onto them — at **orders of magnitude more memory** than
Soufflé on batch workloads. Incrementality is a choice to make only when inputs stream.
DBSP formalizes IVM as stream algebra over abelian **groups** — see §5.3 for why that is
architecturally forbidden here, and what the lattice-compatible fragment is.

**E**: FAQ unifies joins/aggregation/inference over semirings; submodular width / PANDA is
the theory frontier, not deployed engineering. Most relevant to us as the formal frame the
SRE/semiring direction should be checked against (§5.6, F6).

### 4.3 The competitive bar, concretely

- **Datalog/program-analysis scale**: Soufflé, OpenJDK points-to: 35-75 s where SQLite
  takes 6h20m and bddbddb 30 min. Soufflé auto-index selection lands within ~1× of expert
  hand-tuning at 2-5× less memory.
- **The language-integrated floor**: **Flix — same index-selection algorithm as Soufflé,
  concurrent B+ tree, JIT — is 8-13× slower than the Soufflé interpreter** on 1M-edge
  reachability, and its authors call that "useable but not yet state-of-the-art." This is
  the honest first bar for a language-integrated, substrate-constrained engine. Prologos
  today is far below it (unindexed linear scan).
- **Join-heavy interactive**: Free Join vs DuckDB on JOB (built on **IMDB** — convergent
  with the demo's movie-dataset instinct): 2.94× geomean, 0.85× worst case.
- **No published benchmark matches our workload** (tens-to-thousands of rows, persistent
  substrate, no SIMD, goal-at-a-time interactive queries, speculation). The nearest
  signals: the small-N results below. Hence §8: we must author the instrument.

### 4.4 What the literature says about small N (decision-relevant core)

- **Vectorization amortization floor ≈ 64-128 tuples/batch** (X100 Fig 10; reproduced
  Kersten 2018: <64 degrades sharply, ~4-5× at vector size 1). Below it, only
  branch-elimination/type-specialization survive. Note: persistent-vector leaves are
  32-wide — *below the floor*; leaf-batching is required and unmeasured.
- **Any per-query setup above ~1 ms disqualifies** (Kohn/Leis/Neumann ICDE 2018: <1 ms
  query behind 54 ms LLVM compile; even HyPer ships an interpreter). Our per-query
  discrimination rebuild is *natively* this pathology (11.4 ms @ 20K).
- **COLT — the Column-Oriented Lazy Trie** (Free Join §4.2) is the single most important
  small-N technique surveyed: a "trie" that starts as a bare offset vector, hash-forced
  per level on first probe, only for the reached sub-relation. Geomean 1.91× over
  eager-first-level, 8.47× over fully-eager. Pays index cost only where a lookup happens —
  and its monotone vector→hashmap refinement is structurally compatible with a lattice
  substrate.
- **Small-N is endogenous at any scale**: 39% of hash-join output chunks on JOB/DuckDB
  contain exactly one record (Qiao & Zhang SIGMOD 2025). An engine whose intermediates are
  small lives in this regime even when base tables are large.
- **Zone maps are free on immutable chunks** (min/max at seal time, never invalidated) —
  the cheapest indexing that exists, a natural fit for a persistent substrate; prunes
  nothing on random order.
- **Without SIMD, selection vectors beat bitmaps** unambiguously (Ngom DaMoN 2021).
- **Sophisticated structures pay overhead for nothing at tiny N**: EqRel's tiny case costs
  ~4× memory vs a B-tree; WCOJ's worst cases regress 0.85×/0.43×; CP's Compact-Table
  literature says don't build a bitset at table size ≤64.

**The synthesis for our regime**: an interpreter with near-zero per-query setup, lazy
COLT-style index materialization, seal-time zone maps on immutable chunks, selection-vector
filtering — with eager registration-time inverted indexes exactly where the mode/schema
metadata proves them worthwhile. That is the shape §11 charters.

### 4.5 Dead ends (do not repeat)

1. **Layout alone** (C-Store ablation: the stripped column store lost to the row store).
2. **Eager trie/index construction** (EmptyHeaded: up to 2 orders more time precomputing
   than joining; LogicBlox LFTJ up to 2 orders slower than binary-join Umbra).
3. **WCOJ purity** — every credible 2020-2026 system is a hybrid; replacing binary join
   regresses the acyclic majority.
4. **Cyclicity as the WCOJ predictor** — it's skew (Free Join, LSQB).
5. **Whole-query compilation for short queries** (54 ms compile / <1 ms query).
6. **Bitmaps as filter representation without SIMD**.
7. **Dense order-preserving dictionary codes under changing data** (Umbra hashes raw
   values instead).
8. **Explicit materialization of equivalence pairs** (EqRel: a week vs <6 s union-find).
9. **In-DBMS incrementality machinery for batch workloads** (DDlog memory).
10. **DRed as the primary deletion mechanism** — over-deletes under self-supporting
    recursion; see §5.3 for the alternative.

### 4.6 Round-2 communities (what the completeness critic forced in)

- **RETE/TREAT/LEAPS** (production rules): alpha/beta memories ARE incrementally-maintained
  join state on a propagator-shaped network — our nearest architectural cousin. Adopt
  **Nayak's four-conditions checklist** for when a join memory is worth materializing
  (guards against premature beta materialization). TREAT/LEAPS's laziness lesson is
  already embodied by our DFS (no conflict-set materialization). The genuinely novel
  post-persistence capability: **one beta cell holding a join under all speculative
  worldviews at once** — no RETE system can express it.
- **Term indexing (ATP)**: the community whose retrieval primitive matches ours
  (unification, not equality). Discrimination/path/substitution trees; **fingerprint
  indexing** (union-over-compatible-leaves; monotone-set leaf cells) is the best
  substrate-fit direction post-persistence. One free soundness invariant to bake into ANY
  index: **a non-ground key contributes no constraint** — fall through to scan, never
  mis-filter.
- **WAM/JITI (Prolog practice)**: first-argument indexing is table stakes (the thing we
  verifiably lack); YAP's demand-driven **just-in-time multi-argument indexing** is the
  Prolog-native form of COLT laziness, and maps naturally onto the topology stratum
  (index creation as a between-rounds structural request). Determinism detection
  (|matches| = 1 ⇒ no choice point) maps to *skipping the ATMS fork entirely* — dodging
  the per-row assumption cost on the largest class of queries.
- **CP Compact-Table**: table-constraint filtering with residues; the negative result
  (no bitsets ≤64 rows) and the post-persistence novelty (cross-worldview shared residues;
  supports-index-as-why-provenance) both carry.
- **Indexes under speculation (MVCC/versioned/temporal)**: the design constraint that
  survives — **stable fact row-ids + logical (never physical, never worldview-baked)
  pointers** in every index entry. DD-style multiversioned arrangements are blocked until
  a version lattice distinct from the worldview bitmask exists.
- **XSB tabling tries**: subsumptive tabling needs canonical variant renumbering — a
  *semantic* gap at HEAD (tables keyed by name only), not a data-structure swap. The
  answer-cell set-union fix (§7 N-adjacent, L4) comes from here.
- **Soufflé MISP** (auto index selection, minimum chain cover / Dilworth): the right
  *planner* once indexes exist; its static-enumeration weakness becomes a feature if
  realized demand-driven (JITI-style) via the topology stratum.
- **DBSP/DD/Z-sets**: the formal IVM frame; adjudicated §5.3.

---

## 5. Structural analysis (SRE lens — mandatory for every claim here)

### 5.1 The lattice of a fact table — five candidates

**(a) Today's per-relation blob, per-key last-write-wins (cell-2).** NOT a lattice: the
merge (propagator.rkt:628-634) is order-dependent at the value level; the ":623 CALM-safe"
comment is false; the cell is **not SRE-registered** — the entire relational subsystem
(`relation-store-merge`, `solver-term-merge`, `logic-var-merge`, `discrimination-data-merge`)
has zero `register-merge-fn!/lattice` entries. No lattice ⇒ no Hasse diagram ⇒ no
principled parallel decomposition. **The on-network story is false at the relational root
until a lawful join replaces this.** This is the first fix, prior to any representation
choice.

**(b) Per-relation set-of-rows, dedup-union.** A proper join-semilattice (`merge-set-union`
is commutative/associative/idempotent; bot = ∅; CALM-safe). Hasse = the Boolean lattice
Q_|rows| (adjacency = single-row insert). The cleanest meaning of "facts form a join
lattice." Caveat: rows are `equal?`-classes, so this needs a **new `equal?`-based set
domain** (seteq's eq? bot is wrong for fresh structures) — a one-registration gap.

**(c) Per-fact-grained components** (compound cell keyed by fact-id). STRUCTURAL product of
absent/present two-point lattices — again Q_n, but with **component-path precision**: a
watcher wakes on one fact, not the store. The only design where a single fact insert IS a
delta. The granularity RPF item 1 names.

**(d) Columnar per-(relation, position).** STRUCTURAL product of per-column lattices —
the shape `attribute-map` and `discrimination-data` already realize. Monotone **iff
positional identity is stable**; the row↔position bijection must be materialized (it is
not: key→pos is a linear scan, §3.3), and under speculation, tagged-entry lists do not
preserve a per-worldview row order — see §5.4.

**(e) An index as a derived cell** — §5.3; it is a *derived* lattice, not a primary one.

**Verdict**: (b)/(c)/(d) are all genuine join-semilattices with Q_n/product Hasse
structure; (a) is the incumbent and the outlier. The migration is not "add columns"; it is
**"give the fact store a lawful join first."**

### 5.2 The join/meet tension — resolved as a Galois pair

Facts **accumulate** (extent only grows: join) while query answering **narrows** (viable
bindings only shrink: meet). The defensible formalization is **two lattices on different
carriers joined by a Galois connection** — NOT a bilattice (bilattices put two orders on
one carrier and buy a negation operator we don't need). This is exactly Apt's *Essence of
Constraint Propagation* (1999): chaotic iteration of monotone, inflationary, idempotent
narrowing operators to a common fixpoint; CLP(FD) domain narrowing is the canonical
instance; **semijoin reduction / Yannakakis is the same shape** — project a relation onto
a shared attribute (the α of the pair), narrow the other's domain, with sweep order
emerging from the join-tree topology. `structural-thinking.md` already names both halves
("unification is a lattice meet"; "retraction is lattice narrowing").

Realization gap at HEAD: the meet side needs **descending cells** (reverse-inclusion
merge, ⊔ = ∩) — `net-new-cell-desc` exists (propagator.rkt:1438) but **no descending SRE
domain is registered**, and the one live viability cell is read once and never again
(§2.3). The meet direction is structurally inert today. Open (R1): reconciling ascending
and descending cells on ONE network per-worldview without contaminating each other's
monotonicity; the full bridge diagram including the (orthogonal, Boolean) worldview
lattice has not been drawn.

### 5.3 Is an index a derived cell? Yes — with three literalness conditions

The index is DERIVED (SRE Q5), the fact cell PRIMARY: a posting-list index
`hasheq value → set-of-row-ids` with per-key set-union — a proper join-semilattice —
maintained by a propagator watching the fact cell. (Nearest shipped carrier,
`'hash-of-lists-accumulator` (infra-cell.rkt:154-162), does per-key list-append — not
idempotent; the set-valued variant is a one-registration gap.) The code already names this
target: the discrimination comment's "derivation propagator watching the relation-store
cell."

- **Insert half**: literal NOW in shape — "the worklist IS the delta"
  (DESIGN_PRINCIPLES.org) is semi-naive evaluation at the cell layer.
- **Delete half**: non-monotone ⇒ S(-1). Template: `process-retraction`
  (metavar-store.rkt:1606-1621) narrowing by intersection — but it is O(cells × contents)
  per round (quadratic at table scale, must be adapted, not copied), and any ordered
  handler pair hits the verified **`#:after` gap** (registration append-order,
  propagator.rkt:3211-3213; request cells auto-reset) — required substrate work.
  **Do NOT adopt DRed** as the primary deletion mechanism (over-deletes under
  self-supporting recursion). The lattice-compatible direction from DBSP: deletion as a
  positive write of negative weight into a monotone delta-batch LOG, with the group
  inverse relocated to a **derived between-round consolidation stratum** — RESEARCH-OPEN,
  the correct shape to explore.
- **DBSP proper is forbidden**: its incrementalization theorem needs abelian groups
  (inverses); an idempotent join-semilattice is not a group; adopting it would abandon
  CALM. This is a principled exclusion, recorded as decided.

**"Propagators = IVM" becomes literal exactly when**: (1) the derived index **outlives the
query** (persistence — today every solve forks a fresh empty network and discards it);
(2) a real **delta** exists (fact-grained cells, design (c)); (3) **deletion** lands at
S(-1). These are RPF items 1/3/4 — i.e. the §11 charter.

### 5.4 The worldview problem

An index must be correct per-worldview under speculation. Four options, judged on whether
they preserve the sharing that makes an index worth having:

1. **Tagged entries** (shipped mechanism): correct; but `tagged-cell-read` linearly scans
   an unordered entries list, masks go bignum past 62 rows, dissolution is O(N²·A) — the
   read cost destroys the index's advantage past tiny N.
2. **Per-worldview copies**: correct, zero sharing — self-defeating. Rejected.
3. **One index over all rows + bitmask filter at read**: preserves structural sharing;
   filter is O(1) only while masks fit a fixnum.
4. **MVCC/DD arrangements**: the literature's answer, **blocked** — DD proves a single
   total version order is insufficient (product order needed), and our worldview bitmask
   is an orthogonal assumption dimension, not a time trace; a version lattice would have
   to be built.

**Conclusion**: no option reconciles sharing with per-branch correctness past the ~62-row
fixnum boundary **without redesigning worldview granularity** — fact-SET-level (per-source
/ per-import-batch) assumptions instead of per-row, or zero assumptions for ground base
facts (speculation enters with rules/NAF/hypotheticals, not with imported rows). Three
independent mapping critiques converged on this. It is R2 — the deep research question —
and it is also the key that unlocks the genuinely differentiated capability no surveyed
engine has: **speculative what-if joins across alternative fact-bases sharing one index**.

### 5.5 Granularity — the recommendation

Per the cell-allocation rule (compound cells for cohesive scopes): a relation's columns
**change together at ingest** but are **read independently** at query time ⇒ the natural
decomposition is **one compound cell per relation, component-keyed by position** (design
(d)): one CHAMP write per ingest batch, per-column `#:component-paths` precision at read.
Per-fact granularity (c) is the *additional* refinement exactly where retraction needs
individually-narrowable facts. Guardrail from the critiques: **keep the binding-env /
scope-cell row-shaped** (do not columnarize the probe structure) — Photon's row-pivot
lesson, already satisfied by the compound scope-cell.

⚠ This **overturns DEMO design §D3's pre-committed per-relation `monotone-set`** (which
survived a P/R/M/S critique). Overturning a critiqued decision must be explicit: the D3
commitment predates C.c (schema ⟹ facts-only), the F2 scale target, and this survey's
component-path analysis. Q_A (§12) puts the call to the owner; the follow-on track's
Stage-3 critique round re-adjudicates with both options on the table.

### 5.6 The three equations, adjudicated (F6)

- **"Tabling = materialized views" — REFUTED at HEAD; promissory.** Tables are per-query
  and discarded; what exists is intra-query SLG-style memoization (valuable; the *tabling
  literature's* meaning, not the database literature's). Becomes literal with persistence +
  invalidation (S(-1)) + durable freeze — precisely §11's scope.
- **"Propagators = IVM" — ADOPT for the monotone half; over-claims unqualified.** Insert
  half literal now (worklist = delta = semi-naive); delete half unbuilt (S(-1) fact
  stratum); group-delta route forbidden (§5.3).
- **"ATMS = provenance semirings" — the MOST literal, and under-sold.** Support sets ARE
  the PosBool why-provenance semiring (Green–Karvounarakis–Tannen 2007 — the vision doc
  mis-cites this), pending minimality/absorption maintenance the tagged merge currently
  lacks. The general how-provenance/multiplicity/cost case is the designed-but-unbuilt
  `Semiring`-extends-`Lattice` trait (BEYOND_PROLOG §6; only tropical-fuel ships, wired as
  cost). This is the one place the substrate genuinely **generalizes** the DB literature
  (idempotent-semiring provenance as swappable domain registrations) rather than chasing it.

---

## 6. What the adversarial critiques killed

Honest failure list — proposals that did NOT survive verification:

- **Pure columnar layout as a near-term win** (its own ablation: ~0 payoff alone;
  precondition for scale-gated techniques; carrier-before-value debt).
- **"Revive the dead discrimination tree as the index"** — zero callers, self-demoting
  comment; revive-vs-retire must be explicit, and the recommendation is **retire** (the
  inverted index is a different, simpler artifact).
- **"Broadcast = realized parallelism"** — the broadcast fire-fn is a **sequential
  `for/fold`** (propagator.rkt:2448); the 2.3×/75.6× numbers are install-overhead
  amortization vs the deprecated N-propagator model, not parallel speedup. Every
  "all-in-parallel / Hasse-optimal" claim is *declared, not realized* at HEAD (realization
  = BSP-LE scheduler work); label accordingly.
- **WCOJ / LFTJ / EmptyHeaded / factorized reps / dictionary-on-codes / zone-map deployment
  as near-term items** — all scale techniques; unfalsifiable until §8's corpus exists.
  Parked in LATER/RESEARCH-OPEN, not killed as directions.
- **Unboxed/SIMD anything** — zero `flvector`/`fxvector`/`bytes`/`unsafe` in-tree; the
  self-hosting mandate wants columns expressible in-language. Foreclosed by construction;
  FastLanes-style scalar packing is the only encoding route left open (NEEDS_RESEARCH).
- **DBSP group deltas; FAQ variable elimination** — principled INCOMPATIBLE exclusions
  (CALM; sequential elimination fights Hasse-parallelism). Recorded as decided.
- **CAS/seqlock concurrent structures (Soufflé B-tree internals, LFHT)** —
  scheduler-coupled; off the BSP snapshot-and-merge model.
- **term-hash-style indexing of non-ground keys** — unsound; kept only as the invariant:
  non-ground key ⇒ no filter.

---

## 7. The staging ladder

### NOW — Rel T1 phase D.2 (days; no unbuilt prerequisites; all reversible)

| # | Item | Where (verified @ HEAD) | Effect / regime |
|---|---|---|---|
| N1 | **Normalize-at-ingest** — stop re-normalizing per-alternative / per-row-per-column | relations.rkt:854, :872, :3031-3032 (violate the code's own :387-390 discipline); ingest boundary = `extract-facts-and-clauses` :975-1005 | Pays at EVERY scale incl. N=16; boxed `equal?` → `eq?` on interned codes |
| N2 | **Invert the discrimination map** (forward → `value → row-set`) | build :613-651; consumers :850-858, :868-876 | O(F+C) → O(1) per ground position; latent until hundreds of rows but strictly better; enables L1 |
| N3 | **Hoist the build off the per-goal path** (registration-time; the :585 comment already envisions the derived-cell form) | :805 ← :2584 | Removes a MEASURED superlinear per-query rebuild (11.4 ms @ 20K); fixes the live pathology at any repeat-query scale |
| N4 | **Add `solver_row_scans` + `solver_col_compares` counters** (+ emit the inert `dependent-skips`, performance-counters.rkt:221) | 5-site pipeline.md change | Without these every representation A/B is blind on exactly the axes it moves |
| N5 | **Retire dead code + reconcile lying comments** — discrimination tree (:665-793), `tabled?` (:920/:947), viability path (:2590); comments :567/:569/:585/:623/:2577 | — | −130 LoC; removes revive-vs-retire ambiguity; doc-truth |
| N6 | **Phase-0 scale corpus** — extend `bench-solve-pipeline.rkt` (exists! DFS-only, bypasses dispatch) to E2E + engine pinning across the 256 threshold, + generator | §8 | The permanent instrument; unblocks falsifiability |

Ground-key **early exit** on Tier-1 rides along with N2/N3 (same code region).

### LATER — the follow-on REL track (§11); real prerequisites

| # | Item | Prereq | Scale |
|---|---|---|---|
| L1 | First-arg / mode-directed inverted index on the DFS path + Tier-1; determinism detection (skip the ATMS fork at \|matches\|=1) | cross-query persistence (else it re-creates the per-query-rebuild pathology) | 2-4 wk |
| L2 | Migrate `current-relation-store` off the parameter; lawful SRE-registered value-level join on cell-2 | ownership adjudication (Q_B); PM Track 12 interaction | track-scale |
| L3 | Store granularity build-out (per-relation compound, position-keyed; per-fact refinement for retraction) — the Q_A decision | L2 | wk-scale |
| L4 | Tabling answer-cell merge → `equal?`-based monotone-set (Θ(A²) → ~Θ(A)); consumer scan fix; variant tabling (canonical renumbering) | new set domain registration | 1-2 wk |
| L5 | Bulk import `:source`/`:from` (CSV/SQLite/JSON) co-designed with representation; normalize + schema-check at load | none hard; F5 | wk-to-track |
| L6 | Semi-naive fact-Δ + S(-1) fact retraction | persistence + the `#:after` stratum-ordering substrate fix | track-scale |

### RESEARCH-OPEN — no known answer on this substrate

- **R1** Ascending (join) + descending (meet) cells on ONE network under speculation; the
  full bridge diagram with the worldview lattice; a descending SRE domain.
- **R2** **Fact-set-level worldview granularity** (per-source/batch assumptions; ground
  facts assumption-free) — unlocks scale AND the speculative-join differentiator.
- **R3** WCOJ/COLT on persistent structures (no total column order, boxed values, 32-wide
  leaves) — the leaf-batching gap nobody has measured.
- **R4** Realized parallel broadcast (the scheduler decomposition BSP-LE owns).
- **R5** Semiring provenance beyond why-provenance (the `Semiring` trait; idempotent
  semirings only).
- **R6** Deletion as negative-weight writes + derived consolidation stratum (the
  lattice-compatible DBSP fragment).

---

## 8. The Phase-0 benchmark (spec)

**Base**: extend `racket/prologos/tools/bench-solve-pipeline.rkt` (exists; DFS-only;
bypasses driver + dispatch; not in suite) to E2E and across the engine threshold. New
cases join `benchmarks/comparative/` beside `solve-adversarial.prologos`; generator + micro
cases extend `benchmarks/micro/`.

**Datasets**: row counts 10 · 100 · **250 · 260** (bracket the 256 threshold) · 1K · 10K ·
100K (+1M stretch, import-gated); arity 3 vs 15; dense-int keys vs boxed-symbol keys;
high- vs low-selectivity columns. Generator emits literal `.prologos` fact blocks until
`:from` exists (L5). **Real-data track** (F2/F5): an IMDB-derived subset (JOB-adjacent —
lets us reuse the literature's query shapes) and/or a transportation-statistics table set,
sized 100K+.

**Query shapes** (all 8 required): ground-key point lookup (exposes the missing early
exit) · partial-key · full enumeration · all-ground boolean membership (Tier-1
fall-through) · 2-way and 3-way joins (DFS-routed today) · transitive closure (the
semi-naive axis) · fact-NAF (the quadratic) · repeat-query (exposes intra-query-only
tabling + the rebuild).

**Engine pinning**: never rely on `:auto` — pin `solver`/`solve-with` to force DFS vs
ATMS per case. **Locating the actual DFS↔ATMS crossover is a headline deliverable** (the
256 default is a guess; it has never been measured).

**Metrics**: deterministic counters first (`solver_backtracks` — sum of BOTH sites :1524 +
:1837 — `solver_unifies` :1220, `cell_allocs`, `prop_firings`, + the new N4 counters);
wall time via `bench-ab.rkt` (Mann-Whitney; interleave or worktree-pin the baseline).
**Separate registration/load time from query time** (defr runs per-row schema `check`).

**Baselines**: HEAD self-compared → DFS-vs-ATMS crossover map → in-process SQLite
(prepared, warm) and a small Soufflé program at 10K+ rows — making the vision doc's
performance claim falsifiable rather than inherited.

---

## 9. Truth-maintenance obligations (before ANY performance claim ships)

1. **De-escalate the "sub-ms vs ~30 ms SQLite" claim** (RELATIONAL_LANGUAGE_VISION.org
   ~:696): it is an unreproduced anecdote about a *different system* (SWI-Prolog) against
   a **cold-pipeline** SQLite call (connect+parse+plan+marshal); warm prepared-statement
   SQLite is single-digit µs. Restate the thesis as what it actually is — *avoided
   per-query overhead* — which our own per-query rebuild currently violates.
2. **Remove "first-argument indexing" from the advantages-we-have list** — BEYOND_PROLOG
   §2 is correct: we lack it entirely (re-verified at HEAD).
3. **Fix the provenance citation**: Green–Karvounarakis–Tannen, PODS 2007 (not "Deutch et
   al."); and state the honest scope (PosBool why-provenance only, pending minimality).
4. Fix the four **lying comments** (N5): relation-register "registration time" :569;
   cell-2 "hash-union CALM-safe" propagator.rkt:623; "broadcast propagators" :2577;
   discrimination "registration" :567/:585.
5. Either implement or un-document **`:tabled false`** (currently a no-op).
6. Reconcile the **two mode alphabets** (`'in`/`'out` vs `'ground`/`'output`) before L1
   makes modes load-bearing.

---

## 10. Roadmap adjudications

- **`current-relation-store` ownership is a three-way claim**: PM Track 12B lists it among
  registries to retire (DEFERRED.md:895, gated on PM Track 12 ⬜); the RPF list claims it
  for persistence; this work claims it for the store lattice. **Recommendation**: the
  follow-on REL track (§11) takes ownership outright (it is doing the actual migration
  and defines the replacement lattice), with PM 12B's order-independence requirement
  imported as an acceptance criterion. Needs owner sign-off (Q_B).
- **BSP-LE Track 3** (⬜; owns tabling/SLG + the table-answer cell format + the A.2b/A.4
  scaffolding retirements) is **independent but surface-coupled**: fact-store format and
  table-answer format are the same structural question at two altitudes (DEFERRED.md:1267
  names the four co-change sites). **Recommendation**: the §11 track's Stage-3 design
  includes a joint cell-format section reviewed against the Track 3 seed
  (`2026-07-20_BSP_LE_TRACK3_ONNET_SEED.md`); neither blocks the other.
- **DEMO P3** ("per-relation `monotone-set` fact cell + single-shot `:from` load") is
  subsumed by §11 (it *is* L2+L5's first slice); the D3 granularity commitment is
  re-adjudicated there (Q_A).
- **The RPF bullet list dissolves into §11.** Its five items map: persistent fact-grained
  cell → L2/L3; off-parameter migration → L2; incremental re-load + tabling invalidation →
  L5/L6; S(-1) fact retraction → L6; indexing + flat-vector storage → L1 + the Q_A
  representation decision.
- **UCS Track 6** (types-as-predicates) and **CIU T6 Path Selection** remain orthogonal;
  Num T1 ✅ unblocked DEMO P1 (tracker note stale).

---

## 11. Charter seed — the follow-on REL track ("The Fact Store")

*Working name: Rel Track 2 — Persistent Fact Store + Query Structure. To be chartered as
its own tracked design (acceptance file, X.close, PIR) after Rel T1 closes D.*

**Goal**: an engine-neutral, strictly propagator-based fact store that makes the DEMO's
real-data target real — **100K–1M-row multi-table datasets, bulk-imported, queried at
interactive latency** — while keeping ≤100-row tables at today's zero-overhead behavior.

**Pillars** (from this artifact's evidence):
1. **Lawful store lattice** — replace cell-2's last-write-wins with a genuine join;
   SRE-register the entire relational domain family; granularity per Q_A. (L2/L3)
2. **Bulk import co-designed with representation** — `:source`/`:from` for CSV/SQLite/JSON;
   normalize + schema-check once at load; the authoring path converts at registration.
   (L5, F5)
3. **Indexes as derived cells** — registration-time inverted index on moded/first
   positions; COLT/JITI-style lazy materialization beyond that; zone maps at chunk seal;
   the non-ground-key soundness invariant; MISP-style selection once multiple indexes
   exist. (L1)
4. **Cross-query persistence** — the store + its derived indexes outlive the query;
   makes tabling = materialized views literal; rematerialization break-even measured, not
   assumed. (L2, L6)
5. **Worldview granularity redesign** — fact-set-level assumptions; ground base facts
   assumption-free; the speculative-join differentiator. (R2 — the track's research core)
6. **S(-1) fact retraction** — narrowing-based; `#:after` substrate fix first; DRed
   explicitly rejected; R6 explored. (L6)
7. **The benchmark ladder** (§8) grows with each pillar; SQLite/Soufflé anchors at 10K+.

**Non-goals** (decided exclusions, §6): WCOJ purity; codegen/SIMD; DBSP group deltas;
columnar layout as an end in itself; eager index construction.

**Success criteria** (to sharpen at charter time): ground-key point lookup O(1) at 100K
rows; 2-3-way join on 100K-row relations at interactive latency (≪ the ~62 ms scan floor);
repeat-query ≈ free (persistence); ≤100-row tables regress 0%; honest position against
the Flix bar (8-13× Soufflé) reported, not aspirational.

**Demo tie-in**: IMDB subset (JOB-adjacent) and/or transportation statistics as the
flagship programs — several small `.prologos` showcases over real data.

---

## 12. Open questions

**Owner decisions pending**:
- **Q_A — Granularity**: adopt §5.5's per-relation compound cell (position-keyed
  components, per-fact refinement for retraction), explicitly overturning DEMO §D3's
  per-relation `monotone-set` — or carry both into the follow-on track's critique round?
- **Q_B — Ownership**: does the follow-on REL track take `current-relation-store`'s
  retirement from PM 12B (recommended, §10)?
- **Q_C — Filing**: this artifact lives at `docs/research/` with the charter seed inline
  (fused, per the LATTICE_VARIETY precedent) — confirm, or split the charter into the REL
  Master now?
- **Q_D — Timing of §9 truth-maintenance edits**: with the D.2 cheap-wins commit
  (recommended — they are doc-truth siblings of N5), or held for X.close's doc-truth sweep?

**Research-open**: R1-R6 (§7), owned by the follow-on track.

---

## 13. Citation table

| Source | Venue/Year | Why it matters here |
|---|---|---|
| Abadi, Madden, Hachem — *Column-Stores vs. Row-Stores* | SIGMOD 2008 | The ablation: layout ~0×; late-mat ~2.6×, compression ~2×. Prioritization signal. |
| Abadi et al. — *Materialization Strategies* | ICDE 2007 | Late materialization. |
| Abadi, Madden, Ferreira — *Integrating Compression and Execution* | SIGMOD 2006 | Operate directly on encoded data. |
| Ailamaki et al. — *PAX* | VLDB 2001 | Columnar-within-block; the chunk model. |
| Boncz, Zukowski, Nes — *MonetDB/X100* | CIDR 2005 | Vector-at-a-time; the 64-128 tuple amortization floor; main+delta. |
| Kersten et al. — *Compiled and Vectorized Queries* | VLDB 2018 | Compilation vs vectorization ±75%; small-vector degradation. |
| Neumann — *Data-centric compilation (HyPer)* | VLDB 2011 | The alternative we are not taking at small N. |
| Kohn, Leis, Neumann — *Adaptive Execution* | ICDE 2018 | **The small-N result**: <1 ms query / 54 ms compile ⇒ near-zero-setup interpreter. |
| Ngom et al. — *Filter Representation* | DaMoN 2021 | No SIMD ⇒ selection vectors, not bitmaps. |
| Qiao & Zhang — *Data Chunk Compaction* | SIGMOD 2025 | Small-N is endogenous (39% single-record chunks). |
| Afroozeh & Boncz — *FastLanes* | VLDB 2023 | SIMD-like speed from scalar 64-bit code — the open encoding route for a Racket host. |
| Boncz, Neumann, Leis — *FSST* | VLDB 2020 | String compression with equality on compressed form. |
| Moerkotte — *Small Materialized Aggregates* | VLDB 1998 | Zone maps: free at seal on immutable chunks. |
| Behm et al. — *Photon* | SIGMOD 2022 | Don't build a query compiler; row-pivot the probe structures. |
| Pedreira et al. — *Velox* | VLDB 2022 | Second production vote for interpreted vectorization. |
| Atserias, Grohe, Marx — *AGM* | FOCS 2008 | The output-size bound. |
| Ngo, Porat, Ré, Rudra — *NPRR* | PODS 2012 | First AGM-matching join. |
| Ngo, Ré, Rudra — *Skew Strikes Back (Generic Join)* | SIGMOD Rec. 2013 | The WCOJ we'd implement; skew is the signal. |
| Veldhuizen — *Leapfrog Triejoin* | ICDT 2014 | Variable-at-a-time = the SLD analogue. |
| Freitag et al. — *Umbra WCOJ* | VLDB 2020 | The cost-based hybrid; no-regression discipline; eager-index warning. |
| Mhedhbi & Salihoglu — *Graphflow* | VLDB 2019 | Hybrid optimizer beats GHD-only by up to 68×. |
| Wang, Willsey, Suciu — *Free Join / COLT* | SIGMOD 2023 | Unifies binary+WCOJ; **COLT lazy trie — the small-N enabler**; 2.94× over DuckDB on JOB. |
| Olteanu & Závodný — *Factorized Representations* | TODS 2015 | O(N^fhtw) result representations. |
| Abo Khamis, Ngo, Rudra — *FAQ* | PODS 2016 | Semiring aggregation frame; excluded operationally (variable elimination). |
| Marx; Abo Khamis et al. — *Submodular width / PANDA* | JACM 2013 / PODS 2017 | Theory frontier; not deployed engineering. |
| Yannakakis — *Acyclic schemes* | VLDB 1981 | The acyclic baseline; = semijoin/meet-narrowing (§5.2). |
| Leis et al. — *How Good Are Query Optimizers, Really?* | VLDB 2015 | Cardinality estimation dominates. |
| Zhang et al. — *Relational E-matching* | POPL 2022 | WCOJ for e-graphs; honest 0.43× worst case. |
| Zhang et al. — *Better Together (egglog)* | PLDI 2023 | Datalog + lattice merge fns; semi-naive = incremental matching. |
| Scholz et al. — *Soufflé* | CC 2016 | The Datalog scale bar (35-75 s where SQLite = 6h20m); staged compilation. |
| Subotić et al. — *Automatic Index Selection (MISP)* | VLDB 2019 | Min-chain-cover index selection; ~1× of hand-tuning at 2-5× less memory. |
| Jordan et al. — *B-tree / Brie* | PPoPP 2019 / PMAM 2019 | Soufflé's structures; CAS internals scheduler-coupled (excluded). |
| Nappa et al. — *EqRel* | PACT 2019 | Union-find-backed equivalence; explicit pairs time out. |
| Madsen & Lhoták — *Flix* | OOPSLA 2025 | **The language-integrated floor: 8-13× slower than Soufflé.** Our honest first bar. |
| Sun et al. — *GDlog/HISA* | ASPLOS 2024 | Hash-indexed sorted arrays; reference-hashing; GPU (not our substrate). |
| McSherry et al. — *Differential Dataflow / Shared Arrangements* | CIDR 2013 / VLDB 2020 | Multiversioned shared indexes; product-order versions (blocks naive adoption, §5.4). |
| Ryzhyk & Budiu — *DDlog*; Zhao et al. — *FlowLog* | 2019 / 2025 | Auto-incrementalization; its memory cost on batch. |
| Budiu et al. — *DBSP* | VLDB 2023 | IVM-as-group-algebra; **forbidden on CALM cells**; the negative-weight fragment → R6. |
| Gupta, Mumick, Subrahmanian — *Counting*; DRed | SIGMOD 1993 | Classical IVM deletion; DRed rejected as primary (over-deletion). |
| Green, Karvounarakis, Tannen — *Provenance Semirings* | PODS 2007 | K-relations; ATMS = PosBool why-provenance (§5.6). |
| de Kleer — *An Assumption-based TMS* | AIJ 1986 | The ATMS itself. |
| Apt — *The Essence of Constraint Propagation* | TCS 1999 | **The join/meet formalization** (§5.2): chaotic iteration of monotone narrowing operators. |
| Forgy — *Rete*; Miranker — *TREAT*; Nayak et al. | 1982-1990 | Production-rule join memories; the four-conditions materialization checklist. |
| Sekar et al.; Schulz — term indexing; *fingerprint indexing* | ATP literature | Retrieval-by-unification indexes; the non-ground-key invariant. |
| Santos Costa et al. — *Demand-Driven Indexing (YAP JITI)* | ICLP 2007 | Lazy multi-argument indexing = topology-stratum shaped. |
| Demeulenaere et al. — *Compact-Table* | CP 2016 | Table-constraint filtering; no bitsets ≤64 rows. |
| Steindorfer & Vinju — *CHAMP* | OOPSLA 2015 | HAMT iteration/equality warning; leaf-batching open question. |
| Bolívar Puente — *immer (RRB)* | ICFP 2017 | Persistent unboxed-leaf vectors targeting Racket-class hosts. |
| Kuper & Newton — *LVars*; Hellerstein — *CALM*; Conway et al. — *Bloom^L* | 2013-2014 | The monotone-coordination-free frame our substrate instantiates. |
| Kifer & Subrahmanian; Ginsberg; Fitting — bilattices / annotated LP | 1988-1992 | Considered and rejected for §5.2 (wrong carrier). |

*Explicitly UNVERIFIED in the sweep: ICDE-2007 selectivity thresholds; Data Blocks PSMA
figures; BitWeaving per-experiment numbers; immer microbenchmarks; VLog/Nemo comparisons;
BYODS speedups; and — most consequentially — any measurement of vectorized execution over
32-wide persistent-trie leaves (nobody has published one).*
