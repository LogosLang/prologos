# CIU 6 — D4, §5.P4e-1b-vi

Part of [D4](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md), CIU 6's implementation design, split into its parts on 2026-11-06 (owner-approved). This file holds D4 as it stood at `3e76762d`, unchanged except link targets: D4 lines 10214–11225 are lines N-10207 here.

---

<a id="p4e-1b-vi"></a>

##### §5.P4e-1b-vi — the star-COLLAPSE slice: design target, mini-audit, tracker  (opened 2026-10-13, branch `ciu6-path-selection`)

**Design reference.** [Q_U48](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u48) (`*-` is total collapse) · [Q_U55](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u55) (refuse an
ancestor rename under total collapse, both families) · [Q_U56](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u56) (`*->` guided in
selection territory) · [Q_U57](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u57) (P) · [Q_U58](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u58) (M + this slicing). Grounding:
[the audit](../audits/2026-10-13_CIU_6_P4e-1b-vi_GROUNDING_AUDIT.md) F1–F7; probes
`probe-1bvi-{a…o}` in `tracks/CIU/CIU_6/research/P4e-1b-vi/`. Spec: §3.4 ("dropped means
dropped"), §3.6 (monotone migration), §8 Q8 (the lexical grammar owes `*-` a clause).

**The semantics, stated once — every 1b-vi pin tests this.** For a branch `s₁ … sₙ ★`
with ★ ∈ {`*-`, `*-_`}:

- **Placement.** No ancestor `s₁ … sₙ₋₁` contributes an output level (as `^` would); ★ then
  acts as `*` / `*_` on the layer `sₙ` makes. Hence `*-` ≡ `s₁^.….sₙ₋₁^.sₙ*` whenever every
  ancestor is a key step (audit F2).
- **Naming** (`*-_` only, P). A lifted field `f` under content key `c` is named
  `n(s₁)-…-n(sₙ₋₁)-c-f`, where `n` is `select-step-output-name` (`syntax.rkt:1414`): kept →
  its name, renamed → the new name, dissolved → nothing, ordinal → nothing. Hence `*-_` ≡
  every lifted field written with `^-_` whenever every step is a key step.
- **Refusal** (Q_U55). An ancestor carrying a rename is refused under `*-` (and under `^-`,
  `^-k'`); a dissolve on an ancestor is legal and redundant.
- **Derived, not separately decided — path position, the closer seat, depth 1.** In path
  position no step has an output key (measured, `probe-1bvi-m`: every caret form there is
  refused, "a field access has no output key"), so there is nothing to collapse and nothing
  to name: `x.a.b*-` ≡ `x.a.b*` and `x.a.b*-_` ≡ `x.a.b*_`. Likewise with no ancestor (E1,
  E10). Put to the owner at the 1b-vi-A checkpoint rather than assumed.
- **ω, measured rather than derived.** Block-position ω KEEPS the projected key
  (`deep{top:cfg*_}` → `{:top {:eu-cfg {:x 1} :us-cfg {:x 2}}}`) where path-position ω consumes
  it (`rm:cfg*_` → `{:eu-x 1 :us-x 2}`), so P through a block ω gives `{:top-eu-cfg …}` ≡
  `deep{top.eu.cfg^-_ top.us.cfg^-_}` (`probe-1bvi-l`, `-m`). I had expected `top-eu-x`; the
  probe corrected it before any pin was written.

**Principles in play** (`DESIGN_PRINCIPLES.org`). *Correctness Through Types*, read as
correct by construction: the Q_U55 check and the collapse marking each have ONE seat, and
labels render what the user wrote. *Simplicity of Foundation*: one new continuation;
placement reuses dissolve. *Progressive Disclosure*: `*-` is sugar a user can unfold into `^`
and `*`, and the pins state the unfolding. *Pragmatism with Rigor*: every expected value is
measured from today's equivalent spelling, never written by hand.

**Mantra check — two columns.**

| word | catalogue | challenge |
|---|---|---|
| all-at-once | the collapse is decided once per branch, in the parser's branch walk | the per-ancestor marking is still a left-to-right pass over steps; it is a pure function of the written branch (no state), which is the most a parse-time fact can be |
| structurally emergent | placement should EMERGE from the dissolve arms the walkers already have, as C2's landings did | only if `collapsed` is read as dissolve at EVERY placement seat; the six cont readers (F6) are where it could be computed instead — C's audit re-derives them and must show no seat special-cases it |
| on-network | — | path selection elaborates off-network (recursive typing/reduction walkers); 1b-vi neither worsens nor retires that. The PPN series owns the migration; named here as standing scaffolding, not rationalized |

**Drift risks, named before code.**

- **DR-1 twin asymmetry.** Typing and reduction differ in arm order and guards (C2's
  `two{a.{x y}*}` panic). Every C/D edit is mutation-tested per twin.
- **DR-2 silent classification.** A seat answering `#f` / `'flatten` for an unknown cont: the
  six `select-star-cont` readers, `select-step-cont`'s `[else #f]`, `select-step-output-name`.
  The totality dispatcher lands at C, before the cont is reachable from surface syntax.
- **DR-3 label lies.** A refusal printing a spelling the user did not write (Q_U54). Gated by
  the label rows in A's table.
- **DR-4 vacuous pins.** A row whose target equals today's reading, or a parity between two
  refusals. Gated by running A's table at stages B and D before any implementation: every
  flipping row must fail, for the pre-mint reason.
- **DR-5 scope creep.** DEFERRED 167 (in-block L1), 168 (type-territory messages), 145 (the
  caret family's missing table) are out of scope.
- **DR-6 battery headroom.** `test-path-selection.rkt` ran 92–176 s in the last six records
  (sharded, `tools/suite-plan.rkt:121`). A adds batched sources only, never one
  `process-file` per row.

**Mini-audit for 1b-vi-A** (at `a2c78df3`).

| what | where | consequence for A |
|---|---|---|
| level-3 raw runner | `run-ws-raw`, `tests/test-path-selection.rkt:97` | reuse it; A adds no temp-file write (this branch's runners still use `'replace`, which main retired under DEFERRED 170 — the next merge from main brings that fix) |
| level-2 runner | `process-string-ws` (as `p4e1-msgs`, `:6494`) | the spellings run at both levels and must agree line for line |
| error detection | `prologos-error`, `errors.rkt:105` | a refusal is detected by struct, never by splitting on ` : ` — a message can contain ` : ` (`<(x : Nat)…>`) |
| pre-mint pins D flips | `:6194`, `:6195` (`p4e-star-type` → `'symbol`), `:8470` (the table is exactly two rows), `:8482` (`"*-"` has no sentinel) | listed in the D row below; A leaves them |
| leak-gate constraint | `reader-forms.rkt:270` | D's sentinel names must keep the `$postfix-star` prefix |

**1b-vi-A — the stage table.** One row per behaviour: `(id spelling flips-at pre target)`.
A constant `1bvi-stage` ∈ A B C D is bumped as the FIRST step of each sub-slice, which turns
exactly that sub-slice's rows red before its code exists (TDD's red step made mechanical);
controls never flip. The rows run as two batched sources (the spellings; the equivalents),
the spellings at level 2 and level 3 with a parity assertion; the batch fails closed if its
result count does not match its command count, so rows cannot silently misalign.
Retirement: at the 1b-vi close the `pre` column and `1bvi-stage` are deleted — they are
scaffolding for the slicing, not a permanent mechanism. ✅ **Retired at `3f2db4ca`**
([close-3](#p4e-1b-vi-close-3)); what the slice shipped: [§ what shipped](#p4e-1b-vi-shipped).

| sub-slice | content | status |
|---|---|---|
| **1b-vi-A** ✅ `0b6a645f` | the stage table: 40 rows, every expected value measured from today's equivalent spelling (`probe-1bvi-p`). Red step: stage B → exactly C1–C4 red (the silent drop); stage D → 37 / 40 red, each for its measured pre-mint reason (mid-lexeme 28, postfix 2, nameless unbound 3, silent drop 4); controls green. Instrument power by mutation: an already-true target caught twice; a fixture that fails to load caught before `unbound` could accept it. Battery 573 → 575; **5.28 s per run** (per-test-case timing) | ✅ |
| **1b-vi-B** ✅ `332e16a2` | `^-` / `^-k'` refuse an ancestor rename (Q_U55's caret half) with two remedies rendered by the one branch printer; FIRST step: the generated laws ([Q_U60](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u60)) — 61 rows. Red step: 16 rows (C1–C4 + 12 generated), each the silent drop; green after; mutation (check disabled) → the same 16. Instrument: right-hand sides checked at every stage (M3 caught); every live refusal's remedies RUN (B-3). Table 104 rows (43 hand, 61 law); battery + acceptance file 665 / 665; acceptance 88 / 88; **7.86 s per run** | ✅ |
| **1b-vi-C** ✅ `3cbb1025` | the total-collapse machinery, INERT — [design target, mini-audit, findings, VAG](#p4e-1b-vi-c): the star-cont axis (4 conts, raising classifier, pending table), the `(collapsed . c₀)` mark (placement only; unmark law over 104 branches), one placement predicate in both twins, `*-_`'s prefix at one seat, tail-arm guards, prose naming the operator as written (13 arms × 4 conts). Proven by INJECTION: 53 D rows meet their D targets before the mint (harness parity 0 drift; a vacuous pass found by counting and closed). Red: 51, the silent re-nesting; 5 twin mutations red. 670 / 670; acceptance 88 / 88; **7.97 s per run** | ✅ |
| **1b-vi-D-1** ✅ `b567b29e` | the LEVEL arms name the operators PRESENT ([design, findings, VAG](#p4e-1b-vi-d)): `select-fail`'s field becomes a list; `star-dup-key` carries every star at the level, `star-l4-mixed` its branch's; each claim scoped to the family it was measured on. Corrected a 1b-iv sentence measured false in 3 of 4 populations. M-one (one star) red on exactly the mixed row. Found C's ordinal-head defect. 580 / 580 | ✅ |
| **1b-vi-D-2a** ✅ `84beb15a` | [an ordinal head is TRANSPARENT under a collapse](#p4e-1b-vi-d2): `select-branch-total-collapse?` (one definition) + both twins' ord-head arms descend like the bare-number arm; the generator states `ot{0.X}` ≡ `t5{X}` over four families (+61 law rows → 168). Red: C's C-5 guard RAISED on `ot{0.a*-}`. M-ord-reduction red on exactly the 24 injectable ordinal star rows. 670 / 670 | ✅ |
| **1b-vi-D-2b** ✅ `9743e93e` | THE MINT ([design, findings, VAG](#p4e-1b-vi-d2)): the two rows join the one table (pending table retired); the parser marks at `segment-select-items`' one success return; Q_U55's star half (remedies run: 24); Q_U56's guided `*->` in the consumer (+ the one-token `a*->b`; `*>`/`*_>` improve too); pins flipped; arrival gate ∀ minted lexeme; PARITY parser = injection. Red 186; M-mark / M-star-arm / M-arrow / M-keep red. 173 rows, 670 / 670, 7.65 s per run | ✅ |
| **1b-vi-E** ✅ `a41f8362` | [Q_U61](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u61)'s S ([design, findings, VAG](#p4e-1b-vi-e)): an ordinal head passes a keyless star landing through at every depth — one predicate (`select-steps-yield-bare-join?` + `select-step-names-no-key?`), one arm per twin subsuming D-2a's arm and seat B's splice (deleted); the dup refusal names S's cost and the tuple spelling (`select-fail` field `ordinal`). 187 rows; 694 / 694; acceptance 112 / 112. Mutations: names 52, typing 11, reduction 9, ordinal 2 | ✅ |
| **verify** ✅ `0988a4f0` | [adversarial round, adjudicated](#p4e-1b-vi-verify): 4 lenses at `64368197`, 36 raw → 34 survive, 2 killed. 3 BLOCKING fixed — VF-1 a whole-file abort (ω ancestor of a total collapse; parser refusal, 167's waypoint), VF-2 a twin value/type split (reduction's `asort`), VF-3 the ordinal-level prose (E's sentence among it); VF-4/VF-5 + 9 more fixed; 2 filed (179, 180) + addenda to 167/168; Q_U62 posed. Stage V: 250 rows (106 hand, 144 law); 695 / 695; acceptance 112 / 112; 10 mutations red | ✅ |
| **gate** ✅ `83fe4fb4` | main merged in clean (`9d0dea51`; one shared file, main's 3 hunks exactly); full suite at `9d0dea51`: **10 426 / 502 files, all pass**, reconciled file by file against main's 10 394 (+8 `test-path-selection`, +24 `-acceptance` — exactly the branch's two test files); **checkpoint merge to main `83fe4fb4`**, its tree byte-identical to the gated tree; clean merge tree 697 / 697 + acceptance 112 / 112. NEXT: [Q_U62](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u62) (pending), then the 1b-vi close (the `pre` column and `1bvi-stage` retire, above) | ✅ |
| **F** ✅ `3fcb720a` | [Q_U62 = B pinned; SB-1 / SB-2 under B](#p4e-1b-vi-f): B made a contract (50 `sub-block` laws + 12 hand rows); the dup refusal stops offering `^` where an element heads several branches (it kept the BRANCHES apart, a 4-tuple) and offers grouping where it resolves; the all-ordinal L4 offers grouping where spellable; S's scope stated in Q_U61; acceptance M18. Every remedy run per family (probe-1bvi-ai). SB-4 found (pre-existing; filed with SB-3 as DEFERRED 185, main `e751736c`). | battery + acceptance **701 / 701**; `run-file --check` 116 / 116; mutations F1–F7 each red on their own rows (F6 / F7, S+ at either twin seat: 64 / 63) |
| **close-1** ✅ `a9788c0a` · `55b7df16` | [DEFERRED 185 at the close](#p4e-1b-vi-close): a star right after an ordinal head gets Q_U46's one refusal at both seats (SB-3, block band); the all-ordinal L4 offers only the remedies every passing head can spell (SB-4). Plus a buried panic found opening P4e-2 (RV-2): `ot2{2}*` printed the runtime miss as a value; a panic subject now propagates. Reader seats of SB-3 → P4e-2 (DEFERRED 185 addendum). | battery + acceptance **701 / 701**; red steps run against the OLD code (exactly the G rows); mutations G1–G4 + the panic arm each red on their own rows |
| **close-2** ✅ `04e3c5c5` | [the star family in the editor grammar, with 179 / 180](#p4e-1b-vi-close-2): `flatten_step` reads `*_` / `*-` / `*-_` as one token (DEFERRED 144); Q_U56's `*->` text reaches the closer, dot and broadcast seats from `parse-list` (179); the arrival instrument compares the lexeme (180). Ordinal-headed branches tried and NOT shipped (foray churn, DEFERRED 205). FOUND: the corpus gate has failed since `3fcb720a` (MISSING 75 > 71, M18) → owner DECIDED (a): budget 75 at `a7dcde7d`, to be lowered when 205 lands. | battery + acceptance + hygiene **702 / 702**; 60 / 60 tree tests; grammar A/B 0 better / 0 worse / 142; stage H red on the old parser; mutations M1–M4 and the 180 mutation each red on their own rows |
| **close-3** ✅ `3f2db4ca` | [the stage scaffolding retires](#p4e-1b-vi-close-3): rows become `(ID SPELLING EXPECT)`; the stage constant, the PRE / FLIPS-AT columns, the pre-mint classes and C's injection batch go; the parity pin becomes a law over its own domain (81 → 113 rows, size-pinned; held on all 32 new rows). [What 1b-vi shipped](#p4e-1b-vi-shipped). | 346 / 346 rows identical by mechanical dump; battery + acceptance + hygiene **702 / 702**; mutations: the 179 arm → exactly H-179a…h, the parser's mark → batch abort + 80 parity rows, the domain pin → exactly the domain problem |
| **close-4 · gate** ✅ `a28d648c` | [what 1b-vi shipped](#p4e-1b-vi-shipped) (the close note, `daa045c9`); main merged in (61 commits — docs, registers, the BSP-LE move's comment-path rewrites, a PAR 4 probe — no file changed on both sides; staged set = main + exactly the branch's files). Prediction written before the run: 10 431 / 502 = main's code gate (`83fe4fb4`, 10 426) + `test-path-selection` +1 + `-acceptance` +4. NEXT: the checkpoint merge to main (its hash is in the LOG; a commit cannot cite itself) | `--all --force-rerun`: **10 431 tests, 502 files, all pass** (34 s wall, 18 workers), reconciled file by file: exactly the two predicted files differ; battery 702 / 702; `run-file --check` 116 / 116; corpus gate PASS (missing 75 ≤ 75); `.zo` fingerprints of unchanged modules = main's |
| **checkpoint** ✅ `d2ad3dad` | **the 1b-vi slice CLOSES on main.** Merged from a throwaway worktree at main (`ce489cfd`); its tree equals the gated tip's (`9f5a882e`, docs-only after the gate). Main's checkout fast-forwarded with the owner's WIP untouched; DEFERRED citations flipped to it (`1f96d5da`); dailies `1d40da0f`. NEXT: P4e-2 (build J) | the throwaway tree: build with the limit, `.zo` = the gated tree's (reduction, parser, typing-core, unify, driver), battery 702 / 702, `run-file --check` 116 / 116; main's checkout rebuilt: the same `.zo`, battery 702 / 702 |

Per-phase completion, in order (DESIGN_METHODOLOGY Stage 4): tests → commit → this tracker
→ the track LOG (dailies: a pointer) → proceed.

**1b-vi-A — what the slice found, and its Vision Alignment Gate.**

*A third pre-mint class, and what it is not.* A star after an ω sub-block inside a block
(`cloud{regions:{host port}*-}`) does not get the mid-lexeme refusal; it gets "`*-` — `*` is
postfix; it attaches to the END of a segment", the message a SPACED star gets (audit F5,
`mn{a *- b}`). It is not a new arrival route — the arrival matrix already carries it as
`bcast-brace` (`xs:{a}%S%`, `tools/star-arrival-matrix.rkt:53`, a `}` closer Q_U35 calls usable).
Before the mint the closer-adjacent band leaves `*-` a plain symbol, and inside an enclosing
block that symbol is an ITEM, so it meets the payload's stray-star refusal instead of the
top-level nameless lookup (`env{prod dev}*-` → "Unbound variable"). One unminted token, two
consumers, two messages. The E4 rows pin it; D's mint must reach it (the matrix will show it).

*A cost attribution withdrawn.* A whole-file comparison (92.1 s → 100.3 s summed shards) first read
as "+8.3 s from the table". After folding the table into one test-case the rerun read 100.2 s, so
that number was machine load, not the table. Measured per test-case instead: 5.28 s per run.

| VAG question | catalogue | challenge — could it be more aligned? |
|---|---|---|
| (a) on-network | not applicable: a test-only slice | the table pins SURFACE meaning only, independent of where elaboration runs, so a later on-network migration (PPN) can keep it unchanged — this is a reason to keep pins at the surface, and it held |
| (b) complete | 40 rows: E1–E10 × 2, depth, vectors, sub-blocks, both ω positions, path position, the hyphen clash, both Q_U55 families, both Q_U56 territories, controls | **two gaps, assigned rather than hidden.** (1) The rows reach at most 3 of the 15 `star-*` prose arms (content-collision, synth-vector-contents, dup-key); 1b-vi-C owns the other 12, through a render loop over kind × cont, since no surface row reaches most of them. (2) The echo and quote lowerings (`macros.rkt`, Q_U54's site list) are not pinned for `*-` by any row; 1b-vi-D's mini-audit must check whether the table-driven pins (C-8, C-11) already cover them |
| (c) vision-advancing | the semantics is stated as executable equivalences — progressive disclosure made checkable | **the equivalences are 31 examples, not a law.** A generator could build, for any well-formed branch, its `^`-on-every-ancestor and `^-_`-enumeration spellings and assert `*-` / `*-_` against them over many branches. That states Q_U48 / Q_U57 as properties. Not built here (outside the decided slicing); offered to the owner at the checkpoint |
| (d) drift risks | DR-3 label rows present (E4-, E8_, E10-, X-omega-, X-wpath-); DR-4 shown non-vacuous (stage D 37/37, mutations M1/M2); DR-6 measured | **the inherited pattern challenged: the parked-comment idiom** (`:7793`, `:8822`), replaced by executed targets; its known failure (an unreadable parked pin) cannot recur here. DR-6 did materialize (5.28 s per run, about 7 % of a single-process battery run); bounded, not removed |

**1b-vi-B — design target and mini-audit** (at `22994c62`).

*Design reference.* [Q_U55](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u55) (refuse a rename on an ancestor of `^-` / `^-k'`; dissolve
legal; `^-_` keeps the rename), [Q_U60](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u60) (the laws land first). *Principles:* correct by
construction (one syntactic seat, branch-local — the same scope as provenance, `probe-1bvi-k`);
one rendering authority (Q_U54: the message's remedies are rendered by `pp-select-branch`, never
spelled by hand in the parser). *Mantra:* the check is a pure function of one written branch,
decided once at block close; nothing downstream infers it.

*Drift risks for B.* **B-1 over-refusal** — the dissolve-only, `^-_` and no-ancestor cases must
stay legal: the generated controls (7 per family) and K1–K3 guard it. **B-2 a shape test instead
of the classifier** — classify with `select-step-kind` and see through ω (`bcast`), as
`branch-problem`'s P4a / P4c-3 notes require. **B-3 advice that does not work** (P3b verify
finding 8's class) — the table runs every remedy the message offers and asserts it is
accepted. **B-4 scope** — the star half (`*-`, row C5) waits for D; the check is written so the
star leaf is one more arm.

| what | where | consequence |
|---|---|---|
| the seat | `branch-problem`, `parser.rkt:1374`, run over every branch at block close (`:1440`) | add the Q_U55 check after the positional check, so a mid-path `^-` keeps its own message |
| the collapse conts | `syntax.rkt:863–865`: `'collapse`, `(collapse-rename . k')`, `'collapse-synth` | TOTAL = the first two; `select-cont-collapse?` (`:1375`) also answers #t for `'collapse-synth`, so it is NOT the predicate to reuse |
| the renderer | `pp-select-branch`, `pretty-print.rkt:135` | a new require edge `parser.rkt → pretty-print.rkt`: no cycle either way (text closure over the repo's requires, controls `syntax.rkt` / `macros.rkt` / `reader-forms.rkt` reached), and it adds 6 modules to the parser's compile closure (`pretty-print`, `posit-impl`, `processes`, `rrb`, `tabling`, `union-find`) |
| scope of a branch | a sub-block is its own branch list (`sub?` recursion) | `e3{a^p.{b.c^-}}` is NOT refused — the collapse lands under `p`, where the rename is observable |

**1b-vi-B — what the slice found, and its Vision Alignment Gate.**

*The A table had a hole of its own.* A row ahead of the stage was asserted only to FAIL its
target, and a target whose right-hand side is refused, or whose pinned type drifted, fails too.
So the 31 pinned types A committed were checked only in the stage-D red runs, never on the
committed stage. Every right-hand side is now checked at every stage (mutation M3, a drifted
type on a not-yet-live row, is caught).

*An ω leaf is reachable; an ω ancestor is not.* `org{db^p.admins:name^-}` (probe s) is refused
and both its remedies run (row C6). An ω step as an ANCESTOR cannot be spelled in a block
(DEFERRED 167), so the remedy's ancestor-side ω arms are unpinned and marked so in the code.

| VAG question | catalogue | challenge — could it be more aligned? |
|---|---|---|
| (a) on-network | a pure function of one written branch, decided once at block close | parse-time validation runs before any network exists; it is part of the parser's off-network scaffolding, which the PPN series owns. B adds no state and no pass. Named, not rationalized |
| (b) complete | both total forms, several renames at once, the ω leaf (C6), the sub-block scope (K4/K5), every remedy run | (1) the ω-ANCESTOR remedy arms are unreachable and unpinned until DEFERRED 167 lands — stated in the code. (2) The remedies are rendered through the caret printer's `cont->string`, which has no table and a silent `[else "^?"]` (DEFERRED 145); B adds no caret cont, so nothing renders `^?` today |
| (c) vision-advancing | the silent drop is gone; the remedies are generated from the steps by the one printer | **the "keep the level" remedy IS Q_U55 option C's meaning** ("collapse all but the named levels") spelled out. The refusal therefore carries its own migration path: if C is ever adopted, the refused spelling takes the meaning the message already shows. That is §3.6's monotone migration made visible to the user |
| (d) drift risks | B-1: 14 generated controls + K1–K5 hold; B-2: classified through `select-step-kind`, ω seen through; B-3: 17 live refusals, 34 remedies, all accepted; B-4: the star arm waits for D | **inherited pattern challenged: hand-built remedy strings in the parser** (the `^..` messages spell their remedies by hand) — B renders through `pp-select-branch` instead. DR-6 grew 5.28 → 7.86 s per run. The tree-sitter tripwire fired on `parser.rkt`; B adds no syntax (it refuses a combination the grammar already accepts), so no grammar change is owed. `update-deps --check`: 375 mismatches before and after on this branch's stale stored graph — untouched, retired by the next merge from main |

<a id="p4e-1b-vi-c"></a>

**1b-vi-C — design target and mini-audit** (at `bebb8f4b`). Everything below lands INERT: no
lexeme mints a total star until D, and the one production call to the mark is D's. Measured
first: `probe-1bvi-t` (an ω ancestor), the walker routes read at `typing-core.rkt:2087–2237`
and `reduction.rkt:2209–2404`, and the census `research/P4e-1b-vi/census-1bvi-C.py` (56 reads
in 24 functions, five positive controls; its first cut attributed by indentation and charged
typing's dissolve arm to `walk-to-leaf` — the control caught it, the second cut matches parens).

*The design, as six pieces.*

- **C-1 the star-cont axis.** Four conts, a product {flatten, collapse} × {plain, synth}:
  `flatten` `*`, `flatten-synth` `*_`, `flatten-collapse` `*-`, `flatten-collapse-synth` `*-_`
  (named in spelling order). Classified by `select-star-cont-synth?` / `select-star-cont-total?`,
  which RAISE on any other value; built by `select-star-cont-of`. The two new rows sit in
  `postfix-star-pending-table` (`reader-forms.rkt`, the same `(SENTINEL CONT LEXEME)` shape),
  consulted ONLY by the printer's cont→lexeme direction; the reader, parser, macros, the leak
  and arrival gates and `tools/form-deps.rkt` keep iterating the minted table untouched. D
  moves the two rows across — literally D's "two table rows". *Measured before choosing:* a
  MINTED column on the one table was the first design, and eight consumers iterate that table
  directly (`tests/…:6218`, `:6259`, `:6271`, `:8470`, `:8495`, `:9287`, `:9297`, `:9317`, and
  `tools/form-deps.rkt:60`), so C would have edited every gate D is already scheduled to flip.
  Each spelling↔cont pair is still stated exactly once; a C pin holds the two lists disjoint.
- **C-2 the mark.** A marked ancestor carries `(collapsed . c₀)`, where c₀ is the cont the
  user WROTE: `#f` for a plain key (`a` → `(@key a (collapsed . #f))`), `dissolve` for `a^`,
  `(rename . k)` for `a^k` (reachable under `*-_` only; Q_U55 refuses it under `*-`). An ω
  ancestor marks its inner step (probe t: the lift consults the inner cont, `cfg^` is honoured
  per element). Ordinals make no layer and stay unmarked. `select-branch-mark-total-collapse`
  marks s₁…sₙ₋₁ iff the branch ends in a total star and otherwise returns the branch itself
  (`eq?`). **The mark changes PLACEMENT only**: printing and naming read the step as written
  (`select-step-unmark`), so `pp-select-branch` of a marked branch is the user's spelling and
  `select-step-output-name` of a marked step is the written step's — by construction, not by
  a parallel arm per reader.
  *Representation, decided inside M (Q_U58) and recorded rather than posed:* the wrapper
  (R2) over two new atoms `'collapsed` / `(collapsed-rename . k)` (R1). R1 needs a printer
  literal and a naming arm per atom in a caret vocabulary that has no table (DEFERRED 145),
  and `collapsed-rename` would sit one letter from `collapse-rename` (the `^-k'` leaf). R2
  routes every non-placement reader through the written step.
- **C-3 placement.** One predicate, `select-cont-dissolves-level?` (dissolve or collapsed),
  at both twins' dissolve arms. Then placement EMERGES, as M predicted: each marked ancestor
  takes the dissolve arm, `seen` collects it, and `(sₙ ★)` reaches `star-branch-entries` /
  `star-entries` — the remainder-empty landing that `s₁^.….sₙ₋₁^.sₙ*` takes today.
- **C-4 the provenance prefix (P).** `select-star-provenance-prefix` (syntax.rkt, ONE seat):
  for a total synth star, the joined output names of `seen`; otherwise `#f`. Both twins prefix
  the deleted layer's content keys with it before the synth join — typing over symbols,
  reduction over `expr-keyword` names (each layer adapts its own key shape, as `synth-champ-key`
  already does). `seen` is branch-local (a sub-block resets it), which is Q_U57's scope.
- **C-5 the tail-arm guards.** A total star at `select-below-field`'s or `below-value`'s
  star-TAIL arm means an ancestor was KEPT — never marked. Both twins refuse loudly instead of
  computing `*`'s re-nesting, which would be a silent wrong answer (DR-2).
- **C-6 the prose.** `select-fail` gains an optional fifth field, the star cont (a defaulting
  constructor: the 26 producers and 24 test uses are untouched). The two seats that build star
  failure closures pass it. The 13 per-branch star arms render the operator AS WRITTEN and its
  in-family siblings (`*-_`'s "use bare" names `*-`, E8_) through the printer; a missing cont
  renders LOUDLY. The 2 level arms (`star-dup-key`, `star-l4-mixed`) do not know which star
  they describe and keep family-generic wording, checked for truth under the total family.
  Reduction's 3 internal `oops` strings name the lexeme. ⚠ **Production-visible, deliberately:**
  `*_` users now read `*_` (not `*`) in the shared arms — the established rule "name the
  operator the user wrote" applied uniformly instead of special-cased for `*_`.

*Moved to D, where red rows drive them:* the parser's call to the mark at
`segment-select-items`' success return (`parser.rkt:1546`, after every parser check, so no check
ever sees a mark; sub-blocks recurse through the same return); Q_U55's star arm (C5, E5-, the
renamed `*-` law rows); the `*->` message; moving the two pending rows into the minted table.

*How an inert slice is tested — injection.* Production parsing of each D row's `*` spelling
(`ws-string->surfs`, measured shapes: one `surf-select` per row, the closer seat a `'path`
select over the block select) → every star cont converted to its total sibling → every branch
list marked at every level (what D's parser will do) → `process-command` → the row's D TARGET.
Excluded: rows whose target is a parser refusal. At D the check becomes a parity pin: the
parser's own surf must EQUAL the injected one. Stage: `1bvi-stage` → C as the first edit after
the vocabulary exists, so the red is the walkers' and not an unbound identifier.

*The mini-audit — every reader a mark or a new star cont can meet* (census lines at `bebb8f4b`).

| site | reads | decision |
|---|---|---|
| typing `select-branch-entries` (dissolve `:2183`; labels `:2178`, `:2194`) | placement | the predicate (C-3). A mark never reaches the label arms — the dissolve arm is first; mutation M-typing proves the arm is load-bearing |
| reduction `branch-entries` (dissolve `:2375`; labels `:2370`, `:2378`) | the twin | the same predicate; mutation M-reduction |
| syntax `select-step-output-name` (`:1424–1427`) | naming | a marked step names as its written step (C-2) |
| pretty-print `cont->string` (`:139–147`) | printing | a mark renders its written cont (`""` for a plain key); the `[else "^?"]` tail stays (DEFERRED 145) |
| syntax `select-branch-collapse`, `select-branch-keyless?`; parser `dissolve-step?` | leaf classifiers | a mark is never on a leaf — the leaf of a marked branch is the star. No change |
| syntax `select-branch-top-keys` (`:1563–1620`) | level keys | its star shield (`:1560`) answers first, and marks exist only in star branches. No change |
| parser `caret-position-problem`, B's helpers, `split-caret-lexeme`, `segment-select-items` | validation, minting | all run before the success return where D marks. No change |
| typing `join-contents` (`:1766`, `:1784`), `star-join-type` (`:1850`); reduction `star-join-value` (`:1895`, `:1902`) | star cont | the classifier (C-1), raising on an unknown cont |
| pretty-print `step->string` (`:197`) | star cont | already table-driven, with a loud tell for an unknown cont |
| typing `select-below-field` / reduction `below-value` star-tail arms | star cont | the guards (C-5) |
| typing `select-bcast-lift`, reduction `bcast-lift` | an ω inner | apply the inner per element through the branch walk, so the predicate places a marked inner; unpinnable until DEFERRED 167 |
| elaborator, zonk, substitution, `pnet-serialize` | — | zero cont reads (census); the mark rides as data |

*Drift risks specific to C.* **C-R1** twin placement (DR-1): a mutation per twin. **C-R2** the
prefix computed twice: one seat. **C-R3** a production-visible change inside an inert slice: the
`*_` wording, listed and pinned. **C-R4** the injection drifting from what D's parser builds:
pinned at D by surf equality.

**1b-vi-C — what the slice found, and its Vision Alignment Gate** (`3cbb1025`).

*M's prediction held when run.* Placement EMERGED: one predicate, `select-cont-dissolves-level?`,
at the two dissolve arms, and no walker computes the collapse. The red step measured the
alternative exactly: with the walkers untouched, a marked ancestor took the kept-key arm and
re-nested (E2- answered `{:server {:cert … :enabled …}}`), 51 problems, none loud.

*The injection route, and the hole I found in it.* 53 D rows (29 hand, 24 law) meet their D
targets before anything is minted. The harness mirrors `process-string-ws` and is checked
rather than trusted: with the identity transform it reproduces level 2 line for line (0 drift).
Counting the injected rows exposed **X-type passing vacuously**. Its `*` spelling is a parse
refusal ("`*` needs a SPACE"), the harness passed it through untransformed, and it matched the
`*-` target's regex. The lexeme rows (X-arrow, X-type) are now excluded by name, and any other
row that does not parse to a select reads `VACUOUS`, which no target accepts. Proved by putting
X-type back: exactly that one problem.

*Mutations, one seat in one twin each — all red:* M-typing (the C-5 guard raises — the twin
drift was converted into a loud failure by the guard written for it), M-reduction 38,
M-prefix-typing 19, M-prefix-reduction 18, M-guard-typing (the C-5 pin). **My first
M-prefix-typing was malformed** (one `)` too many): a read error, so it proved nothing; redone.

*Two more of my own slips, both caught by gates.* (1) The render loop's inherited "must mention
`*`" check failed for a missing cont — a test defect, caught by the battery and NOT by my
scratch, because the scratch ran only the 1b-vi section and that loop lives in 1b-iii's. A
section scratch is not the battery. (2) A harness edit left an extra `)`; `check-parens` said
so, my command did not stop on it, and the first non-vacuity probe ran against a file that
did not compile. Rerun after the fix.

*Design changed during C, by measurement:* the MINTED column became a pending table — eight
consumers iterate the minted table directly (C-1).

| VAG question | catalogue | challenge — could it be more aligned? |
|---|---|---|
| (a) on-network | no new state: the mark, the classifier and the prefix are pure functions of a written branch | the mark is a parse-time annotation on IR the off-network walkers read; that scaffolding is the PPN series' to retire, and C neither worsens nor retires it |
| (b) complete | 4 conts classified at every reader (raise off-axis); 13 per-branch arms × 4 conts + the missing cont pinned; marks proven never to reach a non-placement arm (M-typing / M-reduction); every reader in the census decided | (1) the ω-ANCESTOR mark is unpinnable until DEFERRED 167. (2) The two level arms stay family-generic: a `*-` user in a level collision still reads "a `*` LIFTED". (3) **No `(@ord N)`-headed `*-` / `*-_` row exists**: that head arm resets `seen` and enters through `select-below-field`, a route the 53 rows never take — D adds the row, with a top-level-vector fixture |
| (c) vision-advancing | placement emerges from existing arms; labels and provenance keys are true by construction (unmark law over 104 branches); the prose reads the operator from data, not from guesses per arm | the injection harness MIRRORS driver internals — a second copy of `process-string-ws`'s scoping. Mitigated by the parity check; retired in substance at D, where the parser's own surf must equal the injected one |
| (d) drift risks | C-R1 mutations ✓; C-R2 one seat, both calls mutated ✓; C-R3 the `*_` wording (no pin asserted the old text — a fixed-string grep with a positive control); C-R4 → D | DR-6: 7.86 → 7.97 s per run, within the variance measured at A — no cost claimed. **The tree-sitter tripwire fired on `reader-forms.rkt`; C mints nothing**, but `flatten_step` is `token.immediate('*')` only (`editors/tree-sitter-prologos/grammar.js:1158`), so D owes `*-` / `*-_` to the grammar or a DEFERRED entry. `update-deps --check`: 375 before and after |

**What C hands D** (D's red rows drive each): call `select-branch-mark-total-collapse` at
`segment-select-items`' success return; Q_U55's star arm — and its "keep the level" remedy must
NOT dissolve sₙ (`t5{a.b^q.c*-}` → `a^.b^q.c*`, not `c^*`; B's `keep-level` would, and B-3's
remedy run will catch it); move the two pending rows; the `*->` message; the four pre-mint pin
flips; the grammar; the parser-surf = injected-surf parity pin; the `(@ord N)`-headed row.

<a id="p4e-1b-vi-d"></a>

**1b-vi-D — design target and mini-audit** (at `97d1f016`). Owner, at the C checkpoint: *"Ok to
proceed (and would you think that passing the star through is our better option? If it doesn't
cost us too much, it would seem to be more correct/accurate to me — do you have a challenge to
that perspective?)"*. D runs in two steps.

*D-1 — the level arms name the operators PRESENT, with each claim scoped to its family.*
Measured before deciding (`probe-1bvi-u`, `-v`): `star-dup-key`'s sentence "dropping the `*`
does not help either" is TRUE for `*` (`env{prod^.db dev^.db}` still collides, on `:db`) and
FALSE for `*-` (`env{prod.db dev.db}` works) — and the level collision is the total family's
characteristic failure (E3-). The challenge I put to "pass the star through": a LEVEL has no
single star. One block can mix families (`env{prod^.db* dev.db*-}`), and the dup gate folds
over component keys with no record of which branch delivered one, so passing ONE cont would
make the message name one operator confidently — wrong in a mixed block, which is the
"identifies the wrong thing" class this track ranks below a vague label. So: `select-fail`'s
fifth field becomes a LIST of conts (`stars`; per-branch arms carry exactly one); `star-l4-mixed`
carries the conts of the branch its label names; `star-dup-key` carries every star cont at the
level (`select-branch-star-conts/deep`, the ω-transparent, sub-recursive twin of
`select-branch-has-star?/deep`). The advice, measured across the population (probe-1bvi-v):

| population | `*-_` | `*` | drop the star | own block |
|---|---|---|---|---|
| P1 heads differ — `env{prod.db*- dev.db*-}` | ✓ | ✓ | ✓ | ✓ |
| P2 same head — `sh{a.b*- a.c*-}` | ✓ | ✗ (`:a`) | ✗ (`:a`) | ✓ |
| P3 a `^` on the differing ancestor — `env{prod^.db*-_ dev^.db*-_}` | ✗ (`:db-url`), ✓ once the `^` is dropped | — | — | ✓ |

so the total family's sentence offers `*-_` plus "drop any `^` on the ancestor that differs",
and never "use `*`" (P1-only). ⚠ **Corrected while implementing:** this design first said "the
non-total sentence keeps its measured claim". probe-1bvi-x measured that claim — "dropping the
`*` does not help either" (1b-iv) — and it is FALSE in three of four populations: dropping ONE
star works (`env{prod^.db dev^.db*}`), dropping the star beside a NAMED key works (`kk{a k}`),
and in a mixed block dropping EITHER star works; only "drop every star, deleted keys equal"
still collides. What holds everywhere is the mechanism, so both families now say it: a dropped
star re-nests what it lifted — `*`/`*_` under the key it was deleting, a total collapse under
its whole path — which resolves the collision unless another branch delivers that key too. `star-l4-mixed`: its "a key surviving before the star keeps the join nested" clause is
scoped to `*`/`*_`; a total collapse always lands at its branch's top; examples render in the
branch's own operators; its remedies hold for `*-` (`vv{a^.b* a^}` ✓, own block ✓).

*D-2 — the mint.* Stage → D first. Then: the two pending rows move into the minted table; the
parser calls `select-branch-mark-total-collapse` at `segment-select-items`' success return;
Q_U55's star arm (its "keep the level" remedy leaves sₙ plain — `a^.b^q.c*`, not `c^*`); the
`*->` guided message (Q_U56) in the selection consumer; the pre-mint pins flip; the arrival
matrix gains `*-` / `*-_`; the tree-sitter grammar learns them (`grammar.js:1158`); the
injection becomes a PARITY pin (the parser's surf must equal the injected one).

*Tests for D-1 first, by injection* (live since C): E3- is strengthened (names `*-`, offers
`*-_`, must NOT say "does not help"); new rows P2 (`X-dup-same`), the mixed block
(`X-dup-mix`, both families named, each sentence present), L4 under `*-` (`X-l4-`), and the
`(@ord N)`-headed pair C handed over (`X-ord-`, `X-ord_`, a top-level-vector fixture). The
harness converts stars PER STAR in textual order (a mixed row must keep its `*`), and fails
closed when the spelling's star count and the surf's disagree. The render loop gains the level
kinds × {each singleton, a mixed set, none}.

*Mini-audit.* `select-fail-star` has 3 readers (typing-errors' helpers, `select-fail-fill-label`,
the render loop) and 2 producers (`star-branch-entries`, the tail arm) — all from C, all
changed together; the two level producers are `typing-core.rkt:1528`, `:1564`. No other module
reads the field.

**1b-vi-D-1 — what the step found, and its Vision Alignment Gate** (`b567b29e`).

*The answer to the owner's question, measured.* Passing the stars through IS the better option,
and the challenge sharpened it rather than refuting it: pass the operators PRESENT, not one star.
**M-one** (the dup gate passes only its first star — the "one star" design) is red on EXACTLY one
row, the mixed block `env{prod^.db* dev.db*-}`; **M-none** (no stars) is red on three (E3-,
X-dup-same, X-dup-mix). Cost: a list-valued field (one `remove-duplicates` + one collector,
`select-branch-star-conts/deep`), two producers, two arms; 580 / 580 in the file.

*Three of my own errors, each caught before commit.* (1) The design's "the non-total sentence
keeps its measured claim" — measured false (above); my first X-dup-mix row REQUIRED the false
sentence, so the test would have pinned it. (2) The first mixed L4 render said "under `*` and
`*-` a key surviving before the star keeps the join nested" — picking the clause from the first
cont and speaking it over every operator, the very error D-1 exists to remove. Caught by
READING the rendered messages, not by the regexes, which all passed; now guarded by a render-loop
check whose power was shown against the captured defective text (hits it, and nothing else).
(3) Two malformed edits (one `)` too many, in the L4 arm and in M-none): both caught by the
`check-parens` gate added after C, so neither ran.

*A defect in C, found by C's own handover row.* The `(@ord N)`-headed pair: `ov{0.a.b*-_}`
(injected) → `@[{:a-b-x 1}]`, where Q_U57's law gives `{:a-b-x 1}` (probe-1bvi-w). Three
decisions already determine the answer — Q_U48 ("the join lands … at the branch's top level")
with Q_U49's splice, Q_U57's law, and P3c's pinned reading that a collapse overrides an ordinal
head's keyless sort (`admins{0.name^-}`, `tests/test-path-selection.rkt:2188`) — so it is not
posed as a question. My C claim "ordinals make no layer and stay unmarked" was right about
marking and wrong as a description of landing: the ordinal head SETS the landing's sort, and a
total collapse must override it. C's 53 rows and the law generator (Q_U60) range over
key-headed fixtures only, which is why nothing saw it. The rows return at D-2's first red step.

| VAG question | catalogue | challenge — could it be more aligned? |
|---|---|---|
| (a) on-network | no new state: the conts are read off the written branches | the level gate still folds component keys off-network (P3c-era); D-1 neither worsens nor retires it |
| (b) complete | both level arms × every singleton, a mixed set and none (render loop); every family clause scoped (`stars-partial` / `stars-total`); the measured-false sentence and the cross-family clause are pinned ABSENT | the dup gate still cannot say WHICH branch delivered the key, so the message names the operators present, not the culprit. Naming the culprit needs the gate to keep provenance per component — a real improvement, not taken here |
| (c) vision-advancing | the message is computed from the same data the walkers read; claims are emitted only for the family they were measured on | the two families' sentences are hand-scoped prose. A message generated from the landing rule itself (one rule → its sentence) would make "true by construction" literal; today it is true by measurement |
| (d) drift risks | M-one / M-none red; the false-sentence check and the cross-family check both have shown power | the ordinal-head defect shows the law generator's fixture set is a blind spot: D-2 adds an ordinal-headed fixture to the GENERATOR, not only two hand rows |

<a id="p4e-1b-vi-d2"></a>

**1b-vi-D-2 — design target and mini-audit** (at `5605ee65`). Owner: *"Excellent, let's proceed
to D-2 per our stage 4 design methodology"*. Two sub-steps, each committed on its own: **D-2a**
fixes the ordinal head while the machinery is still inert (stage stays C, proven by injection);
**D-2b** is the mint (stage → D, the parser builds what the injection built).

*D-2a — under a collapse, an ordinal head is TRANSPARENT.* Measured at HEAD (probe-1bvi-z,
`ot := @[t5's value]`): the caret collapse already behaves so — `ot{0.a.b.c^-}`, `^-_`, and two
collapse branches sharing one ordinal head (`ot{0.a.b.c.m^- 0.a.b.c.n^-}`) give `t5`'s own lines.
That is P3c's pinned reading, and it is what Q_U48 ("lands at the branch's top level") and Q_U57's
law require of the star family. The seat: both twins' `(@ord N)` head arms
(`typing-core.rkt:2156`, `reduction.rkt:2365`) wrap whatever the rest returns as ONE keyless
component; the caret family never reaches them (the collapse arm is first — P3c's "collapse-first
classification"), a total star branch does (it is deep, so it falls through). **The fix**: in each
ord-head arm, a branch ending in a TOTAL star descends transparently — exactly the sibling
bare-number arm's behaviour (`:2181`, `:2379`), passing `seen` unchanged (an ordinal is nameless:
Q_U57's prefix rule). One predicate, `select-branch-total-collapse?` (syntax.rkt), shared with
`select-branch-mark-total-collapse`, so "total" has one definition. **The law** replaces the two
hand rows C handed over: the generator gains `ot` (four families × every position × every
{kept, `^`, rename} assignment) and `ov3` (`*-`), each row an `equiv` with the BASE subject's law
— `ot{0.X}` ≡ `t5{X}`'s equivalent, `ov3{0.a.b.c*-}` ≡ `v3{a^.b^.c*}`. The caret rows are live now
(controls of P3c's reading at every position); the star rows run by injection. *Not changed:*
plain `*` under an ordinal head — `ot{0.a*}` → `{:b …}` (unwrapped) but `ot{0.a^.b*}` →
`@[{:c …}]` (wrapped) is 1b-iv's seat-B behaviour, recorded as an observation, not touched here.

*D-2b — the mint.* Stage → D first (every D row now runs through the PARSER). Then:
1. **Reader**: the two pending rows join `postfix-star-sentinel-table`; the pending table is
   RETIRED (empty scaffolding is a dead path), and the printer reads the one table again.
2. **Parser mark**: `segment-select-items`' success return marks each branch
   (`parser.rkt:1546`), after every check — sub-blocks are marked where they are segmented.
3. **Q_U55's star arm** (C5, E5-, the generated `*-` rename rows): `total-collapse-leaf?` gains
   the `*-` leaf (not `*-_`: it keeps the rename). Message: the leaf is rendered as `sₙ*-`
   ("lifts what `ssl` holds to the top of its branch"); the remedies: drop → every ancestor
   rename removed; keep → `keep-level` over s₁…sₙ₋₁ only, sₙ stays plain, `*-` → `*`
   (`t5{a.b^q.c*-}` → `a^.b^q.c*`, never `c^*`). B-3's runner runs both.
4. **`*->`** (Q_U56): probed after the mint, then a guided refusal in the SELECTION consumer
   ("`*->` reads as `*-` then `>` — put a space"), never at the reader.
5. **Pins**: `:6202`, `:6203` → `postfix-star`; `:8516` (the table is FOUR rows); `:8530` (`*-` →
   its sentinel); C's pending pin (`:10004`) → the table holds the whole axis.
6. **Arrival**: the gate at `:6972` runs for `*` only; it becomes ∀ table lexeme, so every future
   mint is checked by construction (the matrix's 209/209 per spelling becomes a pin, not a run).
7. **Parity**: at stage D, each injected row's surf must EQUAL the parser's surf of the `*-`
   spelling (srclocs aside) — the injection harness stops being a mirror we trust.
8. **Grammar: none owed.** [DEFERRED 144](../../../../DEFERRED.md) already files `flatten_step` for the whole
   family (`*_`, `*-`, `*-_`) to CIU T6's close. ⚠ My C VAG said "D owes `*-`/`*-_` to the grammar
   or a DEFERRED entry" — it missed 144, filed at 1b-v-B2b with 1b-vi named.

*Mini-audit.* Readers of the minted table: reader-forms (4 functions), `tools/form-deps.rkt:60`,
and 8 test sites — all iterate it, so they widen by construction (C-1's reason for the pending
table); the leak gates match the `$postfix-star` prefix, which both new sentinels keep. The
classifier raises off the axis, so a 5th cont cannot slip in. The ord-head arms: 2 (one per
twin), no third walker has one (`select-branch-top-keys` treats star branches as typing's, per
Q_U43). *Drift risks:* **D2-R1** twin asymmetry at the ord arm → a mutation per twin; **D2-R2** the
parser mark diverging from the injection → the parity pin; **D2-R3** an arrival context that
mints `*` but not `*-` → the widened gate; **D2-R4** a remedy that does not run → B-3.

**1b-vi-D-2a — what the step found** (`84beb15a`). *The red step was LOUD, and that is C's guard
earning its keep:* `ot{0.a*-}` puts sₙ directly after the ordinal head, so the head arm handed
`(a ★-)` to `select-below-field`, whose star-TAIL arm found a total star with a kept ancestor and
raised C-5's invariant error — a guard written for "the mark did not run" caught a case my C
design said could not arise. It is still a defect: a typing raise aborts the whole file in
production. *Power:* M-ord-reduction is red on exactly the 24 injectable ordinal star rows (`ot`
7 `*-` + 13 `*-_`, `ov3` 4); M-ord-typing raises. *The law is stronger than the two rows it
replaces:* the caret families' 26 `ot` rows pin P3c's reading at every position and assignment,
where one test (`admins{0.name^-}`) pinned it before. *Observation, not changed:* plain `*` under
an ordinal head lands unwrapped at depth 1 (`ot{0.a*}` → `{:b …}`, 1b-iv's seat B) but wrapped
below a dissolve (`ot{0.a^.b*}` → `@[{:c …}]`); whether that asymmetry is intended is a 1b-iv
question, raised at the checkpoint rather than changed inside a total-collapse slice.

**1b-vi-D-2b — what the mint found, and the Vision Alignment Gate** (`9743e93e`).

*The injection was a faithful mirror — now measured, not trusted.* PARITY holds for every
injectable row: the parser's surf equals C's hand-built IR, marks included. Its power: with the
parser's mark call removed, 68 rows differ (12 have no ancestor to mark, so they cannot).

*A prediction refuted, honestly marked as one.* Q_U56 predicted that `<(x : Nat)*- Nat>` would
get Q_U31's "needs a SPACE"; the row was written from that prediction. Measured: the refusal is
Q_U37's as predicted, but the message is the star-family one 1b-v built (it reads the table) —
true and more specific. The row now pins the measurement.

*Q_U56's text, re-derived from what the consumer can see.* `a*-> b` and `a*- > b` reach the
consumer as the same items, so a message about "glued" must be true of both; the illustrative
"put a space" is not a remedy (`x{a*- > b}` still fails), so the message offers the one that runs
(drop the `>`; X-arrow-fix pins it). A third shape surfaced: `a*->b` is ONE token (`->`
continues an identifier, as in `int->string`) and arrives at the mid-lexeme message — which
would have been false had it said "reads as `*-` then `>`" (X-arrow1 pins its absence).

*M-mark is the sharpest finding of the slice.* Without the parser's mark, a minted `*-` does not
silently re-nest — C-5's guard RAISES, and both batches report a whole-file abort. The guard
converted a silent wrong answer into a loud one, as designed; but its loud form in typing is a
plain `error`, i.e. an abort, not a counted refusal. That is the codebase's convention for
internal invariants (`select-step-kind-unhandled`), and it is unreachable while the mark is
pinned — recorded, not changed.

| VAG question | catalogue | challenge — could it be more aligned? |
|---|---|---|
| (a) on-network | no new state: one table row pair, one pure mark call, two parser arms | the mark is computed in the parser and read by off-network walkers — PPN's to retire; the mint neither worsens nor retires it |
| (b) complete | ∀ minted lexeme × every arrival context (was `*` only); 173 rows incl. 61 ordinal law rows; every live refusal's remedies run (24); parity for every injectable row; the four operators' `>` shapes | the arrival gate covers the TOKEN; whether `*-` behaves in every arrival context (closer band, ω path, in-block, dot) is covered by the rows that exist (E10, X-wpath, X-dot, X-sub) — not by a context × operator generator. A semantic arrival matrix would make it complete by construction |
| (c) vision-advancing | the mint is a TABLE MOVE: nothing that iterates the table was edited, which is C-1's design claim, measured | the D4 law generator states 1b-vi's semantics; the user-facing documentation (the acceptance file, the examples) does not yet show `*-` / `*-_` at all — the 1b-vi verify should add them, so the surface a newcomer reads matches what ships |
| (d) drift risks | D2-R1 M-ord ×2 ✓; D2-R2 parity + M-mark ✓; D2-R3 arrival ∀ lexeme ✓; D2-R4 M-keep ✓ | DR-6: 7.65 s per run at 173 rows (C: 7.97 s at 109) — within variance. update-deps 375 = B's, per section. The grammar tripwire fired again; DEFERRED 144 now records the family as final |

**1b-vi verify, step 1 — the acceptance file shows what shipped** (owner: *"we should add all new
syntax developed into the acceptance file, both for demonstration of the features as well as
verification that they work"*). §M in `examples/2026-07-26-ciu-t6-path-selection.prologos`, on the
guild hall's own subjects: 20 live forms (markers 94–113) — the `*` / `*-` / `*-_` / `*_`
contrasts, Q_U48's ≡, Q_U57's prefix (renamed and dissolved ancestors), branch-locality, Q_U59
where nothing collapses, the closer seat, the dot path, ω, the ordinal head under a collapse
(new fixture `guilds := @[app-config]`), and the remedy Q_U55 offers, run. The three refusals
(Q_U55, Q_U56, L4) are COMMENTED with their measured messages — Gate 1 requires 0 errors, and each
is pinned live in the stage table. `run-file --check` 108 / 108 (was 88); the harness 110 / 110;
a corrupted marker turns exactly `[110]` red. *Two measurement slips of mine, both caught:* the
corpus check first ran on a FILE path, which the script reads as zero files and passes; re-run on
one-file directories — ERROR 31 → 37, unparsed bytes 41 → 48, 0 swallows, 0 MISSING (within the
ratchet; the six are DEFERRED 144's `}*-` gap). Plain `*` under an ordinal head is deliberately
absent from §M until [Q_U61](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u61) is decided.

<a id="p4e-1b-vi-e"></a>

**1b-vi-E — design target and mini-audit: [Q_U61](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u61)'s S** (at `de82f0b0`). Owner: *"Reading
S looks good to me."*

*The rule, stated once.* An ordinal head passes a star's landing through to the block exactly when
the landing is keyless by Q_U47 — when every step between the ordinal head and sₙ names no key.
Q_U49 then splices a Map landing there, and a vector landing is one keyless component there. A
step names no key when it makes no layer (a mid-branch ordinal, Q_U2) or dissolves its level (a
`^`, or a total-collapse mark), seen through ω.

*The seat.* `select-steps-yield-bare-join?` (syntax.rkt) already states this question for the
no-layer steps — it is how 1b-iv fixed `(0 m ★)` — and its only readers are the two ord-head
arms. It gains one step kind: a new `select-step-names-no-key?` (makes no layer OR dissolves its
level) replaces `select-step-makes-no-layer?` INSIDE it only; that predicate's four other readers
are untouched. In both twins (`typing-core.rkt:2172`, `reduction.rkt:2373`) the transparent-descent
arm D-2a added is now guarded by THIS predicate instead of `select-branch-total-collapse?` — every
total-collapse branch passes it (its ancestors are marked), so D-2a's case is subsumed, not kept
beside — and seat B's in-arm splice (`star-keyless-landing` after `select-below-field`) becomes
unreachable and is DELETED (one path, not two). The landing then comes from the same arms a
key-headed branch reaches, so `ot{0.X}` ≡ `t5{X}` holds for plain `*` wherever the remainder
names no key, by construction.

*Tests first.* `1bvi-stage` gains **E**; hand rows flip at E — `ot{0.a^.b*}` ≡ `t5{a^.b*}`,
`ot{0.a^.b^.c*}` ≡ `t5{a^.b^.c*}`, `ov3{0.a^.b^.c*}` ≡ `v3{a^.b^.c*}`, `ot2{0.a^.b* 1.a^.b*}` →
refused (dup `:k`) — and controls that must NOT move: the keyed remainder stays inside the tuple
(`ot{0.a.b*}` → `@[{:a {:c …}}]`), depth 1 is unchanged (`ot{0.a*}`, `vhm{0.{0}* 1.{0}*}`), and the
tuple stays spellable without a star (`ot2{0.a^.b^ 1.a^.b^}`). The law generator gains a `*` row
per `ot` position whose ancestors are all `^` (≡ the `t5` spelling). The 9 depth-1 pins must stay
green. *The cost S names:* the dup message must be TRUE for the ordinal population — its remedies
are run on `ot2` before it is accepted, and changed if they fail.

*Mini-audit.* Readers of `select-steps-yield-bare-join?`: 2 (both ord-head arms). Readers of
`select-branch-total-collapse?` after E: the mark only. Readers of `star-keyless-landing`: checked
at the edit — if seat B was its last caller in a twin, it goes too. *Drift risks:* **E-R1** twin
asymmetry → a mutation per twin; **E-R2** the deleted seat-B path covering a depth-1 shape the new
route does not (`vh{0.{0}*}`: sₙ is a SUB-BLOCK) → the 9 pins; **E-R3** a message whose advice fails
on the ordinal population → run it.

**1b-vi-E — what the slice found, and its Vision Alignment Gate** (`a41f8362`).

*The decision removed code.* S needed no new mechanism: the question was already asked, by
`select-steps-yield-bare-join?`, for one kind of key-less step. Widening the step kind made two
arms redundant — D-2a's total-collapse arm and 1b-iv's seat-B splice — and both are gone. The
mutations show the single arm now carries all three cases: disabling the predicate's new half reds
52 rows including every ordinal `*-` / `*-_` law (D-2a's case), and disabling typing's arm reds the
depth-1 controls (seat B's case).

*S's cost was real, and the message now names it.* `ot2{0.a^.b* 1.a^.b*}` changed from a 2-tuple to
a refusal. Running every remedy the refusal offered (probe-1bvi-ad) showed the generic text held
but told the user neither why two positions met nor how to get the tuple; dropping ONE star traded
the collision for an L4 mix. The fix needed a fact only the dup gate has (the branches), passed the
way C passed the stars: a defaulting field.

*My one slip:* the two message rows' regexes were lower-case where the sentences start upper-case —
red for the wrong reason on the first green run; read, not re-run, and fixed in the tests.

| VAG question | catalogue | challenge — could it be more aligned? |
|---|---|---|
| (a) on-network | no new state; one predicate widened, two arms deleted | as before: the walkers are off-network (PPN's); E neither worsens nor retires it |
| (b) complete | the generator states S at every all-`^` position (`ot`, `ov3`); 6 controls pin what must not move; 4 mutations red | an ω step between the ordinal and sₙ (`ot{0.xs:k^.b*}`-shaped) is covered by the predicate (it sees through ω) but no row reaches it — DEFERRED 167's in-block ω limits apply; noted, not pinned |
| (c) vision-advancing | one rule at an ordinal head for `*`, `*-` and `^-`: a keyless landing passes through; Q_U48's `*-` ≡ "`^` on every key ancestor, then `*`" now holds there too (both sides pinned against `t5`) | §3.3's honest nesting now yields wherever a star's landing is keyless — the documented price of S. The positional-provenance gap (`*-_` cannot tell elements apart) is named in the message; whether ordinals should contribute to a prefix is a separate question, not posed here |
| (d) drift risks | E-R1 twin mutations ✓; E-R2 the 9 depth-1 pins green through the route change ✓; E-R3 every remedy run, message fixed ✓ | update-deps 375 unchanged; acceptance M16/M17 show both sides of the rule on the guild hall |

<a id="p4e-1b-v-shipped"></a>

<a id="p4e-1b-vi-verify"></a>

**1b-vi verify, step 2 — the adversarial verify, adjudicated** (lenses at `64368197`; fixes
`0988a4f0`; probes `tracks/CIU/CIU_6/research/P4e-1b-vi/verify/` v1–v8, each with its HEAD
`.out` and its post-fix `.after.out`).

*Method.* Four read-only lenses, each a Hermes subagent pinned to `643681972acc` (each
verified it) and probing through `tools/scratch-run.sh` in its own scratch directory: **VT**
twins and routes (the standing question head-on), **VS** silent wrong answers and branch
order, **VM** message truth with every offered remedy run, **VI** instrument power. (The
`.claude/workflows` runners are a Claude Code tool; this is the same shape — parallel
read-only facets, then adjudication on the main thread.) The lenses numbered their findings
L1-…L4-; renamed here because "L1" (fusion) and "L4" (the mixing rule) are this document's
own designators. **Every finding was re-measured on the main thread before anything acted on
it**: 36 raw, 34 reproduce, 2 killed on adjudication.

*The standing question — one seat, not its sibling — YES, five times.* (1) The ω arms are a
second route to the star-tail arm, so the C-5 guard's premise ("arriving here means an
ancestor was kept") was false on it, beside three comments calling the shape unreachable.
(2) 1b-iv-B2 threaded `asort` into three reduction helpers; five siblings kept reading the
outer sort — the comment naming that fix says "the feed was threaded". (3) E's ordinal fact
read the branch head; a dissolved head or a terminal sub-block delivers the same fields by
another route. (4) The dup gate got E's ordinal fact and the L4 gate beside it did not.
(5) Q_U56's one-token arm covered one lexeme of the four-row star table; its item-shape
sibling iterates all four.

| id | severity (lenses) | measured at `64368197` | disposition |
|---|---|---|---|
| **VF-1** | BLOCKING (VT-1 = VS-1 = VI-1, independently) | `ow{top:cfg.x*-}` **aborts the whole file** — no result line, not even the `def`s (v1). Every sibling spelling is a per-command refusal (DEFERRED 167: a step after an in-block ω acts on the whole result; v2) | `total-collapse-omega-problem` at branch close (parser.rkt), before Q_U55's check: a total collapse under an ω ANCESTOR is refused — both families, Q_U55's one rule — with the branch-local sub-block remedy rendered by the one printer (`top:{cfg.x*-}`, measured: v6). This is 167's own recommended waypoint; Q_U48's meaning of the refused form needs 167 (`top^:{…}` lands keyless — an ω result is a layer of its own) |
| **VF-2** | BLOCKING (VT-2, VS-2; VT-3 older, same class) | `vk:{a^.b*}` → `@[@[{:k 1}] @[{:k 2}]] : [PVec {:k Int}]` at 0 errors; then `none`, an internal panic beside a keyed sibling, a value that changes with branch order; `vo:{a:n}` likewise (v3) | `asort` threaded through `below-components`, `below-value`, `bcast-lift`, `bcast-apply` and `walk-to-leaf`'s ω, mirroring typing's `sort` at every seat; census: every helper call now passes a sort except Q_U20's forced `'block` and the top level |
| **VF-3** | BLOCKING (VM-1/2/3/4, VI-2/4; MINOR VT-5, VS-5, VM-11, VI-7) | at ordinal levels the gates offered remedies measured false: E's tuple remedy (a `{0}` sₙ, a keyed `^-` sibling, a third starred branch), "dropping a star resolves it", the `*-_` advice, L4's "drop a `^`" (v4); the fact read the head only | `select-level-ordinal-fact` (syntax.rkt): the branches DELIVERED to the level — through dissolves and terminal sub-blocks — classified in the twins' arm order (`'head` / `'head-wrap` / `'mid` / `#f`: a `^-` collapse lands keyed; a bare ordinal step never wraps), summarised as flags read by BOTH gates. Every sentence scoped to the population it was measured on; every remedy run (v7, v8) |
| **VF-4** | BLOCKING-contrived (VM-7) + MINOR (VS-7a, VM-8) | `m3{a*->b*->c}` offered `a*->b*- c`, refused again; `a*_->b`, `a*-_->b` got the generic text naming `*` | one-token arm: non-greedy, every star lexeme, every later arrow rewritten |
| **VF-5** | MAJOR (VT-4, VS-6, VM-6) | `t5{a.b^..c*-}` told of a rename `b^a` and to "Drop `^a`" — the desugar, not what was written | names both: `` `b^a` (how `a.b^..` is read) `` (a literal `a^.b^a` is the same steps) |
| VM-5 | MAJOR | `mx{m* a.b*-}` named `m*` and offered "drop a `^`" with no `^` present; reversed, named `a.b*-` — text depended on branch order | the L4 label names the star branch whose landing is KEYLESS (fallback: the first). 1b-iii-C2 R3's byte-identity pin (2) re-expressed on purpose; its new remedy run |
| VM-10 | MINOR | a star sealed under a kept key (`t3x{a.{b*-_} c* d*}`) was named as a possible lifter, and drew the total-collapse sentence | `select-branch-level-star-conts`: the stars whose landings reach the level |
| VT-6, VT-7, VI-8 | MINOR | stale comments after E; the skip could consume sₙ (latent); an ω unwrap with no reachable input | corrected; the skip stops above sₙ; marked unreachable until 167 |
| VI-3 | MAJOR | the render loop built every fail with five arguments — blind to the ordinal field | × the ordinal facts, with VF-3's invariants as checks (mutation VF3-prose reds them) |
| VI-5 | MAJOR | nothing pinned the table's size: a filter dropping a family stayed green | size pin, PREDICTED before the run from positions × assignments (106 hand; 144 law; `*` 22, `*-` 44, `*-_` 26, `^-` 26, `^-z` 26) |
| VI-6, VI-9 | MINOR | Q_U61's other half (a remainder naming a key stays in the tuple) held at 3 hand points; U61-5's PRE was predicted; the all-`^` plain-star laws were filed as controls | the plain-`*` law over EVERY assignment with a `wrapped` target (+18); all-`^` depth ≥ 2 flip at E with the wrap as PRE; U61-5 marked |
| VS-3 | — | `ot{0.a^.{b*}}` and `oo{0.{0.a^.b*}}` WRAP while `t5{a^.{b*}}` splices: E's "`ot{0.X}` ≡ `t5{X}` by construction" holds for step chains only | the comment corrected; posed as [Q_U62](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u62) — pre-existing behaviour, zero uses (census with a positive control) |
| VS-7b, VI-10 | MINOR | `env{prod dev}*->` gets a comparison-keyword hint; the arrival gate cannot tell a one-token `*-` from `*` then `-` | filed: DEFERRED 179, 180 |
| VM-9 | MINOR | inside `<…>` a SPACED `*-` / `*-_` / `*_` reports a bare "Unbound variable" | addendum to DEFERRED 168 |
| VI-7's M7 | — | the stage table's "every row ahead still fails" arm iterates nothing at the last stage | inherent to a stage table (the scaffolding retires at the 1b-vi close); recorded |
| ~~VS-4~~, ~~VM-12~~ | **killed** | Q_U55's remedies on `og{db^p.admins:name*-}`, and "Drop `^p`" on `sh{a^p.b*- a.c*-}`, meet a second refusal | each remedy fixes the problem its message reports; the next refusal (the permanent ω Map join; a dup the original also carries) is an independent problem the input already had — not a false remedy |

*Mutations* (`mutate-V.sh`, each restored under checksum; every one red on its own pins
only): VF1-off → the whole table fails CLOSED (the batch raises); VF2-dissolve → V-as1…7;
VF2-bcast → V-as8; VF3-head → V-or6 (the sub-block route); VF3-collapse → V-or5;
VF3-prose → U61-4/5, V-or3…6 and the render loop's invariant; L35-label → V-l4a and the R3
pin; L310-stars → V-dup-sealed; VF4-greedy → V-arrow2; VF5-dotdot → V-dotdot. One extra red
under VF3-collapse, at the Q_N4 multiplicity test (`:797`), which the mutated predicate
cannot reach: unattributed — the per-run log was deleted before it was read — and consistent
with DEFERRED 170's temp-file race, which this branch carries until main is merged in. The
post-merge full suite is the check.

*Self-correction.* E's VAG said the message "names S's cost"; it named it for the one
population probe-1bvi-ad measured. The skill rule written that same hour ("run every remedy
the refusal offers on the newly-refused population") was applied to one population, not to
the populations the flag covers. Six sentences in the two level arms were false somewhere
they were emitted.

| VAG question | catalogue | challenge — could it be more aligned? |
|---|---|---|
| (a) on-network | no new state; facts are pure functions of the branch lists | the walkers stay off-network (PPN's); VF-2 is the twin-drift class that a single on-network walker would remove by construction — evidence for that migration, not a substitute |
| (b) complete | 45 rows + 18 laws + a size pin + 10 mutations; every remedy run | the ordinal fact is CLASSIFIED by a function that must mirror the walkers' arm order (VF3-collapse shows the cost of not mirroring); it would be correct by construction if the walkers RETURNED the fact with their components — the same twin-walker drift the off-network walkers owe PPN's on-network walk; recorded as pressure on that migration, not filed separately |
| (c) vision-advancing | a crash and a silent split removed; prose true on every measured population | VF-1 is a waypoint (167), not the meaning; Q_U62 is open |
| (d) drift risks | three "unreachable"/"by construction" comments were wrong in this slice | each corrected comment now cites the probe that measured it |

<a id="p4e-1b-vi-f"></a>
##### §5.P4e-1b-vi-F — Q_U62 = B PINNED; SB-1 / SB-2 UNDER B  (`3fcb720a`, 2026-10-19)

**What.** [Q_U62](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u62) = B was already the code's behaviour, so F does not change the semantics.
It makes B a pinned contract and corrects the two refusals whose remedies were false or missing
once one element heads several branches. Probe: research/P4e-1b-vi/probe-1bvi-ai (40 lines at
`3fcb720a`; `ai:N` = its line N).

- **B as a contract (UC-7).** A `sub-block` law family states `ot{0.P.{X}}` ≡ `t5{P.{X}}`, wrapped
  as the element's one component. It covers every star family over Map contents and `*` / `*-`
  over `ov3`'s vector contents, at each kept/dissolved assignment of P. The 50 rows were predicted
  before the run (7 assignments × 6 families + 4 × 2). Twelve hand rows (U62-1..12) pin the
  examples the decision was argued on: the wrap (`ot{0.a^.{b*}}` → `@[{:c …}]`, ai:35;
  `oo{0.{0.a^.b*}}`, ai:36), the tuple of records (`ot2{0.a^.{b*} 1.a^.{b*}}` →
  `@[{:k 1} {:k 2}]`, ai:37), records of different shapes (`fleet{0.{meta^.id* net^.tls*} 1.{meta^.id*}}`
  → `@[{:n 1, :port 443} {:n 2}]`, ai:38), DC-3's broadcast equivalence, DC-1's factored splice,
  and L★ with a kept key (DC-2's side that holds).
- **SB-1, corrected (UC-8).** With one ordinal heading several branches, the dup refusal's `^`
  remedy kept each BRANCH apart: `fleet{0.meta^.id 0.net^.tls 1.meta^.id 1.net^.tls}` →
  `@[{:id {:n 1}} {:tls {:port 443}} {:id {:n 2}} {:tls {:port 8443}}]` (ai:8), a 4-tuple, and
  "a tuple of the elements" was a tuple of the branches. Now the level fact carries `'multi`. The
  `^` remedy is withheld, the sentence says "of the branches", and grouping is offered where it
  resolves the collision: `fleet{0.{meta^.id* net^.tls*} 1.{meta^.id* net^.tls*}}` →
  `@[{:n 1, :port 443} {:n 2, :port 8443}]` (ai:7). Measured for each family: `*-` ai:10, `*_`
  ai:12, `*-_` ai:14. Grouping is offered only when the colliding branches sit under PAIRWISE-
  DISTINCT ordinals (`'cross`). Within one element it cannot help (`fleet{0.meta^.id* 0.meta^.id*}`,
  ai:15), and with two of three colliders under one ordinal it would still collide (ai:17).
- **SB-2, corrected (UC-8).** The all-ordinal L4 refusal now also offers the grouping where the
  rests can be wrapped (`'groupable`): `ot{0.a^.b^.c^.{m* n}}` → `@[{:n {:y 2}, :x 1}]` (ai:21);
  `*_` ai:25, `*-` ai:27, `*-_` ai:30. A rest that opens with a sub-block cannot be grouped
  (`vhm{0.{{0}*}}` does not parse), so `vhm{0.{0}* 0.{0}}` gets no grouping (ai:31). The existing
  remedies still run on the new population: a key kept before each star ai:22, `^` ai:23, the
  total family's `^` ai:28.
- **S's scope stated (UC-9)** in [Q_U61](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u61)'s entry; the spec note is proposed, not applied.
- **Acceptance M18:** braces scope a landing, shown on the file's own subjects: records of
  different shapes, the broadcast, and the star after the braces. Plus the multi-branch
  refusal, commented, with its remedy run.

**Finding SB-4 (pre-existing, filed with SB-3).** On a vector-only path, the all-ordinal L4 refusal
offers two remedies, and neither can be spelled there: "keep a key before each star" (the path
has no key) and "end the branch with `^`" (`vhm{0.{0}^ 0.{0}}` is a parse error, ai:32). The working
remedy is dropping the star, `vhm{0.{0} 0.{0}}` (the shape of ai:19), or the own-block route. It
came from VF-3's arm in `0988a4f0`, and it is the same class as SB-3: key- and postfix-shaped advice
on paths made only of ordinals. Filed as [DEFERRED 185](../../../../DEFERRED.md) (on main, `e751736c`).

**Mutations F1–F7** (`mutate-F.sh`; each file restored under checksum) — each red on its own rows:

| mutation | rows red |
|---|---|
| F1: SB-1's grouping arm off | SB1, SB1-c1 + the render invariant |
| F2: "of the branches" off | SB1, SB1-c1, SB1-c1b, SB1-c2 + the render invariant |
| F3: `'cross` loosened to "more than one ordinal" | SB1-c1b |
| F4: SB-2's clause off | SB2 + the render invariant |
| F5: `'groupable` ignores a sub-block rest | SB2-c |
| F6: a trailing sub-block passes at the TYPING seat | 64 rows: U62-1..9, U62-12, the `sub-block` laws, … |
| F7: the same at the REDUCTION seat | 63 rows |

F6 and F7 are cruder than S+: they pass a trailing sub-block whatever the chain names, so U62-12
(a kept key) goes red as well. The rows that S+ itself would flip are U62-1..6 and the
dissolved-assignment laws. Both twins are pinned independently.

*Self-corrections.* (1) `'cross` was first written as "more than one ordinal is involved". On
review, `fleet{0.meta^.id* 0.meta^.id* 1.meta^.id*}` would have been offered a grouping that still
collides. It now requires pairwise-distinct ordinals, pinned by SB1-c1b and F3. (2) A scripted
ledger edit truncated this file (−8 716 lines, uncommitted). It was caught by the diff stat,
restored, and redone behind a size assertion. (3) A LOG heading carried a hash I had typed and
not read back; it was caught by `git cat-file` before the commit.

| VAG question | catalogue | challenge — could it be more aligned? |
|---|---|---|
| (a) on-network | no new state; `'multi` / `'groupable` / `'cross` are pure functions of the branch lists | the level facts are a third walker mirroring the two twins' arm order (the verify's (b)); one on-network walker would make them consistent by construction |
| (b) complete | 23 hand rows + 50 laws + 7 mutations; every remedy run per family | SB-4 shows the arm's remedies are still chosen by shape flags, not by whether the user's path can spell them; a remedy generator that tries its own output would close the class |
| (c) vision-advancing | a decided meaning is now a pinned law; two messages true on every measured population | the L★ side condition (DC-2) is a debt for P5's normal forms; until then nothing rewrites stars, so it cannot fire |
| (d) drift risks | the ordinal-head comment called the matter undecided; now it states the decision | F6/F7 show the decision lives in one predicate per twin; a future "simplification" that widens it to sub-blocks flips 63 pins, by design |

<a id="p4e-1b-vi-close"></a>
##### §5.P4e-1b-vi CLOSE — item 1: DEFERRED 185; a buried panic  (`a9788c0a`, `55b7df16`, 2026-10-19)

The close's items, in the order the owner approved ("Ok to proceed on 1"):
1. [DEFERRED 185](../../../../DEFERRED.md), done below;
2. the star family in the tree-sitter grammar ([DEFERRED 144](../../../../DEFERRED.md), with 179 / 180);
3. retire the `pre` column and `1bvi-stage`;
4. the close note, main merged in, the full suite, and the checkpoint merge.

**185, re-measured before fixing: wider than filed.** One meaning, Q_U46's reserved gap (a star after an
ordinal), gets five different messages depending on spelling: guided only for the bracket `y{a[0]*}`;
"`*` is postfix" for `vhm{0*}` and `vhm{0.{0*}}`; "stray `.`" for `y{a.0*}`; a bare "Unbound
variable" for `vhm.0*`, `vv:0*` and `y.a.0*`. The SB-3 claim in the [Q_U62](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u62) ledger is
struck accordingly. SB-4 is wider too: "keep a key before each star" is unspellable on `ot2{0.a* 1.a}`
(no dissolved key), not only on key-less paths.
- **SB-3, block band (`a9788c0a`).** The reader leaves `0*` as `0` then `*` (Q_U27: the same as `{0 *}`),
  so the parser now catches a star-family item after an ordinal head. It gives Q_U46's refusal from
  ONE definition, `select-ordinal-star-message` (`syntax.rkt`), which typing's `star-deep-prefix`
  also uses. Its remedy text is deliberately unchanged: how "flatten element N" is spelled is
  [Q_U63](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u63)'s question.
- **SB-3, reader seats: not here.** The path band and the dotted mid-branch need the reader's recognizer.
  P4e-2 opens exactly that recognizer for `.*`, and [Q_U27](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u27) requires a reader mint to land
  alone with a corpus A/B. They are added to DEFERRED 185 with P4e-2 as the trigger.
- **SB-4 (`a9788c0a`).** Two level flags: `'head-key-tails` (every passing head's sₙ is a key) and
  `'head-dissolves` (every passing head dissolves a key above sₙ). Each remedy is offered only under
  its flag; with neither, "drop each `*`", which runs (`vhm{0.{0} 0.{0}}` → `@[@[{:x 1}] @[{:x 1}]]`).
  The `^` remedy now names the operator, as its total-collapse sibling did. A render invariant first
  failed on the no-cont tell: the new sentence was the only one at that level not naming the operator.
- **RV-2, a buried panic (`55b7df16`).** Found opening P4e-2: `ot2{2}*` printed
  `(panic "select: index 2 …").* : {:a {:b {:k Int}}}` at zero errors; the starless `ot2{5.a}` aborts
  correctly. The outer selection's subject was the inner one's panic and matched no arm in
  `reduction.rkt`'s `expr-select` case. Fixed by one arm, strict in the subject (the ratified
  whole-node abort). Siblings checked: `[map-get …]`, `[get …]`, `.b` and `{b}` on the same subject
  are refused statically (the subject is a tuple), so the star route was the only one.

**Evidence.**
- Red steps were run against the OLD code: the source files were set aside and the battery run at stage G
  (exactly the 6 / then 2 new rows red); every `pre` column held at stage F.
- 12 hand rows plus 3 render invariants.
- Mutations G1–G4 and the panic arm: each red on its own rows.
- Battery + acceptance 701 / 701; run-file --check 116 / 116; update-deps clean.

| VAG question | catalogue | challenge — could it be more aligned? |
|---|---|---|
| (a) on-network | message text and level flags, no state | — |
| (b) complete | every remedy of the two arms run on its population | the class is "advice chosen by shape flags": a remedy renderer that runs its own suggestion would close it (filed with 185) |
| (c) vision-advancing | one meaning, one message, at two seats | the reader seats still split the meaning across bands until P4e-2 |
| (d) drift risks | the struck SB-3 claim was mine, written from the record, not measured | each new claim here cites a probe line |

<a id="p4e-1b-vi-close-2"></a>
##### §5.P4e-1b-vi CLOSE — item 2: the star family in the editor grammar, with 179 and 180  (`04e3c5c5`, 2026-11-02)

The owner approved this item with the rest of the close (["Ok to proceed on 1"](#p4e-1b-vi-close), then "proceed
accordingly" on 2026-11-02). Measurements: [`tsg-close2.txt`](../research/P4e-1b-vi/close/tsg-close2.txt) (§1–5 below cite its sections),
[`probe-179`](../research/P4e-1b-vi/close/probe-179.prologos) (`.out` at `04e3c5c5`, `.pre-fix.out` at `cc520b1d`; lines are output
numbers), [`probe-957`](../research/P4e-1b-vi/close/probe-957.prologos).

**[DEFERRED 144](../../../../DEFERRED.md) (the grammar's `flatten_step` was a bare `*`), fixed.**
- **Before.** `flatten_step` was the string token `'*'`. At the closer seat, `app-config{database}*_`
  (acceptance file L509) parsed as an APPLICATION of the path to the identifier `_`, and `*-` / `*-_` (L574,
  L577) as an application to the operator `-`. These parses have no ERROR and no MISSING node, so no
  count-based gate could see them; only a tree test can.
- **After.** `token.immediate(prec(1, /\*[-_]*/))`: one token for the whole family. It is a superset on purpose,
  per [Q_U53](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u53)'s containment rule. The fused band (`x{a*_ b}`) needed nothing, because `*`, `-` and `_`
  continue an identifier there, as they do in the compiler.
- **The precedence is load-bearing.** `operator` contains the string `'*'`, and tree-sitter breaks a same-length
  tie in favour of a string. Without `prec(1, …)` the existing corpus test 54 (`record.orders:items*:sku`)
  failed (tsg §1). The `:` token at `grammar.js:657` has the same remedy.
- **Evidence.**
  - Three new corpus trees (closer `*_`, `*-`, and `*-_` after a broadcast and after a group) are red on the
    old grammar and green now. A `{0.5}` decimal control passes on both. 60 / 60 (tsg §1).
  - Per-file A/B: 0 better, 0 WORSE, 142 unchanged (tsg §2). That is expected, since the old trees were wrong
    without being errors.
  - The `(flatten_step) @operator` capture now covers `*_`, `*-` and `*-_` whole. Before, it painted the `*`
    alone (tsg §4).
  - No wasm was built (emsdk was off PATH under the scratch HOME), so VS Code's copy updates at the owner's
    next `./install.sh`.

**Ordinal-headed branches: tried, not shipped (filed as [DEFERRED 205](../../../../DEFERRED.md)).** The grammar has no select
branch that starts with an ordinal (`{0.server^.ssl* name}`, P3c's `(@ord N)` head). So the acceptance file's
ordinal lines are ERRORs, and M18's `{0.{…}}` makes the parser invent an identifier (4 MISSING: L638, L642 ×2,
L650, all added by `3fcb720a`).
- A rule for them fixes the acceptance file (E43/M4 → E35/M0). But in every one of seven formulations it makes
  `foray.prologos` worse (E87/M3 → E84/M4), with one 251-line ERROR from L957 (tsg §5).
- L957, `users:<{0.userName^}`, is not valid Prologos: the compiler answers `Unbound variable` for it
  ([probe-957](../research/P4e-1b-vi/close/probe-957.out) line 1).
- With that line plus one def in isolation, both grammars give the same tree. The long ERROR needs the
  preceding context: blanking L940–956 shrinks it to 7 lines, while blanking L950–956 does not.
- This is error-recovery churn, the corpus-budget's own documented class, not a wrong rule. Under the per-file
  A/B rule ("exit 1 if ANY file got worse") it still does not ship.

**Found: the corpus gate has failed on this branch since `3fcb720a`.** `check-corpus.sh` reports MISSING 75 against
a budget of 71, identically before and after this item (tsg §3). The +4 are exactly M18's lines above.
- No hook runs the corpus gate. The pre-commit hook's grammar check is a tripwire that only warns, so 1b-vi-F
  added M18 without measuring it. That was my miss at F, and it is recorded in DEFERRED 205.
- **Decision for the owner**, before the checkpoint merge:
  - (a) raise `max_missing` 71 → 75 with the reason in the commit and a pointer to 205, lowering it again when
    205 lands;
  - (b) hold the checkpoint until 205 lands.
  - **Lean: (a)**. The gap is old (P3c); M18 only measured it, and a gate that stays red stops being read.
    Against (a): a ratchet loosened for a known gap is how drift starts. That is why the reason must name 205.
  - ✅ **DECIDED (a)** (owner, 2026-11-02 17:36: "OK with lean on (a)."). `max_missing` 71 → 75 at `a7dcde7d`,
    with the reason in `corpus-budget.txt` and the commit naming DEFERRED 205; the gate PASSes at 75
    ([close-3](#p4e-1b-vi-close-3)).

**[DEFERRED 179](../../../../DEFERRED.md) (Q_U56's guided `*->` text missed the closer seat), fixed.**
- **Mechanism, now measured** (the entry had it as a conjecture). The fold fuses the closer star onto its
  selection and leaves `>` as the next sibling: `env{prod dev}*->` preparses to
  `(($select-path ($select env prod dev) $postfix-star-collapse) >)`. The `>` is therefore an ARGUMENT, and it
  reached the elaborator as an unbound name. Before the fix this produced the comparison-keyword hint
  (probe-179 pre-fix lines 28–33, 35, 36, 39, 42, 45), or, inside a keyword form, the arity error
  "map-get expects 2 arguments, got 3" (pre-fix line 34).
- **The seat is `parse-list`, not the selection consumer.** The `>` is outside the braces, so Q_U56's item arm in
  `segment-select-items` cannot see it. `parse-list` is the one seat every list form passes before head dispatch,
  so a single arm covers the head, argument and keyword positions.
  - It sits after `$angle-type`, so type territory keeps Q_U31's seat.
  - The error is a per-command value, never a reader raise.
- **What it fires on.** A `>` right after a selection whose last step is a star:
  - the closer band (the star sentinel);
  - the dot band (`env.prod*->` → `($select-path env prod*-)`);
  - the broadcast band (`rm:cfg*_>`).
- **Glued and spaced cannot be told apart in the datum.** So the text is true of both: it names the star's
  meaning, says to drop the `>`, and gives the comparison spelling (`gt`) for the spaced reader.
  - `env{prod} > 1`, with no star, keeps the comparison hint (line 40).
  - `env{prod}*- >= 1` keeps it too (line 49), since `>=` is a comparison attempt rather than a `*->` slip.
- **Data territory is unchanged in kind.** `'[env{prod}*- >]` was already a refusal (pre-fix line 46: the hint)
  and now gets the star text (line 46); `'[a b >]` is unchanged (line 47).
- **A first cut did not fire,** and the red rows staying red is what showed it. `stx->datum` is shallow: a
  compound syntax comes back as a list of syntax objects, so the head test never saw `$select-path`. The arm now
  uses `syntax->datum`.

**[DEFERRED 180](../../../../DEFERRED.md) (the arrival instrument could not tell `*-` from `*` then `-`), fixed.**
- `star-last-token-type` and `star-mints?` take an optional spelling. With one, the last star-family token must
  BE that lexeme, or the answer is `'split`. Without one, they keep the old meaning.
- The arrival gate passes the lexeme under test.
- The battery's "is ONE token" pins now compare `(lexeme . type)` through `p4e-star-token`, with split controls
  (`* -`, `* -_`).

**Evidence.**
- Stage H: 8 flipping rows (H-179a…h) and 3 controls. Red against the old parser on exactly the 8; green after.
- One new test case for 180. It was red against the old instrument (arity); a mutation that ignores the
  spelling turns exactly that case red.
- Mutations M1 (dot band), M2 (broadcast band), M3 (sentinel) and M4 (the arm) each turn exactly their own rows
  red: M1 → H-179f, M2 → H-179g, M3 → the six closer rows, M4 → all eight.
- Hand rows 141 → 152. Battery + acceptance + hygiene **702 / 702**. Dependency cache verified.

| VAG question | catalogue | challenge — could it be more aligned? |
|---|---|---|
| (a) on-network | a lexer token, an instrument argument, a parse-time message; no state | — |
| (b) complete | three bands of 179's shape; both instrument entry points; every remedy run (`env{prod}*-`, `rm:cfg*_`, `[map-get env{prod}*- :db]` → values) | `>=` and other `>`-led names after a star keep the comparison hint, by choice; the ordinal grammar is 205 |
| (c) vision-advancing | the editor now reads the star family the compiler mints | the corpus gate cannot see wrong-but-error-free trees, which is exactly 144's class; only `test/corpus` can, and nothing forces a tree test per new surface form |
| (d) drift risks | the corpus gate failed for a slice and a half unseen | a corpus run in the slice-close checklist, or a hook gate (filed with 205) |

<a id="p4e-1b-vi-close-3"></a>
##### §5.P4e-1b-vi CLOSE — item 3: the stage scaffolding retires  (`3f2db4ca`, 2026-11-02)

1b-vi-A promised it: "at the 1b-vi close the `pre` column and `1bvi-stage` are deleted — they are
scaffolding for the slicing" (the A paragraph above the tracker). Done, with the sub-decisions below taken
inside the approved item.

**Retired.**
- `1bvi-stage`, `1bvi-stage-order`, `1bvi-reached?`.
- The FLIPS-AT and PRE columns. Every row is now `(ID SPELLING EXPECT)`, where EXPECT is the old TARGET,
  or PRE for a control.
- The assertions that only meant something under a stage: "every row ahead still FAILS its target"
  (non-vacuity), "PRE ≠ TARGET", and "a control carries no TARGET".
- The pre-mint expectation classes (`midlex`, `postfix`, `unbound`, `abort` → `raised`). No expectation
  uses them any more: all 346 are `same` 22 · `equiv` 89 · `wrapped` 68 · `line` 51 · `refused` 116.
- 1b-vi-C's injection batch (`1bvi-inject-batch`, `1bvi-inject-problems`, the lexeme-row list,
  `1bvi-injectable?`). It ran the hand-built IR through elaboration "before the mint". Since D, the level-3
  rows run the parser's IR, and the parity pin says it is the same IR.

**Kept, and made stronger.** The parity pin is now stated as a law,
`parse(*- spelling) ≡ totalize(parse(* spelling))`, over the law's own domain. That domain is every row whose
spelling has a total star and that the parser reads as a selection. Before, it was "the rows that flipped at
D", an accident of slicing history.
- The domain grew from 81 rows to 113. The 32 new rows are 14 verify-round hand rows (V-omK1/2/3/5, V-as2/3,
  V-or2/3, V-orK9, V-l4a/b/K, V-dup-sealed, V-arrow2K) and the 18 `sub-block` laws with a total star. The law
  held on all 32 on the first run.
- The domain's size is pinned (113), so a parser that stopped building selections cannot pass vacuously.
- The remedy check now runs every remedy any refused row offers; it used to cover live rows only. A guard
  fails it if no row offers a remedy, since an empty population would give the check no power.
- Unchanged: level 2 ≡ level 3, right-hand sides accepted and typed, the size pin (152 hand / 194 law), and
  unique ids. Added: a well-formedness check on every expectation's kind and shape.

**Sub-decisions, each weighed.**
- **FLIPS-AT retires with PRE rather than staying as a provenance tag.**
  - For keeping it: one cheap column saying which sub-slice made a row true.
  - Against: it gates nothing once the stage is gone, so the next reader would have to work out that a live-
    looking column is dead. Provenance already lives in row ids, group comments, the tracker above and
    `git log -S`.
  - Taken: retire.
- **The injection retires.**
  - For keeping it: an independent second route to the walkers.
  - Against: its independence was at the IR level, and the parity law states exactly that equality. Running
    the same IR through elaboration a second time adds cost and no claim.
  - Taken: retire.
- **The parity domain widens.** Monotone in strength: the old domain is contained in the new one (checked,
  below).

**Evidence.**
- **Equivalence, mechanical** ([`retire-dump.rkt`](../research/P4e-1b-vi/close/retire-dump.rkt)): the table was dumped from the old
  module (id, spelling, TARGET-or-PRE) and from the new one (id, spelling, EXPECT). All 346 rows are
  identical ([before](../research/P4e-1b-vi/close/retire-table-before.txt), [after](../research/P4e-1b-vi/close/retire-table-after.txt), lines 1–346). The old
  parity domain (81) is contained in the new one (113), per the last line of each file. The committed script,
  re-run in place, reproduces the after-file byte for byte.
- **Power** (three mutations):
  - turning off the 179 arm turns exactly H-179a…h red;
  - removing the parser's total-collapse mark aborts both batches on the walkers' C-5 guard and turns 80
    parity rows red, 12 of them from the new 32. The other 33 have no ancestor for the mark to wrap;
  - pinning the domain at 112 gives exactly the one domain problem.
  - A first run of that last mutation was contaminated, because the parser mutation before it had not been
    restored between files. It was discarded and re-run alone.
- **Gates:** battery + acceptance + hygiene 702 / 702; dependency cache verified. `test-path-selection.rkt`
  is 118 lines shorter net. Per-test-case timing was not re-measured.

**Also at this item: the corpus budget.** The owner decided (a) (2026-11-02 17:36, "OK with lean on (a)"). At
`a7dcde7d`, `max_missing` went 71 → 75, with the reason in the file and the commit naming DEFERRED 205. The
gate PASSes at 75.

<a id="p4e-1b-vi-shipped"></a>
##### §5.P4e-1b-vi — WHAT SHIPPED  (A → B → C → D-1 → D-2a → D-2b → E → verify → gate → F → close; 2026-10-13 … 11-02)

**Total collapse is live** ([Q_U48](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u48), [Q_U57](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u57) P), in every band the star family mints.
- `*-` deletes the layer the last step makes, and no ancestor contributes an output level. So
  `app{database*-}` ≡ `app{database*}`, and `t5{a.b.c*-}` ≡ `t5{a^.b^.c*}`, typed
  `{:m {:x Int} :n {:y Int}}`. Both are rows E1- and E7- of the table, where the right-hand side is
  measured on every run.
- `*-_` names each lifted field by the whole collapsed path: `app{server.ssl*-_}` is typed
  `{:server-ssl-cert String :server-ssl-enabled Bool}` (row E2_).
- Where nothing can collapse, `*-` ≡ `*` and `*-_` ≡ `*_` ([Q_U59](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u59)): path position, as in
  `app.server.ssl*-`.

**Refused, guided, with remedies that run.**
- A rename on an ancestor of a total collapse, in both families (`*-` / `*-_`, `^-` / `^-k'`; [Q_U55](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u55)
  A). Example: "`srv` can never appear under a total collapse" (row E5-).
- `*->` and its siblings in selection territory ([Q_U56](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u56)), now at every seat: inside the braces since
  D-2b, and at the closer, dot and broadcast seats since close-2.
- A star right after an ordinal head gets Q_U46's one refusal (close-1, block band).

**Ordinal heads.**
- [Q_U61](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u61) S: an ordinal head passes a keyless star landing through, at every depth.
- [Q_U62](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u62) B ("for now"): braces scope a landing. A star inside the braces lands in the element; a star
  after the braces escapes it.

**Stated as laws** ([Q_U60](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u60)): 194 generated rows (`*` 22 · `*-` 44 · `*-_` 26 · `^-` 26 · `^-z` 26 ·
`sub-block` 50), plus the parity law over 113 rows (close-3). The table is 346 rows (152 hand, 194 law).

**Representation** ([Q_U58](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u58) M): marked in the parser (`(collapsed . c₀)`, at `segment-select-items`' one
success return) and acted on in both twins (typing, reduction).

**Defects fixed on the way.**
- VF-1, a whole-file abort.
- VF-2, a value/type split between the twins.
- VF-3, ordinal-level prose ([verify](#p4e-1b-vi-verify)).
- RV-2, a buried panic printed as a value (close-1).
- DEFERRED 185's block band (close-1).
- DEFERRED 179, 180 and 144, the editor grammar (close-2).

**Not shipped, and where it went.**
- DEFERRED 185's reader seats → P4e-2.
- DEFERRED 205, the grammar's ordinal-headed branches.
- DEFERRED 167 (block-position ω; a waypoint refusal stands) and DEFERRED 115's L★ side condition (ah:23 ≠ 24)
  → P5.
- DEFERRED 168 (type territory).
- DEFERRED 198's addendum (the buried-panic class elsewhere).

**Decisions made during the slice:** Q_U55, Q_U56, Q_U57, Q_U58, Q_U59, Q_U60, Q_U61, Q_U62, the corpus budget
(close-3), and [Q_U63](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u63) J, which is P4e-2's, decided during the close.

**For the PIR.**
- The corpus gate was not run when F added M18. No hook runs it, so it failed unseen for a slice and a half
  (close-2).
- Running every remedy a refusal offers caught advice that does not work at least twice. One was SB-1's `^`,
  which kept the BRANCHES apart as a 4-tuple (F); the other was SB-4's unspellable remedies (close-1).
- Counting the rows an instrument actually covers caught a vacuous pass (X-type, C). The parity domain's size
  pin carries that lesson forward.

