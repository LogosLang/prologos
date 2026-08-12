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
| **P4d** | **The carriers** — Map/keyword-row · het tuple · PVec-of-union · closed-schema subjects · the Q_U9 refusal's message split · corpus re-fate · **Q_U19 ✅ RULED (A)** | ✅ | [§5.P4d](#p4d) · slices **0 ✅ 1 ✅ 2 ✅ 3 ✅ 4a ✅ 4a' ✅ 4b ✅ 4c ✅ 4d-1 ✅ 4d-2 ✅ 5 ✅ 6 ✅** — broadcast is LIVE over PVec · Map · keyword-row · het tuple · union · closed schema. ⭐ The CLOSE's own audit found a whole-file abort in slice 3's code (slice 5) and Q1 re-opened as a live defect (slice 6). All THREE owner questions discharged: Q1 ruled+implemented · [Q2](#q-u22) answered (fix → DEFERRED 88) · Q3 answered (broadcast → 58 re-scoped; contract → 89) |
| **P4e** | **The `*` family · disclose `<`/`:<` · branch-initial `:`** — ⭐ **`*` is SORT-GENERIC** (deletes the layer the preceding step created: `:diags*` mapcat, `database*` splat). `.*` retires as row-splat and rebinds to **ravel**; `*_` adds provenance keys; branch-initial `:` admits the **ordinal² transpose** | 🔄 | [§5.P4e](#p4e) · RE-SCOPED 2026-08-08 ([Q_U23](#q-u23)–[Q_U29](#q-u29)) · ⛔ attempt 1 REVERTED `d0ac2a58` ([DEFERRED 101](DEFERRED.md)); attempt 3 opens from [the census](#star-census) ([Q_U30](#q-u30)/[Q_U31](#q-u31), prereq [102](DEFERRED.md) ✅ `41458174`) · PREP ✅ `f63612e7`+`ae67419f` ([Q_U32](#q-u32)) · **slice A SHIPPED** `e7a49228`, **slice B REVERTED** `0e007864`: [§5.P4e-0-a3](#p4e-0-a3) · ⭐ **P4e-1a ✅ COMPLETE** `9cac0099` — the mint has its CONSUMER. [Q_U36](#q-u36) positive-list fuse + [Q_U37](#q-u37) territory-scoped refusal; 3 slices (attempt 1 of the last REVERTED); suite 10143/488/0, battery 476: [§5.P4e-1a](#p4e-1a) · **P4e-1b 🔄 SEMANTICS FULLY RULED, not implemented** (audit `wf_4b91ca25-73a`) — [Q_U38](#q-u38) collision REFUSED (conservative on the `'dyn` tail; gate moves to typing) · [Q_U39](#q-u39) closer-adjacent `*_` mint SPLIT OUT · ⭐⭐ [Q_U40](#q-u40) the star attaches **OUTER**, one rule over both axes, and it yields the law `x{p₁* … pₙ*} ≡ x{p₁ … pₙ}*` · [Q_U41](#q-u41) `*_` is NOMINAL-ONLY · [Q_U42](#q-u42) same-key VECTORS CONCAT, closing the last semantic question and making the join one recursive rule at every depth. Slicing proposed 4-way (i recipe · ii kind+arms · iii vector · iv nominal+collision+`*_`): [§5.P4e-1b](#p4e-1b) |
| **P4c-5** | **The `.*name` retirement + FULL residue disposal** — the last P4c residue, sequenced AFTER P4e | ⬜ | [§5.P4c-5](#p4c-5) · ⚠ **row ADDED at the P4d close 2026-08-08** — previously visible only as a `P4c-5 ⬜` fragment inside P4c's Notes cell |
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

  **⭐⭐ AMENDED 2026-08-08 [owner — "leave the dot string alone, add a broadcast
  sibling"; then "all three"]. READ THIS BEFORE TOUCHING ANY CODE — the text
  ABOVE, written before the slice-4d mini-audit, would authorise the one edit
  this ruling FORBIDS.** "Unify" means ONE NEW message that the three routes
  funnel into — it does **NOT** mean editing the existing string.
  · **The dot string stays BYTE-IDENTICAL.** `re-keys the OUTPUT` is ONE
    production site (`parser.rkt`, the `[(ormap select-step-cont (car branches))]`
    arm) serving TWO audiences — dot, where "a **field access** has no output
    key" is the CORRECT noun, and broadcast, where it is wrong, ever since
    P4c-3a made `select-step-cont` ω-transparent (`syntax.rkt`'s
    `select-step-cont` recurses through `select-bcast-inner` — that recursion IS
    the routing). The complaint at the bullet above is about the BROADCAST
    audience only. Its DOT pin (`"verify S2: \`^\` in a DOT access REFUSES"`)
    must keep passing untouched; only the ω pin moves.
  · **The discriminator is PER-STEP, not per-branch.** `ormap` returns the CONT
    and DISCARDS which step carried it. Measured at `2fd6b68e`: `ys.a:b^c` (caret
    on a genuine ω step) and `xs:a.b^c` (caret on a DOT step, in a chain the user
    opened with `:`) BOTH take the message today. Find the step (`findf`), then
    ask `select-step-kind` — it already returns `'bcast` (`syntax.rkt`) and is
    ALREADY imported by `parser.rkt` (`select-bcast-step?` is provided but NOT in
    the `only-in` list; the in-file idiom is the kind dispatcher). Zero new
    plumbing.
  · **The three routes fail at THREE LAYERS — this is three seats of work, not
    one funnel** (owner ruled "all three" 2026-08-08): route 1 fails INSIDE
    `segment-select-items`, post-mint (small, clean); `xs:{name}^alias` never
    ENTERS segmentation (`^` is ident-CONTINUE but not ident-START, so the caret
    survives as a bare sibling OUTSIDE the brace group and the form becomes an
    APPLICATION) — a FOLD arm, on the `ordinal-rekey` element-wise precedent;
    `xs:0^alias` mints NO sentinel at all — it fails in the TOKENIZER and the
    fold's entry gate never opens.
  · **The route-1 spelling set UNDER-COUNTS: the COLLAPSE family also reaches
    it.** `xs:name^-` takes the message (measured), matching the dot pin's own
    four spellings.
  · **⚠ PRECEDENCE CONSTRAINT**: `xs:name^^a` takes `split-caret-lexeme`'s
    WELL-FORMEDNESS error first ("one `^` per segment…"). The sibling must NOT be
    installed above it, or a true specific message is replaced by a generic one —
    the class the slice-3 verify already caught once in this track.
  · **⚠ MONOTONICITY**: the refusal stays `'path`-SCOPED. Block-position ω-caret
    is LIVE at 0 errors today (`cfg{admins:name^alias}`, `xs:{name^alias}`) and
    the acceptance file carries commented `[D4.P5]` block-position targets — a
    wider refusal would refuse a spelling the track has committed to meaning.
  · ⚠ A FALSE PREMISE SITS IN THE EDITED LINES: `parser.rkt`'s comment four lines
    above the string claims `make-select-bcast` "has ZERO production callers at
    HEAD". It has FOUR, all in that file. Correct it in the same diff.

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
  layers).

- <a id="q-u22"></a>**⭐ Q_U22 — `^` AT A LEAF IS ARITY-UNIFORM: n=1 YIELDS
  `⟨T⟩`, NOT THE BARE VALUE [owner, 2026-08-08].** Raised co-designing Q2: the
  owner's reading of *"dropped means dropped"* (spec §3.4) predicts that
  `xs:host^` should give `@["a" "b"]` — the values, unwrapped — where HEAD gives
  a vector of 1-tuples. **Ruled the other way, and NOT on implementation cost.**
  Two dropped keys at one level are FORCED to be positional (you cannot put two
  unnamed things in a record), so keyless→tuple is settled at n=2 by the live
  unzip `party:{name^ level^}` → `[PVec ⟨String Int⟩]`. Collapsing n=1 to the
  scalar would make the operator ARITY-DEPENDENT — one dropped key unwraps, two
  tuple up — which breaks the algebra's uniformity for a cosmetic gain. Owner:
  the coherence of the algebra is the deciding reason, and **`<` (disclose/pick)
  plus `join` recover the ergonomics** that the bare-value reading was reaching
  for, so nothing is lost expressively.
  ⚠ Second, independent ground, recorded because it survives even if the
  algebra argument is later revisited: n=1 unwrapping would make `xs:{name^}`
  a SECOND SPELLING of `xs:name`, which is exactly what slice 4c's owner ruling
  retired ("stop teaching a second spelling"). The bare-value spelling already
  exists and is `xs:name`.
  **Consequence for Q2, accepted eyes-open**: `cfg{servers:host^}` reads as
  `{:servers @[⟨"localhost"⟩ …]}` under the caret-once fix — honest, uniform,
  and less pretty than the owner's intuition. That is the trade, named.

- <a id="q-u23"></a>**⭐ Q_U23 — `*` IS SORT-GENERIC: IT DELETES THE LAYER THE
  PRECEDING STEP CREATED. `.*` row-splat RETIRES as a separate operator
  [owner, 2026-08-08 — "Good on the stronger form of `*` with no `^`"].**
  Opened by the owner at the P4e design round with the question *"is `m{k}` not
  the same as `m{k.*}`?"* — and it is. Measured at HEAD: `cfg{database}` →
  `{:database {…}}`, which is exactly the corpus's own recorded expected value
  for `app-config{database.*}`. **`.*` is an IDENTITY wherever the head key
  survives**, because projection-with-ancestry re-nests whatever the splat
  lifted under the surviving key. It does work only after `^` has dissolved that
  key — and even then only alongside SIBLINGS, since `cfg{database^.*}` alone is
  byte-identical to `cfg.database`.
  **The ruling**: one rule, one operator — *`*` deletes the layer the preceding
  step created; the SORT follows the layer.* So `:diags*` deletes the vector
  layer `:diags` made (mapcat), and `database*` deletes the nominal layer the
  `database` branch made (splat). `cfg{database* version}` →
  `{:url …, :pool-size 10, :version "1.0.0"}`, all-keyed, no `^`.
  **This CLOSES spec §8 Q4** ("`*` on Map layers — is there a nominal join?")
  in the affirmative, by the same argument §3.2.3 used to adopt map-generic `:`:
  a vector-only `*` leaves the key-sort thesis decorative exactly where it
  matters. `.*` was the residue of a unification that stopped one step short —
  path-position `.*` was already subsumed by map-generic `:`.
  **Rejected-with-reason**: `database^.*` and `database^*` (the owner's first
  spelling) — both over-spell, because `^` dissolves a key `*` was going to
  delete anyway, and renaming before a delete is inert. ⚠ Neither could be read
  as a SEQUENTIAL composition in any case: **measured**, `cfg{database^ version}`
  is an **L4 mixed keyed/keyless** error, so `^` alone makes the branch keyless
  and any repair-by-`*`-afterwards has an ill-sorted intermediate. A `^*`
  spelling would have had to be ONE glued continuation, like Q_T7's `^-`.
  **The one honest asymmetry, recorded**: vector join is TOTAL (concatenation
  cannot collide); nominal join CAN collide. Collisions route to §3.6 Ruling B —
  and P4e needs no P5 machinery for it, because P3a already landed strict merge
  for plain keys before `make-record` can last-win (PS7's shippable waypoint).
  GROQ's last-wins is the precedent the spec explicitly rejects.
  **Lexical dividend — ⚠⚠ MATERIALLY UNDER-SCOPED AS FIRST WRITTEN; CORRECTED
  2026-08-08 BY THE P4e MINI-AUDIT (`wf_5fb7131d-63a`), re-measured on the main
  thread.** The original claim read: *"Spelled `database* there is no `.` to
  shatter — both bands go through ONE trailing-star splitter."* **That is true
  ONLY for IDENTIFIER-headed layers.** The reader's star-fusion is
  IDENTIFIER-SPECIFIC, not sort-generic: `ident-continue?` admits `*`, so the
  star joins an identifier token — but a NUMBER token and a CLOSER token END
  before it. Measured at HEAD:
  · `cfg{database*}` **FUSES** → `field :database*` (one nominal key) ✅
  · `m{0*}` **SHATTERS** → L4 mixed keyed/keyless ❌
  · `m{0 *}` → the **BYTE-IDENTICAL** L4 error, so glued and spaced carry NO
    distinction — **the ordinal splat is UNSPELLABLE**, the information is
    destroyed at the reader exactly as it is for `.*` ❌
  · `m:0*` → **`Unbound variable :`** — adding ONE character DESTROYS an
    existing `$bcast-step` mint, so the landed ω `*` guard (the `#rx"[*]"` arm,
    which keys on the `$bcast-step` PAYLOAD) structurally CANNOT fire on it ❌
  · `m:0 *` → `Could not infer type [m.:0 [arithmetic::* …]]` — the star became
    ARITHMETIC MULTIPLY applied to the selection ❌

  > **⚠ THE ERROR TEXTS ABOVE ARE STALE — re-measured 2026-08-10 at `19560a7c`.
  > THE STRUCTURAL CLAIMS ALL HOLD; THE SYMPTOMS MOVED, because the P4e-0 revert
  > was PARTIAL.** `d0ac2a58` took out the count-changing MINT but left the
  > guided-error surface `bfba68d5` had added (`parser.rkt` gained 169 lines in
  > the WIP; 54 came out). So attempt 3 does **not** open on a clean
  > pre-attempt-1 tree. At HEAD:
  > · `cfg{database*}` → *"`*` (flatten) is not implemented yet — `database*`
  >   would delete one layer of what the preceding step produces"* — still FUSES
  >   (it reaches the consumer as one nominal key), then guides-refuses. Claim ✅
  > · `m{0*}` and `m{0 *}` → **both** *"`*` — `*` is postfix; it attaches to the
  >   END of a segment"*, not the L4 mixed keyed/keyless error recorded above.
  >   **BYTE-IDENTICAL still holds**, which is the load-bearing half — the
  >   ordinal splat remains UNSPELLABLE. Claim ✅, symptom changed.
  > · `m:0*` → `Unbound variable`. Claim ✅ — one character still destroys the
  >   `$bcast-step` mint.
  > · `m:0 *` NOT re-confirmed: the 2026-08-10 probe used `m := @[10 20 30]`, a
  >   different subject from the original, so it errored on the broadcast before
  >   reaching the star. **Unverified at HEAD**, not refuted — re-probe with the
  >   original subject before relying on it.
  >
  > **The lesson is the recorded one**: *a fact has a timestamp.* The symptom
  > text is not the mechanism; pin the mechanism.

  So the grouping fix this ruling claimed the `database*` spelling had DELETED
  is **still owed for every non-identifier layer head** (ordinal, sub-block,
  bracket/paren closers). The dividend is real but its scope is the nominal and
  keyword layers ONLY — which are the layers this ruling's EXAMPLES use, and not
  the layers its RULE generalizes over. **The sort-generic rule stands as
  SEMANTICS; its lexical realization does not follow for free.**
  What DOES survive: the routing half. `$select-path` (the bare dot path,
  outside any block) calls the same `segment-select-items` fold as the block and
  ω bands, so ONE splitter can serve every identifier-headed surface — at ≥3
  call sites, mirroring `split-step`'s three, because the ω payload arrives
  colon-leading and string-stripped while the others arrive as bare symbols.

- <a id="q-u24"></a>**⭐ Q_U24 — `*_` IS THE PROVENANCE VARIANT, AND IT LANDS
  WITH BARE `*` [owner, 2026-08-08 — "Yes to land `*_` with bare `*`"].**
  Proposed by the owner as a shorthand for the collision case. `*_` splats and
  synthesizes each lifted key from the deleted layer:
  `cfg{database*_ version}` → `{:database-url …, :database-pool-size …,
  :version …}`. **It is the answer to Q_U23's one asymmetry**: it removes
  nominal-join collisions BY CONSTRUCTION rather than erroring, and it rescues
  the per-level case — `regions*_` → `{:ap-host …, :eu-host …, :us-host …}` —
  which under bare `*` collides on every key of a homogeneous Map-of-Map and is
  therefore almost always an error. **They land together** because shipping bare
  `*` alone would deliver an operator whose headline nominal use fails on every
  realistic input, teaching a refusal whose remedy we already have.
  **Precedent**: Q_T7's `^-_`, which D4 already describes as "the flat
  *provenance* recovery… **which is where a structural effect belongs**."
  ⚠ **REQUIRED RULING, do not inherit the wrong parent**: `^_`'s stated rule is
  *"Dropped means dropped — `^`-dissolved segments do not contribute"* (spec
  §3.4), whereas `*_` wants the DELETED key as the prefix. `*_` follows `^-_`'s
  rule, NOT `^_`'s. Inheriting `^_`'s silently degrades `*_` to bare `*`.
  **Spelling**: `*_` is ONE glued continuation, matching `^-_`'s shape. `*^_`
  does not type — `^_` synthesizes ONE key while a splat lifts many.

- <a id="q-u25"></a>**⭐ Q_U25 — BRANCH-INITIAL `:` IS SCOPED INTO P4e FOR THE
  ORDINAL² TRANSPOSE; ORDINALS NEED NO `^` [owner, 2026-08-08 — "the inner
  broadcast should be scoped in now… ordinals don't need `^`, since they already
  return their value-at-index"].** The owner reached this exploring a matrix
  rotate, from an explicitly APL-inspired reading.
  **The owner's refinement CORRECTS THE SPEC against a landed ruling.** Spec
  §10.6 writes the v2 transpose `m{:0^ :1^ :2^}`, but **Q_T4a rules that `^`
  NEVER attaches to an ordinal** — measured at HEAD, `values:{0^}` is the
  guided error *"an ordinal has no key."* The two cannot both stand; the spec
  sketch predates the ruling. §3.3 already makes ordinal branches keyless BY
  BEING ORDINAL ("keyless branches: `^`-terminated, **or ordinal `{N M}`**"), so
  the `^` was never introducing a key — it was marking keyless, which ordinals
  already are. **The correct spelling is `values{:0 :1 :2}`.**
  **⭐ CONSEQUENCE — W2's EXIT IS SMALLER THAN IT WAS WRITTEN.** Spec §7's W2
  ("Pure transposes — ordinal² and nominal²") states its exit as *"generalize
  `^` to set (§7.3) **+** admit branch-initial `:`."* The first conjunct is
  needed only for the **nominal²** pivot (`strings{:home^home …}`, where `^home`
  is a genuine rename). For the **ordinal²** matrix, keylessness is free — so
  the ordinal half is reachable with branch-initial `:` ALONE, no v2 `^`-as-set.
  **⚠⚠ "AND NO NEW TYPING MACHINERY" — REFUTED 2026-08-08 by the P4e mini-audit
  (`wf_5fb7131d-63a`), reproduced on the main thread. The claim is struck.**
  ~~measured, `values{0 1 2}` → `⟨[PVec Int] [PVec Int] [PVec Int]⟩` — the
  transpose's target type ALREADY types and prints. Same type, different value;
  only the branch head changes from indexing to broadcasting.~~
  **THE SUPPORTING MEASUREMENT WAS STRUCTURALLY INCAPABLE OF DETECTING THE
  DIVERGENCE IT WAS CITED TO RULE OUT** — it used a **SQUARE** (3×3) matrix,
  where `{0 1 2}` is the IDENTITY and where the identity and the transpose share
  a type. Re-run NON-SQUARE (2×3), it collapses: `nm{0 1}` →
  `⟨[PVec Int] [PVec Int]⟩` — **TWO** components, the ROWS, while the transpose
  of a 2×3 has **THREE**. The probe only ever proved the target type is
  EXPRESSIBLE, which was never in doubt.
  **And the branch head alone does not get there**, because a branch inherits
  the BLOCK sort, which WRAPS: measured, `nm:0` → `@[1 4] : [PVec Int]` (the
  column, at `'path`) but `nm:{0}` → `@[@[1] @[4]] : [PVec ⟨Int⟩]`. So
  `{:0 :1 :2}` yields `⟨[PVec ⟨Int⟩] × 3⟩`, a transpose wearing an extra
  1-tuple layer — not the transpose.
  **What the refutation LEAVES INTACT, and it is the useful half**: the correct
  COLUMN already exists at `'path` (`nm:0` → `@[1 4]`). So the missing piece is
  **per-position SORT CONTROL at a branch head** — the transpose is three
  `'path` columns assembled — NOT new extraction machinery. That is a narrower
  job than "build a transpose", but it **collides with the landed `'block`
  collapse** and is therefore real design work, not a spelling change.
  ⚠ **Q_U25 (ii) is consequently CONTINGENT**: its keyless/no-`^` half stands on
  its own (verified — ordinal and ω-over-ordinal branch heads are already
  keyless), but *admitting the SPELLING does not produce the TRANSPOSE*.
  **✅ OWNER RULED 2026-08-08 — branch-initial `:` STAYS IN P4e SCOPE** ("if it
  is just a `cond` arm, then I see little reason not to include it"). The arm is
  indeed one `cond` arm — the `kw-sym?` refusal in `segment-select-items`, which
  fires on precisely this spelling today.

  **⭐ WHAT THE ARM ACTUALLY DELIVERS, and why it is COHERENT rather than
  broken** (settled 2026-08-08; a hypothesis that it was a live Q_U20 violation
  was FORMED AND TESTED TO DESTRUCTION — recorded because the negative result is
  the load-bearing part). The extra `⟨⟩` layer is **two landed rulings applied**,
  not a defect:
  · A broadcast step's sort is inherited at `select-bcast-inner-apply/non-union`,
    where the SUB inner is hard-coded `'block` (Q_U20) and the non-sub inner
    threads the inherited sort. Measured, the SAME step differs by context:
    `cfg.servers:host` → `@["a" "b"] : [PVec String]` ('path, extracts) vs
    `cfg{servers:host}` → `{:servers @[{:host "a"} …]} : {:servers [PVec {:host
    String}]}` ('block, assembles a keyed row).
  · **That wrap is CORPUS-PINNED as CORRECT** — acceptance marker **19**,
    `app-config{admins:name}` → `{:admins @[{:name "Alice"} {:name "Bob"}]}`,
    live and passing, and carrying its own "CORRECTED 2026-07-29 (handoff
    verification)" note. So block-context assembly is intended.
  · For an ORDINAL inner there is no key (`select-step-output-name` → `#f`), so
    the block assembles ONE KEYLESS component — which by **[Q_U22](#q-u22)**'s
    arity-uniform rule is `⟨T⟩`, not the bare value. Hence
    `⟨[PVec ⟨Int⟩] × 3⟩`.
  **So bare columns would require OVERTURNING Q_U22**, which was ruled on
  algebra coherence and explicitly rejected the bare-value reading. The arm is
  therefore correct as-is, and what it ships is **honest-nested columns**.
  ⚠ Q_U22's own text names the recovery: *"`<` (disclose/pick) plus `join`
  recover the ergonomics."* BOTH are P4e operators — so whether the bare-column
  transpose is spellable END TO END inside P4e depends on whether the recovery
  can attach at a branch head. ⚠ The obvious spelling `{:0*}` is **BLOCKED by
  the ordinal-star shatter** recorded under [Q_U23](#q-u23) (`m{0*}` ≡ `m{0 *}`),
  so this is NOT free. **OPEN — carried into P4e's slicing.**
  **⚠ THE COST, named**: `{:0}` is not free — measured, it is claimed by the
  landed diagnostic *"block keys are written bare — `x{0}`, not `x{:0}`"*, which
  assumes a leading colon in a block is a TYPO. Admitting branch-initial `:`
  makes `{:name}` legal and that guided error loses its case, so a user who
  writes `x{:name}` meaning `x{name}` gets a well-typed WRONG ANSWER instead of
  a correction. §3.6's monotonicity permits it (errors may become meanings), but
  **the diagnostic must be REPLACED, not deleted**: `x{:name}` over a subject
  whose elements do not offer `name` must fail in the broadcast reading's terms.
  This is the arc's recurring shape — a guided error becoming a silent
  divergence — and it is the single largest hazard in P4e's new scope.
  ⚠ This LIFTS a v1 refusal ([Q_U7](#q-u7): "branch-initial `:` stays refused in
  v1… so a wrapper never heads a branch"). The mini-audit must re-derive what
  depends on that invariant — P4a's totality dispatcher and the components walk
  are the named suspects.
  **`:*` DEFERRED, with the boundary stated.** The owner asked whether
  `values{:*}` could be a shorthand. It is not silly, but it needs `*` to mean
  *"every index at this level"* — a BRANCH-GENERATOR, which neither is nor
  derives from Q_U23's layer-delete (join collapses `m (m a) → m a`; a generator
  expands one written branch into n). They coincide in the splat case by
  accident, which is what made the unification look total. It is also
  well-typed EXACTLY where the axis length is in the type: `⟨T₁ T₂ T₃⟩` is a
  closed nat-keyed row and expands; `[PVec _]` does not, so `values{:*}` over
  `[PVec [PVec Int]]` cannot be typed at all. `{:0 :1 :2}` is v1 because the
  count is WRITTEN. This is W2's own alternative exit ("free once rows/lengths
  are statically known") and §5's L6 pairing of AoS↔SoA with length-indexed
  vectors — the array-programming reading is gated on the types learning to
  carry length, not rejected.

- <a id="q-u26"></a>**Q_U26 — RAVEL IS BARE `.*` [owner, 2026-08-08 — "Perhaps
  we can reclaim the `.*` spelling as ravel, then?"].** `values.*` →
  `@[1 2 3 4 5 6 7 8 9]`; APL's `,`. Whole-container join, the sibling of
  Q_U23's per-step `*`.
  **Why NOT `xs*`** (the owner's first spelling, withdrawn on the measurement):
  `*`-suffixed identifiers are an established convention here — ⚠ **`int*` alone
  appears 148 times** (HEAD-pinned `git grep -o 'int\*' HEAD -- '*.prologos'`;
  **130** comment-stripped. The figure first written here was **121**, measured
  against a DIRTY working tree with `.claude/worktrees/` copies inflating a
  root-level recursive grep — corrected 2026-08-08; the direction is unanimous,
  so the withdrawal is STRENGTHENED, only the arithmetic was off), and it is the
  worked example in our own ambient syntax rules (`[int* _ 2]`), alongside
  `rat*`, `p32*`, `trait*`, `p8*`, `p*`, `ordering*`. So `values*` in SUBJECT
  position is indistinguishable from a name, and resolving it by "split the star
  if the whole token is unbound" would make meaning depend on the binding
  environment — the silent-swallow hazard `parser.rkt` already names for
  `:tags*`. It also does not fit Q_U23's rule: `*` deletes the layer *the
  preceding step* made, and a bare subject is not a step.
  ⚠⚠ **THE CENSUS MEASURED THE WRONG HAZARD CLASS ALONGSIDE THE RIGHT ONE**
  (audit `wf_5fb7131d-63a`, reproduced): bare `*` is not merely a legal
  identifier CHARACTER — it is a **BOUND FIRST-CLASS BINARY FUNCTION**. Measured,
  `def s := *` → `s : _ _ -> _ defined.` That is why a star after a CLOSER
  becomes an APPLICATION rather than a shatter: `m:0 *` →
  `Could not infer type [m.:0 [prologos::core::arithmetic::* …]]`. Any
  star-bearing selection surface must contend with `*` being a live VALUE in
  expression position, not only with names that end in it.
  **`.*` is AVAILABLE**: the P4c-5 `.*name` retirement always carries a TRAILING
  NAME (it is the old `broadcast-get`, migration target `:name`), so bare `.*`
  does not collide with it. ⚠ **Measured cost**: `values.*` does NOT survive the
  reader at HEAD — it shatters to `values | . | *` and reports
  `Unbound variable .`. So reclaiming `.*` puts BACK the grouping fix that
  Q_U23's move to `database*` had deleted. Accepted eyes-open: one grouping fix
  now buys a genuinely new operator instead of a spelling that was an identity
  half the time.
- <a id="q-u27"></a>**⭐ Q_U27 — `*` IS SORT-GENERIC IN THE SURFACE TOO, NOT ONLY
  IN THE SEMANTICS. THE READER WORK IS TAKEN ON [owner, 2026-08-08 — "Let's take
  on the sort-generic and make it available in a way that makes us proud of
  accomplishing a work brought to completeness"].** Closes the hole the P4e
  mini-audit opened under [Q_U23](#q-u23): the rule generalizes over layers but
  the LEXING did not, leaving `m{0*}` byte-identical to `m{0 *}` — an
  **unspellable case in a ruled operator**, which this track's own record says
  comes back.
  **THE ARCHITECTURE IS A HYBRID, AND IT IS FORCED — one sentinel, two sources.**
  Grounded on the landed mechanism, re-verified on the main thread:
  · **Non-identifier heads** (ordinal, `}`/`]`/`)` closers, sub-blocks) — the
    star is ALREADY its own token, byte-adjacent to the base. So this is the
    **`adjacent-to-base?` mint**, the [Q_U8](#q-u8) shape: a star token adjacent
    to a non-empty local result mints the sentinel. Every one of these carriers
    joins **FREE**, because `adjacent-to-base?` *"consults no token type"* — its
    own comment names `.N`, brackets, braces, parens and closers as joining the
    focus set at no cost. This is the same predicate `bcast-step-trigger?` and
    `bcast-brace-trigger?` are built from.
  · **Identifier heads** — the star is ALREADY FUSED (`database*` is ONE token,
    because `ident-continue?` admits `*`), so adjacency cannot see it. This is
    the **post-tokenization splitter**, the `split-caret-lexeme` shape, at
    `segment-select-items`' call sites.
  · The two sources MUST converge on ONE sentinel so the consumer is one arm.
  **Why the hybrid is forced rather than chosen**: removing `*` from
  `ident-continue?` would break `int*` (148 HEAD-pinned uses) and its family, so
  the fusion cannot be prevented; and the adjacency mint cannot see a fused
  token. Neither mechanism alone covers both. ⚠ *Architecture PROPOSED here from
  verified mechanism; the slice's own mini-round confirms before it lands.*
  **NON-NEGOTIABLE CARRY-OVERS from the landed twins** — each already cost a
  BLOCKING regression once: (i) **ONE definition consumed by BOTH groupers**
  (the F1b.7g drift class; `surface-rewrite.rkt` hand-inlines a non-exported
  sibling today). (ii) **The decline is a CLASS, not a list** — copy
  `(not (prev-token-not-emitted? vec i))`; its comment records that shipping it
  "as a list of one" cost a blocking regression. (iii) **Corpus A/B MANDATORY
  with a NAMED predicted diff set** — grouping changes datums (Q_U8's precedent).
  (iv) The mint slice lands **ALONE** (the P4d-0 precedent: a shared grouper
  predicate makes a bundled A/B un-attributable).
  **Ravel's recognizer is separate and its discrimination is clean**: bare `.*`
  fails today because `recognize-dot-access` explicitly declines `.*` and the
  `.*name` retirement recognizer requires an identifier AFTER the star. So
  **presence-of-trailing-identifier IS the discriminator**, and it already lives
  in the recognizer — `.*name` keeps the retirement error, bare `.*` mints ravel.
- <a id="q-u28"></a>**⭐ Q_U28 — A TRAILING `*` SHADOWS A LITERAL FIELD NAME
  SILENTLY, EXACTLY AS `^` DOES [owner, 2026-08-08 — "Match the `^` reading for
  now"].** No type-time disambiguation check: the operator always wins, its
  reading does not depend on what the subject happens to contain, and a
  genuinely star-bearing key is reached the same way a caret-bearing one is.
  **THE PRECEDENT, MEASURED at HEAD** (not asserted — this was the worked
  demonstration the owner asked for):
  · `q := {:a^b 5 :a {:b 9}}` · `q{a^b}` → **`{:b {:b 9}}`** — the RENAME wins;
    the literal `:a^b` (value `5`) is unreachable through the block band.
  · `q.a^b` → a GUIDED error (*"`^` re-keys the OUTPUT of a selection… Use a
    select block if you want to rename"*) — the band that cannot express the
    operator refuses with guidance rather than falling back to the literal name.
  · **`[map-get q :a^b]` → `5`** — the ESCAPE HATCH works. **Shadowing is
    confined to the SELECTION SURFACE**, which is what makes the trade payable.
  ⚠ **"Matching `^`" is about SHADOWING, not about band availability.** `^` is
  refused in the dot band because a field access has no output key to re-key;
  `*` has no such problem — `r.ab*` descends and then deletes a layer, which is
  meaningful. Do NOT inherit `^`'s dot-band refusal along with its shadowing.
  **The exposure is narrower than it looks, and the slice must PIN this**: the
  genuinely SILENT case needs the subject to carry BOTH `:ab` (row-valued) and
  `:ab*`. With only `:ab*` present, the splat of `ab` is a field-MISS and errors
  anyway. *(Predicted, not measured — the surface does not exist yet; pin it.)*
  ⚠ **"FOR NOW" IS DOING REAL WORK, and the revisit is NOT free.** Adding the
  disambiguation error later turns a MEANING into an ERROR — the direction
  §3.6's monotonicity principle **forbids**. So if we ever want it, it must be
  decided before this surface has users. Recorded as a named cost, not a
  reversible default. Census at the ruling: **ZERO star-bearing field names
  exist in the tree** (HEAD-pinned; the only `.prologos` hit is `:diags*`, the
  operator itself in a commented corpus line, and the `.rkt` hits are the
  battery pin plus English prose), so the trade is currently free of victims.
- <a id="q-u29"></a>**⭐ Q_U29 — A MID-LEXEME `*` IS A GUIDED ERROR IN ALL THREE
  BANDS (option 2) [owner, 2026-08-08 — "Option 2"].** A star in a lexeme is the
  OPERATOR or it is nothing; there is no field-name fallback. `r{c*d}` and
  `r.c*d` become guided errors; `xs:c*d` is unchanged (already refused).
  **THE MEASURED STATE THIS REPLACES** — the three bands disagreed, and had for
  the whole track:
  | lexeme | `r{…}` block | `r.…` dot | `xs:…` ω |
  |---|---|---|---|
  | `ab*` (trailing) | `{:ab* 1}` field | `1` field | REFUSED |
  | `c*d` (mid) | `{:c*d 2}` field | `2` field | REFUSED |
  The ω guard is `#rx"[*]"` — **ANY-star, not trailing-star**, and its own
  comment misdescribes itself as trailing-only. So option 2 does not invent a
  refusal; it PROPAGATES the one the ω band already had, and retires a live
  three-way divergence.
  **Rejected-with-reason**: **option 1** (mid-star stays a field name
  everywhere) — uniform, but it DROPS the ω band's live refusal, acquiring
  permissive drift as a side effect of adding an operator, which is the
  direction this project does not drift by accident · **option 3** (keep today's
  per-band divergence) — smallest diff, but it institutionalizes `r{c*d}`
  working while `xs:c*d` refuses, the "two spellings of one form disagreeing"
  class DEFERRED 32 was filed for.
  **Why the breaking half is payable**: census at the ruling found **ZERO
  star-bearing field names in the tree** (HEAD-pinned over tracked sources; the
  only `.prologos` hit is `:diags*`, the operator itself in a commented corpus
  line, and the `.rkt` hits are the flatten battery pin plus English prose in a
  Racket comment). The break costs nothing that exists. And the ESCAPE HATCH is
  measured: `[map-get r :c*d]` → `2`.
  **Precedent it follows**: `split-caret-lexeme` REFUSES >1 caret and a leading
  caret rather than falling back to a field name — malformed operator position →
  guided refusal is already the house pattern for this family.
  **The error must name the escape**, per the "remedy points at a reachable
  spelling" rule: *"`*` is the layer-delete operator and attaches at the END of a
  segment; `c*d` is neither a field nor an operator. A field literally named
  `c*d` is reached with `[map-get r :c*d]`."*
- <a id="q-u30"></a>**⭐ Q_U30 — ALL SEVEN CARRIERS ARE IN SCOPE, TOKENIZER REPAIR
  INCLUDED [owner, 2026-08-09 — "I'd like to be able to reach all seven, so
  tokenizer repair included"].** This is the ruling that SIZES the design.
  Measured by the star-surface census (`wf_19cd5077-15b`): of the seven target
  carriers, **1 of 7** as-spelled (`m{0*}`) reaches the selection surface today ·
  **5 of 7** do when rewritten in-block · **2** (`x.0*`, `xs:0*`) reach nothing
  under ANY spelling without a tokenizer repair. So the in-block narrowing
  (census option R8) is REJECTED and R4 is IN: the two declining recognizers —
  `recognize-dot-ordinal` and `recognize-colon-annotation` — get a `*`-SPECIFIC
  relaxation of their trailing guards.
  ⚠ Those guards exist to protect `x.0N` / `x.1e3` / `:10abc` (Q_R2), so the
  relaxation must be keyed on `*` alone and must not re-open the numeric-suffix
  ambiguity. ⚠ They are TWINS — the P4e-0 attempt fixed the colon one and left
  the dot one untouched, which is how `x.0*` kept destroying the
  `$postfix-index`. Both move together or neither does.

- <a id="q-u31"></a>**⭐ Q_U31 — THE GLUED SIGMA SPELLING IS REFUSED; `*` AT TYPE
  LEVEL REQUIRES SPACES [owner, 2026-08-09 — "I'm fine with needing the spaces
  between a sigma spelling (I think that's more preferred for convention
  anyways)"].** `<(x : Nat)* Nat>` is legal today and elaborates correctly, with
  **ZERO corpus sites** — every written Sigma is spaced. It was attempt 1's
  headline casualty.
  **What the ruling BUYS, and it is structural, not cosmetic**: with the glued
  spelling refused, `*` is no longer genuinely ambiguous inside an angle group,
  so the design does NOT have to thread a context test through the grouper to
  protect Sigma. The census had this blocking the entire `'rangle` axis
  (constraint G1, 7 `star-symbol?` call sites reachable from 17
  `parse-infix-type` sites).
  **Cost**: one guided error at a `star-symbol?` call site. Monotone — the
  refusal may become a meaning later, never the reverse.
  ⚠ The refusal must be a PARSER-layer `parse-error` VALUE, not a preparse
  raise — see [DEFERRED 102](DEFERRED.md) for why that distinction is
  load-bearing (the parser path is abort-safe under a `data`; the preparse path
  was not, until this session).

- <a id="q-u32"></a>**⭐ Q_U32 — A BARE `*` IS REFUSED IN PATTERN POSITION; EVERY
  ARITHMETIC USE IS UNTOUCHED [owner, 2026-08-10 — "The `*` is used as
  multiplication… so as long as those aren't touched, I think it's fine to rule
  against bare `*` showing up in pattern positions"].** This discharges
  [DEFERRED 103](DEFERRED.md) as a LANGUAGE RULING and removes the constraint
  that a star mint be pattern-position-aware at a stage that cannot know it is
  in a pattern.
  **THE GUARD RAIL, PINNED BY MEASUREMENT** (`19560a7c`, all 0 errors) — these
  must not move, and a P4e pin must assert them:
  `* 3 5` → `15` · `[* 3 5]` → `15` · `map [* _ 2] '[1 2 3]` → `'[2 4 6]` ·
  `map [* 3 _] '[1 2 3]` → `'[3 6 9]` · `.(4 * 5)` → `20` (mixfix) ·
  `|> 5 [* _ 2] [* _ 3]` → `30` · `reduce * 1 '[2 3 4]` → `24` ·
  `let op *` / `[op 3 4]` → `12`.
  ⚠⚠ **THE DISCRIMINATOR IS POSITION, NOT SPELLING — and this is the finding
  that makes the ruling implementable rather than obvious.** The owner named
  four arithmetic uses; the sweep found a fifth class they did not: since
  Numerics N6e-E2 **operators are first-class values**, so `reduce * 1 xs` and
  `let op *` put a **BARE** `*` in argument and binding position and both must
  keep working. A refusal keyed on "a bare `*` token" therefore breaks live
  surface. It must key on the POSITION being a pattern.
  **THE DOMAIN, MEASURED** — what the refusal covers, all at `19560a7c`:
  · `match q | * -> 99` → `99`, **0 errors** (a legal catch-all binder today)
  · `match q | 2 * -> 99 | n -> n` → `Could not infer type`, **second arm
    silently deleted** — the DEFERRED 103 defect
  · `defn f | * -> 1` → `f : _ -> Int defined.`, `f 3` → `1`, **0 errors**
  · `defn f | red* -> …` → loses `f` itself → `Unbound variable`
  · `let [a *] pair` → *"pair expects 2 arguments, got 1"* — bracket
    destructuring reads as APPLICATION, so it is **not** in the domain.
  **CONSEQUENCE, ACCEPTED EYES-OPEN**: the ruling is BROADER than the defect. Two
  of the four covered shapes (`| *` alone, `defn f | *`) are legal and *harmless*
  today — they bind a variable named `*`. Refusing them too is the simpler rule
  and is monotone (a refusal may become a meaning; the reverse is barred by spec
  §3.6), and a rule that refused only the arm-deleting subset would have to
  discriminate on sibling-arm count at the same seat.
  **DESIGN DIVIDEND, and it is the point**: DEFERRED 103 framed this as needing
  pattern-awareness "at a stage that does not know it is in a pattern" — but the
  refusal does not have to live at the reader. The arm loss is observable at the
  pattern compiler, which knows exactly that it is in a pattern. Siting it there
  keeps the star mint's stage free of a context test, the same way
  [Q_U31](#q-u31) kept one out of the grouper. ⚠ Stated as an OBSERVATION for the
  mini-design to verify, **not** as a ruling on the site.
  ⚠ Sibling NOT discharged: `compile-match-tree`'s abort on a multi-form LITERAL
  arm (`| 2 3 ->`) is star-free and still live — see DEFERRED 103.
  *(The Q-label register lives at the end of [§ the census](#star-census) — one
  source, deliberately.)*

- <a id="q-u33"></a>**⭐⭐ Q_U33 — ADOPT R10, THE TOKEN-*TYPE* MINT: A SPACE IS
  SIGNIFICANT FOR `*` [owner, 2026-08-10 — "Let's take it, yes"].** At the
  TOKENIZER, where byte-adjacency is still visible, a `*` byte-adjacent to a
  preceding CLOSER gets a DISTINCT TOKEN TYPE instead of `'symbol`. **Counts are
  unchanged at every layer**, so A4 and the ≥15 item-counters never engage —
  which is precisely what killed attempt 1. `x{a}*` is the star step; `x{a} *`
  remains the first-class multiplication operator.
  ⚠ **CORRECTION to this ruling as first written (2026-08-10, measured before it
  shipped): there is NO "half-glued" error case for `*`, and the ARROW T1
  analogy does NOT carry.** ARROW's `->` is infix, so it has two sides and a
  broken middle; `*` here is postfix, and its right-hand side is already
  resolved by G3 identifier fusion — `ident-start?` admits `*`, so `*foo` is an
  ORDINARY IDENTIFIER. Measured: `[f x]*foo` → `(((f x) *foo))` and
  `[f x] *foo` → the **byte-identical** datum; only `[f x]* foo` makes the star
  a lone token. So the both-sides-glued shape never reaches R10 at all — it is
  an identifier, exactly as `int*` is at its 170 sites. **R10 fires only when
  the `*` is a LONE token byte-adjacent to a preceding closer.** No new
  diagnostic is owed here. (Written from the ARROW precedent by analogy, then
  probed — the assert-instead-of-measure failure this arc keeps recording,
  caught this time inside my own ruling text.)
  **⭐⭐ THE MEASUREMENT THAT FORCES IT — adjacency is the ONLY discriminator, and
  it exists only ABOVE the datum layer.** I looked for a cheaper one and the
  probes refuted it twice (2026-08-10, `4ea024f9`):
  · The datum ERASES glued-vs-spaced: `[f x]*` and `[f x] *` are **both**
    `(((f x) *))`, and `(f x)*` is byte-identical to both — which is also the
    shape of `bundle Bx := (Add Sub)*`.
  · **Hypothesis 1, REFUTED**: "the preceding item's sentinel head discriminates
    six of the eight sibling carriers" (`$select-brace`, `$bcast-step`,
    `$list-literal`, `$vec-literal`, `$brace-params`, `$mixfix` are all distinct
    heads). It does not, because the star's meaning depends on GLUING, which the
    datum has already lost.
  · **Hypothesis 2, REFUTED**: "sibling position is uninhabited by working
    arithmetic, so the erasure is harmless." It is inhabited —
    `pick [xs] *` → `[fn [x] [fn [y] [?m x y]]]` at **0 errors**, and identically
    for `pick cfg{database} *`, `pick '[1 2] *`, `pick @[1 2] *`,
    `pick {:a 1} *`. A bare `*` after a group is LIVE SURFACE in argument
    position (it is the first-class operator — the Q_U32 guard rail).
  So a datum-layer rule is unavailable for **every** sibling carrier, not just
  the two bare-group ones. This is the census's headline finding carried all the
  way to semantics, and it explains BOTH prior failures structurally rather than
  as mistakes: attempt 1 took adjacency from the grouper and paid with a count
  change; attempt 2 went below the grouper and had no adjacency left to carry.
  **WHAT IT COSTS, named**: a space becomes semantically load-bearing for `*`,
  and unlike `:` and `->` the spaced form here has a LIVE COMPETING MEANING.
  **Paid in theory, not in practice**: the census measured **ZERO** code sites
  for `)*` `]*` `}*` `>*`, so no file in the tree changes meaning.
  **PRECEDENT**: byte-adjacency already decides `:` ([Q_U8](#q-u8) mints
  `$bcast-step` only when the colon is glued to a non-empty local result), and
  ARROW T1 made `->` glued-vs-spaced significant with half-glued a guided error.
  **Rejected-with-reason**: narrowing back to the in-block spelling (census R8) —
  already rejected by [Q_U30](#q-u30), which put all seven carriers in scope ·
  a datum-layer marker (census R2, attempt 2) — refuted above, twice · a
  different spelling (census R9) — `$star` is already a live Sigma spelling with
  zero producers, `**` is `pow` in the mixfix table, and a `:`-keyword spelling
  collides with the `$bcast-step` mint.
  ⚠⚠ **THE HOME IS CORRECTED — "at the TOKENIZER" (as this ruling first said) is
  the ONE home that does not work.** Settled by measurement at the attempt-3
  mini-audit (`wf_c062f617-251` + a main-thread token probe), and the ruling's
  SUBSTANCE is what saves it: a **TYPE** discriminates where a **CHARACTER**
  cannot. A recognizer sees only the previous CHARACTER, and **`>` is not a
  closer character** — it is the last char of `->` `->>` `&>` `|>` `+>` `-N>`,
  all of which classify to `'symbol` and outrank `symbol`'s own priority.
  Measured, all byte-adjacent, all five would MINT under a char lookback:
  · `a &>* b` · `x |>* y` · `a ->* b` · `s ->>* t` · `p +>* q`
    → char-lookback mints **#t (WRONG)** · type-lookback mints **#f** ✅
  · `[f x]*` (`rbracket`) · `cfg{a}*` (`rbrace`) · `<a>*` (`rangle`)
    → **both** mint #t ✅ — and note `<a>*`'s closer is a real `rangle` TYPE
      while `&>` is `symbol`, so the type separates them perfectly.
  **Therefore the type must be assigned at a TOKEN-LEVEL pass that can see the
  previous token's TYPE — `disambiguate-tokens` is the only one that does** (it
  already re-types by previous-token type and carries exact
  `start-pos`/`end-pos`; it is where `>>` is merged). Cost: one extra round on
  files that currently do zero.
  ⚠ **And a grouper-level mint does not rescue it either**: `adjacent-to-base?`
  gives byte-adjacency to the previous TOKEN, which is `#t` for `&>*` as well —
  so the closer test is needed there too, AND the postfix mint at the grouper is
  **count-CHANGING**, which is attempt 1 exactly. Count-preservation is why the
  ruling is a TYPE mint and not a fusion.
  ⚠ Composes with [Q_U30](#q-u30)'s **R4** (relax the twin recognizers' trailing
  guards so `x.0*` / `xs:0*` stop destroying their own carriers) — same file,
  same kind of edit, and the twins are twins in OBLIGATION but **not in code**
  (`ascii-digit?` vs `char-numeric?`).

- <a id="q-u34"></a>**⭐ Q_U34 — `.( … )` IS ARITHMETIC TERRITORY: NO STAR MINT INSIDE
  MIXFIX [owner, 2026-08-10].** A closer-adjacent `*` inside a `.( … )` group is
  NOT minted. Accepted narrowing, named: **a star STEP cannot appear inside
  `.( … )`.**
  ⚠ **RECORDED LATE (2026-08-10) — the ruling was cited in code, tests and a
  commit message before it had an entry here.** `Q_U34` appeared 6 times across
  `parse-reader.rkt`, `test-path-selection.rkt` and D4 while the register still
  read "next free U34", i.e. the label was never allocated. That is the
  cited-but-unrecorded class this track fights, committed by me. Fixed with the
  entry, not with a note.
  **WHY**: `)*(`  is genuinely BOTH readings — postfix star on a closed group,
  and infix multiply — and no lookback separates them. Measured:
  `.((1 + 2)*(3 + 4))` → `21` at 0 errors with the star minted, before the gate.
  **What separates them is CONTEXT, and it is measurable**: infix `*` exists ONLY
  inside mixfix (`rec.n * 2` at command position is an error; `.(rec.n * 2)` is
  42). So outside mixfix a closer-adjacent star is unambiguous; inside it,
  arithmetic wins.
  **Realisation**: a frame stack in `disambiguate-tokens` mirroring
  `make-bracket-depth-rrb`'s — nine openers from the SHARED enumeration,
  kind-sensitive `lparen`, top-of-stack test, and a MATCHED-closer pop. Each of
  those four qualifiers was earned by a defect: the first cut pushed 4 of 9
  openers, used `memq` over the whole stack, and popped on any closer. See
  [§5.P4e-0 attempt 3 slice A](#p4e-0-a3).

- <a id="q-u35"></a>**⭐ Q_U35 — `*` AFTER A NON-SELECTION EXPRESSION IS REFUSED
  [owner, 2026-08-10 — "For now, yes, refuse. It's out of scope for this to be a
  non-selection expression for now"].** `[f x]*` and `(f x)*` take a guided
  refusal; `*` stays a PATH-SELECTION operator only.
  **THE GAP IT CLOSES**: [Q_U23](#q-u23) defines `*` as deleting the layer **the
  preceding STEP** created — and these two carriers have no preceding step. The
  preceding thing is an arbitrary application, so the rule was simply undefined
  for them. Either the star becomes a VALUE-LEVEL flatten (a different feature,
  with its own typing and the `Functor`/`Foldable` trait question
  [Q_U9](#q-u9) already named as the principled door) or it is refused.
  **⭐ WHAT THE REFUSAL BUYS, and it is structural**: it keeps the star sentinel
  INSIDE the selection surface. Measured before the ruling, `postfix-star` also
  mints in ordinary application arguments (`f [g x]* y`), map-literal values
  (`{:k [f x]*}`) and nested brackets — all legal today, since `*` is a
  first-class operator (the [Q_U32](#q-u32) guard rail). Under a datum rename each
  would have become `Unbound variable $postfix-star`, a leaked internal sentinel.
  Refusing dissolves that whole blast radius instead of arming it site by site.
  **COST, stated**: slice A delivers **TWO** usable carriers (`x{a}*`,
  `xs:{a}*`), not four. `[f x]*` / `(f x)*` get a guided refusal naming the
  separate-flatten spelling — the same shape Q_U9 uses for `List`.
  **Monotone** (spec §3.6): the refusal may become a meaning later, never the
  reverse. Zero corpus sites for either spelling.
  ⚠ Does NOT change [Q_U30](#q-u30)'s seven-carrier scope; it rules on what two of
  them MEAN. `xs:0*` / `x.0*` remain blocked on [DEFERRED 105](DEFERRED.md).

- <a id="q-u36"></a>**⭐⭐ Q_U36 — THE FUSE ARM IS A POSITIVE LIST OVER THE
  PREDECESSOR, AND THAT IS WHAT MAKES P4e-1a TRACTABLE [owner, 2026-08-10].**
  The rule is: **fuse iff the head of the PRECEDING item is in the small closed
  set of SELECTION heads**; [Q_U35](#q-u35)'s guided refusal is the genuine
  `else` catch-all. Never an enumeration of the heads to REFUSE.
  **WHY IT IS A RULING AND NOT A CODING PREFERENCE — it resolves the census's
  own ⭐BLOCKING item.** Tier-O **O7** records that `$star-step`'s membership is
  *"CONDITIONAL AND RECURSIVE — a flat head list cannot say member-iff-its-
  payload-is-a-member"*, and that is precisely the shape that killed slice B;
  `access-sentinel?`'s in-file comment reaches the same verdict independently
  (*"a sentinel that cannot be expressed in the head-set vocabulary the rest of
  the family shares is a design smell, and it was pointing at the real defect the
  whole time"*). A positive PREDECESSOR test sidesteps O7 entirely: it never asks
  whether the star is a member, only whether the thing before it is a selection
  head — a flat closed-set test on a **different datum**. O7 was not carried into
  P4e-1's OWED list; it is discharged here.
  **WHAT IT BUYS, and it is the whole scope argument**: the P4e-1a mini-audit
  (`wf_9bbe5f5a-9e0`) measured the arrival surface at **10 minting carriers × 19
  arrival contexts**, not the 4 × 11 this document had enumerated (see
  [§5.P4e-1a](#p4e-1a)). Under a NEGATIVE list that 4.3× under-count is a defect
  generator — it is exactly the bad-enumeration class that produced the last
  three blocking defects. Under a POSITIVE list the population stops bearing on
  CORRECTNESS at all: every carrier in every context either fuses (selection
  predecessor) or refuses (everything else), by construction. The inventory
  remains load-bearing for **gate coverage**, which is a test obligation, not a
  code one.
  **In-tree precedent, named**: `pipeline.md`'s `definitely-not-map?` inversion
  (CIU T6 P2.b slice 1) — a positive list with a conservative `#f` default, so a
  new node is safe BY CONSTRUCTION. Same direction, same reason.
  Rejected-with-reason: enumerate the non-selection heads (the six carriers this
  document omitted are the standing proof that the non-selection side is not
  knowable in advance); make `$postfix-star` a head-set member (O7 — its
  membership is conditional, and `access-sentinel?` requires `(list? x)` so a
  bare atom can never satisfy it anyway).

- <a id="q-u37"></a>**⭐⭐ Q_U37 — THE STAR'S REFUSAL IS DECIDED IN TERRITORY,
  NOT AT PREPARSE-EVERYWHERE [owner, 2026-08-11 — assent to the recommended
  course after the 1a-iii verify].** The fold fuses ONLY in selection territory
  ([Q_U36](#q-u36)'s positive predecessor test) and otherwise **LEAVES THE STAR
  IN PLACE** for the downstream seat that owns the territory:
  · **expression territory** → `parse-datum`'s guided [Q_U35](#q-u35) refusal
    (the single choke point every head-dispatched arm misses);
  · **type territory** (`<…>`, incl. preparse-synthesized `$angle-type`) →
    `unwrap-angle-type`'s [Q_U31](#q-u31) Sigma-specific refusal;
  · **data territory** (quasiquote) → NOTHING is rewritten; the star is captured
    as the `*` the user wrote (the lowering normalizes the sentinel back).
  **WHY IT IS A RULING**: it is [Q_U34](#q-u34)'s own logic extended one layer in
  — `.( … )` is arithmetic territory, so no mint inside mixfix; `<…>` is where
  `*` is Sigma's SEPARATOR; a quasiquote body is data. The 1a-iii attempt's
  refusal-at-preparse marker assumed every star was the fold's business, and the
  adversarial verify measured the two consequences at once: the marker PRE-EMPTED
  the Sigma seat (its guided refusal shipped unreachable — Q_U31's message never
  fired) and it put a three-element list where the quasiquote lowering expects a
  symbol. One wrong assumption, two symptoms; two patches would have been two
  workarounds.
  **NAMED COST, accepted eyes-open**: slice 1a-i's preparse datum invariant ("no
  unconsumed star survives preparse") is RESTATED — preparse genuinely cannot
  decide every case, because the context that decides lives downstream. The gate
  becomes: *an unconsumed star is refused (or captured as data) by the seat that
  owns its territory, and the internal name never reaches the user* — enforced by
  the E2E message/abort/leak pins plus per-seat positive pins, not by a blanket
  preparse scan. Narrowing an instrument to fit code is the move this arc warns
  against; the narrowing here is to the semantic claim, and the claim was wrong.

- <a id="q-u38"></a>**⭐⭐ Q_U38 — A NOMINAL-JOIN COLLISION IS REFUSED, AND
  CONSERVATIVELY ON THE `'dyn` TAIL [owner, 2026-08-11 — "Refuse, and
  conservatively on the dyn tail"].** A `*` whose lifted keys would collide —
  with a sibling branch's written key, or with another splat's lifted key — is a
  guided error, not a silent merge. Where the subject's row is CLOSED the
  collision is provable and refused on proof; where the row is `'dyn`-tailed the
  lifted key set is only a LOWER BOUND, and the refusal fires on POSSIBILITY.
  **WHAT THIS OVERTURNS**: [Q_U23](#q-u23)'s "P4e needs no P5 machinery for it,
  because P3a already landed strict merge" — **REFUTED, and by twice as much as
  the refutation first written**. There are **TWO** silent last-write-wins sites,
  not one: `make-record` (syntax.rkt, `;; last write wins`) is the TYPE-level
  constructor and IS on the select path via `select-assemble-row`
  (typing-core.rkt), and its VALUE twin `entries->value` (reduction.rkt) folds
  `champ-insert`, which also overwrites. The design named one and stopped.
  **WHY THE LANDED GATE CANNOT DO IT — the mechanical root**:
  `select-branch-top-keys` (syntax.rkt) takes **exactly one parameter**, the
  branch's step list. No ctx, no type, no subject. `dup-output-key` and
  `mixed-sorts?` (parser.rkt) are pure static folds over it, so **no arm added
  there can express a subject-derived key**. The check therefore MOVES to typing,
  at the row-assembly seat, which is the first place a closed row's fields are
  visible. ⚠ `mixed-sorts?` is the more dangerous of the two blind gates — it
  runs one line BEFORE `dup-output-key` and is the sole guarantor of an invariant
  both assembly points consume by inspecting their FIRST component only, so its
  residue is a silently WRONG CARRIER for the level, not an error.
  **THE ENTAILMENT, accepted eyes-open**: on an open-tailed subject, `*` plus ANY
  sibling branch is refused; a star as the SOLE branch has nothing to collide
  with and stays legal.
  **⚠ A THIRD FACT NO FACET FOUND, and it constrains how the rule may be
  PHRASED**: the two layers disagree about field ORDER. `make-record`
  CANONICALIZES (sorts by label after deduping); `entries->value` does NOT (the
  champ carries insertion order). Measured at HEAD: value `{:url "u",
  :pool-size 10}` against type `{:pool-size Int :url String}` from one
  expression. So a rule phrased as *"the later one wins"* is well-defined only
  against the ENTRIES list and never against the printed row — which is one more
  reason the answer is refusal rather than a merge. Any test pinning splat output
  must pin value order and type order SEPARATELY.
  **CALIBRATION, stated because it is the honest cost**: "strict merge" is a
  SELECT-SURFACE-ONLY policy. Map literals have no duplicate gate (`{:a 1 :a 2}`
  → `{:a 2}`, 0 errors), `map-merge` is documented right-wins, `record-extend` is
  explicitly right-priority. This ruling makes selection stricter than every
  surface beside it. Accepted: the star is a STRUCTURAL operator and a silently
  dropped layer is the failure this whole arc exists to avoid.
  **The remedy the refusal names is [Q_U24](#q-u24)'s `*_`** — see
  [Q_U39](#q-u39) for where it is spellable. ⚠ `*_` removes collisions in the
  ORDINARY case, **not universally** — a sibling literally named `database-url`
  still collides, and two layers can synthesize the same key (`{:a-b {:c 1} :a
  {:b-c 1}}` → both `a-b*_` and `a*_` yield `:a-b-c`). The refusal machinery
  covers `*_` too; it just fires rarely there instead of nearly always.
  **Substrate note**: a defined-collision primitive already exists and is unused
  — `champ-insert-join` (champ.rkt) takes a `join-fn`, **zero production
  callers**. It has NO type-layer twin (`make-record` has three parameters and no
  join), so a merge ruling would have needed new type-side substrate either way.
  ⚠ Prior ruling that already conceded the premise: the parser refuses `*` with
  `^` because *"a splat lifts N keys, so there is no single output key for `^` to
  re-key"* (parser.rkt) — the cont axis is already closed to `*`.

- <a id="q-u39"></a>**⭐ Q_U39 — THE CLOSER-ADJACENT `*_` MINT IS A FOLLOW-ON
  SLICE, NOT PART OF THE SEMANTICS SLICE [owner, 2026-08-11 — "Split it into a
  follow-on slice makes sense to me"].** P4e-1b lands the flatten, [Q_U38](#q-u38)'s
  refusal, and `*_` **in the fused-identifier band only** — which costs nothing
  lexically, because it already works there. Giving `c{a}*_` / `xs:{a}*_` a
  spelling is its own slice, with its own adversarial verify.
  **THE MEASURED ASYMMETRY** (all at HEAD, one probe): `cfg{database*_}`,
  `cfg.database*_` and `rows:tags*_` all reach the guided message and are
  DISTINGUISHED from their bare-`*` twins (`split-star-lexeme` already returns
  `'flatten-synth`). `cfg{database}*_` and `rows:{tags}*_` give a bare
  **`Unbound variable`** — the mint gate is `(string=? lexeme "*")`, EXACT
  equality (parse-reader.rkt), so `*_` after a closer lexes as an ordinary
  identifier. ⚠ The diagnostic does not even name `*_`; same wording defect as
  `values.*`.
  **WHY SPLIT RATHER THAN WIDEN**: `$postfix-star` is deliberately a BARE ATOM,
  and that choice is what made 1a-ii's Tier-O arms TWO LINES instead of a
  checklist. Adding `*_` means a second bare sentinel or a payload — and a
  payload re-opens the arity/head-set questions 1a settled. Either way it re-runs
  `pipeline.md` § "a new sentinel, an old recognizer" (leak gate · fuse arm ·
  `unmint-star-for-echo` · `pattern-var?` · `parse-datum` · `unwrap-angle-type`)
  **one slice after we last ran it** — the mid-flight widening *Watching 9*
  records as where this arc introduces its defects (3 data points).
  **THE COST, named**: for one slice the two result-level carriers get a refusal
  that must teach a REWRITE into the other band (`m{a b}*` → `m{a*_ b*_}`), not a
  one-character suffix fix — a wart the user meets exactly when already stuck,
  and a partial departure from Q_U24's "land together" rationale. Monotone, so
  the spelling can be added at any time.
  **⚠ SELF-CORRECTION, recorded because it nearly priced the decision wrong**: I
  first told the owner that widening the mint "costs a monotonicity break." **Too
  strong.** `c{a}*_` is an ERROR today (`Unbound variable`) unless the user has
  deliberately written `def *_ := …` — which does work (measured: `*_ : Int
  defined.`). So widening is **error → meaning** in every practical case, i.e.
  monotone; the non-monotone sliver is only the deliberately-bound case, and it
  is the SAME trade [Q_U33](#q-u33) already accepted for bare `*`, where the cost
  was strictly HIGHER (`*` is a live first-class operator with ~76 spaced
  arithmetic sites). The overstatement made `*_` look more expensive than it is,
  at the exact moment `*_` was the remedy under discussion.

- <a id="q-u40"></a>**⭐⭐ Q_U40 — THE STAR ATTACHES *OUTER*: IT DELETES THE LAYER
  THE PRECEDING STEP CONTRIBUTED [owner, 2026-08-11 — "OUTER seems to be looking
  like the right shape"].** The rule, in one sentence:
  > **`*` deletes the container layer contributed by the preceding step, joining
  > its contents into the enclosing level. The join's SORT follows the CONTENTS**:
  > vectors **concatenate**; Maps **join keywise** ([Q_U38](#q-u38) refuses
  > collisions, [Q_U41](#q-u41)'s `*_` is the remedy); keyless/ordinal components
  > **concatenate in written order** (spec §3.6 rule 5); leaves **error** (rule 4).

  **ONE rule across BOTH axes** — block and broadcast, nominal and vector. That
  uniformity is the ruling's whole case: it is [Q_U23](#q-u23)'s "sort-generic"
  read literally, and it is the only reading under which spec **§8 Q4**'s
  affirmative answer does work on both axes.
  **THE WORKED BATTERY** (subjects measured at HEAD; `rowsv := @[{:tags @[1 2]}
  {:tags @[3]}]`, `rowsm := @[{:cfg {:a 1}} {:cfg {:b 2}}]`,
  `m := {:a {:x 1} :b {:y 2}}`):
  · `rowsv:tags*` → `@[1 2 3]` — contents are vectors, concat. **The spec's own
    `ω·ω→ω` and its normative example** (`build.modules:diags*:msg`, §10.4).
  · `rowsv:{tags}*` → **refused** — every element contributes `:tags`; the
    remedy is the DESCENT spelling, not `*_` (see Q_U41).
  · `rowsm:cfg*` → `{:a 1, :b 2}` — Maps, distinct keys, keywise join.
  · `rowsm:{cfg}*` → `{:cfg {:a 1, :b 2}}` — same key, both Map-shaped, spec
    §3.6 rule 2 recursing.
  · `m{a b}*` → `{:x 1, :y 2}` · `cfg{database}*` ≡ `cfg.database` (n=1 is an
    identity, exactly as `{p^}` is an honest 1-tuple at n=1 per §3.3).
  · `vv:{0 1}*` → `⟨1 2 3 4⟩` — **a matrix RAVEL falls out with no special
    case**; ordinal/keyless layers concatenate and so **can never collide**, so
    Q_U38's refusal structurally never fires on them.
  **⭐ THE EQUATIONAL LAW IT PRODUCES** (call it **L★**), in the family of §3.6's
  `{p:a p:b} ⟶ p:{a b}`:
  > **`x{p₁* … pₙ*} ≡ x{p₁ … pₙ}*`** — distributing the star over every branch
  > equals starring the result — **PROVIDED the preceding step is a BLOCK, with
  > no intervening ω** ⚠ **AND the branches' contents are MAPS —
  > [Q_U45](#q-u45), 2026-08-12.**

  ⚠⚠ **DO NOT READ THE QUALIFIER BELOW AS COMPLETE — [Q_U45](#q-u45) WIDENED IT.**
  The ω qualifier recorded here is necessary and NOT sufficient: L★ also fails for
  VECTOR contents with no ω anywhere, and it fails on **ARITY**, not on order
  (`mm{zz* aa*}` is an n-TUPLE of vectors; `mm{zz aa}*` is one flat vector). The
  Map side is equal only because a Map-valued branch star SPLICES its keys, which
  is the same operation the result form's keywise join performs — and every worked
  example in this ruling's battery used Maps, which is why the gap survived. Q_U45
  also records the surface-observable form: `m2{a* b}` is LEGAL (splice `a`, keep
  `b`'s key) while `mm{zz* aa}` is an L4 mixed-sorts error.

  ⚠ **THE QUALIFIER WAS MISSING WHEN THIS RULING WAS FIRST WRITTEN, and the
  owner's question is what found it** (2026-08-11, same session). **Under a
  BROADCAST the two spellings act on DIFFERENT LAYERS and are NOT equivalent** —
  branch stars delete into the **per-element block level**, while a trailing star
  deletes the **container layer the ω step contributed**. One level apart.
  Measured subject `m : [PVec {:a {:x Int} :b {:y Int}}]`:
  · `m:{a* b*}` → `@[{:x 1, :y 2} {:x 3, :y 4}]` — per-element splice, two in two out
  · `m:{a b}*` → **error** — cross-element join; `:a` shared → recurse → `:x`
    shared on LEAVES (§3.6 rule 4)
  Without the ω the law holds (`m2{a* b*}` ≡ `m2{a b}*` ≡ `{:x 1, :y 2}`).
  **The divergence is a FEATURE** — per-element splice and cross-element join are
  both wanted and the surface distinguishes them exactly where the semantics
  differ — but a test must pin the **NON**-equivalence under broadcast, not only
  the equivalence without one, or the next reader will assume the law is
  unconditional. ⚠ Note also that a star written INSIDE a block was never subject
  to this ruling's OUTER/INNER question at all: it belongs to its branch
  unambiguously. Q_U40 governs only a star written AFTER a closer.

  The BRANCH form is nonetheless **strictly more expressive**, because the stars
  need not be uniform: `m{a* b}` → `{:x 1, :b {:y 2}}` (splice `a`, KEEP `b`'s
  key), which the result form cannot express. Selective splice vs total splice;
  the law says the total form is the all-branches special case.
  **REJECTED, each with its reason:**
  · **INNER** (the star joins the innermost step) — on the broadcast axis it
    degenerates to a **NO-OP**: `rowsm:cfg*` ≡ `rowsm:cfg`. That is precisely the
    "identity wherever the head key survives" defect [Q_U23](#q-u23) diagnosed
    when it retired `.*`; shipping a new operator whose broadcast behaviour is
    silently nothing repeats the thing that ruling fixed.
  · **SPELLING-DETERMINED** (fused ⇒ inner, closer ⇒ outer) — free structurally,
    but two near-identical spellings would mean materially different things with
    no visual cue.
  · **BLOCK-GENERIC / VECTOR-ONLY-UNDER-BROADCAST** — refuses 4 of 7 battery
    cases including the ordinal ravel, and once the rule above is stated as ONE
    sentence the "unruled" framing stops being accurate. Conservatism buying
    nothing.
  **⚠ SELF-CORRECTION, and it was the objection that had been blocking OUTER**: I
  argued that OUTER's cross-element join is the "coincidental" merge §3.6 forbids.
  **Mis-aimed.** Ruling B governs merging *sibling branches within a block* — its
  witness test is about ZIPPING TWO BRANCHES. A star-induced layer-delete is a
  **fold over ONE container**, which is the explicit act §3.1 sanctions
  (*"deleting a layer is only ever the explicit act `*`"*). The spec never
  subordinates the star's join to Ruling B's witness requirement; inheriting its
  COLLISION discipline (what Q_U38 did) is a separate and deliberate choice.
  **IMPLEMENTATION DIVIDEND**: OUTER's representation is **the one already
  shipped** — the closer-adjacent fuse emits `($select-path <preceding step>
  $postfix-star)`, a wrapper around the whole preceding step, which IS the OUTER
  shape. Only the fused-identifier band (`:tags*`, `.a*`) needs normalizing
  OUTWARD, lifting the star from inside the lexeme to the wrapper. INNER would
  have required normalizing the other way.
  **⚠ OPEN, and 1b must settle it**: same output key with BOTH values VECTORS
  (the `rowsv:{tags}*` shape). §3.6 rule 2 needs Maps, rule 3 needs two branches
  with identical spines — so it falls to rule 4's error. Whether same-key vector
  values should instead CONCATENATE is a choice the star's join has to make and
  Ruling B does not cover. Refusing is monotone; decide it explicitly rather than
  inheriting rule 4 by accident.
  **⚠ [DEFERRED 105](DEFERRED.md) — the REPRESENTATION half of its blocker is
  DISCHARGED, the COUNT half is NOT.** 105 records that R4 "cannot land until the
  star's DATUM REPRESENTATION is decided — a wrapper sentinel, or a widened
  `$postfix-index` arity." Q_U40 decides it: the wrapper. But 105's actual defect
  was that restoring the carrier TOKEN makes the star a separate datum ITEM, and
  the fuse that now consumes that item runs inside preparse — so whether the
  count-gated form validators observe the pre-fuse or post-fuse datum is
  **unmeasured**. Do NOT reopen R4 on the strength of this ruling alone.

- <a id="q-u41"></a>**⭐ Q_U41 — `*_` IS NOMINAL-ONLY; OVER A POSITIONAL LAYER IT
  IS A GUIDED REFUSAL [owner, 2026-08-11].** `*_` synthesizes each lifted key
  from **the deleted layer's KEY** — so it applies exactly where the deleted
  layer HAS keys: a block branch, a block result, or a **map-generic broadcast**
  (§3.2.3). Over a deleted VECTOR layer it refuses and names the alternative.
  **THE MECHANISM IS `^_`'s, and that is why this is not a special case.** §3.4:
  *"synthesize the key from the surviving path (`a.b^_ ⇒ :a-b`)"*. A positional
  layer has no surviving key to synthesize from. ([Q_U24](#q-u24)'s ruling that
  `*_` follows `^-_`'s rule rather than `^_`'s is untouched — that is about
  COLLAPSE vs relabel-in-place, a different axis, and `split-star-lexeme` already
  records it at its own site.)
  **`*_`'s BEST CASE is the map-generic broadcast — and it is Q_U24's own
  motivating example, which [Q_U40](#q-u40) is what makes reachable.** Measured
  at HEAD, `regions := {:eu {:host "eu.example.com" :port 80} :us {…}}` gives
  `regions:{host port}` → `{:eu {:host … :port …} :us {…}}`, keys preserved. So:
  · `regions:{host port}*` → **refused**, both elements contribute `:host`+`:port`
  · `regions:{host port}*_` → `{:eu-host …, :eu-port 80, :us-host …, :us-port 443}`
  **INDEX-SYNTHESIS REJECTED** (`rowsv:{tags}*_` → `{:0-tags …, :1-tags …}`),
  three reasons in increasing seriousness:
  1. **Often not typeable.** `rowsv : [PVec …]` — the length is not in the type,
     so the output row's field COUNT would be runtime-determined, which a closed
     row cannot express. It would type only over a TUPLE (`rowsm : ⟨… …⟩`,
     static arity) — i.e. the feature would work for some vector subjects and not
     others, on a `PVec`-vs-`⟨⟩` distinction the user never wrote.
  2. **It inverts the key-sort thesis.** §1.1 + §8 Q2: *"nominal key IDENTITY
     carries the meaning, order does not."* Index-derived keys make POSITION
     carry nominal meaning. Spec **§8 Q3** (nominal→ordinal demotion order) is
     still OPEN and *"requires a canonical key order or a prohibition"*; this is
     the same frontier from the other side, equally unruled. If index-provenance
     is ever wanted, **§8 Q3 is where it belongs** — monotone either way.
  3. ~~**It is the wrong remedy for the actual mistake** — the user who wrote
     `rowsv:{tags}*` meant `rowsv:tags*`.~~ **STRUCK by [Q_U42](#q-u42)
     (2026-08-11, same session).** Under Q_U42 `rowsv:{tags}*` is not a mistake
     at all: it CONCATENATES to `{:tags @[1 2 3]}`, and the two spellings mean
     different, both-useful things that track the language's own
     descent/projection distinction — `rowsv:tags*` → `@[1 2 3]` (key dropped)
     versus `rowsv:{tags}*` → `{:tags @[1 2 3]}` (key kept). **Q_U41's CORE is
     untouched** (provenance needs a key; a positional layer has none) and
     arguments 1 and 2 stand on their own; this third one does not, and is struck
     rather than quietly reworded so the reversal stays visible.
  **THE REFUSAL'S TWO BRANCHES**, restated under Q_U42:
  · the plain `*` already does the job → say so. `rowsv:{tags}*_` is refused
    because the deleted layer is POSITIONAL, and the advice is **drop the
    underscore**: `rowsv:{tags}*` → `{:tags @[1 2 3]}` is what was wanted.
  · there is no join to be had at all → **drop the star**. Measured:
    `pair := @[{:host "a"} {:host "b" :port 1}]` (heterogeneous ⇒ a tuple) has
    `pair:{host}*` erroring on LEAVES (§3.6 rule 4) and `pair:host*` likewise, so
    `pair:host` → `@["a" "b"]` is already the answer. Forcing a join there is an
    attempt to turn positional data into nominal data — §8 Q3's territory, not
    the star's.

- <a id="q-u42"></a>**⭐ Q_U42 — THE KEYWISE JOIN CONCATENATES SAME-KEY VECTOR
  VALUES [owner, 2026-08-11 — "(b) Concatenate gives our spellings more
  expressivity, and I think brings us closer to our design goals"].** When
  [Q_U40](#q-u40)'s join recurses into a shared output key whose two values are
  both VECTORS, it **concatenates** them rather than erroring.
  **WHERE IT ARISES — one level DOWN, not at the top.** `rowsv:{tags}*` deletes
  the ω layer and joins the two Maps keywise; both carry `:tags`, and the values
  are `@[1 2]` and `@[3]`. Spec §3.6 rule 2 wants both Map-shaped (no); rule 3
  wants two branches with identical spines (no — these are two ELEMENTS of one
  traversal, not sibling branches). So the default was rule 4's *"at least one
  side a leaf → error"*, reached **by elimination rather than by anyone having
  considered vectors**. That is why it needed a ruling instead of an inheritance.
  **THE ARGUMENT, and it is Q_U40's own**: the top-level rule already says
  *vectors concatenate*. Erroring one level down would make the SAME operator say
  "vectors concatenate" at depth 0 and "vectors error" at depth 1. Under Q_U42
  the join is ONE recursive rule at every depth — **Maps recurse · vectors
  concat · keyless components concat · leaves error** — which is the uniformity
  Q_U40 was adopted for. It composes: `d := @[{:a {:t @[1]}} {:a {:t @[2]}}]`
  gives `d:{a}*` → `{:a {:t @[1 2]}}` (recurse on `:a`, concat on `:t`).
  **RULING B DOES NOT FORBID IT.** Its *"zipping vectors that merely happen to be
  siblings has no witness and stays an error"* forbids POINTWISE merge without an
  alignment witness. Concatenation is TOTAL and needs no witness. §3.6 is silent
  on concat, not against it. *(Recorded explicitly because the opposite reading —
  taking a Ruling B line as governing an operation it does not govern — is the
  error that had blocked [Q_U40](#q-u40) for two rounds.)*
  **COST, stated**: concat merges data without provenance — which element did
  each item come from? Accepted, because the identical concern applies to the
  ALREADY-ADOPTED top-level mapcat (`rowsv:tags*` → `@[1 2 3]` loses exactly the
  same provenance, spec §3.5), so it does not distinguish the readings.
  **NOTHING ELSE MOVES**: non-vector shared values are unaffected —
  `pair:{host}*` errors on leaves under either reading.
  **CONSEQUENCE, and it is why this is not a small ruling**: it makes
  `rowsv:{tags}*` a FEATURE rather than a refusal, and the two star spellings now
  track the language's own descent/projection distinction —
  `rowsv:tags*` → `@[1 2 3]` (key dropped) versus `rowsv:{tags}*` →
  `{:tags @[1 2 3]}` (key kept). It also STRIKES [Q_U41](#q-u41)'s third
  supporting argument; see there.

- <a id="q-u44"></a>**⭐ Q_U44 — A KEYED LAYER'S POSITIONAL JOIN TAKES CANONICAL
  KEY ORDER, AND `x{a* b* c*}*` IS THE ORDER-RECOVERING SPELLING [owner,
  2026-08-11].** When [Q_U40](#q-u40)'s join concatenates the values of a **keyed**
  layer into a vector, the contents are ordered by **canonical key order** (the
  `symbol<?` order `make-record` already canonicalizes with) — not by champ hash
  order, and not by written order.
  **THE DEFECT IT REPLACES, measured at 1b-iii attempt 1**: contents were read
  via `champ-entries`, so `mm{zz aa mm}*` and `mm{mm aa zz}*` were
  **byte-identical** at `@[3 4 1 2 5 6]` — neither written order nor anything a
  reader could predict, and liable to move if the champ implementation changes.
  **⭐ WHY THE TWO SPELLINGS STILL AGREEING IS *CORRECT*, not a residual wart.**
  Under canonical order those two spellings still produce the same answer, and
  that is right: spec §1.1 + §8 Q2 rule that *nominal key IDENTITY carries the
  meaning, order does not*, so for a KEYED block the two spellings **are the same
  selection**. Hash order was not wrong for collapsing them — it was wrong for
  being ARBITRARY and UNSTABLE. Canonical order removes exactly that and leaves
  the key-sort thesis intact. *(Recorded because the first analysis of this
  question treated the collapse as the defect and recommended refusal on that
  basis — the wrong diagnosis produced the wrong recommendation.)*
  **THE ORDER-RECOVERING SPELLING [owner]**, and it introduces no new mechanism:
  ```
  mm := {:zz @[1 2] :aa @[3 4] :mm @[5 6]}
  mm{zz aa mm}*      →  @[3 4 5 6 1 2]     canonical (aa · mm · zz)
  mm{zz* aa* mm*}*   →  @[1 2 3 4 5 6]     WRITTEN order
  ```
  Each inner star deletes its own branch's key layer — whose contents are a
  SINGLE vector, so no order is fabricated — and contributes it as a **KEYLESS**
  component. Three keyless components make a keyless level, which spec §3.3
  defines as *"tuple components in written order"*. The outer star then deletes a
  layer that is genuinely ordered. **The user recovers order by opting into
  KEYLESSNESS, which is already the language's own carrier of positional
  meaning.**
  **The pairing is [Q_U38](#q-u38)'s shape**: a principled default plus a
  first-class way to ask for the other thing (there, refuse + `*_`; here,
  canonical + `{a* b* c*}*`).
  **Rejected-with-reason**: *written order by default* — contingent on an
  OrderedMap the language does not have; deriving it would force the star's two
  halves to compute contents differently by layer sort. *Outright refusal* —
  costs expressivity the design intends, and the "surprising order" objection
  dissolves once the remedy is IN the language.
  **⚠ OBLIGATION IT CREATES**: `mm{zz* name}` mixes a KEYLESS branch with a KEYED
  one — an L4 sort error, and exactly attempt 1's defect #2 shape (which aborted
  in `make-record` instead of erroring). The parser-gate carve-out must make that
  a **guided** L4 error: users following the documented recovery spelling will
  hit it whenever they mistype, so this is now an ergonomics requirement, not
  only a correctness one.
  **Next free Q-label: U45.**

- <a id="q-u45"></a>**⭐⭐ Q_U45 — L★'s QUALIFIER WIDENS: THE DISTRIBUTION LAW HOLDS
  ONLY WHERE THE JOIN IS KEYWISE. THE VECTOR CASE IS A DELIBERATE
  NON-EQUIVALENCE, NOT A COLLISION WITH [Q_U44](#q-u44) [owner, 2026-08-12].**

  **THE LAW, stated once — it is cited constantly and was written down nowhere in
  one piece, which is why the defect below survived three sessions:**
  > **L★  `x{p₁* … pₙ*}  ≡  x{p₁ … pₙ}*`** — *star every branch* equals *star the
  > whole result.*

  **THE AMENDMENT — one clause; NO program changes meaning.** L★ holds provided
  the preceding step is a BLOCK, **with no intervening ω, AND the branches'
  contents are Maps** — equivalently, the star's join is KEYWISE, so each branch
  star's contribution is **absorbed** by the enclosing level rather than
  **stacked** as a keyless component. `mm{zz aa}*` and `mm{zz* aa*}` keep exactly
  the values [Q_U40](#q-u40) and Q_U44 already give them; what changes is that we
  stop asserting they are equal, and the vector case is PINNED as a
  non-equivalence beside the ω one.

  **⭐⭐ WHY IT FAILS FOR VECTORS — ON *SHAPE* BEFORE ORDER EVER ENTERS.** This
  was first framed (by me) as an ordering conflict with Q_U44. It is not. With
  `mm := {:zz @[1 2] :aa @[3 4] :mm @[5 6]}`:

  | spelling | result | why |
  |---|---|---|
  | `mm{zz aa mm}*` | `@[3 4 5 6 1 2]` : `[PVec Int]` | ONE keyed layer deleted; contents = three vectors; concat in CANONICAL order (aa·mm·zz) |
  | `mm{zz* aa* mm*}` | `@[@[1 2] @[3 4] @[5 6]]` : `⟨[PVec Int] …⟩` | each branch deletes ITS OWN key layer, whose contents are a *single* vector → **one keyless component each**; three of them = a TUPLE, written order |
  | `mm{zz* aa* mm*}*` | `@[1 2 3 4 5 6]` : `[PVec Int]` | Q_U44's recovery — the outer star deletes that keyless layer; keyless contents concat in WRITTEN order |

  Rows 1 and 2 are L★'s two sides, and they differ in **ARITY** — an n-tuple of
  vectors against one flat vector. Row 2 is Q_U44's own text, not an inference
  (*"whose contents are a SINGLE vector, so no order is fabricated — and
  contributes it as a KEYLESS component"*). The Map side is equal because a
  Map-valued branch star **splices its keys** into the enclosing block level,
  which is the same operation the result form's keywise join performs:
  `m2{a* b*}` ≡ `m2{a b}*` ≡ `{:x 1, :y 2}`. **Every worked example behind L★
  used Maps. That is why nobody caught it.**

  **⭐ AND THE NON-EQUIVALENCE IS Q_U44's MECHANISM SEEN FROM THE OTHER SIDE, not
  a conflict with it.** Q_U44's whole device is *order is recovered by opting into
  KEYLESSNESS*. The distributed form IS opting into keylessness. Rows 1 and 3 —
  both flat — differ only in order, and that difference is precisely what Q_U44
  sells. Row 4 makes the other half visible: `mm{aa zz mm}*` is byte-identical to
  row 1, because §1.1 + §8 Q2 rule that for a KEYED block, key IDENTITY carries
  the meaning and order does not.
  ⚠ **A precision the deliberation turned on**: the Map join is order-insensitive
  because the RESULT IS A MAP (a Map's identity is its key→value association;
  order never enters), **NOT** because of the champ's hash ordering — hash order
  was the DEFECT Q_U44 killed. Order has to be *manufactured* only when Map
  contents are flattened INTO a vector, and that is exactly where Q_U44 rules
  canonical. Three regimes: **Map→Map, order never arises · Map→vector, order is
  manufactured ⇒ CANONICAL · keyless→vector, order is already there ⇒ WRITTEN.**

  **⭐⭐ THE SURFACE-OBSERVABLE FORM, and it is the better test [owner's
  observation, 2026-08-12 — "in the vector cases they all must have `*`
  postfixed, whereas in the Map case it would not be an error if one branch were
  and the other not"].** Absorption shows up as a LEGALITY difference, not only an
  equality one:
  ```
  m2{a* b}    →  {:x 1, :b {:y 2}}   LEGAL — splice `a`, KEEP `b`'s key
  mm{zz* aa}  →  L4 mixed keyed/keyless — one keyless component beside one keyed
  ```
  A Map-valued branch star contributes KEYED components, which sit happily beside
  an unstarred keyed branch; a vector-valued branch star contributes ONE KEYLESS
  component, which cannot. **This is checkable without computing the answer**, so
  it is what the battery should assert. Q_U40 already names `m{a* b}` as the
  reason the branch form is *strictly more expressive*.

  **⛔ AND IT FALSIFIES THE PARKED PATCH'S `(list #f)`** — see
  [§5.P4e-1b-iii](#p4e-1b-iii) finding A2. Classifying every star branch KEYLESS
  at the parser makes `m2{a* b}` an L4 error, i.e. **the patch refuses Q_U40's own
  headline expressivity example.** `(list #f)` is right for vector contents and
  wrong for Map contents, and the parser cannot tell which — which is the whole
  reason Q_U43 moved the check to typing.

  **COST, accepted eyes-open**: L★'s side condition stops being SYNTACTIC ("is
  there an ω in the spelling?") and becomes SEMANTIC ("are the contents Maps?"),
  so a user cannot apply the law by pattern-matching on syntax, and P5's L2
  factoring cannot use it as a rewrite without a type-directed guard. Mitigation:
  that is where the information already lives — Q_U38 and Q_U43 moved the star's
  collision and sort checks to TYPING for exactly this reason, so a type-directed
  side condition on a star law is consistent with the design rather than a new
  exception.
  **Rejected-with-reason** (all three break something landed): *make a vector
  branch star SPLICE its elements* — does not even rescue L★ (`@[1 2 3 4]` vs
  `@[3 4 1 2]`) and destroys Q_U44's recovery, which works *because* the inner
  star contributes one component and fabricates no order · *make the result form
  written-order* — contradicts Q_U44 head-on, needs an OrderedMap the language
  does not have, and would make `mm{zz aa}*` differ from `mm{aa zz}*`, breaking
  the §1.1/§8 Q2 thesis · *refuse a star over a keyed layer with vector contents*
  — kills the headline concat case and runs against [Q_U42](#q-u42), which ruled
  the analogous shape one level down to CONCAT rather than error.
  **Next free Q-label: U46.**

- <a id="q-u43"></a>**⭐ Q_U43 — THE L4 SORT CHECK MOVES TO TYPING FOR STAR-BEARING
  BRANCHES, AS [Q_U38](#q-u38)'s COROLLARY [owner, 2026-08-11 — "move the sort
  check to typing per Q_U38's corollary"].** Q_U38 moved the COLLISION check;
  this moves the SORT (L4 keyed-vs-keless) check, which rides the identical walk
  with the identical blindness.
  **WHY IT IS FORCED, discovered writing 1b-ii's arms.** `select-branch-top-keys`
  is documented *"Fully static; the parser's duplicate check AND the L4
  sort-homogeneity check both run on these"*, and returns one component per
  surviving output — a key SYMBOL (keyed) or `#f` (keyless). **A star branch's
  components are SUBJECT-DERIVED**: neither their identity nor their SORT is
  knowable from the step list. Every available answer is wrong differently:
  · `'()` — contributes nothing, which is exactly the silent miss the P4a comment
    says it fixed (*"a sixth kind silently contributed NO component, so the L4
    sort check and the duplicate check would both simply not see it"*);
  · `(list #f)` — declares the branch KEYLESS, wrong whenever the contents are
    Maps, and would raise a spurious L4 mixed-sorts error against keyed siblings;
  · `(list s)` — a key literally named `(@star …)`.
  So the star breaks the function's stated contract for one kind. ⚠ The audit's
  critic had already flagged `mixed-sorts?` as **the more dangerous of the two
  blind gates** — it runs one line BEFORE `dup-output-key` and its residue is a
  silently WRONG CARRIER for the whole level rather than an error.
  **WHAT LANDS**: `select-branch-top-keys` gets an explicit `'star` arm that
  RECORDS that it cannot answer; the parser's two gates carve out star-bearing
  branches with the reason at the site; typing performs both checks where the
  subject's row is visible. ⚠ The carve-out is **1b-iv work** — under 1b-ii the
  star refuses before any walk reaches it, so the arm ships INERT and the
  obligation is written where 1b-iv picks it up. Building the carve-out now would
  be mid-flight widening (*Watching 9*).
  **Next free Q-label: U44.**

- <a id="star-census"></a>**⭐ THE STAR-SURFACE CENSUS IS THE DESIGN'S INPUT
  [owner-commissioned, 2026-08-09].** After two failed attempts, the owner ruled
  that attempt 3 opens from a MEASURED MAP rather than an intuition about where
  a star can safely fire. Run: `wf_19cd5077-15b` (5 axes + completeness critic +
  synthesis, ~1.39M tokens). It produced a ranked constraint set (Tiers A–D,
  G, O), a pipeline surface map, a carrier table, a discriminator inventory and
  **twelve** enumerated approaches. Load-bearing results, each re-measured on the
  main thread before being recorded here:
  · **The reader ERASES glued-vs-spaced for every non-identifier carrier.** So in
    any probe triple the SPACED leg *is* the count-preserving simulation and the
    CONTROL leg *is* the count-changing one — attempt 1's defect was measurable
    before it was written.
  · **24 form-level item-counting consumers**, not the 14 an earlier sweep found;
    nine have no `process-*` function and are invisible to the obvious grep.
  · **The two biggest finds are NOT star defects** — [DEFERRED 102](DEFERRED.md)
    (the abort seam, now FIXED at `41458174`) and **103** (a bare `*` is a legal
    irrefutable PATTERN that silently deletes later `match` arms).
  · **A 1-element sentinel list is NOT unprecedented** — `($select-brace)`
    head-only is already `#t` for both consumers; it is the brace/any-arity
    class, at the cost of the arity check. (I had asserted the opposite.)
  · **`group-items-to-tree`'s output is DISCARDED in production** (2 writes, 0
    reads), and it already diverges from the datum grouper in six arm families —
    so the twin obligation may be the Q_N3 guard rather than correctness.
  · **`$star` is a live, undocumented, zero-producer Sigma spelling** reachable
    from user source; `star-symbol?` was built to accept a sentinel.
  ⚠ **THE FULL ARTIFACT IS NOW IN THE TREE** — the six bullets above are the
  summary; the ranked constraint set (Tiers A–D, G, O), the pipeline surface map,
  the carrier table, the discriminator inventory and the **twelve** enumerated
  approaches were extracted from the run transcript on 2026-08-10 to
  [`docs/research/2026-08-09_STAR_SURFACE_CENSUS.md`](../research/2026-08-09_STAR_SURFACE_CENSUS.md).
  Until then they existed ONLY in a session transcript, which is not durable
  storage — and the owner's ruling is that attempt 3 opens from the MEASURED MAP,
  which cannot be honoured against an unreadable artifact.
  (Q-label register: see [Q_U45](#q-u45), the latest ruling — **next free U46**.)

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
- <a id="p4e"></a>**P4e — the `*` family · disclose `<`/`:<` · branch-initial `:`
  + closures**: ⚠ **RE-SCOPED 2026-08-08 by the P4e design round** —
  [Q_U23](#q-u23) · [Q_U24](#q-u24) · [Q_U25](#q-u25) · [Q_U26](#q-u26).
  The old line read "flatten `*` · splat `.*` · disclose"; **`.*` row-splat is
  RETIRED as a separate operator** (Q_U23) and `.*` is REBOUND to ravel (Q_U26),
  so the sub-items below are not the ones this bullet used to name.
  - the keyword-trailing-`*` consumer split (`:diags*` — split-caret-lexeme
    prior art; §10.4 `build.modules:diags*:msg`) — now ONE splitter serving
    both bands, per Q_U23's lexical dividend
  - **`*` sort-generic** (Q_U23): `database*` splices in block position; the
    nominal-join collision routes to the landed strict-merge waypoint
  - **`*_`** (Q_U24), landing WITH bare `*` — ⚠ its provenance rule is `^-_`'s,
    NOT `^_`'s
  - **bare `.*` = ravel** (Q_U26) — needs the grouping fix; `values.*` shatters
    at HEAD
  - **branch-initial `:`** for the ordinal² transpose (Q_U25) — `values{:0 :1 :2}`;
    ⚠ lifts a [Q_U7](#q-u7) v1 refusal, and ⚠ **must REPLACE, not delete, the
    `"block keys are written bare"` diagnostic**
  - disclose (`users:<{0.userName^}` §10.2) + **DEFERRED 5's HEAD
    re-census** of `<`-adjacent sites — ⚠ NO implementation at HEAD (3 mentions,
    all comments)
  - carries **DEFERRED 63** (re-homed off the landed slice 4c)
  - the keyword-projection disposition (§2.4, due at this close)

  **Spec divergences this round created** (D4's adaptation wins, per the
  standing rule): spec **§8 Q4** ("`*` on Map layers — nominal join?") is
  **CLOSED affirmative** by Q_U23 · spec **§2.1**'s `.*` row-splat row is
  **superseded** (`.*` is now ravel) · spec **§10.6**'s `m{:0^ :1^ :2^}` is
  **corrected** to `m{:0 :1 :2}` by Q_U25, since Q_T4a forbids ordinal-`^` ·
  spec **§7 W2**'s exit shrinks for the ORDINAL half (branch-initial `:` alone).

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
- <a id="p4c-5"></a>**P4c-5 — the `.*name` retirement + FULL residue disposal**, in the commit
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

**SLICING — ruled at the opening co-design [owner, 2026-08-07 — "(a) fix it
first as slice 0"]:**

- **✅ Slice 0 — the homogeneity-probe soundness fix — COMPLETE `00e52c42`
  (2026-08-07).** Landed WIDER than scoped, and the widening was the
  adversarial verify's doing (`wf_9d8f105c`, 3 skeptics):
  **(i)** the pvec-literal probe takes the `unify-ok ∧ conv` conjunct
  (failing-test-first — 3 RED pins reproduced the mistype, the
  order-dependence, and the buried `<error>`);
  **(ii)** ⭐ **the verify REFUTED the first cut with a BLOCKING reproducer**:
  `conv` was spelling-sensitive on UNIONS while the engine's own equality is
  SET-LIKE (`unify-union-components` sorts + dedups), so
  `@[[the <Int|String> 1] [the <String|Int> "x"]]` reclassified het —
  `conv-nf` gained a **union arm** (mutual containment over `flatten-union`;
  union-vs-non-union stays #f, matching unify's own deferred flavor-B case,
  so the two equalities agree in BOTH directions);
  **(iii)** ⭐ **the class had THREE members in ONE function, not one** — the
  list-literal probe (`'[{:b 2} m]` → `List {:b Int}` with a Map value
  inside, the unsound direction) and the map-literal KEYS probe (computed
  keys `{[expr] val}` make key types source-reachable; first-key-wins gave
  one value set two types) carried the identical defect. Same conjunct at
  both; the map-keys arm also gained the rollback wrapper its siblings
  already had. Skeptic 1 VERIFIED the rollback contract empirically (a
  mid-probe solve does NOT leak into the het row) and skeptic 3
  mutation-tested every pin against the pre-fix base worktree.
  **Gates**: battery **375/375** (+10) · neighborhood 344/344 (14 files incl.
  union/session/equality-audit — `conv-nf` is shared) · acceptance **69/69**
  by output diff · corpus A/B 13 files + control = **ZERO semantic diffs**
  (both artifacts explained: a tree-path string in an identical pre-existing
  error; a pre-existing `solve-mult-meta!` raise identical on both legs) ·
  perf A/B interleaved, no regression · **full suite 9916/485/0**.
  **Filed, not fixed** (all pre-existing, verify findings): logic-var
  elements infer `expr-hole` which WILDCARDS the probe (reachable via `defr`
  bodies — a mixed literal with a logic var collapses `[PVec _]`) ·
  `'postponed` counts as unify-ok (optimistic-collapse class, no source
  reproducer found) · the legacy no-net-box rollback path does not restore
  (unreachable in production) · `unify`'s refl arm runs `unify` where its
  own comment says `conv` (unreachable today — upstream infer fails first).
- **✅ Slice 1 — keyword-row + Map carrier — COMPLETE `14ef5e83`
  (2026-08-07).** `regions:host` → `{:ap "ap.…", :eu …, :us …} :
  {:ap String :eu String :us String}` at the production default; the genuine
  Map re-wraps uniform (`[Map K proj(V)]`). Mini-audit `wf_1ff4945e-810`
  (4 facets + critic; found the peel as a THIRD hardcoded-PVec site and the
  Map-carrier tier already solving assertive on a refusing node); adversarial
  verify `wf_89d6c7b7` (3 skeptics — ONE BLOCKING pin defect caught: the
  genuine-Map pin was VACUOUS, its regex matching the def echo's inner type).
  **Records the citations the slice's code comments carry:**
  · **Lean 1 DISSOLVED at implementation** — the co-design's
    "ordinal-over-nominal refuses" rested on ordinals indexing CARRIER keys;
    `bcast-apply` shows the inner step applies to VALUES only, so there is
    nothing to refuse: `users:0` is per-value ordinal projection, uniform
    with the live `m:0` over PVec, failing naturally with the guided ordinal
    message when values do not index. Pinned as the uniform semantics.
  · **The §10.6 carve-out** — `strings:home` was the ONE map-generic-tagged
    line inside a block D4 §5.P0 declared PERMANENTLY commented; carved out
    at this slice (the pivots stay v2-commented). The corpus note points here.
  · **Row-type ANNOTATIONS do not parse** (`def x : {:a Int}` →
    not-a-type-error) — a pre-existing surface gap, discovered scoping the
    genuine-Map pins. ⚠ Row-valued Maps are nonetheless CONSTRUCTIBLE by
    INFERENCE (`[map-map-vals [fn [s] {:host s}] mm]` → `[Map Keyword
    {:host String}]` — the verify refuted the first-cut "unconstructible"
    claim before it landed anywhere); the sub-inner over a row-valued Map
    SUCCEEDS (pinned), while a Map-VALUED value takes the standing Q_U10
    block-over-Map refusal (pinned).
  · **The mini-C9 scalar-tier consequence, measured**: a dyn-row FIELD's
    runtime miss is LOUD when a sibling field is a Map and QUIET when not —
    the ONE scalar tier couples siblings. Ruled-direction only
    (permissive→assertive), accepted eyes-open; the het slice's C9 ruling
    should subsume it.
  · The `bcast-carrier` message now names the truthful set ("PVec, Map, or
    **closed** keyword-row" — the verify caught it refusing a DYN keyword-row
    while naming "keyword-row" bare); dyn-tail's seal/validate-shaped remedy
    and the per-carrier split stay slice 4.
  **Gates**: battery **385/385** (+10 new, 8 re-pointed — all six family-A
  re-points verified to discriminate BOTH the revert and the atomicity
  break) · acceptance **71/71** (+2, markers regenerated via `--check`) +
  89/89 + 6/6 + 29/29 + 28/28 · corpus A/B vs `044a77d7` (19 files):
  EXACTLY the predicted diff set — the two corpus lines + foray's
  `regions:host`, each error→meaning (13→12) · **full suite 9928/485/0**.
- **✅ Slice 2 — het tuple — COMPLETE `ba1c055d` (2026-08-07).**
  `events:t` → `@[:click :key :click] : ⟨Keyword Keyword Keyword⟩` —
  per-position EXACT, output = the honest nat-row (P3c 2a; the Tuple→PVec α
  keeps PVec expectations satisfied). Mini-audit `wf_80ee26f2-7dd` · verify
  `wf_c92f4edd`. **Rulings landed [owner]**: **C9 = (a)** the conservative OR
  over positions (the ONE scalar tier; sibling-coupling accepted, scope is
  'path-only — the block arm is `(void)`) · output shape = nat-row · misses
  NAME the position/field · riders fixed value-channel · `events:x`
  battery-pinned (would be the corpus's first ERROR result; no convention).
  **The audit's refutation**: "one gate, zero new code" was FALSE — the tier
  peel was a SECOND independently-'keyword-gated site; both widened
  (`memq '(keyword nat)`), and the re-expressed s0c pin discriminates the
  half-shipped variant. **The `'bcast-at` wrapping fail**: label-aware walk
  (`record-map-field-types/labeled`, the adjacent sibling of the ONE
  reconstruction helper) + a recursive formatter arm — nested wraps compose
  ("fails at field :r1 — fails at position 1 — …"), and the slice-1 keyword
  twin (carrier fields unnamed) closed in the same stroke.
  `format-closed-row-miss` labels TOTALIZED (integer labels raised —
  unconstructible today, guarded by walker-totality).
  **DEFERRED 45 fixed structurally**: `select-branch-top-keys`' bcast arm
  answers `(list (select-step-output-name s))` — check ≡ meaning by shared
  computation; B1's sub special-case DISSOLVED; the verify's full
  OLD-vs-NEW-vs-consumers table found ZERO divergent shapes and a SECOND
  silently-repaired grade (dissolve inners `k^:w^:r` — now advertised +
  pinned). **DEFERRED 40**: the two path-append sites pair-guarded (the
  verify caught my first pin fixture VACUOUS — single-step, never reached
  the sites; re-pointed at the block-sort mid-branch shape); the ordinal leg
  recorded UNCONSTRUCTIBLE (`(@bcast (@ord N))` has no producer — the mint
  emits bare numbers, legitimate labels).
  **Carried out of the slice, recorded**: the Q_U20 block cell CONCRETE —
  in block position `hx{evs:t}` ≡ `hx{evs:{t}}` (a symbol inner threads the
  outer 'block and degenerates into its sub twin; the extract/assemble
  distinction Q_U20 ruled for 'path COLLAPSES) — material for the ruling ·
  the `@[]`-broadcast refusal misattributes "the subject" (a meta elem) ·
  `not-indexable`'s `x{k}` remedy is off-key inside a broadcast (both
  slice-4 fodder) · the peel's early stop IF two `@bcast` steps ever share
  ONE branch (unmintable today — flag, not defect).
  **Gates**: battery **395/395** (+11, 4 re-expressed; the verify's
  pin-vs-revert matrix shows every production half-revert caught) ·
  acceptance **73/73** ×2 (+2: `events:t` · `tree.entries:name` — the audit
  REFUTED its "PVec-of-rows" reading, `:entries` IS a het tuple, settling
  the three-way §10.8 contradiction; the recursive line stays W4-DEFERRED)
  + 89/89 + 6/6 + 29/29 + 28/28 · corpus A/B vs `5ef1cfac`: EXACTLY the two
  flips · **full suite 9940/485/0**.
- **✅ Slice 3 — PVec-of-union (keys-⋂ / types-⋃) — COMPLETE `1e8d0795`
  (2026-08-07).** Audit `wf_2759e5b0-220` · verify `wf_f24e650c`.
  **⭐ THE AUDIT RE-SCOPED THE SLICE**: the types-⋃ half **already shipped**
  (`build-union-type`), so `row-meet` was never wholly new; and keys-⋂ is a
  structural **NO-OP for Map components** (an open `[Map K V]` statically
  offers every keyword). The slice is therefore TWO halves over **disjoint**
  populations — the **GATE** for row components, the **TIER** for Map-bearing
  unions. It also found **TWO populations with opposite moral status**: a
  genuine non-offerer is a silent wrong answer the flip FIXES; a `Nil`
  remainder is a **correct answer** a naive flip would BREAK — which is the
  question ruling (a) settles.
  **⭐ Q_U21 RULED (a) [owner, 2026-08-07] — `Nil` IS SKIPPED.** `<T | Nil>`
  is the OPTION type; Nil is the absence marker, not a carrier alternative
  that happens to offer no keys. Preserves the `nil-safe-get` idiom;
  a genuine non-offerer (`Int`, a row lacking the key) still refuses.
  **Placement**: the gate lives in `select-bcast-inner-apply` (the per-element
  applier) so it covers exactly the population the tier witness does — union
  ELEMENT, union-typed row FIELD, union-typed tuple POSITION — and its mutual
  recursion with `select-union-lift` handles a component that only *whnfs
  into* a union (a type alias; the structural `flatten-union` cannot see
  through one). It deliberately does NOT reuse `select-project-field`'s union
  arm: that is the single-get OPTIMISTIC polarity, its own comment forbids
  broadcast reuse, and no polarity parameter is threaded down the
  five-signature walk.
  **⚠⚠ THE ACCEPTED CONSEQUENCE, NAMED — an OWNER QUESTION carried to the
  close**: because gate and tier must agree on what a component IS, a
  **Nil-bearing union stays PERMISSIVE**, so a genuine Map miss *inside* one
  is QUIET. That is (a)'s price at the VALUE layer, which the ruling (about
  the TYPE layer) did not reach. Recorded in the code at `tier-union-witness`.
  **The verify found FOUR defects, three of them mine**: (i) BLOCKING — my
  Nil pin was VACUOUS (one-element never-nil fixture) and a genuinely-absent
  element PANICKED, because the gate skipped Nil and the tier did not;
  (ii) BLOCKING — the witness fired on carriers the gate did not cover;
  (iii) HIGH — the bail DISCARDED the inner fail, so every per-component
  failure read as a key miss (false for ordinal inners and block-sort
  projections, and strictly worse than pre-slice in 6 spellings) — it now
  NESTS the inner reason on slice 2's `bcast-at` pattern; (iv) a regression I
  caught in my own RED/GREEN cycle — the witness applied on the NON-broadcast
  path, flipping single-get over a union from the ruled permissive `none` to
  a panic (a `peeled?` flag confines it; the verify proved the confinement
  complete by mutant). ⚠ Plus a **1-directive format string with 2 args**,
  which RAISED and was swallowed by `select-block-hint`'s blanket handler —
  the same class this arc has recorded before.
  **The fixture**: §10.7's "needs an ANNOTATION to build" was WRONG and
  unbuildable — a closed row is not writable in TYPE position. A
  **dynamic-bound `pvec-slice`** widens a het tuple to a PVec of the union of
  its position types (verified not an accident of the bound). The all-offer
  line is live; the refusing line stays commented (first-ERROR-result rule,
  as `events:x`) and is battery-pinned. ⚠ The fixture def initially SHADOWED
  an existing `mixed` in the file — caught by `--check`, renamed `widened`.
  **Gates**: battery **403/403** (+9, 1 re-fixtured, 1 re-expressed) ·
  neighborhood 291/291 · acceptance **77/77** (+4) + 89/89 + 6/6 + 29/29 +
  28/28 · corpus A/B vs `65cb5bce`: only the two known pre-existing artifacts
  · **full suite 9952/485/0**.
- **✅ Slice 4a — the advice stops lying, and starts FUSING — COMPLETE
  2026-08-07. ⚠⚠ ITS MACHINERY WAS RETIRED AT 4c — read this record as
  HISTORY, not as a description of HEAD.** (`61d64708` typing side · `d3947594` parser side; owner ruled
  fix-first, TWO commits). Opened because the slice-4 grounding found a LIVE
  defect inside slice 4's own target; audit `wf_37d324fe-045`, verifies
  `wf_a11a4ef7-900` + `wf_b73e7d14-3cc`.
  **The defect**: the `bcast-carrier` advice (`; otherwise spell it
  `[pvec-map [fn [m] m.NAME] xs]``) was gated on `(and label (symbol? label))`,
  and the LABEL cannot answer the question. FIVE populations walked through,
  each measured before implementation: a SUB inner (`m.{…}`, a parse error) · a
  GLUED ARROW (`m.a->b`, strands the `>`) · a CARET inner (`m.name` — writable,
  and WRONG: drops the rename) · a CHAIN (`m.a` for `:a:b` — writable, and
  wrong) · a NON-ASCII DIGIT key, whose advice was a **whole-file abort**
  (`pipeline.md` severity-1, unclaimed, closed as a side effect).
  ⚠ The old guard's own comment (\"`m.0` is not a thing a user can write\") was
  FALSE — `[pvec-map [fn [m] m.0] xs]` → `@[1 3] : [PVec Int]`; it suppressed
  correct advice while admitting broken advice.
  **The fix**: the step KIND decides, so the decision moved to where the step
  is. `select-fail` gains an `advice` field (all 21 constructors pass it
  explicitly — no defaulting wrapper, since the defect IS advice nobody decided
  to emit); `dot-writable-field-name?` lands in `parse-reader` beside the
  charset it delegates to (the F1b.7g drift class), deliberately conservative
  and pinned on its own contract.
  **⭐ The chain case made the advice COMPOSITIONAL, and that is the phase's
  idea.** `xs:a:b` is not one branch with two steps — Q_U13's NEST encoding
  gives every level its own `expr-select`, so the refusing node is the
  INNERMOST and `:b` lives in its PARENT; a step-local vouch structurally
  cannot see it. But `select-block-hint` descends outermost-first, so it HAS
  the chain and was discarding it. Carrying it down yields the FUSED spelling
  — the functor law, `fmap g ∘ fmap f = fmap (g ∘ f)`, the same identity
  [Q_U7](#q-u7) pins as the L1-fusion theorem. `xs:a:b` → `m.a.b`, depth 3 →
  `m.a.b.c`, **pinned as an EQUIVALENCE rather than as message text**.
  **⚠⚠ THE VERIFY CAUGHT TWO BLOCKING DEFECTS, BOTH MINE, BOTH NEW, BOTH
  INVISIBLE TO EVERY GATE** (battery, five acceptance files and the full suite
  were green over both): **(i)** the restructured walker searched each subject
  TWICE — explicitly, then again via the generic `expr-subfields` fallback
  where `subject` is field 1 — making it **O(2^depth)**: 5.3s / 14.9s / 46.3s
  at depths 14/18/20 against a flat ~4.3s base, on PLAIN DOT chains with no
  broadcast in them, since the hint runs on every infer failure. Output
  byte-identical: pure waste, and provably dead (the chain reaches only the
  advice STRING, never the walker's truthiness). **(ii)** fusion applied in
  BLOCK sort, where ω **assembles** rather than projects — `RP{items:aa}` ≡
  `[pvec-map [fn [m] m{aa}] P]` while `m.aa` differs, and at two steps the
  user's own expression is a hard ERROR while the advised path SUCCEEDS, so the
  message's two remedies contradicted. **My own new pin FROZE it**; it is
  inverted now. Block sort advises nothing: the \"needs a different delimiter\"
  rule the slice already applied to subs and carets, finally applied to the
  SORT axis.
  **The parser half** (`d3947594`): the sibling guard in
  `retired-selection-error`'s `bcast-step-binder` arm was **DEAD CODE** —
  `(pair? f)` where `f` is `(base-name detail)`, which returns a string on
  every branch — so a binder `:{` printed SYNTAX OBJECTS carrying absolute
  filesystem paths into the message, twice, the second time inside the advice.
  Its covering test accepted an alternative and pinned no content, which is why
  a green suite never saw it.
  **Gates**: battery **403 → 415** · acceptance **77/77** + four more, 0
  mismatched markers · full suite **9964 / 485 / 0**, `[485/485]` verified.
  **Filed**: DEFERRED **60** and **61** — ⚠ BOTH DISSOLVED/REWRITTEN at 4c,
  because their subject (the advice machinery) no longer exists.
  **⚠⚠ SUPERSESSION, 2026-08-08 (`a31b7475`)**: every mechanism this record
  describes is GONE — the `advice` field (struct back to 4 fields),
  `bcast-advice-chain`, `extend-advice-chain`, the `chain`/`rest` params, and
  `dot-writable-field-name?` + its export and contract pin. The fusion idea
  survives only as the RE-POINTED L1-fusion equivalence pin. 4c's remedy points
  back at the user's own spelling instead of teaching one, which left all of
  this without a consumer. The two BLOCKING defects and the whole-file-abort
  population remain accurate as history and are why the arc is worth reading.
- **✅ Slice 4b — the schema CARRIER gap — COMPLETE 2026-08-08** (`19ce05aa`;
  owner ruled it INTO slice 4 rather than papering over it with a message).
  Opened by the slice-4 mini-audit (`wf_3e586347-b98`), which found that
  `select-row-of` resolves a schema fvar to its closed row — so `p{name}` and
  `p.name` work — while `select-bcast-lift` tested `expr-Record?` on the RAW
  type and told the same value it "needs a … closed keyword-row subject". A
  message could only have papered over that.
  **⚠ The obvious framing was wrong, and measuring caught it before design**:
  this does NOT make `p:name` succeed on a FLAT schema. `:` projects from each
  field VALUE, so `{:name String}` + `:name` fails on a plain row too. What it
  buys is that a schema SUCCEEDS wherever its row succeeds (`rg:host` over a
  row of records → `{:eu "e", :us "u"} : {:eu String :us String}`, identical to
  the plain row) and FAILS the same way where its row fails (byte-identical).
  **⚠⚠ THE VERIFY REJECTED TWO SUCCESSIVE CUTS — three BLOCKING defects, all
  mine, all green on battery + five acceptance files + the full suite:**
  **(1) a CAPABILITY BYPASS** — `select-row-of` tests SELECTION first then
  schema and calls the order load-bearing (both registries accept one name); my
  first cut copied only the schema arm, so with a `schema P` + `selection P
  from P` collision `u.age`/`u{name}` were refused by the view while `u:h`
  returned the restricted field's contents at ZERO errors · **(2) a WIDTH LIE
  (extras)** — `schema` is OPEN by default and `schema->row` mints `'closed`;
  broadcast is the FIRST consumer that ENUMERATES the row, so a 3-key `Region`
  (the slice's own flagship example) gave `{:ap "a", :eu "e", :us "u"} :
  {:eu String :us String}`, and an extra key that cannot offer the field
  produced a silent `<error>` propagating into a `def` · **(3) a WIDTH LIE
  (absence)**, found by the RE-verify after 1 and 2 closed — every field is
  minted `'present` while the fill "happens at the seal boundary", and a
  `spec f -> S` RETURN has no fill, so a `:default`-ed field can be `'present`
  and ABSENT: `c:h` → `{:a "q"} : {:a String :b String}`, `broad.b` → a silent
  `<error>`.
  Plus a fourth I caught myself first: the lift resolved and
  `select-tier-subject` did not, so a Map miss inside a schema-typed row went
  QUIET where its row PANICS — slice 1's "one gate was two", one carrier over.
  **The shape**: ONE `bcast-resolve-subject`, called from BOTH sites, admitting
  only a non-selection, `:closed`, default-free schema. Each conjunct is a
  measured defect, named at the site; all three refusals are monotone.
  **Gates**: battery **415 → 421** · acceptance 0 mismatched across all five ·
  full suite **9970 / 485 / 0**, `[485/485]`.
  **Filed**: DEFERRED **62** (the precise presence gate — a broadcast-specific
  `schema->row` restores both refused populations) · **63** (inline nested
  schemas are always OPEN, so this lands only for top-level NAMED closed
  schemas, and the refusal leaks a generated `Region__us`) · **64** (both new
  gates are SILENT — "add `:closed`" is never said, and a collided selection
  gets a message `select-row-of` itself calls a lie; slice-4c work) · **65**
  (pre-existing: `lookup-schema-by-name` matches the SHORT name, so a `data`
  type can resolve to a same-named schema).
- **✅ Slice 4c — the per-carrier split, and 4a's advice machinery RETIRED —
  COMPLETE 2026-08-08** (`a31b7475`). Audit `wf_3e586347-b98` · verify
  `wf_d4e1de98-ff5`.
  **The finding that reshaped it**: the advice slice 4a vouched fires ONLY on
  subjects that already failed, and `pvec-map` needs a PVec — which never
  reaches this arm. The spelling could not work on its own audience.
  **⭐ The owner's call was not to fix the spelling but to stop teaching one**:
  converting fixes the CARRIER, and the user's own spelling then works
  (`[pvec-from-list L]` then `:name`, `:a:b`, `:{a b}` — all verified). Each arm
  names its own conversion and stops: List `pvec-from-list` · LSeq `into-vec` ·
  Set `[pvec-from-list [set-to-list xs]]` + the unordered caveat · open/dyn row
  `[validate Schema subj]` · unadmitted schema ('open / 'defaulted, each
  explained) · collided selection named as a VIEW · scalars and functions get
  nothing, because there is nothing true to say.
  **And that retired 4a's machinery** — no consumer left, and unused-but-correct
  is the dual-path shape the rules forbid. Deleted: the `advice` field (struct
  back to 4 fields), `bcast-advice-chain`, `extend-advice-chain`, the `chain`
  param, the `rest` param, `dot-writable-field-name?`. `select-block-hint`
  reverts to the pre-4a single-descent shape; the O(2^depth) walk did NOT return
  (depths 14/18/20 → 4.25/4.27/4.27s, flat). Nine advice pins deleted, TWO
  re-pointed because they incidentally pinned real semantics (block-ASSEMBLES-
  vs-path-PROJECTS; L1 fusion, which Q_U7 records and nothing else pins).
  **⚠⚠ The verify caught FOUR more false promises, all mine, all in the NEW
  text** — the same class the slice exists to remove, committed inside the fix
  for it: `bare-name` matched a user's own `data List` and offered it
  `pvec-from-list` (measured: "Could not infer type") · "and the same spelling
  works" is false whenever the STEP does not fit the converted elements (an
  ordinal inner; non-row elements) · the dyn arm's inherited `the Schema subj`
  is REFUSED for its whole audience, and **my pin asserted only the substring
  under a title claiming a verification never performed — its own fixture
  falsified it** · "mark it `:closed` and the broadcast works" was unconditional
  and false when reached from the dyn arm. Plus LSeq, the last convertible
  carrier, had no arm. All corrected; the dyn and LSeq pins now EXECUTE their
  remedies.
  **Gates**: battery **421 → 420** (a net −1: nine advice pins retired, eight
  carrier pins added) · acceptance 0 mismatched × 5 · full suite
  **9969 / 485 / 0**, `[485/485]`.
- **🔄 Slice 4d — the remaining diagnostics. Sub-slice 4d-1 ✅ COMPLETE
  2026-08-08 (Q_U19 route 1).** Audit `wf_a154667e-42f` · verify
  `wf_f178a813-a4c` (3 skeptics + adjudicator).
  **SHIPPED**: the ω audience gets its own `bcast-rekey-message`; the dot string
  at `parser.rkt`'s caret arm is BYTE-IDENTICAL; the arm dispatches on the step
  carrying the caret via `select-step-kind` (already imported, already answers
  `'bcast`). The `parse-error` is a per-command VALUE, never a raise. The
  "P4c-4b: the payload's THREE sub-cases" pin is RE-POINTED to the DECISION —
  it asserted `re-keys the OUTPUT`, which BOTH messages contain, so it could not
  discriminate and stayed green straight through the split.
  **⚠⚠ ROUTES 2 AND 3 WERE IMPLEMENTED AND REVERTED [owner: "ship route 1"]** —
  see **DEFERRED 75 / 76**. Route 2's datum-level arm **BROKE MONOTONICITY**
  (`^` is a bindable name, so `[snd2 xs:name ^]` is a program HEAD accepts and
  the arm made it an error) and route 3's gate widening **ate binder names**
  (`|.|` has one role; `|:|` has two). Both need a grouper-side adjacency mint —
  the same shape as P4d-0's `:{`, which landed alone for the same reason.
  **⭐ THE VERIFY EARNED ITS KEEP FOR THE FOURTH SLICE RUNNING**: the break was
  invisible to a GREEN battery, five green acceptance files, AND a two-direction
  mutation test that passed. ⚠ **Two of three skeptics wrongly cleared it** (they
  tested `defn ^`, which fails, never `def ^ :=`, which works) — the adjudicator
  and the main thread each reproduced it independently. And **mutation-testing
  refuted a pin title of mine**: "the split is PER-STEP, not per-branch" is not
  observable — Q_U13's NEST gives ONE carrier per level, so a per-branch `ormap`
  passes the whole battery. `findf` is honesty, not a fix; the pin and the
  comment now say so. Also corrected: `parser.rkt`'s claim that
  `make-select-bcast` has "ZERO production callers" (it has FOUR, same file).
  **Gates**: battery **420 → 425** · acceptance **77/77** + 89/89 + 6/6 + 29/29 +
  28/28 · full suite **10061 / 488 / 0**, `[488/488]` verified · the reverted
  surfaces A/B **byte-identical to baseline**.

- **✅ Slice 7 — A PAREN GOAL AS THE SUBJECT OF A POSTFIX ACCESS — COMPLETE
  2026-08-08** (`f54dfc6c`). Owner-requested. `(G):c` now solves, as do `.name`,
  `[0]` and chains; the `def`/`let` seams too. The witness had to be a DATUM
  sentinel, not a syntax property — `(G).0` and `[get (G) 0]` are byte-identical.
  Three owner rulings landed (let spellings agree · multi-line def · a value in
  parens is a *guided* error). Verify `wf_0511966a-d51` (4 skeptics + judge)
  found 3 defects of mine. Suite 10087/488/0. → [§5.P4d-s7](#p4d-s7)

- **✅ Sub-slice 4d-2 — THE BROADCAST AXIS + the stale-phase sweep — COMPLETE
  2026-08-08.** Verify `wf_6893b003-6ae` (3 skeptics + adjudicator).
  **SHIPPED**: a `'bcast-elem` wrapper for the PVec/Map carrier (whose `else` arm
  returned its inner fail RAW while the keyword-row arm wrapped), plus a
  broadcast AXIS on `format-select-fail` — **`#f` / `'elem` / `'at` / `'union`**.
  `subject-other` now names what actually failed, and `not-indexable`'s remedy
  moved INTO the cond that knows the truth. Three user-facing phase promises in
  `parser.rkt` reworded PHASE-FREE (the `.*name` one was promising a feature that
  had already shipped), three stale comments fixed, two slice-4a-origin test
  labels corrected `s4b` → `s4a`.
  **⚠⚠ THE VERDICT WAS FIX-FIRST, and every defect was in code I had just
  written.** The axis was **2-valued when the concept is 3-valued**: `bcast-at`
  (heterogeneous — ONE field/position) and `bcast-union` (ONE component) were
  handed `'elem`'s universal, so `r2:z` printed *"broadcast fails at field :b —
  … **each element** is not a record"* while `:a`'s value IS one — false, and
  self-contradictory with its own prefix four words earlier. Also: `xs:key` was
  emitted for **non-keyword-keyed Maps**, where no `:` spelling exists (a two-hop
  dead end); a remedy derived from ONE field's type was asserted over a whole
  heterogeneous broadcast; the `[else]` arm dropped a **working** `x{k}` for
  schema-typed subjects (right for scalars, wrong for an fvar — and a
  schema-typed subject is exactly what the sibling arms' own "seal it" remedy
  produces); and the call-site wrap re-wrapped a `bcast-union` fail, producing
  the mirror of the double-wrap its own comment claimed to avoid. All fixed and
  each reproducer re-run.
  **⭐ Two skeptic findings were REFUTED as stale** — they read a snapshot taken
  before the `subject-other` PVec-branch fix, which the adjudicator confirmed
  executes. Second arc running where skeptics agreed and were wrong.
  **Gates**: battery **425 → 430** · acceptance 0 mismatched × 5 · full suite
  **10066 / 488 / 0**, `[488/488]`. ⚠ An intervening run read **10061** with
  `all_pass: true` — a batch worker under-reported `test-properties.rkt` as 8
  when it is a deterministic 13. **DEFERRED 81**; the tell was that the total
  moved in a direction the battery delta could not explain.
  **Filed**: DEFERRED **77** (three sibling arms still misattribute; the tuple
  one advises a spelling that SUCCEEDS WITH THE WRONG MEANING) · **78** (the
  census grep structurally cannot see bare-token phase refs — the 10th arc of
  under-counting, in a census I had just widened) · **79** (pre-existing: the
  `let` fused-annotation message states two falsehoods) · **80** (the
  `bcast-step` arm may be dead) · **81**.
  **⬜ REMAINING in 4d**: nothing — 4d-1 and 4d-2 close it.

- **✅ Slice 5 — THE UNION META-FALLBACK NON-TERMINATION — COMPLETE 2026-08-08**
  (owner: *"fix this first … ship code we can be proud of"*). Verify
  `wf_d29c48fd-aed` (2 skeptics + adjudicator).
  **⚠⚠ FOUND AT THE CLOSE, FILED NOWHERE, IN P4d's OWN SLICE-3 CODE.**
  `select-union-lift`'s unsolved-meta arm called `select-bcast-inner-apply` with
  the SAME union `u`; that function's first arm dispatched straight back with the
  same union; `comps`/`offering` derive purely from `u`, so nothing changed
  between iterations — an unconditional infinite mutual recursion. On `sl:a:b`
  (DEFERRED 58's fixture plus ONE chain step): **`fuel exhausted`, exit 1, output
  EMPTY** — a def ABOVE it did not print. The **7th** whole-file abort in this
  track, violating the constraint the phase itself states. A single step could
  not reach it: it needs a union whose component set holds an unsolved META, and
  only a chain produces one.
  **The fix**: factor the non-union tail (`select-bcast-inner-apply/non-union`);
  the one call that passed an UNCHANGED value bypasses the union dispatch, while
  every call that passes a strictly SMALLER value keeps the full dispatcher — so
  the alias / component-whnfs-into-a-union recursion is untouched and
  well-founded by descent (verified: a three-way alias join is byte-identical).
  **⚠⚠ AND THE FIRST CUT TRADED THE ABORT FOR SOMETHING QUIETER AND WORSE.** With
  a union subject the tail reaches `select-project-field`'s union arm — the
  single-get optimistic filter, which **that arm's own comment forbids broadcast
  from reusing, twelve lines above the edit** ("never 'unify' them"). Its fold
  DROPS a meta, so the stored type came out CLEAN and
  `check-escaping-projection-metas` never fired: `def q := sl:a:b` was **ACCEPTED**
  where the SHORTER `def q := sl:a` is hard-refused — more projection, less
  knowledge, past the guard, at zero errors. And adding an empty `{}` component
  (strictly LESS information) flipped a CORRECT keys-⋂ refusal into acceptance.
  Neither skeptic connected it to the D23 guard; **the adjudicator did**.
  Closed by carrying the ORIGINAL metas into the result (a fresh one would not
  restore the guard — it keys on `meta-source-info-kind`). The remaining polarity
  question is **DEFERRED 82**, the swallowed `miss-closed` formatter **83**.
  ⚠ Also corrected: the fix's own termination comment claimed "this function does
  not mention `select-union-lift`" — a grep asserted as a proof. The honest
  invariant is about DESCENT, and it is now written that way.
  **Gates**: battery **431 → 432** · acceptance 0 mismatched × 5 · full suite
  **10068 / 488 / 0**, `[488/488]`.

- **✅ Slice 6 — SPLIT ABSENCE FROM KEY-MISS (Q1 / Q_U21's value layer) — COMPLETE
  2026-08-08** (`003f150b`). Audit `wf_22427256-c66` · verify `wf_aec25ca2-276`.
  **⭐ THE AUDIT REFRAMED THE QUESTION**: ruling (a) was ALREADY not holding at
  HEAD. C9's conservative OR arms the one scalar tier from a Map **sibling**, so
  an actually-absent element in `{:f <Nil|Map> :g Map}` PANICKED — the precise
  failure (a) exists to prevent — while in the same population a genuine miss was
  already LOUD by the same accident. **Owner ruled C9 GOVERNS**; Q_U21 (a) is
  scoped to "no armed sibling" and satisfied at the VALUE layer instead.
  **The split is a DELETION, not an arm**: the Nil short-circuit leaves
  `tier-union-witness` (so the tier arms and the miss is loud), and `champ-of`'s
  assertive-PATH arm is deleted (so it consults only the BLOCK tier). ⭐ The
  assertive tier's guarantee is about the **KEY** — `project`'s question, which
  keeps its arm. It was never about the element's SHAPE, and this file mints
  non-champ values AT MAP TYPE by ruling. Net **−2 arms**.
  **⚠⚠ MY FIRST CUT ADDED AN `expr-nil?` ARM INSTEAD, and the verify refuted it
  twice** — all three skeptics AND the adjudicator converged, and the adjudicator
  built and measured the better fix. (i) My width argument was a **TYPE-level
  claim defending a VALUE-level site**: the gate bounds component TYPES, not
  whether a value at `[Map K V]` is a champ — `ub.a` (the route my own comment
  called safe) yields `none : [Map …]`, and broadcasting it went `none` → PANIC, a
  value→error break, under a comment calling the bound "MEASURED". (ii) Sitting
  above the block arm it **silently weakened Horn D** on the reachable
  `map-assoc` dyn-key route; my own probe missed it by testing a typing-refused
  shape.
  **Gates**: battery **432 → 436** · acceptance 0 mismatched × 5 · full suite
  **10072 / 488 / 0**, `[488/488]`. **Filed**: DEFERRED **84** — the whole-node
  `return` still lets ONE absent element answer for the node (loudness by champ
  hash order; data discarded; a scalar at a container type). Needs a per-element
  vs node ruling plus an ordering-agreement pin.

- **✅ Q2 (the Q_U20 block cell) — ANSWERED 2026-08-08, and the question was
  MIS-POSED.** D4 recorded it as *"in block position `hx{evs:t}` ≡ `hx{evs:{t}}`
  … the extract/assemble distinction COLLAPSES"*. Measured: that holds for PLAIN
  and RENAME inners and FAILS for the caret family, both spellings succeeding at
  0 errors with different output keys, shapes and arities. So the "collapse" was
  never the content.
  **⭐ The content is a RULE the owner's own intuitions turned out to encode, and
  it is the SPEC's**: *a caret applies EXACTLY ONCE, at the level where it is
  written — and dropped means dropped* (§3.4). HEAD applies it **twice** through
  a broadcast and **zero** times through a sub-block, and correctly once on a
  plain dot path. Verified against the rulings, which the dot path satisfies
  exactly: `app{server.ssl.enabled^-}` → `{:enabled true}` (Q_T7, whole branch
  flat) · `^-ssl` → `{:ssl true}` · `^..` → `{:server {:ssl true}}` (Q_T8, one
  level, ancestors kept) · `^ssl` → `{:server {:ssl {:ssl true}}}` (rename in
  place). Four operators, four ruled meanings, all correct on one branch.
  **So the divergence is a DEFECT, not semantics — filed as DEFERRED 88** with
  its three measured members. ⚠ Correcting my own earlier framing to the owner:
  I first argued the divergence was correct structure ("two genuinely different
  nestings") and that making the spellings agree was disqualified from both
  sides. That was rationalising the implementation — I had not checked it
  against Q_T7, which rules `^-` as "collapses the whole branch FLAT". The
  owner's intuition was the ruling; my reading was not.
  **Arity settled separately by [Q_U22](#q-u22)** — `^` at a leaf stays
  arity-uniform, so the fix does NOT make `xs:{name^}` a second spelling of
  `xs:name`.

- **✅ Q3 (DEFERRED 58, the dyn channel) — ANSWERED 2026-08-08 by DECOMPOSITION,
  and it was mis-posed like Q2.** Filed as *"a THIRD admission channel through the
  UNION GATE"*. The controls refute that level: `d.a` on a bare open row gives
  `<error> : ?meta` at 0 errors with **no union and no broadcast**, and
  `dyns:a` does it with **no union**. The gate admits nothing special; it
  propagates what an open-row projection does everywhere.
  **⭐ The broadcast half needs NO new ruling — the 2b POLARITY already decides
  it.** `typing-core` states it twelve lines above the arm: *"Broadcast is the
  OTHER polarity (all-must-offer …) and must NOT reuse this arm."* An open row
  **MAY** offer the key: that satisfies single-get's OPTIMISTIC polarity and
  FAILS broadcast's ALL-MUST-OFFER one. So "may be present in the remainder"
  does **not** discharge "every component must offer" — `sl:a` must refuse
  exactly as `sl:{a}` already does, and the sort-dependence is a SYMPTOM, not
  the defect. Scoped to broadcast, so **D19 is not reopened**: single-get keeps
  its leniency by being the other polarity. **DEFERRED 58 re-scoped in place.**
  **The other half is NOT ours.** `def port : Int := cfg.port` is ACCEPTED and
  `[int+ port port]` yields `[int+ <error> <error>] : Int` at 0 errors — the D23
  guard refuses UNANNOTATED storage but its documented "annotate to discharge"
  takes an assertion the checker has no evidence for. That is the OPEN-ROW
  PROJECTION CONTRACT (D19/Q_T2/D23), which CIU T6 only surfaced — filed as
  **DEFERRED 89**. The honest shape already exists one function away:
  `nil-safe-get` types absence as `T | Nil`, so arithmetic cannot silently
  swallow it.
  ⚠ Method note, second time this session: the option I first offered the owner
  ("the value becomes `none`") was UNDER-SPECIFIED — measuring `nil-safe-get`
  showed the difference is not `none` vs `<error>` but whether the absence is in
  the TYPE. The worked demonstration corrected my own proposal.

  **The P4d close's three owner questions are now ALL discharged** — Q1 ✅ ruled
  and implemented (slice 6), Q2 ✅ answered (fix → DEFERRED 88), Q3 ✅ answered
  (broadcast half → 58 re-scoped; contract half → 89). What remains for the
  close is mechanical: five DEFERRED to re-home · P4e and P4c-5 have no tracker
  row to point at · the tracker flip · the close note.

- **⬜ Slice 4d — the remaining diagnostics** (what 4c did not reach). ⚠ The
  scope below is RE-DERIVED by the slice-4d mini-audit (`wf_a154667e-42f`,
  5 facets + critic @ `2fd6b68e`); every correction is measured, and the
  pre-audit plan was wrong in four places, marked ✗ inline.
  · **Q_U19's unified refusal** — the SITING is answered by precedent
    (`ordinal-rekey-message` is ONE string emitted from FOUR sites, written at
    P3b for **Q_T4a**, the identical "`^` has no key" question one construct
    over, with `retired-selection-marker` as the macros-side per-command
    channel). ✗ **But the precedent's SHAPE does not transfer**: that message is
    one string / four sites / ONE audience, whereas the string here is ONE site
    serving TWO audiences, so the work is a **SPLIT**. Owner ruled 2026-08-08:
    **dot string byte-identical, add a broadcast sibling**, and **all three
    routes** — which are three SEATS (segmentation · a fold arm · the
    tokenizer/gate), not one funnel. Full ruling + the per-step discriminator,
    the precedence constraint and the monotonicity bound: [Q_U19](#q-u19).
  · Re-point the **"P4c-4b: the payload's THREE sub-cases"** pin to the DECISION
    (it froze an ACCIDENT — it asserts today's routing), and the two re-pointed
    pins' section labels (the two kept slice-4a tests carried a `P4d-s4b` prefix — CORRECTED at 4d-2 to `P4d-s4a`).
    ✗ The "orphaned slice-4a test header" is **ALREADY FIXED** at `2b52af8b` —
    it now reads "Neither the append nor the guard exists at HEAD." DROPPED.
  · **DEFERRED 47 ≡ 59.1** — the `subject-other` non-PVec branch. ✗ Not "one
    string, one site": the missing-`bcast-at` prefix is CARRIER-specific (the
    `else` arm of `select-bcast-lift` returns the inner fail RAW while the
    keyword-row arm wraps), so *no prefix* and *"the subject" misattributes* are
    TWO independent defects, over a population of four shapes.
  · **59.2** — `not-indexable`'s `x{k}` remedy is off-key inside a broadcast.
    ✗ The existing `cond` does **not** discriminate the right cases: it
    discriminates CARRIER KIND and computes only the middle interpolation; the
    remedy sits in the UNCONDITIONAL template tail, and `format-select-fail`
    threads no broadcast axis at all.
  · **The stale phase references.** ✗ Not "two reachable in `parser.rkt`":
    `grep -rn 'Path Selection P' racket/prologos/*.rkt` returns **seven sites
    across four files** — three user-facing strings in `parser.rkt` (`P4`,
    `P4c-3`, and the `*` flatten "Until Path Selection P4d") plus comments in
    `parser.rkt`, `parse-reader.rkt`, `syntax.rkt` and `surface-syntax.rkt`.
    D4 assigns `*` flatten to **P4e**, so P4d's close makes that promise
    retroactively false. ⚠ The `*` refusal fires on a TRAILING star
    (`us:tags*`), not a leading one, and it is battery-pinned — text and pin
    move in lockstep.
  · Correct the false premise in the edited lines: `parser.rkt`'s comment
    claiming `make-select-bcast` has "ZERO production callers at HEAD" — it has
    **four**, in that file.
- Corpus re-fate rides each slice. **Gates**: failing-test-first batteries +
  authored fixtures; the corpus A/B is REGRESSION-ONLY for slices 1–4 (the
  carriers have ~no corpus coverage — the vacuous-green hazard, named) but
  LOAD-BEARING for slice 0.

<a id="p4d-close"></a>

##### §5.P4d CLOSE — ✅ COMPLETE 2026-08-08  (close note; the Stage-5 PIR belongs to X.close)

**THE FEATURE.** Broadcast (`:`) is LIVE at the production default over **PVec ·
Map · keyword-row · het tuple · union · closed schema**. The refusals left —
List · LSeq · Set · scalars · open-or-dyn rows · open-or-defaulted schemas ·
collided selections — each name their OWN conversion, and scalars correctly get
none, because there is nothing true to say.

**TWELVE SLICES**: 0 (`00e52c42`) · 1 (`14ef5e83`) · 2 (`ba1c055d`) ·
3 (`1e8d0795`) · 4a (`61d64708`) · 4a′ (`d3947594`) · 4b (`19ce05aa`) ·
4c (`a31b7475`) · 4d-1 (`bd8b8bcf`) · 4d-2 (`25f3f22d`) · 5 (`a945f390`) ·
6 (`003f150b`).

**RULINGS**: [Q_U19](#q-u19) (A) path-position `^`-on-broadcast REFUSED, and the
dot string stays byte-identical · **C9** (a) one scalar tier, conservative OR,
`'path`-scoped · [Q_U21](#q-u21) (a) `Nil` is SKIPPED · **C9 GOVERNS** where it
meets Q_U21 (a), which is scoped to "no armed sibling" ·
[Q_U22](#q-u22) `^` at a leaf is ARITY-UNIFORM · the carrier gap belongs in
slice 4 · **the remedy points back at the user's own spelling, not at a taught
spelling** — the ruling that retired 4a's entire advice machinery at 4c.

**THE THREE OWED OWNER QUESTIONS — ALL DISCHARGED**, and **two of the three were
MIS-POSED as filed**, which is the close's most transferable finding:
- **Q1** (the Nil-bearing union's quiet miss) — RULED and IMPLEMENTED as slice 6.
  ⭐ The close's audit found ruling (a) was ALREADY not holding at HEAD: C9's OR
  armed the tier from a Map SIBLING, so an absent element PANICKED — the precise
  failure (a) exists to prevent — while a genuine miss in the same population was
  already loud, by the same accident. Both inverted at once.
- **Q2** (the Q_U20 block cell) — ANSWERED. The recorded premise ("the
  extract/assemble distinction COLLAPSES") is TRUE only for plain and rename
  inners and FALSE for the caret family. The real content is the SPEC's own rule,
  which the owner's intuitions independently encoded: **a caret applies EXACTLY
  ONCE, at the level where it is written, and dropped means dropped** (§3.4). Fix
  → **DEFERRED 88**.
- **Q3** (DEFERRED 58, the dyn channel) — ANSWERED by DECOMPOSITION. Filed
  against the union gate; the controls show the same silence with NO union and NO
  broadcast. The broadcast half needed **no new ruling** — the 2b polarity
  already decides it ("may be present" does not discharge "must offer") → 58
  re-scoped in place. The annotation-lie half is NOT a Path Selection question →
  **DEFERRED 89**.

**GATE**: full suite **10072 / 488 / 0** (`[488/488]`, forced re-run) · battery
**420 → 436** · acceptance **77/77** + 89/89 + 6/6 + 29/29 + 28/28 · corpus A/B
REGRESSION-ONLY for this phase by construction (the carriers have ~no corpus
coverage — the vacuous-green hazard, named at the opening and still true).

**⭐⭐ THE METHOD FINDING, and it is the phase's real product.** **Every slice
shipped a defect of mine that a green suite, five green acceptance files and the
battery were ALL blind to** — and at 4d-1 a passing **two-direction mutation
test** was green over one too. The adversarial verify caught every one; twice the
ADJUDICATOR caught what all three skeptics missed or actively cleared. Named
sub-findings, each with a live instance:
- **A boolean over a 3-valued domain is a catch-all in disguise** (4d-2's axis).
- **A TYPE-level argument cannot bound a VALUE-level site** (slice 6's width claim
  — my comment called the bound "MEASURED" when the only measurement was a typing
  refusal that did not bear on the question).
- **A pin's NAME can be the lie** (4d-2's GUARD asserted three arms while testing
  the one that did not change; a real regression stayed green beneath it).
- **A skeptic's CLEARANCE is not evidence** — twice, skeptics agreed and were
  wrong (testing `defn ^` instead of `def ^ :=`; reading a stale snapshot).
- **A control probe is the cheapest way to find a mis-posed question** — Q2's
  pure-dot-path control and Q3's no-union/no-broadcast control each exposed, in
  one probe, that the filed framing named the wrong level.
- **When a design question resolves to "current behaviour is correct", check the
  RULING first.** I argued Q2's divergence was correct structure and offered a
  lean to rule it so, without checking Q_T7 — which rules `^-` as collapsing the
  whole branch FLAT. Rationalising the implementation.
- **Worked examples are a DEBUGGING instrument.** The owner asked for them
  because rule-labels were unparseable; they exposed a defect three audits had
  walked past, and twice corrected MY proposal rather than their understanding.

**CARRIED OUT, filed not hidden**: DEFERRED **75/76** (Q_U19 routes 2 and 3 —
implemented, verified, REVERTED for a monotonicity break; they need a
grouper-side adjacency mint and land TOGETHER) · **77** (three sibling arms still
misattribute; the tuple one advises a spelling that SUCCEEDS WITH THE WRONG
MEANING) · **78** (the census grep cannot see bare-token phase refs) · **79** ·
**80** · **81** (the suite can UNDER-REPORT `total_tests` while `all_pass` stays
true — cross-check against a delta you can predict) · **82** · **83** · **84**
(one absent element still answers for the whole node; loudness by champ hash
order) · **88** · **89**. Re-homed at this close: **45 ✅ · 47 ✅ · 59 ✅**
(all three were shipped but unmarked) · **61** (not scheduled — a feature
question, → X.close triage) · **63** (orphaned on the landed slice 4c → P4e).

**⚠ STRUCTURAL REPAIR made here**: **P4e** and **P4c-5** had NO Progress-Tracker
row despite sitting in the critical path, so "point at the next phase" had
nowhere to land. Rows added, with explicit anchors at the bullets that describe
them.

**Status: ✅ P4d COMPLETE.** Next: **[P4e](#p4e)**.

<a id="p4e-0"></a>

### §5.P4e-0 — the star MINT substrate  (opened 2026-08-08 · ⛔ **ATTEMPT 1 REVERTED 2026-08-09** · re-cut pending)

⛔ **STATUS: the MINT is REVERTED** (`d0ac2a58`). What shipped and stayed is the
IDENTIFIER band, which never needed a mint. The non-identifier carriers are
[DEFERRED 101](DEFERRED.md); attempt 3 is scoped by [Q_U30](#q-u30) (all seven
carriers, tokenizer repair included) and [Q_U31](#q-u31) (glued Sigma refused),
and opens from [the star-surface census](#star-census).

**WHY ATTEMPT 1 FAILED, in one line**: it modelled the mint's blast radius as
*the selection surface*; it is **the whole reader**. Preparse form validators,
the angle/type grammar, the tree grouper's `result` and slice 7's subject-marking
all sit upstream or sideways of `segment-select-items`, and all four are where
the defects were. Attempt 2 (a count-preserving bare marker, designed only) was
refuted for the mirror reason — `segment-select-items` is reached ONLY from the
args of a `$select`/`$select-path` node, and the fold CLOSES the selection as it
folds left, so a non-sentinel marker never arrives.

**The mini-design and mini-audit below are KEPT AS WRITTEN**, including the
"count-changing" finding that turned out to be the root of the failure. They are
the record of a correct process reaching a wrong answer, and the delta between
what the mini-audit measured and what the census measured is the reusable part:
the audit read the two groupers and their siblings; it never asked *who else
counts items*.

**The one thing the mini-audit got right and should be reused**: the star mint IS
count-changing, and `bcast-step-trigger?`'s tree arm IS a behavioural no-op
byte-identical to its own `[else]`. Both verified twice.

#### Mini-design (protocol step 1)

- **Design reference**: [Q_U23](#q-u23) (the `*` unification + its CORRECTED
  lexical-dividend block) · [Q_U27](#q-u27) (the forced hybrid) ·
  [Q_U28](#q-u28) (shadowing matches `^`) · [Q_U29](#q-u29) (mid-star is a
  guided error in all three bands) · [§5.P4e](#p4e).
- **Obligations carried**: **DEFERRED 90**'s fix rides here (the continuation
  classifier must REJECT an unknown continuation instead of renaming to it; its
  precedence half is already discharged — Q_U29 plus the no-output-key
  principle) · the battery pin for the `*` refusal moves WITH its text ·
  DEFERRED 91's wrong advice sits on this path but is P4e-1's fix.
- **Principles in play**: **Correct-by-Construction** — the decline must be a
  positive test by SHAPE, so a future sentinel is excluded by construction; the
  `param-group-candidate?` repair is the in-tree precedent. **Decomplection** —
  two sources, ONE downstream meaning, so the consumer stays one arm.
  **Completeness** — the whole point of Q_U27 is that a ruled operator may not
  have an unspellable case.
- **Mantra check, honestly**: this is READER/PARSER work, so "on-network",
  "all-at-once" and "in parallel" do **not** bite, and claiming otherwise would
  be cataloguing. **One word does bite: STRUCTURALLY EMERGENT.** The mint must
  fall out of *adjacency* — a structural property `adjacent-to-base?` already
  computes and which "consults no token type" — and NOT out of an enumerated
  list of contexts. Q_U8 recorded that "six enumeration under-counts this arc";
  the enumeration is the drift, adjacency is the emergence.
- **Drift risks, named BEFORE code**: (i) enumerating carriers instead of
  leaning on type-blind adjacency · (ii) shipping the decline "as a list of
  one" — its own comment records that this already cost a BLOCKING regression ·
  (iii) letting the two groupers diverge (the F1b.7g class; `surface-rewrite`
  already hand-inlines a non-exported sibling) · (iv) making the splitter
  trailing-only *in effect* and silently admitting mid-star, violating Q_U29 ·
  (v) scope creep into semantics — the consumer here is a REFUSAL.

<a id="p4e-0-audit"></a>

#### Mini-audit (protocol step 2) — read at `da47cf2d`

**⭐ THE SLICE'S DEFINING FINDING: the star mint is COUNT-CHANGING, so it is the
`bcast-brace-trigger?` shape, NOT the `bcast-step-trigger?` shape.** `*` is
POSTFIX — it modifies the item BEFORE it — so the mint consumes the preceding
result item and wraps it (`0` + `*` → `($star-step 0)`, 2 items → 1). Its two
siblings differ exactly here, and the difference decides the tree twin:
- `bcast-step-trigger?` wraps the FOLLOWING token and is count-preserving, so
  **its tree arm is a behavioural NO-OP** — verified by reading:
  `surface-rewrite.rkt`'s arm is `(loop (+ i 1) (cons item result))`,
  **byte-identical to its own `[else]` two lines below**.
- `bcast-brace-trigger?` IS count-changing (3 items → 2), so its tree twin
  genuinely FUSES to one `'bcast-brace-group` node.
**The star follows the BRACE precedent**: the tree twin must fuse, and the
**Q_N3 v2 agreement guard gains a row** — proposed
`("x{a}*" '$star-step 'star-step-group "the postfix star mint, closer-adjacent")`,
using a closer-adjacent spelling so the starred item is the LAST item of the
line, which is what that guard inspects.

**The two sources and where each lives**:
| Head kind | Star's token state | Mechanism | Layer |
|---|---|---|---|
| ordinal, `}`/`]`/`)` closers, sub-blocks | ALREADY its own token, byte-adjacent | `adjacent-to-base?` mint (Q_U8 shape) | BOTH groupers |
| identifier (`database*`) | ALREADY FUSED into the symbol | `split-star-lexeme` (the `split-caret-lexeme` shape) | parser, in `segment-select-items` |
Both converge in `segment-select-items`, which has **4 call sites** — the ω
sub-inner, the block sub, the block, and `$select-path` (the bare dot path) —
so one splitter serves every identifier-headed surface, mirroring `split-step`'s
three sites.

**DEFERRED 90's fix site, read**: `split-caret-lexeme`'s continuation classifier
is a chain of exact-string compares with a **rename catch-all** at the bottom,
which is why `^_*` / `^a*` / `^*` all become labels. The fix is to reject a
continuation bearing an operator character before reaching that catch-all.

**The refusal being replaced**: the `#rx"[*]"` arm on the `$bcast-step` payload
is **ANY-star, not trailing-star**, and its own comment misdescribes it — so
Q_U29 is already this arm's behaviour, and the slice PROPAGATES it rather than
inventing it. Its battery pin matches `#rx"\\(flatten\\) is not implemented yet"`
and is the ONLY `*`-in-selection assertion in the battery.

<a id="p4e-0-a3"></a>

#### ATTEMPT 3, SLICE A — the `postfix-star` TOKEN TYPE  (opened 2026-08-10)

**The shape, and why it is not attempt 1.** [Q_U33](#q-u33) rules a token-**TYPE**
mint: a `*` byte-adjacent to a preceding CLOSER is re-typed from `'symbol` to
`'postfix-star` at `disambiguate-tokens`. **Counts do not move at any layer**, so
the ~416 count-gated validator arms never engage — that is the entire difference
from attempt 1, which minted by FUSION at the grouper and was silently absorbed.
The datum is unchanged (`token-entry->stx` gets an explicit arm returning the same
`'*` the `[else]` produced), following the `colon-annotation` promotion's own
precedent, so the corpus A/B baseline stays clean.

**Grounding**: mini-audit `wf_c062f617-251` (4 facets + completeness critic).
Its load-bearing correction is recorded at [Q_U33](#q-u33): **"at the tokenizer"
was the one home that does not work**, because a recognizer sees only the previous
CHARACTER and `>` is not a closer character.

**Coverage, measured.** Slice A mints on **4 of the 7** named carriers — `x{a}*`,
`xs:{a}*`, `[f x]*`, `(f x)*`. Not `m{0*}` (its `*` is an item INSIDE the brace,
not closer-adjacent — the in-block band, which `segment-select-items` owns) and
not `xs:0*` / `x.0*` (the tokenizer band — **slice B**, per Q_U30's R4). ⚠ The
carrier count is **three** that do not mint, not two; earlier prose said two.

<a id="p4e-0-a3-verifies"></a>

##### THREE verify rounds — every one found a BLOCKING defect in my own code

**⭐⭐ THREE ROUNDS, THREE BLOCKING DEFECTS, AND EVERY GREEN GATE WAS BLIND TO ALL
OF THEM.** In each round the battery, all five acceptance files, the
neighbourhood tests AND the corpus A/B were green over the defect. Rounds 2 and 3
found defects **in the fix for the round before** — which is the "widening a slice
mid-flight is where I introduce defects" pattern (Watching 9) playing out three
times in one slice. **Budget for the second AND third verify.**

**Round 1** (`wf_94041a76-dca`) — four defects, ranked:
- ⛔ **The mint fired on LIVE INFIX MULTIPLICATION.** `.((1 + 2)*(3 + 4))` → `21`
  at 0 errors with the `*` typed `postfix-star`. **A design problem, not a code
  bug**: `)*(` is genuinely both readings and no lookback separates them. Ruled by
  [Q_U34](#q-u34) — the mixfix gate.
- ⛔ **`a >>* b` minted.** The lookback read `token-rrb[i-1]`, the pass's INPUT,
  but `compose-merge?` folds two `>` into `>>` and skips an index — so the star
  saw a *consumed* second `>` (typed `rangle`) that does not exist in the output.
  The arm's own postcondition was false in its own output, and the mint was
  **sticky** across the second round. Fixed by reading `result`, the stream being
  built, which makes the postcondition true BY CONSTRUCTION.
- ⛔ **`1 >* 2` and `[f a >* b]` minted** — a bare `>` is typed `rangle` whether
  or not it closes anything. `rangle` was dropped from the closer set outright;
  no target carrier uses a `>` closer.
- ⚠ The glued Sigma mints. Pinned as an ACCIDENT with the sequencing constraint
  it carries (below), not repaired.

**Round 2** (`wf_2c0e6901-7c6`) — one blocking defect, in the fix itself:
- ⛔ **The frame stack pushed 4 of the 9 opener types while popping all 3
  closers.** `'[` `@[` `~[` `#{` `.{` were each a NET POP that ate the enclosing
  `'mixfix` frame, so the Q_U34 gate leaked straight back onto infix
  multiplication: `.('[1 2] + (1 + 2)*(3 + 4))` → `27` at 0 errors, minting.
  **This is the file's own 31d27c83 wrong-frame-pop class, committed 280 lines
  below the comment that names it.**
- Also: `in-mixfix?` used `memq` over the whole stack where the authoritative
  test is TOP-OF-STACK, over-reaching into brackets nested in mixfix (where `*`
  is measurably NOT infix — `.([+ 1 (1 + 2)*(3 + 4)])` is a type error).

**⭐ THE FIX WAS TO DELETE THE LIST, NOT TO EXTEND IT.** The opener enumeration is
now defined ONCE (`bracket-family-openers` / `brace-family-openers` /
`group-closer-types`) and consumed by BOTH frame stacks. `make-bracket-depth-rrb`'s
three literals were replaced by byte-identical constants, so its behaviour is
unchanged by construction. The stack also adopted the authoritative
kind-sensitive `lparen` push and top-of-stack test rather than inventing its own.

<a id="p4e-0-a3-method"></a>

##### Method findings — these outlast the slice

1. **⭐⭐ MY PROBE AND MY TEST SHARED THE IMPLEMENTATION'S BLIND SPOT.** I wrote a
   17-row frame-stack probe *specifically* to hunt leaks, and it missed the
   4-of-9 defect — because, like the code and like the test block, it only
   exercised `(` `[` `{`. **An instrument written from the implementation
   inherits the implementation's assumptions.** The guard rows must be derived
   from the AUTHORITATIVE enumeration, not from what the code happens to handle.
2. **⭐ A HAND-COPIED ENUMERATION IS THE DEFECT, AND THE FILE SAYS SO.** The tree
   already carried two copies of this opener set and records their disagreement
   by commit hash. The third copy diverged immediately. Prefer deleting the list
   to auditing it.
3. **⭐ A RESULT-NARROWING TEST HELPER FAILS RED FOR THE WRONG REASON.**
   `p4e-star-type` returns the FIRST lone `*`; `def a := .(1 * 2)` has an
   arithmetic star before the one under test, so a correct implementation
   reported RED. Same class as the `run-last` incident (P4c-4c §4.2), opposite
   sign — that one went falsely GREEN. Added `p4e-last-star-type`.
4. **The corpus A/B is a NULL INSTRUMENT for this mint** — measured **0 mints
   across all corpus files** (every `]*`-shaped grep hit is inside a comment).
   "The A/B baseline stays clean" is true and vacuous; all real coverage is the
   authored battery. Do not cite the A/B as evidence for this slice.
5. **The adjudicator sharpened or found the worst defect in BOTH rounds** — the
   infix-multiplication finding reached only one skeptic, and the 4-of-9 finding
   was independently reproduced by the adjudicator with a wider blast radius
   (60 false positives across nesting combinations). A skeptic's clearance is
   still not evidence.

<a id="p4e-0-a3-owed"></a>

##### ⛔ THE SEQUENCING CONSTRAINT SLICE A HANDS TO ITS CONSUMER

`<(x : Nat)* Nat>` is legal today, elaborates to `[Sigma Nat Nat]`, and **mints** —
its `*` follows `)`, a genuine closer, outside mixfix. No closer-set or gate
repair reaches it, and gating on angle frames was considered and REJECTED (a `<`
is typed `langle` whether it opens a group or is the less-than operator, so an
angle stack mis-nests on `a < b` and suppresses legitimate later mints).

It is harmless in slice A for one exact reason: **`tree-parser.rkt` finds the
Sigma `*` by LEXEME, not by type** (`grep -c token-entry-types tree-parser.rkt`
→ 0), so a type-only mint is invisible to it.

**[Q_U31](#q-u31)'s refusal of the glued Sigma MUST land before any consumer keys
on `postfix-star`** — otherwise a live Sigma type silently becomes a star step.
That is a Tier-A silent-wrong-answer deferred by exactly one slice, and it is
pinned in the battery so the constraint cannot be lost.

<a id="p4e-0-a3-round3"></a>

##### Round 3 (`wf_573914d7-b8b`) — the mirror image, and a fourth list copy

- ⛔ **A STRAY CLOSER inside mixfix over-popped the frame.**
  `.( } (1 + 2)*(3 + 4) )` → `21` at **0 errors**, the stray `}` eating the
  `'mixfix` frame so the star minted on live multiplication again. Exact mirror
  of round 2's under-push.
  **⭐ THE FINDING THAT MATTERS MORE THAN THE BUG: the authority for mixfix
  extent is `group-items`, NOT `make-bracket-depth-rrb`.** `group-items` carries
  a `close-type` and lets a NON-matching closer fall through as a plain item —
  which is why that probe still prints 21. The bracket-depth stack pops
  unconditionally and over-pops too, so **mirroring it faithfully reproduced its
  bug**. "It mirrors the authoritative one" was true and insufficient. The gate
  now pops only on the frame's own expected closer.
  ⚠ A **matching** `)` does close the group, so `.( ) (1 + 2)*(3 + 4) )` mints —
  correctly, and not silently: `.( )` is a LOUD per-command error ("Empty .( )
  mixfix expression") with the rest of the file still produced.
- ⚠ **`token-entry->compat` had no `postfix-star` arm** — the exported
  `tokenize-string` type changed while its value did not. Armed to report
  `'symbol`, the same remap that case already does for `pipe-right`/`clause-sep`.
  This is the sibling-inconsistency the `dot-ordinal` arm documents as "how the
  next reader gets misled".
- ⚠ **I had created a FOURTH copy of the list I had just made a constant for** —
  the star arm's own closer test was still the literal. Fixed, and the two
  `31d27c83` twins (`langle-matched?` / `has-matching-rangle?`) now share
  `all-group-openers` + `group-closer-types` as well. **Hand-copied opener lists
  in this file: 0.**
- ✅ The round confirmed the shared-enumeration substitution is **pure** — the
  constants are member-identical to the literals they replaced, so
  `make-bracket-depth-rrb` is unchanged by construction.

<a id="p4e-0-a3-flake"></a>

##### ⚠ THE SUITE IS INTERMITTENT, AND IT IS PRE-EXISTING — do not attribute it

Chasing a suspected regression cost real time and produced a fact worth keeping.
Two anomalies appeared during slice A's gating and **both are ambient**:

- **The suite's test COUNT varies.** `test-properties.rkt` is a RANDOMIZED
  property test (`gen:integer-in`); across **469 recorded full-suite runs** its
  case count is **13 in 411 and 8 in 55**. So a ±5 swing in the total is normal
  and says nothing about a change.
- **Full-suite runs fail intermittently at ~16%** — **74 of 469** historical runs
  recorded `all_pass=False`. Slice A saw 1 failure in 8 runs (12.5%), squarely on
  that baseline; the two failures were in DIFFERENT files (`test-mixfix-01`,
  `test-mixfix-02`), neither reproducible in isolation (5/5 and 4/4 clean).

⚠ **A 5-run base sample MISSED BOTH**, which is exactly how a pre-existing
intermittent gets attributed to whatever changed last. **Check
`data/benchmarks/timings.jsonl` — it records 469 runs with per-file counts and
`all_pass` — BEFORE running a base A/B.** One query answered in seconds what five
worktree suite runs could not.
⚠ Also re-learned: **do not compile while a suite is in flight.** One run was
contaminated that way and its failure sent me down the wrong path first.

<a id="p4e-0-b"></a>

#### SLICE B — the tokenizer repair (R4): BUILT, VERIFIED, ⛔ **REVERTED**  (2026-08-10)

**Status: ⛔ REVERTED. R4 is NOT independently landable** — see
[DEFERRED 105](DEFERRED.md). This is a SCOPING result, not a coding error, and it
is the piece the census's "unreachable without a tokenizer repair" phrasing left
open: the repair is necessary and **not sufficient**.

**What it did, and it worked at the token layer.** Both digit arms of
`recognize-dot-ordinal` / `recognize-colon-annotation` stopped before a trailing
`*` instead of declining on it; the mint's predecessor set gained
`colon-annotation` / `dot-ordinal`. `xs:0*` → `xs` `:0` `*` → `(xs ($bcast-step
:0) *)`; `x.0*` → `(x ($postfix-index 0) *)`. Six of the seven carriers minted;
battery 468 green, acceptance 84/84, every slice-A gate held.

**⛔ AND IT WAS A SILENT-WRONG-ANSWER REGRESSION.** 4 tokens → 3 makes the star a
separate DATUM ITEM, and item counts are load-bearing. `def w2 := [take2 p.0*]`
went from a loud `Too many arguments` at HEAD to **`w2 : Int defined.` / `10` at
zero errors**, the written flatten silently discarded and the `*` filling a
parameter slot. A `defr` fact row registered 2 rows instead of 4; a `bundle` went
from a guided refusal to inventing a type parameter. **Attempt 1's failure mode,
one slice later, in a narrower aperture** — violating the very property slice A's
shipped comment names as "the whole reason this is not attempt 1".

**⚠⚠ THE METHOD FINDING, which outlasts the slice: CONTAINMENT IS NOT A SAFETY
PROPERTY.** A verify axis measured **1,943/1,943 glued ≡ HEAD-spaced** and offered
it as *"the argument that makes the count change payable"*. It is a category
error: token-stream containment says HEAD *could* have produced this stream **from
different source text**, never that the written source's MEANING is preserved.
`xs:0 *` and `xs:0*` agreeing **is the defect**. An axis cleared the slice on it;
the adjudicator overturned that clearance and found a fourth defect none of the
three skeptics had. **A containment result must be restated as a meaning claim
before it counts as evidence.**

**WHY THE OBVIOUS FIX DOES NOT APPLY.** The identifier band is count-preserving
because it FUSES — `x.name*` is ONE token, the star riding inside the symbol
(`($dot-access name*)`) for `split-star-lexeme` to split later. The ordinal band
cannot: `$postfix-index`'s payload is `(string->number (substring lexeme 1))` and
must be NUMERIC, so a `.0*` lexeme yields **`#f`**. **The star has nowhere to live
in an ordinal payload** — which is also why the twins use `ascii-digit?` vs
`char-numeric?` and why "apply the same patch twice" was never the shape.

**WHAT R4 IS BLOCKED ON**: the star's DATUM REPRESENTATION — a wrapper sentinel
(`$star-step`, recorded in `reader-forms.rkt` as *"DELIBERATELY ABSENT … a
deferred RULING"*) or a widened `$postfix-index` arity. Both are **P4e-1
representation decisions**, not tokenizer work. ⚠ **Reopen R4 only after that
ruling**; the tokenizer diff is small and re-derivable, and DEFERRED 105 carries
it.

**Kept from the slice**: the stale co-migration pointer in
`recognize-colon-annotation` (it said `parser.rkt`; `fused-type-annot?` moved to
`reader-forms.rkt` at LET P4), plus the measured note that the co-migration is
narrower than it reads — that predicate already excludes digit-headed colon
symbols, so `:0`-shaped tokens were never in its domain.

<a id="p4e-1"></a>

### §5.P4e-1 — the `*` SEMANTICS  (opened 2026-08-10 · ⬜ **1a designed, tests written, NOT implemented**)

**Where it stands**: the design is settled, the arrival inventory is generated, and
P4e-1a's failing tests are written and **parked COMMENTED** in the battery (the
acceptance-file idiom). No implementation. Resume by uncommenting them.

**⭐ WHY THE MINT NEEDS THIS PHASE AT ALL.** Slice A's `postfix-star` token type is
**datum-invisible by design** — that is what kept the corpus A/B baseline clean,
and it is also why the mint is **INERT**: `token-entry->stx` renders it as a plain
`*`, so no consumer can see it. Measured: the carriers give `Could not infer type`,
identical to their spaced controls, so there is currently **ZERO observable
difference** between glued and spaced. A consumer therefore CANNOT be built without
making the datum visible — the two out-of-band channels are both dead (syntax
properties AND srcloc are destroyed by preparse for `cfg{a}*` / `xs:{a}*` on a
`def … :=` RHS, while surviving at command position, so either would work for half
the carriers and silently fail on the surface users actually write).

**⭐⭐ THE CORRECTION TO [DEFERRED 105](DEFERRED.md), and it is what makes
semantics-first viable.** 105 recorded "the datum representation must be decided" as
ONE gate. It is TWO, and they separate:
· For slice A's carriers the star **already occupies a datum item** — measured,
  `def b := cfg{a}*` reads `(def b := cfg ($select-brace a) *)`. Renaming that
  item's VALUE is **COUNT-PRESERVING** and never engages what killed slice B.
· For `xs:0*` / `x.0*` the star has **no item at all** (they shatter), and restoring
  the carrier is what changes the count. That blocker is untouched.
**Four carriers clear, two blocked.** Not "avoids" and not "reaches from the other
side" — a partition, and the slicing must say so.

**THE DESIGN.** Emit `$postfix-star` at `token-entry->stx`; fuse at
`rewrite-dot-access` — the seat this repo already uses for `$dot-access` /
`$bcast-step`. Rule: a `$postfix-star` immediately following a **selection-shaped**
item fuses into a star step; anywhere else it is [Q_U35](#q-u35)'s guided refusal.
⚠ `access-sentinel?` tests HEADS of sub-lists, so a bare `$postfix-star` ATOM does
not trip `rewrite-dot-access`'s gate — it needs its own gate clause, and
`ordinal-rekey-shatter?` is the in-file precedent for exactly that (a sentinel-FREE
shape with its own clause).

**⚠⚠ THE ARRIVAL INVENTORY — GENERATED, NOT READ.** A `postfix-star` token reaches
a datum in **40 of 44** carrier × context spellings, across **ELEVEN** contexts:
command position · `def` RHS · application argument · bracket application · nested
bracket · map-literal value · vector literal · list literal · select-block item ·
`defn` body. Only the four mixfix spellings do not — [Q_U34](#q-u34)'s gate working.
**So the rename puts a sentinel into eleven contexts at once**, and a bare sentinel
reaching the user is the class the revert `d0ac2a58` itemised. [Q_U35](#q-u35) is
what makes it tractable: everything outside selection is REFUSED, not armed.
(The inventory was generated over a carrier × context matrix rather than read off
the code — the last three blocking defects in this arc were all bad enumerations.)

**OWED before implementing**:
- The Tier-O sentinel obligations (`pipeline.md` § "A new sentinel, an old
  recognizer"), **`pattern-var?` first** — a miss there is a whole-file abort in a
  `defmacro` template.
- ⚠ [Q_U23](#q-u23)'s claim that the nominal-join collision "needs no P5 machinery,
  because P3a already landed strict merge" is **REFUTED by the grounding**:
  `make-record`'s body is `;; last write wins`, and `dup-output-key` / `mixed-sorts?`
  fold over **written** branches at parse time, so the landed gate structurally
  cannot see SUBJECT-DERIVED keys. A star over a `Map` needs a ruling: refuse, or
  defer to a runtime merge?
- ⚠ [Q_U31](#q-u31)'s stated cost ("one guided error at a `star-symbol?` call site")
  is **not implementable as written** — glued and spaced Sigma are datum-identical,
  so `star-symbol?` (a datum test) cannot tell them apart. The refusal must key on
  the `postfix-star` TOKEN TYPE or on srcloc adjacency. And `$star` escapes a
  type-keyed refusal entirely (`<(x : Nat)$star Nat>` → `[Sigma Nat Nat]`, 0 errors).
- `.*` retires per Q_U23 with **no inventory taken** of what currently consumes it.

<a id="p4e-1a"></a>

#### §5.P4e-1a — the mint gets a consumer  (opened 2026-08-10 · ⬜ **3 slices, not started**)

Mini-audit `wf_9bbe5f5a-9e0` (4 facets + completeness critic); every load-bearing
claim below re-verified on the main thread. Rulings: **[Q_U36](#q-u36)** (the
positive-list fuse) and the sequencing below.

**⭐⭐ THE INVENTORY IN [§5.P4e-1](#p4e-1) IS A 21% SUB-FRAME. GENERATED, NOT READ.**
"40 of 44 across ELEVEN contexts" is TRUE — the audit regenerated it and D4's
4 × 11 frame reproduces **exactly**, all 40 non-mixfix cells arriving and all 4
mixfix cells blocked. But the frame is not the blast radius:

| | D4 §5.P4e-1 | MEASURED |
|---|---|---|
| minting carriers | 4 | **10** |
| arrival contexts | 10 (prose says 11; the 11th is mixfix, where nothing arrives) | **19** |
| cells | 44 (40 arrive) | **280 (190 arrive)** |

The six carriers this document never counted — `.(1 + 2)*` · `'[1 2]*` ·
`@[1 2]*` · `#{1 2}*` · `{:a 1}*` · `` `[a 1]* `` — each arrive in 19 of 20
contexts, and they mint for a PRINCIPLED reason: `]` `}` `)` are all in
`group-closer-types`. (`#p(a)*` does NOT mint in any context — `#p(a)` lexes as
ONE `path-literal` token, so no `rparen` precedes the star. It is misread as
arithmetic today, but it is outside slice A's mint domain.) The nine further
arrival contexts: pattern position · spec/type position · set literal · `defr`
fact row · goal argument · `let` binding value · `match` scrutinee · quasiquote
body · `defmacro` template.
⚠ **The census had already found this** (`2026-08-09_STAR_SURFACE_CENSUS.md`
MISS 3: *"the population is 11, not 4"*), and this document cites that census as
"the design's input" while its inventory does not carry MISS 3 forward. The
census's completeness critic additionally PREDICTED the pattern-position miss —
*"will still miss that `*` IS ALREADY A BINDING PATTERN"* — and that prediction
is live below.
⚠ **The generating matrix did not exist in the tree.** `1476734b` touched two
files (this doc + the battery); there was no generator, table or data file, so
the claim was **unfalsifiable at HEAD**. That is the bad-enumeration shape this
arc keeps paying for. **Slice 1a-i lands a durable generator.**

**WHY [Q_U36](#q-u36) DISSOLVES THAT.** Under a NEGATIVE list the 4.3× under-count
is a defect generator. Under a POSITIVE predecessor test the population stops
bearing on correctness — every cell fuses or refuses by construction — and the
inventory becomes a GATE-COVERAGE obligation. That is the difference between
this being a scoping crisis and a test-widening task.

**⚠ TWO PRE-EXISTING SENTINEL HOLES, and the differential is what proves they are
pre-existing** — filed [DEFERRED 106](DEFERRED.md) + [107](DEFERRED.md), NOT
fixed here (they reproduce without the star; *Watching 9* says mid-flight
widening is where this arc introduces defects):
1. **The `let` nested-shorthand binding value is not reached by any of the four
   `rewrite-dot-access` seats.** At HEAD `let k c{a}*` reports
   `let: unrecognized format: (let k c ($select-brace a) * k)` — a raw sentinel
   at the user. The differential settles authorship: `let k c.a` gives
   `(let k c ($dot-access a) k)`, the same leak with no star. Spelling-sensitive
   within `let` itself (the ALIGNED form folds correctly), so one gate row would
   not find it. ⚠ This BOUNDS [Q_U35](#q-u35)'s "refusing dissolves that whole
   blast radius" — true only WHERE THE FUSE SEAT RUNS.
2. **Carrier-plus-star in PATTERN position mints, and is unruled.**
   `defn h | [f 1]* -> 1 | z -> 2` silently drops arm 2 and changes arity, with a
   diagnostic that never mentions the star. The `c.a` differential is worse —
   `h defined (arities: 1, 3)` at **ZERO errors**. [Q_U32](#q-u32)'s measured
   domain is BARE `*` only, and its refusal **has never landed**.

**FOUR MORE VERIFIED FINDINGS** (each corrects something shipped):
- ⭐ **The slice-A pin's harmlessness argument names a DEAD PATH.** It says the
  glued Sigma is safe because *"`tree-parser.rkt` finds the Sigma `*` by LEXEME,
  not by type"*. True of tree-parser, irrelevant to production:
  `merge-preparse-and-tree-parser` (driver.rkt) now returns only filtered
  `preparse-surfs` — the tree leg is gone. The live path is preparse →
  `parse-datum` → `star-symbol?`. The pin's CONCLUSION (the sequencing
  constraint) is right; its MECHANISM is false, and a right conclusion from a
  wrong premise is how the next reader gets it wrong.
- ⭐ **[Q_U31](#q-u31) has TWO identity families, not one call site.**
  `star-symbol?` (`parser.rkt`, 7 call sites) **and** `param-type->angle-type`
  (`macros.rkt`, `(memq '* ptype)`), whose own comment says it exists because
  *"without this, `(A * B)` … gets delegated to parse-datum which treats `*` as a
  variable name"* — exactly what the rename causes. Zero corpus instances, so it
  would land silently. ⚠ A reader-seated refusal cannot reach family 2, because
  its `$angle-type` is SYNTHESIZED AT PREPARSE — which is why the refusal rides
  the rename rather than preceding it.
- The rename is probe-verified to break Sigma: `parse-datum` on
  `($angle-type (x : Nat) $postfix-star Nat)` returns a `surf-app` chain
  containing `surf-var $postfix-star` where today it returns `surf-sigma`.
- `access-sentinel?` opens `(and (list? x) (pair? x) …)`, so a bare atom can
  never satisfy it (`(access-sentinel? '$postfix-star)` → `#f`); the gate needs
  its own disjunct, `ordinal-rekey-shatter?` being the in-file precedent. The
  fold's tail UNWRAPS a one-element result, and `preparse-expand-subforms`
  RE-ENTERS whenever the fold changed the datum — so the emitted head must not be
  an `access-sentinel?` member or the P1b-iii left-sibling-swallow returns.

**THE SLICING — three, and the last is necessarily atomic** (owner-assented
2026-08-10). It inverts slice A's failure mode, where the risky change went
first and every verify round then found a defect in the previous round's FIX:

1. ✅ **1a-i — the generator + the widened gate** (`ff9b7d81`). Battery 465 → 466,
   file 74 s → 79 s, neighbourhood 322 green.
   **⭐⭐ THE FINDING: THE OBSERVABLE WAS WRONG, not merely narrow.** The gate
   first grepped user-visible output for `$postfix-star`. The adversarial verify
   simulated 1a-iii by planting the sentinel in each cell and running the gate's
   own machinery: it could fire in **72 of 190** cells, and in the rest clean and
   planted output is **byte-identical** — an unconsumed sentinel is an EXTRA
   DATUM, so the form fails on SHAPE long before anything renders the symbol.
   The invariant is **"no unconsumed `$postfix-star` survives PREPARSE into the
   datum"**, now the primary assertion. Measured and stated, not rounded to
   "total": **datum 187/220 · message 92/220 · UNION 208/220**, complementary
   rather than nested, 12 residual blind cells clustering in `let-bracket` (8),
   `quasiquote-body` (3), `let-nested` (1) — DEFERRED 106's own seat.
   The verify found **four more defects in my code** (a `defmacro-tmpl` row that
   never registered a macro so `datum-subst` never ran, while 33 output lines
   made it look healthy; whole contexts skipped when a batch raised; an
   unreachable `pair?` assertion; a mint pin asserting cardinality not
   membership) and I found a fifth before it (`star-cell-source` took a string
   while every caller passed the record — `format`'s `~a` hid it and every count
   and both mutation tests still agreed). Matrix now **11 × 19 = 209** cells +
   5 controls; DEFERRED 108 re-measured 19/280 → 21/320.
2. ✅ **1a-ii — the Tier-O arms, inert** (`dc458109`). Battery 466 → 469,
   neighbourhood 287 green. **TWO lines of production code**, and that is the
   finding: the generated inventory said *no arm needed* far more often than
   *arm* — `access-sentinel?` + the head sets, `flatten-ws-datum`, and both
   preparse lists all require a PAIR, so a bare atom can never reach them
   (Q_U36's point, arriving as a coverage dividend).
   ⚠ **The handoff's premise was stale**: a `pattern-var?` miss is NOT a
   whole-file abort any more. DEFERRED 3 was discharged at `446070fc`, and
   `pipeline.md` + `macros.rkt`'s own comment were both wrong about it —
   corrected in this slice. The residual raise is `datum-subst-list`'s SPLICE arm
   alone: unreachable from WS (`...` reads as `$rest`), and G2-degraded in sexp.
   **⭐⭐ TWO REVERSALS OF MY OWN WORK.** (i) I fixed the splice arm structurally
   — its stated invariant *is* falsified by `$postfix-star`, the first
   bare-symbol sentinel — and the neighbourhood turned `test-defmacro`'s "the
   SPLICE branch keeps its unbound error" RED. That raise is a **ruling**; only
   its rationale was false. *A falsified rationale does not license reversing the
   decision it was offered for.* (ii) I gave `pp-datum` an arm rendering the
   sentinel as `*`; the verify showed every CONSUMED marker deliberately has no
   arm and prints its internal name, because **appearing there is the defect** —
   `*` would hide a leak inside `expand`. Both reversals are pinned with their
   reasoning so the next bare-symbol sentinel does not re-derive them.
3. ✅ **1a-iii — the atomic change** (`9cac0099`, attempt 2 per [Q_U37](#q-u37);
   attempt 1 recorded below). Battery 469 → 476 · neighbourhood 497 across 14
   files · acceptance 84/84 by diff · **full suite 10143 / 488 / 0** · five
   mutations kill. `xs:{a}*` and `c{a}*` reach `star-not-yet-message`; the two
   parked tests are LIVE; `[f x]*` takes the guided refusal; the glued Sigma
   takes the angle-generic type-seat message at both families (the live family-2
   route is the SPEC spelling); quote/quasiquote capture the star as `*`.
   **The fuse RETIRED two whole-file aborts** (DEFERRED 108: 21 → 19 — the
   usable carriers in match-scrutinee now get a guided message).
   **⭐⭐ ROUND 2'S VERIFY FOUND THE RENAME LEAKING THROUGH ERROR ECHOES** — the
   def seam and the fn binder error both echo source datums, and the rename
   silently changed the echoed content from `*` to the internal sentinel, in two
   seats the matrix's leak pin structurally cannot see (off-matrix positions).
   Fixed via `unmint-star-for-echo`: error echoes render the USER'S spelling
   (capture-fidelity, same argument as the quasiquote arm — and the OPPOSITE of
   `pp-datum`, where the internal name is deliberately the tell). Also: the
   family-2 pin was VACUOUS (`|defn requires` alternation — an instrument hedged
   into its own blind spot; the defn spelling dies before the arm is reached)
   and its comment asserted the dead route; both corrected, and the fifth mutant
   (the `memq '$postfix-star` disjunct) now kills. The preparse-RAISED set is a
   pinned snapshot (3 cells, all star-free pre-existing). Filed: **DEFERRED
   110** (pipe-terminal fused star — `expand-pipe-block`'s one-element unwrap
   spreads a fused node; pre-existing, pinned AS an accident) · **111** (the
   raw-datum-echoing error-site CLASS: two instances fixed, census unclaimed) ·
   **112** (`$facts-sep`, star-free, rel-territory).

   **⭐ THE FUSE SEAT IS GROUNDED — the open question from the P4e-1a audit is
   ANSWERED, and the answer is favourable** (measured at `79e34380`; this is the
   one thing 1a-iii most needed settled before writing code):
   - **`rewrite-dot-access` does NOT have the selection-CLOSING property that
     killed attempt 2.** That property belongs to `segment-select-items`, which
     [DEFERRED 101](DEFERRED.md) records is *"reached ONLY from the args of a
     `$select`/`$select-path` node, and the fold CLOSES the selection as it goes
     — so a non-sentinel marker is left a SIBLING of the finished node, outside
     the args."* `rewrite-dot-access` is a **different fold**: it keeps each
     wrapped node in its accumulator, where the next sentinel can consume it.
     The design's choice of seat is sound, not lucky.
   - **Its arms already have exactly the postfix shape the star needs.** The
     `$dot-access` arm takes `(car acc)` as the target and replaces it with
     `($select-path target field)` — *consume the preceding element*, which is
     what a postfix `*` is. The ω arm added at P4c-4b is that arm verbatim except
     the payload rides WHOLE. A star arm is the same shape a third time.
   - **⚠ THE FIXPOINT OBLIGATION IS THE ONE TO RESPECT.** The emitted head must
     NOT be an `access-sentinel?` member, or `preparse-expand-subforms` re-enters
     and **swallows one LEFT sibling per pass** — the P1b-iii defect that
     silently dropped a `defn` clause at zero errors. Verified: neither
     `arity2-access-sentinel-heads` nor `brace-access-sentinel-heads` contains
     `$select-path`, which is why the existing arms emit it.
   - **The refusal message already exists and is reachable for free.**
     `star-not-yet-message` (parser.rkt) fires from `segment-select-items`, i.e.
     from the ARGS of a `$select`/`$select-path` node — so a star fused INTO
     those args inherits the message the parked test expects, rather than needing
     a new diagnostic. Its own comment already says so: *"Giving them this same
     message is P4e-1's first deliverable; until it lands, do not read this
     comment as a contract."*

   **⛔ ATTEMPT 1 (2026-08-11) — BUILT, VERIFIED, REVERTED; patch parked at the
   session scratchpad (`slice-1a-iii.patch`), findings recorded here, ruling
   [Q_U37](#q-u37).** The build was CLOSE and most of it survives into attempt 2:
   the rename, the gate disjunct, the Q_U36 fuse, both Q_U31 family edits and the
   parked-test uncomment were all correct in content. What was wrong was WHERE
   one decision was made — the fold emitted Q_U35's refusal as a
   `($retired-selection star-no-selection)` marker at preparse, EVERYWHERE.
   The adversarial verify measured the two consequences of that one assumption:
   1. **The marker PRE-EMPTED the Sigma seat.** Inside `$angle-type` contents the
      star was rewritten before `unwrap-angle-type` could see it, so the Q_U31
      Sigma refusal this slice added **shipped unreachable** — its guided message
      never fired, the generic Q_U35 text fired instead. A refusal written and
      landed, and structurally dead on arrival.
   2. **The marker broke the quasiquote lowering** — a three-element list where a
      symbol was expected, in data territory where nothing should be rewritten.
   Plus four smaller: the `xs[0]*` matrix-row comment contradicts the positive
   list (bracket-postfix is NOT on the carrier per §2.4, so the refusal is
   correct-for-now — fix the COMMENT) · the backstop's message text was a
   verbatim duplicate of the marker's · the fold's fixpoint comment no longer
   covered the widened gate · prose in a code slot.
   **MEASURED WINS TO RE-EARN in attempt 2** (they were real, and the abort pin
   is where they show): the fuse retired the two `match-scrut` aborts for the
   usable carriers (21 → 19), and the preparse marker retired six `pattern-pos`
   aborts (19 → 13). Attempt 2 keeps the first (the fuse stays) and gives back
   the second (the marker goes) — the six `pattern-pos` cells return to
   DEFERRED 108's pre-existing residue, which is honest: they were shielded by
   the wrong mechanism, not fixed.

**Scope OUT, with reasons** — [Q_U23](#q-u23)'s Map/strict-merge ruling (this
slice ships the *not-yet message*, never the flatten, so the semantics are not
reached) · the `.*` retirement inventory (Q_U23's own surface) · DEFERRED 106 +
107 (pre-existing, differential-proven).

<a id="p4e-1b"></a>

#### §5.P4e-1b — the `*` SEMANTICS  (opened 2026-08-11 · ⬜ mini-audit DONE, rulings [Q_U38](#q-u38)+[Q_U39](#q-u39), **not implemented**)

Mini-audit `wf_4b91ca25-73a` (5 partitioned read-only facets + completeness
critic, HEAD-pinned `4cf8cad3`). **Every load-bearing claim below was
R-lens-verified on the main thread** — two of the critic's were corrected in the
process, and one facet's headline was discarded.

**WHAT THE AUDIT SETTLED** (each re-measured here, not inherited):

- **The collision refutation is TWICE AS WIDE as recorded** — two last-write-wins
  sites, not one. `make-record` is the TYPE-level constructor and IS on the
  select path (`select-assemble-row`, typing-core.rkt); `entries->value`
  (reduction.rkt) is its VALUE twin, a `champ-insert` fold. → [Q_U38](#q-u38).
- **Both parse gates are blind for a MECHANICAL reason**: `select-branch-top-keys`
  takes exactly ONE parameter. Not an oversight — a structural bound. → Q_U38.
- **The two layers disagree about field ORDER** (`make-record` sorts;
  `entries->value` does not). No facet found this; the critic did. → Q_U38.
- **`*_` is already live in the fused-identifier band and absent from the
  closer-adjacent one**, mint gate `(string=? lexeme "*")`. → [Q_U39](#q-u39).
- **[Q_U23](#q-u23)'s identity claim CONFIRMED at BOTH layers** — and it had been
  covered by NO facet; the critic measured it. `cfg{database.{url pool-size}}` ≡
  `cfg{database}` and `cfg{database^.{url pool-size}}` ≡ `cfg.database`,
  byte-identical, robust to branch reorder. **This is the strongest evidence that
  the splat's plumbing already exists and behaves as Q_U23 predicts.**
- **[Q_U23](#q-u23)'s splitter claim CONFIRMED verbatim** — `split-star-lexeme`
  has exactly THREE call sites, mirroring `split-step`'s three, and the ω payload
  does arrive colon-leading and string-stripped while the others arrive bare.
- **[Q_U24](#q-u24)'s inheritance CONFIRMED** — `^-_` carries `'collapse-synth`
  (a collapse; ONE flat entry lifts) while `^_` carries `'synth` (relabel in
  place, nesting preserved), and `split-star-lexeme` already records at its own
  site that `'flatten-synth` inherits `^-_`'s rule.
- **Not blocked on PF.** The step vocabulary is plain s-expressions, so a star
  kind needs no ADT. `path-segments`'s whole-file abort is pre-existing, filed,
  and off the star's path — but the PF repair INHERITS the star as a marshalling
  obligation (`(expr-keyword seg)` assumes bare symbols; a star step is a list).

**⚠ CORRECTIONS TO THE AUDIT ITSELF — it is not authoritative either:**

1. **The critic's headline capture-gap is a REPRESENTATION QUESTION, not a
   refutation.** It found (verified) that the ω band's local `push` wraps every
   minted step in `make-select-bcast` unconditionally, so a star landing there
   rides as the ω INNER — `(@bcast <star-step>)` — and called that a
   contradiction of Q_U23's own headline example. **The structural fact holds;
   the contradiction does not follow.** Read through the layer model, inner
   placement may be RIGHT: `xs:diags` yields a vector whose inner layer is what
   each `diags` contributed, and "delete the layer the preceding step created"
   plausibly means splice each element's contribution into the parent. The star
   also rides inside the `:diags*` TOKEN, so the surface puts it there lexically
   too. **OPEN — owner ruling owed; see below.**
2. **"At least 20 sites" is NOT verified and must not be quoted.** The recipe IS
   stale — `select-step-kind` dispatches at parser.rkt (the `^`-in-path-access
   refusal) and typing-core.rkt (`select-tier-subject`'s ω peel) are outside its
   13-site list, both confirmed by independent census, and its boast that the
   sixth kind *"met all thirteen … with no correction needed"* is therefore
   false. But the open-coded classifier grep returns 16 sites outside
   `syntax.rkt` and several sit INSIDE functions the recipe already names.
   The honest number needs per-site enclosing-function attribution — slice work,
   not a citable figure.
3. **Facet 2's headline is DISCARDED.** It opened *"REFUTES THE FACET'S OWN
   FRAMING: `make-record` is NEVER called on a runtime selection result"* and
   called the main-thread measurement mis-anchored. It is right that
   `make-record` is type-level; its framing would have cost us the refutation.
   `select-assemble-row` puts it squarely on the select path. The design's defect
   was UNDER-COUNTING, not mis-naming.

**CAPTURE GAPS carried forward** (not 1b's work unless marked):

- **Three ω-inner dispatchers are load-bearing and none is on the recipe**:
  `bcast-apply` (reduction.rkt), `select-bcast-lift` and
  `select-bcast-inner-apply/non-union` (typing-core.rkt). All three branch on
  `select-sub-step?` and fall through to a symbol/generic path otherwise — so a
  star inner would be handled SILENTLY as a symbol. **This IS 1b's work** if the
  ω placement question resolves inner.
- `select-step-name` / `select-step-cont` end in permissive `[else s]` / `[else #f]`
  tails and sit outside the recipe BY DESIGN. A star kind would get the RAW STEP
  LIST back from the first (the DEFERRED 40/46 raw-list-in-a-message class) and
  `#f` from the second — and `#f` is what `findf select-step-cont` and
  `branch-problem`'s positional check key on. **1b's work.**
- **`select-sorts` is `'(path block)` — the SELECTOR sort, not a container sort.**
  Two facets caught this independently. "The sort follows the layer" reads as a
  claim about `select-sorts` and is NOT one; the container decision is a separate
  keyed/keyless fork inside `entries->value`. **Correct the vocabulary before
  "sort-generic" is used again.**
- **The rule is not total over the vocabulary**: an ordinal STEP `.N` contributes
  NO output level (Q_U2 Reading A), and a `'path` selection builds no layer at
  all. Two different reasons, both needing a stated disposition.
- **The `.*` retirement's TEST surface was swept by nobody** — `test-selection-paths.rkt`
  carries **17** lines with a live `.*`/`.**` spelling (measured) across a
  56-case file, plus `test-path-selection.rkt`'s `#p(a.*)` refuse-loudly pins.
  That is the bulk of what a retirement must move. **P4e-2, not 1b.**
- **`selection-field-unrestricted?` (typing-core.rkt) is the ONLY place the
  selection `*`/`**` carries TYPE-level meaning** and is absent from every
  consumer list this design has written. **P4e-2.**
- **The retirement inventory intersects uncommitted owner WIP** —
  `lib/examples/foray.prologos` documents `.*` as the splat operator and is
  MODIFIED in the working tree. Any sweep that edits it collides.
- A repo-root grep picks up `.claude/worktrees/` and silently double-counts
  against a stale branch. **Scope every sweep to `racket/`, `docs/`, `tests/`.**

**SCOPE, per [Q_U39](#q-u39)**: 1b lands the flatten + Q_U38's refusal + `*_` in
the fused-identifier band. OUT: the closer-adjacent `*_` mint (own slice);
the `.*` retirement + ravel (P4e-2); DEFERRED 106–112.

**THE ω PLACEMENT IS RULED — [Q_U40](#q-u40) OUTER**, with [Q_U41](#q-u41)
scoping `*_` to nominal layers. The semantics are now fully specified; what
remains before code is the slicing plan. Three consequences for the
implementation:

1. **The representation is already in the tree.** OUTER is the shape the
   closer-adjacent fuse emits (`($select-path <step> $postfix-star)`), so only
   the FUSED-IDENTIFIER band needs normalizing outward — lifting the star out of
   the lexeme to the wrapper. That is the opposite direction from what INNER
   would have needed, and it is why the placement was worth settling before
   writing anything.
2. **The three ω-inner dispatchers are OFF the hook.** `bcast-apply`,
   `select-bcast-lift` and `select-bcast-inner-apply/non-union` became
   load-bearing only under INNER. Under OUTER the star never appears as an ω
   inner, so their absence from the recipe stops being 1b's problem. ⚠ The recipe
   is still stale (two confirmed `select-step-kind` sites outside its 13, and its
   "met all thirteen" boast is false) — that remains 1b's, since 1b mints a kind.
3. **Ordinals are the collision-free axis.** §3.6 rule 5 concatenates keyless
   components in written order, so [Q_U38](#q-u38)'s refusal structurally never
   fires on an ordinal layer and `vv:{0 1}*` → `⟨1 2 3 4⟩` needs no special case.

**THE LAST SEMANTIC QUESTION IS CLOSED — [Q_U42](#q-u42): same-key VECTOR values
CONCATENATE.** So the star's join is one recursive rule at every depth — Maps
recurse · vectors concat · keyless concat · leaves error — and nothing about the
semantics is now inherited by elimination. Two corrections landed with it, both
found by the owner's questions rather than by a gate: [Q_U40](#q-u40)'s law needed
the **no-intervening-ω qualifier** (branch stars delete into the per-element block
level; a trailing star deletes the container layer the ω step contributed — one
level apart, so `m:{a* b*}` ≢ `m:{a b}*`), and [Q_U41](#q-u41)'s third supporting
argument is **struck**.

**THE SLICING PLAN (proposed, mirroring this track's own ω precedent — P4c-3
landed the KIND with a guided not-yet, P4c-4c landed the semantics):**

| slice | content | test delta |
|---|---|---|
| **1b-i** ✅ `226844f1` | recipe corrected + battery parked. **Measured: 59 live dispatch sites · 35 in the 13 named functions · 2 deliberately-outside-and-undocumented (`select-step-name`/`select-step-cont`, the vocabulary's only SILENT trapdoors) · 8 genuinely OMITTED** — and FOUR of the eight are ω functions `(@bcast step)` itself introduced, so the "met all thirteen" boast is struck: an enumeration cannot be validated by the member it was written for. ⚠ My first attribution pass over-counted ~3× (41 vs 8) by matching only column-0 `define`; six recipe entries are themselves nested | +0 live (deliberate) · battery 476 → 476 |
| **1b-ii** ✅ `dbb9ec77` | `(@star cont)` joins the closed union; the two trapdoors DECIDED (`select-step-name` → #f explicitly, `select-step-cont` → #f deliberately — the star's cont is not a CARET cont); [Q_U43](#q-u43)'s pre-check. ⭐ **The failing test caught my Q_U43 arm in the wrong place** — it went in the head `case`, which dispatches on `(car b)` while a star is almost always LAST, so the branch reported `'(database)`: a key the star had DELETED. Moved to an `ormap` pre-check. ⚠ typing/reduction NOT armed — a refusing arm would be replaced by iii/iv's real one (ban-dual-paths) | +5 live · 476 → **481** |
| **1b-iii** ⛔ attempts 1 AND 2 BUILT · VERIFIED · **REVERTED** | **VECTOR semantics**, typing + reduction ATOMICALLY (spec v1's `ω·ω→ω`). Collisions structurally impossible — concat is total. **Audit finding + the algorithm: [§5.P4e-1b-iii](#p4e-1b-iii)** | the vector battery |
| **1b-iv** | **NOMINAL semantics** + [Q_U38](#q-u38)'s typing-seated collision refusal + `*_`, together per [Q_U24](#q-u24) | nominal battery · collision refusals · `*_` |

The iii/iv split is **the spec's own migration path** (§3.5 "v1: vector layers
only" → §8 Q4's extension): monotone, each half independently gateable, and it
keeps the riskiest work — a collision check at a NEW seat in typing — out of the
slice that first makes the star mean anything.

⚠ **A test must pin the NON-equivalence under broadcast**, not only the law
without one. ⚠ The refusal channels are `bcast-carrier` (typing-errors.rkt) and
`(return (expr-panic …))` through reduction's single `let/ec` — a raw `error`
here is a WHOLE-FILE ABORT, which is why P4c-4c retired its predecessor rather
than leaving it in the tree.

<a id="p4e-1b-iii"></a>

##### §5.P4e-1b-iii — the VECTOR semantics  (mini-audit 2026-08-11 · ⬜ not implemented)

**⭐⭐ THE FINDING: THE STAR IS A BRANCH-LEVEL TRANSFORM, NOT A STEP ARM — and
that is now the THIRD walk with the same requirement.** `branch-entries`
(reduction.rkt) opens with branch-level pre-classifications — `col` (collapse),
then `select-branch-keyless?` — and only then dispatches on the head step. The
star belongs with the first group, for the same reason that moved the
[Q_U43](#q-u43) arm at 1b-ii: **the star removes the label the preceding step
would have contributed.** `cfg{database}*` must not yield `{:database …}` — the
`:database` key IS the layer being deleted — but that label is decided in the
`key`/`caret`/`sub` arm at the branch HEAD, long before a trailing star is
looked at. A `case` arm for `'star` fires too late to unmake it. Same for the
typing twin `select-branch-entries` (typing-core.rkt), which has the identical
cond shape and returns `(values components failure)`.

**THE ALGORITHM, one rule, checked against four cases.** *Take the deleted
layer's CONTENTS — a Map's VALUES or a vector's ELEMENTS — and JOIN them; the
join's sort follows the contents.* With `prefix` = the branch's steps before the
star, the layer is `(below-value v prefix seen)` — or `v` itself when the star is
branch-initial. ⚠ `below-value` RE-NESTS (`cfg{database}` → `{:database …}`),
which is exactly right here: that re-nested value IS the layer being deleted.

| spelling | layer | contents | join |
|---|---|---|---|
| `cfg{database}*` | `{:database {…}}` | one Map | `{:url …, :pool-size …}` ≡ `cfg.database` |
| `cfg{database*}` | `{:database {…}}` | one Map | splices at the BLOCK level |
| `m2{a b}*` | `{:a {:x 1} :b {:y 2}}` | two Maps | `{:x 1, :y 2}` |
| `rowsv:tags*` | `@[@[1 2] @[3]]` | two vectors | `@[1 2 3]` — spec's `ω·ω→ω` |
| `vv:{0 1}*` | `@[⟨1 2⟩ ⟨3 4⟩]` | two tuples | `⟨1 2 3 4⟩` — the ravel |

**1b-iii implements ONLY the all-contents-are-vectors rows** (concat, total, no
collision possible). Map contents are 1b-iv.
⚠ **The condition is on the CONTENTS, not the layer** — a Map layer whose values
are vectors joins by CONCAT and is therefore 1b-iii, not 1b-iv. "The sort follows
the CONTENTS" is Q_U40's wording and it decides this.

**SEAT MIGRATION, owner-assented 2026-08-11.** The parser cannot know the sort —
that is the whole basis of Q_U38/Q_U43 — so `segment-select-items` must MINT the
step unconditionally and the nominal refusal moves DOWNSTREAM to typing, keeping
its *"(flatten) is not implemented yet"* text (nominal genuinely lands at 1b-iv).
Consequence: several P4e-1a pins move seat and must be migrated **with the
reasoning recorded, not silently** — including `[c{a}]*`, whose predecessor
analysis is parser-side and needs re-checking rather than re-pointing.

**Reduction's non-vector arm is an INVARIANT guard, not a user error** — typing
runs first and carries the user-facing refusal, so a non-vector reaching the
value layer is a compiler-invariant violation. That is the established split at
this seat (the `bcast` arm's own comment states it).

**Scoped OUT of 1b-iii, to be refused loudly**: a MID-branch star
(`cfg{database*.x}`). Q_U40 defines the star against the preceding layer; a step
AFTER it descends into the joined result, which is meaningful but unruled. 1b-iii
handles a TRAILING star only.

**Sites**: `segment-select-items` ×4 bands (the `$postfix-star` item + the three
fused-identifier bands via `split-star-lexeme`) · `branch-entries` +
`below-value` (reduction) · `select-branch-entries` + `select-below-field`
(typing) · the vector parked tests · the migrated 1a pins.
**Value accessors, verified**: `expr-champ-racket-champ` + `champ-entries` ·
`expr-rrb-racket-rrb` + `rrb-size`/`rrb-get` · assembly via `entries->value`,
whose keyed/keyless fork reads the FIRST component's key.

**⛔ ATTEMPT 1 (2026-08-11) — BUILT, VERIFIED, REVERTED.** Patch parked at the
session scratchpad (`slice-1b-iii-attempt1.patch`, 393 lines), same disposition
as 1a-iii attempt 1. The build was CLOSE — the headline cases were right
(`rowsv:tags*` → `@[1 2 3] : [PVec Int]`, `vv{0 1}*` → `@[1 2 3 4]`, nominal
refusing, battery 482 green, neighbourhood 325 green) — and it was **wrong in
the one place the whole slice turns on**. Adversarial verify `wf_ba4a51b3-2f8`;
all three re-measured on the main thread before the revert.

**⭐⭐ THE ROOT CAUSE IS ONE THING, AND I HAD WRITTEN IT DOWN MYSELF.**
`select-branch-top-keys` returns `'()` for a star-bearing branch — [Q_U43](#q-u43)'s
recorded *absence* of a check — and the comment I wrote at that arm in **1b-ii**
says, verbatim: *"safe ONLY because the star cannot reach this walk at 1b-ii (the
parser refuses first). THE CARVE-OUT AT THE TWO GATES IS 1b-iv WORK."* **The
seat migration IS what makes the star reach a block.** I invalidated my own
stated precondition one slice later and did not re-read the warning I had left
at the exact site. The carve-out is not 1b-iv work; **it is the price of the seat
migration and must land WITH it.**

**THE THREE VERIFIED DEFECTS:**
1. **WHOLE-FILE ABORT — a `^` after a star.** `cfg{database*.host^}` → empty
   output, not even the `data` decl. A **TWIN ORDER DIVERGENCE**: reduction
   checks the star FIRST (before `col`/`keyless?`), typing checks it LAST — so a
   caret leaf routes into `walk-to-leaf`, which has no `star` arm →
   `select-step-kind-unhandled` → raise. ⚠ **The typing arm's own comment
   asserted the parity that does not exist** (*"BRANCH-LEVEL, before the head
   dispatch, for the same reason as the reduction twin"*). `^_` does NOT abort
   (neither collapse nor dissolve), which is why the shape hides.
2. **WHOLE-FILE ABORT — a star beside a keyed sibling.** `m{name tags*}` →
   `symbol<?: contract violation … given: #f`, empty output. The star's keyless
   component reaches `make-record 'keyword` with a `#f` label, because L4
   (`mixed-sorts?`) cannot see it — Q_U43's `'()` again.
3. **SILENT WRONG ANSWER — the same block, branches reordered.** `m{tags* name}`
   → `@[@[@[1 2] @[3]] "x"] : ⟨[PVec [PVec Int]] String⟩` at **ZERO errors**;
   `:name` is silently discarded, because `entries->value` reads only the FIRST
   entry's key to choose keyed-vs-keyless. **So one illegal block either takes
   the file down or silently loses data purely by the order the user wrote the
   branches in.**

**TWO FURTHER FINDINGS, both real, neither blocking:**
- **Champ order.** A Map layer whose values are vectors concatenates in CHAMP
  HASH order: `mm{zz aa mm}*` and `mm{mm aa zz}*` are **byte-identical** and
  neither is written order. That path is deliberately in 1b-iii's scope ("the
  sort follows the CONTENTS"), and its own comment cites §3.6 rule 5's *written
  order* — which a champ cannot honour. Needs a ruling or a scope cut.
- **Diagnostic degradation.** The refusal stopped naming the user's spelling:
  six structurally different spellings all render the byte-identical message with
  a bare `*`. HEAD interpolated `database*` / `:tags*` / `.name*`. The
  typing-errors comment claims the wording is preserved — the wording is, the
  **interpolated argument** is not, and that was the guided part. Corollary:
  `star-not-yet-message` (parser.rkt) reaches **zero callers**.

**⛔ ATTEMPT 2 (2026-08-11) — BUILT, VERIFIED, REVERTED. Round 2 found defects
IN THE FIXES, which is this track's single most reliable pattern.** Patch parked
(`slice-1b-iii-attempt2.patch`, 603 lines). Verify `wf_096fc42a-87d`; both
blocking defects re-measured on the main thread before the revert.
All four round-1 fixes DID hold — `cfg{database*.host^}` became a per-command
error, both branch orders of `m{name tags*}` gave the guided L4 error, Q_U44's
canonical order and the owner's `mm{zz* aa* mm*}*` recovery spelling both worked,
battery 486 / 0 / 0, neighbourhood 382. **Two NEW defects, both introduced by the
fixes themselves:**
1. **⭐⭐ BLOCKING — SILENT WRONG ANSWER, and a REGRESSION the seat migration
   introduced.** The `$postfix-star` arm ignores `cur` and unconditionally calls
   `(closed-acc)`, so a postfix `*` arriving INSIDE a block is silently re-based
   onto the SUBJECT as its own extra branch. Measured with
   `vh := @[@[@[1 2]] @[@[3]]]`: `vh{0.{0}*}` → `@[@[@[1 2]] @[@[1 2] @[3]]]` at
   **ZERO errors** — the second component is `concat(vh)`, the flatten of the
   WHOLE SUBJECT rather than of the sub-block the star was written on. At HEAD
   this arm was a guided per-command error. Its own comment justifies ignoring
   `cur` with "the star arrives alone" — true only for the OUTER `$select-path`
   carrier, not for an in-block arrival. Same class as round 1's
   `m{tags* name}`, one layer in.
   ⚠⚠ **FRAMING CORRECTED 2026-08-12, by reading the parked patch rather than
   inheriting this record — and the correction changes the FIX.** This entry
   first read *"all three sibling star arms respect `cur`; this one alone does
   not"*. **TWO do**: the ω arm and the `$dot-access` arm, both genuine
   CONTINUATION arms. The third — `star-sym?`, the fused `database*` band —
   **also calls `(closed-acc)` unconditionally, and is CORRECT to**, because a
   bare name always starts a branch (it sits beside `plain-key?`, which does the
   same). `closed-acc` is `(if cur (cons (reverse cur) acc) acc)`, so calling it
   closes the branch in progress and opens a new one holding only the star —
   which IS the branch-initial reading, i.e. operate on the subject.
   **The real defect**: the bare `$postfix-star` sentinel is the one arm
   reachable in **BOTH** positions — branch-initial as the outer `$select-path`
   carrier, continuation when written in-block — and it assumes only the first.
   So the fix is a **position decision, not a transplant from a sibling**, and
   the missing pin must spell a postfix star **AFTER A SUB-BLOCK**, where `cur`
   is non-empty (`vh{0.{0}*}` is that shape).
   ⚠⚠ **THE PARENTHETICAL THIS CORRECTION ORIGINALLY CARRIED IS ITSELF FALSIFIED
   — see [the attempt-3 audit](#p4e-1b-iii-audit3) finding A5.** It read *"`vh{0*}`
   is not — there the star fuses into the lexeme and takes the `star-sym?` arm"*.
   MEASURED at HEAD: nothing fuses (the mint needs a preceding CLOSER and `0` is a
   number token), so `0` and `*` are separate items and the message is
   `split-star-lexeme`'s first-star-at-zero. It reaches `star-sym?` only on the
   `[(not name) (fail cont)]` leg. **The correction was right about the defect and
   wrong about the neighbouring band, by inheriting a reading instead of measuring
   it — the same failure it was written to fix.** A1's position rule (derived from
   the mint) is the durable statement; this cell is kept as written rather than
   silently repaired, because the pattern is the finding.
2. **⭐ BLOCKING — Q_U44's fix does not implement the order it claims.**
   `champ-values/canonical` sorts by `(format "~a" key)`, which for a keyword key
   renders the TRANSPARENT STRUCT `#(struct:expr-keyword NAME)`. The trailing `)`
   (ASCII 41) makes the order diverge from `symbol<?` whenever one key is a
   strict prefix of a sibling whose next char is below `)` — `!`, `$`, `%`, `&`,
   `'`, all legal in Prologos identifiers. Measured: `bang := {:a @[1] :a! @[2]}`
   types as `{:a … :a! …}` (symbol<? order) but `bang{a a!}*` → `@[2 1]`, `:a!`'s
   value FIRST. **The code comment AND the new battery pin both assert
   "canonical = `symbol<?` over the keys" — a claim the implementation does not
   keep**, and no test key set separates them. Two further consequences of
   sorting a struct's DISPLAY form: mixed key kinds order by struct NAME, and
   renaming `expr-keyword` would silently reorder every flatten in the language.
   Fix is to sort on the keyword's NAME with `symbol<?`, matching `make-record`.
**Three MAJOR non-blocking findings, all diagnostic quality:**
· the MID-BRANCH star's message is a LYING DIAGNOSTIC — label degrades to a bare
  `*` (because `select-step-name` of a star is `#f`) and the text claims the
  shape "needs the nominal (Map-valued) case" even when the contents are ALL
  VECTORS. The accurate sentence already exists in reduction.rkt and is
  unreachable by design. `*_` mid-branch is worse: it renders bare `*` too,
  because the suffix is read off `(car (reverse b))`, which is not the star.
· a LEAF-contents refusal says "not implemented yet" for what Q_U40 rules a
  PERMANENT error — there is no future case that will make a String leaf join.
· `(list #f)` is honest for what 1b-iii ACCEPTS but is also applied to shapes it
  REFUSES, where it PRE-EMPTS the star's own message with an L4 sort error.

<a id="p4e-1b-iii-a"></a>

##### §5.P4e-1b-iii-A — make the observations trustworthy  (✅ 2026-08-12)

The audit's findings do not fit one atomic slice, and B below is irreducible (the
seat migration forces the twins' arms; an arm that refuses in one slice and joins
in the next is the dual-path scaffolding 1b-ii refused to build; and the join
forces the classification, or `mm{zz* aa}` reaches `make-record` with a `#f` label
and raises). So A absorbs everything star-free, and B is pre-pinned instead of
made smaller. **Thesis: you cannot verify semantics with a broken instrument and a
lying echo.** Battery 481 → **484**; every item landed INERT for star behaviour.

| # | landed | finding |
|---|---|---|
| 1 | `f0d91853` | **The battery's own instrument was vacuous.** `p4e1-has?` ormapped EVERY output including setup `def` lines, so an expectation that is a substring of a subject's printed type could never fail — measured on the attempt-2 patch's headline pin against the STARLESS control. Fixed LOUDLY (restrict to the final command's output) so vacuous pins redden rather than needing to be guessed at; `p4e1-any-has?` is the visible opt-out, `p4e1-type=?` compares types exactly. ⚠ **My first pin for it OVER-CLAIMED** — it asserted the restriction kills the `[PVec Int]` regex, which it cannot, because the WRONG answer contains that substring too. The two defects are independent; the pin now separates them and pins the containment half as STILL LIVE. ⚠ Exactly ONE pin reddened across 35 call sites, and it was mine — which does NOT vindicate the other 34: the loud fix only catches a pin depending EXCLUSIVELY on setup output. |
| 4 | `43c91859` | **The two rotted PRECONDITIONS replaced with a checkable invariant** — the structural point of the slice. `select-branch-keyless?`'s *"the parser refuses the star before any branch walk runs"* becomes *"every production consumer pre-checks for a star before consulting this"*, with all three named and the grep that audits them. `select-branch-top-keys`' *"safe only while the star cannot reach a block; THE CARVE-OUT IS 1b-iv WORK"* becomes what must actually be checked, and now **forbids the parked patch's `(list #f)`** in writing. A third instance of the same comment class was found in the BATTERY and corrected. Q_U45's legality pair parked. |
| 2 | `e38845a9` | **Canonical key order gets ONE definition** — comparator in `syntax.rkt` (the only home upstream of both twins), walker at `reduction.rkt` MODULE level because `select-reduce`'s `sort` parameter shadows Racket's `sort` for ~470 lines. It returns `#f` rather than inventing an order for a key it cannot speak for. ⭐ **The pin's KEY SET is the finding**: `{:a :a!}` separates `symbol<?` from the struct-display order where attempt 2's `aa`/`mm`/`zz` set agreed under both — and the pin carries an explicit MUTATION GUARD asserting they disagree, so it tells us if it ever stops being evidence. **Mutation-tested**: attempt 2's exact ordering turns it red. |
| 3 | `dd5d145c` | **The FAIL-KIND axis was a silent trapdoor.** `format-select-fail`'s `[else #f]` falls through to the generic message, and NESTED it is a contract violation a blanket handler swallows. Measured: all 14 live kinds have arms, so it was UNREACHABLE — a pure trapdoor — and 1b-iii-B adds THREE kinds to this axis. Made total, and it **reports rather than raises**: a raise in the message formatter is a whole-file abort on the `infer` path. |
| 5 | [DEFERRED 113](DEFERRED.md) | **`pp-expr`'s `'path` arm hardcodes `.`** while `pp-select-branch` honours `first?` — the identical bug one arm over was fixed at P4d-0 slice 5 and the sibling never swept. ⚠ **FILED, NOT FIXED, and the reason is a correction to the audit**: its user-visible claim (`c{a}*` echoes as `c{a}.*`) **did not reproduce** — the probe's diagnostics never route through that arm. The CODE SHAPE is verified; the rendering is not. What is owed is a diagnostic that actually reaches it. |

**⚠ B IS NOT IRREDUCIBLE — CORRECTED 2026-08-12, and I had asserted otherwise.**
Setting B up, the split fell out: land BOTH TWINS' REAL ARMS **INERT** first, then
migrate the parser seat. At HEAD the parser still refuses, so no star reaches the
twins and the arms are correct-but-unreachable code — exactly how 1a-ii landed the
Tier-O arms. ⚠ This is NOT the refusing-arm scaffolding 1b-ii rejected: that was a
placeholder a later slice would REPLACE, whereas these are the actual join, merely
not yet live. Twin atomicity is preserved (both in one commit) and the largest
chunk of risk leaves the migration commit.

| slice | content | why it is safe alone |
|---|---|---|
| **1b-iii-B1** ✅ `1c0c5123` | Both twins' star arms at MATCHING positions (FIRST, ahead of `col`/`keyless?`) · the layer walk · vector concat via A's helper + `rrb-concat` · **EIGHT fail kinds** (not three — mid-branch · leaf-PERMANENT · nominal · hetero · ω-tuple · not-yet · open-row · synth-positional · l4-mixed each say the TRUE thing) · typing's L4 check in `select-level-components` (Q_U43's migration; both branch orders guided) · `seen` FORWARDED in both twins · reduction's 4 assembly sites through ONE star-gated `level-entries` guard | ✅ SHIPPED INERT. Battery 484 → **494** failing-test-first (10 pins failing at HEAD for the right reason, then green) · E2E star surface **byte-identical to HEAD** · neighbourhood 416 `[8/8]` · **mutation-tested PER TWIN** — each twin's pins redden exactly their own side. ⚠ The first mutant protocol was broken TWICE: `git checkout` as mutant-restore left a STALE `.zo` (exposed by a typing-only raise signature in mutant B's output) and then DISCARDED the uncommitted implementation itself. **Never git-checkout to undo a mutant over uncommitted work — invert the mutant, force the rebuild.** |
| **1b-iii-B2** | the parser position rule across all four bands · `star-not-yet-message` retired **definition and all** · uncomment the parked pins | one move makes B1 reachable; every behaviour it exposes is already pinned |

⚠ **B1's own traps, from the audit**: the twins DIVERGE on an empty layer
(typing's `(pair? contents)` refuses, reduction's `(andmap … '())` mints `@[]`)
and on `seen` (reduction forwards it, typing resets to `'()`) — decide both
explicitly, they are twin-contract questions nobody has ruled · typing's contents
arm needs the TAIL and PRESENCE guards the tree already ships
(`closed-keyword-row?`, syntax.rkt) or a `'dyn` row silently joins a SUBSET ·
reduction's non-vector arm is an INVARIANT guard reached via
`(return (expr-panic …))`, **never `error`** · and `champ-values/canonical`
returns `#f` for an un-orderable key, which is NOT "empty" — panic on it.

**B's pre-pinned set, still to write**: the six arrival positions · the legality
pair (parked) · the ω non-equivalence (parked, uncomment) · L★'s vector
non-equivalence (parked) · the discriminating key set (landed) · a tripwire
planting a star in a `rest` position at the four `select-step-kind-unhandled`
sites, so C32's unreachability argument stops living in an audit.

⚠ **THE PARKED PATCHES LIVE IN A PRIOR SESSION'S SCRATCHPAD**, not the current
one: `/private/tmp/claude-501/-Users-avanti-dev-projects-prologos/311a1847-2220-4539-bd51-0e2270a3625f/scratchpad/slice-1b-iii-attempt{1,2}.patch`
(attempt 2 = 427 added lines, six files: parser +42/−10 · reduction +105 ·
syntax +21/−1 · typing-core +78 · typing-errors +17 · battery +151/−29; it
`git apply --check`s clean at `7fd25f35`). Every "parked at the session
scratchpad" above means THAT path.

<a id="p4e-1b-iii-audit3"></a>

##### The attempt-3 mini-audit (2026-08-12, `wf_bbf1169e-340`) — the four-item list was NOT the work

6 partitioned read-only facets + the adversarial completeness critic, HEAD-pinned
`7fd25f35`, ~1.55M tokens, **37 critic findings · 17 capture gaps · 16 R-lens
targets**. Every claim below was R-lens-verified on the main thread before being
recorded. **Three of the four recorded items stand; the audit found the list is a
subset, and one of the four rested on a sentence that does not exist.**

**⭐⭐ A1 — THE POSITION RULE IS DERIVABLE, TOTAL, AND NEEDS NO `cur-subbed?`
TEST.** The reader mints `postfix-star` only for a `*` byte-adjacent to a
preceding token in `group-closer-types = '(rbracket rparen rbrace)`
(parse-reader.rkt:2081, :1619) — and a block's own `{` is an **OPENER**. So a bare
`$postfix-star` **can never be the first item of a block or sub-block payload**.
Therefore:
> `cur = #f` ⇔ the outer `$select-path` carrier ⇔ operate on the **SUBJECT**;
> `cur` non-`#f` ⇔ in-block ⇔ **CONS onto the branch**.

Derived from the mint, not transplanted from a sibling arm — which is what the
record's "respect `cur` like its siblings" framing would have produced.

**⭐ A1b — SIX ARRIVAL POSITIONS, MEASURED; THIS DOCUMENT RECORDED ONE.** All six
reach parser.rkt:1447 (probed at HEAD): (A) branch-initial outer carrier `c{a}*`
· (B) after a `.{…}` sub-block `vh{0.{0}*}` (`cur-subbed?`=#t) · **(C) after an
ORDINAL step `cfg{database[0]*}` (`cur-subbed?`=#f — in no record)** · (D) after
an in-block ω `m{k:{a}*}` · (E) after `^`-dissolve + sub `cfg{database^.{host}*}`
· (F) one level down via the recursive call `cfg{database.{host[0]*}}` (`sub?`=#t)
· plus mid-payload with a SIBLING after it, `cfg{database.{host}* name}`. **A fix
keyed on `cur-subbed?` covers one of six**; the `cur` rule covers all.

**⛔ A2 — `(list #f)` REFUSES [Q_U40](#q-u40)'s OWN HEADLINE EXAMPLE.** The patch's
Q_U43 pre-check answers `(list #f)` for every star branch — KEYLESS — and leaves
both parser gates live. Trace `m2{a* b}`: branch 1 → `(#f)`, branch 2 → `(b)`, so
`mixed-sorts?` (parser.rkt:1335) is `(and #t #t)` → **L4 error at the parser**,
against a spelling Q_U40 rules legal and calls the reason the branch form is
*strictly more expressive*. `(list #f)` is right for VECTOR contents and wrong for
MAP contents and **the parser cannot tell which** — the whole reason Q_U43 moved
the check to typing. See [Q_U45](#q-u45); found by the owner's uniformity
observation, not by a facet. *(Derived from the patch against the live gate; the
patch is not applied, so this is a failing-test-first pin, not a measurement.)*

**⛔ A3 — THE THIRD INSTANCE OF THE REVERT SHAPE IS SITTING UNTOUCHED.** Two
comments in `syntax.rkt` carry the SAME precondition the seat migration deletes,
and the patch addresses one:
· `select-branch-top-keys`' pre-check — *"Safe only while the star cannot reach a
  block; THE CARVE-OUT AT THE GATES IS 1b-iv WORK"* (syntax.rkt:1333-1337);
· `select-branch-keyless?` — *"the #f here is INERT (the parser refuses the star
  before any branch walk runs) and must not be read as a classification"*
  (syntax.rkt:1294-1301), **untouched by the patch, and its `(check-false …)` pin
  untouched too**.
After the patch, two classifiers in one file give **opposite** sort answers for
the same star branch (keyless vs keyed), both pinned. ⚠ And the pre-check's own
comment says `'()` *"moves both gates to typing"* — the patch's typing hunks
contain **no collision check and no sort check at all**, so a comment asserts as
done a migration that exists in no tree.

**⛔ A4 — THE MID-BRANCH SENTENCE DOES NOT EXIST.** This document said *"the
accurate mid-branch wording already exists in reduction.rkt and is unreachable"*.
**MEASURED: `grep flatten reduction.rkt` → 5 hits, all `flatten-union` /
`flatten-app`.** The sentence exists only inside the parked patch. The claim was
written from the patch's perspective as if applied — and attempt 3 starts from
HEAD, so it would have searched for it and found nothing.

**⛔ A5 — MY OWN 2026-08-12 PARENTHETICAL IS FALSIFIED, and it made an
unimplemented band look implemented.** I wrote that `vh{0*}` "is not that shape —
there the star fuses into the lexeme and takes the `star-sym?` arm". **MEASURED at
HEAD: `vh{0*}` → `` `*` — `*` is postfix; it attaches to the END of a segment ``**
— `split-star-lexeme`'s first-star-at-zero message, which can only arise if the
lexeme IS `*`, i.e. `0` and `*` are SEPARATE items and **nothing fuses** (the mint
needs a preceding CLOSER; `0` is a number token). It does take `star-sym?`, but on
the `[(not name) (fail cont)]` leg. **The in-block ordinal band `m{0*}` is
unimplemented and its message tells the user to do what they already did** — the
DEFERRED 101 "unspellable ordinal splat", still live. Same failure class as the
one that correction was fixing: I inherited a reading instead of measuring.

**⛔ A6 — Q_U44 NAMES HALF OF `make-record`.** syntax.rkt:1406-1413 DEDUPS
last-write-wins via `make-hash` and THEN forks on key-domain — `symbol<?` for
`'keyword`, `<` for `'nat`. A helper written to the ruling as stated cannot serve
a nat-domain layer, and non-keyword champ keys are reachable at runtime.

**⛔ A7 — THE HEADLINE NEW INSTRUMENT IS VACUOUS AND ITS COMMENT CLAIMS THE
OPPOSITE.** `p4e1-has?` (tests:6314) `ormap`s over **all** per-command output
**including the setup `def` lines**, and `def rowsv` itself renders
`rowsv : [PVec {:tags [PVec Int]}]` — which contains `[PVec Int]`, as does the
WRONG answer `[PVec [PVec Int]]`. The patch's type-collapse check therefore cannot
fail, while its comment calls it *"the assertion that caught the implementation's
one real defect"*. **Systemic**: any expectation whose regex is a substring of a
subject's printed value or type is silently vacuous.

**FURTHER VERIFIED FINDINGS, each a slice obligation** — `star-not-yet-message`
has FOUR callers (not the census's 5); the patch removes all four but not the
DEFINITION, leaving dead code carrying a live-contract comment (parser.rkt:1254) ·
`format-select-fail` ends in `[else #f]` (typing-errors.rkt:600), so splitting the
fail kind into three walks into a SILENT catch-all — and three nesting sites
`string-append` the recursive result, so a `#f` there is a contract violation that
`select-block-hint`'s blanket handler (:603, one of FOUR in that file) swallows ·
the same star raise is a WHOLE-FILE ABORT on the primary `infer` path and a
silently-swallowed `#f` on the hint path · the typing arm lacks a TAIL guard (a
`'dyn` row exposes only KNOWN fields ⇒ silent SUBSET join) and a PRESENCE guard,
both of which the tree already ships (`closed-keyword-row?`, syntax.rkt:1435) ·
the twins DIVERGE on an empty layer (typing's `(pair? contents)` refuses;
reduction's `(andmap … '())` mints `@[]`) and on `seen` (reduction forwards,
typing resets to `'()`) · `rrb-concat` already exists and the patch open-codes the
join · the parser's gate-safety comment (parser.rkt:1323) claims
`select-branch-top-keys` is "the SHARED walk … typing + reduction use" — **it has
ZERO references in either file** · `pp-expr`'s `'path` arm hardcodes a `.`
(pretty-print.rkt:592), so `c{a}*` will echo as the nonexistent `c{a}.*` — the
identical bug one arm over was fixed at P4d-0 slice 5 and the sibling not swept ·
the ω non-equivalence pin is fully COMMENTED at tests:6975-6998 and the patch does
not uncomment it · `*_` has **no postfix carrier at all** (`c{a}*_` → bare
`Unbound variable`; the mint is `(string=? lexeme "*")`), so the arm's hardcoded
`'flatten` is right by accident and `*_` is classified KEYED, not keyless — the
patch pins the wrong answer.
**Confirmed as recorded**: the `sort` shadow (reduction.rkt:1643→:2111, and the
two live `(sort ` calls both sit OUTSIDE it, so 1b-iii's helper is the first thing
that would trip it) · `entries->value`'s first-component fork, whose twin
`select-assemble-row` RE-INDEXES, so `m{tags* name}` silently re-indexes while
`m{name tags*}` RAISES — same block, reordered · attempt 2 did fix the twin ORDER
divergence.

**WHERE A CANONICAL-ORDER HELPER BELONGS** (none exists — the tree's three champ
sorts are all `(format "~a" key)` or diagnostic-only): the COMPARATOR in
`syntax.rkt`, which already owns `expr-keyword`, `make-record` and `record-field`
and requires neither champ nor rrb; the champ WALKER at `reduction.rkt` MODULE
level, outside the `sort` shadow. `typing-core` requires `reduction`, one-way, so
reduction cannot import from typing.

**⚠ ONE AUDIT CLAIM DOWNGRADED**: a facet traced `c{a}*.host*` to a whole-file
abort; the critic showed the nearest reachable shape refuses cleanly and that
reaching the raise needs a branch that both STARTS with a star and CONTINUES —
which A1's position rule proves impossible. **That is an argued-unreachable
precondition living in an audit, which is precisely the artifact class that caused
both reverts.** It owes a comment at the four `select-step-kind-unhandled` sites
plus a tripwire planting a star in a `rest` position — not a note in a document.

**WHAT ATTEMPT 2 MUST DO DIFFERENTLY**: land the parser gates' star carve-out
**with** the seat migration, not after it; place the typing star check ahead of
`col`/`keyless?` so the twins genuinely match (and pin the caret-after-star case,
which nothing covered); decide the champ-order question; restore per-spelling
interpolation in the message. ⚠ The battery was GREEN over all three defects —
482 cases, plus a 325-test neighbourhood. **No spelling in the battery mixed a
star with a keyed sibling, and none put a caret after a star.**

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


<a id="p4d-s7"></a>

### §5.P4d-s7 — A PAREN GOAL AS THE SUBJECT OF A POSTFIX ACCESS  ✅ 2026-08-08 (`f54dfc6c`)

Owner-requested. `(fruit-color "apple" c)` carried its implicit solve;
`(fruit-color "apple" c):c` did not, answering *"fc is a relation, not a
function"*. By referential transparency it must — the same value, the same
selection.

**Root cause.** The reader mints a postfix access as a **sibling** of its
subject: `(G):c` reads as `((G) ($bcast-step :c))`. So `parse-command-datum`
applied its goal test to the OUTER list and the goal was demoted from "the whole
command datum" to "element 0 of it".

**⭐ WHY THE FIX IS IN THE READER — the measurement that decides it.** The
tempting repair is to descend to the subject downstream and re-test
`prologos-paren-origin` there. Measured at `b6f773a8`, that is **unsound**:

| source | post-preparse datum | top `paren-origin` | subject `paren-origin` |
|---|---|---|---|
| `(G).0` | `(get (G) 0)` | `#f` | `#t` |
| `[get (G) 0]` | `(get (G) 0)` | `#f` | `#t` |

Byte-identical on both axes. `[get (G) 0]` is an application in ARGUMENT
position that must keep refusing (pinned at `test-solve-carrier.rkt`
"SCOPE BOUND"). Downstream there is nothing left to tell them apart — the
paren/bracket distinction exists ONLY in the reader.

The property is also **anti-correlated with the answer**: it SURVIVES in two
positions that must refuse (a `defn` body; a nested bracket `[[(G):c]]`) and is
STRIPPED in three that must solve (def RHS, aligned let RHS, every chain —
`syntax-locs-only` drops properties from moved nodes, and for chains the mark
migrates onto the bare `$select-path` head atom). So the carrier is the DATUM
sentinel `$goal-rhs`, on the argument `parse-reader.rkt` already records for the
`let` leg one level in: *preserve that bit in the DATUM, where stripping cannot
reach it.*

**⭐ THE MECHANISM ALREADY EXISTED.** `let [zb := (G):c] zb` WORKED at HEAD — the
bracket-`let` arm of `mark-binding-values` is the one arm with no element-count
gate, so it minted `$goal-rhs`, which landed in SUBJECT position and was consumed
there by `parse-datum`'s existing sentinel arm. This slice REACHES that
mechanism from the other command positions; it invents none. It is also why
CHAINS came free: the mint precedes the fold, which nests one carrier per level
with the subject always at index 1.

**The enumeration under-counted by three.** Beyond the reported `:c` `.0` `{c}`
`:{c}`: the PLAIN DOT `.name` (the commonest selection surface), `[0]`
(byte-identical to `.0`), and every CHAIN. `.{…}` and `.:name` are NOT members —
their fold arms DESTROY the base (`($retired-selection …)`), so there is no
subject to carry a goal; `subject-preserving-access-heads` excludes them by name.

**Owner rulings (2026-08-08), all landed.**
1. *"The `let`s shouldn't disagree whether they use a `:=` or not."* — the
   aligned/bare arm mints too. The other two spellings refuse an access on ANY
   value (DEFERRED 97), so they are out of reach from here.
2. *"The multi-line `def` shouldn't lose it's solve."* — a continuation-line
   value nests one level deeper, inside a LAYOUT group.
3. *"Wrapping other values in [parens] does seem like it should be a
   properly-guided error."* — the widening is INTENDED; base was the
   inconsistent side (bare `(mm)` already refused while `(mm).a` silently treated
   parens as grouping). The guided diagnostic moved to ELABORATION
   (`non-relation-goal-head-error`), where it survives the selection seat and
   gains a real srcloc — previously `<unknown>`.

**⚠ BRACKET GROUPS NOW CARRY A MIRROR MARK, and it is load-bearing.** A
multi-line value's layout group is byte-identical to a user bracket — same datum,
same span, no properties (measured) — so descending one level to reach the
multi-line value would ALSO descend into `def B := [(G):c]` and mint a goal in
argument position. `prologos-bracket-origin` makes *"unmarked ⇒ layout"*
structural. The descent is exactly one level.

**⚠ THE VERIFY FOUND THREE DEFECTS OF MINE — five slices running.** Sharpest: the
reader predicate tested only the sentinel HEAD while the preparse fold tests head
AND arity, so `($dot-access a b c)` was marked and never folded, leaking as
`Unbound variable $dot-access` where HEAD gave the relation diagnostic. **That is
the exact drift the head-set re-homing claimed to prevent, committed in the same
change** — sharing a list does not make two predicates agree; matching the arity
discipline does. Also: the `let` divergence and the multi-line `def` gap.
Separately, one of my own pins PASSED AT RED for the wrong reason (the oracle
compared a trailing `def after := 42` on both sides); rewritten to compare
against the explicit `[solve (G)]…` spelling.

**Evidence.** Suite **10087 / 488 / 0** (`[488/488]` verified). Battery 432, green.
A reader-level oracle over all 164 `.prologos` files: the mint fires in exactly
three places, all inside Q_C. Verified byte-identical to base: `defn`/`fn`
bodies, match arms, nested brackets, `[get (G) 0]`, sexp mode. No double solve,
no new whole-file abort, and **no silent wrong answer** — every affected case is
working-value → error, never a different value.

**⚠ THE CLOSE-OUT, and why it was needed.** The first landing met the acceptance
criteria but MISSED THE CHIP'S OWN GATE — *"adversarially verify before the
behavioural commit, and AGAIN if the change widens"*. It widened: the bracket
mark, the one-level descent, and the elaboration-time refusal were all added
AFTER the verify ran. The omission cost immediately —

- **The solve family had split in two.** The diagnostic was hoisted for
  `surf-solve` only, leaving `solve-one` / `explain` / the two `-with` arms
  refusing at RUNTIME with an `<unknown>` srcloc while `solve` refused at
  elaboration with a real one. Same message, two production sites: the drift
  class, self-inflicted, in the change whose commit message complains about
  drift. All five arms now share `non-relation-goal-head-error`, which takes a
  `who` so the text stays byte-identical to the runtime site's.

- **Acceptance §K added** (markers 83–89, appended after §J so nothing
  renumbers). It shows the working surface only — gate 1 requires ZERO errors,
  so the scope-guard refusals stay in `test-solve-carrier.rkt`.

- **The reader delta was benchmarked**, having been shipped unmeasured. Reader
  only, same corpus in both legs (main's `lib/examples` carries owner WIP, so
  each tree's own copy would vary the INPUT too), 6 interleaved rounds:
  base **4246.9 ms** mean vs changed **4284.3 ms** — **+0.88%**, against a
  within-leg spread of **3.35%**, with the first changed round FASTER than base.
  Below this setup's measurement floor. Deterministic size of the added work:
  **5160** bracket groups in the corpus ⇒ 5160 property writes per full read.

**Second verify verdict: SHIP** (`wf_6d3e6d28-359`). It judged the POST-fix state
(it noticed the tree had moved under its own lenses and pinned the files by
sha256 before trusting anything), re-ran the full suite `[488/488]` 10099, the
acceptance file (90 results, 0 errors), and confirmed the D1/D2 safety argument
EMPIRICALLY: `def m :=` ⏎ `(fc …):c` solves while `def m :=` ⏎ `[(fc …):c]`
refuses — the descent sees through a layout group but not through a user
bracket.

⚠ **It also corrected MY verify setup.** All three lenses were told to A/B
against the main checkout, on the strength of the four slice-7 files matching
`b6f773a8` — but main carries extra `reduction.rkt` (+41) and `typing-core.rkt`
(+40) commits, so it is NOT a pristine base for a comparison of TYPE ERRORS and
SRCLOCS, which is exactly what the lenses were comparing. The judge discarded it
and built a `git archive b6f773a8` export instead. No verdict changed here, but
it is the stale-base class `workflow.md` already warns about, arriving through
the instruction rather than through the agents.

**Deferred.** 84 (three `let` spellings + `def-` refuse an access on any value) ·
87 (a goal KEYWORD under an access gets the broadcast-carrier message) · 85 (an
empty group at command position aborts the file — pre-existing) · 86 (`'(…)` the
QUOTED GOAL, the owner's fourth request — a language feature needing a
first-class `Goal` type, which does not exist in the tree).


- **The spec** (normative surface): `docs/research/2026-07-28_path-selection-spec.md`
- Predecessor design (record of rounds 1–8b): `2026-07-26_CIU_T6_PATH_SELECTION_DESIGN.md`
- Landed substrate: P2 commits `ad75e57a` · `88d1f746` · `b8f7cc27` · `d4f4b80f` · `ac89341f`
- P3 mini-audit: `wf_2830f0aa-9a4` (token registry, censuses, seats) — findings recorded in the predecessor's P3 row
- Records substrate: `2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md` (D1–D29) · F1b PIR · Rel T1 PIR
- Rules: `prologos-syntax.md` § Reader · `pipeline.md` · `workflow.md` · `on-network.md`
