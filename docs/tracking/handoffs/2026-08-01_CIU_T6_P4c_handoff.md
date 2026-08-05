# Handoff — CIU Track 6 Path Selection: P4c-2's mint + unwrap LANDED; the slice closes on condition (c)

**Date**: 2026-08-01 · **For**: a fresh session finishing **D4.P4c-2** and continuing P4c-3..5.
Per `HANDOFF_PROTOCOL.org`. **ON-DISK IS AUTHORITATIVE.**

> **Hot-load protocol**: read §1–§6 here FIRST, then §2a, then EVERY §2c doc
> **in full** — then **summarize your understanding back to the owner and let
> them validate it BEFORE starting work.**

> ⚠ The live surface law: **dot DESCENDS · brace SELECTS `x{…}` · `:`
> BROADCASTS · `^` RE-KEYS · `*` FLATTENS · `<` DISCLOSES.** Anything phrased
> "dot extracts · bracket selects", or PS1–PS15, is SUPERSEDED. The spec is a
> **GUIDE**; where it and D4 differ, **D4's recorded adaptation wins.**

---

## §1 — Current Work State (PRECISE)

- **Series / Track / Phase**: CIU → Track 6 Path Selection → **D4.P4c-2**,
  status **🔄** (mint + unwrap landed; **condition (c) outstanding**).
- **Design doc**: `docs/tracking/2026-07-28_CIU_T6_PATH_SELECTION_D4.md` (D4).
- **HEAD at write**: `b1399016` — ⚠ **re-derive with `git rev-parse HEAD`.**
  HEAD moved mid-session twice in the P4 arc and origin advanced EXTERNALLY once.
- Local `main`, **MAIN CHECKOUT**. ⚠ If the session launches in a worktree,
  REMOVE it (it happened twice in the P3 arc; verify 0 unique commits first).
- **Suite** GREEN **9758 / 478 files / 0** (full, at `b1399016`) · **battery
  312** (`grep -c '^(test-case' tests/test-path-selection.rkt` — **MEASURE,
  never derive**; a derived count already caused one false regression hunt) ·
  acceptance path-selection **52/52** · **corpus A/B 161 files ZERO diffs**.
- **15 unpushed**, origin/main `07b79b52` — **do NOT push unless directed.**
- **Working tree**: pre-existing **owner WIP only (41 entries) — LEAVE ALONE.**
  Stage EXPLICIT paths · verify `git diff --cached --name-status` · **NEVER
  `git stash`** · no Co-Authored-By · long messages via `git commit -F`.

### Progress (authoritative copy in D4's tracker)

| Phase | Status |
|---|---|
| P0–P3 ✅ · **P4a ✅ `2cef148b`** · **P4b ✅ COMPLETE** (`f77702bb` close) | done |
| **P4c-1 ✅ `182f1678`** — prerequisites + classifier promotion; A/B ZERO | done |
| **P4c-2 🔄 `b1399016`** — mint + binder unwrap landed; **condition (c) owed** | **← HERE** |
| P4c-3 (the `(@bcast step)` kind, 13 sites) · P4c-4 (PVec broadcast + L1/extent) · P4c-5 (`.*name` retirement + residue) | ⬜ |
| P4d · P4e · P5 · PX · X.close (PIR-gated) | ⬜ |

### NEXT IMMEDIATE TASK

**Finish P4c-2 by landing Q_U16 condition (c)** — the LOUD-REFUSAL hardening at
the **17 binder-consumer sites** (11 `fused-type-annot?` + 6 `colon-symbol?`,
across 8 functions; coordinates in §4). When a binder consumer meets a
`$bcast-step` it did not expect, it must emit a guided *"a broadcast step cannot
appear in a binder position"* error rather than falling to a generic arm.
**Until it lands the binder table's failure mode is SILENT** — the 3-arity
class — which is exactly the property the ruling booked the hardening to remove.
Then P4c-2 flips ✅ and P4c-3 opens.

---

## §2 — Documents to Hot-Load (ORDERED)

**§2a Always-Load**: `CLAUDE.md` + `CLAUDE.local.md` · `MEMORY.md` +
`ciu-t6-records.md` (**the tail block = live state**) · `DESIGN_METHODOLOGY.org`
(Stage-4 per-phase protocol) · `DESIGN_PRINCIPLES.org` · `CRITIQUE_METHODOLOGY.org`
· `HANDOFF_PROTOCOL.org` · `MASTER_ROADMAP.org` · CIU master
`docs/tracking/2026-03-21_CIU_MASTER.md`.

**§2b rules** (auto-loaded; load-bearing here): **`prologos-syntax.md` § Reader**
(both modes, always) · **`pipeline.md`** (§ Exhaustive Walkers — P4c-3 IS this
rule; § New AST Node) · `testing.md` (targeted runner; `bench-ab` has NO
`--ref`) · `workflow.md` (5-step gate; adversarial VAG; belt-and-suspenders is
BLOCKING) · `on-network.md` (zero-propagator v1 has a NAMED trigger).

**§2c Session-Specific — READ IN FULL, IN THIS ORDER:**

1. **D4** — §3's **Q_U16 / Q_U16b** blocks (the ruling that made P4c
   buildable, with the refuted alternatives) · **§5.P4c in full** (partition,
   prerequisites, the ten named hazards, doc-truth repairs) · **§5.P4c-1** and
   **§5.P4c-2** (the measured binder table + the close notes) · **§Q8**
   (normative; esp. **Q8.3** the `:` seam and **Q8.5 invariant 3**) · §2.3
   carrier table · §8 R6.
2. Dailies `docs/tracking/standups/2026-07-28_dailies.md` — the **STATE head**
   + the last **4** LOG entries. The file interleaves several arcs; read by
   entry TITLE.
3. Memory `ciu-t6-records.md` — **the tail block**. Mid-file is history.
4. `docs/tracking/DEFERRED.md` — **CIU T6 items 24–31** (31 is P4c-1's).
5. `racket/prologos/examples/2026-07-26-ciu-t6-path-selection.prologos` — the
   `[D4.P4]` lines; 52 live markers; **the marker gate renumbers on mid-file
   uncomment — land trailing markers first.**
6. The spec `docs/research/2026-07-28_path-selection-spec.md` — a GUIDE.
   §3.1–§3.2 · §3.5 · §3.7 · §5.2–§5.4 · §10.2/10.4/10.5/10.7.

---

## §3 — Key Design Decisions (do NOT revisit without census-grade cause)

- **Q_U16 — the binder unwrap lives at the READER POST-PASS.** Q_U8 as ruled
  was **NOT implementable**: §Q8.5 site 8 (join `access-sentinel?` + take a fold
  arm) and parser position-dispatch are MUTUALLY EXCLUSIVE, because the preparse
  fold RUNS OVER BINDER POSITIONS (probe: `defn f [x.a] x` → a **3-arity
  function at ZERO errors**). So: mint uniformly at grouping · `$bcast-step`
  JOINS `access-sentinel?` and inherits all FOUR fold seats · the unwrap moves
  to `transform-let-blocks-stx`/`-elems`, which provably precede all four.
  **Both surfaces survive** — the owner ruled fused `x:Int` MORE important than
  broadcast, and `:` stays the glyph.
  Rejected-with-reason: **moving the glyph off `:`** (owner preference; also
  blocked — no candidate verified to lex intact) · **retiring fused `[x:Int]`**
  (cheapest by far, owner declined) · **parser-side fusion without membership**
  (refuted: `rewrite-dot-access` has FOUR seats and TWO run inside PREPARSE, so
  `users:name` would work in plain application and break inside `|>`, `.( )`
  and map literals; and the `$brace-params` precedent is the WRONG structural
  class — it is self-contained and never fuses, while **every base-consuming
  marker in the tree is an `access-sentinel?` member**).
- **Q_U16b — `users:0` IS a legal ω step.** Hence the `colon-annotation`
  classifier promotion at P4c-1. The rival (a pattern-provenance field on
  `token-entry`) lost on MEASURED cost: **25 constructor sites / 7 files**, and
  `sre-rewrite.rkt` borrows the struct as a general-purpose term carrier — a
  struct-OWNERSHIP question. Filed separately on its own merits, **not** as a
  scheduled revert (that would be the dual-path shape the rules block).
- **The binder table is MEASURED, not enumerated** (D4 §5.P4c-2). Members:
  `def` `defn` `fn` `spec` `let` `property` `functor` `trait`(method params)
  `rel` `defr` **and `$pipe` ARMS** (defn AND match). Immune: `?x:T` (glued to
  ONE token by `narrow-var-annot`), branch-initial `:k`, every SPACED spelling.
  `impl` needs no entry — recursion reaches its inner `defn`.
- **Inherited and still locked**: Q_U5 one carrier · Q_U6 wholesale · Q_U7 the
  `(@bcast step)` wrapper (extent structural; L1 fusion a THEOREM the battery
  pins) · Q_U9 `:` refuses over `List` · Q_U13 NEST · Q_U15 `$select-path` ·
  the `update-in` ω fence · the whole-node abort · zero-propagator v1.
  **Next free Q-label: U17.**

---

## §4 — Surprises (HIGHEST RE-DERIVATION RISK)

1. **The A/B answer is ZERO, and the design says SEVEN.** §5.P4c's named
   seven-site diff set was computed against the mint WITHOUT Q_U16's unwrap.
   With it those sites **round-trip** (mint→unwrap = identity), so the datum
   never moves: 161 files, zero diffs. **Do not read the mismatch as a broken
   gate** — it discriminates: `users:Int` → `($bcast-step :Int)` while
   `let x:Int 5` → `(let x :Int 5 x)`, same lexeme.
2. **The payload is the COLON-SYMBOL, wrapped VERBATIM** — `($bcast-step
   |:name|)`, never a stripped `name`. Stripping at the mint plus re-adding `:`
   at the unwrap is a SECOND copy of the recognizer's accept-set — the F1b.7g
   class. The unwrap is a plain `cadr`. (My pins first encoded the violation.)
3. **`apply-binder-unwrap` must guard non-list `kids`.** `classify-let-block`'s
   FAIL path returns a SYNTAX OBJECT wrapping `($let-error …)`. An unguarded
   `(car kids)` turned a contained let-LAYOUT error into a WHOLE-FILE ABORT —
   the defect parse-reader.rkt's own "CONTRACT REPAIR" note documents, and I
   reintroduced it one screen below that note. Caught by test-let-blocks' pin
   *"a top-level let-block LAYOUT error is CONTAINED, not a file abort."*
4. **The unwrap needs THREE rules, not one**: terminator-bounded (`def`/`let`/
   `$pipe` — up to `:=`/`->`, never past, so bodies keep their broadcasts) ·
   param-head **SCAN** (`rel` is a SIBLING in `def q := rel [a:Int] …`, not a
   head — a head-test structurally cannot see it) · **deep** (`trait`: method
   params sit under the METHOD NAME; safe ONLY because trait bodies are
   signatures — **narrow this entry if `trait` gains default bodies**).
5. **The discriminator is the SPELLING, not the form.** Every form with a
   bracketed param group is a member for the bare-name spelling, so the table is
   NEAR-UNIVERSAL — materially larger than the five entries Q_U16 implied when
   its cost was booked. Recorded as a correction, not absorbed.
6. **The tree already solves this collision lexically, for one vocabulary.**
   `?x:Nat` never mints because `narrow-var-annot` glues it into ONE token — the
   `?` is a lexical "this is a binder" marker. That is the shape a future
   simplification would take (X.close should weigh it); NOT proposed for v1.
7. **`ident-continue?` accepts `*` and `^`**, so `users:tags*` and
   `users:name^alias` arrive as SINGLE keyword tokens with the operator swallowed
   into the step NAME. Refusing them guidedly needs an explicit lexeme check —
   an enumeration. And `:name^alias` otherwise slips past parser.rkt's
   `^`-refusal. **Unowned; must be ruled at P4c-3/4, not discovered.**
8. **The `.prologos` safety net does not exist** — all would-mint files are
   UNGATED. The only suite-RED tripwire was the eight datum pins at
   `tests/test-parse-reader.rkt:494-516`, now flipped and annotated as
   DELIBERATE. Their neighbours `x:0abc`/`x:10abc` and `{:10 v}`/`{:0 v}` must
   **NOT** move: admitting bare `colon` to the trigger breaks both.
9. **The targeted runner ABORTS `test-path-selection.rkt` at 30 s** and
   `--timeout` does not help. A direct
   `racket -e '(require (file "…/tests/test-path-selection.rkt"))'` completes
   clean — use that for the track file, the runner for the neighbourhood.
   **⚠ Background `racket tools/…` runs need `cd racket/prologos` first**; the
   session cwd is the repo root and a backgrounded `cd` does not persist.

---

## §5 — Open Questions and Deferred Work

- **⬜ Q_U16 condition (c)** — the loud-refusal hardening. **THE NEXT TASK.**
  Sites: `fused-type-annot?` at parser.rkt **:4344 :4356 :5389 :5398** and
  macros.rkt **:2404 :2495 :2496 :5080 :5228 :5230 :5326**; `colon-symbol?` at
  parser.rkt **:4345 :5390 :5415 :6086 :6108 :6117** (the last three are
  `parse-rel-params`, the `defr` path structurally invisible to a
  `fused-type-annot?`-keyed census). ⚠ Re-pin — these drift.
- **DEFERRED 24–31** (`docs/tracking/DEFERRED.md`). **31** is P4c-1's: the `ns`
  guard RAISES rather than returning a per-command error, so it is a WHOLE-FILE
  ABORT (the Q_L4 class) — owner-requested follow-up, candidate home P4c.close
  or X.close. **24** remains the one deserving the owner's eye
  (`select-block-hint`'s four side-effect classes inside an error formatter).
- **Doc-truth repairs owed** (listed in §5.P4c): D4:902 and :3067 still
  contradict the resolved `quests:t` question; §5.P4's Intent block still
  asserts the RETIRED pre-NEST model; §Q8.5's silent-degradation tier is
  factually wrong at HEAD (`pp-datum` HAS a `$select-path` arm); §Q8.5
  invariant 1's "prefix-disjointness not priority" framing is wrong for
  `:w`/`:m` (both match at length 2; priority 97>95 decides).
- **The Q_N3 two-grouper agreement guard is BLIND to `$bcast-step`** in both
  versions (v1 count-comparing and the mint is count-preserving; v2 pairs a tree
  TAG with a datum sentinel, which only OPENERS have). A third guard shape is
  owed.

---

## §6 — Process Notes

- **Racket**: `"/Applications/Racket v9.0/bin/racket"`; runner
  `tools/run-affected-tests.rkt --tests …`; probes via `tools/run-file.rkt`
  (`--check` for acceptance) — all from `racket/prologos/`. Manual `raco make`
  needs `PLT_CS_COMPILE_LIMIT=1000000`. `tools/check-parens.sh` after EVERY
  `.rkt` edit — **then COMPILE**.
- **Failing-test-first, and a pin must fail for the reason its name claims.**
  ⚠ **MEASURE the baseline, never assert a remembered one** — I guessed twice
  this session (`{:0 v}` and the quote datum) and both pins failed for the wrong
  reason. A pin asserting a remembered baseline is the shape that ships
  vacuously green.
- **For a behaviour-preserving refactor the pins go in FIRST and stay GREEN** —
  the pins ARE the claim. For a two-sided contract (mint + unwrap) read both
  sides together: the invariance pins are only evidence once the driving side
  is green.
- **The FALSE-ZERO footgun**: a direct `tokenize-char-rrb` without
  `register-default-token-patterns!` matches NOTHING and returns every character
  as its own token. It bit me this session. `tests/test-parse-reader.rkt:23`
  calls the initializer; `tools/reader-corpus-ab.rkt:74` carries a tripwire.
- **Corpus A/B**: `git archive` BOTH legs onto ONE snapshot, worktree-pin the
  baseline, never `git stash` (owner WIP lives in the main tree). A working-tree
  read measures the tree — 3rd sighting of that class.
- **Adversarial verify before EVERY behavioural commit** — it has caught
  something in 9 of the last 10 slices. **P4c-2's mint+unwrap commit did NOT get
  one** (context exhaustion); consider running it retroactively before P4c-3.
- **`grounding-audit` is the default opener for a grounding-heavy mini-audit**;
  `design-options-panel` for adversarially-weighed options. Args as a JSON
  OBJECT. Both ran for P4c (`wf_d7c035da-cee`, `wf_6f15c6ae-6a7`).
  ⚠ **R-lens-verify anything load-bearing yourself** — the panel's hoist target
  was WRONG (it named `reader-forms.rkt` without checking that the predicate is
  over the `token-entry` STRUCT), and three critics had corroborated it.
- Per-phase 5-step gate · commits trigger dailies (STATE overwrite + LOG
  append) · per-slice records in that slice's D4 §5 section · probes in the
  SCRATCHPAD, never the repo · full suite = regression gate ONLY (read
  `data/benchmarks/failures/*.log`, never re-run to diagnose) ·
  **owner co-designs in PROSE, ONE QUESTION PER TURN**.
