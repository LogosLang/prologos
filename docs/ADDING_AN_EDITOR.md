# Adding an editor to Prologos

This document tells you how to add Prologos syntax support to a new editor.

It is written in Simplified Technical English. Sentences are short. Each
sentence gives one instruction. The same word always has the same meaning.

## Glossary

Read this list first. This document uses these terms exactly.

- **Editor** — a program that shows Prologos code. Emacs and VS Code are the two
  editors today. `queries/captures.md` calls the same thing a *consumer*.
- **Grammar** — the tree-sitter parser. The source is `grammar.js` and
  `src/scanner.c`. The build makes two artifacts. See "The grammar" below.
- **Query** — the file `queries/highlights.scm`. It marks parts of the tree with
  capture names.
- **Capture** — a name such as `@keyword` or `@type.builtin`. A capture states
  meaning. A capture does not state colour.
- **Mapping** — a table in your editor plugin. It maps each capture to a face or
  to a token type in your editor.
- **Gate** — a script that checks one obligation. A gate exits 0 on success. A
  gate exits non-zero on failure.

## The contract in one sentence

The project owns the grammar, the query, and the capture vocabulary. You own one
mapping from captures to your editor's own faces.

## What you must not do

Do not copy `highlights.scm` into your plugin. Do not write highlight rules
inside your plugin.

Both editors read the one shared query. A second copy goes stale. A private copy
went stale for five months, and no test could see it.

## The grammar

The build makes two artifacts from the same source.

| artifact | used by | installed to |
|---|---|---|
| `libtree-sitter-prologos.dylib` | Emacs | `~/.emacs.d/tree-sitter/` |
| `tree-sitter-prologos.wasm` | VS Code | `editors/vscode-prologos/grammars/` |

`install.sh` also copies `queries/highlights.scm` to
`editors/vscode-prologos/queries/`. That copy is a build output. Do not edit it.

Each artifact has a `.provenance` file. The file records a hash of the source.
The gates compare that hash. A gate refuses a stale artifact and exits 3.

To build and install both artifacts, run this command from
`editors/tree-sitter-prologos/`:

```bash
./install.sh
```

Run `./install.sh` before you run any gate. The gates measure the installed
artifact. The gates do not read `grammar.js`.

## Steps to add an editor

1. Install the grammar for your editor. Use the artifact your editor needs.
2. Read `editors/tree-sitter-prologos/queries/captures.md`. It lists every
   capture and its meaning.
3. Write a mapping in your plugin. Map each capture to a face or a token type.
4. Cover every capture in the table. Also cover the **roots**. `captures.md`
   gives the roots policy.
5. Load `queries/highlights.scm` at run time. Do not copy it.
6. Write a dump program for your editor. See "The parity harness" below.
7. Run every gate. See the next section.

## The parity harness

`parity/check-parity.sh` compares each editor against one recorded file,
`parity/golden.tsv`. It does not compare the editors to each other directly.

The harness holds one dump program for each editor:

- `parity/dump-captures.el` for Emacs.
- `parity/dump-captures.mjs` for VS Code.

Each program reads `parity/fixture.prologos` through the shared query. Each
program writes one row for each capture. A row has four fields, separated by tab
characters:

| field | meaning |
|---|---|
| 1 | line number |
| 2 | column number |
| 3 | capture name, without the `@` |
| 4 | the source text |

To add a third editor, do these steps:

1. Write a dump program for your editor. Emit the four fields above.
2. Add a call to that program in `parity/check-parity.sh`.
3. Compare its output against `parity/golden.tsv`.

⚠ `golden.tsv` is a record, not a target. A difference means the query changed or
your mapping is wrong. Find the cause first. Update `golden.tsv` only after you
know why it changed.

## The gates, and what each one proves

Run all gates from `editors/tree-sitter-prologos/`.

| gate | proves |
|---|---|
| `./check-corpus.sh` | The grammar parses real Prologos code. |
| `parity/check-parity.sh` | Every editor sees the same captures. |
| `parity/check-vocabulary.sh` | Every capture is documented and mapped. |
| `parity/check-reachability.sh` | Every declared capture fires at least once. |
| `parity/census.mjs --gate` | TextMate and tree-sitter agree where they overlap. |
| `parity/check-tokens.mjs` | Every VS Code token is in the legend and has a colour. |
| `parity/check-regexps.sh` | Every `#match?` regex works in every editor. |

A green gate proves one thing only. A green gate says nothing about the question
another gate asks. Run all of them.

## Rules you must not break

### One meaning, one place

The query states meaning. Your mapping states appearance. Do not put meaning in
your mapping. Do not put appearance in the query.

### `#match?` is read in two dialects

VS Code reads `#match?` patterns as PCRE. Emacs reads the same patterns as Emacs
regexps. In an Emacs regexp, the characters `(`, `)` and `|` are literal.

The pattern `^(Int|Bool)$` therefore matches nothing in Emacs. The rule is dead,
and Emacs reports no error.

`prologos-ts--translate-regexp` in `prologos-ts-mode.el` converts the pattern for
Emacs. It raises an error on any pattern it cannot convert.

Run `parity/check-regexps.sh` after you change any `#match?` pattern.

### A capture with no mapping entry is dropped

Your editor drops a capture that your mapping does not list. Your editor reports
no error. The text keeps its default colour.

`parity/check-vocabulary.sh` finds this. Run it.

### Query rule order decides the result

The query is first-match-wins by **file order**. A rule below a more general rule
never fires. Such a rule compiles, and it paints nothing.

Keep the general `(identifier) @variable` rule last.

## Known traps

These traps have each cost this project real time.

1. **A stale grammar does not fail.** Tree-sitter recovers from a parse error. It
   makes `ERROR` nodes and continues. Highlighting then degrades, and nothing
   reports a problem. Run `./check-corpus.sh` to measure this.
2. **Emacs maps a grammar file one time for each session.** `./install.sh`
   replaces the file on disk. The running Emacs keeps the old parser. Start a new
   Emacs after a grammar change. A reload does not clear it.
3. **`emcc` needs Python 3.10 or later.** It may select an older Python. Then
   `install.sh` builds the dylib and fails on the wasm. Emacs gets the new
   grammar and VS Code keeps the old one. Set `EMSDK_PYTHON` to a Python 3.10 or
   later binary.
4. **A gate reads the raw text of the query.** A comment that contains a token
   such as `#match?` can change what a gate finds. Two gates have failed this
   way. Test a gate against comment text before you trust it.

## Prove that your gate can fail

Add a gate only if you can make it fail on purpose.

1. Build the gate.
2. Break the input on purpose. Confirm that the gate exits non-zero.
3. Repair the input. Confirm that the gate exits 0.
4. Write down what the gate cannot see.

A gate that has never failed may be checking nothing. Three rules in this project
compiled correctly, fired never, and passed every gate.

## Where the files are

All paths start at the repository root.

| file | what it is |
|---|---|
| `editors/tree-sitter-prologos/grammar.js` | grammar source |
| `editors/tree-sitter-prologos/src/scanner.c` | external scanner source |
| `editors/tree-sitter-prologos/queries/highlights.scm` | the shared query |
| `editors/tree-sitter-prologos/queries/captures.md` | the capture vocabulary |
| `editors/tree-sitter-prologos/install.sh` | builds and installs both artifacts |
| `editors/tree-sitter-prologos/parity/` | the gates and their data |
| `editors/emacs/prologos-ts-mode.el` | the Emacs mapping, in `prologos-ts--capture-faces` |
| `editors/vscode-prologos/src/semanticTokens.ts` | the VS Code mapping, in `CAPTURE_MAP` |
| `editors/vscode-prologos/syntaxes/prologos.tmLanguage.json` | the TextMate grammar |

## TextMate

The project keeps a TextMate grammar. GitHub and Linguist use it. Your editor
probably does not need it.

If your editor uses TextMate, it must agree with the tree-sitter result. The gate
`parity/census.mjs --gate` checks this. Recorded exceptions are in
`parity/known-gaps.tsv`, one row for each exception, with a reason.

## Questions

Read `docs/tracking/2026-08-14_0822_EDITOR_HIGHLIGHT_PARITY.md`. It records why
each rule above exists, and what happened when the rule was absent.
