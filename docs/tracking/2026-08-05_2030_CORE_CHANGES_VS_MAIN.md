# Core changes on this branch that are not in `main`

**Branch**: `claude/ocapn-prologos-implementation-auLxZ` · **Base**: `origin/main` @ `2c7d97bd`
**Written**: 2026-08-05 · **Purpose**: PR #28 review aid — the compiler-side work, separated from the OCapN port it grew out of.

---

## Why this document exists

PR #28 opened as "the OCapN port". It still is, but that is no longer most of
what is in it. The port ran into the compiler repeatedly — a whole-file abort
here, a silent wrong answer there, a diagnostic that named the wrong subsystem —
and fixing those became a second body of work that has nothing to do with
object-capability networking and everything to do with the language.

A reviewer looking at 280 changed files cannot tell those two apart. This
document is the split.

---

## Method (so the numbers can be checked)

Core is defined by exclusion: every path in `git diff --name-only
origin/main...HEAD` that does **not** match `ocapn|syrup|captp|interop|tcp-ffi|goblin`.

```
280 changed files total      →  184 core, 96 OCapN
492 non-merge commits        →  374 touch at least one core file
                                (of those, ~185 change code; the rest are
                                 DEFERRED/dailies/tracking entries)
```

The 374 figure overstates core *work*: many April/May commits are OCapN phases
that incidentally touched `driver.rkt` or a test list. The month histogram shows
where the real core work is:

| month | core-touching commits | what they mostly are |
|---|---:|---|
| 2026-04 | 13 | OCapN Phase 0–4; incidental |
| 2026-05 | 50 | OCapN phases + the first genuine core perf fixes (`shift`/`subst`) |
| 2026-07 | 59 | OCapN interop endgame + three compiler perf fixes + CI repair |
| 2026-08 | **252** | almost entirely compiler work |

**Verification state**: suite **560 files / 10 917 tests green** at `368ddcd2`.
(It was 558 / 10 867 immediately after merging 115 upstream commits earlier the
same day; 551 / 10 674 on this branch alone before that merge.) `main`'s tree
carries 493 test files; this branch carries 566 (+73, of which 38 are OCapN →
**+35 core test files**), plus 51 modified.

---

## Complexity scale used below

| | meaning |
|---|---|
| **S** | one site or one arm; the fix is smaller than the diagnosis was |
| **M** | one subsystem, several sites; needs a checklist pass (`pipeline.md`) |
| **L** | cross-cutting sweep, or a new module with its own invariants |
| **XL** | new subsystem / architecture change |

The rating is about *implementation* size. It deliberately does **not** track
how hard the thing was to find — several **S** entries below took far longer to
diagnose than to fix, and that asymmetry is itself the most useful signal in
this table.

---

## 1. Whole-file aborts on the parse/expansion path — **L** in aggregate, **S–M** each

The single largest behavioural theme. A Racket exception raised on the reader /
preparse / parse path escapes `process-file` entirely, so the file produces
**nothing at all** — not even the forms that already succeeded above the fault.
Prologos is supposed to report per-command errors; this class silently converts
one bad form into a file that defines nothing.

The tell is that output is **empty, not partial**, and a green suite is no
defence: an error-count gate reads "no output" as "no errors".

| commit | what aborted the file |
|---|---|
| `5da580f9` | any reader raise — now a reported error that says where |
| `4efe236c` | a locationless syntax object — which is how a bare top-level `[]` aborted the reader |
| `bd1afc65` | the follow-up: with the abort fixed, an empty group still yielded the **wrong command's** result when another form followed, because `"nowhere"` was being used as a merge key |
| `f75fff20` | a removed `~N` literal |
| `c4aa917c` | a malformed `.( )` mixfix |
| `cd0517c4`, `75509ae2` | `do` — joined the marker-seat family |
| `c1e73fe0` | a malformed declaration |
| `486555b1` | a `defn` with a non-symbol name |
| `b6e2cff3` | importing a file with no `ns` |
| `902ca588`, `ccf7adb0` | `(when C (parse-error …))` — diagnostics computed and thrown away, swept probe by probe |

The shared fix is the **marker-seat pattern**: the reader emits a sentinel
(`$let-error`, `$do-error`, `$def-error`, `$preparse-error`, `$mixfix-error`)
that flows as a per-command `parse-error` *value* instead of raising. Each
individual adoption is **S**; the pattern's reach across the reader, preparse,
parser and macro layers makes the theme **L**.

**Review note**: this is the theme most likely to interact with `main`'s own
parser work. It was merged clean at `2026-08-05`, but it is where I would look
first for a conflict on the next merge.

---

## 2. Silent wrong answers — **M**, and the highest-value section

Nothing in this group produced an error message. Each returned a plausible
value that was wrong.

| commit | defect | why it hid |
|---|---|---|
| `fe04f0a9` | `occurs?` could not see a meta inside a container ⇒ **unsound occur-check** | containers were a `[_ e]` catch-all |
| `2df675d5` | `expr-foreign-fn` treated as a closed leaf by **six** walkers | a comment asserted the invariant; nothing enforced it |
| `1b959f9a` | `conv-nf` did not give containers hole-as-wildcard | same container family, fixed one member at a time |
| `250f3317` | `loose-bvar-range` under-reported on association-pair fields ⇒ `shift` silently no-op'd | the range is an optimisation guard; a wrong answer just skips work |
| `10f5a080` | collection literals dropped in the AST↔solver round trip | a narrowing query returned `nil` at **0 errors** |
| `ff19ecc6` | a `defn` body that is just `.field` silently dropped its spec | projection path bypassed the spec seam |
| `003e0c43` | a resolved numeric literal collapsed to a malformed node | |
| `b23b05d1` | a **recursive process type-checked as terminating** | `proc-rec` was unimplemented and discarded silently; now refuses loudly |
| `ba69e790` | a non-exhaustive `match` returned a junk value at 0 errors — W3002 added, and **found a real bug in the tree immediately** | holes are legal (`??foo`), so a partial function looked fine |
| `7efc781d`, `790dfa53` | cross-file spec-store and relation-store leakage inside a batch worker | order-dependent; passed under `--tests` every time |
| `65edc1a4` | resolution bridges captured registry cell-ids while still `#f` | |
| `913af799` | the first-class path FFI list boundary was **inverted in both directions** | |
| `b9002e46` | a dynamic map key may hit any label ⇒ every field's type must widen | |

The structural lesson (now in `pipeline.md` § *Exhaustive Walkers*): a
hand-armed AST walker with a `[_ e]` catch-all cannot be trusted, and a green
suite proves nothing about it. Prefer a generic transparent-struct rebuild as
the fallback, with explicit arms only for binder forms.

**Complexity**: each fix is **S**; the walker-family sweep across
`shift`/`subst`/`nf`/`zonk`×3/`occurs?`/`uses-bvar0?`/`conv-nf` is **M**.

---

## 3. Performance — **S–M** each, large measured effect

Every number here is A/B measured, not estimated.

| commit | change | measured |
|---|---|---|
| `9f004ab5` + `2466f321` | memoize whole-program capability inference on an env-generation key (the second commit widens the key — the registry is a third input it reads) | **suite 402 s → 57 s** |
| `5c6a260d` | the memory report forced **two major GCs per command**, for numbers nothing read | **2.3× of test wall time** |
| `4f6b3f0c` | `looseBVarRange` short-circuit on `shift` | 2.4× |
| `6f2e0773` | same on `subst` | **40.8× at N=5**, linear scaling restored |
| `4efbed69` | tree builder: one pass + binary search, not two quadratics | quadratic → n log n |
| `8c4af36e` | scope the bounded typing run's fuel exhaustion — it was **poisoning every later unification** | correctness *and* speed |

The capability-inference memo is the one to read first: profiling the OCapN
server workload showed **76 % of every frame** was whole-program capability
inference. That is a compiler-wide cost that the port merely happened to expose.

---

## 4. Diagnostics — **S** each, ~28 commits

Too many to table individually; the shape is consistent — an error that named
the wrong subsystem, or named nothing, now names the actual mistake and (where
possible) shows syntax that works.

Representative: module-load errors name file/line/variable (`c9e8034e`);
multiplicity errors stopped printing `Declared multiplicity: declared`
(`598abce4`); the `defn` parameter-list error shows WS syntax that works
(`db65045a`); an unbracketed `defn` body says so instead of naming a lambda you
never wrote (`8eff6e7e`); a foreign match-arm constructor says which type it
belongs to (`0da17830`); importing a book chapter explains what a chapter is
(`67824e69`); row annotations name the `{…}` collision instead of blaming `Int`
(`38ab4bbd`).

Two new warnings with real teeth:
- **W3001** — two of your own imports binding the same spec name (`277fcffd`),
  later narrowed (`2800517e`) because it was claiming a consequence it could not
  demonstrate.
- **W3002** — non-exhaustive `match` (`ba69e790`).

**Review note**: `2800517e` and `6ec2031a` ("battle-tested" oversold the
diagnosis result) are self-corrections. They are in the history on purpose.

---

## 5. Schema / records / `validate` — **M**

Continuation of the CIU T6 records line, all runtime-side.

`f589ef44` runtime `validate` descends into nested schemas · `881ff150` field
types check their **elements**, not just the head constructor · `57140a86`
extends that to `PVec`/`Set`/`Map` · `c42056d3` a deep `:requires` path is
enforced at every hop, not just the top · `36c5552c` a failing seal nested in a
list or map is caught at commit · `61cfa679` a selection whose declaration
failed no longer validates everything · `17449766` a wildcard `:requires` path
parses in a `.prologos` file · `760e8a31` the presence marker moves to a
position the lexer reserves.

New module: **`field-witness.rkt`** (286 lines) — the runtime half of the schema
field-type witness. Bake time computes a per-field acceptance tag as plain data
by *consuming* `subtype?` (zero drift); run time interprets the tag below
`reduction`, so no new cross-module edges and the tags serialise into `.pnet`
where closures cannot.

---

## 6. `.pnet` module cache — **M**, two of these were serving wrong answers

| commit | |
|---|---|
| `72ce62c9` | **a dependency edit did not invalidate the cache** — the cache served stale compiled output |
| `7fa17a60` | 31 AST nodes were unregistered *by sibling* — the reader's unknown-tag fallback returns a raw **vector** that fails a `match` arbitrarily far away, printing like the real struct |
| `97c113c7` | the positional payload has a fixed shape, now asserted on **both** sides |
| `0befd6b5` | dual-write registries on cache-hit restore (#78) |

The sibling-registration failure mode is documented in `pipeline.md`: it stays
latent until the node first appears in — or is first *invoked from* — a cached
module body.

---

## 7. The cell-merge lattice contract — **S** to fix, and the largest single find

Added after the first draft of this document, and it belongs near the top on
value even though it is bottom of the list on line count.

**`5a684215` — the union-type type-checker hang.** Filed for over a year as
*"the `:type`-facet union join not reaching a fixpoint"*. That framing names the
**join**, and the join was innocent. The defect was one layer down, in the
**carrier**: `tagged-cell-merge` unions two lists of tagged entries with a bare
`append`, so `merge(x, x)` returns twice x's entries. The lattice *value* is
stable; the *representation* grows on every write. Change-detection compares
representations, so every round sees a change, dependents re-fire, and the
network never quiesces.

It is a **hang**, not a wrong answer — no bad value to inspect, no assertion, no
error to grep — and it accelerates, because each round's representation is
bigger than the last. It also took the LSP down alongside the type-checker. The
fix is 8 lines in the cell. It had been live for fourteen months.

**`94e6330d` — the contract test, which found two more on its first run.**
`tests/test-merge-laws.rkt` checks every registered merge (13 today) for
idempotence unconditionally, with commutativity/associativity opt-in per merge
because several here are deliberately last-write-wins. It immediately found
`nogood-merge` (a live cell merge in `atms.rkt`, same shape, same latent hang)
and `merge-hasheq-list-append`. Fourteen months of reading the code had not.

**`45616b4d` → `5207ddc3` → `65e89d2b` — the third one dissolved.** Probing
`merge-hasheq-list-append`'s three cells showed they are **write-only**: nothing
reads them, so the merge question was moot and the cells were retired instead of
fixed. The middle commit is a failed first attempt whose scope was wrong and
which the suite caught; it is in the history deliberately.

**`e8ecec93` — the fuel bound was switched off exactly when speculation was on.**
Found while asking whether fuel could have bounded the hang. It could not — fuel
is a *fire-count* budget and cannot bound the cost of one fire — but the probe
turned up that its `on-write-check` was unreachable under speculation anyway:
the hot fast path is gated on `(not under-speculation?)` and the slow path never
consulted it.

**`259e04ca`** is worth reading as method: I had assumed a retry loop was
responsible and a ten-minute probe said it is one fire. The guess is recorded
next to the measurement that killed it.

The ambient lesson is now in `.claude/rules/on-network.md` § *CHECK idempotence
— do not document it*, with the full record in `DEVELOPMENT_LESSONS.org`. The
short form: all three instances carried a comment asserting the property they
violated, and a comment asserting an algebraic law is worth less than no comment
because it stops the next reader from checking.

---

## 8. New capability — **M–L**

| what | size | commits |
|---|---|---|
| **`ordered-map.rkt`** — persistent weight-balanced tree (Adams, DELTA=3 RATIO=2), order relation as a parameter; 16 tests | 204 lines, new | `822d5e6b` (the blocker is *persistence*, not "a backend"), `7d1e0922` |
| **String library Phase 4** — Unicode normalization, grapheme clusters, edit distance + "did you mean?", common prefix/suffix, regex bridge | 191 + 73 lines | `1e00ac95`, `e61437ee`, `4bc01a59`, `8c50ea3f`, `39ae3053` |
| **Float library** — sqrt/NaN/rounding/`if-nan`; the FFI's float marshalling stops being dead code | 60 lines | `8ac49c24`, `ed3d9292` |
| **`Gen` trait** | 79 lines | `ee37f9e3` |
| **`:pre` / `:post` contracts actually run** | | `cee2b436` |
| **`:examples` are actually checked** | | `23bcf08f` |
| **Redex model wired into the ordinary suite** + Vec/Fin QTT usage rules + `vindex` reduction | +84/+22 | `42e25f52`, `d5c1108d`, `2b94721a` |
| **LSP cross-module go-to-definition** — the blocker had already been built | +68 | `7f266d0e` |
| **WS `:mixfix` metadata** registers the operator; unicode symbols work | | `dd57c7bb` |
| **derive skip list**: four hand-written names → one, mechanized | | `1c0676fb`, `704cb9da`, `a342b0f7` |

---

## 9. Guards and tooling — **M**, and the theme is *guards that had rusted*

| commit | |
|---|---|
| `6f7fe634`, `8f338d0d` | the parameter lint had rusted **twice**; wired into pre-commit. Six of the eight flags were mine — a guard nobody runs is not a guard |
| `7cdab855` | cell lint accuracy: 11 flagged sites → 6 → 1 real |
| `041d8b10` | regenerated the dep table — it had rusted and was **mis-selecting tests** |
| `6e38d214` | `bench-ab --refs`. The flag had been *documented* as `--ref` for most of the tool's life and **did not exist** — the documented A/B path silently measured identical code twice |
| `afaf4795` | CI: `PLT_CS_COMPILE_LIMIT` at job level. An interpreted build **fails** the interop gate (14/1 on CI vs 17/17 locally) |
| `b5fba8c0` | `test.yml` YAML syntax error — **the full suite had not run since May 4** |
| `9a12cb7d` | restored `--file-timeout` (dropped by a merge) and pinned the OCapN suite SHA |
| new | `tools/check-doc-twins.sh` — stale generated `.md` twins now say so |

`tools/dep-graph.rkt` shows +791/−294; that is regenerated data, not authored
code, and should be read as **S** despite the line count.

---

## Not done, and carried openly

- **F-row inference** (`93573a33`, `57b03488`) — a minimal version was built,
  **measured unsound**, and reverted. The second projection hits an
  already-solved `dyn` row and D19 mints a meta instead of extending it. The
  proper fix is scoped: 28 `expr-Record-tail` sites, 83 `'closed`/`'dyn`
  literals, and a new row-unification case. Not started deliberately.
- **Session recursion** (`b23b05d1`, `934be86e`) — the process half now refuses
  loudly instead of type-checking as terminating; the type half is broken too,
  and they are **one** gap. Both halves scoped, neither built.
- **OCapN netstring framing** — the wire change itself. The blocking question
  was answered by research 2026-08-05 (the JS reference makes length-prefixed
  framing the default and calls raw mode a compat shim on a retirement path);
  what remains is a real decision about replacing vs joining the existing
  strategy, plus moving the suite pin in the same commit.
- **Four owner rulings** — collected in
  [`2026-08-05_1751_FOUR_OPEN_OWNER_RULINGS.md`](2026-08-05_1751_FOUR_OPEN_OWNER_RULINGS.md).
  Not blocked on work; blocked on a decision that is not mine to make.

---

## What a reviewer should be sceptical of

1. **The self-corrections are load-bearing.** Several commits reverse an earlier
   claim in this same branch (`e4b6e4ba` srcloc cause, `2800517e` W3001 scope,
   `6ec2031a` diagnosis strength, `1f1bd84f` timing attribution, `93573a33`
   F-row). Read the later one.
2. **Perf claims.** All are A/B measured, but the wall-clock ones were taken on
   a shared machine. The `402 s → 57 s` and `40.8×` figures come from
   deterministic-work counters and an interleaved micro respectively, which is
   the stronger evidence; treat any bare wall-clock delta as weaker.
3. **`macros.rkt` (+810/−91) is the biggest single authored file change** and
   sits on the merge seam with `main`'s reader work. It is where the marker-seat
   pattern, the access-sentinel fold reordering (`01ba6d41`), and the `defmacro`
   pattern-variable polarity inversion (`586f7683`) all landed.
4. **Test-count arithmetic.** `+73` test files is gross; `+35` is the core
   figure. One file (`generators.rkt`) is a shared fixture, not a test.

---

## Provenance

Every claim in this document is derived from `git` on the branch, not from
memory. First written at `c34eb349`; **refreshed at `368ddcd2`**, which added
§7 (the cell-merge lattice contract) and moved the suite figure to 560 / 10 917.
The commit-to-theme mapping was produced mechanically and then hand-corrected;
the April/May "core-touching" commits are mostly OCapN phases and are excluded
from the themed sections above even though they appear in the 374 count.

Not themed above, because they are small and self-describing: `91362074` gives
the POL syntax cluster Level-3 (`.prologos` file) coverage of its own;
`585201ac` puts a gate on the last structural residue rather than redesigning
it; `c785df1b` re-probed a held-back residue, found it a duplicate, corrected
and archived it; `368ddcd2` makes a union value say why you cannot look inside
it; `7fc8293c` cleans comment drift left by my own retirement and moves the
warning to the source.
