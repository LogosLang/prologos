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
