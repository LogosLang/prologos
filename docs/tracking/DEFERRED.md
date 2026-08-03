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

Three small items survived the track. Both were re-probed 2026-08-03 and both
filings were ACCURATE — the first is now fixed, the second is confirmed as a
layout ruling rather than a message fix.

1. ✅ **FIXED 2026-08-03 — `let` inside a BRACKETED `fn` body said the wrong
   thing.** `[fn [n : Int] let k := 4 [int+ n k]]` → "fn: all parameters except
   body must be bare symbols or a binder", which sends the reader to stare at
   `n`, which is fine. The let line is consumed as fn PARAMETERS (brackets
   suspend indent grouping, so the fn's bracket swallows the tokens). The
   filing said "the fix wants fn-side layout work" — that is true of making the
   form WORK, but the message was fixable on its own, and the message was the
   complaint. `parser.rkt`'s fn arm now detects the case and says so, names the
   cause, and gives the parenthesized workaround.

   Two traps sat in the detection, and the first cut hit both. (a) The
   predicate cannot look for the symbol `let`: `expand-let` has already run
   over the fn's argument list, found no body, and rewritten it to a
   `($let-error msg)` marker before the parser sees it — so `params` holds a
   marker form, not `let`. (b) `stx->datum` is SHALLOW (`syntax-e`), so the
   marker's head is still a syntax object and `(eq? (car d) '$let-error)` is
   false. Both silent: the hint simply did not fire and the generic message
   came out unchanged, which reads exactly like "the edit didn't take."

   Pinned by three cases in `tests/test-let-blocks.rkt`: the new message
   fires, the workaround it suggests actually runs (a hint naming a fix nobody
   has executed is worse than no hint), and a genuine non-let bad parameter
   (`[fn 5 …]`) still gets the generic message.

2. **The 2-line forgot-body shape gives a mediocre error — NOT a message fix.**
   Re-probed: `let x 4 / y 5` (one continuation line — below the aligned
   discipline's ≥2 activation) falls to the legacy shorthand as
   `(let x 4 (y 5))` → "Unbound variable y". Loud and per-command, but not the
   guided no-body message the ≥3-line shape gets.

   The 2026-08-03 probe establishes WHY the cheap fix is not available, which
   the original filing gestured at ("collides with the nested-form's
   byte-transparency") without pinning. `classify-let-block` bails at
   `(< (length cont-elems) 2)`, and with the reader indent-GROUPING a deeper
   line into one element, `y 5` is a single element — so the forgot-body arm at
   `parse-reader.rkt:2848` is unreachable for this shape. Reclassifying it
   means declaring that a continuation at exactly the HEAD BINDING's column is
   a binding rather than a body — and that column is currently a legal body
   position in the nested shorthand (`let xs [foo]` / `       [bar xs]` aligns
   by coincidence and works today). So this is an owner ruling on layout
   semantics, not a diagnostic improvement, and it stays deferred on that
   basis. Revisit only if users actually hit it.

3. **Unannotated `match` as a binding VALUE** dies on the QTT infer-position
   debt (generic multiplicity message). NOT a let item — the layout produces
   the correct datum since P4 — but let is where users will MEET it, so the
   syntax doc § let carries the annotate-the-binding workaround. The debt
   itself is the QTT track's recorded option-(c) deliberate deferral
   (an `expr-reduce` arm for `infer`/`inferQ` — new typing policy).

   **Same gap as § CIU T6 two standing WS-surface non-blockers item 2**
   (established 2026-08-03): both are "`infer` has no `expr-reduce` case", met
   from two different directions. One owner ruling closes both.

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
## ✅ CLOSED `7efc781d` — Cross-FILE spec-store leakage within a batch worker (filed 2026-07-31, fixed 2026-08-02)

**Root cause, confirmed.** The 2026-07-31 note's prime suspect was right:
`run-ns-*` handed every call the shared `prelude-persistent-registry-net-box`
UNFORKED, so the cell-backed spec store was one table for the life of the
worker process. `spec-store-lookup` (macros.rkt:496) reads the CELL FIRST and
falls back to the parameter; the worker's per-file snapshot restores the
PARAMETER, which that read never consults. The dual write to both is what made
the restore look complete.

**Fix**: fork `current-persistent-registry-net-box` per call, alongside the
prop network `run-ns-*` already forked, seeded FROM the prelude box so
prelude registrations survive. Five lines in `test-support.rkt`;
`tests/test-batch-isolation.rkt` pins both directions (nothing leaks forward,
the prelude still arrives).

**How it was finally caught**: bisection to a TWO-FILE deterministic repro
(`test-defn-multiarg-patterns` then `test-error-messages`, `--jobs 1`), after
five sightings across two separate DEFERRED entries — this one and the OCapN
backlog's X2. The second symptom was the instructive one: a leaked
`(spec ok2 Nat -> Nat)` turned a `defn ok2` that must INFER into one that
CHECKS, and the failure read "cannot infer the type of an unannotated
parameter" — naming an engine that was working perfectly. Same lying-diagnostic
shape as `infer`/`inferQ`, from a different cause.

**Lesson worth keeping**: an order-dependent batch flake is reproducible.
`--jobs 1 --all` makes the order deterministic, and bisecting the prefix
against the failing file found the culprit in six runs. Three earlier sessions
re-observed it instead.

## ✅ CLOSED `ccf7adb0` — `(when C (parse-error …))` computes a diagnostic and throws it away (censused + swept 2026-08-02)

`parse-error` RETURNS a value; it does not raise. So `(unless C (parse-error
…))` evaluates the diagnosis, discards it, and falls through into the code the
guard was written to reject.

**Censused and PROBED, not estimated.** Every site of that shape in
`parser.rkt` was probed with an input that triggers its condition. Five
detonated into raw Racket contract violations — whole-file aborts, zero
commands, with the correct diagnosis computed and unused:

| input | was | now |
|---|---|---|
| `match 5 \| 0 111` | `take: contract violation` | names the missing `->` |
| `defn 5 [x]` | `symbol->string: contract violation` | "expected a name, got 5" |
| `defn h [] \| -> 1` | `car: contract violation` | "no parameters, so its `\|` arms have nothing to match on" |
| `defn i [x] \| 0 1` | `take: contract violation` | "a pattern arm needs `->`" |
| `defn j [x] \| 0 ->` | `car: contract violation` | "nothing after its `->`" |
| `strategy 5` | `symbol->string: contract violation` | "expected a name, got 5" |

The rest recover downstream or are unreachable from the surface — which is why
the sweep was probe-driven rather than a mass conversion. Some sites fall
through to code that produces a BETTER error, and converting those would
regress the message.

**Two lessons worth keeping.**

*Fixing one guard can just move the crash.* `defn 5 [x]` still died after
`parse-defn-multi`'s guard was fixed, because a different `defn` shape was
taking the call — the name is checked once at `parse-defn`'s entry now, before
shape dispatch, so every shape is covered including ones added later.

*This was found once and not swept.* `parse-map-literal` — the function
immediately below the match-arm parser — carries a comment describing this
exact defect being fixed there in July: "It was a value-discarding `when` that
fell through to the loop below and hard-crashed."

**Still open (structural, not a defect):** `parse-error` returning rather than
raising is what makes this shape writable at all. Making it raise, or giving
the parser an error monad, would make the class unrepresentable — a bigger call
than a sweep should make. Until then the shape can be reintroduced by the next
guard someone writes.

## 🔶 PARTIAL `db65045a` — `[x : T]` works for `fn` but is a PARSE ERROR for a `defn` parameter list (found 2026-08-02; message fixed same day, the syntax question is the owner's)

```
defn f [n : Nat]      ;; parse error
  [+ n 2N]
[f 3N]                ;; …then a cascading "Unbound variable"

def g := [fn [x : Nat] [+ x 2N]]   ;; fine
defn h [n:Nat]                      ;; fine (fused)
  [+ n 2N]
```

**Fixed: the message.** It used to print SEXP syntax
(`(defn name [x <T> ...] <ReturnType> body)`) at a WS-mode parse failure, so it
named neither the actual problem nor a spelling that works. It now says the
fused form is what a `defn` parameter list takes, shows it, offers `spec` as
the alternative, and notes that the spaced form works for `fn` — with the sexp
grammar kept in parentheses for sexp-mode readers. The test RUNS the advice
rather than matching its text.

**Still open — an owner call, not a defect:** should `defn` accept the spaced
form? `fn` does; `let` does not (fused only, single-token types, per
`prologos-syntax.md`); `defn` currently follows `let`. If that is deliberate,
this entry closes as documentation.

**Still open — the cascade.** A `defn` that fails to parse still produces a
second `Unbound variable` for the name it was defining, and that rendering does
not even show the name. Each command reporting its own problem is defensible;
suppressing the second would mean tracking "this name failed to define", which
is a feature rather than a fix. Left as a known, now-secondary annoyance: the
first message tells the user what to do.

## ✅ CLOSED — two soundness holes on the STRICT path, found while grounding P6 (2026-07-31)

Both confirmed by probe at `7584c16e`, both independent of P6/P7. **Both were
FIXED at the time — see the CLOSED entry above.** Retained for the mechanisms,
which are still the best description of how each hole worked; the open-bug
marker on this entry was left behind by mistake and is corrected here
(2026-08-02). Hole 2's diagnostic was improved separately — see the
cross-constructor hint entry above.

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

1. ✅ **FIXED 2026-08-03 — `expr-vindex` was STUCK.** `whnf` had computation
   rules for `vhead`/`vtail` on a canonical `vcons` but NONE for `vindex`,
   which appeared only as an `nf` congruence arm — so it type-checked,
   multiplicity-checked, and then sat there.

   Two iota rules, forced by the indices (`i : Fin n` and `v : Vec A n` step
   in lockstep, so a canonical index always meets a canonical vector):
   `vindex(A, n, fzero(m), vcons(A, m, hd, tl)) → hd` and
   `vindex(A, n, fsuc(m, j), vcons(A, m, _, tl)) → vindex(A, m, j, tl)`. The
   recursive arm rebuilds at `m`, the TAIL's length, not `n`.

   The congruence arm is deliberately NOT a copy of `vhead`/`vtail`'s: those
   reduce only the vector, which is right for them and wrong here, since
   `vindex` needs the INDEX canonical too. Copying the neighbouring shape
   would have left `vindex(A, n, [f x], vcons …)` stuck on a computable index.
   Pinned as its own case.

   `expr-fzero` / `expr-fsuc` joined `whnf-trivial?` alongside `vcons`/`vnil`
   in the same commit — same canonical-form argument (no bare-head arm exists
   for either), and the new congruence arm whnf's the index, so they are now
   on a path that is actually taken.

   Pinned at two levels: `test-reduction.rkt` for the iota + congruence rules
   (including a neutral index that must stay stuck without looping), and
   `test-vec-index-ws.rkt` at Level 3, because a rule that fires on hand-built
   terms can still be unreachable through the elaborator. Position 2 is the
   load-bearing case in both — it needs the recursive arm to fire twice, so an
   implementation handling only `fzero` passes position 0.
2. ✅ **FIXED 2026-08-03 — Vec/Fin nodes had no `pnet-serialize` registration.**
   Nine nodes, not seven (`expr-Vec` and `expr-Fin` themselves were missing
   too). All nine now register, pinned by `tests/test-pnet-vec-fin.rkt` — the
   assertion is `struct?` FIRST and `equal?` second, because the failure mode
   is a raw VECTOR that PRINTS like the struct, so an `equal?`-only check can
   pass a vector against a vector.

   **Probing this found a larger, verified gap and it is filed below** — the
   same landmine sits under the `expr-generic-*` arithmetic family and two
   other sibling sets. Fixed in the same commit.
3. ✅ **FIXED 2026-08-03 — the Redex model had no QTT rules for Vec/Fin.**
   All seven are mirrored now: `vnil` / `vcons` / `fzero` / `fsuc` as `checkQ`
   arms (check-only by necessity — `infer` has no case for any of the four, so
   without them the conversion fallback delegates to `inferQ`, hits its
   `tu-error` fallback, and every annotated Vec/Fin term fails as a
   multiplicity violation), and `vhead` / `vtail` / `vindex` as `inferQ` arms
   delegating the TYPE to `infer` — the same no-drift twin pattern the kernel
   uses at those arms.

   `redex/reduce.rkt` also gained `vindex`'s two iota rules plus its congruence
   rule, since residual 1 (above) had just added them to the kernel and the
   model would otherwise have drifted the other way in the same session.

   12 new cases in `redex/tests/test-qtt.rkt` (39 total, up from 27). The
   load-bearing ones assert the DIFFERENCE the rules make rather than just
   their presence: the same linear variable in `vcons`'s head AND tail reports
   `mw` and is REJECTED at top level (a join would have said `m1` and permitted
   the duplication), and `vindex` at position 1 needs the recursive reduction
   rule to fire — an implementation handling only `fzero` passes position 0.

   ⚠ **Found doing this, and it is the more important half.** The Redex model
   was NOT BEING RUN AT ALL: `raco pkg show redex` reported the package absent
   in the dev container, `tools/run-affected-tests.rkt` discovers tests by
   scanning `tests/` only so `redex/tests/` was never in the set, and no
   workflow mentions redex (`grep -rn redex .github/workflows/` is empty). The
   spec could have drifted arbitrarily far from the kernel with a green suite
   throughout — precisely the failure this residual predicted, one level up
   from where it predicted it. Nothing had drifted: all 177 model tests pass at
   HEAD once redex is installed. But that is luck, not a control.

   **Partly closed the same day** by `tests/test-redex-model.rkt`, which runs
   the five model files from the ordinary suite (one `test-case` each, 539
   files / 10448 tests green). Two details that make it a real gate rather than
   a shape:
   - **Failure is detected by OUTPUT, not by exception.** Redex's `test-equal`
     RECORDS a mismatch and `test-results` PRINTS the tally; neither raises, so
     `raco test` exits 0 on a model failing every case. The wrapper asserts the
     success shape (`"All N tests passed."`). Verified by planting a failing
     `test-equal` in `redex/tests/test-subst.rkt` and confirming the wrapper
     fails with the file, line, actual and expected — then reverting.
   - It also asserts the model directory was found and holds ≥5 files, so a
     moved path cannot make the file pass vacuously.

   **STILL OPEN, and it is the load-bearing half:** the wrapper SKIPS (with a
   stderr banner naming the install command) when the `redex` package is
   absent, so a green suite still does not PROVE the model was checked. Making
   it mandatory means pinning `redex` as a project dependency or installing it
   in CI — a dependency decision, hence the owner's. Until then this is a
   ratchet, not a gate.
4. ✅ CLOSED `63dea0b6` — *(was: the J arm drops its base's usage entirely.)*
   Folded into P7.
5. ✅ **FIXED 2026-08-03 — `expr-foreign-fn`'s type was arity-wrong once `args`
   was non-empty.** `global-env-lookup-type` returns the FULL registered Pi,
   which is the node's type only while `args` is empty; `reduction.rkt`'s
   partial-application arm appends whnf'd arguments and returns the updated
   node, so the reported type was wrong by exactly `(length args)`.

   `infer` now peels one Pi per accumulated argument, `subst`-ing each into the
   codomain (not a bare unwrap — a dependent foreign signature's later domains
   can mention the earlier arguments). Over-application returns `expr-error`
   rather than a type wrong by a different amount.

   **The entry said fixing it meant fixing both arms; it meant fixing one.**
   `inferQ` already delegates the TYPE to `infer` — the no-drift twin pattern —
   so the peel lands in a single place and the QTT arm inherits it. The
   caveat comment in `qtt.rkt` is updated in the same commit rather than left
   describing a defect that is gone.

   Pinned by `tests/test-foreign-fn-arity.rkt`, at the arms directly: the
   accumulating node is built only inside `whnf` on the hole-section path, so
   no source program reaches it and a behavioural test would pass with the bug
   in place — the same reason the sibling walker defect (`2df675d5`) needed
   direct tests. The twins' AGREEMENT is asserted at every arity, because
   agreement is the property that made the defect safe to leave.

## ✅ FIXED 2026-08-03 — `.pnet` registration gaps by SIBLING, not by node (found while fixing QTT P5 residual 2)

`pipeline.md` names this shape — *"a fix applied to one member of a container
family but not its siblings"* — and the `.pnet` tag tables are full of it,
because each registration was added when that particular node DETONATED.

Verified in-process (construct the node, `deep-struct->serializable` →
`deep-serializable->struct`, assert the result is a `struct?` and not a raw
vector), so these are measurements rather than inferences:

| Family | Registered before | MISSING before |
|---|---|---|
| `expr-generic-*` | `from-int`, `from-rat` (they bit — the Q11 Posit→Float instances) | `add sub mul div lt le gt ge eq mod negate abs` — **12** |
| `expr-int-*` | `add sub mul div lt eq` | `le`, `mod` — **2** |
| Posit ops | the 12-op list per width, ×4 widths | `sqrt`, `from-nat` per width — **8** |
| Vec/Fin | none | all **9** (P5 residual 2 above) |

The generic set is the alarming one: those are not exotic nodes. Every generic
`+ - * / < <= > >= = mod`, `negate`, `abs` a user writes elaborates to one, and
the family's OTHER two members are registered specifically because they caused
a months-latent crash. All 31 now register; pinned per-member in
`tests/test-pnet-vec-fin.rkt` (enumerated, not sampled — the defect IS the
per-member gap, so a test that checked one member per family would have passed
against every one of these).

**A blanket coverage test was attempted and is NOT the answer as written.** A
reflective sweep over all 345 `expr-*` structs — build a dummy, round-trip it —
reports 130 failures, and that number is NOT trustworthy: dummy field values
are ill-formed for the sentinel-serialized containers (`expr-champ`,
`expr-hset`, `expr-rrb`, the transients), which serialize RECONSTRUCTIVELY and
legitimately reject a dummy payload. It also produced at least one outright
false positive (`expr-Symbol`, which round-trips correctly when checked
in-process). Treat 130 as an upper bound that needs per-node triage, not as a
defect count. The residual — auditing the rest, and deciding which nodes are
deliberately non-persistable (`expr-prop-network`, `expr-opaque`, the
transients) versus simply missed — is real work and is **not** done. Reproduce
the sweep with the recipe above before trusting any number in it.

## ✅ CLOSED `2df675d5` — `expr-foreign-fn` treated as a closed leaf (filed 2026-07-30, fixed 2026-08-02)

The comment *"opaque leaf — no Prologos sub-expressions"* was false in SIX
walkers, not two: `shift`, `subst`, `nf`, `uses-bvar0?`, and all three of
`zonk` / `zonk-at-depth` / `default-metas`. `reduction.rkt`'s partial-
application arm appends whnf'd argument expressions into `args`, so a node
reachable under a binder can hold an open term.

All six now descend `args`, `eq?`-preserving when nothing changed (so the
GitHub #58 P1 sharing property survives). `tests/test-foreign-fn-walkers.rkt`
goes at the walkers DIRECTLY — 5 of its 7 cases fail against the previous
commit, which is the point: the original filing correctly noted the defect is
not reachable from any source program today, so a behavioural test would have
passed with the bug in place. That is how it survived to be found by reading.

Kept the tripwire framing: this arms the invariant rather than relying on the
reduction order that currently hides it.

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

2. ✅ **FIXED 2026-08-03 — an arm that READS its pattern-bound field now gets
   the branch message.** `defn f | zero -> "s" | suc n -> n` reported "cannot
   infer the type of an unannotated parameter … add a `spec`" — advice false
   twice over, since the parameter is not the problem and a spec may be
   present. Now: *"Type mismatch between branches … these disagree: String vs
   Nat"*, with and without a spec.

   The entry's fix path was right and its final sentence was the load-bearing
   half. **Both halves are required and either alone is invisible:**
   - `branch-result-leaves` derives each arm's binder types via
     `reduce-scrutinee-decompose` + `reduce-arm-ctx` — already exported for
     qtt.rkt's twin, so this is a THIRD consumer of one derivation, not a
     fourth copy.
   - `branch-result-mismatch-hint` now takes the EXPECTED type and peels it in
     lockstep with the lambdas, so a hole-domain parameter gets its real type
     from the Pi's domain. Without this the parameter is a hole, so the
     SCRUTINEE is a hole, so there is nothing to decompose and the first half
     changes nothing. Verified in that order — the arm-ctx change alone left
     the probe reporting the old message verbatim.

   Hole extension REMAINS as the fallback, deliberately: the scrutinee type may
   not infer (this runs on an already-failing path) and the type may have no
   constructor metadata (the Church-fold case). Both must keep degrading to
   "unreportable, drop the leaf" — a WRONG binder type would put a wrong type
   in a user-facing message, which is worse than the message being replaced.

   Three cases added to `test-error-messages.rkt`: the spec'd shape, the
   un-spec'd shape, and — the one the message tests could not catch — a
   field-reading arm that AGREES and must still type-check, since every other
   test in this block only ever looks at failing programs.

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

## 🐛 DEFECT — a numeric-LITERAL first branch adopts any second-branch type (found 2026-07-30; mechanism nailed down 2026-08-02, fix still needs a design call)

**It is worse than "accepts a String".** Investigated as the entry asked
(failing-test-first); the shape is a numeric literal in the FIRST branch
adopting whatever type the second branch has, and the accepted definition is
genuinely unsound at runtime:

```
defn d8  | 0 -> 1.5 | n -> "x"     ;; d8 : Int -> String   ← accepted
[d8 0]                             ;; ⇒ 1.5 : String       ← a Posit32 labelled String
defn d11 | 0 -> 1.5 | n -> true    ;; d11 : Int -> Bool    ← accepted
[d11 0]                            ;; ⇒ 1.5 : Bool
defn d10 | 0 -> 1.5 | n -> 2       ;; d10 : Int -> Int     ← 1.5 collapsed INTO an Int
defn d9  | 0 -> "x" | n -> 1.5     ;; ERROR (correct)      ← order-asymmetric
defn ctl | 0 -> 1   | n -> "x"     ;; ERROR (correct)      ← integral literal is fine
```

**Mechanism (confirmed, not suspected).** `check`'s N4 arm
(typing-core.rkt ~:3382) has three cases for a numeric literal against
expected type `T`: concrete-numeric → representability-gated solve; **meta →
`(unify ctx alpha T)`, "link + defer"**; anything else → #f. The branch join
checks branch 1 against the motive META, so the literal takes the link. Branch
2 then solves that meta to `String` — and `alpha` IS that meta, so it becomes
`String`. **Nothing ever re-validates.** The "defer" in the comment names an
obligation that is never discharged.

`d10` shows the same hole eating representability, not just numeric-ness:
`collapse-num-lit` (zonk.rkt:58) explicitly says *"Representability is validated
in check-mode; here we trust the resolved type"*, and on this path check-mode
never validated, so it builds `(expr-int 3/2)` — a malformed Int literal.

Order-asymmetric because branch 1 gets the meta and branch 2 gets a concrete
type: `"x"` first means `1.5` is checked against `String`, which correctly
takes the `[else #f]` case.

**Why no fix here.** Discharging the obligation is a design call in the numeric
tower, not a local patch. The candidates each have a cost:

1. **Constraint on the meta** ("must resolve to a numeric type representable
   for this literal"), swept like trait constraints. Correct, and needs a
   general "meta satisfies predicate" facility this codebase does not have —
   the constraint system is `(trait-name, type-args)`.
2. **Post-typing validation walk** before `default-metas` erases the evidence
   (`freeze` = zonk then default). Cheap, but it is a second mechanism checking
   what check-mode was supposed to have checked.
3. **Gate `collapse-num-lit` on representability.** Strictly right — it stops
   `(expr-int 3/2)` being built — but it does NOT fix the type-level
   unsoundness: `default-metas` then falls back to the notation default, giving
   a Posit32 value under a `String` type. Do not mistake this one for a fix.

Still Num Track 1 territory, as originally filed. What has changed is that it
is now a three-line repro with a named mechanism and a demonstrated runtime
violation, instead of a suspicion.

## ✅ CLOSED `c4aa917c` — live `.( )` mixfix errors RAISE and abort the whole file (filed 2026-07-28, fixed 2026-08-02)

Fixed via the seat the entry named. `expand-mixfix-form` collapses its own
failures to a `($mixfix-error msg)` datum; parser.rkt turns that into a
`parse-error` VALUE with the form's location. Same channel as LET P1's
`$let-error` — reused rather than duplicated, so there is one mechanism for
"a preparse expander failed" and not two.

```
0: a : Int defined.
1: ERROR: Operators from groups 'additive' and 'cons' have no defined precedence relationship — use [] for explicit grouping
2: b : Int defined.
--- 1 errors ---
```

Genuinely PER-COMMAND, unlike the reader raises: expansion is per-form, so the
commands before AND after the bad one still run. Pinned in both directions —
each failure mode reports, and a well-formed `.( 1 + 2 )` still evaluates.

A distinguished `exn:mixfix` struct (mirroring `exn:let-syntax`) rather than
catching `exn:fail?`, so a genuine Racket-level bug inside the parse still
surfaces as itself instead of being reported to the user as a syntax error.

**Five raise sites, not three.** The first pass converted the three in
`parse-expr` and left `parse-primary`'s two, which kept aborting — caught
because a test pinned the surviving raise. Converting a family and stopping at
the ones you happened to grep for is the same shape as the walker defects
elsewhere in this file.

Three tests that pinned the raise are updated to pin the marker; that is the
change the entry existed to make, not collateral.

## ✅ CLOSED — the tilde-number reader diagnostic (filed 2026-07-28; silence fixed `5da580f9`, per-command routing fixed 2026-08-03)

**Was fixed at `5da580f9`**: it became a reported error rather than a raw
Racket `context...:` dump with exit 1 and zero output. Reader raises carry LINE
AND COLUMN (`rrb-line-col`, computed from the char buffer, since tokenization
runs before any syntax object exists), and `process-file-inner` guards the READ
step.

**Now fixed too — the file's other commands survive.** The old entry said this
"needs the reader to EMIT A MARKER instead of raising — the D4.P1a
`parse-error`-value seat", and that is exactly what it took. The `tilde-number`
token pattern no longer raises; it tags the token, `token-entry->stx` emits
`($reader-error "msg")`, and `parser.rkt` converts it on the same channel as
`$let-error` / `$mixfix-error` (plus the `macros.rkt` head-symbol exclusion the
channel requires). One command lost, not the file:

```
"a : Int defined."
(parse-error (srcloc … 3 9 3) "`~` approximate literals were removed — …")
"c : Int defined."
```

Two things worth knowing if this channel is extended again:

- **The `token-pattern`'s third field is the TYPE function, not a value
  function.** Returning a marker symbol from it renames the token TYPE, so the
  `token-entry->stx` arm keyed on the old name silently stops firing and the
  token falls through two `[else]`s to a bare symbol — `~32` came out as an
  unbound variable with no diagnostic at all. Same silent-fallthrough shape the
  `.N` ordinal-access arm is annotated for at that site.
- **The location moved off the message and onto the srcloc**, so the text no
  longer spells "line 4, column 9". A test asserting `#rx"line 4"` against the
  message string is asserting the OLD delivery mechanism; assert
  `srcloc-line` / `srcloc-col` instead.

The five `check-exn` test files the entry named are updated (4 files, 5 cases —
`test-lseq-literal`, `test-negative-literals`, `test-num-lit`,
`test-numeric-display`), each now asserting the rejection is REPORTED rather
than raised. `test-reader-robustness` additionally pins that the commands on
either side survive — the half `5da580f9` could not deliver.

**Narrow the guard, not the blast radius** (unchanged, still load-bearing):
guarding the whole `surfs` computation instead of just the read ALSO swallowed
raises from `preparse-expand-all` that tests rely on escaping (a numeric `ns`
segment). Turning a REJECTION into a report is a different decision from
turning an ABORT into one; only the second was wanted. Caught by the suite, two
files.

**Also learned, and pinned as a negative** (`test-reader-robustness.rkt`): the
sibling raises in `tokenize-string`'s validation loop — negative Nat literal,
stray `&` — are NOT reachable for the obvious inputs. A per-command check gets
there first with a real srcloc, which is strictly better. With the tilde
pattern no longer raising, that loop is the only raising code left in the
reader, and `compat-tokenize-string` has no production caller — it is a
test-only compatibility path.

## ✅ CLOSED `4efe236c` — bare top-level `[]` hard-aborts the reader (filed 2026-07-28, fixed 2026-08-02)

The chain was one step longer than the filing's: a `'()` element gets a syntax
object with line 0, `make-stx` maps 0 → #f (as it is supposed to), and the
re-wrap in `read-all-forms-from-tree` reads that #f back and hands it to
`make-stx` again — whose guards compared with `>` BEFORE checking for #f. So
the crash was `>` on #f, not `max`/`-`, and it fired from the re-wrap rather
than the emission.

`make-stx` now accepts #f in every field, which its own comment always claimed
it did. The three inline `(- (+ (syntax-position last) (syntax-span last))
(syntax-position first))` sites are one `stx-range` helper that degrades to "no
location" instead of raising. `tests/test-reader-robustness.rkt` pins that the
file SURVIVES — 2 of its 3 cases fail against the previous commit.

**Residual, smaller and separate (filed below).** `[]` no longer aborts, but it
does not error consistently either.

## ✅ FIXED 2026-08-03 — a bare top-level `[]` yielded the WRONG command's result when another form followed (found 2026-08-02, splitting out of the abort fix above)

The filing was accurate and its two guesses were both wrong, in a way worth
recording. It said "the reader is not at fault" and pointed at
`preparse-expand-all`. The reader WAS at fault, `preparse-expand-all` was not
involved, and the entry's control case — `[]` alone erroring, annotated
"(correct)" — was the third bug rather than the baseline.

**Three faults, each masking the others.**

1. **The reader located an empty group nowhere.** `wrap-stx-list` had no
   elements to take a range from and passed 0 for line and column; `make-stx`
   maps 0 to `#f`; `stx-range` then propagated `#f` up to the enclosing form.
   The opening bracket's token was sitting in the caller, unused. Fixed with an
   `#:at` fallback — an empty group is located at its bracket.

2. **`merge-preparse-and-tree-parser` treated line 0 as a line.** The merge keys
   the two parse spines against each other BY SOURCE LINE, and 0 is the
   project's unknown-location sentinel (`srcloc-unknown` is `(srcloc … 0 0 0)`,
   and `stx->loc` folds a missing `syntax-line` to 0). So every located-nowhere
   surf on one spine matched every located-nowhere surf on the other — and the
   tree spine routinely carries one. Fixed with a `real-line?` guard on both
   the map build and the lookup.

3. **The two spines disagreed about what an empty group MEANS.** The tree spine
   has always said nil (`parse-bracket-group-tree`: "empty brackets = nil") and
   `def x := []` is tested as the empty list; `parse-datum` said "Unexpected
   datum: ()". Fault 2 was papering over fault 3 — the error surf got swapped
   for the tree surf by the very collision that was corrupting everything else,
   so `def x := []` worked BY ACCIDENT. Tightening the merge key exposed it on
   the first suite run, which is the useful thing about removing an accident.
   `parse-datum` now returns `surf-nil` for `'()`, so the spines agree.

**Consequence for the entry's "(correct)" annotation**: a bare `[]` is no
longer an error, it evaluates to nil — the same thing it means in `def x := []`
and the same thing the tree spine has always said. The inconsistency was the
error, not the value.

The defect was also broader than filed: `def y := ()` in a multi-command file
corrupted results identically (`z` reported twice), so it was every empty
group anywhere, not just a bare top-level `[]`.

Pinned by `tests/test-empty-group-toplevel.rkt` at all three levels — reader
location, one-result-per-command-in-order, and both spines agreeing on nil in
value position. The end-to-end assertion checks COUNT, ORDER and NO-DUPLICATE
together; asserting only that `a`, `b` and `c` each appear would have passed
throughout the bug, since they all did — one of them twice.

## ✅ CLOSED `c38f175a` — `def X :=` + multi-key layout body fails (filed 2026-07-28, fixed 2026-08-02)

`expand-def-assign` (macros.rkt) auto-wraps a multi-token RHS as an
APPLICATION — which is right for `def x := some 42N` and wrong for a layout map
body, where it built `((:eu …) (:us …))`. Hence "Could not infer type": the
diagnostic named typing for what the entry correctly called a parse/layout
seam.

The no-`:=` spelling worked because it reaches `rewrite-implicit-map` with its
keyword tail intact. So the fix SPLICES an all-keyword/dash-headed RHS instead
of wrapping it, and both spellings go through the one rewrite — rather than a
second map-building path being added on the `:=` side.

Narrow by construction: multi-token AND every token keyword- or dash-headed. A
single keyword group already spliced correctly, and anything else keeps the
application default.

The test is an A/B — the two spellings must agree — because asserting on either
one alone would have passed throughout the divergence.

**Found while testing, NOT this defect and still open**: `def r : {:a Int :b Int}`
fails with "Expression is not a valid type" in ALL THREE spellings (`:=`
layout, no-`:=` layout, and single-line `:= {:a 1 :b 2}`). A map literal as a
TYPE annotation, independent of the layout seam; it behaved identically before
this fix.

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

## ✅ CLOSED `65edc1a4` — resolution bridges capture registry cell-ids while they are still #f (found 2026-07-27, fixed 2026-08-02)

Took the **read-at-fire-time** option, not the defer-into-the-lambda one. The
lambda is called at INSTALL time, which is also before some paths have
identified the cells — deferring one level would have moved the bug rather than
removed it. Fire time is the only point at which the answer is guaranteed
current, and it costs a parameter read on a path that is already ambient:
`read-persistent-registry-cell` reads `current-persistent-registry-net-box`
ambiently inside these same fire functions, so no new assumption is added.

The three captured cell-ids and their six parameter passes are GONE rather than
deferred — the fire functions read `(current-impl-registry-cell-id)` and friends
at the point of use. A stale capture is now unrepresentable instead of merely
fixed.

**Test shape, stated honestly.** This defect is silent because the pure bridges
are not the production trait-resolution path, so there is no behavioural
assertion that fails before and passes after. What the tests pin is the ARITY of
the fire functions (which changes exactly when the plumbing is removed), that
both factories survive construction with the cell-ids unset — the module-level
situation — and that ordinary trait dispatch still works, since the factories
really are built at module level.

Unblocks PM Track 12's read-path work, which named this as a prerequisite
(`2026-07-27_PM_TRACK12_REGISTRY_READ_PATH_NOTE.md` §2.4).

## ✅ CLOSED `97c113c7` — `.pnet` positional format has no arity assertion (filed 2026-07-27, fixed 2026-08-02)

Took the "assert the length" option, on BOTH sides, plus the named constant the
entry implied:

- `PNET_SLOT_COUNT` (31) sits beside `PNET_VERSION`, exported, with the rule
  that it moves with the version — a payload of a different shape IS a
  different format.
- **The writer asserts before writing**, so a mis-ordered build fails on the
  machine that made it instead of becoming a shifted read somewhere else.
- **The reader requires EXACT equality**, replacing a `>= 14` minimum. A short
  or long payload is now a cache miss rather than a shifted read.

The write side already knew the count; the read side accepted anything from 14
up. The two disagreed by construction, and nothing said so.

Removed while there: 18 per-slot `(>= (length raw) N)` guards and the 18
`(if s-X … (hasheq))` fallbacks behind them. Both were unreachable — the
version gate already required an exact match, and the code said so itself
("the length guards here are vestigial … but they are kept in the existing
style"). A second mechanism standing in front of the version gate, hiding what
it does; keeping it alongside the new assertion would be the same mistake
twice.

`tests/test-pnet-slot-count.rkt` pins the constant so a change to it is
deliberate rather than a quiet adjustment to make the new assertion pass.

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

1. ✅ **RESOLVED — `<`-check-preds work in WS files** (re-probed 2026-08-02).
   `:check (< _ 5)` parses AND the predicate is live: `{:n 3}` validates `ok`,
   `{:n 7}` comes back `err {:n check-failed "(< _ 5)"}`. The passing case alone
   would not have shown that — 3 < 5 either way — so the failing case is the
   test, and both are pinned in `tests/test-punify-surface.rkt`. The prescribed
   `(> 5 _)` workaround is no longer needed.
2. **`match` with an INLINE `validate` scrutinee fails inference** — still open,
   but the 2026-08-03 probe **narrowed it and corrected the diagnosis**. It is
   NOT route-sensitivity in inline-vs-def-bound scrutinee inference; that
   framing is wrong in both directions:
   - an inline APPLICATION scrutinee infers fine
     (`match [cons 1N nil] | nil -> … | cons h t -> …`), so "inline" is not the
     discriminator;
   - def-binding is not the only workaround — ANNOTATING the match
     (`def m : String := match [validate S e] …`) works too, because it
     re-enters CHECK mode. Worth knowing: a user is likelier to reach for an
     annotation than for a `def`.

   **The mechanism, verified**: three deliberate designs compose into a hole.
   (1) `expr-validate` is registered with return-type `#f` — "position stays ⊥
   → the refusal checks re-route to the imperative checker (which owns the
   rule)". (2) `untyped-interior-position` (CIU T6 F1b.2, D26 route-soundness)
   finds that ⊥ interior position after quiescence and re-routes the WHOLE
   command to the imperative checker. (3) the imperative `infer` has NO
   `expr-reduce` case — reduce is check-only there by design. So the network
   declines because of (1)+(2), and the imperative checker cannot take it
   because of (3).

   **This is not validate-specific.** ANY node with a `#f` typing rule
   (`expr-refl`, `expr-cut`, `expr-hole`, `expr-error`) inside a `match` tree
   hits the same wall.

   **Blocked on the SAME owner ruling already recorded elsewhere**: the QTT
   track's deliberate option-(c) deferral, "an `expr-reduce` arm for
   `infer`/`inferQ` — new typing policy" (see § LET track residuals item 3,
   which is the same gap wearing a different symptom: an unannotated `match`
   as a `let` binding VALUE). Fixing it any other way means reversing (1) —
   CIU T6's decision that the imperative checker owns validate — or weakening
   (2), whose over-approximation is deliberately safe. Neither is an
   implementer's call.

   Boundary pinned in `tests/test-validate-match-scrutinee.rkt`: the three
   routes that must keep working, plus the failing one asserted to fail
   LOUDLY — one per-command error naming the term, with the commands on either
   side intact. A wrong type here would be far worse than an error, and that
   assertion is what would catch it. If the policy call lands, the last case is
   the one to flip.

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

**🔶 FIRST SLICE LANDED 2026-08-03 — the census is now mechanical, the
diagnostic is NOT built.** Item 4 asks for a duplicate-binding diagnostic and
notes it "would have made the N6d-i collision census mechanical instead of
forensic". `tests/test-spec-store-clobber.rkt` makes the census mechanical
without deciding the diagnostic's shape (a fifth warning category is a real
addition — struct + cell + register/init/reset + emit + format + driver wiring
— and the DEFAULT-ON-vs-opt-in question is a UX call).

Measured, not asserted: importing `prologos::data::list` and
`prologos::core::collections` into one module makes **12 spec names**
order-dependent — `all? any? concat drop filter find head length map reduce
reduce1 take` — with no error and no warning. The surviving spec depends purely
on import order.

Three findings from building it, all of which cost a wrong first attempt:
- **The collision is at IMPORT PROPAGATION, not `register-spec!`.**
  Instrumenting `register-spec!` (the site item 2 names first) reports ZERO
  collisions for the same program: module bodies each load with a fresh spec
  store, so the overwrite only happens in the IMPORTING module, via
  `current-spec-propagation-handler`.
- **"Last import wins" is FALSE as a general rule.** A first cut asserted it
  and `sum` falsified it. Order-DEPENDENCE is the claim that holds; that is
  what the test locks.
- **A plain prelude load collides zero times**, which is why this has stayed
  invisible — nothing on the ordinary path imports two overlapping modules into
  one place.

Remaining, unchanged: the diagnostic itself, and the trait-registry
(`macros.rkt`) + import-shadowing (`namespace.rkt`) surfaces, which are NOT
censused.

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
- **✏ 2026-08-02 — TRIAGED (answering the D4.P1a entry's "are they one defect?"): YES, one defect.**
  The D4.P1a five-command repro (union def + implicit-binder spec + call) is an
  INSTANCE of this class, and that entry is folded in here. More usefully, the
  repro is **three commands**, and the third is `[int+ 1 2]`:

  ```
  ns w
  def x : <Int | String> := 42
  x
  [int+ 1 2]              ;; ← hangs here
  ```

  Ingredient matrix (each row is one file, 25 s timeout):

  | file | 3rd command | result |
  |---|---|---|
  | union def, USE, `[int+ 1 2]` | application | **HANG** |
  | union def, USE, `[+ 1 2]` | application (trait) | **HANG** |
  | union def, USE, `[+ 1.5 2.5]` | application (float) | **HANG** |
  | union def, USE, `def y := 1` | def | completes |
  | union def, USE, `42` / `"s"` | literal | completes |
  | union def, USE, `x` | variable | completes |
  | union def, `[int+ 1 2]` (no use) | — | completes |
  | `Int` def (not union), USE, `[int+ 1 2]` | — | completes |

  So all three ingredients are required and each is narrow: **a union-typed
  def, a command that USES it, and a later command containing an
  APPLICATION**. Notably `[int+ …]` is monomorphic — so this is NOT trait
  resolution, which the two filed repros (`+`, a polymorphic spec) both
  suggested. Initialising the union def with a String instead of an Int also
  hangs, so it is not the chosen branch either. `[the <Int | String> x]` works
  as the USE, so it is not specific to a bare reference.

  That points at the `:type`-facet union join failing to converge once an
  application's inference joins into it — consistent with the original
  `attribute-map-merge-fn` finding, and a much smaller thing to instrument
  than an 86-command acceptance file.

- **Not blocked** — needs a dedicated debugging session on the typing propagator network.

---

## ✅ CLOSED `6e38d214` — bench-ab.rkt `--refs` for multi-way comparison (issue #63, fixed 2026-08-02)

`--refs HEAD~1` for A/B, `--refs A,B,C` for multi-way, `--md FILE` for a
markdown table, `--output` for JSON. One GIT WORKTREE per ref, built there and
run from there; the benchmark PROGRAMS always come from the working tree, so
what is compared is the compiler and not the input. No stash and no checkout —
the working tree is never touched, which is the standing rule. A ref that fails
to build is reported and EXCLUDED rather than silently measured against the
working tree's driver.

**This closed a live hazard, not just a gap.** The tool DOCUMENTED a `--ref`
flag it never had: the header advertised it, `workflow.md` instructed it, and
`run-ab-comparison` ran the B leg against the same tree with a comment saying
so ("same code for now; with --ref would checkout different code"). Anyone
following the documentation measured identical code twice and read the
difference as a result. Both rules files had been amended to warn that the flag
did not exist; they now describe the one that does.

Consumers named in the original entry (OE Track 1, PReduce Track 4, PAR
scheduler variants) are unblocked.

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

### 🔶 LARGELY DONE — Phase 4: Float32/Float64 (re-probed 2026-08-02)

Listed as pending; it is essentially all present, and nothing was pinning it
BECAUSE the entry said it was not. Now pinned in
`tests/test-numerics-float.rkt`.

| entry item | probe |
|---|---|
| types + literals | `3.14f32` → Float32, `3.14f64` → Float64 |
| Add/Sub/Mul/Div/Neg/Abs | all dispatch: `[+ 1.5f32 2.5f32]` → `4f32` |
| Eq / Ord | `lt`, `le`, `compare` → `lt-ord` |
| Special values ±Inf | `[/ 1.0f64 0.0f64]` → `+inf.0`; `float-finite?` sees it |
| Float↔Rat, Float↔Int, Float↔Float32 | `float-to-rat` → `1/2`, `float-to-int` → `3`, `float-to-float32` |
| "Open: literal form vs Posit (`~3.14` is Posit32)" | resolved by N6c — `~` literals removed, bare `3.14` is Posit32, `3.14f32`/`f64` are the IEEE forms |

**Residual, unverified**: `sqrt` (no `float-sqrt` found), `if-nan`, NaN
specifically, and Float↔Posit. Those are the honest remainder of the list.

**Found while probing** — `[from-int Float64 3]` died on a raw
`surf-from-int: arity mismatch` at parse time, taking the whole file.
`from-int` and `from-nat` were in the BINARY operator table while their
constructors are unary, so the binary arm called a 2-argument constructor with
three. One argument reached the application path and worked, which is why it
went unnoticed. Moved to the unary table; now a per-command "from-int expects 1
argument, got 2".

- Source: `docs/tracking/2026-02-19_NUMERICS_TOWER_ROADMAP.md`

### Numeric Literal Polymorphism
- `42` polymorphic via `FromInt` — research/future
- Source: `docs/tracking/2026-02-22_NUMERICS_ERGONOMICS_AUDIT.org`

---

## Collections — Deferred Items

### 🔶 PARTIAL — Stage I: Transducer Runners for Non-List (re-probed 2026-08-02)

**`into-vec`, `into-set` and `into-list` EXIST and are importable** from
`prologos::core::collections` — a real module with an `ns` — and have since
commit `7c04a89f`. Verified end to end: `[into-vec [list-to-lseq Int xs]]`
gives `@[1 2 3] : [PVec Int]`. Pinned in
`tests/test-collection-runners.rkt`, contents and all, since a runner that
produced an EMPTY PVec would satisfy the type check.

**Still open**: the TRANSDUCER-PROTOCOL form of these, and pipe fusion for
non-List inputs. Those are what the "transient types not exposed at Prologos
type level" note is about. The runners themselves were never blocked on it.

**A correction to an earlier note in this same session.** I first probed these
by importing `prologos::book::collection-functions`, which is a chapter file
with no `ns` and therefore not importable, and concluded the functions were
unreachable — writing exactly that into this entry. They were reachable from
`core::collections` the whole time. (That probe was not wasted: the import
failure was a raw `ns-context-refer-map` contract violation, now a named error
— see the imports fix above.)

- Pipe fusion for non-List input types
- **Blocked on**: transient types not exposed at Prologos type level;
  pipe fusion requires elaborator changes

### HKT Partial Application for Map Trait Instances — CONFIRMED (probed 2026-08-02)

Stands as filed, and the probe says why cleanly: `Seqable`/`Buildable`/
`Reducible` instances exist for List, LSeq, PVec and Set — all of which are
ALREADY `Type -> Type` — and for Map alone there is none, because `Map K` needs
partial application to have that kind.
- **Blocked on**: unbuilt type system feature

### `Seq` as Proper Trait (deftype → trait migration) — CONFIRMED, and narrower than it reads (probed 2026-08-02)

`deftype [Seq $S] …` is at `book/collection-traits.prologos:118` — still a
deftype, so the entry stands. What it does NOT mean is that the collection
traits generally are deftypes: `Seqable`, `Buildable`, `Foldable` and
`Reducible` are all proper `trait` declarations in
`core/collection-traits.prologos`, with instances for List, LSeq, PVec and Set,
and generic `map`/`filter`/`reduce`/`length`/`to-list` dispatch through them
(verified: `[length xs]` on a List → `3N`).

So this is one straggler in a family that already migrated, not a pending
migration of the family.

**Sharpened 2026-08-03 — what a migration would actually cost.** Two
hypotheses were checked and BOTH were wrong, so they are recorded rather than
left for the next person to re-form:

- *"It is a pedagogical contrast — the book chapter shows the dictionary
  encoding on purpose."* NO. Both `core/collection-traits.prologos` and
  `book/collection-traits.prologos` carry EIGHT `trait` declarations and
  exactly ONE `deftype`, in the same file, with no framing that distinguishes
  it. It really is an inconsistency.
- *"It is dead vocabulary, so migrating it satisfies nobody."* NO. There is a
  live instance: `def list-seq [pair list-seq-first [pair list-seq-rest
  list-seq-empty?]]` with `spec list-seq [Seq List]`, hand-assembled as a
  nested Sigma, in BOTH `core/list.prologos:144` and `book/lists.prologos:713`,
  and `tests/test-trait-impl-04-02.rkt` passes it explicitly to `seq-length` /
  `seq-drop` / `seq-any?` / `seq-all?`.

So the migration is real work with a real consumer: `trait Seq {S : Type ->
Type}` + `impl Seq List` replacing the hand-assembled dict, the three
accessors reworked from explicit `fst`/`snd` projection to where-constraints,
across two library files, with `test-trait-impl-04-02`'s explicit-dict call
sites to convert.

**And the "design uncertainty" now has a name**: migrating puts three new
trait-METHOD names (`first` / `rest` / `empty?`) into the global method
namespace — the same bare-name namespace whose silent last-write-wins is
censused in `tests/test-spec-store-clobber.rkt` (issue #66/#67, 12 names
already order-dependent). `empty?` in particular is a name the collection
family is likely to want more than once. That is the collision question to
settle BEFORE the migration, not after.
- **Blocked on**: the method-name collision question above (issue #66), not on
  deftype-vs-trait dispatch, which the four migrated siblings already settled

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

### ✅ SHIPPED — Phase 4a: Grapheme Cluster Operations (2026-08-02)

`str::grapheme-count`, `str::grapheme-span`, `graphemes`, `grapheme-reverse`.

**The entry's "Mitigation" was the whole answer.** It reads as though UAX #29
tables were the work and the FFI bridge a fallback; the bridge IS the
implementation, because Racket already carries the tables. A ZWJ family emoji
comes back as one cluster from five code points. Two lines of `foreign racket`
plus a walk over `grapheme-span`.

Worth noting how close this came to not being tried: it was written off in the
same breath as sorted collections and regex, on the strength of "~30KB Unicode
tables" — while the line directly beneath it said what to do instead.

**Tested where clusters and code points DIFFER**, since ASCII proves nothing
here — `graphemes "abc"` is right whether or not the implementation understands
clusters. The load-bearing case: reverse NFD `"éa"` by grapheme and re-compose,
which gives `"aé"`. A code-point reverse moves the accent onto the `a` and
composes to `"áe"` — same length, same grapheme count, different string. Only
comparing content catches it.

### ✅ SHIPPED `1e00ac95` — Phase 4b: Unicode Normalization (2026-08-02)

`normalize : NormForm -> String -> String` with `nfc` / `nfd` / `nfkc` / `nfkd`,
bridged to Racket's implementations as the entry specified.

**Split across two modules, and the split is not cosmetic.** The four FFI
bindings live in `prologos::data::string` beside the other Racket bridges; the
`NormForm` type and the `normalize` dispatcher live in
`prologos::core::string-ops`, because `data/string.prologos` is a prelude-less
leaf and a `match` over a user `data` needs machinery it does not have. Putting
the type there fails the module load with a bare "Type mismatch" — worth knowing
before adding any other `data` to a leaf lib module.

`tests/test-string-normalize.rkt` asserts PROPERTIES of each form rather than
snapshots: NFD lengthens a precomposed character, NFC shortens a decomposed one,
NFKC folds a ligature, NFKD folds a circled digit, and — the one that matters —
NFC does NOT fold the ligature, so the canonical/compatibility distinction is
pinned in both directions. One case checks that NFC and NFD disagree at all,
which is what rules out a dispatcher that ignores its form argument.

### ✅ SHIPPED — Phase 4c: String Similarity & Diffing (2026-08-02)

`common-prefix`, `common-prefix-length`, `common-suffix`,
`common-suffix-length`, `levenshtein`, and `closest` (the "did you mean?"
helper the entry named as the use), all in `prologos::core::string-ops`.

**A correction to what this entry said an hour earlier.** It was filed as
PARTIAL, with edit distance declared unwritable: the row-wise DP came back as a
stuck term, and I concluded that "a standard dynamic program cannot be
expressed efficiently here today" and that this constrained Myers diff and Jaro
too.

That was wrong, and wrong in a way worth recording. The diagnosis was right —
each cell's value is needed twice, computing it inline doubles the work per
cell, and the whole thing goes exponential — but the conclusion was not. I had
tried a MULTI-LINE `let` (a parse error in that position) and parameter-passing
(no sharing under lazy reduction), and generalised from two failures to "no
sharing construct works here". The BRACKET `let` on one line works, gives
sharing, and edit distance evaluates: `kitten`/`sitting` = 3.

Two failures are not a survey. The entry claimed a language limitation on that
basis, which would have been read as settled by whoever picked up Myers diff.

Tested against the shape of the bug rather than around it: the
identical-strings case is the 3×3 that used to return a stuck term, so
"returns a number at all" is the assertion; `flaw`/`lawn` catches an
implementation that only walks one diagonal; and `closest` is pinned to answer
`none` when nothing is within the limit, since a confident wrong suggestion is
worse than none.

Myers difference is still not implemented — it is a different algorithm, not
blocked by this.

### 🔶 PARTIAL — Phase 4d: Regex Integration (2026-08-02)

`str::regex-match?`, `str::regex-replace`, `str::regex-replace-all`,
`str::regex-quote` — bridged to Racket's engine.

The entry deferred this on "depends on a regex library (not yet designed)". A
Prologos-level regex AST is indeed undesigned; the RUNTIME has an engine, and a
string-pattern bridge needs no new type. Fourth section this session where
"blocked" turned out to mean "not tried".

**Known trade, stated rather than hidden**: the pattern is a STRING, recompiled
by Racket on every call. Correct, and slower than a compiled pattern in a loop.
When the Prologos-level design lands it can add a compiled `Regex` handle
without changing what these signatures mean.

**Syntax is Racket `regexp`, not `pregexp`** — `\d` and `\w` are pregexp-only;
write `[0-9]` and `[a-zA-Z0-9_]`.

**Still open**: the designed API — a `Regex` type, compiled patterns, match
GROUPS (the bridge returns Bool, not captures, because a capture list needs
list marshalling across the FFI), and split.

Tested where a wrong implementation would still pass a naive test: `match?` in
BOTH directions; `replace` vs `replace-all` against each other, since a test of
one would not notice them wired to the same function; and `regex-quote` with an
assertion that the UNQUOTED pattern does match, so the escaping test cannot
pass vacuously.

### Phase 4e: Rope / TextBuffer Type
- B-tree rope with O(log n) concat/split

---

## Spec System — Phase 2+

### 🔶 Phase 2: Example and Property Checking (QuickCheck-style) — EXAMPLES now checked (2026-08-03); properties/generation still open

Accurate on the CHECKING, which is what the entry is about. Decisive probe: a
deliberately wrong `:examples [[2 999]]` on a doubling function is accepted
silently, 0 errors.

Worth knowing before starting, though: the metadata SURFACE is done.
`:examples`, `:pre`, `:post`, `:properties` all parse and are stored
(`macros.rkt` :3791-3848), and some validation already runs — an error for
`:invariant` combined with `:pre`/`:post`, and a warning when a property's
`:where` constraints are not covered by the spec's. So this phase is the
checker, not the syntax.
- ✅ **DONE 2026-08-03 — run `:examples` entries as tests.** The stored
  examples are now CHECKED at the point the definition they describe first
  exists, on BOTH def seams (inferred and annotated — wiring only one means an
  example silently stops being checked the moment someone adds a type
  annotation). The entry's own repro is the test: a wrong `((dbl 2N) => 999N)`
  on a doubling function is now a per-command error naming the example, what it
  really evaluates to, and what was claimed.

  **Deliberately narrow, and the narrowness is the design.** Only a genuine
  value mismatch between a call and an expected value that BOTH evaluated
  cleanly is reported. Anything that fails to elaborate or evaluate is SKIPPED,
  because an example may legitimately name a helper defined later in the file
  or a type whose instance arrives with a later `impl` — reporting those would
  make `:examples` unusable in exactly the files that most want it. Two of the
  five tests pin that boundary rather than the happy path.

  Reentrancy is guarded at every step: this runs INSIDE a definition's commit,
  so an escaping raise would cost the command that just succeeded.

  Still open in this phase: the `Gen` trait for type-directed random
  generation, property checking for `:properties` / `:laws`, `:pre`/`:post`
  contract wrapping with blame, and the variance / `:compose` / `:identity` /
  `:exists` work below.
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

### Galois Connections — Remaining Deferred — CONFIRMED (probed 2026-08-02)

`connect-domains` does not exist anywhere in the tree, so that half stands. The
substrate it would wrap does: `GaloisConnection` with `-alpha`/`-gamma`
accessors and an `Interval` domain are in `prologos::core::lattice`, with 14
passing tests in `test-galois-connection.rkt`.
- `connect-domains` Prologos-level wrapper (needs AST keyword or FFI)
- Additional abstract domains (Congruence, Pointer, etc.)
- Source: `docs/tracking/2026-02-27_1026_GALOIS_CONNECTIONS_ABSTRACT_INTERPRETATION.md`

### Propagator-First Phase 3e: Reduction Cache Cells — CONFIRMED NOT STARTED (probed 2026-08-02)

`current-track-reduction-deps?` does not exist in the tree, so not even the
gating parameter has been added.
- Convert whnf/nf/nat-value caches to write-through cells
- Gated behind `current-track-reduction-deps?` parameter (off for batch, on for LSP)
- **Risk**: Performance regression in batch mode
- Dependencies: Phase 3a (per-definition cells), Phase 3b (dependency recording) — both complete

---

## FL Narrowing — WS Surface Gaps (1 of 3 open: higher-order narrowing in WS)

### ✅ RESOLVED — Nested Constructor Patterns in Match Arms (re-probed 2026-08-02)

The entry said `| suc zero -> body` treats `zero` as a variable, so the arm
would match any `suc m`. It does not:

```
defn pred [n]
  match n
    | suc zero -> 99N
    | suc m    -> m
    | zero     -> 0N

pred 1N  => 99N     pred 3N => 2N     pred 0N => 0N
```

`pred 3N` is the discriminating case — a variable reading would make it 99.
Now pinned in `tests/test-reader-robustness.rkt`; nothing was pinning it
before, precisely because this entry said it was broken.

### Higher-Order Narrowing in WS Mode — CONFIRMED STILL TRUE (re-probed 2026-08-02)

`narrow [apply-op ?f 3N 2N] = 5N` returns `nil` in a `.prologos` file — no
solutions, no error. The infrastructure works at sexp/API level (23 tests
pass); the WS pipeline does not reach it. Unchanged since 2026-03-08.
- Fix requires deeper integration between narrowing substitution env and DT body traversal
- Source: C3 analysis, 2026-03-08

### ⬜ NOT REPRODUCIBLE — Multi-arity `|` relation variants — zero-arg solve path

Filed as "`solve-goal`'s zero-arg path infers arity from first variant only;
fix: iterate all variants or require explicit args for multi-arity rels".
Probed 2026-08-03 and **the trigger is not constructible at HEAD**, so the fix
has nothing to fix. Reclassified rather than deleted, because the underlying
single-`arity` field is real and the note is where this belongs if variants
ever become arity-heterogeneous.

What the probes show:
- **A `defr` has ONE param header, so its variants cannot differ in arity.**
  `defr p [?x]` with a `|| 2 3` row does not create a 2-ary variant — the row
  CHUNKS by the header arity into rows `2` and `3` (probed: `1 2 3`), which is
  the documented facts-block behaviour.
- **Redefining `defr p` at a different arity REPLACES rather than
  accumulates**, so there is still exactly one arity per name. A stale-arity
  query then gets the guided SWI-style error — "Unknown procedure: p/1 —
  however, there are definitions for: p/2" — not a silent wrong answer.
- **The zero-arg path works** against whichever relation is current:
  `(p)` on a 1-ary `p` returns one empty row per fact.
- `relation-info-arity` has exactly ONE reader in the tree
  (`relation-register`, rebuilding the struct); nothing dispatches on it.

Re-open only with a repro in which one relation NAME carries variants of
differing arity.

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

### Full Concurrent Session Execution (NOT STARTED) — CONFIRMED (probed 2026-08-02)

Accurate. The TYPE side of async exists — `sess-async-send` / `sess-async-recv`
are in `session-lattice.rkt` — but there is no concurrent runtime: no thread or
place usage outside tests and tools, and no multi-network scheduling.
- Buffered channels, `!!`/`??` runtime distinction, multiple concurrent prop-networks
- Distributed propagator scheduling, promise cell lifecycle, fairness guarantees
- **Blocked on**: Multi-network runtime infrastructure, Racket-level concurrency primitives
- Source: `docs/tracking/2026-03-03_SESSION_TYPE_IMPL_PLAN.md`

---

## IO Library — TRIAGED 2026-08-02 (3 done; the 4th's open half verified + reclassified 2026-08-03)

Four of the five entries below were probed. Three describe work that is
implemented AND has passing tests; a fourth is half stale. Nothing here was
built by this triage — it was all already in the tree.

### 🔶 Dependent Send/Receive (`!:`/`?:`) (Phase IO-J) — HALF STALE (re-probed 2026-08-02)

"Runtime predicates exclude dsend/drecv" is no longer true: `io-bridge.rkt`
:111-112 includes `sess-dsend?` / `sess-drecv?` in both `io-sess-send?` and
`io-sess-recv?`, and the constructors are live in `session-lattice.rkt` and
`session-propagators.rkt`. `test-io-dep-session-01/02.rkt` pass (22 tests).

The other half — "elaborator discards binder name" — is **VERIFIED 2026-08-03,
and reclassified: TRUE but not an IO defect.** Repro: `session DepNamed / !:
myname Nat / ! myname / end` displays as `[![x <Nat>] . [!x . end]]` — the
source name `myname` is gone and `x` is synthesised.

There is no name field to discard INTO: `sess-dsend` / `sess-drecv` are
`(type cont)`, which is the system-wide de Bruijn convention rather than a
session oversight. `expr-Pi` is `(mult domain codomain)` and `expr-lam` is
`(mult type body)`, equally nameless, and `pp-expr` synthesises display names
with `fresh-name` for all of them — a lambda parameter loses its name
identically (pinned as the control).

So retaining source names is a **binder-provenance feature spanning every
binder in the language** — a presentation-design decision, sibling to the
`?`-field display ambiguity and the FQN-display-verbosity question, and not an
implementer's call. Both facts are pinned in `test-io-dep-session-01.rkt` as
CURRENT behaviour, so the claim no longer rests on nobody having tried it, and
whichever assertion changes marks the day provenance lands.
- Reader, preparse, surface syntax, parser, IR, type-checker, pretty-printer are ALL complete
- Source: `docs/tracking/2026-03-05_IO_IMPLEMENTATION_DESIGN.md` §7

### ✅ DONE — IO Bridge Propagators (Phase IO-B) (re-probed 2026-08-02)

`io-bridge.rkt` provides `make-io-bridge-cell` and `make-io-bridge-propagator`
with the IO state lattice. `test-io-bridge-01.rkt` passes — bot identity, top
absorbing, valid/invalid transitions, idempotence, cell creation at io-bot.
- Source: `docs/tracking/2026-03-05_IO_IMPLEMENTATION_DESIGN.md` §5

### ✅ DONE — Boundary Operations (Phase IO-C / IO-J) (re-probed 2026-08-02)

`test-io-boundary-01.rkt` passes: channel creation, session cell init, read
delivering to msg-in, write sessions, a nonexistent file going to io-top,
session end closing the port, and `proc-open`. It was listed as blocked on IO
bridge propagators, which are themselves done.
- Source: `docs/tracking/2026-03-05_IO_IMPLEMENTATION_DESIGN.md` §6

### ✅ DONE — Opaque Type Marshalling (Phase IO-A1) (re-probed 2026-08-02)

`expr-opaque` exists in `syntax.rkt`, is marshalled in `foreign.rkt` (:239,
:332) and walked in `reduction.rkt` (:3799, :4671). `test-io-opaque-01.rkt`
passes, 13 tests.
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

## Relational/Unification — PUnify Surface Gaps — TRIAGED 2026-08-02 (5 of 7 stale)

All seven came from one acceptance file's section notes. Re-probed; five no
longer describe the compiler, and are now pinned in
`tests/test-punify-surface.rkt` — because a DEFERRED entry saying "X is broken"
suppresses the test that would catch X regressing, which is exactly what
happened with the nested-constructor-pattern entry above.

### ✅ RESOLVED — Module-path (`::`) resolution in defr clauses
`(is s [str::append "a" "b"])` inside a `defr` clause gives `"ab"`.

### ✅ RESOLVED — solve-one type inference in defn body
`defn one-sol [u] solve-one (edge a b)` types as `_ -> {:a Int :b Int}`, not
`_`. Both `solve` and `solve-one` derive the row type.

### ✅ RESOLVED — `=` with prelude constructors in defr body
`(= o [some 1])` inside a `defr` clause works. (Minor residual: the row TYPE
shows `:o _` while the value is right — the same static/runtime row-type
question the solver-collection fix addressed for maps, one notch further out.)

### ✅ NEVER A DEFECT — Parameterized types in data constructor arguments
The entry's example, `data Box A := box [List A]`, is not Prologos syntax — a
syntax error filed as a type-system gap. Written as `data Box {A : Type} | box
[List A]` it works and the constructor gets its Pi type.

### ✅ RESOLVED — `eq?` trait method not in prelude scope
`[eq? 1 1]` and `[eq? "a" "a"]` both give `true`. The listed workaround
(concrete `int-eq` / `str-eq`) is unnecessary.

### ⤳ MOVED — head + match inference failure
`def h := [head '[1 2 3]]` fails, and it is the SAME defect as the merged
higher-order-on-a-def-RHS entry above (bare command works, `def` RHS does not).
Tracked there; not a separate item.

### ⬜ STANDS — Narrowing limited to constructor-based patterns
Functions with Int literal patterns compile to `boolrec`+`int-eq`, not
invertible for narrowing. The entry calls it a design limitation and it is.

## ✅ CLOSED — Surface Syntax Issues (TRIAGED 2026-08-02; all three sub-items resolved or reclassified, header corrected 2026-08-03)

### ✅ RESOLVED — WS-Mode `:=` Body Parsing with Multi-Form Bodies

The entry said `def x : List Nat := cons 1N [cons 2N nil]` fails because
`expand-def-assign` requires exactly one form after `:=`. It does not: it wraps
a multi-token RHS as an application, which is the fix the entry asked for.
Verified with the entry's exact example, with and without the annotation, and
with the source file's own `def sample-list : List Nat := cons 1N [cons 2N
[cons 3N nil]]`.

`examples/unified-matching.prologos` carried that line COMMENTED OUT under an
"Ideal syntax (commented out — WS := body parsing issue)" note. It is
uncommented and the file runs 0 errors. The note outlived the behaviour it
described — worth remembering when reading an example's own ISSUE comments.

### ⬜ NOT A DEFECT — Multi-Bracket defn

`defn f [a] [b] body` does not work in either mode, and the entry itself says
the standard pattern is the uncurried single-bracket form —
`prologos-syntax.md` makes that the convention ("Uncurried"). So this is a
design NON-GOAL, not a gap. It produces a clean per-command error naming what
it expected, not a crash. Reclassified rather than closed: if curried `defn`
is ever wanted, this is where the note lives.

### ✅ SUPERSEDED — WS Mode Path Expression Disambiguation (`.{`)

The `.{` conflict has a ruling and a diagnostic since CIU T6 D4.P1b-ii:
`cfg.{a}` at top level now gives the guided per-command error "a `.{…}`
sub-block belongs inside a select block — write `x{server.{host port}}`; at top
level, `x{…}` selects and `x.k` accesses". The entry predates that work.

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

## ✅ FIXED 2026-08-03 — a higher-order list function on a `def` RHS failed; the same expression as a bare command worked (merged + re-probed 2026-08-02, fixed 2026-08-03)

The entry was accurate throughout, including its two negative findings (not
about first-class operators; the offered `plus`/`minus` workaround does not
exist), and its "where to start" pointer at `pipeline.md` § "infer / inferQ Are
Twins" named the right SHAPE. The cause was one layer under that: not a missing
`inferQ` arm, but a comparison the two passes make differently.

**Two independent faults, each with a lying diagnostic.**

1. **"Multiplicity violation" was a KIND mismatch.** A type constructor's kind
   is `Pi m0 Type Type` — its type argument really is erased — while a spec's
   `{C : Type -> Type}` writes an unannotated arrow, which defaults to `mw`.
   `subtype?` demanded the two multiplicities be IDENTICAL, so `List` did not
   fit `C` and the whole application spine failed to infer.

   It reached only the QTT pass because typing-core sees `C` as an unsolved
   META, and meta-solving never compares multiplicities — only the post-freeze
   QTT check meets the concrete `List`. That is why the bare command worked:
   it runs no `checkQ-top` at all. The command "working" was never evidence
   the term was well-formed.

   Fixed in `subtype-predicate.rkt`, and not by new policy: Pi multiplicity is
   an UPPER BOUND on the function's use of its argument, and `compatible 'mw
   'm0` is already `#t` everywhere else in the system. The new arm applies that
   same predicate structurally (normalize t1's mult to t2's, then delegate to
   the existing structural walk), so it loosens exactly as far as `compatible`
   and no further — `mw <: m1` stays false, which is the unsoundness the
   ordering exists to prevent.

2. **"Expression is not a valid type" ran `is-type` on an UNZONKED type.** An
   implicit higher-kinded argument leaves a meta-headed application behind,
   which is not a type by inspection. The tell was inside the message: it
   renders with `pp-expr`, which DOES follow solutions, so it printed
   "not a valid type: [List Int]" — naming a valid type. A diagnostic that
   pretty-prints through a resolution its own predicate did not perform will
   always read as nonsense; that mismatch is the thing to notice. Fixed by
   zonking before the check (intermediate `zonk`, not `freeze` — a genuinely
   undetermined type must still fail).

All six lines of the entry's sharp repro now work, `def a : Int := reduce + 0
'[1 2 3]` works on the annotated seam too, and a HOF inside a spec'd `defn`
returns a real value rather than the stuck term the entry recorded.

Pinned by `tests/test-hof-def-seam.rkt`. Every case is a `def` — the bare
command passed throughout and proves nothing here — plus one that asserts the
def and the command PRINT IDENTICALLY, since the disagreement was the defect,
and a unit table for the multiplicity relation in both directions.

**Found while probing, NOT this defect — ✅ FIXED 2026-08-03**: an unbracketed
application as a `defn` body (`defn bump [x] int+ x 1`) reported, WITH a spec
present, "Type mismatch … `[fn [x <Int>] [fn [y <Int>] [fn [z <Int>] [int+ y
z]]]]`" — a message about a three-parameter lambda the user never wrote.

Two faults, and the first hid the second. `inject-spec-into-defn` spliced
`,@body-forms` unconditionally, so three body forms became
`(defn bump [x <Int>] <Int> int+ x 1)` — which parses as a THREE-parameter
typed defn, bypassing the parser's bare-params guard entirely. WITHOUT a spec
the same source already produced a proper parse error, so the two paths
disagreed about the same mistake and only the spec'd one was misleading.

Fixed by DECLINING to inject (rather than raising — this runs inside
`preparse-expand-all`, where a raise costs the whole file) so the parser's
guard speaks, and by making that guard name the actual mistake instead of the
return-type slot: *"defn bump: the body looks like an application written
without brackets — write `[int+ …]`."*

⚠ **The guard's BARE-SYMBOL head is load-bearing, and the obvious predicate is
wrong.** "A well-formed defn under a spec has exactly one body form" is FALSE:
a `let` CHAIN is legitimately several forms at injection time, because the
sibling-chain merge runs later. Declining on mere multiplicity dropped the
spec's types for every specced let-chain defn and broke two `test-let-blocks`
cases — caught by the suite, not by reasoning. Those forms are LISTS; only the
unbracketed-application mistake leads with a bare symbol.

Pinned in `test-error-messages.rkt`, including an assertion that the spec'd and
un-spec'd paths now report the SAME message (a test on either alone would have
missed the disagreement that was the whole defect) and the specced let-chain
control.

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

### ✅ RESOLVED — Compiled Module Cache (BUILT already; probing it 2026-08-03 found a WRONG-ANSWER bug, fixed same day)

**Built and on by default.** The `.pnet` cache is the feature this entry asked
for: `pnet-path-for-module` keys by module name, `pnet-stale?` gates on file
existence + `infrastructure-stale?` (driver.zo newer than the cache) + exact
`PNET_VERSION` equality + `source-hash-for-module`, and
`current-use-pnet-cache?` defaults `#t`. The entry predates it.

**🐛 But `source-hash-for-module` is path + MTIME, not a content hash, and
there is NO transitive-dependency invalidation — so a stale cache returns a
WRONG ANSWER, silently.** Its own comment admits the shape ("Full
implementation would hash file contents + transitive deps"); what was missing
was that this is a correctness bug rather than a freshness nicety.

Verified repro (2026-08-03), three modules, one edit:

```
prologos::dep::base   defn basev [x] [int+ x 1]
prologos::dep::mid    imports base;  defn midv [x] [basev x]
user                  imports mid;   def r := [midv 10]     ;; => 11
```

Edit `base` to `[int+ x 100]` and re-run **the user file only**:

| condition | result |
|---|---|
| cache ON, `mid.pnet` present | **11** ← WRONG, pre-edit answer |
| cache OFF (`current-use-pnet-cache? #f`) | 110 ✓ |
| cache ON, `mid.pnet` deleted | 110 ✓ |

`mid`'s own mtime never changed, so `pnet-stale?` calls it fresh, and `mid`'s
cached env snapshot still carries `base`'s old contributions. Nothing warns.

**Why it has stayed invisible**: `infrastructure-stale?` invalidates
everything whenever `driver_rkt.zo` is newer, so any RACKET edit sweeps the
cache — which is most development. The exposure is edits to `.prologos`
LIBRARY sources with no Racket change, and the repeated `PNET_VERSION` bumps
recorded in `pnet-serialize.rkt` (v3→v7, several of them explicitly "stale
cache made the suite green/red wrongly") are the same class hitting from
different directions.

**✅ FIXED 2026-08-03 — option 1 taken.** `pnet-stale?` now also consults
`lib-sources-stale?`: the newest mtime of any `.prologos` under the lib paths,
compared against the cache file. Deliberately blunt, and choosing it is not a
new policy — it is the SAME SHAPE as the `driver_rkt.zo` check directly above
it, applied to the second input class. A `.pnet` is a function of the Racket
compiler AND of every `.prologos` that fed it; the zo check already answers
"the compiler changed", this answers "a library source changed".

Cost, measured: the scan is ~60 ms once per process (memoized), and is paid
only when a lib source is actually edited. Suite 542 files / 10472 tests at
212 s, inside the documented 5-10% variance band, and a warm run still reports
"55 prelude module caches ready" — the cache is still being HIT, which is the
thing a careless fix would have destroyed.

Option 2 (record each module's dep list in its `.pnet` and walk it
transitively) remains the better answer if the blunt invalidation ever bites
in practice; it needs the dep-edges field re-added with a consumer, having been
retired as write-only at PPN 4C Addendum Phase 4B.1.

**Two implementation traps, both caught by tests rather than by reasoning**:
- **The memo must be KEYED BY THE LIB PATHS.** `current-lib-paths` genuinely
  varies within a process — every test that builds a temp lib rebinds it — so
  a single unkeyed box answers for the wrong directory set. The first cut used
  one box and turned `test-pnet-registry-restore`'s intended cache HITS into
  misses, failing two assertions written precisely to catch "a MISS produces
  the correct answer and proves nothing".
- **A test for this needs THREE phases, not two.** "Edit → new answer" also
  passes if the cache never hits at all — which is the easiest way to "fix"
  this and the worst. `tests/test-pnet-dep-staleness.rkt` asserts a warm run
  still serves the OLD answer from cache BEFORE any edit, and only then that
  the edit is seen. It also resets the MODULE REGISTRY per run: a module
  already registered is never re-loaded from disk at all, so a shared registry
  makes phase 3 report phase 1's answer regardless of the cache. Verified to
  fail against the unfixed code.

- Source: `docs/tracking/2026-02-19_PIPE_COMPOSE_AUDIT.md`

### Bytecode Compilation
- Compile `.prologos` to intermediate format, skip parse/elaborate/type-check
- Deferred until language stabilizes
- Source: `docs/tracking/2026-02-19_PIPE_COMPOSE_AUDIT.md`

### ✅ RESOLVED — Batch-Worker Isolation: 12 Tests Fail in Suite, Pass Individually (re-probed 2026-08-02)

All twelve named files were run TOGETHER through the batch runner
(`--tests` × 12, 4 workers): **166 tests, all pass**. They also pass in every
full-suite run this session (530 files green, sequential and parallel).

The entry's symptom — unsolved dict-metas `[?metaNNNN …]` in batch, resolving
correctly under `raco test` — does not reproduce. Whatever fixed it is not
recorded here; the likely candidates are the Track 4B follow-ups the entry
itself anticipated, or the per-file network forking since added to
`test-support.rkt` and `batch-worker.rkt`.

Left as a marker rather than deleted: the entry names a specific, useful
diagnostic shape (unsolved dict-metas as a batch-vs-individual divergence), and
this session found the SAME shape from a different cause — the cell-backed
spec-store leak, closed above. Worth keeping the sighting on file.

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

## ✅ CLOSED `10f5a080` — solver term conversion drops pvec/map literals (captured 2026-07-25, fixed 2026-08-02)

Not in the conversion functions the entry named. `ground->prologos-expr`
(reduction.rkt) filtered AST nodes through a HAND-ENUMERATED list of thirteen
predicates in front of an `unknown` fallback:

```racket
[(or (expr-zero? v) (expr-suc? v) … (expr-champ? v) (expr-lam? v) (expr-pair? v)) v]
[else (expr-fvar (if (symbol? v) v 'unknown))]
```

Maps and vectors were not on it, so they fell through and the fallback returned
the SYMBOL `unknown`, quietly. That is the exhaustive-walker shape `pipeline.md`
warns about, in a place nobody had looked for it — the third instance found this
session, after the `expr-foreign-fn` walkers and the mixfix raise sites.

Fixed structurally: `(expr? v)`. The fallback exists to catch RAW RACKET values
arriving from the solver's normalization boundary — strings, booleans, integers,
all handled just above — not to filter AST nodes. Every expr passes through now,
including the ones added tomorrow.

Verified for map, list AND pvec. The runtime row now agrees with the static row
type (`:v {:a 1}` under `{:v {:a Int}}`), which was the entry's real point:
this was the one place the two provably disagreed.

**Why it survived**: scalars were always fine. A test written with a string or
an integer literal passes either way, so the control case is in the test file
alongside the three that fail without the fix.

Unblocks the B3.2 FILL path, whose only reachable surface case this was
blocking.

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
> ✅ **`occurs?` HALF DONE 2026-08-03 — it WAS unsound, and is fixed.** The
> probe the entry asked for, run: `occurs?` answered **#f** for a meta held as
> a champ VALUE and as an hset KEY, while answering #t for the bare meta, a
> Record field and a plain application. An unsound occur-check that would admit
> a cyclic solution, exactly as feared.
>
> Cause: `occurs?` walks structs generically via `struct->vector`, and a
> champ/hset/rrb stores its entries in a RACKET VECTOR inside its nodes —
> `(vector? …)` is not `(struct? …)`, so the walk stopped dead there. One
> `vector?` arm closes it; verified on champ value, hset key and rrb element,
> with a different-meta negative so the fix is not simply "yes".
>
> **Why this half was fixable and the others are not**: `occurs?` is READ-ONLY.
> `zonk` / `zonk-at-depth` / `default-metas` SUBSTITUTE, and substituting inside
> a champ rewrites keys whose stored hashes were computed from the old ones —
> that side needs the reconstructive treatment `nf`'s NbE fix and the
> `champ-sentinel` serializer already use. Reading needs no such care, which is
> why it is one line here and a design slice there.
>
> ✅ **`conv-nf` ALSO DONE 2026-08-03 — verified, and INCOMPLETE rather than
> unsound.** Same cause, same one-arm fix, opposite failure direction: the
> struct walk stopped at the entry VECTOR, so container entries fell to
> `equal?`, which is STRICTER than conv — no hole-as-wildcard, no
> meta-identity rule. Probed: a hole inside a champ VALUE or an rrb ELEMENT
> did NOT act as a wildcard, while a bare hole did.
>
> So it answered #f where conv should say #t: it could REJECT a valid
> conversion, never ACCEPT an invalid one. Worth stating precisely, because it
> is the reverse of `occurs?`'s failure and only one of the two was a soundness
> bug. Both negatives are pinned alongside the positives — a "fix" that simply
> returned #t for containers would satisfy the positives on its own.
>
> **Still open**: the `zonk` / `zonk-at-depth` / `default-metas` half — the
> SUBSTITUTING walkers. Both read-only members of the family are now closed;
> what remains needs the reconstructive treatment, because substituting inside
> a champ rewrites keys whose stored hashes came from the old ones. The #58 P3
> `loose-bvar` memo coupling below applies to THAT half — neither `occurs?` nor
> `conv-nf` memoizes.
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

1. ✅ **FIXED 2026-08-03 — guiding diagnostics now reach the def seam.**
   `def bad := (dbl 3)` and `def bad := solve (dbl 3)` both give
   *"solve: dbl is a function — application is written [dbl …]; parens make a
   relational goal"* — the same message top level always gave.

   Taken as the entry prescribed ("give the def seam a pre-typing goal-head
   validation"). `raise-unknown-relation-error` is EXPORTED and called from the
   def arm BEFORE typing, with its raise converted to an ordinary per-command
   error. One derivation, two consumers — re-deriving the classification would
   have been the `infer`/`inferQ` twin-drift shape.

   Order is load-bearing: after typing, the failure is already a non-type and
   the head is unrecoverable, which is exactly why the message never arrived.

   `tests/test-rel-t1-pol.rkt` was WRITTEN to catch this — "pinned so a future
   diagnostic fix shows" — and it did, asserting the old
   `"not a valid type"` text. Updated rather than deleted: PARITY between the
   two spellings is the invariant and still holds; only the message both get
   changed. Two tests added — that the def seam and TOP LEVEL now classify a
   bad head IDENTICALLY (the property, not the string), and that a REAL
   relation on a def RHS still works, since without that control "every def
   errors" would satisfy the parity assertion too.

   **Item 2 below is unchanged**: row-type annotations on `def` still do not
   parse.

   Original filing follows.

**Original item 1**: `def bad := (dbl 3)`
   (or `:= solve (dbl 3)`) dies with the generic *"Expression is not a valid
   type"* — the def arm type-checks the body BEFORE evaluation, so the runtime
   classifier (`raise-unknown-relation-error`, relations.rkt) never fires and
   the user never sees *"dbl is a function — application is written [dbl …]"*.
   At top level the same program gives the good message. Fix direction: give
   the def seam a pre-typing goal-head validation, or make the solve row-type
   computation surface a typed error instead of a non-type.
2. **Row-type annotations on `def` don't parse** — and the 2026-08-03 probe
   narrows WHY, and identifies it as the SAME gap as § D4.P3a item 19.
   `def r : [List {:f String}] := (goal)` → "Expression is not a valid type",
   though the very same type is what the echo PRINTS for the unannotated def.

   **It is not the parser and it is not `is-type`.** Both were suspects and
   both are innocent:
   - `is-type` ACCEPTS an `expr-Record` — checked directly:
     `(is-type ctx-empty (make-record 'keyword …))` → `#t`, and `infer` gives
     `(Type 0)`.
   - the annotation reaches the checker as a value that merely PRINTS like a
     row (`{:f String}` in the error text), so the failure is in what a `{…}`
     ELABORATES TO in type position, not in whether rows are types.

   In type position `{…}` is already spoken for: it is the IMPLICIT-BINDER
   surface (`spec idf {A} A -> A`, verified working). So a row-literal
   annotation needs a disambiguation RULING between implicit binders,
   `$select-brace`, and row types — a language-design call, not a fix.

   **Same gap as § "CIU T6 D4.P3a spin-offs" item 19** ("Row-literal type
   annotations have NO working spelling — the dropped 'annotate' remedy"),
   which the owner already ratified as *"annotate comes back when it's real"*.
   One ruling closes both entries; neither should be worked separately.

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

## ✅ CLOSED 2026-08-03 — (historical) Un-arm'd AST node → spurious "Multiplicity violation" — 3rd data point (captured 2026-07-25)

**A recurring BUG CLASS, not a single defect.** When an AST node has no `inferQ`
arm, qtt's tu-error fallback propagates the failure and `checkQ-top` reports the
generic *"Multiplicity violation"* — a message with no relationship to the
actual problem. Three confirmed instances:

| # | Trigger | Status |
|---|---|---|
| 1 | `def m0 := {}` (CIU T6 F1a.2) | fixed |
| 2 | `def x := solve (…)` (Rel T1 POL.5, `485f4e7d`) | fixed |
| 3 | `def m := {:f [fn …]}` (first SEEN through `validate`, 2026-07-24) | ✅ fixed `cdb535ac` |

**Both actions are DONE — verified 2026-08-03, and the second was already
done when this entry was written:**

- *Fix instance 3* — landed at `cdb535ac` (the entry already carried the ✅).
  Re-probed at HEAD: all three triggers now define cleanly —
  `def m0 := {}` → `{ | _}`, `def m := {:f [fn [x : Int] x]}` →
  `{:f Int -> Int}`, `def x := solve (p ?a)` → `[PVec {:a Int}]`. No
  multiplicity violation from any of them.
- *Promote the CLASS* — **already present in BOTH required forms**, which is
  what `workflow.md` § "A promoted lesson gets TWO forms" asks for and what
  this entry was tracking:
  - the ambient one-liner in `.claude/rules/pipeline.md` § "New AST Node"
    item 8, carrying the debug rule verbatim and pointing down;
  - the full record in `DEVELOPMENT_LESSONS.org` § "infer / inferQ Are Twins —
    a Missing Arm Makes the DIAGNOSTIC Lie", with the three-instance table,
    the why-it-hides paragraph, and the structural fix direction.

  Nothing was owed here; the entry outlived the work. Worth noting because a
  "promote this" item that is silently already done is the same class of stale
  as a "this is broken" item that is silently already fixed — and this session
  has now found several of each.

**Original framing follows.**

- *(original)* Fix instance 3 — the same shape as POL.5's one-arm fix.
- *Promote the CLASS* to `DEVELOPMENT_LESSONS.org`: at 3 data points this is
  codification-ready. The lesson is diagnostic, not just corrective — **a
  "Multiplicity violation" on a `def` whose body is a non-lambda should be
  suspected as an un-arm'd node before it is believed as a QTT result.** The
  structural fix direction is the `pipeline.md` § "Exhaustive Walkers" answer
  applied to `inferQ`: a generic fallback that contributes zero usage rather
  than a tu-error, so a missing arm degrades to imprecision instead of a
  false failure.

---

## 🔶 PARTIAL `9a5ef0c6` — generated `.md` twins are STALE (captured 2026-07-25; hazard closed 2026-08-02, regeneration + keep/delete still open)

**Broader than the entry had it: ELEVEN stale exports, not two**, and some by
five months — `DEVELOPMENT_LESSONS.md` last regenerated 2026-02-25 against an
`.org` edited 2026-07-28, `MASTER_ROADMAP.md` 2026-03-24 against a source
edited today. `tools/check-doc-twins.sh` reports them (11 of 70 `.org` files
have an export; staleness judged by LAST COMMIT TIME, not mtime — a fresh clone
gives every file the same mtime, so mtime reports nothing on CI and everything
locally).

**The stated harm is closed.** Each stale export now opens with a banner naming
its `.org`, the two dates, and the fact that its claims may already have been
retracted at the source. Someone who greps the principles directory and lands
on the `.md` is told, at the top of the file, that they are reading a stale
generated artifact.

**Still open, and deliberately not decided here:**

1. **Regeneration.** Needs org-export; neither emacs nor pandoc is present in
   this environment, so it cannot be done from here.
2. **Whether the exports should be in-tree at all.** The entry's own question,
   and it is the owner's — deleting twelve committed documents is not a call to
   make as a side effect of a staleness sweep. If they go, the checker and the
   banners go with them.

The checker exits 0 by design: it REPORTS. Gating on it would gate work on a
tool the environment may not have.

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

## ✅ CLOSED `790dfa53` — `current-relation-store` is not threaded into test-support or batch-worker (captured 2026-07-25, fixed 2026-08-02)

Threaded into both files the checklist names. The store is an immutable hasheq,
so re-binding the ambient value per call (test-support) and the post-prelude
value per file (batch-worker) is COMPLETE isolation: a `defr` inside builds a
new store and cannot escape.

`tests/test-relation-store-isolation.rkt` pins all three directions — nothing
leaks forward, the caller's binding survives a call, and register-then-query
within ONE call still works. 2 of its 3 cases fail against the previous commit.

**On the entry's own framing** ("worth treating as an architectural signal
rather than a seventh individual fix: the class recurs because the parameter
set is discovered by grep rather than declared in one place") — that is right,
and the architectural fix is still open. What this changes is that instance #7
is no longer silently live while the general answer is designed, and the leak
is now pinned by a test rather than by a grep that has to be remembered.

Note the same session closed the CELL-BACKED half of the identical class (the
cross-file spec-store leak, above). Two instances of one boundary, both live,
found from opposite directions — one by bisecting a flake, one by reading a
DEFERRED entry.

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

## 🔶 PARTIAL — `docs/spec/grammar.ebnf` predated the POL syntax cluster (captured 2026-07-25; the two SOURCE artifacts updated 2026-08-03)

**Both hand-maintained sources now describe what shipped.** `grammar.ebnf`
§5.28 and `grammar.org` § Relational Language were updated together:

- `clause-body` — the `&>` head-token fork (a `(` head is a SEQUENCE of paren
  goals; a symbol head is EXACTLY ONE goal whose inner parens are ARGUMENTS,
  which is what makes `not (= c n)` parse), plus the three continuation-line
  rules and the `(foo)` requirement for a zero-arg goal on its own line. The
  layout rules are stated as PROSE beside the productions, deliberately: they
  cannot be expressed in pure EBNF, and pretending otherwise is how the
  previous version came to describe a language nobody writes.
- `fact-row` / `fact-line` — `|` row separators, each segment matching arity
  exactly, empty segment an error, and the chunk-by-arity default whose partial
  remainder is a loud error.
- `goal` — the implicit `solve` at command position, its scope (top-level
  commands and `def` RHS only, NOT general expression position), the four goal
  keywords that take it, the `guard`/`cut` exclusion, the bracket spelling's
  functional readings, and the institutionalized WS-vs-sexp paren divergence.
- `rel-params` — C.b.1's fused `?x:Int`.
- `narrow-var` — kept, but marked RESERVED with the collision spelled out,
  rather than left reading as live surface.

`grammar.org` additionally gained the BAGS-not-sets ruling (`solve` returns one
row per derivation path; duplicates are ℕ-semiring provenance, not a bug).

**Still open**: the `.md` / `.tex` / `.pdf` renderings are GENERATED from the
`.org` and remain stale — they cannot be regenerated in this environment (no
emacs/pandoc), which is the same blocker as the § generated `.md` twins entry.
The two hand-maintained sources are correct; the exports are not.

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

### 2. ✅ MEASURED 2026-08-03 — `zonk-at-depth`'s re-shift is negligible; NO FIX WARRANTED

The entry said "unmeasured — it may be entirely fine, since solutions are
usually small. **Measure before fixing**; #58's whole lesson is that the layer
you assume is the cost usually isn't." Measured, by counting every execution of
the `(> depth 0)` shift branch and the SIZE of each solution shifted:

| workload | shift calls | total nodes shifted | max nodes in one shift |
|---|---|---|---|
| synthetic (`map`/`reduce`, duplicated defs) | 145 | 137 | **2** |
| `examples/2026-07-17-ciu-t6-f1b4-seal.prologos` | **0** | 0 | 0 |
| `examples/2026-03-20-punify-p3-acceptance.prologos` | **0** | 0 | 0 |

The hypothesis is confirmed with numbers rather than assumed. Solutions being
re-shifted are 0–2 nodes, and on two real acceptance files the branch **never
executes at all**. There is no O(N²) here to fix: the "re-walked once per
occurrence" term is a two-node walk, and applying #58's `shift-arg` guard would
add a whole-term `loose-bvar-range` computation to buy back nothing — which is
precisely the regression #58 measured when the guard was placed where the
repetition ISN'T (198.6 s → 240.9 s on the full suite).

**Closed as measured, not as fixed.** Re-open only with a workload that makes
the shift-call count large AND the shifted terms big.

**Reproduce**: box a `(vector calls total-nodes max-nodes)` counter around the
`(> depth 0)` branch in `zonk-at-depth`'s `expr-meta` arm, sizing each
`zonked-sol` by transparent-struct node count. Instrument REMOVED after
measuring — same reasoning as item 3 above.

**Original**: `zonk-at-depth` re-shifts per meta occurrence

`racket/prologos/zonk.rkt:557` does `(shift depth 0 zonked-sol)` once per meta
occurrence, with depth incremented at each binder (:590/:592/:594). Same shape:
a solution term re-walked once per occurrence. Unmeasured — it may be entirely
fine, since solutions are usually small. **Measure before fixing**; #58's whole
lesson is that the layer you assume is the cost usually isn't.

### 3. ✅ MEASURED 2026-08-03 — the `eq?`-keyed whnf cache DOES hit, 12–25% on type-checking-heavy work

The entry asked for exactly one thing: *"nobody has measured the hit rate on
type-checking-heavy workloads with genuinely repeated structural subterms."*
Measured, by instrumenting `whnf`'s cache path with hit/miss counters and
running three workloads:

| workload | hits | misses | hit rate |
|---|---|---|---|
| synthetic (`map`/`reduce` over repeated list literals, dup'd defs) | 156 | 1161 | **11.8%** |
| `examples/2026-07-17-ciu-t6-f1b4-seal.prologos` (records + schemas) | 161 | 769 | **17.3%** |
| `examples/2026-03-20-punify-p3-acceptance.prologos` | 307 | 911 | **25.2%** |

**The reading**: the `eq?` cache is NOT doing nothing outside the accumulator
workload. On the accumulator, `hasheq` benchmarked indistinguishable from no
cache at all — the honest reading the entry recorded — but that is a property
of THAT workload's term shapes, not of the cache. Type-checking-heavy code
re-whnfs the same term OBJECTS often enough for identity keying to pay.

So there is no case here for reverting to `equal?` keying (which cost
647,773× at N=512 in isolation, per #58) to chase the structural hits `eq?`
loses. Whether those lost hits are worth a second, structurally-keyed tier
remains open — but it is now a question with a baseline instead of a guess.

**Reproduce**: box a `(vector hits misses)` counter around `whnf`'s
`current-whnf-cache` lookup, bump on hit and on miss, and `process-file` the
workload. The instrument was REMOVED after measuring rather than left in —
`whnf`'s cache path is the hottest in the compiler and an unconditional
unbox-and-branch there is exactly the cost #58 was about. The numbers above
are the deliverable; the hook was scaffolding.

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

🔶 **Reason (c) is GONE (2026-08-03): the divergence is now PINNED.**
`tests/test-parse-reader.rkt` asserts both halves of `(a .( b ) c)` — the datum
layer retaining `c` inside `(a ($mixfix b) c)`, and the tree layer emitting a
plain `paren-group` with `c` expelled as a sibling — under a header saying
plainly that it pins a DEFECT and must be read before "fixing" what it asserts.
It also guards against a `mixfix-group` tag reappearing, since D4.P1a deleted
that tag AND its ~445-line consumer.

Reasons (a) and (b) are unchanged and still block the actual fix. What changed
is that the shape can no longer move UNNOTICED — which was the third reason,
and the only one about risk rather than design. When a track picks this up,
that test is the one to update, and its failure is the signal.

**Contrast worth recording**: the sibling divergence on `<`-adjacent braces
(§ D4.P1b-iii spin-off 5) WAS fixable and is fixed — the two groupers now share
`has-matching-rangle?`. The difference is exactly (a)+(b): there, a predicate
existed to share; here, there is a deleted tag and a missing frame concept.

### 2. ✅ PROBED 2026-08-03 — the three group tags DO produce silent garbage, and the merge no longer admits it

The entry asked for exactly one thing — *"feed `#{…}`, `@[…]`, `~[…]` through
the tree layer and check whether the tree-parser result is admitted or rejected
by the merge"* — and both halves now have answers.

**The tree layer really does produce garbage, silently.** All three become an
application of the first element to the rest, with no error:

```
def a := #{1 2}   ->  surf-def a (surf-app (surf-int-lit 1) ((surf-int-lit 2)))
def b := @[1 2]   ->  the same
def c := ~[1 2]   ->  the same
```

So the "a new tag needs an arm" obligation Q_N1 states as absolute is REAL, and
these three violate it. That half of the inconsistency stands.

**The merge does not admit it — and the reason is today's, not yesterday's.**
Those garbage surfs carry srcloc line 0, and until 2026-08-03 the merge treated
line 0 as a MATCHABLE LINE (see § the bare top-level `[]` entry, where a
located-nowhere preparse error was swapped for a located-nowhere tree surf).
The `real-line?` guard added there closes this path too: a line-0 tree surf can
no longer key against anything. Verified end to end — `#{1 2}` is `[Set Int]`,
`@[1 2]` is `[PVec Int]`, `~[1 2]` is `[LSeq Int]`.

**So: not currently exploitable, and NOT structurally safe.** The protection is
the merge key, not the tags. Anything that gives one of these tree surfs a real
source line — a tree-parser srcloc improvement, most obviously — re-opens it
immediately, and the surfs would then WIN (non-error ∧ same form type ∧ same
line). The three arms are still owed.

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

### 3. ✅ FIXED 2026-08-03 — Reader sentinels that were still MACRO PATTERN VARIABLES (`$set-literal`, `$mixfix`)

Both are excluded now, and the whole list is ENUMERATED in a test
(`tests/test-defmacro.rkt`) rather than sampled — the defect IS the per-member
gap, and a test checking one or two sentinels passed for the entire time these
two were missing.

**Demonstrated at the unit level rather than argued**, because the source-level
repro would not reproduce for me: `(datum-subst (list '$set-literal 1)
(hasheq))` RAISED *"Unbound pattern variable in template: $set-literal"* while
the sibling `$dot-access` passed through unchanged. That is the mechanism the
filing describes, and a raise on the preparse path is what makes it a
whole-file abort wherever it IS reachable. A behavioural test would have proved
nothing here — same reasoning as `test-foreign-fn-walkers.rkt`.

The companion assertion matters as much as the fix: a genuine `$x` must still
raise, so the exclusion list cannot be widened into disabling the mechanism it
guards.

Original filing follows.

**Original**: `pattern-var?` excludes eleven reader sentinels, but not all

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

### 5. ✅ FIXED 2026-08-03 — the two groupers now agree on `<`

`surface-rewrite`'s `langle` arm opened an angle group UNCONDITIONALLY;
`parse-reader`'s consults `has-matching-rangle?` and falls back to operator-`<`.
So `m<{a}` grouped as `angle-group(brace-group)` at the TREE layer while the
DATUM layer read `m < ($select-brace a)`.

Fixed as the filing predicted — *"almost certainly by giving surface-rewrite
the same `has-matching-rangle?` fallback parse-reader has"*. The predicate is
now EXPORTED and SHARED rather than re-implemented, which is the only version
that cannot drift again; `surface-rewrite` already required `parse-reader`, so
no cycle. An unmatched `<` falls through to the generic token arm, which is
exactly what makes the two agree: the reader treats it as a plain operator
token and now so does the tree layer.

Verified on three inputs, both layers each:

| input | angle group? |
|---|---|
| `m<{a}` | NO on both (was: tree YES, datum NO) |
| `<Int>` | YES on both — the control an unconditional fallback would kill |
| `m < 3` | NO on both |

Pinned in `test-parse-reader.rkt` as AGREEMENT assertions — each input checked
on both sides in the same test — rather than as three separate expectations,
because the property is that they match, not what either says alone.

Suite green (542 files / 10495 tests) including the `<`-disclose surface at
`lib/examples/foray.prologos:674`, which the filing named as the live case.

Original filing follows.

**Original**: the two groupers DIVERGE on `<`-adjacent braces

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

Related, same family — ✅ **BOTH FIXED 2026-08-03**:

- **`pp-datum` now renders every access sentinel** at its surface spelling
  (`.foo`, `?.foo`, `*.foo`, `.:k`, `?.:k`, `[0]`, `{a b}`, `.{a b}`), mirroring
  the READER's own emission shapes rather than guessing — `nil-dot-access`
  strips two leading chars, which are `?.`. Beyond the per-sentinel spellings,
  a PROPERTY test asserts no `$` survives into rendered output for any of them:
  whatever the spelling, a user-facing diagnostic depends on the internal name
  not leaking.
- **`tools/form-deps.rkt` filters `$`-headed symbols STRUCTURALLY** instead of
  listing them. Its `syntax-keywords` named ten and omitted roughly thirty
  (`$nil-dot-access`, `$postfix-index`, `$select-brace`, `$dot-brace`,
  `$list-literal`, `$vec-literal`, `$quasiquote`, `$rest`, the whole
  numeric-literal family, the error markers…), and every omission was a
  SPURIOUS DEPENDENCY in the tool's output. Same shape and same fix as the
  `datum-subst` polarity inversion above — a `$`-headed symbol is a sentinel or
  a macro pattern variable, never a dependency, so one predicate replaces the
  list and cannot drift as sentinels are added.

✅ **And the item this was "related to" is now fixed too (2026-08-03).**
`parse-binder`'s two failure arms recognise an access sentinel ANYWHERE in the
binder datum and give a guided message:

> a binder cannot contain a field-access or select form — `(x base{a})` is an
> access expression, and a parameter position takes a NAME (`[x]`), a typed
> binder (`[x <T>]` / `(x : T)`) or the fused form `[x:T]`. Bind the value
> first, then access it in the body.

Three details the first cut got wrong, each caught by probing rather than
reasoning:

- **The sentinel is `$select`, not `$retired-selection`** as the filing said —
  the FUSED select head from D4.P3a is what survives preparse and reaches the
  binder walker. `pp-datum` gained a `$select` arm so it renders `base{a}`.
- **The scan must cover the WHOLE datum, not its head.** The sentinel arrives
  as the SECOND element of `(x ($select base a))`; a head-only test finds
  nothing.
- **`stx->datum` is SHALLOW**, so the datum is a list whose ELEMENTS are still
  syntax objects — the first version printed
  `#<syntax:/abs/path/f.prologos:5:10 x>` in the new message, reintroducing the
  exact leak one layer down. A deep strip is applied to the message AND to the
  error's payload field, which feeds `Near:` and would otherwise put them back
  by a different route. The GENERIC "Expected binder" message got the same
  strip — it was dumping syntax objects too.

Pinned in `tests/test-path-selection.rkt`, asserting on the MESSAGE rather
than the printed struct: the payload legitimately holds the datum, so
asserting on the whole struct would assert more than a user ever sees. A
malformed binder with NO sentinel is pinned as a control, since the new arm
must not swallow every bad binder.

### 8. ✅ FIXED 2026-08-03 — polarity inverted; the 23-sentinel residual is gone by construction

The filing's prescription was taken as written: **"the fix is inverting the
predicate's polarity, not 23 more exclusions."**

`datum-subst` no longer raises on a `$`-symbol missing from `bindings` — it
passes it through. The only thing that makes a symbol a template pattern
variable is being BOUND by the macro's pattern, and `bindings` knows that
exactly, so every reader sentinel is safe BY CONSTRUCTION and the census stops
mattering. Same change for the `$var ...` splice arm: an UNBOUND head is not a
splice.

Verified before and after at the unit level — all 23 censused sentinels
(`$list-literal`, `$vec-literal`, `$pipe-gt`, `$quasiquote`, `$rest`,
`$typed-hole`, …) raised beforehand and pass through now — and end to end, a
defmacro whose template builds a list expands correctly.

**Three things worth carrying forward:**

- **`pattern-var?`'s exclusion list is NOT now redundant and must not be
  deleted as belt-and-suspenders.** `datum-match` uses the same predicate on
  the PATTERN side, where a sentinel must match LITERALLY rather than bind
  anything. Two different questions, one predicate; only the template side is
  inverted. Noted at the call site so the next reader does not "clean it up".
  Item 3's two additions above remain correct for that side.
- **What the inversion costs, named rather than glossed**: a typo'd template
  variable (`$boddy` for `$body`) no longer raises during expansion. It passes
  through and surfaces at the USE SITE as an ordinary unbound-variable error
  naming `$boddy` — per-command, with a srcloc, file intact. Probed, not
  assumed. That is a better failure mode than the abort, not merely a cheaper
  one.
- **Two existing tests asserted the OLD polarity and were deliberately
  changed**, including one added earlier the same day. They are rewritten to
  assert pass-through with the reason recorded in place, not deleted — a test
  that changes meaning should say why at the point of change.

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

### 10. ✅ RESOLVED 2026-08-03 — `format-closed-tuple-oob`'s zero-arity branch IS reachable; the reaching case is now pinned

The filing offered two outcomes — "construct the reaching case and pin it, or
delete the arm" — and the first one is correct. **KEEP the arm.**

Its premise was right and its conclusion was not, which is worth separating.
`@[]` really does type as `[PVec _]` rather than a 0-field nat row, so the
literal path never reaches the branch (now pinned as its own case). But the
filing looked at one producer. `pvec-slice` on a closed tuple has its OWN
row-building branch whose field list is literally `'()` when the range is
empty:

```racket
(make-record 'nat (if (>= lo-n hi*) '() …) 'closed)   ;; typing-core.rkt, col-3 slice arm
```

So an empty slice of a tuple IS a closed 0-field nat row, and an ordinal on it
takes the zero-arity branch:

```
def t := @[1 "a"]                  ;; ⟨Int String⟩
def s := [pvec-slice t 1N 1N]      ;; ⟨⟩
s.0
;; => Could not infer type — index 0 is out of range for the 0-tuple ⟨⟩
;;    (the tuple has no positions)
```

Two pins in `tests/test-path-selection.rkt`: the reaching case (asserting the
zero-arity phrasing AND the ABSENCE of the "valid indices" clause, since a
0-position tuple has no range to offer), and the filing's own premise, so that
a future change making `@[]` a 0-tuple surfaces beside the branch it would give
a second producer.

**Method note worth keeping**: "may be unreachable" was decided by enumerating
the CONSTRUCTORS of the type in question — six `make-record 'nat` sites — not
by reasoning about the surface syntax. The surface-level argument is what made
it look dead.

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

### 19. Row-literal type annotations have NO working spelling — the dropped "annotate" remedy  ·  SAME GAP as § Rel T1 POL.9b item 2 (cross-linked 2026-08-03)

`def q : {:a Int} := {:a 1}` → "Expression is not a valid type";
`[fn [m : {:host String}] m.host]` fails select-free; zero in-tree uses. The
Q_T2 remedy list as ruled named "annotate" third — the verify dropped it from
the select refusal messages as advice-that-does-not-work — an adaptation the
owner RATIFIED 2026-07-30 ("annotate comes back when it's real"). Re-add to
the messages when row annotations become writable (PX / F-carrier adjacent).

### 20. 🔶 SELECTION-typed subjects refuse as 'subject-other — the interim MESSAGE landed 2026-08-03; capability-aware projection still deferred

The entry named "a guided selection-aware message would be a cheap interim
improvement". Done. A selection-typed subject now gets:

> select: the subject is the selection `NameOnly`, and a select block does not
> project THROUGH a selection. A selection is a capability-restricted view
> (`:requires`), so projecting through it would bypass the restriction it
> exists to enforce — this is a deliberate refusal, not a shape mismatch.
> Select from the underlying record instead.

The old text said "the subject is not a record", which is TRUE of a thing that
is precisely a restricted record VIEW — so it sent the reader to check their
subject's shape rather than their intent. Two pins in
`tests/test-path-selection.rkt`: the selection case, and a genuinely non-record
subject that must KEEP the generic message (the new arm must not become the
only thing `subject-other` can say).

**Unchanged**: `select-project` still does not project through selection-typed
subjects, and should not until selection values grow their capability-aware
projection. The original entry follows.

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

### 21. ✅ FIXED 2026-08-03 — `k^:x` now gets the splitter's message

`cfg{server^:x}` gave "block keys are written bare — `x{server}`, not
`x{:server}`" instead of the rename-target refusal. It now gives:

> `` `server^:x` — a rename target is a bare label, not a keyword (write
> `server^x`) ``

Fixed exactly as the filing prescribed: `segment-select-items` detects a
keyword item immediately after a CARET-TERMINATED item and emits the
splitter's message, so both readers say the same thing about the same input.

The gate is narrow on purpose — caret-terminated item AND a following keyword.
Without it the arm would swallow the ordinary `cfg{:server}` mistake, whose
generic message is the correct one there; that case is pinned as a control
alongside the working `cfg{server^x}` rename.

Original filing follows.

**Original**: the splitter's `#\:` arm is dead in WS mode

`cfg{server.host^:x}` gets the block-keys-bare message instead of the
splitter's keyword-target refusal: in WS mode the lexeme does not glue
through the colon, so the item arrives as a keyword and the splitter's
`#\:` arm never fires (it is reachable from sexp-mode datums only — the
F1b sexp-green ≠ WS-correct class). MITIGATION: the wrong message's action
(drop the colon) resolves the input, so this is degraded-not-lying. Fix
shape: detect a kw item immediately after a caret-bearing step in
`segment-select-items` and emit the splitter's message.

### 22. ✅ CLOSED `902ca588` — arrowless match arms raw-crash the reader (fixed 2026-08-02)

Not the marker-seat class after all, and simpler than that: the diagnostic was
already there and was being THROWN AWAY. `parse-match-pattern-arm` had EIGHT
guards shaped

```racket
(unless arrow-idx (parse-error loc "match arm missing -> separator" #f))
```

which evaluates the error, DISCARDS the value, and falls through — so
`(take cleaned arrow-idx)` ran with `arrow-idx` = #f and died on a raw
`take: contract violation`. Whole-file abort, zero commands, and a message
about `take` while the correct diagnosis sat one line above, computed and
unused.

Its immediate neighbour `parse-map-literal` carries a comment describing this
EXACT defect being fixed there ("It was a value-discarding `when` that fell
through to the loop below and hard-crashed"). Found in one function, left in
its sibling — the same one-member-of-a-family shape as the walker defects.

All eight now return, via an escape (the guards are spread through a sequence
of interdependent `define`s; threading them into nested conds is how a parser
acquires a different bug). The arrow message names the fix:

```
ERROR: match arm is missing its `->`. Each arm is `| PATTERN -> BODY`;
       write `| 0 -> 111` rather than `| 0 111`.
```

Per-command, so the commands before and after still run. Pinned, with a
well-formed `match` alongside.

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

---

## OCapN third-party handoff — adversarial review backlog (2026-08-01)

Four adversarial reviews of the handoff migration (branch
`claude/ocapn-prologos-implementation-auLxZ`, at `b998b18b`) found nine issues
that were fixed and roughly twenty that were not. The full record, with
concrete failure modes and file:line for each, is
[`2026-08-01_OCAPN_HANDOFF_REVIEW_FINDINGS.md`](2026-08-01_OCAPN_HANDOFF_REVIEW_FINDINGS.md).

Highest-value items, in the order that document recommends:

- ~~**S1 + S2 (security, one bug).**~~ FIXED `d9b3bc2f`. The exporter never
  bound a `desc:handoff-receive` to the connection it arrived on, and the
  used-set died with the connection — together a double-spend across
  reconnects. Both fixes were independently required; the findings document's
  original claim that S1 subsumed S2 was wrong, and is corrected in place.
- ~~**S3.**~~ FIXED `a1eeaff4`. Gift ids were a predictable sequential
  counter; a peer could shadow an honest deposit by guessing a small integer.
  Now 128 random bits, and a duplicate id is refused.
- ~~**C1.**~~ FIXED `cc9ff44e`. `reserve-export-id` lost its reservation when
  the enlivened sturdyref named the connection it arrived on. `run-step` now
  stashes before draining.
- ~~**C4.**~~ FIXED `7efc781d`. `nat-of-payload` accepted `<desc:export [5]>`
  while captp-wire rejected it — two readers of one descriptor.
- ~~**C5.**~~ FIXED `7efc781d`. `peer-location-key` is implemented twice across
  the language boundary and had diverged on unparseable locations. Both refuse
  now, pinned by a differential oracle (`test-ocapn-location-key.rkt`).
- ~~**X2.**~~ FIXED `7efc781d` — not a flake, the cross-file spec leak. See the
  batch-isolation entry above.
- **C6 (new).** `ocapn-gift-stash` replaces the whole gift list rather than
  merging, so two connections depositing concurrently lose one gift. The same
  lost update as C1, one layer out; masked today only by the process-wide
  `validate-sema`. **Not fixable as a patch**: `GiftEntry` is opaque to Racket
  by design (the FFI passes unrecognised types through unmarshalled), so the
  FFI cannot merge two lists, and Racket cannot construct a Prologos `nil`/
  `cons` to build one. The honest fix is per-gift add/remove keyed by gift-id
  with an index-based read, i.e. an FFI redesign. Sits with C2, whose point is
  the same: the accidental `validate-sema` serialisation is what makes all of
  this look safe.
- **A2.** Decompose the ~1100-line driver into `captp-handoff.prologos` +
  `captp-frames.prologos`; this is also how the remaining test debt gets paid.
- **A3 (design task, not a refactor).** The per-connection vat is the root
  cause of three of the four process-global tables and of the cross-vat
  reach-in behind C1. Fixing it removes code.
- **A4.** Two identical-arm `match` sites guard every outbound dial and send;
  an arm-collapsing optimisation would delete the outbound path with a green
  suite.
- ~~**U1.**~~ FIXED 2026-08-03. A `let` whose VALUE sits on a continuation line
  mis-grouped: the BODY line was folded into the value's argument list, so

  ```
  defn g [n]
    let x :=
        [f n 1]
      [int+ x 10]
  ```

  became `[f n 1 [int+ x 10]]` — *"Too many arguments to 'f'", expected 2 got
  3*, naming a function the user never mis-called. Two sites in this tree were
  worked around by re-indenting (`38a4e523`); the compiler defect was not.

  Fixed exactly where the filing said: `classify-let-block` now declines the
  aligned reading when the head binding ENDS at `:=`, since that shape has no
  value on its line and the aligned surface assumes the head line IS a
  complete binding. Declining hands the form to the nested/continuation-value
  path, which reads it correctly. Narrow by construction — the aligned block
  and the sibling `:=` chain are pinned as controls.

  The filing was also specific about the TEST — *"a regression test must run
  through `imports`, not `process-string` — the failure is on the module-load
  path"* — and that is honoured. The test asserts the VALUE (16), not merely
  the absence of an error: a mis-grouped call is an arity error, so
  "no error" alone would pass a fix that merely stopped erroring.
- **U2 (upstream/main).** The ~N^2.17 `build-tree-from-domains`.
- ~~**U3.**~~ FIXED 2026-08-03. `load-module` raised with only
  `prologos-error-message`, so a library module's error arrived as a bare
  *"imports: Error loading module X: Unbound variable"* — no NAME, no SRCLOC,
  leaving the reader to find the line by hand in a module they may not have
  written. Both facts were on the error struct the whole time. It now renders
  with `format-error`, the same renderer the per-command path uses, so a
  failure inside an imported module reads exactly like the same failure in a
  top-level file:

  ```
  imports: Error loading module prologos::u3::bad:
  Error at …/bad.prologos:4:0
    Unbound variable: nonexistent-fn
  ```

  Pinned in `test-error-messages.rkt`, asserting the name, the file, the
  `line:column`, AND that the module name the old message DID carry is still
  there — four separate checks so a partial regression says which fact went.
