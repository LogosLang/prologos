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
| 0 | Acceptance file | ⬜ | `examples/2026-03-30-ppn-track2b.prologos` — must include impl referencing user function |
| 0.5 | Tree parser error stubs for all preparse-consumed forms | ⬜ | D.3 F1: prevent `else` fallthrough producing garbage surfs |
| 1 | Extract `merge-preparse-and-tree-parser` | ⬜ | Refactor driver.rkt:1485-1560; fix impl-generated ordering (D.3 F4) |
| 2 | Wire merge into `process-file-inner` | ⬜ | driver.rkt:1608. WS path only — .rkt path unchanged (D.3 F3) |
| 3 | Wire merge into `load-module` | ⬜ | driver.rkt:1924-1934. WS path only. |
| 4 | Delete `use-tree-parser?`, collapse to merge-only | ⬜ | Delete parameter + old path. Independently revertible (D.3 F9). |
| 5 | Parameterize `preparse-expand-all` (#:expand-user-forms? #f for WS) | ⬜ | D.2-revised + D.3 F2/F7: 4-way form classification, guard only category (c). |
| 6 | Full suite verification + docs | ⬜ | 382/382 GREEN, acceptance file, A/B with cold-cache module loading (D.3 F5). |

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

### 3.0 Tree Parser Error Stubs (D.3 Finding 1)

The tree parser's `else` fallthrough (tree-parser.rkt:128-132) calls `parse-expr-tree` on unrecognized forms. For preparse-consumed forms like `schema`, `selection`, `capability`, `strategy`, `spawn`, `spawn-with`, `precedence-group`, `specialize`, `bundle`, `property`, `functor`, `defmacro`, `deftype` — this produces garbage `surf-app` or `surf-eval` nodes (not `prologos-error?`). The merge's user-form filter would keep these as "user forms," duplicating or corrupting the output.

**Fix**: Add explicit `prologos-error` stubs for ALL forms that preparse handles but the tree parser does not dispatch on. These join the existing stubs for `spec`, `data`, `trait`, `impl`, `ns`, `imports`, `exports`, `session`, `defproc`, `defr`, `solver`.

Forms needing stubs (~15 lines added to tree-parser.rkt):
- `schema`, `selection`, `capability`, `strategy`
- `spawn`, `spawn-with`, `precedence-group`, `specialize`
- `bundle`, `property`, `functor`
- `defmacro`, `deftype`, `proc`
- `foreign` (currently handled by preparse consume)

After this: every form that falls to the tree parser either produces a valid `surf-*` (tree parser handles it) or a `prologos-error` (merge filters it). No garbage surfs from the `else` fallthrough for known form tags.

### 3.1 Extract `merge-preparse-and-tree-parser`

Refactor lines 1485-1560 of `process-string-ws-inner` into a standalone function:

```racket
;; Merge preparse output with tree parser output for WS-mode processing.
;; preparse-surfs: (map parse-datum expanded-stxs) — all forms from old pipeline
;; source-str: the original source string — passed to read-to-tree for tree pipeline
;; Returns: merged surf list preserving Pass 5b ordering semantics
(define (merge-preparse-and-tree-parser source-str preparse-surfs)
  (register-default-token-patterns!)
  ;; Tree pipeline: read-to-tree → G(0) → T(0) → rewrite → parse
  (define pt (read-to-tree source-str))
  (define grouped-root (group-tree-node (parse-tree-root pt)))
  (define refined-root (refine-tag grouped-root))
  (define rewritten-root (rewrite-tree refined-root))
  (define tree-surfs (parse-top-level-forms-from-tree rewritten-root))
  ;; ... existing merge logic (spec-aware partition + filter + combine) ...
  ;; D.3 F4 FIX: preserve Pass 5b ordering — see below
  merged-surfs)
```

**Principle**: Decomplection — merge logic separated from pipeline-specific post-processing.

**D.3 Finding 4 — Impl-Generated Def Ordering**: The existing merge (driver.rkt:1560) does `(append generated-surfs tree-user-surfs-filtered)` — ALL generated surfs first, then ALL user surfs. But preparse's Pass 5b (macros.rkt:2462-2468) hoists only data/trait-generated defs before user forms. Impl-generated defs are intentionally NOT hoisted — they can reference user functions from the same module (macros.rkt:2466-2467 comment).

The merge must match this ordering. Fix: partition `generated-surfs` into `hoisted-generated` (data/trait-generated: names in `generated-decl-names`) and `impl-generated` (everything else). Output: `hoisted-generated` first, then interleave `impl-generated` and `tree-user-surfs-filtered` in source order.

Concretely: instead of `(append generated-surfs tree-user-surfs-filtered)`, use:
```racket
;; Separate hoisted (data/trait) from non-hoisted (impl) generated surfs
(define hoisted (filter hoisted-generated? generated-surfs))
(define non-hoisted (filter (negate hoisted-generated?) generated-surfs))
;; Hoisted first, then non-hoisted + user forms interleaved in source order
(append hoisted (merge-by-source-position non-hoisted tree-user-surfs-filtered))
```

The `hoisted-generated?` predicate checks if a surf's name was marked by `mark-generated-names!` in Pass 2 — data/trait branches call it, impl branches do not. The merge function receives this information from preparse (via the `generated-decl-names` hash or a separate output from `preparse-expand-all`).

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

Changed to (D.3 F3 revision — only WS path changes, .rkt path unchanged):
```racket
(define ws? (regexp-match? #rx"\\.prologos$" path-str))
(define surfs
  (cond
    [ws?
     ;; WS path: read file to string for both old pipeline + tree parser merge
     (define str (file->string path))
     (define raw-stxs (read-all-syntax-ws (open-input-string str) path-str))
     (define expanded-stxs (preparse-expand-all raw-stxs))
     (define preparse-surfs (map parse-datum expanded-stxs))
     (merge-preparse-and-tree-parser str preparse-surfs)]
    [else
     ;; .rkt sexp path: UNCHANGED — keep original port-based reading
     (define port (open-input-file path))
     (define raw-stxs (read-all-syntax port path-str))
     (close-input-port port)
     (define expanded-stxs (preparse-expand-all raw-stxs))
     (map parse-datum expanded-stxs)]))
```

The rest of `process-file-inner` (verbose mode loop, persistent registry init, heartbeat snapshots) is untouched — it operates on `surfs` regardless of source.

**Principle**: Correct-by-Construction — same validated merge logic, different input source. Minimum blast radius — sexp path unchanged (D.3 F3).

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

### Phase 5: Parameterize `preparse-expand-all` (D.2-revised, D.3 F2/F7-revised)

Add `#:expand-user-forms?` parameter to `preparse-expand-all` in macros.rkt. Default `#t` (preserves sexp path behavior). WS merge path passes `#f`.

**D.3 Finding 2/7 — 4-Way Form Classification**: Every form in Pass 2 must be classified. The `#:expand-user-forms?` guard applies ONLY to category (c):

| Category | Forms | Guard? | Rationale |
|----------|-------|--------|-----------|
| **(a) Consumed** — side effects only, no output | ns, imports, exports, foreign | NO | Already consumed; no expansion needed |
| **(b) Generated** — output always from preparse, expansion required | data, trait, impl, bundle, specialize, property, functor, schema, selection | NO | Generated defs are sexp datums that MUST be expanded (preparse-expand-form fires on generated output). Tree parser returns errors for these. |
| **(c) User forms** — handled by tree parser on WS path | def, defn, def-, defn-, eval, check, infer, bare expressions (else catch-all) | **YES** | When `expand? = #f`: skip `preparse-expand-form`. Output raw datum (merge uses tree parser output instead). |
| **(d) Preparse-only pass-through** — forms the tree parser cannot handle, require specialized expansion/desugaring | defr, solver, session, defproc, proc, strategy, capability, spawn, spawn-with, precedence-group | NO | These call `preparse-expand-form` or specialized desugaring functions. Tree parser returns errors. Expansion MUST proceed on WS path. |

**Implementation**: The guard wraps exactly these `preparse-expand-form` call sites in Pass 2:
- Public `defn`/`def` branch (macros.rkt ~line 2832): `(when expand? (preparse-expand-form ...))`
- Private `defn-`/`def-` branch (~line 2591): `(when expand? (preparse-expand-form ...))`
- Catch-all `else` branch (~line 2845): `(when expand? (preparse-expand-form ...))`

All other branches — category (a), (b), and (d) — are NOT guarded. Their `preparse-expand-form` calls fire regardless of `expand?`.

5a. Add `#:expand-user-forms? [expand? #t]` parameter to `preparse-expand-all`.
5b. Add `when expand?` guard at the 3 call sites identified above.
5c. Switch WS merge callers to pass `#:expand-user-forms? #f`.
5d. Verify: full suite GREEN. Targeted test with data+trait+impl+defr+def+eval verifies categories (b) and (d) still expand while (c) skips.

**Risk**: Reduced from D.2 assessment. The guard now has 3 precisely-identified call sites (not "somewhere in 373 lines"). Each is a `preparse-expand-form` call on a user-written form. Category (d) forms are explicitly excluded.

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

## D.3 External Critique Findings

| # | Severity | Finding | Response | Design Change |
|---|----------|---------|----------|---------------|
| F1 | HIGH | Tree parser `else` fallthrough produces garbage surfs for unhandled forms (schema, selection, capability, etc.) | **ACCEPT** — `parse-expr-tree` on keyword-headed children produces `surf-app`, not `prologos-error?`. Merge would keep these. | Phase 0.5 added: explicit error stubs for all preparse-consumed forms in tree-parser.rkt |
| F2 | HIGH | Phase 5 scope incomplete: defr, solver, session, defproc, proc, strategy etc. must NOT be guarded | **ACCEPT** — these call `preparse-expand-form` or specialized desugaring. Guard must only wrap category (c) user forms. | 4-way form classification table added to Phase 5. Guard sites precisely enumerated (3 call sites). |
| F3 | LOW | Pseudocode changes both WS and .rkt paths; design text says only WS | **PARTIALLY ACCEPT** — .rkt path should keep original port-based reading. | §3.2 pseudocode revised: `cond` dispatch, .rkt path unchanged. |
| F4 | HIGH | Merge hoists impl-generated defs before user forms; Pass 5b intentionally does NOT (impl methods can reference user functions) | **ACCEPT, upgraded to HIGH** — could cause undefined-name errors in library files (arithmetic.prologos has 40 impls). | Merge ordering revised: partition generated into hoisted (data/trait) vs non-hoisted (impl). Hoisted first, then impl+user interleaved by source position. |
| F5 | LOW | 16% overhead irrelevant for warm .pnet cache | **ACCEPT** — informational. | Phase 6 A/B should include cold-cache module loading scenario. |
| F6 | LOW | `register-default-token-patterns!` ordering vs preparse | **REJECT** — separate registries (token-pattern-registry in parse-reader.rkt vs current-preparse-registry parameter in macros.rkt). No interaction. | No change. |
| F7 | MEDIUM | Phase 5 guard placement across 25+ branches | **ACCEPT** — subsumed by F2. | Covered by 4-way classification + 3 precise call sites. |
| F8 | LOW | specialize-generated names could collide with tree-user-names | **PARTIALLY ACCEPT** — theoretically possible, practically impossible ($-suffixed names). | Documented as edge case. |
| F9 | LOW | No rollback plan — Phase 4 deletes parameter | **ACCEPT** — phases are independently revertible via `git revert`. | Note added to Phase 4 in progress tracker. |
| F10 | INFO | Merge braids classification, routing, and tree-parser execution. `[else #t]` catch-all is correctness by convention, not construction. | **ACKNOWLEDGED** — the merge is an imperative integration seam with known limitations. In the propagator-only target architecture (Track 3-4), the merge disappears entirely: each form gets a cell, both pipelines write, the lattice join resolves. Classification, catch-alls, and ordering concerns dissolve — correctness is structural (lattice properties + propagator residuation), not imperative (predicate classification). The merge is a throwaway bridge. Completeness is retiring it for propagator cells, not perfecting its classification logic. | No design change. Track 3 eliminates the merge rather than improving it. |

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
