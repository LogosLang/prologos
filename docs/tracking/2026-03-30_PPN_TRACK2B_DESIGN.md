# PPN Track 2B: Production Deployment of Tree Parser — Stage 3 Design (D.1)

**Date**: 2026-03-30
**Series**: [PPN (Propagator-Parsing-Network)](2026-03-26_PPN_MASTER.md)
**Prerequisite**: [PPN Track 2 ✅](2026-03-28_PPN_TRACK2_DESIGN.md) (tree parser validated, merge proven, reader.rkt deleted)
**PIR (predecessor)**: [PPN Track 2 PIR](2026-03-29_PPN_TRACK2_PIR.md) — Gap 2 (tree parser not on production path)
**Principle**: Validated ≠ Deployed ([DEVELOPMENT_LESSONS.org](principles/DEVELOPMENT_LESSONS.org) § "Validated Is Not Deployed")

---

## Progress Tracker

| Phase | Description | Status | Notes |
|-------|-------------|--------|-------|
| 0 | Acceptance file | ⬜ | `examples/2026-03-30-ppn-track2b.prologos` |
| 1 | Extract `merge-preparse-and-tree-parser` | ⬜ | Refactor driver.rkt:1485-1560 into shared function |
| 2 | Wire merge into `process-file-inner` | ⬜ | driver.rkt:1608 |
| 3 | Wire merge into `load-module` | ⬜ | driver.rkt:1924-1934 |
| 4 | Delete `use-tree-parser?`, collapse to merge-only | ⬜ | Delete parameter + old path |
| 5 | Full suite verification + docs | ⬜ | 382/382 GREEN, acceptance file, grep confirms parameter gone |

**Phase completion protocol**: After each phase: commit → update tracker → update dailies → run targeted tests → proceed.

---

## §1 Objectives

**End state**: The tree parser merge is the production default on ALL WS code paths. The `use-tree-parser?` parameter is deleted. Every `.prologos` file processed by `process-file`, `process-string-ws`, and `load-module` uses the tree parser merge path. No fallback. No parameter. No opt-in.

**What is delivered**:
1. A shared `merge-preparse-and-tree-parser` function (extracted from existing validated code)
2. `process-file-inner` uses the merge for `.prologos` files
3. `load-module` full-elaboration path uses the merge for `.prologos` files
4. `process-string-ws-inner` simplified to merge-only (old path deleted)
5. `use-tree-parser?` parameter deleted from codebase

**What this track is NOT**:
- It does NOT implement new tree parser form types (data, trait, impl) — incomplete because preparse handles registration side effects; deferred to Track 3
- It does NOT delete sexp expanders from macros.rkt — incomplete because preparse-expand-all is shared by sexp and WS paths; deferred to Track 3 Phase 11
- It does NOT fill V(1)/V(2) pipeline-as-cell stubs — incomplete because they need cross-form registry cells; deferred to Track 3/4
- It does NOT eliminate the dual-pipeline overhead — incomplete because preparse is still needed for generated defs; deferred to Track 3

---

## §2 Current State

### 2.1 The Gap

PPN Track 2 Phase 6g (`523f2f1`) validated the tree parser merge: 383/383 GREEN with `use-tree-parser? = #t`. But `use-tree-parser?` defaults to `#f` (driver.rkt:1474). The production paths — `process-file` and `load-module` — don't use the tree parser at all. The tree parser is validated but not deployed.

Per the "Validated ≠ Deployed" lesson: a parameter defaulting to `#f` is a gap, not a safety net. Track 2B closes this gap.

### 2.2 Five Callsites of `preparse-expand-all → parse-datum`

| # | Location | Pipeline | Tree Parser? | Scope |
|---|----------|----------|-------------|-------|
| 1 | driver.rkt:1432 | `process-string-inner` (sexp) | NO | Out of scope (sexp reader, no .prologos) |
| 2 | driver.rkt:1490 | `process-string-ws-inner` (tree branch) | YES — the working merge | Already done |
| 3 | driver.rkt:1565 | `process-string-ws-inner` (else branch) | NO — old path | Phase 4: delete |
| 4 | driver.rkt:1617 | `process-file-inner` | NO | **Phase 2: wire merge** |
| 5 | driver.rkt:1933 | `load-module` (full elaboration) | NO | **Phase 3: wire merge** |

Callsite 1 (sexp path) is intentionally out of scope — it uses `prologos-sexp-read-syntax` from sexp-readtable.rkt. The tree parser operates on WS parse trees, not sexp datums.

### 2.3 Structural Differences Between the Three WS Pipelines

The merge logic currently lives only in `process-string-ws-inner` (lines 1485-1560). Each target pipeline differs in post-processing:

**process-string-ws-inner** (the working merge, lines 1476-1567):
- Input: string
- Post-processing: calls shared `process-surfs` (line 1561)
- Context: fresh network per `process-string-ws` call

**process-file-inner** (Gap 1, lines 1608-1666):
- Input: file path → port → `read-all-syntax-ws`
- Post-processing: inline loop with verbose-mode per-command timing, persistent registry network init (`init-persistent-registry-network!`), heartbeat snapshots
- Context: fresh network per `process-file` call

**load-module** full-elaboration (Gap 2, lines 1924-1940):
- Input: file path → port → `read-all-syntax-ws`
- Post-processing: inline loop that raises on first error (line 1938)
- Context: 40+ parameter `parameterize` block with fresh module-local registries (line 1861-1919), fresh `current-spec-store (hasheq)` (line 1888)

**Key observation**: The merge logic is form-level (which surfs come from preparse vs tree parser). It produces a flat list of surfs. The post-processing (how surfs are elaborated) is pipeline-specific and stays untouched. The merge can be extracted cleanly.

### 2.4 The Core Conversion: Port → String

The existing merge requires `read-to-tree` (takes a string). The file-based paths open a port. Fix: read file content as string first (via `port->string` or `file->string`), then pass string to both `read-all-syntax-ws` (via fresh `open-input-string` port) and `read-to-tree`.

This is exactly what the existing merge path does:
```racket
;; process-string-ws-inner, lines 1485-1493:
(define str (port->string port))
(define datum-port (open-input-string str))
(define raw-stxs (read-all-syntax-ws datum-port "<ws-string>"))
...
(define pt (read-to-tree str))
```

### 2.5 What the Merge Handles

The validated merge (lines 1498-1560) partitions outputs:

| Source | Forms | Routing |
|--------|-------|---------|
| Preparse | Generated defs (constructors, accessors, type defs) | Always from preparse (names not in source) |
| Preparse | Spec-annotated defns | From preparse (has spec type injected) |
| Preparse | Consumed forms (ns, imports, data, trait, impl) | Side effects already applied; surfs filtered out |
| Tree parser | User def/defn without spec | From tree parser (direct tree→surf-*) |
| Tree parser | eval, check, infer | From tree parser |
| Tree parser | Stubbed forms (data, trait, etc.) | Errors filtered out — preparse handles them |

The merge reads `current-spec-store` (line 1530 in existing code) to decide spec routing. In `load-module` context, `current-spec-store` is `(hasheq)` (line 1888) — fresh per module. This is correct: module-local specs guide the module's merge.

---

## §3 Design

### 3.1 Extract `merge-preparse-and-tree-parser`

Refactor lines 1485-1560 of `process-string-ws-inner` into a standalone function:

```racket
;; Merge preparse output with tree parser output for WS-mode processing.
;; preparse-surfs: (map parse-datum expanded-stxs) — all forms from old pipeline
;; source-str: the original source string — passed to read-to-tree for tree pipeline
;; Returns: merged surf list (generated defs first, then user forms from tree parser)
(define (merge-preparse-and-tree-parser source-str preparse-surfs)
  (register-default-token-patterns!)
  ;; Tree pipeline: read-to-tree → G(0) → T(0) → rewrite → parse
  (define pt (read-to-tree source-str))
  (define grouped-root (group-tree-node (parse-tree-root pt)))
  (define refined-root (refine-tag grouped-root))
  (define rewritten-root (rewrite-tree refined-root))
  (define tree-surfs (parse-top-level-forms-from-tree rewritten-root))
  ;; ... existing merge logic (spec-aware partition + filter + combine) ...
  merged-surfs)
```

**Principle**: Decomplection — merge logic separated from pipeline-specific post-processing.

`register-default-token-patterns!` is called inside the function (idempotent). No caller dependency on external initialization.

### 3.2 Wire into `process-file-inner` (Gap 1)

Current (driver.rkt:1608-1618):
```racket
(define port (open-input-file path))
(define raw-stxs (if ws? (read-all-syntax-ws port ...) (read-all-syntax port ...)))
(close-input-port port)
(define expanded-stxs (preparse-expand-all raw-stxs))
(define surfs (map parse-datum expanded-stxs))
```

Changed to:
```racket
(define str (file->string path))
(define raw-stxs (if ws? (read-all-syntax-ws (open-input-string str) ...)
                         (read-all-syntax (open-input-string str) ...)))
(define expanded-stxs (preparse-expand-all raw-stxs))
(define preparse-surfs (map parse-datum expanded-stxs))
(define surfs
  (if ws?
      (merge-preparse-and-tree-parser str preparse-surfs)
      preparse-surfs))
```

The rest of `process-file-inner` (verbose mode loop, persistent registry init, heartbeat snapshots) is untouched — it operates on `surfs` regardless of source.

**Principle**: Correct-by-Construction — same validated merge logic, different input source.

### 3.3 Wire into `load-module` (Gap 2)

Current (driver.rkt:1924-1934):
```racket
(define port (open-input-file file-path))
(define raw-stxs (if ws? (read-all-syntax-ws port ...) (read-all-syntax port ...)))
(close-input-port port)
(define expanded-stxs (preparse-expand-all raw-stxs))
(define surfs (map parse-datum expanded-stxs))
```

Same transformation as §3.2. The `load-module` context has fresh `current-spec-store (hasheq)` (line 1888), which the merge reads — this is correct for module-local spec routing.

**Risk**: The 40-parameter `parameterize` block (lines 1861-1919). The merge function doesn't parameterize anything — it reads `current-spec-store` and calls tree parser functions, all of which use the caller's parameter context. No interference.

### 3.4 Delete `use-tree-parser?` and Collapse

After Phases 2-3, the merge runs on all WS paths. The `use-tree-parser?` parameter and old path are dead code:

1. Delete `(define use-tree-parser? (make-parameter #f))` (line 1474)
2. Delete the `cond` dispatch in `process-string-ws-inner` — replace with:
   ```racket
   (define (process-string-ws-inner s)
     (define raw-stxs (read-all-syntax-ws (open-input-string s) "<ws-string>"))
     (define expanded-stxs (preparse-expand-all raw-stxs))
     (define preparse-surfs (map parse-datum expanded-stxs))
     (define surfs (merge-preparse-and-tree-parser s preparse-surfs))
     (process-surfs surfs))
   ```
3. Remove `use-tree-parser?` from provides (line 88)
4. Update `bench-ppn-track2.rkt` to remove `use-tree-parser?` reference

**Principle**: Validated ≠ Deployed applied in full — no parameter, no fallback, no "defaults to #f for safety."

---

## §4 Phasing

### Phase 0: Acceptance File

Create `racket/prologos/examples/2026-03-30-ppn-track2b.prologos` exercising:
- `ns` + `import` (preparse consumed, exercises `load-module`)
- `data` + constructors (preparse generated defs)
- `trait` + `impl` (preparse consumed forms)
- `spec` + `defn` (spec-aware merge routing)
- `def`, `defn` without spec (tree parser user forms)
- `eval` (tree parser)

Run via `process-file` BEFORE any changes to establish baseline. Expected: works via old path, 0 errors.

### Phase 1: Extract Merge Function

Extract driver.rkt:1485-1560 into `merge-preparse-and-tree-parser`. Wire `process-string-ws-inner` tree branch to call it. Pure refactor — zero behavioral change.

**Verification**: `run-affected-tests.rkt --all` with `(parameterize ([use-tree-parser? #t]) ...)` in test-support.rkt — same results as before.

### Phase 2: Wire into `process-file-inner`

Modify driver.rkt:1608-1618 per §3.2. For `.prologos` files, call merge. For `.rkt` files, unchanged.

**Verification**: Run acceptance file via `process-file`. Run targeted: `raco test tests/test-process-ws-01.rkt tests/test-functor-ws-01.rkt tests/test-functor-ws-02.rkt`.

### Phase 3: Wire into `load-module`

Modify driver.rkt:1924-1934 per §3.3. Same pattern as Phase 2.

**Verification**: Run acceptance file (exercises `load-module` via `ns`/`import`). Run full suite — every test with prelude exercises `load-module` for prelude loading.

### Phase 4: Delete Parameter, Collapse

Delete `use-tree-parser?`, old path, export. Simplify `process-string-ws-inner`.

**Verification**: Full suite `racket tools/run-affected-tests.rkt --all` — 382/382 GREEN. `grep -rn "use-tree-parser" --include="*.rkt"` returns 0 results. Acceptance file passes.

### Phase 5: Suite Verification + Documentation

- Full suite with `--report`
- Post-deployment A/B: `bench-ab.rkt --runs 10 benchmarks/comparative/` — confirm overhead matches Track 2 measurement
- Update: Track 2B progress tracker, PPN Master, dailies

---

## §5 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Token patterns uninitialized in file/module paths | Medium | Merge produces empty tree, falls back to all-preparse (silent correctness) | `register-default-token-patterns!` inside merge function |
| `load-module` spec-store interaction | Low | Wrong merge routing for module-internal specs | `current-spec-store` is `(hasheq)` in load-module scope — fresh, correct |
| Double-read overhead (file→string twice for read-all-syntax-ws + read-to-tree) | Low | Minor I/O | Single `file->string`, two `open-input-string` from same string |
| Dual-pipeline ~16% overhead | Known | Measurable | Accepted. Track 3 eliminates dual pipeline. Track 2B deploys; Track 3 optimizes. |
| Port leak from changed file reading pattern | Low | Resource leak | Explicit `close-input-port` or use `file->string` which handles it |

---

## §6 Red-Flag Phrase Audit

| Phrase | Status |
|--------|--------|
| "defaults to #f for safety" | ELIMINATED in Phase 4 — parameter deleted |
| "keeping the old path as fallback" | ELIMINATED in Phase 4 — old `else` branch deleted |
| "opt-in for now" | ELIMINATED — merge is mandatory |
| "validated but not deployed" | RESOLVED — Track 2B IS the deployment |
| "pragmatic approach" | NOT USED — scope boundaries use "incomplete because [reason]" language |

---

## §7 Pre-0 Benchmarks

Not required. Track 2 Phase 9 already measured the dual-pipeline overhead at ~16% (both preparse and tree parser run). Track 2B adds no new pipeline stages — it wires the existing merge into additional callsites. The same 16% applies.

Post-deployment A/B comparison (Phase 5) will confirm the overhead holds for file-based processing.

---

## §8 WS Impact

None. No user-facing syntax is added or modified. Only internal pipeline routing changes.

---

## §9 NTT Speculative Syntax

Not applicable. This track deploys existing infrastructure — no new propagators, lattices, or rewrite rules are introduced.
