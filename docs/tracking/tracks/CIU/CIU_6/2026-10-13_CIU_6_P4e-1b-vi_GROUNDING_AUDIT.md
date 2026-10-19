# CIU 6 — P4e-1b-vi grounding audit (the star-collapse slice)

**Serves**: D4 [§5.P4e-1b-sequencing](../../../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#p4e-1b-sequencing),
row *1b-vi — the star-COLLAPSE slice*; opens the decisions
[Q_U52](../../../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u52) §1–2 named, now ledgered as
[Q_U55](../../../2026-07-28_CIU_T6_PATH_SELECTION_D4.md#q-u55) (pending) and two to follow.
**Written at** `01ef2542` (branch `ciu6-path-selection` = `main`; no CIU code changes since `a492bbb7`).
Racket 9.3, built with `PLT_CS_COMPILE_LIMIT=1000000`. Probes: [`research/P4e-1b-vi/`](research/P4e-1b-vi/)
(`probe-1bvi-{a…f}.prologos`, each with its `.out`), run one file per process with
`tools/scratch-run.sh`; census script reproduced in §5.

## Result

The two questions Q_U52 deferred are smaller than recorded, and one of them is not about the star.
**(1) The renamed ancestor is a question about the collapse family, and the caret family has the
same hole today.** `^-` silently drops a re-keyed ancestor (`e3{a^p.b.c^-}` → `{:c @[1 2]}`) while
its provenance twin honors it (`e3{a^p.b.c^-_}` → `{:p-b-c @[1 2]}`). Nobody uses that spelling (0 hits
in the corpus and the tests) and no test pins it. `*-` is `^-` composed with `*` on one segment. A segment
carries only one operator suffix, so `c^-*` is refused, and the composite has to be spelled as a star
continuation. So whatever is decided for `*-` should be decided for `^-` in the same slice, and the fold
(1b-v-C) makes the star side a table row. The broadcast-ancestor half of Q_U52 §1 has no observable cases
today: an in-block fused ω chain fails outright (filed as **DEFERRED 167**). **(2) The `*->` boundary
predates 1b-vi.** `-` already continues an identifier, so `spec g2 Nat *-> Nat` is not an arrow today: it
is reported as "spec type for g2 has no arrow", which misleads. The corpus has **zero** glued `*->`. Glued
`*-` after an identifier occurs only in the posit names `p*-to-rat` / `p*-if-nar`, and only in comments. Those
names live outside selection territory, which Q_U37 scopes the star to, so 1b-vi does not touch them. The
decision is therefore about which message the glued form gets and in which territory, not about protecting
existing programs.

## 1. The spec, read for this slice

`docs/research/2026-07-28_path-selection-spec.md` (v0.1, a guide, not a prescription) read in
full. What bears on 1b-vi:

1. **The spec keeps the axes apart; D4 has coupled them, for a reason the spec does not see.** `^` is
   the key axis with three continuations (§3.4); `*` is the layer axis, vector-only, with no
   continuations, and its action on Map layers is §8 Q4 (OPEN). D4 has since made `*` sort-generic
   with a nominal join (Q_U23, Q_U49, which answers §8 Q4 "yes, by splice"). It has also given the star
   key-axis continuations (`*_`, Q_U24/Q_U51; `*-`, Q_U48). The coupling comes from the
   one-suffix-per-segment rule (`split-star-lexeme`'s first arm and `split-caret-lexeme`'s
   star guard, `parser.rkt` — DEFERRED 90, Q_U29). Under that rule the composite "re-key this segment,
   then delete its layer" has no spelling except as a star continuation. Reading `*-` as `^-` ∘ `*`
   is what makes Q_U55 a collapse-family decision.
2. **§3.6's monotone migration path** — *"every error shipped today can become a meaning later
   without breaking a working program"* — is the principle that separates the Q_U55 options
   (D4 §1.2 restates it for PS7: "errors may later become meanings, never vice versa").
3. **§3.4 "dropped means dropped"** matches what `^-_` does today: a dissolved ancestor
   leaves the synthesized key (`e3{a^.b.c^-_}` → `{:b-c …}`).
4. **§2.2 / §8 Q8 (the lexical grammar)** lists three juxtaposition-sensitive characters. The star
   family adds a fourth sensitivity (`-` after `*` or `^` is an operator continuation, and `*->` touches the
   arrow). The spec does not mention `*-`. The Q8 deliverable owes it a clause.
5. **§3.3 honest nesting meets total collapse**: a keyless landing in a block is a tuple component.
   So a total collapse over a *vector* join yields a 1-tuple (`v3{a^.b^.c*}` → `@[@[@[1 2] @[3]]]`),
   and over a *nominal* join it splices fields (`t5{a^.b^.c*}` → `{:m {:x 1} :n {:y 2}}`). A user who
   wants the bare value writes the path form. The worked examples should show both, so that no one
   reads a 1-tuple as a defect.
6. **§4 L1 is stated unconditionally, but it holds only in path position** — see F4 / DEFERRED 167.
7. **Doc-truth, for X.close**: read cold, the spec still says `*` is vector-only (§3.5) and `.*` is
   row-splat (§2.1), and both are superseded (Q_U23; Q_U26 ravel). D4 §1.2 maps the *old* PS rulings
   onto the spec, but it has no table of D4's later departures *from* the spec. Proposed: a
   "spec → D4 departures" table (spec element · D4 decision · anchor) in §1.2.

## 2. Findings

**F1 — The caret precedent: a re-keyed ancestor is dropped by `^-` and honored by `^-_`.**
(probe a, `e3 := {:a {:b {:c @[1 2]}}}`)

| input | result | the ancestor's key continuation |
|---|---|---|
| `e3{a.b.c^-}` | `{:c @[1 2]}` | — |
| `e3{a^p.b.c^-}` | `{:c @[1 2]}` | rename **silently dropped** |
| `e3{a^.b.c^-}` | `{:c @[1 2]}` | dissolve — redundant, same outcome |
| `e3{a^p.b.c^-q}` | `{:q @[1 2]}` | rename silently dropped |
| `e3{a.b.c^-_}` | `{:a-b-c @[1 2]}` | — |
| `e3{a^p.b.c^-_}` | `{:p-b-c @[1 2]}` | rename **honored** in the provenance key |
| `e3{a^.b.c^-_}` | `{:b-c @[1 2]}` | dissolve drops out ("dropped means dropped") |
| `e3{a^p.b^q.c^-_}` | `{:p-q-c @[1 2]}` | both honored |

So the caret family observes an ancestor's continuation **only through the provenance channel**.
Usage: `grep` for a re-keyed ancestor under `^-` (`\^[A-Za-z_][A-Za-z0-9_-]*\.[^ ]*\^-`) gives **0** in
every `.prologos` file and **0** in `tests/`. Unused and unpinned, so changing it breaks nothing measurable.

**F2 — The star today, with key ancestors: `*-` is "dissolve every key ancestor, then `*`" at every
depth.** (probes a, c; `t5 := {:a {:b {:c {:m {:x 1} :n {:y 2}}}}}`,
`v3 := {:a {:b {:c @[@[1 2] @[3]]}}}`)

| input | result |
|---|---|
| `t5{a.b.c*}` | `{:a {:b {:n {:y 2}, :m {:x 1}}}}` |
| `t5{a^p.b.c*}` | `{:p {:b {:n {:y 2}, :m {:x 1}}}}` |
| `t5{a^p.b^.c*}` | `{:p {:n {:y 2}, :m {:x 1}}}` |
| `t5{a^.b^.c*}` | `{:n {:y 2}, :m {:x 1}}` — the shape Q_U48 gives `t5{a.b.c*-}` |
| `t5{a^p.b.c*_}` | `{:p {:b {:c-n {:y 2}, :c-m {:x 1}}}}` — `*_` prefixes with the deleted layer's key only |
| `v3{a.b.c*}` | `{:a {:b @[@[1 2] @[3]]}}` |
| `v3{a^p.b.c*}` | `{:p {:b @[@[1 2] @[3]]}}` |
| `v3{a^.b^.c*}` | `@[@[@[1 2] @[3]]] : ⟨[PVec [PVec Int]]⟩` — a 1-tuple (honest nesting) |
| `t5{a.b.c*-}`, `t5{a.b.c*-_}`, `dd{p.u*-}` | the mid-lexeme refusal (`c*-` "is neither a field nor an operator") — the pre-mint state |

Q_U48's equivalence (`*-` ≡ `^` on every ancestor + `*`) holds wherever every ancestor is a key step.
It stops being sugar exactly when an ancestor carries its own continuation (Q_U55), or when an ancestor
is an ω step, which no caret can follow (Q_U19).

**F3 — Q_U55's options differ only where an ancestor has an explicit key continuation.** Plain key
ancestors are collapsed under every option. Measured above: a dissolve is redundant and harmless, and
a rename is where the options diverge. See the D4 ledger entry for the options and the tradeoff analysis.

**F4 — The broadcast-ancestor half of Q_U52 §1 is unobservable today: L1 fusion fails in block
position (DEFERRED 167, filed on main).** (probes d, e, f)

| input | result |
|---|---|
| `w4.a:b:c` (path) | `@[1 2] : [PVec Int]` |
| `w4{a:b:c}` (block) | ERROR — "`:c` … is not present in the record `{:b {:c Int}}` … in the select branch `a.b.c`" |
| `uu.a:0:userName` (path) | `@["L" "J"]` |
| `uu{a:0:userName}` (block) | ERROR — "the subject (branch `a.0`) is a tuple …" |
| `w4{a:{b.c}}`, `w4{a:b}` | `{:a @[{:b {:c 1}} {:b {:c 2}}]}` |

Within one branch, a step after an ω step is either another fused ω step or a sub-block; `.k`
after ω acts on the whole result (spec §3.2.1, measured: `w3{a:b.c}` → "not a field of a vector
element position"). A sub-block starts a new branch. So an ω step can be an ancestor of a deep star
*in the same branch* only through a fused chain, and in-block fused chains fail before any star is
read. The three L1 pins are all in path position. No option for Q_U55 behaves differently here (no
caret can be written after `:`, Q_U19). The case returns once DEFERRED 167 decides the in-block meaning.

**F5 — The `*->` boundary.** (probes b, d; census §5)

| input | today |
|---|---|
| `mn{a*-> b}` | the mid-lexeme refusal for `a*-`; `>` is a separate token |
| `mn{a*- b}` | the same refusal (`a*-` fuses: `-` continues an identifier) |
| `mn{a *- b}` | "`*-` — `*` is postfix; it attaches to the END of a segment" |
| `mn{a*-b}` | the mid-lexeme refusal for `a*-b` |
| `mn{a}*-`, `mn{a}*-_`, `mn{a}*->` | **`Unbound variable`, with no name** — the closer band mints only exact table lexemes (Q_U53), and an unminted star spelling falls through to a nameless lookup |
| `spec g2 Nat *-> Nat` + `defn g2 [n] n` | "spec type for g2 has no arrow but defn has 1 params" — **`*->` is already not an arrow** |

Census: glued `*->` — **0** in `.prologos` (all directories), **0** in `tests/*.rkt`. `*-` glued after
an identifier character (pattern `[]A-Za-z0-9_?!})]\*-`, power-checked on 4 positive and 2 negative
controls) — **3** in `.prologos`, all in comments, all the posit names `p*-to-rat` / `p*-if-nar`
(`lib/prologos/core/conversions.prologos:61`, `:309`, `:310`). `p*-if-nar` is a keyword-only form with its
own elaborator hint (`elaborator.rkt:947`), so **identifiers containing `*-` are live surface outside
selection territory**. Q_U37's territory scoping keeps them out of the star's reach, and inside selection
territory `x{p*-if-nar}` is already refused (Q_U29). 1b-vi leaves both unchanged, because `*-if-nar` is not
a table row. The battery pins the closer band as NOT minting `*-` / `*-_` (`tests/test-path-selection.rkt:6194–6195`);
**1b-vi flips those two pins deliberately**, and the `*--` pins (`:6205`, `:6283`, `:6288`; "`*--` is
never reserved") stay.

> ⚠ **CORRECTION (2026-10-13, before commit)**: the first draft of this paragraph said "**0** glued `*-`
> after an identifier". That count came from a zero-power pattern (`[A-Za-z0-9_?!}\])]\*-` — in an ERE
> bracket `\]` is not an escape, so the pattern demanded a literal `)]*-` and matched neither positive
> control). Found by running the census pattern on positive controls before committing.

So the hazard is not "1b-vi will change what existing code means". Three smaller facts matter instead: in
selection territory a glued `*->` becomes a valid `*-` step plus a stray `>`; in type territory it is
*already* silently not an arrow, with a misleading message; and the closer band's miss message has no name
in it. The Q8 lexical grammar owes all three a clause.

**F6 — The totality census for the dispatcher (implementation scope, for later).** All at `01ef2542`:

| surface | sites | note |
|---|---|---|
| `select-star-cont` readers | **6**: `pretty-print.rkt:197` (table-driven since 1b-v-C) · `reduction.rkt:1895`, `:1902` · `typing-core.rkt:1766`, `:1784`, `:1850` | the five non-printer readers are binary tests on `'flatten-synth`: an unknown cont reads as bare `*` |
| prose arms that spell the star | **15** `star-*` arms of `format-select-fail`, `typing-errors.rkt:616–793` (`star-mid-branch`, `-leaf`, `-hetero`, `-omega-tuple`, `-not-yet`, `-content-collision`, `-omega-nominal`, `-map-opaque`, `-open-row`, `-synth-collision`, `-synth-positional`, `-synth-vector-contents`, `-deep-prefix`, `-dup-key`, `-l4-mixed`) | the printer defect's twin (`#p4e-1b-v-c`) |
| reduction `oops` strings naming `*_` | 3: `reduction.rkt:1796`, `:1818`, `:1898` | internal (typing carries the user-facing refusal) |
| `(string=? lex "*")` selectors | `parser.rkt:438`, `:685` | DEFERRED-130 arms, deliberate (ruling-derived) |
| the family table | `reader-forms.rkt:280` — 2 rows | `*-` / `*-_` are a row each once ruled |
| arrival matrix | `tools/star-arrival-matrix.rkt` already lists `*-`, `*-_` | both 0/209 — the pre-mint state |
| grammar | `editors/tree-sitter-prologos/grammar.js:1158` `flatten_step: token.immediate('*')` | DEFERRED 144 (X.close) |

**F7 — Baseline at `01ef2542`** (the branch fast-forwarded over 20 main commits: the sweep and
runner-queue merges; production files touched are `substitution.rkt` and `type-lattice.rkt`, F3(a)):
battery 573 test-cases, battery + acceptance test file 663 / 663 (×5 shards); acceptance
`run-file.rkt --check` 88 / 88. The full suite was not re-run, because the branch has no code of its own
and main's checkpoint-2 gate is 10 330 / 494 (`01ef2542`).

## 3. What this means for the decisions

- **Q_U55 (pending, posed now)** — what total collapse does to an ancestor that carries an explicit
  key continuation. It is decided for `^-` and `*-` together. The options and their tradeoffs are in
  the D4 ledger entry.
- **The `*->` boundary (Q_U52 §2; posed after Q_U55)** is reframed by F5: the decision is the message and
  the territory, with zero programs at stake, and type territory already needs a fix that 1b-vi did not cause.
- **`*-_`'s prefix rule** (Q_U48's open member) sets how far Q_U55 reaches. If `*-_` follows `^-_` (the
  full surviving output path), a rename on an ancestor is observable under `*-_` and stays legal under
  every option.

## 4. Filed

- **DEFERRED 167** (main) — L1 fusion fails in block position; zero in-block chain pins; message wrong
  under every reading. Before P5.

## 5. Re-run

```sh
# from the worktree root; one file per process
for f in a b c d e f; do
  tools/scratch-run.sh -t 120 docs/tracking/tracks/CIU/CIU_6/research/P4e-1b-vi/probe-1bvi-$f.prologos
done
# census
grep -rn --include=*.prologos -E '\*->' . | grep -v compiled | grep -v research/P4e-1b-vi | wc -l
# ⚠ `]` goes FIRST in the bracket — `\]` is not an ERE escape (the zero-power first draft, F5)
grep -rn --include=*.prologos -E '[]A-Za-z0-9_?!})]\*-' . | grep -v compiled | grep -v research/P4e-1b-vi | wc -l
grep -rn --include=*.prologos -E '\^[A-Za-z_][A-Za-z0-9_-]*\.[^ ]*\^-' . | grep -v research/P4e-1b-vi | wc -l
grep -rn --include=*.rkt -E '\^[A-Za-z_][A-Za-z0-9_-]*\.[^ "]*\^-' racket/prologos/tests | wc -l
grep -n 'select-star-cont' racket/prologos/*.rkt
awk '/^\(define \(format-select-fail/{on=1} on && /^ *\[\(star-/' racket/prologos/typing-errors.rkt
```
