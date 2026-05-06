# OCapN compatibility targets

This directory holds a **subset** of the upstream OCapN (Object-Capability
Network) port from PR #28
(`LogosLang/prologos` branch `claude/ocapn-prologos-implementation-auLxZ`,
last sync 2026-05-06). The 2026-05-06 sync brought the lib slice to
parity with upstream HEAD (16 lib files); the test surface is 20 of
upstream's 26 test files (the 6 omitted require modules whose
elaboration currently produces type errors on this branch's compiler
— see "Omitted from this sync" below).

## Sync 2026-05-06 — parity catch-up

Pulled from upstream HEAD `b971818`:
- 9 new lib files: `bridge-interop-helpers`, `captp-bridge`,
  `captp-session`, `captp-wire`, `netlayer`, `pipelining`,
  `syrup-wire`, `tcp-testing`, `vat` (~2.7 kLOC total).
- 14 new test files (12 with passing tests, 2 self-skip when
  Node.js absent — see Phase 24 interop in upstream).
- 1 new example file:
  `racket/prologos/examples/2026-04-27-ocapn-acceptance.prologos`
  (used by `test-ocapn-acceptance-l3`).
- Refreshed all 7 already-pulled lib files to upstream HEAD versions.
- Refreshed `docs/tracking/2026-04-27_GOBLIN_PITFALLS.md` (1129 → 1260
  LOC; pitfalls #31, #32 added upstream).

### Test status post-sync (20 files)

OK (13 files, 145 cases):
- `test-ocapn-acceptance-l3` (10), `behavior` (13), `captp` (7),
  `e2e` (8), `locator` (13), `message` (19), `netlayer` (14),
  `pipeline` (5), `pipelining` (4), `promise` (16), `refr` (6),
  `syrup` (9), `vat` (21).

SKIP (7 files; self-skip via `(unless (interop-deps-present?) ...
(exit 0))` when Node.js / `tools/interop/node_modules` absent):
- `abort`, `bridge-interop`, `conversation`, `handshake`,
  `live-interop`, `pipelined`, `rpc`. These tests exercise the
  Node.js-side OCapN reference implementation and are runnable
  only after `cd tools/interop && npm install`. They pass cleanly
  here (no errors) because the guard exits before any
  `process-string` of `prologos::ocapn::syrup-wire` is attempted.

### Omitted from this sync

6 upstream test files were dropped because they fail to load:

| upstream test file | reason |
|---|---|
| `test-ocapn-bridge.rkt` | imports `prologos::ocapn::syrup-wire` which fails to elaborate ("Type mismatch") on this branch's compiler |
| `test-ocapn-captp-wire.rkt` | same syrup-wire load failure |
| `test-ocapn-syrup-wire.rkt` | tests syrup-wire directly; same load failure |
| `test-ocapn-syrup-cross-impl.rkt` | same |
| `test-ocapn-netlayer-tcp.rkt` | same |
| `test-ocapn-tcp-testing.rkt` | imports a missing `tcp-ffi.rkt` Racket module |

The `syrup-wire.prologos` and `captp-wire.prologos` lib files ARE
kept in the directory — the SKIP tests reference them in their
post-skip-guard preamble; under a Node.js-equipped environment
they'd be loaded then. But syrup-wire's elaboration error means
the SKIP tests would also fail in such an environment until the
elaborator gap is closed. That's an upstream-vs-this-branch
compiler-version skew, not a local breakage; tracked for the next
sync.

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

**Files**: `syrup.prologos`, `promise.prologos`, `message.prologos`,
`locator.prologos` (upstream-pulled 2026-05-04 PM), `behavior.prologos`
(upstream-pulled 2026-05-04 PM), `core.prologos` (upstream-pulled
2026-05-04 PM, re-exports only)

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

## Hybrid kernel test status

Track of OCapN-shape programs validated against the Zig hybrid kernel
(`dist/prologos-hybrid-bundle/bin/prologos --profile <FILE>`). Each
runs end-to-end through the swappable-backend → backend-hybrid →
kernel BSP scheduler.

| File | Status | Workload | Result | Kernel ns | Fires (native + cb) |
|---|---|---|---|---|---|
| `examples/preduce-lite/07-factorial.prologos` (baseline) | ✅ kernel | factorial-iter 1 5 = 120 | `(expr-int 120)` | ~143 µs | 47 fires (13 native int-arith, 34 callback) |
| `examples/ocapn/ocapn-hybrid-1.prologos` | ✅ kernel | `[get-nat [syrup-nat (suc (suc zero))]]` | `[some <2>]` | ~29 µs | 2 fires (0 native, 2 cb) |
| `examples/ocapn/ocapn-hybrid-2.prologos` | ✅ kernel | `[get-tag [mk-tagged "op:listen" syrup-null]]` | `[some "op:listen"]` | ~126 µs | 5 fires (0 native, 5 cb) |
| `examples/ocapn/ocapn-hybrid-3.prologos` | ✅ kernel | 11-arm `defn` + 3 dispatched calls | `(true, false, true)` packed in nested pair | ~28 µs | 6 fires (0 native, 6 cb) |
| `examples/ocapn/ocapn-hybrid-4.prologos` | ✅ kernel | `[is-some? [get-tag [syrup-tagged "op:deliver" syrup-null]]]` (chained Option) | `(expr-true)` | ~36 µs | 5 fires (0 native, 5 cb) |
| `examples/ocapn/ocapn-hybrid-5.prologos` | ✅ kernel | predicate sweep across 9 SyrupValue ctors | nested-pair of 9 booleans | ~52 µs | 18 fires (0 native, 18 cb) |
| `examples/ocapn/ocapn-hybrid-6.prologos` | ✅ kernel | multi-arg `defn pick` matching on 2 args + tagged?/bool? on results | nested-pair (false, true) | ~117 µs | 16 fires (0 native, 16 cb) |
| `examples/ocapn/ocapn-hybrid-7.prologos` | ✅ kernel | uses `prologos::ocapn::promise` directly: pst-fulfilled + pst-broken predicates | 5-tuple of bools | ~103 µs | 10 fires (0 native, 10 cb) |
| `examples/ocapn/ocapn-hybrid-8.prologos` | ✅ kernel | **mixed**: int+/int* (NATIVE tags 0/2) + bool?/tagged? (callback) | nested-pair (false, false, false) | ~99 µs | 9 fires (**3 native**, 6 cb) |
| `examples/ocapn/ocapn-hybrid-9.prologos` | ✅ kernel | **recursive** sum-to-n (Nat → Int via natrec); wraps result as syrup-int | `[syrup-int 15]` | ~153 µs | 62 fires (**20 native** int+ + identity, 42 cb) |
| `examples/ocapn/ocapn-hybrid-10.prologos` | ✅ kernel | full CapTP **op-deliver** message build (mk-deliver) + 4-predicate sweep on 7-arm match (deliver?, deliver-only?, listen?, abort?) | nested-pair (true, false, false, false) | ~201 µs | 44 fires (0 native, 44 cb) |
| `examples/ocapn/ocapn-hybrid-11.prologos` | ✅ kernel | `transport-name` defn from upstream `locator.prologos` called on both Transport ctors | pair ("loopback", "tcp-testing-only") | ~71 µs | 4 fires (0 native, 4 cb) |
| `examples/ocapn/ocapn-hybrid-12.prologos` | ✅ kernel | upstream `behavior.prologos` Effect enum + 3 ctors (eff-send-only, eff-resolve, eff-break) + 3 syrup-tagged wrappers + 3 tagged? predicate dispatches | pair (true, true, true) | ~32 µs | 6 fires (0 native, 6 cb) |

All measurements: single run, on this Linux x86_64 host, post-build at
`tools/build-hybrid-binary.sh` against branch
`claude/prologos-layering-architecture-Pn8M9`.

### Reading the numbers

- **Kernel ns** is the time spent inside the kernel's BSP fire loop
  (`prof.run_ns`). Doesn't include the Racket-side compile-expr cost,
  the FFI roundtrip envelope, or elaboration time.
- **Native fires** are ones that hit the kernel's built-in fire-fns
  at tags 0-7 (int-arith + identity). They run in ~50-65 ns each.
- **Callback fires** are ones that wrap a Racket fire-fn at fresh
  tags 8+. They run in ~1-5 µs each (FFI overhead + Racket execution).
- The **5×–70× per-fire gap** between native and callback is the
  Phase-7 migration target: each callback that becomes native saves
  most of its current ns.
- **OCapN-shape workloads have zero native fires today**. They use
  user-defined-ctor pattern matching, which has no kernel-native
  equivalent. Phase 7 work would add native fire-fns for `expr-reduce`
  arm dispatch + the ctor-app stuck-value construction.

### Known issues surfaced during testing

Tracked in [`docs/tracking/2026-05-04_PROLOGOS_LANGUAGE_PITFALLS.md`](../../../../docs/tracking/2026-05-04_PROLOGOS_LANGUAGE_PITFALLS.md)
(language/elaboration/kernel pitfalls discovered while running real
programs through the hybrid kernel — distinct from the upstream OCapN
goblin-pitfalls.md). Active items as of 2026-05-04:

- **Pitfall #1** (🟡 worked-around): FQN-qualified prelude symbols
  (e.g., `prologos::data::list::nil`) not resolved by `preduce.rkt`'s
  `expr-fvar` lookup. Surfaced by ocapn-hybrid-5; affects both backends.
- **Pitfall #2** (🟢 fixed in `0ae1230`): Kernel `FormatBuffer`
  truncated profile JSON > 1 KB. Was silently giving partial JSON
  output; raised buffer to 8192 bytes.
- **Pitfall #3** (🔴 open): silent prelude shadowing under
  `:refer-all` — calling a function name that isn't in the named
  module silently falls back to the prelude, surfacing later as
  a confusing "could not infer type" error rather than a clear
  "function not found in module X." Surfaced in ocapn-hybrid-8
  via `[int? a]` resolving to `prologos::data::datum::int?`.
- **Pitfall #4** (🟡 worked-around): identity-bridge install sites
  in `compile-and-bridge` + dynamic-β don't yet pass
  `#:native-op 'identity`, so they fall into the callback path
  even though the kernel has a native identity at tag 0. Easy
  ~5-LOC fix; deferred.

## References

- Upstream PR: https://github.com/LogosLang/prologos/pull/28
  (LogosLang/prologos branch `claude/ocapn-prologos-implementation-auLxZ`)
- `goblin-pitfalls.md` — entries #1 (capability subtype + promise
  resolution composition), #2 (match-with-wildcard limitation on
  user-defined data), #27 (syrup-wire 270s decode pathology). Lives
  upstream as `docs/tracking/2026-04-27_GOBLIN_PITFALLS.md`; not yet
  pulled to this branch.
- OCapN Model.md / CapTP spec — referenced from the per-file headers.
