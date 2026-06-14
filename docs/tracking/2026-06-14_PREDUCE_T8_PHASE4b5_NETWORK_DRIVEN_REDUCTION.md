# PReduce Track 8 — Phases 4b/4c/5: network-DRIVEN reduction + bypass `reduction.rkt`

**Created**: 2026-06-14
**Status**: 🔄 DESIGN (Stage 3) — I lead/approve per owner posture ("you lead and
approve design … review after implementation complete"; "/loop continue design
and implementation through phase 5"). Methodology gates (NTT, Network Reality
Check, PARITY, full suite) apply.
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
