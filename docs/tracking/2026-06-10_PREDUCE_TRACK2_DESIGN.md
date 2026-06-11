# PReduce Track 2 Design — IN-Fragment Rule Ladder (D.2 §5 partition)

**Status**: DESIGN OPENING (2026-06-10, autonomy loop iteration 17) — §1 awaits the
owner ruling; §2-§4 derive from already-owner-signed locks; §5 (fine NTT) and the
critique rounds follow. **Exit criterion (owner-bound, D.2)**: not done until the
guard passes AND guarded β fires AND the PRN §2 confirmation is recorded.

## Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| D | This design doc through critique rounds + fine NTT | ✅ | iter 17-18; DESIGN COMPLETE (HVM2 §1 owner-provisional B+C) |
| 0 | RHS effect-safety dispatch guard (BLOCKING — D.1 §6.2 Option 2) | ⬜ | spec §2 |
| 1 | Arithmetic seed (~12-20 literal-fold rules) | ⬜ | §3 |
| 2 | δ (definition unfolding) | ⬜ | |
| 3 | Guarded β | ⬜ | the guard's first real exercise |

## §1 The HVM2 benchmark-posture decision — OWNER PACKAGE (the D.2 guard discharged)

Per the owner's 2026-06-10 deferral: "Track 2's design doc MUST open with the HVM2
benchmark-posture decision." The full design space, in prose:

**What HVM2 is, for this decision**: HVM2 (Higher-order Co.) is a standalone
massively-parallel runtime that compiles λ-terms to interaction combinators and
runs β-reduction with optimal-reduction-style sharing on CPU/GPU. It is the
strongest public existence proof that interaction-net evaluation scales in
practice. It is NOT a compiler-internal reducer: it owns its whole heap, has no
type checker in the loop, no elaboration interleaving, no effect system of our
shape, and measures THROUGHPUT of pure reduction — while PReduce's reducer runs
INSIDE elaboration on a propagator network, where the §5.8 phase-accounting
baseline says reduction is ~75% of in-driver phase time on reduction-heavy files.

**Posture A — benchmark target.** We declare HVM2 numbers (reductions/sec on
shared workloads like church-fold benchmarks) a comparison bar for Tracks 2-4.
What it buys: an external, un-gameable yardstick; prestige-grade evidence if we
ever approach it. What it costs: the comparison is apples-to-oranges TODAY in
both directions (they have no typing/elaboration overhead to carry; we have no
GPU lowering until SH/Zig work matures) — so early numbers would be
discouraging-by-construction and invite exactly the denominator confusion the
§5.8 reconciliation just untangled. Risk: the bar distorts design choices toward
HVM2's affine-sharing model, which conflicts with our QTT multiplicities and
worldview semantics in ways the D.2 census didn't price.

**Posture B — reference architecture.** We use HVM2 (and interaction-net
literature generally) as a NAMED design reference: the Track 2 ladder's rule
shapes get explicit correspondences (annihilation/commutation pairs ↔ our
relate-propagator pairs; duplication nodes ↔ e-class sharing via hashcons;
their redex queue ↔ our BSP worklist). What it buys: design discipline — every
ladder rule names its IN-theoretic role, which is cheap now and keeps the
"IN-fragment" claim honest; it also sets up the PRN §2 confirmation (reduction-
as-DPO) cleanly. What it costs: a correspondence section to maintain (~hours,
not days); the risk is cargo-culting IN idioms where the lattice substrate has
better-native answers (the SM2/SM4 locks are already non-IN in load-bearing
ways — merge-as-order has no IN analog).

**Posture C — defer again, with a concrete trigger.** No HVM2 commitments in
Track 2; re-open the decision when a named measurement exists. The natural
trigger: Track 8's retirement case (which already requires the measured
reduction-share improvement per the charter §5.8) — at that point we have OUR
numbers on OUR workloads, and an HVM2 comparison becomes interpretable rather
than aspirational. What it buys: zero distraction; no premature bar. What it
costs: the design loses the cheap discipline of posture B's correspondences,
and a third deferral of the same question starts to look like avoidance.

**Recommendation (loop)**: **B for design + C for benchmarking** — adopt the
reference-architecture correspondences in this doc (cheap, disciplines the
ladder, feeds PRN §2), and bind the BENCHMARK question to the Track 8 trigger
(where the §5.8 instruments make the comparison meaningful). Posture A alone is
premature on the evidence above. ⚠ OWNER — this is your deferred decision;
the loop proceeds on B+C as OWNER-PROVISIONAL (reversal path: the
correspondence subsection is additive prose; deleting it reverts B; A can be
adopted at any later point without rework).

## §2 Phase 0 — the RHS effect-safety dispatch guard (owner-signed; D.1 §6.2 Option 2)

The lock: the rule-application core — the SINGLE choke point that instantiates
any RHS — enforces that an RHS may not DELETE, DUPLICATE, or REORDER a captured
subterm whose class is effect-bearing. BLOCKING: must exist and pass before β
(the first generic rule) ever fires; β is its first real exercise.

Realization sketch (to be hardened in the critique rounds):
- The choke point is NEW code (Track 2 builds rule application; there is no
  legacy RHS instantiator to retrofit) — `apply-rule` in a new
  `rule-dispatch.rkt`: match LHS pattern → bind captured vars to child classes
  → instantiate RHS → intern + union result with the matched class.
- The guard runs INSIDE apply-rule, between bind and instantiate: for each
  captured variable, count its occurrences in LHS vs RHS templates (statically
  derivable per rule at REGISTRATION — compute once, store on the registry
  entry as a derived `capture-profile`); at APPLY time, consult the bound
  class's effect-bearing status (the :opaque facet / the effectful-occurrence
  provenance from iteration 13's floor). RHS-count < LHS-count = DELETE;
  > 1 = DUPLICATE; order changes among effectful captures = REORDER. Any of
  the three on an effect-bearing class → the rule does NOT fire for that match
  (structural skip + a counted diagnostic; NOT an error — pure rules on pure
  matches proceed).
- Tier-2 rules (apply-fn closures, no RHS template): the capture-profile is
  underivable — PESSIMISTIC: closure-resident rules do not fire on matches
  containing effect-bearing captures at all (same pessimism+counter mechanism
  as the head classification; the named upgrade is per-rule declared profiles).
- Tests precede the seed: a synthetic effectful class + a deleting rule + a
  duplicating rule + a reordering rule — all three skip; pure equivalents fire.

## §3 Phase 1 — the arithmetic seed (D.2: ~12-20 ops, all head-specific tier-1)

Candidate enumeration (literal folds; LHS = head op with literal-class children;
RHS = computed literal; all `'forward`, `'literal-fold` confluence class,
write-target `'best+alts`, stratum `'s0`):
int+ int- int* int/ int-mod (5) · int comparisons lt/le/gt/ge/eq (5) ·
bool and/or/not folds (3) · nat suc/pred folds on literals (2) · generic-op
folds where both children are same-family literals (defer cross-family to the
coercion-aware round — the numeric-join precedent applies) (≤5).
Each registers into the SM3 registry under the kernel pseudo-module via the
SAME register-rule path the seed pour uses; dispatch reads rules-for-tag.

## §4 Dispatch — broadcast-over-tag-matched-rules (owner D6, carried)

Ingestion (a term position elaborates → intern via eclass-graph; the position's
:eclass-link facet written) → the class's head tag looks up `rules-for-tag` →
the matched rule set fires as ONE broadcast per (class × stratum) with
result-merge = the SM2 write-target semantics (ACI merge-as-answer;
order-independent under critical pairs by construction — the lock's semantic
argument; NO perf claim attaches, so no microbench obligation here). Per-rule
installs remain the heterogeneous fallback.

## §5 Fine-grained NTT model (written iter 18; PIR §15 default discharged)

```ntt
;; --- cells (lattices = the six locked merges) ---
cell rule-registry : RuleRegistry
  :lattice :structural            ;; module-keyed product; dedup-or-error join
  :merge   rule-registry-merge    ;; rule-registry.rkt:96
  :home    prn

cell eclass[k] : EClassProduct    ;; one per interned class, PCE-keyed
  :lattice :structural            ;; {best|alts|canonical|provenance|regime}
  :merge   eclass-merge           ;; eclass-cell.rkt:80 (merge IS the order)

cell congruence-sig-index : SigIndex     :merge hash-union-of-set-union  ;; cell-20
cell congruence-request   : SigDelta     :merge hash-union              ;; cell-21
cell attribute-map        : AttrMap      :merge attribute-map-merge-fn
  :storage 'pointwise-compound    ;; shape-P: O(|delta|) changed-paths

;; --- the dispatch propagator (Phase 1+; ONE broadcast per class × stratum) ---
propagator rule-dispatch [class-cid]
  :reads  (eclass[class-cid] rule-registry)
  :writes (eclass[*] congruence-sig-index congruence-request)
  :fire (let* ([head (head-tag-of (best-form eclass[class-cid]))]
               [rules (rules-for-tag rule-registry head)])
          (broadcast rules                       ;; D6: tag-matched broadcast
            (lambda (rule)
              (apply-rule rule class-cid))))     ;; → rule-dispatch.rkt

;; --- apply-rule (the SINGLE RHS-instantiation choke point; Phase 0 guard inline) ---
;; match LHS → bind captures → GUARD (capture-profile × effect-bearing reads —
;; delete/dup/reorder on effect-bearing ⇒ structural SKIP + counter) →
;; instantiate RHS → eclass-intern → eclass-union (result-merge = write-target)

;; --- strata (SM4: no new kinds) ---
;; rule-dispatch fires in S0 (monotone: intern+union only grows classes);
;; congruence collision handler stays #:tier 'topology (cells 20/21, iter 12);
;; extraction-time NAC presence reads land at Track 4 (not here).
```

Correspondence: every keyword above → realization file:line as annotated; NEW
surfaces are `rule-dispatch.rkt` (apply-rule + capture-profile) and the
ingestion call-site (§6 Q1 resolution below). The D.1 §8 table extends by these
two rows; everything else reuses Track 1 realizations unchanged.

**IN-correspondence subsection (posture B, OWNER-PROVISIONAL)**: literal-fold
rules ≈ IN annihilation (two "agents" — op node + literal children — rewrite to
a value node); δ-unfolding ≈ indirection-node dereference; e-class sharing via
hashcons ≈ HVM2 duplication-node sharing WITHOUT the affine bookkeeping (our
sharing is lattice-monotone, not resource-counted — the QTT layer keeps
multiplicity soundness instead); BSP worklist ≈ the redex queue. Divergence
NAMED: merge-as-order has no IN analog; worldview tagging has no IN analog.

## §6 Open questions — RESOLVED (iter 18; 3-column adversarial per the VAG rule)

**Q1 ingestion timing → LAZY (intern at first rule match)).** Catalogue: lazy
avoids interning the (unmeasured — D5 still queued) singleton majority; eager
gives congruence a complete graph. Challenge: does lazy starve congruence?
No — congruence only ever does work when unions happen, and unions only happen
where rules fire; classes that never meet a rule contribute nothing but memory.
Risk accepted: when D5 data arrives, if singleton fraction is LOW, flip to
eager (one call-site move; recorded as the reversal path).

**Q2 nat literals → fold suc-chains to numeric form AT THE RULE BOUNDARY.**
Catalogue: the nat-value memoization precedent (reduction.rkt:875) already
extracts naturals from suc-chains per-command. Challenge: interning every suc
node as its own class is structurally pointless (the chain IS one literal);
PCE-encoding a 1000-deep chain is also O(n) waste. Resolution: the seed's nat
rules match via nat-value extraction and intern the NUMERIC literal form;
suc-chain sub-positions are not interned (lazy ingestion makes this free).

**Q3 guard observability → PERF-COUNTERS.** Catalogue: perf-inc-* counters are
the established shape; :warnings is user-facing. Challenge: is a guard skip
user-relevant? NO at Phase 0 (it is an internal soundness event; the rule
simply doesn't fire — semantics preserved); YES later if a user RULE is
skipped (Track 9 user rules — :warnings entry then, named). Phase 0:
`guard_skips` counter in PERF-COUNTERS.

**Panel-skip rationale (charter §5.2)**: all three questions sit entirely on
surfaces built this session with locked semantics; a multi-agent panel would
re-read code the resolver authored. The genuinely panel-shaped round was the
SM-level design (Phase A, six panels). Recorded, not silent.

## §7 VAG (adversarial, 3-column — iter 18)

| Decision | Catalogue (passes?) | Challenge (could it be MORE aligned?) |
|---|---|---|
| Lazy ingestion | on-network at first use | CHALLENGED: is lazy "imperative dispatch deciding what happens when"? No — laziness here is ABSENCE of work for absent information; the mantra binds information that EXISTS. Flip-to-eager path recorded. |
| Broadcast dispatch | D6 lock; ACI result-merge | CHALLENGED: the broadcast wraps a sequential loop today (propagator.rkt:2446) — claiming parallelism would be shape-without-benefit. NO perf claim made (the lock's own framing); the broadcast-profile metadata is the future scheduler's hook. |
| Guard as structural skip | soundness floor honored | CHALLENGED: should a skip be a CONTRADICTION instead (loud)? No — a skipped rule preserves semantics exactly (the term stays reducible by other rules / whnf); contradiction would make effect-adjacency a type error, which the SM5 lock explicitly rejected (boundary is one node thick). |
| Capture-profile at registration | derived once, stored | CHALLENGED: is the derived field a cache that can go stale? No — rule templates are IMMUTABLE post-registration (dedup-or-error makes re-registration equal?-only); staleness is structurally impossible. |

**DESIGN COMPLETE** pending the owner's HVM2 ruling (§1, proceeding B+C
provisional) — Phase 0 implementation may begin (its spec is lock-derived and
unaffected by any §1 outcome).
