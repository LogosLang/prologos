# CIU 6 — track LOG (append-only, newest at the bottom)

CIU Track 6 — Anonymous Records, Collections & Path Selection. Entry shape is the dailies'
(`../../../principles/DAILIES_METHODOLOGY.org`): `### <outcome headline> — \`hash\` (date)` with
**Why / decision**, **Surprise / correction**, **Next**. The dailies' STATE head stays the
re-grounding surface and its sparse LOG points here. Opened 2026-10-13 under the per-track-log
convention (`../../README.md`); the series stub and the index of the flat documents of record
are in [`../README.md`](../README.md).

### Before this LOG: the journal of record 2026-07-05 → 2026-09-08 — pointer only
- **Where the history is.** Decisions: D4 §3, the ledger
  ([`2026-07-28_CIU_T6_PATH_SELECTION_D4.md`](2026-07-28_CIU_T6_PATH_SELECTION_D4.md),
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
  `*-` ([Q_U48](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u48), total collapse —
  ruled), the `*-_` decision (open), the cont-axis **totality dispatcher** (the six
  `select-star-cont` readers are binary tests on `'flatten-synth`; an unknown cont reads as
  bare `*`), and `typing-errors.rkt`'s prose column (15 formatters spelling `*`/`*_` per kind —
  the printer defect's twin, `#p4e-1b-v-c`). Two owner decisions come first
  ([Q_U52](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u52) §1–2): what total collapse
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
  not a commandment". Record: [`2026-10-13_CIU_6_P4e-1b-vi_GROUNDING_AUDIT.md`](audits/2026-10-13_CIU_6_P4e-1b-vi_GROUNDING_AUDIT.md);
  probes and outputs in `research/P4e-1b-vi/`. The branch was first fast-forwarded over 20 main commits
  (sweep + runner-queue merges, F3(a) in `substitution.rkt`/`type-lattice.rkt`) to `01ef2542`; battery 573
  test-cases, 663/663 with the acceptance test file, acceptance markers 88/88. Findings: (1) `^-` silently
  drops a re-keyed ancestor (`e3{a^p.b.c^-}` → `{:c …}`) while `^-_` honors it (`{:p-b-c …}`), unpinned and
  unused. `*-` is `^-` ∘ `*` (one operator suffix per segment), so the decision is one rule for both
  families. Posed as **[Q_U55](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u55)** (pending), options
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
  ([Q_U55](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u55)) with the reason (monotone waypoint;
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
  [Q_U56](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u56); the pre-existing type-territory
  messages ("has no arrow", a bare "Type mismatch") filed on main as **DEFERRED 168** (`b309f98e`).
  Then the owner asked for the `*-_` rule "worked out in examples and tradeoffs … with more examples":
  [Q_U57](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u57), ten cases (E1–E10) on five fixtures.
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
  [Q_U57](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u57). The 1b-vi row in D4's sequencing table now
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
  at [Q_U58](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u58). The Per-Phase Protocol's mini-design and
  mini-audit are written into D4 as [§5.P4e-1b-vi](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#p4e-1b-vi):
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
- **Why / decision**: the first sub-slice of [Q_U58](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u58)'s
  slicing: pins first. One row per behaviour, `(id spelling flips-at pre target)`, with every target
  measured from today's equivalent spelling (`research/P4e-1b-vi/probe-1bvi-p`). `1bvi-stage` is bumped as
  the first edit of each later sub-slice, so its rows go red before its code exists. Design and VAG:
  [§5.P4e-1b-vi](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#p4e-1b-vi).
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
  3: ok"*. Ledgered: [Q_U59](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u59) (where nothing can collapse,
  `*-` ≡ `*` and `*-_` ≡ `*_`; the medium confidence is given an object: the monotone cost and a revisit
  trigger), [Q_U60](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u60) (the laws, placed as B's first step —
  my call, recorded as such). B's design target, mini-audit and VAG: [§5.P4e-1b-vi](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#p4e-1b-vi).
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
  ([§5.P4e-1b-vi, 1b-vi-C](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#p4e-1b-vi-c)). Two
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

### 1b-vi-D-1 shipped: the level arms name the operators PRESENT — `b567b29e` (2026-10-14)
- **Why / decision**: owner — *"Ok to proceed (and would you think that passing the star through
  is our better option? If it doesn't cost us too much, it would seem to be more correct/accurate
  to me — do you have a challenge to that perspective?)"*. The challenge: a LEVEL has no single
  star (`env{prod^.db* dev.db*-}`), so passing one would be wrong in a mixed block. The decision
  that survived: pass the operators PRESENT (a list), and scope each claim to the family it was
  measured on ([D4 §5.P4e-1b-vi, 1b-vi-D](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#p4e-1b-vi-d)).
- **What shipped**: `select-fail`'s field is a list; `star-dup-key` carries every star at the
  level, `star-l4-mixed` its branch's; both arms speak per family. M-one (pass one star) red on
  exactly the mixed row; M-none red on three. 670 / 670.
- **Surprise / correction**:
  - **A 1b-iv sentence was false for most of its population** — "dropping the `*` does not help
    either" (probe-1bvi-x: true for 1 of 4 shapes). Replaced by the mechanism, pinned absent.
  - **My design text repeated it** ("the non-total sentence keeps its measured claim") and my
    first X-dup-mix row required it — the measurement came before the commit, not after.
  - **The regexes passed a false message**: the first mixed L4 render spoke the `*` clause over
    `*-`. Found by reading the render; now a guard with shown power.
  - **C's ordinal-head defect** (`ov{0.a.b*-_}` → `@[…]`, not `{:a-b-x 1}`), determined by
    Q_U48 + Q_U49, Q_U57 and P3c's pin — not a new question. The law generator's fixture set
    (key-headed only) is the blind spot.
  - Two malformed edits stopped by the `check-parens` gate; the runner takes one `--tests` per file.
- **Next**: 1b-vi-D-2 — FIRST the ordinal-head fix (rows back + an ordinal fixture in the
  generator), then the mint.

### 1b-vi-D-2a shipped: an ordinal head is transparent under a collapse — `035aea42` (design) + `84beb15a` (2026-10-14)
- **Why / decision**: owner — *"Excellent, let's proceed to D-2 per our stage 4 design methodology"*.
  D-2 split into D-2a (the ordinal-head fix, still inert) and D-2b (the mint); design first
  ([D4 §5.P4e-1b-vi, D-2](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#p4e-1b-vi-d2)).
- **What shipped**: one `select-branch-total-collapse?` predicate; both twins' ord-head arms
  descend transparently under a total collapse; the law generator borrows the base subject's
  equivalents (`ot{0.X}` ≡ `t5{X}`, four families; `ov3`), 168 rows. 670 / 670.
- **Surprise / correction**: the red step raised at C's C-5 guard (`ot{0.a*-}`) — loud, but a
  production whole-file abort; my C note "ordinals make no layer" was half right. My C VAG also
  missed DEFERRED 144 (the grammar for the whole star family, filed at 1b-v-B2b): D owes no grammar.
- **Next**: 1b-vi-D-2b — the mint.

### 1b-vi-D-2b shipped: THE MINT — `*-` and `*-_` are live — `9743e93e` (2026-10-14)
- **What shipped**: the two rows join the one star table (C's pending table retired); the parser
  marks every branch at `segment-select-items`' one success return; Q_U55's star half with
  remedies that run; Q_U56's guided `*->` from the selection consumer; pins flipped; the arrival
  gate runs ∀ minted lexeme; PARITY parser = injection. 173 rows; 670 / 670; 7.65 s per run.
- **Surprise / correction**:
  - **Q_U56's predicted type-territory text was wrong** (the row had been written from the
    prediction); the measured message is 1b-v's star-family one, true and more specific.
  - **"put a space" is not a remedy** (`x{a*- > b}` still fails), and the consumer cannot tell
    glued from spaced; `a*->b` is one token. Three shapes, each with a true message.
  - **M-mark**: without the mark a minted `*-` is a whole-file ABORT (C-5's guard raises), not a
    silent re-nest — loud as designed, but an abort; unreachable while the mark is pinned.
  - **M-keep** confirmed C's handover: B's remedy would have offered `t5{a^.b^q.c^*}` (refused).
  - My `select-star-cont-of #t #f` in the keep remedy would have rendered `*-` — caught on
    re-read before the first run. The deps check first ran a nonexistent path and printed 0 —
    read as "did not run", re-run at the right path: 375 = B's.
- **Next**: owner checkpoint — the 1b-vi verify, the suite gate, the checkpoint merge to main.

### Q_U61 posed + acceptance §M (2026-10-14)
- **Why / decision**: owner — *"Let's open up what the behavior looks like for this `ot`… numerous
  worked examples … checked against our original design spec and intents. And yes we should add
  all new syntax developed into the acceptance file."*
- **Q_U61 (posed, pending)**: probe-1bvi-ac (45 lines) measured a plain `*` under an ordinal head
  against spec §3.3, Q_U47 and Q_U49. Today splices at depth 1 (Q_U49's decided seat B, 9 pins) and
  wraps at depth ≥ 2 (no decision, 0 pins — a seat-B predicate that only sees sₙ★ right after the
  ordinal). Options S (splice through; what Q_U47/Q_U49 say) and W (always wrap; honest nesting);
  recommendation S. [D4 Q_U61](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u61).
- **Acceptance §M**: 20 live forms, 3 commented refusals with measured messages; 108 / 108.
- **Surprise / correction**: the corpus check passes a FILE argument as zero files — re-run on
  directories (+6 ERROR nodes, inside the ratchet). `server.ssl*->port` splits at `>` while
  `mn{a*->b}` fuses — each shape already gets the message true of it.
- **Next**: owner decision on Q_U61; then the rest of the 1b-vi verify, the suite gate, the merge.

### 1b-vi-E shipped: Q_U61 = S — `67979e59` (decision + design) + `a41f8362` (2026-10-14)
- **Why / decision**: owner — *"Reading S looks good to me."* An ordinal head passes a keyless star
  landing through at every depth ([D4 Q_U61](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u61),
  [1b-vi-E](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#p4e-1b-vi-e)).
- **What shipped**: `select-step-names-no-key?` inside `select-steps-yield-bare-join?`; one
  transparent arm per twin (D-2a's arm and seat B's splice deleted); the dup refusal names S's cost
  and the `^` tuple spelling via a `select-fail` field `ordinal`. Stage E; 187 rows; 694 / 694;
  acceptance M16/M17, 112 / 112.
- **Surprise / correction**: S REMOVED code (two arms); the mutations prove the one arm carries all
  three cases. probe-1bvi-ad found the generic dup text true but silent on why two positions meet
  and on the tuple remedy — fixed in the slice, as the S cost analysis promised. My message-row
  regexes were case-wrong on the first run (test defect, fixed). One more transient `index.lock`
  (no holder; retried).
- **Next**: the rest of the 1b-vi verify, the suite gate, the checkpoint merge to main.

### 1b-vi verify: three BLOCKING defects found and fixed — a whole-file abort, a twin value/type split, ordinal-level prose false on most of its population — `0988a4f0` (2026-10-18)
- **Why / decision**: the owner — *"Let's proceed."* — to the verify, the suite gate and the checkpoint merge.
  Four read-only lenses at `64368197` (VT twins, VS silent answers, VM message truth, VI instruments), adjudicated
  on the main thread: 36 raw → 34 survive, 2 killed
  ([D4 §5.P4e-1b-vi verify](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#p4e-1b-vi-verify)). The standing
  question ("one seat, not its sibling") answered YES five times.
- **What shipped**: VF-1 a parser refusal of a total collapse under an ω ancestor (was a whole-file abort;
  DEFERRED 167's waypoint, both collapse families); VF-2 `asort` threaded through five reduction helpers
  (a value/type split at 0 errors); VF-3 one ordinal fact for both level gates, every sentence scoped to its
  measured population, every remedy run; VF-4 / VF-5 and nine more. Stage V: 250 rows (106 hand, 144 law), a
  size pin predicted before the run; ten mutations, each red on its own pins; 695 / 695; acceptance 112 / 112.
- **Surprise / correction**: my own E work. E's VAG said the refusal "names S's cost"; it did so for the one
  population probe-1bvi-ad measured, and six sentences in the two level arms were false elsewhere. And three
  comments claiming a shape unreachable or a law "by construction" were wrong (VF-1's ω route, VF-2's
  "threaded", E's `ot{0.X}` ≡ `t5{X}` over sub-blocks → Q_U62). The lenses' L1-…L4- ids were renamed VT/VS/VM/VI
  (they collided with the fusion law L1 and the mixing rule L4). One unattributed extra mutation red, consistent
  with DEFERRED 170's race (unmerged here).
- **Next**: Q_U62 posed (pending, owner). Merge main into the branch, the full-suite gate, the checkpoint merge.

### Main merged in (first bring-up) `9d0dea51`, then the full-suite gate: 10 426 / 502 files, all pass, reconciled file by file (2026-10-18)
- **Why / decision**: the owner — *"Let's proceed."* — verify → merge main in → suite gate → checkpoint merge (the plan
  on main's dailies, `9533811d`).
- **What shipped**: the prediction held (made read-only while the lenses ran): one file changed on both sides,
  `tests/test-path-selection.rkt`, merged clean with main's three `#:exists 'replace` → `'truncate` hunks (DEFERRED 170);
  the merged tree differs from main in exactly the branch's 99 files, and the only branch file the merge moved is that
  one, by exactly main's hunks; eight shared modules' `.zo`s equal main's checkout. **Gate** (`--all` at `9d0dea51`):
  **10 426 tests, 502 files, 506 units, all pass** (`test-path-selection` sharded ×5). Reconciled against the two
  recorded full runs of main-equivalent code that total main's 10 394 (PAR 4 `931b327b`, PPN 4C `39eba17d`): the ONLY
  per-file differences are the branch's two test files — `test-path-selection` 573 → 581 (+8), `-acceptance` 90 → 114
  (+24); all 500 others equal to the test. Acceptance `run-file --check` 112 / 112; `update-deps --check`: "The cached
  derivation equals a full rescan. ✓" (main's SW-24 replaced the mismatch count).
- **Surprise / correction**: (1) I committed the merge before the gate; the procedure keeps it `--no-commit` so a red
  gate is a `merge --abort`. The gate was green, and the message is left unamended because the recorded run cites
  `9d0dea51`. (2) The first acceptance smoke-run died on `instantiate-linklet: mismatch … process-file31.1`: main
  changed `driver.rkt`'s `process-file`, and my rebuild targets left `tools/run-file.rkt`'s `.zo` stale. A build-target
  omission, not a defect; after a main merge every tool to be run belongs in the `raco make` list. (3) The runner's
  `total_wall_ms` reads ≈ 8 s in every recorded full run (7 948, 8 403 in the references); per-file walls sum to 77.3 s —
  not this run's wall. (4) The verify's one unattributed mutation red (Q_N4, under VF3-collapse) stays unattributed;
  main's DEFERRED 170 fix is now merged, and this gate ran the file sharded ×5 green.
- **Next**: the checkpoint merge to main; the DEFERRED "on the branch" passages flipped to the merge hash; dailies.
  Q_U62 stays pending (owner).

### CIU 6 checkpoint merged to main: `83fe4fb4` — 1b-vi through its verify (2026-10-18)
- **Why / decision**: the owner — *"Let's proceed."* — the checkpoint closing the verify → gate → merge plan.
- **What shipped**: `83fe4fb4` on main (parents `74f70310` main, `32fe9c52` this branch), made in a throwaway
  `--detach` worktree and fast-forwarded into main's checkout (main's 16 owner-WIP files untouched: no overlap with the
  branch's 99). Its tree equals the gated tree (`b630da40` both), so the gate above IS this merge's gate; the clean
  merge tree, built with the limit (`reduction_rkt.zo` fingerprint equal to this branch's), ran the merged test files
  plus main's temp-file guard targeted: **697 / 697**, acceptance **112 / 112**. No instrumentation to triage (no
  tools, 0 environment knobs; the census finds main's own opt-in). The branch fast-forwarded to the merge. On main:
  the five DEFERRED passages saying "until the next checkpoint merge" (167 ×2, 168, 179, 180) and two probe locations
  now cite `83fe4fb4`; the dailies carry the STATE line and a pointer.
- **Surprise / correction**: none beyond the gate entry's.
- **Next**: [Q_U62](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u62) (an ordinal head then a sub-block; lean
  S+, medium) — pending, owner. Then the 1b-vi close: the stage table's `pre` column and `1bvi-stage` retire. Then
  P4e-2.

### Q_U62 opened with worked examples; my lean corrected S+ → B; SB-1…3 found (2026-10-18)
- **Why / decision**: the owner — *"Let's open what Q_U62 is with many, multiple worked examples … walk through the
  design space in played out examples."* Still PENDING; nothing decided.
- **What shipped**: probe-1bvi-ae (74 lines, nine families: the VS-3 shapes, key-head transparency, star-free ordinal
  sub-blocks, factored vs unfactored, a realistic `fleet` subject, the bare-number control, every star family, the star
  outside the braces, heterogeneous per-element records) and the
  [Q_U62 ledger entry](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u62) rewritten around it: five options (B, S+,
  S1, F, R), F refuted by measurement (factoring across an ordinal prefix is not a law), S1 and R rejected with reasons.
  Every quoted value checked mechanically against its probe line (39 values, 0 mismatches; three seeded errors caught).
- **Surprise / correction**: my posing lean (S+, medium; also in the checkpoint entry above) read Q_U47's remainder
  ACROSS the sub-block. Q_U47 computes it in the star's own branch and Q_U49 splices into the ENCLOSING level — the
  sub-block — so B is what the rules on record already say. New lean **B, medium-high**. And the measurement corrected a
  second expectation: `fleet{0 1}:{…}` spells per-element records for a subset, so S+ loses only records of DIFFERENT
  shapes per element (ae:67). Side findings: **SB-1** the dup refusal's "end EVERY branch with `^`" remedy is false when
  an element has several branches (ae:71 — a 4-tuple of branches), a VF-3-class defect in my `0988a4f0`, its fix
  depending on Q_U62; **SB-2** the all-ordinal L4 refusal omits the factored sub-block; **SB-3** `vhm{0.{0*}}` gets a
  misleading "`*` is postfix" message (pre-existing).
- **Next**: the owner's decision on Q_U62; then SB-1's fix under it.

### Q_U62: owner lean B (slight); the joint lean critiqued — B's law measured unconditional, 98/98; decision next — `990fafb7` (2026-10-19)
- **Why / decision**: the owner (2026-10-19 00:22) — *"I do think B has a slight lean than the S+ reading."* A lean, so
  ledgered OWNER LEAN under critique; it agrees with mine, so the stance is joint and was critiqued as such
  ([D4 Q_U62 critique](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u62-critique), UC-1…9).
- **What shipped**: probe-1bvi-af (generated, 102 pairs): `x{0.P.{X}}` ≡ `y{P.{X}}` WRAPPED holds on 98/98 comparable
  pairs — six star families × 15 positions/assignments plus vector contents; 4 pairs refused identically on both sides.
  The step-chain control fails the wrap where S passes, so the comparison discriminates. Under S+ (derived) the same
  grid splits 26 / 72 — a two-case law. Critique: for B, UC-1 (the law) and UC-2 (spec §3.3/§7.5: honest nesting
  "holds because branch count becomes runtime-known"); against, UC-3 (the silent surprise) and UC-4 (S's scope must
  be stated); UC-5 weighs R, the monotone-migration hedge.
- **Surprise / correction**: none against the record; my lean firms from medium-high to high.
- **Next**: the owner's decision — B, or R as the waypoint. Then UC-7 (B as generated laws), UC-8 (SB-1/SB-2 under B),
  UC-9 (S's scope in Q_U61 + a spec note).

### Q_U62: R worked out beside B — each refused shape's two readings both spellable today (26/26 + 26/26); decision still next — `a593fdc6` (2026-10-19)
- **Why / decision**: the owner (2026-10-19 01:11) — *"I'd have to see R worked out alongside B in multiple, clear,
  worked examples to make a weigh-in on either. I don't have an intuition for what R is, otherwise."*
- **What shipped**: probe-1bvi-ag (80 lines) and the ledger section
  [R worked out beside B](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u62-r): R defined as refusing exactly
  where B and S+ disagree; eleven refused programs side by side (B's value; R's refusal; B's meaning and S+'s meaning,
  each spelled under R and measured); over R's whole refused population in af's grid the one-component recipe
  `x{N}:{P.{X}}` reproduces B 26/26 and the unfactored chains reproduce S+'s reading 26/26. R's message drafted
  (proposed, not implemented); a migration table; R's costs; R2 rejected. 34 quoted values checked, 0 mismatches.
- **Surprise / correction**: the measurement reframes the decision. On these shapes B makes `x{N.{X}}` a synonym for
  `x{N}:{X}`, S+ makes it a synonym for the unfactored chains, and R leaves it unassigned. B's only extra
  expressivity over R is records of different shapes per element (ae:67).
- **Next**: the owner's decision — B, S+ or R.

### Q_U62 DECIDED = B (braces scope a landing); the decision critiqued on the owner's four dimensions — `93f36b3a` (2026-10-19)
- **Why / decision**: the owner (2026-10-19 01:33) — *"On the language design front, I want to balance ergonomics,
  expressivity, composition, and correctness. I think I'm landing B still as well. Happy for a critique or pushback on
  these dimensions and choices, but if B is clear on this, then let's go with that for now."*
- **What shipped**: [the decision](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u62) and its critique
  ([DC-1…7](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u62-dc)), measured by probe-1bvi-ah: under B the
  SPLICED reading is also factored, `fleet{0.{meta^.id net^.tls}*}` → `{:n 1, :port 443}` ≡ the unfactored chains
  (DC-1: B's rule is one sentence — a star inside the braces lands in the element, a star after them escapes); L★
  (`x{p* q*} ≡ x{p q}*`) holds at key heads and with a kept key but fails across an ordinal head's braces exactly where
  B and S+ disagree (DC-2, a side condition for P5 → DEFERRED 115 addendum); `x{N.{X} M.{X}}` ≡ `x{N M}:{X}` (DC-3, a
  normal-form question for P5, DC-7). Verdict: B is clear on all four dimensions.
- **Surprise / correction**: DC-2 is a real cost I had not stated before measuring — B's star-position semantics is
  exactly what breaks L★ at one shape. And DC-4 corrects a tempting overclaim: S+ would not be riskier to build (one
  widened shared predicate); B's correctness edge is that it needs no rule. Process slip, caught before commit: a
  scripted ledger edit truncated the D4 (−8 716 lines, uncommitted); restored from `1d254b21` and redone with a size
  check.
- **Next**: UC-7 (pin B as generated laws), UC-8 (SB-1/SB-2 under B), UC-9 (S's scope), the typing-core comment; DEFERRED
  115 addendum + SB-3 filing on main.

### P4e-1b-vi-F — Q_U62 = B pinned; SB-1 / SB-2's remedies under B — `3fcb720a` (2026-10-19)
- **Why**: the owner decided B "for now". B was already the code's behaviour, so F makes it a
  contract and corrects the two refusals whose remedies were false or missing under B (UC-7, UC-8, UC-9).
- **What shipped**: [§1b-vi-F](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#p4e-1b-vi-f):
  - 50 `sub-block` laws + 23 hand rows (stage F; size pin 129 / 194, predicted).
  - The dup refusal no longer offers `^` where an element heads several branches. It kept the BRANCHES
    apart: `fleet{0.meta^.id 0.net^.tls 1.meta^.id 1.net^.tls}` → a 4-tuple. It now offers grouping
    each element's branches, only where that resolves the collision (pairwise-distinct ordinals).
  - The all-ordinal L4 refusal offers grouping where the rests can be wrapped.
  - S's scope is stated in Q_U61.
  - Acceptance M18.
  - Every remedy was run per family (`*`, `*_`, `*-`, `*-_`; probe-1bvi-ai, 40 lines).
  - Battery + acceptance 701 / 701; run-file --check 116 / 116.
  - Mutations F1–F7 each red on their own rows; S+ at either twin seat turns 64 / 63 red.
- **Surprise**: SB-4, a pre-existing VF-3-class defect. On a vector-only path, the all-ordinal L4 refusal
  offers two remedies that cannot be spelled there ("keep a key", and `vhm{0.{0}^ 0.{0}}` is a parse
  error). It is filed with SB-3.
- **Self-correction**: `'cross` was first written as "more than one ordinal", which would offer a grouping
  that still collides (`fleet{0.meta^.id* 0.meta^.id* 1.meta^.id*}`). Tightened before the commit and
  pinned (SB1-c1b, F3).
- **Filed on main `e751736c`**: the DEFERRED 115 addendum (DC-2, L★'s side condition) and DEFERRED 185 (SB-3 + SB-4).
- **Next**: the 1b-vi close (the `pre` column and `1bvi-stage` scaffolding retire), then P4e-2.

### 1b-vi close, item 1: DEFERRED 185 (Q_U46's ordinal-star gap, one text; remedies the branch can spell) + a buried panic — `a9788c0a` · `55b7df16` (2026-10-19)
- **Why**: the owner approved the close ("Ok to proceed on 1"), in four items: 185; the star family in the grammar
  (144 / 179 / 180); retiring the stage scaffolding; the close note, suite and checkpoint.
- **What shipped**: [§1b-vi CLOSE](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#p4e-1b-vi-close):
  - A star right after an ordinal head (`vhm{0*}`, `vhm{0.{0*}}`) now gets Q_U46's refusal from one
    definition shared with typing.
  - The all-ordinal L4 offers each remedy only where every passing head can spell it; otherwise
    "drop each `*`", which runs.
  - `ot2{2}*` no longer prints a runtime miss as a value (a panic subject propagates).
  - Red steps were run against the OLD code; mutations G1–G4 and the panic arm each turned their own rows
    red; 701 / 701.
- **Surprise / correction**:
  - 185 was wider than filed: one meaning had five messages, depending on spelling. My SB-3 sentence ("Q_U46's
    gap 1 made a star after an ordinal a guided error; this spelling misses it") was written from the record:
    only the bracket spelling reached it. Struck in the ledger.
  - The reader seats (`vhm.0*`, `vv:0*`, `y.a.0*` → bare "Unbound variable"; `y{a.0*}` → "stray `.`") go to
    P4e-2, which opens the same recognizer.
  - The panic was found while measuring P4e-2's question, not by any 1b-vi row.
- **Next**: item 2 (the grammar).

### Q_U63 opened: does ravel `.*` add expressivity, or only notation? (PENDING) — docs commit on the branch (2026-10-19)
- **Why**: the owner — *"On 2. I want to open up whether this syntax/spelling offers any true increase in
  expressivity?"* (2026-10-19). Item 3 (the rest of P4e) is to be walked through together, later.
- **What**: [Q_U63](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u63), probes `research/P4e-2/probe-p4e2-a`
  / `-b`.
  - In the whole language ravel is notation (Felleisen: a fixed context, `concat`).
  - In the selector language it is a real increase, by exactly one primitive: join at the focus = bind with
    an identity step. That step is missing at three places: a runtime-length subject, an element reached by
    an ordinal (Q_U46's gap), and a Map's values.
  - Options: K (`.*`), E (an identity step ε), A (APL full ravel), N (library only).
  - My lean: E over K, medium.
- **Surprise / correction**:
  - Under Q_U40's OUTER rule a named step cannot ravel (`w{v*}` is a 1-tuple of `v`). I expected `w.v*` to
    ravel and said so in chat before measuring; it does not.
  - RV-1: Q_U40's record states `vv:{0 1}*` → `⟨1 2 3 4⟩` as falling out; measured, it is refused as
    not-yet.
  - RV-3: `.*` already means "unrestricted" in `selection` declarations.
- **Next**: the owner's answer on Q_U63; P4e-2's grounding audit waits for it.

### Q_U63 worked out: five options over eleven intents, against the principles; a fifth option (J, `x:*`) found; lean revised E → J — docs commit on the branch (2026-10-19)
- **Why**: the owner — *"I think it would do us well to work out these options in worked examples, and consider their
  design tradeoffs against our design principles and expressivity. I'm still not seeing a clear choice among what has
  been considered."*
- **What**: [Q_U63, worked out](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u63-worked) with probe
  `research/P4e-2/probe-p4e2-c` (29 lines):
  - each intent's value measured through today's nearest spelling;
  - each option's spelling for it;
  - a trade-off table against the principles as worded;
  - the laws each option makes checkable.
- **Surprise / correction**:
  - Writing the spellings out produced option **J: `x:*`**, a broadcast of the identity, then join. It is built
    entirely from `:` and `*` under Q_U40's rule, with the identity kept as an IR step, so `syntax.rkt:891`'s
    one-step invariant holds. It removes K's glyph collisions and E's do-nothing token.
  - My lean moves from "E over K" to **J, medium-high**; the old lean is struck in the ledger.
  - A cannot express a one-level ravel at runtime length.
  - RV-4: `tw{teams:m*}` is refused in a block where the path form works; that is DEFERRED 167's class
    (addendum on main).
- **Next**: the owner's decision on Q_U63; 1b-vi close item 2 (the grammar) proceeds meanwhile.

### Q_U63: OWNER LEAN J ("I'm liking J. It reads well to me."); the joint lean critiqued (JC-1…8), seven sub-decisions surfaced (JD-1…7) — docs commit on the branch (2026-10-19)
- **Why**: the owner's answer is a lean ("liking"), so it is ledgered as a lean under critique, joint with mine.
- **What**: [Q_U63 critique](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u63-jc), probe
  `research/P4e-2/probe-p4e2-d` (16 lines).
  - J's substrate is measured:
    - a broadcast over a Map comes back KEYED (`mh:x` → `{:a 1, :b 2}`), so `m:*` joins exactly as
      `m{a b}*` does;
    - a broadcast over a tuple works per position;
    - an ordinal step followed by a broadcast works;
    - `:*` is no keyword, and every near-miss is a bare "Unbound variable", so J breaks nothing.
  - Against J:
    - it elides the broadcast's step in the surface (the IR keeps `(@bcast ε)`);
    - it needs guided refusals for five near-misses;
    - block position waits on DEFERRED 167;
    - it supersedes Q_U26's spelling, though not its meaning.
  - Laws to pin are listed.
  - JD-1…7 (what `.*` becomes; `x:*-`; the block waypoint; near-miss messages; full ravel; ε in PF; the
    `selection` form) are ledgered with leans.
- **Next**: the owner decides J (and takes or defers the JDs). 1b-vi close item 2 (the grammar) proceeds.

### Q_U63 DECIDED J (ravel is `x:*`) and JD-1…7 decided at their leans, as a batch — docs commit on the branch (2026-11-02)
- **Why / decision**: the owner (2026-11-02 12:06) — *"OK to take the leans in a batch. Let's proceed accordingly."* —
  after the 2026-10-19 lean ("I'm liking J. It reads well to me.").
- **What**: [Q_U63](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u63) is marked DECIDED with the decision stated;
  the JD header is DECIDED.
  - [Q_U26](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u26) gets a "spelling superseded" callout; its
    meaning stands.
  - Q_U40's unmeasured `vv:{0 1}*` → `⟨1 2 3 4⟩` line is struck with a correction callout (RV-1).
  - The P4e tracker row and §5.P4e's ravel bullet name `x:*`.
  - **P4e-2 is re-scoped**: the `.*` retirement (`.*` becomes a guided refusal naming `x:*`), plus the `:*`
    production, ε as `(@bcast ε)`, the JD-2…4 messages and waypoint, the laws, and DEFERRED 185's reader seats.
  - Spec departures (§2.1 and §3.5) are proposed, not applied.
- **Re-grounding after a two-week gap**: main moved 23 commits, all `DEFERRED.md` / dailies (REL 2, PM, BSP-LE 3).
  No code changed, so the code gate carries over. Nothing new is addressed to CIU 6. DEFERRED 198 (CIU-owned, filed
  by REL 2: a panicking `:check` printed as a value) is the buried-panic class fixed for selection at `55b7df16`; it
  gets a cross-reference on main.
- **Next**: 1b-vi close item 2, the star family in the tree-sitter grammar (DEFERRED 144, with 179 and 180).

### 1b-vi close item 2 — the star family in the editor grammar (DEFERRED 144), with 179 and 180 — `04e3c5c5` (2026-11-02)
- **What**: [§ close-2](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#p4e-1b-vi-close-2).
  - **144**: `flatten_step` reads `*`, `*_`, `*-` and `*-_` as one token, `token.immediate(prec(1, /\*[-_]*/))`.
    Before, the closer seat parsed `cfg{db}*_` as an application to `_`, an error-free wrong tree. The
    `prec` is load-bearing: corpus test 54 broke without it.
  - **179**: Q_U56's guided `*->` text now reaches the closer, dot and broadcast seats, from one arm in
    `parse-list`. The fold leaves the `>` as a sibling argument, outside the braces, where the item arm cannot
    see it.
  - **180**: the arrival instrument compares the lexeme (`'split`), and the "is ONE token" pins compare
    `(lexeme . type)`.
- **Tried, not shipped**: ordinal-headed branches in the grammar. Seven formulations each fix the acceptance file
  (E43/M4 → E35/M0) and make `foray.prologos` worse: its invalid L957 (the compiler says `Unbound variable`)
  becomes a 251-line ERROR. That is error-recovery churn, and it is filed as DEFERRED 205.
- **Found**: the corpus gate has failed on this branch since `3fcb720a`, at MISSING 75 > 71. The +4 are M18's
  `{0.{…}}` lines, and no hook runs the gate. This was my miss at F.
- **Gates**: 702 / 702 (battery + acceptance + hygiene); 60 / 60 tree tests; grammar A/B 0 better / 0 worse / 142
  unchanged; stage H red against the old parser; mutations M1–M4 and the 180 mutation each red on their own rows;
  dependency cache verified.
- **Measurements**: `research/P4e-1b-vi/close/` — `tsg-close2.txt`, `probe-179` (with `.pre-fix.out`), `probe-957`.
- **Correction**: the code commit's first message (`9cfa3dcb`, amended before any citation into `04e3c5c5`) said
  four new corpus trees were red on the old grammar. Three were; the fourth is a control that passes on both.
- **Next**: close item 3 (retire the stage scaffolding; approved with the close, "Ok to proceed on 1"). The owner's
  decision on the corpus budget (raise to 75, citing 205, or hold the checkpoint) is needed before item 4 (merge
  main in, full suite, checkpoint).

### 1b-vi close item 3 — the stage scaffolding retires; the parity pin becomes a law over its own domain — `3f2db4ca` (+ the corpus budget `a7dcde7d`) (2026-11-02)
- **Why / decision**: the owner (2026-11-02 17:36) — *"OK with lean on (a). Let's proceed with the Next."* So (a)
  the corpus budget is raised 71 → 75, naming DEFERRED 205 (`a7dcde7d`; the gate PASSes), and item 3 proceeds.
  Item 3 was approved with the close ("Ok to proceed on 1"; the "walk through together" was about the later P4e
  items, re-read from the 10-19 exchange).
- **What**: [§ close-3](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#p4e-1b-vi-close-3).
  - Retired: the stage constant, FLIPS-AT and PRE (rows are `(ID SPELLING EXPECT)`), the pre-mint classes, and C's
    injection batch.
  - The parity pin is now the law `parse(*-) ≡ totalize(parse(*))` over every total-star row the parser reads as
    a selection: 81 → 113 rows, size-pinned. It held on all 32 new rows at once.
  - The remedy check covers every refused row that offers remedies.
  - Plus [§ what 1b-vi shipped](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#p4e-1b-vi-shipped), the close note (item 4's first part).
- **Evidence**:
  - Equivalence by mechanical dump: 346 / 346 rows identical, and the old domain ⊆ the new one
    (`research/P4e-1b-vi/close/retire-*`).
  - Power: three mutations, each red only where intended.
  - 702 / 702; dependency cache verified.
- **Surprise / correction**:
  - The first run of the size-pin mutation was contaminated by the previous mutation of `parser.rkt`, which my
    loop had not restored between files. It was discarded and re-run alone; the record cites only the clean run.
  - My first D4 draft double-unescaped braces and printed `{:m {:x Int} :n {:y Int}`. A brace-balance check
    caught it before the commit, and the quoted values were then checked against the dump.
- **Next**: item 4. Merge main in (`--no-commit`, gated), run the full suite, then the checkpoint merge to main.

### 1b-vi close item 4 — main merged in, the full suite gate: 10 431 / 502 all pass, exactly as predicted — `a28d648c` (2026-11-02)
- **What**: `git merge --no-ff --no-commit main`, covering 61 commits since `ab41836c`.
  - They are docs and registers, the BSP-LE series move (comment-path rewrites in `decision-cell.rkt`, two micro
    benchmarks and one example), and PAR 4's O-16 probe.
  - No file changed on both sides. The staged set equals main plus exactly the branch's files, and the merge left
    the branch's files untouched.
- **Prediction before the run**: main's code gate (`83fe4fb4`, 10 426 / 502, carried over by every later
  checkpoint) plus `test-path-selection` 581 → 582, plus `test-path-selection-acceptance` 114 → 118 (the acceptance
  file's M18; its test file is unchanged) = 10 431 / 502.
- **Gate**:
  - `--all --force-rerun`: **10 431 tests, 502 files, all pass**, 34 s wall with 18 workers (80.5 s summed per
    file). Reconciled file by file against the `9d0dea51` record: exactly the two predicted files differ.
  - Battery 702 / 702; `run-file --check` 116 / 116.
  - Tree-sitter corpus gate: PASS at 75.
  - `.zo` fingerprints of four modules neither side changed match main's checkout.
- **Next**: the checkpoint merge to main, from a throwaway worktree. The merge tree must equal this tip's tree. Then
  the DEFERRED citations on main move from "reaches main at the checkpoint" to the checkpoint's hash.

### CHECKPOINT MERGED TO MAIN — the 1b-vi slice closes — `d2ad3dad` (2026-11-02)
- **What**: `ciu6-path-selection` at `9f5a882e` was merged into main (`ce489cfd`) from a throwaway detached worktree.
  The merge tree equals the gated tip's tree (`850ee147…`), and everything after the gate (`a28d648c`) is docs
  only, so the full suite at the gate (10 431 / 502, all pass) is this merge's gate.
- **Verification**:
  - In the throwaway tree: a build with the limit; `.zo` files for reduction, parser, typing-core, unify and driver
    are byte-identical to the gated tree's; battery 702 / 702; `run-file --check` 116 / 116.
  - Main's checkout fast-forwarded. The owner's 16 WIP entries are unchanged (none is a `.rkt`, none overlaps the
    checkpoint's files, and no racket process had its cwd there). After a rebuild it shows the same `.zo` and
    702 / 702. The branch fast-forwarded to `d2ad3dad`, and the throwaway worktree is removed.
- **On main**: DEFERRED `1f96d5da` flips every CIU 6 "on the branch / reaches main at the checkpoint" citation to
  `d2ad3dad` (144, 179, 180; the addenda to 115, 167, 185, 198; 205, which also records the budget decision).
  Dailies `1d40da0f`.
- **Next**: P4e-2, which builds J: `x:*`, `.*` as a guided refusal naming `x:*`, the near-miss messages and the
  `x{a:*}` waypoint (JD-2…4), and DEFERRED 185's reader seats. It opens with a grounding audit. After it, the rest of
  P4e (transpose, disclose, DEFERRED 63, keyword projection) is walked through with the owner.

### P4e-2 OPENED — ravel `x:*` (Q_U63 = J): design target, mini-audit RA-1…13, the sub-slice plan; one scope question to the owner — `5876569b` (2026-11-03)
- **What**: per the Implementation Protocol's per-phase steps 1–2, the mini-design and the mini-audit are written into D4
  [§5.P4e-2](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#p4e-2), not into a separate audit file (the protocol: "Not in
  dailies, not in separate per-phase audit files"; the 1b-vi audit file predates my reading of that line). Probes at
  `5876569b`: `probe-p4e2-e` (60 results), `reader-dump` (68 spellings), `inject` (IR injection), `census-p4e2` (power-checked).
- **Why it is small**: J needs no new rule. The keyed twin `values:k*` already carries every continuation J needs (RA-2). The
  reader seat is a third case of the `:` gate's positional rule (RA-1), and ε inside `(@bcast ε)` reuses the broadcast's whole
  container dispatch (RA-3). The "retirement inventory" is empty: 0 production / owner-WIP hits and, of 54 test lines any
  pattern hits, 0 expression-position pins (RA-4).
- **Surprise / correction**:
  - **DEFERRED 185's addendum misclassified `vv:0*`.** It listed `vv:0*` among the spellings that "missed" Q_U46's refusal. By
    Q_U46 a broadcast contributes a layer, so `t3:0*` has a meaning, and the twins already compute it: the injected
    `(@bcast 0) (@star flatten)` gives `@[1 2 4]` = `t3:0{0 1}*` (RA-7). Corrected on main.
  - **DEFERRED 105's ⛔ verdict re-derived** (RA-8): `x.0*` now wants a refusal (Q_U46 postdates 105), and `xs:0*`'s star can ride
    the broadcast keyword payload like `:k*`. Conjecture until built.
  - **The fact row is the one silent position** of J's 3 → 1 item-count change (RA-9): today `|| "x" values:*` splays into
    3 rows; after the mint it holds one `unknown` term, exactly what the keyed twin `values:k` does today. DEFERRED 192's
    fix covers both.
  - **The `.**` message has offered `xs:*` since `25f3f22d`**, a template accident (RA-5).
  - **My first census was wrong twice, and the power checks caught it**: `|` served as both field separator and ERE
    alternation, and a brace pattern accepted `x{a}:*`. A by-eye classification of the test hits double-counted lines
    (25/7/5/19 → mechanically 21 regex, 8 comment, 1 test name, 6 path-literal, 18 selection); the classifier is now in
    the script.
  - **My first injection run was misaligned by one** (the `ns` form is consumed); discarded and re-run.
- **Next**: the dialogue checkpoint. One scope question (D4 § P4e-2, *Open at this checkpoint*): does E(ii), `xs:0*` as a
  meaning (reopening DEFERRED 105), ride P4e-2 or wait behind a waypoint naming `xs:0:*`? Lean: ride. Then P4e-2-A, the pins.

### Owner, 2026-11-03: two process updates applied; E(ii) decided to ride P4e-2; the mini-audit moves to its own document — docs commit on the branch (2026-11-03)
- **Owner** (2026-11-03 10:57): "As an improvement to our process, I'm thinking that our dailies should switch to following the
  local date hereforth. Audit findings can be there own thing and not cloud-up the design doc (but cross-reference) -- another
  update to process. Fine with the lean to include in Phase 4e-2. Let's proceed therewith."
- **Process, applied on main at `cea41f43`**:
  - dailies follow the LOCAL date: one file per local calendar date, created at its first write with the STATE head copied
    forward. Size, track shift and rewind no longer split a file (`DAILIES_METHODOLOGY.org` § *File rolling*; `workflow.md`,
    where standups keep creation-to-creation);
  - Stage 4 mini-audit findings get their own document in the track's `audits/`, and the design doc keeps the decisions and a
    cross-reference (`DESIGN_METHODOLOGY.org` Per-Phase Protocol step 2).
- **Applied here**:
  - RA-1…13 moved unchanged from D4 §5.P4e-2 to `audits/2026-11-03_CIU_6_P4e-2_GROUNDING_AUDIT.md`. D4 keeps the design target,
    the decisions each citing its RA-n, the worked examples and the plan (207 → 134 lines).
  - The previous entry's claim that the protocol puts findings in the design doc was true when written; it is superseded.
- **Decision**: E(ii) DECIDED — `xs:0*` gets its meaning in P4e-2, reopening DEFERRED 105 for that seat as its own mint with
  its own corpus A/B (D4 § P4e-2, *Decided at the checkpoint*).
- **Next**: P4e-2-A, the pins, all red.

### P4e-2-A ✅ — the ravel stage table, pinned with no compiler change — `8ecb7cbc` (2026-11-03)
- **What**: the table, in `test-path-selection.rkt` § D4.P4e-2.
  - 38 hand rows: C 15, D 11, E 5, plus 7 controls.
  - 28 generated laws: `S:σ` ≡ `S{K}σ`, or the block form's measured refusal reason (`research/P4e-2/probe-p4e2-grid`).
  - B's 8 injection rows, with an identity-mode harness check.
  - C's parity law over a named domain.
  - The 1b-vi runners now wrap the shared `fixture-batch` / `fixture-parse-forms`.
- **Power**: 8 mutants, each failing only its own rows (D4 §5.P4e-2, plan A).
  - Two predictions were corrected before their runs: the hand-row count 35 → 38, and M8's 1 → 3.
  - M3's count (80) was taken after its run; only its composition had been predicted.
- **Departure**: the grammar's corpus trees move to C, with the production. Tree-sitter's corpus runner has no staged-red
  mode.
- **Battery**: 585 + 118 + 2 = 705, all pass.
- **Next**: P4e-2-B, ε inert — `(@id)` in the closed union, its arms at every consumer, one constructor, and a bare
  `(@id)` refused.
