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
record `docs/tracking/2026-10-13_TAGGED_CELL_DOMAIN_MERGES_M1.md`. **Placed in PAR 4**
(owner, 2026-10-13): F3 and M2 go into PAR 4's early phases; input note written to main's
`docs/tracking/tracks/PAR/PAR_4/2026-10-13_PAR_4_P0_DOMAIN_MERGE_LAWS_NOTE.md` (untracked
there, with the main tree's other PAR 4 files). It also bears on
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

## 146 ✅ `champ-lookup` "allocates 64 B per read" — misattributed; the real class fixed — `69f64caf` (+ two transient defects the tests found: `6d172922`, `3a152ac9`)

**The entry's diagnosis is refuted.** Measured by subtraction (`champ-lookup-alloc.rkt`):

| | B/op | ns/op |
|---|---|---|
| census harness, empty thunk | 0 | 3.6 |
| `champ-lookup`, **stored** key, N = 16 / 256 / 4096 | **0** | 9 / 19 / 30 |
| `champ-lookup`, **fresh** `equal?` key | 64 | 37 / 47 / 57 |
| `equal?` on two fresh `cell-id`s alone | **64** | 35 |

The census probe looked up a freshly constructed `(cell-id k)`, so it measured Racket CS's
`equal?` on two records. That allocates on every top-level call: `rumble/equal.ss`, record
branch, `deeper-context` box plus a recursion closure (read at `master`). Measured at 64 B for transparent,
prefab, authentic, custom `prop:equal+hash` and opaque structs alike; fixnums cost 0 B. The
entry's fix shape (rewrite the descent) would have changed nothing.

**What production actually pays.** Census from a temporary instrumented build over `benchmarks/comparative` (19 files, six
data-entry comparison sites; `champ_census_instrument.py`, reverted after the run):

| class | comparisons | share | bytes in `equal?` |
|---|---|---|---|
| `eq?` hit | 238,859 | 76.3 % | 0 |
| hashes differ (cannot be equal) | 63,127 | 20.2 % | 7.09 MB (85 %) |
| same hash, equal (fresh key) | 11,021 | 3.5 % | 1.24 MB |
| same hash, unequal | 0 | 0 | 0 |

Class 1 is almost entirely **insert of a new key onto another key's data entry**. In proportion, all of these
bytes are 0.04–0.25 % of a run's total allocation (1.25–1.46 GB per file, mostly loading). The fix is correct
but its effect is small.

**Fix.** One helper, `de-key=?`: `eq?`, then the **stored hash** (data entries already carry it), then
`equal?`. It is used at all six data-entry sites. This is sound because CHAMP already requires the hash to be consistent with
`equal?`; every production hash was checked (`equal-hash-code` ×121, `cell-id`/`prop-id` n, `eq-hash-code`
of gensyms, `decomp-key-hash`). Before/after (`champ-ab.rkt`, `ROOT=` main vs branch, interleaved twice,
bytes deterministic; wall not claimed at load 7.9):

| pattern | N = 256 | 4096 | 65536 |
|---|---|---|---|
| insert new `cell-id` | 500.4 → 492.4 B | 826.2 → 809.7 | 1180.3 → 1147.2 |
| lookup, stored key | 0.1 → 0.1 | 0.1 → 0.1 | 0.1 → 0.1 |
| lookup, fresh key | 64.2 → 64.2 | 64.2 → 64.2 | 64.2 → 64.2 |

The entry's criterion, "0 B for N ∈ {16, 256, 4096}", **already held** for production-shaped
reads (stored key). For fresh keys it cannot be met inside CHAMP: that cost is the runtime's, and it is removable only
upstream, by interning keys or by not re-constructing them.

**Found along the way (separate commits, each pinned to fail without its fix):** the new rackcheck model property
(owner-ID transient vs an `equal?`-keyed hash) found two latent transient defects.
1. `tchamp-delete-owned!` returned `#f` at the root when the last key was deleted, after which freeze or insert
   crashed (`6d172922`).
2. `tnode-insert!` / `tnode-delete!` on a collision node didn't update the size box (`3a152ac9`).

Both are latent: the first has no production caller, and the second needs full-hash collisions, which are impossible for `cell-id` keys.

**Corrections owed to PAR 4.** Stage-1 contention analysis `:95, :184`; synthesis of record `:100`;
prior-art draft `:189`. The "allocation per read" half of the persistence argument is withdrawn; the write
half (path copy) stands. Written into PAR 4's note §7a; the edit to the synthesis of record is left unapplied.

**Candidate (unnumbered):** the residual class 2 (fresh-but-equal hits, 3.5 %, 112 B each in production).
Find which callers re-construct keys (`decomp-key-hash` pair keys are a suspect: a fresh `cons` of two
`cell-id`s pays the pair box plus two record comparisons). The fix shape is to pass the stored key, or to intern.

**Paste-ready status flip for main's `DEFERRED.md` § 146** (`⬜` → `✅`, append):

> **✅ Closed 2026-10-13, `69f64caf` on `deferred-sweep-146-149`.** Misattributed: the descent allocates
> 0 B; the 64 B was Racket CS `equal?` on the probe's freshly constructed key. Production census: 76 %
> `eq?` hits; the real cost was new-key inserts comparing keys whose hashes already differed (85 % of
> CHAMP's `equal?` bytes, 0.04–0.25 % of total allocation). Fixed by comparing the stored hash first at all
> six data-entry sites. The model property also found and fixed two latent transient defects (`6d172922`,
> `3a152ac9`). Record: merge note § 146.

## 147 ✅ the fire protocol's ceremony — re-attributed; the light fire is under 1 KB — `63d8f6af`

**Baseline re-derived** with the corrected `census.rkt` (which now takes the tree by `@ROOT@` substitution).
Bytes are deterministic and reproduced across interleaved runs:

| per fire (slope 8→64) | main | branch before 147 (146 + 148) | after 147 |
|---|---|---|---|
| read-only fire | 1 386 B | 1 313 B | **928 B** |
| read+write fire | 2 819 B | 2 746 B | **2 232 B** |
| `net-cell-write`, 0 / 1 / 8 deps | 481 / 529 / 801 | 481 / 529 / 801 | 416 / 513 / 785 |

The main row reproduces the entry's numbers exactly, so the per-fire figures were never affected by
146's fresh-key artefact: fire workloads look up the stored `cell-id`. 146 nonetheless took **70 of the
73 B** off every fire, through the worklist dedup's CHAMP inserts of `prop-id`s. That was measured at
`3a152ac9`, which has 148 and the transient fixes but not 146: 1 383 B, against 1 313 B with 146. The
other 3 B are 148's. The "before 147" column was re-measured on a clean worktree at `bca1f47f`, twice.

**The entry's attribution was partly wrong.** Measured piece by piece on the real network
(`fire-attrib.rkt`, `fire-attrib2.rkt`). The components below are measured; the remainders are subtraction:

| per read-only fire, before 147 (1 313 B, census slope) | B |
|---|---|
| `fire-and-collect-writes`, whole | 641 |
| ⤷ `parameterize`, as nested in production (2 bindings at `:2863`, then 1 in `fire-propagator :374`) | **496** |
| ⤷ `output-set` `for/hasheq` (the entry's headline site) | 32 |
| ⤷ `champ-diff` of identical cell maps | 32 |
| ⤷ remainder (`fire-result`, lists) | ~81 |
| `sequential-fire-all` overhead beyond the fire | ~39 |
| round machinery (1 313 − 680) | ~633 |
| ⤷ worklist dedup (`dedup-pids`: a persistent-CHAMP insert per pid; 130 / 362 / 367 B per pid at N = 8 / 64 / 512) | **~362** |
| ⤷ remainder (worklist and round bookkeeping, not attributed further) | ~270 |
| the two `champ-fold`s (`:2041`/`:2053`) | 64 per **write**, not per fire; flat in fan-out (32 B per `node-fold` call) |

The fix took 385 B off the read-only fire. The dedup (362 → 69 B per pid at N = 64) and `output-set` (32 B)
together predict 325 B. The other ~60 B were not attributed (the dedup probe's worklist carries duplicates;
the census's does not).

**Fixes (local; the BSP loop structure is untouched):**
1. `dedup-pids` uses a call-local mutable `hasheqv` keyed by `prop-id-n`. It is the same relation, since `prop-id` is one
   field, and first-occurrence order is kept. Cost is 65–90 B per pid.
2. `output-set` is replaced by `memq` over `output-cids`. It is the same `eq?` relation and allocates nothing.
3. One fold computes both dependent flags as fixnum bits, and it is skipped when there are no dependents. With dependents it
   saved 16 B, not the 32 B a removed fold call predicted. The residual is not in `bitwise-ior` (measured 0 B) and
   was not chased further.

**Not done, and why: the largest remaining item belongs to PAR 4.** The two `parameterize` forms are about
496 B, more than half of the remaining 928 B. Measured alternatives:
- one form with 3 bindings: 448 B;
- one composite parameter holding a 3-field struct: 144 B;
- a bare continuation mark: 0 B.

The three parameters (`current-bsp-fire-round?`, `current-cell-id-namespace`, `current-source-loc`) are the
**ambient state read by S0 fires** that the Q1 audit's §6 hands to PAR 4: parameters are inherited by executor
threads from their creator. How fire context reaches a fire is a PAR 4 H-S decision. A sweep patch
changing the parameter interface would pre-empt it. Recorded in PAR 4's note §7b.

**Tests.** The new `tests/test-bsp-fire-protocol.rkt` (5) holds:
- a dedup property (fresh `prop-id`s against `remove-duplicates` by `n`, with each kept element `eq?` to its first occurrence);
- a propagator enqueued twice fires once;
- two writers of one declared output are both merged;
- no-dependents and plain-dependents enqueueing.

Mutation check (`mutate147.sh`):
- M1 (no dedup) and M2 (declared outputs misclassified as undeclared) each turn the new file red.
- M3 (both flags forced to 0) passes the new file, but turns **existing** `test-ppn-track4` and `test-branch-pu` red.
  So the merged fold was already guarded by suites that can fail.

Full suite at `bca1f47f` + the change: **10 275 tests, 490/490, all pass**, 104.6 s at load 11–12. The
first gate attempt never ran: the runner's re-run guard counted the mutation check's targeted runs, printed
`GUARD: No .rkt files changed…` and exited 0. It was re-run with `--force-rerun`. The runner's
history has no earlier full row for this worktree, so the 490 files are known to include the new one
(5 tests), but the delta against 146's gate is not recorded.

**Paste-ready status flip for main's `DEFERRED.md` § 147** (`⬜` → `✅`, append):

> **✅ Closed 2026-10-13, `63d8f6af` on `deferred-sweep-146-149`.** Light fire 1 386 → 928 B (main →
> branch; read+write 2 819 → 2 232 B). Re-attributed: the dominant items were `parameterize` ×2 (~496 B) and
> the worklist dedup's persistent-set inserts (~350 B), not the `output-set` (32 B). Fixed locally: the dedup uses
> a mutable `hasheqv`, `output-set` becomes `memq`, and the dependent folds are merged and skipped with no dependents.
> `parameterize` is left to PAR 4 H-S (fire context is ambient state, per the Q1 audit §6). Record: merge note § 147.

## 149 ⬜ WATCHING: `test-transducer-01.rkt` 1.35× slower under 9.3

(pending)

---

## Close-out (fill when all four are done)

- Full suite: —
- Four before/after numbers in one table: —
