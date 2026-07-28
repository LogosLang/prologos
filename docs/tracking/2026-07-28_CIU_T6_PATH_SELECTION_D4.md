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
| **P0** | **Acceptance corpus** — augment the EXISTING acceptance file with the spec §10 examples + Appendix fixtures; `--check` gated; new forms commented until their phase lands | ⬜ | §5.P0 |
| **P1** | **Lexical seams + the retirement batch** — brace/colon adjacency, keyword-trailing `*`; dot-key + `.*name` + `m[:a]` retirements; `x[]`/`_[sel]`/`.-1` rejections; round-trip pins. Answers spec Q8 | ⬜ | §5.P1 · censuses fresh from `wf_2830f0aa-9a4` |
| **P2** | **Grade-1 core** — `.k`/`.N` access + bare-path extraction, on the landed P2 substrate | ⬜ | §5.P2 · `.N` has an end-to-end head start via `(get expr N)` |
| **P3** | **Blocks** — `x{…}`, projection-by-default, `^` (3 continuations), L4 sort homogeneity, **STRICT merge** (the §3.6 waypoint) | ⬜ | §5.P3 · ⚠ **GATED on spec Q2** (map output-key ordering) |
| **P4** | **Broadcast ω** — `:s` one-step extent, L1 fusion, **map-generic `:`** (Q1 ✅), `*` flatten, `.*` row-splat, the §5.3 meet rule | ⬜ | §5.P4 |
| **P5** | **Ruling B + factoring** — B2 keywise / B3 same-spine merge, L2 normal form, guided errors printing the factored spelling | ⬜ | §5.P5 · L1–L5 law battery |
| **PX** | **Binder-seam substrate** (carried, surface-independent) — the lambda-adoption hole + the standalone-def seam | ⬜ | §5.PX · position flexible |
| **P6** | **Demand semantics** — the §1.3-vs-POL.10 staging decision, then (if in) lazy leaves | ⬜ | §5.P6 · decision due by P3 |
| **X.close** | **MANDATORY** — bench matrix · DEFERRED triage · doc-truth sweep · memory fold · **Stage-5 PIR** | ⬜ | §5.X · the track does not flip ✅ without the PIR |

*Per `workflow.md`: tests are PER-PHASE (each phase's section states its own
test delta); a behavioural phase shipping +0 tests is INCOMPLETE.*

---

## §1 The redesign in one page

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

### §1.3 What landed and stands (nothing unwinds)

- **P0** acceptance file (`examples/2026-07-26-ciu-t6-path-selection.prologos`):
  its 21 WORKING markers pin P1/P2 substrate and stay a regression instrument;
  its commented old-syntax §B/§C targets are superseded (see §5.P0).
- **P1** `.{` retirement: consistent — the new block is brace-WITHOUT-dot.
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

## §2 Grounded code reality (probe-verified 2026-07-28 @ `89bc321c` unless noted)

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

### §2.3 Standing items the spec does not cover

- **sexp mode** (old PS14): postfix adjacency is WS-only; the sexp special form
  is still an implementation deliverable. The 20 brace-select tests
  (`test-path-expressions.rkt`) remain isolated from WS changes (audit-proven)
  and re-point when the sexp form lands.
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

## §3 Rulings ledger

**Adopted [owner, 2026-07-28]:**
- The spec's every **[ADOPTED]** element is normative for v1.
- **Q1 = YES**: map-generic `:` (spec §3.2.3 + §5.4 row-map typing). With it:
  path-position `.*` is subsumed; `.*name`'s migration target is **`:name`**.
- **`v[0]` keeps its current working semantics for now** — the PS2 flip is
  canceled; no census-flip of `v[literal]` sites.

**Open, GATING (spec §8):**
- **Q2 — map output-key ordering** in keyed blocks (source order vs selection
  order): gates §5.P3 (the first phase testing keyed-block result equality).
- Q4 (`*` on Map layers — v1: vector-only), Q5 (`<` disclose in/out),
  Q6 (idempotent self-merge L7), Q7 (spine identity residuals),
  Q8 (the precise lexical grammar — §5.P1's deliverable).
- Keyword-projection disposition (§2.3). Demand-semantics staging (§2.2).

**Carried from the P3 mini-audit [owner, 2026-07-28], still standing:**
- `#:keyword` retires with the `#.:name` twin (`#.name` survives).
- `^` splitting is P4-parser-side via POL.6 `split-fused-symbol` — no second
  splitter.
- `.-1` = classifier-level rejection; negative bracket/`get` payloads = a
  static error at the grouping seat alongside `m[:a]`.
- ~~`.:.`/`.:[` tokens defer to P5~~ — **MOOT**: the new broadcast is bare
  `:s`; no `.:` tokens exist in the surface at all.

---

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
- **Gate**: spec **Q2** (map output-key ordering) blocks P3's result-equality
  tests. It is the only OPEN question on the critical path.

---

## §5 Per-phase sections

### §5.P0 — Acceptance corpus

**Intent [owner, 2026-07-28]: AUGMENT the existing acceptance file** —
`examples/2026-07-26-ciu-t6-path-selection.prologos` — with the spec's §10
examples and Appendix fixtures. One file, not two: it already holds the P0
charter (nested config, PVec-of-records, solve rows, typing pins,
function-typed forms) and its **21 working markers are live P1/P2 substrate
regression**. A second file would split the instrument and duplicate fixtures.

**Work**:
- **Reconcile fixtures**: the file's `app-config` and the spec's Appendix
  `app-config` are the same shape from different drafts — converge on the
  spec's (it is normative and the §10 results are computed against it),
  keeping any extra fields the existing markers depend on. Same for the party
  PVec vs the spec's `users`. Add the fixtures with no counterpart:
  `build`, `regions`, `strings`, `m`, `events`, `tree`.
- **Replace the superseded target block**: the commented §B/§C old-syntax
  targets (bracket-select, `.:.` iteration, `[*]`) are dead surface — delete
  them with a one-line note pointing at this document, and add the §10 corpus
  in their place, commented per phase.
- **Section the corpus by phase** so uncommenting is mechanical: §10.1
  reshaping/splice/provenance (P3) · §10.2 broadcast/fusion/honest nesting
  (P4) · §10.3 Ruling B/factoring/SoA (P5) · §10.4 flatten + the W1 border
  (P4) · §10.5 map-generic (P4, Q1 ✅) · §10.6 transposes (**v2 — stays
  commented permanently**, with the §7.3 pointer) · §10.7 meet rule (P4) ·
  §10.8 W4 (permanently commented, the exit noted).
- **Negatives pin ERROR CLASS, not message text**, until spec Q8 settles
  wording (the established `;;N=>~ ERROR` marker idiom).

**Normativity**: the corpus is executable spec (spec §10: "intended as
executable test vectors"). Any divergence between file and spec is a bug in
one of them — resolved by ruling, never by quietly editing the marker.

**Open here**: the spec fixture's computed leaves (`:date [now]`,
`:url [env …]`) force EAGERLY until §5.P6 — so the §1.3 demand property gets a
marker COMMENT, not an assertion, in v1. The forced values are indicative
(spec §10 preamble), so every other §10 result is unaffected.

**At X.close**: the file promotes to a suite-gated regression test (the
existing charter, unchanged).

**Test delta**: the augmented file + its `--check` gate (currently 21/21;
expect the count to grow only by forms that WORK at P0 — everything else
lands commented). Status: ⬜.

### §5.P1 — The lexical seams + the retirement batch

**Intent**: everything tokenizer/grouping. Two halves:

**(a) The seams** (spec §2.2 / Q8 — the precise grammar is THIS phase's
deliverable):
1. **Brace adjacency**: `x{…}` (no space) = select block vs `{…}` = literal.
   Mechanism: the positional adjacency test (end-pos == start-pos), same as
   postfix-index (parse-reader.rkt:2441-2450). **Census obligation first**:
   every SPACED `f {…}` in the corpus whose meaning must NOT change, and every
   adjacent `x{…}` that currently parses as application-of-literal.
2. **Colon adjacency**: `x:s` broadcast vs `:s` keyword vs `x : T`/`x:Int`
   annotations. Adjacency + a focus-bearing left context selects broadcast.
   **The annotation collision is the sharp edge**: the census must cover every
   fused `ident:Ident` in annotation position (POL.6 territory) before the
   grammar is fixed. `:{` (lone-colon + brace) is the broadcast-block shape —
   detectable at grouping (probe-verified).
3. **Keyword-trailing `*`**: `:diags*` must split into `:diags` + flatten-`*`
   in selector context. (`*` stays in `ident-continue?` generally — the split
   is contextual, not a charset change; the F1b.7g drift rule applies.)
4. `^` is NOT touched here (parser-side split at P3, per the standing ruling).

**(b) The retirement batch** (carried from the old P3 row, all censuses fresh
from the audit): dot-key `.:name` (2 live) + `#.:name`/`#:keyword` twins ·
broadcast `.*name` (4 live; **migration target now `:name`** per Q1; guiding
classifier errors per the tilde-number template — the ONLY all-paths
diagnostic seat; the compat-path rejects are dead code) · `m[:a]` static error
+ hint (grouping seat) · `x[]`/`_[sel]`/`.-1` rejections (`.-1` at the
classifier; negative payloads at the grouping seat) · round-trip printing pins.

**Discipline**: both-modes census per `prologos-syntax.md` § Reader; any new
opener co-updates the THREE layers (frame dispatch + langle skip-set +
group-items — the 31d27c83 lesson); the counting RULE is live-vs-commented.

**Open here**: none blocking once Q8's grammar is drafted — Q8 is answered BY
this phase, reviewed with the owner before landing.

**Test delta**: reader pins in `test-parse-reader.rkt` (RRB-native API — the
audit's three-API finding standardizes here) + retirement/migration tests in
the track file. Status: ⬜.

### §5.P2 — Grade-1 core

**Intent**: `.k`/`.N` access + bare-path extraction — the spec's grade-1
fragment, on the P2 substrate.

**Grounded head start** (audit + probes): `.N` extraction works END-TO-END
today via a `(get expr N)` fold arm — `expr-get` types PVec + tuple(nat-row) +
Map + List subjects; site 7 projects; the two-tier principle makes misses
loud. The fold target is `get`, NOT `map-get` (probe: map-get's infer has no
PVec leg). `.k` nominal access already works (dot-access → map-get fold).

**Work**: the `.N` recognizer (dot-anchored, priority slot inside the audited
band {rest-89 · dot-lparen-87 · dot-access-86}; digit-required so `.-1` never
matches) · the nat-dot fold arm → `(get expr N)` · chain forms
(`admins.0.name`) · extraction typing = the existing arms (no new nodes
expected — flag if that breaks).

**Test delta**: corpus §10 grade-1 lines uncomment; track-file pins for the
chain forms + `v[0]`-coexistence pins (both spellings extract, per the
ruling). Status: ⬜.

### §5.P3 — Blocks

**Intent**: `x{…}` select block · projection-by-default · `^` three
continuations (parser-side split) · L4 sort homogeneity (level-local) ·
**STRICT merge** (the §3.6 monotone waypoint: ALL duplicate output keys
error, remedies named in the message) · result typing: copattern demand
against the coinductive record type; grades 1-only at this phase.

**GATE: spec Q2 (output-key ordering) must be ruled before this phase's
result-equality tests can be written.**

**Design questions to settle in this section before code** (each gets a
mini-audit): the block's parse representation (new surf/expr nodes — full
pipeline.md cost, budgeted honestly this time: constructor sites compile
CLEAN cross-module, discovery is patterns+runtime); where `^` splitting binds
(POL.6 splitter at parse of block branches); L4's error seat; the honest-
nesting 1-tuple display.

**Test delta**: corpus §10.1 uncomsments (minus computed-leaf demand
assertions); L4/collision negative pins. Status: ⬜.

### §5.P4 — Broadcast ω

**Intent**: `:s` one-step extent (§3.2.1) · fusion L1 (consecutive `:` share a
spine — an ELABORATION-level rewrite, so the layer count is structural) ·
**map-generic `:`** (Q1 adopted; §5.4 row-map typing; Specter ALL/MAP-VALS
collapse) · postfix `*` flatten (vector layers only — Q4 open) · `.*`
row-splat (block position; path position subsumed by Q1) · the §5.3 meet rule
for heterogeneous vectors (coinductive: every element offers the observation).

**Grounded**: the meet rule's error case is the *typing* side of the P2 loud
tier — the runtime side already errors loudly. Result-shape computation =
grades as shape functors (spec §5.2); ω layers = unfused broadcasts.

**Network posture**: v1 stays zero-propagators (the old §7 posture carries;
the Network Reality Check applies to every P4/P5 commit). The broadcast
NODE-level upgrade (one broadcast propagator/one fire/one merge) remains the
future NTT-modeled track.

**Test delta**: corpus §10.2/§10.4/§10.5/§10.7 uncomment. Status: ⬜.

### §5.P5 — Ruling B + factoring

**Intent**: upgrade the strict waypoint to Ruling B — B2 keywise node merge ·
B3 same-spine pointwise merge (spine = source-directed steps with
`^`-continuations erased; Q7's residuals settle here) · L2 factoring
(`{p:a p:b} → p:{a b}`) as the normal form, with **error messages printing
the factored spelling** (spec: SHOULD) · L3 assoc/comm on disjoint keys ·
Q6 (idempotent self-merge) ruled here.

**Test delta**: corpus §10.3 uncomments; L1–L5 law tests as a dedicated
battery (the equational theory IS test material). Status: ⬜.

### §5.PX — Binder-seam substrate (carried unchanged)

The D3-S10 concrete-codomain lambda-adoption hole
(`[the [List String] [map [fn [x] x] ints]]` accepts silently) + the
standalone-def seam (`def f := [fn …]` / `def add5 := [int+ 5 _]` fail where
the body determines the types). Surface-independent; the old doc's round-6b
capture stands. Position flexible. Status: ⬜.

### §5.P6 — Demand semantics (staging decision + implementation)

The §2.2 collision, staged honestly: **decision by P3** (blocks make demand
observable), implementation possibly later. Options to design against POL.10:
lazy leaf thunks in the champ (rep change; `.pnet` + effect-gate interaction) ·
a demand mark at elaboration (selection-aware forcing) · defer §1.3 to a
named post-v1 phase with the corpus marker documenting the gap. **No option is
adopted here** — this section exists so the lift is visible and priced before
anything claims v1-complete. Status: ⬜.

### §5.X — X.close

Bench matrix (feature microbench + E2E per testing.md — priced against the P2
baseline) · DEFERRED triage · doc-truth sweep (incl. the old doc's banner, the
map tutorial, `prologos-syntax.md`'s selection section) · memory fold ·
**Stage-5 PIR** (the track does not flip ✅ without it). Status: ⬜.

---

## §6 SRE lattice lens + NTT posture

The old doc's §6 analysis carries where the carrier is unchanged (the result
row IS the same lattice family). New under the spec: the GRADE algebra (1/ω
composition, ω absorbing) is a semiring morphism into result shapes — the
interval refinement (spec §3.1) is explicitly the QTT semiring; when grades
sharpen, the lens re-runs. Ruling B's merge is a partial monoid on keyed
results (L3: assoc/comm on disjoint keys) — the lattice-lens question "what is
the join and where is it partial" IS Ruling B's case analysis. The NTT
obligation stays where it was: mandatory at the future broadcast-propagator
node, not v1.

## §7 References

- **The spec** (normative surface): `docs/research/2026-07-28_path-selection-spec.md`
- Predecessor design (record of rounds 1–8b): `2026-07-26_CIU_T6_PATH_SELECTION_DESIGN.md`
- Landed substrate: P2 commits `ad75e57a` · `88d1f746` · `b8f7cc27` · `d4f4b80f` · `ac89341f`
- P3 mini-audit: `wf_2830f0aa-9a4` (token registry, censuses, seats) — findings recorded in the predecessor's P3 row
- Records substrate: `2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md` (D1–D29) · F1b PIR · Rel T1 PIR
- Rules: `prologos-syntax.md` § Reader · `pipeline.md` · `workflow.md` · `on-network.md`
