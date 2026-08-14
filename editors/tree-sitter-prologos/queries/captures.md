# Prologos highlight capture vocabulary

The shared contract between `highlights.scm` and every editor that renders it.

This file defines **what each capture means**. It says nothing about colour, on
purpose: meaning is shared, appearance is per-editor. A consumer contributes
exactly one thing — a mapping from these names to its own faces or token types —
and keeps that mapping beside its own code.

Names follow the Neovim standard vocabulary
(`:help treesitter-highlight-groups`), verified against Neovim master
2026-08-14. A custom **leaf** is allowed where no standard one fits, but its
**root must be standard**, so an unfamiliar leaf still falls back to a sensible
colour in a consumer that has never heard of it.

## Adding an editor

1. Read the table below.
2. Write a `capture → your face/token` mapping in your own plugin.
3. Cover every row. Cover the **roots** too — see the policy below.

You do not need our mappings, and we do not need yours. The two shipped ones
(`prologos-ts--capture-faces` in `prologos-ts-mode.el`, `CAPTURE_MAP` in
`src/semanticTokens.ts`) are worth reading as precedent, not as an interface.

## The vocabulary is STRICT

**This table lists exactly the captures `highlights.scm` emits — no more, no
less.** There is no "reserved for later" class. A name nobody emits has no
meaning to document and no appearance to define; adding one is how a mapping
grows entries that are untested by construction and wrong when they finally go
live. Nine such entries accumulated in the VS Code map between its first commit
and 2026-08-14, five of them contradicted by rulings taken since; all were
removed. If a capture becomes real, it lands here and in the query in the same
change.

Enforced by `parity/check-vocabulary.sh`, in both directions.

## Roots policy

A mapping may also contain a **root** — a dotted-prefix ancestor of an emitted
capture, such as `constant` for `constant.builtin`. Roots are kept deliberately
and are NOT vocabulary:

- A **root** catches a whole family, including members that do not exist yet.
  Dropping `variable` today would change 60 of 205 captures in the parity
  fixture; `function` 21; `type` 9.
- A **speculative leaf** catches nothing the root would not already catch. It
  differs only when it adds a modifier — and that is an appearance decision you
  cannot make sensibly before you know what emits it.

So the rule the checker enforces is: **a mapping entry is legitimate iff it is
emitted, or it is a proper dotted-prefix ancestor of something emitted.** Roots
pass; speculative leaves fail. The two look identical in a diff, which is why
the distinction is a test and not a comment.

## The captures

| capture | means |
|---|---|
| `attribute` | multiplicity and metadata annotations (`:0`, `:1`, `:w`, and the keyword in a metadata / trait-metadata / law entry) |
| `character` | a character literal |
| `comment` | a comment; also the wildcard pattern `_` |
| `constant.builtin` | a built-in value constructor (`zero`, `nil`, `cons`, `true`, `false`, …) |
| `constructor` | a data constructor, both at declaration and in patterns |
| `function` | a name being DEFINED — `defn` / `def` / `spec` / `defmacro` / `defr` / relation / trait method |
| `keyword` | a reserved word, whether or not the grammar tokenizes it |
| `module` | a namespace path — an `ns` name or a `require` module |
| `number` | any numeric literal, including an ordinal path step |
| `operator` | an operator token, including goal-position `=` and the path-step operators |
| `property` | a field name — a map key, or a path-selection step |
| `string` | a string literal |
| `string.special.symbol` | a keyword literal (`:foo`) used as a value, not as a map key |
| `type` | a type in reference position |
| `type.builtin` | a built-in type (`Int`, `Bool`, `List`, `Option`, …) |
| `type.definition` | a type name being DEFINED — `data` / `trait` / `bundle` / `property` / `functor` / `capability` |
| `variable` | the fallback: an identifier with no more specific role |
| `variable.hole` | a typed hole (`??`, `??name`) |
| `variable.logic` | a logic variable (`?x`) in relational code |
| `variable.parameter` | a bound parameter name |

Two of these are custom leaves on standard roots: `variable.hole` and
`variable.logic`. Both are Prologos-specific concepts with no standard name, and
both degrade to `variable` in a consumer that does not know them.

## Known gaps

`parity/known-gaps.tsv` lists captures a consumer does not yet map, with the
reason. A gap there is a deliberate, reviewed exception — not a silent omission.
