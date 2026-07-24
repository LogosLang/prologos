# Handoff — Rel Track 1: the DEMO→Aspect-D→POL arc, resuming the POL roster

**Date**: 2026-07-24 · **For**: a fresh session picking up the **remainder of Rel
Track 1** (POL roster + B3.2, then X.close). Per `HANDOFF_PROTOCOL.org`.
**ON-DISK IS AUTHORITATIVE.**

> **Hot-load protocol** (`HANDOFF_PROTOCOL.org` § Hot-Load Reading Protocol): read
> this handoff §1–§6 FIRST, then the Always-Load set, then EVERY session-specific
> doc **in full** — then **summarize your understanding back to the owner and let
> them validate it BEFORE starting work.** "I have full context" requires being able
> to articulate every decision in §3 and every surprise in §4.

---

## §1 — Current Work State (PRECISE)

- **Series / Track**: Rel Series → **Track 1, Relational Language Usability**.
- **HEAD**: `a63a0ac8` (docs) atop `095d8bc5` (POL.10 code) · **Suite** GREEN
  **470 files / 8991 tests / 0 failures** (run on fully-regenerated `.pnet` caches
  after the PNET_VERSION 2→3 bump) · Branch `main`, ahead of origin — **don't push
  unless directed**.
- **Working tree**: pre-existing **OWNER WIP only** (modified `docs/standups/*.org`
  + `examples/*.prologos`, deleted `MASTER_ROADMAP.md` / `LANGUAGE_VISION.md`,
  untracked `LATTICE_*` / `LAVAMOAT_*` / `pldi-*` / `qauntale_outputs/` /
  `research/quantale research/`). **LEAVE ALONE. Stage ONLY your own files.
  NO Co-Authored-By** (`CLAUDE.local.md`).
  ⚠ There are also **two pre-existing owner `git stash` entries** — see §6.
- **Design doc**: `docs/tracking/2026-07-19_REL_T1_RELATIONAL_USABILITY_DESIGN.md`
  (§2 Progress Tracker · §6 Aspect B incl. **§6.10 = the B3 design** · §7 Aspect C ·
  **§8 = the POL roster POL.1–POL.10**).
- **Series Master**: `docs/tracking/2026-07-19_REL_MASTER.md`.
- **Acceptance file**: `racket/prologos/examples/2026-07-19-rel-t1-acceptance.prologos`
  — **runs 0 errors**, targets through `;;28`. Run it after every phase.

### Aspect / phase status

| Unit | Status |
|---|---|
| **A** NAF/guard correctness | ✅ COMPLETE (A.1 · A.2-core · A.2b · A.3 · A.4 · SC) |
| **B** typed solution rows | ✅ COMPLETE (B0 `949d3be7` · B1 `be20e7e0` · B2 `68291d62`) |
| **C** typed logic vars + schema validation | ✅ CLOSED at C.a+C.b+C.c; C.d → **UCS Track 6** |
| **D.0/1** fact-rep + query-opt research | ✅ artifact `0b428424` (+ §14 addendum) |
| **D.2** cheap-wins slice | ✅ `296ac2d5` · `984601b9` · `7ba24b2b` · `feedc6ff` |
| **B3** rule-relation codata rows | 🔄 **B3.0 ✅ `67d96a0d` · B3.1 ✅ `0d34fa7e` · B3.2 ⬜** |
| **POL.2** anon keys | ✅ (landed as B3.0) |
| **POL.4** arity hard-error | ✅ `5307be93` |
| **POL.5** `def := solve` multiplicity | ✅ `485f4e7d` |
| **POL.10** `def` binds reduced value | ✅ `095d8bc5` |
| **POL.1 · POL.3 · POL.6 · POL.7 · POL.8 · POL.9** | ⬜ **← THIS SESSION** |
| **X.close** (bench matrix · DEFERRED triage · doc-truth · memory fold · **Stage-5 PIR**) | ⬜ gates the track ✅ |

### NEXT IMMEDIATE TASK

Owner sequences, but the standing recommendation from the last session is
**POL.6** (diagnosis-led: fused `x:Int` in `defn` params — the C.b.2 last mile),
then **B3.2**, then the **POL.1+POL.3** pair (they share the row-assembly seam),
then the syntax cluster **POL.7 → POL.8**. **POL.9 needs owner co-design first**
(grammar ambiguity — see §5).

---

## §2 — Documents to Hot-Load (ORDERED)

**Always-Load**: `CLAUDE.md` + `CLAUDE.local.md`; `MEMORY.md` +
[[rel-t1-relational-usability]] + [[demo-dependency-resolver-track]];
`DESIGN_METHODOLOGY.org` (**Stage 4 Per-Phase Protocol + the 5-step completion
gate**); `DESIGN_PRINCIPLES.org`; `CRITIQUE_METHODOLOGY.org`;
`HANDOFF_PROTOCOL.org`; `MASTER_ROADMAP.org`; series master
`2026-07-19_REL_MASTER.md`. Rules auto-load — internalize `workflow.md` (per-phase
gate, commit discipline), `testing.md` (**the diagnostic protocol — never re-run
the full suite to diagnose**), `pipeline.md`, `prologos-syntax.md`.

**Session-specific — READ IN FULL, IN THIS ORDER:**

1. **This handoff** (§1–§6).
2. **The design doc** `2026-07-19_REL_T1_RELATIONAL_USABILITY_DESIGN.md` —
   §2 tracker, **§8 POL roster in full** (that is your work list), §6.10 (B3
   design, for B3.2), §7 (Aspect C context for POL.6).
3. **Latest dailies** `docs/tracking/standups/2026-07-19_dailies.md` — STATE head
   + the LOG entries for D.2 / B3 / POL.4 / POL.5 / POL.10. The **Watching**
   subsection carries live pattern counts (premise-refutation cascade at 9).
4. **The owner's polish source** — `docs/standups/standup-2026-07-19.org`
   § "Polish points for REL". ⚠ **Standups are WRITE-ONCE / READ-ONLY.**
   This is where POL.1–POL.9 came from; the roster in §8 is its distillation.
5. **The Aspect D artifact** `docs/research/2026-07-23_FACT_REPRESENTATION_QUERY_OPTIMIZATION.md`
   (892 L) — §11 = the **Rel T2 "The Fact Store" charter seed**, §12 = Q_A–Q_D
   **parked for that charter**, §14 = the D.2 addendum with the measured findings.
   Read §1 (frame), §11, §12, §14 at minimum; the rest when Rel T2 opens.
6. `docs/tracking/2026-07-20_BSP_LE_TRACK3_ONNET_SEED.md` (143 L) — the retirement
   owner for the A.2b/A.4 DFS-routing scaffolds and Aspect-B on-network row
   computation. Needed to keep saying honestly what is deferred where.
7. `docs/tracking/2026-07-21_UCS_TYPES_AS_PREDICATES_NOTE.md` (185 L) — where C.d
   went; POL.6 must not collide with it (POL.6 is the **static functional-binder**
   path, NOT the runtime types-as-predicates reading).
8. `docs/tracking/2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md` (214 L) — CIU T6
   Path Selection, the owner's next track after Rel T1; **it owns the
   `[head rows].field` polymorphic-inference gap** that B3.1 surfaced (see §5).
9. `docs/tracking/2026-06-28_DEPENDENCY_RESOLVER_DEMO_DESIGN.md` (257 L) — the DEMO
   through-line this whole arc serves; §11 is the old "RPF" bullet list now
   subsumed by the Rel T2 charter seed.

---

## §3 — The Arc (how we got here) + Key Design Decisions

### The through-line

**DEMO (dependency-resolver) is the driver.** Everything in this arc exists to make
a multi-paradigm real-data demo possible:

```
DEMO design (2026-06-28)  →  Num T1 ✅ (numerics tower; unblocked DEMO P1)
   →  CIU T6 F1 ✅ (records / anonymous Map / row typing + schema SEAL + validate; PIR 2026-07-19)
   →  Rel T1 (relational surface usability) ← WE ARE HERE
        A ✅ NAF/guard correctness   B ✅ typed solution rows
        C ✅ typed logic vars/schema validation
        D ✅ fact-rep + query-opt research (+ cheap wins)  → seeds Rel T2
        B3 🔄 rule-relation rows     POL 🔄 the polish roster
   →  X.close (PIR) → then owner's call: Rel T2 (Fact Store) or CIU T6 Path Selection
```

The **reason** Rel T1 matters to DEMO: a demo that queries real data needs
(a) correct NAF/guards, (b) solution rows that *compose with the type system*
(you must be able to bind a query result and project its fields), and (c) a
surface that doesn't trip the author. A, B, B3 and POL are exactly those three.

### Decisions made THIS session (do NOT revisit without cause)

**Aspect D (research, D.0/1 + D.2)**

- **D-1 — the frame** (owner F1–F7, artifact §1): the fact store is
  **engine-neutral and strictly propagator-based**; scale target **100K–1M rows**
  (real multi-table data, demo-driven); baselines **in-process SQLite (prepared) /
  Soufflé / HEAD**; artifact + cheap wins land in Rel T1, the **build spins out as
  a REL track** ("Rel T2 — The Fact Store", charter seed artifact §11); bulk
  import (`:source`/`:from`) is a real target co-designed **with** representation;
  formal correctness required with pragmatism biased.
- **D-2 — the store is not a lattice today** and that is the first thing Rel T2
  must fix: cell-2's merge is per-key **last-write-wins** while its comment claims
  "hash-union CALM-safe", and the entire relational subsystem is **outside SRE**
  (zero registrations). The on-network story is false at the relational root until
  a lawful join replaces it.
- **D-3 — join/meet is a Galois pair, not a bilattice** (Apt 1999 chaotic
  iteration; accumulation ascends, query viability narrows; semijoin/Yannakakis is
  the same shape). The meet side is *structurally inert* at HEAD.
- **D-4 — the three vision equations, adjudicated**: tabling = materialized views
  **REFUTED at HEAD** (tables die with the query); propagators = IVM **true for the
  monotone half only** (worklist = delta = semi-naive; deletion needs an unbuilt
  S(-1) fact stratum; DBSP group-deltas are *forbidden* on CALM cells); ATMS =
  provenance is **the most literal** (PosBool why-provenance —
  Green–Karvounarakis–Tannen 2007, which the vision doc mis-cites).
- **D-5 — Q_A–Q_D PARKED** to the Rel T2 charter round (granularity overturn of
  DEMO §D3, `current-relation-store` ownership vs PM 12B, filing, truth-maintenance
  timing). Do not re-open them inside Rel T1.

**B3 — rule-relation codata rows** (design §6.10)

- **D-B3.1 — HYBRID with a PHASE-FORCED division**: static body-goal dataflow is
  *the composition channel*; at-the-end observation is *display refinement only*
  (**B3.2**, unbuilt). This is forced, not chosen: the checker runs before
  reduction, and `expr-champ` infers to `expr-error` by the F1b retired-loud
  posture, so runtime observation **cannot** feed static composition.
- **D-B3.2 — recursion = type-level fixpoint** (Kleene iteration over the rule
  cone from ⊥, union-join to stability, capped). Transitive closure types
  correctly; bail-to-hole would have left reachability/ancestry — the demo's core
  queries — untyped.
- **D-B3.3 — anonymous `rel` IN scope**, same walker (owner: "observational
  results really should share common mechanisms").
- **D-B3.6 — rows are always CLOSED with Κ′ keys**; underivable field *types*
  degrade to hole, never lie; MIXED facts+clauses relations **join the fact
  contribution** (the old relation-global gate discarded it).
- **D-B3.5 — `?x:Int` type-preds EXCLUDED** until UCS enforcement exists (owner:
  claiming static meaning without enforcement "would be dishonest and confusing").

**POL rulings**

- **POL.4 — arity mismatch is a HARD ERROR** with the SWI-style diagnostic
  (owner Q_1). Not the A.3 warn form: a wrong-arity call is a program defect.
- **POL.10 — `def` binds the WHNF-reduced value; SNAPSHOT semantics** (owner F1).
  A binding denotes ONE value — generalized from the owner's own principle that a
  def bound to an effectful expression should not vary per mention. Recipe-style
  liveness was **never designed** (it was the defect's shadow); proper
  invalidation (def ← fact-store dependency propagation) is **Rel T2 IVM
  territory**, and `def`-before-`:from`-load staleness is the documented cost.
- **POL.10 — WHNF, NEVER `nf`.** See §4; this is the single most important
  technical finding of the session.
- **Application memoization is PARKED** (owner): caching `f(arg)` per argument is
  a space/time tradeoff, not a free win; **multiplicity + capability types are its
  future admission knob** (`:0` erased ⇒ not a key; `:1` linear ⇒ memoizing is
  near-category-error; `:w` ⇒ admissible; capability-bearing ⇒ never).

---

## §4 — Surprises and Non-Obvious Findings (HIGHEST RISK FOR A NEW SESSION)

1. **⭐ `whnf` vs `nf` was the ONLY axis that mattered for POL.10.** A first-pass
   eager-`nf` flip was attempted and reverted after three "value-class collisions"
   (module-load prelude corruption; capability discharge under a Pi binder;
   schema-annotated literals). A grounding audit built nf- and whnf-variant driver
   clones and ran the actual collision programs: **the nf clone fails all, the whnf
   clone passes all.** `expr-lam?` ∈ `whnf-trivial?` (reduction.rkt), so whnf of a
   lambda is bit-identical ⇒ **binder-headed stays lazy BY IDENTITY, not by
   carve-out**. The value-class taxonomy built after the first failure was a
   **misdiagnosis of reduction DEPTH as value KIND**. Lesson: *check whnf before
   inventing taxonomy* (2 data points; dailies Watching).
2. **`nf` under binders is silently WRONG here, not merely risky.** Lambda bodies
   normalize into an `expr-champ` containing `expr-bvar`, and `shift`/`subst` treat
   a champ as a **closed leaf** — so beta silently drops arguments (verified:
   `[padd a b].x` → an open term instead of `4N`). That is a latent
   substitution-layer defect the flip merely *exposed*; it is **not fixed** and is
   worth spinning out (see §5).
3. **Effects cannot reach a `def` body at all.** Every effect is capability-gated
   and capabilities arrive **only as function parameters** ⇒ every effectful
   expression lives under a binder, where whnf never looks. `def g := [println "x"]`
   is an **E2001 error today**, not a deferred effect. The capability system *is*
   the purity gate; no policy gate was needed.
4. **The global env is NOT a hash — it is a propagator network.** Each definition
   name owns a **cell** (per-file `module-network-ref`; two-field `def-entry`
   (type, value); LWW merge). "Make the binding a cell" was never a proposal — it
   has been the architecture since PPN 4C. Consequently a per-binding memo slot
   would be a *fourth writer* contending with the residuation δ on a whole-value
   LWW merge, and three of four candidate memo mechanisms are **dead**: whnf runs
   inside cell *merge functions* (`(merge-fn old new)` — no net, no continuation,
   the write is inexpressible), and parameter-sets on BSP worker threads are
   thread-local and lost.
5. **The Tier-2 (on-network) fact path is unreachable BY CONSTRUCTION for
   single-variant fact tables** (D.2.c): var-bearing queries are absorbed by Tier-1
   *inside `solve-goal-propagator` itself*, and all-ground queries are delegated to
   DFS. Measuring Tier-2 at all requires a multi-variant relation.
6. **There is NO DFS↔Tier-2 crossover ≤1000 rows.** Genuine Tier-2 enumeration is
   superlinear (0.97 ms@10 → 371 ms@1000) vs DFS 0.77 ms@1000 — **~480× slower and
   diverging**. The `:auto` threshold of **256 points the wrong way**, and Tier-1's
   shield is what accidentally protects production. Hardens **R2**
   (fact-set-level worldview granularity) as *the* gate on any competitive
   on-network fact path.
7. **The arity-lenient nil trap is real and recurring** (dailies Watching 2b): a
   wrong-arity `solve` silently returned `nil`. It bit the D.2.c corpus generator;
   POL.4 now errors on it. Generated/probe programs must derive their query arity,
   never hardcode it.
8. **Two latent counter defects** found by the struct-field checklist at D.2.b:
   `inert_dependent_skips` had been incremented-but-never-emitted/reset since
   BSP-LE Track 2, and `tools/profile-unify.rkt` constructed `perf-counters` with
   16 args against a 17-field struct. Both fixed.
9. **The B3.0 atomicity trap**: a runtime-only anon-key filter would have broken
   the correct-by-construction static/runtime key agreement (a facts-only
   `solve (data _ s)` would have typed a `:_anon` field the runtime row no longer
   carried). Both halves had to land in one commit. The CbC invariant worked as a
   design forcing-function.
10. **One relayed claim was FALSE.** The grounding audit asserted (as VERIFIED)
    that `def r := [random 1000000N]` yields three distinct values. **There is no
    `random` in Prologos** — the probe could not have run, and it was relayed to
    the owner unverified before being caught. Treat subagent "VERIFIED" labels as
    claims to spot-check, especially probe results that would be *convenient*.

---

## §5 — Open Questions and Deferred Work

**Needs owner co-design before implementation**

- **POL.9 — implicit `solve` at top level.** A bare relational clause outside
  `defr` carrying an implicit `solve` (mirroring the functional implicit `eval`).
  ⚠ **Grammar ambiguity is the open question**: a bare `foo a b` currently reads
  as function application. Plausible disambiguation is relation-registry lookup at
  elaboration, but forward references, shadowing, and error quality under a miss
  all need settling. Co-design, then a WS-Impact analysis.

**Deferred WITH a named home (do not re-litigate; do not silently absorb)**

- **B3.2** — the coinductive/display-time refinement half of B3 (design §6.10).
  In Rel T1 scope, unbuilt.
- **`[head rows].field` → "Could not infer type"** — the polymorphic-`head`-over-
  record-lists inference gap. B3.1 surfaced it for rule rows; it is **pre-existing
  for facts rows since B2** and is **already owned by CIU T6 Path Selection** as
  its broadcast-selection prerequisite. Cross-reference; do not fix here.
- **Rel T2 "The Fact Store"** — artifact §11 charter seed: lawful store lattice +
  SRE registration · bulk import co-designed with representation · indexes as
  derived cells (COLT-style laziness) · cross-query persistence · **R2 worldview
  granularity** · S(-1) fact retraction · the benchmark ladder. Q_A–Q_D (§12) are
  its opening questions. It subsumes the old RPF bullet list and DEMO P3.
- **Application memoization** (owner-parked; multiplicity/capability as the knob).
- **A.2b / A.4 DFS-routing scaffolds + Aspect-B on-network row computation** →
  **BSP-LE Track 3** (seed doc).
- **C.d / runtime `?x:Int`** → **UCS Track 6** (note doc).
- **Recipe-style `def` liveness** (a bound solve tracking later `defr`s) → Rel T2
  IVM pillar, as dependency propagation rather than version-keying.

**Unowned findings worth spinning out (my recommendation, owner's call)**

- **The substitution containment defect** (§4.2) — **NOW SPUN OUT, and it is a LIVE
  BUG, not latent**: [`2026-07-24_SUBSTITUTION_CONTAINMENT_DEFECT.md`](../2026-07-24_SUBSTITUTION_CONTAINMENT_DEFECT.md)
  + a DEFERRED.md entry. A `defn` whose lambda body is a **map literal** leaks
  `?bvar0 : Nat` to top level with **0 errors** (verified repro; control differing only
  in body shape gives the correct `6N`). ~**37 arms across 7 traversals** over six
  runtime collection values; `test-substitution.rkt` has ZERO coverage of the invariant;
  `nf` descends into `expr-rrb` but not its `expr-champ` sibling ten lines earlier.
  **Blocked on one owner ruling** (is `expr-champ` a closed runtime value or an open AST
  container?). Days-scale slice available with no ruling: failing tests + a tripwire at
  the three `nf`-persisting boundaries. Also surfaced independently:
  `PLT_CS_COMPILE_LIMIT` is unset repo-wide, so `shift`/`subst` (~337 arms) fall back to
  the CS interpreter — possibly a large free win, UNVERIFIED in-tree.
- **D.2 named follow-ups**: SCC-ordered (vs global Kleene) B3.1 derivation;
  registration-time caching of `relation-column-typer` per the D.2.d precedent;
  `relation-info-tabled?` field removal (a 48-site struct sweep);
  DFS-side index consultation (blocked on the `unify-terms`
  symbol-on-fact-side soundness question — a Rel T2 L1 audit item).
- **`.pnet` sweep**: which other `expr-*` nodes are runtime-only and therefore
  unregistered? POL.10's champ-sentinel fixed the one the flip surfaced; no
  systematic audit was done.

---

## §6 — Process Notes

- **Per-phase discipline is a BLOCKING 5-step checklist** (`workflow.md`): tests →
  commit → tracker update → dailies → *then* next phase. Every phase this session
  followed it; keep it.
- **Tests are PER-PHASE**, never a dedicated end "test phase". `tests/test-rel-t1-pol.rkt`
  (POL gates) and `tests/test-rel-t1-typed-rows.rkt` (B-arc) **grow** per phase.
- **⚠ NEVER `git stash` in this repo.** There are **two pre-existing owner stash
  entries**, and the working tree carries owner WIP. A mis-pathed `git stash push`
  during an A/B nearly popped an owner stash over owner WIP (aborted safely).
  **Do A/B by direct edit + revert**, not stash.
- **Full suite is a regression GATE, not a diagnostic** (`testing.md`). On "N
  FAILURES": read `data/benchmarks/failures/*.log`, run individual tests, fix, then
  gate once. The guard script blocks re-runs within 5 min without `.rkt` changes —
  use `--force-rerun` when you legitimately need one.
- **Deterministic counters over wall time** for any perf claim.
  `solver_row_scans` / `solver_col_compares` (added D.2.b) are the fact-path
  instruments; `bench-fact-scale.rkt` + `gen-fact-corpus.rkt` are the scale rig.
- **Probe discipline**: multi-line `||` fact blocks (one-line multi-row literals
  mis-parse as a single wrong-arity row); derive query arity, never hardcode;
  probe files go in the **scratchpad**, never the repo.
- **Commit messages**: no Co-Authored-By. Write long messages **via a file**
  (`git commit -F`) — inline heredocs with backticks get eaten by shell
  substitution (happened once; required an amend).
- **Owner co-designs in PROSE** with Q_N labels — **not** AskUserQuestion chips
  ([[design-dialogue-preference]]).
- **Grounding-audit workflow is the default sub-phase opener** for
  grounding-heavy work — but note the reusable template
  (`.claude/workflows/grounding-audit.js`) has a **facet-arg passing defect**
  (3 of 4 facets received `undefined` in the B3 run and self-scoped). Either fix it
  or write a purpose-built inline workflow (the POL.10 run did the latter and got
  much better facet coverage).
- **Standups (`docs/standups/`) are WRITE-ONCE / READ-ONLY.** Read for context;
  never modify.
- **Coordinates DRIFT.** Every file:line in this handoff was true at `a63a0ac8`;
  re-grep before trusting.
- **A tracked design is not DONE until its PIR lands.** Rel T1 flips ✅ only at
  **X.close** (bench matrix · DEFERRED triage · doc-truth sweep · memory fold ·
  Stage-5 PIR). Doc-truth items already queued for it: sync `MASTER_ROADMAP.org`'s
  UCS table (missing Track 5, now +Track 6); correct the vision doc's
  "sub-ms vs 30 ms SQLite" claim and its "first-argument indexing" advantage
  (artifact §9 lists all six).
