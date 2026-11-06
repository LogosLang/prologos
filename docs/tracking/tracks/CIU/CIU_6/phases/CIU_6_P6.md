# CIU 6 — D4, §5.P6

Part of [D4](../2026-07-28_CIU_T6_PATH_SELECTION_D4.md), CIU 6's implementation design, split into its parts on 2026-11-06 (owner-approved). This file holds D4 as it stood at `3e76762d`, unchanged except link targets: D4 lines 12786–12814 are lines N-12779 here.

---

<a id="p6"></a>

### §5.P6 — Demand semantics (staging decision + implementation)

The §2.2 collision, staged honestly: **decision by P3** (blocks make demand
observable), implementation possibly later. Options considered against
POL.10: (a) lazy leaf thunks in the champ (rep change; `.pnet` + effect-gate
interaction) · (b) a demand mark at elaboration (selection-aware forcing) ·
(c) defer §1.3 to a named post-v1 phase with the corpus marker documenting
the gap.

**RULED Q_U3 — option (c) [owner, 2026-07-30: "defer it — (c) stands"].**
Demand semantics is DEFERRED to a named post-v1 phase (the
**demand-semantics phase**, CIU T6 post-v1 — chartered by this stub, opened
only by explicit owner direction). Rationale (the P3a-close presentation):
the lift is a RUNTIME REPRESENTATION change deserving its own Stage-3
design; nothing in P3b–P5 depends on it (all value-level); demand's real
payoff needs the effect story and **Stratum 3 is comment-only at HEAD** —
lazy leaves without the effect stratum buy invisible timing changes for pure
programs and UNSEQUENCED effects for impure ones; the 4a X.close gate keeps
the deferral honest (the PIR must re-state the staged status and the owner
must charter or re-defer explicitly). **Charter-stub inputs for the future
phase's Stage 3**: thunked-champ-leaves vs demand-mark realization · `.pnet`
serialization of thunks · the effect gate · the whnf memo cache · sequencing
against (or explicitly without) the effect stratum. Eyes-open cost accepted:
an [ADOPTED] spec element stays unimplemented through v1; `[now]`/`[env …]`
leaves force at def-commit (the corpus §A comment documents it).
Status: **decision ✅ (Q_U3)**; the phase's residue = the X.close gate row.

