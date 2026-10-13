# Merge note — DEFERRED sweep 146–149 (branch `deferred-sweep-146-149`)

Base `7a0116ec` (main HEAD at worktree creation, 2026-10-12). Written at `c62cd267`.
Racket 9.3 (`/Applications/Racket v9.3/bin/racket`), load 3.5–4.3 during all timings
(other sessions on the machine; ratios, not absolutes, are the evidence).

Order worked: 148 → 146 → 147 → 149 (per the handoff). One commit per item. Each section
carries the measured before/after, the paste-ready `DEFERRED.md` status flip (main's file,
owner-applied or applied here after a rebase once main's tracking docs are committed), and
any candidate for the owner's register — **unnumbered on purpose**: the branch's register
reads `NEXT FREE: 146` while main's uncommitted one reads 150, so allocating here would
re-issue a number (`workflow.md` § DEFERRED numbers are monotonic).

---

## 148 ✅ `tagged-cell-value` never deduplicated entries — `c62cd267`

**What it was.** `entries` is semantically a set of `(bitmask . value)` pairs under
inclusion, join = union. It was represented with `cons`/`append`, the sequence monoid:
associative but not idempotent, so `x ⊔ x ≠ x` on the representation. Two consequences, not
one: unbounded growth under re-writes, and — because the fire protocol diffs raw values with
`equal?` (`propagator.rkt:2881`, `:2900`) — every dependent re-scheduled on a write that
carried no information.

**What changed.** One semantic authority in `decision-cell.rkt` after the struct:
`entry-member?` (bitmask `eqv?`, value `equal?`), `entries-add`, `entries-union`
(newer-first among genuinely new entries). Every operation returns its input list `eq?` when
nothing is new; `make-tagged-merge` returns `old` itself when neither base nor entries
changed. Three sites: `tagged-cell-write`, `tagged-cell-merge`, `make-tagged-merge`.

**Correction to the entry.** It named `:453` and `:465`. Those functions have **no production
callers**; the live path is `net-cell-write` → `(make-tagged-merge domain-merge)`
(`propagator.rkt:1810`, `elaborator-network.rkt:143`, `relations.rkt:2958`,
`compound-tagged-merge`), i.e. the `append` at `:492`, which is where the PAR 4 heap baseline
leaked. All three are fixed through the one helper. The stale comment at `:489-491` ("first
match at max specificity wins") is corrected: the D.12 reader joins every match; the compat
reader (no domain-merge) returns the **oldest** match (`tagged-cell-read` conses
`all-matching` then takes `car`).

**Semantics: a pure refinement**, pinned by a rackcheck property against the old append-based
union on both reader paths (300 cases, duplicate-carrying inputs). The D.12 join-reader is
order-insensitive by commutativity + idempotence of the domain join; the compat reader's
oldest match lives in `old`'s tail in both forms, and `new`'s matches survive the union
exactly when `old` has none.

**Measured** — probe `scripts/tagged-dedup.rkt` in the `racket-performance-probing` skill
(`DC=<decision-cell.rkt> ROUNDS=… racket tagged-dedup.rkt`; before = main's file, after =
this branch's; same probe file both legs).

| workload | metric | before | after |
|---|---|---|---|
| W2 pure re-write: same `(bm . v)` ×10 000 through `make-tagged-merge` | entries | 10 000 | **1** |
| | B/write | 48 | **0** |
| W1 PAR 4 heap workload (`arena-tagged.rkt:150-169`; C=16384 P=16 F=1024), 100 rounds | entries max / mean | 100 / 87.5 | 84 / 62.8 |
| | ns/fire | 1 512 | 1 364 |
| | B/fire | 619 | 477 |
| W1, 30 rounds | entries max / ns/fire | 30 / 472 | 30 / 375 |

W2 is the entry's success criterion ("idempotent re-write leaves `(length entries)`
unchanged") in measured form: closed. W1 still grows, and that is the finding below, not a
defect in the fix.

**Finding (for the owner).** W1 writes `v = 1 + max(neighbours)` — a strictly **ascending
chain** at each bitmask, so successive entries are distinct pairs, not duplicates. A set of
pairs bounds re-writes; it cannot bound a chain. The representation that would is the
**bitmask-keyed map with pointwise join**, `(bm . v₁) ⊔ (bm . v₂) = (bm . v₁ ⊔ v₂)` (the
standard LVar map-lattice construction), bounded by the number of distinct bitmasks. That is a
different lattice, not a sweep item: it needs the domain merge at the union site (only
`make-tagged-merge` has it), and it changes the compat reader's result from "oldest write at
that bitmask" to "join of all writes at that bitmask" at `meta-universe.rkt:280`,
`propagator.rkt:4367`, `metavar-store.rkt:504`. `relations.rkt:2901` already does this join
by bitmask *on read* for scope cells (fact rows write `x` and `y` separately at the same
bitmask) — evidence of intent, but **not** of soundness: it folds with `scope-cell-merge`,
which is per-variable last-writer-wins (`decision-cell.rkt:938`, not commutative) over hash
iteration order. *Correction (2026-10-13, tradeoff analysis):* the keyed form preserves the
denotation only when the domain merge is a genuine join (ACI); at least two production
domain merges are not (`scope-cell-merge`; the `promote-cell-to-tagged` default
`(lambda (o n) n)`, `propagator.rkt:1809`), and the three compat readers already disagree
with the main reader (`propagator.rkt:1616`, which joins) independently of 148. So the size
question is downstream of a correctness one; options A–E and the discriminating
measurements are in the session's analysis, to be folded into whichever design doc takes
the decision. **M1 measured (2026-10-13)**: 2 of 7 production domain merges are joins;
record `docs/tracking/2026-10-13_TAGGED_CELL_DOMAIN_MERGES_M1.md`. It also bears on
**PAR 4 D.1 §6.1**: the flat record "dedups on append by construction" — pair-dedup, the same
limitation — so its `E`-entry capacity overflows under the same chain (the arena probe's
`overflow` counter is the tell).

> **DEFERRED candidate (unnumbered)** — `tagged-cell-value` entries as a bitmask-keyed map
> with pointwise domain join, bounding entries by distinct bitmasks instead of distinct
> pairs. Sites: `decision-cell.rkt` `entries-union` (needs `domain-merge` threaded in;
> `tagged-cell-write`/`tagged-cell-merge` have none), the three compat readers above (result
> changes from oldest to join — decide whether that is the intended monotone reading), and
> `relations.rkt:2901` (its read-side pre-merge becomes redundant). Evidence: W1 above; PAR 4
> D.1 §6.1 capacity. When: at PAR 4 Stage 3 D.2, since the flat record must pick the same
> lattice.

**Not reproduced.** The entry's "heap baseline failed to finish 100 rounds in 300 s" does
not reproduce on the data-structure-only workload: 2.5 s at 100 rounds before the fix.
Whatever produced 300 s was not this leak alone; cause not established, not claimed.

**Tests.** `tests/test-tagged-cell-value.rkt` +12 (7 pins, 5 rackcheck properties). 10 were
RED before the fix; the two that passed are the two that must — "distinct value at the same
bitmask is a new entry" and the refinement conservation law. Targeted runs green:
`test-tagged-cell-value`, `test-solver-context`, `test-mult-propagator`, `test-branch-pu`,
`test-multiclause-debug`, `test-speculation-bridge`, `test-union-types-atms`,
`test-union-types`, `test-relations-runtime`.

**Paste-ready status flip for main's `DEFERRED.md` § 148** (heading `⬜` → `✅`, then
append):

> **✅ Closed 2026-10-13, `c62cd267` on `deferred-sweep-146-149`.** Set semantics on all
> three sites via one helper (`entries-union`); the live site was `make-tagged-merge:492`,
> not `:453`/`:465` (no production callers). Pure refinement, pinned by a rackcheck property
> against the old append on both reader paths. W2 re-write ×10 000: entries 10 000 → 1.
> The PAR 4 heap workload still grows (100 → 84 entries at 100 rounds) because it is an
> ascending chain per bitmask, not duplicates — see the keyed-map candidate filed alongside.
> Record: `docs/tracking/handoffs/2026-10-13_DEFERRED_SWEEP_146-149_MERGE_NOTE.md` § 148.

**Proposed PAR 4 LOG entry** (`docs/tracking/tracks/PAR/PAR_4/LOG.md`, uncommitted on main;
sparse pointer form):

> ### DEFERRED 148 closed on the sweep branch; pair-dedup does not bound the heap baseline's chain — `c62cd267` (2026-10-13)
> **Why / decision**: the heap baseline's growth was two things — duplicates (closed) and an
> ascending chain per bitmask (not closable by any set-of-pairs form, flat or heap). D.1 §6.1's
> flat record inherits the second; D.2 should pick the lattice (pairs vs bitmask-keyed join)
> deliberately. **Surprise / correction**: the entry's cited sites were dead code; the live
> site was the third. The "300 s" figure does not reproduce (2.5 s). **Next**: 146.

---

## 146 ⬜ `champ-lookup` allocates 64 B per read

(pending)

## 147 ⬜ fire-protocol ceremony

(pending)

## 149 ⬜ WATCHING: `test-transducer-01.rkt` 1.35× slower under 9.3

(pending)

---

## Close-out (fill when all four are done)

- Full suite: —
- Four before/after numbers in one table: —
