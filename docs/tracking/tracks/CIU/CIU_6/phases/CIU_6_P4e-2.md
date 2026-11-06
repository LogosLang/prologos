# CIU 6 — D4, §5.P4e-2

Part of [D4](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md), CIU 6's implementation design, split into its parts on 2026-11-06 (owner-approved). This file holds D4 as it stood at `3e76762d`, unchanged except link targets: D4 lines 12555–12707 are lines N-12548 here.

---

<a id="p4e-2"></a>

### §5.P4e-2 — RAVEL `x:*` ([Q_U63](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u63) = J): design target and plan  (opened 2026-11-03, branch `ciu6-path-selection` @ `bd2e48ff`; mini-audit: [its own document](../audits/2026-11-03_CIU_6_P4e-2_GROUNDING_AUDIT.md))

The mini-design (Implementation Protocol, per-phase step 1) is here. The mini-audit's findings (step 2) are in
[their own document](../audits/2026-11-03_CIU_6_P4e-2_GROUNDING_AUDIT.md), cross-referenced below. The commit
story is in the track LOG. The process was revised on 2026-11-03 (owner: "Audit findings can be their own thing and not
cloud-up the design doc (but cross-reference)"); the findings were first drafted here at `71c8dbfc`. `e:N` cites
`research/P4e-2/probe-p4e2-e.out` line N (`5876569b`); `inject:N` cites `inject.out`.

**Design reference.** [Q_U63](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u63) = J and its critique [JC-n / JD-1…7](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u63-jc), with the five
laws listed there; [Q_U26](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u26)'s meaning (a one-level whole-container join) under J's spelling;
[Q_U23](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u23) / [Q_U46](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u46) (a star deletes the layer its *preceding step* made);
[Q_U27](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u27) (`*` is sort-generic in the surface, and the mint carry-overs (i)–(iv));
[Q_U30](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u30) (all seven carriers, tokenizer repair included); [Q_U35](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u35) (`*` after a
non-selection expression is refused). DEFERRED 185 (its reader seats ride here), 105 (the R4
tokenizer repair, ⛔), 167 (the in-block broadcast), 192 (non-ground fact terms). Spec §2.1 / §3.5
departures: still proposed to the owner, not applied (Q_U63's decided text).

**Obligations carried.** From the P4e-2 row of the slice table (`D4:12059`): the `:*`
production; ε as `(@bcast ε)`; JD-2…4's messages and JD-3's waypoint; the laws; DEFERRED 185's reader
seats. From JC-2: "the identity broadcast must be the identity at BOTH twins" — a claim to pin, not
yet a theorem. From DEFERRED 185's update: its remedy text becomes `x.N:*` once `:*` runs ("a remedy
is offered only once it runs"). From Q_U27: the mint lands ALONE, with a corpus A/B and a named
predicted diff set, one definition consumed by both groupers, the decline as a class. From
`.claude/rules/tree-sitter-grammar.md`: the editor grammar learns `:*` in this slice, or a DEFERRED
says why not.

**Principles in play** (`principles/DESIGN_PRINCIPLES.org`):
- *Simplicity of Foundation* — "Complexity is built through composition, not special cases." J adds
  no rule: ravel is the broadcast composed with the existing join. The pressure point is ε, a new
  kind in a closed union.
- *Correct by Construction* — "illegal states are unrepresentable". A bare `(@id)` step outside a
  broadcast is representable once ε exists; it must be unbuildable or refused (RA-3).
- *Progressive Disclosure* — the near-miss messages are the interface: today every J near-miss is a
  bare "Unbound variable" (e:16–22, e:24).
- *The Most Generalizable Interface* — ε inside the broadcast reuses ONE container dispatch (keyed
  Map layer, tuple per position, union meet, Nil skip, meta carry) instead of a ravel per carrier.
- *Decomplection* — spelling and meaning separate: J changes Q_U26's spelling; its meaning stands.

**Mantra check** — catalogue, then challenge.

| word | catalogue | challenge |
|---|---|---|
| all-at-once | the mint is a positional rule over adjacent tokens; its result does not depend on what else the file holds | the grouper is a left-to-right scan (`group-items`), and the trigger reads its accumulator (`(pair? result)`, `parse-reader.rkt:4277`). That is reader scaffolding, off the network; the surface-on-network work (PPN) owns its retirement. Say so; do not dress it up |
| all in parallel | each `:*` site is independent of every other | the `$select-path` fold nests left to right by construction; independent per form, sequential within one |
| structurally emergent | ravel = broadcast ∘ join, both decided; ε is the identity of the step monoid, so the laws (bind, naturality) are theorems of that structure, to be pinned | ε is a seventh kind: an arm at every consumer is special-case pressure. Can ε be an existing kind? Checked: no. A sub-block of one empty branch assembles a ROW, not the element (`select-bcast-inner-apply/non-union`'s `@sub` arm, `typing-core.rkt:1381`) |
| information flow | the twins (typing `select-bcast-lift` `typing-core.rkt:1219`, reduction `bcast-lift` `reduction.rkt:2157`) share the classifier and the per-step functions | two walks kept in agreement by pins, not by construction. ε must go through the GENERIC per-step functions so the twins cannot disagree on it; a ravel arm written twice is the drift this phase must not add |
| ON-NETWORK | elaboration and type checking run on the network | the selection typing walk (`select-project`) is an off-network recursive walk; P4e-2 extends it. Labelled scaffolding (PPN 4C territory), not a new off-network mechanism |

**Drift risks, named before code** (the close's VAG checks each):
1. **A count-changing mint** — DEFERRED 105's failure mode (`D4` [§5.P4e-0](CIU_6_P4e-0.md#p4e-0) attempt 3 slice B: "containment is not a safety
   property"). J turns `values:*` from 3 datum items into 1. Every position measured (RA-9); the corpus A/B is restated as a meaning claim.
2. **ε as a parallel ravel path** in the walkers instead of the identity through the generic per-step functions. Countered by the
   laws at both twins and a mutation per twin seat.
3. **A third copy of the `:` trigger.** `:k` and `:{` already have one each (`parse-reader.rkt:4309`, `:4319`); a third
   hand-written copy is the F1b.7g drift class. The `:*` trigger generalizes `bcast-brace-trigger?`'s following-token test.
4. **A tokenizer-level `:*` keyword.** It would make `{:* 1}` (refused today, `dump: {:* 1}`) a one-entry Map silently. The mint
   stays at the grouper, gated on a base; pinned.
5. **A remedy offered before it runs.** The `.**` message already offers `xs:*` (RA-5). Every remedy is run on its row's subject.
6. **Scope creep**: path literals `#p(a:*)` (PF's, JD-6), `selection` declarations (JD-7, untouched), the MEANING of `[f x]*`
   (Q_U35: refused; only its remedy text changes), the in-block broadcast (DEFERRED 167: a waypoint only).
7. **Performance**: no microbench claim is load-bearing here (protocol step 6 does not apply). The trigger adds one predicate per
   `colon` token; the corpus A/B reports reader wall time as a bounce-back check only.

**What the mini-audit changed in the design.** The findings are in their own document,
[the P4e-2 grounding audit](../audits/2026-11-03_CIU_6_P4e-2_GROUNDING_AUDIT.md) (RA-1…13, probes at
`5876569b`). The decisions they led to:
- **The reader seat is the `:` gate's third case** (RA-1, RA-2). A bare colon glued on both sides, to a base and to a
  star-family token, emits what a keyword `:k*` emits with k = ε. The keyed twin already carries every continuation J
  needs. A parser-side J is refuted: without the mint, `values:*:name` builds a path whose subject is `*`.
- **ε is `(@id)` inside `(@bcast ε)`**, with one constructor; a bare `(@id)` is refused (RA-3). This reuses
  `select-bcast-lift`'s container dispatch; a nullary `(@ravel)` kind would rebuild that dispatch per container.
- **No retirement inventory** (RA-4). No pin flips. JD-7 leaves the 18 `selection`-declaration lines alone.
- **DEFERRED 185's reader seats split** (RA-7). The ordinal-STEP family (`t3.0*`, `y.a.0*`, `y{a.0*}`) gets Q_U46's
  refusal, with the remedy `x.N:*`. `xs:0*` gets its MEANING, the ordinal-sort sibling of `xs:k*`, which the twins
  already compute. The seat is DEFERRED 105's, re-derived as landable (RA-8, a conjecture until built).
- **The count change is safe at every position but one, and that one is DEFERRED 192's** (RA-9). The fact-row rows
  become pins; 192 owns the fix.
- **Messages** (RA-5, RA-6, RA-11). `.**` names one level and two; JD-3's waypoint covers both block shapes; Q_U35's
  refusal gains `[f x]:*`.
- **The editor grammar gains one path-step alternative** (RA-10). Spec §2.1 / §3.5 and RA-13 stay proposals to the
  owner.

**Worked examples — what P4e-2 makes run.** Each predicted value is today's measured equivalent.

| intent | J | today | after P4e-2 = today's equivalent |
|---|---|---|---|
| ravel a matrix | `values:*` | Unbound variable (e:7) | `@[1 2 3 4 5 6 7 8 9] : [PVec Int]` e:31 (`values{0 1 2}*`) |
| a Map's values, joined | `mh:*` | Unbound variable (e:13) | `@[1 2 3] : [PVec Int]` e:32 (`mh{a b}*`) |
| … with provenance | `mh:*_` | — | refused, as `mh{a b}*_` is (e:33): the contents are vectors, with no fields to prefix |
| flatten element 0 | `t3.0:*` | Unbound variable (e:12) | `@[1 2 3] : [PVec Int]` e:35 (`t3.0{0 1}*`) |
| join, then a field | `groups:*:name` | Unbound variable (e:14) | `@["a" "b" "c"] : [PVec String]` e:34 (`groups{0 1}*:name`) |
| join each element's element 0 | `t3:0*` | Unbound variable (e:30) | `@[1 2 4] : [PVec Int]` e:36 (`t3:0{0 1}*`; the injected IR, inject:4) |
| ravel an expression's result | `[id values]:*` | Unbound variable (e:15) | as `values:*` (the subject, e:59) |
| full ravel, rank 3 | `t3:*:*` | Unbound variable (e:11) | `@[1 2 3 4 5 6]` — derived from the two one-level steps, not measured |

| near-miss (JD-1, JD-4) | today | the message will name |
|---|---|---|
| `values.*` | Unbound variable (e:16) | `values:*` |
| `values: *` / `values :*` | Unbound variable (e:17, e:18) | `values:*` (glued) |
| `values:**` | Unbound variable (e:19) | `values:*:*` |
| `values:.*` | Unbound variable (e:20) | `values:*` |
| `values:` | Unbound variable (e:21) | a step after the colon: `values:*`, `values:name` |
| `values.**` | offers `xs:*` (e:23) | `values:*` (one level), `values:*:*` (two) |
| `values.*:name` | Unbound variable (e:24) | `values:*:name` |
| `values*` | Unbound variable (e:22) | a hint, if cheap (JD-4): `values` is bound, `values*` is not |

**The plan — sub-slices, in the order that has worked** (pins first, the inert machinery, then the switch-on):
- **P4e-2-A — pins, all red.** J's laws as generated rows over the fixtures (bind `x:k*` ≡ `x:k:*`; known-length ravel
  `x:*` ≡ `x{0 … n−1}*`; a Map's values `m:*` ≡ `m{k₁ … kₙ}*` and `*_`; naturality `x:*:k` ≡ `x{0 … n−1}*:k`; JD-2
  `x:*-` ≡ `x:*`, `x:*-_` ≡ `x:*_`), each with a size pin predicted before the run; the near-miss, waypoint and remedy
  rows (expected text written from the decisions); the RA-9 position rows; the grammar's corpus trees.
  **✅ 2026-11-03, `8ecb7cbc`** (test-path-selection 582→585). The table is in
  [test-path-selection.rkt § D4.P4e-2](../../../../../../racket/prologos/tests/test-path-selection.rkt). It has:
  - 38 hand rows: C 15, D 11, E 5, plus 7 controls;
  - 28 generated law rows: `S:σ` ≡ `S{K}σ` over 7 carriers × the 4 star families, 14 of them equivalences and 14
    refusals. Each refusal is pinned to its block form's measured REASON: contents at positions, a Map of vectors, or a
    keywise collision (`research/P4e-2/probe-p4e2-grid.out`). The JD-2 laws are covered here, because each block form's
    `*-` / `*-_` equals its `*` / `*_` (grid lines 13–40);
  - B's 8 injection rows, plus a harness check in identity mode;
  - C's parity law over a NAMED domain (37 rows, empty before C).

  **Power.** 8 mutants, each failing only its own rows. Stage B → the 8 injection rows. Stage C → 56 = 15 + 28 + 8 + 4
  remedies + parity. A wrong PRE → 1. A wrong reason → 1. A dropped collision → 1 + the size pin. A blind harness → 8.
  PRE = TARGET → 3 test cases. Two predictions were wrong. My count of the hand rows (35 vs 38) had double-counted two
  remedy lists by regex, and was corrected by id before the first run. M8's 1 → 3 was corrected before its run.

  **Departure.** The grammar's corpus trees move to C, with the production. Tree-sitter's corpus runner has no staged-red
  mode, so a corpus tree written ahead of its production would fail the editor suite rather than pin a target.
  **Measured while pinning.** `values :k` is `Could not infer type` today (the K-kwarg control). `t3:**` is
  `Unbound variable`, the same as `values:*`, so JD-4's `**` row starts from the generic failure.
- **P4e-2-B — ε, inert.** `(@id)` joins the closed union with its arms at every consumer (RA-3); one constructor builds
  `(@bcast (@id))`, and a bare `(@id)` is refused. Reachable only from injection rows. Pins: the identity at both twins,
  and the injected laws. A mutation per twin seat.
- **P4e-2-C — the `:*` mint, ALONE.** One trigger predicate generalizing `bcast-brace-trigger?`'s following-token test,
  with the star family read from its one table (1b-v-C's fold); both groupers; the decline class. Corpus A/B with the
  named predicted diff set (∅ in production, by RA-4); the grammar production. A's J rows flip.
- **P4e-2-D — the messages.** JD-1, JD-4 (including `.**`, RA-5), JD-3's waypoint for both block shapes (RA-6), and the
  remedy texts that now run (185's block band → `x.N:*`; Q_U35 → `[f x]:*`, RA-11). Every remedy run on its row's subject.
- **P4e-2-E — DEFERRED 185's reader seats** (RA-7, RA-8): (i) the ordinal-step family → Q_U46's refusal via a reader marker;
  (ii) `xs:N*` → its meaning via the colon-annotation seat, reopening DEFERRED 105. Each its own mint with its own A/B.
- **P4e-2-F — the close.** The adversarial verify (four lenses), the fix round, main merged in, the full suite, the
  checkpoint; the spec §2.1 / §3.5 departures and RA-13 proposed to the owner.

**Decided at the checkpoint (owner, 2026-11-03 10:57): E(ii) rides P4e-2** — "Fine with the lean to include in Phase
4e-2." So `xs:0*` gets its meaning in this slice, which reopens DEFERRED 105 for that seat, as its own mint with its own
corpus A/B. The question as posed, with the lean and the counter-case it was decided on: does E(ii), `xs:0*` as a meaning,
ride P4e-2, or wait behind a guided waypoint naming `xs:0:*`? Lean: ride. Q_U30 put the carrier in scope, Q_U46 + Q_U27
give the meaning, and the twins already compute it (inject:4). Without it, the bind law `x:k*` ≡ `x:k:*` holds for keys
and is unspellable for ordinals. Counter-case: a second reader mint in this slice, at the seat where 105's slice B
regressed; the waypoint costs nothing and stays monotone.

