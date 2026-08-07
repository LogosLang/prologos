# Dailies — 2026-08-05

Rolled from `2026-08-02_dailies.md` on a **topic shift**. That file covered the
`loc->line` dual-spine arc (closed + merged at `1d23600e`). This one covers a
separate OUT-OF-BAND arc in worktree `.claude/worktrees/wizardly-mendel-2fd502`
(branch `wizardly-mendel-2fd502`, based on `b429d038`): **DEFERRED 51 + 52**,
spun out to chip `task_4c00d3f0`.

⚠ **Not a CIU T6 continuation.** The CIU T6 D4 / Path Selection authority remains
the STATE head in the file before last. Only environment invariants carry over.

---

## 📍 STATE  (overwrite in place — always current)

- ⚠ **THIS FILE WAS RENAMED AT THE MERGE** (was `2026-08-05_dailies.md`). `main`
  had independently rolled a file of that name for the ARROW track, so both
  survive: main's keeps the canonical name, this arc's carries the
  `-deferred51` qualifier. The convention gap is real — "roll a new file" does
  NOT prevent the collision when two out-of-band arcs roll on the same DATE;
  only a same-day arc qualifier does.
- **HEAD**: re-derive with `git rev-parse HEAD` — expect `1ad9411f` or a later
  docs commit. Worktree `.claude/worktrees/wizardly-mendel-2fd502`, branch
  `wizardly-mendel-2fd502`. **⚠ `main` (65cb5bce) IS NOW MERGED IN** (merge
  `75401b89`, parents `f9d68338` + `65cb5bce`), in prep for merging this branch
  BACK to main. Base was `b429d038`; ours 24 commits, main's 32. NOT pushed.
- **⬜ RULING OWED — DEFERRED NUMBERING COLLISION.** The merge preserved BOTH
  arcs' entries and marked the collision with a banner in `DEFERRED.md` rather
  than renumbering: 53/54/55 denote DIFFERENT items on the two arcs. Nothing was
  renumbered because cross-references to both sets live in commit messages
  (immutable), `macros.rkt` comments and test-case names — a coordinated edit,
  not a mechanical one. (51/52 are NOT a collision: same items, ours supersede
  main's SPUN OUT stubs. `main` already carried a duplicate 53 of its own.)
- **⚠ main's checkout carries 19 uncommitted WIP entries** (`typing-core.rkt`,
  `typing-errors.rkt`, `test-path-selection.rkt`, several `.prologos` examples,
  2 deletions). NOT on the branch, NOT merged, NOT touched — but it has to
  coexist at merge-back time, so check it again then.
- **Suite**: **10017 / 487 files / 0 failures** (`all_pass: true`, `[487/487]`) at
  `1ad9411f` (DEFERRED 58 slice 2). Prior: 10015 at `b3e03913`, 9995 at the merge
  `75401b89` — and it reconciles exactly: main's 9940/485 plus this
  branch's +55 tests / +1 file. Both acceptance files 0 errors post-merge (CIU T6
  path-selection, Rel T1). Pre-merge on this branch: 9902/483 at `83d06156`,
  9899 at `066e2c45`, 9890 at `134ddb79`; branch point 9847 / 482 / 0. Read `all_pass` **and `file_count`** from
  `timings.jsonl`, never the console tail (Watching 5) — and note the runner's
  re-run GUARD exits **rc=0 printing no test line at all** when it blocks, and
  its heuristic is fooled by a targeted run made after your edit; use
  `--force-rerun` after one.
- **Where we are**: the chip's four items are FIXED (51 message · 52 both halves
  · 53 · 51(c)) plus the 51(c) FAMILY: srcloc-preserving preparse on the `defr`,
  `[else]`, and `def`/`defn` arms, and the single-binding `let` leg via the
  helper's RELOCATION step — **and DEFERRED 57, the peel over-reach that leg
  shipped with** (a compound `let` body stole the rel RHS's srclocs; silent when
  the collapsed arity was legal). ⚠ 57 took TWO commits: the first cut
  (`066e2c45`, gate on `pre > 0`) was itself a regression and was corrected by
  `83d06156` (refuse only the PAIR that steals a move) — read DEFERRED § 57
  before touching `rebuild-preserving-locs`, both halves of the wrong reasoning
  are recorded there. Members census in DEFERRED § 51(c), **with a correction in
  § 57**: the bracket + aligned-block members MIS-GROUP at 2+ goals, they do not
  degrade loudly. New items filed this arc: 53–57.
- **Corpus gates**: ⚠ the CUMULATIVE A/B (base `6ffc04ef`, 161 files) **DIED
  INCOMPLETE** on a break signal at ~95/161 (`lib/prologos/book/lattices`); all
  4 of its DIFFERS were READ and are non-semantic (two are the absolute lib path
  echoed inside a pre-existing "Cannot find module" error — base vs head worktree
  paths — plus gensym drift and timing/memory noise). **66 files were never
  compared; it needs re-running.** ⚠ Two traps for the next run: corpus-ab writes
  its out-dir files as DOTFILES, so plain `ls` reports the directory EMPTY — use
  `find`; and it compares PHASE-TIMINGS/MEMORY-STATS/absolute paths, so DIFFERS
  is noisy by construction and every one must be read. A built pre-D57 baseline
  worktree at `fb788bfc` is at session-scratchpad `base-d57/` for isolating 57.
  ⚠ **The D57 A/B is RUNNING, and is now DECOUPLED from the working tree** —
  base `base-d57` (`fb788bfc`, pre-D57) vs head `head-d57` (`f9d68338`, post-D57
  / PRE-merge), both frozen scratch worktrees, so it isolates the peel slice and
  cannot be disturbed by further work. Output `corpus-d57.txt`, out-dir
  `corpus-d57/`. READ IT before trusting the slice closed; a semantic diff there
  outranks everything below. (An earlier attempt run against the live worktree
  was killed by the merge — decoupling is the fix, not a re-run.)
- **✅ THE 51(c) FAMILY IS CLOSED except member 4.** DEFERRED 58 shut the DEPTH
  WALL for all three remaining members (bracket, aligned-block, sibling chain)
  with ONE mechanism — the ORIGIN INDEX, `strip-with-origin!` + `stamp-with-origin`
  in macros.rkt. Read DEFERRED § 58 before touching `rebuild-preserving-locs`:
  it records why "search deeper" was UNSOUND (not merely insufficient) and why
  the sibling chain was never a depth problem at all.
- **NEXT: MEMBER 4 — `def name := rel …` (spliced, unparenthesized), owner-ruled
  as its OWN slice.** ⚠ The index CANNOT fix it: the expanded
  `(rel (?q) ($facts-sep …))` is a NEWLY CONSTRUCTED grouping of three previously
  sibling elements, so no datum-equal twin exists at any depth. It needs
  EXPANDED-SIDE DESCENT. ⚠⚠ And repairing it SILENTLY flips that arm's `||`
  fact-row count (measured: 3 rows where `defr` gives 4, on the identical block,
  0 errors both) — that pin must land BEFORE the fix.
- **(historical) the SIBLING-LET MERGE (unchanged by 57 — it degrades
  LOUDLY, upstream, at the fusion in `merge-toplevel-sibling-lets`).** Pinned as
  a KNOWN LIMIT in `test-rel-t1-pol.rkt` — invert that pin on fix, never delete.
  ⚠ Nomenclature: the pin says "the 5th member", the relay note said 6th.
  **The fork was RE-SIZED by the grounding audit** (`wf_6fdbcd29-242`): option (a)
  stx-carrying merge = ~62 sites over 12 functions, 16 external datum call sites,
  and every discriminator (`memq ':=`, `symbol?`, `list?`) fails SILENTLY-FALSE on
  a syntax object; in-tree precedent `combine-foreign-blocks` is already
  stx-polymorphic and buys nothing because it unwraps at construction. Option (c)
  reconstruct-by-recipe is CONFIRMED possible (from the top-level fusion site only
  ONE merge arm is reachable — `merge-let-sequence` + `split-last-let` +
  `extract-let-binding-tokens` — and the `:=` path is a pure ordered splice) but
  **INSUFFICIENT ALONE**: `merge-let-sequence` emits the BRACKET form and
  `expand-let` buries each value one level below the relocation's top-level
  search, so the srcloc death merely moves from macros.rkt:2994 to :3191. Bounded
  increment the audit named: extend the relocation pool by exactly ONE level.
  ⚠ Hard constraint from the audit: any fail-safe must stamp at a **column-0
  anchor**, never a per-piece inner anchor, or every silent mode opens.
- **Behind it**: 54 · 55 (reader origin marker — now load-bearing under FIVE
  entries) · 56 · `expr-narrow` · 51(b) · subterm-granularity gate · POL.9b
  def-seam diagnostic · the bodyless-let semantics question (owner look wanted;
  see DEFERRED § 51(c) relocation notes) · **UNFILED, from the grounding audit
  and all LOUD: the private `def-`/`defn-` arms and the `trait`/`impl`/
  `specialize` arms (+ private twins) still do the bare whole-form stamp, so a
  `rel` in an impl-method / trait-default / specialized body degrades the way
  `def` did pre-51(c); and error POSITIONS for siblings 2..N of a merged let run
  are all reported at sibling 1's line.**
- **Standing hazards**: the LATENT relocation false-pair (minted-wrapper
  collision — goes live if lambda-body queries ever type; Rel T2 purity ruling
  must revisit); DEFERRED 55's peel zone; both recorded at the code site too.
- **Open/blockers**: none.

### Watching

1. **A filed A/B can encode a mis-diagnosis, and the entry will read as
   authoritative** (2 of 2 this session). Both 51 and 52 were filed with correct
   *observations* and wrong *conclusions*. The fix is cheap and mechanical:
   **re-measure with a baseline worktree before believing any filed A/B**, and
   check whether the "before" leg was itself buggy. 52's pre-G2 `p2/4` was a
   LYING diagnostic — restoring it would have been a regression.
2. **Agent-written probe files can clobber the main session's scratchpad**
   (1 instance, this session). A grounding-workflow facet overwrote
   `scratchpad/d51.prologos` mid-session; a later A/B leg silently ran a
   different program than the earlier leg. Caught only because an unrelated line
   of output changed. **Mitigation: name verification probes uniquely, keep them
   in a private subdir, and md5 the inputs before AND after an A/B.** Add a
   "do not write to shared scratchpad" clause to workflow preambles.
3. **⭐ EVERY AUTOMATED GATE WENT GREEN OVER A LIVE DEFECT AT LEAST ONCE THIS
   ARC — 3 of 3, measured, not impressionistic.** Each time the defect was found
   by an ADVERSARIAL AGENT constructing an input nobody had written before:
   · the full suite (483 files, 9863 tests) was GREEN with the `expr-pair`
     over-rejection live — nothing in the suite writes a compound logic-var-free
     goal argument;
   · the corpus A/B (32 relational files) reported **zero semantic diffs** while
     the `$pipe` fabrication was live — no corpus file uses a leading-pipe table;
   · the targeted-test runner reported *"all pass"* while a file had TIMED OUT.
   **The rule this buys**: a green gate means "no REGRESSION on inputs we already
   had", never "the change is correct". For a change that widens what reaches a
   code path, the gates are necessary and not close to sufficient — budget for
   adversarial input construction as a FIRST-CLASS step, not a nicety. Both
   verifies also produced a confidently-wrong BLOCKING finding, so the same rule
   applies in reverse: verify the verifier by measurement.
4. **⭐ NEVER CLAIM A FAMILY IS CLOSED — 3 of 3 such claims fell this arc,
   each within hours.** (1) DEFERRED 53's message listed the rewrite families as
   if closed → a list literal was a 4th trigger. (2) `term-sentinel?`'s "a
   $-headed pair is always ONE VALUE" → structural sentinels. (3) "the POL.8
   guard has NO known reachable trigger" → the `let` binding-RHS leg, refuted by
   a 6-line file with zero rewrites. The correct claim shape is "no KNOWN
   member, having looked in ⟨list of places⟩" — and the enumeration of places
   IS the reviewable artifact. Same lesson as P4c-2's inverted default, arriving
   through prose instead of code.
5. **`all_pass` in `timings.jsonl` is the truth; the console summary is not**
   (**3 instances**). A targeted run reported *"12 tests … all pass"* while one of
   the two files had TIMED OUT and contributed nothing; a `tail -6` of the suite
   hid the summary line entirely; and (2026-08-07) the runner's **re-run GUARD**
   blocked a `--all` invocation with **exit code 0 and no test line at all**
   ("No .rkt files changed since last suite run (62s ago)") — a green-looking
   NON-RUN, and its heuristic is fooled by a targeted run that follows your edit.
   **Read `all_pass` + `file_count` from the last `timings.jsonl` record; pass
   `--force-rerun` after a targeted run.**
6. **⭐ WHICH AXIS OF YOUR FIXTURE DID YOU NEVER VARY?** (**4 data points**, and
   ⚠ **it caught the very commit that codified it, plus the agent sent to refute
   that commit** — so treat it as a CHECK PERFORMED ON THE DIFF, not a principle
   you recall. For each new pin: list the fixture's dimensions explicitly and
   mark which ones the test varies.) `066e2c45` wrote this lesson down and its own
   new pins then varied body shape and goal count while holding the **let
   spelling** constant at `:=` — which is why "a SINGLE goal under a compound
   body was never affected" stayed green over a regression in exactly the
   single-goal case (aligned-block + bracket spellings). The refuting agent then
   varied body shape and let spelling but never varied **goal count down to
   one**, and missed the same regression; the judge found it by varying that.
   Three levels, one failure mode. Original instances below.) DEFERRED 57 was live under a
   green suite for the whole arc because both of the let leg's pins used an ATOM
   let-body and the defect needs a COMPOUND one. What makes this worth its own
   entry is *why* nobody varied it: **the body is not part of the feature under
   test.** The pins were about clause grouping; the body is scenery — but the
   desugar makes the body positionally adjacent to the rel RHS, so scenery was
   load-bearing for the mechanism. Prior instance: the `[else]`-arm pins that
   were "shaped not to see" the right-peel case. **Add to the pin discipline:
   after control-equality, name the mechanism, then ask which INCIDENTAL element
   of the fixture the mechanism touches — and vary that.**
7. **An INFERRED audit finding is a hypothesis, and it fails in BOTH directions**
   (1 round, 2 of 2 checked). The grounding audit inferred two defects from code
   without running: the let leg's body-shape dependence **reproduced exactly**,
   and the `defn`-body silent mis-group **did not reproduce at all** (both
   spellings yield a stuck `(rel [1] ...)`, 0 errors — nothing diverges). Neither
   the confirmation nor the refutation was predictable from the reasoning
   quality, which was equally good in both. **Probe every inferred finding before
   relaying it, including the ones you want to be true.**

---

## LOG  (append per commit, newest at BOTTOM)

### Both filed diagnoses were wrong in their load-bearing half — `e0f03601`

**Why**: chip `task_4c00d3f0`. Both items were filed as G2-surfaced defects in
the relational surface.

**Surprise (the whole story)**: neither filed diagnosis survived re-measurement.

- **51** was filed as "the relation goes defined → undefined". Measured against a
  pre-G2 worktree (`ae26f540~1` = `0fd2098c`): the same clause spelled with
  **dot-access** loses the relation **identically on both legs**. The loss is
  PRE-EXISTING; G2 only added broadcast to a trigger set that already had
  dot-access and postfix-index. Root cause found by instrumenting
  `parse-clause-content`: `macros.rkt` strips each form to a bare datum before
  preparse and the `defr` arm rebuilds with a 3-arg `datum->syntax`, so every
  element inherits the defr's own `(line, col)` — measured `(6,0)` for all three
  elements vs `(5,5) (5,10) (5,13)` in a healthy clause. `(zero? sent-col)` then
  routes to `parse-degraded`. This is a **named, eyes-open POL.8 limit**, stated
  verbatim in the Rel T1 design doc and already test-pinned. Owner ruled **(a)**:
  keep the limit, fix the message only.
- **52** was filed as "a loud arity error became a silent empty bag". The loud
  leg was itself the bug: pre-G2 `a:b` was SPLICED into two tokens, so a
  2-argument call was reported as `p2/4` — a lying diagnostic. G2 made arity
  CORRECT. The real defect is different, broader, and pre-existing: the goal arms
  of `infer` called `infer` on arguments for effect and **discarded an
  `expr-error` result**, so any type error in goal-argument position was silent
  (`[+ "str" 1]`, `[undefined-fn 1]` silent on BOTH legs; loud in `def`).

**Fix**: 51 — message names the CONDITION (any preparse rewrite in the defr) and
its families, open-ended. 52 — propagate the discarded `expr-error`, gated.

**The gate is the interesting part, and it had to widen twice.** An `expr-error`
out of the imperative `infer` has THREE meanings, not one:
1. a real user type error → report;
2. a **relational term** whose type is legitimately unknown (a bare name in a
   goal is a LOGIC VAR, so `mm.c` is a select on an unbound var) → excuse. Caught
   by POL.9's own pinned test when the first version broke it;
3. **an inferencer gap** — `infer` has no arm and falls to its catch-all. Caught
   by the adversarial verify: `(q1 [pair 1 2])` became a hard error while
   `def z := [pair 1 2]` stayed fine, because the command boundary tries the
   ON-NETWORK inferencer first and goal args reach the imperative one only.
   Two more of the same class: a partial-application section in an `is` RHS (the
   idiom the syntax rules RECOMMEND) and the 1-arg `(guard [pred])` form.

So the excuse set is `{logic var} ∪ {nodes infer cannot synthesize}`, the latter
**derived mechanically** as `{register-typing-rule!} \ {infer arms} − expr-error`
= `expr-pair, expr-hole, expr-reduce, expr-refl`, with a **drift-guard test that
recomputes it from source** so a future rule cannot widen the class silently.

**What the gates caught that nothing else did**: the full suite was GREEN
(9863/483) *with* the `expr-pair` over-rejection live — the corpus has no
compound logic-var-free goal arguments, so nothing exercised it. Only the
adversarial verify found it. Conversely the suite caught what `raco test` could
not: the drift guard read `../typing-propagators.rkt` by relative path, which
resolves against the process cwd — fine under `raco test` (cwd = `tests/`),
broken in the batch worker (cwd = `racket/prologos`). Now `define-runtime-path`.

**Next**: the named residuals — 52's clause-body swallow (`expr-clause` still
discards, so an ill-typed goal in a `defr` BODY is silent at registration), the
subterm-granularity gate (`(not (q1 [+ "str" ?y]))` returns a wrong POSITIVE),
and 51(b)/(c).

### The clause-body half, and a "blocking regression" that measurement refuted — `41a0ef75`

**Why**: owner asked for the clause-body swallow too. The first fix reached only
TOP-LEVEL goals; `expr-clause` and its parents still discarded `expr-error`, so
an ill-typed goal inside a `defr` body — where nearly all real goal code lives —
was silent at registration and matched nothing at query time.

**Fix**: six arms propagate (`expr-defr`, `-variant`, `expr-rel`, `expr-clause`,
`expr-fact-block`, `expr-fact-row`). The chain has to be COMPLETE to be
observable; breaking it anywhere leaves the error one hop short of the boundary.

**Surprise 1 — the adversarial verify's BLOCKING finding was wrong, and checking
it was worth more than accepting it.** It reported that `all-different` /
`element` / `cumulative` / `minimize` (writable only in clause bodies, no `infer`
arm) now kill the whole `defr`, "pre-change it registered". Measured: pre-change
it **aborted the whole file** — `match: no matching clause for
(expr-all-different '(a b))` at `zonk.rkt:75`, with NO output at all, not even
the preceding `defr digits`. So the change converts a whole-file abort into a
per-command error. Strictly better; pinned via "the LAST command still runs".
⚠ Deliberately NOT excused — excusing would let the term reach zonk and restore
the crash. Filed as DEFERRED 54.

**Surprise 2 — a worse defect found in passing, filed as DEFERRED 53.** A
compound term in a `||` fact row is SPLAYED into fabricated rows: `|| [some 1]`
yields TWO rows, `|| '[1 2]` yields THREE, zero errors, byte-identical pre/post.
That is a silent WRONG ANSWER — rows the user never wrote — and it makes this
commit's `expr-fact-row` propagation inert for compound terms, because the splay
happens at parse time before typing sees anything. Nothing in the corpus has a
compound fact term, which is why it has stayed hidden.

**Tension recorded, not hidden**: this widens the class of `defr`s that fail to
register, which pulls against 51(b) (where registration-loss is framed as THE
problem, with the enriched *"its defr failed to register"* message named as prior
art). DEFERRED 52's residual list now says so rather than leaving the entries
contradicting the tree.

**Next**: DEFERRED 53 is the one that matters — it fabricates data. Then 54, and
`expr-narrow` (same swallow shape, no repro constructed).

### Naming the relation, and TWO adversarial claims that measurement refuted — `7c52a2ae`

**Why**: the clause-body propagation deletes a whole relation, and the bare
"Could not infer type" gave the user that deletion with no pointer to WHICH
`defr`; the later query then said only `Unknown relation: badclause`, which is
misleading because they DID define it. A fix whose diagnostic misleads is not
finished. Now: `defr badclause: Could not infer type — the relation was NOT
registered`.

**Why not env-add to reach the good message**: the enriched *"its defr failed to
register (see the earlier error)"* branch (relations.rkt) keys on an `expr-defr`
being env-bound, so reaching it means an env write carrying a body that FAILED to
type — which `zonk` may not survive (DEFERRED 54), i.e. exactly the whole-file
abort this arc removed. Left to 51(b).

**Both adversarial verifies produced a BLOCKING finding; both were refuted by
measurement, in the same way.** Each reasoned from what the code *would* do and
concluded "this used to work". Each time, running it showed otherwise:
1. `all-different` &c "registered before" → it **aborted the whole file** at
   `zonk.rkt:75`, printing nothing at all.
2. `[vnil Int]` / `[fzero 3N]` are "legitimate values now rejected" → they
   **fail to infer in `def` position too**, so goal position agreeing with def is
   the fix working. `[pair 1 2]`, which DOES type in def, is exempted — precisely
   the distinction the exempt set was built to draw.
   **The lesson, and the pin**: *def-position behaviour is the ORACLE* for
   whether a goal-arg rejection is correct. Now test-pinned as a discriminator
   rather than left as a judgement call.
   ⚠ The verify's DERIVATION critique still stands and is recorded: the exempt
   set is `{register-typing-rule!} \ {infer arms}`, while these call sites
   arguably want `{all expr kinds} \ {infer arms}` — 19 kinds, not 4.

**Sharpened residual**: the gate's whole-argument granularity is now BIMODAL —
`&> (fc x [+ "str" 1])` deletes the defr, `&> (fc x [+ "str" y])` registers and
answers a silent `@[]`. Pre-change both were silent, so consequences were
UNIFORM; bimodal will read to a user as nondeterminism. Strongest argument yet
for subterm granularity.

**Corpus re-checked** for this commit: only 4 corpus files carry a "Could not
infer type" at all, none from a `defr`; re-run against the new build, 3 identical
and 1 differing only by meta-counter drift. The gate stands.

### DEFERRED 53 — fabricated fact rows, and an inversion that had to be inverted twice — `5a30496d`

**Why**: `|| [some 1]` returned TWO rows, `|| '[1 2]` THREE, zero errors. Rows
the user never wrote. Pre-existing (byte-identical at `b429d038`).

**Cause**: the WS facts arm read "a pair ⇒ a nested continuation row" and
whitelisted only five numeric-literal sentinels as single terms, so every other
compound was splayed into its tokens.

**Fix, two parts**: (A) invert `term-sentinel?` to `$`-headedness so a future
VALUE sentinel is a term by construction; (B) a LINE RULE — an element on the
`||` sentinel's own line is a first-row term, since a continuation row is by
definition on a later line. (B) is guarded on trustworthy srclocs via 51's
column-0 marker.

**⭐ The lesson of the day: I inverted a whitelist and created a NEW instance of
the same bug.** (A)'s stated invariant — "inside fact content a `$`-headed pair
is always ONE VALUE" — is FALSE. The reader wraps a continuation LINE by its
FIRST TOKEN, so a line starting with a structural sentinel arrives as
`($pipe 3 4)`. Treating that as a term turned the ordinary leading-pipe table

```
defr digit [?d]
  || 0
   | 1
```

from a LOUD "empty row beside `|`" into `@[{:d 0} {:d [?$pipe 1]} …]` — fabricated
rows leaking the raw sentinel, zero errors. **Inverting a whitelist is not
automatically safe; the inverted predicate needs its own invariant, stated and
CHECKED.** Fixed by excluding structural sentinels, read off the predicates that
already define them so the set cannot drift.

**Both adversarial verifies of this fix were worth their cost** — one found the
`$pipe` regression, the other independently A/B'd the OLD vs NEW predicate
element-by-element across all 20 corpus files with a `||` line (86 fact groups,
ZERO reclassified), which is stronger evidence than my own end-to-end runs.

**Residuals, now ALL pinned** (the verify fairly objected that the biggest was
undocumented and two others mis-stated). The dominant one: **a `|>` or dot-access
ANYWHERE in the defr disables (B) and the fabrication returns** — action at a
distance, via 51's rebuild. That is why 51(c) is now the NEXT item: it blocks
three separate entries.

**Also corrected**: compound fact values are SEMANTICALLY DEAD, not merely
mis-rendered — `|| [some 1]` then `(m1 [some 1])` → `@[]`, and `[some 1]` renders
`[?some 1]` (the constructor head became a LOGIC VAR) with an `<error>` column
type under 0 errors. That mangling is fact-row-specific, NOT pre-existing as I
first wrote. The fix trades N fabricated rows for 1 unmatchable row: strictly
better, still not working.

### 51(c): srcloc-preserving preparse — the limit is lifted, after two self-inflicted mis-parses

**Why**: 51(c) was blocking three items — 51's own limit, 53's residual 1 (an
idiomatic `|>` or dot-access anywhere in a defr silently restored fabricated
rows), and the reader-marker path for 53's residual 2.

**Fix**: `rebuild-preserving-locs` (macros.rkt) re-attaches srclocs AFTER preparse
by walking the ORIGINAL syntax tree against the expanded datum — unchanged
subtree ⇒ reuse the original syntax object; same-shape lists ⇒ align by common
prefix/suffix and recurse; changed middle ⇒ anchored on the first original
element it replaced. Applied at the **`defr` arm only**, which is where the
tree's only layout-driven grammars live.

**⭐ The lesson: lifting a "refuse rather than risk a silent mis-grouping" guard
is only safe if you then PROVE the grouping. Twice I did not, and twice the
result was the exact failure the guard existed to prevent** — worse than the
status quo ante, because the old degradation stamped column 0 (which the guard DETECTS)
while my half-right versions stamped a NONZERO column, so the guard passed and
the parse silently mis-grouped:
1. equal-length-only alignment bailed for the whole clause → every element got
   the CLAUSE's position → a two-goal clause parsed as one 3-arg goal;
2. stamping (not recursing) an equal-length middle stopped the walk one level
   short → same symptom;
3. and after fixing those, a rewrite in BOTH goals put the continuation on the
   first goal's line, because the strict suffix is datum-equality-based so a
   CHANGED trailing element is not in it. Fixed by peeling the middle from the
   right.
Each was found by running a rewritten clause against a shape-identical
rewrite-free CONTROL and requiring the parses to agree — which is now the test.

**Gates**: suite 9880/483/0. Only `test-rel-t1-pol.rkt` ever failed, and only on
the five tests that deliberately PINNED the lifted limit; those are inverted, and
the new pins assert GROUPING (vs a control), not merely absence of error.

**Scope honesty**: a bare top-level `rel` still degrades and still refuses — it
does not go through the `defr` arm. So the guard is NOT dead code, and `rel` and
`defr` now disagree on the same grammar. That is the next decision.

### 51(c) follow-through: the verify found what my own tests were shaped not to see

**Three findings, all confirmed by my own measurement before acting.**

**F1 — my right-alignment is unsound in general.** Positional right-alignment is
only valid AFTER the last length-changing rewrite; with TWO such rewrites
separated by other elements, the zone between them pairs with originals `delta`
positions to the right. Where a list's elements SPAN LINES that crosses a line
boundary and corrupts the LINE — which is what the layout grammar reads. Reached
only on the flat/paren-wrapped spelling (27 of 70 randomized cases); unreachable
in ordinary indent-grouped WS, where every continuation line is exactly ONE
grouped element so a group cannot change the enclosing list's length.
⚠ **Not a regression** — that spelling mis-parsed BEFORE 51(c) too, because the
guard's column-0 marker never protected it (`(defr …)` sits at column 1). A
160-case A/B found ZERO cases where old was right and new wrong. **Mitigated**:
the peel now only pairs datum-equal elements or two LISTS, so an atom can no
longer pair with a different atom. Filed as DEFERRED 55.

**F2 — `x[i]` is the odd family out**, and my test was shaped not to see it. It
folds to `(get x i)`, the only one of the four families whose output is NOT
`$`-headed, so `pol8-goal-pair?` mistakes it for a goal group and a deeper
continuation becomes a bogus sibling goal. My family loop only checked that the
defr REGISTERS, with the rewrite on the `&>` line — so it passed straight over.
Now pinned with a control comparison, including the failure as a known limit.
Filed as DEFERRED 56. Same polarity trap as 53: "a pair not headed by `$`".

**F3 — the guard's message now lies where it survives.** `def r := rel …` with
parenless clauses fires it with NO rewrite in the source (the `:=` itself is the
rewrite), telling the user to hunt for a dot-access they never wrote. Reworded to
lead with the CONDITION and name `def := rel` explicitly.

**⭐ The meta-lesson, and it is the same one as the gates.** My tests asserted
"registers / no error"; all three findings live in the gap between that and "parses
CORRECTLY". The ⭐ grouping test I did write (compare against a shape-identical
control) is the shape that catches this class — I just did not apply it to every
axis, so the axes I skipped are exactly where the defects were. **When lifting a
guard, the control comparison has to cover every axis the guard used to cover**,
not one representative of it.

### The [else] arm — `rel` and `defr` agree again — (commit follows)

**Why**: after 51(c), a bare top-level `rel` still refused parenless clauses
under a rewrite, because it goes through the fold's `[else]` arm, not the `defr`
arm — two spellings of the same POL.8 grammar disagreeing, the exact class this
chip exists for. Owner: "do the [else] arm too".

**Fix**: the `[else]` arm now rebuilds through `rebuild-preserving-locs`. The
delicate part was PROPERTY parity, not srclocs: `[else]` was the arm whose 4-arg
rebuild carried POL.9's `prologos-paren-origin` (goal-ness of a rewritten
top-level paren group). The helper's fallback was made 4-arg against the
original stx first, so the property contract is identical by construction —
and probed: `(p2 1:Int 2:Int)` still errors AS A GOAL, `(fruit-color f mm.k)`
still implicit-solves.

**Pins**: failing-test-first — bare `rel` + rewrite registers, AND a two-goal
bare `rel` groups identically to a shape-identical rewrite-free control (the
lesson from 51(c) applied on day one this time, not after the verify).

**Measured residual**: unparenthesized `def r := rel …` still degrades — the DEF
arm requires exactly one element after `:=`, and a spliced multi-line `rel` RHS
is several, so `def-rhs-stx` is #f and the whole-form stamp fires. Named in the
guard's own message; left as a co-design question because that arm carries
`prologos-defrhs-command` / Q_C command-position semantics.

### The def arm — the 51(c) family is complete — (commit follows)

**Why**: after defr + [else], the unparen `def r := rel …` spelling still fired
the guard — with NO rewrite in the source, because the `:=` desugar itself
changes the datum and the DEF arm's `def-rhs-stx` requires exactly ONE element
after `:=` (a spliced multi-line `rel` RHS is several → whole-form stamp).

**Fix**: both degrading paths route through the helper — the `def-rhs-stx = #f`
fallback (the measured target; also serves `defn`) and branch (b) (single-element
rewritten RHS, so a paren `(rel …)` RHS with a rewrite inside keeps its clause
layout — pinned ROWS-based, strong: a mis-group would arity-error, not row).
The `value-stx` outer rebuild was deliberately NOT touched: it already embeds the
Q_C-marked RHS syntax object, which `datum->syntax` preserves as-is.

**The measured semantics, stated eyes-open**: the unparen spelling now parses and
routes into the PRE-EXISTING POL.9b def-seam gap ("Expression is not a valid
type") — exactly what `def bad := (dbl 3)` is already pinned to produce. That is
consistency, not a new failure; the misdirecting "parenthesize each GOAL" refusal
is gone, and the pin documents the routing so the seam fix (when it comes) shows
here too.

**Q_C safety came from the PREVIOUS verify, not this round**: the [else] verify's
exhaustive property inventory (2 properties, 2 writers, 3 readers, all
position-restricted; def forms' dispatch reads `prologos-defrhs-command` at the
stamped RHS element only) is what made the def-arm swap mechanical rather than a
co-design question. Its clean bill was the first of the arc — and it also
confirmed the [else] change FIXED a pre-existing silent mis-parse
(`is q [+ n mm.k]` in a rel body: base errored `Unknown procedure: nums/4`,
HEAD yields correct rows).

**Gates**: 152 targeted tests green; all 8 probe batteries at expected error
counts (else1's second error correctly SHIFTED from guard to seam); suite
9893/483/all_pass, 105.8s. Cumulative full-corpus A/B (base `6ffc04ef`,
covering [else]+def) + def-arm verify launched as follow-up.

### The def-arm verify: code clean, prose refuted — `2f983635` corrections

Zero behavioral regressions across 20 probes; both intended deltas confirmed
(including the continuation-line rewrite case, which the pre-51(c) base
MIS-GROUPED to `fruit-color/5` and HEAD groups correctly). But two of my prose
claims fell:
1. **"the POL.8 guard has NO known reachable trigger" — FALSE.** Bare top-level
   `let r := (rel …)`, parenless clauses, zero rewrites → the guard, re-measured
   myself. The `let` desugar is a TOTAL RESHAPE, so the [else] conversion cannot
   help it — no alignment recovers a subtree that moved position AND depth. 4th
   family member, filed under the 51(c) entry with two candidate fix shapes.
2. **"a mis-grouping would surface as an arity error, not a row" — TOO STRONG.**
   In the D55 peel zone with a merged-arity relation registered, the def
   paren-RHS spelling solves SILENTLY. Pre-existing (byte-identical at base) but
   the pin-strength argument was mine and wrong; DEFERRED 55 now lists the
   spelling.
Watching 4 added: never claim a family is closed — 3 of 3 such claims fell this
arc; claim "no KNOWN member, having looked in ⟨places⟩" instead.

### The let leg — a relocation step, not a real diff — (commit follows)

**Why**: the 4th family member, found by the def-arm verify: bare top-level
`let r := (rel …)` with parenless goals fired the guard with ZERO rewrites.

**The instrumentation changed the fix.** My reasoned diagnosis said "total
reshape — no alignment can recover it; needs D55's real diff." Dumping the
before/after trees showed the truth is smaller: the desugar
`(let r := V body) → ((fn (r : _) body) V)` MOVES V datum-identical from element
3 to element 1. Prefix/suffix can't see moves — but a move-without-change needs
only a RELOCATION step: pair a compound expanded element with a datum-equal
original when the match is unique in both directions; recurse (the original stx
comes back wholesale); stamp on any ambiguity. The bidirectional-uniqueness and
compound-only guards are the lesson of this arc applied in advance: a false pair
attaches the WRONG LINE, which is precisely the silent mis-grouping class.

**Pin shape**: equality with the PAREN-goal control — the parenless and paren
spellings have identical semantics, so one `check-equal?` pins grouping AND
solving at once. Single-goal and two-sibling-goal shapes.

**Gates**: 154 targeted green; all 10 probe batteries at expected counts; suite
9890/483/all_pass (one cycle lost to a temp-file flake — see STATE). Cumulative
corpus (base 6ffc04ef, covering [else]+def+let) + let-leg verify to follow.

### The relocation verify: one latent false-pair, a census, and a qualified claim — (commit follows)

**The verify's verdict, re-measured before acting**: the relocation holds for
every single-binding direct let spelling (parenless ≡ paren control throughout),
perf Δ≈0 — and THREE things needed the record:

1. **A CONFIRMED latent false-pair, and it is exactly the class I designed the
   guards against, arriving through a side door.** A user lambda datum-identical
   to the funnel's minted `(fn (name : _) body)` wrapper — with the peel having
   already consumed the true twin — defeats BOTH uniqueness guards: the minted
   node relocates to the user node's plausible locs. Today it only demotes the
   loud guard to a generic type error (rel-in-lambda does not type). **It goes
   live the day lambda-body queries type — Rel T2's purity ruling must revisit.**
   The deep lesson, now qualified at the code site: relocation is monotone in
   srcloc QUANTITY, not DETECTABILITY — it can replace guard-detectable
   column-0 stamps with wrong-but-plausible columns. Datum equality is the
   algorithm's only oracle; minted-equals-user is undecidable here; the durable
   answer stays DEFERRED 55's reader origin marker.
2. **The full member census is now in DEFERRED** — fixed vs still-degrading
   (bracket-form, aligned-block, sibling chains, defmacro-expanded,
   moved-AND-rewritten; all loud, all pre-existing) — so the Watching-4 rule has
   its "list of places looked" artifact and no closure claim is needed.
3. **Bodyless goal-RHS let**: the parenless spelling now matches its control —
   but the control is a pre-existing silent STUCK value (`(rel [1] ...) : _`,
   0 errors; POL.10 snapshot semantics never fire). Equal-to-control passed the
   pin while the control itself looks broken. Owner look wanted.

### DEFERRED 57 — the peel over-reached, and the let leg's own pins were shaped not to see it — `066e2c45`

**Why.** Owner ruled the sequencing after a grounding audit reshaped the fork:
fix the peel over-reach FIRST, then the sibling merge. The reason to reorder is
that the two members had opposite polarity — **the sibling-let chain (the thing I
was sent to fix) fails LOUDLY, while the already-"fixed" single-let case was
failing SILENTLY.** Fixing the loud one while a silent one is live is backwards.

**What was wrong.** `peelable?` accepts ANY two lists, so it cannot tell an
EDITED list from one RESHAPED WHOLESALE. The let desugar
`(let r := V BODY)` → `((fn (r : _) BODY) V)` leaves BODY and V last on their
respective sides, both compound — the peel paired them, and V (the rel RHS,
carrying the clause layout) was rebuilt against BODY's tree. Nonzero column ⇒
POL.8's column-0 marker blind ⇒ two parenless goals collapse into one 5-arg goal.
With an ATOM body `peelable?` refused and relocation found V correctly. **Both
of the let leg's pins used an atom body.**

**Fix.** The peel now requires `pre > 0` — a shared left anchor. Right-alignment
presumes the two lists are the same list with a changed middle, and `peelable?`
only ever sees the one pair it is about to take. Structural, not lucky: clause
regions are anchored by the `&>` sentinel, which no rewrite touches (so pre ≥ 1
even when a rewrite lands on the goal head), while a total reshape changes
element 0's KIND (so pre = 0). The reshape case falls through to relocation,
which matches V by datum equality and does not care that it moved.

**Surprise 1 — it was a REGRESSION, and a silent one.** Pre-let-leg this input
got the loud guard. And the collapse is only loud when the collapsed arity is
undefined: on a multi-arity relation it solves and returns an answer with **0
errors** while the correct reading errors (measured). So the let leg had shipped
a reachable silent-wrong-answer, under a green suite, for the whole arc.

**Surprise 2 — the audit's INFERRED claim was right and its other one was
wrong.** The grounding audit inferred (from code, without running) both that the
let leg was body-shape-dependent AND that a `defn`-body sibling chain fails
silently. Probing: the first reproduced exactly; the second did **not** — a
`defn`-body chain yields a stuck `(rel [1] ...)` with 0 errors on BOTH spellings,
so nothing diverges and no mis-group is observable there today. Same "no wrong
answer is expressible" shape as the lambda-body false-pair. Inferred findings are
hypotheses; the probe is the arbiter, in both directions.

**⭐ The generalizable lesson — WHICH AXIS OF YOUR FIXTURE DID YOU NEVER VARY?**
This is the 4th "every gate green over a live defect" this arc and the 2nd "the
FIXED row is narrower than its name". What is new is that the missed axis was
**not part of the feature under test**: nobody varies the `let` BODY when testing
clause grouping, because the body is not what the fix is about. That is exactly
why it went unvaried — and the desugar makes the body positionally adjacent to
the thing that is. Add to the pin discipline: after control-equality, ask which
*incidental* element of the fixture is load-bearing for the mechanism, and vary
that too.

**Also caught, cheap.** The suite runner's re-run GUARD returns **rc=0 and prints
nothing about tests** when it blocks ("No .rkt files changed since last suite run")
— a green-looking non-run, the same class as Watching 5. Reading `all_pass` from
`timings.jsonl` caught it; the console said nothing wrong. Use `--force-rerun`
after a targeted run.

**Next.** The sibling-let merge (unchanged by this fix — it degrades LOUDLY
upstream at the fusion in `merge-toplevel-sibling-lets`). The audit re-sized that
fork substantially: option (a) stx-carrying merge is ~62 sites over 12 functions
with 16 external datum callers and silent-false discriminators; option (c)
reconstruct-by-recipe is confirmed possible (the `:=` path is a pure ordered
splice, only 3 functions reachable) but **insufficient alone**, because
`merge-let-sequence` emits the BRACKET form and `expand-let` then buries each
value one level below the relocation's top-level search. Bounded increment named
by the audit: extend the relocation pool by exactly one level.

### The D57 verify: my own fix regressed two spellings, and my own new lesson caught me — `83d06156`

**Why.** Adversarial verify on `066e2c45`. Two findings survived judging, and
together they retire the reasoning I shipped.

**The regression.** `pre > 0` was too blunt. `pre = 0` is necessary for a reshape
but nowhere near sufficient — **any** rewrite landing on element 0 zeroes it. Two
spellings that answered CORRECTLY at `fb788bfc` hit the guard after my gate: the
ALIGNED-BLOCK and BRACKET lets, with a compound body and **exactly one** parenless
goal. There relocation cannot reach the moved rel RHS at all (DEPTH — one level
below the middle for the bracket form, two for `$let-block`), so the peel was the
only thing carrying the srclocs and withdrawing it left nothing behind.

**And it was unsound the other way too.** A head-position `mm.k` / `xs[0]` is an
ORDER-PRESERVING fold, where right-alignment is correct. My gate withdrew the peel
there and stamped a whole clause subtree — two goals became one 5-arg goal at a
NONZERO column: the silent mis-group the code exists to prevent. Mechanism
confirmed at the srcloc + parser level; end-to-end unreachable today, so the
verify graded it mechanism-confirmed / severity-refuted, which is the right call.

**The rule that shipped instead** is about the PAIR, not the list: refuse the peel
only when the expanded element MOVED THROUGH UNCHANGED (datum-equal to exactly one
original in the pre-peel middle, unique on the expanded side), because then
relocation pairs it with its TRUE original — strictly stronger evidence than
positional adjacency. A rewritten element has no exact match and still gets the
peel. Narrow, and it stops trading one silent class for another.

**⭐ Watching 6 caught me on the commit that codified it.** `066e2c45` wrote down
"which axis of your fixture did you never vary?" — and its own new pins varied
body shape and goal count while holding the **let spelling** constant at `:=`.
That is why "DEFERRED 57: a SINGLE goal under a compound body was never affected"
stayed green over a regression in the single-goal case. The lesson is evidently
not self-applying: writing it down did not make me run it against the very pins
I was adding in the same commit. **Codify it as a CHECK performed on the diff,
not a principle recalled from memory** — for each new pin, list the fixture's
dimensions explicitly and mark which ones the test varies.

**Verify quality, for the ledger.** 5 refute agents → 6 BLOCKING/MAJOR findings →
2 survived judging. The judge did the real work in both: it REFUTED three of the
four fixtures the surviving finding was argued from (byte-identical on both
trees, i.e. pre-existing), and then found the actual fix-caused regression the
refuting agent had missed — by varying goal count DOWN to one, the one axis that
agent had not varied either. Same failure mode, three levels deep.

**Census correction, filed.** DEFERRED 51(c) calls the bracket and aligned-block
members "still degrading, all LOUD". They are not: at 2+ goals they MIS-GROUP
(`fruit-color/5`), and a mis-group is loud only while the collapsed arity is
undefined. Now pinned as a KNOWN LIMIT. Root cause is DEPTH — the same wall the
sibling-let merge hits, so the two probably want one answer.

**Gate**: suite 9902/483/0 (`[483/483]`); corpus A/B vs `fb788bfc` IN FLIGHT at
session-scratchpad `corpus-d57.txt`.

### DEFERRED 58 — the depth wall closes, and the answer was to stop throwing information away — `b3e03913` + `1ad9411f`

**Why.** Owner: "fix the depth wall once for both, next." The grounding audit
then refuted my framing twice, and both refutations changed the design.

**Refutation 1 — the sibling chain was never a depth problem.** Its srclocs die
UPSTREAM, at the fusion: `(map syntax->datum unit)` then a 4-arg rebuild against
sibling 1, and `datum->syntax` stamps RECURSIVELY over a bare datum. Every node
carried sibling 1's L:C0 before `rebuild-preserving-locs` was ever called. **No
search, at any depth, can recover information that is no longer in the tree.**

**Refutation 2 — "search deeper" was unsound, not merely insufficient.** It keeps
DATUM EQUALITY as the oracle, and datum equality cannot tell a user subtree from
one the desugar MINTS. The audit demonstrated the collision is LIVE at the depth
we already shipped: `let q := [fn [q : _] [some q]]` has the minted wrapper
taking the USER lambda's srclocs while the user's lambda is flat-stamped — a
SWAP. Deepening strictly enlarges that class and opens a wider route than the
recorded one.

**The answer.** `syntax->datum` allocates FRESH pairs and the movers splice
sub-datums BY REFERENCE, so **cons-cell identity is already an exact provenance
marker** for exactly this class — a subtree that moved through a desugar
unchanged. The strip was discarding it. Record it in a `hasheq` and consult it.
No depth parameter, no false-pair exposure (a minted node is a fresh cell, `eq?`
to nothing), and it resolves cases datum-ambiguity stamps today.

**⭐ The shape of this lesson is worth keeping.** Three sessions in a row reached
for a better MATCHER — deeper pools, multi-source relocation, a real tree diff —
when the information they were trying to reconstruct had been *destroyed on the
way in* and was free to keep. **When you find yourself designing a smarter search
for provenance, first ask what discarded it.** Both slices are ~10 lines each;
the estimate they replaced was "~62 datum-shape sites across 12 functions".

**⭐ And the loudness was a property of the FIXTURE, not the code.** The sibling
chain failed loudly only because sibling 1 sits at column 0, which is POL.8's
degradation marker. Written indented inside a `defn`, the identical defect is
SILENT. That retroactively weakens every "still degrading, all LOUD" claim in the
51(c) census — loudness there was never established, only observed at column 0.

**Tests, and the axis I varied this time.** Watching 6 caught me twice already, so
the new pins vary body shape × goal count × let spelling explicitly, and add a
`test-origin-index.rkt` for the two properties a green suite cannot show: that
`strip-with-origin!` is datum-identical to `syntax->datum` (it is on the hot path
for EVERY form now, and the shapes most likely to diverge — improper lists,
vectors, nested empties — appear in no `.prologos` fixture), and that a SECOND
strip shares no keys. That second one is the sharp pin: without it, an accidental
re-strip anywhere would silently reduce the index to a no-op that still passes
every behavioural test.

**Gates.** Suite 10017/487/0 (`[487/487]`); both acceptance files 0 errors. ⭐ The
**D57 corpus A/B came back CLEAN** — 161 files, base `fb788bfc` → head
`f9d68338`, **zero semantic diffs** (4 DIFFERS = 2 gensym drifts + 2
absolute-path echoes inside a pre-existing error; 20 caps all SYMMETRIC, identical
sizes, path-only content deltas — i.e. pre-existing slowness plus my own
concurrent suite runs, NOT a one-sided slowdown from the new hot-path walk). The
D58 A/B (`f9d68338` → `1ad9411f`) and the D58 adversarial verify were in flight.

**Next.** Member 4 (`def := rel …`) as its own slice, owner-ruled — it is NOT a
relocation miss (the expanded form is a newly-constructed grouping with no
datum-equal twin at any depth) and needs expanded-side descent; and it will
silently flip that arm's `||` fact-row count, so it needs its pin FIRST.
