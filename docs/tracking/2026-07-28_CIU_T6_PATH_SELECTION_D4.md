# CIU Track 6 — Path Selection **D4** (implementation design over the 2026-07-28 spec)

**Status**: D4 DRAFT — the redesign intake. The normative SURFACE is the spec:
[`docs/research/2026-07-28_path-selection-spec.md`](../research/2026-07-28_path-selection-spec.md)
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

---

## Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| **P0** | **Acceptance corpus** — augment the EXISTING acceptance file with the spec §10 examples + Appendix fixtures; `--check` gated; new forms commented until their phase lands | ✅ | [§5.P0](#p0) · `e2674208` — 28/28 markers, 0 errors; all 7 fixtures load (layout via `def X`, issue #80 sidestepped); corpus phase-tagged in HEAD notation; carrier pins double as [§2.3](#s2-3) docs |
| **P1a** | **Retirement batch + substrate** — dot-key family · the FULL `broadcast-get` chain (reader + parser keyword + surf + elaborator + node) · `m[:kw]` · reject batch · `surface-rewrite.rkt` `dot-lbrace` cleanup (BEFORE any re-mint) · the marker-form diagnostic seat | ✅ | [§5.P1a](#p1a) · **`859b529d`** — suite 9253/474/0, acceptance 28/28 + 89/89, −744/+320; adversarial verify found 2 whole-file-abort defects (1 MINE, in the seat) → fixed + pinned pre-commit |
| **P1b-i** | **Repairs + probes + the Q8 DRAFT** — the top-level `<` swallow fix (Q_M4) · WS narrowing typed vars · `def ?x` reservation (Q_M3) · the Q_M1 gating probe + `:N` / keyword-`*` / `:<` · **Q8 written from the results** | ✅ | [§5.P1b-i](#p1b-i) + **[§Q8](#q8)** · `fc65ca54` — suite 9263/474/0, corpus A/B 160 files / 2 intended diffs; **Q8 owner-reviewed ✅ 2026-07-28, amended by [Q_M8](#q-m8)** (ordinals multi-digit in both bands) |
| **P1b-ii** | **The `.{` opener** — `dot-lbrace` re-mint across **EIGHT** edit regions (not six) incl. the surviving `surface-rewrite.rkt:516` POSITIVE addition; plain `'rbrace` closer (Q_M5); new `$dot-brace` sentinel + `dot-brace-group` tag + tree-parser arm (Q_N1); the Q_N3 two-grouper agreement guard | ✅ | [§5.P1b-ii](#p1b-ii) · **`1a1091d4`** — suite **9279/474/0**, acceptance 28/28 + 89/89, corpus A/B **158 files / 1 intended diff**; adversarial verify caught a **BLOCKING regression I introduced** (`$dot-brace` missing from `pattern-var?` → whole-file abort in a defmacro template) — fixed + pinned pre-commit |
| **P1b-iii** | **Brace adjacency + the head registry + Q_M8** — the forced `$select-brace` sentinel (Q_M6) · the `reader-forms.rkt` leaf registry · adjacency in BOTH groupers (Q_N7) · bucket 4 ruled SELECT (Q_N5) · the `:N` digit-run widening + the structural `fused-type-annot?` repair (Q_N4) · P1b-ii's residual CLOSED | ✅ | [§5.P1b-iii](#p1b-iii) · **`a6af2761`** — suite **9304/474/0**, acceptance 28/28 + 89/89, corpus A/B **158 files / ZERO diffs**; adversarial verify caught **3 BLOCKING** (one non-idempotent fold → a silently-dropped `defn` clause) + 10 SIGNIFICANT — all fixed or filed pre-commit |
| **P2** | **Grade-1 core** — `.k`/`.N` access + bare-path extraction. Carries **Q_M8's dot half** (`digit+` at the dot). Ruled at the mini-audit: **`.N` REUSES `$postfix-index`** (Q_R1 — near-zero registrations, fixpoint inherited, `v[0]` ≡ `v.0` byte-identical) · **copy the `:N` trailing guard** (Q_R2) · **dot band stays adjacency-free** (Q_R3) · `m.0` moves out of the v2 block (Q_R4) · **the `.N` error surface IS IN SCOPE** (Q_R5) | ✅ | [§5.P2](#p2) · **`3005170b`** — suite **9370/475/0**, acceptance **35/35** + 89/89, corpus A/B **158 files / ZERO diffs**; audit `wf_22020418-a5f` (**12th** consecutive premise refuted); doc-truth separately `0e5a56a3` ([Q_R6](#q-r6)); adversarial verify caught **a diagnostic REGRESSION I introduced** + 2 more, all fixed pre-commit; DEFERRED 9–13 |
| **P3a** | **The node + KEYED blocks, no `^`** — `surf-select`/`expr-select` (full pipeline.md cost paid once; twins; walkers via the generic fallback; NO PNET bump) · payload segmentation + the malformed-payload seat · **D-lenient presence** (Q_T2) · subject-once reduction · **strict merge for plain keys BEFORE `make-record` can last-win** · type-position refusal · branch-aware miss errors · §9's learnability pair | ✅ | [§5.P3a](#p3a) · **`290f77f9`** — suite **9418/475/0**, acceptance **41/41** + records, battery 136/136, neighborhood 623/21; [Q_U1](#q-u1) (corpus list corrected, `6d919142`); adversarial verify caught **1 BLOCKING** (block-pipe select corruption at 0 errors — 6th consecutive slice) + 3 SIGNIFICANT, all fixed pre-commit; DEFERRED 15–20 |
| **P3b** | **The `^` family** — the ONE splitter (continuation grammar `-`?·{ε\|label\|`_`} + `^..`) · dissolve/splice · in-place rename · `^_` Reading N · the `^-` collapse family ([Q_T7](#q-t7)) · `^..` ([Q_T8](#q-t8)) · **output-level-local merge** ([Q_T3](#q-t3), the monotonicity pin) · the [Q_T4a](#q-t4a) ordinal-`^` guided error · the malformed-`^` battery | ✅ | §5.P3b · **`36ce601c`** — suite **9469/475/0**, acceptance **50/50** + records, battery 178; light re-grounding only (per Q_T5); adversarial verify caught **1 BLOCKING** (whole-datum ordinal-rekey marker → match-arm whole-file abort; fixed ELEMENT-WISE) + 8 SIGNIFICANT — all fixed pre-commit; DEFERRED 21–22; Q_U4 candidate flagged (sub-block synth scope) |
| **P3c** | **Keyless + L4 + honest nesting** — the nat-row mint at EVERY n (incl. 1 and homogeneous n) · ordinal branches `{N M}` · the L4 mixing error · `⟨String⟩` 1-tuple pins · the G11 one-space pair pinned side by side | ✅ | [§5.P3c](#p3c) · **`1b021d57`** — suite **9497/475/0**, acceptance **52/52**, battery 206; P3 (BLOCKS) COMPLETE; the verify's FIRST no-BLOCKING slice in eight (2 SIGNIFICANT fixed pre-commit: the @ord walk-to-leaf twin-drift, the decimal-fusion leak); G11 landed AS AMENDED; in-block `v[0]`≡`.0` ratified-by-pin |
| **P4** | **Broadcast ω** — ⭐ **P4a ✅ · P4b ✅ COMPLETE** (b-i carrier + b-ii `$dot-access` migration; `x.a` now mints the unified selector carrier) · P4c–P4e ⬜ — `:s` one-step extent, L1 fusion, **map-generic `:`** (Q1 ✅), `*` flatten, `.*` row-splat, **the 2b HETEROGENEITY SPLIT** (per-position exact over tuples; keys-⋂/types-⋃ over PVec-of-union = NEW row-meet machinery) · **disclose `<`/`:<` (Q5 ✅ v1)** · dyn-tail = support-bounded (4d) | 🔄 | [§5.P4](#p4) · co-design: audit `wf_8458c23b` + options panel · **RULED 2026-07-31**: [Q_U5](#q-u5) · [Q_U6](#q-u6) · [Q_U7](#q-u7) · [Q_U8](#q-u8) · [Q_U9](#q-u9) (the PAUSE cleared) · partition LOCKED P4a–P4e |
| **P4a** | **Totality + strategy-independent repairs** (no new surface) — the `select-step-kind` classifier routed through **THIRTEEN** dispatch sites in **FIVE** files (the design said 4, the first census said 8; the adversarial verify found 5 more, incl. two LEAF classifiers that run UPSTREAM of the guards and a render site the identifier-grep structurally could not see) · the whole-node-abort fixtures · the `select-reduce` subject re-whnf hoist (a CONTRACT fix — measured no perf delta) · the `whnf-trivial?` container-VALUE arms (1822 ns/call, 9.5×, by interleaved microbench; ≈−0.1% of wall) · the P2 bench baseline ESTABLISHED (none had ever been recorded) | ✅ | [§5.P4a](#p4a) · battery 204 → **224** |
| **P4c** | **The `:` gate + the ω wrapper + PVec broadcast** — ⭐ **Q_U16 RULED** (Q_U8 was NOT implementable; the binder unwrap moves to the reader post-pass, so the mint stays uniform and BOTH surfaces survive) · **Q_U16b**: `users:0` IS a legal ω step | 🔄 | [§5.P4c](#p4c) · P4c-1 ✅ `182f1678` · P4c-2 ✅ `68cdaae7` ([inverted default](#p4c-2-inverted)) · [P4c-3](#p4c-3) ✅ `d477772c` · [P4c-4a](#p4c-4a) ✅ `f31237fd` · [P4c-4b](#p4c-4b) ✅ `6b22515d` (end to end) · **[P4c-4c](#p4c-4c-close) ✅ `ae26f540`** — broadcast is REACHABLE: PVec ω value semantics + **G2** + the preparse seam guard. ⭐ The verify caught a BLOCKING whole-file abort every gate was blind to; owner ruled the structural fix ([close](#p4c-4c-close)) · [Q_U18](#q-u18) ✅ · DEFERRED 43 ✅ · 48 RULED uniform · P4c-5 ⬜ |
| **P4d** | **The carriers** — Map/keyword-row (TWO typing arms: keyword-row `expr-Record` + genuine `expr-Map`; ONE new champ reduction arm, atomic with typing) · het tuple (TYPING-ONLY — same `expr-rrb` runtime as PVec) · PVec-of-union + `row-meet` (NEW machinery + an AUTHORED fixture) · the Q_U9 refusal's message split · corpus re-fate · **Q_U19 ✅ RULED (A)** at the opening | 🔄 | [§5.P4d](#p4d) · opened 2026-08-07: audit `wf_4bc76d94-a2d` (6 facets + critic; found a LIVE order-dependent soundness hole — `unify.rkt` Record↔Map coercion read as equality — and the Q_U9 Functor census FALSE-when-made) · slicing under co-design |
| **PF** | **Path first-classness** (substrate; **P5's prerequisite**) — ⭐ **Q_U17 RULED B2**: a Path segment is a first-class `Step` value. Reify the closed six-kind union as a `data Step` ADT on the `Datum` pattern; `Path` stays GROUND; `segments : Path -> [List Step]`. Repairs the dead `path-segments` in the SAME change | ⬜ | [§5.PF](#pf) · [Q_U17](#q-u17) · panel `wf_68178bd3-eea` |
| **P5** | **Ruling B + factoring** — B2 keywise / B3 same-spine merge, L2 normal form, guided errors printing the factored spelling | ⬜ | [§5.P5](#p5) · L1–L5 law battery · ⚠ B3 needs [PF](#pf) |
| **PX** | **Binder-seam substrate** (carried, surface-independent) — the lambda-adoption hole + the standalone-def seam | ⬜ | [§5.PX](#px) · position flexible |
| **P6** | **Demand semantics** — RULED STAGED (4a); **decision ✅ Q_U3 (owner, 2026-07-30): option (c)** — deferred to a named post-v1 phase, charter stub in §5.P6 | ⬜ (residue = the X.close gate row only) | [§5.P6](#p6) |
| **X.close** | **MANDATORY** — bench matrix · DEFERRED triage · doc-truth sweep · memory fold · **Stage-5 PIR** | ⬜ | [§5.X](#x-close) · the track does not flip ✅ without the PIR |

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

<a id="s3"></a>

## §3 Rulings ledger

**The spec's standing [owner, 2026-07-28]**: the spec was formed OUTSIDE the
project, idealized — it is a **suggestion and guide, not a prescription**;
adaptation to grounded code reality is expected. Where D4 adapts, the
adaptation is recorded here with its reason.

**Adopted [owner, 2026-07-28]:**
- The spec's **[ADOPTED]** elements are normative for v1 *as adapted below*.
- **Q1 = YES**: map-generic `:` (spec §3.2.3 + §5.4 row-map typing). With it:
  path-position `.*` is subsumed; `.*name`'s migration target is **`:name`**.
- **`v[0]` keeps its current working semantics for now** — the PS2 flip is
  canceled; no census-flip of `v[literal]` sites.

**The D5-critique batch rulings [owner, 2026-07-28]** — note: the "D5 critique"
was a 13-agent adversarial workflow (`wf_2cef0199-18a`, 6 lenses +
refute-by-default verifiers) adjudicated conversationally; it has **no
standalone document**. Its surviving, R-lens-verified findings are recorded in
§2.3 (the carrier table), the rulings below, and §8 (risks):
- **Notation = translation, not spec-editing (Batch 1, option b).** The spec
  keeps its idealized notation; the CORPUS FILE is the adaptation layer,
  written in HEAD's printed forms via the §2.3 translation table. §5.P0's
  normativity protocol is refined: divergence in NOTATION is transcription
  (resolved by the table); divergence in RESULT is semantics (resolved by
  ruling). Fixtures normalize to the `def X` implicit-map form (the
  `def X :=` layout defect is filed — **issue #80** + DEFERRED) and carry
  `defn now`/`defn env` stubs with indicative values.
- **2a — HONEST NESTING ADOPTED (spec §3.3 as written).** A keyless block is
  an n-tuple at every n, including n = 1. Owner rationale: implicit splice
  would break the algebraic properties of path selections; **the disclose
  operator `<`/`:<` is DESIGNED as the unwrap remedy** for wanting the bare
  value (a strong signal on spec Q5 — see the open list). Code reality
  AGREES once seen at the right layer: the tuple carrier is a nat-keyed
  closed record (1-field rows representable; runtime rep = `expr-rrb`, the
  same carrier the landed P2 substrate projects from) — only the LITERAL
  inference arm collapses n=1 to PVec, and selection never routes through
  the literal arm. The block constructor mints nat-rows directly.
- **2b — THE HETEROGENEITY SPLIT ADOPTED.** Spec §5.3's single meet rule is
  adapted per-carrier, because HEAD has TWO het carriers:
  · **Het tuple** (`⟨row₁ row₂ …⟩`, positions statically known — what `@[…]`
    literals produce): broadcast projects **per-position, exactly** — no
    meet needed, and a miss errors NAMING THE POSITION. Strictly stronger
    than the spec's rule where it applies.
  · **PVec-of-union** (`[PVec <A|B>]`, length unknown): the spec's rule,
    restated over UNION COMPONENTS — every component must offer the key
    (keys ⋂), result field type = ⋃. NEW machinery, small, booked at §5.P4.
  · **Polarity note (write it down or it becomes a bug)**: the in-tree union
    projection arm is filter-on-miss (optimistic) and is CORRECT for what it
    serves — a single get on one union-typed value, which IS one branch.
    Broadcast projects EVERY element, so all-must-offer is the sound
    polarity there. Two operations, two polarities, no conflict.
- **2c — Q2 DISSOLVED, off the critical path.** Q2-type: CLOSED by landed
  code (type rows canonically sorted — load-bearing for `equal?`-as-row-
  identity, `syntax.rkt:749-756`, not churnable). Q2-value: **carrier-
  determined (champ) order — DERIVED FROM THE SPEC'S OWN KEY-SORT THESIS**,
  not conceded to the implementation: §1.1 says nominal keys' identity
  carries the meaning and their order does not, so selection-order display
  would contradict the spec's foundation. Corpus markers transcribe to champ
  order (deterministic per key set). §5.P3's gate is REMOVED.

**The Batch-3/4 rulings [owner, 2026-07-28 — all as recommended]:**
- **3a — `.{` ADOPTED** as the mid-path sub-block: a `dot-lbrace` compound
  token at the dot band (the `dot-lparen` precedent; prefix-disjoint; P1 owns
  the THREE-layer opener co-update). `.` uniformly means DESCEND.
- **3b — brace adjacency with HEAD-SYMBOL PRECEDENCE**: known reader-form
  heads (`racket{…}`, future language ids) recognized BEFORE the select-block
  rule; spaced `{…}` is never a block. P1 census = three buckets (spaced ·
  adjacent reader-form head · adjacent select-block); the 10 FFI sites +
  `test-foreign-block.rkt` become round-trip pins; guiding diagnostic on
  selecting from a reader-form head.
- **3c — multi-digit `:N`: lean keyword-index token, DECIDED BY PROBE at
  P1's Q8 review** (`{:10 v}` probe + both-modes `:digits` census).
- **3d — colon seam resolved by POSITION**: broadcast is expression-position
  only; annotation colons live in binder/head contexts. P1 census VERIFIES
  the disjointness (Rel T1 typed-var sites `?x:Int` especially).
- **4a — demand semantics STAGED**: spec §1.3 tag amended to
  [ADOPTED — staged]; an X.close gate row added; lazy leaves = own post-v1
  design (§5.P6). The static half (copattern typing never forces) is true at
  v1 regardless.
- **4b — the STEP-LIST NODE**: one selection node family carrying the step
  list (keys · ordinals · broadcast markers · `^` continuations · blocks ·
  disclose). Typing WALKS the steps (per-position tuple exactness, the union
  meet, grade-layer counting structural — L1 fusion becomes a fact, not a
  rewrite). Reduction LOWERS per step onto shipped machinery (`get`,
  `pvec-map`, `map-map-vals`). `expr-broadcast-get` RETIRES with `.*name`
  rather than being repaired. The P3 mini-audit prices the struct before code.
- **4c — row-map typing PER-FIELD in v1**: broadcast bodies are selector
  steps, not arbitrary terms — per-field is cheap; the weakening arrives
  (explicitly) with first-class selectors. The `def := [map-map-vals …]`
  qtt lying-diagnostic (pre-existing) gets a P4 probe.
- **4d — dyn-tail: SUPPORT-BOUNDEDNESS carries** (the old surface's surviving
  D3-M5 principle): closed row → per-field · `(Map K V)` → uniform V→V′ ·
  dyn tail → loud static error naming the remedies (seal / validate /
  annotate).
- **Q5 — DISCLOSE `<` ADOPTED IN v1 [owner]**, bare form, spelled `:<` in
  broadcast composition; lands at P4 (in-step). ⚠ P1 grammar obligation:
  `<` is a WS angle-group opener (the mixfix-swallow family) — `users:<{…}`
  gets a mandatory probe row in Q8.
- **Q4** — `*` stays vector-only in v1 (spec's own answer). **Q6/Q7** — moot
  under P3's strict waypoint; deferred to P5's mini-audit.

**The P1-opening ruling [owner, 2026-07-28]:**
- **THE `.*name` MIGRATION GAP IS ACCEPTED, DELIBERATELY.** Ruling Q1 makes
  `.*name`'s migration target `:name`, which does not land until **P4** — so
  retiring the surface at P1 leaves its live sites broken for three phases.
  The alternative considered and **REJECTED** was migrating those sites to a
  working spelling now (e.g. `[map [fn [r] r.x] …]`). Owner rationale: *"my
  concern with migrating is that we'll also forget to migrate back; at least
  the gap creates noise along the way until it is fixed."* The breakage is
  therefore a deliberate **reminder instrument**, not debt — it is the thing
  that makes P4 unforgettable. Two obligations follow, both on §5.P1:
  (a) the audit must confirm the file(s) carrying those sites are **NOT
  suite- or acceptance-GATED** — accepted noise and a red suite are different
  things, and if they ARE gated the ruling needs revisiting; (b) the breakage
  must be **per-command and non-fatal** (the `d18648f0` precedent: a retired
  form yields a generic per-command error and the file CONTINUES), never the
  raw-Racket-abort shape `.{` had before its retirement.

**The P1 mini-audit rulings [owner, 2026-07-28]** (audit `wf_789e4f0f-f02`, 7
facets + completeness critic @ `5c171caa`, all load-bearing findings
main-session R-lens-verified; full findings in §5.P1):

- <a id="q-l1"></a>**Q_L1 — colon seam: the `?`-PREFIX DISCRIMINATOR adopted; the WS repair is
  SCOPED IN.** Ruling 3d's position-disjointness is **REFUTED at HEAD**:
  narrowing-query typed logic vars (`[add ?x:Nat ?y:Nat] = 5N` — 6 live sites,
  consumer `narrow-var-constraints` parser.rkt:6871) are `ident:Ident`
  annotations in EXPRESSION position, a different subsystem from POL.6.
  Resolution: broadcast never claims a `?`-headed subject — the discriminator
  already exists in the surface. Rider: that surface is ALREADY silently
  broken in WS (the splitter runs on a glued symbol only the sexp reader
  produces; the sole WS test is VACUOUS — passes on substring "x"), so P1b
  repairs it, else P1 cannot tell new breakage from old.
- <a id="q-l2"></a>**Q_L2 — the WS-vs-sexp `.{` divergence is INSTITUTIONALIZED** (the POL.9
  precedent): sexp `.{` = selection-path fan-out (15 live test sites,
  parser.rkt:3481) STAYS; WS `.{` = the mid-path sub-block (ruling 3a).
  Documented eyes-open; convergence belongs to the future sexp phase (§2.4).
- <a id="q-l3"></a>**Q_L3 — `broadcast-get` retires as the FULL CHAIN at P1a**: reader token +
  parser keyword (parser.rkt:146, arm :2332-2350) + surf struct
  (surface-syntax.rkt:251/:894) + elaborator arm (:2394) + the expr node +
  its 2 walker-safety pins. Census: the keyword form has **ZERO live users**
  — this is dead-API removal, not capability retirement. Basis: ban-dual-paths
  (keeping it beside P4's `:` is two mechanisms for one operation);
  "partial retirement" is a red-flag phrase; and the audit itself proved
  partial retirements rot (`d18648f0`'s surviving surface-rewrite leg).
  Completeness-over-deferral: no unbuilt dependency exists, so no deferral is
  licensed.
- <a id="q-l4"></a>**Q_L4 — the diagnostic seat is BUILT at P1a**: reader emits a retirement
  MARKER FORM; preparse converts it to a per-command **`parse-error` VALUE**.
  Prior art: `$mixfix-retired` (deleted `d18648f0`) proves the marker
  mechanism end-to-end; its flaw was RAISING (`expand-mixfix-retired` called
  `error`) — which is exactly why audit-09 aborted with zero output. The
  named tilde template is probe-proven a WHOLE-FILE ABORT (structural: the
  reader tokenizes the entire file before any command runs, driver.rkt:2226),
  which would contradict the accepted-gap ruling's own premise (noise, not
  silence) and the spec §3.6/Q8 error-surface obligations.
- <a id="q-l5"></a>**Q_L5 — the working-tree `.[x]` / `.[a.b]` spellings are PRIOR SKETCHING —
  disregard** [owner]. In neither the spec nor D4; all censuses run against
  HEAD (`git show HEAD:<file>`), never the dirty tree (the audit's two
  wrongly-"refuted" counts both measured owner WIP).
- <a id="q-l6"></a>**Q_L6 — P1 SPLITS into P1a (retirements + substrate) / P1b (seams + Q8)**:
  audit-discovered scope (the surface-rewrite cleanup, the reader-form-head
  registry, the diagnostic seat, the 4-site chain, net-new pins) made the
  single phase too large for one gated slice.

**The P1b mini-audit rulings [owner, 2026-07-28]** (audit `wf_d0862784-5e5`, 6
facets + completeness critic @ `bc0c7578`; every load-bearing finding
main-session R-lens-verified; full record in §5.P1b):

- <a id="q-m1"></a>**Q_M1 — `:N` disambiguated by POSITION (option b).** ⚠ The audit's largest
  find: `:0`/`:1`/`:w`/`:m` are NOT unclaimed lexical space — they are the
  **QTT multiplicity vocabulary** (`recognize-colon-annotation`,
  parse-reader.rkt:847-860), consumed at 18 sites across
  parser/macros/driver/tree-parser. Probe-verified: `users:0` → `(users :0)`
  and `[fn [x :0 Int] x]` → `(fn (x :0 Int) x)` are **the same lexeme**.
  Ruling 3c framed `:N` as a multi-digit question settled by a `{:10 v}`
  probe — that probe cannot see this collision. Resolution: multiplicity
  annotations are binder/param position, broadcast is expression position.
  ⚠ **OBLIGATION, not an assumption**: position-disjointness was ALREADY
  REFUTED ONCE on this seam (ruling 3d, by the narrowing typed-vars). P1b-i's
  FIRST probe hunts expression-position `:0`/`:w`/`:m`; a counterexample
  re-opens Q_M1 before anything is built on it.
- <a id="q-m2"></a>**Q_M2 — P1b SPLITS THREE WAYS** (audit-recommended, owner-approved), with
  an ORDERING CONSTRAINT the design had not stated: **`.{` must be re-minted
  BEFORE or WITH lbrace adjacency**, because `.{` today presents a loose `|.|`
  token whose end-pos abuts the `{`, so adjacency-first would turn every
  in-flight `x.{…}` into a select block anchored on a bare dot.
- <a id="q-m3"></a>**Q_M3 — `def ?x` becomes a GUIDED ERROR.** Q_L1's "the discriminator
  already exists in the surface" is a **namespace RESERVATION we are making**,
  not a property we inherit: `def ?cfg := {:a 1}` is legal at HEAD and
  `?cfg.a` → `1 : Int` at 0 errors (probe-verified). Owner rationale: `?` is a
  **modality** marker (functional narrowing; `defr` logic-var params), so a
  `def` binding was never meant to be one — reserving it costs nothing now and
  prevents the surprise later. No present soundness issue; the reservation is
  prophylactic.
- <a id="q-m4"></a>**Q_M4 — the TOP-LEVEL `<` SWALLOW IS FIXED IN P1b-i [owner]**, not
  documented as a hazard. The audit REFUTED the design's framing: the
  swallower is a bare depth-0 `<`, NOT `:<` — probe-verified, `users<{a}`
  (no colon) and even `def p := 1 < 2` / `def q := 3 > 4` (no colon, no brace)
  collapse into ONE form at **ZERO errors**. Mechanism now pinned:
  `langle-matched?`'s terminating arm is `(and close-type (eq? type
  close-type) …)`, but at top level `close-type` is `#f`, so it can never
  fire and the scan runs to `[(>= i n) #f]` — the end of the whole token
  stream. Fix: **bound the scan at the next top-level form start**; the
  information already exists one domain earlier (`content-line-indices`,
  Domain 2, computed before Domain 4's `make-bracket-depth-rrb`), so this is
  plumbing + a termination arm, not new analysis. Owner: *"This has been an
  issue to fix for a while, and there is a stronger need now than ever
  before."* ⚠ Constraint: multi-line angle groups (`<(x : Int)\n -> Int>`)
  were DELIBERATELY kept working at `31d27c83` — the bound must admit
  CONTINUATION lines while rejecting NEW-FORM lines, and the 15 pins from
  that commit are the gate. If it proves messier than the plumbing suggests,
  STOP and re-checkpoint rather than let the slice swell.
- <a id="q-m5"></a>**Q_M5 — ruling 3a's PRECEDENT is CORRECTED**: the model is **`hash-lbrace`
  (6/6 sites, plain `'rbrace` closer, probe-verified nesting)**, NOT
  `dot-lparen`. Citing dot-lparen silently imported its `'mixfix-rparen`
  sentinel, which exists to carry SEMANTIC MODE, not to disambiguate a
  closer — and a sentinel closer would reproduce the `31d27c83` cross-line
  swallow, because the extent scanner stores REAL token types as frame
  closers (parse-reader.rkt:1311) and `langle-matched?` has no translation
  arm. **`dot-lbrace` uses plain `'rbrace`.** The word "closer" never appeared
  in ruling 3a.
- <a id="q-m6"></a>**Q_M6 — a DISTINCT SENTINEL for the select block is FORCED, not
  preferable.** Adjacency is DESTROYED at the datum layer (probe: `x{a b}`
  and `x {a b}` are byte-identical, as are `racket{42}` / `racket {42}` and
  `spec identity {A : Type}`), so "a fourth fork on `$brace-params`" is not
  implementable by position at all — and `$brace-params` turns out to be
  **≥7-purposed** (map literal · implicit type binders · foreign block ·
  solver config · defproc capability binders · selection path fan-out ·
  foreign-import capability annotations), every fork position-disambiguated.
  ⚠ Constraint: `combine-foreign-blocks` (macros.rkt:2431-2437) has **NO
  adjacency test**, so spaced `racket {code}` is accepted today and is
  back-compat-PINNED — therefore the head-adjacent bucket keeps emitting
  `$brace-params` UNCHANGED and only the non-head-adjacent select block gets
  the new sentinel. Any new sentinel owes `pattern-var?` (macros.rkt:1144+)
  AND tree-parser.rkt's inline skip-list — **P1a's own headline defect
  class**.
- <a id="q-m7"></a>**Q_M7 — the standing `^` ruling is CORRECTED (it was not executable).**
  "`^` splitting is P3-parser-side via POL.6 `split-fused-symbol` — no second
  splitter" names the WRONG primitive: `split-fused-symbol` (parser.rkt:5437)
  splits on `":"`, has two binder-path callers, and REJECTS >2 segments; the
  tree's ONLY `^` splitter is parser.rkt:3543 inside `validate-selection-
  paths` — which is the SEXP-ONLY surface Q_L2 freezes. **P3 has no reusable
  WS-path `^` primitive** and must either lift the sexp one or write the
  primitive the old ruling forbade. Recorded now so P3 does not build on a
  false premise.
  *(Coordinates re-verified at the P3 audit: `split-fused-symbol` is at
  parser.rkt:5540 — the ruling's :5437 had drifted +103 — and the sexp `^`
  splitter at :3578 inside `validate-selection-paths` (:3567), drift +35.
  A SECOND reason it is unliftable, found there: it calls a LOCAL hand-rolled
  `string-split` (parser.rkt:3762-3770) that does NOT drop empty segments —
  `a^` becomes a rename to the EMPTY keyword and `a^b^c` is silently absorbed
  as one caret-bearing keyword. The F1b.7g drift class, live in the very
  primitive the old ruling proposed to lift.)*
- <a id="q-m8"></a>**Q_M8 — ORDINALS ARE MULTI-DIGIT IN BOTH BANDS [owner, 2026-07-28].** The
  owner ruled against P1b-i's draft recommendation: *"An ordinal broadcast could
  and should very much be multi-digit, practically — just as an ordinal `.Ndd`."*
  The recommendation was **wrongly premised**, and the refutation is measured:
  · **The overlap is TWO lexemes, not a space.** `recognize-colon-annotation`
    (parse-reader.rkt:847) accepts **12** lexemes — `:0`–`:9`, `:w`, `:m` — while
    `mult-annot?` (parser.rkt:3904) accepts **3** — `:0 :1 :w`. So **nine of the
    twelve already lex as one token and already are not multiplicities**;
    probe-verified, a binder-position `:7` gives a clean loud *"Expected binder
    [x <T>] or (x : T)"*. Ordinal ∩ multiplicity = **`:0` and `:1` only**.
  · **Those two are already discriminated**: of 289 live multiplicity tokens,
    287 spaced + 2 opener-preceded, **zero focus-adjacent** (Q8.3).
  · **So widening the digit run from 1 to N is not widening a collision** — it
    finishes a job the recognizer already half-did. `mult-annot?`'s `memq`
    rejects `:10` by the identical path it rejects `:7`: same arm, same error,
    **no new failure mode and no new error surface on the multiplicity side.**
  · **It also repairs a latent defect unrelated to Path Selection**: `{:0 v}`,
    `{:1 v}`, `{:9 v}` are legal map keys today and **`{:10 v}` SHATTERS** into
    `: 10`. Arbitrary and user-surprising.
  · **Blast radius is nil**: zero live uses of `:2`–`:9` or `:m` at HEAD, so the
    already-over-accepted range is unexercised.
  · **On the dot side the ruling FIXES A SILENT WRONG ANSWER** (Q8.1): `x.1.2`
    reads as the rational **6/5** and `x.10.20` as **51/5** today. A dot-anchored
    `digit+` recognizer kills it structurally — multi-digit is the *same*
    one-line `digit+` that fixes the rational, not an extra.
  **Implementation homes** (neither moves into P1b-ii): the `:N` widening rides
  the colon seam at **P1b-iii** (until broadcast exists `users:10` has no
  meaning); `.N` lands at **P2** as designed. Both owe a corpus A/B, being
  tokenizer changes. *Watching data point: probing before ruling changed the
  ruling — this time against MY OWN recommendation, on a premise I stated
  confidently and had not measured to its edges.*

**The P2 mini-audit rulings [owner, 2026-07-29]** (audit `wf_22020418-a5f`, 6
facets + completeness critic @ `c5153685`; every load-bearing claim
main-session R-lens-verified before adjudication. **12th consecutive phase
whose premise the mini-audit refuted or rescoped.** The doc-truth half landed
separately at `0e5a56a3` per owner ruling Q_R6):

- <a id="q-r1"></a>**Q_R1 — `.N` REUSES `$postfix-index`; it does NOT mint a new sentinel.**
  The audit's decisive finding: §5.P2 never ruled the sentinel choice, and it
  is the decision that sets the phase's whole cost. Both naive `$dot-access`
  reuses are BROKEN — a numeric payload **hard-raises** at macros.rkt:5556
  (`symbol->string` on `10`, i.e. a whole-file abort) and a symbol payload
  `|10|` silently yields `(map-get x :10)`, the wrong NODE (no PVec leg) with
  the wrong KEY DOMAIN. Reuse is verified near-free: `$postfix-index` is
  ALREADY in `pattern-var?` (macros.rkt:1152) and ALREADY in the
  `access-sentinel?` fusion gate (:5496), and its fold arm ALREADY terminates
  `[else `(get ,target ,key)]` (:5625) — the exact target §5.P2 specifies. So
  `v[0]` and `v.0` become **byte-identical datums**, which makes the owner's
  standing "two surfaces over ONE mechanism" ruling literally true at the datum
  layer rather than merely architecturally.
  **Costs, accepted with eyes open**: (a) `.0` and `[0]` are datum-
  indistinguishable, so spelling-specific diagnostics are forfeited and
  X.close's open "does bracket-postfix retire?" question is prejudged toward
  keeping them unified; (b) of the fold arm's four retirement guards only
  `postfix-hole` is reachable from a `digit+` payload, so `_.0` would print
  BRACKET-flavoured advice (*"use `[fn [m] m[k]]`"*) — **P2 fixes that message
  to be spelling-agnostic.** Decisive reason: the nine-tier sentinel surface
  produced the BLOCKING defect in *both* of the last two slices, and reuse
  avoids it entirely (no new `pattern-var?` entry, no new pp-datum/form-deps
  omission — the residual stays 23-of-33, not 24-of-34).
- <a id="q-r2"></a>**Q_R2 — COPY the `:N` twin's TRAILING GUARD.** The just-landed colon half
  consumes `digit+` and THEN declines on `ident-continue?`
  (parse-reader.rkt:907). `.N` copies it. This governs five shapes that each
  lex as ONE numeric token today — `x.0N` → `($nat-literal 0)` · `x.1e3` →
  **1000** · `x.1/2` → `($rat-literal 1/2)` · `x.1f` → float · `x.1p8` → posit
  — and with the guard all five DECLINE and stay exactly as they are today,
  minting no new error surface. **`xs.0N` is a NAMED NON-GOAL**: `0N` is the
  project's own Nat spelling and `expr-get` accepts Nat *or* Int, so it reads
  as sensible Prologos, but supporting it needs `digit+` plus an optional `N`
  and that is not this phase. Recorded so the next reader does not think it
  was missed.
- <a id="q-r3"></a>**Q_R3 — the DOT BAND STAYS ADJACENCY-FREE, ruled rather than inherited.**
  The band has no adjacency gate at all (`adjacent-to-base?` is called only
  from the bracket and brace arms), so `x .0` and `x. 0` both read `((x |.|
  0))` and a spaced `.0` WILL select after P2. `.k` never enforced adjacency
  either, so requiring it for `.N` alone would create a NEW inconsistency
  *inside* the band, and retrofitting the whole band is out of scope. Blast
  radius is nil by census. Per Q_N5's precedent this is RULED, not discovered.
- <a id="q-r4"></a>**Q_R4 — `m.0` MOVES OUT of the `§10.6` v2 block.** The corpus
  self-contradicted: `m.0` sat inside a block headed *"v2, PERMANENTLY
  commented (spec §7.3)"* while its own annotation said *"works at D4.P2 via
  .N"*. It moves to a live section rather than the header being amended.
  Ordering also matters and the audit priced it: `run-file.rkt` keys `;;N=>` to
  **RESULT INDEX**, so uncommenting `party.0.name` (line 118) costs **23**
  marker renumbers while a trailing addition costs **zero** — land the trailing
  ones first.
- <a id="q-r5"></a>**Q_R5 — the `.N` ERROR SURFACE IS IN SCOPE.** P2 owns the first user-facing
  ordinal-access diagnostics, and the two out-of-range paths are wildly
  asymmetric: PVec at RUNTIME is excellent (`panic: get: index 9 out of bounds
  for PVec of length 3`) while a CLOSED nat-row (het tuple) out-of-range is
  caught statically and reported as a bare *"Could not infer type"* — no arity,
  no positions, no path — because `closed-row-miss-hint` is **KEYWORD-GATED**
  (typing-errors.rkt:148, :151). Het tuples are exactly the carrier the
  acceptance file pins (`mixed`, `events`), so this is the FIRST thing a user
  hits on the new surface.
- <a id="q-r6"></a>**Q_R6 — the doc-truth batch lands SEPARATELY**, before P2's code. Done:
  `0e5a56a3`. It corrected a self-contradiction in **owner-reviewed normative
  text** (§Q8.1's five-vs-six), a **layer error** that had already propagated
  into a session summary (the "0 errors" claim), a **false illustration** in
  §Q8.5 invariant 2 that no facet caught, invariant 3's opener-shaped token
  layer plus four stale coordinates including the fusion gate it exists to
  name, and §8 R3's retired-`.*` quadruple-duty claim.

**Recorded adaptation (Batch-1 discipline — an UNRECORDED adaptation is a bug
in D4, so it is recorded here rather than applied silently):** `.N` routing
through `expr-get` means that on a `(Map Int V)` subject it resolves to a
**NOMINAL key lookup wearing ordinal notation**, against the spec's own
key-sort thesis (spec §2.1 reads `.N` as "ordinal access (index)"). Blast
radius is low — `(Map Int V)` requires an annotation to reach — and unifying
the spellings is the point of Q_R1, so the adaptation is ACCEPTED. Named so it
cannot be rediscovered as a defect.

**The P3 co-design rulings [owner, 2026-07-29]** (the COMPLETE Q_T batch —
Q_T1–Q_T8, ruled across four deliberative rounds,
in PROSE per the standing discipline; audit `wf_27a84061-c7e` fed them —
**13th consecutive phase whose premise the mini-audit refuted or rescoped**):

- <a id="q-t3"></a>**Q_T3 — "level-local" means OUTPUT-level-local.** The L4/strict-merge checks
  run over the keys that reach a result level AFTER `^`-splicing. Ruled because
  the syntactic-block reading ACCEPTS `cfg{server^.{port} database^.port}` —
  two dissolving branches landing `:port` at the same output level — which
  Ruling B B4 REJECTS, and that is the one direction that breaks the strict
  waypoint's monotonicity guarantee ("every error today can become a meaning
  later"). Probe-verified that the naive lowering would silently last-win it.
- <a id="q-t4a"></a>**Q_T4a — `^` NEVER attaches to an ordinal; it is a guided spelling error.**
  Owner: an ordinal returns the value at an index, not a key-value; and
  non-local attachment (my PS6 reading, scanning left past ordinals to the
  key-generating segment) "breaks composition, first-class re-use, and
  expectations." The expressivity lives at the right place already:
  `cfg{admins^first.0}` renames the NOMINAL segment then descends → `{:first
  ⟨admins[0]⟩}`. Consequence: DEFERRED 11 dissolves into a MESSAGE-QUALITY
  item — `x.0^` / `x[0]^` / `{admins.0^first}` all need one guided error
  ("an ordinal has no key; rename the nominal segment"), not a semantics.
- <a id="q-t4b"></a>**Q_T4b — THE `^` BASE RULES** (the mutual-clarity round; misread by me, now
  pinned): a branch's output key is its **surviving head key**; every `^` form
  acts **locally on its own segment**; **rename is IN PLACE**; only
  `^`-dissolve removes a level; bare leaf `^` contributes the leaf VALUE as a
  keyless component (no keys ⇒ no ancestry question). So `server.host^h` →
  `{:server {:h …}}` and `server^.host^h` → `{:h …}`. The spec flagship
  re-derives exactly under these rules.
  **Where the misreading came from, recorded so it cannot recur**: (1) NO §10
  example renames a leaf under a KEPT ancestor — every spec rename sits under
  a dissolved ancestor or at the branch head, so the corpus cannot
  discriminate in-place from collapsing; (2) the acceptance file's §B `^_`
  line (written at P0) showed a FLAT result imported from the SUPERSEDED
  surface's D3-era "`^_` = derive-ALL" ruling — an old-surface semantic in the
  new corpus without the §8 R5 NOTATION-vs-SEMANTICS classification. The line
  is corrected in this commit.
- <a id="q-t4b-prime"></a>**Q_T4b′ — `^_` takes READING N (local, like its siblings)**: it is `^k'`
  with a computed label — rename the leaf IN PLACE to the path-synthesized
  key. `cfg{server.host^_}` → `{:server {:server-host …}}`. The flat
  "provenance" behaviour is NOT lost — it is the explicit collapse spelling
  `server.host^-_` (Q_T7), which is where a structural effect belongs.
- <a id="q-t7"></a>**Q_T7 — the `^-` COLLAPSE family is IN SCOPE at P3.** `^-` collapses the
  whole branch flat: `h.k^-` → `{:k …}` · `h.k^-k'` → `{:k' …}` · `h.k^-_` →
  `{:h-k …}` (the flat provenance recovery). Makes `i^.h^.k` ergonomically
  `i.h.k^-`. Lexing verified: `k^-` / `k^-k2` / `k^-_` each glue into ONE
  token; the splitter's continuation grammar is `-`?·{ε | label | `_`}.
  ⚠ Eyes-open cost: after `^` a leading `-` IS the collapse marker, so a
  rename target literally beginning with `-` is unsupported.
- <a id="q-t8"></a>**Q_T8 — the parent-key collapse is IN SCOPE, spelled `^..` (not `^.`).**
  `ssl.enabled^..` ≡ `ssl^.enabled^ssl` → `{:ssl …}`; ancestors above the
  parent are kept (`server.ssl.enabled^..` → `{:server {:ssl …}}`). The owner
  flagged the `^.` parse hazard and pre-authorized `^..`; probes CONFIRMED the
  hazard is real and `^..` dissolves it: `a.b^.c` (missing space) reads
  IDENTICALLY to the legitimate mid-path dissolve `a`·`b^`·`.c` — a silent
  one-space meaning flip between two well-typed keyed forms with NO type-error
  net (the §2.2 mitigation does not apply here) — and `a.b^.0` collides the
  same way with ordinals. Under `^..` both no-space shapes contain a bare
  `|.|` mid-branch and are LOUD malformed-payload errors. Edge recorded:
  `a.b^...` absorbs into `$rest`; the malformed-payload seat must reject a
  `$rest` item in a block payload.
- <a id="q-t6"></a>**Q_T6 — the `spec` type-position hole is FILED** (DEFERRED 14), not fixed in
  P3. Pre-existing (the shipped `.`-access is dropped identically) and rooted
  in `spec`'s error architecture (a preparse command inside a `void`-ing
  handler), not in selection. ⚠ The C30 open question is now ANSWERED — it is
  the WORSE reading: the dropped spec's type datum IS registered (the
  follow-up `defn h` error QUOTES the raw `($retired-selection …)` marker
  from the stored spec), so the hole stores garbage rather than losing a
  declaration.
- <a id="q-t1"></a>**Q_T1 — ROUTE A: mint the `expr-select` node NOW, scoped grades-1-only
  [owner, 2026-07-29].** Decided from the COMPLETED-feature horizon, on four
  legs: (1) **P5's spine identity is a comparison over a structured step
  representation** ("source-directed steps with `^`-continuations erased") —
  a desugared block leaves nothing to compare; (2) **the error-surface
  argument REVERSES at the completed horizon** — P5's "SHOULD print the
  factored spelling" and even P3's strict-merge remedies need BLOCK CONTEXT
  at error time, which desugaring forfeits permanently while inheriting only
  generic messages (the audit's C9/G7 diagnostic concern is answered by
  wiring `format-closed-row-miss` — a standalone, reusable fn — into the
  node's own typing arm, WITH branch context: same quality, better ceiling,
  and the work persists); (3) **option 2 is a strict PREFIX of option 3**
  (surf node + parser + elaborator are shared; the routes differ only in what
  the elaborator arm emits), so route B's elaborate-time lowering would be
  scaffolding with a designed ONE-phase lifetime that P4 must tear out (the
  dual-path ban forbids keeping it); (4) ruling 4b already fixed the node as
  the destination — only timing was open, and the audit priced it. Honest
  price accepted: ~13 files, the inferQ/checkQ twins (delegation model
  `cdb535ac`), walkers via the generic transparent-struct fallback (no
  binder ⇒ no depth routing), NO PNET bump (symbol-keyed tag table,
  verified), subject evaluated ONCE in the node's reduction (no let/fn
  workaround). P3 is a MULTI-SLICE phase; Q_T5 organizes it.
- <a id="q-t2"></a>**Q_T2 — PRESENCE: HORN D, LENIENT [owner, 2026-07-29].** The rule: **a
  block may select a field iff the subject's type SOURCES that field's
  presence as `'present`; everything else is a loud static error** naming the
  4d remedy list (seal / validate / annotate). The result row is closed,
  all-`'present`, honestly — PS15's sourced-presence qualifier satisfied, so
  §B's "sealable, validatable" claim is TRUE, and the presence-blind seal
  (verified: zero `record-field-presence` reads in either seal fn) is never
  asked to vouch for fabricated presence.
  · **LENIENT**: a dyn row's LISTED-`'present` fields are selectable (their
    presence IS sourced — PS15's own criterion); only `'unknown`-marked and
    unlisted fields refuse. Consistent with 4d: broadcast needs the WHOLE
    support (dyn tail ⇒ loud), a block names SPECIFIC fields, so
    support-boundedness (D3-M5) is satisfied per-field.
  · **Probe fact that reshaped the case table**: `map-dissoc` on a CLOSED row
    simply REMOVES the field (still closed, no `'unknown` mark; projecting it
    is already a loud miss). `'unknown` arises only from dissoc-on-DYN — so
    closed rows cannot carry unknown presence, and the corpus (all closed
    rows) costs ZERO.
  · **The deliberate asymmetry, ruled not absorbed**: bare `.field` on a dyn
    row stays D19-permissive (exploration); a BLOCK on the same row refuses
    (construction is assertive-tier — it mints a committed, sealable value).
  · Rejected-with-reason: Horn A (stamp `'present` always) fabricates
    presence on dyn subjects and the blind seal then guarantees it — the
    seal's contract broken exactly where PS15 warned; Horn B (`'unknown` in a
    closed row) is unsound TODAY for the same blind-seal reason and mints a
    carrier state no walker has ever seen; Horn C (presence-aware seal) is
    complementary to B, not an alternative to D, and is F1b-scope growth
    mid-phase. All refusals are MONOTONE (F-row/P6 can later relax them).
- <a id="q-t5"></a>**Q_T5 — P3 SPLITS THREE WAYS: P3a → P3b → P3c [owner, 2026-07-29 — "that
  shape looks good to me"].** **P3a** = the node + keyed blocks, no `^` (the
  full pipeline cost paid once; D-lenient presence from day one; strict merge
  for plain keys BEFORE `make-record` can last-win; the malformed-payload
  seat; the type-position refusal; §9's learnability pair). **P3b** = the `^`
  family (the ONE splitter; five operators; the output-level-local merge
  re-check with the Q_T3 monotonicity case as its named pin; the Q_T4a
  ordinal-`^` guided error). **P3c** = keyless + L4 + honest nesting (the
  nat-row mint at EVERY n; ordinal branches `{N M}`; the L4 mixing error; the
  `⟨String⟩` pins; the G11 one-space pair). **Ordering is FORCED, not
  chosen**: a→b because the splitter extends the payload parser and every `^`
  semantic runs through the node's arms; b→c because both §B keyless corpus
  lines use leaf-`^`, so tuples cannot ship before bare-`^` means something.
  Rejected-with-reason: folding P3c into P3a puts the tuple mint ahead of the
  bare-`^` semantics it depends on — the forward-reference-between-slices
  shape that made P1b split three ways. **P3 needs ZERO tokenizer changes**
  (every ruled spelling already lexes, probe-verified), so NO corpus A/B is
  owed anywhere in the phase; gates = acceptance + targeted batteries + full
  suite + the pre-commit adversarial verify (a BLOCKING catch in five
  consecutive behavioural slices — load-bearing, not optional). P3b/P3c open
  with LIGHT mini-audits (coordinate re-verification against `wf_27a84061-c7e`,
  not full re-audits). **The Q_T batch is COMPLETE.**

**The P3a-close checkpoint rulings [owner, 2026-07-30]:**
- <a id="q-u1"></a>**Q_U1 — P3a owns EVERY no-`^` block line** (the §5.P3a corpus list was
  corrected against the file; `6d919142`).
- <a id="q-t2-adaptation"></a>**Q_T2 adaptation RATIFIED** — "annotate its row type" dropped from the
  refusal remedy lists ("annotate comes back when it's real"); DEFERRED 19
  carries the re-entry trigger.
- <a id="q-u2"></a>**Q_U2 — mid-branch ordinal steps take READING A** ["Reading A stands —
  ordinal blocks own the re-derivation"]. A grade-1 `.N` step inside a keyed
  branch DESCENDS, contributing NO output level — ordinal keys are
  contingent, there is no identity to preserve; nominal ancestry above and
  below survives (`cfg{admins.0.name}` → `{:admins {:name "Alice"}}`).
  Re-derivation (fresh indexing) is reserved for ordinal BLOCKS — `{N M}`,
  including the 1-tuple `.{0}` per honest nesting — so `.0` (one focus, no
  shape) and `.{0}` (1-tuple) stay DISTINCT and the step/block grade
  distinction survives; the in-block step matches the bare path's landed P2
  extraction, with ancestry kept. Consistent with Q_T4a's recorded
  consequence ("renames the NOMINAL segment then descends").
  **Implementation: P3c** (rides the ordinal machinery; P3a's parser refusal
  lifts there; P3b untouched).
- <a id="q-u3"></a>**Q_U3 — the P6 demand DECISION takes option (c)** ["defer it — (c)
  stands"]: demand semantics deferred to a named post-v1 phase; §5.P6
  carries the ruling + the charter stub; the 4a X.close gate stays armed.

**The P3b-close checkpoint ruling [owner, 2026-07-30]:**
- <a id="q-u4"></a>**Q_U4 — `^_`/`^-_` synth scope: SUBJECT-ROOT is PREFERRED; the flip is
  DEFERRED until it next matters.** P3b implemented branch-of-its-block
  scope (`server.{host^_}` → `{:server {:host …}}` while the dot spelling
  gives `{:server {:server-host …}}`). Owner: the local reading is "not a
  bad assumption" but of lesser utility — **a sub-branch is LESS likely to
  share a common leaf key**, so the synth's disambiguating power wants the
  full path; not a high-priority feature, "switch when it matters next."
  Natural trigger: P5's L2 factoring (which makes the divergence observable
  and wants the two spellings equal) or the first user-visible need.
  DEFERRED 23 carries the trigger + the one-line flip site.

**The P4 co-design rulings [owner, 2026-07-31]** (Q_U5/Q_U6 — ruled in a
deliberative walk that REVERSED the frame twice: the mini-audit
(`wf_8458c23b-312`, 5 facets + critic @ `02dd27d7` — **14th consecutive
premise refuted**) fed an adversarial options panel (`wf_82e56156-b28`)
whose own CRITIC overturned the proposers' lean by probe, and the OWNER'S
challenge then overturned the critic's framing of what blocks. ⚠ The LET
track's merge (`5e16ead4`) landed MID-WALK — audit coordinates are
@ `02dd27d7`; re-pin before use):

- <a id="q-u5"></a>**Q_U5 — THE SELECTOR REPRESENTATION: ONE REIFIED CARRIER (panel option
  B), MONOMORPHIC AT P4.** `expr-path` and `expr-select` unify on one
  reifiable selector carrier; `#p(…)`, `x{…}` and path position become
  spellings of ONE representation; the vacuous ground `Path` type is
  superseded. The walk that got here: (1) the owner REJECTED the brace-only
  answer ("loses information on its spine … doesn't reach the generalized
  first-classness we want"); (2) the panel's proposers leaned "charter the
  reification" on the premise that B needs row polymorphism — an unbounded
  extension; (3) the panel's critic REFUTED the conclusion by probe
  (monomorphic source-annotated projection types cleanly at HEAD: `spec g
  P -> Int` / `defn g [r] r.a` ✓); (4) the owner refuted the PREMISE'S
  FRAMING: the records system was BUILT from row polymorphism + codata —
  verified: the carrier comment STAGES the row variable (syntax.rkt:672
  "`ρ` row-meta = **F-row**"), the records design §151 names open rows as
  THE row-polymorphic case, D12 ships substrate-level codata, and every P4
  carrier's element/field type is KNOWABLE (PVec elem-type · Map k/v ·
  nat-row per-position · keyword-row per-label). So B splits: **(i) the
  carrier unification needs ZERO new typing** (every P4 site has a known
  source row) and lands NOW — it is the half that cannot be retrofitted;
  **(ii) bound-selector precision** (`Selector src dst` / D11's
  `HasField`-constraint idiom) rides **F-row's EXISTING entry gate**
  (DEFERRED: "generate `p : {:x _ | _}` from `p.x`, solve structurally") —
  a named deferral onto an already-chartered absorber, NOT a new charter.
  Rejected-with-reason: **A** (brace-only node + untouched `expr-path` =
  C without the honesty; unnamed dual carrier) · **C** (charter the
  reification = a SECOND charter over First-Class Paths **Phase 8**,
  already chartered 2026-03-20 as "Out of scope" and idle since — the
  belt-and-suspenders blocking red flag + the Validated≠Deployed sibling) ·
  **D** (selector-as-Datum: Datum's syntactic order ≠ selection order, so
  L2/Q6 leave the carrier) · **E** (selector-as-function — and record the
  GENERAL RESULT: a selector typed as its own APPLICATION erases the
  spine; function types are not lattice elements, so no Pi/section/
  closure/lens-as-function representation can support P5's spine equality
  or Ruling-B pointwise merge. This is the positive argument FOR the data
  carrier, and it rules out the §7.7 lens FRAMING as a representation
  while keeping lenses as an INTERPRETATION).
- <a id="q-u6"></a>**Q_U6 — WHOLESALE PATH-POSITION MIGRATION AT P4, with the three-stage
  sequencing.** Dot AND colon path steps mint the node; the preparse
  `map-get`/`nil-safe-get`/`get` fold legs retire into `$select` minting.
  NOT colon-only: that leaves path text on two representations
  discriminated by a step's GRADE (complection; P5 would normalize across
  both). Grounded costs: the fold's callers are a NON-issue —
  probe-verified all **FOUR** production callers (map-literal values ·
  subforms re-entry · pipe pre-fold · mixfix; the 4th is P3a's own
  addition, missed by every enumeration — 6th consecutive under-count)
  depend ONLY on arity collapse and are head-agnostic (`$select` and
  `map-get` fold identically through all four). The REAL cost is the
  BEHAVIOR-PRESERVATION CHECKLIST: `.field`'s landed behavior must survive
  under the carrier's `'path` sort — Q_T2's ruled asymmetry is LIVE
  (probe: `dyn1.host` → `"h" : ?meta` D19-permissive vs `dyn1{host}` →
  loud Horn-D refusal), so ONE carrier carries TWO typing postures by
  sort; plus the P2 `closed-row-miss-hint` family (via
  `projection-parts`), nil-safe variants, and `get-in`/`update-in`
  retargeting. **Sequencing (ruled)**: (1) totality dispatcher +
  strategy-independent repairs (no new surface) → (2) carrier unification
  + wholesale migration with the behavior checklist → (3) the ω semantics
  on top. Sub-slice partition finalizes after Q_U7/Q_U8.

- <a id="q-u7"></a>**Q_U7 — THE ω STEP IS A ONE-STEP WRAPPER: `(@bcast step)` [owner,
  2026-07-31 — "(b) stands"].** `users:name` → `[(@bcast name)]` ·
  `users:{a b}` → `[(@bcast (@sub …))]` · `x:s:t` → `[(@bcast s) (@bcast t)]`.
  **Ruling 4b is RESTATED**: the ω step is a one-step wrapper; EXTENT is
  structural (the spec's "broadcasts exactly the NEXT step" is the
  representation 1:1 — a broadcast-of-nothing is UNCONSTRUCTIBLE, and the
  §3.2.1 extent pair is two visibly different datums); **L1 fusion is a
  THEOREM the battery pins** (`users:0:userName` → ONE layer), not a
  property the representation maintains — fusion is FREE under any
  candidate (each ω step consumes one container layer and re-wraps one;
  fmap∘fmap = fmap arithmetically; nothing computes a layer count); the
  old "layer count = unfused-ω-steps" clause is RETIRED as
  descriptive-not-normative (§10.4's layers come from data shape + `*`).
  Rejected-with-reason: the flat nullary marker (extent-by-adjacency ⇒
  representable malformed states + a backward scan, the structurally-
  emergent red flag) · the run-carrying wrapper (the surface never writes
  runs ⇒ the parser must MERGE adjacent wrappers — exactly the
  normalization pass 4b's rationale forbids; spends the terminal-`@sub`
  invariant for no v1 consumer; P5 recovers runs by a trivial fold over
  consecutive wrappers) · the per-step grade field (taxes the entire
  landed vocabulary for one grade). In the components walk ω is
  key-transparent like ordinal steps — a WRITTEN arm under the P4a
  totality dispatcher; branch-initial `:` stays refused in v1 (W2/spec
  §7.3), so a wrapper never heads a branch. The wrapper is plain data,
  so it survives the Q_U5 carrier unification unchanged (a marker's
  meaning depends on neighbors — exactly what a reified composable
  selector must not do).

- <a id="q-u8"></a>**Q_U8 — THE `:` GATE: UNIFORM POSITIONAL SENTINEL-MINT AT GROUPING +
  PARSER POSITION-DISPATCH [owner, 2026-07-31 — "uniform mint"].** At
  grouping, a `keyword` or `colon-annotation` token BYTE-ADJACENT to a
  non-empty local result mints the new access sentinel
  **`($bcast-step payload)`** — the `adjacent-to-base?` shape, landed in
  BOTH groupers (Q_N7 twin), positional NOT enumerated (`.N`/brackets/
  braces join the focus set free; six enumeration under-counts this arc).
  `$bcast-step` IS an access sentinel (fuses onto its base via the fold —
  the `$postfix-index` pattern) and pays the NINE-site §Q8.5 registration
  surface. The `ident:ident` collision (annotation vs broadcast) is
  position-dependent and ONLY the parser knows position, while adjacency
  is destroyed below grouping (Q8.5 inv 2) — so grouping PRESERVES the
  distinction and the parser DISPATCHES: expression position reads the
  sentinel as the ω/broadcast step; **binder position UNWRAPS it as the
  annotation** (`fused-type-annot?`'s 4 sites · LET's binder consumer ·
  the spec-param and `$brace-params` binder paths — census-gated).
  Shattered spellings (`users:{a b}` = bare `:` + adjacent group;
  `users:<{a}`) become grouping arms over EXISTING tokens — **zero
  tokenizer changes**. **Corpus A/B MANDATORY** (grouping changes datums)
  with a NAMED predicted diff set: exactly the fused-binder sites (3
  `.prologos` let lines at HEAD flip datum shape, not behavior — the
  parser unwraps); any diff outside the set is a bug. **The LET merge
  IMPROVED the safety net**: the fused-annotation hazard class went from
  ZERO instances (A/B-blind at `02dd27d7`) to 3 acceptance lines + 12
  suite-gated embedded pins + 17 defn-param shapes — a naive gate now
  turns the suite red instead of shipping silently. Rejected-with-reason:
  mint-suppression in grouping-recognizable contexts (reintroduces an
  enumerated context list — the under-count class); parser-only (cannot
  see adjacency, Q8.5 inv 2); a fused tokenizer token (same collision,
  bigger surface).

**The P4 pre-implementation PAUSE rulings [owner, 2026-07-31]** — all three
items of the hold-point, ruled before P4a opened:

- <a id="q-u9"></a>**Q_U9 — `:` REFUSES over `List`, with a guided error [owner, 2026-07-31].**
  Broadcast covers the carriers the KEY-SORT THESIS reaches; `List` is not one
  of them, so `quests:t` does not uncomment and the corpus line's fate changes.
  The grounded argument (probed at `711a9bde`, not asserted):
  **(i) `List` is the only candidate with no native carrier** — `Map`→
  `expr-champ`, `PVec`→`expr-rrb`, `Set`→`expr-hset`, het-tuple→`expr-Record`
  (nat key-domain), while `List` is a USER-SPACE inductive
  (`data List {A} | nil | cons : A -> List A`,
  `lib/prologos/data/list.prologos:12`) with no struct in `syntax.rkt`.
  Broadcasting it would make the compiler-native `select-reduce` pattern-match
  constructor applications of a STDLIB type — a dependency direction no other
  selection carrier has, and a slope with no principled stopping point short of
  trait dispatch (`Option`, `Either`, `LSeq`, user functors).
  **(ii) The key-sort thesis (spec §1.1) does not reach a cons-spine**: every
  other carrier has a key domain (ordinal or nominal); a List's positions are
  recoverable only by walking. This is the SAME argument §3.2.3 used to
  ADOPT map-generic `:` ("a vector-only `:` leaves the thesis decorative
  exactly where it matters") — pointed the other way.
  **(iii) The remedy exists, is one primitive, and preserves precision** —
  probe at HEAD, 0 errors: `def qv := [pvec-from-list quests]` →
  `qv : [PVec {:g String :r Int :t String}]` (the row SURVIVES), and the
  landed grade-1 machinery reaches in (`qv[0].t` → `"Rescue the cat"`).
  `pvec-from-list : List A → PVec A` is a live compiler primitive
  (`parser.rkt:2966`).
  **(iv) Monotone** — spec §3.6's own migration principle: errors may become
  meanings, never the reverse.
  **Deliverable, not a shrug**: the refusal is a GUIDED error naming
  `pvec-from-list` and stating that the row type is preserved (iii proves it).
  **The principled door is NAMED**: `:` refuses over `List` *because `List` has
  no `Functor` instance* — the higher-kinded trait vocabulary (`Functor`,
  `Foldable`, `Seqable`, `Buildable`, `Reducible`, `Indexed`, `Keyed`,
  `Setlike`) is ALREADY DECLARED WITH LAWS at
  `lib/prologos/core/collection-traits.prologos:41-177` and has **ZERO live
  instances tree-wide** (the only three mentions are commented aspirations in
  the 2026-03-21 Track 8 acceptance file). So the exit is "inhabit a
  designed-but-uninhabited surface, then route `:` through `Functor`" — seeded
  as a candidate CIU track, NOT chartered here.
  Recorded counter-argument (it is real, and it is why the carrier question
  moved rather than dying): `solve` returns `List`, and solve rows are exactly
  what this feature exists for — Rel T1 landed typed solution rows so
  relational output would compose with records. The resolution is **upstream,
  not here**: `solve-*`/`explain-*` should return `PVec` (spun out as its own
  mini-track — seam measured at TWO lines, `solve-row-type`'s `'list` arm
  `typing-core.rkt:4338` + `racket-list->prologos-list` `reduction.rkt:905`;
  consumer census 2 live `.prologos` sites + ~31 mechanical test type-string
  pins + the `nil`→`@[]` empty shape). That fixes the ergonomics at the source
  WITHOUT widening selection's carrier semantics. **Implementation: P4d**
  (the refusal + its guided error); nothing before P4d reads this decision —
  verified, `quests:t` sits COMMENTED at corpus `:235`, so it produces no
  datums and P4c's reader-datum A/B does not touch it.

  > **✅ THE UPSTREAM FIX HAS LANDED — 2026-07-31.** The spun-out mini-track is
  > COMPLETE: `solve`/`solve-with`/`explain`/`explain-with` now return `PVec`
  > (`b2c4366a`), and the `let x := (goal …)` implicit-solve gap found alongside
  > it is closed (`b5b641b9`). Doc: `docs/tracking/2026-07-31_SOLVE_CARRIER_SPINOUT.md`.
  > **So the Q_U9 refusal now costs solve rows NOTHING** — `def quests := solve
  > (quest t g r)` is already `[PVec {…}]`, and `quests:t` will work at P4d with
  > no `pvec-from-list` hop at all. The corpus example's two `map` sites needed
  > no source change (see the correction below).
  >
  > **Two claims in the paragraph above did NOT survive contact — correct them
  > before relying on either:**
  > 1. **"Seam measured at TWO lines" — it was SEVEN.** The two named are real,
  >    but the census missed the three DISPLAY walkers (`display-row-type-parts`
  >    + `display-result-rows` in typing-core, `pp-solve-echo-ordered` in
  >    driver), each of which fails **silently** — the B3.2 coinductive echo
  >    refinement and the POL.3 declaration-order echo just quietly stop firing.
  >    It also missed `pnet-serialize.rkt`, where the carrier reaches module
  >    caches via POL.10 and hit a **live hash-persistence defect** (`rrb-root`'s
  >    `tail` is a raw Racket vector and `deep-s->v` has no `vector?` arm, so
  >    champ rows leaked through with `equal-hash-code` values baked in).
  > 2. **"2 live `.prologos` sites" need rewriting — they did NOT.** The census
  >    read `spec map … [List A] -> List B` and concluded `map` is
  >    List-monomorphic; that spec is one *instance* under container-generic
  >    dispatch. `map`/`filter`/`length`/`first` all carry the PVec carrier
  >    through unchanged, so only the `;;NN=>` markers moved. A `spec` line is
  >    evidence about an instance, not about dispatch.
  >
  > The `~31 mechanical test pins` and the `nil`→`@[]` empty-shape call were
  > both accurate.
  >
  > **⚠ TWO FURTHER CORRECTIONS — the P4d opening audit, 2026-08-07:**
  > 1. **The lines ARE uncommented now** — `quests:t` went live at P4d-0
  >    slice 1 (`33d83989`) and `quests:{t r}` at slice 5 (`77259635`);
  >    acceptance markers 43/44, passing. The statements above ("does not
  >    uncomment"; "sits COMMENTED at corpus `:235`… the A/B does not touch
  >    it") and their two §5.P4 restatements are OBE — the solve→PVec spin-out
  >    re-fated them upstream, and P4d's re-fate list shrinks by one.
  > 2. **The Functor door's census was FALSE WHEN WRITTEN, not stale**:
  >    `Functor List` has been LIVE since 2026-03-01 (`6dffa9a6` —
  >    `core/list.prologos` `spec list-functor [Functor List]` /
  >    `def list-functor map`), and `Functor PVec` alongside it
  >    (`core/pvec.prologos` `pvec-functor`). The "ZERO live instances
  >    tree-wide" census missed both. **The refusal RULING STANDS** on its
  >    other grounds — (i) no native carrier, (ii) the key-sort thesis does
  >    not reach a cons-spine, (iv) monotone — but the guided error must NOT
  >    claim the absence, and the named exit is no longer "inhabit an
  >    uninhabited surface": the surface is inhabited, and the remaining exit
  >    work is routing `:` through it (still a candidate track, NOT P4d).
- **The `update-in` ω FENCE — RATIFIED [owner, 2026-07-31].** `update-in`
  accepts **grade-1 selectors only**; an ω-bearing selector refuses LOUDLY.
  Broadcast WRITES are spec §7.7 traversal territory, explicitly not v1.
  Monotone (the refusal can become a meaning later). Load-bearing because
  Q_U5's carrier ABSORBS First-Class Paths' `#p(…)` — including its **working
  write direction** — so without the fence the unified carrier would silently
  widen `update-in`'s domain the moment ω steps become constructible.
- **The WHOLE-NODE ABORT — RATIFIED [owner, 2026-07-31].** A runtime miss
  INSIDE a broadcast aborts the WHOLE selection — the single `let/ec`
  (`reduction.rkt:1600`), no partial results, no `expr-panic` buried in an
  output slot. Consistent with the P2.b two-tier discipline; stated and
  PINNED so a "map semantics" intuition cannot drift it later. This is the
  same fact the P4a LOWER-vs-WALK fail-first fixture settles by test.

**The P4b opening ruling [owner, 2026-07-31]:**

- <a id="q-u10"></a>**Q_U10 — WHOLESALE STANDS; the `'path` sort GAINS A MAP POSTURE**
  ["(a) — keep wholesale, give the 'path sort a Map posture"]. The P4b
  mini-audit (`wf_1cb9d606-89c`, 5 facets + completeness critic @ `2cef148b`,
  1.17M tokens) produced a **BLOCKING objection to Q_U6 as written**, which
  this ruling resolves.
  **The objection, probe-verified at HEAD**: `.field` on a `(Map K V)` subject
  WORKS (`m.a` → `1 : Int`, 0 errors, via `expr-map-get`,
  typing-core.rkt:2205-2213) while `{field}` on the SAME subject REFUSES
  STATICALLY (`select-row-of`'s `[(expr-Map? tm) … 'subject-map]`,
  typing-core.rkt:663). So wholesale `$select` minting for `.field` would
  **silently delete a working surface** — and not an obscure one: it is
  DOCUMENTED in the ambient rules (`prologos-syntax.md:117` "Dot access is for
  map keys — `user.name` → `[map-get user :name]`"), TAUGHT as the headline
  ergonomic in `examples/map-tutorial-demo.prologos:219-225` against an
  explicit `[Map Keyword Nat]` def, and PINNED E2E at
  `tests/test-dot-access-02.rkt:112-119` — a pin BOTH fold-census facets
  missed, because it asserts a **value**, not a datum, so it fails by TYPE
  ERROR rather than shape mismatch. A migration plan phrased as "update the
  datum assertions in the migrating commit" structurally cannot catch it.
  **The ruling**: wholesale stands (the complection Q_U6 rejected is still the
  thing to avoid), and the `'path` sort gains a **Map posture** — `.field` on
  a Map subject keeps `map-get` semantics under the unified carrier.
  **Consequence, accepted eyes-open**: design claim C2 ("ZERO new typing
  work") is **REFUTED** and formally withdrawn. Sort dispatch has to exist
  anyway for Q_T2's dyn-row asymmetry; Map is a THIRD posture in a table we
  are already building, not a new mechanism. Therefore **design-round item 5's
  semantic table is TWO-DIMENSIONAL — indexed by (subject kind × sort), not by
  sort alone.** Rejected-with-reason: **(b)** narrow the migration to the
  reified spellings only (`#p(…)` + `x{…}`), leaving `.field` on `map-get` —
  preserves the Map surface for free but leaves path text on TWO
  representations discriminated by subject type, which is exactly the
  complection Q_U6 was ruled to prevent; **(c)** migrate only record-typed
  subjects — incoherent, elaboration precedes typing so the discriminator is
  not available where the mint happens.

- <a id="q-u11"></a>**Q_U11 — RETIRE the silently-broken `#p(…)` vocabulary, with a guided
  error** ["(a) — retire them with a guided error", owner 2026-07-31]. Opening
  P4b-i by probing the encoding, the path literal turned out to carry FOUR
  spellings of which only ONE works:

  | spelling | at `099ef690` |
  |---|---|
  | `#p(a)` · `#p(a.a1)` | **live** — `get-in m p` returns the value |
  | `#p(a.*)` · `#p(a.**)` | defines as `Path`, then `get-in` → **`<error>` VALUE at ZERO ERRORS** |
  | `#p(a.{b c})` | same — `<error>` value, 0 errors |

  The broken half is the **P2.b fabrication class, live**: a value where an
  error is owed, unconstrainable because the vacuous ground `Path` type
  discards the branches (`typing-core.rkt:2050-2051` matches `_`). Their own
  acceptance file has them COMMENTED OUT
  (`examples/2026-03-20-first-class-paths.prologos:80,83,86`), so there is no
  live corpus use. **Retired rather than carried across the carrier
  unification** — carrying them would move a silent-wrong-answer into the new
  carrier and make "ends single-carrier" hollow (the blocking
  belt-and-suspenders shape); fixing them into working semantics would be new
  behaviour inside a slice that is meant to be behaviour-preserving, and
  multi-branch collides with the `(car branches)` truncation P4b-iii repairs.
  Monotone. Refusal fires at ELABORATION — at the literal, not its use — via
  the `parse-error` seat (a per-command error VALUE, never a raise), the same
  seat the `update-in` guards use at elaborator.rkt:2347/:2351.
  ⚠ **The P4b mini-audit did NOT catch this.** Its F3 confirmed
  "`#p(a.b.c)` round-trips" and "`get-in` works" — both TRUE, for the subset
  anyone probed. The fuller vocabulary was never run end-to-end. **15th
  consecutive premise refutation of this arc, and this time the refuted
  premise was the audit's own.**

  **TWO further findings surfaced while implementing the refusal** (both
  diagnosed by READING THE DATUM after two wrong guesses, per the diagnostic
  protocol — a branch-COUNT guard and a keyword-SHAPE guard both missed):
  1. **P1b-ii silently broke `expand-brace-branches`.** That expander keys on
     `$brace-params` (parser.rkt, inside `validate-selection-paths`), but
     P1b-ii re-minted `.{` from `$brace-params` to `$dot-brace` and the test
     was never re-pointed. So the brace expansion **stopped firing** and has
     been dead since — a regression nobody noticed, because its only consumer
     was already producing `<error>` values at 0 errors.
  2. **A brace spelling never arrives as a group at all.** The WS reader
     collapses `#p(a.{a1 a2})` into ONE symbol — `(path |:a.{a1 a2}|)` — so
     `parse-path-string` splits on `.` and mints `#:a` and `#:{a1 a2}` as
     ORDINARY KEYWORDS. Both pass any keyword test; the malformed thing is the
     segment's CONTENT. The guard is therefore a shattered-NAME test
     (whitespace or bracket characters in the segment), not a count or a shape
     test. The old `[else (expr-keyword seg)]` coerced this — and rename pairs
     — into a keyword wholesale: the same silent-catch-all class P4a spent its
     whole phase eliminating, one arm away from it.

- <a id="q-u12"></a>**Q_U12 — "WHOLESALE" MEANS THE `$dot-access` LEG ONLY; b-ii SPLITS THREE
  WAYS** ["(b) — $dot-access leg only, split it like b-i", owner 2026-07-31].
  The b-ii mini-audit (`wf_f8568392-b44`, 5 facets + critic @ `2e3fc14e`,
  1.22M tokens) found the ruling's own term ambiguous in a way nobody had
  anticipated: **the sort axis is THREE-valued, not two.**
  `rewrite-dot-access` has THREE live access legs minting THREE DIFFERENT
  nodes, each with its own subject-dispatch table:

  | leg | mints | block counterpart |
  |---|---|---|
  | `$dot-access` | `expr-map-get` | `x{…}` |
  | `$nil-dot-access` (`#.f`) | `expr-nil-safe-get` | **NONE** — `#{…}` does not exist |
  | `$postfix-index` (`[k]`) | `expr-get` | — |

  And the two PATH nodes have **divergent subject tables**: `expr-map-get`
  has a union leg `expr-get` lacks; `expr-get` has PVec **and List** legs
  `expr-map-get` lacks — so **`List` is a subject row the 2-D table's own
  enumeration omitted.**
  **The ruling**: b-ii migrates the **`$dot-access` leg only**. This is NOT
  the complection Q_U6 rejected — that objection was one SORT on two
  representations, whereas nil-safe access and ordinal/dynamic indexing are
  genuinely DIFFERENT SORTS, not spellings of one thing. Scoping to the
  named-step sort is where the Map posture and the (subject × sort) table
  actually live. `#.field` and `[k]` keep their nodes; their migration is a
  named follow-up, not an omission.
  **b-ii splits like b-i**: **b-ii-1** the Map posture + the semantic table
  (typing side) → **b-ii-2** the fold migration → **b-ii-3** the `_.field`
  rescue. Each with its own failing-test-first pass, because the per-caller
  obligations are **NOT uniform** (below).

**The P4c opening rulings [owner, 2026-08-01]:**

- <a id="q-u16"></a>**⭐ Q_U16 — THE BINDER UNWRAP MOVES TO A READER POST-PASS; Q_U8 SURVIVES,
  ONE LAYER EARLIER.** ["That looks like the appropriate shape."]
  **Q_U8 as ruled was NOT IMPLEMENTABLE**, and the refutation is verified, not
  argued. The P4c grounding audit (`wf_d7c035da-cee`, 6 facets + completeness
  critic @ `532474c0`, 7 agents / 1.53M tokens) found that §Q8.5 invariant 3
  site 8 (join `access-sentinel?` + take a `rewrite-dot-access` arm) and Q_U8's
  parser position-dispatch are **MUTUALLY EXCLUSIVE**: the preparse fold RUNS
  OVER BINDER POSITIONS. Main-session probe at HEAD, with the existing
  structural analogue: `ns t` + `defn f [x.a] x` → **`f : _ _ _ -> _ defined.`
  — a THREE-arity function at ZERO errors.** So `[x:Int]` would never reach the
  parser's binder consumers intact, and the parser cannot dispatch by position
  at a seat the sentinel never arrives at.
  **The escape that was tried and DOES NOT WORK** (recorded because it was the
  main session's own lean, and the adversarial options panel `wf_6f15c6ae-6a7`
  killed it): drop `access-sentinel?` membership and let the PARSER fuse, on the
  `$brace-params` precedent. Refuted on two independent grounds. (i)
  `rewrite-dot-access` has **FOUR call seats** — macros.rkt:2004 (map-literal
  contents) · :2714 (main preparse) · :6564 (the `|>` expander) · :6950 (the
  `$mixfix` expander) — and **TWO run inside PREPARSE, before the parser
  exists**, so `users:name` would work in plain application and break inside
  pipes, `.( )` operands and map literals. (ii) The `$brace-params` precedent is
  the WRONG STRUCTURAL CLASS: it is self-contained and never fuses onto a base,
  whereas **every base-consuming marker in the tree without exception is an
  `access-sentinel?` member**. Measured at HEAD: `[f x{a}]` groups to
  `(f x ($select-brace a))` and the FOLD makes it `(f ($select x a))`; without
  the fold `[f users:name]` stays three items and `f` receives TWO arguments.
  **THE RULING — the owner's reframe, and it keeps BOTH surfaces**
  [owner: "I want to keep the fused syntax (even more important than
  broadcast), and I have a strong preference for `:` as the broadcast glyph"]:
  1. **Mint UNIFORMLY at grouping** — Q_U8's positional rule stands verbatim,
     no context list, no tokenizer change.
  2. **`$bcast-step` JOINS `access-sentinel?`** and takes its fold arm, so it
     inherits all FOUR seats for free — which is exactly what the rejected
     escape could not do.
  3. **The binder UNWRAP moves to the READER POST-PASS** —
     `transform-let-blocks-stx` (parse-reader.rkt:2716), verified a GENERAL
     recursive syntax walk run from the reader's own entry point, already doing
     head-keyed structural classification (`let-headed?` · `classify-let-block`
     · `mark-let-goal-rhs` · `skip-reader-form-body`), and running at READER
     time — therefore **provably before all four fold seats**.
  **The owner's discriminator, and why it moved one axis over.** The proposal
  was to disambiguate on *whether the symbol left of `:` is a collection*. The
  premise is CORRECT and measured — the contexts genuinely differ (of **289**
  live multiplicity tokens **287 are SPACED**; the whole measured collision is
  **SEVEN** sites, every one a fused TYPE annotation in a BINDER position;
  broadcast lives in EXPRESSION position). But "is it a collection" is a **TYPE**
  question and the mint fires THREE LAYERS before typing — the same
  discriminator **Q_U10 already rejected as its option (c)** ("incoherent,
  elaboration precedes typing so the discriminator is not available where the
  mint happens"). It is not total even at typing: in `x:Int` the `x` is being
  BOUND and has no type yet by definition. The distinction that IS available
  early is **binder position vs expression position** — the same instinct,
  applied at the axis the pipeline can actually see.
  **BONUS, and it is why this is a repair rather than scaffolding**: the fold
  running over binder positions is a **LIVE LATENT DEFECT** today (`defn f
  [x.a] x` → 3-arity at zero errors). P4c is the phase that SURFACES it, not
  the phase that causes it.
  **COST, BOOKED PLAINLY — do not soften this**: the binding-form head list is
  a **PERMANENT hand-maintained enumeration with a SILENT failure mode** and
  **no retirement plan**. Not "almost a plan." Three conditions ride with it:
  (a) the unwrap is `eq?`-preserving BY CONSTRUCTION (the file already carries
  that warning at :2559); (b) **every binding form gets a test pin so a new form
  without an entry fails RED**; (c) the binder entries are made TOTAL, so an
  unrecognized shape is LOUD — otherwise a missed form reproduces the 3-arity
  class the ruling exists to fix.
  Rejected-with-reason: **moving the broadcast glyph off `:`** (would dissolve
  the cluster, but revisits the six-glyph mnemonic family — owner: strong
  preference for `:`; also BLOCKED, nobody verified a candidate glyph lexes
  intact where `:` does not) · **retiring the fused `[x:Int]` annotation** (the
  cheapest resolution by far — 7 corpus sites + 8 datum pins — but the owner
  ruled the fused surface MORE important than broadcast) · **parser-side fusion
  without membership** (the four-seat refutation above).

- <a id="q-u16b"></a>**Q_U16b — `users:0` IS A LEGAL ω STEP** [owner, 2026-08-01]. So the gate
  serves BOTH bands, and the discrimination question is LIVE.
  **Consequence, measured**: `colon-annotation`'s registered classifier returns
  **`'symbol`** (parse-reader.rkt:1166) while `keyword` returns `'keyword`
  (:1226), so the ordinal band is type-INDISTINGUISHABLE at grouping. Had the
  answer been NO, a gate keyed on `(eq? type 'keyword)` would have been
  dispatchable at HEAD with zero new machinery (colon-annotation would-mint is
  **ZERO** by census), six of the eight flipping datum pins would stop flipping,
  and the L1-fusion pin would have had to move off its corpus line. The owner
  took the fuller surface; the L1 pin **keeps** `users:0:userName`.
  **MECHANISM — settled by MEASUREMENT, not by ruling**: promote
  `colon-annotation` to a real token type. The rival (carry a pattern-provenance
  field on `token-entry`) was costed by the panel at three mutually incompatible
  numbers (25 / 10 / ~14–16) with OPPOSITE verdicts drawn from them; the main
  session enumerated exhaustively at HEAD — **25 constructor sites across 7
  files** (14 production · 11 test/bench) plus 1 `struct-copy`, and
  **`sre-rewrite.rkt` holds 4 of them, borrowing `token-entry` as a
  general-purpose term carrier** (`'binding`/`'sample`/`'constant`). That makes
  the provenance field a struct-OWNERSHIP question, not a field addition.
  Classifier-promotion wins on cost by an order of magnitude. ⚠ Ship it with an
  EXPLICIT arm at `token-entry->stx`, never relying on the `[else]` — its safety
  today is a coincidence of two else-arms doing the identity thing at the exact
  site the file documents as its silent-miss hazard, and coincidental safety
  expires silently. The provenance field is filed on its OWN merits
  (`$exp-literal` + `$rat-literal`, both self-documented as identity-erased),
  NOT as this gate's justification, and NOT as a scheduled revert of the
  classifier change — they are RIVALS carrying the same information, and "ship
  one with a revert clause" is the dual-path shape the rules block.

- <a id="q-u17"></a>**⭐ Q_U17 — A PATH SEGMENT IS A FIRST-CLASS `Step` VALUE.
  RULED B2** [owner, 2026-08-02 — "Assent to B2; place it as its own slice"].
  Opened at the owner's request, their stated concern being "bring Path
  Selection closest to FIRST-CLASSNESS". **Placement: its own slice — `PF`**
  (not inside P4c), because the `Step` reification and the `path-segments`
  repair are one change (U17b) and **P5's B3 same-spine merge depends on it**.
  **The defect.** The step vocabulary is a CLOSED UNION of SIX kinds, but the
  first-class API declares `segments : Path -> [List Keyword]` — true of exactly
  ONE kind. And `path-segments` **already whole-file aborts** (pre-existing,
  `f072c115`): it hand-builds a Prologos cons-chain where the marshaller wants a
  RACKET list, so that type has NEVER marshalled and `from-segments` /
  `path-append` are dead with it. **Path first-classness today is DECLARED, NOT
  DELIVERED.** Eleven production sites (path-ops ×5, reduction ×4, elaborator ×2)
  read segments as bare symbols via `(expr-keyword seg)` — a silent type lie for
  four of the six kinds. ω is the sixth member of an already-false contract; it
  does not create the gap, it makes it unignorable.
  **Proposed ruling — B2, REIFY a `Step` ADT**: `data Step` mirroring
  `select-step-kind`'s six kinds, `Path` stays GROUND and unparameterized,
  `segments : Path -> [List Step]`. Modelled on the `Datum` reification (8
  constructors, `prologos::data::datum`) — the pattern, NOT Datum-as-carrier,
  which Q_U5 already rejected.
  **Every alternative disqualified, each on a named ground**: **B1 defer** — by
  *Spec as Living Interface* (a live lie about a function that also aborts), NOT
  by First-Class-by-Default, whose foreclosure clause does not bite because Q_U5
  already made the first-class decision and the pending composition is NAMED;
  and there is **no zero-cost B1**, since the honest minimum deletes three dead
  declarations. **B3 parameterize** — UNNECESSARY: `step-sub` recurses through
  `List`, not `Path` (exactly as `datum-cons` recurses through `Datum`), so no
  parameterization and no mutual recursion is needed. **B4 un-unify** — reverses
  Q_U5's central ruling, reached through a four-step walk including an owner
  rejection. **B5 narrow** — First-Class by Default names this case almost
  verbatim (premature opacity). **B6 eliminator-first** (emergent, and the
  sharpest) — expressively EQUAL to B2, differing only in whether the
  intermediate is a first-class VALUE; under the Hyperlattice reading **a `data
  Step` is a lattice element** (mergeable, cell-storable, unifiable) and **a
  continuation is not** — the same argument Q_U5 used against selector-as-
  function. Disqualified because **P5's scope includes "B3 same-spine merge"**
  (verified from the tracker), which requires structural path comparison.
  **U17b — the repair and the typing are ONE change.** `racket-list->prologos-list`
  already exists in the marshaller, so the abort is fixed by returning a Racket
  list — but the repair must decide WHAT it returns. Fix it to keywords and the
  lie is re-enshrined; fix it to `Step` and the spec becomes true. Marshalling
  template already in-tree: `datum->datum-expr`.
  **U17c — P4c-4b PROCEEDS UNCHANGED** (all three panel clusters agree). The
  encoding is not where first-classness is won or lost: `(@bcast step)` is a
  unary constructor of a closed union with ONE producer and ONE classifier, so
  converting it later is cheap *because that is already the ADT shape*. Two
  riders, both main-thread verified: the `.pnet` gate item **drops** (`expr-path`
  IS registered — `regN! expr-path`), and the four "a wrapper never heads a
  branch" comments should be corrected in the same commit, polarity inverted
  (the index must PERMIT ω-at-head) — three of them justify an arm by a claim
  the same file refutes.
  **COST, honestly**: TWO ADTs, not one — the `cont` vocabulary
  (`dissolve | synth | collapse | collapse-synth | (rename . k) |
  (collapse-rename . k)`) reifies alongside `Step`. And it inherits the tax the
  `Datum` module documents in its own comment: wildcard `_` in a match over a
  user data type "triggers a type-inference limitation that causes module
  loading to fail", so every `Step` consumer enumerates all six arms. A known
  inference bug, not a design property — but real today.
  **INCOMPLETE BECAUSE** the eleven consumer sites migrate through one
  marshaller, which is not P4c-4b's work; deferred to the slice that also
  repairs `path-segments` (the same change, per U17b) — **now slice `PF`**.
  Grounding: options panel `wf_68178bd3-eea` (7 agents / 1.24M tokens), every
  load-bearing claim R-lens-verified on the main thread.
  **Next free Q-label after this: U20.**

- <a id="q-u18"></a>**⭐ Q_U18 — RULED IN FULL [owner, 2026-08-02].**
  **(i) The unknown-head default flips to PRESERVE** ("worth the trade").
  **(ii) The grant is G4** — hold TEST-ONLY until P4c-4c's value semantics land,
  then grant. **G2 (retire the enable-set) is the recorded LEAN, NOT a ruling** —
  to land with or after P4c-4c, and **RE-EVALUATED at that point**.
  *(Original framing, kept because the correction below is the point:)* the
  unknown-head policy AND the first production grant are ONE decision, and it
  GATES EVERY CORPUS UNCOMMENT.
  Opened 2026-08-02 at the P4c-4c mini-audit. They look like two questions and
  are one: the policy is *why* there is no production grant, so until it is
  ruled the entire broadcast surface is reachable only from tests. **That is the
  "Validated ≠ Deployed" shape and it should be named as such**, not left in
  DEFERRED.
  **THE MEASUREMENT THAT FORCES IT** (re-verified on the main thread at
  `17086a09`): a **bare top-level ω is STRIPPED under EVERY grant** —
  `users:name` → `((users :name))` even when its own head `users` is granted,
  even under a broad grant — because the head is unknown to both the cond and
  the scanner, so `[else]` blanket-strips. **Every ω line in the acceptance file
  is a bare top-level command**, so no acceptance marker can be exercised at
  all. Compounding: `broadcast-enabled-contexts` has **ZERO production setters**,
  so `process-file` runs at default `'()` regardless.
  **WHY IT IS HARD, and it is not new**: P4c-3 measured that the head-keyed walk
  **cannot decide it in EITHER direction** — strip kills application-position
  broadcast, preserve regresses live binder positions under unknown heads
  (`[add ?x:Nat ?y:Nat] = 5N`) — ⚠ **THAT HALF IS REFUTED, see below**, and both spellings were claimed to be `[SYMBOL item item]`,
  structurally indistinguishable at the reader. So Q_U18 is not "pick an arm";
  it is "find the discriminator, or rule that broadcast ships only where a
  recognized head scopes it." DEFERRED 32's open half is this question.
  **DUE**: before ANY corpus uncomment. Nothing in P4c-4c or P4d's carrier work
  depends on it; every acceptance-marker deliverable does.

  **⭐⭐ CORRECTION 2026-08-02 — THE COUNTER-EXAMPLE AGAINST *PRESERVE* DOES NOT
  EXIST, AND THIS REOPENS THE QUESTION.** `?x:Nat` is glued into **ONE TOKEN** by
  `recognize-narrow-var-annot`, so `bcast-step-trigger?` can NEVER fire on it.
  Measured at `526d3de1`: `[add ?x:Nat ?y:Nat] = 5N` reads as
  `((= (add ?x:Nat ?y:Nat) ($nat-literal 5)))` — byte-identical under a grant of
  `add`; **no `$bcast-step` is minted**. So the two spellings are NOT both
  `[SYMBOL item item]`: one is `[SYMBOL glued-token glued-token]`, the other
  `[SYMBOL base ($bcast-step …)]`.
  ⚠ **`parse-reader.rkt`'s OWN COMMENT already said this** — *"Immune by
  construction: `?x:T` (glued to ONE token by narrow-var-annot)"* — in the very
  file being edited. The false claim was INFERRED from "this corpus line runs 0
  errors today" **without checking whether it MINTS**; that is the
  assert-a-mechanism-instead-of-measuring-it failure this arc keeps recording,
  and the tree contained the refutation in a comment.
  **WHAT NOW HOLDS, MEASURED**:
  · **PRESERVE has ZERO measured corpus regressions** — an exhaustive census over
    **795 `.prologos` files plus WS strings embedded in `.rkt` tests** found NO
    live site that is "plain-identifier fused annotation · binder position ·
    unknown head". Every binder-shaped site is either under a head the walk
    already recognizes (`defn` ×5, `let` ×4, `defr` ×1) or is `?`-glued and never
    mints.
  · The five "measured casualties" of the pre-inversion default (`capability`,
    `Pi`, `Sigma`, `DSend`, `DRecv`) have **ZERO fused-annotation sites** in
    `lib` or `examples` — they were **SYNTHETIC PROBES**, not corpus sites. Real,
    but they price the risk very differently from "the corpus breaks".
  · **The `?`-glue has ONE HOLE: digit-headed segments.** `?x:0` DOES mint
    (`((def q := ?x ($bcast-step :0)))`); `?x:Nat`, `?x:w`, `?x:Int:Even` all
    glue. Verified.
  · **The one PRINCIPLED counter-example** is macro pattern variables:
    `pattern-var?` accepts any symbol not in ~20 enumerated reader sentinels, so
    `[myform x:Int]` is a genuine binder under a genuinely unknown head. **Zero
    instances in tree; constructible in one line.**
  **⭐ AND A THIRD SEAT THE FRAMING MISSED**: `parser.rkt` already ships a
  `bcast-step-binder` diagnostic kind distinct from the expression-position
  `bcast-step`, raised from **THREE binder consumers**, whose message reads
  *"this is a BINDER position … the fused spelling should work here"*. **The
  parser can already tell the two apart — because a binder consumer knows it is
  one.** So the honest form of Q_U18 may not be "which arm does the READER pick"
  but "**why is the reader deciding this at all?**"
  Grounding: options panel `wf_46bd24b7-5ca` (7 agents / 1.32M tokens); both
  refutations re-verified on the main thread before being recorded.

  ---

  **⭐ THE RULING (policy half) — owner, 2026-08-02: "worth the trade".**
  **The unknown-head arm flips from STRIP to PRESERVE.** Adopted as option `O1`,
  *"the sigil already IS the discriminator"* — and the word **already** is what
  makes it a ruling rather than a gamble:
  · `recognize-narrow-var-annot` GLUES `?x:Nat` into ONE TOKEN, so the
    logic-variable binder population **cannot mint, by construction** — not by
    enumeration, not by a maintained table. That is the discriminator the
    question was hunting for, and it was already in the tree one layer below
    the walk.
  · **PRESERVE therefore has ZERO measured corpus regressions** (795-file
    census). The evidence that had motivated STRIP was thinner than recorded:
    the five "measured casualties" were **synthetic probes**, not corpus sites.
  ~~**OWED WITH IT — the one real defect the sigil analysis exposed**: close the
  DIGIT-HEADED HOLE.~~
  ⚠ **CORRECTED 2026-08-02, BEFORE ANY CODE — "the one real defect" IS NOT ONE.**
  I recorded the digit hole from the READER DATUM alone (`?x:0` does not glue and
  does mint) without probing what the spelling MEANS end to end. Measured:
  **`?x:0` and `?x:w` are BOTH ALREADY REFUSED**, by an existing guided
  diagnostic that names them explicitly — *"`:0` is not a type — a fused
  parameter annotation must name one, as in `x:Int` (digit-headed `:0`/`:7` and
  `:w`/`:m` are multiplicities)"*. Only `?x:Nat` is legal (`r : _ defined.`).
  **So there is NO legal spelling at risk**, and the gluing asymmetry between
  `?x:0` and `?x:w` is invisible: both reach the same refusal by different routes.
  Narrower still: the PRESERVE flip only changes the **unknown-head** arm, and
  `defr`/`defn`/`spec`/… are all RECOGNIZED, so the scanner answers for them and
  the flip never runs there. The residual is `?x:0` **under an unknown head** —
  an already-illegal spelling under a head the walk does not know. The
  consequence is a **diagnostic-quality change** (the `bcast-step-binder` message
  instead of the sharper multiplicity one), not a break.
  **NOTHING IS OWED AS A PREREQUISITE.** If the sharper diagnostic is worth
  protecting that is a diagnostic-quality item, booked rather than landed here.
  ⚠ Third time this session a recorded mechanism claim fell to an end-to-end
  probe, and the pattern each time was **reading the datum and inferring the
  meaning**.
  **THE ACCEPTED RESIDUAL, named rather than smoothed over**: `pattern-var?`
  accepts any symbol not in ~20 enumerated reader sentinels, so macro pattern
  variables need no sigil — `[myform x:Int]` is a genuine binder under a
  genuinely unknown head. **Zero instances in tree; constructible in one line.**
  Under PRESERVE it takes the EXISTING `bcast-step-binder` arm, a per-command
  guided error already saying *"this is a BINDER position … the fused spelling
  should work here"*. So the failure is LOUD and RECOVERABLE.
  ⚠ **This is a knowing, narrow exception to the INVERTED DEFAULT's criterion**
  ("a miss must never mean *your working code now errors*"), and it is recorded
  as such: it errors only for code that **does not exist in the tree**, the
  diagnostic already exists, and the alternative — STRIP — makes broadcast in
  application position permanently unreachable, which the acceptance-marker
  evidence shows is most of the feature. **Trade accepted by the owner on that
  framing.**
  **⭐ THE GRANT — RULED G4** [owner, 2026-08-02]: **hold TEST-ONLY until
  P4c-4c's value semantics land, then grant.** The enable-set STAYS, production
  stays at default `'()`, and broadcast remains reachable only from tests until
  there is something for it to evaluate to. Sequencing, not mechanism — and the
  honest reading of "Validated ≠ Deployed": the gap is now **scheduled and
  named**, with P4c-4c as its discharge, rather than left open-ended.

  **⭐ G2 IS NOW RULED — IT LANDS *ALONGSIDE* P4c-4c** [owner, 2026-08-04:
  *"G2 alongside P4c-4c"*]. G2 = retire the enable-set entirely; head-specific
  dispatch becomes unconditional. The re-evaluation the ruling below scheduled
  was **held at the P4c-4c opening and resolved there**, on the §4.1 framing:
  the flip is inert until G2, so G2 is not cleanup but *the thing that delivers
  the feature*, and P4c-4c's value semantics are what make the working set
  observable — which is the input to the G2 decision. Landing them together is
  what makes that input available at the moment it is needed, instead of
  shipping value semantics for a surface nothing can reach.
  ⚠ **CONSEQUENCE, and it is the operative one for the slice**: G2 is the FIRST
  change in this arc where **production behaviour actually moves.** Every prior
  P4c slice was byte-identical at the default `'()` and could lean on that; from
  here the **corpus A/B is load-bearing, not a formality**, and the P4c-4b
  targeting (12 mintable files) must be RE-DERIVED rather than inherited.
  ⚠ **And the test surface inverts**: P4c-4a's pins were mutation-verified
  AGAINST the grant seam, and one is named for *"the flip is INERT AT DEFAULT"*.
  Retiring the seam turns some of those pins RED and — the worse case — makes
  others **VACUOUS**. Both classes must be enumerated separately before the edit;
  a pin that silently stops discriminating is the failure this track keeps
  paying for.
  The argument FOR G2, recorded at the time it was still a lean and unchanged by
  the ruling:
  · its stated justification has expired TWICE — "the sentinel has no consumer
    until P4c-3" (the consumer exists) and gating the head-keyed decision (now
    settled by (i));
  · keeping a mechanism alongside a settled decision is this project's
    **belt-and-suspenders red flag**, not defence-in-depth;
  · the **CHAIN rule** — an ungranted ancestor strips a granted descendant,
    granting `wrap` does not help while granting `defn` does — exists ONLY
    because there is an "ungranted" state to inherit. G2 dissolves it.
  ~~**RE-EVALUATION TRIGGER**: at P4c-4c's close~~ — **HELD AND RESOLVED at the
  P4c-4c OPENING instead** (owner, 2026-08-04): G2 lands **alongside** P4c-4c,
  not after it. The trigger is struck rather than deleted because the reason it
  moved is the substance: waiting for the close would have meant shipping value
  semantics for a surface that nothing outside the battery can reach.

  **✅ THE FLIP LANDED — `e71ef6b8`** (suite 9835/482/0 · battery 340 → 344 ·
  acceptance unchanged · default behaviour pinned unchanged). Two findings from
  landing it, both recorded because they correct this very entry:

  1. ⚠ **THE "ONE REAL DEFECT" — the digit-headed hole — IS NOT A DEFECT.** See
     the struck text above: `?x:0` AND `?x:w` are BOTH already refused by an
     existing guided diagnostic. No legal spelling was at risk. Nothing owed.
  2. ⚠⚠ **THE FLIP IS INERT IN PRACTICE UNTIL G2, WHICH REFRAMES G2 ENTIRELY.**
     It works — with the inner head granted, `[one users:name]` becomes
     `(one users ($bcast-step :name))`, and it nests. But the enable-set's FIRST
     arm strips any node whose OWN head is not granted, and granting every
     function name is absurd. **So the flip alone does NOT unlock
     application position.** G2 is not "retire expired scaffolding" — it is
     **the thing that delivers the feature**. Pinned in the battery
     ("Q_U18: the flip is INERT AT DEFAULT") so it cannot be forgotten.
     ⇒ **When G2 is re-evaluated at P4c-4c's close, weigh it as a FEATURE
     decision, not a cleanup.** Consider whether the re-evaluation belongs
     ALONGSIDE P4c-4c rather than strictly after, since P4c-4c's value semantics
     are what make the working set observable, and that observation is the input
     to the G2 decision.
     ✅ **THAT IS WHAT THE OWNER RULED, 2026-08-04 — ALONGSIDE.** See the G2
     block above; the re-evaluation trigger moved from P4c-4c's close to its
     opening.

  **⚠ SEQUENCING NOTE — (i) IS INERT AT DEFAULT AND CAN LAND EARLY.** The
  unknown-head arm only runs when preservation is ACTIVE; at `'()` the first arm
  blanket-strips and that arm never executes. So the PRESERVE flip **and the
  digit-hole fix** are testable through the P4c-4a grant seam and safe to land
  before the grant itself — they change nothing a user can see until G4 fires.

- <a id="q-u19"></a>**⭐ Q_U19 — `^` ON A BROADCAST: THE PATH-POSITION REFUSAL IS
  RATIFIED; ONE GUIDED MESSAGE UNIFIES THE THREE ROUTES [owner, 2026-08-07 —
  "(A) ratify and unify the diagnostics"].**
  **The P4d opening audit reframed the question before it was asked** (measured
  at `ea9c19e4`, re-verified on the main thread): `^` on an ω step **already
  re-keys, semantically, in BLOCK position** — `cfg{admins:name^alias}` →
  `{:admins @[{:alias "a"} …]} : {:admins [PVec {:alias String}]}` at 0 errors,
  and the sub-block spelling `xs:{name^alias}` → `[PVec {:alias String}]`
  likewise — so the choice was never *refuse vs build re-keying*; it was
  whether the PATH spelling should join a shipping block behaviour. **Ruled NO,
  on the structural asymmetry**: in block position the ω output HAS a key (the
  block entry) for `^` to rename; in path position `xs:name` is
  `[PVec String]`, BARE — there is no key to re-key, which is what the existing
  refusal already says. Option (B) — path-position promote, `xs:name^alias` ⇒
  `[PVec {:alias String}]` — REJECTED: it INVENTS a key rather than renaming
  one (a different operation wearing rename's spelling), and the block spelling
  already expresses that intent. Monotone (spec §3.6): the ratified refusal can
  become a meaning later at zero cost.
  **The measured path-position surface was THREE behaviours, two unguided**
  (all per-command, no aborts — each probed with a following `def` that
  survives):
  · `xs:name^alias` / `xs:name^` / `xs:name^_` → the pre-existing guided
    refusal — whose text says "a **field access** has no output key", the wrong
    noun for an ω step;
  · `xs:{name}^alias` / `xs:{name}^` → **`Unbound variable ^`** (unguided);
  · `xs:0^alias` → **`Unbound variable :`** (unguided, blaming the wrong
    token).
  **Deliverables (P4d, riding the diagnostics slice)**: ONE broadcast-aware
  guided refusal covering all three routes — name the ω step, state the
  no-output-key ground, and point at the block spelling that works
  (`xs:{name^alias}`, probe-verified above); route both unbound-variable
  fall-throughs into it; update the "P4c-4b: the payload's THREE sub-cases" pin
  to pin the DECISION (it froze an accident; it must now fail for the reason
  its name claims). ⚠ The original entry's "under a grant" clause is OBE — G2
  retired the grant, so the surface is reachable UNCONDITIONALLY at the
  production default.
  *(Original entry, kept for the record:)* Opened 2026-08-02 at the P4c-4c
  mini-audit. Under a grant the parser ALREADY builds
  `(@bcast (@key name (rename alias)))` — it is constructible today — and it
  lands on the pre-existing `^`-in-path-access refusal **only because
  `select-step-cont` was made ω-transparent at P4c-3a**. Whether the intended
  behaviour is *refused, guided* or *re-keys the broadcast output* is stated
  nowhere. The pin at `tests/test-path-selection.rkt` ("P4c-4b: the payload's
  THREE sub-cases") therefore froze an ACCIDENT, not a ruling.

- <a id="q-u20"></a>**⭐ Q_U20 — A SUB-INNER ω ASSEMBLES AT 'block, ALWAYS
  [owner, 2026-08-05 — "Assent — sub-inner assembles at 'block, always"].**
  The lift threads exactly ONE sort, and the two inner kinds need OPPOSITE ones:
  a SYMBOL inner extracts ('path — 'block would wrap `xs:a` as `[PVec {:a T}]`),
  a SUB inner assembles ('block — 'path fails its one-component constraint). So
  the lift takes a PER-INNER-KIND sort decision: `users:{a b}` over
  `[PVec {:a A :b B}]` is a PVec of NARROWED ROWS, `[PVec {:a A :b B}]`, by
  applying the sub-block's OWN branches to each element at 'block and
  re-wrapping. The spec (§3.2.1) and the corpus's own expected values both state
  this reading; the extent pair only makes sense under it. Hard-coded as a
  semantics RULE of the lift rather than inherited from context — that is the
  ruling, not an implementation accident. Grounding: mini-audit
  `wf_e15a1ef6-dfb` (its sub-inner facet measured the sort collision at both
  layers). **Next free Q-label: U21.**

**Open, GATING (spec §8):**
- ~~**Q8** (the precise lexical grammar)~~ — **CLOSED 2026-07-28**: written at
  P1b-i, **owner-reviewed**, and ruled (Q_M8 the sole amendment). §Q8 is now
  normative for P1b-ii/iii and P2.
- Keyword-projection disposition (§2.4) — revisit when P4 lands broadcast
  (likely subsumed by `users:name`).
**Carried from the P3 mini-audit [owner, 2026-07-28], still standing:**
- `#:keyword` retires with the `#.:name` twin (`#.name` survives).
- ~~`^` splitting is **P3**-parser-side via POL.6 `split-fused-symbol` — no
  second splitter~~ — **SUPERSEDED by Q_M7 above**, which found this ruling not
  executable (`split-fused-symbol` splits on `":"` and rejects >2 segments; the
  tree's only `^` splitter is the sexp-only `validate-selection-paths`). It is
  struck here rather than left standing, because two contradictory statements
  eleven lines apart in the same section is exactly how P3 would inherit the
  false premise Q_M7 was written to prevent.
- ~~`.-1` = classifier-level rejection~~ — **SUPERSEDED** by §Q8.1 + §5.P2:
  `.-1` (and `.+1`) LEX CLEANLY as dot-access with a signed field, so the
  rejection is a CONSUMER decision, not a classifier one; pinned at P2.
  Negative bracket/`get` payloads = a static error at the grouping seat
  alongside `m[:a]` (landed P1a).
- ~~`.:.`/`.:[` tokens defer to P5~~ — **MOOT**: the new broadcast is bare
  `:s`; no `.:` tokens exist in the surface at all.

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

<a id="p0"></a>

### §5.P0 — Acceptance corpus

**✅ LANDED `e2674208` — 28/28 markers, 0 errors** (was 21/21).

**Intent [owner]: AUGMENT the existing acceptance file** —
`examples/2026-07-26-ciu-t6-path-selection.prologos` — with the spec's §10
examples and Appendix fixtures. One file, not two: it already held the P0
charter and its working markers are live P1/P2 substrate regression.

**What landed**:
- **All 7 spec Appendix fixtures load** (`users` · `build` · `regions` ·
  `strings` · `m` · `events` · `tree`). Layout bodies use the `def X`
  implicit-map form — the `def X :=` form hits **issue #80** (filed).
  `now`/`env` stubs carry indicative values (the staged-demand ruling 4a).
- **Fixture convergence**: `app-config` gained `:date [now]` and
  `:url [env "DATABASE_URL"]` per the spec Appendix; its marker was
  re-transcribed.
- **The dead old-bracket-surface targets were REPLACED** with the phase-tagged
  spec corpus in HEAD notation: §B blocks [P3] · §C splat + Ruling B [P4/P5] ·
  §D broadcast [P4] · §I the §10.2–§10.8 corpus (incl. disclose `:<`). §10.6
  transposes and §10.8 recursion stay PERMANENTLY commented with their
  v2/exit pointers.
- **The `v[0]` NOTE was corrected** — the PS2 flip is canceled, so that pin is
  now a MUST-NOT-BREAK regression, not a flip warning.
- **Two fixture outputs double as §2.3 carrier documentation**: `users`
  exhibits the literal-arm 1-tuple collapse (which ruling 2a routes around),
  and `events` pins the het-tuple carrier that the 2b split's first rule
  targets.

**Normativity protocol (refined by ruling, Batch 1)**: the corpus is executable
spec. Divergence between file and spec in **NOTATION** is transcription —
resolved by the §2.3 table. Divergence in **RESULT** is semantics — resolved by
ruling, **never by quietly editing a marker**.

**Still open here**: the spec fixture's computed leaves force EAGERLY until
§5.P6, so the §1.3 demand property is a marker COMMENT, not an assertion, in
v1. Forced values are indicative (spec §10 preamble), so every other §10 result
is unaffected.

**At X.close**: the file promotes to a suite-gated regression test.

**Test delta**: the augmented file + its `--check` gate — **28/28** (from
21/21); records acceptance unchanged at 89/89; zero production code touched.

<a id="p1"></a>

### §5.P1 — The lexical seams + the retirement batch

**SPLIT into P1a + P1b (owner Q_L6)** after the mini-audit
(`wf_789e4f0f-f02`, 7 facets + completeness critic @ `5c171caa`; raw output:
`/private/tmp/claude-501/…/tasks/w1vsud0hy.output` + per-agent journal in the
workflow transcript dir — session-local; the durable findings are THIS
section). The audit **refuted the phase's central ruling** (3d — see Q_L1),
found the `.{` glyph NOT free, re-scoped the `broadcast-get` retirement, and
proved the named diagnostic template is a whole-file abort. The unbroken
mini-audit-refutes-premise streak continues (8th consecutive).

**Audit record — the grounded facts P1a/P1b build on** (all main-session
R-lens-verified unless marked):

- **The dot band is EXACTLY five** recognizers, proven exhaustive (`char=? c1
  #\.` at parse-reader.rkt :713/:730/:748/:762/:771; `ident-start?` omits `.`):
  rest-89 · dot-key-88 · dot-lparen-87 · broadcast-87 · dot-access-86.
  Prefix-disjointness — not priority — is what makes a `dot-lbrace` token safe
  (dot-access :732 already excludes `{`; every other member requires a
  different second char). ⚠ D4 carried a stale 3-member cite of this band in
  one place alongside the correct 5-member cite (fixed with this fold).
- **The "three-layer opener co-update" is SIX sites**: registration
  (:1091-1092 shape) · extent frame dispatch (:1310) · extent langle skip-set
  (:1291-1292, in `langle-matched?` :1279) · group-items langle skip-set
  (:2356-2357, in `has-matching-rangle?` :2337) · group-items opener arm
  (:2498-2505) — the framing collapsed the two langle TWINS whose disagreement
  IS the `31d27c83` defect — **plus a SIXTH in a second file**:
- ⚠ **`surface-rewrite.rkt` still carries FULL `dot-lbrace` → retired-mixfix
  routing** (:516-521 `memq` arm → `'mixfix-group`/`mixfix-rbrace`; closer
  legs :507/:510/:537), production-reachable via `group-tree-node` ←
  driver.rkt:2432. `d18648f0`'s "grep = 1 hit" VAG was scoped to
  parse-reader.rkt only. Inert today ONLY because no recognizer emits the
  token — **registering `dot-lbrace` at P1b without this cleanup silently
  wakes retired mixfix semantics**. Hence P1a lands the cleanup BEFORE any
  re-mint. (Two facets found this independently.)
- **`.{` today** (probe): loose `|.|` + `$brace-params`, with FOUR distinct
  downstream errors depending on payload shape (even-count · bare-symbol ·
  unbound-`|.|`) — the design's single cited message was one of four.
- **Census corrections, and the RULE**: the audit's two "refutations" of the
  `.*name`=4 count both measured the DIRTY WORKING TREE (owner WIP had
  commented 3 of 4 sites; Q_L5 disregards those sketches). At HEAD the design
  is right: `.*name` = 4 (first-class-paths :185/:188/:192/:349) · dot-key
  `.:name` = 2 (first-class-paths:43 PREFIX form; punify-p3:441 POSTFIX form —
  two SHAPES, so the migration message covers both) · `racket{…}` = 10 (the
  facet counts of 12/14 included an out-of-tree emacs fixture + comments).
  **Every P1 census runs `git show HEAD:<file>`, never plain grep.**
- **`m[:kw]` is RULE-DEPENDENT**: 22 = loose `[:` lines · **16 =
  adjacency-verified lines (the actionable rule — the retirement discriminates
  on adjacency + keyword-literal payload)** · 30 = occurrences incl. `][:`
  chains. Suite cost: 5 pins flip (test-postfix-index-01:33-35;
  -03:119-124/:142-147/:195/:204); the discriminator must SPARE `m[k]` with
  `k : Keyword` (pinned -03:127-135; live surface-ergonomics:258).
- **The accepted gap is genuine noise**: `first-class-paths.prologos` has ZERO
  `;;N=>` markers and nothing references it outside docs/ — not suite-gated,
  not acceptance-gated. (Disambiguation: `tests/test-first-class-paths.rkt` IS
  suite-gated but is a different artifact whose broadcast coverage is
  commented out.)
- **`expr-broadcast-get` is permissive** (confirmed): `ladmins.*nope` →
  `'[<error> <error>]` at 0 errors — the live silent-wrong-answer under a
  green suite. Retiring the node deletes the defect.
- **Reject-batch reclassification**: `x[]`/`_[sel]`/`.-1`/negative payloads
  have ZERO existing coverage (net-new pins, not flips). Two are
  mis-classified: `v[-1]` is a SILENT WRONG ANSWER today (types `Int`, prints
  a stuck term, 0 errors) and the same defect rides bracket-free
  `[get v -1]`; `_[sel]` fails identically as `[get _ :a]`, so a bracket-only
  rejection leaves the partial-application idiom broken — both scoped
  judgments recorded in §5.P1a.
- **Reader-form heads have NO registry**: the set is `{racket}`, hard-coded
  TWICE (macros.rkt:2431/:2435; driver.rkt:3337), and there is NO module edge
  from parse-reader.rkt to macros.rkt — head recognition lives at PREPARSE
  while adjacency precedence must live at GROUPING. P1b creates the single
  source of truth (a leaf module or registration parameter); the F1b.7g
  inline-list drift class applies directly.
- **WS `racket{…}` has ZERO regression coverage**: `foreign.prologos` is
  `'skip`ed by the runner; all 13 `test-foreign-block.rkt` cases are
  sexp-mode. Ruling 3b's "round-trip pins" are NEW coverage, not preserved.
- **Brace adjacency has a FOURTH bucket** (left token = a CLOSING delimiter:
  `f[x]{a}`, `(g y){a}`) and the positional test's `(pair? result)` conjunct
  is load-bearing — it alone protects 13 live opener-adjacent sites
  (`'[{…}`, `@[{…}`). `$brace-params` is already TRIPLE-purposed (map literal
  · implicit type binder · foreign block) from one sentinel (:2496); the
  largest spaced population is BINDERS (`spec identity {A : Type}` is one
  space from a select block).
- **`:<` severity is INPUT-DEPENDENT**: with no depth-0 `>` in scope the
  probe degrades benignly to an operator reading; with a later depth-0 `>` it
  CROSS-LINE SWALLOWS (two top-level forms collapse into one — trigger:
  `langle-matched?` finds the `>`, close-type `#f` window runs to EOF). The
  Q8 probe row must test BOTH shapes or it reports "no problem".
- **`.` quadruple-duty disambiguation order exists NOWHERE in writing** — Q8
  owes it (R3). And the fourth duty is contested per Q_L2: sexp `.{` fan-out
  (15 live test sites) vs WS `.{` sub-block — divergence institutionalized.
- **Ungated collateral**: 2 golden fixtures embed `($dot-key :name)` (zero
  test callers — go silently stale, note only);
  `benchmarks/micro/bench-ppn-track2.rkt:174` measures a dot-key payload
  under the name "rewrite-dot-access" (already misnamed) — P1a re-points it.
- **Two separable defects → DEFERRED**: the tilde-number seat itself
  whole-file-swallows (a mid-file `~3` silently discards ALL output — the
  exact silence class the new seat exists to prevent); bare top-level `[]`
  hard-aborts with a raw contract violation (parse-reader.rkt:2160-2161
  position-0 stx → macros.rkt:2804 `max` on #f).

<a id="p1a"></a>

### §5.P1a — The retirement batch + substrate  ✅ `859b529d`

**✏ CLOSE NOTES (2026-07-28).** Suite **9253 / 474 / 0** · neighborhood
**477 / 16 files** · acceptance **28/28 + 89/89** · audit-06/-09
differential-identical to HEAD · −744/+320 across 23 files. Written
failing-first: 10 RED guided-diagnostic pins → green.

**What the adversarial verify caught** (3 perspective-diverse skeptics on the
uncommitted diff — the practice paid, and the headline is self-inflicted):
- **BLOCKING, and MINE — the seat introduced the abort it exists to prevent.**
  The marker arm called `(car args)` unguarded, so a user-written zero-arg
  `[$retired-selection]` RAISED at the parse seam and killed the whole file.
  Its three raw-sentinel siblings had carried `(pair? args)` from the start —
  I wrote the guard three times and omitted it on the fourth. Fixed + pinned
  (B5). **Lesson shape: when a new arm joins a family, diff it against its
  siblings, not against its own intent.**
- **SIGNIFICANT, pre-existing** — `pattern-var?` excluded the LIVE sentinels
  but not the retired `$dot-key`/`$nil-dot-key`, so a retired shape inside a
  `defmacro` TEMPLATE read as an unbound pattern variable and raised out of
  preparse: whole-file abort, a retired-surface path that BYPASSES the seat.
  The mini-audit had flagged the asymmetry (facet 3 finding 19); closed here
  because the phase owns that list. Pinned (B6).
- **MINOR** — negative NON-integer indices escaped the guard, and **probing
  corrected the skeptic's own mechanism**: `-1` arrives BARE but `-1.5`/`-2/3`
  arrive WRAPPED as `($decimal-literal -3/2)`/`($rat-literal -2/3)`, so no
  unwrapped numeric test can see them. Hence `negative-index-payload?`. Pinned
  (B7). *(Another "probe before believing the mechanism" data point — this
  time against a report, not a design.)*
- **CONFIRMED**: node deletion complete across reflection consumers + the pnet
  table; zero misfires on every must-survive surface; **`.( )` mixfix fully
  intact INCLUDING comparison chains** — the live pratt path implements them
  natively, so the deleted `expand-comparison-chain` was a redundant dead twin.

**Adaptations made during implementation** (design → code):
- **The seat's conversion point moved preparse → PARSER.** Error VALUES are
  already legal there and flow per-command; preparse Pass 2 has no per-form
  handler and datums are its only legal output. Consequence: retirement
  TOKENS stay as marker emitters, so **all reader token-layer pins stayed
  green** and the churn shrank to rewrite-units + E2E pins.
- **The `m[:kw]` hint in the design row was wrong** — it named `m[a]`, the
  *superseded* surface's spelling. Corrected to `m.a` / `[get m :a]`.
- **The nil-dot-key twins were already broken in WS**, and the mechanism is
  now known: the stx arm kept the RAW LEXEME (`#:name`) as the key, so the
  e2e path died as `Unbound variable`. Their retirement is a message upgrade,
  not a capability removal.
- **test-postfix-index-02 carried a rewrite-unit pin the audit's flip list
  missed** (`m[:key]` → `get`) — found by running, not by reading.

**Recorded, not fixed** (2 pre-existing whole-file aborts, both reproduce
identically at HEAD → DEFERRED): live `.( )` mixfix errors still RAISE
through preparse — the same failure class Q_L4 documents, and **the seat now
exists for them**; and a union-typed def + implicit-binder spec + call hangs
in typing. Also left: chained `m[:a][:b]` reports only the last key
(cosmetic, one correct-class error, continuation intact).

**Test delta**: +14 in `test-path-selection` (10 guided-diagnostic, 4
survivor incl. the direct `definitely-not-map?` conservative-default pin
replacing what the retiring walker tests incidentally carried), +3 defect
pins (B5/B6/B7); 11 flips across `test-dot-access-01/-02`, `test-nil-type`,
`test-postfix-index-02/-03`; the 2 P2.a walker pins retired WITH the node.

---

**Original work list** (as designed; all items landed):

**Work list** (order matters — substrate first):
1. **`surface-rewrite.rkt` `dot-lbrace` cleanup** — delete/re-point the
   :516-521 arm + :507/:510/:537 closer legs. ⚠ Probe first whether the
   `'mixfix-group` consumers (:1412/:1654/:1778/:1789) serve any OTHER live
   producer before touching them. Zero behavioral change expected; the
   `d18648f0` pins must stay green.
2. **The diagnostic seat** (Q_L4), mechanism REFINED by the audit's own
   grounding: the retirement TOKENS/RECOGNIZERS **STAY**, as marker emitters
   (their sentinels `$dot-key`/`$nil-dot-key`/`$broadcast-access` already ride
   the datum stream to every entry path); the preparse REWRITE arms (the
   semantics) are DELETED, normalizing each retired shape to ONE marker head
   `$retired-selection` with a kind tag; **the PARSER converts the marker to a
   per-command `parse-error` VALUE** with the kind-tailored migration message.
   Conversion sits at the parser, not preparse, because parse-error VALUES are
   already legal there and flow per-command (probe: `v[]` → "Unexpected
   datum: ()", file continues — facet 5 [12]), whereas preparse Pass 2 has NO
   per-form handler (macros.rkt:2803-2806) and datums are its only legal
   output. This is `$mixfix-retired`'s marker mechanism with the raise
   replaced by the POL.4 value conversion. Consequence for the test delta:
   ALL token-layer pins (test-parse-reader :395-399/:408-412/:438-442) STAY
   GREEN; only preparse-rewrite units + E2E pins flip. Verify per-command
   continuation E2E on every entry path the seat claims. Two riders recorded:
   the tree-spine merge survives on a latent `loc->line` `(cadr loc)` bug
   (driver.rkt:2468-2473 — noted, not depended on); the sexp tilde template's
   format string is itself malformed (`~ ` consumed by the formatter,
   sexp-readtable.rkt:310) — do not copy it verbatim.
3. **Dot-key family retirement**: `.:name` recognizer + BOTH macros arms (the
   prefix Pattern-2a :5453 leg AND the postfix fold-left :5508 leg — two
   shapes, one guided message naming `.name`); `#.:name` (`$nil-dot-key`) and
   `#:keyword` twins retire; **`#.name` SURVIVES** (must-not-break pins).
   Watch for duplicate/legacy grouping routes (the `d18648f0` two-route
   precedent).
4. **The full `broadcast-get` chain** (Q_L3): reader recognizer (:766, reg
   :1094-1095) · parser keyword (parser.rkt:146 + arm :2332-2350) · surf
   struct (surface-syntax.rkt:251/:894) · elaborator arm (:2394) · the
   `expr-broadcast-get` node per pipeline.md IN FULL (syntax/substitution/
   zonk/reduction whnf+nf arms/pretty-print/pnet-serialize/typing/qtt) ·
   ~~PNET_VERSION bump if the node is tag-registered … a version sweep is the
   only reliable cache invalidation~~ — ⚠ **STRUCK 2026-07-29**: refuted by §8
   R6 as corrected. The tag table is SYMBOL-keyed (additive), and
   `pnet-stale?` already invalidates on `infrastructure-stale?` + a source
   hash, so a bump is owed only when an EXISTING shape's serialization
   changes. P1a itself needed none. (Left visible rather than deleted: this is
   the second copy of the premise the `3cf60868` doc-truth commit was written
   to kill, found by the handoff verification — the "one correction, two
   copies" shape.) The `.*name` guided error names `:name` as the P4
   replacement (the accepted-gap noise, 4 sites). Post-keyword-removal
   diagnostic shapes pinned BOTH ways: `(broadcast-get x :f)` at command
   position = a POL.9 goal → "Unknown procedure"; `[broadcast-get x :f]` =
   unbound variable. Test delta: the 2 walker-safety pins RETIRE with the
   node; the `definitely-not-map?` conservative-default coverage they
   incidentally carried is REPLACED by a direct pin on an arbitrary unarmed
   node (the critic's C3 — do not silently drop the track file's only pin on
   the positive-list default).
5. **`m[:kw]` static error + hint** (preparse-postfix seat): counting rule =
   adjacency-verified (16 lines); ⚠ hint CORRECTED at implementation — the
   carried "names `m[a]` / `get`" was the SUPERSEDED surface's spelling
   (brackets are not selection under the new law; `m[a]` = `(get m a)` with
   unbound `a`). The hint names **`m.a`** (dot descends — works today) and
   **`[get m :a]`**. The 5 flipping pins updated; `m[k]` with `k : Keyword`
   variable stays green (the discriminator is keyword-LITERAL payload, sound
   at the preparse arm since `ident-start?` excludes `:`).
6. **Reject batch**: `x[]` + `_[sel]` graceful static errors at the grouping
   seat (net-new pins). `v[-1]`: static error at the grouping seat for the
   bracket spelling; the bracket-free `[get v -1]` twin is FLAGGED to P2
   (grade-1 core owns `get`'s index discipline) — recorded here so it is not
   lost. `.-1`: NO P1a action — with no `.N` recognizer there is nothing to
   reject yet; lands at P2 as the digit-required classifier design already
   states.
7. **Collateral**: re-point `bench-ppn-track2.rkt:174`'s payload + name; note
   the 2 stale golden fixtures (zero callers, no action).
8. **Recorded decisions**: the `expr?`-predicate gaps on the four surviving
   path siblings (`expr-get-in?`/`expr-update-in?`/`expr-path?`/`expr-Path?`
   — pre-existing, pipeline.md item 1) are LEFT NAMED for P2's mini-audit,
   not closed opportunistically here (retirement slice, not a repair slice).
   PNET: **no version bump** — the tag table is SYMBOL-keyed (removal shifts
   nothing) and zero `.pnet` caches carry the node (grep over all 39; no lib
   module ever used `.*name`); stated honestly: this rests on the
   cache-content census, NOT on `infrastructure-stale?`. Owner-WIP noise
   named eyes-open: `foray.prologos` (~18 live new-surface lines) +
   `today.prologos` (a live `.{` mixfix line) are ungated and will change
   behavior loudly across P1b/P3 — expected, not a regression.

**Test delta**: retirement pins (guided messages + file-continues E2E) in
`test-path-selection.rkt`; reader pins in `test-parse-reader.rkt`; the 5
`m[:kw]` flips in test-postfix-index-01/-03; the `#.name` + `m[k]`-variable
must-not-break pins; the conservative-default replacement pin; net-new reject
pins. Both modes where the surface exists in both. Failing-test-first.
Status: ✅ (see this section's close notes / the tracker).

<a id="p1b"></a>

### §5.P1b — The seams + the Q8 grammar  (SPLIT THREE WAYS, Q_M2)

**Mini-audit `wf_d0862784-5e5`** (6 facets + completeness critic @ `bc0c7578`;
27 critic findings, 22 capture gaps; load-bearing claims R-lens-verified on the
main thread). **9th consecutive phase whose premise the audit refuted.**

**The audit record — grounded facts P1b-i/ii/iii build on:**

- ⚠ **THE HAZARD IS INVERTED.** §5.P1b previously said "the SIX-site
  co-update (five parse-reader sites + the P1a-cleaned surface-rewrite)",
  which reads as DISCHARGED. It is not: `surface-rewrite.rkt:516` is the
  **general brace-opener arm**, alive, needing `dot-lbrace` as a **POSITIVE
  ADDITION**. Probe-verified: the spec flagship
  `app-config{server^.{ssl port} version}` groups **CORRECTLY TODAY** —
  `((app-config ($brace-params server^ |.| ($brace-params ssl port)
  version)))` — precisely BECAUSE `.{` lexes as two tokens and `lbrace` is
  handled at :516. Minting the token without that arm stops it firing, the
  inner `}` closes the OUTER block, and `version` is expelled. **P1b would
  REGRESS a currently-correct grouping** — the opposite of the "inert until
  wired" assumption the risk framing carried.
- **"Match your siblings" would INHERIT A LIVE BUG here.** `dot-lparen` is
  ABSENT from surface-rewrite entirely (0 grep hits), and that absence is a
  latent defect: `(a .( b ) c)` mis-groups at the tree layer with `c`
  EXPELLED. The ACTION (add the arm) is right; the precedent's FACT (no arm)
  must not be copied. P1a's lesson, inverted.
- **`hash-lbrace` is the complete-coverage precedent** (6/6 sites) — see Q_M5.
- **The `.` duty count is SIX, not four**: `.k` · `.N` (P2) · `.*` (retired,
  token still lexes) · `.{` · `.(` · `...` **plus** (5) the single-char
  FALLBACK — which is what `.{`, `.N` and a standalone `.` all hit today —
  and (6) the DECIMAL POINT inside number tokens (`3.14` → one token; the
  `v.0` vs `3.14` boundary is exactly what P2's `.N` must respect). Also
  `.-1` LEXES CLEANLY as dot-access with field `-1` (`ident-start?` includes
  `-`), so the carried "`.-1` = classifier rejection" ruling is about an
  existing well-formed token, not a shatter.
- **Priority numbers are DECORATIVE where they tie**: dot-lparen and
  broadcast-access both sit at 87; nil-dot-key and nil-dot-access both at 92.
  The registry is a plain mutable hash sorted by descending priority — ties
  break by UNSPECIFIED hash order. **Prefix-disjointness, not priority, is
  the safety property**; Q8 owes this as a standing invariant line, and a new
  `dot-lbrace` must take a unique priority without relying on one.
- **The registry has ONE hard-coded site, not two**: macros.rkt:2434/:2438
  (coordinates were stale by +3 after P1a). driver.rkt:3337 is
  `handle-foreign`'s `(foreign racket "module" …)` IMPORT DECLARATION — a
  different form with no brace. Q8 must decide explicitly whether the registry
  unifies block-head languages with import-declaration languages.
- **A zero-dependency LEAF MODULE is the only registry option with in-tree
  precedent**: there is NO cross-module registration idiom into parse-reader
  (its token-pattern registry is module-private, zero external callers), while
  four leaf-module precedents exist (`tropical-fuel-primitives.rkt`,
  `definition-entry.rkt`, `derivation-chain-types.rkt`, `source-location.rkt`)
  — one naming cycle-safety as its own rationale. The parameter option is
  additionally disqualified by the collection-path trap.
- **`(pair? result)` protects MORE than recorded**: 13 opener-adjacent lines
  in `.prologos` (9 of them ACCEPTANCE-gated) **plus 16 more in suite-gated
  test files**.
- **The sexp `.{` fan-out is ~2× the recorded size**: 27 test-cases / 50
  occurrences in `test-selection-paths.rkt` + 4/4 in `test-path-expressions`.
  Q_L2's isolation claim CONFIRMED (both route through
  `prologos-sexp-read-syntax`, never the WS reader).
- **A THIRD already-silently-broken-in-WS surface** in this neighbourhood: the
  WS side of the `selection` form (WS yields `:address` + loose `|.|` +
  `$brace-params`, never the trailing-dot string the validator splits) —
  alongside the narrow-var one and the `<` swallow. Recorded, not scoped in.
- **Bucket 4 (closing-delimiter-adjacent: `f[x]{a}`, `(g y){a}`, `{:a 1}{b}`)
  has ZERO live sites** — a free decision, but `(pair? result)` is TRUE for
  all three, so a naive `is-postfix?` generalization classifies them as select
  blocks by accident. P1b-iii must DECIDE, not discover.
- **Q8 owes a binder-adjacency THREE-WAY split**: `[fn [x :Int] x]` and
  `defn s [x :Int]` ACCEPT the spaced form (adjacency-blind); `parse-rel-params`
  (defr) EXPLICITLY ERRORS on it; expression position is where adjacency
  decides. Three positions, three rules.
- **Two additional opener enumerations, both currently inert** and excluded
  from "the six" with reason: parse-reader.rkt:1585-1586 (the disambiguator's
  negative-prefix list, a no-op arm today) and tools/golden-capture.rkt:89
  (dev tooling).
- **A SEVENTH site is conditional on a decision P1b-ii must make**: whether
  `dot-lbrace` mints a NEW GROUP TAG. surface-rewrite.rkt:519 derives the tag
  from the token type; a new tag needs a tree-parser dispatch arm or it hits
  the "Unhandled form" fallthrough. Reusing `'brace-group` avoids that but
  ERASES the `.{` distinction from the tree spine, which P3 will need.

<a id="p1b-i"></a>

### §5.P1b-i — Repairs, probes, and the Q8 draft  ✅ `fc65ca54`

**Intent**: land the repairs and settle the probe-decided items, so Q8 is
WRITTEN FROM measured facts rather than leans. No new surface syntax.

1. **THE Q_M1 POSITION PROBE — FIRST, and gating.** Hunt expression-position
   `:0`/`:1`/`:w`/`:m` in both modes and across the corpus at HEAD. If ANY
   exists, ruling Q_M1(b) re-opens BEFORE anything is built on it. (The seam
   has refuted position-disjointness once already.)
2. **The WS narrow-var repair** — a **MISSING JOINER, not a missing
   splitter**, so the standing no-second-splitter rule is satisfied. WS
   already delivers `?x` and `:Nat` as separate adjacent datums (probe:
   `[add ?x:Nat ?y:Nat] = 5N` → `((= (add ?x :Nat ?y :Nat) …))`); fusing them
   at the `=`/`#=` arms leaves `collect-narrow-vars+constraints`,
   `rewrite-constrained-vars`, `narrow-var-base-name` and
   `narrow-var-constraints` ALL untouched, and is a provable no-op in sexp
   mode — the two modes CONVERGE. Reuse `fused-type-annot?` (parser.rkt:5420)
   as the recognizer; do NOT reuse `split-fused-symbol` (it rejects chains,
   which the narrowing surface pins as supported). ⚠ Coordinates were STALE
   by 44 lines: `narrow-var-constraints` is at **:6915**, call sites
   **:3057/:3063/:3082**. Replace the VACUOUS pin
   (test-constraint-chain-01.rkt:186-193 — passes on substring `"x"`).
3. **The top-level `<` swallow fix (Q_M4)** — bound `langle-matched?`'s scan
   at the next top-level form start; plumb `content-line-indices` (already
   computed at Domain 2) into `make-bracket-depth-rrb` (Domain 4). Must admit
   CONTINUATION lines, reject NEW-FORM lines. The `31d27c83` pins
   (test-parse-reader.rkt:499-547 ×8 + test-mixfix-02.rkt:359-416 ×7) are the
   gate. **Failing-test-first on the `def p := 1 < 2` / `def q := 3 > 4`
   repro.** If messier than plumbing suggests: STOP and re-checkpoint.
4. **`def ?x` → guided error (Q_M3)**, riding the P1a marker seat.
5. **The remaining probes**: keyword-trailing `*` (confirm `recognize-keyword`
   delegates to `ident-continue?` — that delegation IS the F1b.7g anti-drift
   fix, so the split must happen at a CONSUMER; prior art:
   `validate-selection-paths` already splits `^` string-wise off a keyword
   lexeme and handles a whole-segment `"*"`); `:<` in BOTH shapes (should be
   SAFE once item 3 lands — re-probe to confirm rather than assume).
6. **Q8 DRAFT** from the results — owner-reviewed before P1b-ii/iii land.

**Test delta**: narrow-var real pins (replacing the vacuous one); `<`-swallow
pins both directions (swallow gone / multi-line angle still works); `def ?x`
guided-error pin; probe results recorded in this section. Status: ✅ `fc65ca54`.

---

<a id="q8"></a>

## §Q8 — THE LEXICAL GRAMMAR  ✅ *owner-reviewed 2026-07-28; NORMATIVE*

> **Review outcome**: adopted as written, with **one amendment — Q_M8**
> (ordinals are multi-digit in both bands; the draft's `:N` recommendation was
> withdrawn as wrongly-premised). Q8 now governs P1b-ii, P1b-iii and P2.

Written FROM the P1b-i probe results, not from leans. Every row is
probe-verified at `fc65ca54` unless marked `[P1b-ii]` / `[P1b-iii]` (the rows
those slices will add). Priorities are quoted from the registrations; **see
the invariant note at the end — priority is NOT the safety property.**

<a id="q8-1"></a>

### Q8.1 — The `.` band: SIX duties, in matching order

`.` is on six duties, not the four §8 R3 records. Two were unlisted: the
single-char FALLBACK (what `.{`, `.N` and a bare `.` all hit today) and the
DECIMAL POINT inside a number token.

| # | Form | Token (priority) | Discriminator after `.` | Status |
|---|---|---|---|---|
| 1 | `x...` | `rest-param` (89) | a second `.` | live |
| 2 | `m.:k` | `dot-key` (88) | `:` | **RETIRED** at P1a — token still lexes, marker seat converts |
| 3 | `.( … )` | `dot-lparen` (87) | `(` | live (mixfix) |
| 4 | `xs.*f` | `broadcast-access` (87) | `*` | **RETIRED** at P1a — as above |
| 5 | `x.name` | `dot-access` (86) | `ident-start?` AND **not** `:`, `{`, `*`, digit | live |
| 6 | `x.{…}` | `dot-lbrace` (87) | `{` | **live** since P1b-ii `1a1091d4` (registered parse-reader.rkt:1192) |
| — | `3.14` | `decimal-literal` (75) | anchors at a **DIGIT**, never at `.` | live — no overlap with the band |
| — | `x . y` | single-char symbol fallback | — | the catch-all; `.N` also lands here until P2 |

⚠ **CORRECTED 2026-07-29 (P2 audit `wf_22020418-a5f`) — this section
CONTRADICTED ITSELF, in normative text.** The table above has had SIX rows
since P1b-ii, but the Totality prose below said "five" and the row-6 Token
column still described the PRE-P1b-ii state (`*(fallback)* → dot-lbrace …
today falls to the single-char .`). §5.P2 inherited the five. **This is the
THIRD consecutive under-count of this one enumeration** (four → five → six),
and it matters beyond tidiness: §Q8.5 invariant 1's safety argument is
literally "prefix-disjoint from *all band members*", which is sound only if
the enumeration is complete.

**Totality**: the **six** band members test *different* second characters
(`.` / `:` / `(` / `*` / `{` / ident-start), and `recognize-dot-access`
excludes `:`, `{`, `*` and digits **explicitly** (parse-reader.rkt:734-739 —
the digit exclusion is real but REDUNDANT under `ident-start?`, which admits
no digits, so "double-guarded" is accurate and one guard is decorative). A
`dot-lbrace` insertion was therefore disjoint from all five that preceded it,
and a `.N` insertion is disjoint from all six. `.-1` LEXES CLEANLY as
dot-access with field `-1` (`ident-start?` admits `-` — **and `+`, so the
class is SIGNED, not negative: `x.+1` lexes identically**), so the carried
"`.-1` = classifier rejection" ruling is about a **well-formed token**, not a
shatter — P2 owns it when `.N` arrives, as a CONSUMER decision.

**The OPPOSING family was also under-counted, by 5×.** This section named only
`decimal-literal` as the digit-anchored competitor. **SIX** digit-anchored
recognizers currently claim the digit run after a dot — `decimal-literal`
(:286), `number` (:268), `exp-literal` (:309), `float-literal` (:352),
`posit-literal` (:409), `rat-literal` — and all six lose that claim to a
dot-anchored recognizer. That is why the **trailing-guard** question (Q_R2) is
not cosmetic: it decides five shapes that each lex as ONE numeric token today
(`x.0N` `x.1e3` `x.1/2` `x.1f` `x.1p8`). Two further unruled items in BOTH
bands: **leading zeros** (`x.007` → 7 today via `string->number` on `#e007`;
`:007` is one token since P1b-iii) and the **Unicode-digit crash**
(`char-numeric?` is Unicode-wide while `string->number` is not, so `٣` raises a
raw `exact?: contract violation` — `(char<=? #\0 c #\9)` is strictly safer and
is a NARROWING, not a competing definition, so the F1b.7g rule permits it).

**`.N` is MULTI-DIGIT (ruled Q_M8).** P2's `.N` recognizer anchors at the
**dot** and takes `digit+` (not one digit). It is prefix-disjoint from
`decimal-literal` (which anchors at a **digit**, never at a dot) and from all
six band members.

⚠ **CORRECTED 2026-07-29 — "it fixes a SILENT WRONG ANSWER … both at 0 errors"
was a LAYER ERROR.** The readings below are real but **reader-layer only**. END
TO END every rational-class form is **LOUD**, because the stranded bare `|.|`
symbol is unbound. Re-probed at `c5153685` via `tools/run-file.rkt`:
`m.0` / `m.1.2` / `m.10.20` → `ERROR: Unbound variable`; `m.-1` → `ERROR: Could
not infer type`; **4 errors**, not 0. The defect is a live MIS-LEXING that
produces a MISLEADING error — not a silent wrong value.

**Consequence for the failing-test-first obligation** (this is why the
correction matters rather than being pedantry): the honest pin is **TWO-LAYER** —
(a) a reader/datum pin (`($decimal-literal 6/5)` today → `(get (get x 1) 2)`
after), and (b) an end-to-end pin framed *"was a misleading error, now computes
the right value"*. A pin written as *"was silently 6/5 at 0 errors"* **cannot
fail for the reason it claims**, which is this arc's hazard 4 (already the
source of one vacuous pin and two mis-premised fixtures). Four of the P2
audit's six facets caught this independently.

Probe-measured at `b389479b`, re-confirmed at `c5153685`, today:

| Source | Today | Why |
|---|---|---|
| `x.10` | `(x \|.\| 10)` | falls to the single-char `.` fallback |
| `x.1.2` | `(x \|.\| ($decimal-literal 6/5))` | **the RATIONAL bug** — `decimal-literal` anchors at the `1` |
| `x.10.20` | `(x \|.\| ($decimal-literal 51/5))` | same class, multi-digit |

A dot-anchored `digit+` recognizer kills the rational **structurally**: the
tokenizer consumes `.1` at the dot, then `.2`, so `decimal-literal` never gets to
anchor. Multi-digit is therefore not an extra — it is the same one-line `digit+`
that fixes `x.1.2`.

<a id="q8-2"></a>

### Q8.2 — The `{` band: TWO lexical rows, and a separate GROUPING table

⚠ **The `{` order is not a lexical order at all**, and Q8 must say so. Only
two `{` recognizers exist; every other bucket is a GROUPING decision made
from token POSITIONS.

| Lexical | Token (priority) |
|---|---|
| `#{…}` set | `hash-lbrace` (91) |
| `{…}` | `lbrace` (30) |

| Grouping (WS ONLY) | Rule | Status |
|---|---|---|
| spaced `f {…}` | never a select block | must not change (largest population is BINDERS) |
| adjacent reader-form head `racket{…}` | head-symbol precedence — checked FIRST | `[P1b-iii]`; keeps `$brace-params` (spaced form is back-compat-pinned) |
| adjacent `x{…}` | select block | `[P1b-iii]` — **forced NEW sentinel** (Q_M6) |
| `.{…}` | descend-then-select | `[P1b-ii]`, plain `'rbrace` closer (Q_M5) |
| closing-delimiter-adjacent `f[x]{a}` | **undecided** — zero live sites | `[P1b-iii]` must RULE, not discover |

The sexp readtable binds `{` as a terminating macro with no positional
context, so this table is **structurally WS-only** — the Q_L2 divergence,
stated rather than discovered.

<a id="q8-3"></a>

### Q8.3 — The `:` seam: position AND adjacency

`:0`/`:1`/`:w`/`:m` are **not spare glyphs** — they are the QTT multiplicity
vocabulary (`colon-annotation`, priority 97), consumed at 18 sites. `users:0`
and `[fn [x :0 Int] x]` are **the same lexeme**.

| Form | Reading | Rule |
|---|---|---|
| `?x:Nat` (contiguous) | narrowing typed logic var | `narrow-var-annot` (96) — ONE token; **chains** `?x:A:B` included |
| `?m :name` (spaced) | logic var + keyword ARGUMENT | untouched — contiguity is the discriminator |
| `x:Int` | type annotation | binder/head position (POL.6) |
| `x :0 Int` | QTT multiplicity | binder position, **spaced** |
| `users:name` / `users:0` | broadcast `[P1b-iii]` | expression position **AND adjacent to a FOCUS-BEARING token** |
| `{:0 …}` | map key / multiplicity | preceded by an OPENER, not a focus — never broadcast |

**Q_M1's discriminator, as measured** (re-verified at `b389479b`): of **289**
live multiplicity tokens, **287 are spaced** and the other **2 are preceded by
`{`**; **zero are adjacent to a focus-bearing token**. So the rule is adjacency
to a *focus-bearing* token — position alone is insufficient, and this is the
same shape as `is-postfix?`'s `(pair? result)` conjunct. *(An earlier draft said
291/289/2 — a regex-boundary artifact; the shape and conclusion are unchanged.)*

**Multi-digit `:N` — RULED Q_M8: the digit run WIDENS to N.** See §3 Q_M8. The
draft recommendation here ("do not add a digits-only recognizer") was **withdrawn
as wrongly-premised** — it treated `:`+digit as QTT-owned space. It is not:
`recognize-colon-annotation` accepts **12** lexemes (`:0`–`:9`, `:w`, `:m`) while
`mult-annot?` (parser.rkt:3904) accepts **3** (`:0 :1 :w`). Nine of the twelve
ALREADY lex as one token and are ALREADY not multiplicities.

<a id="q8-4"></a>

### Q8.4 — `*` and `<`

| Form | Finding |
|---|---|
| `:diags*` | `*` GLUES (`recognize-keyword` delegates to `ident-continue?`, and that delegation **is** the F1b.7g anti-drift fix). `int*`/`trait*` are live identifiers, so a charset change is forbidden — the split must happen at a **CONSUMER**. Prior art: `validate-selection-paths` already splits `^` off a keyword lexeme and handles a whole-segment `"*"`. |
| `:<` disclose | **SAFE as of `fc65ca54`.** The hazard was never `:<` — a bare depth-0 `<` swallowed identically, and so did `def p := 1 < 2` / `def q := 3 > 4` with no colon and no brace. Fixed by the Q_M4 bound; `users:<{a}` + a later `>` now reads as three forms. |

<a id="q8-5"></a>

### Q8.5 — Standing invariants

1. **Prefix-disjointness, NOT priority, is the safety property.** Priorities
   TIE in two places — the **87 group is THREE-WAY** since P1b-ii
   (`dot-lparen` / `broadcast-access` / `dot-lbrace`; *corrected 2026-07-29 —
   this said "two places … both 87", stale in arity*), and
   `nil-dot-key`/`nil-dot-access` are both 92 — and the registry is a plain
   `(make-hash)` sorted descending with a `for/or` FIRST-match — **ties break
   by unspecified hash order**. A new recognizer must be prefix-disjoint and
   must not rely on its number. *The code already says this better than the
   doc did: parse-reader.rkt:1188-1191 — "safe because the three are
   PREFIX-DISJOINT (`(` / `*` / `{`), not because of the number".*
   Corollary verified at P2: the scan advances by the matched length, so an
   INTERIOR dot is structurally unreachable as an anchor — `3.14` is consumed
   whole at the `3`, which is a stronger argument than "no overlap".
2. **Adjacency lives in TOKEN POSITIONS. Any rule keyed on it must be decided
   at or before GROUPING** — because the *consumers* downstream of grouping
   cannot recover it. *(P1b-i learned this the hard way: a datum-layer fusion
   of `?x` + `:Nat` absorbed unrelated keywords.)*
   ⚠ **CORRECTED 2026-07-29 — the old illustration was FALSE at HEAD and
   misleading in a dangerous direction.** It read: "`x{a b}` ≡ `x {a b}`
   byte-identical as datums." Probed at `c5153685`: `x{a}` → `((x
   ($select-brace a)))` vs `x {a}` → `((x ($brace-params a)))`, and `x[0]` →
   `((x ($postfix-index 0)))` vs `x [0]` → `((x (0)))`. They are **distinct**
   — because P1a/P1b-iii took this very lesson and moved the decision to
   grouping via `adjacent-to-base?` (parse-reader.rkt:2632). The old text
   described the PRE-FIX state and implied "the datum layer can't tell, so
   don't bother checking." **No facet caught this; the completeness critic
   did.**
   Scope note for P2: the **dot band has NO adjacency gate at all** —
   `adjacent-to-base?` is called only from the bracket arm (:2692-2694) and
   the brace arm (:2750). `x .0` and `x. 0` both read `((x |.| 0))`, so a
   dot-anchored recognizer fires regardless of the preceding space. Ruled
   Q_R3: the dot band stays adjacency-free (`.k` never enforced it either;
   retrofitting the whole band is out of P2's scope, and the blast radius is
   nil by census).
3. **New sentinels owe NINE registrations — this invariant used to say TWO, and
   ONE OF THOSE TWO WAS A NO-OP.** ⚠ Corrected at P1b-iii after the P1b-ii
   regression. The old text ("`pattern-var?` and tree-parser's inline
   skip-list") was written ONE COMMIT BEFORE the regression it was meant to
   prevent, and **under-specified by exactly the amount that let it through**:
   tree-parser.rkt:662's memq is **DEAD CODE** (both cond arms terminate in a
   `(char=? (string-ref s 0) #\:)` test, so a `$`-headed item fails the arm
   regardless, and every member of the list starts with `$` or is `quote`).
   The real surface, verified at `88b3019a`:

   ⚠ **CORRECTED AGAIN 2026-07-29 (P2 audit).** The token layer below was
   written from an OPENER's shape and under-specifies for a SELF-CONTAINED
   token by exactly the amount that would let one through — *the identical
   failure mode this invariant was corrected for at P1b-iii.* Twice now, an
   enumeration written from one member's shape has missed the next
   differently-shaped member. **Read the applicability column, not just the
   list.** Four coordinates were also stale (audited at `88b3019a`; `a6af2761`
   moved them) — including the fusion gate this invariant exists to name.

   **Token layer** — applicability depends on the token's SHAPE:

   | | Site | OPENER (e.g. `dot-lbrace`) | SELF-CONTAINED (e.g. `.N`, `dot-access`) |
   |---|---|---|---|
   | a | the recognizer | required | required |
   | b | `register-token-pattern!` | required | required |
   | **f** | **`token-entry->stx`'s `case type`** (parse-reader.rkt:2264; copy the `dot-access` template at :2265-2270) | required | **REQUIRED — and a miss is SILENT** |
   | c | `langle-matched?` opener set (:1486) | required | **N/A** — no closer |
   | d | its `has-matching-rangle?` TWIN (:2570, keep IDENTICAL) | required | **N/A** |
   | e | the extent frame dispatch (:1503-1539) | required | **N/A** |
   | — | the test oracle's THIRD copy of the opener list (tests/test-parse-reader.rkt:1174) | required | **N/A** |

   **Site f is the one no enumeration had ever named, and it fails SILENTLY**:
   a new token type with no `case type` arm falls through BOTH `[else]`s —
   :2262 `[else (string->symbol lexeme)]` and :2342 `[else (make-stx value …)]`
   — yielding the bare symbol `|.1|`. No raise, no diagnostic, wrong datum.
   Note also that site 1 below ("`group-items` arm") names the CALLER (:2648 →
   :2734/:2828/…), not the minting function; `token-entry->compat`'s value
   `[else]` (:2092) is a test-only twin.

   **Sentinel/tag layer** (EVERY new sentinel):
   1. `group-items` arm (parse-reader.rkt) — mints the datum sentinel
   2. `group-items-to-tree` (surface-rewrite.rkt) — **SILENT if missed, and
      load-bearing**: a non-error tree surf can REPLACE preparse's error surf
   3. tree-parser dispatch arm — its `else` **silently** calls `parse-expr-tree`
      for any node with children; "Unhandled form" is UNREACHABLE from a group tag
   4. **`pattern-var?` (macros.rkt)** — **LOUD whole-file abort if missed.**
      This is the P1b-ii regression
   5. preparse opacity (macros.rkt:**1999** — *was cited :1988*)
   6. sub-form recursion skip (macros.rkt:**2560** — *was cited :2536*)
   7. `combine-foreign-blocks` head test (macros.rkt:**2445** — *was :2444*) — if head-relevant
   8. **`access-sentinel?` (macros.rkt:**5493** — ⚠ *was cited :5446, a 47-line
      drift in the very site this invariant was corrected to NAME; :5446 is the
      `dot-access?` comment*) + the `rewrite-dot-access` fold
      arm** — ⚠ **named by NO enumeration before P1b-iii, and the site that
      produced P1b-ii's carried residual.** Without it the sentinel never fuses
      onto its base, stays a separate sibling, and every guided error it owns
      becomes unreachable in arity-checking contexts
   9. the parser head-dispatch arm (parser.rkt, modelled on :829)

   **Silent-degradation tier** — pre-existing and family-wide, NOT chargeable to
   a new sentinel: `pp-datum` (pretty-print.rkt, handles 11 heads and **no
   access sentinels at all**) and `tools/form-deps.rkt:42`.

   **The structural reading**: nine hand-maintained enumerations is the disease,
   not the checklist's length. `pattern-var?` in particular is a NEGATIVE list
   defaulting to "this IS a pattern variable" — the same inverted polarity
   `definitely-not-map?` had before P2.b slice 1 inverted it. See DEFERRED
   § "CIU T6 D4.P1b-ii spin-offs" item 3.
4. **Both reader modes, always.** WS and sexp diverge by construction here
   (adjacency, `.{`), so a census in one mode proves nothing about the other.

<a id="p1b-ii"></a>

### §5.P1b-ii — The `.{` opener  ✅ `1a1091d4`

**Mini-audit**: `wf_f91e5aac-df2` (5 facets + completeness critic, HEAD-pinned
`09a1f0d7`; a first run `wf_e34bc9f3-6a8` died on an auth expiry with zero
results). Every load-bearing finding below was **main-session R-lens-verified**.
It refuted the design on three points and **inverted the phase's hazard model**.

#### What the audit changed

1. **⚠ COORDINATES DRIFTED +136 to +148** on all five parse-reader cites (P1a +
   P1b-i both inserted). Only `surface-rewrite.rkt:516` was exact. HEAD truth is
   the table below. *Ninth consecutive phase with drifted coordinates.*
2. **⚠ THE HAZARD MODEL WAS INVERTED.** The design said a missing tree-parser
   arm "hits the *Unhandled form* fallthrough" — i.e. LOUD. **False.**
   `"Unhandled form"` (tree-parser.rkt:119) lives inside the nested `case` of the
   **top-level-form** arm; a GROUP tag can never reach it. The reachable arm is
   **tree-parser.rkt:189-193**, which calls `parse-expr-tree` **SILENTLY**
   whenever the node has children — always true for a brace group. Worse,
   `driver.rkt:2457-2459` admits tree output when *non-error ∧ same-form-type ∧
   same-line*, so **a silent garbage surf can BEAT preparse's correct one**. A
   missing arm is a silent-wrong-answer, not an error.
3. **⚠ THE "NEW TAG NEEDS AN ARM" OBLIGATION HAS THREE LIVE COUNTEREXAMPLES**:
   `set-group`, `at-group`, `tilde-group` are minted at surface-rewrite.rkt
   :519/:527/:528 with **zero** tree-parser arms and zero non-test consumers —
   they already ride the silent :189-193 path. Verified. Whether that is benign
   for them is **UNVERIFIED → filed** (DEFERRED), not assumed.
4. **MY OWN QUESTION'S PREMISE WAS WRONG.** I asked whether `dot-lbrace` belongs
   in the "langle skip-set" at all, reasoning a select block is not mixfix. The
   lists at :1427-1428 / :2504-2506 are **OPENER DEPTH-BALANCING** sets (paired
   increment/decrement inside the langle lookahead), **not** suppression sets.
   Adding `dot-lbrace` is **REQUIRED**; omitting it causes TWO failures — a
   spurious no-rangle-match, and a **WRONG-FRAME POP** in the frame dispatch
   (the `31d27c83` class). Angle suppression is separately keyed on frame kind
   `'mixfix` (:1442/:1458/:1465), which a `'brace`/`'rbrace` frame never sets —
   so **type-level angle groups keep working inside a select block**, which is
   the behaviour we want, and it falls out of Q_M5 rather than needing a rule.
5. **Q_M5 VALIDATED HARDER THAN ARGUED**: because the closer is plain `'rbrace`,
   **ZERO closer-side edits are needed** — every closer enumeration already
   lists `rbrace` (parse-reader.rkt :1430/:1470/:2507/:2734; surface-rewrite.rkt
   :504/:533). A sentinel closer would have added six sites **and** needed 4+
   translation arms (`langle-matched?` :1433 has NO translation; its twin
   :2510-2513 DOES — the asymmetry is itself the hazard).
6. **THE INVERTED HAZARD IS CONFIRMED AND SILENT.** Probed: the flagship groups
   correctly today (`(root (line app-config (brace-group server^ |.| (brace-group
   ssl port) version)))` — the surviving `|.|` is the direct evidence that `.{`
   lexes as two tokens). Without the :516 addition an unarm'd opener falls to
   surface-rewrite.rkt:539-540 `[else …]`, the inner `}` closes the OUTER group
   at :504-506, and the real outer `}` is discarded by the stray-closer arm
   :532-534 — **a silently wrong tree, no raise**.
7. **IT IS ≥8 EDIT REGIONS, NOT 6**: the recognizer is a separate edit from the
   registration, and surface-rewrite.rkt needs **:516 AND :519** unconditionally
   (the two-way `if` has no arm for a third token type — so :519 is not the
   "conditional seventh site" the design priced, it is mandatory either way).

#### The rulings [owner, 2026-07-28]

- **Q_N1 — TWO decisions, one layer apart; BOTH mint new.** The design named only
  the tree tag. There is a parallel **datum-layer** decision: which SENTINEL HEAD
  the new `group-items` arm emits (siblings mint distinct ones — `lbrace`→
  `$brace-params`, `dot-lparen`→`$mixfix`, `hash-lbrace`→`$set-literal`).
  **Ruled: new sentinel `$dot-brace` + new tree tag `'dot-brace-group` + write
  the tree-parser arm.** Rationale: (a) reusing `$brace-params` would give `.{`
  the **implicit-type-binder** meaning and a large consumer surface (driver
  capability extraction, form-cells, ~30 library sites) — the genuinely dangerous
  reuse, worse than the tree tag; (b) reuse is lossless *today* only because the
  loose `|.|` token survives grouping, and **P1b-ii's own mint destroys that
  signal** — a one-way loss, not a neutral choice; (c) **srcloc cannot recover
  it** — verified: `group-items-to-tree` is entered with the enclosing node's
  srcloc and all four mint sites (:501/:513/:520/:530) reuse the same binding, so
  every group in a form shares one srcloc, and the opener token is consumed.
- **Q_N2 — the `.( )` sibling bug is FILED, not fixed here.** It is real and
  worse than recorded: a **LAYER DIVERGENCE**, not a mis-group — probed,
  `(a .( b ) c)` keeps `c` at the datum layer (`((a ($mixfix b) c))`) and
  **EXPELS** it at the tree layer (`(root (line (paren-group a |.(| b) c))`), at
  zero errors. Not fixable by an arm: the `'mixfix-group` tag and its ~445-line
  consumer were DELETED at P1a, so a new arm has no tag to emit but
  `'paren-group` (erasing the distinction), and the angle half needs a `'mixfix`
  frame concept `group-items-to-tree` does not have. No test pins `.( )` at the
  tree layer either. → DEFERRED.
- **Q_N3 — ADD THE STRUCTURAL GUARD.** Nothing pins *"every registered opener
  token type has an arm in BOTH groupers."* surface-rewrite.rkt:539 is a bare
  `[else]` catch-all in a transforming walker — the exact red flag
  `pipeline.md` § Exhaustive Walkers names, and precisely the class that produced
  the `dot-lparen` bug. A contract test censusing the token-pattern registry's
  opener names against both arm lists makes the class impossible **by
  construction** rather than by checklist.

#### The edit regions (HEAD `09a1f0d7`, all re-verified)

| # | Site | HEAD coord | Edit |
|---|---|---|---|
| 1 | `recognize-dot-lbrace` | new, beside `recognize-dot-lparen` :756 | `.`+`{` → 2 |
| 2 | registration | :1136-area (dot band) | priority **87** (sibling of `dot-lparen`; safe by DISJOINTNESS, not number — Q8.5 inv. 1) |
| 3 | `langle-matched?` opener set | :1427-1428 | append `dot-lbrace` |
| 4 | frame dispatch | :1453-1454 | append to `'(lbrace hash-lbrace)` → `(cons 'brace 'rbrace)` |
| 5 | `has-matching-rangle?` opener set | :2504-2506 | append `dot-lbrace` — **identical to #3, the twin** |
| 6 | `group-items` arm | after the `lbrace` arm :2639-2645 | new arm → `$dot-brace`, closer `'rbrace`, srcloc span **2** |
| 7 | surface-rewrite.rkt | :516 **and** :519 | memq gains `dot-lbrace`; the tag `if` becomes a `cond` |
| 8 | tree-parser arm | :128-135 arm set | `[(dot-brace-group) …]` |

⚠ **Priority 90 is NOT free** — it is `char-lit` (:1182). Only 81, 82, 94 are
unused in 80-99. (We use 87 regardless; recorded so the next reader does not
interpolate.)

#### Test delta

- **Three flips**, not two: test-parse-reader.rkt:401-406 (`check-false (assq
  'dot-lbrace …)` — INVERTS) · test-mixfix-01.rkt:54-58 (compat-path
  `check-exn` — flips because the standalone-`.` rejection is **token-type**
  keyed, so folding both chars into one non-symbol token makes it unreachable) ·
  **test-mixfix-01.rkt:332-342** (a Level-3 WS pin the design never named).
- **The flagship needs an EXPLICIT NEW PIN — the corpus A/B cannot see it.**
  Verified: exactly **ONE** live non-comment `.{` exists in all 160 corpus files
  (`examples/2026-03-20-first-class-paths.prologos:331`); every
  `app-config{server^.{…}}` line in our own acceptance file is `;;`-commented.
- **The A/B must compare succeeded/failed TALLIES, not only `.golden` contents**:
  `tools/golden-capture.rkt:83` calls `tokenize-string`, whose standalone-`.`
  rejection is exactly what flip 2 disables, and it swallows per-file exceptions
  into a FAIL counter — so a file may move FAIL→SUCCESS, a diff of a different
  shape.
- **The Q_N3 guard** as a contract test.
- A **third opener enumeration** exists in the test oracle
  (tests/test-parse-reader.rkt:1015-1019, a verbatim copy of the production
  8-member list) — the guard should cover it or it drifts.

**Acceptance delta: ZERO markers uncommented** (P1b makes forms LEXABLE; the
semantics are P3's, and the file ties uncommenting to a verified result).

#### CLOSE NOTES ✅

**Gates**: suite **9279 / 474 / 0** · acceptance **28/28 + 89/89** · neighbourhood
battery 443/443 (incl. both sexp `.{` files and all three defmacro files) ·
**corpus A/B: 158 files, ONE diff, intended** — `first-class-paths.prologos:331`,
form count unchanged 52→52, `app-config |.| ($brace-params …)` →
`app-config ($dot-brace …)`.

**⚠ THE A/B WAS WRONG THE FIRST TIME, AND THE FAILURE IS INSTRUCTIVE.** Run 1
reported **5 diffs** — which were *exactly* the 5 owner-modified `.prologos`
files. Both legs read from different trees, so it compared *content*, not
readers. Re-run with both legs reading identical HEAD content and only the
reader differing → 1 diff. **This is the same dirty-tree trap that made two
facets of the P1 audit "refute" a correct design count.** An A/B over a dirty
tree measures the tree, not the change: pin BOTH legs' inputs, not just the code.

**⚠ ADVERSARIAL VERIFY CAUGHT A BLOCKING REGRESSION — MINE — AND THE SUITE WAS
GREEN.** `$dot-brace` was missing from `pattern-var?` (macros.rkt), so the new
sentinel read as a macro PATTERN VARIABLE: `.{ }` inside a defmacro **template**
made `datum-subst` raise, i.e. a **whole-file abort with zero results**, where
the same source gave a per-command error before the token existed. It is the
exact P1a headline defect class, at the exact site P1a fixed for
`$dot-key`/`$nil-dot-key` — **and Q8.5 invariant 3 names this obligation
explicitly**. I wrote that invariant and then did not follow it. Fixed +
pinned; the pin exercises macro **USE**, because P1a's sibling pin only
registers a macro and registration is harmless — a registration-shaped pin stays
green through the whole defect.

**The guided error was also wrong at first**: `.{ }` reported *"Unbound
variable"* until it was routed through P1a's marker seat — telling a user their
valid new syntax had a missing variable. Now: `` `.{ }` select blocks are not
supported yet — path selection lands them in CIU Track 6 P3. Field access works
today: `x.name` ``, per-command, file continues.

**Three SIGNIFICANT findings, all verified NOT regressions → DEFERRED items 3+4**:
the guided error is unreachable in arity-checking contexts (map literal, `fn`
params, `validate`) because `$dot-brace` stays a *sibling* item until P1b-iii
fuses it — ordering-dependent, named not fixed; `.{ }` inside `.( )` aborts; and
inside a parenless `defr` goal it is silent. The `.( )` one shares a root with a
pre-existing family: **`$set-literal` and `$mixfix` are ALSO still pattern-vars**
and abort identically in a macro template. DEFERRED item 3 records the
structural reading — `pattern-var?` is a hand-maintained NEGATIVE list whose
default is "pattern variable", the same inverted polarity `definitely-not-map?`
had before P2.b slice 1 inverted it. More exclusions is not the fix.

**What the Q_N3 guard bought**: it caught the third opener enumeration
immediately — the test oracle's verbatim copy of the production list
(test-parse-reader.rkt:1015) reported a real example file as unbalanced until
`dot-lbrace` was added there too.

Status: ✅ `1a1091d4`.

<a id="p1b-iii"></a>

### §5.P1b-iii — Brace adjacency + the head registry  ✅ `a6af2761`

**Mini-audit**: `wf_18992d66-b81` (6 facets + completeness critic, HEAD-pinned
`88b3019a`). Main-session R-lens-verified. It found a **BLOCKING problem with
Q_M8** and **located the root cause of P1b-ii's carried residual**.

#### ⚠ BLOCKING — Q_M8 as ruled would ship a SILENT WRONG ANSWER

The ruling's safety premise ("`:10` is rejected by the SAME `memq` arm that
already rejects `:7` — no new failure mode") is **FALSE for the 2-element `defn`
bare-param shape**. Probe-verified at `88b3019a`:

| Source | Result today |
|---|---|
| `defn g [x :7] x` | **SILENTLY ACCEPTED** → `g : [Pi [x :0 <[Type 0]>] x -> x]` — `:7` consumed as a **TYPE NAME**, a different function, 0 errors |
| `defn g [x :10] x` | LOUD parse-error |
| `defn g [x :0] x` | LOUD parse-error |
| `defn g [x :1] x` | LOUD parse-error |

So the *valid* multiplicities are loud here and **`:7` is the anomaly**.
Widening makes `:10` lex like `:7` — moving it **LOUD → SILENT WRONG**.

**Root cause — a site NO enumeration names**: `fused-type-annot?`
(parser.rkt:5459-5460) is a **SECOND hard-coded colon enumeration**, excluding
exactly `'(:0 :1 :w :m)` — four lexemes — against a recognizer minting **twelve**.
Everything outside those four falls through and is consumed as a type name. Its
own comment eight lines above warns *"a second copy is how the two paths would
drift"* — while being exactly that.

**Q_N4 [owner]: WIDEN THE SCOPE.** Fix `fused-type-annot?` **structurally**, not
by extending the list: **no type name starts with a digit**, so a digit-headed
colon symbol is never a type annotation. This co-migrates with the recognizer
widening AND **repairs the pre-existing `:7` silent-wrong-answer**. Q_M8 done
correctly makes the language *more* sound, not less.

#### The carried residual has a LOCATED cause

**`access-sentinel?` (macros.rkt:5446-5450)** gates the left-fold that fuses a
sentinel onto its base. It lists six predicates; `$dot-brace` is not among them —
verified, macros.rkt has exactly two `dot-brace` mentions, both the P1b-ii
`pattern-var?` fix. **That single omission IS the unreachable-guided-error gap.**

And **adjacency does NOT fuse** (Q4 answered: NO). `is-postfix?` only MARKS —
`xs[0]` yields two siblings — and the consuming fold lives one layer down in
`rewrite-dot-access`, gated by `access-sentinel?`. **Corollary the phase
inherits**: the new select sentinel reproduces the identical gap on day one
unless it also gets a predicate + an `access-sentinel?` entry + a fold arm.
Closing P1b-ii's residual and not opening a new one are **the same edit** — in
`macros.rkt`, a file this phase's stated scope ("entirely tokenizer/grouping")
does not name.

#### ⚠ Scope the design MISSED ENTIRELY — and it is worse than P1b-ii's

**§5.P1b-iii never mentions `surface-rewrite.rkt`**, the second grouper, which
has **ZERO adjacency machinery** (grep for `end-pos|start-pos|postfix|adjacen`
→ 0 hits). The two groupers therefore ALREADY diverge in shape on `xs[0]`
(datum `($postfix-index 0)` vs tree plain `bracket-group`).

Why this is worse here: `brace-group` already has a **NON-ERROR** tree handler
returning a map literal, and driver's error-recovery arm (driver.rkt:2557-2560)
lets a non-error tree surf **REPLACE** preparse's error surf. So a
parse-reader-only implementation does not merely lose a diagnostic — **the guided
"not until P3" error is SILENTLY SWALLOWED and the user gets a plausible wrong
map.** → **Q_N7 [owner]: implement adjacency in BOTH groupers.**

#### The rulings [owner, 2026-07-29]

- **Q_N4** — Q_M8 widens in scope: recognizer digit-run `digit+` **plus** the
  structural `fused-type-annot?` fix (see above).
- **Q_N5 — BUCKET 4 IS RULED "SELECT", EXPLICITLY.** ⚠ Inaction is **not** the
  status quo: for `f[x]{a}` **both** `is-postfix?` conjuncts already pass (the
  previous raw-vector item is the `rbracket`, byte-adjacent and
  `token-entry?`-passing; `result` already holds `f` + the postfix group), so a
  naive generalization rules bucket 4 **by accident**. The bracket band already
  answers the analogous question affirmatively (`xs[0][1]` chains through
  `is-postfix?` off an `rbracket`). Ruled to MATCH that precedent — by decision,
  not by default. Zero live sites (census: 160 files, 0 hits).
- **Q_N6 — the binder hazard is ACCEPTED.** `defn f{x} x` is a binder today
  (`($brace-params x)`, byte-identical to the spaced form) and becomes a select
  block after. **Zero live adjacent-brace binder sites**, but the exposure is
  real: **419 of 622 live spaced braces are implicit type binders** (vs 202 map
  literals — a 2.07× margin), and **384 of 622 sit immediately after an
  identifier on the same line**, i.e. one deleted space away. Accepted; **both
  spellings get pins**. No diagnostic attempted — grouping has no position
  concept, so it cannot tell binder position from expression position.
- **Q_N7** — adjacency lands in **both** groupers (above).

#### Q8.5 invariant 3 was UNDER-SPECIFIED — corrected in §Q8

It named two registrations. The audit's answer to Q1 is **NINE real ones**, and
**one of the two it named is a NO-OP**: the tree-parser memq (`:662`) is dead
code — both cond arms terminate in a `(char=? (string-ref s 0) #\:)` test, so a
`$`-headed item fails regardless, and every member of the list starts with `$`
or is `quote`. **The invariant written one commit before P1b-ii's regression, to
prevent exactly it, listed one real item and one no-op — under-specifying by
precisely the amount that let the regression through.** §Q8.5 is corrected.

#### Other audit findings folded

- **Coordinate drift, ELEVENTH consecutive phase**: `recognize-colon-annotation`
  is at :871 (design said :847); `is-postfix?` at :2631 (design ~:2441);
  `combine-foreign-blocks` at :2438 (design ~:2431 — which is `arrow-sym?`).
- **The head "registry" is ONE site, not two.** driver.rkt:3335-3339 is
  `handle-foreign` guarding the `(foreign racket "mod" …)` DECLARATION — head
  symbol `foreign`, `racket` in arg-1, a STRING required next. It never meets a
  brace group. The single grouping-relevant site is macros.rkt:2447. *The "no
  module edge" half stands, and so does the leaf-module conclusion.*
- **Registry home**: `parse-reader.rkt` requires only rrb/propagator/parse-lattice
  and `macros.rkt` does not require it — so a **new leaf module** requiring
  nothing project-local can be required by both with no cycle. `surface-rewrite`
  already requires parse-reader, so it inherits.
- **The editors already diverge**: `editors/emacs/prologos-mode.el:119` and
  `prologos-font-lock.el:220` hard-code the literal **adjacent** `"racket{"`, so
  the editor already requires adjacency while `combine-foreign-blocks` does not.
  P1b-iii *closes* a divergence — but a Racket-side registry cannot reach `.el`,
  so the residual is NAMED as accepted.
- **The back-compat pin the design leans on is SEXP-ONLY** and constrains nothing
  in WS (test-foreign-block's `run-ns` calls `process-string`; sexp `{`→
  `$brace-params` comes from the positionless readtable). The real justification
  for the head carve-out is the **10 live WS adjacent sites**.
- **`$brace-params` is ≥7-purposed → actually ELEVEN** (ten source-level + two
  synthesized). Missing from the design's list: spawn/session overrides
  (parser.rkt:6555), **schema construction `Person {…}` (macros.rkt:2011, 24 LIVE
  SITES — the closest semantic neighbour of a select block, all spaced)**, spec
  metadata blocks (nested brace-params), schema defaults injection (rewrites in
  place). **Independent corroboration of Q_M6**: the only existing
  map-vs-binder discriminator is CONTENT-based (first element is a keyword) and
  lives in preparse — a select block `x{name age}` has BARE-SYMBOL content, so
  reusing `$brace-params` would route select blocks into the binder path.
- **The opener-adjacent population is ~2× the design's 13** — 13 in `.prologos`
  plus 14 live `'[{` in `.rkt` test strings plus `#p({name email})` ≈ 28. If
  `(pair? result)` is dropped, every list-of-maps literal mis-reads its **first
  element only**, at zero errors.
- **⚠ THE GENERALIZATION SHAPE**: `lbrace` must **NOT** join the
  `(memq type '(lbracket lparen))` arm — that arm's closer is a two-way `if`
  selecting `'rparen` for anything not `lbracket`. **Identical to the shape
  P1b-ii hit in surface-rewrite.rkt.** Correct: hoist the adjacency test into a
  named helper consumed by both arms, leaving the brace arm's `'rbrace` intact.
- **P1b-iii FLIPS the P1b-ii FLAGSHIP pin** (test-parse-reader.rkt:438-442),
  written one commit ago — `app-config` is not a reader-form head, so that brace
  becomes a select block. §5.P1b-iii's test-delta named only "NET-NEW `racket{…}`
  pins"; a flip discovered at suite time reads as a regression.
- **The Q_N3 guard is STRUCTURALLY BLIND here, twice**: every row is uniformly
  SPACED (exactly the population that must not change), and it compares ITEM
  COUNTS while this phase's defect class is a **shape divergence at equal
  count**. The pre-existing `xs[0]` case proves the blindness is live. → extend
  it to be shape-aware.
- **⚠ THE A/B TRAP IS PRIMED AT THE WORST FILE**: `lib/examples/foreign.prologos`
  holds **10 of the 12** adjacent sites (83% of the surface) and **is one of the
  6 dirty `.prologos` files** (+19/−3 owner WIP). Both legs must read from a
  materialized `git show 88b3019a:` snapshot. Expected-diff set is **EMPTY for
  both halves** — any non-empty result is a bug, not a change to review.
- **Correction**: the design's "six currently-PASSING markers at RISK" does not
  reproduce — the acceptance file has exactly **two** live ident-adjacent bracket
  sites (`:122 party[0].name`, `:216 mixed[1]`).
- **`(> i 0)` is REDUNDANT** today — `(pair? result)` subsumes it — and becomes
  load-bearing only if that conjunct is removed.

#### The nine-tier registration surface (from Q1; §Q8.5 now carries it)

Not in scope here (no new TOKEN — the decision is positional at grouping): the
five token-layer enumerations P1b-ii co-updated. **In scope**: `group-items`
brace arm · `group-items-to-tree` (SILENT + load-bearing) · tree-parser dispatch
arm (its `else` silently calls `parse-expr-tree`) · `pattern-var?` (LOUD
whole-file abort — the P1b-ii regression) · preparse opacity (macros.rkt:1988) ·
sub-form recursion skip (:2536) · `combine-foreign-blocks` head (:2444) ·
**`access-sentinel?` + the `rewrite-dot-access` fold arm — named by NO
enumeration, and the site that produced the residual** · the parser head-dispatch
arm. Silent-degradation tier, pre-existing and family-wide, NOT chargeable here:
`pp-datum` (handles 11 heads, no access sentinels at all) and
`tools/form-deps.rkt:42`.

---

#### CLOSE NOTES ✅

**Gates**: suite **9304 / 474 / 0** · acceptance **28/28 + 89/89** · battery 501/501 ·
**corpus A/B 158 files, ZERO diffs on both halves** — the audit predicted an empty
expected-diff set and it held.

**⚠ ADVERSARIAL VERIFY CAUGHT THREE BLOCKING DEFECTS, ALL ONE ROOT CAUSE, ALL MINE.**
The fusion arm I added to `rewrite-dot-access` was **not idempotent**: it rewrote
`(x base ($select-brace a))` to `(x ($select-brace base a))` — still sentinel-headed,
so `select-brace?` matched it again. Since `preparse-expand-subforms` re-enters while
the datum keeps changing, each pass swallowed one more sibling to the LEFT:

| consequence | observed |
|---|---|
| multi-arity `defn` clause | `$pipe` head eaten → **clause SILENTLY DROPPED**, function evaluated with the wrong arms, **0 errors** |
| `defn g [x base{a}] x` | silently defined a **4-parameter** function |
| application head | `(h base ($select-brace a))` → `($select-brace h base a)` |

Every OTHER access-sentinel arm rewrites the sentinel AWAY (to `get`/`map-get`) and is
a fixpoint **by construction** — their predicates pin a fixed arity. Mine deliberately
accepted `>= 1`, which removed exactly that protection. **Fixed** by emitting the
NOT-YET marker (`$retired-selection` with a new `select-block` kind) — a non-sentinel
head, hence a fixpoint, and zero new registrations since that sentinel is already in
`pattern-var?` and already has its parser arm. Idempotence is now test-pinned.

The irony is worth recording: this phase's Q_N4 hunk exists to repair a
silent-wrong-answer, and the same commit introduced one.

**SIGNIFICANT findings — fixed in-phase:**
- **The registry did not do its job.** `reader-forms.rkt`'s docstring said "this is the
  ONE list" and that both grouping and preparse require it. **macros.rkt required it
  zero times** and `combine-foreign-blocks` still tested an inline `(eq? v 'racket)` —
  two lists, and the module unified nothing. Now wired; `lang` is derived from the head
  rather than hard-coded.
- **A VACUOUS PIN of my own.** A test titled "reachable inside fn params too" asserted
  on `[fn [x : Int] cfg{host}]` — the select block is in the **body**; the param list
  was untouched. It passed for a reason unrelated to its name. Renamed, and the real
  param-list case added.
- **The Q_N7 justification was FALSE.** The comment claimed that without the
  surface-rewrite fork the guided error "would be SILENTLY SWALLOWED". Disproved by
  construction (a third checkout, byte-identical output over 20 files):
  `same-form-type?` only pairs surf-infer/def/defn/defn-multi, so a preparse ERROR surf
  can never pair with a non-error tree surf — **preparse always wins when it errors**.
  The fork is KEPT (the groupers should agree, and the Q_N3 v2 guard pins it) but the
  justification is corrected in both the comment and here.
- **My diagnostic gave advice that does not work**: it recommended `[x : Int]`, which
  the defn form-shape gate rejects in the very shape that raises the error. Now
  recommends only `[x:Int]`.
- **The `pattern-var?` residual is 23 of 33, not 2** — including `$list-literal`, so a
  plain `'[1 2]` in a defmacro template is a whole-file abort TODAY. Comment corrected;
  DEFERRED item 8 carries the census.

**Filed, not fixed** (DEFERRED items 5–8): the two groupers still diverge on
`<`-adjacent braces — live at `foray.prologos:674`, on the **disclose surface P4 owns**;
binder-position select blocks get a raw-syntax diagnostic rather than the guided error;
and the `pattern-var?` polarity problem.

**What the Q_N3 v2 guard bought**: it is now shape-aware (tag ↔ sentinel across six
brace spellings) where v1 was blind twice over — all its rows were spaced, and it
compared counts when the defect class is shape-at-equal-count.

Status: ✅ `a6af2761`.

**Original design text (superseded in part by the above):**

The forced select-block sentinel (Q_M6) for the non-head-adjacent bucket only;
head-adjacent keeps `$brace-params` UNCHANGED (the spaced-`racket {…}`
back-compat pin, test-foreign-block.rkt:155-160). Leaf-module registry.
Generalize `is-postfix?` beyond `lbracket` while KEEPING `(pair? result)`.
Rule bucket 4. NET-NEW WS `racket{…}` pins — all 13 existing foreign-block
cases pass PARENTHESIZED SEXP source that never reaches `group-items`, so the
head-precedence rule is UNTESTABLE from them; 2 of the 10 live WS sites are
MULTI-LINE bodies, the shape most exposed and the one a single-line pin
misses. Sentinel registration checklist: `pattern-var?` + tree-parser
skip-list.

⚠ **Q_M8 — the `:N` DIGIT RUN WIDENS TO N here.** `recognize-colon-annotation`
(parse-reader.rkt:847) is hard-capped at 2 chars; widen its digit run to
`digit+` (keeping the `:w`/`:m` arms and the trailing `not ident-continue?`
guard, so `:0abc` still declines). This rides P1b-iii because until broadcast
exists `users:10` has no meaning. **Why it is safe, measured**: the recognizer
already accepts 12 lexemes while `mult-annot?` accepts 3, so `:10` is rejected
by the *same* `memq` arm that already rejects `:7` — no new failure mode. It
additionally repairs `{:10 v}`, which SHATTERS today while `{:0 v}`/`{:9 v}` do
not. Zero live `:2`–`:9`/`:m` uses, so nothing live moves. **Owes a corpus
A/B** (tokenizer change) and a pin on both halves: `users:10` one token, and a
binder-position `:10` still loudly rejected.

Status: ✅ (see this section's close notes / the tracker).

**Acceptance delta for ALL of P1b: ZERO markers uncommented** — every line
P1b makes LEXABLE is a P3/P4/P5 SEMANTICS target, and the file's convention
ties uncommenting to a verified `;;N=>` RESULT; there is no honest result for
"this now tokenizes." Reader pins go to `test-parse-reader.rkt`. ⚠ Six
currently-PASSING markers are at RISK if `(pair? result)` is dropped.

<a id="p1b-superseded"></a>

### §5.P1b — (superseded framing; see the three sub-sections above)  ⬜

**Work list**:
1. **`.{` = `dot-lbrace` re-mint** (ruling 3a): the SIX-site co-update (five
   parse-reader sites + the P1a-cleaned surface-rewrite). Prefix-disjoint by
   the audit's band proof; the WS-vs-sexp divergence documented per Q_L2.
2. **Brace adjacency with head-symbol precedence** (ruling 3b): the
   positional adjacency mechanism generalized off `lbracket`-only (keep the
   `(pair? result)` conjunct — 13 live sites depend on it); the FOUR-bucket
   census (spaced · adjacent reader-form head · adjacent select-block ·
   closing-delimiter-adjacent) run against HEAD; **the reader-form-head
   REGISTRY created** as the single source of truth consumed by both preparse
   and grouping (new leaf module or registration parameter — the module-edge
   gap is real); NEW WS `racket{…}` round-trip pins (zero exist today).
3. **Colon seam** (Q_L1): broadcast = expression-position adjacency EXCEPT
   `?`-headed subjects (the narrowing discriminator); **the WS narrow-var
   repair scoped in** (route `?x:T` through the POL.6 splitter or equivalent
   at the WS path; replace the vacuous test-constraint-chain-01:186-193 pin
   with a real one).
4. **`:N` multi-digit** — probe-decided at the Q8 review (`{:10 v}` probe +
   both-modes `:digits` census, per ruling 3c).
5. **Keyword-trailing `*`** — contextual split of `:diags*` (no charset
   change; F1b.7g delegation rule).
6. **`:<` probe row** — BOTH input shapes (benign no-`>` AND the depth-0-`>`
   cross-line swallow) in the Q8 grammar.
7. **Q8 — the deliverable**: the precise lexical grammar for the
   juxtaposition-sensitive characters, including the `.` quadruple-duty
   disambiguation ORDER (`.k` / `.N` / `.*`→retired / `.{`) and the `{`
   four-bucket order (reader-form head ≻ select-block ≻ literal; spaced never
   a block). **Owner-reviewed before landing.**

~~`^` is NOT touched in either half (parser-side split at P3, per the standing
ruling — no second splitter).~~ ⚠ **STRUCK**: superseded by **Q_M7** (§3) —
that ruling was NOT EXECUTABLE (`split-fused-symbol` splits on `":"`; the
tree's only `^` splitter is sexp-only AND keeps empty segments). **P3b builds
THE ONE splitter.** Struck rather than left, because "no second splitter" is
a premise that bites exactly at P3b.

**Test delta**: seam pins in `test-parse-reader.rkt` (RRB-native API — the
three-API finding standardizes here) both modes; the WS narrow-var repair pin
(replacing the vacuous one); WS `racket{…}` pins; adjacency-bucket pins incl.
the closing-delimiter bucket and the binder-brace must-not-change population.
Status: ⬜.

<a id="p2"></a>

### §5.P2 — Grade-1 core

**Intent**: `.k`/`.N` access + bare-path extraction — the spec's grade-1
fragment, on the P2 substrate.

**Grounded head start** (audit + probes): `.N` extraction works END-TO-END
today via a `(get expr N)` fold arm — `expr-get` types PVec (Nat-or-Int) +
Record/tuple(nat-row, EXACT per-position via `record-project`) + Map +
selection-fvar + schema-fvar + List, terminating `[_ (expr-error)]`
(typing-core.rkt:1861-1885); the two-tier principle makes misses loud.
*("site 7 projects" was an UNRESOLVABLE citation — corrected 2026-07-29. It
meant the P2.b round-8 audit's **site 7**, the `[map-get tup 1N]`
fabricated-`none` case closed structurally at `88d1f746`; it is a
predecessor-doc label, not a D4 §7.)* The fold target is `get`, NOT `map-get` (probe: map-get's infer has no
PVec leg). `.k` nominal access already works (dot-access → map-get fold).

**Work**: the `.N` recognizer (dot-anchored, prefix-disjoint inside the
**SIX**-member band {rest-89 · dot-key-88 · dot-lparen-87 · dot-lbrace-87 ·
broadcast-87 · dot-access-86} — ⚠ **this cite has now been wrong THREE TIMES**
(three → five → six); §Q8.1 is normative and was itself self-contradictory
until 2026-07-29. Per Q8.5 invariant 1 the safety property is
**disjointness, not priority**) · the nat-dot fold arm → `(get expr N)` · chain
forms (`admins.0.name`) · extraction typing = the existing arms (no new nodes
expected — flag if that breaks).

⚠ **Q_M8 — `.N` TAKES `digit+`, NOT ONE DIGIT.** Multi-digit ordinal access
is owner-ruled. It is not extra work: the same one-line `digit+` that admits
`x.10` is what kills the rational mis-lex, because a dot-anchored recognizer
consumes `.1` before `decimal-literal` (which anchors at a **digit**) can ever
anchor. `x.1.2` → `($decimal-literal 6/5)` and `x.10.20` → `51/5` at the
reader.

⚠ **"AND THAT FIXES A LIVE SILENT WRONG ANSWER … both at 0 errors" was a LAYER
ERROR — struck 2026-07-29.** End to end all three forms are **LOUD** (`ERROR:
Unbound variable`; `m.-1` → `Could not infer type`; 4 errors, re-probed at
`c5153685`) because the stranded bare `|.|` is unbound. See §Q8.1 for the
two-layer pin this forces. **Failing-test-first on the rational pair at BOTH
layers**, not just on `x.10`, and never framed as "was silently 6/5".

Clarification carried from Q8.1: `.-1` **lexes cleanly** as dot-access with
field `-1` (`ident-start?` admits `-`). A digit-required `.N` correctly declines
it, but the carried "`.-1` = classifier rejection" ruling is therefore about a
**well-formed token** and is a CONSUMER decision, not a classifier one.

#### Mini-audit `wf_22020418-a5f` — what it changed  (6 facets + critic @ `c5153685`)

**12th consecutive phase whose premise it refuted or rescoped.** The doc-truth
half landed separately (`0e5a56a3`, ruling Q_R6). What it changed about the
WORK:

1. **The sentinel choice was never ruled, and it sets the whole cost** → Q_R1
   (reuse `$postfix-index`). Both naive `$dot-access` reuses are broken: a
   numeric payload hard-raises (whole-file abort), a symbolised one silently
   mints the wrong node with the wrong key domain.
2. **The fold arm's fixpoint question is ANSWERED, not open.** The existing
   fold is a fixpoint *by construction* because no arm's output is
   sentinel-headed: re-entry is gated on the datum having CHANGED
   (macros.rkt:2527-2534) and the ormap gate short-circuits (:5537), so pass 2
   is a no-op. Every live arm emits `map-get` / `nil-safe-get` / `get` /
   `$retired-selection`, none of which matches any of the eight
   `access-sentinel?` predicates. **`(get target N)` inherits the property** —
   which is a second, independent reason Q_R1's reuse is the safe option, since
   P1b-iii's BLOCKING defect was exactly a non-fixpoint fold.
3. **`token-entry->stx`'s `case type` is the site that matters, and a miss
   there is SILENT** (parse-reader.rkt:2264; copy the `dot-access` template at
   :2265-2270). ⚠ Build the payload with **`string->number`**, not the
   siblings' `string->symbol` — that is what makes it byte-identical to
   `v[0]`'s bare fixnum and thus what makes Q_R1 actually hold.
4. **Two work items are FREE or already done.** "Chain forms
   (`admins.0.name`)" is free — chains arrive as flat top-level siblings and
   the existing single fold-left handles them in one pass. "Bare-path
   extraction" already works at top level, `def` RHS, HOF lambda, and spec'd
   `defn`; the ONLY gap is a `defn` with an UNANNOTATED param, which is the
   **§5.PX** inference family, not a `.k`/`.N` gap. §5.P2's Intent silently
   promised that; it does not deliver it and should not pretend to.
5. **The A/B diff set is predicted EMPTY** — zero non-comment `ident.digit`
   occurrences across all 160 tracked `.prologos` at HEAD, computed with the
   REAL tokenizer over a clean `git archive HEAD` snapshot. ⚠ **The dirty-tree
   trap is quantified in advance at exactly ONE site**:
   `lib/examples/foray.prologos:787` (`app-config[admins.0[name^ role^]]`),
   owner WIP, absent at HEAD. **If the A/B reports one diff in `foray`, that is
   THE TREE, not the change.**
6. **`rewrite-dot-access` has THREE production callers, not one** —
   macros.rkt:1957 (`preparse-map-literal-contents`, map-literal VALUES),
   :2527 (the re-entry), :6236 (`expand-mixfix-form`, the `.( … )` token stream
   before pratt-parse). A `.N` arm placed *inside* `rewrite-dot-access`
   inherits all three free; anywhere else silently misses `{:k x.0}` and gives
   "Unexpected token after expression" for `.(x.0 + 1)`.
7. ⚠ **A FALSE PREMISE in the predecessor is struck**: its D3-era prescription
   was "one fold arm plus **stopping that re-entrancy**". The re-entrancy is
   **LOAD-BEARING** — `v[idx.i]` → `20 : Int` works *only* because the payload
   is re-preparsed. Do not stop it. What it actually gets wrong is narrow (a
   LITERAL-headed payload, `v[1.b]`, folding to `(map-get 1 :b)`) and the
   result is an unguided error, not a wrong value.

#### Work (as ruled)

- **The recognizer**: dot-anchored, `digit+`, with the Q_R2 `ident-continue?`
  trailing guard; prefix-disjoint from all SIX band members (§Q8.1); priority
  87 or 88, placed in source order inside the dot cluster — but per §Q8.5
  invariant 1 the safety argument is **disjointness, not the number**. Use
  `(char<=? #\0 c #\9)` rather than `char-numeric?` (Unicode-wide vs
  `string->number`'s narrower domain — a NARROWING, so the F1b.7g rule
  permits it).
- **The token→datum arm** at `token-entry->stx` (site f), payload via
  `string->number`, minting `$postfix-index`.
- **No fold-arm change is expected** (Q_R1 reuse) — but VERIFY, and flag if the
  existing arm needs anything.
- **Q_R5's error surface**: un-gate `closed-row-miss-hint` for the nat
  key-domain so het-tuple out-of-range names arity and index instead of "Could
  not infer type"; and make the `postfix-hole` message spelling-agnostic (it
  currently gives bracket advice, which `_.0` would now reach).
- **NEW-instance guards P2 must not introduce** (the audit's "does P2 create a
  new instance" pass): `namespace.rkt:888`'s ns-dot guard raises only for
  `$dot-access`, so `ns foo.2` would **SILENTLY DROP** the segment —
  reintroducing exactly the bug `b0db8f3e` fixed. Extend its memq. Same class:
  `reconstitute-selection-paths`/`-path-list` (macros.rkt:2695, :2700) are
  `$dot-access`-only, so a WS selection path with an ordinal segment
  (`:items.0`) is not reconstituted — verify and fix or file.
- **Commit the corpus A/B harness.** There is NO committed harness; it is
  re-derived every phase, which is how P1b-ii's first run measured the tree.
  Two live footguns to encode: `tokenize-char-rrb` reads a MUTABLE registry
  populated only inside the reader entry points, so a direct call matches
  NOTHING (one facet's first scan returned a FALSE ZERO for exactly this — put
  a tripwire in); and the walker must skip leading-`.`/`~` basenames (a
  dangling Emacs lock symlink for the acceptance file exists right now).
- **§Q8.3 one-liner for P4** (forward obligation the audit found): the new
  `.N` token becomes the adjacency PREDECESSOR of a following `:name`
  (`xs.0:name`), so §Q8.3's FOCUS-BEARING token set must admit it or broadcast
  silently fails to fire at P4. One line now prevents a P4 rediscovery.

#### Named NON-goals and pre-existing exclusions (so P2 is neither blamed nor tempted)

- **`xs.0N`** — sensible-looking Prologos that the Q_R2 guard declines. Named,
  not missed.
- **`expr-pvec-nth` REJECTS Int literals on a nat-row while `expr-get` ACCEPTS
  them** (typing-core.rkt:2228-2235, deliberate and commented). After P2, `t.1`
  (→ `get`, Int OK) and `[pvec-nth t 1]` (Int → error) answer differently for
  the same subject. **Do NOT "fix" this** — `.N` routes through `get`.
- **`\.` is ALREADY mis-lexed** (`recognize-backslash-char` rejects `.`) and is
  the SOLE bare-dot token in the whole HEAD corpus (space-followed, so P2 does
  not touch it). `\.5` newly changes. Pre-existing; excluded.
- **`compat-tokenize-string` RAISES "Unexpected character: ."** on a bare `.`
  while the production path emits `|.|` silently (parse-reader.rkt:2136-2138).
  After P2 that raise stops firing for `.digit` inputs. Its sole dependent test
  uses a SPACED dot so stays green — but it is a bare `(check-exn exn:fail? …)`
  with no message match; tighten it while in the area.
- **DEFERRED items 1–8**: none are fixed by P2. **Item 8 must not be
  disturbed** — `pattern-var?`'s 23-of-33 residual (including `$list-literal`,
  so `'[1 2]` in a defmacro template is a whole-file abort TODAY); the ruled
  fix is INVERTING the predicate's polarity, not adding exclusions, and Q_R1
  means P2 adds no entry at all. Item 5 (`<`-adjacent grouper divergence, live
  at `foray.prologos:674`) is **P4's**, on the disclose surface.

#### Test delta

Failing-test-first, and the rational pair is pinned at **BOTH LAYERS** per the
§Q8.1 correction: (a) reader/datum pins (`x.10` · `x.1.2` · `x.10.20` — today
`($decimal-literal 6/5)` / `51/5`, after `(get (get x 1) 2)`), (b) end-to-end
pins framed *"was a misleading error, now computes the right value"* — never
"was silently 6/5". Plus: the four subject types (PVec / het tuple / Map /
List) in-bounds and out-of-range · **the `v[0]` ≡ `v.0` datum-identity pin**
(what makes Q_R1's "two surfaces, one mechanism" checkable rather than
asserted) · the Q_R2 guard's five declining shapes · the Q_R3 spaced-`.0`
ruling · `.-1`/`.+1` as a consumer decision · the fixpoint pin (once ≡ twice,
modelled on tests/test-path-selection.rkt:867-879 from P1b-iii) · the
lying-diagnostic repairs (`{:a m.0}` · `[fn [v] v.0]` · bare `m.0`) · the ns
guard · a both-modes census note (sexp is structurally unaffected — the sexp
readtable binds no `#\.`, and the sexp IR spelling for ordinal access is
already `(get x 0)`, so `.N` adds NO new divergence, unlike `.{`'s Q_L2).

⚠ **Probe trap the audit flagged twice**: `prologos-read` (parse-reader.rkt:3130)
is the **WS** reader. A "sexp mode" probe routed through it silently measures WS
and manufactures a phantom divergence — use `prologos-sexp-read`.

Corpus: `m.0` moves out of the §10.6 v2 block (Q_R4) and trailing markers land
before line-118's 23-renumber edit. Status: ⬜.

#### CLOSE NOTES ✅ `3005170b`

**Gates**: suite **9370 / 475 / 0** (from 9304/474 — +66 tests, +1 file) ·
acceptance path-selection **35/35** (from 28) + records **89/89** ·
neighborhood battery **558 / 16 files** · reader corpus A/B **158 files, ZERO
diffs**, both legs pinned to identical HEAD content. The audit PREDICTED an
empty diff set and it held, and its quantified dirty-tree prediction held too:
the one site a working-tree A/B would have flagged is `foray.prologos:787`
(owner WIP, absent at HEAD), which does read differently under `.N`.

**Shipped**: the `recognize-dot-ordinal` recognizer (`digit+`, Q_R2 guard,
ASCII-digit gate, priority 87 by disjointness) · the `token-entry->stx` arm
minting `$postfix-index` with a `string->number` payload · Q_R5's ordinal
miss-hint · the `namespace.rkt` new-instance guard · a spelling-agnostic
`postfix-hole` message · plus two pieces of committed infrastructure the track
had been re-deriving by hand (below).

**⚠ THE ADVERSARIAL VERIFY CAUGHT A DIAGNOSTIC REGRESSION I INTRODUCED** — 5th
behavioural slice running, and still nothing a green suite could see.
`ordinal-key-index` accepted ANY `expr-int` including NEGATIVE, dropping the
`exact-nonnegative-integer?` half of the guard it mirrors
(`record-project`'s literal-nat leg) — the **infer/inferQ-twin drift shape**.
Because the ordinal branch sits FIRST in `closed-row-miss-hint`'s `or`, a
negative literal produced a hint asserting an expression was out of range when
that expression **type-checks fine** (`record-project` routes a negative literal
to the dynamic path, which succeeds as the union of positions) — *and* that
false hint SUPPRESSED the correct keyword closed-row-miss hint on the same
expression. Strictly worse than the message it replaced.
The adjudicator **worktree-pinned a baseline and A/B'd**, which is what turned
this from "a gap" into "a REGRESSION" and made it commit-blocking. It is
unreachable from `.N` (which cannot lex a sign) and from `het[-1]` (the
`postfix-neg` marker intercepts) — the reachable surface is the paren-keyword
form `(get het -1)`, which is **exactly why no `.N` test caught it**. Fixed +
3 pins.

**Two more verify fixes**: the `token-entry->compat` sibling arm (**four lenses
found it independently** — the token fell through to `|.10|`, contradicting both
its dot-band siblings and Q_R1's numeric payload) and `closed-nat-row?` used
instead of hand-inlining its three-way conjunction.

**⚠ AND A LAYER ERROR IN MY OWN COMMENT — the THIRD instance of that class in
this phase**, after `0e5a56a3` (§Q8 contradicting itself) and `f6f30eaa` (the
phase headline). It called the `char-numeric?` counterfactual a "SILENT WRONG
DATUM … worse than" the audit's predicted `exact?: contract violation`. Both
halves were layer-confused: the `#f` payload is silent only at the DATUM layer
(end-to-end it is a LOUD per-command error with the file continuing, i.e. LESS
severe), and the audit's prediction describes the SHIPPED path correctly — it
was right, not superseded. The same comment block gets the distinction right 30
lines earlier. **Corrected in the comment.**

**Three of my own TEST defects, caught before the commit**: a **VACUOUS pin that
PASSED** (bare `#rx"9"`/`#rx"3"` matched DIGITS IN THE TEMP-FILE PATH inside a
printed error struct — the identical trap this arc already hit); a
**MIS-PREMISED pin** (`.( v.0 )` is a single-operand mixfix that errors
identically on the baseline with a plain `.name`); and a **ruling I had stated
wrong from the audit's own text** — a space BEFORE the dot is irrelevant, but a
space AFTER it means there is no `.N` lexeme at all, contiguity being inherent
to a token. The audit conflated the two spaces.

**Design claims the audit corrected**: two work items were FREE or already done
(chains fall out of the existing fold-left; bare-path extraction already works
in 3 of 4 positions, the 4th being §5.PX's inference family, which §5.P2's Intent
silently promised) · the predecessor's "stop that re-entrancy" prescription is a
**FALSE PREMISE** — the re-entrancy is LOAD-BEARING, `v[idx.i]` works only
because the payload is re-preparsed · `rewrite-dot-access` has **THREE**
production callers, so the `.N` arm inherits map-literal values and the `.( … )`
token stream free.

**New committed infrastructure** (both were being re-derived by hand every
phase, which is how P1b-ii's first A/B measured the tree):
- **`tools/reader-corpus-ab.rkt`** — refuses to guess a corpus (`--corpus is
  REQUIRED`) so both legs must be handed the same snapshot, and carries a
  TRIPWIRE for the mutable-registry footgun that gave one audit facet a
  confident FALSE ZERO.
- **`tests/test-path-selection-acceptance.rkt`** — this file's siblings were all
  gated; it was not, so "N/N markers" had been hand-verified since P0. Fine while
  phases only APPENDED; P2 uncomments mid-file and shifts ~20 markers, which is
  precisely the situation that produced the Rel T1 misnumbering defect. Also
  pins that no two markers claim the same index — P2's own first attempt did
  exactly that.

**DEFERRED 9–13**: the ordinal hint's cross-domain blindness (`cfg.0` especially
— the adjudicator's pick as the most plausible first-contact error, in mild
tension with Q_R5's own rationale) · a possibly-unreachable zero-arity branch
(the VAG's red flag) · **the trailing guard blocking `^`, a landmine for P3's
RE-KEY** (`x.0^` declines while `x[0]^` lexes — the two spellings Q_R1 unified
would diverge on exactly the character P3 introduces) · `reconstitute-path-list`'s
`$dot-access`-only walk · the `tokenize-string` raise→token flip.

<a id="p3"></a>

### §5.P3 — Blocks  ✅ COMPLETE (P3a `290f77f9` · P3b `36ce601c` · P3c `1b021d57` — the Q_T batch; split per Q_T5)

**The §3 Q_T rulings govern this phase.** The mini-audit (`wf_27a84061-c7e`,
7 facets + critic @ `76214095` — 13th consecutive premise refuted) fed a
deliberative one-question-per-turn co-design with the owner; every ruling and
its rationale is in the §3 ledger. This section is the IMPLEMENTATION shape.

**What the audit established** (all probe-verified, load-bearing for the
slices): the KEYED result needs no new row machinery (an all-keyword map
literal already mints the corpus's closed rows — but Route A was ruled anyway,
on completed-architecture grounds, Q_T1); the KEYLESS sort CANNOT be desugared
(`@[…]` collapses to PVec at EVERY homogeneous n, so both §B keyless lines are
unreachable via literals); STRICT MERGE cannot be inherited (`make-record`
silently last-wins — the check runs BEFORE minting); the P1a gate has a HOLE
at `spec` (DEFERRED 14 — P3 ships its OWN type-position refusal); and NO
tokenizer changes are needed (every ruled spelling already lexes), so NO
corpus A/B is owed.

<a id="p3a"></a>

#### §5.P3a — The node + keyed blocks, no `^`  ⬜  ← the fresh session opens here

**Work**: `surf-select` + `expr-select` per pipeline.md § New AST Node in
FULL — struct + provides + `expr?` · `shift`/`subst` · zonk ×3 · `whnf`/`nf`
(+ `whnf-trivial?` if stuck-classified) · `pp-expr` · **pnet-serialize
REGISTRATION (no bump — §8 R6 as corrected)** · `infer`/`check` · **the
`inferQ`/`checkQ` twins** (delegation model `cdb535ac`: TYPE delegated to
`infer`, USAGE mirroring `checkQ`) · surf struct + parser arm + elaborator
arm. No binder ⇒ no depth routing; cold walkers ride the generic
transparent-struct fallback.

**The preparse seam** (replaces P1a's NOT-YET marker for the shapes this
slice handles): the fold arm fuses `[base, $select-brace …]` into a
`$`-headed, NON-access-sentinel datum head (the fixpoint requirement — hazard
1; the baseless leg REMAINS as the "needs a subject" backstop per the audit's
C23). That new head pays its SUBSET of the nine-site surface: `pattern-var?`
(the loud-if-missed site) + the parser head arm; NO reader token ⇒ no
token-layer sites; it must NOT join `access-sentinel?` (that is what makes the
fold a fixpoint).

**Semantics**: payload segmentation (a non-sentinel item OPENS a branch;
following access sentinels ATTACH; `$dot-brace` recurses); typing = per-branch
copattern demand with **Q_T2 D-lenient presence** (sourced-`'present` or a
loud refusal naming seal/validate/annotate) + assembly into a CLOSED keyword
row; reduction = subject evaluated ONCE, then per-branch extraction; **the
duplicate-output-key check runs BEFORE `make-record`** (plain keys at this
slice; remedies `^k'`/`^_` named in the message); the malformed-payload seat
(empty block `x{}` gets its OWN arm AHEAD of L4 — zero branches is vacuously
both sorts and `record-value-union` raises on empty; bare keyword items;
`$rest`; stray `|.|`; bracket groups); the TYPE-POSITION refusal; miss errors
via `format-closed-row-miss` WITH branch context (the audit's C9 answered).

**Test delta** (⚠ corpus list CORRECTED 2026-07-30 — ruled **Q_U1** [owner]:
**P3a owns EVERY no-`^` block line**; the list below was previously written
against no file — it named `{name}`, which does not exist in §B (a
mis-transcription), and left three no-`^` lines unassigned, the §9
"assigned to NO PHASE" class landing on this slice's own work list): node
pins (fixpoint incl. LEFT siblings · `pattern-var?` via macro USE, not
registration — the P1b-ii lesson) · E2E keyed corpus — `{database}` ·
`{server.{host port}}` · `{server.{ssl.{enabled}}}` (was unassigned) ·
`def sub := app-config{server.{host}}` + re-projection · `regions{eu us}`
(§I :320, was unassigned — a plain keyed n-ary selection over a closed-row
subject; its own `[D4.P3]` line tag is correct, the §10.5 heading's
`[D4.P4]` covers only the broadcast lines) · the error battery (`{zzz}`
names available fields + the branch · `{}` · duplicate plain keys ·
dyn-subject refusal · `(Map K V)`-subject refusal · type-position) · twins
pins (a block in a `def`/`defn` body under QTT) · **§9's learnability
pair**: `x.a.b` vs `x{a.b}` side by side, and the block-side miss message
names the extraction spelling. NOT P3a's despite its `[D4.P3]` tag: §G's
seal/validate pair (acceptance :240-245) uses `server^.{host port}` —
mid-path dissolve ⇒ **P3b's** (its delta now names it, per Q_U1). Gates:
targeted battery · acceptance `--check` · full suite · adversarial verify.

**CLOSE NOTES ✅ `290f77f9`** (opened `6d919142` with Q_U1; failing-test-first
— 34 pins RED at open, each failing on the NOT-YET marker, i.e. for the
reason its name claims).

**Gates**: suite **9418 / 475 / 0** (from 9370 — +48) · acceptance **41/41**
(from 35; the 6 new markers value-verified before pinning; the renumber
gate-checked, no duplicate indices) · battery **136/136** · neighborhood
**623/623 over 21 files** (incl. the pipe-compose and schema/seal families
the verify fixes touched) · **zero tokenizer changes ⇒ no corpus A/B owed**
(Q_T5, as predicted).

**⚠ THE ADVERSARIAL VERIFY CAUGHT A BLOCKING DEFECT — 6th consecutive
behavioural slice, and this one was a SILENT WRONG VALUE at 0 errors.**
Block-form `|>` with a select init: head-macro dispatch runs BEFORE the
access-sentinel fold, and the pipe's step builder appends its accumulator
into whatever datum a step is — appending into a raw `$select-brace` payload
CORRUPTED it (`|> cfg{server} f` → `($select-brace server cfg)` → the later
fold fused the corrupted select onto the FUNCTION). With an adversarial `f`
whose row offered the keys, the wrong select evaluated silently. Pre-P3a the
same input was a guided error — the slice turned a refusal into corruption,
which is exactly what the verify exists to catch. **Fix**: a pipe-local
pre-fold (`expand-pipe-block` runs `rewrite-dot-access` over its raw parts
first — sound because the fold is a fixpoint). The general
head-macros-before-fold ordering is DEFERRED 17 (the if/cond/let siblings
are LOUD-but-lying and dot-identical, i.e. pre-existing).

**Three SIGNIFICANT, all fixed pre-commit**:
1. **The `$select` subject was never preparse-expanded** — the fold-arm
   comment's premise ("already expanded when fused") was FALSE: the fold at
   the subforms seam runs BEFORE per-subform recursion. Compound subjects
   (bracket groups, map literals with dot-access values, selects-of-selects)
   froze raw sentinels into lying downstream errors. Fix: `$select` is now
   PARTIALLY opaque — the subject expands, the payload stays protected.
2. **Schema-sealed subjects refused wrong-kinded** (found by TWO skeptics
   independently) — `sealed{name}` hit 'subject-other while the refusal
   messages named "seal the subject" as remedy #1, a circular dead-end. Fix:
   `select-project` projects THROUGH schema fvars via `schema->row`
   (all-'present by construction — the strongest Horn-D source; the
   dot-access arm has carried the same leg since F1). SELECTION-typed
   subjects stay refused on read-capability grounds (DEFERRED 20).
3. **`^`-bearing items fabricated field misses** (`cfg{version^}` → "field
   :version^ is not present … spelled `.version^`") on exactly the spellings
   the duplicate message recommends. Fix: a P3b-pointer arm in the
   segmentation seat, symmetric to the ordinal arm's P3c pointer, gating
   both branch-head and dot-access-attach positions. ⚠ P3b REPLACES this
   gate with the real splitter.

**Q_T2 adaptation — RATIFIED [owner, 2026-07-30: "the adaptation stands —
annotate comes back when it's real"]**: the remedy list as ruled named seal /
validate / **annotate** — the verify found "annotate its row type" has NO
working spelling at HEAD (row-literal annotations refuse everywhere; zero
in-tree uses — DEFERRED 19), i.e. the P1b-iii advice-that-does-not-work
class. The messages name only the two VERIFIED remedies (seal via
`the Schema subj`, validate); annotate re-enters when row annotations become
writable (DEFERRED 19 carries the trigger).

**Also hardened at the verify**: ground non-map subjects PANIC at the whnf
arm (was a silent stick, asymmetric with the loud nested descent —
`definitely-not-map?` consulted); trailing steps after a terminal `@sub`
PANIC instead of silently vanishing (constructed-IR only; the parser grammar
forbids the shape); two dead negative pins fixed (an open row prints `{… |
_}` — the pipe is INSIDE the braces, so the original `} |` regexp could
never fire); `~s` for string items (a bare `s` rendering was
indistinguishable from the valid spelling); the sub-block empty message no
longer claims `{}` is a map literal.

**Scope rulings surfaced mid-slice**: mid-branch ordinal steps
(`{admins.0}`) are REFUSED loud — ruled **Q_U2 Reading A** at the close
checkpoint (descent, no output level; lifts at P3c); multi-arity defn clauses with HETEROGENEOUS result
types fail PRE-EXISTING with a lying unannotated-param diagnostic
(select-free control `| 0 -> {:a 1} | n -> 5` pinned it; filed as a spawned
task) — the multi-arity pin uses same-row arms with distinct VALUES.

**Pre-existing, filed not fixed** (DEFERRED 15–20): the def-RHS block-pipe
(baseline worktree-pinned at clean `6d919142`) · the do-expander
whole-file-abort family · the head-macro raw-sentinel family · the dyn-assoc
type/value desync selection would otherwise launder · row annotations ·
selection-subject capability alignment.

**P3b watch items** (from the verify): the fold fuses against ANY left
sibling incl. non-expression sentinels (`$angle-type` in the pre-existing
spec-hole context, `:=` — both loud or pre-dropped today; the splitter round
should decide a fusable-base posture) · the `re-key-sym?` gate is P3b's
demolition site · `format-select-fail`'s 'unknown wording will misreport a
future 'optional mark (no producer today).

<a id="p3b"></a>

#### §5.P3b — The `^` family  ✅ `36ce601c`

**Work**: the ONE splitter over glued lexemes (Q_M7: nothing liftable — the
sexp splitter keeps empty segments, F1b.7g class), continuation grammar
`-`?·{ε | label | `_`}, plus `^..` recognized over the bare-`|.|` datum shapes
(`[seg^, |.|, |.|]`); dissolve/splice (mid-path `^`); in-place rename `^k'`;
`^_` Reading N (computed label, in place); the `^-` collapse family
(`^-` / `^-k'` / `^-_` — leading `-` after `^` reserved); `^..` parent-key
collapse (ancestors above the parent kept); **the output-level-local
duplicate check** (Q_T3) with `cfg{server^.{port} database^.port}` as the
NAMED monotonicity pin; the Q_T4a ordinal-`^` guided error (one message, all
spellings: `x.0^`, `x[0]^`, `{admins.0^first}` → "an ordinal has no key;
rename the nominal segment: `admins^first.0`"); the malformed-`^` battery
(`a^b^c` · lone `^` · spaced `^b` · `^...`-absorbs-`$rest` rejected).

**Test delta**: splitter unit pins per continuation · the flagship E2E ·
rename/dissolve/`^_`/`^-`/`^-_`/`^..` corpus lines · §G's seal/validate pair
(acceptance :240-245 — `[D4.P3]`-tagged but `^`-bearing, assigned HERE per
Q_U1) · duplicate-leaf error naming remedies · the monotonicity pin · the
ordinal-`^` battery. Gates as P3a.

**CLOSE NOTES ✅ `36ce601c`** (failing-test-first — 29 pins RED at open,
each failing on the P3a re-key pointer / stray-`.` text / unbound-`^` it was
named for; the light re-grounding re-verified the demolition-site coordinates
+ the hazard-4 lex shapes + the Q_T3 naive-lowering baseline before any code).

**Gates**: suite **9469 / 475 / 0** (from 9418 — +51) · acceptance
**50/50** (from 41 — the six §B `^` lines + the §G seal/validate pair, all
value-verified before pinning; renumber gate-checked, no duplicate indices) ·
track battery **178** test-cases · neighborhood **433/433 over 10 files** ·
**zero tokenizer changes ⇒ no corpus A/B owed** (Q_T5, as predicted — the
`^-`/`^-k'`/`^-_` glue and the `^..`→`|.| |.|` shatter were probe-confirmed
at the re-grounding).

**Shipped**: `split-caret-lexeme` (THE ONE SPLITTER; continuation grammar
`-`?·{ε | label | `_`}; refuses >1 `^`, `--`-leading, digit-leading and
keyword rename targets) · the `(@key name cont)` step vocabulary + the
SHARED branch walk in syntax.rkt (`select-branch-top-keys` /
`select-synth-name` — parser check, typing and reduction consume the SAME
walk, the twins lesson applied to check+meaning) · mid-path dissolve/splice ·
in-place rename · `^_` Reading N (seen-steps threading — the first battery
run caught the truncated-branch synth) · the `^-` family · `^..` desugared
at segmentation to the ruled `[P^ L^P]` (fused `^..enabled` / `^..{…}`
continuations agree with the spaced spelling) · the Q_T3 OUTPUT-level
duplicate check (the monotonicity pin errors) · Q_T4a's ONE message across
all three datum shapes (segmentation arms + an ELEMENT-WISE `ordinal-rekey`
marker in the preparse fold) · the malformed-`^` battery · keyless leaf `^`
refuses with the P3c pointer (the boundary note honored — parsed, refused).

**⚠ THE ADVERSARIAL VERIFY CAUGHT A BLOCKING DEFECT — 7th consecutive
behavioural slice, and it was MINE.** The first `ordinal-rekey` seat
replaced the WHOLE datum with the guided marker: a `match` arm containing
`v[0]^` lost its `->` and hit the pre-existing arrowless-arm raw crash — a
WHOLE-FILE abort (zero commands) where HEAD recovered per-command. The same
root cause swallowed a defn clause (lying "defn requires…" diagnostic),
broke map-literal arity ("even number of elements" on a well-formed
literal), and shredded pipe inits. **Fix: ELEMENT-WISE replacement** (the
P1a dot-key precedent — the marker replaces base+ordinal+caret only,
siblings survive), + 11 regression pins. The crash SITE (arrowless match
arms raw-crash on their own) is pre-existing and filed (DEFERRED 22).

**Eight SIGNIFICANT, all fixed pre-commit**: fused `^..` continuations
missed the two-bare-dot lookahead → INVERTED stray-dot advice ("write the
path with no spaces" on a spaceless input) — the lookahead now accepts
fused `($dot-access …)`/`($dot-brace …)` second dots, and the `^.`
near-miss + renamed-leaf-`..` shapes get a `^..`-aware message ·
`k^...label` leaked the internal `($rest-param …)` sentinel verbatim (the
`$rest` arm now matches the tagged shape) · **the duplicate message's `^_`
remedy REPRODUCED the collision in both canonical dup classes**
(dissolved-ancestry synth = the colliding leaf name, correct per Q_T4b′ —
so `^_` was dropped from THAT message, the advice-that-does-not-work class;
`^k'` + sub-block grouping are probe-verified live) · the P3c ordinal-step
pointer now NAMES its phase, closing the Q_T4a advice loop (the ruled
example `admins^first.0` lands on it until P3c) · a VACUOUS `#rx"-"` pin of
mine matched the temp-file path in the transparent error struct (the arc's
own trap, third sighting) · digit-leading rename targets (`k^0`, `k^-0`)
minted a dot-unreachable `:0` field at 0 errors — refused (the one minor
the adjudicator promoted) · `{0^first}` escaped the ONE Q_T4a message ·
`server^{x}` lost its segment name to a "field" placeholder.

**Interpretation pinned eyes-open — RULED Q_U4 at the close checkpoint
[owner, 2026-07-30]**: `^_`/`^-_` synth scope shipped as
**branch-of-its-block** (`server.{host^_}` → `{:server {:host …}}` vs the
dot spelling's `{:server {:server-host …}}`). The owner ruled SUBJECT-ROOT
is preferred (a sub-branch is less likely to share a common leaf key) but
not high priority — the flip is DEFERRED until it next matters (P5's L2
factoring is the natural trigger; DEFERRED 23 carries it).

**Filed, not fixed**: DEFERRED 21 (`k^:x` keyword rename target — the
splitter's `#\:` arm is WS-dead, sexp-only reachable; degraded-not-lying) ·
DEFERRED 22 (arrowless match arms raw-crash — pre-existing, the Q_L4
marker-seat class, the P3b BLOCKING finding's crash site).

**P3c watch items**: the keyless-leaf refusal + the ordinal-step refusal
are P3c's demolition sites (their pins flip); Q_U2's discriminating pair
`admins.0` vs `admins.{0}` is P3c's; the `^..`-fused sub-block continuation
(`^..{…}`) now parses through the desugar — P3c's keyless work must keep it
keyed-only.


<a id="p3c"></a>

#### §5.P3c — Keyless + L4 + honest nesting  ✅ `1b021d57`

**Work** (⚠ boundary note: P3b ships the SPLITTER and every MID-PATH `^`
semantic; the LEAF-position keyless reading lands HERE, because a keyless
branch only means something once the tuple carrier exists — so P3b's close
leaves a leaf `^` parsed-but-refused, and P3c makes it assemble):
bare leaf `^` = keyless component (the branch contributes the leaf VALUE);
**mid-branch ordinal STEPS per Q_U2 Reading A** (the P3a refusal lifts: `.N`
in a keyed branch descends, NO output level — typing = the element type via
the existing PVec/het-tuple arms, reduction = the existing rrb path; the
test delta adds the DISCRIMINATING PAIR `admins.0` vs `admins.{0}` — descent
vs 1-tuple); ordinal branches `{N M}`; the nat-row mint at EVERY n — 1-tuples and
homogeneous n included, which is the entire reason selection routes around
the literal arm (ruling 2a as corrected by the audit); L4 sort homogeneity
(all-keyed → Map, all-keyless → tuple, MIXING errors level-locally — both
sorts must exist before the error is expressible, hence this slice); honest
nesting display (`⟨String⟩` at n=1 — a pin, not a decision: `pvec-slice`
already mints and prints it).

**Test delta**: `{server.host^ database.url^}` → `⟨String String⟩` ·
`{version^}` → `⟨String⟩` · `{N M}` ordinal selection with fresh indices ·
the L4 mixing error (`{version^ server.port}`) · **the G11 one-space pair
pinned side by side** (`{a^0}` keyed-rename-to-`:0` vs `{a^ 0}` keyless
2-tuple). Gates as P3a; P3c closes the phase → the P3 close notes + the
per-phase 5-step gate.

**CLOSE NOTES ✅ `1b021d57` — P3 (BLOCKS) IS COMPLETE** (failing-test-first
— 16 pins RED at open on the three P3c pointers; the light re-grounding
probed the demolition sites, the `pvec-slice` ⟨⟩ mint, and the G11 conflict
before any code).

**Gates**: suite **9497 / 475 / 0** · acceptance **52/52** (from 50 — §B's
two keyless lines, value-verified) · track battery **204** test-cases ·
neighborhood **410/410 over 11 files** · **zero tokenizer changes across the
WHOLE PHASE** (Q_T5's exemption held P3a→P3c; no corpus A/B ever owed).

**Shipped**: the KEYLESS sort — `^`-terminated branches contribute leaf
VALUES; ordinal branches `{N M}` re-derive in written order; the nat-row
mint at EVERY n (ruling 2a — `cfg{version^}` → `@["1.0.0"] : ⟨String⟩`,
honest, never a collapsed PVec) · **Q_U2 Reading A** — ordinal STEPS descend
with no output level; the discriminating pair pinned (`{admins.0}` →
`{:admins row}` ≠ `{admins.{0}}` → `{:admins ⟨row⟩}`); the `(@ord N)` head /
bare-number step distinction keeps dissolve-splice continuations keyed ·
**L4** at the OUTPUT level over the shared walk's components (spliced
keyless into a keyed level errors; sub-levels check themselves) · **B5** —
keyless levels concatenate, NO dup check (`{version^ version^}` = legal
⟨String String⟩) · typing `select-index-of` (PVec / closed-nat-row with
static OOB) + the components model `(key-or-#f . field)`; reduction mirrors
with `rrb-from-list` + bounds-checked `index-into` (PVec runtime OOB panics
LOUDLY with the length — the P2.b tier) · the three P3-pointer arms
demolished; **the Q_T4a advice loop closes END-TO-END** (`{admins^first.0}`
executes: rename, then descend).

**Two twin-drift catches at the RED battery** (mine, pre-verify):
reduction's `below-value` dropped the `seen` synth threading, and the whnf
arm admitted only champ subjects — ordinal blocks over vectors would have
panicked as non-maps.

**⚠ THE ADVERSARIAL VERIFY: NO BLOCKING — the FIRST slice in EIGHT without
one.** 2 SIGNIFICANT + 3 MINOR, all fixed pre-commit:
1. (SIGNIFICANT, mine, the Exhaustive-Walkers twin-drift class) ordinal
   heads + keyless/collapse LEAVES pre-classify into `walk-to-leaf`, whose
   dispatch missed the `(@ord N)` pair — `admins{0.name^}` got a LYING
   "not a record" on a PVec the keyed twin works on; on records the hint's
   swallow-all ate a format throw → a BLANK generic. Fixed with the @ord
   arm in BOTH walks ATOMICALLY — the adjudicator flagged that fixing
   typing alone would have converted the loud lie into a runtime champ-of
   panic (i.e. CREATED a blocking).
2. (SIGNIFICANT) `{N.M}` fused-decimal spellings leaked the internal
   `($decimal-literal q)` sentinel with the rational value — the guided
   collision arm names `x{N .M}` / `x{N.{M}}` (the leak itself was
   pre-existing; the diff made the advice false — adjudicator-split).
3. (MINOR) `.-1` was invisible in the vector-subject message; the wording
   predated live ordinals — label filled at the fail consumers, PVec
   teaching refreshed.
4. (MINOR) in-block `v[0]` silently aliased `.0` — RATIFIED-BY-PIN as the
   Q_R1 "two surfaces, one mechanism" identity extended into blocks;
   head-position `{[0]}` guided to the bare spelling.
5. (MINOR) two stale P3a-era pin titles asserted new error classes through
   loose `#rx"ordinal"` matches — retitled + tightened.

**Interpretation pinned eyes-open**: `{0.name^-}` (ordinal head + collapse
leaf) re-keys to `{:name …}` — the collapse's whole point is producing a
key, so it overrides the head's keyless sort; the three walks agree
(collapse-first classification). The G11 pair landed AS AMENDED (both
halves loud: the digit-target refusal vs the cross-domain refusal — the
one-space flip crosses a loud wall; the recorded rename-to-`:0` reading was
overtaken by the P3b verify's dot-unreachability ruling).

**P3c watch items → P4**: the components model is the broadcast assembly's
natural substrate (a broadcast step's per-element results are components);
the `not-indexable`/`subject-tuple` messages will need `:s` teaching when
broadcast lands; DEFERRED 9's cross-domain hint family now has the
`tuple-or-vector` message as its pattern.

<a id="p4"></a>

### §5.P4 — Broadcast ω  (CO-DESIGN COMPLETE 2026-07-31 — Q_U5–Q_U9 RULED; partition LOCKED P4a–P4e; the PAUSE is CLEARED — implementation opens at P4a)

**The P4 mini-audit** (`wf_8458c23b-312`, 5 facets + completeness critic @
`02dd27d7` — 14th consecutive premise refuted) fed an adversarial options
panel (`wf_82e56156-b28`, 3 clusters × propose/critique/synthesize). Every
load-bearing claim below was re-verified on the MAIN THREAD. ⚠ The LET
track merged mid-walk (`5e16ead4`, +738 lines across macros/parse-reader/
parser/typing-core): `02dd27d7` remains an ancestor and no select surface
was semantically touched (LET REUSES the P1a marker seat), but every audit
coordinate is @ `02dd27d7` — re-pin before use. §3's Q_U5/Q_U6 carry the
rulings; this records what the audit established and the staged shape.

#### What the audit + panel established (probe-verified corrections to the Intent below)

1. **The unnamed predecessor**: the FIRST-CLASS PATHS track
   (`2026-03-20_FIRST_CLASS_PATHS_DESIGN.md`, Phases 0–7c SHIPPED) is the
   prior arc over THIS problem — its §1 problem statement is P4's verbatim.
   Its Phase 7b IS the `expr-broadcast-get` P1a retired; its 7c built `^`
   in path segments before P3b rebuilt it in blocks; its Phase 8 (Lens) =
   spec §7.7 from the other side, chartered once and idle. Its machinery is
   LIVE: `#p(a.b.c) : Path` round-trips; `get-in` works; **`update-in`
   works — the write direction exists**. Q_U5 ABSORBS this carrier.
2. **The precision cliff is real but narrow**: literal paths inline
   (elaborator.rkt:2282 @02dd27d7) and keep precision; a BOUND path
   degrades to `?meta`. Monomorphic source-annotated projection types
   cleanly (probe) — and the deeper grounding is the owner's: rows were
   BUILT row-polymorphic + codata-shaped, with `ρ` STAGED at F-row
   (syntax.rkt:672) — so **P4's surface needs zero row-polymorphism work**;
   only source-UNKNOWN selector reuse waits, on F-row's existing gate.
3. **The Intent's LOWERING clause is contradicted by shipped code**:
   `select-reduce` WALKS and opens ONE `let/ec` (reduction.rkt:1600) — a
   lowered per-element realization would BURY `expr-panic` values in output
   slots (the P2.b fabrication class; four agents converged). Settled by a
   FAIL-FIRST FIXTURE in P4a, not argument. Under WALK the def-seam
   `map-map-vals`/`pvec-map` twin defect (closed-row + het-tuple legs FAIL
   at the def seam with the lying "Multiplicity violation"; Map/PVec legs
   pass — 4-way probe) is NOT a P4 prerequisite; it stays FILED.
4. **The 2b split under-enumerates**: `[PVec {closed row}]` — the case
   nearly every corpus line exercises — has NO stated arm, and `quests` is
   a **List** (cons-spine, corpus :225), a fifth carrier. The split needs a
   stated uniform-row arm + a List disposition + a THIRD dispatcher
   (subject → elem-type + per-carrier functorial lift): `select-row-of`
   sends PVec AND union to one 'subject-other catch-all; `select-ord-of`
   does not exist.
5. **PVec-of-union is NOT blocked** (the Intent and §2.3 assumed it was):
   `def pu : [PVec <Circ | Squa>] := @[…]` types/reduces/indexes at HEAD.
   ONLY projection fails — incl. `u.size` offered by BOTH components at
   Int — because the union arm loops on bare `(whnf (car cs))`
   (typing-core.rkt:2232 @02dd27d7) where the nil-safe-get sibling applies
   `schema-fvar->row-or-self` (:2254). One PER-COMPONENT conversion +
   `row-meet` (still 0 hits) = the leg; the §10.7 discriminating fixture
   IS constructible.
6. **The residue is 16 mentions / 3 files**, incl. the token-TYPE group
   `[(dot-access nil-dot-access broadcast-access)]` (parse-reader.rkt:2161
   @02dd27d7) named by NO enumeration, and `broadcast-access?` STILL live
   in `access-sentinel?` — the retired sentinel still gates fusion.
   Disposal is a NAMED slice item.
7. **The `:` gate is ZERO code** (§Q8.3 design-only). Census @02dd27d7:
   232 adjacent keyword tokens, ALL opener-preceded; ZERO focus-adjacent.
   The fused-binder hazard (`[fn [x:Int] x]` — zero corpus instances,
   A/B-blind) GREW at the LET merge (fused `var:Type` let binders). `.N`
   joins the focus set FREE under a positional rule, by hand under an
   enumerated one. Q_U8's round; recognizer change ⇒ A/B mandatory.
8. **Perf levers the Intent never budgeted**: `whnf-trivial?` holds every
   container TYPE former and ZERO container VALUE carriers (champ/rrb/
   hset; ~96% of per-element cost; no bare head arms outside `nf` = the
   safety proof) · `select-reduce` re-whnf's the subject PER BRANCH
   (reduction.rkt:1754) against its own "evaluated ONCE" comment. Both →
   P4a; the bench must NOT share a commit range with the first
   per-element broadcast (attribution).
9. **The shared walk needs TOTALITY before a sixth step kind**: four
   silent catch-alls (e.g. `[else '()]` syntax.rkt:906). A named
   `select-step-kind` dispatcher over the closed step union, consumed by
   every walk — loud arms, one fixture per catch-all position (the
   Exhaustive Walkers rule applied BEFORE the step kind lands, for once).
10. **DEFERRED 5's citation is dirty-tree-only** (`foray.prologos:674`
    absent at HEAD — 114 lines); the owning slice re-censuses `<`-adjacent
    sites at HEAD.
11. **Lattice notes, now load-bearing**: **Q6** decides whether Ruling-B
    merge is a join-semilattice — i.e. whether a selector can EVER be a
    cell value (the broadcast-propagator track's trigger at §9 row 3 is
    real); schedule Q6 WITH the cell-merge requirement in view (P5 rules
    it; P4's representation must not foreclose it). The 2b keys-⋂ is
    ANTI-MONOTONE in the union component set — CALM-safe only because the
    set is CLOSED at typing time (annotation-only at HEAD; now DECLARED
    rather than assumed). And filter-on-miss (single get) vs
    all-must-offer (broadcast) form a Galois ADJOINT PAIR — the asymmetry
    is structural; never "unify" them.

#### The LOCKED partition (Q_U6 sequencing; Q_U7/Q_U8 folded 2026-07-31)

- **P4a — totality + strategy-independent repairs (no new surface)**: the
  `select-step-kind` totality dispatcher (loud arms; one fixture per
  catch-all position — the arms ARE behavior) · the LOWER-vs-WALK
  fail-first panic fixture · the `select-reduce` subject re-whnf hoist ·
  the `whnf-trivial?` container-VALUE arms · a clean bench vs the P2
  baseline (nothing else in the slice ⇒ attribution-clean).
- **P4b — the ONE selector carrier + wholesale path migration (Q_U5/Q_U6)**:
  unify `expr-path`/`expr-select`; retire the preparse fold's access legs
  into `$select` minting (all four callers head-agnostic, probe-verified);
  the BEHAVIOR-PRESERVATION CHECKLIST is the core work (D19 dyn-row
  permissive metas under the `'path` sort · the P2 miss-hint family ·
  nil-safe variants · `get-in`/`update-in` retargeting **+ the ratified ω
  FENCE, which must land in THIS slice — the carrier absorbs First-Class
  Paths' working write direction, so a later fence leaves the domain
  silently widened between slices** · `#p(…)` re-carrier). Carrier-shape
  detail (new field vs selector-in-branches-slot; the §8 R6
  constructor-arity hazard prefers the latter) = the slice's own mini-round.
  ⚠ **A SECOND live test pin, named by no enumeration** (found at the P4
  re-grounding, `711a9bde` — the 7th under-count of the arc): the
  back-compat alias `rewrite-nil-dot-access` (macros.rkt:5906, ZERO
  production callers) carries a **6-test-case battery at
  `tests/test-nil-type.rkt:126-155` that asserts the fold's EXACT OUTPUT
  DATUM** (`'(nil-safe-get user :name)`, the chained twin, the
  in-larger-form case). Under wholesale `$select` minting **4 of the 6 go
  RED**. Same class as P4c's `broadcast-access` token pin — but it lands
  HERE, in P4b, and must be updated in the migrating commit.
- **P4c — the `:` gate + the ω wrapper + PVec broadcast (first corpus
  green)**: the `$bcast-step` sentinel (nine-site registration, BOTH
  groupers, Q_U8) · parser position-dispatch + the binder-consumer
  unwrapping (census-gated: 4 `fused-type-annot?` sites + LET binders +
  spec/`$brace-params` paths; 3+12+17 live fused-annotation sites must
  stay green E2E) · the `(@bcast step)` wrapper in the step vocabulary
  (its totality-dispatcher arm, key-transparent) · broadcast over PVec
  subjects (uniform elem — the missing "third arm" stated) · the L1
  fusion pin (`users:0:userName` → ONE layer) + the extent pair pin ·
  **the `.*name`→`:name` migration + the FULL residue disposal (16
  mentions incl. `access-sentinel?` membership + parse-reader:2161) in
  the same commit that retires the recognizer** (the parser.rkt:793
  promise) · the corpus A/B with the NAMED diff set. Corpus: §D party
  lines · §10.2 basics/fusion/honest-nesting.
- **P4d — map-generic `:` + the 2b heterogeneity split**: map-generic
  over Map/keyword-row subjects (`regions:host`, §10.5; per-field
  row-map, 4c's no-desugar ban) · het-tuple subjects per-position EXACT
  (`events:t`/`events:x` §10.7 · the `tree` lines §10.8) · PVec-of-union
  (the PER-COMPONENT `schema-fvar->row-or-self` conversion + `row-meet`,
  still 0 hits + the §10.7-style discriminating fixture, now known
  constructible) · **the List REFUSAL (Q_U9 ✅ ruled)** — a guided error
  naming `pvec-from-list`, stating the row type is preserved, and pointing
  at the `Functor`-instance door ~~; the corpus's `quests:t` / `quests:{t r}`
  lines are re-fated HERE (they do NOT uncomment)~~ — **BOTH CLAIMS CORRECTED
  2026-08-07** (see [Q_U9](#q-u9)'s correction block: the lines are LIVE as
  markers 43/44 since P4d-0, and the Functor census was false when written —
  the error drops the "no instance" clause) · dyn-tail
  4d refusals.
- **P4e — flatten `*` · splat `.*` · disclose `<`/`:<` + closures**: the
  keyword-trailing-`*` consumer split (`:diags*` — split-caret-lexeme
  prior art; §10.4 `build.modules:diags*:msg`) · `.*` row-splat in block
  position (§C lines; the splat/duplicate-check interaction below) ·
  disclose (`users:<{0.userName^}` §10.2) + **DEFERRED 5's HEAD
  re-census** of `<`-adjacent sites · the keyword-projection disposition
  (§2.4, due at this close).

#### Pre-implementation pause items — ✅ ALL THREE RULED 2026-07-31 (the owner's hold-point, CLEARED)

Ruling-shaped (owner) — full rationale in §3's P4-PAUSE block:
1. **Q_U9 — ✅ RULED: `:` REFUSES over `List`**, with a guided error naming
   `pvec-from-list` (probe-verified precision-preserving) ~~and the `Functor`
   instance named as the principled door. `quests:t` does NOT uncomment~~
   *(both corrected 2026-08-07 — see [Q_U9](#q-u9)'s correction block)*;
   §F's `[D4.P4]` lines are re-fated at P4d. The motivating counter-argument
   (solve returns List) is resolved UPSTREAM by the `solve-*`/`explain-*`
   → PVec mini-track, spun out separately — seam measured at two lines.
   **Implementation: P4d.**
2. **The update-in ω FENCE — ✅ RATIFIED.** `update-in` accepts grade-1
   selectors only; ω-bearing selectors refuse loudly. Monotone. Guards the
   write direction Q_U5's carrier absorbs from First-Class Paths.
   **Implementation: P4b** (with the `get-in`/`update-in` retargeting) —
   the fence must land in the SAME slice that unifies the carrier, or the
   widened domain is live between slices.
3. **The whole-node abort — ✅ RATIFIED.** A runtime miss inside a broadcast
   aborts the WHOLE selection; no partial results, no buried panics.
   **Pinned at P4a** by the LOWER-vs-WALK fail-first fixture.

Design-round work (per-slice mini-rounds; no owner gate):
4. **The carrier shape** (P4b's round, against code): selector-struct in
   the EXISTING branches slot (same arity; one line in `select-map-exprs`)
   vs a new field vs `expr-selector`+re-pointed `expr-select` — decided
   under the §8 R6 constructor-arity hazard; the slice must END
   single-carrier (`expr-path` retired within P4b, never aliased past it).
5. **The `'path`-sort semantic table** (P4b's round): every landed
   dot-access behavior mapped to its node twin — D19 permissive metas ·
   the P2 miss-hint family (`projection-parts`) · nil-safe `#.name` ·
   `_.field` holes · the `ns foo.bar` ns-dot guard (do not reintroduce
   b0db8f3e) · `reconstitute-selection-paths` (DEFERRED 12 absorbs here).
6. **Splat vs the static duplicate check** (P4e's round): `.*` contributes
   keys UNKNOWN at parse — Q_T3's parser-side check keeps the static
   half; a TYPING-side extension catches splat-vs-explicit collisions
   loudly at select-project assembly.
7. **The `:diags*` splitter grammar** (P4e's round): trailing-`*` split at
   the consumer; multi-`*`/interior-`*` shapes enumerated.
8. **A/B diff-set re-derivation at implementation HEAD** (the LET merge
   moved the tree once already; re-pin before P4c's A/B).

**Intent** — the COMPLETE P4 contract (each item tagged with its ruling):
- `:s` **one-step extent** (spec §3.2.1) · **L1 fusion** — under the step-list
  node (4b) consecutive `:` sharing one spine is a STRUCTURAL FACT of the step
  list, not an elaboration rewrite; the layer count is unfused-ω-steps.
- **map-generic `:`** (Q1 ✅) — keys preserved, values mapped; Specter
  ALL/MAP-VALS collapse into one operator.
- **`*` flatten** — vector layers only in v1 (spec Q4 answer kept).
- **`.*` row-splat** — block position; path position is subsumed by Q1.
- **THE 2b HETEROGENEITY SPLIT** (NOT the spec's single meet rule — see §3):
  · **het tuple** (`⟨row₁ row₂ …⟩`, positions statically known — what `@[…]`
    literals produce, pinned by the `events` fixture): broadcast projects
    **per-position, EXACTLY**; a miss is an error **naming the position**.
    No meet is computed. Strictly stronger than the spec's rule here.
  · **PVec-of-union** (`[PVec <A|B>]`, length unknown — reachable only via
    annotation today): the spec's rule over **union components** — every
    component must offer the key (**keys ⋂**), result field type = **⋃**.
    This is **NEW machinery** (`row-meet` has zero in-tree hits): budget it.
  · ⚠ **POLARITY**: the in-tree union projection arm is filter-on-miss
    (optimistic) and is CORRECT for a single `get` on one union-typed value;
    broadcast projects EVERY element, so **all-must-offer** is the sound
    polarity here. Two operations, two polarities — do not "unify" them.
  · A §10.7-style fixture where components offer the key at DIFFERENT types is
    owed — today's `events` fixture cannot discriminate the two rules.
- **DISCLOSE `<` / `:<`** (Q5 ✅ v1, bare form) — in-step unwrap, so it never
  interacts with broadcast extent. P1 owes its angle-opener probe row.
- **DYN-TAIL = SUPPORT-BOUNDEDNESS** (4d): closed row → per-field ·
  `(Map K V)` → uniform V→V′ · **dyn tail → loud STATIC error** naming the
  remedies (seal / validate / annotate).
- **Row-map typing PER-FIELD** (4c) — broadcast bodies are selector STEPS, not
  arbitrary terms, so per-field precision is cheap; do NOT desugar map-generic
  `:` to `map-map-vals`+lambda (that collapses to constant-W over ⋃ and would
  violate the per-position exactness just ruled). ⚠ Probe the pre-existing
  `def := [map-map-vals …]` → "Multiplicity violation" lying-diagnostic if the
  lowering touches that node.
- **Realized on the STEP-LIST NODE** (4b): typing WALKS the steps; ~~reduction
  LOWERS per step onto shipped machinery (`get`, `pvec-map`, `map-map-vals`)~~
  — ⚠ **CORRECTED 2026-07-31 (P4 audit, 4-agent convergence)**: the landed
  `select-reduce` WALKS under ONE `let/ec`; a per-element LOWERING would
  bury `expr-panic` values in output slots (the P2.b fabrication class).
  Reduction EXTENDS the native walk; the fixture in P4a pins it.
  **`expr-broadcast-get` RETIRES** with `.*name` — it is not repaired.

**Grounded**: the meet rule's error case is the *typing* side of the P2 loud
tier — the runtime side already errors loudly. Result-shape computation =
grades as shape functors (spec §5.2); ω layers = unfused broadcasts.

**Network posture**: v1 stays zero-propagators (the old §7 posture carries;
the Network Reality Check applies to every P4/P5 commit). The broadcast
NODE-level upgrade (one broadcast propagator/one fire/one merge) remains the
future NTT-modeled track.

**Test delta**: corpus §10.2/§10.4/§10.5/§10.7 uncomment. Status: ⬜.

<a id="p4a"></a>

#### §5.P4a — Totality + strategy-independent repairs  (no new surface)

**Mini-audit (2026-07-31, at `cab30b9a`) — the catch-all count was FOUR, it
is EIGHT.** The design (audit finding 9) said "four silent catch-alls (e.g.
`[else '()]` syntax.rkt:906)". Censused, every `cond` arm that dispatches on
STEP KIND and silently absorbs an unknown one:

| # | Site | Silent behaviour before P4a |
|---|---|---|
| 1 | `syntax.rkt:849` `select-step-output-name` | `#f` — contributes no name (⇒ every `^_`/`^-_` synth name computed over such a branch is silently SHORT) |
| 2 | `syntax.rkt:907` `select-branch-top-keys` | `'()` — contributes no component (⇒ the parser's L4 sort check AND its output-key duplicate check simply do not see it) |
| 3 | `typing-core.rkt:776` `walk-to-leaf` | projected as a NOMINAL KEY |
| 4 | `typing-core.rkt:824` `select-branch-entries` | projected as a NOMINAL KEY |
| 5 | `typing-core.rkt:882` `select-below-field` | projected as a NOMINAL KEY |
| 6 | `reduction.rkt:1675` `walk-to-leaf` | `project (champ-of v name)` |
| 7 | `reduction.rkt:1703` `branch-entries` | projected as a NOMINAL KEY |
| 8 | `reduction.rkt:1752` `below-value` | projected as a NOMINAL KEY |

(Two more — `typing-core.rkt:822` and `reduction.rkt:1732` — delegate INTO
#4/#7, so they are covered rather than separate.)

⚠ **AND THAT CENSUS WAS ITSELF INCOMPLETE — it is THIRTEEN sites in FIVE
files** (the adversarial verify; 3 of 4 skeptics found pieces of this
independently). The design said four, I said eight, the answer is thirteen.
**The method was the defect**: I grepped for the exported helper names, then
looked for `cond` arms, in three files. That is SYNTAX-directed, and it
structurally cannot see two whole classes — dispatchers that **open-code** the
shape tests, and dispatchers shaped as `and`/`if` rather than `cond`. The five
it missed:

| # | Site | Why the grep missed it | Severity |
|---|---|---|---|
| 9 | `syntax.rkt` `select-branch-collapse` | `(and (select-key-step? s) …)`, not a `cond` | **runs UPSTREAM of the guards** |
| 10 | `syntax.rkt` `select-branch-keyless?` | same | **runs UPSTREAM of the guards** |
| 11 | `parser.rkt` `dissolve-step?` | a fourth file; parser-local re-implementation of #10 | leaf gate for `^..` |
| 12 | `parser.rkt` `branch-problem` | a fourth file; `select-step-cont`'s `#f` IS the catch-all | positional `^` legality |
| 13 | `pretty-print.rkt` `step->string` | **open-coded** `(and (pair? s) (eq? (car s) '@ord))` — no exported identifier to grep | leaked the raw datum |

**#9 and #10 are the serious ones.** They are LEAF classifiers that run
*before* the guard in all three branch walks (`syntax.rkt:932/939`,
`typing-core.rkt:787/798`, `reduction.rkt:1689/1697`). Answering a silent `#f`
there **defeats** the guards downstream rather than reaching them: the branch
is mis-SORTED (keyed vs keyless) with no raise anywhere, and
`select-branch-top-keys`' `key` arm returns immediately without touching
`rest`, so the wrong key set flows straight into the parser's L4 sort check
and duplicate-output-key check. Traced: branch `[server (@bcast (@key name
dissolve))]` yields `'(server)` where `'(#f)` is correct — silently.

**Owner ruling [2026-07-31]: extend the routing; deliver the totality.** All
thirteen now route through `select-step-kind`. Twelve RAISE on a missed kind;
**#13 renders a loud marker instead**, because `pp-expr` is on the
error-message path (`driver.rkt:291/309/507/798/834` + the typing hints) and a
raise there would convert a real diagnostic into an internal crash — and
`typing-errors.rkt`'s catch-all handler could swallow it, achieving strictly
LESS than a visible marker. It uses `select-step-kind/display`, a NON-raising
variant defined by DELEGATION to the classifier (never a second copy of the
kind list — that is the drift this phase exists to kill). This is a written
scope decision, not an omission.

**The `ADDING A KIND` recipe in `syntax.rkt` was corrected to name all
thirteen sites and all five files** — that comment, not this document, is what
a future implementer actually follows at P4c, and the first version of it
would have left five sites wrong.

Q_U7's `(@bcast step)` is the sixth kind that would have met all thirteen.

**Ruling [owner, 2026-07-31]: route ALL EIGHT through one classifier.**
`select-step-kind` (syntax.rkt, exported) maps a step to
`'key | 'ord-step | 'caret | 'sub | 'ord-branch` and RAISES otherwise; every
consumer ends in `select-step-kind-unhandled`, which raises naming ITSELF.
The kinds are pairwise disjoint by construction, so the classifier is total
and order-independent. `match` cannot help — steps are s-expressions, not
transparent structs, so `pipeline.md` § Exhaustive Walkers' generic-rebuild
answer does not apply and a named classifier is the available structural
form. Two consumer shapes, by arm size: `case` where the bodies are small
(1, 2, 3, 6), a `memq` guard + explicit else where the body is the walk's
largest arm (4, 5, 7, 8). Both route through the classifier. In every case
`sub` joins `key`/`caret` because that is exactly what the old `else` caught
— **the refactor is behaviour-preserving by construction**, and the totality
else fires only for genuinely NEW kinds.

**⚠ SELF-REVIEW CAUGHT A DEFECT I INTRODUCED — the twin-drift class, again.**
The `memq` guard must list EXACTLY the kinds the old `else` caught, or the
"behaviour-preserving by construction" claim above is false. At sites **5**
(`select-below-field`) and **8** (`below-value`) — the two "below a kept head"
walks, which are ATOMIC TWINS — the arms above the else take TERMINAL `sub`
and `ord-step`, so that else ALSO caught **`ord-branch`**. The first cut wrote
`'(key caret sub)` at both, turning a delegation into a RAISE. Sites 4 and 7
were correct (their preceding arms DO take `ord-branch` and `ord-step`), which
is exactly why eyeballing "they all look the same" fails: the four guards do
NOT have the same correct answer. **The suite did not catch this** — the path
is unreachable from surface syntax today (R4: a green suite proves nothing for
this class), which is precisely why it earned a direct-call pin rather than
trust. Both fixed together; the pin was validated by re-introducing the defect
and confirming it fails with `select-below-value: no arm for select step kind
'ord-branch` — the reason its name claims, not a vacuous pass.

**Test delta: +20** (204 → 224), all in `tests/test-path-selection.rkt`.
- **8 totality pins**, one per site. These are DIRECT-CALL unit pins by
  necessity: there is no sixth step kind yet, so the untotal case is
  **unconstructible from surface syntax** and no `process-string` pin can
  reach these arms. Reached via `select-step-output-name` /
  `select-branch-top-keys` (already exported), `tc:select-project`, and
  `select-reduce` (**newly exported for the pins — zero behavioural change**;
  production still enters through the whnf `expr-select` arm).
  ⚠ The pins were written against the CURRENT walks asserting they RAISE,
  NOT against a not-yet-existing `select-step-kind` — a pin calling the
  latter would have failed with "unbound identifier", which is **not the
  reason the pin claims** (this arc's hazard 4, already the source of one
  vacuous pin and two mis-premised fixtures). All 8 went RED as
  `check-exn`/"no exception raised" — the claimed reason — then GREEN.
- **3 whole-node-abort fixtures**, pinning the ratified ruling. Honest
  status: these **characterize existing behaviour** (the ruling was a
  RATIFICATION), so they did not go RED first; their job is to stop P4c
  drifting it. The discriminator is deliberate — TWO branches with the FIRST
  succeeding, so a per-element LOWERING would produce a 2-field record with
  the panic in one slot (the P2.b fabrication class) while WALK produces the
  panic as the whole node.
- **2 twin-regression pins** for the self-review catch above — the "below a
  kept head" walks must still DELEGATE an `ord-branch`, not report no arm.
  The assertion is deliberately NOT "returns value X" but "does not fail the
  TOTALITY way": an `(@ord N)` there may still panic for an honest reason
  (bad subject, OOB); what it must never do is claim the walk has no arm for
  its kind.

**The two repairs, measured SEPARATELY for attribution** (probe:
120×3 multi-branch selections over champ + rrb subjects; `reduce_steps` is
the exact, ambient-immune counter):

| | `reduce_steps` | `reduce_ms` (3 runs) |
|---|---|---|
| A — totality routing only | 7791 | 24 · 24 · 27 |
| B — + subject re-whnf hoist | 7791 | 25 · 26 · 27 |
| C — + `whnf-trivial?` container arms | 7791 | **19 · 19 · 19** |

- **The re-whnf hoist moved NOTHING** (A→B). The audit called it a "perf
  lever the Intent never budgeted"; on a `def`-bound subject the repeat
  `whnf` calls are **cache hits** (confirmed structurally: `reduce_steps` is
  flat, and `perf-inc-reduce!` fires in `whnf-impl`, i.e. only past the
  cache). It is landed as a **contract fix, not a perf win** — the header
  comment had claimed since P3a that the subject is "evaluated ONCE … reused
  across every branch" while `(whnf subj-expr)` sat INSIDE the `append-map`
  lambda. It would matter for an uncached/expensive subject; say so rather
  than bank an unearned number.
- **The `whnf-trivial?` container arms moved all of it** (B→C) — but ⚠ **the
  reasoning I first gave for this was INVALID, and the wall method was too**
  (both caught at the P4a adversarial verify):
  - **The `reduce_steps` control is CIRCULAR for the B→C leg.**
    `perf-inc-reduce!` fires at `reduction.rkt:2054`, **before** the
    `whnf-trivial?` branch at `:2062`, so `reduce_steps` *cannot move* when
    container arms are added. Its flatness is true by construction and carries
    ZERO evidential weight for C. (It legitimately supports A→B, where a
    removed uncached `whnf` would have shown.) A tautology dressed as a
    control is exactly the "claim is true at a layer nobody named" family.
  - **n=3 sequential is not an A/B**, per our own `testing.md`. Measured
    run-to-run spread on an UNCHANGED tree: `reduce_ms` 13·14·14·14·15·16·16·16
    (~20% peak-to-peak), so a ~6 ms delta sits ~1.2× the noise band. The
    "variance collapsed to 19·19·19" is also partly integer-ms quantization
    (`performance-counters.rkt` rounds).
  - **What actually carries the claim** is an interleaved per-call microbench
    the verify constructed: `expr-tchamp`/`expr-trrb`/`expr-thset` are
    structurally identical transients that are NOT whnf-trivial and have no
    match arm, giving a true control. 200k iters × 5 rounds: **211 ns
    (fast path) vs 2019 ns (full match) = 1822 ns/call, 9.5×**. Predicate-
    position probing (98 ns at position 1 vs 200 ns at position 46 ⇒
    2.25 ns/predicate) also refutes the "this is the CS interpreter"
    confound — the 1.8 µs is genuine compiled cost of a ~265-way linear
    struct-predicate chain.
  - **Honest magnitude**: `reduce_ms` is ~0.3% of end-to-end wall
    (`gc_ms` alone is 3× it), so "−25%" is ≈ **−0.1% of wall**. Real,
    mechanically explained, and small. `reduce_ms` is also the wrong slice in
    both directions — `time-phase! reduce` wraps only four driver sites, so
    every `whnf` inside type-check/qtt/elaborate lands in other buckets.
- **Safety proof re-verified at `cab30b9a`** (re-verify if the match moves):
  `whnf-impl/match` has **no bare-head arm** for `expr-champ`/`expr-rrb`/
  `expr-hset` — every such pattern sits at nested indent, matching an
  already-whnf'd ARGUMENT of a map/set/vector operation, never `e`. They
  therefore fell to `[_ e]` (`reduction.rkt:3957`) — identity — so the fast
  path returns exactly what the match returned.
- **This IS the P2-baseline establishment.** §5.P4/§5.X say "priced against
  the P2 baseline"; **no such baseline was ever recorded** (neither P2's nor
  P3's close notes carry one, and there is no selection baseline in
  `data/benchmarks/`). Table A above is that baseline, recorded so X.close's
  bench matrix is executable.

**Carried forward from P2's close notes**: the `xs.0:name` focus-set
obligation — Q_U8's *positional* rule discharges it BY CONSTRUCTION (`.N`
joins the focus set free), confirm when P4c lands.
⚠ **The second item I listed here was FALSE** (caught at the P4a verify): I
wrote that "commit the corpus A/B harness" was still uncommitted. It is
committed — `racket/prologos/tools/reader-corpus-ab.rkt`, landed at
`3005170b` (the P2 commit), and **§5.P2's own close notes record it as
delivered**. I asserted an open obligation that this document already
recorded as closed, four hundred lines above. Verified by
`git log --diff-filter=A -- racket/prologos/tools/reader-corpus-ab.rkt`.

**Test-quality repairs from the verify** (the pins were weaker than claimed):
the 8 totality pins used `check-exn exn:fail?` — demonstrated to pass on an
ARITY error or a malformed fixture, so a future change to `make-record`/
`champ-insert` could have turned all eight green with the arms fully reverted.
Narrowed to a `totality-exn?` predicate matching the actual message, and the
fixtures HOISTED out of the guarded lambdas (a fixture that throws must fail
the test, not satisfy it). Whole-node fixture 2 was a message pin sold as a
discriminator — `expr-champ` is `#:transparent`, so a buried panic prints both
`nope` and `invariant violation` too; the `expr-panic?` assertion (the half
that actually discriminates) was added to it. And `select-step-kind-unhandled`
had **zero coverage** — all 8 pins raise from the CLASSIFIER, never from a
consumer's else — so the mechanism the design advertises now has a direct pin.

**Known limit, stated rather than papered over**: the whole-node fixtures
discriminate at BRANCH granularity inside one `select-reduce` call. If P4c
implements ω by mapping a sub-walk over N elements, each element gets its own
`let/ec` and burial is reintroduced with all three fixtures still green. The
element-level guarantee cannot be pinned until a broadcast step exists — P4c
owes that fixture.

Status: ✅ (see the Progress Tracker).

<a id="p4b"></a>

#### §5.P4b — The ONE selector carrier + wholesale path migration  (mini-audit folded 2026-07-31)

**The mini-audit** (`wf_1cb9d606-89c`, 5 HEAD-pinned read-only facets +
adversarial completeness critic @ `2cef148b`, 6 agents / 1.17M tokens).
**FOUR of the seven design claims did not survive**, and the critic found a
BLOCKING objection no facet connected. Every load-bearing finding below was
R-lens-verified on the main thread before folding.

**Design-claim verdicts:**

| Claim | Verdict |
|---|---|
| C1 — all four fold callers head-agnostic, `$select`/`map-get` fold identically | **REFUTED.** Head-agnostic AT THE FOLD (callers re-pinned: macros.rkt:1962, :2611, :6113, :6499), but one step downstream `preparse-expand-form` carries a DEDICATED `$select` partial-opacity arm (macros.rkt:2013-2019) that `map-get` never touches — `map-get` falls to the generic list arm and gets FULL subform recursion. Two of the four callers re-enter `preparse-expand-form` directly, so they do NOT fold identically end-to-end. Rider: a loud→silent slide — `map-get`'s parser arm has an arity ceiling of 2 (parser.rkt:2663), `$select`'s has NO count check (parser.rkt:1195-1209), so a zero-hole pipe step that errors loudly today becomes an extra BRANCH silently. |
| C2 — ZERO new typing work | **REFUTED** → withdrawn by Q_U10. Three divergent subject postures, and the walks are DELIBERATELY non-delegating (typing-core.rkt:637-639 says so in a comment). |
| C3 — one line in `select-map-exprs` | **UNDERCOUNTS BY ONE WALKER, and it fails SILENTLY.** The 6-walker funnel is real (syntax.rkt:780-782; shift/subst/zonk×3/nf all route through it), but `uses-bvar0?` (pretty-print.rkt:1042, select arm :1226) is a SEVENTH hand-armed walker OUTSIDE it: `[(expr-select subject _)` with a comment asserting "subject is the only expr slot". Correct today; the moment branches hold an expr it under-reports bvar0 usage with no error — the `pipeline.md` § Exhaustive Walkers signature exactly. Cleared as safe by construction: `occurs?` (unify.rkt:240) and `expr-subfields` (typing-errors.rkt:73-87) are generic `struct->vector` walks; `conv-nf` falls to `equal?`; `narrowing.rkt` has ZERO references. |
| C4 — no PNET_VERSION bump | **CONCLUSION CONFIRMED, REASONING REFUTED.** §8 R6's symbol-keyed/additive argument covers struct ADDITION only; P4b does an ARITY CHANGE and a TAG REMOVAL. On arity mismatch `(apply ctor fields)` raises — but driver.rkt:2892 wraps deserialization in `(with-handlers ([exn? …]) …)`, so it is SWALLOWED into silent re-elaboration. On tag REMOVAL the reader's `[else v]` (pnet-serialize.rkt:589-599) returns a RAW VECTOR with **no exception at all**, so the handler never fires and the impostor lands in the module env (the `pipeline.md` § New AST Node item-6 failure). What actually makes "no bump" true is `infrastructure-stale?` (pnet-serialize.rkt:664-671): any syntax.rkt edit rebuilds `driver_rkt.zo`, whose mtime then invalidates every `.pnet`. **Corollary — the registration ROUTE must FLIP**: `expr-select` uses `regN!` (loud on arity drift); `expr-path`/`expr-Path` use `auto-cache!` (:542), whose body SWALLOWS exceptions so a stale-arity call voids the registration silently. P4b must DELETE that line, not repoint it — the rationale is already written in-tree for the identical `expr-map-get` case (pnet-serialize.rkt:336-341). |
| C5 — Q_T2 asymmetry live | **CONFIRMED, and WIDER: it is THREE-WAY.** dyn pair (typing-core.rkt:564-567 vs :677-678) + Map pair (:2205-2213 vs :663) — and the Map pair runs the OPPOSITE direction on the hit case. |
| C6 — the ω fence | **CONFIRMED but UNDERSTATED: the fence is a REPAIR of a LIVE defect, not only a forward guard.** Multi-branch truncation is ALREADY a silent wrong answer at five `(car (expr-path-branches …))` sites (reduction.rkt:3431/:3446/:4445/:4454) plus the elaborator's static inline (:2285/:2363), and BOTH existing static guards (elaborator.rkt:2346-2347, :2349-2351) are structurally BYPASSED by the expression/dynamic route. |
| C7 — vacuous ground `Path` | **CONFIRMED** (typing-core.rkt:2050-2051 discards branches with `_`; unify.rkt:799 is unconditional `ok`). Refinement: `#p()` empty is a DIFFERENT failure class (reader-layer `Unbound variable`), so "vacuous" does not predict it. |

**⭐ THE REAL CARRIER-SHAPE DECISION IS THE SEGMENT ENCODING MISMATCH — and
none of the three candidate shapes named it.** `expr-path` branches hold
`expr-keyword`/`expr-symbol` **structs** (minted at elaborator.rkt:2257-2266);
`expr-select` branches hold bare **symbols** plus `(@key name cont)` /
`(@sub . branches)` / `(@ord N)` **s-expressions** (syntax.rkt:786-800,
classified at :860-873). The shapes were framed as ARITY questions (new field
vs branches-slot vs new struct); the actual cost is an **encoding convergence
plus a rewrite of every step consumer**, which is invisible from any
constructor-count analysis. Settle the encoding BEFORE trusting any edit-site
list. Facet 1's recommendation (shape **a′**: repurpose `expr-path` INTO the
carrier and place it in `expr-select`'s existing `branches` slot, preserving
`expr-select` arity 2 and inheriting the eight pipeline arms `expr-path`
already carries) survives only if the encoding question is answered first.
Note also facet 1's structural point: a bare `#p(a.b)` is a STANDALONE VALUE
in expression position (`def p1 := #p(name)` is live), so the unified carrier
MUST be an `expr?` with its own arms — shape (a) as literally written cannot
carry `#p(…)`, and (a)/(c) are therefore not two sizes of the same thing.

**Scope facts the design under-counted:**

- **The RED set is 25 tests across SEVEN files**, not the "4 of 6 in one file"
  §5.P4 names: test-postfix-index-02 (10) · test-implicit-map-01 (4) ·
  test-dot-access-01 (3) · test-nil-type (**3, not 4** — the other three are
  `$retired-selection` markers and a no-sentinel passthrough, all
  migration-invariant) · test-mixfix-01 (2) · test-path-selection:1501 (1) ·
  **test-dot-access-02 (2, failing by TYPE ERROR not datum shape — the file
  both fold-census facets missed).**
- **`expr-path` has a LIVE FFI SURFACE** that Q_U5's carrier round did not
  mention: `path-ops.rkt:33-121` (6 shims, each `expr-path?`-guarded) bound by
  `lib/prologos/core/path.prologos:12-17`, plus `unify.rkt:799`,
  `foreign.rkt:362` (`[(expr-Path) 'Path]` marshalling tag) and
  `union-types.rkt:102` (ordering key). Retiring `expr-path` re-points a
  FOREIGN MODULE, not just Racket call sites. `path-branch-count`
  (path-ops.rkt:83-88) is already a grade predicate in primitive form.
- **The ω fence is VACUOUS inside its own slice** unless written as a total
  `case` over `select-step-kind` terminating in `select-step-kind-unhandled`
  — the step vocabulary is a CLOSED union with **no ω member** until P4c mints
  `(@bcast step)`. Write it as the total dispatch (P4a's mechanism), so it
  becomes live the moment the kind lands.
- **`_.field` sections silently retire, unpinned.** `map-get` and `map-assoc`
  ARE in `sectionable-op-keywords` (parser.rkt:703-730); `get`,
  `nil-safe-get` and `$select` are NOT. So `_.field` currently desugars to a
  hole-domain lambda and would stop. `_[k]` IS pinned
  (tests/test-path-selection.rkt:598-599); `_.field` has **no test anywhere**.
- **`whnf-trivial?` holds `expr-Path?` (the TYPE) but not `expr-path?` (the
  VALUE)** — reduction.rkt:2010-2065. A literal is a canonical form with no
  head rule, so by the predicate's own criterion it belongs there; its absence
  means every `#p(…)` reaching whnf pays the full ~990-arm match. A live
  `pipeline.md` core-item-4 gap one line from a P4a deliverable. **P4b
  DECISION**: a reducible carrier must stay OUT, a literal carrier must go IN.
- **The `expr?` predicate gap is ASYMMETRIC and still open**: `expr-select?`
  is registered (syntax.rkt:1620); `expr-path?`, `expr-Path?`, `expr-get-in?`,
  `expr-update-in?` are NOT. §5.P1a item 8 deferred this to "P2's mini-audit"
  and it did not close. P4b closes it by construction or carries it forward.
- **A SIXTH hand-maintained sentinel enumeration**: `tools/form-deps.rkt:42`'s
  `syntax-keywords` (carries `$dot-access`/`$dot-key`/`$retired-selection`,
  not `$select`) — it EXCLUDES syntax keywords from the stdlib dependency
  graph, so an unlisted head is silently counted as a reference to an
  undefined name. Joins `pattern-var?`, `access-sentinel?`, namespace.rkt:896,
  `sectionable-op-keywords`, and `tools/reader-corpus-ab.rkt:76-80`. Note the
  RETIREMENT direction is a different surface from §Q8.5's nine MINTING sites.

**⚠ Three doc-truth defects in THIS document, found by the audit:**
1. §5.P2 audit finding 6 says `rewrite-dot-access` has **THREE** production
   callers at macros.rkt:1957/:2527/:6236; §5.P4's P4b bullet says **four**.
   The code says FOUR and **none of the three cited coordinates lands**.
2. §5.P4b's "4 of the 6 go RED" at test-nil-type is **3 of 6**.
3. §8 R6's no-bump reasoning is right by accident (see C4).

Status: ⬜ — scope re-derived; the encoding decision and the slice split are
the open items.

<a id="p4b-i"></a>

##### §5.P4b-i — Encoding convergence + the carrier repurpose

**Slice 1 — Q_U11 retirement** (`f072c115`): see §3 Q_U11.

**Slice 2 — the encoding convergence** (this slice). `expr-path`'s branches
now hold **bare symbols** — the same step vocabulary `expr-select`'s branches
use (syntax.rkt:786+). `#p(a.b)` and `x{a.b}` therefore carry ONE
representation of the selector, which is the substantive half of Q_U5.

Six consumer sites re-pointed, all of which had used a segment DIRECTLY as an
`expr-map-get` key: the `get-in`/`update-in` whnf arms + their `nf` twins
(reduction.rkt), and the two elaborator static inlines. Plus the
pretty-printer, whose `expr-keyword?`/`expr-symbol?`/`[else "?"]` cond
collapsed to a single symbol render (its `[else "?"]` was another silent
catch-all of the P4a family).

**The FFI became the MARSHALLING BOUNDARY**, which is where marshalling
belongs: `path-head` marshals a symbol OUT to a Prologos keyword value;
`path-from-segments` marshals keywords IN and **refuses** a non-keyword rather
than coercing it — coercing an unrecognized segment into a key is precisely
what made `#p(a.*)` fabricate `<error>` values (Q_U11).

**`whnf-trivial?` gained the selector carrier** — a DECISION, not an
inheritance (the audit named it as one). Verified: `whnf-impl/match` has NO
`expr-path` arm at any indent, so it already fell to `[_ e]` (identity), and
`nf`'s arm is `[(expr-path _) e]`. A literal with no head rule is exactly this
predicate's criterion. `expr-select` — the APPLICATION — is reducible
(whnf arm reduction.rkt:2967-2982) and stays OUT. Same
type-former-without-its-value-carrier gap P4a closed for champ/rrb/hset, one
line away and missed by that census too.

**Method**: this is a behaviour-preserving refactor, so the pins were written
BEFORE the change and had to stay GREEN — the pins ARE the claim. Six FFI/E2E
characterization pins (`head` · `tail` · `depth` · `branch-count` · `leaf?` ·
`get-in`/`update-in`) plus the whnf identity pin. Test delta **+7** (229 → 236).

⚠ **FILED, PRE-EXISTING, not caused by this slice** (characterized at
`f072c115` while writing the pins): `p::segments` **whole-file ABORTS** —
`path-segments` builds a Prologos cons-chain while the foreign marshaller
expects a RACKET list, so the declared `Path -> [List Keyword]` never
marshalled. `from-segments` and the `path-append` combinator built on it are
dead with it. 5 of 6 primitives work. Deliberately NOT pinned (a whole-file
abort would take the test file with it).

⚠ **b-i DOES NOT YET END SINGLE-CARRIER.** The remaining structural step is
nesting `expr-path` INTO `expr-select`'s `branches` slot so there is literally
one selector struct. Held back deliberately: that slot change makes the slot
hold an **expr**, which activates the audit's C3 finding (`uses-bvar0?`,
pretty-print.rkt:1226, recurses into the SUBJECT ONLY) and requires
`select-map-exprs` to map into the selector. Walker-shaped work, owed its own
failing-test-first pass. **This slice is "one encoding", NOT "one carrier"** —
stated so the phase headline does not outrun what shipped (the
Validated≠Deployed shape).

**Process note**: the targeted runner's 30 s default now aborts this file (the
FFI pins add `process-file` cycles) — `raco test` reported 235 passing while
the runner said `ABORTED — 0 timeouts`. Use `--timeout 180`; an abort here is
not a failure.

**Slice 3 — the SLOT NESTING (b-i now ENDS single-carrier).**
`expr-select`'s `branches` slot holds an **`expr-path`** — the reified
selector — rather than a raw list. After this there is exactly ONE way to hold
a selector, which is Q_U5's "three spellings, one representation" made
structural: `#p(…)` is a bare carrier, `x{…}` is a carrier applied to a
subject, and path position mints the same carrier.

Sites: 1 mapper (`select-map-exprs`, now mapping BOTH slots) · 4 positional
matches unwrapping (`pretty-print` · `typing-errors` · `reduction` ·
`typing-core`) · 2 constructors wrapping (elaborator, and reduction's
re-construction) · 5 test constructions. `qtt.rkt`'s match binds `_` and
needed no change.

**The audit's C3 finding, resolved rather than inherited.** C3 said
`uses-bvar0?` (pretty-print) recurses into the SUBJECT ONLY, under a comment
asserting "subject is the only expr slot" — a silent under-report the moment
the slot holds an expr. This slice is that moment. Two facts make it
tractable: (i) all six `expr-path` walker arms are `[(expr-path _) e]` — pure
identity — so mapping into the slot is a no-op; (ii) at P4 the monomorphic
ruling means a selector holds bare SYMBOLS, never exprs, so the walker could
not have under-reported anything yet. **So C3 is real as a class and INERT at
P4** — it goes genuinely live when BOUND selectors land (F-row). The walker is
corrected here anyway, because "inert today" is exactly how the silent-walker
class starts. `uses-bvar0?` is exported for the pin (a bvar inside a selector
is unconstructible from surface syntax, so the pin must call it directly —
same rationale as P4a's `select-reduce` export; zero behavioural change).

**Test delta +4** (236 → 240): the slot holds the carrier · the mapper
preserves it · `uses-bvar0?` recurses · the surface is unchanged E2E.

**On the NAME**: the design says "`expr-path` retired within P4b, never
aliased past it", which facet 1 read as a rename into the unified carrier.
The struct IS now the one selector carrier; only its NAME is legacy. That is
not an alias and not a dual path — there is one struct — but the rename is
deliberately NOT done here: it is ~30 arms of pure churn (substitution ×2,
zonk ×3, nf, pp ×2, typing-core, qtt, pnet, path-ops ×7, reduction ×8,
elaborator ×2, unify, foreign, union-types) with no semantic content, and
bundling it into a behaviour-preserving slice would make the diff unreviewable
for zero benefit. Named as cosmetic follow-up rather than left implicit.

Status: ✅ b-i COMPLETE (Q_U11 retirement ✅ · encoding ✅ · single-carrier ✅;
the carrier's NAME is a named cosmetic follow-up).

<a id="p4b-ii"></a>

#### §5.P4b-ii — The `$dot-access` fold migration (mini-audit folded 2026-07-31)

**Mini-audit** `wf_f8568392-b44` (5 HEAD-pinned facets + completeness critic
@ `2e3fc14e`, 6 agents / 1.22M tokens). Re-pinned from scratch because the
SolveCarrier merge invalidated every P4b coordinate. Load-bearing findings
R-lens-verified on the main thread.

**⭐ THE SORT AXIS IS THREE-VALUED** — see Q_U12. This is what forced the
scoping ruling; the design's "2-D (subject kind × sort)" table was itself an
under-specification.

**⭐ ASYMMETRY #3 (NEW) — SELECTION-TYPED SUBJECTS.** `.f` projects THROUGH
the view and is READ-CAPABILITY-GATED (an out-of-view field errors); `{f}`
refuses via the catch-all `'subject-other`, whose message **LIES** ("the
subject is not a record") and names no remedy. The refusal is deliberate
(DEFERRED 20); the diagnostic does not say so. Joins the dyn-row asymmetry
(Q_T2) and the Map asymmetry (Q_U10) — **three**, and the table must be
indexed by (subject kind × sort) with all three.

**⭐ `_.field` SECTIONS WORK — and wholesale minting deletes them, untested.**
Probe-verified at HEAD: `[_.a {:a 7}]` → `7 : Int`; `map _.a recs` →
`@[1 2] : [PVec Int]`; `map _{a} recs` → ERROR. Mechanism: `map-get` ∈
`sectionable-op-keywords` (parser.rkt:755) + the gate (:1355-1360), which
`$select` **cannot reach** because its arm is dispatched EARLIER in the same
cond (:1238). ⚠ **This document previously implied `_[k]` is a working
symmetric case — it is not**: `_[k]` is pinned as a guided REFUSAL
(tests/test-path-selection.rkt:598-600), because the postfix leg has a `_`
guard (macros.rkt:6039-6040) that the DOT leg deliberately lacks. The
asymmetry is intentional; the deletion would not be. **b-ii-3 owns the
rescue**; `_.field` has NO test anywhere.

**⭐ THE RED CENSUS IS STRUCTURALLY WRONG, not merely undercounted.** "25
across 7 files" is a **datum-shape** census, and the failure mode that
matters — a VALUE assertion going red by TYPE ERROR — is invisible to it.
Missing entirely:
- `tests/test-first-class-paths.rkt:88-130` — WS-mode, value-asserting
  dot-access, in the ONE file testing `#p(…)`/`get-in`/`update-in`, i.e. the
  surfaces Q_U5/Q_U6 absorb. **Highest-coupling RED file in the tree; named by
  no facet and no design census.**
- `tests/test-selection-paths.rkt` (~8 cases) — the corpus for
  `reconstitute-selection-paths`, a **SIXTH** `$dot-access` consumer.
- `tests/test-route-soundness-01.rkt:152-157` and
  `tests/test-implicit-map-02.rkt:155-162` — more Map-posture pins.
- `tests/test-dot-access-02.rkt` has **FIVE** Map value-assertions
  (:112, :121, :145, :153, :170), not the two this doc cited.
- **A FIFTH fold entry point**: the `rewrite-nil-dot-access` alias
  (macros.rkt:6086) has zero production callers but THREE direct test callers
  — on the edit surface while absent from every "four callers" framing.

**THE FOUR CALLERS ARE NOT UNIFORM** — per-caller obligations differ, and
`preparse-expand-subforms` (macros.rkt:2665) is the dangerous one: the
`$select` arm is PARTIALLY OPAQUE and skips sibling-level passes that
`map-get` gets through the generic arm, so a naive mint makes every `.field`
in the tree lose infix / implicit-map / sibling-let processing. The migration
must either route the minted head through the generic arm or widen the
`$select` arm — decided per caller, not once.

**THE MAP POSTURE APPLIES AT EVERY DESCENT LEVEL**, not just the leaf —
`outer.inner.a` through an intermediate Map is a pinned surface. Sort is a
property of the whole carrier, so threading it down suffices, but ALL THREE
per-level dispatches (`walk-to-leaf`, `select-branch-entries`,
`select-below-field`) must take the Map arm. Prior art for the shape:
`select-below-field`'s ordinal-STEP arm ("descend, contribute NO output
level", Q_U2 Reading A) generalized to keyed steps — reusing it keeps the
reduction twin together, which is where P4a's self-review already caught an
omission.

**⚠ DOC-TRUTH DEFECTS IN THIS DOCUMENT** (found by the critic):
1. **Four places disagree** on which phase owns `quests:t`/`quests:{t r}` —
   the P4c bullet claims them, the P4d bullet says they are re-fated to P4d,
   the SolveCarrier back-note says P4d, the pause summary repeats P4d.
   **RESOLVED by solve→PVec: they are P4c PVec broadcasts.**
2. **Consequence undrawn**: with solve→PVec landed, **P4d's List refusal has
   NO corpus instance** and needs a purpose-built fixture.
3. The corpus cite `:235` is stale by 3 (the lines are :232/:233).

**ADJACENT, NOT IN b-ii's BLAST RADIUS but the natural place to close it**:
the `ns` silent-segment-drop guard has **THREE UNCLOSED NEW INSTANCES** —
probe-verified, `ns foo{bar}` and `ns foo#.bar` both accept at 0 errors and
silently drop the segment, while `ns foo.bar` correctly aborts. The guard
(namespace.rkt:895-896) enumerates **2 of the 8** sentinels in
`access-sentinel?`. Exactly the bug class `b0db8f3e` fixed and the P2 audit
re-closed for `.N`; P1b/P3 minted new family members and nobody extended it.

<a id="p4b-ii-1"></a>

##### §5.P4b-ii-1 — The (subject kind × sort) semantic table  ✅

**Scope, as ruled mid-slice [owner]**: cover **ALL** asymmetries, not just
Q_U10's Map posture, **including the diagnostics**. Typing-side only — no fold
change, so the RED set stays green and the posture is pinned cell-by-cell
before anything migrates.

**The sort is a FIELD on the carrier** [owner]: `expr-path (branches sort)`,
`'path | 'block`. Rejected: a distinguished step kind (the sort is a property
of the whole carrier, not of any step) and a second struct (reopens
"ends single-carrier" one slice after b-i closed it). It cannot be DERIVED:
today a bare carrier is `#p(…)` and a nested one is a block, but after b-ii-2
`x.a` and `x{a}` are the same node shape. **`auto-cache!` DELETED in the same
slice** (ruling C4) — its body swallows exceptions, so this arity change would
have voided the registration silently; now `regN!`/`reg0!`, which error loudly.

**The Map posture takes option (b)** [owner] — a `select-uniform` marker.
Rejected: **(a)** synthesize a closed row from the requested labels (fabricates
a support the subject lacks, and it would flow into result-shape computation as
if the key set were known — this track's failure history is fabrications that
type-check); **(c)** fold Map into the dyn-row machinery (merges two postures
Q_T2 and Q_U10 separated, whose RUNTIME behaviours differ — Map miss = loud
panic, dyn miss = D19-permissive meta; the merge would be invisible later
precisely because it reads as a simplification).

**The table, as shipped** (all four asymmetries + the cells that deliberately
AGREE):

| subject | `'path` | `'block` |
|---|---|---|
| keyword record, present | field type | field type |
| **Map** (Q_U10) | `select-uniform` at V, **key type checked** | `'subject-map` |
| **dyn row**, presence `'unknown` (Q_T2) | fresh meta (D19/D24) | `'unknown-presence` |
| **dyn row**, unlisted | fresh meta | `'miss-dyn` |
| **selection view** (NEW #3) | `select-view`, capability-gated | `'subject-selection` |
| **union** (NEW #4) | `select-union`, per-component ⋃ | `'subject-other` |
| closed row, missing | `'miss-closed` | `'miss-closed` — **agree** |
| nat/ordinal | unreachable at b-ii by Q_U12 scoping | ordinal dispatch |

**Both diagnostics repaired.** The block-over-view message was reaching
`'subject-other`, whose text ("the subject is not a record") is FALSE of a
selection — it IS a record, restricted — and named no remedy; it now names the
view, explains the `:requires` bypass, and gives two remedies. **This half is
LIVE at HEAD.** The out-of-view message (`selection-not-in-view`) is written
and pinned but only reaches users at b-ii-2, since `.field` still routes
through `expr-map-get`.

**Self-review caught the sort axis was a SILENT CATCH-ALL** — `(if (eq? sort
'path) … …)` gave any other value block semantics, P4a's exact class on a fresh
axis one slice later, and load-bearing because Q_U12 already NAMES the next two
sorts (`#.field`, `[k]`). Now `select-sorts` + `select-sort-unhandled`
mirroring the step-kind machinery. Pin validated by re-introducing the defect.

#### ⚠ THE ADVERSARIAL VERIFY — 4 skeptics, and it earned its keep

Three defects in what shipped, plus three unpinned claims. **All re-verified by
main-thread probe before acting.**

1. **A LIVE CAPABILITY BYPASS.** The selection arm was placed BELOW the schema
   arm; the reference (`expr-map-get`) orders them the other way. Both
   registries accept the same name, so `schema Person` + `selection Person from
   Person` is constructible — and `u{age}` returned **`{:age 9}` at 0 errors**
   for an out-of-view field. The `'block` half was PRE-EXISTING (there was no
   selection arm at all); what this slice did was add the arm and put it where
   a colliding name could never reach it, and ship a test asserting "a block
   over a view still refuses" that was FALSE for that case. Read-capability
   cell — the bar is higher. Fixed; order is now reference-matched and
   commented as load-bearing.
2. **The Map arm dropped the KEY-TYPE check.** The reference is
   `(if (check ctx k kt) vt (expr-error))` — TWO obligations; only the miss
   half was implemented. Probe: `mi : (Map Int String)` / `mi.a` REFUSES at
   HEAD, and the first cut would have admitted it, degrading to a runtime panic
   at b-ii-2. `select-uniform` now carries the key type.
3. **MY FIXTURE WAS MALFORMED.** `requires-paths` is a list of PATHS;
   `TBL-VIEW` passed a flat `'(#:name)`, so `selection-allows-field?` returned
   `#f` for EVERY label — both selection pins passed because the gate refused
   everything, and `selection-field-type` (the ADMIT half of asymmetry #3) had
   ZERO coverage. The fixture-makes-the-pin-vacuous class, on the slice that
   had just quoted it.
4. **The sort threading was unexercised.** All `'path` pins entered at the
   LEAVES, so replacing `sort` with the literal `'block` at any of ~15
   recursive call sites still passed 260 tests. Now pinned at the top and at
   depth, as a NEGATIVE assertion (it rules no assembled shape).
5. **`whnf`'s sort-preserving reconstruction was unpinned** — the production
   comment warned about exactly the silent re-sort; the warning was written,
   the pin was not.
6. **The sort-totality pin's NAME overstated the mechanism.** The guard fires
   at the DISPATCH POINTS, not across the walk: a non-divergent cell still
   answers under an unknown sort. Reworded, and widened from one divergent cell
   to three. The fourth (selection) is documented as unreachable by direct
   call — registries live only for the duration of `process-file`.

**Then THREE more folded in on the owner's ruling** (all unreachable today, all
detonating at b-ii-2 — taking them keeps b-ii-1 the safe typing-side slice):

7. **ASYMMETRY #4 — UNION subjects**, which the mini-audit's enumeration of
   "three" missed entirely. Probe: `u : <(Map Keyword Int) | (Map Keyword
   String)>` gives `u.a` → `1 : Int | String` at 0 errors, `u{a}` refuses.
   `select-row-of` had NO union arm. Wholesale minting would have silently
   deleted a working surface — Q_U10's own failure mode, one subject kind over.
   ⚠ The arm is the OPTIMISTIC filter-on-miss polarity (correct for a single
   get); broadcast is the all-must-offer adjoint and must NOT reuse it (§3's 2b
   ruling: never "unify" them). Commented at the arm.
8. **`select-index-of` — the file's own comment calls it "the nat twin of
   `select-row-of`" — never got the sort axis**, so the ordinal column of a
   2-D table silently carried block semantics and could never raise the guard.
   The twin-drift class P4a's self-review caught, one dispatcher over. Now
   total; the two sorts AGREE there by Q_U12 scoping (`.N` reuses
   `$postfix-index`), which is recorded at the arm so it is not mistaken for
   luck.
9. **`pretty-print.rkt` hard-coded the BLOCK spelling** and discarded the sort,
   so after b-ii-2 every `x.a` would render as `x{a}` in error messages and
   `def` echoes — silent wrong output on the DIAGNOSTIC path. **Third
   consecutive slice whose census missed a `pretty-print.rkt` site.** Renders
   by sort now, and degrades to a visible marker rather than raising (the P4a
   site-13 ruling: a raise on the error path converts a diagnostic into a
   crash).

**Owed to b-ii-2, found here, NOT owed by this slice**:
- **The carrier has no STRICTNESS slot.** `expr-map-get`'s third field
  materializes P2.b slice 4's two-tier decision into reduction: `(expr-true)`
  → loud panic naming the key + available keys; anything else (unsolved meta,
  **dyn-row subjects**) → permissive `(expr-error)`. `select-reduce` panics
  unconditionally. So at b-ii-2 a Map miss gets the WRONG message and **a
  dyn-row miss PANICS where today it is permissive** — a real regression the
  D19 pins would catch. Reduction cannot consult types, which is why the slot
  exists; b-ii-2 must materialize the tier onto the carrier. This is a
  CARRIER-SHAPE question re-opened one slice after b-i settled it.
- `select-reduce`'s header asserts a runtime miss is an "INVARIANT VIOLATION
  (typing sourced every field 'present)". Under the Map/dyn postures typing
  sources nothing, so the sentence becomes FALSE at b-ii-2 — contract-truth
  fix owed in the migrating commit, same class as P4a's "evaluated ONCE".
- `select-project` has **TWO** production callers, not the one this slice's
  comment claimed: the `expr-select` infer arm AND `typing-errors`'
  `select-block-hint`. Harmless today (both pass `'block`), but at b-ii-2 the
  DIAGNOSTIC re-walk runs the `'path` column, and `selection-field-type` has
  SIDE EFFECTS (`register-selection!` + `global-env-add-type-only`) — formatting
  an error message would mutate the selection registry.
- `select-sort?` is dead code (written, exported, never wired — its natural
  home is a `#:guard` on the struct). Stale comments at `syntax.rkt` and in the
  test file still say `[(expr-path _) e]`.

Status: ✅ b-ii-1 COMPLETE.

<a id="p4b-ii-2"></a>

##### §5.P4b-ii-2 — The `$dot-access` fold migration (mini-audit folded 2026-08-01)

**Mini-audit** `wf_db6ff64a-b94` (5 HEAD-pinned facets + completeness critic
@ `7ba7bdad`, 6 agents / **1.36M tokens**). Load-bearing findings R-lens-verified
on the main thread. **It refuted the design's named danger and found the real
one**, and it refuted a claim b-ii-1 shipped.

**⭐ Q_U13 RULED — the mint uses the NEST encoding** [owner, 2026-08-01].
`x.a.b` mints `($select ($select x a) b)` — ONE CARRIER PER LEVEL — not the
GATHER shape `($select x a b)`. Rationale: **nesting is what the fold already
does** (probe-verified at HEAD: `x.a.b` → `(map-get (map-get x :a) :b)`), so
this is the minimal diff; and it **preserves per-level tier granularity BY
CONSTRUCTION**, which dissolves the objection that looked like it would
re-open the carrier shape (below). Accepted cost, eyes open: the dot spelling
and the `#p(a.b)` literal then encode the same path text with different
nesting arity — one struct either way, so this is not the two-representation
complection Q_U6 rejected, but it IS a divergence and is recorded as one.
The GATHER alternative was rejected-with-reason: it matches `#p(…)` exactly
and reads most literally as Q_U5's "three spellings, one representation", but
it forces the tier to become a list parallel to the steps and re-opens
per-step granularity as new work.

**⭐ THE TIER PROBLEM DISSOLVES UNDER NEST — and the two questions were the
SAME question, which no facet connected.** The strictness facet established
that the tier is decided PER DESCENT LEVEL (probe: in one chain shape, a
dyn-row level is permissive while a Map level panics) and concluded a scalar
tier slot is "structurally insufficient". The critic showed that holds only
for GATHER: under NEST each level is its own node with its own slot, exactly
as `expr-map-get` has today. So Q_U13 decides Q1.

**⚠ THE DESIGN'S NAMED DANGER DOES NOT REPRODUCE.** §5.P4b-ii claimed
`preparse-expand-subforms`'s partially-opaque `$select` arm would make every
`.field` lose infix / implicit-map / sibling-let processing. Refuted by five
probes: every sibling pass that arm bypasses is keyed on a HEAD a folded
access node never has (`def/defn/spec/trait/property/functor`; `$pipe`;
`let`/`racket`). `(map-get x :a)` and `($select x a)` composed identically in
all five. The `$select` arm DOES expand the subject; only the payload steps
are opaque, which is intended.

**⭐ THE REAL LOUD→SILENT SITE IS THE PIPE CALLER — and the in-tree test prose
FORGETS it.** `apply-pipe-step` appends the accumulator into any hole-free
list step. `|> m foo.bar` today yields `(map-get foo :bar m)` → LOUD
`arity-error "map-get expects 2 arguments, got 3"`, because `map-get`'s parser
arm imposes EXACT arity 2. Minted, it yields `($select foo bar m)` → a SILENT
two-branch `surf-select` (`branches=((bar) (m))`) — the piped accumulator has
become a selection branch at zero errors — because `$select`'s parser arm has
only an emptiness check and NO upper bound. **R-lens-verified both halves.**
`tests/test-path-selection.rkt:1020-1022` asserts in prose that
`rewrite-dot-access` has "THREE production callers" and names three; the
fourth, `expand-pipe-block` (macros.rkt:6294), landed at P3a AFTER that P2
test was written and is precisely the dangerous one. **Zero dot-access-in-pipe
coverage exists in the tree.** Correct the prose in the migrating commit.

**⚠ TWO PREREQUISITES NOBODY NAMED**:
1. **`select-reduce` does not receive the sort** — its signature is
   `(subj-expr branches)` and the call site passes two args, discarding the
   `sort` the whnf arm binds. Plumbing it is step ZERO for any tier decision.
2. **Neither walk has a `'path` ASSEMBLY.** Both assemble a ROW
   unconditionally under BOTH sorts; `x.a` must yield the VALUE. This is not
   a green-field question: **`cfg{server}.server.host` is PINNED GREEN**
   (`tests/test-path-selection.rkt:1280`) and becomes a `'path` selector over
   a `'block` selector, where the middle level must EXTRACT for the outer to
   find `host`.

**⚠ THE REGRESSION SET IS WIDER THAN §5.P4b-ii-1 RECORDED, AND ITS PINS ARE
THE WRONG SPELLING.** Of the four asymmetries, THREE regress permissive→panic
(dyn row · selection view · union) and the Map cell regresses in MESSAGE
QUALITY — from `map-get: key :zzz not found; available keys: …` to
`select: … (invariant violation — typing sourced it as present)`, **which is
FALSE for a Map under Q_U10's own posture**. And there is a SECOND arm nobody
framed: a definitely-non-map SUBJECT degrades to `(expr-fvar 'none)` at zero
errors today and PANICS under the carrier — reachable from a union narrowed
at runtime, with no typing counterpart, so no typing-axis enumeration
(including b-ii-1's four asymmetries) could surface it.
**⚠ CORRECTION to this document and to a claim made to the owner**: b-ii-1's
close notes said the D19 pins "would catch" the dyn-row regression. **They
would not.** All three cited pins use the BRACKET `[map-get …]` spelling,
which parses through the `map-get` PARSER KEYWORD, not the `$dot-access`
sentinel Q_U12 scopes b-ii-2 to. They stay GREEN through every regression
above, and **no test anywhere pins the DOT spelling's permissive miss.**

**⚠ SILENT-ACCEPT FLIPS, which no red-set census can see.** Migrating
LOOSENS QTT: `expr-map-get`'s `inferQ` is SUBJECT-TYPE-GATED (Map / Record /
schema-or-selection fvar, else `tu-error`) while `expr-select`'s delegates
unconditionally — and the map-get arm has NO `expr-union` case although
typing-core's `infer` arm does, so migrating also silently FIXES a live
lying-"Multiplicity violation" on union subjects. Both are accept-direction
flips: they produce no failing test, so they must be PINNED BEFORE the fold
or they land unrecorded.

**C5 is wider than recorded**: `select-block-hint` is not a targeted re-walk —
it SEARCHES every subfield of ANY failing expr (`ormap search (expr-subfields
x)`), from `infer/err`, on every inference failure. After b-ii-2 the `'path`
column opens FOUR side-effect classes inside an error formatter:
`register-selection!` + `global-env-add-type-only`, `fresh-meta` ×2, `check`
(which solves metas), and `with-speculative-rollback` (a network fork) — all
under an all-exceptions swallow that discards the raise but not the effects.

**`_.field` deletion is REAL, SILENT, and the repair is not the obvious one.**
Three working shapes, ZERO tests. "Add `$select` to `sectionable-op-keywords`"
is **INERT**: `$select`'s clause precedes the section clause in the SAME
`parse-list` cond, so it never reaches it. (b-ii-3's, but b-ii-2 must not
delete it in the meantime.)

**Q_U12's taxonomy is looser than its phrasing** (adjudicated): ordinals are
ALREADY in the step vocabulary (`'ord-step`/`'ord-branch`) and ride the
carrier from block spellings, so "`[k]` is a different sort" is not the real
reason. The structural reason is that `[k]` admits a COMPUTED key — an expr —
while the payload is declared STATIC data with no exprs inside
(`syntax.rkt:765`) and `select-step-kind` is a closed union. Stating it
structurally also says exactly when the follow-up becomes possible.

**⭐ Q_U14 RULED — b-ii-2 SPLITS: 2a (prerequisites + before-the-fold pins) →
2b+2c TOGETHER (the mint + its diagnostics)** [owner, 2026-08-01]. 2c is NOT
separable from 2b: without it a `.zz` miss gets a block-worded message whose
remedy tells the user to spell it `.zz` — and `select-block-hint` runs BEFORE
`closed-row-miss-hint`, so the bad message WINS. Not a lost hint, actively
misleading advice; "we'll fix the message next slice" is how a misleading
diagnostic becomes permanent.

###### §5.P4b-ii-2a — Prerequisites + the before-the-fold tripwires  ✅

**The two prerequisites the audit found that NOBODY had named:**
1. **`select-reduce` now RECEIVES the sort.** Its signature was
   `(subj-expr branches)` and the whnf call site DISCARDED the sort it had just
   bound — so every runtime outcome for a migrated `.field` would have been
   decided by a sort-blind function. Step zero for any tier work.
2. **BOTH walks now have a `'path` ASSEMBLY.** They assembled a ROW
   unconditionally under BOTH sorts, so the fold could not be flipped: `x.a`
   would have typed as `{:a T}` and reduced to `{:a v}` instead of `T`/`v`. A
   path EXTRACTS, a block PROJECTS. Under Q_U13's NEST encoding a `'path`
   carrier is exactly one branch of one step per level, so extraction is
   unambiguous; a 0-or->1-component path carrier REFUSES loudly rather than
   silently taking the first (the P2.b fabrication class). ⚠ This was not a
   green-field question — **`cfg{server}.server.host` is PINNED GREEN** and
   becomes a `'path` selector over a `'block` one.

**The `tier` FIELD on `expr-select`** (arity 2→3, `#f` = no claim), landed
INERT — every construction passes `#f` and nothing reads it; b-ii-2b mints the
meta at the fold and teaches `select-reduce` to read it. On `expr-select` and
not on the selector because the tier is a property of the APPLICATION
(subject × selector) — a bare `#p(…)` has no subject and so no tier — and
because it then rides `select-map-exprs`, the ONE reconstruction point for six
walkers, instead of six independent identity arms. A SCALAR suffices only
because of Q_U13: under NEST each level is its own node, exactly as each
`.field` is its own `expr-map-get` today.
⚠ **`select-map-exprs` MAPS the tier, it does not merely carry it.** A carried-
but-unmapped tier would never ZONK, `expr-true?` would never hold, and every
Map miss would go silently PERMISSIVE — a reverse regression with no signal,
and precisely the hidden cost the audit identified in the rejected
put-it-on-the-selector option. Pinned.

**THE BEFORE-THE-FOLD TRIPWIRES** — pins for behaviour b-ii-2b WILL change.
They are tripwires, not invariants: their job is to make each change VISIBLE
(a RED test at 2b, updated deliberately with the delta recorded) instead of
silent. They exist because the audit found a class **no red-set census can
see** — ACCEPT-DIRECTION flips produce no failing test.
- **the union-subject LYING DIAGNOSTIC**, live and probe-confirmed today:
  `def y := u.a` on a union reports **"Multiplicity violation"** because
  `qtt.rkt`'s `expr-map-get` arm is subject-type-gated with no `expr-union`
  case while typing-core's `infer` has one. The fold SILENTLY FIXES this.
- **the DOT spelling's permissive dyn-row miss** — `d1.zzz` → `<error>` at
  ZERO errors. **Nothing in the tree pinned this**: all three D19 pins use the
  BRACKET spelling, which never reaches the `$dot-access` sentinel.
- **`_.field` sections**, three shapes, zero prior tests.
⚠ The `_.field` tripwire FAILED ON ITS FIRST RUN for the `:no-prelude`
false-green reason this file was hardened against (`map` does not exist there,
so an Unbound-variable cascade masks the deletion the pin exists to catch).
Moved to the prelude-backed fixture, reason recorded in the pin.

⚠ **Two b-ii-1 pins went RED on the assembly change — correctly.** They
asserted `select-project` returns a ROW under `'path`, which is exactly what
2a changes. Updated to assert EXTRACTION, annotated as having caught their own
slice's change.

Test delta **269 → 276**. Suite green.

Status: ✅ 2a COMPLETE · ⬜ 2b+2c (the mint + its diagnostics).

###### §5.P4b-ii-2b/2c — THE FLIP + its diagnostics  ✅ `54d940fe`

**Q_U15 RULED — the fold mints a DISTINCT sentinel `$select-path`** [owner],
not a reused `$select`. Forced: `surf-select` had NO sort field and the
elaborator HARD-CODED `'block`, so a reused head left the elaborator unable to
tell a dot access from a brace block. The fold mints in preparse and the origin
is gone by the time a surf-select exists, so the sort had to become a CARRIED
fact and a distinct head is the channel.

**⭐ THE ARITY GATE, and why the distinct sentinel pays for itself.**
`map-get`'s parser arm imposes EXACT arity 2; `$select`'s has only an emptiness
check and NO upper bound, so every surplus arg becomes a BRANCH.
`apply-pipe-step` appends the accumulator into any hole-free step, so a reused
`$select` would have turned `|> m foo.bar` from a LOUD arity-error into a
SILENT two-branch select. The same append lives in the `>>` compose twin, so a
blacklist fix needed BOTH. Enforcing one-branch at the path arm fixes every
caller at once, structurally.

**Registration cost, MEASURED: FIVE sites, not §Q8.5's nine** — because that
surface is written for a GROUPING-minted sentinel and this one is minted by the
fold in preparse, after grouping and tree-parsing. Mirroring the sibling beat
applying the checklist. (The verify then found a SIXTH — see below.)

**2c was NOT separable** (Q_U14): probed live, `r.zzz` said "…in the select
branch `zzz` — bare field access is spelled `.zzz`", instructing the user to
write what they had just written, and `select-block-hint` runs BEFORE
`closed-row-miss-hint` so the bad message WON. The fix is SCOPED — the block
spelling keeps its teaching tail — pinned both ways.

**The RED set came in at 12 datum assertions across 4 files and NOTHING ELSE.**
No value-assertion failures, no type errors. The b-ii audit warned a
datum-shape census is blind to type-error failures; that warning was sound, and
the reason it did not bite is that b-ii-1 and 2a did the semantic work first.

#### ⚠ THE ADVERSARIAL VERIFY (4 skeptics) — a BLOCKING find and hollow pins

1. **BLOCKING, found INDEPENDENTLY BY TWO SKEPTICS** via A/B against a baseline
   tree: `.field` on a union whose runtime value is a NON-MAP component
   **PANICKED** where `[map-get u :a]` degrades to `none` at ZERO errors. The
   first cut tier-gated the keyed MISS and never looked at the SUBJECT-kind arm
   one level above. **That is the permissive→panic conversion this slice exists
   to prevent**, and the message lied twice — "the block" for a dot access, and
   "invariant violation" when typing legitimately admitted a union with a
   non-map component. Now tier-gated; both spellings agree.
2. **THE TIER PINS WERE HOLLOW**, proved by MUTATION: disabling reduction's
   assertive arm, and separately disabling typing's `solve-strict-assert!`,
   EACH left 283/283 green. 2a's tripwire pinned the PERMISSIVE half; the LOUD
   half — whose failure STORES a wrong answer — had nothing. Three pins added
   (the P2.b A1/A1b/A2 analogues) and BOTH mutations re-run to confirm they now
   fail. One is also the only test executing `assertive-miss-message`, whose
   extraction had fixed a live crash with zero coverage.
3. **A SILENT ACCEPT-FLIP nobody predicted**: the field rides as a bare SYMBOL
   now, so `segment-select-items` splits `^` out of it into a re-key
   continuation and the `'path` assembly DROPPED it — five spellings returned
   the plain field at ZERO errors where HEAD refused, while `pp-expr` rendered
   the `^` faithfully. Honest display over dishonest semantics. Now a guided
   refusal; blocks keep `^` in full.
4. **THE FOURTH CONSECUTIVE MISSED `pretty-print.rkt` SITE**: `pp-datum` had no
   arm, so `expand r.a` emitted the raw sentinel where HEAD emitted readable
   `(map-get r :a)` — a silent regression on the introspection path for the
   most common access surface in the language. b-ii-1's census fixed `pp-expr`
   and stopped 1000 lines short of its DATUM-layer twin, on a datum-layer
   migration.
5. **THREE BINARY SORT DISPATCHES**, violating the rule written one slice
   earlier: `(if (eq? sort 'path) …)` in elaborator/typing-core/typing-errors,
   when `select-sort-unhandled` exists precisely to forbid it. Concrete future
   failure: a `'nil-safe` node gets tier `#f`, which reduction reads as BLOCK,
   so a nil-safe miss whose contract is `none` would panic. All total now.
6. **Three MINORs**: `assertive-miss-message` claimed two consumers and had one
   (map-get now shares it — the anti-drift property is ESTABLISHED, not
   asserted); `uses-bvar0?` skipped the tier under a stale "subject is the only
   expr slot" comment; `select-reduce`'s `[tier #f]` default was a trap (`#f`
   means BLOCK, not "no claim") — defaults removed.

Suite **9732/478/0** · battery **280 → 289** · acceptance 52/52 + 89/89 + 29/29.

Status: ✅ 2b+2c COMPLETE.

<a id="p4b-ii-3"></a>

##### §5.P4b-ii-3 — DISSOLVED at the close (its scope was discharged at 2b)

`_.field` was RESCUED inside 2b by eta-expansion in the `$select-path` parser
arm. The design's assumed repair — "add `$select` to `sectionable-op-keywords`"
— is **INERT**: that clause is dispatched LATER in the same `parse-list` cond,
so the section path is unreachable for any select head. Re-verified at the
close: `[_.a r]` → `7`, `map _.a recs` → `@[1 2]`, `|> r _.a` → `7`, all at
zero errors. Nested `_.a.b` remains broken — verified IDENTICAL at HEAD
(`parse-keyword-section` detects only a top-level `_`), so it is pre-existing,
not a regression (DEFERRED 28).

Status: ✅ DISSOLVED — no residue of its own.

<a id="p4b-ii-close"></a>

##### §5.P4b-ii — CLOSE  ✅ (2026-08-01)

**b-ii is COMPLETE**: b-ii-1 (the (subject × sort) table, four asymmetries) →
b-ii-2a (the two unnamed prerequisites + the tripwires) → b-ii-2b/2c (the flip
+ its diagnostics) → b-ii-3 DISSOLVED. Q_U12's scoping held: the `$dot-access`
leg migrated; `#.field` and `[k]` keep their nodes as named follow-ups
(DEFERRED 30 — and the audit sharpened the REASON from a taxonomic one to a
structural one: `[k]` admits a COMPUTED KEY, and the payload is declared
static-no-exprs).

**Residue filed, DEFERRED 24–30.** The one that deserves the owner's eye is
**24**: `select-block-hint` searches every subfield of every failing expr, from
`infer/err`, under a swallow-everything handler — and the flip made the `'path`
column reachable from it, opening four side-effect classes (registry mutation,
`fresh-meta` ×2, meta-solving `check`, a speculative network fork) **inside an
error formatter**. Mechanism confirmed by reading; **observable harm NOT
demonstrated** in two close-time probes. Filed as a reachability RISK, stated
that way deliberately — "I could not trigger it twice" is not evidence of
safety for a walker that runs on every inference failure.

**What b-ii cost, and what it bought.** Four owner rulings (Q_U12 scoping,
Q_U13 NEST, Q_U14 the 2a/2b+2c split, Q_U15 the distinct sentinel), one
mini-audit (1.36M tokens, 6 agents) and one adversarial verify (4 skeptics).
The verify found a **BLOCKING** permissive→panic that two skeptics located
independently, and proved by MUTATION that the tier pins were hollow — two
independent mutations left the battery fully green.

**The transferable lesson**: *a tripwire on one side of a fork is not coverage
of the fork.* 2a's tripwire pinned the PERMISSIVE half of the two-tier miss;
the LOUD half — whose failure STORES a wrong answer — had nothing, and stayed
green under mutation. When a change introduces a FORK, both arms need pins, and
mutation is what proves it.

Suite **9732/478/0** · battery 240 → **289** · acceptance 52/52 + 89/89 + 29/29.

<a id="p4c"></a>

#### §5.P4c — The `:` gate + the ω wrapper + PVec broadcast  (co-design 2026-08-01; Q_U16/Q_U16b RULED)

**Grounding**: audit `wf_d7c035da-cee` (6 facets + completeness critic @
`532474c0`, 7 agents / 1.53M tokens) → adversarial options panel
`wf_6f15c6ae-6a7` (3 clusters × propose/critique + synthesis, 7 agents / 1.17M
tokens). Every load-bearing claim below was **R-lens-verified on the main
thread**; two of the panel's own numbers were wrong and are corrected here.
The rulings are §3's Q_U16 / Q_U16b.

##### PREREQUISITES — land FIRST, independently valuable, owed under every option

Both were raised by three independent critics, and both are **live defects at
HEAD**, not hypotheticals:

1. **Hoist `adjacent-to-base?` into `reader-forms.rkt`.** It is defined at
   parse-reader.rkt:3187-3193 (four conjuncts, consults NO token type), is NOT
   exported, has exactly two call sites (:3249 lbracket, :3305 lbrace) — and
   **surface-rewrite.rkt:550-556 hand-inlines the same four conjuncts** for
   lbrace only, its own comment admitting it "mirrors parse-reader's
   `adjacent-to-base?`", in a module that ALREADY requires reader-forms.rkt.
   That is a live F1b.7g drift instance. Landing the `:` mint in both groupers
   without hoisting writes the test a THIRD time. ⚠ D4's coordinate for this
   function (`:2632`) is **555 lines stale**.
2. **Make the `ns` name guard TOTAL.** namespace.rkt:895-896 enumerates only
   `$dot-access`/`$postfix-index`; probe: `ns foo:bar` → `((ns foo :bar))`, so
   the uniform gate FIRES and the guard would silently DROP the segment — a
   FOURTH instance of the `b0db8f3e` class, which D4 already records as having
   THREE unclosed instances. **Refuse any PAIR segment** rather than adding a
   fourth memq entry: that closes the class instead of extending it.

##### The partition

- **P4c-1 — prerequisites + the classifier promotion.** The two above, plus
  `colon-annotation` promoted to a real token type (Q_U16b) WITH an explicit
  `token-entry->stx` arm. No new surface; the corpus A/B must be **ZERO diffs**
  at this point, which is what makes it a clean attribution baseline.
- **P4c-2 — the mint + the binder unwrap** (the Q_U16 core). The grouping arm
  in BOTH groupers over the hoisted predicate; ~~`$bcast-step` into
  `access-sentinel?` + its fold arm~~ — ⚠ **THIS DID NOT LAND AND P4c-2 CLOSED ✅
  ANYWAY** (found 2026-08-02 at the P4c-3 close; `access-sentinel?` at
  macros.rkt:6128-6132 lists eight members and `$bcast-step` is not one —
  `broadcast-access?` there is the RETIRED `$broadcast-access`, a different
  head, which is what made the gap read as closed). **It is NOT a live defect**:
  with the enable-set empty no sentinel survives the post-pass, so the fold
  never meets one. It is a PREREQUISITE of the first grant, and it moves to
  P4c-4 with the grant — see §5.P4c-3. The accurate record of what landed is the
  in-code comment at parse-reader.rkt:2834-2835, not this line; the design doc
  was the drifting copy; the reader post-pass unwrap with its
  totality hardening and per-binding-form pins. **The corpus A/B lands here**
  with the named diff set below.
- **P4c-3 — the `(@bcast step)` step kind.** Its arm across P4a's THIRTEEN
  sites (the `ADDING A KIND` recipe at syntax.rkt:879-904 is the authority, NOT
  this document), plus the two shape-test helpers OUTSIDE the recipe, plus the
  branch-initial refusal. ⚠ **The enable-set does NOT land here** — owner ruling
  2026-08-02, see §5.P4c-3. It moves to P4c-4, where the thing it would switch
  on exists.
- **P4c-4 — PVec broadcast + the law pins + ⭐ THE ENABLE-SET.** The third
  dispatcher in both walks; the L1 fusion pin (`users:0:userName` → ONE layer)
  and the §3.2.1 extent pair; `quests:t`/`quests:{t r}` uncomment as PVec
  broadcasts. **Plus everything the first grant requires, moved here from
  P4c-3** (owner ruling 2026-08-02): `$bcast-step` into `access-sentinel?` + its
  fold arm (the P4c-2 line above) · the PRODUCER BRIDGE (`make-select-bcast` has
  ZERO production callers at HEAD — the parser's `bcast-step` arm emits the
  not-yet error instead of constructing, so no grant can yield a working
  broadcast) · a TEST SEAM (`broadcast-enabled-contexts` is an unexported
  `define`, not a parameter, so no context can be enabled from a test) · the
  per-context DISPATCH MECHANISM (only `(pair? …)` is consulted today) · and the
  unknown-head ruling that DEFERRED 32's open half names.
- **P4c-5 — the `.*name` retirement + FULL residue disposal**, in the commit
  that discharges the parser's `:name` promise.

##### THE NAMED PREDICTED DIFF SET (A/B is MANDATORY; any diff outside is a bug)

Group-aware, independently re-derived at HEAD — **161 tracked `.prologos` ·
1532 `keyword` tokens · 289 `colon-annotation` tokens · SEVEN would-mint**
(repo-wide, 163 files: still seven):
`examples/2026-07-31-let-blocks.prologos:185,:186,:195` ·
`examples/2026-07-31-let-toplevel.prologos:37` (TWO tokens — **defn params, not
let**) and `:84` · `examples/homoiconicity.prologos:96` (`':hello`).
⚠ **Re-derive at implementation HEAD** — `examples/2026-03-20-first-class-paths.prologos`
and `lib/examples/foray.prologos` are BOTH dirty in the owner's tree, and an
A/B over a dirty tree measures the tree (3rd sighting of that class). Pin BOTH
legs' inputs with `git archive`, never a working-tree read.

##### HAZARDS THE AUDIT NAMED — none may be rediscovered mid-slice

1. **The `.prologos` safety net DOES NOT EXIST.** All three would-mint files are
   UNGATED; all six `process-file`-gated acceptance files contain ZERO. The only
   suite-RED tripwire is **eight verbatim datum pins** at
   `tests/test-parse-reader.rkt:494-516`, ALL of which flip — list them as
   **DELIBERATE** flips or they read as a regression. Safe-by-construction and
   **must NOT be touched**: `:512-513` (`x:0abc`/`x:10abc` — the annotation arm
   declines, the colon shatters) and `:522-523` (`{:10 v}`/`{:0 v}` —
   branch-initial, empty local result). **P4c should gate one would-mint file
   before the mint lands.**
2. **⚠ Admitting bare `colon` to the trigger BREAKS `:512-513`.** In both, the
   shattered bare `:` IS byte-adjacent with a non-empty result. This is a hard
   constraint on any attempt to reach the five shatter spellings.
3. **`ident-continue?` accepts `*` and `^`** (parse-reader.rkt:231/:237), so
   `users:tags*` and `users:name^alias` lex as **SINGLE keyword tokens** with
   the operator swallowed into the step NAME. Refusing them guidedly needs an
   explicit lexeme check on the minted name — an enumeration, to be named as
   such: *"incomplete because `ident-continue?` swallows the operator into the
   token; deferred for removal to the phase landing the `*` and `^` steps."*
   And `:name^alias` otherwise **slips past** parser.rkt:1316's `^`-refusal
   (via `select-step-name` returning the raw pair) — the refusal the b-ii-2b
   verify installed after five spellings were found silently ignored.
4. **Quote-adjacency is a THIRD bucket**: `':hello` → `(|'| :hello)` mints in
   EXPRESSION position where no binder unwrap can rescue it. Prior art for the
   decline conjunct: `prev-token-reader-form-head?` (parse-reader.rkt:3197-3201).
5. **The Q_N3 two-grouper agreement guard is BLIND to this sentinel** in both
   versions (v1 is count-comparing and the mint is count-preserving; v2 pairs a
   tree TAG with a datum sentinel, a correspondence only OPENERS have). The
   "one grouper only" failure is UNPINNED — a third guard shape is owed.
6. **§Q8.5's applicability table has NO ROW for this shape** (third consecutive
   under-specification of that invariant): `$bcast-step` is NO-NEW-TOKEN *and*
   NON-OPENER, while the table offers only OPENER and SELF-CONTAINED. Sentinel
   site 2 (`group-items-to-tree`) is **N/A** for a non-opener — proof in-tree:
   `tag-dot-access` is defined and exported with ZERO producers.
7. **TWO DISJOINT registration surfaces, neither cross-referencing the other**:
   §Q8.5's reader-sentinel sites AND P4a's 13-site step-vocabulary recipe. Carry
   both checklists side by side in the slice.
8. **`token-entry->stx`'s keyword arm is `(string->symbol lexeme)`**, so `:Int`
   already arrives as the colon-symbol `|:Int|`. The mint must WRAP it verbatim
   so the unwrap is `cadr`; a mint that strips and an unwrap that re-adds `:`
   is a second copy of the recognizer — the F1b.7g class.
9. **The scalar `tier` cannot express "some elements hit, some missed"** across
   a broadcast level (syntax.rkt:792-796; Q_U13's sufficiency argument is stated
   PER DESCENT LEVEL). Unaddressed anywhere — rule it in P4c-4.
10. **`parse-rel-params` (parser.rkt:6062/:6108) consumes `colon-symbol?`
    DIRECTLY** and never calls `fused-type-annot?`, so it is structurally
    invisible to a census keyed on the narrower predicate. `fused-type-annot?`
    is ELEVEN sites / 7 functions (not the design's four); counting
    `colon-symbol?` too gives **17 sites / 8 functions**.

##### DOC-TRUTH REPAIRS owed in this slice

D4:902 still says `quests:t` works "at P4d" and :3067 still says it "does NOT
uncomment" — both superseded by the solve→PVec spin-out; the corpus cite `:235`
is stale by 3 (the lines are `:232`/`:233`). §5.P4's Intent block at :3103-3105
still asserts the RETIRED pre-NEST model ("under the step-list node (4b)", "the
layer count is unfused-ω-steps"), both superseded by Q_U13/Q_U7. **§Q8.5's
silent-degradation tier is factually WRONG at HEAD** — `pp-datum` HAS an
access-family arm (`$select-path`, pretty-print.rkt:1691-1693) — and its sibling
path is `racket/prologos/tools/form-deps.rkt`, not `tools/form-deps.rkt`.
§Q8.5 invariant 1's "prefix-disjointness, not priority" framing is also wrong
for `:w`/`:m`: **both recognizers match at length 2 and priority 97>95 silently
decides.**

<a id="p4c-1"></a>

##### §5.P4c-1 — Prerequisites + the classifier promotion  ✅

**No new surface.** Three deliverables, two of which were LIVE defects.

1. **`adjacent-to-base?` is now THE definition, consumed by both groupers.**
   ⚠ **The options panel's recommended home was WRONG**, and checking the
   dependency gave a simpler answer: the predicate is over the `token-entry`
   STRUCT (parse-reader.rkt:183), so hoisting it to `reader-forms.rkt` would
   drag the struct along and break that module's deliberate "requires nothing
   project-local" invariant — the very property that made it the suggested
   home. `surface-rewrite.rkt` **already requires parse-reader.rkt** (:26), so
   EXPORTING is cycle-free by construction. The hand-inlined four-conjunct copy
   at surface-rewrite.rkt:550-556 is deleted; P4c-2 would have made it a third.
2. **The `ns` name guard is TOTAL, by POLARITY INVERSION.** It was a NEGATIVE
   list of two sentinel heads, which is why **`ns foo:bar` SILENTLY DROPPED
   `:bar` at ZERO errors** — probe-verified end-to-end, a LIVE `b0db8f3e`
   instance, not a prospective one. `ns` accepts exactly ONE option
   (`:no-prelude`), so the total form is a positive ALLOW-LIST: the same
   inversion `definitely-not-map?` took at P2.b slice 1. This CLOSES the class
   (D4 recorded three unclosed instances) instead of adding a fourth entry.
   ⚠ **Named consequence**: the guard RAISES rather than returning a
   per-command error value, so `ns foo:bar` goes from a silent drop to a
   WHOLE-FILE ABORT. Strictly better and monotone, but harsher than the
   discipline calls for — filed as **DEFERRED 31** (owner-requested), channel
   conversion deliberately out of this slice's scope.
3. **`colon-annotation` classifies to its own token type** (Q_U16b), with
   **EXPLICIT arms at BOTH `case type` sites** (`token-entry->stx` and its
   compat twin) rather than relying on `[else]` — whose safety would have been
   a coincidence of two identity-returning else-arms at the exact site this file
   documents as its silent-miss hazard.

**Test delta +9** (7 in the track file, incl. the ns refusal + its message +
the totality-preservation pair + the datum-invisibility pin; 3 in
`test-parse-reader.rkt` beside their siblings, where
`register-default-token-patterns!` is called at :23).

⚠ **THREE OF MY OWN PINS FAILED FOR THE WRONG REASON and were corrected before
implementation** — the discipline caught the author: one read `(car rs)` on a
lone `ns` line that yields NO results; one asserted a GUESSED datum baseline for
`{:0 v}` (it is `($brace-params :0 v)`) — a baseline pin asserting a guessed
baseline is worse than none; and two were mutually incoherent about the error
channel. **And the FALSE-ZERO footgun bit the author of the pins**: a direct
`tokenize-char-rrb` without `register-default-token-patterns!` returned every
character as its own `symbol` token — the exact hazard
`tools/reader-corpus-ab.rkt:74` carries a tripwire for.

**CORPUS A/B: 161 files, ZERO DIFFS**, both legs pinned to ONE immutable
`git archive` snapshot with only the code differing (the owner's tree has 6
dirty `.prologos` files; a working-tree read would have measured the tree —
3rd sighting of that class). That zero is the point of landing these three
together: it is the clean attribution baseline that makes P4c-2's SEVEN
predicted diffs attributable to the MINT alone.

Status: ✅ P4c-1 COMPLETE.

<a id="p4c-2"></a>

##### §5.P4c-2 — The mint + the reader-post-pass binder unwrap  (mini-design 2026-08-01)

**THE BINDER TABLE, MEASURED — not enumerated from memory.** Q_U16 booked "a
permanent hand-maintained enumeration" of binding forms. The mini-design
measured its actual membership at HEAD by probing which forms carry a fused
annotation that the mint would capture, and the result **corrects the design in
both directions and is materially larger than assumed**:

| MINT FIRES (binder position — unwrap owed) | MINT DOES NOT FIRE |
|---|---|
| `def x:Int` · `defn f [a:Int]` · `fn [x:Int]` · `spec g [a:Int]` · `let x:Int` · `property` · `functor` · `trait` METHOD params · **`$pipe` ARMS** (`defn` AND `match`) · `rel [a:Int]` · `defr [a:Int]` | **`?x:Nat` in ANY form** — glued into ONE token by `narrow-var-annot` (pri 96) · `schema`'s `:f` (branch-initial ⇒ empty local result) · SPACED `x : T` anywhere · map keys `{:a 1}` (branch-initial) · keyword args `f x :name` (spaced) |

`impl` needs NO entry — the walk recurses and the inner `defn` covers it.

**THREE findings the census produced that no prior enumeration named:**
1. **`$pipe` arms fire** — `match v | c a:Int -> a` → `($pipe c a :Int -> a)`,
   and `defn f | a:Int -> a` likewise. Named by neither the audit, the options
   panel, nor the first draft of this table (owner-caught).
2. **PATTERNS NEST**: `defn g | [cons h:Int t] -> h` →
   `($pipe (cons h :Int t) -> h)`. The unwrap CANNOT scan an arm's top-level
   items — it must recurse into pattern sub-groups.
3. **`defr`/`rel` ARE members via the BARE-NAME spelling** even though their
   `?`-prefixed form is immune. An earlier draft of this table declared `defr`
   OUT on the strength of the `?a:Nat` probe alone — an under-count committed
   and corrected inside one session, by measuring rather than listing.

**⚠ THE DISCRIMINATOR IS THE SPELLING, NOT THE FORM — and that changes Q_U16's
booked cost.** Every form with a bracketed param group is a member for the
bare-name spelling, so the table is NEAR-UNIVERSAL rather than the five entries
the ruling implied. A near-universal allow-list is a weaker structure than what
was accepted; recorded as a correction to the ruling's cost, not smuggled in.
**Owner ruled [2026-08-01]: take the table as measured**, with the loud-refusal
hardening at the 17 consumer sites so a MISSING entry surfaces as a guided
error on first use rather than as a wrong parse.

**⭐ THE TREE ALREADY SOLVES THIS COLLISION LEXICALLY, for one vocabulary.**
`?x:Nat` never fires because `narrow-var-annot` glues it into ONE token — the
`?` prefix is a lexical marker meaning "this is a binder", making the collision
STRUCTURALLY IMPOSSIBLE instead of managing it downstream. Recorded because it
is the shape a future simplification would take (and the shape X.close should
weigh), not proposed for v1: requiring a marker on ordinary binders would change
the fused surface the owner ruled MORE important than broadcast.

**Condition (a) is documented AT THE SEAT and is not theoretical**:
parse-reader.rkt:2586-2596 records that the first draft of this walk rebuilt
every stx-list and DROPPED SYNTAX PROPERTIES — including POL.9's
`prologos-paren-origin` — silently degrading an implicit-solve paren goal to an
APPLICATION. The unwrap must be eq?-preserving for untouched forms.

**Drift risks named before code**: the table missing a form (mitigated by the
consumer hardening) · the eq?-preservation trap above · twin drift between the
two groupers · the quote bucket (`':hello`) where the mint fires in EXPRESSION
position and no binder unwrap can rescue it.

**LANDED (the mint + the unwrap) — but P4c-2 is NOT COMPLETE**; condition (c)
is outstanding, see below.

**The mint**: one shared trigger `bcast-step-trigger?` (= `adjacent-to-base?` +
a token-type test + the quote decline), consumed by BOTH groupers rather than
copied. Positional, so `.N`/brackets/parens/closers joined the focus set free.
⚠ **The payload is wrapped VERBATIM** — `($bcast-step |:name|)`, not a stripped
`name`. My pins first asserted the stripped form; that would have forced the
unwrap to re-add `:`, i.e. a SECOND copy of the recognizer's accept-set — the
F1b.7g class. The unwrap is therefore a plain `cadr`.

**The unwrap** needed THREE rules the mini-design had not separated:
- **terminator-bounded** (`def` · `let` · `$pipe` arms) — up to `:=` / `->`,
  never past, so values and arm BODIES keep their broadcasts;
- **param-head SCAN** (`defn` `fn` `spec` `property` `functor` `rel` `defr`) —
  because `rel` is a SIBLING in `def q := rel [a:Int] …`, not a form head, and
  a head-test structurally cannot see it;
- **deep** (`trait`) — method params sit inside lists headed by the METHOD
  NAME, so there is nothing to key on. Safe ONLY because a trait body is
  signatures with no expression bodies; **this entry must narrow if `trait`
  ever gains default method bodies.**

**⚠ CORRECTION TO THIS DOCUMENT — the predicted A/B diff set is ZERO, not
SEVEN.** §5.P4c's named seven-site set was computed against the mint WITHOUT
Q_U16's unwrap. With the unwrap those sites ROUND-TRIP (mint→unwrap = identity),
so the datum never moves: **161 files, ZERO diffs**. Verified it discriminates
rather than trusting the number — zero-where-seven-was-predicted is exactly what
a silently-broken gate looks like. The same lexeme separates the two readings:
`users:Int` → `($bcast-step :Int)` while `let x:Int 5` → `(let x :Int 5 x)`.
A future reader must not treat the mismatch as a regression.

**⚠ A REGRESSION I INTRODUCED, caught by an EARLIER PHASE'S pin.**
`apply-binder-unwrap` did `(car kids)` unguarded — but `kids` is not always a
list: `classify-let-block`'s FAIL path returns a SYNTAX OBJECT wrapping
`($let-error …)`. A contained let-LAYOUT error became a `car: contract
violation`, i.e. a WHOLE-FILE ABORT. parse-reader.rkt carries a "CONTRACT
REPAIR" note documenting that exact hazard, and I reintroduced it roughly one
screen below the note. Caught by test-let-blocks' pin named *"a top-level
let-block LAYOUT error is CONTAINED, not a file abort"* — a pin written by an
earlier phase doing its job against a later phase's author.

**THE EIGHT DELIBERATE FLIPS** (tests/test-parse-reader.rkt:494-516) updated and
annotated IN PLACE as flips — third consecutive phase where the prior rung's
flagship pin flips. Their two neighbours must NOT move and are load-bearing:
`x:0abc`/`x:10abc` (annotation arm declines, colon shatters — OUTSIDE the
trigger) and `{:10 v}`/`{:0 v}` (branch-initial ⇒ empty local result).

**Also recorded — a second guessed baseline this session**: the quote-bucket pin
first asserted `(quote :hello)`; the datum is `(|'| :hello)`, the loose `'`
being exactly WHY the bucket needs a decline. A pin that asserts a REMEMBERED
baseline is the one shape that ships vacuously green.

Suite **9758 / 478 / 0** · battery 294 → **312** · acceptance 52/52 · A/B ZERO.

<a id="p4c-2-close"></a>

##### §5.P4c-2 CLOSE — the table's FOUR measured misses + condition (c)  ✅

**Owner ruled scope (ii)** at the re-grounding checkpoint: full unwrap-coverage
repair, not consumer-hardening alone. The reason is the table's own record —
**measuring it produced four distinct misses inside ONE session**, which
disqualifies the enumeration as the safety property and makes condition (c) the
mechanism rather than the belt. That is the INVERSE of how this document framed
the two, and the inversion is the slice's main design finding.

**⭐ A LIVE END-TO-END REGRESSION, found by re-grounding, invisible to every gate
this phase ran.** `defn- priv [x:Int] x` defines a 1-arity function at ZERO
errors on the pre-mint baseline and FAILS at `b1399016`. `private-form-base`
normalized the `-` suffix at PREPARSE — strictly AFTER the reader post-pass — so
at unwrap time the head is literally `defn-`, the `memq` misses, and the sentinel
leaks into the param group. **ELEVEN suffixed heads.** Isolated by an A/B against
a worktree pinned at `182f1678`. The corpus A/B stayed ZERO because no tracked
file pairs a private form with a fused annotation, and **all 18 P4c-2 pins are
reader-level**, so none could see it — the same blindness that lets
`def x:Int := 5` hold a green datum pin while aborting the whole file.
`private-form-base` MOVED to `reader-forms.rkt` (two consumers, two layers, and
parse-reader cannot require macros) rather than being copied — a second copy is
the F1b.7g class that module exists to forbid.

**The other three misses**: a leading implicit-binder group ATE the arming so the
real param group leaked (`spec f {A} [x:Int]`, idiomatic) · `defmacro`'s param
group binds and was in NO list · a flat single-line `$pipe` arm never reached the
arm rule (SPELLING-SPECIFIC — the multi-line form was correct, and is now pinned
so a fix cannot trade one spelling for the other).

**⚠ AND AN OVER-REACH THE RULING NEVER BOOKED — the opposite direction, which
condition (c) STRUCTURALLY CANNOT CATCH** because no sentinel survives for a
refusal arm to see. The terminator SEARCH ran to the end of the list when no
terminator was found, and `:=` is OPTIONAL in WS `let`: `let x 5` + a body
`users:name` came back with the broadcast silently STRIPPED. Same for arms-only
`defn` (the PRIMARY multi-arity form). Q_U16 booked three conditions; **none of
them covers this direction.** Inert only until P4c-3 gives the sentinel a
consumer — pinned now rather than discovered then.

**ROOT CAUSE, shared by three of the five**: `scan-for-param-heads` carried a
STICKY `armed?` flag that survived every intervening SYMBOL and was discharged by
the next LIST of any kind. That single shortcut produced both directions of
error, and it is why the FIRST `$pipe` arm unwrapped **by accident** — the
`($bcast-step …)` itself was being mistaken for the param group. Replaced with
explicit region consumption over the real grammar: HEAD · optional NAME · zero or
more `{…}` groups · ONE param group · then BODY, never touched.

**Condition (c) — the shape CHANGED once the sites were measured.** This document
scoped it as "convert silence into a guided error" at 17 predicate-keyed sites.
Both halves of that premise are wrong:
- **The 17 are not where a leak lands.** `parse-defn`'s DISPATCHER decides by
  content (its bare-params arm requires every element to be `symbol?`), so a
  leaked LIST declines every arm and never reaches the consumer the census named.
  The guard written at `parse-defn-bare-params`' `[else]` was **unreachable**.
  **FIFTH instance of the `parse-rel-params` blindness class** — a dispatcher is
  a binder consumer, keyed on neither predicate.
- **The failure mode is not silence.** Under maximal mutation every reachable
  form already failed LOUDLY — four different generic messages, two dumping raw
  syntax objects at the user. Only `def` was worse than silent (whole-file abort,
  PRE-EXISTING) — **since FIXED**: the spun-off chip landed and merged, and
  `def x:Int := 5` now defines cleanly at 0 errors (verified at the merge). So (c) is a **DIAGNOSTIC upgrade**, and is described
  as one rather than as the design framed it.

**⭐ MUTATION CAUGHT A DEAD GUARD OF MINE.** The first `bcast-step-datum?`
compared `(car d)` to the symbol directly, but `stx->datum` at these seats peels
ONE layer — the head arrives still wrapped — so the predicate never returned `#t`
at ANY site. Suite green, probes green, guards inert. Only emptying the binder
tables found it. **A green suite is not evidence for a tripwire.**

**The guards cannot carry a standing pin, and that is the desired end state**:
with the table correct nothing reaches them, and hand-feeding the leaked shape as
sexp does not work either (it goes through the SAME post-pass and is unwrapped —
probe-verified). The test file records the five-step MUTATION procedure instead.
Reachable and pinned: the expression-position message (replacing a LYING "Unbound
variable") and that it is PER-COMMAND.

Commits: `cbd8d1a7` (the four misses + the over-reach) · `8c4faee2` (condition (c)).
Gate: suite **0 failures / 478 files** (count nondeterministic per the standing
rule) · battery 312 → **321** · acceptance 52/52 + 89/89 + 6/6 + 29/29 + 28/28 ·
**corpus A/B ZERO diffs across 163 files against the PRE-MINT baseline**, both
legs on ONE `git archive` snapshot · row matrix identical to baseline in every
column.

<a id="p4c-2-inverted"></a>

##### §5.P4c-2 — THE INVERTED DEFAULT (owner ruling, `68cdaae7`)  ✅

The verify's three BLOCKING findings expanded to **seven measured regressions**
(comma false-mint · `Pi` · `Sigma` · `capability` · bracket-`let` · spliced-`let`
after `->` · `let` on a def RHS), each A/B'd against a real `182f1678` build.
Rather than a tenth round of enumeration, the owner ruled **option (2) — invert
the default**, plus the comma fix "and any other enumerations we can identify".

**THE RULING'S SHAPE.** The post-pass used to unwrap only inside RECOGNIZED
binder regions, so a missed head meant the sentinel survived into a binder
position and **broke working code**. Inverted, a miss can only mean *"broadcast
does not fire here yet"* — the annotation still works, the broadcast reports
loudly. Errors may become meanings, never the reverse: the same monotonicity
§9's strict-first waypoint is ratified on.

**⭐ THE ENABLE-SET IS EXPLICIT AND EMPTY.** `broadcast-enabled-contexts` = `'()`.
Not an omission — the sentinel has no consumer until P4c-3, so preserving it
anywhere buys nothing and costs a SPELLING-DEPENDENT surface. The moderate form
was built first and measured, and had exactly that defect: the sentinel survived
in a FLAT `def y := users:name` but not in an indented body — an accident of
recursion order, not a decision. Made uniform instead.

With the set empty the mint is **provably equivalent to not minting**, which is
what turns "regression-free" into a checkable property:
- the 15-probe matrix is **byte-identical** to a real `182f1678` build;
- corpus A/B **ZERO diffs / 163 files** against the PRE-MINT baseline;
- the eight "deliberate flips" in `test-parse-reader.rkt` **flipped BACK** to
  their pre-mint datums — a mechanical demonstration that **mint ∘ unwrap =
  identity** on every one of those shapes.

**⚠ THE ENUMERATION DOES NOT VANISH — IT MOVES.** Recognized heads still own
their bodies, so the table becomes *"where broadcast SURVIVES"*. Only the failure
DIRECTION changed. That was the whole of the ruling and it should not be
overclaimed as retiring the table.

**Other enumerations fixed, not merely listed**: the COMMA closed as a **class**
(`adjacent-to-base?` asks about the physically preceding token while the base it
means is the last thing in `result` — they disagree for every token grouping
consumes WITHOUT EMITTING; the quote decline was written for exactly this and its
own comment named the shape) · **region heads are not always form heads** (the
identical blindness already fixed for param heads) · the bracket bindings group ·
`unwrap-bcast-step`'s unguarded `cadr` (a whole-file abort, THIRD instance of
that shape in this track). The `capability`/`Pi`/`Sigma`/`DSend`/`DRecv` rows
were deliberately **not** added — the inverted default covers them and every
future form, which is the point. The guard the verify proved **dead by
construction** was deleted: a dead tripwire reads as coverage.

**Honest consequence**: the guided `bcast-step` / `bcast-step-binder` messages
are now UNREACHABLE — live code behind an empty enable-set, reachable at P4c-3
with the first enabled context. Kept rather than reverted; their pins restaged to
assert today's inert behaviour so nothing claims coverage it lacks.

**Still owed at P4c-3** (named so they are not rediscovered): the over-reach
survivors the verify found in property clauses / bare-`fn` / type unions become
live the moment a context is enabled · `parse-param-names-for` is an unhardened
binder consumer · the `*`/`^` swallowing hazard · **the blind spot nobody has
tested: the `.pnet` module-cache round-trip and the REPL/LSP reader entries** —
every probe in this arc used exactly two doors.

Gate: suite **0 failures / 478 files** · battery **322** · acceptance 52/52 +
89/89 + 6/6 + 29/29 + 28/28 · A/B ZERO/163 · matrix identical in all 15 columns.

Status: ✅ **P4c-2 COMPLETE** (`b1399016` · `cbd8d1a7` · `8c4faee2` · `68cdaae7`).

<a id="p4c-3"></a>

##### §5.P4c-3 — The `(@bcast step)` step kind  (close 2026-08-02)

**Deliverable: the KIND and its arms.** `(@bcast step)` added to
`select-step-kind`'s closed union and armed across the `ADDING A KIND` recipe's
THIRTEEN sites (`3b998aa8`). The recipe **held with no correction** — the first
enumeration in this arc to survive a new member intact, which is worth recording
precisely because the arc's other lesson is the opposite. The NAME/KEY walks
DELEGATE to the wrapped step (ω changes container ARITY, not key behaviour); the
VALUE walks emit a guided NOT-YET naming P4c-4, because delegating there would
project off the CONTAINER instead of broadcasting over it.

Prerequisites landed first per owner ruling: `8fa30336` (DEFERRED 32 over-reach
survivors) · `8c95d4ae` (DEFERRED 36 RESOLVED). Then `f6310c27`, the `[else]`
split — the inversion had written `(scan-for-param-heads (map unwrap-binders-deep
kids))`, stripping deeply FIRST, so the scan was DEAD WORK and the eight
param-head forms would have been blanket-stripped at the first grant.

##### ⭐ THE ENABLE-SET MOVES TO P4c-4 (owner ruling 2026-08-02)

The sub-phase opened on the question "what fills `broadcast-enabled-contexts`" —
per-FORM or per-POSITION granting, and is preserve TRANSITIVE. **The question is
not answerable as posed, and three MEASURED facts say why.**

1. **The enable-set is a boolean wearing a list's clothes.** Exactly three
   production references — the definition (parse-reader.rkt:2845), the `(pair?
   …)` predicate (:2847), and ONE consultation (:3007). **Nothing anywhere tests
   membership.** So "which contexts" is not a choice the code can express; any
   non-empty value flips the same global switch. And because that arm is FIRST
   in the `cond`, the first grant switches on ~80 lines of never-executed code
   at once — arms 2–5 plus ten helpers, including all three `8fa30336` fixes.
2. **Granting anything breaks the position broadcast is actually written in.**
   Matched A/B via the recorded MUTATION procedure (force non-empty, rebuild,
   probe, revert):

   | spelling | empty (HEAD) | non-empty |
   |---|---|---|
   | `def flat := users:name` | "Could not infer type" | guided not-yet — **survives** |
   | `defn armed \| 0 -> users:name` | generic param error | guided not-yet — **survives** |
   | `defn body-app [q] [one users:name]` | "Too many arguments" | **unchanged — STRIPPED** |

   The third is DEFERRED 32's open half. Head `one` is unknown to the `cond`
   AND to the scanner, so `recognized? = #f` and `[else]` blanket-strips
   (:3067-3069). ⚠ **That symptom is OVER-DETERMINED** — the strip and the
   missing `access-sentinel?` membership both produce it. The strip is confirmed
   by the code path, not by the probe alone.
3. **Flipping the unknown-head default to PRESERVE is refuted from the corpus.**
   `[add ?x:Nat ?y:Nat] = 5N` (examples/2026-03-09-fc-trait-rel-dom.prologos:141,
   runs 0 errors today) is a live BINDER position under an unknown head.
   `[one users:name]` is an EXPRESSION position under an unknown head. Both are
   `[SYMBOL item item]`. **The head-keyed walk cannot separate the two
   populations in either direction, and the corpus contains live examples of
   both.**

   ⚠ **REFUTED 2026-08-02 — this counter-example DOES NOT EXIST.** `?x:Nat` is glued into ONE TOKEN by `recognize-narrow-var-annot`, so the trigger can never fire on it; `[add ?x:Nat ?y:Nat] = 5N` mints NOTHING, under any grant. The claim was inferred from "this line runs 0 errors today" without checking whether it MINTS — and the tree's own comment said so. **PRESERVE has ZERO measured corpus regressions** (795-file census). See D4 `#q-u18`.

**And there is nothing behind the switch yet.** `make-select-bcast` has ZERO
production callers (syntax.rkt:177 provide + :907 definition only) — no producer
bridge exists, and the parser's `bcast-step` arm emits the not-yet error instead
of constructing (parser.rkt:863). `$bcast-step` is absent from `access-sentinel?`
(macros.rkt:6128-6132), so a survivor would not even fuse onto its base. **No
grant can make broadcast work in any position today; it can only change which
not-yet error you get, and break application position on the way.**

**Ruling**: P4c-3 closes on the kind + its arms, enable-set still `'()`. The set
and its five prerequisites move to P4c-4, where the consumer lives. This keeps
the mint equivalent-to-not-minting through the close, and means the unknown-head
default gets ruled against a WORKING consumer rather than against a not-yet
error — spending the ruling on a switch with something behind it.

⚠ **On "provably ≡ not minting"** (P4c-2's close): what holds BY CONSTRUCTION is
COUNT-PRESERVATION. Full equivalence rests on the shape-sensitive classifiers
being invariant, which is established EMPIRICALLY (A/B ZERO/163 + the 15-probe
matrix + the eight flipped-back pins). **A measured equivalence with a named
limit, not a proof** — and the limit is precisely the one the P4c-2 verify
already paid for: the corpus DOES carry fused spellings (`defn square [x:Int]`
at lib/examples/foray.prologos:116, `defr bool [?p:Int]` at :891, `let x:Int 4`
at examples/2026-07-31-let-blocks.prologos:185, and more), but it carries no
instance of the particular COMBINATION that broke — a private-suffix head paired
with a fused annotation — which is why that regression was A/B-invisible AND
invisible to all 18 reader-level pins. Corpus coverage is per-COMBINATION, not
per-feature; do not read "the corpus exercises fused annotations" as cover.
Related: `absorb-let-siblings`, `classify-let-block` and `mark-let-goal-rhs`
ALREADY SEE minted sentinels at HEAD — they run BEFORE `apply-binder-unwrap` in
the same visit (parse-reader.rkt:3220-3225). The empty enable-set protects the
pass's OUTPUT, not its internals.

<a id="p4c-3a"></a>

##### §5.P4c-3a — the FOURTEENTH site: `select-step-name` was ω-blind

D4's partition names "the two shape-test helpers OUTSIDE the recipe". Only
`select-step-cont` was covered — and covered by unwrapping at its call sites, not
in the helper. `select-step-name` was missed, and the recipe structurally could
not catch it: the recipe enumerates `case (select-step-kind …)` dispatchers and
this is an `if` over ONE predicate.

**The defect is an ASYMMETRY, which is why no P4c-3 pin caught it.** The branch
CLASSIFIER `select-branch-collapse` sees through the wrapper, so a `users:k^-`
branch sorts correctly as collapsing — and then the LABEL is taken from the RAW
leaf. Measured before the fix:

```
(select-branch-top-keys (list (make-select-bcast '(@key k collapse))))
  ⇒ ((@bcast (@key k collapse)))     -- a LIST, against a contract of
                                        "a key SYMBOL … or #f"
```

Three call sites share `[else (select-step-name (car (reverse b)))]` inside a
`col`-guarded branch: `select-branch-top-keys` (syntax.rkt), `branch-entries`
(reduction.rkt), `select-branch-entries` (typing-core.rkt). The latter two are
**MASKED** today — but for DIFFERENT reasons, and only one is evaluation order:
reduction computes the label first and discards it when `walk-to-leaf` raises,
while typing-core computes it INSIDE the continuation, which the raise precedes.
Both go live when P4c-4 removes the raise. **syntax.rkt's is live now**:
`select-branch-top-keys` is a pure STATIC key computation feeding the parser's
OUTPUT-key duplicate check and its L4 sort-homogeneity check, with nothing to
raise first, and a non-symbol component can never match under the duplicate
check's `eq?` — so duplicates would go UNDETECTED. Silent, the one outcome the
P4a totality dispatcher exists to prevent.

Fixed in the HELPER, not at the three call sites: a third copy of the unwrap is
the F1b.7g drift class this vocabulary has already paid for. Delegation is
recursive, matching `select-step-output-name`'s `[(bcast)]` arm.

⚠ **NO `syntax.rkt` LINE NUMBERS IN THIS SECTION, DELIBERATELY.** The first cut
of both the section and the in-code comment cited that file's coordinates, and
the comment's own +59 lines invalidated every one of them — the section's map
pointed into the middle of the comment that made it stale. That is the exact
class `19ab78a9` had fixed ONE COMMIT EARLIER. Anchor on NAMES; `grep` is the
index. (Caught by the adversarial verify, which is also how the `parser.rkt`
sibling below was found.)

<a id="p4c-3a-cont"></a>

##### §5.P4c-3a (cont.) — and the FIFTEENTH, found by my own false comment

Writing the fix, I asserted above `select-step-cont` that "every one of this
helper's call sites already unwraps, so it correctly stays ω-blind." **Checking
that assertion instead of shipping it refuted it.** `parser.rkt`'s
`^`-in-path-access refusal did not unwrap, and `select-key-step?` is false for a
wrapper, so the `ormap` silently missed a `^` inside one. Measured on the exact
lambda that line carried:

```
(@key k dissolve)            ⇒ dissolve   -- refusal fires
(@bcast (@key k dissolve))   ⇒ #f         -- refusal does NOT fire
```

That is the identical hole `branch-problem` documents **and unwraps for**, at a
sibling site in the same file that did not. **D4 had already booked this hazard
independently** at §4310 (`:name^alias` "slips past" the `^`-refusal) — so the
comment asserted completeness against a hazard its own design doc had recorded.

**⭐ AND THE FIX CHANGED SHAPE UNDER THE ADVERSARIAL VERIFY, which is the part
worth keeping.** My first cut kept `select-step-cont` ω-BLIND and hand-copied the
unwrap into the parser, justified as: its callers "ask SEVERAL questions (kind
AND cont)", so the unwrap belongs with the classification. The verify's sharpest
finding is that **this justification is false at precisely the site that received
the copy** — the refusal asks ONE question, and with a transparent accessor its
whole lambda collapses back to a bare `(ormap select-step-cont …)`. Two further
facts settled it: the enumeration in my comment said FIVE call sites and there
are **NINE**; and transparency is a measured NO-OP at the other eight (each has
already unwrapped and is looking at a `caret` step, or sits behind a `memq` guard
excluding `bcast`). So: **both accessors are now ω-transparent**, the hand-copy
is gone, and the standing obligation — which had already been sprung once — is
removed rather than pinned. My first cut had literally pinned the blindness as
INTENDED, which would have made the trap permanent and turned removing it into a
test failure.

Two more verify findings, both acted on: the fifteenth-site pin as first written
**defined a local COPY of the parser's predicate**, so reverting the production
fix left it green — a dead tripwire, the very thing P4c-2's close had already
deleted one instance of. It now exercises the shipped helper (checked: the
shipped and old-blind definitions disagree on the pinned input). And the
DEFERRED-39 sweep, which that item ASKED FOR and I had not run, has now been run
— it found **two more ω-blind sites** (`parser.rkt:1170`, `:1212`), both silent
and diagnostic-degrading, **deliberately left unfixed because no probe I wrote
reaches either one**; fixing a diagnostic that cannot be gated is the failure
mode, not the fix. Booked with mechanism + fix shape in DEFERRED 39, plus
DEFERRED 40 for `select-step-name`'s remaining non-totality (`(@ord N)` and
`(@sub …)` still return LISTS against the same contract — pre-existing, and
raising on `sub` could break a live guarded path, so it needs measurement).

⚠ **THE GENERALIZABLE POINT, and it is the one worth carrying forward.** The
`ADDING A KIND` recipe enumerates `case (select-step-kind …)` dispatchers, so it
structurally **cannot see** helpers shaped as an `if`/`and` over ONE predicate.
That is the same blindness-class the recipe's own header records for its first
cut (open-coded shape tests; `and`/`if`-shaped dispatchers) — so the recipe's
"held with no correction needed" is true *of the thirteen* and was never a claim
about the two helpers D4 named outside it. One of those two was covered, one was
not, and a fifteenth site nobody had named shared the defect. DEFERRED 39 books
the sweep BY SHAPE. The honest revision of the P4c-3 headline: the recipe held;
the boundary around the recipe did not.

Gate: suite **0 failures** · battery **325 → 328** · acceptance 52/52 + 89/89 +
6/6 + 29/29 + 28/28 (all matching the recorded baseline) · the five `^`-refusal
spellings re-probed end-to-end (all refused; plain access and `m{foo^alias}`
still work, so the added unwrap did not make the refusal blanket).

Status: ✅ **P4c-3 COMPLETE**. Status: ⬜ P4c-4..5.

<a id="p4c-4"></a>

##### §5.P4c-4 — PVec broadcast + the enable-set  (mini-design + mini-audit, opened 2026-08-02)

**Grounding**: audit `wf_b5bc52c5-bfd` (5 facets + completeness critic @
`c3bf0c63`, 6 agents / 1.13M tokens). Every load-bearing claim below was
**R-lens-verified on the main thread**.

**⚠ THE SLICE ORDER I FIRST RECOMMENDED WAS BACKWARDS, and grounding caught it.**
I proposed "fold membership + producer bridge first, so the unknown-head question
becomes decidable against a working consumer." Neither can be **observed**: with
the enable-set empty, `apply-binder-unwrap`'s first arm strips every sentinel in
every position, so nothing reaches the parser's `bcast-step` arm. Measured — five
surface spellings (`users:name`, `def a := …`, `[…]`, map-literal value, `|>`)
plus the literal internal head `($bcast-step :name)`: **ZERO occurrences** of the
guided not-yet message; the literal head yields `:name : Keyword`. So the
**TEST SEAM is a prerequisite, not a successor** — today the only validation
route is source mutation on a scratch build, which is precisely what let three
enumeration gaps through this arc.

**THE SLICE IS AT LEAST FOUR SITES, NOT TWO.** `macros.rkt:6125-6127` states the
obligation as three (a datum-level predicate + the `access-sentinel?` entry + the
fold arm), and `segment-select-items` needs its own arm or an unarmed
`($bcast-step …)` lands on its `[else]` and emits a plausible-but-wrong
diagnostic (`parser.rkt:1252-1255`).

**Verified about the fold**: `access-sentinel?` has exactly ONE production
consumer — the gate at `macros.rkt:6195` — and no seat carries its own member
list, so Q_U16's "inherits all four seats for free" **is true at the predicate
layer**. All four seat coordinates verify unchanged. ⚠ Two corrections: **all
FOUR seats run inside preparse** (`parse-reader.rkt:2769` says "two of which" —
third drift in that same comment block, in the SAFE direction, since it
strengthens Q_U16); and seat `:2714` is **re-entered FROM the parser** via
`parse-type-segment`, so "before the parser exists" is false of every
*invocation* though the reader post-pass still precedes it. **The fold arm
inherits a FIXPOINT OBLIGATION**: its emitted datum must NOT be sentinel-headed,
or `preparse-expand-subforms` re-enters and swallows one LEFT sibling per pass —
the P1b-iii bug that silently DROPPED a `defn` clause at zero errors.

**DEFERRED 39's two ω-blind sites are NOT reachable from the headline case** —
both need a multi-item payload and `$select-path` mints exactly one field per
level, so they go live only for a BLOCK-position broadcast. Whether they are in
scope depends on whether this slice lights up block position.

<a id="p4c-4-merge"></a>

###### ⭐ THE DUAL-SPINE MERGE — absent from every prior enumeration

Prologos runs TWO parsers and `merge-form` ends `[else tree-surf]`
(`driver.rkt:2503`, commented *"tree parser wins for user forms"*). What protects
every SIBLING selection surface is that it is deliberately **errored** on the tree
spine (`tree-parser.rkt:147` `select-brace-group`, `:177` `dot-access`), and
errored surfs are filtered out of `tree-by-line` (`#:when (not (prologos-error?
s))`, `:2473`), so preparse becomes authoritative. That file states the hazard
verbatim: *"a missing arm lets a garbage surf BEAT preparse's."*

**`$bcast-step` mints NO TAG, so it has no tag arm and that protection is
STRUCTURALLY UNAVAILABLE to it.** `same-form-type?` compares the OUTER form
(`surf-def` vs `surf-def`), not the body — so a `def q := users:name` whose tree
body is a garbage application would fall to `[else tree-surf]` and win.

**And it is defused today by a plain defect, not by design.** `loc->line`
(`driver.rkt:2443`) takes `(cadr loc)` for any list ≥2; tree NODES carry
`(line col start end)` (⇒ COL) and tree TOKENS carry `(0 0 start end)` (⇒ 0),
while preparse carries srcloc STRUCTS (⇒ real line). The keys are on different
scales, the lookup misses, preparse wins. **The broadcast is protected by
accident**, and the day that is corrected every latent tree surf goes live at
once. Filed OUT OF BAND with the blast radius deliberately unmeasured:
`docs/tracking/2026-08-02_LOC_TO_LINE_MERGE_DEFECT.md` (`388af899`).

~~**Recorded assumption of the producer bridge**: if that fix lands, the broadcast
needs its own tree-spine protection in the same change.~~

✅ **DISCHARGED 2026-08-02, and in the favourable direction — the assumption is
moot because THE TREE LEG IS GONE.** The out-of-band investigation this note
spawned (`388af899` → the arc merged at `1d23600e`) did not fix the key: it
measured that fixing the key makes things **worse**, and removed the leg instead
(`2d7813ef`). `merge-form`, `tree-by-line` and `loc->line` no longer exist in
`driver.rkt`. Verified at `0ca22343`: the only remaining mention is a historical
comment recording the removal.

**Three findings from that arc that this design should absorb**, because two of
them correct things recorded above:

1. **There was a THIRD defect, and it inverts the fix I proposed.** The two spines
   number lines on **different bases** — tree 0-based, preparse 1-based. So the
   arm-swap "minimal fix" in the spawned note's §3 would have paired form N's
   preparse surf with form N+1's tree surf: **176 of 242 hits mispaired (73%)**,
   and end-to-end `def a := 1` became `ERROR: Unbound variable`. My suggested fix
   would have shipped a silent wrong-answer bug. It was in nobody's enumeration —
   not the note's, not the P4c-4 mini-audit's, not five grounding facets'.
2. **The tree spine had won ZERO forms, ever.** `[else tree-surf]` never once
   fired in the life of that code. And correcting the key made the corpus
   REGRESS — errors 359 → 724 across 35 files with **not one improvement**, two
   clean files lost to whole-file aborts, 32 test files failing, from **14
   distinct defects across 4 layers**.
3. **The census settled what the merge even WAS**: the tree spine's datum path
   feeds `parse-datum`, *the same parser preparse uses*. It never adjudicated
   between two parsers — it compared one parser against itself across two
   READERS. So there was never a second opinion for the broadcast to lose to.

**Consequence for P4c-4b**: the producer bridge needs no tree-spine protection,
no tag, and no `merge-form` exception arm. That whole branch of the slice is
deleted rather than deferred.

⚠ **Carry the METHOD lesson, not just the outcome**: an error-COUNT gate could
not see the two whole-file aborts, and a full-output census found six value-level
flips with the count unchanged (`"localhost" : String` → `<error> : String`).
**Gate corpus work on FULL OUTPUT, never on error counts** — which is what
`pipeline.md` already says about whole-file aborts, now with a second instance.

**Mantra check, honestly**: this is reader/parser-layer work and the parse layer
installs **ZERO** propagators. "On-network" is not satisfied and cannot be by this
slice — it is off-network scaffolding whose chartered retirement is **PPN 4D**
(prerequisite-blocked on 4C + PM Track 12). Named rather than rationalized.

**Drift risks named at the open** (checkpoints for the mid-flight principles
challenge): the "four seats for free" claim (assume short until each seat's own
code is read — it held, but only at the predicate layer); `$bcast-step` has no
`pnet-serialize.rkt` registration and DEFERRED 36's ✅ is scoped to the empty
enable-set, so caching goes live with the first grant; scope creep from the
enable-set's MECHANISM into its POLICY (the unknown-head ruling); the `*`/`^`
swallow hazard, still unowned.

<a id="p4c-4b"></a>

###### §5.P4c-4b — the fold arm + the producer bridge + the not-yet CHANNEL  ✅ `6b22515d`

**The chain closes.** Reader PRESERVES (P4c-4a's grant) → the fold FUSES onto the
base → the parser CONSTRUCTS `(@bcast step)` → typing REFUSES through the failure
slot. Measured with a `def` grant:

```
def q := users:name   ⇒ broadcast `:name` — the ω value semantics land at P4c-4c…
def after := 42       ⇒ after : Int defined.       ← THE POINT
```

**⭐ THE CHANNEL FIX, WITHOUT WHICH THIS SLICE SHIPS A WHOLE-FILE ABORT.**
`select-bcast-not-yet` raises a raw `error`; `process-command/solve-guard` catches
ONLY `exn:prologos-solve`, deliberately. Unreachable before now — **the producer
bridge is exactly what reaches it.** Root cause: TWO PROPOSITIONS SHARING ONE
CHANNEL — *the compiler is broken* (`select-step-kind-unhandled`, raise is RIGHT)
and *the user wrote something unbuilt* (raise is WRONG). Split: typing returns
`(values #f (select-fail 'bcast-not-yet …))` through the slot these walks ALREADY
thread; reduction KEEPS its raise, because arriving at the value layer after
typing refused IS an invariant violation. Two arms, two questions.
⚠ **This corrects a claim I made to the owner** — that an error value would be
"invasive and need threading". It was not; the threading was already there. The
principled fix and the cheap fix were the same fix.

**The six parts.** `bcast-step?` + `$bcast-step` into `access-sentinel?` (the
P4c-2 deliverable that never landed under a ✅ — DEFERRED 37; it read as closed
because `broadcast-access?` there is the RETIRED `$broadcast-access`) · the fold
arm, the `$dot-access` arm VERBATIM except the payload rides WHOLE, so the emitted
head is `$select-path` and the **fixpoint obligation holds by construction** · the
`segment-select-items` arm + the PRODUCER BRIDGE (`make-select-bcast` had ZERO
production callers until this import).

⚠ **My first cut of the parser arm was WRONG and a probe caught it.**
`$select-path` consumes the SUBJECT itself and passes only `(cdr args)`, so for
`users:name` the ω step arrives FIRST with no `cur`. I treated that as
branch-initial and it refused the headline spelling with "needs a preceding
subject". `cur = #f` now STARTS a branch, as `plain-key?` does. W2's
branch-initial refusal is a BLOCK rule, and the mint cannot produce one there
anyway (it requires byte-adjacency to a base).

**The payload asymmetry — three sub-cases, two of them silent.** `$bcast-step`
carries the token VERBATIM so its payload is COLON-LEADING, where `$dot-access`
carries a bare symbol. Stripping and handing it to `plain-key?` is silently wrong
twice: `users:0` would be a NOMINAL key named `0` (Q_U16b rules it an ORDINAL —
now the number), and `users:tags*` would be a field LITERALLY NAMED `tags*`
(`ident-continue?` admits `*`, so it arrives as ONE token — now a guided
refusal). `users:name^alias` is the safe one: it routes to the ONE splitter.

**Riders.** The four "a wrapper never heads a branch" comments CORRECTED, polarity
inverted — the claim conflated a BLOCK surface rule (`x{:name}`) with a
representation invariant about a one-step `'path` branch, and three of the four
justified an arm by it. The `.pnet` gate item DROPPED (`expr-path` IS registered).

Gate: suite **9831 / 482 / 0** · battery 336 → **340** · acceptance 52/52 + 89/89
+ 6/6 + 29/29 + 28/28 · **corpus A/B: ZERO semantic diffs.**

**The A/B, and how it was scoped** — recorded because the scoping is the
interesting part. A full 139-file run was started and ABANDONED (≈40 s/file × 2
legs ⇒ hours). It was re-scoped to the **12 files that can possibly MINT** — an
`ident`/`)`/`]`/`}` byte-adjacent to `:` — because those are the only files where
`access-sentinel?`'s new member or the fold arm can fire. That is targeting, not
narrowing: for every other file the new predicate changes an `or`-chain's cost
and not its result. Both legs read ONE `git archive` snapshot (so the owner's
dirty tree cannot masquerade as a code delta) and the baseline was
**worktree-pinned** at `6b22515d^`; diffed on **FULL OUTPUT**, never error counts.

Raw: 4 of 12 differed. All four were internal-counter drift (`?meta2472` vs
`?meta2086`) — and the offset was a CONSTANT 386, which is the tell for a
startup/tree-state difference rather than a per-file one. **Discriminated rather
than assumed**: a control file that CANNOT mint shows the same drift, so it is
not the fold. Normalizing counters leaves **ZERO** semantic diffs across all 12,
the control **IDENTICAL**, and one residual that is the `run-file.rkt`
FILESYSTEM PATH inside a stack trace — worktree vs main checkout, an artifact of
the method itself.

⚠ **Two false greens of mine, both from grepping a keyword instead of counting
the outcome**: a module-load `unbound identifier` is not a `FAILURE`, and rackunit
reports an arity mismatch as `ERROR`. The batch runner's count caught both. Grep
the outcome, not a word.

Status: ✅ **P4c-4b COMPLETE**. Next: **P4c-4c** — the ω VALUE semantics (PVec
broadcast + the L1/extent law pins), which is what the not-yet now names.

<a id="p4c-4a"></a>

###### §5.P4c-4a — the test seam + per-context dispatch  ✅ `f31237fd`

`broadcast-enabled-contexts` was an unexported `define` and
`broadcast-preservation-active?` was `(pair? …)` — a boolean wearing a list's
clothes. Now a **guarded parameter**, exported, with the predicate testing
**membership keyed on the node's own head** (via `binder-head-base`, so the
eleven private-suffix spellings cannot drift). A grant scopes to the form it
names; the default stays empty, so production behaviour is byte-identical —
proven, not merely tested: `(memq X '())` is #f for every X and
`binder-head-base` is total and effect-free.

**The adversarial verify refuted TWO of my claims and found a real defect.**

1. **No guard**, admitting the whole-file-abort class: this parameter is set BY
   HAND from tests, so dropping the list is the natural typo, and
   `(parameterize ([… 'def]) …)` raised `memq: not a proper list` at READ time
   outside any per-command handler. **Fourth instance of that shape in this
   track**, with the first three documented one screen away. Guarding at the
   parameterize makes the membership test total by CONSTRUCTION.
2. **My totality comment was FALSE** — it argued from "`(memq #f …)` is #f for
   every list", but `(memq #f (list #f))` is `(#f)`, so a `'(#f)` grant would
   have granted every group-headed node.
3. **My scoping story was HALF TOLD**, and the missing half is the operative one.
   I documented only that an outer grant cannot reach INWARD. Outward runs the
   other way: an **ungranted ancestor destroys what a granted descendant
   preserved**, because the not-granted arm's `unwrap-binders-deep` recurses
   through already-visited sub-groups. So the rule is a **CHAIN** — node granted,
   every ancestor granted, and each ancestor's rule leaving that position alone.
   Pre-existing (the old global switch stripped these identically) but
   undocumented and untested, **and it is what decides whether P4c-4b's first
   real grant works.** Now documented at the definition site and pinned.
4. **"Mechanism only" was too strong.** The `[else]` arm's CODE is untouched; its
   REACHABILITY is not — previously every node reached the cond once anything was
   granted, now only granted heads do. Production is unaffected (default empty),
   so the honest claim is "**no production behaviour changes**", not "policy is
   untouched".

**DEFERRED 32's open half stays untouched and undecided, by design.** A pin
caught me encoding a wish about it: I asserted granting the INNER head `g` would
preserve inside `[g users:name]`; it does not, because `g` is unknown and the
unknown-head arm strips regardless. The failure was correct behaviour, and it
re-confirms P4c-3's measurement from a second direction — now by a shippable test
rather than a mutation.

**Perf, measured** (the predicate runs once per node): **+45 ns/call** (50.7 vs
5.9); ~681 calls on a 1164-line file against 139 ms reader wall ⇒ **~31 µs,
0.02%**. A 200-entry nonsense grant inflating `memq` ~40× is within noise across
three interleaved rounds — so suite wall movement is ambient, not this.

**Lint**: baselined by hand with rationale. **NOT** added to `test-support.rkt`'s
parameterize blocks despite `pipeline.md`'s checklist — five of those six blocks
are PER-RUN helpers, so registering it there would clear the grant inside the
very helpers a test uses to exercise it. Not `--save-baseline`d either, since
that would silently accept two parameters that are not mine (DEFERRED 41).

**Mutation-verified**: reverting to the old global `pair?` turns **2** pins red.
Said plainly because the first draft turned only ONE red and had to be
strengthened — and because at assertion granularity that is 2 of 12, i.e. four of
the six original test-cases are regression ANCHORS, not discriminators.

Gate: suite **9807 / 479 / 0** · battery 328 → **336** · acceptance 52/52 + 89/89
+ 6/6 + 29/29 + 28/28.

Status: ✅ **P4c-4a COMPLETE**. Next: **P4c-4b** — `access-sentinel?` membership +
the fold arm (with its FIXPOINT obligation: the emitted datum must not be
sentinel-headed) + the producer bridge + the `segment-select-items` arm, carrying
the [dual-spine merge assumption](#p4c-4-merge).

<a id="p4c-4c"></a>

##### §5.P4c-4c — the ω VALUE semantics  (RE-SCOPED 2026-08-02; owner-assented)

**⭐ THE SLICE AS ORIGINALLY SCOPED CANNOT LAND ITS OWN DELIVERABLES.** Three
independent READER facts each suffice to block it, all re-verified on the main
thread at `17086a09` (the critic found them; I re-ran its probes rather than
accept them):

1. **A bare top-level ω is STRIPPED under EVERY grant.** `users:name` →
   `((users :name))` even granting its own head, even under a broad grant — the
   unknown-head policy (DEFERRED 32's open half). **Every ω line in the
   acceptance file is a bare top-level command.**
2. **`:{…}` DOES NOT MINT** — `users:{t r}` reads as `users : ($select-brace t r)`,
   because `bcast-step-trigger?` gates on token TYPE and a lone `:` before an
   opener is neither `keyword` nor `colon-annotation`. That kills `quests:{t r}`
   **and both members of the §3.2.1 extent pair** — all named in the old scope.
3. **`broadcast-enabled-contexts` has ZERO production setters**, so `process-file`
   runs at default `'()` regardless of anything this slice does.

Of the four originally-named deliverables, only the L1 fusion pin has a mintable
line — and `users:0:userName` bare is stripped too, so even that needs `def`
position plus a grant reaching `process-file`.

**⚠ TWO CARRIER FACTS I ASSERTED WERE WRONG**, and each would have produced bad
code: `expr-hset` has **no arm in any of the four dispatchers** — Set is not a
selection carrier at all today, true of the struct and false of the machinery
(I would have written an arm that can never fire); and `expr-Record` is
**TYPE-only** — a het tuple's runtime value is an `expr-rrb` (I would have
mis-keyed the value arm).

**RE-SCOPED DELIVERABLE — PVec value semantics only**, which is what the scope
line always said and what the not-yet message promises a user:
- the THREE typing arms (`walk-to-leaf`, `select-branch-entries`,
  `select-below-field`) — return a TYPE into the `(values x fail)` slot;
- the THREE reduction arms (`walk-to-leaf`, `branch-entries`, `below-value`) —
  return a VALUE; these have **no failure slot**, escaping via `let/ec return`;
- ⚠ **a FOURTH site the partition did not name**: an `rrb-of`-style container
  guard. `champ-of` and `index-into` are the precedent; there is **no `rrb`
  twin**, and because reduction carries no failure slot a mid-descent
  non-container has no other way to report;
- the L1 fusion + §3.2.1 extent LAWS pinned in the battery in `def` position
  (which mints); their CORPUS lines wait on Q_U18 + the `:{` mint.

**Semantics, from the code**: `xs : [PVec {:name String}]` ⇒ `xs:name` is value
`@["…" …]` (`expr-rrb`) at type `[PVec String]`. Mirror `pvec-map : (A → B) →
PVec A → PVec B` and the `expr-pvec-map` whnf arm. The corpus pins the shape
three lines above the commented target with the explicit `map` spelling.

**⭐ SCOPE WIDENED 2026-08-04 [owner: *"G2 alongside P4c-4c"*] — G2 LANDS HERE.**
The slice is now TWO pieces, and the second is what makes the first observable:

- **(A) the PVec ω value semantics** — the six arms + the `rrb-of` guard above;
- **(B) G2 — retire the enable-set** (`broadcast-enabled-contexts` /
  `broadcast-preservation-active?`), making head-keyed preservation
  UNCONDITIONAL. Rationale + the full argument: [Q_U18](#q-u18)'s G2 block.

**Why together, stated so it is not re-litigated**: the PRESERVE flip is INERT
at the default, because parse-reader's FIRST arm deep-strips any node whose own
head is ungranted. So (A) alone ships value semantics for a surface reachable
only from the battery — the *Validated ≠ Deployed* shape the arc has already
named once. (B) alone ships reachability with nothing to evaluate to. Together
they are the first end-to-end user-visible broadcast.

**⚠ THREE OBLIGATIONS THAT ONLY EXIST BECAUSE (B) IS IN SCOPE**, none of which
prior P4c slices carried:
1. **The corpus A/B becomes load-bearing.** Every earlier slice could lean on
   "default `'()` ⇒ byte-identical"; that argument is gone. Re-derive the
   mintable-file set at HEAD rather than inheriting P4c-4b's 12, diff FULL
   OUTPUT, and carry a CONTROL file that cannot mint to discriminate counter
   drift.
   ⚠⚠ **CORRECTED 2026-08-04, WITHIN THE HOUR, BY MEASUREMENT — this obligation
   as first written produced a FALSE ALL-CLEAR.** It said *"pin BOTH legs to ONE
   `git archive` snapshot (the owner's tree is dirty)"*, inheriting P4c-4b's
   method wholesale. **Snapshot the CODE; run the INPUTS from the WORKING TREE.**
   The reason is specific and fatal: `lib/examples/foray.prologos` is the ONLY
   file G2 changes, and it is **owner WIP — 114 lines committed vs 946 in the
   working tree** (measured). A snapshot-INPUT A/B therefore compares a corpus
   that **does not contain the feature** and reports **ZERO diffs across all 304
   files** — a total false all-clear on the one slice where production behaviour
   actually moves. Measured against a real arm-deleted build, working-tree inputs
   give `304 compared · 1 CHANGED · foray.prologos, 13 of 201 forms`.
   ⚠ The dirty tree is still a hazard — it just moves: report **which side of the
   committed line each diff falls on**, so owner WIP cannot be read as a G2
   effect. Do NOT `git stash`.
   ⚠ And the **"12 mintable files" figure is NOT REPRODUCIBLE from its stated
   criterion** — the recorded rule ("an `ident`/`)`/`]`/`}` byte-adjacent to
   `:`") selects **161 of 163** files literally, **143** with comments stripped,
   and the true token-level predicate selects **3**. Whatever produced 12 was
   neither. Re-derive; do not inherit the number OR the rule.
2. **The battery inverts.** P4c-4a's pins were mutation-verified AGAINST the
   grant seam and one is named *"the flip is INERT AT DEFAULT"*. Enumerate the
   pins that go RED **and, separately, the pins that go VACUOUS** — the second
   class is the dangerous one — before touching the parameter.
3. **The accepted PRESERVE residual goes live.** Macro pattern variables
   (`pattern-var?` needs no sigil) were ruled an acceptable residual on the
   grounds of zero in-tree instances *and* an existing per-command
   `bcast-step-binder` guided error. Under G2 that arm is reachable in
   production for the first time — verify the ERROR CHANNEL, not just the
   message. Four whole-file aborts have shipped in this track by that exact gap.

<a id="p4c-4c-audit"></a>

**⭐ THE MINI-AUDIT — `wf_a24f3e0f-d84`** (7 facets + completeness critic,
HEAD-pinned; 8 agents / 1.66M tokens / 0 errors). It refuted FOUR recorded
facts, one of them written the same hour. **Every load-bearing item below was
re-verified on the main thread**, not adopted from the report.

**⚠⚠ 1. BLOCKING FACT #1 IS DEAD — a bare top-level ω is NOT stripped under
every grant.** Measured on the main thread:

```
default        : ((users :name))
grant '(users) : ((users ($bcast-step :name)))   ← PRESERVES
grant '(def)   : ((users :name))
```

It WAS true at `17086a09`, where the re-scope verified it. **The PRESERVE flip
(`e71ef6b8`) rewrote the `[else]` arm** (`:3210-3212`), and a bare top-level
command's head IS the subject symbol — so granting the subject preserves. The
re-scope generalised from the `'(def)` sub-case, which still strips.
⇒ **Acceptance markers ARE exercisable, and the L1 fusion pin does NOT need
`def` position.** The re-scope was right when written and went stale under the
very flip it was waiting on — *a fact has a timestamp, and this one outlived it
by one commit.*

**⚠⚠ 2. THE PARTITION IS INCOMPLETE — 3+3+1 is not the shape.** Verified:
`expr-PVec` occurs in the ENTIRE select region (700–1200) exactly ONCE, at
`typing-core.rkt:923`. **`select-row-of` has NO PVec arm**, so a PVec subject
falls to the `:758` catch-all `[(not (expr-Record? tm)) … 'subject-other]` —
**the three typing arms have nothing to delegate to.** That is a FOURTH typing
site, which D4 books elsewhere as *"a THIRD dispatcher (subject → elem-type)"*.
Three more the partition never named:
- **`select-below-components`** (`:1149-1152`) reaches site 2 by FALLTHROUGH and
  is the only caller carrying non-empty `seen` from a dissolve splice — so
  changing site 2's return for a bcast head silently changes dissolve splices;
- **the `expr-get-in` / `expr-update-in` family** (reduction `:3579-3581`,
  `:3588-3596`, `:4594-4595`, `:4603-4604`) walks path segments with **ZERO
  step-kind dispatch**. Probed: it returns `expr-error` at **zero errors** — the
  silent-wrong-answer class, not a raise;
- **a THIRD `bcast-step-binder` guard** at `parser.rkt:6382` (`parse-rel-params`)
  that the guard census resting under the residual argument had missed.

**⚠ 3. THE HEADLINE SPELLING REACHES SITE 2, WHOSE PROTOCOL IS DIFFERENT.**
Measured: `users:name` routes to `select-branch-entries` (`:1141`), which returns
a **COMPONENT LIST** (`:984`), not a type — sites 1 and 3 return types. Writing
`(values pvec-type #f)` at `:1141` by analogy with its siblings is the most
likely single way to get this slice wrong.

**⚠⚠ 4. THE PRESERVE RESIDUAL IS SEVEN SHAPES, NOT ONE — AND ONE IS SILENT.**
Measured against a REAL arm-deleted build (not a grant simulation). Leaks:
`[myform x:Int]` (the one the ruling named) · **`defmacro when [$c:Int $b]`** ·
`data Box := mk [x:Int]` · `capability C [x:Int] x` · `def g := [fn m:Int m]` ·
`def x:A:B := 5` · (`deftype` — but see below). Does NOT leak: `defn` · `defn-` ·
`spec` · `def` · `let` · trait methods · match arms · `?x:Nat`.
⭐ **Five are loud. `defmacro when [$c:Int $b] $c` is SILENT** — no diagnostic at
all; the macro registers with `($bcast-step :Int)` INSIDE its pattern.
**Q_U18 accepted the residual explicitly on the grounds that it is "LOUD and
RECOVERABLE" — that argument does not cover this member.** And the design named
the WRONG MECHANISM: it is not `pattern-var?`/unknown-head, it is
`param-group-candidate?` (`:3323-3334`) rejecting any `$`-headed group, and
**`defmacro` is a RECOGNISED head** — so this shape was never in the population
the ruling reasoned about.
✅ **OWNER RULED 2026-08-04: close the `defmacro` leak as part of this slice.**
G2 lands alongside as ruled; the acceptance argument is repaired rather than
re-opened.

**⚠ 5. THE GRANT SEAM CANNOT EXPRESS THE POST-G2 STATE.** `binder-head-base`
answers `#f` for a non-symbol and the parameter guard forbids `#f` in the list,
so **a group-headed node can never be granted** — and a bracketed top-level
command has exactly that shape. Three facets' grant-probes therefore contradicted
each other. ⇒ **Obligation #2 (RED vs VACUOUS pins) CANNOT be discharged through
the seam; it needs a real arm-deletion build.** The P4c-4a chain/totality pins
that read "[same]" under a grant do so as a SEAM ARTIFACT, not as evidence.

**⚠ 6. G2 DOES NOT FULLY DISSOLVE THE CHAIN.** Three deep-strippers survive arm
1's deletion: the `trait` arm (`:3129-3130`), the `$pipe` pattern region
(`:3121-3122`), and `take-param-region`'s implicit/param groups. Any reasoning of
the form *"after G2 nothing strips ancestrally"* is false for those three.

**⚠ 7. SCOPE LEAKAGE IS FORCED, not avoidable by discipline** — named so it can
be pushed back deliberately: `select-row-of`'s missing PVec arm needs a
subject→elem-type dispatcher (a P4d-booked item), and the `rrb-of` guard's ELSE
branch must decide what a NON-PVec container does — and Map (`regions:host`) and
het-tuple (`events:t`) subjects ARRIVE whether or not they are in scope.

**⚠ 8. THE `rrb-of` GUARD MUST REPORT VIA `(return (expr-panic …))`, NEVER
`error`.** With no failure slot the only two exits are the escape (per-command,
file continues) and a raise (whole-file abort). Writing `[else (error …)]`
re-creates exactly the abort P4c-4b removed. Note also `champ-of` and
`index-into` are **NOT twins** (unwrapper vs accessor) and `champ-of`'s message
asserts *"typing admitted the block"* unconditionally, which is FALSE under
`sort='path` — **copy `index-into`'s wording, not `champ-of`'s.**

**✅ CONFIRMED, and it gives the slice an ORACLE rather than a spec to
interpret**: the target semantics already work under the explicit spelling —
`pvec-map [fn [m] m.name] xs` → `@["a" "b"] : [PVec String]`. Mirror arm
`reduction.rkt:3306-3314`. And **the L1 fusion discriminator is the TYPE, not the
value**: naive nesting yields `[PVec [PVec String]]`; fusion must yield
`[PVec String]`, so a pin asserting only the value list does not discriminate.

**STALE COORDINATES CORRECTED** (all re-verified): the sole `let/ec` is
`reduction.rkt:1647`, **not `:1600`** — D4 cited `:1600` TWICE and that line is a
comment · `pvec-from-list` is `parser.rkt:3285-3290`, **not `:2966`** (which is
`surf-get`) · `DEFERRED.md:2986`'s three claims about the parameter are ALL now
false (it is at `:2933`, it IS a `make-parameter`, it IS provided at `:64`).
⚠ **"The four dispatchers"** (used above in the `expr-hset` note) is the number
**this track already refuted once** — D4's own §P4a record says THIRTEEN sites in
FIVE files. The `expr-hset` claim is true; the denominator is not.

**TEST-SURFACE FINDINGS**: `tests/test-parse-reader.rkt` has ~8 assertions that
go RED under G2 with **ZERO code reference to the parameter** — a grep-driven
retirement finds nothing there · the most dangerous VACUOUS case is
`test-path-selection.rkt:3958-3964`, the only standing coverage of
`binder-head-base`'s private-suffix normalization, whose live consumers all
SURVIVE G2 — it must be **re-expressed as a binder-behaviour pin, not deleted** ·
`bcast-e2e`'s subject is a **MAP**, so reusing it for a PVec law pin would pass
for the wrong reason · the battery is at **344 cases / 58 s**, approaching
`testing.md`'s 60 s absolute guidance.

<a id="p4c-4c-close"></a>

##### §5.P4c-4c CLOSE — ✅ COMPLETE 2026-08-05

**Four commits.** `51e260ab` the PVec ω value semantics · `bcdb4083` DEFERRED 43
(the strictness tier follows the unwrap) · `0fd2098c` DEFERRED 50 spun out ·
`ae26f540` **G2 + the preparse seam guard**.

**THE FEATURE ARRIVES**: `xs:name` → `@["a" "b"] : [PVec String]` at the
production default — no grant, no parameter. L1 fusion holds as a THEOREM at
depths 2/3/4 (each ω step consumes one layer and re-wraps one; nothing counts
layers), and the converse holds — `xs:tags` correctly REFUSES to fuse when the
user asked for two layers.

**⭐ THE DEFINING EVENT: the adversarial verify caught a BLOCKING regression that
EVERY gate was blind to.** G2 let `$bcast-step` survive into preparse-CONSUMED
forms (`require`/`ns`/`schema`/`foreign`) whose recognizers raise —
`require [prologos::data::nat:refer [add]]` went from 0 errors to a WHOLE-FILE
ABORT. Fifth instance of `pipeline.md`'s abort class in this track, with the
first four documented one screen away. **Zero corpus sites use a fused directive
keyword**, which is precisely why the suite, all five acceptance files AND the
corpus A/B passed over it; the adjacent population is ~2400 spaced occurrences,
each one deleted space away.

**Owner ruled option B** (guard the seam) over A (enumerate directive heads),
because an enumeration leaves the NEXT sentinel to rediscover the class.

**⚠ B'S REAL COST — the finding worth carrying forward**: converting raises to
VALUES makes previously-inert TEST-HELPER DESIGN load-bearing. 20 assertions
across 9 files changed channel, and two failed for a reason that *could not exist
under a raise*: `functor-for` returns a registry lookup and discards results;
`run-last` returns `(last (run s))` while the refusal lands on the FIRST form.
**Any helper that narrows the result set can now silently swallow a refusal and
go green.** Both fixed; a sweep for other result-discarding helpers is unclaimed,
deliberately not widened into this slice.
⚠ Only the 20 FAILING sites were converted, not all 31 `check-exn` sites in those
files — the other 11 still raise (they fail before the guarded seam), and
converting them would have weakened correct assertions.

**Rulings landed**: [Q_U18](#q-u18)'s G2 half · **DEFERRED 43** (the tier follows
the unwrap — and its own "not reachable in production" rationale was FALSE, which
the verify proved) · **DEFERRED 48 RULED UNIFORM** (the tier is INFERRED, not
written, so per-tier abort would make identical source behave differently on
something invisible in it).

**Gate**: suite **9847 / 482 / 0** · battery **356** · acceptance 52/52 + 89/89 +
6/6 + 29/29 + 28/28 · corpus A/B **5 of 6 identical incl. the control**; `foray`
(owner WIP, the only file with real mint sites) **29 → 21 errors, no value became
an error**.

**⚠ KNOWN PROPERTY OF B, recorded not hidden**: the guard is head-agnostic, so a
compiler-INTERNAL invariant violation during preparse also degrades to a
per-command error. Still fully reported, never silent — but it merges two
propositions into one channel, which this track deliberately SPLIT at P4c-4b.
Re-splitting needs a distinguished internal-error marker that keeps raising.

**⚠ METHOD, for the PIR**: this slice produced **five false claims in comments**
and **three vacuous pins**, every one from writing what I believed the code did
instead of probing first. Most were caught by the adversarial verify; three I
caught myself, only after distrusting the habit. The same error appeared in a
live diagnosis (naming an Emacs lock file as the memory-runaway cause before
testing it — it was not). ONE finding about method, not eight incidents.

**Spun out**: DEFERRED **50** (defmacro fused annotations — chip
`task_204859b9`; PRE-EXISTING, not a G2 leak) · **51** (parenless `&>` loses the
relation) · **52** (goal arity error → silent empty bag).
**Tooling**: `tools/corpus-ab.rkt` — one subprocess per file with wall + memory
caps, encoding the corrected A/B method.

**Status: ✅ P4c-4c COMPLETE.** Next: the `:{` mint (**alone** — it touches
`bcast-step-trigger?`, the ONE predicate both groupers share, so mixing it makes
the A/B un-attributable), then **P4d**.

<a id="p4c-sequencing"></a>

##### §5.P4c — THE SEQUENCING after the P4c-4c re-scope  (owner-assented 2026-08-02)

**Nothing is dropped. The order changes**, because three reader-layer facts gate
the corpus half. Most of the deferred work was ALREADY scheduled by this
document — reading it rather than re-homing by instinct is what surfaced that,
and it corrected a recommendation of mine (I proposed the Q_U9 List refusal for
P4c-4c; Q_U9's own ruling says **"Implementation: P4d"**, twice).

| Deferred piece | Home | Note |
|---|---|---|
| map-generic over Map/keyword-row (`regions:host`) | **P4d** | already scoped |
| het-tuple per-position EXACT (`events:t`) | **P4d** | the 2b heterogeneity split |
| PVec-of-union + `row-meet` | **P4d** | already scoped |
| **Q_U9 List refusal + guided error** | **P4d** | ⚠ NOT P4c-4c — Q_U9 says so itself |
| `quests:t` / `quests:{t r}` corpus lines | ~~P4d~~ **✅ LIVE at P4d-0** | markers 43/44 (`33d83989` + `77259635`) — the solve→PVec spin-out re-fated them upstream; P4d's list shrinks by one |
| `*` flatten (`:diags*`) | **P4e** | P4c-4b's guided refusal is the correct interim |
| `.*` row-splat · disclose `<`/`:<` | **P4e** | already scoped |
| **the `:{…}` reader mint** | **[P4d-0](#p4d-0)** ✅ `77259635` | + 46 (Q_U20) + 55; both extent members in the corpus; **P4d unblocked** |
| **unknown-head policy + first production grant** | **[Q_U18](#q-u18) ✅ RULED** | PRESERVE + **G4** (test-only until P4c-4c). ~~Owed with it: the digit-hole fix~~ — **not a defect**, both spellings already refused. **G2 ✅ RULED 2026-08-04: ALONGSIDE P4c-4c**, not after |
| **`^`-on-broadcast** | **[Q_U19](#q-u19) ✅ RULED 2026-08-07** | **(A) the path-position refusal is RATIFIED** — no key to re-key on a bare ω output; block-position `^` already re-keys and STAYS. ONE guided message unifies the three routes, at P4d's diagnostics slice |

~~**THE CRITICAL PATH** (revised after Q_U18's ruling): the **PRESERVE flip + the
digit-hole fix** (inert at default, testable through the P4c-4a grant seam, so
safe to land early) → **P4c-4c** (PVec value semantics) → **the G4 grant fires**
at/after P4c-4c, and **G2 is re-evaluated there** → the `:{` mint → **P4d**~~

**THE CRITICAL PATH — REVISED 2026-08-04 after the G2 ruling.** The PRESERVE
flip ✅ landed (`e71ef6b8`); the digit-hole fix is **struck** (it was never a
defect). What remains:

~~**P4c-4c + G2 as ONE slice**~~ ✅ **LANDED 2026-08-05** (`ae26f540`) — value
semantics + unconditional preservation + the preparse seam guard; G4 discharged
BY the slice. See [§5.P4c-4c CLOSE](#p4c-4c-close). Remaining:
the `:{` mint (**alone** — it touches
`bcast-step-trigger?`, the one predicate both groupers share, so mixing it makes
the A/B un-attributable) → **P4d** (carriers + the Q_U9 List refusal + the corpus
re-fate, with [Q_U19](#q-u19) ruled) → **P4e** (`*` flatten · `.*` row-splat ·
disclose) → **P4c-5** → **PF** (Q_U17's `Step`/`Cont` ADTs + the `path-segments`
repair) → **P5**.

⚠ The merge of P4c-4c and G2 does NOT re-home anything else. Everything in the
table above keeps its stated home; the one change is that the G4 discharge and
the G2 retirement now happen INSIDE P4c-4c instead of bracketing it.

✅ **Q_U18 IS RULED** — and the "Validated ≠ Deployed" gap it named is now
**SCHEDULED rather than open-ended**: G4 makes P4c-4c its discharge point. ⚠ The
half of P4c-3's reasoning that said "cannot decide it in either direction" was
**refuted** — see Q_U18's correction block; the PRESERVE counter-example does
not exist, because `?x:Nat` is one glued token.

<a id="p4d-0"></a>

### §5.P4d-0 — the `:{…}` mint + the sub-inner lift  (DEFERRED 42 + 46; opened 2026-08-05)

**The P4d prerequisite, landed ALONE** per the sequencing — it touches
`bcast-step-trigger?`, the one predicate both groupers share. Mini-audit
`wf_e15a1ef6-dfb` (4 facets + critic, ~1.1M tokens); every load-bearing claim
below re-verified on the main thread.

**⭐ WHAT THE AUDIT CORRECTED BEFORE IT COULD MISLEAD** (now folded into
DEFERRED at `2692a958`): the "minimal" memq widening produces a DEGENERATE datum
(`($bcast-step :)` + a separate brace) — the real mint WRAPS:
`($bcast-step ($select-brace …))`, keyed on the colon glued to the FOLLOWING
opener (base-adjacency alone breaks `def b: [List Nat]`, which works today) ·
46 was MISLOCATED (the arms exist; the LIFTS put `@sub` at branch-head) ·
40 = 46, filed twice with conflicting fixes; adjudicated · 39's five-site
exoneration was stale three days after it was written · ⚠ the parser's
`$bcast-step` fold arm has an unguarded `(symbol->string (cadr it))` that is a
WHOLE-FILE ABORT at HEAD (3 reproducers) and sits directly on the mint's path.

**Rulings**: [Q_U20](#q-u20) (sub-inner assembles at 'block, always) · the
parser guard is SITE-LOCAL; the class-level parse-path guard is its own slice
(DEFERRED 53) [owner, 2026-08-05].

**Slices**:
1. ⬜ uncomment the EIGHT corpus lines that already work at HEAD (own commit —
   never bundled, or the A/B is un-attributable; ⚠ marker renumbering).
2. ✅ `0c0ef6dc` the SITE-LOCAL parser guard — the three HEAD aborts are
   per-command now; pin failed as the abort itself (an ERROR escaping the test
   body), green after. Battery 356 → 357.
3. ✅ `667684ad` the WRAPPING mint — ONE shared trigger, both groupers, the tree
   twin fuses ('bcast-brace-group), the Q_N3 v2 guard gains its first colon row.
4. ✅ `667684ad` the LIFT DISCRIMINATION (Q_U20) — and the verify found TWO
   BLOCKING defects invisible to every gate (no test or corpus spells `^:{` or a
   binder `:{`): top-keys SPLICING a sub inner's keys (three grades, worst a
   symbol<? whole-file abort) and `unwrap-bcast-step` unwrapping ANY pair (a
   binder `:{` silently DEFINED a garbled Pi at 0 errors). Both fixed + pinned;
   spin-offs DEFERRED 54–55. **Both §3.2.1 extent members work end to end.**
5. ✅ `77259635` — EIGHT more corpus lines live incl. **both extent members**
   (acceptance 61/61 → **69/69**); the spurious-dot display fixed; the
   vector-element refusal names the broadcast alternative (DEFERRED 55 ✅).
   The L4/top-keys coherence landed earlier IN slice 4 as the B1 fix.

**A/B**: `tools/corpus-ab.rkt` as-is · Tier 1 = `foray.prologos` (the ONLY
minting file; owner WIP ⇒ working-tree inputs) · Tier 2 must-NOT-move =
`benchmarks/comparative/dependent-types.prologos` (the corpus's only spaced
colon-then-lbrace, a live data constructor) · control = a zero-colon zero-brace
file · file list by `find`, not `git ls-files` (a deleted-in-worktree file
would silently drop from both legs).

**Status: ✅ P4d-0 COMPLETE 2026-08-05** — `33d83989` · `0c0ef6dc` · `667684ad`
· `77259635`. DEFERRED 42 ✅ · 46 ✅ · 55 ✅; spin-offs 53 (parse-path guard
slice), 54 (goal-position row, → the 51/52 chip). Close-note in lieu of PIR
(sub-slice; the track PIR owns the full retro): the phase's finding is that
**both blocking defects were invisible to every gate** — no test or corpus
spelled `^:{` or a binder `:{` — and both were exactly the two static-drift
hazards the mini-audit had measured BEFORE implementation (top-keys vs
output-name; the any-pair unwrap). The audit → verify pipeline did its job
twice over. **P4d is UNBLOCKED.**

<a id="p4d"></a>

### §5.P4d — the CARRIERS  (opened 2026-08-07)

**Mini-audit** `wf_4bc76d94-a2d` (6 facets + completeness critic, ~1.34M tokens
@ `ea9c19e4`); every load-bearing claim below re-verified on the main thread.
**[Q_U19](#q-u19) RULED (A) at the opening** — the path-position refusal is
ratified; one guided message unifies the three routes (rides the diagnostics
slice).

**⭐ WHAT THE AUDIT CORRECTED before it could mislead:**

- **The scope statement conflated TWO carriers.** `regions`/`strings` are
  KEYWORD-ROWS (`expr-Record`, key-domain 'keyword), NOT `expr-Map` — separate
  type constructors, separate `select-row-of` arms. TWO typing arms; ONE shared
  reduction arm (both run on `expr-champ` — probed: `map-keys` serves both).
- **The het tuple is TYPING-ONLY.** Its runtime carrier is `expr-rrb` — the
  SAME as PVec — so `rrb-of`/`bcast-lift` already handle it; adding a reduction
  twin would be belt-and-suspenders. Map/keyword-row is the only carrier
  needing new reduction work. The single typing seat is `select-elem-of`
  (typing-core), whose carrier axis is a binary `if` its own comment already
  books for this dispatch; `rrb-of` (reduction) is currently UNREACHABLE
  through typing and goes LIVE the moment the typing gate widens — the two
  sides land ATOMICALLY (the P4c-4c discipline, recorded at the site).
- **The ω path already reaches the Q_U10 Map posture for Map-as-ELEMENT**
  (`ms : [PVec [Map Keyword Int]]` · `ms:a` → `@[1 3]` at 0 errors); only the
  CARRIER slot is gated. P4d is narrower than "add Map support to broadcast".
- **`quests:t` / `quests:{t r}` are OUT of the re-fate list** — live since
  P4d-0 (markers 43/44). Five stale D4 sites said otherwise; corrected this
  commit (see [Q_U9](#q-u9)'s correction block).
- **Q_U9's Functor door was FALSE WHEN WRITTEN** — `Functor List` live since
  2026-03-01. The refusal stands on its other grounds; the guided error drops
  the "no instance" clause. Full correction at [Q_U9](#q-u9).
- **The `bcast-carrier` message split is REQUIRED BY P4d, not optional within
  it**: one arm currently serves EVERY non-PVec subject and tells each — Set
  and List included — that "the map, keyword-row and heterogeneous-tuple
  carriers land at CIU T6 D4.P4d". That sentence goes false-and-unexplained
  for the out-of-scope carriers the moment the in-scope ones land.

**⭐⭐ NEW, in the blast radius — a LIVE type-soundness hole** (found by the
completeness critic; re-verified on the main thread): a het literal with a Map
element NEVER FORMS A TUPLE. `unify.rkt`'s deliberately-symmetric Record↔Map
COERCION arm (`:588-589` at `ea9c19e4` — its own comment says "fires in EITHER
argument ordering") is consumed by typing-core's pvec-literal-homogeneity probe
as an EQUALITY, so the FIRST element's type wins:
`def r1 := {:a 2 :b 3}` · `def m1 : [Map Keyword Int] := {:a 1}` ·
`@[r1 m1]` → `[PVec {:a Int :b Int}]` (a closed type `m1` does not satisfy) →
`mixed:b` → **`<error> : [PVec Int]` at 0 errors**; the reversed order is
benign (`[PVec [Map Keyword Int]]`). Order-dependence is what pins it on the
unify arm rather than a subtyping rule. Three P4d touchpoints: (a) het fixtures
with a Map element silently test the WRONG carrier; (b) it is the
buried-error-in-an-output-slot class DEFERRED 48 exists to prevent, via a route
48 does not cover; (c) the Map carrier work makes it MORE reachable.
**Disposition: co-design (fix-first as slice 0, vs DEFERRED + fence the
fixtures).**

**Carried into this phase**: the **C9 scalar-tier question** — a het tuple has
N position types; the tier is ONE scalar per `expr-select`; `select-tier-subject`
peels `expr-PVec?` only. D4's own P4 audit list said "rule it in P4c-4" and
P4c-4 closed without ruling it; DEFERRED 48 rules the ABORT uniform, not the
tier. Due at the het slice's mini-design. · DEFERRED **40-residual/45**
(`select-step-name` totality + the top-keys label twin — value-channel only,
never a raise) · DEFERRED **47** (the empty-PVec wording — a diagnostics-slice
rider) · the CALM restatement for `row-meet` (the "annotation-only at HEAD"
premise is FALSE — a PVec-of-union is INFERABLE via `nil-safe-get`'s Nil
append; the argument moves to the `has-unsolved-meta?`→⊥ ground).

**Slicing: ⬜ under co-design.**

<a id="pf"></a>

### §5.PF — Path first-classness  (Q_U17 RULED B2, owner 2026-08-02)

**Why it exists.** Path first-classness today is **DECLARED, NOT DELIVERED**.
`segments : Path -> [List Keyword]` is true of exactly ONE of six step kinds, and
`path-segments` has **never marshalled** — it hand-builds a Prologos cons-chain
where the foreign marshaller wants a RACKET list (pre-existing, `f072c115`), so
`from-segments` and `path-append` are dead with it. Eleven production sites read
segments as bare symbols via `(expr-keyword seg)`, a silent type lie for four
kinds. ω did not create this; it made it unignorable. The full argument and the
disqualification of every alternative is [Q_U17](#q-u17).

**Deliverables**

1. **`data Step`** in the lib, six constructors mirroring `select-step-kind`. The
   Racket-side classifier stays the single source of kind truth; the lib type is
   its reflection, so a seventh kind is added in ONE place and the marshaller's
   totality rides the existing `select-step-kind-unhandled` seat.
   ⚠ `step-sub` recurses through **`List`**, not `Path` — exactly as
   `datum-cons` recurses through `Datum`. **No parameterization, no mutual
   recursion**; `Path` stays ground. (This is why seed option B3 was unnecessary
   rather than merely costly.)
2. **`data Cont`** — the second ADT, and the cost the headline hides:
   `dissolve | synth | collapse | collapse-synth | (rename . k) |
   (collapse-rename . k)`.
3. **The `path-segments` repair, in the SAME change** (U17b). The fix is "return
   a Racket list" — `racket-list->prologos-list` already exists — but the repair
   must decide WHAT it returns. Returning keywords re-enshrines the lie;
   returning `Step` makes the spec true. Marshalling template already in-tree:
   `datum->datum-expr`. Same question for `head : Path -> Keyword`.
4. **Migrate the eleven bare-symbol consumer sites** through ONE marshaller.
5. **Revive `from-segments` / `path-append`**, dead since the abort.

**Cost, stated plainly.** TWO ADTs, not one. And it inherits the tax the `Datum`
module documents in its own comment: wildcard `_` in a match over a user data
type "triggers a type-inference limitation that causes module loading to fail",
so every `Step` consumer written in Prologos enumerates all six arms. A known
inference bug, not a design property — but real today, and it scales with the
vocabulary.

**What it enables.** P5's **B3 same-spine merge** needs structural comparison of
two paths, which is exactly what a first-class `Step` value permits and an
eliminator does not — that asymmetry is what disqualified the emergent B6.
Q_U12's deferred sorts (`#.field` nil-safe, `[k]` ordinal/dynamic) land as new
constructors rather than as new lies.

**Does NOT block P4c.** `(@bcast step)` is a unary constructor of a closed union
with ONE producer and ONE classifier, so converting it later is cheap *because
that is already the ADT shape*. The encoding is not where first-classness is won
or lost.

Status: ⬜ PF — **not started**; prerequisite of P5's B3.

<a id="p5"></a>

### §5.P5 — Ruling B + factoring

**Intent**: upgrade the strict waypoint to Ruling B — B2 keywise node merge ·
B3 same-spine pointwise merge (spine = source-directed steps with
`^`-continuations erased; Q7's residuals settle here) · L2 factoring
(`{p:a p:b} → p:{a b}`) as the normal form, with **error messages printing
the factored spelling** (spec: SHOULD) · L3 assoc/comm on disjoint keys ·
Q6 (idempotent self-merge) ruled here.

**Test delta**: corpus §10.3 uncomments; L1–L5 law tests as a dedicated
battery (the equational theory IS test material). Status: ⬜.

<a id="px"></a>

### §5.PX — Binder-seam substrate (carried unchanged)

The D3-S10 concrete-codomain lambda-adoption hole
(`[the [List String] [map [fn [x] x] ints]]` accepts silently) + the
standalone-def seam (`def f := [fn …]` / `def add5 := [int+ 5 _]` fail where
the body determines the types). Surface-independent; the old doc's round-6b
capture stands. Position flexible. Status: ⬜.

<a id="p6"></a>

### §5.P6 — Demand semantics (staging decision + implementation)

The §2.2 collision, staged honestly: **decision by P3** (blocks make demand
observable), implementation possibly later. Options considered against
POL.10: (a) lazy leaf thunks in the champ (rep change; `.pnet` + effect-gate
interaction) · (b) a demand mark at elaboration (selection-aware forcing) ·
(c) defer §1.3 to a named post-v1 phase with the corpus marker documenting
the gap.

**RULED Q_U3 — option (c) [owner, 2026-07-30: "defer it — (c) stands"].**
Demand semantics is DEFERRED to a named post-v1 phase (the
**demand-semantics phase**, CIU T6 post-v1 — chartered by this stub, opened
only by explicit owner direction). Rationale (the P3a-close presentation):
the lift is a RUNTIME REPRESENTATION change deserving its own Stage-3
design; nothing in P3b–P5 depends on it (all value-level); demand's real
payoff needs the effect story and **Stratum 3 is comment-only at HEAD** —
lazy leaves without the effect stratum buy invisible timing changes for pure
programs and UNSEQUENCED effects for impure ones; the 4a X.close gate keeps
the deferral honest (the PIR must re-state the staged status and the owner
must charter or re-defer explicitly). **Charter-stub inputs for the future
phase's Stage 3**: thunked-champ-leaves vs demand-mark realization · `.pnet`
serialization of thunks · the effect gate · the whnf memo cache · sequencing
against (or explicitly without) the effect stratum. Eyes-open cost accepted:
an [ADOPTED] spec element stays unimplemented through v1; `[now]`/`[env …]`
leaves force at def-commit (the corpus §A comment documents it).
Status: **decision ✅ (Q_U3)**; the phase's residue = the X.close gate row.

<a id="x-close"></a>

### §5.X — X.close

Bench matrix (feature microbench + E2E per testing.md — priced against the P2
baseline) · DEFERRED triage · doc-truth sweep (incl. the old doc's banner, the
map tutorial, `prologos-syntax.md`'s selection section) · **the §1.3 demand
GATE (ruling 4a): v1 may not be declared complete without the staged-demand
status re-stated in the PIR and the lazy-leaf phase chartered or explicitly
re-deferred by the owner** · memory fold · **Stage-5 PIR** (the track does not
flip ✅ without it). Status: ⬜.

---

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

- **The spec** (normative surface): `docs/research/2026-07-28_path-selection-spec.md`
- Predecessor design (record of rounds 1–8b): `2026-07-26_CIU_T6_PATH_SELECTION_DESIGN.md`
- Landed substrate: P2 commits `ad75e57a` · `88d1f746` · `b8f7cc27` · `d4f4b80f` · `ac89341f`
- P3 mini-audit: `wf_2830f0aa-9a4` (token registry, censuses, seats) — findings recorded in the predecessor's P3 row
- Records substrate: `2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md` (D1–D29) · F1b PIR · Rel T1 PIR
- Rules: `prologos-syntax.md` § Reader · `pipeline.md` · `workflow.md` · `on-network.md`
