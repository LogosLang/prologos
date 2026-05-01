# SRE Track 2I — Phase 3 Handoff (Phases 1, 2, 2a, 3c closed; Phase 3 ready to open)

**Date**: 2026-04-30 (end of working session)
**Purpose**: Transfer context for picking up SRE Track 2I at Phase 3 (empirical SD sweep). Phases 1, 2, 2a, and 3c are complete and committed. Phase 3 mini-design is locked and persisted to the design doc; ready to implement.

**Read this document FIRST. Then hot-load per §2 below. Summarize understanding back to the user before starting Phase 3 implementation work.**

---

## §1 Current Work State (PRECISE)

**Track**: SRE Track 2I "SD∨ / SD∧ Algebraic-Property Checks" + per-relation `meet-registry` (Phase 3c)
**Series**: SRE (Structural Reasoning Engine) — see [SRE Master](../2026-03-22_SRE_MASTER.md)
**Design doc**: [`docs/tracking/2026-04-30_SRE_TRACK2I_SD_CHECKS_DESIGN.md`](../2026-04-30_SRE_TRACK2I_SD_CHECKS_DESIGN.md) (Stage 3 light)

**Phase status**:

| Phase | Description | Status | Commit |
|---|---|---|---|
| 1 | `test-sd-vee` + `test-sd-wedge` in sre-core.rkt; wire into inference + reporting; implication rules `distributive ⇒ SD` | ✅ | `a35d5f65` |
| 2 | Programmatic sample generator from ctor-desc registry + sd-evidence struct + `/detailed` variants | ✅ | `f241e14e` |
| 2a | Principled-fix corrective: per-component-spec generation (Option C), drop `with-handlers`, include binder ctors with closed-body limitation | ✅ | `1c0c012e` |
| 3c | Per-relation `meet-registry` on sre-domain; retire `current-lattice-subtype-fn` callback; principled subtype-meet dispatch | ✅ | `d4e8c811` (+ `05438feb` hash backfill) |
| **3** | **Empirical sweep + findings (refined post-Phase-3c)** | ⬜ **NEXT** | — |
| 3.5 | (deferred) Has-pseudo-complement empirical check | ⬜ | — |
| 3b | (deferred) Generator extension for session/form domain sweeps | ⬜ | — |
| T | Dedicated test phase: `test-sre-sd-properties.rkt` | ⬜ | — |
| Discussion | Review Phase 3 findings; decide on registration declaration updates | ⬜ | Out-of-band of phase tracker |

**Recent commits (last 5 in repo, top-down most recent first)**:
- `44c8c07f` dailies: log SH (Self-Hosting) Series founding batch *[from concurrent session — not Track 2I]*
- `a88ea1bd` sh: deep research note — propagator network as super-optimizing compiler *[concurrent session]*
- `2424b166` docs/research: PTF — lattice hierarchy and distributivity for propagators *[Track 2I-derived]*
- `d5be1769` sh: research note — self-hosting path and bootstrap stages *[concurrent session]*
- `3ef7b87b` sh: open SH (Self-Hosting) Series Master *[concurrent session]*

**Track 2I commits in chronological order** (top of stack first):
- `05438feb` sre/track2i: design doc commit-hash backfill (d4e8c811)
- `d4e8c811` sre/track2i: per-relation meet-registry, retire subtype-meet callback (Phase 3c)
- `1c0c012e` sre/track2i: per-component-spec generator + binder inclusion (Phase 2a)
- `f08c27c6` sre/track2i: tracker update + dailies for Phase 2 close
- `f241e14e` sre/track2i: programmatic sample generator + detailed SD evidence (Phase 2)
- `547b8751` sre/track2i: tracker update + dailies for Phase 1 close
- `a35d5f65` sre/track2i: add SD∨ / SD∧ algebraic-property checks (Phase 1)

**Next immediate task**: Implement Phase 3 per locked mini-design (design doc § Phase 3). Scope is bounded; design and audit have been performed and persisted. Open with mini-design conversational checkpoint per Stage 4 protocol, then implement.

**Test status**: 8132 tests / 420 files / 1 pre-existing failure (`test-parse-reader.rkt` — verified independent of Track 2I via stash test on Phase 2a HEAD before Phase 3c). Targeted-runner on Track 2I-touched files: 98 tests / 2 files / all pass via `racket tools/run-affected-tests.rkt --tests tests/test-sre-algebraic.rkt --tests tests/test-sre-track2h.rkt`.

---

## §2 Documents to Hot-Load (ORDERED)

### §2a Always-Load (every session)

These establish project identity and process. Skim if recently read; DO read.

1. `CLAUDE.md` + `CLAUDE.local.md` — project + local instructions
2. `MEMORY.md` — auto-memory index
3. `docs/tracking/principles/HANDOFF_PROTOCOL.org` — this protocol
4. `docs/tracking/principles/DESIGN_METHODOLOGY.org` — Stage 4 protocol (mini-design + mini-audit, VAG, 5-step phase completion)
5. `docs/tracking/principles/CRITIQUE_METHODOLOGY.org` — P/R/M/S lenses; SRE Lattice Lens
6. `docs/tracking/principles/DESIGN_PRINCIPLES.org` — 10 load-bearing principles
7. `docs/tracking/principles/DEVELOPMENT_LESSONS.org` — distilled retros (longitudinal patterns)
8. `docs/tracking/MASTER_ROADMAP.org` — single source of truth for series/tracks
9. **SRE Master** [`docs/tracking/2026-03-22_SRE_MASTER.md`](../2026-03-22_SRE_MASTER.md) — series tracker; Track 2I row near bottom

### §2b Architectural Rules (auto-loaded via `.claude/rules/`)

Internalized, not just present in context:

- `.claude/rules/on-network.md` — design mantra; off-network = debt
- `.claude/rules/propagator-design.md` — fire-once, broadcast, set-latch, component-paths
- `.claude/rules/structural-thinking.md` — **SRE Lattice Lens (7 questions)**; Hyperlattice Conjecture
- `.claude/rules/stratification.md` — strata on propagator base
- `.claude/rules/testing.md` — diagnostic protocol; never re-run full suite for diagnostics
- `.claude/rules/pipeline.md` — exhaustiveness checklists for AST/struct/parameter additions
- `.claude/rules/workflow.md` — operational discipline (commit, phase completion, VAG adversarial framing, with-handlers red-flag)

### §2c Session-Specific (READ IN FULL)

These are the load-bearing primary artifacts for Phase 3 work:

1. **[Track 2I Design Doc](../2026-04-30_SRE_TRACK2I_SD_CHECKS_DESIGN.md)** — THE design. Read in full. Phase 3 mini-design is § Phase 3 (locked 2026-04-30). Phases 1, 2, 2a, 3c entries document what was delivered. § Stage 2 Audit (folded in) provides the cross-domain context.
2. **[Lattice Variety and Canonical Form for SRE](../../research/2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md)** — Stage 0/1 research note. Anchors Track 2I's why. § 5.4 is the SD-check seed for Phase 1.
3. **[Lattice Hierarchy and Distributivity for Propagators](../../research/2026-04-30_LATTICE_HIERARCHY_AND_DISTRIBUTIVITY_FOR_PROPAGATORS.md)** — PTF Stage 0/1 research note (commit `2424b166`). § 4 has the distributivity-status flip worked example. Important for Phase 3 framing — explains why the flip matters and what the hierarchy posture unlocks.
4. **[PTF Master](../2026-03-28_PTF_MASTER.md)** — Series home for the lattice hierarchy note. Track 2 row references the new note.
5. **[Current dailies](../standups/2026-04-26_dailies.md)** — Look at the END for Phase 3c entry (commit `d4e8c811`) which has the bonus-discovery story. Plus prior Phase 1/2/2a entries.
6. **[Issue #40 — with-handlers audit](https://github.com/LogosLang/prologos/issues/40)** — Filed at Phase 2a close. Sister anti-pattern (defensive scaffolding); Phase 3c addressed the callback-polymorphism sister.
7. **[PM Master § Track 12 Phase 3c precedent](../2026-03-13_PROPAGATOR_MIGRATION_MASTER.md)** (search "Phase 3c precedent" in the file) — cross-reference for the meta-solution callback retirement deferred to PM Track 12.
8. **[DEFERRED.md SRE Track 2I Phase 3c → PM Track 12 input](../DEFERRED.md)** (search "SRE Track 2I Phase 3c") — same cross-reference for visibility from the DEFERRED side.

### §2d Companion research notes (background; READ if context permits)

- [Widening, Narrowing, and Continuity for UCS](../../research/2026-04-30_WIDENING_NARROWING_INFINITE_DOMAINS_FOR_UCS.md) — companion to canonical-form note; addresses limit-case domains
- [Capability Safety as Datalog and Non-Compositionality of Safety](../../research/2026-04-23_CAPABILITY_SAFETY_DATALOG_HYPERGRAPHS.md) — separate research arc from earlier in session; background on multi-agent + capability concerns

### §2e Code surfaces touched by Track 2I

To consult during Phase 3 implementation:

- `racket/prologos/sre-core.rkt` — sd-evidence struct, test-sd-vee/test-sd-wedge (+ /detailed), implication rules, **sre-domain-meet accessor (Phase 3c)**, meet-registry field on sre-domain struct
- `racket/prologos/sre-sample-generator.rkt` — `generate-domain-samples` per-component-spec generator. Phase 3 will likely add `run-sd-sweep` here.
- `racket/prologos/type-lattice.rkt` — `type-lattice-meet` with `#:subtype-fn` keyword (Phase 3c refactor)
- `racket/prologos/unify.rkt` — `type-merge-registry` and `type-meet-registry` (Phase 3c)
- `racket/prologos/subtype-predicate.rkt` — `type-pseudo-complement` updated with explicit `#:subtype-fn`
- `racket/prologos/tests/test-sre-algebraic.rkt` — Track 2I primary test surface; `realistic-type-atoms` defined here
- `racket/prologos/tests/test-sre-track2h.rkt` — `subtype-meet` helper added by Phase 3c

---

## §3 Key Design Decisions (RATIONALE)

These are settled. Don't revisit without good reason.

1. **Phase 3 sweeps type×equality + type×subtype only**, NOT session×equality or form×equality. Reason: Phase 2a generator's `build-atoms-by-spec` only populates `'type` and `mult-lattice-spec` pools. Session/form domains need generator extension (Phase 3b, deferred). Decision locked 2026-04-30 dialogue.

2. **Pseudo-complement check deferred to Phase 3.5** (separate phase). Reason: keeps Phase 3 scope tight to validating the distributivity finding. Pseudo-complement is a separable concern. Decision locked 2026-04-30 dialogue.

3. **Bonus findings → discuss-when-found, NOT commit speculatively**. Reason: Phase 2a and Phase 3c each surfaced a real bonus finding (malformed-compounds-via-with-handlers; distributivity-flip-via-callback). User direction: when Phase 3 surfaces another, dialogue first, decide together. NOT auto-commit.

4. **NO registration declaration updates in Phase 3**. Per user direction (consistent across phases). Phase 3 reports findings; Discussion phase decides. The bonus discovery (equality lattice IS distributive) is a Discussion-phase candidate for declaration update; do NOT pre-empt that.

5. **Phase 3 uses `sre-domain-meet` lookup, NOT direct `type-lattice-meet` calls**. Phase 3c made per-relation meet principled; Phase 3 uses it correctly-by-construction. The sweep dispatches: `((sre-domain-meet td 'equality) ...)` for the equality-meet path; `((sre-domain-meet td 'subtype) ...)` for the subtype-meet path.

6. **Phase 3 uses `realistic-type-atoms` as base-values**: `(list (expr-Int) (expr-Bool) (expr-Nat) (expr-String))`. Type domain has no nullary ctors registered; without base-values, no compounds generate (sentinel filter excludes bot/top). Defined in `test-sre-algebraic.rkt`; Phase 3 sweep should reuse or import equivalently.

7. **PTF Lattice Hierarchy note is the framework reference for Phase 3 findings interpretation**. The note's § 4 explains why the distributivity-status flip matters (defensive scaffolding hides true algebraic posture) and the hierarchy catalog tells us what each level unlocks. Reference when interpreting findings.

8. **Sister meta-solution callback (`current-lattice-meta-solution-fn`) is OUT of scope for Track 2I**. Deferred to PM Track 12 with cross-references in PM Master + DEFERRED. 5+ usage sites; ties to metavar-store internals; significantly larger scope than the subtype callback Phase 3c addressed. Phase 3c retirement template documented for PM Track 12 to adopt.

9. **The Track 2H subtype-aware-meet behavior is preserved** — just dispatched via per-relation registry instead of via off-network callback. `(type-lattice-meet a b #:subtype-fn subtype?)` does what the callback-installed meet did. The semantics are unchanged; only the dispatch mechanism is principled.

10. **Acceptance file deviation**: NO `.prologos` acceptance file for Track 2I. Per user direction (scope too small for SD-check work). Justified in design doc preamble. Test-sre-algebraic.rkt + test-sre-track2h.rkt + Phase T's test-sre-sd-properties.rkt are sufficient regression net.

---

## §4 Surprises and Non-Obvious Findings

The most important section. Highest-risk items for a fresh session to get wrong.

### 4.1 The Move B+ pattern's payoff scales beyond defensive guards (CRITICAL)

Two distinct corrective sub-phases (2a, 3c) both surfaced *real bugs the prior code was hiding*. The pattern:
1. Identify defensive/implicit scaffolding (with-handlers, callback parameter)
2. Refactor to correct-by-construction
3. Tests fail in unexpected ways → those failures ARE the bonus finding
4. Fix the underlying structural concern

Phase 2a found `with-handlers` was masking malformed compounds (lattice sentinels in component slots → invalid `(expr-Pi mw type-top type-top)` values that merge can't dispatch on). Phase 3c found the always-installed callback was hiding that the type lattice under equality merge IS distributive (Track 2H's union-aware merge restored distributivity; the callback's mixed semantics hid that fact).

**Phase 3 might surface another such finding.** Per user direction (decision #3): if it does, dialogue first, decide together — NOT commit speculatively.

### 4.2 The distributivity-status flip (Phase 3c bonus discovery)

`type×equality` distributivity status changed across three points:
- Track 2G (2026-03-30): "type lattice not distributive under equality merge" — correct AT THE TIME (pre-Track-2H, distinct atoms went to type-top giving M3 sublattice)
- PPN 4C T-3 Commit B (2026-04-22): made equality merge produce union types for incompatible atoms (the merge change wasn't framed as distributivity-changing at the time, but it was)
- Phase 3c (2026-04-30): retiring the always-installed callback surfaced that equality lattice IS distributive (216/216 hand-picked-6 triples confirmed)

**Phase 3 task**: validate this on the wider Phase 2a-generator sample space (compounds + non-dependent binders), not just the 6 hand-picked atoms. The wider validation is the load-bearing one for Discussion-phase declaration update.

**The deeper lesson** (codification candidate): "when a track changes a merge or meet function, re-validate algebraic-property declarations on the affected domain at Stage 4 close." Worth flagging if the pattern recurs (1 data point so far).

### 4.3 Lattice sentinels (bot/top) are NOT valid structural components

`type-bot` is the symbol `'type-bot`; `type-top` is `'type-top`. They're valid lattice ELEMENTS (they participate in merge / SD checks) but NOT valid structural COMPONENTS — feeding them into `(expr-Pi mw type-top type-top)` produces malformed values that merge functions can't dispatch on (`match: no matching clause for 'type-top`).

Phase 2a's two-pool model handles this: the `full-pool` (lattice elements, including sentinels) vs the `non-sentinel-pool` (structural components, sentinels filtered out). `build-atoms-by-spec` does the filtering. **Don't collapse the two pools.**

### 4.4 Type domain has no nullary ctors registered

So `nullary-ctor-inhabitants` returns empty for the type domain. Without `base-values`, the generator produces no compounds (since the component pool is empty after sentinel filter). Phase 3 sweep MUST pass `realistic-type-atoms` as base-values (or equivalent) to exercise compound generation.

### 4.5 `all-ctor-descs` takes `#:domain` keyword, not positional

Caught at compile time in Phase 2 implementation. Easy gotcha.

### 4.6 The sister meta-solution callback follows the same retirement template

`current-lattice-meta-solution-fn` (`type-lattice.rkt:68`) is structurally identical to the retired subtype callback — a `make-parameter` callback installed by driver.rkt that changes algebraic behavior based on driver init. 5+ usage sites; ties to metavar-store internals. Documented in PM Master Track 12 + DEFERRED.md as natural next target for PM Track 12. **Phase 3 should NOT touch it** — it's broader scope than Track 2I.

### 4.7 Concurrent session collision (process note)

This session experienced a concurrent-branch collision earlier in Phase 3c work — the user had another session active touching files in the same branch. The collision caused Phase 3c work to silently revert at one point (recovered via re-implementation). User noted afterward "we don't have anything else going at the moment, so we should be safe to work again." If a fresh session experiences similar phantom-revert behavior, suspect concurrent-branch activity and check `git stash list` / git log for unexpected commits.

### 4.8 Test-parse-reader.rkt is pre-existing-failing

1 example file with unbalanced brackets + 1/49 example files failed topology comparison. **Pre-existing on Phase 2a close** (verified via stash test). Not Track 2I's concern. Don't get distracted by it during Phase 3 full-suite checks.

---

## §5 Open Questions and Deferred Work

### Phase 3 itself (NEXT)

- **Mini-design + mini-audit conversational opening**: per Stage 4 protocol, open with dialogue checkpoint, then implement. Mini-design IS already locked in design doc § Phase 3 — but the conversational opening lets the user calibrate before code lands.
- **Sweep function placement**: `sre-sample-generator.rkt` (per design doc) — sample generation + diagnostic share concern. Could alternatively go in a new `sre-property-sweep.rkt` if the sweep ends up substantial.
- **Findings table format**: design doc § Phase 3 Findings is currently empty. Phase 3 populates it.

### Deferred to later phases / tracks

- **Phase 3.5**: pseudo-complement empirical check (own test function parallel to test-distributive et al., ~30-50 LoC). Determines Heyting reach for non-Heyting-declared domains. Decoupled from Phase 3 to keep that scope tight.
- **Phase 3b**: generator extension for session × equality and form × equality sweeps. Requires per-domain ctor analysis + atom-pool extension in `build-atoms-by-spec`. session×equality is the OTHER empirically-interesting case.
- **Phase T**: dedicated test phase `test-sre-sd-properties.rkt`. Workflow rule MANDATORY. Comes after Phase 3 + 3.5 + 3b (whichever land).
- **Discussion (out-of-band)**: review Phase 3 findings; decide whether to update declared-properties at the equality registration site (`unify.rkt:92`). If distributivity confirmed across wider sample, candidate: add `'distributive prop-confirmed`; potentially `'has-pseudo-complement prop-confirmed` if Phase 3.5 confirms.

### Sibling concerns (filed elsewhere; NOT Track 2I scope)

- **Issue #40**: codebase-wide `with-handlers` audit (72 remaining instances after Phase 2a). A/B/C/D categorization framework. SRE-adjacent findings preserved as audit starting point.
- **PM Track 12**: `current-lattice-meta-solution-fn` retirement (sister callback to the subtype one Phase 3c retired). Cross-reference in PM Master + DEFERRED.md.
- **PNF→PTF clarification (resolved)**: the user's reference to "PNF" was a typo for "PTF" (Propagator Theory Foundations). The lattice hierarchy research note landed in PTF (commit `2424b166`).

---

## §6 Process Notes

Established or reaffirmed during this session:

- **Per-phase Stage 4 protocol**: mini-design + mini-audit conversational, persisted to design doc; implementation; VAG adversarial two-column; 5-step phase completion (test, commit, tracker, dailies, proceed).
- **Conversational cadence**: max ~1h or 1 phase boundary per autonomous stretch; checkpoint between phases.
- **`git commit -o pathspec`**: the defensive committal pattern when external state churn is happening (concurrent sessions, linter actions). Restricts commit to the named paths even if index changes underneath. Used multiple times this session.
- **Move B+ pattern precedent**: Phase 2a's `with-handlers` retirement and Phase 3c's callback retirement both followed the pattern (defensive/implicit scaffolding masks structural reality; principled refactor surfaces bonus findings; fix the underlying concern). Phase 3 should expect this might recur.
- **Adversarial VAG with two columns**: catalogue (what passes) vs challenge (could it be MORE aligned). Used at Phases 1, 2, 2a, 3c. Surfaced real concerns each time.
- **GitHub issue vs DEFERRED.md**: long-lived cross-cutting concerns spanning multiple files/series → GitHub issue (better visibility, search, cross-referencing). In-flight scope deferrals within an active track → DEFERRED.md. Used #40 (with-handlers audit) at Phase 2a close.
- **Cross-references at phase close**: Phase 3c added cross-references to PM Master + DEFERRED.md for the sister meta-solution callback. Pattern: when a phase's principled refactor has implications for sibling concerns elsewhere, cross-reference proactively.
- **Test-track-rerun discipline**: failure logs in `data/benchmarks/failures/*.log` persist; read them with the Read tool, don't re-run full suite for diagnostics. Per `.claude/rules/testing.md`.

---

## §7 Hot-Load Reading Protocol (per HANDOFF_PROTOCOL.org)

When picking up this handoff:

1. Read this handoff document first (§1-§6 above).
2. Read §2a Always-Load — skim if recently read, but DO read.
3. Read EVERY §2c Session-Specific document — IN FULL, not sampled.
4. Skim §2b Architectural Rules (auto-loaded; internalize the Move B+ pattern lesson + with-handlers red-flag rule + adversarial VAG framing).
5. Look at §2d if context permits.
6. Summarize understanding back to the user BEFORE starting work.
7. The user validates the understanding — only then proceed to Phase 3 mini-design conversational opening.

"I have full context" requires being able to:
- Articulate the four phase outcomes (1, 2, 2a, 3c)
- Name the bonus discoveries (malformed-compounds; distributivity-flip)
- Recall why pseudo-complement is deferred and why session/form are deferred
- Recognize the Move B+ pattern and the surprise it might surface again

If any of those is unclear after reading, ASK before proceeding.

---

## §8 Cross-References

- Design doc: [`2026-04-30_SRE_TRACK2I_SD_CHECKS_DESIGN.md`](../2026-04-30_SRE_TRACK2I_SD_CHECKS_DESIGN.md)
- SRE Master: [`2026-03-22_SRE_MASTER.md`](../2026-03-22_SRE_MASTER.md) (Track 2I row)
- PTF Master: [`2026-03-28_PTF_MASTER.md`](../2026-03-28_PTF_MASTER.md) (Lattice Hierarchy note linked at row 2)
- PM Master Track 12: [`2026-03-13_PROPAGATOR_MIGRATION_MASTER.md`](../2026-03-13_PROPAGATOR_MIGRATION_MASTER.md) (Phase 3c precedent + meta-solution callback target)
- DEFERRED.md (search "SRE Track 2I Phase 3c"): [`DEFERRED.md`](../DEFERRED.md)
- Issue #40: https://github.com/LogosLang/prologos/issues/40
- Workflow rule (with-handlers red-flag): `.claude/rules/workflow.md` lines 56-58
- Methodology (VAG adversarial): `docs/tracking/principles/DESIGN_METHODOLOGY.org` § Vision Alignment Gate
- Methodology (Stage 4 protocol): `docs/tracking/principles/DESIGN_METHODOLOGY.org` § Stage 4
- Lessons (Move B+ pattern, 3 data points before 2a/3c): `docs/tracking/principles/DEVELOPMENT_LESSONS.org` § Microbench-Claim Verification (PPN 4C S2.c-iii)
