# PReduce Autonomy — Decision Ledger

Append-only. One entry per non-trivial decision. Labels per CHARTER.md §3:
ROUTINE / SIGNIFICANT / ⚠ OWNER-PROVISIONAL. Newest entries at the BOTTOM
(append-only means chronological reading order; the owner reviews top-to-bottom
from their last review point).

Entry template:

```
## YYYY-MM-DD — iteration N — [LABEL] short title
- **Decision**:
- **Options considered**: (SIGNIFICANT and above)
- **Principle / precedent cited**:
- **Reversal path**: (OWNER-PROVISIONAL only)
- **Landed in**: commit hash / doc link
```

---

## 2026-06-10 — iteration 0 — [ROUTINE] Charter + coordination spine established
- **Decision**: Experiment infrastructure created interactively (with owner) before
  loop start: branch `preduce-autonomy` + worktree at
  `/Users/avanti/dev/projects/prologos-preduce-auto` based at main `d1586b15`;
  CHARTER.md, LEDGER.md, HANDOFF.md, dailies directory under
  `docs/tracking/preduce-autonomy/`.
- **Principle / precedent cited**: HANDOFF_PROTOCOL.org (file-based session
  continuation); workflow.md dailies discipline; charter co-designed with owner
  in the 2026-06-10 main session.
- **Landed in**: (this commit)

## 2026-06-10 — interactive (pre-loop) — [OWNER-DECIDED] TBGH frame ratified; research layer committed
- **Decision**: Owner ratified the TBGH (Tiurin–Barrett–Ghica–Hu semilattice-enriched
  SMC, arXiv:2406.15882) frame adoption from the 2026-05-09 utm-fl substrate notes,
  and directed committing the entire uncommitted PReduce research layer to main.
  This closes the #1 ranked owner question from the 2026-06-10 grounding audit
  (no ratification trace existed; the amendment layer was working-tree-only).
- **Landed in**: main `c27bcc89` (research layer, 44 files), `533bfcab`
  (audit-driven staleness fixes); branch rebased onto main (`05a82134`).

## 2026-06-10 — interactive (pre-loop) — [OWNER-DECIDED] Phase A is interactive; loop entry = Phase B
- **Decision**: Tracks 0.1–0.3 design closure happens as main-session co-design with
  the owner; the autonomous loop starts at Phase B (Track 1 onward) against locked
  designs. Charter §2 amended accordingly.
- **Principle / precedent cited**: workflow.md "novel-design implementation is
  categorically main-session" + §18.18.6.13 design-via-workflow lesson; the
  grounding audit found ~9 open owner-decision points concentrated in 0.1–0.3.
- **Landed in**: (this commit)

## 2026-06-10 — interactive (pre-loop) — [ROUTINE] Grounding-audit findings adopted as planning inputs
- **Decision**: The 2026-06-10 vision-grounding audit (5 facets + adversarial critic,
  HEAD `0b6f46d5`) and the typing-on-network Network Reality Check (HEAD `82f22446`,
  verdict: PASSES — production typing is genuinely on-network, cell-read authoritative,
  `infer/err` fallback-only; hybrid at the parametric-dict-meta edge) are the grounding
  baseline for Phase A co-design. Key reusable facts: tropical-fuel production-deployed
  but residuation unconsumed; e-class `:order :refinement` has no SRE realization path;
  "two strata suffice" asserted-not-derived (congruence rebuild unassigned; Stratum 3
  comment-only); S(-1) = `process-retraction` unified handler since 2026-05-20.
- **Landed in**: audit synthesis in main-session transcript; durable corrections in
  main `533bfcab`.
