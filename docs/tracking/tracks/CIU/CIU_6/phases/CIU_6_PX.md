# CIU 6 — D4, §5.PX

Part of [D4](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md), CIU 6's implementation design, split into its parts on 2026-11-06 (owner-approved). This file holds D4 as it stood at `3e76762d`, unchanged except link targets: D4 lines 12776–12785 are lines N-12769 here.

---

<a id="px"></a>

### §5.PX — Binder-seam substrate (carried unchanged)

The D3-S10 concrete-codomain lambda-adoption hole
(`[the [List String] [map [fn [x] x] ints]]` accepts silently) + the
standalone-def seam (`def f := [fn …]` / `def add5 := [int+ 5 _]` fail where
the body determines the types). Surface-independent; the old doc's round-6b
capture stands. Position flexible. Status: ⬜.

