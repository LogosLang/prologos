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
   - `current-multi-defn-registry` (`multi-dispatch.rkt:24`) — a `make-parameter` hasheq, off-NET-1. For a **genuine multi-arity** defn (≥2 distinct arities) the **base name** `foo` lives ONLY here (only the per-arity clause cells `foo::N` reach the mnr); bare unapplied `foo` is a **hard error** (`elaborator.rkt:735`). And Pass-1.5 seeds a base-name `foo` def-bot cell that **never grounds** (no `global-env-add 'foo`) → `module-network-lookup-status 'foo` is **permanently `'pending`** — a latent landmine for any "wait on foo" δ. **Probed 2026-06-06 (`process-file` @ `5a300609`, 4B.4 micro-decision #1):** `def x := foo` for a genuine multi-arity `foo` → file-end **"Unbound variable"** *both forward and backward* (order-independent, residuate-never-grounds); for a **single-arity multi-pattern** `foo` it works (0 err — base name grounds). **Pre-existing in 4B.3**; `def x := foo` is inherently ill-formed in value position (no single value for an arity-dispatched name). 12B brings the multi-defn registry on-network (via PM 12) + grounds `foo` (or routes bare refs through `lookup-multi-defn`) so a forward-ref residuates, **and restores the more-informative "must be applied" diagnostic** that residuation currently replaces with "Unbound variable" (a diagnostic regression).
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

**4B.4 keeps (tractable now, on the NET-1 δ substrate) — and that is ALL of 4B.4:**
- The **annotated-path forward-ref residuation** (probe **g** — the confirmed gap): drop the `(not type-surf)` gate on the **real-body** annotated branch in `process-def`, reuse the NET-1 δ (defer the annotated-path `:1418` commit; the pre-register's `#f` value is kept-old by `def-value-lww`, so the δ stays sole writer; EXCLUDE the opaque data-type branch `:1321–1332` whose value never grounds). **The three co-design micro-decisions were RESOLVED 2026-06-06 (PPN 4C design §18.21.23.6) — ALL DEFERRED** (see "12B takes" below + 4B.5 for dedup); 4B.4 carries no guard for them.

**12B takes (everything that needs the deeper substrate):**
- Type-only producers' forward-refs (selection/capability/session) — already handled by the multi-pass; the free-ordering work is *retiring* the multi-pass, not adding them to the δ.
- The ctor-read conversion + Phase-5b hoist retirement + generated-name seeding.
- The multi-defn-registry-on-network bridge + the relation-store ordering — **incl. the multi-clause base-name landmine (4B.4 micro-decision #1, deferred 2026-06-06):** ground the base name / route bare refs through `lookup-multi-defn` so `def x := foo` for a genuine multi-arity `foo` residuates instead of file-end "Unbound", and restore the "must be applied" diagnostic (§3 item 5).
- **Import-shadowing forward-refs (4B.4 micro-decision #2, deferred 2026-06-06; D-4B3-8/9):** the δ stores the own-ns `qualify-name` (`driver.rkt:1102`); import-shadowed referents need the full `resolve-name` (refer-map/aliases) order. Part of the broader on-network name resolution.
- **defr value-position forward-refs (4B.4 micro-decision #3, deferred 2026-06-06):** defr is a full-value mnr-writer but its names are not Pass-1.5-seeded → `'absent` → immediate error; needs the seeding extension + the relation-store ordering (§3 items 3 + 5). *(install-dedup is NOT a 12B item — it belongs to PPN 4C Addendum Phase 4B.5 [general-body / multi-reference], not free-ordering.)*
- **The merge-as-answer ("γ") for annotated-def type-obligations (4B.4.a co-design, deferred 2026-06-09):** the fully-on-network treatment of `def x : T := a` forward-refs is the `def-entry-merge` upgrade the forward-compat note anticipates (`definition-entry.rkt:65–71`): **type-unify-or-top on `:type`** (+ set-once on `:value` if redefinition becomes an error). The merge itself then computes `T ⊓ type(a)` — T-preservation AND the type-obligation become structural, and an incompatible referent surfaces as `def-collision` (⊤) **emerging from the lattice**, consumed per the D6 lock (§18.21.16: the future cross-network track "should CONSUME the existing `def-collision` ⊤, not introduce a new one"). 4B.4.a instead ships **re-supply-T** (the annotated δ writes `(def-entry T value)`, T captured at install time) + a **finalize-time imperative `check/err`** for the obligation — named scaffolding under D6's error-monad shell; γ retires BOTH. Genuine dependencies: (a) the type-obligation computation is NET-2 elaboration machinery (meta-store, trait/subtype registries) → needs the cross-network seam (§3 item 4 / §5) for the contradiction to *emerge* on-network rather than be imperatively asserted inside a fire-fn; (b) the **redefinition language-design decision** (LWW legal-redefinition vs set-once-error) — the merge change is half of that decision and incoherent without it; (c) `def-entry->cons`'s loud-error contract on `def-collision` (`namespace.rkt:183–184`) relaxes to a consumed-⊤ read path (today it is a Correct-by-Construction tripwire for ALL def cells); (d) the §18.21.17 carried single-write obligation was argued on LWW — the algebra change re-opens that argument.
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
7. **The γ merge upgrade (type-unify-or-top on `:type`)** — sequencing + coupling: gated on the redefinition language-design decision (LWW vs set-once); changes the merge algebra the §18.21.17 single-write obligation was argued on (every def cell revalidates); the `def-collision` consumer story lands with it (see the §6 "merge-as-answer" item). Does γ land with the typing-read conversion (§3 item 4), or as its own slice?

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

---

## §10 On-network deferred typing — the PPN 4C Addendum Phase 4B.5 "(iii)" design capture (2026-06-10, user-directed visible work)

4B.5's mechanism fork (design doc §18.21.25.3 Q-4B5.1) chose **(ii-b)** — an imperative demand-driven sweep at the finalize layer — and deferred **(iii)**, the on-network realization, HERE as visible work. Same verdict shape as the 4B.4.a TC-(b) analysis: *the cheap version is principle-blocked; the principled version is infrastructure-blocked.* This section is the principled version's design capture, to be picked up when the prerequisites land.

### §10.1 What (iii) IS

General-body forward-ref residuation realized as genuine on-network deferred typing: the body's NET-2 elaboration/typing state **survives** across commands; when the referent's `def-entry` cell (NET-1) grounds, the typing propagators **re-fire** and the def commits structurally — no sweep, no placeholder list, no imperative retry. The 4B.5 sweep + SCC pass + the A1 gate + the demand trigger ALL retire under (iii). Together with the γ merge-as-answer upgrade (§6 item; type-obligation emerges from the lattice), this completes on-network elaboration for the def layer.

### §10.2 The three prerequisites (why it's infrastructure-blocked)

1. **PM 12 cells** — the ambient elaboration context (registries, parameters) that deferred typing needs must be on-network state, not parameterize-scoped Racket state that dies with the command.
2. **PM Track 13 mnr↔elab unification OR the NTT §17b cross-network bridge** — a NET-2 typing propagator must `:reads` a NET-1 `def-entry` cell. Today a propagator is `net → net` on ONE network; the crossing needs either unification (one network) or a genuinely new cross-network bridge primitive (NTT §17b, 5 open Q's).
3. **§6 root-cause diagnosis** (PPN 4D note §6, install-breaks-resolution) — (iii) installs propagators into NET-2's meta-resolution fixpoint, exactly the undiagnosed sensitivity class. The `first-of-rest` canary is a tripwire, not a license.

### §10.3 Audit facts to build against (R-lens-verified @ `ed8e2200`; design doc §18.21.25.1 — RE-GROUND on pickup)

- **The live per-command discard is `reset-meta-store!`** (metavar-store.rkt:2869 `(set-box! net-box (make-elaboration-network))`) — 7 driver sites (:462 per-command, :1536 per-clause, :1658, :1705, :1753, :1983, :2649) + metavar-store.rkt:1841, with DUAL behavior gated on `(when new-cell-fn …)` (:2865-2866). The non-discard reset must reconcile ALL sites + both gate behaviors (pipeline.md Two-Context Audit).
- **`reset-elab-network-command-state` (elab-network-types.rkt:104) is dormant AND broken** — zero callers (callback removed by Track 7 Phase 6, driver.rkt:2831); `:108` calls 2-arg `(prop-net-hot '() fuel)` against the 1-field struct (fuel retired by D.4 1C-iv-b). Reviving it = re-shaping against the hot/warm/cold + fuel-cell migration FIRST.
- **Revival hazards**: preserving warm cells while resetting `next-prop-id→0` leaves stale per-cell dependents champs keyed by colliding prop-ids (propagator.rkt:291/298); the template also clears `pair-decomps` (:114-115) — wiping install-dedup state any preserved propagators rely on. Universe + infra cell-ids are re-populated per reset (metavar-store.rkt:2873-2918) — surviving propagators installed against prior cell-ids dangle; **cell-id stability across commands is an unstated prerequisite**.
- **δ-ification facts** (for when general-body δs return): fire-once lock-in is conditional on PRODUCED OUTPUT (propagator.rkt:3386-3393; equal?-diff over declared outputs :2871-2878; wake on ANY path :1746-1750) → an N-input all-or-nothing fire-once IS an all-ready gate (no set-latch needed at N=2-3; adjudicate vs propagator-design.md at scale). Hazards: partial write permanently locks; equal?-write does not lock (redefinition). Dedup keys must be RAW directional cons `(referrer-cid . referent-cid)` — `decomp-key` canonicalizes and would collapse the mutual a→b/b→a pair (propagator.rkt:4208-4212); `net-pair-decomp?`/`insert` accept raw keys on any network incl. NET-1.
- **Component-paths contract carries**: `'definition-entry` is `#:classification 'structural` (phase1d-registrations.rkt:300-303; wiring infra-cell-sre-registrations.rkt:47); every δ input needs its `(cons cid path)` entry (propagator.rkt:1411-1431).

### §10.4 What retires when (iii) lands

The 4B.5 sweep machinery (groundness passes + SCC pass + assumption-env), the A1 `current-residuation-enabled?` gates (both sites), the demand trigger, the general-body placeholder, the def-group guard — all named scaffolding in §18.21.25 with this section as the retirement target. The DEF-vs-USE residual boundary (uses of textually-later defs) dissolves under the whole-file fixpoint.


---

## §11 Relational goals must residuate too — Rel T1 POL.9 Q_D slice 2 (design capture, 2026-07-25, owner-directed)

**Filed here rather than against Rel T2** because this is not a fact-store
concern: it is the *same* forward-reference-residuation problem this track
owns, arriving from a second namespace. Owner call at Rel T1 X.close.

### §11.1 What Rel T1 delivered, and which half is missing

POL.9 made a paren group in command position a GOAL carrying an implicit
`solve` (`(reach a b)` ≡ `solve (reach a b)`). Its **load-bearing argument was
free-ordering**, and it is worth restating because it is this track's argument:

> Free ordering REQUIRES syntactic **category**-decidability. Under the
> rejected registry-lookup design, `foo a b`'s CATEGORY (application vs query)
> would pend on name resolution — un-typeable, un-composable, retroactively
> re-categorized. Under parens the category is **static**, so only the
> **BINDING** residuates.

That is precisely the shape 12B wants: a *static* category with a *residuating*
binding. POL.9 built the enabling property. **Q_D slice 2 — the part that
exercises it — was designed and not built:**

| Slice | What | Status |
|---|---|---|
| 1 | Unknown relation → honest error via the POL.4 `exn:prologos-solve` presentation | ✅ shipped (`ddf29351`) |
| 2 | A goal over a **later-defined** relation **residuates** and retries when the `defr` lands | ⬜ **here** |

### §11.2 Why it is NOT the "fast-follow" the Rel T1 design called it (grounded)

The Rel T1 design said slice 2 would "wire goals into the EXISTING demand-
residuation loop." **The code says otherwise**, and the mis-sizing is the
finding:

- `residuation-demand-name` (`driver.rkt:1416`) keys on **fvar names** that are
  `'pending` in the global env or present in the general residue. That is `def`
  machinery.
- A `defr` writes the global env *and* the relation store (driver.rkt — env
  write precedes the store write and the registration gates). A **not-yet-seen**
  `defr` name is `'absent`, not `'pending` — nothing pre-allocates a def-bot
  cell for a relation that has not been read yet.
- So the demand trigger cannot fire for `(reach a b)` before `defr reach`
  exists. Slice 2 needs either a pre-scan that marks later `defr` names pending,
  or an end-of-file retry — i.e. **new machinery for a second namespace**, not a
  wiring change.

### §11.3 Why it belongs to 12B specifically

It is the **exact sibling of §7 open question 3** (multi-defn-registry-on-
network: "bring `current-multi-defn-registry` on-network (PM 12) + ground the
base name so a forward-ref residuates"). Three registries, one shape:

| Registry | On-network? | Forward-ref residuates? |
|---|---|---|
| def/global env | ✅ (PPN 4C 4A/4B) | ✅ NET-1 δ |
| `current-multi-defn-registry` | ⬜ PM 12 | ⬜ §7 Q3 |
| `current-relation-store` | ⬜ PM 12 | ⬜ **§11 (this)** |

The dependency chain is 12B's canonical one: **PM 12 brings the relation store
on-network → 12B makes a goal over a bot relation-cell residuate to fixpoint.**
You cannot do the residuation without the cell, which is §2's whole argument for
why 12B is separate from 12.

### §11.4 Two adjacent Rel T1 items that resolve here

1. **POL.9c's ungated 4th direction.** The Q_B disjointness gate cannot gate
   `defr`-over-a-prior-**multi-arity-defn**, because the multi-defn registry
   carries **no module provenance** — gating would break prelude-name shadowing
   (the `xor`/`singleton` precedent). Registry-on-network (PM 12) gives it
   provenance; then the 4th direction gates with the same local-only rule.
2. **`current-relation-store` is threaded into neither `test-support.rkt` nor
   `batch-worker.rkt`** (grep = 0 in each) ⇒ `solve` types as untyped, silently,
   in those contexts. This is the **7th** instance of the two-context class that
   `pipeline.md § New Racket Parameter` exists to prevent — and PPN 4C already
   ruled that codification has FAILED and demanded the architectural answer.
   Migrating the store to a cell removes the parameter, so the class cannot
   recur for it.

### §11.5 Acceptance / parity gate (for the eventual Stage 1–3)

```prologos
;; The whole point: this file must work in EITHER order.
(reach "a" c)          ;; forward reference — currently "Unknown relation"
defr reach [?x ?z]
  &> edge x z
```

- Slice-2 done ⇔ the goal above returns the same rows as the reordered file.
- Parity gate (à la 4A.c-iii-b's writer-census): every path that today raises
  the POL.4 unknown-relation error must be shown to reach it ONLY for names no
  `defr` in the file defines — i.e. residuation covers what the error covered.
- Watch: `raise-unknown-relation-error` (relations.rkt) now classifies heads
  against the global env for its diagnostics. Under residuation the "unknown"
  branch must not fire before the fixpoint settles, or the diagnostic becomes
  order-dependent — the exact regression this track exists to remove.

### §11.6 Interim state (honest)

Rel T1's POL row is marked ✅ for POL.9 (9a+9b+9c). Slice 2 is **not** in it;
the row has been annotated rather than left over-claiming. Nothing in the corpus
forward-references a relation today, so this is a capability gap, not a live
defect.

**Cross-reference**: Rel T1 design §8 POL.9 (Q_D); Rel T1 PIR
[`2026-07-25_REL_T1_PIR.md`](2026-07-25_REL_T1_PIR.md) §12 action item 11;
DEFERRED.md § "Rel T1 POL.9 Q_D slice 2".
