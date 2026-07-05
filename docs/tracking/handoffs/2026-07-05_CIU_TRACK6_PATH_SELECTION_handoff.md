# Handoff — CIU Track 6: Path Selection & Anonymous-Record (`Map`) Typing

**Date**: 2026-07-05
**Author**: Claude (session that founded Num Series + opened CIU Track 6 + landed F2/F3/F4)
**Resume target**: **F1** — retire the internal `Open` type → structural `Map` typing.

> ⚠ On-disk is authoritative. RUN `git log --oneline -8` + `git status --short` FIRST. Re-verify every audit "broken" finding with **canonical** syntax before trusting it (a schema false-alarm bit us this session).

---

## §1 Current Work State (precise)

- **Series/Track**: **CIU Series, Track 6** — Anonymous Records & Path Selection.
- **Design doc**: `docs/tracking/2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md` (Stage 0/1; §2a locked decisions; §4a grounding-audit findings). Track row in `docs/tracking/2026-03-21_CIU_MASTER.md`.
- **HEAD**: `35b3bc90` — "docs(CIU T6): mark F2/F3/F4 fundamentals complete".
- **Suite**: GREEN **8530 / 448 / 0**.
- **Working tree**: pre-existing OWNER WIP only (42 items) — leave alone, never blind-commit.
- **Progress**:
  - **F2** ✅ (`af161de7`) — 5 path AST nodes registered in `pnet-serialize`.
  - **F3** ✅ (`af161de7`) — `^` added to `recognize-keyword` (WS `:key^alias` rename tokenizes).
  - **F4** ✅ (`142da071`) — `tests/test-first-class-paths.rkt` (WS coverage).
  - **F1** ⬜ **NEXT** — retire `Open` → structural `Map` typing. Goal `{:a 1}.a : Int`.
- **Next immediate task**: co-design F1's three open decisions (§5 below), then implement F1a (`{:a 1}.a : Int` + retire `Open`) main-session, WS-wired, WS-tested.

## §2 Documents to Hot-Load (ordered)

**Always-load** (project identity + process): `CLAUDE.md` + `CLAUDE.local.md`; `MEMORY.md`; `DESIGN_METHODOLOGY.org`; `DESIGN_PRINCIPLES.org`; `CRITIQUE_METHODOLOGY.org`; `HANDOFF_PROTOCOL.org`; `docs/tracking/MASTER_ROADMAP.org`; **CIU series master** `docs/tracking/2026-03-21_CIU_MASTER.md`.

**Architectural rules** (auto-loaded via `.claude/rules/`, but internalize): `pipeline.md` (the exhaustiveness checklist — **F1 touches `typing-core` + `qtt` in parallel, files 7+8**), `on-network.md`, `structural-thinking.md`, `testing.md`, `propagator-design.md`.

**Session-specific** (read in full):
1. `docs/tracking/2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md` — **the design doc.** §2 owner vision (V1–V5), §2a locked decisions (D1–D5), §4a grounding-audit findings (the real subsystem state), §5 open design questions.
2. `docs/tracking/standups/2026-07-05_dailies.md` — this session's arc.
3. Grounding-audit result: run `wf_b5bda45e` (distilled into §4a of the design doc — the audit's raw output file may be gone; §4a is the durable record).

## §3 Key Design Decisions (rationale)

- **D1 — `Map` IS the anonymous *open record* type; retire the internal `Open`.** Owner: maps are anonymous records that should type structurally/observationally (the type = the observed field types). `Open` (an α-semantic wildcard, `syntax.rkt:990`) erases field types → `{:a 1}.a : Open` instead of `: Int`. Retire it.
- **D2 — `Map` ⇄ `schema` interop, both directions.** A `Map` flows where a compatible `schema` is expected and vice versa.
- **D3 — unify Map + schema as ONE structural-record notion** (axes: named/anonymous × closed/open). `schema` already carries a `closed?` flag, so the open/closed distinction exists *inside* schema already — don't build two mechanisms.
- **D4 — home = CIU Series (Track 6).** The Array⇄Map unification is genuinely **CIU Track 3's** turf (`Indexed`/`Keyed` trait dispatch, ⬜ pending) — reconcile/sequence, do NOT parallel-design.
- **D5 — fundamentals-first + WS-first.** Wire everything through to WS (the usability design target) and regression-test in WS `.prologos`.
- **F1 approach (chosen)** — generalize the *working* schema per-field projection (`typing-core:1536`, `schema-lookup-field` → `schema-field-type->expr`) to anonymous map literals, rather than inventing row-polymorphism from scratch. (Not yet decided: the representation, row-depth, and scope split — §5.)

## §4 Surprises and Non-Obvious Findings

- **The audit's "schema-typed dot-access BROKEN" was a PROBE ARTIFACT.** It used the non-canonical `schema Person := {…}` inline form. The canonical **block** form works: `def alice : Person := {…}` → `alice.age → 30 : Int` (0 errors). The V1 substrate *functions* — de-risked. **General lesson: re-verify audit "broken" claims with canonical syntax.**
- **F4 perf landmine**: a WS `process-file` test that loads the **full prelude** balloons to ~48s under 10-worker suite contention. Use `:no-prelude` for language-level feature tests (F4 stayed ~0.6s). Broadcast `.*` needs a list literal `'[…]` (= prelude) so its WS coverage is deferred/probe-only.
- **`Open` is α-semantic** (unifies/checks both directions at zero cost: `typing-core:2608-2609`, `qtt:2140-2141`, `unify:574-575`). Retiring it means narrowing those wildcard behaviors so anonymous-record projection stops absorbing to/from arbitrary types.
- **`qtt` asymmetry**: `qtt.rkt:1206-1220` (`inferQ` `expr-map-get`) has **NO `expr-Open` arm** (falls to `tu-error`) while `typing-core:1515` does — an existing inconsistency any Open-replacement must reconcile.
- **The `.{`→`_{}` reframe dissolves the collision** we hit — `coll{selector}` postfix juxtaposition (via the `arr[i]` `$postfix-index` adjacency precedent) is the redesigned surface; `.{` was only ever mixfix.
- **Quantale is orthogonal to records** — it lives in the QTT-multiplicity/SRE-tensor layer, not the value-type lattice where records live (flat lattice + variance subtyping). Don't over-index on quantale-for-records.

## §5 Open Questions and Deferred Work

**F1 open decisions (co-design with owner FIRST):**
- **Q1 — representation**: reuse `schema-entry` as an anonymous inline record carried on the `Map` type (per D3), vs a dedicated new AST node (full pipeline-exhaustiveness cost, `syntax`→`qtt`).
- **Q2 — row-polymorphism depth**: start structural + open-by-default; defer row variables (`{:a Int | ρ}`) to a later phase?
- **Q3 — scope split**: F1a = `{:a 1}.a : Int` + retire `Open`; then F1b = `Map`⇄`schema` record subtyping/interop (D2).

**Deferred / related:**
- **V2/V3/V4 selection syntax** (`coll{selector}` postfix, broadcast, result-shape) — after F1. V4 (result-shape: keep-path-or-not) is the design's hardest/most-open piece; the "selector-shape = result-shape" framing is on the table.
- **Array⇄Map unification** → reconcile with **CIU Track 3** (Trait-Dispatched Access).
- Broadcast `.*` result type is an unsolved meta (not precise element type) — imprecise; revisit with structural typing.
- No `process-file`-safe way to test full-prelude WS features fast (the 48s landmine) — `:no-prelude` is the workaround.

## §6 Process Notes

- **Owner prefers PROSE + STRUCTURED design dialogue with options SPACED into clearly-separated blocks** (each option = its own bolded label + whitespace; NOT dense inline `(a)/(b)/(c)`). Questions labeled **Q_N** (owner dislikes "Ask N"). Decisions labeled (D1, F1a…). Memory: `design-dialogue-preference` (refined 2026-07-05). Use AskUserQuestion sparingly.
- **WS-first**: features wired through to WS; tests written in **WS `.prologos`** (not sexp/`.rkt`), with `:no-prelude` for language-level features.
- **Per-change gate**: `tools/check-parens.sh` per `.rkt` → `cd racket/prologos && raco make driver.rkt` → targeted `run-affected-tests.rkt --tests …` → full `--all --force-rerun --no-precompile` (output → FILE) → commit (`git commit -F -`, **stage ONLY your files**, **NO `Co-Authored-By`**).
- **Diff-back / main-session implementation**: grounding audits (the `grounding-audit` workflow) are delegable; the design dialogue + novel-design implementation are main-session. R-lens-verify audit `rlens_targets` surgically before trusting.
- **Never blind-commit the working-tree OWNER WIP** (42 items). Racket: `"/Applications/Racket v9.0/bin/racket"`.
- **Memories updated this session**: `numerics-track`, `design-dialogue-preference`, `demo-dependency-resolver-track`, `MEMORY.md` (Num Series pointer).

---
*Handoff for CIU Track 6 F1. Resume: hot-load §2, confirm the dailies-file choice if relevant, co-design §5's Q1–Q3, then implement F1a WS-first.*
