# CIU 6 — D4, §5.PF

Part of [D4](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md), CIU 6's implementation design, split into its parts on 2026-11-06 (owner-approved). This file holds D4 as it stood at `3e76762d`, unchanged except link targets: D4 lines 12708–12761 are lines N-12701 here.

---

<a id="pf"></a>

### §5.PF — Path first-classness  (Q_U17 RULED B2, owner 2026-08-02)

**Why it exists.** Path first-classness today is **DECLARED, NOT DELIVERED**.
`segments : Path -> [List Keyword]` is true of exactly ONE of six step kinds, and
`path-segments` has **never marshalled** — it hand-builds a Prologos cons-chain
where the foreign marshaller wants a RACKET list (pre-existing, `f072c115`), so
`from-segments` and `path-append` are dead with it. Eleven production sites read
segments as bare symbols via `(expr-keyword seg)`, a silent type lie for four
kinds. ω did not create this; it made it unignorable. The full argument and the
disqualification of every alternative is [Q_U17](../2026-07-28_CIU_6_D4_DECISION_LEDGER.md#q-u17).

**Deliverables**

1. **`data Step`** in the lib, six constructors mirroring `select-step-kind`. The
   Racket-side classifier stays the single source of kind truth; the lib type is
   its reflection, so a seventh kind is added in ONE place and the marshaller's
   totality rides the existing `select-step-kind-unhandled` seat.
   ⚠ `step-sub` recurses through **`List`**, not `Path` — exactly as
   `datum-cons` recurses through `Datum`. **No parameterization, no mutual
   recursion**; `Path` stays ground. (This is why seed option B3 was unnecessary
   rather than merely costly.)
2. **`data Cont`** — the second ADT, and the cost the headline hides:
   `dissolve | synth | collapse | collapse-synth | (rename . k) |
   (collapse-rename . k)`.
3. **The `path-segments` repair, in the SAME change** (U17b). The fix is "return
   a Racket list" — `racket-list->prologos-list` already exists — but the repair
   must decide WHAT it returns. Returning keywords re-enshrines the lie;
   returning `Step` makes the spec true. Marshalling template already in-tree:
   `datum->datum-expr`. Same question for `head : Path -> Keyword`.
4. **Migrate the eleven bare-symbol consumer sites** through ONE marshaller.
5. **Revive `from-segments` / `path-append`**, dead since the abort.

**Cost, stated plainly.** TWO ADTs, not one. And it inherits the tax the `Datum`
module documents in its own comment: wildcard `_` in a match over a user data
type "triggers a type-inference limitation that causes module loading to fail",
so every `Step` consumer written in Prologos enumerates all six arms. A known
inference bug, not a design property — but real today, and it scales with the
vocabulary.

**What it enables.** P5's **B3 same-spine merge** needs structural comparison of
two paths, which is exactly what a first-class `Step` value permits and an
eliminator does not — that asymmetry is what disqualified the emergent B6.
Q_U12's deferred sorts (`#.field` nil-safe, `[k]` ordinal/dynamic) land as new
constructors rather than as new lies.

**Does NOT block P4c.** `(@bcast step)` is a unary constructor of a closed union
with ONE producer and ONE classifier, so converting it later is cheap *because
that is already the ADT shape*. The encoding is not where first-classness is won
or lost.

Status: ⬜ PF — **not started**; prerequisite of P5's B3.

