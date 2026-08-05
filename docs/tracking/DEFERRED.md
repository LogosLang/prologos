# Deferred Work

Single source of truth for all deferred work across the Prologos project.
Items are organized by topic. When work is deferred during implementation,
add an entry here immediately.

**Principle**: Completeness over deferral. Items here should be genuinely
blocked on unbuilt infrastructure or uncertain design — not effort avoidance.
See `docs/tracking/principles/DEVELOPMENT_LESSONS.org` § "Completeness Over
Deferral".

**Completed items**: Moved to `DEFERRED_COMPLETE.md` during staleness sweeps.

**Last consolidated sweep**: 2026-03-20 (PUnify Parts 1-2 complete, 7308 tests, 377 files).

---

## LET track residuals (X.close sweep, 2026-07-31 — track COMPLETE, `feb79740`)

Three small items survive the track, none blocking, all verified at HEAD:

1. **`let` inside a BRACKETED `fn` body fails with a misleading message.**
   `[fn [n : Int] let k := 4 [int+ n k]]` → "fn: all parameters except body
   must be bare symbols or a binder" — the let line is consumed as fn
   PARAMETERS (brackets suspend indent grouping, so the fn's bracket swallows
   the tokens). Per-command since LET P1 (it was a whole-file abort), but the
   form does not work and the message names the wrong thing. Workaround: use a
   parenthesized `(let x := 4 body)` or hoist. Found by the P0 grounding
   (unfiled then); the fix wants fn-side layout work, not let-side.

2. **The 2-line forgot-body shape gives a mediocre error.** `let x 4 / y 5`
   (one continuation line — below the aligned discipline's ≥2 activation)
   falls to the legacy shorthand as `(let x 4 (y 5))`, body = apply y to 5 →
   "Unbound variable y". An error, loud, but not the guided no-body message
   the ≥3-line shape gets. Documented at P3 (design doc §9); a fix needs the
   1-continuation case disambiguated, which collides with the nested-form's
   byte-transparency — revisit only if users actually hit it.

3. **Unannotated `match` as a binding VALUE** dies on the QTT infer-position
   debt (generic multiplicity message). NOT a let item — the layout produces
   the correct datum since P4 — but let is where users will MEET it, so the
   syntax doc § let carries the annotate-the-binding workaround. The debt
   itself is the QTT track's recorded option-(c) deliberate deferral
   (an `expr-reduce` arm for `infer`/`inferQ` — new typing policy).

## ✅ WITHDRAWN, with a correction — "the `:=` let chain is BROKEN in UNSPECCED defns" was issue #70 in a let costume (filed 2026-07-31, corrected same day at LET P2 `e8a41a9a`)

**The filing was WRONG and is withdrawn.** Its repro used `[+ a [+ x y]]` —
generic `+` over the defn's UNANNOTATED parameter — which is the documented
issue-#70 inference limitation, unrelated to let. The control that would have
caught it (`defn ca [a] [+ a 4]`, no let at all) fails identically. A pre-P2
A/B (worktree at `974e5cc5`) shows the unspecced `:=` chain WORKED with
concrete ops (`int+`) before any P2 change. 4th data point this session for
"a failing test is only evidence if it fails for the reason you claim" — and
the first filed by the same process that codified the pattern. Kept (not
deleted) because a withdrawn filing teaches more than a silent one.

What WAS real and did land at P2 (`e8a41a9a`): the tree spine's let-chain arm
was a rival half-implementation (`:=`-only, annotation-dropping, and a no-`:=`
`let-bracket` head fell through to a junk application surf that would WIN the
merge). It now DEFERS to preparse per the driver's own architecture comment —
a structural single-implementation move with no demonstrated behavioral delta,
claimed as exactly that. The defer is named scaffolding; it retires when the
form-cell path grows a real let.
## 🐛 Cross-FILE spec-store leakage within a batch worker (diagnosed 2026-07-31, LET P1 gate)

**Symptom**: `test-defn-multiarg-patterns.rkt` registered `(spec c Handle2 -1> Nat)`
via `run-ns-ws-all`; `test-new-lattice-cell.rkt`, running LATER IN THE SAME
BATCH WORKER, died with "spec: def c has both a spec and inline type
annotation" on its own `def c : CellId`. Passes alone; order-dependent; surfaced
when LET P1's +1 test file reshuffled worker assignment. (Unblocked by renaming
the spec to `hconsume` at `49f51c14` — that removes the collision, NOT the leak.)

**Mechanism (partially diagnosed — finish before fixing)**: the batch worker
DOES restore the spec store per file — `restore-macros-registry-snapshot!`
(tools/batch-worker.rkt:223) and `current-spec-store` IS in the snapshot vector
(macros.rkt:713 region). So the leak rides something the snapshot does not
cover: prime suspect is the CELL-BACKED registry layer — `run-ns-ws-all` passes
`prelude-persistent-registry-net-box` UNFORKED (test-support.rkt:195 region),
so a spec cell written there is shared across every file in the worker process,
and cell-first reads see it. That is the pipeline.md Two-Context class, sibling
of the 2026-06-29/07-14 batch-isolation incidents in testing.md.

**Watch**: any NEW test file addition reshuffles workers and can surface the
next collision pair. Single-letter spec/def names in test strings are collision
bait until fixed.

## ✅ CLOSED — the two eliminator usage residuals (QTT P6 + P7, 2026-07-31)

- **The Church-fold agreement hole** → ✅ `e5810cfe`. It was LIVE, not theoretical:
  a linear resource dropped inside an unanalysable branch — and in a second
  variant DOUBLE-FREED — type-checked clean and RAN, while the byte-identical
  Bool-scrutinee control was rejected. The skip swallowed NESTED violations.
- **natrec's step counted once** → ✅ `63dea0b6`, and the filing was WRONG about
  scope: natrec has zero shipped uses; the same defect sat in 8 HOF primitives
  with 121 shipped uses. Fixed across 9 nodes / 28 sites / both twins. Also
  reframed — it is the app rule (scale an argument by its binder multiplicity)
  finally applied, not a tightening: a user-written HOF capturing a linear was
  already rejected; only the built-in twins accepted it.
- **The J arm's dropped base usage** (filed below at P5) → ✅ `63dea0b6`, folded
  into P7 by owner direction.

## ✅ CLOSED — the three pattern-matching soundness items (2026-07-31)

- **Unreachable arms** → ✅ `55aac8c4`. Broader than filed: the reported
  "unknown ctor becomes a catch-all" was one instance of a general defect — an
  arm after ANY irrefutable arm is dropped by the pattern compiler and therefore
  never TYPE-CHECKED, so `match v (n -> 1N) (zero -> "dead")` defined clean with
  a String body where a Nat was expected. Fixed as a REACHABILITY check, which
  needs no heuristic about whether a lowercase name was "meant" as a constructor.
  Required a second fix to be usable: `expand-expression` had no error
  propagation, so the message arrived as
  "Cannot elaborate: #(struct:prologos-error …)" — propagation added at the
  `surf-def` command boundary and at `surf-lam`.
- **Cross-type constructor** → ✅ `09e68e60`. `ctor-belongs-to-type?` consults the
  same registry `reduce-scrutinee-decompose` uses, and DECLINES when membership
  is undecidable, so it rejects only what it can show is foreign.
- **Linear destructuring via multi-clause `defn`** → ✅ `6d4e8c73`, and the ROOT
  CAUSE was much wider than the filed symptom: `extract-pi-binders` matched a
  `surf-arrow`'s multiplicity as `_` and substituted 'mw, so `A -1> B` and
  `A -> B` were indistinguishable to every consumer.

## 🐛 `expand-expression` has no general error propagation (2026-07-31)

`expand-expression` is a structural rebuild; an error VALUE produced during
expansion is wrapped into the surrounding node and carried to the elaborator,
which reports it as `Cannot elaborate: #(struct:prologos-error …)` — the struct,
printed. `55aac8c4` added propagation at the `surf-def` command boundary and at
`surf-lam`, which covers a def body (the common case), but a producer nested
deeper still leaks that way. Arming every arm is the exhaustive-walker hazard
`pipeline.md` warns about; the structural answer is a reflective rebuild that
propagates by construction, or an error-carrying surface node.

## 🐛 A specific message for a foreign constructor in a match arm (2026-07-31)

`09e68e60` rejects it, but through the generic "Type mismatch" — accurate, not
lying, but it does not say *"`mk-b3` is a constructor of `Box3`, not `Bool`"*.
Wants the post-hoc hint pattern (a `(ctx e names) → string-or-#f` helper in
`typing-errors`' ordered chain, as used for the branch-result and QTT
diagnostics).

## 🐛 Two soundness holes on the STRICT path, found while grounding P6 (2026-07-31)

Both confirmed by probe at `7584c16e`, both independent of P6/P7. **Both are now
FIXED — see the CLOSED entry above.** Retained for the mechanisms.

1. **An unknown constructor in a match pattern silently becomes an irrefutable
   VARIABLE pattern**, making every later arm dead code with zero diagnostics.
   `defn deadarm [v] match v (vnil -> 1N) (vcons a b -> "not-a-nat")` at expected
   type `Nat` DEFINES CLEAN — arm 2's String body is never checked. Mechanism:
   `normalize-pattern`'s `[else pat]` (macros.rkt). Consequence beyond the bug:
   any probe using a misspelled constructor proves nothing, because no
   `expr-reduce` is produced at all.
2. **A constructor from an UNRELATED data type is accepted in an arm.**
   `spec crossctor Bool -> Nat` / `defn crossctor [b] match b (true -> 1N)
   (mk-b3 x -> 2N)` where `mk-b3 : Nat -> Box3` DEFINES with 0 errors. Cause: the
   bare-name `global-env-lookup-type` fallback in `reduce-arm-ctx`'s derivation
   (typing-core.rkt) with no membership test against `lookup-type-ctors`. Note
   this CONSTRAINS any "make an unfindable ctor an error" fix — the fallback
   already half-defeats it.

## ✅ CLOSED `6d4e8c73` — Linear destructuring via a multi-clause `defn` is rejected (2026-07-31)

**Root cause was wider than this symptom** — see the CLOSED entry above.
Original report retained:

`spec c3 Handle2 -1> Nat` + `defn c3 | mk-h k -> k` → "Multiplicity violation",
though it consumes the linear scrutinee exactly once. The fio spelling
(`defn f [h] match h (mk-h k -> …)`) works, so the two surface forms disagree.
Verified PRE-EXISTING by A/B against the parent commit while implementing P6 —
not caused by the QTT track.

## Residuals from QTT P5 (the guard retirement) — filed 2026-07-30

P5 (`9f0ddede` + `7b14fffe`) armed the 8 nodes and DELETED
`contains-unsupported-qtt?`. These surfaced and were deliberately not fixed in
that commit; item 4 has since closed.

1. **`expr-vindex` is STUCK** — `whnf` has computation rules for `vhead`/`vtail`
   on a canonical `vcons` (reduction.rkt) but NONE for `vindex`, which appears
   only as an `nf` congruence arm. So `vindex` now type-checks and
   multiplicity-checks but does not compute. Pre-existing, unrelated to QTT;
   filed so "Vec is supported now" is not over-read.
2. **Vec/Fin nodes have no `pnet-serialize` registration** — zero `reg!`/
   `auto-cache!` entries for the 7 constructor/eliminator nodes. Harmless today
   (no cached module contains one), but the moment a lib or user module caches a
   Vec term the reader's unknown-tag fallback returns a raw VECTOR impostor that
   fails a struct match arbitrarily far away — `pipeline.md` item 6's documented
   misleading-failure class. P5 is the natural trigger point because it makes
   Vec/Fin defs pass the gate for the first time.
3. **The Redex model has no QTT rules for Vec/Fin** — `redex/qtt.rkt` has
   grammar/typing/reduction for them but zero usage rules, so P5's seven usage
   rules ship spec-unbacked. The soundness property stays vacuously true (nothing
   breaks), which is exactly why this would drift silently.
4. ✅ CLOSED `63dea0b6` — *(was: the J arm drops its base's usage entirely.)*
   Folded into P7.
5. **`expr-foreign-fn`'s type is arity-wrong once `args` is non-empty** — both
   `typing-core`'s infer arm and P5's QTT twin return the FULL registered Pi
   rather than the remainder after `(length args)` applications. They agree with
   each other, so this is twin-parity, not drift; fixing it means fixing both.
   Reachable only via the hole-section `whnf` path.

## 🐛 LATENT — `expr-foreign-fn` is treated as a closed leaf by `shift`/`subst` but ACCUMULATES Prologos exprs (found 2026-07-30)

`substitution.rkt`'s `shift` and `subst` both have
`[(expr-foreign-fn _ _ _ _ _ _ _ _) e]` with the comment *"opaque leaf — no
Prologos sub-expressions"*. That comment is FALSE: `reduction.rkt`'s partial-
application arm appends whnf'd argument expressions into the `args` field and
returns the updated node when arity is not yet reached. So a node reachable
under a binder could hold an open term that `subst` then refuses to descend.

This is the exact shape `pipeline.md` § "Exhaustive Walkers" documents (the
`expr-champ` "closed leaf" comment asserting an invariant nothing enforced ⇒
beta silently drops arguments / `shift` never renumbers ⇒ capture).

**Probed, NOT reproducible** at `9c75e046`: a partially-applied 2-ary foreign
under a lambda (`def g := [fn [x : String] [append x "!"]]`, then `[g "hi"]`),
and a top-level partial (`def p := [append "pre-"]` then `[p "post"]`), both give
correct values — the accumulation does not survive to a substitution point in
practice, because substitution happens on the enclosing `expr-app` before `whnf`
ever builds the partial. So: a live tripwire, not a live bug. Worth either
enforcing the invariant or descending `args` in both walkers.

## ✅ RULED + SHIPPED — `m0 ⊔ m1`: a linear resource MUST be consumed on every path (2026-07-30)

**Owner ruled option 3; implemented in QTT P3 (`3a4d521a`).** Kept here rather
than deleted because the reasoning is the reference for the next multiplicity
question. Ruling: *"linear types should always be linear... there's a
correctness concern otherwise."* The join stayed the honest lub and a separate
`join-branches` guard supplies linear-per-path — `maybe-close` (the fd leak
below) now errors; `always-close` type-checks. Two residuals, both filed:
- P4 ✅ `e7fbd2ba` — the message NOW names the resource, its declaration, what
  happened and why, for all four violation classes. (The premise above was wrong:
  `multiplicity-error` already had `variable`/`declared`/`actual` fields that
  already rendered — they were filled with the string literals "declared" and
  "actual". No protocol change was needed, only real values.)
- The reduce arm's permissive fallback never checks agreement, so a leak on an
  unanalysable (Church-fold) arm still hides. Closes when that path does.

Original framing, retained:

Raised by QTT P1/P2 (`966226cf`, `9fbbc90f`). NOT the implementer's call, so it
shipped with the status-quo-preserving cell and is recorded here.

`mult-join` (prelude.rkt) is the lub of the tree's own `mult-leq` order, so
`m0 ⊔ m1 = m1`. That means a linear value consumed on SOME branches and dropped
on others type-checks — **affine per path**, not linear per path. Demonstrated on
the real API (fio, verified at `9fbbc90f`):

```prologos
;; closes the handle on EVERY path — the correct linear program
def always-close := [fn [h :1 <Handle>] [fn [c : Bool]
  (boolrec [fn [_ : Bool] Unit] [fio-close h] [fio-close h] c)]]   ;; ✓ accepted

;; closes on one branch, SILENTLY DROPS the handle on the other — an fd leak
def maybe-close  := [fn [h :1 <Handle>] [fn [c : Bool]
  (boolrec [fn [_ : Bool] Unit] [fio-close h] unit c)]]            ;; ✓ ALSO accepted
```

Before P1 this pair was **inverted**: `always-close` was REJECTED (m1+m1 = mw)
and `maybe-close` accepted. P1 fixed the false rejection. What remains is that
the leak is still accepted — precisely the failure `Handle`'s linearity exists to
prevent.

Three options:
1. **Lenient (shipped)** — `m0 ⊔ m1 = m1`. Preserves every currently-accepted
   program; permits the leak.
2. **Strict** — `m0 ⊔ m1 = mw`, so a linear resource must be consumed on every
   path. Rejects the leak, but is a behavioural regression for accepted code AND
   mislabels "zero-or-one" as "unrestricted" behind the generic "Multiplicity
   violation" string (typing-errors.rkt hardcodes the declared/actual fields as
   literals, so the message cannot say what actually went wrong).
3. **Lenient join + a per-position branch-AGREEMENT guard** for positions whose
   DECLARED multiplicity is m1. Gives strict linear-per-path semantics with a
   PRECISE failure instead of encoding a rejection as `mw`. Expressible where the
   join now sits: `ctx` is in scope and carries `(type . mult)` positionally
   parallel to the usage vectors, and `(tu-error)` is already the arm's failure
   form. This is the option the first analysis pass never enumerated.

Recommendation: (3) if linear-per-path is wanted, since it is the only one that
can produce a diagnostic naming the dropped resource. Do NOT read the shipped
default as an endorsement — it is the status quo, and the status quo permits the
leak.

## ✅ CLOSED `63dea0b6` — natrec's `step` usage is counted ONCE though it runs n times (2026-07-30)

**Superseded by QTT P7**, which also found the filing under-scoped: the same
defect sat in 8 HOF primitives with 121 shipped uses, while natrec has none.
The Redex model's matching natrec rule is noted below and still stands as a
follow-up. Original entry retained:

QTT P1 changed eliminator branch combination to a join at 5 sites and
DELIBERATELY left `natrec` on `add-usage` (qtt.rkt, comment in place). The
rationale is sound as far as it goes — base and step are not mutually exclusive
alternatives, so joining them would UNDER-count, unsound in the permissive
direction. But the current rule is not right either: `step` has type
`Π(n:Nat). motive(n) → motive(suc n)` and is applied 0..n times, while its usage
is added exactly ONCE. A linear variable captured only in the step is therefore
counted `m1` no matter how many times it is consumed.

Making it sound means scaling the step by `mw`
(`(add-usage u4 (add-usage u2 (scale-usage 'mw u3)))`), which newly rejects a
class of currently-accepted code. Recorded rather than defaulted into. Note the
Redex model (redex/qtt.rkt:173-186) carries the same natrec rule, so the two are
currently IN AGREEMENT — a fix must move both.

## ✅ CLOSED `9f0ddede` + `7b14fffe` — Retire `contains-unsupported-qtt?` (2026-07-30)

**Done in QTT P5**: all 8 nodes armed in qtt.rkt and the guard DELETED, so
multiplicity checking is unconditional at the def seam. PNET_VERSION 7→8 rode
the deletion. Original entry retained for the rationale:

QTT P2 removed the `expr-reduce` entry, which was the one that mattered. What is
left (driver.rkt) is a hand-armed walk that recurses 12 node kinds, flags 8
(`expr-vnil`, `expr-vcons`, `expr-vhead`, `expr-vtail`, `expr-vindex`,
`expr-fzero`, `expr-fsuc`, `expr-foreign-fn`), and terminates at `[_ #f]` — over
~344 `expr-*` structs. Everything else stops the walk and is reported
"supported" WITHOUT being looked inside, so the guard both over-skips (a flagged
node anywhere disables QTT for the whole def) and under-detects.

Per `pipeline.md` § "Exhaustive Walkers" the structural answer is a reflective
fallback; per `workflow.md` the guard IS the belt-and-suspenders dual path
masking qtt.rkt's gaps, and the endgame is arming those 8 nodes in qtt.rkt and
DELETING the function. Each of the 8 is its own typing question (Vec/Fin are
length-indexed; `expr-foreign-fn` is an opaque runtime value), which is why P2
deleted one entry rather than the guard.

⚠ Whoever does this: a `.pnet` version bump belongs in the same commit, for the
reason P2's did — on a cache hit the driver never elaborates, so the QTT gate
does not run and a module that should newly fail keeps loading from cache.

## The branch-result join — residual work after the diagnostic fix (2026-07-30)

Context: a multi-clause `defn` whose clause bodies have different result types
reported the unannotated-parameter hint — a lying diagnostic whose own advice
could not help, because `infer` returns `expr-error` for ANY hole-domain lambda
without inspecting the body (typing-core.rkt:1129) and every generated clause
lambda is hole-domain by construction (macros.rkt:10282/:10294) even when a
`spec` is present. Fixed on the DIAGNOSTIC side only — the join is untouched
(commit `04085007`). See `typing-errors.rkt` § the branch-result-mismatch
diagnostic.

Three pieces stayed out, deliberately:

1. **The union route proper** — making the join produce `<A | B>` for differing
   branches, so `defn f | 0 -> 1 | n -> "x"` gets `Int -> <Int | String>`.
   TRIAGED AND REJECTED FOR NOW, per the explicit instruction to triage against
   the union-hang entries first. Evidence: a union in a codomain position emits a
   fork-on-union request at EVERY call site (`type-map-write` →
   `maybe-emit-fork-on-union-request`, typing-propagators.rkt), and that
   machinery carries the two open unbounded-hang defects below — "BUG:
   Union-type checking hangs the type-checker (BSP non-quiescence)" and "DEFECT
   — union-typed def + implicit-binder spec + call HANGS the type checker". A
   hang is strictly worse than a bad message. Note also that the same strict
   join serves user-written 3-arg `if` (parser.rkt:1393) and `match` arms, so a
   semantic change here alters `if` typing project-wide. **Blocked on** the
   dedicated typing-propagator-network debugging session those entries call for.

2. **Unreportable branch types → the old message still shows, and is still
   wrong there.** The hint fires only when it can EXHIBIT two inferred,
   non-convertible, REPORTABLE branch types; a type mentioning a hole or a de
   Bruijn variable is refused (that filter is what keeps wrong types and `_` /
   `?bvar0` artifacts out of user-facing prose). The common shape it gives up on
   is a branch that READS its pattern-bound field, because `branch-result-leaves`
   extends the arm ctx with `(expr-hole)` per binding rather than the
   constructor's real field types:
   `defn f | zero -> "s" | suc n -> n` (with or without `spec f Nat -> Nat`)
   still reports "cannot infer the type of an unannotated parameter … Annotate
   the parameter or add a `spec`" — and that advice is false: the parameter is
   not the problem and a spec is already present. Fix path, non-blocked and
   mechanical: export the arm-binder ctx derivation `check-reduce-structural`
   already performs (typing-core.rkt:4451-4473 — `instantiate-pi-chain` +
   `extend-ctx-with-fields`) and call it from the leaf walk, the "one derivation,
   two consumers, cannot drift" pattern already used for `select-project` and
   `seal-missing-required`. Needs the peeled ctx to carry the expected Pi's
   domain so the scrutinee type is decomposable.

3. **Guarded clause groups** are now walked (the branch-neutral rewrite dropped
   the `expr-int-eq` target gate that had excluded them), but see the crash entry
   below — the more common guard shape does not survive parsing at all.

## ✅ CLOSED `f51bda2b` — a guarded clause group with no `[params]` header CRASHES the compiler and aborts the whole file (found 2026-07-30)

**Cause was a missing parse, not a compiler bug**: `parse-defn-clause` took
everything before `->` as PATTERNS with no `when` handling, though the
bracketed-header parser has always had that split. `n when [int-lt n 0]` became
three patterns, the clauses had mismatched arity, and the pattern compiler
indexed off the end of its parameter list and raised — a whole-file abort by
construction. Fixed by mirroring the header path, so the bare-`|` guarded form
now WORKS rather than merely failing politely. Semantics pinned (dispatch,
successive-guard fallthrough, header form unchanged, and an earlier command's
output surviving). Original report retained:

**Repro** (independently verified at `5e6d9f41`, pre-existing — the crash is in
`macros.rkt`, long before typing):

```
ns pre1
def before := 1
defn m07
  | n when [int-lt n 0] -> "neg"
  | n -> 5
def after := 2
```

`racket tools/run-file.rkt` prints NO numbered results at all — not even
`def before := 1`, which precedes the offending form — just a raw Racket
`list-ref: index too large for list / index: 3 / in: '(__arg0 __arg1)` with a
`context...:` dump through `macros.rkt:9928 compile-match-tree` →
`macros.rkt:10235 compile-pattern-group` → `macros.rkt:10309
expand-defn-multi`. Adding the bracket header (`defn m07 [n] | n when … -> …`)
avoids it. Same **whole-file-abort silence class** as the `.( )` mixfix entry
below and the tilde-reader entry: a raise on the expansion path takes the file
down instead of becoming a per-command error. Likely cause: the guard row's
pattern list is arity-adjusted for a 1-column group while `param-names` still
holds two entries, so `compile-match-tree` indexes past the list.

## 🐛 DEFECT — the branch-result join silently ACCEPTS a float branch against a String branch (found 2026-07-30)

**Repro** (independently verified at `5e6d9f41`, pre-existing; the in-file
control errors correctly in the same run):

```
ns pre2
defn ctl | 0 -> 1   | n -> "x"    ;; ERROR (correct — Int vs String)
defn d8  | 0 -> 1.5 | n -> "x"    ;; d8 : Int -> String defined  ← NO error
```

So the first-arm-wins join is not merely strict, it is **unsound for a
Rat/Posit-literal first branch**: the definition is accepted with result type
`String`. Found while adversarially verifying the branch-result diagnostic;
the diagnostic cannot see it because `check` never fails. Suspect the numeric
literal's flexible typing (the widening/defaulting path) satisfies the motive
meta and then re-solves against `String`. Wants a failing-test-first
investigation on the numeric-literal side of the join — plausibly Num Track 1
territory.

## 🐛 DEFECT — live `.( )` mixfix errors RAISE and abort the whole file (found 2026-07-28, the D4.P1a adversarial verify)

An incomparable-precedence-group error or an empty `.( )` raises out of
`preparse-expand-all` (macros.rkt `parse-expr` → `pratt-parse` →
`preparse-expand-form` → driver.rkt `process-file-inner`) and kills the file
with ZERO result lines. Repro: a file containing `.( 1 + 2 )` /
`.( 1 :: '[2 3] ++ '[4] )` / `.( 3 + 4 )` → exit 1, no output, uncaught
`mixfix: Operators from groups 'additive' and 'cons' have no defined
precedence relationship`. Byte-identical at HEAD — **not** a P1a regression.
Notable because it is the SAME failure class D4 ruling Q_L4 documents for the
old `$mixfix-retired` raiser, on the surviving mixfix path: **D4.P1a built the
per-command marker seat (`$retired-selection` → `parse-error` VALUE,
parser.rkt) that these errors should route through.** Fix candidate: emit a
marker/error-value from the pratt path instead of raising. Recorded in D4
§5.P1a close notes.

## 🐛 DEFECT — union-typed def + implicit-binder spec + call HANGS the type checker (found 2026-07-28, the D4.P1a adversarial verify)

Five-command repro, >10 min CPU-bound, never completes: `ns c1` /
`def u : <Int | String> := 42` / `u` / `spec identity2 {A : Type} A -> A` /
`defn identity2 [x] x` / `[identity2 7]`. Dropping EITHER the bare `u` use OR
the final call completes in seconds. Kill backtrace pins
`typing-propagators.rkt:3009 infer-on-network/full` → `driver.rkt:693
process-command` — after parse, in typing. Reproduced on a pristine HEAD copy,
so pre-existing and unrelated to the P1a surface deletions. Likely
union-speculation × implicit instantiation. Adjacent to (possibly the same as)
the existing "Union-type checking hangs the type-checker (BSP non-quiescence)"
entry below — **triage whether they are one defect** before opening work.

## 🐛 DEFECT — the tilde-number reader diagnostic is a WHOLE-FILE ABORT (found 2026-07-28, the D4.P1 mini-audit)

**Repro (probe-verified at `5c171caa`)**: a file containing `def a := 1` /
`a` / `def b := ~3` / … run via `tools/run-file.rkt` prints ONLY the
`prologos-reader: ~ approximate literals were removed …` message plus a raw
Racket `context...:` dump — the earlier commands' output NEVER appears, and
there is no per-command error count. Structural cause: the classifier `error`
fires inside `tokenize-char-rrb` while `read-all-syntax-ws`
(driver.rkt:2226) tokenizes the ENTIRE file before any command runs — so any
classifier-level raise is a whole-file abort by construction. This is the
exact silence class the P2 loud-tier work exists to prevent, sitting in the
reader. **Remedy**: once CIU T6 D4.P1a lands the marker-form + `parse-error`
value diagnostic seat, migrate the tilde diagnostic onto it (emit a marker,
convert per-command). Owner of the remedy: D4.X.close triage (or fold into
P1a if trivially cheap once the seat exists). Recorded in D4 §5.P1.

## 🐛 DEFECT — bare top-level `[]` hard-aborts the reader with a raw contract violation (found 2026-07-28, the D4.P1 mini-audit)

A standalone `[]` as a top-level form dies inside the reader: parse-reader.rkt
:2160-2161 emits a position-0 stx → `syntax-position` #f → macros.rkt:2804
`max`/`-` on #f → raw Racket contract violation, whole file lost. `[f []]`,
`def x := []`, `a []` are all fine — the defect is the bare-top-level shape
only. Adjacent to (but distinct from) D4.P1a's `x[]` reject-batch item, which
covers the POSTFIX-adjacent empty bracket; this is the standalone form.
Fix candidate: guard the position-0 emission or route through the P1a
diagnostic seat. Recorded in D4 §5.P1.

## 🐛 DEFECT — `def X :=` + multi-key layout body fails; identical body without `:=` works (filed 2026-07-28, the D5 critique)

**Repro (byte-identical bodies, A/B verified at `2b1b383d`)**:
```
def r1 :=
  :eu {:host "eu.example.com" :port 443}
  :us {:host "us.example.com" :port 443}
;; → ERROR: Could not infer type

def r2
  :eu {:host "eu.example.com" :port 443}
  :us {:host "us.example.com" :port 443}
;; → r2 : {:eu {:host String :port Int} :us {:host String :port Int}} defined.
```
Trigger is fiddly (≥2 top-level keys, or ≥2 dash items with a multi-line
`@[…]`) — evidence of a defect, not a documented restriction. Single-line
`:=` bodies work. The diagnostic ("Could not infer type") names the wrong
thing — it is a PARSE/layout seam, not typing. Found while running the Path
Selection spec's Appendix fixtures (4 of its `def X :=` forms hit this).
Workaround in corpus files: use the `def X` (no `:=`) implicit-map form.
Owner ruled 2026-07-28: filed as **issue #80**
(https://github.com/LogosLang/prologos/issues/80, OPEN). Adjacent context: the
implicit-map-def WS path was touched by the 2026-07-18 hand-testing arc
(`ff31d237` — process-string-ws parity), so the seam has history.

---

## ✅ RESOLVED — CIU T6 F1b: D23 posture-flip (DEPLOYED F1b.6 `7bcbca69`, 2026-07-18)

**The Q4 tightening is DEPLOYED — D23 (track doc §2a round 6): escape-boundary
hard error.** A dyn-row point-projection meta (kinds `dyn-row-projection` /
`dyn-row-dynamic-projection` ONLY — the narrow partition; bulk-op result kinds
keep scrubbing) escaping into a stored type is a HARD ERROR with def-srcloc, at
the two def-commit boundaries; exploration stays permissive; escape hatch =
explicit annotation. Implementation = F1b.2 (groundwork) + F1b.6 (the flip, via a
type-LOCAL walk `check-escaping-projection-metas` / `collect-expr-metas-deep`).
Full record: design doc §13.6 F1b.6 ✏ CLOSE. This pin is now historical (kept for
the sequencing rationale below); the flip landed AFTER F1b.3's presence activation
as required. **Rejected-with-reason (do NOT resurrect
from this entry's old phrasing)**: (a) freeze-wide default-to-error at zonk-final —
freeze fires in NON-display contexts (stored types driver.rkt:1704, constraint
rendering :1579-1580/:1754-1755, capture :1349); a policy there corrupts error
messages and capture, verified blast radius; (b) the constraint-store realization
of the obligation — the constraint struct's equational rendering + retry-only
failed-transitions do not fit an unsolved-observation obligation (the meta store
already records provenance at mint; a second record is duplication). The
refusal-relax half (meta-V from dyn rows) moved to § F-carrier below.

## CIU T6 F-carrier: the Q_E(b) carrier unification — consolidated retirement home (D26 stub charter, 2026-07-17)

The ONE coherent future carrier change (D16): bounded dyn tails carrying `(K,V)`,
key-domain generalization beyond `keyword`/`nat` (heterogeneous key-types:
strings, maps, arbitrary keys — owner-flagged 2026-07-15), and `expr-Map`
dissolution into the row carrier. Stub tracker row: F1 design doc §2. Sequencing
vs F-row (they interact via the bounded-tail Galois end-state, design doc §12.5
pin 3) is decided by whichever opens first. **Everything that retires here, with
entry gates** (round-6 rulings, track doc §2a):

1. **Covariant/label-keyed depth** (D21 deferral) — triggers: row-type
   annotations become user-writable (the PROBES P8 forward surfaces), OR
   supertype-typed fields (generic `Num`, unions) in expected-row positions.
   Upgrade = local realization swap at the D21 fallback arm; can NEVER ride
   C_Cons (`'sub` goals are pure unify pairs).
2. **The unify-internal width slice** (D21 non-coverage) — gate: evidence of a
   REAL production population of row-vs-row width events bypassing check
   (PROBES P8: zero today; D15 homogeneity semantics DEPEND on the failure —
   any unify-side width needs a direction carrier, which is F-carrier work).
3. **T refusal-relax** (D23 deferral): solve `V := ⋃knowns ∪ ?fresh` from dyn
   rows — gate: the union-behavior probe (union-containing-free-meta vs a later
   exact type) pinned at the refusal-leg comments (typing-core record-<:-map?/
   record-<:-elem?).
4. **Annotation-derived bounds** for D19 metas — no machinery exists at HEAD
   (meta-info.constraints is dead-threaded); becomes expressible once tails
   carry bounds.
5. **Heterogeneous key-types** (absorbs the former standalone entry): `expr-Map`
   survives as the dictionary type until here; the carrier's key-domain slot is
   where the generalization lands; D17's `{}` keyword-commitment is one
   recoverable seed site.

## CIU T6 F1b.5: the deep-walker charter — ONE mechanism, one entry (D27.5, 2026-07-17)

Validate v1 is ONE-LEVEL with STRUCTURAL depth symmetry (it consumes the same
field-set enumeration as `schema->row` — never a second one-level implementation).
THREE deferrals are ONE walker mechanism and live in THIS single entry (never
residue-letter entries — divergent gates/double-count):

1. **Container/nested-seal traversal depth** (the driver top-node class — def-forcing
   + eval arm see only top nodes; a seal nested in a pair/list escapes both).
2. **Tier-2 element recursion** (`(List Int)` fields checking each element).
   HONEST reason (D28 corrected the false one): `ctor-meta` ALREADY carries
   field-types/params/rec-flags runtime-readable (macros.rkt `ctor-meta` +
   `lookup-ctor`) — what is unbuilt is the param-substitution + recursion +
   depth discipline (recursive-schema edge), NOT metadata.
3. **Sub-schema descent** (auto-registered `Parent__field` entries carry
   check/default = #f — stripped at registration; a one-level engine hitting a
   sub-schema-typed field has no defined deep disposition).
4. **Nested / wildcard selection requires-paths** (F1b.5-s4, `0f95d544`):
   selection-validate enforces only SINGLE-SEGMENT `:requires` (a length-1
   keyword-path `(#:name)`) as the read-capability miss-check. A deep path
   (`:address.zip` → `(#:address #:zip)`, incl. its top hop) or a wildcard
   (`:address.*` → `(#:address *)`) defers — it is the SAME descent mechanism as
   #3 applied to a selection's read-capability (descend into the `:address`
   sub-value to check `:zip`). A selection with deep requires still gets full
   type/:check/closedness validation at s4; only the nested read-capability miss
   isn't caught yet. Filtered at the bake (`(null? (cdr path))` ∧ keyword head).

`defr : Schema` fact-row runtime validation rides the same charter (an adapter
over the positional discharge, parser.rkt `parse-defr-schema-typed`).

**✏ 2026-07-18 (hand-testing) — the nested-`validate`-descent gap is DEMO-RELEVANT,
may fold into Path Selection.** Hand-test verified at `f108c19b`: `[validate
Config badcfg]` where `badcfg.server.port = "x"` returns **`ok`** (accepts the
bad nested `:server` — the witness treats a nested-schema field's champ value as
opaque/accept-on-uncertainty per the one-level D28 posture). ASYMMETRY worth
noting: the STATIC seal DOES descend (a bad nested *literal* is caught at commit),
but runtime `validate` does not — precisely the demo's headline flow (external
data → `validate` → `Result`) would report `ok` on a config whose inner fields
are wrong. This is items #1/#3 above (container/nested + sub-schema descent).
Owner steer (2026-07-18): does NOT need building yet, but "could very likely be
included in the Path Selection work" (which precedes the return to demo work) —
so this walker-descent may graduate WITH Path Selection rather than as a
standalone charter trigger. Entry-gate (a) [a real nested-schema demo consumer]
is the watch.

**Entry gates**: (a) a real consumer with nested/container schema shapes — the
P-Real demo schemas are the watched trigger (checked at F1b.5-p0; list-typed
fields would open this EARLY); (b) API compatibility is PRE-PAID: E keys are
PATH-shaped from v1 (D27.3, singleton paths) so the walker extends without a
breaking E change (product-over-paths); (c) the depth discipline designed
(recursive schemas). 

**Residue (e), honest wording (D27.5; ✏ F1b.5-s4)**: the open?-absorbed
missing-required (schema-seal-residual-ok?'s open? disjunct) is *dischargeable
via validate (OPT-IN)* — the OPT-IN path is now REAL (validate landed s2 for
schemas, s4 for selections). AUTO-discharge stays deferred to the blame-latch
era — gate: the §3b blame-latch citation verified concrete at F1b.5-p0 (else
re-anchor; an invented placeholder gate is forbidden). s4 does NOT close this
entry (auto-discharge is the deferred half).

## CIU T6: the cross-module schema channel — staleness + cache-hit registration (probe-found at F1b.5-p0, 2026-07-17)

> **TRIAGED 2026-07-27 (GitHub #78 X.close): gaps 2 and 3 are RESOLVED; gap 1
> remains open.** This entry called its own fix shape correctly ten days early
> — "serialize the schema registry into `.pnet` (the ctor-registry precedent:
> serialize + cache-hit merge + load-module capture/re-propagation)" is exactly
> what #78 P2 shipped (`54358a5f`).
>
> - **Gap 2 — RESOLVED** (`54358a5f`). schema (and selection/session/strategy/
>   process/user-operators/user-precedence-groups) are now serialized into
>   `.pnet` (v4, indices 24-30), restored into BOTH parameter and cell on a
>   cache hit, and captured/re-propagated by `load-module`. Cross-module
>   schemas are no longer cold-load-only. Regression-gated by
>   `tests/test-pnet-registry-restore.rkt` (severity-3 case).
>   ⚠ The predicted symptom was UNDER-stated: this did not merely make
>   inject/wrap silently no-op — it produced a HARD module-load failure
>   (`imports: Error loading module <M>: Type mismatch`), because the seal
>   guard at `typing-core.rkt:3125-3126` turns the arm off entirely. That is
>   the issue's severity 3.
> - **Gap 3 — RESOLVED** (verify: all 7 registries appear in
>   `save-macros-registry-snapshot`, and `tools/batch-worker.rkt` save/restores
>   via it at `:98`/`:223`). The F1b.5-s1 hygiene rider this entry anticipated
>   did land.
> - **Gap 1 — STILL OPEN**: `.pnet` validity is still own-source mtime +
>   `driver_rkt.zo` stamp only; no content/dep hashing. A dependency's schema
>   changing still does not invalidate a dependent's cache. #78 P2 makes the
>   *contents* correct on a hit; it does nothing about *when* a hit is
>   legitimate. **Entry gate met** — the "first real cross-module schema
>   consumer" gate was overtaken by #78, so gap 1 is now the sole remaining
>   piece and should be scheduled rather than gated.

PRE-EXISTING class, probe-verified at `6584b443` (F1b.5-p0 agents; full record
design doc §13.8 ✏ items 6-7). THREE coupled gaps, ONE channel fix:

1. **No cross-module cache invalidation**: `.pnet` validity = own source mtime +
   `driver_rkt.zo` stamp ONLY (`source-hash-for-module`'s own comment concedes
   no content/dep hashing). Schema-derived data baked into a USING module's AST
   (defaults + :check chains TODAY via inject-schema-defaults/wrap-schema-checks;
   validate's baked plans from F1b.5-s2) goes silently stale when the DEFINING
   module's schema changes. update-deps' edge graph feeds test selection only.
2. **Schemas are not serialized into `.pnet` and not re-registered on cache-hit**
   (zero schema tokens in pnet-serialize's 17-registry list; no register-schema!
   on the cache-hit merge path) → A-cache-hit + B-cache-miss ⇒ `lookup-schema`
   = #f ⇒ the existing inject/wrap SILENTLY NO-OP. Cross-module schemas are
   COLD-LOAD-ONLY today. (Validate's elaboration bake errors LOUD on the miss —
   better diagnosability, same underlying gap.)
3. **The registry parameter is off three save/restore lists** (batch-worker
   restore, test-support parameterize, the macros 19-param snapshot) — masked
   by cell-first reads + the cell-id riding save-macros-cell-ids. The list
   insertions land as the F1b.5-s1 hygiene rider; THIS entry keeps the
   structural fix.

**Fix shape (one channel)**: serialize the schema registry into `.pnet` (the
ctor-registry precedent: serialize + cache-hit merge + load-module capture/
re-propagation) + dep participation in the cache key (content/dep hashing at
source-hash-for-module — its comment already names the full implementation).
**Entry gates**: (a) first REAL cross-module schema consumer (a library module
exporting schemas — none exist today; the demo is single-file); (b) or the
first stale-baked-plan incident in practice. Until then the class is documented
here + at §13.8.

## PM: resolution bridges capture registry cell-ids while they are still #f (found at GitHub #78, 2026-07-27)

VERIFIED at `a892f951`, separate from #78 and deliberately NOT swept into it.
`make-pure-trait-bridge-factory` (`resolution.rkt:460-462`) and
`make-pure-hasmethod-bridge-factory` (`:552-555`) read
`(current-impl-registry-cell-id)` / `(current-param-impl-registry-cell-id)`
**eagerly**, outside the returned lambda — and both factories are invoked at
`driver.rkt:3623-3624`, at **module level**, where those cell-ids are still
`#f` and stay `#f` for the life of the process. `read-persistent-registry-cell`
(`resolution.rkt:408-413`) has **no parameter fallback**: it returns `(hasheq)`
unconditionally on a `#f` cid. Net effect: the pure trait/hasmethod bridges
read an EMPTY impl registry in every process.

Opposite polarity to #78 (which was write-to-param/read-from-cell; this is
read-from-a-cell-that-was-never-identified), and the same half-migration root.
Silent in both cases. **Fix shape**: defer the capture into the lambda, or read
the cid at fire time. **Constraint**: this is a prerequisite for PM Track 12's
read-path work — see `2026-07-27_PM_TRACK12_REGISTRY_READ_PATH_NOTE.md` §2.4.

## PM: `.pnet` positional format has no arity assertion (found at GitHub #78 P2, 2026-07-27)

`serialize-module-state` and `deserialize-module-state` exchange a bare
positional list, and `driver.rkt`'s cache-hit arm is its ONLY consumer (verified
tree-wide). Nothing asserts the length or names the slots. Appending is safe;
**inserting** a slot anywhere before the tail would silently shift every later
position, and because every registry slot is a hasheq the types are
indistinguishable — the failure would be silent wrong registries, i.e. exactly
the #78 severity-1/2 class. The `PNET_VERSION` gate is the only thing standing
between a mis-ordered write and a mis-read.

Cheap hardening: assert the deserialized length matches an expected constant,
or move to a keyed/named representation. Not urgent (one consumer, exact
version gate), but the blast radius is silent-wrong-answer.

## CIU T6: inference on unannotated params (projection + arithmetic) — records ergonomics (hand-testing, 2026-07-18)

Two record-ergonomics soft spots found dogfooding `foray.prologos` — both are
the SAME class (inference on an UNCONSTRAINED param), both have named deep-fix
homes, both got a **near-term error-message mitigation** (`ff813935`: the bare
"Type mismatch" now says "cannot infer the type of an unannotated parameter …
annotate `[x : T]` or add a `spec`").

1. **Projection on an untyped param** — `defn f [p] p.x` fails: to project `:x`
   the checker must know `p` is a record. Today requires an annotation (`[p : T]`)
   or a spec whose name MATCHES the defn (the owner's `point-add` hit this via a
   `spec paint-add`/`defn point-add` name typo → bare untyped params). **Deep fix
   = F-row**: projection-driven ROW inference — generate a constraint
   `p : {:x _ | _}` from `p.x` and solve it structurally. Now more tractable
   (rows exist post-F1a/F1b) but still extension-typing scope (§12.5 pins / the
   one-solver era). Entry gate: F-row opens.
2. **Generic `+`/arithmetic on an untyped param** — `defn f [x] [+ x 1]` fails
   standalone (pre-existing): `+` needs `x`'s type. **Deep fix = Num Track 2**
   (generic `Num` / constraint-as-type): constrain `x : Num`-ish from `[+ x 1]`.
   Seed note `2026-07-02_GENERIC_NUM_TYPE_NOTE.md`. Entry gate: Num Track 2 opens.

Neither blocks records-correct-in-principle (annotate or spec is the workaround);
the mitigation makes the workaround discoverable. Do NOT attempt the deep fixes
in a records slice — they are their own tracks.

## CIU T6: schema EXTENSION / inclusion — un-named future design track (owner brewing, hand-testing 2026-07-18)

Owner wants to eventually EXTEND one schema with another (`AdminUser` = `User`
+ extra fields — flatten the parent's fields into the child), but ruled it needs
its own **ergonomic + parse design** and time to brew (2026-07-18); a LARGER
design question than F1b, out of scope for the current demo (nested `schema`s
are sufficient for demo purposes — owner-confirmed).

**Current state (hand-test verified `f108c19b`)**: there is NO schema-extension
mechanism. The only schema directives are `:closed` (schema-level) + `:default`/
`:check` (per-field, `parse-field-properties` macros.rkt). Composition today =
**nesting only** (a schema field whose TYPE is another schema), which works well:
deep projection `cfg.server.host` resolves through named-type AND inline
auto-registered (`Parent__field`) sub-schemas; the static seal descends into
nested literals. Nesting is the intended composition story for now.

**The discoverability trap (candidate small pre-fix, deferred with the feature)**:
`schema Admin :include User` is SILENTLY parsed as a field NAMED `:include` of
type `User` (`:include` is not a directive — field names lead with `:keyword`,
so it looks like a legit field), producing a confusing downstream
"schema seal: missing required field :include". A user reaching for extension
gets no hint. Options if the owner wants a near-term guard: (a) a warning/error
when a schema field's TYPE position is itself a registered schema name AND the
field name looks directive-ish (`:include`/`:extends`/`:from`) — heuristic, risky;
(b) leave it until the extension feature lands and decides the real syntax.

**Design surface (for when the track opens)**: syntax (`:include S`? `schema X
from Y`? a spread?) · flatten semantics (structural row-union vs a nominal
"extends") · field-collision rules (override? error? most-derived-wins?) ·
`:closed` interaction (does a child of a `:closed` parent stay closed?) ·
whether extension composes with `selection` (a view over an extended schema).
Likely CIU (records/rows) territory; may relate to F-row's extension typing.

## CIU T6: projections via `selection` — down-cast + read-capability design (Path-Selection-adjacent, hand-testing 2026-07-18)

`selection` (F1b.5-s4) is a read-side capability VIEW, hand-test verified
`f108c19b`. Owner: this projection work is "likely related design work"
(Path Selection) and not a current demo need (2026-07-18) — DEFERRED, folds into
the OPEN **Path Selection** owner conversation (track doc §2a OPEN note).

**What works**: `selection V from S :requires [f …]` narrows the readable surface
to its `:requires` fields — `v.name` reads on `NameOnly :requires [:name]`;
multi-field requires works; validate on a selection enforces requires-present +
present-field type/`:check`, accepts extra parent fields. Empty `:requires []`
is rejected (needs ≥1 of requires/provides/includes).

**Two gaps (both → Path Selection)**:
1. **No down-cast from a parent value**: `def x : NameOnly := aPersonValue` →
   Type mismatch (expected NameOnly, got Person). A selection value is CONSTRUCTED
   from a map literal — you cannot narrow an existing record to a subset view.
   The "project a subset OUT of a record" ergonomic is exactly Path Selection's
   V4 result-shape crux; selection is a *typed view you build*, not a *projection
   you apply*. Feeds the Path Selection co-design.
2. **Reading a NON-requires field off a selection value fails with a CRYPTIC
   message**: `v.age` on `NameOnly :requires [:name]` → bare "Could not infer
   type" (the view type exposes only its `:requires` fields — semantically a
   coherent read-capability restriction, but the diagnostic is opaque). Candidate
   small message improvement (name the view + its readable fields), pre-close OR
   with the Path Selection work. NOTE also an OPEN semantics question for that
   co-design: should a selection value expose ALL parent fields it carries at
   runtime, or stay strict to `:requires`? (current = strict).
3. **Bare map-ops on a SELECTION value** (`[map-keys s]` / `map-assoc`/`dissoc`/
   `vals`/`has-key?`/`nil-safe-get` where `s : SomeSelection`) → "Could not infer
   type" (folded here from F1b.7e, `311fc034`, 2026-07-19). F1b.7e fixed these on
   SCHEMA values (a schema-fvar subject projects to its row via `schema->row`),
   but selection fvars were deliberately NOT projected: to stay consistent with
   `map-get`'s selection arm (which gates reads to `:requires`, the
   read-capability), structural ops on a selection need the `:requires`-RESTRICTED
   row projection, not the full parent row — which IS this selection-projection
   design. Fix shape (when this opens): a `selection->requires-row` projection
   (parent's fields filtered to the single-segment `:requires` set) applied in
   the same 7 imperative arms `schema-fvar->row-or-self` (typing-core) already
   touches; couples to the strict-vs-carried-fields semantics question in item 2.

## CIU T6: named-`?`-field vs presence-optional DISPLAY ambiguity (7g surfaced, owner-acknowledged 2026-07-19)

F1b.7g made `?`/`!`-suffixed keyword keys read whole (`:active?` is now a valid
field/key name). This makes a PRE-EXISTING, display-only ambiguity newly
REACHABLE: a field literally named `active?` with presence `'present` renders
`{:active? Bool}` — INDISTINGUISHABLE from an OPTIONAL field `active` (the D24
presence-`'unknown` display marker appends a `?` suffix, pretty-print.rkt:439-445;
already-documented at syntax.rkt:684-686 as "revisit if it bites"). It is
**display-only** — flips NO parse-time behavior; the stored label is `active?`
verbatim and the value reads/projects correctly (`s.active?` → the value). Owner
acknowledged (7g Q2), NOT a blocker. **When it bites** (a user confused by
`{:active? Bool}` meaning "field active?" vs "optional active"): the fix is a
presentation-design choice in the pretty-printer — e.g. render presence-unknown
with a distinct marker (a leading `?`, or a space, or `{:active [?] Bool}`) so the
suffix-`?` of a real field name never collides with the presence marker. Couples
to the D24 presence-marks display + the broader FQN-display-verbosity presentation
question (dailies 29). Low urgency; a display-layer-only change (no reader/typing
touch).

## CIU T6: two standing WS-surface non-blockers (F1b arc hand-testing, filed 2026-07-19)

Two known, low-severity surface gaps found across the F1b arc — workarounds exist,
neither blocks records-correct-in-principle; filed so the doc-truth is honest.

1. **`<`-check-preds are unusable in WS files** — a `<`-leading form (`:check (< _ 5)`)
   is mis-read: `<` opens an angle-type reader GROUP in WS mode, so the predicate
   never parses as a comparison. **Workaround: `(> N _)`** (reversed direction:
   `:check (> 5 _)` means "field < 5"; the `>`/`>=` normalizer handles the arg
   swap). Same CLASS as the 7g `?`-in-keyword-token gap (a WS-reader charset/
   grouping issue) — the reader-level fix would let `<` inside a check pred read as
   the operator, not the angle-group opener. Pre-existing; not records-specific.
2. **`match` with an INLINE `validate` scrutinee fails inference** —
   `match [validate S e] | ok v -> … | err es -> …` fails to infer the scrutinee's
   `Result S E` type inline; **def-bind first** (`def r := [validate S e]` then
   `match r …`) works. Route-sensitivity in the checker's inline-vs-def-bound
   scrutinee inference (the F1a col-3/p0 literal/binding-route-sensitivity class).
   Found at F1b.5-s2.

## CIU T6 → Rel: typed solution rows — MOVED to the Rel series (2026-07-19)

**Charter home is now the Rel series** ([`2026-07-19_REL_MASTER.md`](2026-07-19_REL_MASTER.md)
→ [`2026-07-19_REL_SOLVE_TYPING_NOTE.md`](2026-07-19_REL_SOLVE_TYPING_NOTE.md)
Problem 1), grouped with the `not`/NAF-correctness work as the first (un-named)
Rel track. Owner (2026-07-19): solve typing sequences BEFORE Path Selection (its
highest-value consumer). The original charter is retained below for the entry gates.

`solve` results carry NO type at HEAD (`expr-hole`); per-solution ROW types
(`List {unknown : T …}`) would make Path Selection over solution sets TYPED.
Chartered at F1b close, NOT inside F1b — the naive version is broken (solution-row
labels are NOT statically derivable: args are whnf'd before the ground/free split;
anonymous `_` vars become gensym-named keys — PROBES/panel Q5-B). **Entry gates**:
(a) define the typeable-goal fragment; (b) ONE shared ground/free predicate
consumed by reduction AND typing (never a reproduced walk); (c) the two-context/
relation-registry audit (incl. relations from cached `.pnet` bodies); (d) reconcile
the TWO unbound representations (unresolved var → own-name fvar vs missing key →
`none` — presence-`'optional`/Option candidates; explain's reserved keys = the
first `'optional` clients); (e) display posture vs D23 (untyped relations ⇒ rows
of metas).

## CIU T6 (post-F1b): explain restructure — provenance beside the rows

Explain's reserved `:certainty`/`:cycle` keys merge into the SAME champ namespace
as query-var keys (reduction.rkt explain merges) — the right eventual shape is a
wrapper record `{:solutions […] :certainty …}` (provenance beside the rows, not
merged in). Inherits the D25.2 interim clobber guard as a pin — LANDED at F1b.1
(commit `83784ef9`), realized as **binding-wins-on-collision** (the metadata
insert is skipped when a query var claims a reserved name; covers all THREE
reserved keys certainty/cycle/provenance — provenance is the live one under
default semantics; skip keeps solve/explain treating the same query
identically, vs reject which would make explain stricter). Not blocked; open
when the explain surface next gets attention.

## Numerics N6d-i follow-ups: method-wrapper derive skip-set remediation

Four items deferred from the auto-derive design (Numerics design doc §9d D-N6.5;
grounding-audit 2026-07-02 at HEAD `c8a425f7`). The derive ships with a
skip+warn policy; these lift the skips / harden the substrate.

### 1. Lift the `add`/`sub`/`join`/`reduce` derive skips (spec-clobber remediation)

- **Scope narrowed 2026-07-02**: the N6d-i derive shipped an elaborator
  resolution reorder (`elaborator.rkt`: where-context arm moved BEFORE the
  own-namespace arm) that STRUCTURALLY fixes the *capture* class — a bare
  trait-method call inside a `where`-constrained body (e.g. `[leq x y]` in
  `impl Lattice (Map K V) where (Lattice V)`, `[narrow x y]` in propagator) now
  resolves via the where-dict, not a same-named derived wrapper, restoring the
  pre-derive behavior for ALL methods. So capture is NO LONGER a reason to skip.
- **The remaining skip reason = spec-CLOBBER only** (issue #66): the derive
  skips `add`/`sub`/`join`/`reduce` because each collides with an existing
  NON-trait top-level def+spec of the same name — nat's `add`/`sub` (`impl Add
  Nat` body calls the *imported* nat `add`, an unconstrained context the reorder
  doesn't touch) + their concrete `spec add Nat Nat -> Nat`; string-ops `join`;
  list `reduce`. A derived generic `spec add {A} … where (Add A)` overwrites the
  concrete spec in the bare-name spec store → wrong implicit-arg counts.
- **Remediation**: fix the bare-name spec-store clobber (issue #66 — FQN-keyed
  or module-scoped specs), then the skips lift cleanly. Low urgency (generic
  `+ - *` keywords cover bare-call ergonomics; `mul`/`eq?`/`compare`/`neg`/`abs`
  already derive first-class fine).

### 2. Spec-store bare-name keying — silent clobber (structural defect) [issue #66]

- **What**: the spec registry keys by BARE symbol with silent last-write-wins:
  `register-spec!` (`macros.rkt:480-482`), import spec-propagation
  (`driver.rkt:2810-2811`), and implicit-hole counting strips FQNs before
  lookup (`elaborator.rkt:567-576`). Two same-named specs from different
  modules (e.g. nat's `add` vs a generic `add`; a derived `reduce` vs
  `list.prologos`'s `reduce`) overwrite each other in any module importing
  both — the loser's call sites get WRONG implicit-argument counts, silently.
- **Fix direction**: FQN-keyed spec store (or module-scoped shadowing with
  deliberate resolution order). Crosses the module system — candidate for a
  PM-series follow-up. Blocks item 1's clean resolution.

### 3. Zero-arg / output-position-only trait methods as context-resolved values

- **What**: the derive's argument-position rule excludes constants (`zero`,
  `one`, `bot`, `top`, `empty-coll`) and output-only methods (`from-integer :
  Int -> A`). Structurally: bare-reference auto-apply requires all-m0 binders
  (`elaborator.rkt:541-542`) but where-dict params are mw (`macros.rkt:4213`),
  and there is no argument to unify the type var against. Expected-type-directed
  constraint resolution (`def z : Float64 := zero`) is UNPROVEN at HEAD — no
  machinery confirmed for solving an output-position constraint meta from the
  checking direction before `resolve-trait-constraints!`.
- **Fix direction**: a checking-mode resolution path (the N4 context-typing
  shape applied to constraint metas). Natural home: the UCS trait re-engineering
  track (`2026-06-30_TRAITS_AS_REFINEMENT_TYPING_NOTE.md`) or a dedicated
  probe+mini-design. Also lifts the `from-integer`/`from-rational` exclusions
  (whose names additionally collide with hard arity-2 parser keywords —
  `parser.rkt:1961-1974` — so they may want distinct wrapper names regardless).
- **N6f dependency (2026-07-02)**: the `sum`/`product` explicit-dict → where-constraint
  modernization (Num Track 1 N6f, D-N6.5 filing) is BLOCKED here — their bodies call the
  nullary identity accessor (`[AdditiveIdentity-zero id-dict]` / `[MultiplicativeIdentity-one …]`,
  `core/algebra.prologos:117,129`), which needs `zero`/`one` resolved from the where-context
  (exactly this item). N6f-a retired the `plus/minus/times/divide/negate-fn/abs-fn` wrappers
  (commit `a556f38e`) but LEFT `sum`/`product` explicit-dict pending this resolution.

### 4. Registry silent-overwrite: no duplicate-binding diagnostics [issue #67]

- **What**: every collision surface found by the N6d-i audit fails SILENTLY —
  trait registry (`macros.rkt:6228-6231`), spec store, import shadowing
  (`namespace.rkt:833` "MUST BE LAST — shadowing depends on ordering") are all
  hash-set overwrite with no duplicate-binding error or warning.
- **Fix direction**: an opt-in (or default-on) duplicate-binding diagnostic at
  registration time. Cheap hardening; would have made the N6d-i collision
  census mechanical instead of forensic. The derive's cross-trait-duplicate
  warning (modeled on HKT-9's ambiguity check, `elaborator.rkt:165-176`) is the
  first slice.

---

## BUG: Union-type checking hangs the type-checker (BSP non-quiescence)

- **Found**: 2026-06-29 hunting a `foray.prologos` type-check hang (DEMO Series session).
- **Symptom**: the typing propagator network NEVER quiesces — infinite BSP firing in `attribute-map-merge-fn` (`typing-propagators.rkt:440`), the `:type`-facet union join not reaching a fixpoint. `run-to-quiescence-bsp` loops forever (no fuel bound on the elaborator/typing network → a HANG, not a bounded error).
- **Minimal repro** (ORDER-DEPENDENT): a `.prologos` file with, in this order — `def x : <Int | String> := 42` / `x` / `the <Int | String> "0"` — hangs. Reordering (`def x` ; `the …` ; `x`) completes; the same shape with plain `Int` completes; each form alone completes. So it is the union-type join under specific accumulated network state.
- **Scope of fix**: a type-lattice-convergence investigation — why the union join's `facet-merge` for `:type` is non-idempotent / non-convergent under this state (relates to SRE Track 2H type-lattice/quantale). Likely ALSO wants a **fuel bound on the typing/elaborator network** so non-convergence becomes a bounded diagnostic instead of a hang.
- **Impact**: union types (`<A | B>`) in certain sequences hang the compiler AND the LSP (it type-checks on open) — real-program-affecting, not just foray.
- **Workaround in place**: foray's union forms commented out (so it loads).
- **✏ 2026-07-17 (CIU T6 F1b.3, worktree-verified PRE-EXISTING at `0bdfca22`)**: the
  class is BROADER than the original repro — after the F1 acceptance file's
  accumulated state (86+ commands incl. union-typed defs `hu : Int | String`),
  BOTH (a) a polymorphic spec+app (`spec pick {A : Type} A A -> A` … `pick wn ww`)
  AND (b) a plain annotated-lambda def (`def idint := [fn [x : Int] x]`) HANG the
  file run (BSP non-quiescence, unbounded memory) on the PRE-F1b.3 compiler too.
  Repro files preserved: session scratchpad `f1b3-m322.prologos` / `t-idint-pre`.
  CONSEQUENCE: the F1b.3 width canaries live in a SEPARATE clean-state acceptance
  file (`examples/2026-07-17-ciu-t6-f1b3-width.prologos`) rather than appended to
  the main file. Possible connection to the transient full-suite mass-stalls
  (2 data points) — check when this gets its session.
- **Not blocked** — needs a dedicated debugging session on the typing propagator network.

---

## Tooling: Extend bench-ab.rkt with --refs for multi-way A/B/C+ comparison

- **GitHub Issue**: [#63](https://github.com/LogosLang/prologos/issues/63) (PRIMARY surface; queryable; linkable from PRs)
- **MASTER_ROADMAP.org**: forward-references at OE Series Track 1 (weighted parsing) + PReduce Track 4 (cost-guided extraction)
- **Origin**: PPN 4C Tropical Quantale Addendum 1C-vi A/B/C report (2026-05-16; `docs/tracking/2026-05-16_TROPICAL_1C_VI_ABC_REPORT.md`); design doc §13.7 cross-track note flagged as "small tool enhancement"
- **Scope**: `tools/bench-ab.rkt` currently supports A/B (`--ref HEAD~1`); extend with `--refs` accepting multiple commit refs for multi-way comparison; markdown table generation option
- **Consumed by**: OE Series Track 1 (weighted parsing with cost-extraction variants); PReduce Track 4 (cost-guided extraction with multiple strategies); future PAR tracks (parallel scheduler variants comparison)
- **Not in scope for 1C-vi**: A and B baselines for THIS addendum's report are captured data files (OLD struct-field counter RETIRED at 1C-iv-b; live A re-measurement structurally impossible); a markdown report sufficed (β3 resolution per §10.0.7)
- **Multi-surface tracking discipline**: this entry is part of a dual-surface pattern (Issue + MASTER_ROADMAP forward-refs + this entry, all cross-referenced) — codification candidate from §10.0.7 ("Multi-surface tracking with cross-references is more durable than DEFERRED.md alone"; user observation: "capturing in deferred is not meaningful follow up and likely will be work lost")
- **Estimated scope**: ~50-100 LoC + tests
- **Not blocked on anything** — can be implemented when a consuming track has the multi-variant comparison need

---

## HIGH PRIORITY: Propagator/Cell Allocation Efficiency Track

### Design Track for Efficient Prop/Cell Allocation
- **Audit complete**: `docs/tracking/2026-03-20_CELL_PROPAGATOR_ALLOCATION_AUDIT.md` (commit `f7bd03d`)
- **Thesis**: Any even modest gains in allocation efficiency will have disproportionate effect across the entire infrastructure — every part of the system creates cells and propagators at scale
- **Key findings**: `struct-copy prop-network` (13-field copy) is dominant cost; 25 call sites; 6 optimization opportunities identified preserving pure data-in/data-out contract
- **Top 3 optimizations**: (1) mutable worklist/fuel in quiescence loop, (2) field-group struct splitting (hot/warm/cold), (3) batch cell registration via existing transient CHAMP builder
- **Incremental GC**: Future consideration — network IS the provenance trail; understand provenance patterns before committing to self-GC work
- **Next step**: Create design document from audit, scope implementation phases, benchmark before/after
- **Not blocked on anything** — can be implemented independently of PUnify or Track 8

---

## Numerics Tower

### Phase 4: Float32/Float64
- 13 AST nodes per width (type, literal, add/sub/mul/div, neg/abs/sqrt, lt/le, from-nat, if-nan)
- Special values: ±Inf, NaN (multiple bit patterns, unlike Posit's single NaR)
- Cross-family conversions: Float↔Posit, Float↔Rat, Float↔Int
- Numeric trait instances: Add/Sub/Mul/Div/Neg/Abs/Eq/Ord for Float32/Float64
- Open: literal form for IEEE floats vs Posit (currently `~3.14` is Posit32)
- Source: `docs/tracking/2026-02-19_NUMERICS_TOWER_ROADMAP.md`

### Numeric Literal Polymorphism
- `42` polymorphic via `FromInt` — research/future
- Source: `docs/tracking/2026-02-22_NUMERICS_ERGONOMICS_AUDIT.org`

---

## Collections — Deferred Items

### Stage I: Transducer Runners for Non-List
- `into-vec`, `into-set` runners using transducer protocol + transient builders
- Pipe fusion for non-List input types
- **Blocked on**: transient types not exposed at Prologos type level;
  pipe fusion requires elaborator changes

### HKT Partial Application for Map Trait Instances
- Enable `Map K` as `Type -> Type` constructor
- Requires type-system-level partial application support
- **Blocked on**: unbuilt type system feature

### `Seq` as Proper Trait (deftype → trait migration)
- Enables trait resolver auto-dispatch for Seq
- Requires careful refactoring of deftype/trait boundary
- **Blocked on**: design uncertainty about deftype vs trait dispatch

### Clause-Style Constraint Matching (Layer 2 Specialization)
- Enable prioritized dispatch over disjoint trait constraints via `|` clause syntax
- Requires fallible trait resolution (try/fail instead of hard error)
- **Not blocked**, but separate from Layer 1 (fold+build doesn't need this)
- Source: `docs/tracking/2026-02-28_2200_CLAUSE_STYLE_CONSTRAINT_MATCHING.md`

### Sorted Collections (SortedMap, SortedSet)
- B+ tree or red-black tree backends
- **Blocked on**: backend infrastructure not yet built

### Parallel Collection Operations
- Parallel `map`/`filter`/`reduce` via Racket's places/futures
- **Blocked on**: runtime parallelism infrastructure

---

## Collections — Data Structures Roadmap

### Phase 3: Specialized Structures (NOT STARTED)
- 3a: SortedMap + SortedSet (B+ Tree)
- 3b: Deque (Finger Tree)
- 3c: PriorityQueue (Pairing Heap)
- 3d-3f: **Subsumed by Logic Engine** — LVars, LVar-Map/Set, PropNetwork
- 3g: Length-Indexed Vec (dependent types over collections)
- Source: `docs/tracking/2026-02-19_CORE_DATA_STRUCTURES_ROADMAP.md`

### Phase 4: Integration + Advanced (NOT STARTED)
- 4a: QTT Proof Erasure (erase type-level proofs at runtime)
- 4b: CRDT Collections (conflict-free replicated data types)
- 4c: Actor/Place Integration (cross-actor persistent collections)
- 4d: ConcurrentMap (Ctrie — lock-free concurrent hash map)
- 4e: SymbolTable (ART — Adaptive Radix Tree for string keys)
- 4f: **Subsumed by Logic Engine Phase 4** — UnionFind
- Source: `docs/tracking/2026-02-19_CORE_DATA_STRUCTURES_ROADMAP.md`

### Linear Enforcement for Transient Handles
- Transient handles should be used linearly (QTT `m1` multiplicity)
- Currently enforced by convention only
- **Blocked on**: QTT linear tracking for mutable handles
- Source: `docs/tracking/2026-02-20_0347_TRANSIENT_BUILDERS.md`

---

## String Library

### Phase 4a: Grapheme Cluster Operations
- `string-graphemes`, `string-grapheme-count`, grapheme-aware `string-reverse`
- Requires UAX #29 state machine (~30KB Unicode tables)
- **Mitigation**: FFI to Racket's `string-grapheme-span` or ICU library

### Phase 4b: Unicode Normalization
- `string-normalize : NormForm -> String -> String` (NFC/NFD/NFKC/NFKD)
- Bridge to Racket's `string-normalize-nfc` etc. via FFI

### Phase 4c: String Similarity & Diffing
- Jaro distance, common prefix, Myers difference
- Useful for "did you mean?" suggestions in error messages

### Phase 4d: Regex Integration
- Depends on a regex library (not yet designed)

### Phase 4e: Rope / TextBuffer Type
- B-tree rope with O(log n) concat/split

---

## Spec System — Phase 2+

### Phase 2: Example and Property Checking (QuickCheck-style)
- Type-check and run `:examples` entries as tests
- `Gen` trait for type-directed random generation
- Property checking for `:properties` and `:laws`
- Contract wrapping: `:pre`/`:post` generate runtime checks with blame
- Variance inference, `:compose`/`:identity` verification, `:exists` integration
- Source: `docs/tracking/2026-02-22_EXTENDED_SPEC_DESIGN.org`,
  `docs/tracking/2026-02-27_2300_SPEC_FUNCTOR_AUDIT.md` (Tier 3)

### Phase 3: Refinement Types and Verification
- `:refines` → Sigma types, `:properties` → compile-time proof obligations
- Proof search: `:proof :auto` triggers logic engine
- `:measure` for termination checking, opaque functors
- Source: `docs/tracking/2026-02-22_EXTENDED_SPEC_DESIGN.org`

### Phase 4: Interactive Theorem Proving
- Editor protocol for `??` hole interaction
- Case splitting, proof search, refinement reflection
- Source: `docs/tracking/2026-02-22_EXTENDED_SPEC_DESIGN.org`

---

## Syntax — Mixfix

### Statement-Like Forms in `.{...}`
- Keep `.{...}` purely expression-oriented for now

### `do` Notation Inside `.{...}`
- Prefer dedicated `do` blocks for monadic code

### `functor :compose` Auto-Registration of Mixfix Symbol
- Deferred due to coupling concerns

### Extended Pattern Matching in `.{...}`
- E.g., `.{n + 1}` → `suc n` (Agda view patterns)

### Phase 4: Advanced Mixfix
- Unicode operator symbols, postfix operators, full mixfix patterns
- Source: `docs/tracking/2026-02-23_MIXFIX_SYNTAX_DESIGN.org`

---

## Logic Engine / Propagator Architecture — Remaining

### Capabilities — Phase 8d: Multi-Agent Cross-Network Reasoning
- Separate agents on separate propagator networks cross-referencing via
  cross-network propagators, with dependent-typed proof objects as provenance
- **Blocked on**: session type design (Phase 9), dependent capabilities (Phase 7e-7g)
- Source: `docs/tracking/2026-03-01_1500_CAPABILITIES_AS_TYPES_DESIGN.md` §Phase 8d

### Galois Connections — Remaining Deferred
- `connect-domains` Prologos-level wrapper (needs AST keyword or FFI)
- Additional abstract domains (Congruence, Pointer, etc.)
- Source: `docs/tracking/2026-02-27_1026_GALOIS_CONNECTIONS_ABSTRACT_INTERPRETATION.md`

### Propagator-First Phase 3e: Reduction Cache Cells — NOT STARTED
- Convert whnf/nf/nat-value caches to write-through cells
- Gated behind `current-track-reduction-deps?` parameter (off for batch, on for LSP)
- **Risk**: Performance regression in batch mode
- Dependencies: Phase 3a (per-definition cells), Phase 3b (dependency recording) — both complete

---

## FL Narrowing — WS Surface Gaps

### Nested Constructor Patterns in Match Arms
- `| suc zero -> body` treats `zero` as a variable name, not the constructor
- Root cause: `parse-reduce-arm` doesn't recurse into `parse-single-pattern`
- **Workaround**: Use `defn` pattern clauses with double brackets
- Source: C2 investigation, 2026-03-08

### Higher-Order Narrowing in WS Mode
- `[apply-op ?f 3N 2N] = 5N` doesn't trigger HO narrowing via WS pipeline
- Infrastructure works at sexp/API level (23 tests pass)
- Fix requires deeper integration between narrowing substitution env and DT body traversal
- Source: C3 analysis, 2026-03-08

### Multi-arity `|` relation variants — zero-arg solve path
- `solve-goal`'s zero-arg path infers arity from first variant only
- Fix: iterate all variants or require explicit args for multi-arity rels

---

## Homoiconicity

### Phase IV: Runtime Eval & Read
- Runtime `eval`, `read`, `unquote-splicing` (`,@`), quasiquote `,x` in paren forms
- Source: `docs/tracking/2026-02-19_HOMOICONICITY_ROADMAP.md`

---

## Type System — HKT

### HKT-9: Constraint Inference from Usage
- Method-triggered constraint generation algorithm designed, gated behind feature flag
- Source: `docs/tracking/2026-02-20_2100_HKT_GENERIFICATION.md`

---

## Mixed-Type Maps

*(Type Narrowing for `map-get` — RESOLVED by CIU T6 F1a structural records; moved to
DEFERRED_COMPLETE.md at the 2026-07-16 F1b-opening triage.)*

### Pattern Matching for Union Values
- Convenience forms for matching on union values
- Source: `docs/tracking/2026-02-22_MIXED_TYPE_MAPS.md`

---

## Session Types — Concurrent Runtime

### Full Concurrent Session Execution (NOT STARTED)
- Buffered channels, `!!`/`??` runtime distinction, multiple concurrent prop-networks
- Distributed propagator scheduling, promise cell lifecycle, fairness guarantees
- **Blocked on**: Multi-network runtime infrastructure, Racket-level concurrency primitives
- Source: `docs/tracking/2026-03-03_SESSION_TYPE_IMPL_PLAN.md`

---

## IO Library

### Dependent Send/Receive (`!:`/`?:`) (Phase IO-J)
- Two small gaps: elaborator discards binder name, runtime predicates exclude dsend/drecv
- Reader, preparse, surface syntax, parser, IR, type-checker, pretty-printer are ALL complete
- **Not blocked** — can be implemented immediately
- Source: `docs/tracking/2026-03-05_IO_IMPLEMENTATION_DESIGN.md` §7

### IO Bridge Propagators (Phase IO-B)
- `io-bridge-cell` type, side-effecting IO propagator, wiring into `run-to-quiescence`
- **Blocked on**: Nothing
- Source: `docs/tracking/2026-03-05_IO_IMPLEMENTATION_DESIGN.md` §5

### Boundary Operations: `open`/`connect`/`listen` (Phase IO-C / IO-J)
- Capability-gated channel creation for external resources
- **Blocked on**: IO bridge propagators
- Source: `docs/tracking/2026-03-05_IO_IMPLEMENTATION_DESIGN.md` §6

### Opaque Type Marshalling (Phase IO-A1)
- `expr-opaque` wrapper struct for Racket values (file ports, db connections)
- **Blocked on**: Nothing
- Source: `docs/tracking/2026-03-05_IO_IMPLEMENTATION_DESIGN.md` §4

### `Path` Type (Phase IO-A2)
- Cross-platform file path abstraction (String wrapper initially)
- **Blocked on**: Nothing
- Source: `docs/tracking/2026-03-05_IO_IMPLEMENTATION_DESIGN.md` §8

### `Bytes` Type (Deferred to Phase 2)
- Binary data type. Not needed for text IO but needed for binary IO, SQLite FFI, network
- Source: `docs/tracking/2026-03-05_IO_LIBRARY_DESIGN_V2.md` §12.3

### CSV Maps — `parse-csv-maps`
- Header-aware CSV parsing returning `List [Map String String]`
- **Blocked on**: `map-from-pairs` function
- Source: IO-G plan

---

## Effectful Computation on Propagators — Remaining

### Phase 2: Architecture A+D — Propagator-Native Effectful IO (NOT STARTED)
- Session types as causal clocks, effect ordering via Galois connection
- 16 sub-phases across 6 phases (AD-A through AD-F)
- **Not blocked**: All phases buildable without concurrent runtime
- Source: `docs/tracking/2026-03-07_ARCHITECTURE_AD_IMPLEMENTATION_DESIGN.org`

### Phase 3: Full Reactive Effect Integration (RESEARCH)
- Architecture C — topological scheduling of effect propagators with freeze semantics
- **Blocked on**: Phase 2 completion
- Source: `docs/tracking/2026-03-06_EFFECTFUL_PROPAGATORS_RESEARCH.md` §5c

---

## Session Types — Parameterized/Indexed Sessions & Bounded Liveness

### Parameterized (Indexed) Session Types (RESEARCH)
- Session type definitions parameterized by a value from the dependent type level
- Multiplexed protocols (like CapTP) run N concurrent sub-sessions
- **Not blocked**: Dependent type infrastructure exists. Design work needed.
- Source: `docs/research/2026-03-07_ENDO_AS_SESSION_TYPES.org` §4.3, §15

### Bounded Liveness for Session Types (RESEARCH)
- Graduated roadmap: timeout branches → fuel-indexed recursive sessions → timed session types
- Both converge on parameterized session types
- Source: `docs/research/2026-03-07_ENDO_AS_SESSION_TYPES.org` §5.4, §15.2

---

## Propagator-First Elaboration Migration

### TMS-Aware Infrastructure Cells + Structural State — NOT STARTED
- Infrastructure cells and elab-network structural fields are NOT TMS-managed
- `restore-meta-state!` cannot be retired until this is addressed
- **Fix path**: (1) infra cells → TMS-aware via `net-new-tms-cell`, (2) meta-info/id-map → TMS cells
- **Placement**: PPN Track 4 (Elaboration as Attribute Evaluation) — putting elaboration on the network with formal propagator edges requires TMS-aware cells. Relabeled from "Track 8 prerequisite" (2026-03-30): PPN Track 4 IS the elaboration-on-network track.
- Source: Track 6 Phase 5b findings (commit `cb393bb`)

### Unify type inference and trait resolution under the propagator network — NOT STARTED
- Current elaboration uses propagator network for cells but NOT formal propagator edges
- Constraint solving driven by imperative retry loops, not propagator scheduler
- **Placement**: PPN Track 4 (Elaboration as Attribute Evaluation, IS SRE Track 2C). Relabeled (2026-03-30): this IS Track 4's core scope.
- Source: `docs/tracking/2026-03-11_1800_PROPAGATOR_FIRST_MIGRATION.md`

---

## Off-Network Registry Scaffolding (PM Track 12 consolidation)

**Context**: registries accumulate off-network across tracks as each track needs one. PM Track 12 ("module loading on network") is the designated consolidation track — it will both migrate existing off-network registries to on-network cells AND normalize their APIs into a unified shape.

**Principle** (established via dialogue 2026-04-19): building registries on-network per-track, without PM Track 12's unified design, risks divergent implementations that PM 12 still has to normalize. Disciplined off-network scaffolding + consistent API DNA across registries + explicit scaffolding labels is the lower-risk path. Migration from "Racket parameter holding a hash" to "cell with hash-union merge" is mechanical; migration from "N divergent on-network implementations" is re-architecture.

**Per-track registry tracking** — each track that adds a registry should append its entry here with the shape information PM Track 12 will need.

### PPN Track 4C registry additions

| Registry | Track / Phase | Status | API family / shape | Lifecycle | Retirement plan |
|---|---|---|---|---|---|
| Tier 2 merge-fn registry | 4C / Phase 1 | ⬜ planned | `register-merge-fn!/lattice` — keyword-arg style (align with existing `register-domain!` per Phase 1 mini-design audit, 2026-04-19) | Written at module load; read at `net-new-cell` for domain inheritance and at `net-add-propagator` for structural enforcement; no per-command reset | PM Track 12 migrates to cell; current shape is Racket parameter holding hash (merge-fn → domain-name) |
| `current-source-loc` parameter | 4C / Phase 1.5 | ✅ built 2026-04-19 | Racket parameter (not a keyed registry — single dynamic-scope value, similar class to `current-cell-id-namespace`, `current-speculation-stack`) | Set via `parameterize` at elaborate-entry (per surf-node srcloc field), driver command-entry (per command surf-node srcloc), and scheduler `fire-propagator` wrapper (per propagator struct srcloc field — on-network data). Read at emit sites (warnings, errors, future diagnostics) via `(current-source-loc)` | PM Track 12 evaluates during its scoping phase; may remain a parameter (dynamic-scope concept is parameter-shaped, not cell-shaped). Underlying DATA is on-network (surf-node srcloc fields, propagator struct srcloc field); the parameter is DERIVATION for reader convenience, not captured state |
| `hasse-registry-handle` Racket struct | 4C / Phase 2b | ✅ built 2026-04-19 | Racket-level struct (cell-id + l-domain-name + position-fn + subsume-fn) — lightweight wrapper around the on-network registry cell | Constructed at `net-new-hasse-registry`; held by consumers (Phase 7, 9b) and passed to `hasse-registry-register` / `hasse-registry-lookup` operations. Cell (entries storage) is ON-NETWORK; handle is OFF-NETWORK (Racket-level) | PM Track 12 evaluates shape — handle carries function references (position-fn, subsume-fn) which are Racket-runtime-meaningful only. Not a registry; a single-use per-instance metadata struct. May remain Racket-level OR migrate if PM 12 establishes a broader "handle-like value" pattern for registry wrappers |
| `current-process-id` parameter | 4C / Phase 1e-β-iii-a | ✅ built 2026-04-20 | Racket parameter (default 0) tagging Lamport timestamps at E1 clock writes. Defined in [`clock.rkt`](../../racket/prologos/clock.rkt). | Read at every `net-write-timestamped` call and every `net-new-timestamped-cell` call to tag the fresh timestamp with the process-id dimension. Under single-BSP (today) always returns 0. Future parallel workers parameterize per-worker. | PM Track 12 evaluates: (a) keep as parameter (dynamic-scope concept matches worker identity); (b) migrate to cell if worker identity needs network participation; (c) retire if BSP-round granularity becomes the natural process boundary. |
| `current-clock-cell-id` parameter | 4C / Phase 1e-β-iii-a | ✅ built 2026-04-20 | Racket parameter holding the cell-id of the global clock cell. Defined in [`clock.rkt`](../../racket/prologos/clock.rkt). Set via `net-allocate-clock-cell`. | Set at network initialization (clock cell allocated on main persistent-registry network). Read by consumer-side helpers that need fresh timestamps. Similar shape to `current-attribute-map-cell-id` (cell-id parameter for the attribute-map). | PM Track 12 decides clock granularity: (a) global clock (single parameter, session-wide ordering); (b) per-submodule clock (parameter resolved via scope chain); both keep the E1 Lamport shape in `clock.rkt`. |
| Hasse-registry primitive | 4C / Phase 2b | ⬜ planned | `hasse-registry` primitive parameterized by lattice L; SRE-registered lattice per §6.12 | Written at Phase 7 (impl entries) and Phase 9b (constructor entries); read at resolution time for O(log N) structural navigation | **TBD at Phase 7 mini-design** (M1 external critique finding) — write-path may be cell-write (on-network) OR `register-impl!`/`register-constructor!` scaffolding (PM Track 12). Decision applies to BOTH impl registry AND constructor catalog (M3 symmetric) |
| Impl registry | 4C / Phase 7 | ⬜ planned | Instance of Hasse-registry with L_impl (specificity lattice per §6.12.6) | Written at module load when `impl X Y` declarations elaborate; read during parametric trait resolution | Inherits Hasse-registry primitive's choice (see above) |
| Constructor inhabitant catalog | 4C / Phase 9b | ⬜ planned | Instance of Hasse-registry with L_inhabitant (subsumption lattice per §6.12.6) | Written at module load when `data X := ...` declarations elaborate; read during γ hole-fill | Inherits Hasse-registry primitive's choice (see above); M3 re-firing-on-growth semantics decided at Phase 9b mini-design |
| `current-process-id` parameter | 4C / Phase 1e-β-iii | ⬜ planned | Racket parameter (default 0) tagging Lamport timestamps at E1 clock writes | Read at every `net-write-timestamped` call to tag the new timestamp with the process-id dimension. Under single-BSP (today) always returns 0 — the pid carries no runtime information. Parameterized per-worker in future parallel-execution contexts. | PM Track 12 evaluates: (a) keep as parameter (dynamic-scope-shaped concept matches worker identity), (b) migrate to on-network cell (if worker identity needs network participation), or (c) retire entirely when BSP-round granularity becomes the natural process boundary. |
| `current-lattice-meta-solution-fn` callback parameter | 4C addendum S2.c-iii audit (2026-04-24) | ⬜ flagged | Racket parameter holding `meta-solution` function ([type-lattice.rkt:68](../../racket/prologos/type-lattice.rkt)). Installed by driver.rkt:2633 via `install-lattice-meta-solution-fn!`. Used by type-lattice.rkt:86, 176, 399, 403, 421 for `is-meta-unsolved?`-style checks during ground-check + subtype operations. Off-network scaffolding to break import cycle (type-lattice.rkt is leaf module; can't import metavar-store.rkt). | Set once at driver init via `install-lattice-meta-solution-fn!`; read on demand during type-lattice operations. **Mantra violations**: ❌ off-network, ❌ not structurally emergent (callback invocation is imperative), ❌ not info flow through cells. | **PM Track 12 + PPN 4C parent Phase 4 jointly retire**: when PM 12 makes module-load-time infrastructure on-network (cells accessible from leaf modules via scope chain), type-lattice.rkt's queries restructure to read directly from cells. Phase 4's CHAMP retirement provides the natural reframing point for the data flow (was reading CHAMP via callback → reads attribute-map facet via universe dispatch). See [PPN 4C parent Phase 4 row](2026-04-17_PPN_TRACK4C_DESIGN.md) for absorbed scope. The "constraint on shim signature" (post-S2.c-iii: `meta-solution` must remain a top-level definition with signature `(id) -> solution-or-#f` so the callback installation works) is not a feature — it's a constraint imposed by this scaffolding. |
| Per-domain meta-store parameters (3) | 4C addendum S2.d-followup audit (2026-04-25) | ⬜ flagged | `current-sess-meta-store` (metavar-store.rkt:2693), `current-mult-meta-store` (:2562), `current-level-meta-store` (:2465). Each is a Racket parameter holding `(make-hasheq)`. Off-network mantra violation; legacy from pre-network meta storage era. Parallel pattern across all 3 non-type domains. | Set at module-load via `make-parameter` default; read in fresh-X-meta + solve-X-meta! for status tracking. Coexists with `meta-domain-info` `'champ-fallback` entries that route to these stores when `'universe-active?` is #f. Post-S2.d (all 4 domains universe-active), the champ-fallback path is dead; these stores become unused. | **PM Track 12 retires**: submodule-scope primitive provides the natural retirement target — meta-store registry semantics migrate to per-submodule on-network cells. Until then, scaffolding labeled in D.3 §7.5.14.1. S2.e closes the per-domain factory + meta-store retirement together (parallel to type's `current-prop-meta-info-box` retirement timing in Phase 4). |
| Per-domain CHAMP-box parameters (3) | 4C addendum S2.d-followup audit (2026-04-25) | ⬜ flagged | `current-sess-meta-champ-box`, `current-mult-meta-champ-box`, `current-level-meta-champ-box`. Each holds a box of CHAMP for status tracking — parallel to type's `current-prop-meta-info-box`. Off-network. | Read in `meta-domain-info` `'champ-fallback` entries (e.g., `mult-champ-fallback`, `level-champ-fallback`, `sess-champ-fallback`). Post-S2.d all 4 universe-active → champ-fallback dead path → these boxes become unread. | **PM Track 12 retires** with the meta-store parameters above. S2.e closes the dead-path retirement before PM 12 lands. |
| Per-domain factory callbacks (3) | 4C addendum S2.d-followup audit (2026-04-25) | ⬜ flagged | `current-prop-fresh-mult-cell` (driver.rkt:2600), `current-prop-fresh-level-cell` (similar), `current-prop-fresh-sess-cell` (similar). Each is a Racket parameter holding a fresh-cell allocation closure. Used in fresh-X-meta legacy fallback path for pre-init test contexts. | Set at module-load with default `#f`; populated by driver.rkt during init. Read in fresh-X-meta legacy path (when universe is not initialized — bare-metavar-store tests not loading elaborator-network.rkt). | **PM Track 12 retires**: when test fixture infrastructure goes on-network, the pre-init fallback paths can collapse entirely — tests would call `init-meta-universes!` at setup. S2.e reviews whether these fallbacks remain needed; if not, retires before PM 12. Per D.3 §7.5.14.1 + §7.5.14.3. |
| `current-prop-mult-cell-write` write callback (1) | 4C addendum S2.c-iv adversarial VAG (2026-04-24) | ⬜ flagged | Racket parameter holding mult-cell write closure (driver.rkt:2605 → `elab-mult-cell-write`). Used in solve-mult-meta! legacy path. Note: level/session don't have analogous write callbacks — they use direct `elab-cell-write` in their legacy paths. Asymmetry is mult-specific (legacy artifact). | Set at module-load; read in solve-mult-meta! legacy fallback path only. Post-S2.c-iv mult universe-active, legacy path dead → callback becomes unread. | **PM Track 12 retires** with mult store/champ-box. S2.e could retire earlier (no PM 12 dependency for the callback itself; only the data store it writes to). Per D.3 §7.5.14.3. |

### parameter-lint baseline refresh (2026-06-01, during PPN 4C 4A.c-iii-c)

The 4A.c-iii-c -c gate surfaced that `racket tools/lint-parameters.rkt --strict` had been **silently failing** on **16 NEW unbaselined exported params** that accumulated across recent tracks without a baseline refresh (the guard rusted — it isn't wired into pre-commit/CI, so nothing ran it). Confirmed -c is lint-NEUTRAL (introduced zero new flags); the 16 are pre-existing drift, NOT -c's doing. Handled (separate from 4A.c, as orthogonal infra hygiene):

- **Triage**: all 16 have cross-module uses (3–68 each) → none cleanly private-izable; they are per-command-reset (via `reset-meta-store!` network recreation) / per-`elaborate` (`current-source-loc`) state, not per-test-isolation params → test-registering would mis-classify them. So **all 16 are irreducible exported state → genuine PM Track 12 (params→cells) agenda**; no avoidable debt to classify away.
- **`--save-baseline`** (commit alongside this entry): accepted the 16 as known-debt AND cleaned **18 stale entries** for params retired by earlier tracks (`current-speculation-stack` [1A-iii], `current-{level,mult,sess}-meta-{store,champ-box}` [S2.e-iv-c], `current-retracted-assumptions` [2B], `current-prop-{id-map,meta-info}-*` / `-mult-cell-write` / `-fresh-{level,mult,sess}-cell`, `current-ready-queue-cell-id`, `current-resolution-executor`, `current-in-stratified-resolution?`). Baseline now = 186 (accurate current unclassified set); `--strict` GREEN (NEW: 0). NOT laundered into -c (separate honest commit + this capture).
- **The 16 baselined params** (PM Track 12 cell-migration targets): the meta-universe per-domain cluster `current-{type,mult,level,session}-meta-universe-cell-id` + `current-{type,mult,level,session}-universe-merge` + `current-{type,mult,meta-solve}-universe-contradicts?` + `current-worldview-hasse-registry-handle` (from the S2.* universe migrations) + `current-domain-classification-lookup` (Phase 1f). The others (`current-source-loc`, `current-process-id`, `current-clock-cell-id`) are already tracked in the registry table above.
- **Stale DEFERRED rows**: the per-domain meta-store/champ-box/factory/write-callback rows above (S2.d-followup, 2026-04-25) describe params now RETIRED (confirmed by the baseline's stale-entry cleanup) — mark done in a future DEFERRED tidy.
- **Meta (operationalization)**: the guard rusted because `--strict` isn't run automatically. Decide later whether to wire it into the pre-commit hook / CI (else it re-rusts) — small follow-up, not 4A.c. Architectural endpoint: PM Track 12 migrates these to cells and obsoletes the lint entirely.

### PM Track 12 design input from PPN 4C Phase 1e-α (2026-04-20) — submodule-scope primitive

Phase 1e-α's η split of `merge-hasheq-union` surfaced a scope conflation in the current architecture that PM Track 12 is positioned to resolve. Core finding (from [PPN 4C D.3 §6.14.2](2026-04-17_PPN_TRACK4C_DESIGN.md)):

**"Identity-or-error" at a cell needs an answer to "identity within what scope?"** Today's flat shared-persistent-registry-network can't answer this — tests legitimately redefine names across runs, and that's correct behavior under the shared-fixture architecture, not a bug. Per-site identity classification is blocked until scope is first-class on the network.

**PM Track 12's submodule-scope mechanism is the structural answer**. Full discussion at [`2026-03-13_PROPAGATOR_MIGRATION_MASTER.md`](2026-03-13_PROPAGATOR_MIGRATION_MASTER.md) § Track 12, "Design input from PPN 4C Phase 1e-α (2026-04-20)." Summary of requirements this surfaces:

- Submodule as cell-space primitive (structural, not naming convention)
- Scope resolution for registry reads walks the scope chain
- Module reload = retract + reassert (extends S(-1) stratum pattern)
- Test-isolation flows from scope structure, not discipline
- Generalizes to LSP edits, REPL sessions, multi-module compilation

**32 identity-candidate migration sites** pre-identified in PPN 4C Phase 1e-α commit `876f3bf3`:
- 23 macros.rkt registry sites (all 23 `(define-values ... (net-new-cell ... merge-hasheq-replace))` pairs in `init-macros-cells!`)
- 1 namespace.rkt module-registry site
- 7 metavar-store.rkt per-elab store sites

Each currently uses `merge-hasheq-replace` (honest labeling of today's flat-scope semantics). When PM Track 12 provides submodule-scope, substitution to `merge-hasheq-identity` (already defined + SRE-registered as `'hasheq-identity`) is mechanical.

**5 additional timestamp-candidate migration sites** pre-identified in PPN 4C Phase 1e-β-iii-a (commit `4205b0ad` for primitive; migration deferred):

These are "snapshot cells of Racket parameters" — dual-store pattern where the Racket parameter is the live state and the cell is initialized as a snapshot at network-init time:

| Cell / site | Live parameter (to retire) | Current merge | After PM 12 |
|---|---|---|---|
| `narrow-var-constraints` cell at [global-constraints.rkt:104](2026-04-17_PPN_TRACK4C_DESIGN.md) | `current-narrow-var-constraints` | `merge-last-write-wins` | `net-new-timestamped-cell` |
| `ns-context` cell at [namespace.rkt:757](2026-04-17_PPN_TRACK4C_DESIGN.md) | `current-ns-context` | `merge-replace` | `net-new-timestamped-cell` |
| `defn-param-names` cell at [global-env.rkt:358](2026-04-17_PPN_TRACK4C_DESIGN.md) | `current-defn-param-names` | `merge-replace` | `net-new-timestamped-cell` |
| per-name definition cells at [global-env.rkt:121, 354](2026-04-17_PPN_TRACK4C_DESIGN.md) | `current-definition-cell-ids` (map) | `merge-replace` | `net-new-timestamped-cell` per name |

**Primitive ready** at [`clock.rkt`](../../racket/prologos/clock.rkt) (1e-β-iii-a, commit `4205b0ad`) with 17/17 tests GREEN. PM Track 12 activates: when the parameters retire (making cells primary state), the migration is mechanical and the timestamp-ordering becomes load-bearing. See [PM series master § Track 12](2026-03-13_PROPAGATOR_MIGRATION_MASTER.md) "Additional design input from PPN 4C Phase 1e-β-iii (2026-04-20)" for full context.

### PM Track 12 design input from PPN 4C Phase 1A-iii-a-wide Step 1 + T-1 (2026-04-22) — `with-speculative-rollback` retirement

PPN 4C 1A-iii-a-wide Step 1 completed TMS→tagged-cell-value substrate migration for on-network state. Remaining `elab-net` snapshot in [`with-speculative-rollback`](../../racket/prologos/elab-speculation-bridge.rkt) is **scaffolding** for off-network residue:

| Off-network store | Retirement track |
|---|---|
| `meta-info` CHAMP (metavar-store.rkt) | **Main-track PPN 4C Phase 4** |
| Constraint store | **PM Track 12** |
| `id-map` (elab-network struct field) | **PM Track 12** |

**PM 12 light cleanup sub-phase** (after Phase 4 + PM 12 core migration complete): mechanical retirement of `with-speculative-rollback` entirely. 6 caller sites migrate from `(with-speculative-rollback thunk success? label)` to `(speculate label thunk [#:success? success?])` (pure ATMS-tagged write + nogood, no snapshot). Expected ~20-30 min. Full detail in [PM Track 12 master](2026-03-13_PROPAGATOR_MIGRATION_MASTER.md) "Additional design input from PPN 4C Phase 1A-iii-a-wide Step 1 + T-1 (2026-04-22)."

6 caller sites:
- `typing-core.rkt:1205` (map-assoc), `:1291` + `:1325` (union-map-get-component + nil-safe-get), `:2439` (union-check-left)
- `typing-errors.rkt:78` (per-branch error enrichment)
- `qtt.rkt:2425` (checkQ union-left)

Replacement API shape (to be finalized at PM 12 cleanup sub-phase):
```racket
(speculate label thunk [#:success? success?])
  ;; Semantic: "provisionally run thunk under a fresh ATMS assumption.
  ;; If successful, commit; if not, record nogood and return #f."
  ;; Operational: pure ATMS tagging + nogood recording; no snapshot;
  ;; no elab-net box save/restore.
```

Callers don't change beyond form substitution — the `speculate` form is observationally equivalent to the current mechanism once off-network residue is gone (Phase 4 + PM 12 complete).

---

### Information PM Track 12 will want

For every entry in this section, PM 12 needs:
- **Name + API signature** — identifies the migration target
- **Lifecycle** — when written, when read, whether reset between commands (affects merge-function choice and TMS-awareness)
- **Reader count + shape** — informs whether readers can be redirected to cell reads or need API-level migration
- **API family** — identifies normalization targets; registries in the same family can share migration patterns
- **Current scaffolding label** — confirms the entry is intentionally off-network, not accidentally so

### Registries NOT (yet) catalogued

Existing pre-4C off-network registries (`register-domain!`, `register-typing-rule!`, `register-stratum-handler!`, `register-topology-handler!`, various Racket parameters across `prelude.rkt`, `namespace.rkt`, module-registry, trait-registry, etc.) are NOT itemized here — would require a separate cross-track audit. Deferred to PM Track 12's opening scoping phase, which will produce the comprehensive inventory. The discipline codified here (append per track) prevents 4C's additions from disappearing into that audit.

---

## Free Ordering on Network (PM Track 12B)

**Status**: ⬜ NOT STARTED — Stage-0 pre-design capture (2026-06-06). Full implementation note: [`2026-06-06_PM_TRACK12B_FREE_ORDERING_ON_NETWORK.md`](2026-06-06_PM_TRACK12B_FREE_ORDERING_ON_NETWORK.md). Master row: [PM Master § Track 12B](2026-03-13_PROPAGATOR_MIGRATION_MASTER.md).

**What**: achieve full **order independence** by retiring the imperative FREE_ORDERING multi-pass preparse (Pass −1/0/1/1.5/2 pre-registrations + the Phase-5b generated-decl hoist) and replacing it with uniform **on-network forward-ref residuation** — every forward reference residuates to fixpoint on the network. The multi-pass + hoist + synchronously-consulted off-network registries ARE the order-dependency scaffolding the lattice-fixpoint North Star wants to dissolve (`2026-02-28_1800_FREE_ORDERING.md`). Builds on PPN 4C Addendum Phase 4B's NET-1 δ residuation substrate.

**Why 12B not 12**: PM Track 12 is the mechanical registries→cells migration; PM 12B makes forward-refs *residuate* against those cells and *deletes* the imperative multi-pass. 12B **consumes** 12.

**Scaffolding to retire** (grounded @ HEAD `9cc752ea`; full inventory in the note §3):
- Pass-0/1 pre-registrations (`macros.rkt:2390–2460`); Phase-5b hoist (`:2876–2903`); the post-expansion **generated-name seeding** gap (Pass-1.5 is pre-expansion → can't see ctor/accessor names).
- The 3 synchronous typing env-reads (`typing-propagators.rkt:1771/2475/2644`, all NET-2) → wait on NET-1 cells (**the cross-network seam**; A3-narrow / §6 boundary).
- Forward-ref-gating off-network registries: `current-multi-defn-registry` (the multi-clause base-name permanently-`'pending` landmine), `current-relation-store` (defr), capability/schema/selection registries.
- The `loading-set` cross-module cycle check (`driver.rkt:~2132`) → lattice-fixpoint cycle diagnosis (PPN 4C addendum §18.11).

**Dependencies**: PM Track 12 (registries→cells, hard); PPN 4C Addendum Phase 4C/4D (cross-network seam + §6 diagnosis); PPN 4C Addendum Phase 4B (the NET-1 δ substrate). **NOT NTT** (speculative future syntax, not an implementation dependency — cross-network access is implemented directly in Racket).

**Origin / why deferred (genuine-dependency, not Let-Pain-Drive)**: PPN 4C Addendum Phase 4B.4 mini-design grounding (2026-06-06) established empirically that type-only producers (selection/capability/session) **already** forward-resolve via the imperative multi-pass — so the free-ordering work for them is *retiring* the scaffolding, which needs PM 12's cells + the 4C/4D cross-network seam. The pain is real; the substrate is the blocker. 4B.4 keeps only the annotated-path forward-ref residuation (tractable on the existing NET-1 δ); everything else lands here.

---

## Relational/Unification — PUnify Surface Gaps

### Module-path (`::`) resolution in defr clauses
- `str::concat` unbound inside `defr` clause bodies in `is` goals
- Root cause: `::` lookup doesn't resolve in relational elaboration context
- Source: acceptance file §H4, §K2

### solve-one type inference in defn body
- `solve-one` in `defn` body returns `_` type; `solve` works in same position
- Source: acceptance file §J

### `=` with prelude constructors in defr body
- Prelude constructors (some/none) in `=` goals inside `defr` fail
- Source: acceptance file §K

### Parameterized types in data constructor arguments
- `data Box A := box [List A]` fails with not-a-type-error
- Source: acceptance file §G

### `eq?` trait method not in prelude scope
- `Eq` trait's `eq?` not directly callable from prelude
- Workaround: concrete equality functions (`int-eq`, `str-eq`)
- Source: acceptance file §M

### head + match inference failure
- `[head '[1 2 3]]` followed by pattern match fails type inference
- Pre-existing issue, not PUnify-introduced
- Source: acceptance file §G6

### Narrowing limited to constructor-based patterns
- Functions with Int literal patterns compile to `boolrec+int-eq`, not invertible for narrowing
- Design limitation, not a bug
- Source: acceptance file §I

---

## Surface Syntax Issues

### WS-Mode `:=` Body Parsing with Multi-Form Bodies
- `def x : List Nat := cons 1N [cons 2N nil]` fails — `expand-def-assign` requires exactly one form after `:=`
- Fix: wrap multiple elements as implicit application
- **Not blocked**
- Source: `examples/unified-matching.prologos` Section 5

### Multi-Bracket defn Not Supported
- `defn f [a] [b] body` doesn't work in sexp or WS mode
- Standard pattern is uncurried single-bracket: `defn f [a b] body`
- **Not blocked**: requires parser extension
- Source: `examples/unified-matching.prologos` Section 11

### WS Mode Path Expression Disambiguation
- `.{` conflict between mixfix and path branching syntax
- Sexp mode works correctly. WS disambiguation deferred.
- Source: Phase 3e-e plan (2026-03-03)

---

## LSP / Editor Support

### Token-level srcloc precision for diagnostics
- Errors point to enclosing `defn` instead of exact token
- **Blocked on**: full propagator integration (cell-per-node architecture)
- Source: LSP Tier 2, commit `712c45a`

### Cross-module go-to-definition
- Only works for symbols defined in current file
- **Blocked on**: cross-module location tracking in module registry
- Source: LSP Tier 2, commit `12ea616`

---

## QTT / Multiplicity

### QTT multiplicity violation with generic trait-constrained functions in defn bodies
- Generic `map`/`filter`/`reduce` fail QTT checking due to erased trait dict params
- **Blocked on**: QTT rework for dict-param handling or propagator integration
- Workaround: use list-specific functions or keep expressions standalone
- Source: LSP Tier 4 testing

---

## Arithmetic / Operator Dispatch

### `+` `-` `*` `/` should work as higher-order generic functions
- Currently parser keywords, can't be passed to `map`/`reduce` or use `_` placeholders
- First-class wrappers (`plus`, `minus`, `times`, `divide`) exist as workarounds
- Source: LSP Tier 4 testing

### Trait-constrained functions can't be passed bare to higher-order functions
- `reduce plus 0 '[1 2 3 4 5]` fails — elaborator can't auto-insert dict args in HO position
- **Blocked on**: elaborator enhancement for automatic eta-expansion + dictionary insertion
- Source: LSP Tier 4 testing

---

## Propagator Observatory — Visualization Polish

### 5d: Bookmarked Rounds
- Source: `2026-03-12_PROPAGATOR_VISUALIZATION_DESIGN.md` Phase 5d

### 6a-6d: Polish and Integration
- Performance tuning, SVG/PNG export, contradiction diagnosis view, documentation
- Source: `2026-03-12_PROPAGATOR_VISUALIZATION_DESIGN.md` Phases 6a-6d

---

## Propagator Taxonomy — Extended Research

### Richer Taxonomy Beyond Track 7 Foundation
- Temporal, higher-order, distributed, adaptive, observational propagators
- Informs distributed/concurrent runtime and LSP integration
- **Blocked on**: Track 7 (now COMPLETE — foundation taxonomy established)
- Source: `2026-03-18_TRACK7_PERSISTENT_CELLS_STRATIFIED_RETRACTION.md` §2.6

---

## Coding Standards

### Nat-in-Computations Audit
- Replace `Nat` with `PosInt`/`Int` in computation examples and APIs
- `Nat` only for inductive/proof contexts
- Source: Session type design review (2026-03-03)

---

## Infrastructure / Performance

### Compiled Module Cache
- Persistent compilation cache keyed by module path + source hash
- Source: `docs/tracking/2026-02-19_PIPE_COMPOSE_AUDIT.md`

### Bytecode Compilation
- Compile `.prologos` to intermediate format, skip parse/elaborate/type-check
- Deferred until language stabilizes
- Source: `docs/tracking/2026-02-19_PIPE_COMPOSE_AUDIT.md`

### Batch-Worker Isolation: 12 Tests Fail in Suite, Pass Individually
- **Severity**: Medium — tests pass individually but fail in parallel batch runner
- **Symptoms**: 12 test files show unsolved dict-metas (`[?metaNNNN ...]`) in batch but resolve correctly when run individually via `raco test`
- **Root cause investigation** (Track 4B, commit `70a5763f`):
  - Added 12 missing constraint cell-id parameter resets to batch-worker.rkt — insufficient to fix
  - Cell-ids are correctly reset to `#f` per-file, but the divergence persists
  - Likely cause: `current-prop-net-box` state or elab-network setup differs between individual runs (fresh process) and batch context (shared process with parameterize isolation)
  - The on-network path (`infer-on-network/err`) may not activate in batch context if prop-net-box is stale/absent
- **Affected files**: test-collection-fns-01, test-eq-ord-extended-02, test-generic-ops-01-02, test-generic-ops-02-02, test-hasmethod-01, test-hkt-errors, test-kind-inference-where, test-prelude-system-01, test-punify-integration, test-reducible-02, test-trait-resolution, test-where-parsing
- **Not blocked on**: Track 4B mechanism is correct (all pass individually). This is a test-runner infrastructure issue.
- **Next step**: Audit `current-prop-net-box` lifecycle in batch-worker vs individual test runs. Check whether `infer-on-network/err` is even reached in batch context or falls back immediately.
- **Source**: Track 4B Phase 3 (commit `74f79506`), batch-worker fix (commit `70a5763f`)

---

## Future Track 4D Scope: Per-Command Transient Cell Consolidation

**Source**: PPN 4C addendum Step 2 S2.e mini-design (2026-04-25). Surfaced during S2.e measurement audit — `cell_allocs` cumulative measurement reveals the dominant cell allocation cost is per-command transient elaboration, not persistent meta storage. Step 2's universe consolidation addressed PERSISTENT meta cells (the right charter), but the bottleneck the §5 hypothesis was framed for (cells/cell_allocs targets) is in per-command transients.

**Concrete data** (from probe verbose, post-S2.d at HEAD `34972bac`):
- Persistent network: 54 cells (was 50 pre-Step-2 — only +4 net change because per-meta consolidation savings approximately offset by universe + hasse-registry + compound-merge infrastructure cells)
- `cell_allocs` cumulative: 1181 (was 1071 pre-Step-2 — +110)
- Per-command breakdown: ~30-50 cells per command × 28 commands = ~1100 transient allocations dominating cell_allocs

**Per-command cell sources** (each allocates ~30-50 transient cells):
- Attribute-record cells per AST position
- SRE structural decomposition sub-cells (`decompose-pi` allocates dom + cod + mult per Pi)
- Per-command spec/FormCell registration cells
- Typing-propagator scratch cells (per-command typing sub-network)

**Why this is Track 4D scope (not S2.e or any current track)**:
- Step 2's PU consolidation pattern (4 universe cells for N metas) APPLIES to other repeated allocation sites — but they're broader than meta storage
- Track 4D's thesis ("collapse fragmented typing/elaboration/reduction subsystems into a unified attribute-grammar substrate") subsumes per-command consolidation conceptually
- Per-command attribute-record allocations could share an enclosing namespace-level PU under the unified substrate
- This is research-stage; concrete designs await Track 4D's Stage 1-3 cycle

**Forward scope candidates** (not exhaustive — Track 4D's mini-design will refine):
- **Per-command attribute-record PU**: each command's positions could share a per-command compound cell
- **SRE structural decomposition sub-cell consolidation**: Pi-PU consolidates dom + cod + mult sub-cells
- **Per-command spec/FormCell registration**: subsumed into Track 4D's grammar-rule compilation

**Cross-references**:
- PPN 4C Phase 9 Design §7.5.14.4 (track-internal capture; full per-command breakdown table)
- Track 4D research vision §5.4 (forward-pointer in 4D's research doc; added 2026-04-25)
- This DEFERRED.md entry (cross-track tracking — ensures the work isn't missed across the multi-month Track 4D timeline)

**Track 4D Stage 2 audit obligation**: when Track 4D's Stage 2 (gap analysis) opens, measure transient allocation patterns to characterize the consolidation opportunity quantitatively (concrete site enumeration with allocation counts).


---

## SRE Track 2I Phase 3c → PM Track 12 input: callback-style parameters in type-lattice.rkt

**Origin**: SRE Track 2I Phase 3c (2026-04-30) retired `current-lattice-subtype-fn` (Racket-parameter callback in `type-lattice.rkt`) in favor of a per-relation `meet-registry` field on `sre-domain`. The principled retirement template is documented in [SRE Track 2I Design](2026-04-30_SRE_TRACK2I_SD_CHECKS_DESIGN.md) § Phase 3c.

**Sister callback awaiting PM Track 12**: `current-lattice-meta-solution-fn` (`type-lattice.rkt:68`)

- **Pattern**: `make-parameter` callback installed at driver init (`driver.rkt:2637`); changes algebraic behavior of `type-lattice-merge`/`try-unify-pure` based on whether install was called.
- **Surface area**: 5+ usage sites across `has-unsolved-meta?`, `try-unify-pure`, multiple `try-intersect-pure` branches (`type-lattice.rkt` lines 86, 176, 399, 403, 421).
- **Cross-cutting concern**: ties to metavar-store internals (`metavar-store.rkt:2324` references the callback).
- **Scope rationale**: significantly larger than the subtype callback Phase 3c addressed; appropriate for PM Track 12's module-load-time parameter migration scope.

**Retirement template** (from Phase 3c, applies to meta-solution callback by analogy):
1. Identify the structural concern the callback masks (here: implicit polymorphism — meta-aware merge depends on driver init order).
2. Replace with explicit parameter or per-relation registration (correct-by-construction).
3. Drop the callback parameter + install function + lint-baseline entry.
4. Update consumers to pass the explicit parameter (or use the registry accessor).
5. Update tests that implicitly relied on the callback.

**Phase 3c bonus precedent**: the principled refactor surfaced an algebraic finding (the type lattice under equality merge was distributive post-Track-2H, but the always-installed callback was hiding it via mixed equality+subtype semantics). Expect similar surfacings when retiring the meta-solution callback — the callback may be hiding meta-handling assumptions that become visible only with explicit dispatch.

**Cross-references**:
- [SRE Track 2I Design](2026-04-30_SRE_TRACK2I_SD_CHECKS_DESIGN.md) § Phase 3c (retirement template)
- [PM Master Track 12](2026-03-13_PROPAGATOR_MIGRATION_MASTER.md) § Phase 3c precedent for callback-style parameter retirement
- [Issue #40](https://github.com/LogosLang/prologos/issues/40) — sister anti-pattern (with-handlers defensive scaffolding); both are off-network state injection
- `tools/lint-parameters.rkt` + `tools/parameter-lint-baseline.txt` — tactical interim



---

## PPN 4C tropical addendum: hybrid pivot scaffolding retirement — RETIRED-PER-D.4-CANONICAL (2026-05-14)

**Status (2026-05-14)**: RETIRED. The hybrid pivot SCAFFOLDING never shipped. Under the D.4 architectural reframing (Cell/Propagator/Scheduler Orthogonality principle codified `6a628bc7`), the §13.6 Pre-0 spike (commit `7b681b9e`) directly measured the specialized cell type framework's fast-path performance and falsified the hybrid pivot's empirical motivation (Pre-0 R-19 extrapolation). The cell IS the live state under D.4 canonical — no scaffolding to retire later.

**Spike results that falsified the hybrid motivation**:
- W1+ specialized cell-write (with realistic dispatch overhead): **6.4 ns/call** (target ≤ 30 ns; ~4× under)
- W3 GC at 5×100k decrements: **0.000 ms major-GC** (target ZERO; structurally guaranteed by direct fixnum mutation)
- W3 alloc (10×100k decrements): **1.1 KB** (vs Pre-0 A7.3 struct-copy 6251 KB — **5700× memory improvement**)
- W4 specialized cell-read: **0.8 ns/call** (target ≤ 15 ns)
- W1+ + W4 per-decrement cycle: **7.3 ns** (target ≤ 45 ns)

**What this entry would have tracked** (preserved for historical record): under D.3 hybrid pivot, the per-decrement fuel-cost cell migration was scaffolded as off-network struct field (PRIMARY) + cell (DERIVED via lazy sync). The retirement was deferred to SH Series runtime infrastructure. The discipline added a four-surface tracking matrix (this DEFERRED.md entry + GitHub Issue #55 + D.3 §10.1.A retirement plan + Q-1B-6 falsification gate) to ensure the scaffolding wasn't forgotten.

**Why this is RETIRED rather than DELETED**: the entry serves as a record of the alternative design considered + the discipline applied. The discipline itself (four-surface tracking; falsification gate before locking in a principle-violating commit) is valid prophylactically for future tracks; this entry serves as a worked example. The "Hot-Load Is a Protocol, Not a Prioritization" pattern from DEVELOPMENT_LESSONS.org applies: don't delete the historical record of design alternatives considered.

**Cross-references**:
- [GitHub Issue #55](https://github.com/LogosLang/prologos/issues/55) — closed as "superseded by D.4 principled on-network design"
- [D.4 design doc](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md) §10 — D.4 canonical direct migration (replaces D.3 hybrid)
- [D.4 design doc](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md) §13.6 — Pre-0 spike plan + result
- [§4.6 Specialized cell type framework](2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md) — the canonical D.4 architecture
- Spike implementation: `racket/prologos/benchmarks/micro/bench-specialized-cell-spike.rkt` (throwaway; commit `7b681b9e`)
- Spike result data: `racket/prologos/data/benchmarks/tropical-spike-d4-2026-05-14.txt`
- D.3 historical sections marked RETIRED-PER-D.4-CANONICAL: §10.1.A (Honest framing + retirement plan), §10.A (Threshold propagator role under hybrid), §10.B (Cell Staleness Contract), §14.4 Q5 (dual classification)
- [DESIGN_PRINCIPLES.org § Cell / Propagator / Scheduler Orthogonality](principles/DESIGN_PRINCIPLES.org)
- [DEVELOPMENT_LESSONS.org § Cell/Propagator/Scheduler Orthogonality](principles/DEVELOPMENT_LESSONS.org)

---

## PPN 4C addendum 3C.c-VAG named drift (KR-1/2/3) + 3C.d.3a empirical probe artifact

**Status (2026-05-24)**: NAMED DRIFT — escalated to Phase 11b per addendum §9.5.5.4 Q-D.1 (c) ESCALATE-with-substrate decision. Tracking debt paid up-front via:
1. This DEFERRED.md entry
2. Skip-gated parity test `'union-diagnosis-restoration "Phase 11b"` at [`tests/test-elaboration-parity.rkt`](../../racket/prologos/tests/test-elaboration-parity.rkt) (3C.d.4 deliverable 4)
3. Parent D.3 Phase 11b row "Scope addition (2026-05-24) — KR-1/2/3 absorption" (3C.d.4 deliverable 7)
4. Test rename at [`tests/test-provenance-errors.rkt`](../../racket/prologos/tests/test-provenance-errors.rkt):359 reflecting partial deferral (3C.d.4 deliverable 5)

**Source**: PPN 4C addendum [§9.5.4.14 KR-1/2/3 named drift](2026-04-21_PPN_4C_PHASE_9_DESIGN.md) (captured at 3C.c-VAG close 2026-05-24, commit `25f4343c`) + [§9.5.5 Phase 3C.d mini-design](2026-04-21_PPN_4C_PHASE_9_DESIGN.md) Q-D.1 lock + [§9.5.5.13 empirical findings](2026-04-21_PPN_4C_PHASE_9_DESIGN.md) (commit `ebf56b80`).

### KR-1: Diagnosis-line UX regression (union error rendering)

**Pre-3C.c behavior**: `(def x <Nat | Bool> "hello")` produced rendered error output including `[diagnosis] retract: x : <Nat | Bool>` line via `build-derivation-chain`'s `format-context-diagnosis` (typing-errors.rkt:173-280).

**Post-3C.c behavior**: under the new `(listof derivation-chain)` shape (Q-B.2 + Q-C.6 flip), per-step `because: <name>` lines render via `derivation-step-assumption-names`. The `[diagnosis] retract:` line is GONE. ATMS state queries (`solver-state-explain-hypothesis`, `solver-state-minimal-diagnoses`) at render time DEFERRED per §9.5.4.4 Q-C.4 lock.

**Restoration decision (3C.d.0 Q-D.1)**: 3 options weighed via 3-column adversarial framing:
- (a) RESTORE at 3C.d via ATMS state queries — REJECTED (inverts 3C.c design intent; render-time staleness hazard; KR-3 grows)
- (b) ESCALATE to Phase 11b with timeline commitment — REJECTED (unbounded deferral; "pragmatic" rationalization)
- (c) ESCALATE-with-substrate — LOCKED

**Phase 11b inheritance**: Phase 11b mini-design RE-WEIGHS (a)/(b)/(c) variants with trace-monoidal-category-theory framing (Joyal-Street-Verity 1996; Hasegawa 1997; Abramsky-Haghverdi-Scott 2002) as research input. The skip-gated canary's `[diagnosis] retract:` substring assertion captures the PRE-3C.c shape; Phase 11b's chosen restoration shape may differ — canary updated alongside restoration.

**Restoration path infrastructure (per §9.5.5.1 T2 audit)**: `solver-state-explain-hypothesis`, `solver-state-assumptions`, `solver-state-minimal-diagnoses`, `nogood-explanation` struct, `assumption` struct, `greedy-hitting-set` algorithm all present + battle-tested. `build-derivation-chain` + `format-context-diagnosis` + `format-atms-conflict` (typing-errors.rkt:173-280) STILL IN PRODUCTION for the NON-union path (type-mismatch-error). Restoration would be MECHANICAL GLUE (~50-100 LoC) re-calling existing helpers in union path — NOT new infrastructure.

### KR-2: Derivation-step field sparsity for sexp-fed steps

**Description**: Under `(listof derivation-chain)` shape, derivation-step has 5 fields: `propagator-id` + `srcloc` + `assumption-ids` + `assumption-names` + `residual-cost`. The sexp translator (`derivation-chain-for/union-check` at [`error-explanation.rkt`](../../racket/prologos/error-explanation.rkt):391+) hardcodes `propagator-id=#f` + `srcloc=#f` for sexp-fed steps (no propagator; speculation-failure doesn't track srcloc). 2/5 fields are `#f` for sexp-fed steps.

**Enrichment path**: when sexp typing unifies on-network (PPN Track 4D "Attribute Grammar Substrate Unification" + Phase 11b), sexp-fed steps gain propagator-id + srcloc STRUCTURALLY. The fields are forward-compatible (LSP-ready; per §9.5.2.2 Q-A.8 invariant); no breaking change required at restoration.

**Phase 11b inheritance**: enrichment naturally lands when Phase 11b implements general `derivation-chain-for(position, tag)` primitive (per parent D.3 Phase 11b row scope).

### KR-3: Two-shape error infrastructure (union new shape + non-union old shape coexist)

**Description**: post-3C.c, two error-rendering shapes coexist:
- **Union path** (3C.c shipped): `union-exhaustion-error` with `derivation-chain: (listof derivation-chain)` field (`errors.rkt`:135); per-step `because: <name>` rendering.
- **Non-union path** (pre-3C.c unchanged): `type-mismatch-error` with `provenance: (listof string)` field (`errors.rkt`:65); `because: <line>` rendering plus `[diagnosis] retract:` lines via `build-derivation-chain` + `format-context-diagnosis`.

**Unification target**: Phase 11b's general `derivation-chain-for(position, tag)` primitive unifies both shapes via single API. Trace-monoidal-category-theory framing (Joyal-Street-Verity 1996) provides theoretical grounding for the general chain construction.

**Phase 11b inheritance**: design + implement unified API; retire dual shapes atomically.

### 3C.d.3a empirical probe artifact

**Artifact**: `racket/prologos/data/probes/2026-05-24-3C-d-3-w1-empirical-probe.rkt` (Racket source, runs via `racket file.rkt`) + `racket/prologos/data/probes/2026-05-24-3C-d-3-w1-empirical-output.txt` (captured stdout).

**Purpose**: Three regimes × five scenarios capturing empirical W1 srcloc state at 3C.d.3 close. Critical finding (Scenario B): W1 dispatch chain threads parameterized `current-source-loc` through `process-fork-on-union` → propagator-struct → `static-reverse-walk` → derivation-step end-to-end. Empirical evidence FLIPPED pre-empirical (β.3.ii) leaning to (β.3.i) post-empirical (see addendum §9.5.5.13.2).

**Phase 11b use**: re-runnable empirical baseline. When Phase 11b mini-design opens, the probe can be re-run to:
- Verify current dispatch-chain srcloc state (regression sanity-check)
- Compare pre-Phase-11b vs post-Phase-11b srcloc threading
- Audit production sexp-path srcloc readiness (currently #f BY DESIGN per D-3C.c-1; Phase 11b restoration changes this)

**Probe design**: uses `(module+ main)` pattern so the check-stdout-clean pre-commit hook's dynamic-require doesn't see intentional stdout output. New convention for `.rkt` artifacts in `data/probes/`.

### Cross-references

- Source design: PPN 4C addendum [§9.5.4.14 (KR-1/2/3 named drift)](2026-04-21_PPN_4C_PHASE_9_DESIGN.md) + [§9.5.5 (3C.d mini-design)](2026-04-21_PPN_4C_PHASE_9_DESIGN.md) + [§9.5.5.13 (3C.d.3 empirical findings)](2026-04-21_PPN_4C_PHASE_9_DESIGN.md)
- 3-column adversarial Q-D.1 lock: [§9.5.5.4](2026-04-21_PPN_4C_PHASE_9_DESIGN.md)
- Parent D.3 Phase 11b row: [PPN Track 4C D.3](2026-04-17_PPN_TRACK4C_DESIGN.md) Progress Tracker Phase 11b (2026-05-24 scope addition)
- Skip-gated canary: [`tests/test-elaboration-parity.rkt`](../../racket/prologos/tests/test-elaboration-parity.rkt) `'union-diagnosis-restoration "Phase 11b"`
- Test rename: [`tests/test-provenance-errors.rkt`](../../racket/prologos/tests/test-provenance-errors.rkt) "renders per-step assumption-names (diagnosis lines deferred to Phase 11b — see KR-1)"
- Restoration substrate (still live for non-union path): [`typing-errors.rkt:173-280`](../../racket/prologos/typing-errors.rkt) (`build-derivation-chain` + `format-context-diagnosis` + `format-atms-conflict`)
- Phase 11b research input: trace monoidal category theory (Joyal-Street-Verity 1996, Hasegawa 1997, Abramsky-Haghverdi-Scott 2002 — see parent D.3 Phase 11b row)

## FREE_ORDERING migration to propagator-native module loading — captured at PPN 4C Phase 4 mini-design (2026-05-25)

The `macros.rkt:2366-2460` `preparse-expand-all` 3-pass mechanism + `tools/form-deps.rkt` SCC analysis delivers **name-level residuation at preparse time** (3-pass pre-registration of declaration names: ns/imports → no-dep declarations → spec+impl → main loop). Per Audit C (PPN 4C addendum §18.10.4): this is imperative scaffolding that delivers name-level residuation; Phase 4 introduces value-level residuation at elaboration time; the two layers compose.

**User direction (2026-05-25)**: *"having an imperative multi-pass parsing would be a regression for the lattice-fixpoint compiler that we hold as our North Star vision. This work should likely also migrate and be updated to our propagator-native approaches. Sounds like work to be done on module-loading on network, though; not in current scope."*

**Scope clarification**: FREE_ORDERING migration is **scaffolding with retirement plan** — to be migrated to propagator-native cell-based name registration in module-loading-on-network follow-up work. NOT in Phase 4 scope. Phase 4 preserves the preparse layer; module-loading-on-network work retires it.

### Migration target

Replace 3-pass imperative preparse with propagator-native cell-based name registration:
- Declaration names (data/trait/deftype/defmacro/bundle/property/functor + spec + impl) write to registry cells at preparse-equivalent time
- Body elaboration residuates on registry cells for name resolution
- Module-level cycle detection becomes lattice-fixpoint diagnostic per §18.11 cyclic definitions handling principle

### Cross-references

- Source audit: PPN 4C addendum [§18.10.4 (FREE_ORDERING at preparse layer)](2026-04-21_PPN_4C_PHASE_9_DESIGN.md) + [§18.5 (PM 12 boundary)](2026-04-21_PPN_4C_PHASE_9_DESIGN.md) + [§18.11 (cyclic definitions principle)](2026-04-21_PPN_4C_PHASE_9_DESIGN.md)
- Original FREE_ORDERING design: [`2026-02-28_1800_FREE_ORDERING.md`](2026-02-28_1800_FREE_ORDERING.md)
- Literate book context: [`2026-02-28_1400_LITERATE_BOOK_SYSTEM.md`](2026-02-28_1400_LITERATE_BOOK_SYSTEM.md) Phase 5a/5b/5c
- Implementation: `macros.rkt:2366-2460` (`preparse-expand-all`), `tools/form-deps.rkt` (SCC analysis)
- Module-level cycle detection (related, same retirement target): `driver.rkt:1872-1874` (`loading-set` "Circular dependency detected")
- Future track (where this retires): module-loading-on-network follow-up — PM Track 12 + post-Phase-4 + possibly PPN Track 4D coordination

## Rel T1 A.2b DFS-routing scaffolding → BSP-LE Track 3 (captured 2026-07-19, commit `bcd02d6d`)

The A.2b minimal slice added **Check 3** in the adaptive dispatcher
(`stratified-eval.rkt` `use-propagator?` → `reachable-has-body-local-rule?`): a
would-be-on-network NAF/guard query whose reachable relation graph has a **rule
clause with a body-local (non-param) variable** routes to **DFS** (the correct
reference solver), because the on-network ATMS rule engine cannot thread body-local
clause vars (clause-env is param-only; `resolve-term` returns a bare symbol) →
join/recursion generators are INCOMPLETE on-network (`twohop`→`{}`, `reaches`→base
case only; probe-verified).

**This is scaffolding with a named retirement plan.** It is honest engine-selection
(not off-network scaffolding bolted on), but it exists only because the on-network
rule engine is half-built.

**Retirement owner: BSP-LE Track 3** (Tabling / SLG memoization, ⬜ unbuilt). When
Track 3 lands (a) on-network **body-local-var threading** (reuse `collect-clause-vars`,
today DFS/explain-only) + (b) **SLG completion detection** (for recursive termination)
+ (c) **worldview-preserving table answers** (PUnify Part 3 §9.6 support-set:
unconditional=∅ memoize across worlds, conditional worldview-filtered —
`2026-03-19_PUNIFY_PART3_ATMS_SOLVER_ARCHITECTURE.md:612-620`, designed-but-never-built),
**delete the Check-3 predicate** and these shapes flow back on-network.

### Cross-references

- Landed slice: commit `bcd02d6d`; design `2026-07-19_REL_T1_RELATIONAL_USABILITY_DESIGN.md` §5 A.2b (reframed).
- Grounding + options synthesis (carry into Track 3's Stage-3): workflows `wf_c2f8bfa3-db2` (grounding-audit) + `wf_9c6eb408-522` (options-panel) — dailies `2026-07-19_dailies.md` LOG.
- Prior art for the worldview layer: PUnify Part 3 §9.6 (support-set-tagged table reads).
- The four co-change sites for the eventual on-network table format: table cell born plain (`atms.rkt:459`), tag-blind `table-answer-merge` (`atms.rkt:100-101`), `net-cell-write` tag-gate (`propagator.rkt:1993`), producer `logic-var-read`+flat-write (`relations.rkt:2743/2751`).

## Rel T1 A.4 guard DFS-routing scaffolding → BSP-LE Track 3 (captured 2026-07-20, commit `6b56397d`)

The A.4 minimal slice added **Check 4** in the adaptive dispatcher (`stratified-eval.rkt`
`use-propagator?` → `reachable-has-guard?`): a would-be-on-network query whose reachable
relation graph contains a `guard` goal routes to **DFS** (the correct reference solver for
guards, ground + free-var, single + multi-fact).

**Why**: on-network guards have three real bugs — (a) `resolve-condition-from-net` didn't
recurse into struct condition exprs (`expr-generic-gt`) so the condition var stayed
unresolved and the guard default-passed; (b) the single shared guard bit `G` can't filter
a multi-fact generator per-row (`install-conjunction` tags every row `(G|Bi)`); (c) an S0
belief-narrow is re-projected away (`worldview-cache` is derived from decisions-state via
`install-worldview-projection`, `propagator.rkt:969`). AND guards live only in tabled rule
clauses, so their generator inherits the A.2b tabling seam above.

**This is scaffolding with a named retirement plan.** Honest engine-selection (guards go to
the solver that handles them), not off-network scaffolding.

**Retirement owner: BSP-LE Track 3.** The full on-network guard mechanism was **prototyped
+ verified** during A.4 (struct-resolution fix + per-binding guard belief-clear [the S0
analogue of `naf-per-binding-mask`, a pure `eval-fn(subst)`, no fork] + a **between-round
handler** [guard-pending cell + `process-guard-request` mirroring `process-naf-request`,
required by bug (c)]) and reverted for the simpler DFS-route. It deploys once Track 3 lands
worldview-preserving tabling (so guard generators materialize per-branch tags). Then
**delete the Check-4 predicate**.

### Cross-references

- Landed slice: commit `6b56397d`; design [`2026-07-19_REL_T1_RELATIONAL_USABILITY_DESIGN.md`](2026-07-19_REL_T1_RELATIONAL_USABILITY_DESIGN.md) §5 A.4.
- **Track 3 seed (both issues + prototyped designs)**: [`2026-07-20_BSP_LE_TRACK3_ONNET_SEED.md`](2026-07-20_BSP_LE_TRACK3_ONNET_SEED.md).

## Rel T1 Aspect C, C.d — `?x:Int` runtime domain-constraint (types-as-predicates) → UCS Track 6 (captured 2026-07-21)

Aspect C closed at **C.a + C.b + C.c** (owner, 2026-07-21). The remaining piece — **C.d**,
statically activating a declared `?x:Int` param type as a typing source for un-schema'd rule
relations — is **DEFERRED to a UCS track**, NOT a Rel T1 deliverable.

**Why**: a **schema** is a checked contract on **fact relations** (static, altitude-1 — that
IS what Rel T1 delivered: C.c's schema⟹facts-only gate + the existing fact-row checking). But
`?x:Int` on a **rule** logic-var is a **guard / unary domain-constraint `Int(x)`** (altitude-2,
runtime) — its "static upper bound" is really the guard's static projection, sound only once
the guard prunes at runtime. That is constraint-solving-over-value-domains = larger UCS work.

**Nothing is lost by deferring**: C.b already STORES the type-preds on `param-info`
(`param-info-type`, 0 consumers, store-only) and shipped the fused `?x:Int` reader in both
readers/languages. The UCS track inherits the substrate + bridges it to the existing
(dead-in-WS) `?var:C1:C2` narrowing → `type-guard` runtime mechanism.

### Cross-references
- **Retirement owner: UCS Track 6** ([`2026-03-28_UCS_MASTER.md`](2026-03-28_UCS_MASTER.md) Progress Tracker).
- **Handoff note (the full settled design + verified coordinates + known gaps)**: [`2026-07-21_UCS_TYPES_AS_PREDICATES_NOTE.md`](2026-07-21_UCS_TYPES_AS_PREDICATES_NOTE.md).
- Rel T1 design: [`2026-07-19_REL_T1_RELATIONAL_USABILITY_DESIGN.md`](2026-07-19_REL_T1_RELATIONAL_USABILITY_DESIGN.md) §7.5 (RESOLVED) / §7.6 (C.d) / §7.7 (deferred + non-monotone S(-1) cap).
- Grounding-audit: `wf_ab037f07-570` (guard machinery + fix options).
- BSP-LE Master Track 3 retirement obligation: [`2026-03-21_BSP_LE_MASTER.md`](2026-03-21_BSP_LE_MASTER.md).
- **Process note**: the A.4 investigation was lengthened by a WS-syntax probe error (one-line fact rows `|| 5 3` parse as one wrong-arity row → spurious empty results, masqueraded as a tabling failure). Probes need multi-line fact rows.

## Solver term conversion drops pvec/map literals — unify with a collection literal yields `unknown` (captured 2026-07-25, surfaced by Rel T1 B3.2's mini-audit)

**PRE-EXISTING, live, and a static/runtime DISAGREEMENT.** Unifying a relational
variable with a collection LITERAL produces the runtime value `unknown`, while
the static type is derived correctly:

```
defr mp [?x ?m]
  &> (edge x z) (= m {:a 1})

solve (mp x m)
;; '[{:m unknown, :x 1} …] : [List {:m {:a Int} :x Int}]
;;        ^^^^^^^ runtime            ^^^^^^^^ static — they disagree
```

Same for `(= v '[1 2])` (there the static side holes, so only the runtime
`unknown` shows). Scalars are fine (`(= tag "lit")` → `"lit" : String`), so the
gap is specific to the collection literals in the AST↔solver-term conversion
(`normalize-ast-to-solver-term` / `solver-term->prologos-expr`).

**Why it matters beyond cosmetics**: (a) B3.1 derives the row type correctly, so
this is the one place where the static row type and the actual row provably
disagree — the CbC key/type agreement B3.0 worked to preserve; (b) it BLOCKS the
only reachable surface case of B3.2's FILL path (a hole-typed field whose values
are ground); (c) the DEMO through-line loads records as facts (`:from`), which is
adjacent territory.

**Not chased** at discovery: B3.2's scope was the display seam, and this is a
solver-representation defect. The B3.2 FILL path is unit-pinned so it is correct
the day this lands.

### Cross-references
- Surfaced by: Rel T1 B3.2 mini-audit (2026-07-25), design §6.10.
- Probe: `(= m {:a 1})` / `(= v '[1 2])` in a rule body, then `solve`.

## Substitution containment defect — runtime collections as closed leaves (captured 2026-07-24, spin-out from Rel T1 POL.10)

> **✅ RESOLVED 2026-07-25 for the BVAR half** — ruling (D) + the NbE fix.
> `f19d6f56` (tripwire) · `6323587e` (compile-limit adoption, an independent win
> found here: suite −18%) · `7ea49168` (**the fix**: NbE open-the-binder in `nf`)
> · `036b59f7` (narrowing containment — the wider sibling) · `8ec5e507`
> (hot-scan, 6.9×). The repro now prints `5N`/`6N` at 0 errors; the tripwire
> stays installed as the standing invariant assertion. Full record + the
> post-fix reading of the traversal table: defect doc §2.0.
>
> **STILL OPEN — the META half (own slice, not folded silently):** the fix
> closed *de Bruijn index* containment; `zonk` / `zonk-at-depth` /
> `default-metas` / `occurs?` skip on **metas**, which NbE says nothing about.
> Post-fix reachability is **UNVERIFIED** — one surface probe (`def m := {:a 3}`,
> `{:v 3.5}`) typed and displayed correctly, which only shows that route doesn't
> reach them. `occurs?` is the higher-stakes one (an unsound occur-check admits
> cyclic solutions). Next step is a probe of a champ carrying an *unsolved* meta
> through zonk and through `occurs?`; also `conv-nf` (independent, unverified).
>
> ⚠ **NEW COUPLING — GitHub #58 P3 (`94cfbcbd`, 2026-07-27) constrains this slice.**
> `loose-bvar.rkt` memoizes each term's loose-bvar range in a weak **`eq?`-keyed**
> table, sound today precisely *because* `shift`/`subst` are the identity on
> `expr-meta` (substitution.rkt:49, :542) — so a term containing an unsolved meta
> correctly reports range 0. But a meta's SOLUTION lives off-node in
> metavar-store and is filled in mid-command while the expr node's identity stays
> fixed. **The moment any walker learns to follow meta solutions, that memo goes
> stale-by-construction** and must be invalidated on `solve-meta!`
> (`clear-loose-bvar-cache!` is exported for exactly this). Do not land the META
> half without revisiting it. Recorded in loose-bvar.rkt's memo comment too, so
> the constraint is visible at the code as well as here.
>
> Everything below is the ORIGINAL capture, kept as the diagnosis of record.

**LIVE BUG — a silent wrong answer in legal, zero-error user code.** `shift`/`subst`
(and `zonk`/`zonk-at-depth`/`default-metas`/`nf`/`uses-bvar0?`/`occurs?`/`conv-nf`/
`narrow-subst-bvars`) treat the six runtime collection values (`expr-champ`, `expr-hset`,
`expr-rrb` + the three transients) as closed no-descend leaves. `subst` drops the beta
argument; `shift` fails to renumber → silent variable capture. Verified reproduction: a
`defn` whose lambda body is a **map literal** leaks `?bvar0 : Nat` to top level with
**0 errors** (control differing only in the body shape gives the correct `6N`).

**~37 arms across 7 traversals.** Decisive history: `nf`'s `expr-rrb` arm was changed
from identity to **descending** six days after CHAMP landed (`9fc669bb`); the same fix
was never applied to `expr-champ`/`expr-hset` or to any other traversal. Discipline
recognised and repaired at exactly one site, ad hoc. `tests/test-substitution.rkt` has
**zero** champ/Map coverage — the invariant existed only as a false comment.

**Blocked on ONE OWNER RULING**: is `expr-champ` a **closed runtime value** (the F1b
RETIRED-LOUD position ⇒ fix = stop minting under binders + NbE open-the-binder in `nf`,
recommended) or an **open AST container** (⇒ fix = all 37 arms, keys included)?

**Staging** (full analysis in the design doc): (1) NOW, days-scale, no ruling needed —
failing regression tests + a tripwire at the three `nf`-persisting boundaries
(`reduction.rkt:570`/`:698`/`:1458`), NOT at shift/subst and NOT at the mint;
(2) `PLT_CS_COMPILE_LIMIT` is unset repo-wide and `shift`/`subst` (~337 arms each) fall
back to the CS interpreter — an independent, possibly large win, UNVERIFIED in-tree;
(3) spun-out track for the real fix.

**Widened by**: any eager-`nf` re-attempt · Rel T2 Fact Store · BSP-LE Track 3 ·
CIU T6 Path Selection · **PReduce e-graph (hard blocker — it normalizes under binders
by construction)**.

⚠ A green full suite is NOT a gate here — the suite is green with the bug live.

### Cross-references

- **Design doc / full analysis**: [`2026-07-24_SUBSTITUTION_CONTAINMENT_DEFECT.md`](2026-07-24_SUBSTITUTION_CONTAINMENT_DEFECT.md).
- Surfaced by Rel T1 POL.10: commits `cf454176` (reverted trial + post-mortem), `095d8bc5` (landed whnf resolution).
- Grounding: workflow `wf_468a6129-447`.

---

## Rel T1 POL.9b — the `def` seam swallows solve diagnostics + rejects row-type annotations (captured 2026-07-25, X.close triage)

**PRE-EXISTING, shared by BOTH spellings** (parity-probed: the implicit
`def r := (goal)` and the explicit `def r := solve (goal)` produce
*byte-identical* messages, so POL.9b neither caused nor worsened this — it
inherited it and pinned it).

Two distinct gaps at the same seam:

1. **Guiding diagnostics don't reach the def seam.** `def bad := (dbl 3)`
   (or `:= solve (dbl 3)`) dies with the generic *"Expression is not a valid
   type"* — the def arm type-checks the body BEFORE evaluation, so the runtime
   classifier (`raise-unknown-relation-error`, relations.rkt) never fires and
   the user never sees *"dbl is a function — application is written [dbl …]"*.
   At top level the same program gives the good message. Fix direction: give
   the def seam a pre-typing goal-head validation, or make the solve row-type
   computation surface a typed error instead of a non-type.
2. **Row-type annotations on `def` don't parse.**
   `def r : [List {:f String}] := (goal)` → "Expression is not a valid type",
   though the very same type is what the echo PRINTS for the unannotated def.

**Pinned**: `tests/test-rel-t1-pol.rkt` § "POL.9b: def-seam PARITY on bad heads"
asserts message EQUALITY between the two spellings, so a fix to either is
visible immediately.

**Owner**: unclaimed — a small Rel-adjacent slice; touches the driver def arm +
typing-core's solve row-type path.

---

## Rel T1 POL.9c — the `defr`-against-prior-multi-arity-`defn` direction is UNGATED (captured 2026-07-25, by design; unblocks at **PM 12/12B**)

> Routed 2026-07-25: the blocker is the multi-defn registry's lack of module
> provenance, which PM Track 12 removes by bringing it on-network — see
> [PM 12B §11.4](2026-06-06_PM_TRACK12B_FREE_ORDERING_ON_NETWORK.md) item 1
> and 12B §7 Q3.

### Original entry

Q_B (defn/defr namespaces disjoint) gates three directions: `defr` over a local
`def`/`defn`, `def`/`defn` over a local `defr`, and a multi-arity `defn` BASE
name over a local `defr` (all at driver.rkt `check-crosskind-collision`).

The FOURTH direction — a `defr` whose name is already a **multi-arity `defn`** —
is deliberately **not** gated: multi-arity base names live only in the ambient
`current-multi-defn-registry` (multi-dispatch.rkt), which carries **no module
provenance**. Gating against it would fire on prelude multi-defns (`nth` and
friends) and so would violate the local-only rule that keeps refer-import
shadowing legal (the `lib/examples/foray.prologos` `xor` precedent).

**Unblocks when**: the multi-defn registry gains module provenance (i.e. moves
onto the per-module network like the def cells did in PPN 4C 4A) — at which
point the fourth direction can be gated with the same local-only discipline.

---

## ✅ RESOLVED (2026-07-25, X.close Batch C `cdb535ac`) — un-arm'd node → spurious "Multiplicity violation"

> **Root was NOT what this entry recorded.** The trigger was logged as
> `def := [validate …]`; probing showed `expr-validate` has a proper `inferQ`
> arm that DELEGATES to its subject — the subject (a map whose value was a
> LAMBDA) was the problem. `inferQ` carried an `expr-lam` arm only inside the
> beta-redex case, so a lambda in INFER position fell to the catch-all. Fixed
> by adding the arm (TYPE delegated to typing-core, USAGE mirroring checkQ).
> The class is promoted to BOTH tiers: `pipeline.md` checklist item 8 (ambient,
> actionable + the debug rule) and `DEVELOPMENT_LESSONS.org` § "infer / inferQ
> Are Twins" (the record). Kept below for the history.

## (historical) Un-arm'd AST node → spurious "Multiplicity violation" — 3rd data point (captured 2026-07-25)

**A recurring BUG CLASS, not a single defect.** When an AST node has no `inferQ`
arm, qtt's tu-error fallback propagates the failure and `checkQ-top` reports the
generic *"Multiplicity violation"* — a message with no relationship to the
actual problem. Three confirmed instances:

| # | Trigger | Status |
|---|---|---|
| 1 | `def m0 := {}` (CIU T6 F1a.2) | fixed |
| 2 | `def x := solve (…)` (Rel T1 POL.5, `485f4e7d`) | fixed |
| 3 | `def m := {:f [fn …]}` (first SEEN through `validate`, 2026-07-24) | ✅ fixed `cdb535ac` |

**Two actions, both owed:**
- *Fix instance 3* — the same shape as POL.5's one-arm fix.
- *Promote the CLASS* to `DEVELOPMENT_LESSONS.org`: at 3 data points this is
  codification-ready. The lesson is diagnostic, not just corrective — **a
  "Multiplicity violation" on a `def` whose body is a non-lambda should be
  suspected as an un-arm'd node before it is believed as a QTT result.** The
  structural fix direction is the `pipeline.md` § "Exhaustive Walkers" answer
  applied to `inferQ`: a generic fallback that contributes zero usage rather
  than a tu-error, so a missing arm degrades to imprecision instead of a
  false failure.

---

## Generated `.md` twins are STALE relative to their canonical `.org` sources (captured 2026-07-25, X.close doc-truth)

`workflow.md` states `.org` is canonical and the `.md` is a generated export.
The X.close doc-truth sweep corrected the overstated performance claims in
`LANGUAGE_VISION.org` and `RELATIONAL_LANGUAGE_VISION.org`; their `.md` twins
still carry the OLD text (`grep -c "30ms" RELATIONAL_LANGUAGE_VISION.md` → 2).

**Why it matters**: an agent (or a person) grepping the principles directory can
land on the `.md` and read a claim the `.org` has already retracted — precisely
the failure the sweep was fixing. The twins need regeneration from org-export,
and it is worth deciding whether the `.md` exports should exist in-tree at all
(they have no consumer that the `.org` doesn't serve).

---

## ✅ RESOLVED (2026-07-25, X.close ruling Q_N1) — the goal keywords now take the implicit solve

> **Owner ruled option (A)**: whitelist all three. `goal-keywords` in
> `parser.rkt` is `{rel, not, =, is}`, **derived from `run-solve-goal`'s
> dispatch set** so it cannot drift from the engine; `guard`/`cut` stay out
> because a top-level solve does not dispatch them either. `(not (blocked "c"))`,
> `(= 1 1)` and `(is q 5)` are now byte-identical to their explicit `solve`
> spellings (test-pinned, incl. def-RHS parity). The functional readings live
> on the bracket spelling — `[not true]`, `[= 1 1]` — which is the delimiter
> convention's own. One corpus line changed: `narrowing-demo.prologos`'s
> `(= ?x 5)`, whose comment was updated (it was already being used as a query).

### Original entry

**A real ergonomic hazard, not cosmetic.** POL.9's `paren-goal-stx?`
(`parser.rkt`) requires a **non-keyword** head (plus `rel`). `not`, `=` and `is`
are parser keywords, so at top level:

```
(not (blocked "c"))
;; => [reduce [(defr blocked …) "c"] | true -> false | false -> true] : Bool
```

— i.e. **functional Bool negation applied to a stuck goal term**, computing
nothing useful and reporting **0 errors**. A user who has internalized "parens
make goals" writes exactly this and gets a silently-useless answer. The explicit
`solve (not (blocked "c"))` works (it is the A.1 deliverable).

**Why it is the way it is**: the keyword exclusion is what protects `(match …)`,
`(+ 1 2)` and `(= ?x 5)` from being read as goals; `not`/`is`/`=` ride that
exclusion incidentally rather than by decision.

**Options** (needs an owner ruling, not a unilateral fix):
1. Whitelist the GOAL keywords (`not`, `=`, `is`) alongside `rel` in
   `paren-goal-stx?` — smallest change; makes the surface uniform.
2. Leave the exclusion and add a DIAGNOSTIC when a paren-`not` at command
   position wraps a goal-app (point at `solve (not …)`).
3. Document only (done — `.claude/rules/prologos-syntax.md` § Relational
   syntax now carries the warning).

Option 1 interacts with the functional `not` on Bool, which is why this is a
ruling and not a patch.

---

## ✅ RESOLVED (2026-07-25, `bb45d2a0`) — the acceptance file is now gated; POL L3 rides it. PARTIAL: POL internals still lack unit tests

> **Closed**: gaps (1) and (2). `tests/test-rel-t1-acceptance.rkt` (32 cases) runs
> the file through `process-file`, asserts 0 errors, verifies every marker, and
> RANGE-CHECKS marker indices. All markers rewritten against actual output —
> **30/30 pass, was 5/28**. Running `--check` also exposed that the POL.8/POL.9
> markers were MISNUMBERED (off by one and two), which the range check now
> catches. **Still open**: `test-rel-t1-pol.rkt` remains Level-2 throughout
> (0 `process-file`), so the POL cluster's L3 coverage runs through the
> acceptance gate rather than through cases of its own; and the POL parser
> internals (`regroup-flat-lines-by-layout`, `parse-clause-content`,
> `paren-goal-stx?`, `check-crosskind-collision`) still have ZERO unit tests.

### Original entry

Three compounding testing gaps, verified:

1. **`examples/2026-07-19-rel-t1-acceptance.prologos` is gated by nothing.**
   No test references it (`grep -rln rel-t1-acceptance tests/` = ∅); no golden
   exists for it; `compare-golden-for-file` has zero callers in `tests/`. Its
   0-errors status was verified by hand every phase — a discipline, not a gate.
   If it regresses, the suite stays green.
2. **~13 of its 28 `;;N=>` markers are PROSE**, so even a manual `--check` run
   cannot pass them (the checker does exact match).
3. **The whole POL cluster is L2-only in the suite**: `test-rel-t1-pol.rkt` has
   **0** `process-file` calls against **84** `run-ns-ws-last`. `testing.md`
   mandates three-level WS validation for syntax features, and POL.7/8/9 are
   syntax features. The sibling files (`-naf`, `-typed-rows`, `-typed-vars`) DO
   call `process-file` — the pattern was available and simply not applied here.
   L3 coverage for POL therefore rests entirely on gap (1), which is ungated.

**Fix direction**: add a suite test that runs the acceptance file through
`process-file` and asserts 0 errors (cheap, closes 1+3 at once); convert the
prose markers to real `;;N=>` expectations or drop the `=>`; add `process-file`
cases for the POL.8/POL.9 grammar.

---

## Rel T1 — `current-relation-store` is not threaded into test-support or batch-worker (captured 2026-07-25; pre-existing, design-acknowledged)

`grep -c current-relation-store` = **0** in BOTH
`racket/prologos/tests/test-support.rkt` and
`racket/prologos/tools/batch-worker.rkt`. Consequence: in the `run-ns*` and
batch-worker contexts the relation store is not the ambient one, so `solve`
types as untyped where production would type it — **silently**. Design §6.9
recommended threading it and accepted the gap.

This is instance **#7** of the two-context boundary bug class that
`pipeline.md` § "New Racket Parameter" (items 2+3) exists to prevent — the
checklist names exactly these two files. Worth treating as an architectural
signal rather than a seventh individual fix: the class recurs because the
parameter set is discovered by grep rather than declared in one place.

---

## ✅ RESOLVED (2026-07-25, `bb45d2a0`) — SC now has its regression test

> Three cases in `test-rel-t1-pol.rkt` run through `run-ns-ws-last`
> (== `process-string-ws`, the exact path SC fixed): a NAMED `solver` config
> with `solve-with` (the owner's literal blocker), inline `{overrides}`, and
> the `:semantics` key. Each asserts the "should have been expanded" failure
> cannot recur.

### Original entry

`19d9f8ae` fixed an owner-reported blocker (`process-string-ws` dropped
preparse-macro support, so `solver` configs failed in the REPL/LSP path) with
+12/−17 in `driver.rkt` and **zero new tests**. The commit cites "130 REPL/LSP/WS
tests pass" — that is pre-existing regression evidence, not a pin on the fixed
behavior. No test anywhere spells `solver cfg` / `:tabling` (grep = 0), so the
exact regression would not be caught again. Phase SC is also still 🔄 in the
tracker. `workflow.md` permits a no-test commit only for "refactor with zero
behavioral change"; this was a behavioral fix.

**Fix**: add a `process-string-ws` test that defines a named `solver` config and
runs `solve-with` against it.

---

## Rel T1 POL.9 Q_D slice 2 → **PM Track 12B § 11** (owner-routed 2026-07-25)

> **Owner ruling at X.close**: this is not a Rel concern — it is the SAME
> forward-reference-residuation problem PM Track 12B owns, arriving from a
> second namespace. Full design capture:
> [`2026-06-06_PM_TRACK12B_FREE_ORDERING_ON_NETWORK.md`](2026-06-06_PM_TRACK12B_FREE_ORDERING_ON_NETWORK.md) **§11**
> (why it is not the "fast-follow" the Rel design called it — grounded;
> the PM 12 → 12B dependency chain; the acceptance/parity gate; and the two
> adjacent Rel T1 items that resolve there, incl. the 7th two-context instance).
> It is the exact sibling of 12B §7 Q3 (multi-defn registry).

### Original entry

The settled POL.9 design (§8, Q_D) has two slices: slice 1 = "Unknown relation"
via the POL.4 `exn:prologos-solve` presentation (**shipped** in 9a), slice 2 =
wire goals into the EXISTING demand-residuation loop so a goal over a
later-defined relation retries when the `defr` lands (free-ordering behavior, no
new propagator substrate). Slice 2 was called "fast-follow" and never built;
`residuation-demand-name` (`driver.rkt`) is still def-path only. The POL row is
marked ✅, which over-states completion.

---

## ✅ RESOLVED (2026-07-25, `bb45d2a0`) — the merge FUTURE-TRAP is test-pinned

> A layout canary in `test-rel-t1-pol.rkt` runs the nested-`not` form through
> the L2 path; if the merge winner flips to the srcloc-stripped tree surf, the
> column info is gone, the nesting collapses, and the test fails at the point
> of change rather than silently.

### Original entry

Adding a `defr` arm to `driver.rkt`'s `surf-source-line` / `same-form-type?`
(e.g. while extending the preparse/tree merge for an unrelated reason) would
silently flip the L2 winner for `defr` to the **srcloc-STRIPPED** tree-spine
surf, breaking POL.8's column-based layout grammar with no test failure at the
point of change. Named in design §8 prose; not filed, not test-pinned.

**Fix direction**: a test that asserts POL.8 layout still parses under
`process-string-ws` (the L2 path) would fail loudly if the merge winner flipped.

---

## Rel T1 — `docs/spec/grammar.ebnf` predates the POL syntax cluster (captured 2026-07-25)

The formal grammar describes none of what shipped: `clause-body = '&>' , { goal }`
(no parenless goals, no layout), `fact-row = expr , { expr }` (no `|` row
separators), goals always parenthesized (no implicit solve), and `rel-params` has
no `:`-type alternative (C.b.1's fused `?x:Int`). It also still describes the
dead-in-WS `?var:C1:C2` narrow-var surface, which now COLLIDES with C.b.1's
spelling. The `.org`/`.md`/`.tex`/`.pdf` renderings inherit all of it.

---

## Substitution / reduction perf — spin-offs from GitHub #58 (captured 2026-07-27)

Three items surfaced by the #58 grounding audit + implementation that were
deliberately NOT swept into the fix. #58 itself is CLOSED (P0–P4: `5a2e57a3`,
`3fce3ed0`, `cf1791ce`, `94cfbcbd`, `4a2bbee3`); design doc
`2026-07-27_SUBSTITUTION_QUADRATIC_BLOWUP_DESIGN.md`.

### 1. `substS` in sessions.rkt has the SAME O(N²) shape, unfixed

`racket/prologos/sessions.rkt:85-86` — `(substS cont (add1 k) (shift 1 0 e))` is
the identical binder-crossing re-shift that #58 fixed in `substitution.rkt`, but
it lives outside that file and was left alone. It is a **fourth walker in the
same family** (with `shift`, `subst`, `zonk-at-depth`); the grounding critic
flagged the family as "already out of sync".

**Why deferred, not effort-avoidance**: session types are not on any measured hot
path today, and #58's scope was the reducer. The fix is mechanical once wanted —
`shift-arg`'s guard applies verbatim. **Do it when session-typed code gets a real
workload**, or fold it into any track that touches `sessions.rkt`.

### 2. `zonk-at-depth` re-shifts per meta occurrence

`racket/prologos/zonk.rkt:557` does `(shift depth 0 zonked-sol)` once per meta
occurrence, with depth incremented at each binder (:590/:592/:594). Same shape:
a solution term re-walked once per occurrence. Unmeasured — it may be entirely
fine, since solutions are usually small. **Measure before fixing**; #58's whole
lesson is that the layer you assume is the cost usually isn't.

### 3. The whnf/nf cache is now `eq?`-keyed — its hit rate is UNMEASURED

#58 P2 (`cf1791ce`) changed all three per-command caches from `equal?` to `eq?`
keying, which was a 15.7× win at N=256 and suite-neutral. But it necessarily
**loses structural hits**: on the accumulator workload `hasheq` benchmarked
indistinguishable from *no cache at all*, which is the honest reading that the
cache was doing nothing useful there — not evidence it does nothing useful
anywhere. Nobody has measured the hit rate on type-checking-heavy workloads with
genuinely repeated structural subterms.

**If it turns out to matter**, the principled fix is a memoized cheap structural
hash (or hash-consing — survey option #4), **not** reverting to the O(N³)
`equal?` key. Cheap first probe: add hit/miss counters to `whnf` and run the
comparative bench.

## CIU T6 D4.P1b-ii spin-offs (filed 2026-07-28, owner-ruled Q_N2)

### 1. `.( )` mis-groups at the TREE layer — a live LAYER DIVERGENCE

`dot-lparen` is absent from `surface-rewrite.rkt` entirely (`git grep -n
dot-lparen HEAD -- racket/prologos/surface-rewrite.rkt` → 0 hits), so `.(` falls
to `group-items-to-tree`'s `[else]` arm (:539-540) as a bare token and the first
`)` closes the ENCLOSING group at :504-506. Probe-verified at `09a1f0d7`:

```
(a .( b ) c)
  DATUM: ((a ($mixfix b) c))                        ;; c RETAINED
  TREE:  (root (line (paren-group a |.(| b) c))     ;; c EXPELLED
```

**Zero errors.** The two grouping implementations disagree — this is the
`31d27c83` "layers must agree" defect class at a third layer that commit's own
comment does not cover.

**Why deferred, not effort-avoidance** [owner ruling Q_N2]: it is not fixable by
adding an arm. (a) The `'mixfix-group` tag and its ~445-line consumer were
DELETED at D4.P1a, so a new arm has no tag to emit but `'paren-group`, which
erases the mixfix distinction. (b) The angle-suppression half needs a `'mixfix`
FRAME concept that `group-items-to-tree` does not have at all — a design change,
not an arm. (c) No test pins `.( )` at the tree layer (every `dot-lparen` test
hit is tokenizer-level), so any shape change would ship unguarded.

**Do it when**: a track touches the mixfix surface, or `group-items-to-tree`
grows a frame concept. P1b-ii's `dot-lbrace` is deliberately justified on its own
terms (Q_M5's plain-`'rbrace` closer) rather than by analogy to this sibling —
"match your siblings" would have inherited the bug.

### 2. Three group tags ride the SILENT tree-parser fallthrough — benign or not, unverified

`set-group`, `at-group` and `tilde-group` are minted at surface-rewrite.rkt
:519/:527/:528 and have **zero** tree-parser dispatch arms and zero non-test
consumers (verified at `09a1f0d7`). They therefore take tree-parser.rkt:189-193
`[else (if (pair? children) (parse-expr-tree children loc) …)]` — which is
**silent** for any node with children and produces a `surf-app`. Combined with
driver.rkt:2457-2459 (tree output wins when non-error ∧ same-form-type ∧
same-line), a garbage surf can beat preparse's correct one.

This may be entirely benign — preparse may always win these by form-type
mismatch — but **nobody has verified it**, and P1b-ii's Q_N1 ruling cites the
"a new tag needs an arm" obligation as absolute while three in-tree tags violate
it. Resolve the inconsistency: either they are fine (and the obligation is
narrower than stated), or they are three latent silent-garbage paths.

**Cheap first probe**: feed `#{…}`, `@[…]`, `~[…]` through the tree layer and
check whether the tree-parser result is admitted or rejected by the merge.

### 3. Reader sentinels that are still MACRO PATTERN VARIABLES (`$set-literal`, `$mixfix`)

`pattern-var?` (macros.rkt:1144+) excludes eleven reader sentinels, but **not all
of them**. Probe-verified at D4.P1b-ii: `(pattern-var? '$set-literal)` → `#t` and
`(pattern-var? '$mixfix)` → `#t`, while their ten siblings return `#f`.

Consequence: a `#{…}` set literal or a `.( … )` mixfix group inside a **defmacro
template** makes `datum-subst` raise `"Unbound pattern variable in template"` —
an uncaught raise at preparse, i.e. a **WHOLE-FILE ABORT with zero results**.
Adversarially confirmed for `$mixfix`:

```
defmacro getm [$u] [$u.(a + b)]      ;; + a use site  →  whole-file abort
```

**Pre-existing — NOT introduced by P1b-ii** (which hit the identical defect for
its own new `$dot-brace`, found it in adversarial verify, and fixed it in the
same commit). Filed rather than widened silently, because the fix is a one-line
exclusion per sentinel and the *interesting* question is the structural one:

**The real fix is not more exclusions.** `pattern-var?` is a hand-maintained
NEGATIVE list whose default is "this is a pattern variable" — the same inverted
polarity that `definitely-not-map?` had before CIU T6 P2.b slice 1 inverted it to
a positive list with a conservative default. A `$`-prefixed *reader sentinel* is
never a user's pattern variable; the predicate should ask whether the symbol is a
DECLARED macro parameter, not whether it is absent from a list someone remembered
to update. Every new sentinel is otherwise a latent whole-file abort.

**Do it when**: a track touches macro expansion, or the next new sentinel lands.
Cheap first probe: enumerate every `$`-headed symbol the reader can emit and run
`pattern-var?` over the set.

> ✅ **DISCHARGED 2026-08-01 — commit `446070fc`, as the structural fix this
> entry asked for, not as more exclusions.**
>
> Both triggers had fired: the `:` mint (`b1399016`) landed a new sentinel
> (`$bcast-step`), and the def-seam work was touching macro expansion.
>
> The prescribed probe was run first and the count was worse than this entry
> knew: **24** reader-minted `$` heads were absent from `pattern-var?`, not two.
> Among them `$nat-literal`, `$rat-literal`, `$list-tail`, `$pipe-gt`,
> `$quasiquote`, `$unquote`, `$rest`, `$typed-hole` — so a defmacro template
> containing an ordinary **`5N`**, **`1/2`** or **`|>`** was a whole-file abort,
> not just the exotic `#{…}` / `.( … )` this entry names.
>
> Fix taken is the one prescribed: `datum-subst` now asks whether the symbol is a
> DECLARED macro parameter — i.e. a key in `bindings` — instead of consulting a
> negative list. Sentinels are correct by construction and a newly-minted one can
> never reintroduce the class.
>
> A/B on this entry's OWN two examples, base `969bfd6c` vs `446070fc`:
>
> | example | base | after |
> |---|---|---|
> | `defmacro getm [$u] [$u.(a + b)]` + use | ABORT, zero results | file completes; 1 per-command error |
> | `#{1 2 3}` in a template + use | ABORT, zero results | file completes; 1 per-command error |
>
> ⚠ Scope of the discharge, stated precisely: the **whole-file abort** is gone —
> which is what this entry filed. `.( … )` and `#{…}` inside a macro template
> still do not *evaluate* correctly (they now surface as ordinary per-command
> errors). That residue is the mixfix/set-literal semantics question, tracked
> separately by items 1 and 4 in this section; it is not this entry's ask.
>
> Named cost, eyes open: a genuine typo (`$usr` for `$u`) no longer raises at
> substitution — it passes through and fails downstream as an ordinary unbound
> variable, i.e. a per-command error naming the symbol rather than a whole-file
> abort. The `$var ...` SPLICE branch keeps its error. Pins:
> `tests/test-defmacro.rkt` (datum-level + a new Level-3 `process-file` block —
> the datum pins cannot observe an abort).

### 4. `.{ }` inside `.( )` aborts, and inside a parenless `defr` goal is SILENT

Two more P1b-ii adversarial-verify findings, **both verified NOT regressions**
(the pre-diff spellings and the plain-`{…}` controls behave identically):

- **`.(cfg.{b c} + 1)` → whole-file abort** (`mixfix: Unexpected token after
  expression`). Nothing normalizes a brace-family sentinel before the Pratt
  parser. The P1a RETIRED sentinels are on the safe side of this line — they are
  rewritten to `$retired-selection` *before* pratt-parse — so retired forms
  degrade better than live ones here. Same family as item 3 above.
- **`.{ }` inside a parenless `defr` goal produces NO error at all**: the
  relation is silently never registered and the `defr` command echoes a LATER
  command's result string. Controls (`cfg.host`, `cfg.*name`) DO get the guided
  parenless-goal message (parser.rkt:5765), so the dot-access family routes to
  the guidance while brace-shaped siblings slip through to a silent path.

Both are ordering/normalization gaps in surfaces P1b-ii does not own. Revisit
when P3 gives `.{ }` semantics — several may dissolve once the construct is real
rather than a not-yet stub.

## CIU T6 D4.P1b-iii spin-offs (filed 2026-07-29, from adversarial verify)

### 5. The two groupers DIVERGE on `<`-adjacent braces — and it is live on the disclose surface

`m<{a}` and the spec's disclose spelling `users:<{0.userName^}` yield `$select-brace`
at the datum layer but `brace-group` at the tree layer. Root cause: parse-reader's
`langle` arm FALLS BACK to emitting `<` as a plain operator when no matching `>`
exists (so `result` is non-empty at the brace and the adjacency test fires), while
surface-rewrite's `langle` arm has NO fallback — it unconditionally recurses for
`'rangle`, so the brace is the first item inside that recursion and `(pair? result)`
is false.

**Live at `racket/prologos/lib/examples/foray.prologos:674`** — `users:<{0.userName^}`,
which is exactly the `<` DISCLOSE surface **P4 is scheduled to build on** (spec §3.7,
ruled ADOPTED v1 at Q5).

Not observable end-to-end today: `same-form-type?` keeps preparse's error winning
(see item 6). The Q_N3 v2 agreement guard added at P1b-iii asserts precisely this
tag↔sentinel correspondence but its six rows contain no `<`-adjacent case.

**Do it when**: P4 opens (it owns disclose), or sooner if the guard is extended. The
fix is to make the two langle arms agree — almost certainly by giving
surface-rewrite the same `has-matching-rangle?` fallback parse-reader has.

### 6. `same-form-type?` makes the tree layer unable to override a preparse error — verify before relying on it either way

D4.P1b-iii's Q_N7 ruling was justified by "a non-error tree surf can REPLACE
preparse's error surf, so the guided error would be silently swallowed". Adversarial
verify **disproved it by construction**: a third checkout with `surface-rewrite.rkt`
reverted produced byte-identical output across 20 end-to-end files. `merge-form`
(driver.rkt) gates on `same-form-type?`, which only pairs
surf-infer/def/defn/defn-multi — an error surf can never pair with a non-error one.

The fork was kept anyway (the groupers *should* agree, and the guard now pins it),
but **the justification in the design and the code comment was wrong and is
corrected**. Worth knowing precisely, because the same reasoning will be reached for
again: **the tree layer cannot rescue a preparse error, and cannot corrupt one.**

### 7. Select blocks in BINDER positions get a raw-syntax diagnostic, not the guided error

`def f := [fn [x base{a}] x]` and `spec idf{A} A -> A` are both LOUD and the file
continues — the correctness property holds — but the message comes from the binder
walker and dumps raw syntax objects including absolute file paths:

```
ERROR: Expected binder [x <T>] or (x : T), got (#<syntax:/private/…/f.prologos:3:10 x>
  #<syntax:… ($retired-selection select-block #f)>)
```

It never mentions select blocks, and the internal marker sentinel leaks into
user-facing text. Both binder walkers would need a marker arm. Filed rather than
widened because P1b-iii had already grown well past its designed scope; the honest
behaviour is pinned so a future change cannot silence it.

Related, same family: `pp-datum` (pretty-print.rkt) has no arm for ANY access
sentinel — `$select-brace`, `$dot-brace`, `$postfix-index`, `$nil-dot-access`,
`$broadcast-access` all render as raw sentinels; only `$brace-params` renders. And
`tools/form-deps.rkt`'s `syntax-keywords` lists four sentinels and omits five.

### 8. `pattern-var?`'s residual is 23 of 33, not 2 — and `'[1 2]` in a macro template ABORTS TODAY

Item 3 above named `$set-literal` and `$mixfix`. A full census of every `$`-headed
symbol the reader can emit puts the real number at **23 of 33**:

`$clause-sep $compose $decimal-literal $exp-literal $facts-sep $float-literal
$list-literal $list-tail $lseq-literal $mixfix $narrow-eq $nat-literal $pipe
$pipe-gt $posit-literal $quasiquote $rat-literal $rest $rest-param $set-literal
$typed-hole $unquote $vec-literal`

**`$list-literal` is in that list**, so a plain quoted list inside a defmacro template
is a whole-file abort at HEAD:

```
defmacro lst [$x] [f '[1 2]]
[lst 1]        →  defmacro: Unbound pattern variable in template: $list-literal
                  (zero results, no error summary)
```

This supersedes item 3's count. The structural reading there stands and is now
better evidenced: the fix is inverting the predicate's polarity, not 23 more
exclusions.

---

## CIU T6 D4.P2 spin-offs (filed 2026-07-29, from the pre-commit adversarial verify)

Four skeptics + an adjudicator on the uncommitted `.N` diff. One SIGNIFICANT
finding was a real regression and was FIXED before the commit (the negative
literal hijacking `closed-row-miss-hint`; see typing-errors.rkt's
`ordinal-key-index` comment and the three regression pins in
`tests/test-path-selection.rkt`). Two more were fixed in passing (the
`token-entry->compat` sibling arm; the layer-error comment). These are what
SURVIVED as deliberate non-goals.

### 9. The ordinal miss-hint is narrower than the surface `.N` opens

Q_R5 gave the nat key-domain its own `closed-row-miss-hint` branch, so a
het-tuple index out of range now names index and arity. Four adjacent shapes
still fall through to a bare "Could not infer type" / "Type mismatch":

- `cfg.0` — an ORDINAL on a KEYWORD-domain row. **The adjudicator singled this
  one out**, and rightly: it is the most plausible first-contact error on a
  brand-new positional surface, and Q_R5's own stated rationale was "the first
  thing a user would hit". Leaving it bare is in mild tension with the ruling
  that motivated the branch.
- `het.name` — a KEYWORD field on a NAT-domain row (the mirror case).
- ordinal OOB in CHECK position (inside a `spec`'d body) rather than infer.
- `.N` on a non-tuple carrier (Int, String).

Each is a one-line symmetric extension of the machinery P2 just built, and
NONE is a lie — every case is loud, honest, and strictly better than the
pre-P2 "Unbound variable" these spellings used to produce. Deferred rather
than swept in because the branch order in `closed-row-miss-hint` is exactly
where P2's own regression came from: adding arms there without an A/B against
a pinned baseline is how a correct diagnostic gets suppressed. Whoever takes
this should A/B each new arm the way the P2 adjudicator did.

### 10. `format-closed-tuple-oob`'s zero-arity branch may be structurally unreachable

`(if (zero? arity) " (the tuple has no positions)" …)` (typing-errors.rkt)
ships with no test and no demonstrated reachability: `@[]` types as
`[PVec _]`, not a 0-field nat row, so it takes the runtime path instead. This
is the VAG's own red flag — a defensive guard whose guarded condition may be
impossible. Either construct the reaching case and pin it, or delete the arm.
Do not leave it as decoration.

### 11. ~~The `.N` trailing guard blocks `^`~~ — DISSOLVED 2026-07-29 by ruling Q_T4a

> **Resolution**: the owner ruled that `^` NEVER attaches to an ordinal (an
> ordinal yields the value at an index; there is no key to operate on, and
> non-local attachment breaks composition). So `x.0^`, `x[0]^` and
> `{admins.0^first}` are all SPELLING ERRORS, and the Q_R1 "two surfaces one
> mechanism" identity is preserved — they agree on being rejected. What remains
> is MESSAGE QUALITY only, owned by **D4.P3b** (one guided error naming the
> valid spelling `admins^first.0`). The original filing follows for the record.


Q_R2's guard declines on any `ident-continue?` char after the digit run, and
`ident-continue?` contains `#\^` and `#\'`. Consequence: `x.0^` is not ordinal
access, while the bracket spelling `x[0]^` lexes fine.

**This is a landmine for P3**, which lands `^` RE-KEY: the moment `^` becomes
meaningful after a selector, the two spellings Q_R1 unified will diverge on
exactly the character P3 is introducing. It is not a defect today (nothing
uses `^` after an ordinal yet) and it is not a reason to widen the guard now —
but P3's mini-audit must decide it deliberately rather than discover it, and
Q_R1's "two surfaces, ONE mechanism" identity is what is at stake.

### 12. `reconstitute-path-list` is `$dot-access`-only, so ordinal segments leak the sentinel

`macros.rkt`'s `reconstitute-selection-paths` / `reconstitute-path-list`
reconstitute only `$dot-access` segments, so a `selection … :requires
[:address.0]` leaks a raw `'($postfix-index 0)` into the user-facing message.
Loud, same error count as baseline, and the same family as the `pp-datum` /
`form-deps.rkt` silent-degradation tier §Q8.5 already declares family-wide and
not chargeable to a new sentinel. Pre-existing shape; `.N` widens its input
space. Fix belongs with whatever finally inverts that family's polarity
(see item 8).

### 13. `tokenize-string` flipped from RAISING to emitting a token on `.digit` input

The compat tokenizer's standalone-`.` rejection (`"Unexpected character: ."`)
no longer fires for `x.10`, because `.10` is now one token. The exported API's
behaviour on that input therefore changed from raise to value. Not
production-reachable (the only non-test consumer, `tools/golden-capture.rkt`,
reads token TYPES only) and the value is now sibling-consistent since P2 added
the `token-entry->compat` arm. Recorded because §Q8.5 pre-classified this site
as "a test-only twin" WITHOUT recording that a behaviour flip was possible
there — and the sole dependent test uses a SPACED dot, so nothing caught it.
The weak pin (`(check-exn exn:fail? …)`, no message match) in
`tests/test-varargs.rkt` is worth tightening.

### 14. `spec` silently drops a malformed type — and REGISTERS the garbage (filed at P3 co-design, Q_T6)

`spec h cfg{version} -> Nat` alone → **0 errors, no output, the spec silently
dropped**. Identical for the SHIPPED surface: `spec g cfg.version -> Nat` is
dropped the same way, so this is pre-existing and not selection's.

Mechanism: `spec` is a PREPARSE command — `process-spec` runs inside
`(with-handlers ([exn:fail? void]) …)` (macros.rkt:2791-2793), so its type
datum never reaches `parse-list`'s head-dispatch gate and any failure is
voided. The P1a NOT-YET gate therefore has a hole at the project's PRIMARY
signature surface, and P3 cannot assume it inherits a guided refusal in type
position (it adds its own).

⚠ It is the WORSE of the two readings the P3 audit's critic left open (its
C30): the spec's type datum IS partially registered, not merely lost. Probe: a
following `defn h [x] 1N` dies with `defn: expected <ReturnType> or :
ReturnType, got (($retired-selection select-block #f) -> Nat)` — the defn
error QUOTES the raw marker from the stored spec — then the defn itself is
lost (`Unbound variable` at the call). Two errors, neither naming the spec or
the block; a stored garbage type shaping a later diagnostic.

Root cause is `spec`'s error architecture (the void-ing handler), the same
class Q_L4's marker seat was built for at the reader layer. The fix belongs to
a spec/preparse-diagnostics slice, not to Path Selection; P3 ships its own
type-position refusal independently.

## CIU T6 D4.P3a spin-offs (filed 2026-07-30, from the pre-commit adversarial verify — 4 skeptics + main-thread adjudication)

The verify caught one BLOCKING (the block-pipe select corruption) and three
SIGNIFICANT defects in the uncommitted diff — all FIXED pre-commit (see D4
§5.P3a close notes). These are what survived as deliberate filings: every one
is PRE-EXISTING (verified select-free / dot-identical / baseline-pinned), with
P3a only widening the walked-into surface.

### 15. Block-form `|>` on a `def` RHS is broken — pre-existing, baseline-pinned

`def r3 := |> cfg.server map-keys` → 2 errors at CLEAN HEAD (`6d919142`,
worktree-pinned A/B; "Unbound variable" ×2) while the same pipe at TOP LEVEL
works. Select-free — the P3a pipe pre-fold changes the error TEXT (now
"Expression is not a valid type", still 2 loud errors) but the seam predates
it. Adjacent to the infix-pipe def-RHS grouping corruption the fold skeptic
also reproduced dot-identically (`(idf (def r3 := …))` — the def swallowed
into the application). A pipe/def layout-seam fix, not selection's.

### 16. The `do` expander whole-file-aborts on ANY access-sentinel statement — pre-existing family

A defn body `do` / `cfg{a}` raises raw out of preparse (macros.rkt `do` arm,
"each binding must be [name <type> value]…") → ZERO commands output, internal
sentinel leaked. `cfg.a` baseline aborts identically, so the hole is the
do-expander's (the Q_L4 marker-seat class: a raise where a per-command error
value belongs). Same family: `def cfg{a} := 5` (def-LHS select) aborts at the
def parser — dot baseline identical. P3a makes `x{…}` a shipped surface that
now walks into both.

### 17. Registered head-macros (`if` / `cond` / `let`) see RAW access sentinels — lying per-command diagnostics, pre-existing family

Head-macro dispatch runs BEFORE the access-sentinel fold, so `if true cfg{a} 5`
→ "boolrec expects 4 arguments, got 3"; `let s := cfg{a}` in a defn dumps
internal syntax. ALL reproduce identically with `cfg.a` (per-command, file
survives). The P3a fix for the one SILENT member of this family (the pipe,
which corrupted instead of erroring) was a pipe-local pre-fold; the general
fix is running the fold before head-macro dispatch — an ordering change with
wide blast radius that needs its own slice. `match` folds correctly already.

### 18. Dyn-key `map-assoc` mints a type/value DESYNC that selection then launders — pre-existing upstream

`def d3 := [map-assoc base kh 42]` (kh dynamic `:host`) types
`{:host String … | _}` while the runtime value holds `{:host 42 …}` — the
desync is minted by dyn-assoc TYPING (pre-existing). `d3{host}` then returns
`{:host 42} : {:host String}` — a CLOSED row claiming String over an Int,
stripping the `| _` marker that at least advertised uncertainty. The select
is honest per its inputs (Horn D trusts sourced-'present); the fix belongs at
the dyn-assoc typing rule. The reduction-layer panic stays unreachable
(verified: the dissoc route refuses at typing).

### 19. Row-literal type annotations have NO working spelling — the dropped "annotate" remedy

`def q : {:a Int} := {:a 1}` → "Expression is not a valid type";
`[fn [m : {:host String}] m.host]` fails select-free; zero in-tree uses. The
Q_T2 remedy list as ruled named "annotate" third — the verify dropped it from
the select refusal messages as advice-that-does-not-work — an adaptation the
owner RATIFIED 2026-07-30 ("annotate comes back when it's real"). Re-add to
the messages when row annotations become writable (PX / F-carrier adjacent).

### 20. SELECTION-typed subjects refuse as 'subject-other — capability-alignment deferred

`select-project` projects through SCHEMA-typed subjects (the verify's
convergent fix) but deliberately NOT through selection-typed ones: a
selection is a capability-restricted VIEW (F1b.5-s4 `:requires`), and
projecting through it without the read-capability check would bypass the
restriction. When selection values grow their capability-aware projection
(DEFERRED "projections via selection" items), extend the leg; until then the
refusal is generic ('subject-other) — a guided selection-aware message would
be a cheap interim improvement.

## CIU T6 D4.P3b spin-offs (filed 2026-07-30, from the pre-commit adversarial verify — 4 skeptics + adjudication)

The verify caught one BLOCKING (the whole-datum ordinal-rekey replacement —
a match arm containing `v[0]^` whole-file aborted where HEAD recovered
per-command) and eight SIGNIFICANT defects in the uncommitted diff — all
FIXED pre-commit (see D4 §5.P3b close notes). These survived as filings:

### 21. `k^:x` keyword rename target — the splitter's `#\:` arm is dead in WS mode

`cfg{server.host^:x}` gets the block-keys-bare message instead of the
splitter's keyword-target refusal: in WS mode the lexeme does not glue
through the colon, so the item arrives as a keyword and the splitter's
`#\:` arm never fires (it is reachable from sexp-mode datums only — the
F1b sexp-green ≠ WS-correct class). MITIGATION: the wrong message's action
(drop the colon) resolves the input, so this is degraded-not-lying. Fix
shape: detect a kw item immediately after a caret-bearing step in
`segment-select-items` and emit the splitter's message.

### 22. Arrowless match arms raw-crash the reader — pre-existing, the Q_L4 marker-seat class

`match 5\n  | 0 111` (no `->`) dies with a raw `take: contract violation`
from `parse-match-pattern-arm` (parser.rkt ~:7392): whole-file abort, zero
commands output. Verified select-free and pre-existing at HEAD by the P3b
adjudicator (it was the crash SITE of the P3b BLOCKING finding, but the
arrowless input class crashes on its own). The fix belongs to the match
parser (a guided per-command error naming the missing `->`), not to
selection. Same family as the `.( )` mixfix raises and the tilde abort —
the marker-seat / POL.4 conversion discipline applied to match arms.

### 23. `^_`/`^-_` synth scope: SUBJECT-ROOT preferred over the shipped branch-of-its-block — flip when it next matters (ruled Q_U4, 2026-07-30)

P3b shipped branch-of-its-block scope: `x{server.{host^_}}` →
`{:server {:host …}}` while the dot spelling `x{server.host^_}` →
`{:server {:server-host …}}`. Owner ruling (Q_U4): subject-root is
PREFERRED — a sub-branch is less likely to share a common leaf key, so the
synth's disambiguating power wants the full path — but it is not a
high-priority feature; "switch when it matters next." Triggers: P5's L2
factoring work (which makes the divergence observable — under keywise merge
`x{server.host^_}` ≡ `x{server.{host^_}}` wants to be a theorem, and the
subject-root reading is the one that makes it true) or the first
user-visible need. Flip site (one line each + re-pins): typing-core
`select-below-entries` and reduction `below-entries` currently RESET `seen`
at the `@sub` boundary — subject-root = thread `seen` through instead; then
flip the `server.{host^_}` pins to `{:server {:server-host …}}`.

## CIU T6 D4.P4c-2 spin-offs (filed 2026-08-01 at the P4c-2 close — from the adversarial verify `wf_cb055ff6-16a`, 6 skeptics + adjudicator)

The verify's three BLOCKING findings were FIXED in the slice (`68cdaae7`, the
inverted default). These are what SURVIVED adjudication unfixed. Items 32 and 33
**become live the moment P4c-3 enables its first broadcast context** — they are
inert today only because `broadcast-enabled-contexts` is `'()`.

### 32. 🔄 MOSTLY FIXED (`8fa30336`, P4c-3 prereq) — over-reach survivors; ONE finding remains and it is the important one

`take-param-region`'s param-group arm tests only "is it a group", so ANY group in
that slot is deep-unwrapped; and `take-arm-region` runs to the END of its list
when no `->` terminator is found. Three shapes measured at the reader (all
byte-identical to pre-mint TODAY, hence corpus-A/B-blind, hence not regressions —
but all are P4c-3 landmines):

- **`property` clauses are position-dependent**: the same broadcast in clause 1
  vs clause 2 of one `property` reads differently — sentinel stripped in the
  first, preserved in the second. Two spellings of one form disagreeing is the
  exact class this track keeps paying for.
- **bare-`fn`**: `[fn m [one users:name]]` strips, `[fn [m] [one users:name]]`
  preserves. The optional-NAME step eats `m` in `(fn NAME GROUP)`.
- **`type` union alternatives**: `type Foo := A | B users:name` strips.

**FIXED at `8fa30336`** — the adjudicator's recipe taken as written, plus the
two causes traced: `param-group-candidate?` is now a POSITIVE test (not
`$`-headed by SHAPE so a future sentinel is excluded by construction, not
`-`-headed, not keyword-led), `take-arm-region` is BOUNDED (no arrow ⇒ not an
arm ⇒ touch nothing), and `binder-nameless-heads` ('(fn)) stops the bare-param
lambda's name-skip from handing its BODY to the param-group arm. Mutation-
verified: with preservation force-enabled the two `property` clauses now AGREE.

**⬜ WHAT REMAINS, and it outweighs the fixes — a DESIGN input, not a bug**:
enabling a context is NOT just adding to the list. With preservation forced on,
a body broadcast is STILL stripped, because the unknown-head default unwraps
everything and a body sub-group's head (`users` in `(users :name)`) is by
definition UNKNOWN. So the first enabled context must decide **what an unknown
head does inside an ALREADY-PRESERVED region** — the inverted default and
per-context preservation meet exactly there. Deliberately not guessed at.

**⬜ RE-SCOPED TO P4c-4 (owner ruling 2026-08-02), and SHARPENED BY MEASUREMENT
at the P4c-3 close.** Both directions of the unknown-head default are now
refuted from the corpus, so this is not a choice between a safe and an unsafe
option — it is a demonstration that the head-keyed walk cannot decide it at all:

- **STRIP on unknown** (today): `defn body-app [q] [one users:name]` — measured
  UNCHANGED between empty and non-empty enable-set, i.e. the broadcast is
  stripped in ordinary application position, which is the position broadcast is
  primarily written in.
- **PRESERVE on unknown**: refuted by `[add ?x:Nat ?y:Nat] = 5N`
  (`examples/2026-03-09-fc-trait-rel-dom.prologos:141`, runs 0 errors today) — a
  live BINDER position under an unknown head.

⚠ **REFUTED 2026-08-02 — THIS COUNTER-EXAMPLE DOES NOT EXIST.** `?x:Nat` is glued into ONE
TOKEN by `recognize-narrow-var-annot`, so `bcast-step-trigger?` can never fire on it:
`[add ?x:Nat ?y:Nat] = 5N` mints NOTHING, under any grant. The claim was INFERRED from
"this line runs 0 errors today" without checking whether it MINTS — and `parse-reader.rkt`'s
own comment already said "Immune by construction". **PRESERVE has ZERO measured corpus
regressions** (census: 795 `.prologos` files + WS strings in `.rkt` tests). The one live hole
is DIGIT-headed segments (`?x:0` DOES mint); the one principled counter-example is macro
pattern vars, zero instances in tree. So this item's "cannot decide it in EITHER direction"
framing is HALF WRONG and Q_U18 is reopened — see D4 `#q-u18`.

✅ **RESOLVED 2026-08-02 by [Q_U18](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u18).**
The unknown-head arm flips to **PRESERVE** (owner: "worth the trade"), because the
sigil discriminator is ALREADY in the tokenizer — `?x:Nat` glues to ONE TOKEN and
cannot mint. Owed with it: close the **digit-headed hole** (`?x:0` mints). Accepted
residual: macro pattern vars, zero instances in tree, caught by the EXISTING
`bcast-step-binder` per-command error. The grant is **G4** — test-only until
P4c-4c. This item's remaining half is therefore CLOSED.

Both spellings are `[SYMBOL item item]`. **Structurally indistinguishable at the
reader.** Whatever resolves this is not a longer head table. See D4 §5.P4c-3;
the on-network disposition attribute this points at is chartered under PPN 4D
(prerequisite-blocked on PPN 4C 🔄 + PM Track 12), not new work to invent here.

### 33. `parse-param-names-for` and `parse-defn-binder-seq` are unhardened binder consumers

Reachable with an UNMUTATED tree by two-minute probes, so the claim that the
binder consumers are "a CLOSED set" found by mutation was too strong. Both dump
**raw Racket syntax objects AND an absolute filesystem path** into user-facing
text, and `parse-param-names-for` says `defn` for an `fn`. Not functional
regressions (both spellings error on both legs) — diagnostic quality, which is
what condition (c) was for. `parse-param-names-for` is also the shared entry for
`the-fn`, so the gap is not confined to `defn`. **Fix**: a `bcast-step-datum?`
arm at each `[else]`, same shape as the `parse-binder` guard; and sweep the
remaining `parse-binder`-calling consumers **by grep, not by head** — the
head-driven census is what missed these.

### 34. `unwrap-let-block` may have zero standing coverage — SUSPECTED, not reproduced

A 21-mutation matrix on a scratchpad copy reported that deleting the
`$let-block` clause in `scan-for-param-heads` left all replicated reader pins
green, while 19 of 21 other mutations turned pins red. **I did not re-run that
matrix** and am not adopting its VERIFIED label. What IS confirmed: the clause is
load-bearing (aligned blocks work at HEAD and would silently break without it),
and the documented mutation fallback keys on `binder-param-heads` /
`binder-region-heads` — **which this clause does not consult**, so emptying them
leaves it armed. If the result holds, the branch is covered by neither the
battery nor the procedure that substitutes for one. **Fix**: one `check-equal?`
on the aligned-block shape.

### 35. Four cosmetic / doc-truth leftovers in the P4c-2 surface

- The `bcast-step` message interpolates the payload TWICE, so a zero-payload
  `($bcast-step)` renders ``broadcast `:#f` … spell it `[map [fn [m] m.#f] xs]` ``.
  No raise (the `(pair? args)` guard holds) and the file continues.
- `surface-rewrite.rkt`'s `bcast-step-trigger?` arm is byte-identical to its own
  `[else]` — a no-op whose comment claims it makes the two groupers agree.
- `binder-region-terminators`' `:=` entry appears unreachable since def/let moved
  to `unwrap-binder-prefix` (dropping `->` turns pins red; dropping `:=` turns
  none red).
- The `⚠ EQ?-PRESERVING BY CONSTRUCTION` comment is **false as written**:
  `apply-binder-unwrap` returns a fresh list, so the identity short-circuit
  cannot fire for any non-empty list form. The property it guards (POL.9 paren
  origin) still holds — via `datum->syntax`'s props argument, not via eq? — and
  was verified end-to-end. Worth correcting because the comment is cited as the
  reason a specific bug class cannot recur.

### 36. ✅ RESOLVED (2026-08-01, at the P4c-3 opening) — BOTH DOORS PROBED, BOTH CLEAN

**Nobody in the arc tested this, including the main session.** Every probe went
through exactly two doors: `read-all-forms-string` and `process-file`.
`pipeline.md` documents a whole failure class where a reader artifact in a CACHED
module body detonates only when that body is first re-linked or beta-reduced,
with a misleading error arbitrarily far from the cause, and warns the gap "stays
latent until the node first appears in — or is first INVOKED from — a cached
module body". `$bcast-step` has no `pnet-serialize.rkt` registration and no
`access-sentinel?` membership. Separately, `CLAUDE.md`'s two-context audit rule
names the elaboration-vs-module-loading seam as the permanent architectural
boundary, and `repl.rkt` / the LSP have their own reader entry points — nobody
checked whether the post-pass runs on them at all. **PROBED, and the answer is clean on both doors.**
- **REPL/LSP door**: `process-string-ws` handles a fused param (`f : Int -> Int
  defined.`), a private-suffix form (`p : Int -> Int defined.`) and a broadcast
  (inert, honest error) — identical to the `process-file` door. Structural
  reason: `transform-let-blocks-elems` has a SINGLE call site inside the reader
  (parse-reader.rkt, in `tree-node->stx-elements`), which both doors traverse.
- **`.pnet` door**: a lib carrying `defn f [n:Int]`, `defn- helper [x:Int]` and
  `def base:Int := 41` was compiled cold, cached (4088-byte artifact under
  `data/cache/pnet/`), and re-read warm twice — results identical every time
  (`2 : Int` / `41 : Int`). **Decisively: `strings` on the cached artifact finds
  ZERO `bcast-step` occurrences**, i.e. the unwrap runs BEFORE serialization and
  no reader sentinel can enter a cached body. That is the specific `pipeline.md`
  failure class this item was raised against, and it does not apply.
⚠ One honest note on method: the first run of this probe reported "no .pnet
produced" because I looked next to the source file; the cache lives under
`data/cache/pnet/`. The artifact had been written all along. Test artifact
removed after the probe.

⚠ **THIS ✅ IS SCOPED TO THE EMPTY ENABLE-SET AND DID NOT SAY SO** (noted
2026-08-02 at the P4c-3 close). The `.pnet` conclusion holds *because the unwrap
is currently TOTAL*; the REPL/LSP structural argument is independently sound (it
is about which door is traversed) but says nothing about what SURVIVES. At the
first grant a surviving sentinel CAN reach a cached body and `pipeline.md`'s
unregistered-node failure mode — a silent raw VECTOR from the reader's
unknown-tag fallback, detonating arbitrarily far away — becomes live.
**Re-probe at the grant; do not inherit this ✅.** Note the item's own text
already records that `$bcast-step` has no `pnet-serialize.rkt` registration.

### 37b. ✅ DISCHARGED at P4c-4b (`6b22515d`) — `$bcast-step` joined `access-sentinel?`

Item 37's gap is closed: the predicate, the membership, and the fold arm all
landed, and the fold's emitted head is `$select-path` so the fixpoint obligation
holds by construction.

### 42. ⬜ The `:{…}` reader mint — a P4d PREREQUISITE, unhomed until now

`users:{t r}` does NOT mint: it reads as `users : ($select-brace t r)`, because
`bcast-step-trigger?` gates on token TYPE and a lone `:` before an opener is
neither `keyword` nor `colon-annotation`. So **Q_U7's own second canonical
example** (`users:{a b}` → `[(@bcast (@sub …))]`, which `syntax.rkt` states as
producible) is unreachable.

Blocks: `quests:{t r}` **and both members of the §3.2.1 extent pair**, all of
which D4 names in P4c-4's scope. Also keeps DEFERRED 39's two ω-blind parser
sites and DEFERRED 40 latent, since both need a BLOCK-position broadcast.

⚠ Touches `bcast-step-trigger?`, the ONE predicate both groupers share — the
surface P4c-2 spent four commits and seven measured regressions getting right.
Land it on its own, not mixed with value-semantics work, or the A/B is
un-attributable. Scheduled as a **P4d prerequisite** (P4d owns the line it
unblocks). See D4 `#p4c-sequencing`.

## CIU T6 D4.P4c-3 spin-offs (filed 2026-08-02 at the P4c-3 close)

### 37. `$bcast-step` is NOT in `access-sentinel?` — a P4c-2 deliverable that did not land under a ✅

`access-sentinel?` (macros.rkt:6128-6132) lists eight members and `$bcast-step`
is not one. `broadcast-access?` in that list is the **RETIRED** `$broadcast-access`
(a different head, retired at D4.P1a — the module's own comment at :6136 says so),
which is what made the gap read as closed to a name-shaped glance.

D4's P4c-2 partition explicitly lists "`$bcast-step` into `access-sentinel?` +
its fold arm" as a P4c-2 deliverable, and **P4c-2 closed ✅**. Q_U16's ruling
item 2 makes it load-bearing: joining `access-sentinel?` is precisely what buys
the sentinel all FOUR fold seats "for free", and was the stated reason the
rejected parser-side-fusion escape could not work.

**Not a live defect**: with the enable-set empty no sentinel survives the reader
post-pass, so the fold never meets one. **It IS a prerequisite of the first
grant** — without it a survivor never fuses onto its base, so `users` and the
sentinel stay two separate elements. Moved to P4c-4 with the enable-set.
D4's partition line has been corrected in place.

### 38. There is no TEST SEAM for the enable-set

`broadcast-enabled-contexts` (parse-reader.rkt:2845) is a plain module-level
`define` — not a `make-parameter` — and is not in the module's `provide`. So no
test can enable a context, and the per-phase test gate cannot be satisfied for
ANY grant. The only validation route available is source mutation on a scratch
build (the procedure recorded at `tests/test-path-selection.rkt`, search
"MUTATION"), which is what this session used.

Compounding: because the `(not (broadcast-preservation-active?))` arm is FIRST
in `apply-binder-unwrap`'s `cond`, arms 2–5 plus ten helpers have **zero standing
execution** — the first grant is the first production run of that whole
subsystem at once. Wanted before P4c-4's grant, not after.

### 39. `select-step-name` was the FOURTEENTH site — check for a fifteenth by SHAPE

Fixed at the P4c-3 close (see D4 §5.P4c-3a): the helper was ω-blind, so a
collapse-terminated ω branch yielded `((@bcast (@key k collapse)))` — a LIST —
where syntax.rkt:1099's contract says a key SYMBOL or #f.

**The generalizable point**: the `ADDING A KIND` recipe enumerates `case
(select-step-kind …)` dispatchers, so it structurally cannot see helpers shaped
as an `if`/`and` over ONE predicate. That is the same blindness-class the recipe's
own header records for its first cut (open-coded shape tests; `and`/`if`-shaped
dispatchers). D4 named TWO such helpers — and **BOTH were ω-blind**; the claim
that `select-step-cont` "was covered" was false (it was covered at five of its
**NINE** call sites, and the missing one was live).

**⬜ THE SWEEP HAS NOW BEEN RUN** (2026-08-02, after the adversarial verify
pointed out that this item asked for it and it had not been). Command:
`grep -rn 'select-key-step?\|select-sub-step?\|select-ord-step?\|select-bcast-step?' racket/prologos/*.rkt`
filtered to uses outside a `select-step-kind` `case`. Result — **two more ω-blind
sites, both in `parser.rkt`, both SILENT, both diagnostic-quality**:

- **`parser.rkt:1170`** — `[(and (eq? it '|.|) cur (select-key-step? (car cur)))]`,
  the `^.`-near-miss message. ω-blind, so a wrapped `^`-bearing step falls
  through to the generic stray-`.` advice — which **this site's own comment says
  "would be FALSE here"**. Degraded-to-wrong diagnostic.
- **`parser.rkt:1212`** — `[(select-key-step? head-step) (cadr head-step)]` else
  the literal `"field"`. ω-blind ⇒ the `$select-brace` message names `"field"`
  instead of the real head, defeating exactly the P3b-verify intent its comment
  states (*"`server^{x}` must name `server`, not 'field'"*).

**DELIBERATELY NOT FIXED, and this is the reason**: I could not construct a probe
that REACHES either site. `m.foo^.` and `m.foo^s..` are caught earlier by the
`^`-in-path-access refusal; `server{x}` is the LEGAL brace form. Both are latent
regardless (nothing constructs an `@bcast` value until P4c-4 wires the producer).
Fixing a diagnostic I cannot gate would be a change validated by reading only —
the thing this track has repeatedly paid for. **Fix at P4c-4, when the producer
exists and both are reachable end-to-end.** For 1212 the fix is likely a REUSE
rather than a fourth shape test: `select-step-name` is now ω-transparent and
returns a symbol for symbol/`@key`/`@bcast` and a non-symbol otherwise, so
`(let ([n (select-step-name head-step)]) (if (symbol? n) n "field"))` is the whole
arm.

**Sites verified BLIND-BUT-SAFE by the sweep** (no action): `syntax.rkt:1204`
(`select-sub-step?` in the dissolve arm — measured equivalent on both paths,
structurally so, since the `[(bcast)]` arm re-enters with the same `rest`);
`typing-core.rkt:1016`/`:1057`/`:1132`/`:1142` and `reduction.rkt:1778` (all fall
through to a `memq` guard → the `bcast` arm → `select-bcast-not-yet`, i.e. blind
but LOUD).

### 40. `select-step-name` is still not TOTAL — `(@ord N)` and `(@sub …)` return LISTS

Raised by the P4c-3a adversarial verify and **confirmed by measurement** at the
post-fix tree:

```
(select-step-name '(@ord 3))          ⇒ (@ord 3)          ;; a LIST
(select-step-name '(@sub (a) (b)))    ⇒ (@sub (a) (b))    ;; a LIST
```

The stated grievance behind the P4c-3a fix was "a LIST where the contract says a
key SYMBOL or #f" — and that contract is violated identically by two
**PRE-EXISTING** kinds, which the fix left alone. So the fourteenth site was
patched for `bcast` while keeping the exact `[else s]` catch-all shape P4a spent
a whole phase eliminating.

**Not a regression** (it predates this arc) and **latent** (`parser.rkt` refuses
a branch-initial sub-block and a segment after one, so `@sub` is always terminal
and never a branch head). But that is a **SURFACE rule**, and this arc's own
justification for writing unreachable `bcast` arms is, verbatim, *"a surface rule
is not a representation invariant — P5's factoring rewrites branches and could
produce one"*. The same argument applies here.

**Fix shape**: `case (select-step-kind s)` ending in `select-step-kind-unhandled`,
like every other walk over the vocabulary. ⚠ **Measure before landing** —
`reduction.rkt`'s `below-value` and `typing-core.rkt`'s `select-below-field`
compute `name` under a guard that ADMITS `sub` (`'(key caret sub)`), so raising
on `sub` could break a live path. That is why it is booked rather than done here.

### 41. Two unclassified parameters have drifted past the lint baseline — NOT from this track

Surfaced 2026-08-02 running `racket tools/lint-parameters.rkt` while registering
`broadcast-enabled-contexts` (D4.P4c-4a). Two parameters are unclassified AND
absent from `tools/parameter-lint-baseline.txt`, so they were added after the
last baseline save without being classified:

- `current-check-fire-invariants?` — `propagator.rkt:2229`
- `current-residuation-enabled?` — `global-env.rkt:67`

**Deliberately NOT resolved here, and deliberately NOT `--save-baseline`d**: that
command rewrites the whole file and would have silently accepted both alongside
mine, which is precisely the drift the lint exists to catch. Mine was added by
hand with its rationale instead.

Each needs the same three-way triage the lint offers: test-registered (add to
`test-support.rkt`'s parameterize blocks), migrated to a cell (PM Track 12), or
baselined with a written reason. ⚠ Note the trap found while triaging mine —
five of test-support's six parameterize blocks are PER-RUN helpers, so
registering a parameter there RESETS it inside the helpers a test uses; that is
correct for accumulating registries and wrong for a test-settable config.

## CIU T6 D4.P4b-ii spin-offs (filed 2026-08-01 at the b-ii close — from the mini-audit, the adversarial verify, and the close's own triage)

### 24. `select-block-hint` runs the `'path` column inside an ERROR FORMATTER, with four side-effect classes — NEWLY LIVE

**Mechanism, verified**: `select-block-hint` (typing-errors.rkt) is not a
targeted re-walk of the failing node — it SEARCHES every subfield of ANY
failing expr (`(ormap search (expr-subfields x))`), runs from `infer/err` on
every inference failure, and is wrapped in a swallow-EVERYTHING handler that
discards a raise but NOT effects already performed.

Before the b-ii-2b flip this could never reach the side-effecting arms:
`select-row-of` refused selection / Map / union subjects under `'block` before
them. **The flip makes the `'path` column reachable from that walker**, and
that column contains: `register-selection!` + `global-env-add-type-only`
(sub-selection minting, via `selection-field-type`), `fresh-meta` ×2 (the
dyn/'unknown arms), `check` (which SOLVES metas — the Map key-type gate), and
`with-speculative-rollback` (a network fork, the union arm).

**Honest status**: the mechanism is confirmed by reading; **an observable harm
was NOT demonstrated** at the close. Two probes (a failing expr containing
dyn-row dot accesses; a type error containing a selection dot-access) showed no
meta inflation beyond the elaborator's own expected strictness-slot mint. So
this is filed as a REACHABILITY RISK with the mechanism named, not as a
reproduced defect — and deliberately not as "fine", because "I could not
trigger it in two probes" is not evidence of safety for a walker that runs on
every inference failure in the program.

**What would settle it**: instrument the four effect sites, run the full suite,
and see whether any fires from inside `select-block-hint`. If any does, the fix
is to make the hint's re-walk effect-free (a read-only projection variant)
rather than to narrow its search.

### 25. `format-select-fail`'s remaining arms are still unconditionally block-worded

b-ii-2c made five arms sort-aware. `subject-tuple` is **reachable under
`'path`** (`select-row-of`'s nat-key-domain arm is sort-blind by construction)
and still reads "a keyed block selects NAMED fields". `subject-map` under
`'path` still interpolates "(branch `a`)" although a path access has no branch
— which contradicts a b-ii-2c pin's own comment. `ordinal-oob`,
`not-indexable` and `subject-selection` look unreachable under `'path` (Q_U12
routes `.N` through `$postfix-index`; the selection arm sends `'path` to
`select-view`) — verify before assuming.

Mutation evidence from the verify: stripping the block wording from
`miss-dyn` / `unknown-presence` / the not-a-record fallback left the whole
battery green, i.e. three of the five conditionalised arms are unpinned on both
sides.

### 26. `typing-propagators.rkt` has no `expr-select` registration — the whole dot surface is now on the unhandled fallback

`expr-map-get` is registered; `expr-select` is not, so every `.field` in the
language now lands in `unhandled-expr-counts` instead of a registry-dispatched
rule. **Pre-existing for the block spelling since P3a**, but this flip moved
the highest-traffic access surface in the language onto it. Coverage hygiene,
not a live defect — `expr-validate` was registered explicitly for exactly this
reason ("registering suppresses unhandled-expr-counts noise").

### 27. Stale comments describing a rewrite that no longer happens

`surface-rewrite.rkt:1403`/`:1407` and `sre-rewrite.rkt:650` still say
`($dot-access field) target → (map-get target :field)`. Both are comment-only
placeholders (no live rule, no `register-sre-rewrite-rule!` call), so the CODE
claim holds and only the prose is wrong — but this is the doc-truth class that
sends the next census to the wrong file.

### 28. `_.a.b` nested sections are broken — PRE-EXISTING, verified identical at HEAD

`parse-keyword-section` detects only a TOP-LEVEL `_`, so the outer level never
had a hole to section. Direct `parse-datum` A/B confirms `(map-get (map-get _
:a) :b)` and `($select-path ($select-path _ a) b)` both wrap the outer node
around a `surf-lam`. Single-level `_.a` works. Not a regression; recorded so it
is not re-diagnosed as one.

### 29. The `defr` parenless-clause delta is unpinned

HEAD classified `(map-get cfg :host)` in a parenless clause body as a goal pair
(`pol8-goal-pair?` = "pair not headed by a `$` sentinel"); `($select-path …)`
IS `$`-headed, so the clause now takes `parse-degraded`'s guided refusal —
**strictly better**, and that message's "(e.g. dot-access)" is now literally
accurate rather than aspirational. No pin.

### 30. Q_U12's named follow-ups remain open (by ruling, not omission)

`#.field` (nil-safe → `expr-nil-safe-get`) and `[k]` (postfix index →
`expr-get`) keep their own nodes. The b-ii-2 audit sharpened the reason: the
taxonomy is NOT "different sorts" — ordinals already ride the carrier as
`'ord-step`/`'ord-branch` from block spellings. The real, structural reason is
that `[k]` admits a **COMPUTED key** (an expr) while the selector payload is
declared STATIC data with no exprs inside and `select-step-kind` is a closed
union. Stating it structurally also says exactly when the follow-up becomes
possible: when the payload can carry exprs.

### 31. The `ns` name guard RAISES — it is a WHOLE-FILE ABORT, not a per-command error  (filed 2026-08-01 at D4.P4c-1, owner-requested)

`validate-ns-declaration`'s refusal (namespace.rkt, the guard P4c-1 just made
TOTAL) is a raw Racket `(error 'ns …)`, not a `parse-error` VALUE. So a bad
namespace segment takes down the WHOLE FILE — no later command runs, and the
user sees a Racket-level error rather than a guided per-command diagnostic.

**This is the Q_L4 class**, and P1a built the marker-form seat precisely for it:
per the POL.4 conversion discipline a per-command error is a VALUE, never a
raise. The seat is already in use for the retired-selection family
(`$retired-selection` → `parse-error`, parser.rkt's `retirement-message` arm).

**Why it is filed rather than fixed in P4c-1**: P4c-1's prerequisite was
TOTALITY (the guard was a negative list that silently dropped `ns foo:bar` at
zero errors — a live `b0db8f3e` instance). The error CHANNEL is a separate
concern with its own blast radius, and widening the slice to change it would
have been scope creep. **Named consequence, eyes open**: making the guard total
converts `ns foo:bar` from a SILENT DROP into a WHOLE-FILE ABORT. That is
strictly better — loud beats silent, and it is monotone — but it is harsher
than the guided per-command error the project's own discipline calls for.

**Shape of the fix**: route the refusal through the marker-form seat so it
returns a `parse-error` value; the message text P4c-1 wrote is already correct
and can move verbatim. Test-pinned today at
`tests/test-path-selection.rkt` (the P4c-1 block) with `check-exn` — those pins
flip to result-list assertions when the channel converts, and the pin comments
say so.

**Owner**: requested at the P4c-1 checkpoint (2026-08-01) — "make sure that `ns`
whole-file abort issue is noted for follow-up at some point in this track."
Candidate home: P4c's close, or X.close's doc-truth/diagnostics sweep.

### 31 — GROUNDED 2026-08-01 (def-seam branch). Four corrections; still DEFERRED, now for a DIFFERENT reason.

Audited while doing the `def`-seam conversions (`536d1728`, `59e58662`,
`446070fc`, `7a5f7689`), which are the same POL.4 pattern this item asks for.
The item is still worth doing, but **not as written** — and one of the two
blockers it never knew about has now been removed.

1. **The function named above does not exist.** `validate-ns-declaration` has
   ZERO occurrences in `racket/`. The real function is
   **`process-ns-declaration`** (`namespace.rkt:878`), with two production
   call sites (`macros.rkt:2955` under a Pass -1 `exn:fail?` swallow, and
   `macros.rkt:3121` bare — the bare one is the abort you see).

2. **Two raise sites, not one.** `namespace.rkt:880` (shape/arity — reachable
   by a lone `ns`, `ns "foo"`, `ns 42`) and `namespace.rkt:914` (the P4c-1
   totality guard — `ns foo:bar`, `ns foo.bar`, `ns foo bar`, `ns foo[2]`, …).
   A conversion must cover both.

3. **The module-load blocker — REMOVED at `7a5f7689`.** `load-module`'s loop
   was `(unless (prologos-error? surf) …)` with no else, so an error surf in a
   LIBRARY module was silently skipped. Converting `ns` on top of that would
   have regressed a bad `ns` in a library module from a loud abort into a
   module loading with no namespace and no prelude, silently — the `b0db8f3e`
   class P4c-1 had just closed. That loop now reports error surfs, so this
   objection no longer applies. (It applied to the shipped `$let-error` and
   `$def-error` conversions too; both were quietly affected.)

4. **The remaining blocker is structural and specific to `ns`.** Its fold arm
   CONSUMES its form — `(process-ns-declaration datum) acc`, bare `acc`,
   `macros.rkt:3120-3123` — so unlike `def` there is no datum flowing onward
   for a marker to ride. Converting requires CHANGING THE ARM TO EMIT, and
   emitting for a normally-consumed head adds a result, which shifts the
   `;;N=>` acceptance-marker indices (suite-gated, several wrapper files).
   **A FAILURE-ONLY emission avoids that**: a valid `ns` still returns `acc`,
   and a malformed one currently yields no results at all, so nothing green
   shifts. That is the shape to design toward.

   Note also that both raises precede every side effect (`ns-sym` bound at
   :921, context set at :925, prelude at :945-958), so a failing guard leaves
   the file with no namespace and no prelude — a per-command error would let a
   cascade of unbound-variable errors follow. "One guided error, then stop"
   may be the honest target rather than a literal per-command value.

5. **The pin count is understated.** FIVE `check-exn` assertions across FOUR
   test cases in `tests/test-path-selection.rkt`, and "the P4c-1 block" misses
   the strictest (the P2 pin asserts the message text, not just `exn:fail?`).

6. **The P4c-1 pin comment's justification is factually wrong** and this item
   inherits it: it claims aborting at the first command is
   "near-indistinguishable from a per-command error". It cannot be —
   `run-print` never runs, so there is no numbered result list and no
   `--- N errors ---` line at all.

**Strictly cheaper siblings, same class, NO structural blocker** (their arms
already cons, so a marker can ride today): `macros.rkt:3348` bare `solver` and
`macros.rkt:3360` bare `schema` — both verified live whole-file aborts. If the
goal is to retire whole-file aborts by volume, these come first.


---

## Dual-spine parser merge (filed 2026-08-02 at the `loc->line` defect close, `d4e32398`..`eec12ea2`)

> **⭐ STATUS 2026-08-03 — THE TREE LEG IS GONE (`2d7813ef`).** Owner ruling: finish
> PPN Track 3 Phase 7. `merge-preparse-and-tree-parser` is now the preparse
> pass-through + `consumed-form-residue?` filter, **keeping the form-cell block**;
> `tree-surfs` / `tree-by-line` / `merge-form` / the admission gate / both lookups
> are deleted (−195/+69 driver.rkt). Gates: corpus A/B on FULL OUTPUT against a
> `git archive` pin at `f0bce056`, both legs on the SAME 163 inputs — errors
> 359 = 359, aborts 26 = 26, no file changed its error count, and **zero differing
> lines after normalising generated-name counters** (the only raw diff is gensym /
> meta numbering, because the tree leg no longer allocates). Suite 9819/482/0.
>
> ⚠ **AND THE HISTORY WAS NOT WHAT WE THOUGHT.** Phase 7's tracker row read
> `✅ … No merge` for four months and was wrong **twice**: (a) at `5d3b597c` the
> cell pipeline was wired into `process-string-ws` ONLY — `process-file`, the
> primary design target, never left the merge; (b) `19d9f8aea` (Rel T1 SC,
> 2026-07-20) then reverted the string path to the merge as well, because
> cell-pipeline-only **dropped preparse-macro support** (`solver` / `schema` /
> `defmacro` broke in REPL/LSP). That revert removed
> `extract-surfs-from-form-cells`'s last caller — which is exactly why the form
> cells are write-only. **The remaining work is not wiring; it is solving the
> preparse-macro problem that caused the revert.** See
> [Track 3 § Phase 7 status](2026-04-01_PPN_TRACK3_DESIGN.md#p7-status).
>
> Per-item deltas: **1** reduced to the form-cell wiring · **4 RESOLVED by
> removal** · **6 ⛔ RULED DO-NOT-DELETE 2026-08-03** — reader/parser unification
> is LHC / PPN 4D multi-track work, not a fix-chip deletion; item 6 now carries the
> full grounding audit, including the refutation of its own "~1,971 lines / 33
> functions" figure and of "deletable as a standalone change" · **2 / 5 moot for
> the merge** (no tree leg to feed) though the `parse-form-tree` mode fork itself
> still exists, and **5 is COUPLED to 6** (see item 6's abort finding) ·
> **3 / 7 unchanged**.

Context: `docs/tracking/2026-08-02_LOC_TO_LINE_MERGE_DEFECT.md` §0. The merge key
was broken three ways; the tree spine has won **0 of 5,171 corpus forms, ever**;
correcting the key REGRESSES the corpus (errors 359→724, 32 test files fail), so
the spine is now held shut on purpose at `tree-spine-admitted?` (driver.rkt),
pinned by `tests/test-dual-spine-merge-key.rkt`. These are the residuals.

1. **⭐ THE DECISION — and it is NOT the binary this entry was first filed under.**
   Originally written as "commission the tree spine, or retire the merge". The
   census then established that `parse-eval-tree-for-cell` is **not a parser**: it
   converts tree → datum → `parse-datum`, *the same parser preparse uses*. So the
   system does not have two parsers competing. It has **ONE parser and TWO
   READERS**, and the merge is comparing a parser against itself.

   The real option is therefore **UNIFICATION**: one parser (`parse-datum`), two
   readers, delete the 1,971-line legacy `parse-*-tree` family, and retire the
   merge — because comparing `parse-datum(readerA)` against `parse-datum(readerB)`
   has no adjudication left to do. Any residual difference is a **reader** bug,
   which belongs in a test, not in a runtime merge. That is the completeness
   answer: one atom table, one head dispatch, **by construction**, which is why
   all 14 defect classes become impossible rather than fixed.

   `racket tools/spine-census.rkt <files>` measures agreement where both spines
   produced a surf:

   | tree-spine mode | agreement | divergences |
   |---|---|---|
   | legacy (`parse-*-tree`, a 2nd PARSER) | 428/1454 = 29% | 1026 |
   | datum (tree-as-READER, grouped node) | 954/1162 = 82% | 208 |
   | raw-datum (tree-as-READER, RAW node) | 1542/1568 = 98% | 26 |
   | **raw-datum + the macros.rkt where-pass fix** | **1544/1558 = 99%** | **14** |

   ⚠ The first three rows are `--mode all` figures and the last is `--mode
   raw-datum`; they are **not** strictly comparable (the tool never resets
   registries between files, and `--mode all` runs modes outer, so later modes
   see more pollution). Same-mode, the where-pass delta is **23 → 14**. Always
   A/B with the same `--mode`.

   Still an owner ruling — but the thing to rule on is unification vs. keeping
   preparse authoritative forever, not "commission vs retire".

1b. **⚠ WHICH SIDE DOES PPN BUILD OFF? — settled 2026-08-03, and it inverts the
   risk I had described.** The worry was that retiring the wrong side would damage
   the substrate PPN 4C/4D returns to. There are **THREE** layers here and they
   are routinely conflated:

   | layer | owner | state | touched by this arc? |
   |---|---|---|---|
   | the reader's 5 parse cells (char·indent·token·bracket·tree, `parse-reader.rkt`) | PPN Track 1 | cells landed, **propagator wiring unbuilt**; scoped by [4D §12](2026-05-19_PPN_4D_IMPLEMENTATION_DRAFT_NOTE.md) | **NO** |
   | the per-form cells (`form-cells.rkt`, source-line keyed) | PPN Track 3 | written, read by nothing **yet** | **NO** |
   | the merge's tree leg (`parse-top-level-forms-from-tree` → `tree-by-line` → `merge-form`) | the merge | never fired, now gated off | **YES — only this** |

   **PPN Track 3 Phase 7's own design says to DELETE the merge.** Verbatim
   ([Track 3 design](2026-04-01_PPN_TRACK3_DESIGN.md) §"Phase 7: Pure Merge
   Function + Shared Cells"): *"**Delete**: `merge-preparse-and-tree-parser`,
   `merge-form`, source-line-keyed identity matching, `tree-by-line` hash
   building. Total ~80 lines from driver.rkt."* Phase 7 shipped only its first
   half (`40d07caa`, "form cells wired into driver pipeline") — the cells went in,
   the deletion never happened, and the comment *"Phase 7 will switch
   process-command to read from these cells"* was written **in that same commit**.
   It is Phase 7's own unfinished second half, reading as future work from a phase
   already marked ✅.

   **So retirement is not a departure from PPN's plan — it IS PPN's plan, left
   unfinished.** The per-form cells are the intended REPLACEMENT for the merge,
   which is exactly why they must **not** be deleted: their write-only state is
   the "propagator wiring unbuilt" condition PPN Master row 3 documents, not
   abandonment. ⚠ I previously called them "dead weight" and "not a reason to
   preserve anything" — **that was the genuinely dangerous characterisation**, and
   it was wrong. Deleting them would delete PPN Track 3's deliverable.

   **PPN 4C is unaffected either way**: it is "Elaboration completely on-network —
   9 axes", elaborator-side. Neither 4C nor 4D mentions
   `merge-preparse-and-tree-parser`, `tree-by-line`, or
   `parse-top-level-forms-from-tree` anywhere.

2. **The `current-raw-node` production change — measured, NOT landed.** It is the
   designed hook (tree-parser.rkt reads `(or (current-raw-node) node)` for the
   datum conversion; form-cells.rkt sets it from a raw-node map) and the merge
   path simply binds it `#f` (driver.rkt). Setting it is what takes agreement
   82%→98%. **Deliberately not landed**: with the admission gate shut it changes
   nothing observable, so landing it alone is machinery with nothing behind it —
   the exact shape CIU T6 D4.P4c-3 already hit. It is step 1 of unification, not a
   standalone change.

3. **⚠ THE "98% CEILING" WAS WRONG — corrected 2026-08-02, and the correction is
   the useful part.** This item originally read: *"the residual 26 are structural;
   whole-file `preparse-expand-all` inserts the dict binders from cross-form spec
   context and per-form `preparse-expand-single` cannot see it; open question
   whether 98% is permanent."* That was reasoning, not measurement, and it was
   **refuted**: `-single` gets the spec injection fine and merely left the `where`
   clause un-discharged, because it skipped `maybe-inject-where` — a pass `-all`
   runs twice. Fixed (`41697413`), **23 → 14 same-mode** (I first published this
   as "26 → 14", which compared an `--mode all` baseline against a `--mode
   raw-datum` result — the instrument's own pollution, not the code's), pinned by
   `tests/test-preparse-expand-parity.rkt`.

   ⚠ And the damage was worse than the census's one-line summary suggested: it
   reports only the FIRST structural difference, so it printed `preparse: $Add-A
   / tree: x`, which reads cosmetic. Dumping the real surfs for `arithmetic`'s
   `defn +` showed the tree body was **`(surf-var where)`** — the dangling
   `where` consumed AS THE FUNCTION BODY, with the real body `[add x y]`
   silently discarded and ZERO errors. Read past the first divergence line
   before judging a class cosmetic.

   **The open question is now the remaining 14**, a different and smaller set:
   `surf-map-literal` ×3, `surf-solve` ×3, `surf-nat-type` ×1, and 7 bound-variable
   name differences. Nobody has characterised them. Do NOT assume they are
   structural — that assumption has now been wrong twice on this exact question.

4. ✅ **RESOLVED BY REMOVAL 2026-08-03 (`2d7813ef`)** — the branch went with the
   tree leg, deliberately rather than left disabled. It was dead already (the gate
   emptied `tree-by-line`), so removal was behaviour-neutral. ⚠ If recovery-first
   is ever wanted back it must be rebuilt **on the form cells WITH a
   `same-form-type?` guard** — not restored as it was. Issue #69(b)'s other half
   (preparse error surfs are not silently dropped) stands and is what the
   surviving `for/list` delivers. Original entry follows.

   **The error-recovery branch is UNGUARDED, and it is the merge's most
   defensible future role.** `(or tree-match s)` (driver.rkt) has no
   `same-form-type?` and no spec-store check, unlike the four guards on the
   `[else]` path. It converted `spec {:0 …}` / `{:1 …}` QTT errors into
   definitions whose binders are all `#f` → `mw` — **a declared-LINEAR parameter
   silently becoming unrestricted**. Dead today (the gate empties `tree-by-line`,
   so both lookups miss), live the moment anyone opens the gate. If any part of
   the spine is commissioned first, this path plus a `same-form-type?` guard is
   the likeliest candidate — but it must be guarded BEFORE, not after.

5. **`process-file` and `process-string-ws` run DIFFERENT tree parsers**, and the
   fork is an accident: `parse-form-tree` branches on whether `current-source-str`
   is bound, and only the string path binds it. So the FILE path — the primary
   design target — takes the legacy `parse-*-tree` arms (29%) while the string
   path takes the datum conversion (82%). Unadjudicated. It decides which parser
   a commissioned merge would start trusting, so it is upstream of item 1.

6. ⛔ **DO NOT DELETE — OWNER RULING 2026-08-03. This is LHC / PPN 4D work, not a
   fix-chip deletion.** The ultimate goal is running **100% on the propagator
   network** (the Logos Hyperlattice Compiler, toward self-hosting). Unifying the
   reader/parser onto that stratum is a **larger multi-track effort**, and
   deleting the tree parser from inside a bug-fix chip would pre-empt it.

   **The supporting measurement, which also dissolves the "delete it, the datum
   route covers it" argument**: `net-add-propagator` + `elab-add-propagator` count
   is **0** across all four parse-layer files (`tree-parser.rkt`,
   `parse-reader.rkt`, `surface-rewrite.rkt`, `form-cells.rkt`). **Both** branches
   are off-network, so deleting one buys nothing on-network — it just removes the
   thing PPN 4D is the eventual successor to. (This also settles the apparent
   conflict with [Track 3 §11's](2026-04-01_PPN_TRACK3_DESIGN.md) "tree-parsing is
   canonical": §11 described an aspiration the code never acquired, so neither
   deleting nor keeping the arms advances or retreats from it.)

   <a id="stepb-audit"></a>
   **A full Stage-4 grounding audit ran before the ruling (`wf_d604bfc7-776`, 6
   agents / 1.2M tokens, HEAD-pinned, every load-bearing claim R-lens-verified on
   the main thread). Its findings are banked below because they are the map anyone
   returning here will need — and because two of them refute this very entry.**

   ⚠ **THIS ENTRY'S OWN NUMBER WAS WRONG, AND IT IS THE DANGEROUS KIND OF WRONG.**
   "~1,971 lines / 33 functions" is not a measurement of the legacy family: it is
   `wc -l` of the **whole file** at the filing revision (`1971`, to the digit) and
   `grep -c '^(define (parse-.*-tree'` over it (`33`, to the digit). That glob
   **captures `parse-eval-tree-for-cell`** — the datum route any revival needs —
   and at HEAD the keeper sits 35 lines from a deletable near-twin
   (`parse-eval-tree-for-cell` :742 KEEP / `parse-eval-tree` :777). **The figure is
   the sweep that would delete the wrong thing.**

   ⚠ **AND "deletable as a standalone change" IS REFUTED.** The datum route
   **cannot run** with `current-source-str` unbound: `pos->line-col`
   (parse-reader.rkt) does `(string-ref str i)` with only an `i >= pos` guard and
   no length check, so on `""` it RAISES — reproduced. The raise is **unguarded at
   both levels** (`tree-node->stx-form` is called OUTSIDE the `with-handlers` in
   `parse-eval-tree-for-cell`; `extract-surfs-from-form-cells`'s verified-tags arm
   has no handler while its sibling `else` arm does), so the failure mode is a
   **whole-file ABORT**. On the `process-file` path — which never binds the
   parameter — the legacy arms are therefore the **only branch that functions**.
   Items 5 and 6 are **coupled**: deleting the arms without first binding
   `current-source-str` turns every `.prologos` file into an abort. (5th instance
   of the unguarded-parameter/whole-file-abort shape in this track.)

   **The real partition** (measured with `read-syntax` + `port-next-location`, not
   grep): legacy-only arms = **10 fns / 342 lines**; **ungated** expression
   machinery that fires regardless of `current-source-str` = **34 fns / 915
   lines**; the datum route = **1 fn / 34 lines**; wholly dead = **6 fns / 49
   lines**. Which of these is even *eligible* depends on which caller you
   preserve — `extract-surfs-from-form-cells` is 16-tag-gated, but
   `parse-top-level-forms-from-tree` (spine-census + the micro-bench) is not.

   **Three further findings, none previously recorded:**
   - **9 `case` arms are already SHADOWED-DEAD.** Racket `case` is first-match
     (verified), and session/defproc/defr/solver/subtype/selection/capability/
     foreign/strategy appear BOTH at `tree-parser.rkt:147-148` and again later —
     so `parse-session-tree`, `parse-defproc-tree`, `parse-defr-tree` and
     `parse-solver-tree` are unreachable in **both** modes, and the
     `capability`/`foreign`/`strategy` error stubs never fire.
   - **srcloc loss is a Phase 7 revival blocker.** Every surf
     `extract-surfs-from-form-cells` produces carries `("<unknown>" 0 0 0)` —
     both arms end in `(datum->syntax #f expanded)`. Also `form-cells.rkt`
     **mutates** `current-raw-node` rather than parameterizing it, so a file-path
     revival must bind BOTH parameters or leak across files.
   - **The 16-symbol tag list is duplicated** with no shared constant
     (`tree-parser.rkt:147-148` vs `form-cells.rkt`'s `tree-parser-verified-tags`)
     — verified identical today; silent divergence if either drifts.

   **The suite is BLIND to all of this**: `tree-parser.rkt`'s 26-case
   `module+ test` block is never collected (the runner enumerates `tests/` only)
   and no `tests/` file requires `tree-parser.rkt`. A green suite is **zero
   evidence** here. Also: `tools/spine-census.rkt`'s `--mode` **defaults to `all`,
   which includes `legacy`** — any future deletion breaks the instrument's default
   invocation, not an opt-in flag.

   Finally: this entry's "legacy parse measured ~0% of pipeline time" has **no
   backing measurement anywhere in `docs/`**. It is nonetheless true *a fortiori* —
   `parse-form-tree` has zero production callers, so legacy parse is 0% **by
   construction**. Restate it that way; do not cite a measurement that does not
   exist. Original entry follows.

   **The legacy `parse-*-tree` family is ~1,971 lines / 33 functions of DUPLICATED
   parsing** whose 14 classified defects (see the defect note §0) exist *because*
   duplication lets tables drift — atom table 11 of parser.rkt's 42, head
   dispatch ~58 of ~357. Under a RETIRE ruling it is deletable outright; under
   COMMISSION-on-the-datum-path it is deletable too, since the datum path does
   not use it. Either way it is dead weight; the only question is when.

7. **Smaller, verified, not blocking**: `item-srcloc`'s TOKEN branch still
   fabricates line/col as `0 0` in a raw list (tree-parser.rkt), and
   `format-srcloc` (source-location.rkt) calls `srcloc-file` with no `srcloc?`
   guard — so a list-shaped srcloc RAISES `contract violation` rather than
   printing. Unreachable while the gate is shut. `pos->line-col` already exists
   and is exported for the recovery; do not write a new one.


## CIU T6 D4.P4c-4c spin-offs (filed 2026-08-04 from the pre-commit adversarial verify `wf_6eb75d73-799`, 4 skeptics + adjudicator)

### 43. ✅ RESOLVED 2026-08-04 — folded into P4c-4c by owner ruling. THE STRICTNESS TIER NOW FOLLOWS THE ω UNWRAP

**Fixed in two halves.** Typing: `select-tier-subject` peels one container layer
per LEADING ω step, so the tier sees the type the ω step unwraps to. (Non-ω
nesting never had the bug — Q_U13's NEST encoding gives every level its own
`expr-select` node with its own tier; verified, `x.inner.a` over a Map is loud.)
Reduction: `champ-of` now TIER-FORKS three ways instead of panicking
unconditionally, mirroring `project` beside it.

⚠⚠ **THIS ENTRY'S OWN DEFERRAL RATIONALE WAS FALSE, and the adversarial verify
caught it.** The text below said *"the grant is `'()`, so nothing here is
reachable in production."* The `champ-of` half was **always** production-reachable
with no grant: the `expr-select` entry admits **rrb** subjects into `select-reduce`
BEFORE the `definitely-not-map?` fork, and `expr-rrb?` is not a member of that
predicate (only `expr-hset?` is). So `ub.a` where
`ub : <[Map Keyword Int] | [PVec Int]> := @[1 2 3]` reaches `champ-of` on the
ordinary dot path — where it used to PANIC "invariant violation", itself wrong,
since the union's Map branch is exactly why typing admitted `.a`.
⚠ And my FIRST fix degraded it to `<error>`, giving a **third answer to a
two-answer question**: three adjacent union-non-map cases answered `none`,
`<error>`, `none`. Corrected to `none`, agreeing with `definitely-not-map?`'s
sibling ("Match `map-get`: degrade to `none`"). Pinned, no-grant.

**Residuals, filed rather than fixed** (see 48, 49). Original text retained below
because the false rationale is the lesson.

---

### 43 (original text, 2026-08-04) — THE STRICTNESS TIER DOES NOT FOLLOW THE ω UNWRAP

One root cause, two OPPOSITE symptoms, and the slice's own `pvec-map` oracle
disagrees with it in both directions. `infer-select` solves the tier from the
**subject** type (`typing-core.rkt`, the `[(path) (when (expr-Map? tm) …)]` arm);
under ω the subject is always a PVec, and `select-elem-of` unwraps to the element
*after* that decision. Meanwhile `champ-of` (`reduction.rkt`) has no tier fork at
all, unlike its top-level sibling.

**Direction A — a Map miss goes SILENT where the language is loud:**
```
def xs : [PVec [Map Keyword Int]] := @[{:a 1} {:zzz 9}]
xs:a                        →  <error> : [PVec Int]        ZERO errors
[pvec-map [fn [m] m.a] xs]  →  @[1 (panic "key :a not found; available: :zzz")]
```
**Direction B — a union non-map PANICS where the language degrades:**
```
def ws : [PVec <[Map Keyword Int] | Int>] := @[w1 w2]   ;; w2 = 7
ws:a                        →  panic: "…is not a map at runtime"
[pvec-map [fn [x] x.a] ws]  →  q : [PVec Int] defined.   (no error)
```
Rider: `champ-of`'s message asserts **"typing admitted the BLOCK"** at a `'path`
site — the exact falsehood `rrb-of`'s own comment says it avoided by not copying
`champ-of`'s wording, then reached anyway by delegating to it. It also names the
STEP, not the value.

**Why it is deferred**: the grant is `'()`, so nothing here is reachable in
production; and the fix is a DESIGN decision about whether Q_U10's Map posture
survives a functorial lift — Q_U18/G2 territory, not a code slip.
**⚠ Why it MUST NOT slip past G2**: the moment a grant lands, a Map-carrier
broadcast silently swallows a miss that the dot spelling reports loudly. Sites:
`typing-core.rkt`'s tier solve (thread the tier through the unwrap) and
`reduction.rkt`'s `champ-of` (tier-fork it, as its top-level sibling already does).

### 44. An ω inside a vector or list literal SPLITS silently, at zero errors

```
def xs := @[{:name "a"} {:name "b"}]
def r := @[xs:name]   →  r : ⟨[PVec {:name String}] Keyword⟩
                         @[@[{:name "a"} {:name "b"}] :name]
```
Same for `'[xs:name]`. The ω token is not fused onto its base inside a literal, so
it becomes TWO elements. This is the silent-wrong-answer class the track exists to
fight, it lives in the READER (which P4c-4c does not touch, so it is not caused
here) — and it is a landmine directly under G2, because G2 is what makes literals
reachable with a live mint.

### 45. Latent label divergence: `select-step-output-name` vs `select-branch-top-keys`

```
branch ((@bcast 0) name)  →  top-keys = (name)   output-name(head) = #f
branch ((@bcast a) b)     →  top-keys = (a)      output-name(head) = a   ← agrees
```
`select-step-output-name` delegates to the inner step, which answers `#f` for an
ordinal; `select-branch-top-keys` recurses with `rest` and reaches the deeper key.
⚠ The NON-ω twin is consistent — the bare-number arm descends transparently,
mirroring top-keys — but the new ω arms do not. **Unobservable today** (the label
is discarded under `'path`, and block-position ω is parse-refused), so this is a
note, not a defect. Goes live with P4d or P5's factoring, and the failure mode is
the silent mis-sort P4a exists to prevent.

### 46. `(@bcast (@sub …))` is unhandled on both sides — currently UNREACHABLE

`branch-entries` would treat the whole `@sub` list as a field name. Unreachable
because the mint never fires: `xs:{name age}` → "Unbound variable `:`" (DEFERRED
42, the `:{` reader mint). ⚠ So DEFERRED 42 and this entry must land TOGETHER —
minting `:{` without handling the sub-inner ω turns an "unbound variable" into a
silent wrong answer. Scope note for P4d.

### 47. The empty-PVec ω diagnostic is generically worded

`@[]` infers `[PVec _]`, so the inner step meets an unsolved meta and reports
"the subject … is not a record, so it has no fields to access". Per-command, file
continues, no fabrication — correct behaviour, imprecise message (the subject is
an unsolved element meta, not a non-record). Pre-existing wording from
`select-project-field`, surfaced by ω rather than caused by it.

### 48. ✅ RULED 2026-08-05 [owner] — KEEP THE WHOLE-NODE ABORT UNIFORM

**The ruling: uniform.** A miss inside a broadcast aborts the whole selection on
EVERY tier, including the permissive one. No change to the code; the ratified
Q_U7 rider stands unamended.

**The argument that lost, recorded because it is real** and will be re-raised
otherwise: the rider is justified by *"no `expr-panic` buried in an output
slot"*, and on the permissive tier there is no panic — the value is `none`,
which the language produces deliberately everywhere else. So the rider's stated
concern is structurally absent there, and the cost is measured: `ws:a` yields
`none` where `[pvec-map [fn [m] m.a] ws]` yields `@[1 none]` — and `pvec-map` is
the spelling broadcast's OWN diagnostic recommends.

**The argument that won**: ⭐ **the tier is INFERRED, not written.** Per-tier abort
semantics would make identical source text preserve surviving elements or not,
based on something the reader of that source cannot see. Uniform abort is
predictable; per-tier is not — and predictability of a surface construct beats
recovering data in a case the user cannot identify from the text. The rider was
also pinned specifically so a "map semantics" intuition could not drift it later,
and the drift being proposed was exactly that.

**Consequence to state honestly in docs**: on a permissive carrier, broadcast
loses data that `pvec-map` would keep. That is a KNOWN and ACCEPTED cost, not an
oversight, and the diagnostic that recommends `pvec-map` is therefore also
recommending the more forgiving spelling — which is fine, but should not be
described as "equivalent".

*(original entry retained below)*

### 48-original. Under ω a PERMISSIVE carrier annihilates the whole vector, where `pvec-map` preserves the hits

```
def ws : [PVec <[Map Keyword Int] | Int>] := @[um u1]   ;; um = {:a 1}, u1 = 7
[pvec-map [fn [m] m.a] ws]  →  @[1 none] : [PVec Int]    ← the good element survives
ws:a                        →  none      : [PVec Int]    ← total loss
```

This is the ratified **WHOLE-NODE ABORT** (Q_U7 rider): a miss inside any element
aborts the whole selection through the single `let/ec`, no partial vectors. So it
is *ruled semantics, not a defect* — filed because the slice ships a pin asserting
"ω agrees with the `pvec-map` ORACLE" for direction A, and that agreement does NOT
extend to permissive carriers. The pin's comment now says so; this entry is the
open question behind it: **is whole-node abort the right rule for the PERMISSIVE
tier specifically**, where nothing is actually wrong and `pvec-map` degrades
per-element? Zero production reach today (ω is grant-only). ⚠ **Re-decide at G2**,
which is when it becomes reachable.

### 49. `champ-of`'s message names the STEP, not the value

`(champ-of v name)` is called with `name` = the step name, so a miss reads
"`select: a is not a map at runtime`" — which parses as "the field `a` is not a
map". Its `rrb-of` sibling gets it right ("this one is not a vector"). Half of
DEFERRED 43's rider; the other half (the false "typing admitted the block" clause
at a `'path` site) WAS discharged. Cosmetic, and deliberately not fixed inside a
slice that had already moved production behaviour once — it needs a shared-helper
signature change.

### 50. 🔀 SPUN OUT (chip `task_204859b9`, 2026-08-04) — fused annotations in `defmacro` param lists, and `pattern-var?`'s sentinel gap

**⚠ THE FRAMING THAT REACHED THE OWNER WAS WRONG, and the correction is the entry.**
The P4c-4c mini-audit reported that G2 "newly leaks a `$bcast-step` into a
`defmacro` pattern, SILENTLY", and I relayed that as a G2 regression; the owner
ruled it into the slice on that basis. **It is not a G2 regression.** Measured at
the production default, no grant:

```
defmacro twice [$c:Int $b] …   →  ((defmacro twice ($c :Int $b) …))          THREE params
  (under the leaking grant)    →  ((defmacro twice ($c ($bcast-step :Int) $b) …))  also THREE
```

The fused annotation becomes a SEPARATE param item either way, inflating arity
2→3, so the macro can never match. G2 changes the third item's SHAPE and nothing
observable: `[twice 5 9]` reports `Unbound variable twice` on BOTH legs, and the
spaced spelling `[$c $b]` works on both. **The datum differs; the meaning does
not** — the arc's recurring failure, 4th instance, this time the audit's claim
with my endorsement on top of it.

**So the defect is PRE-EXISTING and independent of ω**: a fused annotation in a
`defmacro` param list silently registers an unmatchable macro, and the user's only
signal is a misleading "unbound variable" at the CALL site.

**Root cause**: `param-group-candidate?` (parse-reader.rkt) rejects any `$`-headed
group by SHAPE, and macro pattern variables are `$`-prefixed — so the macro's param
region is never taken and never unwrapped. `defn [x:Int]` is unaffected and
unwraps correctly even with the inner head granted, which isolates it.

**Rides with it**: `pattern-var?` (macros.rkt) hand-excludes ~19 sentinels and its
own comment records the residual at **23 of 33**, `$list-literal` included — a live
whole-file abort for `'[1 2]` in a defmacro TEMPLATE today. Same underlying
question (what IS a `$`-symbol?), so they should be solved once. ⚠ I hypothesised
`$bcast-step` would abort in a template too and **probed it — it did NOT
reproduce**; recorded so the next session does not inherit an unverified claim.

**Not blocking G2**: nothing here is caused by, or gates, the P4c-4c/G2 work.

### 51. ✅ FIXED 2026-08-05 (commit `e0f03601`; message only, owner-ruled option (a)) — the parenless `&>` guard blamed dot-access for a condition that is not dot-access

**⚠ The filed diagnosis was WRONG in its load-bearing half, corrected by
re-measurement.** As filed this read as a G2 regression ("the relation goes
defined → undefined"). It is not. The **relation loss is PRE-EXISTING**: the
same clause shape spelled with dot-access instead of broadcast behaves
**identically** at pre-G2 (`0fd2098c`) and at `b429d038` —

```
defr dotbare [?a]
  &> base users.name 2
(dotbare q)
```
→ guard fires, relation never registers, `solve: Unknown relation: dotbare`,
file continues — **byte-identical on both legs** (fresh-file A/B, 2026-08-05).
G2 only added *broadcast* to a trigger set that already contained dot-access and
postfix-index (`xs[0]`); all three verified at `b429d038`.

**Root cause (verified by instrumenting `parse-clause-content`)**: `macros.rkt`
strips every top-level form to a bare datum before preparse
(`(define datum (syntax->datum stx))`, :3168) and the `defr` arm rebuilds with a
**3-arg** `datum->syntax` (:~3391), so every inner element inherits the `defr`'s
own line/column. Measured: a healthy clause has sentinel col 2 and element cols
`(5,5) (5,10) (5,13)`; a rewritten one has **every element at `(6,0)`**, and
`parse-clause-content`'s `(zero? sent-col)` test routes to `parse-degraded`,
which only accepts fully-parenthesized goals.

This is a **NAMED, EYES-OPEN POL.8 LIMIT**, not an accident — the Rel T1 design
doc says so verbatim ("degraded srclocs … are DETECTED via the impossible
sentinel-column-0 marker: all-paren parses as before, parenless errors with
guidance") and it is test-pinned at `test-rel-t1-pol.rkt` ("POL.8: degraded
srclocs (preparse rewrite) + parenless goals → guidance").

**Owner ruling 2026-08-05: option (a)** — keep the limit, fix only the message.
The message now names the CONDITION (a preparse rewrite anywhere in the defr)
and all three families, instead of "(e.g. dot-access)". Note "teach the guard
about `$bcast-step`" would have been wrong by construction: `pol8-goal-pair?`
requires a *pair*, so `&> base users:name` fails on the bare head `base` before
any sentinel is consulted.

**Still open, deliberately** (pinned as status quo so a change is conscious):
- **(b)** the refusal takes the relation's registration with it. Prior art for a
  better shape already exists — the floundering gate produces *"Unknown relation:
  unsafe-r — its defr failed to register (see the earlier error)"*. Registering
  the relation with only its GOOD clauses is refused: that would be a silent
  wrong answer.
- **(c)** lifting the limit (srcloc-preserving preparse). Expensive: because the
  strip is at :3168, srclocs cannot be preserved *through* expansion — it needs
  either a syntax-aware `preparse-expand-form` or a post-rebuild re-attachment
  walk. ⚠ Blast radius is **narrower than feared**: probed 2026-08-05, the `let`
  aligned-block classifier and `||` multi-row fact splitting both survive a
  rewrite intact (`b` = 9 with and without dot-access in the form), because the
  reader's indent grouping already built their structure. `parse-clause-content`
  is the only consumer that re-derives layout AFTER preparse.

### 52. ✅ FIXED 2026-08-05 (commit `e0f03601`; owner-ruled) — a type error in relational GOAL-ARGUMENT position was silently swallowed

**⚠ The filed A/B was a MIS-DIAGNOSIS.** As filed: "a goal-position arity error
becomes a silent empty bag". Re-measured against a pre-G2 baseline worktree:

- Pre-G2, `a:b` was **spliced into two tokens**, so a 2-argument call was
  reported as `p2/4`. That "loud arity error" was **itself a symptom of the
  splicing bug** — the diagnostic was a lie. G2 made arity counting CORRECT
  (`(p2 1:Int)` → `p2/1`; `(p2 1:Int 2:Int 3:Int)` → `p2/3`). Nothing to restore.
- The silent empty bag is **not new and unrelated to broadcast**: pre-G2,
  `(p2 1:Int)` already returned a silent `@[]`, and `[+ "str" 1]` /
  `[undefined-fn 1]` in goal-arg position are silent on **both** legs.

**The actual defect** (found by instrumenting `infer`): the "Goals → Goal" and
solve/explain arms of `infer` (typing-core.rkt) called `infer` on goal arguments
purely for effect and returned a fixed type, **discarding an `expr-error`
result**. `infer` signals type failure by RETURNING `(expr-error)`, not by
raising. So an ill-typed argument became an opaque term that unified with
nothing → empty bag, zero errors. The same expression is LOUD in `def` position
and as a bare expression command:

```
(q1 [+ "str" 1])     → @[]  zero errors        def z := [+ "str" 1] → ERROR
(q1 1:Int)           → @[]  zero errors        1:Int (bare)         → ERROR
(is x [+ "str" 1])   → @[{:x unknown}]         ← a bogus BINDING, worse than @[]
```

**The fix** propagates the error, gated on **logic-var freedom**. That gate is
load-bearing and was learned the hard way: an ungated first version broke the
pinned POL.9 test "a preparse rewrite inside a paren goal keeps goal-ness",
because under the relational fallback a bare name is a LOGIC VARIABLE — so in
`(fruit-color f mm.c)`, `mm` is a logic var and `mm.c` is genuinely
un-inferrable **without being a user error** (the documented "computed goal args
don't evaluate" semantics). Rule applied: **propagate only from EVALUATED,
logic-var-free positions**.
- `expr-goal-app` args — evaluated (`(q1 [+ 0 1])` → `@[{}]`) ⇒ propagate
- `expr-is-goal` RHS — evaluated (`(is x [+ 1 1])` → `{:x 2}`) ⇒ propagate
- `expr-unify-goal` — **NOT** tightened: `=` does not evaluate at all
  (`(= x [+ 1 1])` and `(= x [+ "str" 1])` both render `{:x unknown}`), so its
  operands are TERMS and rejecting one would be inconsistent.

**⚠ THE GATE HAD TO BE WIDENED TWICE — an `expr-error` out of the IMPERATIVE
`infer` has THREE meanings, not two.** The adversarial verify found three live
over-rejections in the first version of this fix, all of which the full suite
(9863 tests) passed straight through:

| input | before the fix | first fix | why |
|---|---|---|---|
| `(q1 [pair 1 2])` | `@[]` | **ERROR** | `infer` has NO `expr-pair` arm — it types pairs only in `check`, against an expected Sigma. The ON-NETWORK inferencer has a rule, and the command boundary tries on-network FIRST, so `def z := [pair 1 2]` succeeds (`[Sigma Int Int]`) while goal args — which reach the imperative inferencer only — did not. |
| `(is g2 [int* _ 2])` | binds a closure | **ERROR** | a partial-application section types only in CHECK position, and an `is` RHS is inferred with no expected type. It also escapes the logic-var gate BY CONSTRUCTION: the elaborator turns the relational fallback OFF for an `is` RHS, so `_` stays an `expr-hole` rather than becoming a logic var. This is the idiom `prologos-syntax.md` explicitly RECOMMENDS. |
| `solve (guard [lt 0 1])` | stuck term | **ERROR** | the 1-arg form elaborates to `(expr-guard ec #f)`; the pre-fix arm called `(infer ctx #f)` and DISCARDED it. Every other walker over this struct carries `(and goal …)`; this arm now does too. |

So the excuse predicate is `goal-arg-excused?`, not "contains a logic var": an
argument is excused if it contains a logic variable **or** a node the imperative
`infer` cannot synthesize (`infer-unsynthesizable?` — `expr-pair`, `expr-hole`,
`expr-reduce`, `expr-refl`). That set is **DERIVED, not guessed**: it is exactly
`{nodes with register-typing-rule!} \ {nodes with an imperative infer arm}`
minus `expr-error`, computed mechanically — and `test-goal-arg-typing.rkt`
**recomputes it from source and fails on drift**, so a future
`register-typing-rule!` cannot silently widen the class and reintroduce the
`expr-pair` shape under another node name.

`goal-arg-excused?` is a **generic reflective walk**, not a hand-armed one
(`.claude/rules/pipeline.md` § Exhaustive Walkers). reduction.rkt's
`collect-deep-logic-vars` was unusable for this: it arms only 4 node kinds behind
an `[else '()]` catch-all and has **no `expr-select` arm**, so it reports "no
logic vars" for `mm.c` — the exact form the predicate exists to recognise.
⚠ Its own honest limit: the walk covers struct / pair / vector / hash / set / box,
so it cannot miss a NODE kind, but a sub-expression reachable only through some
other container type would be missed. None exists today.

**Named residuals** (real, out of the ruled scope):
- **The gate's WHOLE-ARGUMENT granularity is now BIMODAL, which reads as
  nondeterminism.** Two clauses with the SAME type error diverge on whether a
  logic var happens to sit beside it:
  `&> (fc x [+ "str" 1])` → the defr is DELETED;
  `&> (fc x [+ "str" y])` → registers, query returns a silent `@[]`.
  Pre-change both were silent — the residual existed but its consequences were
  UNIFORM. Sharpened by the adversarial verify, and it is the strongest argument
  for the subterm-granularity fix below.
- An argument containing a logic var AND a genuine type error stays silent
  (`(q1 [+ "str" ?x])`) — the gate is deliberately conservative, and since a goal
  argument that mentions a variable is the NORMAL relational shape, the fix is
  live mainly on fully-ground arguments. Worse sub-case found by the verify:
  `(not (q1 [+ "str" ?y]))` returns `@[{}]` — the ill-typed inner goal silently
  fails to match, so the NEGATION succeeds. A wrong positive, not just a lost
  diagnostic. Pre-existing (all of these were silent before), but the right
  long-term fix is to test logic-var-freedom at the FAILING SUBTERM rather than
  at the argument root.
- ~~`expr-clause` / `expr-fact-block` / `expr-fact-row` still discard sub-errors~~
  **✅ FIXED same day, owner-requested** (see below). Those three plus
  `expr-defr`, `expr-defr-variant` and `expr-rel` now propagate, so an ill-typed
  goal in a `defr` clause BODY is loud at registration. ⚠ The consequence, stated
  eyes-open: this **widens the class of `defr`s that fail to register**, which is
  51(b) territory pointing the opposite way — 51(b) frames registration-loss as
  the problem and names a better shape (the enriched *"its defr failed to
  register (see the earlier error)"* message) as prior art. Owner-directed, so
  not illegitimate, but the two entries pull against each other until 51(b) is
  taken. Adopting that enriched message would reconcile them.
  ⚠ `expr-fact-row`'s propagation is **inert for compound terms** — they are
  splayed at parse time before typing sees them (DEFERRED 53).
  ⚠ Still swallowing, same shape, no repro constructed: `expr-narrow`.
  ⚠ **The rejection now NAMES the relation** — `defr badclause: Could not infer
  type — the relation was NOT registered` — because the bare form gave a
  whole-relation deletion with no pointer to which `defr`. The QUERY-side message
  is still the bare `Unknown relation: badclause` (misleading — they DID define
  it) rather than the enriched *"its defr failed to register (see the earlier
  error)"* that the schema/floundering gates get. Reaching that branch needs the
  name env-bound to an `expr-defr`, i.e. an env write carrying a body that FAILED
  to type — which `zonk` may not survive (DEFERRED 54). That reconciliation is
  51(b)'s job.
- `(= x [+ 1 1])` rendering the binding as `unknown` is its own pre-existing
  display defect; pinned as status quo.
- `expr-guard`'s CONDITION is checked with `check`, whose boolean result is
  discarded, so an ill-typed guard condition behaves exactly like `guard true`
  (`(guard [+ "str" 1])` succeeds). Pre-existing; unreachable in practice today
  because `expr-clause` swallows it first.


### 53. ✅ FIXED 2026-08-05 — a compound term in a `||` fact row was SPLAYED into fabricated rows (pre-existing silent WRONG ANSWER)

Measured, **byte-identical at `b429d038` and after the DEFERRED 51/52 work**, so
this is neither caused by nor fixed by that arc:

```
defr r2 [?a]
  || [some 1]
solve (r2 q)        →  @[{:q unknown} {:q 1}]        ← TWO rows, from ONE

defr r3 [?a]
  || '[1 2]
solve (r3 q)        →  @[{:q unknown} {:q 1} {:q 2}] ← THREE rows, from ONE

defr r4 [?a ?b]
  || {:k 1} 2       →  ERROR: defr facts: 3 terms do not fill rows of arity 2
```

**This is the silent-wrong-answer class, not a lost diagnostic**: the query
returns rows that were never written, with ZERO errors, and the fabricated
values (`unknown`, then the constituent tokens) are indistinguishable from real
data. `r4` is the only arity that gets caught, and only by accident — the splay
happens to make the term count wrong.

**Mechanism** (suspected, from the CIU T6 grounding critic's G5 — verify before
fixing): `parser.rkt`'s fact-row splitter partitions on `term-sentinel?`, which
is a **numeric-literal whitelist** (`$nat-literal`, `$decimal-literal`,
`$float-literal`, `$exp-literal`, `$posit-literal`). Anything else that is a
compound pair is treated as a NESTED ROW and splayed. The polarity is the same
as `pattern-var?`'s — the fix is inversion (a conservative default), not adding
another member.

**Why it stayed hidden**: `grep -rn "^\s*||.*("` over `examples/` and `lib/`
returns **zero** compound fact terms, so nothing in the corpus or the suite
exercises it. The DEFERRED 52 fix added `expr-fact-row` propagation, which is
therefore **inert for compound terms** — they are splayed into individually
well-typed atoms before typing ever sees them. That propagation is not wrong,
just currently unreachable by this shape; it is recorded here so nobody reads it
as coverage.

**Also noted from the same probe** (separate, smaller): a `3.14` or `nil` fact
row renders as `unknown` in a solution row — pre-existing, unrelated to the
splay, and probably the same display gap as `(= x [+ 1 1])` → `{:x unknown}` in
DEFERRED 52's residuals.

---

#### THE FIX (2026-08-05) — two changes, and what each one buys

**(A) `term-sentinel?` INVERTED.** It was a five-member numeric whitelist
(`$nat-literal`, `$decimal-literal`, `$float-literal`, `$exp-literal`,
`$posit-literal`), so every OTHER reader sentinel fell through to the
`pair? ⇒ nested row` reading — the exact "new sentinel, old recognizer" polarity
failure `.claude/rules/pipeline.md` warns about. It now tests **`$`-headedness
AND NOT structural**, so a future VALUE sentinel is a term BY CONSTRUCTION. This
is what fixes `'[1 2]` (which reads as `($list-literal-parse 1 2)`), and — being
srcloc-independent — it fixes `$`-headed compounds on CONTINUATION lines too,
including the row REORDERING the splay caused (nested rows are appended after all
flat rows, so `|| 1 / '[2 3] / 4` used to come back 1, 4, 2, 3).

⚠ **The "AND NOT structural" half was learned the hard way.** The first version
asserted that inside fact CONTENT a `$`-headed pair is always ONE VALUE. **False**:
the reader wraps a continuation LINE by its FIRST TOKEN, so a line beginning with
a structural sentinel arrives as `($pipe 3 4)` / `($clause-sep foo a)` /
`($facts-sep 2)`. Classifying those as terms turned an ordinary leading-pipe
table

```
defr digit [?d]
  || 0
   | 1
   | 2
```

from a LOUD `empty row beside \`|\`` into **two fabricated rows leaking the raw
sentinel** — `@[{:d 0} {:d [?$pipe 1]} {:d [?$pipe 2]}]`, zero errors — i.e. it
moved a NEW shape into the very class this entry is about. Caught by the
adversarial verify; regression-pinned. The exclusion reads the structural set off
the predicates that already define it (`sentinel-kind-of`, `$pipe`) so it cannot
drift from them.

**(B) A LINE RULE.** An element on the same source line as the `$facts-sep`
sentinel is a first-row TERM, never a nested row — a continuation row is BY
DEFINITION on a later line. This is what fixes `[some 1]` and `{:k 1}`, which are
plain groups, not `$`-headed. Verified by instrumenting the reader: `|| 1 2` /
`3 4` gives sentinel line 3 with the nested `(3 4)` at line 4, while
`|| [some 1]` puts sentinel and compound BOTH on line 6.

⚠ **Guarded on trustworthy srclocs** via DEFERRED 51's impossible-column-0
marker: a preparse rewrite anywhere in the defr collapses every element onto the
defr's own line, which would make "same line" vacuously TRUE and MERGE real
continuation rows into the first row. Degraded ⇒ exact old behaviour, A/B'd
byte-identical.

**Measured** (`b429d038` vs fixed): `|| [some 1]` 2 rows → **1**; `|| '[1 2]`
3 rows → **1**; `|| {:k 1} 2` arity error → **1 row**. Controls byte-identical:
multi-line continuation rows, arity chunking (`|| 1 2 3 4` at arity 2 → 2 rows),
pipes mixed with continuation lines, leading-pipe tables, and the degraded-srcloc
fallback. An independent element-by-element A/B of the OLD vs NEW predicate over
**all 20 corpus files containing a `||` line (86 fact groups) reclassified ZERO
elements**.

#### Residuals — all test-pinned

1. **A preparse rewrite ANYWHERE in the defr disables rule (B) — the biggest
   limit, and it acts AT A DISTANCE.** `macros.rkt` rebuilds the whole defr
   whenever preparse changes anything in it (DEFERRED 51), collapsing every
   element to column 0; the guard then declines, and "declines" means the
   FABRICATION RETURNS. Confirmed triggers include `|>` and dot-access — both
   documented as IDIOMATIC in `prologos-syntax.md`. Note the list literal that
   (A) fixes is itself a (B)-killer for its siblings: `|| '[1 2]` beside
   `|| [some 3]` splays the latter. Rule (A) is srcloc-independent and survives.
   Closing this needs **DEFERRED 51(c)**, not more work here.
2. **A NON-`$`-headed compound alone on a CONTINUATION line is still splayed**
   (e.g. `[some 2]`). Narrow by design — the `$`-headed case is fixed by (A).
   The reader has already SPLICED the bracket group away there, so `[some 2]`
   and a bare two-token row `some 2` are literally the same datum.
   ⚠ **Closing it is cheaper than first assessed**: `parse-reader.rkt` already
   attaches `'prologos-paren-origin` to PAREN groups at the group-construction
   site and returns bracket groups bare — so a bracket marker is a one-line,
   precedented change at that same site. It would NOT close residual 1, because
   the degraded rebuild destroys syntax PROPERTIES exactly as it destroys
   srclocs.
3. **Compound fact VALUES do not work — the row is SEMANTICALLY DEAD, not merely
   mis-rendered.** `|| [some 1]` then `(m1 [some 1])` → `@[]`: the row cannot be
   matched by the very term that wrote it. Removing the splay is what makes
   compounds REACH the solver, where this shows. Corrections to the first draft
   of this note, all from the adversarial verify:
   · `[some 1]` does not render `unknown` — it renders **`[?some 1]`**: the
     CONSTRUCTOR HEAD became a logic variable, i.e. a fact row containing a free
     variable, and the column type is **`<error>`** emitted under `--- 0 errors ---`.
   · that mangling is **fact-row-specific, NOT pre-existing** — `(= x [some 1])`
     renders correctly. Only the `'[1 2]` / `{:k 1}` shapes reproduce outside a
     fact row (`(= y '[1 2])` → `unknown`).
   So the fix trades "N fabricated rows" for "1 unmatchable row". Strictly better
   (the count is right and nothing is invented) but still not WORKING — do not
   read the row-count fix as making compound facts usable.

### 54. The four global-constraint goal forms are parser-reachable but UNPLUMBED (`zonk` has no arm) — found 2026-08-05

`all-different`, `element`, `cumulative`, `minimize` are gated on
`current-parsing-relational-goal?` (parser.rkt), so a clause body is the ONLY
place they can be written. They are not carried through the pipeline: `grep -n
"expr-all-different\|expr-cumulative\|expr-minimize" typing-core.rkt` → zero
hits, and `zonk` has no arm either. At `b429d038` this input

```
defr digits [?d]
  || 1 | 2 | 3
defr c1 [?a ?b]
  &> (digits a) (digits b) (all-different a b)
def marker := 99
```

died with `match: no matching clause for (expr-all-different '(a b))`
(`zonk.rkt:75`) and produced **NO output at all** — a WHOLE-FILE ABORT, the class
`.claude/rules/pipeline.md` § "A Raise on the Parse/Expansion Path" tells us to
hunt ("the tell: output is EMPTY, not partial"). `digits` never printed.

**The DEFERRED 52 clause-body propagation incidentally FIXED the abort**: `infer`
now rejects the clause before `zonk` runs, so it is a per-command error and the
file continues. Test-pinned. ⚠ Do NOT "fix" this by excusing these node kinds in
`infer` — that would let the term reach `zonk` and restore the crash.

**What remains**: the forms are still unusable. Making them work means plumbing
them through the AST pipeline (`.claude/rules/pipeline.md` checklist —
`zonk` ×3, `substitution`, `pretty-print`, `typing-core`, `qtt`,
`pnet-serialize`, …) and giving `reduction.rkt` a real consumer; today
`reduction.rkt`'s only arm is a stuck/identity case and `relations.rkt` never
consumes them. Until then a user who writes one gets "Could not infer type",
which is honest but does not say the form is unimplemented.

⚠ An adversarial verify reported this as a BLOCKING regression of the
clause-body fix, on the belief that these forms "registered" before. Measurement
refuted that — they aborted the file. Recorded so the claim is not re-inherited.

⚠ A SECOND adversarial verify made a broader version of the same claim: that the
excuse set is derived from the wrong universe (it is `{register-typing-rule!} \
{infer arms}`, where the clause-body call sites arguably want `{all expr kinds} \
{infer arms}` — 19 kinds, not 4), and that 11 surface-reachable constructs
therefore now delete their relation. The DERIVATION critique is fair and worth
keeping in view. The REGRESSION claim was refuted by measurement: the headline
examples (`[vnil Int]`, `[fzero 3N]`) **fail to infer in `def` position too**, so
rejecting them in goal position makes the two AGREE. Def-position behaviour is
the oracle for whether a goal-arg rejection is correct, and it is now
test-pinned. `[pair 1 2]` — which DOES type in def position — is exempted, which
is exactly the distinction the derivation was built to make.

**Adjacent, unfixed**: `expr-narrow` (typing-core.rkt) still infers its
`func`/`args`/`target` for effect and returns `expr-hole` — the same swallow
shape as the arms fixed in DEFERRED 52, left in place because no repro was
constructed for it.
