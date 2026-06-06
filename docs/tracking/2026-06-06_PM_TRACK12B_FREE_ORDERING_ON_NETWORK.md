# PM Track 12B — Free Ordering on Network (pre-design capture / implementation note)

**Date**: 2026-06-06
**Series**: PM (Propagator Migration)
**Status**: ⬜ NOT STARTED — Stage-0 pre-design capture. Needs full Stage 1–3 when picked up.
**Origin**: PPN 4C Addendum Phase 4B.4 mini-design grounding — grounding-audit `wf_c667e1e1-ab9` (5 HEAD-pinned facets + completeness critic) + main-session R-lens + empirical probes, 2026-06-06. **HEAD `9cc752ea`** (production `5a300609`).
**Owner-Series rationale**: closely related to PM Track 12 (registries → cells); PM 12B consumes PM 12's cells and adds the residuation + multi-pass retirement on top. Placed on the PM series per user direction (2026-06-06).

---

## §1 The thesis — the free-ordering north star

> **Full order-independence: every forward reference residuates to fixpoint on the network — no multi-pass parsing, no topological hoist, no order-dependency.**

Today's elaboration already achieves order-independence for *most* top-level forms — but it does so via **imperative scaffolding**: the FREE_ORDERING multi-pass preparse (Pass −1/0/1/1.5/2), the Phase-5b generated-decl hoist, and off-network registries consulted synchronously. That scaffolding is exactly the order-dependency machinery the lattice-fixpoint vision wants to dissolve (`2026-02-28_1800_FREE_ORDERING.md`: *"an imperative multi-pass parsing would be a regression for the lattice-fixpoint compiler that we hold as our North Star… should migrate to propagator-native approaches"*).

**PM Track 12B retires that scaffolding and replaces it with uniform on-network forward-ref residuation**, building on the NET-1 δ residuation substrate delivered by PPN 4C Addendum Phase 4B (def-bot pre-allocation + fire-once δ + file-end drive + DQ5 finalize).

This unifies several already-named-but-never-formalized follow-ups:
- §18.5 / §18.10.4 — "FREE_ORDERING → module-loading-on-network follow-up (scaffolding with retirement plan, post-Phase-4 / post-PM 12)."
- §18.11.3 — "the `loading-set` cycle check retires; cycle diagnosis via lattice fixpoint."
- §18.21.20 DQ4 — "module-load OUT → module-loading-on-network; REPL/string OUT → PPN Track 8/11."

(Cross-references are to `docs/tracking/2026-04-21_PPN_4C_PHASE_9_DESIGN.md`.)

---

## §2 Relationship to PM Track 12 (why 12B, not part of 12)

| | PM Track 12 | PM Track 12B |
|---|---|---|
| Concern | **Mechanical**: migrate registry `make-parameter`s → cells (registries on-network) | **Architectural**: make forward-refs **residuate** against those cells + **delete the imperative multi-pass** that substitutes for residuation today |
| Deliverable | The cells | Order-independence-by-residuation + scaffolding retirement |
| Relationship | — | **Consumes** PM 12's cells |

PM 12 gives you on-network registries; PM 12B makes a forward reference to a registry entry *wait on the cell at bot* rather than be pre-registered by an early pass. The two are distinct: you can do PM 12's migration without changing the multi-pass, and you cannot do 12B's residuation without the cells.

---

## §3 The scaffolding to retire (grounded inventory @ HEAD `9cc752ea` — RE-GROUND on pickup)

All line numbers are post-4B.3-b; re-verify at the then-current HEAD (the 4B arc shifts coordinates).

1. **Pass-0 / Pass-1 imperative pre-registrations** — `macros.rkt:2390–2460`. Pass 0 pre-registers no-dep declarations *"so that later declarations… find these registrations regardless of source ordering"*: `process-data`/`process-trait`/`process-deftype`/`process-defmacro`/`process-bundle`/`process-property`/`process-functor`, plus `register-schema!` (`:2424`) and `register-selection!` (`:2434`, *"Pre-register selection name so… forward references work"*). Pass 1: `process-spec`/`process-impl` (`:2452`/`:2459`). **This is the imperative substitute for residuation.** → forward-refs to data/trait/schema/selection/spec/impl residuate on-network.

2. **Phase-5b generated-decl hoist** — `macros.rkt:2876–2903`. A stable partition that reorders data/trait-generated `def`/`defn`/`spec`/`deftype` to the **front** so *"constructor types and trait accessor types enter global-env… BEFORE any user defn/def is type-checked."* **The clearest order-dependency scaffold.** → ctors residuate instead of being hoisted (requires generated-name seeding, below). NB: impl-generated defs are deliberately NOT hoisted (`:2884–2885`) because impl helpers reference user defns — that case is *already* order-fragile and is a 12B target.

3. **Generated-name seeding gap** — `macros.rkt:2480–2486` (Pass 1.5, the 4B.2 substrate) seeds def-bot cells for **user** `def`/`defn` names only; it runs **pre-expansion** so it *cannot see* data/trait-generated ctor/accessor names. 12B needs a **post-expansion** seeding pass so generated names get def-bot cells and can be forward-referenced via residuation. (Pass 1.5 itself is free-ordering-*aligned* — KEEP/extend, not retire.)

4. **The 3 synchronous typing env-reads** — `typing-propagators.rkt:1771` (fire-time fvar read in `make-fvar-fire-fn`), `:2475` (install-time fvar read), `:2644` (ctor-type read). All are `global-env-lookup-type` (a ground-only projection of the NET-1 mnr) executed **on the NET-2 typing network**; they `#f`-skip / leave-⊥ on a pending referent. Converting them to *wait* on a NET-1 cell is **the cross-network seam** (NET-1 env ↔ NET-2 typing) — the A3-narrow / §6 boundary 4B explicitly refuses to cross.

5. **Off-network registries that gate forward-refs**:
   - `current-multi-defn-registry` (`multi-dispatch.rkt:24`) — a `make-parameter` hasheq, off-NET-1. The multi-clause **base name** `foo` lives ONLY here (only the per-arity clause cells `foo::N` reach the mnr); bare unapplied `foo` is a **hard error** (`elaborator.rkt:735`). And Pass-1.5 seeds a base-name `foo` def-bot cell that **never grounds** (no `global-env-add 'foo`) → `module-network-lookup-status 'foo` is **permanently `'pending`** — a latent landmine for any "wait on foo" δ. 12B brings the multi-defn registry on-network (via PM 12) + grounds `foo` so a forward-ref residuates.
   - `current-relation-store` (defr's relation side-effect, `driver.rkt:689–693`) — defr is a **full** mnr-writer (`global-env-add`, `:682/:686`, NOT type-only) *plus* an off-network relation-store write whose ordering a deferred commit must preserve.
   - `current-capability-registry`, the schema/selection registries, trait/impl registries — PM 12 migrates them; 12B residuates forward-refs against them.

6. **The `loading-set` cross-module cycle check** — `driver.rkt:~2132` (`(error 'imports "Circular dependency detected: …")`). Cross-module cycles are syntactically rejected. → cycle diagnosis via lattice fixpoint (§18.11: lazy/productive cycles converge; strict cycles diagnose as fuel-exhaustion).

7. **Capability/session early-resolution path** — empirically, forward-refs to capabilities/sessions resolve *today* (see §4 probe **b**) via a residuation-free preparse-era mechanism whose exact site was not pinned in the 4B.4 probe (selection/schema = Pass-0 confirmed; capability/session = TBD). Ground it on pickup and unify under on-network residuation.

---

## §4 Empirical evidence (the 4B.4 probes, `process-file` @ `5a300609`)

| Probe | Program | Today | Reading |
|---|---|---|---|
| **h** | `def x := a` ; `def a := 5N` (inferred fwd→def) | 0 err — residuates | the 4B.3 slice (shipped) |
| **g** | `def x : Nat := a` ; `def a := 5N` (**annotated** fwd→def) | **1 err: Unbound** | the genuine **4B.4** gap (annotated path gated out of residuation) — stays in 4B.4, NOT 12B |
| **b** | `def a := ReadCap` ; `capability ReadCap` (fwd→type-only producer) | **0 err** | type-only producers **already order-independent** via the imperative multi-pass (Pass-0 pre-reg for selection/schema; capability/session via a preparse-era path) — a **12B** retirement target, not a 4B.4 gap |
| **e** | `def a := ReadCapXYZ` (never defined) | 1 err: Unbound | confirms the later definition is what resolves the forward ref |

*Caveat (verified-vs-inferred)*: `prop_allocs`/`prop_firings` are **NET-2** counters and do **not** count the NET-1 mnr δ, so they cannot by themselves prove a forward-ref is residuation-free. The "type-only producers are already order-independent" conclusion rests on (a) the empirical **b** = 0 err and (b) the code-confirmed Pass-0 `register-selection!`/`register-schema!`. The exact capability/session early-registration site is flagged for the 12B Stage-2 audit.

---

## §5 Dependencies

- **PM Track 12** (registries → cells) — the substrate 12B residuates against. **Hard dependency.**
- **PPN 4C Addendum Phase 4C/4D** (the cross-network seam: NET-1 env ↔ NET-2 typing; the §6 install-breaks-resolution diagnosis) — required for the type-position forward-refs and the ctor-read conversion (§3 item 4). The 3 synchronous typing reads cannot become NET-1-residuating without resolving how a NET-1 cell feeds a NET-2 read **without** installing a NET-2 propagator (the A3-narrow constraint; §6 is the latent risk).
- **PPN 4C Addendum Phase 4B** (the NET-1 δ residuation substrate: def-bot pre-alloc, fire-once δ, drive, finalize) — 🔄 in progress; 12B builds directly on it.
- **NOT NTT.** NTT §17b (the speculative `cross-network-bridge` form) is *future syntax* for declaring such networks with the expressivity we already implement in Racket; the cross-network access is implemented **directly** (function-call today; propagator-installed reactive later). There is **no implementation dependency** on NTT. (Correction recorded 2026-06-06 — an earlier framing over-stated this.)

---

## §6 Scope boundary vs PPN 4C Addendum Phase 4B.4

**4B.4 keeps (tractable now, on the NET-1 δ substrate):**
- The **annotated-path forward-ref residuation** (probe **g** — the confirmed gap): drop the `(not type-surf)` gate in `process-def`, reuse the NET-1 δ (defer the annotated-path `:1418` commit; the pre-register's `#f` value is kept-old by `def-value-lww`, so the δ stays sole writer).
- Co-design micro-decisions: the multi-clause base-name seed-landmine (hygiene fix vs defer-with-the-bridge); import-shadowing (own-ns `qualify-name` vs full `resolve-name`, D-4B3-8/9).

**12B takes (everything that needs the deeper substrate):**
- Type-only producers' forward-refs (selection/capability/session) — already handled by the multi-pass; the free-ordering work is *retiring* the multi-pass, not adding them to the δ.
- The ctor-read conversion + Phase-5b hoist retirement + generated-name seeding.
- The multi-defn-registry-on-network bridge + the relation-store ordering.
- Type-position forward-refs (NET-2 typing residuation).
- The `loading-set` cross-module cycle check → lattice-fixpoint diagnosis.

---

## §7 Open design questions (for the eventual Stage 1–3)

1. **Generated-name seeding mechanism** — a post-expansion topology pass (sees ctor/accessor names) vs a forward-model from the data/trait declaration. How does it stay order-insensitive (the FREE_ORDERING guard)?
2. **The cross-network seam** — how does a NET-1 env cell feed a NET-2 typing read *without* installing a NET-2 propagator (A3-narrow), or is the §6 install-breaks-resolution risk finally diagnosed and the constraint lifted? (Coupled to 4C/4D.)
3. **Multi-defn-registry-on-network** — bring `current-multi-defn-registry` on-network (PM 12) + ground the base name so a forward-ref residuates; reconcile bare-vs-applied (`foo` error vs `foo::N` dispatch).
4. **Type-position residuation** — forward-refs in type position (`def x : Foo := …`) read the `:type` facet on NET-2; what residuates them, and is it the same mechanism as the value-δ or a `:type`-facet analogue?
5. **Cycle-as-lattice-diagnostic** — replace the `loading-set` syntactic rejection with productive/unproductive-cycle diagnosis via fixpoint convergence (§18.11).
6. **Retirement ordering** — which pre-registration retires first; what is the per-form gate that proves "residuation now covers what the pre-registration covered" (the parity gate, à la 4A.c-iii-b's writer-census).

---

## §8 Principle alignment

- **On-network / Hyperlattice**: the multi-pass + hoist are off-network order-dependency; residuation-to-fixpoint is the on-network expression. Retiring the scaffolding is the vision, not an optimization.
- **Genuine-dependency deferral (not Let-Pain-Drive)**: 12B is deferred because the *substrate* isn't built (PM 12 cells + the 4C/4D cross-network seam), NOT because there's no pain. The pain is real (the imperative multi-pass IS the regression the North Star names); the substrate is the blocker.
- **Correct-by-Construction**: replacing imperative pre-registration with structural residuation makes "forward reference works" a property of the topology, not of pass ordering.
- **Decomplection**: separates *what is declared* (cells) from *when it is reachable* (residuation to fixpoint) — currently complected by the pass that pre-registers names in a fixed order.

---

## §9 Cross-references

- PPN 4C Addendum Phase 4B mini-design — `docs/tracking/2026-04-21_PPN_4C_PHASE_9_DESIGN.md` §18.21 (esp. §18.21.16 D1-D6, §18.21.22 the δ substrate, §18.21.23 the 4B.4 scope reframe that spawned this note).
- PM Track 12 — `docs/tracking/2026-03-13_PROPAGATOR_MIGRATION_MASTER.md` § Track 12.
- FREE_ORDERING — `docs/tracking/2026-02-28_1800_FREE_ORDERING.md` (the 3-pass preparse this track retires).
- DEFERRED.md § "Free Ordering on Network (PM Track 12B)".
- Grounding-audit run: `wf_c667e1e1-ab9` (5 facets + completeness critic @ `9cc752ea`).
