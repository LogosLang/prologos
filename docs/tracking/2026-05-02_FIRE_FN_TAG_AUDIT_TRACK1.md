# Fire-Fn Tag Audit (SH Track 1, audit phase)

**Date**: 2026-05-02
**Status**: Audit — categorization, no broad tagging
**Track**: SH Track 1 (`.pnet` network-as-value), audit phase
**Branch**: `claude/prologos-layering-architecture-Pn8M9`
**Cross-references**:
- [SH Master Tracker](2026-04-30_SH_MASTER.md) — Track 1
- [SH Series Alignment Delta](2026-05-02_SH_SERIES_ALIGNMENT.md) — §5 names this audit as the next Track 1 sub-piece
- Fire-fn-tag field commit: `b0227cb` (added `fire-fn-tag` field with default `'untagged`)
- Test fix-up: `85f5ecd` (3 direct ctor calls in test-source-loc-infrastructure.rkt)

## 1. Purpose

The `fire-fn-tag` field on `propagator` (commit `b0227cb`) defaults to `'untagged` for back-compat. This audit categorizes the ~200 production `net-add-propagator` / `net-add-fire-once-propagator` / `net-add-broadcast-propagator` call sites and identifies which ones will need explicit tags for `.pnet` network-topology serialization to be meaningful.

**Key insight discovered during the audit**: the vast majority of fire-fns in the codebase are **compile-time-only** — they drive elaboration, typing, narrowing, and decomposition. They fire during `process-file`, write to typing cells, and the result is read back as typed AST. They never run in a deployed program.

For `.pnet` deployment artifacts (mode `'program`, per the format-2 wrapper), only **runtime-relevant** fire-fns need stable tags. That set is much smaller than 200.

## 2. Call-site distribution by file

Total `net-add-*` invocations in production code (excluding tests):

| File | Count | Compile-time / Runtime / Both |
|---|---|---|
| `typing-propagators.rkt` | 44 | Compile-time (typing rules) |
| `elaborator-network.rkt` | 40 | Compile-time (elaboration infra) |
| `propagator.rkt` | 22 | Substrate (the wrappers themselves) |
| `relations.rkt` | 10 | Both (compile-time tabling + runtime solve) |
| `session-propagators.rkt` | 8 | Compile-time (session typing) |
| `sre-core.rkt` | 7 | Compile-time (SRE structural reasoning) |
| `session-runtime.rkt` | 6 | **Runtime** (session protocol execution) |
| `constraint-propagators.rkt` | 6 | Compile-time (constraint solving during typing) |
| `wf-propagators.rkt` | 5 | Compile-time (well-foundedness checks) |
| `unify.rkt` | 5 | Compile-time (PUnify) |
| `elab-network-types.rkt` | 4 | Compile-time |
| `narrowing.rkt` | 2 | Compile-time |
| `merge-fn-registry.rkt` | 2 | Compile-time (registry) |
| `driver.rkt` | 2 | Compile-time |
| `sre-rewrite.rkt` | 1 | Compile-time (DPO rewriting) |
| `effect-bridge.rkt` | 1 | Both (effect ordering checks compile-time, execution runtime) |
| `effect-ordering.rkt` | 1 | Compile-time |
| `effect-executor.rkt` | 1 | **Runtime** (effect execution) |
| `cap-type-bridge.rkt` | 1 | Compile-time |
| `capability-inference.rkt` | 1 | Compile-time |
| `bilattice.rkt` | 1 | Substrate |
| `infra-cell-sre-registrations.rkt` | 1 | Substrate (domain registrations) |
| `metavar-store.rkt` | 1 | Compile-time |
| `performance-counters.rkt` | 1 | Compile-time |
| **Total** | **~170** | (some files have multiple categories) |

(Counts via `grep -cE` per file; rough.)

## 3. Categorization framework

Three categories based on whether the propagator participates in deployment:

### A. Compile-time-only propagators (the majority)

Fire-fns that drive elaboration, typing, decomposition, constraint solving, narrowing, etc. They run inside `process-file`'s elaboration network, produce a typed AST, then stop being relevant. The compiled program (Track 4 output) does not load these propagators — they served their purpose at compile time.

**Tag policy**: leave at `'untagged`. They never appear in a `'program` mode `.pnet` because they're not in the runtime sub-graph.

Examples: `typing-propagators.rkt`, `elaborator-network.rkt`, `unify.rkt`, `narrowing.rkt`, `constraint-propagators.rkt`, `sre-core.rkt`, `metavar-store.rkt`.

### B. Runtime propagators (the small but load-bearing set)

Fire-fns that DO run at deployment. They appear in the runtime sub-graph of compiled programs. Need stable tags so the `.pnet` loader can resolve them against the runtime kernel.

**Tag policy**: explicit, stable, kernel-resolvable. Naming convention `'rt-<category>-<name>`, e.g., `'rt-int-add`, `'rt-merge-set-union`, `'rt-session-send`.

Examples: `session-runtime.rkt` (session protocol execution), `effect-executor.rkt` (effect execution), `relations.rkt`'s solve-time propagators.

### C. Substrate propagators (built into the kernel itself)

Fire-fns that ARE the kernel. Lattice merges, structural decomposers, broadcast-fan, fire-once flags. The kernel provides them; user `.pnet` files reference them by tag.

**Tag policy**: explicit, stable, kernel-defined. Naming convention `'kernel-<name>`, e.g., `'kernel-merge-set-union`, `'kernel-bsp-round`, `'kernel-broadcast-fan`.

Examples: `propagator.rkt` (the wrappers themselves), `infra-cell-sre-registrations.rkt`, `bilattice.rkt`, `merge-fn-registry.rkt`.

## 4. Concrete runtime-relevant fire-fns identified

The following are the call sites that MUST get stable tags for deployment:

| Site | Category | Proposed tag |
|---|---|---|
| `session-runtime.rkt` × 6 sites | B | `'rt-session-send`, `'rt-session-recv`, `'rt-session-select-l`, `'rt-session-select-r`, `'rt-session-offer`, `'rt-session-close` |
| `effect-executor.rkt` × 1 site | B | `'rt-effect-execute` |
| `relations.rkt` solve-time propagators (subset of 10) | B | `'rt-relation-clause-N` (per-clause, generated at registration time) |

That's roughly **10–20 distinct runtime fire-fns**. Far below 200.

For the substrate kernel (category C), the count is similar:
| Substrate fn | Tag |
|---|---|
| Set union merge | `'kernel-merge-set-union` |
| Hash union merge | `'kernel-merge-hash-union` |
| Top-bot lattice merge | `'kernel-merge-tagged-cell-value` |
| Component-tagged compound merge | `'kernel-compound-tagged-merge` |
| Broadcast fan | `'kernel-broadcast-fan` |
| Fire-once flag-guard | `'kernel-fire-once-guard` |
| Threshold check | `'kernel-threshold-fire` |
| Cross-domain α | `'kernel-cross-domain-alpha` |
| Cross-domain γ | `'kernel-cross-domain-gamma` |

~10 substrate primitives. Together with the runtime set, **the total fire-fn-tag namespace is ~20–30 stable tags**, not 200.

## 5. Why not tag everything

I considered mass-tagging all 200 call sites and rejected it for these reasons:

1. **Compile-time fire-fns don't need tags.** They never appear in deployment artifacts. Tagging them is busywork that adds complexity without value.

2. **Auto-generated tags are fine for unique call sites.** The `'untagged` default is acceptable as long as any future serialization (Track 1's network-topology phase) refuses to serialize `'untagged` propagators in `'program` mode. This makes the missing-tag case loud rather than silent.

3. **Stable tags for the small runtime set is what matters.** ~20–30 named tags that the runtime kernel and per-program `.o` files agree on is a manageable convention. Naming 200 ad-hoc tags would dilute the namespace.

4. **The audit framework + naming convention IS the deliverable.** Once we've categorized which sites are compile-time vs runtime vs substrate, future track work can apply tags incrementally and consistently.

## 6. Naming convention (proposed)

For tags emitted by code in this codebase:

| Prefix | Meaning |
|---|---|
| `'kernel-*` | Built into `libprologos-runtime` (the Zig kernel). Lattice merges, scheduler primitives. |
| `'rt-*` | Runtime fire-fns shipped with the user program's `.o`. Generated by the per-program lowering pass; tag includes the user program's hash for uniqueness. |
| `'cT-*` | Compile-time fire-fns. By default, these stay `'untagged`. The prefix is reserved for cases where compile-time fire-fns need to round-trip through `.pnet` for module-cache purposes (which is the existing format-1 path; the cache today doesn't use tags). |
| `'untagged` | Default. Acceptable for compile-time fire-fns. Refused at deployment-mode serialization. |

## 7. What this audit doesn't do

- **Does not tag any call sites.** The fire-fn-tag field is in place; the default `'untagged` works fine. Future Track 1 phases will tag call sites *as the deployment-mode serializer requires them*. Tagging in advance commits us to a naming scheme prematurely.

- **Does not change runtime behavior.** Pure documentation + categorization. The kernel still works as before.

- **Does not write the deployment-mode `.pnet` serializer.** That's a future Track 1 phase that consumes this audit's output to know which call sites need attention.

## 8. Forward path

This audit feeds three downstream pieces of work:

1. **Track 1 deployment-mode serialization (future phase)**: when serializing a `.pnet` in `'program` mode, refuse to serialize `'untagged` propagators. Error message: "fire-fn at <srcloc> has no tag; cannot serialize for deployment. See fire-fn tag audit doc § 4."

2. **Per-program lowering pass (Track 2 / Track 4)**: when lowering a user program's runtime sub-graph, generate `'rt-<program-hash>-<index>` tags for each user fire-fn body. Emit them as exported symbols in the per-program `.o`.

3. **Kernel API design (Track 4)**: the runtime kernel's API includes a tag-resolution table mapping `'kernel-*` symbols to function pointers. This audit identifies the ~10 entries that table needs.

## 9. Cross-references

- SH Master Tracker, Track 1
- Fire-fn-tag struct field: commit `b0227cb`
- `.pnet` format-2 wrapper: commit `65312be` — provides the mode flag (`'module` vs `'program`) that determines whether `'untagged` is acceptable
- Low-PNet IR data model: `propagator-decl` carries `fire-fn-tag` — Track 2 implementation (commit `f4157be`)
- Issue #44 (PReductions output contract) — once PReductions registers its propagators with stable tags, those tags slot into the `'kernel-*` namespace
