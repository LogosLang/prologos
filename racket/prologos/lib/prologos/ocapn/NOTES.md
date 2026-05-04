# OCapN compatibility targets

This directory holds a **subset** of the upstream OCapN (Object-Capability
Network) port from PR #28
(`LogosLang/prologos` branch `claude/ocapn-prologos-implementation-auLxZ`,
imported 2026-05-04). The full upstream port includes ~14 library modules
and ~16 test files; what's checked in here is the slice that exercises
specific compatibility targets for the current branch's PReduce-lite +
hybrid Zig kernel work.

## Parallel-branch coordination

Branch `claude/ocapn-prologos-implementation-auLxZ` is iterating in
parallel, building out more of the OCapN implementation upstream. **This
branch's role is different**: we use OCapN as a stress-testing ground for
the reducer + kernel, pulling files in to validate Phase 10b coverage and
to drive OCapN-shape workloads through the hybrid kernel.

When the upstream branch lands a new module:
- If it's Tier A (type-only) or Tier B (data + match), consider pulling
  it as a compatibility target — it will exercise more of preduce.rkt's
  AST surface on the kernel.
- If it's Tier C (FFI / wire codecs) or Tier D (trait dispatch), defer
  until the relevant reducer phase lands.

Periodic re-sync: when a meaningful upstream batch lands, copy the
new lib + test files here under the existing tier classification.

## Tier classification

The upstream OCapN port stresses different language features at different
levels. We classify the brought-in files into compatibility tiers based on
what they need from the reducer.

### Tier A — type-level only (runs today)

**Files**: `refr.prologos`

**What it uses**: `capability` declarations + `subtype` edges. No value-level
reduction; pure registry population during elaboration.

**Status**: ✅ Elaborates cleanly on this branch. `tests/test-ocapn-refr.rkt`
passes (6 test cases).

### Tier B — landed under PReduce-lite Phase 10b (and `nf` from day one)

**Files**: `syrup.prologos`, `promise.prologos`, `message.prologos`

**What they use**: `data` declarations with multiple constructors and
per-constructor `match` clauses (predicates, selectors, smart constructors,
state transitions). The `match` reduction dispatches over USER-DEFINED
constructors (e.g., `pst-unresolved`, `syrup-tagged`, `op-deliver`).

**Status**: ✅ Both reducers handle these.
  - The production reducer `nf` (reduction.rkt) has supported user-defined
    ctors since day one via `try-structural-reduce` — `tests/test-ocapn-syrup.rkt`
    has been green from the moment it was checked in.
  - PReduce-lite Phase 10b (preduce.rkt, 2026-05-04) added the matching
    dispatch for `eval` paths that opt into PReduce-lite via
    `current-use-preduce?`. Validated by `tests/test-preduce-phase10b.rkt`
    (12 tests covering nullary/unary/binary/ternary user ctors + arm
    dispatch + field extraction + nf differential).

**Stress shapes** for Phase 10b implementation:
- `syrup.prologos` — 10 constructors with mixed arities (0, 1, 2). Predicates
  spell out every ctor (no wildcards) per goblin-pitfalls #2.
- `promise.prologos` — 3 constructors + monotone state transitions
  (multi-arg match clauses pattern-matching on TWO constructors at once:
  `| reason [pst-unresolved _] -> ...`).
- `message.prologos` — ARITY-4 constructor `op-deliver`, plus 6 other
  constructors of various arities. The arity-4 case is the hardest test
  for the PReduce-lite Phase 10b implementation (most ctors are 0–2 args).

### Tier C — permanently outside PReduce-lite scope

Not brought in (they would require FFI or kernel features we deliberately
deferred):

- `tcp-testing.prologos` — uses `foreign-fn`. Skipped from PReduce-lite
  per user direction; would block on Phase 9 (FFI), which is out of scope.
- `syrup-wire.prologos` — bytewise encode/decode. Phase 9 + a primitive
  byte-string type. Has the **pitfall #27** 270s decode pathology — a
  candidate strategic benchmark target for the hybrid Zig kernel's HOF
  substitution speedup.

### Tier D / E — not yet imported

The upstream port also has:
- `locator.prologos`, `behavior.prologos`, `vat.prologos`, `core.prologos` —
  Tier B (need Phase 10b) but larger and not currently a compatibility
  target. Add as needed.
- `ocapn-eigentrust.prologos` and friends — exercise trait dispatch +
  open-world matching; classified Tier D, separate gate.

## What "compatibility target" means here

These files are NOT part of the standard library on this branch. They are
**diagnostic instruments**: each one names a feature the reducer needs to
support, parameterized by what it stresses. As PReduce-lite phases land,
we re-evaluate which tier moves from skipped → green:

| Phase | Unblocks | Status |
|-------|----------|--------|
| 10 (built-in ctor reduce) | Tier A | ✅ landed |
| 10b (user-defined-ctor reduce via ctor-registry) | Tier B (syrup, promise, message) | ✅ landed 2026-05-04 |
| 11+ (closure capture / HOF) | larger Tier B if any rely on closures | open |
| Phase 9 (FFI, deferred) | Tier C (TCP, wire codecs) | deferred |

When a phase lands, drop the corresponding entries from `tests/.skip-tests`.

## References

- Upstream PR: https://github.com/LogosLang/prologos/pull/28
  (LogosLang/prologos branch `claude/ocapn-prologos-implementation-auLxZ`)
- `goblin-pitfalls.md` — entries #1 (capability subtype + promise
  resolution composition), #2 (match-with-wildcard limitation on
  user-defined data), #27 (syrup-wire 270s decode pathology). Lives
  upstream as `docs/tracking/2026-04-27_GOBLIN_PITFALLS.md`; not yet
  pulled to this branch.
- OCapN Model.md / CapTP spec — referenced from the per-file headers.
