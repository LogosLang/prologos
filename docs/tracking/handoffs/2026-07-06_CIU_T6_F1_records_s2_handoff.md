# Handoff — CIU Track 6 F1: Structural Records, resume at F1a-s3

**Date**: 2026-07-06 · **Author**: session that co-designed F1 (records + collection reframe) → D.2 → implemented F1a-s1 + s2.
**Resume target**: **F1a-s3** (remaining dispositions), then **F1a-col** (tuples + flavor-B collections).

> ⚠ On-disk is authoritative. RUN `git log --oneline -10` + `git status --short` FIRST. Re-verify any "broken" claim with canonical syntax before trusting.

---

## §1 Current state (precise)

- **HEAD**: `589fb067` — "feat(CIU T6 F1a-s2): {:a 1}.a : Int". Suite **GREEN 8545 / 449 / 0**.
- **Working tree**: pre-existing OWNER WIP ONLY (`.claude/settings.local.json`, `docs/standups/*.org`, `examples/*.prologos`, `MASTER_ROADMAP.md`/`LANGUAGE_VISION.md` deletions, untracked owner files). **LEAVE ALONE — never blind-commit.** Stage only your files.
- **THE GOAL IS DONE**: `{:a 1}.a : Int` works end-to-end (WS, `:no-prelude`). Unannotated all-keyword literals infer structural records `{:a Int}`; projection returns the observed type; `+ {:a 1}.a 1 ⇒ 2 : Int` (V5). Heterogeneous `{:n 1 :s "x"} : {:n Int :s String}` (per-field). Annotated maps + schema paths unchanged. Exact `assoc`/`dissoc`/`keys`/`vals`/`has-key`/`nil-safe-get`; closed-row-miss = type error.
- **Racket binary**: `"/Applications/Racket v9.0/bin/racket"` (quoted). Runner: `cd racket/prologos && racket tools/run-affected-tests.rkt`.

## §2 Hot-load (in order)

1. **This handoff** (§3 refinement is load-bearing).
2. **The F1 design doc** — `docs/tracking/2026-07-06_CIU_T6_F1_STRUCTURAL_RECORDS_DESIGN.md`: §2 progress tracker (s1/s2 ✅), **§11a s2 implementation notes + the design refinement**, §4.3 disposition table, §10 the 7 resolved questions, §11 D.3-finding→resolution map.
3. **The track doc** — `docs/tracking/2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md` §2a: locked decisions **D1–D14** (D13/D14 = the collection reframe).
4. **The D.3 critique record** — `docs/tracking/2026-07-06_CIU_T6_F1_STAGE3_CRITIQUE_D3.md` (B1–B4, S1–S12; which are done vs s3-remaining).
5. **The dailies** — `docs/tracking/standups/2026-07-05_dailies.md` (the 2026-07-06 F1 arc + s2 checkpoint).
6. **Research notes** (context) — `docs/research/2026-07-06_ROWS_COALGEBRA_PROPAGATOR_NOTE.md`.
   Memory (auto-loaded): `ciu-t6-records`, `design-dialogue-preference`, MEMORY.md.
   Rules (auto): `pipeline.md` (New AST Node checklist — records are internal-only), `on-network.md`, `testing.md`, `workflow.md`.

## §3 The design refinement s2 revealed (READ — it corrects D.2)

D.2 §4.3 said the **Record→Map α** is "only a `check` arm; leave `unify`/`subtype-predicate` untouched." **Insufficient.** The α must be reachable from **FOUR** subsumption entry points (all now implemented):
1. `check`-subsumption fallback (`typing-core` ~:2760) — `record-<:-map?` (solves meta-`V`).
2. qtt's DUPLICATED `checkQ` fallback (`qtt` ~:2464) — same arm (B2).
3. `subtype?` **and** `structural-subtype-ground?` (`subtype-predicate.rkt`) — `record-subtypes-map?` (pure structural). **BOTH**: nested subsumption `(List Record) <: (List Map)` recurses the covariant element through `structural-subtype-ground?`, NOT `subtype?`.
4. `classify-whnf-problem` (`unify.rkt`, requires subtype-predicate) — directional `(Record,Map)`+`(Map,Record)` coercion, always `record-subtypes-map?(record,map)`. Needed because polymorphic `(cons {:a 1} nil)` commits the element param to the record, which meets the `(Map K V)` annotation through `unify`, not `check`.

**D11 (no record `<:` record judgment) is PRESERVED** — this is the record→*Map* bridge (a record projected to its uniform-Map view, Q_E), not record-vs-record width. `record-subtypes-map?` (pure, in subtype-predicate, provided to unify) vs `record-<:-map?` (typing-core, solves meta-V). Forced by `test-postfix-index-03` (pre-s2 worked only via `(Map K Open)`'s `Open` unifying with `Nat`).

## §4 Key implementation coordinates (verify line numbers — they drift)

- **Carrier**: `syntax.rkt` — `(struct expr-Record (key-domain fields tail))` + `(struct record-field (type presence))` + helpers `record-map-field-types`/`make-record`/`record-extend`/`record-remove`/`record-lookup-field` (all provided). NO `prop:ctor-desc-tag` (keyed variable-width can't ride the fixed-arity positional walk).
- **Elaborator**: `elaborator.rkt` `surf-map-literal` (~:2113) — entries-first scan; all-keyword → record seed `(map-empty (expr-Keyword) (expr-Record 'keyword '() 'closed))`; else legacy Open seed.
- **typing-core infer**: map-empty record-seed arm; map-assoc grow (`record-extend`) + dynamic-key degrade; `record-project` (get/map-get); the map-op Record arms (dissoc/keys/vals/size/has-key/nil-safe-get); helpers `record-project` + `record-<:-map?` near `schema-lookup-field` (~:390). B1 seed-check arm at map-empty-vs-Map (~:2485).
- **qtt**: map-assoc/map-get/dissoc delegate type to `(infer ctx e)`; B2 fallback arm.
- **subtype-predicate**: `record-subtypes-map?` (provided); cases in `subtype?` + `structural-subtype-ground?`.
- **unify**: classify-whnf-problem Record↔Map coercion (after the Open cases).
- **Tests**: `tests/test-record-node.rkt` (pipeline, 15); `tests/test-f1-records-acceptance.rkt` (WS acceptance gate — runs `examples/2026-07-06-ciu-t6-f1-records.prologos` `--check`, 27 markers). Flipped: test-first-class-paths, test-mixed-map (T-2 supersession), test-path-expressions, test-postfix-index-03.

## §5 F1a-s3 remaining + F1a-col

**s3** (genuinely remaining after s2 pulled the map-op surface forward):
- **B3** — Record-vs-Record SAME-SHAPE unify classify case (equal key-domain+labels+tails → `'sub` per-field goals; label mismatch → `'conv` + closed-row-miss). Different-shape → union-widen = **F1a-col** flavor B (NAMED regression until then; escape hatch `: (List <r1|r2>)`). + a **prelude-loaded** WS test (list-of-records; `:no-prelude` can't see `'[…]`).
- **S3** — `map-fold-entries`/`map-filter-entries`/`map-map-vals` Record arms (uniform-view; today `[_ (expr-error)]` → regress on records) + the union-arm accepting Record components.
- **S7** — the RICH closed-row-miss diagnostic (currently plain "Could not infer type"; want "field :b not in {:a Int} — available: :a"). `typing-errors.rkt` hint arm (Issue-#70 walk precedent).
- **S10** — trait-resolution `ground-expr?` Record arm (done in s1? verify) + the "records match no Map-headed instance head" posture; 2-line probe for blast radius.
- **cross-module `.pnet` canary** (D.3 coverage gap — a Record-typed def in a lib module consumed downstream; the F2 detonation surface `:no-prelude` single-file acceptance can't reach).
- **B4** acceptance dynamic-key canaries (Keyword key → degrade; String key → error).

**F1a-col** (sibling slice, same phase): **flavor A** tuple minting + the `@[…]` heterogeneous classifier (Nat-keyed row; tuple-by-default; `@[1 "a"]` errors today = net-new); **flavor B** union-widening on element-unify-failure (visible, not silent). Then **F1a.2** (dyn tail + Open node deletion / D7-b), **F1b** (width + Map↔schema seal), **F-row** (ρ/`Concat`, UCS-5/SRE-5 junctions).

## §6 Disciplines / gates

- **WS-first**: wire to WS; tests in WS `.prologos` (`:no-prelude` for language features — full prelude balloons ~48s under suite contention). The acceptance file + its suite gate is the Level-3 regression net.
- **Per-change gate**: `../../tools/check-parens.sh <file>` per `.rkt` → `raco make driver.rkt` → targeted `run-affected-tests.rkt --tests …` → full `--all --force-rerun` (output→FILE, read once; NEVER re-run to diagnose — read `data/benchmarks/failures/*.log`) → commit (`git commit -F -`, stage ONLY your files, **NO `Co-Authored-By`**).
- **Owner design-dialogue** = PROSE, options in spaced blocks, `Q_N` labels; AskUserQuestion sparingly. Design dialogue + novel-design implementation = MAIN-SESSION; grounding/mechanical = delegable (grounding-audit / design-options-panel / research workflows).
- **Minting-is-the-point-of-no-return**: any change to what a literal types as forces every downstream consumer arm to be handled or it regresses — the suite is the gate; expect display-churn (flip) + real-regression (fix) categories.

---
*Handoff for CIU T6 F1a-s3. Resume: hot-load §2, verify §4 coordinates, then s3 dispositions (B3 first — it needs the prelude WS test). On-disk is authoritative.*
