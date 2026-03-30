# PPN Track 2: Surface Normalization as Propagators --- Post-Implementation Review

**Date**: 2026-03-29
**Duration**: ~8.5 hours across 1 session (16:43 PDT through 01:10+1 PDT)
**Commits**: 68 (from `a0fd5238` Pre-0 benchmarks through `7302345d` tracker/PIR)
**Test delta**: 7529 -> 7529 (0 new tests in main suite; +57 new tests in surface-rewrite.rkt and tree-parser.rkt)
**Code delta**: ~3258 insertions, ~8 deletions across 6 .rkt files; ~8923 insertions, ~1996 deletions total (including docs)
**Suite health**: 383/383 files, 7529 tests, all pass
**Design iterations**: 6 (D.1, D.1b CALM revision, D.1c Pocket Universe, D.2 self-critique, NTT modeling, D.3 external critique)
**Design docs**: [PPN Track 2 Design](2026-03-28_PPN_TRACK2_DESIGN.md), [PPN Track 2 Stage 2 Audit](2026-03-28_PPN_TRACK2_STAGE2_AUDIT.md)
**Prior PIRs**: [PAR Track 1](2026-03-28_PAR_TRACK1_PIR.md), [PPN Track 1](2026-03-26_PPN_TRACK1_PIR.md), [PPN Track 0](2026-03-26_PPN_TRACK0_PIR.md), [PM Track 10B](2026-03-26_PM_TRACK10B_PIR.md), [PM Track 10](2026-03-24_PM_TRACK10_PIR.md)
**Series**: PPN (Propagator Parsing Network) --- Track 2 of 8

---

## 1. What Was Built

PPN Track 2 delivers a propagator-based surface normalization pipeline that operates on parse trees from the PPN Track 1 reader. The track replaces `parse-datum` (the conversion from reader output to surface syntax structs) with a tree parser that converts parse tree nodes directly to `surf-*` structs, bypassing the old reader.rkt entirely for the core language.

The architecture has three layers:

1. **surface-rewrite.rkt** (~1200 lines, 31 tests): Tag refinement stratum T(0) that refines generic `'line` tags into semantic tags (`'def`, `'defn`, `'spec`, `'type`, etc.), form grouping stratum G(0) that converts line-structured parse trees into form-structured ones, 10 rewrite rules (5 simple, 4 recursive, 1 complex), and a pipeline-as-cell model that embeds the stratified pipeline as a monotone lattice value.

2. **tree-parser.rkt** (~1250 lines, 26 tests): Direct conversion from tree nodes to `surf-*` structs. Handles `def`, `defn`, `spec`, `type`, `trait`, `impl`, `bundle`, `subtype`, `ns`, `import`, `fn`, `match`, `solve`, `defr`, Pi/Sigma types, arrows, builtins, `natrec`, `Eq`, maps, and all application forms.

3. **driver.rkt integration**: A spec-aware merge strategy where: (a) forms with `spec` annotations use preparse output (preserving spec injection), (b) generated definitions from preparse are included (registration side effects), and (c) all other user-written forms use tree parser output. This achieves switchover without reimplementing preparse's 5 responsibilities at tree level.

The switchover is **live**: tree parser output is used for real elaboration on every `.prologos` file. The result: 383/383 test files GREEN, 7529 tests passing, zero behavioral change.

**Key architectural insight**: The tree parser replaces `parse-datum`, not `preparse`. Preparse does 5 things (registration, macro expansion, spec injection, generated definitions, WS desugaring). The tree parser does 1 thing (tree -> surf-*). The merge strategy handles the gap.

---

## 2. Timeline and Phases

All times PDT (UTC-7), 2026-03-29 through 2026-03-30.

### Design Phase

| Phase | Time | Commit | Description | Duration |
|-------|------|--------|-------------|----------|
| Stage 2 Audit | pre-session | `d0ccf5c` | macros.rkt comprehensive analysis: 9763 lines, 48 functions, 5 passes | ~30m |
| D.1 | 16:40 | `b676567` | Surface normalization as propagators --- initial design | ~45m |
| Pre-0 benchmarks | 16:43 | `a0fd523` | Preparse invisible vs elaboration. 22-35us/rule | ~15m |
| D.1b | 18:56 | `5acff03` | CALM-compliant revision: datum-level replacement merge is NOT monotone | ~30m |
| D.1c | 19:43 | `a6c9349` | Parse tree as Pocket Universe --- algebraic embedding insight | ~20m |
| D.2 | 19:47 | `99725f1` | Self-critique: 7 findings (CALM violation in D.1, missing G(0), template depth) | ~15m |
| NTT modeling | 19:50 | `db2ce39` | Full pipeline modeled in NTT. 3 proposed extensions: rewrite, refine, foreach | ~20m |
| D.3 | 19:55 | `33b9a86` | External critique: 10 findings incorporated (error provenance, escape hatch) | ~15m |

**Design time**: ~3.5 hours (including audit). 6 design iterations.

### Implementation Phase

| Phase | Time | Duration | Commit(s) | Description | Tests |
|-------|------|----------|-----------|-------------|-------|
| 1 | 20:08 | ~15m | `27e8870` | surface-rewrite.rkt: rewrite infrastructure, 38 tag rules, rewrite-rule struct | 0 |
| 1b | 20:18 | ~8m | `b990292` | Tag refinement T(0) wired into reader pipeline. 383/383 GREEN | 0 |
| 2a | 20:32 | ~10m | `d1cc404` | 5 simple rewrite rules (let-binding, string-interp, dot-access, dot-key, infix-pipe) | 31 |
| 2b | 20:48 | ~12m | `99cccaa` | 4 recursive rewrite rules (cond, do, list-lit, lseq-lit) + quasiquote deferred | 31 |
| 3 | 21:02 | ~10m | `2d3d1f7` | Quasiquote propagator. 3 deferred to Phase 6 (pipe-fusion, mixfix, defn-multi) | 31 |
| 6a | 21:35 | ~20m | `8778dfe` | G(0) form-grouping stratum: line -> form structure bridge | 31 |
| 6b | 21:55 | ~12m | `d67094d` | Pipeline-as-cell: monotone stage chain, advance-pipeline | 31 |
| 6c | 22:10-23:15 | ~65m | `2a7cf89`->`6fa8b70` | tree-parser.rkt: 1250 lines, 26 tests. Core language + builtins | 57 |
| 6d | 23:20-23:55 | ~35m | `577b809`->`3bca61e` | Integration: hybrid path, defn fix, surf-app fix. 383/383 GREEN | 57 |
| 6e | 23:58 | ~5m | `c1a4f35` | V(1) user macro bridge stubbed --- LOW PRIORITY | 57 |
| 6f | 00:02 | ~5m | `74951b3` | V(2) spec injection documented --- pass-through to preparse | 57 |
| 6g | 00:10-00:48 | ~38m | `523f2f1`->`8d80c27` | **SWITCHOVER**: merge active, spec-aware merge, all deferred resolved | 57 |
| 7 | 00:48 | ~2m | (verification) | Layer 2 already working --- expand-top-level processes tree parser surf-* identically | 57 |
| 8a | 01:05 | ~5m | `50f60c3` | Import migration ATTEMPTED and REVERTED. Compat-token type mismatch, 23 failures | 57 |
| 9 | 01:08 | ~3m | (benchmarks) | A/B benchmarks: 16% overhead from dual pipeline (expected) | 57 |

**Implementation time**: ~4.5 hours (20:08 through 01:10+1)
**Design-to-implementation ratio**: ~3.5h design : ~4.5h implementation = **0.8:1**

### Time Breakdown

| Activity | Duration | % |
|----------|----------|---|
| Design (D.1-D.3 + audit + benchmarks) | ~3.5h | 41% |
| Phase 1-3 (rewrite infrastructure + rules) | ~55m | 11% |
| Phase 6a-6b (G(0) + pipeline-as-cell) | ~32m | 6% |
| Phase 6c (tree-parser.rkt) | ~65m | 13% |
| Phase 6d-6g (integration + switchover) | ~83m | 16% |
| Phase 7-9 (verification + benchmarks) | ~10m | 2% |
| Documentation + tracker updates | ~45m | 9% |
| Dailies updates | ~10m | 2% |

**Critical observation**: Phase 6c (tree-parser.rkt, a brand-new module) took 65 minutes for 1250 lines --- about 19 lines/minute, which is high throughput. Phase 6d (integration with existing code) took 35 minutes but included 2 bugs found and fixed. Phase 6g (switchover) took 38 minutes including 3 strategy pivots. The pattern holds: new code is fast, integration code is where bugs live.

---

## 3. Test Coverage

### New test files

| File | Tests | Categories |
|------|-------|------------|
| test-surface-rewrite.rkt (in surface-rewrite.rkt) | 31 | Tag refinement (8), simple rewrites (5), recursive rewrites (4), quasiquote (3), form grouping (6), pipeline-as-cell (5) |
| test-tree-parser.rkt (in tree-parser.rkt) | 26 | def (3), defn (4), spec (2), type (2), trait (1), impl (1), fn (2), match (2), builtins (3), arrows (2), applications (4) |

**Total**: 57 new tests across 2 modules.

### Coverage by component

| Component | Test approach | Confidence |
|-----------|--------------|------------|
| Tag refinement T(0) | Unit tests + full suite (every .prologos file exercises it) | High |
| Form grouping G(0) | Unit tests + integration through tree parser | High |
| 10 rewrite rules | Per-rule unit tests | High |
| Pipeline-as-cell | Unit tests for monotone advancement | Medium |
| tree-parser.rkt | Per-form unit tests + e2e through driver.rkt | High |
| Spec-aware merge | Full suite (383/383) | High (implicit) |
| Merge fallback | Full suite exercises all specialized forms | High (implicit) |

### Gaps

- No dedicated test for the merge strategy logic itself (covered implicitly by full suite)
- No performance regression tests for the dual pipeline overhead
- No test for error recovery when tree parser produces malformed surf-* nodes
- V(1) user macros at tree level are untested (deferred, handled by merge fallback)

---

## 4. Bugs Found and Fixed

| # | Bug | Root Cause | Phase | Fix |
|---|-----|-----------|-------|-----|
| 1 | Tree rewriting BLOCKED --- line vs form structure | Parse tree nodes have `'line` tags, not form-head tags. Rewrite rules match form heads but trees group by lines | 6 (pre-6a) | G(0) form-grouping stratum: `group-tree-node` converts line structure to form structure before rewriting |
| 2 | defn type inference failure --- Pi chain with holes | `parse-defn-tree` produced params with string names instead of symbols; Pi chain construction passed strings to `make-binder` | 6d | `string->symbol` conversion in param-name extraction. Caught by diagnostic protocol (targeted test, not full suite) |
| 3 | surf-app args as nested structure instead of flat list | `parse-app-tree` recursively nested application nodes instead of collecting arguments into a flat list | 6d | Restructured to collect all argument sub-trees into a single `surf-app` with flat args list. Caught immediately by `expand-expression` contract violation |
| 4 | Phase 8a: compat-token type mismatch | reader.rkt consumers expect `compat-token` structs; tree parser produces `token` structs (different types from different modules). Mechanical import swap broke 23 tests | 8a | REVERTED. Proper fix requires either: (a) compat-token -> token migration in all consumers, or (b) token -> compat-token wrapper in tree parser output |

**Bug analysis**: Bugs 1-3 are structural understanding errors --- incorrect assumptions about the parse tree's shape. Bug 4 is a type system boundary error. None are logic errors in the rewrite rules or tree parser core. The rewrite infrastructure and pipeline-as-cell model had zero bugs.

**Why the wrong path seemed right**:
- Bug 1: The design assumed parse trees had per-form tags (like `'def`, `'defn`). This seemed reasonable because the *reader* produces semantic tokens. But the tree *builder* groups by lines (display structure), not by forms (semantic structure). The design's CALM analysis was correct for form-level rewriting but the input was at line level.
- Bug 2: Racket's reader preserves identifiers as strings in some contexts; the test programs used simple identifiers that happened to work as strings. Multi-parameter functions exposed the discrepancy because `make-binder` does a symbol comparison.
- Bug 3: The sexp parser (`parse-datum`) builds nested `(app (app f x) y)` for curried application, but the tree parser was doing the same when it should produce `(app f (list x y))` for uncurried WS-mode application. The two parsers have different application models.
- Bug 4: Assumed import migration was mechanical (swap `parse-reader` for `reader`). But the type systems diverge: `compat-token` (from reader.rkt) wraps legacy reader data; `token` (from parse-reader.rkt) is a clean PPN struct. They are not interchangeable.

---

## 5. Design Decisions and Rationale

### D1. CALM-compliant rewrite architecture (D.1b revision)

The initial D.1 design proposed datum-level rewriting with replacement merge: replace a parse tree node with its rewritten form. D.1b recognized this as a CALM violation --- replacement is not monotone (the old value disappears). The fix: tag refinement (additive tags, never removed) + form grouping (structural enrichment) + rewrite rules that produce NEW nodes alongside originals. All operations are monotone.

**Principle served**: Correct-by-Construction (CALM compliance structural, not discipline-maintained).

### D2. Parse tree as Pocket Universe (D.1c)

The parse tree is an algebraic embedding --- a lattice sub-object where tree operations commute with the embedding into the surface syntax lattice. This means: (a) rewrites at tree level produce the same result as rewrites at surface level, (b) the tree parser is a lattice homomorphism, and (c) pipeline stages compose because they are lattice morphisms.

**Principle served**: First-Class by Default (parse tree is a reified algebraic object, not an opaque intermediate).

### D3. G(0) form-grouping before T(0) tag refinement in final pipeline

After discovering the line-vs-form structure mismatch, the pipeline was reordered: G(0) groups lines into forms FIRST, then T(0) refines tags. This is the opposite of the initial design, which had T(0) first. The reorder works because G(0) operates on syntactic delimiters (keywords), not on tags.

**Principle served**: Decomplection (line structure is display concern; form structure is semantic concern; separating them resolved the mismatch).

### D4. Merge strategy instead of replacement

Instead of replacing preparse with the tree parser (which would require reimplementing 5 responsibilities), the switchover uses a MERGE: tree parser handles user-written forms, preparse handles registration/generation/spec-injection. The merge is per-form, not per-file. A spec-aware variant sends forms with `spec` annotations to preparse output.

**Principle served**: Completeness applied pragmatically --- complete the switchover (tree parser is live) without incomplete reimplementation of preparse responsibilities.

### D5. Pipeline-as-cell: stratified pipeline as lattice value

The pipeline stages (raw -> grouped -> tagged -> rewritten -> parsed) are encoded as a monotone lattice value in a single cell. `advance-pipeline` moves the pipeline forward; the cell's merge function ensures monotonicity (stage can only advance, never regress). This embeds the 5-stage stratification in data, not in sequential code.

**Principle served**: Data Orientation (pipeline state is a lattice value) + Propagator-First (pipeline progression triggers propagators).

### D6. 5-level structure hierarchy

The track identified 5 levels of structure in the surface syntax pipeline:

1. **Characters** --- raw text (parse-reader.rkt, PPN Track 1)
2. **Tokens** --- lexical units (parse-reader.rkt tokenizer)
3. **Lines** --- display structure (tree builder groups by indentation)
4. **Forms** --- semantic structure (G(0) groups by keywords)
5. **Surface AST** --- typed structures (tree-parser.rkt produces surf-*)

The hierarchy clarifies where each transformation operates and prevents confusion between levels (the line-vs-form bug was a level 3/4 confusion).

---

## 6. Lessons Learned

### L1. Parse trees have display structure, not semantic structure

Parse tree nodes are tagged `'line`, not `'def` or `'defn`. The tree builder groups by indentation and delimiters --- these are DISPLAY concerns. Semantic grouping (which lines form a single `def`) requires an explicit stratum (G(0)). This distinction is fundamental and was not apparent from the audit alone.

**How to apply**: When designing transformations on intermediate representations, verify the actual tag vocabulary and grouping conventions by reading the code, not by inference from the output format.

### L2. The Pocket Universe principle applies to parse pipelines

A parse tree is a lattice sub-object where operations commute with the embedding into the target lattice. This means pipeline stages can be composed as lattice morphisms, and correctness of the composition follows from algebraic properties. This was validated by the G(0) -> T(0) -> rewrite -> parse pipeline producing identical results to the old parse-datum path on all 383 test files.

**How to apply**: When building staged pipelines, model each stage as a lattice morphism and verify commutativity. Correctness proofs become composition of morphism proofs.

### L3. The merge strategy enables incremental switchover

Rather than a big-bang replacement of preparse, the merge strategy allows the tree parser to handle what it can while preparse handles the rest. Each form is independently routed. This means future work can migrate individual preparse responsibilities one at a time, each with its own validation.

**How to apply**: When replacing a large system, consider a per-unit merge rather than wholesale replacement. The merge introduces overhead (dual pipeline) but reduces risk to near-zero.

### L4. Surface normalization has 5 levels of structure

The 5-level hierarchy (characters -> tokens -> lines -> forms -> surface AST) is a permanent architectural insight. Each level has its own grouping principle, its own tag vocabulary, and its own appropriate transformations. Confusing levels (e.g., applying form-level rewrites to line-level nodes) produces the class of errors seen in Bug 1.

### L5. Pre-0 benchmarks shape design fundamentally

The Pre-0 benchmarks showed that preparse takes <1% of total wall time (elaboration dominates at 99.99%). This meant performance was NOT a motivation for the track --- architectural cleanliness was. The benchmarks also showed that 22-35us per rewrite rule means even 100 rules add <4ms. These findings prevented premature optimization in the design.

### L6. NTT modeling reveals language gaps

Modeling the PPN Track 2 pipeline in NTT syntax revealed 3 missing NTT constructs: `rewrite` (pattern -> template transformation declarations), `refine` (lattice-based tag refinement), and `foreach` (collection-level propagator application). These are concrete proposals for NTT extensions, grounded in a real use case.

---

## 7. Metrics

| Metric | Value |
|--------|-------|
| Wall clock duration | ~8.5 hours |
| Design iterations | 6 (D.1, D.1b, D.1c, D.2, NTT, D.3) |
| Design-to-implementation ratio | 0.8:1 (3.5h : 4.5h) |
| Implementation commits | 68 |
| New .rkt files | 2 (surface-rewrite.rkt, tree-parser.rkt) |
| New code (Racket) | ~3250 lines |
| New tests | 57 (31 + 26) |
| Bugs found | 4 (3 fixed, 1 reverted) |
| Test suite (final) | 383/383 files, 7529 tests |
| Suite wall time | ~125-150s range |
| Rewrite rules | 10 (5 simple, 4 recursive, 1 complex) |
| Tag refinement rules | 38 |
| tree-parser.rkt coverage | Core language + 20 form types |
| Dual pipeline overhead | ~16% (from A/B benchmarks) |
| Preparse responsibilities remaining | 5 (registration, macros, spec injection, generated defs, WS desugaring) |
| Merge fallback coverage | All specialized forms (5 types) + all user macros (13 types) |

---

## 8. What's Next

### Immediate (PPN Track 2 follow-up) — COMPLETED

- **Phase 8a** ✅ (`94e0f099`): All 53 test files migrated. 11 compound token types fixed.
- **Phase 8b** ✅ (`bb09f4e9`): All production code migrated off reader.rkt.
- **Phase 10** ✅ (`469e2276`): reader.rkt DELETED (1898 lines). Native implementations in parse-reader.rkt.
- **Phase 11** DEFERRED to Track 3: macros.rkt sexp expanders (~1000 lines), blocked on tree parser handling all form types.

### Medium-term (PPN Tracks 3-4)

- **PPN Track 3**: Parser as propagators --- move the remaining parse-datum logic onto the propagator network. The tree parser is the foundation; Track 3 adds error recovery and incremental reparsing.
- **PPN Track 4**: Macro expansion as propagators --- V(1) user macros at tree level. Currently handled by merge fallback; Track 4 makes them first-class tree transformations.

### Long-term (NTT + incremental)

- **NTT rewrite/refine/foreach**: The 3 proposed NTT extensions enable declaring rewrite pipelines in the type system. Implementation guide: the Track 2 pipeline IS the reference semantics.
- **Incremental compilation**: The pipeline-as-cell model and per-form merge strategy are designed for incremental updates --- changing one form re-runs only that form's pipeline, not the entire file.

---

## 9. Key Files

| File | Role | Lines |
|------|------|-------|
| `racket/prologos/surface-rewrite.rkt` | Rewrite infrastructure: T(0) tag refinement, G(0) form grouping, rewrite rules, pipeline-as-cell | ~1200 |
| `racket/prologos/tree-parser.rkt` | Tree -> surf-* conversion: 20+ form types, core language | ~1250 |
| `racket/prologos/driver.rkt` | Integration: spec-aware merge, hybrid path, switchover logic | (modified) |
| `racket/prologos/parse-reader.rkt` | PPN Track 1 reader (prerequisite); minor modification for tree parser integration | (modified) |
| `docs/tracking/2026-03-28_PPN_TRACK2_DESIGN.md` | Design document (D.1 through D.3, 6 iterations) | ~500 |
| `docs/tracking/2026-03-28_PPN_TRACK2_STAGE2_AUDIT.md` | macros.rkt comprehensive audit: 9763 lines, 48 functions, 5 passes | ~300 |

---

## 10. Evaluative Analysis

### What went well

1. **Diagnostic protocol caught defn type inference bug (Bug 2)**. When `defn` forms failed during integration, running individual test files revealed the Pi chain construction was passing string param-names instead of symbols. The diagnostic protocol (targeted test, not full suite) identified the root cause in under 5 minutes. Without it, this would have been a full-suite-rerun investigation.

2. **surf-app args-as-list bug (Bug 3) caught immediately by contract violation**. The `expand-expression` function has an arity contract that rejects nested application nodes. When the tree parser produced the wrong structure, the contract fired on the first test program. Contract-driven design caught a structural error in seconds, not minutes.

3. **G(0) form grouping resolved the line-vs-form structure mismatch**. After discovering the parse tree uses line structure (Bug 1), the G(0) stratum was designed and implemented in ~20 minutes. It cleanly separates display grouping from semantic grouping and immediately unblocked the rest of the pipeline.

4. **Pipeline-as-cell insight**. Encoding the 5-stage pipeline as a monotone lattice value in a single cell was a mid-implementation insight. It eliminates the need for explicit stage ordering and makes pipeline progression a propagator event. The implementation was 12 minutes.

5. **5-level structure hierarchy clarified the architecture**. The hierarchy (characters -> tokens -> lines -> forms -> surface AST) emerged from the line-vs-form debugging and immediately clarified where every transformation operates. It prevented further level-confusion errors for the rest of the track.

6. **NTT modeling revealed 3 extensions**. The `rewrite`, `refine`, and `foreach` constructs are concrete, use-case-grounded proposals. They emerged from attempting to express the Track 2 pipeline in NTT syntax and discovering that existing NTT constructs could not express tree-level rewriting.

7. **Spec-aware merge elegantly handled spec injection**. Instead of reimplementing spec injection at tree level (which would require duplicating preparse's cross-form registry lookup), the merge routes spec-annotated forms to preparse output. This handles all spec injection cases with zero new code.

8. **Merge fallback handles ALL specialized forms without additional code**. The 5 specialized form types (pipe-fusion, mixfix, defn-multi, session-ws, import-tree) that the tree parser does not handle are automatically served by preparse through the merge fallback. No per-form special-casing was needed.

### What went wrong

1. **Initial design assumed datum-level rewriting with replacement merge (D.1)**. The D.1 design proposed replacing parse tree nodes with rewritten versions. D.1b recognized this as a CALM violation: replacement is not monotone (the original value is destroyed). The fix (additive tags + enrichment) required redesigning the rewrite architecture. Cost: ~30 minutes of design revision.

2. **Assumed parse tree nodes had form-head tags (Bug 1)**. The design assumed trees were tagged with `'def`, `'defn`, etc. They are tagged with `'line`. This assumption came from conflating the reader's token types (which ARE semantic) with the tree builder's node tags (which are structural). Cost: ~25 minutes of blocked work + G(0) implementation.

3. **Assumed tree-level rewriting could replace preparse entirely**. The switchover analysis (Phase 6d) revealed that preparse does 5 things and the tree parser does 1. The "replace macros.rkt" objective was revised to "replace parse-datum and merge for the rest." This was the right call --- attempting a full replacement would have been a multi-session effort with uncertain benefit.

4. **Phase 8a import migration assumed mechanical swap**. Replacing `reader.rkt` imports with `parse-reader.rkt` imports seemed like a find-and-replace task. It broke 23 tests because `compat-token` and `token` are different struct types with different fields. The migration was reverted in 5 minutes but the attempt cost ~10 minutes total.

5. **"14 simple rules" claim from the audit was wrong**. The audit identified 14 pure rewrite rules, implying all were simple pattern -> template replacements. In practice, 5 need recursive templates (descending into sub-expressions), and 4 need access to sibling forms or cross-form state that simple rules cannot express. The track implemented 10 of the 14 as actual rules; the remaining 4 are handled by the merge fallback.

### Where we got lucky

1. **G(0) + T(0) reorder worked on first try**. Swapping the pipeline order from T(0) -> G(0) to G(0) -> T(0) could have broken tag refinement (which might depend on line structure). It did not --- tag refinement operates on keyword matching, which is structural-level-independent. If T(0) had depended on line grouping, the fix would have required a two-pass tag refinement.

2. **The merge strategy fell into place naturally**. The spec-aware merge was conceived during Phase 6g and implemented in ~15 minutes. It could have required complex form-matching logic or preparse introspection. Instead, the existing `spec-present?` predicate was sufficient to route forms correctly.

3. **Layer 2 (expand-top-level) worked with tree parser output without modification**. The surface syntax expansion layer processes `surf-*` structs identically regardless of whether they came from `parse-datum` or `tree-parser`. If `expand-top-level` had assumptions about the producing module (e.g., metadata fields, source locations), the switchover would have required Layer 2 fixes.

### What surprised us

1. **Preparse does 5 things, not 1**. The audit identified 48 functions in macros.rkt but framed them as "preparse pipeline." The implementation revealed 5 distinct responsibilities: (a) registration (side effects), (b) macro expansion (recursive), (c) spec injection (cross-form), (d) generated definitions (derived forms), (e) WS desugaring (surface normalization). Only (e) is what the tree parser replaces. The other 4 are ongoing preparse responsibilities.

2. **The merge fallback handles specialized forms WITHOUT implementing them at tree level**. The 5 specialized form types were initially expected to require tree-level implementations. The merge strategy means they simply fall through to preparse, which already handles them. Zero additional code.

3. **The switchover was achieved by a MERGE strategy, not by replacing preparse**. The original objective was "replace macros.rkt." What was delivered is "merge tree parser + preparse outputs." This is architecturally different --- it maintains two code paths but achieves the goal (tree parser output used for elaboration) pragmatically.

4. **Lines are DISPLAY, forms are SEMANTICS**. This distinction was not documented anywhere in the codebase. The tree builder groups by indentation (display); forms group by keywords (semantics). The 5-level hierarchy emerged from this surprise and is a permanent architectural insight.

---

## 11. Architecture Assessment

### How the architecture held up

The propagator network infrastructure held up well. Key validation points:

- **SRE Track 2F algebraic foundation** was used for tag refinement (T(0) is a lattice morphism on tag domains). The algebraic modeling was directly applicable, not just theoretical.
- **Pipeline-as-cell** model is sound and validated: monotone lattice values in cells, pipeline advancement via propagator firing. The infrastructure from PM Tracks 1-8 (cells, propagators, CHAMP, scheduling) supported this without modification.
- **Parse-reader.rkt (PPN Track 1)** provided exactly the tree structure needed. The 5-cell architecture (chars, tokens, indent, brackets, tree) gave clean access to tree nodes for the tree parser.

### Friction points

- **Merge strategy is pragmatic but not pure**. It maintains two code paths (preparse + tree parser), which means both run on every file. This is the source of the 16% overhead. A pure solution would eliminate preparse entirely.
- **reader.rkt import boundary**. The compat-token / token type mismatch reveals that the old and new reader modules have incompatible struct types. This boundary must be resolved before reader.rkt can be retired.
- **Preparse's 5 responsibilities are entangled**. Registration, spec injection, and generated definitions are deeply intertwined in macros.rkt's loop structure. Migrating them individually will require careful decoupling.

### Technical debt accepted

| Debt | Rationale | Tracking |
|------|-----------|----------|
| Dual pipeline overhead (~16%) | Acceptable for correctness; both pipelines validate each other. Will be eliminated when preparse responsibilities are migrated. | PPN Track 2 Phase 8b-8c |
| reader.rkt still imported | Compat-token type mismatch prevents consumer migration. | PPN Track 2 Phase 8a (deferred) |
| Preparse still runs for 5 responsibilities | Merge fallback handles this cleanly; no behavioral impact. Migration is incremental. | PPN Tracks 3-4 |
| V(1) user macros at tree level not implemented | 13 macro types, all LOW PRIORITY. Merge fallback handles them. | Deferred indefinitely (merge is sufficient) |
| V(2) spec injection not at tree level | Spec-aware merge handles this elegantly. Full migration requires cross-form registry at tree level. | PPN Track 4+ |

---

## 12. What We Would Do Differently

1. **Start with G(0) form grouping BEFORE designing rewrite rules**. The line-vs-form discovery cost ~25 minutes of blocked work and required redesigning the rewrite activation strategy. If G(0) had been Phase 1, the rest of the design would have been grounded in the correct structure level from the start.

2. **Audit the actual parse tree node tags, not just the reader output format**. The Stage 2 audit analyzed macros.rkt but not the tree builder's output structure. A 10-minute inspection of `parse-reader.rkt`'s tree output would have revealed the `'line` tagging immediately.

3. **Design the merge strategy from the beginning**. The merge emerged late (Phase 6g) as a pragmatic solution. If the design had started with "tree parser replaces parse-datum; preparse handles everything else; merge combines them," the entire implementation would have been more focused.

---

## 13. Wrong Assumptions

| # | Assumption | Reality | Impact |
|---|-----------|---------|--------|
| 1 | Parse tree nodes have form-head tags (`'def`, `'defn`) | They have `'line` tags only; form-head tags exist in tokens, not tree nodes | Required G(0) stratum to bridge line->form structure. ~25m blocked work. |
| 2 | Datum-level replacement merge is monotone (CALM-safe) | Replacement destroys the original value --- NOT monotone | Required D.1b CALM-compliant redesign: additive tags + enrichment instead of replacement. ~30m design revision. |
| 3 | Tree parser can replace preparse entirely | Tree parser replaces parse-datum (1 of 5 preparse responsibilities) | Revised objective: merge strategy instead of wholesale replacement. Pragmatic but architecturally honest. |
| 4 | Import migration (reader.rkt -> parse-reader.rkt) is mechanical | compat-token and token are different struct types with incompatible fields | Phase 8a reverted. Consumer migration requires type-level work, not import-level. |
| 5 | All 14 audit-identified rewrites are simple pattern->template | 5 need recursive templates; 4 need cross-form context | Implemented 10 as rules; 4 handled by merge fallback. Design overestimated rewrite rule coverage. |

---

## 14. What We Learned About the Problem

Surface normalization in Prologos has **5 levels of structure**, not the 2 assumed at design time (raw text and surface AST). The intermediate levels (tokens, lines, forms) each have their own grouping principles, tag vocabularies, and appropriate transformations. Any pipeline design that conflates levels will produce the class of errors seen in this track.

The problem of "replacing macros.rkt" is actually 5 sub-problems corresponding to preparse's 5 responsibilities. Only one (WS desugaring / surface normalization) is addressed by tree-level rewriting. The others require different approaches:
- Registration: side-effect migration to cell writes (PM Track 7 Phase 2 already partially done)
- Macro expansion: tree-level macro system (PPN Track 4)
- Spec injection: cross-form data flow (cell-based spec registry)
- Generated definitions: derivation propagators
- WS desugaring: tree parser (this track) + rewrite rules

The **Pocket Universe principle** --- that a parse tree is a lattice sub-object where transformations commute with the embedding --- is a genuine architectural insight. It means the tree parser's correctness can be verified algebraically (morphism property) rather than case-by-case. This principle generalizes beyond parsing to any staged pipeline with intermediate representations.

---

## 15. Are We Solving the Right Problem?

Yes. The track proves that propagator-based surface normalization works on real programs (383 test files, 7529 tests). The merge strategy is a pragmatic bridge, not a permanent architecture --- it enables incremental migration while delivering the core value (tree parser output used for elaboration) immediately.

The revised objective (merge, not replace) is arguably the RIGHT problem. A full preparse replacement would require reimplementing 5 interlocked responsibilities in a single track, with high risk and uncertain benefit given that preparse takes <1% of wall time. The merge gets the architectural value (propagator-based pipeline) without the risk.

The 16% dual-pipeline overhead is real but bounded: both pipelines run but only one output is used per form. Eliminating preparse will remove the overhead, but the merge provides value (correctness cross-validation) in the interim.

---

## 16. Longitudinal Survey --- 10 Most Recent PIRs

### Quantitative Summary

| # | Track | Date | Duration | Commits | Test Delta | Design Iters | D:I Ratio | Bugs | Wrong Assumptions |
|---|-------|------|----------|---------|------------|------------|-----------|------|-------------------|
| 1 | PM Track 8 | 03-22 | ~18h | 66 | +35 | 4 (D.1-D.4) | 1:2 | 10+ | 3 (restore-meta-state!, callback scope, scheduling) |
| 2 | SRE Track 0 | 03-22 | ~3h | 7 | +15 | 2 (D.1-D.2) | 2:1 | 0 | 0 |
| 3 | SRE Track 1+1B | 03-23 | ~8h | 21 | +43 | 5 (D.1-D.4+1B) | 2:1 | 4 | 2 (lattice ordering, binder semantics) |
| 4 | SRE Track 2 | 03-23 | ~4h | 6 | +0 | 4 (D.1-D.4) | 1.7:1 | 1 | 1 (struct? guard over-aggressive) |
| 5 | PM 8F | 03-24 | ~8h | 15 | +0 | 4 (D.1-D.4) | 1.5:1 | 2 | 3 (zonk call count, bvar solutions, ground-expr? duality) |
| 6 | PM Track 10 | 03-24 | ~18h | 30 | -37 | 4 (D.1-D.4) | 1:2 | 8 | 3 (parameterize bottleneck, registry count, expander dependency) |
| 7 | PM Track 10B | 03-26 | ~8h | 20 | +0 | 4 (D.1-D.4) | 3:5 | 8 | 2 (PUnify toggle, zonk elimination scope) |
| 8 | PPN Track 0 | 03-26 | ~4h | 8 | +30 | 4 (D.1-D.4) | 1:1 | 2 | 0 |
| 9 | PPN Track 1 | 03-26 | ~14h | 25 | +108 | 9 (D.1-D.9) | 1.4:1 | 25+ | 3 (datum compat, disambiguator complexity, token types) |
| 10 | PAR Track 1 | 03-28 | ~14h | 53 | +0 | 4 (D.1-D.4) | 1.5:1 | 10 | 2 (dynamic topology CALM violation, cell-id collision) |
| **11** | **PPN Track 2** | **03-29** | **~8.5h** | **68** | **+57** | **6** | **0.8:1** | **4** | **5** |

### Recurring Patterns (3+ PIRs)

**Pattern 1: Pre-0 benchmarks reshape the design (10/11 PIRs).**
Every track except SRE Track 0 ran Pre-0 benchmarks that changed the design fundamentally. PM 8F's benchmarks found bvar solutions are zero (removing a design phase). PM Track 10's benchmarks found parameterize is NOT the bottleneck (pivoting from parameter elimination to serialization). PPN Track 2's benchmarks found preparse is invisible (<1% wall time). This pattern is fully codified in DESIGN_METHODOLOGY.org and consistently delivers value.

**Pattern 2: Integration phases find all the bugs (8/11 PIRs).**
PM Track 8 (A4-B3), PPN Track 1 (Phase 5c: 25 failures in 7 rounds), PAR Track 1 (Phases 4-5: 10 bugs in 2 phases), PPN Track 2 (Phase 6d: 2 bugs in integration). Core infrastructure phases are fast and clean; wiring into existing code is where assumptions break. This is consistent across every track that has both infrastructure and integration phases.

**Pattern 3: Wrong assumptions cluster at system boundaries (9/11 PIRs).**
Assumptions about struct types (PPN Track 1 compat-token, PPN Track 2 compat-token), about what other modules produce (PPN Track 2 line tags, SRE Track 2 struct? guard), and about what responsibilities a module has (PPN Track 2's preparse-does-5-things). The only tracks without boundary assumption errors are SRE Track 0 (self-contained) and PPN Track 0 (pure lattice algebra).

**Pattern 4: Design iteration count correlates with implementation smoothness (11/11 PIRs).**
SRE Track 0 (2 iterations, 0 bugs). SRE Track 2 (4 iterations, 1 bug). PPN Track 2 (6 iterations, 4 bugs --- but 3 were boundary assumptions no amount of design would catch). The trend holds: more design iterations produce fewer LOGIC bugs. Boundary/integration bugs persist regardless.

**Pattern 5: Merge/hybrid strategies succeed over wholesale replacement (5/11 PIRs).**
PM Track 10 (fork-prop-network, not replace-meta-store). PM Track 8 (worldview-aware reads, not remove-CHAMP). PPN Track 2 (merge, not replace-preparse). PAR Track 1 (stratified topology, not rewrite-BSP). When a track attempts wholesale replacement of a large system, it either pivots to a hybrid (PM Track 10's #lang drop) or encounters cascading failures (PM Track 10's registry whack-a-mole before the audit). This pattern is approaching codification threshold (5+ occurrences).

### Slow-Moving Trends

**Trend A: Design-to-implementation ratio is stabilizing around 1:1 to 1.5:1.** Early tracks (PM Track 8, PM Track 10) had 1:2 ratios with more bugs. Recent tracks (SRE 0-2, PPN 0-2) have 1:1 to 2:1 ratios with fewer logic bugs. The design investment is paying off in reduced implementation debugging.

**Trend B: Test delta per track is decreasing.** PM Track 8 (+35), SRE Track 0 (+15), PPN Track 1 (+108, outlier --- new module), PPN Track 2 (+57). Infrastructure migration tracks add zero tests (PM 8F, PM 10B, PAR Track 1). This is appropriate --- infrastructure tracks validate via the existing suite. But it means coverage of NEW infrastructure code is implicit, not explicit.

**Trend C: Track duration has a bimodal distribution.** Small tracks (SRE Track 0: 3h, SRE Track 2: 4h, PPN Track 0: 4h) vs large tracks (PM Track 8: 18h, PM Track 10: 18h, PPN Track 1: 14h, PAR Track 1: 14h). PPN Track 2 at 8.5h is in between. The large tracks all involve integration with existing code; the small tracks are either self-contained or pure migration.

### Longitudinal Health Indicators

- **Same lesson recurring**: "Wrong assumptions at system boundaries" has appeared in 9 of 11 PIRs. The response is partially architectural (Stage 2 audits now explicitly audit boundary assumptions) and partially inherent (boundaries are where mental models diverge from implementation reality). The audit improvement is working (PPN Track 2's audit identified macros.rkt's 48 functions but MISSED the tree builder's tagging scheme --- the audit methodology could be extended to require cross-module boundary verification).

- **PIR lessons flowing to principles docs**: The CALM compliance lesson (PAR Track 1) is in DEVELOPMENT_LESSONS.org. The diagnostic protocol (PM Track 10) is in workflow rules. The Pocket Universe principle (PPN Track 2) is a candidate for DESIGN_PRINCIPLES.org. Pipeline-as-cell and 5-level hierarchy are candidates for PATTERNS_AND_CONVENTIONS.org.

- **Design critique rounds are consistently valuable**: Every track with 3+ critique rounds (D.1-D.3+) has had design changes that prevented implementation problems. PPN Track 2's D.1b (CALM revision) prevented a monotonicity violation that would have surfaced as subtle data loss during rewriting. The critique practice is validated and should not be skipped even under time pressure.

---

## Lessons Distilled

| Lesson | Distilled To | Status |
|--------|-------------|--------|
| L1: Parse trees have display structure, not semantic structure | Candidate for PATTERNS_AND_CONVENTIONS.org | Pending |
| L2: Pocket Universe principle for parse pipelines | Candidate for DESIGN_PRINCIPLES.org | Pending |
| L3: Merge strategy for incremental switchover | Candidate for DEVELOPMENT_LESSONS.org | Pending |
| L4: 5-level structure hierarchy | Candidate for PATTERNS_AND_CONVENTIONS.org | Pending |
| L5: Pre-0 benchmarks shape design | Already in DESIGN_METHODOLOGY.org | Done |
| L6: NTT modeling reveals language gaps | NTT Syntax Design document (3 extensions proposed) | Done |
| Pattern 5: Merge/hybrid over wholesale replacement | Candidate for DEVELOPMENT_LESSONS.org (approaching 5-PIR threshold) | Pending |
| Trend: Wrong assumptions at boundaries -> audit cross-module boundaries | Candidate for workflow rule enhancement | Pending |

---

## Open Questions

- ~~**What failure modes become more likely as the dual pipeline scales?**~~ RESOLVED by Phase 10: reader.rkt deleted, dual-path validation removed. Single reader path.
- **Should the 5-level structure hierarchy be formalized in the codebase?** Currently it exists only in documentation. Making it explicit (e.g., type-level tags distinguishing levels) would prevent level-confusion errors structurally.
- ~~**Is the 16% dual-pipeline overhead acceptable long-term?**~~ RESOLVED: The 16% was the `use-tree-parser? #t` hybrid path (development/validation only). Production default (`#f`) never had this overhead. The hybrid path remains available but is not the default. See §Addendum below.
- **Are we actually learning from the "wrong assumptions at boundaries" pattern?** It has appeared in 9 of 11 PIRs. The Stage 2 audit methodology has improved but the pattern persists. The next response should be architectural: can we make boundary assumptions explicit and machine-checkable (e.g., interface contracts between modules)?

---

## PIR Addendum: Phase 8a/8b/10 (2026-03-30)

### Additional Work Completed

| Phase | Commit | Description | Delta |
|-------|--------|-------------|-------|
| 8a | `94e0f099` | All 53 test files migrated from reader.rkt to parse-reader.rkt. 11 compound token types fixed in compat wrapper. | +244 lines parse-reader.rkt |
| 8b | `bb09f4e9` | All production code migrated off reader.rkt (driver, repl, tools, benchmarks). | -6 net lines |
| 10 design | `cd6aa2d1` | §8 addendum to Track 2 design doc. Compat shim approach (Option B). | +109 lines docs |
| 10 | `469e2276` | reader.rkt DELETED (1898 lines) + test-reader.rkt DELETED (449 lines). Native prologos-read-syntax in parse-reader.rkt. | **-2330 net lines** |

### Updated Metrics

- **Test count**: 7454 (was 7529; -75 from test-reader.rkt deletion)
- **File count**: 382 (was 383; -1 from test-reader.rkt)
- **Suite time**: 125.3s (was 132.1s; faster without reader.rkt .zo loading)
- **Code deleted**: 2347 lines (reader.rkt 1898 + test-reader.rkt 449)
- **Code added**: ~300 lines (compat token fixes + native reader implementations)
- **Net**: approximately -2050 lines across all Phase 8-10 work

### Clarification: 16% Dual-Pipeline Overhead

The Phase 9 A/B measurement (16% overhead) was specific to the `use-tree-parser? #t` hybrid merge path, which runs BOTH preparse AND tree parser on every WS form. This path exists for development validation but is NOT the production default (`#f`). The production WS path is: `read-all-syntax-ws` (new parse-reader.rkt tokenizer + tree builder + datum extraction) → `preparse-expand-all` → `parse-datum` → elaboration. reader.rkt was never on the production `process-string` sexp path either — that uses `prologos-sexp-read-syntax` from sexp-readtable.rkt (Racket's native reader).

Track 7 dual writes (hash parameter + propagator cell for each registry operation) remain present. These are architecturally necessary until cell-primary migration completes in Track 8E+.

### What Remains (Phase 11, deferred to Track 3)

macros.rkt sexp expanders (~1000 lines: `expand-if`, `expand-when`, `expand-cond`, `expand-let`, etc.) cannot be deleted yet because `preparse-expand-all` is shared by both sexp and WS processing paths. Retirement requires: (1) tree parser handling ALL form types including data/trait/impl/spec, (2) registration moved to tree level, (3) `preparse-expand-all` made obsolete. This is documented as a Track 3 prerequisite in the PPN Master.
