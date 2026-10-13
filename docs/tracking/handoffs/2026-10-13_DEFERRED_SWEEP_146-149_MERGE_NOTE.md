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
> the worklist dedup's persistent-set inserts (~362 B), not the `output-set` (32 B). Fixed locally: the dedup uses
> a mutable `hasheqv`, `output-set` becomes `memq`, and the dependent folds are merged and skipped with no dependents.
> `parameterize` is left to PAR 4 H-S (fire context is ambient state, per the Q1 audit §6). Record: merge note § 147.

## 149 ✅ not a Racket 9.3 regression: main's tree runs the compiler's giant `match` functions INTERPRETED (no code change on this branch)

**Under matched builds the 1.35× does not exist.** The two legs were fresh detached worktrees at `674ae09b`,
built by one script whose only difference is the binary (`PLT_CS_COMPILE_LIMIT=1000000 raco make -j 4` of
the five tests plus `driver.rkt`). The `.dep` headers confirm 9.0 and 9.3 `.zo`s. Each leg warmed its own
`.pnet` cache once.

| matched builds, 9.0 vs 9.3 | in-process, test-phase CPU (ABBA ×4 / ×2) | `raco test` wall (rotated ×3) |
|---|---|---|
| `test-transducer-01` | 1 213 / 1 242 ms (1.02×) | 4.59 / 4.63 s (1.009×) |
| `test-transducer-02` | 849 / 861 ms (1.01×) | 4.09 / 4.14 s (1.012×) |
| `test-lseq-01` | 620 / 622 ms (1.00×) | 3.84 / 3.86 s (1.005×) |
| `test-reduction-perf-01-01` | 228 / 220 ms (0.96×) | 3.25 / 3.31 s (1.018×) |
| `test-propagator-bsp` | 10 / 10 ms | — |

Load phase (instantiating the compiler and the prelude): 2 612–2 655 ms on both versions. Allocation agrees to
0.15 % (1 298.2 vs 1 300.2 MB load; 266.0 vs 265.9 MB test). **Both versions compute the same thing.** Of the 40
`.pnet` files, 36 have identical length and token multiset after normalising the tree path (they differ only
in hash-table print order). The other 4 differ in one gensym'd name, `meta5786$$1` vs `meta5791$$1`. That name
comes from Racket's process-wide `gensym` (`metavar-store.rkt:1859`), whose counter already differs by version
*before any elaboration* (2 940 under 9.0 and 2 795 under 9.3, after loading the compiler warm). The name carries no
computational signal.

**The 10-12 number reproduces exactly when the 9.3 leg is built WITHOUT `PLT_CS_COMPILE_LIMIT`** (a third
worktree, `r93nl`, built the same way except `env -u PLT_CS_COMPILE_LIMIT`):

| `raco test` wall, medians of 3 | 9.0 + limit | 9.3 + limit | 9.3, no limit | no limit ÷ 9.0 |
|---|---|---|---|---|
| `test-transducer-01` | 4.59 s | 4.63 s | **6.22 s** | **1.355×** (10-12: 1.36×, 1.35×) |
| `test-transducer-02` | 4.09 | 4.14 | 5.32 | 1.30× |
| `test-lseq-01` | 3.84 | 3.86 | 4.02 | 1.05× |
| `test-reduction-perf-01-01` | 3.25 | 3.31 | 3.27 | 1.01× |

The slowdown is file-specific because it scales with how much elaboration and reduction a file does in process.
That is the shape the dailies saw: one file at 1.35×, three at parity. Which three files were used on 10-12 was not recorded,
so whether `-02` was among them cannot be checked.

**Profiles of the test phase** (`prof149.rkt`, 1 ms sampler, `test-transducer-01`; top frames by self time):

| 9.0 + limit (1 216 ms, GC 1 027) | 9.3 + limit (1 218 ms, GC 1 025) | 9.3 no limit (2 899 ms, GC 1 191) |
|---|---|---|
| 29.4 % `measure-memory-before` | 28.6 % `measure-memory-before` | **41.8 % `f3224` `…/match/compiler.rkt`** |
| 23.4 % `measure-memory-after` | 23.4 % `measure-memory-after` | **11.1 % `whnf`** (`reduction.rkt`) |
| 10.5 % `vec-remove-insert-node` | 9.0 % `vec-remove` | 10.6 % `measure-memory-after` |
| 9.0 % `vec-remove` | 6.2 % `module-network-add-definition` | 10.1 % `measure-memory-before` |
| 4.4 % `pnet-stale?`, 4.4 % `deserialize-module-state` | 4.5 % / 4.5 % (the same two) | 2.6 % `nf`, 2.0 % / 2.0 % (the same two) |

The matched pair has the same shape: DEFERRED 152's forced major GCs make up half, and DEFERRED 151's `.pnet` reads
appear in both. Interpretation multiplies the mutator about 9× (≈193 → ≈1 708 ms non-GC), and the time lands in
`match`-generated clause code inside `whnf`/`nf`. Compiled `match` code exists in the matched builds too
(9.0: `f773 …/match/compiler.rkt` at 2.3 %; 9.3: below the top 12), so the entry's "9.2 `match`" candidate was
right about the *place* but not the cause. At 41.8 %, that code is running interpreted.

**And main's tree is in that state now.** Its `.zo`s were written 10-12 at 20:24:26–30 under 9.3. Fingerprinted
against the two builds of identical source (main has no uncommitted `.rkt`; the branch changed only `champ`,
`propagator` and `decision-cell`):
- **15 of the 15 modules whose `.zo` differs between the two builds match the NO-LIMIT build** (`elaborator macros
  parse-reader parser pretty-print qtt reduction relations sre-core substitution surface-syntax syntax
  typing-core typing-propagators zonk`). `reduction`, `typing-core`, `elaborator` and `macros` are
  **byte-identical** to it.
- **0** match the limited build. 2 match neither, because their sources or inlined dependencies differ from
  the branch: `driver`, and `propagator`. `propagator`'s main `.zo` (288 134 B) sits in the no-limit *size
  class* (288 208 B, against 256 401 B limited), so it was built in the fallback mode too. **But its hot path behaves
  as compiled.** 147's census on main's `propagator` gave 1 386 B per read-only fire, and a *limited* build at
  `3a152ac9` gave 1 383 B, whereas interpreted code allocates wildly more (no-limit cold load: 128 GB against
  1.1 GB). That fits Racket CS's fallback as I understand it (from memory of the implementation; not re-read today):
  an oversized linklet gets an interpreted *outer layer* while its nested `lambda`s below the limit are still
  compiled, so the penalty concentrates in individually giant functions such as `whnf`/`nf`/`subst`. Main's
  propagator/scheduler timings are therefore probably not materially affected; that is not measured. `champ` and
  `decision-cell` are identical under both builds, so 146's and 148's A/Bs against main's files are clean.
  85 modules are identical under both builds and carry no signal.

This is the trap `testing.md:11` describes, and it is **persistent**. The runner `putenv`s the limit, but
`raco make` never recompiles an up-to-date `.zo`, so every suite run since has used the interpreted compiler.
**Suite-level cost, measured** (full suite in the two 9.3 worktrees at `674ae09b`, ABAB): limited build
**105.9 / 105.8 s**; main's build state (no limit, then four runner suites, which leave the `.zo`s untouched,
verified after) **134.9 / 135.1 s**, i.e. **1.275×**. Both are 10 275 tests, 490/490, all pass, and the reps agree to 0.2 s across load
2.5–11.5. Per file (307 files ≥ 300 ms): median 1.15×, p75 1.40×, and the sum of per-file wall is 704 → 936 s (1.33×).
The worst files are `test-functor-ws-02` **25×** (0.6 → 15.1 s), `test-hashable-02` 12×, `test-firstclass-ops` 10× and
`test-io-csv-02` 5.5×. This accounts for the dailies' 10-12 suite figure: 130.8 s under 9.3 against 95–109 s under 9.0
("+20–37 %, the shape of noise") was this. This sweep's own tree is clean (17/17 limited): the
`PLT_CS_COMPILE_LIMIT=1000000 raco make` at 02:06 recompiled everything downstream of `propagator.rkt`. 146–148
claim bytes, not wall, and their A/Bs load only `champ`/`propagator`, which are not among the 15.

**Remedy for main (the owner's call; this session does not touch main's tree):** delete the `compiled/`
directories under `racket/prologos` (or at least the 15 modules' `.zo`/`.dep`; dependents follow by SHA), then
rebuild through the runner or with `PLT_CS_COMPILE_LIMIT=1000000 raco make -j 4 driver.rkt`. Verify by
comparing `compiled/reduction_rkt.zo` with a known limited build, or by timing `test-transducer-01` (≈4.6 s
vs ≈6.2 s under `raco test`). **Prevention** is filed as a candidate (below), because the trap's whole problem is that
it depends on someone remembering.

**Side results, recorded so nobody chases them again:**
- **`.pnet` bytes depend on process history.** `transducer.pnet` written by a process that elaborated its
  dependencies from source is 747 783 B; written over warm (`.pnet`-loaded) dependencies it is 384 910 B. After
  `(imports prologos::data::transducer …)` all 12 registries have identical counts under either file, and
  `test-transducer-01` passes with both. So the cold-written file *repeats* its dependencies' entries.
  This refines DEFERRED 151's "identical modulo gensym numbering", which holds only for files written the same way
  (paste-ready addendum below).
- The `.pnet` round-trip rebuilds every hash as `for/hasheq` (`pnet-serialize.rkt:304`, `:757`), which would
  break an `equal?`-keyed registry with pair keys, such as the subtype registry (`macros.rkt:8071`, `:8083`).
  **Probed: it does not bite.** The live reader holds an `equal?` table, cold and warm, and 104/104 self-lookups
  hit. It is latent only.
- Cold vs warm load, 9.3 + limit, `test-transducer-01`: 1 121 / 1 131 ms vs 2 702 / 2 698 ms. This independently
  reproduces DEFERRED 151's direction (the cache is a net loss).

**Probes** (preserved in the probing skill's `scripts/`): `build149.sh` (identical build per leg),
`run149.rkt` (load/test phase split), `ab149.sh` (ABBA in-process), `rt149.sh` (`raco test`, rotated legs),
`prof149.rkt` (test-phase sampler), `subreg.rkt` and `regcount.rkt` (the two `.pnet` side results).

**Paste-ready status flip for main's `DEFERRED.md` § 149** (`⬜ WATCHING` → `✅`, append):

> **✅ Closed 2026-10-13: not a 9.3 regression** (sweep branch record; no code change). Matched builds (fresh
> worktrees, same commit, same build command, only the binary differs) are at parity on five files (`raco test`
> 1.005–1.018×; allocation within 0.15 %; same `.pnet` networks). The 1.35× reproduces *exactly* (1.355×)
> when 9.3 builds without `PLT_CS_COMPILE_LIMIT`. Main's tree is in that state: 15/15 distinguishable
> giant modules match the no-limit build (4 byte-identical), written 10-12 20:24, and they persist through runner
> suites because up-to-date `.zo`s never recompile. Profile: 41.8 % in interpreted `match` clause code plus
> 13.7 % `whnf`/`nf`, against ≤ 2.3 % compiled `match` code under the matched builds. Remedy and prevention:
> DEFERRED 159. Record: merge note § 149.

**Paste-ready NEW entry for main's `DEFERRED.md`** (NEXT FREE was 159 at 02:40; renumber if it has moved):

> ### 159. ⬜ ⭐ MAIN'S TREE RUNS THE COMPILER'S GIANT `match` FUNCTIONS INTERPRETED — a 10-12 `raco make` without `PLT_CS_COMPILE_LIMIT` (the 9.0→9.3 rebuild); the runner's `putenv` cannot repair it because up-to-date `.zo`s never recompile
>
> Found by DEFERRED 149. 15 modules (`reduction`, `typing-core`, `elaborator`, `macros`, `qtt`, `zonk`,
> `substitution`, `parser`, …) match a no-limit 9.3 build of identical source, 4 byte-for-byte, and none
> matches a limited build (`propagator.rkt` was built in the same fallback mode, but its per-fire path measures as
> compiled; the penalty concentrates in the giant `whnf`/`nf`/`subst` functions). Cost: `test-transducer-01` 1.355×
> (`raco test` 6.22 vs 4.59 s); test-phase mutator ≈9×;
> full suite 1.275× (105.9 → 135.0 s; per file median 1.15×, worst 25×). Every timing taken in main since 10-12 20:24 that exercises elaboration or reduction carries it,
> including the dailies' 9.3 suite
> figure (130.8 s, attributed to load). **Remedy** (owner): remove `racket/prologos/**/compiled`, rebuild with
> the limit. **Prevention** (decision; the trap is "someone must remember"): (a) `hook-guard-racket.sh` denies
> `raco make` without `PLT_CS_COMPILE_LIMIT` in the command, which covers agents and subagents, the layer that
> guard was built for; (b) the runner fails fast when a giant module is interpreted, using a ~1 ms
> self-check (time `whnf`/`shift` on a fixed term; compiled vs interpreted is bimodal, and `testing.md:11` measured
> shift at ~830×), which covers humans and every entry point that goes through the runner. (b) alone suffices for
> correctness of the gates; (a) stops the defect being re-created. **When**: before PAR 4 pins its baseline.
> Record: sweep merge note § 149.

**Paste-ready ADDENDUM for main's `DEFERRED.md` § 151** (append):

> *Addendum 2026-10-13 (DEFERRED 149 sweep):* a module's `.pnet` bytes depend on how its dependencies were
> loaded. `transducer.pnet` written over source-elaborated dependencies is 747 783 B; written over
> `.pnet`-loaded ones it is 384 910 B. All 12 registries have equal counts after import with either file. So
> "identical modulo gensym numbering" holds only for files written the same way, and part of the 15.7 MB is
> dependencies' entries repeated. That bears on fix (b), and on any cache keyed or checked by content hash.

---

## Close-out

- **Full suite**: 10 275 tests, 490/490, all pass at `63d8f6af` (147's gate). Everything after it is
  documentation; 149 changes no code. The four 9.3 worktree suites at `674ae09b` (§ 149) also all pass.
- **The four items, before → after:**

| # | measure | before | after |
|---|---|---|---|
| 146 | `champ-lookup`, stored key (the entry's 64 B) | 0 B (misattributed: it was `equal?` on a fresh key) | 0 B |
| 146 | `champ-insert` of a new key, N = 256 / 65 536 | 500.4 / 1 180.3 B | 492.4 / 1 147.2 B |
| 147 | BSP fire, read-only / read+write (census slope) | 1 386 / 2 819 B | **928 / 2 232 B** |
| 148 | the same `(bm . v)` re-written ×10 000: entries, B/write | 10 000, 48 B | **1, 0 B** |
| 149 | `test-transducer-01`, 9.3 ÷ 9.0, matched builds | "1.35×" (10-12) | **1.009×**; the 1.35× is main's no-limit build (1.355×) |

- **For the owner, in order of urgency:**
  1. **Rebuild main's `compiled/` with the limit** (§ 149 remedy). Main's suite is 1.275× slower than it should
     be, some files 10–25×, and every elaboration timing taken there since 10-12 20:24 is inflated.
  2. Paste the DEFERRED flips 146–149, the new **159** (the trap, prevention as a decision), and the **151**
     addendum.
  3. PAR 4's note §7a (Stage-1 "allocation per read" withdrawn) and §7b (the fire-context cost table).

## Close-out addendum: applied to main (2026-10-13, owner-authorized)

- **Main rebuilt with the limit (~02:55).** The 9 `compiled/` dirs under `racket/prologos` (707 `.zo`) were
  *moved* to the agent's scratch dir `main-compiled-nolimit-20261012/` (the harness hard-blocks
  `find … -exec rm -rf`; moving is reversible, and the copy is pruned after 24 h idle). Rebuilt with
  `PLT_CS_COMPILE_LIMIT=1000000 raco make -j 8 driver.rkt lsp/server.rkt tools/run-affected-tests.rkt`
  (19 s); 8/8 reference `.zo`s are now size-identical to the limited build.

  | main, runner `fd2986cc`, `--all --force-rerun` | before | after (×2) |
  |---|---|---|
  | full suite | 69.5 s, 1 failure | **56.5 s** (all pass*), **57.1 s** (1 failure) |
  | `raco test test-transducer-01` | 6.10 s | **4.53 / 4.53 / 4.55 s** (one unexplained 2.94 s reading on the cold test tree, output not captured) |

  \* That "all pass" counted `test-generators` at 0 tests, which is DEFERRED 161. The single failures (`test-cond-01`
  before, `test-error-messages` after) each pass alone, which is DEFERRED 160. The rebuild did not cause them: one
  occurred before it. ⚠ The LSP server started before the rebuild (`lsp/server.rkt`) runs interpreted code
  until it is restarted.
- **Main's `DEFERRED.md`** (working copy, uncommitted alongside the other sessions' 150–158): 146–149 closed with
  this note's paste-ready texts (148's "filed alongside" now points at PAR 4 D.2, where the owner placed the
  keyed-map form), the 151 addendum, and **159–161 filed; register 159 → 162**. Diffed against a pre-edit copy:
  only the register line and the four headings were replaced; everything else is additions.
- **PAR 4 note § 7c** (main, untracked): what the trap means for PAR 4. `par4-p0` is clean now (8/8 limited,
  `.zo`s from 02:17); timings taken in main before 02:55 need re-checking; the P2 gate is weakened by 160/161.
- **Dailies 2026-10-12**: STATE (suite line, register, Watching (0) resolved) and a sparse LOG pointer.
- **Next in this session: F3(a)** (owner decision O-7, handoff addendum, queued "after the item in hand (147)").
  It was not picked up before 149: the addendum landed mid-session (02:32) after the handoff had been read.
