# PAR 4 D.3 — wave 2 briefing (given verbatim to every wave-2 agent)

You are one of ten agents in the **second wave** of an adversarial critique of a compiler design. Wave 1 had ten
independent critics. Their 103 findings were triaged by hand into 18 clusters. Your job is narrower than wave 1's:
**settle**, **defend** or **cover a gap** in one assigned area, with evidence.

You work alone and do not see the other wave-2 agents' output. Some of them may be running probes on the same
machine at the same time.

## The project, in five sentences

Prologos is a functional-logic language whose compiler (Racket 9.3, `#lang racket/base`) runs on a **propagator
network**. Cells hold lattice values; propagators fire when their inputs change and write joins into cells; a
scheduler runs them to a fixpoint. The network is **stratified**: S0 is the monotone value stratum, and topology
changes, retraction (S(−1)) and negation-as-failure (S1) run sequentially at stratum boundaries. Today's production
scheduler is BSP (bulk-synchronous rounds: snapshot, fire every queued propagator, merge all writes, repeat).
PAR 4 ("Arena Executors") is the track that makes S0 execution as fast as possible, grounded in measurement: DIRECT
writes at K = 1, then K > 1 executors.

## What to read

Paths are relative to the worktree root `/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors`
(branch `par4-arena-executors` at `df80be74`; its `racket/prologos/` production code is identical to `main` at
`c1f389ab`).

1. **The triage**: `docs/tracking/tracks/PAR/PAR_4/critiques/2026-10-15_PAR_4_D3_WAVE1_TRIAGE.md`. Read it in full,
   and especially the clusters named in your charge.
2. **The design under critique**: `docs/tracking/tracks/PAR/PAR_4/2026-10-15_PAR_4_D2_DESIGN.md` (D.2). Read the
   sections your clusters name.
3. **Wave 1's evidence**: `racket/prologos/benchmarks/par4/d3-wave1/`.
   - `<critic>/` holds each critic's probes and their outputs.
   - `raw/` holds the full JSON returns of C1–C5, C8 and C9.
   - `wave1-findings-index.json` indexes all 103 findings.

   Read the raw returns for the findings in your clusters. **Reuse or adapt wave 1's probes** rather than starting
   from nothing. Copy them into your scratch directory first; never edit them in place.
4. As needed: the wave-1 briefing `critiques/2026-10-15_PAR_4_D3_WAVE1_BRIEFING.md`, the P0 record
   `2026-10-13_PAR_4_P0_MEASUREMENTS.md`, D.1 `2026-10-12_PAR_4_D1_DESIGN.md`,
   `docs/tracking/principles/DESIGN_PRINCIPLES.org`, `docs/tracking/principles/CRITIQUE_METHODOLOGY.org`, and the code
   under `racket/prologos/`.

The methodology's external briefing (`CRITIQUE_METHODOLOGY.org`, § Orientation for External Critics) applies to your
proposals. Phrase directions as information flow (which cells, which propagators), not as "first do X, then Y". The
ten design principles are the evaluation criteria. Your domain expertise is wanted.

## Rules

1. **Read-only on the repository.** Do not edit, create, delete, commit, stash, checkout or push anything in the
   worktree or in `/Users/avanti/dev/projects/logos/prologos`. **Never create a git worktree or write anything under
   `.git`.** Put every probe in your own scratch directory,
   `/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/<your id>/`.
2. **Racket**: `"/Applications/Racket v9.3/bin/racket"`. The path contains a space, so quote it.
   - A probe requires modules by absolute path, e.g.
     `(require (file "<worktree>/racket/prologos/propagator.rkt"))`.
   - To run a `.prologos` program and see its results, use `<worktree>/tools/scratch-run.sh -t <secs> <file>`, one file
     per process. A bare `process-file` prints nothing.
   - Wrap every run in `timeout -k 10 <seconds>`.
   - Run **at most one Racket process at a time**, and keep each run under about 60 s of CPU unless your charge says
     otherwise.
   - **Never** run the full test suite. **Never** `pkill` or `killall` by name.
   - **Do not rebuild anything in the repository.** Only W2-2 may build, and only in its scratch copy (its charge
     says how).
3. **Evidence classes**: THEOREM (state its hypotheses), MEASUREMENT (give the command and its output), PRECEDENT
   (cite it), CONJECTURE, ESTIMATE (state the inputs), TASTE.
   - Every count needs the command that produced it.
   - Every "0", "identical" or "no difference" needs a **power check**: show that the method finds a case that
     should be found.
   - Cite code as `path:line`, re-derived at HEAD.
   - Timing is evidence only when it is held under the suite lock and interleaved, with the machine load stated
     (`uptime`). Prefer counts and allocation where they answer the question.
4. **Settlers** return one verdict for each contested question in their charge. A verdict is one of: the finding
   holds · it holds with an amendment · it fails · undetermined, saying what would settle it. Each verdict comes with
   its power check.
5. **Defenders** argue for the D.2 position they are assigned, from the codebase and the principles, against **the
   strongest form** of the findings they answer. Say what in the attack you concede. A defence that concedes nothing
   is not credible.
6. **Gap critics** critique as wave 1 did, in wave 1's finding format.
7. **Do not pad.** Three grounded results beat fifteen speculative ones.

## What to return

Your final answer must be one JSON object. Prose goes inside its fields.

```json
{
  "agent": "W2-<n> <name>",
  "role": "settler | defender | gap-critic",
  "summary": "≤ 8 sentences",
  "verdicts": [
    {
      "question": "the contested question, as given in your charge",
      "clusters_and_findings": ["CL-1", "C7-2"],
      "verdict": "holds | holds-with-amendment | fails | undetermined",
      "amendment": "if any",
      "evidence": "command + output, path:line, theorem with hypotheses",
      "evidence_class": "THEOREM | MEASUREMENT | PRECEDENT | CONJECTURE | ESTIMATE | TASTE",
      "power_check": "how you know the method could have found the opposite",
      "confidence": "high | medium | low"
    }
  ],
  "defence": {
    "position": "for defenders: the D.2 position defended",
    "concessions": ["what you concede"],
    "argument": "the case, grounded",
    "design_that_would_make_it_pay": "if any"
  },
  "findings": [
    "wave-1 format for new findings: id W2-<n>-<k>, lens, section, claim_attacked, severity, evidence, evidence_class, direction, falsifier, confidence"
  ],
  "probes": ["absolute path of each probe file, with its output file"]
}
```

Settlers fill `verdicts`. Defenders fill `defence`, and add `verdicts` where they settle a question along the way.
Gap critics fill `findings`. Any role may add `findings` for something new.

## Shared instruments

- **Executor injection point.** BSP takes its fire executor from the parameter `current-parallel-executor`
  (`propagator.rkt:3675`; exported).
  - An executor is `(lambda (snapshot-net pids) -> (listof fire-result))`. The sequential one is
    `sequential-fire-all` (`:3295`), which calls `fire-and-collect-writes snapshot-net pid idx` per pid. Both are
    exported.
  - `driver.rkt:567` sets the parameter, at load, to `(make-parallel-thread-fire-all)`.
  - Supplying your own executor lets you turn the thread executor off (`sequential-fire-all`), time each fire, or
    run fires on a thread created earlier, with **no rebuild**.
- **Other hooks.** `current-bsp-observer` (per-round diffs) and `current-bsp-round-stats` (per-round fire and merge
  times) are exported. Wave 1's probes show how to use them, e.g. `d3-wave1/C3/home_fence_probe.rkt`,
  `d3-wave1/C7/placement.rkt`, `d3-wave1/C10/hub-probe.rkt` and `d3-wave1/C2/probe-executor-ab.rkt`.
- **The two heavy files** are `racket/prologos/benchmarks/comparative/constraints-adversarial.prologos` and
  `type-adversarial.prologos`. The medium tier is the 19 files in that directory.
- **The suite lock**, required for timing:
  `"/Applications/Racket v9.3/bin/racket" <worktree>/racket/prologos/benchmarks/par4/hold-suite-lock.rkt <worktree>/racket/prologos/tools/suite-lock.rkt <cmd> <args…>`.
  It holds the machine-wide lock exclusively while `<cmd>` runs. It does **not** stop other agents' probes, so state
  the load and interleave the legs.

## Charges

Each agent's charge is the entry with its id. Questions are numbered; settlers return one verdict per question.

### W2-1 — granularity settler (CL-1, CL-4, CL-16)

Run with the thread executor off (inject `sequential-fire-all` or a timing executor).
1. Under D.2's per-cell home rule (a fire runs on the owner of its first output; round-robin; K = 8), is the busiest
   executor's share **by fire time** (not by count) ≥ 0.8 on the two heavy files? C3-1, C7-2 and C10-1 measured it
   by count.
2. Under **per-component** ownership, what are the busiest share by time and the effective parallelism, at
   K ∈ {4, 8, 16}?
   - A component is a (position, facet) of the attribute map.
   - A fire's home is the owner of the first component it writes, taken from its declared `#:component-paths` or
     from the keys of the delta it writes.
   - Effective parallelism is Σ width / Σ max-per-home per round, both by count and weighted by time.
   - Power row: homing by propagator id.
3. Compare **per-cell fencing** with **per-component fencing**, where per-component fences only the attribute map's
   `:type` components and the type cells. For each: what share of fires and of fire time is fenced, and how many
   fenced↔free crossings (alternations) occur per S0 run on the critical path?
4. Repeat 1–3 on at least 8 of the 19 medium-tier files, one per process. Do not stop at the two heavy files.

Deliver a table, and a verdict on **whether P3 has a workload under any ownership unit**.

### W2-2 — P2-lite settler (CL-2, CL-16); the only agent allowed to build

Build a scratch copy:

```
mkdir -p <scratch>/tree && git -C <worktree> archive HEAD racket/prologos tools | tar -x -C <scratch>/tree
```

`git archive` reads the object store and writes nothing under `.git`. Edit only inside `<scratch>/tree`.

Put **both variant switches behind environment variables read at module load**, so that one build serves every leg:
- `W22_EXEC_OFF`: the driver does not install the thread executor;
- `W22_KEYED_DIFF`: for merges whose result keeps every key of `old` that is outside `new`'s keys `eq?` to before,
  diff only `new`'s keys.

Build with:

```
cd <scratch>/tree/racket/prologos && PLT_CS_COMPILE_LIMIT=1000000 "/Applications/Racket v9.3/bin/raco" make -j 4 driver.rkt <your harness>
```

The `.pnet` cache is not in git, so the first runs regenerate it; discard them as warm-up.

1. How much command time does removing the thread executor save on the two heavy files, and on the medium tier?
2. Is the keyed diff's output identical to the full diff on every write? Answer with an equivalence monitor in the
   variant (sampled or full), plus a power row: a keyed diff that deliberately drops one key must be caught.
3. Measure command time for four legs: as-is; executor off; keyed diff; both. Run the heavy files and the medium
   tier, at least 7 interleaved runs each, holding the suite lock, with `uptime` recorded.
   - Is C10-3's estimate borne out by its keyed-diff part?
   - Implement the delta-carried writes only if they fit in bounded time. Otherwise estimate their part, stating the
     inputs.
4. Re-derive P2's model with the executor off and the keyed diff on, from a single instrument. What gain would P2
   still have?

Time budget: about 90 minutes.

### W2-3 — detector protocol settler (CL-3, CL-10, CL-11)

1. Reproduce, in one model of your own, the premature declaration that C1-4, C3-4 and C5-1 found in D.2's detector
   (an idle-epoch max-counter, Σprod = Σcons, two scans).
2. Build one exhaustive model containing:
   - K = 2–3 executors;
   - local cascades triggered by a drained delta;
   - counted fire requests for dependents homed elsewhere;
   - a contradiction stop;
   - nested regions keyed by network id;
   - a **store-buffering** memory abstraction: an executor's store may be delayed past its own later loads unless a
     store→load fence intervenes.

   In that model, check each repair:
   - (a) D.1's resettable flag;
   - (b) an activity parity counter (C5);
   - (c) a quiet mark (e, consᵢ) (C3);
   - (d) cons published only after the cascade drains (C1, C5);
   - (e) credit recovery with a monotone threshold (C1; Mattern 1989; Huang 1989).

   For each: is it sound, is it live, how many fences does it need, and which of its state are monotone cells?
3. The late-write check (C5-7): with the chosen detector, is write-then-check with fences needed, or a parking
   handshake? Do lanes modelled as logs with cursors, so that prod and cons are derived reads (C4-8), remove the
   ordering invariant between separate cells?
4. Measure the cost of the smallest sound repair. Copy `benchmarks/par4/detect.rkt`, and add a CASCADE row (a delta
   that triggers a local chain) beside its CHAIN and BURST rows. Use K ∈ {2, 4, 8} on parallel threads. Report ns per
   message, with the load.

### W2-4 — production-defect settler (CL-5)

1. **PD-1 / DEFERRED 177.**
   - When does `:strategy auto` pick ATMS? Look at `solver.rkt:76-77` and where it is used.
   - Run a DFS-against-ATMS answer differential over the relational examples and test programs you can extract
     (`racket/prologos/examples/`, `racket/prologos/tests/`, `lib/`). One `.prologos` per process, at most 20
     programs.
   - Do any existing tests pin a wrong answer?
2. **PD-3.** Do fires on today's thread-per-round executor touch shared mutable state? Reproduce a race or bound it.
   - Candidates: `set-box!` on `current-prop-net-box` (`resolution.rkt:373, 386`, reached through the retry bridge
     at `metavar-store.rkt:1063`); `current-persistent-registry-net-box`; meta-store hashes; the perf counters
     (compare `PERF-COUNTERS` totals between executors, since increments without atomics lose counts); the
     observer.
   - Use injected executors, and compare outcomes over many runs.
3. **PD-2 / DEFERRED 178.** Measure how far production reaches it. Bound it statically (the five `relations.rkt`
   sites), and dynamically with a **generic non-fixpoint detector** that needs no rebuild: after
   `run-to-quiescence` returns, re-fire every propagator once on the result network and report any cell that
   changes. Apply it to the relational examples. Power row: C2's Tier-1 probe must be flagged.
4. **PD-5.** Does any example or test drive the strata outer loop (`propagator.rkt:3619-3634`) past 10 iterations?

For everything confirmed, return text ready to go into DEFERRED: title, found by, reproduction, reach, fix shape.

### W2-5 — ambient-state census settler (CL-13)

1. **Static census.** Which parameters do S0 fire bodies read, directly or through production callees?
   - Enumerate the fire functions passed to `net-add-propagator`, `net-add-fire-once-propagator`,
     `net-add-broadcast-propagator` and their wrappers.
   - Approximate the call graph by module-level names.
   - Find the calls `(p)` where `p` is bound by `make-parameter`.
   - Tabulate: parameter · defining site · how it is assigned (`parameterize`-scoped, assigned directly per
     command, at install time, or at module level) · which fires read it.
   - Power check: the census must find `current-source-loc`'s 5 reads and `current-worldview-bitmask`'s reads
     through `maybe-wrap-worldview`.
2. Which of those parameters would hold a stale or wrong value:
   - (a) on a persistent executor created once per process (C6-2);
   - (b) on today's thread-per-round executor? Do any fires **assign** parameters or `set-box!` shared boxes,
     whose effects a per-round thread would lose or race on? This overlaps with W2-4 Q2, which is fine.
3. Confirm the top candidates dynamically with no rebuild. Compare injected executors (sequential; a fresh thread
   per round; one thread created earlier and reused) on the heavy files and on speculation-heavy examples.

### W2-6 — worldview coherence settler (CL-6)

1. Are these proposals consistent with each other?
   - (a) The read is ev_W = base ⊔ matching entries (C4-1, C9-3).
   - (b) Cell-1 is split. The information becomes a derived projection α(decisions, nogoods); the viewpoint W is
     carried per propagator or per query (C4-4, C2-4).
   - (c) Labelledness is closed downstream: labelled fires write only tagged cells, and promotion happens at the
     topology tier (C9-4). Lifting is additive or evaluated on the union-closure of the labels (C4-7).
   - (d) Invalidation happens only at boundaries, over completed inputs (C8-5).
   - (e) `unify-fire` writes each side into the other (C4-12).
   - (f) D.2's two-phase set. Is it still needed once (b) is in place?
2. List cell-1's production writers at HEAD (C2-4's inventory). What does each become under the combined proposal?
3. Which tests pin today's semantics and must flip (`test-tagged-cell-value.rkt:213-224`,
   `test-solver-context.rkt:341-362`, others)? Which would catch a regression? Run lattice-level probes (adapt C4's
   and C9's) on the combined design.
4. At the lattice level, does the combined proposal fix DEFERRED 177's three rows? Probe it.

### W2-7 — merge-row settler (CL-14)

1. **`:usage`** (contested: C4-6 against C9-9).
   - Let ⊥ stand for an unsolved multiplicity. Are + and · monotone and associative at every arity on the chain
     ⊥ < m0 < m1 < mw? Or is the interval lattice the right carrier?
   - Under the obligation of one writer per position (C9-9), is the cell merge exercised at all?
   - Which carrier preserves today's QTT verdicts? Extract cases from `tests/test-qtt*.rkt` and run a few.
2. **Row 8.** Re-run C4's oracle (`d3-wave1/C4/c4-type-oracle.rkt`) on a richer universe: dependent codomains, Sigma,
   type applications (`List ?a`), and nested unions.
   - Does "`try-unify-pure` fails ⇒ ⊤" stay free of erasures for Role B?
   - Is the blocked share still confined to multiplicity metas and unions that hold a meta?
3. **Role A against Role B.** Over at most 15 suite test files, one per process, record the installed merge of every
   cell written in S0. Which carry `type-lattice-merge` (Role A) and which `type-unify-or-top` (Role B)? See C8-1:
   `sre-core.rkt:2277-2297` against `elaborator-network.rkt:359-365`.
4. **Row 2.** At the lattice level, with the ev_W read and `unify-fire` writing both sides, does a flat ⊤ per key
   produce DFS's answers on C9's programs? What must ⊤ mean: a branch's nogood, or the query's failure?

### W2-8 — defender: K > 1 belongs in PAR 4 (against CL-1, CL-4, C10-6, C6-5)

**Position**: P3 belongs in PAR 4, and a design exists that makes it pay on today's workloads or the near-term ones.

Engage:
- CL-1's measurements of the hub cell;
- CL-4's problems with the fence;
- C10-6's proposal to defer K > 1 to a sequel;
- C6-5's point that K is a machine budget.

Consider:
- ownership at component granularity;
- files whose S0 is **not** concentrated on the hub (the relational and solver files, e.g. `atms-adversarial`,
  `solve-adversarial`, `scheduler-adversarial`, `parity-adversarial`): measure per-file hub share across the 19 files
  with C10's `hub-probe.rkt`;
- user-level networks (`net-run`, `reduction.rkt:4456`) and solver networks as first targets;
- BSP-LE 3's coming search workload;
- the cost of building the substrate now against later.

Return the defence, and a verdict on: **is there a workload in the repo today where K > 1, under some ownership
unit, gives ≥ 1.5× on S0?**

### W2-9 — defender: DIRECT at K = 1 (P2), and BSP as the reference (against C10-3, C10-6, C1-8, C3-9, C1-7)

**Position**: P2 stays in PAR 4 as planned, and BSP stays as the replay oracle.

Argue what DIRECT gives beyond speed:
- the undeclared-write class disappears (C2-8);
- no snapshot ceremony;
- one semantics for fire-once (CL-7);
- a substrate for K > 1;
- determinism.

Then answer:
- Is P2-lite a step toward DIRECT or a substitute for it? C10-3 says DIRECT keeps the in-fire and outside-BSP diffs,
  so is the keyed diff needed under DIRECT as well?
- C1-8: is a lifted Kleene network (sparse per-depth values) sound, and cheaper than keeping BSP's inner loop as the
  oracle? State the theorem with its hypotheses, and probe a fixture if that is feasible.

Return the defence, and verdicts on: **does P2 deliver value that P2-lite does not?** and **is a lifted Kleene
network a sound and cheaper replacement for BSP as the oracle?**

### W2-10 — gap critic: users' and developers' experience

No wave-1 critic covered this. Critique D.2 and the triage from the side of the user and of the compiler developer,
after P2 and at K > 1:
- **Diagnostics.** Are they deterministic, and good? Which contradiction or error gets reported (C5-8, C9-7)?
  Consider `error-explanation.rkt` and D.2 §7's derivations over rounds.
- **The LSP and the VS Code propagator view** (`lsp/server.rkt:519, 547`; `trace-serialize.rkt`;
  `editors/vscode-prologos/src/propagatorView.ts`). What breaks, and what do they need from §7?
- **Reproducibility.** Can a failure under a nondeterministic schedule be reproduced? Consider seeds,
  record/replay, and the parity suite's design (D.2 §10.2).
- **User-visible semantics** of `:fuel`, `:timeout` and `:execution` (C2-9; `solver.rkt`; `macros.rkt:1009`).
- **Progressive disclosure.** A newcomer should never meet K, epochs or fences.
- **Predictability.** Variance in run time at K > 1.

Use wave 1's finding format. Small probes are allowed, e.g. run a program that has an error under BSP with the
executor on and off, and compare the reported errors.
