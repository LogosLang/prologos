# Handoff — CIU T6 Path Selection: P4c-4b LANDED; P4c-4c RE-SCOPED; **Q_U18 is the load-bearing open ruling**

**Date** 2026-08-02 · **For** a fresh session continuing **D4.P4c-4c**.
Per `HANDOFF_PROTOCOL.org`. **ON-DISK IS AUTHORITATIVE.**

> **Hot-load**: read §1–§6 here, then every §2c doc IN FULL, then **summarize
> your understanding back to the owner and let them validate it BEFORE starting
> work.**

> The live surface law: **dot DESCENDS · brace SELECTS `x{…}` · `:` BROADCASTS ·
> `^` RE-KEYS · `*` FLATTENS · `<` DISCLOSES.** The spec is a **GUIDE**; where it
> and D4 differ, **D4's recorded adaptation wins.**

---

## §1 — Current Work State (PRECISE)

- **Series / Track / Phase**: CIU → Track 6 Path Selection → **D4.P4c-4c**, ⬜
  **RE-SCOPED, not started**.
- **Design doc**: `docs/tracking/2026-07-28_CIU_T6_PATH_SELECTION_D4.md` (D4).
  It now carries ~98 stable anchors — **link by anchor, cite by NAME, never by
  line number** (this repo's coordinates drift constantly and have burned this
  arc four times).
- **HEAD at write**: re-derive with `git rev-parse HEAD`. ⚠ origin has advanced
  **externally twice** in this arc — always
  `git rev-list --count origin/main..HEAD`, never a remembered number.
- Local `main`, **MAIN CHECKOUT**. If the session launches in a worktree, verify
  0 unique commits and REMOVE it.
- **Gate at the last close**: suite **9831 / 482 files / 0** · battery **340**
  (`grep -c '^(test-case' racket/prologos/tests/test-path-selection.rkt` —
  MEASURE, never derive) · acceptance **52/52 + 89/89 + 6/6 + 29/29 + 28/28**.
- **Working tree**: **14 owner-WIP entries + untracked — LEAVE ALONE.** Stage
  EXPLICIT paths · verify `git diff --cached --name-status` · **never
  `git stash`** · no Co-Authored-By · long messages via `git commit -F`.

### Progress

| Phase | Status |
|---|---|
| P0–P3 · P4a · P4b · P4c-1 · P4c-2 · P4c-3 · **P4c-4a** `f31237fd` · **P4c-4b** `6b22515d` | ✅ |
| **P4c-4c** — RE-SCOPED to PVec value semantics | ⬜ **← HERE** |
| **Q_U18** (unknown-head policy + first production grant) | ⬜ **GATES every corpus uncomment** |
| Q_U19 (`^`-on-broadcast) · `:{` mint · P4d · P4e · P4c-5 · PF · P5 · PX · P6 · X.close | ⬜ |

### NEXT IMMEDIATE TASK

**P4c-4c, re-scoped: the PVec ω VALUE semantics.** Six arms + a fourth site:

- **THREE typing arms** — `walk-to-leaf`, `select-branch-entries`,
  `select-below-field` (typing-core.rkt). Protocol `(values x fail)`; they
  currently return `(values #f (select-fail 'bcast-not-yet …))`. Replace with a
  TYPE.
- **THREE reduction arms** — `walk-to-leaf`, `branch-entries`, `below-value`
  (reduction.rkt). They currently RAISE via `select-bcast-not-yet`. **No failure
  slot**; they escape via `let/ec return` with `expr-panic`. Replace with a VALUE.
- **⚠ A FOURTH SITE THE PARTITION DOES NOT NAME**: an `rrb-of`-style container
  guard. `champ-of` and `index-into` are the precedent; there is **no `rrb`
  twin**, and with no failure slot a mid-descent non-container has no other way
  to report.
- **The L1 fusion + §3.2.1 extent LAWS** pinned in the battery **in `def`
  position** (which mints). Their CORPUS lines wait on Q_U18 + the `:{` mint.

**Semantics, from the code**: `xs : [PVec {:name String}]` ⇒ `xs:name` is value
`@["…" …]` (`expr-rrb`) at type `[PVec String]`. Mirror `pvec-map : (A → B) →
PVec A → PVec B` and the `expr-pvec-map` whnf arm. The corpus pins the shape
three lines above the commented target, with the explicit `map` spelling.

**Gate it with `def`-position test pins.** Bare top-level does NOT mint (see §4).

---

## §2 — Documents to Hot-Load (ORDERED)

**§2a Always**: `CLAUDE.md` + `CLAUDE.local.md` · `MEMORY.md` +
`ciu-t6-records.md` (**the tail = live state**) · `DESIGN_METHODOLOGY.org` ·
`DESIGN_PRINCIPLES.org` · `CRITIQUE_METHODOLOGY.org` · `HANDOFF_PROTOCOL.org` ·
`MASTER_ROADMAP.org` · CIU master.

**§2b rules** (ambient; load-bearing here): `on-network.md` · `pipeline.md`
(§ Exhaustive Walkers; § "A Raise on the Parse/Expansion Path Is a WHOLE-FILE
Abort" — **this arc added a FIFTH instance by a new door: the TYPING path**) ·
`testing.md` · `workflow.md` (§ tracker Notes are HEADLINES + the anchor
convention) · `prologos-syntax.md`.

**§2c Session-specific — IN FULL, IN THIS ORDER:**

1. **D4** — `#p4c-4c` (the re-scope + the three blockers) · **`#p4c-sequencing`
   (THE SCHEDULE — read this before proposing any ordering)** · `#q-u18` ·
   `#q-u19` · `#p4c-4b` · `#p4c-4a` · `#q-u7` · `#q-u9` · `#q-u16b` · `#q-u17`
   · `#pf`.
2. `docs/tracking/DEFERRED.md` — CIU T6 items **31–41**.
3. Dailies `docs/tracking/standups/2026-07-28_dailies.md` — STATE head + the
   last 6 LOG entries (read by TITLE; the file interleaves arcs).
4. Memory `ciu-t6-records.md` — the tail block.

---

## §3 — Key Design Decisions (do NOT revisit without census-grade cause)

- **THE INVERTED DEFAULT** (`68cdaae7`): unwrap by default, preserve only where
  granted. The enumeration MOVES, it does not vanish.
- **P4c-4a**: `broadcast-enabled-contexts` is a **GUARDED PARAMETER**, exported,
  membership keyed on the node's own head. ⚠ **The scoping rule is a CHAIN** —
  an ungranted ANCESTOR destroys what a granted descendant preserved, because
  the not-granted arm deep-recurses through already-visited sub-groups.
- **P4c-4b**: the chain closes reader→fold→parser→typing. The fold emits
  `($select-path <base> ($bcast-step <payload>))` — head is `$select-path`, so
  the **fixpoint obligation holds by construction**. Typing REFUSES through the
  failure slot; **reduction KEEPS its raise** deliberately (two propositions,
  two channels — not belt-and-suspenders).
- **Q_U7** — `(@bcast step)` is a ONE-STEP wrapper, extent STRUCTURAL.
  ⚠ **"A wrapper never heads a branch" is FALSE** and was corrected at four
  sites: `$select-path` consumes the SUBJECT, so the ω step arrives FIRST.
- **Q_U9** — `:` REFUSES over `List`. **Implementation: P4d**, not P4c-4c.
- **Q_U17 RULED B2** — a Path segment is a first-class `Step` value; slice **PF**,
  before P5.
- **Next free Q-label: U20.**

---

## §4 — Surprises (HIGHEST RE-DERIVATION RISK)

1. **⭐ A BARE TOP-LEVEL ω IS STRIPPED UNDER EVERY GRANT.** `users:name` →
   `((users :name))` even granting its own head `users`, even under a broad
   grant. The head is unknown to both the cond and the scanner, so `[else]`
   blanket-strips. **Every ω line in the acceptance file is a bare top-level
   command**, so no acceptance marker is exercisable. This is Q_U18.
2. **`:{…}` DOES NOT MINT.** `users:{t r}` → `users : ($select-brace t r)`.
   `bcast-step-trigger?` gates on token TYPE and a lone `:` before an opener is
   neither. Kills `quests:{t r}` AND both §3.2.1 extent members.
3. **`broadcast-enabled-contexts` has ZERO production setters** — `process-file`
   runs at default `'()` regardless.
4. **TWO CARRIER FACTS ARE FALSE and both would produce bad code**:
   `expr-hset` has **no arm in any dispatcher** (Set is not a selection carrier
   today — true of the struct, false of the machinery), and **`expr-Record` is
   TYPE-only** (a het tuple's runtime value is an `expr-rrb`).
5. **The scope says "PVec" but the corpus demands THREE carriers** — PVec,
   closed keyword rows, het tuples. The latter two are **P4d**.
6. **A grep for one keyword is NOT a gate.** Two false greens this arc: a
   module-load `unbound identifier` is not a `FAILURE`, and rackunit reports an
   arity mismatch as `ERROR`. **Use the runner's count.**
7. **The targeted runner ABORTS `test-path-selection.rkt` at 30 s** and
   `--timeout` does not help. Use
   `racket -e '(require (file "…/tests/test-path-selection.rkt"))'` for the track
   file, the runner for the neighbourhood.
8. **A corpus A/B needs a pinned baseline and ONE snapshot for both legs.** The
   full 139-file run takes hours; scope it to the files that can MINT (12 at
   last count) — that is TARGETING, not narrowing. Counter drift with a CONSTANT
   offset is a tree-state artifact: **discriminate it with a control file that
   cannot mint**, do not assume.

---

## §5 — Open Questions

- **⬜ Q_U18 — THE LOAD-BEARING ONE.** The unknown-head policy and the first
  production grant are **ONE decision**. Until ruled, the entire broadcast
  surface is reachable **only from tests** — the "Validated ≠ Deployed" gate.
  ⚠ **Not "pick an arm"**: P4c-3 MEASURED that the head-keyed walk cannot decide
  it in EITHER direction. ⚠ **HALF OF THAT IS NOW REFUTED (2026-08-02)**: the
  PRESERVE counter-example `[add ?x:Nat ?y:Nat] = 5N` **DOES NOT EXIST** —
  `?x:Nat` is glued into ONE TOKEN by `recognize-narrow-var-annot` and mints
  NOTHING under any grant, exactly as `parse-reader.rkt`'s own comment says
  ("Immune by construction"). **PRESERVE has ZERO measured corpus regressions**
  over a 795-file census. The live hole is DIGIT-headed segments (`?x:0` mints);
  the principled counter-example is macro pattern vars, zero instances in tree.
  ⭐ And `parser.rkt` ALREADY distinguishes binder from expression position
  (`bcast-step-binder` vs `bcast-step`, three binder consumers) — so the honest
  form of Q_U18 may be "**why is the READER deciding this at all?**"
  Read D4 `#q-u18`'s correction block IN FULL. DEFERRED 32's open half is this
  question.
- **⬜ Q_U19 — `^` on a broadcast**: refuse, or re-key the broadcast output? It
  is ALREADY constructible. ⚠ The existing pin freezes an **accident**, not a
  ruling. Due at P4d.
- **⬜ The `:{…}` reader mint** — a P4d PREREQUISITE.
- **DEFERRED 31, 33, 34, 35, 37–41** — 37 (`access-sentinel?`) is DISCHARGED by
  P4c-4b; 39's two ω-blind parser sites remain latent (they need a
  BLOCK-position broadcast, which `:{` non-mint still prevents); 40 likewise.
- **DEFERRED 36's re-probe obligation** (the `.pnet` cache under a grant) — P4c-4b
  was the first grant; **verify whether it was re-probed.**

---

## §6 — Process Notes

- **Racket** `"/Applications/Racket v9.0/bin/racket"`; manual `raco make` needs
  `PLT_CS_COMPILE_LIMIT=1000000`. `tools/check-parens.sh` after EVERY `.rkt`
  edit, **then COMPILE**. All tooling runs from `racket/prologos/`.
- **Adversarial verify before EVERY behavioural commit** — it has caught
  something in essentially every slice this arc, including **claims of mine it
  refuted outright**. Budget for it.
- `grounding-audit` opens a mini-audit; `design-options-panel` weighs options
  (args need a `clusters` array — a missing one returns "no clusters" with 0
  agents). **R-lens-verify anything load-bearing yourself**: this arc the panel
  found real defects AND was wrong in ways three critics corroborated.
- Per-phase 5-step gate · commits trigger dailies (STATE overwrite + LOG append)
  · per-slice records in that slice's D4 §5 section · probes in the SCRATCHPAD
  · **owner co-designs in PROSE, ONE QUESTION PER TURN**.
- **Tracker Notes are HEADLINES + a LINK** (`workflow.md`, codified `49037e35`
  after a row of mine reached 6,153 chars). Healthy rows run 160–800.

**FIRST MOVE**: read the above, re-verify HEAD / suite / battery, then
**summarize your understanding back to the owner before starting work.** The
first substantive turn is likely a co-design on **Q_U18**, not code — it gates
everything downstream of P4c-4c.
