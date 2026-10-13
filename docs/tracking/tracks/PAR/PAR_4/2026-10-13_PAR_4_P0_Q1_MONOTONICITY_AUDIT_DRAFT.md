# PAR 4 · P0 — Q1 static monotonicity audit (DRAFT, agent-written)

**Serves**: PAR 4 — Arena Executors, Pre-0 (P0) of
[`2026-10-12_PAR_4_D1_DESIGN.md`](2026-10-12_PAR_4_D1_DESIGN.md) §9, items **A-1, A-2, A-3** as
defined in [`research/…_STAGE1_RESEARCH_SYNTHESIS.md`](research/2026-10-12_PAR_4_STAGE1_RESEARCH_SYNTHESIS.md)
lines 114–116, and gap **Q1** of [`2026-10-12_PAR_4_STAGE2_GAP_ANALYSIS.md`](2026-10-12_PAR_4_STAGE2_GAP_ANALYSIS.md) §3.
**Status**: DRAFT, agent-written input. It is not the record. **Superseded by the synthesis of
record, [P0 record §9](2026-10-13_PAR_4_P0_MEASUREMENTS.md)** (2026-10-13): 9 claims spot-checked
(all hold); M3, M4 and the guard measured — §9's follow-up #1 ("declare the undeclared outputs")
is necessary but **not sufficient** for the guard: the LWW lattice is the defect (DEFERRED 157).
**Written at** `7a0116ec`. All `file:line` citations are against that commit in the main
checkout, relative to `racket/prologos/` unless a path is given.

**Pin note (MEASUREMENT).** `git rev-parse --short HEAD` printed `7a0116ec` when the work began.
HEAD then advanced during the session, to `f3d7f5e3` via `4a92da5c` (driver+lsp check-only
diagnostics) and `f3d7f5e3` (DEFERRED docs). Between the two commits,
`git diff --stat 7a0116ec f3d7f5e3 -- racket/prologos` changes only two production files:
`driver.rkt` and `lsp/server.rkt` (the rest are in tests/, tools/, benchmarks/). Consequences:

- Every non-`driver.rkt` citation is identical at both commits.
- Every `driver.rkt` line number here was read with `git show 7a0116ec:racket/prologos/driver.rkt`.

In the text, "HEAD" means `7a0116ec`.
**Census scope**: every `*.rkt` under `racket/prologos/` **excluding `tests/`, `benchmarks/`,
`tools/`, `compiled/`**. That leaves 135 files: 120 top level, `lsp/` 3, `redex/` 11,
`data/probes/` 1. None of the subdirectories has an install site.
**Method**: static reading only. The schedule-variation suite runs separately and is not
consulted here. Re-run commands are in §11.

Labels: **THEOREM** = a cited mathematical result with its hypotheses; **MEASUREMENT** = a
count or a fact read from code at `7a0116ec`; **JUDGEMENT** = this author's classification or
argument, open to dispute.

---

## 0. Result

The census finds **144 production call sites** of the propagator-install APIs. Thirteen of
them are wrapper definitions or generic internals (WRAP). Thirteen more sites install a fire
function through those wrappers. That gives **157 sites**: 144 classified and 13 wrappers.
Most are monotone in the sense the asynchronous-iteration theorem needs:

- 14 monotone by construction.
- 87 monotone by a one-line argument (29 of these also emit topology requests).
- 17 stable latches.

The remainder needs attention:

| verdict | sites |
|---|---|
| THRESHOLD/LATCH-U: fire-once over an input that can still grow | 7 |
| ABSENCE-READING | 8 |
| NON-MONOTONE | 4 |
| TOPOLOGY-EMITTING only | 1 |
| UNCLEAR | 6 |

Two facts matter more than any single site:

**(1) A-2 fails on S0-written cells.** Of the three named non-join merges, only
`merge-hasheq-replace` has an S0 writer: the constraint store, written by the constraint-retry
bridge fire. `merge-list-append` and `merge-replace` cells are written only at
construction, declaration, or post-quiescence time. The real A-2 exposure lies elsewhere, in
merges the brief did not list but that S0 fires write on every elaboration and every query:

| merge | site | behaviour |
|---|---|---|
| `scope-cell-merge` (logic variables) | `decision-cell.rkt:887-904` | per-key "new wins" |
| attribute-map `:usage` facet | `typing-propagators.rkt:416` | merge = `add-usage`, where 1+1 = ω |
| attribute-map `:warnings` facet | `typing-propagators.rkt:418` | append |
| worldview cache, cell-1 | `propagator.rkt:960` | LWW |
| resolution request, cell-14 | `propagator.rkt:802` | append |
| fork-on-union request, cell-15 | `propagator.rkt:815` | per-key LWW |
| `type-unify-or-top` | `type-lattice.rkt:203-219` | its result depends on an ambient meta-solution callback, and its fallback is non-commutative |

**(2) BSP semantics that code relies on.** Several behaviours are properties of the BSP
scheduler rather than of the fire functions, and a DIRECT executor must reproduce or retire
them:

- **Undeclared writes overwrite.** Writes to undeclared outputs are applied as a direct set that
  bypasses the merge (`propagator.rkt:3018-3045`).
- **Fire-once lives only in the BSP loop.** Its "self-clear only after a productive fire" rule
  is implemented there alone (`propagator.rkt:3307-3399`). The Gauss-Seidel drain ignores it
  (`propagator.rkt:2713-2766`).
- **Re-installed propagators lose metadata.** Propagators created inside a fire are re-installed
  with flags, assumption, component paths and srcloc dropped (`propagator.rkt:3060-3066, 3376`).
- **A parameter picks the code path.** Eleven fire-time reads of `current-bsp-fire-round?`
  choose between emitting a topology request and mutating topology inline.

---

## 1. What is being checked

**THEOREM** (asynchronous / chaotic iteration; Bertsekas 1983, Üresin–Dubois 1990). Take a
product of lattices with the ascending chain condition. Take an operator whose components are
**monotone** (A-1). Write updates into cells by a **join**, i.e. a merge that is commutative,
associative, idempotent and inflationary (A-2). Require bounded staleness of reads, and require
that every component is re-applied after each change of its inputs (fairness). Then
asynchronous iteration reaches the same least fixpoint above the initial state as
round-synchronous (BSP) iteration.

- **A-3 is a special case of A-1.** Suppose a fire function tests an input for ⊥ / `'none` /
  empty / `#f` and writes something in that case that it would not write once the input is
  filled. Then f(⊥) ⋢ f(x) for some x ⊒ ⊥, so f is not monotone.
- **Fire-once interacts with fairness.** A fire-once propagator is never re-applied after its
  first productive fire. It is equivalent to a monotone operator only if its output is
  constant on the up-set of the input state at which it first produced output.

**Classes used** (JUDGEMENT categories, following the brief):

| class | meaning |
|---|---|
| MBC | MONOTONE-BY-CONSTRUCTION: copy, constant write, or a pure function of inputs into a join |
| MA | MONOTONE-ARGUED: needs the one-line argument given in the row. `+TOPO` = also writes a topology-request cell (set-union merge) |
| TL-S | THRESHOLD/LATCH, stable: the trigger is upward-closed and the written value cannot change above the trigger |
| TL-U | THRESHOLD/LATCH, unstable: the trigger is upward-closed, but the value written at the first productive fire can differ from the value at a larger input. Under fire-once the later value is dropped, so the result depends on *when* the first productive fire happens |
| AR | ABSENCE-READING: the quoted test acts on ⊥/absent and writes something it would not write once the cell is filled. "Own-output guard" = the absent cell is the propagator's own output |
| NM | NON-MONOTONE: can write a smaller value or retract, or has external side effects |
| TOPO | TOPOLOGY-EMITTING only |
| UNC | UNCLEAR: the row says what would decide it |
| WRAP | wrapper or generic internal; the fire function is supplied by a caller, which is classified at its own row |

**Mechanism facts** that the classification relies on (MEASUREMENT):

- **M1 — every propagator is an S0 propagator.**
  - The propagator struct has no stratum field: `(struct propagator (inputs outputs fire-fn
    broadcast-profile flags srcloc))` at `propagator.rkt:364`.
  - Strata other than S0 exist only as stratum handlers, which are functions run between S0
    runs (`register-stratum-handler!` at `propagator.rkt:3198`; `process-tier` at `:3441-3479`).
  - Comment labels such as "S1 trait-resolution propagator" (`typing-propagators.rkt:908-916`)
    and "S2 … fire after S0+S1 quiesce" (`:1571-1577`) are **not enforced**. Those propagators
    fire in S0.
- **M2 — fire-once is a BSP-scheduler feature.**
  - The BSP loop keeps a `fired-set` (`propagator.rkt:3307-3332`).
  - It marks a fire-once propagator fired and removes it from its inputs' dependents **only if
    that fire produced declared value-writes or new cells** (`:3378-3399`). A fire that returns
    the net unchanged leaves the propagator armed.
  - The Gauss-Seidel drain (`:2713-2766`) has no fire-once handling at all.
- **M3 — undeclared writes bypass the merge in BSP.**
  - `fire-and-collect-writes` diffs only declared outputs into `value-writes` (`:2876-2883`).
    Any other changed cell becomes an `undeclared-write` (`:2904-2908`).
  - `bulk-merge-writes` applies undeclared writes by `struct-copy` of the whole cell value — a
    direct set, not `net-cell-write` (`:3018-3045`). Two undeclared writers of one cell in one
    round therefore lose an update even under BSP. A DIRECT executor that writes through the
    merge has different semantics for these sites.
- **M4 — re-installation drops metadata.** A propagator created inside a fire is re-installed
  by the scheduler from `(inputs outputs fire-fn)` only (`:3060-3066`, `:3376`).
  `PROP-FIRE-ONCE`, `#:assumption`, `#:component-paths` and `srcloc` are lost.
- **M5 — `current-bsp-fire-round?` selects the path inside fires.**
  - When `#t`, decomposition emits a request to a topology cell.
  - Otherwise it creates cells and propagators inline.
  - Read sites: `elaborator-network.rkt:897`, `sre-core.rkt:2469, 2689, 2712, 2804, 2817`,
    `narrowing.rkt:296, 348`, `constraint-propagators.rkt:288`, plus `net-add-propagator` /
    broadcast scheduling at `propagator.rkt:2325, 2499`.
- **M6 — tagged reads depend on S0-written state.** `net-cell-read` of a tagged cell filters by
  `current-worldview-bitmask`, or by the worldview cache **cell-1** if that parameter is 0
  (`propagator.rkt:1596-1601`). Cell-1 has merge `worldview-cache-merge = (if (= old new) old
  new)`, i.e. LWW (`propagator.rkt:960-961`).

---

## 2. Census (MEASUREMENT)

**APIs and their production call sites.** The `net-add-propagator` definition is at
`propagator.rkt:2253`; the brief's ~2285 is approximate.

| API (definition) | call sites | notes |
|---|---|---|
| `net-add-propagator` (`propagator.rkt:2253`) | **108** | 6 of these are inside `propagator.rkt` wrappers |
| `net-add-fire-once-propagator` (`:2346`) | **30** | |
| `net-add-broadcast-propagator` (`:2434`) | **1** | `elab-network-types.rkt:232`, a wrapper |
| `net-add-parallel-map-propagator` (`:2510`) | **0** | deprecated |
| `net-add-cross-domain-propagator` (`:4419`) | **5** | `cap-type-bridge.rkt:218`, `driver.rkt:3844, 3855`, `session-type-bridge.rkt:123, 133` |
| `net-add-threshold` / `net-add-barrier` (`:2557` / `:2570`) | **0 / 0** | |
| **total** | **144** | |

**Per-file counts:**

| file | sites |
|---|---|
| `elaborator-network.rkt` | 40 |
| `typing-propagators.rkt` | 34 |
| `relations.rkt` | 10 |
| `propagator.rkt` | 8 |
| `session-propagators.rkt` | 8 |
| `session-runtime.rkt` | 6 |
| `sre-core.rkt` | 6 |
| `unify.rkt` | 5 |
| `wf-propagators.rkt` | 5 |
| `constraint-propagators.rkt` | 4 |
| `driver.rkt` | 3 |
| `elab-network-types.rkt` | 3 |
| `cap-type-bridge.rkt` | 2 |
| `narrowing.rkt` | 2 |
| `session-type-bridge.rkt` | 2 |
| `bilattice.rkt`, `capability-inference.rkt`, `effect-bridge.rkt`, `effect-ordering.rkt`, `namespace.rkt`, `reduction.rkt` | 1 each |

**Wrappers that take a fire function**, and their production callers. The fire function is
classified at the caller.

| wrapper (definition) | callers |
|---|---|
| `elab-add-propagator` (`elab-network-types.rkt:182`) | `metavar-store.rkt:692, 850, 1063` |
| `elab-add-fire-once-propagator` (`:201`) | `metavar-store.rkt:542, 562` |
| `elab-add-broadcast-propagator` (`:224`) | `metavar-store.rkt:487` |
| `rt-add-propagator` (`session-runtime.rkt:489`) | `session-runtime.rkt:517, 657, 809, 871, 954, 962` |
| `module-network-install-fire-once` (`namespace.rkt:311`) | `driver.rkt:1704` (HEAD numbering) |
| the `current-prop-add-propagator` callback (`driver.rkt:3721-3725`) | **none**; the parameter is a stub, never invoked (`metavar-store.rkt:1448-1451`) |

That is 13 caller sites, so **157** sites are audited in total.

**Reconciliation with the brief's "130".** My count for the first three APIs is 108 + 30 + 1 =
**139**. The brief's 130 was not reproduced:

- A line count of `(API` that includes comments gives 145. Its extra hits are comment lines in
  `metavar-store.rkt:514` and `merge-fn-registry.rkt:101` and definition lines.
- My figure excludes comment-only text and definition lines, and includes calls where the API
  name ends the line. The first pass of my own grep missed 7 such end-of-line calls before I
  corrected the regex.

The D.1 risk row's "finite audit list (103 sites)" (`D1_DESIGN.md:535`) counted
`net-add-propagator` alone and is superseded by 157.

**Production reachability.** These sites have **no production caller** (grep for `(name` at
HEAD, tests excluded). They are listed but do not affect the live verdicts:

- `effect-ordering.rkt:223`
- `constraint-propagators.rkt:239, 256, 280, 303`
- all 5 `wf-propagators.rkt` sites (`wf-compile-program` has 0 callers)
- `session-runtime.rkt:517` (`maybe-install-io-bridge` has 0 callers)
- `driver.rkt:3724`
- `propagator.rkt:2516, 2563, 2587`

`elaborator-network.rkt:227` has no direct call either, but it is live: it is installed as a
callback through `install-prop-network-callbacks!` (`driver.rkt`, HEAD `:3708-3714`).

---

## 3. Verdict counts (JUDGEMENT; per site)

| class | sites | of which no production caller |
|---|---|---|
| MBC | 14 | 0 |
| MA | 87 | 9: `effect-ordering:223`, `constraint-propagators:239, 256, 303`, `wf-propagators` ×5 |
| TL-S | 17 | 0 |
| TL-U | 7 | 0 |
| AR | 8 | 0 |
| NM | 4 | 1 (`session-runtime.rkt:517`) |
| TOPO only | 1 | 1 (`constraint-propagators.rkt:280`) |
| UNC | 6 | 0 |
| WRAP | 13 | 4 (`driver:3724`, `propagator:2516, 2563, 2587`) |
| **total** | **157** | |

**`+TOPO` secondary tag**: 29 of the 87 MA sites. They are:

- `elaborator-network.rkt`: the 20 structural-unify sites.
- `sre-core.rkt:2426, 2765`.
- `unify.rkt`: 5 sites.
- `session-propagators.rkt:310`.
- `narrowing.rkt:219`.

`narrowing.rkt:238` (UNC) also emits topology requests. Together with the one TOPO-only site,
that makes **31** topology-emitting sites in all. Every topology request cell (cells 6–9) has
merge `topology-request-merge`, which is set-union (`propagator.rkt:951`; comment at
`:660-665`) — a join. TOPO is therefore not itself an A-2 problem.

---

## 4. Per-site tables

Columns: `file:line | API | fire fn | class | evidence | multiplicity`.

API abbreviations:

| abbreviation | API |
|---|---|
| nap | `net-add-propagator` |
| fo | `net-add-fire-once-propagator` |
| bc | broadcast |
| xd | `net-add-cross-domain-propagator` |
| eap / efo / ebc | `elab-add-propagator` / `elab-add-fire-once-propagator` / `elab-add-broadcast-propagator` |
| rap | `rt-add-propagator` |
| mfo | `module-network-install-fire-once` |

Rows with an identical fire function are grouped. Every line is listed.

### 4.1 `elaborator-network.rkt` (40)

| file:line | API | fire fn | class | evidence | multiplicity |
|---|---|---|---|---|---|
| 227, 461, 467, 517, 523, 572, 576, 615, 619, 623, 660, 664, 695, 731, 735, 771, 775, 813, 817, 871 (20) | nap | `make-structural-unify-propagator` `:928-951` | MA +TOPO | The bot branches write the other side's value (`:936-941`). That equals va ⊔ vb, because ⊥ is the unit of `type-unify-or-top` (`type-lattice.rkt:205-206`). Otherwise it writes `type-unify-or-top va vb` to both cells, or `type-top`. Under BSP, `maybe-decompose` writes `(set (sre-decomp-request …))` to cell-7 (`:897-905`); otherwise it decomposes inline. Caveat: the cell merge consults ambient meta state (§6) | per unify constraint (`:227`), or per component of a decomposed compound-type pair; created in the topology handler `:1134-1166` or inline on the DFS path |
| 472, 476, 527, 531, 580, 583, 627, 630, 667, 670, 698, 701, 738, 741, 778, 781, 820, 823, 877, 880 (20) | nap | Pi/app/Sigma/Eq/Vec/1/Map/pair/lam/generic reconstructors `:407-431, 547-556, 589-599, 636-645, 676-682, 707-716, 747-756, 787-796, 836-845` | MA | `[(or (type-bot? …) …) net]` waits while any sub-cell is ⊥, an upward-closed condition. Any `type-top` input writes `type-top`. Otherwise it writes ctor(sub-values), which is monotone in each argument under the unification order | 2 per decomposed pair (one per side) |

### 4.2 `typing-propagators.rkt` (34)

All write the attribute-map cell `tm-cid`. Its merge is `attribute-map-merge-fn`
(`:447-470`): per-position, per-facet. The facets merge as follows:

| facet | merge |
|---|---|
| `:type` | `merge-classify-inhabit` (classifier = `type-unify-or-top`) |
| `:constraints` | intersection |
| `:usage` | **`add-usage`** |
| `:warnings` | **append** |
| other facets | `new-v`, i.e. LWW (`:399-419`) |

Every `:type` write through `type-map-write` may also write a fork-on-union request into
cell-15 (`:622-634`); see §5.2.

| file:line | API | fire fn | class | evidence | multiplicity |
|---|---|---|---|---|---|
| 1220 | nap | `make-branch-check-fire-fn` `:1105-1130`, wrapped at the branch bit | MA | Waits on `(eq? inhabitant 'bot)`. Writes the contradiction sentinel iff `(subtype? inhabitant-type component)` fails. Upward-closed if the inhabitant only refines. Installed by the value-tier handler `process-fork-on-union` (`:1159`, registered `:1515`) | per union component per fork-on-union event |
| 1271 | fo | `make-branch-contradiction-watcher-fire-fn` `:1423-1461` | TL-S | Trigger `(classify-inhabit-contradiction? cinhab-val)`; the contradiction is top, so the trigger is upward-closed. The output is constant: `(seteq aid)` to cell-16 (set-union) and to cell-18 (per-position set-union, `propagator.rkt:861`) | per branch per fork |
| 1299 | nap | `make-fork-chain-threshold-fire-fn` `:1379-1421` | AR (own-output guard) | The threshold `subset? branch-aid-ns position-aid-ns` is upward-closed. But `[(hash-has-key? cell-19-val position) net]` (`:1399`) emits only if the output is absent. The written value `(derivation-chain-for/union-contradict net …)` (`:1419`) is computed from the **whole network at fire time**. Cell-19's merge is per-key new-wins (`propagator.rkt:879-885`). Fixpoint of non-diagnostic cells unaffected; diagnostic payload schedule-dependent | per fork |
| 1759, 2539 | fo | `make-usage-zero-fire-fn` `:1668-1673` | TL-S | `(if (> depth 0) … net)`: context depth is fixed once the `:context` facet is written | per arity-0 rule node / per meta node |
| 1768 | fo | `make-usage-unary-fire-fn` `:1741-1746` | TL-U | `(if (null? u) net (that-write … u))` copies the child `:usage` at the first non-null value. A child `:usage` written more than once (by an app or arity≥3 parent, rows 2642/1789) can grow after the latch | per unary SRE-rule node |
| 1778 | fo | `make-usage-binary-fire-fn` `:1730-1737` | TL-U | Same as 1768, for two children | per binary SRE-rule node |
| 1789 | nap (lambda at site) | arity≥3 usage fold `:1790-1796` | NM (with A-2) | Not fire-once. It re-fires on any child `:usage` change and writes `(foldl add-usage …)`. The facet merge **adds** this to the earlier sum (`:416`; `mult-add` 1+1 = ω, `prelude.rkt:36-44`), so the final value depends on how many distinct input states are observed. Equal re-writes are skipped (`:466`) | per arity≥3 SRE-rule node |
| 2078 | nap (lambda) | computed return type `:2079-2088` | UNC | Waits until all child `:type`s are non-⊥, then writes `(ret-type child-types)` if non-`#f`. Decided by whether every registered `ret-type` procedure is monotone in the unification order: does it return a compatible type for a meta-containing child and for its refinement? | per SRE-rule node with a computed return |
| 2102 | nap (no inputs) | `make-literal-fire-fn` `:1805-1807` | MBC | constant write | per arity-0 rule node |
| 2117 | nap (lambda) | constant-return op `:2118-2125` | MA | Waits until no child is ⊥. A child `type-top` writes `type-top`. Otherwise it writes the constant `ret-type` | per op node with operands |
| 2546 | fo | `make-meta-solution-output-fire-fn` `:1558-1568` | TL-S (+A-2 sink) | Writes once `:term` is concrete, i.e. not `'bot`, not the contradiction sentinel, not `expr-meta`. The inhabitant merge is equal-or-contradiction (`classify-inhabit.rkt:175-180`), so the value is stable modulo contradiction. The output cell's merge `meta-solution-merge = append` (`:968-969`) makes **entry order** schedule-dependent | per meta node |
| 2564 | nap | `make-classify-inhabit-residuation-fire-fn` `:1023-1062` | MA | Waits until both layers are populated. Writes the contradiction sentinel iff `subtype?` fails. Upward-closed if the classifier only narrows and the inhabitant only refines. Declares cell-10 as an output but never writes it | per meta node |
| 2586 | fo | `make-constraint-creation-fire-fn` `:860-868` | AR (own-output guard; benign) | `(if (constraint-bot? current-constraints) (that-write … initial-domain) net)`. Benign because `constraint-merge` is intersection (`constraint-cell.rkt:116-141`) and the initial domain is the full candidate set, so the suppressed write would be absorbed. Also reads the impl registry (ambient, §6) | per trait-constrained meta |
| 2597 | nap | `make-type-narrows-constraints-fire-fn` `:878-905` | MA | Writes `refine-constraint-by-type-tag current tag` ⊆ current, under the intersection merge. The tag is fixed once the type is concrete. The `constraint-bot?` test waits; it does not act | per constraint type-arg |
| 2605 | fo | `make-trait-resolution-fire-fn` `:933-951` | **AR** (own-output guard) | `(if (eq? current-term 'bot) (that-write net tm-cid dict-meta-pos ':term dict-expr) net)`. If another writer puts a *different* `:term` first, this propagator skips and no contradiction arises. If it fires first, the inhabitant merge yields the contradiction sentinel. The outcome depends on order | per trait-constrained meta |
| 2613 | fo | `make-bvar-fire-fn/ctx-pos` `:2006-2015` | TL-S | Waits on `(context-cell-value? ctx-val)`. Contexts are written once by context-extension latches; the domain is a static expression | per bvar node |
| 2616 | fo | `make-usage-bvar-fire-fn` `:1677-1682` | TL-S | depth fixed once the context is written | per bvar node |
| 2636 | nap | `make-app-fire-fn` `:1840-1921` | MA | Waits on a ⊥ function type. The downward `type-map-write-unified` is a read-modify-write equal to a direct write, because the classifier merge is `type-unify-or-top`. Feedback waits on `(or (type-bot? arg-type) (expr-meta? arg-type))`. Caveat: Pi branch versus `type-tensor-core` branch (`:1845` vs `:1911`) | per application node |
| 2642 | nap | `make-usage-app-fire-fn` `:1686-1701` | **AR** (+A-2) | `(define effective-m (if (or (eq? m 'm0) (eq? m 'm1) (eq? m 'mw)) m 'mw))` (`:1699`): an unsolved mult-meta is read as ω. Not fire-once; it re-fires on func `:type` change (component path `:2647`). Any new sum is **added** by the `:usage` merge | per application node |
| 2654, 2674 | fo | `make-context-extension-fire-fn` `:1995-2003` | TL-S | Waits on `(context-cell-value? parent-ctx)`. Writes parent ⊕ static domain expression | per lam / Pi node |
| 2659 | nap | `make-lam-fire-fn` `:1924-1936` | MA | Waits until both are non-⊥. Writes `Pi(mult, dom-expr, body-type)`, monotone in body-type | per lam node |
| 2665 | fo | `make-usage-lam-fire-fn` `:1706-1715` | TL-U | `(cdr body-usage)` latched at the first non-null value; see 1768 | per lam node |
| 2680 | nap | `make-pi-fire-fn` `:1939-1950` | MA | Waits until both sides are `expr-Type`. Writes `Type(lmax …)` | per Pi node |
| 2686 | fo | `make-usage-pi-fire-fn` `:1718-1726` | TL-U | as 2665 | per Pi node |
| 2711 | nap | `make-union-fire-fn` `:1964-1975` | MA | as 2680 | per union-type node |
| 2739 | fo (lambda) | ann contradiction watcher `:2740-2744` | TL-S | `(if (type-top? term-type) (type-map-write … type-top) net)`: top trigger, constant output | per annotation node |
| 2781, 2854 | fo (lambda) | match-arm result copy `:2782-2785`, `:2855-2858` | TL-U | `(if (type-bot? body-type) net (type-map-write net tm-cid e body-type))` latches the **first** non-⊥ body type. The classifier can still be refined, e.g. by `try-unify-pure` on a meta-containing type (`type-lattice.rkt:212-218`); after self-clear the refinement is not copied | per match arm |
| 2809, 2838 | fo | per-binding context extension `:1995` / all-bindings lambda `:2839-2847` | TL-S | Parent context fixed; binding types are static (from the constructor's Pi chain). The 2809 contexts are superseded by 2838, which the comments at `:2824-2827` call "SIMPLIFIED" | per bound pattern var / per arm |
| 2882 | fo (lambda) | pair → Sigma `:2883-2888` | TL-U | latches `Sigma(fst-type, snd-type)` at the first both-non-⊥ state | per pair node |
| 2913 | fo | `make-coercion-detection-fire-fn` `:825-851` | TL-S (+A-2 sink) | Waits on ⊥. Type family is stable for a concrete numeric type. A non-numeric (`'other`) type writes nothing, so the propagator stays armed (M2). `:warnings` merge = append | per binary generic-op node |

### 4.3 `relations.rkt` (10)

The logic-variable carrier is the **scope cell**. Its merge is `scope-cell-merge`, which for
two non-⊥ values on the same key gives `[else v] ;; both non-bot: new wins`
(`decision-cell.rkt:887-904`). It becomes `make-tagged-merge scope-cell-merge` after promotion
(`:2958`). See §5.2.

| file:line | API | fire fn | class | evidence | multiplicity |
|---|---|---|---|---|---|
| 796 | fo | `discrim-fire` `:778-794` | TL-S | `(if (or (not pe) (eq? arg-val scope-cell-bot) (not arg-val)) net …)` waits. Then it writes the viable set; `viability-merge` is intersection (`:751-754`). Stable if the top-level constructor of a bound argument does not change (it cannot, under the scope merge; see §5.2) | per free arg position × variant × goal call |
| 2132 | nap | `unify-fire` `:2112-2120` | **AR** | `[(eq? v1 scope-cell-bot) (if (eq? v2 scope-cell-bot) net (logic-var-write net lhs v2))] [(eq? v2 scope-cell-bot) (logic-var-write net rhs v1)] [(equal? v1 v2) net] [else net]`. It copies only into an *absent* side. With both sides bound and unequal it does nothing, so whether the binding propagates depends on which side was written first; under the scope merge's "new wins", the final binding depends on order too | per var=var unify goal |
| 2148, 2161, 2183 | fo (no inputs) | constant `logic-var-write` closures | MBC | Constant write; `:2183` evaluates `val` at install time (`:2175`). The bitmask is captured at install (`maybe-wrap-worldview`, `:2082-2088`) | per var=ground / `is` goal under a non-zero worldview |
| 2353 | fo | `guard-fire` `:2331-2349` | **NM** | (a) Unbound vars are substituted as expressions: `(if (eq? v scope-cell-bot) expr v)` (`:2312, 2318`); an unevaluable result counts as truthy (`[else #t]`, `:2341`). (b) On false it **retracts**: `(bitwise-and current-wv (bitwise-not invalid-mask))` read-modify-written to cell-1, whose merge is LWW. (c) Declared outputs are `'()`, so under BSP the cell-1 write is an *undeclared* direct set (M3) and the fire-once never self-clears (M2). Two guards failing in one round lose one update even under BSP | per guard goal |
| 2636, 2699 | fo (no inputs) | fact-row constant `logic-var-write` | MBC | constant write under a captured bitmask (and `#:assumption` at 2699) | per arg × viable fact row |
| 2824 | nap, outputs `'()` | `consumer-fire` `:2794-2822` | UNC | Monotone in the table, whose merge `table-answer-merge` is dedup-append (`atms.rkt:100`). But all writes are undeclared, so BSP applies them by direct set (M3), and several answers write the same variable in one fire, where the scope merge is "new wins". Decided by whether two answers matching the same ground args can differ on a free arg within one worldview | per tabled-goal consumer |
| 2859 | nap | `producer-fire` `:2838-2855` | **AR** | `(define has-binding? (for/or … (not (eq? v scope-cell-bot)) …))`, then `(net-cell-write net table-cid (list bindings))`. It writes a **partial tuple containing `scope-cell-bot` entries** whenever any argument is bound. The set of partial tuples recorded depends on which intermediate states are observed | per tabled-goal producer |

### 4.4 `propagator.rkt` (8)

| file:line | API | fire fn | class | evidence | multiplicity |
|---|---|---|---|---|---|
| 983 | nap | `install-worldview-projection` `:974-983` | UNC | The fire function is monotone: the bitmask is the OR of committed bits (`decision-cell.rkt:697-703`). It writes cell-1, which has an LWW merge and is also narrowed by `guard-fire` in S0 (`relations.rkt:2349`) and by value-tier handlers (`typing-propagators.rkt:1506`). It **changes the worldview inside S0**. Decided by whether the decisions cell changes within an S0 run, and whether any other S0 writer of cell-1 runs in the same run | once per solver context (`atms.rkt:237`; contexts are made at `atms.rkt:524`, `relations.rkt:3123`) |
| 2359 | nap | fire-once wrapper | WRAP | sets `PROP-FIRE-ONCE` | — |
| 2516 | nap | `net-add-parallel-map-propagator` | WRAP | 0 production callers | — |
| 2563, 2587 | nap | `make-threshold-fire-fn` / `make-barrier-fire-fn` `:2532-2551` | WRAP | monotone iff the predicates are upward-closed; 0 production callers | — |
| 3376 | nap | deferred re-install in `run-to-quiescence-bsp` | WRAP | drops flags, assumption, component paths and srcloc (M4) | per propagator created inside a fire |
| 4464, 4484 | nap | cross-domain α / γ lambdas `:4466-4478`, `:4486-4495` | WRAP (generic) | `[(not c-val) net]` waits on `#f`; monotone iff α (resp. γ) is monotone. The 5 callers are classified in §4.6 | 1–2 per bridge |

### 4.5 Session, SRE, unify, logic programming, misc.

| file:line | API | fire fn | class | evidence | multiplicity |
|---|---|---|---|---|---|
| `session-propagators.rkt:127, 145, 162, 178, 197, 230` | nap | send / recv / async-send / async-recv / select / offer decomposers `:113-227` | MA | ⊥ and `sess-meta?` defer. A shape match writes the continuation; a shape mismatch writes `sess-top`. The shape is fixed once concrete, so the mismatch test is upward-closed | per process operation |
| `session-propagators.rkt:249` | nap | `add-stop-prop` `:235-247` | MA | `[(sess-bot? sess-val) (net-cell-write n sess-cell (sess-end))]` looks like acting on ⊥. But every non-top branch writes the same constant `sess-end`, so the case split is a constant write; it is not absence-dependent | per stop |
| `session-propagators.rkt:310` | nap | SRE duality (`sre-core.rkt:2635-2669`) | MA +TOPO | see `sre-core` rows | per dual pair |
| `session-runtime.rkt:297, 305, 435, 442` | nap | msg / choice cross-wire copies | MBC | `(if (msg-bot? v) n (net-cell-write …))`: a copy (the ⊥ test only skips a no-op) | 2 + 2 per channel pair |
| `session-runtime.rkt:380` | nap | `rt-add-session-advance` `:382-392` | MA | shape test upward-closed (`sess-mu` unfolded) | per advance step |
| `session-runtime.rkt:491` | nap | `rt-add-propagator` | WRAP | | — |
| `session-runtime.rkt:517` | rap | `make-io-bridge-propagator` (`io-bridge.rkt:180-233`) | **NM** | External side effects in the fire: `write-string`, `read-string`, `close-input-port`. A re-fire repeats the write, and a second read reads different data. No production caller (`maybe-install-io-bridge` has 0 callers) | per IO channel |
| `session-runtime.rkt:657` | rap | stop guard `:658-664` | MA | `[(sess-bot? sess) n] [(sess-end? sess) n] [else (net-cell-write n sess-cell sess-top)]`: the violation test is upward-closed | per channel at stop |
| `session-runtime.rkt:809, 871` | rap | select advance / offer distribute | MA | as 380 / as `session-propagators.rkt:230` | per select / offer |
| `session-runtime.rkt:954, 962` | rap | link msg forward | MBC | copy | 2 per link |
| `sre-core.rkt:2426, 2765` | nap | `sre-make-structural-relate-propagator` → equality `:2530-2559` / subtype `:2572-2622` / duality `:2635-2669` | MA +TOPO | **Equality**: as structural-unify. **Subtype**: writes only a contradiction or the equality-merge, and waits on ⊥. **Duality**: involution on tags; wrong pairing writes top. `(net-pair-decomp? net pair-key)` reads the topology registry, which is not mutated in-fire (`propagator.rkt:2921-2940`) | per decomposed component pair |
| `sre-core.rkt:2434, 2437, 2772, 2775` | nap | `sre-make-generic-reconstructor` `:2359-2373` | MA | as the elaborator reconstructors | 2 per decomposed pair |
| `unify.rkt:319, 335, 372, 387, 426` | nap | SRE equality relate | MA +TOPO | as above. Installed by the imperative unifier, which then runs a **nested** `run-to-quiescence` (`:340, 392, 432`). Reachable from inside an S0 fire via the retry bridge (§4.6, `metavar-store.rkt:1063`) | per Pi / binder / sub-goal unify call |
| `wf-propagators.rkt:69, 77, 97, 123, 162` | nap | bilattice negation / positive clause / aggregate upper / clause lower | MA | Monotone in the precision order: lower cells use join, upper cells use meet (`bilattice.rkt:96-105`). `(if any-feasible? n (net-cell-write n upper-p-cid #f))` writes into a descending cell as upper bounds descend. **No production caller** | per atom / clause |
| `bilattice.rkt:167` | nap, outputs `'()` | consistency check | MA | `(if (leq lo hi) n …contradiction)`: the violation is upward-closed as lo rises and hi falls. Writes the network `contradiction` field by `struct-copy` (undeclared) | per checked bilattice var (`wf-engine.rkt`) |
| `constraint-propagators.rkt:239, 303` | nap | P1 / P4 type→constraint | MA | intersection refine by tag; 0 production callers | — |
| `constraint-propagators.rkt:256` | nap | P2 constraint→type | MA | threshold `constraint-one?` upward-closed; 0 callers | — |
| `constraint-propagators.rkt:280` | nap, outputs `'()` | P3 constraint→method | TOPO | Writes the callback request to cell-6 (set-union). 0 callers (`:277-278`) | — |
| `narrowing.rkt:219` | nap | `make-branch-fire-fn` `:278-317` | MA +TOPO | A constructor emits a branch request once (guarded by the pair-decomp registry). An absent constructor in the tree writes `term-top`; the tag is fixed once known. `term-var` and ⊥ residuate | per definitional-tree branch node |
| `narrowing.rkt:238` | nap | `make-rule-fire-fn` `:335-360` | UNC +TOPO | Waits until no binding is ⊥, then emits a rule request **once**. The handler evaluates the RHS **once**, with the binding values current at handler time (`:107-114`). Decided by whether a binding cell can move between non-⊥ values (e.g. `term-var` → constructor) after emission | per rule leaf |
| `reduction.rkt:4444` | nap | `racket-fire` wrapping a **user** Prologos function `:4436-4440` | UNC | Monotonicity is the user program's obligation. `whnf` inside the fire reads ambient global and meta state | per user `net-add-prop` evaluation |
| `capability-inference.rkt:288`, `cap-type-bridge.rkt:236` | nap | call-edge copy of the callee cap-set into the caller | MBC | copy into `cap-set-join` | per call edge (separate network, run by `run-to-quiescence-bsp`) |
| `effect-bridge.rkt:69` | nap | session → effect-position `:53-68` | MA | Waits on ⊥, top → top, otherwise depth = `session-steps-to`. `eff-pos-merge` takes the max depth per channel (`effect-position.rkt:185-196`) | per IO channel (`session-runtime.rkt:1004`) |
| `effect-ordering.rkt:223` | nap | `add-ordering-propagator` `:208-226` | MA | Waits on ⊥. Transitive closure is monotone; the cycle test is upward-closed. 0 production callers | — |

### 4.6 Cross-domain callers and wrapper callers

| file:line | API | fire fn | class | evidence | multiplicity |
|---|---|---|---|---|---|
| `session-type-bridge.rkt:123, 133` | xd | `send-type-alpha` / `recv-type-alpha` `:73-91`; γ = constant `sess-bot` `:102` | MA | Extracts the message type of a concrete shape; `[else type-bot]` for other shapes. The session shape cannot change once concrete. γ is a no-op | per channel |
| `driver.rkt:3844, 3855` (HEAD) | xd (α only) | `type->mult-alpha` (`elaborator-network.rkt:1093-1102`) | MA | `[(mult-meta? m) mult-bot]` waits rather than acting | per mult-meta-carrying Pi decomposition |
| `cap-type-bridge.rkt:218` | xd | α `type-to-cap-set` `:65-…`; γ `cap-set-to-type` `:123-…` | UNC | γ writes a union type built from a *growing* cap set into a type cell whose merge is `type-unify-or-top` (`:197`), an equality order. Successive γ outputs are not ordered in that lattice. Decided by whether `build-cross-domain-network` (`driver.rkt` HEAD `:1116`) ever reaches `type-top` on real input | per global function |
| `driver.rkt:3724` (HEAD) | nap | `current-prop-add-propagator` callback | WRAP | the parameter is a stub with 0 invocations | — |
| `driver.rkt:1704` (HEAD) | mfo | forward-reference δ `:1687-1696` | TL-S | `(if (def-entry? referent-entry) … net)`: upward-closed trigger. The referent is written once by its sole writer (comment `namespace.rkt:305-308`) | per forward reference |
| `metavar-store.rkt:487` | ebc | readiness item-fn `:492-512` | TL-S | Contributes `(seteq mid)` when the meta is non-⊥ and non-top; set-union latch. Edge case: a meta that reaches top before the first fire is never latched, so readiness differs between schedules only on contradiction. Reads `current-worldview-bitmask` unwrapped (§6) | per universe group of a constraint's metas |
| `metavar-store.rkt:542` | efo | per-cell readiness `:546-553` | TL-S | as 487 | per legacy per-cell meta |
| `metavar-store.rkt:562` | efo | latch → ready queue `:566-572` | TL-S (+**A-2 sink**) | Trigger: latch non-empty, upward-closed. Writes `(list (tagged-entry (action-thunk) aid))` into **cell-14**, whose merge is `resolution-stratum-merge = append` (`propagator.rkt:802-808`; the comment there says "order may carry intent") | per constraint / trait / hasmethod readiness |
| `metavar-store.rkt:692` | eap | pure trait bridge (`resolution.rkt:478-538`) | **AR** (own-output guard) | `[(resolved-cell-value? dict-val) pnet]` (`:484`), where `resolved-cell-value?` means "not ⊥/top" (`:420-423`). That admits meta-containing types, so `[(not (andmap resolved-cell-value? type-arg-vals)) pnet]` can pass on a partial type. The parametric choice "most specific (fewest pattern vars)" (`:526-529`) can then latch on partial information, and the own-output guard prevents a later re-choice | per trait constraint with type-arg metas |
| `metavar-store.rkt:850` | eap | pure hasmethod bridge (`resolution.rkt:565-656`) | **AR** (own-output guards) | as 692. Also `(not (resolved-cell-value? (meta-component-read … trait-var…)))` and `… dict-meta…` guard the secondary outputs (`:641-653`) | per hasmethod constraint |
| `metavar-store.rkt:1063` | eap | constraint-retry bridge (`resolution.rkt:371-387`) | **NM** | (a) Reads the ambient `(current-prop-net-box)` and **`set-box!`s** it (`:373, 386`). (b) Branches on `(eq? (constraint-status current-c) 'postponed)` (`:383`). The status cycles postponed → retrying → postponed in the L2 handler (`resolution.rkt:293-301`), so it is not monotone. (c) Runs `unify-core` (`:196`), which may install propagators and run a nested quiescence (§4.5 `unify.rkt`). (d) Writes the constraint store (merge `merge-hasheq-replace`), which is **not a declared output**; under BSP that write is a direct set (M3) | per postponed constraint |

---

## 5. Merge functions (A-2)

### 5.1 The three named non-join merges

Definitions (MEASUREMENT):

| merge | definition | why it is not a join |
|---|---|---|
| `merge-hasheq-replace` | `infra-cell.rkt:141-149`: per-key last writer wins | non-commutative |
| `merge-list-append` | `:166-171` | non-idempotent and order-dependent |
| `merge-replace` | `:199-202` | replace |
| `merge-last-write-wins` | `:207` | alias of `merge-replace` |

`merge-last-write-wins` must be counted with `merge-replace`. The SRE registrations at
`infra-cell-sre-registrations.rkt:78-112` declare the domains; they create no cells.

| merge | allocation site | cell | written where (file:line) | when written | S0 fire writes it? |
|---|---|---|---|---|---|
| hasheq-replace | `macros.rkt:596-648` (23 sites) | persistent-registry cells: schema, ctor, type-meta, subtype, coercion, capability, property, functor, trait, trait-laws, impl, param-impl, bundle, specialization, selection, session, preparse, spec-store, strategy, process, precedence-groups, operators, macro | `macros-cell-write!` `macros.rkt:582-585`, called from the 23 `register-*!` functions (`macros.rkt:465 … 10806`) and from `driver.rkt` HEAD `:2953` (restore), `:3399, 3404` (module loader) | declaration processing and module load, on the **persistent registry network**, which is a separate network held in a box | **No** (none found). They are *read* in S0 by the pure bridges (`resolution.rkt:408-413`) |
| hasheq-replace | `metavar-store.rkt:2879` | constraint store `cstore` | `add-constraint!` `:1021`; `write-constraint-to-store-pure` `:1205-1210`, called from `resolution.rkt:199, 203` (retry) and `:295, 300` (L2 executor) | elaboration time; **S0 fire** (retry bridge `metavar-store.rkt:1063` → `resolution.rkt:385` → `:192-206`); L2 handler (`process-resolution`, `metavar-store.rkt:1683`) | **YES**: an S0 fire, as an *undeclared* write |
| hasheq-replace | `metavar-store.rkt:2882, 2884, 2886, 2888, 2902` | trait-constraints, trait-cell-map, hasmethod-constraints, capability-constraints, hasmethod-cell-map | `register-trait-constraint!` `:607, 640`; `register-hasmethod-constraint!` `:752, 787`; `register-capability-constraint!` `:883` | elaboration time | no path found from an S0 fire (call-graph depth ≤ 2) |
| hasheq-replace | `metavar-store.rkt:2908` | unsolved-metas | `fresh-meta` `:1907, 1934`; `solve-meta-core!` `:2106`; `solve-meta-core-pure` `:2159, 2171` | elaboration; L2 handler (`resolution.rkt:220, 270, 278, 284`); **reachable from S0** through the retry bridge's `unify-core`, if unification solves a meta | **UNCLEAR, probably yes**: decided by whether `unify-core` inside the retry bridge reaches `solve-meta!` |
| hasheq-replace | `namespace.rkt:1099` | module registry | `register-module!` `namespace.rkt:459`; init `:1099` | module load; per-command init | no |
| list-append | `warnings.rkt:86, 88, 90` | coercion / deprecation / capability warnings (persistent net) | `warnings-cell-write!` `warnings.rkt:73-78`, called from `emit-*-warning!` `:158, 183, 211, 232`. Callers: `typing-core.rkt:404, 2754-2765` (imperative infer), `elaborator.rkt:1233, 4471`, `driver.rkt:543, 548`, `typing-propagators.rkt:3234` (post-quiescence harvest). Reset by `net-cell-reset` `:104-111` | elaboration / post-quiescence | no path found from an S0 fire (depth ≤ 2) |
| list-append | `global-constraints.rkt:102` | narrow-constraints (persistent net) | only the init write; `narrow-cell-write!` (`:91-94`) has 0 callers | construction | no |
| list-append | `relations.rkt:3131` | query answer accumulator | `dissolve-solver-pu` `relations.rkt:3008`, after `run-to-quiescence` (`:3158`) | post-quiescence | no |
| list-append | `infra-cell.rkt:296` (`net-new-list-cell`) | — | 0 callers | — | — |
| replace | `namespace.rkt:1103` | ns-context snapshot | creation only (`:1102-1104`) | per-command init | no |
| replace (alias `merge-last-write-wins`) | `global-constraints.rkt:105` | narrow-var-constraints (persistent net) | init only; 0 writers | construction | no |
| replace | `infra-cell.rkt:308` (`net-new-replace-cell`) | — | 0 callers | — | — |

**Allocation-site counts.** `merge-hasheq-replace` has 31: 23 `net-new-cell` sites in
`macros.rkt` plus 8 `new-cell-fn` sites (7 in `metavar-store.rkt`, 1 in `namespace.rkt`). The
brief's "23" counted `net-new-cell` only. `merge-list-append` has 6, of which 5 are live.
`merge-replace` has 3 including the alias, of which 2 are live.

**Verdict on the three (JUDGEMENT):**

- **`merge-hasheq-replace` is written by an S0 fire.** The writer is the constraint store; the
  firing site is the retry bridge at `metavar-store.rkt:1063`. The write is undeclared, so under
  BSP it is a whole-cell direct set. Two retry bridges firing in one BSP round can therefore lose
  one constraint's status update even today. The unsolved-metas cell is probably also
  S0-reachable.
- **`merge-list-append` and `merge-replace`:** no S0 writer was found. The fix scope for
  these two is "keep them out of S0", which already holds.

### 5.2 Non-join merges on S0-written cells that the brief did not list (found in passing)

| merge (definition) | cell(s) | S0 writer(s) | property violated |
|---|---|---|---|
| `scope-cell-merge` `decision-cell.rkt:887-904` (`[else v] ;; both non-bot: new wins`) | every relational scope cell (`relations.rkt:2014`); also its tagged form `make-tagged-merge scope-cell-merge` (`:2958`) | every relational propagator writing a logic var: `relations.rkt:796` (via viability), 2132, 2148, 2161, 2183, 2636, 2699, 2824 | commutativity, per key |
| `logic-var-merge` `relations.rkt:1990-1993` ("last binding wins") | legacy logic-var cells (`alloc-logic-var`, used for NAF inner results) | NAF fork contents (S1); not counted as S0 | commutativity |
| `make-tagged-merge` `decision-cell.rkt:480-493` | every promoted (tagged) cell | all worldview-wrapped fires | Entries are appended, not deduplicated, so the merge is not idempotent. `tagged-cell-read` folds `domain-merge` over matching entries in arrival order (`decision-cell.rkt:420-434`), so with a non-commutative domain merge (the scope merge) the **read** depends on arrival order |
| attribute-map facets, `typing-propagators.rkt:416, 418, 419` | `tm-cid` (all typing) | 1789, 2642 (`:usage`); 2913 (`:warnings`) | `:usage` = `add-usage` is not idempotent (1+1 = ω); `:warnings` = append; other facets are LWW |
| `worldview-cache-merge` `propagator.rkt:960-961` | cell-1 | `propagator.rkt:983` (projection); `relations.rkt:2353` (guard, undeclared) | LWW, and narrowed by AND-NOT. The D.1 §6.1 storage table lists worldview bitmasks as `'flat-bitmask` with `fxior`. **Cell-1 is not that lattice** |
| `resolution-stratum-merge` `propagator.rkt:802-808` | cell-14 | `metavar-store.rkt:562` | append: non-commutative, non-idempotent |
| `fork-on-union-request-merge` `propagator.rkt:815-828` | cell-15 | every `type-map-write` inside typing fires (`typing-propagators.rkt:622-634`) | per-key LWW. The same position can be emitted with different `components` if its union is refined within one S0 run. The guard reads cell-17, which only handlers write, so it is constant during S0 |
| `union-derivation-chains-merge` `propagator.rkt:879-885` | cell-19 | `typing-propagators.rkt:1299` | per-key LWW (guarded by emit-once; §4.2) |
| `meta-solution-merge` `typing-propagators.rkt:968-969` | meta-solution output cell | `typing-propagators.rkt:2546` | append (entry order) |
| `type-unify-or-top` `type-lattice.rkt:203-219` | type cells: elaborator, meta universes, bridges | most typing / unify fires | (i) `has-unsolved-meta?` calls the ambient `(current-lattice-meta-solution-fn)` (`type-lattice.rkt:85-92`), so the merge is not a fixed function of its two arguments. (ii) The fallback `(if (has-unsolved-meta? v1) v2 v1)` returns `v2` when both sides contain unsolved metas: non-commutative |
| `config-merge` `propagator.rkt:644` (first-write-wins); `naf-pending-merge` `:652-658` (per-key LWW); `merge-hasheq-list-append` `infra-cell.rkt:154-162` (wakeup registries `metavar-store.rkt:2891-2896`) | cells 3, 4; wakeup registries | Written at query start (`relations.rkt:3120-3121`), at install time (`relations.rkt:2234`), and at elaboration time (`metavar-store.rkt:620, 769, 1031`). No S0 fire writer was found | not S0-exposed (JUDGEMENT) |

**JUDGEMENT on D.1.** D.1 §5.3 says "duplicates harmless *because merges are idempotent*
(A-2)". That is false for `make-tagged-merge` (duplicate entries), `add-usage`, cell-14 and the
`:warnings` facet. It is true for exact duplicates under the LWW merges, but those are
order-dependent instead.

---

## 6. Ambient state read by S0 fires (item 4)

| ambient state | read in S0 at | value can differ between executors? |
|---|---|---|
| `current-worldview-bitmask` (parameter) | `net-cell-read` / `net-cell-write` of every tagged cell (`propagator.rkt:1596`); `metavar-store.rkt:504` (unwrapped broadcast item-fn) | **Yes if not re-parameterized per fire.** `wrap-with-worldview` (`propagator.rkt:2164-2168`) and `maybe-wrap-worldview` (`relations.rkt:2082-2088`) parameterize per fire, which is fine. Unwrapped fires see the thread's ambient value; a scheduler-owned executor thread would see the value from its *creation*. Racket parameters are inherited by a thread from its creator's parameterization (Racket Reference, "Parameters") |
| worldview cache cell-1 (a cell, but S0-written: M6) | every unwrapped tagged read | yes: written mid-run by 983 / 2353 (§4.4, §4.3) |
| `current-bsp-fire-round?` | 11 sites (M5) | must be `#t` on every DIRECT executor, or fires mutate topology inline |
| `current-cell-id-namespace` | `net-new-cell` inside fires | set per fire in BSP (`propagator.rkt:2864`); DIRECT needs a per-executor namespace (D.1 §5.2) |
| `current-source-loc` | everywhere | set per fire from the struct (`propagator.rkt:373-375`): safe |
| `current-prop-net-box` (a **mutable box**) | retry bridge `resolution.rkt:373, 386` (read and `set-box!`); `with-enet-reads` `:187-189` | **Yes, and racy**: a shared box mutated inside a fire |
| `current-persistent-registry-net-box` | pure bridges `resolution.rkt:409`; constraint creation via `build-trait-constraint` (`typing-propagators.rkt:866`) | Registries are written only at declaration time (§5.1), so they are stable during S0 if the box is the same one on every executor |
| `current-lattice-meta-solution-fn` | inside the **merge** `type-unify-or-top` (`type-lattice.rkt:86`) | the callback reads the meta store, which S0 fires write (meta-universe cells) |
| `current-speculation-assumption` | `write-constraint-to-store-pure` `metavar-store.rkt:1207` (inside the retry fire) | derived from `current-worldview-bitmask`; same caveat |
| global environment / meta store via evaluation | `reduction.rkt:4436-4440` (`whnf`); `relations.rkt:2334` (`eval-fn` captured at install, `:2254`) | depends on the evaluator's own parameter reads (not traced) |
| `current-sre-debug?` | `sre-core.rkt:2549` | debug only |

Ambient reads at **install** time are outside S0 fires and are not listed:
`current-structural-mult-bridge` (`elaborator-network.rkt:485`, read in a fire only on the DFS
path), `current-meta-solution-output-cell-id`, `current-is-eval-fn`, and `current-*-bridge-fn`.

---

## 7. Scheduler behaviours that code silently relies on (BSP vs DIRECT)

These are MEASUREMENT facts about the scheduler, with the sites that depend on them (JUDGEMENT):

1. **Undeclared outputs are direct-set (M3).** Sites with `'()` or incomplete outputs:
   - `relations.rkt:2353` (cell-1)
   - `relations.rkt:2824` (scope cells)
   - `metavar-store.rkt:1063` (cstore)
   - `bilattice.rkt:167` (contradiction field)
   - `constraint-propagators.rkt:280` (dead)

   The commit history documents one such bug already: `typing-propagators.rkt:1241-1266`
   describes cell-18 being "de facto last-write-wins" until it was declared as an output. A
   DIRECT executor that writes through the merge changes these semantics. A DIRECT executor
   that keeps the direct set races.
2. **Fire-once timing (M2).** The 7 TL-U sites produce different values depending on the first
   productive fire. They are deterministic under BSP only because the round structure fixes
   that moment.
3. **Re-install drops fire-once and assumption (M4).** A fire-once or assumption-tagged
   propagator created *inside* a fire becomes plain and untagged after the topology step. This
   would matter for DFS-path decompositions that occur inside fires.
4. **Nested quiescence inside a fire.** The retry bridge (`metavar-store.rkt:1063`) calls
   `unify-core`, which installs SRE propagators (`unify.rkt:319-432`) and runs
   `run-to-quiescence` on them (`:340, 392, 432`). Their parent is the bridge's own fire.
5. **Worldview changes inside S0.** The brief allows reading under a fixed worldview, not
   changing it. Two sites change it:
   - `propagator.rkt:983`, which grows cell-1;
   - `relations.rkt:2353`, which clears bits.

   Value-tier handlers also narrow cell-1, outside S0, which is allowed. D.1 §5.2 conjectures
   that hub cells (incl. `worldview-cache-cell-id`) are "only read at the boundary" (A-8). For
   cell-1 this is **refuted by the code**: it is read by every unwrapped tagged read inside
   S0 and written inside S0.

---

## 8. Sites a schedule-variation test should target

Ordered by expected likelihood of a fixpoint difference (JUDGEMENT). "Vary" names the
interleaving to randomise; "compare" names the observable.

| # | site | class | vary | compare |
|---|---|---|---|---|
| 1 | `metavar-store.rkt:1063` → `resolution.rkt:371-387` | NM | two postponed constraints sharing metas, retried in the same round or under DIRECT | constraint statuses in the cstore; final meta solutions; `current-prop-net-box` content after the solve |
| 2 | `relations.rkt:2353` (guard) + `propagator.rkt:983` (projection) | NM / UNC | two failing guards in one round; a guard failing while a decision commits | final cell-1; answer set (lost-update test: both guards' bits must be cleared) |
| 3 | `relations.rkt:2132` (`unify-fire`) | AR | X = Y with X and Y bound to different values by different propagators, varying which binds first | contradiction vs. silent success; final bindings (with `scope-cell-merge` "new wins") |
| 4 | `relations.rkt:2859` / `2824` (tabling) | AR / UNC | multi-variable tabled goals whose arguments bind in different rounds | table contents (count of partial tuples containing `scope-cell-bot`); answer set |
| 5 | `typing-propagators.rkt:2642`, `1789` (`:usage`) | AR / NM | an app whose function type's mult is a meta solved mid-run; arity≥3 ops whose children's usage arrives in pieces | the `:usage` facet; multiplicity-violation warnings |
| 6 | `typing-propagators.rkt:2781, 2854, 2882` | TL-U | a match arm / pair whose body type contains a meta that is unified later | result-position `:type` |
| 7 | `typing-propagators.rkt:1768, 1778, 2665, 2686` | TL-U | a child usage written twice (app child) | parent `:usage` |
| 8 | `metavar-store.rkt:692, 850` (pure bridges) | AR | type arg `List ?A` with both a `List A` and a `List Nat` parametric impl; `?A := Nat` before vs after the bridge fires | chosen dictionary |
| 9 | `typing-propagators.rkt:2605` (trait resolution, own-output guard) | AR | a conflicting `:term` written before vs after resolution | presence of the contradiction sentinel |
| 10 | `metavar-store.rkt:562` (cell-14 append) | TL-S + A-2 | several readiness latches firing in one run | order of actions seen by `process-resolution`; resulting elaboration |
| 11 | `typing-propagators.rkt:622-634` (cell-15 per-key LWW) | A-2 | a union-typed position refined within one S0 run | `components` seen by `process-fork-on-union` |
| 12 | `typing-propagators.rkt:1299` (cell-19 chains) | AR | branches contradicting in different orders | derivation-chain payloads (diagnostic) |
| 13 | `narrowing.rkt:238` | UNC | a binding moving `term-var` → constructor after the rule request | result cell |
| 14 | `typing-propagators.rkt:2078` | UNC | computed-return-type rules over meta-containing children | result `:type` (contradiction?) |
| 15 | `cap-type-bridge.rkt:218` | UNC | growing cap sets (call-graph order) | `type-top` in type closures |
| — | `session-runtime.rkt:517`, `reduction.rkt:4444` | NM / UNC | not schedule-testable as written: the first is dead and side-effecting, the second runs user code | — |

---

## 9. Mapping onto D.1 / Stage 2 (JUDGEMENT; proposals, unapplied)

- **Q1 / A-1, A-3 are not clean.** Eight AR and four NM sites exist, plus seven TL-U latches
  whose correctness under DIRECT depends on fire timing. Per the Stage 2 tradeoff table ("B if
  the Q1 audit is clean; else A"), DIRECT writes for *all* of S0 are not yet licensed by this
  reading. A narrower option is open to the owner: DIRECT only for propagators whose
  `propagator-outputs` cells have a join merge, with the remainder confined to a BSP sub-run.
- **A-2.** Of the brief's three merges, only the hasheq-replace constraint store is S0-written.
  §5.2 is the A-2 list that matters for D.1: scope cells, the tagged merge, cell-1, cell-14,
  cell-15, `:usage` / `:warnings`, and `type-unify-or-top`.
- **Corrections D.1 would need** (not made: owner-owned):
  - `D1_DESIGN.md:535`: "103 sites" → 157.
  - §5.3: "duplicates harmless because merges are idempotent" holds only for the join merges.
  - §6.1: the worldview bitmask is not `fxior` (cell-1 is LWW + AND-NOT).
  - §5.2 / A-8: cell-1 is read and written inside S0.
- **Follow-up candidates** (not filed in `DEFERRED.md`; this task is read-only):
  - declare the undeclared outputs of the five M3 sites;
  - carry flags, assumption and component paths through `collect-deferred-propagators`;
  - make `scope-cell-merge` detect conflict instead of "new wins";
  - replace the `:usage` facet merge with the pointwise-join combinator that `qtt.rkt:68`
    already describes ("Pointwise JOIN of usage contexts").

---

## 10. Method limits

- **Static reading only.** No fire was executed. Classifications marked MA rest on the one-line
  argument given in the row. Where the argument depends on a lattice's order (the
  `type-unify-or-top` classifier, session shapes, term lattices), I read the merge and the
  predicates, not every client.
- **Reachability is a grep for `(name`** at HEAD with tests excluded. It misses higher-order
  use: handlers registered by value, callbacks installed into parameters. Two such cases were
  traced by hand (`elab-add-unify-constraint`, the bridge factories). "0 production callers"
  can therefore be wrong for functions passed as values.
- **"Who writes this cell" was traced to call-graph depth ≤ 2–3** from the writing helper. Deeper
  transitive reachability from fire functions into imperative code (`unify-core`, `whnf`,
  `eval-fn`, `infer`) is **not closed**. Hence unsolved-metas is marked UNCLEAR, and the
  warnings cells' "no S0 writer" is a depth-bounded result.
- **Multiplicity is a static class, not a count.** A static site cannot size a runtime
  population; P0-1 (dynamic cell census) is the measurement for that.
- **TL-S vs TL-U** depends on whether an input can change after the first productive fire. Some
  TL-S rows (contexts, def-entries, discrimination) rest on "written once" claims taken from
  the writers' code and comments, not from a proof.
- **Not attempted:**
  - the 186 `current-worldview-bitmask` / `worldview-cache` sites named in Stage 2 Q1 were not
    audited line by line; only those inside the classified fire functions and `net-cell-read`
    were;
  - stratum handlers themselves were not audited (they are non-monotone by declaration and
    run sequentially);
  - `lsp/` and `redex/` have no install sites.
- **Commit drift.** HEAD moved from `7a0116ec` to `f3d7f5e3` while this was being written; the
  move changed `driver.rkt` and `lsp/server.rkt` only. Citations are pinned to `7a0116ec`. At
  `f3d7f5e3`, the `driver.rkt` line numbers shift: for example `[fire-fn` 1687 → 1701,
  `module-network-install-fire-once` 1704 → 1718, `install-prop-network-callbacks!` 3708 → 3731,
  `current-prop-add-propagator` 3721 → 3744. All other files are unchanged. The scripts used
  for the first census pass read `git show HEAD:`; the driver numbers were re-read at
  `7a0116ec` afterwards.

---

## 11. Re-run (from the repository root)

These scripts are the ones used for this draft. They live in the profile's **scratch directory,
which is pruned** after 24 h, so the commands are reproduced here.

```
git rev-parse --short HEAD                                    # 7a0116ec
# install sites (3+2+2 APIs), production only, end-of-line aware:
find racket/prologos -name '*.rkt' -not -path '*/tests/*' -not -path '*/benchmarks/*' \
  -not -path '*/tools/*' -not -path '*/compiled/*' -print0 \
 | xargs -0 grep -n -E '\((net-add-propagator|net-add-fire-once-propagator|net-add-broadcast-propagator|net-add-parallel-map-propagator|net-add-cross-domain-propagator|net-add-threshold|net-add-barrier)([[:space:])]|$)' \
 | grep -v -E ':[0-9]+:\s*;' | grep -v '(define (net-add-'
# wrapper callers:
… | xargs -0 grep -n -E '\((elab-add-propagator|elab-add-fire-once-propagator|elab-add-broadcast-propagator|rt-add-propagator|module-network-install-fire-once)([[:space:])]|$)'
# non-join merge allocation sites:
… | xargs -0 grep -n -E '(merge-hasheq-replace|merge-list-append|merge-replace|merge-last-write-wins|merge-hasheq-list-append)'
# driver.rkt at the pinned commit (HEAD advanced to f3d7f5e3 during the session; driver.rkt differs):
git show 7a0116ec:racket/prologos/driver.rkt | grep -n -E 'net-add-|module-network-install-fire-once'
# confirm the pinned commit and HEAD agree on every other production file:
git diff --stat 7a0116ec HEAD -- racket/prologos | grep -v -E 'tests/|tools/|benchmarks/'
```

Scratch scripts used: `q1sites.py` (sites + enclosing define, HEAD via `git show`),
`callers.py` / `encl.py` (production callers with enclosing define), `merges.py`,
`reconcile.sh`.
