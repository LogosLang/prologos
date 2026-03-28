# PAR Track 1 Stage 2 Audit: Stratified Topology

**Date**: 2026-03-27
**Purpose**: Precise call-site inventory for the two CALM violators identified in PAR Track 0 audit. This is the data that PAR Track 1's Stage 3 design document builds against.
**Prerequisite**: [PAR Track 0 CALM Audit](2026-03-27_PAR_TRACK0_CALM_AUDIT.md)

---

## Violator 1: sre-core.rkt — Structural Decomposition

### Call Graph (fire function → topology)

```
Fire function closures (3 entry points):
  sre-make-equality-propagator    (line 528) → lambda at line 532
  sre-make-subtype-propagator     (line 570) → lambda at line 575
  sre-make-duality-propagator     (line 622) → lambda at line 630

All three call:
  → sre-maybe-decompose           (line 456)
    → sre-decompose-generic       (line 384)    [binder-depth=0 path]
    OR → net (unchanged)                         [binder-depth>0 + requires-binder-opening]
    OR → sre-decompose-generic                   [binder-depth>0 + ground relation]

sre-decompose-generic (line 384):
  → sre-get-or-create-sub-cells   (line 307)  × 2 (cell-a, cell-b)
    → sre-identify-sub-cell       (line 274)  × N (one per component)
      → net-new-cell              (lines 288, 291, 294)  ← TOPOLOGY
  → net-add-propagator            (lines 423-427)  × N (sub-relate propagators)
  → net-add-propagator            (lines 431-433)  × 1 (reconstructor for cell-a)
  → net-add-propagator            (lines 434-436)  × 1 (reconstructor for cell-b)
  → net-pair-decomp-insert        (line 438)       × 1 (registry: pair decomposed)
  → net-cell-decomp-insert        (line 322)       × 2 (registry: cell decomposed)
```

### Exact Topology Call Counts Per Decomposition

For a compound type with arity N (e.g., PVec has N=1, Map has N=2, Pi has N=2):

| Operation | Count | Signature |
|-----------|-------|-----------|
| `net-new-cell` | up to 2×N | `(net initial-value merge-fn contradicts?) → (values net cell-id)` |
| `net-add-propagator` (sub-relate) | N | `(net (list sa sb) (list sa sb) fire-fn) → (values net pid)` |
| `net-add-propagator` (reconstructor-a) | 1 | `(net subs-a (list cell-a) fire-fn) → (values net pid)` |
| `net-add-propagator` (reconstructor-b) | 1 | `(net subs-b (list cell-b) fire-fn) → (values net pid)` |
| `net-cell-decomp-insert` | 2 | `(net cell-id tag sub-ids) → net` |
| `net-pair-decomp-insert` | 1 | `(net pair-key) → net` |
| **Total topology ops** | **2N + N + 2 + 3 = 3N + 5** | |

For PVec (N=1): 8 topology operations per decomposition.
For Map (N=2): 11 topology operations.
For Pi (N=2): 11 topology operations.

### Guard: `net-pair-decomp?` Prevents Redundant Decomposition

`sre-maybe-decompose` (line 467) checks `(net-pair-decomp? net pair-key)` before calling `sre-decompose-generic`. This means each (cell-a, cell-b, relation) triple is decomposed at most once. The guard is a network lookup, not a fire-function-local cache — it persists across firings.

**Implication for stratified topology**: The decomposition-request protocol can use the same guard. If a request has already been processed (pair is in decomp registry), skip it.

### Data Flow: What the Fire Function Needs After Decomposition

The fire function creates sub-cells and sub-propagators, then **returns the modified network**. It does NOT read from the sub-cells in the same firing. The sub-cells are populated in subsequent firings when:
1. Reconstructors fire (sub-cells → parent cell)
2. Sub-relate propagators fire (sub-cell-a ↔ sub-cell-b)

**Critical insight**: The fire function's return value is the network with topology changes. It does NOT depend on sub-cell values. The topology creation and value propagation are independent — this confirms the two-fixpoint architecture is clean.

### sre-identify-sub-cell Branches (line 274)

| Branch | Condition | Action | Creates Cell? |
|--------|-----------|--------|---------------|
| Meta/var with cell mapping | `recognizer(expr)` + `resolver(expr)` returns cid | Reuse existing cell | **No** |
| Meta/var without mapping | `recognizer(expr)` but no cid | `net-new-cell bot` | **Yes** |
| Bot value | `bot?(expr)` | `net-new-cell bot` | **Yes** |
| Concrete value | else | `net-new-cell expr` | **Yes** |

In practice, during elaboration the meta path reuses cells (no topology). During ground-type checking (subtype, duality), the concrete path creates cells. The bot path creates cells when one side hasn't been decomposed yet.

### Duality-Specific Decomposition (line 622+)

`sre-make-duality-propagator` has an additional decomposition path at `sre-duality-decompose-dual-pair` (line ~700+). This creates topology via the same `sre-get-or-create-sub-cells` + `net-add-propagator` path but with dual constructors (different tags on each side). Same call signatures, same count formula.

---

## Violator 2: narrowing.rkt — Narrowing Propagator Installation

### Call Graph (fire function → topology)

```
Fire function closures (2 entry points):
  make-branch-fire-fn  (line 228) → lambda at line 230
  make-rule-fire-fn    (line 275) → lambda at line 276

make-branch-fire-fn lambda:
  → install-narrowing-propagators  (line 246)  [recursive!]
    → net-add-propagator           (line 168-169)  × 1 (branch propagator)
    → net-add-propagator           (line 187-188)  × 1 (rule propagator)
    → install-narrowing-propagators (line 204)  × K (recursive for dt-or)

make-rule-fire-fn lambda:
  → eval-rhs                       (line 286)
    → net-new-cell                 (line 323)  × M (suc sub-terms)
    → net-new-cell                 (line 338)  × M (app arg-terms)
    → nat->term                    (line 328)
      → net-new-cell              (line ~415)  × M (nat literal sub-cells)
    → expr->ctor-sub-cells        (line 341)
      → net-new-cell              (line 386)  × M (curried ctor args)
```

### Exact Topology Call Counts

Branch fire function (per constructor match):
| Operation | Count | Notes |
|-----------|-------|-------|
| `net-add-propagator` | 1-2 per child | Recursive — one branch or rule propagator per child subtree |
| Recursive `install-narrowing-propagators` | Depth of definitional tree | Can install entire subtree of propagators |

Rule fire function (per rule evaluation):
| Operation | Count | Notes |
|-----------|-------|-------|
| `net-new-cell` | 0-M | One per constructor sub-term in the RHS. M = number of constructor args in RHS expression. |

### Data Flow: What the Fire Function Needs After Topology

**Branch**: After installing child propagators, the fire function returns the modified network. The child propagators will fire in subsequent rounds. The branch fire function does NOT read results from children — it merely installs them.

**Rule**: After creating sub-cells for constructor terms, the fire function builds a `term-ctor` value referencing those cell-ids and writes it to the result cell. **Unlike SRE, the rule fire function DOES use the created cell-ids immediately** — the `term-ctor` value contains references to the freshly created cells.

**Critical difference from SRE**: In SRE, the fire function creates topology and returns without reading from it. In narrowing, the rule fire function creates cells AND builds values referencing them. This means the stratification is slightly different — the cell creation and the value that references it must be atomic from the fire function's perspective.

### nat->term Helper (line ~410)

```racket
(define (nat->term n net)
  (if (zero? n)
      (values net (term-ctor 'zero '()))
      (let-values ([(net1 sub-cid) (net-new-cell net (term-ctor 'zero '()) term-merge term-contradiction?)])
        (let loop ([i 1] [net net1] [inner-cid sub-cid])
          (if (>= i n)
              (values net (term-ctor 'suc (list inner-cid)))
              (let-values ([(net2 new-cid) (net-new-cell net (term-ctor 'suc (list inner-cid)) term-merge term-contradiction?)])
                (loop (+ i 1) net2 new-cid)))))))
```

For `nat->term N net`: creates N cells (one per suc layer). Returns the network with cells and a `term-ctor` referencing them.

---

## Violator 3 (Latent): constraint-propagators.rkt — install-fn Callback

### Call Site

```racket
;; line 266
(define (install-constraint->method-propagator net constraint-cell install-fn)
  (net-add-propagator net
   (list constraint-cell) '()
   (lambda (n)
     (define cv (net-cell-read n constraint-cell))
     (if (constraint-one? cv)
         (install-fn n (constraint-one-candidate cv))  ;; ← callback
         n))))
```

**Currently unused** — exported but no callers found in the codebase.

**Contract needed**: `install-fn : (net × candidate → net)` must be value-only (cell writes). If it calls `net-add-propagator` or `net-new-cell`, it becomes a CALM violator.

---

## Network Registry Operations (Non-Cell/Propagator Topology)

Three registry operations are called from within fire functions:

| Function | File:Line | What It Modifies | CALM Impact |
|----------|-----------|------------------|-------------|
| `net-cell-decomp-insert` | propagator.rkt:1604 | `warm.cell-decomps` CHAMP | Metadata, not cell/propagator. But BSP diff drops it. |
| `net-pair-decomp-insert` | propagator.rkt:1618 | `warm.pair-decomps` CHAMP | Same — metadata lost under BSP. |
| `net-cell-decomp-lookup` | propagator.rkt:1598 | Read-only | Safe. |
| `net-pair-decomp?` | propagator.rkt:1613 | Read-only | Safe. |

**Impact**: Even if we only address `net-new-cell` and `net-add-propagator`, the decomp registry writes would also be lost under BSP. They must be part of the stratified topology protocol — either emitted as requests or moved to the topology stratum.

---

## Summary: What PAR Track 1 Must Build

### Scope

| Module | Topology Ops to Stratify | Lines Affected |
|--------|-------------------------|----------------|
| sre-core.rkt | `net-new-cell` (×2N), `net-add-propagator` (×N+2), decomp registry (×3) | ~50 lines in `sre-decompose-generic` + `sre-get-or-create-sub-cells` |
| narrowing.rkt | `net-add-propagator` (×recursive), `net-new-cell` (×M) | ~30 lines in `install-narrowing-propagators` + `eval-rhs` |
| constraint-propagators.rkt | Contract documentation only | ~5 lines (comment) |
| propagator.rkt | Topology stratum in BSP loop | ~40 lines (new) |

### Data Requirements for the Decomposition-Request Protocol

**SRE decomposition request** must carry:
- `domain`: which SRE domain (type, term, session)
- `cell-a`, `cell-b`: the cells to decompose
- `va`, `vb`, `unified`: current cell values (for component extraction)
- `pair-key`: decomposition guard key
- `desc`: constructor descriptor (for extract, reconstruct, arity)
- `relation`: which relation (equality, subtype, duality)

**Narrowing branch request** must carry:
- `tree`: definitional tree subtree to install
- `arg-cells`, `result-cell`: existing cells
- `bindings`: accumulated pattern variable bindings

**Narrowing rule cell-creation request** must carry:
- `initial-value`: the term value for the new cell
- `merge-fn`, `contradicts?`: cell lattice functions
- Needs to return `cell-id` to the requester (for `term-ctor` referencing)

### The Narrowing Rule Challenge

SRE decomposition is clean for stratification: the fire function creates topology and returns without reading from it. The topology stratum can process requests asynchronously.

Narrowing's `make-rule-fire-fn` is harder: it creates cells AND immediately uses their IDs in the return value (`term-ctor 'suc (list sub-cid)`). The cell creation and the value that references it are coupled.

**Options**:
1. **Pre-allocate cell IDs**: The topology stratum allocates cell IDs in advance and provides them to the fire function. The fire function uses the pre-allocated IDs in its values. The topology stratum creates the actual cells later. Requires a cell-ID reservation mechanism.
2. **Two-phase rule evaluation**: Phase 1 (in fire function): compute which cells are needed, emit requests. Phase 2 (in topology stratum): create cells, re-evaluate to build term with actual IDs. Duplicates work.
3. **Inline cell creation for narrowing only**: Mark narrowing cells as "provisional" — they're value-only cells (no propagators attached) that can be created inline without CALM violation. The CALM issue is about propagators, not cells alone.

Option 3 is interesting: cells without propagators don't affect scheduling order. A cell that exists but has no dependents doesn't trigger any firings. The CALM violation comes from propagators (which change what fires in future rounds), not from cells (which are just storage). If `eval-rhs` creates cells but NOT propagators, it may be CALM-safe.

**Needs verification**: Is creating a cell (without propagators) during a BSP fire round CALM-safe? The cell adds to the topology but doesn't change the propagator worklist. Other propagators can't read a cell they don't know about. The only way it becomes visible is if the cell-id appears in a value written to another cell — but that value is just data, not a scheduling dependency.

---

## Cross-References

- **PAR Track 0 CALM Audit**: [2026-03-27_PAR_TRACK0_CALM_AUDIT.md](2026-03-27_PAR_TRACK0_CALM_AUDIT.md)
- **SRE Track 1 PIR** (introduced the violating code): [2026-03-23_SRE_TRACK1_PIR.md](2026-03-23_SRE_TRACK1_PIR.md)
- **DEVELOPMENT_LESSONS.org** § "CALM Requires Fixed Topology"
- **BSP scheduler**: propagator.rkt lines 1193-1232
- **CALM guard**: propagator.rkt `current-bsp-fire-round?` (commit `af35f5e`)
