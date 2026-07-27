# Handoff — CIU Track 6: Path Selection (the OPEN design conversation)

**Date**: 2026-07-25 · **For**: a fresh session opening the **Path Selection
design conversation**. Per `HANDOFF_PROTOCOL.org`. **ON-DISK IS AUTHORITATIVE.**

> **Hot-load protocol** (§ Hot-Load Reading Protocol): read this handoff §1–§6
> FIRST, then the Always-Load set, then EVERY session-specific doc **in full** —
> then **summarize your understanding back to the owner and let them validate it
> BEFORE starting work.** "I have full context" requires being able to articulate
> every decision in §3 and every surprise in §4.

> ⚠ **THIS IS A DESIGN SESSION, NOT AN IMPLEMENTATION SESSION.** The surface is
> an OPEN owner design conversation. Do not write production code, do not open a
> Stage-4 phase, and do not commit to a surface before the owner has ruled. The
> design doc's own §6 prescribes: grounding audit → **design dialogue** →
> Stage-3 doc + phased roadmap → *then* implement.

---

## §1 — Current Work State (PRECISE)

- **Series / Track**: CIU Series → **Track 6** (Anonymous Records & Collections
  & Path Selection). Track 6 is 🔄 **specifically because Path Selection is
  open** — everything else in it (F1a, F1a.2, F1b) is ✅ COMPLETE.
- **HEAD**: `6c40c05d` · **Suite** GREEN **471 files / 9150 / 0** · branch
  `main`, ahead of origin — **don't push unless directed**.
- **Working tree**: pre-existing **OWNER WIP only** (~41 entries: modified
  `docs/standups/*.org` + `examples/*.prologos`, deleted `MASTER_ROADMAP.md` /
  `LANGUAGE_VISION.md`, untracked `LATTICE_*` / `LAVAMOAT_*` / `pldi-*` /
  `qauntale_outputs/` / `research/quantale research/` / `TRACK8_DESIGN.md` /
  `CRITIQUE_METHODOLOGY.md`). **LEAVE ALONE.**
  ⚠ **Stage explicit paths, then VERIFY with `git diff --cached --name-status`**
  — NOT a `^[AM]` grep (it hides D-rows; that is how two owner deletions were
  once committed, reverted `2c4609f6`). **NEVER `git stash`** (two owner
  stashes). **NO Co-Authored-By.** Long commit messages via `git commit -F`.
- **Design doc**: `docs/tracking/2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md`
  (214 lines) — **§2 owner vision V1–V5 · §2a locked decisions D1–D29 across 7
  rounds · §2a "OPEN — Path Selection unified surface" ← THE SUBJECT ·
  §5 open questions 3/4/5/6/8 · §6 proposed approach**.
- **Series master**: `docs/tracking/2026-03-28_CIU_MASTER.md` (see
  `MASTER_ROADMAP.org` line ~146 for the Track 6 status paragraph).

### NEXT IMMEDIATE TASK

**Open the Path Selection design conversation.** Per §6: (1) a grounding audit
over the reader/selection surfaces, (2) design dialogue with the owner on §5's
open items, (3) only then a Stage-3 doc. Expect the owner to co-design in
**prose with Q_N labels** — not AskUserQuestion chips.

---

## §2 — Documents to Hot-Load (ORDERED)

**Always-Load**: `CLAUDE.md` + `CLAUDE.local.md`; `MEMORY.md` +
[[ciu-t6-records]] + [[rel-t1-relational-usability]] +
[[demo-dependency-resolver-track]] + [[prologos-look-and-feel-conventions]];
`DESIGN_METHODOLOGY.org` (**Stage 1–3 — this is a DESIGN session**);
`DESIGN_PRINCIPLES.org`; `CRITIQUE_METHODOLOGY.org` (**P/R/M/S lenses + the SRE
lattice lens — both will be used**); `HANDOFF_PROTOCOL.org`;
`MASTER_ROADMAP.org`; CIU master. Rules auto-load — internalize
`prologos-syntax.md` (**the delimiter conventions ARE the design space here**),
`structural-thinking.md` (**the SRE lattice lens is mandatory for the result-shape
question**), `workflow.md`, `testing.md`, `pipeline.md`.

**Session-specific — READ IN FULL, IN THIS ORDER:**

1. **This handoff** (§1–§6).
2. **`2026-07-05_PATH_SELECTION_RECORDS_DESIGN.md`** (214 L) — the whole thing.
   §2 is the owner's vision *verbatim*; §2a is seven rounds of locked
   decisions you must not re-open; the **"OPEN — Path Selection unified
   surface"** block is the subject; §5 lists the open questions; §6 the
   approach.
3. **`2026-07-06_CIU_T6_F1_STRUCTURAL_RECORDS_DESIGN.md`** — the records/rows
   substrate Path Selection projects through (D6 row carrier, presence marks,
   the 3-state tail). You need the carrier's shape to reason about result shape.
4. **`docs/tracking/2026-07-19_CIU_T6_F1B_PIR.md`** — especially the
   **HOF-over-rows prerequisite** it named for broadcast selection.
5. **`docs/tracking/2026-07-25_REL_T1_PIR.md`** §1 + §9 — what typed solution
   rows now give you (this is *why* Path Selection is tractable now).
6. **`docs/tracking/standups/2026-07-24_dailies.md`** — **STATE head is your
   re-grounding surface**; the LOG's last three entries cover Batch C/D and the
   DEMO-arc review.
7. `docs/research/2026-07-06_ROWS_COALGEBRA_PROPAGATOR_NOTE.md` — the research
   note behind D9 (engineering grounding only, never gating).

---

## §3 — Key Design Decisions (do NOT revisit without cause)

**Locked across seven co-design rounds (2026-07-05 → 07-17).** The full list is
design §2a; the ones that constrain *this* conversation:

- **D1/D6/D7 — `Map` IS the anonymous open record; the carrier is ROW-SHAPED.**
  Per-field slots + an explicit **3-state tail** (`closed | dyn | ρ-reserved`) +
  room for presence marks. Literals get ground closed-tail rows, so `{:a 1}.b`
  is a *closed-row miss*, not a policy error. `expr-Open` is DELETED.
- **D2/D3 — `Map` ⇄ `schema` interop both ways**; two axes (named/anonymous ×
  closed/open) reconciled as ONE structural-record notion.
- **`coll[…]` postfix is the direction, and it SUPERSEDES `coll{selector}` /
  `_{…}`.** §2 V2's brace surface is historical — do not design against it.
- **F1a-col shipped ONLY the degenerate case**: `v[i]` literal-index positional
  projection (Nat-or-Int, mirroring PVec's gate), composing as `v[1].b`
  (chained postfix-then-dot). **`v[1.b]` and `coll.[…]` are deliberately NOT
  built** — they were held for this conversation.
- **D8 — QTT pin**: record fields are `mw` for all of F1.
- **D5 — WS-first**: every feature wired through to WS and regression-tested in
  WS `.prologos` syntax directly.

---

## §4 — Surprises and Non-Obvious Findings (HIGHEST RE-DERIVATION RISK)

1. **⭐ The broadcast prerequisite is a PREREQUISITE, not a follow-on.**
   `coll.[…]` is "apply a per-element projection across a collection" — and
   that shape fails inference *today*: `[map [fn [r] r.field] rows]` and
   `[map [validate Person _] rows]` both give "Could not infer type" when
   `rows : List {…}` is def-bound. The element type doesn't push into the
   lambda's hole domain through `map`. **Broadcast cannot be ergonomic until
   this infers**, so the grounding must include it. (F1b PIR; design §2a ✏.)
2. **The result-shape question (V4) is the hardest piece and the owner is
   genuinely unsure** — that is recorded, not a gap in the capture. Flatten-to-
   leaves vs preserve-nesting vs preserve-path vs `^`-rename. Do not arrive
   with a single answer; arrive with a lattice of options and their costs.
3. **`^` already owns RENAME** — it is not free for selection syntax. It was
   settled in the Rel T1 Aspect-B round (keys = query-var names, `^` owns
   rename) and F3 shipped the WS tokenizer support.
4. **A green full suite is NOT a correctness gate.** It was green 470/0 with a
   live silent-wrong-answer bug for months (Rel T1 SUB). Read `pipeline.md`
   § "Exhaustive Walkers".
5. **Probing changes the RULING, not just the facts** — 3 data points, the
   sharpest at Rel T1 Batch C where a conclusion was stated *out loud* from
   code-reading and the probe reversed it. Probe before you rule, and before
   you tell the owner.
6. **The pattern usually already exists** — search before building. Rel T1's
   acceptance gate had FOUR prior instances in the preceding track.
7. **Selection-value map-ops are DEFERRED and adjacent**: a selection is a
   read-capability view with `:requires`; there is no down-cast from a parent
   value, and a non-`:requires` projection gives a cryptic error. Filed as
   "selection projections" in DEFERRED.md — **it will come up in this design.**
8. **Schema EXTENSION (`:include`) does not exist** — no mechanism today, only
   nesting; `:include User` silently becomes a field. Owner has been brewing a
   design. Adjacent to selection; do not assume it exists.

---

## §5 — Open Questions and Deferred Work

**The conversation's actual agenda** (design §5, live items):

- **§5.3 Selection surface** — grammar, precedence, interaction with
  application `[f x]` and existing `.` dot-access. Does `.` single-access
  unify into it?
- **§5.4 Result shape (V4)** — **the hardest, most-open piece.**
- **§5.5 Broadcast (V3)** — explicit marker vs implicit auto-broadcast; how a
  selector distinguishes "over the collection" from "on the collection."
- **§5.6 Array ⇄ Map unification (V2)** — one indexed-selection mechanism
  dispatched by key type, or two surfaces? Relation to CIU + PVec.
- **§5.8 Migration** — retire `.{` cleanly; `#p(…)`, `selection`,
  `get-in`/`update-in` continuation.

**Named + owned elsewhere (do not absorb)**: the unannotated-param / F-row
inference gap (→ F-row / Num Track 2, but see §4.1 — it gates broadcast) ·
selection projections · schema `:include` · PM Track 12/12B (parameters→cells,
7-instance two-context class) · Rel T2 "The Fact Store" · BSP-LE T3 · UCS T6.

---

## §6 — Process Notes

- **Stage 1–3 discipline** (`DESIGN_METHODOLOGY.org`): grounding audit →
  design dialogue → Stage-3 doc with a phased roadmap and a **mandatory
  `X.close` row** → only then Stage 4. A tracked design is not DONE until its
  **PIR** lands.
- **The grounding-audit workflow is the default opener** for a grounding-heavy
  design (`.claude/rules/workflow.md`): it keeps file-reading in disposable
  sub-agent context and returns a distilled synthesis + `rlens_targets` the
  main session verifies **surgically**. But **the design dialogue itself is
  main-session + owner** — a workflow cannot make the design decisions.
- **The owner co-designs in PROSE with Q_N labels**, not AskUserQuestion chips
  ([[design-dialogue-preference]]). Give options, a recommendation, named
  costs, and ask for explicit rulings.
- **NTT model REQUIRED** if the design adds propagators/lattices/cells.
  **SRE lattice lens REQUIRED** for any lattice — and the result-shape question
  is lattice-shaped.
- **Adversarial gates**: the VAG / principles gate must **challenge**, not
  catalogue — two columns, and if nothing inherited gets challenged, re-run it.
- **Dailies**: STATE head (overwrite) + append-only LOG; roll at ~400–500 lines
  (currently ~230, fine). **Commits trigger dailies updates.**
- **Assert on every programmatic replacement** — an edit that cannot fail
  loudly will eventually fail silently (two instances in one session:
  a no-op `.replace`, and the `^[AM]` staging grep).
- Probes live in the scratchpad, **never** the repo. Don't name probe relations
  after builtins.
