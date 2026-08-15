# Handoff — SURF Track 1, resuming at P2 (the breadcrumb)

**Written** 2026-08-15 · **Structure** per `principles/HANDOFF_PROTOCOL.org` §1–§6

---

## §1: Current Work State (PRECISE)

| | |
|---|---|
| **Track / phase** | SURF Track 1 (surfer re-engineering), resuming at **P2** |
| **Design doc** | `docs/tracking/2026-08-14_0003_SURFER_REENGINEERING.md` |
| **Last commit** | `7abaa421` — dailies LOG (i) |
| **Last code commit** | `fff2d09d` — `ws-string->surfs` exposed |
| **Branch / checkout** | local `main`, **MAIN CHECKOUT** |
| **Working tree** | owner WIP only — **11 paths**, incl. `foray.prologos` and four deleted `principles/*.md`. **LEAVE THEM.** Stage explicit paths, never stash. `editors/` is CLEAN |
| **Suite** | ✅ 10224 / 488 / 0, 180.9 s — fresh at `0e34bc15`; nothing since touched compiler surface except `fff2d09d` (additive export, targeted 236/236) |
| **Editor gates** | 8/8 green at `c7c7f796`; untouched since |

### Progress tracker (copied from the design doc)

| Phase | Description | Status |
|---|---|---|
| P0 | WS-mode fixture | ✅ |
| P1 | Breadcrumb — MEASURE the layout walk | ✅ [§6](../2026-08-14_0003_SURFER_REENGINEERING.md) |
| P2 | **Breadcrumb — implement** (layout only, no LSP) | ⬜ **NEXT** |
| P3 | Spike — dump `surf-*` trees | ✅ §7–§9 |
| P4 | LSP structure endpoint | ⬜ (cost measured, §10) |
| P5 | Node model over the compiler tree | ⬜ |
| P6 | Transient session, one overlay, `C-M-*` | ⬜ |
| P7 | Selection: mark, expand/contract | ⬜ |
| P8 | Integration: retire the old model | ⬜ |
| P9 | SURF T1.close | ⬜ |

### Next immediate task

**P2 — implement the header-line breadcrumb, layout only.** One design question
must be answered first, and it is a *choice*, not a measurement (P1 already
measured it): **at depth 0 — 41% of positions — does the breadcrumb show the
current line, or a constant root segment such as the namespace?** Ancestors-only
is ruled out; it leaves the header blank two-fifths of the time.

Everything else for P2 is settled: segments are the node's own first line
truncated to ~24 chars, ancestors are found by walking to each strictly-less-
indented line, separator `›`, middle-elision is a rare path (depth ≥4 is 3%).

---

## §2: Documents to Hot-Load (ORDERED)

### §2a — Always-Load

1. `CLAUDE.md` + `CLAUDE.local.md`
2. `MEMORY.md` (auto-memory index)
3. `DESIGN_METHODOLOGY.org`
4. `DESIGN_PRINCIPLES.org`

### §2b — Architectural Rules (auto-loaded; these are the load-bearing ones here)

1. **`.claude/rules/tree-sitter-grammar.md`** — the eight gates, the instrument
   rule, **COMPILER-IS-AUTHORITY**, the per-file A/B. Most-cited this session.
2. `.claude/rules/workflow.md` — § **Fail-Open**, § Relay Protocol, the
   phase-completion checklist, the tracker-notes rule.
3. `.claude/rules/pipeline.md` — § **Exhaustive Walkers** (the reflective-walk
   pattern this track's node model rests on).
4. `.claude/rules/testing.md` — § bench A/B (one wall-clock reading is not a
   measurement — violated twice this session).

The mantra / NTT / SRE-lattice rules **do not apply**: this is Emacs tooling, not
propagator work. The design doc says so explicitly rather than performing them.

### §2c — Session-Specific (read IN FULL)

1. **`docs/tracking/2026-08-14_0003_SURFER_REENGINEERING.md`** — the track. §2
   and §2b are the rulings; §6–§10 are this session's measurements.
2. `docs/tracking/standups/2026-08-15_dailies.md` — STATE head + LOG (i).
3. `docs/tracking/2026-08-02_LOC_TO_LINE_MERGE_DEFECT.md` — **§0 only**.
   Load-bearing: it is why we do *not* touch the location extractor.
4. `~/dev/assay/ocaml/TAPL/gopcaml-mode` — `readme.md` § Architecture, and
   `gopcaml-mode.el`'s `set-transient-map` / `gopcaml-on-exit-zipper-mode`.
5. `docs/tracking/2026-08-15_1218_WS_PARSE_CUBIC.md` — PARSE T1, ✅ closed.
   Read only if touching parse performance.

---

## §3: Key Design Decisions (RATIONALE) — do NOT revisit without cause

| # | Decision | Why |
|---|---|---|
| **R1** | The header-line breadcrumb is the **only** always-on element. Nothing paints over the text. | The old surfer repainted a depth-tinted background on every cursor move. Parens are *text*; an overlay is *chrome*. Making chrome behave like text produced the noise. |
| **R2** | **Navigation first.** Transformation is SURF T2. | Get the interaction right before anything edits a buffer. |
| **R3** | **`C-M-*` takeover**, gopcaml-style. | The standard sexp motions are near-useless in a layout-sensitive language. |
| **R4** | **The HYBRID carrier**: layout for the breadcrumb, the compiler tree over LSP for the session. Tree-sitter keeps font-lock and stops being load-bearing. | gopcaml links `compiler-libs` — it never used tree-sitter. Our own ambient rule says the compiler is the authority. Two grammars for one language drifted five months / 8336 errors / two repair tracks. |
| — | **Incrementality is a temporary gap, not a property** (owner). | Consequences: tree-sitter's edge expires; **do not build a stale-tree layer**; the request asks for *the tree*, never encoding "full reparse". |
| — | Breadcrumb segments are **the node's own first line**, ancestors chosen by the **indentation walk**. | No table at any layer. Navigation reads all nodes, segments read text, depth reads positions — so §4.1's anti-whitelist property holds *by construction* everywhere. Rejected: node types + significance table (needs the compiler tree continuously, so incompatible with R4; and a *filtering* table's miss is silent). |
| — | Phases resequenced, breadcrumb first. | No LSP dependency, only always-on surface, and the spike runs before an endpoint it could disqualify. |

---

## §4: Surprises and Non-Obvious Findings (highest risk to get wrong)

1. **⛔ Do NOT teach `surf-node-srcloc` the list form.** We agreed to; the
   measurement says no. The merged production tree has **zero** list-form
   locations — the list form is a **tree-spine** artifact, and the spine is
   deliberately off. It would be dead code *and* would reopen the 0-based /
   1-based hazard closed by `2026-08-02_LOC_TO_LINE_MERGE_DEFECT.md`, whose §0
   opens by saying its own "minimal fix" *would have shipped a silent
   wrong-answer bug*.
2. **41% of positions have NO ancestors.** Ancestors-only leaves the header blank
   two-fifths of the time. Taste would have chosen wrong.
3. **The 8% of unlocated nodes is ONE struct**: `binder-info` (520/523), which is
   `(name mult type)` and has no location field **by design**. Effective coverage
   over real source nodes is ~100%, not 92%.
4. **`io.prologos` produces ZERO surfs, correctly** — `ns` + 8 `foreign` +
   comments, all preparse-consumed. ⚠ So the P4 endpoint **must** distinguish
   "parsed fine, no navigable forms" from "failed to parse".
5. **`collections`' depth 14 is a TYPE**, not code: `surf-defn` → five nested
   `surf-pi` → sigma/arrow/app, all at one or two source positions (the implicit
   binders of `map`'s type). Descending them moves the cursor nowhere.
6. **Position-collapse removes 30–72% of nodes**, not the 3% first measured. The
   strict test wanted *exactly one* struct child AND a matching position; only
   the position match is needed.
7. **PARSE T1 fixed the smaller half.** `read-to-tree` is now 10% of production
   parse; preparse+merge is 90% and superlinear at ~n^1.6.
8. **`get-document-symbols` is LINE REGEXES**, not AST — the LSP has no
   AST-backed structure today.
9. **Warm LSP round trip is 0.6 ms.** IPC was never the constraint.

---

## §5: Open Questions and Deferred Work

- **P2 blocker (a choice, not a measurement)**: what the breadcrumb shows at
  depth 0 — the current line, or a constant namespace root.
- **P4 input**: the empty-tree vs failed-parse distinction (§4 item 4).
- **Unmeasured**: whether `surf-node-srcloc` returning `#f` on tree-parser nodes
  degrades **error locations** today. 3 production call sites. Not a surfer
  concern; worth its own look.
- **Candidate track**: preparse+merge is ~n^1.6. A 100 KB file approaches a
  second. Not urgent.
- Truncation width and middle-elision: crude rule first, tune on real files.
- `DEFERRED.md` **NEXT FREE 144**. Open grammar items: **141**, **143**.
- SURF T2 (transformation) is deferred by R2.

---

## §6: Process Notes

- ⭐ **Design decisions go in conversation PROSE, never `AskUserQuestion` chips.**
  Owner, 2026-08-15: chips "do not give us the depth enough to make informed
  choices". Memory: `design-decisions-in-prose`.
- ⭐ **Define terminology on first use in conversation**, not only in the file.
  "R4" was used as if established when it existed only in the doc.
- ⭐ **Measure, do not reason** — and then check the instrument. This session
  produced **five** wrong measurements before their right ones (walker counted
  srcloc structs as nodes; recursed into them; knew only one location form;
  measured the tree spine not production; a cold single run 25× off). The fix
  every time was to **print an actual value** instead of reasoning about an
  aggregate.
- **Fail-open is 5-of-N** — `core.hooksPath`, the audit anchor, `activate()`'s
  early return, the stale grammar, `parse_ms`. Past the threshold for a
  `DEVELOPMENT_LESSONS.org` entry.
- `~/.spacemacs` and the owner's Emacs config are **READ-ONLY** — diagnose,
  report the exact line, never edit.
- **Never say "restart Emacs"** — `M-x prologos-reload`. Exception: a
  grammar/scanner change, which needs a fresh Emacs and a full VS Code restart.
- Do **not** report push status. **Do** confirm the owner's WIP survived.
- PIR waived for PARSE T1 (lighter track); the objective PIR gate still applies
  to SURF T1.
