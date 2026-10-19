# PAR 4 D.2 — self-critique (P / R / M lenses and the SRE lattice lens)

**Of**: [`../2026-10-15_PAR_4_D2_DESIGN.md`](../2026-10-15_PAR_4_D2_DESIGN.md), as first drafted at `2c758ce4`.
**Method**: `CRITIQUE_METHODOLOGY.org` (the three lenses, the SRE lattice lens, the finding format). This is the D.2
self-critique the methodology asks for before the external round; the agent-driven adversarial round (D.3) follows and
writes `2026-10-1x_PAR_4_D3_EXTERNAL_CRITIQUE.md` beside this file.

**Labels**: `D2P-n` (principles), `D2R-n` (reality check), `D2M-n` (propagator mindspace), `D2L-n` (SRE lattice lens).
They are prefixed with the document so that they cannot collide with the track's phases P1–P6. **Resolution**: *applied*
(D.2 revised in the same commit), *kept open* (a question for D.3 or the owner), or *rejected*, with the reason.

## Summary

Of 19 findings, 13 are applied to D.2, 4 stay open (D2P-5, D2R-5, D2M-1, D2L-5) and 2 are rejected (D2P-6,
D2M-3). The three that change the design:
- **D2L-1**: the worldview's derived read is anti-monotone, so P1a row 1 fixes the merge but not every reader.
- **D2P-3**: fire-once is only legal on a stable latch, which conflicts with P1b's "re-fire on growth".
- **D2P-2**: correctness by construction needs join *combinators*; E is a check, not a construction.

## P — principles challenged

**D2P-1 — the fence is a "keep the old path as fallback".** That is one of the red-flag phrases, and its retirement
depends on another track (PC-1, PC-2). If PPN 4C never supplies a two-argument type merge, the fence becomes
permanent, and the K > 1 claim quietly shrinks to non-typing work.
→ **Applied**: the fence gets an exit criterion and an owner. It retires cell by cell, measured by the fenced set, and
the set is reported in every epoch record (D2P-4) and at P3's gate. O-12 is the owner's decision on who builds the
residual.

**D2P-2 — "correct by construction" is overstated for E.** E samples a merge's laws at registration time. That is a
check, closer to a co-inductive monitor run once, not a construction. The principle could be more truly served: most
of P1a's targets are built from a handful of join combinators — max, ior, set union, the flat lattice with ⊤, pointwise
map join, product. A merge *assembled from* those is a join by construction, with no sampling.
→ **Applied**: P1a adds a small combinator library (`join:flat`, `join:max`, `join:ior`, `join:set`, `join:pointwise`,
`join:product`) whose results carry a `join` declaration by construction. E samples only hand-written merges. The
inductive layer of G-2 becomes the combinators, and E moves to the co-inductive column for the remainder.

**D2P-3 — fire-once and the unstable latches conflict.** P1b proposes "re-fire on growth" for the seven unstable
latches. But those sites are fire-once propagators: BSP self-clears them after the first productive fire (the fired-set
logic in the inner loop, `propagator.rkt:3530-3543`), and P2's executor copies that. A fire-once propagator *cannot*
re-fire. The real rule is that fire-once is an optimization valid only when the output is constant once the trigger
holds, i.e. a *stable* latch (the Q1 audit's 17 stable latches).
→ **Applied** to P1b: "fire-once is declared only on a stable latch". Each unstable latch either drops fire-once (and
re-fires on growth) or latches only on a value that cannot grow. The fire-once flag joins the properties E-like
checking covers: a sampled check that the output does not change above the trigger.

**D2P-4 — first-class by default: the fence is invisible.** Which cells are fenced, and why, is scheduler-internal. In a
user network (`reduction.rkt:4456`, `user:net-run`) that is exactly what a user needs to see (G-3, GT-6).
→ **Applied**: epoch records name the fenced cells of the epoch, and E's verdict is a cell (D2L-4).

**D2P-5 — simplicity: the S0 ↔ S0-fenced alternation is a new construct with no theorem.** The simpler correct
alternative is a whole-network rule: a network with any fenced cell runs at K = 1. It is trivially correct and needs no
alternation. Its cost is that elaboration networks, which nearly all contain type cells, would not run in parallel until
PPN delivers. The alternation's value is the parallel share it recovers, which no one has measured.
→ **Kept open**, with a measured decision rule: P0-8 measures the S0 share that writes type cells. If the recovered
share is small, take the whole-network rule (simpler); otherwise the alternation. D.2 §6.3 now names both.

**D2P-6 — orthogonality: row 4 couples a fire's computation to a merge choice.** "Write totals, merge by max" prescribes
what the fire computes from the merge's semantics. That is a cell/propagator contract, not a scheduler coupling, and it
is the normal shape of a monotone propagator: an output that is a monotone function of the inputs, joined.
→ **Rejected**: no layering violation. Recorded so D.3 does not re-raise it without new evidence.

## R — reality check (re-derived at HEAD, `racket/` = main `c1f389ab`)

**D2R-1 — the 11 reads of `current-bsp-fire-round?` are not all one shape.** Measured by reading each:
- 9 choose request versus inline install: `sre-core.rkt:2469, 2689, 2712, 2804, 2817`, `narrowing.rkt:296, 348`,
  `elaborator-network.rkt:897`, `constraint-propagators.rkt:288`;
- 2 decide whether an install also enqueues on the worklist: `propagator.rkt:2343, 2517`, "Don't modify worklist
  during BSP".

After G-1 no install happens inside a fire, so the second pair always takes the outside-a-fire branch.
→ **Applied**: D.2 §6.5 states the 9 + 2 split. The parameter is still deletable, and the claim is no longer CONJECTURE.

**D2R-2 — P3's `home` field touches the `propagator` struct.** It has 7 production constructor sites (grep
`(propagator ` outside tests, benchmarks and tools), plus `.pnet` serialization.
→ **Applied** to §12.2: home is computed at the topology stratum from the assignment and *not* stored in the struct. It
is a derived read (owner of the first output), so neither the struct nor `.pnet` changes. This is better on-network
anyway.

**D2R-3 — the fire-once / self-clear logic must not be reimplemented.** P0 §2.5: the sequential drain lacks it, and 27
test files fail under it. P2's executor must call the same code BSP uses, not a copy.
→ **Applied** to §6.6: factor `self-clear-fire-once` out of the inner loop, and have both schedulers call it.

**D2R-4 — the Tier-1 flush is not mentioned.** `run-to-quiescence-bsp` has a Tier-1 path (`propagator.rkt:3431-3446`)
that fires fire-once, empty-input propagators directly, with no rounds. It is already "DIRECT", and it emits no
observation record (DEFERRED 176 item 4).
→ **Applied**: §6.6 keeps Tier 1 as is. It is DIRECT at K = 1 by construction, and P2 gives it an epoch record.

**D2R-5 — the retry bridge is shared territory.** `metavar-store.rkt:1063` is PPN 4C's ground. Its branch has not
changed `metavar-store.rkt`, `typing-propagators.rkt` or `type-lattice.rkt` relative to main (measured with `git diff
--stat main ppn4c-elaboration-on-network`), but it is live.
→ **Kept open** for D.3's cross-track critic and the owner: P1a rows 8 and 9 need PPN 4C's agreement before they land
(PC-2, PC-3).

## M — propagator mindspace

**D2M-1 — "the two alternate until neither has work" is imposed ordering.** It is, and it belongs to the fence, which
is scaffolding (D2P-1, D2P-5). An emergent version would need the fenced merges to be joins, which is the very thing
missing.
→ **Kept open**, tied to D2P-5.

**D2M-2 — the epoch record's "changed cells" implies a diff walk.** At K = 1 the diff of two persistent maps shares
structure and is cheap. At K > 1 it would be a scan over every owned cell at each boundary. The emergent form: each
executor adds a cell to its own changed-set (a monotone set cell) when an owned cell strictly increases, and the
epoch's changed set is the union at the boundary.
→ **Applied** to §7 and §9 (`exec-changed : Cell (Vec K (Set CellId))`).

**D2M-3 — the detector is a scan.** It is, and CALM says detection cannot be monotone. It is declared at the boundary
fiber, and its cost was measured (P0 §4.1).
→ **Rejected** as a defect; kept as the one declared non-monotone act.

## SRE lattice lens

**D2L-1 — the worldview's derived read is anti-monotone.** P1a row 1 makes the *stored* worldview a join (committed ior,
invalidated ior). But the read `live = committed ∧ ¬invalidated` *shrinks* as invalidated grows. A fire that filters
its inputs or outputs by `live` inside S0 is anti-monotone even though every write is a join. That is the read-side
failure the merge-law gate warns about (`design-doc-gates.md`). D.2 §6.5 also claimed that row 1's derived read
removes the ambient `current-worldview-bitmask` read in unwrapped fires, and that is wrong if fires read `live`.
→ **Applied**: the rule in §6.3 row 1 and §6.5 is that, inside S0, fires compute on *labelled* values (tagged entries
keyed by assumption bits) and never filter by `live`. `live` is read only at boundaries (S(−1), S1, and observation).
The scheduler may *skip* enqueueing work whose assumptions are invalidated, because invalidation is permanent: skipping
more over time never changes a labelled result. CONJECTURE until P1b's census of worldview reads inside fires
(`maybe-wrap-worldview` and the unwrapped read at `metavar-store.rkt:504`) shows every one fits.

**D2L-2 — lanes as sets need idempotent deltas, and fenced cells must not receive lane deltas.** Under the fence, a
fenced cell is written only in the deterministic sub-run, on the scheduler thread with the executors parked.
→ **Applied** to §6.7: fenced cells have no owner during the DIRECT phase; a DIRECT fire that would write one is itself
fenced by definition.

**D2L-3 — `map-union-disjoint` is partial.** The assignment and the epoch records are written once per key. A second
write to the same key must be ⊤ (a classified error), not undefined.
→ **Applied** to §9: flat per key, with ⊤ on conflict.

**D2L-4 — E's verdict should be a cell, not a boolean computed off-network.** SRE already has a property lattice
(`prop-confirmed` / `prop-contradicted`, joined by `infer-domain-properties`). The fence is then a propagator from that
property cell to the scheduler's placement: a Galois-style bridge from the property lattice to {fenced, free}, where
contradicted ⇒ fenced and confirmed ⇒ free, monotone in the property lattice.
→ **Applied** to §6.3 and §9 (`merge-props` cells; `fence` derived).

**D2L-5 — the multiplicity order for `:usage` must be spelled out.** The lean (totals in the fire, pointwise max) is a
join only on a chain ⊥ < 0 < 1 < ω, where + on usages is monotone. `qtt.rkt`'s `join-usage` (`:93`) is the alternation
combinator, so it is a different operation and not that join.
→ **Kept open** for P1a, with E's samples: is + monotone on that chain for every arity (the arity ≥ 3 fold at
`typing-propagators.rkt:1789` is the case to probe)?

## What D.3 should attack hardest (handed to the critique round)

1. D2P-5 / D2M-1: the fence's form. Is there a design with no fence at all?
2. D2L-1: whether every in-S0 worldview read can be made labelled.
3. §6.7's memory-model claim (R-2): the citation is still owed.
4. §2 item 3: the realizable K > 1 value before PPN 4C.
5. P1a row 2's conjecture that no program relies on overwrite.
