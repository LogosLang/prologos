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
| P0 | Capture registry + D1 renames | ✅ | `7fd4445c`. D2 ruled **option E**; `queries/captures.md` + two-direction gate; 9 dead entries deleted. [§9](#p0-record) |
| P1 | Parity harness: one fixture, capture-by-capture, asserted in BOTH | ✅ | `30671d9d`. **Query layer is ALREADY in parity** — identical in both. Golden now **228** (was 205; the scanner fix made comments visible). [§8](#p1-record) |
| P2 | TextMate: declared, and made to AGREE where it overlaps | 🔄 | Census `81ac5a01` · scanner `e8b9ab0f` (comments 1%→100%) · **D3 ruled + agreement gate `294dbc0f`**. Remaining: fix the **5 disagreements**. [§10](#p2-record), [§12](#d3-ruled) |
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
| 1 | ✅ **CONFIRMED TextMate** ([§12](#d3-ruled)). Map `{}` keys blue, implicit-map keys orange | Explained in §1(2) — `@property` vs `@constant.other` through two scopes. A capture-level decision. | **P3** |
| 2 | Path-selection branches paint as keywords, not key chrome | Suspected TextMate showing through; `.scm` captures steps as `@property`. | **P2**, confirm in **P1** |
| 3 | `foray.prologos:712` — closing inner projection ≠ opening | `app-config{server.ssl.{enabled^-ssl cert-path^cert}}`; nested projection braces, and the `.scm` captures no brackets → TextMate. | **P2** |
| 4 | ✅ **CONFIRMED TextMate mis-lex** ([§12](#d3-ruled)). Fused `var:Type` mispaint | Probed: the grammar is right (`x`→parameter, `Int`→builtin type). So the mispaint is a layer above — TextMate, or the scope map. | **P2/P3**, confirm in **P1** |

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
gets a sensible colour. Proposed renames are in the verification below.

#### ✅ VERIFIED against upstream (2026-08-14) — P0 task 1, DONE

Checked against **Neovim master `runtime/doc/treesitter.txt`**
(`treesitter-highlight-groups`), which has owned the standard list since 0.9.
Result: **16 standard · 3 custom-with-valid-root · 1 broken.**

⚠ **A local copy is NOT a safe source.** This machine has nvim **0.9.4**, whose
doc is the *pre-rename* generation: it lists `@namespace @field @conditional
@parameter @float @include @repeat @exception @text.*` and contains **none** of
`@variable.parameter @attribute @module @number.float @keyword.import` — i.e.
none of the modern names, including two we already use. Verifying against it
would have produced the opposite conclusion. (Unrelated: that nvim binary is
currently broken — `dyld: Symbol not found: _ts_language_version`, its 0.9.4
build against tree-sitter 0.26.9. The doc file still reads fine.)

**Corrections to the pre-verification table:**

| capture | earlier claim | verified | action |
|---|---|---|---|
| `@namespace` | "deprecated → `@module`" | **worse — the ROOT `namespace` is not standard**, so it does not even fall back. A Neovim user's theme gives it *nothing* today. | → `@module` |
| `@constant.other` | "→ `@constant`" | `@constant` is valid, but **`@string.special.symbol` is the standard capture for symbols/atoms** — what Clojure `:foo` and Elixir `:foo` use. Prologos keyword literals are exactly that. | → `@string.special.symbol` (recommended) |
| `@variable.other` | "→ `@variable.logic`" | confirmed: no standard leaf fits a logic variable; custom leaf under a standard root is the idiomatic move | → `@variable.logic` |
| `@variable.other.hole` | "→ `@variable.hole`" | confirmed. (`@comment.todo` was considered — apt for a placeholder, wrong for a non-comment.) | → `@variable.hole` |

⭐ The `@string.special.symbol` finding is the one that pays for the
verification: it means a Neovim user's Prologos keyword literals would colour
**the same as their Clojure keywords**, with no theme configuration at all.
That is precisely the third-party leverage D1 was adopted for, and I would not
have got there from memory.

#### ✅ CONFIRMED by a SECOND, INDEPENDENT source (2026-08-14, later same day)

The owner upgraded Neovim **0.9.4 → 0.12.4**, so the *bundled* doc is now the
modern generation and can be cross-checked against the WebFetch of master used
above. Re-classified against `/opt/homebrew/share/nvim/runtime/doc/treesitter.txt`
(90 captures):

```
standard 18 · custom-with-valid-root 2 · BROKEN 0
```

Up from **16 / 3 / 1**. Both sources agree, including on `@string.special.symbol`
— which is the rename with the least intuition behind it, and therefore the one
most worth a second source. The single broken capture is gone: nothing we emit
now renders as *nothing* in a stock Neovim.

⚠ Note the local doc only became usable BECAUSE of the upgrade. At 0.9.4 it
would still have given the opposite answer. "Check it locally" is safe advice
only once you have verified which generation the local copy is.

**Toolchain re-verified after the upgrade** (tree-sitter also bumped): grammar
regenerated with no drift in the committed `src/parser.c`; corpus gate unmoved
(swallows 0, unparsed 1.6%, missing 77); Emacs ERT 63/63; `tsc --noEmit` clean.

⚠ **The tree-sitter CLI is effectively pinned, and that is load-bearing.**
`install.sh` prefers the repo-local `node_modules/.bin/tree-sitter` (**0.25.10**)
over PATH; Homebrew now carries **0.26.12**. That pin is what keeps the
generated parser reproducible against what is committed. Bumping the repo-local
CLI regenerates `parser.c` and is a deliberate act with its own verification —
not something to drift into by upgrading Homebrew.

**Still open in P0**: whether to take the `@string.special.symbol` recommendation
(it changes the VS Code colour of every `:keyword` — currently orange via
`constant.language`), and the Emacs-side lockstep noted above.

<a id="d2"></a>
### D2 — registry format: ✅ RULED (2026-08-14) — **option E**, strict vocabulary, roots policy. [§9](#p0-record)

See [§6](#d2-analysis). Owner asked for tradeoffs and worked examples with room
to deliberate; no recommendation is being forced.

<a id="d3"></a>
### D3 — TextMate floor: ✅ RULED (2026-08-14) — **keep it**; we want Linguist/GitHub reach. Invariant is AGREEMENT ([§7.4](#d3-critique)), enforced by `census.mjs --gate`. [§12](#d3-ruled)

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

---

<a id="p1-record"></a>
## 8. Per-phase records

### P1 — parity harness ✅ (2026-08-14, `30671d9d`)

`parity/` — `fixture.prologos` (0 ERROR nodes, exercises all 20 captures),
`golden.tsv` (205 rows), `dump-captures.el`, `dump-captures.mjs`,
`check-parity.sh`.

**Result: the two consumers already agree, byte for byte.** So the four
catalogued issues in §4 are **not** query-layer problems — P2 and P3 are acting
on the layers below (TextMate, `semanticTokenScopes`, the two mappings). That is
precisely the fact §4 wanted established before P2 moved, and it narrows P2:
three of the four were *suspected* TextMate, and the query layer is now excluded
as a cause rather than assumed innocent.

**⭐ The harness was wrong before the code was, and it would have blamed the
wrong editor.** The first dump used raw `treesit-query-capture`, skipping the
`#match?` translation. Emacs evaluates `#match?` in EMACS regexp dialect — `(`
and `|` are literal — so every identifier-matched capture fell through to the
`(identifier) @variable` fallback: `Int`/`String` → `@variable` rather than
`@type.builtin`, `zero` → `@variable`, `solve` → `@variable`. `type.builtin` is
the ONLY capture reachable *only* via `#match?`, which is why it was the single
visibly-missing one — a 19/20 that looked like a fixture-coverage gap and was
actually an instrument bug. Freezing that golden would have made VS Code (which
uses JS RegExp, and was correct) the reported divergence.

Fixed by extraction, not duplication: `prologos-ts-translate-query-predicates`
now has ONE home in `prologos-ts-mode.el` and is called by the font-lock builder
and the harness alike. Behaviour-preserving — 69 settings, 0 skipped.

**Golden shape ruling.** RAW captures, canonical `(line, col, capture)` order —
**not** the consumer's resolved first-match-wins view. `treesit-query-capture`
returns in NODE order, not query-file order, so implementing that rule in the
harness encodes one engine's traversal as the contract. Per-consumer resolution
is checked separately, if at all.

**Both power-checked** (a green gate proves nothing until seen red): disabling
the predicate bridge → 12 divergent lines; perturbing one golden row → exit 1.
The gate also refuses when the fixture gains an ERROR node, since captures
inside one vanish and the golden would shrink while staying green.

**Verified alongside**: the deployed `.wasm` is byte-identical to a fresh emcc
build, so both consumers genuinely run one grammar. ⚠ **Gap CLOSED 2026-08-14 (`72af1b02`)** — see below. It had been left open as
"worth closing in P2 or T1.close"; it bit twice before that.

**Not included**: capture → mapping completeness. That is P0's, P0 is blocked on
D2, and half-implementing it here would front-run the ruling.

---

<a id="p0-record"></a>
## 9. P0 record — D2 ruled, registry landed (2026-08-14, `7fd4445c`)

**Ruling: option E**, strict vocabulary, plus an explicit roots policy. The
owner's stated reason was **decomplection**, and it is the right frame: meaning
is shared, appearance is per-editor, and one registry carrying both was the
complecting move.

The argument that decided it over A was **coupling, not tidiness**. Under A both
consumers load one file, so a contributor editing *their* editor's section can
break an editor they have never opened. Under E that is impossible — and the
people it protects are exactly the third parties the track is for.

### ⚠ The premise in §1(3) was stale

Measured at HEAD before ruling: of 20 captures, **19 map exactly in both**. Three
of §1(3)'s four divergences had already been closed by D1's renames. The single
real gap is `attribute`, and it is deliberate — closing it is P3's colour
decision, not a mapping fix.

**So the problem D2 was framed to prevent — two mappings drifting — was one
documented gap. The actual mess was the opposite direction: nine entries in the
VS Code map that the query never emits.** Forward-only completeness, which is all
§3.1 specified, reports every one of them as healthy.

### The nine, and why each went

Provably dead: resolving all 205 fixture captures through the map and through
map-minus-nine gives **0 differing tokens** — and the claim rests on the `.scm`
never emitting those names, not on fixture coverage. All nine entered at
`498d990e`, the commit that *created* the provider: speculative vocabulary
written before the `.scm` was authoritative.

| group | entries | why |
|---|---|---|
| contradicted by a ruling | `punctuation`, `punctuation.bracket`, `punctuation.delimiter` | the `.scm` header rules brackets out as "highest-noise/lowest-information" |
| contradicted by a ruling | `macro` | `defmacro_form name` is deliberately `@function` |
| contradicted by a ruling | `parameter` | not nvim vocabulary (D1); `variable.parameter` already maps to the identical target |
| redundant | `function.call`, `punctuation.bracket`, `punctuation.delimiter` | the root produces a byte-identical token |
| open, but implausible | `variable.builtin`, `label` | Prologos has no `self`/`this` and no labels |
| open, plausible | `function.builtin` | deleted anyway — strict vocabulary admits no reserved class |

### Roots policy — enforced, not described

A root and a speculative leaf are indistinguishable in a diff, so the checker
decides: **an entry is legitimate iff it is emitted, or is a proper
dotted-prefix ancestor of something emitted.**

Roots earn it — dropping `variable` changes 60 of 205 captures, `function` 21,
`type` 9. A speculative leaf catches nothing its root would not, and differs only
by a modifier — an appearance decision that cannot be made before knowing what
emits it. `constant` (latent root of `constant.builtin`) passes; `function.call`
did not.

### What landed

`queries/captures.md` (contract, 20 captures, no colours) ·
`parity/check-vocabulary.sh` (both directions) · `parity/known-gaps.tsv` (the one
reviewed exception, ratchet-style) · nine entries deleted from `CAPTURE_MAP`.

⚠ Power-checked three ways, and the check found a bug in the checker itself:
`nreverse` is destructive, so the violation count read 1 while two failures
printed. Counted before reversing now.

---

<a id="p2-record"></a>
## 10. P2 record — the census, and what it found (2026-08-14, `81ac5a01`)

Per [§7.5](#d3-critique), census before cutting. `parity/census.mjs` reports, per
character span, which TextMate scope paints it and which capture claims it —
using `vscode-textmate` + `vscode-oniguruma`, the engine VS Code actually runs,
because TextMate patterns are Oniguruma and a JS-RegExp approximation would be
wrong in exactly the way that then drives the D3 product decision.

### ⭐⭐ `(comment) @comment` covers ~1% of the library, and both editors were covering for it

> ⚠ **CORRECTED 2026-08-14 (`ac3b97d4`).** This section first read
> "`@comment` is UNREACHABLE / produces ZERO nodes in real files". That
> generalized from a **two-file sample** — `eq.prologos` and `list.prologos`,
> both genuinely at zero and both among the 47 of 73 library files that are.
> The third gate measured the corpus: the rule fires **1394 times** and covers
> **~1%** of library comment lines. The defect and its diagnosis stand; the
> magnitude claim was wrong, and it was wrong in the direction that overstates.

| area | captures | `;` lines | coverage |
|---|---|---|---|
| `lib` (real WS Prologos) | 47 | 4064 | **1%** |
| `examples` | 1346 | 11631 | 12% |
| `editors/emacs/test` | 1 | 54 | 2% |
| **total** | 1394 | 15749 | **9%** |


Per-file zeros are common — `core/eq.prologos` 0 of 57, `data/list.prologos`
0 of 116 — but they are not universal, which is what the original claim missed.

The grammar declares comments correctly — `extras` at `grammar.js:34`, the rule
at `:1142`. The **external scanner** consumes them first: `src/scanner.c` (~:399)
skips comment-only lines while computing indentation, so the characters are gone
before the parser can tokenize the extra. The query rule is not wrong; it is
unreachable.

**Why five months passed without notice: each editor covers for it privately.**
Emacs paints comments from its **syntax table** (`prologos-ts-mode.el:262`) —
22 of 24 fixture comment lines fontified despite ~1 node. VS Code paints them
from **TextMate** (1121 fixture chars of `comment.line.semicolon.prologos`).

So a consumer reading only `highlights.scm` — *the audience this whole track is
for* — gets no comment highlighting at all. That is §1(1) one level down, and
strictly worse: there, one editor covered for the shared file; here **both**
cover for the **grammar**, by different private mechanisms, so comparing the two
editors to each other can never reveal it. P1 passes precisely because they agree
perfectly about the one capture they both barely receive.

### ⚠ A gap in the gates, now visible

A capture can be written in the query, documented in `captures.md`, and mapped by
every consumer, while the grammar emits no node for it. `check-vocabulary`
inspects the query TEXT; `check-parity` inspects consumer AGREEMENT. **Neither
asks whether the tree actually contains the node.** A third check —
"every capture fires at least once over the corpus" — would close it, and would
have caught this on day one.

### Consequence for P2's sequencing

The census's "TextMate only" bucket is dominated by comments (1121 of 1124
chars). That is not TextMate being over-broad — it is TextMate *compensating*.
Reducing TextMate before the scanner is fixed would delete the only thing
painting comments in VS Code. **P2 is therefore blocked on a TSG-side scanner
fix**, and D3 should not be ruled on the current census, because the biggest
number in it is an artifact of a defect rather than a real division of labour.

### ⚠ The third gate does not catch this either (added `ac3b97d4`)

`check-reachability.sh` asks whether a capture ever fires. `@comment` **passes**
it, with 1455 corpus hits, while being ~99% broken in the library. **"Fires
somewhere" is a floor, not a health check** — a capture can be 99% broken and
read as healthy.

Where an independent expected count exists, measure COVERAGE instead:
`check-reachability.sh --coverage` does that for comments (`;`-lines being a
cheap ground truth). That is the instrument the scanner fix moves, per area,
before and after. Reachability keeps its value for the *completely* dead case —
it just never had the resolution for this one.

### ✅ Unblocked — the scanner fix (2026-08-14, `e8b9ab0f`)

The scanner marked its token end AFTER looking past comment-only lines, so the
parser resumed beyond them. Fix: mark the end BEFORE the first comment and keep
looking ahead. **The layout decision is unchanged** — indentation still comes
from the next real line, which is why the loop skips comments at all; only the
token boundary moved.

| | before | after |
|---|---|---|
| comment coverage, `lib` | 1% | **100%** |
| comment coverage, total | 9% | **101%**\* |
| MISSING | 77 | **76** |
| unparsed | 1.6% | **1.3%** |
| error-bytes | 18193 | **14586** |
| ERROR count | 2689 | 2700 |

\* >100% is expected: the denominator counts `;`-starting lines, the numerator
counts comment TOKENS, so a trailing `foo ;; note` scores in one and not the
other. ERROR rising while error-bytes fall by 3607 is the documented
anti-correlation. Ratchet tightened to 1.3 / 76.

**What this does to the census — and therefore to D3.** "TextMate only" collapses
from **1124 chars (1121 of them comments) to 3**. The remainder is
`keyword.operator.quote` ×2 and one `constant.other.keyword`. So TextMate is now
almost entirely *redundant* with the query rather than *compensating* for it, and
**D3 can be ruled on evidence that means what it says** — which it could not,
one commit ago.

---

## 11. The wasm provenance gap — closed (2026-08-14, `72af1b02`)

The dylib carried provenance and `check-corpus.sh` refused a stale parser; the
wasm had neither, so VS Code's half of the shared grammar could drift silently.

**It bit twice in two sessions, both by the same route.** `install.sh` builds the
dylib first and the wasm second; the wasm step fails when emcc picks up a Python
older than 3.10 (Xcode ships 3.9). The failure is loud, but lands *after* the
dylib is installed — so the session ends with **Emacs on the new grammar and VS
Code on the old**, and every later parity run compares two different grammars and
reports the difference as a finding.

- `install.sh` writes `<wasm>.provenance` beside both copies, same fields and same
  `SRC_HASH` inputs as the dylib — so "current" means one thing for both.
  Verified: both now report `ecc916df762c`.
- `check-parity.sh` exits 3 on a stale or unprovenanced wasm, distinguishing
  **absent** / **unprovenanced** / **stale** (printing both hashes).
- A skipped wasm build does **not** delete an existing wasm — it may still be
  valid, and deleting it would silently disable VS Code semantic tokens.

Power-checked in all four states. Also fixed: `--emacs-only` used to print
"PASS — both consumers agree" after checking one consumer; it now states what it
ran and that the run says nothing about parity.

---

<a id="d3-ruled"></a>
## 12. D3 ruled, and the agreement gate (2026-08-14, `294dbc0f`)

**Ruling: keep TextMate reasonably complete.** The owner wants Linguist/GitHub
reach, which is §7.3's option value made concrete, so TextMate is the portable
syntax format for consumers that never run our extension. Invariant is
**agreement** (§7.4), enforced by `census.mjs --gate` against
`queries/textmate-agreement.tsv`.

That file is a **vocabulary↔vocabulary** correspondence, not a third consumer
mapping — TextMate scope names are the same standard Linguist consumes — so it
lives beside `captures.md`.

### ⭐ The refinement that makes the invariant usable

**TextMate being LESS SPECIFIC is not a disagreement.** `defn foo` and a
reference to `foo` are the same regex; TextMate structurally cannot tell a
definition from a variable. `@function` over `variable.other` is the semantic
layer *adding* information — the point of the layering — not a contradiction.
`*GENERIC*` names the scopes meaning "nothing more specific to say".

Effect: 10 pairs / 150 chars → **5 pairs / 24 chars**, and everything removed was
expected by construction.

### ⚠ The gate's first run was wrong, and the output's implausibility is what caught it

It compared TextMate against the committed **golden**, which is deliberately RAW
(every match, canonically sorted) because that is the right contract for
comparing two ENGINES. Wrong input here: it still carries the
`(identifier) @variable` fallback rows that first-match-wins discards, so it
reported `Int` as `@variable`-vs-`support.type` when the consumer paints
`@type.builtin` and the layers agree. The census now resolves exactly as
`semanticTokens.ts` does. Same lesson as P1, one layer along: **right data, wrong
question.**

### The five real disagreements

| chars | capture | TextMate scope | what it is |
|---|---|---|---|
| 10 | `@property` | `constant.other.keyword` | map keys `:key` — **issue #1** |
| 6 | `@keyword` | `constant.other.keyword` | `:refer` |
| 4 | `@module` | `keyword.control.declaration` | the `ns` / `require` line |
| 3 | `@type.builtin` | `constant.other.keyword` | `Int` in `x:Int` — **issue #4** |
| 1 | `@comment` | `keyword.operator.wildcard` | the `_` pattern |

**Issues #1 and #4 are now CONFIRMED TextMate**, with the query excluded as a
cause rather than assumed innocent — exactly what P1 and P2 existed to establish.
#4 is a TextMate mis-lex: it reads the `:Int` of a fused annotation as a keyword
literal.
