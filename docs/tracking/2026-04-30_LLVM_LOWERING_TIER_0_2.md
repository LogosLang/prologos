# LLVM Lowering — Tiers 0–2 (SH Series, Track 1)

**Date**: 2026-04-30
**Status**: Stage 3 design + Stage 4 implementation interleaved (per Tier-as-Phase Protocol)
**Series**: SH (Self-Hosting) — first track, scope-limited proof of concept
**Branch**: `claude/prologos-layering-architecture-Pn8M9`
**Cross-references**:
- [LANGUAGE_VISION.org § Self-Hosting → LLVM → Logos](principles/LANGUAGE_VISION.org)
- [SEXP_IR_TO_PROPAGATOR_COMPILER](../research/2026-03-30_SEXP_IR_TO_PROPAGATOR_COMPILER.md) § Phase 2
- [MASTER_ROADMAP.org § SH Series placeholder](MASTER_ROADMAP.org) (line 258)

---

## 1. Summary

Add a Racket-hosted LLVM lowering pass that reads typed AST values produced by `elaborate-top-level` and emits LLVM IR. Three tiers, each a self-contained milestone with CI-runnable tests:

- **Tier 0** — `Int` literal returned by `main` (exit code).
- **Tier 1** — Arithmetic, comparisons, and conversions over `Int`/`Bool` (no closures, no allocation).
- **Tier 2** — Top-level functions with non-capturing parameters, direct calls, and one-line `m0` erasure for type-level binders.

Tier 2 is the natural break before deeper Phase-2 blockers (closure conversion, GC, layout, IO) kick in.

## 2. Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| Plan | Write this document | ✅ | initial draft |
| T0.A | Driver hook: extract typed body of `def main` | ✅ | `lower-program/from-global-env` queries `global-env-lookup-{type,value}` after `process-file` populates the env |
| T0.B | LLVM emitter for `expr-int`, `expr-Int` | ✅ | `racket/prologos/llvm-lower.rkt` — closed pass; `unsupported-llvm-node` exn for everything else |
| T0.C | Tier 0 acceptance file + Racket-side test | ✅ | `examples/llvm/tier0/{exit-42,exit-0,exit-7}.prologos` + `tests/test-llvm-lower.rkt` |
| T0.D | Tier 0 CI integration | ✅ | `.github/workflows/llvm-lower.yml` runs unit + e2e |
| T0.✅ | Tier 0 commit | 🔄 | next |
| T1.A | Lowering for `expr-int-{add,sub,mul,div,mod,neg,abs,lt,le,eq}` | ⬜ | |
| T1.B | `expr-app` for primitive-rooted application | ⬜ | |
| T1.C | Tier 1 acceptance file + tests + CI | ⬜ | |
| T1.✅ | Tier 1 commit | ⬜ | |
| T2.A | `expr-lam` lowering at top level (non-capturing only) | ⬜ | |
| T2.B | `expr-bvar` → SSA local; `expr-app` → `call` | ⬜ | |
| T2.C | `m0` binder drop (single-line erasure at top level) | ⬜ | |
| T2.D | Free-variable detector (refuses captures with clear error) | ⬜ | |
| T2.E | Tier 2 acceptance file + tests + CI | ⬜ | |
| T2.✅ | Tier 2 commit | ⬜ | |

## 3. Scope

### In scope (Tier 0–2 sum)

- `def main : Int := <expr>` as the entry point
- `def name : T := <expr>` for ground `T ∈ {Int, Bool}`
- `defn name [x y ...] := <body>` with all parameters of type `Int` or `Bool` and no captures
- Primitive Int operators from `elaborator.rkt:795` (`int+`, `int-`, `int*`, `int/`, `int-mod`, `int-neg`, `int-abs`, `int-lt`, `int-le`, `int-eq`)
- Direct application of a known top-level definition or primitive
- `m0`-multiplicity binders dropped (degenerate case: erasure for type-only parameters)

### Out of scope (deferred to later SH tracks)

- Heap allocation, GC, layout for sums/products
- Closures with free variables (lifted Tier 2 detector raises a clear error)
- Polymorphism that requires monomorphization
- `Rat`, `Nat`, `String`, `List`, user data types
- Effects / IO beyond `main`'s exit code
- Pattern matching to LLVM CFG (Tier 3)
- Promotion of the lowering pass to a propagator stratum (recorded as scaffolding; see § 5)

### Failure mode

The lowering pass is **closed**: encountering any AST node not in the supported set raises `(unsupported-llvm-node node sub-tier)` with the struct kind, source location (when present), and a hint pointing to the next tier or to the SH-series gap. No silent fallthroughs, no no-ops, no fallbacks. Boundary failure aligns with the project's "validate at system boundaries" rule.

## 4. WS Impact

None. Tier 0–2 add no surface syntax. The existing reader, parser, and elaborator produce typed AST; the lowering pass is a new *output* mode invoked after `process-file`.

## 5. Mantra Alignment — honest scaffolding statement

> "All-at-once, all in parallel, structurally emergent information flow ON-NETWORK."

The Tier 0–2 lowering pass is a Racket function. It is **not** a propagator stratum. It is **scaffolding** for SH Phase 2, and labelled as such.

Where it aligns:
- **Information flow**: input is read from typed AST cells produced by the elaboration network. The pass is a *consumer* on the network's output boundary. Reading from cells is the right side of the boundary.
- **No off-network mutation of compiler state**: the pass does not write to cells, does not register propagators, does not introduce ambient parameters that hold compiler state.

Where it does not align (and why that is acceptable here):
- **Not all-at-once / not in parallel**: the function walks the AST sequentially. There is no broadcast, no fan-in latch, no per-node propagator. Justification: the pass is at a *system boundary* (compiler emitting a textual artifact) and the items are not independent in the relevant sense — instruction emission within a basic block is sequential by SSA construction.
- **Not structurally emergent**: control flow decides which case fires (`match` on the AST struct kind). Justification: same as above; the boundary translates an in-network value to an off-network text format.

**Retirement plan to the principled form** (deferred, named):
The mantra-aligned form is a **lowering stratum** where each LLVM-instruction-pattern is a registered propagator rule that fires when its input cell (typed AST node) is ready (per [SEXP_IR_TO_PROPAGATOR_COMPILER § 5 question 3](../research/2026-03-30_SEXP_IR_TO_PROPAGATOR_COMPILER.md)). Promotion is a later SH-series track gated on:
1. PPN Track 4D substrate so AST cells are first-class
2. Incremental compilation requirement (PPN Track 8) being in scope
3. A microbench showing per-function lowering is the bottleneck

Until then, the function form ships and is labelled *scaffolding*. This follows the Validated-Is-Not-Deployed and "Pragmatic-Is-A-Rationalization" disciplines: the gap is named, the trigger conditions for closing it are concrete, the function form is incomplete-because-X (X = stratum form requires PPN 4D + Track 8 prerequisites).

## 6. NTT Sketch (eventual stratum form)

For the future stratum form. Not implemented in Tier 0–2; recorded so the function form's signatures can be designed with the eventual cell shapes in mind.

```
;; A typed AST node cell holds an expr-* value (lattice: discrete)
cell typed-ast-cell : Cell (Discrete Expr) :reads <none> :writes <by elaborator>

;; A lowering result cell holds an LLVM-IR fragment (string-list lattice: append)
cell llvm-fragment-cell : Cell (AppendList String) :reads <by emitter>

;; A lowering propagator: one instance per AST struct kind
propagator lower-int-add
  :reads (typed-ast-cell input) (llvm-fragment-cell lhs) (llvm-fragment-cell rhs)
  :writes (llvm-fragment-cell output)
  :where Monotone
  :component-paths ...
```

The pass emerges from the topology of typed-AST cells. Each AST shape registers a lowering rule (analogous to SRE form registry). Output fragments accumulate via an append lattice. The driver walks the output cells in topological order and serializes.

This is the principled form. Tier 0–2 does **not** build it. The function form's API (`lower-toplevel : Symbol × Expr × Expr → String`) is shaped to be replaceable by the stratum form without touching callers.

## 7. File layout

| Path | Purpose |
|------|---------|
| `racket/prologos/llvm-lower.rkt` | Lowering pass module (function form) |
| `racket/prologos/tests/test-llvm-lower.rkt` | Racket-side unit tests on the IR string |
| `racket/prologos/examples/llvm/tier0/*.prologos` | Tier 0 acceptance programs |
| `racket/prologos/examples/llvm/tier1/*.prologos` | Tier 1 acceptance programs |
| `racket/prologos/examples/llvm/tier2/*.prologos` | Tier 2 acceptance programs |
| `tools/llvm-compile.rkt` | CLI driver: `.prologos` → `.ll` → `clang` → native binary |
| `.github/workflows/llvm-lower.yml` | CI: install clang, run tier acceptance tests |

## 8. Test strategy

### Local

The user runs Racket v9 built from GitHub source. Tests are invoked by `racket` on the user's `PATH`. No hard-coded racket paths. Test commands:

```
# Racket-side unit tests (IR string assertions, no LLVM needed)
racket tools/run-affected-tests.rkt --tests tests/test-llvm-lower.rkt

# End-to-end (requires clang on PATH)
racket tools/llvm-compile.rkt examples/llvm/tier0/exit-42.prologos
./out && echo "exit=$?"
```

### CI

A new GitHub Actions workflow `.github/workflows/llvm-lower.yml`:
1. `actions/checkout@v4`
2. `Bogdanp/setup-racket@v1.11` with `version: '9.0'` (matches existing `test.yml`)
3. `apt-get install -y clang` (Ubuntu runner ships clang via base image; verify version)
4. `raco pkg install --auto --skip-installed`
5. `raco make racket/prologos/driver.rkt racket/prologos/llvm-lower.rkt`
6. **Tier 0 step**: lower + run all `examples/llvm/tier0/*.prologos`, assert exit code matches `:expect <n>` directive
7. **Tier 1 step**: same for tier1
8. **Tier 2 step**: same for tier2
9. **Unit step**: `racket tools/run-affected-tests.rkt --tests tests/test-llvm-lower.rkt`

Each tier's step is independent so a tier-N regression does not mask tier-N+k results. CI runs are gated on this workflow at PR time.

### Acceptance file directives

Each `.prologos` test file ends with a comment of the form:

```
;; :expect-exit 42
```

The test driver parses this directive, lowers the file, runs the binary, and asserts.

## 9. Tier 0 — Literals

### Goal

Compile `def main : Int := 42` to a native binary that exits with code 42.

### Supported AST set

- `expr-int`, `expr-Int`
- The wrapping shape `(list 'def NAME TYPE BODY)` from `elaborate-top-level`
- Optional `expr-ann` around the body (if elaboration emits one for ascription)

### Steps

1. **T0.A — Driver hook**: Modify `process-file` (or add a sibling `process-file-for-llvm`) to return the elaborated top-level forms list. Identify the form whose name is `main`. Extract its body expression and ascribed type.
2. **T0.B — Emitter**: `racket/prologos/llvm-lower.rkt` exports `lower-program : (Listof TopForm) → String`. Tier 0 cases:
   - `expr-int n` → emit `i64 n`
   - body of `main` is a literal → wrap in `define i64 @main() { ret i64 <n> }`
   - All other AST nodes → `(unsupported-llvm-node ...)`
3. **T0.C — Acceptance**: `examples/llvm/tier0/exit-42.prologos` and one negative case (`exit-0.prologos`).
4. **T0.D — CI**: workflow file with the Tier 0 step.

### Validation

- Local: `racket tools/llvm-compile.rkt examples/llvm/tier0/exit-42.prologos --emit-only` produces deterministic IR (snapshotted in unit test).
- CI: `examples/llvm/tier0/*.prologos` exit codes match `:expect-exit` directives.

### Commit message convention

```
SH Track 1 Tier 0: literal Int → main exit code

Adds racket/prologos/llvm-lower.rkt with the closed Tier 0 AST support
(expr-int + main-as-exit-code wrapper). Adds examples/llvm/tier0/,
tests/test-llvm-lower.rkt, tools/llvm-compile.rkt, and the
llvm-lower.yml CI workflow.

Tier 0 supports: expr-int, expr-Int, (def main Int <int-val>).
Any other AST node raises unsupported-llvm-node with source location.

Scaffolding statement (per plan doc § 5): the lowering pass is a Racket
function, not a propagator stratum. Promotion to a stratum is gated on
PPN Track 4D + incremental compilation requirement.
```

## 10. Tier 1 — Arithmetic

### Goal

Compile programs like `def main : Int := [int+ 1 [int* 2 3]]` (exit code 7).

### New AST set (additive)

- `expr-int-add`, `expr-int-sub`, `expr-int-mul`, `expr-int-div`, `expr-int-mod`
- `expr-int-neg`, `expr-int-abs`
- `expr-int-lt`, `expr-int-le`, `expr-int-eq`
- `expr-Bool`, `expr-true`, `expr-false`
- `expr-app` — only the case where the function is one of the primitive nodes above (full `expr-app` defers to Tier 2)

### Open question

The elaborator's `primitive-op-eta-table` returns eta-expanded `expr-lam` wrappers. For inline use like `[int+ 1 2]`, the elaborator may produce either:

(a) `(expr-int-add 1 2)` directly (inlined), or
(b) `((expr-lam ... (expr-lam ... (expr-int-add (expr-bvar 1) (expr-bvar 0)))) 1 2)` (eta-expanded form)

Phase T1.A first investigates which form survives elaboration + zonking. If (b), Tier 1 includes a small beta-reduction step at the lowering boundary (no full reducer; just a one-rule unfolder for primitive eta-redexes). If (a), no additional work.

### Validation

- Tests for each binary op with positive/negative operands
- Tests for each comparison (encoded as exit 0/1)
- Test for nested expressions (`[int+ 1 [int* 2 3]]`)
- Snapshot test of generated IR for one canonical example

### Commit message

`SH Track 1 Tier 1: Int arithmetic + comparisons + Bool literals` with the same scaffolding statement carried forward.

## 11. Tier 2 — Top-level functions

### Goal

```
defn add [x y : Int] := [int+ x y]
def main : Int := [add 5 7]   ; exit 12
```

### New AST set (additive)

- `expr-lam` at top level only, with strict requirements:
  - Multiplicity is `mw` (unrestricted) or `m1` (linear) — emitted as a parameter
  - Multiplicity is `m0` (erased) — parameter dropped, body lowered without it
  - Body has no free variables beyond the lambda's own bvars (i.e. no captures)
- `expr-bvar i` → look up de Bruijn index `i` in the current lowering environment, emit the SSA local name
- `expr-app` — full case: lower function (must resolve to a known top-level definition or primitive), lower args, emit `call`
- `expr-Pi` (when it appears as the type of a top-level def) — recognized but ignored at the type level

### Constraints

- **Closure detector** (T2.D): a free-variable scan over each `expr-lam`'s body. If any `expr-bvar` index reaches *out* of the lambda chain to an outer lambda, raise `(unsupported-llvm-node closure-capture body)` with the offending index. This is the planned failure for Tier 3 features.
- **m0 erasure** (T2.C): for a chain of lambdas, walk left-to-right; for each `expr-lam 'm0`, drop the binder and decrement bvar indices in the body. This is the *degenerate* erasure pass — full erasure (irrelevance propagation, Pi → arrow) is a future track.
- **Function name resolution**: an `expr-app` whose function is `expr-fvar name` resolves to a top-level definition by `name`. If not found and not a primitive, raise unsupported.

### Validation

- `[add 5 7]` exits 12
- Recursion that the runtime can handle without stack overflow (e.g. `fact 5` exits 120) — *if* recursion fits within Tier 2 (a recursive `defn` whose body is just arithmetic + a tail call)
- Closure attempt: a `defn` whose body references a top-level `def` is allowed (resolved as `call`); a nested `fn` that captures must error cleanly.

### Commit message

`SH Track 1 Tier 2: top-level functions, m0 erasure, closure-rejecting`

## 12. Open questions

Resolved at the relevant tier's mini-design (per Per-Phase Protocol):

- **OQ-T0-1**: How is the elaborated top-level form actually exposed by `process-file`? It currently runs but does not return the form list. *Resolution path*: add a `--emit-elaborated` mode or a new `process-file/elaborated` entry. Decide at T0.A.
- **OQ-T1-1**: Eta-expanded vs inlined primitives (see § 10). *Resolution*: investigate at T1.A by printing what `[int+ 1 2]` elaborates to.
- **OQ-T2-1**: Are de Bruijn indices preserved post-zonk for top-level `defn` bodies? *Resolution*: investigate at T2.A.
- **OQ-T2-2**: Does `defn add [x y]` produce one `expr-lam` per parameter (curried) or one with two? Affects bvar arithmetic. *Resolution*: T2.A.
- **OQ-CI-1**: Does the GHA Ubuntu runner ship a clang version compatible with our IR? Local clang is 18.1.3. *Resolution*: pin clang version in CI if the default drifts.

## 13. Acceptance file

Per `ACCEPTANCE_FILE_METHODOLOGY.org`, an acceptance file lives at `racket/prologos/examples/2026-04-30-llvm-tier0-2.prologos`. Sections marked Tier 0 / Tier 1 / Tier 2; commented-out target expressions get uncommented as each tier closes. The file is run via `process-file` before *and* after each tier to confirm no regressions in the elaborator.

---

## Notes for the implementer

- Use `tools/check-parens.sh` after every `.rkt` edit. Skip nothing.
- Use `tools/run-affected-tests.rkt --tests tests/test-llvm-lower.rkt` for targeted runs (per `testing.md` § Targeted tests).
- Conversational checkpoint after each Tier commit (per `workflow.md` § Conversational implementation cadence).
- All-tests-green before tier-N+1 begins.
- Each tier's commit includes the tracker update in the same commit.

