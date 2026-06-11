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
- **Landed in**: design doc §4.8 + §4.6 closure + Master §Layer-1 amendment (commit `d702b9c5`).

## 2026-06-10 — interactive (pre-loop) — [OWNER-DECIDED] SM4 LOCKED — exhibited strata table + tier vocabulary + single source + prn home
- **Decision**: SM4 settled+locked in one round (panel `wf_0a69bf63-f7f` + mempalace
  prior-art probes, recency-adjudicated). Owner: (1) TIER vocabulary — rule-dispatch
  strata = S0 + S(-1); everything else = tier-ordered handler INSTANCES (the code's own
  #:tier vocabulary); headline = "zero new stratum/tier KINDS", a corollary of the
  exhibited 12-row table; (2) SINGLE normative source — stratification.md + D.1 §5.1;
  Master reduced to claim + pointer (three self-falsifications in five weeks from
  duplicated vocabulary); (3) e-class cells live on PRN (request-cell instances
  pre-allocation + two-context audit priced into Track 1).
- **Carried**: extraction = (i)-A S0-computed fixpoint + dual-trigger read protocol
  (§18.21.25 precedent; pure demand banned); promotion = (ii)-A between-round handler
  AFTER retraction settling, BLOCKED on the #:after ordering declaration + keep-pending
  idiom (verified: silent append-order + unconditional auto-reset + max-merge regime ⇒
  wrong-window promotion is PERMANENT); cost semantics for green slice = local
  DAG-relaxation, sharing-aware = Track 4 NP-boundary.
- **Corpus amendments in lock commit**: Master Layer-3 claim+pointer; Master:96 F4
  reword; Master:99 F7 opaque-row fix; stratification.md:46 F3a (legacy box RETIRED
  2026-04-16 — our own morning pass had preserved the stale claim) + :138 F3b
  (cost-bounded DISSOLVED) + tier-vocabulary normative note.
- **Autonomy data point #5**: mempalace prior-art probes (recency-adjudicated in main
  session) fed the panel pre-verified facts and visibly cheapened the round (5 agents,
  ~800k tokens vs ~1M); the panel still caught staleness OUR OWN same-day pass missed —
  duplication-driven drift is real and the single-source decision is the structural fix.
- **Landed in**: design doc §5 + Master + stratification.md amendments (commit `465fc16a`).

## 2026-06-10 — interactive (pre-loop) — [OWNER-DECIDED] SM5 + SM6 LOCKED — effect soundness + persistence product
- **Decision**: final two sub-models locked from the combined panel (`wf_bdd89ecd-516`):
  - **SM5**: posture A composite with owner-refined guard timing — Option 1 soundness
    floor in Track 1 (effectful? registry property, PESSIMISTIC default for
    capability-polymorphic heads + bite counter, deterministic (epoch × occurrence-path)
    identity keys, never-in-signature-index, positive :opaque facet); the effect-safety
    guard (no RHS delete/duplicate/reorder of captured effect-bearing subterms) =
    **BLOCKING Track 2 Phase 0** — the owner asked for the full design space in prose
    after finding the option labels too compressed, then chose the synthesis (guard
    structurally precedes the first generic rule, which IS β). Add-only re-entry
    (Master Q7 answered). Stratum-3 hand-off = named deferral (Architecture AD trigger).
  - **SM6**: Axis-2 re-specified as PRODUCT (3-chain × admission classes; opaque outside
    as facet; open → rule-id keyspace) + ground-admission rule (born-context-free only
    into the question-keyed store; promoted stay module-homed); pessimistic
    classification both instances; **regime = 5th component of the SM2 product (explicit
    owner sign-off to amend a locked sub-model)**; question-homed rewrites registry
    decoupled from mtime; ground-only cross-session day one; reserved schema slots;
    D3 key-fork + 0.3 encoding freeze as one cycle.
- **Round discoveries**: F-A (hashcons dedups effects at ingestion) + F-B (generic rules
  capture effects through pattern variables) — posture B returned UNSOUND-AS-STATED;
  classification needs NON-LOCAL evidence (capability-polymorphic heads / module-env
  dependence — one decision shape, two instances); "ground" was two proxies, neither
  semantic. T7 RESOLVED in-panel.
- **Autonomy data point #6**: compressed option labels failed the owner at the decision
  point — the co-design needs full prose design-space exposition BEFORE the question
  when the options carry novel soundness content; the owner's "uninformed intuition"
  (Option 2 / guard earlier) was directionally RIGHT and produced a better synthesis
  than either pre-packaged option.
- **Landed in**: design doc §6 + §7 + SM2 §2.1 product amendment + Master Axis-2
  re-specification (commit `d2036954`).

## 2026-06-10 — interactive (pre-loop) — [ROUTINE] TRACK 0.1 CLOSED — NTT exit gate PASSED
- **Decision**: the exit gate ran as main-session assembly (coarse NTT model §8.1 +
  unified 24-row correspondence table §8.2 + consistency checks §8.3) followed by ONE
  adversarial purity agent. Verdict: PASS-WITH-AMENDMENTS, all applied — (A) precise
  lattice definitions for write-once-flat and dedup-or-error (⊤contradiction as
  legitimate top; merge totality preserved; idempotent identical re-registration);
  (B) the idempotence seam added to carried seams; (C) two pre-deployment verification
  gates recorded (SP2: dedup-or-error ACI in code; SP3: broadcast write-shape composes
  with the product merge). Master Track 0.1 row → ✅ with D.1 linked.
- **Principle / precedent cited**: the NTT-model-required rule (workflow.md) — 3/3
  tracks using NTT modeling have now caught real defects (PPN Track 2: 3 gaps; SRE 2G:
  scatter impurity; PReduce 0.1: two under-specified merge error semantics).
- **Landed in**: commit `326f7e4e`. Track 0.1 closure = the experiment's Phase A
  substantially complete; six autonomy data points held for the retro.

## 2026-06-10 — interactive (pre-loop) — [OWNER-DECIDED] TRACK 0.2 CLOSED — taxonomy + partition + HVM2 deferral
- **Decision**: single-cluster panel (`wf_4d3d2df9-a4c`, 3 agents) + owner decisions:
  - **Partition = Option B + corrections + STRUCTURAL binding**: Track 2 = IN-ladder
    (guard Phase 0 → named arithmetic seed ~12-20 ops → δ → guarded β) with the
    owner-bound exit criterion (guard passes AND guarded β fires AND PRN §2 recorded);
    Track 3 = ι/DPO.
  - **HVM2 = DEFERRED WHOLE** (owner diverged from the reference-posture
    recommendation) — with the guard that Track 2's design doc opens with the
    benchmark-posture decision; interaction-count characterization recorded as the
    honest-middle material.
- **Panel findings of note**: "~50 whnf cases" stale by ~9× (461 arms/235 heads —
  Master amended); the effect-safety guard must cover ι instantiation (field-drop +
  natrec step-duplication), not only β; trait-narrowing multi-candidate fallback =
  the first genuine SATURATE/+alts producer (ledger-6 evidence); the implicit-NAC
  claim DOWNGRADED to conditional by the critique (blocking verification commissioned
  at Track 3 opening — do NOT fire the SM3 D1 revisit unverified); capability/session/
  NAF/FFI confirmed as dimensions/boundaries/existing-strata, not rule kinds.
- **Landed in**: D.2 (docs/tracking/2026-06-10_PREDUCE_TRACK0.2_RULE_TAXONOMY.md) +
  Master amendments (rows 0.2/2/3 + census) (commit `92c5339e`).

## 2026-06-10 — interactive (pre-loop) — [OWNER-DECIDED] TRACK 0.3 CLOSED — PHASE A COMPLETE
- **Decision**: 2-cluster panel (`wf_7250f731-04d`) + owner decisions:
  - **Identity sign-off package (the one §7.4 owner cycle; the track's only
    non-reversible rulings)**: PCE/1 canonical encoding + sha256-bytes (verified
    in-base) + the three D3 rulings + BOTH key-space closures (effectful digest
    structurally excluded from the persisted domain via admission-guard ERROR +
    kind-byte separation; question-store key gains the RULE-SET-DIGEST component).
  - **Container + payload**: .pnet/2 tagged sections (evolution as format property;
    question sidecar nothing-mtime-shaped; one-time cold rebuild accepted) + boundary
    tier 2′ (extraction sections + frozen CELL-record incl. per-cell enrichment
    annotation — the verified day-one obligation; propagator-record RESERVED,
    NTT/SH-Track-1 trigger). Single-hasher rule: pce.rkt owns encode+hash; golden
    vectors ARE the cross-language conformance artifact.
  - **Merge timing**: branch lands on main after 0.3 close (owner reviews + merges;
    Phase B branches fresh off main).
- **Grounding highlights**: no canonical encoder exists anywhere; equal-hash-code has
  no stability contract; gensym uids traversal-order-dependent (forbidden in hash
  domains); PNET_VERSION equality-gate; additive reads de facto; Zig PoC unpinned
  (owner-action tracker row). The critique's reflexive catch: the lock-set itself was
  main-invisible — LBD-1 provenance ratification = this merge decision.
- **PHASE A COMPLETE**: Tracks 0.1 + 0.2 + 0.3 closed; Track 0 (series founding) ✅.
  The charter's Phase B (autonomous loop, Track 1 entry) conditions are met once the
  branch merges. 8 autonomy data points held for the retro.
- **Landed in**: D.3 + Master amendments (rows 0/0.3/5) (this commit).

## 2026-06-10 — LOOP iteration 0 (Phase B shakeout) — [ROUTINE]
- **Decision**: iteration 0 executed per charter §7 kickoff: (a) cold-compile +
  full-suite BASELINE launched in the worktree (background; results ingested next
  firing — local green + timings entry are the gates' floor); (b) DEFERRED.md triage
  DONE (the A.0 leftover): "Reduction Cache Cells" marked ABSORBED into PReduce
  (belt-and-suspenders guard noted); Allocation-Efficiency audit + per-command
  transient-allocation finding cross-referenced as Track 1 cost-model inputs;
  bench-ab --refs confirmed valid for Track 4; (c) Phase B dailies created.
- **Flagged for iteration 1**: the §5.8 reduction-share measurement METHOD is a small
  design decision (existing time-phase! instrumentation vs profiler run on the
  comparative suite) — not improvised inside the shakeout.
- **Landed in**: (this commit)

## 2026-06-10 — LOOP iteration 0 CLOSED + iteration 1 — [SIGNIFICANT] reduction-share measurement method
- **Iteration 0 CLOSED**: suite baseline GREEN (8380/428/131.2s all pass, timings at
  41d222d7); bench-ab Phase B baseline saved
  (data/benchmarks/preduce-phaseb-baseline-41d222d7.json; A≈B sanity holds, cv≤1.1%).
- **Iteration 1 decision — the §5.8 reduction-share METHOD**: SAMPLING PROFILER over
  the comparative suite, in-process via driver main, one process per benchmark
  (bench-ab isolation parity), 5ms samples, ZERO production-code changes; share =
  SELF-time aggregated by source file (avoids recursive-total double-counting),
  reduction.rkt and substitution.rkt reported separately + combined; full render-text
  profile saved per benchmark for the record. Realized as the repeatable
  tools/profile-reduction-share.rkt (committed).
- **Options considered**: (a) time-phase! instrumentation — rejected: phase-level
  timers cannot isolate reduction nested inside type-check/eval; (b) timer wrapping
  of whnf/nf entries — rejected for v1: touches THE hot path (even a disabled-flag
  check per whnf call is a per-call cost; the SM1.1 blast-radius discipline says
  measure first, instrument only if profiler attribution proves too coarse — named
  upgrade); (c) sampling profiler — ADOPTED.
- **Caveats recorded** (from the smoke test): an <unknown> attribution bucket
  (runtime/JIT frames) and performance-counters.rkt overhead visible on tiny
  benchmarks — report shares of both total and attributed time on the big benchmarks;
  refine only if the bounds are too loose to serve as the denominator.
- **Landed in**: (this commit); measurement running in background across the full
  comparative set → results ingested next firing = the §5.8 DENOMINATOR.

## 2026-06-10 — LOOP iteration 1 — [SIGNIFICANT] §5.8 DENOMINATOR v1 recorded — owner figure NOT reproduced
- **Measured** (v2 protocol: sampling profiler, call-tree REDUCTION-TREE-BOUND =
  max node-total among reduction.rkt nodes, recursion-merged):
  ppn-track4c acceptance = **25.36%** tree-bound (1.79% self);
  type-adversarial = **36.89%** (3.00% self);
  constraints-adversarial = 2.32% (elaboration-stress by design);
  sub-second benchmarks unreliable at 5ms sampling (church-folds v1/v2 variance).
- **Finding**: the reduction call-tree share on reduction-heavy representative
  workloads is ~25-37% — the self-vs-tree gap (10-15×) confirms whnf's work lands in
  callees (match dispatch, champ, counters). The owner-reported ~50-60% is NOT
  reproduced on this corpus. Possible reconciliations: the figure describes other
  workloads (full suite? evaluation-heavy real programs?), or includes costs this
  protocol attributes elsewhere. OWNER NOTIFIED (charter doorbell) — async input
  wanted on the figure's provenance; the loop CONTINUES meanwhile (the queue's next
  units are correctness-gated, not denominator-gated).
- **Denominator v1 (standing until owner input or protocol v3)**: Track 4/8 perf
  claims measure against THIS protocol (tools/profile-reduction-share.rkt) on
  ppn-track4c + type-adversarial: baseline tree-bounds 25.36% / 36.89%.
- **Protocol backlog**: wfle + track4-acceptance runs failed silently (re-run with
  stderr); sub-second benchmarks excluded from the denominator corpus.
- **Landed in**: (this commit)

## 2026-06-10 — LOOP iteration 2 — [SIGNIFICANT] SM1.1 mini-design closed (grounding-audit `wf_33f45b2a-8fc` + R-lens)
- **Audit verdicts adopted** (all claims verified; ':term mystery resolved — that-write
  maps ':term→':type at :570-571, hardening breaks zero production callers):
  1. **Hardening scope = ALL THREE defaults** (facet-merge :412, facet-bot :421,
     facet-bot? :432 → error naming the facet). Rationale: the permissive defaults
     would silently give the four new facets WRONG semantics (last-write-wins;
     (not v) misclassifies set-valued bots). The only affected code is
     bench-attribute-record.rkt's J-A sections (simulated ':mult/':level/':session —
     a REJECTED architecture): those sections are EXCISED with an annotation, not
     preserved (measuring a counterfactual is not worth a permissive merge default).
  2. **Bot-filter motivation RESTATED** (capture-gap correction): production never
     writes bot deltas today (guards verified at :1617-1619/:1565-1567/:817); the
     two-site fix is prophylactic hygiene for the new facets, not a current-bug fix.
     Clause order: skip-bot-delta FIRST, then old-bot-store, then equal?, then merge.
  3. **Expose-or-filter = FILTER at arity-2** (the user-facing whole-record view —
     :eclass-link etc. are internal e-graph state; no LSP-hover leak), arity-3
     by-name reads stay raw. Both arms specified per the capture gap.
  4. **Shape-P = ENUM route, PLAIN-ONLY v1**: reuse specialized-cell-meta enum fields
     (no struct change — pipeline.md checklist does NOT trigger; verified the
     fast-path gate requires 'hot+'monotone-counter so a new combo falls through);
     dispatch at the SOLE pu-value-diff call site (propagator.rkt:2056-2058, delta
     in scope at :1984); tagged-promoted cells keep full diff (the masked
     (cons pos ':term) mismatch at :1191 is a PRE-EXISTING latent bug, ledgered as
     its own small item — NOT touched in SM1.1).
  5. **'5 facets' prose = FOUR sites** (typing-propagators :479/:523 + two test
     files) — same-commit updates; the :2844 comment rewords to CHAMP-sharing-
     within-run only.
- **[⚠ OWNER-PROVISIONAL] Acceptance-file ruling**: workflow.md's Phase-0 gate is
  unsatisfied (no PReduce acceptance file exists). PROVISIONAL: SM1.1 (additive
  facets + hygiene, no behavior change to existing paths) gates on the EXISTING
  ppn-track4c acceptance + probe + full suite; the PReduce Track 1 acceptance file
  is created as the NEXT unit (before any e-class code). Reversal path: if the owner
  wants the acceptance file strictly first, SM1.1's commit waits behind it (no code
  conflict either way).
- **Landed in**: (this commit); implementation begins this firing, ONE code commit
  when green.

## 2026-06-10 — LOOP iteration 2 — [SIGNIFICANT] §5.8 DENOMINATOR RECONCILED — phase accounting found
- **Discovery during the SM1.1a acceptance gate**: the driver emits PHASE-TIMINGS with
  a SEPARATE `reduce_ms` bucket. On ppn-track4c: reduce 1136ms of ~1523ms phase total
  = **~75% reduction share by PHASE accounting** — vs 25.4% by whole-process profiler
  tree-bound on the same file. Reconciliation: the denominators differ — phase
  accounting measures in-driver phase time (excludes startup/parse/module-load that
  the profiler's whole-process total includes). The owner-reported ~50-60% is
  CONSISTENT with phase accounting; iteration 1's "not reproduced" verdict was a
  denominator-definition artifact, not a contradiction. The iteration-1 doorbell
  stands CORRECTED (good news: the perf thesis's headroom is real under the
  phase-accounting lens).
- **§5.8 protocol v3**: BOTH numbers are now standing baselines — phase-accounting
  reduce-share (~75% ppn-track4c) for the user-experienced compile-time story;
  profiler tree-bound (25.4%) for whole-process honesty. Track 4/8 claims cite both.
- **Landed in**: (this commit)

## 2026-06-10 — LOOP iteration 3 — [ROUTINE] SM1.1a LANDED — facet substrate green
- **Shipped** (one code commit): four reduction facet cases across all three dispatches
  (lattice defs per D.1 §8.3 incl. ⊤ values); ALL THREE defaults hardened to error;
  bot-filter SCOPED to internal reduction facets; arity-2 FILTER
  (internal-reduction-facets hidden; arity-3 raw); bench J-A counterfactual excised
  (A5 memory sections retained — they never touch the dispatches); comment fixes
  (:type-shim, arity-2 doc, .pnet fiction); new tests/test-preduce-facets.rkt
  (lattice laws, hardening, both filter sites, pointwise spot-check, arity-2 filter).
- **Gate story (the process working)**: full suite caught ONE real consequence —
  test-sre-coverage: 4 generic-op checks → type-bot. Root cause: the UNSCOPED
  bot-filter suppressed legacy :type bot-seed writes whose changed-paths do
  WAKE-SIGNAL duty for numeric-join propagators (the audit's one untraced R-lens item
  — "origin of stored bots" — was exactly this; flagged-not-traced, the gate traced
  it). Fix: scope the filter. AUTONOMY DATA POINT #9: a static audit's flagged-unknown
  became a gate-caught regression — the flag discipline + the gate together did the
  job co-design would have.
- **Pre-existing flake documented (NOT ours)**: test-module-network-01 4B.3-b failed
  in ONE full-suite batch run ("No exception raised" from enforce-component-paths!),
  passes 59/59 individually; mechanism = registry-classification state under
  batch-worker save/restore; exposure trigger = file count 428→429 reshuffling
  partitions. Latent ordering sensitivity in REGISTRY state, not touched by SM1.1a.
  Watching-listed; candidate for the batch-worker parameter audit.
- **Suite**: 8417/429 green except the documented flake (passes individually);
  targeted sets green; acceptance (ppn-track4c) Level-3 clean (and yielded the
  PHASE-TIMINGS denominator reconciliation, ledgered above).
- **Landed in**: (this commit)

## 2026-06-10 — LOOP iteration 4 — [SIGNIFICANT] SM1.1b LANDED — shape-P precise; over-fire×fire-once lesson
- **Shipped**: `pointwise-delta-paths` (propagator.rkt, sole-diff-site dispatch;
  PLAIN-only; tagged falls back) + `#:storage 'pointwise-compound` on BOTH attr-map
  creation sites (factory route, 'warm tier — fast-path gate not satisfied) +
  benchmarks/micro/bench-shape-p.rkt + shape-P behavioral tests (watched/unwatched/
  no-change/absorbed — worklist-membership assertions).
- **Microbench claim VERIFIED (§5.8, before+after, same harness)**: plain
  pu-value-diff 10.6µs/128µs/811µs per 1-pos write at N=100/1000/5000 → shape-P
  ~1.9-2.0µs FLAT (~420× at N=5000). Precision cost: statistically invisible.
- **AUTONOMY DATA POINT #10 — the gate refuted MY OWN design reasoning**: v1 derived
  paths from delta keys alone ("sound SUPERSET — over-fire only, CALM-safe") and broke
  trait resolution: over-fire is sound for monotone REFIREABLE propagators but
  CONSUMES FIRE-ONCE dependents' single shot (no-change wakes ate the constraint/
  trait propagators' one firing). Fix: exact comparison restricted to delta keys —
  equal to pu-value-diff's result under the pointwise law, still O(|delta|).
  CODIFICATION CANDIDATE (Watching, needs 1 more data point): "changed-path
  precision is a SOUNDNESS contract wherever fire-once dependents exist; over-fire
  is not free."
- **Batch-flake adjudication (controlled A/B, this iteration)**: the final gate
  showed test-sre-coverage failing IN BATCH ONLY (passes individually); stash +
  control suite at the SM1.1a state reproduced the SAME failure (plus the documented
  test-module-network-01) WITHOUT shape-P ⇒ NOT an SM1.1b regression. Residual
  honesty: the control includes SM1.1a — whether SM1.1a made sre-coverage
  batch-MARGINAL is the next unit's question (pre-SM1.1a control = step 1 of the
  flake-diagnosis audit). Both flakes now tracked together.
- **Landed in**: (this commit). SM1.1 (a+b) COMPLETE.

## 2026-06-10 — LOOP iteration 5 — [SIGNIFICANT] flake audit: mechanism found, fix hypothesis REFUTED, classified+tracked
- **Audit results**: (a) pre-SM1.1a control GREEN — but CONFOUNDED (428-vs-429 file
  partition change rides with the code change; cannot separate by this design);
  (b) MECHANISM: install-default-typing-domain! is a MODULE-LOAD-TIME parameter
  mutation (typing-propagators.rkt:2331) and current-typing-domain was missing from
  batch-worker's restore list — the pipeline.md New-Parameter checklist violation,
  pre-existing; (c) conformance patch landed (capture at worker init + per-file
  restore + provide) — checklist-correct hygiene; (d) **the patch did NOT eliminate
  the flake** (same 4-check signature next gate) — hypothesis REFUTED by experiment;
  likely the worker-init capture itself reads an empty parameterization. STOPPED
  GUESSING per the diagnostic protocol: classified as a TRACKED KNOWN FLAKE
  (DEFERRED.md entry with the full evidence trail + the queued instrumented probe);
  gate policy = non-blocking iff passes individually, verified per occurrence.
- **The structural fix is PReduce's own roadmap**: SM3's rule-registry absorption
  moves rule visibility from thread parameterization to CELL state — this flake is
  added motivation.
- **AUTONOMY DATA POINT #11**: the loop correctly executed
  hypothesis→fix→experiment→REFUTATION→classify-and-track without sunk-cost
  spiraling; the refuted fix was KEPT (independently checklist-correct), the
  refutation recorded, the deep diagnosis queued rather than improvised.
- **Landed in**: (this commit)

## 2026-06-10 — LOOP iteration 6 — [ROUTINE] Track 1 acceptance file landed (Phase 0 gate discharged)
- **Shipped**: examples/2026-06-10-preduce-track1.prologos — reduction-heavy broad
  exerciser organized BY REDUCTION KIND per the D.2 taxonomy (β closures/higher-order,
  δ unfolding chains, ι built-in + user multi-arity, arithmetic literal/generic/Nat,
  trait residue, collections/pipelines, mixed-depth whnf parity targets for the green
  slice's CONSUMING READ). Level-3 clean first run: 0 errors, 275 reduce steps,
  baseline-only match-fail hole noise (parity with track4c). The OWNER-PROVISIONAL
  acceptance ruling (iter 2) is DISCHARGED — the Phase-0 gate now exists for all
  Track 1+ phases; run before/after each phase per workflow.md.
- **Landed in**: (this commit)

## 2026-06-10 — LOOP iteration 7 — [ROUTINE] pce.rkt landed — the PCE/1 identity cornerstone
- **Shipped**: pce.rkt (the SINGLE-HASHER module per D.3 §2: canonical encoder over
  the closed v1 domain — exact ints sign+magnitude bignum-safe, exact rationals,
  interned symbols, strings/bytes/booleans/null/pairs/vectors, sorted immutable
  hashes, transparent structs by stable name+arity+fields; little-endian length
  prefixes; floats + uninterned symbols = admission ERRORS) + sha256 digests with
  VERSION+KIND prefix + the persisted-domain guard (kind-2 effectful-session digests
  structurally excluded — D.3 closure iv) + the golden-vector GENERATOR in-module
  (the artifact: data/pce-golden-vectors-v1.txt, 13 vectors) + tests/test-pce.rkt
  (23 checks: determinism, distinctness, kind separation, guards, hash-order
  independence, bignums, live golden-vector conformance).
- **Verified**: digests DETERMINISTIC across separate OS processes (regenerate+diff
  clean) — the property equal-hash-code never had; mini-audit confirmed the encoding
  preconditions (expr structs loc-free, de Bruijn, 313 transparent, struct->vector
  stable names).
- **Landed in**: (this commit)

## 2026-06-10 — LOOP iteration 8 — [ROUTINE] eclass-cell.rkt + 'eclass-refine relation landed (SM2 lock realized)
- **Shipped**: eclass-cell.rkt — the locked componentwise-ACI product
  {best argmin-with-PCE-tie-break | alts set-union | canonical min-join |
  provenance set-union | regime max-toward-ground}, eclass-bot/bot?/merge,
  Q-shape-agnostic (cost . form) best carrier (owner D7 honored), the 'term
  carrier domain hosting BOTH 'equality (flat→'term-top) and 'eclass-refine
  (coarsening join) via merge-registry (SM2 D2: shared carrier, relations as
  propagator kinds) + register-domain! + register-merge-fn!/lattice. sre-core.rkt
  4-edit surface per the §2.10 census: sre-eclass-refine relation constant
  (order-preserving+idempotent), variance-maps entry (components → equality at v1;
  congruence is the signature-watcher layer's job), sre-make-eclass-refine-
  propagator (symmetric coarsening via the domain registry), propagator-ctor-table
  entry. Tests (22): ACI laws, per-component semantics, PCE tie-break symmetry +
  determinism, closed regime chain, registry dispatch, live-network coarsening
  through the PUBLIC dispatcher (sre-make-structural-relate-propagator), idempotent
  re-fire.
- **Landed in**: (this commit)

## 2026-06-10 — LOOP iteration 9 — [SIGNIFICANT] THE GREEN SLICE IS ALIVE (D.1 §2.4 trace executing)
- **Shipped**: eclass-graph.rkt — the hashcons registry (on-network cell; PCE-digest →
  (alloc . cell-id), equal?-keyed; per-key MIN-BY-ALLOC hash-union so racing interns
  resolve deterministically), eclass-intern (content-address via the single hasher;
  hashcons hit = same cell + ZERO allocation; ':canonical = the cell-id's allocation
  number — network ids are monotone, min-join IS first-allocation order, NO separate
  counter, no off-network state), eclass-union (e-graph union = an 'eclass-refine
  relate INSTALL; the join lands at BSP quiescence), lookup/read.
- **Design fix mid-unit**: ':alts switched to equal?-based sets (members are PCE
  digests = bytes; seteq would silently fail to dedup equal digests computed
  separately — caught at design time, before any test could mask it).
- **The three trace tests (41 checks, first-run green)**: (1) the LITERAL TRACE —
  create → intern → union install → quiescence → both cells hold the join, argmin
  best, min-alloc canonical, digest-dedup alts; (2) RACING UNIONS — a~b + b~c
  installed before quiescence, permuted orders → ONE fixpoint (CALM
  order-independence, transitive convergence through the shared cell, global argmin
  preserved); (3) the CONSUMING READ — :eclass-link facet (arity-3 raw) → registry
  → class best, with the link FILTERED from the user-facing arity-2 view.
- **Three-key separation live**: canonical NAME (min alloc) ≠ cost-best FORM
  (argmin) ≠ content-address KEY (PCE digest) — each asserted by a distinct check.
- **Landed in**: (this commit). Track 1's substrate stack is now: facets ✅ shape-P ✅
  PCE ✅ product cell + relation ✅ hashcons + union ✅.

## 2026-06-10 — LOOP iteration 10 — [ROUTINE] #:after + keep-pending stratum substrate landed (BLOCKING dependency discharged)
- **Re-sequencing note**: D5 probe deferred — a faithful singleton-fraction capture
  needs a whnf-cache observer hook (production touch, own mini-design; the
  per-command cache parameter is discarded after each command, so post-run
  inspection can't see it). Queued with the hook design note; the #:after substrate
  (BLOCKING for rule promotion) taken instead.
- **Shipped**: register-stratum-handler! gains #:after (per-tier STABLE topological
  order via the pure+provided order-stratum-entries; cycles error at module-load;
  unknown/cross-tier targets inert — re-sort on every registration picks up
  late-registering targets) + #:keep-pending? (reset-BEFORE-handler so deliberate
  request re-writes survive; legacy order preserved exactly for all 8 production
  sites — entries are plain lists, no struct checklist). stratification.md CAUTION
  amended to DISCHARGED.
- **Coverage note (honest)**: the pure sort is exhaustively tested (chain/stability/
  diamond/cycle/inert/cross-tier, 10 checks); the keep-pending PROCESS-TIER branch is
  shape-landed and will get its behavioral test at the FIRST consumer (the rule-
  dispatch handler) — global stratum-handlers box pollution makes a safe isolated
  integration test impossible today (the same registry-globalness the tracked flake
  lives in; noted, not fought here).
- **Landed in**: (this commit)

## 2026-06-10 — LOOP iteration 11 — [SIGNIFICANT] congruence ENGINE landed (11a; the cascade executes)
- **Mini-design decisions (solo, in-context grounding — every consumed module was
  authored this session)**: (1) e-node SIGNATURE = PCE digest of
  (vector 'enode op canonical(child)...) — canonicals are PCE-encodable min-alloc
  integers; (2) **SOUND-IF-STALE** is the load-bearing argument: classes only
  coarsen, so signature equality at ANY time is congruence FOREVER — stale index
  entries can never cause a wrong union; a stale-keyed intern allocates a duplicate
  that the scan heals (wasteful-but-sound = the CALM-compatible failure mode);
  (3) phasing: 11a = the ENGINE (decomposed intern + collision scan + batch union —
  pure/cell-level, fully testable NOW), 11b = the reactive wiring (parent watchers +
  topology-tier collision handler on a PREALLOCATED request cell — needs the
  make-prop-network preallocation touch, own mini-audit).
- **Shipped**: eclass-canonical, eclass-node-signature, eclass-intern-node
  (signature-keyed; returns node DESCRIPTORS for 11b's watchers),
  eclass-congruence-collisions (group-by-current-signature scan),
  eclass-union-all (chained relates per group). Tests: the textbook cascade
  (f(a),f(b) distinct → a∪b → collision detected → cascade converges, cheaper
  parent form wins, idempotent re-scan) + the sound-if-stale duplicate-heal path.
- **Property learned at the gate (test failed in the GOOD direction, then fixed)**:
  staleness is ASYMMETRIC under min-join — the FIRST-allocated class's canonical
  never changes (its signature-keyed nodes stay fresh forever); only LATER-allocated
  classes' parents go stale. 11b's watchers therefore only react to canonicals the
  union actually CHANGED — the join computation already knows which side that is.
  (Also: my test initially constructed the stale scenario on the wrong side and the
  suite caught the misconstruction — data point #12, gates catching test-author
  error, not just code error.)
- **Landed in**: (this commit)

## 2026-06-10 — LOOP iteration 12 — [SIGNIFICANT] congruence WIRING landed (11b) — the cascade is REACTIVE
- **Shipped**: cells 20 (congruence sig-index — monotone {sig → (set class-cid)},
  equal?-keyed, sound-if-stale) + 21 (congruence request — per-round changed-sig
  delta) PREALLOCATED in make-prop-network with drift guards (zero behavior change
  for non-e-class networks; zero-NET-2 preserved). eclass-intern-node now seeds the
  index AND installs the PARENT WATCHER: a plain REFIREABLE propagator (the iter-4
  over-fire×fire-once lesson applied at design time) watching ONLY the children's
  ':canonical component-paths (the asymmetric-staleness property applied — only
  union-changed canonicals wake it). process-congruence-requests: STATELESS
  topology-tier handler (collided group → 'eclass-refine relate installs;
  re-installs idempotent at quiescence; registered at module load on the
  preallocated cell per the request-accumulator pattern).
- **Proof**: ONE union + ONE run-to-quiescence auto-unions congruent parents with
  NO manual scan — including the TWO-LEVEL cascade (the f-union itself wakes g's
  watchers). BSP is the scheduler default so the production path is exercised.
- **Design notes**: keep-pending NOT consumed here after all — the monotone-index +
  delta-request split is CALM-cleaner than a keep-pending accumulator (the index is
  state = a cell; requests are deltas). The keep-pending behavioral test remains
  owed at its true first consumer (rule dispatch).
- **D.1 §2.1's congruence design is now fully realized** (engine 11a + wiring 11b).
- **Gate follow-up (same iteration)**: test-trace-serialize's preallocated-cell
  CENSUS assertions (20→22, 22→24) updated for cells 20/21 — the pipeline.md
  "reflection-based consumers" checklist item, caught by the gate exactly where
  the checklist says to look; sre-coverage = the tracked flake, 9/9 individually.
- **Landed in**: (this commit + the census fast-follow)

## 2026-06-10 — LOOP iteration 12 follow-up — [ROUTINE] cell-census class swept (3 files, 8 sites) + a process lesson
- The 11b preallocation (cells 20/21) shifted the well-known census 20→22; the
  reflection/census consumers asserting it: test-trace-serialize (2 sites, fixed
  in the fast-follow), test-propagator (5 sites), test-observatory-01 (1 site).
  ALL now updated.
- **Process lesson (data point #13)**: I fixed the FIRST gate-reported file instead
  of auditing the census CLASS — two more gate rounds found the rest one file at a
  time (the diagnostic-protocol "audit the domain" rule applied late). ALSO: two
  silent no-op python replaces (pattern mismatch) slipped through before an
  asserted-match fix — assert-pattern-found is now the standing discipline for
  scripted edits (the Edit tool's uniqueness check does this natively; scripted
  multi-edits must replicate it).
- **Checklist amendment candidate (Watching)**: pipeline.md "New Struct Field" has
  the reflection-consumer item; a "New PREALLOCATED CELL" checklist entry should
  name the census consumers explicitly (trace-serialize, test-propagator,
  observatory) — 1 data point, codify on the next preallocation.
- **Landed in**: (this commit)

## 2026-06-10 — LOOP iteration 13 — [SIGNIFICANT] effect-safety FLOOR landed (D.1 §6.2 F-A, Track 1 Option 1)
- **Shipped**: the :opaque facet (the MISSED 5th SM1.1 facet — D.1 §4.1 listed it via
  the §6 lock, my SM1.1a shipped 4; landed here where it is load-bearing; monotone-or,
  internal/filtered); head classification v1 (explicit effectful-head registry seeded
  read/write/print/send/recv/perform + capability-polymorphic registry with
  PESSIMISTIC default + the bite counter the lock requires; unregistered = pure;
  authoritative α = SM3 registry / Track 7 named upgrade); ground-path ADMISSION
  GUARDS in eclass-intern + eclass-intern-node (effectful heads ERROR — "use
  eclass-intern-effectful"); eclass-intern-effectful: deterministic
  (epoch × occurrence-path) kind-2 keys (persistence-excluded BY pce-persistable-
  digest — the iter-7 guard doing its job), cell-only allocation (NO hashcons
  registry entry, NO signature-index entry, NO parent watcher — congruence never
  sees effect occurrences as dedup sources), idempotent re-fire (same key → same
  class, zero allocation).
- **Tests (117 targeted green)**: guards fire / pure unaffected; two [read ch]
  occurrences NEVER dedup; idempotent re-fire; kind-2 persistence exclusion
  verified live; registry + sig-index exclusion asserted; bite counter counts;
  :opaque facet laws + user-view filtering.
- **Track 2's blocking entry guard (the RHS delete/dup/reorder check) remains
  exactly where the owner put it**: at Track 2 Phase 0, before β ever fires — this
  unit is the Track 1 FLOOR only.
- **Landed in**: (this commit)

## 2026-06-10 — LOOP iteration 14 — [SIGNIFICANT] Track 1 CLOSE-OUT AUDIT (D.1 §9; Master row ✅)
- Substrate inventory + design deviations + named remainders written into D.1 §9 and
  the Master Track 1 row (✅ SUBSTRATE COMPLETE with commit trail). The four
  deviations are all gate-caught-and-ledgered items, none silent. SM3's rule-registry
  universe cell is named as the bridge unit before Track 2 (rules need a home before
  the arithmetic seed; doubles as the typing-domain flake's structural fix).
- bench-ab A/B vs the iteration-0 baseline running at close (results appended on
  ingest). PIR next unit (16-question live checklist + longitudinal survey) + the
  Track 1 close DOORBELL per charter §8.
- **Landed in**: (this commit)

## 2026-06-10 — LOOP iteration 14 close — [SIGNIFICANT] TRACK 1 CLOSED — PIR written; doorbell rung
- **bench-ab at close (§5.8 curve honesty)**: large benchmarks ±2.5% vs the
  iteration-0 baseline (type-adversarial +0.8%) — NEUTRAL as designed (nothing in
  the production path consumes the substrate yet); sub-second deltas
  noise-dominated; pattern-matching +9.6% WATCH-LISTED for next-phase re-check.
  Saved: data/benchmarks/preduce-track1-close-e350a8c0.json.
- **PIR**: 2026-06-10_PREDUCE_TRACK1_PIR.md — all 16 questions answered against the
  methodology checklist; §15 carries one OWNER-PROVISIONAL (fine NTT model as
  Track 2's design opener rather than a Track 1 retrofit); §16 names the
  codify-NOW item (changed-path precision contract → propagator-design.md, 2 data
  points) + 2 watching items. Master row: Track 1 CLOSED with PIR link.
- **[⚠ OWNER] doorbell**: Track 1 closed per charter §8 — the owner notification
  carries: substrate complete + neutral perf + the §15 NTT ruling request + the
  SM3-registry-as-bridge-unit plan for Track 2's opening.
- **Landed in**: (this commit)

## 2026-06-10 — LOOP iteration 15 — [SIGNIFICANT] SM3 rule-registry universe cell landed (15a — the Track 2 bridge)
- **Shipped**: rule-registry.rkt — the SP1 schema struct (sre-rewrite spine + the
  six locked extensions incl. the RESERVED worldview-bitmask slot + stratum kept
  separate); the universe cell (module-keyed components; per-namespace
  DEDUP-OR-ERROR merge — the not-ACI list-append fixed by construction); the
  PROPAGATOR-MAINTAINED ':tag-index (self-watching monotone derivation —
  information flow, not registrar dual-write); 'rule-registry SRE domain;
  register/lookup/rules-for-tag reads. 68 targeted checks: isolation, idempotent
  re-register, conflict ERROR, index derivation at quiescence, late-registration
  monotone catch-up, schema round-trips.
- **CODIFIED (the PIR §16 codify-NOW item, riding this rules commit)**:
  propagator-design.md § "Changed-Path Precision Is a Soundness Contract" — the
  over-fire×fire-once lesson, 2 data points.
- **NOT in 15a (named)**: prn-init seed pour + driver wiring (15b); the
  typing-domain consumer-read migration (its own named track); broadcast dispatch
  (Track 2 where rules first fire).
- **Landed in**: (this commit)

## 2026-06-10 — LOOP iteration 16 — [ROUTINE] SM3 15b landed — seed pour + driver wiring; SM3 COMPLETE
- **Shipped**: current-rule-registry-cell-id (cell-ID plumbing only — the value-
  mirror shape stays off the table per D4) + init-rule-registry-cell! +
  pour-kernel-rule-seed! (sre-rewrite rules tier-split by rhs-template presence,
  stratum-qualified ids; ctor-descs as tier-2 ROUTING METADATA only — arity + the
  4 closure fields stay legacy-homed until the named consumer-read migration);
  wired into driver's per-file prn init (after init-attribute-map-cell!);
  batch-worker New-Parameter conformance (#f per file). Re-pour idempotent under
  dedup-or-error. Acceptance clean WITH the pour live in the init path.
- **The kernel pseudo-module now holds the projected rule corpus on-network**;
  Track 2's arithmetic seed registers into the same cell.
- **Landed in**: (this commit)

## 2026-06-10 — LOOP iteration 17 — [SIGNIFICANT] Track 2 design OPENED — the HVM2 owner package + the locked-derived skeleton
- **The D.2 guard discharged**: the design doc opens with the HVM2 posture decision
  as a full-prose OWNER PACKAGE (three postures with honest costs; loop
  recommendation = B+C: reference-architecture correspondences for the design +
  benchmarking bound to the Track 8 trigger where §5.8 instruments make comparison
  meaningful). Proceeding OWNER-PROVISIONAL on B+C; reversal = additive-prose
  deletion; A adoptable later without rework. DOORBELL rung.
- **§2-§4 derive from owner-signed locks** (no new decisions): Phase 0 RHS guard
  realization sketch (capture-profile derived at REGISTRATION; effect-bearing
  consult at APPLY; structural skip + counter, not error; tier-2 pessimism);
  the ~20-op arithmetic seed enumeration; broadcast-over-tag dispatch.
- **§5 fine NTT owed before Phase 1** (PIR §15 default in effect). §6 names the
  three open questions for the critique rounds (ingestion timing wants D5 data;
  nat-literal representation; guard observability home).
- **Landed in**: (this commit)

## 2026-06-10 — LOOP iteration 18 — [SIGNIFICANT] Track 2 DESIGN COMPLETE
- **§5 fine NTT model written** (PIR §15 default discharged): cells with the six
  locked merges, the rule-dispatch propagator skeleton (broadcast-over-tag), the
  apply-rule choke point with the guard inline, strata placement (S0 dispatch —
  monotone; topology congruence unchanged), correspondence rows for the two NEW
  surfaces (rule-dispatch.rkt + the ingestion call-site), and the posture-B
  IN-correspondence subsection WITH named divergences (merge-as-order and
  worldview tagging have no IN analog).
- **§6 resolved 3-column**: lazy ingestion (D5-data reversal path recorded);
  nat suc-chains fold to numeric form at the rule boundary (nat-value precedent;
  lazy makes sub-position non-interning free); guard observability =
  PERF-COUNTERS guard_skips (user-facing :warnings deferred to Track 9 user
  rules, named). PANEL-SKIP rationale recorded in-doc (all three questions sit on
  surfaces authored this session with locked semantics; the panel-shaped round
  was Phase A's SM design).
- **§7 adversarial VAG**: four decisions challenged (lazy-vs-mantra; broadcast
  shape-without-benefit avoided — no perf claim; skip-vs-contradiction; derived
  capture-profile staleness structurally impossible). DESIGN COMPLETE pending
  only the §1 HVM2 ruling (B+C provisional; Phase 0 unaffected by any outcome).
- **Landed in**: `1736f804`

## 2026-06-10 — LOOP iteration 19 — [SIGNIFICANT] Track 2 Phase 0 LANDED — the BLOCKING guard exists and passes
- **Shipped**: rule-dispatch.rkt — derive-capture-profile (registration-time;
  per-var LHS/RHS occurrence counts + ordered sequences; 'underivable for tier-2;
  staleness structurally impossible per the VAG), effect-bearing-class? (reads the
  iteration-13 floor's provenance marker), guard-allows? (DELETE = captured-unused;
  DUPLICATE = used-more-than-captured; REORDER = effectful relative order changed;
  violating match = STRUCTURAL SKIP + counter, never an error; tier-2 = pessimistic
  skip on any effectful capture + counter), apply-rule (THE single RHS choke point:
  match → bind → GUARD → instantiate → intern → union; lazy class-of contract —
  uninterned subforms are effect-free BY CONSTRUCTION since the floor interns every
  effectful occurrence). PERF-COUNTERS struct-field integration NAMED to Phase 1's
  wiring commit (fixed-field struct → checklist; module counter until then).
- **Tests preceded the seed (the lock's ordering)**: 30+ checks incl. all three
  violation kinds skipping on effect-bearing captures, the order-PRESERVING
  effectful match firing (not a violation), pure matches firing freely, tier-2
  pessimism counted, the end-to-end literal fold landing (folded form wins argmin;
  original alt retained), and the guard blocking a deleting fire AT the choke
  point with the class verifiably untouched.
- **β may now be designed against a guard that already exists** — the owner's
  structural-not-calendar timing honored.
- **Landed in**: (this commit)

## 2026-06-10 — LOOP iteration 20 — [SIGNIFICANT] THE SEED FIRES — the first reduction rules run on the e-graph
- **Shipped**: the (compute OP ...) template node (declarative-serializable per the
  D.2 tier-1 requirement — rules stay DATA; the whitelisted pure-op table is the
  INTERPRETER's) + dispatch-rules (rules-for-tag → registry-rule-by-id →
  apply-rule per match; direct invocation per lazy ingestion) +
  kernel-rules-seed.rkt (15 declarative folds: int arith ×5 incl. div/mod with
  abort-on-zero, comparisons ×5, booleans ×3, nat suc/pred on numeric form ×2 per
  the §6 Q2 resolution).
- **Gate-caught at first seed run (data point #14)**: #f was BOTH a legitimate
  computed value (boolean folds) AND the abort sentinel — correct false-valued
  folds aborted. Fix: a distinct gensym sentinel; domain failures return IT,
  #f flows as a value. The unused sentinel binding was already in the draft —
  the design knew, the implementation shortcut; the test corpus's comparison
  coverage caught it immediately.
- **The series thesis is now literally running**: intern → tag-lookup → GUARD →
  declarative fold → union → argmin extraction, at quiescence, on cells. 65
  checks: all 15 folds, div/0 non-firing with class untouched, non-literal
  no-match, alts retained (best+alts), re-dispatch fixpoint.
- **Phase 1 REMAINING (named)**: PERF-COUNTERS guard_skips field (struct
  checklist), the elaboration ingestion call-site, acceptance §4 Level-3 probe,
  §5.8 A/B bench.
- **Landed in**: (this commit)

## 2026-06-10 — LOOP iteration 21 — [ROUTINE] Phase 1 close-out: counters field + driver seed pour
- **Shipped**: perf-counters gains guard-skips (18th field; struct checklist swept:
  all 5 direct ctor sites updated — incl. tools/profile-unify.rkt found STALE at 16
  fields pre-existing, fixed in passing; ->hasheq + provide + the increment macro;
  reset! ALSO gained the missing inert-dependent-skips reset — same oversight class,
  fixed in passing); the dispatch guard's skip! now increments BOTH the test box
  (unit instrumentation) and the pc (production PERF-COUNTERS reporting — different
  consumers, no fallback logic); pour-arithmetic-seed! rides the driver's prn init
  after the kernel pour. test-perf-counters' key census 16→17.
- **Gates**: 73 targeted green; acceptance 0 errors with the seed pouring at every
  file init.
- **Landed in**: (this commit). A/B bench at the gate's tail.

## 2026-06-10 — LOOP iteration 22 — [SIGNIFICANT] THE INGESTION HOOK — whnf meets the e-graph (gated, default OFF)
- **Shipped**: current-preduce-ingest? (default #f) + preduce-ingest-int (TOTAL —
  e-graph round-trip when plumbed, native fold otherwise; match clauses don't fall
  through) + three gated clauses ahead of whnf's int-add/sub/mul literal arms +
  the per-file hashcons cell (init-eclass-hashcons-cell! at driver prn init;
  batch-worker conformant) + the PREDUCE_INGEST=1 subprocess A/B switch (the
  experiment toggle, NOT a deployment path — the flip criterion is NAMED at the
  hook: δ + guarded β landed AND §5.8 A/B positive, then flip or revert per
  validated≠deployed).
- **Honest framing (charter honesty-about-the-curve)**: the seed ops are exactly
  what whnf folds natively at ns speed — this unit's deliverable is the OVERHEAD
  FLOOR instrument (per-position intern+dispatch cost bounds what δ/β must save),
  not a win. Speculative-context note ledgered: e-graph writes during speculative
  whnf persist as monotone garbage (sound-but-wasteful, the documented class).
- **Proof**: 55 targeted checks (OFF default untouched; ON-unplumbed total;
  ON-plumbed lands identical folds with classes persisting as MEMOS — re-ingestion
  is a hashcons hit, zero growth); acceptance Level-3 clean with ingest ON
  (reduction-on-network processing real program arithmetic in a full driver run).
- **NEXT**: the per-fold ns microbench (ON vs OFF — the floor number; the
  comparative suite barely hits literal int folds, so per-fold ns is the honest
  §5.8 instrument), then δ (Phase 2).
- **Landed in**: (this commit)

## 2026-06-10 — LOOP iteration 23 — [SIGNIFICANT] the OVERHEAD FLOOR measured (§5.8)
- **bench-preduce-ingest.rkt** (committed; repeatable): native whnf int-fold
  ~119.1µs/op fresh, ~117.3µs same-expr (no whnf cache in the bare process — the
  absolute includes invariant per-call whnf overhead; the DELTAS are the
  instrument). E-graph gate ON: FRESH positions ~170.7µs (+51.6µs = the
  intern+dispatch+union round-trip — THE FLOOR), MEMO HITS ~123.8µs (+6.5µs =
  digest+hashcons lookup).
- **The bar this sets (recorded as the §5.8 design input for δ/β)**: a memoized
  position pays ~52µs once + ~6.5µs per reuse; it WINS when the recomputation it
  avoids exceeds that amortized cost. δ-unfolding + β on non-trivial bodies cost
  orders more than 52µs (phase-accounting: 1136ms reduce on ppn-track4c) —
  plausible headroom, to be PROVEN at the Phase 2/3 A/B, not assumed.
- **Curve honesty**: with seed-only rules the hook is a pure cost (+43% per fresh
  fold) — exactly the bounded early regression the charter §5.8 anticipates;
  default stays OFF; the flip criterion stands as named at the hook.
- **Landed in**: (this commit)

## 2026-06-10 — LOOP iteration 24 — [SIGNIFICANT] δ (Phase 2) landed — the memo that can beat the floor
- **The design insight (3-columned in-flight)**: the e-graph form for δ is THE EXPR
  STRUCT ITSELF (loc-free + PCE-encodable, iter-7 verification ⇒ projection is
  identity both ways), and the memo class is {body, whnf(body)} — literally an
  e-class of two equal terms, body at cost 10, result at cost 0 (argmin serves the
  result). KEYED BY THE BODY'S DIGEST: redefinition ⇒ new digest ⇒ fresh memo —
  SOUND BY CONSTRUCTION (orphans = the documented monotone-garbage class). The win
  vs current-whnf-cache is CROSS-COMMAND persistence on the prn (the per-command
  cache resets; the e-graph doesn't) — and eventually cross-file via Track 5.
- **Shipped**: preduce-ingest-delta (TOTAL; gated by the same default-OFF flag) +
  the gated fvar clause ahead of the native δ arm (ctor/type names still never
  unfold) + kernel::delta as a tier-2 METADATA registry entry (the ctor-desc
  absorbed-in-metadata-only pattern; the hook is the realization).
- **Coverage honesty**: unit tests pin the memo MECHANICS; the fvar-arm path needs
  a global env and is exercised at LEVEL 3 (acceptance with PREDUCE_INGEST=1 —
  clean; every def reference routes through the hook). A dedicated
  process-string-level δ test is owed with the Phase 2/3 A/B unit.
- **Landed in**: (this commit). Next: guarded β (Phase 3 — the guard's first real
  exercise) + the δ/β A/B against the iter-23 floor.

## 2026-06-10 — LOOP iteration 25 — [SIGNIFICANT] GUARDED β FIRES — the Track 2 exit criterion holds
- **Shipped**: expr-head-effectful? (app-spine walk to the iteration-13 head
  classification) + the gated β clause (pure-arg redexes memoize as
  {redex, contractum} e-classes via the SAME mechanics as δ — preduce-ingest-delta
  gained #:compute, the de-gated native step, after the memo-miss recursion was
  caught AT DESIGN REVIEW pre-test; effect-headed args = PESSIMISTIC skip + counter,
  native β stays legacy-sound since effects are deferred descriptors — the guard
  protects the E-GRAPH's identity semantics, F-A/F-B). guard-skip-note! unifies the
  test-box and pc counter paths (the two diverged — gate-caught, data point #15:
  dual counters need ONE increment fn by construction).
- **The owner-bound exit criterion**: (1) the guard passes ✓ (Phase 0, 30+ checks +
  the β skip test); (2) guarded β FIRES ✓ (the contractum joins the redex's class at
  cost 0; memo hits on re-reduction; acceptance Level-3 clean with β live —
  twice/make-adder/fib all route through it); (3) the PRN §2 confirmation RECORDED ✓
  (PRN master Confirmed Findings row: β/δ as DPO-style e-graph rewrites with the
  guard as application condition).
- **Track 2's ladder is COMPLETE**: Phase 0 guard → arithmetic seed → δ → guarded β.
  Remaining before track close: the δ/β A/B vs the iter-23 floor + the owed
  process-string δ test + Track 2 PIR + doorbell.
- **Landed in**: (this commit)

## 2026-06-10 — LOOP iteration 26 — [SIGNIFICANT] TRACK 2 CLOSED — and the A/B caught a real crash
- **The A/B did its §5.8 job twice over**: (1) it CAUGHT a real ON-path crash the
  grep-based acceptance check had missed (δ/β interning meta-bearing exprs →
  PCE's admission guard correctly erroring on uninterned symbols; the weak gate
  counted zero "error" lines and never checked exit codes — data point #16:
  ACCEPTANCE CHECKS MUST CHECK EXIT CODES). Fix: PCE-admissibility fallback in the
  memo (inadmissible terms simply don't memoize — domain dispatch, not defensive
  programming; the closed-domain design behaving as designed). (2) It rendered the
  honest verdict: ON = +38% on the fresh-heavy small acceptance (reduce 40→164ms —
  the floor manifesting), NEUTRAL on ppn-track4c. THE FLIP CRITERION IS NOT MET;
  default stays OFF per the hook's own definition; the payoff curve points at
  Tracks 4/5 exactly as chartered at iteration 0.
- **The owed δ process-string test**: DISCHARGED BY the Level-3 acceptance-ON exit-
  code-checked gate (strictly stronger than process-string for this path) — the
  reasoning recorded here rather than a redundant test.
- **Track 2 CLOSED**: PIR (16 questions; §15 corpus caveat explicit; §16
  longitudinal — precision-as-soundness CONFIRMED at 3 data points), Master row ✅
  with the A/B verdict, doorbell rung.
- **Landed in**: (this commit)

## 2026-06-10 — LOOP iteration 27 — [SIGNIFICANT] Track 4 design OPENED — extraction as a propagator fixpoint
- **The design centerpiece**: classic e-graph extraction IS a propagator quiescence
  on the existing substrate — Q-valued extraction-cost cells (min-merge, CALM) +
  refireable per-node cost propagators watching children (the iteration-12 fan-in
  shape with a different payload) + a pure top-down read at quiescence. NO new
  stratum (the SM4 admission test passes: extraction needs S0 quiescence, which
  run-to-quiescence provides); extraction-time is ALSO where semantic-NAC presence
  reads land per the SM3 D1 lock.
- **§1 derives (not re-decides) from owner D7**: Q = 4-function interface; v1 =
  tropical (min,+); multi-dim cost = a later Q instance, no schema change.
- **§3 names a contract distinction**: the question-keyed store is a CACHE lattice
  (better-wins monotone under q-better?), NOT a registry (append-only) — the §6 Q3
  critique question.
- **§5 commits the payoff A/B** to answer the Track 2 §15 corpus caveat WITH A
  CORPUS (a repeated-reference acceptance section), and re-opens the flip decision
  with that data.
- **Landed in**: (this commit)

## 2026-06-10 — LOOP iteration 28 — [SIGNIFICANT] Track 4 DESIGN COMPLETE
- §6 resolved 3-column: LAZY cost cells (extraction-request-bound; the burst rides
  the quiescence call already being made); DEDICATED parent-descriptor index
  (cohesion; the iteration-12 merge reused; written at intern, consumed lazily);
  the store is a CACHE LATTICE not a registry (primary/derived per SRE Q5;
  recomputable-by-construction with a declared eviction boundary — the
  belt-and-suspenders shape requires a fallback path, which does not exist).
- §7 fine NTT: two PROPOSED-NEW surfaces only (q-min-merge + extraction.rkt);
  everything else reuses landed realizations. §8 VAG challenged four decisions
  incl. the "lazy twice in a row" habit check (resolved: both bind work to PRESENT
  information — a request is information).
- **Landed in**: (this commit). Phase 1 next: Q interface + cost cells + fixpoint
  propagators + the diamond/cascade tests.

## 2026-06-10 — LOOP iteration 29 — [SIGNIFICANT] Track 4 Phase 1 — EXTRACTION RUNS AS A PROPAGATOR FIXPOINT
- **Shipped**: extraction.rkt (the q-instance interface — combine/better?/identity/
  top/criterion-id; tropical v1; tropical-cost-merge + 'extraction-cost SRE domain;
  lazy per-canonical cost cells seeded from LITERAL bests; REFIREABLE cost-recompute
  propagators per descriptor; run-to-quiescence = the fixpoint; pure top-down argmin
  read rebuilding the cost-best FORM tree) + the parent-descriptor index cell
  (child-keyed, written at intern-node; descriptors gained node-cost as a
  backward-compatible 4th element).
- **Two gate-caught e-graph fundamentals (data points #17, #18)**: (1) LITERAL-ONLY
  SEEDING — a node-born ':best carries the node-LOCAL cost, not a valid total; the
  seed must come from literal alts only (the local 2 beat the compositional 3 and
  served a non-form); (2) CANONICALIZE EVERY IDENTITY — descriptors carry pre-union
  member cell-ids; the union is invisible unless reachability, cell allocation,
  propagator wiring, and the read ALL go through ':canonical (the diamond's g-alt
  was unreachable from f's cell until then). Both are textbook e-graph rules that
  the propagator realization had to re-learn through its own gates — and now
  enforces by construction.
- **The diamond passes**: g(x) at 3 beats f(x) at 11 through ONE quiescence;
  h(g(x)) at 4 through two levels; cheaper literals beat node alts; deterministic.
- **Landed in**: (this commit). Phases 2-4: the question-keyed store, residuation,
  the payoff A/B.

## 2026-06-10 — LOOP iteration 30 — [ROUTINE] Track 4 Phase 2 — the question-keyed store lives
- **Shipped**: extraction-store.rkt — the SM6 §7.4 owner schema realized as a CACHE
  LATTICE (keep-better per key under the criterion's order; bot=empty; recomputable
  from primary; the registry contract explicitly NOT applied); the question key =
  (PCE digest of the class's SORTED alt-digest set, criterion-id, RESERVED
  worldview #f) — content-defined: the same alternative set is the same QUESTION
  regardless of cell identity; extract/cached (consult-before, record-after).
- **Proof (15 checks)**: miss runs the fixpoint + records; HIT SERVES WITH ZERO
  ALLOCATION (next-cell-id unchanged — the fixpoint provably did not run); a
  different criterion-id is a different question; keep-better absorbs a worse
  write and accepts a better one (the lattice, both directions).
- **Landed in**: (this commit). Phase 3 residuation next, then the payoff A/B.

## 2026-06-10 — LOOP iteration 31 — [ROUTINE] Track 4 Phase 3 — residuation's first consumer
- **Shipped**: extract/budgeted — tropical-left-residual (PPN 4C 1B; pure leaf
  module, zero consumers until now) gets its FIRST production consumer: root
  feasibility = the comparison (the algebra FLOORS, so infeasibility is cost >
  budget, never a sign); feasible → (cost, form, residual); infeasible → #f
  (an infeasible QUESTION, never an error). Honest scope note in-code: over
  CONVERGED exact costs the root check decides the whole tree; per-level
  residual pruning earns its keep under partial costs / multi-criteria Q — the
  named growth path, not built speculatively.
- **Proof (23 checks total)**: budget 5 admits the diamond's optimum (3) with
  residual 2 ≡ the 1B primitive's answer; budget 2 → #f; exact-fit → residual 0
  (the truncated floor); the residual threads ASSOCIATIVELY down the winning
  tree (manual chain ≡ root residual).
- **Landed in**: (this commit). Phase 4 (the payoff A/B) closes the track.

## 2026-06-10 — LOOP iteration 32 — [SIGNIFICANT] TRACK 4 CLOSED — the machinery is done; the curve has not turned; the levers are named
- **The A/B's real findings**: (1) TWO corpus premises FALSIFIED in single runs
  (defs evaluate eagerly — references add no reduce work; repeated top-level calls
  don't route heavy work through the instrumented path at testable scale) — the
  falsifications taught more than a confirming benchmark; (2) the memo's MARGINAL
  cost on repeated identical redexes ≈ 0 (proven in deltas: corpus +12ms OFF,
  ~0 ON); (3) blanket ingestion's standing overhead (+~130ms on the acceptance)
  exceeds recovery on every corpus in hand. THE FLIP CRITERION REMAINS UNMET —
  recorded without spin.
- **What IS done**: extraction as a propagator fixpoint (proven), the question-
  keyed store (zero-allocation hits), residuation consumed, the floor + the
  instruments. §15's chain names the SPECIFIC levers: selective ingestion
  (δ/β-only, size-thresholded), the consult-wiring of extract/cached into the
  read path, Track 5 cross-file multiplication — each cheap to test against
  ppn-track4c's 1136ms reduce phase.
- **PIR + Master row + doorbell.** §16 new candidate: "falsify the workload
  premise before building the benchmark" (2 points this track).
- **Landed in**: (this commit)
