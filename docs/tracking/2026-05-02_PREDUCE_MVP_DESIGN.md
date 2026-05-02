# PReduce MVP — Stage 3 Design Doc

**Date**: 2026-05-02
**Status**: Stage 3 design proposal — **awaiting user review**
**Track**: SH / PM Track 9 — first concrete realization (MVP scope)
**Branch**: `claude/prologos-layering-architecture-Pn8M9`

**Cross-references**:
- [PM Track 9: Reduction as Propagators (Stage 1, 2026-03-21)](2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md) — the **full vision**, of which this MVP is a strict subset (no incrementality, no dependency tracking)
- [Kernel Pocket Universes (2026-05-02)](2026-05-02_KERNEL_POCKET_UNIVERSES.md) — orthogonal; Racket-side MVP doesn't need it
- [Concurrency Primitives (2026-05-02)](../research/2026-05-02_CONCURRENCY_PRIMITIVES_LLVM_SUBSTRATE.md) — orthogonal; MVP is single-threaded
- `racket/prologos/reduction.rkt` — the existing tree-walking reducer (~3700 lines) that PReduce-MVP eventually replaces
- `racket/prologos/propagator.rkt` — the BSP propagator infrastructure PReduce builds on
- `.claude/rules/on-network.md` — design mantra; PReduce is the canonical "reduction on-network" instance
- `.claude/rules/propagator-design.md` — fire-once propagators, broadcast, set-latch patterns
- `.claude/rules/stratification.md` — topology stratum (used for dynamic dispatch / β-expansion)

---

## Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| 0 | Acceptance file: 6-7 small Prologos programs whose `nf` is known | ⬜ | gate before Phase 1 |
| 1 | `preduce.rkt` skeleton: discrete value lattice + cell-allocator helpers + opaque-value rule | ⬜ | no AST cases yet |
| 2 | `compile-expr` for literals + arithmetic (with Nat→Int coercion) + bvars + pairs | ⬜ | no β yet |
| 3 | Static β-reduction (compile-time expansion for non-recursive lambdas) | ⬜ | covers many simple programs |
| 4 | Topology stratum for dynamic β (recursive lambdas) | ⬜ | covers factorial / fib |
| 5 | Pattern-match: `expr-natrec`, `expr-boolrec`, `expr-J` | ⬜ | covers nat recursion |
| 6 | Differential testing: random Prologos programs, compare `preduce` vs `nf` | ⬜ | ~100 cases |
| 7 | PIR + decision: ship as alternative path, or replace `nf` outright | ⬜ | |

Status legend: ⬜ not started, 🔄 in progress, ✅ done, ⏸️ blocked.

---

## 1. Summary

PReduce-MVP is a propagator-network-based reducer for the elaborated Prologos AST. It produces, for an input expression `e`, a network of cells + propagators whose run-to-quiescence yields the WHNF of `e`. The MVP covers a **core subset** of ~20 AST node kinds — enough to execute factorial, fibonacci, list-folds, and the existing acceptance examples — and defers the long tail (272 distinct node references in the current reducer) to follow-on phases.

**MVP scope is execution, not optimization.** No e-graph merges, no equality saturation, no speculative reduction, no tropical-quantale fuel, no incremental dependency tracking. The cell-value lattice is the simplest possible (discrete with bot); each cell is written once. The MVP is the architectural scaffolding on which the full Track 9 vision (incremental reduction with dependency-tracked invalidation) is later built.

**Output**: `(preduce expr) → expr` — drop-in replacement for `(nf expr)` over the supported subset. Outside the subset, falls back to the existing `nf` (graceful degradation during phased rollout).

---

## 2. Relationship to PM Track 9 (the full vision)

The Stage 1 doc (2026-03-21) sketches reduction-as-propagators with **dependency tracking** and **incremental invalidation** — when a meta resolves mid-elaboration, downstream reduction cells automatically recompute. That's the load-bearing motivation for Track 9: it eliminates the per-command memo cache staleness problem that Track 8 Part C creates.

**This MVP does NOT include incrementality.** The MVP runs reduction once, end-to-end, and produces the result. No subscription to dependency cells, no recomputation on change.

| Feature | PM Track 9 (full) | PReduce-MVP |
|---|---|---|
| Reduction implemented as propagators | ✓ | ✓ |
| One cell per reduction sub-result | ✓ | ✓ |
| Dependency tracking | ✓ | ✗ — deferred |
| Invalidation on meta resolve | ✓ | ✗ — deferred |
| E-graph / equality saturation | (open) | ✗ |
| Speculative reduction × ATMS | ✓ | ✗ — deferred |
| Tropical-lattice fuel | ✓ (per PPN 4C M2 lean) | ✗ — imperative counter for MVP |
| Replaces memo caches | ✓ | partial — caches still used as fallback |

**Why MVP first**: incrementality is non-trivial (dependency-set propagation through every reduction case) and not load-bearing for "execute a Prologos program." Landing the MVP gives us:
1. A working PReduce on a finite subset; validates the architectural shape
2. A test harness (differential vs `nf`) that becomes the regression gate for full Track 9
3. The Phase 1 cell-allocator helpers and discrete lattice that full Track 9 inherits and extends

The MVP is the foundation, not a competitor, of the full Track 9 vision. Naming is preserved ("PReduce") because the architectural shape (one-cell-per-sub-result, propagators implement reduction rules) is identical; only the dependency layer differs.

---

## 3. Scope

### In scope (MVP — Phase 1-7)

**~19 AST node kinds** sufficient to execute the simple Prologos programs the existing acceptance suite exercises:

| Group | Nodes |
|---|---|
| Literals | `expr-int`, `expr-true`, `expr-false`, `expr-nat-val`, `expr-zero`, `expr-suc`, `expr-unit`, `expr-nil` |
| Arithmetic | `expr-int-add`, `-sub`, `-mul`, `-div`, `-mod`, `-eq`, `-lt`, `-le` (with Nat→Int coercion baked into the fire-fn) |
| Variables | `expr-bvar` (de Bruijn), `expr-fvar` (top-level) |
| Functions | `expr-lam`, `expr-app` |
| Pairs | `expr-pair`, `expr-fst`, `expr-snd` |
| Eliminators | `expr-natrec`, `expr-boolrec`, `expr-J` (refl-only iota rule) |
| Annotation | `expr-ann` (erased) |
| Type-formers as opaque values | `expr-Pi`, `expr-Sigma`, `expr-Type`, `expr-Vec`, `expr-Eq`, `expr-Nat`, `expr-Int`, `expr-Bool`, `expr-Unit` — held as cell-init values; no propagator needed (they're values) |

### Out of scope (deferred)

Each deferred case has a target follow-on phase or track:

| Group | Target |
|---|---|
| **`expr-foreign-fn`** (Racket FFI; partial-app + NF-on-args + marshal + side effects) | **Phase 9** — needs its own design doc; non-trivial under BSP because (a) NF on args requires PReduce to also run in NF mode before marshalling, (b) `(apply proc rkt-args)` may have side effects which under BSP must fire exactly once per logical call, (c) marshal-in/marshal-out per-type discipline. The "simple" version (pure-functional, total foreign procs) is ~150 LOC. The full version touches I/O semantics. Defer cleanly. |
| Vec eliminators (`expr-vhead`, `expr-vtail`, `expr-vcons`, `expr-vnil`) | Phase 10 |
| Char/String/Keyword/Symbol/Path literals + ops | Phase 11 |
| Posit / Rat / Quire arithmetic | Phase 12 |
| `expr-reduce` (general pattern matching) | Phase 13 |
| Container types (`expr-PVec`, `expr-Map`, `expr-Set`, `expr-champ`) | Phase 14 |
| Generic / trait dispatch (`expr-generic-*`) | Phase 15 (gates on PPN 4C completion) |
| Logic engine surface (`expr-clause`, `expr-defr`, `expr-fact-block`, `expr-atms-*`) | Phase 16 |
| `expr-meta` (no metas; post-elaboration assumption) | n/a — MVP runs only on fully-elaborated AST |
| `expr-error` / `expr-hole` / `expr-typed-hole` | n/a — MVP errors on these (they shouldn't appear post-elaboration) |
| `expr-Open` / `expr-cumulative` | Phase 17 |
| `expr-Fin` / `expr-fsuc` / `expr-fzero` | Phase 10 |
| Incremental recomputation / dependency tracking | Track 9 full |
| Speculative reduction | Track 9 full + ATMS integration |
| E-graph / equality saturation | Track 9 full |
| Tropical-quantale fuel | PPN 4C M2 |

If `compile-expr` encounters an out-of-scope node, it raises a structured error and the caller falls back to `nf`. This is **graceful degradation**: PReduce handles what it handles; existing reducer covers the rest.

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

This is the simplest possible lattice; it's the moral equivalent of "uninitialized memory that, once written, stays." The MVP's correctness reduces to: every reduction rule's propagator writes the right value to its output cell.

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

**Termination**: imperative counter in the topology handler (per Q4 of kernel-PU doc — fuel is imperative for v1; lattice-cell fuel is post-MVP). Default ~10⁶ ops; configurable via `current-preduce-fuel` parameter.

**No CALM violation**: topology is the canonical strata for non-monotone structural changes. Same machinery as PAR Track 1, BSP-LE Track 2B, etc.

### 4.4 Termination

Three termination conditions:
1. **Quiescence**: all propagators fire to fixpoint, result cell holds a value. Normal case.
2. **Fuel exhaustion**: topology counter hits zero. Result cell remains ⊥; `preduce` raises an error (non-terminating program).
3. **Contradiction**: a cell merges to ⊤. Indicates a bug in the translation or the input program; `preduce` raises an error.

### 4.5 Entry / exit

The MVP runs in **closed-world mode**: the input expression has no free metas, no free fvars except those resolvable from the global definition table. This is the standard post-elaboration assumption.

For `expr-fvar` lookups, `compile-expr` consults the existing top-level definition table (the same one `nf` uses) and returns the cell-id of that definition's value. To avoid re-compiling the same definition multiple times, a per-`preduce` call cache: `defn-name → cell-id`.

---

## 5. Per-AST-node translation table

The complete MVP translation rules. `B` denotes the network builder (mutable), `env` is the bvar environment, `→ cid` denotes "returns the result cell-id."

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

### 5.8 Foreign functions — deferred from MVP

`expr-foreign-fn` is **out of MVP scope** (Phase 9 follow-on, see § 3 deferral table).

**Rationale**: foreign-fn handling in the existing reducer (`reduction.rkt:1456`) requires:
1. Per-arg accumulation across multiple β fires (each app adds one arg)
2. **Full normalization** (`nf`, not `whnf`) of all args before marshalling — meaning PReduce would need an NF mode for arg cells, not just WHNF
3. Marshalling Prologos values → Racket values per type (`marshal-in`)
4. Invocation via `(apply proc rkt-args)` — which may have side effects
5. Marshalling Racket result → Prologos value (`marshal-out`)
6. The result re-enters reduction (`(whnf prologos-result)`)

Items 1, 3, 5 are mechanically tractable. Items 2 and 4 are the real cost:
- **(2) NF mode**: PReduce-MVP ships WHNF; foreign-fn's NF requirement would force the NF infrastructure into MVP scope. Better to defer NF to its own phase where the design can address recursive descent through binders cleanly.
- **(4) Side effects**: `proc` may print, mutate, allocate. Under BSP, a propagator must fire exactly once per logical invocation (otherwise the side effect duplicates). Fire-once propagators handle this if the topology is right, but the design needs explicit treatment of "when does the side effect happen relative to the round" — and that interacts with future ATMS speculation (which might fire-then-retract a foreign call). Worth its own design.

**Workaround for MVP**: any program using `expr-foreign-fn` falls back to `nf` via the graceful-degradation path (§ 3 closing paragraph). The acceptance file (§ 8.1) is chosen to NOT exercise foreign-fn, so MVP coverage isn't compromised. Programs that DO need foreign-fn (e.g., `[int->string 42]`) still work — just via the existing reducer.

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

Per the workflow rule "NTT model REQUIRED for propagator designs." Speculative NTT for PReduce-MVP:

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

| NTT | Racket realization (MVP) | Future (full Track 9) |
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

### 8.1 Acceptance file (Phase 0)

`racket/prologos/examples/2026-05-02-preduce-mvp.prologos` — 7 small programs whose `nf` is known and whose AST stays within the MVP subset (no foreign-fn):

1. `def main := [int+ 2 3]` → `(expr-int 5)`
2. `def main := [if true 1 2]` → `(expr-int 1)`
3. `def main := <[+ 1 2]; [* 3 4]>` → pair of `(expr-int 3)` and `(expr-int 12)`
4. `def main := [fst <1; 2>]` → `(expr-int 1)`
5. `def main := fact 5` → `(expr-int 120)` (factorial via natrec)
6. `def main := fib 10` → `(expr-int 55)` (Fibonacci via natrec)
7. `def main := [sum 5]` → `(expr-int 15)` where `sum n = n + (n-1) + ... + 0` via natrec (avoids list/foreign-fn dependency)

Run `(preduce main-body)` and compare to `(nf main-body)`. Each phase unlocks specific entries: Phase 2 unlocks #1-4; Phase 5 unlocks #5-7.

### 8.2 Differential testing (Phase 7)

A property-based test: generate random closed Prologos terms over the supported subset (using `racket/random` + a small term generator). For each:
```racket
(define result-preduce (with-fuel default-fuel (preduce term)))
(define result-nf      (nf term))
(check-equal? result-preduce result-nf)
```

Target ~100 random cases. Bugs in `compile-expr` show as mismatches. The existing `nf` is the oracle.

### 8.3 Integration test (Phase 8)

Feature-flag-driven shim in `typing-core.rkt`:
```racket
(define (whnf-or-preduce e)
  (if (current-use-preduce?)
      (preduce-whnf e)
      (whnf e)))
```

Run the full test suite with `current-use-preduce?` set to `#t`. Expectation: all tests in the supported subset pass; tests exercising out-of-scope nodes fall back to `nf` via `compile-expr`'s graceful-degradation path.

If suite is green: Phase 8 PIR records "PReduce validated as drop-in alternative on supported subset."

If not green: each failure investigated individually; either (a) it's an MVP bug — fix; (b) it's an out-of-scope node not yet in graceful-degradation — add fallback.

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
  examples/2026-05-02-preduce-mvp.prologos  ; new, acceptance file
```

Existing files touched (small):
- `propagator.rkt` — register `preduce-value` domain
- `typing-core.rkt` — optional shim point if Phase 8 deploys

No changes to AST, elaborator, or the existing reducer. PReduce-MVP is purely additive.

---

## 10. Open questions

| # | Question | Resolution path |
|---|---|---|
| Q1 | Single shared network across multiple `preduce` calls within a command, or fresh per call? | Fresh per call for MVP (simplest). Sharing is an optimization; defer. |
| Q2 | When a defn is referenced multiple times via `expr-fvar`, do all references share one cell, or one per reference? | Share one cell (Phase 6 defn-cache). This gives function-level memoization for free. |
| Q3 | What about compiled body subnetworks for the *same* lambda applied to *different* args? | Each app instantiates a fresh body subnetwork. No body-sharing across calls. This trades memory for simplicity; e-graph sharing is full-Track-9. |
| Q4 | Does PReduce produce WHNF, NF, or a parameter? | Parameter `current-preduce-mode ∈ {whnf, nf}`. WHNF stops at the head; NF recursively reduces under binders. Phase 1 ships WHNF; NF is a thin recursive wrapper. |
| Q5 | Garbage collection of the network after `preduce` returns? | Racket GC. The network is a fresh `prop-network` struct; once `preduce` returns, the only reference is the result expr; the cells go away. |
| Q6 | Interaction with PPN 4C (elaboration-on-network)? | Orthogonal. PReduce runs *after* elaboration (post-meta-resolution). The two networks could merge later (full Track 9) but not for MVP. |
| Q7 | Performance vs `nf`? | Expected slower for the MVP — we're paying network overhead instead of direct recursion. Acceptable for the MVP's purpose (architectural validation, not perf). Phase 8 PIR records the gap; full Track 9's e-graph sharing will close it. |
| Q8 | How does PReduce handle programs that don't terminate under `nf` (currently caught by fuel)? | Same fuel mechanism via topology counter. A non-terminating program eventually exhausts and raises. |

---

## 11. Decision points to resolve before implementation

The user reviews this doc and answers:

1. **Naming**: ship as "PReduce" (consistent with Track 9) or "preduce-MVP" (explicit MVP scope)? My lean: filename `preduce.rkt` with module-level comment naming it as the MVP precursor to full Track 9.
2. **AST subset**: ~19-node core subset in § 3 (with `expr-foreign-fn` deferred to Phase 9; rationale in § 5.8) — confirm or override? Foreign-fn deferral is the principal scope cut: programs needing FFI (`int->string`, etc.) fall back to `nf` until Phase 9 lands.
3. **Phase ordering**: 0-8 as listed, or different sequencing? E.g., Phase 7 differential testing could be moved earlier as a per-phase gate.
4. **Validation strategy**: differential testing target — 100 random cases enough, or 1000? Property-based generator scope — closed terms only, or open terms with assumed-typed environments?
5. **Out-of-scope handling**: graceful degradation (fall back to `nf`) or hard error? My lean: graceful degradation for the rollout period; remove the fallback once coverage is complete.
6. **Sequencing relative to other tracks**: where does this land relative to PPN 4C, kernel PU, Sprint G? My read: PReduce-MVP is independent of all of them — runs purely on the existing Racket prop-network, no kernel work, no AST changes.

---

## 12. Adversarial framing (Vision Alignment Gate)

| Catalogue | Challenge |
|---|---|
| ✓ PReduce is on-network | Are env lookups on-network? — *Yes; bvars resolve to cell-ids from env, not racket parameters or hashes.* |
| ✓ Discrete value lattice is monotone | Is "first write wins" a real lattice or a lazy excuse? — *It's the simplest valid lattice (chain ⊥ → e → ⊤). The deeper question is whether we should use the e-graph lattice now and avoid the migration. Answer: e-graph requires equivalence merges (a × b = b × a) which is exactly the "optimization" the user said is out of MVP scope. Stay simple.* |
| ✓ Topology stratum for dynamic dispatch | Is this the canonical stratification, or are we reinventing it? — *Canonical; same machinery as PAR Track 1, BSP-LE Track 2B. No new stratum mechanism.* |
| ✓ Per-call fresh network | Is this scaffolding? — *Yes, named explicitly in Q1 + Q3 as deferred sharing optimization. Track 9 full will share across calls via subscription model.* |
| ✓ Imperative fuel (Q8) | "Imperative" — is this rationalization for off-network? — *Imperative for v1, named scaffolding. Tropical-quantale fuel cell from PPN 4C M2 is the v2 retirement target. Specific replacement, not "we'll get to it eventually."* |
| ✓ Graceful degradation to `nf` for out-of-scope nodes | Is this belt-and-suspenders? — *Yes — but bounded. Phase 8 PIR commits to removing fallback once coverage is complete. Not permanent dual-mechanism.* |
| ✓ Foreign-fn deferred from MVP | Is this a real deferral or rationalization? — *Real, with named target (Phase 9) and specific rationale (§ 5.8): NF-on-args requires NF mode in PReduce; side-effect semantics under BSP need explicit treatment. Programs using FFI fall back to `nf` until Phase 9. Acceptance file chosen to not exercise FFI so MVP coverage isn't compromised.* |
| ✓ Differential testing | Is the test methodology valid? — *Differential against `nf` is the strongest possible oracle (it's the existing implementation). The risk is `nf` having a bug that PReduce inherits — but that's a different class of bug (semantic, not architectural).* |

---

## 13. References

### PReduce / reduction-on-propagators

- [PM Track 9: Reduction as Propagators (Stage 1, 2026-03-21)](2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md) — origin
- [PPN 4C Design (2026-04-17)](2026-04-17_PPN_TRACK4C_DESIGN.md) — M2 mini-design lean: tropical-quantale fuel cell as PReduce template

### Architectural prerequisites

- [Stratification rule](../../.claude/rules/stratification.md) — canonical strata pattern; PReduce-MVP uses topology
- [Propagator design rule](../../.claude/rules/propagator-design.md) — fire-once, broadcast, set-latch
- [On-network rule](../../.claude/rules/on-network.md) — design mantra
- `racket/prologos/propagator.rkt:715–730` — `fork-prop-network` (not used by MVP but referenced for PU integration future)
- `racket/prologos/propagator.rkt:2441` — `register-stratum-handler!` (used by PReduce-MVP for topology)

### Code

- `racket/prologos/reduction.rkt` — current tree-walking reducer (oracle for differential testing)
- `racket/prologos/syntax.rkt` — AST node definitions

---

**End of design doc.**
