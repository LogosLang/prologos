# Broadcast over Any Collection — Trait-Dispatched `:` (Implementation Note / Track Seed)

**Status**: Implementation note — **seed arming CIU Track 4 (with Track 1 as prerequisite)**. NOT a new track proposal: both tracks already exist in the CIU master and already charter this work. NOT Stage-1. Read-only grounding; no code touched.
**Date**: 2026-07-31
**Series**: CIU ([`2026-03-21_CIU_MASTER.md`](2026-03-21_CIU_MASTER.md)) → **Track 1** (Seq Protocol) + **Track 4** (Trait-Dispatched Iteration)
**Forcing example**: CIU Track 6 D4 **Q_U9** — `:` refuses over `List` ([`2026-07-28_CIU_T6_PATH_SELECTION_D4.md`](2026-07-28_CIU_T6_PATH_SELECTION_D4.md) §3, the P4-PAUSE block)
**Grounding basis**: main-session probes + census at HEAD `711a9bde`, during the D4.P4 re-grounding. All coordinates cited at that HEAD — **they drift; re-verify before implementing.**

---

## §1 Why this note exists

CIU T6 D4 ruled **Q_U9** (owner, 2026-07-31): the path-selection broadcast operator `:` **refuses over `List`**, because `List` is a user-space inductive with no native carrier and the key-sort thesis does not reach a cons-spine. The refusal is monotone and correct for v1 — but it is a *carrier-class* boundary, and a carrier-class boundary is the wrong long-term shape for an operator whose whole job is "map a selector over a container."

The principled boundary is a **trait** one: `:` should traverse anything that *offers* traversal, and refuse anything that does not — with the refusal naming the missing instance rather than naming the type.

This note records what already exists, what is stale in the existing charters, and what the smallest honest first increment is.

## §2 The tracks already exist — do not re-charter

⚠ **This is the third prior-art miss of the D4.P4 arc** (see `MEMORY.md` § "Prior-art search before claiming new pattern"; the PPN 4C Galois-bridge instance was the first). During the Q_U9 dialogue I described trait-dispatched broadcast as "a real feature, and a much larger one than P4d." Both halves were wrong in the same direction: the trait vocabulary is **already declared with laws**, and the dispatch work is **already chartered in two CIU tracks**, written 2026-03-21.

**CIU Track 4 — Trait-Dispatched Iteration** (`⬜ Pending`, prereq: Track 8 + Tracks 1 and 3) already states, verbatim:

> **Broadcast via Seq**: `surf-broadcast-get` generates `Seq C` constraint on the target collection. Broadcast iterates via resolved `seq-first`/`seq-rest`/`seq-empty?` — **any collection, not just cons/nil lists.**
> **Result type preservation**: `Buildable` constraint on output. **PVec broadcast → PVec; List broadcast → List.**
> **User extension**: Any type implementing `Seq` automatically gets broadcast and gmap participation.

That is Q_U9's door, described four months before Q_U9 was asked.

**CIU Track 1 — Seq Protocol** (`⬜ Pending`) is its prerequisite and already states:

> Implement native `Seq` instances for List, PVec, Set, Map with efficient dispatch […]
> **Extend `Functor` instances beyond List (PVec, Map, Option, Result)**

## §3 The three grounded findings

### F1 — The higher-kinded trait vocabulary is DECLARED WITH LAWS and has ZERO live instances

`lib/prologos/core/collection-traits.prologos` declares **eight** higher-kinded traits — `Seqable` (:41), `Buildable` (:58), `Foldable` (:72), `Reducible` (:85), `Functor` (:97), `Indexed` (:147), `Keyed` (:163), `Setlike` (:177) — duplicated in `lib/prologos/book/collection-traits.prologos`. `Functor` carries its laws inline:

```prologos
trait Functor {F : Type -> Type}
  fmap : [Pi [A :0 <Type>] [Pi [B :0 <Type>] [-> [-> A B] [-> [F A] [F B]]]]]
  :laws
    - :name "identity"      :holds [eq? [fmap id xs] xs]
    - :name "composition"   :holds [eq? [fmap [compose f g] xs] [fmap f [fmap g xs]]]
```

`grep 'impl Functor|impl Foldable|impl Seqable|impl Buildable|impl Reducible|impl Indexed|impl Keyed|impl Setlike'` across the whole tree returns **zero live hits**. The only three mentions are **commented aspirations** in `examples/2026-03-21-track8-acceptance.prologos:54-55,71` (`;; impl Indexed PVec ;; Indexed is a HKT trait`).

**So the work is "inhabit a designed-but-uninhabited surface," not "design a surface."** The laws are already written and are directly usable as the instance test battery.

### F2 — Track 1's own premise is STALE: List has no `Functor` instance either

Track 1 says "**Extend** `Functor` instances **beyond List**," which presumes a `Functor List` exists. Per F1, none does. `map` over List is **monomorphic**:

```prologos
spec map [A -> B] [List A] -> List B      ;; lib/prologos/data/list.prologos:46
defn map [f xs]
  match xs
    | nil       -> nil
    | cons a as -> cons [f a] [map f as]
```

The first instance is therefore net-new, not an extension. This matters for sequencing: Track 1's opening increment is `impl Functor List` + `impl Functor PVec` and the law battery, and it can land **without** Track 4.

### F3 — Track 4's stated MECHANISM is written against a node that no longer exists

Track 4 says broadcast dispatch hangs off `surf-broadcast-get`. That node was **retired at CIU T6 D4.P1a** (ruling Q_L3, the full chain: reader token + parser keyword + surf struct + elaborator arm + `expr-broadcast-get`). It was First-Class Paths Phase 7b's `.*name` operator.

Its replacement is the D4.P4 surface: the `:` operator, minted as the `$bcast-step` grouping sentinel (Q_U8) and represented as the one-step wrapper **`(@bcast step)`** (Q_U7) inside the unified selector carrier (Q_U5). So Track 4 must be **re-pointed**, and the re-pointing is an improvement rather than a cost:

- Broadcast is now a *step kind in a closed union* consumed by ONE shared walk (`select-step-kind`, minted at D4.P4a as a totality dispatcher). A trait-dispatched carrier lookup has exactly one site to live at, per walk, instead of a bespoke node's own pipeline.
- The **carrier-dispatch seam Q_U9 creates is literally the dispatch site**: P4c's PVec arm, P4d's map-generic/het-tuple/PVec-of-union arms, and P4d's List *refusal* are five hand-written arms of what Track 4 would make one `Seq`/`Functor` resolution.
- Track 4's "PVec broadcast → PVec; List broadcast → List" is precisely the `Buildable` answer to Q_U9 — shape preservation per carrier, which is also what spec §3.1 demands ("each ω step contributes the shape of the container it traversed").

## §4 The smallest honest first increment

Ordered so each step is independently valuable and none blocks D4:

1. **`impl Functor List` + `impl Functor PVec`, with the declared laws as the test battery** (Track 1). Net-new per F2. No compiler change; library-level. Immediately makes the Q_U9 refusal's error message *true* in the strong sense — "`List` has no `Functor` instance" stops being a description of our implementation and starts being a checkable fact about the program.
2. **`impl Seqable`/`Buildable` for List, PVec, Map, Set** (Track 1), with the efficient dispatch the charter already specifies (`Seq PVec`: `first` = rrb-get 0, `rest` = rrb-drop 1, `empty?` = rrb-count = 0).
3. **Re-point Track 4 at `:`** (this note's F3): replace the `surf-broadcast-get` mechanism text with the `(@bcast step)` / shared-walk one, and state the dispatch site as the totality dispatcher's ω arm.
4. **Route the ω arm through the resolved instance** (Track 4), collapsing D4.P4's hand-written carrier arms into one resolution + `Buildable` output shaping. Q_U9's refusal becomes an *instance-missing* diagnostic automatically.

**Step 1 alone discharges the honesty debt** in Q_U9's guided error and is a genuinely small piece of work.

## §5 What this does NOT claim

- **It does not reopen Q_U9.** The refusal stands for v1 on its own merits (no native carrier; the key-sort thesis does not reach a cons-spine; the remedy `pvec-from-list` is one primitive and preserves the row type — probe-verified at 0 errors). This note is the door, not a challenge to the wall.
- **It does not block D4.P4.** Nothing in P4a–P4e depends on any of this. The hand-written carrier arms are the correct v1 shape; Track 4 later *collapses* them rather than replacing work that shouldn't have been done.
- **It does not resolve the `solve` carrier question.** That is upstream and independent: `solve-*`/`explain-*` should return `PVec` regardless of trait dispatch, because solve results are finite, ordered, indexed, bag-semantic collections. Spun out as its own mini-track (seam: `solve-row-type`'s `'list` arm `typing-core.rkt:4338` + `racket-list->prologos-list` `reduction.rkt:905`).
- **The prerequisite chain is real**: Track 4's charter lists Track 8 + Tracks 1 and 3. Track 8 is DELIVERED (HKT `impl` registration + resolution, per the master's Cross-Series table). Track 3 was RE-CHARTERED when T6 took its surface half. Track 1 is the live blocker and step 1 above is its opening.

## §6 Principles bearing

The CIU master's own Principles table already names the violations this closes:

| Principle | Master's stated status | What §4 changes |
|---|---|---|
| Traits over concrete types | **VIOLATED** — "`Foldable` works, `Indexed` doesn't" | F1 sharpens this: *no* HK trait has an instance, so none of them "work" |
| Open extension, closed verification | **VIOLATED** — new collections require modifying `reduction.rkt` | Step 4 is exactly this: a user type implementing `Seq` gets `:` for free |
| Most Generalizable Interface | **VIOLATED** — sugar bypasses traits | `:` is the sugar; step 4 routes it through the trait |

## §7 References

- CIU master: [`2026-03-21_CIU_MASTER.md`](2026-03-21_CIU_MASTER.md) § Track 1, § Track 4, § Principles at Stake
- Q_U9 + the P4 pause rulings: [`2026-07-28_CIU_T6_PATH_SELECTION_D4.md`](2026-07-28_CIU_T6_PATH_SELECTION_D4.md) §3, §5.P4
- The spec's shape/grade story: [`../research/2026-07-28_path-selection-spec.md`](../research/2026-07-28_path-selection-spec.md) §3.1–§3.2, §5.2
- The retired predecessor node: [`2026-03-20_FIRST_CLASS_PATHS_DESIGN.md`](2026-03-20_FIRST_CLASS_PATHS_DESIGN.md) §3.8 (Phase 7b, `.*field`)
- Trait declarations: `racket/prologos/lib/prologos/core/collection-traits.prologos`
- The monomorphic `map`: `racket/prologos/lib/prologos/data/list.prologos:46`
