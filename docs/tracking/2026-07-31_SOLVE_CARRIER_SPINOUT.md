# Rel/CIU seam spin-out — the SOLVE CARRIER: `List` → `PVec`

**Status**: 🔄 in progress · **Opened** 2026-07-31 · **Base HEAD** `cab30b9a` ·
**Branch** `focused-morse-3454bf`

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
| P1 | Carrier flip: typing + runtime + display walkers + consumers | ✅ | `2b34dbf7` |
| P2 | `let` implicit-solve gap + guided diagnostic | ✅ | `f2fd9d9d` |
| X.close | Full-suite gate, roadmap, D4 §Q_U9 back-note | ✅ | `8d0e3d38` |

## 1. The seam — VERIFIED at `cab30b9a`

The opening note called this "two lines". The census found **six** production
sites; the three display walkers were the capture gap.

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

## 2. Consumer census (at HEAD, via `git grep … HEAD`, not the dirty tree)

**`.prologos` corpus** — 2 live sites pipe a solve-bound name into a
List-monomorphic HOF (`spec map [A -> B] [List A] -> List B`,
`lib/prologos/data/list.prologos:46`), both in
`examples/2026-07-26-ciu-t6-path-selection.prologos`:

- `:234` `map [fn [q] q.r] quests` (bound at `:224` `def quests := solve (quest t g r)`)
- `:246` `map [fn [q] q.t] alice-quests` (bound at `:243` by an *implicit* solve)

Both become `pvec-map` — a **native AST primitive** (parser keyword, reduces via
`rrb-fold`), so this is an improvement, not a workaround: no List round-trip.
Their `;;NN=>` acceptance markers move with them. Every other `.prologos` solve
site is a bare top-level echo with no downstream List consumption.

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

## 5. Files

- `racket/prologos/typing-core.rkt` — `solve-row-type`, `display-row-type-parts`, `display-result-rows`
- `racket/prologos/qtt.rkt` — the `inferQ` twins
- `racket/prologos/reduction.rkt` — `answers->champ-list` + wrappers
- `racket/prologos/driver.rkt` — `pp-solve-echo-ordered`
- `racket/prologos/preparse.rkt` / `macros.rkt` — the implicit-solve scope (P2)
- `racket/prologos/examples/2026-07-31-solve-carrier.prologos` — acceptance file
- `racket/prologos/tests/test-solve-carrier.rkt` — the track's test file
