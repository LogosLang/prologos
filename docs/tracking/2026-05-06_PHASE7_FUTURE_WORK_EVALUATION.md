# Phase 7+ Future Work — Code-Size Contribution Estimates

**Date**: 2026-05-06
**Context**: With Fix C, int-mod migration, and the bot-guard fix landed,
the hybrid kernel is BSP-correct and the int-binary cluster is complete.
This doc evaluates the remaining migration targets identified in
`2026-05-05_HYBRID_PHASE7_MIGRATION_DATA.md` and estimates how much
each will add (or remove) on each side of the Racket↔Zig boundary, with
rationale.

## Current baselines

| layer | file | LOC |
|---|---|---:|
| Zig kernel | `runtime/prologos-runtime-hybrid.zig` | 695 |
| Zig core | `runtime/core/cells.zig` | 102 |
| Zig profile | `runtime/core/profile.zig` | 116 |
| **Zig total** | | **913** |
| Racket reducer | `racket/prologos/preduce.rkt` | 1522 |
| Racket backend (hybrid) | `preduce-backend-hybrid.rkt` | 243 |
| Racket backend (racket) | `preduce-backend-racket.rkt` | 101 |
| Racket core | `preduce-core.rkt` | 165 |
| Racket FFI bridge | `runtime-bridge.rkt` | 316 |
| **Racket total** | | **2347** |

## Summary table

Estimates are per-track NET LOC delta — what gets added on each side
minus what's retired. ROI is "callback-time fraction in the workload
battery that this track expects to absorb to native". "Risk" weights the
likelihood that the actual delta exceeds the estimate.

| # | track | Zig Δ | Racket Δ | ROI (cb-time absorbed) | risk | prereq |
|---|---|---:|---:|---:|---|---|
| 5 | `expr-boolrec` → kernel_select | +0 | +30 | ~4% | low | none |
| 6 | ~~int-mod migration~~ | ~~done~~ | ~~done~~ | ~~~1%~~ | ~~done~~ | done |
| 4 | ctor-N native ABI | +400 | +200 / -100 | ~5% (workload), ~50% (OCapN-style) | medium-high | ABI design pass |
| 3 | `expr-reduce` match dispatch | +200 | +200 / -150 | ~10% | medium | #4 (ctor tags) |
| 2 | `expr-natrec` step | +150 | +50 / -30 | ~5% (effective; ~17% theoretical) | medium | #1 |
| 1 | recursive `expr-fvar` + `expr-app` | +1000 | +400 / -200 | ~60% | high | design pass; closure ABI |
| 7 | CHAMP collection ops | +5000+ | +500 / -200 | ~4% (synthetic; unknown for real workloads) | high | invasive new data structure |

## Per-track rationale

### #5 — `expr-boolrec` → `kernel_select` (free win)

**Zig: +0 LOC.** `kernel_select` already exists at shape-3 tag 0 (it's
the Phase 9b boolrec primitive that was registered but never routed
from preduce.rkt). Verified at `runtime/prologos-runtime-hybrid.zig:235`.

**Racket: +30 LOC.** Add `'select` to NATIVE-OP-TAGS for shape-3
dispatch (or add a parallel SHAPE_3_NATIVE_TAGS hash) and update the
expr-boolrec compile case (`preduce.rkt:599`) to install at shape 3 +
tag 0 with `#:native-op 'select`. Plus a `eager-compile-arm` helper to
ensure `tc` and `fc` arm bodies compile to cells eagerly (currently
they may compile lazily inside make-boolrec-fire's callback).

**Why this size**: Zig: kernel already has the function. Racket:
boolrec has 21 LOC currently; the migration adds an arms-eager-compile
step (~30 LOC) and changes the install call. The current callback
fire-fn (`make-boolrec-fire`) can be retired (~20 LOC saved). Net
small gain.

**Caveat**: shape-3 dispatch routing through `#:native-op` doesn't
currently exist (the `NATIVE-OP-TAGS` hash maps symbol → tag with no
shape hint, and `install-fire-once` always uses shape from `n-inputs`
which boolrec already passes correctly). Just wire it.

### #4 — ctor-N native ABI (moderate; load-bearing for #3)

**Zig: +400 LOC.** Three sub-pieces:
1. **Tagged-tuple cell representation** (~150 LOC). Two ABI options:
   (a) heap-allocated struct pointed to by a TAG_HANDLE cell, or
   (b) extend boxed-i64 to allow `(ctor-tag, 4-bit-arity, 4×12-bit field-cids)` for the arity-≤4 fast-path + heap fallback. Option (b)
   captures the OCapN-common arity-1..4 ctors without heap allocation.
2. **Native ctor-build primitive** (~100 LOC). 1-input, 2-input,
   3-input, N-input variants that read field cells, build the tagged
   tuple, write to output. Mostly mechanical.
3. **Native ctor-tag read primitive** (~50 LOC). Used by match
   dispatch. Reads the cell's ctor-tag without allocating.
4. **Allocator + lifecycle** (~100 LOC). If heap-backed, kernel needs
   a small bump-allocator for tagged tuples. Reset on
   `prologos_kernel_reset`.

**Racket: +200 LOC, retire ~100 LOC.** Three pieces:
1. **ABI-side bridge** (~80 LOC). Adapt `box-prologos-value` /
   `unbox-prologos-value` to recognize the new TAG_USER_CTOR or
   TAG_HANDLE-with-ctor-payload representation. Map ctor short-name
   ↔ ctor-tag-id at registration time.
2. **compile-expr ctor-app dispatch** (~80 LOC). Replace
   `preduce.rkt`'s `alloc-value-cell` for ctor application with
   native ctor-build install. Touches the user-ctor compile path
   (currently allocates a `preduce-user-ctor` Racket struct).
3. **classify-builtin-ctor adaptation** (~40 LOC). Update the
   `preduce-user-ctor?` branch in `classify-builtin-ctor` to read the
   native tagged-tuple representation. Currently reads
   `preduce-user-ctor-short-name` and `preduce-user-ctor-field-cids`
   from a Racket struct.
4. **Retire `preduce-user-ctor` struct** (-100 LOC). The struct +
   accessors + match clauses across `preduce.rkt` / `syntax.rkt`.

**Why this size**: ctor representation IS an ABI. The fixed encoding
of `(tag, fields...)` is compact but every consumer (compile-expr,
match dispatch, profiling, debugging) needs to know about it.
Heap-backed implementation is mechanically small (100-200 LOC); the
boxed-i64 bit-twiddling fast path is what pushes the kernel side
toward 400. The Racket side gains a bridge but retires the
preduce-user-ctor struct entirely (net Racket gain is small).

**Why ROI is workload-dependent**: in OCapN-style data-construction
workloads, ctor-N is ~50% of cb time (per the original Phase 7 doc).
In the broader workload battery (W1..W15), it's ~5% — recursion +
match dispatch dominate there. Migration ROI scales with workload
mix.

**Why "medium-high" risk**: the ABI design is the load-bearing
piece. Get it wrong and you re-architect twice. Heap-backed ABI is
safer (less constraining) but adds GC concerns. Boxed-i64 fast path
is faster but constrains arity to ≤4 fields (which IS what current
ctors mostly are, but Phase 10b's CapTPOp.op-deliver is exactly 4).

### #3 — `expr-reduce` match dispatch (depends on #4)

**Zig: +200 LOC.** Two sub-pieces:
1. **Native discriminator primitive** (~80 LOC). Reads scrutinee
   ctor-tag, writes to a "winner" cell holding the matching arm
   index. 1-input, 1-output.
2. **Per-arm gated identity-bridge** (~80 LOC). Already similar to
   kernel_identity, but reads the winner cell + the arm-cell + writes
   to the result cell only when winner matches. Each match installs
   N of these (one per arm).
3. **Arm-tag registration** (~40 LOC). At install time, register
   "this arm wins for ctor-tag X" — kernel-side mapping.

**Racket: +200 LOC, retire ~150 LOC.** Two pieces:
1. **Eager arm compilation** (~120 LOC). expr-reduce compile case
   (`preduce.rkt:688`) currently calls `compile-and-bridge` LAZILY
   inside `make-reduce-fire`'s callback (after the scrutinee
   resolves). Native dispatch can't do that — arms must be
   pre-compiled at install time. This eagerification touches
   `compile-and-bridge` and the binder-environment threading
   (each arm's bvars need fresh bindings).
2. **Discriminator + bridge install glue** (~80 LOC). Replace
   `make-reduce-fire`'s callback install with: install discriminator
   + N gated bridges.
3. **Retire `make-reduce-fire`** (-150 LOC). The callback +
   `classify-builtin-ctor` shrink to just "read ctor-tag" since the
   matching is kernel-side.

**Why this size**: match dispatch is structurally just
"discrimination + N identity bridges". The discriminator is small
once ctor-N is native (it just reads the cell's ctor-tag — no
need to dispatch on Racket-struct accessors). The Racket side gains
eager arm compilation (which is a real semantic shift — must
fix any lazy-arm-compilation tests).

**Why prerequisite #4**: the discriminator reads the scrutinee's
ctor-tag from the kernel-side representation. Without #4, ctors
are Racket structs (`preduce-user-ctor`) and the kernel can't
inspect them. Doing #3 before #4 means re-doing the discriminator
in Racket as a callback, which doesn't migrate to native cleanly.

### #2 — `expr-natrec` step (effective ROI lower than theoretical)

**Zig: +150 LOC.** One piece:
1. **Native natrec iterator** (~150 LOC). 4-input (motive, base,
   step, target), 1-output. The fire-fn unrolls `target` (a Nat) to
   call `step` repeatedly with the running accumulator. The catch:
   `step` is itself a closure that takes 2 args and returns 1.

**Racket: +50 LOC, retire ~30 LOC.** Mostly the install-time
glue + retire `make-natrec-fire` callback.

**Why effective ROI is ~5% not 17%**: the `step` closure is usually a
defn-call, which is callback-bound. Each iteration does a kernel→
Racket→kernel hop. FFI overhead per hop is ~115 ns (per the
hybrid PIR's calibration). For 100-iteration natrecs (e.g.,
`sum-down 100`), that's 11.5 µs of FFI overhead VS the iteration
loop. If the loop driver itself (Racket-side compile-and-bridge per
iteration) currently costs ~5 µs/iter, native saves only ~30% —
hence ~5% effective ROI. The full 17% requires #1 (native call
apparatus to retire the FFI hop per step).

**Why "medium" risk**: well-defined construct (motive, base, step,
target are typed) but the step closure ABI is the same problem
as #1.

### #1 — Recursive `expr-fvar` + `expr-app` (the big architectural piece)

**Zig: +1000 LOC.** Five sub-pieces:
1. **Closure cell representation** (~200 LOC). A closure value
   carries (function-pointer-or-tag, captured-env-cell-ids[]).
   Represented via TAG_HANDLE pointing to a heap-allocated struct.
2. **`apply` primitive** (~250 LOC). Reads the closure cell, reads N
   arg cells, builds the new env frame, calls the function. The
   "calls the function" step needs to install fresh per-call cells
   for the body's free-vars-in-env, which is dynamic — a key
   architectural shift from current static-unfolding.
3. **Stack/trampoline for recursion** (~250 LOC). The kernel can't
   easily recurse via real call frames (BSP scheduler doesn't
   support that). Trampoline via a continuation-cell that holds the
   "next call to execute" — the BSP scheduler fires it like any
   propagator.
4. **Recursion-depth guard / fuel** (~50 LOC). Without the static-
   unfolding compile-time termination, runtime recursion needs an
   explicit fuel counter to avoid runaway.
5. **Tail-call detection** (~250 LOC). Without TCO, deeply-recursive
   programs blow the trampoline. Compile-expr can mark a tail call,
   and the apply primitive can reuse the current frame.

**Racket: +400 LOC, retire ~200 LOC.** Three pieces:
1. **expr-lam compile case** (~150 LOC). Rewrite to construct a
   closure cell with the captured free-vars (currently there's a
   `(define (statically-reducible-lam f) ...)` path that's static-
   only).
2. **expr-app compile case** (~150 LOC). Currently does β at
   compile time; new flow installs an apply propagator with the
   closure + arg cells.
3. **expr-fvar compile case** (~100 LOC). Resolve to a closure
   value cell instead of inlining the body.
4. **Retire static-β unfolding** (-200 LOC). The current
   compile-time unfolding via `compile-expr inner env net` for
   recursive defns + the `statically-reducible-lam` machinery in
   `preduce.rkt:747+`.

**Why this size**: closures + apply + recursion is the most
fundamental construct in the language. Currently the
"static-unfolding" approach takes the easy path (compile-time
β-reduction terminates because of fuel/fixpoint), but it
allocates fresh propagators per recursive call site, exhausting
the tag pool at modest N (W14 prime-count at N≥7 was the
trigger for the tag-pool bump). Native call apparatus removes
this scaling problem — installs ONE propagator per defn, calls
at runtime.

**Why "high" risk**: this re-architects how recursion compiles.
Current preduce-lite tests assume static-unfoldable defns. The
shift breaks any test that depends on a specific compiled-cell
count. Static β collapses simple programs to literals (B1, B2,
H1, J1, J2 from the shape battery have ZERO runtime fires —
they're fully β-reduced). Native call apparatus would replace
that with runtime apply, costing those programs more rounds.

**What it enables**: 60% of cb time across the workload battery
moves to native. Recursive defns scale with depth not total call
count. Tag pool no longer exhausts on recursion.

**Prereq**: needs a separate design doc. Closure ABI, env
representation, recursion bound semantics, tail-call rules — none
of these are decided.

### #7 — CHAMP collection ops (poor ROI; defer)

**Zig: +5000+ LOC.** Implementing CHAMP (persistent hash array
mapped trie) and RRB-vector in Zig. Multi-week project.

**Racket: +500 LOC bridge, retire ~200 LOC** of compile-map-* /
compile-set-* / compile-pvec-* callbacks (which currently delegate
to `prologos::core::map`'s Racket implementation).

**Why poor ROI**: collection ops are ~4% of cb time across the
workload battery. The OCapN battery uses syrup-list (a user-defined
List-like ctor) not CHAMP-Map. CHAMP is heavily used in the
elaborator (immutable persistent structures across speculation) but
not in user-facing programs through preduce. The kernel-native
implementation pays huge fixed costs (CHAMP from scratch, RRB,
hash-cons, …) for a small workload-time win.

**When to revisit**: if a real workload (e.g., compiler self-hosting
phase) becomes collection-heavy, re-evaluate. Until then, callback-
delegate-to-Racket is fine.

## Combined LOC delta if all of #1–#5 land

- **Zig: +1750 LOC** (913 → ~2660). ~3× growth. Closures + ctors +
  match dispatcher + natrec + boolrec.
- **Racket: -50 LOC NET** (preduce.rkt: ~1520 → ~1470). Static-
  unfolding code retires; eager-compilation glue replaces it. The
  surface complexity migrates to Zig.

(#7 not included — defer until workload justifies.)

## Suggested ordering

### Path A — biggest payoff first

1. **#5 boolrec** (cheap warm-up; validates shape-3 native routing).
2. **#4 ctor-N** (load-bearing ABI; needed for #3).
3. **#3 match dispatch** (depends on #4).
4. **#1 recursive call apparatus** (biggest piece; benefits from
   stable ctor-N + match-dispatch foundations).
5. **#2 natrec** (effective ROI requires #1 first).

### Path B — incremental ROI

1. **#5 boolrec** (cheap).
2. **#4 ctor-N** (heavy lift but unblocks #3).
3. **#3 match dispatch** + **#2 natrec** (parallel; both depend on #4
   and #1's eventual closure ABI but can be done with stub closures
   that delegate to Racket for now).
4. **#1 recursive call apparatus** (last; replaces the stubs).

### Path C — value-engineering minimum

1. **#5 boolrec** (free).
2. **#4 ctor-N**, but only the ABI design + heap-backed
   representation. Skip the boxed-i64 fast path (saves ~150 Zig
   LOC).
3. **#3 match dispatch** with the simplified ctor-N.
4. STOP — re-measure. If natrec / call apparatus still dominate,
   continue. If the shape of cb time has shifted, re-evaluate.

## Open questions for design pass before starting any of #1–#4

1. **ctor-N ABI**: heap-allocated tagged tuple (TAG_HANDLE) or
   bit-packed (TAG_USER + arity + 12-bit field cids)? The latter
   limits arity ≤ 4 but avoids heap allocation. OCapN's largest
   ctor is op-deliver at arity 4 — fits exactly. Phase 10+
   user-defined ctors might exceed 4. Spec'ing both with a
   selector at install time is feasible but doubles the kernel
   surface area.

2. **Closure representation**: Racket-style flat-env vs De Bruijn
   stack vs explicit env-cells? Current static-unfolding doesn't
   need a runtime env representation; native call needs one.

3. **Tail-call semantics**: optional optimization or required for
   correctness (deep recursion blows the trampoline)? In Prologos's
   target programs (compiler self-hosting), recursion depth could
   easily exceed any non-TCO budget.

4. **Eager arm compilation** (for #3): does it break programs that
   rely on arm bodies being compiled per-call? E.g., a recursive
   defn whose arm body re-references itself with different bvars
   currently compiles fresh cells per visit. Eager compilation
   means ONE compiled cell that uses runtime args. This requires
   #1 to be done first OR a "stub closure" form for recursive
   bodies in match arms.

5. **Bot-guard convention**: now that native fire-fns guard
   against TAG_BOT, should the protocol be formalized? E.g., a
   `kernel_fire_fn_protocol` doc that enumerates the contract:
   inputs may be bot, outputs must be bot if any input is bot,
   etc. Currently it's spread across the make-int-binary-fire
   comment + my recent commit's commit message.

## What this analysis does NOT settle

- **Whether #1 is feasible at all without losing the static-β
  benefits**. B1, B2, H1, J1, J2 from the shape battery do ZERO
  runtime fires today because static β eats them. Migration to
  runtime apply means they cost more rounds. If we keep BOTH
  static-β AND native-apply (compile-time decision: apply if
  dynamic, β if static), Racket-side complexity grows.

- **The actual per-fire cost of native call apparatus**. The hybrid
  PIR § Appendix A measured ~115 ns/fire for native, ~4100 ns/fire
  for callback. Native call apparatus is in between — depends on
  closure-allocation cost, env-frame setup, fuel-check overhead.
  Until we prototype, we don't know if the migration delivers the
  "60% of cb time" payoff.

- **Whether #1+#2+#3 should land as ONE track or three**. They're
  architecturally coupled: ctor-N + match dispatch + apply each
  reference each other (apply needs to handle ctor-fields-as-args,
  match dispatcher reads ctor tags, etc.). Landing them
  independently means a stub-laden middle state. Landing them as
  one is a multi-week project.
