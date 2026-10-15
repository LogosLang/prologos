# CIU 6 — track LOG (append-only, newest at the bottom)

CIU Track 6 — Anonymous Records, Collections & Path Selection. Entry shape is the dailies'
(`../../../principles/DAILIES_METHODOLOGY.org`): `### <outcome headline> — \`hash\` (date)` with
**Why / decision**, **Surprise / correction**, **Next**. The dailies' STATE head stays the
re-grounding surface and its sparse LOG points here. Opened 2026-10-13 under the per-track-log
convention (`../../README.md`); the series stub and the index of the flat documents of record
are in [`../README.md`](../README.md).

### Before this LOG: the journal of record 2026-07-05 → 2026-09-08 — pointer only
- **Where the history is.** Decisions: D4 §3, the ledger
  ([`../../../2026-07-28_CIU_T6_PATH_SELECTION_D4.md`](../../../2026-07-28_CIU_T6_PATH_SELECTION_D4.md),
  Q_L…Q_U54; earlier D1–D29 in the track doc). Per-slice records: D4 §5, by anchor
  (`#p4e-1b`, `#p4e-1b-sequencing`, `#p4e-1b-v-c`, …). The surprise journal: the dailies
  `../../../standups/2026-07-05` → `2026-09-08_dailies.md` (14 files mention the track; the P4e
  arc is in `2026-08-10`, `-08-11`, `-08-12`, `-08-14`, `-08-15`, `-09-08`). Handoffs: 15 under
  `../../../handoffs/` (latest `2026-08-11_CIU_T6_P4e-1b_handoff.md`, written at P4e-1a's close).
- **Position at hand-over** (`2026-09-08_dailies.md` STATE, recorded at `7a0116ec`): Path
  Selection phase P4e (the `*` family), slice **1b-v-C — the fold — ✅** (`24fc1be4` pins ·
  `a492bbb7` the fold): one semantic authority (`postfix-star-sentinel-table`,
  `reader-forms.rkt`) for the reader, the splitter, the printer and `form-deps`. Battery 573 ·
  acceptance 88/88 · arrival matrix `*` and `*_` 209/209, `*-` and `*-_` 0/209 · suite
  10 248 / 488 / 0 (189.0 s, Racket 9.0, old runner).
- **Next at hand-over**: 1b-vi (below).

### CIU 6 resumed in its own worktree; `tracks/CIU/` opened; baseline re-measured on Racket 9.3 — docs commit on main (2026-10-13)
- **Why / decision**: owner — continue CIU 6 "in its own working tree (so not to collide with
  any work that may be coming into `main`)", and track it under `tracks/` with a per-track LOG
  and sparse dailies. Branch **`ciu6-path-selection`** off `main` @ `58241c0c`, nested worktree
  `.claude/worktrees/ciu6-path-selection`; main receives tested checkpoint merges only, never a
  rebase once hashes are cited. Opened `tracks/CIU/README.md` as a stub over the flat series
  master (nothing moved; the flat CIU 6 documents of record are indexed there; three UNAPPLIED
  edits to the roadmap and the master proposed there), this LOG, and rolled the dailies to
  `2026-10-13_dailies.md` (cross-track STATE head + sparse pointers; roll triggers: track shift
  and the 488-line prior file).
- **Re-grounding** (the track's own lesson: re-ground before resuming a parked track). Main
  moved **27 commits** since `7a0116ec`. In `racket/`, they touch `champ.rkt`,
  `decision-cell.rkt`, `driver.rkt`, `propagator.rkt`, `lsp/server.rkt`, the runner
  (`batch-worker`, `run-affected-tests`, `suite-plan`) and six new test files. **None of the
  star family's surfaces moved** (zero commits on `parser.rkt`, `reader-forms.rkt`,
  `parse-reader.rkt`, `macros.rkt`, `syntax.rkt`, `typing-core.rkt`, `typing-errors.rkt`,
  `reduction.rkt`, `pretty-print.rkt`, `elaborator.rkt`, `surface-rewrite.rkt`, the battery,
  the matrix, the acceptance file). The toolchain moved 9.0 → **9.3**, and the runner gained
  whale sharding and working LPT dispatch.
- **Baseline at `58241c0c`, in the worktree** (built with `PLT_CS_COMPILE_LIMIT=1000000`;
  `reduction`/`typing-core`/`elaborator`/`parser` `.zo` byte-identical to main's):

  | gate | 2026-10-13 (9.3) | at hand-over (9.0) |
  |---|---|---|
  | suite `--all --force-rerun` | 10 289 tests / 492 files, 57.4 s, **1 failure** — `test-error-messages` `:465:2`, DEFERRED 160's suite-only flake; alone 44/44 pass | 10 248 / 488 / 0, 189.0 s |
  | battery `test-path-selection.rkt` | 573 test-cases; sharded ×5, 23.5–38.9 s per shard | 573 |
  | acceptance `run-file.rkt --check` | 88 / 88 | 88 / 88 |
  | arrival matrix | `*` 209/209 · `*_` 209/209 · `*-` 0 · `*-_` 0 (the pre-1b-vi state) | same |

  The +41 tests / +4 files are main's (the sweep merge and the runner's tests). The two wall
  times are not a performance comparison: different toolchain, build flags and runner.
- **Surprise / correction**: none in the CIU surfaces. The baseline's one failure is a third
  sighting of DEFERRED 160 (same check, same message as the second); a data point with the
  preserved log was added to that entry.
- **Pending owner decision W-1** (workflow, not a design question): where CIU 6's track
  documents (this LOG, D4's per-slice records) are committed between checkpoint merges — on
  the branch with the code (lean), or on main as PAR 4 does. Shared registers (DEFERRED
  entries, the dailies) go to main either way. Analysis in this session's reply; record the
  answer here.
- **Next**: **1b-vi, the star-collapse slice** (D4 `#p4e-1b-sequencing`, row 1b-vi):
  `*-` ([Q_U48](../../../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u48), total collapse —
  ruled), the `*-_` decision (open), the cont-axis **totality dispatcher** (the six
  `select-star-cont` readers are binary tests on `'flatten-synth`; an unknown cont reads as
  bare `*`), and `typing-errors.rkt`'s prose column (15 formatters spelling `*`/`*_` per kind —
  the printer defect's twin, `#p4e-1b-v-c`). Two owner decisions come first
  ([Q_U52](../../../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u52) §1–2): what total collapse
  does to a **renamed** ancestor (`t4{a^p.b.c*-}`), and the **`*->` token boundary**. Opens
  with the grounding mini-audit, re-deriving those counts at this HEAD.

### W-1 decided: CIU 6's track documents ride the branch; shared registers go to main — no commit (2026-10-13)
- **Why / decision**: owner — *"B — … work on specific parts of the system happen under separate
  worktrees/branchs with periodic and regular merges back into main, so that work can safely happen
  concurrently."* So this LOG, D4's ledger and per-slice records, and the track's
  research artifacts are committed on `ciu6-path-selection` with the code they describe, and reach `main` at
  checkpoint merges. `DEFERRED.md` (a register every session allocates from) and the dailies (cross-track
  STATE) are committed on `main` directly. Rejected: PAR 4's docs-on-main practice, which suits a branch
  whose code never merges; here it would make main cite unmerged hashes as ✅ between checkpoints.
- **Surprise / correction**: this supersedes the tracking skill's standing rule "commit the track's
  documents to main at every milestone" for tracks whose code merges to main; the skill was amended the
  same day.
- **Next**: the 1b-vi grounding audit.

### 1b-vi grounding audit: the renamed-ancestor question belongs to the collapse family (`^-` has the same unruled hole), `*->` predates 1b-vi, and L1 fails in block position (DEFERRED 167) — this commit (2026-10-13)
- **Why / decision**: owner — a short audit first, plus a review of the spec "as a suggestion to review,
  not a commandment". Record: [`2026-10-13_CIU_6_P4e-1b-vi_GROUNDING_AUDIT.md`](2026-10-13_CIU_6_P4e-1b-vi_GROUNDING_AUDIT.md);
  probes and outputs in `research/P4e-1b-vi/`. The branch was first fast-forwarded over 20 main commits
  (sweep + runner-queue merges, F3(a) in `substitution.rkt`/`type-lattice.rkt`) to `01ef2542`; battery 573
  test-cases, 663/663 with the acceptance test file, acceptance markers 88/88. Findings: (1) `^-` silently
  drops a re-keyed ancestor (`e3{a^p.b.c^-}` → `{:c …}`) while `^-_` honors it (`{:p-b-c …}`), unpinned and
  unused. `*-` is `^-` ∘ `*` (one operator suffix per segment), so the decision is one rule for both
  families. Posed as **[Q_U55](../../../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u55)** (pending), options
  A refuse / B total wins / C explicit wins, with the tradeoff analysis in the ledger. (2) In type territory
  `Nat *-> Nat` is already not an arrow ("has no arrow"); 0 glued `*->` anywhere. (3) An in-block fused ω chain
  errors (`w4{a:b:c}`) where the path form works, with zero pins: filed **DEFERRED 167** on main. It also
  makes the broadcast-ancestor half of Q_U52 §1 unobservable for now. (4) The totality census: 6
  `select-star-cont` readers (5 binary), 15 `star-*` prose arms in `format-select-fail`, 3 internal `oops`
  strings, 2 deliberate `"*"` selectors; the battery pins `cfg{a}*-`/`*-_` as unminted (`:6194–6195`), and 1b-vi
  flips them deliberately. (5) A spec → D4 departures table is owed (D4 §1.2 maps only the old PS rulings
  onto the spec).
- **Surprise / correction**: my first census pattern for "`*-` glued after an identifier" was zero-power
  (`\]` is not an escape inside an ERE bracket, so it demanded a literal `)]*-`) and reported **0**. Running it
  on positive controls before committing caught it. The corrected pattern finds 3 hits, all the posit names
  `p*-to-rat` / `p*-if-nar` in comments. `p*-if-nar` is a live keyword-only form (`elaborator.rkt:947`), so
  identifiers containing `*-` exist outside selection territory and stay safe by Q_U37's territory scoping.
  Fail-open watch: 8-of-N. Also: Q_U52 §1's "a broadcast ancestor is unwritable" is true but does not
  separate the options; the case is blocked one step earlier, by DEFERRED 167.
- **Next**: owner decision Q_U55; then the `*->` boundary (Q_U52 §2, reframed by F5: a message and a
  territory, zero programs at stake); then `*-_`'s prefix rule; then implementation, opening with the
  totality dispatcher's pins.

### Q_U55 decided: A — a rename on an ancestor of a total collapse is refused, in BOTH collapse families; dissolve stays legal; provenance forms keep the rename — this commit (2026-10-13)
- **Why / decision**: owner — *"I'm good with Option A (refuse) on Q_55. And that we fix `^-` to be in
  line with the behavior as well, for consistency."* Recorded in D4's ledger
  ([Q_U55](../../../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u55)) with the reason (monotone waypoint;
  the silent drop becomes a guided error; `^-` costs nothing to align — 0 uses, 0 pins) and the
  implementation shape (a syntactic check in the shared branch walk, not typing; failing-first pins in
  both families; the `^-` half lands in 1b-vi with the `*-` mint).
- **Surprise / correction**: the rule turned out narrower than posed. Probe `probe-1bvi-g` shows
  `^_` and the `^-` family are already refused on an ancestor ("attaches to the branch's LAST segment" /
  "a LEAF continuation"), so the only spellable ancestor continuations are dissolve `^` (legal, redundant)
  and rename `^k'` (refused under `*-`/`^-`/`^-k'`, legal under `^-_` and — pending — `*-_`).
- **Also from this probe, for the `*->` question** (owner asked what `*->` denotes): it is not a
  designed construct. It first appears in Q_U52 §2 (`783be940`, the 1b-v audit), as a token-boundary
  hazard of the `*-` spelling: `-` continues an identifier and `>` does not, so a star glued to `->`
  always lexes as `…*-` then `>`. Measured today: `spec s4 Nat *-> Nat` → "spec type for s4 has no
  arrow"; ~~`<(x : Nat)*- Nat>` → a bare "Type mismatch" (no lexical message)~~ **withdrawn
  2026-10-13** — the control failed the same way; isolated, it is a nameless "Unbound variable"
  (see *Q_U58 decided … 1b-vi-A* below), while the glued-Sigma
  `<(x : Nat)* Nat>` gets Q_U31's guided "needs a SPACE" message.
- **Next**: the `*->` handling (owner's call after the explanation), then `*-_`'s prefix rule.

### Q_U56 decided (`*->` is a guided diagnostic in selection territory; type territory filed as DEFERRED 168); Q_U57 posed — `*-_`'s prefix, L vs P, measured through today's equivalents — this commit (2026-10-13)
- **Why / decision**: owner — *"Yes, that looks like a guided diagnostic as per (a)."* Ledgered as
  [Q_U56](../../../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u56); the pre-existing type-territory
  messages ("has no arrow", a bare "Type mismatch") filed on main as **DEFERRED 168** (`b309f98e`).
  Then the owner asked for the `*-_` rule "worked out in examples and tradeoffs … with more examples":
  [Q_U57](../../../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u57), ten cases (E1–E10) on five fixtures.
  Both candidate prefixes are measurable today through equivalent spellings: L ≡ `^` on every ancestor
  + `*_`, and P ≡ every lifted field written with `^-_` (probe `probe-1bvi-h`). So the table is
  measured, not predicted.
- **Surprise / correction**: the decision reduces to two invariants that cannot both hold. I1 (`-`
  orthogonal to `_`, as in the caret family) gives L. I2 (provenance names everything the operator
  deleted, Q_U24's own principle) gives P. The sibling case E3 separates them: L refuses
  `env{prod.db*-_ dev.db*-_}` (duplicate `:db-port`), which is the collision provenance exists to remove.
  And P ⊇ L (dissolving ancestors under P gives L's answer, E6). Also measured (`probe-1bvi-i`): joining
  keys with `-` is not injective, and the strict merge refuses the resulting clash loudly.
- **Next**: owner decision Q_U57.

### Q_U57 decided: P — `*-_` names the whole collapsed path; every decision 1b-vi owed is made; two implementation facts measured for the plan — this commit (2026-10-13)
- **Why / decision**: owner — *"`P`'s table and rationale stand as reasoned, let's go with that."* Ledgered at
  [Q_U57](../../../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u57). The 1b-vi row in D4's sequencing table now
  shows all three decisions (Q_U55 A, Q_U56 (a), Q_U57 P).
- **Measured for the implementation plan**:
  - `probe-1bvi-k`: provenance names only what the BRANCH collapses. `e3{a.{b.c^-_}}` → `{:a {:b-c …}}`, so an
    enclosing sub-block's head is not in the name. So `*-_`'s ancestor prefix is **static per branch**,
    computable from the branch's own steps by `^-_`'s naming function (`select-synth-name` /
    `select-step-output-name`, `syntax.rkt:1414`, `:1495`). Only the content key is dynamic, and the 1b-v join
    already threads it (`select-synth-prefixed-key`, `syntax.rkt:1511`).
  - `probe-1bvi-j`: the existing parser desugar (Q_T8 `^..`, `parser.rkt:1464`) does NOT echo the user's
    spelling in a refusal (`app{server.ssl.nope^..}` is labelled `server.ssl.nope`). Star refusals build their label
    with `pp-select-branch` over the stored steps (`typing-core.rkt:1628`). So a plain dissolve desugar of `*-`
    would print the desugared form, and Q_U54 decided against exactly that (a label that names a spelling the
    user did not write). That is a prediction, not yet measured on a `*-` refusal.
- **Next**: the 1b-vi implementation plan (pins first; then the collapse machinery; then the table rows that
  mint `*-` / `*-_`), with one locus choice for the owner — where total collapse is represented (see the reply).

### Q_U58 decided (M + slicing A→B→C→D); Stage 4 opened on 1b-vi — design target recorded; one published claim corrected — this commit (2026-10-13)
- **Why / decision**: owner — *"Ok with lean on M. Proposed sequencing looks good to me. Let's record it,
  then proceed to implementation per our Stage 4 Design Methodology (Implementation Protocol)."* Ledgered
  at [Q_U58](../../../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u58). The Per-Phase Protocol's mini-design and
  mini-audit are written into D4 as [§5.P4e-1b-vi](../../../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#p4e-1b-vi):
  the semantics stated once, principles in play, a two-column mantra check, drift risks DR-1–DR-6, the A
  audit, and the sub-slice tracker.
- **Phase design target (1b-vi-A)**: read §5.P4e-1b-vi; principles Correctness Through Types (correct by
  construction), Simplicity of Foundation, Progressive Disclosure, Pragmatism with Rigor; drift risks DR-3
  (label lies) and DR-4 (vacuous pins) are A's own; the rest are watched from B on.
- **Surprise / correction**:
  - **A published claim was wrong.** DEFERRED 168 and Q_U56 said `<(x : Nat)*- Nat>` reports a bare
    "Type mismatch". Probe g's spaced control (`<(x : Nat) * Nat>` with the same `defn s1 [p] 0` body)
    printed "Type mismatch" too, so the row measured the body, not the lexing. Isolated with bare type
    expressions (`probe-1bvi-o`), `*-` in a type, glued or spaced, is a nameless "Unbound variable".
    Struck through and corrected in DEFERRED 168 (main `150915c4`), Q_U56 and the earlier LOG entry. Lesson:
    the control must differ from the case in exactly one variable; mine also differed in whether its body
    type-checks.
  - **Block-position ω keeps the projected key** (`deep{top:cfg*_}` → `{:top {:eu-cfg …}}`; path-position
    `rm:cfg*_` → `{:eu-x …}`), so P through a block ω names `top-eu-cfg`, not the `top-eu-x` I had worked
    out by hand. Found by `probe-1bvi-l` before any pin was written.
  - **Path position has no ancestors to collapse** (`probe-1bvi-m`: every caret form refused there, "a
    field access has no output key"). So `x.a.b*-` ≡ `x.a.b*` and `x.a.b*-_` ≡ `x.a.b*_`. This follows
    from the decided rules; it was not decided separately, and it goes to the owner at the A checkpoint.
- **Next**: 1b-vi-A, the stage table (`tests/test-path-selection.rkt`).

### 1b-vi-A shipped: the star-collapse stage table — 40 rows, targets measured, red step shown at stages B and D — `0b6a645f` (2026-10-13)
- **Why / decision**: the first sub-slice of [Q_U58](../../../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u58)'s
  slicing: pins first. One row per behaviour, `(id spelling flips-at pre target)`, with every target
  measured from today's equivalent spelling (`research/P4e-1b-vi/probe-1bvi-p`). `1bvi-stage` is bumped as
  the first edit of each later sub-slice, so its rows go red before its code exists. Design and VAG:
  [§5.P4e-1b-vi](../../../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#p4e-1b-vi).
- **Evidence**: stage B → exactly C1–C4 red (the silent drop); stage D → 37 / 40 red, each for its pre-mint
  reason; mutation M1 (an already-true target) caught twice, M2 (a broken fixture) caught before the
  `unbound` class could accept it. Battery 573 → 575 test-cases, all pass; the table costs 5.28 s per run
  (per-test-case timing). No production code changed, so acceptance was not re-run.
- **Surprise / correction**:
  - **Replaced an inherited idiom.** Earlier slices parked failing pins as comments (`test-path-selection.rkt:7793`,
    `:8822`), and one parked pin hid an unreadable `\*` escape. Here every target is compiled and executed.
  - **Withdrew my own cost attribution.** Two whole-file runs (92.1 s → 100.3 s summed shards) suggested "+8.3 s
    from the table". I folded the table into one test-case on that theory; the rerun read 100.2 s, so the
    difference was machine load. Then measured per test-case: 5.28 s. The fold stays (batches once per run,
    not once per shard), but its saving is not shown.
  - **Withdrew a claim before committing it.** I first wrote that `cloud{regions:{host port}*-}` reveals "a
    fifth arrival route". It does not: the matrix already has the carrier (`bcast-brace`). Before the mint
    the unminted `*-` is an item inside the enclosing block, so it gets the spaced-star refusal. Corrected in
    D4 before this commit.
  - **Hook guard, live in Hermes now**: a `raco make` without an inline `PLT_CS_COMPILE_LIMIT` was refused
    by `tools/hook-guard-racket.sh` (DEFERRED 159), even with the variable exported earlier in the shell.
- **Gaps assigned, not hidden** (VAG (b)): the rows reach at most 3 of the 15 `star-*` prose arms, and 1b-vi-C owns
  the other 12; the echo and quote lowerings belong to 1b-vi-D's mini-audit. **Offered** (VAG (c)): state
  Q_U48 / Q_U57 as generated laws rather than 31 examples.
- **Next**: dialogue checkpoint with the owner (Stage 4 cadence), then 1b-vi-B (bump the stage to B; C1–C4
  go red; implement the caret-family refusal).

### Q_U59 settled, Q_U60 decided; 1b-vi-B shipped: `^-` / `^-k'` refuse a renamed ancestor with two runnable remedies, and the equivalences are generated laws — `332e16a2` (2026-10-14)
- **Why / decision**: owner at the A checkpoint — *"1: Ok as settled, with medium confidence · 2: fold it in ·
  3: ok"*. Ledgered: [Q_U59](../../../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u59) (where nothing can collapse,
  `*-` ≡ `*` and `*-_` ≡ `*_`; the medium confidence is given an object: the monotone cost and a revisit
  trigger), [Q_U60](../../../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u60) (the laws, placed as B's first step —
  my call, recorded as such). B's design target, mini-audit and VAG: [§5.P4e-1b-vi](../../../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#p4e-1b-vi).
- **What shipped**: the check sits in `branch-problem` (`parser.rkt`, block-close validation), after the
  positional check; TOTAL means `'collapse` / `(collapse-rename . k')`; the two remedies are step lists
  rendered by `pp-select-branch` (new edge parser → pretty-print, acyclic, +6 modules). 61 generated law rows
  (`^-`, `^-z`, `*-`, `*-_` over `t5`; `*-` over `v3`). Red: 16 rows; green after; mutation → the same 16.
  Battery + acceptance file 665 / 665; acceptance 88 / 88.
- **Surprise / correction**:
  - **My A table had a hole.** Rows ahead of the stage were asserted only to fail their target, and a refused
    right-hand side or a drifted pinned type also fails, so A's 31 pinned types were never verified on the
    committed stage. Fixed: every right-hand side is checked at every stage (mutation M3 caught).
  - **Wrote two ω arms with no test.** Probing found the ω LEAF reachable (`org{db^p.admins:name^-}`, row
    C6, pre measured with only the check disabled) and the ω ANCESTOR unreachable (DEFERRED 167), so the
    ancestor-side arms are kept, unpinned, and marked so in the code.
  - **A zero-power instrument, caught by its control**: my first module-closure script reported that
    `parser.rkt` does not reach `syntax.rkt`, which it requires directly (`module->imports` raised on an
    undeclared module and the handler swallowed it). Replaced by a text closure checked against three positive
    controls.
  - **Dates**: the session crossed midnight; Q_U59 / Q_U60 were first written as 2026-10-13 and corrected to
    2026-10-14 (the owner's answer arrived after `22994c62`, 10-13 11:11; `e3a30441` was 10-14 17:38).
  - `git commit` failed once on a transient `index.lock` (gone on inspection, no process holding it), retried.
- **Next**: owner checkpoint, then 1b-vi-C — the `collapsed` cont + the `*-` / `*-_` conts + the totality
  dispatcher + the 15 prose arms, landed INERT; stage stays B until D (C flips no surface row).

### 1b-vi-C shipped: the total-collapse machinery, inert, proven by injection — `6142d318` (design) + `3cbb1025` (code) (2026-10-14)
- **Why / decision**: owner — *"Let's proceed with Slice C per our Stage 4 Design Methodology
  (Implementation Protocol)"*. Design target and mini-audit committed before any code
  ([§5.P4e-1b-vi, 1b-vi-C](../../../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#p4e-1b-vi-c)). Two
  representation choices made inside Q_U58's M and recorded, not posed: the mark is a wrapper
  `(collapsed . c₀)` around the WRITTEN cont (so printing and naming read the step as written),
  and the two new spellings live in a printer-only pending table rather than a MINTED column.
  Q_U55's star arm and the parser's mark call moved to D, where red rows drive them.
- **What shipped**: a closed star-cont axis (4 conts, a raising classifier at the 5 readers); the
  mark (unmark ∘ mark = id, prints and names as written — law over 104 branches); ONE placement
  predicate at both twins' dissolve arms (placement emerged, as M predicted); `*-_`'s prefix at
  one seat; tail-arm guards in both twins; `select-fail` carries the star cont and the 13
  per-branch arms name the operator as written (render loop: every kind × every cont + missing).
  INJECTION: each D row's `*` spelling parsed by production, conts made total, every branch list
  marked, run through `process-command` — 53 D rows meet their D targets before the mint.
  670 / 670; acceptance 88 / 88; 7.97 s per run.
- **Surprise / correction**:
  - **A vacuous pass, found by counting.** X-type's `*` spelling is a parse refusal that matched
    its `*-` target; the harness passed it through untouched. Closed: lexeme rows excluded by
    name, any other unparsed row reads `VACUOUS` (proved by putting X-type back).
  - **A malformed mutation** (one `)` too many): a read error proved nothing; redone → red (19).
  - **A section scratch is not the battery**: my test defect in the 1b-iii render loop surfaced
    only in the battery. **A command that did not gate on `check-parens`** ran a probe against a
    non-compiling file. **The patch tool's fuzzy match dropped a word** from an existing comment
    (my `old_string` misquoted it); caught in the diff review, restored.
  - The census's first cut attributed by indentation and charged typing's dissolve arm to
    `walk-to-leaf`; its positive control caught it.
  - Measured design change: a MINTED column would have edited eight consumers D already flips.
  - `git commit` hit a transient `index.lock` again; nothing held it; retried.
- **Next**: owner checkpoint, then 1b-vi-D — the mint (see "What C hands D" in the D4 section).
