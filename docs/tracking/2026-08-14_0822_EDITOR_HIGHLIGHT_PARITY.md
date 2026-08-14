# Editor Highlight Parity — EHP Track 1

**Status**: 🔄 charted, not started · **Opened** 2026-08-14 · **Depends on**
TSG T1 (closed) and the Emacs migration (`ac9d4ae3`).

Make `queries/highlights.scm` the **single source of truth** for Prologos syntax
highlighting, consumed identically by Emacs and VS Code — and specify the
contract well enough that a third editor is a *mapping table*, not a port.

> The owner is only targeting these two editors (the 80% case, and their own).
> The point of the track is not breadth: it is putting the **build-once**
> claim into practice on tooling, where it can actually be verified.

---

## Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| P0 | Capture registry: one machine-readable table both consumers read | ⬜ | Kills drift cause 3 — [§3.1](#p0) |
| P1 | Parity harness: one fixture, capture-by-capture, asserted in BOTH | ⬜ | Makes drift *detectable* — [§3.2](#p1) |
| P2 | Reduce TextMate to a declared, disjoint bootstrap | ⬜ | Kills drift cause 1 — [§3.3](#p2) |
| P3 | Review `semanticTokenScopes` per capture | ⬜ | Kills drift cause 2; settles the blue/orange class — [§3.4](#p3) |
| P4 | The four catalogued issues, on the repaired base | ⬜ | [§4](#issues) |
| P5 | `#match?` dialect lint (or retire the predicate) | ⬜ | [§3.5](#p5) |
| P6 | `docs/ADDING_AN_EDITOR.md` — the contributor contract | ⬜ | The deliverable that makes this leverage |
| P7 | EHP T1.close — PIR-lite, DEFERRED triage | ⬜ | |

---

## 1. Where we actually are

Emacs reads `highlights.scm` as of `ac9d4ae3`. That was *one* of the two halves.
"Write once" is still not true, and the reasons are structural, not cosmetic.

**VS Code renders through THREE layers; Emacs through one.**

```
  VS Code:  TextMate grammar  ─┐
            highlights.scm ──► semantic tokens ──► semanticTokenScopes ──► THEME
  Emacs:    highlights.scm ──► faces
```

### The three drift causes, each measured 2026-08-14

**(1) TextMate shows through.** The extension still ships
`syntaxes/prologos.tmLanguage.json` — 32 scope assignments — always on.
Wherever the `.scm` is silent, VS Code still paints and Emacs does not. This is
why the shared file could rot for five months without anyone noticing: **the
editor that most people looked at was covering for it.**

**(2) The theme never sees our captures.** `semanticTokenScopes` remaps every
token type onto a TextMate scope, and the theme colours *that*. Worked example,
which is exactly the owner's first catalogued issue:

| source | capture | token | scope | renders |
|---|---|---|---|---|
| `{:name 1}` | `@property` | `property` | `variable.other.property.prologos` | **blue** |
| bare `:kw` | `@constant.other` | `variable`+`readonly` | `constant.language.prologos` | **orange** |

Not a bug — the `.scm` deliberately calls map keys properties, and two scopes
render differently. But it means **a capture's colour is decided two hops away
from the capture**, in a file nobody edits when they edit the query.

**(3) Two hand-maintained consumer mappings.** `CAPTURE_MAP`
(src/semanticTokens.ts) and `prologos-ts--capture-faces` (prologos-ts-mode.el)
are independent. Measured across the 20 captures the file actually uses:

| capture | VS Code | Emacs |
|---|---|---|
| `attribute` — multiplicity, metadata | **dropped entirely** | `prologos-multiplicity-face` |
| `character` — char literals | **dropped entirely** | `font-lock-string-face` |
| `variable.other.hole` — typed holes | collapses to `variable` | `prologos-hole-face` |
| `constant.other` | collapses to `constant` | `font-lock-constant-face` |

**The shared file already specifies more than VS Code consumes**, and nothing
reports it.

---

## 2. The target

1. `highlights.scm` is authoritative for everything it captures.
2. Anything else a native layer paints is **declared, disjoint, and tested** to
   be disjoint.
3. Each consumer contributes exactly one thing: a **capture → native face/token
   mapping**, drawn from one shared registry.
4. Divergence is a **test failure**, not a discovery.

---

## 3. Design

<a id="p0"></a>
### 3.1 (P0) One capture registry

`queries/captures.json` — the canonical vocabulary, read by both consumers:

```jsonc
{ "variable.parameter": {
    "doc":   "a bound parameter name",
    "vscode": { "type": "parameter", "modifiers": [] },
    "emacs":  { "face": "font-lock-variable-name-face" } },
  "attribute": {
    "doc":   "multiplicity + metadata annotations",
    "vscode": { "type": "decorator", "modifiers": [] },
    "emacs":  { "face": "prologos-multiplicity-face" } } }
```

- Keep the **dotted-prefix fallback** in both consumers — the queries rely on it.
- **Vocabulary**: stay aligned with the de-facto `nvim-treesitter` capture names
  the file already follows loosely. That is the whole third-party argument: a
  contributor already knows what `@variable.parameter` means, and only has to
  say what it looks like in *their* editor.
- **Test**: every capture appearing in `highlights.scm` has a registry entry,
  and every registry entry resolves in both consumers. `attribute` and
  `character` fail this today.

<a id="p1"></a>
### 3.2 (P1) The parity harness — the load-bearing phase

One fixture; a golden list of `(line, col, capture)`; asserted from **both**
consumers. Emacs via ERT; VS Code via a node harness over the same
`web-tree-sitter` path `semanticTokens.ts` uses.

This is what converts "build once" from a claim into a property. Note the
ordering rationale: **P1 lands before P2**, because reducing TextMate is exactly
the change most likely to silently remove colour, and the harness is what would
catch it.

<a id="p2"></a>
### 3.3 (P2) TextMate reduced to a declared bootstrap

TextMate cannot simply be deleted: semantic tokens arrive only after activation
and a parse, and a user can switch them off
(`editor.semanticHighlighting.enabled`). So it stays — but scoped:

- **Allowed**: a documented, disjoint set. Brackets and delimiters are the
  honest case — `highlights.scm` explicitly declines them, with a reason.
- **Forbidden**: anything the `.scm` also captures.
- **Test**: over the fixture, no TextMate scope lands on an offset a capture
  claims. Overlap becomes a failure rather than a mystery.

<a id="p3"></a>
### 3.4 (P3) `semanticTokenScopes` reviewed per capture

Right now it is a legacy of the TextMate-first design and nobody revisits it
when the query changes. Fold it into the registry (P0), make each mapping an
explicit choice with a comment, and settle the blue/orange class of questions
**at the capture level, where it belongs** — one place, both editors.

<a id="p5"></a>
### 3.5 (P5) The `#match?` dialect hazard

Emacs evaluates `#match?` with **Emacs** regexp syntax and needs the backslashes
doubled through tree-sitter's string unescaping; VS Code gets PCRE. Bridged in
`prologos-ts--translate-regexp`, which raises on anything untranslatable — but
the shared file can still be written in a dialect one side cannot honour, and
the failure is a **silently dead rule**.

Two candidate resolutions, to be decided in-phase: lint the regexes to the
translatable subset, or reduce `#match?` usage by promoting those words to
grammar tokens (which would also fix `[trait x]`-style questions at the source).

---

<a id="issues"></a>
## 4. The four catalogued issues, and where they land

| # | Issue | Diagnosis | Phase |
|---|---|---|---|
| 1 | Map `{}` keys blue, implicit-map keys orange | Explained in §1(2) — `@property` vs `@constant.other` through two scopes. A capture-level decision. | **P3** |
| 2 | Path-selection branches paint as keywords, not key chrome | Suspected TextMate showing through; `.scm` captures steps as `@property`. | **P2**, confirm in **P1** |
| 3 | `foray.prologos:712` — closing inner projection ≠ opening | `app-config{server.ssl.{enabled^-ssl cert-path^cert}}`; nested projection braces, and the `.scm` captures no brackets → TextMate. | **P2** |
| 4 | Fused `var:Type` mispaint (regression from path selection) | Probed: the grammar is right (`x`→parameter, `Int`→builtin type). So the mispaint is a layer above — TextMate, or the scope map. | **P2/P3**, confirm in **P1** |

⚠ Three of four are *suspected* TextMate. That suspicion is exactly what P1
exists to convert into fact before P2 acts on it — colours cannot be read
headlessly, so the harness is the instrument.

---

## 5. Open decisions

- **D1 — vocabulary**: adopt `nvim-treesitter` capture names as the contract
  (recommended: maximum third-party leverage), or define a Prologos-specific set?
- **D2 — registry format**: JSON (both read natively) vs generating both
  mappings from one source at build time. JSON is simpler and has no build step.
- **D3 — TextMate floor**: how much is the bootstrap allowed to paint? Comments
  and strings only, or also brackets/delimiters?
