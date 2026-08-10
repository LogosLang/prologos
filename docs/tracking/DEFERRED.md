# Deferred Work

Single source of truth for all deferred work across the Prologos project.
Items are organized by topic. When work is deferred during implementation,
add an entry here immediately.

**Principle**: Completeness over deferral. Items here should be genuinely
blocked on unbuilt infrastructure or uncertain design — not effort avoidance.
See `docs/tracking/principles/DEVELOPMENT_LESSONS.org` § "Completeness Over
Deferral".

**Completed items**: Moved to `DEFERRED_COMPLETE.md` during staleness sweeps.
Last sweep 2026-08-05 (37 entries; the previous one was 2026-03-20, and in the
interval a third of this file had become closed entries). **Read the body, not
the header** — two `✅`-headed entries were kept here because they carry
residue the header does not advertise, and the sweep only found them by
reading. A `✅` header means "the thing named in the title is done", not
"nothing in this entry is open".

**Blocked on the owner, not on us**: four questions are collected in
[`2026-08-05_1751_FOUR_OPEN_OWNER_RULINGS.md`](2026-08-05_1751_FOUR_OPEN_OWNER_RULINGS.md)
— each with what is already probed and true, the options, and what each unblocks.

## ✅ FIXED 2026-08-05 — session type nodes were UNREGISTERED for `.pnet`, breaking the stdlib on a warm cache

**Zero `sess-*` nodes were registered in `pnet-serialize.rkt`.** So any module
declaring session types deserialized as raw VECTORS when served from cache —
and `lib/prologos/core/io-protocols.prologos` declares **four** recursive
protocols (`FileRead`, `FileWrite`, `FileAppend`, `FileRW`). The standard
library was broken for anyone with a warm `.pnet` cache and fine for anyone
cold.

**The diagnostic is the one `pipeline.md` warns about**, and it is worth quoting
because it reads as nonsense until you know:

```
sess-mu-body: contract violation
  expected: sess-mu?
  given: '#(struct:sess-mu #(struct:sess-choice ((:read-all . …))))
```

A value being told it is not the thing it visibly is. **The leading quote is the
tell** — that is a vector, not a struct. The unknown-tag fallback returns a raw
vector that PRINTS like the real struct and fails the first predicate to touch
it, arbitrarily far from the cause.

**Verified both directions before and after**: with the pre-existing cache
present the test failed; deleting `io-protocols.pnet` made it pass; after
registering, a cache written by the fixed code reads back clean
(`test-io-session-01` 11/11 warm, `test-io-dep-session-02` 8/8).

**The whole family is registered**, not just the node that detonated —
`sess-end`, `sess-mu`, `sess-svar`, `sess-choice`, `sess-offer`, the six
send/recv variants, `sess-branch-error`. Registering only the detonating node is
the "registration-by-detonation" pattern this same file was swept for earlier in
this session (31 nodes missing BY SIBLING).

**How it survived, and why that matters more than the fix.** Nothing about this
is triggered by a code change — only by CACHE STATE. It passed every CI run
whose cache was cold and failed every run whose cache was warm, and neither
looks like a regression. It surfaced only because a full-suite gate ran for an
unrelated four-line test addition, immediately after a `raco make` had changed
the cache state.

⚠ **It also means an earlier probe in this same session was luckier than I
knew.** I ran `test-io-session-01` while checking whether recursive session
types work, got 11/11, and cited it as evidence that they "ship and are
exercised". True — but the cache happened to be cold. A green result whose
correctness depends on invisible cache state is not the evidence it appears to
be.

## ✅ ADOPTED 2026-08-05 — netstring framing, and the "decision" was a false dilemma

`ocapn-test-suite` **#41 ("message-framing")** wrapped every CapTP message in a
netstring. Ours did not, so as of upstream `31f0b806` the two could not talk —
every test errored during `setup_session`, in under a fifth of a second, on a
merge commit that touched no OCapN code at all (the clone was unpinned).

**Done, all in one commit** (the entry required the pin to move with the wire):

- **`'netstring` strategy** in `tools/interop/ocapn-framing.rkt` —
  `<ascii-digits>:<payload>`, **no trailing comma**, so NOT a classic netstring.
  Shape taken from upstream's `utils/netstrings.py` (`length.encode() + b":" +
  self`) and `@endo/syrup-frame`, the two implementations we interoperate with —
  read from the source, not from memory of the netstring convention.
- **Server default flipped** `'raw-syrup` → `'netstring`.
- **Pin moved** `74db78f` → `31f0b80`. Leaving it behind would hide the next
  drift exactly as it hid this one.
- **5 regression tests** in `test-ocapn-syrup-wire.rkt`, perturbation-verified:
  emitting a classic-netstring trailing comma fails 2 of them. They cover the
  property the framing exists for — two frames coalesced in one buffer, a payload
  that itself looks like a length prefix (`12:notalength` → `13:12:notalength`),
  clean EOF as `#f`, and malformed prefixes raising rather than silently
  resyncing.

**Gate: 24/24 against the NEW suite.** Plus full suite 561/10965/0,
`test-ocapn-syrup-wire` 45, `captp-wire` 18, `netlayer-tcp` 2.

### ⚠ The blocker I filed was a false dilemma

This entry said the remaining work needed a decision: *"whether the new strategy
replaces `'raw-syrup` or joins it"*. There was nothing to decide. Adding a
strategy is **purely additive** — the parameter already existed, `'raw-syrup`
stays for the byte-equality fixtures, `'newline` stays for the `.mjs` cross-impl
peers, and nothing upstream reads either any more. I invented the choice by
assuming adoption meant removal.

**Third time this session a "needs a ruling" call was wrong** — after the
provide-surface trade (answer was already in the module the entry named) and the
multi-arity dispatch bug (looked like a syntax decision only because I had
misdiagnosed it). The pattern is consistent and worth naming: **I escalate while
the mechanism is still unclear, and the unclarity presents as a design question.**
All three dissolved on contact with the code. Probe before filing something as
the owner's.

## 🐛 Two diagnostics degraded upstream — found by the 2026-08-05 `main` merge

Both were caught because this branch had TESTS pinning the messages; both were
verified against a **pure `origin/main` worktree build**, so neither is merge
fallout. Recorded rather than silently accommodated, because in both cases the
weaker message is now what a user sees.

### 1. ✅ CLOSED 2026-08-05 — and the entry's PREMISE was wrong: the guard never stopped firing

Filed as a merge regression. It was not one, and chasing it found the better fix.

`book/collection-functions.prologos` has **two** problems, and which one surfaces
depends on error-surf handling:

| line | problem |
|---|---|
| 28 | `module prologos::core::collections` — **not a Prologos form at all**; `module` is the literate-BOOK directive `tools/tangle-stdlib.rkt` reads |
| 30 | `(imports …)` with no `ns` in scope — the `require-ns-context` guard's case |

This branch's old code **skipped** error surfs (`unless (prologos-error? surf)`),
so it passed over line 28 and surfaced line 30's guard message. Main's shape
REPORTS the first error surf. That is the better shape — the old path was
silently skipping a real error — it just arrived bare (`Unbound variable:
module`), which is what made it look like a lost diagnostic.

So the guard is intact and still fires wherever it is reached. The fix was to
make the EARLIER error carry the explanation, via the existing
`unbound-op-hint-table` (elaborator.rkt):

> hint: `module` is a book-chapter directive, not a Prologos form. The `book/`
> files are literate prose that `tangle-stdlib` reads — they are not importable
> modules. Import the tangled library instead (e.g. `prologos::core::collections`),
> or write `ns` if this file is meant to BE a module.

Better than what was "lost": it names the actual first problem, at the line that
has it, and explains what a chapter file is. `tests/test-import-no-ns.rkt` pins
the name, the file:line, and both halves of the explanation.

**The lesson is about my own filing.** "A message changed, therefore a
regression" skipped the step of asking which error each version was reporting.
They were reporting *different errors* — and the one the old code showed was the
second one, reached by silently discarding the first.

### 2. ✅ FIXED 2026-08-05 — `.field` on a non-projectable carrier lost its type-naming hint

This branch's hint named the carrier AND its type — *"`.name` is field access,
but `n` has type `Int`, which has no fields. `.field` needs a record {…} or a
map."* D4.P4b-ii migrated `.field` from `$dot-access`→`map-get` onto
`$select-path`→`expr-select`, so the select-fail message answers first with the
generic *"the subject is not a record, so it has no fields to access"*.

**Fixed, and it turned out NOT to need a ruling.** I filed this as "a
diagnostics-precedence decision for the owner". It is not: `infer/err` in this
same file already states the rule — *"most specific first"* — and
`test-path-selection.rkt` asserts it ("the check door yields to every
more-specific message"). Naming the type IS more specific than "is not a
record", so the existing convention decides it.

`projection-parts` was taught the new node shape, and the `subject-other` arm
now names the type when `unprojectable-type?` (a POSITIVE list, so it fires only
where the claim is provably true and an unrecognized carrier declines by
default):

> select: `name` is field access, but the subject has type Int, which has no
> fields. `.field` needs a record {…} or a map.

Gated to DOT ACCESS. A first cut fired for select BLOCKS too, where "field
access" names the wrong construct — caught by the existing block pin, which is
why that pin was worth keeping when the wording moved.

**The transferable bit**: a consumer keyed on a node shape goes silently dark
when the shape migrates — the `pipeline.md` § "Exhaustive Walkers" family-sibling
class, in its consumer form. Nothing errored; a specific message just quietly
became a general one.

> **The four open OWNER RULINGS that gate this queue are collected in**
> [`2026-08-05_1751_FOUR_OPEN_OWNER_RULINGS.md`](2026-08-05_1751_FOUR_OPEN_OWNER_RULINGS.md)
> — is `eval` a capability · can `{…}` mean a row type in type position · how
> `Ord`/`Seq` thread through SortedMap · should `redex` be a dependency. Each is
> answerable in a sentence, and each unblocks entries below. They were scattered
> across four sections and a dailies file, which is why they kept being
> re-derived.

**Last consolidated sweep**: 2026-03-20 (PUnify Parts 1-2 complete, 7308 tests, 377 files).

---

<a id="numbering"></a>

## ⭐ NUMBERING — MONOTONIC, PERMANENT, NEVER REUSED  [owner ruling, 2026-08-08]

> ### **NEXT FREE: 101**
> Allocate from THIS REGISTER and bump it in the same commit. **It is the only
> allocation source.**

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

## ✅ CLOSED `ccf7adb0` — `(when C (parse-error …))` computes a diagnostic and throws it away (censused + swept 2026-08-02; the structural residue gated 2026-08-05)

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

**The structural residue is ANSWERED 2026-08-05 — with a gate, not a redesign.**

The residue read: "`parse-error` returning rather than raising is what makes
this shape writable at all. Making it raise, or giving the parser an error
monad, would make the class unrepresentable — a bigger call than a sweep should
make. Until then the shape can be reintroduced by the next guard someone writes."

Re-reading that with the rest of this arc in hand, **making it raise would be
the wrong fix**, not merely a big one. It trades this class for the
whole-file-abort class — and the whole-file-abort class is strictly worse (an
empty file, not one bad command) and is exactly what the marker-seat work spent
this arc removing. An error monad remains a real option and a large one.

So the achievable property is not *unrepresentable* but *cannot survive*:
`racket/prologos/tools/lint-discarded-errors.rkt`, wired into pre-commit as
gate 4. It reads with `read-syntax` (locations preserved), flags a `when`/
`unless` whose body ENDS in an error constructor and which sits in a non-final
position of a real body sequence, and is BASELINED at today's 18 sites — the
same device `lint-parameters.rkt` uses, for the same reason: those 18 were
probed and consciously left (some fall through to a BETTER message), so failing
on them would block every commit and teach people `--no-verify`.

**Two bugs in the lint itself, both worth recording because both are the
failure mode this entry is about:**

1. The first version used "not the last element of the enclosing list" as a
   stand-in for "value discarded". An `if` then-branch is element 2 of 4, so
   every correct `(if C (parse-error-result …) (continue …))` was reported.
   16 hits, all false. Fixed with an explicit body-position table.
2. `syntax-e` on an improper list — `(lambda (fmt . args) …)` — returns a raw
   pair, and recurring on it handed a non-syntax value back in. The contract
   violation aborted that file. **Seven files were being skipped**,
   `tree-parser.rkt` among them, while the run still printed a total and looked
   complete. A linter that silently drops its hardest inputs is precisely the
   defect class it was written to find.

Perturbation-checked: a fresh `(unless C (parse-error …))` is caught with exit
1; the `if`-arm and `cond`-arm spellings in the same fixture are spared —
exactly one hit, not three.

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

## 🐛 DEFECT — a numeric-LITERAL first branch adopts any second-branch type (found 2026-07-30; mechanism nailed down 2026-08-02; the MALFORMED-NODE half fixed 2026-08-03, the type-level unsoundness still needs a design call)

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
3. ✅ **DONE 2026-08-03 — gate `collapse-num-lit` on representability.** Taken
   because it is the one candidate that is local and obviously correct, and its
   own warning here is preserved rather than quietly dropped: **this is NOT a
   fix**. `default-metas` still falls back to the notation default, so
   `defn d8 | 0 -> 1.5 | n -> "x"` is still accepted at `Int -> String` and
   `[d8 0]` still yields a numeric value under a `String` type.

   What changes is that a MALFORMED NODE is no longer constructed. `[d10 0]`
   went from **`3/2 : Int`** — an `expr-int` whose payload is a ratio — to
   `1.5 : Int`. A well-formed value at a wrong type is recoverable by whatever
   fixes the type-level hole; an `expr-int` holding 3/2 can crash any consumer
   that believes the struct's own contract, arbitrarily far from here.

   The guard also corrects a comment that had become false:
   `collapse-num-lit` said *"Representability is validated in check-mode; here
   we trust the resolved type"* — and on THIS path check-mode never validates,
   which is exactly how the malformed node got built. Trusted, now checked.

   Nat's guard is `exact-nonnegative-integer?`, not `exact-integer?` — the
   nonneg half is the piece a naive reading drops, and it has its own test.

   Pinned in `tests/test-branch-numlit-wellformed.rkt`, verified failing against
   the ungated code. Four cases, and TWO of them are the boundary rather than
   the win: one asserts the type-level unsoundness is STILL PRESENT (so nobody
   reads this as closed), and one asserts ordinary literals — `Int`, `Nat`,
   bare decimal, `Rat` — are untouched, since the guard sits on a path every
   numeric literal in every program takes.

   **Items 1 and 2 remain the actual fix**, and the entry stays open for them.

Still Num Track 1 territory, as originally filed. What has changed is that it
is now a three-line repro with a named mechanism and a demonstrated runtime
violation, instead of a suspicion.

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

## 🔶 PARTIAL — CIU T6 F1b.5: the deep-walker charter (D27.5, 2026-07-17; ALL FOUR ITEMS DONE 2026-08-03. Residue (e)'s AUTO-discharge and the wildcard QUANTIFIER semantics are what remain — both design questions, not gaps)

Validate v1 is ONE-LEVEL with STRUCTURAL depth symmetry (it consumes the same
field-set enumeration as `schema->row` — never a second one-level implementation).
THREE deferrals are ONE walker mechanism and live in THIS single entry (never
residue-letter entries — divergent gates/double-count):

1. ✅ **DONE 2026-08-03 — nested-seal traversal on the commit path.** The
   forcer was TOP-NODE-ONLY, so of these four only the first was caught:

   ```
   def top    := [Pos {:n 0}]                 ;; ERROR at commit   ✓
   def inlist := '[[Pos {:n 0}]]              ;; defined.          ✗
   def inpair := {:a [Pos {:n 0}]}            ;; defined.          ✗
   def infn   := [fn [x : Int] [Pos {:n 0}]]  ;; defined.          ✗
   ```

   `inlist` and `inpair` are now caught. `infn` deliberately is NOT, and that
   exclusion is load-bearing rather than an omission: a seal under a BINDER may
   reference the bound variable, so forcing it evaluates a body that has not
   been applied — it can panic on a value the program never constructs, or get
   stuck on an open term. The walk stops at the full binder inventory
   (`substitution.rkt`'s `shift`: lam / Pi / Sigma / reduce), and skips
   `expr-reduce` WHOLE rather than descending its scrutinee — conservative, and
   the arms are where the binders live.

   **The walk is generic `struct->vector` recursion, not `expr-subfields`, and
   that is required rather than stylistic**: `expr-subfields` reads transparent
   expr FIELDS, so it finds the cons-spine case (`inlist`) and NOT the champ one
   (`inpair`), whose payload is a Racket data structure. Same container-blindness
   that produced this session's `occurs?` / `conv-nf` defects. Both carriers are
   test-pinned side by side, so the walk cannot regress to the shallower one and
   stay green. An opaque struct yields a 1-element vector and is simply not
   descended, so nothing here can error on a carrier it does not model.

   **Gated on the schema registry being non-empty**, which is what makes it
   affordable on the commit path: a program declaring no schemas pays one
   `hash-count`, and where schemas exist the walk is O(body) — the same order as
   the zonk and nf already performed on that body. Suite unchanged at ~71 s.

   ⚠ **The asymmetry with `def-panic-error` is deliberate.** That one keeps its
   top-node bound (pinned at `test-path-selection.rkt` B8, and again beside its
   counterpart now). A seal is a COMMIT-TIME CONTRACT — D22's ruling is that
   tabulation FORCES — so a failing one is an error whether or not anything
   reads it. A bare `panic` inside a constructed value is an ordinary lazy value
   the program may never force, and erroring on it would make laziness
   unobservable.

2. ✅ **DONE 2026-08-03 — tier-2 element recursion.** The entry's own honest
   reason was the fix's shape: `ctor-meta` already carried params +
   field-types, and what was unbuilt was the param-substitution + recursion +
   depth discipline. All three landed.

   `(ctor Name)` asserted only that a value's constructor belonged to the type
   and NOTHING about its arguments, so a `(List String)` field accepted
   `[cons 1 nil]` and an `(Option Int)` field accepted `[some "z"]` — the same
   silent-acceptance class as item 3, one level in. The tag is now
   `(data Name NSKIP (Ctor FieldTag …) …)`, computed by substituting the
   applied type arguments into each constructor's registered field-type datums.

   - **NSKIP** is the count of erased type params a constructor VALUE carries:
     `[some 1]` reduces to `(some Int 1)`, `[cons 1 nil]` to
     `(cons Int 1 (cons Int 2 (nil ?m)))`. It comes from the ctor's own
     `params`, not from counting applied arguments, so a bare data type
     (`Color`, zero of both) still tags.
   - **`self`** marks a field whose substituted type IS the type being tagged
     — `cons`'s `(List A)` tail. The runtime re-enters the whole tag there,
     which is what makes a list check EVERY element instead of its head. It is
     also what makes the bake terminate at all. Test-pinned at POSITION 2
     specifically: an implementation that only checks the head passes position
     0 and fails position 2 (the same shape as the `vindex` position-2 lesson).
   - **`data-witness-tag` DECLINES to the old `(ctor Name)`** on any ctor with
     no registered meta, any arity that does not line up, and any field-type
     datum that will not convert. That fallback is the entire safety story for
     an arm this broad: the new tag is a strict refinement, and where it cannot
     be computed the previous behaviour stands rather than a guess. Pinned.
   - Runtime ACCEPTS on an unknown constructor and on a spine whose field count
     differs from the tag's (a partial application) — uncertainty, per D28. The
     HEAD check is byte-identical to `(ctor …)`'s, so this can only reject a
     strict superset of what the old tag rejected, and only on an argument.

   The `got` payload composes through the levels:
   `"List (cons field 0 is Option (some field 0 is String))"`.

   Blast radius was the reason for the full-suite gate rather than a targeted
   run — this arm fires on EVERY ctor-typed schema field. Exactly one test
   changed: the assertion that pinned `(tag-of '(Option Int))` as
   `'(ctor Option)`, i.e. the pin on the element-blind behaviour this item
   existed to remove.

   **The non-ctor CARRIERS landed in the same session** — `(PVec T)`,
   `(Map K V)`, `(Set T)`. Their values are an rrb, a champ and an hset rather
   than constructor applications, so they never reached the `data` arm and sat
   at `'any`: `[validate Vecd {:xs @[1 "z"]}]` returned `ok`. Tags `(pvec T)` /
   `(hmap K V)` / `(hset T)`; elements come straight off the carrier, so there
   is no ctor-meta or spine walking involved. A POSITIVE list of three known
   heads matched by BARE name with the arity checked — an unrecognized head
   still falls through to the ctor arm and then to `'any`, so nothing here can
   fire on a carrier that has not been modelled. A `Map` checks BOTH keys and
   values. A value of the wrong carrier kind ACCEPTS (same call as the `row`
   arm), and a TRANSIENT PVec accepts unread — it is a mutable handle mid-build,
   so a verdict from it is about a state that may not be the one committed.

   `value-kind-string` gained the two carrier kinds while here: without them a
   `(PVec Int)` mismatch reported got=`"value"`, which names nothing at all.
   Now `"PVec (element 1 is String)"` / `"Map (the value at :a is Int)"`.
3. **Sub-schema descent** (auto-registered `Parent__field` entries carry
   check/default = #f — stripped at registration; a one-level engine hitting a
   sub-schema-typed field has no defined deep disposition).
4. 🔶 **NESTED requires-paths DONE 2026-08-03; wildcards still deferred.**
   The `(null? (cdr path))` filter dropped a deep path WHOLE, so
   `:requires [:address.zip]` enforced **nothing** — and the more surprising
   half is that it did not enforce its TOP HOP either. An absent `:address` was
   not a read-capability miss, though `:requires [:address]` would have caught
   it: the longer name silently turned the requirement off.

   Two halves, both landed:
   - the top hop joins `req-syms`, so an absent `:address` is a miss exactly as
     `:name` would be;
   - the REMAINDER rides the plan entry (a new slot 7) and the runtime descends
     it inside the present field's value.

   Reported under the FULL dotted path (`{:address.zip missing-required}`)
   rather than under the top hop, because the err champ is keyed by field and
   `{:address missing-required}` would be a lie — `:address` is right there.
   `missing-required` is the correct Reason: this IS a read-capability miss,
   one level in.

   **A non-map on the path is a MISS, not an accept** — deliberately the
   OPPOSITE call from the type witness one item up. The witness declines to
   assert what it cannot read; a `:requires` is a claim about REACHABILITY, and
   a path that cannot be walked is unreachable by definition.

   Two notes for whoever does the wildcard half:
   - `validate-map-exprs` (syntax.rkt) used to rebuild plan entries with seven
     explicit `list-ref`s, so adding slot 7 would have **silently TRUNCATED**
     every entry on any shift/subst/zonk/nf, detonating later at an unrelated
     `list-ref`. It now maps the entry spine generically and transforms only the
     two EXPR slots — correct for any future arity by construction
     (`pipeline.md` § Exhaustive Walkers). The reduction arm reads slot 7
     defensively for the same reason: a plan baked by an older build is one
     entry short, and absent deep-requires means exactly "none".
   - the wildcard remainder still defers: "every key under here" is a
     QUANTIFIER, not a path, and needs semantics before it can be enforced. Its
     top hop IS required now (unambiguous, and independent of that ruling).

   ✅ **The wildcard SPELLING now parses in WS mode (2026-08-03).** It did not,
   and the reason is the reader's six-member dot band discriminating on the
   SECOND character: `*` belongs to `recognize-broadcast-access`, which needs
   an identifier AFTER the star (`.*field`). A star at the END of a path
   matched nothing in the band, so the dot fell through as a bare `|.|` symbol
   and `reconstitute-path-list` — which collected only `$dot-access` segments —
   stopped, leaving `(:address |.| *)` for the selection parser to reject.
   Sexp-green, WS-broken: `test-selection-compose.rkt` exercised the spelling
   happily through the native reader.

   Two arms, and the second is NOT a variation of the first: `.*` is the
   bare-dot-then-star pair, while **`.**` arrives as `($broadcast-access *)`**
   — the star consumed as the marker and the SECOND star as the "field" — so
   handling only `.*` leaves `.**` erroring. Both are test-pinned. A wildcard
   segment is TERMINAL (nothing follows `*` in a path), which is what lets the
   collect loop append-and-stop.

   ⚠ **Found while probing this, and FIXED the same day — a failed selection
   declaration left a live selection that validated everything.** Preparse
   pre-registers every selection as a STUB (`macros.rkt`, empty
   requires/provides) so `known-type-name?` recognizes the name during spec
   processing. When the declaration then FAILED, nothing replaced the stub —
   `validate` found it, saw no required fields, and returned `ok` FOR ANY
   INPUT. The file reported one error and then carried a selection that
   accepted anything, which is worse than the error.

   The reachable trigger is a wildcard `:requires` in a `.prologos` file: the
   WS reader splits `:m.*` into `:m` `.` `*`, so it is a hard registration
   error there. (The wildcard spelling survives only the native sexp reader,
   which is why `test-selection-compose.rkt` exercises it happily — another
   instance of the sexp-green ≠ WS-correct rule in `prologos-syntax.md`.)

   Fixed with an explicit `stub?` field on `selection-entry` and a check in
   `validate`'s elaboration arm. The two obvious cheaper markers do NOT work
   and the reason is worth keeping: `requires-paths = '()` is legitimate (a
   selection may have only `:provides`), and `srcloc = #f` is taken — typing-core
   mints synthetic sub-selections with no location. 5 construction sites, all
   enumerated per the struct-field checklist (4 `selection-entry` calls + the
   `regN!` registration); zero `struct-copy` sites.

   The WS tokenization of `.*` — which was the reachable trigger for this — is
   FIXED above, so the stub path now needs a different way in (a `:requires`
   naming a field the parent schema lacks is the one the test uses). The stub
   guard stays regardless: ANY failing declaration leaves the same stub, and
   the guard is about the stub, not about the particular way in.

`defr : Schema` fact-row runtime validation rides the same charter (an adapter
over the positional discharge, parser.rkt `parse-defr-schema-typed`).

**✅ ITEM 3 (sub-schema descent) FIXED 2026-08-03 — the nested-`validate`
asymmetry is closed.** Re-probed at HEAD first and the report was still exactly
true: `[validate Config bad]` with `bad.server.port = "x"` returned **`ok`**.
The framing that made it worth doing ahead of the rest of the charter is that
it was an **ASYMMETRY, not a missing feature** — the STATIC seal descends into
a nested literal and rejects the bad inner field; runtime `validate` did not.
Runtime validate is the demo's headline flow (external data → validate →
Result), so the two ran the wrong way round relative to each other.

**The fix is a fifth tag kind, not a second validator.** `field-type->witness-tag`
gained a `(row (K . T) …)` arm and `value-witnesses-tag?` gained its
interpreter. Depth comes from the TYPE's own shape, so a schema nested three
deep tags three deep with no depth parameter; the projection reuses
`schema->row` rather than re-enumerating fields. Tags stay plain s-expressions,
so `.pnet` serialization needed no change at all.

Four things worth carrying forward:

- **A schema NAME does not `whnf` through to its row.** Verified by
  instrumenting the bake: `whnf` leaves `(expr-fvar 'M::Server)` alone. The
  registry lookup is what resolves it — the first cut matched only
  `expr-Record` and changed nothing, which is how this was found.
- **The seen-set is load-bearing, and was proved so rather than assumed.**
  `schema Node :next Node` is expressible TODAY (a field type is a bare name
  through the same registry). Removing the guard hangs the probe — verified,
  25 s timeout, exit 124. On a cycle the tag degrades to `'any`: the D28
  posture, and the honest form of the charter's "depth discipline" gate —
  cyclic descent is DECLINED, not silently mis-tagged.
- **Two deliberate ACCEPTS keep err-polarity.** A non-map value accepts (the
  witness must not assert a type error it cannot substantiate), and a MISSING
  nested key accepts (absence is the PLAN's business — it owns `required?` and
  reports against the right key; from here it would surface as a type-mismatch
  on the PARENT field, naming the wrong thing). The arm rejects on exactly one
  condition: a key that is PRESENT and definitively fails its own tag.
- **The `got` payload names the path.** `type-mismatch "Server" "Map"` is true
  and useless — the value IS a map; which field is wrong is the whole question.
  `witness-got-string` walks to the first failing key: `"Map (:port is String)"`,
  or `"Map (:b.:c is String)"` when the miss is deeper. Non-row tags are
  untouched, pinned by a test.

Both sub-schema spellings work: a named schema (`:target Endpoint`) and the
inline layout form (`:s` / indented sub-fields → the auto-registered
`Parent__s`). Pinned at unit level (`tests/test-field-witness.rkt`, +6 cases)
and Level 3 (`examples/2026-07-17-ciu-t6-f1b5-validate.prologos`, markers
28-33 — including the good case, the missing-key case, and the payload text).

⚠ **Found in passing, filed rather than fixed**: a BRACE in schema-field type
position (`:s { :n Int }`) is not the inline-sub-schema spelling — it elaborates
to `(expr-app (expr-app (expr-fvar '$brace-params) …) …)`, a garbage head that
tags `'any` and silently witnesses nothing. The layout form is the supported
one. This is the `{…}`-in-type-position disambiguation the owner already owns
(see § the row-annotation ruling), so it is not fixed here.

**Items #1 (container/nested traversal), #2 (tier-2 element recursion) and #4
(nested/wildcard selection requires-paths) remain open** — a list-typed field
still does not check its elements, and a selection's deep `:requires` still
defers. Entry-gate (a) [a real nested-schema demo consumer] stays the watch for
those.

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

   > **The minimal version was BUILT, MEASURED UNSOUND, and reverted
   > (2026-08-04). Worth recording, because it looks right.** Adding an
   > `expr-meta` arm to `expr-map-get`'s typing that solves the meta to the
   > weakest supporting row — `{:k ?v | _}`, via `unify` for the `solve-meta!`
   > coupling — delivers exactly what this entry describes, for ONE field:
   >
   > ```
   > defn f [p] p.x        ⇒ f : {:x _ | _} -> _        ← the constraint, inferred
   > [f {:x 42 :y "o"}]    ⇒ 42
   > [f {:x "str"}]        ⇒ "str"                      ← polymorphic in the field
   > ```
   >
   > It breaks on the SECOND field. `defn g [p] [int+ p.a p.b]` infers only
   > `{:a Int | _}`: the second projection hits an already-solved DYN row, and a
   > dyn-row miss mints a fresh meta (D19) instead of EXTENDING the row. The
   > demand for `:b` is silently dropped — and then:
   >
   > ```
   > [g {:a 1}]   ⇒ [int+ 1 <error>] : Int      ← at ZERO errors
   > ```
   >
   > A clean "cannot infer" refusal becomes an `<error>` embedded in a result
   > the command reports as successful. Strictly worse than the status quo, so
   > it is not shipped.
   >
   > **What this pins down for whoever opens F-row**: the load-bearing piece is
   > not solving the meta initially — that part is ten lines. It is **row
   > EXTENSION on an already-solved dyn row**, i.e. a genuinely row-polymorphic
   > unifier where the tail is a variable that accumulates field demands, rather
   > than the D19 mint-a-meta-on-miss behaviour. "Solve it structurally" in the
   > line above is doing all the work in that sentence.
   >
   > **Scoped 2026-08-04** so the size is known before anyone starts.
   > `expr-Record`'s tail is a SYMBOL (`'closed` / `'dyn`); a row variable needs
   > it to admit a meta.
   >
   > **Re-checked 2026-08-05, and the missing piece is WHY that representation
   > change is unavoidable rather than one option among several.**
   > `metavar-store.rkt:1884`: *"Assign a solution to a metavariable. **Errors if
   > already solved.**"* Monotonicity is enforced, by design. So extending a row
   > that has already been solved cannot work by re-solving its meta — the only
   > route is for the row to have been solved to something that CONTAINS a fresh
   > tail meta, and extension then means solving THAT. Which is precisely a row
   > variable. The 29 read sites are load-bearing because every one of them
   > pattern-matches a symbol and would meet a meta.
   >
   > That is the difference between this entry and the three "needs a ruling"
   > calls I got wrong this session: those dissolved when I looked at the code,
   > and this one got HARDER. The obstacle is a checked invariant, not an
   > unexamined assumption of mine.
   >
   > Measured surface (re-counted 2026-08-05; the earlier 28/83 had drifted):
   >
   > - **29** `expr-Record-tail` sites across 5 files (typing-core 17, syntax 5,
   >   unify 4, union-types 1, typing-errors 1)
   > - **83** literal `'closed`/`'dyn` occurrences — every `(eq? tail 'dyn)`
   >   becomes an `open-tail?` predicate, and missing one silently mis-classifies
   >   an open row as closed
   > - a new **row-unification** case (two rows, both with variable tails), which
   >   is where the soundness lives
   > - the `pipeline.md` struct-field checklist: every walker — `shift`,
   >   `subst`, all three `zonk`s, `pretty-print`, `occurs?` — must descend into
   >   a meta tail, and per that file's § Exhaustive Walkers a missed arm here is
   >   silent
   >
   > Not a slice. A rejected shortcut worth naming: a syntactic pre-pass over the
   > `defn` body collecting `(map-get p :k)` demands up front would fix the
   > direct multi-field case soundly, but leaves the same hole for a param passed
   > opaquely to a callee that projects it — the demand is invisible to the scan.
   > That is the second plausible-looking version of this fix; it fails for a
   > different reason than the first.
2. **Generic `+`/arithmetic on an untyped param** — `defn f [x] [+ x 1]` fails
   standalone (pre-existing): `+` needs `x`'s type. **Deep fix = Num Track 2**
   (generic `Num` / constraint-as-type): constrain `x : Num`-ish from `[+ x 1]`.
   Seed note `2026-07-02_GENERIC_NUM_TYPE_NOTE.md`. Entry gate: Num Track 2 opens.

Neither blocks records-correct-in-principle (annotate or spec is the workaround);
the mitigation makes the workaround discoverable.

### ✅ Re-probed 2026-08-04 — claim 1's "or a spec" was NOT TRUE, and the reason was a SOUNDNESS hole (now fixed)

Both soft spots still reproduce as filed when there is neither annotation nor
spec — those are correctly routed to F-row and Num Track 2 and are untouched.

But the entry's stated workaround — "annotate **or spec** is the workaround" —
was false for the projection case, and the reason turned out to be worse than a
missing feature.

**The hole.** A `defn` whose body is EXACTLY a `.field` projection reaches spec
injection with its access sentinel still raw, so `defn e [p] gpt.x` arrives as
the two body forms `(gpt ($dot-access x))`. `inject-spec-into-defn` declines
when the body has >1 form led by a bare symbol — a guard aimed at the
unbracketed-application mistake (`defn bump [x] int+ x 1`), whose comment
asserted "only the unbracketed-application mistake leads with a bare symbol".
A projection's BASE is a bare symbol too.

So the spec was **silently dropped**, and unlike the case the guard was built
for, nothing spoke afterwards — once folded the body is a well-formed single
form, so the parser had nothing to complain about:

```
spec e1 Point -> Int
defn e1 [p] gpt.x       ⇒  e1 : _ -> Int     ← 0 errors, spec ignored
[e1 "not a point"]      ⇒  1 : Int           ← ACCEPTED
```

The declared parameter type was not enforced at call sites. A green suite says
nothing about this class; it was found by asking why the entry's own stated
workaround did not work.

**Fixed** (macros.rkt) by counting the forms the body will have once folded —
each access sentinel consumes exactly one preceding element, so that count is
`length - sentinels`. The guard keeps firing exactly where it was aimed:

| body forms | effective | verdict |
|---|---|---|
| `(int+ x ($dot-access a) 1)` | 3 | DECLINE — the good message still speaks |
| `(int+ x 1)` | 3 | DECLINE — unchanged |
| `(gpt ($dot-access x))` | 1 | inject |
| `((let x 4) (let y 5) body)` | head is a list | inject — unchanged |

(A first attempt simply skipped the guard when any sentinel was present. That
would have disarmed it for `defn bump2 [p] int+ p.x 1` — the mistake WITH a
projection in it. Pinned as its own test.)

**WS-only**: the identical program in sexp always succeeded, so the pins are
Level 3. **Not fallout from item 17** — verified against a build of the
preceding commit.

Nine pins in `tests/test-error-messages.rkt` fix the whole remedy table,
including the unsoundness itself (a `String` passed to a `Point` parameter must
be refused) and the guard's original target. Verified they fail with the fix
reverted.

**Knock-on**: one pin in `test-path-selection.rkt` was silently relying on this
bug — it wrote a spec and expected the "unannotated parameter" message, which
only appeared because the spec was being declined. Rewritten to drop the spec
(restoring the two-failures-at-once shape it is about), plus a new pin for the
improved spec'd behaviour.

**The mitigation message is unchanged in the end** — "Add a `spec`, or annotate
…" is now true, because the counterexample was fixed rather than the claim
weakened. It was briefly reworded to state the corner; that wording is reverted. Do NOT attempt the deep fixes
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

## CIU T6 (post-F1b): explain restructure — provenance beside the rows — RE-PROBED 2026-08-03, entry ACCURATE and its guard VERIFIED

The interim clobber guard the entry describes is real and works. Measured:

```
defr provrel [?provenance]
  || "x"
explain (provrel provenance)
⇒ @[{:provenance "x"}]              ← the BINDING wins; no metadata inserted
```

versus an ordinary query, where the metadata is present:

```
defr color [?c]
  || "red"
     "blue"
explain (color c)
⇒ @[{:c "red"  :provenance {:depth 0N :clause-id :color/1-0 …}}
    {:c "blue" :provenance {…}}]
```

So binding-wins-on-collision holds for the live reserved key, and a query
variable named `?certainty` also round-trips cleanly. The structural point the
entry makes stands unchanged — provenance is merged INTO the row's namespace
rather than sitting beside it, so the two can only ever coexist by one of them
yielding. Not blocked; open when the explain surface next gets attention.

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

**MEASURED 2026-08-03 — the four are NOT one class, and the suite cannot tell
you which.** Lifting each skip individually and running the affected files:

| lifted | affected-file result |
|---|---|
| `add` | 24 failures |
| `sub` | 21 failures |
| `join` | all pass |
| `reduce` | all pass |

`join` + `reduce` lifted together were **green on the FULL suite** (542 files).
That is the wrong conclusion, and the probe that corrected it is the point:

⚠ **`join` CANNOT lift. With it lifted, `[join "-" '["x" "y"]]` fails outright**
— "Could not infer type", cascading to "Unbound variable". The entire suite
stayed green because **nothing in it calls `join` at all**. The entry's stated
reason for the `join` skip ("string-ops join — spec clobber; heavily used") was
correct the whole time; there was simply no test able to say so.

That gap is now closed: `tests/test-trait-method-derive.rkt` gains a `join`
case, verified to FAIL with the skip lifted. Note also that its neighbour —
"derive/skip-set-preserves-list-reduce", which looks like it guards `reduce` —
does **not**: A/B shows `[reduce int+ 0 '[1 2 3]]` is byte-identical with the
`reduce` skip lifted. It is a documentation pin, and is now labelled as one.

**THE BLOCKER IS NOT (only) THE SPEC STORE — measured 2026-08-03.** After
issue #66's qualified-lookup fix landed, the skips were re-tested: still 24
failures with all four lifted. So the entry's attribution to "spec-CLOBBER
only" is incomplete. The derived wrapper is a top-level `def` under the BARE
method name, so it shadows the imported function's **VALUE**, not just its
spec — and no spec-store fix reaches that.

**The skip set is mechanizable, and here is how far a one-line predicate gets.**
Adding `(not (global-env-lookup-type mname))` + `(not (lookup-spec mname))` to
`derivable-method?` — "do not derive a name something already binds" — and
emptying the hand-maintained list takes the affected-file failures from
**24 to 4**. That is the structural answer this codebase prefers to a
hand-maintained enumeration, and it is most of the way there.

The remaining 4 are all in `test-firstclass-ops.rkt` and are an ORDERING
problem, not a counterexample to the idea: the predicate as written skips a
derive whenever the name is bound AT THAT MOMENT, which over-fires for methods
whose binding comes from a module loaded earlier in the same prelude sweep
(`to-float`, `abs`, `neg`). The predicate wants to be "bound by an import from
a DIFFERENT module" rather than "bound at all", which is the same
module-provenance question issue #66 and POL.9c both wait on — and it needs the
elaboration-vs-module-load two-context care `pipeline.md` records.

**✅ SHIPPED 2026-08-03 after the residual was diagnosed — the list is down
from FOUR names to ONE.** The 4 leftovers were not an ordering problem in the
sense first guessed; they were the MULTI-PASS one. Preparse re-walks the forms,
so on the second pass the name is bound *by our own wrapper from the first*, and
a naive `(not (global-env-lookup-type mname))` then declines to regenerate the
def — the wrapper silently disappears. Adding a `derived-wrapper-names` set, so
the guard can tell "someone else binds this" from "we bound this last pass",
takes it to 1. (Same multi-pass shape as the trait registry registering three
times for two declarations, one entry up.)

Progression, measured on the 24 files that break when the list is emptied:
**24 failures → 4 (naive guard) → 1 (re-derivation fix) → 0 (with `join`
listed).** Full suite green, 543 files.

**`join` is the one that cannot be computed away**, and the reason is load
ORDER: when the trait carrying it is processed, `string-ops` has not been
loaded, so there is no binding for the guard to see. The derived wrapper then
shadows string-ops' `join` at the **VALUE** level — not the spec-store clobber
this entry originally blamed, so no spec-store fix reaches it either. Seeing it
needs the whole program's name universe up front: the module-provenance
question this item and issue #66 both wait on.

⚠ **And `join` is exactly the one the suite could not see** — per-method A/B
called it safe, the full suite agreed, and `[join "-" '["x" "y"]]` fails
outright with it derived. All four calls are now pinned in
`test-trait-method-derive.rkt`, verified byte-identical against the pre-change
hand-list baseline, so "the guard replaced the list without changing anything"
is a fact rather than a claim.

**And the corpus was run for the same reason** — the suite had already been
shown insufficient here once. All 50 `examples/*.prologos` through
`run-file.rkt`, hand-list baseline vs computed guard: **total diff FOUR LINES,
and the only difference is a gensym counter**. The instrument that would have
caught a `join`-shaped regression was used before shipping this time, not
after.

**So the honest state is**: `add`/`sub` are hard-blocked (measured, loudly).
`join` is blocked, now with a test that says so.

`reduce` shows no breakage anywhere it was looked for — the full suite, the 24
affected files, targeted probes of four call shapes, and an **examples-corpus
A/B: all 50 `examples/*.prologos` run through `run-file.rkt` in both states,
total diff FOUR LINES, and the only difference is a gensym counter
(`?suc0_8381` vs `?suc0_1973`)**. That is as close to byte-identical as the
corpus can report.

**It stays skipped anyway.** "No breakage found" is precisely what the full
suite said about `join` an hour earlier, and `join` was broken in the most
basic call anyone would write. The corpus is a stronger instrument than the
suite was — it exercises real programs — but it is still an absence, and the
skip exists to protect against a named mechanism (issue #66's bare-name race)
that has not been fixed. Lift it when the race is fixed, not when a search for
counterexamples comes up empty.

### 2. 🔶 Spec-store bare-name keying — silent clobber (structural defect) [issue #66] — QUALIFIED lookup fixed 2026-08-03; the race itself is open

- **What**: the spec registry keys by BARE symbol with silent last-write-wins:
  `register-spec!` (`macros.rkt:480-482`), import spec-propagation
  (`driver.rkt:2810-2811`), and implicit-hole counting strips FQNs before
  lookup (`elaborator.rkt:567-576`). Two same-named specs from different
  modules (e.g. nat's `add` vs a generic `add`; a derived `reduce` vs
  `list.prologos`'s `reduce`) overwrite each other in any module importing
  both.

  ⚠ **"the loser's call sites get WRONG implicit-argument counts" — CORRECTED
  2026-08-03, after trying to reproduce it.** The claim holds for a QUALIFIED
  call to the loser (probed: "Could not infer type", cascading; now fixed by the
  qualified key). It does NOT hold for a BARE call, and the reason is
  structural: value resolution and spec propagation both follow import order
  over the same import list, so **they agree**. Measured — an unqualified
  `[length xs]` with both modules imported gives the right answer, and it is
  byte-identical with the qualified-lookup probe removed, i.e. it was never
  broken. Instrumenting the lookup shows why: a bare `[length xs]` arrives at
  the spec site already resolved to `prologos::data::list::length`.

  The W3001 message was written from the un-reproduced claim and has been
  corrected to say only what holds: the NAME is ambiguous and which module
  answers to it depends on import order. Worth telling someone — they may get a
  different function than they meant — but a question of MEANING, not of a
  corrupted argument count.
- **Fix direction**: FQN-keyed spec store (or module-scoped shadowing with
  deliberate resolution order). Crosses the module system — candidate for a
  PM-series follow-up. Blocks item 1's clean resolution.

**🔶 THE QUALIFIED HALF LANDED 2026-08-03.** Import propagation now files each
spec under `module::name` as well as the bare name, and the three elaborator
lookup sites probe the qualified key first. So **the workaround W3001
recommends — "qualify the call" — actually works now**, where before it did
not: the loser of the bare-name race had NO reachable spec at all, so even a
call naming its module explicitly got the winner's implicit-argument count.

Observable, and verified failing-test-first rather than assumed: with
`prologos::core::collections` imported first (so `list` wins the bare write), a
qualified `[prologos::core::collections::length xs]` reported *"Could not infer
type"* and cascaded to *"Unbound variable"*. It now elaborates.

⚠ **A first A/B of this measured the same binary twice** — a `cd` in a `&&`
chain failed, the rebuild never ran, and both legs printed identical output,
which read as "the change does nothing". The workflow rules record exactly this
trap; it cost a wrong conclusion until the run was redone with absolute paths.
The eventual instrumented probe (`FQNDIFF`) showed the qualified key resolving
to a *different* spec entry on every qualified call — the code path was live all
along.

**This does NOT fix the race**, and the entry stays open for that reason: a
genuinely unqualified `map` still resolves by import order. (What that costs is
narrower than this entry originally claimed — see the correction above.) What changed is that
there is now a working escape hatch, and W3001 names it. The remaining work is
the module-scoped store — and it now has a measured target: **the prelude's own
12 order-dependent spec names**, which W3001 deliberately does not report
because a user cannot act on them.

Bare-name behaviour is untouched by construction (FQN first, bare fallback), so
this can only turn a wrong answer into a right one. Three byte-identical
hand-inlined strip-then-lookup loops in `elaborator.rkt` collapsed into the one
`lookup-spec/qualified` helper on the way — otherwise the FQN probe would have
had to be added three times.

### 3. 🔶 Zero-arg / output-position-only trait methods as context-resolved values — the OUTPUT-POSITION half DONE 2026-08-03; the ZERO-ARG half open

**The entry's diagnosis was wrong about where the blocker was, and measuring is
what showed it.** It says expected-type-directed constraint resolution "is
UNPROVEN at HEAD — no machinery confirmed for solving an output-position
constraint meta from the checking direction". It works. A hand-written

```
spec mk {A} Int -> A where (Gen A)
defn mk [s] [gen s]
def a : Int := [mk 5]        ;; => -95 : Int
```

resolves the constraint from the annotation, today, with no changes. So the
machinery was never the problem — what blocked trait METHODS was
`derivable-method?` refusing to emit their bare wrapper, because it required
every trait parameter to occur in a DOMAIN position.

**Relaxed**: a parameter may occur in the RESULT position too, provided the
method TAKES arguments. `gen : Int -> A` and `convert : A -> B` now derive;
`def a : Int := [gen 5]` and `def b : Bool := [gen 4]` pick different instances
from the identical call shape. Verified end-to-end rather than by counting
generated defs — with `impl Convertible Int Bool`, `[convert 0]` gives `true`
and `[convert 5]` gives `false`.

**`(pair? doms)` is the boundary, and it is the honest half of the split.** A
method that takes arguments gives the checker an APPLICATION to hang an
expected type on. A bare constant — `zero : A`, `one`, `bot`, `empty-coll` —
has none, so it still derives nothing and **`def o : Int := one` is still
`Unbound variable`**. That is the ZERO-ARG half of this item, still open, and
now separately pinned in `tests/test-gen-trait.rkt` so the two are not confused
for one another.

**Unblocks, immediately**: `Gen`'s bare `gen` (§ Spec System Phase 2), which is
what led here — building `Gen` is what exposed that the entry blamed the wrong
component. The N6f `sum`/`product` dependency below is NOT unblocked: those
call the nullary identity accessors, which are the zero-arg half.

**Verified with the corpus, not just the suite**, because this ADDS bare
wrappers and that is precisely the shadowing shape `join` had (a green
542-file suite said `join` was safe to derive when it was not). All 50
`examples/*.prologos` through `run-file.rkt`, before vs after: **diff of FOUR
LINES, and the only difference is a gensym counter**. Also probed directly the
names this newly derives — `from`, `try-from`, `into`, `from-integer`,
`from-rational`, `alpha`, `gamma` — and A/B'd `into`, the one that collides
with a collections function: identical.

**Original entry:**

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

### 4. ✅ Registry silent-overwrite: duplicate-binding diagnostics [issue #67] — SPEC-STORE SURFACE DONE 2026-08-03

**🔶 FIRST SLICE — the census is mechanical.** Item 4 asks for a duplicate-binding diagnostic and
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

**✅ SECOND SLICE LANDED 2026-08-03 — W3001, the diagnostic itself, DEFAULT-ON.**

The filing said "the DEFAULT-ON-vs-opt-in question is a UX call". It was
settled by measurement, and the measurement moved twice — both times because a
probe contradicted the previous number, which is the part worth keeping:

1. First claim: *"a plain prelude load collides zero times"*, from the census's
   `register-spec!` instrumentation. **Wrong for this purpose** — that is a
   different SITE. At the PROPAGATION site the prelude collides on **12 names
   by itself** (`all? any? concat drop filter find head length map reduce
   reduce1 take`), because it imports both `prologos::data::list` and
   `prologos::core::collections`. So a naive default-on warns on every file
   anyone ever writes. **That is a real finding about the prelude**, recorded
   here, and it is item 1's clobber set seen from the other end.
2. Second attempt compared against the whole spec store, which then fired on a
   SINGLE explicit `imports prologos::data::list` (14 names) — because an
   explicit import shadows the prelude, which is what explicit imports are FOR.

The rule that survived is **actionability**: warn when the user's OWN imports
collide with EACH OTHER, and only then. Prelude-internal is the project's
problem, not the user's; shadowing the prelude is deliberate. What is left is
the case the user created and can fix — and on that set default-on has no false
positives, which is what earns it the default.

Shape, and each piece has a reason:
- **The gate is "the implicit-argument shape DIFFERS"** (where-constraints +
  implicit-binders), not "a write happened" — so re-importing the same module
  twice is silent. Measured: all 14 collisions in the realistic pair differ, so
  the gate costs no coverage here; it exists for the cases where it would.
- **ONE line listing the names**, not one per name. The realistic pair collides
  on 12 at once and the sentence is identical for each; the list IS the
  information.
- **No winner is named.** The first cut said "X wins here" and the probe
  falsified it immediately — preparse walks the import list TWICE, so every
  name warned once per direction with OPPOSITE winners. The census had already
  established that "last import wins" is FALSE (`sum` is the counterexample);
  order-DEPENDENCE is the true claim, so that is what the message makes.
- **File-level, not per-command.** These are raised during preparse, before any
  command runs, so `reset-warning-cells!` (per command) would wipe them before
  anything could report them — and leaving them in the per-command channel
  would repeat all 12 under every command in the file. Appended once by
  `process-file-inner`, which also gives it a per-FILE reset. That reset is not
  optional: without it a long-lived process reports every earlier file's
  collisions under the current one. Found exactly that way — the four W3001
  tests passed one at a time and three failed in file order.

**A CORRECTION to the paragraph above, made after reading the code rather than
the numbers.** The prelude's 12 "collisions" are not latent bugs — they are a
DELIBERATE shadow, and `namespace.rkt` says so at the site:

    ;; These shadow List-specific names (map, filter, reduce, etc.) with
    ;; generic versions that work on any Seqable/Buildable/Foldable collection.
    ;; MUST BE LAST — shadowing depends on ordering.

So W3001 declining to report them is right for a second reason: they are
intended. Describing them as "12 order-dependent spec names" as though they were
a defect overstated it, and the overstatement came from reading a measurement
without reading the code that produced it.

**The real exposure on this surface is that the invariant is enforced by a
COMMENT.** Move that `imports` line up and twelve names silently change meaning
with the suite green. `tests/test-spec-store-clobber.rkt` now pins it: every one
of the twelve must resolve to the CONSTRAINED (collections) spec, and the
qualified List spec must still be reachable. Asserted via where-constraints
rather than whole entries — those are what drive implicit-argument counts, and
what W3001 itself gates on, so the pin tracks the property that actually breaks
call sites instead of failing on innocuous edits.

⚠ **Sensitivity verified, and the FIRST perturbation did not trip it**: moving
the collections import a few entries earlier changed nothing, because the new
position was still after `prologos::data::list`. Moving it to FIRST fails with
the intended message. A perturbation that does not fail proves nothing about the
test — only about the perturbation — and stopping at the first one would have
shipped a guard never seen to fire.

**✅ THIRD SLICE 2026-08-03 — the TRAIT registry is now censused too**, and the
finding is an ASYMMETRY sitting fifty lines apart in `macros.rkt`:

- `register-impl!` checks for a duplicate and **RAISES** ("Duplicate instance:
  ~a already registered …").
- `register-trait!`, immediately above it, is a bare `hash-set` — no check, no
  error, no warning.

Two registries with the same shape and the same hazard ship OPPOSITE policies,
and nothing anywhere says which is intended. Measured: a trait redefined in one
file silently wins, and re-types the FIRST trait's accessor — `Shrinkable-shrink`
is defined twice with different types, at zero errors. Pinned in
`tests/test-spec-store-clobber.rkt`; if a diagnostic lands, that test's
`check-false` on "duplicate" is the assertion that flips.

No diagnostic built, for the reason W3001 already had to answer: preparse walks
the declarations more than once (instrumenting `register-trait!` shows THREE
overwrite events for two declarations), so a naive error fires spuriously.
Deciding error-vs-warn — and whether same-file trait redefinition is legitimate
at all, given `defn` redefinition is — is a policy call, and the point of
locking the behaviour is that the call gets made deliberately.

Remaining: the import-shadowing surface (`namespace.rkt` VALUE bindings) is
still uncensused. Note WHY that census is not a one-liner, since the spec census
already paid for the lesson: a final-state diff cannot see an overwrite, so it
needs registration-EVENT instrumentation — the same reason instrumenting
`register-spec!` reported zero collisions while the propagation site had 14.

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

## ✅ FIXED 2026-08-05 — Union-type checking hangs the type-checker (BSP non-quiescence). The carrier was not idempotent; the join was innocent

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

- **✅ FIXED 2026-08-05 — and the 14-month-old hypothesis was pointing at the wrong layer.**

  Profiled the three-command repro (25 s sample, 6437 samples): `tagged-cell-read`
  (`decision-cell.rkt`) is **49% of total**, and `attribute-map-merge-fn` under it
  is **30% SELF**. That matches the original `attribute-map-merge-fn` sighting —
  but the call is coming from the READ side, not from a write-side join, and that
  changes the diagnosis entirely.

  **Root cause**: `tagged-cell-merge` and `make-tagged-merge` both unioned their
  entry lists with a bare `(append (entries new) (entries old))`. So
  `(merge x x)` returned **twice** x's entries — the merge is **NOT IDEMPOTENT**,
  which is the one property `structural-thinking.md` requires of every cell merge
  in this system, and which nothing asserted for this one.

  A cell whose lattice VALUE is stable but whose REPRESENTATION grows every round
  reads as *changed* to the scheduler. Dependents re-fire, re-write the same
  entries, and round N+1 is round N plus one more copy. `tagged-cell-read` merges
  every matching entry on every read, so per-read cost grows with the list too —
  which is why it presented as an accelerating hang with unbounded memory
  (measured: 99.8% CPU, RSS 643 MB and climbing at 15 s).

  **So the `:type`-facet union join was never the problem.** The join may be
  perfectly convergent; the CARRIER underneath it was not a lattice. The entry's
  "type-lattice-convergence investigation" framing sent this at SRE Track 2H's
  quantale work for over a year; the fix is 8 lines in `decision-cell.rkt`.

  **Fix**: `union-entries` dedups by `equal?` on the whole `(bitmask . value)`
  pair, keeping the FIRST occurrence — exactly what the ordering contract already
  required ("NEW entries first — later writes win at same specificity"; the read
  takes the first match when no domain-merge is supplied). Deliberately a linear
  `member` scan, not a hash: `pipeline.md` records that `equal-hash-code` is
  depth-bounded at ~17 levels, so hashing expr-bearing values degrades to a
  linear scan running full structural `equal?` anyway. The scan keeps n from
  growing, so n stays small.

  **Verified**: all five filed repro shapes complete in ~4 s at 0 errors and with
  CORRECT answers — the 3-command `[int+ 1 2]` form, the original order-dependent
  `the <Int | String>` form, the `[+ 1 2]` trait form, the String-initialised
  form, and the F1b.3 polymorphic-spec form (recorded 2026-07-17 as an apparently
  separate hang; same defect). The three controls that always completed still
  complete. Full suite **559 files / 10888 green**.

  Pinned in `tests/test-union-type-quiescence.rkt`. Perturbation-checked: with
  the dedup reverted, the two lattice-contract cases fail instantly with
  `actual: 4 / expected: 2` and four repro cases report "did not finish within
  25 s — the network is not quiescing".

  **The fuel half — one real defect found and fixed, but the ask is NOT
  discharged.** The entry also wanted "a fuel bound on the typing/elaborator
  network so non-convergence becomes a bounded diagnostic instead of a hang".
  Chasing why the existing bound never tripped found this:

  `fuel-cell-id` declares `#:on-write-check (lambda (old new net) (<= new 0))`,
  which writes a contradiction structurally on exhaustion. But `on-write-check`
  was consulted **only on `net-cell-write`'s hot fast path**, and that path is
  gated on `(not (prop-net-warm-under-speculation? …))`. The slow path — the one
  every speculative write takes — checks `contradiction-fns` and **never looks at
  `on-write-check` at all**. So the fuel bound was disabled precisely while
  speculation was active, which is the one situation it exists for. Fixed:
  the slow path now ORs the cell's `on-write-check` into its contradiction test.
  Exactly one cell declares one today (fuel), so the blast radius is that cell.
  Suite green with it (559 files / 10888).

  **But that alone does NOT bound this hang** — with the carrier fix reverted and
  the fuel fix in, the repro still ran past 400 s. Diagnosed since (split out
  below): fuel is a FIRE-COUNT budget and the process is stuck inside ONE fire,
  so no fuel setting can help. **A hang is still the failure mode for the next
  non-convergence**, and the reason is now known rather than guessed.

  **Also stale**: the entry's "workaround in place: foray's union forms commented
  out". `lib/examples/foray.prologos` has no union forms left to restore, and its
  6 current errors are all `Unbound variable`, unrelated to this.

## Two more non-idempotent cell merges, found by the merge-law test on its first run (2026-08-05)

`tests/test-merge-laws.rkt` was written as the recommended answer to the entry
below — check the lattice contract instead of bounding the symptom. It found two
further instances of the same defect **on its first run**, which is the argument
for it existing.

**1. `nogood-merge` — FIXED.** Its own comment read "Merge: append (functionally
equivalent to set-union for unique nogoods)", two lines under a docstring
declaring "the lattice is P(P(AssumptionId)) under set-union. Monotone: nogoods
only accumulate." The parenthetical was doing all the work and nothing checked
it: `(nogood-merge x x)` returned the list twice. A live cell merge
(`atms.rkt:231`), so it carried the same non-quiescence hazard that hung the
type-checker for fourteen months. Now dedups; commutative and associative up to
set equality (the list representation has an order that set-union does not).

**2. `merge-hasheq-list-append` — the cells it served are RETIRED 2026-08-05.**

Not idempotent (`(merge {a:(1)} {a:(1)})` → `{a:(1 1)}`), and it was a cell merge:
the three wakeup cells at `metavar-store.rkt`. I filed three questions — what
writes them, is any writer non-idempotent, is a duplicate observable — and the
third answered the other two. **Nothing read them.**

| | |
|---|---|
| writes to the trait-wakeup cell | 6–11 per file |
| reads | **0, on all 51 example files** |

The three `collect-ready-*-for-meta` readers had no callers in the tree; their
`*-via-cells` siblings were retired in PPN 4C S2.b-iv for exactly this reason and
these were left only because they were out of that phase's scope
(`metavar-store.rkt:1108` says so).

**Retired**: 3 readers, `get-wakeup-constraints`, 3 `read-*` helpers, 3 cell
allocations, 3 parameters, their entries in `scoped-cell-ids` / the reset and
parameterize lists, `tools/batch-worker.rkt`'s save/restore lines, and 3 write
sites that ran on every command. Suite 560 files / 10914 green.

**The merge itself survives, unfixed and now unused by any cell.** Deduping it
would have been the wrong move: it would have tidied dead machinery. It stays in
`infra-cell.rkt` as a generic helper, still pinned in `tests/test-merge-laws.rkt`
as a KNOWN non-idempotent merge, so if a future cell adopts it the test says what
it is buying. `retract-hasheq-list-entries` also survives and stays reachable —
`process-retraction`'s dispatch is STRUCTURAL (it samples a value and asks "is it
a list?"), not keyed to those cells.

**The first attempt failed, and how is worth keeping.** I scoped it from a grep
of the READER names and missed the CELL-ID consumers: `batch-worker.rkt`'s
parameterize list, 8 assertions in `test-infra-cell-constraint-01.rkt`, and
`test-retraction-stratum.rkt` using a wakeup cell as the vehicle for its
hasheq-list retraction test. The build was clean — a linklet mismatch only
surfaces at instantiation — and targeted tests passed. Only the batch suite
caught it, via a "DEAD WORKERS" banner whose suggested cause (stale `.zo`) was
wrong while its verdict was right.

Three tests changed rather than deleted: the retraction case now pins the
STRUCTURAL DISPATCH through a surviving cell (better — `retract-hasheq-list-entries`
already had five direct unit tests, so the old case was only ever testing the
dispatch); `test-infra-cell-constraint-01`'s three hollow wakeup cases went, and
the "all cells empty after reset" case got its five real assertions back; and the
`scoped-cell-ids` count moved 11 → 8. That last one is the assertion that noticed
the removal, which is what a count pinned against a list is for.

## `merge-list-append` is a CELL merge at 8 sites, and the law test said it was "a helper" (2026-08-05)

Third finding from the merge-law arc, and the first one where the **test's own
comment** was the defect.

`tests/test-merge-laws.rkt` pinned `merge-list-append` as a known non-lattice
with the note: *"If a cell ever adopts this merge and its writers are not
write-once, expect the union-hang shape."* The antecedent was **already true**
when that was written. Censused:

| site | cell |
|---|---|
| `warnings.rkt:108/110/112/114/116` | 5 warning cells |
| `global-constraints.rkt:102` | narrow-constraints |
| `relations.rkt:3136` | the query **answer accumulator** |
| `infra-cell.rkt:309` | `net-new-list-cell`, the generic constructor |

This is the exact failure mode the file exists to catch — a claim about a merge,
asserted rather than checked — reproduced inside the guard written to catch it.
Found by asking the registry what was registered rather than reading the
comment: the static scan showed ~30 registration sites against 13 in the law
table, and probing the four easiest uncovered ones turned this up on the first.

**It is nonetheless NOT the `tagged-cell-merge` hazard, and the reason differs
per consumer** — which is why "add dedup" would have been wrong:

- The **5 warning cells** are written IMPERATIVELY (`warnings-cell-write!`
  `set-box!`es the network from `emit-*-warning`), not by a propagator fire, and
  `reset-warning-cells!` clears them per command. Nothing ever re-merges a cell
  with its own value, so there is no fixpoint to fail to reach.
- **`relations.rkt`'s answer accumulator IS propagator-written** (`:3013`, the
  gating-success writers) — and there the non-idempotence is **REQUIRED**. Rel
  T1 POL.1 is an owner ruling that solution sets are **BAGS**: one row per
  derivation path, the multiplicity IS the derivation count (ℕ-semiring
  provenance). A global dedup on this merge would silently violate that ruling
  and break `solve`.

**Fixed**: the comment, with the census and the per-consumer reasoning, so the
next reader is not told the antecedent is hypothetical. Test green (28 cases).

**NOT fixed, and deliberately**: the merge stays non-idempotent. The residual
obligation is at the CELL, not the merge — if a new cell adopts
`merge-list-append` and its writers are propagator re-fires whose duplicates are
not meaningful, that cell needs a different merge. Nothing enforces that today;
it is the same gap as the entry below (no drift guard on the law table), now
with a worked example of what the guard would have caught.

**Uncovered — CLOSED to 8, and the residual has a NAMED obstacle (2026-08-05).**
A static scan of `register-merge-fn!/lattice` call sites (a property of the
TREE, unlike registry size) gave 29 registered against 13 covered. Probed and
added 8: propagator.rkt's four stratum-request accumulators
(`retraction-stratum-merge`, `fork-contradiction-request-merge`,
`decomposed-positions-merge`, `contradicted-branch-aids-merge`), three more
infra-cell facet merges, and `constraint-merge`. **Table 13 → 21, floor raised,
47 cases green.**

Two findings from doing it, both from the table catching MY assumption:

1. **`contradicted-branch-aids-merge` is not a set merge** despite registering
   under `'monotone-set` beside three that are — its carrier is a HASH of
   position → aid-set. I gave it set samples and it failed COMMUTATIVITY,
   because the non-hash guard arms return whichever argument is a hash. The
   domain name describes the ALGEBRA, not the carrier, and nothing says so.
2. **`constraint-merge` is idempotent only UP TO NORMALIZATION.** A
   one-element `constraint-set` merged with itself intersects to a singleton,
   which the merge's own `[(= n 1) (constraint-one …)]` arm normalizes — a
   different representation of the same lattice point. Not a defect:
   `constraint-from-candidates` normalizes at construction too (`:109`), so that
   shape is unconstructible through the public API. Pinned with a normalizing
   `equiv` so that if either normalization is removed, this says so.

**Second pass, same day — 21 → 24 covered, and I had invented the blocker.** I
first wrote that the residual 6 were blocked because they are module-private, and
framed widening those provides as a trade needing a ruling. That was
over-escalated: `merge-fn-registry.rkt` already exports
`reset-merge-fn-registry!` and its snapshot/restore pair under a "Testing
support:" comment, so exporting a merge in order to law-test it is **precedented
ordinary work**, not a design change. Six exports later the list is down to two
real residuals, and inventing a blocker cost more than the exports did.

**And the second pass found the thing this file was not looking for.** Of the six
newly-exported merges, three are joins (`worldview-merge`,
`hasse-merge-hash-union`, `merge-meta-solve-identity` — added to the table) and
**two are ACCUMULATORS**, which brings the count of registered cell merges that
are *not lattice joins* to **four**:

| merge | `merge(x,x)` | and it is CORRECT |
|---|---|---|
| `add-usage` (`qtt.rkt`, domain `'usage`) | `(m1) + (m1) = (mw)` | semiring ADDITION — using a linear resource twice makes it unrestricted. **Idempotence would break QTT.** |
| `merge-list-append` (`relations.rkt` answer cell) | `(append x x)` | Rel T1 POL.1 — solution sets are BAGS, multiplicity IS the derivation count. Idempotence would break `solve`. |
| `warnings-facet-merge` (`warnings.rkt`) | `(append x x)` | two identical warnings from two sites are two warnings. |
| `merge-hasheq-list-append` | grows | the one with no defence; its cells were write-only and are retired. |

**This makes the ambient rule too strong as written.** `on-network.md` says
"every cell value must be a lattice element with a monotone merge", and four
registered cell merges are not joins — three of them rightly. The honest
statement is that cells come in **two kinds**: JOIN cells (idempotent, hence
CALM-safe and order-independent) and ACCUMULATOR cells (not idempotent, so their
correctness depends on a property **nothing checks** — that their writers never
re-fire with a value already merged). `tagged-cell-merge` was an accumulator that
believed it was a join, and that is precisely the fourteen-month hang.

`merge-fn-registry.rkt` does not record the distinction: a domain name says WHICH
lattice, never WHETHER it is one. That is the registry gap worth closing, and it
is a better-specified version of the drift-guard entry below.

**CLOSED 2026-08-05 — all 28 registered merges are covered.** 24 in the `MERGES`
table plus the 4 accumulators pinned in their own cases. The table itself has 33
entries because it also covers the decision-cell family, which is **not
registered** — and that is precisely why it is hand-written rather than
registry-driven: `tagged-cell-merge`, the merge behind the fourteen-month hang,
is not in the registry at all.

⚠ **I got the arithmetic wrong twice, and the shape of the error is the useful
part.** I reported "13 of 29" and then "24 of 29" by subtracting the TABLE SIZE
from the REGISTRY SIZE — two different sets with a partial overlap. Coverage is
a **set difference**, not a subtraction. Asking it properly
(`comm -23 registered covered`) turned a claimed residual of 3 into **seven**
more uncovered merges (`context-facet-merge`, `session-lattice-merge`,
`table-answer-merge`, `table-registry-merge`, `tropical-fuel-merge`,
`type-lattice-merge`, `union-derivation-chains-merge`) — every one of which
probed idempotent on the first try and went straight in. A count is not a
coverage claim. The last two before that (`merge-classify-inhabit`,
`merge-by-timestamp-max`) needed only domain-typed samples; neither needed a
decision.

The enumeration now lives in the test file as a test-case, so it cannot rot
silently, and the floor is 33.

## ✅ CLOSED 2026-08-05 — the merge-law drift guard, on the third attempt

Filed the same day as "cannot be gated on the registry, and that is a registry
problem". The premise was half right: it cannot be gated on the registry's
**size**. It can be gated on the registry's **call sites**, which is a different
thing and needs nothing built.

**Attempt 1** — `(<= (merge-fn-registry-size) 40)`. Passed standalone, failed in
the batch runner at 46. `merge-fn-registry.rkt` is a process-global hash
populated by MODULE SIDE-EFFECTS, so its size is a property of whatever the
enclosing process loaded. Not a property of the tree; cannot gate anything.

**Attempt 2** — me running `comm -23 registered covered` by hand and writing the
answer into a comment. That found seven uncovered merges the counting had
hidden, and would have gone stale at the next registration.

**Attempt 3 (shipped)** — do the set difference IN THE TEST, against the source
text. Registration sites are a property of the TREE, so it is deterministic
under any loading order — the thing attempt 1 lacked. **No enumeration API on
the registry is required, so this does NOT wait on PM Track 12**, which is what
the entry originally said it was blocked on.

A text scan rather than a runtime enumeration, deliberately: the registry keys on
function OBJECTS, so a runtime view can only see merges whose modules the current
process happened to load. The source is the whole tree, always.

**It failed twice on the way in, and both are recorded in the file**:

1. `(build-path (current-directory) 'up)` resolved wrong under the batch worker
   and the scan found **zero** merges. Caught by a `(>= (length registered) 25)`
   sanity assertion written specifically so a scan-based check cannot go
   vacuously green — the failure mode of every scan-based guard. Fixed with
   `define-runtime-path`, resolved from the test file's own location.
2. The scan matched `merge-fn-registry.rkt`'s own `(define
   (register-merge-fn!/lattice merge-fn …))` and its provide list. Excluded the
   defining module BY NAME rather than writing a regex clever enough to tell a
   definition from a call — that regex is what breaks silently later.

**Perturbation-verified**: deleting `tropical-fuel-merge` from the table makes the
guard report exactly `'(tropical-fuel-merge)`. Restored, 66 cases green.

The diagnostic names the two legitimate ways to satisfy it — add a row with
domain-typed samples, or declare it in `ACCUMULATOR-MERGES` **and write the
reason into the ACCUMULATORS case** — and says "do not simply widen this list",
because the cheap way out of a coverage guard is to widen its allowlist.

## ✅ CLOSED 2026-08-05 — the suite re-run guard treated a ONE-FILE targeted run as "a suite run"

`run-affected-tests.rkt:313-325`. The guard keys on `timings.jsonl`'s mtime and
blocks a full-suite request when no `.rkt` has changed since it — the anti-pattern
it exists to stop (re-running 150s of suite to "see which tests fail") is real
and the guard is worth having.

But **it does not record WHICH run wrote that timestamp**. A targeted
`--tests tests/test-X.rkt` run writes `timings.jsonl` exactly like a full run
does. So the normal, correct workflow —

1. edit a file,
2. `--tests` it to iterate (fast, writes timings),
3. run `--all` as the regression gate

— has step 3 **blocked by step 2**, inside the 5-minute window, with the message
"No .rkt files changed since last suite run". Which is true and misleading: one
file ran, 559 did not, and the change has never faced the gate. Hit it exactly
that way while landing the merge-law drift guard; `--force-rerun` is the
documented escape and works, but the escape being needed on the happy path means
the guard is mis-scoped.

**Why it matters more than the 150s**: the guard's failure direction was toward
*not running the regression gate*, and its message actively reassured you that
one already ran. Every other guard in this tree fails toward more checking.

**FIXED** as described. The `'source` field in the timings record was hardcoded
`"affected"` for every run; it now records the actual mode
(`"all"` / `"targeted"` / `"affected"`), and the guard suppresses a full run only
when the LAST record was `"all"`. The `elapsed < 300` window and the changed-file
scan are unchanged. Unknown or absent `source` (schema < 3, hand-edited file)
counts as NOT-full, so the guard's failure direction is now toward running the
suite.

**Verified both directions**, because half a guard is worse than none — and the
real risk in a change like this is silently DISABLING the guard, which looks
exactly like success. The predicate was exercised against every input shape it
can meet:

| last record | guard blocks a re-run? | |
|---|---|---|
| `source: "all"` | **yes** | the guard still does its job |
| `source: "targeted"` | no | the bug, fixed |
| schema 2, no `source` | no | legacy records fail toward running |
| empty file | no | |
| file absent | no | |

Plus end-to-end: `--all` immediately after a targeted run now RUNS (previously it
printed GUARD and exited in under a second).

⚠ **The same trap was already documented in the same file, 380 lines below.**
`run-affected-tests.rkt:700` carries a comment on the LPT-sort scheduler: *"every
TARGETED run also appends a record, and 77% of all records are targeted
(1162/1503)... precisely the sequence that leaves a 1-6 file record last."* That
consumer was fixed 2026-07-27. The re-run guard reads the same file with the same
assumption and was not. **Two consumers, one trap, one file** — when a shared
artifact turns out to have a misleading shape, the fix has to sweep every reader
of it, not just the one that hurt. Worth remembering that the earlier fix's own
note recorded the measured impact as NIL and fixed it anyway "because a silently
degenerating optimizer is a lie in the code" — this second consumer is where that
judgement paid off.

## Fuel bounds FIRE COUNT, not work per fire — so it cannot make non-convergence a bounded diagnostic (2026-08-05)

Split out of the union-hang entry above, where it was the remaining half of
"a fuel bound so non-convergence becomes a bounded diagnostic instead of a hang".

**I filed a hypothesis here and then refuted it with a ten-minute probe.** The
filed guess was a retry loop at the CALLER: `process-command/demand` carried
16.5% SELF time in the 25 s profile, and `infer-on-network/full` restores the
saved fuel and clears the fuel contradiction on exit by design, so re-entering it
forever looked like the obvious candidate.

**It is not that.** Counting entries to `infer-on-network/full` under a synthetic
non-convergence (revert `union-entries` to a bare `append` to manufacture one)
gives exactly **2** — one per command, as designed. No retry. Breaking the hung
process gives the whole answer in one stack:

```
attribute-map-merge-fn        typing-propagators.rkt:447
tagged-cell-read              decision-cell.rkt:409
                              typing-propagators.rkt:1731
fire-and-collect-writes       propagator.rkt:2878
sequential-fire-all           propagator.rkt:3176
run-to-quiescence-bsp         propagator.rkt:3282
infer-on-network/full         typing-propagators.rkt:3010   ← entered twice, total
```

The process is stuck inside **one propagator fire**, in a single BSP run, merging
one colossal entry list.

**So the finding is architectural, and it generalises past this bug.**
`TYPING-FUEL-LIMIT` is 200 and the BSP round loop decrements fuel by the number
of propagators fired per round — fuel is a **fire-count budget**. It cannot bound
the COST OF ONE FIRE. A single fire whose input has grown without bound runs for
minutes, and no fuel setting changes that, because fuel is never consulted until
the fire returns.

That is why the entry's original ask cannot be met by "add a fuel bound to the
typing network": the bound is already there, it is already scoped per typing run,
and it is the wrong shape for this failure mode.

**What WOULD bound it**, roughly in order of how well each fits the
cell/propagator/scheduler orthogonality in `.claude/rules/on-network.md`:

1. **Bound the carrier** — a cell-layer property, and the one that actually
   fixed the union hang: if no merge can grow a value without bound, no fire can
   take unbounded time on it. Idempotent merges are already required; nothing
   checks them. A merge-law property test over the registered merge functions
   (idempotent / commutative / associative on sampled values) would be a
   general-purpose guard, and would have caught `tagged-cell-merge` in 2026-06-29
   from the lattice contract alone. This is the recommended direction.
2. **A per-fire budget** at the propagator layer (allocation or time), so a fire
   that overruns is a bounded diagnostic. Costs a check per fire, and "time" is
   scheduler-observable, which the orthogonality rule warns against.
3. **Nothing at the scheduler layer** — a wall-clock kill belongs to the harness,
   not the network, and would report the wrong thing anyway ("slow" rather than
   "this merge is not a lattice").

**Not blocked; not started.** (1) is a real, self-contained piece of work with a
clear payoff beyond this entry: it turns "every cell merge must be a lattice"
from a documented obligation into a checked one.

## 🔶 Propagator/Cell Allocation Efficiency Track — the top-3 ALL SHIPPED; one is validated-not-deployed (re-probed 2026-08-04)

**The audit's headline number is stale and two of its three optimizations are
in the tree.** Measured at HEAD:

| audit claim | measured |
|---|---|
| "`struct-copy prop-network` (13-field copy) is dominant cost" | `prop-network` is **3 fields** — `(struct prop-network (hot warm cold))` |
| "25 call sites" | ~53 `struct-copy prop-network` sites, but each copies 3 fields, not 13 |
| Top-3 (1) mutable worklist/fuel in the quiescence loop | ✅ shipped — BSP-LE Track 0 Phase 3c, `propagator.rkt:2699` "mutable worklist/fuel drain pattern" |
| Top-3 (2) field-group struct splitting (hot/warm/cold) | ✅ shipped — BSP-LE Track 0 Phase 3b; the struct IS the hot/warm/cold grouping this recommended |
| Top-3 (3) batch cell registration via transient CHAMP | ⚠ **built, tested, NOT DEPLOYED** |

**(3) — and the deployment attempt found there is nothing to deploy it to
(2026-08-04).** `net-new-cells-batch` exists (`propagator.rkt:1487`), is
exported, has six passing cases, and had zero production callers. Reading that
as the "Validated ≠ Deployed" shape, I went looking for the N-sequential-cell
sites to convert. There are none:

- The whole tree contains exactly **one** site allocating N cells in a loop —
  `narrow-function` (`narrowing.rkt`), and it has **no production callers**
  (only `test-narrowing-01.rkt`, every call at **arity 1**, where a "batch" is
  one cell).
- The two other loop-adjacent sites are not N-cell allocations at all:
  `relations.rkt:761` allocates ONE viability cell (the loop builds a set), and
  `build-var-env` (`:2019`) allocates **one compound `scope-cell` for all
  variables at once**.

That last one is the answer. The architecture moved past this optimization:
`propagator-design.md` § Cell Allocation Efficiency prescribes "separate cells
for separate concerns, **compound cells for cohesive scopes**", and the codebase
follows it — logic-variable scopes, decision state, commitment tracking are each
ONE compound cell, not N. Batch allocation answers "how do I make N allocations
cheap"; compound cells answer "why are there N allocations". **The audit
(2026-03-20) predates that discipline**, so its third optimization was
superseded rather than left undone.

Converted the one site anyway (`narrowing.rkt`), because its `for/fold`
threading a network through independent allocations is the red flag
`on-network.md` names — but it is **test-only at arity 1, so there is no perf
benefit to report, and this should not be read as "the batch API is now
deployed"**. It is not.

**Recommendation**: retire (3) as superseded, or re-scope it as "audit for
remaining N-cell groups that should become compound cells" — which is the
question the current architecture actually asks.

**Not re-verified**: the audit's *thesis* (that allocation efficiency has
disproportionate leverage). It may well still hold — but with the 13-field copy
gone, the baseline it was measured against no longer exists, so any new claim
needs a fresh measurement rather than a citation.

### (original) Design Track for Efficient Prop/Cell Allocation
- **Audit complete**: `docs/tracking/2026-03-20_CELL_PROPAGATOR_ALLOCATION_AUDIT.md` (commit `f7bd03d`)
- **Thesis**: Any even modest gains in allocation efficiency will have disproportionate effect across the entire infrastructure — every part of the system creates cells and propagators at scale
- **Key findings**: `struct-copy prop-network` (13-field copy) is dominant cost; 25 call sites; 6 optimization opportunities identified preserving pure data-in/data-out contract
- **Top 3 optimizations**: (1) mutable worklist/fuel in quiescence loop, (2) field-group struct splitting (hot/warm/cold), (3) batch cell registration via existing transient CHAMP builder
- **Incremental GC**: Future consideration — network IS the provenance trail; understand provenance patterns before committing to self-GC work
- **Next step**: Create design document from audit, scope implementation phases, benchmark before/after
- **Not blocked on anything** — can be implemented independently of PUnify or Track 8

---

## Numerics Tower

### 🔶 LARGELY DONE — Phase 4: Float32/Float64 (re-probed 2026-08-02; residuals mostly closed 2026-08-03)

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

**✅ MOSTLY CLOSED 2026-08-03.** Probed first — five `Unbound variable`s, so the
residual was accurate, not stale. `prologos::data::float` now provides `sqrt`,
`expt`, `exp`, `log`, `nan?`, `infinite?`, `floor`, `ceiling`, `truncate`,
`round`.

Shipped as `foreign racket` bindings, which is the Phase 4a/4b precedent
restated: the AST route costs NINE files per primitive (the `pipeline.md`
checklist) and buys nothing when Racket already implements each one exactly.

`nan?` + `infinite?` are BOTH there deliberately — that is what "NaN
specifically" needed. `float-finite?` (a parser keyword) answers "neither NaN
nor ±Inf", so code holding a non-finite value could not tell which it had.

⚠ **AND THE FFI's FLOAT MARSHALLING WAS DEAD CODE.** Both marshallers in
`foreign.rkt` have carried `Float32`/`Float64` cases since Numerics N3f —
`float64->flonum`, `flonum->float64` and siblings, with a comment calling the
FFI "the legitimate NaN/Inf round-trip point". **None of it was reachable**:
`base-type-name` had no Float arms, so a `Float64`-typed foreign argument fell
to the `Passthrough` catch-all and the raw `expr-float64` STRUCT went to the
Racket function. The symptom is `sqrt: contract violation … given:
(expr-float64 4.0)`, which reads like a bad declaration rather than a missing
arm — and it is a RAISE, so it takes the file down.

Note the shape: the `Passthrough` default is what made it silent-ish. A type
`base-type-name` does not know becomes "the Racket side handles IR values
directly" — true for `Path`/`Keyword`, false for everything else. Same
catch-all-does-the-wrong-thing pattern as `pipeline.md` § Exhaustive Walkers.
Two arms fixed it and made ~30 lines of existing marshalling live.

**The last two residual items, both closed the same day:**

- **`if-nan` — DONE**, in the float lib, and deliberately NOT a compiler
  primitive unlike its posit sibling. `p32-if-nar` has to be one because there
  is no other way to test nar-ness; `nan?` now gives the test, so this is an
  ordinary `match` — and a match arm is only evaluated when selected, which is
  the laziness the guard exists for. Polymorphic in the result type, so it
  covers the `conversions.prologos` usage shape (a value-case only meaningful
  when the input is not NaN).

- **Float↔Posit — WAS NEVER MISSING.** Listed as unverified; it works both
  directions via the trait route (`to-float` / `to-posit`). My first probe used
  a `[from Float64 Posit32 …]` spelling that does not exist and read the
  `Unbound variable` as a missing feature — the same mistake this file has
  recorded several times, in the same session. The interesting half checks out
  too: **both NaN and infinity map to `NaR`**, the posit tower's single
  non-value, so nothing silently becomes a number, and a finite value round-trips
  exactly. Pinned rather than deleted, since nothing was pinning it.

**Phase 4's residual list is now empty.**

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

### Sorted Collections (SortedMap, SortedSet) — ACCURATE, and the blocker is specifically PERSISTENCE (sharpened 2026-08-04)
- B+ tree or red-black tree backends
- **Blocked on**: backend infrastructure not yet built
- Probe: `sorted-map-empty` is `Unbound variable`; nothing sorted-keyed exists.

> **Why the shortcut that closed four sibling entries does NOT apply here.**
> Numerics Phase 4, String 4a/4b/4c/4d all turned out to be "blocked" only
> until someone tried a `foreign racket` bridge, because Racket already carried
> the implementation (Unicode tables, normalization, regex engine, float ops).
> The obvious next move is to try the same here, and it fails for a specific
> reason worth recording so nobody re-derives it:
>
> - Racket DOES ship ordered dictionaries — `data/skip-list` and
>   `data/splay-tree`, both verified working (a skip-list over `datum-order`
>   returns `((1 . "a") (2 . "b") (3 . "c"))` from out-of-order inserts).
> - Both are **MUTABLE** (`skip-list-set!`, `splay-tree-set!`). Prologos
>   collections are persistent, so a functional `sorted-assoc` over a mutable
>   backend has to COPY per operation — O(n) per insert, which is worse than the
>   sorted-assoc-list it would replace and defeats the point of the entry.
> - The distribution has no persistent ordered dictionary, and the tree's own
>   persistent structures (`champ.rkt`, `rrb.rkt`) are **unordered**.
>
> So the missing piece is precisely a **persistent** balanced ordered structure —
> a weight-balanced or red-black tree in the same class of hand-written work as
> CHAMP and RRB, not a bridge.
>
> ### ✅ THE BACKEND IS BUILT (2026-08-04) — `racket/prologos/ordered-map.rkt`
>
> A persistent weight-balanced tree (Adams / Nievergelt-Reingold, DELTA=3
> RATIO=2): `om-set` / `om-ref` / `om-remove` / `om-min` / `om-max` / `om-fold`
> / `om-to-list` / `om-keys` / `om-values` / `om-count` / `om-from-list`.
> Weight-balanced rather than red-black because the invariant IS a size ratio,
> so every node already carries the subtree count `om-count` and any future
> rank/select need.
>
> **The order relation is a PARAMETER, not baked in** — deliberately. How an
> `Ord` dictionary threads through at the Prologos level, and whether SortedMap
> joins the `Seq` protocol, are API decisions for the owner. This module is the
> backend only and does not pre-empt them.
>
> 16 tests (`tests/test-ordered-map.rkt`). The three load-bearing ones assert
> what a sorted assoc list would ALSO pass, which is what makes them the reason
> to have a tree at all:
> - **BALANCE** under ascending, descending, and delete-heavy input — a depth
>   bound, not eyeballed shape. Verified they FAIL with `balance` stubbed to a
>   plain rebuild — and the differential test keeps PASSING there, because a
>   degenerate tree is still *correct*. That is exactly why balance needs its
>   own assertion.
> - **PERSISTENCE** — an old handle unchanged by later writes, plus a 50-version
>   chain. The property that made bridging `data/skip-list` wrong.
> - **A differential oracle** against a sorted assoc list over 600 deterministic
>   mixed insert/remove ops, catching a rotation that loses or duplicates an
>   entry — which a shallow-but-corrupt tree would otherwise hide.
>
> **Still open**: the Prologos-level `SortedMap` / `SortedSet` surface, i.e. the
> owner API decisions above. The blocker this entry named is gone.
  Worth noting what DOES exist next door, since it is the nearest thing anyone
  will reach for: `sort` is bound (it fails on a bare `[sort '[3 1 2]]` with
  "Could not infer type", i.e. it wants an expected type or an Ord dict, not
  that it is missing). A sorted CONTAINER is the gap, not sorting.

### Parallel Collection Operations
- Parallel `map`/`filter`/`reduce` via Racket's places/futures
- **Blocked on**: runtime parallelism infrastructure

---

## Collections — Data Structures Roadmap

### 🔶 Phase 3: Specialized Structures — 3g is BUILT; 3a-3c genuinely not started (re-probed 2026-08-03)
- 3a: SortedMap + SortedSet (B+ Tree) — **not started**, confirmed: no B+/finger
  tree or pairing-heap code anywhere in the tree.
- 3b: Deque (Finger Tree) — not started, same probe.
- 3c: PriorityQueue (Pairing Heap) — not started, same probe.
- 3d-3f: **Subsumed by Logic Engine** — LVars, LVar-Map/Set, PropNetwork
- 3g: ✅ **Length-Indexed Vec — BUILT.** `expr-Vec` / `expr-Fin` are AST nodes
  with `vnil` / `vcons` / `vhead` / `vtail` / `vindex` / `fzero` / `fsuc` as
  parser keywords. Verified end to end:

  ```
  def v : <Vec Int 3N> := (vcons Int 2N 10 (vcons Int 1N 20 (vcons Int 0N 30 (vnil Int))))
  def h : Int := (vhead Int 2N v)              ⇒ 10
  def i : Int := (vindex Int 3N (fsuc 2N (fzero 1N)) v)   ⇒ 20
  ```

  `vindex`'s iota rules landed 2026-08-03 (see § Residuals from QTT P5 item 1);
  before that it type-checked and sat stuck. Covered at the reduction level
  (`test-reduction.rkt`), at Level 3 (`test-vec-index-ws.rkt`) and in the Redex
  model (`redex/tests/test-qtt.rkt`).

  ⚠ Two surface notes, both load-bearing for anyone using it: the annotation is
  REQUIRED (`def v : <Vec Int 3N> := …`), and these are parser keywords, so they
  take PARENS — `[vcons …]` fails with "Could not infer type" while
  `(vcons …)` works.
- Source: `docs/tracking/2026-02-19_CORE_DATA_STRUCTURES_ROADMAP.md`

### Phase 4: Integration + Advanced (NOT STARTED)
- 4a: QTT Proof Erasure (erase type-level proofs at runtime)
- 4b: CRDT Collections (conflict-free replicated data types)
- 4c: Actor/Place Integration (cross-actor persistent collections)
- 4d: ConcurrentMap (Ctrie — lock-free concurrent hash map)
- 4e: SymbolTable (ART — Adaptive Radix Tree for string keys)
- 4f: **Subsumed by Logic Engine Phase 4** — UnionFind (confirmed present:
  `union-find.rkt`, 28 definitions)
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
- 🔶 **`Gen` trait — LANDED 2026-08-03, and it surfaced the blocker.**
  `prologos::core::gen` defines `trait Gen {A}` with `gen : Int -> A` and
  instances for Int and Bool. SEEDED rather than random, deliberately: `gen` is
  a pure function of its seed, so a law failure is reproducible from the seed
  alone — no captured random state, and no test that fails once a week.

  ✅ **`[gen 5]` WORKS** — `def a : Int := [gen 5]` and
  `def b : Bool := [gen 4]` select different instances from the identical call
  shape, the expected type doing the choosing.

  ⚠ **It did not, for about an hour, and the hour is the interesting part.**
  `gen : Int -> A` puts the trait parameter in the RESULT position only, so
  `derivable-method?` refused to derive a bare wrapper — which is exactly
  **item 3 of § "Numerics N6d-i follow-ups"**, and connecting the two was the
  first finding (nothing had). The second finding was that **item 3's own
  diagnosis was wrong**: it blamed the resolution machinery as "UNPROVEN at
  HEAD", and a hand-written `spec mk {A} Int -> A where (Gen A)` resolves fine
  from an annotated `def`. The blocker was the derive rule, not the resolver.
  Relaxed there, and both entries move.

  A law checker can also use the dictionary method (`[Int--Gen--gen 5]`), which
  is what the tests exercised before the wrapper existed.

  **A second finding from building it**: there is NO `Int -> Nat` conversion
  anywhere in the tower. `from-nat` goes the other way, `conversions.prologos`
  has `impl ToInt Nat` and no inverse, and no `to-nat` exists. So a `Gen Nat`
  instance has nothing to build on short of counting `suc` from `zero`. Nat is
  the type trait laws mention most, so this is the first thing a law checker
  will want.

- Property checking for `:properties` and `:laws` — **no longer blocked.** The
  laws are stored fully structured (`(- :name "reflexive" (:forall
  ($brace-params x : A)) (:holds (eq? x x)))`) and `Gen` can now produce a
  value at a type the context chooses, which was the missing half. What remains
  is the checker itself: walk a trait's laws, generate for the `:forall` binders
  at the instance's type, evaluate `:holds`, and report. Plus an invocation
  surface — automatic at `impl` is the valuable version and the risky one (every
  prelude impl would check at load), so that is a real decision rather than a
  detail.

  ⚠ **A `Gen Nat` instance is the first thing it will want, and cannot be
  written**: there is no `Int -> Nat` conversion anywhere in the tower.
  `from-nat` goes the other way, `conversions.prologos` has `impl ToInt Nat`
  and no inverse, no `to-nat` exists. Nat is the type trait laws mention most.
- ✅ **DONE 2026-08-03 — contract wrapping: `:pre`/`:post` now RUN.**

  Lowered in `wrap-contract-checks` (macros.rkt), applied to the raw defn
  BEFORE `inject-spec-into-defn` adds types, so the parameter names are still
  bare and there is nothing to un-annotate:

  ```
  :pre    (boolrec _ BODY (panic "…") (PRE p1 … pn))
  :post   ((fn (r : _) (boolrec _ r (panic "…") (POST p1 … pn r))) BODY)
  ```

  `boolrec` rather than `match` because `if` already lowers to it and it is a
  plain 4-element datum — no arm construction, nothing that has to survive a
  later preparse pass. `:post` is a beta-redex rather than a `let` for the same
  reason: a `let` emitted here would still need `expand-let` to run over it,
  and this runs INSIDE preparse. The predicates are APPLIED, not interpreted —
  nothing in the lowering knows what a predicate looks like, which is what
  keeps the design doc's surface intact.

  The message names the spec and which contract (`sd: :pre violated`), since a
  bare panic leaves the reader to find both.

  **Stated non-goal, guarded rather than assumed**: a MULTI-FORM body (a `let`
  chain) is left UNWRAPPED. Folding a sequence into `boolrec`'s single `then`
  slot needs it re-associated, which is `expand-let`'s job. `contract-wrappable?`
  makes that explicit, and a test pins that such a definition still WORKS —
  declining to wrap must not break the function.

  Tests: `tests/test-spec-contracts.rkt`, 5 cases. The load-bearing ones are
  the `:post` that reads BOTH args and return (a lowering passing only the
  result could not tell those cases apart), the no-contract spec (this sits on
  the path of every spec'd defn in every program), and the multi-form non-goal.

  ⚠ **A test-fixture lesson from the same commit**: `test-float-lib.rkt`
  parameterized only `current-lib-paths` + `current-module-registry`. Direct
  foreign calls worked; `to-posit` needed trait dispatch and came back "No
  instance of ToPosit32 for Float64" while the identical file through
  `run-file.rkt` gave `NaR`. The divergence was the FIXTURE's. It also passed
  twice before failing, because a batch neighbour had already loaded the
  registries into the process — the passes-alone-fails-in-batch signature,
  running in reverse.

  **Original probe** (kept — it is the failing case the fix had to close):

  ```
  spec sd Int Int -> Int
    :pre [fn [x : Int] [fn [y : Int] [not [eq? y 0]]]]
  defn sd [x y] [int* x y]

  [sd 6 0]        ;; => 0 : Int      ← violates :pre, ZERO errors
  ```

  The surface is DONE and the semantics are absent: the metadata parses, the
  spec registers, and nothing anywhere consumes `:pre`/`:post` except the G1
  guard that rejects combining `:invariant` with them.

  **It is unblocked, which is the useful finding.** The design doc
  (`2026-02-22_EXTENDED_SPEC_DESIGN.org` §Phase 2) specifies the surface
  exactly — `:pre` is a function of the ARGS, `:post` a function of args plus
  the return — so there is no semantics call left to make. And
  `inject-spec-into-defn` (macros.rkt) already has both halves a wrapper needs
  in hand: `param-names` and `body-forms`. The rewrite shape is
  `match [pre-fn p1 p2 …] | true -> <body> | false -> panic`, with `:post`
  binding the result first.

  NOT started here deliberately: it is a FEATURE with a design doc, and the
  project's own methodology gives those a phased design and a PIR rather than
  one commit in a sweep. What was missing before today was the verified current
  state and the note that nothing blocks it; both are now on record.

  ⚠ And one probe correction worth keeping, since it is the third time this
  session: my first attempt used `:pre [> _ 0]` — the SCHEMA `:check` spelling.
  That is not what the design doc specifies for specs, and the `_` hole has no
  meaning for a multi-parameter function. A second probe failed on `int-div`
  being unbound and briefly looked like `:pre` breaking the spec; the control
  (same spec, no `:pre`) failed identically. Run the control.
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

### Statement-Like Forms in `.{...}` — ACCURATE (re-probed 2026-08-03)
- Keep `.{...}` purely expression-oriented for now
- Probe: a `let` inside `.{…}` fails at the `def` seam
  (*"def requires: (def name <type> body)"*) — the block never reaches mixfix
  parsing. Expression-only, as the entry says.

### `do` Notation Inside `.{...}`
- Prefer dedicated `do` blocks for monadic code

### `functor :compose` Auto-Registration of Mixfix Symbol — ACCURATE, and its PREREQUISITE is also unbuilt (re-probed 2026-08-03)
- Deferred due to coupling concerns
- Probe: `:compose` appears nowhere in the compiler — `process-functor` does not
  parse it, and the only mentions in the tree are two identical comments in
  `collection-traits.prologos` saying *"Phase 2+ will use :compose"*. So this is
  not "auto-registration is deferred while `:compose` works"; the key itself
  does not exist. Anyone taking this builds `:compose` first.

### Extended Pattern Matching in `.{...}` — ACCURATE, and it fails SILENTLY (re-probed 2026-08-03)
- E.g., `.{n + 1}` → `suc n` (Agda view patterns)
- Probe: `defn pr | .{n + 1} -> n | zero -> 99N` **defines with 0 errors**, and
  `[pr 5N]` then returns `??__match-fail : Nat` — the pattern never matches and
  nothing says so. `[pr 0N]` correctly gives `99N`, so the arm that IS supported
  works and only the view pattern is inert.
- That silence is the general non-exhaustive-match behaviour, not something
  specific to view patterns — filed as its own entry above.

### 🔶 Phase 4: Advanced Mixfix — UNICODE SYMBOLS WORK (re-probed 2026-08-03)
- ~~Unicode operator symbols~~ — **they work**, and the thing that made them
  look unsupported was a separate WS-surface bug, now fixed (below).
  `spec f Bool Bool -> Bool` / `:mixfix {:symbol ⊕ :group logical-and}` then
  `.( true ⊕ false )` evaluates. Pinned in `tests/test-mixfix-02.rkt`.
- Postfix operators — **probed 2026-08-03, accurate**: a `:mixfix` symbol used
  postfix (`.( 3N ! )`) fails with "Unexpected end of expression in `.{...}`".
  The Pratt parser has no postfix slot.
- Full mixfix patterns — still open, not probed.
- Source: `docs/tracking/2026-02-23_MIXFIX_SYNTAX_DESIGN.org`

⚠ **The reason this looked deferred: WS `:mixfix` metadata silently did
nothing.** `spec f … :mixfix {:symbol xxor :group logical-and}` stored the raw
`($brace-params :symbol xxor :group logical-and)` list where
`maybe-register-mixfix-operator` expects a hash — the sexp path parses it (the
`:mixfix` arm of `parse-spec-metadata`), the WS path did not. The consumer's
`(hash? mixfix-meta)` guard then made the mismatch a NO-OP: the spec defined
cleanly, no error, and the operator was never registered. `.( true xxor false )`
failed with *"Unexpected token after expression: xxor"* — pointing at the USE
site while the declaration was what silently failed.

`tests/test-mixfix-02.rkt` had unit coverage that passed throughout, because it
drives `process-spec` with the SEXP datum directly. Mixfix declaration is a
WS-only feature in practice, so the tested surface and the used surface were
disjoint. Now covered at Level 3.

⚠ **Known bound, newly pinned: spec metadata must be on a CONTINUATION LINE.**
Same-line `spec f … :doc "x"` or `… :mixfix {…}` fails, and reports *"Type
mismatch"* — a message that says nothing about metadata. True for `:doc` too, so
it is the inline metadata FORM that is unsupported rather than anything about
mixfix.

---

## Logic Engine / Propagator Architecture — Remaining

### Capabilities — Phase 8d: Multi-Agent Cross-Network Reasoning
- Separate agents on separate propagator networks cross-referencing via
  cross-network propagators, with dependent-typed proof objects as provenance
- **Blocked on**: session type design (Phase 9), dependent capabilities (Phase 7e-7g)
- Source: `docs/tracking/2026-03-01_1500_CAPABILITIES_AS_TYPES_DESIGN.md` §Phase 8d

### Galois Connections — Remaining Deferred — CONFIRMED (probed 2026-08-02, substrate re-exercised 2026-08-03)

`connect-domains` does not exist anywhere in the tree, so that half stands. The
substrate it would wrap does: `GaloisConnection` with `-alpha`/`-gamma`
accessors and an `Interval` domain are in `prologos::core::lattice`, with 14
passing tests in `test-galois-connection.rkt`.

Re-exercised end-to-end 2026-08-03, since "the substrate exists" is worth more
when someone has actually run it: `[Interval-Sign--GaloisConnection--alpha
[mk-interval 1 5]]` gives `sign-pos`, and `gamma` of that gives back an
interval. Both adjoints work through the dictionary. What `connect-domains`
should DO with them, though, is not specified anywhere the entry points at —
package the pair as a value? install a propagator bridging two domain cells? —
so it is an API design question, not just missing code.
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

### Higher-Order Narrowing in WS Mode — CONFIRMED STILL TRUE (re-probed 2026-08-02 and again 2026-08-03)

`narrow [apply-op ?f 3N 2N] = 5N` returns `nil` in a `.prologos` file — no
solutions, no error. Unchanged since 2026-03-08.
- Fix requires deeper integration between narrowing substitution env and DT body traversal
- Source: C3 analysis, 2026-03-08

⚠ **A CORRECTION to this entry's own claim (2026-08-03).** It said "the
infrastructure works at sexp/API level (23 tests pass); the WS pipeline does not
reach it". The 23 tests are the narrowing suite in GENERAL — grepping every
narrowing test file (`test-narrowing-01`, `-search-01`, `-search-02`,
`test-narrow-syntax-01/02`, `test-trait-narrowing-01`) finds **no higher-order
case at all, at any level**. So "works at sexp level" is not something the suite
establishes; it is an inference from adjacent coverage, and the gap may be
narrower or wider than stated. Anyone starting the fix should verify the sexp
claim FIRST rather than assuming half the problem is already solved.

**Now pinned** in `tests/test-narrowing-search-01.rkt`: the query raises no
error and returns the empty solution set. Locked deliberately as SILENCE,
because `nil` is indistinguishable from a genuine "no solution exists" — that
indistinguishability is what makes this worse than an error, and it is the
assertion that flips when the gap closes.

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

### Phase IV: Runtime Eval & Read — ACCURATE, and the blocker is a RULING (re-probed 2026-08-03)
- Runtime `eval`, `read`, `unquote-splicing` (`,@`), quasiquote `,x` in paren forms
- Source: `docs/tracking/2026-02-19_HOMOICONICITY_ROADMAP.md`
- Probe: `quote`, `eval-datum`, `read-datum` are all `Unbound variable`. The
  DATA half is done and working — `prologos::data::datum` defines `Datum` with
  constructors and predicates, and `[nat? [datum-nat 5N]]` gives `true`. What is
  missing is the evaluator, not the representation.
- ⚠ **And it is cheap in the wrong way, which is why it should NOT just be
  built.** Racket already implements the evaluator — a `foreign racket` bridge
  to the driver's own `process-string` is the Phase 4a/4b shape and would take
  minutes. But this is a CAPABILITIES language, and a plain-function `eval` is
  ambient authority to execute arbitrary code: the one primitive whose whole
  point is that it should be gated. Whether `eval` is a capability, and what
  that capability looks like, is an owner ruling on the capability model — not
  an implementation detail. Recorded so the next person sees the cheapness and
  the reason to resist it in the same place.

---

## Type System — HKT

### 🔶 HKT-9: Constraint Inference from Usage — BUILT and TESTED, flag OFF (re-probed 2026-08-03)

The entry says "algorithm designed, gated behind feature flag", which
understates it in one direction and overstates the gap in the other. Probed:

- **It is implemented**, not merely designed: `try-infer-constraint-from-method`
  in `elaborator.rkt`, wired into the bare-name resolution chain.
- **It is tested**: `tests/test-constraint-inference.rkt`, 11 cases, all
  passing, driven with the flag ON.
- `current-infer-constraints-mode?` defaults `#f`, so none of it is reachable
  in an ordinary program.

⚠ **So this is the "Validated Is Not Deployed" shape that `workflow.md` calls a
BLOCKING red flag** — "a track that ends with `use-X? = #f` has a gap, not a
safety net" — and it should be triaged as that rather than as unstarted design
work. Two honest paths: flip the default and re-validate, or record the reason
it must stay off. The rationale in the code is a DESIGN objection, not a
correctness one ("no mainstream language does this and it adds complexity"),
which makes it exactly the kind of call the flag is deferring rather than
answering.

- Source: `docs/tracking/2026-02-20_2100_HKT_GENERIFICATION.md`

---

## Mixed-Type Maps

*(Type Narrowing for `map-get` — RESOLVED by CIU T6 F1a structural records; moved to
DEFERRED_COMPLETE.md at the 2026-07-16 F1b-opening triage.)*

### Pattern Matching for Union Values — PROBED 2026-08-05; the entry undersold it

The filing said "convenience forms for matching on union values". There are no
forms at all, convenient or otherwise, and both failure paths were the bare
"Could not infer type" — a message that names inference for what is actually a
missing language feature, sending the reader to look for an annotation that would
not have helped.

Probed, 1 error each:

```
def x : <Int | String> := 42
match x | 0 -> "zero" | _ -> "other"    ⇒ Could not infer type
[the Int x]                             ⇒ Could not infer type
[the <Int | String> x]                  ⇒ WORKS
```

The third line is the shape of the gap: a union is perfectly usable as long as
you never look inside it.

**Done 2026-08-05 — the diagnostics, not the feature.** Both paths now name the
union, say what is missing, and give the two workarounds (keep it at the union
type, or use a `data` type with one constructor per case, which `match` does
narrow). Three tests in `test-error-messages.rkt`, including a control that
annotating with the whole union still succeeds — so the hint cannot outlive the
limitation it describes.

One implementation note worth keeping: **a `match` on a literal pattern does not
survive as an `expr-reduce`.** The pattern compiler emits a lambda applied to the
scrutinee with a HOLE parameter type —
`[[fn [x <_>] [boolrec … [int= x 0]]] umatch2::x]` — so a hint keyed on the node
kind fires on nothing. Mine did, until a probe printed the failing expression.
The hint now matches the compiled SHAPE (app-of-hole-typed-lambda) and keeps the
`expr-reduce` arm for scrutinees that do survive as one.

**Still open — the feature.** Case analysis on unions needs either a typed
down-cast (`the` returning an Option, or a checked narrowing form) or
flow-sensitive narrowing on a discriminating test. That is a design question, not
a gap: it interacts with QTT (does a narrowing consume the value?) and with the
union-typed row work. Source: `docs/tracking/2026-02-22_MIXED_TYPE_MAPS.md`

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

### 🐛 `prologos::core::csv` CANNOT BE IMPORTED — found 2026-08-03, PRE-EXISTING

Found while probing the `parse-csv-maps` entry below. **Every ordinary program
that imports this module fails at load**, under every spelling:

```
imports [prologos::core::csv :refer []]           → Error loading module
imports [prologos::core::csv :refer [parse-csv]]  → Error loading module

error[E1004]: no instance found for (ReadCap ReadCap)
  --> lib/prologos/core/csv.prologos:46:0
  E2001: Required capability ReadCap not available in scope.
```

`prologos::core::io` and `prologos::core::fio` import fine, so it is specific to
this module, not to capability-annotated modules generally.

**Not a regression — verified against a pre-session worktree at `7efc781d`,
where it fails identically.** (One difference: there it was a raw whole-file
abort with a Racket `context...:` dump; at HEAD it is a proper per-command
error, from the preparse containment fix above. Better presentation of the same
break.)

⚠ **AND TWO TEST FILES COVER THIS MODULE AND PASS.** `test-io-csv-02.rkt`
("CSV module E2E tests … through the compilation pipeline") and
`test-io-main-01.rkt` are green. They build a fixture that parameterizes
`current-impl-registry prelude-impl-registry` and friends; the production path
through `process-file` does not get the same, and that is where it breaks. So
the module is covered by E2E tests, and no user can import it. That is the same
fixture-fidelity gap that bit `test-float-lib` the same day, in the opposite
direction — there the fixture was wrong and the product fine; here the product
is broken and the fixture hides it.

**✅ DEFECT 1 FIXED 2026-08-03 — a capability in a spec was AUTO-GENERALIZED
into a type variable.** `known-type-name?` (macros.rkt) did not consult the
capability registry, so Phase 1b's auto-detect — which keeps any capitalized
symbol that function does not claim — turned every capability name in a spec
into a fresh `{X : Type}` binder:

```
spec rd ReadCap -0> String -> String
defn rd [_cap path] path
⇒ rd : [Pi [x :0 <[Type 0]>] [Pi [y :0 <x>] String -> String]]     ← BEFORE
⇒ rd : [Pi [x :0 <ReadCap>] String -> String]                       ← AFTER
```

`ReadCap` became a type VARIABLE, `_cap` got that variable's type, the binder
never registered as a capability, and the scope stayed empty. **The error then
pointed at the CALL SITE** ("E2001: … not available in scope") while the damage
was done in the SPEC — which is exactly why every hypothesis recorded below was
reasonable and wrong. Referring the name explicitly does not help: the
auto-detect asks `known-type-name?`, not the environment.

One arm, beside the existing schema/selection/trait/bundle arms. Pinned in
`tests/test-capability-spec-forms.rkt`.

⚠ **DEFECT 2 IS NOT FIXED, deliberately — csv is hit by BOTH and remains
unimportable.** The scope search compares functor names with `eq?`, while the
two sides are qualified differently: the requirement comes from a foreign
decl's `:requires (ReadCap)` (bare), and the binder's type under an explicit
`require` elaborates to `prologos::core::capabilities::ReadCap`. Comparing on
the bare segment is a one-line change (`spec-bare-name`, the helper already
used for issue #66) and it DOES make csv import and run cold. Written,
measured, held back for two reasons:

1. **It loosens a SECURITY check** — the scope search is what refuses IO in a
   capability-free context. One full-suite failure of `test-io-main-01`'s "IO
   without cap in scope should produce E2001" was observed with it applied
   (6/6 in isolation and 3/4 full suites afterwards, and `run-no-cap`
   hard-sets the scope to `'()` so the change is provably inert there) — but a
   security check that failed once should not ship on a probability argument.
2. **It surfaces a THIRD problem — verified REAL, not a fixture artifact.**
   With the capability resolved, `read-csv` elaborates to
   `[fn [x :0 <ReadCap>] [fn [y <String>] [parse-csv [read-file x y]]]]` — the
   erased capability threaded into `read-file` as a RUNTIME argument (the
   `:requires (Cap)` foreign wrapper adds capability token args), and QTT
   rejects it.

   ⚠ **This was nearly written off as a fixture artifact** because csv appeared
   to import and run cleanly through `run-file.rkt` with the scope fix applied.
   It did not: that run was served from a warm `.pnet`. **Clearing the entire
   `data/cache/pnet` directory reproduces the multiplicity violation on the
   production path, every time.** That is the THIRD time this module's cache has
   produced a false success in one session — see the withdrawn workaround above.
   For anything involving csv, clear the whole cache directory, not just the
   module's own file.

   What makes it puzzling rather than obvious: the foreign binder IS erased —
   `handle-foreign-decl` builds `Pi (c :0 ReadCap) …` — so passing an `m0`
   variable into an `m0` position should be legal QTT. Whatever rejects it is
   not the arity or the multiplicity annotation as written.

   ⚠ **AND IT IS NOT A QTT PROBLEM AT ALL — narrowed 2026-08-03. `.pnet` CACHE
   CONTENT IS CONTEXT-DEPENDENT.** csv's own source, run DIRECTLY as a file
   (`ns csvdirect :no-prelude`, byte-identical body), elaborates with **0
   errors**. The same source loaded via `imports` fails. So the content is fine
   and the module-LOAD path is what differs.

   Narrowed further, and this is the part that matters. Deterministic across
   trials, from a wiped `data/cache/pnet`:

   | scenario | result |
   |---|---|
   | cold → `imports csv` | **FAIL** (multiplicity violation) |
   | cold → run csv's source DIRECTLY → `imports csv` | **pass** |

   The failing import writes **39** `.pnet` files (it drags in the full prelude
   via the importer's `ns`); the direct run writes **13** (csv is
   `:no-prelude`). After the 13-file state exists, the import succeeds — and
   keeps succeeding. After the 39-file state, it fails and keeps failing.

   **So the same module can be cached in two different states, and which one
   you get depends on what loaded it first.** A `.pnet` is supposed to be a
   function of the module's source (plus the compiler and its lib sources —
   that is what `pnet-stale?` checks). It is evidently also a function of the
   loading CONTEXT, which nothing checks and nothing records.

   That single fact explains all three false successes this module produced in
   one session — the withdrawn load-ordering "workaround", the apparent
   cold-cache import, and the "fixture artifact" reading of this very
   violation. Each time the cache was answering, in a state some earlier run
   had put it in.

   **This is the thing to fix, and it is bigger than csv**: any module whose
   cached form depends on its first loader is a correctness hazard, not a
   performance one. Related to — but distinct from — the transitive-dependency
   staleness closed earlier in this file: that was *when* a hit is legitimate;
   this is *what* the hit contains.

Re-open with the multiplicity question answered.

⚠ **A LOAD-ORDERING WORKAROUND WAS FILED HERE AND IS WITHDRAWN — it was a STALE
CACHE.** The claim was that `imports capabilities` before `imports csv` makes it
work, which it appeared to do, repeatably. It does not: **delete
`data/cache/pnet/prologos/core/csv.pnet` and the same file fails identically.**
The earlier success was a `.pnet` written under some other condition being
served for a module that cannot actually elaborate.

So the honest statement is stronger than the one it replaces: **there is no
workaround. `prologos::core::csv` cannot be imported, by any spelling, in any
order.**

And the cache behaviour is worth its own note: a `.pnet` can serve a module that
does NOT elaborate. `pnet-stale?` gates on source mtime + infrastructure stamp +
version, none of which know the cached module was never valid — so once such a
file exists, the module appears to work until something invalidates it. That is
how a broken module can look fine for a whole session, and it is why the
"workaround" survived several probes before failing.

**What the evidence still supports**: the capability registrations made while
the PRELUDE loads `capabilities` do not reach csv's load. csv is `:no-prelude`,
requires `capabilities` itself, and that require is served from an
already-loaded module without re-establishing what the capability check needs.

⚠ **Reordering csv's OWN requires does not help** — tried, putting
`require capabilities` ahead of `require io` inside the module, and it still
fails to load. So the fix is not available inside the module: the registrations
have to be established in the IMPORTER's scope before csv loads, which is why
the workaround is a line at the import site. Anyone reaching for the obvious
in-module fix should know it was already tried.

⚠ **AND THE MECHANISM IS NOT WHAT THE ERROR SUGGESTS — instrumented 2026-08-03,
and this is the finding that saves the next person the most time.** The obvious
reading of E2001 ("not available in scope") is that the `_cap` binder failed to
enter `current-capability-scope`. Instrumenting says otherwise:

- `capability-type?` FINDS `ReadCap` — no registry miss for it at any point.
- `current-capability-scope` is `'()` at the failing `read-file` call, and NOT
  ONE of the 1763 lambda binders elaborated during csv's load registers as a
  capability. So the scope is empty for a reason upstream of the lookup.
- **Most importantly: the E2001 fires identically in the WORKING file.** The
  `imports capabilities` / `imports csv` version that succeeds end-to-end emits
  exactly the same `CAPSCOPE need=ReadCap scope='()` and the same E1004/E2001
  text during csv's load — and then completes with `r` defined and the value
  printed.

So the constraint is registered as unresolved in BOTH cases, and what differs
is whether something later DISCHARGES it. The failure is in deferred-constraint
resolution, not in binder scoping — which means chasing
`current-capability-scope` (the natural first move, and the one taken here) is
a dead end.

**The discharge condition, traced**: `check-unresolved-capability-constraints`
(`trait-resolution.rkt`) reports E2001 for every registered constraint
`#:when (not (meta-solved? meta-id))`. So a constraint is retired by its META
being solved, nothing else. Elaboration solves it only on the EXACT-functor
branch; the subtype branch deliberately leaves it unsolved ("type checker
accepts `(expr-meta)` optimistically") and does not register a constraint at
all; the `else` branch registers and leaves it unsolved.

That is where to start: in the working case something solves that meta between
registration and the sweep, and in the failing case nothing does. Both files
reach the same `else` branch with an empty scope, so the divergence is entirely
downstream of elaboration.

This is the same class as the cross-module schema channel closed earlier in this
file (#78 P2): a registry populated during a nested module load not reaching the
next one. Note the registry IS serialized into `.pnet` (slot 13) and IS
deserialized, and `load-module` captures and re-propagates it
(`mod-capability-reg`) — so the pieces exist and the gap is in when they apply.

Confirming evidence, each a single-variable change:
- imported `ReadCap` under `:no-prelude` → E2001 not in scope
- **locally-declared** capability under `:no-prelude` → works
- imported `ReadCap` WITH the prelude → works
- csv through a harness with a PRE-BUILT `prelude-module-registry` → works —
  ⚠ but that harness ran with a `.pnet` present, so per the withdrawal above it
  is NOT independent evidence. Re-run it cold before relying on it.

**The prelude-dependence framing below was the first cut and is superseded** by
the ordering finding above; kept because the probes are still the evidence:

```
ns capform                                   ;; full prelude
spec rd1 {cap :0 ReadCap} String -> String
defn rd1 [path] [read-file path]             ;; ✓ 0 errors

ns capnp :no-prelude                         ;; same body, same spec
require [prologos::core::io :refer [read-file]]
require [prologos::core::capabilities :refer-all]
defn rd2 [path] [read-file path]             ;; ✗ E2001 not in scope
```

`:refer-all` on `capabilities` does not help, so it is not a matter of naming
the right export. Something the PRELUDE establishes — and an explicit `require`
of the capabilities module does not — is what makes a `:requires`-annotated
foreign call satisfiable.

**Consequence beyond csv**: any `:no-prelude` library module that CALLS a
capability-annotated foreign function is exposed to this, and `:no-prelude` is
exactly what stdlib modules use to avoid circularity. `prologos::core::io`
escapes only because it *declares* `read-file` without ever calling it — csv is
the first module to actually call one.

⚠ **THE TWO CAPABILITY FORMS DO DIFFERENT JOBS, AND `csv` NEEDS BOTH — this is
the real finding, and it was learned by trying the fix and watching it fail.**
Rewriting csv's `spec read-csv ReadCap -0> String -> …` to the brace form the
E2001 diagnostic literally recommends (`{cap :0 ReadCap}`) does not fix the
import, AND it breaks `test-io-main-01.rkt` with a different error:

```
E2004: capability security violation — authority roots with
       undeclared transitive capabilities:
  `prologos::core::csv::read-csv` requires undeclared: {ReadCap}
```

So:
- the **positional `ReadCap -0>`** form is what DECLARES the requirement, which
  the transitive authority check (E2004) reads;
- the **brace `{cap :0 ReadCap}`** form is what puts the capability IN SCOPE,
  which the satisfaction check (E2001) reads.

Neither implies the other, and a module that both declares and uses a
capability appears to need both — or the machinery needs one to imply the
other. **That is a capability-subsystem design question, not a module bug**,
which is why the attempted fix was REVERTED rather than shipped: it traded a
load failure for a security-check failure and left the module no more
importable.

Two things were checked and are NOT the cause: both the capability and impl
registries ARE captured and re-propagated across module loads (`driver.rkt`
`mod-capability-reg` / `mod-impl-reg`).

⚠ Also worth keeping: the module's own tests already call `(read-csv "path")`
with ONE argument — i.e. against the brace signature, not the positional one
that is actually written. The declaration and its tests disagree, and the
fixture hides that too.

**The `parse-csv-maps` item below is moot until this is fixed**: there is no
point adding a function to a module nobody can import.

### CSV Maps — `parse-csv-maps`
- Header-aware CSV parsing returning `List [Map String String]`
- **Blocked on**: `map-from-pairs` function — ⚠ **and that blocker looks
  MISNAMED.** `map-from-seq : LSeq (MapEntry K V) -> Map K V` exists in both
  `prologos::core::map` and `prologos::book::maps`. Whether the gap is really a
  pairs-shaped variant, or just a list→LSeq hop away from what is already
  there, was not established — but "the function does not exist" is not what
  the tree says. Blocked behind the import failure above regardless.
- Source: IO-G plan

---

## Effectful Computation on Propagators — Remaining

### 🔶 Phase 2: Architecture A+D — Propagator-Native Effectful IO — **"NOT STARTED" IS STALE; it is substantially BUILT** (re-probed 2026-08-03)

The entry says NOT STARTED and lists "16 sub-phases across 6 phases (AD-A
through AD-F)". Grepping the tree for those very markers finds them spanning
**A through F, across 12 files**, with five dedicated modules:

| module | sub-phases |
|---|---|
| `effect-ordering.rkt` | AD-A0, AD-D, AD-D1, AD-D2, AD-D3, AD-F2 |
| `effect-position.rkt` | AD-A2 |
| `effect-bridge.rkt` | AD-B, AD-B1, AD-B2 |
| `session-runtime.rkt` | AD-C, AD-C1, AD-C2, AD-E, AD-F1 |
| `effect-executor.rkt` | AD-E, AD-E1, AD-E2, AD-E3, AD-F2, AD-F3 |

plus AD-B wiring in `parser.rkt` / `macros.rkt` / `elaborator.rkt` /
`typing-core.rkt` / `typing-propagators.rkt` / `typing-errors.rkt` and AD-F2 in
`driver.rkt`. That is ~15 of the 16 numbered sub-phases with code against them.

And it is **tested**: 9 files — `test-effect-bridge-01`, `-collection-01`,
`-executor-01`, `-ordering-01`, `-position-01`, `test-session-runtime-01`
through `-04` — **207 cases, all passing**.

**What this entry needs is a status audit, not implementation.** Someone should
walk the design doc's 16 sub-phases against the markers and record which are
genuinely complete, which are partial, and which are absent — the one thing a
grep cannot tell you is whether a marker means "done" or "started here". Until
then "NOT STARTED" is actively misleading: it is the single most wrong line in
this file, and it would send anyone picking up the track to rebuild what exists.

- Session types as causal clocks, effect ordering via Galois connection
- **Not blocked**: All phases buildable without concurrent runtime
- Source: `docs/tracking/2026-03-07_ARCHITECTURE_AD_IMPLEMENTATION_DESIGN.org`

### Phase 3: Full Reactive Effect Integration (RESEARCH)
- Architecture C — topological scheduling of effect propagators with freeze semantics
- **Blocked on**: Phase 2 completion — ⚠ and per the re-probe above, Phase 2 is
  much further along than this entry assumes, so the block may be softer than
  it reads. Confirm Phase 2's real status before treating this as gated.
- Source: `docs/tracking/2026-03-06_EFFECTFUL_PROPAGATORS_RESEARCH.md` §5c

---

## 🔶 Session Types — recursion is unusable in BOTH halves, and they are ONE gap (filed 2026-08-04; the process-side discard is now LOUD)

> **Probed further the same day, and the finding is bigger than the process
> half.** Recursive session TYPES are declarable but **unimplementable**:
>
> ```
> (session Loop (Mu X (Send Int (SVar X))))   ⇒ session Loop defined.
> (defproc sender : Loop (proc-send self 1 (proc-stop)))
>     ⇒ ERROR: Process sender does not implement session protocol
>              [mu [!Int . svar[0]]]
> (session Once (Send Int End))               ⇒ defined
> (defproc sender2 : Once (proc-send self 1 (proc-stop)))
>     ⇒ type-checked.          ← the identical send, non-recursive
> ```
>
> **Cause**: `typing-sessions.rkt` never calls `unfold-session` — **zero uses**.
> A channel sitting at `sess-mu B` therefore matches none of `type-proc`'s
> arms (`sess-send`, `sess-recv`, …), so every operation on a recursive session
> is refused. The unfolding machinery is NOT missing: `unfold-session` /
> `unfoldS` are implemented in `sessions.rkt:102`, and `effect-position.rkt:112`
> already uses them. Typing simply never adopted them.
>
> **But unfolding alone buys no working program, and that is the real finding.**
> Under `μX.!Int.X` the continuation after a send is `X`, which unfolds back to
> `Loop` — a protocol that never ends. Terminating it requires `proc-stop`,
> whose rule demands every channel be ended, so no non-recursive process can
> implement it. Adding an escape branch does not help: `μX. offer {done: End,
> put: Recv Int X}` still obliges the `put` branch to return to `X`.
>
> **So the type half and the process half are ONE gap.** S4 must land both:
> `unfold-session` wired into `type-proc`'s channel lookups, AND a process
> recursion form with the standard rule (the jump checks that the channel
> context has returned to the state it was in at the binder). Doing either
> alone produces no implementable recursive protocol — only a differently
> worded refusal.
>
> Not attempted here. The process half's rule is where soundness lives, and a
> subtly wrong one would ACCEPT programs that do not implement their protocol —
> strictly worse than today's refusal.
>
> **⚠ SCOPE CORRECTION 2026-08-05 — "recursion is unusable" overstates it, and I
> was the one overstating.** I summarised this entry in conversation as "a
> recursive session type is declarable and unimplementable". That is false.
> **Recursive session types are LIVE in the standard library and exercised**:
> `lib/prologos/core/io-protocols.prologos` declares `FileRead`, `FileWrite`,
> `FileAppend` and `FileRW` with `rec` and `-> rec` back-references, and
> `test-io-session-01` (11 cases) + `test-io-dep-session-02` (8, one asserting
> `sess-mu?` directly) pass.
>
> They work because the IO path unfolds: `session-runtime.rkt` (4 sites),
> `io-bridge.rkt`, `effect-position.rkt`. What does NOT unfold is **`type-proc`'s
> channel lookups** — the process typing judgement. So the gap is precisely
> *process* recursion plus `type-proc`'s adoption of `unfold-session`, and NOT
> the session-type layer, which ships and is used.
>
> The entry's own body already said this correctly ("Typing simply never adopted
> them"). The overstatement was mine, in summary, and it is the kind that makes a
> live, working feature look unbuilt — the same failure mode as the five "blocked"
> entries this session that named an obstacle already built.

## (the process half, filed earlier the same day) PROCESS recursion is unimplemented — the discard is now LOUD

**Never previously filed** — it lived as a `TODO` in `elaborator.rkt` and
nowhere else. Found by sweeping for defects recorded only in code comments.

`(proc-rec Label)` parsed correctly into `surf-proc-rec` with its label, and
then elaboration threw the label away and emitted `(proc-stop)`, under a comment
calling that "a sentinel that typing-sessions can handle".

**It is not a sentinel.** `proc-stop`'s typing arm (`typing-sessions.rkt:129`)
REQUIRES every channel to be ended, and actively SOLVES any remaining session
metas to `sess-end`. So a recursive process was typed as **terminating**, and
the recursion vanished at **zero errors** — the process type-checked against a
protocol it does not implement.

The asymmetry is the shape of the gap: session **TYPES** can recurse
(`sess-mu` / `sess-svar`, `sessions.rkt:39-40`); **processes** cannot. Building
the process half is S4 work and is NOT done here.

**Done here**: the discard is now a loud per-command refusal naming the label
and saying why `stop` is not an acceptable stand-in — so the next person does
not re-apply the same "harmless sentinel" reasoning. Suite green with it (550
files / 10658), i.e. nothing in the tree depended on the silent behaviour.

**Reach**: sexp-only. No WS spelling routes to `proc-rec` today, so this was
reachable only by writing the sexp IR form directly.

**Coverage note worth keeping**: the one existing test
(`test-process-parse-01.rkt`) asserts the PARSE — that the label survives into
`surf-proc-rec` — and stops exactly where the defect began. Two pins added in
`tests/test-proc-recursion-refusal.rkt`, including a control that a genuinely
terminating process still elaborates (a refusal that also fired on `proc-stop`
would otherwise pass).

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

### ⚠ TMS-Aware Infrastructure Cells + Structural State — **the FIX PATH is obsolete** (re-probed 2026-08-03)
- Infrastructure cells and elab-network structural fields are NOT TMS-managed
- `restore-meta-state!` cannot be retired until this is addressed
- ~~**Fix path**: (1) infra cells → TMS-aware via `net-new-tms-cell`, (2) meta-info/id-map → TMS cells~~
- ⚠ **`net-new-tms-cell` NO LONGER EXISTS as a production mechanism, and the
  migration went the OPPOSITE way.** PPN 4C 1A-iii-a Step 1 S1.a (2026-04-22)
  moved the type-meta cell factory *from* `net-new-tms-cell` *to* `net-new-cell`
  with the `tagged-cell-value` substrate — `elaborator-network.rkt` records it
  as "the last production consumer of `net-new-tms-cell`", after which "the
  entire TMS mechanism (struct, read/write/commit, factory,
  `current-speculation-stack` parameter) becomes dead and is retired in
  subsequent sub-phases S1.b-e".

  So the entry proposes migrating TO a mechanism that has since been deleted.
  **The goal may still be right; the route is not.** Whoever takes this should
  restate it against `tagged-cell-value` — which the same comment names as "the
  sole speculation mechanism for on-network state" — and note that the
  off-network residue it is really about (meta-info CHAMP + constraint store +
  id-map) is already routed to Phase 4 + PM Track 12.
- **Placement**: PPN Track 4 (Elaboration as Attribute Evaluation) — putting elaboration on the network with formal propagator edges requires TMS-aware cells. Relabeled from "Track 8 prerequisite" (2026-03-30): PPN Track 4 IS the elaboration-on-network track.
- Source: Track 6 Phase 5b findings (commit `cb393bb`)

### 🔶 Unify type inference and trait resolution under the propagator network — **the first bullet is STALE** (re-probed 2026-08-03)
- ~~Current elaboration uses propagator network for cells but NOT formal propagator edges~~ —
  `typing-propagators.rkt` carries `install-typing-network`, and its own Network
  Reality Check block answers the three questions affirmatively: *"1.
  net-add-propagator: YES — install-typing-network calls it per position. 2.
  net-cell-write produces result: YES — fire-fns write to type-map. 3. Cell
  trace: form cell (type-map ⊥) → propagator fires → cell write → cascade →
  quiescence → cell read (result)."* Formal propagator edges exist for typing.
- Constraint solving driven by imperative retry loops, not propagator scheduler
  — not re-probed; this half may well still hold, and it is the substantive part
  of the entry.
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

### ✅ RESOLVED 2026-08-03 — the DEP TABLE had rusted, and it was mis-selecting tests

Third guard checked in the same sweep, and the one with teeth:
`racket tools/update-deps.rkt --check` — the command `CLAUDE.md` lists under
"Validate deps" — exited **1** with **501 mismatches** across four dependency
tables. `tools/dep-graph.rkt` was last regenerated **2026-07-02**.

**This one was not cosmetic: the table drives affected-test SELECTION.** A stale
entry means `run-affected-tests.rkt` (the project's PRIMARY test command, per
`testing.md`) runs the wrong set — silently, and in the dangerous direction.
Measured on one module:

```
mentions of `prologos::core::csv` in the dep table
  before: 1        after: 3
```

The missing dependents included **`test-io-main-01.rkt`**, which imports
`prologos::core::csv` in its own preamble. So a change to `csv.prologos` would
NOT have run that test. (Not hypothetical for this session — csv turned out to
be the most defect-dense module in the tree.)

Regenerated with `--write`; `--check` now exits 0 and the full suite is green at
548 files / 10625 tests. 791 insertions, 294 deletions in the table.

⚠ **Same rust class as the two lints above** — three guards, all documented, all
with nothing running them, all drifted. The dep table is the one that was
actively degrading the test signal rather than merely accumulating debt. It has
no natural pre-commit seat (regeneration is not a per-commit act), so the
candidate seat is CI or the post-commit hook.

### 🐛 the CELL lint has rusted too — same class, and it blocks wiring (found 2026-08-03)

Checked immediately after wiring the parameter lint, on the theory that a
sibling guard nobody runs would have drifted the same way. It has.
`racket tools/lint-cells.rkt --strict` exits **1**:

```
Cell-creation site classification (110 production sites, 146 files scanned)
  registered   : 77
  unregistered : 16 sites, 10 unique merge fns
    baseline-accepted : 5
    NEW (not in baseline) : 11 sites, 6 unique
```

The eleven, none of them from this session:

| merge fn | sites |
|---|---|
| `type-unify-or-top` | `cap-type-bridge.rkt:197`, `elaborator-network.rkt:374/377/380`, `session-type-bridge.rkt:121/131` |
| `type-merge` / `mult-merge` / `level-merge` / `session-merge` | `meta-universe.rkt:187/189/191/193` |
| `attr-map-merge` | `data/probes/2026-05-24-…-empirical-probe.rkt:74` |

The baseline was last touched **2026-04-20** — three and a half months of
accumulation with nothing checking, which is exactly the parameter lint's story
one file over.

**⚠ CORRECTION to this entry's own first draft (same day).** It said "ten of the
eleven are load-bearing SRE surface … a DESIGN act per function". Looking
properly, the eleven reduce to **one** real unregistered merge function plus two
LINT-ACCURACY problems:

- **4 sites are LOCAL VARIABLES, not merge functions.** `meta-universe.rkt:187-193`
  reads `type-merge` / `mult-merge` / `level-merge` / `session-merge` from
  `(current-type-universe-merge)` and friends — local `define`s of a parameter
  read. The lint reports the local binding NAME. Registering "type-merge" would
  be meaningless; there is no such function. Baselining them would record noise.
- **1 site is a PROBE FILE** — `data/probes/2026-05-24-…-empirical-probe.rkt:74`
  — counted among "110 production sites". Probe files are not production; that
  is a scoping bug in the lint's file selection.
- **6 sites are one genuine function**: `type-unify-or-top`
  (`cap-type-bridge.rkt`, `elaborator-network.rkt` ×3, `session-type-bridge.rkt`
  ×2), which is what the four universe locals wrap via
  `compound-tagged-merge`. It is genuinely unregistered, and registering it IS a
  design act (domain + algebraic properties) — but it is ONE decision, not six.

**✅ BOTH ACCURACY PROBLEMS FIXED 2026-08-03.** `tools/lint-cells.rkt` now
excludes `/data/probes/` from its production scan, and recognises a name bound
by a local `(define NAME (current-…))` as a parameterized-passthrough rather
than an unregistrable merge function. The report went from

```
110 production sites … NEW (not in baseline): 11 sites, 6 unique
```
to
```
109 production sites … NEW (not in baseline):  6 sites, 1 unique
```

— exactly the reduction the analysis predicted, which is the check that the
diagnosis was right rather than merely plausible.

**One item remains, and it is a real design decision**: `type-unify-or-top` is
unregistered at 6 sites (`cap-type-bridge.rkt:197`,
`elaborator-network.rkt:374/377/380`, `session-type-bridge.rkt:121/131`).
Registering it via `register-merge-fn!/lattice` means declaring its domain and
algebraic properties — PPN 4C surface, and not something to decide from outside
the track.

**Then wire the gate** into the same third-gate seat in
`tools/git-hooks/pre-commit` that the parameter lint now occupies. The guard
cannot be wired while it exits 1, so that one registration is the whole
remaining blocker.

### 🐛 the parameter-lint guard is STILL UNWIRED, and has rusted again (2026-08-03)

The 2026-06-01 note below says the guard "rusted — it isn't wired into
pre-commit/CI, so nothing ran it". **It still is not**, and the predictable
thing happened: running `racket tools/lint-parameters.rkt --strict` today exits
**1** with 8 unbaselined exported parameters.

**Six of the eight were introduced by this session's own work** —
`current-duplicate-binding-warnings` / `-cell-id`,
`current-inexhaustive-match-warnings` / `-cell-id`, `current-own-import-specs`,
`current-suppress-duplicate-binding-warnings?`. I added parameters across
several commits without running the lint, because nothing runs it. That is the
same failure the note describes, one cycle later, and it is the argument for
wiring it rather than refreshing the baseline again.

Those six are now baselined (they are the same class as the existing
`current-coercion-warnings` / `-cell-id` entries, which sit in the baseline too).

The other two were then REVIEWED rather than blanket-baselined, since baselining
someone else's parameters unread is exactly the rot this guard exists to catch:

- `current-check-fire-invariants?` (propagator.rkt) — used only by
  `tests/test-scheduler-odiff.rkt`, which parameterizes it locally. A debug flag
  with one consumer; legitimately exported.
- `current-residuation-enabled?` (global-env.rkt) — read at five sites in
  `driver.rkt` and parameterized there; genuinely cross-module.

Both are accepted state, so both are now baselined and `--strict` exits **0**.

**✅ AND IT IS NOW WIRED — the actual fix.** `tools/git-hooks/pre-commit` gains
a third gate running `lint-parameters.rkt --strict`, beside the existing
paren-balance and stdout-clean gates. Whole-tree rather than staged-file-scoped
(a per-file view cannot tell "new" from "already accepted"), and gated on a
production `.rkt` being staged, so it costs one Racket startup only when it
could matter.

The hook comment records why, because the history is the argument: the
2026-06-01 response to this guard failing was to refresh its baseline, and the
guard promptly rusted again. **Updating the baseline stays a legitimate option —
but it should be a DECISION, and it was previously the automatic one.**

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
shows `:o _` while the value is right.)

**The residual is DIAGNOSED 2026-08-03**, and it is not the "static/runtime
row-type question" this line originally guessed. Measured by instrumenting
`observe-row-field-types` (typing-core.rkt), which is the display-time
refinement that fills a hole from what the rows actually contain:

```
solve (lit  ?o)   ;; = o 1          →  [PVec {:o Int}]     ✓
solve (strv ?o)   ;; = o "s"        →  [PVec {:o String}]  ✓
solve (optv ?o)   ;; = o [some 1]   →  [PVec {:o _}]       ✗
```

The observation IS reached for the constructor case and then discarded, because
`(infer ctx-empty …)` returns `expr-error` on the stored value. The stored value
is the reason:

```
val = (expr-app (expr-fvar 'some) (expr-int 1))
```

— a BARE `some` with **no implicit type argument**. A normally-elaborated
`[some 1]` is `(prologos::data::option::some Int 1)`. So the solver keeps the
raw clause-body term rather than an elaborated expr, and nothing downstream can
type it. That also explains the display: `[some 1]` here vs
`[prologos::data::option::some Int 1]` everywhere else.

**So the fix is in the relational engine** — elaborate constructor terms in
`defr` clause bodies — not in the display layer. A display-layer patch is
possible (resolve the bare head through the ctor registry and derive the type
from `ctor-meta`, the way `field-witness.rkt`'s `value->ctor-type-name` does)
and would only ever replace a hole, but it would be papering over an
unelaborated term rather than fixing it.

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

## LSP / Editor Support

### ✅ FIXED 2026-08-04 — token-level srcloc precision; the cause was SPEC INJECTION and the filed blocker was wrong

⚠ **This entry was corrected the same day it was first re-probed.** The first
pass concluded "only a WS layout-continued body loses precision" — wrong, and
wrong in the classic way: the probe varied *two* things at once (layout AND the
presence of a `spec`) and the finding was attributed to the visible one. The
controlled probe:

| form | reported | verdict |
|---|---|---|
| indented body, **no spec** | line 5, col 10, span 12 | ✅ exact token |
| indented body, **with spec** | line 9, col 0, span 35 | ❌ the whole `defn` |
| **single-line** body, **with spec** | line 14, col 0, span 35 | ❌ the whole `defn` |
| `def a :=` + indented body | col 10, span 18 | ✅ exact token |
| bracket-continued argument | col 14, span 23 | ✅ exact token |
| top-level, `fn`-in-`def`, sexp | — | ✅ exact token |

Layout is irrelevant. **A `defn` that carries a `spec` loses token precision;
one that does not, keeps it.**

**Cause** (`macros.rkt`, the preparse form loop): a defn with no spec survives
expansion unchanged and is returned as its ORIGINAL syntax object — all inner
srclocs intact. A defn WITH a spec goes through `maybe-inject-spec`, which
rebuilds it as plain data (`` `(defn ,name ,typed-bracket ,ret-angle ,@body-forms) ``),
and the result is re-wrapped with `(datum->syntax #f final-datum stx)` — where
`stx` is the WHOLE form. `datum->syntax` stamps that one location onto every
freshly-created sub-object, so every token in the body now reports the `defn`'s
line, column and span. The body-forms have already been stripped of their
syntax objects upstream, so there is nothing left to preserve at the rebuild.

**The filed blocker is wrong.** This is not waiting on "full propagator
integration (cell-per-node architecture)". `surf-var` carries its own srcloc
(`surface-syntax.rkt:440`), the elaborator destructures it
(`elaborator.rkt:1055`) and threads it into `unbound-variable-error` (`:824`) —
demonstrably exact in every shape that does not pass through spec injection.

**Fixed** by `splice-preserved-tail` (`macros.rkt`): before the rebuild,
re-attach the ORIGINAL syntax objects to any trailing elements the rewrite left
untouched. Spec injection only replaces the parameter bracket and inserts a
return type, so the body forms match by suffix and come back with their own
locations. Substitution is gated on `equal?` of the datums, so it can only add
location information — the datum that lands in the tree is the one that was
already going there. Follows the Rel T1 POL.9b precedent (`def x := (…)`).

After: `spec n Int -> Int` / `defn n [x]` / `  [int+ x undef_withspec]` reports
**5:10 span 14** — the token — where it reported 9:0 span 35, the whole defn.

⚠ **Scoped to `defn`, and that is load-bearing, not caution.** The first version
spliced every rebuilt form and broke **15 tests across 5 files**, all "X is a
relation, not a function". The `def` leg decides its RHS's command position by
comparing `(last final-datum)` against the RHS *datum*; handed a syntax object
it compares unequal, `value-stx` goes `#f`, the `'prologos-defrhs-command` stamp
never lands, and a paren GOAL silently reverts to an application. The def leg
already preserves its own RHS syntax and needs no help.

Three pins in `tests/test-error-messages.rkt` assert exact line/col/span for a
spec'd multi-line body, a spec'd single-line body, and — as the control that
distinguishes "coarsened everything" from "coarsened only the spec'd path" — a
spec-LESS body that was already precise. Verified the two spec'd pins fail with
the splice disabled and the control does not.

Suite 549 files / 10649 green; 15-example corpus A/B against HEAD shows only the
usual meta-id suffix difference.

- Source: LSP Tier 2, commit `712c45a`

### ✅ Cross-module go-to-definition — IMPLEMENTED 2026-08-04; the stated blocker was already gone

`get-definition-location` answered with the CURRENT document's uri in every
branch, which is why it only ever worked in-file. But the named blocker —
"cross-module location tracking in module registry" — had already been built:
`module-info` carries `definition-locations` (populated by
`register-definition-location!` during elaboration) and `file-path`. Nothing
consulted them.

Now a fallback, reached only after the in-file lookups miss, searches the loaded
modules and answers with the defining file. `foldr` from a document that does
not define it resolves to `lib/prologos/data/list.prologos`.

**Two traps, both of which make a wrong implementation look like an unimplemented
one — recorded because each cost a debugging cycle:**

1. **`lsp-state-module-registry` is dead.** Its setter is never called anywhere
   in `server.rkt`; the field is `#f` from `make-initial-state` onward. The
   registry actually lives in the per-document REPL session (and the prelude
   cache). Searching the obvious field finds nothing, silently.
2. **`module-info-definition-locations` is an ACCUMULATING ambient snapshot** —
   it holds every location recorded up to that module's load, not only that
   module's own definitions. Pairing a hit with the holding module's `file-path`
   therefore attributes definitions to whatever module happened to load next:
   measured, `foldr` resolved to `core/abstract-domains.prologos`, a file
   containing **zero** occurrences of the word. The fix takes the file from the
   SRCLOC, which knows its own source. (That snapshot behaviour is worth its own
   look — it means every module carries a copy of everything before it.)

Lookup is two-pass — exact short name before qualified suffix — and visits
modules in ns-symbol order, so an ambiguous name resolves the same way every
time instead of following hash iteration.

Three pins in `tests/test-lsp-goto-definition.rkt`, the suite's first coverage of
this handler: the cross-module hit (asserting the answer names a DIFFERENT and
correct file — "found something" would have passed on the in-file fallback), an
in-file definition still winning over a module one, and an undefined name still
resolving to nothing. Verified they fail with the new branch disabled.

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

## 🐛 A 2-arg multi-arity `defn` over NULLARY constructors returns a WRONG ANSWER, silently (found 2026-08-05)

Compiles, type-checks, 0 errors, wrong result. It discriminates on the FIRST
argument only, so every call whose first argument matches an arm returns that
arm's body regardless of the second.

**Minimal repro — 15 lines, no OCapN** (`examples/2026-08-05-multiarity-nullary-repro.prologos`):

```
data K
  ka
  kb
  kc

spec keq K K -> Bool
defn keq
  | ka ka -> true
  | kb kb -> true
  | kc kc -> true
  | _ _ -> false
```

`[keq ka ka]` → `true` ✓ · `[keq ka kb]` → **`true`** ✗ · `[keq kb ka]` → **`true`** ✗

Both wrong answers are explained by first-argument-only matching: `ka kb` hits
the `ka ka` arm, `kb ka` hits `kb kb`. The `| _ _ -> false` catch-all is
unreachable.

**How it was found**: making the `RefrKind` change below, `refr-kind-eq?` was
written in exactly this shape and `test-ocapn-bridge`'s case *"refr-eq? different
kinds => false even with same id"* failed. Without that test the refactor would
have landed green — 165 of 166 bridge cases passed, the conformance gate would
have been unaffected (it never compares two different kinds at the same id), and
brand-check would have been quietly broken. **The one assertion that caught it is
the only one in the tree that distinguishes the two.**

**This is pitfall #18's shape** (*"multi-arity `defn` with leading 0-arity ctors
only matches the first arg"*), which has been on file since Phase 0 — but the
pitfall log frames it as a matching quirk. The severity is the story: it is a
SILENT WRONG ANSWER in a function whose whole job is discrimination.

**Two forms that DO work** (both probed):

```
;; A — outer match, one-level inner match per arm.  PREFERRED: no numerals.
defn keq2 [x y]
  match x
    | ka -> match y | ka -> true | _ -> false
    | kb -> match y | kb -> true | _ -> false

;; B — ordinal, then nat-eq?.  Works, but reintroduces the numeral.
```

Form A is what `captp-core` now uses. Note it is TWO-deep, which is fine;
three-deep nested `match` fails at import time (already in
`prologos-syntax.md`).

### ✅ FIXED 2026-08-05 — `param-names` asked "all variables?" BEFORE normalizing

**One line, in `expand-defn-pattern-group` (`macros.rkt`).** `param-names`
computed `all-var?` with `pattern-is-variable?` over the **raw** clause patterns.
A bare nullary constructor is still a `pat-atom` of kind `'var` at that moment —
`normalize-pattern` has not yet consulted `lookup-ctor` — so every bare
constructor counted as a variable, `all-var?` came out `#t`, and the generated
parameters were named after the **patterns**. `| ka ka -> …` produced TWO
parameters BOTH NAMED `ka`. `compile-match-tree` then took
`(list-ref param-names col)` per dispatch column, got the same name twice, and
**the second dispatch re-read the first argument**.

Fix: normalize once, up front; decide `all-var?` on the normalized patterns and
reuse them for the rows. Regression test `tests/test-multiarity-nullary-dispatch.rkt`
(5 cases; **3 fail** with the fix reverted — exactly the three bare-pattern ones,
while the bracketed and all-variable cases pass either way, which is correct
because neither was ever broken).

Gates: full suite 560/10955/0, conformance 24/24, `test-ocapn-bridge` 166/166.

### ⚠ CORRECTION — the root cause published earlier THAT DAY was wrong, twice over

This entry previously said the cause was **the parser failing to split
`| ka ka ->` into two patterns**, and recommended either registry-aware splitting
or *requiring brackets and erroring otherwise*. Both were wrong, and the second
would have been actively harmful — a syntax restriction imposed on users to work
around a one-line ordering bug in the compiler.

Two mistakes produced it, and they are the reusable part:

1. **A mechanism inferred from a behavioural difference instead of looked at.**
   Instrumenting `expand-defn-multi` showed the parse was correct all along: two
   patterns per clause, normalizing to two nullary compounds. The rows entering
   `compile-match-tree` were right. Nothing about the parser was involved.
2. **A confounded experiment.** The "brackets fix it" probe used a **2**-constructor
   type while the bare probe used **3** — two variables changed at once. The clean
   2×2 (bracketing × constructor count, one file) is what settled it. That the
   confounded run happened to reach the *right* discriminator is the danger:
   **a confounded experiment that lands on the correct answer is worse than one
   that lands on the wrong answer**, because nothing prompts you to re-run it.

This is the same error as the srcloc misattribution earlier in the same session
("I varied layout AND spec presence, blamed layout") — repeated within the hour,
after being written down. The instrument that broke both was the same: change one
thing, in one file, and read the output rather than the theory.

### Narrowing that got there### Narrowing that got there (kept — the reasoning, including the wrong turns)

Attempted the fix; did not land it. Recording the narrowing because it is most of
the work and the next person should not redo it.

**Established by probe:**

1. **Nullary only.** The same shape with FIELD-CARRYING constructors is
   **correct**. Probed side by side in one file:
   ```
   data W  wa : Nat   wb : Nat
   defn fb | [wa _] [wa _] -> 1N | [wa _] [wb _] -> 2N | _ _ -> 9N
   ```
   → `1N`, `2N`. Both right. The nullary twin is wrong. So this is not general
   multi-column dispatch — bracketed compound patterns take a different route
   (they are already `pat-compound` syntactically and need no lookup).
2. **Two DIFFERENT wrong behaviours**, which is why "matches first arg only" is
   an incomplete description:
   - `defn keq | ka ka -> true | kb kb -> true | _ _ -> false` → `[keq ka kb]`
     is **`true`** (matched the wrong arm).
   - `defn fa | ka ka -> 1N | ka kb -> 2N | _ _ -> 9N` → `[fa ka kb]` is
     **`9N`** (fell to the catch-all instead of matching arm 2).
   One story has to explain both.
3. **NOT the unknown-constructor path.** `macros.rkt:11551` already documents
   that an unknown bare name stays a VARIABLE and becomes an irrefutable
   catch-all — and `unreachable-arm-error` guards it. That is not what is
   happening here: `normalize-pattern` (`:11196`) does convert a known nullary
   name to `pat-compound`, `unreachable-arm-error` does not fire, and behaviour
   (2) rules out first-arm-eats-everything.

**Where I stopped — and this reading was RIGHT, which is why it mattered.**
`compile-match-tree` (`:11436`) and `specialize-rows` (`:11279`) look correct on
paper — for a
nullary ctor `n-fields = 0`, so `new-pats` drops the column, `new-params` drops
the parameter, and the recursive call should dispatch on what was column 1. Hand-
tracing `fa`'s `ka`/`kb` case predicts the RIGHT answer (`2N`), which the
implementation does not produce. **So the divergence is somewhere between that
reading and the actual behaviour, and I did not find it.** The next step is to
instrument `compile-match-tree` and print the row sets at each level for the
15-line repro — cheap, and it settles it.

**Not fixed** — this is elaborator work with a live wrong-answer bug at the end
of it, not a workaround question. The immediate protection is the repro, the
severity banner on pitfall #18, and the two documented working forms.

**A guided error is the fallback if the fix proves deep**: refuse a multi-arity
`defn` with nullary-constructor patterns in a non-first column, since the
compiler demonstrably cannot honour them. Loud-and-restrictive beats a silent
wrong answer.

## ✅ DONE 2026-08-05 — the Peano kind tags are gone from `captp-core`

The Nat-audit entry below recommended this and I twice declined it — first as
"the entry asked for an audit, not a rewrite", then because its gate's suite
clone was absent. The second reason stopped being true when I verified the gate
runs here (~30s), so the refactor happened.

Six `Nat` numerals (`refr-kind-remote-import-promise := [suc [suc [suc [suc [suc
zero]]]]]`) became a 6-way nullary `data RefrKind`; the predicates match the
constructor directly instead of `nat-eq?`-ing a numeral; `refr-kind` now returns
a kind rather than a number you had to count. The workaround's stated cause
(issue #60) was verified not to reproduce at HEAD before touching anything.

**Gates, all green**: conformance **24/24**, `test-ocapn-bridge` 166/166,
`test-ocapn-captp` 7, `test-ocapn-pipelining` 4, `test-ocapn-e2e` 8, full suite.

**It found a live language defect on the way** — see the entry directly above.
Worth noting what that says about the two earlier refusals: holding the refactor
was defensible both times, but it also kept a silent brand-check bug latent in
the language one refactor away from being tripped. The audit could not have found
it; only writing the code did.

## Coding Standards

### 🔶 Nat-in-Computations — AUDITED 2026-08-04 (the audit IS what this entry asked for; the refactor is a separate call)

**Measured**: 387 `spec` lines mention `Nat` across the stdlib. The distribution
is the finding — it is not evenly spread, and most of it is one subsystem:

| module | Nat specs | verdict |
|---|---|---|
| `ocapn/captp-core` | 156 | ids/counters — computation, should be `Int` |
| `ocapn/interop-driver` | 39 | same |
| `ocapn/vat` · `captp-wire` · `behavior` · … | ~60 | same |
| `data/nat` · `book/natural-numbers` | 32 | **correct** — the inductive module and its chapter |
| `data/list` · `book/lists` | 30 | indices/length — arguably computation |

So ~250 of 387 are the OCapN stack using `Nat` for session ids, promise ids,
positions, and refcounts. `PosInt` exists (Numerics N5de nominal-erased refined
types), so the target spelling is available.

**The sharp finding, which is not what the entry expected.** `captp-core` uses
`Nat` as an **enum tag in Peano encoding**:

```
;; Kind tags. Encoded as Nat for issue #60 avoidance (no enum sum).
def refr-kind-local-export          : Nat := zero
def refr-kind-remote-import-promise : Nat := [suc [suc [suc [suc [suc zero]]]]]
```

Six kinds, spelled as unary numerals, miscountable by eye, 18 use sites. That is
neither computation nor induction — it is a sum type wearing a numeral, and the
comment says why: a documented workaround for
[issue #60](https://github.com/LogosLang/prologos/issues/60) (multi-constructor
data types unusable cross-module).

**Issue #60's shape no longer reproduces.** Probed at HEAD with its exact
description — a 2-constructor type whose constructors carry fields, defined in
one module, constructed / called / matched from another:

```
data BridgeStep
  bridge-step     : Nat -> String
  bridge-step-out : Nat -> String -> [List String]
```

Cross-module construction, a cross-module call of the defining module's `match`
function, and a local `match` over the imported type all run clean at 0 errors,
under `:refer` and under one-hop `:refer-all`. The nullary 3-constructor form
works too. So the Peano enum is removable — and it is module-LOCAL (all 18 uses
are inside `captp-core`), which is the easy case.

**Why it is still not done, 2026-08-05** — the honest reason, not "no time".
The entry names `tools/interop/`'s 24/24 conformance run as the gate for this
refactor, and that gate's Python suite clone is **absent from a fresh
container**. It is fetchable (verified: the clone succeeds here), but a ~20-line
change to interop-critical code should land WITH its gate green in the same
session, not on the argument that it is small. The enum swap is the easy case
precisely because it is module-local — that makes it a good first slice for
whoever runs the gate, not a good drive-by.

**Recommendation, NOT done here**: replace the Peano kind tags with a 6-way
nullary `data RefrKind`, and separately move the OCapN id/counter `Nat`s to
`Int`. Both are refactors of working, interop-gated code — `tools/interop/`'s
24/24 conformance run is the gate, and this entry asked for an audit, not a
rewrite. Sizing it: the enum swap is ~20 lines in one module; the `Nat`→`Int`
sweep is ~250 signatures across the OCapN stack and wants its own track.

**Spun out — a sharper diagnosis of pitfall #33** (`refer-all` chains and type
identity), isolated while probing #60. The pitfall log frames it as a
`:refer-all`-chain problem. It is not:

- direct `:refer` — works, type resolves to the FQN
- one-hop `:refer-all` — works, FQN
- a chain through ANY middle module — fails, **including when the middle module
  uses explicit `:refer`**

So the mechanism is not `refer-all` at all: **a module does not re-export what it
imports**, and `resolve-in-refer-all` (namespace.rkt:636) only consults each
refer-all'd module's OWN exports before falling through to "return the symbol
as-is". The bare symbol then survives as an opaque type name distinct from the
FQN — hence the pitfall's "Type mismatch: `T` vs `M1::T`, same type, different
name".

And the reason it is silent rather than loud is worth recording: `known-type-name?`
is **namespace-blind**. Probed side by side — `spec f TotallyMadeUpName -> String`
auto-generalizes into `[Pi [x :0 <[Type 0]>] x -> String]` (a type variable,
correctly), while `spec f BridgeStep -> String` does NOT, because `BridgeStep`
IS a known type globally. Resolution then yields the bare symbol. The same
namespace-blindness that caused the capability-in-spec defect fixed earlier this
session, in the opposite direction: there a real type became a variable, here a
real type becomes an opaque name.

A guided error is available and bounded — a spec type name that survives
resolution as a BARE symbol while being a known type in some loaded module could
say "`BridgeStep` is defined in `prologos::i60::step`, which this module does not
import". Same-file forward references are safe from it (probed: they resolve to
the file's own FQN). Not attempted: it touches spec-wide type-name resolution and
wants a call on whether that case should error or resolve.

- `Nat` only for inductive/proof contexts (the rule, unchanged; also in CLAUDE.md)
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

**Restoration path infrastructure (per §9.5.5.1 T2 audit)**: `solver-state-explain-hypothesis`, `solver-state-assumptions`, `solver-state-minimal-diagnoses`, `nogood-explanation` struct, `assumption` struct, `greedy-hitting-set` algorithm all present + battle-tested.

> ⚠ **Qualification added 2026-08-04 — "battle-tested" is true of the PLUMBING, not of the RESULT.** Read before restoring anything on this basis:
>
> - `solver-state-minimal-diagnoses` (plural) returns **at most ONE** diagnosis — `(list diagnosis)` on a single greedy run, `'()` otherwise. It never enumerates alternatives.
> - That diagnosis is not necessarily **minimum**. `greedy-hitting-set` (`atms.rkt:158`) is the max-degree greedy heuristic: repeatedly take the assumption appearing in the most remaining nogoods. Standard, and standardly approximate — so a restored `[diagnosis] retract: …` can advise retracting MORE than necessary.
> - Ties are broken by **hash iteration order** (`for/fold` over `in-hash` with strict `>`, so first-encountered max wins). Deterministic within a build, arbitrary as advice: on a tie, which assumption gets blamed carries no meaning.
>
> `atms.rkt:701` carries the one-line form of this as a `TODO` ("Replace with tropical semiring CSP when available") and it had **never been filed**. Tropical *fuel* infrastructure exists (`tropical-fuel.rkt`, `tropical-fuel-primitives.rkt`); a tropical-semiring CSP solver does not, so the TODO is honest future work rather than a stale claim. Exact minimum-hitting-set enumeration is independently tractable at these nogood counts if Phase 11b wants the guarantee without the CSP. `build-derivation-chain` + `format-context-diagnosis` + `format-atms-conflict` (typing-errors.rkt:173-280) STILL IN PRODUCTION for the NON-union path (type-mismatch-error). Restoration would be MECHANICAL GLUE (~50-100 LoC) re-calling existing helpers in union path — NOT new infrastructure.

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

> ⚠ **Coordinates re-verified 2026-08-04 — both citations below had drifted.**
> `preparse-expand-all` is at **macros.rkt:3078** (not 2366-2460; that range is
> now the let-syntax containment handler, unrelated), and its passes have grown
> a member: Pass 0 (:3103), Pass 1 (:3153), **Pass 1.5** — def-bot
> pre-allocation, PPN 4C Addendum Phase 4B.2-b (:3178) — and Pass 2. The
> module-level cycle check is at **driver.rkt:3203**, not 1872-1874.
> `tools/form-deps.rkt` still exists. The entry's substance is unaffected; the
> line numbers would have sent the next reader to the wrong function, and the
> pass inventory is what the migration has to reproduce.

The `preparse-expand-all` 3-pass mechanism (now 4 passes) + `tools/form-deps.rkt` SCC analysis delivers **name-level residuation at preparse time** (pre-registration of declaration names: ns/imports → no-dep declarations → spec+impl → main loop). Per Audit C (PPN 4C addendum §18.10.4): this is imperative scaffolding that delivers name-level residuation; Phase 4 introduces value-level residuation at elaboration time; the two layers compose.

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
- Implementation: `macros.rkt:3078` (`preparse-expand-all`), `tools/form-deps.rkt` (SCC analysis) — coordinates re-verified 2026-08-04
- Module-level cycle detection (related, same retirement target): `driver.rkt:3203` ("Circular dependency detected")
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

## 🔶 PARTIAL `9a5ef0c6` — generated `.md` twins are STALE (captured 2026-07-25; hazard closed 2026-08-02, regeneration + keep/delete still open)

**Broader than the entry had it: ELEVEN stale exports, not two**, and some by
five months — `DEVELOPMENT_LESSONS.md` last regenerated 2026-02-25 against an
`.org` edited 2026-07-28, `MASTER_ROADMAP.md` 2026-03-24 against a source
edited today. `tools/check-doc-twins.sh` reports them (11 of 70 `.org` files
have an export; staleness judged by LAST COMMIT TIME, not mtime — a fresh clone
gives every file the same mtime, so mtime reports nothing on CI and everything
locally).

**The stated harm is closed.** Each stale export opens with a banner naming its
`.org` and the fact that its claims may already have been retracted at the
source. Someone who greps the principles directory and lands on the `.md` is
told, at the top of the file, that they are reading a stale generated artifact.

⚠ **The banners USED TO CARRY THE TWO DATES, and that was a bug in the fix —
demonstrated within hours (2026-08-03).** A hardcoded "last regenerated X; source
changed as recently as Y" goes stale the moment the source moves again. It did:
this session edited `grammar.org` for the POL syntax cluster, and
`grammar.md`'s banner still claimed the source had last changed 2026-07-02. A
staleness warning that is itself stale is worse than none — it invites the
reader to trust a number.

All 11 banners are now DATE-FREE and point at `tools/check-doc-twins.sh`, which
computes the answer live from both files' last commit times and therefore cannot
rot. The count the entry quotes has also moved: **1 of 70 exports is behind
today, not 11** — and that one is `grammar.md`, stale because of this session's
own `.org` edit.

**Still open, and deliberately not decided here:**

1. **Regeneration.** Needs org-export; neither emacs nor pandoc is present in
   this environment, so it cannot be done from here.
2. **Whether the exports should be in-tree at all.** The entry's own question,
   and it is the owner's — deleting twelve committed documents is not a call to
   make as a side effect of a staleness sweep. If they go, the checker and the
   banners go with them.

The checker exits 0 by design: it REPORTS. Gating on it would gate work on a
tool the environment may not have.

## ✅ RESOLVED (2026-07-25, `bb45d2a0`) — the acceptance file is now gated; POL L3 rides it. PARTIAL: POL internals still lack unit tests

> **Closed**: gaps (1) and (2). `tests/test-rel-t1-acceptance.rkt` (32 cases) runs
> the file through `process-file`, asserts 0 errors, verifies every marker, and
> RANGE-CHECKS marker indices. All markers rewritten against actual output —
> **30/30 pass, was 5/28**. Running `--check` also exposed that the POL.8/POL.9
> markers were MISNUMBERED (off by one and two), which the range check now
> catches.
>
> **Gap (3) CLOSED 2026-08-05**: `test-rel-t1-pol.rkt` now has a Level-3
> section — 12 cases through `process-file` covering POL.7 (`||` blocks, `|`
> explicit rows, the arity-mismatch error), POL.8 (bare-head-is-one-goal,
> sibling-at-goal-column, deeper-continuation-is-an-argument) and POL.9
> (implicit solve at top level and on a `def` RHS, `foo x` / `[foo x]` staying
> application, and the three guiding diagnostics). 121 tests, green; the file
> was 106.
>
> Two of them are worth more than the rest. The POL.8 pair asserts that the
> flat spelling and the deeper-continuation spelling produce the **same
> answer** — which is the layout rule itself, stated as an equality rather than
> as a snapshot. Perturbation-checked: moving that continuation line from
> "deeper" to the goal column turns it into a sibling goal and the equality
> fails, as it must.
>
> **Still open**: the POL parser internals (`regroup-flat-lines-by-layout`,
> `parse-clause-content`, `paren-goal-stx?`, `check-crosskind-collision`) have
> ZERO unit tests. The L3 cases exercise them end-to-end, so a break is now
> caught — but it is caught as a wrong answer, not as a named function's
> contract.

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

### 9. ✅ RESOLVED 2026-08-03 — all FOUR shapes of the ordinal miss-hint now land

The two the adjudicator cared about are done:

- **`cfg.0` — an ordinal on a KEYWORD row.** *"`.0` is ORDINAL access, but
  `{:a Int :b Int}` is a keyword row: its fields are NAMED. Write `.field`
  (available: :a :b)."*
- **`het.name` — a keyword on a NAT row.** *"`:name` names a field, but
  `⟨Int String⟩` is a tuple: its slots are POSITIONAL. Write `.N` (valid
  indices 0–1)."*

Both were bare *"Could not infer type"*.

**The filing's warning was the operative instruction** — *"the branch order in
`closed-row-miss-hint` is exactly where P2's own regression came from; adding
arms there without an A/B against a pinned baseline is how a correct
diagnostic gets suppressed. Whoever takes this should A/B each new arm the way
the P2 adjudicator did."* Done: a seven-shape battery captured before and
after, and the diff is EXACTLY the two target lines — the four
previously-good messages are byte-identical, and both valid projections still
project. Those four are now pinned as the A/B test, not just run once.

Each new arm is guarded on the OPPOSITE key domain to the branch beside it, so
no input can match two of them; that is what makes the placement safe rather
than lucky.

**The remaining two shapes landed the same day**, A/B'd the same way (a
fifteen-shape battery this time, so the six already-good messages act as
controls; the diff is exactly the target lines).

- **`.N` / `.field` on a NON-projectable carrier** — `n.0` where `n : Int`,
  `s.0` where `s : String`, `n.name`, `g.0` on a function. All four
  Record-guarded branches decline on these, so the whole chain fell through to
  a bare *"Could not infer type"* naming neither the carrier nor its type. Now:
  *"`.0` is positional access, but `n` has type Int, which has no positions.
  `.N` needs a tuple ⟨…⟩ or a PVec."*

  **The POSITIVE list is the load-bearing part**, and it is `definitely-not-map?`'s
  lesson (`pipeline.md` § Exhaustive Walkers) applied to types. The obvious
  guard — "the carrier's type is not a Record" — is WRONG, and not marginally:
  `closed-row-miss-hint` recurses into subterms, so it would fire on a PVec
  carrier whose projection is perfectly fine whenever some *sibling* subterm is
  what actually failed, and OUTRANK the real message. `unprojectable-type?`
  instead enumerates the types that provably have neither fields nor positions
  (Int/Nat/Rat/Posit*/Bool/Char/String/Unit/Pi) and defaults to #f, so the
  claim is self-evidently true everywhere it can fire and an unrecognized
  carrier declines by construction. Pinned by a test that asserts a PVec is
  never called unprojectable.

- **Ordinal OOB in CHECK position.** `def q : Int := het.9` reported a bare
  *"Type mismatch Int <could not infer>"* while the identical expression
  unannotated — or under `(the Int …)` — got the full *"index 9 is out of
  range for the 2-tuple ⟨Int String⟩ — valid indices 0–1"*. **Adding a type
  annotation made the diagnostic strictly worse**, which is backwards, and that
  is the real defect here rather than the missing text.

  Fixed by calling the SAME `closed-row-miss-hint` from the check door, gated
  on `(expr-error? actual)` — the check failed *because* inference gave up, so
  the infer-door hint is describing this very failure and transfers verbatim.
  Placed LAST in the check-side `or`: every message above it knows the expected
  type and this one does not, so it can only ever replace the bare fallback.
  One hint, two consumers — the doors cannot drift.

**A test-harness trap worth the next person's time**: the first draft spelled
its helpers `f` and `g`, and broke a test fifty lines further down that passed
in isolation and failed only in file order. `run-ws` restores the module /
trait / impl / bundle registries from the shared snapshot per run — but the
SPEC STORE is not among them, so a `spec f …` stays live for every later run in
the file and a subsequent `def f := …` gets checked against it. Renaming is the
fix; the shared-fixture pattern does not isolate specs.

**Original:** the ordinal miss-hint is narrower than the surface `.N` opens

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

### 15. ✅ STALE — block-form `|>` on a `def` RHS WORKS (re-probed 2026-08-03)

Both shapes the entry names now evaluate cleanly, 0 errors:

```
def cfg := {:server {:a 1 :b 2}}

def r3 := |> cfg.server map-keys      ⇒ '[:a :b]
def r4 :=
  |> cfg.server
     map-keys                          ⇒ '[:a :b]
```

The entry recorded 2 "Unbound variable" errors at clean HEAD `6d919142`, and
noted the P3a pipe pre-fold had changed the text to "Expression is not a valid
type" while leaving 2 loud errors. Neither reproduces. Something between
2026-07-30 and today closed it — plausibly the LET/POL layout work or this
session's preparse-containment changes; not attributed, because the entry's own
lesson is that attribution without a bisect is a guess.

**Original filing:**

`def r3 := |> cfg.server map-keys` → 2 errors at CLEAN HEAD (`6d919142`,
worktree-pinned A/B; "Unbound variable" ×2) while the same pipe at TOP LEVEL
works. Select-free — the P3a pipe pre-fold changes the error TEXT (now
"Expression is not a valid type", still 2 loud errors) but the seam predates
it. Adjacent to the infix-pipe def-RHS grouping corruption the fold skeptic
also reproduced dot-identically (`(idf (def r3 := …))` — the def swallowed
into the application). A pipe/def layout-seam fix, not selection's.

### 16. ✅ FIXED 2026-08-03 — the `do` expander whole-file-aborted on ANY access-sentinel statement

The entry named the seat exactly right — "the Q_L4 marker-seat class: a raise
where a per-command error value belongs" — and that is the fix, third instance
of the family after `$let-error` and `$mixfix-error`.

`expand-do`'s two raise sites now go through a distinguished `exn:do-syntax`
struct, caught by `expand-do` itself, collapsing to one `($do-error msg)` marker
that `parser.rkt` converts to a per-command `parse-error` VALUE on the same
channel. Verified before/after on the entry's own repro:

```
before:  ZERO commands printed, raw Racket dump, exit 1
after:   0: before : Int defined.
         1: ERROR: do: each binding must be [name <type> value] …
         2: after : Int defined.
         --- 1 errors ---
```

A distinguished struct rather than `exn:fail?`, for the reason recorded at
`exn:let-syntax`: catching broadly would swallow a genuine Racket-level bug
from inside the expansion and report it as a `do` syntax error.

Pinned in `tests/test-let-blocks.rkt` beside its two siblings. The load-bearing
assertion is that the commands on BOTH sides survive — a test that only checked
for an error message would pass against the old raise too, since it errored; it
just took everything with it.

✅ **The display residue is closed too (same day).** The message rendered the
internal `($select-brace a)` rather than the user's `cfg{a}` — the same "raw
internal form in a user-facing message" shape the `let` hint's
`strip-syntax-deep` closed on its own path. `render-access-sentinels`
(macros.rkt) folds the reader's access sentinels back to source, so the message
now reads:

```
ERROR: do: each binding must be [name <type> value] …, got cfg{a}
```

A POSITIVE table with an identity default — an unrecognised form passes through
unchanged rather than being guessed at, the same polarity discipline as
`definitely-not-map?`. A display helper that invents structure for a shape it
does not know would be worse than showing the raw form.

⚠ **Note the general shape this exposes**: head-macro dispatch runs BEFORE the
access-sentinel fold, so ANY expander that reports on its own arguments sees raw
sentinels. That is item 17 below, whose general fix is running the fold before
head-macro dispatch. `render-access-sentinels` is the display-side mitigation
for the one expander that now reports per-command; item 17's ordering change is
still the real answer.

**Original filing:**

A defn body `do` / `cfg{a}` raises raw out of preparse (macros.rkt `do` arm,
"each binding must be [name <type> value]…") → ZERO commands output, internal
sentinel leaked. `cfg.a` baseline aborts identically, so the hole is the
do-expander's (the Q_L4 marker-seat class: a raise where a per-command error
value belongs). Same family: `def cfg{a} := 5` (def-LHS select) aborts at the
def parser — dot baseline identical. P3a makes `x{…}` a shipped surface that
now walks into both.

### 17. ✅ FIXED 2026-08-04 — the access-sentinel fold now runs BEFORE head-macro dispatch

The general fix the entry named, done: `rewrite-dot-access` is hoisted above
head-macro dispatch in `preparse-expand-form`, so every registered head macro
sees folded sentinels instead of raw ones.

**Why it was broken**: the fold lives in `preparse-expand-subforms`, which that
arm only reaches when the head is NOT a macro. A macro head short-circuited to
`resolved(datum)` on the raw list, where `($select-brace …)` and
`($dot-access …)` are EXTRA SIBLINGS of their base — hence "boolrec expects 4
arguments, got 3": an arity complaint for an ordering problem.

`expand-pipe-block` already carried this exact call locally (the P3a verify's
BLOCKING catch, where appending an accumulator into a raw sentinel payload
corrupted a select SILENTLY at 0 errors). This hoists the same one line to
cover every head macro rather than the one that drew blood.

**Safety**: the fold is a fixpoint, so the later pass in
`preparse-expand-subforms` is a no-op; and every form that must keep its
sentinels raw — `$foreign-block`, `$brace-params`, `$select-brace`/`$dot-brace`,
`$select` — is matched by an arm ABOVE this one and never arrives.

⚠ **The entry over-claimed, and the correction matters for the next reader.**
It named `if` / `cond` / `let`. Re-probed against a worktree built at the
pre-fix commit: only **`if`** was still broken. `cond` with a dot-access guard,
`cond` with a select body, bracket-`let`, and WS-layout `let` in a defn body ALL
worked before this change — including the entry's own `let s := cfg{a}` example,
which it said "dumps internal syntax". Something between the filing and now
fixed those; not bisected. Six pins in `tests/test-path-selection.rkt`, and the
perturbation run says exactly three of them (the three `if` shapes) fail without
the hoist — the `cond` and `let` pins pass either way and are there as
regression cover, not as evidence.

**Example-corpus A/B** (15 reachable examples — every one whose source pairs a
head macro with an access sentinel — each run against a worktree built at the
pre-fix commit): **no behavioural difference**. Three files differ textually and
all three are non-behavioural: two carry stack-trace line numbers shifted by
exactly the 25 lines this change inserts into `macros.rkt` (the errors are
pre-existing broken imports, identical either side), and one differs only in a
meta-variable ID suffix (`?suc0_2093` vs `?suc0_1941`) — allocation-order
numbering, which the F1-records example already documents as varying.

**A genuine type error is NOT masked**: `(if true cfg{a} 5)` still errors,
because a select block yields the ROW `{:a Int}`, not `Int` — the entry's own
example was ill-typed independent of the ordering bug. Pinned, so "item 17 is
fixed" can never come to mean "`if` stopped checking".

**Original filing:**

### (original) Registered head-macros (`if` / `cond` / `let`) see RAW access sentinels

Still exactly as filed. `(if true cfg{a} 5)` gives *"boolrec expects 4
arguments, got 3"* plus a cascading "Unbound variable" — per-command, file
survives, and the message blames arity for what is a fold-ordering problem.

⚠ **Note what changed AROUND it**: item 16's `do` expander now reports
per-command and renders its argument as source (`cfg{a}`, via
`render-access-sentinels`). That is the display-side mitigation for ONE
expander. The general fix this entry names — running the access-sentinel fold
before head-macro dispatch — is untouched, and `if` / `cond` / `let` still see
raw sentinels. Do not read item 16's fix as covering this.

**Original filing:**

Head-macro dispatch runs BEFORE the access-sentinel fold, so `if true cfg{a} 5`
→ "boolrec expects 4 arguments, got 3"; `let s := cfg{a}` in a defn dumps
internal syntax. ALL reproduce identically with `cfg.a` (per-command, file
survives). The P3a fix for the one SILENT member of this family (the pipe,
which corrupted instead of erroring) was a pipe-local pre-fold; the general
fix is running the fold before head-macro dispatch — an ordering change with
wide blast radius that needs its own slice. `match` folds correctly already.

### 18. ✅ FIXED 2026-08-04 — dyn-key `map-assoc` widens colliding field types instead of lying

Reproduced exactly as filed, then fixed where the entry said the fix belonged:
the dyn-assoc typing rule.

D16's dynamic-key extension kept every known field's TYPE **verbatim** while
flipping only the tail. But a dynamic key may be any one of those very labels,
so the row kept `:host String` over a runtime 42. Each kept field now widens to
`<T | V>` — an unknown key hits AT MOST ONE label, so every field is either
unchanged or replaced by the inserted value, and the union is the join of
exactly those two possibilities. `record-widen-all-with` (typing-core) is the
TYPE-side dual of D24's `record-mark-all-unknown`:

> dynamic dissoc — presence becomes uncertain, type-if-present stays a fact
> dynamic assoc  — presence stays a fact, TYPE-if-present becomes uncertain

It is also *tighter* than the D24 sibling's per-field fresh meta, because assoc
KNOWS V where `update-in`'s arbitrary fn does not.

**Cost is zero where the types already agree**: `build-union-type` dedups, so
`<Int | Int>` collapses back and the F1a.2 p1b acceptance line
(`map-assoc {:a 1} kk 5` → `{:a Int | _}`) is byte-identical. Across the
row-reachable example corpus, A/B'd against HEAD in a separate worktree, the
ONLY behavioural difference was the intended one.

The laundering the entry named is gone with it: `def sel := d3{host}` now
records `{:host <Int | String>}` instead of a CLOSED `{:host String}`.
`select-project` was already honest per its inputs, as filed — it returns the
field type verbatim, so fixing the input fixed the output. The
reduction-layer panic stays unreachable.

⚠ **What NOT to conclude from an expression echo.** `d3{host}` at the REPL
still prints `{:host Int}`, because an expression command display-narrows a
union against the value it actually produced (the documented display-only
refinement, walled off from static typing). Only the type a `def` RECORDS can
launder, and that is what the pins assert — four in
`tests/test-path-selection.rkt`, including a control that homogeneous assoc is
unchanged.

**Spun off and fixed alongside** (`pretty-print.rkt`): a union in a row field
now prints with its `<…>`. This change made union field types reachable from
ordinary dynamic-key assoc for the first time, and bare they are ambiguous
three ways — `{:host Int | String :port Int | _}` reads as a row whose tail is
`| String :port Int | _`. `<…>` is the union's only source spelling, so this
renders what a user would write rather than inventing a display-only bracket.
Four snapshots in `test-rel-t1-typed-rows.rkt` and two example markers updated.

**Still open, NOT fixed here** (separate, pre-existing, wider churn): the same
ambiguity exists for `[Map String Int | String]` — is that `Map String <Int |
String>` or `<Map String Int | String>`? Type-application argument positions
have the same problem rows had. Out of scope for item 18.

**Original filing:**

`def d3 := [map-assoc base kh 42]` (kh dynamic `:host`) types
`{:host String … | _}` while the runtime value holds `{:host 42 …}` — the
desync is minted by dyn-assoc TYPING (pre-existing). `d3{host}` then returns
`{:host 42} : {:host String}` — a CLOSED row claiming String over an Int,
stripping the `| _` marker that at least advertised uncertainty. The select
is honest per its inputs (Horn D trusts sourced-'present); the fix belongs at
the dyn-assoc typing rule. The reduction-layer panic stays unreachable
(verified: the dissoc route refuses at typing).

### 19. 🔶 Row-literal type annotations have NO working spelling — the REFUSAL is now guided (2026-08-04); the spelling still needs the owner ruling  ·  SAME GAP as § Rel T1 POL.9b item 2

Re-probed 2026-08-04: all three spellings still fail, exactly as filed
(`def q : {:a Int} := {:a 1}`, `[fn [m : {:host String}] m.host]`, and the
angle-bracket `<{:a Int}>` the entry does not mention).

**What changed**: the `def` route no longer says "Expression is not a valid
type" — a message that sends the reader to check whether `Int` is a type when
the problem is the `{…}`. It now says:

> a row type has no writable spelling yet — in type position `{…}` is the
> implicit-binder group (`{A B : Type}`), so this reads as a map literal, not a
> row.
>   Drop the annotation and let inference mint the row: `def q := {:a 1}` gives
>   `q : {:a Int}`.

This deliberately does NOT promise a spelling — that is the open ruling. It
names the actual collision and gives the remedy that works today. A test runs
the remedy, so if inference ever stops minting `{:a Int}` the message cannot
keep advertising it.

**Still open, and the reason this is 🔶 not ✅**:

1. **The ruling itself.** `{…}` in type position already means the implicit
   binder group; a row spelling has to either disambiguate or pick another
   delimiter. Unchanged.
2. **The `fn`-parameter route reports from a DIFFERENT site.**
   `[fn [m : {:host String}] m.host]` gives "Could not infer type", not the
   guided message — it never reaches `is-type/err`. Same for a non-keyword
   literal, which elaborates to `expr-map-literal` and reports "Type mismatch"
   on a def. So one of the entry's two original spellings is still generic.
   Fixing that means finding the annotation-checking site on the `fn` path;
   not attempted here.

The Q_T2 remedy list still omits "annotate" from the select refusal messages,
and should keep omitting it until a spelling exists (owner RATIFIED 2026-07-30,
"annotate comes back when it's real").

**Original filing:**

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
  suite. **Re-verified 2026-08-03: the hazard is LIVE.** `run-step-drain`
  (interop-driver.prologos) still reads

  ```
  match [drain-dials [step-out-reqs cid cs op step]]
    | true  -> emit-after-stash stashed [append [conn-step-outbound step] [withdraw-frames cid op]]
    | false -> emit-after-stash stashed [append [conn-step-outbound step] [withdraw-frames cid op]]
  ```

  — byte-identical arms, and `drain-dials` is reachable ONLY as the scrutinee.

  **A cheap regression test was considered and deliberately NOT written.** The
  obvious one — call `drain-dials` from Prologos and assert the dial FFI queue
  received the request (`ocapn-dial-request` / `-drain` / `-reset!` are all
  exported, so it is easy) — would still PASS after someone collapsed
  `run-step-drain`'s arms, because it never goes through `run-step-drain`. A
  guard that cannot fail in the scenario it names is decoration, which is
  exactly what D4.P2 item 10 says not to leave behind. Covering the real
  hazard needs a test that drives a full `run-step` and then asserts the queue
  is non-empty; that is OCapN-setup-heavy and belongs with the A4 work itself.

  The principled fix is unchanged: extend `OutReq` to a `StateReq` so
  stash/park/publish drain like sends do, instead of depending on seven
  hand-maintained matches.
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
- ~~**U2.**~~ FIXED 2026-08-03. `build-tree-from-domains` was quadratic TWICE
  over, and the measured cost was far worse than the filing's estimate:

  | | before | after |
  |---|---|---|
  | `read-to-tree` on captp-core (4066 lines) | **28,337 ms** | **84–91 ms** (~310×) |
  | FULL TEST SUITE (542 files) | ~220 s | **72 s** (~3×) |

  Two independent quadratics, exactly as filed: `find-line-start-pos` rescanned
  the character buffer FROM ZERO for every content line (O(lines × chars)), and
  `find-content-line-for-pos` walked a LIST with `list-ref` for every token —
  O(tokens × lines²), since `list-ref` is itself O(i). Fixed as prescribed: ONE
  pass building a line-start VECTOR, then binary search per token.

  ⚠ **The first cut broke 28 test files**, and the bug is worth recording
  because it is invisible in the common case: the line-start scan wrote at EOF
  as well as at each newline, and at EOF the loop's `line` is the LAST line —
  whose start was already recorded — so the write moved that whole line's
  tokens to the end of the buffer. It only shows on a file WITHOUT a trailing
  newline, which is exactly the shape a hand-written fixture tends not to have.
  Pinned in `test-parse-reader.rkt` alongside a blank-and-indented-line case.

  This is also the single largest developer-experience change in the session:
  the suite went from ~3.7 minutes to ~1.2.
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

---

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

### 42. ✅ RESOLVED at D4.P4d-0 (`667684ad`, 2026-08-05) — the WRAPPING mint landed (one shared trigger, both groupers, Q_N3 v2 row); Q_U7's second canonical example is producible. *(original text below)*

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

### 45. ✅ RESOLVED at D4.P4d slice 2 (`ba1c055d`) — fixed STRUCTURALLY, not patched

> ⚠ **Re-homed at the P4d close (2026-08-08).** This carried no status glyph while
> D4 §5.P4d's slice-2 record already said *"DEFERRED 45 fixed structurally:
> `select-branch-top-keys`' bcast arm answers `(list (select-step-output-name s))`
> — check ≡ meaning by shared computation"*, with the verify's OLD-vs-NEW-vs-consumers
> table finding zero divergent shapes. The divergence cannot recur because the two
> sides are now ONE computation. *(original below)*

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

### 46. ✅ RESOLVED at D4.P4d-0 (`667684ad`) — Q_U20 in both lifts (sub-inner assembles at 'block, always); the top-keys splice (B1) and the binder unwrap defeat (B2) fixed + pinned in all grades. *(original + cross-ref below)*

### 46-original. ⚠ CROSS-REF + CORRECTION 2026-08-05 (mini-audit `wf_e15a1ef6-dfb`): **same defect as 40**; and "unhandled" is MISLOCATED — both twins HAVE bcast arms (P4c-4c); the defect is that the LIFTS apply the inner step as a ONE-STEP BRANCH, putting `@sub` at branch-head where `select-step-name` hands the raw list to the `(key caret sub)` arm as a "field name". Outcome is CARRIER-DEPENDENT (closed row: loud-but-LYING; dyn row / Map at 'path: SILENT ACCEPT), not the blanket "silent wrong answer" recorded. One fix point per side (`select-bcast-lift` / `bcast-apply`), discriminating on the inner kind. `(@bcast (@sub …))` is unhandled on both sides — currently UNREACHABLE

`branch-entries` would treat the whole `@sub` list as a field name. Unreachable
because the mint never fires: `xs:{name age}` → "Unbound variable `:`" (DEFERRED
42, the `:{` reader mint). ⚠ So DEFERRED 42 and this entry must land TOGETHER —
minting `:{` without handling the sub-inner ω turns an "unbound variable" into a
silent wrong answer. Scope note for P4d.

### 47. ✅ RESOLVED at D4.P4d slice 4d-2 (`25f3f22d`) — the broadcast axis landed; ≡ 59.1

> ⚠ **Re-homed at the P4d close (2026-08-08).** This carried no status glyph. It is
> the SAME defect as **59.1** (the equivalence was probe-verified, and neither entry
> cross-referenced the other — the 40≡46 shape). Both shipped together: a
> `'bcast-elem` wrapper for the PVec/Map carrier plus a broadcast AXIS on
> `format-select-fail`, so the message now names the broadcast and says *"each
> element"* rather than misattributing to *"the subject"*. Cited at four sites in
> `typing-errors.rkt`. *(original below)*

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
- **(c)** ✅ **DONE 2026-08-05 — the limit is LIFTED for `defr`.**
  `rebuild-preserving-locs` (macros.rkt, above `preparse-expand-all`) re-attaches
  srclocs AFTER expansion by walking the original syntax tree against the
  expanded datum: unchanged subtree ⇒ reuse the original syntax object; same-shape
  lists ⇒ align by common prefix/suffix and recurse; changed middle ⇒ anchored on
  the first original element it replaced. Applied at the **`defr` arm only** —
  that is where the tree's only LAYOUT-DRIVEN grammars live (POL.8 clause
  grouping reads element columns; the `||` splitter reads the sentinel's line).
  All four rewrite families now parse in a parenless clause, and DEFERRED 66's
  dominant residual closes with it.
  ⚠ ~~Still limited: a bare top-level `rel` … still degrades~~ **✅ CLOSED same
  day (owner-requested): the `[else]` arm now uses the helper too**, so a bare
  top-level `rel` takes parenless goals with a rewrite, grouped identically to a
  rewrite-free control (test-pinned). POL.9's property contract is carried by the
  helper — its list rebuild and fallback are both 4-arg against the original stx,
  so `prologos-paren-origin` survives exactly as the old direct rebuild kept it
  (probed: `(p2 1:Int 2:Int)` still errors as a goal; `(fruit-color f mm.k)`
  still implicit-solves).
  ⚠ ~~The one spelling still degrading is UNPARENTHESIZED `def r := rel …`~~
  **✅ CLOSED same day (owner-requested): the DEF arm too.** Both of that arm's
  degrading paths now route through the helper: the `def-rhs-stx = #f` fallback
  (multi-element RHS — the measured target; also serves `defn`) and branch (b)
  (single-element rewritten RHS — so a paren `(rel …)` RHS containing a rewrite
  keeps its clause layout, pinned rows-based). The Q_C contract is untouched by
  construction — no `prologos-defrhs-command` is stamped on the multi-element
  path today, the helper never mints properties, and the [else] verify's
  exhaustive property inventory (2 properties, 3 readers, all
  position-restricted) covers the def arm too.
  **Measured post-fix semantics of the unparen spelling, eyes open**: the clause
  PARSES, and the spelling then routes into the PRE-EXISTING POL.9b def-seam gap
  ("Expression is not a valid type" — a bare multi-token RHS is
  application/value by Q_C, and a def-bound rel VALUE infers a hole type), i.e.
  exactly what `def bad := (dbl 3)` is already pinned to produce. Consistency
  with the sibling spellings; the misdirecting "parenthesize each GOAL" refusal
  (when the actual fix is parenthesizing the REL) is gone. The seam gap itself
  remains its own pinned item ("Pinned so a future diagnostic fix shows").
  ⚠ ~~With all three arms converted, the POL.8 guard now has NO known reachable
  trigger~~ **REFUTED by the def-arm adversarial verify within hours, and the
  claim itself was the error** (3rd "family is closed" claim to fall this arc —
  see the dailies Watching entry). The guard fires on a bare top-level
  **`let r := (rel …)`** with parenless clauses and ZERO rewrites in the source
  (measured, 6-line reproducer). Mechanism, from the helper's own algebra: `let`
  goes through the CONVERTED [else] arm, but its desugar is a TOTAL RESHAPE
  (`let` → nested `fn` application through the one funnel), so no prefix/suffix
  alignment at any list level can recover the `rel` subtree — it moved both
  position and depth. ~~That is precisely the case DEFERRED 68's real-diff … is for~~
  **✅ CLOSED same day (owner-requested), and the instrumentation REFINED the
  diagnosis**: the desugar `(let r := V body) → ((fn (r : _) body) V)` is a
  reshape, but V survives DATUM-IDENTICAL — it only MOVES (element 3 → element
  1). So the fix is not a real diff: `rebuild-preserving-locs` gained a
  RELOCATION step — before stamping a changed middle, pair each COMPOUND
  expanded element with a datum-equal original middle element when the match is
  unique IN BOTH DIRECTIONS, and recurse (datum-equal ⇒ the original stx comes
  back wholesale). Guards, each load-bearing: compound elements only (identical
  atoms are everywhere — a false pair attaches the WRONG LINE, the mis-grouping
  class this arc keeps paying for); uniqueness on the original side (two
  identical goals on different lines must not swap locs); uniqueness on the
  expanded side (a duplicated output must not take one loc twice). Ambiguity ⇒
  stamp, exactly as before — monotone by construction.
  Pinned equality-with-the-PAREN-control (same semantics, parenless vs paren
  spelling), single-goal and two-sibling-goal shapes. Genuine moves that are
  ALSO rewritten, or ambiguous duplicates, still stamp — DEFERRED 68's real
  diff remains the durable answer for those.
  ⚠ **A 5th member exists and is pinned as a KNOWN LIMIT (not fixed):
  SIBLING-LET chains** (`let x := 5` / `let r := (rel …)` / body) — found by
  self-probe minutes after the let-leg landing, per the Watching-4 discipline.
  `merge-toplevel-sibling-lets` FUSES the siblings' stxs into one datum
  (`(map syntax->datum unit)` → a merged nested let), so its rebuild has TWO
  source trees; single-source alignment and the one-level relocation step
  structurally cannot recover the second sibling's subtrees. Closing it needs
  NEW machinery — either an stx-carrying `merge-sibling-lets` (the merge
  helpers currently test datum shapes throughout) or deep multi-source pool
  relocation in the helper — a design step, deliberately not improvised
  mid-arc given that every clever alignment extension this arc introduced a
  silent mis-parse caught only by adversarial verification. The guard's honest
  message covers it meanwhile.
  ⚠ **The relocation verify's census (2026-08-07) — the full member list, so no
  future "family is closed" claim is needed**: FIXED = single-binding direct
  `let` spellings (`:=`, bare, multi-line value, two sibling goals), `defr`,
  `[else]` (bare `rel`, goal keywords), `def`/`defn`. STILL DEGRADING, all LOUD,
  all pre-existing: sibling-let chains (above), bracket-form
  `let [r := (rel …)]`, aligned-block bindings (relocation never reaches
  `$let-block` innards), defmacro-EXPANDED rel RHS (rewritten ⇒ relocation
  correctly refuses), moved-AND-rewritten subtrees. Perf: Δ≈0 on 200 lets.
  ⚠ **One CONFIRMED latent false-pair** (re-measured): a user lambda
  datum-identical to the let funnel's minted `(fn (name : _) body)` wrapper —
  with the peel having consumed the true twin — relocates the MINTED node to the
  user node's plausible locs, defeating both uniqueness guards. Today this
  demotes the precise guard message to a generic "Could not infer type" (a rel
  in a lambda body does not type, so no wrong answer is expressible); **it goes
  live as a silent-misgroup hole the day lambda-body queries type — Rel T2's
  purity ruling MUST revisit this** (the code comment at the relocation site
  says so too). "Monotone by construction" is qualified in place: monotone in
  srcloc quantity, not detectability.
  ⚠ **Bodyless goal-RHS let** (`let r := (rel …)` with NO body): the paren
  spelling yields a STUCK `(rel [1] ...) : _` with 0 errors on both legs
  (pre-existing control defect — POL.10's snapshot semantics never fire); the
  parenless spelling now MATCHES that control, converting its old loud guard
  error into the same silent stuck value. Equal-to-control per the pin
  criterion, but the control looks broken — owner look wanted on the bodyless
  semantics.
  ⚠ Also from the same verify: branch (b)'s "a mis-grouping would surface as an
  arity error, not a row" pin-strength argument is TOO STRONG — in DEFERRED 68's
  peel-residual zone (rewrites in BOTH goal lines) with a relation of the merged
  arity registered, the def paren-RHS spelling solves SILENTLY (@[] under a
  mis-grouped 5-ary reading; control errors pairr/2). Pre-existing — byte-identical
  at the pre-51(c) base — but the def spelling belongs on DEFERRED 68's list of
  reachable-through spellings, and the rows-based pin covers the single-rewrite
  case only.
  ⚠ Blast radius of what landed is **narrow**: the `let` aligned-block classifier
  and `||` multi-row splitting already survived a rewrite (the reader's indent
  grouping builds them pre-preparse), so `parse-clause-content` and the fact-row
  splitter were the only consumers re-deriving layout AFTER preparse.
  **Two silent MIS-PARSES were introduced and fixed during development**, both
  found by measurement, both now regression-pinned — see the 51(c) note under
  DEFERRED 66's residual 1 and the tests in `test-rel-t1-pol.rkt`.

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
  splayed at parse time before typing sees them (DEFERRED 66).
  ⚠ Still swallowing, same shape, no repro constructed: `expr-narrow`.
  ⚠ **The rejection now NAMES the relation** — `defr badclause: Could not infer
  type — the relation was NOT registered` — because the bare form gave a
  whole-relation deletion with no pointer to which `defr`. The QUERY-side message
  is still the bare `Unknown relation: badclause` (misleading — they DID define
  it) rather than the enriched *"its defr failed to register (see the earlier
  error)"* that the schema/floundering gates get. Reaching that branch needs the
  name env-bound to an `expr-defr`, i.e. an env write carrying a body that FAILED
  to type — which `zonk` may not survive (DEFERRED 67). That reconciliation is
  51(b)'s job.
- `(= x [+ 1 1])` rendering the binding as `unknown` is its own pre-existing
  display defect; pinned as status quo.
- `expr-guard`'s CONDITION is checked with `check`, whose boolean result is
  discarded, so an ill-typed guard condition behaves exactly like `guard true`
  (`(guard [+ "str" 1])` succeeds). Pre-existing; unreachable in practice today
  because `expr-clause` swallows it first.

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

### 55. ✅ DISCHARGED at D4.P4d-0 slice 5 (`77259635`) — the spurious-dot display fixed (one pp arm honouring `first?`) and the vector-element refusal now names the broadcast alternative. *(original below)*

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

### 59. ✅ RESOLVED at D4.P4d slice 4d-2 (`25f3f22d`) — BOTH members; 59.1 ≡ 47

> ⚠ **Re-homed at the P4d close (2026-08-08).** It was homed on *"P4d slice 4's
> diagnostics batch"*, which has since completed. **59.1** (the misattributed
> subject) is the SAME defect as **47** and shipped with it. **59.2**
> (`not-indexable`'s `x{k}` remedy off-key inside a broadcast) also shipped — the
> remedy moved INTO the `cond` that knows the carrier, is broadcast-aware, and is
> suppressed entirely where nothing true can be said. ⚠ Note the plan's claim that
> *"the existing cond already discriminates the right three cases"* was FALSE: the
> cond discriminated carrier kind and the remedy sat in the unconditional tail.
> *(original below)*

Both pre-existing, both surfaced while pinning the carriers; natural riders on
P4d slice 4's diagnostics batch.

1. **The `@[]` / meta-element broadcast refusal misattributes the subject.**
   `def emp := @[]` types `[PVec _]`; `emp:t` refuses with *"select: the subject
   is not a record, so it has no fields to access"* — which describes the (meta)
   ELEMENT as "the subject", names neither the broadcast nor the key, and carries
   no branch. Refusal is the monotone-safe direction; the wording is the defect.
2. **`not-indexable`'s remedy is off-key inside a broadcast.** An ordinal inner
   over a row carrier (`evs:0`) correctly names the position and the failure, but
   the appended advice is *"select named fields instead (`x{k}`)"* — the spelling
   for the NON-broadcast case. Inside a broadcast the fix the user wants is
   `evs:t`.

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

### 64. ✅ RESOLVED at D4.P4d slice 4c (`a31b7475`) — both gates now name their remedy

The open-schema arm says the admitted form is `:closed`; the collided-selection
arm says "This is a SELECTION — a capability-restricted view" and offers no
list conversion. Both are battery-pinned ("an OPEN schema is told the one thing
that fixes it", "a collided SELECTION is told it is a view"). *(original below)*

The resolver refuses an open schema and a name-collided selection, and both fall
through to the generic `bcast-carrier` message. Neither says the thing the user
needs:

1. **open schema** — the remedy is literally "add `:closed`", and no message
   says so.
2. **collided selection** — it gets the generic carrier refusal, which
   `select-row-of`'s own comment calls "a LIE — a view is a record, restricted",
   and which offers `pvec-from-list` / `pvec-map`, both wrong for a view.
   `select-row-of` already has the honest bespoke message; the broadcast path
   does not reach it. The resolver argues the selection case at length in a
   comment and emits none of it.

⚠ The collision pin asserts only the ABSENCE of the leaked value, so neither
gap can be caught by the battery today. Both are `bcast-carrier` per-carrier
split work — slice 4c.

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


### 66. ✅ FIXED 2026-08-05 — a compound term in a `||` fact row was SPLAYED into fabricated rows (pre-existing silent WRONG ANSWER)

> ⚠ **Renumbered 53 → 66 at the merge-back** (2026-08-08). It was **53** on branch `wizardly-mendel-2fd502`, where it collided with a DIFFERENT `main` entry of the same number. Commit messages and any code comment saying "DEFERRED 53" from that branch mean THIS entry.

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

### 70. ✅ FIXED 2026-08-07 (commit `066e2c45`) — the right-peel over-reached: a COMPOUND `let` body stole the rel RHS's srclocs, and the let leg's pins all used the one body shape that worked

> ⚠ **Renumbered 57 → 70 at the merge-back** (2026-08-08). It was **57** on branch `wizardly-mendel-2fd502`, where it collided with a DIFFERENT `main` entry of the same number. Commit messages and any code comment saying "DEFERRED 57" from that branch mean THIS entry.

**The landed let leg (`134ddb79`) was BODY-SHAPE-DEPENDENT.** With a compound
body — `[some vr]`, the idiomatic spelling — two parenless sibling goals under a
`let`-bound `rel` COLLAPSED into one over-arity goal:

```
let vr := (rel [f]
  &> fruit-color f "blue"
     fruit-size f "small")
  [some vr]
```
→ `solve: Unknown procedure: fruit-color/5 — however, there are definitions for:
fruit-color/2`. The paren-goal control returns `@[{:f "blueberry"}]`. Swap the
body for the ATOM `vr` and the same clause parses correctly.

⚠ **It is not reliably loud.** When the collapsed arity happens to be LEGAL (a
multi-arity relation), the collapse solves and returns a result with **0 errors**
while the correct reading errors — measured. So this was a reachable
silent-wrong-answer, not merely a bad message.

⚠ **And it was a REGRESSION, not a residual**: before the let leg landed, this
same input got the LOUD POL.8 guard. The fix converted a correct refusal into a
mis-grouping — precisely the trade `rebuild-preserving-locs`'s own commentary
forbids ("a partial fix that converts a LOUD refusal into a SILENT mis-grouping
is strictly worse than the status quo").

**Root cause**: `peelable?` accepts ANY two lists ("a group pairs with a group"),
so it cannot tell a list that was EDITED from one RESHAPED WHOLESALE. The let
desugar `(let r := V BODY)` → `((fn (r : _) BODY) V)` leaves BODY and V last on
their respective sides, both compound — so the peel paired them and V (the rel
RHS, carrying the clause layout) was rebuilt against BODY's tree. Nonzero column
⇒ POL.8's column-0 marker goes blind. With an ATOM body `peelable?` refused and
the relocation step found V correctly, which is exactly why every pin passed.

**Fix**: the peel now requires a **shared left anchor** (`pre > 0`).
Right-alignment presumes the two lists are THE SAME LIST with a changed middle,
and `peelable?` only ever sees the single pair it is about to take. The
discriminator is structural, not lucky: the lists this walk protects are CLAUSE
REGIONS, anchored on the left by the `&>` sentinel, which no rewrite touches — so
`pre >= 1` there even when a rewrite lands on the goal head itself. A total
reshape changes element 0's very KIND (the keyword `let` becomes an application),
so `pre = 0`. The reshape case falls through to RELOCATION, which matches V by
datum equality and does not care that it moved.

**Test-pinned** (3 cases, each by CONTROL EQUALITY against the paren spelling —
"no error" was the pin shape that missed this in the first place): the compound
body (the regression); the atom body (guards the relocation path the fix must not
cost); and the single-goal case, which **isolates the trigger — the collapse
needs TWO OR MORE sibling goals AND a compound body** (one goal has no
continuation line for the peel to mis-pair).

**How it was found, and the lesson**: not by any gate. The suite was green over
it throughout (9890/483/0) because no pin used a compound body. It surfaced by
PROBING an *inferred* claim from a grounding audit — the audit reasoned the peel
was body-shape-dependent from the code, and the probe confirmed it. This is the
4th instance this arc of "every automated gate went green over a live defect",
and the 2nd of "the pinned FIXED row is narrower than the pin's name suggests".
⭐ **The generalizable form: when a fix is pinned by a fixture you chose, ask
which axis of that fixture you never varied.** Here it was the let BODY — an
element that is not part of the feature under test at all, which is why nobody
varied it.

⚠ **THE FIRST CUT OF THIS FIX WAS WRONG AND WAS CORRECTED SAME DAY**
(`066e2c45` → `83d06156`), by an adversarial verify that measured both halves.
It gated the peel on `pre > 0`, arguing that clause regions are anchored by the
`&>` sentinel (so `pre >= 1`) while a total reshape changes element 0's KIND.
Both halves fail:
- **It REGRESSED working code.** `pre = 0` is necessary for a reshape but far
  from sufficient — ANY rewrite landing on element 0 zeroes it. The
  **aligned-block** (`let vr (rel …)` with an aligned second binding) and
  **bracket** (`let [vr (rel …)]`) spellings, with a compound body and EXACTLY
  ONE parenless goal, answered CORRECTLY at `fb788bfc` and hit the guard after
  the gate. There relocation cannot reach the moved rel RHS at all (DEPTH: one
  level below the middle for the bracket form, two for `$let-block`), so the peel
  was the only thing carrying the srclocs.
- **It was unsound the other way.** A head-position `mm.k` / `xs[0]` is an
  ORDER-PRESERVING fold where right-alignment is correct; the gate withdrew the
  peel there and stamped a whole clause subtree — two goals became one 5-arg goal
  at a NONZERO column, i.e. the silent mis-group this code exists to prevent.
  (Confirmed at the srcloc + parser level; end-to-end currently unreachable, so
  mechanism-confirmed / severity-refuted.)

**The rule that shipped** is about the PAIR, not the list: refuse the peel only
when the expanded element **moved through unchanged** — datum-equal to exactly
one original in the pre-peel middle, unique on the expanded side too — because
then RELOCATION pairs it with its true original, which is strictly stronger
evidence than positional adjacency. A genuinely rewritten element has no exact
match and still gets the peel, which is the continuation-line case the peel
exists for.

⚠ **CENSUS CORRECTION.** DEFERRED 51(c) lists the bracket form and aligned-block
bindings as "STILL DEGRADING, all LOUD". Measured: at TWO OR MORE parenless goals
they **MIS-GROUP** (`fruit-color/5`), they do not hit the guard — and a mis-group
is loud only while the collapsed arity happens to be undefined; on a multi-arity
relation the same shape is a silent wrong answer. Pre-existing and byte-identical
at `fb788bfc`; now test-pinned as a KNOWN LIMIT so it is visible. Root cause is
DEPTH (relocation scans only the middle's top-level elements), which is the same
wall the SIBLING-LET merge hits.

**Adjacent, still open**: the SIBLING-LET chain (DEFERRED 51(c), the known limit)
is unaffected by this fix — it degrades LOUDLY, upstream, at the fusion in
`merge-toplevel-sibling-lets`, and is the next slice. A grounding audit
additionally named, all unfiled and all LOUD, the private `def-`/`defn-` arms and
the `trait`/`impl`/`specialize` arms, which still do the bare whole-form stamp;
and noted that error POSITIONS for siblings 2..N of a merged let run are all
reported at sibling 1's line.

### 71. ✅ FIXED 2026-08-07 (commits `b3e03913` slice 1, `1ad9411f` slice 2) — THE DEPTH WALL: cons-cell identity was already an exact provenance marker, and the strip was throwing it away

> ⚠ **Renumbered 58 → 71 at the merge-back** (2026-08-08). It was **58** on branch `wizardly-mendel-2fd502`, where it collided with a DIFFERENT `main` entry of the same number. Commit messages and any code comment saying "DEFERRED 58" from that branch mean THIS entry.

Closes the last three members of the 51(c) family in one mechanism: **bracket
`let [vr (rel …)] body`**, **aligned-block `let` (`$let-block`)**, and the
**top-level SIBLING-LET chain**. All three now group and solve exactly like their
paren controls; three KNOWN LIMIT pins are INVERTED (they said to).

**THE WALL.** Everything in `rebuild-preserving-locs` aligns two ELEMENT VECTORS
at ONE level — common prefix, common suffix, the right peel, the relocation step.
A desugar that moves a subtree DEEPER is invisible to all of it. Measured depths
of the moved rel RHS, ORIGINAL side: inline `:=` **1** (works today), bracket
**2**, `$let-block` **3**. On the EXPANDED side it is **2k−1** for the k-th
binding (`let-bindings->nested-fn`'s `foldr` builds a right-nested chain), and
each level of `let` nesting adds +3 original / +2 expanded — i.e. **unbounded
along two axes**, so a fixed-depth-K search was never a fix.

⚠ **AND "SEARCH DEEPER" WAS THE WRONG ANSWER ANYWAY** — the prior audit's
"extend the pool by one level" would have been unsound. Deepening keeps DATUM
EQUALITY as the oracle, and datum equality cannot tell a user subtree from one
the desugar MINTS. That is not theoretical: **at the shallow depth we already
shipped**, `let q := [fn [q : _] [some q]]` has the minted `(fn (q : _) …)`
wrapper taking the USER lambda's srclocs while the user's own lambda is
flat-stamped — a **SWAP**, not a loss. An adversarial 2-line reproducer exists
that is safe at depth 1 and unsound at depth ≥ 2. Deepening strictly enlarges
that class, and it adds a route far wider than the recorded one (which needed the
peel to have consumed the true twin first).

**THE OBSERVATION.** `syntax->datum` allocates **fresh pairs**, and the movers
splice sub-datums **BY REFERENCE** — `let-bindings->nested-fn`'s `foldr` inserts
`value` unchanged, `datum-subst` is a bare `hash-ref`, `preparse-expand-subforms`
returns the SAME object when nothing changed. So **cons-cell identity is already
an exact, zero-cost provenance marker** for precisely the class this family is
about: a subtree that moved through a desugar UNCHANGED. `strip-with-origin!`
records it (`hasheq`: freshly-allocated pair → the syntax object it came from)
while producing the same datum `syntax->datum` produces.

Better than the search on every axis: **no depth parameter** to re-derive when a
sentinel adds a level; **no false-pair exposure by construction**, because a
minted node is a fresh cell and is `eq?` to nothing; and it resolves cases that
datum-ambiguity stamps today.

**THREE THINGS THAT HAD TO BE TRUE**, each measured to matter:
1. **ADDITION, never replacement.** The index holds only COMPOUND nodes and
   POL.8's own sentinel (`$clause-sep`) is an ATOM — replacing the alignment with
   an index walk regressed the `defr` control by handing that symbol the
   whole-form anchor.
2. **Consult at EVERY recursive entry**, not just the outer call.
3. **The STAMP must RECURSE.** It was terminal, which is what made the depth look
   *unbounded* rather than merely *nested*: a moved subtree inside a stamped
   element was never visited at all.

**SLICE 2 — and the earlier diagnosis was wrong in its load-bearing half.**
DEFERRED 51(c) recorded the sibling chain as needing "an stx-carrying merge
(~62 datum-shape sites over 12 functions) or deep multi-source pool relocation",
because the fusion "has TWO source trees". **Neither.** It was never a
depth-of-search problem: `merge-toplevel-sibling-lets` did `(map syntax->datum
unit)` and rebuilt against sibling 1, and `datum->syntax` stamps **RECURSIVELY**
over a bare datum, so every node already carried sibling 1's line and column
before `rebuild-preserving-locs` was ever called. No search, at any depth, can
recover information that is no longer in the tree. The fix is to stop discarding
it: strip the siblings through a **shared** index (~10 lines, all machinery
shared with slice 1). `merge-sibling-lets` still receives plain datums, still
decides on datum shapes, and its error-containment invariant is untouched.

⭐ **The old loudness was INCIDENTAL.** The chain failed LOUDLY only because
sibling 1 sits at column 0 — exactly POL.8's degradation marker. The identical
defect written indented (inside a `defn`) would have been SILENT. "It fails
loudly" was a property of the fixture, not of the code. The same correction
applies to the census's "still degrading, all LOUD" language generally.

**RULED (owner, 2026-08-07)**: a duplicated node takes the **same** loc.
`datum-subst` splices by reference, so a `defmacro` template using `?e` twice
yields two `eq?`-identical copies; both resolve through the index to the one
original. Relocation refuses that case via an expanded-side uniqueness guard; the
index deliberately does not.

**Tests**: the three inverted pins by control-equality, plus an explicit "the
collapse is gone, not merely relabelled" check (control-equality alone would pass
if BOTH sides broke identically — which is exactly how the `def := rel` member
hides from its own pin), plus a "still merges" pin for the fusion (a grouping
test cannot see whether the fusion stopped fusing, which would drop earlier
siblings out of scope). New `tests/test-origin-index.rkt` pins the two properties
a green suite would NOT demonstrate: (A) `strip-with-origin!` is datum-identical
to `syntax->datum` over shapes chosen to break a naive walker (improper lists,
vectors, nested empties) — it is on the hot path for every form now; (B) the
recorded key is `eq?` to the pair the expander receives, **and a SECOND strip
shares no keys** — the trap that would silently reduce the index to a no-op while
every behavioural test still passed.

**Gates**: suite **10020 / 487 / 0** (at `c77fbeb4`); both acceptance files 0
errors. **Both corpus A/Bs came back with ZERO SEMANTIC DIFFS**, each isolated to
its own change:
- D57 (161 files, `fb788bfc` → `f9d68338`): 4 DIFFERS = 2 gensym drifts + 2
  absolute-path echoes; 20 caps all SYMMETRIC with identical sizes.
- D58 (161 files, **`75401b89` → `c77fbeb4`**): 5 DIFFERS = 2 gensym drifts + 3
  path-only (they collapse to IDENTICAL lines once the two worktree paths are
  normalised); 20 caps all SYMMETRIC.

⚠ **A BASELINE-SELECTION TRAP, recorded because it nearly produced a false
alarm.** The D58 A/B was FIRST run against `f9d68338` — the last baseline that
happened to be frozen — which is **PRE-MERGE**. That comparison spans main's
entire 30-commit delta as well as the three D58 commits, and it reported 13
differing lines in `examples/2026-07-26-ciu-t6-path-selection.prologos` with the
BASE leg showing **12 errors** against head's 0. That is main's own broadcast work
landing, measured backwards — not a defect. **The base of a corpus A/B must be the
commit the change actually sits on, not the newest baseline lying around.**
⭐ The tell that caught it: the diff pointed the WRONG WAY. Base worse than head,
in a file already known to run at 0 errors on the current tree, is structurally
impossible for a change of ours — so it is a statement about the HARNESS, not the
code. (Note the asymmetry: had it pointed the other way, that reasoning would not
have been available and the two explanations would have needed separating by
measurement.)

**Explicitly NOT in scope** (owner-ruled a separate slice): the FOURTH member,
`def name := rel …` spliced/unparenthesized, which collapses the same way at a
nonzero column with a blind guard. It is **not** a relocation miss — the expanded
`(rel (?q) ($facts-sep …))` is a NEWLY CONSTRUCTED grouping of three previously
sibling elements, so no datum-equal twin exists at any depth and the index cannot
see it. It needs expanded-side DESCENT, a different generalization. ⚠ And
repairing it will silently flip that arm's `||` fact-row count (measured 3 rows
vs `defr`'s 4 on the same block, both with 0 errors), so it needs its own pin
BEFORE the fix lands.

**Still open, unfiled, and now cheaper**: the private `def-`/`defn-` arms and the
`trait`/`impl`/`specialize` arms (+ private twins) still do a bare whole-form
stamp and never reach `rebuild-preserving-locs`. Because those are STAMP sites,
an index-aware stamp would close them with no per-arm work (inferred, not
measured). Same mechanism discharges the "error POSITIONS for siblings 2..N are
reported at sibling 1's line" item.

⚠ **A SEMANTIC SIDE EFFECT RODE IN ON SLICE 1 AND WAS CORRECTED** (`c77fbeb4`),
found by adversarial verify, measured, **with a silent mode**. The index hands
back the ORIGINAL syntax object — which also carries its syntax PROPERTIES — and
`prologos-paren-origin` is **position-sensitive**: the reader attaches it to every
paren group and `paren-goal-stx?` reads it to decide that a paren group AT COMMAND
POSITION is a relational goal (POL.9). So a `defmacro` lifting its argument to top
level turned an application into a goal:

```
defmacro dbg [$e]
  $e
dbg (inc 10)    before: `11 : Int`, 0 errors  →  after: ERROR, 1 error
dbg (= 1 1)     before: `true : Bool`, 0 err  →  after: `@[{}] : _`, 0 ERRORS
```

The second is the sharp one — zero errors on both legs, only the value and type
differ. `dbg [inc 10]` is identical throughout, isolating the trigger to
macro-spliced PARENS at command position.

**THE RULE THAT FIXED IT**: a hit whose original is the node we were ALREADY
aligned with has not moved and keeps its properties (as the `equal?` branch always
did); any other hit MOVED and takes **srclocs only** (`syntax-locs-only`). That is
byte-equivalent to pre-index behaviour for properties — the old code stamped,
which dropped them — while keeping every srcloc the index exists for.

⚠ Which reading is *correct* is genuinely arguable: POL.9 does say a paren group
at command position is a goal, so the accident arguably made macro-spliced code
behave like hand-written code. **That is exactly why it could not stay** — a
language-semantics change arriving unreviewed, undocumented and untested inside a
srcloc fix.

✅ **RULED 2026-08-07 [owner]: KEEP THE GOAL READING OUT.** A macro-spliced paren
group at command position stays an APPLICATION. This is now a decision, not
merely a reverted side effect — do not "fix" it later by adopting POL.9's
command-position reading for macro output on the grounds of consistency. It is
test-pinned three ways, including the silent goal-keyword case.

⭐ **The generalizable lesson**: "hand back the original node" is NOT neutral. A
syntax object carries a POSITION *and* CLAIMS ABOUT ITS POSITION, and moving it
re-asserts the second where it was never true. Slice 1 argued its own safety as
"the helper never mints properties, only copies originals" — reasoning about
MINTING, and missing that COPYING a property to a different position is itself a
semantic act. The class was entirely unguarded (zero `syntax-property` references
in any test); now pinned three ways, including the silent case.

⚠ **A fail-safe correction for whoever touches this next**: the "stamp at a
column-0 anchor" constraint recorded earlier is a design GOAL that HEAD already
violated in 2 of 3 members, not a property to preserve — and no column-0 anchor
is even available from a syntax object in scope, since a paren-wrapped top-level
form sits at column **1**. The reliable fail-safe is a `#f` loc
(`(datum->syntax #f d #f)`), which BOTH layout guards already test for alongside
`(zero? sent-col)`.

### 72. ✅ FIXED 2026-08-08 (commit `e05729a5`) — MEMBER 4: `def name := rel …` mis-grouped a clause containing a REWRITE; expanded-side descent closes it

> ⚠ **Renumbered 59 → 72 at the merge-back** (2026-08-08). It was **59** on branch `wizardly-mendel-2fd502`, where it collided with a DIFFERENT `main` entry of the same number. Commit messages and any code comment saying "DEFERRED 59" from that branch mean THIS entry.

The fourth member of the 51(c) family, owner-ruled into its own slice. Its clause
elements are collapsed onto one line at a NONZERO column, so POL.8's column-0
marker is blind and a parenless clause silently mis-groups.

⚠ **BUT NOTHING ABOUT IT REACHES OUTPUT, which changes how it can be worked.**
Measured at `c77fbeb4` — the mis-grouped spelling and its shape-identical paren
control produce **byte-identical output**:

```
def k := rel [?f]                    def k := rel [?f]
  &> fruit-color f "blue"              &> (fruit-color f "blue") (fruit-size f "small")
     fruit-size f "small"            k
k
```
→ both: `ERROR: Expression is not a valid type` + `ERROR: Unbound variable`,
2 errors. The **POL.9b def-seam gap** (a bare multi-token RHS is application/value
by Q_C, and a def-bound rel VALUE infers a hole type) masks the whole thing.

**The PARENTHESIZED spelling is CORRECT and is not affected**: `def k := (rel [?f]
&> fruit-color f "blue" / fruit-size f "small")` returns `@[{:f "blueberry"}]`,
0 errors, byte-identical to its paren-goal control.

**CONSEQUENCES FOR SEQUENCING** (this is the entry's point):
- there is **no behavioural failing-test-first** available — the fix would change
  no observable behaviour, so it is pinnable only at the PARSER level (parse the
  form, inspect the `surf-*` tree);
- the `||` fact-row pin a prior audit demanded "BEFORE the fix" **cannot be
  written behaviourally for this arm either**, because the arm errors out. The
  audit's 3-rows-vs-4 observation was made at surf level, not end to end;
- so the honest options are (a) fix it with PARSER-LEVEL pins as insurance,
  labelled latent; (b) close the def-seam gap FIRST — that is what makes
  `def name := rel …` usable at all — after which member 4 is observable and
  testable normally; or (c) leave it filed and take observable work instead.

**Why it is not free to ignore**: the day the def-seam gap closes, this becomes a
LIVE SILENT mis-group, and whoever closes that gap will have no reason to look
here.

✅ **FIXED — and the filed description above was STALE in a way that changed the
fix.** It says the clause elements are "collapsed onto one line". Measured at
`c77fbeb4`: DEFERRED 71's origin index ALREADY recovered the UNCHANGED goal
(L4:C5, correct). What actually collapsed was the **CHANGED** subtree and its
enclosing `$clause-sep` group, both landing on the `:=` token (L2:C7). So the
defect is smaller and sharper than filed, and it fires ONLY when a preparse
rewrite sits inside the rel — without one the group is datum-unchanged and the
index returns the original wholesale.

**THE FIX — EXPANDED-SIDE DESCENT** (`rebuild-preserving-locs`, the relocation
branch). When a RUN of original middle elements folds into ONE compound expanded
element, wrap the run and recurse; ordinary alignment then pairs each element
with its original and descends into the changed one. Guards: exactly one expanded
middle element, a proper list, no longer than the run, and a datum-equal HEAD.
Failing any of them falls through to the stamp, i.e. prior behaviour.

⚠ **THE FOLD ALSO DROPS TOKENS** — this is what the first cut got wrong.
`expand-def-assign` consumes the `:=` as well as wrapping, so an original run of
FOUR (`:=` `rel` `(?f)` `($clause-sep …)`) becomes a THREE-element list; an
equal-length guard never fires. The correspondence is the run's TRAILING slice of
the folded element's own length, and the matching HEAD is what makes it a claim
rather than a coincidence of arity.

Measured: `$clause-sep` L2:C7 → **L3:C2**, `($select-path mm k)` L2:C7 →
**L3:C19** — byte-identical to the known-correct PARENTHESIZED control.

**Test-pinned at the SRCLOC level** (`tests/test-def-rel-srcloc.rkt`), because the
defect is invisible from output and the pre-existing end-to-end guard is VACUOUS
for it (both sides collapse identically, so `check-equal?` passes over a live
bug). ⚠ The helper must handle BOTH sentinel shapes: indent-grouped sources give
a GROUP headed by `$clause-sep`, while inside explicit parens the reader suspends
indent grouping and it arrives as a BARE SYMBOL — a helper knowing one shape
silently returns `#f` for the other.

**Gates**: suite 10027/488/0; both acceptance files 0 errors; corpus A/B
(`59b4174e` → `e05729a5`, 161 files) ZERO semantic diffs, all caps symmetric.
⚠ **The corpus is WEAK evidence here and should not be cited as strong**: no
corpus file contains a `def := rel …` form at all, so it demonstrates
"no collateral damage", not "the fix works". The srcloc pins are the real
evidence.

⚠ **STILL OPEN, and it was the reason this member was scheduled after the seam**:
the `||` fact-row divergence on this arm. A prior audit measured THREE rows here
where `defr` gives FOUR on an identical block, at surf level. That remains
unpinned and unresolved — and see DEFERRED 73, which found the `defr` side is not
a clean oracle either.

**And it is NOT a relocation miss** — the origin index of DEFERRED 71 cannot see
it. The expanded `(rel (?q) ($facts-sep …))` is a NEWLY CONSTRUCTED grouping of
three previously-SIBLING original elements, so no datum-equal twin exists at any
depth and no cons-cell identity survives. It needs **expanded-side DESCENT**
(recurse into the folded expanded element against the folded original run, whose
tail is datum-equal to the originals) — a different generalization from anything
DEFERRED 71 built.

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

### 74. ✅ FIXED 2026-08-08 (commit `59b4174e`) — THE POL.9b DEF-SEAM: one shared gate, and the honest message when a type never existed

> ⚠ **Filed at the merge-back.** This entry was referenced as "DEFERRED 61" by
> commit `59b4174e` and by code comments in `driver.rkt`, `qtt.rkt`,
> `typing-errors.rkt` and `tests/test-rel-t1-pol.rkt`, but an entry was never
> actually written — the number was in use before the section existed. It is
> filed here at its post-merge number; the code comments now say 74.

**THE SEAM WAS ONE LINE, AND THE DEFECT WAS A DIVERGENCE.** The ANNOTATED `def`
path guarded `is-type/err` against non-ground types; the INFERRED path called it
bare. Both were written by the same commit — the guard was simply not mirrored.
The fix is ONE predicate (`def-type-not-ground?`) behind ONE gate
(`def-body-type-ok`) used by BOTH paths, rather than a second copy that could
drift a second time.

**WHAT IT COST WAS MORE THAN A BAD MESSAGE.** The def path type-checks BEFORE it
evaluates, so rejecting a non-ground body preempted every diagnostic raised at
EVALUATION time. Three already-written guiding messages were unreachable:
`def bad := (dbl 3)` → *"dbl is a function — application is written `[dbl …]`"*;
`def bad := solve (nosuchrel a b)` → *"Unknown relation: nosuchrel"*;
`def bad := explain (dbl 3)` → the same guiding message. And `def k := rel …`
(an unparenthesized rel VALUE) could not bind at all.

✅ **RULED (owner, 2026-08-08)**: `def k := rel …` yields a **rel VALUE**. Note
this is NOT the same output as the parenthesized `def k := (rel …)`, which is a
GOAL with implicit solve (POL.9) and yields the SOLVED row set — making them
identical would mean an unparenthesized RHS solves, contradicting Q_C.

⚠ **AN ASYMMETRY THE "just mirror the guard" FRAMING HIDES**: the annotated
path's hole comes from the USER's bare-param annotation — a legitimate wildcard
by construction — while the inferred path's can mean inference FAILED. That is
why mirroring alone was not enough:

**THE HONEST MESSAGE WHEN THE TYPE NEVER EXISTED.** Letting non-ground bodies
through to QTT means QTT is asked to check a body's usage AGAINST a type that is
not there, and its generic `tu-error` reads **"Multiplicity violation"** — naming
a subsystem that is working perfectly. Measured on the corpus: FIVE forms in
three files moved from "Expression is not a valid type" to that, i.e.
vague-but-neutral → specific-but-wrong. So when the type is NOT GROUND and QTT
fails, the report is the inference failure.
⚠ **The trigger is NOT "contains a hole"**: `def d := flip const false 2` infers
a type carrying an unsolved META, and a hole-only test misses it — the first cut
did exactly that and the lying message survived. The condition is the GATE's own
predicate, which is also the principled one.
⭐ **Bonus, unlooked-for**: this also fixed a PRE-EXISTING lying diagnostic —
`examples/2026-04-17-ppn-track4c-adversarial.prologos` command 0 read
"Multiplicity violation" BEFORE any of this work and now reads "Could not infer
type".

**RIDE-ALONG — the `expr-narrow` infer/inferQ TWIN.** `infer` has had an arm
since the node was added; `inferQ` never did, so it fell to `[_ (tu-error)]`.
It was MASKED by the seam, so it is not optional alongside this fix.
See `.claude/rules/pipeline.md` § "infer / inferQ Are Twins".

**Gates**: suite 10019/487/0 at the time; corpus blast radius BOUNDED BY
SIGNATURE to 4 of 161 files and compared exhaustively — zero semantic diffs, no
"Multiplicity violation" left in the affected set.

---

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

### 81. ⬜ The suite's `total_tests` can silently UNDER-REPORT while `all_pass` stays true

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
