# GitHub #58 — O(N²) substitution blow-up: independent re-derivation and fix

**Issue**: [#58](https://github.com/LogosLang/prologos/issues/58) — *"O(N²) substitution
blow-up — `shift` walks growing accumulator on every binder traversal"*, filed by
kumavis 2026-05-04, assigned to hierophantos, labels `performance` / `interpreter` /
`substitution`.

**Status**: Stage-3 design settled; implementation in progress.
**Baseline HEAD**: `09d3566c` · **Branch**: `on2-substitution-blowup-732521`
**Owner ruling (2026-07-27)**: fix **all three layers** + the doc-truth sweep; close #58
on the whole result.

---

## Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| **P0** | Baseline measurement + this doc + the failing-test-first battery | ✅ | `5a2e57a3` — 11 `check-eq?` gates RED at HEAD, semantics invariants GREEN |
| **P1** | Layer 3 — `delta = 0` early-out in `shift` | ✅ | 11 → 7 red; the 4 G2 gates flip. End-to-end delta is WITHIN NOISE (6003 → 5973 ms at N=128) — Layer 1 masks it; becomes visible after P2 |
| **P2** | Layer 1 — whnf/nf cache key (`equal?` → `eq?`) | ✅ | **15.7× at N=256** and growing. All THREE per-command caches fixed (nf, whnf, nat-value — same defect, same family). Full suite **474 / 9209 / 1**, the 1 being this track's own P3 gates |
| **P3** | Layer 2 — `loose-bvar-range` short-circuit, all FOUR sites | ✅ | **LINEAR SCALING RESTORED — exponent 3.1 → 1.0.** N=256: 49 775 → 19 ms (**2 620×**). New `loose-bvar.rkt`; guard on both `shift` and `subst`. All 22 gates green incl. the differential oracle |
| **P4** | Doc-truth sweep | 🔄 | `bench-ab --ref` ✅ · `trivially-whnf?` ✅ · new pipeline.md § cache-key hazard ✅ · still: the "zero-cost" header claim, the stale hset comment |
| **X.close** | Bench matrix · DEFERRED triage · PIR · close #58 with contributor credit | ⬜ | PIR is the objective gate |

---

## 1. Why this is an independent re-derivation, not a port

kumavis fixed this on `origin/claude/ocapn-prologos-implementation-auLxZ` in three
commits (`a55817f8` diagnosis, `4f6b3f0` shift, `6f2e077` subst) and reported N=5
47 036 ms → 1 153 ms (40.8×), scaling N^2.0 → N^1.0. **None of the three is an ancestor
of `main`** (`git merge-base --is-ancestor` → NO for each; `grep -c loose-bvar` over
`racket/` → 0). Their branch's merge-base with main is `b467f1e3` (2026-07-26), only 44
commits back — so their tree is *current*, and it already runs their fix on top of our
SUB.1/2/3 work. That is useful evidence, not a reason to port blind.

We re-derived because `main` is not the tree the issue was filed against, and the
measurement below shows the dominant cost at HEAD is **not** what the issue names.

## 2. What we measured (P0 baseline, HEAD `09d3566c`)

All measurements under `PLT_CS_COMPILE_LIMIT=1000000` (mandatory — without it the
giant-match modules compile to the Chez interpreter, ~830× slower `shift`).

**Workload** (`acc8.prologos`, scratch): a tail-recursive accumulator whose argument
grows one cons per step. Workload-validity per `testing.md`: the only arithmetic is the
Nat counter's structural `suc` pattern — no bignums, no hashing, no container values
(a PVec/Map accumulator would measure *nothing*, since the runtime containers are closed
leaves in both walkers — see §5 G7).

```
spec build [List Nat] Nat -> [List Nat]
defn build
  | acc 0N       -> acc
  | acc [suc k]  -> [build [cons 1N acc] k]
[length [build nil 128N]]
```

### 2.1 The end-to-end signature

`reduce_steps` grows **exactly linearly** (2688/1344 = 2.00× per doubling — semantics
unchanged), while `reduce_ms` grows **~8.5× per doubling → exponent ≈ 3.0**:

| N | reduce_steps | reduce_ms | step ratio | time ratio |
|---|---|---|---|---|
| 8 | 253 | 2 | — | — |
| 32 | 757 | 85 | 1.80× | 7.7× |
| 64 | 1429 | 701 | 1.89× | 8.2× |
| 128 | 2773 | 6003 | **2.00×** | **8.6×** |

**This is worse than the issue reports.** The issue predicts N²; we measure N³.

### 2.2 Three stacked defects

**Layer 1 — the whnf/nf cache degenerates to O(N³).** The per-command caches are
`(make-hash)` — `equal?`-keyed on whole terms (`driver.rkt:708-709`), probed at
`reduction.rkt:1751-1753`. Racket's `equal-hash-code` is **depth-bounded**: a family of N
accumulator terms saturates at **17 distinct hash values**.

| N | distinct `equal-hash-code` values | collision rate |
|---|---|---|
| 16 | 16 | 0.0% |
| 64 | **17** | 73.4% |
| 256 | **17** | 93.4% |
| 1024 | **17** | 98.3% |

So every probe degenerates to a linear scan running full structural `equal?` against
O(N) resident keys, each comparison O(N) → **O(N³)**. Isolated on the exact term family:

| N | `make-hash` | `make-hasheq` | ratio |
|---|---|---|---|
| 64 | 33.9 ms | 0.008 ms | 4 338× |
| 128 | 318 ms | 0.016 ms | 19 758× |
| 256 | 2 334 ms | 0.066 ms | 35 413× |
| 512 | **16 922 ms** | 0.026 ms | **647 773×** |

⚠ **The issue explicitly rules this out** ("the whnf/nf cache is innocent — 0.04 % of
total"), and kumavis's third commit is titled *"root cause IDENTIFIED — shift, not
cache."* That conclusion was sound for their workload and their instrument: their
`cache-time` counter measured explicit bookkeeping, not collision cost, so it was
structurally blind to this. Both findings are real; **which layer dominates depends on
term shape.**

**Layer 2 — `shift` walks the growing argument, O(N²).** The issue's finding, confirmed
by micro: per-call cost scales at exponent **1.006** in argument node count, flat
~26 ns/node across a 125× size range. A **closed** argument — one `shift` provably
cannot change — still pays a full walk *and a full rebuild*.

**Layer 3 — free waste.** `shift` has no `delta = 0` early-out, and the reduce-arm call
site passes the arm's `binding-count` as delta, which is **0 for every nullary clause**.
So every `| nil -> …` / `| zero -> …` clause evaluates `(shift 0 0 s)`. Our own Redex
model already asserts `(shift 0 0 e) ≡ e` (`redex/properties.rkt:144-148`).

### 2.3 The layering, proved by A/B

Three cache modes, identical results at every N (semantics preserved):

| N | `equal?` (HEAD) | `hasheq` | no cache | speedup |
|---|---|---|---|---|
| 32 | 79 ms | 13 | 13 | 6.1× |
| 64 | 709 ms | 68 | 69 | 10.4× |
| 128 | 6 007 ms | 453 | 441 | 13.3× |
| 256 | **49 775 ms** | **3 264** | 3 250 | **15.3×** |

`hasheq` ≈ **no cache at all** at every N — on this workload the cache's structural hits
provide essentially zero benefit while costing 15×. And the profile inverts exactly as
the issue predicts once Layer 1 is removed:

| | HEAD (`equal?` cache) | with `hasheq` |
|---|---|---|
| `whnf` self | **58.6 %** | **0.1 %** |
| `shift` self | 1.1 % | **45.0 %** |
| `subst` total | 1.2 % | 46.1 % |

**Layer 1 was masking Layer 2.** With `hasheq` the exponent drops 3.1 → ~2.7, so Layer 2
is real and still needs fixing.

## 3. Two corrections to the issue's own text

**(a) The enumeration under-counts, 4:3.** `subst` re-shifts its argument at **four**
sites, not three: `substitution.rkt:549` (lam), `:551` (Pi), `:553` (Sigma) — and
**`:988`**, the `expr-reduce` arm, which passes `(shift bc 0 s)` **inside a `map` over
`arms`**. An A-arm match therefore costs A full walks of `s`, not one. For the canonical
2-clause accumulator `defn` the multiplier is **3 per element** (one lam + two reduce
arms). *A fix guarding only the `1 0` sites leaves the dominant multiplier in place.*

**(b) The proposed implementation is not the one that was built.** The issue plans a
`loose-bvar-range : Fixnum` field on "~327 expr-* structs". kumavis instead used a
`make-weak-hasheq` memo (`loose-bvar.rkt`, +110 lines), stating: *"We use a weak-memo to
get the same asymptotic behavior without touching all 327 expr-\* struct definitions."*
The struct count is **344** at HEAD, not 327.

The memo route also **avoids a soundness blocker nobody flagged**: `conv-nf` compares
*all* struct fields via `struct->vector` (`reduction.rkt:4421-4428`), so a cached range
field would participate in definitional equality — two structurally identical terms with
different cached ranges would compare unequal. Plus six generic `struct-type-make-constructor`
rebuild sites would carry a stale range, two of them (`re-abstract`, `rename-bvar`) in the
range-**increasing** direction, where a stale-too-small range makes the short-circuit skip
a subtree that needed shifting — a silent wrong answer of exactly the SUB class.

**We adopt the memo route**, for these reasons rather than by inheritance.

## 4. Design

### P1 — `delta = 0` early-out (Layer 3)

`(shift 0 cutoff e) ≡ e` for all `e` and `cutoff`: shift's only effect is
`(expr-bvar (+ k delta))` on qualifying bvars, and `+ k 0 = k`. Guard at entry.
Independent of P2/P3, strictly cheaper, and the property is already model-asserted.

### P2 — cache key (Layer 1)

`(make-hash)` → `(make-hasheq)` at `driver.rkt:708-709`.

*Why this is correct, not merely faster*: exprs are immutable (`grep -c '#:mutable'
racket/prologos/syntax.rkt` → **0**), so an `eq?`-keyed memo of a pure function is sound.
It is strictly more conservative than `equal?` — it can only lose hits, never produce a
wrong one. The same soundness argument already ships on `main` for `nbe-scan-cache`
(`reduction.rkt:3727`, a `make-weak-hasheq` with exactly this justification written out).

*The honest risk*: `hasheq` loses structural hits. Our data shows they are worthless on
the accumulator workload, but other workloads (type-checking with repeated subterms) may
differ. **The full suite and the bench matrix are the gate**, not this argument. If
structural hits prove load-bearing elsewhere, the principled alternative is a memoized
cheap structural hash — *not* reverting to the O(N³) key.

### P3 — `loose-bvar-range` (Layer 2)

`loose-bvar-range e` = 1 + max free bvar index in `e`, or 0 if closed. Then
`(shift delta cutoff e)` is the identity whenever `(<= (loose-bvar-range e) cutoff)`,
and `(subst k s e)` is the identity whenever `(<= (loose-bvar-range e) k)`.

Memoized in a `make-weak-hasheq` keyed on node identity. Sound because exprs are
immutable, so the range is a pure function of identity — the *same* argument
`nbe-scan-cache` already relies on.

**Why a numeric range rather than a boolean predicate** (this is the load-bearing reason,
and it is why `contains-open-container?` cannot be reused): the question "is there a bvar
with index ≥ cutoff?" *depends on cutoff* and therefore cannot be memoized per term. The
numeric max is the cutoff-independent, memoizable form. Separately,
`contains-open-container?` answers a different question entirely — it calls
`(occ-walk e #f)`, where `#f` means "not inside a container yet, do not test bvars at
all", and the container boundary *resets* depth (`reduction.rkt:559-560`, `:568`,
`:599-600`). Neither subsumes the other.

**All four sites must be guarded**, including `:988` inside the per-arm `map`.

### Composition with SUB.3 (NbE)

They compose *positively* in general and *not at all* at the dominant site:

- **Positive**: the guard fires when a term is relatively closed. SUB.3a's NbE replaces
  `bvar0` with an **fvar**, and both walkers are identity on fvars
  (`substitution.rkt:31`, `:529`). So NbE opening strictly *increases* how often the
  guard fires.
- **The exception**: `nf` does **not** normalize `expr-reduce` arm bodies —
  `reduction.rkt:4395-4396` is `(expr-reduce (nf scrut) arms structural?)`, arms pass
  through untouched. So NbE never reaches reduce arms, which is exactly where 2 of the 3
  walks per element live. **Any argument of the form "NbE already closes bodies, so
  ranges are small" is false for precisely the dominant cost centre.**

Also worth recording: **no SUB commit modified `substitution.rkt` production code.** The
only change in the whole arc is `dd285174` (X.close), self-labelled "comment-only, no
behavior". `shift`/`subst` are behaviorally byte-identical to their pre-SUB state.

### Rejected: per-node perf counters

Considered and **rejected on measurement**. `testing.md` mandates preferring deterministic
counters over wall-clock, and the issue's own empirical table cites `shift-nodes` /
`subst-nodes`. But:

| strategy | cost/op |
|---|---|
| baseline (empty loop) | 1.04 ns |
| **parameter read + branch** (the existing `perf-inc-*` pattern) | **43.28 ns** |
| module-level `set!` (fixnum) | 3.07 ns |
| box `set-box!`/`unbox` | 2.36 ns |

Wiring the existing macro into `shift`/`subst` measured **26 → 69 ns/node, a 2.6×
pessimization of the walker being optimized**. The cheap alternatives are module-global
and therefore **not thread-local like a parameter** — counts would interleave under the
parallel batch runner and silently lie.

The `eq?`-identity assertions in §5 test the mechanism *exactly*, at zero production
cost, and fail on `main` today. They are a strictly stronger gate. (This also refutes
`performance-counters.rkt`'s own header claim of "~5ns" — a P4 doc-truth item.)

## 5. Test plan — failing-test-first, verified failing at `09d3566c`

| Gate | Assertion | At HEAD | Unlocked by |
|---|---|---|---|
| **G1** | `(shift 1 0 CLOSED)` is `eq?` to its input | **#f** | P3 |
| **G2** | `(shift 0 0 ANY)` is `eq?` to its input | **#f** | P1 |
| **G3** | `(shift 5 0 CLOSED)` is `equal?` to its input | #t | must **stay** #t |
| **G4** | `subst` keeps a closed argument `eq?` across a binder | **#f** | P3 |

Plus: a differential battery asserting the guarded walkers agree with the unguarded ones
over terms planting loose bvars at every depth and in every armed field position; and an
end-to-end scaling assertion with a generous threshold (pre-fix ratio is 8.5× per
doubling, post-fix should approach 2× — a threshold of 4× has large margin and is not
ambient-sensitive).

⚠ **A green full suite is not the gate here.** The suite is green today with all three
layers live.

## 5.1 Result

Same workload, same file, all results verified correct at every N:

| N | P0 baseline | after P2 | after P3 | total |
|---|---|---|---|---|
| 32 | 85 ms | 12 | **3** | 28× |
| 64 | 701 ms | 68 | **5** | 140× |
| 128 | 6 003 ms | 462 | **10** | 600× |
| 256 | 49 775 ms | 3 174 | **19** | **2 620×** |
| 512 | ~7 min (projected) | — | **39** | — |

**Scaling exponent 3.1 → 1.0.** Each doubling of N now doubles the time
(3→5→10→19→39), and `reduce_steps` doubles exactly alongside it (1059 → 2019 →
3939 → 7779 → 15459), so the semantics are unchanged and the per-step cost is now
constant. This is the property the issue asked for, reached by a different route
than it proposed.

### 5.2 The phantom regression — the most expensive mistake of this track

After P3 first landed, the full suite read **240.9 s against P2's 198.6 s**, and a
per-file diff looked conclusively like a real regression: +340 s of increases
against −8.8 s of decreases, spread broadly, top-5 files only 18% of the total.
That is the signature of a systematic slowdown, not noise.

It was not real. **The identical P2 code re-measured hours later came back
1629.3 s against its own earlier 1267.9 s — +28.5% pure ambient drift.** Against a
*contemporaneous* baseline (a worktree pinned at `cf1791ce`, built and run in the
same window), P3 is **−3.8%**, i.e. slightly faster.

`.claude/rules/testing.md` already says this in as many words — "sequential bench
invocations are NOT a valid A/B", "worktree-pin the baseline". The rule was quoted
early in this very session and then not followed: a P2 number from hours earlier
was compared against fresh P3 numbers. Four full redesign iterations were spent
chasing it:

| Variant | per-file total | vs the WRONG baseline | vs the RIGHT one |
|---|---|---|---|
| P3 compute-guard (first cut) | 1696.2 s | +24.3% | ≈ 0 |
| P3 consult-only guard | 1699.0 s | +24.5% | ≈ 0 |
| P3 armed + entry-only memo | 1685.5 s | +23.5% | **−3.8%** |
| P3 + `prunable?` gate | 1736.7 s | +27.3% | (worse; reverted) |

The tell was available early and was missed: **the number barely moved across
implementations spanning 441 → 131 → 26 ns/node.** A cost that is invariant to a
17× change in the thing supposedly causing it is not that cost. That should have
triggered "re-measure the baseline" long before it triggered a fourth redesign.

What the detour did buy, honestly: the final design is materially better than the
first cut on every micro (range computation 441 → 26 ns/node; one-shot shift
134 → 22 µs), and the `prunable?` experiment was measured and rejected rather than
kept on intuition. The design is better; the *reason* for changing it was wrong.

**One near-miss worth recording.** The first `compute-range` routed its catch-all
through `generic-range`, which dispatches on a *value* and sends any `expr?`
straight back to `loose-bvar-range` — where the memo entry does not exist yet.
Infinite recursion; the build succeeded and the test run hung. The fix is the
`fields-range` / `generic-range` split: one descends into a struct's FIELDS, the
other dispatches on a field's CONTENTS, so recursion strictly decreases. A
memoized walker whose fallback can re-enter itself on the same key is a hazard
worth naming — `compute-range` must never hand its own argument to the memo.

## 6. Capture gaps carried from the grounding audit

- **G1/meta coupling**: `expr-meta` is a closed leaf in both walkers
  (`substitution.rkt:49`, `:542`), so a range memo reports 0 for a term containing an
  unsolved meta. **Sound today** because the walkers are identity on metas. But
  DEFERRED's still-open META half of the containment defect proposes that walkers may
  need to follow meta *solutions* — which live off-node while node identity stays fixed.
  An `eq?`-keyed range memo would become **stale-by-construction** the moment that lands.
  These two work items are hard-coupled and must be sequenced deliberately.
- **G5/walker-family drift**: there are **four** walkers with this binder-crossing shape,
  already out of sync — `substS` (`sessions.rkt:85-86`, same O(N²) shape, outside
  `substitution.rkt`), `zonk-at-depth` (`zonk.rkt:557`), and `occ-walk`. Scope or defer
  explicitly.
- **Preserve the hard-failure property**: neither walker has a catch-all, so an
  unhandled node *hard-fails* rather than silently skipping — the opposite of the
  `pipeline.md` § Exhaustive Walkers failure mode. A leading fast-path arm keeps this.
  Adding a reflective fallback alongside would convert hard failures into silent passes
  and re-open the bug class. **Do not add one.**

## 7. Cross-references

- Issue [#58](https://github.com/LogosLang/prologos/issues/58) + the contributor's survey
  and PIR (branch-only): `2026-05-04_SUBSTITUTION_PERF_SURVEY.md`,
  `2026-05-04_LOOSE_BVAR_RANGE_PIR.md`
- [`2026-07-24_SUBSTITUTION_CONTAINMENT_DEFECT.md`](2026-07-24_SUBSTITUTION_CONTAINMENT_DEFECT.md) — the SUB arc
- [`2026-07-25_REL_T1_PIR.md`](2026-07-25_REL_T1_PIR.md) — Rel T1 close
- Grounding audit: workflow `wf_2eee350c-fd7` (7 facets + adversarial completeness critic)
- `.claude/rules/pipeline.md` § Exhaustive Walkers · `.claude/rules/testing.md` § benchmarking
