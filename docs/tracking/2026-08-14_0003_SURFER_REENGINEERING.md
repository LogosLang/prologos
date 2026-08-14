# Surfer Re-engineering — SURF Track 1

**Status**: ⏸️ **BLOCKED** on the tree-sitter grammar — see [§0](#blocked) ·
**Opened** 2026-08-14 · **Owner rulings** in §2 and §0.

Re-engineering `prologos-surfer-mode` after it was disabled in practice (the
`use-package` block in the owner's config has been commented out for a while).
The reference is [gopcaml-mode](https://gitlab.com/gopiandcode/gopcaml-mode)
(local clone: `~/dev/assay/ocaml/TAPL/gopcaml-mode`), followed **loosely** — we
take its interaction model, not its implementation.

> **Scope note on process**: this is Emacs tooling, not compiler work. The design
> mantra, the NTT model requirement and the SRE lattice lens are all scoped to
> the propagator network and do **not** apply here. Recording that explicitly
> rather than performing them vacuously — a gate applied where it has no purchase
> is cataloguing, which `CRITIQUE_METHODOLOGY.org` names as the failure mode.

---

<a id="blocked"></a>
## 0. ⏸️ BLOCKED — the grammar cannot carry this yet (measured 2026-08-14)

P0 wrote a WS-mode fixture and validated it through the compiler: **0 errors, 7
forms**. The same file yields **7 `ERROR` nodes** under tree-sitter. That prompted
a corpus scan, and the result stops the track:

| measure | value |
|---|---|
| `grammar.js` last touched | **2026-03-11** (`899b2263c`) — five months; LET, ARROW and Rel T1 all landed after |
| library files scanned | 51 |
| files parsing **clean** | **14** |
| files with `ERROR` nodes | **37** (73%) |
| total `ERROR` nodes | **2,123** (`conversions.prologos`: 498 in 828 lines) |

`core/` alone holds 1,866, clustered by the leading token of the offending line:
`defn` **779** · `(fn` 272 · `spec` 191 · `|` 124 · `:forall` 63 · `def` 55 ·
`foreign` 45 · `trait` 39. `defr` — the entire Rel T1 relational syntax —
appears **zero** times in `grammar.js`.

**So this is not lag on new syntax; it fails on `defn`, `spec`, `def`, `trait`,
the core of the language.** A surfer built here would be erratic in ~3/4 of real
files and would be blamed for it. Note the blast radius is wider than the surfer:
`prologos-ts-mode` font-lock runs off the same tree.

**Owner ruling (2026-08-14): fix the grammar FIRST.** SURF T1 resumes when the
corpus parses clean. Tracked as **TSG Track 1** —
`2026-08-14_0030_TREE_SITTER_GRAMMAR_REPAIR.md`.

⚠ **Method note, third instance this session.** The registry path was invisible
to greps; the cold-start bug was invisible to 48 green unit tests; this was
invisible until the corpus was actually parsed. In each case the *instrument*,
not the reasoning, was the binding constraint. The design above was sound and
would still have produced a broken tool.

---

## Progress Tracker

| Phase | Description | Status | Notes |
|---|---|---|---|
| P0 | WS-mode fixture + test scaffold | ✅ | `test/surfer-sample.prologos` — compiler-clean (0 errors). Existing `test/sample.prologos` is **sexp mode**, wrong shape for a layout surfer |
| P1 | Node model: navigable nodes, extent-collapse, parent/child/sibling (pure, no UI) | ⏸️ | **Blocked on TSG T1** — [§0](#blocked). Design stands; the tree under it does not |
| P2 | Transient session: entry/exit, single overlay, `C-M-*` motions | ⬜ | The gopcaml mechanism — [§4.2](#p2) |
| P3 | Header-line breadcrumb (the always-on component) | ⬜ | [§4.3](#p3) |
| P4 | Selection: mark node, expand/contract | ⬜ | `C-M-SPC` |
| P5 | Integration: retire the old model, defcustoms, docs, reload-script note | ⬜ | Old surfer's 67 tests mostly encode the retired model |
| P6 | SURF T1.close — bench-free close, DEFERRED triage, PIR-lite | ⬜ | |

**Deferred to SURF Track 2**: structural *transformation* (gopcaml's
move-forward/back, transpose, structural kill/copy). Owner ruling: navigation
first, get the feel right before anything edits text.

---

## 1. Why the old one was disabled

Not a tuning problem — the noise is architectural. `prologos-surfer.el` installs
a `post-command-hook` with a 50 ms debounce that recomputes the enclosing scope
and repaints on **every cursor movement** (`:271`). Three effects compound:

1. **Always-on** — the highlight is ambient chrome that changes constantly in
   peripheral vision.
2. **Background tint over a whole region** — competes with syntax highlighting
   *and* with the selection face.
3. **Depth tinting** — eight generated faces (`:172`), so the colour *shifts* as
   you cross nesting levels. Motion in the periphery, triggered by motion.

### The framing that matters

The original goal was "different parts of the AST as visible as parens are in
Lisp". That analogy is what produced the noise, and it does not hold:

> Parens are **text** — static, part of what you read, and they do not move when
> your cursor does. An overlay is **chrome** that tracks the cursor. Making
> chrome behave like text is the mistake.

gopcaml does not attempt it. It makes structure visible **on demand** — exactly
while you are operating on it — and invisible otherwise.

---

## 2. Owner rulings (2026-08-14)

| # | Question | Ruling |
|---|---|---|
| R1 | What stays always-on? | **Header-line breadcrumb** of the AST path at point (`defn nth › match › arm`). Nothing is ever painted over the text. |
| R2 | Transformation now? | **Navigation first.** Transformation is SURF Track 2. |
| R3 | Keys | **`C-M-*` takeover**, gopcaml-style. The standard sexp motions are near-useless in a layout-sensitive language, so they are the natural home. |

---

## 3. What we take from gopcaml, and what we do not

**Take — the interaction model.** A structural command builds a cursor over the
tree, stores it buffer-locally, creates **one** overlay, and calls
`set-transient-map MAP t #'on-exit`. Movement keys move cursor + overlay + point
together. **Any other keystroke exits**, and `on-exit` deletes the overlay and
the state. Verified in the clone: `gopcaml-mode.el` `gopcaml-zipper-mode-and-move`
→ `set-transient-map` (`:305`), `gopcaml-on-exit-zipper-mode` deletes the zipper
and overlay.

**Do not take — the Huet zipper and the dynamic module.** gopcaml needs a real
zipper because it performs AST *transformations* and must keep structure
consistent across them; it pays for that with an OCaml dynamic module, a
hand-written 89 KB `ast_zipper.ml`, and an AST cache with dirty-region tracking
and idle rebuilds. We have **tree-sitter**, which already gives incremental
reparse and a node cursor. For navigation-only (R2) a node + parent/sibling walk
is sufficient and is what the current code already does correctly.

⚠ **The zipper question returns in SURF T2.** Tree-sitter nodes are invalidated
by buffer edits, so a transformation phase must re-locate after every edit
(cheap — reparse is incremental, re-find by position) or hold its own structure.
That is a T2 decision, deliberately not pre-empted here.

---

## 4. Design

<a id="p1"></a>
### 4.1 (P1) Node model — the one rule that matters

**Navigation must NOT use a curated node-type whitelist.** The current code
carries `prologos-surfer--scope-node-types`, a hand-maintained list of ~12 types
(`prologos-surfer.el:65`). This is the exact shape of the failure
`.claude/rules/pipeline.md` § "Exhaustive Walkers" documents: a hand-armed list
meets a node kind it has no entry for, and the fallback does the wrong thing
**silently** — here, a new grammar construct is simply un-navigable, with no
error and nothing to notice. The grammar evolves; the list would rot.

Instead:

- **Navigate all *named* nodes.** Tree-sitter's named/anonymous distinction
  already excludes punctuation and keyword tokens, and it comes from the grammar
  rather than from a list a human maintains. New constructs are navigable **by
  construction**.
- **Collapse degenerate steps.** A node whose extent equals its parent's (a pure
  wrapper) makes up/down feel like nothing happened. Skip while extents are
  equal. This is a structural rule, not a list — it needs no maintenance.

**The label table is allowed to stay a whitelist**, and the distinction is the
point: a missing navigation entry fails **silently** (construct unreachable); a
missing *label* entry fails **visibly** (breadcrumb shows `match_arm` instead of
`arm` — legible, merely less pretty). Whitelists are acceptable exactly where
their failure mode is visible.

<a id="p2"></a>
### 4.2 (P2) The transient session

```
first C-M-* keypress
  ├─ ensure parser
  ├─ locate innermost navigable node at point
  ├─ create ONE overlay on it
  └─ set-transient-map SESSION-MAP t #'end-session

subsequent C-M-* → move node, move-overlay, goto-char (node start)
any other key    → transient map lapses → end-session → overlay deleted, state nil
```

`C-g` and ESC exit for free: they are not in the session map, so the keep-pred
drops it. No advice needed (unlike the result overlays, which are not transient).

Motions, following gopcaml: `C-M-u` up · `C-M-d` down · `C-M-n`/`C-M-p` next/prev
sibling · `C-M-f`/`C-M-b` forward/backward in document order.

<a id="p3"></a>
### 4.3 (P3) Header-line breadcrumb

The always-on component, and the only one. Computed from point's ancestry, shown
as `defn nth › match › arm`. Costs one screen line and **zero** pixels over the
code.

Update on `post-command-hook`, but recompute the *string* only when the node
identity changes (the existing overlay code already uses this comparison,
`prologos-surfer.el:204`) — so ordinary motion inside one node is free.

---

## 5. Per-phase records

*(filled in as phases land — headline + link, per the tracker-notes rule)*

---

## 6. Open questions

- **Q1** — Should the breadcrumb elide long paths (head `…` tail) or scroll? Defer
  until we see real paths in real files.
- **Q2** — Does `C-M-*` collide with anything in the owner's Spacemacs/evil setup?
  To be checked against a live config at P2, not assumed.
