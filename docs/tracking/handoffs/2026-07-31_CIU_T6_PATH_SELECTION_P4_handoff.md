# Handoff — CIU Track 6 Path Selection: the P4 co-design is COMPLETE (Q_U5–Q_U8); implementation opens at the PAUSE, then D4.P4a

**Date**: 2026-07-31 · **For**: a fresh session implementing **D4.P4**
(broadcast ω on the unified selector carrier). Per `HANDOFF_PROTOCOL.org`.
**ON-DISK IS AUTHORITATIVE.**

> **Hot-load protocol**: read this handoff §1–§6 FIRST, then §2a Always-Load,
> then EVERY §2c doc **in full** — then **summarize your understanding back to
> the owner and let them validate it BEFORE starting work.**

> ⚠ The live surface law: **dot DESCENDS · brace SELECTS `x{…}` · `:`
> BROADCASTS · `^` RE-KEYS · `*` FLATTENS · `<` DISCLOSES.** Anything phrased
> "dot extracts · bracket selects · `:` iterates · `*` splats", or PS1–PS15,
> is the SUPERSEDED surface. The spec is a GUIDE; where it and D4 differ,
> **D4's recorded adaptation wins.**

---

## §1 — Current Work State (PRECISE)

- **Series / Track / Phase**: CIU → Track 6 Path Selection → **D4.P4**
  (broadcast ω), co-design COMPLETE, implementation NOT started. The
  session opens on **the PAUSE** (three owner items, §5), then **P4a**.
- **HEAD at handoff write**: `f1537a7b` — ⚠ **re-derive with `git rev-parse
  HEAD`**; coordinates in prose go stale (three stale handoff coordinates in
  the P3 arc; HEAD moved MID-CO-DESIGN this arc when the owner's LET track
  merged).
- Local `main`, **MAIN CHECKOUT**. ⚠ If the session launches in a worktree,
  REMOVE it (owner ruling; it happened twice in the P3 arc — verify 0 unique
  commits + clean tree first).
- **Suite** GREEN **9599 / 476 / 0** — the LET merge's own gate @ `5e16ead4`
  (LET added a test file); docs-only commits since (verify
  `git diff --name-only 5e16ead4..HEAD -- '*.rkt'` → empty). Acceptance
  path-selection **52/52** (`examples/2026-07-26-ciu-t6-path-selection.prologos`,
  gated by `tests/test-path-selection-acceptance.rkt`) + records **89/89**.
  Track battery **204** test-cases (`tests/test-path-selection.rkt`) — ⚠ the P3c close notes / commit message and the 2026-07-28 dailies say **206**; that was arithmetic, not a measurement. 204 is the runner's and `timings.jsonl`'s figure at `5e16ead4`.
- **origin/main is at the merge `5e16ead4`** (owner-pushed), so the unpushed
  set is the P4 co-design docs run: `cae212c8` Q_U5/Q_U6 · `5b67046a` Q_U7 ·
  `a090b46a` Q_U8+partition · `f1537a7b` dailies · `7d800476` session-close
  dailies · **plus this handoff's own commit** — re-derive with
  `git rev-list --count origin/main..HEAD`. **Do NOT push unless directed.**
- **Working tree**: pre-existing **owner WIP only (41 entries) — LEAVE
  ALONE.** Stage EXPLICIT paths; verify `git diff --cached --name-status`;
  **NEVER `git stash`**; NO Co-Authored-By; long messages via
  `git commit -F`.

### Progress Tracker (authoritative copy lives in D4)

| Phase | Status |
|---|---|
| P0–P2 ✅ (`e2674208`…`3005170b`) · **P3 (BLOCKS) ✅ COMPLETE** (P3a `290f77f9` · P3b `36ce601c` · P3c `1b021d57`) | done |
| **P4 co-design** — audit `wf_8458c23b` + options panel `wf_82e56156`; **Q_U5/Q_U6/Q_U7/Q_U8 RULED**; partition LOCKED P4a–P4e | ✅ docs `cae212c8`→`f1537a7b` |
| **THE PAUSE** — Q_U9 (List) + update-in ω fence + whole-node abort | ⬜ **← THE SESSION OPENS HERE** |
| P4a totality+repairs · P4b carrier+migration · P4c gate+wrapper+PVec · P4d map-generic+2b · P4e flatten/splat/disclose | ⬜ |
| P5 Ruling B · PX · X.close (PIR-gated; P6 residue = the gate row) | ⬜ |

### NEXT IMMEDIATE TASK

**Resolve the PAUSE with the owner** (§5 items 1–3 — Q_U9 needs a ruling;
the two fences need ratification; none blocks P4a technically, but the owner
held the phase on them deliberately), **then open P4a failing-test-first**:
the `select-step-kind` totality dispatcher (loud arms at the four silent
catch-alls — one fixture per position; e.g. `[else '()]` @
syntax.rkt:907@`02dd27d7`) · the LOWER-vs-WALK fail-first panic fixture
(a runtime miss inside a broadcast must ABORT the node, never bury an
`expr-panic` in an output slot — `select-reduce`'s single `let/ec`) · the
`select-reduce` per-branch subject re-whnf hoist · the `whnf-trivial?`
container-VALUE-carrier arms (champ/rrb/hset absent; ~96% of per-element
cost; no bare head arms outside `nf` = the safety proof) · an
attribution-clean bench vs the P2 baseline (nothing else in the slice).

**Grounding: the P4 mini-audit + options panel ALREADY RAN**
(`wf_8458c23b-312`, 5 facets + critic @ `02dd27d7`, 14th consecutive premise
refuted; `wf_82e56156-b28`, 3 clusters × propose/critique/synthesize) and
are folded into D4 §3 + §5.P4. **P4a opens with a LIGHT re-grounding only**
(coordinate re-pinning — the LET merge shifted macros/parse-reader/parser/
typing-core line numbers; all audit coordinates are @ `02dd27d7`).

---

## §2 — Documents to Hot-Load (ORDERED)

**§2a Always-Load**: `CLAUDE.md` + `CLAUDE.local.md` · `MEMORY.md` +
`ciu-t6-records.md` (**the paragraph at the VERY END = the P4 state**;
mid-file is history) · `DESIGN_METHODOLOGY.org` (Stage-4 per-phase
protocol) · `DESIGN_PRINCIPLES.org` · `CRITIQUE_METHODOLOGY.org` ·
`HANDOFF_PROTOCOL.org` · `MASTER_ROADMAP.org` · CIU master
`docs/tracking/2026-03-21_CIU_MASTER.md`.

**§2b rules** (auto-load; load-bearing for P4): **`pipeline.md`**
(§ Exhaustive Walkers — P4a's totality dispatcher IS this rule applied
early; § New AST Node — P4b/P4c mint carrier + sentinel; § infer/inferQ
twins) · **`prologos-syntax.md`** § Reader (both modes, always; the `:`
seam) · `testing.md` (targeted runner; `bench-ab` has NO `--ref` —
worktree-pin baselines; the A/B needs BOTH legs pinned) · `workflow.md`
(5-step gate; adversarial VAG; belt-and-suspenders is BLOCKING — P4b must
END single-carrier) · `on-network.md` (the zero-propagator posture has a
NAMED trigger; the Network Reality Check applies to every P4 commit).

**§2c Session-Specific — READ IN FULL, IN THIS ORDER:**

1. **D4** `docs/tracking/2026-07-28_CIU_T6_PATH_SELECTION_D4.md` — §3
   ledger: **the Q_U5–Q_U8 blocks** (each with full rationale +
   rejected-with-reason) and the Q_T batch they build on · **§5.P4 in
   full**: the audit-record (11 numbered findings), the LOCKED partition
   P4a–P4e, and **the pre-implementation pause items** · §Q8 (normative
   lexical grammar) · §2.3 carrier table · §8 risks (R6 arity hazard —
   load-bearing for the carrier-shape decision).
2. The spec `docs/research/2026-07-28_path-selection-spec.md` — §3.1–§3.2
   (grades, extent, fusion) · §3.5 (flatten) · §3.7 (disclose) · §5.2–§5.4
   (result-shape computation, meet rule, row-map) · §7.5/§7.7/§7.8 (the
   first-classness outlook Q_U5 partially lands) · §10.2/10.4/10.5/10.7
   (P4's corpus). A GUIDE — D4's adaptations win.
3. **The FIRST-CLASS PATHS design**
   `docs/tracking/2026-03-20_FIRST_CLASS_PATHS_DESIGN.md` — the absorbed
   predecessor (Phases 0–7c shipped; its 7b was `expr-broadcast-get`; its
   §1 problem statement is P4's). P4b retires its carrier INTO the unified
   one; know what it shipped before touching it.
4. The dailies `docs/tracking/standups/2026-07-28_dailies.md` — STATE head
   + the last **3** LOG entries (P4 open + Q_U5/U6 → Q_U7/U8 → the handoff
   close). ⚠ The **"D4.P3c LANDED"** entry sits further up, *above* the
   merged QTT/LET worktree-arc entries — read it too; it carries P3's
   closing state. (This file interleaves two arcs since the merge.)
5. `racket/prologos/examples/2026-07-26-ciu-t6-path-selection.prologos` —
   §C/§D/§I carry the [D4.P4]-tagged lines; 52 live markers; the marker
   gate renumbers on uncomment.
6. `tests/test-path-selection.rkt` (**204** cases; P4 grows it) +
   `tests/test-path-selection-acceptance.rkt` (the gate).
7. `docs/tracking/DEFERRED.md` — CIU T6 items **5** (P4e's, citation is
   DIRTY-TREE-only — re-census at HEAD), **9**, **12** (absorbed by P4b's
   semantic table), **19** (row annotations — context for F-row), **21–23**.

---

## §3 — Key Design Decisions (owner-ruled; do NOT revisit without census-grade cause)

- **Q_U5 — ONE REIFIED SELECTOR CARRIER, monomorphic at P4.**
  `expr-path` + `expr-select` unify; `#p(…)`, `x{…}`, path position =
  three spellings of ONE representation. Precision now comes from KNOWN
  source rows (probe: `spec g P -> Int` / `defn g [r] r.a` types cleanly);
  bound-selector reuse rides **F-row's existing gate** (`ρ` row-meta is
  STAGED in the carrier comment, syntax.rkt:672@`02dd27d7` — the owner:
  the records types were BUILT from row polymorphism + codata; the type on
  the collection is knowable). Rejected: brace-only (spine loss — the
  owner's original objection), a SECOND charter (First-Class Paths Phase 8
  sat idle four months; belt-and-suspenders is BLOCKING), Datum (syntactic
  order ≠ selection order), selector-as-function (**ERASES THE SPINE** —
  function types are not lattice elements; the general result, recorded).
- **Q_U6 — WHOLESALE path migration + the three-stage sequencing.** All
  FOUR `rewrite-dot-access` production callers (map-literal values ·
  subforms re-entry · pipe pre-fold · mixfix — the 4th was P3a's own
  addition, missed by every enumeration) are probe-verified HEAD-agnostic
  (arity collapse only). The REAL cost is the behavior-preservation
  checklist: **one carrier, TWO typing postures by sort** (Q_T2's ruled
  asymmetry is LIVE: `dyn1.host` → `?meta` D19-permissive vs `dyn1{host}`
  → loud Horn-D refusal).
- **Q_U7 — the ω step is the ONE-STEP WRAPPER `(@bcast step)`.** Ruling 4b
  RESTATED: extent structural (broadcast-of-nothing UNCONSTRUCTIBLE; the
  §3.2.1 extent pair = two visibly different datums); **L1 fusion is a
  THEOREM the battery pins** (`users:0:userName` → ONE layer), free under
  any representation; the layer-count clause retired as descriptive.
  Rejected: flat marker (extent-by-adjacency ⇒ representable malformed
  states + a backward scan), run-carrier (the parser would MERGE adjacent
  wrappers — the normalization 4b's own rationale forbids), per-step grade
  field. ω is key-transparent in the components walk (a WRITTEN dispatcher
  arm); branch-initial `:` stays refused in v1 (W2).
- **Q_U8 — the `:` gate: UNIFORM positional `$bcast-step` mint at grouping
  + parser position-dispatch.** Byte-adjacent keyword/colon-annotation
  after a non-empty local result mints the sentinel (BOTH groupers; a REAL
  access sentinel — fuses via the fold, the `$postfix-index` pattern,
  paying the NINE-site §Q8.5 surface). The parser dispatches by position:
  expression → ω step; **binder → the annotation consumers UNWRAP**
  (`fused-type-annot?` ×4 · LET's binder consumer · spec/`$brace-params`
  paths). Zero tokenizer changes. **Corpus A/B MANDATORY** with a NAMED
  diff set (the fused-binder sites). Rejected: mint-suppression by context
  (an enumerated context list — the under-count class), parser-only
  (adjacency destroyed below grouping, Q8.5 inv 2), a fused token.
- **Inherited, still locked**: Q1 map-generic `:` · Q5 disclose v1 bare ·
  the 2b polarity split (filter-on-miss vs all-must-offer = a Galois
  ADJOINT PAIR — never "unify"; the union component set is DECLARED closed
  at typing time) · 4c per-field row-map (desugaring to
  `map-map-vals`+lambda BANNED) · 4d dyn-tail support-boundedness ·
  zero-propagator v1 (trigger: X.close perf pressure or F-row — real, at
  §9 row 3) · Q_U2 Reading A · Q_T3/T4/L4 · Q_U4 (subject-root synth
  PREFERRED, flip deferred — DEFERRED 23).

## §4 — Surprises (HIGHEST RE-DERIVATION RISK)

1. **The audit's frame reversed TWICE.** The panel's proposers leaned
   "charter the reification" on "B needs row polymorphism"; the panel's own
   critic probe-refuted the CONCLUSION (monomorphic annotated projection
   works); the OWNER then refuted the PREMISE'S FRAMING (rows were built
   row-polymorphic + codata; `ρ` staged at F-row). Do not resurrect the
   "row polymorphism blocks B" argument — it is dead at both ends.
2. **First-Class Paths is live and half-forgotten**: `#p(a.b.c) : Path`
   round-trips; `get-in` works; **`update-in` WORKS (the write direction
   exists)**; and a malformed `#p(0)`-class literal defines at 0 errors
   (the ground `Path` type is vacuous). Its Phase 7b IS the retired
   `expr-broadcast-get`. D4 §5.P4 now names it; older text reads as if the
   problem were new.
3. **§5.P4's LOWERING clause was wrong** (four agents converged):
   `select-reduce` WALKS under ONE `let/ec` (reduction.rkt:1600@`02dd27d7`)
   — a per-element lowering would BURY `expr-panic` values in output slots
   (the P2.b fabrication class). Settle by the P4a fail-first fixture. Under
   WALK, the def-seam `map-map-vals`/`pvec-map` twin defect (closed-row +
   het-tuple legs FAIL at the def seam with a lying "Multiplicity
   violation"; Map/PVec legs pass) is NOT a P4 prerequisite — filed, not
   owed.
4. **PVec-of-union is NOT blocked** (the design assumed it was):
   constructible/reducible/indexable at HEAD; ONLY projection fails —
   `u.size` offered by BOTH components at Int still fails — because the
   union arm lacks the PER-COMPONENT `schema-fvar->row-or-self` its
   nil-safe sibling has (typing-core.rkt:2232 vs :2254 @`02dd27d7`). The
   §10.7 discriminating fixture IS constructible.
5. **The LET merge landed MID-CO-DESIGN** (`5e16ead4`): +738 lines in
   macros/parse-reader/parser/typing-core; no select-surface collision
   (LET REUSES the P1a marker seat — the seat generalized); ALL audit
   coordinates are @ `02dd27d7` and MUST be re-pinned. And it **improved
   the Q_U8 safety net**: the fused-annotation hazard went from ZERO
   instances (A/B-blind) to 3 acceptance lines + 12 suite-gated embedded
   pins + 17 defn shapes — a naive `:` gate now turns the suite RED.
6. **The residue is bigger than filed**: `broadcast-access` = 16 mentions /
   3 files, incl. a token-TYPE group (parse-reader.rkt:2161@`02dd27d7`)
   named by NO enumeration, and `broadcast-access?` is STILL a live member
   of `access-sentinel?` — the retired sentinel still gates fusion. **Plus a
   live TEST pin on the token type** (`tests/test-parse-reader.rkt:561`
   asserts `'broadcast-access` for `xs.*name`) which the disposal turns RED
   unless updated in the SAME commit. P4c disposes ALL of it in the commit
   that pays the parser.rkt:793 `:name` promise.
7. **`quests` is a List, not a PVec** (cons-spine; corpus :225) — the 2b
   split's carrier enumeration missed it; its broadcast disposition is
   Q_U9, THE PAUSE.
8. **Two levers the design never budgeted**: `whnf-trivial?` has every
   container TYPE former and ZERO container VALUE carriers (~96% of
   per-element cost; safety proof verified); `select-reduce` re-whnf's the
   subject PER BRANCH against its own "evaluated ONCE" comment. Both are
   P4a's. The bench and the first per-element broadcast must NOT share a
   commit range (attribution).
9. **Enumeration under-counts hit SIX this arc** (the 4th fold caller was
   P3a's own pipe pre-fold). Positional rules over hand lists wherever
   possible; where a list is unavoidable, the totality dispatcher makes the
   miss LOUD.

## §5 — THE PAUSE (owner hold-point) + Open/Deferred

**The owner deliberately paused before implementation on these** (D4 §5.P4
§ "Pre-implementation pause items"):

1. **Q_U9 (PENDING, owner)** — the List broadcast disposition: broadcast
   over cons-spines (a fifth functorial lift) vs a guided refusal naming
   the PVec conversion (which changes `quests:t`'s corpus fate). Due at
   P4d; does not block P4a–P4c.
2. **The update-in ω FENCE (ratification)** — `update-in` accepts grade-1
   selectors only; ω-bearing selectors refuse loudly (broadcast writes are
   spec §7.7 traversal territory, NOT v1). Monotone.
3. **The whole-node abort (ratification)** — a runtime miss inside a
   broadcast aborts the WHOLE selection (single `let/ec`; no partial
   results, no buried panics). Consistent with the P2.b tier; pin it so
   "map semantics" intuition cannot drift it.

**Slice-round work (named, no owner gate)**: the carrier struct shape
(P4b's round, against code, under the §8 R6 arity hazard; the slice ENDS
single-carrier) · the `'path`-sort semantic table (D19 metas · P2
miss-hints via `projection-parts` · nil-safe `#.name` · the ns-dot guard —
do not reintroduce b0db8f3e · `reconstitute-selection-paths` = DEFERRED 12
absorbed) · the splat-vs-duplicate-check typing-side extension (P4e) · the
`:diags*` trailing-`*` splitter grammar (P4e) · the A/B diff-set
re-derivation at implementation HEAD.

**Standing deferred**: DEFERRED 5 (P4e re-censuses at HEAD — the :674
citation is dirty-tree-only) · 9 · 12 (P4b absorbs) · 19 (F-row context) ·
21 · 22 · 23 (Q_U4 flip, P5's trigger). Q6 (idempotent self-merge) is
P5's ruling but P4's representation must not foreclose it — the wrapper is
inert data, verified safe. The keyword-projection disposition (§2.4) is
due at P4e's close.

## §6 — Process Notes

- **Racket**: `"/Applications/Racket v9.0/bin/racket"`; runner
  `tools/run-affected-tests.rkt --tests …`; probes via `tools/run-file.rkt`
  (`--check` for acceptance); all from `racket/prologos/`. Manual
  `raco make` needs `PLT_CS_COMPILE_LIMIT=1000000`. `tools/check-parens.sh`
  after EVERY `.rkt` edit — **then COMPILE**.
- **Failing-test-first**; a pin must fail for the reason its name claims
  (no bare-digit regexes — the temp-file-path trap hit TWICE; transparent
  error structs print paths, so `#rx"-"`-class pins are vacuous).
- **Adversarial verify before EVERY behavioural commit** — 7 of the last 8
  slices had a catch (P3c was the first no-BLOCKING slice in eight; its
  rank-1 was still a twin-drift in the ONE dispatch not routed through the
  shared walk). The adjudicator worktree-pins a baseline when a regression
  claim needs proving.
- **The shared-walk discipline**: parser check, typing, and reduction
  consume the SAME syntax.rkt walk — any new step kind gets its arm in the
  totality dispatcher FIRST (P4a), then everywhere at once.
- **Owner co-designs in PROSE, one question per turn, Q-labels** (batch
  letters used: L, M, N, R, T, U through U8; **next free: U9**, pre-named
  for the List question).
- **Per-phase 5-step gate** · commits trigger dailies (STATE overwrite +
  LOG append) · per-slice records in the slice's D4 §5 section · probes in
  the SCRATCHPAD, never the repo · full suite = regression gate ONLY
  (failure logs, never a re-run) · the marker gate renumbers on mid-file
  uncomment — land trailing markers first.
- **Bench discipline**: `bench-ab.rkt` has NO `--ref`; worktree-pin
  baselines; never stash (owner WIP lives in the main tree); the
  `whnf-trivial?` lever and the first broadcast must be separately
  attributable.
