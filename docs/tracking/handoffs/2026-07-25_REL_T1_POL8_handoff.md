# Handoff — Rel Track 1: the POL syntax cluster (POL.8 → POL.9 impl) → X.close

**Date**: 2026-07-25 · **For**: a fresh session picking up the **last of the POL
roster** and closing Rel Track 1. Per `HANDOFF_PROTOCOL.org`.
**ON-DISK IS AUTHORITATIVE.**

> **Hot-load protocol** (§ Hot-Load Reading Protocol): read this handoff §1–§6
> FIRST, then the Always-Load set, then EVERY session-specific doc **in full** —
> then **summarize your understanding back to the owner and let them validate it
> BEFORE starting work.** "I have full context" requires being able to articulate
> every decision in §3 and every surprise in §4.

---

## §1 — Current Work State (PRECISE)

- **Series / Track**: Rel Series → **Track 1, Relational Language Usability**.
- **HEAD**: `e257c311` (docs) atop `f55988cc` (POL.7 code) · **Suite** GREEN
  **470 files / 9054 tests / 0 failures** · Branch `main`, ahead of origin —
  **don't push unless directed**.
- **Working tree**: pre-existing **OWNER WIP only** (modified `docs/standups/*.org`
  + `examples/*.prologos`, deleted `MASTER_ROADMAP.md` / `LANGUAGE_VISION.md`,
  untracked `LATTICE_*` / `LAVAMOAT_*` / `pldi-*` / `qauntale_outputs/` /
  `research/quantale research/`). **LEAVE ALONE. Stage ONLY your own files.
  NO Co-Authored-By** (`CLAUDE.local.md`).
  ⚠ **Two pre-existing owner `git stash` entries — NEVER `git stash` here** (§6).
- **Design doc**: `docs/tracking/2026-07-19_REL_T1_RELATIONAL_USABILITY_DESIGN.md`
  (§2 Progress Tracker · §6 Aspect B incl. §6.10 B3 · §7 Aspect C ·
  **§8 = the POL roster — your work list, incl. the SETTLED POL.9 design**).
- **Series Master**: `docs/tracking/2026-07-19_REL_MASTER.md`.
- **Acceptance file**: `racket/prologos/examples/2026-07-19-rel-t1-acceptance.prologos`
  — **runs 0 errors**. Run it after every phase.

### Aspect / phase status

| Unit | Status |
|---|---|
| **A** NAF/guard correctness | ✅ COMPLETE (A.1 · A.2-core · A.2b · A.3 · A.4 · SC) |
| **B** typed solution rows | ✅ COMPLETE (B0 `949d3be7` · B1 `be20e7e0` · B2 `68291d62`) |
| **C** typed logic vars + schema validation | ✅ CLOSED at C.a+C.b+C.c; C.d → **UCS Track 6** |
| **D** fact-rep research + cheap wins | ✅ artifact `0b428424` + D.2 a–d |
| **B3** rule-relation codata rows | ✅ **COMPLETE** (B3.0 `67d96a0d` · B3.1 `0d34fa7e` · **B3.2 `df428f7e`**) |
| **SUB** substitution-containment spin-out | ✅ **BVAR half CLOSED** (R(D) · `f19d6f56` · `6323587e` · `7ea49168` · `036b59f7` · `8ec5e507` · SUB.close `32f0d250`). **META half OPEN** (§5) |
| **POL.1** answer-set dedup | ✅ RULED doc-only (bag semantics stays) — the doc line lands at X.close |
| **POL.2/.3/.4/.5/.6/.7/.10** | ✅ `67d96a0d` · `b0e3da9c` · `5307be93` · `485f4e7d` · `0f6dc98c` · `f55988cc` · `095d8bc5` |
| **POL.8** implicit rule-clause groups | ⬜ **← THIS SESSION** |
| **POL.9** implicit `solve` | 🔄 **design SETTLED (§8, Q_A–Q_E ruled 2026-07-25); implementation ⬜** |
| **X.close** (bench · DEFERRED triage · doc-truth · memory fold · **Stage-5 PIR**) | ⬜ gates the track ✅ |

### NEXT IMMEDIATE TASK

**POL.8** — implicit rule-clause groups in `defr`: drop the delimiting parens
around rule-clause goals, layout-based like the functional language.
`&> fruit-color fruit "blue"` ≡ `&> (fruit-color fruit "blue")`; continuation
lines indent past the `&>`; nesting by deeper indent (`not` ⤷ `= color
not-color`). Both spellings stay legal (additive). Owner source: standup
`2026-07-19.org` § "Polish points for REL" → "Implicit rule-clause groups".
⚠ Carries the full **three-level WS validation + WS-Impact** obligations
(workflow.md): tree-parser layout rules, and it **interacts with POL.9's settled
grammar** (§3 D-POL9).

Then **POL.9 implementation**, then **X.close**.

---

## §2 — Documents to Hot-Load (ORDERED)

**Always-Load**: `CLAUDE.md` + `CLAUDE.local.md`; `MEMORY.md` +
[[rel-t1-relational-usability]] + [[demo-dependency-resolver-track]];
`DESIGN_METHODOLOGY.org` (**Stage 4 Per-Phase Protocol + the 5-step completion
gate**); `DESIGN_PRINCIPLES.org`; `CRITIQUE_METHODOLOGY.org`;
`HANDOFF_PROTOCOL.org`; `MASTER_ROADMAP.org`; series master
`2026-07-19_REL_MASTER.md`. Rules auto-load — internalize `workflow.md`,
`testing.md` (**the diagnostic protocol**), `pipeline.md` (**incl. the NEW
§ "Exhaustive Walkers"**), `prologos-syntax.md` (**load-bearing for POL.8/POL.9 —
the `[]`/`()` delimiter conventions ARE the POL.9 design**).

**Session-specific — READ IN FULL, IN THIS ORDER:**

1. **This handoff** (§1–§6).
2. **The design doc** `2026-07-19_REL_T1_RELATIONAL_USABILITY_DESIGN.md` —
   §2 tracker, **§8 POL roster in full** (your work list; POL.8 is the next
   bullet, POL.9 carries the settled paren-goal design + Q_A–Q_E rulings +
   named costs), §6.10 (B3, for context on the typed rows POL.9 will surface).
3. **BOTH dailies, in order** — the owner asked for the fuller arc:
   - `docs/tracking/standups/2026-07-19_dailies.md` (472 L, **read-only
     history**) — the Rel T1 **aspect arc**: A (NAF/guard, incl. the 3-bug
     grounding + the E-with-B convergence), B (typed rows), C (typed logic
     vars), D (fact-rep research + cheap wins), B3.0/B3.1, POL.2/.4/.5/.10.
     Its LOG carries the *reasoning* behind every settled decision this track
     rests on, and the Watching list that later graduated to rules.
   - `docs/tracking/standups/2026-07-24_dailies.md` (current, **STATE head =
     your re-grounding surface**) — the SUB spin-out (the live-bug arc + the
     compile-limit adoption + the retraction), POL.6, B3.2, POL.3, POL.9
     co-design, POL.7.
4. **The owner's polish source** — `docs/standups/standup-2026-07-19.org`
   § "Polish points for REL" (⚠ **standups are WRITE-ONCE / READ-ONLY**) —
   POL.8's and POL.9's verbatim asks, with the owner's own examples.
   Also `docs/standups/standup-2026-07-24.org` (the current interval's opener).
5. `docs/tracking/2026-07-24_SUBSTITUTION_CONTAINMENT_DEFECT.md` — the spin-out
   record. **§2.0** (post-fix reading of the traversal table + the OPEN meta
   half) and **§4.2/§4.3** (the compile-limit measurements + the retraction)
   are the parts that still bind future work.
6. `docs/tracking/2026-07-20_BSP_LE_TRACK3_ONNET_SEED.md` (143 L) — retirement
   owner for the A.2b/A.4 DFS-routing scaffolds; needed to keep saying honestly
   what is deferred where.
7. `docs/tracking/2026-07-21_UCS_TYPES_AS_PREDICATES_NOTE.md` (185 L) — where
   C.d went.
8. `docs/research/2026-07-23_FACT_REPRESENTATION_QUERY_OPTIMIZATION.md` — §11
   (the **Rel T2 "Fact Store" charter seed**), §12 (Q_A–Q_D parked), §14 (D.2
   addendum). Read at least those three when X.close's DEFERRED triage runs.
9. `docs/tracking/2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md` — CIU T6 Path
   Selection, the owner's likely next track; it **owns** the `[head rows].field`
   gap (line ~124).

---

## §3 — Key Design Decisions (do NOT revisit without cause)

**POL.9 — the paren-goal design (SETTLED 2026-07-25, owner + Claude prose round; design §8)**

- **D-POL9 — THE RULE**: *goal-ness comes from context (`defr`/`solve`/`rel`
  bodies) or from parens (everywhere else)*. A paren group in command position
  is a GOAL carrying an implicit `solve`: `(fruit-not-of-color f "red")` ≡
  `solve (…)`. `foo x` / `[foo x]` stays function application. This **completes
  the existing delimiter reservation** (`prologos-syntax.md`: `()` = "special
  form, not application" + relational goals) rather than adding a new rule.
- **Why paren beat the seed's registry-lookup idea (load-bearing)**:
  free-ordering REQUIRES syntactic **category**-decidability. Under
  registry-lookup, `foo a b`'s category (application vs query) pends on name
  resolution — un-typeable, un-composable, retroactively re-categorized. Under
  parens the category is static and only the BINDING residuates — the pattern
  the driver's demand loop already implements (`residuation-demand-name` +
  sweep-retry, PPN 4C 4B.5.a).
- **Q_A** paren-goals ADOPTED. **Q_B** defn/defr namespaces **DISJOINT at
  registration** (second registration of a name held by the other kind = error
  pointing at the first; kills the silent-wrong-reading hazard, keeps a future
  Curry-style functions-are-relations unification clean). **Q_C** scope =
  **top-level commands + `def` RHS**, explicitly NOT general expression position
  (paren-goals inside `defn` bodies would make calls re-query the ambient fact
  store from inside functions — the purity/store-dependence question, its own
  future round). **Q_D** forward refs: slice 1 = "Unknown relation" via the
  POL.4 `exn:prologos-solve` presentation; slice 2 (fast-follow) = wire goals
  into the EXISTING demand-residuation loop (free-ordering behavior, no new
  propagator substrate). **Q_E** conjunction-by-juxtaposition PARKED for the
  POL.8 grammar round.
- **Named costs, accepted eyes-open**: (1) `(f x)` = application in sexp IR but
  a goal in WS — an **institutionalized WS-vs-sexp divergence** on the most
  iconic Lisp form (exposure is *us*, writing sexp fixtures); (2) one character
  of semantic weight (the echo self-corrects: rows-with-types vs a value).
- **Impl Phase 0**: empirical census of what top-level `(foo x)` does in WS
  today (expected: error ⇒ additive).

**POL.1 — bag/multiset semantics STAYS (owner ruling)**: row multiplicity is the
derivation count (the ATMS=provenance reading; Prolog `findall` parity).
Deliverable shrank to a **doc clarification at X.close**; an opt-in `distinct`
(the `setof` analogue) is **Rel T2**, where it meets the DFS first-hit
short-circuit question dedup would make observable.

**SUB ruling (D)** — `expr-champ` is a **CLOSED runtime map value**. The fix
(SUB.3a) makes the invariant true BY CONSTRUCTION via NbE open-the-binder rather
than policing it: `nf` opens binders with deterministic `#%nbe` fvars, so
container mints can only capture fvars, on which `shift`/`subst` are already
identity. The SUB.1 tripwire stays installed as the standing assertion.

**B3.2 — display-time refinement is DISPLAY-ONLY** (design §6.10 D-B3.1(ii)):
refines the ECHOED type from actual rows (SHARPEN a union to observed branches;
FILL a hole); the STORED type stays static and governs composition. Applied at
the **eval echo seam only** — a `def` announces the type it stores. The
**CLOSED-tail gate** is what scopes it to solution rows (D-B3.6).

**Compile limit ADOPTED** (`6323587e`): the runners `putenv`
`PLT_CS_COMPILE_LIMIT=1000000`; manual `raco make` should set it in the shell.

---

## §4 — Surprises and Non-Obvious Findings (HIGHEST RE-DERIVATION RISK)

1. **⭐ A green full suite is NOT a correctness gate for walker bugs.** The suite
   was green 470/0 with a LIVE silent-wrong-answer bug for months. Only
   failing-test-first found it. This is now `pipeline.md` § "Exhaustive Walkers"
   (7+ silent in-tree instances tabulated) — **read that section**; it is the
   pattern the whole SUB arc kept re-deriving, with the 3-step structural answer
   (generic transparent-struct rebuild as fallback → binder inventory from
   `shift` → differential oracle when arms are needed for perf).
2. **⚠ The suite wall-clock could not resolve a ~5 s change** on a machine that
   had been running suites for hours: identical code varied **5.6–8.5 s**
   run-to-run and the evening drifted **173 → 185 → 204 s**. A perf claim
   ("hot scan saves ~8-11 s") was RETRACTED on this basis (defect doc §4.3).
   **Interleaved same-process micro is the instrument**; the SUB.3a "+6.4 %"
   figure inherits the caveat and X.close must re-measure **from a cold machine**.
3. **`touch FILE && raco make` does NOT recompile** (SHA short-circuit) — it
   produced a false negative that nearly killed the compile-limit win. Delete
   the `.zo`/`.dep` for a true A/B leg. (Codified in `testing.md`.)
4. **Instrument the parse; never infer reader shape.** POL.6's root was found by
   a temporary `eprintf` on the real `process-file` path: WS delivers
   `defn f [x:Int]` as the TWO elements `x` + `:Int`, so the defn silently became
   **2-ary with a parameter named `:Int`** — the "cannot infer" message was the
   downstream symptom of a silently wrong arity. Same technique found POL.7's
   `$pipe`-as-garbage-term.
5. **POL.7 refuted a standing Watching entry**: "one-line facts mis-parse as a
   single wrong-arity row" was **stale for exact multiples** (arity-chunking
   already existed). The real trap was the **partial remainder's silent dead
   row**. Check the premise before building on a Watching item.
6. **The runner's "DEAD WORKERS — no results after 30 s" banner is a false alarm
   for a lone >30 s test file.** Pair it with any second file (or `require` it
   directly) before diagnosing a phantom crash.
7. **Test-infra**: `cb1-run-ws` (and siblings) return raw **error structs** for
   failing programs — use the existing `cc-result-strings` converter before
   `regexp-match?`, or the check errors with a contract violation.
8. **A live static/runtime DISAGREEMENT exists** (surfaced by B3.2, deferred):
   unifying a relational var with a **collection literal** yields the runtime
   value `unknown` while the static type derives correctly —
   `'[{:m unknown, :x 1}] : [List {:m {:a Int} :x Int}]`. DEFERRED.md entry with
   the probe; it also blocks B3.2's FILL path from having a reachable surface case.
9. **Effects cannot reach a `def` body** (capability-gated, params-only ⇒ always
   under a binder). The capability system IS the purity gate.
10. **The global env is a PROPAGATOR NETWORK** (each def name owns a cell;
    `def-entry` (type,value); LWW merge) — not a hash.
11. **Subagent/probe "VERIFIED" claims need spot-checking** — an audit once
    asserted a `def r := [random …]` probe result; **`random` doesn't exist in
    Prologos** and it reached the owner before being caught.
12. **Probe-authoring trap**: naming a probe relation `pair` collides with the
    `pair` builtin and echoes unevaluated. Avoid builtin names in probes.

---

## §5 — Open Questions and Deferred Work

**Named + owned (do not re-litigate; do not silently absorb)**

- **SUB META half** — `zonk` ×3 + `occurs?` skip on **metas**, which the NbE fix
  says nothing about. Post-fix reachability **UNVERIFIED** (one surface probe
  came back clean, which only rules out that route). `occurs?` is the
  higher-stakes one (unsound occur-check ⇒ cyclic solutions). DEFERRED.md has
  the entry + probe recipe. Own slice.
- **Collection-literal unify → runtime `unknown`** (§4.8). DEFERRED.md.
- **A.2b/A.4 DFS-routing scaffolds + Aspect-B on-network row computation** →
  **BSP-LE Track 3** (seed doc).
- **C.d runtime `?x:Int`** → **UCS Track 6** (note doc).
- **`[head rows].field` "Could not infer type"** → owned by **CIU T6 Path
  Selection** as its broadcast-selection prerequisite. Cross-reference; don't fix.
- **Rel T2 "The Fact Store"** — artifact §11 charter seed; Q_A–Q_D (§12), R2
  worldview granularity, `distinct`, recipe-style `def` liveness, the
  `tabled?` 48-site sweep, SCC-ordered B3.1 derivation.
- **Un-arm'd node → spurious "Multiplicity violation"** — **3rd data point**
  (F1a.2, POL.5, and `def := [validate …]` which is STILL LIVE). Promotion due
  at X.close; the third instance is also an open POL-adjacent defect.
- **POL.9 Q_E** conjunction-by-juxtaposition — parked for the POL.8 round.

**Watching (in the dailies STATE head)** — suite count nondeterminism; the
walker disease (now promoted); the bench trio (now promoted); premise-refutation
cascade at **11** (+ "a green suite gates correctness", + the two POL.7
refutations); "reduction DEPTH is the axis" (2 of 3).

---

## §6 — Process Notes

- **Per-phase discipline is a BLOCKING 5-step checklist** (`workflow.md`): tests
  → commit → tracker update → dailies → *then* next phase. Every phase this arc
  followed it.
- **Tests are PER-PHASE.** `tests/test-rel-t1-pol.rkt` (POL gates),
  `tests/test-rel-t1-typed-rows.rkt` (B-arc), `tests/test-rel-t1-typed-vars.rkt`
  (C-arc + POL.6) **grow** per phase.
- **⚠ NEVER `git stash` in this repo** — two pre-existing owner stashes + owner
  WIP. A/B by direct edit + revert.
- **Full suite is a regression GATE, not a diagnostic.** On "N FAILURES": read
  `data/benchmarks/failures/*.log`, run individual tests, fix, then gate once.
- **Deterministic counters over wall time**; interleaved same-process micro for
  A/B (§4.2). **Never compile while a timing suite is in flight** (it
  contaminated a run this arc).
- **Commit messages**: no Co-Authored-By. Write long messages **via a file**
  (`git commit -F`) — inline `-m` with backticks gets **command-substituted**
  (it ate a word this arc and required an amend).
- **Owner co-designs in PROSE** with Q_N labels — **not** AskUserQuestion chips
  ([[design-dialogue-preference]]). The POL.9 round is the model: options,
  recommendation, named costs, explicit rulings requested.
- **Standups (`docs/standups/`) are WRITE-ONCE / READ-ONLY.**
- **Dailies**: STATE head (overwrite, always current) + append-only LOG; roll at
  ~400–500 lines or a topic shift (`DAILIES_METHODOLOGY.org`).
- **Coordinates DRIFT.** Every file:line here was true at `e257c311`; re-grep.
- **A tracked design is not DONE until its PIR lands.** Rel T1 flips ✅ only at
  **X.close** (bench matrix from a COLD machine · DEFERRED triage · doc-truth
  sweep · memory fold · Stage-5 PIR, 16-question checklist-first).
  Doc-truth items already queued: the POL.1 bag-semantics line; sync
  `MASTER_ROADMAP.org`'s UCS table (missing Track 5, now +Track 6); correct the
  vision doc's "sub-ms vs 30 ms SQLite" claim + its "first-argument indexing"
  advantage (artifact §9 lists all six).
