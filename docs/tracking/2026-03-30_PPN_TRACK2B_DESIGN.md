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
| 5 | Parameterize `preparse-expand-all` (#:expand-user-forms? #f for WS) | ⬜ | D.2-revised: parameterize, not duplicate. Sexp expanders unreachable from WS path but retained for sexp path. |
| 6 | Full suite verification + docs | ⬜ | 382/382 GREEN, acceptance file, parameter gone, WS path skips user-form expansion |

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
6. `preparse-expand-all` parameterized: `#:expand-user-forms? #f` on WS path skips sexp expansion for user-written forms
7. Sexp-specific expanders no longer called on WS path (~1545 lines of expand-* functions become WS-dead; retained for sexp `process-string` path until sexp path retirement)

**What this track is NOT**:
- It does NOT implement new tree parser form types (data, trait, impl) — incomplete because preparse still handles registration side effects and generated def production; the merge routes these forms to preparse's output, which is correct
- It does NOT fill V(1)/V(2) pipeline-as-cell stubs — incomplete because V(2) spec injection requires cross-form attribute flow (PPN Track 4 scope); V(1) user macros require tree-level macro system (PPN Track 3 grammar productions or Track 7 user-defined grammar extensions)
- It does NOT eliminate the dual-pipeline overhead fully — incomplete because preparse registration+generation still runs alongside tree parser; full elimination requires moving registration to propagator cells (Track 3+)

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

### 3.5 Decouple Registration from Expansion (Phase 11)

`preparse-expand-all` (macros.rkt:2366-2593) is a monolithic 5-pass function that does THREE distinct things per form in Pass 2:

1. **Consume** (ns, imports, exports, foreign) — side effects only, no output
2. **Generate** (data, trait, impl) — produce generated defs (constructors, accessors, method defs) via `process-data`, `process-trait`, `process-impl`
3. **Expand** (def, defn, eval + user forms) — spec injection via `maybe-inject-spec` + macro expansion via `preparse-expand-form`

With the merge deployed (Phases 1-4), #3 fires on the preparse side but its output is **discarded for user forms** — the merge uses tree parser output instead. The sexp expanders (`expand-let`, `expand-if`, etc.) do wasted work: they expand datums that are thrown away.

**The fix** (revised per D.2 finding P2): Parameterize `preparse-expand-all` with `#:expand-user-forms?` (default `#t`). The WS merge path passes `#f` — user-written forms (def, defn, eval, check, infer) skip `preparse-expand-form` and are output as raw datums. Generated defs from data/trait/impl STILL pass through `preparse-expand-form` (they need expansion — see D.2 R2).

```racket
(define (preparse-expand-all stxs #:expand-user-forms? [expand? #t])
  ;; Pass -1: ns/imports (unchanged)
  ;; Pass 0: register data/trait/deftype/defmacro/bundle (unchanged)
  ;; Pass 1: register spec/impl (unchanged)
  ;; Pass 2: consume + generate + conditionally expand
  ;;   - ns/imports/exports/foreign: consume (side effects) — unchanged
  ;;   - data/trait/impl: generate defs → preparse-expand-form — unchanged (generated defs need expansion)
  ;;   - def/defn/eval/check/infer: when expand? = #t → preparse-expand-form (sexp path)
  ;;                                 when expand? = #f → output raw datum (WS path; tree parser handles these)
  ;; Pass 5b: hoist generated defs before user forms (unchanged)
  ...)
```

After this: on the WS path, `preparse-expand-form` is called ONLY on generated defs (data/trait/impl output), NOT on user forms. The sexp expanders (`expand-let`, `expand-if`, etc.) are unreachable from the WS path.

**Why NOT duplication** (D.2 P2): Creating a separate `preparse-register-and-generate` function would duplicate ~80% of `preparse-expand-all` (Passes -1/0/1 and most of Pass 2). This violates Decomplection. A single parameter controlling phase elimination is cleaner — one function, one maintenance point.

**What stays**: Everything. No functions are deleted. The ~1545 lines of expand-* functions become WS-dead but sexp-live (the sexp `process-string` path still calls `preparse-expand-all` with default `#:expand-user-forms? #t`). Actual deletion of expanders is deferred: "incomplete because `process-string` sexp path still uses registered expanders; deferred until sexp path retirement."

**What changes**: One parameter added to `preparse-expand-all`. One `when expand?` guard around the user-form expansion in Pass 2. WS callers pass `#:expand-user-forms? #f`.

**Principle**: Completeness — Track 3 inherits a clean single-pipeline architecture where the WS path never calls sexp-specific expansion on user forms. Decomplection — one function, not two.

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

### Phase 5: Parameterize `preparse-expand-all` (D.2-revised)

Add `#:expand-user-forms?` parameter to `preparse-expand-all` in macros.rkt. Default `#t` (preserves sexp path behavior). WS merge path passes `#f`.

5a. Add `#:expand-user-forms? [expand? #t]` parameter to `preparse-expand-all`.
5b. In Pass 2: wrap user-form expansion (`preparse-expand-form` calls on def/defn/eval/check/infer) with `(when expand? ...)`. When `#f`, output raw datum without expansion.
5c. Generated defs from data/trait/impl STILL pass through `preparse-expand-form` (unchanged — the `when expand?` guard only affects user forms, not generated def expansion at lines 2527/2533).
5d. Switch WS merge callers (`merge-preparse-and-tree-parser`) to call `(preparse-expand-all stxs #:expand-user-forms? #f)`.
5e. Verify: full suite GREEN. Sexp path (`process-string`) calls `(preparse-expand-all stxs)` with default `#t` — unchanged behavior. WS path skips user-form expansion — merge uses tree parser output for user forms anyway.

**Verification**: `grep -rn "expand-user-forms" macros.rkt driver.rkt` shows parameter definition + WS callers passing `#f`. Full suite GREEN.

**Risk**: The `when expand?` guard must be placed precisely — only around user-form expansion, NOT around generated-def expansion, spec injection, or registration. Misplacing it would break the sexp path (if expansion is accidentally skipped for generated defs on the sexp path) or leave wasted work on the WS path (if expansion isn't actually skipped for user forms). A targeted test: run a WS file with `data` + `trait` + `impl` + `def` + `eval` and verify generated defs are expanded but user forms are raw datums on the preparse side of the merge.

### Phase 6: Suite Verification + Documentation

- Full suite with `--report`
- Post-deployment A/B: `bench-ab.rkt --runs 10 benchmarks/comparative/` — confirm overhead
- Grep: `use-tree-parser?` returns 0 results, sexp expanders deleted from WS path
- Update: Track 2B progress tracker, PPN Master, dailies, PIR addendum

---

## §5 Relationship to Track 2 Technical Debt

Track 2's PIR identified 5 items of accepted technical debt (§11). This section maps each to Track 2B's handling:

| Debt (from PIR §11) | Track 2B Status |
|---------------------|-----------------|
| Dual pipeline overhead (~16%) | REDUCED — Phase 5 skips sexp expansion for user forms on WS path. Preparse still runs for registration+generation+generated-def-expansion. Full elimination requires registration on propagator cells (Track 3+). |
| reader.rkt still imported | RESOLVED in Track 2 Phase 10 — reader.rkt deleted. |
| Preparse still runs for 5 responsibilities | Phase 5 makes expansion conditional (skipped for user forms on WS path). 4.5 of 5 remain active: registration, spec storage, generated defs, consume, + generated-def expansion. User-form expansion eliminated. |
| V(1) user macros at tree level | NOT addressed — incomplete because V(1) requires tree-level macro system. Merge fallback handles correctly. Placement: Track 3 (grammar productions) or Track 7 (user-defined grammar extensions). |
| V(2) spec injection at tree level | NOT addressed — incomplete because V(2) requires cross-form attribute flow on the network. Placement: PPN Track 4 (elaboration as attribute evaluation, IS SRE Track 2C). |

---

## §6 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Token patterns uninitialized in file/module paths | Medium | Merge produces empty tree, falls back to all-preparse (silent correctness) | `register-default-token-patterns!` inside merge function |
| `load-module` spec-store interaction | Low | Wrong merge routing for module-internal specs | `current-spec-store` is `(hasheq)` in load-module scope — fresh, correct |
| Double-read overhead (file→string twice for read-all-syntax-ws + read-to-tree) | Low | Minor I/O | Single `file->string`, two `open-input-string` from same string |
| Dual-pipeline ~16% overhead | Known | Measurable | Accepted. Track 3 eliminates dual pipeline. Track 2B deploys; Track 3 optimizes. |
| Port leak from changed file reading pattern | Low | Resource leak | Explicit `close-input-port` or use `file->string` which handles it |

---

## §7 Red-Flag Phrase Audit

| Phrase | Status |
|--------|--------|
| "defaults to #f for safety" | ELIMINATED in Phase 4 — parameter deleted |
| "keeping the old path as fallback" | ELIMINATED in Phase 4 — old `else` branch deleted |
| "opt-in for now" | ELIMINATED — merge is mandatory |
| "validated but not deployed" | RESOLVED — Track 2B IS the deployment |
| "pragmatic approach" | NOT USED — scope boundaries use "incomplete because [reason]" language |

---

## §8 Pre-0 Benchmarks

Not required. Track 2 Phase 9 already measured the dual-pipeline overhead at ~16% (both preparse and tree parser run). Track 2B adds no new pipeline stages — it wires the existing merge into additional callsites. The same 16% applies.

Post-deployment A/B comparison (Phase 5) will confirm the overhead holds for file-based processing.

---

## §9 WS Impact

None. No user-facing syntax is added or modified. Only internal pipeline routing changes.

---

## §10 NTT Speculative Syntax

Not applicable. This track deploys existing infrastructure — no new propagators, lattices, or rewrite rules are introduced.

---

## D.2 Self-Critique Findings

### Lens 1 — Principles Challenge

| # | Decision | Principle | Severity | Finding | Resolution |
|---|----------|-----------|----------|---------|------------|
| P1 | Merge reads `current-spec-store` (imperative parameter) | Data Orientation | LOW | Not data-oriented — reads imperative state for routing decision. Principled: spec-store as cell. | Acceptable for 2B — extracting existing validated logic, not introducing new patterns. Track 4 will put spec-store on the network. |
| P2 | Phase 5 creates `preparse-register-and-generate` as copy of `preparse-expand-all` | Decomplection | MEDIUM | Code duplication (~80% shared). Two functions maintaining same Passes -1/0/1. | **FIX**: Parameterize `preparse-expand-all` with `#:expand-user-forms? #t` (default) instead of duplicating. WS path passes `#f`. One function, no duplication. This is not the "adding a parameter to inject X" anti-pattern — it's phase elimination, not behavior injection. |
| P3 | Design pseudocode uses undefined `ws?` variable | — | LOW | Real code uses `(regexp-match? #rx"\\.prologos$" path-str)` inline. Design pseudocode should match. | Clarify in implementation — not architecturally significant. |
| P4 | Delete `use-tree-parser?` entirely | Validated ≠ Deployed | NONE | Correct. No escape hatch reasoning. `git bisect` for debugging. | No change needed. |
| P5 | Phase 5d says "delete sexp expanders" | Completeness | **HIGH** | **CONTRADICTS §3.5 "stays for sexp path"**. The sexp `process-string` path still calls `preparse-expand-all` → `preparse-expand-form` → registered expanders. Deleting the functions breaks the sexp path and ~350 test files. | **FIX**: Do NOT delete expander functions in Track 2B. Phase 5 parameterizes `preparse-expand-all` to skip expansion on WS path. Expanders become WS-dead but sexp-live. Actual deletion deferred to sexp path retirement: "incomplete because `process-string` sexp path still uses `preparse-expand-form`; deferred until sexp path retired." |

### Lens 2 — Codebase Reality Check

| # | Claim | Verification | Result |
|---|-------|-------------|--------|
| R1 | Merge reads `current-spec-store` at line 1530 | `grep -n "current-spec-store" driver.rkt` | ✓ Confirmed (line 1530) |
| R2 | Generated defs pass through `preparse-expand-form` (lines 2527, 2533) | `grep -n "preparse-expand-form" macros.rkt` | ✓ Confirmed — trait/impl generated defs DO need expansion |
| R3 | ~1000 lines of sexp expanders | `awk` line count on expand-* functions | ✗ Actually ~1545 lines (21 functions). But per P5, these cannot be deleted while sexp path exists. |
| R4 | `use-tree-parser?` only in driver.rkt | `grep -rn "use-tree-parser"` | ✓ Confirmed — only 3 references, all in driver.rkt |
| R5 | No tests parameterize `use-tree-parser?` | Same grep | ✓ Confirmed — no test files reference it |

### Design Changes Required

1. **Phase 5 revised**: Do NOT duplicate `preparse-expand-all`. Add `#:expand-user-forms?` parameter (default `#t`). WS merge path passes `#f`. Generated defs from data/trait/impl still expanded (they pass through `preparse-expand-form` regardless).

2. **Phase 5d removed**: Sexp expanders NOT deleted — they stay for the sexp `process-string` path. The ~1545 lines are WS-dead but sexp-live. Scope boundary updated: "incomplete because `process-string` sexp path still uses registered expanders; deferred until sexp path retirement."

3. **§1 deliverable 7 revised**: "Sexp expanders no longer called on WS path" replaces "sexp expanders deleted." The functions exist but are unreachable from WS processing.
