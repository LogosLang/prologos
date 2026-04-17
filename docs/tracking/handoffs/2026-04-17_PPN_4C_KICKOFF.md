# PPN Track 4C — Kickoff Briefing

**Date**: 2026-04-17
**Flavor**: Kickoff briefing (not mid-work handoff) — BSP-LE Track 2B is cleanly complete; this document starts the next track.

---

## §1 Target

**PPN Track 4C: Elaboration on-network — retire ALL imperative bridges.**

From [PPN Master](../2026-03-26_PPN_MASTER.md) Track 4C row:
> 6 bridges from 4B: parametric resolution, solve-meta!, infer/err fallback, freeze/zonk, unsolved-dict, warning params. Bridges dissolve when elaboration boundary moves on-network.

**The larger goal** (user's framing, 2026-04-17): "Collapse the parsing pipeline to a single fixpoint computation." Elaboration becomes propagator-native; the entire pipeline — lex → surface → parse → elaborate — is one unified on-network fixpoint.

Early design note exists at [`../research/2026-04-07_PPN_TRACK4C_DESIGN_NOTE.md`](../research/2026-04-07_PPN_TRACK4C_DESIGN_NOTE.md). No Stage 3 design doc yet.

---

## §2 First Action Post-Compaction: Warm-Up Scan

**Before starting Stage 1 research**, scan `docs/research/` for existing Prologos research on:

- **Hypergraph rewriting grammars** — background for prior PPN series designs; likely multiple documents
- **Attribute grammars** — related research for elaboration semantics (PPN Track 4 is "elaboration as attribute evaluation")
- **Related existing PPN design docs** — PPN Track 4 design D.4, PPN Track 4B design D.2

These have served as background for prior PPN series designs already. The user's intent is to re-engage deeper context and dialogue around these for 4C.

Then hot-load the Track 4C inputs (§3 below).

---

## §3 Hot-Load (Session-Specific)

**Always-load** (every session per HANDOFF_PROTOCOL.org §2): CLAUDE.md, MEMORY.md, DESIGN_METHODOLOGY.org, DESIGN_PRINCIPLES.org, HANDOFF_PROTOCOL.org, and the auto-loaded `.claude/rules/` files.

**Session-specific for PPN 4C**:

| Document | Why it matters |
|---|---|
| [PPN Master §4](../2026-03-26_PPN_MASTER.md) "Cross-Cutting Lessons from BSP-LE Track 2B (for Track 4C Design)" | Load-bearing — 7 architectural insights explicitly curated for 4C design |
| [BSP-LE Track 2B PIR](../2026-04-16_BSP_LE_TRACK2B_PIR.md) | Full context behind the 7 lessons; reference when the PPN §4 summary isn't enough |
| [PPN Track 4 PIR](../2026-04-04_PPN_TRACK4_PIR.md) | Typing on-network; first 46% milestone |
| [PPN Track 4B PIR](../2026-04-07_PPN_TRACK4B_PIR.md) | Attribute evaluation; 90% on-network; the 6 bridges this track will retire |
| [Track 4C Design Note](../research/2026-04-07_PPN_TRACK4C_DESIGN_NOTE.md) | Existing scoping; starting point for Stage 3 design |
| Research docs from §2 scan | Hypergraph rewriting + attribute grammars — background informing design |
| [`.claude/rules/stratification.md`](../.claude/rules/stratification.md) | Generalized stratum mechanism; elaborator-strata unification is a PPN Master §4.6 candidate |
| [`.claude/rules/structural-thinking.md`](../.claude/rules/structural-thinking.md) "Direct Sum Has Two Realizations" | Module Theory tagging-over-bridges — directly relevant to 4C's "retire 6 bridges" |

---

## §4 User's Stated Framing (2026-04-17)

Direct quotes from the conversation preceding compaction:

1. *"The initial instigation for this track was to bring speculative evaluation onto the network, so that we could bring elaboration onto the network and collapse the parsing pipeline to a single fixpoint computation — that's the whole goal for PPN 4, and it's taken a number of follow-on tracks to iterate towards this."*

2. *"I'm hoping to prioritize this goal as our next major track work."*

3. *"I'm hoping to re-engage ourselves in deeper context and dialogue around our research in hypergraph rewriting grammars and attribute grammars, as it pertains to elaboration — and to warm up our contexts around that after compaction."*

4. PPN 4C and PM Track 12 are **orthogonal** (established in the same conversation). PM 12 is LSP/self-hosting prerequisite territory; does not block 4C. Sequence: 4C first.

---

## §5 Stage 1 Research Questions

When the design doc is written (Stage 3), it should address these. The earlier stages (research + audit) should bring back data on:

1. **What do hypergraph rewriting grammars contribute to elaboration design?** Specifically: how does the "parse + elaborate as a single fixpoint" framing map onto hypergraph rewriting semantics? (Re-engage with the existing research docs scanned in §2.)

2. **What do attribute grammars contribute?** PPN Track 4 framed elaboration as attribute evaluation; 4C extends this to 100% on-network. Does the attribute-grammar framing remain the right lens, or does it need refinement given the bridges we're retiring?

3. **Per-registration evaluator pattern (BSP-LE 2B A2 insight)**: how does "analyze AST-node kind at registration, install a specific evaluator propagator" interact with existing elaboration dispatch? Grep sites first (`infer`, `check`, `elab-*` dispatches).

4. **Module Theory scope sharing for each of the 6 bridges**: for each bridge, audit — can it be realized as bitmask-tagged layers on a shared carrier cell (tagging-over-bridges)? Some may directly decompose; others may need new carriers.

5. **Elaborator strata → BSP scheduler unification**: `run-stratified-resolution!` (S(-1), L1, L2) should be recast as BSP stratum handlers on the same infrastructure used by the solver. Scope check: is this part of 4C, or a separate track?

6. **Parity gate design (M3 methodology)**: `test-elaboration-parity.rkt` should be built at design time, encoding each of the 6 bridge retirements as test cases. Compare before-4C elaboration to post-4C outputs; zero semantic divergence tolerated.

---

## §6 Explicit Non-Goals

- **NOT PM Track 12**: module-loading state migration (parameters → cells) is orthogonal and belongs to PM series. Do not scope into 4C.
- **NOT LSP Track 11 features**: incremental re-elaboration is downstream of 4C; 4C provides the on-network substrate but doesn't deliver LSP-facing features.
- **NOT self-hosting**: 4C is Phase 0 Racket infrastructure; self-hosting is a separate future initiative.

---

## §7 Process Discipline (per recent methodology)

From the 7 process improvements codified during BSP-LE 2B:

- **M1 Mantra Audit at Stage 0**: before Phase 1, audit the 4C design against the mantra. Pre-existing 6 bridges are the archetypal violation; the audit names them explicitly.
- **M2 Pre-0 benchmarks per semantic axis**: not just performance. For each of the 6 bridges, benchmark the current behavior across semantic compositions (typing rules × expression kinds × bridge interactions).
- **M3 Parity skeleton at design time**: `test-elaboration-parity.rkt` is a design artifact, not a PIR follow-up.
- **W1 Belt-and-suspenders is a blocking red flag**: when retiring a bridge, either delete it or revert — don't keep both paths.
- **W2 Never use `--no-precompile` after `raco make driver.rkt`**: the runner handles compilation.
- Phase completion: 5-step blocking checklist (tests, commit, tracker, dailies, proceed).

---

## §8 BSP-LE Track 2B Final State (one-line context)

Complete. 43+ commits, PIR, 7 process improvements, A1 addendum (topology → general stratum unification), A2/A3 scoped as future work, A3 static lint (`tools/lint-parameters.rkt`) in place. 4 of 9 PIR lessons distilled. Suite 399/399, 7763 tests. Three architectural follow-ups converge on the same agenda at different layers: A1 ✅ (solver), A2-future → PPN 4C (elaboration), A3-future → PM 12 (module loading).
