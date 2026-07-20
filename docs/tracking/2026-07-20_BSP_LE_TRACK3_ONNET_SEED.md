# BSP-LE Track 3 — On-Network Tabling / Guard Seed (from Rel T1 Aspect-A)

**Date**: 2026-07-20 · **Series**: [BSP-LE](2026-03-21_BSP_LE_MASTER.md) · **Status**:
SEED (pre-design) for **BSP-LE Track 3 (Tabling / SLG memoization)**. NOT a design.
Captures two concrete on-network seams that Rel Track 1 (Aspect-A NAF/guard
correctness) hit and worked around with **interim DFS-routing scaffolding**, plus the
**prototyped-and-verified on-network mechanisms** that Track 3 should deploy so it can
delete that scaffolding. This is the "partial seed" for Track 3's design+implementation.

> **Why this exists**: Rel T1 made the DFS-vs-ATMS *routing* correct for NAF and guard,
> but the on-network *correctness* of tabled rule generators and guards is blocked on
> tabling infrastructure that Track 3 owns. Rather than build that infrastructure inside
> a usability track, Rel T1 routed the affected shapes to DFS (which is correct) and
> captured the on-network work here. Two scaffolding checks (`reachable-has-body-local-rule?`
> and `reachable-has-guard?` in `stratified-eval.rkt` `use-propagator?`) are Track 3's
> **retirement obligation** — see the [BSP-LE Master § Track 3](2026-03-21_BSP_LE_MASTER.md)
> and [DEFERRED.md](DEFERRED.md).

---

## Issue 1 — On-network tabled rule generators are INCOMPLETE (Rel T1 A.2b)

**Symptom (probe-verified)**: a rule generator forced on-network produces the wrong
answer SET, independent of NAF/worldview tags. `twohop(a,c):-edge(a,b),edge(b,c)` → `{}`
(empty); recursive `reaches` → base case only. DFS gives the complete set.

**First-order root — the body-local-var gap**: the on-network ATMS clause installer
builds `clause-env` from **head params only** (`relations.rkt` `install-one-clause` /
`install-one-clause-concurrent`), and `resolve-term` returns the **bare symbol** for a
non-param var. So a body-local (non-param) join/recursion variable gets no scope cell —
it is ground-matched — and the clause cannot bind through it. `collect-clause-vars`
(which would collect body-local vars) is **DFS/explain-only** today.

**Second-order root — tabling flattens per-branch worldviews**: even with a complete
answer set, the on-network tabling producer/consumer discards per-branch worldview tags
(the generator's output var lands without the distinct fact-bit tags the per-binding
machinery needs). **Four table-format co-change sites** (grounding-audit `wf_c2f8bfa3-db2`):
1. table cell born PLAIN, never `promote-cell-to-tagged`'d — `atms.rkt:459`
2. tag-blind `table-answer-merge` (dedup-append) — `atms.rkt:100-101`
3. `net-cell-write` worldview-tagging gated on old-val already tagged — `propagator.rkt:1993`
4. producer `logic-var-read` (worldview-collapsed) + flat untagged write — `relations.rkt:2743/2751`

**Prior art (adopt-or-diverge)**: PUnify Part 3 §9.6 "Interaction with ATMS Worlds"
(`2026-03-19_PUNIFY_PART3_ATMS_SOLVER_ARCHITECTURE.md:612-620`, designed-but-never-built):
table answers carry a **support set**; unconditional answers (support=∅) memoize across
all worlds; conditional answers are worldview-filtered. This two-tier split resolves the
memoize-vs-worldview tension a flat "tag every answer" destroys. NOTE: tables are
**per-solve** (fresh solver-context per top-level solve), which narrows the invariance
question and makes "diverge, tag the derived output" defensible.

**Track 3 work to retire the A.2b scaffolding** (`reachable-has-body-local-rule?`, Check 3):
(a) on-network body-local-var threading (reuse `collect-clause-vars`), (b) SLG completion
detection, (c) worldview-preserving table answers (§9.6 support-set or a divergent
per-answer tag). Then **delete Check 3** and the join/recursion generators flow back
on-network. Full detail: [DEFERRED.md](DEFERRED.md) § "Rel T1 A.2b DFS-routing scaffolding",
[Rel T1 design §5 A.2b](2026-07-19_REL_T1_RELATIONAL_USABILITY_DESIGN.md).

---

## Issue 2 — On-network guards are INCOMPLETE (Rel T1 A.4)

Guards live only in rule clauses (`&> ... (guard ...)`); rules table by default. So a
guard's generator materializes through the same on-network tabling path as Issue 1, and
the on-network guard has **three distinct real bugs** (each verified with valid probes):

- **(a) Struct-condition resolution gap.** The on-network guard's `resolve-condition-from-net`
  walked only `expr-app`/`pair`, NOT struct condition nodes like `expr-generic-gt`. So
  `[gt weight 0]` reached `eval-fn` with `weight` still an unresolved logic-var → `nf`
  went stuck → `truthy? [else #t]` → the guard **silently passed** (never filtered).
  (Contrast: the DFS guard path already uses `subst-logic-vars-in-expr`, which recurses
  into structs via `struct-info` — `relations.rkt` `solve-single-goal` guard arm.)

- **(b) Single-bit per-binding collapse.** `install-conjunction` tags every fact row of a
  multi-fact generator with the ONE shared guard bit `G` (rows at `(G|Bi)`). Clearing `G`
  hides ALL rows (over-narrow); keeping `G` leaks ALL rows. `guard-fire` reads the
  condition var worldview-collapsed to one value and evaluates the condition ONCE, so it
  cannot discriminate rows. This is the S0 (fire-once) analogue of the NAF single-bit
  collapse that A.2-core fixed at the S1 handler. Order-dependent symptom: leak-all OR
  lose-all depending on which value the last-write-wins collapse lands on.

- **(c) S0 belief-narrow does not persist.** `worldview-cache` is a **derived projection
  of decisions-state** (`install-worldview-projection`, `propagator.rkt:969-978`). A guard
  narrow performed at S0 (during the round) is **re-projected away** as decisions-state
  keeps evolving. NAF's identical AND-NOT persists only because `process-naf-request` runs
  in a **between-round** handler (after S0 + the projection quiesce).

**Interim fix (landed, Rel T1 A.4, commit `6b56397d`)**: Check 4 —
`reachable-has-guard?` in `stratified-eval.rkt` `use-propagator?` routes any would-be-
on-network query whose reachable relation graph has a `guard` goal to **DFS**, which
filters guards correctly (ground + free-var, single + multi-fact). Verified: wfle F2
`positive-edge` → `{(a,b,3),(c,d,5)}`, `positive-edge-nat` → `{(a,b,3N),(c,d,5N)}`.

### The prototyped on-network guard mechanism (verified — deploy in Track 3)

During A.4 the full on-network guard fix was **built and verified working** for a
generator that materializes on-network (`f2-guard-probe` → `{3,5}`), then reverted in
favor of the simpler DFS-route. Track 3 should re-land it once Issue 1's worldview-
preserving tabling makes every tabled generator materialize per-branch tags. The three
pieces:

1. **Struct-resolution fix.** Replace `resolve-condition-from-net`'s hand-rolled
   expr-app/pair walk with a var-name→value substitution + `subst-logic-vars-in-expr`
   (which handles struct condition exprs). Build the subst from the net (`logic-var-read`
   per condition var, or RAW per-binding for the generator var).

2. **Per-binding guard belief-clear** — the S0 analogue of `naf-per-binding-mask`
   (`relations.rkt:134`). Enumerate the condition's single multi-binding generator var's
   RAW tagged entries (`net-cell-read-raw` + `tagged-cell-value-entries`, NOT
   `logic-var-read` which collapses); evaluate the condition PER binding (a **pure**
   `eval-fn(subst)` — NO fork, unlike NAF's inner re-solve); AND-NOT `(OR failing) &
   ~(OR passing)` from the worldview-cache. The entry bitmask is the whole row's tag
   `(G|Bi)`, so the `failing & ~passing` cancellation clears exactly the failing row's
   fact-bit and preserves the shared `G` + passing rows (re-derived + verified).

3. **Between-round handler.** The belief-narrow MUST run in a between-round value-tier
   stratum handler mirroring `process-naf-request` (per bug (c)). Prototype: a new
   well-known **guard-pending cell** (was `cell-id 20` in `make-prop-network`, hash-union
   merge) + `process-guard-request` registered via `register-stratum-handler!`; the guard
   install writes a request (condition + env + guard-bit-pos + var-refs + eval-fn) instead
   of the S0 fire-once. Residuate (skip) when a condition var reads bot (Prolog-parity
   residual; a hard flounder terminal is deferred). **The guard analogue is SIMPLER than
   NAF** — the per-binding test is a pure eval, so no fork is needed.

**Track 3 dependency**: piece 2's per-binding enumeration reads the generator var's tagged
entries on the outer scope cell — which requires Issue 1's worldview-preserving tabling to
materialize them (a param-passthrough generator materializes today; a body-local-var one
does not). So the guard mechanism deploys AFTER Issue 1's tabling work. Then **delete
Check 4**.

---

## Grounding + prior syntheses (carry into Track 3 design)

- Grounding-audit `wf_c2f8bfa3-db2` (A.2b tabling) + `wf_ab037f07-570` (A.4 guard) — HEAD-pinned facet syntheses (the four co-change sites, the belief-vs-existence layer, the S0-vs-between-round stratum finding).
- Options-panel `wf_9c6eb408-522` (A.2b mechanism families: Family F consumer-fresh-bit vs Family P §9.6 support-set).
- [Rel T1 design](2026-07-19_REL_T1_RELATIONAL_USABILITY_DESIGN.md) §5 A.2b + §5 A.4.
- [DEFERRED.md](DEFERRED.md) § "Rel T1 A.2b DFS-routing scaffolding".
- Retirement checks to delete: `stratified-eval.rkt` `reachable-has-body-local-rule?` (Check 3) + `reachable-has-guard?` (Check 4).

**Process note (worth carrying)**: the A.4 investigation was lengthened by a WS-syntax
probe error — fact rows written on ONE line (`|| 5 3`) parse as a single wrong-arity row,
not multiple rows, yielding spurious empty results. Multi-line fact rows are required.
This masqueraded as an on-network/tabling failure. Track 3 probes must use multi-line facts.
