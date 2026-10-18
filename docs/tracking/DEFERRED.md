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

<a id="numbering"></a>

## ⭐ NUMBERING — MONOTONIC, PERMANENT, NEVER REUSED  [owner ruling, 2026-08-08]

> ### **NEXT FREE: 181**
> Allocate from THIS REGISTER and bump it in the same commit. **It is the only
> allocation source.**

**MAPPING — branch `wizardly-mendel-2fd502`, renumbered 2026-08-08 at merge prep.**
The branch allocated 84–87 from a register reading 84; main independently filed
84–96. Main's entries did NOT move. Resolve any citation of 84–87 by ancestry.

| was | now | branch entry |
|---|---|---|
| 84 | 97  | three `let` spellings + `def-` refuse a postfix access |
| 85 | 98  | an empty group at command position aborts the file |
| 86 | 99  | `'(…)` the quoted goal |
| 87 | 100 | a goal keyword under an access gets the wrong message |

⚠ Commit messages `44da4627` and `2fe6c8a4` cite the OLD numbers and are immutable.

**Four rules. The first is the one that was being broken.**

1. **NEVER derive the next number from `max(heading) + 1`.** That was the de-facto
   practice and it is what made a number REUSABLE: after any renumber, deletion,
   or move to `DEFERRED_COMPLETE.md`, the max drops and the next writer silently
   re-issues a number that is already cited in an immutable commit message.
   The register above only ever goes UP.
2. **A number is PERMANENT once allocated.** It is never reassigned to a different
   entry — not when the entry is fixed, dissolved, superseded, or moved to
   `DEFERRED_COMPLETE.md`. Retiring an entry retires its number with it. Gaps are
   expected and are not a defect to tidy up.
3. **NEVER renumber a LIVE entry.** Commit messages, code comments and test names
   are immutable references; renumbering silently invalidates all of them.
4. **A branch that will file entries CLAIMS A BLOCK FIRST.** Bump the trunk's
   register by the size of the block in a one-line commit on `main`, then allocate
   only inside the claimed block. This is the actual collision prevention — rules
   1–3 make a collision *detectable and honest*, but only a claimed block makes it
   *impossible*. Two branches that both allocate "the next few numbers" from the
   same register value will collide however careful each is on its own.

**Why this exists — the incident it is named for.** At the merge `2fd6b68e`
(2026-08-08) branch `wizardly-mendel-2fd502` and `main` had each independently
allocated **53–61**. Nine entries collided. Because both sides had already cited
those numbers in commit messages, one side had to be renumbered — the branch's
53–61 became **66–74** — and every affected commit message is now permanently
wrong, mitigated only by the mapping table below and a `was N → now M` note on
each entry. It also left `### 53` meaning **three** different things depending on
which side and which era you read it from, so any reference to it must be resolved
by ancestry (`git merge-base --is-ancestor <sha> 2b52af8b`; success = main-side).
That is the cost this section exists to never pay twice.

**When a collision has already happened** (i.e. rule 4 was missed): the side that
has NOT yet merged renumbers into fresh numbers above the register, every moved
entry carries a `was N → now M` note, a mapping table is added, and code comments
and test names are swept in the SAME commit. Commit messages cannot be fixed —
say so explicitly rather than letting a reader assume they are current.

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
## 🟡 MITIGATED `51b6b1f9` (SW-27) — Cross-FILE spec-store leakage within a batch worker (diagnosed 2026-07-31, LET P1 gate)

> **Mitigated 2026-10-13 by SW-27 (DEFERRED 160).** The unforked box was one channel; the other was the DRIVER: registrations
> assign their parameters and `process-file` bound none, so it leaked in the LSP and any multi-program process too. Both
> are now scoped per compilation unit. Still open (owner): specs keyed by bare name rather than by namespace — see 160.
> The history below is kept as found.

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

**Mechanism ESTABLISHED 2026-10-13** (checkpoint 3 gate; DEFERRED 160's `test-error-messages` sightings, and
the same predecessor file as in 2026-07-31). Two probes, one plain Racket process, through `test-support`'s
`run-ns-*` helpers (scratch `probe160-spec-leak.rkt`, `probe160-netbox.rkt`; copies in the
racket-performance-probing skill): (1) `defn ok2` in `ns t` defines as `Nat -> Int`; after a program with
`(spec ok2 Nat -> Nat)` in `ns test`, the same `defn ok2` in `ns t` fails "cannot infer the type of an
unannotated parameter"; a same-bodied `okq` still defines. (2) That spec program CHANGES the contents of
`prelude-persistent-registry-net-box`; with its contents restored before the victim, the victim defines as
`Nat -> Int`. So the unforked box that `run-ns-*` share (`test-support.rkt:148`, `:167`, `:191`) carries the
leak, keyed by the bare name across namespaces. **Fix shape** (a decision, with 160): fork the box per call as
`with-forked-network` does for the propagator net, and/or restore it per file in the batch worker. **Open**:
whether the driver itself (LSP, REPL: many programs in one process) has an analogous leak is UNTESTED.

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
- **Origin**: PPN 4C Tropical Quantale Addendum 1C-vi A/B/C report (2026-05-16; `docs/tracking/tracks/PPN/PPN_4C/2026-05-16_TROPICAL_1C_VI_ABC_REPORT.md`); design doc §13.7 cross-track note flagged as "small tool enhancement"
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
| `current-lattice-meta-solution-fn` callback parameter | 4C addendum S2.c-iii audit (2026-04-24) | ⬜ flagged | Racket parameter holding `meta-solution` function ([type-lattice.rkt:68](../../racket/prologos/type-lattice.rkt)). Installed by driver.rkt:2633 via `install-lattice-meta-solution-fn!`. Used by type-lattice.rkt:86, 176, 399, 403, 421 for `is-meta-unsolved?`-style checks during ground-check + subtype operations. Off-network scaffolding to break import cycle (type-lattice.rkt is leaf module; can't import metavar-store.rkt). | Set once at driver init via `install-lattice-meta-solution-fn!`; read on demand during type-lattice operations. **Mantra violations**: ❌ off-network, ❌ not structurally emergent (callback invocation is imperative), ❌ not info flow through cells. | **PM Track 12 + PPN 4C parent Phase 4 jointly retire**: when PM 12 makes module-load-time infrastructure on-network (cells accessible from leaf modules via scope chain), type-lattice.rkt's queries restructure to read directly from cells. Phase 4's CHAMP retirement provides the natural reframing point for the data flow (was reading CHAMP via callback → reads attribute-map facet via universe dispatch). See [PPN 4C parent Phase 4 row](tracks/PPN/PPN_4C/2026-04-17_PPN_TRACK4C_DESIGN.md) for absorbed scope. The "constraint on shim signature" (post-S2.c-iii: `meta-solution` must remain a top-level definition with signature `(id) -> solution-or-#f` so the callback installation works) is not a feature — it's a constraint imposed by this scaffolding. |
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

Phase 1e-α's η split of `merge-hasheq-union` surfaced a scope conflation in the current architecture that PM Track 12 is positioned to resolve. Core finding (from [PPN 4C D.3 §6.14.2](tracks/PPN/PPN_4C/2026-04-17_PPN_TRACK4C_DESIGN.md)):

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
| `narrow-var-constraints` cell at [global-constraints.rkt:104](tracks/PPN/PPN_4C/2026-04-17_PPN_TRACK4C_DESIGN.md) | `current-narrow-var-constraints` | `merge-last-write-wins` | `net-new-timestamped-cell` |
| `ns-context` cell at [namespace.rkt:757](tracks/PPN/PPN_4C/2026-04-17_PPN_TRACK4C_DESIGN.md) | `current-ns-context` | `merge-replace` | `net-new-timestamped-cell` |
| `defn-param-names` cell at [global-env.rkt:358](tracks/PPN/PPN_4C/2026-04-17_PPN_TRACK4C_DESIGN.md) | `current-defn-param-names` | `merge-replace` | `net-new-timestamped-cell` |
| per-name definition cells at [global-env.rkt:121, 354](tracks/PPN/PPN_4C/2026-04-17_PPN_TRACK4C_DESIGN.md) | `current-definition-cell-ids` (map) | `merge-replace` | `net-new-timestamped-cell` per name |

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

### ~~`+` `-` `*` `/` should work as higher-order generic functions~~ ✅ STALE — FIXED by Numerics N6e-E2
- ~~Currently parser keywords, can't be passed to `map`/`reduce` or use `_` placeholders~~
- ~~First-class wrappers (`plus`, `minus`, `times`, `divide`) exist as workarounds~~
- Source: LSP Tier 4 testing
- ⚠ **MEASURED FALSE 2026-08-08.** `[map negate '[1 2 3]]` → `'[-1 -2 -3]`,
  `[reduce + 0 '[1 2 3 4 5]]` → `15`. And it is not only the operators — the
  PRIMITIVE and CONVERSION keywords pass too: `[map from-nat [range 3N]]` →
  `'[0 1 2]`, `[map p32-sqrt '[4.0 9.0 16.0]]` → `'[2.0 3.0 4.0]`,
  `[map p32-from-int '[1 2 3]]` → `'[1.0 2.0 3.0]`. `.claude/rules/prologos-syntax.md`
  records the N6e-E2 change; this entry was never updated. Struck through rather
  than deleted so the claim's history stays visible.

### Trait-constrained functions can't be passed bare to higher-order functions
- `reduce plus 0 '[1 2 3 4 5]` fails — elaborator can't auto-insert dict args in HO position
- **Blocked on**: elaborator enhancement for automatic eta-expansion + dictionary insertion
- Source: LSP Tier 4 testing
- ⚠ **PARTIALLY STALE 2026-08-08** — the sibling entry above is now false, and
  the named repro's shape works: `[reduce + 0 '[1 2 3 4 5]]` → `15`. Whether the
  *bare trait-method* case (`plus`) still fails was NOT re-measured; re-check
  before acting on this entry.

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
- [D.4 design doc](tracks/PPN/PPN_4C/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md) §10 — D.4 canonical direct migration (replaces D.3 hybrid)
- [D.4 design doc](tracks/PPN/PPN_4C/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md) §13.6 — Pre-0 spike plan + result
- [§4.6 Specialized cell type framework](tracks/PPN/PPN_4C/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md) — the canonical D.4 architecture
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

**Source**: PPN 4C addendum [§9.5.4.14 KR-1/2/3 named drift](tracks/PPN/PPN_4C/2026-04-21_PPN_4C_PHASE_9_DESIGN.md) (captured at 3C.c-VAG close 2026-05-24, commit `25f4343c`) + [§9.5.5 Phase 3C.d mini-design](tracks/PPN/PPN_4C/2026-04-21_PPN_4C_PHASE_9_DESIGN.md) Q-D.1 lock + [§9.5.5.13 empirical findings](tracks/PPN/PPN_4C/2026-04-21_PPN_4C_PHASE_9_DESIGN.md) (commit `ebf56b80`).

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

- Source design: PPN 4C addendum [§9.5.4.14 (KR-1/2/3 named drift)](tracks/PPN/PPN_4C/2026-04-21_PPN_4C_PHASE_9_DESIGN.md) + [§9.5.5 (3C.d mini-design)](tracks/PPN/PPN_4C/2026-04-21_PPN_4C_PHASE_9_DESIGN.md) + [§9.5.5.13 (3C.d.3 empirical findings)](tracks/PPN/PPN_4C/2026-04-21_PPN_4C_PHASE_9_DESIGN.md)
- 3-column adversarial Q-D.1 lock: [§9.5.5.4](tracks/PPN/PPN_4C/2026-04-21_PPN_4C_PHASE_9_DESIGN.md)
- Parent D.3 Phase 11b row: [PPN Track 4C D.3](tracks/PPN/PPN_4C/2026-04-17_PPN_TRACK4C_DESIGN.md) Progress Tracker Phase 11b (2026-05-24 scope addition)
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

- Source audit: PPN 4C addendum [§18.10.4 (FREE_ORDERING at preparse layer)](tracks/PPN/PPN_4C/2026-04-21_PPN_4C_PHASE_9_DESIGN.md) + [§18.5 (PM 12 boundary)](tracks/PPN/PPN_4C/2026-04-21_PPN_4C_PHASE_9_DESIGN.md) + [§18.11 (cyclic definitions principle)](tracks/PPN/PPN_4C/2026-04-21_PPN_4C_PHASE_9_DESIGN.md)
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

### 37b. ✅ DISCHARGED at P4c-4b (`6b22515d`) — `$bcast-step` joined `access-sentinel?`

Item 37's gap is closed: the predicate, the membership, and the fold arm all
landed, and the fold's emitted head is `$select-path` so the fixpoint obligation
holds by construction.

### 42-original. The `:{…}` reader mint — a P4d PREREQUISITE, unhomed until now

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

~~**Sites verified BLIND-BUT-SAFE by the sweep** (no action): `syntax.rkt:1204`
(`select-sub-step?` in the dissolve arm — measured equivalent on both paths,
structurally so, since the `[(bcast)]` arm re-enters with the same `rest`);
`typing-core.rkt:1016`/`:1057`/`:1132`/`:1142` and `reduction.rkt:1778` (all fall
through to a `memq` guard → the `bcast` arm → `select-bcast-not-yet`, i.e. blind
but LOUD).~~
⚠ **THE EXONERATION ABOVE WENT STALE 3 DAYS AFTER IT WAS WRITTEN** (caught by the
`:{`-phase mini-audit): `select-bcast-not-yet` was RETIRED at P4c-4c — zero
definitions, zero callers — so "blind but LOUD" no longer describes those five
sites. They now route to the LIVE value-semantics arms, which is *better* than
loud for a symbol inner — and *worse* for a sub inner, whose raw `(@sub …)` list
reaches carrier diagnostics as a "name". Re-derive the verdict at the `:{` phase;
do not inherit it.
⚠ **Coordinates drifted**: the two parser sites are now `parser.rkt:1178` (was
:1170) and `parser.rkt:1281` (was :1212) — re-find by SHAPE, not number.
⚠ The prescribed :1281 fix (reuse `select-step-name`) is SAFE only while
`select-step-name` returns values — see the adjudication note at 40.

### 40. ⚠ CROSS-REF ADDED 2026-08-05: **this is the SAME DEFECT as 46**, seen from the other side — and the two entries prescribed CONFLICTING fixes with no cross-reference (caught by the `:{`-phase mini-audit `wf_e15a1ef6-dfb`). 46 says *handle* the sub-inner ω; this entry says *make the walk total by raising* (`select-step-kind-unhandled` is a bare `error`). ⚠⚠ And 39's prescribed reuse of `select-step-name` at its parser site COMPOSES with this entry's raise into a WHOLE-FILE ABORT on the parse path. **Adjudication (follows from the owner's two 2026-08-05 rulings — site-local guards; no new raises on the parse path)**: the `:{` phase fixes 46 by discriminating on the INNER KIND in the two lifts, which removes the ω route to this defect entirely; the residual here (the PRE-EXISTING, latent, non-ω `[else s]` contract violation) stays deferred, and when it lands its fix must be a VALUE-channel one — NOT the raise this entry originally prescribed. `select-step-name` is still not TOTAL — `(@ord N)` and `(@sub …)` return LISTS

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
> [Track 3 § Phase 7 status](tracks/PPN/PPN_3/2026-04-01_PPN_TRACK3_DESIGN.md#p7-status).
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
   | the reader's 5 parse cells (char·indent·token·bracket·tree, `parse-reader.rkt`) | PPN Track 1 | cells landed, **propagator wiring unbuilt**; scoped by [4D §12](tracks/PPN/PPN_4D/2026-05-19_PPN_4D_IMPLEMENTATION_DRAFT_NOTE.md) | **NO** |
   | the per-form cells (`form-cells.rkt`, source-line keyed) | PPN Track 3 | written, read by nothing **yet** | **NO** |
   | the merge's tree leg (`parse-top-level-forms-from-tree` → `tree-by-line` → `merge-form`) | the merge | never fired, now gated off | **YES — only this** |

   **PPN Track 3 Phase 7's own design says to DELETE the merge.** Verbatim
   ([Track 3 design](tracks/PPN/PPN_3/2026-04-01_PPN_TRACK3_DESIGN.md) §"Phase 7: Pure Merge
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
   conflict with [Track 3 §11's](tracks/PPN/PPN_3/2026-04-01_PPN_TRACK3_DESIGN.md) "tree-parsing is
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

### 46-original. ⚠ CROSS-REF + CORRECTION 2026-08-05 (mini-audit `wf_e15a1ef6-dfb`): **same defect as 40**; and "unhandled" is MISLOCATED — both twins HAVE bcast arms (P4c-4c); the defect is that the LIFTS apply the inner step as a ONE-STEP BRANCH, putting `@sub` at branch-head where `select-step-name` hands the raw list to the `(key caret sub)` arm as a "field name". Outcome is CARRIER-DEPENDENT (closed row: loud-but-LYING; dyn row / Map at 'path: SILENT ACCEPT), not the blanket "silent wrong answer" recorded. One fix point per side (`select-bcast-lift` / `bcast-apply`), discriminating on the inner kind. `(@bcast (@sub …))` is unhandled on both sides — currently UNREACHABLE

`branch-entries` would treat the whole `@sub` list as a field name. Unreachable
because the mint never fires: `xs:{name age}` → "Unbound variable `:`" (DEFERRED
42, the `:{` reader mint). ⚠ So DEFERRED 42 and this entry must land TOGETHER —
minting `:{` without handling the sub-inner ω turns an "unbound variable" into a
silent wrong answer. Scope note for P4d.

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

### 53. 🔀 SPUN OUT (chip `task_e1c15ee6`, 2026-08-05) — PARAMETERIZED `data` binds the TYPE PARAMETER as a constructor

```
data Tree A
  | leaf A
  | branch [Tree A] [Tree A]
[leaf 42]
```
=> `Tree : [Type 0] defined.` · **`A : ns::Tree defined.`** · `Unbound variable`
(leaf) ×3. `A` is the TYPE PARAMETER, bound as a nullary constructor; the real
constructors are never registered.

Non-parameterized `data` **works today**:
`data Direction | north | south` + `defn opposite | north -> south | …` +
`[opposite north]` => `south`, 0 errors.

**Surfaced by** ARROW T1 P3, while trying to un-comment the `int->str` block in
`examples/2026-03-18-track7-acceptance.prologos` (§ K2). That block had THREE
blockers; ARROW fixed one (the reader/arrow one), `int->str` never existed
(the real name is `str::from-int`), and this is the third.

⭐ **It also corrects a stale annotation that FIVE sites in that file point at.**
The E2 note claimed NO file-level `data` registers constructors. That is half
wrong — and the live half is a MIS-PARSE (a wrong binding is created), not a
missing registration, which is a sharper diagnosis than the original. The note
was corrected in place at ARROW T1 P3 (`004c025d`); the file's NULLARY blocks
(Direction, Color, …) are now re-triable and should be un-commented once
confirmed, while the `Tree`-based ones stay blocked on this item.

**Why deferring is safe**: loud `Unbound variable` per command, no silent wrong
answer, and prelude data types (Nat/Bool/List/Option) are unaffected because
they load via module import, not file-level `data`.
**Why it should not sit long**: it silently *invents a binding* (`A`), and it
has already caused four months of a wrong annotation blocking unrelated work.

⚠ Do not gate on `examples/2026-03-18-track7-acceptance.prologos`: >15 minutes
to run and ZERO `;;N=>` markers (it predates the marker system, 2026-07-06).
Use a small probe plus the marker-bearing acceptance files.


### 56. ⬜ GUARD THE PARSE PATH — the class-level completion of option B, its OWN slice (owner ruling 2026-08-05)

`ae26f540` guarded PREPARSE (the per-form fold in `preparse-expand-all`), so a
raise there degrades to a per-command `($preparse-error msg)`. **The PARSE step is
the other half of `pipeline.md`'s own class name** — "A Raise on the
**Parse/Expansion** Path" — and it is still unguarded: `process-file-inner` runs
preparse then parse as separate steps, and a raise in the second escapes whole.

**HEAD-reachable reproducers, measured (3 whole-file aborts, output EMPTY — not
even the `def before := 1` above them):**

```
m{[$bcast-step [a b]]}   →  symbol->string: contract violation, given '(a b)
m{[$bcast-step 5]}       →  symbol->string: contract violation, given 5
m{[$bcast-step]}         →  cadr: contract violation, given '($bcast-step)
```

The specific site (`parser.rkt` `$bcast-step` fold arm, unguarded
`(symbol->string (cadr it))`) gets a SITE-LOCAL shape guard in the `:{` phase
(owner: "site-local"), because the real `:{` mint makes the payload a LIST and
walks straight into it. **This entry is the CLASS**: a per-command guard at the
parse seam, so the SIXTH sentinel does not rediscover what the first five did.

**Why its own slice** (owner ruling): the preparse guard alone converted 20
assertions across 9 files, and parse is the busier path — expect more. It also
re-raises the channel-merging property flagged at the P4c-4c close (a
compiler-internal invariant violation degrading to a per-command error), so the
slice should consider a DISTINGUISHED internal-error marker that keeps raising —
re-splitting the two propositions P4c-4b separated.
⚠ Method note for whoever lands it: the preparse conversion surfaced that
**result-discarding test helpers** (`run-last`, lookup-returning fixtures) can
silently swallow a refusal once it becomes a value. Sweep for those FIRST.

## CIU T6 D4.P4d-0 spin-offs (filed 2026-08-05 from the pre-commit adversarial verify `wf_7d93efe5-b68`)

### 54. Goal-position `:{` (and its dot SIBLING) yields a silent `unknown` row

`(= ?y xs:{a})` flips the baseline's loud `= expects 2 arguments, got 3` into a
silent `@[{:y unknown}] : _` at 0 errors. ⚠ The CLASS is PRE-EXISTING — the dot
sibling `(= ?y xs.a)` yields the identical unknown row at the same baseline — so
this is the DEFERRED 51/52 neighbourhood (selection sentinels reaching relational
paths), not a mint defect. Zero corpus sites. Silent-wrong-answer shaped, so it
must not sit past the 51/52 chip (`task_4c00d3f0`); whoever lands that fix should
take this reproducer with them.

### 55-original. In-block `:{` is newly ADMITTED but refused with a MISLEADING diagnostic

`rows{a:{p q}}` (narrowing a map FIELD inside a select block) now parses — the
baseline refused at parse — and typing refuses per-command with a message that
pretty-prints the nonexistent spelling `rows{a:.{p q}}` (the spurious-dot display
defect, P4d-0 slice 5's item) and describes vector-ordinal semantics where the
user narrowed a map field. A refusal, not an acceptance, and per-command — but it
is the FIRST adjacent spelling users will try, and it is unpinned. Home: the
P4d-0 slice-5 display fix plus a message that names the map-field case.


### 57. ⬜ `tier-union-witness` flattens STRUCTURALLY — a Map behind a type-alias union is not witnessed (D4.P4d slice 3 verify)

`select-union-lift` and `tier-union-witness` both call `flatten-union`, which
matches `expr-union` STRUCTURALLY without `whnf`. A component that only *whnfs
into* a union — `def N : Type := <[Map Keyword Int] | Nil>` — therefore survives
in the component list unflattened.

**The GATE half is already handled**: `select-bcast-inner-apply` tests
`expr-union?` on each (whnf'd) component and recurses into `select-union-lift`,
so an alias-nested union is gated correctly.

**The TIER half is NOT**: `tier-union-witness` does `(map whnf (flatten-union t))`
and scans one level only, so a Map buried one union-level down is not found, the
tier stays permissive, and a runtime miss is QUIET — the DEFERRED-43 signature,
one indirection over. Measured by the slice-3 verify:

```
def MM : Type := <[Map Keyword Int] | Nil>
def both : [PVec <MM | Nil>] := @[m1]
both:zzz     →  <error> : [PVec Int]        ;; ZERO errors
;; the same union written FLAT panics correctly
```

NOT a slice-3 regression (pre-slice there was no witness at all). Corpus count of
`: Type :=` in `lib/` + `examples/` is **0**, so nothing shipped is affected.
**Fix shape**: a whnf-first recursive flatten, used at both sites.
⚠ `build-union-type` (`union-types.rkt`) has the same non-recursive
`append-map flatten-union` — wider and pre-existing; scope that separately.

### 58. ⬜ RULED, implementation owed — an OPEN ROW does not discharge broadcast's "every component must offer" (D4.P4d; re-filed 2026-08-08 after co-design)

**⚠ RE-SCOPED IN PLACE. This was filed as "a THIRD admission channel through the
UNION GATE" — that aimed at the wrong level, and the controls prove it.** The
union gate admits nothing special; it faithfully propagates what an open-row
projection does everywhere. Measured at `da555602`:

```
def d := {}                          ;; { | _}
d.a          → <error> : ?meta       ;; NO union, NO broadcast
def dyns := @[{} {}]
dyns:a       → <error> : [PVec ?meta] ;; NO union
```

**THE QUESTION IS ANSWERED — by a polarity ruling we already hold, not by a new
decision.** `typing-core`'s own comment, twelve lines above the arm:

> ⚠ Broadcast is the OTHER polarity (all-must-offer, the 2b split's Galois
> adjoint) and must NOT reuse this arm — see D4 §3's 2b polarity ruling: never
> "unify" them.

An open row **may** offer the key. That satisfies single-get's OPTIMISTIC
polarity and **fails** broadcast's ALL-MUST-OFFER polarity. So "may be present in
the remainder" does **NOT** discharge "every component must offer", and the
sort-dependence is a symptom rather than the defect:

```
sl:a     → <error> : [PVec Int | ?meta]   0 errors        ← must REFUSE
sl:{a}   → refuses, already, with a good message          ← the model to match
```

`sl:{a}`'s existing text is the deliverable's model: *"field :a (branch `a`) is
not listed on the open row { | _} — seal the subject against a schema
(`the Schema subj`) or validate it against one."*

**Deliverable**: make the PATH sort agree with the BRACE sort for an open-row
component under a broadcast. ⚠ **Scoped to BROADCAST only** — single-get keeps
its D19/Q_T2 leniency by being the other polarity, so this does NOT reopen D19.
⚠ Monotone in the forbidden direction (a value becomes an error), so it needs
naming as a deliberate narrowing of a silent wrong answer, and a pin on the
single-get control proving IT did not move.

**The other half is NOT this entry** — the annotation lie
(`def port : Int := cfg.port` accepted, `<error>` wearing `Int`, into arithmetic)
is **DEFERRED 89**, and it is not a Path Selection question.

### 60. ⊘ DISSOLVED at D4.P4d slice 4c (`a31b7475`) — the subject no longer exists

The `pvec-map`-of-dots advice was DELETED, so the polarity mismatch has no
vehicle: no carrier message spells a dot-access remedy any more. ⚠ Re-open only
if a future slice reintroduces a taught spelling — DEFERRED 61's brace-template
idea would. The in-code marker this entry cited is gone with the arm.
*(original below)*

The advised spelling is a `pvec-map` of DOT accesses, and `.` over a union is
the OPTIMISTIC single-get polarity (filter-on-miss) while `:` is all-must-offer
(keys-⋂) — `select-project-field`'s union arm says so in its own comment and
forbids broadcast reuse. So over a union-typed link the advice is QUIETER than
the thing it describes. Measured at slice 4a:

```
def u : <[Map Keyword Int] | Int> := 7
def L := '[{:a u} {:a u}]
L:a:b                            ;; advises `[pvec-map [fn [m] m.a.b] xs]`
def P := [pvec-from-list L]
[pvec-map [fn [m] m.a.b] P]      ;; @[none none] : [PVec Int]   — silent
P:a:b                            ;; ERROR: keys-intersection rule — loud
```

**Pre-existing at ONE step** (base advised `m.a`, with the same polarity), so
slice 4a did not create it — but fusion EXTENDS it across the chain, where
before the truncated advice left a second, loud refusal standing.

Closing it means walking the element type along the chain to detect a union
link and poisoning the advice there — typing analysis inside a diagnostic, and
its own slice. Recorded in the code at `format-select-fail`'s `bcast-carrier`
arm.

### 61. ⬜ NOT SCHEDULED — a FEATURE question, re-homed at the P4d close to X.close triage

> ⚠ **Re-homed 2026-08-08.** It was left UNHOMED when slice 4c rewrote it, and it is
> not a gap: what remains is *"sub and caret inners have honest BRACE spellings that
> nothing offers"*, which is a **feature proposal**, and taking it requires
> reconciling with 4c's owner ruling — *"the fix is not a better second spelling; it
> is not teaching one."* So it is not P4d work and should not sit in a phase queue
> pretending to be. Decide it at **X.close DEFERRED triage**, as a yes/no on whether
> the brace spellings are worth advertising at all.
>
> ⚠ Its own body carries a warning worth keeping: **two independent auditors got its
> item 2 wrong**, both reasoning from "the advice machinery is deleted" to "no
> message advises anything" — conflating 4a's *taught-spelling* advice with 4c's
> *conversion* remedy. Probe before repeating either claim.

⚠ The original text below is OBE: it described slice 4a's "poisoning rule",
which was deleted at 4c along with the rest of the advice machinery. Two
corrections to it, both MEASURED at HEAD:

- **Item 1 is moot.** No sort advises a dot spelling now, so nothing is
  "withdrawn by poisoning".
- **⚠ Item 2's premise is FALSE at HEAD, and two independent auditors got this
  wrong.** Block sort is NOT silent: `R{items:aa}` over a List field emits the
  full conversion remedy ("convert it with `[pvec-from-list xs]`"). Both audits
  reasoned from "the advice machinery is deleted" to "no message advises
  anything", conflating 4a's *taught-spelling* advice with 4c's *conversion*
  remedy. Probe before repeating either claim.

**What actually remains**: sub and caret inners have honest BRACE spellings
(`m{a b}`, `m{name^alias}`, both verified equivalent to their `:`-forms) that
nothing offers. ⚠ Taking this requires reconciling with 4c's owner ruling —
*"the fix is not a better second spelling; it is not teaching one"* — so it is a
FEATURE question (should any remedy teach a spelling?), not a gap to close.
*(original below)*

Two conservative-direction losses from slice 4a's poisoning rule, both
suppression-only (never a wrong spelling), neither pinned:

1. **A non-ω following link poisons the whole chain.** `L:a.b`, `M:a:0` and
   `R{items:a.b}` advised `m.a` at base and advise nothing now. The poisoning
   rule targets ω chains, where a partial path answers a different question; a
   following `.b` or `:0` applies to the ω's RESULT, so `m.a` remained a correct
   spelling of the step that actually failed.
2. **BLOCK sort now advises nothing at all.** Correct as far as it goes — the
   dot-path is not the block spelling, because block ω ASSEMBLES (measured:
   `RP{items:aa}` ≡ `[pvec-map [fn [m] m{aa}] P]`, while `m.aa` projects and
   differs). But the honest advice EXISTS: it is the BRACE spelling `m{aa}`.
   Advising it would restore the guidance the suppression removed, and is the
   same "different delimiter" move already owed for sub and caret inners.

Both are monotone (advice can be added back at zero cost); neither can produce a
wrong spelling today. Worth taking together, since (2) and the sub/caret cases
share one mechanism: a brace-spelling advice template.

### 62. ⬜ The ω subject resolver refuses more than it must — the precise gate is a presence question (D4.P4d slice 4b)

`bcast-resolve-subject` admits a schema only when it is `:closed` AND carries no
`:default`. Both conjuncts are sound but blunt; each was a measured width lie in
an earlier cut of the slice, in OPPOSITE directions:

- **extras** (the `:closed` conjunct) — an open schema's runtime value can carry
  keys the declared row does not, and broadcast is the first consumer that
  ENUMERATES the row. Measured: a 3-key open `Region` gave
  `{:ap "a", :eu "e", :us "u"} : {:eu String :us String}`.
- **absence** (the `:default` conjunct) — `schema->row` marks every field
  `'present` while its own docstring says the fill "happens at the seal
  boundary"; a `spec f -> S` RETURN has no fill, so a defaulted field can be
  `'present` in the row and absent at runtime. Measured: `c:h` gave
  `{:a "q"} : {:a String :b String}` and `broad.b` a silent `<error>`.

The precise gate for BOTH is a presence-faithful row: mint an open schema's row
with a dyn TAIL, and a defaulted field with the presence the seal actually
guarantees rather than an unconditional `'present`. That means a
broadcast-specific `schema->row` variant (the shared one is load-bearing for
`.` and `{}`, which read named fields and never notice), so it was filed rather
than improvised inside a diagnostics slice. Monotone: both refusals can become
meanings with no user-visible break.

### 63. ⬜ INLINE nested schemas are always OPEN, so the slice-4b deliverable misses the idiomatic spelling (D4.P4d slice 4b re-verify)

Auto-generated sub-schemas are registered open — `macros.rkt`'s sub-schema
construction passes the closed flag as `#f` unconditionally, so a parent's
`:closed` never propagates. Consequence, measured:

```
schema Region :closed
  :us
    :a
      :h String
```
`plain.us:h` → `{:a "x", :b "y"} : {:a String :b String}`, while the
byte-identical `rg.us:h` refuses. Two problems: the refusal is CORRECT (the
inline sub genuinely accepts an undeclared key — admitting it would reproduce
62's extras direction exactly), but it names a compiler-generated identifier
(`Region__us`) the user never wrote, and its advice is nonsense for that
subject. So slice 4b's headline — "a schema-typed subject is the row it
denotes" — holds only for top-level NAMED closed schemas. Fixing the
propagation is the real answer; the leaked generated name is slice-4c material.

> ⚠ **RE-HOMED at the P4d close (2026-08-08).** Slice 4c has LANDED and did not take
> the leaked-generated-name half, so that half was orphaned — homed on a slice that
> no longer exists to receive it. Both halves now belong to **P4e** (the next phase
> that touches this surface) or to X.close triage if P4e does not reach it. The
> substance is unchanged; only the home moved.

### 65. ⬜ `lookup-schema-by-name` matches on the SHORT name, so an unrelated type can resolve to a schema (pre-existing; surfaced at D4.P4d slice 4b)

`register-schema!` keys on the short name and `lookup-schema-by-name` falls back
to it, so any type whose short name matches any schema resolves to that schema.
With `schema Bar :closed` + `data Bar := mk1 | mk2`, `v := mk1` then `v:h` yields
`{:a String :b String}` at 0 errors — a row fabricated for a nullary constructor
with no fields.

**NOT a regression**: the dot-only, broadcast-free version reaches the same end
state at base, including a WHOLE-FILE ABORT (`foreign: Cannot marshal to
string … #(struct:expr-select …)`, empty output — `pipeline.md`'s raise class).
But broadcast widens the fabrication from one field to the whole row, which is
62's extras argument verbatim, and it is a third instance of the class the two
slice-4b gates were written for. The fix is name resolution, not selection.



---

## Renumbered on merge-back — `wizardly-mendel-2fd502` → `main` (2026-08-08)

The DEFERRED 51/52 arc ran out-of-band on its own branch and numbered its entries
independently, so **nine** numbers denoted different items on the two sides.
`main`'s numbering is the trunk's and had already been made self-consistent
(its own 53 collision was resolved 53 → 56), so the BRANCH's entries moved.

| was (branch) | now | entry |
|---|---|---|
| 53 | **66** | a compound term in a `\|\|` fact row was SPLAYED into fabricated rows |
| 54 | **67** | the four global-constraint goal forms are UNPLUMBED |
| 55 | **68** | the FLAT / paren-wrapped clause spelling mis-parses under multiple rewrites |
| 56 | **69** | `x[i]` on a deeper CONTINUATION line becomes a bogus goal |
| 57 | **70** | the right-peel over-reached (a compound `let` body stole the rel RHS's srclocs) |
| 58 | **71** | THE DEPTH WALL — the origin index |
| 59 | **72** | MEMBER 4 — `def name := rel …` mis-grouped a clause containing a rewrite |
| 60 | **73** | an anonymous `rel` carrying `\|\|` fact rows returns `@[]` typed `Goal` |
| 61 | **74** | the POL.9b def-seam gap |

⚠ **Commit messages are immutable and still say the OLD numbers.** Every moved
entry carries its own `was N → now M` note so those references stay traceable;
the code comments and test names were updated in the merge-back commit.
⚠ **51 and 52 are NOT renumbered** — they are the SAME items on both sides, and
this branch's ✅ FIXED versions supersede `main`'s 🔀 SPUN OUT stubs (spliced in
above, not appended).


### 67. The four global-constraint goal forms are parser-reachable but UNPLUMBED (`zonk` has no arm) — found 2026-08-05

> ⚠ **Renumbered 54 → 67 at the merge-back** (2026-08-08). It was **54** on branch `wizardly-mendel-2fd502`, where it collided with a DIFFERENT `main` entry of the same number. Commit messages and any code comment saying "DEFERRED 54" from that branch mean THIS entry.

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

### 68. The FLAT / paren-wrapped clause spelling mis-parses under multiple rewrites — pre-existing, silent (found 2026-08-05 by adversarial verify)

> ⚠ **Renumbered 55 → 68 at the merge-back** (2026-08-08). It was **55** on branch `wizardly-mendel-2fd502`, where it collided with a DIFFERENT `main` entry of the same number. Commit messages and any code comment saying "DEFERRED 55" from that branch mean THIS entry.

```
(defr q [?a ?b ?c ?zz]
  &> g a.p zz
     h b zz.p)
```
→ parses as `(goal g 1) (goal zz 3)` — a goal named after a LOGIC VARIABLE — with
**zero errors**. A randomized 70-case sweep of that spelling diverged from the
rewrite-free control in **27 cases**, most silently.

**Not a 51(c) regression** — measured: the same spelling mis-parsed BEFORE 51(c)
too. Its safety premise never held there: `parse-clause-content`'s degradation
marker is an impossible **column 0**, but a top-level `(defr …)` sits at **column
1**, so the old whole-form stamp produced a non-zero column, the guard passed,
and it silently mis-parsed. A 160-case A/B found **zero** cases where the old
behaviour was correct and the new one wrong.

**Why it is nonetheless 51(c)'s to name**: 51(c)'s `rebuild-preserving-locs`
aligns a changed middle by positional RIGHT-alignment, which is only valid after
the LAST length-changing rewrite. With two such rewrites separated by other
elements, everything between pairs with an original `delta` positions to its
right — and in this spelling a list's elements SPAN LINES, so the mispaired zone
crosses a line boundary and elements get the wrong LINE, which is what the layout
grammar reads. In the ordinary indent-grouped WS spelling this is unreachable
(70/70, 90-case and 65-case batteries all clean): there, line-0 elements are flat
and every later line is exactly ONE grouped element, so a group can never change
the enclosing list's length and the mispaired zone stays inside line 0, where only
columns are corrupted and `goal-col` comes from the prefix.

**Mitigated, not fixed**: the peel now only pairs elements that are datum-equal
or BOTH lists, so an atom can no longer pair with a different atom. That shrinks
the unsound surface without making the spelling correct.

**Real fix**: a proper diff (or an origin marker from the reader) instead of
prefix/suffix + right-alignment. Related to DEFERRED 66's residual 2, which wants
the same reader-side marker.

**Reachable-through spellings (grows as found)**: the flat/paren-wrapped clause
spelling (original finding); the **def paren-RHS spelling** (`def x := (rel …)`
with rewrites in BOTH goal lines — solves SILENTLY when a relation of the merged
arity exists; def-arm verify, 2026-08-05, byte-identical pre-51(c)); and the
**`let` binding-RHS leg** degrades by a stronger mechanism (total-reshape
desugar — no alignment can recover it; see the 51(c) entry).

### 69. `x[i]` on a deeper CONTINUATION line becomes a bogus goal — pre-existing, and 51(c) made its diagnostic worse (found 2026-08-05)

> ⚠ **Renumbered 56 → 69 at the merge-back** (2026-08-08). It was **56** on branch `wizardly-mendel-2fd502`, where it collided with a DIFFERENT `main` entry of the same number. Commit messages and any code comment saying "DEFERRED 56" from that branch mean THIS entry.

```
defr q [?f]
  &> fruit-color f
       cols[0]        ;; control: "red"  → registers fine
```
→ `ERROR: defr q: Could not infer type — the relation was NOT registered`.

**Cause**: `x[i]` folds to `(get x i)` — the ONLY one of the four rewrite
families whose output is **not `$`-headed** (`.`/`:` → `$select-path`, `'[…]` →
`$list-literal-parse`). `pol8-goal-pair?` therefore classifies it as a GOAL
GROUP, and `parse-clause-content` tests that branch before any column
classification, so the continuation becomes a bogus sibling goal instead of
extending the previous goal. Test-pinned as a known limit alongside the three
families that DO work there.

**Pre-existing** — an ordinary `[inc z]` on a continuation line behaves
identically before and after 51(c). What 51(c) changed is the DIAGNOSTIC: the old
path returned the actionable *"parenthesize each goal in this clause"*; the new
one returns an unrelated type error. That regression in guidance is real even
though the parse behaviour is not.

**Fix direction**: `pol8-goal-pair?` decides "is this a goal group?" by "a pair
not headed by a `$` sentinel", which is the same polarity trap DEFERRED 66 hit —
a rewrite whose output happens not to be `$`-headed silently changes meaning. The
durable answer is the reader-side origin marker (see 53 residual 2), not another
member.

### 73. ⬜ An anonymous `rel` carrying `||` FACT ROWS returns `@[]` and types its column `Goal` (found 2026-08-07, silent)

> ⚠ **Renumbered 60 → 73 at the merge-back** (2026-08-08). It was **60** on branch `wizardly-mendel-2fd502`, where it collided with a DIFFERENT `main` entry of the same number. Commit messages and any code comment saying "DEFERRED 60" from that branch mean THIS entry.

Separate from member 4 and from the `def` seam — measured on the bare top-level
spelling, which has neither:

```
(rel [?q]
  || [some 1]
     [some 2]
     "z")
```
→ `@[] : [PVec {:q Goal}]`, **0 errors**. The `defr` equivalent (`defr rr [?q]`
with the same block, then `(rr x)`) returns **four** rows:
`@[{:x [?some 1]} {:x "z"} {:x unknown} {:x 2}]`.

So `||` fact rows appear not to be consumed as facts inside an anonymous `rel`
value: the column types as `Goal` rather than as the row values' type, and the
solution set is empty. Silent in both directions — no error on either side.

⚠ Note the `defr` side is not a clean oracle either: its 4 rows include the known
DEFERRED 66 splay residual (`[some 2]` on a continuation line becomes a fabricated
row, and `{:x unknown}` appears). So "make them agree" is not obviously the right
target — what each SHOULD produce wants a ruling before either is changed.

Found while scoping member 4; not investigated further.

### 75. ⬜ Q_U19 route 2 — `xs:{name}^alias` is UNGUIDED, and it needs a GROUPER-SIDE adjacency mint (D4.P4d slice 4d; attempted and REVERTED)

`xs:{name}^alias` and `xs:{name}^` report a bare `Unbound variable` — the caret
is not part of the selection, it is a stray token. Measured at `2fd6b68e`:
`xs:{name}^alias` lexes as `xs` `:` `{` `name` `}` `^` `alias`, i.e. the caret and
its alias are BARE SIBLINGS AFTER the `}`, so the form falls through to
application and the caret is a free variable.

**Attempted at slice 4d as a datum-level fold arm in `macros.rkt`
(`bcast-rekey-sibling?` = a `$bcast-step` followed by `'^`), and REVERTED [owner
2026-08-08: "ship route 1"]. The revert is the finding:**

⚠⚠ **IT BROKE MONOTONICITY, and the adversarial verify caught it over a GREEN
battery, five green acceptance files and a passing two-direction mutation test.**
`^` is a **bindable name** — `def ^ := 7` → `^ : Int defined.`, and
`def use := [+ ^ 1]` works. So a `$bcast-step` followed by `^` is not necessarily
a re-key mistake; it can be an ordinary variable reference:

```
def xs := @[{:name "a"} {:name "b"}]
def ^ := 7
defn snd2 [a b] b
def a4 := [snd2 xs:name   ^]     ;; HEAD: `a4 : _ defined.`  → arm made it an ERROR
def a5 := [snd2 xs:{name} ^]     ;; HEAD: `a5 : _ defined.`  → arm made it an ERROR
```

⚠ **There is NO PRECEDENT for this**, contrary to the first mitigation offered:
`xs.0 ^` and `xs[0] ^` do already refuse at HEAD, but those are ORDINAL shapes
hitting a different arm. The NAMED analogue `[snd2 m.name ^]` works on both
trees. ⚠ Also note **two of three skeptics wrongly concluded "no monotonicity
break"** — both tested `defn ^` (head position, which genuinely fails) and never
`def ^ :=`. The adjudicator and the main thread each reproduced it independently.

**WHY A FOLD ARM CANNOT WORK, and what would**: adjacency is destroyed below
grouping (the documented Q8.5 invariant 2), and `xs:{name}^` — a spelling the
ruling covers — is DATUM-IDENTICAL to `[f xs:{name} ^]`. The discriminator exists
only at the grouper: `adjacent-to-base?` (`parse-reader.rkt`), which is exactly
what `bcast-brace-trigger?` uses for the `:{` mint. So this is a
**reader-adjacency mint, structurally the same shape as P4d-0's `:{` work** — and
P4d-0 landed that ALONE, on the argument that mixing it makes the A/B
un-attributable. Same argument applies here.

Blast radius of the unguided state is small: bare `^` appears in the corpus in
**7 lines, all comments**, zero live code.

**Fix shape**: a `^`-adjacency trigger at the grouping seat minting a sentinel
the parser keys on, then route it to `bcast-rekey-message` (already defined,
`parser.rkt`, shipped for route 1). Lands with **76**, which shares the root cause.

### 76. ⬜ Q_U19 route 3 — `xs:0^alias` is UNGUIDED, and the colon-band gate cannot tell the PATH colon from the ANNOTATION colon (D4.P4d slice 4d; attempted and REVERTED)

`xs:0^alias` reports `Unbound variable`, blaming the COLON. Cause, measured: the
lexeme falls BETWEEN two recognizers — `recognize-keyword` requires
`char-alphabetic?` after the colon (so a digit is not a keyword), and
`recognize-colon-annotation`'s digit arm returns `#f` when the digit run is
followed by an ident-continue char, and `^` IS one (`ident-continue?` admits it).
So `:0^alias` mints NO sentinel and shatters to `xs |:| 0 ^ alias`.

**Owner ruling stands and is NOT re-opened [2026-08-08]: it takes Q_T4a's
`ordinal-rekey-message`, not the Q_U19 broadcast sibling** — `users:0` is itself a
legal ω step (Q_U16b), so the mistake is `^` after an ORDINAL, which has no key,
and the dot band already answers that exact mistake with that exact string.

**Attempted at slice 4d by widening `ordinal-rekey-shatter?` and its fold arm from
`(eq? (car xs) '|.|)` to `(memq (car xs) '(|.| |:|))`, and REVERTED. Two defects,
both found by the adversarial verify:**

1. ⚠ **`|.|` has ONE role; `|:|` has TWO** — path colon *and* type-annotation
   colon — so the widened arm EATS BINDER NAMES:
   `def z1 : 3 ^` → `def requires: (def name <type> body)` (the name `z1` was
   consumed); `[fn [x : 3 ^] x]` → payload `($retired-selection ordinal-rekey #f)`
   (the param `x` was consumed). Error→error today, so not yet a break — but the
   base-drop `(if (null? acc) acc (cdr acc))` is consuming the wrong element.
   ⚠ The main thread initially cleared this by A/B — the DOT band over-fires the
   same way at baseline (`[f 1 . 0 ^ 2]` → the ordinal message) — and that
   clearance was **too generous**: the dot band's over-fire is benign precisely
   because `.` has no second role.
2. ⚠ **It did not achieve the ruling's own goal.** The dot band is
   spacing-invariant; the colon band was not, because route 2's arm consumed
   `($bcast-step |:0|)` before the shatter could see it:
   | | HEAD | attempt |
   |---|---|---|
   | `xs:0^alias` | Unbound variable | ordinal ✅ |
   | `xs:0 ^ alias` | Unbound variable | **broadcast ❌** |
   | `xs.0^alias` · `xs.0 ^ alias` | ordinal | ordinal ✅ |
   And the pin used only the GLUED form, so it stayed green over the exact
   spelling "the two bands must agree" is about — a vacuous pin covering a real gap.

**Fix shape**: a gate that distinguishes the path colon from the annotation colon
(the grouper knows; the datum layer does not), plus an ordinal-payload deferral so
75's arm cannot shadow it. **Lands WITH 75** — one root cause: the datum layer
cannot see what both routes need. Pin BOTH bands and BOTH spacings.

---

### 77. ⬜ The broadcast axis is threaded but NOT CONSUMED in three sibling arms — and the tuple one advises a spelling that SUCCEEDS WITH THE WRONG MEANING (D4.P4d slice 4d-2)

Slice 4d-2 gave `format-select-fail` a broadcast axis (`#f` / `'elem` / `'at` /
`'union`) and consumed it in `subject-other` and `not-indexable`. **Three arms
reachable beneath the same wrappers still say "the subject" — which names the
CARRIER — and still give block/dot advice inside a `:` broadcast**:
`subject-map`, `subject-tuple`, `subject-selection`.

⚠ **The tuple case is the worst, because the advice is not an error — it is a
DIFFERENT ANSWER** (verified):

```
def ts := @[@[1 "x"] @[2 "y"]]        ;; [PVec ⟨Int String⟩]
ts:{a b}  → "… the subject is a tuple … ordinal selection is `x{N M}`,
             single-element extraction `x.N`"
ts{0 1}   → @[@[1 "x"] @[2 "y"]] : ⟨⟨Int String⟩ ⟨Int String⟩⟩   ;; the CARRIER
ts.0      → @[1 "x"] : ⟨Int String⟩                              ;; the first ELEMENT
ts:{0 1}  → what the user actually wanted, 0 errors
```

Selection: `us:{name}` advises `v.field`; the true fix is `us:name`.

The wording is PRE-EXISTING; what 4d-2 changed is that the broadcast prefix now
sits immediately before it, making the contradiction adjacent in one sentence.
The fix is mechanical — the axis is already in scope at each arm.

**Ride-along, same function (LOW, latent)**: the three wrapper arms
`string-append` the result of `format-select-fail`, which ends `[else #f]`. All
14 produced kinds are handled today so it cannot fire; when a 15th lands it
raises, and `select-block-hint`'s blanket `with-handlers` swallows the ENTIRE
hint search where a `#f` would have let the `ormap` continue to sibling
subfields. 4d-2 widened that trap from `bcast-at`/`bcast-union` to the whole
PVec/Map population. Give the wrappers a `(or … "")` or make the formatter total.

### 78. ⬜ The stale-phase census pattern STRUCTURALLY cannot find bare-token phase references (D4.P4d slice 4d-2)

Slice 4d-2 swept user-facing phase promises using
`grep -rn 'Path Selection P' racket/prologos/*.rkt` (seven sites, four files).
**That pattern cannot match a phase token that is not immediately preceded by the
words "Path Selection"**, and the verify found survivors of exactly that shape:

- `tree-parser.rkt` — `"select blocks are not supported yet (CIU T6 Path Selection lands them at P3)"`. P3 LANDED; `cfg{name}` and `cfg{server.{host}}` work today. The words are "Path Selection **lands**", so the grep misses it.
- `tree-parser.rkt` — `"let: tree spine defers to preparse (LET P2)"` — the LET track is COMPLETE.
- `tree-parser.rkt` ×3 — `"deferred to Phase 3e"`.

None was reachable from surface syntax in ~12 probed shapes, and each site's own
comment says the arm exists for a future consumer — so they are **latent, not
live**. Fix with a broader census (`P[0-9]`, `P4[a-e]`, "lands", "arrives",
"until then", "not supported yet", "deferred to") over the WHOLE tree including
`lib/`, `tools/`, `tests/`.

⚠ This is the design's own-enumeration-under-counts pattern at its 10th arc, and
this time it under-counted a census I had just widened after being told it was
under-counted. **Grep patterns are enumerations too.**

### 79. ⬜ PRE-EXISTING — the `let` fused-annotation message states TWO falsehoods and its remedy omits `:=`

Found by the slice-4d-2 verify; **not caused by that slice** (the text is in HEAD).
`macros.rkt`'s fused-annotation arm emits:

> `let: a fused type annotation here was read as a broadcast step — write it spaced (`let name : T value`) to work around it. (`let` is missing from the reader post-pass binder table in parse-reader.rkt; the fused spelling should work here.)`

Both parenthetical claims are false, and so is the remedy as printed:
1. `parse-reader.rkt`'s `binder-region-heads` is `'(def let)` — **`let` IS in the table.**
2. The printed remedy fails verbatim: `let z : Int 5` → `let: unrecognized format`. Only `let z : Int := 5` works — **`:=` is REQUIRED and the message omits it.**
3. For the only input that REACHES this arm (a chained annotation, `let y:Int:Bool 4`), the spaced counterpart `let q : Int : Bool := 6` yields `Unbound variable` — **no working remedy exists at all.**

⚠ A `parser.rkt` comment asserts this sentence "WAS DELETED AT G2 BECAUSE IT
STATED A FALSEHOOD". It was not — it is live, verbatim. Fix the message, or
delete the claim that it is gone.

### 80. ⬜ The `bcast-step` EXPRESSION-position arm may be dead, and now advertises an unbuilt feature that shipped (D4.P4d slice 4d-2)

`retired-selection-error`'s `[(bcast-step)]` arm. Its header says "Both are
reachable today" — written PRE-P4c-3 and never re-verified. Neither the slice-4d
mini-audit, nor three skeptics, nor the adjudicator, nor the main thread could
reach it from surface syntax (`:name` bare, `def a := :name`, `[map xs :name]`,
`[xs :name]`, `def f := xs:` all route elsewhere); one facet reached it only via a
hand-written `[$bcast-step]` sentinel. Its message was reworded phase-free at
4d-2, but if the arm is dead the right move is deletion — it is the same shape as
the retired `bcast-not-yet`. **Needs a constructed-datum probe, not a grep.**
(The binder twin below it IS reachable and is unaffected.)

### 81. ✅ **DISCHARGED `160ad2f6`** (SW-25: the runner names every per-file count drop) — The suite's `total_tests` can silently UNDER-REPORT while `all_pass` stays true

Measured at D4.P4d slice 4d-2. Two consecutive `--all` runs on the SAME code gave
**10061** and **10066**; the delta was entirely `test-properties.rkt`, recorded as
**8** in one run and **13** in the other. Standalone it is **13, deterministic,
three runs**, and the file contains no randomness (`grep -cE 'random|quickcheck|sample|shrink'` → 0). Both suite runs reported `all_pass: true` with zero
`FAILED:` lines.

So a batch worker can under-report a file's test count without failing anything —
which means **`total_tests` is not a reliable regression signal on its own**, and
a real loss of tests would look exactly like this. It is a cousin of the
documented "a killed runner still prints all pass" hazard in
`.claude/rules/testing.md`, but with no `user break` and no truncated progress
marker to give it away — the only tell was that the per-file delta did not match
the battery delta.

**Practical rule until fixed**: when the suite total moves in a direction the
battery delta does not explain, diff per-file counts from `timings.jsonl`
(`results[].tests`) before believing either figure.

**Status 2026-10-13 — discharged (SW-25, `160ad2f6`).** The instance is explained: `test-properties.rkt` required
`test-generators.rkt`, a TEST file, so its 5 tests were counted into `test-properties` only when the worker had not
instantiated that module yet — DEFERRED 161's mechanism, fixed by `8014caef` and guarded by `test-suite-plan.rkt`
("no test file requires another test file"); recorded counts read 13 through `58241c0c`, 8 from `61b24b02` on. The
hazard stays general, so the runner now does the per-file diff itself: after the summary it prints
`COUNT DROP: <file> ran N tests; at its last recorded pass (<commit>) it ran M` for every passing file below its count
in the newest valid record where it passed (suite-plan.rkt `prior-test-counts` / `count-drops`, newest 30 records,
73 ms worst case on main's 202 MB history). Exit code unchanged: deleting a test is legitimate. Verified end to end
(a test case commented out → the line, naming `e4e9e451`'s 8) and by mutation. It already paid for itself: it is
what showed that SW-27's 14 rewritten checks all still run (no drop on the four migrated files).

---

### 82. ⬜ The union meta arm still DROPS a DECIDED non-offerer — the polarity lie, narrowed but not closed (D4.P4d slice 5)

Slice 5 stopped the meta arm LAUNDERING the D23 escape guard (it now carries the
unsolved metas into the result, so `def q := sl:a:b` is refused exactly as
`def q := sl:a` is). **What it did not fix is the polarity.**

When `offering` contains an unsolved meta, the arm lands in
`select-bcast-inner-apply/non-union`, which with a UNION subject reaches
`select-project-field`'s union arm — the SINGLE-GET optimistic filter. That arm's
own comment forbids this reuse in terms:

> ⚠ Broadcast is the OTHER polarity (all-must-offer, the 2b split's Galois
> adjoint) and must NOT reuse this arm — see D4 §3's 2b polarity ruling: never
> "unify" them.

Its fold drops any component that is neither Map nor Record (`[else acc]`). That
is correct for the *unsolved meta* (we genuinely do not know), and WRONG for a
component already DECIDED not to offer the key: such a component can never become
an offerer, so dropping it is not licensed by the arm's anti-monotonicity
rationale. Gating on the DECIDED components is monotone-safe.

**What is owed**: a landing that refuses on the decided non-offerers while
deferring only on the metas — i.e. run the keys-⋂ gate over
`(filter (not expr-meta?) offering)` and merge the metas into the result. That is
a design decision about the 2b polarity, not a mechanical fix, which is why slice
5 narrowed rather than closed it. Ties to **58** (the dyn channel) — same arm,
same question of what "may be present" discharges.

### 83. ⬜ `format-closed-row-miss` raises on a UNION row, and a blanket handler eats it — the bare "Could not infer type" (D4.P4d slice 5)

`select-project-field`'s union arm mints `'miss-closed` with a **union** in the
`row` slot. `format-select-fail`'s `miss-closed` arm calls
`format-closed-row-miss`, whose first act is `(expr-Record-fields rec)` — a
contract violation on a union. `select-block-hint` wraps the whole hint search in
`(with-handlers ([(lambda (_) #t) (lambda (_) #f)]) …)`, so the raise is
SWALLOWED, the hint returns `#f`, and the user gets a bare
`Could not infer type` with no guidance.

⚠ **The codebase already knows this trap and documented it** — it is the stated
reason `bcast-union` deliberately does NOT nest through `miss-closed`
(`typing-errors.rkt`, the `bcast-union` arm: *"a contract violation on a union
that `select-block-hint`'s blanket handler SWALLOWS, which is exactly why the
pre-slice all-miss refusal printed a bare 'Could not infer type' with no guidance
at all"*). Slice 3 routed AROUND the hole; slice 5's meta landing routes the new
population straight into it.

Measured contrast in one file:
```
xs:zzz   → broadcast `:zzz` fails on every element — … available fields: :a   ✅ Record row
sl:a:0   → … `Int | ?meta` has no positions                                   ✅ ordinal sibling
sl:a:b   → Could not infer type                                               ❌ union row
```
Only the SYMBOL inner falls in the hole; the ordinal sibling one character away
is fine, because it mints a different kind.

**Fix**, both local: guard `format-closed-row-miss` on `expr-Record?` with a
union-aware fallback, **or** have `select-project-field`'s union arm mint a
union-aware kind instead of `miss-closed`. ⚠ Also worth fixing the blanket
handler itself — a `with-handlers` that swallows every exception is why a
contract violation reads as a missing diagnostic.

---

### 84. ⬜ ONE absent element still answers for the WHOLE node — the split's named residual (D4.P4d slice 6)

Slice 6 split absence from key-miss at the TIER layer: `champ-of` now consults only
the BLOCK tier, so an absent element stays quiet while a genuine key miss goes
LOUD. **What it does not touch is the whole-node abort.**

`select-reduce` has a single `let/ec return`, and both permissive exits escape
through it — `champ-of`'s `[else] → none` and `project`'s `[else] → <error>`. So
one element's absence abandons the entire selection, and the answer is decided by
whichever element folds FIRST:

```
def A : [PVec <Nil | MKI>] := @[m2 nn]   A:a  →  LOUD (the miss folds first)
def B : [PVec <Nil | MKI>] := @[nn m2]   B:a  →  none, 0 errors   ;; SAME multiset
```

Row carriers are worse, because the order is CHAMP HASH ORDER, not source order —
three structurally identical records differing only in FIELD NAMES gave `none`,
loud, loud. And the collapse discards data: `{:f nn :g m3}` with `m3 = {:y 7}`
returns `none`, throwing away the real `7`.

⚠ Two further consequences, both measured: the result is a **scalar at a container
type** (`none : {:f Int :g Int}`, `none : [PVec Int]`) — a type lie the printed
type does not admit; and `nil-safe-get` "composing with broadcast" holds only in
the all-hit case (a single absent element collapses the whole vector rather than
yielding `@[1 none 3]`). Both PRE-DATE slice 6 and are unchanged by it.

**What is owed is a ruling**: is absence a PER-ELEMENT answer (yielding a
container with a marker in the absent slot) or a NODE answer (today)? The Q_U7
whole-node-abort rider ratified an **error** aborting the node so no panic is
buried — it never covered delivering a **VALUE** through that channel, which is
what makes the type lie possible. Note DEFERRED 48's ruling constrains per-TIER
abort granularity and does NOT block a per-element absence answer.

⚠ **Pin obligation either way**: nothing anywhere pins that two orderings of the
same node agree. Whichever way this is ruled, that pin is the deliverable.


### 85. ⬜ `[p32-sqrt 1e10]` is a STUCK TERM with ZERO errors — an exponent literal is `Int`, but passes a `Posit32` argument check (found 2026-08-08)

```
ns q
[p32-sqrt 1e10]
```
→ `[p32-sqrt 10000000000] : Posit32`, **0 errors**. The term is echoed back
UNREDUCED and typed `Posit32`; nothing anywhere says it did not compute.

**Mechanism (inferred, one step verified)**: per Numerics N6b the literal's
default type is keyed on NOTATION ORIGIN — decimal → `Posit32`, fraction → `Rat`,
**exponent → `Int`/`Posit32`**. `1e10` arrives as an `Int`, `p32-sqrt`'s argument
check nonetheless admits it and reports the result type as `Posit32`, and then
`reduction.rkt`'s arm `[(expr-p32-sqrt (expr-posit32 a)) …]` does not match an
`expr-int` payload, so the node is stuck. Verified: the decimal spellings all
reduce (`[p32-sqrt 16.0]` → `4.0`, `[p32-sqrt 0.0001]` → `0.01`), and
`[p32-sqrt [p32-from-int 9]]` → `3.0`, so the defect is specific to the
EXPONENT-notation literal reaching a posit primitive.

⚠ **Silent in both directions** — no error on either side, and a stuck term
pretty-prints as a plausible value. This is the class the arc has been paying for
all week: the gate that would catch it (an arity/type error) never fires.

**Not investigated**: whether the same shape hits the other widths
(`p8`/`p16`/`p64`, `f32`/`f64`) or other posit primitives (`p32*`, `p32-abs`, …).
The argument check is presumably shared, so a census is the first move.

### 86. ⬜ A TYPE MISMATCH in a float/posit primitive's argument reports "Multiplicity violation" (found 2026-08-08)

```
ns q
[f64-sqrt 2.0]
```
→ `ERROR: Multiplicity violation`. The actual fault is a plain type mismatch:
`2.0` is a `Posit32` (decimal literals default there) and `f64-sqrt` wants a
`Float64`. The correct spelling `[f64-sqrt (the Float64 2.0)]` →
`1.4142135623730951f`, 0 errors.

**The same LYING-DIAGNOSTIC class as DEFERRED 74, at a DIFFERENT site.** 74 fixed
the `def` SEAM — an unannotated `def` whose body type was not ground reached QTT,
which had nothing to check against and reported its generic `tu-error`. This one
is `checkQ` failing on an ARGUMENT, so 74's gate does not cover it and it is
still live. Per `.claude/rules/pipeline.md` § "infer / inferQ Are Twins", a
"Multiplicity violation" naming a subsystem that is working perfectly is the
signature to chase; here QTT is again innocent.

**Worth deciding as one question with 74's residual**: whether `tu-error`'s
generic reporter should ever be allowed to surface as "Multiplicity violation"
at all, or whether every path into it should have to say what it was actually
checking. 74 fixed one caller; this shows callers are the wrong granularity.

**Found while** answering how to implement `sqrt` (2026-08-08). Both 85 and 86
were surfaced by probing the existing primitives, not by any gate.


### 87. ⬜ TASK — there is no generic `sqrt` in the stdlib; add a `Sqrt` trait over the primitives that already exist (2026-08-08)

**Not a defect — an absent feature, and the one users hit first.** `sqrt 32.0`
reports `Unbound variable`, and there is no library to require: nothing defines
`sqrt` in any `.prologos` library and it is not in the prelude's auto-import list
(`namespace.rkt`). Verified by grep and by running it. The working spellings are
the WIDTH-SPECIFIC parser keywords — `p8/p16/p32/p64-sqrt` and `f32/f64-sqrt` —
which a user has no way to guess.

**Everything underneath already works.** The primitives are fully plumbed
(parser keyword → `surf-*` → `expr-*` → `reduction.rkt`) and backed by real
implementations: `float64-sqrt` = `flsqrt` (`float-impl.rkt:40`), `posit32-sqrt`
= `posit-sqrt 32` (`posit-impl.rkt:508`). So this task adds a NAME and a
dispatch, not an algorithm.

**The shape, verified end-to-end at `a2d6e13e` (0 errors, all four dispatching):**

```
trait Sqrt {A}
  sqrt : A -> A

impl Sqrt Posit32   defn sqrt [x : Posit32] <Posit32>  p32-sqrt x
impl Sqrt Posit64   defn sqrt [x : Posit64] <Posit64>  p64-sqrt x
impl Sqrt Float64   defn sqrt [x : Float64] <Float64>  f64-sqrt x
impl Sqrt Int       defn sqrt [x : Int]     <Int>      isqrt x
```

measured: `[sqrt 2.0]` → `1.41421356 : Posit32` · `[sqrt (the Float64 2.0)]` →
`1.4142135623730951f` · `[sqrt [p64-from-int 2]]` → `1.4142135623730952p` ·
`[sqrt -1.0]` → `NaR` (total, no crash).

**`Int` needs an implementation — there is no integer sqrt primitive.** Newton /
Heron, pure Prologos, verified exact `floor(√n)` for 0, 1, 2, 15, 16, 17, 999999,
1000000:

```
spec isqrt-go Int Int -> Int
defn isqrt-go [x g]
  let g2 := [int/ [int+ g [int/ x g]] 2]
    match [int-lt g2 g]
      | true  -> [isqrt-go x g2]
      | false -> g

spec isqrt Int -> Int
defn isqrt [n]
  match [int-le n 0]
    | true  -> 0
    | false -> [isqrt-go n n]
```
⚠ The `n <= 0` guard is load-bearing — it is what stops `int/ x g` dividing by
zero on the first step.

**⭐ THE OPEN DESIGN QUESTION, and it should be ruled before this is written:
what does `sqrt` MEAN over `Int`?** The trait signature `A -> A` forces `Int →
Int`, i.e. FLOOR, so `[sqrt 2]` = `1`. That is a real semantic commitment and
there are at least three alternatives: (a) floor, as above — cheap, total, and
silently lossy; (b) NO `Int` instance, forcing an explicit conversion
(`[sqrt [p32-from-int 2]]`) so the precision loss is visible at the call site;
(c) a different signature (`Int -> Posit32`, or `Int -> Option Int` exact-only),
which the current `A -> A` trait shape cannot express. Note `Abs` and `Neg` are
`A -> A` and lossless, so `sqrt` would be the first `A -> A` arithmetic trait
method that is NOT — worth deciding deliberately rather than inheriting from the
trait template.

**Home**: `lib/prologos/core/arithmetic.prologos`, beside `Add`/`Sub`/`Mul`/
`Div`/`Neg`/`Abs`. ⚠ To make the obvious spelling work with no require, `Sqrt`
and `sqrt` must ALSO be added to that module's `:refer` list in the prelude
imports (`namespace.rkt:763`) — the module is already prelude-auto-imported, so
the entry there is the whole difference between `sqrt 32.0` working and reporting
`Unbound variable`.

**Does NOT fix DEFERRED 85 or 86**, and would inherit both: a generic `sqrt` over
a `Posit32` argument still sticks on an exponent literal (85), and a wrong-typed
argument still reports "Multiplicity violation" (86) — arguably more confusingly,
since the user would no longer have written a width-specific name.

**Test obligation**: per `.claude/rules/testing.md`, three-level WS validation —
the trait dispatch is library surface, so Level 3 (`process-file` on a real
`.prologos` file) is the one that matters, plus the `floor(√n)` cases above as
the `Int` instance's own pins.

---

### 88. ⬜ A CARET DOES NOT APPLY EXACTLY ONCE — twice through a broadcast, ZERO times through a sub-block (CIU T6 D4.P4d, Q2's real content)

The spec's rule (§3.4) and Q_T7/Q_T8 together say: **a caret applies exactly
once, at the level where it is written, and "dropped means dropped."** On a plain
dot path HEAD satisfies this exactly — all four ruled operators are correct:

```
app{server.ssl.enabled^-}     → {:enabled true}               ;; Q_T7: whole branch FLAT
app{server.ssl.enabled^-ssl}  → {:ssl true}                    ;; Q_T7: flat, renamed
app{server.ssl.enabled^..}    → {:server {:ssl true}}          ;; Q_T8: ONE level, ancestors kept
app{server.ssl.enabled^ssl}   → {:server {:ssl {:ssl true}}}   ;; rename in place
```

**Three measured members where it does not.** Subject:
`def cfg := {:servers @[{:host "localhost" :port 8080} {:host "example.com" :port 443}]}`

**(1) ZERO applications — `^-` is INERT inside a sub-block, silently degrading to
`^`.** Both spellings produce identical output at 0 errors:
```
app{server.ssl.{enabled^-ssl cert-path^-cert}}  → {:server {:ssl {:cert …, :ssl true}}}
app{server.ssl.{enabled^-ssl cert-path^cert}}   → {:server {:ssl {:cert …, :ssl true}}}
```
Per Q_T7 the first should hoist both entries flat → `{:ssl true :cert "…"}`. The
`-` is discarded: the user asks to COLLAPSE and silently gets a RENAME. This is
the sharpest member — two spellings with ruled-different meanings are
indistinguishable.

**(2) TWO applications — the caret reaches OUT through a broadcast.**
```
cfg{servers:host^}       → @[@[@["localhost"] @["example.com"]]] : ⟨[PVec ⟨String⟩]⟩
cfg{servers:host^-name}  → {:name @[{:name "localhost"} …]}
```
In the first the dissolve fires at the inner (each element → `⟨String⟩`) AND
again on the outer branch (the block itself goes keyless) — hence three levels of
wrapping. In the second the rename lands on the inner AND the outer key. Expected
under the caret-once rule: `{:servers @[⟨"localhost"⟩ ⟨"example.com"⟩]}` and a
single flat hoist respectively.

**(3) A dropped key BORROWS a name instead of staying dropped.**
```
cfg{servers^:host}  → {:host @[{:host "localhost"} …]}
```
`servers^` dissolves the `servers` level, so nothing should name the block entry
— "dropped means dropped". Instead the output name is taken from the INNER step.

**Root cause, verified in three places**: the leaf/label classifiers are
ω-TRANSPARENT but SUB-OPAQUE. `select-branch-collapse` and `select-branch-keyless`
both do `(if (eq? (select-step-kind s0) 'bcast) (select-bcast-inner s0) s0)` —
seeing THROUGH the ω wrapper to find a caret and re-classifying the whole outer
branch — while `select-step-output-name` has `[(sub) #f]` and never unwraps a sub.
So a caret written bare after `:` is counted at two levels, and one written inside
`:{…}` is confined and cannot reach the level `^-` is defined to collapse.

⚠ **The fix is constrained by [Q_U22](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u22)**:
`^` at a leaf stays ARITY-UNIFORM, so `cfg{servers:host^}` corrects to
`{:servers @[⟨"localhost"⟩ …]}` (1-tuples), NOT to bare values. Fixing toward the
bare-value reading would make `xs:{name^}` a second spelling of `xs:name`, which
slice 4c retired.

⚠ **Not a P4d regression** — the asymmetry predates the phase (P4c-3's Q_U7 ω
transparency); P4d made it reachable and visible. Sizing note: member (1) is
likely independent of (2)/(3) and may be separable.

**Pin obligation**: all four ruled dot-path lines above (they are the oracle and
nothing pins them), plus one pin per member, plus the arity pin from Q_U22.

---

### 89. ⬜ AN OPEN-ROW PROJECTION CAN BE ANNOTATED INTO A LIE, and the stuck value then enters arithmetic at ZERO errors (found 2026-08-08 co-designing CIU T6 Q3; NOT a Path Selection question)

Projecting an unknown key off an open row yields a **fresh meta** at the type
layer — "the meta IS the observation", which is D19/Q_T2's deliberate leniency
and is right. The problem is what happens when the user annotates it. Measured at
`da555602`:

```
def cfg := {}                    ;; { | _}
def s1  := cfg.port              ;; ERROR: undischarged open-row projection …
                                 ;; ← the D23 guard, working
def port : Int := cfg.port       ;; ACCEPTED
port                             ;; <error> : Int          ← type says Int
def doubled := [int+ port port]  ;; ACCEPTED
doubled                          ;; [int+ <error> <error>] : Int    0 errors
```

The D23 guard correctly refuses UNANNOTATED storage. But its documented discharge
— *"Annotate to discharge it"* — accepts an annotation the checker has no
evidence for: it held a meta meaning "could be anything", the user asserted
`Int`, and it took the assertion. The `<error>` is a symptom; **the accepted lie
is the defect**, and it is what lets a stuck term wear a clean `Int` into `int+`.

**The language already has the honest shape, and it is one function away.**
`nil-safe-get` puts the absence IN THE TYPE:

```
[nil-safe-get mm :port]          → nil  : Int | Nil     ;; absent
[nil-safe-get {:port 8080} :port] → 8080 : Int | Nil     ;; present
```

You cannot do arithmetic on that without acknowledging the `Nil`. So the
candidate fix is that an open-row projection types as an **option** (`T | Nil`)
rather than as a bare meta the user can annotate away — which makes
`def port : Int := cfg.port` refuse and pushes the user to `Int | Nil` or the
nil-safe idiom.

⚠ Also inconsistent with its own neighbours: the permissive degradation VALUE
elsewhere in this system is ruled to be `none`, not `<error>` — `reduction.rkt`
says *"Match `map-get`: degrade to `none`"*, and an adversarial verify already
caught `expr-error` there as *"a THIRD answer to a question with two"*. The
open-row arm is giving that rejected third answer.

⚠ **Scope**: this is the OPEN-ROW PROJECTION CONTRACT (D19 / Q_T2 / D23), not
Path Selection. CIU T6 only surfaced it. Sizing unknown — the D23 discharge is
load-bearing for existing code, so the census of annotated open-row projections
comes first. The broadcast half is **DEFERRED 58**, which is separable and does
not depend on this.

---

### 90. ⬜ `x{k^_*}` DEFINES A FIELD LITERALLY NAMED `_*`, AT ZERO ERRORS — and it blocks Q_U24's `*_`

Found by the D4.P4e mini-audit (`wf_5fb7131d-63a`), reproduced on the main
thread at `4317c88d`:

```
def cfg := {:database {:url "u" :port 1} :version "v"}
cfg{database^_*}
;; → {:_* {:url "u", :port 1}} : {:_* {:port Int :url String}}   ← 0 errors
```

**Cause**: `split-caret-lexeme` (`parser.rkt`) classifies the caret continuation
by **exact string compare** — `""`→dissolve, `"_"`→synth, `"-"`→collapse,
`"-_"`→collapse-synth — with a **rename catch-all below**. `_*` matches none of
the four, so it falls through and becomes a *rename target* named `_*`. Nothing
rejects a star in a continuation, because `ident-continue?` admits `*`.

**Why it is P4e-blocking, not merely cosmetic**: [Q_U24](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u24)
spells the provenance splat **`*_`** — one glued continuation in the *same
lexeme space*. The converse order is also live and also wrong: `cfg{database*^a}`
splits the caret FIRST, leaving a name `database*`. **So `^`/`*` precedence must
be RULED before either `*_` or bare `*` lands**, and the continuation classifier
must reject unknown continuations rather than renaming to them.

⚠ Belongs to the "a catch-all is a silent-wrong-answer generator" family — the
same shape as the boolean-over-3-valued-domain finding at P4d slice 4d-2.

**⭐ WIDER THAN FILED — FOUR MEMBERS, NOT ONE (measured 2026-08-08 at
`2b9407db`, opening P4e-0).** The rename catch-all accepts *any* continuation,
so every operator character passes through as label text:

```
cfg{database^_*}  → {:_*     {…}}   : {:_*     {…}}   ← 0 errors
cfg{database^a*}  → {:a*     {…}}   : {:a*     {…}}   ← 0 errors
cfg{database^*}   → {:*      {…}}   : {:*      {…}}   ← 0 errors
cfg{database*^a}  → error naming field `:database*`, advising `.database*`  (= 91)
```

**✅ THE PRECEDENCE REQUIREMENT IS DISCHARGED — no new owner ruling needed.**
This entry demanded that `^`/`*` precedence be ruled before `*` or `*_` lands.
[Q_U29](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u29) already answers it, and a
second independent principle covers the other direction:

- **Star inside a caret continuation** (`^_*`, `^a*`, `^*`) — Q_U29: *a star in
  a lexeme is the OPERATOR or it is nothing.* A label bearing a star is not a
  label, so these are guided errors.
- **Star before the caret** (`database*^a`) — the splat has **no single output
  key to re-key**, exactly the reason the landed dot-band refusal gives for
  `q.a^b` (*"`^` re-keys the OUTPUT of a selection, and a field access has no
  output key"*). Also a guided error.

So **a segment lexeme carries AT MOST ONE operator suffix**, which falls out of
two existing principles rather than needing a third, and matches
`split-caret-lexeme`'s own ">1 caret" refusal shape. **Nothing meaningful is
lost**: `name^alias*` would rename and then delete the layer the alias names
(moot), and `name*^alias` would rename N lifted keys to one name (incoherent).
`*_` is the STAR's own continuation ([Q_U24](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u24)),
not a caret interaction.

**Fix, at P4e-0**: the continuation classifier REJECTS an unknown continuation
instead of renaming to it. Monotone — each refusal may become a meaning later.

---

### 91. ⬜ THE CLOSED-ROW MISS HINT ADVISES A SPELLING THAT DOES NOT WORK — and it names Q_U26's ravel

`typing-errors.rkt`'s closed-row miss hint appends
`"; in the select branch \`~a\` — bare field access (no construction) is spelled \`.~a\`"`.
When the branch IS `*`, it advises `` `.*` ``. Measured at `4317c88d`:

- `cfg{*}` → *"in the select branch `*` — … is spelled `.*`"*, and `cfg.*`
  **shatters** to `Unbound variable .`
- `cfg{database*^a}` → *"spelled `.database*`"*, also wrong (path position
  absorbs the star identically)
- also reachable via `cfg{database *}` and `cfg{database.{url}*}`

**Two defects, one site**: (i) the advised spelling is not parseable TODAY;
(ii) after [Q_U26](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u26) bare `.*` is
**RAVEL**, a different operator — so the hint would advise a spelling that
parses and means something else. This is the *"the remedy points back at the
user's own spelling"* rule (P4d slice 4c) violated in the one place P4e is about
to make load-bearing.

---

### 92. ⬜ TWO `*` SURFACES OUTSIDE P4e's NAMED SCOPE — one asserts a surface fact P4e falsifies, one is a LIVE wildcard

The P4e scope names the select surface and the `.*name` coexistence. The audit
found two more, both at `4317c88d`:

1. **`elaborator.rkt`'s retired path-literal wildcard message** states *"In the
   current surface `*` is postfix FLATTEN and a sub-selection is a select block
   `x{…}`"*. [Q_U23](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u23) makes `*` a
   **sort-generic layer-delete** (not "flatten"), and
   [Q_U26](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u26) makes bare `.*`
   **ravel** — so the sentence goes stale **twice** at P4e. A diagnostic that
   asserts a surface FACT is a maintenance liability; this is the class the
   track has already been burned by.
2. **`validate-selection-paths` keeps a LIVE `'*` / `'**` wildcard** (the
   `(string=? seg "*")` / `"**"` arms) reachable from
   `selection … :requires [:address.*]`. Whatever P4e rules about `*` must say
   whether this vocabulary is the same operator, a different one, or retiring.

Grep `wildcard-seg?` and `string=? seg "*"`; neither is in P4e's bullet.


### 93. ⬜ Integral floats/posits display INCONSISTENTLY across the six widths — 2 keep the `.0`, 4 drop it (found 2026-08-08)

Measured at `1ba731eb`, same value in each format:

| format | integral | non-integral |
|---|---|---|
| Posit32 | `1.0` ✅ | `0.5` |
| Float64 | `1.0f` ✅ | `0.5f` |
| Float32 | `1f32` ⚠ | `0.5f32` |
| Posit64 | `1p` ⚠ | `0.5p` |
| Posit8 | `1p8` ⚠ | — |
| Posit16 | `1p16` ⚠ | — |

Only INTEGRAL values are affected — every format prints non-integral values with
digits. It is not a literal-vs-computed distinction either: `[p64/ 2.0p 2.0p]`
prints `1p` exactly as the literal `1.0p` does.

**Cosmetic, NOT a correctness bug — verified.** Every printed form re-reads as
its own type: `1p` → `Posit64`, `1f32` → `Float32`, `1p8` → `Posit8`. So this is
a legibility/consistency item, not a round-trip failure.

**CAUSE — three different mechanisms, only one of them deliberate**
(`pretty-print.rkt`):
- **Posit32** forces it ON PURPOSE — `posit->display`'s `n = 32` arm appends
  `".0"` when the shortest decimal contains neither `.` nor `e`, and the
  function's own header says *"Posit32 bare (integral → forced `.0`)"*.
- **Float64** gets it BY ACCIDENT — `float64->display` is
  `(string-append (number->string v) "f")`, and Racket's `number->string` on a
  flonum already yields `1.0`. Nothing in our code asked for it.
- **Float32, Posit64, Posit8/16** get no forcing at all: `float32->display` runs
  `shortest-decimal` (which yields `1`) then appends `f32`; the `n = 64` and
  `else` arms of `posit->display` append `"p"` / `"pNN"` to the bare shortest
  decimal.

⚠ **The code's own stated intent is not achieved.** `posit->display`'s `n = 64`
arm carries the comment *"Posit64 → bare `p` (symmetry with Float64's `f`)"* —
but for integral values Float64 prints `1.0f` and Posit64 prints `1p`, so the
symmetry the comment claims is exactly what does not hold. Whoever fixes this
should treat that comment as the specification and make it true, or change it.

**Why it matters beyond tidiness**: an integral posit/float reads as an INTEGER
at a glance. This was filed because a user read `* 3 [/ 1.0 3.0]` and its three
siblings as having returned `Int`, and asked how the rounding was collapsing to
one — the values were correct (`1.0`/`1f32`/`1p`/`1.0f`, all exactly one), the
display just made three of the four look like integers.

**⭐ OPEN — which way to unify?** Not obvious, and it should be ruled before the
code moves:
(a) force `.0` everywhere → matches Posit32 and Float64, makes "this is not an
    Int" visible at a glance, and is the reading the `n = 64` comment implies;
(b) drop it everywhere → matches the majority (4 of 6) and the shortest-decimal
    principle, but makes every integral float print like an Int.
⚠ Note (a) has a snag the entry should not hide: `posit->display`'s header
documents the Posit8/16 bare-integer form as INTENTIONAL — *"integral mantissa
re-reads via the pNN integer shape, e.g. `2p8`"* — so unifying toward `.0` needs
that claim re-checked, not overridden.

**Adjacent, same investigation**: DEFERRED 85 (a posit primitive sticks on an
exponent literal) and 86 (a mistyped argument reports "Multiplicity violation").


### 94. ⬜ TASK — a `Float32`/`Float64` value can ONLY come from a LITERAL: there is no `Int`/`Nat`/`Rat` → Float conversion at all (found 2026-08-08)

**The conversion surface is asymmetric between the two real formats**, and the
float half is one-way OUT. From the parser keyword table:

| | from-int | from-nat | from-rat | to-rat | cross-width |
|---|---|---|---|---|---|
| `Posit8/16/32/64` | ✅ | ✅ | ✅ | ✅ | — |
| `Float32/Float64` | ❌ | ❌ | ❌ | `float-to-rat` | `float-to-float32` (NARROWING only) |

Floats have exactly three conversions and all three point AWAY from Float:
`float-to-int`, `float-to-rat`, `float-to-float32`.

**Measured consequences** (all at `541a6b07`):
```
def k := 3
(the Float64 k)                      → ERROR: Could not infer type
(the Float64 [from-int k])           → ERROR: Type mismatch      (from-int is Rat's)
def r : Rat := [from-int 3]
(the Float64 r)                      → ERROR: Could not infer type
(the Float32 (the Float64 3.0))      → ERROR: Could not infer type
[float-to-float32 (the Float64 3.0)] → 3f32 : Float32            (the ONE route, narrowing)
```
So a Float value can enter a program ONLY as a literal — `(the Float64 2.0)` —
and there is no widening `Float32 → Float64` either.

**⭐ WHY THIS MATTERS BEYOND ERGONOMICS: it makes Float UNTESTABLE OVER A RANGE.**
Any property you want to check across many values needs to turn a loop variable
into the value, and for Float that is impossible — every case must be a
hand-written literal. Discovered writing a reciprocal round-trip checker
(`k * (1/k) == 1`), which is ~15 lines and works for all four posit widths:

```
spec p64-ok? Int -> Bool
defn p64-ok? [k]
  let x := [p64-from-int k]
    [p64-eq [p64* x [p64/ 1.0p x]] 1.0p]
```
and CANNOT be written for Float at all, because `[f64-from-int k]` does not
exist. The posit results came out as lists over 1..30; the float column simply
could not be produced. That asymmetry will bite every future numerics property
test, and it is the kind of gap that stays invisible precisely because the
workaround (write literals) looks like a style choice rather than a forced move.

**Suggested shape** — mirror the posit set, which is already the in-tree
precedent: `f32-from-int` / `f64-from-int`, `-from-nat`, `-from-rat`, plus the
missing widening `float32-to-float` to pair with `float-to-float32`. A
posit↔float bridge (`p64-to-float` / `float-to-posit`) may fall out of the same
work but is NOT required to close this.

**Not investigated**: whether the elaborator's numeric-literal defaulting could
supply the widening implicitly (a decimal literal already becomes `Posit32` by
notation origin per N6b, and `(the Float64 2.0)` retypes it — so the machinery to
turn a NUMBER into a Float exists; what is missing is a way to reach it from a
runtime value). That may make this much cheaper than four new primitives.

**Related**: DEFERRED 87 (the generic `sqrt` task) — its `Float64` instance is
usable only on literals for the same reason, which weakens the trait's claim to
be generic over the numeric types.


### 95. ⬜ A `defn`-wrapped `map`/`filter` SILENTLY produces a STUCK TERM — the container type never resolves (found 2026-08-08)

**The LOUD half of this is already recorded** in the legacy entry *"QTT
multiplicity violation with generic trait-constrained functions in defn bodies"*
(§ Type System / QTT), whose workaround — *"keep expressions standalone"* — is
correct and remains the practical answer. **This entry is the SILENT half, which
that entry does not mention and which is the more dangerous of the two.**

```
defn t2 [n]  [map [fn [k : Nat] [from-nat k]] [range n]]      ;; LOUD
defn t4 [xs] [filter [fn [k : Int] [not [f64-ok? k]]] xs]     ;; SILENT
```
· `t2` → `ERROR: Multiplicity violation` — the known, loud case.
· `t4` → **`t4 : [_ Int] -> [_ Int] defined.`** — it DEFINES, with the container
  position a HOLE. Applying it then yields an unreduced term:
  `[t4 '[3 41 49]]` → `[[fst ?meta…] Int [reduce [?meta… Int '[3 41 49]] |
  lseq-nil -> … ]]` with **0 errors**, where the same expression written at the
  CALL SITE gives `'[49] : List Int`.

So the two directions differ by which combinator is applied to what: the failure
is not uniformly loud, and in the silent direction a user gets a definition that
type-checks, a call that "succeeds", and a value that is not a list.

**Cross-references**:
- the legacy QTT entry above — same root cause (erased trait dict params /
  container polymorphism), and it owns the fix;
- **85** — same OUTCOME class (a stuck term wearing a plausible type, 0 errors);
- **86** — the loud direction's message is that same misattributed
  "Multiplicity violation", i.e. this shares 86's diagnostic problem too.

**Not investigated**: which of `map`/`filter`/`reduce`/`foldr` fall on which side
of the loud/silent split, and whether an explicit container annotation on the
parameter (`[xs : [List Int]]`) resolves it — that would make the workaround
better than "keep it standalone".

⚠ **Filed after a duplicate check that killed three of four candidates**, which
is worth recording as evidence the check is worth doing: a float-conversion gap
was already **94**, a display inconsistency already **93**, and a
"keywords aren't first-class" claim of mine was simply WRONG (measured — see the
struck-through legacy entry above).


### 96. ⬜ ⭐ A `map`/`reduce` PIPELINE CANNOT BE PUT IN A `defn` — it works at top level, and fails as a Multiplicity violation OR a SILENT stuck term (found 2026-08-08, THREE independent times in one session)

**The user-facing shape.** This computes at top level:

```
.(1.0 - [reduce * 1.0 [map one-minus @[0.2 0.2 0.2 0.2 0.2]]])   →  0.672319997 : Posit32
```

and the SAME body cannot be wrapped in a function:

```
spec independent-occurence [PVec Posit32] -> Posit32
defn independent-occurence [xs]
  .(1.0 - [reduce * 1.0 [map one-minus xs]])
→ ERROR: Multiplicity violation
```

**⚠ THREE MANIFESTATIONS, and the second is SILENT.** Measured on the same body:
1. **with a spec** → `ERROR: Multiplicity violation` — naming QTT, which is
   innocent (see cross-refs);
2. **with NO spec** → it DEFINES, as `ioB : [_ Posit32] -> Posit32` — note the
   HOLE where the container should be — and then every call returns a STUCK TERM
   with **0 errors**: `[- 1.0 [?meta1642 Posit32 Posit32 [fn [x <Posit32>] …
   [p32* x y]] 1.0 [[fst ?meta1659 …`. A user sees a plausible-looking expression
   echoed back instead of a number.
3. **with the `<T>` angle param/return form** → Multiplicity violation again.

**ANNOTATION DOES NOT FIX IT.** `[PVec Posit32]`, `[List Posit32]`, and the
`<[PVec Posit32]>` form all fail identically. So the container type being named is
NOT what the resolution needs.

**WHAT IS MEASURED (and what is not).** In the stuck term the multiplication
resolved fine — `*` became `p32*` — and the UNRESOLVED metas are the ones sitting
where `reduce` and `map` themselves should be (`?meta1642`, `?meta1659`), with
`prologos::data::lseq::lseq-nil` appearing in the residue. So it is the
COMBINATOR's own dispatch that fails to resolve, not the element operation.
⚠ **The obvious explanation is WRONG and was checked**: `map`/`reduce` in scope
are NOT higher-kinded trait methods. They are `prologos::data::list`'s
List-specific functions (`spec map [A -> B] [List A] -> List B`,
`spec reduce [B -> A -> B] B [List A] -> B`), both in the prelude's `data::list`
`:refer` list; `Functor`'s method is `fmap`, and `collection-traits` refers only
the trait NAMES (`Reducible`, `Collection`), not methods. **So why a List-typed
`map` accepts a `PVec` literal at top level at all, and why it then leaves an
unresolved meta under a `defn`, is NOT established.** That is the first thing to
find out.

**MINIMAL REPRODUCER** (no posits, no user functions):
```
defn t2 [n] [map [fn [k : Nat] [from-nat k]] [range n]]     → Multiplicity violation
defn t4 [xs] [filter [fn [k : Int] [int-lt 2 k]] xs]        → defines as [_ Int] -> [_ Int]
[t4 '[1 2 3 4]]                                             → stuck reduce/lseq term, 0 errors
```
`defn t1 [n] [range n]` defines correctly, so it is the COMBINATOR, not the
parameter.

**WORKAROUND — structural recursion, which is what the prelude itself does.**
`map`, `reduce`, `foldr` and `filter` are each written in `data::list` as a plain
`match xs | nil -> … | cons a as -> …`. Doing the same in user code works:
```
spec prod-one-minus [List Posit32] -> Posit32
defn prod-one-minus [xs]
  match xs
    | nil       -> 1.0
    | cons a as -> [p32* [p32- 1.0 a] [prod-one-minus as]]

spec independent-occurence [PVec Posit32] -> Posit32
defn independent-occurence [xs]
  [p32- 1.0 [prod-one-minus [pvec-to-list-fn xs]]]
```
verified: `@[0.2 ×5]` → `0.672319997` (identical to the top-level form),
`@[0.5 0.5]` → `0.75`, `@[0.1 0.9]` → `0.91`, `@[]` → `0.0`.

**⚠ WHY THIS IS A BIGGIE.** It makes the HOF vocabulary unusable for ABSTRACTION —
the one thing it is for. A pipeline can be written at a call site but never
factored into a named, reusable, testable function, so every user hits it the
moment they try to name a computation they already got working. It was found
THREE independent times in a single session by two different people pursuing
unrelated goals (a probability combinator; a Float64 reciprocal-round-trip
collector; a range/map/filter counterexample search), which is the strongest
available evidence that it is on the main path and not an exotic corner.

**CROSS-REFERENCES**
- **86** — a type mismatch reported as "Multiplicity violation". Manifestation 1
  here is the same lying-diagnostic surface: QTT named for someone else's fault.
  86's entry already argues that fixing this caller-by-caller is the wrong
  granularity; this entry is a third caller and strengthens that.
- **74** (✅ FIXED) — the `def` seam, where a non-ground body type reaching QTT
  produced exactly this message; the fix routes it to "Could not infer type"
  instead. That fix covers the `def` SEAM only. Manifestation 1 is a `defn` body,
  so it is NOT covered, and the same "report the root cause, not QTT's generic
  failure" reasoning applies.
- **85** — the other silent stuck-term filed the same day (`[p32-sqrt 1e10]`).
  Manifestation 2 is the SAME output pathology from a different cause: a term
  that pretty-prints plausibly and reduces to nothing, with zero errors. Worth
  asking once, for both, whether a residual unreduced application in a printed
  RESULT should be loud by default.
- **87** — the generic `sqrt` task. Related usability finding recorded there:
  parser keywords (`from-nat`, `p32-sqrt`, …) are NOT first-class and cannot be
  passed to `map`, needing eta-expansion into a lambda; only `+ - * / negate abs`
  are first-class (N6e-E2). Anyone hitting 96 will hit that immediately after.

**Adjacent usability trap, noted not filed**: list patterns are UNBRACKETED —
`| cons a as ->`, not `| [cons a as] ->`. The bracketed form reads as an arity-3
application (`cons` carries an implicit type parameter), defines cleanly as
`(arities: 1, 3)`, and then silently `??__match-fail`s at every call.

### 97. ⬜ Three `let` spellings — and `def-` — refuse a postfix ACCESS on any value (pre-existing; surfaced by D4.P4d slice 7)  *(was 84 → now 97)*

> ⚠ **Renumbered 84 → 97** at merge prep, 2026-08-08. This branch
> allocated 84 from a register that read 84; main independently filed 84–96
> in the meantime, so `### 84` means something different there. Commit messages
> `44da4627` and `2fe6c8a4` cite the OLD number and cannot be fixed — resolve by
> ancestry. See § NUMBERING and the mapping table below.

Slice 7 gave `let x := (goal …):c` its implicit solve, and the owner ruled the
`let` spellings must not disagree. Extending the aligned/bare arm made two of
them agree — but the other two cannot be reached from here, because they refuse a
postfix access on an **ordinary value** too. Measured at `b6f773a8` with
`def xs := @[{:name "a"}]`, no goal anywhere:

```
let p4 := xs:name          ✅ works
let [p1 xs:name] p1        ❌ "let: each binding must be (name value) or (name : type value), got p1"
let [p2 := xs:name] p2     ❌ "Could not infer type"
let p3 xs:name             ❌ "a fused type annotation here was read as a broadcast step …
                              (`let` is missing from the reader post-pass binder table)"
```

Three distinct diagnostics, three distinct causes. The flat-pairs arm assumes
odd/even index parity that a sibling sentinel breaks; the nested-shorthand form
collides with the FUSED-ANNOTATION reading (`name:T`), which its own error
message already diagnoses and names the fix for. None is caused by slice 7 —
each reproduces identically on both sides of it — so slice 7 pinned only the two
spellings that are capable of carrying an access, rather than pinning someone
else's defect.

⚠ Related in-tree comment that is FALSE at HEAD: `parse-reader.rkt`'s
`mark-binding-values` says its bare arm covers "incl. the fused `name:T VALUE`".
It does not — `let fz:Int (fc …)` refuses with a BARE goal and no postfix at all.

⚠ **`def-` (the private spelling) is in the same class.** The Q_C def leg
(`macros.rkt` `def-rhs-stx`) matches the head `def` LITERALLY, so
`def- x := (goal …)` never carried the implicit solve. Slice 7 briefly made
`def- x := (goal …):c` succeed — an access making a refusing form work, i.e. the
private spelling disagreeing with itself — and was corrected to match the def
leg's own predicate. Whether `def-` should carry Q_C at all is the open question.

⚠ **The internal `$goal-rhs` sentinel leaks into one user-facing message** on the
nested-shorthand path: `let: unrecognized format: (let x ($goal-rhs (fc f red)) …)`
where base echoed the user's own datum. Cosmetic, and only reachable on the
already-broken spelling above — but it should be stripped when that error is
formatted.

### 98. ⬜ An EMPTY group at command position raises a contract violation — a whole-file abort (pre-existing)  *(was 85 → now 98)*

> ⚠ **Renumbered 85 → 98** at merge prep, 2026-08-08. This branch
> allocated 85 from a register that read 84; main independently filed 84–96
> in the meantime, so `### 85` means something different there. Commit messages
> `44da4627` and `2fe6c8a4` cite the OLD number and cannot be fixed — resolve by
> ancestry. See § NUMBERING and the mapping table below.

`()`, `().0`, `():c` and `[]:c` at top level raise
`>: contract violation expected: real? given: #f` and take the WHOLE FILE down —
`pipeline.md`'s whole-file-abort class (output EMPTY, not partial), not a
per-command error. Reproduces identically at `b6f773a8` and with slice 7 applied,
so it is pre-existing; found by slice 7's adversarial verify while sweeping
malformed shapes, and cleared of blame by A/B against a clean-rebuilt base tree.

Worth fixing because the empty group is exactly what a user leaves behind while
editing, and the file then reports nothing at all rather than pointing at the
line.

### 99. ⬜ `'(…)` — a QUOTED GOAL that returns the goal instead of solving it [owner request 2026-08-08]  *(was 86 → now 99)*

> ⚠ **Renumbered 86 → 99** at merge prep, 2026-08-08. This branch
> allocated 86 from a register that read 84; main independently filed 84–96
> in the meantime, so `### 86` means something different there. Commit messages
> `44da4627` and `2fe6c8a4` cite the OLD number and cannot be fixed — resolve by
> ancestry. See § NUMBERING and the mapping table below.

> "We do, sometimes, want to return the Goal and not a solution to the goal, so
> for those cases, `'(...)` a quoted goal should return the goal and not be an
> implicit solve."

Not implemented in any form: `'(fc f "red")` today is `Unbound variable '` — the
reader has a `quote-lbracket` token for `'[` (the list literal) and a bare
`quote` token, but nothing for `'` immediately followed by `(`, so the quote
lexes as a standalone symbol.

This is a LANGUAGE FEATURE, not a parse tweak, and it is why slice 7 did not
attempt it. It needs, at minimum: a reader token + datum form mirroring
`quote-lbracket`; a decision on what a first-class goal VALUE is (there is no
`Goal` type in the tree today — `expr-goal-app` exists only as an internal node
consumed by `solve`); a type for it, so `def g := '(fc f "red")` can be
announced and `solve g` can consume it; a `pp-expr` rendering; and a
`pnet-serialize` registration (per `pipeline.md`, an unregistered node in a
cached module body fails far away, as a deserialized vector impostor).

Natural home: a slice of its own, with the Q_C scope question already settled by
slice 7 (the quote SUPPRESSES the implicit solve wherever that solve would
otherwise fire — top level, `def` RHS, `let` RHS, and now an access subject).

### 100. ⬜ A GOAL KEYWORD under a postfix access gets the broadcast-carrier message, not its own (D4.P4d slice 7)  *(was 87 → now 100)*

> ⚠ **Renumbered 87 → 100** at merge prep, 2026-08-08. This branch
> allocated 87 from a register that read 84; main independently filed 84–96
> in the meantime, so `### 87` means something different there. Commit messages
> `44da4627` and `2fe6c8a4` cite the OLD number and cannot be fixed — resolve by
> ancestry. See § NUMBERING and the mapping table below.

`(not (blocked "c")):c` now reports *"broadcast `:c` needs a PVec, Map, tuple, or
closed keyword-row subject — this one is `_`"*. True but unhelpful: a NAF goal
does not produce rows at all, so there is nothing to broadcast over, and the
message never says so. Base reported the relation-in-application diagnostic
instead — different, and also not right.

Same shape for `(= 1 1).0`, which yields a bare `Could not infer type` on both
sides.

The goal keywords `{rel, not, =, is}` are derived from `run-solve-goal`'s
dispatch, and only `rel` / a relation goal-app yields a row carrier. So the
honest message is per-keyword: "a `not` goal answers yes/no — there are no rows
to select from". Non-blocking (no wrong answer, no abort); found by slice 7's
second adversarial verify.


---

### 101. ⬜ ⭐ THE NON-IDENTIFIER STAR CARRIERS ARE UNSPELLABLE — the P4e-0 mint was REVERTED, and the gap is filed rather than left silent

`*` is ruled SORT-GENERIC ([Q_U23](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u23)) and its
surface was ruled sort-generic too ([Q_U27](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u27)).
**Only the IDENTIFIER band delivers that today.** `ident-continue?` admits `*`,
so `database*` / `:tags*` / `c*d` arrive as ONE token and the parser splits
them. Every other carrier still shatters:

| spelling | at HEAD |
|---|---|
| `m{0*}` · `m{0 *}` | byte-identical datums — the ordinal splat is **unspellable** |
| `x{a}*` · `[f x]*` · `xs:{a}*` | the star is a loose sibling |
| `xs:0*` | the `$bcast-step` mint is destroyed (`recognize-colon-annotation`'s trailing guard declines on `*`) |
| `x.0*` | the `$postfix-index` is destroyed (`recognize-dot-ordinal`'s **byte-identical twin** guard) |
| `*_` on any non-identifier carrier | leaks `Unbound variable *_` |

**WHY THE FIRST TWO ATTEMPTS FAILED — read this before the third.**

**Attempt 1, a COUNT-CHANGING adjacency mint** (`bfba68d5`, reverted here).
`*` is postfix, so the mint consumed the item BEFORE it. Measured consequences:
· four preparse forms silently accepted a SHORTENED form, two of them losing a
definition (`bundle Bx := (Add Sub)*` produced NO output where the spaced form
correctly errors) · the glued Sigma spelling `<(x : Nat)* Nat>` became a parse
error, a clean regression · the two groupers wrapped DIFFERENT items on `<`/`>`
· `$star-step` could not be expressed in slice 7's head-set vocabulary, because
its membership was CONDITIONAL on its payload.

**Attempt 2, a COUNT-PRESERVING marker** (designed, never written — refuted by
grounding `wf_282dce0e-2ac`). `segment-select-items` is reached ONLY from the
args of a `$select`/`$select-path` node, and the fold CLOSES the selection as it
goes — so a non-sentinel marker is left a SIBLING of the finished node, outside
the args. Three of four bands would get *"it appeared here without a selection
to attach to"* with a selection immediately to their left. Registering it
instead collides with slice 7's TWO arity classes (`test-solve-carrier.rkt` now
pins that arity-1 lists are not sentinels) and orphans subjects: `[f]*.a` folds
`.a` onto the marker, dropping `f`.

**THE LESSON, and it is the one to carry into attempt 3**: both designs modelled
the mint's blast radius as *the selection surface*. **It is the whole reader.**
Preparse form validators, the angle/type grammar, the tree grouper's `result`
and slice 7's subject-marking all sit upstream or sideways of
`segment-select-items`, and all four are where the defects were.

**Attempt 3 must open with a MEASURED MAP** [owner, 2026-08-09]: every consumer
that counts items, every consumer that switches on shape, and every grammar that
already claims `*` — enumerated from the code, not from intuition about where a
star can safely fire.

**Also owed, independent of the mint**: `recognize-dot-ordinal`'s guard is the
untouched twin of `recognize-colon-annotation`'s; a band-dependent divergence
makes `(G):f*` keep the implicit solve while `(G):0*` loses it on a purely
lexical accident (latent now, a silent wrong answer once `*` has semantics).

---

### 103. ⬜ ⭐ A BARE `*` IS A LEGAL IRREFUTABLE PATTERN — it SILENTLY DELETES every later `match` arm, and loses the enclosing `defn`

Found by the same census; reproduced at `d0ac2a58`. Pre-existing, 0 corpus sites.

```
def q := 5
match q
  | 2 * -> 99
  | n -> n
```
→ elaborates to `[reduce x | 2 -> 99]` — **ONE arm**. The `| n -> n` arm is gone.
The only symptom is a downstream `Could not infer type`, which names neither the
star nor the missing arm.

`| 2 * ->` is read as a two-element pattern whose second element is a fresh
irrefutable binder, so the arm matches everything and the rest are unreachable
and dropped. In `defn` clause position the sibling shape
(`defn f | red* -> …`) loses **`f` itself** → `Unbound variable f`, with a
diagnostic that blames spelling or imports.

The census called this "the worst failure mode" it found: silent, zero errors,
and invisible to a green suite because nothing in the corpus spells it.

⚠ **Bears on the star design** ([DEFERRED 101](#)): if a bare `*` stays legal in
pattern position, any star mint must be pattern-position-aware **at a stage that
does not know it is in a pattern**. Refusing it there converts a silent wrong
answer into a loud error *independently of any star work* — but it is a language
ruling, not a repair (owner Q2 of the census).

⚠ Sibling, same seat: `compile-match-tree` **aborts** on a multi-form LITERAL arm
(`| 2 3 -> 99` → `list-ref: contract violation`, `macros.rkt:11313`), and it
reproduces in **sexp** mode, so it is an IR defect. Consequence for method: a
star-free CONTROL can be the leg that detonates, so an A/B assuming the control
is safe will mis-attribute.

⚠ **Coordinate drifted** (re-measured 2026-08-10 at `19560a7c`): the abort is at
`compile-match-tree` in `macros.rkt`, reported at **`:11333`**, not `:11313`.
Anchor on the symbol.

---

### 104. ⬜ A BARE OPERATOR BOUND BY `def` YIELDS A STUCK TERM AT ZERO ERRORS — `let` binds the same operator correctly

Found 2026-08-10 by the Q_U32 bare-`*` position sweep (CIU T6 P4e prep). **Not a
star defect and not a selection defect** — the star was the probe; it reproduces
with `+`, so it is the whole first-class-operator surface (Numerics N6e-E2).

Measured at `19560a7c`, one file, zero errors reported:

```
def p := +
[p 6 7]        ;; => [?meta1631 6 7] : _     ← STUCK TERM, no error

let q +
  [q 6 7]      ;; => 13 : Int                ← correct
```

`def p := +` reports `p : _ _ -> _ defined.` and then the application does not
reduce: the function position stays an unsolved meta and the whole term is
returned stuck, **with the file reporting 0 errors**. The `let` spelling of the
identical binding resolves and evaluates. Same divergence with `*`
(`def times := *` → `[?meta1700 6 7] : _`).

**Why it is filed loud**: this is the silent-wrong-answer shape — no error, a
plausible-looking echo, and a value that is not a value. A user reading
`p : _ _ -> _ defined.` has no signal that `p` is unusable.

**Suspected mechanism (INFERRED, not probed)**: per `prologos-syntax.md`, in HEAD
position at arity 2 `[+ a b]` is the parser keyword with auto-widening, while
everywhere else the name denotes the lawful same-type trait function needing dict
resolution from context. A bare `def` RHS has no context to resolve against, so
the dict meta is never solved — but the def seam checks in CHECK mode and lets it
through, whereas `let`'s binder path supplies the context. ⚠ If that is right, the
adjacent hazard is `pipeline.md` § "infer / inferQ Are Twins" — verify before
believing it.

**Fix direction**: either resolve at the `def` seam as `let` does, or refuse with
a guided error naming the annotation (`def p : Int -> Int -> Int := +`). Refusing
is monotone; silently stuck is not. **Not scoped to P4e** — filed so the sweep's
find is not lost.

---

### 105. ⛔ R4 (the tokenizer repair) IS NOT INDEPENDENTLY LANDABLE — restoring the carrier TOKEN makes the star a separate datum ITEM, and that count change is attempt 1's failure mode

Built, verified, and REVERTED 2026-08-10 at D4.P4e-0 attempt 3 slice B. Not a
coding error — a **scoping** result, and it is the reason the census called
`xs:0*` / `x.0*` "unreachable under ANY spelling without a tokenizer repair"
without saying the repair alone suffices.

**What was built** (per [Q_U30](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u30)'s
R4): both digit arms of `recognize-dot-ordinal` / `recognize-colon-annotation`
stop before a trailing `*` instead of declining on it, and the star mint accepts
`colon-annotation` / `dot-ordinal` as predecessors. It WORKED at the token layer —
`xs:0*` → `xs` `:0` `*` → `(xs ($bcast-step :0) *)`, carrier restored; six of the
seven carriers minted; battery 468 green; acceptance 84/84; all of slice A's
gates held.

**⛔ AND IT WAS A SILENT-WRONG-ANSWER REGRESSION.** The repair takes the source
from 4 tokens to 3, so the star becomes a **separate datum item** — and item
counts are load-bearing. Measured, HEAD vs the built tree, both at 0 errors on
the working tree:

```
def p := [pvec-from-list '[10 20 30]]
spec take2 {B : Type} Int -> B -> Int
defn take2 [a b] a
def w2 := [take2 p.0*]
```
· HEAD: `ERROR: Too many arguments to 'take2'` (4 items) — **loud**
· BUILT: `w2 : Int defined.` / `10 : Int` — **0 errors**, and the flatten the user
  wrote was silently discarded, the `*` filling `take2`'s second parameter
  (operators are first-class since Numerics N6e-E2).

Also measured: a `defr` `||` fact row `|| a.0*` chunks by arity, so the relation
silently registered **2 rows instead of 4**; and `bundle P3 := (Add:0* Sub)` went
from a guided `invalid constraint` to silently **inventing a type parameter**
that a later `where` clause then accepted.

**⭐ THIS IS ATTEMPT 1'S FAILURE MODE, ONE SLICE LATER, IN A NARROWER APERTURE** —
and slice A's own shipped comment names the property it violates: *"COUNT-
PRESERVING … which is the whole reason this is not attempt 1 (a count change is
absorbed silently by the ~416 count-gated validator arms)."*

**⚠ AND THE ARGUMENT THAT CLEARED IT WAS A CATEGORY ERROR — worth more than the
bug.** One verify axis measured 1,943/1,943 "NEW(glued) ≡ HEAD(same source with a
space before each star)" and offered that containment as *"the argument that makes
the count change payable"*. It is not. Token-stream containment says HEAD *could*
have produced this stream **from different source text**; it says nothing about
the meaning of the source the user wrote. `xs:0 *` and `xs:0*` agreeing IS the
defect, because the glued spelling's meaning moved from a loud refusal to a
silently-absorbed argument. **Containment is not a safety property; here it was a
restatement of the defect.**

**WHY THE OBVIOUS FIX DOES NOT APPLY.** The identifier band is count-PRESERVING
because it FUSES: `x.name*` is ONE token and the star rides inside the symbol
(`($dot-access name*)`), split later by `split-star-lexeme`. The ordinal band
cannot do that: `$postfix-index`'s payload is `(string->number (substring lexeme
1))` and MUST be numeric, so a `.0*` lexeme yields **`#f`** — a silent wrong
ordinal. **The star has nowhere to live in an ordinal payload.**

**THE REAL BLOCKER, therefore**: R4 cannot land until the star's DATUM
REPRESENTATION is decided — a wrapper sentinel (`$star-step`, which
`reader-forms.rkt` records as *"DELIBERATELY ABSENT … a deferred RULING"*), or a
widened `$postfix-index` arity. Both are P4e-1-shaped representation decisions,
not tokenizer work. **Reopen R4 only after that ruling.**

**Doc-truth found alongside, all in `parser.rkt`, all still live**: a comment
asserts `xs:0*` "lexes as `:0` + `*` since P4e-0's annotation-guard fix, so the
ORDINAL carrier arrives as a `$star-step`" — **both halves false** (the revert
`d0ac2a58` restored the guard; `$star-step` does not exist) · another references
`star-step-trigger?` — ⚠ **THIS LINE'S OWN CLAIM WAS CORRECTED 2026-08-10
(`0306ed72`) AND THE CORRECTION DID NOT REACH HERE UNTIL 2026-08-10.** It read
"has **no definition anywhere in the tree**", which is FALSE as written:
`git show bfba68d5:racket/prologos/parse-reader.rkt` has it exported, defined and
called. It has no definition **at HEAD** because the revert `d0ac2a58` took it
with the mint. The comment is stale about a symbol that DID exist — diagnosed by
reading instead of by `git log`, which is the finding, not the symbol · a third
states "every star that now reaches the parser takes a guided not-yet", which is
false for slice A's carriers too (only the FUSED identifier band gets the guided
message).

---

### 106. ⬜ The `let` NESTED-SHORTHAND binding value leaks a RAW SENTINEL to the user — pre-existing, and it BOUNDS Q_U35's blast-radius argument

Found by the D4.P4e-1a mini-audit (`wf_9bbe5f5a-9e0`), **re-measured on the main
thread before filing**. Not caused by the star; the star only joins it.

**Measured at HEAD** (`process-string-ws`):

```
ns z1 / def c := {:a 7} / defn g [z] / ⇥ let k c{a}* / ⇥⇥ k
  → let: unrecognized format: (let k c ($select-brace a) * k)
```

**The differential is what proves authorship** — the same seat with an EXISTING
sentinel and no star at all:

```
ns z2 / def c := {:a 7} / defn g [z] / ⇥ let k c.a / ⇥⇥ k
  → let: unrecognized format: (let k c ($dot-access a) k)
```

So `$dot-access` already leaks here today. Control (`let k 7`) is fine.

**Cause**: there are exactly FOUR `rewrite-dot-access` call sites —
`preparse-map-literal-contents`, `preparse-expand-subforms`, the `|>` expander
and the `$mixfix` expander. The nested-shorthand `let` binding value is reached
by none of them, so neither the fold nor any refusal seated in it ever fires.

**⚠ WHY IT IS LOAD-BEARING BEYOND ITS OWN SIZE**: it BOUNDS
[Q_U35](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u35)'s claim that refusing
"dissolves that whole blast radius instead of arming it site by site". That
holds only WHERE THE FUSE SEAT RUNS. Q_U35 is not wrong; its scope is narrower
than stated, and this is the counter-example.

**⚠ SPELLING-SENSITIVE WITHIN `let`** — one gate row would not find it. The
ALIGNED multi-binding form folds correctly (`g : _ -> Int defined.`); the
NESTED-SHORTHAND single-binding form leaks; the BRACKET form fails differently
(`each binding must be (name value)…`). **Any gate row must spell all three.**

**Not fixed at P4e-1a**: pre-existing, differential-proven, and *Watching 9*
(mid-flight widening is where this arc introduces defects). P4e-1a's obligation
is bounded to not worsening it invisibly — 1a-i's widened gate carries all three
`let` spellings.
⚠ **STATED PRECISELY, because the gate is not total here and this entry's seat is
where the residue lives**: planting the sentinel in all 220 minting cells, 208
turn the gate red and **12 do not** — 8 of them `let-bracket`, 1 `let-nested`,
3 `quasiquote-body`. So the rename cannot slip a new leak past the gate in the
`let-aligned` and `let-nested` spellings, but `let-bracket` is largely blind, for
the same reason this entry exists: no `rewrite-dot-access` seat reaches it, and
its failure is a shape error that never echoes the offending datum.

### 107. ⬜ A CARRIER-PLUS-STAR in PATTERN position mints, is UNRULED, and silently drops an arm — Q_U32 ruled only BARE `*`, and its refusal never landed

Found by the same mini-audit; **the census's completeness critic PREDICTED it**
(`2026-08-09_STAR_SURFACE_CENSUS.md`: a third design "will still miss that `*` IS
ALREADY A BINDING PATTERN … a SILENTLY DELETED CLAUSE rather than an error").
Re-measured on the main thread.

**Measured at HEAD**:

```
ns p1 / defn f [z] z / defn h / ⇥ | [f 1]* -> 1 / ⇥ | z -> 2
  → cannot infer the type of an unannotated parameter …
    [fn [x <_>] [fn [y <_>] [reduce x | f -> …]]]
```

Arm 2 is GONE and the arity changed; the diagnostic never mentions the star.

**The differential is worse, and again pre-existing** — an existing sentinel in
the same seat, no star:

```
ns p2 / def c := {:a 7} / defn h / ⇥ | c.a -> 1 / ⇥ | z -> 2
  → h defined (arities: 1, 3).       ← ZERO errors, a silently invented arity
```

**The gap in the rulings**:
[Q_U32](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u32)'s measured domain is BARE
`*` (`| * ->`, `| 2 * ->`, `defn f | * ->`, `defn f | red* ->`) — carrier-plus-
star is not in it. And Q_U32 is a **RULING ONLY**: no pattern-position refusal
exists in the tree (`star-not-yet-message` + its three call sites are the whole
surface), so the guard rail it names is unbuilt.

**Two obligations, deliberately separated**: (a) the PRE-EXISTING sentinel-in-
pattern-position hole, which `c.a` demonstrates at zero errors and which is the
larger defect; (b) ruling carrier-plus-star, which is a Q_U32 EXTENSION and wants
an owner ruling. Neither is P4e-1a work — but 1a-i's generated gate covers
pattern position, so the rename cannot make (a) worse unseen.

### 108. ⬜ A TRAILING `*` in PATTERN position or MATCH-SCRUTINEE position is a WHOLE-FILE ABORT — 19 cells, PRE-EXISTING, and the star's MINT is NOT implicated

Found at D4.P4e-1a slice 1a-i, by a generated sweep
(`racket/prologos/tools/star-arrival-matrix.rkt`). **21 of 320 cells raise out of
preparse**, i.e. the file produces NOTHING — `pipeline.md` § "A Raise on the
Parse/Expansion Path Is a WHOLE-FILE Abort".

| context | cells | signature |
|---|---|---|
| `pattern-pos` (`defn h \| CARRIER -> 1 \| z -> 2`) | 7 | `list-ref: contract violation` / `index too large for list` |
| `match-scrut` (`defn h [z] match CARRIER \| w -> 1`) | 14 | `car: contract violation` |

*(First measured at 19/280 over a 14-carrier matrix; re-measured at 21/320 after
the slice's adversarial verify added the `xs[0]*` carrier — which aborts in both
contexts — and a `c.a*` fuse-band control, which aborts in neither.)*

**⭐ THE MINT IS RULED OUT, by a glued-vs-spaced differential on the SAME shape:**

```
| '[1 2]* -> 1     mint=Y   RAISE list-ref: contract violation
| '[1 2] * -> 1    mint=n   RAISE list-ref: contract violation   <- IDENTICAL
| '[1 2] -> 1      (no star)        4 outputs, fine
match '[1 2]*      mint=Y   RAISE car: contract violation
match '[1 2] *     mint=n   RAISE car: contract violation        <- IDENTICAL
match '[1 2]       (no star)        4 outputs, fine
```

A **SPACED** `*` is ordinary first-class-operator surface (it is exactly what
[Q_U32](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u32)'s guard rail protects), so
this predates the whole P4e star work. Corroborating: three NON-MINTING controls
(`xs:0*`, `x.0*`, `#p(a)*`) abort in `match-scrut` too. Slice A is not the cause,
and neither is P4e-1a.

**The `pattern-pos` signature is DEFERRED 103's SIBLING** — `list-ref` out of
`compile-match-tree`, the same accessor and the same class as the recorded
`| 2 3 ->` abort. Likely one fix; check before treating them as two.

**Severity note.** `defn h | '[1 2] * -> 1 | z -> 2` is legal-looking surface a
user can write today, and it silently produces **no output at all** — not an
error, nothing. That is the "output stops being partial rather than becoming
partial" tell.

**Pinned, not skipped** — `tests/test-path-selection.rkt`, the slice-1a-i gate.
The 19 cells are recorded as a MEASURED SNAPSHOT and compared as a whole set, so
a NEW abort turns the battery red **and so does a fix** (which should then update
the snapshot and claim the win here). Skipping them would have silently narrowed
the gate — the one failure mode a coverage instrument cannot self-report.

**Not fixed at P4e-1a**: pre-existing, differential-proven, and it is a
`compile-match-tree` / match-scrutinee defect rather than star-surface work.

### 109. ⬜ A SELECTION SENTINEL in a `spec`/`defn` TYPE REGION mis-fuses with `$angle-type` AS ITS SUBJECT, and the seam prints raw SYNTAX OBJECTS — pre-existing, star-free

Found at D4.P4e-1a attempt 2 by the message-leak gate (the E2E pin that compares
leaking contexts as a SET); **proven pre-existing by star-free differentials**
before filing:

```
spec s1 c{a} -> Int    (no star)
  → defn: expected <ReturnType> or : ReturnType, got
    (#<syntax… ($select $angle-type a)> #<syntax… ->> #<syntax… Int>)
spec s2 c.a -> Int     (no star, the DOT sibling)
  → … ($select-path $angle-type a) …                      ← identical class
```

**Two defects in one seat:**
1. **The mis-fusion.** `rewrite-dot-access` runs over a type-region list whose
   HEAD is the `$angle-type` symbol, so the select-brace/dot arms wrap **the head
   symbol itself** as their subject — `($select $angle-type a)`, a nonsense node.
   The fold's "wrap the predecessor" assumes expression position; a type list's
   first element is a SENTINEL HEAD, not a value.
2. **The display.** The `defn: expected <ReturnType>` error formats raw SYNTAX
   OBJECTS (`#<syntax…>`) into a user message — internal representation at the
   user, the same class as DEFERRED 106's `let` seat. Under P4e-1a a
   `$postfix-star` rides along (`spec s0 c{a}* -> Int` shows it verbatim), which
   is how the gate caught the seat — but the star is a PASSENGER: the seam even
   INSERTS an arrow, so the star's fold-time predecessor is `->` and Q_U36's
   fuse correctly declines it.

**Adjacent, not duplicate**: DEFERRED 106 is "a seam the fold never reaches";
this is the opposite — a seam the fold reaches AND SHOULD NOT, plus raw-syntax
display. The ARROW T1 `spec e-> Int -> Int` silent-accept class lives at this
same seam.

**Pinned**: `tests/test-path-selection.rkt`'s message-leak set carries
`spec-type` as a member; fixing either half moves the set and turns the battery
red, which is how the fix claims its win.

### 110. ⬜ `expand-pipe-block`'s single-element unwrap cannot tell "ONE fused item that is a list" from "a list of parts" — a TERMINAL fused star in `|>` gets a factually FALSE refusal

Found by the D4.P4e-1a attempt-2 adversarial verify; **the ambiguity is
PRE-EXISTING** (starless control: `def r0 := |> c{a}` → `Unbound variable` — the
spread turns the fold's `($select c a)` into `init='$select`), but the star's
fused output is ALWAYS list-shaped, so the new surface lands in it
deterministically.

**Measured**:

```
def r1  := |> c{a}*     → "`*` (flatten) applies to a SELECTION step — there is
                           no selection to its left here"   ← FALSE; the fold fused it
def r1b := |> c{a}* f   → the not-yet message               ← correct (mid-pipe)
```

**Cause**: `expand-pipe-block` (macros.rkt) re-wraps the fold result with
`(if (list? folded) folded (list folded))` — the one-element unwrap at the
fold's exit returns the fused `($select-path ($select c a) $postfix-star)`
ITSELF, which is a list, so the pipe expander spreads it as parts:
`init = '$select-path`, steps = the fragments. Its own comment ("the
single-element unwrap at the fold's exit is re-wrapped") is false for every
fused-selection result.

**Pinned as the accident** (`test-path-selection.rkt`, "the pipe-TERMINAL fused
star"), exactly as Q_U19's pin froze one: the pin documents today's routing and
must not be read as a ruling. Fixing this entry turns that pin red, which is how
the fix claims the cell. ⚠ Note the fix is in PIPE territory, not star
territory — the unwrap needs a shape test that distinguishes a single folded
NODE from a parts list (e.g. keying on the known fold-output heads), and the
starless `|> c{a}` case should come right with it.

### 111. ⬜ CLASS: error sites that echo RAW PREPARSE DATUMS into user messages — two fixed instances, no census

The D4.P4e-1a attempt-2 verify found TWO seats where an error message echoes the
offending source datum verbatim, so the star rename silently changed the echoed
content from `*` (what the user typed) to `$postfix-star` (the internal name):
the `def` seam's "unexpected tokens before `:=`" (macros.rkt) and the `fn`
binder error (parser.rkt, which printed raw `#<syntax …>` objects). Both are
FIXED in the slice via `unmint-star-for-echo` (macros.rkt) + battery pins — but
they were found **by luck of two probes, not by enumeration**, and the
adjudicator's point stands: every `format`/`error` site that interpolates an
unparsed datum is a candidate seat, and the matrix's leak pin only sees the 19
arrival contexts.

**The ask**: a grep-driven census of raw-datum-echoing error sites
(`format` + `~a`/`~s` over preparse-level datums in macros.rkt / parser.rkt /
driver.rkt / namespace.rkt), each classified: echoes user source (should render
the user's spelling — route through `unmint-star-for-echo` or a successor) vs
internal diagnostics. DEFERRED 106 (`let` prints its raw datum) and DEFERRED 109
(`spec` seam prints raw syntax) are the two KNOWN unfixed members; `pol8-bad-head-error`
and `process-ns-declaration`'s segment message were flagged at 1a-ii as two more.
Related-but-different: `$facts-sep` (DEFERRED 112) leaks as an UNBOUND VARIABLE,
not an echo.

### 112. ⬜ `defr` + `||` fact blocks leak `Unbound variable: $facts-sep` — star-free, pre-existing

Ambient observation from the D4.P4e-1a attempt-2 verify (also seen during the
1a-i matrix work as "Unbound variable $facts-sep" in defr/goal-argument
contexts): `defr pair2 [?a ?b]` followed by a `|| …` fact block — and the
minimal `|| 1 | 2` under an arity-1 defr — reports `Unbound variable:
$facts-sep`. An internal sentinel surfacing at the user with NO star anywhere;
structurally untouchable by the P4e work (every added arm keys on
`$postfix-star`). The `||` fact-row machinery emits `$facts-sep` and some path
fails to consume it. Rel-territory (POL.7 fact rows), not star territory.

---

### 113. ⬜ `pp-expr`'s `'path` arm HARDCODES the `.` separator while `pp-select-branch` honours `first?` — the same defect fixed one arm over at P4d-0 slice 5, sibling never swept

Found by the D4.P4e-1b-iii attempt-3 mini-audit (`wf_bbf1169e-340`), and **filed
rather than fixed because the user-visible half did NOT reproduce on the probe I
wrote for it** — see the honesty note below.

**VERIFIED by code read** (`pretty-print.rkt`, quoted at HEAD `7fd25f35`):

```racket
[(path)  (if (= (length branches) 1)
             (format "~a.~a" (pp-expr subject names)          ;; ← hardcoded `.`
                     (string-join (map pp-select-branch (list (car branches))) ""))
             ...)]
```

`pp-select-branch` renders its FIRST step with `first? = #t` — i.e. deliberately
*without* a leading separator, because the caller is supposed to supply the right
one. This caller always supplies `.`. So a branch whose first step carries its own
glyph renders with BOTH: an ω branch as `users.:tags`, and (under P4e-1b) a
branch-initial star as `c{a}.*`, which is not a spelling the language has.

⭐ **The identical bug one arm over was already fixed**, and its comment states the
shape exactly: *"D4.P4d-0 slice 5: honour `first?` — this arm hardcoded `.{` and
ignored the flag the bcast arm passes, so `users:{a b}` rendered as the NONEXISTENT
spelling `users:.{a b}` in every diagnostic path (the bcast arm's own comment
claimed otherwise)."* The sibling site was not swept then. ⚠ The `[(star)]` arm's
own comment reasons about `first?` (*"a branch-INITIAL star … is a real spelling,
and `.{*}` would be a nonexistent one"*) — it does its half correctly; the
separator is emitted by a caller that knows nothing about the branch's first step.

⚠ **HONESTY NOTE, and it is why this is a filing and not a fix.** The audit stated
the consequence as user-visible (`c{a}*` "will echo as `c{a}.*`"). **I could not
reproduce it**: a probe at HEAD using `users:nosuch` and `c.nosuch` returned the
field-miss diagnostics, which do not route through `pp-expr`'s `'path` arm at all.
So what is established is the CODE SHAPE, not the user-facing rendering. What is
owed before fixing: identify which diagnostics (or value displays) actually render
a `'path`-sort `expr-select` through `pp-expr`, and pin one. If none does, the arm
is unreachable and the fix is trivial-but-untestable — which is itself worth
knowing, and is the same "argued-unreachable" trap this arc keeps paying for.

⚠ **THE OWED REPRODUCTION LANDED 2026-08-12, at 1b-iii-B2** — measured, not
inferred: `users := {:name "alice"}` / `users:tags*` renders its echo as
`bcast-e2e::users.:tags*` — the hardcoded `.` before the ω step's `:`, exactly
the predicted nonexistent-spelling class (`users.:tags`), with B2's star riding
along. Route: `inference-failed-error`'s message tail → `pp-expr`'s `'path` arm.
So the arm IS reachable from a live diagnostic and the fix is testable — this
entry is ready to be scheduled. (The B2 pin beside it documents the echo as
capture-fidelity-with-a-wrong-separator, not a field-name defect.)

**Not P4e-1b-iii work**: pre-existing, star-free (the ω spelling exhibits it
without any star), and *Watching 9* — mid-flight widening is where this arc
introduces its defects. The 1b-ii display pin cannot see it: it calls
`pp-select-branch` directly and never goes through `pp-expr`.

---

---

### 114. ⬜ `#p(a.b*)` accepts a star-fused segment as a LITERAL KEY, and `[get-in m #p(a.b*)]` yields a first-class `<error>` VALUE at ZERO errors — pre-existing, star-adjacent

Found by the 1b-iii-B adversarial verify (`wf_30884180-93c`), independently
reproduced with controls. `def p2 := #p(a.b*)` → `p2 : Path defined.` at 0
errors (the `b*` stored as a literal key — Q_U28's operator-wins ruling violated
on this surface); `[get-in m p2]` → `<error> : _` printed as a FIRST-CLASS VALUE
with zero error lines, where the inline miss control `[get-in m #p(a.nosuch)]`
is loud. PRE-EXISTING relative to B1/B2 (the `#p` reader is not one of the four
migrated bands; census G6: `#p(…)` is an opaque reader region). Two defects: the
star-in-path-literal acceptance, and the `<error>`-as-value leak (the P4b-i
`#p` retirement's residue). The fix likely belongs with the `#p` vocabulary's
disposal (P4e-2 / the `.*` retirement inventory's neighbour).

⚠ F3 from the same verify — a match row carrying an extra pattern is a
WHOLE-FILE abort (`compile-match-tree` `list-ref`, macros.rkt:11484 at
`d5934397`), which the star surface hands users a natural road into
(`| mm{zz}* -> 1` kills the file) — is **DEFERRED 103's sibling** (that entry
already records the `list-ref` signature) **+ DEFERRED 108's abort set**; noted
there rather than re-filed. Starless controls (`| 1 2 -> 3`) abort identically.

---

### 115. ⬜ L2's normal form is NOT legality-preserving across a `*` — `{p:a* p:b} ⟶ p:{a* b}` needs a side condition (P5 owns L2)

Found in the [Q_U46](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u46) design round
(options panel `wf_f8461dda-659`), measured at `68604a07`.

Spec §4's **L2 (Factoring / normal form)** is `{p:a p:b} ⟶ p:{a b}` when spines
are identical, and §3.6's spine definition **does not mention `*`**. Read
literally, `modules:diags*` and `modules:diags` share a spine — so a normalizer
would factor a starred branch together with an unstarred sibling.

**MEASURED that this is not legality-preserving**: `bd{modules:{diags* name}}`
is an **L4 mixed keyed/keyless error** — the star's branch contributes a KEYLESS
component (its contents join into a vector) beside the keyed `name`, and one
level assembles a Map OR a tuple, never both. So the factored form can be ILLEGAL
where the unfactored form is fine.

**What is owed**: L2's side condition, written so a future normalization pass
cannot apply the law across a star-bearing branch. Q_U46 rules the seat-level
symptom a **guided error**; this entry is the LAW's repair, which belongs with
**P5** (Ruling B + L2 factoring — `§5.P5`). ⚠ Write it before P5 builds the
normalizer, not after: a normalizer that silently changes a program's legality
is the worst shape this class can take.

### 116. ⬜ THE BRACKET ORDINAL `m[0]` IS REDUNDANT WITH `m.0` — but ONLY for a LITERAL index; `m[i]` is dynamic indexing with no dot-band spelling

Raised by the owner 2026-08-12 during the D4.P4e-1b-iii-C co-design ("deprecate
the `m[0]`, it's redundant with `m.0`, and out of scope if it complicates
implementation"). **Filed rather than ruled, because measuring it falsified half
the premise.**

**MEASURED at `0feca574`** (`v := @[10 20 30]`, `i := 1`):

| spelling | result |
|---|---|
| `v[0]` | `10 : Int` |
| `v.0` | `10 : Int` — **identical** |
| `v[i]` | **`20 : Int`** |
| `v.i` | ERROR — *"`i` is not a field of a vector element position — a vector subject takes ordinal steps (`.N`) or ordinal branches (`x{N M}`)"* |

So the redundancy holds **only for a literal index**. `v[i]` is DYNAMIC
indexing and the dot band cannot express it: `.N` takes a literal ordinal or a
field name, and a variable is neither. This is the `[k]` ordinal/dynamic sort
that [Q_U12](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u12) lists as a deferred
sort — the dynamic half turns out to be already live.

**Also measured**: `cfg2{a[0].b}` and `cfg2{a.0.b}` are byte-identical
(`{:a {:b @[1 2]}}`), and the starred forms render the IDENTICAL label `a.0.b*` —
the printer already normalizes the bracket away. **Zero corpus sites** for a
bracket ordinal inside a select block.

**⚠ IT DOES NOT SIMPLIFY THE STAR WORK, and that was the reason offered for
doing it now.** [Q_U47](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u47)'s gap is
about steps that contribute no output NAME. Deprecating `[0]` removes a
*spelling* of the ord-step but leaves `.0`, and it does not touch the ordinal
BRANCH HEAD (`vh{0 …}`), which is a different kind — MEASURED `vh{0}` →
`⟨[PVec [PVec Int]]⟩`, a keyless tuple component. Every gap shape survives the
deprecation.

**THREE FRAMINGS, none ruled:**
1. **Deprecate the LITERAL bracket only** — keeps `v[i]`. But the bracket form
   still exists, so the reader's `adjacent-to-base?` mint stays and little is
   actually simplified.
2. **Deprecate the whole bracket postfix** — loses dynamic indexing until some
   spelling replaces it. Non-monotone against a live capability.
3. **Leave it, file the redundancy** — the display already normalizes, and 0
   corpus sites means nothing is confused by it today.

**Placement**: OUT of the P4e line. It touches the reader's adjacency mint,
nowhere near the selection twins, and it wants its own slice with its own
verify. Sequenced in D4 §5.P4e-1b-sequencing as explicitly outside.

### 118. ⬜ ⭐ AN ω STEP WITH A *SYMBOL* INNER, INSIDE A SELECT BLOCK, ASSEMBLES A NARROWED ROW INSTEAD OF EXTRACTING THE FIELD — `x{k:s}` ≡ `x{k:{s}}` at zero errors, and the bands disagree

Found by the same verify. **PRE-EXISTING.** Directly contradicts
[Q_U20](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u20) as written ~60 lines above
the offending call. The PATH band extracts correctly (`x.k:s`), the BLOCK band
does not, so the two bands disagree on a shape C2 has just made live.

⚠ **IT MAKES A C2 PIN GREEN FOR THE WRONG REASON, and that is why it is filed
loud.** The pin asserting `rows{k:s*}` "STAYS REFUSED — its join is nominal"
reasons that *"the layer is the ω's vector whose ELEMENTS are Maps"*. Those
elements are Maps **only because the block-band ω failed to extract**. When this
entry is fixed the layer becomes `[PVec [PVec Int]]`, the star joins, and the pin
flips — a pin that will break on an unrelated CORRECT fix, having been read as
evidence that the nominal case is properly shielded. Whoever fixes this must
re-read that pin rather than repair it.

---

### 119. ⬜ A CARET IMMEDIATELY BEFORE A STAR IS A GUIDED REFUSAL AT THE BRANCH HEAD BUT IS SILENTLY SWALLOWED AT DEPTH ≥ 2

Same verify; **PRE-EXISTING** (parser.rkt untouched by C2), flagged because C2 is
what makes deep stars the thing users write. At depth ≥ 2 the `*` is absorbed
into the field name, producing a misleading "field not present" error whose
echoed branch **carries no star at all** — so the diagnostic hides the operator
the user actually wrote.

---

### 120. ⬜ A `def` WHOSE NAME COLLIDES WITH A PRELUDE CONSTRUCTOR IS ACCEPTED AGAINST *ANY* ANNOTATION AT ZERO ERRORS

Same verify, unrelated to the star; filed as a **probe-hygiene trap**. It looks
exactly like a type-soundness hole in whatever slice is under test, and it cost
the verifier a cycle. Recorded so the next one does not pay it again.

---

### 121. ⬜ ⚠ **THE DIAGNOSIS BELOW IS WRONG — SEE [122](#deferred-122).** `p4e1`'s STRING PATH FAILS TO BIND A SUBJECT THAT `process-file` BINDS FINE — recorded as a LEVEL-2 vs LEVEL-3 harness divergence; it is PROCESS-STATE POLLUTION

> ⚠⚠ **CORRECTED 2026-08-12 by C2 verify round 2 (`wf_87b2134b-d05`).** The
> entry below, the code comment at the parked pin, and the commit message that
> shipped them all record this as a Level-2-vs-Level-3 harness divergence. **It
> is not**, and the part that is wrong is the part that matters: the identical
> string through the identical `process-string-ws` binds fine **in a clean
> process**. It is not a property of the string path at all — it is process-state
> pollution keyed on the subject NAME (`s`+single digit). Filed as
> [DEFERRED 122](#deferred-122).
> **Consequence, and it is why this correction is urgent**: as written, this entry
> sends the next session to widen the harness, which cannot fix it. And the parked
> pin — the regression pin for round 1's *headline* BLOCKING defect — is
> unblockable TODAY by renaming its subject off the `s`+digit shape. It has been
> sitting un-pinned for a recorded reason that does not hold.
> *(Original framing retained below for the record.)*

Found at C2 verify round 1 while pinning the duplicate-key fix. The subject
`def s7 := {:a {:b {:c @[1 2]}} :b @[9]}` binds under `process-file` (probe
verified, the dup error fires correctly) but under the battery's `p4e1` string
helpers the NEXT command reports `Unbound variable s7`.

**Consequence, and it is the reason this is filed rather than shrugged at**: a
verified fix for a BLOCKING silent-wrong-answer is parked commented instead of
pinned, because its pin cannot run. An unpinned fix is how that defect shipped in
the first place. The class is `testing.md` § "Three-level WS validation" — the
Level-2/Level-3 gap — appearing in the instrument rather than in the language.

**What is owed**: either find the p4e1 subject shape that binds (and unpark the
pin at `test-path-selection.rkt`'s "a star NESTED in a sub-block is visible to
the dup gate"), or give the case an acceptance-file row instead.

<a id="deferred-122"></a>

### 122. ⬜ ⭐ A PARSE-LEVEL STATE LEAK SILENTLY DROPS `def s0|s1|s7 := …` AND BLAMES AN ANGLE-BRACKET ERROR ON A LINE CONTAINING NEITHER `<` NOR `*` — and it is what PARKED round 1's headline regression pin

Found by CIU T6 D4.P4e-1b-iii-C2 **verify round 2** (`wf_87b2134b-d05`),
adjudicator-confirmed by its own re-run. **Supersedes
[DEFERRED 121](#121)'s recorded diagnosis**, which named a Level-2/Level-3
harness divergence — measured, that is false: the identical string through the
identical `process-string-ws` binds fine **in a clean process**.

**WHAT IS MEASURED**: in a process that has already run the track's test module,
`def s7 := 1` (and `s0`, `s1`, …) is silently DROPPED, and the reported error is
the angle-group parser's product-type message — on a line containing neither `<`
nor `*`. `def a := …` / `def w := …` are unaffected. The discriminator is the
subject NAME: `s` followed by a single digit.

⚠ **THE MECHANISM IS NOT LOCATED, and that is recorded rather than guessed.**
The emit site is the `$postfix-star` arm of the angle-group parser
(`parser.rkt`, the "ANGLE-GENERIC on purpose" arm), so reaching it for
`(def s7 := 1)` means the parser entered an angle group for a datum containing
none. The READER is exonerated — `read-all-forms-string` is byte-identical in
both states. Ruled out: `tools/star-arrival-matrix.rkt`, `tests/test-support.rkt`,
and the two angle+star sources in the battery. Candidate class: a module-level
mutable global rather than a parameter (`parse-reader.rkt`'s
`token-pattern-registry` is one such and is not reset between
`process-string-ws` calls) — **not confirmed**.

**WHY IT IS MORE THAN A HARNESS WART, and the escalation that was not tested**:
a silently dropped definition meets the letter of BLOCKING. It is filed here at
MAJOR only because it was demonstrated in a process that had first run the test
module, and no single-file `process-file` route was found. ⚠ **The long-lived
processes are the obvious escalation and were NOT tested** — `lsp/server.rkt` and
`repl.rkt`. If either reproduces it, this is BLOCKING.

**⭐ THE INSTRUMENT HAZARD IS THE SHARPER HALF.** Under the leak a pin's two
checks disagree: a `check-false (p4e1-type …)` PASSES *vacuously* — the type is
`#f` because the command errored, not because the branch was refused — while only
the positive `check-true` catches anything. **A pin written with only the negative
half is green for the wrong reason.** This track has already paid for exactly this
class once (`p4e1-has?` was "VACUOUS, AND SYSTEMICALLY SO", fixed by being made
deliberately loud); it is back through a different door, and every negative pin
whose subject is named `s0`–`s9` is a candidate.

**WHAT IS OWED**: (1) find the mutation — it is parse-level, post-reader, and
keys on `s`+digit; (2) **un-park the dup pin, which is the regression pin for
round 1's headline BLOCKING defect** — verified, a one-character rename of its
subject unblocks it today; (3) correct the code comment at the parked pin, which
repeats 121's wrong diagnosis; (4) probe the LSP/REPL routes.

---

### 123. ⬜ ⭐ `select-fail`'s `path` CARRIES NAMES, NOT STEPS — so every label built from it COLLAPSES DISTINCT BRANCHES, and that is what blocks the star tail-arm's narrow label

Found by CIU T6 D4.P4e-1b-iii-C2 **verify round 2**, while fixing the third of
the round's diagnostic majors. The obvious fix was written, MEASURED, and
REVERTED — this entry exists so the next session does not re-attempt it blind.

**THE SURFACE DEFECT** (round 2's owed major (a)): `select-below-field`'s
star-TAIL arm holds only `(sₙ ★)`, so its label echoes the last two steps of a
branch the user wrote in full. MEASURED: `y2{a.b[0]*}` reports ``0*``. Its
sibling seat `star-branch-entries` labels from the whole branch `b`, so
**diagnostic quality depends on which seat caught the failure**.

**THE FIX THAT LOOKS FREE, AND WHY IT IS NOT.** `path` IS the consumed prefix —
measured `(a b)` for `y2{a.b[0]*}`, `(a)` for `y{a[0]*}`, `()` at top level, so
`(append path steps)` does not double-count — and it renders the right branch:
``a.b.0*``. ⛔ **But `path` stores bare NAMES, dropping the cont suffix, so
distinct branches collapse onto one label.** Measured under the candidate fix,
three DIFFERENT branches all reported ``a.b.0*``:

```
y3{a^.b[0]*}   ⟹  `a.b.0*`
y3{a.b[0]*}    ⟹  `a.b.0*`
y3{a^r.b[0]*}  ⟹  `a.b.0*`
```

In a multi-branch block that **names a sibling branch as the failing one**. A
label that identifies too little is better than one that identifies the wrong
thing, so the change was reverted and the narrow label kept.

**⭐ THE LOSSINESS IS SYSTEMIC, NOT LOCAL — this is the half that makes it worth
an entry.** `format-select-fail`'s `branch-str`
(`(string-join (map (lambda (p) (format "~a" p)) path) ".")`, typing-errors.rkt)
already renders `path` dot-joined for **every other fail kind**, so it carries
the same collapse today, for kinds far outside the star work.

⚠⚠ **CORRECTED BY VERIFY ROUND 3 ON TWO POINTS — this entry shipped wrong about
its own subject, twice.**

1. **IT IS LIVE, NOT A LATENT QUALITY RISK.** This entry originally said "nobody
   has measured which of those messages can name the wrong branch". Measured
   now: the `subject-other` kind does exactly that. `rec3{a.b a^r.b.zzz}` (on
   `{:a {:b @[@[1 2]]}}`) reports ``select: `zzz` (branch `a.b`)`` — and
   `rec3{a.b}` alone succeeds, so **the branch the message names is a valid
   sibling that did not fail**. Three distinct branches (`a^r.b.zzz`,
   `a.b.zzz`, `a^.b.zzz`) all render the same label.
2. **THERE IS A SECOND COLLAPSE CHANNEL, and the original diagnosis named only
   the first.** It is not just that `path` drops the cont suffix: the ω /
   broadcast marker is dropped too. `rowz{k:s.zzz}` renders ``(branch `k.s`)``,
   and `rowz{k.s.zzz}` proves `k.s` is not merely a different spelling — it
   fails one step EARLIER, so the label names a branch that could not have
   produced this error.

**THE REPAIR**: make `path` carry STEPS rather than names — **24** `append path`
sites in typing-core.rkt (some already append the step, e.g. the ordinal arm;
others the name, e.g. the bcast arms), plus `branch-str`, plus `pp-select-branch`.
Then both the tail arm's label and `branch-str` can render faithfully. Its own
slice; **do not do it inside a star slice**.

⚠ **AND THE SCOPE ABOVE ORIGINALLY CHARGED FOR A "REDUCTION TWIN" THAT DOES NOT
EXIST** (round 3, #9). Measured: `reduction.rkt` has **0** `append path` sites
and **0** `select-fail` sites; its four walks (`level-entries`, `branch-entries`,
`below-components`, `below-value`) take no `path` parameter at all, and its star
failures are `expr-panic` values carrying fixed strings with no branch label.
Reduction has **no seat in this repair**. The stale clause read as a
co-migration obligation of the kind `pipeline.md` makes ATOMIC, so a future
session would either hunt for a reduction-side `path` and find nothing, or ADD
one believing a twin was owed. ⭐ It survived a full verify round because **pins
assert kinds and code, never prose** — the same class F5 was landed to fix.

⚠ **A SECOND, SMALLER RESIDUAL, recorded so it is not mistaken for this one**:
`pp-select-branch` renders every `ord-step` as `.N`, so even a faithful label
would spell `y{a[0]*}`'s branch as `a.0*`. That is [DEFERRED 113](#113)'s class
(a renderer hardcoding `.`), not this one.

---

### 124. ⬜ `*_` IS STRUCTURALLY UNSPELLABLE AT THE CLOSER-ADJACENT SEAT — `x{a b}*_` lexes as `*` applied to `_`, so that seat's guided not-yet can never fire from the surface

Found by the CIU T6 D4.P4e-1b-iv adversarial verify (`wf_0df64e7f-231`).
**Pre-existing lexing** — untouched by 1b-iv — but it is recorded now because the
upcoming `*_` slice will otherwise assume a coverage the surface cannot deliver.

**MEASURED**: `mn{a*_}` reaches the intended guided refusal (the FUSED-identifier
band works). `mn{a b}*` is a live spelling. `mn{a b}*_` does NOT reach the `*_`
path at all.

⚠⚠ **THE MECHANISM ABOVE WAS WRONG — CORRECTED 2026-08-13 by the 1b-v grounding
audit and re-verified on the main thread.** This entry said `*_` after a closer
"lexes as `*` applied to `_`". It does not: it lexes as **ONE symbol token
`*_`**. `*` is `ident-start?` and `_`, `-`, `*` are ALL `ident-continue?`, so
`recognize-symbol` swallows the whole run — the lexeme `"*"` that the mint gate
tests for never exists as a separate token. Measured through `tokenize-string`:
`"x{a b}*_ "` → `(symbol *_)`, `"x{a b}*- "` → `(symbol *-)`. Confirmed by a
second route: `mn{a}* _` (SPACED) gives *"Could not infer type"* — the star DOES
mint and a lone `_` lands in argument position — while `mn{a}*_` gives
*"Unbound variable"*. If the glued form were `*` applied to `_` the two would be
identical.
⭐ **The conclusion stands and the FIX gets cheaper**: relaxing the gate's
exact-lexeme test is SUFFICIENT: no token-splitting is required. ⚠ But the gate
is a FOUR-part conjunction (lexeme · not-in-mixfix · non-empty output · a
byte-adjacent predecessor whose type is a group closer), and the parser's
`$postfix-star` arm additionally HARDCODES `'flatten` in both legs, never calling
`split-star-lexeme` — so it is a TWO-SITE change. See [Q_U52](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u52).

**WHY IT MATTERS FOR THE NEXT SLICE**: `*_`'s guard in `star-join-type` is
reachable only from the fused band. Any claim that `*_` is "refused everywhere"
is therefore untestable at the closer-adjacent seat — the seat that produced the
`'path` regression 1b-iv-B2 self-caught, and the one whose landing Q_U49 made
sort-sensitive. ⚠ [Q_U39](#q-u39) already defers the closer-adjacent `*_` MINT;
this entry is the narrower fact that the seat cannot even be probed today.

**OPTIONS**: teach the reader to split `*_` after a closer as it does after an
identifier (which is Q_U39's mint, so it belongs with that ruling), or record
explicitly in the `*_` slice that the closer-adjacent seat is out of scope and
its guard is unexercised-by-construction.


---

### 125. ⬜ ⭐ `.*_` AND `.*-` ARE ALREADY OWNED BY THE RETIRED-BROADCAST RECOGNIZER — so Q_U26's ravel and the star's continuation grammar are on a collision course at the CHARACTER level

Found by the CIU T6 D4.P4e-1b slice 1b-v grounding audit's completeness critic
(`wf_cc1a72a0-75b`), by enumerating the hazard surface by CHARACTER after the
facets had enumerated it by sentinel NAME.

**MEASURED**:
```
rv.*   ⟹ ERROR: Unbound variable
rv.*_  ⟹ ERROR: broadcast `.*_` was retired — its replacement is `:_` (e.g. `xs:_`)
rv.*-  ⟹ ERROR: broadcast `.*-` was retired — its replacement is `:-` (e.g. `xs:-`)
```
`recognize-broadcast-access` (parse-reader.rkt) matches `.` `*` then any
`ident-continue?` char — and `_` and `-` ARE `ident-continue?`. So it consumes
`.*_` and `.*-` and reads them as `.*` plus a field named `_` / `-`.

**WHY IT MATTERS**: [Q_U26](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u26) rules
RAVEL to be bare `.*`. If the star's continuation grammar is `{"" _ - -_}` — as
[Q_U48](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u48) and
[Q_U51](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u51) imply — then `.*_` is
ravel-with-synth, and today it emits a message about a feature retired for
entirely unrelated reasons. Ravel is itself unimplemented (`rv.*` is
`Unbound variable`), so nothing is broken **yet**; the collision lands whenever
P4e-2 implements ravel or 1b-vi mints `*-`.

**OWED**: decide who owns `.*_` / `.*-` before either lands. Not 1b-v's — 1b-v
touches the closer-adjacent band only ([Q_U52](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u52)).

---

### 126. ⬜ THE ANGLE BAND IS A FOURTH CARRIER OF DEFERRED 124's DEGRADATION — a glued `*_` inside `<…>` silently loses Q_U31's guided Sigma refusal

Found by the same critic run. DEFERRED 124 names three carriers; this is a
fourth, and it is in a different grammar.

**MEASURED**:
```
def pr : <(x : Nat)* Nat>   ⟹ ERROR: inside `<…>`, `*` needs a SPACE before it — glued to a
                               closing bracket, `*` is the path-selection flatten operator…
def qr : <(x : Nat)*_ Nat>  ⟹ ERROR: Unbound variable
```
`unwrap-angle-type` (parser.rkt) switches on the `$postfix-star` sentinel, so a
spelling that never mints reaches it as an ordinary symbol and the Q_U31 refusal
does not fire. ⚠ Its WS-mode twin `tree-parser.rkt`'s Sigma detector keys on the
LEXEME `"*"` instead of the sentinel — a twin-drift pair worth moving together.

**OWED**: when the mint widens, this arm must recognize the new sentinel or the
guided refusal silently narrows. In scope for 1b-v's census, filed separately
because the *fix* is the same edit and the *risk* is that it is forgotten.

---

### 127. ✅ **DISCHARGED — repair in `tools/star-arrival-matrix.rkt` since 1b-v-A; containment PINNED at `24fc1be4` (C-9)** ⭐⭐ `tools/star-arrival-matrix.rkt` CANNOT DISTINGUISH "CORRECTLY DOES NOT MINT" FROM "I CANNOT SEE THIS TOKEN" — and after a reader widening it reports FULL COVERAGE of a question it has stopped asking

Found by the same critic run. This is the instrument built specifically because
D4 §5.P4e-1's reach claim needed evidence, so its blindness is load-bearing.

**TWO INDEPENDENT DEFECTS, both verified:**
1. `star-last-token-type` gates on `(string=? (token-entry-lexeme (car ts)) "*")`
   — the SAME exact-lexeme shape as the mint it exists to verify. A source whose
   only star token is `*_` leaves `found` at `#f`, so `star-mints?` answers "does
   not mint".
2. **The carrier table hardcodes a bare `*` in ALL 11 minting sources** (`"c{a}*"`,
   `"xs:{a}*"`, `"@[1 2]*"`, …). So a widened reader is measured at 190/190 cells
   covered and **0 cells for the new spelling**, with nothing in the run saying so.

⭐ **THE CONTROLS ARE THE SHARPER HALF.** The three non-minting controls satisfy
"must be 0" because `star-last-token-type` returns `#f` when there is no `*`
token *at all*. A new `*_` control would pass for the identical reason — i.e. the
instrument's pass and its blindness are the same observation. That is the vacuous-
pin class this track has already paid for twice, in the one artifact whose job is
to prevent it.

**OWED**: widen both the gate and the carrier table in the same commit as any
reader mint, and give the controls a POSITIVE assertion (the token was seen AND
did not mint) so blindness cannot read as success.

⚠ **RELATED RE-BASELINE, not a bug**: the DEFERRED-108 abort snapshot pins 19
whole-file-aborting cells as a SET compared whole. A reader widening changes which
sources abort, so it will turn red and needs a deliberate re-baseline. It will
look like a regression.

---

### 128. ⬜ ⭐⭐ Q_U42 AND Q_U50 ARE IN TENSION AND HEAD IMPLEMENTS Q_U50 — a same-key VECTOR collision under ω refuses where Q_U42 rules it concatenates

Found by CIU T6 D4.P4e-1b slice **1b-v-A**, by RUNNING the pre-written Q_U42 pin
block before touching it rather than reading it. Both of Q_U42's worked examples
diverge, not just one.

**MEASURED at HEAD** (`53df2b4d`):
```
rowsv := @[{:tags @[1 2]} {:tags @[3]}]     ⟹ [PVec {:tags [PVec Int]}]   (homogeneous)
rowsv:{tags}*   ⟹ ERROR: … cannot join Map-valued contents under `:` (broadcast) …
                   [Q_U42 rules {:tags @[1 2 3]}]
dcomp := @[{:a {:t @[1]}} {:a {:t @[2]}}]
dcomp:{a}*      ⟹ ERROR: … same star-omega-nominal refusal …
                   [Q_U42 rules {:a {:t @[1 2]}}]
rowsv:tags*     ⟹ @[1 2 3]                  ← the DESCENT twin matches its ruling
```

**THE TENSION.** [Q_U42](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u42) rules that
when the keywise join recurses into a shared key whose two values are VECTORS it
**concatenates** — its argument being that the top-level rule already says vectors
concatenate, and one operator must not say the opposite one level down.
[Q_U50](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u50) rules that a **homogeneous
`PVec`** under ω refuses on POSSIBILITY, because one element type stands for every
element — "the same keys N times, N unknown". `rowsv` is homogeneous, so it lands
in Q_U50's refusal and Q_U42's promise at once.

**⭐ A PLAUSIBLE RESOLUTION, NOT RULED**: Q_U50's argument turns on a collision
**dropping** something, and concatenating N vectors is **total for any N** — the
unknown length is not a problem for concat. So the possibility-refusal arguably
should fire only where the colliding values would drop, i.e. NOT on Q_U42's
population. That would make Q_U50 refuse Map-valued and leaf-valued collisions
under ω while letting vector-valued ones through, which is exactly Q_U42's "one
recursive rule at every depth".

**WHY IT IS FILED RATHER THAN RULED HERE**: Q_U42 is unimplemented, its
implementation is in no current slice, and this is a ruling question for the
owner — not something 1b-v should decide in passing. ⚠ **The pin block stays
PARKED and must NOT be "fixed" to match HEAD**, which would encode the opposite
of a ruling. The parked block carries this note.

⚠ Q_U50's record says "NO CODE CHANGE" and lists one owed message improvement; it
did not consider Q_U42's population. That is how two rulings agreed separately and
disagreed jointly.

---

### 129. ✅ **DISCHARGED `940c9c88`** ⭐ THE READER'S SENTINEL EMIT IS SPELLING-BLIND — `token-entry->stx` maps the token TYPE to a hardcoded `'$postfix-star` and never consults the lexeme, so B2b's mint has a wrong-answer route B1's ordering argument does not cover

> **FIXED at `940c9c88`** (slice 1b-v-B2b, per [Q_U53](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u53)):
> the emit is `(postfix-star-lexeme->sentinel lexeme)` — the SAME call the widened
> gate makes on the SAME entry, so the miss-case is unreachable by construction.
> No fallback, no raise. ⭐ Mutation-tested in the exact shape this entry
> describes: emit hardcoded back with the gate widened gives `*_` →
> `$postfix-star` (gate still minting), and the battery's [Q_U53 canary] emit
> half goes red on it while the gate half stays green.

Found by the CIU T6 D4.P4e-1b slice 1b-v adversarial verify (`wf_fc98d241-4e5`,
survivor S12). **Not a defect at HEAD** — it is a precondition B2b must satisfy,
recorded because B1's commit message argues the ordering removes exactly this
hazard and the argument has a gap.

**THE FACT** (verified): `token-entry->stx` (parse-reader.rkt) has ONE sentinel
emit, `[(postfix-star) '$postfix-star]`, keyed on the token TYPE. The mint gate in
`disambiguate-tokens` types a token via an exact-lexeme test and sets
`(seteq 'postfix-star)` for ALL spellings it accepts. So the LEXEME is available
at the emit site and is not read.

**WHY IT MATTERS AT B2b**: B1 landed the cont channel first precisely so that
widening the reader could not make `x{a b}*_` silently MEAN `x{a b}*`. That
argument covers the PARSER arm. It does not cover the EMIT: if B2b widens only
the gate's lexeme test and leaves the emit hardcoded, every widened spelling
still emits `$postfix-star`, whose cont is `'flatten` — reproducing the exact
wrong answer by a different route.
**WHAT B2b MUST DO**: emit via `postfix-star-lexeme->sentinel` (reader-forms.rkt,
landed at B1 and currently with NO production consumer — that absence is the
signal). ⚠ Keep ONE token type: `parse-reader.rkt`'s compat remap keys on
`postfix-star`, and splitting the type would need that site too.

⚠⚠ **THAT PARENTHETICAL UNDER-COUNTS BY 18 — corrected 2026-08-13 (the B2b
grounding `wf_7f5bda0c-500`, R-lens-verified).** Sites keyed on the bare
`postfix-star` TOKEN TYPE: **3 production** (parse-reader.rkt:2089 the mint, :2341
the compat remap, :2590 the emit) · **2 TOOL** (`tools/star-arrival-matrix.rkt:193`,
`:217`) · **14 battery rows** (tests/test-path-selection.rkt). ⭐ **The two TOOL
sites are the ones that bite**: [DEFERRED 127](#127) widened that instrument's
LEXEME test to `star-spellings` and left its TYPE test bare, so splitting the
token type would silently re-blind the mint verifier — reinstating exactly the
defect 127 repaired, in the instrument whose job is verifying this mint. The
"keep ONE token type" advice STANDS; only its cost estimate was wrong.

⭐ **RULED as [Q_U53](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u53)**: the emit's
miss-case is not given a behaviour — it is made UNREACHABLE by widening the gate's
lexeme conjunct to EXACT table membership, so gate and emit ask one question of one
datum. A bare `#f`, a fallback, and a raise are each disqualified independently
(the raise is uncatchable — `parse-reader.rkt` has zero `with-handlers`).

---

### 140. ✅ FIXED — `let` bound only the first name in two shapes; bracket at `c809c5d0`, aligned block at TSG T2 P1+P2 (LET_OPEN/LET_ALIGN scanner tokens)

Filed 2026-08-15 from an owner report (`foray.prologos:136-137`: "`x` is coloured
as a parameter, but `z` is not"). Measured by rendered FACE, which is what the
user actually sees:

| `let` shape | binds? |
|---|---|
| sibling chain (`let y 4` / `let z 5`) | ✅ both |
| nested shorthand (`let y 4` / indented `let z 5`) | ✅ both |
| ~~aligned block~~ (`let y 4` / `    z 5`) | ✅ **FIXED — TSG T2** |
| ~~bracket form~~ (`let [y 4 z 5]`) | ✅ **FIXED `c809c5d0`** |

Both broken shapes are **documented canonical syntax** in
`.claude/rules/prologos-syntax.md` — the aligned block is called "the canonical
multi-binding layout" — and both compile at **0 errors** (probe: `let y [+ 2 2]`
/ `    z [+ y y]` / `  * z z` → `64 : Int`). So the grammar is wrong relative to
the compiler, per the standing rule.

**Diagnosis**: `let_binding` is `seq(name, optional(':='), value, optional(newline))`
and `value` is a full `$.expression`. It is GREEDY. In the bracket form
`let [y 4 z 5]` it takes `4 z 5` as ONE application, yielding a single binding —
which is why the bracket form fails even though `let_expr` already spells
`seq('[', repeat1($.let_binding), ']')`. The aligned form fails the same way,
with the continuation line read as the BODY.

**Why it is not a one-liner**: the two shapes need different value grammars. In
brackets a value is exactly one datum (flat name/value pairs); in the layout form
it runs to end-of-line and may continue on deeper-indented lines. Separating
"next aligned binding" from "the body" is column knowledge the LR state does not
have — the scanner-token recipe in `.claude/rules/tree-sitter-grammar.md`.

**Not urgent**: it is a missing colour on binding sites, not a mis-parse — 0
ERROR nodes in the aligned form. The sibling-chain and nested spellings are
unaffected and are what most code uses.

---

#### ✅ BRACKET HALF FIXED — `c809c5d0` (2026-08-15)

A separate bracket rule whose value is exactly one datum
(`path_expr | grouped_expr | paren_expr | atom`), aliased to `let_binding` so
the node type the queries match stays one name. `application` is deliberately
excluded: juxtaposition is precisely what must not cross a binding boundary.

⭐ **This entry UNDER-RECORDED the defect.** With `:=` spelled out —
`let [y := 4 z := 5]`, which the compiler accepts at 0 errors — the same greed
produced an **ERROR node**, not merely a missing binding. All four bracket
spellings (plain · `:=` · `y : Int := 4` · grouped value) now bind every name at
0 errors, pinned by `test/corpus/let_bracket.txt`.

⚠ **The trap, caught by the per-file A/B on its first real use**: including
`angle_group` in the value choice regressed `sample.prologos` **M0 → M1 with
ERROR unchanged**, so a netted total would have read as a pure win. In
`(let [x <Nat> (inc zero)]` the parser then took `x` as a bare name and `<Nat>`
as its VALUE, stranding `(inc zero)`. **An angle group after a binder name is
that binder's TYPE, never its value.** Pinned by a corpus test.

#### ⬜ ALIGNED HALF — what it actually costs

Measured, not estimated. The failing parse is one `let_binding` whose value is a
single `application` spanning lines 1–3: it swallows the second binding **and**
the body.

The discriminator is a COLUMN — `.claude/rules/prologos-syntax.md` defines the
body as sitting strictly between the `let` column and the binding column — and
the LR state does not have it. Per the contested-shape recipe this is scanner
work, and specifically:

1. a zero-width token emitted just after `let`, to CAPTURE the first binding's
   column (the scanner cannot otherwise know it);
2. a second zero-width token separating "next aligned binding" from "the body",
   valid only after a complete layout binding;
3. a per-`let` column **stack** in `Scanner` (lets nest), plus the matching
   change to `serialize`/`deserialize` — the existing `indent_stack` shows the
   shape but the format is offset-versioned, so adding a field is a format
   change.

That is the same size as the three contested-shape tokens already in the
scanner, each of which the rules file records as needing "a DESIGN, not a better
rule". It is not a follow-on to the bracket fix.

**Design phase OPEN**: `2026-08-15_0705_LET_ALIGNED_BLOCK.md` (TSG Track 2).
⭐ Its P0 is already ✅ and it is the part worth reading: the grammar-only
route was **built twice and measured**, not waved away. Both formulations make
the aligned block work and both regress the shapes they were not about —
the sibling chain gains an ERROR and the nested form binds the literal `let`
**as a name**. Nested and aligned are the same token sequence and differ only
in indent DEPTH relative to the first binding's column, which is precisely what
the LR state lacks.

---

### 130. ✅ **DISCHARGED `940c9c88`** THE PARSER'S TWO STAR REFUSAL MESSAGES HARDCODE `*` WHILE B1 FAMILY-IZED THE THREE ECHO SEATS — one seat, not its sibling, inside a single commit

> **FIXED at `940c9c88`** (rode with 1b-v-B2b): both arms —
> `unwrap-angle-type`'s glued-star refusal and `parse-datum`'s star arm — render
> `postfix-star-sentinel-lexeme` of the sentinel they matched. The bare-`*` text
> is BYTE-IDENTICAL to before (its pins did not move); for any other member the
> guidance is derived from the RULING ([Q_U31]: only a spaced bare `*` is a
> product) rather than from the `*` example — and the multiplication clause,
> a fact about `*` alone, renders for `*` alone.

Found by the same verify (survivor S13). B1 made `unmint-star-for-echo` and both
quote lowerings render the lexeme the USER WROTE, and left the two REFUSAL
messages — `unwrap-angle-type`'s glued-star arm and `parse-datum`'s star arm
(parser.rkt) — hardcoding `*` in their prose.

**Latent today**: both arms now RECOGNIZE the family (B1 rewired their
predicates), but the only spelling that reaches them is `*`, because the reader
mints only that. **At B2b it becomes live**: a glued `*_` inside `<…>` will take
Q_U31's refusal and be told about `*`.

**Cheap, and it belongs with B2b** — the lexeme is already available via
`postfix-star-sentinel-lexeme`.

---

### 131. ⬜ `star-dup-key`'s "dropping the `*` does not help either" IS MEASURABLY FALSE, and `*_` gives it a second population

Found by the same verify (survivor S14). The clause reads: *"If the key was
lifted, dropping the `*` does not help either: it re-nests the layer under the
key the star was deleting."*

**MEASURED FALSE** — the verify's own run shows the remedy applied to the very
expression the message was complaining about, working:
```
… duplicate output key `:a-x` … dropping the `*` does not help either …
{:a {:x 1}, :a-x 9} : {:a {:x Int} :a-x Int}      ← that exact remedy, applied
```
The clause over-generalises from the case where the re-nested key COLLIDES with
the sibling to the case where it does not.

⚠ **This is the THIRD wrong remedy found in this message family** (the round-2
`star-dup-key` rewrite and the round-3 `star-l4-mixed` rewrite were the first
two), and the pattern is the same each time: a remedy derived from the one
example in front of the author. See the standing lesson — **derive the message
from the RULING, and RUN every remedy it names**.

---

### 132. ⬜ `join-contents`' `keys` parameter keeps a silent `#f` DEFAULT, so a future third call site inherits Q_U41's positional refusal by OMISSION

Found by the same verify (survivor S16). `(define (join-contents contents [keys #f]) …)`
in `star-join-type`. B2a's own comment five lines above states the invariant —
"the absence of keys IS [Q_U41]'s refusal condition … the two call sites below
each say which they are" — and the signature un-states it by defaulting.

Both existing call sites pass explicitly (one of them passes `#f` deliberately,
with a comment saying so). A third would silently get the positional refusal.
**Fix**: make the parameter required. Trivial; filed rather than done because it
is a shape change to a function under active edit in this slice.

⚠ Filed together with **129–131** from one verify run; the run's full survivor
set (16, of which 12 are addressed at `b12d02ed` and `cb555002`) is in the
workflow transcript at
`.claude/projects/…/subagents/workflows/wf_fc98d241-4e5/journal.jsonl`.

---

### 138. ⬜ ⭐ THE `.org` → `.md` EXPORT PIPELINE STOPPED, AND 7 OF 13 TWINS ARE SUBSTANTIALLY STALE — three of them may hold content that a regeneration would DESTROY

Found by the **EHP T1.close doc-truth sweep** (2026-08-14). Started as one file
and the entry's own "check the other twins" instruction found a systemic problem.

**The `.org` is canonical and the `.md` is a generated artifact** (`workflow.md`).
The export stopped running at different times for different files:

| twin | `.org` | `.md` | .org last | .md last |
|---|---|---|---|---|
| `DEVELOPMENT_LESSONS` | **2005** | **367** | 2026-08-15 | **2026-02-25** |
| `DESIGN_METHODOLOGY` | **1921** | **708** | 2026-07-25 | 2026-03-24 |
| `DESIGN_PRINCIPLES` | **1168** | **602** | 2026-05-17 | 2026-03-24 |
| `POST_IMPLEMENTATION_REVIEW` | 608 | 496 | — | — |
| `GÖDEL_COMPLETENESS` | 458 | 332 | — | — |
| `CRITIQUE_METHODOLOGY` | 449 | 349 | — | — |
| `LANGUAGE_VISION` | 471 | 383 | — | — |

`DEVELOPMENT_LESSONS.md` is missing ~1,600 lines and **every lesson promoted
since February**. `DESIGN_METHODOLOGY.md` is missing ~1,200.

⚠⚠ **AND THREE TWINS HAVE A *LARGER* `.md` THAN `.org`** — which is the more
dangerous direction, because it means content was probably added to the
GENERATED file and exists nowhere else. `workflow.md` states the consequence
outright: *"Content added only to `.md` WILL BE LOST on the next org-mode
export."*

| twin | `.md` − `.org` | note |
|---|---|---|
| `PATTERNS_AND_CONVENTIONS` | **+14** | `.org` 2026-04-17, `.md` 2026-02-24 — so the `.md` is BOTH older and larger |
| `RELATIONAL_LANGUAGE_VISION` | **+11** | `.org` 2026-07-25, `.md` 2026-02-25 |
| `ERGONOMICS` | +4 | roughly contemporaneous, likely formatting |

**Diff those three before regenerating anything.** A blanket re-export would
silently delete whatever is only in the `.md`.

⚠ **This is an instance of the lesson it is missing** ([Fail-Open](principles/DEVELOPMENT_LESSONS.org)).
Nothing about a stale `.md` announces staleness. It opens, it renders, it looks
like a document. A reader lands on a February view of the project's methodology
with no signal that a canonical file exists holding five times the content.

**Remedies, all the owner's call:**

1. **Diff the three inverted twins first**, and move any `.md`-only content into
   the `.org`.
2. Then **regenerate** — an org-export operation the owner runs. Do not
   hand-edit a `.md`.
3. Or **delete the `.md` twins** if nothing consumes them. A stale export that
   nobody generates is pure liability.
4. Or **add a generated-artifact header** naming the canonical source, so the
   file at least states its own status.

Not urgent for correctness — every agent-facing rule points at the `.org`, and
`CLAUDE.md` names the `.org` as canonical. The exposure is a human opening the
`.md` directly, and the `.md`-only content in remedy 1.

---

### 137. ⬜ ⭐ THE PSEUDO-KEYWORD LIST IS PAINTED BY NAME, UNCONDITIONALLY — so `def solve := 1` paints `solve` as a KEYWORD, and the words are CONTEXTUAL, not promotable wholesale

**REWRITTEN 2026-08-14** after measuring. It was filed as "should these become
grammar tokens?" — the measurement answers **no**, and finds a live mispaint
underneath it.

`queries/highlights.scm:57` matches 19 words against `(identifier)` **by name**:
`forall exists solve solver solve-one solve-with explain explain-with rel schema
query expand expand-1 expand-full parse elaborate with-transient transient reduce`.

### Measurement 1 — 18 of 19 bind as ORDINARY VARIABLES at 0 errors

`def solve := 1`, `def query := 2`, `def schema := 3`, `def parse := 5` … all
compile clean. Only **`with-transient`** raises (a genuine preparse form:
*"expected (with-transient coll fn-expr)"*).

**So tokenizing them in the grammar would mis-parse legal code.** Same argument
that keeps `@type.builtin` and `@constant.builtin` name-matched: a word the user
may bind is not syntax the grammar may claim.

### ⚠ Measurement 2 — but binding-ability does NOT prove non-keyword-ness

`reduce` fails to bind, and it **is a real keyword**: `tree-parser.rkt:1430`
gives it the same head-position treatment as `match`, and `surface-syntax.rkt`
carries `surf-reduce` + `reduce-arm` for `reduce scrutinee | ctor bindings ->
body`. It is *also* a prelude trait method (`collection-traits.prologos:60`, and
`reduce + 0 xs` in the syntax rules).

⚠⚠ **METHOD NOTE — this cost a wrong edit, caught before it landed.** The first
pass concluded "`reduce` is not a command" from grepping `parser.rkt` /
`parse-reader.rkt` / `driver.rkt` — **the sexp path**. WS mode goes through
**`tree-parser.rkt`**, which was not grepped, and a deletion of a real keyword
was about to ship. **The authority for "is this a WS keyword" is
`tree-parser.rkt`, not `parser.rkt`.**

### The live consequence

The rule is unconditional, so these words paint as keywords **everywhere**:

```
def solve := 1     'solve' -> font-lock-keyword-face        <- WRONG
def foo   := 1     'foo'   -> font-lock-function-name-face  <- right
```

This is the `[trait x]` hazard the query's own comment documents for the
*anonymous-token* list. The `#match?` list has it too, and the comment does not
cover it.

### The shape of a fix — positional, not promotional

The grammar already models it: `check_form`, `eval_form` and `infer_form` are
explicit rules, so those keywords are tokenized **by position** and the query
matches a node instead of a name. Any of the 19 that are genuine command forms
belong in that shape. That is this entry, correctly scoped — and it is **TSG
work**, gated on 139's audit.

**Not urgent**: cosmetic, and the dialect hazard that prompted the original
filing is separately closed by `parity/check-regexps.sh`.

---

### 139. ⬜ AUDIT THE 19 PSEUDO-KEYWORDS: which are syntax, and in WHICH POSITIONS — the prerequisite for 137

Filed 2026-08-14 by EHP T1.close, when 137's measurement showed the list is
heterogeneous and that a wholesale answer does not exist.

For each of the 19 words at `highlights.scm:57`, establish:

1. **Is it a keyword at all?** ⚠ Check **`tree-parser.rkt`** (the WS path) and
   `surface-syntax.rkt`, not only `parser.rkt` / `parse-reader.rkt`. Grepping the
   sexp path alone produced a wrong answer for `reduce` and nearly shipped a
   deletion of a real keyword.
2. **In which POSITIONS?** `reduce` is a head-position eliminator **and** a
   prelude trait method. `solve` is a command-position adverb **and** a bindable
   name. The answer is a position, not a boolean.
3. **Does a grammar node already exist** for that position, or must one be added
   in the `check_form` / `eval_form` shape?

Known so far, from 137's measurement:

| word | evidence |
|---|---|
| `with-transient` | **genuine preparse form** — raises when bound |
| `reduce` | **genuine keyword** (`tree-parser.rkt:1430`, same as `match`) **and** a prelude trait method |
| the other 17 | bind as ordinary variables at 0 errors; keyword-ness in other positions **unestablished** |

Output: a table of word × position × grammar-node — exactly what 137 needs to
scope its rules. Until then the query keeps matching by name, and the mispaint
137 records stands.



---

<a id="d141"></a>
### 141. ⬜ `match` (and friends?) AS A BINDING VALUE never forms a `match_expr` — the arms leak into the enclosing form, at ONE error

Filed 2026-08-15 from TSG T2's pinned-shape battery. The pin "aligned block with
a multi-line `match` value" failed, and isolation showed the failure has
NOTHING to do with alignment:

```
defn f [a]
  let k : Int := match a       <- `match a` parses as APPLICATION(match, a)
                   | 1 -> 10   <- this arm leaks out as a defn_arm of f
                   | m -> m
    [+ k a]
```

Measured (2026-08-15, post-`c2dedd72` grammar): identical E1 / 0 `match_expr`
with and without an aligned continuation binding; `match` in BODY position
parses fine (E0, 1 `match_expr`). The compiler accepts the annotated form at 0
errors (`prologos-syntax.md` documents it, with the type annotation required),
so the grammar is wrong relative to the compiler.

**Scope note**: probably not `match`-specific — any layout-armed expression in
VALUE position (`match`, possibly `if`/`fio` arms) may share the gap. Census
before fixing.

**Why deferred rather than fixed in TSG T2**: it is upstream of the aligned
block, pre-existing, and the aligned machinery behaves identically on it
(adds no errors, invents nothing). Folding it in would have made the A/B
verdict unattributable.


---

<a id="d142"></a>
### 142. ✅ FIXED (same-day) — the layout map has real grammar structure; keys are `map_key` @property nodes, and the colour override this replaced is RETIRED

Filed 2026-08-15 from the map-key chrome work. The layout form:

```
def business
  :business-info
    :name "JMZI"
    :status :active
```

parses as NESTED APPLICATIONS of keyword atoms — measured:
`((((:business-info :name) "JMZI") :status) :active)`, one spine, E0. The
compiler's `flatten-ws-kv-pairs` preparse gives this real key/value structure;
the tree-sitter grammar has no counterpart, so:

- **No query can tell a KEY from a VALUE** (`:status` vs `:active` — same node
  shape, and glom nesting even destroys head-position as a proxy). Key-specific
  chrome for the layout form is impossible until this lands.
- The tree is silently WRONG (E0) for every consumer — folding, the surfer's
  future node model, and any structural query over records.

The construct is INDENT-shaped (kv lines at a column are siblings; deeper
nests; `-` introduces list items), i.e. the contested-shape recipe again —
scanner + column knowledge, sibling of the aligned-let work (TSG T2). Scope it
as its own TSG track; census `-` list items and inline-brace mixing first.

**CLOSED 2026-08-15, same day** (owner: "address DEFERRED 142 here"). The
compiler census pinned the contract — one entry per line; an entry REQUIRES a
payload (bare `:foo` is a keyword VALUE, `x : Keyword`); `-` items take
sibling entries at the key's column; not legal as a `let` block value — and
the construct turned out NOT to need the aligned-let column stack: the dash's
2-column offset makes every nesting level a real indent-stack level. One
zero-width scanner token (`KV_KEY`, stateless: emitted before a line-leading
keyword iff a payload follows, by lookahead) both settles kv_entry-vs-atom and
SEVERS the application glom, since a value expression cannot absorb a keyword
that arrives behind a token application cannot consume. Keys flow through the
shared @property pipeline in both consumers; the shipped colour override
(custom token + configurationDefaults) was retired in the same commit — the
owner's ruling: an extension must not paint over other people's themes.
Pinned by `test/corpus/layout_map.txt` (5 cases) + the parity fixture.


---

<a id="d143"></a>
### 143. ⬜ SPACED compound param types mis-parse — `name : A -> B` ERRORs at the arrow, `name : List A` silently SPLITS into two params

Filed 2026-08-15 from the golden-regeneration pass: the two `-u`-resistant
tests reduced to this ONE root cause (the nested-match test's arm errors were
cascade damage from its broken param header, not a match defect — the nested
match parses clean with simple params, measured).

Compiler-verified VALID at 0 errors:

```
defn map2 {A B} [f : A -> B, xs : List A] : List B     -- types correctly
defn filter2 {A} [pred : A -> Bool, xs : List A] : ...  -- types correctly
```

Grammar today: `_param_type` is ATOMIC (grouped/angle/identifier) per
DEFERRED 134, whose bound was measured correct for the FUSED form — but the
spaced form was collateral: `A -> B` leaves the arrow homeless (ERROR) and
`List A` becomes `xs : List` plus a BARE PARAM `A` at E0 — the silent-split
shape 134's own comment documents for fused, now on syntax the compiler
ACCEPTS.

**Design note for the fix**: 134's greed argument does not transfer wholesale.
The fused bound exists because `[p1:Point p2:Point]` has no delimiter between
a type and the next name; the SPACED form is delimited by `,` and `]`, so a
spaced `typed_param` could admit a wider type rule than a fused one. Bound the
two separately.

**Census alongside**: bare-param `fn` (`[fn a body]`) — the compiler parses it
(fails only in typing for unrelated reasons); the grammar has no rule. Decide
whether it is documented syntax before arming it.

**Pins**: `test/corpus/implicit_params.txt` "Defn with implicit type
parameters" and `test/corpus/nested_match.txt` "Nested match in match arm
body", both marked `:skip` with this entry as the reason — un-skip them when
this lands; they are the acceptance tests.

---

### 144. ⬜ THE TREE-SITTER GRAMMAR'S `flatten_step` IS A BARE `*` — the star-continuation family (`*_` LIVE at 1b-v-B2b; `*-`/`*-_` at 1b-vi) mis-parses at the CLOSER seat in the editor

Found by the grammar-drift tripwire firing on `940c9c88` (CIU T6 slice
1b-v-B2b), which is exactly what it exists for.

**2026-10-14 — THE FAMILY IS NOW FINAL** (CIU T6 1b-vi-D-2b, `9743e93e` on
`ciu6-path-selection`; the tripwire fired again, as expected): the compiler mints
all four — `*`, `*_`, `*-`, `*-_` — closer-adjacent and fused. The `*->` boundary is
decided ([Q_U56](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u56)): not a construct; the
selection consumer refuses it, guided, so the grammar needs no `*->` form either.
The fix shape below is unchanged.

**THE FACT** (verified): `editors/tree-sitter-prologos/grammar.js` has
`flatten_step: $ => token.immediate('*')`. The compiler now mints `*_`
closer-adjacent (`x{a}*_`, `[f x]*_`, `xs:{a}*_`), so the grammar consumes the
`*` and strands the `_` — an ERROR / mis-paint on precisely the syntax B2b
added. ⚠ The FUSED band (`x{a*_ b}`) is fine BY ACCIDENT: the grammar's
identifier regex `[a-zA-Z_][a-zA-Z0-9_!?*+\-']*` admits `*` and `_` mid-name,
the same accident the compiler's `ident-continue?` makes — one identifier token
in both. Only the closer seat is broken.

**WHY FILED, NOT FIXED** (the rule: grammar at `X.close`, or a DEFERRED entry
saying why not): CIU T6 still has 1b-v-C, 1b-vi, P4e-2, PF, P5, PX, P6 ahead,
and **1b-vi changes this token AGAIN** — `*-` and `*-_`, plus the `*->` boundary
question [Q_U52](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u52) raised, which is a
grammar question as much as a reader one (`x{a*-> b}`). Doing it once at
X.close, after the family is final, is the fix that survives.

**FIX SHAPE when it lands**: `flatten_step: $ => token.immediate(/\*[-_]*/)` —
a SUPERSET of the family, mirroring the battery's `p4e-star-token-lexeme?` and
the matrix's `star-spellings`, per [Q_U53](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u53)'s
containment rule (an instrument or a grammar that is exactly the mint table
re-blinds itself the moment the table grows) — plus a corpus test. ⚠ Read
MISSING before ERROR when judging it (tree-sitter-grammar.md).

**IT IS MEASURABLE TODAY**: the acceptance file's §L (added at B2b) carries the
closer-seat `*_` forms, and `./check-corpus.sh` scans `examples/` — so the gap
shows up in the corpus gate without anyone remembering it.

(`angle_group`'s `token.immediate('*')` is irrelevant: the compiler refuses a
glued star inside `<…>` per Q_U31, and a grammar that accepts more than the
compiler is the harmless direction.)

---

### 145. ⬜ THE CARET FAMILY CARRIES THE SAME TWO-COPY SHAPE THE STAR FOLD RETIRED — parser literal arms ↔ pretty-print's `cont->string` with a silent `[else "^?"]`, and NO table

Found by the 1b-v-C adversarial verify (`wf_34ba9e6b-dea`). The star family now
has ONE authority (`postfix-star-sentinel-table`, reader-forms.rkt) read by the
reader, the splitter, the printer and `form-deps`. The `^` family
(`^` / `^k` / `^_` / `^-` / `^-_`) has none: `split-caret-lexeme` (parser.rkt)
carries its cont vocabulary as literal arms, and `pretty-print.rkt`'s
`cont->string` — directly above the star arm — re-spells it by hand, with a
SILENT `[else "^?"]` fallback (the star arm's miss now renders LOUDLY).

**Why filed, not fixed at 1b-v-C**: the star fold was scoped to the star arm by
[Q_U54](2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u54); the caret family is
stable (no growth queued), so the drift hazard is latent rather than live.
**When**: with the cont-axis totality work at 1b-vi, or at PF — whichever first
touches `cont->string`. Fix shape: a caret table of the same three-column shape
(sentinel · cont · lexeme), the splitter and printer delegating, a render pin
per row. ⚠ Keep the star and caret tables SEPARATE: [Q_U31]/[Q_U29] rule that a
segment carries at most one operator suffix, and the guards in each splitter
test for the OTHER family's character — two tables, two guards, by design.

### 146. ✅ **DISCHARGED `69f64caf`** (branch `deferred-sweep-146-149`, merged to main in `11f558c8`) — MISATTRIBUTED: stored-key lookups allocate 0 B; the 64 B was Racket CS `equal?` on the probe's freshly built key — ~~`champ-lookup` ALLOCATES 64 B PER READ — a lookup should allocate 0; at ~5 lookups per fire it is ~10 % of a light fire's bytes~~

Found by the PAR 4 Stage-1 allocation census (`census.rkt`, Racket 9.3:
`champ-lookup` any N → **64 B**, 36–55 ns; `net-cell-write` 0/1/8 deps = 481/529/801 B).
Site: [`champ.rkt:120`](../../racket/prologos/champ.rkt) `(define (champ-lookup root hash key)`.
Likely cause: a closure or a boxed intermediate in the descent loop (not yet profiled —
confirm with `(current-memory-use 'cumulative)` deltas around a single call and the
Chez `inspect/object` of the compiled loop). **Why filed**: PAR 4 is a design track; this is a
sequential win independent of it, and the read path is hot under EVERY scheduler.
**When**: any time; 1–2 h. Fix shape: rewrite the descent as a named `let` over
`(node hash shift)` with no captured lambdas; pin with a `rackcheck` property that
`champ-lookup` allocates 0 bytes for N ∈ {16, 256, 4096}. Record: PAR 4 contention
analysis §PSF-2 ([`tracks/PAR/PAR_4/research/…CONTENTION_ANALYSIS.md`](tracks/PAR/PAR_4/research/2026-10-12_PAR_4_STAGE1_CONTENTION_ANALYSIS.md)).

**✅ Closed 2026-10-13, `69f64caf` on `deferred-sweep-146-149`.** Misattributed: the descent allocates
0 B; the 64 B was Racket CS `equal?` on the probe's freshly constructed key. Production census: 76 %
`eq?` hits; the real cost was new-key inserts comparing keys whose hashes already differed (85 % of
CHAMP's `equal?` bytes, 0.04–0.25 % of total allocation). Fixed by comparing the stored hash first at all
six data-entry sites. The model property also found and fixed two latent transient defects (`6d172922`,
`3a152ac9`). Record: `docs/tracking/handoffs/2026-10-13_DEFERRED_SWEEP_146-149_MERGE_NOTE.md` § 146 (branch `deferred-sweep-146-149` @ `8322459b`; merged to main in `11f558c8`).

### 147. ✅ **DISCHARGED `63d8f6af`** (branch `deferred-sweep-146-149`, merged to main in `11f558c8`) — light fire 1 386 → 928 B, RE-ATTRIBUTED (the dominant costs were `parameterize` and the worklist dedup) — THE FIRE PROTOCOL'S CEREMONY — `for/hasheq` output-set per fire (even for single-output propagators) and TWO `champ-fold` closures per slow-path write — ~1.4 KB of the 2.8 KB per read+write fire

Same census: a BSP read-only fire costs **1 386 B / ~570 ns** before any write; a
read+write fire **2 819 B / ~1 500 ns**; breakdown 50 % ceremony, 17 % write, 33 %
re-merge. Sites: [`propagator.rkt:2895`](../../racket/prologos/propagator.rkt) `output-set`
built by `for/hasheq` inside `fire-and-collect-writes` for every fire;
[`propagator.rkt:2041`](../../racket/prologos/propagator.rkt) and `:2053` — two `champ-fold`s
over the dependents CHAMP in `net-cell-write/slow-path`, each allocating a closure per
write; plus `parameterize` ×2 per fire. **Why filed**: PAR 4 H-S removes the whole protocol
(snapshot / output-set / diff / re-merge) for the DIRECT path, so a deep fix here would be
superseded — but the BSP scheduler stays a valid scheduler and these are cheap: a
single-output fast path (`(if (null? (cdr output-cids)) …)` with an `eq?` test instead of
a hasheq), and one fold with the predicate hoisted. **When**: before or alongside PAR 4
P2; A/B with the `PERF-COUNTERS` line, not wall. Success: light fire < 1 KB.

**✅ Closed 2026-10-13, `63d8f6af` on `deferred-sweep-146-149`.** Light fire 1 386 → 928 B (main →
branch; read+write 2 819 → 2 232 B). Re-attributed: the dominant items were `parameterize` ×2 (~496 B) and
the worklist dedup's persistent-set inserts (~362 B), not the `output-set` (32 B). Fixed locally: the dedup uses
a mutable `hasheqv`, `output-set` becomes `memq`, and the dependent folds are merged and skipped with no dependents.
`parameterize` is left to PAR 4 H-S (fire context is ambient state, per the Q1 audit §6). Record: `docs/tracking/handoffs/2026-10-13_DEFERRED_SWEEP_146-149_MERGE_NOTE.md` § 147 (branch `deferred-sweep-146-149` @ `8322459b`; merged to main in `11f558c8`).

### 148. ✅ **DISCHARGED `c62cd267`** (branch `deferred-sweep-146-149`, merged to main in `11f558c8`) — `tagged-cell-value` NEVER DEDUPLICATES ENTRIES — the speculative append and the merge both `cons`/`append` unconditionally, so a cell re-written with the same `(bitmask . value)` grows without bound

Sites: [`decision-cell.rkt:453`](../../racket/prologos/decision-cell.rkt) (speculative write:
`(cons (cons worldview-bitmask new-val) entries)` with no membership test) and `:465`
(merge: `(append (entries new) (entries old))`, no union). Found when the PAR 4
`arena-tagged.rkt` HEAP baseline failed to finish 100 rounds in 300 s: each round
re-appended identical entries, so merge cost grew linearly in rounds and the "heap
baseline" measured the leak, not the lattice (reduced to 3/10 rounds to get numbers).
Semantically harmless today (reads take the most specific entry; duplicates do not
change the value) — **a latent quadratic**, visible on any long-lived speculative cell.
**Why filed**: the PAR 4 flat `'flat-tagged` record dedups on append by construction
(D.1 §6.1), which closes it for flat cells; the heap form still needs it. Fix shape:
membership test on the `(bm . v)` pair at `:453` (entries are short — linear is fine; add
a `rackcheck` property: idempotent re-write leaves `(length entries)` unchanged); at
`:465` a union that keeps "newer first". **When**: 1 h; any time.

**✅ Closed 2026-10-13, `c62cd267` on `deferred-sweep-146-149`.** Set semantics on all
three sites via one helper (`entries-union`); the live site was `make-tagged-merge:492`,
not `:453`/`:465` (no production callers). Pure refinement, pinned by a rackcheck property
against the old append on both reader paths. W2 re-write ×10 000: entries 10 000 → 1.
The PAR 4 heap workload still grows (100 → 84 entries at 100 rounds) because it is an
ascending chain per bitmask, not duplicates — the bitmask-keyed map form is a PAR 4 D.2 decision (placed there by the owner, 2026-10-13; `tracks/PAR/PAR_4/LOG.md` § DEFERRED 148), not a DEFERRED entry.
Record: `docs/tracking/handoffs/2026-10-13_DEFERRED_SWEEP_146-149_MERGE_NOTE.md` § 148 (branch `deferred-sweep-146-149` @ `8322459b`; merged to main in `11f558c8`).

### 149. ✅ **RESOLVED, NO CODE CHANGE — NOT A 9.3 REGRESSION; the 1.35× was main's build (see 159)** — ~~WATCHING — `test-transducer-01.rkt` is reproducibly ~1.35× SLOWER under Racket 9.3 than 9.0 (4.4→6.0 s, 4.3→5.8 s, worktree-pinned interleaved A/B); three other files at parity~~

Measured 2026-10-12 at `7a0116ec` (9.0 brew cask vs 9.3 from racket-lang.org; both
`raco make`d; 4 files × 2 rounds interleaved). Not yet a finding: needs a profile under
both versions (`profile` lib, or `PLT_EXPANDER_TIMES`/`PLT_LINKLET_TIMES`) before a cause
is claimed. Candidates: 9.2's non-linear-pattern checks in `match` (the transducer test is
`match`-heavy), or 9.3's `racket/base` re-layering. **When**: before the next full-suite
timing baseline is recorded under 9.3 (`data/benchmarks/timings.jsonl` ratios are
otherwise noise under load 4–6.5). Record: dailies 2026-10-12 § Watching.

**✅ Closed 2026-10-13: not a 9.3 regression** (sweep branch record; no code change). Matched builds (fresh
worktrees, same commit, same build command, only the binary differs) are at parity on five files (`raco test`
1.005–1.018×; allocation within 0.15 %; same `.pnet` networks). The 1.35× reproduces *exactly* (1.355×)
when 9.3 builds without `PLT_CS_COMPILE_LIMIT`. Main's tree is in that state: 15/15 distinguishable
giant modules match the no-limit build (4 byte-identical), written 10-12 20:24, and they persist through runner
suites because up-to-date `.zo`s never recompile. Profile: 41.8 % in interpreted `match` clause code plus
13.7 % `whnf`/`nf`, against ≤ 2.3 % compiled `match` code under the matched builds. Remedy and prevention:
DEFERRED 159. Record: `docs/tracking/handoffs/2026-10-13_DEFERRED_SWEEP_146-149_MERGE_NOTE.md` § 149 (branch `deferred-sweep-146-149` @ `8322459b`; merged to main in `11f558c8`).

### 150. ⬜ ⭐ THE BSP MERGE SPAWNS ~n GREEN THREADS PER WIDE ROUND BY DEFAULT — `current-tree-reduce-threshold` = 256 routes every round of ≥256 fires through `tree-reduce-fire-results … #t`, which pairs write-sets via `thread` + `channel` at every tree level; on the plain SEQUENTIAL executor that is pure overhead: 4.8–5.3× slower on wide networks

Found by PAR 4 P0 (A/B against the pre-track record). PAR 2 recorded graph colouring 500
at 1.42× (`ce4cde52`, 2026-03-28); it did not reproduce (1.03×). Same machine, same Racket
9.3, interleaved ×2, `bench-parallel-demos.rkt` byte-identical: PAR 2's code 1.55/1.65 ms
sequential vs HEAD 9.51/8.98 ms. `git bisect` (11 steps, bimodal 1.7 vs 9.1 ms) → first bad
commit **`a7b015dd` (2026-04-15) "Phase 2c: semaphore-based worker pool"**, which changed
[`propagator.rkt:2245`](../../racket/prologos/propagator.rkt) `current-tree-reduce-threshold`
from `#f` to `256` (tuned WITH the pool attached; production runs without one). Mechanism:
[`propagator.rkt:3397-3398`](../../racket/prologos/propagator.rkt) passes `parallel? #t`
regardless of executor; `:3149-3152` spawns a green `thread` + `channel` per pair per level
(Racket CS green threads: no parallelism). At HEAD, threshold 256 vs `#f`, interleaved ×2:
graph colouring 500 9.40/9.46 → 1.98/1.96 ms (4.8×); constraint grid 12 9.62/10.91 →
2.02/2.04 (4.8–5.3×); wave chain 1000 4.66/4.70 → 2.53/2.54 (its FIRST round fires all 999
initially-scheduled propagators). Live in production: cold-cache prelude elaboration has
rounds of 216–368 fires. **Fix shape** (owner's call — production default): threshold `#f`,
or gate the tree path on a real pool executor; the green-thread `parallel?` branch can never
win and should be deleted. **When**: before PAR 4 pins its baseline — every PAR 4 A/B is
otherwise credited with removing this defect (P0 record §5 "two baselines"). Record: [`tracks/PAR/PAR_4/2026-10-13_PAR_4_P0_MEASUREMENTS.md`](tracks/PAR/PAR_4/2026-10-13_PAR_4_P0_MEASUREMENTS.md).

*Addendum 2026-10-14 (PAR 4 owner decision O-9 — the fix shape is decided; still open until it lands):*
- **Decision**: production default **off**, and the tree path **deleted** — the green-thread `parallel?` branch,
  the size-switched route (`propagator.rkt:3377` at main `99c893d4`) and the `current-tree-reduce-threshold`
  parameter. It lands in PAR 4 P0.5 (D.1 §14 O-9, [`tracks/PAR/PAR_4/2026-10-12_PAR_4_D1_DESIGN.md`](tracks/PAR/PAR_4/2026-10-12_PAR_4_D1_DESIGN.md)).
- **Read at `99c893d4`**: the tree "reduce" does no lattice work. `merge-fire-results` (`:3090`) only appends
  lists, and the combined result then goes through the same sequential `bulk-merge-writes` (`:2978`). Its one
  semantic change: all of a round's declared writes are applied before any undeclared write (replacement,
  DEFERRED 157), so a round of 256+ fires uses a different application order.
- **Evidence** (P0 record §11, `eb25caee` + `8278a66d`; on main since PAR 4 checkpoint 1, `c1f389ab`):
  - the full suite passes with the default off (10 394 / 502);
  - the 39 prelude caches generated cold under 256, off and 0 are identical;
  - a merge-order census finds 0 tree-order divergences in the suite's 648 rounds of 256+ fires, because no such
    round carries an undeclared write; a constructed two-writer network shows the order changes an answer
    (3 → 1) when the shape does occur;
  - cold prelude elaboration: merge phase 3.03 → 0.020 ms and −7.7 MB per run (its widest round is 368 fires);
  - wide networks: 6.0–7.4× (P0 §10.1).

### 151. ✅ **DISCHARGED** — fix (a) `baa1dce2` (checkpoint 3); fix (b) `08acff4a` (checkpoint 4: the body is fasl, `eab8dcf7`; the reader `tools/pnet-dump.rkt`, `c6f8fff7`) — THE `.pnet` MODULE CACHE WAS A NET LOSS: `pnet-stale?` `read`s every WHOLE file to compare a 2-element header, then the loader reads it AGAIN — 2.6 s per process start, vs 0.53 s elaborating the same 39 modules from source

[`pnet-serialize.rkt:795-806`](../../racket/prologos/pnet-serialize.rkt) `pnet-stale?`
does `(call-with-input-file pnet-path read)` — the full datum, ~0.4–1 MB per module — to
check `(car d)` = version and `(cadr d)` = source key; `deserialize-module-state` (`:905`)
reads it again. Measured (PAR 4 P0, M5 Max, 9.3; same under 9.0, 77.8 vs 76.5 ms/MB): 39
`.pnet` files, 15.7 MB, ONE full read of all = **1 207 ms**; a near-empty prelude-importing
file costs 2 590 ms in `process-file` with the cache (profile: `deserialize-module-state` 46 %,
`pnet-stale?` 45 %) and **526 ms with the cache disabled** — elaboration from source is now
faster than one read of the serialized form (the cache's premise, `driver.rkt:2991` "skip
300ms+ elaboration", is stale). Results identical modulo gensym numbering (4 files diffed).
Batch workers amortize it per worker; every `racket driver.rkt`, `bench-ab` leg, scratch run
and fresh LSP pays it in full. **Fix shape**: (a) immediately: put version+key in a SEPARATE
first datum / sidecar and `read` only that; (b) then decide whether the cache earns its keep
at all (binary `fasl`/`s-exp->fasl` instead of text `read`, or retire it). **When**: any time;
(a) is an hour. Record: [`tracks/PAR/PAR_4/2026-10-13_PAR_4_P0_MEASUREMENTS.md`](tracks/PAR/PAR_4/2026-10-13_PAR_4_P0_MEASUREMENTS.md).

*Addendum 2026-10-13 (DEFERRED 149 sweep):* a module's `.pnet` bytes depend on how its dependencies were
loaded. `transducer.pnet` written over source-elaborated dependencies is 747 783 B; written over
`.pnet`-loaded ones it is 384 910 B. All 12 registries have equal counts after import with either file. So
"identical modulo gensym numbering" holds only for files written the same way, and part of the 15.7 MB is
dependencies' entries repeated. That bears on fix (b), and on any cache keyed or checked by content hash.

**Status 2026-10-13 — fix (a) merged to main in `baa1dce2` (checkpoint 3; branch `per-process-152-151` @ `7358c7c4`).**
`PNET_VERSION` 10 → 11: a file is `(pnet-header VERSION KEY)` + body (old slots 2–30, unchanged); `pnet-stale?`
reads only the header (an old single-datum file is stale from its first 13 bytes); the loader reads once. Staleness
judgement unchanged (`pnet-header-fresh?`, `pnet-serialize.rkt:223`). Measured by the stream (record below): the
stale-check read of all 40 files 1 291–1 375 → 1 ms; warm load phase (driver + prelude) CPU 2 690–2 760 → 1 540–1 550 ms,
1 307 → 838 MB. **Warm still loses to cold and to no cache**: the loader's one text `read` is 1.24–1.32 s for
16.9 MB. **Data for (b)**: the same bodies as `fasl` are 9.5 MB and read in 53–56 ms; that a fasl body makes a warm
load beat no-cache (≈ 310 ms inferred) is a CONJECTURE, not measured end to end — measuring it is the next step
(decision SW-22). Tests: `tests/test-pnet-header.rkt` (12). Every checkout's cache regenerates once. Record:
`docs/tracking/handoffs/2026-10-13_PER_PROCESS_152_151_NOTE.md`.

**Fix (b) measured end to end, 2026-10-13 (owner decision SW-22).** Branch `deferred-151b-pnet-fasl` (off main
`2792123c`): `eab8dcf7` makes the BODY fasl and keeps the header text (`PNET_VERSION` 11 → 12; `pnet-stale?` unchanged);
`9713a1a5` is the record ([`handoffs/2026-10-13_PNET_FASL_151B_DATA/README.md`](handoffs/2026-10-13_PNET_FASL_151B_DATA/README.md)).
- **Same data**: bodies 40/40 equal to v11 modulo root path; strings and vectors come back immutable (text `read`
  made them mutable), and no production code mutates one (every `vector-set!` site is on a local `make-vector`;
  CHAMP/RRB values are rebuilt on load). Full suite on v12: 10 350 / 497, all pass.
- **Load phase, CPU ms median** (ABBA ×4, under the exclusive suite lock, load 12–16): warm **1 450 → 285**
  (5.1×), below no-cache (530 / 546, the control), so the cache now PAYS (1.9×); cold 1 028 → 732; 809 → 405 MB.
  The ≈ 310 ms conjecture above holds (285 measured). Suite wall, one ABAB pair: 15.8 / 16.9 → 13.4 / 13.5 s.
- **Decided (owner, SW-22): merge as fix (b)** — merged in checkpoint 4, `08acff4a`. Retiring the cache would have
  forgone the 1.9×. The cost, a `.pnet` no longer readable as text, is met by `tools/pnet-dump.rkt` (owner request
  SW-23, `c6f8fff7`): summary with the loader's verdict and its reason, `--slot`, `--text` (read-back-able); it
  reads with `pnet-serialize.rkt`'s own readers and `PNET-BODY-SLOTS`, which the writer now checks its body against.
- **Correction.** This entry said fasl's format "follows the Racket version". That was the pre-6.90 documentation:
  since Racket 6.90.0.21 the encoding is version-independent (Racket reference §13.10). A Racket upgrade still
  regenerates every cache, because it rebuilds `driver_rkt.zo` (`infrastructure-stale?`), not because of fasl; and
  the loader's read sits inside an `exn?` handler, so an unreadable body falls back to source.
- **Measured since**: the 9.5 MB vs 4.5 MB fasl sizes are string sharing — fasl writes each distinct string object
  once; in memory the bodies' 42 267 strings are 1 703 objects, text `read` makes 42 241 (99.9 % of the gap). The
  fasl reader returns the shared objects, immutable, which is what makes sharing them safe.

### 152. ✅ **DISCHARGED `0e5da30f`** (branch `per-process-152-151`, merged to main in `baa1dce2`; the runner opts back in with `--memory-stats`, `e3efb2dc`) — `process-file` FORCES TWO MAJOR GCs PER CALL — `measure-memory-before`/`-after` call `(collect-garbage 'major)` unconditionally (~45 ms per file; the largest single cost of a 60 ms run)

[`performance-counters.rkt:403-416`](../../racket/prologos/performance-counters.rkt). Found by
PAR 4 P0 profiling (preloaded prelude, 10 reps): `measure-memory-before` + `-after` ≈ 33 %
of samples on every comparative file; `gc_ms` ≈ 56–60 ms per file regardless of work. It
inflates every `process-file` measurement (bench-ab, PHASE-TIMINGS shares) and every LSP
re-elaboration. **Fix shape**: only when a MEMORY-STATS consumer is active (a parameter, or
the driver CLI flag), never in library calls. **When**: any time. Record: [`tracks/PAR/PAR_4/2026-10-13_PAR_4_P0_MEASUREMENTS.md`](tracks/PAR/PAR_4/2026-10-13_PAR_4_P0_MEASUREMENTS.md).

**Status 2026-10-13 — discharged (checkpoint 3).** `measure-memory-before`/`-after` (`performance-counters.rkt:433`/`:443`)
collect only when `memory-stats-enabled?` (`:425`): `current-memory-stats?`, `PROLOGOS_MEMORY_STATS` (anything but
`""`/`"0"`, read per call), or `racket driver.rkt --memory-stats`. Off → no MEMORY-STATS line (omitted, not marked).
Measured by the stream, test phase, base → fix (ABBA n=4; CPU / GC ms / major GCs): `test-transducer-01`
1 276 / 1 067 / 36 → 208 / 14 / 0. Coordinator check: `raco test test-transducer-01` 4.43/4.58 → 1.91/1.88 s wall
(ABAB, load 7–11; the ratio is the evidence). Tests: `tests/test-memory-stats.rkt` (6). **The runner** keeps the
`memory` field only on request (owner decision SW-12, option C): `--memory-stats` (`e3efb2dc`); checked both ways —
off: no field, 1.7 s; on: `{gc_ms, mem_before/after/retained_bytes}`, 2.9 s. Restart the LSP server to get the fix there.

### 153. ⬜ `benchmarks/comparative/parity-adversarial.prologos` CRASHES AT HEAD — the DFS solver's `solve: Depth limit exceeded (100)` escapes `process-file` uncaught; `bench-ab` has been timing a crash for this file

Reproduced on the pristine main checkout at `7a0116ec` (`racket driver.rkt …`) and in the
PAR 4 P0 harness. Two defects: (a) the depth-limit error is not converted to a per-command
`prologos-error` (contrast POL.9's conversion for unknown relations, `relations.rkt:3080`);
(b) the benchmark's query exceeds the DFS depth limit. **When**: before the next comparative
A/B. Record: [`tracks/PAR/PAR_4/2026-10-13_PAR_4_P0_MEASUREMENTS.md`](tracks/PAR/PAR_4/2026-10-13_PAR_4_P0_MEASUREMENTS.md).

### 154. ⬜ THE DETERMINISTIC COUNTERS ARE BLIND TO PROPAGATOR WORK UNDER THE PRODUCTION SCHEDULER — `prop_firings` counts only the sequential drain (`propagator.rkt:2758`), and `perf-inc-prop-alloc!` is NEVER CALLED (`prop_allocs` ≡ 0)

`solve-adversarial` under BSP: `cell_allocs` 4 079, `prop_firings` 0, `prop_allocs` 0. The
`testing.md` rule "prefer the deterministic-work counters over wall for A/B" therefore cannot
see the propagator network at all. **Fix shape**: count fires in `fire-and-collect-writes`
(BSP) as well as the drain; call `perf-inc-prop-alloc!` in `net-add-propagator`; add
`bsp_rounds`. PAR 4 needs these as phase-gate counters (P0 record §6). **When**: with PAR 4 P1
at the latest. Record: [`tracks/PAR/PAR_4/2026-10-13_PAR_4_P0_MEASUREMENTS.md`](tracks/PAR/PAR_4/2026-10-13_PAR_4_P0_MEASUREMENTS.md).

### 155. ✅ **DISCHARGED `51a24f4f`** (SW-25: runs write `data/benchmarks/runs/`; two writers, not one) — RUNNING A MICRO-BENCHMARK DIRTIES THE TREE — `bench-parallel-demos.rkt` rewrites the TRACKED `data/benchmarks/parallel-demo-results.json` (PAR 2's recorded result, `ce4cde52`)

Found when a PAR 4 P0 run overwrote it in the main checkout (restored from HEAD; both
versions kept under the P0 data). A recorded result that any run silently replaces is not a
record. **Fix shape**: write to an untracked `data/benchmarks/runs/<timestamp>-…json`, or
`--output`; keep the committed file as the named baseline. Sweep the other `benchmarks/micro`
writers. **When**: any time. Record: [`tracks/PAR/PAR_4/2026-10-13_PAR_4_P0_MEASUREMENTS.md`](tracks/PAR/PAR_4/2026-10-13_PAR_4_P0_MEASUREMENTS.md).

**Status 2026-10-13 — discharged (SW-25, `51a24f4f`).** The sweep covered every writer of a TRACKED file under
`racket/prologos/data/` (49 tracked files), not just `benchmarks/micro`: **two** writers, not one —
`bench-parallel-demos.rkt` → `parallel-demo-results.json` (this entry) and `tools/parity-test.rkt` →
`parity-baseline.txt` (BSP-LE 2B Phase 0a's baseline, rewritten on every run). Every other mention of a
`data/benchmarks` file in code is a comment or a print. Both now write `data/benchmarks/runs/<name>-<time>.<ext>`
(git-ignored); `--output PATH` re-records a baseline deliberately. Verified: the tracked files byte-identical after
both ran; `runs/` ignored; `--output` honoured.

### 156. ⬜ ⭐ → PPN 4C (owner, SW-26) — ON-NETWORK INFERENCE ACCEPTS ILL-TYPED PRIMITIVE-OP OPERANDS — `[int+ 1 "x"] : Int`, `[f64+ "x" "y"] : Float64`, `[int-lt 1 "x"] : Bool`, `[from-nat "x"] : Int` all type-check

**Found by**: the LSP check-only diagnostics work (2026-10-13) — `[int+ k "x"]` printed as a
stuck term `[int+ 3 "x"] : Int` instead of an error. **The mechanism**: every primitive op
registered through `register-typing-rule!` (`typing-propagators.rkt:2132-2141`
`register-binary-ops!`/`register-unary-ops!`; the Int/Rat/Posit/Float families from `:2192`)
fixes the RETURN type and never constrains the operands. The imperative rule does check them
(`typing-core.rkt:3074`, `(check ctx a (expr-Int))`), but the driver tries
`infer-on-network/err` first and falls back to `infer` only when the network FAILS
(`driver.rkt:791`) — so the operand check runs only when some unrelated child is
network-unhandled: `[f64+ (the Float64 1.0) "x"]` errors (`the` forces the fallback) while
`[f64+ g "x"]` with `g : Float64` does not. **Checking catches it**: under a `spec`,
`defn bad [n] [int+ n "x"]` reports `Type mismatch`. So the hole is infer-mode only —
measured on top-level expressions; unannotated `def`/`let` RHSs presumably share the path
(UNVERIFIED). Both `#:evaluate?` modes agree, so it is static, not a reduction artefact.
**Why filed / severity**: a soundness hole in inference — ill-typed programs are accepted and
reduce to stuck terms; since `process-file #:evaluate? #f`, LSP diagnostics are purely static,
so these programs get NO diagnostic at all. **Fix shape**: the rule must carry an operand
contract — extend `register-typing-rule!` with per-child expected types (homogeneous families:
operand = return type for arithmetic, a separate operand type for comparisons → Bool, `Nat` for
`from-nat`), and have the propagator WRITE the expected type into each child's type cell, so a
mismatch is a contradiction on-network rather than a silently ignored child. Census every
`register-typing-rule!` site with arity > 0 for the same gap. Regression pins: the probe
expressions above must error in both `#:evaluate?` modes; `[int+ 1 2]` stays `Int`.
**When**: soon — it is a correctness gap visible to every editor user.

**Owner decision 2026-10-13 (SW-26): PPN 4C takes this** — it may resolve within that track. Relayed by a note in the
PPN 4C track directory (`tracks/PPN/PPN_4C/2026-10-13_PPN_4C_NOTE_FROM_DEFERRED_SWEEP.md`, on its branch once that
session commits it). Its natural home is the design's §6.4 *Aspect-coverage completion (A3, Phase 6)*
(`tracks/PPN/PPN_4C/2026-04-17_PPN_TRACK4C_DESIGN.md`, "Problem: 76 `register-typing-rule!` entries vs ~326 `expr-*`
structs"). **Caveat, from the mechanism above**: A3 aims to make the `infer/err` fallback reachable only for genuinely
unrepresentable cases, and that fallback is the ONLY path that catches this hole today (`[f64+ (the Float64 1.0) "x"]`
errors because `the` forces it). So 156 resolves inside PPN 4C only if the on-network rules gain an operand contract;
retiring the fallback without one would make it worse (zero cases caught instead of some). The regression pins above
should be in place before A3 retires anything.

### 157. ⬜ ⭐ BSP LOSES UPDATES TODAY: UNDECLARED WRITES BYPASS THE MERGE, AND THE RELATIONAL GUARD RETRACTS THROUGH A LAST-WRITER-WINS CELL — two failing guards in one round clear only ONE worldview bit, whether or not the output is declared

Two defects, measured together (`benchmarks/par4/q1-mechanisms.rkt`, branch `par4-p0`; found
statically by the PAR 4 Q1 audit, then measured):
(a) **Undeclared writes are applied by direct set** — `bulk-merge-writes`
[`propagator.rkt:3018-3045`](../../racket/prologos/propagator.rkt) `struct-copy`s the
whole cell value; it never calls the merge. Two propagators writing one cell undeclared in the
same round: **BSP 2, sequential 6, correct 6** (ior cell, each sets its own bit). Declaring the
outputs fixes this for a join merge (6/6). Sites with `'()` or incomplete outputs:
`relations.rkt:2353` (guard → cell-1), `relations.rkt:2824` (tabling consumer → scope cells),
`metavar-store.rkt:1063` (constraint-retry bridge → constraint store), `bilattice.rkt:167`
(contradiction field).
(b) **The guard retracts by AND-NOT read-modify-write on cell-1**, whose merge
`worldview-cache-merge` is replacement ([`propagator.rkt:960`](../../racket/prologos/propagator.rkt);
[`relations.rkt:2331-2349`](../../racket/prologos/relations.rkt)). Two guards failing in one
round, worldview `0b110`: **BSP 4 (one bit still set), sequential 0** — and **declaring the
output does NOT fix it** (still 4): replacement is not a join, so concurrent retractions lose.
**Fix shape** (measured: 6/6 under both schedulers): retraction as GROWTH — an
*invalidated-bits* cell with `ior` merge, and worldview = committed ∧ ¬invalidated as a derived
read (the two-phase-set construction; Shapiro et al. 2011, CRDTs). Then the guard is monotone
and needs no read-modify-write. Language-level impact — a failed guard's tagged writes staying
visible — is CONJECTURE (not reproduced; the ATMS route is itself incomplete, Rel T1 A.2b).
**When**: before PAR 4 P3 (K > 1 makes the race real at every round), or with BSP-LE 3. Record: [`tracks/PAR/PAR_4/2026-10-13_PAR_4_P0_MEASUREMENTS.md`](tracks/PAR/PAR_4/2026-10-13_PAR_4_P0_MEASUREMENTS.md) §9.

### 158. ⬜ PROPAGATORS INSTALLED INSIDE A FIRE LOSE THEIR FLAGS — the BSP scheduler re-installs them from `(inputs outputs fire-fn)` only, dropping `PROP-FIRE-ONCE`, `#:assumption`, `#:component-paths` and srcloc; a fire-once propagator installed in a fire fires on every input change

[`propagator.rkt:3060-3066`](../../racket/prologos/propagator.rkt) `collect-deferred-propagators`
returns `(list inputs outputs fire-fn)`; `run-to-quiescence-bsp` re-installs with plain
`net-add-propagator` (`:3376`). Measured (`q1-mechanisms.rkt`, T raised 1→2→3): fire-once at
top level under BSP — 2 fires (one unproductive + one productive), C = 1 ✓; **the same
propagator installed inside a fire — 4 fires, C = 3** (fire-once lost). Related, same probe:
the sequential drain does not deduplicate its worklist, so an inline installer enqueued by
both installation and an input write **installs twice** (2 vs 1 under BSP). Production
exposure: fire-once / assumption-tagged installs on the inline (non-topology-request) path,
i.e. when `current-bsp-fire-round?` is `#f` or on the DFS route — not yet enumerated.
~~**Fix shape**: carry the `propagator` struct (flags, assumption, paths, srcloc) through
`fire-result-new-propagators` and re-install it whole.~~ **REVISED 2026-10-13** (owner guidance:
structure created during propagation is a topology change and requires a stratum): the inline
path applies new structure *between rounds of the S0 inner loop* (`propagator.rkt:3372-3377`),
not at the topology stratum, so carrying the flags through would preserve an unstratified
mechanism. **Measured: no production code reaches it under BSP** — a trap that raises on any
in-fire structure (`PAR4_TRAP_MIDRUN=1`, branch `par4-p0`) leaves the full suite green (10 257
tests, 489 files), and fires on the probe's deliberate in-fire install. **Fix shape**: retire the
path — in-fire structure creation becomes an error; discovery goes through a topology request
that carries the whole propagator spec. **When**: PAR 4 P0.5 (before P2: DIRECT has no rounds, so
the path has no defined application point). Record: [`tracks/PAR/PAR_4/2026-10-13_PAR_4_P0_MEASUREMENTS.md`](tracks/PAR/PAR_4/2026-10-13_PAR_4_P0_MEASUREMENTS.md) §9.

### 159. ⬜ ⭐ A `raco make` WITHOUT `PLT_CS_COMPILE_LIMIT` SILENTLY BUILDS THE COMPILER'S GIANT `match` FUNCTIONS INTERPRETED, AND NO GATE NOTICES — main ran that way from 10-12 20:24 to 10-13 02:55 (suite 1.23–1.28× slow, single files up to 25×); remedied in main, prevention open

Found by DEFERRED 149 (record: `docs/tracking/handoffs/2026-10-13_DEFERRED_SWEEP_146-149_MERGE_NOTE.md`
§ 149, branch `deferred-sweep-146-149` @ `8322459b`). At the 9.0→9.3 switch (10-12 20:24) main's
`compiled/` was rebuilt by a `raco make` without the limit. 15 modules (`reduction`, `typing-core`,
`elaborator`, `macros`, `qtt`, `zonk`, `substitution`, `parser`, `pretty-print`, `syntax`,
`surface-syntax`, `parse-reader`, `relations`, `sre-core`, `typing-propagators`) matched a no-limit
9.3 build of identical source, 4 of them byte for byte; none matched a limited build. The runner's `putenv`
(`run-affected-tests.rkt:49-50`) cannot repair this, because `raco make` never recompiles an up-to-date `.zo`. So
the state survived every suite since: the first 9.3 suite, 3 minutes after that build, is the dailies'
130.8 s. The cost lands in individually giant functions (profile: 41.8 % in interpreted `match` clause
code, plus 13.7 % in `whnf`/`nf`). Small nested lambdas stay compiled: 147's per-fire census on main's `propagator`
equals a limited build's within 3 B, so propagator-path bytes are unaffected.

Measured with a worktree A/B at `674ae09b`, 9.3 limited vs no-limit: the full suite went 105.9 / 105.8 → 134.9 / 135.1 s
(1.275×). Per file the median is 1.15× and p75 1.40×; the worst are `test-functor-ws-02` at 25× (0.6 → 15.1 s),
`test-hashable-02` at 12× and `test-firstclass-ops` at 10×. `raco test test-transducer-01` went 4.59 → 6.22 s.

**Remedy APPLIED 2026-10-13 ~02:55** (owner-authorized). Main's 9 `compiled/` dirs under
`racket/prologos` were moved aside to the agent's scratch dir (`rm -rf` is hard-blocked by the agent harness; the
copy is pruned after 24 h idle). They were rebuilt in 19 s with `PLT_CS_COMPILE_LIMIT=1000000 raco make -j 8
driver.rkt lsp/server.rkt tools/run-affected-tests.rkt`, and 8 reference modules are now size-identical to the
limited build. Main, same runner (`fd2986cc`): suite 69.5 s → 56.5 / 57.1 s (1.23×); `raco test
test-transducer-01` 6.10 → 4.53 s. ⚠ An LSP server started before the rebuild still runs the
interpreted code until it is restarted. Suite totals recorded in main between those times
(`data/benchmarks/timings.jsonl`, 2026-10-12T20:27 … 2026-10-13T02:54, which includes the whale-sharding
110.5 → 68 s comparison) carry the penalty. Comparisons within one run keep their direction.

**Prevention: open (a decision).** The defect is that correctness depends on someone remembering an env
var. Two layers:
- **(a)** `tools/hook-guard-racket.sh`, the harness-enforced PreToolUse guard, denies `raco make` without
  `PLT_CS_COMPILE_LIMIT` in the command. This covers agents and subagents, which is the layer that guard exists for,
  but not humans.
  **DONE (checkpoint 3):** `9d24d463` (merged `977c008e`) refuses `raco make|setup`, `raco pkg install|update` and
  `raco test --make` whose environment lacks `PLT_CS_COMPILE_LIMIT` ≥ 1000000, however raco is spelled; it reads
  inline `VAR=…`, `env VAR=…` and an earlier `export` in the same command. Since `eb2a4b72` its deny carries BOTH
  harnesses' fields — Hermes's shell-hook bridge ignored the Claude-only output (`_parse_response` → `None`, an
  allow). **Registered 2026-10-13**, user level, pointing at main's checkout (so the guard in force is main's):
  Claude Code `~/.claude/settings.json` `PreToolUse` `Bash`; Hermes profile `logos-language-designer` `config.yaml`
  `hooks.pre_tool_call` `terminal` — active after the owner's one-time consent (Hermes SKIPS an unapproved hook when
  there is no TTY, as in the desktop app). A guard that fails to parse exits 2: Hermes then blocks (verified in
  `shell_hooks.py:417`), and Claude Code's documented exit-2 contract is a block too (not tested here) — it fails
  closed, loudly. Record: merge note § Checkpoint 3.
- **(b)** The runner, and `bench-lib.rkt`'s single `raco make`, fail fast when a giant module is interpreted,
  using a ~1 ms self-check that times `whnf`/`shift` on a fixed term. Compiled vs interpreted is bimodal (`testing.md:11`
  measured `shift` at ~830×). This covers every entry point through the runner, humans included, and catches the
  state however it arose.

(b) alone keeps the gates honest; (a) stops agents re-creating the state. The measurement that discriminates
for (b) is the self-check's two modes on this machine (limited vs no-limit build) and its false-positive rate
at load ~25. **When**: before PAR 4 pins its baseline.

### 160. 🟡 MITIGATED by SW-27 (`51b6b1f9` + `922f6dd5`: a program's registry state is scoped to its compilation unit) — **OPEN: specs are keyed by BARE name, not by namespace**; the architectural fix belongs to PM Track 12B (free ordering) and PM Track 11 = PPN 8 (incremental) — SUITE-ONLY FAILURES UNDER THE CURRENT RUNNER — a file fails inside `--all` and passes alone; 2 of 3 full runs at `fd2986cc` (`test-cond-01`: `Unbound variable classify`; `test-error-messages`: an annotated `Nat -> Nat` lambda "cannot infer the type of an unannotated parameter")

Found during the DEFERRED 159 remedy: three full suites in main within 6 minutes (load 2–28), before
and after the rebuild, so the build is not the cause.
- **Run 1, before the rebuild:** `test-cond-01` failed at `tests/test-cond-01.rkt:44:2`, `:50:2` and later checks:
  `(unbound-variable-error (srcloc "<ws-string>" 7 6 8) "Unbound variable" 'classify)`, meaning the file's
  `defn classify` (under `(ns c3)`) was not visible to the `eval` that follows it.
- **Run 3, after the rebuild:** `test-error-messages` failed at `tests/test-error-messages.rkt:465:2`, "expected success,
  got: (type-mismatch-error … "cannot infer the type of an unannotated parameter — …" "Nat -> Nat"
  "<could not infer>" "[fn [x <_>] [reduce x | zero -> 1 | suc y -> 2]]")".
- Run alone, they pass 3/3 and 2/2.
- **+1, 2026-10-13 (CIU 6 worktree baseline, `58241c0c`, fresh `ciu6-path-selection` build; `reduction`/`typing-core`/
  `elaborator`/`parser` `.zo` byte-identical to main's):** `test-error-messages` again, the same check (`:465:2`, test-case *"matching clause result
  types still type-check (control, L2)"*) and the same message; 10 289 tests / 492 files, 57.4 s, 18 workers,
  the file completed 81st of 496 units. Alone: 44 tests, all pass. This time the full log was copied before the
  alone-run (`~/.hermes/profiles/logos-language-designer/cache/scratch/ciu6/fail-test-error-messages.log`,
  scratch — pruned after 24 h idle); the runner's stdout does not record which files shared the victim's worker.

The full failure logs are lost: the runner deletes a file's `data/benchmarks/failures/*.log` when a
later run of that file passes, and the alone-runs were those later runs. The excerpts above were read
before them.

**Conjecture** (not established): state leaks between files that share a batch worker. Both symptoms
are "something this file registered or annotated is not seen", which is consistent with a namespace or registry
collision (the tests' namespaces, `c3`/`c4`, are generic). It may be newly *exposed* rather than new: `389b3413`
made LPT dispatch effective (dispatch had been alphabetical), which changes which files share a worker. The last
suites before and at `389b3413` were all-pass, but that is one run each.

**Discriminating measurement**: `--all` ×N recording the worker→file sequence for each failure, then a
replay in one process of that worker's preceding files followed by the victim. **Fix shape** depends on the
leak. Independently, keep failure logs per run id so the evidence survives a passing re-run. **When**: before
the next suite baseline is pinned. A flaky gate makes every "all pass" probabilistic.

**Status 2026-10-13 — the evidence tooling landed (`f6e530d7`); the investigation is still open.**
- **Support (i)**, `1753757d`: failure logs are kept per run in `data/benchmarks/failures/runs/<run-id>/`, never
  edited (newest 20 runs with evidence, plus `failures/latest` and `--failures-run`). A later pass no longer
  destroys the earlier log.
- **Support (ii)**, `6a806d03`: each run records `'workers` (per worker, its units in dispatch order) in its timings
  record and in `runs/<id>/run.json`, including INCOMPLETE runs.
- **First use of (ii)**: the checkpoint gate replayed one worker's 18-unit history in one process and isolated a
  suite-only COUNT change in one step (161's library mechanism, `8014caef`).
- **New evidence on `test-cond-01`** (F3(a) suite, 2026-10-13, branch `deferred-sweep-146-149`): the full message is
  `preparse: spec: defn classify has both a spec and inline type annotations`, then `Unbound variable: classify`.
  That is the cross-file spec-store leak class at the top of this file ("Cross-FILE spec-store leakage within a
  batch worker", 2026-07-31, which names a prime suspect at `test-support.rkt:195`). The earlier sightings recorded
  only the second half. It passed alone 2/2, and in a second full run of the same code.
- **Next**: `--all` ×N under the new runner; for any failure, replay its worker sequence from `run.json` and bisect
  the culprit as for 161. Start from the spec-store suspect.
- **Root-caused for `test-error-messages` (checkpoint 3 gate, 2026-10-13, run `20261013T061739-12431`):** 10 350 /
  497, the only failure `:465:2` again. The run's `'workers` record gave the victim's worker sequence (4th of 40);
  replayed in one batch worker it fails 3/3, and the victim alone passes. **Main's own code fails the same
  replay** (`deferred-sweep-146-149` @ `405f164e` = `01ef2542` + docs), so the checkpoint did not cause it.
  Single-predecessor bisection: **`test-defn-multiarg-patterns.rkt` then `test-error-messages.rkt`** fails; the
  other two predecessors do not. Renaming in a copy of the victim: `ok2` alone → pass, `ok1` alone → fail. The
  predecessor declares `(spec ok2 Nat -> Nat)` in `ns test` (`:286`); the victim's `defn ok2` in `ns t` is checked
  against it. **Mechanism established** — see § *Cross-FILE spec-store leakage* at the top of this file.

**Status 2026-10-13 — mitigated, still open (SW-25 batch; decision SW-27, `51b6b1f9` + `922f6dd5`; see the owner's
note below).** The open question in the
mechanism note — "whether the driver itself (LSP, REPL) has an analogous leak" — was answered first, and it changed the
fix: **the driver leaked too**, so this was a language bug, not only a harness artifact.
- **Mechanism.** Registrations update their parameter by ASSIGNMENT (`register-spec!`, `macros.rkt:498`, and 16+ other
  registries), and `process-file-inner` seeds each file's registry cells from those parameters (`init-*-cells!`).
  `process-file` bound none of them (`load-module` already scoped specs per module, `driver.rkt:3208`), so a top-level
  program's registrations stayed in the process and seeded the next program's cells. test-support's one shared box
  was a second channel.
- **User-visible, measured with no test code** (`process-file` as the LSP calls it): an editor re-check of ONE document
  after the user deleted `spec f` and annotated `f` inline failed "defn f has both a spec and inline type annotations"
  — the deleted spec still applied; and `spec ok2` in `ns test` broke a later `defn ok2` in `ns t` (this entry's
  `test-error-messages` message). `racket driver.rkt a b` loops `process-file` the same way (`driver.rkt:3967`).
- **Fix (SW-27, scope not restore).** `call-with-file-registry-scope` binds every parameter a unit's cells are seeded
  from and every cell id it assigns — 59: 24 registries + 24 cell ids (macros.rkt's ONE ordered list per family, from
  which the batch worker's save/restore are now derived), 3+3 warnings, 2+2 narrowing, the attribute-map id — to the
  caller's current value, and forks the registry network (O(1)). `process-file` runs in it; `#:before-unit-exit` is
  the sanctioned read of a unit's final state (the LSP's per-document spec store; 14 test sites in 4 files, `922f6dd5`,
  which had read it after return). test-support's `run-ns-*` calls are each a unit over a fresh box of the post-prelude
  network.
- **Verified.** Probes red → green on all three channels; the checkpoint-3 pair in ONE batch worker fails 3/3 on
  `e7cda107`, passes 3/3 after; `tests/test-file-unit-isolation.rkt` (5, incl. a class guard: every parameter an
  `init-*-cell(s)!` assigns or seeds from — 59, scanned from source — is in the scope); four mutations red; full suite
  10 385 / 501 all pass, delta exact. Evidence: `handoffs/2026-10-13_SW25_DATA/`.
- **Side effect, intended.** Whether typing runs in persistent or per-command attribute-map mode no longer depends on
  an EARLIER program in the process (it did for LSP REPL evals after any document check, and for `run-ns` calls after
  any `run-ns-ws-file-all` in the same worker).
- **Not covered: LSP REPL sessions** → DEFERRED 171.

**Owner, 2026-10-13 — why this stays open.** SW-27 (each program self-contained) is reasonable for now. Properly
speaking, a `spec` should be **fully qualified to its namespace**: today the spec store is keyed by the bare symbol
(`macros.rkt:490` "symbol → spec-entry"; lookups by `bare-fname`, `elaborator.rkt:385`), so within ONE process unit two
namespaces still share a key space — SW-27 removed the cross-PROGRAM channel, not the cross-NAMESPACE one. A complete
solution falls into the scope of **incremental compilation** (PM Track 11, `MASTER_ROADMAP.org:56`, = PPN Track 8,
`:516`) and **free ordering of modules** (PM Track 12B, `:322`, Stage-0 note
`2026-06-06_PM_TRACK12B_FREE_ORDERING_ON_NETWORK.md`), and may take several tracks' worth of scope. Questions that
design must answer, none measured here: what a spec's key is (FQN, or the namespace it is declared in); how a spec
propagated from an import (`current-propagated-specs`) is named when two imports export the same bare name; and what
replaces per-unit SCOPING once modules are elaborated in free order on one network — the unit boundary SW-27 relies
on is exactly what free ordering dissolves. Until then: SW-27 holds per program, and DEFERRED 171 (REPL sessions) is
the known gap in it.

### 161. ✅ **DISCHARGED `2999a74b` + `8014caef`** (branch `runner-queue-gate`, merged to main in `f6e530d7`) — A FILE THAT RUNS ZERO TESTS IS COUNTED AS A PASS — `test-generators.rkt` reported `PASS (0.0s)` with 0 tests in the first `--all` after a cold rebuild of `compiled/`; the INCOMPLETE check counts units that REPORTED, not units that RAN tests

Found during the DEFERRED 159 remedy. On the first full suite after `compiled/` was rebuilt (test `.zo`s
compiled during the run), `test-generators.rkt` reported status `pass` with `'tests` = 0 and wall 0 ms; the
run recorded "10257 tests … all pass" to `timings.jsonl`. The suite before it and the one after counted the
file's 5 tests, and it passes alone (5 tests). `run-affected-tests.rkt:966-969` defines `all-pass?` as "every
dispatched unit reported, and every status is `"pass"`", so a unit that reports pass after running nothing
passes the gate. The INCOMPLETE fix (`fd2986cc`) closed missing *results*, not empty ones. Why 0 tests ran
is not established. Candidate: a precompile/dispatch race on a cold test tree, seen in 1 of 1 cold runs and
0 of 1 warm ones. **Fix shape**: treat `'tests` = 0 as no-result (INCOMPLETE) unless the file is declared
test-free, or compare against the file's last recorded count. **When**: with 160; both make "all pass" mean
less than it says.

**Status 2026-10-13 — discharged at the checkpoint (`f6e530d7`).**

**Fixed** in `2999a74b`. The gate lives in `tools/suite-plan.rkt` (`gate-verdict` / `gate-incomplete?` /
`gate-all-pass?`).
- A unit that reports PASS with 0 tests is NO RESULT: its progress line says `EMPTY — 0 tests`, the run is INCOMPLETE
  (exit 2), and nothing is recorded.
- The rule applies per unit, so an empty shard is caught too.
- Legitimately empty files are named in ONE auditable list, `TEST-FREE-FILES` (currently `test-multiclause-debug.rkt`,
  `test-p2-debug.rkt`). `tests/test-support.rkt` is no longer a unit (`NON-TEST-MODULES`).
- Pinned by 5 test-cases in `tests/test-suite-plan.rkt`, red against the old rule.

**The cause of the first sighting, found by the checkpoint gate** (`8014caef`). `test-properties.rkt` required
`test-generators.rkt`. A batch worker instantiates a module once, so that file's 5 test-cases ran, and were counted,
inside whichever of the two units the worker reached first. Replayed in one worker with the recorded sequence:
`test-properties` counts 13 alone and 8 after `test-generators`. In the reverse order, `test-generators` reports PASS
with **0** tests, which is this entry's symptom; whether the original run had that order was not recorded, so that
attribution is an inference. Under the new gate the same artefact would have been a **false INCOMPLETE**.
- Fix: the generators moved to `tests/property-generators.rkt`, a library the runner never dispatches.
- Guard: `tests/test-suite-plan.rkt` fails if any `test-*.rkt` requires another one beyond `NON-TEST-MODULES`
  (mutation: restoring the old require turns it red).
- Old records double-counted those 5 tests whenever the two files ran in different workers (18 counted for 13).

**Open**:
1. ✅ **DONE (SW-19)**: `c02d378a` adds the rule to `record-invalid-reason` (generic, no list: over main's 1 936 records
   it matches exactly these 2), and main's `timings.jsonl` is annotated (2 records; only the key added; a second pass
   annotates 0). Was: Main's history holds 2 records with an undeclared 0-test PASS unit (`test-generators.rkt`,
   `test-int-list-quick.rkt`, both `all_pass` true). Annotating them is a decision: SW-5 said annotate, but the
   annotation tool marks only records whose results are fewer than file_count.
   Related, SW-21 (`6e0cc7a8`): `--tests` on a module that is not a test unit (`test-support.rkt`, a library or fixture
   under `tests/`) is refused with exit 64 instead of being run, reported EMPTY and called INCOMPLETE.
2. `test-int-list-quick.rkt`'s 0-test record is NOT explained by the library mechanism: no test file requires it
   (census at `8014caef`).

### 162. ⬜ LPT DISPATCH WAS INERT FROM THE DAY IT SHIPPED — per-file medians keyed by file-name STRINGS in a `for/hasheq`, so 0 of 489 lookups hit, every file sorted as `+inf.0`, and dispatch ran alphabetically — **fix landed `389b3413`**; a comment still states the refuted "impact was NIL" measurement, and the class sweep is open

**Found by**: the whale-sharding work (2026-10-13), from a completion log that ran in alphabetical order. A probe
printed "runner lookup (hasheq, fresh string): +inf.0 / same data, equal?-keyed hash: 96175 / lookups that hit
with a copied key: 0 of 489". `eq?` on strings compares allocations, and a key read from JSON is never `eq?` to
one built from a path. As a result the slowest file, `test-path-selection.rkt`, started ~17 s into the run.

**Fixed** in `389b3413`. The medians moved to `tools/suite-plan.rkt` `historical-medians` (`for/hash`), pinned by
`tests/test-suite-plan.rkt`, which goes red when `for/hasheq` is restored. Suite: 127.6 → 110.5 s. ⚠ Both runs
used 159's interpreted build, so the ratio holds but the absolute seconds do not.

**Open**:
1. **A comment still states the refuted measurement.** `tools/run-affected-tests.rkt:710-713` says "Measured
   impact was NIL (median effective parallelism 8.97 poisoned vs 8.96 clean over 282 runs) — the schedule is not
   what gates this suite." Both legs of that comparison ran the inert sort, so it compared alphabetical order
   with alphabetical order and says nothing about LPT. The same claim is at `standups/2026-07-26_dailies.md:257`;
   that is a dailies LOG and stays as written, with the correction recorded here and at `suite-plan.rkt:16`.
   **Fix**: rewrite the comment to cite this entry.
2. **The class: `eq?`-keyed tables over non-interned keys.** Sweep `racket/prologos/tools/` and `tools/` for
   `hasheq` / `make-hasheq` / `for/hasheq` whose keys are strings, paths or other freshly built data; every such
   lookup misses silently. **Fix shape** per site: `equal?`-keyed tables, or intern (`string->symbol`) at the
   boundary. Add one test per table showing that a lookup with a *copied* key hits; that is the test that
   caught this.
3. **Which files share a worker has changed.** Since `389b3413` the dispatch order, and so the set of files that
   share a batch worker, is different. 160 conjectures that its suite-only failures were newly exposed by this.

**When**: (1) any time; it takes minutes. (2) with 160's investigation, which reads the same tools.

**Status 2026-10-13.** **Open 1** fixed in `36bd4e7d` (merged in `f6e530d7`): the comment now marks "impact NIL" as
REFUTED and cites this entry. **Open 2** (the class sweep) was done on branch `guards-hook-sweep` (`d5359d2a`, NOT
yet merged): `benchmark-tests.rkt`'s regression and variance tables were inert in exactly this way (`make-hasheq`
keyed by file-name strings), fixed with a copied-key test. One latent site, `measure-production-n.rkt:91`, is
interned literals today. The five runner files are clean.
**Checkpoint 3**: open 2 merged in `977c008e`; the latent `measure-production-n.rkt:91` site is fixed
(`make-hash`) in `200bc3d6` (owner decision SW-18). Open 3 stays with 160.

### 163. ⬜ ⭐ EVERY RUNNER START KILLED EVERY BATCH WORKER ON THE MACHINE — Step 0's `pkill -f batch-worker.rkt` was machine-wide, so a run in any session, worktree or clone killed the workers of every concurrent suite — **fix landed `b45bbf44`**; 6 worktrees + 2 clones still carry the old runner

**Found by**: the whale-sharding verification (2026-10-13), observed 3×:
- Main's full suite lost all 18 workers, first after 63 and then after 22 of 493 units, each time seconds after a
  run started in `.claude/worktrees/deferred-sweep-146-149`. A live check found 0 workers alive while the runner
  waited out its timeout.
- In the other direction, that worktree's `--all` killed the 4 workers of a sharded run in main.

Before `fd2986cc`, a run that lost its workers this way printed "all pass" (164).

**Fixed** in `b45bbf44` (`tools/run-affected-tests.rkt:528-550`). An orphan is exactly a worker whose runner died,
which means it has been reparented to PID 1. Cleanup is now `pkill -P 1 -f <this checkout's absolute
tools/batch-worker.rkt>`. Verified live:
- During a run, the old pattern matched 4 workers and the new pattern 0.
- A concurrent targeted run no longer disturbs the long run (5/5 units).
- Positive control: `kill -9` of the runner only → 4 orphans with PPID 1 → the next runner start → 0.

There is no unit test, because this is process-level behaviour.

**Open**:
1. **The bug is still live in every checkout that predates `b45bbf44`.** A runner started in one of them still
   kills main's workers and everyone else's. As of 2026-10-13, found by grepping each checkout's runner for
   `"-P" "1"`:
   - worktrees `charming-khayyam-a7835d`, `dazzling-wescoff-4b692b`, `editor-support-path-change-a3ddf9`
     (detached HEADs), `heuristic-thompson-a2091b` (branch `clever-bhabha-f3a408`), `par4-p0`,
     `sleepy-kepler-8aa2cb`;
   - clones `~/dev/projects/prologos-egraph-spike` and `~/dev/projects/prologos-preduce-auto`.

   `deferred-sweep-146-149` already has the fix. **Fix**: bring each live checkout to main ≥ `b45bbf44` (merge,
   rebase or cherry-pick the one hunk); which route is each branch owner's decision. Do `par4-p0` first, since
   PAR 4 pins baselines; retire dead worktrees.

   **Status 2026-10-13 (owner-authorized, from the sweep session):** `par4-p0` → `a456c370`, a merge of main.
   Gate: 10 298 / 493 all pass, with an exact file-by-file delta (merge note § Coordination). The five dormant worktrees
   were **removed**. Each had its HEAD in main's history, no tracked changes, no untracked files, and no process,
   and was idle 8–9 weeks; their ignored files were editor undo histories, an older (Racket 9.0) `settings.json` and
   VS Code build output. Their two merged branches were deleted (`git branch -d`). **Still open: the two clones only.**
   Both hold commits and records that are not on main (`egraph-relational-spike`: 12 commits, the spike's closing
   note; `preduce-autonomy`: 62 commits, the loop's ledger and retro), so they wait on an owner decision.
   **Owner decision 2026-10-13: keep both clones as-is for now.** Their runners still carry the machine-wide
   form (`run-affected-tests.rkt:529-530`, `"-f" "batch-worker.rkt"`) and take no suite lock; every nested
   worktree has the scoped form (main `:723-727`).
2. ✅ **DONE (checkpoint 3).** Guard `e9b2a30e` (merged `977c008e`): a `pkill`/`killall` whose pattern can reach a
   racket process is refused unless parent-scoped. `8b113a9f` (owner decision SW-16) closes the indirect forms —
   a `pgrep` in a command that also kills is judged as the `pkill` it amounts to (co-occurrence over-approximates
   pipe / `$(…)` / variable / file dataflow), `ps | grep PAT | … kill`, `-v`, `kill -1`, and `"$(…)"` inside quotes;
   145 rows, 9 mutations all red. `53e6de98` narrows the allow-list to `Bash(pkill -P:*)` (decision SW-17).
   Registered as in 159 (a). Was: **Agents can still do it by hand.** `.claude/settings.local.json:71` allows `Bash(pkill:*)` without a prompt,
   and a `pkill -f racket` or `pkill -f batch-worker` from any session has the same blast radius. **Fix shape**
   (a decision): either `tools/hook-guard-racket.sh` (159's PreToolUse guard) denies a
   `pkill`/`killall` pattern that matches racket or batch-worker without `-P`, or the allow-list is narrowed.
3. **Is Step 0 needed at all?** From reading the code, not from a measurement: a worker exits at stdin EOF
   (`batch-worker.rkt:182-183`), and its stdin closes when its runner dies. So an orphan should live only until
   its current file ends, which is bounded by `--file-timeout` (the runner passes its `--timeout`, default
   300 s). Measure this first.
   - If it holds, Step 0 is only a speed-up and can go, removing the last kill from the runner.
   - If it does not, a worker-side parent watchdog is the structural form: a worker knows its own runner, but a
     runner cannot know another runner's workers.
4. **Past timeouts can't be attributed.** Every "TIMEOUT: No result received" in any session before `b45bbf44`
   may have been another session's runner start rather than the change under test. 164 counts the recorded ones.

**When**: (1) now, because it is live in 8 checkouts. (2) and (3) with (1).

### 164. ✅ **DISCHARGED — open items 1–5 fixed on branch `runner-queue-gate`, merged to main in `f6e530d7`** — AN INCOMPLETE RUN REPORTED "ALL PASS" AND WAS RECORDED AS A FULL SUITE — the no-result TIMEOUT path killed the workers and fell through with `bailed?` unset, and `all-pass?` was an `andmap` over only the results that DID arrive — **fix landed `fd2986cc`**; 13 such records sit in main's `timings.jsonl`, and sibling fail-opens are open

**Found by**: the whale-sharding work (2026-10-13). After 63 of 493 units (the workers had been killed by 163) the
runner printed "1629 tests in 343.6s (490 files, …, all pass)" and appended a 63-result record to
`timings.jsonl` as a full run. That record was removed by hand; the file is untracked.

**Fixed** in `fd2986cc` (`tools/run-affected-tests.rkt:966-969` plus the summary, record and exit sites after it).
A run with fewer results than dispatched units now prints `INCOMPLETE — n of N units reported`, exits 2 and
records nothing. Verified two ways:
- with a scratch test file that `(exit 0)`s its worker: "INCOMPLETE — 1 of 2 units reported", exit 2, no record;
- in the wild, on a run that reported 22 of 493 units.

**Measured: the history is polluted.** In main's `racket/prologos/data/benchmarks/timings.jsonl`, 13 of 971
full-suite records (`file_count` ≥ 300) say `all_pass: true` with fewer results than files. Every one ran to the
timeout wall or past it:
- 2026-03-18 … 03-26: 9 records with **0 results** (0/372 … 0/382), wall ≈ 600 s, which is "all pass" over no
  tests at all;
- 2026-07-14 `64529290` 279/453; 07-17 `09f002e0` 25/455; 07-24 `94f7da34` 80/470; 07-31 `cab30b9a` 220/476.

The other checkouts that have a timings file have none: `deferred-sweep-146-149` (1 full record),
`prologos-egraph-spike` (2), `prologos-preduce-auto` (42). The causes are not established; 163 is one candidate
and worker crashes are another. These records have no current effect on scheduling: `historical-medians` reads
the last 5 runs with `file_count` ≥ 100 (`suite-plan.rkt:46-56`), and the newest bad record is from 07-31. Any
longitudinal read of the file does include them (baselines, PIRs, trend tools).

**Open**:
1. **Zero tests still counts as a pass** — that is 161. Together with this entry it makes up the whole
   invariant that "all pass" means what it says: every dispatched unit reported, AND it ran ≥ 1 test.
2. **The re-run guard exits 0 having run nothing** (`tools/run-affected-tests.rkt:307-326`). A refused `--all`
   prints a GUARD banner and `(exit 0)`, so `run --all && git commit`, or an agent that reads only the exit
   status, takes "ran nothing" as green. Observed 2026-10-13: a refused run's exit 0 was briefly read as a
   result. The tradeoff is a decision:
   - a distinct nonzero code is honest, but makes a deliberate refusal look like a failure;
   - keeping exit 0 means the refusal has to be unmistakable everywhere it is read.
3. **The record reader should filter as well.** `historical-medians` should skip any record whose `results` is
   shorter than its `file_count`, so a future fail-open of any kind cannot reach the scheduler. The same
   predicate finds the 13 records. Whether to annotate or drop them is a decision about editing history (the
   file is untracked).
4. **Worker stderr is never drained.** `tools/run-affected-tests.rkt:800-815` opens it and closes it only at EOF.
   Test output cannot reach it, because `batch-worker.rkt:303` captures `current-error-port` around each file.
   Anything written outside that window does reach it (worker-level errors, runtime messages), and past the pipe
   buffer (~64 KB on macOS) the worker would block. Since `fd2986cc` such a block would surface as INCOMPLETE,
   so it is loud, but its cause would be invisible. This is a conjecture; it has never been observed.
   **Fix**: drain stderr in the reader thread into the unit's failure log.
5. **The records misstate their own clock.** `tools/bench-lib.rkt:249` reads `(seconds->date now #t)  ; UTC`, but
   the `#t` argument is `local-time?`, so every `timestamp` ending in `Z` is local time. Checked:
   `(seconds->date 0 #t)` gives hour 17, offset −25200. Anything that reads these as UTC is off by 6–7 h.
   **Fix**: pass `#f`, or drop the `Z`. Old records stay local; whether to mark the cut-over in the record is a
   decision.

**When**: (1) and (3) together, before PAR 4 pins a baseline. (2), (4) and (5) any time.

**Status 2026-10-13 — open items 1–5 fixed (merged in `f6e530d7`); owner decisions SW-4–SW-6 applied.**
- **Open 1** (zero tests): fixed with 161, `2999a74b`.
- **Open 2** (GUARD exit 0): `57a542e2`. A refusal exits **3**, and the banner says "NOTHING WAS RUN". Every exit
  code is in one table, `suite-plan.rkt` § EXIT STATUS: 0 / 1 / 2 / 3, plus 75 for a busy suite lock under `--no-wait`.
- **Open 3** (reader filter): `fa6437fc`. `historical-medians` skips records whose results are fewer than file_count,
  or that carry `"invalid"`. The records are annotated, not dropped, by `tools/annotate-invalid-timings.rkt`, which is
  idempotent, atomic and holds the suite lock. On a copy of main's file it marks **24**: the 13 full-suite
  `all_pass` ones counted here, 9 full-suite failing ones and 2 smaller runs. Main's own file: see the checkpoint
  record.
- **Open 4** (stderr): `58dcf0f8`. **The conjecture is measured true, and the effect is worse than lost output.**
  About 240 KB written to a worker's stderr made the old runner report TIMEOUT for a passing file and then hang in
  `subprocess-wait`. Worker stderr is now drained and attributed per unit. `c47c450b` stops the collector waiting
  300 s once every worker has exited.
- **Open 5** (timestamps): `f20220df`. `schema_version` 4 writes the local offset (`…-07:00`); `bench-lib.rkt`
  `parse-record-timestamp` reads both forms (a schema ≤ 3 `Z` is the local clock). Old records stay as written.

### 165. ✅ **DISCHARGED `bd6fddd1`** (branch `runner-queue-gate`, merged to main in `f6e530d7`) — A TARGETED RUN COULD LEAVE THE BATCH WORKER'S OWN DYNAMIC DEPENDENCY STALE, AND EVERY WORKER DIED AT LOAD — `batch-worker.rkt` loads `tests/test-support.rkt` by `dynamic-require`, which `raco make` never follows, and the `--tests` precompile built only driver.rkt and the named files

**Found by** the DEFERRED-sweep session, 2026-10-13, during F3(a): reproduced twice, and again on the runner branch.
After a driver.rkt rebuild, a targeted run whose tests do not require `test-support.rkt` left
`tests/compiled/test-support_rkt.zo` stale. Every worker then died at load with `instantiate-linklet: mismatch …
importing instance: tests/test-support.rkt`. The run printed DEAD WORKERS, 0 tests, ABORTED, and advised
`raco make driver.rkt`, which cannot fix it. Even `raco make tools/batch-worker.rkt` does not reach the stale file,
because the edge is dynamic (deliberately: `batch-worker.rkt` :51-53).

**Fixed** in `bd6fddd1`:
- the edge is declared once, as `suite-plan.rkt` `WORKER-DYNAMIC-MODULES`, and the worker dynamic-requires exactly
  that list;
- `worker-precompile-paths` (batch-worker.rkt plus the list) is built in the production stage by the targeted
  precompile, the full-suite `precompile-modules!` and the `--no-precompile` stale scan;
- 2 test-cases, one a static read of the worker;
- `58dcf0f8`: the dead-worker banner prints the worker's stderr and names the stale module.

**Open**:
1. Every checkout older than `f6e530d7` still has the gap (see 163 open 1 for the list).
2. The full-suite precompile path was verified by reading, not by a repro.

### 166. ✅ **DISCHARGED `c1d4f8f3`** (branch `deferred-sweep-146-149`; reaches main at the next checkpoint) — THE SUITE QUEUE CAN BE BYPASSED SILENTLY — an inherited `PROLOGOS_SUITE_LOCK` makes a run queue on a private lock file, and nothing on screen says so; also, the lock is not held by the workers a runner spawns

**Found by** the coordinator at the checkpoint (`f6e530d7`), on the queue's first real use. A targeted `--no-wait` run went
ahead while a full suite held the machine lock exclusively. The cause was in the shell: `PROLOGOS_SUITE_LOCK` was set
to the runner agent's private test path, having leaked from a subagent's terminal session into the coordinator's
persistent shell. With the variable unset, the same run was refused correctly: exit 75, with the holder named (pid,
mode, since, checkout, command). Raw locks on the real file were held throughout, so the lock itself is sound.

**Fix shape**: print the lock path and mode in every run's header, with a ⚠ line when `PROLOGOS_SUITE_LOCK` overrides
the default. Possibly accept the override only together with an explicit flag (a decision); the tests set it
deliberately.

**Measured limitation (not a bug; record it in `suite-lock.rkt`'s header)**: children do not inherit the lock.
probe `lock-probe.sh` (+ `lock-inherit.rkt`, `lock-try.rkt`; racket-performance-probing skill `scripts/`): when a lock-holding parent is SIGKILLed, another process can take the lock at once, while
the child it spawned is still running. A SIGKILLed runner therefore frees the queue while its orphaned workers finish
their current unit (they exit at stdin EOF). That is a bounded window of contention, and only after a crash.

**Status 2026-10-13 — discharged (owner decision SW-20: no extra flag).** `suite-lock.rkt` `suite-lock-banner`: every
runner, `bench-ab`, `benchmark-tests` and the annotate tool print `Suite lock: <mode> on <path>`; when
`PROLOGOS_SUITE_LOCK` resolves to a file other than the default, a ⚠ line names both files, and the runner repeats it
under its `N tests in` line. Before: 0 lines about the lock under an inherited override; after: header, ⚠, ⚠.
The measured limitation is recorded in `suite-lock.rkt`'s header. Tests: `test-suite-lock.rkt` (9 checks; two
mutations red).

### 167. ⬜ L1 FUSION FAILS IN BLOCK POSITION — `w4{a:b:c}` errors where the path form `w4.a:b:c` gives `@[1 2]`; zero pins anywhere for an in-block fused ω chain, and the error message is wrong under every reading

**Found by** the CIU 6 1b-vi grounding audit (2026-10-13, branch `ciu6-path-selection` @ `01ef2542` = main), while
working out what "total collapse" (`*-`, D4 Q_U48) would do to a broadcast ancestor. Probe
`docs/tracking/tracks/CIU/CIU_6/research/P4e-1b-vi/probe-1bvi-f.prologos` (on main since the checkpoint merge `83fe4fb4`;
merge; output beside it), run with `tools/scratch-run.sh`:

| input | result |
|---|---|
| `uu.a:0:userName` (path) | `@["L" "J"] : [PVec String]` |
| `uu{a:0:userName}` (block) | ERROR — "broadcast `:userName` fails on every element — … the subject (branch `a.0`) is a tuple (nat-keyed row); a keyed block selects NAMED fields …" |
| `w4.a:b:c` (path) | `@[1 2] : [PVec Int]` |
| `w4{a:b:c}` (block) | ERROR — "broadcast `:c` fails on every element — … field :c is not present in the record {:b {:c Int}}; available fields: :b; in the select branch `a.b.c` …" |
| `w4{a:{b.c}}`, `w4{a:b}` (block) | `{:a @[{:b {:c 1}} {:b {:c 2}}]}` |

(`uu := {:a @[@[{:userName "L"}] @[{:userName "J"}]]}`, `w4 := {:a @[{:b {:c 1}} {:b {:c 2}}]}`.)

**Mechanism — not traced; read from the message only (conjecture).** The second ω step is looked up in the ORIGINAL
element (`:c` in `{:b {:c Int}}`), i.e. the in-block walk does not compose the chain the way the path walk does. The
spec states L1 unconditionally (`docs/research/2026-07-28_path-selection-spec.md` §3.2.2 and §4 L1: `x:f:g` ≡ mapping
the composite). The battery pins L1 three times, all in PATH position (`tests/test-path-selection.rkt` test-cases
"P4c-4c: L1 FUSION is a THEOREM", "P4d-s1: L1 fusion holds across row layers", "P4d-s4a: L1 FUSION as a theorem").
`grep -E '[a-z0-9]+\{[a-z]+:[a-z0-9]+:[a-z0-9]+'` over D4, this file and the battery finds no in-block chain at all.
What a fused in-block chain SHOULD return (per-element projection keeps keys: `{:a @[{:b {:c 1}} …]}`, the same as
`w4{a:{b.c}}`) is itself unstated — a decision, not only a fix. Under any reading the message is wrong: it names a
field `:c` the user never asked of that record, and renders the branch as `a.b.c`, a spelling that means something else.

**Fix shape**: decide the in-block meaning of `x{a:b:c}` (projection along the composite, keyed per element — the
recommended reading, since it agrees with the sub-block spelling `a:{b.c}`), then compose the chain in the block walk
(typing and reduction twins) and pin L1 in block position beside the three path pins. Until then a guided refusal
naming the sub-block spelling is the monotone waypoint.

**When**: before CIU 6 P5 (Ruling B + factoring — L2's normal form assumes L1 holds wherever an ω step can be
written). It also bounds D4 Q_U52 §1's broadcast-ancestor question: inside one branch, the steps after an ω step are
further fused ω steps or a sub-block, so an ω ancestor under a deep star is unobservable until this lands.

> ⚠ **ADDENDUM (2026-10-18, CIU 6 1b-vi verify, branch `ciu6-path-selection` @ `0988a4f0`, on
> main since the checkpoint merge `83fe4fb4`)**: ~~"an ω ancestor under a deep star is unobservable until this lands"~~ **Withdrawn** —
> under a TOTAL collapse it was a **whole-file abort**: `ow{top:cfg.x*-}` (`ow := {:top {:eu {:cfg {:x {:p 1}}} :us
> {:cfg {:x {:p 2}}}}}`) printed no result line at all, not even the `def` above it. Mechanism (read, then measured):
> typing's ω arms hand the steps after `:` straight to `select-below-field`'s star-tail arm, whose C-5 invariant
> `error`ed before the presence check that refuses `*` and `^-` per command. Three verify lenses found it
> independently (D4 §5.P4e-1b-vi `#p4e-1b-vi-verify`, VF-1; probes `research/P4e-1b-vi/verify/v1`, `v2`, `v6`).
> 🟡 **MITIGATED for the collapse families only**: the parser now refuses a total collapse (`*-`, `*-_`, `^-`,
> `^-k'`, `^-_`) under an ω ancestor with THIS entry's waypoint — a guided refusal naming the sub-block spelling
> (`top:{cfg.x*-}`, measured `{:top {:eu {:p 1}, :us {:p 2}}}`). **OPEN, unchanged**: the in-block meaning of a
> fused chain and of a `.` step after ω; every other spelling still gets the misleading message above
> (`ow{top:cfg.x}` → "field :x is not present in the record {:eu …}"); the waypoint can widen to every in-block
> step after ω when this entry's decision is taken.

### 168. ⬜ A STAR GLUED TO AN ARROW IN A TYPE IS SILENTLY NOT AN ARROW — `spec s4 Nat *-> Nat` reports "spec type for s4 has no arrow"; ~~`<(x : Nat)*- Nat>` reports a bare "Type mismatch"~~ **Withdrawn** — `<(x : Nat)*- Nat>` reports a nameless "Unbound variable" (see the correction below)

**Found by** the CIU 6 1b-vi grounding audit (2026-10-13; probe
`docs/tracking/tracks/CIU/CIU_6/research/P4e-1b-vi/probe-1bvi-g.prologos` on branch `ciu6-path-selection`, output beside
it; on main since `83fe4fb4`). Measured at `01ef2542`:

| input (with a matching `defn`) | message |
|---|---|
| `spec s4 Nat *-> Nat` | "preparse: spec: spec type for s4 has no arrow but defn has 1 params" |
| ~~`spec s3 <(x : Nat)*- Nat> -> Nat`~~ | ~~"Type mismatch"~~ — the raw probe-g output, kept as the record; **not evidence about `*-`** (correction below) |
| `spec s2 <(x : Nat)* Nat> -> Nat` (control) | Q_U31's guided "inside `<…>`, `*` needs a SPACE before it …" |

> ⚠ **CORRECTION (2026-10-13, probe `probe-1bvi-o` on branch `ciu6-path-selection`; on main since `83fe4fb4`)**: the "Type mismatch" row came
> from a control that did not isolate the variable. Probe g's SPACED control `spec s1 <(x : Nat) * Nat> -> Nat` with the
> same body (`defn s1 [p] 0`) ALSO prints "Type mismatch", so the body fails against the Sigma spec for its own reason
> and the message says nothing about how `)*-` lexes. Re-measured with bare type expressions, which print `T : Type`:
>
> | input | message |
> |---|---|
> | `<(x : Nat) * Nat>` | `[Sigma Nat Nat] : [Type 0]` |
> | `<(x : Nat)* Nat>` | Q_U31's "needs a SPACE" |
> | `<(x : Nat)*- Nat>` | **"Unbound variable"** — no name |
> | `<(x : Nat) *- Nat>` (spaced) | **"Unbound variable"** — no name |
> | `spec k2 Nat *-> Nat` + `defn k2 [n] n` | "spec type for k2 has no arrow" (confirms the first row with a body that checks) |
>
> So in a type, `*-` (glued or spaced) is read as an identifier and reported by a lookup that does not print the name:
> the same nameless miss the CIU 6 audit found in the closer band (F5, `mn{a}*-`). The 1b-vi prediction below concerns
> only the GLUED form; the spaced form is a plain unbound name and stays one.

**Mechanism (read from the reader's character classes, consistent with the messages):** `-` is an identifier-continue
character and `>` is not, so a star glued to `->` always lexes as `…*-` followed by `>`, never as `*` followed by `->`.
The arrow disappears before the spec parser looks for it, and the message blames a missing arrow. Corpus: 0 glued `*->`
in any `.prologos` file or test, so no program is affected. It is a typo-level diagnostic.

**Why filed separately** (owner decision Q_U56, D4, 2026-10-13: "a guided diagnostic as per (a)"): CIU 6 1b-vi mints `*-`
as an operator and gives a glued `*->` a guided message in SELECTION territory only. The type-territory message
predates the slice and belongs to spec and arrow parsing. One part changes by itself at 1b-vi: once the closer band mints
`*-`, `<(x : Nat)*- Nat>` should reach Q_U37's type-territory refusal and get the same "needs a SPACE" message as
`<(x : Nat)* Nat>` (a prediction, to be pinned in 1b-vi).

**Fix shape**: where the spec/arrow parser finds no arrow, check for a `…*-` lexeme followed by a `>` token and say so
("`*->` reads as `*-` then `>` — put a space before `->`"). Never raise at the reader: a raise there aborts the whole
file. **When**: no gate. Pick it up with the next spec-parser diagnostics work, or at CIU 6 X.close's doc-truth pass if
still open.

> **ADDENDUM (2026-10-18, CIU 6 1b-vi verify finding VM-9; probe `research/P4e-1b-vi/verify/v5` line 16, on main
> since the checkpoint merge `83fe4fb4`)**: a SPACED `*-`, `*-_` or `*_` inside `<…>` reports a bare,
> nameless "Unbound variable" (`<(x : Nat) *- Nat>`), while the glued forms get the guided type-territory text ("inside
> `<…>`, `*-` is a path-selection star operator, not a type operator — it has no type-level reading, glued or spaced.
> …"). The text's "or spaced" is true of the operator, but no spaced spelling ever shows it. **Fix shape**: give a
> spaced star-family symbol inside `<…>` the same guided text, in this entry's (type) territory.

### 169. ✅ **DISCHARGED `8fbaefb8`** (SW-24: the graph is DERIVED, never stored; reaches main at checkpoint 5) — `tools/dep-graph.rkt` WAS THREE MONTHS STALE — `update-deps.rkt --check` exits 1 with 378 mismatches; targeted (affected-test) selection reads this graph

Found 2026-10-13 while adding `tests/test-pnet-dump.rkt` (checkpoint 4). `racket tools/update-deps.rkt --check` on
main's code (branch `deferred-sweep-146-149` @ `61b24b02`): **378 mismatches** — source-deps 82, test-deps 258,
prologos-lib-deps 9, test-prologos-deps 29. By kind: MISSING 227 (151 test files absent from test-deps, 46 source
modules, 23 + 7 prologos entries), MISMATCH 140 (edges changed), EXTRA 11 (entries for files that left). The data was
last regenerated in `2385799d` (2026-07-02). What still works: `--all` runs every test file on disk, and the runner
auto-scans a CHANGED test file that the graph does not list (`dep-graph.rkt:1287-1346`), so new tests are run. What
does not: affected-test selection for a changed SOURCE module follows the stored edges, so a test that reaches the
module only through a missing or changed edge is not selected (not measured how often). Fix shape: `racket
tools/update-deps.rkt --write`, review the diff, and make `--check` part of a gate (pre-commit or the checkpoint
gate) so it cannot drift again. **When**: next runner/tooling batch; before relying on targeted runs to vet a
source change.

**Status 2026-10-13 — discharged by deriving the graph instead of regenerating it (owner decision SW-24: automate,
minimal maintenance).** Tradeoff weighed: a pre-commit `--write` hook keeps a committed generated file that every
parallel branch edits (a merge conflict at every checkpoint) and misses files changed outside a commit; `--check` in a
gate only detects drift. `8fbaefb8` deletes the four data sections: `derive-dep-graph` computes every layer from the
files on disk with the same scanners, through a per-file cache (`data/cache/dep-graph.rktd`, git-ignored) keyed by each
file's sha1 and, as a whole, by the sha1 of `dep-graph.rkt`'s own source — a scanner change invalidates it with no
version to bump. Measured: warm derivation 37–43 ms CPU, full scan 520–536 ms; the derived layers equal what the old
`--write` regenerates (0 differing keys in all four).
- **What the staleness cost, measured** (`sw24-probe.rkt`, stored graph vs derived, as the runner calls
  `compute-affected-tests`): over the 119 root source modules the stored graph MISSED 22 483 of 38 004 affected-test
  selections (59 %), and for `merge-fn-registry.rkt`, `decision-cell.rkt`, `tropical-fuel-primitives.rkt` it selected
  NONE of 451–452. End to end: a one-line edit to `merge-fn-registry.rkt`, `--dry-run` → "No tests affected" before,
  "Affected tests (448 of 502, 3 skipped)" after. Library modules: 176 of 910 missed. And `all-test-files` returned
  354 of 502 test files, so the info.rkt "run ALL" path and `benchmark-tests`' default run skipped 148.
- `update-deps.rkt --check` now verifies the cached derivation equals a full rescan (exit 1 otherwise); `--write` is
  retired with a message. The coherence check also runs in every full suite (`tests/test-dep-graph.rkt`, 8 cases;
  five mutations red), which puts it in the checkpoint gate.
- Owner item: `CLAUDE.md:34` still reads "Validate deps: `racket tools/update-deps.rkt --check`" — true, but the
  protected-file edit to say "derived on every run; `--check` verifies its cache" was not approved in-session.

---

### 170. ✅ **DISCHARGED `e7cda107`** (SW-25: 43 sites → `'truncate`, guard test) — A SHARDED TEST FILE RACES ITS OWN TEMP FILES — `make-temporary-file` + `#:exists 'replace` lets one shard's delete-and-recreate collide with a twin shard's time-named file (`open-output-file: file exists`); `test-path-selection.rkt` fails 3 of 3 targeted runs at `a15b1a9e`

**Found by**: the PPN 4C checkpoint merge gate (2026-10-13, merge of `ppn4c-elaboration-on-network`
into `a15b1a9e`): full suite 10 366 tests, 1 FAILURES — `test-path-selection.rkt` shards 1/5 and 3/5,
each one test erroring `open-output-file: file exists` on a temp path such as
`…/T/prologos-pathsel-17919073441791907344063.prologos`. The merge's own changes are docs and `.rkt`
comments only, so it was A/B'd on main's pristine code (detached worktree, limited build,
`racket tools/run-affected-tests.rkt --tests tests/test-path-selection.rkt`, 5 shards):

| code | runs failing | per-run wall |
|---|---|---|
| `34602ded` (before the two 08:39 merges) | 1 of 3 | 7.5–7.9 s |
| `1961d49d` (+ SW-19…21 runner/lock merge) | 0 of 3 | 7.4–7.5 s |
| `a15b1a9e` (+ the fasl `.pnet` body merge `08acff4a`) | **3 of 3** | 4.0 s |
| `a15b1a9e` with `'replace` → `'truncate` at the 4 sites below | **0 of 5** | 3.9–4.0 s |

Every failing run carried the same signature (2–4 `file exists` errors per run). The merged tree
(`a15b1a9e` + the PPN move) failed 2 of 3.

**Mechanism** (read in code, then confirmed by the last table row): `make-temporary-file` names the
file from `(current-seconds)` and `(current-inexact-milliseconds)` and creates it exclusively, retrying
on a collision (`collects/racket/file.rkt:191-238`, Racket 9.3). The helpers then reopen it with
`(call-with-output-file tmp #:exists 'replace …)`, and `'replace` DELETES the file and creates it
again. Between the delete and the create, a twin shard — the same test code started at the same
moment in another worker — can draw the same seconds-plus-milliseconds name and create it; the
recreate then fails with "file exists", and nothing retries it. Shards of one file run the same
sequence in lockstep, which makes the same-millisecond draw likely; the fasl `.pnet` speedup
(7.5 s → 4.0 s) tightened the lockstep, which is why the failure went from occasional to certain. The
defect is older than both merges (1 of 3 at `34602ded`); the speedup only exposed it. `'truncate`
opens the existing file without deleting it, so there is no window. The sharding note at
`tools/suite-plan.rkt:142` ("test-path-selection under K=2 and K=3, every shard, 0 failures")
predates K=5 and the speedup.

**Sites**: `tests/test-path-selection.rkt:75`, `:99`, `:142` (`run-ws`, `run-ws-raw`,
`run-ws-pre-raw`) and `tests/test-support.rkt:226` (`run-ws`, used by many files). The same
`make-temporary-file` + `#:exists 'replace` pair appears in 30+ further test files (census:
`grep -l make-temporary-file tests/*.rkt` ∩ `grep -l "#:exists 'replace"`); an unsharded file can
collide only with a concurrent file that draws the same name, so the exposure there is by chance,
not lockstep — not measured.

**Fix shape**: `#:exists 'truncate` wherever the path came from `make-temporary-file` (the file
already exists, created exclusively); a lint or a shared helper so new tests do not reintroduce the
pair. Optionally put the pid in the template. **When**: before the next checkpoint gate on any
branch — every `--all` run at `a15b1a9e` or later is expected to show this failure until it lands.
Not applied by the PPN 4C session (outside its track); the measured fix is the last table row.
Record: `tracks/PPN/PPN_4C/LOG.md` § *Checkpoint 1 merged*.

*Addendum 2026-10-13 (DEFERRED-sweep session, independently, while gating SW-24):* (1) the mechanism reproduced
with no test code — three concurrent processes, each `make-temporary-file` then write ×3 000 in one shared directory
(`tmp-race.rkt`, 2 trials): `#:exists 'replace` failed 178–243 times per process (6–8 %), every one
`open-output-file: file exists`; `'truncate` failed 0 of 18 000. (2) Census of the class (racket/prologos root,
`tests/`, `tools/`): **41** `make-temporary-file` sites are then written with `'replace`, under **18** name templates;
`prologos-test-~a.prologos` is shared by 23 test files and `prologos-ws-~a.prologos` is `test-support.rkt`'s `run-ws`,
so concurrent workers share those name spaces (28 sites already use `'truncate`). (3) It hit the sweep branch's first
suite after SW-24 (`test-path-selection.rkt` ×3 shards, one error each; the re-run passed): SW-22's fasl speedup
(merged at checkpoint 4) is what made it frequent, per the table above. Probe + data: `handoffs/2026-10-13_SW24_DATA/`.

**Status 2026-10-13 — discharged (SW-25, `e7cda107`).** All **43** sites → `#:exists 'truncate` (41 in `tests/`, incl.
`test-support.rkt`'s `run-ws-file`, plus two PRODUCTION sites that both censuses missed because the keyword sits after
the lambda: `pnet-serialize.rkt:987`, the atomic `.pnet` write's temp file, and `lsp/server.rkt:554`, the LSP's
per-check document). `tests/test-temp-file-hygiene.rkt` reads every module under `racket/prologos` as syntax and refuses
a temp-file path written with `'replace` (temp DIRECTORIES exempt; a power check proves the detector). Verified:
`test-path-selection.rkt` sharded ×2 failed 2 of 3 runs before and passed 5 of 5 after; guard red with 43 → green;
one `'replace` restored in `test-support.rkt:226` → red naming that line. Evidence: `handoffs/2026-10-13_SW25_DATA/`.

### 171. ⬜ AN LSP REPL SESSION'S REGISTRATIONS ESCAPE IT — into the process, other sessions, and every later document check (measured for constructors)

Found closing DEFERRED 160 (SW-27). `eval-in-session-raw!` (`lsp/server.rkt:206`) binds **6** of the 24 registry
parameters per session (preparse, trait, impl, param-impl, capability, spec store) and writes them back; the other 18
(ctor, type-meta, subtype, coercion, trait-laws, bundle, specialization, property, functor, precedence groups,
operators, macros, schema, selection, session, strategy, process, propagated specs) are assigned at the PROCESS ROOT.
Measured (`probe-repl-escape.rkt`, `handoffs/2026-10-13_SW25_DATA/`): session A evaluates `data Color := Red | Green`;
`Red` is then registered at the process root (#f → #t) and visible INSIDE a later `process-file` of an unrelated
document — SW-27's unit scope inherits the caller's current values, which here include the session's. The
user-visible symptom is not yet constructed (a candidate: a document's bare `Red` pattern resolving as a constructor,
DEFERRED 103's class). **Fix shape**: a session is a PERSISTENT unit — keep its full registry snapshot
(`save-macros-registry-snapshot`, i.e. `macros-registry-params`, SW-27's list) in the repl-session and bind all of
them per eval, writing back after; the same list makes it exhaustive by construction. **When**: with the next LSP
item, or the sweep after SW-26.

### 172. ⬜ A PROGRAM THAT EXHAUSTS REDUCTION FUEL CRASHES `process-file` — the `error 'reduction` at `reduction.rkt:2861` is an uncaught `exn:fail`, so every result in the file is lost, not just the offending command's

**Found by** PPN 4C's 4B.5.b grounding audit (probes p23/p24, branch `ppn4c-elaboration-on-network` @ `0c2aaf6a`, code =
main `150915c4`): `def z : Int := [int+ z 1]` then `z` → `process-file` raises `reduction: fuel exhausted after too many
reduction steps` (a `whnf` / `reduce-int-binary` stack) and returns nothing; the file's `z : Int defined.` is lost with it.
Without the use (p25) the same file runs: `z : Int defined.`, 0 errors. Measured with the audit's `probe-print.rkt`
(process-file, one file per process).

**Mechanism** (read in code): `whnf` decrements `current-reduction-fuel` (1M steps, bound per command at `driver.rkt:731`)
and raises a plain `error` at 0 (`reduction.rkt:2861`). The file loop converts exactly one exception class per command,
POL.4's distinguished `exn:prologos-solve` (`process-command/solve-guard`, `driver.rkt:1594`) — by design, "any other raise
still crashes loudly (a blanket boundary would mask real compiler defects)". Fuel exhaustion is not a compiler defect: it
is the program's own non-termination, reachable by any non-terminating evaluation (a spec'd `defn loop` reaches it —
`tests/test-reduction-perf-01-02.rkt:43`), not only by the definition cycles that found it.

**Pinned today**: `tests/test-reduction-perf-01-02.rkt:43` (skipped in the suite as pathological) expects the raise at
`run-ns` level (`check-exn … "fuel exhausted"`); the fix flips it deliberately.

**Fix shape**: raise a distinguished `exn:prologos-fuel` (sibling of `exn:prologos-solve`) and convert it in
`process-command/solve-guard` to a per-command `prologos-error` that names the evaluation that did not finish within the
limit. Check whether type-checking-time `whnf` (conversion under dependent types) can reach the same raise; convert there
too. Not measured: the LSP path (`process-file #:evaluate? #f`) evaluates no top-level expression, so it is presumably
unaffected.

**Related**: PPN 4C 4B.5.b's productivity check would reject the unproductive definition cycles that reach this (p23/p26,
accepted at definition today) — not the general case.

**Addendum (2026-10-14)**: also reached while a `def` is processed, not only at a top-level evaluation:
`def rec1 : Int -> _ := [fn [x : Int] [rec1 x]]` then `def s : String := [rec1 3]` → the same uncaught raise under
`process-command/demand` (q5-h06p on the branch). Whether type checking or the def's value evaluation reached `whnf` was
not determined.

**When**: independent of 4B.5.b; the next sweep, or with POL work.

**Record**: `docs/tracking/tracks/PPN/PPN_4C/audits/2026-10-13_PPN_4C_4B5b_GROUNDING_AUDIT.md` GA-5 (on branch
`ppn4c-elaboration-on-network` until its next checkpoint merge); probes `…/PPN_4C/research/4B5b/p23-*`–`p26-*`.

### 173. ⬜ ⭐ A SPEC-LESS MUTUAL `defn` CAN COMMIT A TYPE WITH A HOLE — `g2 : Nat -> _ defined.`, after which every use of `g2` type-checks (`def s : String := [g2 3N]` accepted, 0 errors; g2 returns Bool); ~~live on main since PPN 4C 4B.5.a (`2d791705`)~~ widened by PPN 4C 4B.5.a (`2d791705`) — a committed hole predates it (CORRECTED 2026-10-14, see the callout)

> ⚠ **CORRECTION (2026-10-14, PPN 4C session; controls q5-v27, q5-v27b, q5-v27c, q5-h06q on the branch)** — three
> claims of this entry as filed on 2026-10-13 (`96274f3d`) were wrong or mis-attributed:
> 1. ~~"`[int+ [g2 3N] 1] : Int`, a Bool used as an Int" demonstrates the hole~~ **Withdrawn**: with both functions
>    spec'd `Nat -> Bool` (no hole anywhere, q5-v27) the same line is still accepted, `: Int`, 0 errors. That
>    acceptance is DEFERRED 156 (primitive ops do not constrain their operands). I ran no spec'd control before
>    filing. The hole's own effect, measured with a discriminating use: `def s : String := [g2 3N]` is **accepted**
>    with the spec-less pair (p27b: `s : String defined.`, 0 errors) and refused with the spec'd pair (q5-v27b:
>    *Type mismatch, Expected: String, Got: Bool*).
> 2. ~~"`[p27::f2 2N] : _` (does not reduce)"~~ is not the hole: the spec'd pair prints `[q5v27::f2 2N] : Bool` too.
>    The demand trigger looks only at the use's own names, so a use of a committed g2 whose body calls the
>    still-deferred f2 evaluates before the sweep completes f2 (q5-v27c: after a direct use of f2, `[g2 3N]` gives
>    `true`). Filed separately as DEFERRED 175.
> 3. ~~"live on main since 4B.5.a"~~: a committed type with a hole **predates** 4B.5.a.
>    `def rec1 : Int -> _ := [fn [x : Int] [rec1 x]]` → `rec1 : Int -> _ defined.` (q5-h06q; no forward reference,
>    no deferral). What 4B.5.a added: a group that HM types fully (p27: both `Nat -> Bool`) commits a hole, because
>    the deferred member's pre-register is re-written with holes and its partner is typed in a different command.
>    The fix shape below covers both: never commit a top-level type that contains a hole.

**Found by** PPN 4C's 4B.5.b grounding audit, probe p27 (branch `ppn4c-elaboration-on-network` @ `0c2aaf6a`, code = main
`150915c4`):

```
defn f2 | zero -> true      | suc n -> [g2 n]
defn g2 | zero -> [f2 zero] | suc n -> [f2 n]
[g2 3N]
[int+ [g2 3N] 1]
```

→ `f2 : Nat -> Bool defined.` · **`g2 : Nat -> _ defined.`** · `[p27::f2 2N] : _` ~~(does not reduce; cause not
investigated)~~ (DEFERRED 175) · ~~**`[int+ [p27::f2 2N] 1] : Int`**~~ (DEFERRED 156, correction 1) — 0 errors. The pair is
well typed (both `Nat -> Bool`).

**Mechanism** (read in code; consistent with p27 and p18): f2's body references g2, a same-file def-head not yet defined
(`'pending`), so 4B.5.a's annotated deferral arm (`driver.rkt:2116-2130`) defers f2 and leaves its pre-register in place,
re-written meta-free with `unsolved-metas-to-holes ∘ freeze` (`:2123`): for a spec-less `defn`, `Nat -> ?m` becomes
`Nat -> _`. g2 then sees f2 as `'ground`, is not deferred, types its arms against the wildcard and commits `Nat -> _`. A
hole unifies with anything, so no use of g2 is checked. Sibling, p18 (an ill-typed pair: `f | zero -> 0N | suc n -> [g n]`,
`g | zero -> "s" | suc n -> [f n]`): f's branch mismatch IS reported, but g commits `Nat -> String` against f's later-refuted
wildcard and survives f's removal; `[g 1N]` prints `[p18::f 0N] : String`. The 4B.5.a design called the premature
`'ground` "benign under placeholder-keyed completion tracking" (addendum §18.21.26.5); that holds only for a hole-free
(spec'd) pre-registered type.

**Before 4B.5.a** both files errored (f's forward reference was an immediate Unbound) — inferred from the 4B.5 design's p2
record at `5b0c78ed` (3 × Unbound), not re-measured.

**Why ⭐**: silent acceptance at zero errors (`def s : String := [g2 3N]`, p27b), and DEFERRED 156's operand contract would
not catch it (`_` unifies with any type).

**Fix shape**: in-track — PPN 4C 4B.5.b (decision Q-4B5.4, addendum §18.21.27): members whose types have holes are typed
as a group and commit only when every member checks against the group's final, hole-free environment; a hole left in a
committed top-level type is an error ("cannot infer the type of `g2` — annotate it"), never a commit. Stop-gap if 4B.5.b
is delayed: refuse to commit a top-level type that still contains a hole produced on the deferral path.

**When**: 4B.5.b, the next PPN 4C slice; before any user-facing claim that spec-less mutual recursion works.

**Record**: `docs/tracking/tracks/PPN/PPN_4C/audits/2026-10-13_PPN_4C_4B5b_GROUNDING_AUDIT.md` GA-4, GA-4b (on branch
`ppn4c-elaboration-on-network`); probes `…/PPN_4C/research/4B5b/p18-*`, `p27-*`.

### 174. ⬜ AN ANNOTATED SELF-REFERENTIAL DEFINITION THAT IS NOT A FUNCTION IS ACCEPTED — `def z : Int := [int+ z 1]` → `z : Int defined.`, 0 errors; any use exhausts reduction fuel (and, until DEFERRED 172 lands, crashes the file)

**Found by** PPN 4C's 4B.5.b grounding audit (branch `ppn4c-elaboration-on-network` @ `0c2aaf6a`, code = main `150915c4`):
probe p25 (`def z : Int := [int+ z 1]` + an unrelated def and use) → `z : Int defined.`, 0 errors; p24 (the same with a use
of `z`) → `process-file` raises `reduction: fuel exhausted…` uncaught (DEFERRED 172).

**Mechanism** (read in code): the annotated path pre-registers the definition's type before elaborating its body, so a
self-reference types (the old self-recursion mechanism, gate G3 of the PPN 4C addendum). 4B.5.a's pending-referent scan
then EXCLUDES the definition's own name (`driver.rkt:2116-2120`, the exclude list), so a self-reference never defers, and
nothing asks whether the body is productive. Predates PPN 4C's 4B.5 arc — by reading; not measured at an old commit.

**Why not in 4B.5.b**: owner decision **Q-4B5.4** (2026-10-14; PPN 4C addendum §18.21.27): 4B.5.b owns every definition
cycle that passes through the deferral residue — inferred cycles, hole-typed spec-less `defn` groups (DEFERRED 173), and
annotated cycles of two or more members (probe p26). A size-1 annotated cycle never enters the residue, so it needs a
second detection site, at the annotated self-reference.

**Fix shape**: reuse 4B.5.b's productivity predicate (decision Q-4B5.6: a cycle member's elaborated body must be a lambda,
after stripping `the`) where the annotated path elaborates a body that references its own pre-registered name; a
non-lambda self-referential body → 4B.5.b's definition-cycle diagnostic. Pins: p24, p25; G3 (annotated self-recursion
through a lambda, probe p15) must stay green. If 4B.5.b's mini-design finds the second site cheap, it may be pulled in.

**When**: after 4B.5.b ships its productivity predicate — with 4B.5.c (the 4B arc close) at the latest.

**Record**: `docs/tracking/tracks/PPN/PPN_4C/audits/2026-10-13_PPN_4C_4B5b_GROUNDING_AUDIT.md` GA-5; probes
`…/PPN_4C/research/4B5b/p24-*`, `p25-*` (on branch `ppn4c-elaboration-on-network`).

### 175. ⬜ ⭐ A TOP-LEVEL USE OF A COMMITTED DEFINITION THAT CALLS A STILL-DEFERRED ONE EVALUATES TO A STUCK TERM — `[g2 3N]` prints `[q5v27::f2 2N] : Bool` instead of `true`, 0 errors (PPN 4C 4B.5.a's demand trigger is shallow)

**Found by** PPN 4C (branch `ppn4c-elaboration-on-network` @ `569b797e`, code = main `104c9780`), control probes for the
correction of DEFERRED 173. q5-v27c:

```
spec f2 Nat -> Bool
defn f2 | zero -> true      | suc n -> [g2 n]
spec g2 Nat -> Bool
defn g2 | zero -> [f2 zero] | suc n -> [f2 n]
[g2 3N]          ;; → [q5v27c::f2 2N] : Bool     (stuck)
[f2 2N]          ;; → true : Bool
[g2 3N]          ;; → true : Bool
```

**Mechanism** (read in code; consistent with q5-v27c): f2 references g2 before g2 is defined, so 4B.5.a defers f2 (its
type is pre-registered from the spec); g2 types against that and commits. A top-level use triggers the sweep only when the
use's OWN names are pending or deferred (`residuation-demand-name`, `driver.rkt:1499-1512`): `[g2 3N]` names only g2,
which is committed, so it evaluates at once, reaches f2, whose value is not yet there, and stops. `[f2 2N]` names f2,
which is in the residue, so it triggers the sweep, and every later use reduces. The canonical G1 case passes only
because its use names the deferred member (`[even? 4N]`).

**Why ⭐**: a wrong value at zero errors, in the exact feature 4B.5.a shipped (spec'd mutual recursion).

**Fix shape**: in-track (PPN 4C 4B.5.b, which owns the sweep). Simplest and sound: an evaluated top-level command runs the
sweep fixpoint first whenever the residue has ANY outstanding item, whatever names the command mentions. The narrower
alternative — demand closed transitively over committed bodies' references — needs a reference graph that 4B.5.b's
cycle analysis will build anyway. Pin: q5-v27c's first `[g2 3N]` must print `true : Bool`.

**When**: 4B.5.b.

**Record**: PPN 4C LOG § *Q-4B5.4 decided; main merged in; three of my DEFERRED 173 claims corrected* and the grounding
audit's GA-10 (on the branch); probes `…/PPN_4C/research/4B5b/q5-v27*`.

### 176. ⬜ THE PROPAGATOR OBSERVER'S RECORDS MISREPORT WHAT FLOWED — 45 % of BSP diff records show a value the cell does not hold; the sequential scheduler names a placeholder writer; the LSP merges every S0 run and fork in a file into one timeline that starts from the final state

**Found by** PAR 4, re-posing owner decision O-3 (observers). Sources: D.1 Appendix A.6–A.7, on branch
`par4-arena-executors`; the code is main `c1f389ab`. Two probes, with data in `data/par4-p0/o3/` (on the branch):
- `benchmarks/par4/o3-observer-census.rkt`: 18 comparative files, with the observer installed the way the LSP installs it;
- `benchmarks/par4/o3-observer-fixtures.rkt`: five small networks under BSP and under the sequential scheduler.

1. **A BSP record's `new-value` is the written contribution, not the cell's new value** (the observer block,
   `propagator.rkt:3557-3574`; read, then measured).
   - 303 of 672 records (45.1 %) carry a `new-value` that the cell does not hold after the round. 283 of them are in
     rounds where two or more propagators wrote the cell; 20 are single writers into accumulating merges.
   - Control: fixture X1 (one writer, max merge) shows 0; X2 (two writers, set union) shows 2.
   - The editor's scrubber assigns `newValue` as the cell's value
     (`editors/vscode-prologos/src/propagatorView.ts:1647`), so it displays partial values.
2. **The sequential scheduler's record names the run's first-fired propagator as the source of every diff**
   (`propagator.rkt:2647, 2653`; read). Measured in fixtures X3 and X5: in X5, under reverse installation order, it
   names p0 as the source of a cell that p0 never writes.
3. **The LSP's trace is a single timeline across every quiescence call and fork in the file, and it starts from the
   final network** (read).
   - One accumulator is installed around the whole `process-file` (`lsp/server.rkt:547`).
   - `make-trace-accumulator` re-stamps round numbers (`propagator.rkt:601`), erasing the boundaries between runs.
   - The trace is built with initial = final (`lsp/server.rkt:586`).

   Measured scale: `atms-adversarial` sends 111 rounds, from 108 S0 runs and 6 forks, into one timeline.
4. **Some steps are silent** (read).
   - Tier-1 flushes emit no record (`propagator.rkt:3431-3446`).
   - Writes made by stratum handlers are never reported.

   Measured: 6 of the 18 files emit no record at all. Whether their S0 work is Tier-1 flushes or nothing was not
   measured.
5. **`atms-events` is always `'()`**: `git grep` finds no production constructor.

**Impact**: the editor's propagator view (`$/prologos/propagatorSnapshot`) and the observatory's traces. No compiler
output is affected: the compiler never reads the observer, and error explanation refuses it
(`error-explanation.rkt:22`). The impact is shown at the level of the records; the editor's display was read in
code, not run.

**Fix shape** — depends on owner decision O-3 (D.1 Appendix A.12; the lean is OB-4, "observation in logical time"):
- (a) **BSP side, in PAR 4** (P1 or P2). Per (round, cell), record the old value, the held value and the set of
  propagators that wrote the cell that round. This touches only `propagator.rkt`'s observer block and replaces
  items 1–2.
- (b) **Epoch records**, keyed by (network, epoch) and emitted by every scheduler, including Tier-1 flushes and the
  boundary's own step. This covers item 3's run boundaries and item 4, and gives item 5 a home, since ATMS events
  happen at stratum boundaries.
- (c) **The LSP and editor side**, which needs an owner to place it. The visualization design
  (`2026-03-12_PROPAGATOR_VISUALIZATION_DESIGN.md`) is complete and no active series owns it; its deferrals sit
  under § *Propagator Observatory — Visualization Polish* above. The work: read the keyed records, capture the
  initial network, and have the scrubber show held values.

**When**:
- (a) and (b): with O-3's implementation in PAR 4 P1 or P2;
- (c): before anyone relies on the editor view to answer a "why" question.

**Record**: PAR 4 D.1 Appendix A.6–A.12 and LOG § *O-3 re-posed* (on branch `par4-arena-executors`).

**Addendum (2026-10-14, owner guidance G-3)**: the owner wants a visual debugger as part of the language's dev
tooling, for two purposes: demonstrating how the system works, and practical debugging and introspection. It is not
in PAR 4's scope to deliver. Consequences for this entry:
- (c) is **wanted, not optional polish**. It still needs an owner to place it on the roadmap.
- (a) is sharpened by a new measurement (fixture probe `5fbb30df` on the branch). A round record must carry the
  cell, its old value, the value it holds after the round, the round's writers and the round index. With those, a
  cell's final value unfolds into a derivation in which every premise sits at an earlier round, so it is
  well-founded even on a cycle.
  - Without the old value as a premise, a join that reaches `top` names only the last writer (fixture X5).
- New part **(d) — error explanation on rounds**. `error-explanation.rkt` cuts cycles with a visited set and a depth
  bound of 32 (`error-explanation.rkt:164-195`): fuel, not structure. Where round records exist, a derivation over
  rounds gives the same answer with termination by construction. *When*: with (c), or whenever error explanation is
  next revisited.

Requirements table and critique: PAR 4 D.1 Appendix A.13 (on branch `par4-arena-executors`, `47edfd8a`).

**Addendum (2026-10-15, owner decision O-3 = OB-4, "observation in logical time")**: the contract this entry's fixes
follow is now decided (PAR 4 D.1 §14 O-3, `1e1684e2` on the branch).
- (a) and (b) land in PAR 4. D.2 places them in P1 or P2 for the round records and in P2 for the epoch records, the
  shared (network, epoch, round) keys and the replay.
- (c) and (d) remain outside PAR 4 and still need a roadmap home, which is the owner's call.

The entry stays open until the fixes land.

### 177. ⬜ ⭐ THE ATMS SOLVER RETURNS ANSWERS THAT DFS REJECTS — `(= x 1) (= x 2)` in one clause gives `{:x 2}`; `(= x 1) (= y 2) (= x y)` gives `{:x 1, :y 2}`; a caller's `x = 1` is invisible inside a branch, which then answers `{:x 2}` as well

**Found by** PAR 4's D.3 adversarial critique round. Critic C9 (red team) found it; C4 independently measured the
read-side mechanism. Reproduced by hand on 2026-10-15 with `tools/scratch-run.sh` on the two probe files. The code
is main `c1f389ab`. The probes are kept on branch `par4-arena-executors` in
`racket/prologos/benchmarks/par4/d3-wave1/C9/`: `c1-overwrite.prologos` and `c4-varvar.prologos`.

| query | `:strategy atms` | `:strategy depth-first` |
|---|---|---|
| `two ?x` with `&> (= x 1) (= x 2)` | `@[{:x 2}]` | `@[]` |
| `(rel [?x] (= ?x 1) (pick ?x))`, `pick` ∈ {`x = 1`, `x = 2`} | `@[{:x 2} {:x 1}]` | `@[{:x 1}]` |
| `clash ?x ?y` with `&> (= x 1) (= y 2) (= x y)` | `@[{:x 1, :y 2}]` | `@[]` |
| `agree ?x ?y` with `&> (= x 1) (= y 1) (= x y)` (control) | `@[{:x 1, :y 1}]` | `@[{:x 1, :y 1}]` |

Three mechanisms (read in code; C9 also measured each at the lattice level):
1. **A tagged read drops the base whenever an entry matches.** `tagged-cell-read` returns the base only when no entry
   matches (`decision-cell.rkt:470`), so a branch's binding hides the caller's. This explains row 2.
   - C4 measured the read to be non-monotone in the cell's own merge order on 768 of 9 600 random cases over a
     set-union domain.
   - A reader that joins the base in showed 0 of 9 600.
2. **`unify-fire` drops a var-var conflict.** When both sides are bound and differ, it returns the network unchanged
   (`relations.rkt:2112-2120`), so no conflict reaches any merge. This explains row 3.
3. **Per-key last-writer-wins.** `scope-cell-merge` lets the newer binding win per key (`decision-cell.rkt:938-955`),
   so `x = 2` overwrites `x = 1`. This explains row 1.

**Reach**: `:strategy atms`, and `:strategy auto`, the default (`solver.rkt:77`), above its DFS↔ATMS crossover
(threshold 256, `solver.rkt:76`). The crossover's reach is not measured. The answers are wrong under every scheduler,
so order-differential instruments (PAR 4's merge-order census and replay monitor) cannot see this.

**Fix shape**. All three parts are needed; each covers a different row.
- (a) The read becomes `base ⊔ ⨆{v | label ⊆ W}`. That is ATMS label semantics, and a join-homomorphism into the
  domain at each worldview W.
- (b) `unify-fire` writes each side's value into the other, so the conflict reaches the merge.
- (c) A per-key flat lattice with ⊤, as in PAR 4 D.2 P1a row 2. A ⊤ inside a branch's entry becomes that branch's
  nogood; a ⊤ in the base becomes the query's failure.

Test layer: a DFS-vs-ATMS answer-set differential over the relational tests and examples. It can fail on errors that
do not depend on the schedule.

**When**: with PAR 4 P1a (D.3 triage clusters CL-5 and CL-6), unless the owner wants a shipped solver strategy's
wrong answers fixed sooner.

**Record**: PAR 4 D.3 wave-1 triage §1, §3 CL-6 and §4 PD-1
(`docs/tracking/tracks/PAR/PAR_4/critiques/2026-10-15_PAR_4_D3_WAVE1_TRIAGE.md` on the branch).

### 178. ⬜ BSP'S TIER-1 FLUSH RETURNS A NETWORK THAT IS NOT A FIXPOINT — it fires the fire-once, empty-input propagators, then clears the whole worklist, discarding the dependents its own writes enqueued (`propagator.rkt:3431-3445`)

**Found by** PAR 4's D.3 round: critics C2 (reality check) and C5 (theory), independently. Reproduced by hand on
2026-10-15 with C2's `probe-tier1.rkt` (on branch `par4-arena-executors`, in
`racket/prologos/benchmarks/par4/d3-wave1/C2/`).

The probe network: a copy propagator A → B, already quiescent, then a fire-once propagator with no inputs that
writes A := 7.

| scheduler path | A | B | B after a second run |
|---|---|---|---|
| Tier 1 | 7 | **0** | **0** |
| Tier 2 control (same writer, not fire-once) | 7 | 7 | 7 |
| the drain | 7 | 7 | 7 |

The run reports no contradiction and an empty worklist, so callers cannot tell.

**Reach**: not measured. Tier 1 requires worldview cell = 0 and a worklist made only of fire-once, empty-input
propagators (`propagator.rkt:3411-3430`), whose outputs must already have dependents.
- Production installers of that shape are at `relations.rkt:2148, 2161, 2183, 2636, 2699`.
- They take the fire-once path when `current-worldview-bitmask` ≠ 0 (`relations.rkt:2140`), and that can differ from
  the cell.

Two related gaps, both read in code:
- Tier-1 fires run outside `fire-and-collect-writes`. `current-bsp-fire-round?` is therefore `#f`, so an install
  inside such a fire takes the inline branch, where P0's in-fire trap cannot see it.
- Tier 1 emits no observer record (DEFERRED 176 item 4).

**Fix shape**: either delete the Tier-1 branch, since BSP's inner loop already handles these propagators, or keep the
dependents that the flushed writes enqueue on the worklist. PAR 4 D.2 had planned to keep Tier 1 "as is"; that is
corrected in the D.3 triage (SC-20). Under PAR 4 P2, Tier 1 becomes the first pass of the K = 1 worklist.

**When**: PAR 4 P0.5 (with DEFERRED 150), or sooner if a trap measures production reach.

**Record**: PAR 4 D.3 wave-1 triage §1 and §4 PD-2 (on the branch).

### 179. ⬜ Q_U56'S GUIDED `*->` TEXT MISSES THE BLOCK-CLOSER POSITION — `env{prod dev}*->` reports the comparison-keyword hint ("comparison keywords are spelled lt/le/gt/ge …"), not the star-family diagnostic

**Found by** the CIU 6 1b-vi verify (2026-10-18; lens VS, finding VS-7; D4 §5.P4e-1b-vi `#p4e-1b-vi-verify`), re-measured
on the main thread: probe `docs/tracking/tracks/CIU/CIU_6/research/P4e-1b-vi/verify/v5-misc.prologos` line 15, branch
`ciu6-path-selection` @ `0988a4f0` (on main since the checkpoint merge `83fe4fb4`).

| input | message |
|---|---|
| `env{prod dev}*->` | "hint: comparison keywords are spelled lt/le/gt/ge in Prologos (< and <= conflict with angle-bracket syntax) …" |
| `mn{a*->b}`, `mn{a*-> b}`, `mn{a*- > b}`, `t5{a.{b*-> c}}`, `t5{a.{b}*-> c}` (controls) | Q_U56's guided text ("there is no `*->` operator … drop the `>`" / "end the segment there …") |

**Mechanism — conjecture, from the messages only**: the closer band mints `}*-`, and the `>` after the closed block is
then read by the generic top-level `>` handling, outside the selection consumer that carries Q_U56's arm. **Fix shape**:
give the closer-band star followed by `>` Q_U56's message ("drop the `>`"), in the consumer — never the reader (a
reader raise aborts the whole file). **When**: no gate; with the star-family grammar work (DEFERRED 144) at CIU 6 T6's
close, or with the next Q_U56-family message work.

### 180. ⬜ THE STAR ARRIVAL INSTRUMENT CANNOT TELL A ONE-TOKEN `*-` FROM `*` THEN `-` — `star-last-token-type` / `star-mints?` answer `postfix-star` / `#t` for `c{a}*-` and `c{a}* -` alike (and for `-_`), so the flipped arrival pins' "is ONE token" lost its power at the 1b-vi mint

**Found by** the CIU 6 1b-vi verify (2026-10-18; lens VI, finding VI-10), re-measured on the main thread: probe
`docs/tracking/tracks/CIU/CIU_6/research/P4e-1b-vi/verify/v9-arrival.rkt` + `.out` (branch `ciu6-path-selection`; on main
since the checkpoint merge `83fe4fb4`). The instrument is `tools/star-arrival-matrix.rkt` (first/last star-family token,
lexeme not compared); its readers are the arrival gate and the `p4e-star-type` pins in `tests/test-path-selection.rkt`.

**Impact, at the level shown**: none observed — nothing mis-mints today; the reader and the parity pin (the parser's surf
equals the injected IR, 68 rows) both hold. This is instrument POWER: a regression that split `*-` into `*` and `-` would
pass the arrival gate. **Fix shape**: require the minting token's LEXEME to equal the table lexeme under test (the gate
already iterates the table). **When**: with DEFERRED 144, or the next edit of the arrival matrix.
