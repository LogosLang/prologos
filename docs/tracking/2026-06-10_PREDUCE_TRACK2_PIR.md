# PReduce Track 2 PIR — IN-Fragment Rule Ladder

**Date**: 2026-06-10 · **Commits**: `23215fa1`..(close commit), loop iterations 17-26
**Exit criterion (owner-bound)**: guard passes ✓ AND guarded β fires ✓ AND the
PRN §2 confirmation recorded ✓ (PRN master Confirmed Findings row, 2026-06-10).
Written against POST_IMPLEMENTATION_REVIEW.org's 16 questions.

## §1 Stated objectives
D.2's ladder on Track 1's substrate: Phase 0 effect-safety dispatch guard
(BLOCKING) → arithmetic seed → δ → guarded β, with the design opening on the
HVM2 posture decision and the §5.8 measurement discipline throughout.

## §2 Delivered
The design doc (HVM2 owner package + fine NTT + 3-column resolutions + VAG);
rule-dispatch.rkt (capture profiles, the guard, apply-rule, compute nodes,
dispatch-rules); kernel-rules-seed.rkt (15 declarative folds + δ metadata);
the whnf ingestion hooks (int folds, δ-memo, guarded β — all gated default-OFF
with the flip criterion named at the hook); guard_skips through PERF-COUNTERS;
the overhead-floor instrument + numbers; the PRN §2 confirmation. ~120 new
checks across 3 test files.

## §3 Timeline
Iterations 17-26 in one session: design 2, Phase 0 1, seed 2 (incl. the
abort-sentinel fix), close-out cluster 1, ingestion hook 1, floor bench 1,
δ 1, β 1, close 1.

## §4 Deferred (named)
Binder-aware usage counter for β's per-match profile (pessimism + counter until
then); the tier-2 apply-fn FIRE path in apply-rule (guard already gates it);
the D5 probe (observer hook); ingestion beyond int/δ/β arms (ι is Track 3);
the HVM2 §1 ruling (B+C provisional, awaiting owner); the default-ON flip
(criterion: A/B positive on workloads where the cross-command memo bites —
this corpus is single-command-dominant; see §15).

## §5 What went well
The substrate held: every Track 2 phase composed Track 1 pieces without
modifying them (the e-class {redex, contractum} realization reused the δ memo
mechanics verbatim; the guard read iteration-13's classification unchanged).
The gates kept catching real semantics (abort-vs-#f; the counter divergence;
the memo-miss recursion caught at design review before any test ran).

## §6 What went wrong
Three self-inflicted-then-caught defects: #f doubling as abort sentinel
(boolean folds aborted); dual skip-counters diverging; the β memo-miss
self-recursion (caught pre-test). Each cost one cycle; each produced a
codified-or-watching lesson.

## §7 Where we got lucky
expr structs being loc-free + PCE-encodable (iteration-7 verification) made
the δ/β form projection IDENTITY — the expr↔form round-trip that looked like
Track 2's biggest surface simply vanished.

## §8 What surprised us
δ's true win condition is CROSS-COMMAND persistence (the per-command whnf
cache already covers within-command reuse) — visible only because the floor
measurement forced the question "what exactly does the memo beat?"

## §9 Architecture hold-up
Held. Rules are data in the registry cell; dispatch reads the derived tag
index; the guard is a structural application condition (never an exception);
all hooks total + gated; effects never enter the recorded graph. The
mantra-relevant deviation is the prn-box imperative mutation inside whnf —
inherited from the established box-carried-prn pattern, named for the SH-era
cell migration.

## §10 What this enables
Track 3 (ι/DPO) has pattern-matching rules as its only new rule shape; Track 4
(extraction) has cost-bearing classes to extract from; Track 8's retirement
case has its instruments and its floor.

## §11 Technical debt (named)
The pessimistic β guard (usage counter upgrade); per-occurrence v1 form
language vs expr forms split-brain (δ/β use exprs, the seed uses datums —
unify when ι forces the question); the occurrence-index box (iter 13, still).

## §12 What we'd do differently
Measure the floor BEFORE designing the ingestion hook (the order was right
this time by luck of the queue — the floor reframed δ's value proposition
mid-design).

## §13 Wrong assumptions
"The seed will demonstrate wins" — it demonstrates costs (the right
benchmark for a seed is correctness + the floor, not speedup); "#f is a fine
sentinel" (it never is in a language with booleans).

## §14 What we learned
The ladder's rungs differ in WHERE the novelty lives: the seed's novelty was
the template language; δ's was the key (digest = redefinition soundness);
β's was the guard interaction. None was the e-graph itself — Track 1 absorbed
all of that.

## §15 Are we solving the right problem?
Yes, with the corpus caveat now explicit: the cross-command memo's win
condition needs multi-command, repeated-reference workloads; the comparative
suite is elaboration-stress and the acceptance file is small. The A/B at this
close records the honest (likely ~neutral-to-negative) number; the REAL test
arrives with Track 4 extraction + Track 5 cross-file persistence, exactly as
the charter's payoff-curve note predicted at iteration 0.

## §16 Longitudinal (vs the 10 PIRs surveyed at Track 1's PIR)
The Track 1 PIR's three new candidates all recurred HERE: precision-as-
soundness (the sentinel bug is its third data point — pattern CONFIRMED,
codified), audit-the-class (counter divergence = same family), denominator-
definition disputes (the floor's "what does the memo beat" is the same lesson
in cost form). New this track: "dual counters need ONE increment fn by
construction" (#15) and "totality at gated match clauses" (the recursion +
the inline-native-fallback pattern — 2 data points, watching).

## Metrics
10 iterations · 9 code commits · ~120 new checks · suite 8571→8611 · the floor:
+51.6µs fresh / +6.5µs memo-hit per position · guarded β: effect-capturing
redexes 0-recorded (counter-verified) · **the close A/B (ON vs OFF, 5-run
medians)**: track1 acceptance total 332→460ms (+38%; reduce 40→164ms — the
floor manifesting on fresh-heavy/low-reuse work), ppn-track4c 1568→1556ms
(neutral). VERDICT: the flip criterion is NOT met; default stays OFF per the
hook's own definition. The A/B also CAUGHT a real crash (PCE admission on
meta-bearing exprs) that the grep-based acceptance check missed — exit-code
checking is now the standing acceptance discipline (data point #16).

## Key files
rule-dispatch.rkt · kernel-rules-seed.rkt · reduction.rkt (the three gated
hooks) · tests/test-{rule-dispatch,rules-seed,preduce-ingest}.rkt ·
benchmarks/micro/bench-preduce-ingest.rkt · the Track 2 design doc ·
PRN master (the §2 confirmation row).
