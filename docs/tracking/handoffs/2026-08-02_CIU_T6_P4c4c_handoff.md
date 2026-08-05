# Handoff — CIU T6 Path Selection: **Q_U18 RULED + the PRESERVE flip LANDED**; P4c-4c is next

**Date** 2026-08-02 (refreshed after the Q_U18 arc) · **For** a fresh session
continuing **D4.P4c-4c**. Per `HANDOFF_PROTOCOL.org`. **ON-DISK IS AUTHORITATIVE.**

> **Hot-load**: read §1–§6 here, then every §2c doc IN FULL, then **summarize your
> understanding back to the owner and let them validate it BEFORE starting work.**

> The live surface law: **dot DESCENDS · brace SELECTS `x{…}` · `:` BROADCASTS ·
> `^` RE-KEYS · `*` FLATTENS · `<` DISCLOSES.** The spec is a **GUIDE**; where it
> and D4 differ, **D4's recorded adaptation wins.**

---

## §1 — Current Work State (PRECISE)

- **Series / Track / Phase**: CIU → Track 6 Path Selection → **D4.P4c-4c**
  (re-scoped), ⬜ **not started**.
- **Design doc**: `docs/tracking/2026-07-28_CIU_T6_PATH_SELECTION_D4.md`. ~98
  stable anchors — **link by anchor, cite by NAME, never by line number**;
  coordinates drift here and have burned this arc four times.
- **HEAD at write**: `e71ef6b8` — ⚠ **re-derive with `git rev-parse HEAD`**.
  12 unpushed; ⚠ origin has advanced **externally twice** this arc, so always
  `git rev-list --count origin/main..HEAD`.
- Local `main`, **MAIN CHECKOUT**. If the session launches in a worktree, verify
  0 unique commits and remove it.
- **Gate**: suite **9835 / 482 files / 0** · battery **344**
  (`grep -c '^(test-case' racket/prologos/tests/test-path-selection.rkt` —
  MEASURE, never derive) · acceptance **52/52 + 89/89 + 6/6 + 29/29 + 28/28**.
- **Working tree**: owner WIP only — **LEAVE ALONE.** Stage EXPLICIT paths ·
  verify `git diff --cached --name-status` · **never `git stash`** · no
  Co-Authored-By · long messages via `git commit -F` (a brace glyph in a `-m`
  message got shell-expanded once this arc).

### Progress

| Phase / Question | Status |
|---|---|
| P0–P3 · P4a · P4b · P4c-1 · P4c-2 · P4c-3 · **P4c-4a** `f31237fd` · **P4c-4b** `6b22515d` | ✅ |
| **Q_U17** (Path segment = first-class `Step`) `b77b3e2e` · **Q_U18** (PRESERVE + G4) `3b4a02cf` · the flip `e71ef6b8` | ✅ RULED |
| **P4c-4c** — PVec value semantics | ⬜ **← HERE** |
| Q_U19 (`^`-on-broadcast, due P4d) · DEFERRED 42 (`:{` mint, P4d prereq) · **G2 re-evaluation** (at P4c-4c) · P4d · P4e · P4c-5 · PF · P5 · PX · P6 · X.close | ⬜ |

### NEXT IMMEDIATE TASK

**P4c-4c — the PVec ω VALUE semantics.** Six arms plus a fourth site:

- **THREE typing arms** — `walk-to-leaf`, `select-branch-entries`,
  `select-below-field` (typing-core.rkt). Protocol `(values x fail)`; they
  currently return `(values #f (select-fail 'bcast-not-yet …))`. Return a TYPE.
- **THREE reduction arms** — `walk-to-leaf`, `branch-entries`, `below-value`
  (reduction.rkt). They currently RAISE via `select-bcast-not-yet`. **No failure
  slot** — they escape via `let/ec return` with `expr-panic`. Return a VALUE.
- **⚠ A FOURTH SITE THE PARTITION NEVER NAMED**: an `rrb-of`-style container
  guard. `champ-of` and `index-into` are the precedent; there is **no `rrb`
  twin**, and with no failure slot a mid-descent non-container cannot report.
- **The L1 fusion + §3.2.1 extent LAWS** pinned in the battery **in `def`
  position** (which mints). Their CORPUS lines wait on DEFERRED 42 + the grant.

**Semantics, from the code**: `xs : [PVec {:name String}]` ⇒ `xs:name` is value
`@["…" …]` (`expr-rrb`) at type `[PVec String]`. Mirror `pvec-map : (A → B) →
PVec A → PVec B` and the `expr-pvec-map` whnf arm. The corpus pins the shape
three lines above the commented target with the explicit `map` spelling.

**Gate with `def`-position test pins** — bare top-level does NOT mint (§4).

---

## §2 — Documents to Hot-Load (ORDERED)

**§2a Always**: `CLAUDE.md` + `CLAUDE.local.md` · `MEMORY.md` +
`ciu-t6-records.md` (**the tail = live state**) · `DESIGN_METHODOLOGY.org` ·
`DESIGN_PRINCIPLES.org` · `CRITIQUE_METHODOLOGY.org` · `HANDOFF_PROTOCOL.org` ·
`MASTER_ROADMAP.org` · CIU master.

**§2b rules** (ambient; load-bearing here): `on-network.md` · `pipeline.md`
(§ Exhaustive Walkers; § "A Raise on the Parse/Expansion Path Is a WHOLE-FILE
Abort" — this arc added an instance by a NEW door, the TYPING path) ·
`testing.md` · `workflow.md` (§ tracker Notes are HEADLINES + the anchor
convention) · `prologos-syntax.md`.

**§2c Session-specific — IN FULL, IN THIS ORDER:**

1. **D4** — `#q-u18` **IN FULL, including its correction block and the G2
   reframe** · `#p4c-4c` · `#p4c-sequencing` (THE SCHEDULE — read before
   proposing any ordering) · `#q-u19` · `#p4c-4b` · `#p4c-4a` · `#q-u7` ·
   `#q-u9` · `#q-u16b` · `#q-u17` · `#pf`.
2. `docs/tracking/DEFERRED.md` — CIU T6 items **31–42** (32 ✅ resolved by
   Q_U18; 37 ✅ discharged at P4c-4b; **42** is the `:{` mint).
3. Dailies `docs/tracking/standups/2026-07-28_dailies.md` — STATE head + the last
   7 LOG entries (read by TITLE; the file interleaves arcs).
4. Memory `ciu-t6-records.md` — the tail block.

---

## §3 — Key Design Decisions (RATIONALE; do NOT revisit without census-grade cause)

- **⭐ Q_U18 (owner, 2026-08-02)** — (i) the unknown-head arm **PRESERVES**;
  (ii) the grant is **G4**, test-only until P4c-4c. **What makes (i) safe is
  STRUCTURAL, not a table**: `recognize-narrow-var-annot` glues `?x:Nat` into ONE
  TOKEN at the tokenizer, so the typed-logic-var population can never mint. The
  discriminator was already in the tree. **G2 = a recorded LEAN, not a ruling.**
- **⭐ Q_U17 (owner)** — a Path segment is a first-class `Step` value; `data Step`
  on the `Datum` pattern, `Path` stays ground. Slice **PF**, before P5 (whose B3
  same-spine merge depends on it).
- **THE INVERTED DEFAULT** (`68cdaae7`) — still governs *recognized* heads; Q_U18
  is a **knowing, narrow exception** for the unknown-head arm, ruled on the
  grounds that it breaks only code that does not exist.
- **P4c-4a** — the enable-set is a **GUARDED PARAMETER**, membership keyed on the
  node's own head. ⚠ **The scoping rule is a CHAIN**: an ungranted ANCESTOR
  destroys what a granted descendant preserved.
- **P4c-4b** — the chain closes reader→fold→parser→typing. The fold emits
  `($select-path <base> ($bcast-step <payload>))`, so the **fixpoint obligation
  holds by construction**. Typing REFUSES through the failure slot; **reduction
  KEEPS its raise** (two propositions, two channels — not belt-and-suspenders).
- **Q_U7** — `(@bcast step)` is a ONE-STEP wrapper. ⚠ *"A wrapper never heads a
  branch" is FALSE*, corrected at four sites.
- **Q_U9** — `:` REFUSES over `List`. **Implementation: P4d**, not P4c-4c.
- **Next free Q-label: U20.**

---

## §4 — Surprises and Non-Obvious Findings (HIGHEST RE-DERIVATION RISK)

1. **⭐⭐ THE PRESERVE FLIP IS INERT UNTIL G2 — so G2 is the OPERATIVE half, not
   cleanup.** The flip works (inner head granted ⇒ `[one users:name]` →
   `(one users ($bcast-step :name))`, nests), but the enable-set's FIRST arm
   strips any node whose OWN head is ungranted, and granting every function name
   is absurd. **Weigh G2 as a FEATURE decision** at P4c-4c's close — possibly
   ALONGSIDE it, since P4c-4c's semantics are what make the working set
   observable and that observation is the input to G2.
2. **⭐ A BARE TOP-LEVEL ω IS STRIPPED UNDER EVERY GRANT** — so no acceptance
   marker is exercisable. Consequence of the same first-arm gate.
3. **`:{…}` DOES NOT MINT** (`users:{t r}` → `users : ($select-brace t r)`) —
   kills `quests:{t r}` and both §3.2.1 extent members. **DEFERRED 42.**
4. **TWO CARRIER FACTS ARE FALSE and both would produce bad code**: `expr-hset`
   has **no arm in any dispatcher** (Set is not a selection carrier today — true
   of the struct, false of the machinery), and **`expr-Record` is TYPE-only** (a
   het tuple's runtime value is an `expr-rrb`).
5. **The scope says "PVec" but the corpus demands THREE carriers** — PVec, closed
   keyword rows, het tuples. The latter two are **P4d**.
6. **⚠ THE RECURRING FAILURE OF THIS ARC — reading the DATUM and inferring the
   MEANING.** Three times a recorded mechanism claim fell to an end-to-end probe:
   (a) `[add ?x:Nat ?y:Nat]` "refutes PRESERVE" — it mints nothing; (b) the
   "digit-headed hole" is not a defect — `?x:0`/`?x:w` are both already refused;
   (c) the tree-spine assumption. **The reader datum is not the semantics.**
7. **A grep for one keyword is NOT a gate.** A module-load `unbound identifier`
   is not a `FAILURE`; rackunit reports an arity mismatch as `ERROR`. **Use the
   runner's count.**
8. **The targeted runner ABORTS `test-path-selection.rkt` at 30 s**;
   `--timeout` does not help. Use
   `racket -e '(require (file "…/tests/test-path-selection.rkt"))'` for the track
   file, the runner for the neighbourhood.
9. **Corpus A/B**: pin ONE snapshot for both legs, worktree-pin the baseline,
   scope to the files that can MINT (≈12 — that is TARGETING, not narrowing).
   Counter drift with a CONSTANT offset is a tree-state artifact — **discriminate
   with a control file that cannot mint**, do not assume.

---

## §5 — Open Questions and Deferred Work

- **⬜ G2 re-evaluation** — retire the enable-set? Now known to be the operative
  half (§4.1). Trigger: **P4c-4c's close**.
- **⬜ Q_U19** — `^` on a broadcast: refuse, or re-key the broadcast output? It is
  ALREADY constructible; the existing pin freezes an **accident**, not a ruling.
  Due at **P4d**.
- **⬜ DEFERRED 42** — the `:{…}` reader mint, a **P4d prerequisite**. Touches
  `bcast-step-trigger?`, the ONE predicate both groupers share ⇒ land it alone or
  the A/B is un-attributable.
- **⬜ PF** — Q_U17's `Step` + `Cont` ADTs, the `path-segments` repair (same
  change), the eleven consumer-site migration. Before **P5**.
- **DEFERRED 31, 33, 34, 35, 38–41** live. **32 ✅** (Q_U18) · **36 ✅** but its
  re-probe obligation under a grant was never discharged · **37 ✅** (P4c-4b).

---

## §6 — Process Notes

- **Racket** `"/Applications/Racket v9.0/bin/racket"`; manual `raco make` needs
  `PLT_CS_COMPILE_LIMIT=1000000`. `tools/check-parens.sh` after EVERY `.rkt`
  edit, **then COMPILE**. All tooling runs from `racket/prologos/`.
- **Adversarial verify before EVERY behavioural commit** — it has caught
  something in essentially every slice this arc, **including claims of mine it
  refuted outright**. Budget for it.
- `grounding-audit` opens a mini-audit; `design-options-panel` weighs options
  (its args need a `clusters` array — a missing one returns "no clusters" with 0
  agents). **R-lens-verify anything load-bearing yourself.**
- Per-phase 5-step gate · commits trigger dailies (STATE overwrite + LOG append)
  · per-slice records in that slice's D4 §5 section · probes in the SCRATCHPAD ·
  **owner co-designs in PROSE, ONE QUESTION PER TURN** · tracker Notes are
  HEADLINES + a LINK (healthy rows 160–800 chars).
- **Do NOT write a handoff or Relay Note unless the owner explicitly asks.**

**FIRST MOVE**: re-verify HEAD / suite / battery, read §2c, then **summarize your
understanding back to the owner before starting work.**
