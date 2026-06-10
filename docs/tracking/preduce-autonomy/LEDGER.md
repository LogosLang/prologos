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

## 2026-06-10 — interactive (pre-loop) — [OWNER-DECIDED] Track 0.1 SM2 decisions D2/D5/D7
- **Decision**: Sub-model 2 (e-class cell) settled via design-options panel
  (run `wf_118652c1-716`: 3 clusters × propose/adversarial-critique + synthesis) +
  main-session owner-challenger pass + owner decisions:
  - **D2 domain home**: shared term carrier — `'eclass-refine` as a merge-registry
    relation, NOT a separate 'eclass domain (T5 census = lock-blocking falsification check).
  - **D5 probe**: redefined injected-rule probe, parallel, calibration-only; never
    gates cell shape (original Artifact-1 criterion VOID — verified tautology,
    reduction.rkt:1390 first-match-wins).
  - **D7 cost-Q (S1 commitment, Master Q5 direction)**: Q-POLYMORPHIC from day one;
    tropical = first instance; storage specialization per-Q + microbench-gated.
    NOTE: owner diverged from the session recommendation (monomorphic-tropical-now) —
    generality over fast-path.
- **Options considered**: 4-5 per cluster + critic-added options; full record in panel
  output (main-session transcript) and distilled into the design doc.
- **Principle / precedent cited**: Cell/Propagator/Scheduler orthogonality (regime as
  per-rule registry datum); merge-IS-order (sre-core.rkt:147-150); prefer-tagging-over-
  bridges (structural-thinking.md). Owner-challenger pass REFUTED the panel's cluster-A
  kill-shot with production evidence (typing-propagators.rkt:2488 — intra-cell
  cross-component propagation ships today), reopening the carrier-split as a measured
  storage decision (D4).
- **Landed in**: `docs/tracking/2026-06-10_PREDUCE_TRACK01_DESIGN.md` §2 (commit `cc12a74f`);
  lock pending T5 census + owner review of the draft.

## 2026-06-10 — interactive (pre-loop) — [ROUTINE] SM2 LOCKED — T5 census LOW + corpus amendments
- **Decision**: SM2 lock executed. T5 census (read-only agent, HEAD `533bfcab`) returned
  LOW risk: relation set is an open table-driven registry (8-edit touch surface);
  structural refinement adopted — relations are propagator kinds, cells bind ONE merge
  at creation, so e-class cells bind the product merge at creation and racing unions
  resolve by the cell's min-join (green-slice criterion); footnote: sre-identify-sub-cell
  (sre-core.rkt:2280) hardcodes equality merge for decomposition sub-cells. Corpus
  amendments per D.1 §2.7 landed in the SAME commit (Master Layer-2 → product cell +
  :enrichment declaration + D3 three-key separation; E_GRAPHS:240 BSP-rebuild analogy
  softened; E_GRAPHS §7.1 cell-value/keys/declaration amended; sketch §4.2
  superseded-banner). arXiv:2511.20782 WebSearch-verified (Arbore/Cheung/Willsey).
- **Principle / precedent cited**: workflow.md doc-drift gate ("verified-false premises
  otherwise re-import" — the 'as written' trap that killed panel option C3).
- **Landed in**: commit `db0bb8ba`

## 2026-06-10 — interactive (pre-loop) — [OWNER-DECIDED] Track 0.1 SM3 decisions D1/D2/D4
- **Decision**: Sub-model 3 (unified rule registry) settled via design-options panel
  (run `wf_f8b887ba-0ca`) + owner-challenger pass + owner decisions:
  - **D1 semantic-NAC boundary (resolves owner-census point 1)**: extraction-fixpoint
    absence — the only congruence-correct boundary (verified: congruence closure creates
    NAC matches no rhs-template analysis predicts). Termination-guard NACs DISSOLVE into
    the e-class ACI absorption law (zero build). Absent-forever = named-not-built
    escalation. Realization: monotone presence cells.
  - **D2 two-tier registry**: tier-1 declarative/serializable (the honest Track 0.3
    deliverable); tier-2 closure-resident, absorbed in METADATA ONLY (verified: ~8/14 SRE
    rules closure-resident, ctor-descs have no declarative core); declarative-core
    compiler queued as named future track.
  - **D4 storage**: "4b" — ONE compound universe cell on the persistent network,
    module-keyed components + propagator-maintained tag-index; cell-first birth;
    parameter+mirror OFF the table. Prelude-window verified non-blocking (seed-pour at
    prn-init; re-sequencing has a Track 9 trigger).
- **Carried (designed, not owner-gated)**: D5 dedup-or-error namespace merge (today's
  list-append verifiably not ACI); D6 dispatch = relation ENTRY + broadcast-over-rules
  argued on SEMANTICS not the A/B numbers (verified category error); D7 dynamism deferred
  with Track 9 trigger. SM2 backflow flag added (congruence finding weakens EAGER
  contract's structural checkability — contract stands, enforcement mechanism unverified).
- **Process note (autonomy-experiment data point #3)**: panel agents pinned to main
  cannot see branch artifacts — the synthesis flagged the SM2 lock doc as "absent" when
  it is committed on this branch. Future panels must receive the worktree path for
  branch docs.
- **Landed in**: design doc §3 (commit `e343af03`); locked at `7162f492`.

## 2026-06-10 — interactive (pre-loop) — [OWNER-DECIDED] Track 0.1 SM1 decisions (carrier / identity regime / 2′)
- **Decision**: Sub-model 1 (Layer 1) settled via panel `wf_01c38ba0-ab4` + main-session
  R-lens verifications + owner decisions:
  - **Carrier home**: EXTEND the production attribute map with reduction facets — on the
    REGROUNDED justification (Realization-B carve-outs verifiably absent + intra-cell
    production precedent; the phase-collapse thesis cannot adjudicate and is removed from
    the rationale per the justification-by-slogan guard).
  - **Identity regime**: epoch-keyed live-parse occurrence-sets (old epochs inert, no
    retraction); epoch mechanism = 2′-assessment design obligation.
  - **2′ posture**: COMMISSION a focused adversarial assessment of the registry-resident
    embryo before anything locks on it (critic-invented, unvetted, sits on the confirmed
    O(all-keys) diff-cost ceiling, front-runs D4's universe gate). SM1.4 blocked on it.
- **Main-session verifications this round**: diff-cost ceiling CONFIRMED (pu-value-diff
  diffs old vs FULL merged value; no changed-path hint on net-cell-write — any fix must
  be cell-layer per orthogonality); ".pnet cache populates it" comment is FICTION (zero
  attribute handling in pnet-serialize) — carrier is session-persistent only.
- **Autonomy-experiment data point #4**: the panel's composed architecture closed only
  through a critic-invented variant (2′) that no agent adversarially vetted — the
  owner-challenger layer caught it and the owner gated it. Pattern: panel COMPOSITIONS
  need the same skepticism as panel kill-shots.
- **Landed in**: design doc §4 (commit `183f5a52`); SM1 lock pending the 2′ assessment.

## 2026-06-10 — interactive (pre-loop) — [OWNER-DECIDED] SM1 LOCKED via the 2′ assessment (D frame)
- **Decision**: The commissioned 2′ assessment (panel `wf_9d49880c-9ea`) returned; owner
  adopted: (1) the **D frame** — eager-allocate green slice + shape-P delta-notify built
  for the attribute map now + 2′-B pre-registered at D4's gate with T-FLIP thresholds
  (80%/50% singleton fraction, 1.5× alloc cost, 1.2× suite wall) as owned conventions;
  D5 singleton-fraction count BEFORE any allocation code; (2) SM2's "singleton structural
  fast path" phrase = SATISFIED PER-CLASS (write-target datum, not storage home — no
  embryo commitment; clarifying sentence added to §2.1); (3) epochs = instrumentation-
  grade counter for the D5 measurement (ledger item 13), real epoch cell at SM1.2.
- **Assessment highlights**: 2′-as-commissioned DEAD by its own packet (per-key watcher
  install conveyor + the newly-priced dependent-fold second ceiling); shape-P
  ('pointwise-merge declared property, changed-paths from delta keys, no API change)
  verified correct-by-construction for both compound-tagged-merge and
  attribute-map-merge-fn; NAME-at-reservation DROPPED (no SM2 amendment — minted at
  allocation per lock); the "no path-declaring S0 dependents" negative invariant given
  a recorded home (§4.8 + allocation-site comments; SM3 rule registry = named exception).
- **Landed in**: design doc §4.8 + §4.6 closure + Master §Layer-1 amendment (this commit).
