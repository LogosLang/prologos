# Tree-sitter Grammar — working rules

Distilled from TSG Track 1 (2026-08-14), which took the grammar from 87% of the
corpus mis-parsing to 0 swallows / 1.7% unparsed. Full record:
`docs/tracking/2026-08-14_0030_TREE_SITTER_GRAMMAR_REPAIR.md`.

## ⭐ The closing-phase obligation

**A track that changes user-facing syntax updates `grammar.js` in its `X.close`
phase, or files a DEFERRED entry saying why not.** Same status as the existing
"WS-mode validation before marking DONE" rule.

This exists because the grammar drifted **five months** behind the language with
no signal: tree-sitter never fails, it *recovers*. Every consumer — font-lock,
folding, the surfer — degrades silently, so nothing ever surfaced. A pre-commit
tripwire warns when the reader/parser surface changes without the grammar, but
the tripwire is a backstop; the close is where it belongs.

The corpus is already generated for you: every track writes a `.prologos`
acceptance file into `examples/`, and the gate scans `examples/`. New syntax
lands in the corpus automatically — you only have to measure.

## The workflow

```bash
cd editors/tree-sitter-prologos
./install.sh          # generate + build + install + smoke test + provenance
./check-corpus.sh     # gate against corpus-budget.txt
```

`install.sh` FIRST, always. The gate measures the **installed dylib**, not
`grammar.js`. A staleness guard now refuses (exit 3) when the installed parser
was not built from the current source — it compares a content hash from the
provenance file, not mtimes.

Installing while Emacs is open is **safe** (atomic rename). A running Emacs
keeps the parser it mapped; the new one is picked up at its next start.

## ⭐ Read SWALLOWS first, and watch MISSING. Error COUNT rises when the grammar improves.

**Three signals, and they are not interchangeable** (owner, 2026-08-14):

- **SWALLOWS** — the gated metric. One ERROR node covering ≥20% of a file is the
  failure that makes an editor unusable.
- **MISSING going UP is a STRONGER defect signal than ERROR going up.** A MISSING
  node is the parser reporting it had to *invent* a token to continue — which
  means a rule matched and then could not be satisfied, i.e. a rule that is
  WRONG rather than absent. ERROR is a lagging signal by comparison: one big
  ERROR swallows everything inside it, so other defects become invisible, and
  the count improves while a real regression rides along underneath.
- **ERROR count is anti-correlated with progress** and must never be read alone.

Measured instance (TSG T1 §9.7): a first cut of path selection moved
ERROR 3054 → 2743 — an apparent win — while pushing **MISSING 74 → 110**. All
+36 were a `}` the parser invented because `select_block` assumed bare
identifiers where the corpus writes whole paths. The headline number improved
throughout; only the MISSING delta showed the regression. **When MISSING rises,
stop and difference it against a rebuilt pre-change grammar — do not net it off
against an ERROR drop.**


A **swallow** is one ERROR node covering ≥20% of a file — the failure that makes
an editor unusable, because font-lock and navigation lose the whole region
rather than the bad form.

- **ERROR count is anti-correlated with progress.** Letting a construct parse
  further replaces one swallowing mega-ERROR with several precise small ones, so
  the count *goes up*. Measured repeatedly: 8336 → 8456 on a real improvement.
- **Error-bytes lag.** Each fix exposes the next gap in newly reachable text.
- **Swallow count tracks reality.** It is the gated metric in `corpus-budget.txt`.

Editor support is always operating on half-written code, so the property that
matters is not "parses at 0" but **a broken form damages itself and stops
there**. (Owner framing, 2026-08-14 — it is why the metric exists.)

## ⭐ The tell: does anything already claim this syntax?

**Grep for competing claimants before spending.**

| symptom | meaning | cost |
|---|---|---|
| generates first try, no conflict declarations, no regressions | the grammar simply **lacked** the shape | ONE RULE |
| conflicts that walk from position to position as you reshape | two rules **compete** for the syntax | a DESIGN |

First kind: `angle_param`, `=`, `defr`, operators, `string`, `qualified_name`.
Second kind: same-line `defn` bodies, `fio`'s inline match arm, map literals —
each needed a lexical split, not a better rule.

## ⭐ The recipe for a contested shape: a scanner token

When two rules claim the same syntax, move the decision to the **lexer**. A
zero-width external token makes the branch an ordinary shift on one character of
lookahead instead of an ambiguity. Three uses in-tree: `_same_line_body`,
`_map_open`, `_arm_lparen`.

⚠ **The load-bearing half is in the GRAMMAR, not the scanner.** The scanner
cannot tell where in a rule the parser is; it only sees `valid_symbols`. So the
grammar must withhold the token until the right point — for `_same_line_body`
that means making the param list REQUIRED in the same-line branch. Make it
optional and the token fires right after `defn NAME`, swallows `[x]` as the
body, and strands the real one.

⚠ A trailing `optional($._newline)` inside a child rule is an ambiguity when the
PARENT also offers `_newline` as a sibling choice. `match_arm` and
`data_constructor` carry it safely; the `trait` body children did not.

## Diagnosis

- **Leading-token clustering MISDIRECTS — 4 for 4.** It counts the first token
  of the line *containing* an error, so it fingered `defn` (779, really
  multi-clause arms), `(fn` (272, really operators), and `ns` (16.9%, a
  construct with **no defect at all** — one 19,280 B swallow whose cause was on
  the next line). Use it to find *where* errors land, never *what* causes them.
  **Only minimal-snippet probes establish causation.**
- **A differential must vary ONE thing.** `a::b` vs `prologos::data::nat`
  differs in segment count AND first-segment length; the wrong cause sat in the
  deferred list for four phases.
- **Prefix truncation is unsound for bisecting.** `sed -n '1,Np'` manufactures
  an error at the cut (a prefix ending mid-`impl` has no body). Use
  delete-window or substitution **on the full file** — differential, and cannot
  invent a failure.
- **Probes passing proves nothing about locality.** Every reverted same-line
  formulation was green on all shape probes while driving swallows 6 → 24.

## When to revert

**Flat corpus + passing probe = KEEP. Flat corpus + failing probe = REVERT.**

A fix for a rare construct cannot move the corpus (`let`: 83 lines against 1,423
`defn` lines; `qualified_name`: byte-identical). That is a fact about the corpus,
not a verdict on the fix. But `paren_type` and the `param_list` split both failed
their own targets *and* measured flat — those were reverted.

---

## ⭐ `queries/highlights.scm` is THE source of truth — both editors read it

Since 2026-08-14 the shared query is consumed by **both** the VS Code
semantic-token provider (`src/semanticTokens.ts`) and Emacs
(`prologos-ts-mode.el`). **Neither carries its own copy. Do not add inline
highlight rules to either** — that is the duplication that let the query rot for
five months while VS Code's TextMate layer covered for it.

Each consumer contributes exactly one thing: a **capture → native face/token**
mapping. Full record + the open phases:
`docs/tracking/2026-08-14_0822_EDITOR_HIGHLIGHT_PARITY.md`.

### The vocabulary is the Neovim standard

Capture names follow `:help treesitter-highlight-groups`. A custom **LEAF** is
fine (`@variable.logic` is ours) because the dotted fallback lands it on a
standard root. A custom **ROOT** has nothing to fall back to and renders as
**nothing** in a stock consumer — that is what `@namespace` did until it became
`@module`. Pinned by `prologos-ts-test/captures-use-standard-roots`.

⚠ **Do NOT verify captures against a locally installed Neovim below 0.10.** The
pre-rename generation lacks `@variable.parameter`, `@attribute` and `@module` —
checking against it concludes our CORRECT captures are wrong and "fixes" them
backwards. Verify against Neovim **master**, or confirm the local nvim is 0.10+.

### ORDER IS SEMANTIC, in both consumers

The file is **first-match-wins by FILE ORDER**, not by specificity. A rule placed
below the general rule it was meant to beat is **vacuous** — it compiles and
never fires. The bare `(identifier) @variable` fallback must stay LAST.

Emacs reproduces this because `treesit-font-lock-settings` is applied in **LIST
order** — feature LEVEL does not reorder it (measured, not assumed). So settings
are emitted in file order and **`:override` is NEVER set**.

### ⭐ Verify captures FIRE, not that they compile

This class has bitten **four times**, and every instance had "0 patterns
skipped" true while rules painted nothing. Assert on actual captures/faces over
real snippets; "it parses" and "it compiles" both mean nothing here.

Three specific traps, all silent:
- **`#match?` uses EMACS regexp syntax in Emacs** (`(` and `|` are literal), and
  tree-sitter **unescapes the query string first**, so backslashes must be
  DOUBLED. Bridged by `prologos-ts--translate-regexp`, which RAISES on anything
  untranslatable so a bad pattern is skipped VISIBLY.
- **Match data.** Calling `string-match` inside a `replace-regexp-in-string`
  replacement function clobbers what it reads back — substitutions land one
  character short, producing a VALID capture name for a face that does not exist.
- **A capture with no mapping entry is silently dropped.** `@attribute` is
  dropped in VS Code today, deliberately.

### Editing the shared query

Run `./install.sh` after ANY `.scm` change — it copies the file to the VS Code
extension. The corpus gate measures the installed **parser** and does not see
`.scm` edits at all, so a green gate is NOT evidence the query is fine.
