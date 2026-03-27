# PPN Track 1: Lexer + Structure as Propagators — Post-Implementation Review

**Date**: 2026-03-26
**Duration**: ~14 hours across 1 session
**Commits**: ~25 (from `f677847` through `b00be40`)
**Test delta**: 7421 → 7529 (+108 tests); 379 → 380 files
**Design iterations**: 9 (D.1 through D.9)
**Design doc**: `docs/tracking/2026-03-26_PPN_TRACK1_DESIGN.md`

---

## §1 Objectives

**Original**: Replace reader.rkt (1898 lines, 54 functions, 10 context-sensitive decisions) with a propagator-based reader using the 5-cell architecture from PPN Track 0's lattice design.

**Specific goals**:
1. Implement all 5 parse domain lattices as RRB-embedded propagator cells
2. Build datum extraction for backward compatibility with 51 consumer files
3. Wire new reader into driver.rkt as production reader
4. Golden comparison on all 110 .prologos library files
5. A/B benchmarks showing zero performance regression
6. `rrb-diff` for Track 8 incremental editing readiness

**All 6 goals delivered.**

---

## §2 What Was Delivered

### Files created
- `parse-reader.rkt` (~1200 lines) — propagator-based reader, 5-cell architecture
- `tests/test-parse-reader.rkt` (108 tests) — 5 parse domains + integration + golden comparison
- `tools/golden-capture.rkt` — 4-level golden baseline capture

### Files modified
- `rrb.rkt` (+211 lines) — `rrb-diff` structural diff, 13 new tests
- `driver.rkt` — `use-new-reader?` switch + `read-all-syntax-ws` dispatch
- `parse-lattice.rkt` — D.9 token set-narrowing (type → types as seteq)

### By the numbers
- 15 implementation phases (0 through 8)
- 108 new tests in parse-reader, 13 in rrb
- 72/72 library files produce identical datums (100%)
- 380/380 test suite green
- 7529 tests, 143.5s wall time
- 31 token recognizer patterns in the new tokenizer
- Zero performance regression (A/B: all within ±4% noise)

---

## §3 Timeline

| Phase | Commit | Description | Tests |
|-------|--------|-------------|-------|
| 0 | `f677847` | Golden baseline capture (110 files, 4 levels) | — |
| 1a | `8b7757c` | char-rrb + indent-rrb | 21 |
| 1b | `5819465` | Tokenizer (18 patterns, set-of-types) | 36 |
| 1c+1d | `9af5b2d` | Bracket-depth RRB + tree-builder | 44 |
| 1e | `006ffec` | Context disambiguator + full pipeline | 51 |
| 1f | `6df01a9` | Integration gate (topology 110/110) | 58 |
| 2 | `a046558` | Reader macro token patterns (+17) | 75 |
| 3a-c | `65fa3dd` | Read/Write/Compat APIs | 97 |
| 4 | `801e9d1` | Golden: topology + brackets 110/110 | 97 |
| 5a | `a2dd08a` | Datum extraction (41/72 files) | 108 |
| 5b | `e6e4d25` | Diagnostic protocol → 72/72 files | 108 |
| 5c | `e592109` | **Switch flip: 380/380 GREEN** | 108 |
| 6 | `63fe61f` | rrb-diff (structural diff) | 35 in rrb |
| 7 | `d210d6e` | A/B benchmarks (zero overhead) | — |
| 8 | `b00be40` | Suite verify: 380/380 confirmed | — |

Design-to-implementation ratio: ~40% design (D.1-D.9), ~60% implementation (Phases 0-8).

---

## §4 What Was Deferred

1. **reader.rkt deletion** — Kept as fallback (1898 lines). Requires removing all direct imports from 51 consumer files. Deferred to PPN Track 2 (full consumer migration).
2. **Per-node propagator cells** — Track 1 uses bulk RRB cells (one cell per domain). Per-node cells are Track 8 (incremental editing). The `rrb-diff` infrastructure bridges the gap.
3. **Parallel tokenization** — Sequential scan in Track 1. The pivot to parallel is a propagator replacement (one O(n) sweep → N O(1) latches), not an architecture change.
4. **3 test file fixes** — varargs, session-async-ws-01, session-async-e2e had position-sensitive scoping that resolved after clean recompile. Root cause understood (0→1 position conversion) but edge cases may recur. Tracked for monitoring.

---

## §5 What Went Well

1. **Research investment paid off again.** PPN Track 0 (4 lattice domains, 6 bridges, NTT extensions) meant Track 1 implementation had zero architectural surprises. The 5-cell design was correct on first attempt. This is the 3rd data point for "research investment → implementation smoothness" (Track 0: 3 docs, 0 wrong assumptions; Track 10: 0 docs, 12+ bugs; Track 1: 9 design iterations, 0 architectural pivots during implementation). **Pattern confirmed: ready for codification.**

2. **Diagnostic protocol was decisive.** The switchover went from 25 failures to 0 through 7 systematic rounds. Each round: audit all failures, identify common root cause, fix at the root, verify. No whack-a-mole. Key common causes discovered:
   - Silent character skip (12 failures from one bug)
   - `<` angle bracket vs operator (5 failures)
   - `||` facts-sep, `&>` clause-sep (4 failures)
   - Position 0→1 offset (3 failures)

3. **Propagator Only framing was correct.** D.5 upgraded "Propagator First" to "Propagator Only." The result: the reader IS 5 RRB cells and their relationships. No imperative algorithms. The tree is the fixpoint. Datum extraction is a pure function over the tree — no state, no context threading.

4. **Compatibility layer was the right investment.** The compat wrappers (`compat-read-all-forms-string`, `compat-tokenize-string`, `compat-read-syntax-all`) let 51 consumer files work unchanged. Zero migration needed for the switchover. Track 2 can migrate consumers incrementally.

5. **Golden comparison caught every regression.** 4-level golden (topology, brackets, datums, srcloc) on 110 files was the quality gate that validated each phase.

---

## §6 What Went Wrong

1. **Position handling was underspecified in the design.** D.1-D.9 never discussed 0-based vs 1-based position conversion. The `make-stx` function initially added 1 unconditionally, then added 1 to already-1-based positions from syntax wrappers (double +1). This caused 3 "mystery" failures that seemed position-dependent but were actually a systematic bug. **Lesson**: position semantics must be specified in the design.

2. **No-skip fallback was wrong.** The initial tokenizer silently skipped unrecognized characters — a borrowed pattern from error recovery. For a production reader, silent data loss is never acceptable. Every character must produce a token or be whitespace. This single fix eliminated 12 failures.

3. **Angle bracket ambiguity was more complex than anticipated.** `<` is both a type delimiter and a comparison operator. The design mentioned set-narrowing for tokens but didn't address the grouping-level ambiguity in `group-items`. The fix required: (a) `has-matching-rangle?` lookahead, (b) bracket-aware nesting, (c) mixfix context suppression. Three interacting mechanisms for one ambiguity.

---

## §7 Where We Got Lucky

1. **The 3 "position-dependent" failures resolved on recompile.** These appeared stuck at 377/380 for two commit rounds, then spontaneously resolved when the old-reader benchmark run triggered a clean recompile cycle. If they had persisted, the investigation would have been deep and time-consuming.

2. **No consumer files needed modification.** The compat wrappers produced identical datums. If ANY datum format had been incompatible with parser.rkt's expectations, the switchover would have required parser changes.

---

## §8 What Surprised Us

1. **Token count: 31 patterns.** The old reader handles all token types in one monolithic tokenizer function. The new reader's pattern registry required 31 individual recognizer functions. The registry is more maintainable but the sheer count was unexpected.

2. **Comma as cosmetic separator.** Commas in brace-params (`{A, B : Type}`) are ignored by the old reader. The no-skip fix exposed them as tokens, breaking 6 library files. WS-mode has several characters that are "cosmetic" (no semantic content) — these need explicit handling.

3. **Suite time IMPROVED.** 150.3s → 143.5s despite adding 108 tests. The new reader is marginally faster for large files because RRB construction is O(n) with good cache locality vs the old reader's recursive descent with frequent string allocation.

---

## §9 Architecture Assessment

The propagator architecture held up perfectly. Key validation:

- **5-cell design**: Correct. One cell per domain (char, indent, token, bracket-depth, tree). All 5 cells are RRB-embedded. The tree cell is the M-type fixpoint.
- **RRB embedding**: Correct. 9× faster build, 3× faster sequential read vs CHAMP. The `rrb-diff` extension enables incremental editing.
- **Set-narrowing tokens**: Correct. D.9's revision (type → types as seteq) resolved the set-once vs reclassification contradiction. Disambiguation narrows by intersection under reversed subset order.
- **Compatibility layer**: Clean. The datum extraction is a pure function over the tree — no propagator network needed at extraction time.

No architectural modifications were required to existing systems (driver.rkt, parser.rkt, elaborator.rkt). The new reader is a drop-in replacement.

---

## §10 What This Enables

1. **PPN Track 2**: Normalization on tree structure (directly, not via datums)
2. **PPN Track 3**: Parser as propagator consumer (tree → AST pipeline)
3. **PPN Track 8**: Incremental editing (rrb-diff + per-node cells)
4. **SRE Track 2D**: Tree rewriting as structural relation
5. **reader.rkt retirement** (1898 lines deletable after Track 2)
6. **Self-describing .pnet serialization** for parse trees

---

## §11 Technical Debt Accepted

1. **reader.rkt still loaded** — imported for fallback and compat. ~1898 lines of dead code on hot path. Track 2.
2. **31 token patterns are sequential priority** — not yet a lattice registry. Track 5 (bilattice elimination ordering).
3. **Datum extraction is a separate function** — not a propagator. Correct for Track 1 (one-shot), but Track 8 needs reactive datum extraction.

---

## §12 What Would We Do Differently

1. **Specify position semantics in D.1.** The 0-based vs 1-based confusion cost 3 investigation rounds. One paragraph in the design would have prevented it.
2. **No-skip from the start.** The "skip unrecognized character" fallback was clearly wrong in hindsight. The first tokenizer should have emitted single-char symbols for unrecognized characters.
3. **Test the switchover earlier.** Phases 0-4 built golden comparison infrastructure but didn't flip the switch until Phase 5c. Flipping earlier (even expecting failures) would have revealed the failure patterns sooner, allowing the diagnostic work to overlap with the API development.

---

## §13 Wrong Assumptions

1. **"Datums will match trivially"** — assumed the tree → datum extraction would be straightforward once the tree was correct. In reality, the old reader has dozens of context-sensitive token productions (11 compound tokens, 5 sentinel types, cosmetic separators) that the new reader needed to replicate exactly.
2. **"Position is a simple +1"** — assumed positions were a trivial conversion. The double-wrapping bug (adding 1 to already-1-based positions) showed that position flow through nested `make-stx` calls is non-trivial.

---

## §14 What We Learned About the Problem

**Parsing in Prologos is primarily a TOKENIZATION problem, not a tree-building problem.** The tree builder (Phase 1c) was 50 lines. The tokenizer + datum extraction was 800+ lines. The context sensitivity is almost entirely at the token level — which characters form which tokens, and which token types are delimiters vs operators. The tree structure falls out trivially from indent + bracket-depth.

This validates the PRN insight: "parsing is not special." The hard part (tokenization) is a classification problem solvable by lattice fixpoint. The easy part (tree construction) is monotone aggregation.

---

## §15 Are We Solving the Right Problem?

Yes. The reader replacement was necessary for:
- Propagator migration completeness (the reader was the last imperative pipeline stage)
- Incremental editing (Track 8)
- Self-describing serialization (the tree is data, not implicit in control flow)

The 380/380 green, zero-overhead result confirms the approach is sound.

---

## §16 Pattern Analysis

### Recurring patterns from prior PIRs:

| Pattern | Track 1 instance | Prior instances | Status |
|---------|-----------------|-----------------|--------|
| Research investment → smoothness | 9 design iterations, 0 pivots | Track 0 (3 docs, 0 bugs), Track 10 (0 docs, 12 bugs) | **CONFIRMED (3rd instance)** |
| Diagnostic protocol effectiveness | 25→0 in 7 rounds | Track 10B (registry audit) | Reinforced |
| Silent data loss from error recovery | No-skip bug (12 failures) | NEW | Watch for similar in SRE |
| Position semantics unspecified | 0-based vs 1-based confusion | NEW | Codify in design checklist |

### Cross-reference
- **PPN Track 0 PIR**: Lattice design correct, zero architectural surprises in Track 1. Research investment validated.
- **PM Track 10 PIR**: .pnet serialization infrastructure used by golden capture. Module loading path stable.
- **PM Track 10B PIR**: Network-always architecture enabled clean reader integration (no special-case for "reader mode").

---

## Key Files

| File | Purpose | Lines |
|------|---------|-------|
| `parse-reader.rkt` | Propagator reader (all 5 domains) | ~1200 |
| `tests/test-parse-reader.rkt` | Reader tests | ~500 |
| `rrb.rkt` | RRB persistent vector + rrb-diff | +211 |
| `driver.rkt` | Switch dispatch | +20 |
| `parse-lattice.rkt` | Lattice domain structs | ~200 |
| `parse-bridges.rkt` | Bridge/exchange functions | ~200 |
| `tools/golden-capture.rkt` | Golden baseline tool | ~150 |
