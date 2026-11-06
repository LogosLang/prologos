# CIU Track 6 — Path Selection **D4** (implementation design over the 2026-07-28 spec)

**Status**: D4 DRAFT — the redesign intake. The normative SURFACE is the spec:
[`docs/tracking/tracks/CIU/CIU_6/2026-07-28_path-selection-spec.md`](2026-07-28_path-selection-spec.md)
(v0.1, status-tagged per element; its §10 corpus is the acceptance suite).
This document is the IMPLEMENTATION design over it: supersession mapping,
grounded code reality, the rulings ledger, and the re-planned phase ladder.
**Predecessor**: [`2026-07-26_CIU_T6_PATH_SELECTION_DESIGN.md`](2026-07-26_CIU_T6_PATH_SELECTION_DESIGN.md)
— CLOSED as the record of rounds 1–8b (its PS1–PS15+deltas surface is
superseded per §1.2 below; its P0–P2 implementation record stands).
**Series / Track**: CIU Series → Track 6 · **Date opened**: 2026-07-28 · **Owner**: Zee Larson

**Process note [owner, 2026-07-28]**: one-line tracker rows do not scale. This
document is born with PER-PHASE SECTIONS (§5); the Progress Tracker below
carries status + a pointer only, and every phase's design, audit findings,
rulings, censuses and test delta live in its own section.

**Split into its parts [owner, 2026-11-06]**: "Fine with the D4 split." This file is now the spine: the
tracker, §1–§2, §4 and §6–§10, plus an index. The §3 decision ledger, the §Q8 lexical grammar and every §5
per-phase record are their own documents in this directory, linked below; each holds its D4 lines verbatim
(only link targets were rewritten) and states the line offset, and [§11](#d4-line-map) maps every old D4 line.
Every moved anchor keeps its id in its new file AND a stub here, so an old `D4.md#…` link still lands.

---

## Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| **P0** | **Acceptance corpus** — augment the EXISTING acceptance file with the spec §10 examples + Appendix fixtures; `--check` gated; new forms commented until their phase lands | ✅ | [§5.P0](phases/CIU_6_P0.md#p0) · `e2674208` — 28/28 markers, 0 errors; all 7 fixtures load (layout via `def X`, issue #80 sidestepped); corpus phase-tagged in HEAD notation; carrier pins double as [§2.3](#s2-3) docs |
| **P1a** | **Retirement batch + substrate** — dot-key family · the FULL `broadcast-get` chain (reader + parser keyword + surf + elaborator + node) · `m[:kw]` · reject batch · `surface-rewrite.rkt` `dot-lbrace` cleanup (BEFORE any re-mint) · the marker-form diagnostic seat | ✅ | [§5.P1a](phases/CIU_6_P1.md#p1a) · **`859b529d`** — suite 9253/474/0, acceptance 28/28 + 89/89, −744/+320; adversarial verify found 2 whole-file-abort defects (1 MINE, in the seat) → fixed + pinned pre-commit |
| **P1b-i** | **Repairs + probes + the Q8 DRAFT** — the top-level `<` swallow fix (Q_M4) · WS narrowing typed vars · `def ?x` reservation (Q_M3) · the Q_M1 gating probe + `:N` / keyword-`*` / `:<` · **Q8 written from the results** | ✅ | [§5.P1b-i](phases/CIU_6_P1.md#p1b-i) + **[§Q8](2026-07-28_CIU_6_D4_LEXICAL_GRAMMAR.md#q8)** · `fc65ca54` — suite 9263/474/0, corpus A/B 160 files / 2 intended diffs; **Q8 owner-reviewed ✅ 2026-07-28, amended by [Q_M8](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-m8)** (ordinals multi-digit in both bands) |
| **P1b-ii** | **The `.{` opener** — `dot-lbrace` re-mint across **EIGHT** edit regions (not six) incl. the surviving `surface-rewrite.rkt:516` POSITIVE addition; plain `'rbrace` closer (Q_M5); new `$dot-brace` sentinel + `dot-brace-group` tag + tree-parser arm (Q_N1); the Q_N3 two-grouper agreement guard | ✅ | [§5.P1b-ii](phases/CIU_6_P1.md#p1b-ii) · **`1a1091d4`** — suite **9279/474/0**, acceptance 28/28 + 89/89, corpus A/B **158 files / 1 intended diff**; adversarial verify caught a **BLOCKING regression I introduced** (`$dot-brace` missing from `pattern-var?` → whole-file abort in a defmacro template) — fixed + pinned pre-commit |
| **P1b-iii** | **Brace adjacency + the head registry + Q_M8** — the forced `$select-brace` sentinel (Q_M6) · the `reader-forms.rkt` leaf registry · adjacency in BOTH groupers (Q_N7) · bucket 4 ruled SELECT (Q_N5) · the `:N` digit-run widening + the structural `fused-type-annot?` repair (Q_N4) · P1b-ii's residual CLOSED | ✅ | [§5.P1b-iii](phases/CIU_6_P1.md#p1b-iii) · **`a6af2761`** — suite **9304/474/0**, acceptance 28/28 + 89/89, corpus A/B **158 files / ZERO diffs**; adversarial verify caught **3 BLOCKING** (one non-idempotent fold → a silently-dropped `defn` clause) + 10 SIGNIFICANT — all fixed or filed pre-commit |
| **P2** | **Grade-1 core** — `.k`/`.N` access + bare-path extraction. Carries **Q_M8's dot half** (`digit+` at the dot). Ruled at the mini-audit: **`.N` REUSES `$postfix-index`** (Q_R1 — near-zero registrations, fixpoint inherited, `v[0]` ≡ `v.0` byte-identical) · **copy the `:N` trailing guard** (Q_R2) · **dot band stays adjacency-free** (Q_R3) · `m.0` moves out of the v2 block (Q_R4) · **the `.N` error surface IS IN SCOPE** (Q_R5) | ✅ | [§5.P2](phases/CIU_6_P2.md#p2) · **`3005170b`** — suite **9370/475/0**, acceptance **35/35** + 89/89, corpus A/B **158 files / ZERO diffs**; audit `wf_22020418-a5f` (**12th** consecutive premise refuted); doc-truth separately `0e5a56a3` ([Q_R6](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-r6)); adversarial verify caught **a diagnostic REGRESSION I introduced** + 2 more, all fixed pre-commit; DEFERRED 9–13 |
| **P3a** | **The node + KEYED blocks, no `^`** — `surf-select`/`expr-select` (full pipeline.md cost paid once; twins; walkers via the generic fallback; NO PNET bump) · payload segmentation + the malformed-payload seat · **D-lenient presence** (Q_T2) · subject-once reduction · **strict merge for plain keys BEFORE `make-record` can last-win** · type-position refusal · branch-aware miss errors · §9's learnability pair | ✅ | [§5.P3a](phases/CIU_6_P3.md#p3a) · **`290f77f9`** — suite **9418/475/0**, acceptance **41/41** + records, battery 136/136, neighborhood 623/21; [Q_U1](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u1) (corpus list corrected, `6d919142`); adversarial verify caught **1 BLOCKING** (block-pipe select corruption at 0 errors — 6th consecutive slice) + 3 SIGNIFICANT, all fixed pre-commit; DEFERRED 15–20 |
| **P3b** | **The `^` family** — the ONE splitter (continuation grammar `-`?·{ε\|label\|`_`} + `^..`) · dissolve/splice · in-place rename · `^_` Reading N · the `^-` collapse family ([Q_T7](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-t7)) · `^..` ([Q_T8](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-t8)) · **output-level-local merge** ([Q_T3](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-t3), the monotonicity pin) · the [Q_T4a](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-t4a) ordinal-`^` guided error · the malformed-`^` battery | ✅ | §5.P3b · **`36ce601c`** — suite **9469/475/0**, acceptance **50/50** + records, battery 178; light re-grounding only (per Q_T5); adversarial verify caught **1 BLOCKING** (whole-datum ordinal-rekey marker → match-arm whole-file abort; fixed ELEMENT-WISE) + 8 SIGNIFICANT — all fixed pre-commit; DEFERRED 21–22; Q_U4 candidate flagged (sub-block synth scope) |
| **P3c** | **Keyless + L4 + honest nesting** — the nat-row mint at EVERY n (incl. 1 and homogeneous n) · ordinal branches `{N M}` · the L4 mixing error · `⟨String⟩` 1-tuple pins · the G11 one-space pair pinned side by side | ✅ | [§5.P3c](phases/CIU_6_P3.md#p3c) · **`1b021d57`** — suite **9497/475/0**, acceptance **52/52**, battery 206; P3 (BLOCKS) COMPLETE; the verify's FIRST no-BLOCKING slice in eight (2 SIGNIFICANT fixed pre-commit: the @ord walk-to-leaf twin-drift, the decimal-fusion leak); G11 landed AS AMENDED; in-block `v[0]`≡`.0` ratified-by-pin |
| **P4** | **Broadcast ω** — ⭐ **P4a ✅ · P4b ✅ COMPLETE** (b-i carrier + b-ii `$dot-access` migration; `x.a` now mints the unified selector carrier) · P4c–P4e ⬜ — `:s` one-step extent, L1 fusion, **map-generic `:`** (Q1 ✅), `*` flatten, `.*` row-splat, **the 2b HETEROGENEITY SPLIT** (per-position exact over tuples; keys-⋂/types-⋃ over PVec-of-union = NEW row-meet machinery) · **disclose `<`/`:<` (Q5 ✅ v1)** · dyn-tail = support-bounded (4d) | 🔄 | [§5.P4](phases/CIU_6_P4.md#p4) · co-design: audit `wf_8458c23b` + options panel · **RULED 2026-07-31**: [Q_U5](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u5) · [Q_U6](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u6) · [Q_U7](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u7) · [Q_U8](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u8) · [Q_U9](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u9) (the PAUSE cleared) · partition LOCKED P4a–P4e |
| **P4a** | **Totality + strategy-independent repairs** (no new surface) — the `select-step-kind` classifier routed through **THIRTEEN** dispatch sites in **FIVE** files (the design said 4, the first census said 8; the adversarial verify found 5 more, incl. two LEAF classifiers that run UPSTREAM of the guards and a render site the identifier-grep structurally could not see) · the whole-node-abort fixtures · the `select-reduce` subject re-whnf hoist (a CONTRACT fix — measured no perf delta) · the `whnf-trivial?` container-VALUE arms (1822 ns/call, 9.5×, by interleaved microbench; ≈−0.1% of wall) · the P2 bench baseline ESTABLISHED (none had ever been recorded) | ✅ | [§5.P4a](phases/CIU_6_P4a.md#p4a) · battery 204 → **224** |
| **P4c** | **The `:` gate + the ω wrapper + PVec broadcast** — ⭐ **Q_U16 RULED** (Q_U8 was NOT implementable; the binder unwrap moves to the reader post-pass, so the mint stays uniform and BOTH surfaces survive) · **Q_U16b**: `users:0` IS a legal ω step | 🔄 | [§5.P4c](phases/CIU_6_P4c.md#p4c) · P4c-1 ✅ `182f1678` · P4c-2 ✅ `68cdaae7` ([inverted default](phases/CIU_6_P4c.md#p4c-2-inverted)) · [P4c-3](phases/CIU_6_P4c.md#p4c-3) ✅ `d477772c` · [P4c-4a](phases/CIU_6_P4c.md#p4c-4a) ✅ `f31237fd` · [P4c-4b](phases/CIU_6_P4c.md#p4c-4b) ✅ `6b22515d` (end to end) · **[P4c-4c](phases/CIU_6_P4c.md#p4c-4c-close) ✅ `ae26f540`** — broadcast is REACHABLE: PVec ω value semantics + **G2** + the preparse seam guard. ⭐ The verify caught a BLOCKING whole-file abort every gate was blind to; owner ruled the structural fix ([close](phases/CIU_6_P4c.md#p4c-4c-close)) · [Q_U18](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u18) ✅ · DEFERRED 43 ✅ · 48 RULED uniform · P4c-5 ⬜ |
| **P4d** | **The carriers** — Map/keyword-row · het tuple · PVec-of-union · closed-schema subjects · the Q_U9 refusal's message split · corpus re-fate · **Q_U19 ✅ RULED (A)** | ✅ | [§5.P4d](phases/CIU_6_P4d.md#p4d) · slices **0 ✅ 1 ✅ 2 ✅ 3 ✅ 4a ✅ 4a' ✅ 4b ✅ 4c ✅ 4d-1 ✅ 4d-2 ✅ 5 ✅ 6 ✅** — broadcast is LIVE over PVec · Map · keyword-row · het tuple · union · closed schema. ⭐ The CLOSE's own audit found a whole-file abort in slice 3's code (slice 5) and Q1 re-opened as a live defect (slice 6). All THREE owner questions discharged: Q1 ruled+implemented · [Q2](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u22) answered (fix → DEFERRED 88) · Q3 answered (broadcast → 58 re-scoped; contract → 89) |
| **P4e** | **The `*` family · disclose `<`/`:<` · branch-initial `:`** — ⭐ **`*` is SORT-GENERIC** (deletes the layer the preceding step created: `:diags*` mapcat, `database*` splat). `.*` retires as row-splat; ~~rebinds to **ravel**~~ ravel is **`x:*`** ([Q_U63](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u63) = J, 2026-11-02); `*_` adds provenance keys; branch-initial `:` admits the **ordinal² transpose** | 🔄 | [§5.P4e](phases/CIU_6_P4.md#p4e) · RE-SCOPED 2026-08-08 ([Q_U23](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u23)–[Q_U29](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u29)) · ⛔ attempt 1 REVERTED `d0ac2a58` ([DEFERRED 101](../../../DEFERRED.md)); attempt 3 opens from [the census](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#star-census) ([Q_U30](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u30)/[Q_U31](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u31), prereq [102](../../../DEFERRED.md) ✅ `41458174`) · PREP ✅ `f63612e7`+`ae67419f` ([Q_U32](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u32)) · **slice A SHIPPED** `e7a49228`, **slice B REVERTED** `0e007864`: [§5.P4e-0-a3](phases/CIU_6_P4e-0.md#p4e-0-a3) · ⭐ **P4e-1a ✅ COMPLETE** `9cac0099` — the mint has its CONSUMER. [Q_U36](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u36) positive-list fuse + [Q_U37](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u37) territory-scoped refusal; 3 slices (attempt 1 of the last REVERTED); suite 10143/488/0, battery 476: [§5.P4e-1a](phases/CIU_6_P4e-1.md#p4e-1a) · **P4e-1b 🔄 SEMANTICS FULLY RULED, not implemented** (audit `wf_4b91ca25-73a`) — [Q_U38](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u38) collision REFUSED (conservative on the `'dyn` tail; gate moves to typing) · [Q_U39](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u39) closer-adjacent `*_` mint SPLIT OUT · ⭐⭐ [Q_U40](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u40)–[Q_U48](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u48). ⭐ **The flatten is LIVE at depth ≤ 1** (1b-iii shipped, `d5934397`); depth ≥ 2 is shielded pending [Q_U47](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u47)'s landing rule, now ruled. Semantics + slicing: [§5.P4e-1b](phases/CIU_6_P4e-1.md#p4e-1b) · remaining slices C1 · C2 · iv · v: [§5.P4e-1b-sequencing](phases/CIU_6_P4e-1b-iii-iv.md#p4e-1b-sequencing) · **1b-vi ✅ CLOSED** (checkpoint `d2ad3dad`, 2026-11-02): [§5.P4e-1b-vi](phases/CIU_6_P4e-1b-vi.md#p4e-1b-vi) · **P4e-2 🔄 OPENED 2026-11-03** (ravel `x:*`): [§5.P4e-2](phases/CIU_6_P4e-2.md#p4e-2) |
| **P4c-5** | **The `.*name` retirement + FULL residue disposal** — the last P4c residue, sequenced AFTER P4e | ⬜ | [§5.P4c-5](phases/CIU_6_P4c.md#p4c-5) · ⚠ **row ADDED at the P4d close 2026-08-08** — previously visible only as a `P4c-5 ⬜` fragment inside P4c's Notes cell |
| **PF** | **Path first-classness** (substrate; **P5's prerequisite**) — ⭐ **Q_U17 RULED B2**: a Path segment is a first-class `Step` value. Reify the closed six-kind union as a `data Step` ADT on the `Datum` pattern; `Path` stays GROUND; `segments : Path -> [List Step]`. Repairs the dead `path-segments` in the SAME change | ⬜ | [§5.PF](phases/CIU_6_PF.md#pf) · [Q_U17](2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u17) · panel `wf_68178bd3-eea` |
| **P5** | **Ruling B + factoring** — B2 keywise / B3 same-spine merge, L2 normal form, guided errors printing the factored spelling | ⬜ | [§5.P5](phases/CIU_6_P5.md#p5) · L1–L5 law battery · ⚠ B3 needs [PF](phases/CIU_6_PF.md#pf) |
| **PX** | **Binder-seam substrate** (carried, surface-independent) — the lambda-adoption hole + the standalone-def seam | ⬜ | [§5.PX](phases/CIU_6_PX.md#px) · position flexible |
| **P6** | **Demand semantics** — RULED STAGED (4a); **decision ✅ Q_U3 (owner, 2026-07-30): option (c)** — deferred to a named post-v1 phase, charter stub in §5.P6 | ⬜ (residue = the X.close gate row only) | [§5.P6](phases/CIU_6_P6.md#p6) |
| **X.close** | **MANDATORY** — bench matrix · DEFERRED triage · doc-truth sweep · memory fold · **Stage-5 PIR** | ⬜ | [§5.X](phases/CIU_6_X.md#x-close) · the track does not flip ✅ without the PIR |

*Per `workflow.md`: tests are PER-PHASE (each phase's section states its own
test delta); a behavioural phase shipping +0 tests is INCOMPLETE.*

---

<a id="s1"></a>

## §1 The redesign in one page

<a id="s1-1"></a>

### §1.1 What the spec is

A theory upgrade, not an amendment. Three commitments the old surface lacked:

1. **The key-sort thesis** (spec §1.1): vectors and Maps are key-valued nodes —
   ordinal keys are *contingent* (selection re-derives them), nominal keys are
   *essential* (selection preserves them unless `^` says otherwise).
2. **Per-step result discipline** (spec §1.2): blocks `x{…}` PROJECT by
   default; `^` DISSOLVES a level (splice); bare paths EXTRACT. The old
   design's single keying rule becomes a per-step choice.
3. **Selection is demand** (spec §1.3): blocks are copattern sets over codata;
   unselected computed leaves are never forced. This ties the feature to the
   coinductive anonymous-record typing that unlocked it.

On top: multiplicity **grades** 1/ω/0|1 (spec §3.1 — interval refinement
points at the QTT semiring), the **equational theory L1–L7** as test material,
**Ruling B** merge with a strict-first monotone waypoint (§3.6), and the
**W1–W4 expressivity walls** each with a designated exit (§6).

<a id="s1-2"></a>

### §1.2 Supersession of the settled surface (PS1–PS15 → spec)

| Old ruling | Disposition | Where |
|---|---|---|
| PS1 the law (dot·bracket·`:`·`*`) | **REPLACED** — block = `x{…}` by adjacency; `:s` broadcasts (one step, fused); postfix `*` = flatten; `.*` = row-splat; `^` = the key operator | spec §2.1 |
| PS2 uniform law (`v[…]` selects, `v.0` extracts) | `.N` extraction **survives**; the bracket flip is **CANCELED** — `v[0]` keeps its current working semantics for now [owner 2026-07-28] | §3 ledger |
| PS3 keying = last segment | **REPLACED** — projection-with-ancestry + `^` dissolve | spec §1.2, §3.3 |
| PS4 identities vs positions | **SURVIVES, now derived** from the key-sort thesis | spec §1.1, §3.3 |
| PS5 assembly (keyed→Map, keyless→tuple, mixed=error) | **SURVIVES** verbatim as L4, level-local | spec §3.3 |
| PS6 `^` on the key-generating segment | **GENERALIZED** — one operator, three continuations; mid-path dissolve/splice is NEW | spec §3.4 |
| PS7 collision = static error | **AMENDED to Ruling B** — strict-everywhere is the shippable v1 waypoint (so PS7 *is* the waypoint); errors may later become meanings, never vice versa | spec §3.6 |
| PS8 miss semantics | **SURVIVES** — P2's landed two-tier principle is substrate | landed code |
| PS9 `*` splat / `[*]` | **REPLACED** — `.*` row-splat (block position); bare postfix `*` = flatten one vector layer; `[*]` gone | spec §2.1, §3.5 |
| PS10 dot-only dynamism (`v.i` P4.d) | **SUPERSEDED** — v1 has NO dynamic keys; three-tier design is outlook | spec §7.6 |
| PS11 selector sugar + keyword-projection | **SUPERSEDED/OPEN** — first-class selectors are outlook (§7.5); keyword-projection's direct use is likely SUBSUMED by broadcast (`users:name`); disposition OPEN (§3) | spec §7.5 |
| PS12 retirements | **SURVIVE**, some deepened (`m[:a]`: brackets are no longer selection at all) | §5.P1 |
| PS13 reserved slots | **SUPERSEDED** by the staged-features program (0\|1 grade, `..` as schema-elaborated sugar, observational stratum, bidirectionality, relational reading) | spec §7 |
| PS14 sexp special form | **STILL NEEDED** — the spec does not address sexp mode; carried as an open implementation item | §3 ledger |
| PS15 subjects | **SUPERSEDED** by the typing story: copattern blocks, grade/shape result computation, the §5.3 meet rule, §5.4 row-map | spec §5 |

<a id="s1-3"></a>

### §1.3 What landed and stands (nothing unwinds)

- **P0** acceptance file (`examples/2026-07-26-ciu-t6-path-selection.prologos`):
  **AUGMENTED at D4.P0 (`e2674208`) to 28 markers**; they pin P1/P2 substrate and
  stay a regression instrument. The old-syntax §B/§C targets were replaced with
  the phase-tagged spec corpus (see §5.P0).
- **P1** `.{` retirement: what died was `.{`-as-MIXFIX (the `.( )` sibling).
  The spec's mid-path sub-block spelling `server^.{…}` is a DIFFERENT, NEW
  construct — today it reads as a loose `|.|` + `$brace-params` and errors
  end-to-end (`cfg.server.{host port}` → "Bare symbol 'host' not allowed as
  map key"). Its grouping is NEW P1 work — **RULED 3a**: a `dot-lbrace` compound token (§3).
- **P2** (5 slices, `ad75e57a`→`ac89341f`): the two-tier principle IS the
  grade-1 substrate — loud assertive misses (Map key / PVec / List / dynamic
  tuple OOB, both def seams), site 7's projection, the carried-alpha slot,
  `definitely-not-map?`'s positive polarity. The spec's §5.3 meet rule and
  §1.3 demand semantics sit ABOVE this layer, not against it.
- **The P3 mini-audit** (`wf_2830f0aa-9a4`): the token-registry facts,
  retirement censuses (live: dot-key 2 · `.*name` 4 · `m[:kw]` 22), the
  dead-compat-rejects finding, the classifier-error template, and the
  three-layer opener obligation all carry into §5.P1.

---

<a id="s2"></a>

## §2 Grounded code reality (probe-verified 2026-07-28 @ `89bc321c` unless noted)

<a id="s2-1"></a>

### §2.1 The three lexical seams, as they lex TODAY

Spec §2.2 names three juxtaposition-sensitive characters; probed:

| Form | Today's reader output | Consequence |
|---|---|---|
| `users:0` / `users:name` / `users :name` | ALL → `(users :0)` / `(users :name)` — **no adjacency distinction** | broadcast needs srcloc-adjacency at grouping (the postfix-index positional mechanism is the template, parse-reader.rkt:2441-2450) |
| `x:Int` | `(x :Int)` — annotations are parser-interpreted from the same shape | **the colon seam includes TYPE ANNOTATIONS**, not just keyword literals — the census must cover annotation positions |
| `x{a b}` vs `x {a b}` | BOTH → `(x ($brace-params a b))` — adjacency not distinguished | making adjacency significant changes SPACED `f {…}` call sites — census required before landing |
| `a^b` / `ssl^.enabled^ssl` | glue: `(a^b)` / `(ssl^ ($dot-access enabled^ssl))` | caret continuations split PARSER-side (POL.6 `split-fused-symbol` — ruled, carries) |
| `modules:diags*:msg` | `:diags*` — **`*` glues into the keyword** | flatten needs keyword-trailing-`*` handling |
| `users:{0.userName^}` | `users : ($brace-params …)` — `:{` yields a LONE `:` symbol (no keyword forms) | the broadcast-block form is detectable at grouping via the bare-`:` + adjacency |
| `app-config{database.*}` | `… database \|.\| *` — `.* }` shatters (broadcast recognizer needs ident-continue after `*`) | block-position row-splat needs its own grouping handling; coexists lexically with the `.*name` retirement |

<a id="s2-2"></a>

### §2.2 The POL.10 collision — the biggest hidden lift

Spec §1.3 [ADOPTED]: *"unselected computed leaves are never forced."* Today a
`def`'s map literal **whnf-forces its leaf values at commit** (POL.10 snapshot
semantics; the `expr-map-assoc` whnf arm forces `v`). `:date [now]` runs at
definition, not at selection. Demand semantics requires **lazy Map leaves** —
a runtime representation change with its own design (thunked leaves in the
champ? a demand mark? interaction with `.pnet` serialization and the effect
gate). **Staged as its own phase-gate decision (§5.P6), not silently absorbed.**
Until it lands, the corpus fixtures' computed leaves run eagerly — every §10
result is unchanged, only the forcing TIME differs.

<a id="s2-3"></a>

### §2.3 The carrier table (printed forms + the spec-notation translation)

The §2.1 grounding was lexical; this is the TYPE/PRINT layer the D5 critique
showed was missing (its "single most important unasked question"). Probed
2026-07-28 @ `2b1b383d`:

| Spec writes | HEAD's carrier + printed form | Notes |
|---|---|---|
| `〈T〉` (U+3008) | `[PVec T]` | homogeneous vector |
| n-tuple `〈T₁ T₂〉` | `⟨T₁ T₂⟩` (U+27E8) — a nat-keyed CLOSED row | het `@[…]` literals produce this |
| `〈τ₁ \| τ₂ \| …〉` het vector | **`⟨row₁ row₂ row₃⟩`** — a positional het TUPLE, duplicates un-collapsed, no union | the 2b split's first carrier; PVec-of-union exists only via annotation |
| 1-tuple `〈String〉` | representable (1-field nat-row; runtime `expr-rrb`) but the LITERAL arm collapses `@[x]` to `[PVec T]` | selection mints rows directly — the 2a ruling. ⚠ R5 classification RECORDED (2026-07-29): the spec's corpus marker `〈String〉` transcribes to HEAD's `⟨String⟩` — a NOTATION divergence (two spec notations share the `〈…〉` glyph; row 1 is the generic homogeneous vector, this row the concrete tuple). Previously applied only in an acceptance-file comment. Also: the literal arm collapses at EVERY homogeneous n (the probe iterates under rollback), not only n=1 — which is WHY selection mints rows directly for both of §B's keyless lines |
| keyed row `{:k T …}` in selection order | type: **canonically sorted** (`syntax.rkt:749-756`, `equal?`-identity, load-bearing) · value: champ-hash order, key-set-determined | the 2c ruling: carrier order, thesis-derived |
| row-meet (§5.3) | **does not exist** (0 grep hits) | booked as NEW machinery, §5.P4 |
| presence marks + `dyn` tail | `expr-Record (key-domain fields tail)`, `record-field (type presence)` — the S-lens-declared presence lattice | §6 declares it; dyn-tail semantics RULED by 4d, and for BLOCKS by **Q_T2 (Horn D lenient)** |

<a id="s2-4"></a>

### §2.4 Standing items the spec does not cover

- **sexp mode** (old PS14): postfix adjacency is WS-only; the sexp special form
  is still an implementation deliverable. ⚠ Figure corrected (P3 audit):
  `test-path-expressions.rkt` has 20 test-cases TOTAL of which 4 touch `.{`;
  the BULK of the sexp selection surface is `test-selection-paths.rkt` (56
  test-cases, 50 `.{`-bearing lines), which this section previously did not
  name. Both remain isolated from WS changes (audit-proven twice) and
  re-point when the sexp form lands.
- **`v[0]` bracket-postfix**: KEEPS current working semantics for now
  [owner 2026-07-28]. `.N` extraction arrives alongside; both spellings
  extract. Revisit at X.close whether bracket-postfix stays, becomes `get`
  sugar documentation-only, or retires.
- **keyword-projection `map :name users`** (the D.3-B2 replacement): never
  implemented; its direct use is subsumed by `users:name` under map-generic
  broadcast. The HOF/function-value case waits on first-class selectors
  (spec §7.5). **OPEN — owner disposition when P4 lands broadcast.**
- **PX (the binder-seam phase)**: the lambda-adoption hole + the standalone-def
  seam are SURFACE-INDEPENDENT substrate bugs — carried unchanged (§5.PX).

---

<a id="s4"></a>

## §4 Phase sequencing and dependencies

The Progress Tracker (top) carries status; this section carries WHY the order
is what it is.

- **P1 → P2 → P3 are strictly ordered**: tokens must lex before access can
  fold, and access must exist before blocks can contain paths.
- **P4 needs P3**: a broadcast body is a block (`users:{0.userName^}`), so
  block semantics must exist before ω can distribute over them.
- **P5 needs P4**: Ruling B's B3 case is defined over *spine identity*, and a
  spine is only observable once broadcasts exist. P3's STRICT merge is the
  deliberate waypoint in between — every error it raises can become a meaning
  at P5 without breaking a working program (spec §3.6 monotonicity).
- **PX is position-flexible**: surface-independent substrate bugs; it can land
  in any gap, and should land before X.close.
- **P6's DECISION is due at P3** (blocks are what make demand observable);
  its IMPLEMENTATION may land later or post-v1 — see §5.P6 for why it is
  staged rather than absorbed.
- **Gate**: NONE open on the critical path. Spec Q2 was DISSOLVED by ruling 2c
  (carrier order, thesis-derived); **Q8 is CLOSED** (written at P1b-i, owner-reviewed 2026-07-28, normative;
  see §Q8) — its own deliverable, not a blocker on
  anything upstream.

---

<a id="s5"></a>

## §5 Per-phase sections

Each phase's record is its own document in [`phases/`](phases/). The anchor stubs in the last column keep
every old `D4.md#…` link landing on the row that names its new home.

| Phase record | Was D4 lines | Anchors (stubs) |
|---|---|---|
| [§5.P0](phases/CIU_6_P0.md) | 4264–4309 | <a id="p0"></a> |
| [§5.P1 … P1b-i + §5.P1b-ii … P1b (superseded framing)](phases/CIU_6_P1.md) | 4310–4698, 4976–5475 | <a id="p1"></a><a id="p1a"></a><a id="p1b"></a><a id="p1b-i"></a><a id="p1b-ii"></a><a id="p1b-iii"></a><a id="p1b-superseded"></a> |
| [§5.P2](phases/CIU_6_P2.md) | 5476–5744 | <a id="p2"></a> |
| [§5.P3](phases/CIU_6_P3.md) | 5745–6104 | <a id="p3"></a><a id="p3a"></a><a id="p3b"></a><a id="p3c"></a> |
| [§5.P4 (co-design, partition, pause)](phases/CIU_6_P4.md) | 6105–6376 | <a id="p4"></a><a id="p4e"></a> |
| [§5.P4a](phases/CIU_6_P4a.md) | 6377–6596 | <a id="p4a"></a> |
| [§5.P4b](phases/CIU_6_P4b.md) | 6597–7337 | <a id="p4b"></a><a id="p4b-i"></a><a id="p4b-ii"></a><a id="p4b-ii-1"></a><a id="p4b-ii-2"></a><a id="p4b-ii-3"></a><a id="p4b-ii-close"></a> |
| [§5.P4c](phases/CIU_6_P4c.md) | 7338–8632 | <a id="p4c"></a><a id="p4c-5"></a><a id="p4c-1"></a><a id="p4c-2"></a><a id="p4c-2-close"></a><a id="p4c-2-inverted"></a><a id="p4c-3"></a><a id="p4c-3a"></a><a id="p4c-3a-cont"></a><a id="p4c-4"></a><a id="p4c-4-merge"></a><a id="p4c-4b"></a><a id="p4c-4a"></a><a id="p4c-4c"></a><a id="p4c-4c-audit"></a><a id="p4c-4c-close"></a><a id="p4c-sequencing"></a> |
| [§5.P4d-0 + §5.P4d + §5.P4d-s7](phases/CIU_6_P4d.md) | 8633–9430, 12937–13081 | <a id="p4d-0"></a><a id="p4d"></a><a id="p4d-close"></a><a id="p4d-s7"></a> |
| [§5.P4e-0](phases/CIU_6_P4e-0.md) | 9431–9764 | <a id="p4e-0"></a><a id="p4e-0-audit"></a><a id="p4e-0-a3"></a><a id="p4e-0-a3-verifies"></a><a id="p4e-0-a3-method"></a><a id="p4e-0-a3-owed"></a><a id="p4e-0-a3-round3"></a><a id="p4e-0-a3-flake"></a><a id="p4e-0-b"></a> |
| [§5.P4e-1 + 1a + 1b](phases/CIU_6_P4e-1.md) | 9765–10213 | <a id="p4e-1"></a><a id="p4e-1a"></a><a id="p4e-1b"></a> |
| [§5.P4e-1b-vi](phases/CIU_6_P4e-1b-vi.md) | 10214–11225 | <a id="p4e-1b-vi"></a><a id="p4e-1b-vi-c"></a><a id="p4e-1b-vi-d"></a><a id="p4e-1b-vi-d2"></a><a id="p4e-1b-vi-e"></a><a id="p4e-1b-v-shipped"></a><a id="p4e-1b-vi-verify"></a><a id="p4e-1b-vi-f"></a><a id="p4e-1b-vi-close"></a><a id="p4e-1b-vi-close-2"></a><a id="p4e-1b-vi-close-3"></a><a id="p4e-1b-vi-shipped"></a> |
| [§5.P4e-1b-v](phases/CIU_6_P4e-1b-v.md) | 11226–11578 | <a id="p4e-1b-v-b2b"></a><a id="p4e-1b-v-c"></a><a id="p4e-1b-v-b2b-shipped"></a><a id="p4e-1b-v"></a> |
| [§5.P4e-1b sequencing, 1b-iii, 1b-iv](phases/CIU_6_P4e-1b-iii-iv.md) | 11579–12554 | <a id="p4e-1b-sequencing"></a><a id="p4e-1b-iii-c2"></a><a id="p4e-1b-iv-verify"></a><a id="p4e-1b-iv"></a><a id="p4e-1b-iii-c2-r3"></a><a id="p4e-1b-iii-c2-r2-tail"></a><a id="p4e-1b-iii"></a><a id="p4e-1b-iii-a"></a><a id="q-deep-prefix"></a><a id="p4e-1b-iii-audit3"></a> |
| [§5.P4e-2](phases/CIU_6_P4e-2.md) | 12555–12707 | <a id="p4e-2"></a> |
| [§5.PF](phases/CIU_6_PF.md) | 12708–12761 | <a id="pf"></a> |
| [§5.P5](phases/CIU_6_P5.md) | 12762–12775 | <a id="p5"></a> |
| [§5.PX](phases/CIU_6_PX.md) | 12776–12785 | <a id="px"></a> |
| [§5.P6](phases/CIU_6_P6.md) | 12786–12814 | <a id="p6"></a> |
| [§5.X](phases/CIU_6_X.md) | 12815–12828 | <a id="x-close"></a> |

<a id="sq8-moved"></a>

## §Q8 The lexical grammar (normative) and §3 the decision ledger — their own documents

- **§Q8**, owner-reviewed 2026-07-28 and normative: [`2026-07-28_CIU_6_D4_LEXICAL_GRAMMAR.md`](2026-07-28_CIU_6_D4_LEXICAL_GRAMMAR.md). Stubs: <a id="q8"></a><a id="q8-1"></a><a id="q8-2"></a><a id="q8-3"></a><a id="q8-4"></a><a id="q8-5"></a>
- **§3**, the decision ledger (Q_L … Q_U63): [`2026-07-28_CIU_6_D4_DECISION_LEDGER.md`](2026-07-28_CIU_6_D4_DECISION_LEDGER.md). Stubs: <a id="s3"></a><a id="q-l1"></a><a id="q-l2"></a><a id="q-l3"></a><a id="q-l4"></a><a id="q-l5"></a><a id="q-l6"></a><a id="q-m1"></a><a id="q-m2"></a><a id="q-m3"></a><a id="q-m4"></a><a id="q-m5"></a><a id="q-m6"></a><a id="q-m7"></a><a id="q-m8"></a><a id="q-r1"></a><a id="q-r2"></a><a id="q-r3"></a><a id="q-r4"></a><a id="q-r5"></a><a id="q-r6"></a><a id="q-t3"></a><a id="q-t4a"></a><a id="q-t4b"></a><a id="q-t4b-prime"></a><a id="q-t7"></a><a id="q-t8"></a><a id="q-t6"></a><a id="q-t1"></a><a id="q-t2"></a><a id="q-t5"></a><a id="q-u1"></a><a id="q-t2-adaptation"></a><a id="q-u2"></a><a id="q-u3"></a><a id="q-u4"></a><a id="q-u5"></a><a id="q-u6"></a><a id="q-u7"></a><a id="q-u8"></a><a id="q-u9"></a><a id="q-u10"></a><a id="q-u11"></a><a id="q-u12"></a><a id="q-u16"></a><a id="q-u16b"></a><a id="q-u17"></a><a id="q-u18"></a><a id="q-u19"></a><a id="q-u20"></a><a id="q-u22"></a><a id="q-u23"></a><a id="q-u24"></a><a id="q-u25"></a><a id="q-u26"></a><a id="q-u27"></a><a id="q-u28"></a><a id="q-u29"></a><a id="q-u30"></a><a id="q-u31"></a><a id="q-u32"></a><a id="q-u33"></a><a id="q-u34"></a><a id="q-u35"></a><a id="q-u36"></a><a id="q-u37"></a><a id="q-u38"></a><a id="q-u39"></a><a id="q-u40"></a><a id="q-u41"></a><a id="q-u42"></a><a id="q-u44"></a><a id="q-u45"></a><a id="q-u46"></a><a id="q-u47"></a><a id="q-u48"></a><a id="q-u49"></a><a id="q-u50"></a><a id="q-u51"></a><a id="q-u52"></a><a id="q-u53"></a><a id="q-u54"></a><a id="q-u55"></a><a id="q-u56"></a><a id="q-u57"></a><a id="q-u58"></a><a id="q-u59"></a><a id="q-u60"></a><a id="q-u61"></a><a id="q-u62"></a><a id="q-u62-critique"></a><a id="q-u62-r"></a><a id="q-u62-dc"></a><a id="q-u63"></a><a id="q-u63-worked"></a><a id="q-u63-jc"></a><a id="q-u43"></a><a id="star-census"></a>

<a id="s6"></a>

## §6 SRE lattice lens (the six questions, run against the ADAPTED surface)

1. **Classification**: STRUCTURAL. The result carrier is **row × presence ×
   tail** — a labelled product of per-field VALUE lattices, indexed by a
   support set, a key-domain ∈ {keyword, nat}, presence marks
   (`record-field (type presence)` — the S-lens-declared presence lattice,
   `syntax.rkt:665-687`), and a tail ∈ {closed, dyn}. NEITHER source document
   named presence/tail; this declaration closes that gap.
2. **Algebraic properties**: per-field flat lattices; support = powerset;
   the GRADE set {1, ω} composes by multiplication with ω absorbing — a
   (deliberately tiny) commutative monoid that the spec's interval refinement
   ([1,1]/[0,1]/[0,ω]/[1,ω]) would grow toward the QTT semiring already
   in-tree (m0/m1/mw). v1 claims only the monoid; the semiring alignment is
   OUTLOOK and the lens re-runs when 0|1 arrives.
3. **Bridges**: keyword-selection → source row is the D21 Galois pair
   (projection α, width-subsumption γ) — carried from the old §6. The nat
   edge remains relabelling WITHOUT an adjoint (dense-prefix forbids the
   sparse γ; the old D3-S8 finding stands). NEW: the 2b split adds the
   union-component bridge (flatten-union → per-component record-project,
   all-must-offer polarity).
4. **Composition**: result shapes = grade-interpreted shape functors composed
   along the path (spec §5.2); `*` deletes exactly one vector layer — the one
   deliberate join in an otherwise functorial language (the spec's own
   framing; the lens flags it as the single place associativity of shape
   composition must be test-pinned, L1×L2 interaction).
5. **Primary vs derived**: the SOURCE row is primary; every selection result
   is DERIVED (recomputable). A selection must never become the sole carrier
   of a fact — this is what makes the read-only v1 safe and what the write
   direction (spec §7.7) will have to revisit.
6. **Hasse / parallel decomposition**: N sibling branches of a block are N
   independently-computable projections joined at assembly (the flatten and
   path-keyed shapes remain the all-at-once forms). Under strict merge the
   join is trivially disjoint; Ruling B (P5) makes the join partial — its
   case analysis IS the answer to "where is the join defined."

**~~OPEN~~ RULED (Batch 4 = ruling 4d; further refined for BLOCKS by Q_T2's
D-lenient rule): dyn-tail semantics** — what `.*`
row-splat and map-generic `:` mean over a row whose tail is `dyn` (unknown
support). The old surface's SUPPORT-BOUNDEDNESS principle (D3-M5, survived)
says splat needs a bounded support; `(Map K V)` uniform broadcast needs no
per-field row at all. Ruled in Batch 4.

**NTT posture**: v1 adds zero propagators/cells — ratified twice (predecessor
§7; D3-M2 refutation). The deferral is now NAMED with a TRIGGER (§9 gate row
3): the broadcast-propagator node track opens on X.close perf pressure or
F-row, whichever first, with its NTT model mandatory.

<a id="s8"></a>

## §8 Risks (carried forward + new — the D5 critique's ⑤)

- **R2 (walker gaps)** — carried: every walker touching the NEW nodes (block,
  `^` continuations, broadcast steps) defaults to the generic
  transparent-struct rebuild (three in-tree templates: the SUB.1 tripwire,
  `re-abstract`, `narrow-subst-bvars`); explicit arms only for binders + hot
  paths, hot arms carrying a differential-oracle contract test.
- **R3 (`.` on duty N)** — ⚠ **STALE, corrected 2026-07-29**: this said
  QUADRUPLE and listed `.*`, which **P1a RETIRED**. §Q8.1 (normative) is the
  single source: the band is **SIX** members plus two non-band duties, and the
  OPPOSING digit-anchored family is six recognizers, not one. Two
  contradictory statements in one document is the shape Q_M7 was struck to
  prevent — so this row now POINTS at §Q8.1 rather than restating it.
  Both-modes census per `prologos-syntax.md` § Reader still applies.
- **R4 (a green suite proves nothing for this class)** — carried verbatim:
  failing-test-first for anything walker- or seam-shaped; the D5 critique's
  three live probes (permissive `expr-broadcast-get`, the `:=` layout defect,
  the loose-`.{` shatter) all sat under a green suite.
- **R5 (NEW — carrier drift)**: the spec's idealized carriers vs HEAD's
  (§2.3). Any §10 corpus divergence must be classified NOTATION vs SEMANTICS
  before resolution (ruling Batch 1); a "quick fix" that edits a marker
  without the classification re-opens the D5 blockers.
- **R6 (pipeline cost honesty — ⚠ CORRECTED 2026-07-29, P3 audit)**: new AST
  nodes pay pipeline.md in FULL — including `pnet-serialize` registration and
  the D3-M2 item-13 deliberate `#f` typing-propagators registration — **but
  NOT an automatic `PNET_VERSION` bump**. The earlier text asserted the bump
  and instructed promoting it into pipeline.md at X.close, which would have
  propagated a FALSE obligation into the ambient rules tier. Verified: the
  tag table is SYMBOL-keyed on `struct->vector`'s tag, so registering a new
  struct is purely additive (no pre-existing cache can contain the new tag),
  and `pnet-stale?` already invalidates on `infrastructure-stale?` (any
  driver `.zo` rebuild) plus a source hash. A bump is owed only when an
  EXISTING shape's serialization changes (P1a's own precedent: no bump,
  "symbol-keyed tag table + a zero-hit cache census"). The constructor-arity
  hazard (compiles CLEAN cross-module; discovery is patterns-at-build +
  constructors-at-runtime) belongs to pipeline.md § New STRUCT FIELD — it
  bites the cheaper-looking variant of ADDING A FIELD to a shipped node,
  which is exactly the variant this row previously could not reject on
  principle because it never named it.

<a id="s9"></a>

## §9 Principles gate (two columns — catalogue ‖ challenge)

| Decision | Catalogue (passes?) | Challenge (could it be MORE aligned?) |
|---|---|---|
| Strict merge first (§3.6 waypoint) | Monotone: errors may become meanings, never the reverse. CALM-adjacent staging. | Challenged and KEPT: the alternative (Ruling B at P3) front-loads spine identity before broadcasts exist to have spines. The waypoint is sequencing, not scaffolding — no dual path exists at any moment. |
| `v[0]` retention beside `.N` | Owner-ruled 2026-07-28. | Challenged: is it belt-and-suspenders? NO — two SURFACES over ONE mechanism (`(get expr N)`); the D5 verifier refuted the dual-path framing. Residue: an X.close revisit trigger is named (retire, document as `get` sugar, or keep). |
| Zero-propagator v1 (§5.P4) | Ratified twice (predecessor §7; D3 critique M2 refutation — the Check asks what the track ADDS). | **Challenged and CHANGED**: "the future NTT-modeled track" had no name and no trigger — the ban-"pragmatic" rule demands specificity. Now: **deferred to the broadcast-propagator node track (CIU, post-v1), TRIGGERED by either (a) selection-perf pressure at the X.close bench matrix or (b) F-row landing** — whichever first; the NTT model is mandatory at that opening. |
| Projection-by-default flips by enclosure (spec §1.2: the same path text means block-projection inside `{…}`, extraction outside) | The spec's own per-step discipline; consistent with copattern reading. | Challenged and KEPT with an obligation: this is the surface's largest learnability bet; the corpus MUST pin the pair (`x.a.b` vs `x{a.b}`) side by side so the flip is documented by executable example — ⚠ **assigned to NO PHASE until 2026-07-29** (found by the P2 audit): **P2 lands the `x.a.b` half; P3 OWNS THE PAIR**, and neither test delta had named it, and the P3 error for the common confusion (a bare path where a block was meant) names the other spelling. |
| Demand semantics staged (P6) | Honest: the collision is priced, not hidden. | Challenged: is staging an ADOPTED element a "validated-not-deployed" shape? Resolution = Batch-4 ruling: amend the spec tag to [ADOPTED — staged] + an X.close gate row, or commit v1. The gate row is the tripwire either way. |

<a id="s10"></a>

## §10 References



<a id="d4-line-map"></a>

## §11 Where D4's lines went (the split of 2026-11-06, from D4 at `3e76762d`)

A citation of a D4 line from before the split (`D4:NNNN`) resolves here: find the range, then add the offset.

| D4 lines (before) | Now in | New line |
|---|---|---|
| 1–19 (header) | this file | N+0 |
| 20–197 (Progress Tracker) | this file | N+6 |
| 198–4232 (§3 decision ledger) | [2026-07-28_CIU_6_D4_DECISION_LEDGER.md](2026-07-28_CIU_6_D4_DECISION_LEDGER.md) | N-191 |
| 4233–4259 (§4) | this file | N-4029 |
| 4260–4263 (§5 header) | this file | N-4029 |
| 4264–4309 (§5.P0) | [CIU_6_P0.md](phases/CIU_6_P0.md) | N-4257 |
| 4310–4698 (§5.P1 … P1b-i) | [CIU_6_P1.md](phases/CIU_6_P1.md) | N-4303 |
| 4699–4975 (§Q8) | [2026-07-28_CIU_6_D4_LEXICAL_GRAMMAR.md](2026-07-28_CIU_6_D4_LEXICAL_GRAMMAR.md) | N-4692 |
| 4976–5475 (§5.P1b-ii … P1b (superseded framing)) | [CIU_6_P1.md](phases/CIU_6_P1.md) | N-4577 |
| 5476–5744 (§5.P2) | [CIU_6_P2.md](phases/CIU_6_P2.md) | N-5469 |
| 5745–6104 (§5.P3) | [CIU_6_P3.md](phases/CIU_6_P3.md) | N-5738 |
| 6105–6376 (§5.P4 (co-design, partition, pause)) | [CIU_6_P4.md](phases/CIU_6_P4.md) | N-6098 |
| 6377–6596 (§5.P4a) | [CIU_6_P4a.md](phases/CIU_6_P4a.md) | N-6370 |
| 6597–7337 (§5.P4b) | [CIU_6_P4b.md](phases/CIU_6_P4b.md) | N-6590 |
| 7338–8632 (§5.P4c) | [CIU_6_P4c.md](phases/CIU_6_P4c.md) | N-7331 |
| 8633–9430 (§5.P4d-0 + §5.P4d) | [CIU_6_P4d.md](phases/CIU_6_P4d.md) | N-8626 |
| 9431–9764 (§5.P4e-0) | [CIU_6_P4e-0.md](phases/CIU_6_P4e-0.md) | N-9424 |
| 9765–10213 (§5.P4e-1 + 1a + 1b) | [CIU_6_P4e-1.md](phases/CIU_6_P4e-1.md) | N-9758 |
| 10214–11225 (§5.P4e-1b-vi) | [CIU_6_P4e-1b-vi.md](phases/CIU_6_P4e-1b-vi.md) | N-10207 |
| 11226–11578 (§5.P4e-1b-v) | [CIU_6_P4e-1b-v.md](phases/CIU_6_P4e-1b-v.md) | N-11219 |
| 11579–12554 (§5.P4e-1b sequencing, 1b-iii, 1b-iv) | [CIU_6_P4e-1b-iii-iv.md](phases/CIU_6_P4e-1b-iii-iv.md) | N-11572 |
| 12555–12707 (§5.P4e-2) | [CIU_6_P4e-2.md](phases/CIU_6_P4e-2.md) | N-12548 |
| 12708–12761 (§5.PF) | [CIU_6_PF.md](phases/CIU_6_PF.md) | N-12701 |
| 12762–12775 (§5.P5) | [CIU_6_P5.md](phases/CIU_6_P5.md) | N-12755 |
| 12776–12785 (§5.PX) | [CIU_6_PX.md](phases/CIU_6_PX.md) | N-12769 |
| 12786–12814 (§5.P6) | [CIU_6_P6.md](phases/CIU_6_P6.md) | N-12779 |
| 12815–12828 (§5.X) | [CIU_6_X.md](phases/CIU_6_X.md) | N-12808 |
| 12829–12936 (§6 … §10) | this file | N-12561 |
| 12937–13081 (§5.P4d-s7) | [CIU_6_P4d.md](phases/CIU_6_P4d.md) | N-12129 |
