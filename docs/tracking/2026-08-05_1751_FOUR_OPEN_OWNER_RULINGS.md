# Four Open Owner Rulings — the questions gating the DEFERRED queue

**2026-08-05** · branch `claude/ocapn-prologos-implementation-auLxZ` · suite 551 / 10674 / 0

These four questions came out of a systematic `DEFERRED.md` sweep. Each one
blocks work that is otherwise ready — implementation is not what is missing.
They are gathered here because they were scattered across four sections and one
dailies file, which is why they kept getting re-derived.

Each section states: **what is already true** (probed, not remembered), **the
question**, **the options with their costs**, and **what unblocks** on an answer.

None of these needs a long answer. A sentence per question is enough to start.

---

## Q1 — Is `eval` a capability?

**Status of the code**: the DATA half of homoiconicity is done and working.
`prologos::data::datum` defines `Datum` with constructors and predicates;
`[nat? [datum-nat 5N]]` gives `true`. What is missing is the evaluator:
`quote`, `eval-datum`, `read-datum` are all `Unbound variable`.

**Why this is a ruling and not a task.** The implementation is close to free —
Racket already has the evaluator, and a `foreign racket` bridge to the driver's
own `process-string` is the same shape as the Phase 4a/4b bridges that closed
Numerics Phase 4 and String 4a–4d. It would take minutes.

That cheapness is the trap. This is a **capabilities language**, and a
plain-function `eval` is ambient authority to execute arbitrary code — the one
primitive whose entire point is that it should be gated. Building it the easy
way silently makes every module able to run anything.

**The options:**

| | shape | cost |
|---|---|---|
| **A** | Plain function — `eval-datum : Datum -> a` | Free to build; ambient authority; contradicts the capability model at its sharpest point |
| **B** | Capability-gated — `eval-datum : EvalCap -0> Datum -> a` | Follows `read-file`'s existing precedent (`:requires (ReadCap)`); needs a decision on where `EvalCap` sits in the subtype lattice (below `SysCap`? a peer?) |
| **C** | Capability-gated AND restricted — eval in a sub-environment with a caller-supplied module registry rather than the ambient one | Strongest; most design; probably its own track |

**What unblocks**: Homoiconicity Phase IV (runtime `eval` / `read`,
`unquote-splicing`, quasiquote in paren forms).

**Note for whoever answers**: B is the answer the rest of the language implies —
`prologos::core::capabilities` already carries a subtype hierarchy and
`read-file` is already gated this way. The real content of the question is
whether `EvalCap` is a new peer or sits under `SysCap`, and whether `main`'s
powerbox hands it out by default.

---

## Q2 — Can `{…}` mean a row type in type position?

**Status of the code**: row types exist and inference mints them correctly —
`def q := {:a 1}` infers `q : {:a Int}`. What has no spelling is *writing* one:

```
def q : {:a Int} := {:a 1}          → refused
[fn [m : {:host String}] m.host]    → refused
def r : <{:a Int}> := {:a 1}        → refused
```

Zero in-tree uses, because there is no way to write one.

**The collision.** `{…}` in type position already means the **implicit-binder
group** (`{A B : Type}` in a `spec`). A row annotation would have to either
disambiguate against that or pick another delimiter.

**The options:**

| | shape | cost |
|---|---|---|
| **A** | Disambiguate `{…}` by content — keyword-headed ⇒ row, binder-headed ⇒ implicit group | No new syntax; the reader already distinguishes these for map literals (`map-literal-brace-params?` exists); a keyword-named type variable would be ambiguous |
| **B** | A distinct delimiter or prefix — e.g. `#{:a Int}` or `row{:a Int}` | Unambiguous; adds surface; another thing to teach |
| **C** | Named rows only — declare with `schema`, annotate by name | Already works today (`schema Point` + `spec f Point -> Int`); no anonymous rows ever |

**What unblocks**: DEFERRED D4.P3a item 19, Rel T1 POL.9b item 2, and the
"annotate" remedy that was deliberately dropped from the select-refusal messages
(owner ratified 2026-07-30: *"annotate comes back when it's real"*). Those
messages currently name only remedies that work; re-adding the third is
mechanical once a spelling exists.

**Note**: option C is already the status quo and may simply be the answer. If so
this closes as documentation rather than as work.

---

## Q3 — How do `Ord` and `Seq` thread through SortedMap?

**Status of the code**: the backend is **built** —
`racket/prologos/ordered-map.rkt`, a persistent weight-balanced tree, 16 tests
covering balance under adversarial input, persistence, and a differential oracle
against a sorted assoc list. The blocker the entry named is gone.

Deliberately **not** decided by the backend: it takes the order relation as an
explicit parameter (`om-set t <? k v`). That was left open rather than guessed.

**Two sub-questions, and they are separable:**

**(a) How does the comparator reach the operations?**

| | shape | cost |
|---|---|---|
| **A** | Explicit comparator argument, as the backend has it | Simplest; un-idiomatic for the language; every call site carries it |
| **B** | `Ord` dictionary via a `where (Ord K)` constraint, like the rest of the stdlib | Idiomatic; the map must then carry or re-resolve its dict on every operation |
| **C** | Comparator captured in the map value at construction | Ergonomic; makes the map value carry a function, which interacts with serialization (`.pnet`) and equality |

**(b) Does SortedMap join the `Seq` protocol?**

`Seqable`, `Buildable`, `Foldable`, `Reducible` are already proper traits with
instances for List, LSeq, PVec and Set, and `map`/`filter`/`reduce`/`length`
dispatch through them. `Seq` itself is the one straggler — still
`deftype [Seq $S]` at `book/collection-traits.prologos:118` — a single leftover
in a family that already migrated, not a pending family migration.

Joining SortedMap to the protocol means deciding whether iteration order is part
of the contract (it is, for a sorted map — that is the point) and whether that
conflicts with the existing unordered instances.

**What unblocks**: the Prologos-level `SortedMap` / `SortedSet` surface. The
backend is ready the moment (a) is answered; (b) can follow separately.

---

## Q4 — Should `redex` be a project dependency?

**Status of the code**: `tests/test-redex-model.rkt` runs the Redex model — the
project's **spec** — from the suite, 177 model tests. It **skips loudly** when
the `redex` package is absent.

**Why this matters more than a packaging preference.** The model was not being
run in this environment at all: `raco pkg show redex` → absent, and the suite
runner only scans `tests/`, never `redex/tests/`. Nothing reported it; the suite
was green the whole time. The spec could have drifted arbitrarily far from the
kernel and no gate would have noticed.

Nothing *had* drifted — all 177 pass once `redex` is installed — but that is
luck, not a control.

**So a green suite still does not prove the spec was checked.** That is the
actual state today.

**The options:**

| | shape | cost |
|---|---|---|
| **A** | Hard dependency — `redex` in `info.rkt` | Strongest gate; a package on every contributor's machine |
| **B** | CI-only — installed in the workflow, skipped locally | No local burden; the gate is real on `main`; local suites stay silently partial |
| **C** | Status quo — skip when absent | Zero cost; the spec remains unverified by default, which is what surfaced this |

**What unblocks**: making "the suite is green" mean "the spec was checked".

**Note**: B is the cheap correct answer if the concern is contributor burden —
CI is where a spec gate has to hold anyway. The thing to avoid is C-by-default
with no one aware of it, which is where this started.

---

## Why these four and not others

`DEFERRED.md`'s remaining entries fall into three kinds. Only these four are
answerable in a sentence:

1. **These rulings** — decisions, not work.
2. **Construction tracks** — row-polymorphic unifier (scoped: 28
   `expr-Record-tail` sites, 83 `'closed`/`'dyn` literals, a new row-unification
   case, the walker checklist), S4's paired halves, rope/TextBuffer, concurrent
   session runtime, PM 12/12B.
3. **Research** — session-type parameterization, propagator taxonomy, bounded
   liveness. Honest content is "not started".

**One transferable finding from the sweep that produced this list**: `DEFERRED`'s
*blocker* claims were unreliable in one direction — **five entries named a
blocker that was already built, or simply was not the obstacle**. Q3's blocker
turned out to be gone; Q1's is a ruling wearing an implementation costume. When
answering these, it is worth probing the blocker rather than trusting the
framing, including the framing above.

## References

- `docs/tracking/DEFERRED.md` — § Homoiconicity Phase IV (Q1), § CIU T6 D4.P3a
  item 19 + § Rel T1 POL.9b (Q2), § Collections — Deferred Items (Q3)
- `docs/tracking/standups/2026-08-03_dailies.md` — the Redex finding (Q4) and the
  running list of the four
- `racket/prologos/ordered-map.rkt` + `tests/test-ordered-map.rkt` — Q3's backend
- `docs/tracking/2026-02-19_HOMOICONICITY_ROADMAP.md` — Q1's source
