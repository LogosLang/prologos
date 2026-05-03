# PReduce-lite — Stage 3 Design Doc

**Date**: 2026-05-02 (decision points resolved 2026-05-02)
**Status**: Stage 3 design — **decision points resolved; ready for Phase 0**
**Track**: PM Track 9 — first concrete realization (lite = no incrementality, no optimization, no speculation; full AST coverage)
**Branch**: `claude/prologos-layering-architecture-Pn8M9`

**Naming convention**: "PReduce-lite" is the position; the implementation file is `racket/prologos/preduce.rkt` with the entry point `(preduce e)`. Module-level docstring identifies it as PReduce-lite, the Track 9 first concrete realization without incrementality.

**Cross-references**:
- [PM Track 9: Reduction as Propagators (Stage 1, 2026-03-21)](2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md) — the **full vision**, of which PReduce-lite is the first realization (no incrementality, no dependency tracking)
- [Kernel Pocket Universes (2026-05-02)](2026-05-02_KERNEL_POCKET_UNIVERSES.md) — orthogonal; Racket-side PReduce-lite doesn't need it
- [Concurrency Primitives (2026-05-02)](../research/2026-05-02_CONCURRENCY_PRIMITIVES_LLVM_SUBSTRATE.md) — orthogonal; PReduce-lite is single-threaded
- `racket/prologos/reduction.rkt` — the existing tree-walking reducer (~3700 lines) that PReduce-lite eventually replaces
- `racket/prologos/propagator.rkt` — the BSP propagator infrastructure PReduce builds on
- `.claude/rules/on-network.md` — design mantra; PReduce is the canonical "reduction on-network" instance
- `.claude/rules/propagator-design.md` — fire-once propagators, broadcast, set-latch patterns
- `.claude/rules/stratification.md` — topology stratum (used for dynamic dispatch / β-expansion)

---

## Progress Tracker

PReduce-lite covers the full reducer surface (~80 distinct AST node kinds in `reduction.rkt`'s match dispatch) in 16 phases. Each phase ships specific node coverage with a per-phase differential-test gate against `nf`. Final-phase differential test: 1000 random cases over the full surface.

| Phase | Description | Status | Notes |
|---|---|---|---|
| 0 | Acceptance file: 7 small Prologos programs covering Phases 2-5+10 nodes | ✅ | landed in `examples/preduce-lite/`; all 7 elaborate cleanly. Programs: 01-int-add (5), 02-int-nested (9), 03-pair-sum (7), 04-nested-pair (100), 05-add-five (15), 06-boolrec (100), 07-factorial (120) |
| 1 | `preduce.rkt` skeleton: discrete value lattice + cell-allocator helpers + opaque-value rule (covers all type-formers as values) + parameters + error type + entry points | ✅ | landed; 13/13 tests pass in `tests/test-preduce-phase1.rkt`; topology stratum scaffold deferred to Phase 4 (when first request type lands) |
| 2 | Literals (Int/Bool/Nat-val/zero/suc/Unit/Nil) + Int arithmetic (8 ops, with Nat→Int coercion) + `bvar` / `fvar` + `ann` (erase) + pairs (`pair`/`fst`/`snd`) | ⬜ | first compile-expr cases |
| 3 | Static β-reduction (compile-time expansion for non-recursive lambdas) — `lam` + `app` for the closed case | ⬜ | covers programs without recursion |
| 4 | Topology stratum for dynamic β (recursive lambdas via `app` in topology mode) | ⬜ | covers factorial / fib |
| 5 | Eliminators: `natrec`, `boolrec`, `J` (refl-only iota) | ⬜ | covers nat recursion |
| 6 | Vec eliminators: `vhead`, `vtail`, `vcons`, `vnil` | ⬜ | + `Fin` family (`fzero`, `fsuc`) |
| 7 | Char/String/Keyword/Symbol/Path literals + their primitive ops | ⬜ | string concat, char-eq, etc. |
| 8 | Posit/Rat/Quire arithmetic | ⬜ | mirrors Phase 2 with extended numeric tower |
| 9 | `foreign-fn` (with NF-mode integration) — partial-app accumulation, marshal-in/out, side-effect discipline | ⬜ | enables FFI under PReduce; needs its own mini-design at phase entry |
| 10 | `expr-reduce` (general pattern matching with constructor dispatch) | ⬜ | |
| 11 | Container types: `PVec`, `Map`, `Set`, `champ` reductions | ⬜ | |
| 12 | Generic / trait dispatch (`expr-generic-*`) | ⬜ | gates on PPN 4C trait-resolution status |
| 13 | Logic engine surface: `clause`, `defr`, `fact-block`, `atms-*`, `cell-id-*`, `prop-id-*`, `solver`, `goal`, `derivation`, `relation`, `schema`, `answer`, `uf`, `net`, `table-store` | ⬜ | logic primitives that appear post-elaboration as opaque values; most just opaque-pass-through |
| 14 | `Open`/`cumulative`/remaining edge cases (`broadcast-get`, `cut`, `explain`, `explain-with`, `all-different`, `from-int`, `from-nat`, `panic`) | ⬜ | tail of the reducer surface |
| 15 | Differential testing: 1000 random closed Prologos terms over full AST surface; `preduce` vs `nf` equality on every case | ⬜ | the correctness gate |
| 16 | PIR + flip default: shim in `typing-core.rkt` and `reduction.rkt` so `nf` calls `preduce` by default; old reducer kept as fallback for one release; full removal in next track | ⬜ | the deployment phase per workflow rule "Validated ≠ Deployed" |

Status legend: ⬜ not started, 🔄 in progress, ✅ done, ⏸️ blocked.

**Estimated calendar**: ~25-35 days of focused work. Phases 1-5 (~10 days) deliver enough to run factorial/fibonacci end-to-end on the network; Phases 6-14 (~15 days) close coverage; Phases 15-16 (~5 days) are the validation + deployment gate.

---

## 1. Summary

PReduce-lite is a propagator-network-based reducer for the elaborated Prologos AST. It produces, for an input expression `e`, a network of cells + propagators whose run-to-quiescence yields the WHNF of `e`.

**Design priority order** (load-bearing):

1. **Correctness** — PReduce-lite must produce results equal to `nf` for every supported node. Not "approximately right," not "right modulo edge cases" — exactly equal under `equal?`. Differential-test against `nf` at every phase.
2. **Simplicity** — every design choice that trades simplicity for performance is wrong for this track. Discrete value lattice (not e-graph), per-call fresh networks (not sharing), one cell per sub-expression (not granularity tuning), imperative fuel (not tropical-lattice fuel). The simplest realization that produces correct results.
3. **Performance** — *not a goal of PReduce-lite.* Expected to be slower than `nf` because we're paying network overhead for what `nf` does as direct recursion. The full Track 9 vision (e-graph sharing, dependency-tracked invalidation, tropical-quantale fuel) closes the perf gap; PReduce-lite establishes the architectural shape on which those layers compose.

If at any point we find ourselves making a design choice for performance that compromises simplicity or correctness, we are violating the priority order. **Eager optimization is explicitly out of scope.**

**Scope: full AST coverage, phased implementation.** PReduce-lite eventually covers every AST node kind handled by the existing `reduction.rkt` (~80 distinct match arms). Implementation lands in 16 phases; each phase extends the supported set and gates on a differential-test pass against `nf`. The final phase (15) is a 1000-case property-based differential gate over the full surface; phase 16 flips the default (per workflow rule "Validated ≠ Deployed").

**"Lite" means**: no incrementality, no e-graph merges, no equality saturation, no speculative reduction, no tropical-quantale fuel. The cell-value lattice is the simplest possible (discrete with bot); each cell is written once. PReduce-lite is the architectural scaffolding on which full Track 9 (incremental reduction with dependency-tracked invalidation) is later built — same shape, more lattice structure.

**Output**: `(preduce expr) → expr` — drop-in replacement for `(nf expr)` over the supported subset. **Out-of-scope nodes raise a structured error** (no silent fallback during development). For incremental rollout: opt-in via `current-use-preduce?` parameter; default `#f` until Phase 16 flips it after full-coverage gate. This favors correctness over rollout convenience: bugs surface fast rather than hide behind fallback paths. (See § 8 for the validation strategy + parameter contract.)

### 1.1 Per-phase implementation protocol

For each phase 0-16, the following workflow is mandatory (per workflow rule on conversational implementation cadence):

1. **Plan**: re-read the relevant sections of the original PReduce research doc (`2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md`) and this design doc; write a phase mini-plan inline at the phase's progress-tracker row + as a comment block at the top of the phase's implementation file. The mini-plan lists: nodes added this phase, fire-fn shape per node, test cases to add, success criteria.
2. **Implement**: the code per the mini-plan.
3. **Validate**: per-phase test set passes (acceptance file entries unlocked + new test cases + ~50-case differential against `nf` over current subset). For Phase 5+: at least one Prologos program exercising the new feature runs end-to-end via `(preduce e)` and produces the same value as `(nf e)`.
4. **Commit + push**: phase isn't done until pushed; tracker updated to ✅ with commit hash.
5. **If failure**: diagnose; if local fix, apply and re-validate; **if sticky** (3+ failed attempts), redesign the phase — write a delta in this doc + a new mini-plan; user-checkpoint before continuing.
6. **Next phase** starts only after current phase is ✅.

---

## 2. Relationship to PM Track 9 (the full vision)

The Stage 1 doc (2026-03-21) sketches reduction-as-propagators with **dependency tracking** and **incremental invalidation** — when a meta resolves mid-elaboration, downstream reduction cells automatically recompute. That's the load-bearing motivation for Track 9: it eliminates the per-command memo cache staleness problem that Track 8 Part C creates.

**PReduce-lite does NOT include incrementality.** PReduce-lite runs reduction once, end-to-end, and produces the result. No subscription to dependency cells, no recomputation on change.

| Feature | PM Track 9 (full) | PReduce-lite |
|---|---|---|
| Reduction implemented as propagators | ✓ | ✓ |
| One cell per reduction sub-result | ✓ | ✓ |
| Full AST coverage (~80 node kinds) | ✓ | ✓ |
| Dependency tracking | ✓ | ✗ — deferred |
| Invalidation on meta resolve | ✓ | ✗ — deferred |
| E-graph / equality saturation | (open) | ✗ |
| Speculative reduction × ATMS | ✓ | ✗ — deferred |
| Tropical-lattice fuel | ✓ (per PPN 4C M2 lean) | ✗ — imperative counter |
| Replaces memo caches | ✓ | ✓ after Phase 16 (caches go away when default flips) |

**Why lite first**: incrementality is non-trivial (dependency-set propagation through every reduction case) and not load-bearing for "execute a Prologos program." Landing PReduce-lite gives us:
1. A working PReduce over the full AST surface; validates the architectural shape
2. A test harness (differential vs `nf`) that becomes the regression gate for full Track 9
3. The Phase 1 cell-allocator helpers and discrete lattice that full Track 9 inherits and extends
4. A retired `reduction.rkt` (Phase 16) — once `nf`'s callers use `preduce`, the imperative tree-walker can shrink to a thin façade or be removed entirely

PReduce-lite is the foundation, not a competitor, of the full Track 9 vision. The shape (one-cell-per-sub-result, propagators implement reduction rules) is identical; only the dependency layer differs.

---

## 3. Scope

PReduce-lite covers the **full reducer surface** — every AST node kind handled by `reduction.rkt`'s match dispatch (~80 distinct node kinds in production today). Implementation is phased; each phase ships specific node coverage and is gated by per-phase differential testing against `nf`. Until full coverage lands (Phase 15 differential gate), unsupported nodes **raise a structured error** rather than silently fall back to `nf`.

### Coverage by phase (compressed)

| Phase | Nodes added |
|---|---|
| 1 | Skeleton + opaque-value rule for type-formers (`Pi`, `Sigma`, `Type`, `Vec`, `Eq`, `Nat`, `Int`, `Bool`, `Unit`, plus all type-formers handled identity-style by `nf-whnf`) |
| 2 | Literals (`int`, `true`, `false`, `nat-val`, `zero`, `suc`, `unit`, `nil`); Int arithmetic (`int-{add,sub,mul,div,mod,eq,lt,le}` with Nat→Int coercion); `bvar`, `fvar`, `ann` (erase); pairs (`pair`/`fst`/`snd`) |
| 3 | Static β: `lam` as value, `app` for closed (non-recursive) cases via compile-time expansion |
| 4 | Topology stratum + dynamic β: recursive `lam`/`app` via topology-emitted body subnetworks |
| 5 | Eliminators: `natrec`, `boolrec`, `J` (refl-only iota) |
| 6 | Vec eliminators (`vhead`, `vtail`, `vcons`, `vnil`) + `Fin` family (`Fin`, `fzero`, `fsuc`) |
| 7 | Char/String/Keyword/Symbol/Path literals + their primitive ops (string concat, char-eq, etc.) |
| 8 | Posit/Rat/Quire arithmetic (mirrors Phase 2 with extended numeric tower) |
| 9 | `foreign-fn` — partial-app accumulation, NF mode for args, marshal-in/out, side-effect discipline. Mini-design at phase entry. |
| 10 | `expr-reduce` (general pattern matching with constructor dispatch) |
| 11 | Container types: `PVec`, `Map`, `Set`, `champ` reductions |
| 12 | Generic / trait dispatch (`expr-generic-*`); gates on PPN 4C trait-resolution status |
| 13 | Logic-engine surface as opaque values + their reduction rules: `clause`, `defr`, `fact-block`, `atms-*`, `cell-id-*`, `prop-id-*`, `solver`, `goal`, `derivation`, `relation`, `schema`, `answer`, `uf`, `net`, `table-store` |
| 14 | Tail edges: `Open`, `cumulative`, `broadcast-get`, `cut`, `explain`, `explain-with`, `all-different`, `from-int`, `from-nat`, `panic` |

### Hard-error policy on unsupported nodes

`compile-expr` raises `preduce-unsupported-node-error` for any AST node not yet handled by the current phase. The error includes:
- The node kind that hit the unhandled path
- The phase at which support is planned
- A reproducible expression to add to per-phase regression tests

Two consequences:
1. **Bugs surface fast.** A miscompiled node never silently falls through to `nf`'s correct answer; PReduce-lite's coverage is exactly what it claims.
2. **Per-phase rollout is opt-in.** Tests that exercise unsupported nodes don't run under PReduce-lite until the phase lands. The `current-use-preduce?` parameter (default `#f` until Phase 16) gates participation.

After Phase 15's full-surface differential gate passes, Phase 16 flips the default to `#t`. Per workflow rule "Validated ≠ Deployed," validation phase and deployment phase are explicitly separated.

### What's *never* in PReduce-lite (deferred to full Track 9)

| Feature | Target |
|---|---|
| Incremental recomputation / dependency tracking | Track 9 full |
| Speculative reduction × ATMS | Track 9 full + ATMS integration |
| E-graph / equality saturation | Track 9 full |
| Tropical-quantale fuel | PPN 4C M2 |
| `expr-meta` reduction (PReduce-lite assumes post-elaboration AST: no metas) | n/a — meta resolution is the elaborator's job |
| `expr-error` / `expr-hole` / `expr-typed-hole` (shouldn't appear post-elaboration) | n/a — hard-error if encountered |

---

## 4. Architecture

### 4.1 The cell-value lattice

Each PReduce cell holds an **expr-value** under a discrete lattice:

```
   ⊤  (contradiction)
   |
   e₁, e₂, …  (concrete expression values — incomparable)
   |
   ⊥  (unevaluated)
```

Merge function:
```racket
(define (preduce-merge a b)
  (cond
    [(eq? a 'preduce-bot) b]
    [(eq? b 'preduce-bot) a]
    [(eq? a 'preduce-top) 'preduce-top]
    [(eq? b 'preduce-top) 'preduce-top]
    [(equal? a b) a]
    [else 'preduce-top]))
```

**Properties**:
- Monotone (each cell can only ascend the lattice)
- CALM-safe (no coordination needed for monotone joins)
- Each cell written **at most once** (deterministic reduction guarantees this; ⊤ indicates a bug)
- Domain-id `preduce-value-domain` registered alongside existing `prop-int`, `prop-bool`, etc.

This is the simplest possible lattice; it's the moral equivalent of "uninitialized memory that, once written, stays." PReduce-lite's correctness reduces to: every reduction rule's propagator writes the right value to its output cell.

### 4.2 The compile-expr translation

Signature:
```racket
(compile-expr : expr × env × net → (values cell-id net))
```
- `expr` is the input AST node
- `env` is a list of cell-ids indexed by de Bruijn index (for `expr-bvar` lookup)
- `net` is the propagator network (accumulator, threaded through)
- Returns the cell-id whose value (after run-to-quiescence) holds the WHNF of `expr`, plus the updated network

**Top-level entry**:
```racket
(define (preduce expr)
  (define net0 (make-prop-network))
  (define-values (result-cid net1) (compile-expr expr '() net0))
  (define net-final (run-to-quiescence net1 #:fuel default-fuel))
  (define result-value (net-cell-read net-final result-cid))
  (cond
    [(eq? result-value 'preduce-bot) (error 'preduce "cell unfilled — bug")]
    [(eq? result-value 'preduce-top) (error 'preduce "contradiction — bug or mis-typed program")]
    [else result-value]))
```

The pattern is uniform across AST node kinds:
1. Recursively `compile-expr` sub-expressions, getting their cell-ids
2. Allocate a result cell (init `preduce-bot`)
3. Install a propagator that reads the sub-cells, applies the reduction rule, writes the result cell

### 4.3 Topology stratum for dynamic dispatch

β-reduction is **non-static**: the body of a lambda isn't compiled until the lambda is applied (which may happen recursively many times). Same for `expr-natrec` (each recursive step instantiates a new application).

These are handled via the existing **topology stratum** (per `.claude/rules/stratification.md`):

1. A request-accumulator cell `preduce-topology-requests` holds pending dynamic-dispatch jobs.
2. When a β-propagator fires and its function-input is a lambda, it writes a request `(beta lam-expr arg-cid result-cid env)` to the accumulator.
3. The topology stratum handler runs after S0 quiesces: walks pending requests, calls `compile-expr` on each lambda body in the appropriate environment, and installs an identity propagator from the body's result cell to the original app's result cell.
4. After topology fires, the new propagators participate in the next S0 round.

**Termination**: imperative counter in the topology handler (per Q4 of kernel-PU doc — fuel is imperative for v1; lattice-cell fuel is full-Track-9 territory). Default ~10⁶ ops; configurable via `current-preduce-fuel` parameter.

**No CALM violation**: topology is the canonical strata for non-monotone structural changes. Same machinery as PAR Track 1, BSP-LE Track 2B, etc.

### 4.4 Termination

Three termination conditions:
1. **Quiescence**: all propagators fire to fixpoint, result cell holds a value. Normal case.
2. **Fuel exhaustion**: topology counter hits zero. Result cell remains ⊥; `preduce` raises an error (non-terminating program).
3. **Contradiction**: a cell merges to ⊤. Indicates a bug in the translation or the input program; `preduce` raises an error.

### 4.5 Entry / exit

PReduce-lite runs in **closed-world mode**: the input expression has no free metas, no free fvars except those resolvable from the global definition table. This is the standard post-elaboration assumption.

For `expr-fvar` lookups, `compile-expr` consults the existing top-level definition table (the same one `nf` uses) and returns the cell-id of that definition's value. To avoid re-compiling the same definition multiple times, a per-`preduce` call cache: `defn-name → cell-id`.

---

## 5. Per-AST-node translation table

Translation rules for the Phase 1-5 core surface (later phases extend with their own subsections). `B` denotes the network builder (mutable), `env` is the bvar environment, `→ cid` denotes "returns the result cell-id."

### 5.1 Literals

| Node | Translation |
|---|---|
| `(expr-int n)` | Allocate cell with init `(expr-int n)` → cid |
| `(expr-true)` / `(expr-false)` | Same shape |
| `(expr-nat-val n)` | Same |
| `(expr-zero)` | Same |
| `(expr-suc inner)` | Compile inner → cid_in. Allocate cid_out. Install fire-once propagator: when cid_in resolves to `(expr-nat-val k)`, write `(expr-nat-val (+ k 1))` to cid_out; otherwise write `(expr-suc <inner-value>)` (stuck form) |
| `(expr-unit)` / `(expr-nil)` | Allocate cell with init self → cid |

### 5.2 Variables

| Node | Translation |
|---|---|
| `(expr-bvar i)` | Look up `(list-ref env i)`. Return that cell-id directly (no new cell). The bvar IS the cell from its binder's scope. |
| `(expr-fvar name)` | Look up name in the global definition table. If cached in the per-preduce-call defn-cache, return the cached cid. Otherwise, compile the definition's body in empty env, cache the cid, return it. |

### 5.3 Arithmetic

For each binary op `op ∈ {add, sub, mul, div, mod, eq, lt, le}`:

| Node | Translation |
|---|---|
| `(expr-int-op a b)` | Compile a → cid_a, b → cid_b. Allocate cid_out. Install fire-once propagator: when both inputs resolve to numeric values, **coerce Nat→Int** (`(expr-nat-val k)` → `(expr-int k)`; `(expr-zero)` → `(expr-int 0)`; `(expr-suc n)` → coerce inner + add 1), then write `(expr-int (op n_a n_b))` (or `(expr-true)` / `(expr-false)` for comparisons) to cid_out. |

The propagator's fire function needs both inputs concretely; `prop-fire` reads cells via `net-cell-read`, returns `(net-cell-write net cid_out result)` if both inputs are concrete values, or stays pending if either is still ⊥. The Nat→Int coercion mirrors `try-coerce-to-int` in the existing reducer (line ~999); inlined into the propagator's fire-fn rather than a separate pass since the coercion is local.

### 5.4 Pairs

| Node | Translation |
|---|---|
| `(expr-pair fst-expr snd-expr)` | Compile fst-expr → cid_a, snd-expr → cid_b. Allocate cid_out. Install fire-once propagator: when both inputs resolve, write `(preduce-pair-value cid_a cid_b)` to cid_out. (The pair-value is a wrapper carrying cell-ids of components — projections look at it.) |
| `(expr-fst inner)` | Compile inner → cid_in. Allocate cid_out. Install fire-once propagator: when cid_in resolves to `(preduce-pair-value cid_fst _)`, install identity propagator from cid_fst to cid_out. |
| `(expr-snd inner)` | Symmetric. |

### 5.5 Functions

| Node | Translation |
|---|---|
| `(expr-lam mw type body)` | Allocate cell with init `(preduce-lam-value type body env)`. The lambda is a value; its body isn't compiled until applied. The captured env (the cell-id list) closes over the binders. |
| `(expr-app f a)` | Compile f → cid_f, a → cid_a. Allocate cid_out. Install fire-once **β-propagator**: when cid_f resolves to `(preduce-lam-value _ body lam-env)`, emit a topology request `(beta body cid_a lam-env cid_out)`. The topology handler compiles `body` with env `(cons cid_a lam-env)`, installs identity propagator from compiled-body's result cid to cid_out. |

For built-in / opaque functions (lambdas already over the FFI surface), the β-propagator special-cases on the function form.

### 5.6 Eliminators

| Node | Translation |
|---|---|
| `(expr-natrec mot base step target)` | Compile target → cid_t. Allocate cid_out. Install fire-once **natrec-propagator**: when cid_t resolves: if `(expr-zero)` or `(expr-nat-val 0)`, install identity from compiled `base` to cid_out; if `(expr-nat-val (+ k 1))` or `(expr-suc n)`, emit topology request to compile `(expr-app (expr-app step n) (expr-natrec mot base step n))` and install identity from its result to cid_out. |
| `(expr-boolrec mot tc fc target)` | Compile target → cid_t. When cid_t resolves to `(expr-true)`, install identity from compiled `tc` to cid_out; if `(expr-false)`, from compiled `fc`. |
| `(expr-J motive base left right proof)` | Compile proof → cid_p. When cid_p resolves to `(expr-refl)`, emit topology request to compile `(expr-app base left)` and identity-forward to cid_out. |

### 5.7 Annotation

| Node | Translation |
|---|---|
| `(expr-ann inner _)` | Compile inner → cid_in. Return cid_in directly (annotation erasure; no new cell). |

### 5.8 Foreign functions — deferred to Phase 9

`expr-foreign-fn` is **deferred from PReduce-lite Phases 1-8** (Phase 9 follow-on, see § 3 deferral table).

**Rationale**: foreign-fn handling in the existing reducer (`reduction.rkt:1456`) requires:
1. Per-arg accumulation across multiple β fires (each app adds one arg)
2. **Full normalization** (`nf`, not `whnf`) of all args before marshalling — meaning PReduce would need an NF mode for arg cells, not just WHNF
3. Marshalling Prologos values → Racket values per type (`marshal-in`)
4. Invocation via `(apply proc rkt-args)` — which may have side effects
5. Marshalling Racket result → Prologos value (`marshal-out`)
6. The result re-enters reduction (`(whnf prologos-result)`)

Items 1, 3, 5 are mechanically tractable. Items 2 and 4 are the real cost:
- **(2) NF mode**: PReduce-lite Phases 1-8 ship WHNF; foreign-fn's NF requirement would force the NF infrastructure in earlier than its natural place (WHNF-mode is enough for everything else; NF is an internal recursion under binders). Better to defer NF to its own phase where the design can address recursive descent through binders cleanly.
- **(4) Side effects**: `proc` may print, mutate, allocate. Under BSP, a propagator must fire exactly once per logical invocation (otherwise the side effect duplicates). Fire-once propagators handle this if the topology is right, but the design needs explicit treatment of "when does the side effect happen relative to the round" — and that interacts with future ATMS speculation (which might fire-then-retract a foreign call). Worth its own design.

**Behavior in PReduce-lite Phases 1-8**: any program using `expr-foreign-fn` raises `preduce-unsupported-node-error` if invoked through `(preduce e)`. Per the hard-error policy (§ 3 + § 8.5), there is no silent fallback inside PReduce. Users running with `current-use-preduce? = #f` (the default until Phase 16) see the existing `nf` handle foreign-fn unchanged; users running with `current-use-preduce? = #t` early are explicitly opted into PReduce coverage and get the loud error. The acceptance file (§ 8.1) is chosen to NOT exercise foreign-fn, so per-phase test gates aren't blocked. The diagnostic helper `(preduce-or-nf e)` (§ 8.5) catches the error and dispatches to `nf` for exploratory REPL use.

---

## 6. Worked example: factorial

Source:
```prologos
def fact (n : Nat) : Nat :=
  match n
    | zero  -> 1
    | suc k -> n * (fact k)

def main := fact 5
```

Post-elaboration AST (sketch):
```
(expr-lam mw expr-Nat
  (expr-natrec mot
    (expr-nat-val 1)                  ; base
    (expr-lam mw _                    ; step: λk. λrec. (suc k) * rec
      (expr-lam mw _
        (expr-int-mul (expr-suc (expr-bvar 1)) (expr-bvar 0))))
    (expr-bvar 0)))                    ; target = n
```

For `main`, calling `fact 5`:

1. **Top-level**: compile `(expr-app fact (expr-nat-val 5))`. Allocate result cell `R_main`.
2. **β-propagator** fires on `R_fact`/`(expr-nat-val 5)`. Emits topology request: compile fact's body in env `[arg-cid-for-5]`.
3. **Topology stratum** runs. Compiles the body `(expr-natrec mot 1 step (expr-bvar 0))` in env `[arg-cid-for-5]`. The bvar 0 returns arg-cid-for-5. Result cell `R_body` allocated. Identity propagator installed from `R_body` → `R_main`.
4. **natrec-propagator** fires when target resolves (5). Emits topology to compile `(step 4 (natrec ... 4))`.
5. **Topology stratum** runs again. Compiles inner natrec for `n=4`. Recurses.
6. At `n=0`, base case fires: `R_at_zero` becomes `(expr-nat-val 1)`.
7. The chain of identity propagators threads results back up through `n=1, 2, 3, 4, 5`. Each level's `expr-int-mul` propagator fires when both its inputs resolve.
8. Eventually `R_main` holds `(expr-int 120)`.
9. `(preduce ...)` reads `R_main`, returns `(expr-int 120)`.

**Network shape**:
- ~5 cells per natrec level × 6 levels = ~30 cells
- ~10 propagators per level
- Topology stratum fires ~6 times (once per recursion depth)
- All within a few BSP rounds

This is a unit-of-work example that would form one of the Phase 0 acceptance file entries.

---

## 7. NTT model

Per the workflow rule "NTT model REQUIRED for propagator designs." Speculative NTT for PReduce-lite:

```ntt
;; Cell value lattice
(domain preduce-value
  (:lattice :discrete-with-bot)
  (:bot 'preduce-bot)
  (:top 'preduce-top)
  (:merge preduce-merge))

;; β-reduction propagator
(propagator beta-reduce
  (:reads f-cell arg-cell)
  (:writes app-result-cell)
  (:fire-once)
  (:fire
    (let ((f (cell-read f-cell)))
      (cond
        [(preduce-lam-value? f)
         (emit-topology-request 'beta
           (preduce-lam-value-body f)
           arg-cell
           (preduce-lam-value-env f)
           app-result-cell)]
        [(preduce-bot? f) (stay-pending)]
        [else (cell-write app-result-cell (expr-app f arg-cell))]))))

;; Topology handler
(stratum-handler preduce-topology-handler
  (:fires-after S0)
  (:reads preduce-topology-requests)
  (:writes (cells, propagators ...))
  (:body
    (for ((req (cell-read preduce-topology-requests)))
      (case (request-kind req)
        [beta
         (let* ((body-cid (compile-expr (req-body req) (cons (req-arg req) (req-env req)))))
           (install-identity-propagator body-cid (req-result-cell req)))]
        [natrec-suc ...]
        [foreign-call ...]))))
```

### NTT correspondence table

| NTT | Racket realization (PReduce-lite) | Future (full Track 9) |
|---|---|---|
| `(domain preduce-value :lattice :discrete-with-bot)` | `register-domain!` with `preduce-merge` | extend to e-graph lattice |
| `(propagator beta-reduce (:reads ...))` | `net-add-fire-once-propagator` | unchanged |
| `(:fire-once)` | flag-guarded fire-once | unchanged |
| `(emit-topology-request ...)` | write to `preduce-topology-requests` cell | unchanged |
| `(stratum-handler :fires-after S0)` | `register-stratum-handler!` | unchanged |
| `(install-identity-propagator ...)` | `net-add-propagator` with `kernel-identity` tag | unchanged |
| (no dependency tracking) | n/a | reduce-cell subscribes to dep set; propagator fires on dep change |

### NTT gaps surfaced

- NTT doesn't have first-class `emit-topology-request` syntax — open question for the future NTT track. Recorded.
- NTT doesn't have `:fire-once` annotation — already noted as a gap by SRE Track 2G.

---

## 8. Validation strategy

PReduce-lite ships a **per-phase regression gate** plus a **final-phase property-based differential gate** plus a **full-suite shim test** at deployment. Every phase has explicit test obligations; no phase merges without its gate passing.

### 8.1 Acceptance file (Phase 0)

`racket/prologos/examples/2026-05-02-preduce-lite.prologos` — 7 small programs whose `nf` is known and whose AST stays within the Phases 2-5 subset:

1. `def main := [int+ 2 3]` → `(expr-int 5)`
2. `def main := [if true 1 2]` → `(expr-int 1)`
3. `def main := <[+ 1 2]; [* 3 4]>` → pair of `(expr-int 3)` and `(expr-int 12)`
4. `def main := [fst <1; 2>]` → `(expr-int 1)`
5. `def main := fact 5` → `(expr-int 120)` (factorial via natrec)
6. `def main := fib 10` → `(expr-int 55)` (Fibonacci via natrec)
7. `def main := [sum 5]` → `(expr-int 15)` where `sum n = n + (n-1) + ... + 0` via natrec (avoids list/foreign-fn dependency)

Run `(preduce main-body)` and compare to `(nf main-body)`. Each phase unlocks specific entries: Phase 2 unlocks #1-4; Phase 5 unlocks #5-7.

Additional acceptance files added per phase as the surface grows (Phase 6 adds Vec eliminator examples; Phase 7 string ops; Phase 9 foreign-fn; Phase 10 expr-reduce; etc).

### 8.2 Per-phase regression gate

Each phase ships a per-phase test set in `tests/test-preduce-phase-{N}.rkt`. The set targets exactly the nodes the phase introduces:
- For each new node kind, ≥3 hand-written test cases covering: typical use, boundary case, interaction with previously-supported nodes
- The phase's section of the acceptance file
- Targeted differential test (~50 random cases over the *current* supported subset)

Phase merges into the track only when its test set is green.

### 8.3 Final-phase differential gate (Phase 15) — 1000 cases

After Phase 14 (full-surface coverage), Phase 15 runs a property-based differential test:
- Generator produces random closed Prologos terms over the **full** AST surface (not subset-restricted)
- For each term: run `(preduce term)` and `(nf term)`, assert `equal?`
- Target: **1000 cases**, with shrinking on failure
- Failures investigated individually before Phase 16 begins

Why 1000: PReduce-lite covers ~80 node kinds with combinatorial interactions. 100 cases (the original MVP target) gives ~1.25 cases per node-kind in expectation — too sparse to catch interaction bugs. 1000 gives ~12 per node-kind plus broader interaction coverage. Cost: a few minutes of CPU time. Better to be correct.

```racket
(define (preduce-differential-gate iterations)
  (for ([i (in-range iterations)])
    (define term (random-closed-term #:seed i))
    (define result-preduce
      (with-handlers ([preduce-unsupported-node-error?
                       (lambda (e)
                         (error 'preduce-differential-gate
                           "Phase 15 hit unsupported node ~a — coverage incomplete"
                           (exn-node-kind e)))])
        (with-fuel default-fuel (preduce term))))
    (define result-nf (nf term))
    (unless (equal? result-preduce result-nf)
      (error 'preduce-differential-gate
        "MISMATCH on case ~a:\n  term: ~v\n  preduce: ~v\n  nf:      ~v"
        i term result-preduce result-nf))))
```

Note: under the hard-error policy, hitting an unsupported node during Phase 15 is itself a coverage bug, NOT a "fall back to nf" event. Phase 15 should encounter zero unsupported-node errors; if it does, the relevant earlier phase has a coverage hole and must be amended before Phase 15 can pass.

### 8.4 Deployment validation (Phase 16)

Once Phase 15 is green, Phase 16:
1. Flips `current-use-preduce?` default to `#t`
2. Runs the **full existing test suite** (~all `tests/test-*.rkt` files) with the new default
3. Expectation: zero regressions vs the prior `nf`-default suite run
4. If green: PIR records "PReduce-lite is the default reducer; old `nf` retained for one release as named-fallback parameter `current-use-nf-fallback?` (default `#f`)"
5. If not green: investigate per-failure; either bug in PReduce-lite (fix), or test legitimately depends on `nf` semantics (rare; document as known divergence)

Per workflow rule "Validated ≠ Deployed," Phase 15's validation gate and Phase 16's deployment gate are explicitly separated. Phase 15 says "PReduce-lite is correct"; Phase 16 says "PReduce-lite is the default."

### 8.5 No graceful-degradation fallback in PReduce itself

PReduce-lite raises `preduce-unsupported-node-error` on any node not yet covered by the current phase. There is **no silent fallback to `nf`** inside PReduce. Rationale and trade-off analysis: see § 12 adversarial framing entry on hard-error policy.

For exploratory use (e.g., running an arbitrary program at the REPL during early phases), a separate diagnostic helper is provided:
```racket
(define (preduce-or-nf e)
  (with-handlers ([preduce-unsupported-node-error? (lambda (_) (nf e))])
    (preduce e)))
```
Opt-in per call, makes the engine switch visible in the call site rather than invisible in the runtime. The diagnostic helper is for human-driven exploration, never wired into the test suite or `typing-core` shim.

---

## 9. File / module layout

```
racket/prologos/
  preduce.rkt                 ; new, ~600-800 LOC
    - preduce-merge
    - preduce-domain registration
    - compile-expr
    - per-AST-node fire functions
    - topology handler
    - top-level (preduce e)
  tests/test-preduce.rkt      ; new, ~200 LOC
    - acceptance file run
    - per-node unit tests
    - differential vs nf
  examples/2026-05-02-preduce-lite.prologos  ; new, acceptance file
```

Existing files touched (small):
- `propagator.rkt` — register `preduce-value` domain
- `typing-core.rkt` — optional shim point if Phase 8 deploys

No changes to AST, elaborator, or the existing reducer. PReduce-lite is purely additive.

---

## 10. Open questions

| # | Question | Resolution path |
|---|---|---|
| Q1 | Single shared network across multiple `preduce` calls within a command, or fresh per call? | Fresh per call for PReduce-lite (simplest). Sharing is an optimization; defer. |
| Q2 | When a defn is referenced multiple times via `expr-fvar`, do all references share one cell, or one per reference? | Share one cell (Phase 6 defn-cache). This gives function-level memoization for free. |
| Q3 | What about compiled body subnetworks for the *same* lambda applied to *different* args? | Each app instantiates a fresh body subnetwork. No body-sharing across calls. This trades memory for simplicity; e-graph sharing is full-Track-9. |
| Q4 | Does PReduce produce WHNF, NF, or a parameter? | Parameter `current-preduce-mode ∈ {whnf, nf}`. WHNF stops at the head; NF recursively reduces under binders. Phase 1 ships WHNF; NF is a thin recursive wrapper. |
| Q5 | Garbage collection of the network after `preduce` returns? | Racket GC. The network is a fresh `prop-network` struct; once `preduce` returns, the only reference is the result expr; the cells go away. |
| Q6 | Interaction with PPN 4C (elaboration-on-network)? | Orthogonal. PReduce runs *after* elaboration (post-meta-resolution). The two networks could merge later (full Track 9) but not for PReduce-lite. |
| Q7 | Performance vs `nf`? | Expected slower for PReduce-lite — we're paying network overhead instead of direct recursion. Acceptable for PReduce-lite's purpose (architectural validation, not perf). Phase 16 PIR records the gap; full Track 9's e-graph sharing will close it. |
| Q8 | How does PReduce handle programs that don't terminate under `nf` (currently caught by fuel)? | Same fuel mechanism via topology counter. A non-terminating program eventually exhausts and raises. |

---

## 11. Decision points — resolved 2026-05-02

| # | Question | Decision | Rationale |
|---|---|---|---|
| 1 | **Naming** | "PReduce-lite" — position; filename `preduce.rkt`; entry point `(preduce e)` | Conveys "first concrete realization, no incrementality" without the "MVP" framing that suggests minimal scope. PReduce-lite covers the full AST surface; what's "lite" is the lattice + missing dependency layer. |
| 2 | **AST subset** | Full coverage, phased — all ~80 reducer nodes land across Phases 1-14; foreign-fn deferred to Phase 9 with its own mini-design | "Aim for full coverage but avoiding some like foreign function is acceptable." Phased implementation acknowledges effort; full coverage is the destination, not an aspiration. |
| 3 | **Phase ordering** | 0-16 as listed in Progress Tracker; per-phase regression gates throughout, full differential at Phase 15, deployment at Phase 16 | "The plan should cover all nodes but implementing them in phases is acceptable." Per-phase gates rather than back-loaded testing — bugs surface immediately. |
| 4 | **Differential testing** | 1000 cases at Phase 15 over the full AST surface; per-phase ~50 cases over current subset | "Better to be correct." 100 cases (original MVP target) gives ~1.25 cases per node-kind in expectation — too sparse. 1000 gives ~12 per node-kind plus interaction coverage. Cost: a few minutes CPU. |
| 5 | **Out-of-scope handling** | Hard error inside PReduce (`preduce-unsupported-node-error`); separate opt-in `(preduce-or-nf e)` diagnostic helper for exploratory use | "Better to be correct." Three correctness traps in graceful degradation: coverage-hole hiding, false-positive test results, end-state mismatch (post-Phase 16 has no fallback anyway). Hard error is the steady-state semantics — develop on it from day one. Explicit explanation of the trade-off at session checkpoint 2026-05-02. |
| 6 | **Sequencing** | Independent of all other tracks (PPN 4C, kernel PU, Sprint G, Sprint D) | Runs purely on existing Racket `prop-network`; no kernel work; no AST changes; no lowering changes. Can land in parallel with any other track. |

All decision points resolved. Ready for Phase 0 (acceptance file).

---

## 12. Adversarial framing (Vision Alignment Gate)

| Catalogue | Challenge |
|---|---|
| ✓ PReduce is on-network | Are env lookups on-network? — *Yes; bvars resolve to cell-ids from env, not racket parameters or hashes.* |
| ✓ Discrete value lattice is monotone | Is "first write wins" a real lattice or a lazy excuse? — *It's the simplest valid lattice (chain ⊥ → e → ⊤). The deeper question is whether we should use the e-graph lattice now and avoid the migration. Answer: e-graph requires equivalence merges (a × b = b × a) which is exactly the "optimization" the user said is out of MVP scope. Stay simple.* |
| ✓ Topology stratum for dynamic dispatch | Is this the canonical stratification, or are we reinventing it? — *Canonical; same machinery as PAR Track 1, BSP-LE Track 2B. No new stratum mechanism.* |
| ✓ Per-call fresh network | Is this scaffolding? — *Yes, named explicitly in Q1 + Q3 as deferred sharing optimization. Track 9 full will share across calls via subscription model.* |
| ✓ Imperative fuel (Q8) | "Imperative" — is this rationalization for off-network? — *Imperative for v1, named scaffolding. Tropical-quantale fuel cell from PPN 4C M2 is the v2 retirement target. Specific replacement, not "we'll get to it eventually."* |
| ✓ Hard-error policy on unsupported nodes | Is this user-hostile? — *Mitigated by `current-use-preduce?` defaulting to `#f` until Phase 16. Tests + users see no change until full-coverage gate has passed. Hard error fires only in opt-in PReduce paths, where it forces honest coverage tracking instead of false-positive test results. The diagnostic `(preduce-or-nf e)` helper exists for exploratory REPL use without polluting the engine.* |
| ✓ Foreign-fn deferred to Phase 9 | Is this a real deferral or rationalization? — *Real, with named target (Phase 9) and specific rationale (§ 5.8): NF-on-args requires NF mode in PReduce; side-effect semantics under BSP need explicit treatment. Programs using FFI raise `preduce-unsupported-node-error` until Phase 9 lands; the existing `nf` continues to handle them via `current-use-preduce? = #f`. Acceptance file chosen to not exercise FFI.* |
| ✓ Per-phase gate + final 1000-case differential | Is this redundant? — *No. Per-phase gate validates the just-added subset; final gate validates interactions across the full surface. Phase 15 catches interaction bugs that per-phase gates can't (since per-phase gates only see partial coverage).* |
| ✓ Validated ≠ Deployed (Phase 15 vs 16) | Real separation, or theatre? — *Real. Phase 15 is "PReduce-lite is correct" (1000-case differential); Phase 16 is "PReduce-lite is the default" (full suite passes with `current-use-preduce? = #t`). Per workflow rule, validation phase must be followed by an explicit deployment phase, not implicitly conflated.* |
| ✓ No eager optimization (priority order: correctness > simplicity > performance) | Will perf shortcuts creep in during implementation? — *Tracked at every phase commit: each commit message lists the design choices made and confirms none traded simplicity or correctness for performance. If a perf-driven choice is made, it must be (a) named as a deviation in the commit message, (b) justified, (c) accompanied by an entry in the design-doc deltas section. The bar for accepting a perf-driven choice is high; the default is "no, simpler is better, perf is for full Track 9."* |
| ✓ Differential testing | Is the test methodology valid? — *Differential against `nf` is the strongest possible oracle (it's the existing implementation). The risk is `nf` having a bug that PReduce inherits — but that's a different class of bug (semantic, not architectural).* |

---

## 13. References

### PReduce / reduction-on-propagators

- [PM Track 9: Reduction as Propagators (Stage 1, 2026-03-21)](2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md) — origin
- [PPN 4C Design (2026-04-17)](2026-04-17_PPN_TRACK4C_DESIGN.md) — M2 mini-design lean: tropical-quantale fuel cell as PReduce template

### Architectural prerequisites

- [Stratification rule](../../.claude/rules/stratification.md) — canonical strata pattern; PReduce-lite uses topology
- [Propagator design rule](../../.claude/rules/propagator-design.md) — fire-once, broadcast, set-latch
- [On-network rule](../../.claude/rules/on-network.md) — design mantra
- `racket/prologos/propagator.rkt:715–730` — `fork-prop-network` (not used by PReduce-lite Phases 1-14 but referenced for PU integration future)
- `racket/prologos/propagator.rkt:2441` — `register-stratum-handler!` (used by PReduce-lite for topology)

### Code

- `racket/prologos/reduction.rkt` — current tree-walking reducer (oracle for differential testing)
- `racket/prologos/syntax.rkt` — AST node definitions

---

**End of design doc.**
