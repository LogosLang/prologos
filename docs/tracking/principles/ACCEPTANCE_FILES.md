# Acceptance File Best Practices

**Created**: 2026-03-16
**Status**: Living document
**Location**: `racket/prologos/examples/{date}-{feature}.prologos`

Acceptance files are diagnostic instruments, regression nets, and living showcases of the language. They are written *before* implementation begins and run *after* each phase. A track is not done until its acceptance file runs with 0 errors via `process-file`.

---

## 1. When to Write

Write the acceptance file as **Phase 0**, before any implementation code. This is non-negotiable — it's the first artifact of every implementation track.

The acceptance file establishes:
- What works today (baseline)
- What should work after implementation (aspirational targets)
- What's already broken and unrelated to this track (pre-existing L3 gaps)

Writing the file first forces confrontation with the full pipeline — top-level scoping, file-level preparse, multi-form interaction — before implementation narrows focus to internals. Issues discovered during acceptance file authoring are design inputs, not surprises.

---

## 2. Two Roles: Regression Net vs. Feature Showcase

Acceptance files serve one of two roles depending on track type:

### Syntax-adding tracks (e.g., WFLE, dot-access, implicit maps)

The file is a **feature showcase**. New syntax starts commented out with aspirational annotations. As phases complete, expressions are uncommented. The file demonstrates the new capability envelope.

- Organize by **capability** (baseline existing features, new syntax forms, interactions with existing features, edge cases)
- Commented-out sections are the implementation targets
- Each phase should have a clear mapping: "Phase N unlocks Section X"

### Infrastructure tracks (e.g., Track 3 cell-primary, Track 4 ATMS, Track 5 module networks)

The file is a **broad regression net**. No new syntax is added, so the file exercises the systems that the infrastructure change *affects*. The goal is comprehensive coverage of the subsystem's consumers.

- Organize by **consumer** — which parts of the language exercise the subsystem being changed
- All expressions should pass at baseline (Phase 0); any that don't are pre-existing gaps
- The file's value is in confirming that nothing broke, across a wide surface area

Both roles share the same conventions (§4) and validation protocol (§6).

---

## 3. What to Include

### For every acceptance file

- **Broad prelude exercise**: Full `ns` (not `:no-prelude`). Exercise standard library features — Nat, Bool, List, Option, Result, Pair, Eq/Ord/Add/Sub/Mul traits and instances. The prelude is the most common consumer of every subsystem.
- **Cross-feature compositions**: Don't just test features in isolation. Combine them: generic arithmetic inside closures, polymorphic functions applied to union-typed values, pipelines ending in trait-constrained functions, pattern matching on data types returned by higher-order functions. Bugs live in the spaces *between* features.
- **Grammar-driven targets**: Walk the grammar file (`docs/spec/grammar.ebnf`) and ask: "have we exercised production X inside context Y at L3?" Each grammar production that interacts with the track's scope should have at least one acceptance expression. This is the most reliable source of compositional targets.
- **Depth**: Deep nesting, long chains, multiple interacting features in one expression. Shallow tests pass; deep compositions reveal edge cases.
- **Edge cases relevant to the track**: For infrastructure tracks, this means the specific patterns the implementation changes (e.g., Track 5: definition failure cleanup, module loading, cross-module lookup, definition re-export chains).

### For syntax-adding tracks

- **Every new syntax form** proposed in the design doc, exercised at L3
- **Aspirational ideal syntax** for forms that don't work yet — commented out with context explaining expectations and hypotheses for why they don't work. These are targets to return to.
- **Interaction with existing syntax**: New forms composed with existing features (e.g., new `solver` form used inside `let`, inside pipelines, with where-clauses)

### For infrastructure tracks

- **Consumer-organized sections**: Identify every subsystem that consumes the infrastructure being changed, and dedicate a section to each. For Track 5 (global-env), consumers include: trait resolution (instance lookup), module imports (env snapshot), where-clause generics (dict lookup), qualified access (module cache), definition failure paths (cleanup), pattern matching (constructor lookup).
- **Affected code paths**: If the design doc identifies specific code paths that change behavior (e.g., "module loading now runs with networks"), exercise those paths explicitly.
- **Performance canaries**: Include expressions that exercise the hot paths — large lists, deep recursion, many-definition modules. Not for benchmarking, but to catch catastrophic regressions (the 850s pattern-kind regression was exactly this class of issue).

### Creativity over copying

Do not copy-paste from existing test files. The test suite already covers unit-level behavior. The acceptance file's value is in *novel compositional targets* that stretch coverage into untested territory. Think of new combinations:

- Functions that call functions that use traits that depend on module imports
- Definitions that shadow prelude names, then get referenced by later definitions
- Cross-module dependency chains three levels deep (A imports B imports C)
- Closures capturing generic-dispatched values
- Pipeline operators applied to relational solve results

The WFLE acceptance file's Nixon diamond, win/lose game positions, and self-referential paradoxes are good examples — novel scenarios designed to stress the system, not reproductions of existing tests.

---

## 4. Conventions

### Syntax style

Acceptance files are living showcases of the language. They must use **ideal WS syntax** as defined in `.claude/rules/prologos-syntax.md`. Key points:

- **Multi-arity `defn`** for constructor dispatch — `defn foo | zero -> ... | suc k -> ...`, NOT `defn foo [x] match x | ...`
- **`[]` for all functional contexts** — application, lambda, partial application. Never `()` for these.
- **Partial application with wildcards** over inline lambdas — `[int* _ 2]` not `[fn [x] [int* x 2]]`
- **`def` at top level**, never `let` (which is not legal at top level in `.prologos` files)
- **Minimize `if`** — prefer structural pattern matching. `if` is essentially redundant with Bool dispatch.
- **Prefer type inference** — `def x := 42` over `def x : Int := 42` where unambiguous
- **No sexp wrapping** — `(let ...)`, `(fn ...)` are sexp fallback forms. WS ideal uses `def`/`[fn ...]`/multi-arity.

When an ideal syntax form doesn't work yet, comment it out with `IDEAL:` annotation and provide a working fallback. The gap between ideal and working is valuable diagnostic information.

### Header block

Every acceptance file must open with a header block documenting:

```
;; ========================================================================
;;
;;   Track N Acceptance File — [Track Name]
;;
;;   STATUS: Phase 0 (Pre-Implementation Baseline)
;;   Run via: process-file "racket/prologos/examples/{date}-{feature}.prologos"
;;
;;   [Brief description of what the track does and why the file exists]
;;
;;   Conventions:
;;     - Commented-out = aspirational ideal; annotated with BUG/BLOCKED
;;     - Uncommented = must pass today; regression if broken
;;     - [Track-specific syntax conventions]
;;
;;   Sections:
;;     A. [Section name and what it exercises]
;;     B. ...
;;
;; ========================================================================
```

### Annotation protocol

- **Uncommented expressions**: Must pass at Phase 0 baseline. Any failure after a phase is a regression.
- **`BUG (L3): description`**: Pre-existing gap at Level 3. Not a track regression. Include enough context to diagnose: what fails, what the expected behavior is, and a hypothesis for why.
- **`BLOCKED on [section]: reason`**: Depends on another section's BUG being fixed first.
- **`IDEAL: description`**: The aspirational syntax that should eventually work. May differ from the fallback that works today.
- **Status annotations on sections**: `STATUS: WORKING`, `STATUS: BLOCKED`, etc. — especially useful for sections with mixed working/broken expressions.

### Naming

File: `racket/prologos/examples/{date}-{feature}-acceptance.prologos`
Namespace: `ns acceptance::{feature}` or `ns examples.{feature}-acceptance`

---

## 5. Structure

### Section organization

Each section should:
1. Open with a comment block naming the section and what it exercises
2. Have numbered sub-items (`A1`, `A2`, ...) for individual expressions or groups
3. Include expected results as comments (`=> Expected: ...`)
4. Group related expressions (e.g., all Nat arithmetic together, all generic dispatch together)

### Baseline section

Include a "Section Z: Uncommented Baseline" at the end that collects the critical must-pass expressions into a single scannable block. This is the quick-check for regressions — if Section Z passes, the file is likely healthy.

### Phase validation footer

End the file with a phase validation checklist mapping phases to expected section outcomes:

```
;; Phase validation checklist:
;;   Phase 0: Run baseline — all uncommented expressions must pass
;;   Phase 1: [Infrastructure] — no regression; Section X still passes
;;   Phase 2: [Feature] — Sections Y, Z newly passing
;;   ...
;;   Phase N: PIR — benchmark before/after, document findings
;;
;; After each phase: run this file via process-file, verify 0 new failures.
;; Pre-existing BUG/BLOCKED items do not count as regressions.
```

---

## 6. Validation Protocol

### Per-phase validation (mandatory)

After each implementation phase:

1. Run the acceptance file via `process-file` at Level 3
2. Compare results against the previous phase's results
3. Confirm: no new failures (pre-existing BUGs don't count)
4. If the phase was expected to unlock new expressions, uncomment them and verify
5. Note the outcome in the design doc's progress tracker

A phase is not DONE until the acceptance file confirms no regressions at L3.

### Tracking pass counts

The design doc's progress tracker should note acceptance file outcomes per phase. Be specific:

```
| Phase | Status | Acceptance |
|-------|--------|------------|
| 0     | ✅     | 47 expressions pass, 23 commented BUG |
| 1     | ✅     | 47 pass (no regression) |
| 3     | ✅     | 49 pass (+2 uncommented from module loading fix) |
```

This makes regressions immediately visible and provides PIR data.

### Cross-referencing

The acceptance file and design doc should cross-reference:
- Design doc Phase N description says "expected to unlock acceptance sections X, Y"
- Acceptance file's phase footer maps phases to sections
- Dailies note acceptance outcomes per phase

---

## 7. The BUG Annotations Are the Most Valuable Artifact

A well-written acceptance file will have 30-50% of its expressions commented out with BUG annotations at Phase 0. This is not a failure — it's a *diagnostic map* of the L3 gap landscape.

Each BUG annotation documents:
- What the ideal syntax looks like
- What error or failure occurs
- A hypothesis for the root cause
- Whether it's a pre-existing gap or a new regression

Over time, BUG annotations from acceptance files across multiple tracks build a comprehensive picture of L3 gaps. When a future track fixes a gap, the annotation tells you exactly which acceptance expression to uncomment.

Do not remove BUG annotations when they're fixed — change them to a completion note:

```
;; --- A6: Union in both parameter and return ---
;; FIXED (Track 7, Phase 3): union return type now works at L3.
spec echo-union <Int | String> -> <Int | String>
defn echo-union [x] x
```

---

## 8. Lessons from Prior Acceptance Files

### Track 3 (Cell-Primary Registries) — 13 sections, ~712 lines

- Organized by feature domain (patterns, polymorphism, traits, collections, HOFs, data types, dependent types, numerics, strings, maps, modules, generics, bundles)
- Discovered HKT Foldable resolution failure at L3 — a pre-existing gap invisible to unit tests
- Section Z baseline block proved useful for quick regression checks

### Track 4 (ATMS Speculation) — 12 sections, ~1056 lines

- Organized by speculation trigger (union types, nested unions, map widening, generics, Peano, numerics, HOFs, lambdas, data types, collections, quote, combined stress)
- ~40% commented out with BUG annotations — each one a documented L3 gap
- Section L ("Combined Stress Patterns") mixed features compositionally and found unique issues (generic arithmetic in closures, polymorphic identity on union values)
- Performance canary expressions (large lists, deep nesting) caught no regressions but would have caught the 850s pattern-kind regression if it had occurred

### WFLE (Well-Founded Logic Engine) — 9 sections, ~653 lines

- Organized by capability envelope (baseline, solver config, WF semantics, explain/provenance, tabling, advanced relational, functional interaction, type system interaction, edge cases)
- Most creative: Nixon diamond, win/lose game positions, self-referential paradoxes, schema-typed relations
- Novel scenarios stretched the system beyond existing test coverage
- Interaction sections (G: functional language, H: type system) documented the design boundary between relational and functional worlds — valuable architectural documentation even when blocked

### Common pattern across all three

The acceptance file authored at Phase 0 invariably discovers issues that change the implementation plan. HKT Foldable failure (Track 3), foldl parse error (Track 4), and functional-relational bridge gap (WFLE) were all found during acceptance authoring, not during implementation. Write the file early; it will teach you things.
