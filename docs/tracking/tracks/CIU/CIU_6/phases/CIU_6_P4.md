# CIU 6 — D4, §5.P4 (co-design, partition, pause)

Part of [D4](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md), CIU 6's implementation design, split into its parts on 2026-11-06 (owner-approved). This file holds D4 as it stood at `3e76762d`, unchanged except link targets: D4 lines 6105–6376 are lines N-6098 here.

---

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
  2026-08-07** (see [Q_U9](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u9)'s correction block: the lines are LIVE as
  markers 43/44 since P4d-0, and the Functor census was false when written —
  the error drops the "no instance" clause) · dyn-tail
  4d refusals.
- <a id="p4e"></a>**P4e — the `*` family · disclose `<`/`:<` · branch-initial `:`
  + closures**: ⚠ **RE-SCOPED 2026-08-08 by the P4e design round** —
  [Q_U23](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u23) · [Q_U24](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u24) · [Q_U25](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u25) · [Q_U26](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u26).
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
  - ~~**bare `.*` = ravel** (Q_U26) — needs the grouping fix; `values.*` shatters
    at HEAD~~ → **ravel is `x:*`** ([Q_U63](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u63) = J, 2026-11-02); `.*` becomes a guided refusal
  - **branch-initial `:`** for the ordinal² transpose (Q_U25) — `values{:0 :1 :2}`;
    ⚠ lifts a [Q_U7](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u7) v1 refusal, and ⚠ **must REPLACE, not delete, the
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
   *(both corrected 2026-08-07 — see [Q_U9](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u9)'s correction block)*;
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

