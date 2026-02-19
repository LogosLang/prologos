# Test Skip/Bypass Mechanism — Design Document

**Created**: 2026-02-19
**Status**: ⬚ Not Started
**Purpose**: Design a robust, user-configurable mechanism to bypass known pathological tests without code changes.

---

## Motivation

`test-pipe-compose.rkt` takes >60 min and blocks full-suite runs. Even after fixing that specific issue, we need a general mechanism for:
- Known slow tests during development
- Tests broken by in-progress refactors
- Platform-specific test failures
- Any future pathological test discovered

The mechanism should be simple, explicit, and overridable.

---

## Design

### Skip List File: `tests/.skip-tests`

Simple plaintext, one test per line, `#` for comments. Optional inline reason after `#`:

```text
# Pathological tests — see docs/tracking/ for details
# Format: filename  # reason
test-pipe-compose.rkt  # >60min, quadratic module reload — see 2026-02-19_PIPE_COMPOSE_AUDIT.md
```

**Why this format**:
- Simple (no syntax knowledge needed)
- Inline documentation of reasons
- Easy to parse in Racket
- Git-trackable (shared across developers)
- Follows `.gitignore` / `.dockerignore` conventions

### Interception Point

In `run-affected-tests.rkt`, **between** `compute-affected-tests` and `run-tests`:

```
git diff -> classify -> compute-affected-tests -> [FILTER HERE] -> run-tests
```

The filter also applies in `--all` and `force-all?` branches.

### CLI Flags

| Flag | Effect |
|------|--------|
| *(default)* | Apply skip list from `tests/.skip-tests` |
| `--no-skip` | Ignore skip list completely, run everything |
| `--skip FILE` | Add additional file to skip (additive with skip list) |
| `--skip-only` | Invert: run ONLY the normally-skipped tests |

### Reporting

**Normal mode** (to stderr, so it doesn't interfere with test output):

```
Skipping 1 known pathological test(s):
  test-pipe-compose.rkt  (>60min, quadratic module reload)

Affected tests (15 of 82, 1 skipped):
  test-parser.rkt
  ...

--- Running 15 test files with -j 10 ---
```

**`--dry-run` mode** (separate section for clarity):

```
Affected tests (16):
  test-parser.rkt
  test-pipe-compose.rkt  [SKIPPED]
  ...

Skipped (1):
  test-pipe-compose.rkt  (>60min, quadratic module reload)

Would run 15 test files.
```

**Edge cases**:
- Skip file missing: no tests skipped, no warning (file is optional)
- Skip file has unknown test: warning to stderr, continue
- All affected tests skipped: "No tests to run (all affected tests are skipped)."

---

## Implementation

### Changes to `run-affected-tests.rkt` (~40 lines added)

**1. Add `read-skip-list` function** (after line 93):

```racket
;; Read skip list. Returns list of (symbol . reason-or-#f) pairs.
(define (read-skip-list tests-dir)
  (define skip-file (build-path tests-dir ".skip-tests"))
  (if (file-exists? skip-file)
      (call-with-input-file skip-file
        (lambda (in)
          (for/list ([line (in-lines in)]
                     #:let ([trimmed (string-trim line)])
                     #:when (and (not (string=? trimmed ""))
                                 (not (string-prefix? trimmed "#"))))
            (define parts (string-split trimmed "#" #:trim? #f))
            (define filename (string-trim (car parts)))
            (define reason (and (> (length parts) 1)
                                (string-trim (string-join (cdr parts) "#"))))
            (cons (string->symbol filename) reason))))
      '()))
```

**2. Add CLI parameters** (after line 102):

```racket
(define no-skip? (make-parameter #f))
(define skip-only? (make-parameter #f))
(define extra-skips (make-parameter '()))
```

**3. Add CLI flags** (in `command-line` form):

```racket
["--no-skip" "Ignore .skip-tests, run all affected tests"
 (no-skip? #t)]
["--skip" file "Skip an additional test file"
 (extra-skips (cons (string->symbol file) (extra-skips)))]
["--skip-only" "Run ONLY the normally-skipped tests"
 (skip-only? #t)]
```

**4. Add filter function** (used in all code paths):

```racket
(define (apply-skip-filter test-list tests-dir)
  (cond
    [(no-skip?) (values test-list '())]
    [else
     (define skip-entries (read-skip-list tests-dir))
     (define all-skips
       (append (map car skip-entries)
               (extra-skips)))
     (define filtered (filter (lambda (t) (not (member t all-skips))) test-list))
     (define actually-skipped (filter (lambda (t) (member t all-skips)) test-list))
     ;; Report to stderr
     (unless (null? actually-skipped)
       (eprintf "Skipping ~a known pathological test(s):\n" (length actually-skipped))
       (for ([t (in-list actually-skipped)])
         (define entry (assq t skip-entries))
         (define reason (and entry (cdr entry)))
         (eprintf "  ~a~a\n" t (if reason (format "  (~a)" reason) ""))))
     (if (skip-only?)
         (values actually-skipped filtered)  ; invert
         (values filtered actually-skipped))]))
```

**5. Apply in all three code paths** (`--all`, `force-all?`, normal targeted).

---

## Key Files

| Action | File |
|--------|------|
| CREATE | `tests/.skip-tests` |
| MODIFY | `tools/run-affected-tests.rkt` (~40 lines) |
| UPDATE | This tracking document |

---

## Verification Plan

1. **Default (skip active)**: `racket tools/run-affected-tests.rkt --all --dry-run` — skipped test shown separately
2. **`--no-skip`**: all 82 tests listed (including pathological)
3. **`--skip-only`**: only skipped tests listed
4. **`--skip extra.rkt`**: additional test skipped beyond skip list
5. **No skip file**: no error, no tests skipped
6. **Full suite with skip**: completes in ~7 min (vs >60 min)

---

## Implementation Log

*(To be filled during implementation)*
