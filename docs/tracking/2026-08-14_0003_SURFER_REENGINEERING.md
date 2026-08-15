# Surfer Re-engineering — SURF Track 1

**Status**: ⬜ **UNBLOCKED, not started** — TSG T1 closed the grammar blocker
(§0 is kept as the record of why this track stopped) · **Opened** 2026-08-14 ·
**Owner rulings** in §2 and §0.

⚠ **Before implementing P1, re-check the node model against the REPAIRED
grammar.** It now has `pvec_literal`, `path_expr` and its step nodes, three
scanner tokens, and a unified `angle_group` — so the tree this track will
navigate is materially different from the one §4.1 was designed against.

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
| P0 | WS-mode fixture | ✅ | `test/surfer-sample.prologos` — compiler-clean (0 errors) |
| P1 | **Breadcrumb — MEASURE the layout walk on real files** | ⬜ | Settles the two open unknowns by inspection, not taste: show the current line or only its ancestors, and how to truncate |
| P2 | **Breadcrumb — implement** (layout only, no LSP, no dependency) | ⬜ | [§4.3](#p3). Ships and is usable on its own |
| P3 | **Spike — dump `surf-*` trees for real files** | ⬜ | srcloc coverage · granularity · degenerate wrappers. Decides whether the compiler tree is navigable before we build an endpoint for it |
| P4 | LSP structure endpoint | ⬜ | Ask for *the tree*; never encode "full reparse" — [§2b](#carrier) |
| P5 | Node model over the compiler tree | ⬜ | [§4.1](#p1-node-model). Re-check against the repaired grammar's shape |
| P6 | Transient session: entry/exit, one overlay, `C-M-*` | ⬜ | The gopcaml mechanism — [§4.2](#p2) |
| P7 | Selection: mark node, expand/contract | ⬜ | `C-M-SPC` |
| P8 | Integration: retire the old model, defcustoms, docs | ⬜ | Old surfer's 67 tests mostly encode the retired model |
| P9 | SURF T1.close | ⬜ | |

⚠ **Resequenced 2026-08-15 (owner).** The breadcrumb moved to the front. It was
P3 of 6 and is now P1–P2 of 9. Old → new: P3→P2, P1→P5, P2→P6, P4→P7, P5→P8,
P6→P9. Three reasons the new order is better: the breadcrumb has **no
dependency** on the LSP work and can ship alone; it is the only always-on
surface, so it earns feedback earliest; and the spike (P3) tells us whether the
compiler tree is navigable **before** we spend a phase building an endpoint to
serve it.

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

<a id="carrier"></a>
## 2b. Carrier decision (2026-08-15)

**R4 — owner ruling: the HYBRID.** Layout carries the always-on breadcrumb.
The compiler tree, fetched over LSP once per session, carries navigation.
Tree-sitter keeps font-lock and stops being load-bearing for the surfer.

Measured basis: warm LSP round trip **0.6 ms**; parse of the largest corpus file
**10.9 ms** after PARSE T1. Session entry therefore costs about **12 ms**.

### ⚠ Owner correction — incrementality is a temporary gap, not a property

The tradeoff table listed "not incremental, a full reparse per fetch" as a cost
of the compiler carrier. That is a **statement about today, not about the
design**. Incremental compilation is a stated project goal, reached through the
propagator network and cell persistence — `.claude/rules/stratification.md`
§ "Candidate Future Strata" says compiler passes are stratum-separable and that
running them as BSP strata "gives incremental-compilation for free via cell
persistence".

The groundwork is visible in the code already. The parse **is** the cell
pipeline: `parse-string-to-cells` builds cells on a `prop-network`. The merge
creates per-form cells and `driver.rkt:2564` records their state as
*"cells landed, propagator wiring unbuilt"* (PPN Master row 3), explicitly not
abandonment.

**Three consequences for this design, and they are not cosmetic:**

1. **Tree-sitter's remaining edge is temporary.** Incremental reparse was its
   one durable advantage over the compiler. It expires.
2. **Do NOT build a staleness layer.** A stale-tree cache with position
   re-anchoring (gopcaml's `of_state_immediate`) is scaffolding that incremental
   compilation makes redundant. Keep the fallback to layout, which is already
   written and costs nothing. This is the `workflow.md` red flag applied ahead
   of time rather than after.
3. **Shape the request for incrementality now.** The session asks for *the tree*
   and lets the server decide whether it recomputed or reused. Do not put "full
   reparse" into the protocol, and do not let the client hold a tree it believes
   it owns.

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

<a id="p1-measured"></a>
## 6. P1 — the breadcrumb, measured (2026-08-15)

The layout walk implemented as a probe and run over every non-blank,
non-comment line in `lib/` — **6,769 positions**. No grammar, no compiler: the
walk takes each strictly-less-indented line above, which is exactly what the
breadcrumb will have at runtime.

### Depth of the path

| | |
|---|---|
| mean | 1.10 |
| median | 1 |
| p90 / p99 / max | 3 / 4 / 9 |

Distribution: **0 ancestors 41%** · 1 → 26% · 2 → 21% · 3 → 8% · 4 → 3% · 5+ → ~0%

### Width

| | median | p90 | p99 | max |
|---|---|---|---|---|
| segment length | 20 | 45 | 90 | 99 |
| total, ancestors only | 18 | 74 | 157 | 290 |
| total, including the current line | 51 | 118 | 206 | 334 |

### What it settles

**Unknown 1 — show the current line, or only its ancestors?** Ancestors-only is
**empty 41% of the time**, because two-fifths of positions sit on a top-level
line with nothing above them. A header line that is blank two-fifths of the time
costs a screen row and returns nothing. Pure ancestors-only is therefore out;
the choice is between always including the current line (redundant at depth 0)
and adding a constant root segment so the path is never empty.

**Unknown 2 — truncation.** A per-segment cap near **24 characters** keeps the
median segment (20) whole and cuts the tail (p90 45, max 99). Depth ≥4 is **3%**
of positions, so middle-elision is a rare path, not the common one. No adaptive
width scheme is needed to start.

### ⭐ An argument for layout that the type-based options cannot answer

Real paths from the corpus:

```
def app-config  ›  :server  ›  :ssl  ›  [:cert-path "/etc/ssl/cert.pem"]
def app-config  ›  :admins  ›  - :name "Alice"  ›  [:role :super]
defn fib-rec [a b n]  ›  match n  ›  | _ ->  ›  [fib-rec b .(a + b) .(n - 1)]
```

The first two navigate a **data structure**, not code. `def app-config › :server
› :ssl` tells you which subsection of a config map you are editing. A node-type
breadcrumb renders the same position as `map › entry › map › entry`, which is
information-free. Layout handles code and data with one rule.

<a id="p3-spike"></a>
## 7. P3 — the surf-tree spike (2026-08-15)

Reflective walk over the surface tree for five real files. Route copied from
`tools/spine-census.rkt`: `read-to-tree` → `group-tree-node` → `refine-tag` →
`rewrite-tree` → `parse-top-level-forms-from-tree`.

| file | nodes | depth | located | struct-form | list-form | degenerate |
|---|---|---|---|---|---|---|
| core/io | 87 | 2 | 99% | 86 | 0 | 0% |
| core/eq | 170 | 6 | 86% | 95 | 51 | 2% |
| core/collections | 1067 | 6 | 98% | 164 | 886 | 0% |
| core/conversions | 197 | 3 | **26%** | 42 | 9 | 0% |
| examples/foray | 1541 | 8 | 91% | 698 | 711 | 5% |
| **total** | **3062** | | **90%** | 1085 | 1657 | **3%** |

### The tree is navigable — three findings in its favour

1. **It is small and shallow.** 87 to 1541 nodes, depth 2 to 8. The tree-sitter
   tree over the same `lib/` had `expression` alone appearing **34,138** times as
   a pure wrapper. Session payload is not a concern.
2. **Degenerate wrappers are 3%**, against tree-sitter's pervasive wrapping.
   §4.1's extent-collapse rule was designed against the tree-sitter tree. Against
   the compiler tree it is close to unnecessary — keep it, but it stops being
   load-bearing.
3. **90% of nodes carry a position.**

### ⚠⚠ The finding that matters: TWO location representations

The last field is a position in two different shapes:

- a `srcloc` **struct** — 1085 nodes
- a plain **4-element list** `(line col start end)` — **1657 nodes, the majority**

`surf-node-srcloc`, the shipped reflective extractor this design leans on,
tests `(srcloc? last)` and returns `#f` otherwise. **It therefore returns `#f`
for roughly 60% of tree-parser-produced nodes.** The premise that generic
extraction gives us position coverage for free is true structurally and false in
practice until the extractor accepts both shapes.

⚠ It has **3 production call sites** (`driver.rkt` ×2, `elaborator.rkt`). Whether
that degrades error locations today is **unverified** and worth checking on its
own account — it is not only a surfer concern.

### ⚠ My own measurement was wrong first, in the direction that would have killed the design

The first corrected run reported **35% located** and I was about to report it as
a blocker. The detector recognised only the struct form. The list form is the
majority, so the true figure is 90%. Two walker defects preceded it: counting
`srcloc` structs as tree nodes, and recursing into them.

### Caveats on scope

- This is the **tree spine**, not the merged production surfs. 279 `error` nodes
  include `"ns: consumed by preparse"` — expected here, because production merges
  the tree spine with preparse surfs and falls back per form.
- `conversions.prologos` at 26% located is the outlier and correlates with its
  146 error nodes. Unexplained.
- Before P4, re-run against the **merged** surfs. `merge-preparse-and-tree-parser`
  is not exported, so that needs a small export.
