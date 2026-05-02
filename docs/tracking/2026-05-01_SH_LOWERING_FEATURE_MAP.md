# SH Lowering — Feature Map and Dependency Graph

**Created**: 2026-05-01
**Status**: Stage 0/1 — research synthesis. Maps the feature surface for "AST → propagator network" lowering, classifies every AST node, and shows the dependency graph between SH lowering, the current Racket reducer, PReduce, and PPN Track 4C.
**Origin**: User question 2026-05-01 — "I want to understand all the features required to run an arbitrary Prologos program, and what the dependency graph is for those parts."

## Thesis

The user's two-part decomposition of SH work is **correct but incomplete**:

- **Part 1**: AST → propagator network (lowering)
- **Part 2**: propagator network runtime (substrate)

The two parts are real and load-bearing. **Part 1 is the long pole** — its surface area is ~200 expr-* AST nodes against the language; we currently lower ~12. **Part 2 is small in concept** (cells, propagators, BSP, fire-fn dispatch, GC, threads) but has substantial sub-projects (memory management, native concurrency, FFI inversion).

But there is also a **hidden Part 0** that the SH master doc folds in but is worth surfacing: PReduce (Track 9). PReduce is *reduction* lifted on-network. It is **not** what our SH lowering is, despite the name overlap. It runs at a different stage of the pipeline. Conflating PReduce with SH lowering is the most common framing error.

## Two-axis decomposition (per SH_MASTER §66-86)

The SH series itself is structured around two axes:

| Axis | Retires | Stage | What it produces |
|---|---|---|---|
| **Axis 1** | Racket as **runtime** dependency | A → A.5 | Native binaries; deployed Prologos programs run without Racket. Compiler still in Racket. |
| **Axis 2** | Racket as **compile-time** dependency | A.5 → B → C | Compiler-in-Prologos; bootstrap verification. |

Our work this session — Sprints A–E.3 — is entirely **Axis 1**. The user's "Part 1 + Part 2" maps onto SH Tracks 2 + 4 (lowering + production substrate). PPN Track 4C and Track 9 are independent series that **feed into** Axis 1 but are not **OF** it.

## Architectural pipeline (current → target)

```
Source (.prologos)
  │
  ▼
WS-mode reader  ──► tree-parser ──► sexp form
                                      │
                                      ▼
                             parser ──► surface AST (surf-*)
                                      │
                                      ▼
                          elaborator ──► typed AST (expr-*)
                                      │
                          ┌───────────┼───────────┐
                          ▼           ▼           ▼
                    typing-core    REDUCTION   ZONK
                    (200 nodes)   (50 cases)  (~30 sites)
                          │           │           │
                          └───────────┴───────────┘
                                  │
                                  ▼
                         FULLY-ELABORATED AST  ◄── starting point for lowering
                                  │
                                  ▼
                       ast-to-low-pnet  ◄── SH Track 2 (this work; ~12/200 nodes)
                                  │
                                  ▼
                            Low-PNet IR
                                  │
                                  ▼
                          low-pnet-to-llvm  ◄── SH Track 2.C
                                  │
                                  ▼
                              LLVM IR
                                  │
                                  ▼
                              clang link
                                  │
                                  ▼
                       runtime/prologos-runtime.{zig,o}  ◄── SH Track 4 (Sprint B+C+E.1+E.2)
                                  │
                                  ▼
                          native binary (x86_64 ELF)
```

## Feature map: the 327 expr-* nodes vs what we handle

`syntax.rkt` defines 327 `expr-*` structs. The reducer handles ~200 (some are types, not values). The SH lowering handles ~12. Here's the breakdown by family:

### ✅ Lowered today (Sprint A–E.3)

| Family | AST nodes | What |
|---|---|---|
| Int | `expr-int` | i64 cell with literal init |
| Bool | `expr-true`, `expr-false` | i64 0/1 cell |
| Int arith | `expr-int-add`, `-sub`, `-mul`, `-div` | (2,1) propagator with kernel-int-* tag |
| Int cmp | `expr-int-eq`, `-lt`, `-le` | (2,1) propagator → Bool cell |
| Conditional | `expr-boolrec`, `expr-reduce` (2-arm Bool) | (3,1) `kernel-select` propagator |
| Annotation | `expr-ann` | strip wrapper |
| Bound vars | `expr-bvar` | env lookup |
| Let-binding | `expr-app` of `expr-lam` | translate arg → cell, push to env |
| Tail-rec defn | recognized via pattern match in `match-tail-rec` | feedback network with select gate |

### 🔵 Required for arbitrary Prologos but **not yet lowered**

Listed in rough dependency / effort order:

| Effort | Family | AST nodes | What's needed |
|---|---|---|---|
| ~0.5d | **Free vars / named call** | `expr-fvar` saturated app | Compile-time inlining via beta-reduction. Substitution already exists in `substitution.rkt`. Closes the gap from Sprint E.3 (today only tail-rec defns work; non-recursive helpers fail). |
| ~0.5d | **Negation / abs** | `expr-int-neg`, `expr-int-abs` | (1,1) propagators already exist in kernel; just need translator cases. |
| ~0.5d | **Mod / int-mod** | `expr-int-mod` | New (2,1) tag in kernel; trivial. |
| ~1d | **Nat type** | `expr-zero`, `expr-suc`, `expr-nat-val`, `expr-Nat` | Same i64 cell as Int with unsigned semantics. `expr-natrec` is the recursion eliminator — handle as compile-time unroll OR as iterate-while when target is variable. |
| ~2-3d | **Pairs / Sigma** | `expr-pair`, `expr-fst`, `expr-snd`, `expr-Sigma` | Build returns *list* of cell-ids per pair-typed expr. Generalizes `build` from `Cid` to `(Listof Cid)`. Unblocks structured iteration state. |
| ~2-3d | **General match** | `expr-reduce` with N arms of any binding-count | Multi-way select; per-constructor dispatch. Requires constructor-tag dispatch in the kernel. |
| ~1d | **Unit / Nil** | `expr-unit`, `expr-Unit`, `expr-nil`, `expr-Nil` | Trivial — cell with init=0 (or omit when erased). |
| ~3-5d | **Vectors / lists** | `expr-vnil`, `expr-vcons`, `expr-vhead`, `expr-vtail`, `expr-vindex`, `expr-Vec` | Heap-allocated runtime structure. Needs runtime alloc + GC interaction. |
| ~3-5d | **Posit family** (8/16/32/64) | `expr-posit*`, `expr-p*-add` etc. | Each shape needs full kernel arithmetic primitives. Substantial but parallel to Int. |
| ~3-5d | **Rational** | `expr-rat-*`, `expr-from-int` | Pair of i64 (num/denom). Builds on Sigma. |
| ~5d | **Strings / chars** | `expr-string-*` | Variable-length runtime data. Requires runtime alloc + UTF-8 handling. |
| ~5-10d | **Maps / Sets / PVecs** | `expr-map-*`, `expr-set-*`, `expr-pvec-*` | Persistent data structures (CHAMP/HAMT). The Zig HAMT (Track 6 stub) is the substrate; lowering needs to wire to it. |
| ~5d | **Generic arithmetic via traits** | `expr-generic-add`, `-sub`, `-mul`, etc. | Needs trait-resolution in the lowering OR a compile-time pass that resolves generic ops to monomorphic ones. Most natural: rely on elaborator's `resolve-trait-constraints!` to monomorphize before lowering. |
| ~10d | **First-class functions / closures** | `expr-lam` not at let-binding position | Heap closure cells. Needs runtime alloc + `apply` propagator that reads function cell + arg cells. Major lift — interacts with GC and possibly with runtime function-call infrastructure. |
| HARD | **Non-tail recursion** | recursive `expr-app` not in tail position | Conceptually requires runtime call stacks, fundamentally at odds with BSP-parallel model. Either (a) build classical fib via memoization (allocate one cell per `fib(k)` for k=0..n at compile time — same as our current unrolled form) or (b) introduce activation records. (a) only works for known-N. |
| ~5d | **Foreign calls** | `expr-foreign-fn` | (k,1) propagator that calls a host function. For native runtime: dlsym + symbol table. |
| HARD | **Effect / capability machinery** | `expr-effect-*`, `expr-cap-*` | Capabilities are typing-only at first; runtime depends on which effects are kept reified vs erased. Needs Track 5 (erasure boundary) decisions. |
| HARD | **Logic / solve / defr** | `expr-solve`, `expr-defr-*`, `expr-clause`, etc. | Logic-programming runtime with backtracking. Today implemented in metavar-store + relations on the elaborator network. Native version needs ATMS + scheduler ports. |
| HARD | **Session types** | `expr-session-*` | Channel runtime + protocol verification. Most of this is type-level (m0-erased). Runtime-relevant pieces: channel state, send/receive operations. |
| ~3d | **Holes / metas** | `expr-hole`, `expr-typed-hole`, `expr-meta` | At runtime: should not exist (must be solved during elaboration). Lowering should reject. Sprint E.3 already does this for `expr-fvar` unknowns. |
| HARD | **Union types / unification on values** | `expr-union`, `expr-unify-goal` | Logic-programming territory. Defer with logic. |

### ⚪ Type-level only (no runtime presence)

| Family | AST nodes | Note |
|---|---|---|
| Type formers | `expr-Type`, `expr-Pi`, `expr-Sigma`, `expr-Eq`, `expr-Vec`, etc. | Erased before lowering. If they appear, that's a bug. |
| Equality | `expr-refl`, `expr-J` | Erased (proofs). |
| Singletons | `expr-fzero`, `expr-fsuc`, `expr-Fin` | Erased or replaced with i64 indices. |

## The current reducer is feature-complete; SH lowering is not

The Racket reducer (`reduction.rkt:1340-3209`) handles **all 200 reducible AST nodes** across ~50 reduction cases. It implements:
- β-reduction (lambda app)
- ι-reduction (eliminators: natrec, boolrec, J)
- Projections (fst/snd, vhead/vtail)
- Trait dispatch (idx-nth on resolved dicts)
- Foreign function calls (with marshalling)
- Three memoization caches with cache-staleness handling
- Integer, posit, rational arithmetic

It is **complete for arbitrary Prologos**.

Our SH lowering handles ~12/327 nodes. Adding a node typically takes 0.5–3 days of focused work (the 8-file pipeline checklist plus the lowering case). Total estimated effort to reach feature parity with the reducer: **3–6 months** of continuous work, with the harder items (closures, effects, logic) representing genuine architectural research.

This is **expected and not alarming**. The reducer evaluates symbolically; lowering produces an executable network. They have different shapes and different constraints. Equivalent feature parity is a long arc. The MVP path (Sprints A-E + the small follow-ups) is the **80% of the language that 80% of programs use**.

## How SH lowering relates to PReduce, PPN 4C, and others

### PReduce (PPN/PRN cross-series, Track 9)

**Goal**: Make REDUCTION incremental and on-network. Each reduction result becomes a cell; a propagator recomputes when the input expression's dependency cells change. Replaces today's per-phase memo cache (which has staleness issues — see `2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md`).

**Relationship to SH lowering**:
- **Different stage of pipeline**. PReduce operates on AST during the elaborator's reduce phase. SH lowering operates AFTER elaboration is complete.
- **Different output**. PReduce produces *another AST* (the reduced form). SH lowering produces a *low-pnet structure* (cells + propagators + LLVM IR).
- **Different consumer**. PReduce's output feeds back into typing-core, zonk, elaborator. SH lowering's output feeds clang.
- **Pipeline order**: PReduce runs DURING elaboration (potentially many times); SH lowering runs ONCE on the post-elaboration result.

**Could SH lowering reuse PReduce ideas?** Partially. The cell-as-cache-of-result idea applies if we ever need *runtime* incremental recomputation (e.g. interactive REPL with dependency-tracked recomputation). Not needed for AOT compilation.

### PPN Track 4C (compiler IS the network)

**Goal**: Lift type checking + elaboration onto the propagator network. 5 facet lattices (`:type`, `:context`, `:usage`, `:constraints`, `:warnings`) per AST node. Inference rules become propagators. Today's CHAMP storage and zonk tree-walks dissolve into on-network equivalents.

**Relationship to SH lowering**:
- **Different problem**. PPN 4C makes the COMPILER a network. SH lowering makes the COMPILED PROGRAM a network.
- **Sequential dependency** for self-hosting (axis 2). PPN 4C must complete before Track 9 (compiler-in-Prologos) makes sense.
- **No direct dependency** for axis 1 (which is what we're working on). The Racket-hosted compiler can produce post-elaboration ASTs whether elaboration is on-network or imperative.

**Could SH lowering reuse PPN 4C ideas?** Yes, indirectly:
- The 5-facet attribute model could inform what *survives* elaboration into the lowering input.
- PPN 4C's stratification + dispatch infrastructure parallels what runtime BSP needs.
- But there's no shared code path today.

### NTT (Network Type Theory / propagator-as-syntax)

**Goal**: First-class `propagator` declarations in source syntax (NOT just for AST evaluation). Users write propagator topology directly.

**Relationship to SH lowering**:
- **Adjacent**. NTT and SH lowering both produce networks, but from different sources (NTT from user-written `propagator` forms, SH lowering from elaborated AST).
- **Could share back-end**. Once Low-PNet IR is the common target, NTT's compiled form and SH lowering's compiled form are the same shape.
- **NTT may eventually replace some SH lowering work**. If a user writes their iterative-fib as a NTT propagator declaration directly, the recognizer in `match-tail-rec` becomes redundant for that program.

### SRE (Structural Reasoning Engine)

**Goal**: Lattice operations, form registry, structural unification.

**Relationship to SH lowering**: SRE is a *runtime* concern (Part 2), not a lowering concern (Part 1). Once compiled programs use SRE primitives, the runtime substrate (Track 4) must include SRE.

### BSP-LE Track 2B (BSP scheduler)

**Goal**: Bulk-synchronous parallel scheduler for the propagator network.

**Relationship to SH lowering**: BSP-LE is the spec our **runtime** (Sprint B) implements. We've already done the native port. BSP-LE the design + the Sprint B implementation = our Part 2's scheduler.

## Dependency graph (compact)

```
                   ┌─────────────────────────┐
                   │   Source .prologos       │
                   └────────────┬────────────┘
                                │
                                ▼
        ┌─────────────────────────────────────────────────┐
        │   Racket-hosted compiler (parser, elaborator,   │
        │   typing-core, reducer, zonk)                   │
        │                                                 │
        │   ◄── PPN 4C optional (typing-on-network)       │
        │   ◄── PReduce optional (reduction-on-network)   │
        └────────────┬────────────────────────────────────┘
                     │ post-elaboration AST
                     ▼
        ┌─────────────────────────────────────────────────┐
        │   PART 1: AST → low-pnet                         │
        │   (this work — SH Track 2)                       │
        │                                                  │
        │   Lowering surface: 12/200 today;                │
        │   target: 80% of language for typical programs.  │
        │                                                  │
        │   Per-AST-node work: 0.5–3 days each.            │
        │   ◄── Shares: type erasure boundary (Track 5)    │
        │   ◄── Adjacent: NTT (user-written propagators)   │
        └────────────┬────────────────────────────────────┘
                     │ low-pnet IR
                     ▼
        ┌─────────────────────────────────────────────────┐
        │   low-pnet → LLVM IR (Track 2.C)                 │
        │                                                  │
        │   Tag-based fire-fn dispatch.                    │
        │   ◄── Tags must match runtime's switch.          │
        └────────────┬────────────────────────────────────┘
                     │ LLVM IR
                     ▼
        ┌─────────────────────────────────────────────────┐
        │   PART 2: native runtime (Track 4)               │
        │                                                  │
        │   Subparts:                                      │
        │   - Cells + propagator install (Sprint A) ✅     │
        │   - BSP scheduler (Sprint B) ✅                  │
        │   - Instrumentation (Sprint C) ✅                │
        │   - Feedback / cyclic (Sprint E.1) ✅            │
        │   - GC                          ❌ (Track 6)     │
        │   - Concurrency / threads       ❌ (Track 6)     │
        │   - I/O via FFI inversion       ❌ (Track 7)     │
        │   - HAMT/CHAMP runtime          ⚠️ (Track 6)     │
        │   - SRE form registry           ❌ (later)       │
        │   - ATMS speculation            ❌ (later)       │
        │   - Logic engine                ❌ (Sprint F+)   │
        │                                                  │
        │   The "atomic substrate" is small.               │
        │   Each persistent data structure or runtime      │
        │   service is its own sub-project.                │
        └─────────────────────────────────────────────────┘
```

## Where most of the work is

**By node count**: Part 1 (lowering) is the long pole. 200 expr-* nodes to handle vs maybe 10 runtime sub-systems.

**By difficulty**: Mixed.
- *Easy lowering, easy runtime*: Int arithmetic, comparisons, conditionals. (Sprints A-E.3)
- *Easy lowering, complex runtime*: HAMT/CHAMP, GC. The structures are small; GC integration is large.
- *Complex lowering, easy runtime*: traits/dispatch (compile-time monomorphization), pair lowering. The runtime barely changes; the lowering needs Sigma-typed cells.
- *Complex lowering AND complex runtime*: closures, effects, logic. These need both new lowering AND new runtime services.

**By calendar time**: roughly 60-70% of remaining work in Part 1 (lowering surface), 30-40% in Part 2 (runtime sub-systems). Part 2 has fewer items but each item is bigger.

## Recommended next moves (ordered by ROI)

1. **Sprint F.1 — non-recursive function inlining** (~0.5d). Closes the immediate `function call not supported` error for helper functions. High user-visible impact, trivial implementation.
2. **Sprint F.2 — Pair / Sigma lowering** (~2-3d). Generalizes `build` to return cell-id lists. Unblocks structured state, multi-return values, the foundation for `iterate-while` with compound state.
3. **Sprint F.3 — Nat + natrec + iterate-while** (~2d, depends on F.2). Handles Peano-style iteration cleanly. Combine with the existing tail-rec lowering for two paths into the same feedback network.
4. **Sprint F.4 — General match (multi-arm with binders)** (~2-3d). Enables pattern matching on sum types (Maybe, Either, etc).
5. **Sprint G — runtime services bootstrap**. Starts on Track 6 (GC + thread pool). Needed before any heap-allocated data (lists, maps, closures) can land in lowering.

After F.1–F.4, lowering covers ~30 of 200 AST nodes — roughly the "first-order functional core" of Prologos. After G, the runtime is ready for heap structures. Together they cover an estimated **70%+ of typical user programs**.

## What this design doc settles vs leaves open

**Settles**:
- Two-part decomposition is correct for axis 1.
- Most calendar work in Part 1; Part 2 has fewer items but each one larger.
- PReduce, PPN 4C, NTT are NOT what SH lowering is. They are adjacent or upstream pieces.
- Feature parity with the reducer is a 3–6 month arc.

**Leaves open**:
- How to handle non-tail recursion. Current options (memoization at compile time = unrolled; activation records = breaks BSP) both have drawbacks. Possibly never needs solving if user code uses tail-rec or iterate-while.
- Closure runtime. Open until we have a heap + GC.
- Logic/solve runtime. Major sub-project; defer to Sprint H+ once the functional core lands.
- When SH lowering should optionally use PReduce as a sub-pass (e.g. constant fold step expressions before lowering). Not needed yet; revisit when we have benchmarks where compile-time precomputation matters.

## References

- `racket/prologos/reduction.rkt:1340-3209` — current reducer feature surface
- `racket/prologos/typing-core.rkt:397-1450` — type checker surface
- `racket/prologos/syntax.rkt` — 327 expr-* node definitions
- `racket/prologos/ast-to-low-pnet.rkt:130-535` — current SH lowering (12 of 200 nodes)
- `docs/tracking/2026-04-30_SH_MASTER.md` — overall SH series + two-axis retirement
- `docs/tracking/2026-03-21_TRACK9_REDUCTION_AS_PROPAGATORS.md` — PReduce design (referenced; verify path)
- `docs/tracking/2026-04-17_PPN_TRACK4C_DESIGN.md` — typing-on-network (axis 2 prerequisite)
- `docs/tracking/2026-05-01_BSP_NATIVE_SCHEDULER.md` — Sprint B+C runtime scheduler write-up
- `runtime/prologos-runtime.zig` — Part 2 substrate (~520 lines today)
- `runtime/test-bsp-feedback.c` — kernel-level BSP feedback validation
