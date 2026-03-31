# PPN Track 2B: Production Deployment + Mixfix Pocket Universe — Post-Implementation Review

**Date**: 2026-03-30
**Duration**: ~10 hours across 1 session
**Commits**: 18 (from `3457c6ca` Phase 0 through `eba3aad7` Phase C.1+C.2)
**Test delta**: 7459 → 7454 (test-reader.rkt deleted in Track 2 Phase 10; no new test files)
**Code delta**: ~600 lines added (surface-rewrite.rkt +450, tree-parser.rkt +40, driver.rkt merge +60, parse-reader.rkt +50), ~100 lines deleted (driver.rkt old paths)
**Suite health**: 382/382 files, 7454 tests, all pass
**Design iterations**: D.1, D.1b, D.2, D.3, §11 (implementation finding), §12 (propagator redesign), D.2c, D.3b, §12 revision
**Design docs**: [PPN Track 2B Design](2026-03-30_PPN_TRACK2B_DESIGN.md)
**Prior PIRs**: [PPN Track 2](2026-03-29_PPN_TRACK2_PIR.md), [PPN Track 1](2026-03-26_PPN_TRACK1_PIR.md)
**Series**: PPN (Propagator Parsing Network) — Track 2B

---

## 1. What Was Built

PPN Track 2B deploys Track 2's tree parser to the production path and implements propagator-native mixfix resolution. The track closes Track 2's "validated but not deployed" gap (the `use-tree-parser?` parameter that defaulted to `#f`).

Three layers of work:

1. **Merge infrastructure**: A source-line-keyed merge function that routes each form's output from either preparse or tree parser based on identity matching (source line) and a per-form lattice join function (`merge-form`). Deployed on `process-file` and `process-string-ws`.

2. **Mixfix Pocket Universe**: A DAG-stratified claim lattice for resolving operator precedence in `.{...}` expressions. Position-aware claims make the merge commutative/associative/idempotent. Comparison chaining as a separate pre-pass stratum. Unary minus detection.

3. **Expression form coverage**: Pipe/compose rewrite rules in surface-rewrite.rkt. Error stubs for 22+ preparse-consumed forms. Error propagation fixes in parse-eval/check/infer-tree. Tag refinement for check/infer. `>>` disambiguator merge. G(0) mixfix context fix for `<`/`>` as operators.

---

## 2. Timeline and Phases

| Phase | Commit | What |
|-------|--------|------|
| 0 | `3457c6ca` | Acceptance file |
| 0.5 | `9a8f9158` | 15 error stubs for preparse-consumed forms (D.3 F1) |
| 1 | `67df701f` | Extract merge-preparse-and-tree-parser |
| 2+3 | `8a263d89`, `b7809237` | Wire merge into process-file. **AST parity gap discovered** (§11). |
| A+B | `3c1bb200` | Pipe/compose rewrite rules + `>>` disambiguator |
| E partial | `8ff16dca` | Defn Pi chain fix |
| F | `ebb3b290` | **MERGE DEPLOYED** — source-line-keyed identity matching |
| G | `6f599054` | `use-tree-parser?` DELETED |
| C prereq | `38383e3b` | G(0) mixfix context: `<` `>` preserved as operators in `.{...}` |
| C | `8574079a` | Mixfix Pocket Universe — DAG-stratified claim lattice |
| C.1+C.2 | `eba3aad7` | Comparison chaining + unary minus |

Design-to-implementation ratio: ~5h design (D.1 through D.3b + §12) : ~5h implementation. Approximately 1:1.

---

## 3. What Went Well

1. **The source-line-keyed merge solved the queue alignment problem.** Three merge policies were tried (original spec-aware, conservative eval-only, queue-based). All failed due to positional correspondence fragility. The identity-based approach (match by source line, not by position in list) was correct-by-construction — no alignment, no ordering dependency. The merge-form function IS the lattice join.

2. **The diagnostic protocol prevented thrashing.** When the merge produced 11 failures, the protocol said: audit the full domain before fixing. The audit identified 3 root cause categories and the queue mechanism as the fundamental flaw. Without the audit, we would have spent hours fixing individual symptoms.

3. **G(0) mixfix context fix was found through the audit.** The `<`/`>` being consumed as angle brackets inside `.{...}` was only discovered by systematically testing every mixfix expression pattern. Without the audit, this would have been a late surprise during mixfix implementation.

4. **The Pocket Universe claim lattice is genuinely propagator-native.** Position-aware claims, commutative merge, DAG-stratified resolution. The dataflow fold (tightest-to-loosest) is the scheduling of information flow, not an algorithm. The comparison chaining pre-pass is Decomplection applied — separate concerns, separate strata.

---

## 4. What Went Wrong

1. **Three failed merge policies before finding the correct one.** The original spec-aware merge, conservative eval-only merge, and queue-based merge all produced test failures (11-22 failures each). Each attempt took 15-30 minutes to implement and validate. Total wasted: ~1.5 hours. The root cause was starting with algorithmic thinking (queues, positional counting) instead of information-flow thinking (identity matching, lattice join).

2. **Track 2's "switchover" was not actually deployed.** The `use-tree-parser?` parameter defaulted to `#f`. Track 2 declared the switchover "complete" (Phase 6g) but never flipped the default. This is the exact pattern the "Validated ≠ Deployed" lesson warns against — and the lesson was codified DURING this track, not before it. The lesson came too late to prevent the gap it describes.

3. **Imperative thinking kept creeping back into propagator design.** The Pratt parser temptation, the queue-based merge, the recursive tree builder — each time the design defaulted to algorithms before being redirected to information flow. The user had to push back repeatedly: "if we're not doing the propagator-only approach now, for what reason not?"

---

## 5. Where We Got Lucky

1. **The acceptance file caught trait syntax early.** The initial acceptance file had wrong trait syntax (`spec greet-msg` instead of `greet-msg : A -> String`). This was caught on the first run, preventing a false baseline.

2. **The `>>` disambiguator fix happened to also fix the compat tokenizer.** Adding `>>` merge to the disambiguator made the compat-merge-compose post-pass a no-op — the merge happens earlier now. This was unintentional but correct.

---

## 6. What Surprised Us

1. **The AST parity gap was wider than anyone anticipated.** The Track 2 PIR said "Phase 8a fix: 2-3 hours." The actual gap required: 22+ error stubs, error propagation fixes, defn Pi chain fix, G(0) mixfix context fix, `>>` disambiguator merge, pipe/compose rewrite rules, full mixfix resolution, comparison chaining, unary minus. The "validated on test path ≠ validated on production path" lesson was the most important finding of the track.

2. **`load-module` cannot use the merge.** Recursive module loading creates unbounded read-to-tree chains. Library modules must use preparse-only on cold cache. This was not anticipated in the design and required a principled exclusion decision.

3. **The `<` and `>` disambiguation inside `.{...}` is a tree-builder infrastructure issue.** Both G(0) form grouping and `group-tokens` needed fixes. The datum-level `group-items` already handled this correctly — the tree pipeline had a parity gap at the infrastructure level.

---

## 7. How the Architecture Held Up

The propagator network infrastructure held up well:
- **Rewrite rules** worked exactly as designed for pipe/compose
- **Tag refinement** (T(0)) was easily extended for check/infer
- **Parse-reader.rkt** cell architecture required minimal changes (disambiguator fix, group-tokens fix)

Friction points:
- **The merge is imperative scaffolding.** The source-line-keyed merge, while correct, is not propagator-native. §12.6 documents the three components (lattice join = permanent, identity matching = scaffolding, scheduling = scaffolding). Track 3-4 replaces the scaffolding with shared cells and propagator firing.
- **macros.rkt dependency for operator tables.** surface-rewrite.rkt imports from macros.rkt for operator/precedence data. This creates a dependency from the replacement (surface-rewrite) on the replaced (macros). Track 3 should extract operator data into a shared module or cell.

---

## 8. What This Enables

- **Track 3 starts on a clean foundation.** The tree parser merge is live. `use-tree-parser?` is deleted. Mixfix is resolved at tree level. No "fix the tree parser first" prerequisite.
- **Mixfix claim lattice is reusable.** The position-aware claim lattice pattern applies to any precedence resolution. Track 3's grammar productions could use the same pattern for ambiguity resolution.
- **Source-line merge pattern informs cell-based merge.** The `merge-form` function is the permanent lattice join. Track 3-4 makes it a cell merge function directly.

---

## 9. Technical Debt Accepted

| Debt | Rationale | Tracking |
|------|-----------|----------|
| Merge identity via source-line key | Scaffolding — Track 3 replaces with shared cells | PPN Master Track 3 notes |
| Merge scheduling via sequential map | Scaffolding — Track 3 replaces with propagator firing | PPN Master Track 3 notes |
| macros.rkt import for operator data | Expedient — Track 3 extracts to shared module or cell | PPN Master Track 3 notes |
| load-module excluded from merge | Recursive merge unbounded — Track 3 cells eliminate recursion | PPN Master Track 3 notes |
| Phase 5 (preparse-expand-all param) shelved | Optimization of soon-to-be-replaced infrastructure | Not tracked — superseded by Track 3 |
| Expression keyword handlers deferred | Error stubs + merge fallback handles correctly | PPN Track 3 scope |
| Defn variant parity partial | Multi-arity pattern defn returns error → preparse fallback | PPN Track 3 scope |

---

## 10. What Would We Do Differently

1. **Start with source-line-keyed identity matching from the beginning.** The queue-based approach was three wasted attempts. If we had applied information-flow thinking from the start ("each form has an identity, both pipelines write, the lattice resolves"), we would have skipped the queue entirely.

2. **Audit the full domain BEFORE the first merge attempt.** The 11 failing tests after the first merge revealed problems that a pre-implementation audit of all form types would have caught. The diagnostic protocol says "audit first" — we should have applied it proactively.

3. **Resist algorithmic thinking more aggressively.** Every time we reached for an algorithm (Pratt parser, recursive tree builder, queue alignment), it was the wrong approach. The propagator-native design was always simpler and more correct. The user's principle — "if we're not doing the propagator-only approach now, for what reason not?" — should be the FIRST question, not the corrective.

---

## 11. Wrong Assumptions

| # | Assumption | Reality | Impact |
|---|-----------|---------|--------|
| 1 | Track 2's "switchover" was production-deployed | `use-tree-parser?` defaulted to `#f` — tree parser never ran in process-file | Entire Track 2B was needed to close this gap |
| 2 | Queue-based merge preserves correspondence | Different error counts cause misalignment — wrong forms substituted | 3 failed merge policies, ~1.5h wasted |
| 3 | Tree parser produces elaboration-equivalent output for all forms it handles | False positives: non-error surf-* with wrong internal structure | 11-22 test failures from first merge attempt |
| 4 | Mixfix resolution is a simple pattern→template rewrite | Requires: claim lattice, DAG stratification, comparison chaining pre-pass, unary detection, G(0) context fix | Phase C was the largest implementation phase |
| 5 | `<` and `>` are always bracket delimiters in the tree pipeline | Inside `.{...}`, they're comparison operators. G(0) and group-tokens needed fixes | Discovered through systematic mixfix audit |

---

## 12. What We Learned About the Problem

**"Validated on test path" ≠ "validated on production path"** is a deeper lesson than the original "Validated ≠ Deployed." The Track 2 validation was against `process-string-ws` with simple test inputs. Production `.prologos` files processed by `process-file` exercise more complex forms (inline type annotations, match bodies, mixfix, relational keywords). The boundary between test validation and production deployment is where hidden assumptions live.

**The merge problem IS a lattice design problem.** Three imperative attempts failed. The information-flow approach (identity matching + lattice join) succeeded immediately. This validates the project's propagator-first principle: when you encounter a problem that feels like it needs an algorithm, look for the lattice structure. The algorithm is the lattice's eager evaluation.

**Mixfix resolution is information flow, not parsing.** The Pratt parser is an algorithm that scans left-to-right. The claim lattice is information that accumulates monotonically. The DAG structure determines which information wins. Position-awareness makes the merge order-independent. This is fundamentally different from "parsing with precedence" — it's "accumulating claims on a shared structure."

---

## 13. Are We Solving the Right Problem?

Yes. Track 2B closes the gap between Track 2's validated architecture and production deployment. The merge is live, the parameter is deleted, mixfix is resolved by the claim lattice. Track 3 inherits a working single-pipeline architecture.

The scope evolution (from "deploy the merge" to "achieve AST parity including propagator-native mixfix") was driven by the Completeness principle and the user's pushback against deferral. Each scope expansion was justified by what implementation revealed — not by design ambition. The final scope is exactly what Track 3 needs.

---

## 14. Lessons for Codification

| Lesson | Candidate For | Status |
|--------|---------------|--------|
| "Validated on test path" ≠ "validated on production path" | DEVELOPMENT_LESSONS.org | New — extends Validated≠Deployed |
| Identity-based matching over positional correspondence | DEVELOPMENT_LESSONS.org | New — information-flow over algorithms |
| Resist algorithmic thinking: look for the lattice | DESIGN_PRINCIPLES.org | Reinforces Propagator-First |
| Comparison chaining as separate stratum (Decomplection) | PATTERNS_AND_CONVENTIONS.org | New — pre-pass pattern for orthogonal concerns |
| G(0) context sensitivity (bracket meaning changes by context) | PATTERNS_AND_CONVENTIONS.org | New — context-dependent grouping |

---

## 15. Open Questions

- **Should the merge's `merge-form` function be tested independently?** It's the permanent lattice join. Unit tests on `merge-form` would validate the join's algebraic properties (commutativity, associativity, idempotence) before Track 3 uses it as a cell merge function.
- **How many expression forms does the tree parser handle correctly vs falling back to preparse?** The merge masks this — everything works, but some forms are tree-parser-native and others are preparse-fallback. A coverage audit would quantify Track 3's remaining work.
- **Does the mixfix claim lattice handle all user-defined operators correctly?** The current implementation reads `effective-operator-table` from macros.rkt parameters. User-defined operators via `:mixfix` spec metadata are included. But no test exercises a user-defined precedence group.
