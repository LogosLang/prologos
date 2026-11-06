# CIU 6 — P4e-2 grounding audit (ravel `x:*`, Q_U63 = J)

**Serves**: D4 [§5.P4e-2](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#p4e-2), the design target and plan of the slice that builds ravel as `x:*`
([Q_U63](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u63) = J). The decisions these findings led to are recorded there, each citing its RA-n; this
document holds the evidence (owner, 2026-11-03: "Audit findings can be their own thing and not cloud-up the design doc
(but cross-reference)"; `principles/DESIGN_METHODOLOGY.org` Per-Phase Protocol step 2 as revised that day).
**Written at** `bd2e48ff` (branch `ciu6-path-selection`, = the 1b-vi checkpoint `d2ad3dad` on main + docs). Racket
9.3, built with `PLT_CS_COMPILE_LIMIT=1000000`. The findings were first drafted inside D4 at `71c8dbfc` and moved here
unchanged in substance. Probes, committed at `5876569b` in [`research/P4e-2/`](../research/P4e-2/):

- `probe-p4e2-e.prologos`: `e:N` is its output line N, via `tools/scratch-run.sh`; the `ns` line produces no result.
- `reader-dump.rkt`: `dump: <spelling>` is that spelling's block in `reader-dump.out`, covering 68 spellings through
  reader, preparse and parser.
- `inject.rkt`: `inject:N` is a parsed surf with its steps rewritten, run through `process-command`.
- `census-p4e2.py`: eight power-checked patterns, counted over production, tests, source and the owner's WIP.

Findings use the prefix `RA-n`, checked clean on 50 local branches.

## Result

J needs no new rule, and the slice is smaller than the record implied:
- **The seats.** The reader seat is a third case of the `:` gate's positional rule (RA-1), and the keyed twin
  `values:k*` already carries every continuation J needs (RA-2). ε belongs inside `(@bcast ε)`, which reuses the
  broadcast's whole container dispatch; the closed union's guard fires on it today, so it needs its arms (RA-3).
- **Nothing to retire.** No production or owner-WIP site uses a spelling the slice touches, and no expression-position
  test pin flips (RA-4).
- **Two corrections to the record.**
  - DEFERRED 185's addendum misclassified `vv:0*`. A star after a broadcast has a meaning, and the twins already
    compute it (RA-7).
  - DEFERRED 105's ⛔ verdict no longer holds for either seat (RA-8). This is a conjecture until built.
- **One silent position.** J's item-count change is silent in exactly one place, the `||` fact row. There it does
  what the keyed twin already does, and DEFERRED 192's fix covers both (RA-9).
- **Message findings and one staleness.** An existing message already offers `xs:*` by accident (RA-5). Block
  position has two shapes (RA-6). The editor grammar is loud on J (RA-10). Q_U35's refusal can name `[f x]:*`
  (RA-11). A principles-doc example is stale (RA-13, proposed).

## Findings

- **RA-1 — the reader seat.** `values:*` reads as three items, `(values : *)`: the colon at column 6, the star at 7
  (`dump: values:*`). The `:` gate mints `$bcast-step` only for a `keyword` / `colon-annotation` token glued to a base
  (`bcast-step-trigger?`, `parse-reader.rkt:4319`) or a bare colon glued on BOTH sides to a base and an `lbrace`
  (`bcast-brace-trigger?`, `:4309`, DEFERRED 42). `:*` is neither, so it falls through. Glued and spaced differ only in
  srcloc (`dump: values: *`, `dump: values :*`). J's seat is the third case of the same rule: a bare colon glued on both
  sides to a base and to a star-family token, emitting what a keyword `:k*` emits with k = ε.
- **RA-2 — the keyed twin already carries every continuation J needs.** Measured in `reader-dump.out`:

  | keyed twin | built today | J's spelling |
  |---|---|---|
  | `values:k*` / `*_` / `*-` / `*-_` | `((@bcast k) (@star flatten))` / `flatten-synth` / `flatten-collapse` / `flatten-collapse-synth` | `values:*` … `values:*-_` |
  | `values:k*:name` | a nested `$select-path` with `($bcast-step :name)` | `values:*:name` |
  | `values:k*.0` | `(get … 0)` | `values:*.0` |
  | `values:k*{a b}` | `($select … a b)` | `values:*{a b}` |
  | `values.0:k*` | `($select-path (get values 0) ($bcast-step :k*))` | `values.0:*` |
  | `values:k**`, `k*^`, `k*x` | guided parse errors at the segment split | `values:**` gets JD-4's own text |

  Without the mint the continuations are mangled, not merely unbound: `values:*:name` builds a path whose SUBJECT is `*`
  (`dump: values:*:name`). A parser-level recognizer cannot recover that; the reader is the only seat. (A parser-side J was
  considered and is refuted by this row.)
- **RA-3 — the IR seat, and ε's representation.** The step vocabulary is a closed union (`select-step-kind`,
  `syntax.rkt:1417`; its contract at `:1395-1432`: "a new kind must be added to select-step-kind AND given an arm in every
  `case` over it"). Seven `case` sites (syntax `select-step-mark-collapsed`, `select-step-unmark`, `select-step-output-name`,
  `select-branch-top-keys`; typing `select-branch-entries`; reduction `select-reduce`; printer `pp-select-branch`) and 23
  consumers of a broadcast's inner step (most delegate to `select-step-name` `:1547`, `select-step-cont`,
  `select-step-output-name` `:1706`, the printer's `step->string`, or `select-project`). ε = `(@id)` **inside** `(@bcast ε)`
  (the decided text) reuses `select-bcast-lift`'s whole container dispatch; a nullary `(@ravel)` kind would rebuild it per
  container and lose JC-2. Injected: `(@bcast (@id))` RAISES `select-step-kind: unknown select step kind: (@id)` (inject:7)
  — the negative control: the guard fires, and ε needs its arms. The bare `(@id)` outside a broadcast must be unbuildable
  (one constructor) and refused by the branch validator if it ever arrives.
- **RA-4 — the retirement inventory is empty.** Census (`census-p4e2.out`; 8 patterns, each passing its must-match and
  must-reject strings): **0** non-comment hits in 139 production `.prologos` files and in the owner's WIP `foray.prologos`
  for every spelling P4e-2 touches. The 54 distinct test lines any pattern hits are classified mechanically: Racket regexes
  (`#rx".*"`, 21), comments (8) and a test name (1) are look-alikes; 6 are the `#p(a.*)` / `#p(a.**)` path-literal pins
  (PF's form) and 18 are `selection` declarations (JD-7, untouched). **The expression-position class is 0: no pin flips.** So the "17 lines … the bulk of what a retirement must move" of
  [§5.P4e-1b](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#p4e-1b) (the `test-selection-paths.rkt` count) is, under JD-7, nothing to move. foray's `.*` "splat" is one
  comment (line 687 of the WIP copy): no collision.
- **RA-5 — the `.**` message offers `xs:*` already, by accident.** `values.**` → "broadcast `.**` was retired — its
  replacement is `:*` (e.g. `xs:*`)" (e:23). It is the `.*NAME` → `:NAME` template (`parser.rkt:979`, since `25f3f22d`,
  2026-08-08) applied to the field name `*`. Once J lands the remedy RUNS, and ravels one level. JD-4's family: name
  `x:*` (one level) and `x:*:*` (two).
- **RA-6 — block position has two shapes.** `rec{k:*}` and `y{a.0:*}` both read `($select … : *)` and both get "block keys
  are written bare — `x{}`, not `x{:}`" (e:25, e:26; `parser.rkt:2062`). JD-3's waypoint covers both, naming `rec.k:*` and
  `y.a.0:*`.
- **RA-7 — DEFERRED 185's reader seats split in two, and one of them is a CORRECTION.** By [Q_U46](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u46)'s rule ("the star
  deletes the layer **sₙ** contributed"):
  - `t3.0*`, `y.a.0*`, `y{a.0*}` star an ordinal **step**, which contributes no layer → Q_U46's ordinal-star refusal, the
    text the block band already gives (`values{0*}`, e:58), with the remedy `x.N:*` once J runs. Today: Unbound variable
    (e:27, e:28), "stray `.`" (e:29).
  - `t3:0*` stars a **broadcast**, which does contribute a layer → by Q_U46 + [Q_U27](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u27) it has a meaning: the join of
    each element's element 0, the ordinal-sort sibling of `values:k*`. Measured: the twins already compute it —
    `(@bcast 0) (@star flatten)` injected → `@[1 2 4] : [PVec Int]` (inject:4) = `t3:0{0 1}*` (e:36). Only the reader
    cannot spell it (e:30, Unbound variable).
  - ⚠ **Correction:** DEFERRED 185's 1b-vi-close addendum listed `vv:0*` among the spellings that "missed" Q_U46's
    refusal. That classification was wrong; `vv:0*` is a missing spelling of a meaning already built. (Addendum on main.)
- **RA-8 — DEFERRED 105's verdict, re-derived at HEAD.** 105 (⛔, 2026-08-10) blocked `x.0*` / `xs:0*` on the star's datum
  representation: "the star has nowhere to live in an ordinal payload" ([§5.P4e-0](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#p4e-0) attempt 3). Two later facts move it:
  `x.0*` now wants a REFUSAL (Q_U46, 2026-08-12), so a reader marker that collapses to one loud item suffices and no star
  representation is needed; `xs:0*`'s star would ride the broadcast's KEYWORD payload, as `:k*`'s does (`:k*` fuses into one
  symbol — the count-preserving shape), not `$postfix-index`'s numeric one. **Conjecture until built:** both seats are
  landable as their own mints, each with its corpus A/B. This was checked against the record and the reader code, not by
  building.
- **RA-9 — the count change, as a meaning claim at every position** (DEFERRED 105's lesson). Today's 3-item reading of a glued
  `x:*`:

  | position | today | after the mint (predicted) |
  |---|---|---|
  | application argument `[take1 values:*]` | loud — "Too many arguments" (e:37) | the meaning: `take1` of the ravel |
  | collection literals `@[values:* 1]`, `'[values:*]` | loud — Unbound variable (e:38, e:39; `'[…]` is a list literal whose elements are evaluated: control e:40) | the meaning |
  | binder `defn f1 [x:*]` | loud — "Empty type segment in arrow type" (e:42; control e:41) | still loud; text to measure |
  | `def q1:* := 1` | loud — Type mismatch (e:44; control e:43) | still loud; text to measure |
  | bundle `(Eq:*)` | loud — Unbound variable (e:55, e:56; control e:53, e:54) | still loud; text to measure |
  | **fact row** `\|\| "x" values:*` | **silent**: 3 rows, `{:a unknown, :b unknown}` among them (e:50; control e:47) | **silent**: 2 rows with an `unknown` term — exactly the keyed twin today, `\|\| "x" values:k` (e:52) |

  The only zero-error change is the fact row, and it is DEFERRED 192's class (a non-ground term in a `||` row is accepted
  silently): 192's fix (refuse at registration) covers J's term and the keyed twin's alike. J adds no hazard class there;
  192 gets an addendum. Demand: 0 of 1 109 `||` rows hold a non-ground term (192's census).
- **RA-10 — the editor grammar is loud on J today.** `values:*` and `values.0:*` parse as a `path_expr` with an `ERROR`
  node on the colon (`grammar.js:1153`'s `broadcast_step` is one immediate token `/:[a-zA-Z_]…/`), so the corpus gate can
  see them — not the silent-wrong-tree class its comment at `:1140-1148` records. P4e-2 adds one path-step alternative.
- **RA-11 — Q_U35's refusal can name the spelling it lacked.** `[id values]*` → "`*` (flatten) applies to a SELECTION step
  … e.g. `xs:{a}*` or `cfg{a}*`" (e:57; `parser.rkt:696`). Q_U35 promised "the separate-flatten spelling"; under J that is
  `[f x]:*` (Unbound today, e:15; its subject is bound, e:59). Its meaning stays refused (Q_U35); only the remedy grows.
- **RA-12 — `selection` declarations are untouched, and the one type-level use stays.** `selection-field-unrestricted?`
  (`typing-core.rkt:2639`) is the only TYPE-level reader of `*` / `**` (RV-3); JD-7 leaves it.
- **RA-13 — a principles-doc staleness, proposed, not applied.** *The Most Generalizable Interface*
  (`principles/DESIGN_PRINCIPLES.org:200-212`) still gives `xs.*field` as its example of syntactic sugar; that spelling
  was retired at D4.P1a (its message names `xs:field`, `parser.rkt:979`). Owner-owned surface.

## Method notes

The controls caught four errors in my own instruments; each is recorded so the next probe does not relearn it.
- The first census was a bash table delimited by `|`. That character is also ERE alternation, so the field split cut
  the patterns; the power check aborted the run.
- A brace pattern accepted `x{a}:*`, because `}` ends a base. The must-reject string caught it.
- The first count of test hits was made by eye and double-counted lines that two patterns match: 25/7/5/19, against
  the mechanical 21 regex / 8 comment / 1 test name / 6 path literal / 18 selection. The classifier now lives in
  `census-p4e2.py`.
- The first injection run was misaligned by one row, because the `ns` form is consumed. It was discarded and re-run.

A probe line that failed on its own malformed control was fixed before it was read: the `defn` binder syntax, and a
`bundle` used with the wrong `where` form.

## Re-run

```
# from the worktree root; one file per process
tools/scratch-run.sh -t 200 docs/tracking/tracks/CIU/CIU_6/research/P4e-2/probe-p4e2-e.prologos \
  > docs/tracking/tracks/CIU/CIU_6/research/P4e-2/probe-p4e2-e.out
cd docs/tracking/tracks/CIU/CIU_6/research/P4e-2
PLT_CS_COMPILE_LIMIT=1000000 timeout -k 10 300 "/Applications/Racket v9.3/bin/racket" reader-dump.rkt   # → reader-dump.out
PLT_CS_COMPILE_LIMIT=1000000 timeout -k 10 300 "/Applications/Racket v9.3/bin/racket" inject.rkt        # → inject.out
cd -
python3 docs/tracking/tracks/CIU/CIU_6/research/P4e-2/census-p4e2.py <main checkout> \
  > docs/tracking/tracks/CIU/CIU_6/research/P4e-2/census-p4e2.out
```
