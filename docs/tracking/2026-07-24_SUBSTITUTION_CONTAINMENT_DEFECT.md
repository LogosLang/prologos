# Substitution Containment Defect — runtime collection values are treated as closed leaves

**Spin-out from Rel T1 POL.10** · 2026-07-24 · HEAD `f7d5b01b` · **Status: RULED (D)
(owner, 2026-07-24) — `expr-champ` is a CLOSED runtime map value; fix = NbE
open-the-binder. SUB.1 now-slice in progress.**

## Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| **R** | The §3 owner ruling: (D) closed runtime value vs (A) open AST container | ✅ **(D)** | owner, 2026-07-24; repro + API isolation + coordinates independently re-verified at `82109163` first |
| **SUB.1** | Now-slice: module/cache-crossing probe · tripwire at the 3 `nf`-persisting boundaries · regression tests | ✅ | `f19d6f56`. Probe (4 routes): **no surface def-store route exists today** — all blocked by independent def-seam typing gaps (see §6 note) ⇒ **no `.pnet` invalidation needed at SUB.3**; tripwire keeps that true if those gaps are later fixed. Depth-aware predicate (binder inventory = shift's 4 forms; reflective walk elsewhere); +12 unit (+ BUG-PIN flipping at SUB.3) + 5 E2E; suite 470/9003/0, zero false positives |
| **SUB.2** | `PLT_CS_COMPILE_LIMIT` in-tree measurement + adoption (owner-prioritized) | ✅ **ADOPTED** | Measured (§4.2): **TRANSFERS** — shift/subst ~830×/~745× micro; suite **211→173 s (−18%), all pass**; compile +17% hot core. **Adopted `6323587e`** (owner-blessed): runner-level putenv (run-affected-tests + bench-ab; subprocesses inherit; user override respected) + testing.md + CLAUDE.local.md notes; full CLEAN rebuild at the limit = 39 s (caveat discharged); wiring validated (suite invoked WITHOUT shell env → 470/0 in 192.7 s incl. from-clean test precompile, transducer 4.2 s). False-negative trap recorded (touch ≠ recompile — delete the .zo). **SUB.3 Pre-0 runs under this mode** |
| **SUB.3a** | The (D) fix CORE: NbE open-the-binder in `nf` (lam/Pi/Sigma; deterministic `#%nbe` depth-keyed fvars) + re-abstraction (generic-rebuild walker, spine-rebuild for capturing containers) + fast-path/verdict-memo + pp spine-brace display + the SUB.1 test flips | ✅ | **`7ea49168` — THE BUG IS FIXED** (repro: 6N/5N, 0 errors; validate ok; display `{:a x}` preserved). Gates: suite 470/9012/0 ×4; acceptance 0-err; lint clean. Perf (adopted mode, warm): 173→184.7 s = **+6.4% suite cost**; remaining lever = explicit-arm hot scan (close-phase option). Tripwire KEPT as the standing invariant guard (assertion, not dual mechanism); consumer audit discharged empirically (goldens + corpus green) |
| **SUB.3b** | Narrowing containment — the WIDER sibling: `narrow-subst-bvars` generic-rebuild fallback (+Pi/Sigma binder arms, +lam type field) AND `narrow-match` map/vec DECOMPOSITION (the second stacked gap: substituted spines fell to the `equal?` fallback vs champ targets) | ✅ | `036b59f7` — failing-repro-first (`box ?y = {:a 5N}` on a map-body defn returned NIL; now `'[{:y 5N}]`; vec/nested/multi-key verified; mismatch correctly nil). Sets DEFERRED, named (order-insensitive matching with logic vars = search). +7 tests incl. the Pi capture pin; all 6 narrowing test files green; suite 470/9019/0 |
| **SUB.3-scan** | Hot-scan (owner-directed): armed walk + reflective oracle as differential contract | ✅ | `8ec5e507` — **6.9× per walk** (armed 265µs vs reflective 1825µs / 11k nodes, interleaved same-process A/B, ~0 variance). 29-term differential battery (poison in every armed field position) pins armed ≡ reflective. Suite-level wall pair NOT provable tonight (ambient drift — late-session runs 203–212 s vs the tight 173/184.7 pairs earlier); **re-confirm the suite pair in a quiet window** (expected residual ~1-2 s vs the pre-scan ~8-11 s) |
| **SUB.close** | Doc-truth (§2 table verdicts now stale post-fix) · lesson promotions (un-arm'd-node 3rd data point; touch≠recompile; workload-poisoned-bench) · quiet-window suite pair · Rel T1 tracker/dailies fold | ⬜ | folds into Rel T1 X.close if owner prefers |

**Severity**: a **silent wrong answer in legal, zero-error user code** — an open de Bruijn
index escapes to top level as a typed value. Not a crash, not a type error.

**Provenance**: surfaced (not caused) by the Rel T1 POL.10 eager-`nf` trial (`cf454176`,
reverted); analysed by grounding workflow `wf_468a6129-447` (4 facets + 2 adversarial
critiques); reproduction and all coordinates below independently re-verified in the main
session at HEAD `f7d5b01b`.

---

## 1. The reproduction (verified, main session)

Two functions differing **only** in whether the lambda body is a map literal:

```prologos
ns p26verify

spec ctrl [Map Keyword <Nat -> Nat>] -> Nat
defn ctrl [p]  [[get p :f] 5N]
[ctrl (solve-one (is ?f [fn [y : Nat] [add y 1N]]))]

spec bug [Map Keyword <Nat -> [Map Keyword Nat]>] -> Nat
defn bug [p]  [get [[get p :f] 5N] :a]
[bug (solve-one (is ?f [fn [y : Nat] {:a y}]))]
```

```
1: 6N : Nat          ← control, CORRECT
3: ?bvar0 : Nat      ← an open de Bruijn index at top level, typed Nat
--- 0 errors ---
```

Causality is **isolated, not inferred**: at the Racket API level, with no relational
machinery, no logic vars and no typing, `(subst 0 <val> champ{:a bvar0})` returns its input
`eq?`-identical while the equivalent `expr-map-assoc` **spine** substitutes correctly. The
counterfactual closes it — implementing the missing arm makes the same reduction yield the
right answer, so **the wrong output is not producible under a corrected `subst`**.

## 2. The defect, exactly

`shift` and `subst` treat runtime collection values as closed, no-descend leaves:

- `substitution.rkt:264` — `[(expr-champ _) e]  ; Racket value, no de Bruijn vars`
  ← **a false assertion**, the only "design note" that ever existed
- `substitution.rkt:744` — `[(expr-champ _) e]` (no comment)

**Two distinct failure modes**, not one:
1. **`subst` drops the beta argument** — the substitution never reaches inside the champ.
2. **`shift` never renumbers** indices inside the champ, so `subst`-under-a-binder's
   `(shift 1 0 s)` leaves them pointing at the wrong binder — **silent variable capture**.
   (Corrected `shift` yields `bvar 1`; HEAD yields `bvar 0`.)

**It is a 6-container × 7-traversal family — ~37 arms**, not one arm. Containers:
`expr-champ`, `expr-hset`, `expr-rrb`, `expr-trrb`, `expr-tchamp`, `expr-thset`.

| Traversal | champ arm | Behavior / consequence |
|---|---|---|
| `shift` | substitution.rkt:264 | **SKIPS** → capture (all 6: :264/:279/:292/:336-338) |
| `subst` | substitution.rkt:744 | **SKIPS** → argument dropped (all 6: :744…:818) |
| `zonk` | zonk.rkt:308 | **SKIPS** → an unsolved meta inside a champ is never zonked |
| `zonk-at-depth` | zonk.rkt:787 | **SKIPS** |
| `default-metas` / `freeze` | zonk.rkt:1270 | **SKIPS** → un-collapsed `expr-num-lit` survives (probe-verified) |
| `nf` | reduction.rkt:3876 | **SKIPS** — while the `expr-rrb` twin at :3907-3909 **DESCENDS** |
| `uses-bvar0?` | pretty-print.rkt:1148 | **SKIPS** → a dependent Pi prints as a non-dependent arrow |
| `occurs?` | unify.rkt:234-250 | **SKIPS** (halts at the champ node's Racket vector) → unsound occur-check |
| `conv-nf` | reduction.rkt:4051-4069 | **SKIPS** → definitionally-equal maps judged unequal |
| `narrow-subst-bvars` | narrowing.rkt:919 | **SKIPS**, and is **wider** — drops bvars for map/record nodes even as *spines* |
| `whnf` | :3480 catch-all | correct-by-accident (a champ *is* WHNF); perf-only cost |
| `pp-expr` | :454-465 | **DESCENDS** |
| `pnet-serialize` | :122/:497 | **DESCENDS** (added by POL.10, 2026-07-24) |
| SRE `ctor-desc` | — | no descriptor for any runtime collection value |

**The display/transform asymmetry is why this stayed hidden**: every *transforming* layer
skips, and the only layer that *descends* is pretty-print — so the bad term is faithfully
printed by a layer that never had a chance to fix it.

### The decisive historical evidence

`nf`'s `expr-rrb` arm was **changed from identity to descending six days after CHAMP
landed** (`9fc669bb`, "Stages D+F", vs the CHAMP introduction `f299f6f1`), carrying the
comment *"Normalize all elements inside the RRB tree"*. The identical fix was **never**
applied to `expr-champ` or `expr-hset` in `nf`, and never to **any** of the six containers
in `shift`/`subst`/`zonk`/`uses-bvar0?`/`occurs?`/`conv-nf`. The containment discipline was
recognised and repaired at exactly **one** site, ad hoc.

### There is no invariant to defend

`tests/test-substitution.rkt` (184 lines) contains **zero** occurrences of `champ`, `Map`,
or `map-assoc` — verified. The invariant existed only as the (false) comment.

## 3. Root cause, and the fork that needs an owner ruling

The proximate defect is the missing arms. The **root** is that `nf` normalizes an **open**
body: `reduction.rkt:3544` — `[(expr-lam m t body) (expr-lam m (nf t) (nf body))]` recurses
**without opening the binder**, which no dependent type checker does. That is what mints an
open champ in the first place.

**✅ RULED (D) — owner, 2026-07-24.** `expr-champ` is a CLOSED runtime map value; the
fix is the NbE open-the-binder shape below. Recorded fork, for the register:

- **(D) A CLOSED runtime map value** (the F1b RETIRED-LOUD position, typing-core.rkt:3149-3157:
  a champ is "a RUNTIME map value, born only in reduction, after type-check"). Then open maps
  must stay as **spines** (`expr-map-assoc`), which the pipeline already traverses correctly,
  and the fix is to stop minting champs under binders + open the binder during `nf`
  (**NbE**: substitute a fresh **fvar**, which `shift`/`subst` are *already* identity on at
  substitution.rkt:31/:511 — so the closed-leaf invariant becomes **true rather than
  enforced**, and `conv-nf`'s under-binder incompleteness is fixed in the same stroke).
  Honest costs: no fresh-fvar generator exists in `reduction.rkt`; re-abstraction needs
  **one** champ-descending function (one function written knowing the invariant beats
  retrofitting 37 arms); and every `nf` consumer must be audited for whether it persists or
  merely displays/compares.
- **(A) An OPEN AST container**, first-class under binders. Then it is **all ~37 arms**, via
  ONE named `champ-map-exprs` on the existing `record-map-field-types` /
  `validate-map-exprs` pattern (syntax.rkt:690-699/:731) — **shifting KEYS too** (verified
  open-capable: `nf(lam k. assoc {} k 7)` → `{x 7N}`), rehashing with `equal-hash-code`
  (**never** the stored hash), **not** in `champ.rkt` (shared with the propagator network's
  `cell-id-hash`, champ.rkt:443-450), plus an `eq?`-preserving closed fast path. This
  contradicts the F1b ruling and makes `expr-champ` a redundant second representation of a
  spine the pipeline already handles.

**Recommendation: (D)**, because it makes the invariant true instead of policed, and fixes
`conv-nf` as a side effect. But it is a semantics decision about a core representation and
belongs to the owner.

## 4. Staging

1. **NOW — days-scale, inside the Rel T1 POL cluster** (no design ruling needed):
   - **The failing regression tests** (§5) — lock the finding in before any redesign.
   - **A tripwire at the three `nf`-persisting boundaries** — `reduction.rkt:570`, `:698`
     (answer-row `champ-insert`) and `:1458` (validate `base-ok`) — the entire proven
     wrong-answer surface, on cold paths, raising a distinguished exception on the POL.4
     `exn:prologos-solve` pattern (relations.rkt:1584) so the command boundary reports it
     and the run continues. Converts silent-wrong into loud-refuse.
     ⚠ **NOT at `shift`/`subst`** (no srcloc, no command context; `driver.rkt:1408` catches
     only `exn:prologos-solve?` by explicit design) and **NOT at the mint** (it would fire
     on correct display code — `driver.rkt:689-691` legitimately nf's an eval result, so
     `[fn [a : Nat] {:x a}]` mints an open champ for display today).
2. **`PLT_CS_COMPILE_LIMIT` — MEASURED IN-TREE (SUB.2, 2026-07-24). The claim TRANSFERS,
   and then some.** All measured on this machine, same evening, interleaved baseline:
   - **Interpreter fallback CONFIRMED**: `shift` per-call cost is **position-INDEPENDENT**
     (arm 1 `expr-bvar` 85µs ≈ late-arm `expr-int` 87µs) — per-call interpreter overhead,
     not linear dispatch. Matches the audit's synthetic ~100µs.
   - **Micro (11k-node tree walk)**: shift **1.27 s/call → 1.52 ms/call (~830×)**;
     subst **1.31 s → 1.76 ms (~745×)** — per-node 115µs → 0.14µs.
   - **Full suite**: **211.0/212.0 s → 173.0/173.8 s (−18% wall, all 470 files pass,
     two runs each side)**. Tail-gated by two ~70s files, so aggregate CPU saving is
     larger than the wall delta; biggest per-file: `test-transducer-01` 15.1→3.4 s
     (**4.4×**). `test-validate` 67→63 s; `test-rel-t1-typed-rows` 75→72 s.
   - **Compile cost**: hot-core cascade (substitution/reduction/typing-core/qtt/unify/
     elaborator/zonk + dependents) 22.4 s default → 26.1 s at limit=1e6 (**+17%**);
     substitution.zo 93→102 KB. Cheap.
   - ⚠ **Methodology trap that cost a false negative first**: `touch FILE && raco make`
     does NOT recompile (SHA short-circuit) — the first A-leg silently benched the OLD
     .zo. A/B legs must **delete the `.zo`/`.dep`**, not touch. (Confirmed twice: the
     substitution A-leg and the isolated clone leg.)
   - **State**: tree RESTORED to default-compiled (verified: suite 212.0 s all-pass,
     per-file timings back to baseline). **Adoption is the owner's call** — flagged at
     the 2026-07-24 checkpoint with the wiring options (runner-level `putenv` + doc
     line vs env-only). It is also the precondition for any sound Pre-0 on this fix
     (demonstrated: rankings DO invert once compiled).
3. **Spun-out track for the real fix** (D1–D3 under ruling (D), or the 37-arm sweep under
   (A)). Sequence after the compile-limit measurement. Scope in or explicitly defer the two
   adjacents: **`narrow-subst-bvars`** (narrowing.rkt:881-919) is **wider** than champ and
   is *not* fixed by any champ-representation change; and already-written `.pnet` artifacts
   may need invalidation.

## 5. Test plan

- **Unit, MUST FAIL today** — `tests/test-substitution.rkt`, adding
  `(only-in "../champ.rkt" champ-empty champ-insert champ-entries)`. Assert
  `(subst 0 (expr-int 42) champ{:a bvar0})` has entries `((:a . 42))` and
  `(shift 1 0 champ{:a bvar0})` has `((:a . bvar1))`. Mirror for `expr-hset` and `expr-rrb`.
  Template: `tests/test-validate-node.rkt:163-172`, which already carries a
  `;; ---- pipeline-walker contract ----` section stating this exact kind of contract.
- **E2E, MUST FAIL today** — the §1 `p26verify` shape, asserting `6N`/`5N` and **no
  `?bvar` substring**. `grep '?bvar'` over all `.golden` returns zero today, so that string
  is a clean canary.
- **Contract test** — the champ-descending helper (or the mint guard) touches exactly the
  expr slots, keys *and* values, and returns its input `eq?`-identical when nothing changed.
- **Companion (only if (D) lands)** — a pretty-print test that a closed-key `map-assoc`
  spine still renders as `{…}`; otherwise every map-returning `defn` display regresses from
  `{:x x}` to `[map-assoc {} :x x]`.
- ⚠ **Do NOT treat a green full suite as the gate** — the suite is green today with the bug
  live (470 files / 8991 tests / 0 failures at `f7d5b01b`).

## 6. What widens the blast radius

It is already reachable, so this is about scope, not activation. Each of these removes a
barrier **without touching `substitution.rkt`**:

- **Re-attempting the eager `def`-`nf` flip** — tried once, reverted (`cf454176`); its
  collisions *were* this bug.
- **Rel T2 "The Fact Store"** — persisting normalized rows is exactly the `nf`-persisting shape.
- **BSP-LE Track 3** — on-network row computation.
- **Rel T1 typed-row ergonomics / CIU T6 Path Selection** — removing the `spec`-annotation
  requirement that currently makes the repro look contrived.
- **PReduce e-graph** — normalizes under binders by construction; this defect is a **hard
  blocker** there.

**Named open question — CLOSED (SUB.1 probe, 2026-07-24, main session @ `82109163`)**:
POL.10's `champ-sentinel` (pnet-serialize.rkt:122/:497) already round-trips champs into
`.pnet`, and the audit verified a **def-stored open champ** via `validate`. Probe result:
**no legal surface route def-stores the poisoned shape today** — four routes tried, all
blocked by *independent* def-seam typing gaps: `def := (solve-one (is ?f [fn …]))`
(annotated AND bare) → "Expression is not a valid type" (function-typed row field);
`def := [validate S {…}]` → "Multiplicity violation" (the POL.5/F1a.2 un-arm'd-node
class, **3rd data point**); `def := (solve-one (= ?f [fn …]))` → "not a valid type".
The inline apply (no def) reproduces `?bvar0` but is within-command transient. Since
`.pnet` serializes only module-level state and all caches were regenerated at
PNET_VERSION 3 (POL.10), **the wrong answer does NOT cross a module boundary at HEAD ⇒
no cache invalidation at SUB.3**. Caveat: empirical (4 routes), not a proof — the SUB.1
tripwire is what makes it structural, and it must land BEFORE the def-seam typing gaps
are ever fixed. (Those gaps are themselves adjacent findings for the POL cluster.)

## 7. Cross-references

- Surfaced by: Rel T1 POL.10 — design
  [`2026-07-19_REL_T1_RELATIONAL_USABILITY_DESIGN.md`](2026-07-19_REL_T1_RELATIONAL_USABILITY_DESIGN.md)
  §8 POL.10; commits `cf454176` (the reverted trial, with the three-collision post-mortem)
  and `095d8bc5` (the landed whnf resolution).
- Session handoff: [`handoffs/2026-07-24_REL_T1_POL_ARC_handoff.md`](handoffs/2026-07-24_REL_T1_POL_ARC_handoff.md) §4.2, §5.
- Grounding workflow: `wf_468a6129-447` (4 facets + reachability probes + 2 adversarial critiques).
- Pipeline discipline this violates: `.claude/rules/pipeline.md` § New AST Node (the
  containment/traversal checklist) — a container node whose traversal contract was never settled.
