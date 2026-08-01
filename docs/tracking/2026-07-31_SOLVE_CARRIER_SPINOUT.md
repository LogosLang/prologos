# Rel/CIU seam spin-out — the SOLVE CARRIER: `List` → `PVec`

**Status**: ✅ **COMPLETE** 2026-07-31 · **Base HEAD** `cab30b9a` ·
**Branch** `focused-morse-3454bf` (NOT pushed) · **Gate**: full suite **9548 / 477 / 0**;
8 acceptance files **296/296**

## Why

CIU Track 6 Path Selection ruled **Q_U9** (2026-07-31, owner): the broadcast
operator `:` REFUSES over `List`, because `List` is a user-space inductive
(`data List {A} | nil | cons`, `lib/prologos/data/list.prologos:12`) with no
native carrier struct, and the key-sort thesis (path-selection spec §1.1) does
not reach a cons spine. Every other selection carrier is native:
`Map`→`expr-champ`, `PVec`→`expr-rrb`, `Set`→`expr-hset`, het-tuple→`expr-Record`.

But `solve` returns `List`, and typed solution rows (Rel T1 Aspect B) exist
precisely so relational output composes with the records surface. The ergonomic
fix therefore belongs **upstream**: change the container `solve` produces rather
than widen selection's carrier semantics. This unblocks `quests:t`-style path
selection over query results — the primary DEMO-track need.

Second, unrelated-but-adjacent deliverable: the **`let` implicit-solve gap** (§4).

## Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| P0 | Census at HEAD, acceptance file, `explain` disposition ruling | ✅ | this doc; `examples/2026-07-31-solve-carrier.prologos` |
| P1 | Carrier flip: typing + runtime + display walkers + consumers + `.pnet` | ✅ | `b2c4366a` |
| P2 | `let` implicit-solve gap + guided diagnostic | ✅ | `b5b641b9` (+ `353c465e` foreign-block fix) |
| X.close | Full-suite gate, roadmap, D4 §Q_U9 back-note | ✅ | this commit |

## 1. The seam — VERIFIED at `cab30b9a`

The opening note called this "two lines". The census found **six** production
sites; the three display walkers were the capture gap. A **seventh** (the `.pnet`
carrier, §1.4) only surfaced during P1's adversarial verification — the census
missed it too.

### Typing (2 sites)

| Site | What |
|---|---|
| `typing-core.rkt:4341` `solve-row-type` | `wrapper ∈ 'list \| 'bare`; the List-ness is the single line `(expr-app (list-type-fvar) row)` |
| `typing-core.rkt:3249/3254/3256/3261` + `qtt.rkt:2476/2482/2489/2495` | the 4 solve/explain call sites × the infer/inferQ twins |

`solve-one` is `'bare` (D25.4-unwrapped champ) and does **not** move.

### Runtime (1 site, 7 call sites)

`reduction.rkt:273` `answers->prologos-expr` = `racket-list->prologos-list` ∘
row-build. Called from:

| Enclosing fn | Call sites | Disposition |
|---|---|---|
| `run-solve-goal` (:653) | :664 :680 :706 :719 :750 | **FLIP** |
| `run-explain-goal` (:886) | :905 (`racket-list->prologos-list`) :934 | **FLIP** |
| `run-narrowing` (:441) | :492 :504 :511 | **STAYS List** — see §3 |

### Display (3 sites — THE CAPTURE GAP)

| Site | What it does | Why it breaks |
|---|---|---|
| `typing-core.rkt:3977` `display-row-type-parts` | unwraps `[List row]` for the B3.2 coinductive echo refinement | matches `expr-app`; `expr-PVec` is a different struct → refinement silently stops firing (holes never fill) |
| `typing-core.rkt:3996` `display-result-rows` | walks the cons spine to observe row values | no `expr-rrb` arm → returns `'()` → `refine…` early-returns `ty` |
| `driver.rkt:635` `pp-solve-echo-ordered` | POL.3 declaration-order key echo | no `expr-rrb` arm → falls back to `pp-expr` → rows echo in hash order |

All three fail **silently** (degrade, not error) — exactly the class the
adversarial-verify gate exists to catch. Each gets a failing test first.

### 1.4 Module caching (`pnet-serialize.rkt`) — found by adversarial verify, NOT by the census

The census asked "what READS a solve result". It should also have asked "what
PERSISTS one". Rel T1 POL.10 made `def` bind whnf-reduced values, so a library
module's `def x := solve (…)` puts the carrier into a module env-snapshot — which
is exactly why the v2→v3 cache bump added a `champ-sentinel` arm for the rows.

Post-flip those rows arrive inside an `expr-rrb`, and probing the serializer
directly showed a **real defect, silent and correctness-relevant**:

```racket
(deep-struct->serializable (expr-rrb (rrb-from-list (list row))))
;; ⇒ #(struct:expr-rrb #(struct:rrb-root #f 1 0
;;      #( #(struct:expr-champ #(struct:champ-root #(struct:champ-node 256 0
;;           #( #(421465141712168 …) ) …)))) ))
```

`rrb-root`'s `tail` is a **raw Racket vector**, and `deep-s->v` has arms for
`pair?`/`list?`/`hash?`/`box?`/`struct?` but **none for `vector?`** — so the
tail's contents fell through `[else v]` unchanged, writing `equal-hash-code`
values to disk. Those are process-stable only; persisting them is precisely what
the champ-sentinel arm exists to prevent.

Fixed by an `rrb-sentinel` arm mirroring `champ-sentinel` exactly
(reconstructive: elements serialized — each still routed through `deep-s->v`, so
nested rows get their own sentinel — tree rebuilt at read via `rrb-from-list`),
plus a `PNET_VERSION` 8→9 bump so no cache written under the broken path is read
back. Pinned by two round-trip tests.

The same latent gap exists for `expr-hset` (Sets), which wraps a champ without
hitting the `expr-champ?` arm. **Pre-existing and orthogonal** — spun out rather
than folded in.

## 2. Consumer census (at HEAD, via `git grep … HEAD`, not the dirty tree)

**`.prologos` corpus** — 2 live sites pipe a solve-bound name into a HOF, both
in `examples/2026-07-26-ciu-t6-path-selection.prologos`:

- `:234` `map [fn [q] q.r] quests` (bound at `:224` `def quests := solve (quest t g r)`)
- `:246` `map [fn [q] q.t] alice-quests` (bound at `:243` by an *implicit* solve)

⚠ **CORRECTION to this section's first draft** (caught in P1 by the acceptance
run, not by the census): the census read `spec map [A -> B] [List A] -> List B`
(`lib/prologos/data/list.prologos:46`) and concluded `map` is List-monomorphic,
so both sites would need rewriting to `pvec-map`. **That is wrong.** That spec is
one *instance* under container-generic dispatch. Probed at the flip:
`map`, `filter`, `length` and `first` all accept the PVec carrier and return
PVec (`map [fn [q] q.f] rows` → `@["apple" "cherry"] : [PVec String]`). So **no
`.prologos` source changes are needed at all** — only the `;;NN=>` markers move.
The lesson is the general one: a `spec` line is evidence about one instance, not
about dispatch. Every other `.prologos` solve site is a bare top-level echo with
no downstream container consumption.

`pvec-map` (a native AST primitive reducing via `rrb-fold`, no List round-trip)
remains available and is pinned in the acceptance file alongside generic `map`.

**Racket tests** — 7 files carry shape/type assertions over solve output:
`test-rel-t1-typed-rows` (20), `test-rel-t1-pol` (11), `test-rel-t1-naf` (10),
`test-relational-e2e` (9), `test-rel-t1-typed-vars` / `test-defr-schema` /
`test-bound-args-01` (1 each). Most are mechanical type-string pins
(`"[prologos::data::list::List {:a Int :b String}]"` → `"[PVec {:a Int :b String}]"`)
and value pins (`'[{…}]` → `@[{…}]`).

**One user-visible shape change**: the empty result flips from
`nil : [List {:y _}]` to `@[] : [PVec {:y _}]`. This is a genuine improvement —
`nil` was a *nullary constructor* that carried no container identity, so an empty
solve result and a `None` looked alike at the value level.

**Bag semantics survive.** Rel T1 POL.1 ruled solution sets are BAGS (one row per
derivation path; the multiplicity IS the derivation count — ℕ-semiring
provenance). PVec is ordered and duplicate-bearing, so this is preserved.
Test-pinned with a duplicate-row fixture rather than assumed.

## 3. Rulings

**R1 — `explain` / `explain-with` FLIP with `solve`.** They share the `'list`
wrapper, the same runtime shape (rows + conditional `:certainty`/`:cycle`/
`:provenance` metadata keys under a `'dyn` tail), and the same consumers.
Splitting the family would be an arbitrary inconsistency users would have to
memorize. The `'dyn` tail already excludes explain rows from B3.2 display
refinement; that is unchanged by the carrier.

**R2 — `solve-one` unchanged.** It is `'bare` (an unwrapped champ, D25.4), not a
container at all. Out of scope by construction.

**R3 — `run-narrowing` STAYS on `List`.** Functional-logic narrowing (`unify`
against a target) is a different feature that happens to share the row-building
helper. Its static type is `expr-hole`, so flipping it would move a runtime shape
with no type to match, for no ruled benefit. Q_U9 is scoped to the solve family.
Named here rather than left implicit; if narrowing later wants a native carrier
that is its own ruling.

**R4 — the `'list` wrapper value is DELETED, not retained.** After the flip all
four solve/explain sites pass `'pvec` and `solve-one` passes `'bare`, leaving
`'list` with zero callers. Per `workflow.md` § "Belt-and-suspenders is a blocking
red flag", a dead alternative path is not a safety net. `solve-row-type`'s
contract becomes `wrapper ∈ 'pvec | 'bare`.

**R5 — the row-build core is FACTORED, not duplicated.** `answers->prologos-expr`
splits into `answers->champ-list` (the shared core, returning a Racket list of
`expr-champ`) plus two one-line wrappers. Narrowing keeps the List wrapper; the
solve family gets `answers->prologos-pvec`. No copy-paste twin to drift.

## 4. The `let` implicit-solve gap

Probed and reproducible at `cab30b9a`:

| form | result |
|---|---|
| `def x := (goal …)` | ✅ implicit solve fires (Rel T1 POL.10) |
| `let x := (goal …)` (nested shorthand) | ❌ `ERROR: Unbound variable f` |
| `let x (goal …)` / aligned block | ❌ same |
| `let [x := (goal …)] body` (bracket form) | ❌ same |
| `let x := solve (goal …)` | ✅ works |

Implicit solve's scope is "command position ONLY — top-level commands and `def`
RHS" (`.claude/rules/prologos-syntax.md` § Relational syntax). The LET track
landed 2026-07-31 (`5e16ead4`) adding a new binding form, and the implicit-solve
scope never grew to cover its binding RHS.

**Ruling (R6): `let` binding RHS JOINS the implicit-solve scope.** The standing
purity concern recorded in `prologos-syntax.md` is about *general expression
position* — a goal inside a `defn` body would make ordinary calls re-query the
ambient fact store. A `let` binding RHS is not that: it is a **binding** RHS,
evaluated once at the binding site, exactly like `def`'s. `def` and `let` are the
same act at two scopes, and the LET track's own funnel makes that structural
(everything desugars to `((fn (name : T) body) value)` — the RHS is the
*argument*, evaluated once). Refusing here would mean `def x := (goal …)` works
and `let x := (goal …)` doesn't, for no reason a user can predict.

The scope stays **binding RHS**, not `let` bodies — a goal in a body is general
expression position and keeps the existing (non-goal) reading.

### 4.1 Realization — why a sentinel, and not the existing mark

Goal-ness is carried by the reader's `'prologos-paren-origin` **syntax
property**. `let` desugars in a **preparse macro** (`macros.rkt` `expand-let`),
and preparse macros receive fully **stripped datums** — verified by instrumenting
`expand-let`'s entry, where every element arrives with `syntax? = #f`. So by the
time any `let` code could look, the property is gone. `def` dodges this by
threading its RHS syntax through the `:=` rewrite (`def-rhs-stx`); `let` has five
spellings, so the same threading would mean five hooks into machinery that landed
the same day.

The property's whole information content here is **one bit** — "this value was
written in parens" — so it is preserved in the DATUM, where stripping cannot
reach it, as a `$goal-rhs` sentinel (the same idiom as the existing `$let-block`).
The **reader** owns POSITION + PARENS; the **parser** owns the KEYWORD TABLE and
therefore goal-ness. Neither needs the other's table, so nothing can drift — the
F1b.7g concern. Registered in `macros.rkt`'s pattern-variable exclusion list
alongside the other sentinels (the LOUD-if-missed class).

The position rule mirrors **POL.9b's own**: only a value that is a **single
element** after `:=` (or the second of a bare `name VALUE` pair) qualifies; a
multi-token RHS stays the auto-wrapped application. That is not a nicety — the
first cut wrapped every non-body paren child, which wrapped the ARGUMENT of the
explicit spelling `let ls := solve (goal …)` and produced a **double solve**
(`(solve @[…]) : _`). Caught by acceptance marker 23, which is why the file pins
the explicit spelling next to the implicit one.

### 4.2 The guided diagnostic — the INVERSE of POL.9's

`relations.rkt`'s `raise-unknown-relation-error` already guides the
goal-over-a-function case: `(dbl 3)` → *"dbl is a function — application is
written `[dbl …]`"*. The **mirror image had no diagnostic at all**: APPLYING a
relation surfaced whatever its arguments did — for the common `[fc f "red"]`
shape a bare **`Unbound variable f`**, naming the query variable rather than the
mistake (`f` is unbound precisely *because* this should have been a goal); the
all-ground `[fc "a" "red"]` instead reached typing and said *"Could not infer
type"*. Two unhelpful messages for one mistake.

Both now produce one message naming the fix. Deliberately **not** scoped to
`let` — `def n := [f (fc x "red")]` and top level produce the identical bare
error, because the cause is the same (a relation in application position). R6
keeps the implicit solve to binding RHS, so argument position stays an error;
this makes it an error that says what to do.

**Two guards, both load-bearing, one found by regression:**
- **Local shadowing** — `[fn [fc] [fc 1]]`: inside that scope `fc` is an
  ordinary parameter. Guarded by an `env-lookup` check before the diagnostic.
- **Namespace + rebinding** — the first cut consulted the relation STORE and
  matched any key ending `::fc`. The store is **not namespace-scoped**, so a
  relation `m` in one namespace mis-diagnosed four unrelated Batch-C tests whose
  `def m := {…}` had nothing to do with relations. Fixed by testing the **global
  env** value for `expr-defr?` instead — the same test `raise-unknown-relation-error`
  uses. Going through the env makes namespace- *and* rebinding-correctness
  structural rather than checked. Both are test-pinned.

## 5. Files

- `racket/prologos/typing-core.rkt` — `solve-row-type`, `display-row-type-parts`, `display-result-rows`
- `racket/prologos/qtt.rkt` — the `inferQ` twins
- `racket/prologos/reduction.rkt` — `answers->champ-list` + wrappers
- `racket/prologos/driver.rkt` — `pp-solve-echo-ordered`
- `racket/prologos/preparse.rkt` / `macros.rkt` — the implicit-solve scope (P2)
- `racket/prologos/examples/2026-07-31-solve-carrier.prologos` — acceptance file
- `racket/prologos/tests/test-solve-carrier.rkt` — the track's test file
