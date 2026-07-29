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
| **P0** | **Acceptance corpus** — augment the EXISTING acceptance file with the spec §10 examples + Appendix fixtures; `--check` gated; new forms commented until their phase lands | ✅ | §5.P0 · `e2674208` — 28/28 markers, 0 errors; all 7 fixtures load (layout via `def X`, issue #80 sidestepped); corpus phase-tagged in HEAD notation; carrier pins double as §2.3 docs |
| **P1a** | **Retirement batch + substrate** — dot-key family · the FULL `broadcast-get` chain (reader + parser keyword + surf + elaborator + node) · `m[:kw]` · reject batch · `surface-rewrite.rkt` `dot-lbrace` cleanup (BEFORE any re-mint) · the marker-form diagnostic seat | ✅ | §5.P1a · **`859b529d`** — suite 9253/474/0, acceptance 28/28 + 89/89, −744/+320; adversarial verify found 2 whole-file-abort defects (1 MINE, in the seat) → fixed + pinned pre-commit |
| **P1b-i** | **Repairs + probes + the Q8 DRAFT** — the top-level `<` swallow fix (Q_M4) · WS narrowing typed vars · `def ?x` reservation (Q_M3) · the Q_M1 gating probe + `:N` / keyword-`*` / `:<` · **Q8 written from the results** | ✅ | §5.P1b-i + **§Q8** · `fc65ca54` — suite 9263/474/0, corpus A/B 160 files / 2 intended diffs; **Q8 owner-reviewed ✅ 2026-07-28, amended by Q_M8** (ordinals multi-digit in both bands) |
| **P1b-ii** | **The `.{` opener** — `dot-lbrace` re-mint, **SIX** sites incl. the surviving `surface-rewrite.rkt:516` (a POSITIVE addition — omitting it REGRESSES a currently-correct grouping); plain `'rbrace` closer per Q_M5 | ⬜ | §5.P1b-ii · must land BEFORE/WITH P1b-iii (Q_M2) |
| **P1b-iii** | **Brace adjacency + the head registry** — the forced select-block sentinel (Q_M6) · leaf-module registry · the 4 buckets · NET-NEW WS `racket{…}` pins | ⬜ | §5.P1b-iii |
| **P2** | **Grade-1 core** — `.k`/`.N` access + bare-path extraction, on the landed P2 substrate | ⬜ | §5.P2 · `.N` has an end-to-end head start via `(get expr N)` |
| **P3** | **Blocks** — `x{…}`, projection-by-default, `^` (3 continuations), L4 sort homogeneity, **HONEST NESTING (n-tuples at every n — ruled 2a)**, **STRICT merge** (the §3.6 waypoint) | ⬜ | §5.P3 · Q2 gate RESOLVED (2c: carrier order, thesis-derived) |
| **P4** | **Broadcast ω** — `:s` one-step extent, L1 fusion, **map-generic `:`** (Q1 ✅), `*` flatten, `.*` row-splat, **the 2b HETEROGENEITY SPLIT** (per-position exact over tuples; keys-⋂/types-⋃ over PVec-of-union = NEW row-meet machinery) · **disclose `<`/`:<` (Q5 ✅ v1)** · dyn-tail = support-bounded (4d) | ⬜ | §5.P4 · step-list node (4b) · per-field row-map (4c) |
| **P5** | **Ruling B + factoring** — B2 keywise / B3 same-spine merge, L2 normal form, guided errors printing the factored spelling | ⬜ | §5.P5 · L1–L5 law battery |
| **PX** | **Binder-seam substrate** (carried, surface-independent) — the lambda-adoption hole + the standalone-def seam | ⬜ | §5.PX · position flexible |
| **P6** | **Demand semantics** — RULED STAGED (4a): spec tag amended, X.close gated; lazy-leaf design = own post-v1 phase | ⬜ | §5.P6 |
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

### §2.3 The carrier table (printed forms + the spec-notation translation)

The §2.1 grounding was lexical; this is the TYPE/PRINT layer the D5 critique
showed was missing (its "single most important unasked question"). Probed
2026-07-28 @ `2b1b383d`:

| Spec writes | HEAD's carrier + printed form | Notes |
|---|---|---|
| `〈T〉` (U+3008) | `[PVec T]` | homogeneous vector |
| n-tuple `〈T₁ T₂〉` | `⟨T₁ T₂⟩` (U+27E8) — a nat-keyed CLOSED row | het `@[…]` literals produce this |
| `〈τ₁ \| τ₂ \| …〉` het vector | **`⟨row₁ row₂ row₃⟩`** — a positional het TUPLE, duplicates un-collapsed, no union | the 2b split's first carrier; PVec-of-union exists only via annotation |
| 1-tuple `〈String〉` | representable (1-field nat-row; runtime `expr-rrb`) but the LITERAL arm collapses `@[x]` to `[PVec T]` | selection mints rows directly — the 2a ruling |
| keyed row `{:k T …}` in selection order | type: **canonically sorted** (`syntax.rkt:749-756`, `equal?`-identity, load-bearing) · value: champ-hash order, key-set-determined | the 2c ruling: carrier order, thesis-derived |
| row-meet (§5.3) | **does not exist** (0 grep hits) | booked as NEW machinery, §5.P4 |
| presence marks + `dyn` tail | `expr-Record (key-domain fields tail)`, `record-field (type presence)` — the S-lens-declared presence lattice | in NEITHER document; §6 declares it; dyn-tail semantics = Batch-4 question |

### §2.4 Standing items the spec does not cover

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

- **Q_L1 — colon seam: the `?`-PREFIX DISCRIMINATOR adopted; the WS repair is
  SCOPED IN.** Ruling 3d's position-disjointness is **REFUTED at HEAD**:
  narrowing-query typed logic vars (`[add ?x:Nat ?y:Nat] = 5N` — 6 live sites,
  consumer `narrow-var-constraints` parser.rkt:6871) are `ident:Ident`
  annotations in EXPRESSION position, a different subsystem from POL.6.
  Resolution: broadcast never claims a `?`-headed subject — the discriminator
  already exists in the surface. Rider: that surface is ALREADY silently
  broken in WS (the splitter runs on a glued symbol only the sexp reader
  produces; the sole WS test is VACUOUS — passes on substring "x"), so P1b
  repairs it, else P1 cannot tell new breakage from old.
- **Q_L2 — the WS-vs-sexp `.{` divergence is INSTITUTIONALIZED** (the POL.9
  precedent): sexp `.{` = selection-path fan-out (15 live test sites,
  parser.rkt:3481) STAYS; WS `.{` = the mid-path sub-block (ruling 3a).
  Documented eyes-open; convergence belongs to the future sexp phase (§2.4).
- **Q_L3 — `broadcast-get` retires as the FULL CHAIN at P1a**: reader token +
  parser keyword (parser.rkt:146, arm :2332-2350) + surf struct
  (surface-syntax.rkt:251/:894) + elaborator arm (:2394) + the expr node +
  its 2 walker-safety pins. Census: the keyword form has **ZERO live users**
  — this is dead-API removal, not capability retirement. Basis: ban-dual-paths
  (keeping it beside P4's `:` is two mechanisms for one operation);
  "partial retirement" is a red-flag phrase; and the audit itself proved
  partial retirements rot (`d18648f0`'s surviving surface-rewrite leg).
  Completeness-over-deferral: no unbuilt dependency exists, so no deferral is
  licensed.
- **Q_L4 — the diagnostic seat is BUILT at P1a**: reader emits a retirement
  MARKER FORM; preparse converts it to a per-command **`parse-error` VALUE**.
  Prior art: `$mixfix-retired` (deleted `d18648f0`) proves the marker
  mechanism end-to-end; its flaw was RAISING (`expand-mixfix-retired` called
  `error`) — which is exactly why audit-09 aborted with zero output. The
  named tilde template is probe-proven a WHOLE-FILE ABORT (structural: the
  reader tokenizes the entire file before any command runs, driver.rkt:2226),
  which would contradict the accepted-gap ruling's own premise (noise, not
  silence) and the spec §3.6/Q8 error-surface obligations.
- **Q_L5 — the working-tree `.[x]` / `.[a.b]` spellings are PRIOR SKETCHING —
  disregard** [owner]. In neither the spec nor D4; all censuses run against
  HEAD (`git show HEAD:<file>`), never the dirty tree (the audit's two
  wrongly-"refuted" counts both measured owner WIP).
- **Q_L6 — P1 SPLITS into P1a (retirements + substrate) / P1b (seams + Q8)**:
  audit-discovered scope (the surface-rewrite cleanup, the reader-form-head
  registry, the diagnostic seat, the 4-site chain, net-new pins) made the
  single phase too large for one gated slice.

**The P1b mini-audit rulings [owner, 2026-07-28]** (audit `wf_d0862784-5e5`, 6
facets + completeness critic @ `bc0c7578`; every load-bearing finding
main-session R-lens-verified; full record in §5.P1b):

- **Q_M1 — `:N` disambiguated by POSITION (option b).** ⚠ The audit's largest
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
- **Q_M2 — P1b SPLITS THREE WAYS** (audit-recommended, owner-approved), with
  an ORDERING CONSTRAINT the design had not stated: **`.{` must be re-minted
  BEFORE or WITH lbrace adjacency**, because `.{` today presents a loose `|.|`
  token whose end-pos abuts the `{`, so adjacency-first would turn every
  in-flight `x.{…}` into a select block anchored on a bare dot.
- **Q_M3 — `def ?x` becomes a GUIDED ERROR.** Q_L1's "the discriminator
  already exists in the surface" is a **namespace RESERVATION we are making**,
  not a property we inherit: `def ?cfg := {:a 1}` is legal at HEAD and
  `?cfg.a` → `1 : Int` at 0 errors (probe-verified). Owner rationale: `?` is a
  **modality** marker (functional narrowing; `defr` logic-var params), so a
  `def` binding was never meant to be one — reserving it costs nothing now and
  prevents the surprise later. No present soundness issue; the reservation is
  prophylactic.
- **Q_M4 — the TOP-LEVEL `<` SWALLOW IS FIXED IN P1b-i [owner]**, not
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
- **Q_M5 — ruling 3a's PRECEDENT is CORRECTED**: the model is **`hash-lbrace`
  (6/6 sites, plain `'rbrace` closer, probe-verified nesting)**, NOT
  `dot-lparen`. Citing dot-lparen silently imported its `'mixfix-rparen`
  sentinel, which exists to carry SEMANTIC MODE, not to disambiguate a
  closer — and a sentinel closer would reproduce the `31d27c83` cross-line
  swallow, because the extent scanner stores REAL token types as frame
  closers (parse-reader.rkt:1311) and `langle-matched?` has no translation
  arm. **`dot-lbrace` uses plain `'rbrace`.** The word "closer" never appeared
  in ruling 3a.
- **Q_M6 — a DISTINCT SENTINEL for the select block is FORCED, not
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
- **Q_M7 — the standing `^` ruling is CORRECTED (it was not executable).**
  "`^` splitting is P3-parser-side via POL.6 `split-fused-symbol` — no second
  splitter" names the WRONG primitive: `split-fused-symbol` (parser.rkt:5437)
  splits on `":"`, has two binder-path callers, and REJECTS >2 segments; the
  tree's ONLY `^` splitter is parser.rkt:3543 inside `validate-selection-
  paths` — which is the SEXP-ONLY surface Q_L2 freezes. **P3 has no reusable
  WS-path `^` primitive** and must either lift the sexp one or write the
  primitive the old ruling forbade. Recorded now so P3 does not build on a
  false premise.
- **Q_M8 — ORDINALS ARE MULTI-DIGIT IN BOTH BANDS [owner, 2026-07-28].** The
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
- **Gate**: NONE open on the critical path. Spec Q2 was DISSOLVED by ruling 2c
  (carrier order, thesis-derived); the only open question is **Q8 (the lexical
  grammar), which is ANSWERED BY §5.P1** — its own deliverable, not a blocker on
  anything upstream.

---

## §5 Per-phase sections

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
   PNET_VERSION bump if the node is tag-registered (decide from the serialize
   table; the #78 v3→v4 precedent — a version sweep is the only reliable
   cache invalidation). The `.*name` guided error names `:name` as the P4
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
Status: ⬜.

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

## §Q8 — THE LEXICAL GRAMMAR  ✅ *owner-reviewed 2026-07-28; NORMATIVE*

> **Review outcome**: adopted as written, with **one amendment — Q_M8**
> (ordinals are multi-digit in both bands; the draft's `:N` recommendation was
> withdrawn as wrongly-premised). Q8 now governs P1b-ii, P1b-iii and P2.

Written FROM the P1b-i probe results, not from leans. Every row is
probe-verified at `fc65ca54` unless marked `[P1b-ii]` / `[P1b-iii]` (the rows
those slices will add). Priorities are quoted from the registrations; **see
the invariant note at the end — priority is NOT the safety property.**

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
| 6 | `x.{…}` | *(fallback)* → `dot-lbrace` | `{` | **`[P1b-ii]`** — today falls to the single-char `.` |
| — | `3.14` | `decimal-literal` (75) | anchors at a **DIGIT**, never at `.` | live — no overlap with the band |
| — | `x . y` | single-char symbol fallback | — | the catch-all; `.N` also lands here until P2 |

**Totality**: the five band members test *different* second characters
(`.`/`:`/`(`/`*`/ident-start), and `recognize-dot-access` excludes `:`, `{`,
`*` and digits **explicitly**, so `.{` is double-guarded and a `dot-lbrace`
insertion is disjoint from all five. `.-1` LEXES CLEANLY as dot-access with
field `-1` (`ident-start?` admits `-`), so the carried "`.-1` = classifier
rejection" ruling is about a **well-formed token**, not a shatter — P2 owns
it when `.N` arrives.

**`.N` is MULTI-DIGIT, and it FIXES A SILENT WRONG ANSWER (ruled Q_M8).** P2's
`.N` recognizer anchors at the **dot** and takes `digit+` (not one digit). It is
prefix-disjoint from `decimal-literal` (which anchors at a **digit**, never at a
dot) and from all five band members. Probe-measured at `b389479b`, today:

| Source | Today | Why |
|---|---|---|
| `x.10` | `(x \|.\| 10)` | falls to the single-char `.` fallback |
| `x.1.2` | `(x \|.\| ($decimal-literal 6/5))` | **the RATIONAL bug** — `decimal-literal` anchors at the `1` |
| `x.10.20` | `(x \|.\| ($decimal-literal 51/5))` | same class, multi-digit |

A dot-anchored `digit+` recognizer kills the rational **structurally**: the
tokenizer consumes `.1` at the dot, then `.2`, so `decimal-literal` never gets to
anchor. Multi-digit is therefore not an extra — it is the same one-line `digit+`
that fixes `x.1.2`.

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

### Q8.4 — `*` and `<`

| Form | Finding |
|---|---|
| `:diags*` | `*` GLUES (`recognize-keyword` delegates to `ident-continue?`, and that delegation **is** the F1b.7g anti-drift fix). `int*`/`trait*` are live identifiers, so a charset change is forbidden — the split must happen at a **CONSUMER**. Prior art: `validate-selection-paths` already splits `^` off a keyword lexeme and handles a whole-segment `"*"`. |
| `:<` disclose | **SAFE as of `fc65ca54`.** The hazard was never `:<` — a bare depth-0 `<` swallowed identically, and so did `def p := 1 < 2` / `def q := 3 > 4` with no colon and no brace. Fixed by the Q_M4 bound; `users:<{a}` + a later `>` now reads as three forms. |

### Q8.5 — Standing invariants

1. **Prefix-disjointness, NOT priority, is the safety property.** Priorities
   TIE in two places (`dot-lparen`/`broadcast-access` both 87;
   `nil-dot-key`/`nil-dot-access` both 92) and the registry is a plain hash
   sorted descending — **ties break by unspecified hash order**. A new
   recognizer must be prefix-disjoint and must not rely on its number.
2. **Adjacency lives in TOKEN POSITIONS and is DESTROYED at the datum layer.**
   `x{a b}` ≡ `x {a b}` byte-identical as datums. Any rule keyed on adjacency
   must be decided at or before grouping. *(P1b-i learned this the hard way:
   a datum-layer fusion of `?x` + `:Nat` absorbed unrelated keywords.)*
3. **New sentinels owe two registrations**: `pattern-var?` (macros.rkt) and
   tree-parser's inline skip-list — both hard-coded enumerations.
4. **Both reader modes, always.** WS and sexp diverge by construction here
   (adjacency, `.{`), so a census in one mode proves nothing about the other.

### §5.P1b-ii — The `.{` opener  ⬜

`dot-lbrace` re-mint across **SIX** sites — five in parse-reader.rkt
(registration · extent frame dispatch :1310 · extent langle skip-set :1292 ·
group-items langle skip-set :2357 · group-items opener arm :2500) **plus
surface-rewrite.rkt:516** (the positive addition above). Closer = plain
`'rbrace` (Q_M5). Decide the group-tag question (seventh site, above).
Prefix-disjointness re-verified post-P1a: the band is still five members
(dot-key and broadcast-access remain registered as marker emitters) and
`recognize-dot-access` excludes `{` explicitly AND requires `ident-start?`.
Flips: test-parse-reader.rkt:401-406 (asserts NO dot-lbrace token — INVERTS)
and test-mixfix-01.rkt:54-58 (asserts `.{` RAISES via the compat path — a
DIFFERENT flip shape). Status: ⬜.

### §5.P1b-iii — Brace adjacency + the head registry  ⬜

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

Status: ⬜.

**Acceptance delta for ALL of P1b: ZERO markers uncommented** — every line
P1b makes LEXABLE is a P3/P4/P5 SEMANTICS target, and the file's convention
ties uncommenting to a verified `;;N=>` RESULT; there is no honest result for
"this now tokenizes." Reader pins go to `test-parse-reader.rkt`. ⚠ Six
currently-PASSING markers are at RISK if `(pair? result)` is dropped.

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

`^` is NOT touched in either half (parser-side split at P3, per the standing
ruling — no second splitter).

**Test delta**: seam pins in `test-parse-reader.rkt` (RRB-native API — the
three-API finding standardizes here) both modes; the WS narrow-var repair pin
(replacing the vacuous one); WS `racket{…}` pins; adjacency-bucket pins incl.
the closing-delimiter bucket and the binder-brace must-not-change population.
Status: ⬜.

### §5.P2 — Grade-1 core

**Intent**: `.k`/`.N` access + bare-path extraction — the spec's grade-1
fragment, on the P2 substrate.

**Grounded head start** (audit + probes): `.N` extraction works END-TO-END
today via a `(get expr N)` fold arm — `expr-get` types PVec + tuple(nat-row) +
Map + List subjects; site 7 projects; the two-tier principle makes misses
loud. The fold target is `get`, NOT `map-get` (probe: map-get's infer has no
PVec leg). `.k` nominal access already works (dot-access → map-get fold).

**Work**: the `.N` recognizer (dot-anchored, prefix-disjoint inside the **FIVE**-
member band {rest-89 · dot-key-88 · dot-lparen-87 · broadcast-87 ·
dot-access-86} — ⚠ this section previously cited a THREE-member band, the
under-count Q8.1 corrected; and per Q8.5 invariant 1 the safety property is
**disjointness, not priority**) · the nat-dot fold arm → `(get expr N)` · chain
forms (`admins.0.name`) · extraction typing = the existing arms (no new nodes
expected — flag if that breaks).

⚠ **Q_M8 — `.N` TAKES `digit+`, NOT ONE DIGIT, AND THAT FIXES A LIVE SILENT
WRONG ANSWER.** Multi-digit ordinal access is owner-ruled. It is not extra
work: the same one-line `digit+` that admits `x.10` is what kills the rational
bug, because a dot-anchored recognizer consumes `.1` before `decimal-literal`
(which anchors at a **digit**) can ever anchor. Probe-measured at `b389479b`:
`x.1.2` → `($decimal-literal 6/5)` and `x.10.20` → `51/5`, both at 0 errors.
**Failing-test-first on those two**, not just on `x.10`.

Clarification carried from Q8.1: `.-1` **lexes cleanly** as dot-access with
field `-1` (`ident-start?` admits `-`). A digit-required `.N` correctly declines
it, but the carried "`.-1` = classifier rejection" ruling is therefore about a
**well-formed token** and is a CONSUMER decision, not a classifier one.

**Test delta**: corpus §10 grade-1 lines uncomment; track-file pins for the
chain forms + `v[0]`-coexistence pins (both spellings extract, per the
ruling). Status: ⬜.

### §5.P3 — Blocks

**Intent**: `x{…}` select block · projection-by-default · `^` three
continuations (parser-side split) · L4 sort homogeneity (level-local) ·
**STRICT merge** (the §3.6 monotone waypoint: ALL duplicate output keys
error, remedies named in the message) · result typing: copattern demand
against the coinductive record type; grades 1-only at this phase.

**The Q2 gate is RESOLVED (ruling 2c)**: type rows canonical (landed),
value order carrier-determined — derived from the key-sort thesis itself
(nominal key order carries no meaning). Result-equality tests transcribe
markers to champ order. **Honest nesting is RULED (2a)**: the block
constructor mints nat-rows directly at every n including n = 1 — the literal
arm's PVec collapse is irrelevant (selection never routes through it); the
disclose operator is the designed unwrap remedy [owner].

**Design questions to settle in this section before code** (each gets a
mini-audit): the block's parse representation (new surf/expr nodes — full
pipeline.md cost, budgeted honestly this time: constructor sites compile
CLEAN cross-module, discovery is patterns+runtime); where `^` splitting binds
(POL.6 splitter at parse of block branches); L4's error seat; the honest-
nesting 1-tuple display.

**Test delta**: corpus §10.1 uncomsments (minus computed-leaf demand
assertions); L4/collision negative pins. Status: ⬜.

### §5.P4 — Broadcast ω

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
- **Realized on the STEP-LIST NODE** (4b): typing WALKS the steps; reduction
  LOWERS per step onto shipped machinery (`get`, `pvec-map`, `map-map-vals`).
  **`expr-broadcast-get` RETIRES** with `.*name` — it is not repaired.

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
map tutorial, `prologos-syntax.md`'s selection section) · **the §1.3 demand
GATE (ruling 4a): v1 may not be declared complete without the staged-demand
status re-stated in the PIR and the lazy-leaf phase chartered or explicitly
re-deferred by the owner** · memory fold · **Stage-5 PIR** (the track does not
flip ✅ without it). Status: ⬜.

---

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

**OPEN (named for the Batch-4 walkthrough): dyn-tail semantics** — what `.*`
row-splat and map-generic `:` mean over a row whose tail is `dyn` (unknown
support). The old surface's SUPPORT-BOUNDEDNESS principle (D3-M5, survived)
says splat needs a bounded support; `(Map K V)` uniform broadcast needs no
per-field row at all. Ruled in Batch 4.

**NTT posture**: v1 adds zero propagators/cells — ratified twice (predecessor
§7; D3-M2 refutation). The deferral is now NAMED with a TRIGGER (§9 gate row
3): the broadcast-propagator node track opens on X.close perf pressure or
F-row, whichever first, with its NTT model mandatory.

## §8 Risks (carried forward + new — the D5 critique's ⑤)

- **R2 (walker gaps)** — carried: every walker touching the NEW nodes (block,
  `^` continuations, broadcast steps) defaults to the generic
  transparent-struct rebuild (three in-tree templates: the SUB.1 tripwire,
  `re-abstract`, `narrow-subst-bvars`); explicit arms only for binders + hot
  paths, hot arms carrying a differential-oracle contract test.
- **R3 (`.` on QUADRUPLE duty)** — sharpened: `.k` · `.N` (new) · `.*` ·
  bare `.` before `{` (the sub-block seam). The Q8 grammar must state all
  four and their disambiguation order; both-modes census per
  `prologos-syntax.md` § Reader.
- **R4 (a green suite proves nothing for this class)** — carried verbatim:
  failing-test-first for anything walker- or seam-shaped; the D5 critique's
  three live probes (permissive `expr-broadcast-get`, the `:=` layout defect,
  the loose-`.{` shatter) all sat under a green suite.
- **R5 (NEW — carrier drift)**: the spec's idealized carriers vs HEAD's
  (§2.3). Any §10 corpus divergence must be classified NOTATION vs SEMANTICS
  before resolution (ruling Batch 1); a "quick fix" that edits a marker
  without the classification re-opens the D5 blockers.
- **R6 (NEW — pipeline cost honesty)**: new AST nodes pay pipeline.md in
  FULL — including `pnet-serialize` registration + a `PNET_VERSION` bump
  (absent from pipeline.md's own checklist; promote it there at X.close) +
  the D3-M2 item-13 deliberate `#f` typing-propagators registration —
  and constructor-arity breakage compiles CLEAN cross-module (the slice-4
  lesson): discovery is patterns-at-build + constructors-at-runtime.

## §9 Principles gate (two columns — catalogue ‖ challenge)

| Decision | Catalogue (passes?) | Challenge (could it be MORE aligned?) |
|---|---|---|
| Strict merge first (§3.6 waypoint) | Monotone: errors may become meanings, never the reverse. CALM-adjacent staging. | Challenged and KEPT: the alternative (Ruling B at P3) front-loads spine identity before broadcasts exist to have spines. The waypoint is sequencing, not scaffolding — no dual path exists at any moment. |
| `v[0]` retention beside `.N` | Owner-ruled 2026-07-28. | Challenged: is it belt-and-suspenders? NO — two SURFACES over ONE mechanism (`(get expr N)`); the D5 verifier refuted the dual-path framing. Residue: an X.close revisit trigger is named (retire, document as `get` sugar, or keep). |
| Zero-propagator v1 (§5.P4) | Ratified twice (predecessor §7; D3 critique M2 refutation — the Check asks what the track ADDS). | **Challenged and CHANGED**: "the future NTT-modeled track" had no name and no trigger — the ban-"pragmatic" rule demands specificity. Now: **deferred to the broadcast-propagator node track (CIU, post-v1), TRIGGERED by either (a) selection-perf pressure at the X.close bench matrix or (b) F-row landing** — whichever first; the NTT model is mandatory at that opening. |
| Projection-by-default flips by enclosure (spec §1.2: the same path text means block-projection inside `{…}`, extraction outside) | The spec's own per-step discipline; consistent with copattern reading. | Challenged and KEPT with an obligation: this is the surface's largest learnability bet; the corpus MUST pin the pair (`x.a.b` vs `x{a.b}`) side by side so the flip is documented by executable example, and the P3 error for the common confusion (a bare path where a block was meant) names the other spelling. |
| Demand semantics staged (P6) | Honest: the collision is priced, not hidden. | Challenged: is staging an ADOPTED element a "validated-not-deployed" shape? Resolution = Batch-4 ruling: amend the spec tag to [ADOPTED — staged] + an X.close gate row, or commit v1. The gate row is the tripwire either way. |

## §10 References

- **The spec** (normative surface): `docs/research/2026-07-28_path-selection-spec.md`
- Predecessor design (record of rounds 1–8b): `2026-07-26_CIU_T6_PATH_SELECTION_DESIGN.md`
- Landed substrate: P2 commits `ad75e57a` · `88d1f746` · `b8f7cc27` · `d4f4b80f` · `ac89341f`
- P3 mini-audit: `wf_2830f0aa-9a4` (token registry, censuses, seats) — findings recorded in the predecessor's P3 row
- Records substrate: `2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md` (D1–D29) · F1b PIR · Rel T1 PIR
- Rules: `prologos-syntax.md` § Reader · `pipeline.md` · `workflow.md` · `on-network.md`
