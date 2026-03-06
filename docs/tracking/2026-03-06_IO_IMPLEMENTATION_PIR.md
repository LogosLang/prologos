# Post Implementation Review: IO System (IO-A through IO-J)

**Date**: 2026-03-06
**Scope**: Phases IO-A through IO-J of the Prologos IO subsystem
**Duration**: ~36 hours across 2 sessions (2026-03-05 through 2026-03-06)
**Commits**: IO-A1 (`8a2f5d0`) through IO-D5 (`f2dd088`) — 31 total (20 implementation + 8 tracking + 3 design fixes)
**Design Documents**: `docs/tracking/2026-03-05_IO_LIBRARY_DESIGN_V2.md` (Phase I design, ~1000 lines), `docs/tracking/2026-03-05_IO_IMPLEMENTATION_DESIGN.md` (Phase II implementation plan)

---

## 1. Objectives and Scope

### Original Goal

Build a complete IO subsystem for Prologos spanning four layers: opaque FFI
marshalling, IO bridge propagators for session-aware side effects, convenience
functions for file/console/filesystem operations, and capability-secured access
control. The design required integrating IO with the existing session type system,
capability type system, propagator network, and the WS-mode `.prologos` reader
pipeline.

### Planned Scope

29 sub-phases across 10 phases:
- **IO-A**: Foundation types (opaque marshalling, Path/IOError, capability hierarchy extensions)
- **IO-B**: Runtime bridge (IO state lattice, IO bridge propagator, FFI registry)
- **IO-C**: Boundary operations (`proc-open` runtime, integration tests)
- **IO-D**: Convenience functions (file IO, console IO, `with-open` macro, filesystem queries, `main` as powerbox)
- **IO-E**: Session protocols (protocol definitions, session-based file IO, composition tests)
- **IO-F**: Linear handle type (`Handle` ADT with `:1` bracket pattern)
- **IO-G**: Structured data (RFC 4180 CSV parser + Prologos module)
- **IO-H**: Capability inference (wire `run-post-compilation-inference!` into compilation)
- **IO-I**: Dependent capabilities (`cap-entry` struct, applied cap inference)
- **IO-J**: Dependent send/receive (elaborator binder scope, runtime predicates, grammar)

### Actual Scope

**29 of 29 sub-phases completed. 100% scope adherence.**

Originally, D5 (main as powerbox) was deferred pending IO-H (capability inference).
Once IO-H was complete, D5 became unblocked and was implemented as the final
sub-phase.

Minor items correctly deferred to future work:
- `path-parent`, `path-extension`, `path-file-name` (need `substring`/`index-of` in stdlib)
- `list-dir` (needs List type marshalling through FFI)
- `parse-csv-maps` (needs Map construction from pairs)
- Network IO (`proc-connect`/`proc-listen`) — tracked as IO-K in DEFERRED.md
- `throws IOError` exception syntax — deferred to Phase 2

None of these represent scope failure; they are genuine infrastructure dependencies.

---

## 2. What Was Delivered

### Quantitative Summary

| Metric | Value |
|--------|-------|
| New `.prologos` library files | 7 (io, fio, csv, io-protocols, path, io-error, fs) |
| New Racket runtime files | 2 (io-bridge.rkt, io-ffi.rkt) |
| New test files | 20 |
| New tests added | ~226 |
| Modified files (significantly) | ~12 (driver, elaborator, macros, foreign, session-runtime, syntax, surface-syntax, parser, prelude, namespace, batch-worker, dep-graph) |
| Overall test suite growth | 5,535 → 5,860 (+325, +5.9%) |
| New AST node | 1 (expr-opaque) |
| Design decisions documented | 21 (D1-D21 in IO Library Design V2) |
| Sub-phases completed | 29/29 |
| Sub-phases deferred | 0 |
| Regressions introduced | 0 (full suite green after every commit) |

### Architectural Components Delivered

1. **Opaque FFI marshalling** (`expr-opaque` AST node + `Opaque:*` prefix serialization) — type-safe pass-through for Racket values that have no Prologos representation
2. **IO state lattice** (5 elements: `io-bot → io-opening(path,mode) → io-open(port,mode) → io-closed → io-top`) with monotone merge + contradiction detection
3. **IO bridge propagator** (side-effecting fire-fn watching io/session/msg cells) with file open, read, write, close lifecycle
4. **FFI registry** (12 wrapped Racket IO primitives) with marshalling wrappers for EOF, void, port dispatch
5. **Boundary operation runtime** (`proc-open` match arm in `compile-live-process` with IO channel creation)
6. **File/console/filesystem convenience functions** in `.prologos` library modules
7. **`with-open` macro** (preparse expansion to `proc-open` + body + auto-close)
8. **Session IO protocols** (`FileRead`/`FileWrite`/`FileAppend`/`FileRW`) with direct IO execution
9. **Linear handle type** (`Handle` ADT with `:1` Pi types, bracket pattern, read-and-cache trick)
10. **RFC 4180 CSV module** (parser + serializer + Prologos module with RS/US boundary encoding)
11. **Capability inference pipeline** (`run-post-compilation-inference!` hooked into `process-string`/`load-module`)
12. **Dependent capabilities** (`cap-entry` struct replacing bare symbols in `cap-set`, applied cap type extraction)
13. **Dependent session operations** (elaborator scope threading via Racket parameters, runtime `sess-dsend?`/`sess-drecv?`)
14. **`main` as powerbox** (SysCap provisioned for `main` and top-level evals, `:requires` annotations on foreign blocks)

### Three-Tier Progressive Disclosure

The IO system implements the three-tier progressive disclosure model from the V2 design:

- **Tier 1**: `defn main [] [read-file "data.csv"]` — no capabilities visible, `main` provisions SysCap implicitly
- **Tier 2**: `spec reader ReadCap -0> String -> String` — explicit capability in function signature
- **Tier 3**: `{cap :0 FileCap "/etc/app.conf"}` — dependent path-scoped capabilities + session protocols

---

## 3. What Went Well

### 3a. Two-Document Design Process Was Effective

The IO system benefited from a two-document design cycle:
- **V2 Library Design** (~1000 lines, 15 sections) — architectural vision, capability hierarchy, progressive disclosure tiers, module structure
- **Implementation Design** (25 sections, 29 sub-phases, ~199 tests planned) — concrete file-by-file plan with dependency graph

The V2 design caught fundamental issues early: the `World :1` token approach was
rejected in favor of fine-grained capabilities, the hybrid io/fio module split was
designed, and the double-boundary model (compile-time caps + runtime session advancement)
was established before any code was written. The implementation plan then translated
these decisions into actionable sub-phases.

### 3b. Session Type Infrastructure Paid Dividends

The session type system (S1-S8), completed just before IO work began, provided
ready-made infrastructure:
- `proc-open` plugged directly into `compile-live-process` (S7 runtime)
- IO protocols (`FileRead`/`FileWrite`) used the existing session type parser, elaborator, and propagator checker
- Dependent send/receive (IO-J) extended the session AST with minimal friction
- The `with-open` macro reused the WS preparse `proc-item->sexp` pipeline

This confirmed the "propagator lattice of lattices" architecture: each new domain
slots into the existing network without modifying core propagator infrastructure.

### 3c. Capability System Integration Was Clean

The capability type system — originally a simple registry with subtype relationships —
scaled to handle:
- Foreign function capability annotations (`:requires` on foreign blocks)
- Erased cap parameters in function types (`-0>` multiplicity arrow)
- Implicit resolution via `insert-implicits-with-tagging`
- Subtype-based satisfaction (`SysCap` satisfies `ReadCap` via transitive chain)
- Dependent capabilities with applied indices (`FileCap "/data"`)
- Post-compilation inference (`run-post-compilation-inference!`)

All of this worked through the existing `:0` Pi binder mechanism. The capability
system never required new AST nodes for the resolution machinery — capabilities
are just types with special treatment in the elaborator.

### 3d. The Hybrid IO/FIO Model Worked

The design decision (D2, Option C) to provide both session-based IO (`prologos.core.io`)
and linear-handle IO (`prologos.core.fio`) proved correct:
- `io` module: Simple string-in/string-out convenience functions. Users write
  `[read-file path]` and get a string back. No ceremony.
- `fio` module: Linear handles for users who need resource safety guarantees.
  `fio-with-file` bracket pattern ensures cleanup.

The two modules serve different levels of the trust model without competing.

### 3e. Implementation Order Flexibility

The original plan projected a linear IO-A → IO-B → ... → IO-J ordering. In practice,
IO-J (dependent sessions) was implemented before IO-F (linear handles) and IO-G (CSV),
because the dependency graph allowed it. The progress tracker table made this
reordering visible and traceable. The final sub-phase (IO-D5) was originally slotted
after IO-D4 but was correctly deferred until IO-H was complete, then implemented
last — demonstrating that the phase dependency analysis in the design doc was accurate.

---

## 4. What Was Challenging

### 4a. Propagator Networks Cannot Order Side Effects

The most significant architectural discovery of the entire IO implementation.
The original design assumed IO bridge propagators would handle file operations:
watch session cells, fire on session advancement, execute IO side effects during
propagation.

In practice, flat propagator networks provide **no ordering guarantees**. During
`run-to-quiescence`, propagators fire in whatever order the worklist produces.
This means a "close" propagator can fire before a "write" propagator, corrupting
the IO sequence. The problem is fundamental: propagators compute monotone fixed
points, not sequential instruction streams.

**Resolution**: Direct IO execution during `compile-live-process`. IO side effects
(file reads, writes, closes) execute inline as the compilation walk encounters
them, not via deferred propagators. The IO bridge propagator was retained for
state tracking but not for sequencing.

**Lesson**: Propagator networks are the right tool for convergent computation
(type checking, inference, constraint solving). They are the wrong tool for
sequencing effects. This distinction is now codified.

### 4b. The Batch Worker Parameter Gap

IO-D5 uncovered a latent bug in the test infrastructure. The batch worker
(`tools/batch-worker.rkt`) saves/restores ~25 Racket parameters between test files
to maintain isolation. But `current-capability-registry` was missing from this list.

The symptom was subtle: tests passed individually (`raco test`) but failed in the
batch runner (`run-affected-tests.rkt`). Without the cap registry, `capability-type-expr?`
returned `#f` during module loading, so `:0` lambda binders weren't recognized as
capability types and weren't pushed into `current-capability-scope`, causing E2001
errors.

**Resolution**: Added `current-capability-registry` to the batch worker's save/restore
list.

**Lesson**: Any new Racket parameter introduced in `macros.rkt` or `namespace.rkt`
needs a corresponding entry in `batch-worker.rkt`. This should be documented as a
checklist item for future parameter additions.

### 4c. Data-Flow Tricks for Lazy Evaluation

Prologos uses lazy evaluation (call-by-need). FFI functions with side effects must
be forced to evaluate, but the reducer only evaluates terms in data-flow position
(constructor arguments, match scrutinees). Functions returning `Unit` are particularly
problematic — `(write-file path data)` might never be evaluated if its result isn't
used.

The IO-F implementation required three tricks:
1. **Return-handle pattern**: `fio-write-ret` returns the handle ID (not void) so the FFI call is in the data flow
2. **Read-and-cache pattern**: `fio-read-ret` reads eagerly + caches, returns handle ID; `fio-read-cached` retrieves — forces read before close
3. **Match-on-unit pattern**: `(match (fio-close h) (unit -> result))` forces the close side effect by pattern-matching on the return value

These tricks are specific to the lazy evaluation model and would not be needed in
a strict language.

### 4d. RS/US Boundary Encoding for Structured FFI Data

The Prologos FFI passes only strings (no structured data marshalling for List types).
To pass CSV data (lists of lists of strings) through this boundary, the implementation
uses ASCII Record Separator (30) and Unit Separator (31) characters as delimiters —
an encoding that's invisible in normal text but allows structured data to survive
the string-only boundary.

This worked but highlights the need for richer FFI marshalling in the future. The
List type marshalling gap (tracked in DEFERRED.md) would eliminate this class of
workaround.

---

## 5. How Results Compared to Expectations

### 5a. Scope: 100% Adherence

All 29 planned sub-phases were completed. No sub-phase was abandoned or reduced
in scope. The correctly-deferred items (path helpers, `list-dir`, CSV maps) are
genuine infrastructure dependencies, not scope failure.

### 5b. Test Count: Close to Projection

The implementation design projected ~199 tests. Actual: ~226 new tests (+14% over
projection). The overshoot came primarily from:
- Diagnostic tests for capability subtype satisfaction (IO-D5)
- Additional E2E WS pipeline tests (IO-J3)
- CSV Racket-side tests that weren't in the original projection (IO-G1)

### 5c. Architecture: Double-Boundary Model Validated (with Caveats)

The V2 design's double-boundary model was validated:
1. **Compile-time**: Capability annotations on foreign blocks + inference pipeline
   detect unauthorized IO at compile time
2. **Runtime**: Session types advance through IO operations, with bridge propagators
   tracking state

The caveat: runtime IO execution is direct (not propagator-mediated), which means
the "double boundary" is really compile-time caps + direct runtime execution with
session state tracking. The bridge propagator monitors state but doesn't sequence
operations.

### 5d. Design Decisions: All 21 Held

None of the 21 design decisions (D1-D21) needed to be reversed during implementation.
The most consequential decisions that proved correct:
- **D2**: Hybrid io/fio model (both convenience and safety paths)
- **D17**: Composite caps as union-type semantics via `capability` + `subtype`
  (pragmatic over pure union types, functionally identical)
- **D19**: `main` as powerbox (simple, effective, covers Tier 1 completely)
- **D21**: IO error codes for clear E2001/E2004 diagnostics

---

## 6. What This Enables Going Forward

### 6a. Real-World Programs

Prologos can now write programs that interact with the external world: read/write
files, parse CSV data, query the filesystem, print to console. The `main` powerbox
means simple programs "just work" without capability ceremony.

### 6b. Network IO (IO-K)

The boundary operation infrastructure (`proc-open`) was designed to extend to
`proc-connect` (TCP/HTTP) and `proc-listen` (server sockets). The IO bridge,
FFI registry, and session protocol patterns established in IO-B/C/E directly
transfer.

### 6c. Database Access

The capability hierarchy already includes `DbReadCap`/`DbWriteCap` (designed but
not implemented). The FFI, bridge, and convenience function patterns from IO-D
provide the template.

### 6d. Richer Error Handling

The `IOError` ADT (IO-A2) and capability error codes (E2001, E2004) provide the
foundation. The deferred `throws IOError` exception syntax would enable
Result-free error handling in IO-heavy code.

### 6e. Schema-Typed CSV

The CSV module (IO-G) currently returns `List (List String)`. A `parse-csv-maps`
variant returning `List (Map String String)` (header-keyed) was deferred but is
straightforward given the existing RS/US encoding.

### 6f. Capability Audit Tooling

The REPL commands (`cap-closure`, `cap-audit`, `cap-verify`, `cap-bridge`) from
IO-I provide interactive capability introspection. These could evolve into a
security audit tool that verifies capability compliance across an entire project.

---

## 7. Integration with Other System Components

### 7a. Propagator Network

IO adds the fourth domain to the propagator network (after types, multiplicities,
and sessions). The IO bridge propagator uses the same `net-add-propagator` /
`run-to-quiescence` infrastructure. The key finding — propagators don't sequence
effects — doesn't diminish their value for state tracking and convergent computation.

### 7b. Session Types

IO protocols (`FileRead`/`FileWrite`/`FileAppend`/`FileRW`) are session types.
`proc-open` creates an IO channel that participates in the session type system.
Dependent sessions (IO-J) enable protocols like "send a length, then send that
many messages." The session type PIR's recommendation to "build real IO for
boundary operations" has been fulfilled.

### 7c. Capability Types

Capabilities gained three new powers through the IO implementation:
1. **Foreign function annotations**: `:requires (ReadCap)` on foreign blocks
2. **Post-compilation inference**: `run-post-compilation-inference!` detects
   underdeclared authority roots
3. **Dependent capabilities**: `FileCap "/data"` scopes authority to specific paths

The `main` powerbox connects the capability hierarchy to program entry, completing
the security story: capabilities flow from `main` → called functions, with the
inference engine verifying the flow.

### 7d. QTT (Quantitative Type Theory)

The `fio` module demonstrates `:1` (linear) IO handles — resources that must be
used exactly once. The QTT checker enforces this: unused handles and double-used
handles produce multiplicity errors. This is the first practical use of linear
types in the Prologos standard library.

### 7e. WS Reader Pipeline

Every IO feature has WS-mode tests verifying the full `.prologos` reader pipeline.
The WS reader handled IO-specific syntax without modification:
- `foreign racket "file.rkt" :requires (Cap) [name :as alias : Type]`
- `-0>` multiplicity arrow in `spec` declarations
- `with-open` / `proc-open` in process contexts
- Dependent session operators in WS process bodies

---

## 8. Lessons Learned

### Process Lessons

1. **Two-document design (vision + implementation plan) scales to large features**.
   The V2 Library Design provided the "why" and "what"; the Implementation Design
   provided the "how" and "when." Neither alone was sufficient — the vision doc
   without the implementation plan would have left sub-phase ordering ambiguous;
   the implementation plan without the vision doc would have made architectural
   decisions ad hoc.

2. **Phase dependency graphs enable implementation reordering**. IO-J was implemented
   before IO-F and IO-G because the dependency graph showed they were independent.
   IO-D5 was correctly deferred until IO-H. The explicit dependency graph in the
   implementation plan was essential for this flexibility.

3. **External critique improves design**. The implementation plan underwent personal
   feedback (commit `e3261a3`) and external critique (commit `5beb655`, 9 items).
   Four were accepted fully, two partially, three rejected with reasoning. The
   accepted items caught real issues: performance concerns for fio session overhead,
   StdioCap inference for console IO, and `main` sequential-only constraint.

4. **Batch worker parameter sync is a maintenance burden**. Every new Racket parameter
   needs an entry in three places: its `make-parameter` definition, test-support.rkt's
   ready-state capture, and batch-worker.rkt's save/restore. Missing any one causes
   batch-only test failures that are extremely difficult to diagnose.

### Technical Lessons

5. **Propagators compute fixed points, not sequences**. Propagator networks are
   excellent for monotone convergence (type checking, cap inference, lattice
   operations). They are wrong for sequencing side effects. IO operations must
   execute directly, not via deferred propagators. This is the single most important
   architectural lesson of the IO implementation.

6. **Lazy evaluation requires data-flow tricks for side effects**. FFI functions
   with side effects must return values that are consumed by the program's data
   flow, or they may never execute. The return-handle, read-and-cache, and
   match-on-unit patterns are the standard workarounds.

7. **The `:0` Pi binder mechanism is powerful and general**. Capabilities, trait
   constraints, and type-class dictionaries all use `:0` Pi binders resolved by
   `insert-implicits-with-tagging`. Adding capability annotations to foreign
   blocks required zero new resolution machinery — just prepending `:0 Pi` binders
   to the function type.

8. **Module loading and test execution have different parameter contexts**. During
   module loading, parameters like `current-capability-registry` and
   `current-capability-scope` may not be populated. Functions that depend on these
   parameters (like `capability-type-expr?`) must handle the empty case, or the
   module loading context must ensure the parameters are populated before
   cap-annotated modules are loaded.

9. **RS/US encoding works but is a code smell**. Using ASCII control characters
   to encode structured data through a string-only FFI boundary is effective but
   fragile. Richer FFI marshalling (List, Map types) would eliminate this class of
   workaround.

10. **`spec`/`defn` cannot express `:1` multiplicity**. The syntactic sugar assumes
    `:w` (unrestricted) multiplicity for all parameters. Linear IO handles must use
    the sexp `(def name : (Pi (h :1 Handle) ...) ...)` form. This is a known
    limitation tracked in DEFERRED.md.

---

## 9. Recommendations

### For Network IO (Next IO Phase)

1. Follow the same two-document design process. Network IO introduces new concerns
   (connection lifecycles, timeouts, TLS) that need vision-level design before
   implementation planning.
2. Reuse the IO bridge + FFI registry pattern from IO-B/B3. The `io-ffi-registry`
   approach (string-keyed dispatch table) extends naturally to socket operations.
3. Use direct IO execution (not bridge propagators) for network operations, following
   the IO-E2 architectural decision.

### For the Codebase

4. Add List/Map FFI marshalling to eliminate the RS/US encoding workaround. This
   unblocks `list-dir`, `parse-csv-maps`, and future structured data functions.
5. Consider a `-1>` multiplicity arrow in `spec` for linear parameters, enabling
   `fio` functions to use `spec`/`defn` instead of sexp `def`.
6. Add a "new parameter checklist" to CLAUDE.md or a development guide documenting
   that new `make-parameter` definitions need entries in test-support.rkt and
   batch-worker.rkt.

### For the Process

7. Continue the PIR practice for features spanning >10 sub-phases. Both the session
   type PIR and this IO PIR have captured lessons that directly prevent future bugs.
8. The design → critique → revise cycle (V2 design → personal feedback → external
   critique → implementation) produced the highest-quality design decisions. Apply
   this pattern to future large features.
9. Consider automated testing of batch-worker parameter completeness — a test that
   compares all exported parameters from macros.rkt/namespace.rkt against the
   batch-worker's save/restore list.

---

## 10. Conclusion

The IO implementation achieved its full scope: Prologos now has a complete IO
subsystem spanning opaque FFI marshalling, session-aware IO bridges, file/console/
filesystem convenience functions, linear handle types, CSV structured data, capability
inference, dependent capabilities, dependent sessions, and the `main` powerbox. All
29 sub-phases were completed with zero regressions and zero scope failures.

The most significant architectural outcome is the validation — and correction — of
the propagator-based IO model. Propagators remain the right tool for capability
inference, session type checking, and IO state tracking. But the discovery that
propagator networks cannot sequence side effects fundamentally shaped the IO-E2
implementation: IO operations execute directly during process compilation, with
propagators monitoring state but not controlling execution order. This distinction
between convergent computation and sequential effects is now understood and documented.

The capability security story is complete: IO functions carry capability proofs in
their types (via `:requires` on foreign blocks), `main` provisions `SysCap` as the
root of the trust chain, the inference engine detects underdeclared authority roots
(E2004), and dependent capabilities scope authority to specific resources. This
makes Prologos's IO system capability-secure by construction, not by convention.

**Final metrics**: 31 commits, 29 completed sub-phases, 7 new library files + 2
runtime files + 20 test files, ~226 new tests, 5,535 → 5,860 test suite (+5.9%),
zero regressions, zero scope failures.
