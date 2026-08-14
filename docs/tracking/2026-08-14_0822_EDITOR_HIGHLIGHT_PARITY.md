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
| P0 | Capture registry + D1 renames (`namespace`->`module`, drop `.other`) | ⬜ | Kills drift cause 3 — [§3.1](#p0), [§D1](#d1). ⚠ verify the standard list upstream FIRST |
| P1 | Parity harness: one fixture, capture-by-capture, asserted in BOTH | ⬜ | Makes drift *detectable* — [§3.2](#p1) |
| P2 | TextMate: declared, and made to AGREE where it overlaps | ⬜ | Kills drift cause 1 — [§3.3](#p2), amended by [§7.4](#d3-critique) |
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
2. Anything else a native layer paints is **declared**, and where it overlaps
   the query the two must **agree** — tested. (Amended from "disjoint" by
   [§7.4](#d3-critique).)
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
### 3.3 (P2) TextMate declared, and made to agree

> ⚠ **AMENDED by [§7.4](#d3-critique).** This section originally required
> TextMate to be *disjoint* from the query. That is over-strict: it would
> foreclose TextMate's value as the portable format for consumers that never run
> our extension. The invariant is **agreement**, not disjointness — overlap is
> fine, disagreement is the bug. The text below is kept for the reasoning about
> why TextMate cannot simply be deleted; read its bullets through the amendment.

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

## 5. Decisions

<a id="d1"></a>
### D1 — vocabulary: ✅ RULED (2026-08-14) — adopt `nvim-treesitter` names

Owner: adopt, and note that community is the likely first third party, so set
them up well.

**We are closer than expected.** Classified 2026-08-14 — **16 of 20 already
standard**:

| status | captures |
|---|---|
| standard (16) | `attribute` `character` `comment` `constant.builtin` `constructor` `function` `keyword` `number` `operator` `property` `string` `type` `type.builtin` `type.definition` `variable` `variable.parameter` |
| **deprecated (1)** | `namespace` → **`module`** (nvim renamed it) |
| custom, standard root (3) | `constant.other` · `variable.other` · `variable.other.hole` |

The three customs are *legal* — the dotted convention means an unknown leaf
falls back to a standard root, so a consumer that has never heard of them still
gets a sensible colour. But `.other` carries no meaning. Proposed renames, to
be settled in P0:

| now | proposed | why |
|---|---|---|
| `@namespace` | `@module` | the upstream rename; free correctness |
| `@constant.other` | `@constant` | `.other` distinguishes it from nothing |
| `@variable.other` | `@variable.logic` | it is a logic variable (`?x`) — say so |
| `@variable.other.hole` | `@variable.hole` | typed holes; two levels bought nothing |

⚠ **Renaming is exactly the drift P0 exists to prevent, and proves the case:**
`@variable` maps to NO face in Emacs on purpose, so `@variable.logic` would fall
back to *nothing* unless the Emacs map gains an explicit entry in the same
commit. One rename, two files, silent loss if you forget.

⚠ The standard list above is from the convention as I know it and **must be
verified against upstream `nvim-treesitter` docs in P0** before we rename
anything. Getting it wrong is worse than not adopting.

<a id="d2"></a>
### D2 — registry format: 🔬 OPEN, analysis below

See [§6](#d2-analysis). Owner asked for tradeoffs and worked examples with room
to deliberate; no recommendation is being forced.

<a id="d3"></a>
### D3 — TextMate floor: 🔬 OPEN, critique below

See [§7](#d3-critique). Owner's leaning: TextMate as a fallback for when
tree-sitter is unreachable; strip down, then build back. Invited critique — and
there is a substantive one, which also **corrects §3.3 of this document**.

---

<a id="d2-analysis"></a>
## 6. D2 — how should the mapping be shared?

### The question behind the question

A third-party editor **cannot use our mappings**. They can use our *vocabulary*.
So "share the mapping" splits in two:

- **the vocabulary** — capture names + what each MEANS. Genuinely shared, and
  the thing a contributor needs.
- **the per-consumer mapping** — capture → face / token. Inherently one per
  editor. Putting ours in one file is convenience; it is not shared with anyone.

Whether those live in one file or two is the actual decision.

### Option A — one JSON registry, both consumers read it at runtime

```jsonc
// queries/captures.json
{ "variable.parameter": {
    "doc": "a bound parameter name",
    "vscode": { "type": "parameter", "modifiers": [] },
    "emacs":  { "face": "font-lock-variable-name-face" } } }
```
Emacs: `json-parse-buffer` at load. VS Code: `readFileSync` + `JSON.parse`.

**For** — one file to edit; no build step; no generated artifact to go stale;
a contributor reads one file to learn the whole vocabulary.
**Against** — every consumer's mapping is in a file the other consumer also
loads, so the file grows a section per editor and nobody's section is where
their code is; JSON has no comments (workable via `doc`); Emacs gains a runtime
file dependency (it already has one for `highlights.scm`, so this is marginal).

### Option B — one source, both mappings generated at build time

Source table → emits `captureMap.ts` and `prologos-ts-capture-map.el`.

**For** — native literals, no runtime parse; can validate at generation.
**Against** — a build step in two languages; **two generated files committed to
git, which someone will eventually hand-edit** — the classic failure of this
shape; and a stale generated file is a silent wrong-colour, the exact class we
are trying to leave. Buys little: the parse it avoids is ~20 entries.

### Option C — the `.scm` carries its own mapping in comments

**For** — literally one file.
**Against** — abuses the query format, no tooling understands it, and we would
be hand-parsing comments. Listed to be dismissed.

### Option D — keep two mappings, add a completeness TEST

No new format. A test asserts every capture in `highlights.scm` resolves in
both `CAPTURE_MAP` and `prologos-ts--capture-faces`.

**For** — smallest change; each mapping stays next to the code that uses it;
**and this test is needed under every option anyway**.
**Against** — no single place to read the vocabulary, so the contributor story
is "read two files in two languages and infer the convention".

### Option E — vocabulary file + per-consumer mappings + the test

`queries/captures.md` (or `.json`) defines names and meanings ONLY. Each
consumer keeps its own mapping beside its own code. The P0 test asserts
three-way completeness: vocabulary ⊇ what the `.scm` uses, and each mapping
covers the vocabulary.

**For** — puts the shared thing (meaning) in the shared place and the
per-editor thing (appearance) with that editor; the contributor doc is then
"here is the vocabulary, write your own mapping", which is the honest contract;
no consumer loads another consumer's data.
**Against** — three files instead of one; the vocabulary file can drift from
the `.scm` (which is what the test is for).

### What to weigh

1. **Which failure hurts more** — a mapping silently missing an entry (A and E
   prevent by construction only if the test exists; the test is what actually
   prevents it under all options), or a generated file going stale (B only)?
2. **Who is the reader?** If the contributor story is the point, E optimises for
   it and A is close behind. B and D are worst for it.
3. **Is a build step acceptable** in a repo whose editor tooling currently has
   none for Emacs?

⚠ Note the common factor: **the completeness test does the real work in every
option.** The format choice is mostly about the contributor's reading
experience, not about preventing drift. That is worth being explicit about
before spending deliberation on the format.

---

<a id="d3-critique"></a>
## 7. D3 — critique of "TextMate as fallback only"

Owner's leaning is right in intent, and I have three corrections plus one that
changes this document's own design.

### 7.1 "Fallback when TS is unreachable" is not a thing VS Code can express

TextMate is the language's *grammar*; it always runs. Semantic tokens **layer
over** it and win where they apply. There is no switch reading "use TextMate
only if semantic tokens are unavailable".

So the fallback the owner wants **already exists, automatically, in the
overlap** — and does not exist at all outside it. Outside the overlap TextMate
is not a fallback, it is the *permanent and only* authority. The design question
is therefore not "when does TextMate apply" but **"how much non-overlap do we
tolerate, and must the overlap agree?"**

### 7.2 The wasm dependency is a BUILD problem, not a runtime one

The `.wasm` ships inside the `.vsix`. For an installed extension tree-sitter is
always reachable. The genuinely-unreachable cases are narrower:

1. before the extension activates (a real, visible window on a cold open);
2. the user set `editor.semanticHighlighting.enabled: false`;
3. **our own dev loop with no emcc** — today's situation, and the one that
   actually bit.

(3) argues for **CI building the wasm**, not for shaping the grammar around it.
Letting a missing build tool dictate the highlighting architecture would be
solving the wrong problem.

### 7.3 The strongest argument against stripping: TextMate has its own audience

`.tmLanguage.json` is the portable syntax format for consumers that will never
run our extension — GitHub/Linguist being the obvious one, and Sublime-family
tools by conversion. We have not pursued that, so this is **option value rather
than current reach** — but stripping TextMate to comments-and-strings forecloses
it, and the cost of keeping it is only that it must not *disagree*.

### 7.4 ⭐ This corrects §3.3 of this document

I wrote that TextMate must be **disjoint** from the `.scm`. Given 7.1 and 7.3,
the better invariant is **agreement**:

> TextMate may paint anything. Where both layers paint the same span, they must
> agree. Overlap is fine; *disagreement* is the bug.

Same harness tests it, and it is strictly weaker — so it permits keeping a
useful TextMate grammar instead of forcing a strip. I think my original
"disjoint" was over-strict and would have thrown away 7.3 for tidiness.

### 7.5 On "strip everything down to see where both sides sit"

Endorse the intent, question the method. We do not have to *strip* to *see*: the
P1 harness can emit a per-span census of who paints what, with nothing removed.
Stripping first gives a period of visibly worse highlighting **with no instrument
to tell you whether it got worse** — the same shape as every other trap this
project has hit recently. Recommended order: census first, then cut with
evidence, then rebuild.

### 7.6 What I would put to the owner

Not a decision — the two coherent positions:

- **Keep TextMate reasonably complete**, enforce *agreement*, and treat it as
  the portable format for non-tree-sitter consumers (7.3).
- **Reduce it to a genuine bootstrap** (comments, strings, numbers), accept that
  a cold open is briefly plain, and give up the portable-format option.

Either is defensible. The first is where I would lean, on 7.3 alone — but 7.3
depends on whether Linguist/GitHub reach is something the owner wants, which is
a product question, not a technical one.
