# Prologos Language / Elaboration Pitfalls

Tracks bugs discovered in the **Prologos compiler stack itself**
(parser, elaborator, typing-core, reducer, kernel) as they surface
during downstream work — particularly while running real `.prologos`
programs through the hybrid kernel via the swappable-backend
infrastructure. Distinct from the upstream OCapN/Goblins
`goblin-pitfalls.md`, which catalogs OCapN-specific design pitfalls
(capability subtype, syrup-wire, etc.).

## Format

Each entry is numbered + dated and follows this shape:

- **#N** — short title — *date discovered*
- **Surfacing program / context**: where it was first seen
- **Symptom**: the user-visible failure
- **Root cause** (if known) or hypothesis
- **Workaround**: what to do until it's fixed
- **Status**: 🔴 open / 🟡 worked-around / 🟢 fixed (with commit hash)
- **Affects**: which subsystems / which backends

New entries get appended; closed entries stay (don't delete history).

---

## #1 — FQN-qualified prelude symbols not resolved by `expr-fvar` lookup
*Discovered 2026-05-04 (`0ae1230`)*

**Surfacing program**: `racket/prologos/examples/ocapn/ocapn-hybrid-5.prologos`
when it tried `[syrup-list nil]` after `(imports (prologos::data::list :refer [List nil cons]))`.

**Symptom**:
```
preduce: expr-fvar prologos::data::list::nil not found in global env
  context...:
   .../prologos/preduce.rkt:211:0: compile-expr
```

**Root cause** (hypothesis): the elaborator emitted the FQN-qualified
form `prologos::data::list::nil` for the `nil` reference (probably
because `:refer-all` import path isn't being honored on the lookup
side), but `global-env-lookup-value` only resolves it under the
short name `nil` in some contexts. Likely a per-file-vs-prelude
definition-cells boundary: the `nil` ctor is registered in the
prelude's def cells under one name, looked up under another at
reduce time.

Affects BOTH backends (preduce.rkt directly + preduce-hybrid via
the shared compile-expr) — so it's not a refactor regression. It
was already there pre-refactor; just hadn't been exercised by a
program that used FQN-qualified prelude ctors during reduction.

**Workaround**: avoid `[syrup-list nil]` in test programs; use
syrup-null-equivalent stand-in or open-code the empty case.

**Status**: 🟡 worked-around. Affects preduce.rkt (and transitively
preduce-hybrid via the shared compile-expr). Production `nf`
unaffected because it uses a different lookup path that resolves
FQN names.

**Affects**: `racket/prologos/preduce.rkt` (compile-expr's
expr-fvar case), `racket/prologos/global-env.rkt`
(`global-env-lookup-value`), and any reducer that goes through the
preduce.rkt entry point.

**Path to fix**: trace the `nil`/`cons` registration in the prelude's
definition-cells and ensure the lookup tries both FQN and short-name
forms (mirror the dual-lookup pattern in `lookup-ctor-meta` for
user-ctor reduce). ~30 min if the registration vs lookup names
diverge in only one place; could be deeper if the elaborator's
qualification logic needs adjustment.

---

## #2 — Kernel `FormatBuffer` truncated profile JSON when N_TAGS=256
*Discovered 2026-05-04 (`0ae1230`); fixed same day*

**Surfacing program**: ran `tests/bench-ocapn-hybrid-vs-lite.rkt`
+ later programs through the hybrid binary with `--profile`. The
JSON output appeared valid but cut off mid-array.

**Symptom**: `prologos_print_stats` and `prologos_print_callback_summary`
emitted truncated JSON. The first ~80 per-tag entries printed OK;
everything past ~1024 chars was dropped silently. Tools that parsed
the output (`json.loads`) failed on the unbalanced braces.

**Root cause**: `runtime/core/format.zig` declared `FormatBuffer.buf:
[1024]u8`. The full PNET-STATS object with 256 per-tag entries
(both `by_tag` AND `ns_by_tag` arrays) is ~3000+ bytes. `putc`
silently dropped writes past the buffer length (`if (self.len <
self.buf.len)`) — no overflow, no error, just truncation.

**Workaround**: not needed; `prologos_get_stat` (per-tag programmatic
read via FFI) was unaffected and gave correct numbers.

**Status**: 🟢 fixed in commit `0ae1230` — buffer raised to 8192
bytes (~4× headroom for current N_TAGS=256). Profile JSON now
parses cleanly.

**Affects**: kernel-side text profile output. Fix is forward-
compatible if N_TAGS grows to 256 × 4 = 1024.

**Lesson**: silent buffer truncation is the worst class of bug —
no error, valid-looking partial output, downstream parsers crash.
Future kernel-side print code should either grow the buffer
dynamically OR error on overflow.

---

## #3 — Silent prelude shadowing under `:refer-all` produces confusing inference errors
*Discovered 2026-05-04 (`0ae1230`+)*

**Surfacing program**: `racket/prologos/examples/ocapn/ocapn-hybrid-8.prologos`
when it called `[int? a]` on a SyrupValue. `prologos::ocapn::syrup`
does NOT export `int?` (only `null?`, `bool?`, `refr?`, `promise?`,
`tagged?`); the call resolved to `prologos::data::datum::int?` (a
Datum predicate from the prelude) instead.

**Symptom**: the elaborator reported
```
(inference-failed-error
  (srcloc "<unknown>" 0 0 0)
  "Could not infer type"
  "[prologos::data::datum::int? ocapn-on-hybrid-8::a]")
```
followed downstream by an unbound-variable-error for the def
*depending* on the failed def — but with NO mention of the actual
issue (that the predicate name was looked up in the wrong module).

**Root cause** (hypothesis): `:refer-all` imports from the
named module's exports list; absent that name in the named module,
the elaborator falls back to the prelude (which exports
`prologos::data::datum::int?` as `int?`). The fallback is silent —
the user expected the syrup version, got the datum version. The
TYPE error then surfaces in inference rather than at the lookup,
making the root cause invisible.

**Workaround**: use predicates that actually exist on the target
type. For SyrupValue: `null?`, `bool?`, `refr?`, `promise?`,
`tagged?`. To check for a non-trivial value, use one of the
selectors (`get-nat`, `get-string`, etc.) and check the resulting
Option.

**Status**: 🔴 open (UX issue, not a correctness bug). The fallback
behavior is arguably correct (we WANT to find prelude functions),
but the diagnostic is poor — should at least say "function `int?`
is not exported by `prologos::ocapn::syrup` but matches a prelude
function `prologos::data::datum::int?` of incompatible type."

**Affects**: elaborator's name-resolution diagnostic emission. The
type checker's "could not infer" error is the surface symptom; the
root cause is lookup-side.

**Path to fix**: when fallback name-resolution to prelude succeeds
but produces a type error, emit a diagnostic noting (a) the
fallback path taken, (b) which named module was searched first,
(c) the type mismatch. ~1 hour in the elaborator's import-resolution
+ inference-error pretty-printing.

---

## #4 — Identity-bridge migration not wired through `#:native-op`
*Discovered 2026-05-04 (`0ae1230`+); not surfaced as a user bug*

**Surfacing context**: profiling program 8 (which uses int-arith)
showed 3 native fires, but the program has only 2 int-arith
expressions (10+20 and 7*6). The 3rd native fire is presumably
an identity-bridge (the Phase 10 migration target from the
original hybrid track) that ALSO routes to KERNEL-IDENTITY-TAG=0.
The remaining identity-bridge install sites in the post-refactor
compile-expr (e.g. `compile-and-bridge`'s `make-identity-fire`)
do NOT currently pass `#:native-op 'identity`, so they fall into
the callback path.

**Symptom**: missed optimization. Identity bridges that the
pre-refactor preduce-hybrid.rkt routed natively (Phase 10's "96%
callback reduction" claim) now go through Racket callbacks in some
paths. Net effect: the headline OCapN-shape benchmark (W4) shows
0 native fires; in the pre-refactor world some of those would have
been native identities.

**Status**: 🟡 worked-around (not a regression vs. earlier benchmarks
since W4 used hand-built ASTs that didn't include identity bridges
either way). Easy fix: pass `#:native-op 'identity` from
`compile-and-bridge`'s `b-install-fire-once` call site in
preduce.rkt. ~5 LOC.

**Affects**: `racket/prologos/preduce.rkt` (`compile-and-bridge`,
the dynamic-β bridging in `expr-app`'s else branch).

**Path to fix**: thread `#:native-op 'identity` through the
two install sites that wrap `make-identity-fire` (preduce.rkt
~lines 791 + 867). ~5 min implementation; benefit visible in
the next benchmark run.

---

## Pattern observations across pitfalls

(Update as more entries land.)

- **#1 + future**: name-resolution between FQN-qualified emission
  (elaborator side) and short-name registration (registry side) is
  a recurring seam. Watch for similar bugs in `lookup-ctor` (user
  ctors), `lookup-trait`, `lookup-impl`, `lookup-bundle`.
- **#2**: silent truncation in kernel-side I/O. Audit other fixed-
  buffer print sites if they exist.
