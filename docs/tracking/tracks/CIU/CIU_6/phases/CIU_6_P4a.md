# CIU 6 — D4, §5.P4a

Part of [D4](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md), CIU 6's implementation design, split into its parts on 2026-11-06 (owner-approved). This file holds D4 as it stood at `3e76762d`, unchanged except link targets: D4 lines 6377–6596 are lines N-6370 here.

---

<a id="p4a"></a>

#### §5.P4a — Totality + strategy-independent repairs  (no new surface)

**Mini-audit (2026-07-31, at `cab30b9a`) — the catch-all count was FOUR, it
is EIGHT.** The design (audit finding 9) said "four silent catch-alls (e.g.
`[else '()]` syntax.rkt:906)". Censused, every `cond` arm that dispatches on
STEP KIND and silently absorbs an unknown one:

| # | Site | Silent behaviour before P4a |
|---|---|---|
| 1 | `syntax.rkt:849` `select-step-output-name` | `#f` — contributes no name (⇒ every `^_`/`^-_` synth name computed over such a branch is silently SHORT) |
| 2 | `syntax.rkt:907` `select-branch-top-keys` | `'()` — contributes no component (⇒ the parser's L4 sort check AND its output-key duplicate check simply do not see it) |
| 3 | `typing-core.rkt:776` `walk-to-leaf` | projected as a NOMINAL KEY |
| 4 | `typing-core.rkt:824` `select-branch-entries` | projected as a NOMINAL KEY |
| 5 | `typing-core.rkt:882` `select-below-field` | projected as a NOMINAL KEY |
| 6 | `reduction.rkt:1675` `walk-to-leaf` | `project (champ-of v name)` |
| 7 | `reduction.rkt:1703` `branch-entries` | projected as a NOMINAL KEY |
| 8 | `reduction.rkt:1752` `below-value` | projected as a NOMINAL KEY |

(Two more — `typing-core.rkt:822` and `reduction.rkt:1732` — delegate INTO
#4/#7, so they are covered rather than separate.)

⚠ **AND THAT CENSUS WAS ITSELF INCOMPLETE — it is THIRTEEN sites in FIVE
files** (the adversarial verify; 3 of 4 skeptics found pieces of this
independently). The design said four, I said eight, the answer is thirteen.
**The method was the defect**: I grepped for the exported helper names, then
looked for `cond` arms, in three files. That is SYNTAX-directed, and it
structurally cannot see two whole classes — dispatchers that **open-code** the
shape tests, and dispatchers shaped as `and`/`if` rather than `cond`. The five
it missed:

| # | Site | Why the grep missed it | Severity |
|---|---|---|---|
| 9 | `syntax.rkt` `select-branch-collapse` | `(and (select-key-step? s) …)`, not a `cond` | **runs UPSTREAM of the guards** |
| 10 | `syntax.rkt` `select-branch-keyless?` | same | **runs UPSTREAM of the guards** |
| 11 | `parser.rkt` `dissolve-step?` | a fourth file; parser-local re-implementation of #10 | leaf gate for `^..` |
| 12 | `parser.rkt` `branch-problem` | a fourth file; `select-step-cont`'s `#f` IS the catch-all | positional `^` legality |
| 13 | `pretty-print.rkt` `step->string` | **open-coded** `(and (pair? s) (eq? (car s) '@ord))` — no exported identifier to grep | leaked the raw datum |

**#9 and #10 are the serious ones.** They are LEAF classifiers that run
*before* the guard in all three branch walks (`syntax.rkt:932/939`,
`typing-core.rkt:787/798`, `reduction.rkt:1689/1697`). Answering a silent `#f`
there **defeats** the guards downstream rather than reaching them: the branch
is mis-SORTED (keyed vs keyless) with no raise anywhere, and
`select-branch-top-keys`' `key` arm returns immediately without touching
`rest`, so the wrong key set flows straight into the parser's L4 sort check
and duplicate-output-key check. Traced: branch `[server (@bcast (@key name
dissolve))]` yields `'(server)` where `'(#f)` is correct — silently.

**Owner ruling [2026-07-31]: extend the routing; deliver the totality.** All
thirteen now route through `select-step-kind`. Twelve RAISE on a missed kind;
**#13 renders a loud marker instead**, because `pp-expr` is on the
error-message path (`driver.rkt:291/309/507/798/834` + the typing hints) and a
raise there would convert a real diagnostic into an internal crash — and
`typing-errors.rkt`'s catch-all handler could swallow it, achieving strictly
LESS than a visible marker. It uses `select-step-kind/display`, a NON-raising
variant defined by DELEGATION to the classifier (never a second copy of the
kind list — that is the drift this phase exists to kill). This is a written
scope decision, not an omission.

**The `ADDING A KIND` recipe in `syntax.rkt` was corrected to name all
thirteen sites and all five files** — that comment, not this document, is what
a future implementer actually follows at P4c, and the first version of it
would have left five sites wrong.

Q_U7's `(@bcast step)` is the sixth kind that would have met all thirteen.

**Ruling [owner, 2026-07-31]: route ALL EIGHT through one classifier.**
`select-step-kind` (syntax.rkt, exported) maps a step to
`'key | 'ord-step | 'caret | 'sub | 'ord-branch` and RAISES otherwise; every
consumer ends in `select-step-kind-unhandled`, which raises naming ITSELF.
The kinds are pairwise disjoint by construction, so the classifier is total
and order-independent. `match` cannot help — steps are s-expressions, not
transparent structs, so `pipeline.md` § Exhaustive Walkers' generic-rebuild
answer does not apply and a named classifier is the available structural
form. Two consumer shapes, by arm size: `case` where the bodies are small
(1, 2, 3, 6), a `memq` guard + explicit else where the body is the walk's
largest arm (4, 5, 7, 8). Both route through the classifier. In every case
`sub` joins `key`/`caret` because that is exactly what the old `else` caught
— **the refactor is behaviour-preserving by construction**, and the totality
else fires only for genuinely NEW kinds.

**⚠ SELF-REVIEW CAUGHT A DEFECT I INTRODUCED — the twin-drift class, again.**
The `memq` guard must list EXACTLY the kinds the old `else` caught, or the
"behaviour-preserving by construction" claim above is false. At sites **5**
(`select-below-field`) and **8** (`below-value`) — the two "below a kept head"
walks, which are ATOMIC TWINS — the arms above the else take TERMINAL `sub`
and `ord-step`, so that else ALSO caught **`ord-branch`**. The first cut wrote
`'(key caret sub)` at both, turning a delegation into a RAISE. Sites 4 and 7
were correct (their preceding arms DO take `ord-branch` and `ord-step`), which
is exactly why eyeballing "they all look the same" fails: the four guards do
NOT have the same correct answer. **The suite did not catch this** — the path
is unreachable from surface syntax today (R4: a green suite proves nothing for
this class), which is precisely why it earned a direct-call pin rather than
trust. Both fixed together; the pin was validated by re-introducing the defect
and confirming it fails with `select-below-value: no arm for select step kind
'ord-branch` — the reason its name claims, not a vacuous pass.

**Test delta: +20** (204 → 224), all in `tests/test-path-selection.rkt`.
- **8 totality pins**, one per site. These are DIRECT-CALL unit pins by
  necessity: there is no sixth step kind yet, so the untotal case is
  **unconstructible from surface syntax** and no `process-string` pin can
  reach these arms. Reached via `select-step-output-name` /
  `select-branch-top-keys` (already exported), `tc:select-project`, and
  `select-reduce` (**newly exported for the pins — zero behavioural change**;
  production still enters through the whnf `expr-select` arm).
  ⚠ The pins were written against the CURRENT walks asserting they RAISE,
  NOT against a not-yet-existing `select-step-kind` — a pin calling the
  latter would have failed with "unbound identifier", which is **not the
  reason the pin claims** (this arc's hazard 4, already the source of one
  vacuous pin and two mis-premised fixtures). All 8 went RED as
  `check-exn`/"no exception raised" — the claimed reason — then GREEN.
- **3 whole-node-abort fixtures**, pinning the ratified ruling. Honest
  status: these **characterize existing behaviour** (the ruling was a
  RATIFICATION), so they did not go RED first; their job is to stop P4c
  drifting it. The discriminator is deliberate — TWO branches with the FIRST
  succeeding, so a per-element LOWERING would produce a 2-field record with
  the panic in one slot (the P2.b fabrication class) while WALK produces the
  panic as the whole node.
- **2 twin-regression pins** for the self-review catch above — the "below a
  kept head" walks must still DELEGATE an `ord-branch`, not report no arm.
  The assertion is deliberately NOT "returns value X" but "does not fail the
  TOTALITY way": an `(@ord N)` there may still panic for an honest reason
  (bad subject, OOB); what it must never do is claim the walk has no arm for
  its kind.

**The two repairs, measured SEPARATELY for attribution** (probe:
120×3 multi-branch selections over champ + rrb subjects; `reduce_steps` is
the exact, ambient-immune counter):

| | `reduce_steps` | `reduce_ms` (3 runs) |
|---|---|---|
| A — totality routing only | 7791 | 24 · 24 · 27 |
| B — + subject re-whnf hoist | 7791 | 25 · 26 · 27 |
| C — + `whnf-trivial?` container arms | 7791 | **19 · 19 · 19** |

- **The re-whnf hoist moved NOTHING** (A→B). The audit called it a "perf
  lever the Intent never budgeted"; on a `def`-bound subject the repeat
  `whnf` calls are **cache hits** (confirmed structurally: `reduce_steps` is
  flat, and `perf-inc-reduce!` fires in `whnf-impl`, i.e. only past the
  cache). It is landed as a **contract fix, not a perf win** — the header
  comment had claimed since P3a that the subject is "evaluated ONCE … reused
  across every branch" while `(whnf subj-expr)` sat INSIDE the `append-map`
  lambda. It would matter for an uncached/expensive subject; say so rather
  than bank an unearned number.
- **The `whnf-trivial?` container arms moved all of it** (B→C) — but ⚠ **the
  reasoning I first gave for this was INVALID, and the wall method was too**
  (both caught at the P4a adversarial verify):
  - **The `reduce_steps` control is CIRCULAR for the B→C leg.**
    `perf-inc-reduce!` fires at `reduction.rkt:2054`, **before** the
    `whnf-trivial?` branch at `:2062`, so `reduce_steps` *cannot move* when
    container arms are added. Its flatness is true by construction and carries
    ZERO evidential weight for C. (It legitimately supports A→B, where a
    removed uncached `whnf` would have shown.) A tautology dressed as a
    control is exactly the "claim is true at a layer nobody named" family.
  - **n=3 sequential is not an A/B**, per our own `testing.md`. Measured
    run-to-run spread on an UNCHANGED tree: `reduce_ms` 13·14·14·14·15·16·16·16
    (~20% peak-to-peak), so a ~6 ms delta sits ~1.2× the noise band. The
    "variance collapsed to 19·19·19" is also partly integer-ms quantization
    (`performance-counters.rkt` rounds).
  - **What actually carries the claim** is an interleaved per-call microbench
    the verify constructed: `expr-tchamp`/`expr-trrb`/`expr-thset` are
    structurally identical transients that are NOT whnf-trivial and have no
    match arm, giving a true control. 200k iters × 5 rounds: **211 ns
    (fast path) vs 2019 ns (full match) = 1822 ns/call, 9.5×**. Predicate-
    position probing (98 ns at position 1 vs 200 ns at position 46 ⇒
    2.25 ns/predicate) also refutes the "this is the CS interpreter"
    confound — the 1.8 µs is genuine compiled cost of a ~265-way linear
    struct-predicate chain.
  - **Honest magnitude**: `reduce_ms` is ~0.3% of end-to-end wall
    (`gc_ms` alone is 3× it), so "−25%" is ≈ **−0.1% of wall**. Real,
    mechanically explained, and small. `reduce_ms` is also the wrong slice in
    both directions — `time-phase! reduce` wraps only four driver sites, so
    every `whnf` inside type-check/qtt/elaborate lands in other buckets.
- **Safety proof re-verified at `cab30b9a`** (re-verify if the match moves):
  `whnf-impl/match` has **no bare-head arm** for `expr-champ`/`expr-rrb`/
  `expr-hset` — every such pattern sits at nested indent, matching an
  already-whnf'd ARGUMENT of a map/set/vector operation, never `e`. They
  therefore fell to `[_ e]` (`reduction.rkt:3957`) — identity — so the fast
  path returns exactly what the match returned.
- **This IS the P2-baseline establishment.** §5.P4/§5.X say "priced against
  the P2 baseline"; **no such baseline was ever recorded** (neither P2's nor
  P3's close notes carry one, and there is no selection baseline in
  `data/benchmarks/`). Table A above is that baseline, recorded so X.close's
  bench matrix is executable.

**Carried forward from P2's close notes**: the `xs.0:name` focus-set
obligation — Q_U8's *positional* rule discharges it BY CONSTRUCTION (`.N`
joins the focus set free), confirm when P4c lands.
⚠ **The second item I listed here was FALSE** (caught at the P4a verify): I
wrote that "commit the corpus A/B harness" was still uncommitted. It is
committed — `racket/prologos/tools/reader-corpus-ab.rkt`, landed at
`3005170b` (the P2 commit), and **§5.P2's own close notes record it as
delivered**. I asserted an open obligation that this document already
recorded as closed, four hundred lines above. Verified by
`git log --diff-filter=A -- racket/prologos/tools/reader-corpus-ab.rkt`.

**Test-quality repairs from the verify** (the pins were weaker than claimed):
the 8 totality pins used `check-exn exn:fail?` — demonstrated to pass on an
ARITY error or a malformed fixture, so a future change to `make-record`/
`champ-insert` could have turned all eight green with the arms fully reverted.
Narrowed to a `totality-exn?` predicate matching the actual message, and the
fixtures HOISTED out of the guarded lambdas (a fixture that throws must fail
the test, not satisfy it). Whole-node fixture 2 was a message pin sold as a
discriminator — `expr-champ` is `#:transparent`, so a buried panic prints both
`nope` and `invariant violation` too; the `expr-panic?` assertion (the half
that actually discriminates) was added to it. And `select-step-kind-unhandled`
had **zero coverage** — all 8 pins raise from the CLASSIFIER, never from a
consumer's else — so the mechanism the design advertises now has a direct pin.

**Known limit, stated rather than papered over**: the whole-node fixtures
discriminate at BRANCH granularity inside one `select-reduce` call. If P4c
implements ω by mapping a sub-walk over N elements, each element gets its own
`let/ec` and burial is reintroduced with all three fixtures still green. The
element-level guarantee cannot be pinned until a broadcast step exists — P4c
owes that fixture.

Status: ✅ (see the Progress Tracker).

