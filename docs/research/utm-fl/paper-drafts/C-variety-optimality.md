# Paper C — Variety-Stratified Optimality: Per-Variety Hasse Decomposition as Optimal Parallel Schedule

**Status**: skeleton v0.1.
**Type**: Theory paper.
**Target venues**: LICS, LMCS, or PTF-orbit theory venue.
**Time-to-submit estimate**: 18–24 months (skeleton now, run in parallel with A).
**Owner**: TBD.
**Co-authors**: TBD; Nation co-authorship discussion open as paper develops.
**Dependencies**: cites Paper Poly (categorical foundation). Independent of Papers A and B but mutually reinforcing with B.

---

## 0. Working title alternatives

- *Variety-Stratified Optimality for Lattice-Based Parallel Computation*
- *The Hasse Diagram is the Optimal Schedule (Per Variety)*
- *Per-Variety Cost Models for Propagator Networks*

---

## 1. Headline claim

For lattice variety **V**, the **Hasse diagram of a finitely-presented sub-lattice in V** is the **optimal parallel decomposition** under V's natural cost model.

Each variety has its own natural cost model; each variety's optimality result has its own proof shape. The unifying structural claim is the per-variety Hasse-decomposition pattern.

## 2. Instances

| Variety | Cost model | Status | Source |
|---|---|---|---|
| Boolean / hypercube | Parallel circuit depth | Theorem (cite source via PTF) | TBD |
| Distributive | Garg LLP rounds (lattice-linear predicate detection rounds) | Theorem (Garg) | Garg, *Predicate Detection: Theory and Application* |
| SD (semidistributive) | TBD | **Conjecture** | This paper |
| Modular | TBD | **Conjecture** | This paper |
| Free (FL) | TBD | **Conjecture** | This paper |

The interesting cases are SD/modular/FL. Boolean and distributive give us established theorems to anchor the framing; the novelty is the *unification* + the *conjecture extension* to higher varieties.

## 3. The binder boundary as worked example / counterexample

Per `2026-05-08_PROLOGOS_LATTICE_VARIETY_CATEGORIZATION`:

> A pervasive break occurs at the binder boundary (function/Pi types and their analogues in other domains).

The Prologos type lattice is distributive on the *ground sublattice* (atomic generators only) but breaks distributivity on the *wider sample* (binder-included). This is a worked example of:

- A real lattice that sits *between* distributive and free.
- The binder boundary is the precise structural transition.
- The optimality result for the ground sublattice (distributive instance) does *not* lift cleanly across the binder boundary.

This is either a counterexample to naive lifting, or the cleanest known case study for the SD/modular/FL conjectured optimality — the paper picks one.

## 4. Outline (TBD)

- §1 Introduction — the variety-blindness of most parallel-decomposition results.
- §2 Background — lattice variety hierarchy (FL ⊃ SD ⊃ modular ⊃ distributive ⊃ Heyting ⊃ Boolean); propagator networks as parallel schedules.
- §3 Boolean / hypercube optimality — the established result.
- §4 Distributive optimality — Garg LLP, restated under our framing.
- §5 The SD conjecture — natural cost model for SD; sketch of why Hasse decomposition should be optimal.
- §6 Modular and free conjectures — what the proof shapes would look like.
- §7 The binder boundary — worked example from Prologos type lattices.
- §8 Related work — Garg LLP; Boolean-circuit-depth literature; Whitman / Freese-Ježek-Nation; lattice-theoretic complexity (Bloniarz-Hunt-Rosenkrantz 1988); LVars.
- §9 Discussion — implications for compiler design (per-variety scheduler choice); leverage back into Paper B's "FL is the right substrate" claim.

## 5. Open questions blocking this paper

See `../open-questions.md`:
- Q-C1 (cost model) — what is "natural" per variety; is it canonical?
- Q-C2 (binder boundary) — match to known phenomenon? **Nation consultation track**.
- Q-C3 (Boolean/distributive instance citations).

## 6. Engineering anchors required

See `../engineering-anchors.md`:
- A1 (Whitman 10/10) — supports the FL/free-end of the variety hierarchy.

## 7. Risk profile

**Medium.** Optimality results are sensitive to cost-model choice; per-variety cost models may not be canonical. Boolean and distributive instances likely already-published theorems (citation work, not invention work). The novelty concentrates in:
- Unification under one framework.
- Conjecture extension to SD/modular/FL.
- Binder-boundary worked example.

## 8. Sequencing rationale (un-deferring)

Original plan deferred Paper C 24+ months. Updated plan skeletons C now, runs in parallel with A. Reasons:

- Paper C produces leverage *back into* Paper B's "this is the right substrate" claim. Deferring 24 months means Paper B carries the universality load without the optimality scaffold.
- Substantial existing material (`2026-05-08_PROLOGOS_LATTICE_VARIETY_CATEGORIZATION`, `2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE`, `2026-04-30_LATTICE_HIERARCHY_AND_DISTRIBUTIVITY_FOR_PROPAGATORS`).
- Skeletoning early lets the conjecture work mature with engineering, rather than waiting until engineering moves on.

## 9. Provenance / source material

- `2026-05-08_PROLOGOS_LATTICE_VARIETY_CATEGORIZATION.md` — empirical Whitman 10/10 + binder boundary.
- `2026-04-30_LATTICE_HIERARCHY_AND_DISTRIBUTIVITY_FOR_PROPAGATORS.md` — operational catalog per variety.
- `2026-04-30_LATTICE_VARIETY_AND_CANONICAL_FORM_FOR_SRE.md` — element-level theory.
- `2026-03-28_ALGEBRAIC_EMBEDDINGS_LATTICES.md` — PTF foundations.
- Garg, *Predicate Detection*.
- Bloniarz-Hunt-Rosenkrantz 1988 (lattice-theoretic complexity classification).
