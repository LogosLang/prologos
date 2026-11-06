# CIU 6 — D4, §5.P0

Part of [D4](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md), CIU 6's implementation design, split into its parts on 2026-11-06 (owner-approved). This file holds D4 as it stood at `3e76762d`, unchanged except link targets: D4 lines 4264–4309 are lines N-4257 here.

---

<a id="p0"></a>

### §5.P0 — Acceptance corpus

**✅ LANDED `e2674208` — 28/28 markers, 0 errors** (was 21/21).

**Intent [owner]: AUGMENT the existing acceptance file** —
`examples/2026-07-26-ciu-t6-path-selection.prologos` — with the spec's §10
examples and Appendix fixtures. One file, not two: it already held the P0
charter and its working markers are live P1/P2 substrate regression.

**What landed**:
- **All 7 spec Appendix fixtures load** (`users` · `build` · `regions` ·
  `strings` · `m` · `events` · `tree`). Layout bodies use the `def X`
  implicit-map form — the `def X :=` form hits **issue #80** (filed).
  `now`/`env` stubs carry indicative values (the staged-demand ruling 4a).
- **Fixture convergence**: `app-config` gained `:date [now]` and
  `:url [env "DATABASE_URL"]` per the spec Appendix; its marker was
  re-transcribed.
- **The dead old-bracket-surface targets were REPLACED** with the phase-tagged
  spec corpus in HEAD notation: §B blocks [P3] · §C splat + Ruling B [P4/P5] ·
  §D broadcast [P4] · §I the §10.2–§10.8 corpus (incl. disclose `:<`). §10.6
  transposes and §10.8 recursion stay PERMANENTLY commented with their
  v2/exit pointers.
- **The `v[0]` NOTE was corrected** — the PS2 flip is canceled, so that pin is
  now a MUST-NOT-BREAK regression, not a flip warning.
- **Two fixture outputs double as §2.3 carrier documentation**: `users`
  exhibits the literal-arm 1-tuple collapse (which ruling 2a routes around),
  and `events` pins the het-tuple carrier that the 2b split's first rule
  targets.

**Normativity protocol (refined by ruling, Batch 1)**: the corpus is executable
spec. Divergence between file and spec in **NOTATION** is transcription —
resolved by the §2.3 table. Divergence in **RESULT** is semantics — resolved by
ruling, **never by quietly editing a marker**.

**Still open here**: the spec fixture's computed leaves force EAGERLY until
§5.P6, so the §1.3 demand property is a marker COMMENT, not an assertion, in
v1. Forced values are indicative (spec §10 preamble), so every other §10 result
is unaffected.

**At X.close**: the file promotes to a suite-gated regression test.

**Test delta**: the augmented file + its `--check` gate — **28/28** (from
21/21); records acceptance unchanged at 89/89; zero production code touched.

