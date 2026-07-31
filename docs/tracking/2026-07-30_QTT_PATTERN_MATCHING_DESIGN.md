# QTT: multiplicity checking for pattern matching

**Status**: P1 ✅ · P2 ✅ · P3 ✅ · P4 ✅ · P5 ✅ · X.close ✅ — **COMPLETE**. Created
retroactively at P3 (the work arrived as a Suggested-task chip, not from a
Stage-3 design; P1/P2 landed before this doc existed and their sections are
written from their commits).

**Series**: QTT — in `MASTER_ROADMAP.org` § QTT since P3 close.

**No PIR** (owner ruling, 2026-07-30): not a full designed track. `workflow.md`'s
objective PIR gate is for tracked Stage-3 designs; the per-phase VAGs (§6, §9)
and these close notes serve instead.

## 0. What this track changed, in one place

| | Before | After |
|---|---|---|
| `match` / multi-clause `defn` | **no multiplicity checking at all** | checked |
| fio's `-1>` handles (the only linear API) | declared linear, never verified | verified, and they hold |
| linear var used once per branch | **rejected** (m1+m1 = mw) | accepted |
| linear var dropped on some branches | accepted (**fd leak**) | rejected |
| the violation message | 3 placeholder lines, `Variable:` = the whole body | names the resource, declaration, what happened, and why |
| defs containing Vec / Fin / a foreign value | **QTT skipped entirely for the whole def** | checked (guard deleted) |

Suite 9418 → 9473, 475 files, 0 failures throughout. Zero stdlib fallout.

After P5, multiplicity checking is unconditional **at the def seam**. Bare
top-level expressions, `check` commands, foreign decls and cache-hit loads remain
outside the gate — not regressions, but the claim is scoped deliberately.

## Summary

`contains-unsupported-qtt?` (driver.rkt) returned `#t` for `expr-reduce`, and
both driver gates used it to skip `checkQ-top`. So every `match` and every
multi-clause `defn` — the primary dispatch form per `prologos-syntax.md` —
escaped multiplicity checking entirely, and `grep -c expr-reduce qtt.rkt` was 0.
The stdlib's only linear API (fio's `-1>` handles) is match-implemented, so the
one place linearity was declared was the one place it was never checked.

Fixing that exposed a second, independent defect: eliminator branches were
combined with semiring ADDITION, so a linear variable used once in each branch
became `m1 + m1 = mw` and was rejected — though only one branch runs.

## Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| P1 | `mult-join` + `join-usage`; branch alternation at 5 eliminator sites | ✅ | `966226cf` — suite 9444/475/0 |
| P2 | `checkQ` `expr-reduce` arm + beta-redex arm; guard entry removed; PNET 6→7 | ✅ | `9fbbc90f` — suite 9445/475/0, zero fallout |
| P3 | Linear-per-path: branch-agreement guard at `m1` positions (**owner ruling: option 3**) | ✅ | `3a4d521a` — suite 9455/475/0; VAG produced `join-branches` |
| P4 | Precise diagnostic naming the dropped resource | ✅ | `e7fbd2ba` — suite 9460/475/0; VAG caught the message-only rendering trap |
| P5 | Retire `contains-unsupported-qtt?` — arm the 8 remaining nodes, delete the guard | ✅ | `9f0ddede` (arms) + `7b14fffe` (deletion + PNET 7→8) — suite 9473/475/0 |
| X.close | Roadmap row + DEFERRED sweep + close notes | ✅ | **NO PIR** (owner, 2026-07-30): this is not a full designed track — it arrived as a chip and the design doc is retroactive. `workflow.md`'s objective PIR gate is for tracked Stage-3 designs; close notes suffice here. |

## 7. P4 mini-design (step 1)

**Design reference**: §5.P3 ("the benefit that does NOT land here").

**Obligation carried**: option 3 was argued partly on being *able* to name the
dropped resource. P3 shipped the correctness half; P4 owes the message half.

**What the audit changed about the plan** (§8): the plan of record assumed
`bu`/`tu-error` carry no payload, so a protocol refactor or a post-hoc walk was
needed. The audit found `multiplicity-error` **already has** `variable` /
`declared` / `actual` fields that already render as three lines — they are simply
filled with the string literals `"declared"` and `"actual"`, and `variable` gets
the entire pretty-printed body. So P4 is not a refactor: it is computing real
values for fields that already exist. No protocol change at all.

**Principles in play**: *One derivation, two consumers* — the explainer must
mirror the typing rules it explains, so it lives in `qtt.rkt` beside them
(precedent: typing-core exports `select-project` / `seal-missing-required`
purely for typing-errors hints). *Completeness* — the fields render whether or
not they are meaningful, so leaving placeholders is a visible defect, not a gap.

**Mantra check**: neutral again, and for the same reason as P3 — a pure
analysis over values already in hand, on the already-failing path only. No new
state. Recording it rather than claiming a pass.

**Drift risks named BEFORE coding**:
1. **Re-deriving the branch expected-types in typing-errors** — the boolrec arm
   checks branches against `(expr-app mot (expr-true))` / `(… (expr-false))`, the
   reduce arm against a `shift`ed expected type. Re-deriving those in the error
   module is exactly the twin drift `pipeline.md` warns about. The explainer goes
   in `qtt.rkt`.
2. **LSP code regression** — `error->code` maps on message text, `type.?mismatch`
   FIRST and `multiplicity` later. A reworded message that gains "type mismatch"
   or loses "multiplicity" silently changes the code. Keep the substring.
3. **Names may not exist** — `recover-name-map` is best-effort and one of the two
   driver call sites passes no names at all. The message must degrade to
   something useful (the binder's TYPE) rather than to an index or "".
4. **Claiming a cause we did not establish** — the same failure mode as the
   branch-result diagnostic earlier: if the explainer cannot prove a specific
   cause it must return #f and let the generic message stand.
5. **Scope creep into non-multiplicity errors** — the walk is for
   `checkQ-top/err` only.

## 8. P4 mini-audit (step 2)

| Fact | Coordinate |
|---|---|
| The producer, with hardcoded literals | `typing-errors.rkt` `checkQ-top/err` — `"declared"`, `"actual"`, and `variable` = the whole body |
| The struct — fields ALREADY EXIST | `errors.rkt:71` `(struct multiplicity-error prologos-error (variable declared actual))` |
| It ALREADY renders 3 dedicated lines | `errors.rkt:170` — `Variable:` / `Declared multiplicity:` / `Actual usage:` |
| Names reach only ONE of two doors | `driver.rkt:2131` passes `(recover-name-map)`; `driver.rkt:1913` passes neither loc nor names |
| The real gate is the lambda arm | `qtt.rkt` — `(compatible effective-m (uhead u))`; `check-all-usages` is vacuous in production (both driver sites pass `ctx-empty`) |

Consequence for the design: the explainer reproduces the lambda arm's own test —
peel `(lam, Pi)` pairs, and at the level where the BODY checks cleanly but the
binder's `uhead` is incompatible, that binder is the cause. Where the body itself
fails, recurse. At a non-lambda body, look for a linear branch disagreement.

### Before / after

```
;; every multiplicity violation, before P4:
Multiplicity violation
  Variable: [fn [x :1 <Nat>] 0N]        ← the whole body, not a variable
  Declared multiplicity: declared        ← literally the word "declared"
  Actual usage: actual

;; after P4:
Multiplicity violation — the parameter of type Box is declared `:1` (linear)
  but is not used. A linear value must be consumed; nothing may drop it.

Multiplicity violation — a linear value must be used exactly once on EVERY path,
  but the branches disagree: it is used once in one branch and not used in
  another. Dropping it on a path does not release it (there is no implicit
  destructor), so consume it in every branch.
```

## 9. P4 Vision Alignment Gate (step 5) — two columns

### (a) On-network?

| Catalogue | Challenge |
|---|---|
| Pure analysis over values in hand; runs only on the already-failing path; no new state. | **Was a mutable shortcut available and rightly refused?** Yes — the guard could have recorded the offending position in a parameter as it ran, which would have been less code. That is `make-parameter`-shaped off-network state on a hot path for the benefit of a cold one, and the red-flag list names it. The post-hoc recomputation is strictly more aligned and costs nothing measurable (it runs once, on a failure). |

### (b) Complete?

| Catalogue | Challenge |
|---|---|
| All four violation classes now explained; fields filled; suite 9460/475/0; acceptance 5/5. | **Did the benefit reach the USER, or only the struct?** This is where the phase nearly failed. The first draft filled `variable`/`declared`/`actual` correctly and left the message as bare "Multiplicity violation" — and `tools/run-file.rkt` (plus the ~11 test files copying its `result->string`, and the `;;N=>` acceptance harness) print the MESSAGE ALONE. The improvement was invisible in exactly the surface users see. Caught by running the probe rather than trusting the struct. Detail now lives in the message, with the fields still filled for `format-error`/LSP. **Shape without benefit, caught at the gate rather than after it.** |

### (c) Vision-advancing?

| Catalogue | Challenge |
|---|---|
| The diagnostic now names the resource, the declaration, what happened, and why it is wrong. | **Is anything asserted that was not established?** The explainer returns #f rather than guessing, and the pre-P4 message is retained verbatim for that path — the same contract as the branch-result hint earlier in the session. One honest gap: the message says "the parameter of type T" rather than a NAME, because `recover-name-map` is best-effort and one of the two driver doors passes no names at all. Naming the type is what can be *proven*; inventing a variable name would be the failure mode this project keeps re-learning. |

### (d) Drift-risks-cleared?

| Risk (named in §7 before coding) | Outcome |
|---|---|
| 1. Re-deriving branch expected-types in typing-errors | Avoided by construction — `explain-qtt-failure` lives in `qtt.rkt` beside the arms. |
| 2. LSP code regression | Did not materialize, and is now **test-pinned** (`qtt-msg/still maps to LSP code E1003`) rather than left to a comment. |
| 3. Names may not exist | **Materialized** — handled by naming the TYPE instead of a variable. See (c). |
| 4. Claiming an unestablished cause | Did not materialize; `#f` → generic message, retained verbatim. |
| 5. Scope creep beyond `checkQ-top/err` | Held. |

**Not covered by the named risks** — the message-only rendering trap (b). It was
in the earlier grounding but I did not carry it into §7's risk list, and it is
the one that nearly shipped. The lesson generalizes past this phase: *a
diagnostic improvement is not done until it is read back through the renderer the
user actually gets.*

## 1. The ruling (owner, 2026-07-30)

`m0 ⊔ m1` was surfaced as an owner decision rather than defaulted. **Option 3
confirmed**: linear-per-path semantics, implemented as the lenient lub PLUS a
branch-agreement guard at linear positions — not by redefining the join.

Owner rationale: *"linear types should always be linear... there's a correctness
concern otherwise."*

Supporting argument recorded at the time: linear logic's additive rule types both
branches under the same context; Idris 2 (the canonical QTT implementation) reads
it the same way. The point that makes it stronger *here* than in an affine
language: Prologos has **no implicit destructor**, so dropping a `Handle` on a
path does not close it — it leaks the fd. "Affine per path" is not a softer
discipline here, it is precisely the bug `-1>` exists to prevent.

Why not redefine the join to `m0 ⊔ m1 = mw` (option 2): it stops being the lub of
the tree's own `mult-leq` order, which breaks `m0` as the identity and silently
invalidates `join-usage`'s null shortcuts; it conflates "dropped on a path" with
"used many times"; and the rejection surfaces through a message that structurally
cannot say what went wrong.

### Evidence the ruling rests on (verified at `9fbbc90f`)

```prologos
;; correct linear program — handle closed on EVERY path
always-close … (boolrec … [fio-close h] [fio-close h] c)   ;; pre-P1 REJECTED → now accepted
;; leak — closed on one branch, silently dropped on the other
maybe-close  … (boolrec … [fio-close h] unit c)            ;; accepted, and still accepted after P1
```

Before P1 the pair was **inverted**. P1 fixed the false rejection; P3 closes the
leak.

## 2. P1 (✅ `966226cf`)

`mult-add` is semiring addition and PPN 4C Phase 2 deliberately analysed it,
accepting `:usage` as a commutative MONOID and recording "REFUTE idempotence".
**That finding stands** — it was about the tensor. ALTERNATION is a second
operation the tree had no operator for, so `:usage` carries both; the D2 note was
amended in place, not overturned, and the join is arm-local (a typing-rule
combinator, NOT a second SRE merge relation).

`mult-join` is the lub of `mult-leq` and differs from `mult-add` in **exactly one
cell** (`m1 ⊔ m1 = m1`) — which makes the swap monotone-permissive: it can only
accept more programs, never reject more.

`natrec` deliberately excluded: base and step are not mutually exclusive
alternatives (step runs 0..n times), so joining would UNDER-count. Its own
unsoundness (step counted once) is filed separately.

## 3. P2 (✅ `9fbbc90f`)

`checkQ` `expr-reduce` arm: usage = `U_scrutinee + JOIN over arms`, with
`reduce-arm-ctx` / `reduce-scrutinee-decompose` factored out of
`check-reduce-structural` and exported so the QTT side reuses the type checker's
own derivation (one derivation, two consumers).

Also a `checkQ` beta-redex arm — `let` desugars to `(app (lam …) arg)` and
`checkQ` had none, so a let-bound `match` would have reached `inferQ` (no reduce
arm) and reported a spurious violation.

`PNET_VERSION` 6→7 in the same commit: on a cache hit the driver deserializes and
never elaborates, so the QTT gate does not run — without the bump a module that
should now fail keeps loading from cache and the suite goes green on a warm tree
while a cold clone fails.

## 4. P3 mini-design (step 1)

**Design reference**: §1 (the ruling) and §5.P3 below. No prior Stage-3 doc.

**Obligations carried**: the owner ruling on `m0 ⊔ m1`; the DEFERRED entry
"OWNER DECISION — `m0 ⊔ m1`" closes with this phase.

**Principles in play**:
- *Correct-by-Construction* — the guard is a structural property of the typing
  rule, not a post-hoc check bolted on.
- *Completeness over deferral* — but see the honest split in §5.P3: the
  correctness benefit lands here, the DIAGNOSTIC benefit does not, and that is
  named rather than implied.
- *Single source of truth* — the guard reads declared multiplicities from `ctx`,
  the same place `compatible` reads them; no second table.

**Mantra check** (`All-at-once, all in parallel, structurally emergent
information flow ON-NETWORK`): honestly, **neutral, not passing**. `qtt.rkt` is
imperative off-network type checking in its entirety; this phase adds a pure
predicate over values already in hand — no new parameter, no new mutable state,
no new off-network *state*. It neither advances nor retreats from the mantra.
Bringing typing on-network is PPN's `typing-propagators.rkt` work, not this
phase's, and claiming a mantra "pass" here would be cataloguing.

**Drift risks named BEFORE coding** (checkpoints for step 3 / VAG (d)):
1. **Position misalignment** — the guard compares `ctx` position *i* against
   usage position *i*. If a usage vector is not trimmed back to the ambient ctx
   depth, the comparison is against the WRONG variable and rejects spuriously.
   `join-usage`/`add-usage` silently pad, so nothing catches it locally.
2. **Over-reach beyond linear positions** — applying agreement at `mw` positions
   would reject ordinary code en masse. The guard must fire ONLY where the
   declared multiplicity is `m1`.
3. **`natrec` must not receive the guard** — base and step are not alternatives;
   every execution reaches base exactly once, so there is no agreement question.
4. **The reduce arm's permissive fallback** — an unanalysable arm contributes no
   usage, so it also cannot be checked for agreement. A leak could hide there.
   Keep permissive (the alternative newly rejects over a lookup gap) and say so.
5. **Scope creep into the diagnostic** — making the message name the dropped
   resource requires threading failure info out of `bu`/`tu-error`, a real
   protocol refactor. Resist; file as P4.

## 5. P3 mini-audit (step 2) + design

### 5.1 Audit — the sites (verified at `9fbbc90f`)

| Site | qtt.rkt line | Function | Failure form |
|---|---|---|---|
| `boolrec` | 477 | `inferQ` | `(tu-error)` |
| `p8-if-nar` | 837 | `inferQ` | `(tu-error)` |
| `p16-if-nar` | 927 | `inferQ` | `(tu-error)` |
| `p32-if-nar` | 1087 | `inferQ` | `(tu-error)` |
| `p64-if-nar` | 1177 | `inferQ` | `(tu-error)` |
| `expr-reduce` arms | 2448 | `checkQ` | `(bu #f (zero-usage n))` |

Five sites are in `inferQ` and return `tu`; one is in `checkQ` and returns `bu`.
So the guard must be a **plain predicate**, with each site producing its own
failure form — it cannot itself return a result carrier.

### 5.2 Audit — the parallelism the guard depends on

`ctx-extend` (syntax.rkt:1456) is `(cons (cons type mult) ctx)`, i.e. front-cons,
so **usage index 0 ↔ `ctx` car ↔ innermost binder**. `cdar` (qtt.rkt:207) reads a
position's declared multiplicity, exactly as `check-all-usages` does. The guard
walks `ctx` and the two usage vectors in lockstep and therefore inherits drift
risk 1 — mitigated by requiring equal lengths and declining (not rejecting) if
they diverge.

### 5.3 Design — `branches-agree-on-linear?`

```
(branches-agree-on-linear? ctx u1 u2) → boolean
  for each position i:
    declared = (cdar ctx_i)
    if declared is m1 and u1[i] ≠ u2[i] → #f      ;; one branch consumes, the other drops
  otherwise → #t
```

- Fires ONLY at `m1` positions (risk 2). `m0` disagreement is already caught by
  `compatible m0 m1`; `mw` positions are free by definition.
- Equality, not "not one-of-{m0,m1}": `m1` vs `mw` is also a disagreement, and
  while the join would catch it downstream via `compatible m1 mw`, catching it
  here is precise and cheap.
- Length divergence ⇒ **decline** (return `#t`) rather than reject, so a
  bookkeeping bug cannot manifest as a spurious linearity error (risk 1).
- N-ary (reduce): check each arm against the running accumulator before joining.
  Transitivity holds because a disagreement with the accumulated value is a
  disagreement with some earlier arm.

### 5.P3 The benefit that does NOT land here (VAG (b), stated up front)

Option 3 was argued partly on being *able* to produce a diagnostic naming the
dropped resource. This phase delivers the **correctness** half — the right
programs are rejected — and NOT the message half: `bu`/`tu-error` carry no
payload, so the rejection still surfaces as the generic "Multiplicity violation"
whose declared/actual fields are hardcoded literals (typing-errors.rkt).

Naming that plainly rather than letting "option 3" imply the whole package.
P4 (deferred) is the post-hoc walk pattern — the same shape as the branch-result
diagnostic earlier in this session: on an already-failing `checkQ-top`, re-walk
to find the disagreeing position and name the variable.

## 6. P3 Vision Alignment Gate (step 5) — two columns

Column 1 alone is rationalization. Column 2 is where drift surfaced — and it
changed the implementation twice.

### (a) On-network?

| Catalogue | Challenge — could this be MORE aligned? |
|---|---|
| No new off-network state: a pure predicate over values already in hand. No parameter, no mutation. | **`qtt.rkt` is off-network in its entirety — is this phase entrenching it?** It adds a check at 6 sites. Two things came out of pushing on this: (1) the guard is not an ad-hoc comparison, it is the statement *the join must be EXACT at linear positions* (`u1 ⊔ u2 = u1 = u2` there) — a side condition on the lattice operation, which is how it should be expressed when typing moves on-network. Recorded in the code so the framing survives. (2) **the guard and the join were two separate calls at 6 sites** — discipline a 7th eliminator could forget, silently restoring affine-per-path for that construct with a green suite. **Fixed**: `join-branches` bundles them, so there is no way to join branch usages without the linear check. Correct-by-construction rather than maintained-by-care. |

### (b) Complete?

| Catalogue | Challenge |
|---|---|
| Guard at all 6 alternation sites; 5 new tests; suite 9455/475/0; acceptance 5/5. | **Shape without benefit?** Partly, and named up front rather than discovered later: option 3 was argued on being *able* to name the dropped resource, and this phase delivers only the **correctness** half. `bu`/`tu-error` carry no payload, so the rejection still reads "Multiplicity violation" with hardcoded declared/actual fields. That is invisible deferral unless stated — so it is §5.P3, tracker row P4, and a DEFERRED entry, not a footnote. |

### (c) Vision-advancing?

| Catalogue | Challenge |
|---|---|
| Linear types are now actually linear: the fio leak that type-checked at HEAD is rejected. | **Which pragmatic shortcut is being rationalized as permanent?** The reduce arm's permissive fallback. P2 justified it as "can miss a violation, cannot invent one" — true, but **P3 raises its stakes**: a skipped arm is never checked for agreement either, so a linear resource dropped on an unanalysable arm is *precisely* the leak P3 exists to reject, hiding in the one path that does not look. Still the right trade, but it is a hole, not a rounding error. Comment sharpened in place to say so; filed. |

### (d) Drift-risks-cleared?

| Risk (named in §4 before coding) | Outcome |
|---|---|
| 1. Position misalignment (ctx vs usage) | Did not materialize. Guard declines on length divergence; the reduce arm's length assertion already guarded the join. |
| 2. Over-reach beyond linear positions | Did not materialize — and is now **test-pinned** in both directions (`the guard fires ONLY at linear positions`, `the-same-shape-UNRESTRICTED-is-still-fine`). |
| 3. `natrec` must not receive the guard | Held; verified by grep (0 occurrences in its arm), not by memory. |
| 4. Permissive fallback | **Materialized** as a real hole — see (c). Named and documented rather than silently carried. |
| 5. Scope creep into the diagnostic | Resisted; became tracker row P4. |

**Did the risks cover more than correctness?** Partly. There is no perf axis
here worth a microbench — the guard is one lockstep walk over vectors already
built, on a path that only runs during type checking — but that is an argument,
not a measurement, and it is recorded as such rather than as a claim.
