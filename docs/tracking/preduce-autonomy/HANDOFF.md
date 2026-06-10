# PReduce Autonomy — Handoff

**Rewritten at the end of every iteration. Read this SECOND (after CHARTER.md) at
the start of every iteration.**

---

## Current state (as of 2026-06-10, LOOP iteration 0 — Phase B is LIVE)

**The loop is running.** Iteration 0 CLOSED (suite GREEN 8380/428/131.2s at 41d222d7;
bench-ab baseline saved). Iteration 1 IN FLIGHT: the reduction-share method DECIDED
(sampling profiler; tools/profile-reduction-share.rkt committed — see ledger) and the
measurement is running across the comparative set in background
(data/benchmarks/profiles/redshare-*.txt). DONE: denominator RECONCILED (phase-accounting reduce_ms ~75% on ppn-track4c — the
owner figure is CONSISTENT under the phase lens; profiler tree-bound 25.4% for
whole-process honesty; both standing). DONE: **SM1.1a LANDED green** (facet substrate:
4 internal facets + hardened closed dispatch + scoped bot-filter + arity-2 filter +
tests; one wake-duty regression gate-caught + root-caused + scoped; one pre-existing
batch flake documented — test-module-network-01 4B.3-b, registry state under
batch save/restore). DONE: **SM1.1b LANDED — SM1.1 (a+b) COMPLETE** (shape-P precise: ~420× at N=5000,
flat O(|delta|); over-fire×fire-once lesson = data point #10 + Watching codification
candidate; batch flakes adjudicated NOT-SM1.1b by controlled A/B).
DONE: flake audit (iter 5) — mechanism found (module-load parameter mutation +
missing restore-list entry), conformance patch landed, fix hypothesis REFUTED by
experiment, flake CLASSIFIED+TRACKED in DEFERRED.md (instrumented probe queued;
structural fix = SM3 registry absorption; gate policy = non-blocking iff passes
individually, verified per occurrence).
DONE: Track 1 acceptance file landed (Phase-0 gate discharged; reduction-kind-
organized; Level-3 clean; run before/after every phase).
DONE: pce.rkt LANDED (PCE/1 encoder + digests + persisted-domain guard + golden
vectors + 23 tests; cross-process determinism verified).
DONE: eclass-cell.rkt + the 'eclass-refine relation LANDED (the SM2 lock realized:
product merge + 'term carrier + relation constant/variance/factory/ctor-table; 22
tests through the public dispatcher).
DONE: **THE GREEN SLICE IS ALIVE** (eclass-graph.rkt: hashcons + intern + union-
emitter; 41 first-run-green checks incl. the D.1 §2.4 literal trace, racing-union
CALM fixpoint, and the consuming read; ':alts equal?-set design fix). Track 1
substrate stack complete: facets ✅ shape-P ✅ PCE ✅ product cell + relation ✅
hashcons + union ✅.
NEXT UNIT (choose at firing per charter §7 sequencing): (a) **#:after ordering +
keep-pending substrate** (stratification.md CAUTION: REQUIRED before any
order-sensitive handler pair — BLOCKING for rule promotion; touches
register-stratum-handler! propagator.rkt:3193 + the process-tier auto-reset
:3466-3468), OR (b) **D5 probe** (singleton-fraction calibration on the comparative
corpus — cheap, informs Track 1 close), OR (c) **congruence layer** (S0
signature-set watchers per D.1 §2.1). Recommended order: (b) D5 probe (one firing,
data informs everything), then (a) #:after substrate, then (c). The effect-safety
guard (BLOCKING Track 2 Phase 0) remains queued behind these.
Implementation queue below. Phase A history follows for context.

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
DONE: SM2 LOCKED (db0bb8ba), SM3 LOCKED (7162f492), SM1 SETTLED (§4) — owner: extend
attribute map / epoch-keyed live-parse / commission 2′ assessment. Diff-cost ceiling
CONFIRMED (O(all-keys) per compound write; fix must be cell-layer); ".pnet populates
attribute map" comment = fiction.
DONE ALSO: SM1 LOCKED (D frame adopted: eager green + shape-P for attr-map + 2′-B
pre-registered at D4's T-FLIP gate; NAME-at-reservation closed no-amendment; SM2
fast-path phrase clarified per-class; Master §Layer-1 amended; negative invariant
homed in §4.8).
DONE ALSO: SM4 LOCKED. SM5 + SM6 LOCKED (combined panel; §6 + §7): F-A hashcons-dedup
+ F-B generic-rule-capture soundness findings; floor in Track 1, effect-safety guard =
BLOCKING Track 2 Phase 0; deterministic (epoch × occurrence-path) keys for effectful
occurrences; add-only re-entry (Q7 answered); Axis-2 re-specified as product (Master
amended); ground-admission rule (born-context-free only into question-keyed store);
pessimistic classification + bite counters; regime = 5th SM2 product component
(owner-signed amendment of a locked sub-model); ground-only cross-session day one;
T7 RESOLVED in-panel (pnet-serialize surface read; first-of-kind cell-state sections
named).
**TRACK 0.1 CLOSED 2026-06-10** — NTT exit gate PASSED (D.1 §8.4; adversarial purity
pass returned PASS-WITH-AMENDMENTS, all applied: precise lattice definitions for
write-once-flat + dedup-or-error with ⊤contradiction as legitimate top; two
pre-deployment verification gates recorded for SP2/SP3). Master Track 0.1 row ✅.
**PHASE A COMPLETE 2026-06-10** — Tracks 0.1 (D.1), 0.2 (D.2), 0.3 (D.3) all CLOSED;
Track 0 (series founding) ✅ in the Master. The full lock-set lives on this branch.
NEXT (in order):
(a) **OWNER: review + merge `preduce-autonomy` → main** (decided: merge after 0.3
close; docs-only, no code/suite risk; the lock-set becomes citable at main HEAD;
rebase onto current main first — main advances under the owner's other session).
(b) **OWNER ACTIONS carried**: DEFERRED.md triage (A.0 leftover — folded into the
loop's iteration-0 shakeout). [Zig PoC pinning REMOVED per owner ruling 2026-06-10:
the PoC is a separate lowering experiment, not a consumer — D.3 §5 amended.]
(c) **PHASE B ENTRY (the autonomous loop)**: conditions met post-merge. Track 1 =
the implementation queue in dependency order: SM1.1 production-merge commit + shape-P
delta-notify + comment fix (ONE commit + full typing regression); pce.rkt (PCE/1
encoder + golden vectors — precedes hashcons per LBD-5); D5 probe (singleton-fraction
FIRST; injected-rule variant); term-carrier domain + 'eclass-refine (8-edit surface,
§2.10); e-class product cell (5 components) + hashcons registry + union-emitter
(green slice per §2.4/§3.2); #:after ordering + keep-pending substrate (BLOCKING for
promotion); congruence layer; effect-safety guard = BLOCKING Track 2 Phase 0 (covers
ι instantiation). Per the charter: the loop works Phase B against these LOCKED
designs; OWNER-PROVISIONAL label for anything the locks under-determine; main-session
checkpoints per charter §7.
(d) Ledger holds 8 autonomy data points for the retro (charter §9).
PROCESS: pass the worktree path (/Users/avanti/dev/projects/prologos-preduce-auto)
for branch docs; panel COMPOSITIONS need the same skepticism as kill-shots (data
point #4).

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
