# `loc->line` mis-extracts the line for tree surfs — the dual-spine merge is defused by a one-line defect

**Filed** 2026-08-02 at the CIU T6 D4.P4c-4 mini-audit · **Status** ✅ **RESOLVED
2026-08-02** (`d4e32398`, `8f437a5c`, `385d3ec1`) — but **not the way this note
proposed**; see [§0](#outcome) ·
**Not** CIU T6 work — it is shared parser machinery and its blast radius is the
whole dual-spine merge.

---

<a id="outcome"></a>

## §0 — OUTCOME: three defects, not two; the suggested fix is HARMFUL; the spine must stay off

**⚠ THIS NOTE'S §3 "minimal fix" WOULD HAVE SHIPPED A SILENT WRONG-ANSWER BUG.**
Read §0 before §1–§5. The sections below are preserved **as filed**, errors and
all, because the shape of the mistake is the lesson.

### The third defect — the one that decides everything

**The two spines number lines on DIFFERENT BASES.** The tree spine is **0-based**
(`make-indent-rrb-from-char-rrb` starts its `source-line` counter at 0,
`parse-reader.rkt`); the preparse spine is **1-based** (`pos->line-col` starts at
1 → `datum-srcloc`, `parser.rkt`). This was in nobody's enumeration — not this
note's, not the P4c-4 mini-audit's, not five grounding facets'.

It **inverts §3's conclusion**. Swapping the arms does not "fix node-derived
surfs"; it makes the key pair **form N's preparse surf with form N+1's tree
surf**, and `same-form-type?` waves that through whenever the neighbours are the
same kind.

Also corrected: §1's table says arm 2 "yields the COLUMN". It yields a hardcoded
literal **`0`** — the node srcloc is `(list source-line-num 0 0 0)`, col and both
positions hardcoded ("simplified srcloc"). So `tree-by-line` holds exactly **one**
real key, `0`, bound to the file's last non-error tree surf.

### The measurements (§5 steps 1–2; 163-file corpus, 138 files producing output, 5,171 forms)

| Key variant | Hits | Mispairings | Forms flipping to tree |
|---|---|---|---|
| **HEAD (broken)** | **0** | — | **0** |
| §3's arm swap alone | 242 | **176 (73%)** | 216 |
| arm swap + base normalisation | 1,372 | 0 | **694 (13.4%)** |

- **The tree spine has won 0 forms, ever.** `[else tree-surf]` — "tree parser wins
  for user forms" — has never once fired in the life of this code.
- **§3's fix, end-to-end on three `def`s** (`a:=1 b:=2 c:=3`): `a` becomes
  **`ERROR: Unbound variable`**, because `def a`'s surf is replaced by `def b`'s.
- **A correct key makes it WORSE.** With the base normalised (emit a 1-based
  srcloc struct from `item-srcloc`), the tree spine wins 694 forms and the corpus
  **regresses**: errors **359 → 724** across **35 files, not one improved**
  (`lib/prologos/core/conversions` 0→56, `ciu-t6-f1-records` 8→75,
  `ciu-t6-path-selection` 0→24, `records-typing` 0→34), and **32 test files
  fail** — mixfix, dot-access, let-blocks, records, path-selection, keyword
  literals. §5 step 2 anticipated exactly this: "the tree spine's arms have gone
  stale." They have — precisely *because* they never ran.

### The resolution shipped (`d4e32398` → `8f437a5c` → `385d3ec1`)

The measurement picks none of §5 step 4's options cleanly. The landing arrived in
three steps, each correcting the one before — the sequence is the record:

- **`d4e32398`** — make the defusal deliberate **at the key**: a tree-shaped
  srcloc yields `#f`. Correct behaviour, wrong home (see below).
- **`8f437a5c`** — close the **string-mode hole** in that fix (the
  `process-string-ws` path carries a srcloc *struct with line 0*, which is truthy,
  so the list arm never fired there), and **pin the invariant with a test** — the
  first commit shipped +0 tests against this project's own rule.
- **`385d3ec1`** — move the spine guard to an **admission gate**, splitting the
  identity-key rule from the parse-fitness claim.

Option 2 (flip `[else tree-surf]` → `preparse-surf`) was **not** taken, and the
reason sharpened on inspection: it would leave the **unguarded** error-recovery
path enabled while disabling the guarded one, and it makes `merge-form` a constant
function. See the guard's-home section below.

**Gates.** Suite **9,799 tests / 479 files / 0 failures** (baseline). Corpus A/C
over all 163 files: total errors **359 = 359**, **no file changed its error
count**. Two deltas, both explained:
- 11 files differ **only** in generated-name counters (`?meta3125` → `?meta3005`),
  because more entries now take the pre-existing gensym branch.
- **One** real change — `homoiconicity.prologos` result 16, `Unbound variable` →
  `Unexpected datum: ()`. That was the corpus's **sole** accidental
  error-recovery substitution: a preparse error whose srcloc line fell back to 0
  (`datum-srcloc`'s `(or (syntax-line stx) 0)`) matched `tree-by-line`'s only real
  key, and the **unguarded** `(or tree-match s)` swapped in an unrelated tree
  surf. The file's own diagnostic for `'()` (line 98) now surfaces. An
  improvement.

### Why the spine regresses: **14 distinct defects across 4 layers**, not a stale arm

Classified by per-cluster root-cause analysis over the 35 regressed files, with an
adversarial synthesis pass. The headline: the tree spine is a **~1,970-line partial
re-implementation of an 8,212-line parser**, frozen at an older vocabulary — and it
consumes a **lossier input** than preparse does.

| Layer | Defect | Severity |
|---|---|---|
| **Input contract** | Tree consumes lexeme STRINGS, re-deriving numbers with a bare `string->number`; the reader already classified and valued them exactly (`#e` prefix). `1.5f32` becomes **1.5 × 10³²**; `1e23` is off by 8,388,608 | **SILENT** |
| **Input contract** | Tree parses **UNEXPANDED** source (`read-to-tree` on `source-str`); preparse runs `preparse-expand-all` first. Prelude `defmacro`, trait-type applications, schema seal + `:default` fill, `validate` wrappers are all invisible to it. **Not repairable inside `tree-parser.rkt` at all** — it needs a pipeline change | loud |
| Dispatch | Atom table is **11 of 42** symbols (`Keyword`, `Rat`, `Unit`, all `Posit*`/`Float*`/`Quire*`, `zero`, `nil`, `refl` …) | loud; **silent** where a prelude value shadows the type name |
| Dispatch | Head dispatch is **~58 of ~357** (`Map`, `Set`, `PVec`, all `pvec-*`/`map-*`/`set-*` primitives …) | loud; **silent** when a prelude binding shadows a primitive |
| Dispatch | `parse-form-tree`'s `[else]` is a **non-error** fallthrough; `at-group`, `set-group` and `error` reach it unarmed. `@[1]` → `1`; `#{not true}` → `false` | **SILENT** |
| Stale arm | `{…}` built as the retired `surf-map-assoc` chain, never `surf-map-literal` — so CIU T6's closed-record seeding never runs. **First divergence in ≥8 of the 35 files** | loud |
| Stale arm | `<A -> B>` hardcodes multiplicity `'m0` (**erased**); preparse uses `#f` → `mw`. The sexp sibling 200 lines away is correct | **SILENT** |
| Stale arm | `<A * B>` with a non-binder LHS emits `surf-pair` (a **value**) instead of `surf-sigma` (a **type**) | loud |
| Stale arm | `parse-check-tree` reads positionally, so `check e : T` takes the `:` token as the type and **discards `T`** | loud |
| Stale arm | `parse-defn-tree` reads 3 fixed positions, so a multi-token return type **silently discards the body** | **SILENT** |
| Merge | The error branch `(or tree-match s)` has **zero guards** — no `same-form-type?`, no spec-store. It converted `spec {:0 …}` / `{:1 …}` QTT errors into definitions where the substituted tree surf's binders are all `#f` → `mw`: **a declared-linear parameter silently becomes unrestricted** | **SILENT / soundness** |

**Only five surf kinds can ever be swapped** (`same-form-type?` admits six and
`surf-defn-multi` is never produced by the tree spine). **All five are broken.**

**⚠ Correction to my own gate.** I reported leg B as "359 → 724 errors". That
**understates** it: two files that are **clean (0 errors) at HEAD** abort entirely
under leg B — `examples/unified-matching.prologos` (91 results lost) and
`lib/prologos/core/abstract-domains.prologos` (23 lost). An error-COUNT gate cannot
see a whole-file abort, and it cannot see the silent rows either: a full-output
census found 6 value-level flips with the error count unchanged, including
`"localhost" : String` → `<error> : String` and `b : Bool` → `b : Goal`.
**Any future attempt must gate on full output, never on error counts.**

### Three downstream consumers that independently block the spine (none were in §4)

A winning tree surf carries a **4-element list** where every downstream consumer
expects a **`srcloc` struct**:

| Consumer | Behaviour on a bare list |
|---|---|
| `format-srcloc` (`source-location.rkt`) | struct accessors, no list guard → **RAISES** `srcloc-file: contract violation` |
| `srcloc->range` (`lsp/diagnostics.rkt`) | falls to `[else]` → **every diagnostic pinned to 0:0** in the editor |
| `register-definition-location!` (`driver.rkt`, 8 sites) | values are **`.pnet`-serialized**; only the struct shape is registered (`pnet-serialize.rkt`) → the documented detonate-far-away mode (`pipeline.md`) |

So reviving the spine needs the struct conversion **anyway**. It is recorded
verbatim and **unapplied** in `item-srcloc`'s comment, with its measurement, so the
next attempt starts from the known step instead of re-deriving it.

### Answering §4's open question

**Yes, the token line is recoverable** — `pos->line-col` already exists and is
exported (`parse-reader.rkt`); do not write a new one. But it needs the source
text, and **`process-file` does not parameterize `current-source-str`** (it is
`""`). That has a second consequence nobody had noticed: the **file** path takes
the LEGACY `parse-*-tree` branch while the **string** path (REPL/LSP/tests) takes
`parse-eval-tree-for-cell` — **the two pipelines run different parsers.** Adjudicate
that before any spine revival; it decides which parser the merge would trust.

### ✅ The guard's home — criticism upheld, and acted on (`385d3ec1`)

The adversarial synthesis argued the guard was in the **wrong place**: defusing at
`loc->line` leaves *a loaded gun*, because emitting a real srcloc struct from
`item-srcloc` is a change **three downstream consumers legitimately want**, and the
next person who makes it silently re-arms 694 form-swaps. **Upheld** — and the
synthesis's own counter-argument does *not* survive the measurement: it said
inverting would leave the spine "permanently unexercised, which is what rotted
it," but the spine has **never** been exercised (0 wins ever), so that cost is
already fully paid.

**The root of the confusion: two propositions were sharing one `cond`.**

1. *An unknown position is not an identity.* A hygiene rule about identity keys —
   true regardless of the tree spine, true if it is deleted, true if it is
   commissioned tomorrow. **Stays in `loc->line`**, now stated as its own rule and
   applied uniformly to all three srcloc shapes.
2. *The tree spine's output is not fit to win.* A claim about **parse fitness**,
   with 14 measured defects behind it. Position-knowledge was only ever a **proxy**
   for it — and proxies drift from their targets, which is exactly why a correct
   change defeated the guard. **Moved to an admission gate**,
   `tree-spine-admitted?` (default `#f`), which empties `tree-by-line`.

**Why admission and not `merge-form`'s `[else]`** — the option that looked obvious,
and the one the synthesis actually recommended. Two disqualifiers: every other arm
of `merge-form` already returns `preparse-surf`, so flipping `[else]` makes it a
**constant function** ignoring its second argument; and the **error-recovery branch
reads `tree-by-line` directly with no guards at all**, so flipping `[else]` would
leave the tree spine's only live role being its **unguarded** one — the path where
the QTT bypass rides in. Gating admission covers **both** consumers.

**Both directions verified**, which is the whole point of the move: with the
`item-srcloc` struct conversion applied `test-dual-spine-merge-key` now **passes**
(it previously failed); with `tree-spine-admitted?` flipped to `#t` it **fails**.

**The dead-parse cost, measured before proposing removal** (200-rep microbench):
47 µs (`bool-logic`) / 119 µs (`first-class-paths`) / 227 µs (`ciu-t6-f1-records`) /
327 µs (`homoiconicity`) / 872 µs (`data/list`), against whole-file wall of
0.41–4.23 s — **0.003 %–0.09 % of runtime**. Removing `parse-top-level-forms-from-tree`
is **not** a performance win, so it stays; and that is right anyway, because on the
string path it routes through `preparse-expand-single`, which may register macros
as a **side effect**. Skipping it would be a behavioural change dressed as an
optimisation, for no measurable gain.

**Still open — the instrument.** The gate should become a **set of eligible form
kinds** rather than a boolean, but not before a **differential oracle**
(`pipeline.md` § "Exhaustive Walkers") exists to decide membership: assert
`tree-surf ≡ preparse-surf` corpus-wide and fail the build on divergence. It would
have caught all fourteen defects before the key was ever touched. Landing the set
first would repeat CIU T6 D4.P4c-3's "nothing behind the switch."

### Owner decision remaining

Commission the tree spine (repair the stale arms + the srcloc type + the
file/string parser divergence — a track-sized job), **or** retire the merge
explicitly. The merge already self-describes as "a throwaway bridge" that PPN
Track 3–4 dissolves, which argues for the latter. This work takes neither step; it
stops at *the defusal is now deliberate and measured*.

### For CIU T6 D4.P4c-4

Its producer bridge is protected by this defect, and **that protection is
unchanged** — the tree spine still never wins, so P4c-4 needs no coordinated
change. What changed is the *reason*: it now rests on a stated invariant in
`loc->line` rather than on an accident. If the spine is ever revived, the bridge
needs its own protection at that time (§6 stands).

> **Why this is written down rather than fixed inline**: CIU T6's P4c-4 needs to
> know whether the merge protects a broadcast. It currently does — *by accident*,
> because of the defect below. Fixing the defect makes every latent tree surf go
> live **at once**, which is a behavioural change well outside that phase's scope.
> Discovering its blast radius mid-slice is exactly the mid-phase pivot the
> mini-audit exists to prevent.

---

## §1 — The defect

`loc->line` (`racket/prologos/driver.rkt:2442-2447`), the helper that keys the
dual-spine merge:

```racket
(define (loc->line loc)
  (cond
    [(srcloc? loc) (srcloc-line loc)]
    [(and (list? loc) (>= (length loc) 2)) (cadr loc)]  ;; (file line col span) or (line col pos span)
    [(and (pair? loc) (number? (car loc))) (car loc)]    ;; (line col pos span) as first element
    [else #f]))
```

**Arm 2's own comment claims it serves two shapes. It is correct for at most one,
and arm 3 — which handles the shape that actually flows — is UNREACHABLE**,
because arm 2 catches every list of length ≥ 2 first.

### The shapes that actually flow — verified, not assumed

> ❌ **The `(cadr loc)` column reading below is WRONG — see [§0](#outcome).** The node
> srcloc is `(list source-line-num 0 0 0)`: col and both positions are hardcoded
> `0`, so arm 2 returns the literal `0` for *every* node, not a column. And the
> line it does carry is **0-based**, unlike preparse's.

| Producer | Shape | `loc->line` gives | Correct? |
|---|---|---|---|
| **preparse** — `datum-srcloc`, `parser.rkt:220-226` | `srcloc` **struct** | `(srcloc-line loc)` | ✅ real line |
| **tree, node** — `parse-tree-node` srcloc field, `parse-reader.rkt:1666` | `(list line col start-pos end-pos)` | `(cadr loc)` = **col** | ❌ |
| **tree, token** — `item-srcloc`, `tree-parser.rkt:56-57` | `(list 0 0 start-pos end-pos)` | `(cadr loc)` = **0** | ❌ (and see §4) |

`parse-tree-node`'s field comment is the authority and is unambiguous:

```racket
srcloc      ;; (list source-line source-col start-pos end-pos) | #f
```

Line **first**. Arm 3's comment says exactly this (`(line col pos span) as first
element`) and its body `(car loc)` is the correct extraction — it simply never
runs.

## §2 — Why it matters: this key IS the merge

```racket
(define tree-by-line
  (for/hasheq ([s (in-list tree-surfs)]
               #:when (not (prologos-error? s)))     ;; errors filtered OUT
    (define line (surf-source-line s))               ;; ← loc->line
    (if line (values line s) (values (gensym) s))))
```

and

```racket
(define (merge-form preparse-surf tree-surf)
  (cond
    [(not tree-surf) preparse-surf]                          ;; ← lookup MISS lands here
    [(not (same-form-type? preparse-surf tree-surf)) preparse-surf]
    …
    [else tree-surf]))                                       ;; ← the tree spine WINS
```

Preparse surfs key on a **real line**; tree surfs key on a **column or 0**. The
keys are computed on different scales, so the lookup generally misses,
`tree-surf` is `#f`, and preparse wins by default.

**That is the opposite of the designed behaviour.** `merge-form`'s last arm is
`[else tree-surf]`, commented *"Both pipelines produced valid output → tree
parser wins for user forms."* The tree spine is supposed to be authoritative for
user forms; today it effectively never is.

### The protection mechanism this defect is masking

Every sibling selection surface is protected by being deliberately **errored** on
the tree spine, so it is filtered out of `tree-by-line` and preparse becomes
authoritative — e.g. `tree-parser.rkt:147` (`select-brace-group`) and `:177`
(`dot-access`). That file states the hazard verbatim:

> a missing arm lets a garbage surf BEAT preparse's

So there are **two** independent things keeping garbage tree surfs from winning:
the per-tag error arms (designed, correct) and the broken key (accidental). Only
the first is intended. **This is a belt-and-suspenders situation where the
suspenders are a bug** — and per the project's own rule, dual mechanisms mask
defects in each other. Any tag *lacking* an error arm is protected today solely
by the broken key.

## §3 — The minimal fix, and why it is not sufficient

> ❌ **CORRECTED BY [§0](#outcome) — DO NOT APPLY THE CODE IN THIS SECTION.** The
> two spines number lines on different bases (tree 0-based, preparse 1-based), so
> this swap does not enable the merge — it MISPAIRS form N with form N+1.
> Measured: 176 of 242 hits (73%) are mispairings; on three `def`s it leaves the
> first one unbound.

The two list arms are simply **in the wrong order**. The discriminator is already
written: a `(file line col span)` shape has a non-number head (a path or string);
the tree shape has a numeric head.

```racket
(define (loc->line loc)
  (cond
    [(srcloc? loc) (srcloc-line loc)]
    ;; tree shape: (line col start-pos end-pos) — LINE FIRST, all numeric
    [(and (pair? loc) (number? (car loc))) (car loc)]
    ;; file-first shape: (file line col span)
    [(and (list? loc) (>= (length loc) 2)) (cadr loc)]
    [else #f]))
```

⚠ **This alone does not make the merge correct**, and shipping it as "the fix"
would be worse than leaving it: it turns the merge on for *node*-derived surfs
while leaving *token*-derived surfs keyed on a fabricated `0` — so those would
now all collide on one key instead of missing. See §4.

## §4 — The second defect, which is the harder one

`item-srcloc` (`tree-parser.rkt:53-58`) **fabricates** the line and column for a
token entry:

```racket
[(token-entry? item) (list 0 0 (token-entry-start-pos item)
                              (token-entry-end-pos item))]
```

Positions are real; line and column are hardcoded `0`. So any surf whose srcloc
came from a token carries no line at all. Under the §3 fix these all key on `0`
and collide.

**Open question for the investigation**: does `token-entry` carry enough to
recover the real line — directly, or by mapping `start-pos` through the source
text? If yes, `item-srcloc` should compute it. If not, that path must be made to
return `#f` so those surfs fall to `(gensym)` (unmatchable) rather than collide
on `0` — the existing `(if line … (gensym))` branch already expresses that
intent, and `0` defeats it by being truthy.

## §5 — Suggested order of work

**Do not start by changing behaviour. Measure the blast radius first** — that is
the whole point of doing this out of band.

1. **Instrument, don't fix.** Add a temporary counter in `merge-form`: for each
   form, compute the key both ways (current and §3-corrected) and record whether
   a lookup that misses today would HIT under the fix, and whether that hit would
   land on `[else tree-surf]`. Emit counts only; change no behaviour.
2. **Run the corpus** (163 tracked `.prologos` files) and the suite. The output is
   the number that decides everything: *how many forms currently take preparse
   that would flip to the tree spine.* If it is small, this is a contained fix.
   If it is large, the merge has been running on preparse for so long that the
   tree spine's arms have gone stale, and correcting the key would surface a
   backlog of latent garbage surfs.
3. **Audit the tag arms.** Enumerate every tag `parse-node-tree` can dispatch and
   check which have explicit arms vs fall to the silent `else → parse-expr-tree`.
   The comment at `tree-parser.rkt:139-147` says an explicit arm is MANDATORY;
   the sweep confirms whether that has been maintained. Any tag without one is
   protected today only by the broken key.
4. **Then choose the resolution**, informed by (2) and (3):
   - *fix the key and repair the fallout* — correct per the design intent, most work;
   - *fix the key and flip the default* (`[else tree-surf]` → `preparse-surf`),
     making tree-spine adoption opt-in per form — smaller blast radius, but it
     inverts a documented design decision and should be ruled, not assumed;
   - *fix `item-srcloc` to return `#f`* for tokens and correct the arm order —
     narrowest correct step; makes node-derived merging work and leaves
     token-derived surfs honestly unmatchable.
5. **Gate**: full suite + the 163-file corpus A/B (`git archive` both legs onto one
   snapshot, worktree-pin the baseline — `bench-ab.rkt` has no `--ref`). A corpus
   A/B with **zero** diffs would mean the fix changed nothing, which for this
   defect is evidence the instrumentation in (1) was wrong, not evidence of safety.

## §6 — What CIU T6 assumes in the meantime

P4c-4's producer bridge will make `users:name` produce a **non-error** surf on the
tree spine. Unlike its siblings it mints no tag, so it has **no tag arm and cannot
be errored** — the §2 protection is structurally unavailable to it. It is therefore
protected *only* by this defect.

CIU T6 records that as an explicit assumption rather than inheriting it silently.
If this investigation lands a fix, the broadcast needs its own tree-spine
protection **in the same change** — either a tag + error arm matching the
siblings, or a `merge-form` exception arm on the POL.9b template
(`driver.rkt:2487-2497`), which already prefers preparse when the two spines
disagree in category about a `def` body.

## §7 — Coordinates (re-derive before trusting; this repo's drift regularly)

| What | Where |
|---|---|
| `loc->line` | `driver.rkt:2442-2447` |
| `surf-source-line` | `driver.rkt:2450-2458` |
| `tree-by-line` (the error filter) | `driver.rkt:2473-2477` |
| `merge-form` (`[else tree-surf]`) | `driver.rkt:2482-2503` |
| POL.9b exception arm (the template) | `driver.rkt:2487-2497` |
| `parse-tree-node` srcloc field | `parse-reader.rkt:1663-1669` |
| `item-srcloc` (the `0 0` fabrication) | `tree-parser.rkt:53-58` |
| tag error arms + the hazard comment | `tree-parser.rkt:139-147`, `:174-180` |
| `datum-srcloc` (preparse, srcloc structs) | `parser.rkt:220-226` |

All verified at `66a8e731`.
