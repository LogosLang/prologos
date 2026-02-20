# Prologos

Functional-logic language unifying dependent types, session types, linear types (QTT), logic programming, and propagators. Phase 0 implementation in Racket (`#lang racket/base`).

## Commands

- **Run tests**: `racket tools/run-affected-tests.rkt` (targeted, with timing) or `--all`
- **Full benchmark**: `racket tools/benchmark-tests.rkt --report`
- **Validate deps**: `racket tools/update-deps.rkt --check`

## Architecture

Source is in `racket/prologos/`. Standard library in `lib/prologos/`. Tests in `tests/`.

### AST Pipeline (14 files, touch all for new AST nodes)

syntax.rkt -> surface-syntax.rkt -> parser.rkt -> elaborator.rkt -> typing-core.rkt -> qtt.rkt -> reduction.rkt -> substitution.rkt -> zonk.rkt -> pretty-print.rkt (+ sometimes unify.rkt, macros.rkt, foreign.rkt)

### Type Checking Pipeline

elaborate -> type-check -> resolve-trait-constraints! -> check-unresolved -> all-failed-constraints -> zonk-final

### Key Patterns

- **Two-phase zonking**: intermediate (preserves unsolved metas) vs final (defaults to lzero/mw)
- **Speculative type-checking**: `save-meta-state`/`restore-meta-state!` for Church fold attempts, union types
- **Dict params use mw** (not m0) to avoid QTT violations when body uses the dict

## Rules

See @.claude/rules/testing.md, @.claude/rules/prologos-syntax.md, @.claude/rules/workflow.md
