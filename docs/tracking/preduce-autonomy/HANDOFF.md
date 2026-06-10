# PReduce Autonomy — Handoff

**Rewritten at the end of every iteration. Read this SECOND (after CHARTER.md) at
the start of every iteration.**

---

## Current state (as of 2026-06-10, interactive pre-loop session)

The loop has NOT yet run, and per the 2026-06-10 owner decision it does NOT run
until Phase A (Tracks 0.1–0.3 design closure) completes interactively. Charter §2
records the amended sequencing.

Done so far (all interactive, with the owner):
- Branch `preduce-autonomy` + worktree `/Users/avanti/dev/projects/prologos-preduce-auto`,
  rebased onto main at `533bfcab` (charter commit now `05a82134`).
- TBGH research layer committed to main (`c27bcc89`) — owner-ratified.
- Grounding-audit staleness fixes committed to main (`533bfcab`).
- Vision grounding audit complete: owner-decision census (8 open points, charter §3),
  drift inventory, prerequisite reality check (tropical-fuel: real, deployed, caveats
  recorded in charter §2), typing-on-network Network Reality Check: PASSES.

## Exact next step

**Interactive Track 0.1 co-design, continued** (main session, owner present — NOT a
loop iteration). DONE 2026-06-10: closure semantics decided (decisions-first → coarse
NTT exit gate); SM2 (e-class cell) SETTLED via options panel + owner decisions D2/D5/D7
— see `docs/tracking/2026-06-10_PREDUCE_TRACK01_DESIGN.md` §2 and the ledger entry.
DONE: SM2 LOCKED (db0bb8ba). SM3 LOCKED (tier census pinned §3.7: 13 rules 5/8 split,
28 ctor-descs, 17 pnet registries, 41-entry seed pour with 5 serializable; naming
scheme delivered §3.4; make-rewrite-propagator-fn disposition = rework as broadcast
item-fn at SP3).
NEXT: (a) SM1 (AST PU layout) — carries the carrier-root-index requirement fed back
from SM3 §3.4; recommended next. (b) Then SM4 (re-derive "two strata suffice" incl.
congruence watchers + fuel + presence cells), SM5 (effect posture — owner-census
point 5: design against comment-only Stratum 3 vs gate), SM6 (persistence regimes —
consumes D3 content-address key + tier split). (c) DEFERRED.md triage still pending.
(d) R-lens carried: T3/T4 (SM2.3), T7 (SM6/0.3), broadcast-write-shape vs product
merge (SP3).
PROCESS: panels read MAIN checkout — pass the worktree path
(/Users/avanti/dev/projects/prologos-preduce-auto) for branch docs (ledger data
point #3).

## If the loop is started before Phase A completes

Do NOT begin Track 1 implementation — Phase A designs are not locked. The only
loop-eligible work is read-only grounding prep (e.g., per-sub-model code-surface
audits feeding the interactive co-design). When in doubt, halt with a BLOCKED
ledger entry per charter §8.

## Open threads

- Owner-decision census: 8 open points listed in charter §3; TBGH ratification resolved.
- DEFERRED.md triage not yet done (A.0 leftover; fold into 0.1 opening).
- MASTER_ROADMAP: dedicated PReduce rollup section under PRN still to be added
  (noted in Master references, 2026-06-10).
- Main is advancing concurrently (owner's PPN 4C session); rebase this branch onto
  main at each interactive session boundary, and re-verify HEAD-pinned citations after
  each rebase.

## Gate status

Docs-only commits so far; no code changes on this branch; no gates run. Suite state
inherited from main (8380/0 green per `82f22446` commit message).
