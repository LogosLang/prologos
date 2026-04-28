# EtProp Pitfalls — Notes from the EigenTrust-on-Propagators Bring-Up

**Date**: 2026-04-28
**Context**: While implementing the EigenTrust-on-propagators example
(`racket/prologos/lib/examples/eigentrust{,-prop.rkt,.prologos}`), the work
surfaced several rough edges in Prologos and the surrounding Racket tooling.
This document captures them in one place so future similar work doesn't have
to rediscover them.

The list is **observation only** — these are bugs / friction in language
features and tooling, not in the EigenTrust example itself. They're filed
here because tracking them in commit messages alone made them invisible.

------------------------------------------------------------------

## 1. `def` is reference-transparent — side effects re-fire on every use

In Prologos a `def name := body` stores `body`'s **AST**, not its evaluated
value. Each subsequent reference to `name` substitutes the AST and re-reduces
it. For pure computations that's fine; for foreign calls with side effects
it's a footgun.

Repro:

    foreign racket "racket/base" [add1 : Nat -> Nat]

    foreign racket "lib/examples/eigentrust-prop.rkt" :as et
      net-new : Posit32 -> Posit32

    def h := et/net-new 1000000.0
    h
    h
    h     ;; -> three different handle ids

Each `h` re-evaluates `et/net-new`, allocating a fresh network. This breaks
multi-`def` imperative-style programming with foreign side effects. Note
that within a single `process-command` boundary the per-command `whnf-cache`
**does** memoise identical AST nodes, so a single top-level expression with
multiple syntactic occurrences of `h` after substitution does behave; but
`def`-bound names are unfolded across `def` boundaries.

**Workaround**: the entire algorithm runs as one expression — typically a
single `defn` body whose RHS chains `let := body` bindings. Within that one
expression all FFI calls evaluate exactly once.

**Underlying language design call**: this is consistent with definitional
equality in dependent type theory (defs are *transparent*), so it's not
strictly a bug — but the behaviour is surprising for anyone bringing in
side-effecting foreign code, and there is no warning surface.

## 2. Reduction is call-by-name — unused let-bound side effects are dropped

`let _ := side-effecting-call body` evaluates `body` without ever
substituting `_` (since `_` is a wildcard). The `side-effecting-call` is
therefore **never evaluated**. Same shape for any unreferenced binding:

    let _i := et/net-add-prop ...   ;; never fires
    let _r := et/net-run h          ;; never fires
      result-expr                    ;; only this is reduced

The eigentrust shim works around this by making every "side-effecting" FFI
call return a **meaningful** Posit32 (the cell-ref or the handle id) so the
caller is forced to thread it through a subsequent call. Sequencing via
`do` blocks doesn't help — `do` desugars to nested let.

A shim helper such as `seq : Unit -> A -> A` that pattern-matches on `unit`
also failed empirically; the match seems to be optimised through. Real
forcing only happens at the **FFI argument boundary** where `whnf` /
`nf` are used to marshal values.

**Implication for any FFI-via-foreign API**: every effectful call MUST
return a non-trivial value that the user is induced to consume. Returning
`Unit` is a trap.

## 3. `let x := value body` requires `body` strictly more indented than `let`

Prologos's WS-mode `let` macro merges consecutive bodyless `let`s into a
single binding group, with the trailing expression as the body. Surface
syntax requires the body to be indented past the `let` column:

    defn calc [n]
      let x := add1 n
        add1 x         ;; OK — body indented past `let`

If the body shares the `let`'s indent the parser silently drops the whole
defn (no error reported, the name registers as **unbound**):

    defn calc [n]
      let x := add1 n
      add1 x           ;; WRONG — defn never registered

This combines with pitfall #4 below to make defn-body errors particularly
hard to diagnose.

## 4. Defn-body errors swallow the whole defn

When `defn name body` has a malformed body (e.g. wrong indent, undefined
identifier in a particular position), the surface form is silently rejected
and `name` never registers. The first hint is a downstream
"Unbound variable: name" error from a later top-level expression. There is
no error from the defn itself.

Observed during eigentrust-prop bring-up: `defn pretrust-cells [...]` with
a stale forward reference compiled silently into nothing; the only signal
was the later `[pretrust-cells h pretrust]` failing.

## 5. `defn name | pat -> body` arity-1 list patterns produce a non-exhaustive match

This compiles cleanly but raises `??__match-fail` at run time:

    defn zeros-of
      | nil          -> nil
      | [cons _ rs]  -> [cons 0.0 [zeros-of rs]]

The fix is the explicit-`match` form, which works:

    defn zeros-of [xs]
      match xs
        | nil          -> nil
        | [cons _ rs]  -> [cons 0.0 [zeros-of rs]]

The two forms should be equivalent; the multi-arity dispatch path appears to
miss the `nil`-as-constructor pattern in arity-1 list matches.

## 6. Foreign type signatures must fit on ONE line

The foreign-block parser tokenises type tokens and then splits on `->`. If
the type is wrapped across lines:

    net-add-prop : Posit32 Posit32 Posit32
                   [List [List Posit32]] [List Posit32] Posit32 -> Posit32

`foreign-type-tokens->sexp` errors with "Cannot parse foreign type tokens".
The fix is a single (potentially long) line:

    net-add-prop : Posit32 Posit32 Posit32 [List [List Posit32]] [List Posit32] Posit32 -> Posit32

This is annoying for FFI declarations of broadcast propagators (which take
several list-typed arguments) but is currently mandatory.

## 7. Foreign FFI doesn't support Posit32 marshalling out of the box

`base-type-name` recognises `expr-Posit32` / `expr-Posit64` and returns the
symbol, but `marshal-prologos->racket` and `marshal-racket->prologos` had no
case for them: the foreign machinery would say "Unsupported marshal-in
type: Posit32". The previous handoff added Posit32/Posit64 marshalling
(see commit `f9a3d7c`); this is still the only marshalling path that
short-circuits the existing posit-impl.rkt arithmetic ops via FFI.

The carrier is the **bit-pattern integer** (matching posit-impl.rkt), so
`foreign racket "posit-impl.rkt" [posit32-add : Posit32 Posit32 -> Posit32]`
works directly.

## 8. Foreign data structure types are passed via `[List ...]` but only allowed
in specific positions

`[List Nat]`, `[List Posit32]`, and `[List [List Posit32]]` work in foreign
type signatures. They must be bracketed (the parser handles them as type
applications). Using bare `List Nat` would unfold into curried `List ->
Nat -> ...`, which is wrong.

## 9. Top-level `let` is forbidden, but inside `defn` bodies works fine

`let h := body` at the top level errors with
`let: 'let' is not allowed at top level. Use 'def' instead.`

There's no surface alternative for "give a name to an intermediate value at
the top level". `def` re-evaluates (pitfall #1). The only way to evaluate
something exactly once at top level is to inline the entire computation
into one expression.

## 10. `(zeros-of rs)` parens vs `[zeros-of rs]` brackets are NOT
interchangeable

In WS mode `(...)` is reserved for parser keywords (`match`, `def`, etc.) and
relational goals. Function application uses `[]`. Writing `(f x)` for an
ordinary application typically silently fails (the parser tries to find a
special form named `f` and either drops the form or fails very far away
from the source line).

## 11. `list-literal` quoting handles bare numeric literals correctly

Confirmed working: `'[0.5 0.25 0.125]` produces a `[List Posit32]` (the
posit literals retain their decimal-literal interpretation; bare `0.5` is
equivalent to `~0.5` per the grammar). Earlier confusion was that quoted
identifiers (`'[src1 src2]`) get reified as Datum symbols, not as variable
references — so list-literal sugar works for **constants** but not for
**values**.

## 12. Racket-9-only features + Ubuntu 24.04 ships Racket 8.10

`make-parallel-thread-fire-all` (`propagator.rkt:2592`) uses `(thread
#:pool 'own)` — a Racket 9 feature that's silently a runtime error on
Racket 8.x:

    application: procedure does not accept keyword arguments
      procedure: thread

The driver unconditionally installs this executor at module load
(`driver.rkt:434`). On Racket 8 the test suite errors out from any code
path that goes through `run-to-quiescence-bsp`. Workarounds tried:

  * `parameterize` to `sequential-fire-all` at the call site — works for
    your own entry points but doesn't help the driver's own
    `run-post-compilation-inference!` which is set up at module load.

  * Patch `propagator.rkt` to detect Racket version — invasive.

Resolution chosen here: build Racket 9 from source. The download host
(`download.racket-lang.org`) is on a curl allowlist, so source must be
pulled from `https://github.com/racket/racket/archive/refs/tags/v9.1.tar.gz`
and built with `make CPUS=4 PKGS=""`. `rackunit` then has to be
hand-installed by copying `pkgs/rackunit/rackunit-lib/rackunit` and
`pkgs/compiler-lib/raco/testing.rkt` into the Racket collects tree —
`raco pkg install` fails because the catalog server is also on the allowlist.

## 13. Prologos's parser drops files using `prologos::core::abs-trait`

`racket/prologos/lib/examples/foreign.prologos` `require`s
`prologos::core::abs-trait` which no longer exists (renamed/merged into
`prologos::core::arithmetic`). Running this example now errors:

    imports: Cannot find module: prologos::core::abs-trait

This is unrelated to the eigentrust work but came up while sanity-checking
the FFI surface.

## 14. `tools/check-parens.sh` hardcodes a Mac-style Racket path

The pre-commit paren checker shells out to
`/Applications/Racket v9.0/bin/racket` (line 21), which is a Mac dev
machine artifact. On Linux + the project's expected path
(`/usr/local/bin/racket`) this fails open with a confusing
"FAIL: ... No such file or directory" message even when the file's parens
are balanced.

Workaround used here: a small standalone `parencheck.rkt` script that
parses files with `read-syntax`. Either a `command -v racket` lookup or a
configurable path setting in `check-parens.sh` would close this.

## 15. Default Posit32 conversions use exact rationals and are slow at scale

Encoding a Racket rational into a Posit32 bit pattern (`posit32-encode`) and
decoding it back (`posit32-to-rational`) goes through the exact-rational
posit format. For our 4-peer × 20-iteration EigenTrust this is unproblematic,
but the propagator network's reduction phase reports ~55 seconds in
`reduce_ms` even though the actual fixpoint runtime is sub-second. The
overhead is in the elaboration / type-checking of the recursive `drive`
loop and the FFI marshalling, not the propagator firing itself. Future
work: a `Posit32` instance of `Num` and operator desugaring would let the
.prologos source operate on posits directly (without going through Rat),
which would also let the FFI shim drop its rational pre-computation step.

------------------------------------------------------------------

## Tracking

These observations are not tracked in any specific PIR or design doc;
they're cross-cutting friction discovered during the bring-up. If any of
them blocks future work, file a tracking doc per `.claude/rules/workflow.md`
and link back here.
