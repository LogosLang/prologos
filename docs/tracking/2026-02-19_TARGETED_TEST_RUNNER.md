# Targeted Test Runner — Design & Implementation Log

**Created**: 2026-02-19
**Status**: ✅ Complete
**Commits**: `d2ea461` (initial implementation), `71bbca9` (auto-scan feature)
**Purpose**: Document the design, implementation, and lessons learned for the reverse-dependency DAG-based targeted test runner in `tools/`.

---

## Motivation

The Prologos test suite has grown to **2,717+ tests across 82+ test files**. Full parallel runs (`raco test -j 10`) take significant time. The module architecture is well-layered (reader → parser → elaborator → typing → driver), making it possible to compute exactly which tests are affected by a given source change — avoiding the full suite during iterative development.

Three strategies were considered:
1. **Simple heuristic** — pattern-match filenames to test files (fast but imprecise)
2. **Medium** — source→test mapping without transitive closure (misses indirect deps)
3. **Full reverse-dependency DAG** — three-layer graph with transitive closure (comprehensive)

**Decision**: Option 3. The well-layered architecture makes the DAG tractable (~35 source modules, ~63 .prologos modules, ~82 test files). More pain now, more gain as the project scales.

---

## Architecture

Three files in `racket/prologos/tools/`:

| File | Role | Lines |
|------|------|-------|
| `dep-graph.rkt` | Static DAG data + graph algorithms + auto-scan | ~812 |
| `run-affected-tests.rkt` | CLI entry point (git diff → classify → compute → run) | ~220 |
| `update-deps.rkt` | Validation tool (`--check` mode) | ~260 |

### Three-Layer Dependency Graph

**Layer 1 — Source module forward-deps** (`source-deps`):
- 35 source `.rkt` modules with their `require` dependencies
- Keys are bare filename symbols (e.g., `'parser.rkt`)
- Example: `'parser.rkt → '(source-location.rkt surface-syntax.rkt errors.rkt sexp-readtable.rkt macros.rkt)`

**Layer 2 — Test → source module deps** (`test-deps`):
- `test-dep` struct: `(source-modules uses-driver?)`
- `uses-driver? #t` = integration test (full pipeline, may load .prologos files)
- `uses-driver? #f` = unit test (directly imports specific modules)
- 82 test file entries

**Layer 3 — .prologos library forward-deps** (`prologos-lib-deps`):
- 63 `.prologos` modules with their `require` dependencies
- Keys are dotted module names (e.g., `'prologos.data.list`)

**Layer 3b — Test → .prologos runtime deps** (`test-prologos-deps`):
- Which `.prologos` modules each driver-using test loads at runtime
- ~39 test→prologos mappings

**Layer 2b — Example file mapping** (`example-test-map`):
- Maps `tests/examples/*.rkt` files to `test-lang.rkt` / `test-lang-errors.rkt`

### Core Algorithm: `compute-affected-tests`

```
Input: list of changed files (classified as changed-source/test/prologos/example)

Step 1: Source propagation
  For each changed .rkt source → look up transitive reverse-deps
  → collect all transitively-affected source modules

Step 2: Test inclusion (source path)
  For each test in test-deps → if any source-modules ∈ affected set, include it

Step 3: .prologos propagation
  For each changed .prologos module → look up transitive reverse-deps
  → for each test in test-prologos-deps → if any prologos deps ∈ affected set, include it

Step 4: Direct test inclusion
  Changed test files → always included

Step 5: Example mapping
  Changed example files → include mapped test file

Output: sorted list of test filenames to run
```

Graph algorithms: `invert-dag` (forward → reverse), `transitive-closure` (BFS from start nodes). Reverse DAGs precomputed at module load time (< 1ms for ~35 nodes).

---

## Design Decisions

### Why hardcoded data + auto-scan (not pure auto-discovery)?

- **Precision**: Regex-based auto-scanning is approximate. It over-counts (finds module names in comments/strings) and under-counts (misses indirect deps). Hand-curated data from code inspection is more accurate.
- **Speed**: Hash table lookups are O(1). No filesystem I/O on the hot path.
- **Auto-scan as fallback**: When unknown modules are detected (new files not in the DAG), auto-scan reads their actual `require` forms from disk, patches the in-memory DAG, and proceeds with targeted testing. No manual intervention needed for day-to-day work.
- **`update-deps.rkt --check`** validates the hardcoded data against actual requires, catching drift.

### Why BFS transitive closure?

A change to `prelude.rkt` affects `syntax.rkt` (directly), which affects `parser.rkt` (via syntax.rkt), which affects many tests. Simple one-hop lookups would miss these chains. BFS from the changed node through the reverse DAG captures all transitive dependents.

### Why conservative fallback for unknown files?

When `compute-affected-tests` encounters a module not in the hardcoded DAG, there are two options:
1. **Ignore it** — risk missing affected tests (dangerous)
2. **Auto-scan + targeted** — read the file's requires from disk, patch the DAG, proceed normally

We chose option 2 (auto-scan) as the primary strategy, with "run ALL tests" as the ultimate fallback if the file doesn't exist on disk.

---

## Implementation Milestones

| Step | What | Status |
|------|------|--------|
| 1 | Create `tools/` directory | ✅ |
| 2 | `dep-graph.rkt` — hardcode all 3 layers + graph algorithms | ✅ |
| 3 | `run-affected-tests.rkt` — CLI with git integration | ✅ |
| 4 | `update-deps.rkt` — require parser + `--check` mode | ✅ |
| 5 | Validation — `--dry-run` and `--check` verified | ✅ |
| 6 | Unknown-file safety fallback | ✅ |
| 7 | Auto-scan of unknown modules (patches in-memory DAG) | ✅ |

---

## Key Lessons

### `#lang` handling in Racket's `read`
Racket's `read` function fails on files starting with `#lang racket/base` because `#lang` is a reader extension, not a standard s-expression. Must call `(read-language port (lambda () (void)))` before reading forms. Applied to both `scan-rkt-requires` and `scan-test-source-deps`.

### `#%variable-reference` for path anchoring
Using `(current-directory)` to compute project paths breaks when the CWD isn't expected. Instead, anchor from the script's own module location:
```racket
(define tools-dir
  (let ([src (resolved-module-path-name
              (variable-reference->resolved-module-path
               (#%variable-reference)))])
    (simplify-path (path-only src))))
```
This is reliable regardless of where the script is invoked from.

### Regex scanner imprecision vs hand-curated data
The `update-deps.rkt --check` mode reports ~54 mismatches between auto-scanned and hand-curated data. These are expected:
- Scanner finds module names in comments/strings (over-count)
- Scanner misses dynamically-computed requires (under-count)
- Hand-curated data reflects actual code-level understanding

This validates the design choice of hardcoded data as the primary source of truth.

### Path classification patterns
Git produces paths relative to repo root (`racket/prologos/syntax.rkt`). These must be classified into one of five categories:
- Source `.rkt` (top-level, not in subdirs)
- Test `.rkt` (in `tests/`)
- `.prologos` lib (in `lib/prologos/`)
- Example `.rkt` (in `tests/examples/`)
- Irrelevant (docs, tools, files outside prologos)

The `classify-path` function handles all cases including `info.rkt` (triggers run-all) and `lib/examples/*.prologos` (maps to `test-lang.rkt`).

---

## Verification Results

| Scenario | Result |
|----------|--------|
| `--dry-run` (default, diff against HEAD) | Correctly classifies paths, lists affected tests |
| `--against HEAD~1` (naming cleanup commit) | 76/82 tests (correct — widespread rename) |
| `--all --dry-run` | Lists all 82 test files |
| `posit-impl.rkt` changed | 73 tests (correct: high fan-out through reduction.rkt) |
| Single test file changed | 1 test |
| `prologos.data.datum` changed | 2 tests (introspection + quote) |
| `prologos.core.hashable-trait` changed | 1 test |
| Unknown source module (auto-scan, with project-root) | Auto-scans requires, proceeds with targeted testing |
| Unknown source module (no project-root) | Falls back to all 82 tests |

---

## Expected Impact

| Changed file | Tests affected | Est. time |
|---|---|---|
| `pretty-print.rkt` | ~8 tests | ~10s |
| `reduction.rkt` | ~20 tests | ~30s |
| `parser.rkt` | ~25 tests | ~40s |
| Single `.prologos` lib | ~5-15 tests | ~15s |
| Single test file | 1 test | ~3s |
| `prelude.rkt` | ~70 tests | ~full |
| `driver.rkt` | ~55 tests | ~90s |

---

## Edge Cases

| Case | Handling |
|------|----------|
| New untracked test file | `git ls-files --others` catches it; always re-runs itself |
| New source module (unknown) | Auto-scan from disk if `project-root` provided; else run ALL |
| New .prologos module (unknown) | Auto-scan from disk if `project-root` provided; else run ALL |
| Deleted module | Skipped silently if not in dep graph |
| Changed file outside `prologos/` | Ignored by path normalization |
| Changed `info.rkt` | Run all tests (package metadata) |
| Changed `tools/*.rkt` | Ignored (meta-tooling) |

---

## Usage

```bash
# Run only tests affected by current changes
racket tools/run-affected-tests.rkt

# Preview affected tests without running
racket tools/run-affected-tests.rkt --dry-run

# Diff against a branch
racket tools/run-affected-tests.rkt --against main

# Run everything
racket tools/run-affected-tests.rkt --all

# Validate hardcoded dep data
racket tools/update-deps.rkt --check
```

## Future Work

- `update-deps.rkt --write` mode (auto-update `dep-graph.rkt` data section)
- CI integration (run `--check` as pre-commit hook)
- Performance metrics logging (actual vs estimated time savings)
