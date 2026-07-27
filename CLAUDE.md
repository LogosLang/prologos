# Prologos

Functional-logic language unifying dependent types, session types, linear types
(QTT), logic programming, capabilities, and propagator networks. Phase 0
self-hosted compiler in Racket (`#lang racket/base`). WS-mode `.prologos` files
are the primary user-facing syntax; the sexp form is internal IR.

## Design Mantra

> "All-at-once, all in parallel, structurally emergent information flow ON-NETWORK."

This is the gravity of the system. Every propagator install, cell allocation,
loop, parameter, and return value is filtered against it. See
@.claude/rules/on-network.md for operational form and red-flag patterns.

## Glossary

Project-specific acronyms an agent will hit:

- **QTT** — Quantitative Type Theory; multiplicities `m0` (erased), `m1` (linear), `mw` (unrestricted)
- **SRE** — Structural Reasoning Engine; lattice-based structural unification + variance system
- **BSP-LE** — Bulk Synchronous Parallel Logic Engine on propagators
- **PPN** — Propagator-native typing; series bringing elaboration fully on-network
- **ATMS** — Assumption-based Truth Maintenance System; speculation + worldview tracking
- **`.pnet`** — Compiled propagator network cache (module load artifact)
- **Cells vs parameters** — cells are first-class on-network state; parameters are scaffolding being retired

## Quick start

- **Targeted tests**: `racket tools/run-affected-tests.rkt --tests tests/test-X.rkt`
- **Full suite**: `racket tools/run-affected-tests.rkt --all`
- **Investigate failures**: read `data/benchmarks/failures/*.log` (do NOT re-run the full suite)
- **A/B benchmark**: `racket tools/bench-ab.rkt --runs 10 benchmarks/comparative/`
- **Validate deps**: `racket tools/update-deps.rkt --check`
- **Install git hooks**: `tools/install-git-hooks.sh` (one-time per clone; pre-commit + post-commit)
- **Check delimiter balance**: `tools/check-parens.sh <file.rkt>` (also runs in pre-commit hook)

Racket binary on this machine: `"/Applications/Racket v9.0/bin/racket"` (quoted for space).

## Architecture

### Source layout

- `racket/prologos/` — compiler source
- `racket/prologos/lib/prologos/` — standard library (`.prologos` files)
- `racket/prologos/tests/` — test files (use shared fixture pattern from `test-support.rkt`)
- `racket/prologos/examples/` — acceptance files + tutorial programs
- `tools/` + `racket/prologos/tools/` — runners, benchmarks, hooks, linters
- `docs/tracking/` — design docs, dailies, principles, handoffs

### AST pipeline (touch all when adding an AST node)

`syntax.rkt` → `surface-syntax.rkt` → `parser.rkt` → `elaborator.rkt` →
`typing-core.rkt` → `qtt.rkt` → `reduction.rkt` → `substitution.rkt` →
`zonk.rkt` → `pretty-print.rkt` (+ sometimes `unify.rkt`, `macros.rkt`,
`foreign.rkt`, `pnet-serialize.rkt`).

See @.claude/rules/pipeline.md for the exhaustiveness checklist.

### Type-checking pipeline

`elaborate` → `type-check` → `resolve-trait-constraints!` → `check-unresolved`
→ `all-failed-constraints` → `zonk-final`

### Propagator network

The compiler runs on a propagator network: cells hold lattice values,
propagators react to changes, the BSP scheduler fires propagators in parallel
rounds. See @.claude/rules/propagator-design.md for the design checklist
(mantra alignment, fire-once vs broadcast, set-latch fan-in, component-paths).
See @.claude/rules/stratification.md for the strata system (S0 monotone,
S(-1) retraction, S1 NAF, topology).

### Prelude system

`ns foo` auto-imports a Haskell/Clojure-style prelude (Nat, Bool, List, Option,
Result, traits like Eq/Ord/Add/Sub/Mul). Defined as a Racket-side requires list
in `namespace.rkt`. Use `ns foo :no-prelude` to opt out. Library modules
(`prologos.data.*`, `prologos.core.*`) skip the prelude to avoid circularity.

## Key patterns to know

- **PRIMARY DESIGN TARGET**: WS-mode `.prologos` files. Validate at all three levels — sexp, WS string, WS file via `process-file`. Sexp is the IR; users never see it.
- **Two-phase zonking**: intermediate (preserves unsolved metas) vs final (defaults to lzero/mw).
- **Speculative type-checking**: `save-meta-state` / `restore-meta-state!` for Church fold attempts, union types.
- **Dict params use mw** (not m0) to avoid QTT violations when the body uses the dict.
- **Cells over parameters**: when in doubt, use a cell. Parameters are scaffolding marked for migration.

## Rules (auto-loaded via @-references)

- @.claude/rules/on-network.md — design mantra, on-network principle
- @.claude/rules/propagator-design.md — propagator design checklist
- @.claude/rules/stratification.md — strata on the propagator base
- @.claude/rules/structural-thinking.md — SRE lattice lens, Hyperlattice Conjecture
- @.claude/rules/pipeline.md — exhaustiveness checklists for new AST/struct/parameter additions
- @.claude/rules/prologos-syntax.md — WS-mode syntax conventions
- @.claude/rules/testing.md — test commands, benchmarking tiers, hook gates
- @.claude/rules/workflow.md — commit/review/methodology discipline
- @.claude/rules/mempalace.md — experimental semantic-search tool guidelines

## Process documents (docs/tracking/principles/)

For methodology beyond what the rules cover:

- `HANDOFF_PROTOCOL.org` — hot-load + session-continuation protocol; READ FIRST after compact or fresh session
- `DESIGN_METHODOLOGY.org` — 5-stage discipline (research → audit → design → implement → PIR)
- `POST_IMPLEMENTATION_REVIEW.org` — 16-question PIR template
- `CRITIQUE_METHODOLOGY.org` — adversarial framing (P/R/M/S lenses, SRE lattice lens)
- `WORK_STRUCTURE.org` — Series / Track / Audit hierarchy
- `LANGUAGE_VISION.org` + `LANGUAGE_DESIGN.org` — what we're building toward
- `DESIGN_PRINCIPLES.org` — 10 load-bearing principles (cells, decomplection, completeness, etc.)
- `DEVELOPMENT_LESSONS.org` — distilled retros across PIRs (longitudinal patterns)
- `ACCEPTANCE_FILE_METHODOLOGY.org` — Phase 0 acceptance file pattern
- `DAILIES_METHODOLOGY.org` — how to write the dailies (mutable STATE head + append-only LOG) + the Relay-Note re-grounding protocol

Full set + index: `docs/tracking/principles/README.org`

## Tracking + active work

- **Master roadmap**: `docs/tracking/MASTER_ROADMAP.org` — single source of truth
- **Deferred queue**: `docs/tracking/DEFERRED.md`
- **Current dailies**: latest in `docs/tracking/standups/YYYY-MM-DD_dailies.md`
- **Active series**: PPN, PM, SRE, BSP-LE, CIU

## When to read what

| Task | Primary | Then |
|------|---------|------|
| Adding a new AST node | `pipeline.md` | the AST pipeline list above |
| Designing a propagator | `propagator-design.md` | `on-network.md` for mantra alignment |
| Designing a stratum | `stratification.md` | `propagator-design.md` |
| Lattice / merge function | `structural-thinking.md` | SRE lattice lens (6 questions) |
| Writing a `.prologos` example | `prologos-syntax.md` | `examples/` for prior art |
| Running tests / benchmarks | `testing.md` § benchmarking | `tools/` directory |
| Committing / branching / PR | `workflow.md` | hook discipline + commit-message style |
| Resuming after compact | `HANDOFF_PROTOCOL.org` | latest dailies + active design doc |
| Writing dailies / after a rewind | `DAILIES_METHODOLOGY.org` | the STATE head + Relay-Note protocol |
| Designing a new feature | `DESIGN_METHODOLOGY.org` | the 5 stages, mantra audits |
| Adversarial critique round | `CRITIQUE_METHODOLOGY.org` | P/R/M/S lenses, SRE lattice lens |
| Writing a PIR | `POST_IMPLEMENTATION_REVIEW.org` | 16 questions |
| External contributor PR | `workflow.md` § external critique | `gh pr list` for current state |
