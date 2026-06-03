# PM Track 12 Implementation Note — `spec`/`defn` Name-Level Free-Ordering On-Network

**Created**: 2026-06-03
**Status**: Design input for PM Track 12 (not yet scheduled). Captured ahead of implementation.
**Origin**: Surfaced during **PPN 4C Addendum Phase 4B** Q-4B.1/Q-4B.4 grounding (two `grounding-audit` workflows + main-session R-lens, HEAD `71aaf69b`, 2026-06-03). Persisted to PPN 4C addendum design `2026-04-21_PPN_4C_PHASE_9_DESIGN.md` §18.21.11–§18.21.12.
**Linked from**: PM Series Master `2026-03-13_PROPAGATOR_MIGRATION_MASTER.md` § Track 12.

---

## §1 The consideration (one paragraph)

The free-ordering thesis ("ordering emerges from dataflow, no imperative passes") has **two layers**: **value/reference-level** (a reference residuates on a name's cell — PPN 4C Addendum Phase 4B's job) and **name-level** (declarations pre-register so any form can reference any other regardless of source order — today realized **imperatively** by the FREE_ORDERING multi-pass preparse). PPN 4C Addendum Phase 4B brings the value/reference level on-network. The **name-level** for the `spec`/`defn` case — making the `spec` form write the per-name `def-entry` `:type` cell on-network so a forward/mutual reference to a spec'd-but-not-yet-defn'd name resolves *structurally* (cell residuation) rather than via the imperative preparse name-pass — was **evaluated for inclusion in 4B and deferred** to PM Track 12 / module-loading-on-network. This note captures *why* and the *grounded pickup facts* so PM 12 can act on it cold.

This is the PPN Track 3 design item that was **designed but never built**: *"Defn production propagators read spec cells — if ⊥, the defn residuates until the spec is written. This eliminates the two-pass ordering in preparse-expand-all. Ordering emerges from cell dependency, not control flow."* (`2026-04-01_PPN_TRACK3_DESIGN.md` ~line 156.) Realizing it is name-level free-ordering on-network.

## §2 Why deferred from PPN 4C Addendum Phase 4B (4 entanglements)

4B's scope is value/reference-level residuation on the already-on-network `def-entry` cell (4A put it there). Making `spec` *write* that cell on-network is **not a clean 4B slice** — the grounding found four entanglements that make it module-loading-on-network / PM-12 territory:

1. **No elaboration-time hook → net-new pipeline surface, not a relocation.** `spec` is **consumed at preparse**: no `surf-spec` struct exists anywhere (`surface-syntax.rkt`/`parser.rkt`/`tree-parser.rkt`/`elaborator.rkt`), and the tree-parser **hard-errors** on any spec reaching it (`tree-parser.rkt:590` `(parse-error-result loc "spec: consumed by preparse")`). `process-command` (`driver.rkt:451`) has no `spec` arm. So making `spec` write the cell at elaboration time requires **creating a `surf-spec` node through the whole AST pipeline** (surface-syntax → parser → tree-parser → elaborator → a `process-command` arm) — an *addition*, not a move.

2. **The spec-store cannot collapse into the `def-entry` `:type` cell.** `spec-entry` (`macros.rkt:469`) carries **8 fields** `(type-datums docstring multi? srcloc where-constraints implicit-binders rest-type metadata)`; the `def-entry` cell holds only `(type × value)`. ≥5 **elaboration-time** readers consume the non-type fields: `elaborator.rkt:377-401` (`where-constraints` + `implicit-binders` → trait-constraint implicit-arg insertion), `elaborator.rkt:577` (`where-constraints` n-constraints), `elaborator.rkt:652` (`rest-type` → varargs), `typing-core.rkt:411` (`metadata` `:deprecated`), plus `macros.rkt:9466` `lookup-spec-type-for-patterns` (multi-arity pattern defns, elaboration-time). The spec-store **must persist** regardless; only the *type-injection role* is migratable.

3. **Two-network crossing.** The spec-store cell is on the **persistent-registry network** (NET-2; `current-spec-store-cell-id`, written via `macros-cell-write!` → `current-persistent-registry-net-box`, `macros.rkt:566`). The `def-entry` cell is on the **per-file `module-network-ref` prop-net** (NET-1; `namespace.rkt:191`/`:228`). A "spec writes the def-entry cell" design crosses two distinct networks (the same NET-1↔NET-2 boundary 4B faces, now inside the spec mechanism). See the NTT cross-network bridge gap (`2026-03-22_NTT_SYNTAX_DESIGN.md` §17b) — the architecturally-correct future primitive for cross-network reactive access.

4. **`maybe-inject-spec` is a validation site, not just a type-write.** The live spec→defn type injection is `maybe-inject-spec` (`macros.rkt:4058`, 15 call sites; **not** `annotate-surfs-with-specs` at `form-cells.rkt:353`, which is **dead code — zero callers**). It runs at preparse, makes spec-type ≡ defn-type **by construction** (injects the spec type *into* the defn surf), AND **errors loudly** on spec/defn arity-mismatch + double-annotation (`macros.rkt:4079`/`:4081`/`:4091`) and skips pattern-clause defns (`:4073`). The `def-entry` `:type` merge is **LWW new-wins, NOT unify** (`definition-entry.rkt:96`; `type-unify-or-top` is kept-but-unreachable, `:65-71`). So a *separate* spec write would (a) lose the by-construction spec-type ≡ defn-type equality → **silent type drift** unless the defn write happens-after or `type-unify-or-top` is restored, and (b) **drop the loud preparse consistency errors** unless the validation is separately relocated.

## §3 The good news — NOT entangled with the rest of FREE_ORDERING / the ~18 PM-12 registries

The `spec` write surface is **isolated to `spec-store`** (+ an optional, orthogonal `:mixfix`→operator-precedence write via `register-user-operator!`, `macros.rkt:7959`). `process-spec` (`macros.rkt:3335-3535`) writes **only** `register-spec!` (`macros.rkt:479-482` → `current-spec-store` param + the spec-store cell) and the gated mixfix write. It *reads* the trait/bundle registries (`expand-bundle-constraints`, `extract-inline-constraints` via `lookup-trait`) **read-only** — no write-ordering coupling. It touches **none** of the data/trait/impl/ctor/bundle/property name-registration machinery (the ~18 registry parameters listed in PPN 4C addendum §18.5; full set enumerated at `macros.rkt:534-559`). So the spec/defn name-ordering slice is a **sibling concern** to PM 12's registry-parameter migration, not a dependency on it — they can be designed together but the spec slice doesn't *require* the registry migration first.

## §4 What PM Track 12 should design (the pickup)

Realize name-level free-ordering for the `spec`/`defn` case on-network. Concretely:
- **Make `spec` a first-class on-network entity** — either a `surf-spec` node carried through the AST pipeline to an elaboration-time `process-command` arm, OR an elaboration-time spec-processing step — so it can write at a network-bound point (the mnr is bound). (This is the net-new pipeline surface from §2.1.)
- **Keep the spec-store** (on-network already, dual-written) for the rich `spec-entry` fields the elaboration-time consumers need (§2.2); the slice migrates only the **type-injection role** to a cell write.
- **Bridge or unify NET-1/NET-2** (§2.3) — the spec-store (NET-2) and `def-entry` (NET-1) split. Coordinate with **PM Track 13** (mnr↔elab-network unification — the "firing-PU-as-cell-value" concern) and the NTT §17b cross-network-bridge primitive. If the networks unify (PM 13), the crossing dissolves.
- **Preserve `maybe-inject-spec`'s validation** (§2.4) — the arity/double-annotation consistency checks must not be dropped when the type-flow moves to a cell; either keep them at the spec step or restore `type-unify-or-top` on the `:type` sub-cell so the merge catches spec/defn type mismatch instead of silently new-wins-ing.
- **Retire the FREE_ORDERING name-pass for the spec/defn slice** once the above lands — `maybe-inject-spec` (the preparse datum-rewrite) + the Pass-1/Pass-2 ordering become redundant for `spec`→`defn`; the heavier name-registration (data/trait/impl/bundle/property/functor) stays on preparse until its own migration.

## §5 What PPN 4C Addendum Phase 4B does instead (so the boundary is clear)

4B does **not** touch `spec` or FREE_ORDERING. It routes forward/mutual references through residuation on the `def-entry` cell that the **defn handler already writes** (`driver.rkt:1185` `global-env-add-type-only` / `:1150` `global-env-add`, on NET-1, put on-network by 4A). A forward reference residuates on the referent's `def-entry` cell until the referent's **defn** runs and writes it. The `spec` mechanism stays exactly as-is (preparse name-pre-registration + `maybe-inject-spec` injection). The only thing the deferred spec→cell slice would *add* is resolving a spec'd forward-ref's type *earlier* (from the spec, before its defn runs) — a latency optimization, not a correctness need — which is precisely PM 12's name-level-free-ordering work, not 4B's value-level work.

## §6 Cross-references

- **PPN 4C Addendum Phase 4B** mini-design + grounding: `2026-04-21_PPN_4C_PHASE_9_DESIGN.md` §18.21.11 (Q-4B.4 topology-stratum + cross-network reframe) + §18.21.12 (separability grounding + scope decision).
- **PPN Track 3** spec-cell-residuation design item (designed, never built): `2026-04-01_PPN_TRACK3_DESIGN.md` ~line 156.
- **FREE_ORDERING** (the imperative name-pass this slice migrates): `2026-02-28_1800_FREE_ORDERING.md`; PPN 4C addendum §18.5 + §18.10.4 (name-level vs value-level distinction + the module-loading-on-network deferral).
- **PM Track 13** (mnr↔elab unification — the network-unification that would dissolve the NET-1/NET-2 crossing): `2026-05-20_PM_TRACK13_IMPLEMENTATION_NOTE.md`.
- **NTT §17b** cross-network bridge form (the cross-network primitive if networks are NOT unified): `2026-03-22_NTT_SYNTAX_DESIGN.md` §17b.
- **Grounding workflows**: `wf_84f2a3a6-392`, `wf_7e3933f9-e74` (Q-4B.4), `wf_f27f8b33-fb1` (this separability audit).
- **Key code coordinates @ `71aaf69b`**: `macros.rkt:2366-2460` (preparse 4-pass), `:3335-3535` (process-spec), `:479-482` (register-spec!), `:4058-4104` (maybe-inject-spec, the live injection + validation), `:469` (spec-entry 8 fields); `tree-parser.rkt:590` (spec-consumed-by-preparse hard guard); `form-cells.rkt:353` (annotate-surfs-with-specs — DEAD); `definition-entry.rkt:96`/`:65-71` (def-entry-type LWW new-wins, unify kept-but-unreachable); `global-env.rkt:192-193` (global-env-add-type-only → mnr def-entry cell); `namespace.rkt:191`/`:228` (def-entry cell on the mnr prop-net); `macros.rkt:566` (spec-store on the persistent-registry net); elaboration-time spec-entry consumers `elaborator.rkt:377-401`/`:577`/`:652`, `typing-core.rkt:411`, `macros.rkt:9466`.
