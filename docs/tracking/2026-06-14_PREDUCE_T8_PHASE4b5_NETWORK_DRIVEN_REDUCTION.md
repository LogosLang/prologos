# PReduce Track 8 — Phases 4b/4c/5: network-DRIVEN reduction + bypass `reduction.rkt`

**Created**: 2026-06-14
**Status**: 🔄 Stage 3 design + 5a implemented. I lead/approve per owner posture
("you lead and approve design … review after implementation complete"; "/loop
continue design and implementation through phase 5"). Methodology gates (NTT,
Network Reality Check, PARITY, full suite) apply.

**Progress**: 5a ✅ (`a72b3f2`) — `whnf-step1` + loop-driven `whnf-via-egraph`,
parity-gated. **5b ✅ (`c49c53c`)** — `whnf-via-egraph-network`: the SCHEDULER-DRIVEN
cascade (reduce stratum, cell-23, keep-pending). The reduction DRIVER is the BSP
scheduler, not a loop — Network Reality Check PASSES. Parity-gated against native
whnf (test-preduce-egraph.rkt network variant, 47 checks); **full suite 8725
all-pass**. The migrated fragment (β, ι, suc-collapse, fst/snd, J, boolrec, ann,
vhead/vtail) is genuinely network-driven; the rest is the 'native fallback;
demand subterms native (full cascade-driven demand via set-latch = future).
**5d ✅ (parallel demand)** — the set-latch refinement landed for INDEPENDENT
operands: binary arithmetic (int+/-/*/lt/le/eq) emits `'demand-par`, which interns
ALL operands and queues them into the SAME reduce-request round so their cascades
interleave per BSP round (not sequenced), joined by a barrier propagator
(set-latch fan-in, `propagator-design.md`). Fixes "reduction serializes
independent subterms": the balanced-tree acceptance collapsed 353→43 BSP rounds
(8.2× depth reduction, max 256 propagators/round); fib's two recursive branches now
progress together. Parity-gated; full suite green. See §10.5.
**5c (route the DEFAULT whnf through the engine = bypass deploy) is staged**: it
is low-value + risky until more constructs migrate off 'native (most reduction is
still 'native today), and it changes the hot path → needs suite-wide parity.
Terminal (delete native arms) owner-gated. See §10.
**Builds on**: Phase 2 (dispatch stratum), Phase 4a (recursion step = union
propagator) + the cbv memo key + incremental observer
(`2026-06-14_PREDUCE_T8_PHASE4_RECURSION_ON_NETWORK.md`).
**Thesis** (PReduce Master): *"reduction lifts entirely onto the propagator
network … reduction.rkt retired … rule application IS propagator firing."*

## 1. The gap after 4a

4a put the recursion-step RECORDING on-network (each β/δ/ι step is a union
propagator). But the DRIVER is still off-network: `whnf`'s arms compute a
contractum and **recursively call `whnf`** (`reduction.rkt` whnf-impl/match). The
network records what whnf already decided; it does not DRIVE the reduction.

Phases 4b/4c/5 move the driver on-network: reduction becomes e-graph saturation
(rules fire as propagators/stratum, a cascade drives the next step), and `whnf`/`nf`
become **intern → saturate → extract** (Phase 5 = bypass the recursive arms).

## 2. Scope reality (grounded at HEAD) — why this is staged

`whnf-impl/match` is ~1700 lines over DOZENS of constructs (β; δ fvar-unfold;
ι natrec on nat-val/zero/suc; suc-collapse; fst/snd; J; boolrec; ann; vhead/vtail;
foreign-fn app; general app (reduce-func); int +/−/*/÷/mod/neg/abs/lt/le/eq;
from-nat; rat arith; posit8/16/32/64 arith; structural `reduce`/match; map/string
ops; …), each with its own **strictness** (which subterms must be WHNF before the
head fires). A COMPLETE bypass (parity across all of them) is multi-session.

Therefore: a **staged migration**, parity-gated, with an honest native fallback
for not-yet-migrated constructs. "Incomplete because the construct set is large"
— NOT "pragmatic dual path." The fallback shrinks to nothing as constructs migrate.

## 3. The architecture — a demand cascade on the dispatch stratum

The unifying primitive: a **one-step classifier**

```
whnf-step1 : expr → (contractum E)        ; head-reduced one step to E
                  | (demand (P …))         ; STRICT: subterms at positions P must
                                           ;   be WHNF before the head can fire
                  | 'whnf                   ; already weak-head-normal (value/neutral)
                  | 'native                 ; construct not yet migrated → fallback
```

derived from `whnf-impl/match` by replacing each recursive `(whnf x)` with either
a `demand` on x (strict prefix) or a `contractum` (the head step). Examples:
- β `(app (lam b) a)` → `(contractum (subst 0 a b))` (head; no demand)
- δ `(app (fvar f) …)` (f defined) → `(contractum (unfold f …))` (head)
- ι `(natrec m z s (suc n))` → `(contractum (app (app s n) (natrec m z s n)))`
- arith `(int+ A B)` → if A,B literals `(contractum (int (+ a b)))` else
  `(demand (0 1))` (strict in both operands)
- `(reduce S arms)` → if S a constructor `(contractum (arm-body …))` else
  `(demand (0))` (strict in scrutinee)
- value/neutral head → `'whnf`

### Reduce-propagator + cascade (the driver, on-network)

For a class K with best form F:
1. `whnf-step1 F`:
   - `(contractum E)` → intern E, `eclass-union K E`, **emit dispatch on E's class**
     (the cascade follows the head — this is the recursion, on-network).
   - `(demand Ps)` → for each position p, intern the subterm, emit dispatch on it,
     and install a **readiness watcher** (set-latch, `propagator-design.md`): when
     all demanded subterms reach WHNF (their classes' best is a value), RE-FIRE the
     reduce-propagator on K (now the head can fire). Strictness = a fan-in latch.
   - `'whnf` → done (K is weak-head-normal; its best IS the WHNF).
   - `'native` → fall back: compute `(whnf F)` natively, intern + union (the 4a
     recording path) — staged-migration escape hatch.
2. The reduce-propagator is REFIREABLE (demand re-fires it) and component-path
   precise (watches only the demanded subterm classes).

**Weak-head control** falls out of `demand`: we only reduce subterms a construct
is STRICT in (to expose its head). Inner non-demanded subterms are never dispatched
→ no over-saturation, WHNF not full NF. (Full `nf` = whnf + recursively dispatch
the remaining subterms; a separate outer pass.)

**Termination**: the global reduction fuel (cell-11) already bounds the cascade;
the cbv memo key makes the e-graph share repeated redexes so the cascade is the
DAG, not the tree.

### Form representation (the linchpin decision)

Operate on **expr-structs** (what 4a/δ already intern), NOT list-form templates.
`whnf-step1` is native Racket over expr-structs (subst, unfold, fold) — the SAME
"compute inside the rule" pattern arithmetic uses (`(compute + …)`); we just keep
the values as expr-structs. This SIDESTEPS the list-form template language's
inability to express de Bruijn substitution (the 4c blocker). The "rule" is the
reduce-propagator; the "RHS compute" is `whnf-step1`'s contractum. Network Reality
Check holds: a propagator fires, reads the class, writes the contractum class +
union, the cascade dispatches — the result emerges from cell writes, not a return.

## 4. Phase 5 — `whnf`/`nf` via extraction

- `whnf-via-egraph E`: intern E → `run-to-quiescence` (the reduce-propagators +
  cascade saturate the head chain) → read E's class `:best` (the WHNF).
- `nf-via-egraph E`: whnf-via-egraph, then recursively dispatch the subterms
  (full saturation under the demand discipline extended to all positions).
- **Bypass**: route `whnf`/`nf` through the egraph path for the COVERED fragment;
  `'native` fallback for the rest. As constructs migrate, the fallback shrinks. The
  end state ("reduction.rkt retired") is reached when `whnf-step1` returns `'native`
  for nothing — a future session's milestone, owner-gated for the final deletion.

## 5. NTT model (sketch)

```
cell eclass[K] : eclass-value                    -- :best form, lattice
cell dispatch-requests : { eclass-id ↦ unit }    -- hash-union (Phase 2 cell-22)

propagator reduce(K) :                            -- the rule, on the dispatch stratum
  reads  eclass[K].:best  (+ demanded subterm classes' :best)
  writes eclass[K], eclass[contractum], dispatch-requests
  fire:  case whnf-step1(best K) of
           contractum E -> intern E; union K E; request E
           demand Ps    -> request Ps; latch: when all WHNF, refire K
           whnf         -> ∅
           native       -> fallback: whnf natively; union   (staged)

stratum dispatch (Phase 2 process-dispatch-requests) : runs reduce(K) per pending K
```

| NTT | Racket |
|---|---|
| `reduce(K)` rule | extend `process-dispatch-requests` to run `whnf-step1` per class |
| `whnf-step1` | new — refactor of `whnf-impl/match` (one-step + demand) |
| demand latch | `monotone-set` latch + threshold (`propagator-design.md` set-latch) |
| extraction | `net-cell-read` K's `:best` after quiescence |
| parity gate | run native `whnf` and `whnf-via-egraph`, assert `equal?` |

## 6. PARITY GATE (the safety net — non-negotiable)

Every migrated construct is gated by: for a corpus (acceptance file terms + test
terms), `(equal? (whnf-native E) (whnf-via-egraph E))` for all E. A parity harness
runs both and diffs. A construct is "migrated" only when parity holds on the corpus
AND the full suite is green with `whnf` routed through the egraph path for it.
Native `whnf` is retained as the parity ORACLE during migration; it is deleted only
when `whnf-step1` covers everything (the terminal, owner-gated).

## 7. Staged implementation plan (parity-gated per stage)

- **5a — engine + parity harness (no default change)**: `whnf-step1` for the CORE
  head fragment (β, δ, ι) + `demand` for the strict fragment (arith, `reduce`);
  the reduce-propagator + demand-latch cascade; `whnf-via-egraph`; a parity harness
  test. Gate: parity holds on fib/factorial/arith corpus; suite green (default
  unchanged — egraph path is opt-in/tested).
- **5b — deploy for the covered fragment**: route `whnf` through `whnf-via-egraph`
  when `whnf-step1` covers the whole reduction (else native). Gate: full suite green
  via the egraph path for covered terms; acceptance 0 errors; viz shows the cascade.
- **5c+ — migrate remaining constructs** (vectors, posits, J, boolrec, foreign,
  maps, strings…), one parity-gated batch at a time. Terminal (all covered → delete
  native arms) is **owner-gated**.

## 8. Risks

- **Parity divergence** (reduction order, sharing, neutral forms): the harness
  catches it per-construct; fix `whnf-step1` until `equal?`. Do NOT route a
  construct whose parity fails.
- **Demand-latch correctness** (strict constructs): the set-latch must re-fire only
  when ALL demanded subterms are WHNF; use the tested `monotone-set` + threshold.
- **Cascade non-termination**: fuel-bounded (cell-11); the cbv memo key dedups.
- **Scope creep**: STOP at 5a (engine + parity, no default change) if 5b parity
  is not clean; that is a complete, valuable, honest increment. 5c+/terminal are
  explicitly multi-session.

## 9. 5b machinery — DESIGNED + de-risked (next-session implementation spec)

5a's driver is a LOOP. 5b makes it scheduler-driven (the genuine network-DRIVE).
The machinery is intricate (several interdependent correctness points); it is fully
specified here so it implements cleanly. Per §8 scope-creep guard, 5a (validated
primitive, gated) is the landed increment; 5b lands when its parity is clean.

**Request representation (origin-keyed — sidesteps the extraction/cost problem).**
`reduce-request-cell-id` (cell-23; hash-union; **`#:keep-pending? #t`**) maps
`origin-K → current-form` (NOT `class-id → #t`). The origin K is fixed; the form
evolves down the reduction. This makes extraction trivial: when done, write K's
`:best`. No cost-juggling across a union chain.

**Reduce stratum handler** (reduction.rkt; registered `register-stratum-handler!
#:tier 'topology #:keep-pending? #t`). For each `(K . F)` in pending:
- `'whnf`  → write K `:best = (cons 0 F)` (the WHNF). Done (no re-request).
- `'native`→ `Fn = (whnf F)`; write K `:best = (cons 0 Fn)`. Done.
- `(step C)`→ union K with intern(C) (the on-network RECORDING / viz trace); write
  `reduce-request {K → C}` (cascade; survives via keep-pending).
- `(demand SUB RECON)` → `sub-nf = whnf-via-egraph-NETWORK(SUB)` (nested, re-entrant
  — `current-bsp-fire-round?` is #f in strata, verified Phase 2); `F' = RECON sub-nf`;
  write `reduce-request {K → F'}`.

**Cascade re-trigger (the load-bearing mechanism):** the `union K (intern C)` in the
`step` arm installs an `eclass-union` relate propagator → **S0 worklist activity** →
the BSP outer loop fires it → strata re-run → the reduce stratum sees the kept
`{K → C}` → reduces C → … This is why `step` MUST union (not just re-request): the
union is what re-triggers the scheduler each round (mirrors how congruence requests
ride on watcher fires). Without it, a bare request write leaves the worklist empty
and the stratum never re-runs (the Phase-2 inner/drain early-return on empty
worklist).

**Driver / extraction.** `whnf-via-egraph-NETWORK(E)`: `eclass-intern E → K`; install
a fire-once S0 EMITTER on K writing `reduce-request {K → E}` (the Phase-2 emitter
pattern — needed so the first stratum pass runs; emitter watches K so it dodges the
Tier-1 fast path that skips strata); `run-to-quiescence`; extract `(cdr (eclass-read
K :best))`. No-plumbing → native `whnf` (total, as 5a).

**Parity + deploy (5c).** Extend test-preduce-egraph with a NETWORK variant (set up
prn-box + hc per test-preduce-ingest) and assert `whnf-via-egraph-NETWORK == whnf`
on the corpus. When parity holds + suite green, route `whnf` through the network
path for the covered fragment (`'native` for the rest — the shrinking fallback).

**Correctness points to verify (the risk register):**
1. Cascade terminates: `'whnf`/`'native` arms write no request; fuel (cell-11) backstops.
2. Extraction = WHNF: origin-keyed `:best`-write at the `'whnf` arm (not cost-racing).
3. keep-pending: reset runs BEFORE the handler, so the handler's `{K→C}` survives.
4. Re-trigger: the `step` arm's union supplies the worklist activity each round.
5. Nested demand re-entrancy: clear/scope as Phase 2 (strata run with fire-round #f).
6. cell-23 cell-count test bumps (test-propagator/trace-serialize/observatory) — as cell-22.

This is the complete spec; 5b is implementation + parity-debugging, not redesign.

## 10. 5b LANDED (2026-06-14) — scheduler-driven reduction, validated

`whnf-via-egraph-network` (`c49c53c`) realizes the genuine network-DRIVE: the BSP
scheduler drives reduction via the keep-pending reduce stratum, exactly per §9.

- **cell-23 reduce-request** (origin-keyed {K → current-form}, hash-overwrite).
- **`process-reduce-requests`** (`register-stratum-handler! #:keep-pending? #t
  #:tier 'topology`): 'whnf/'native write K's cost-0 `:best` (extraction); 'step
  interns + unions K (the union = the worklist activity that re-triggers the
  stratum each round) + re-requests {K → C}; 'demand reduces the strict subterm
  natively then continues the cascade.
- **driver**: intern E → emitter (fire-once on K, dodges Tier-1) writes {K → E};
  `run-to-quiescence` saturates; extract K's `:best`. No-plumbing/inadmissible →
  native whnf (total).

**Network Reality Check (PASSES):** (1) stratum + emitter + per-step union added;
(2) result via `net-cell-write` (K's :best), triggered by the reduce-request cell
write + union worklist activity, driven by `run-to-quiescence` (the scheduler) —
NOT a Racket loop; (3) trace: intern → emitter → reduce-request → stratum →
cascade (union + re-request) → scheduler re-fires → 'whnf → write K :best →
extract.

**Gate:** parity (whnf-via-egraph-network == native whnf, 47 checks) + full suite
**8725 all-pass**.

**What this is / isn't.** This is the network-driven reduction ENGINE (the Phase 5
substrate), validated, for the migrated head fragment. It is NOT yet the default
whnf (5c). Deploying it as the default is gated on migrating the remaining
constructs (arith, structural reduce, δ, foreign, posits, maps, strings…) into
`whnf-step1` so the routing is meaningful rather than mostly-'native overhead —
the multi-session construct-migration work. The terminal (`reduction.rkt` arms
deleted) stays owner-gated.

**Honest scope note:** demand subterms reduce via native whnf in 5b (the head
chain is scheduler-driven). Full cascade-driven demand (the strict subterms also
on the cascade) is the set-latch refinement (`propagator-design.md`) — landed for
INDEPENDENT operands in 5d (§10.5); the single-strict-subterm `'demand` arms (app
head, fst/snd, natrec target, J, boolrec, vhead/vtail, reduce scrutinee, int
neg/abs) stay native (one strict position → no parallelism to gain; routing them
is the ~7× demand-cascade cost declined in 5c).

## 10.5 — 5d: parallel demand (`'demand-par`) — the set-latch refinement for independent operands

**Problem (owner, 2026-06-15):** "reduction design serializes independent
subterms." Single-subterm `'demand` is strict in exactly ONE position, so a
construct with N INDEPENDENT strict operands (binary arithmetic: `int+` is strict
in BOTH args, neither depends on the other) was sequenced — operand i fully reduced
before operand j even began. For `(int+ (fib (n-1)) (fib (n-2)))` the two recursive
branches are independent yet were reduced one-then-the-other. This violates the
mantra's "all in parallel."

**Fix:** `whnf-step1`'s binary-arithmetic arms now emit
`(list 'demand-par OPERANDS RECON*)` (via the `step1-par` helper: `'native` when all
operands are already values — the int-int fast-folds are matched first; else
`'demand-par`). The reduce stratum's `pr-demand-par`:
1. interns EACH non-value operand to its own class `KOi` and queues `{KOi → Oi}`
   into the SAME `reduce-request` round → the stratum's `for/fold` advances ALL
   operands one step per round (interleaved cascades = parallel rounds);
2. installs a BARRIER propagator (`net-add-barrier`, the set-latch fan-in) watching
   the `KOi` classes; when ALL are READY (`:best` is cost-0 — the `pr-write-whnf!`
   marker) it re-forms `{K → (RECON* resolved)}` and the head cascade continues;
3. value operands pass through unchanged (no class allocated).

The iterating `whnf-via-egraph` variant handles `'demand-par` by reducing each
operand sequentially (parity-identical result; the parallelism is a property of the
NETWORK driver, not the classifier).

**Network Reality Check:** ✅ the operands' reductions are now genuine
`net-add-propagator`/`net-cell-write` cascades on the network (vs `whnf-native`
off-network in 5b); the barrier is a `net-add-propagator`; the join is information
flow through the `KOi` cells.

**Evidence (viz traces, before/after):**
| file | rounds (old → new) | multi-prop rounds | max prop/round |
|---|---|---|---|
| `2026-06-14-parallel-reduction.prologos` (balanced ×/+ tree) | 353 → **43** (8.2×) | 49 → 36 | 256 → 256 |
| `2026-06-14-fib-small.prologos` (`fib 6`) | 220 → 248 | 51 → **78** | 21 → 22 |

The balanced tree is the clean demonstration: the same width-256 work that was
sequenced across 353 rounds now completes in 43 (the tree's actual depth). fib gains
concurrency (51→78 multi-prop rounds) at a small round-count cost (operand reduction
moved on-network — more interning/union propagators); fib's depth-dominated
recursion is inherently more serial than the balanced tree.

**Scope:** binary arithmetic only (`int+/-/*/lt/le/eq`) — the genuine
independent-strict-operand case. Other eliminators are strict in one position (no
parallelism to gain). Generalizing parallelism INTO `whnf-impl`'s primitive folds
(e.g. parallel reduction of N-ary data-op operands) is the larger compute-leaf
reimplementation, SH/Zig-era.

Parity-gated (`test-preduce-egraph.rkt`, both variants); full suite green.
