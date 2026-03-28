# PAR Track 1: Stratified Topology — BSP-as-Default

**Date**: 2026-03-27
**Series**: PAR (Parallel Scheduling)
**Stage**: 3 (Design Iteration D.1)
**Prerequisites**: PAR Track 0 CALM Audit (✅ `2f3c160`), Stage 2 Audit (`813634a`)

---

## Goal

Make the BSP scheduler the default for `run-to-quiescence`, producing identical results to DFS for all 380 test files. This requires resolving all CALM topology violations identified in the Track 0 audit.

## Deliverables

1. **380/380 green under BSP** — `current-use-bsp-scheduler? #t` with zero test failures
2. **Stratified topology protocol** — decomposition requests as cell values, topology stratum between BSP rounds
3. **CALM guard active** — `current-bsp-fire-round?` enforced in production
4. **Narrowing CALM validation** — empirical confirmation that cell-only creation is CALM-safe (or refactoring if not)

## Non-Deliverables (deferred)

- `:auto` heuristic (PAR Track 3 — needs benchmarking data)
- True parallelism / futures (PAR Track 2 — research)
- Performance improvement (Track 1 is about correctness, not speed)

---

## Architecture: Two-Fixpoint BSP Loop

The current BSP loop is:
```
repeat:
  fire all worklist propagators against snapshot
  bulk-merge writes
until worklist empty
```

The new loop separates value fixpoint from topology fixpoint:
```
repeat:
  VALUE STRATUM (BSP-safe, parallelizable):
    repeat:
      fire all worklist propagators against snapshot
      bulk-merge VALUE writes only
    until worklist empty

  TOPOLOGY STRATUM (sequential):
    read decomposition-request cells
    for each unprocessed request:
      create sub-cells (net-new-cell)
      create sub-propagators (net-add-propagator)
      register in decomp registries
    clear processed requests
    (new propagators are on worklist for next value stratum)

until neither value nor topology changed
```

The outer loop runs until stable — no value changes AND no topology changes. Each inner value stratum runs BSP to quiescence on a fixed topology. The topology stratum processes accumulated requests and may add to the worklist. If it does, the next value stratum fires.

---

## Design: Decomposition-Request Protocol

### Request Cell

A single cell per network: `decomp-request-cell`. Lattice: set-union of request structs. Merge: set-union (monotone under subset ordering). Bot: empty set.

```racket
(struct decomp-request (kind domain cell-a cell-b va vb unified pair-key desc relation) #:transparent)
;; kind: 'sre-structural | 'narrowing-branch | 'narrowing-rule-cells
```

Fire functions write decomposition requests to this cell instead of calling `net-new-cell` / `net-add-propagator` directly.

### Request Emission (replaces inline topology)

**SRE path** — `sre-decompose-generic` becomes `sre-emit-decomposition-request`:
```racket
(define (sre-emit-decomposition-request net domain cell-a cell-b va vb unified pair-key desc
                                         #:relation [relation sre-equality])
  ;; Guard: already decomposed? → skip
  (if (net-pair-decomp? net pair-key)
      net
      ;; Write request to decomp-request cell
      (let ([req (decomp-request 'sre-structural domain cell-a cell-b va vb unified pair-key desc relation)])
        (net-cell-write net (prop-network-decomp-request-cell net) (set-add (set) req)))))
```

**Narrowing branch path** — `make-branch-fire-fn` emits request instead of calling `install-narrowing-propagators`:
```racket
;; Inside the branch fire function lambda:
(let ([req (decomp-request 'narrowing-branch ...)])
  (net-cell-write net (prop-network-decomp-request-cell net) (set-add (set) req)))
```

### Topology Stratum Handler

```racket
(define (process-topology-requests net)
  (define req-cell (prop-network-decomp-request-cell net))
  (define requests (net-cell-read net req-cell))
  (if (or (not requests) (set-empty? requests))
      (values net #f)  ;; no requests → no topology change
      (let ([net* (for/fold ([n net]) ([req (in-set requests)])
                    (match (decomp-request-kind req)
                      ['sre-structural
                       (sre-decompose-generic n (decomp-request-domain req) ...)]
                      ['narrowing-branch
                       (install-narrowing-propagators n ...)]
                      ['narrowing-rule-cells
                       ;; Create cells, return mapping
                       ...]))])
        ;; Clear processed requests
        (values (net-cell-write net* req-cell (set)) #t))))  ;; topology changed
```

### Integration into BSP Loop

```racket
(define (run-to-quiescence-bsp net #:executor [executor sequential-fire-all])
  (let outer-loop ([net net])
    ;; Value stratum: BSP rounds until worklist empty
    (define net-value-stable (run-value-stratum-bsp net executor))
    ;; Topology stratum: process decomposition requests
    (define-values (net-topo-done topology-changed?)
      (process-topology-requests net-value-stable))
    (if topology-changed?
        (outer-loop net-topo-done)  ;; new topology → re-run value stratum
        net-topo-done)))            ;; stable → done
```

---

## Narrowing: Cell-Only Creation CALM Analysis

The Stage 2 audit identified that `make-rule-fire-fn` creates cells (via `eval-rhs` → `net-new-cell`) but NOT propagators. The question: is cell-only creation CALM-safe?

**Argument for CALM-safety**:
- A cell without dependents (no propagator watches it) doesn't affect the worklist
- Other propagators can't read a cell they don't know about (cell-id is local)
- The cell-id appears in a value written to `result-cell`, but that's a value operation, not a topology dependency
- The cell is storage — it holds a value but triggers nothing

**Argument against**:
- The cell exists in the network's `cells` CHAMP — BSP's `fire-and-collect-writes` would not capture it
- If another propagator later adds the cell as a dependent (in a future topology stratum), the cell must exist

**Resolution**: Phase 0 validates empirically. If narrowing tests pass under BSP with the CALM guard relaxed for `net-new-cell` (but NOT `net-add-propagator`), cell-only creation is confirmed CALM-safe. If they fail, narrowing needs the full request protocol.

**If CALM-safe**: Relax the guard to only block `net-add-propagator` during fire rounds, not `net-new-cell`. Simpler fix for narrowing (no refactoring needed).

**If NOT CALM-safe**: Narrowing rule evaluation needs pre-allocated cell IDs or the two-phase protocol from the Stage 2 audit.

---

## Implementation Phases

### Phase 0: Narrowing CALM Validation (empirical)
- Temporarily relax `current-bsp-fire-round?` guard to allow `net-new-cell` but block `net-add-propagator`
- Run narrowing tests under BSP: `raco test tests/test-narrowing-*.rkt` with `current-use-bsp-scheduler? #t`
- If all pass → cell-only creation is CALM-safe. Proceed with simplified design.
- If failures → narrowing needs the full request protocol. Expand Phase 3.

### Phase 1: Decomposition-Request Cell Infrastructure
- Add `decomp-request` struct to propagator.rkt
- Add `decomp-request-cell` to `prop-network` (created in `make-prop-network`)
- Merge function: set-union. Bot: empty set.
- Export: `prop-network-decomp-request-cell`

### Phase 2: SRE Decomposition → Request Emission
- Replace `sre-decompose-generic` call in fire functions with `sre-emit-decomposition-request`
- `sre-emit-decomposition-request` writes to decomp-request cell
- Move `sre-decompose-generic` to be called from topology stratum handler only
- Keep `sre-get-or-create-sub-cells`, `sre-identify-sub-cell` unchanged (called from topology handler)
- Update `sre-maybe-decompose` to emit request instead of decompose inline
- ~50 lines changed in sre-core.rkt

### Phase 3: Narrowing Branch → Request Emission (if needed)
- If Phase 0 shows cell-only is CALM-safe: only refactor `make-branch-fire-fn` to emit requests (it calls `install-narrowing-propagators` which adds propagators)
- If Phase 0 shows cell-only is NOT safe: also refactor `make-rule-fire-fn`
- ~30 lines changed in narrowing.rkt

### Phase 4: Topology Stratum in BSP Loop
- Implement `process-topology-requests` in propagator.rkt
- Modify `run-to-quiescence-bsp` to add outer loop (value stratum → topology stratum → repeat)
- Handle decomp registry writes (`net-pair-decomp-insert`, `net-cell-decomp-insert`) in topology stratum
- ~40 lines in propagator.rkt

### Phase 5: BSP-as-Default + Full Suite Verification
- Flip `current-use-bsp-scheduler?` to `#t`
- Run individual failing tests first (test-sre-subtype.rkt)
- Then full suite regression gate
- Verify 380/380 green, 72/72 library files correct

### Phase 6: CALM Guard Hardening
- Keep `current-bsp-fire-round?` active in production (not just during testing)
- If Phase 0 confirmed cell-only CALM-safe: guard blocks `net-add-propagator` only
- If not: guard blocks both `net-add-propagator` AND `net-new-cell`
- Document the CALM contract in propagator.rkt header

### Phase 7: Constraint-Propagators Contract
- Document `install-fn` callback contract: must not call `net-add-propagator`
- Add runtime assertion in `install-constraint->method-propagator`

### Phase 8: PIR + Tracker + Dailies

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Narrowing cell-only is NOT CALM-safe | Low | Medium — adds Phase 3 scope | Phase 0 validates empirically before design commits |
| Decomp registry writes cause subtle BSP issues | Medium | Low — registries are guards, not scheduling | Topology stratum handles them alongside cell/propagator creation |
| Performance regression from outer loop overhead | Low | Low — outer loop fires ≤ depth of type nesting | Benchmark before/after |
| Fire functions that we missed in audit | Low | Caught by CALM guard at runtime | Guard is correct-by-construction |

## Estimated Scope

| Component | Lines | Time |
|-----------|-------|------|
| Phase 0 (validation) | 0 (parameter tweak) | 10 min |
| Phase 1 (infrastructure) | ~20 | 15 min |
| Phase 2 (SRE refactor) | ~50 | 30 min |
| Phase 3 (narrowing, if needed) | ~30 | 20 min |
| Phase 4 (BSP loop) | ~40 | 20 min |
| Phase 5 (verification) | 0 | 15 min |
| Phase 6-7 (hardening) | ~10 | 10 min |
| Phase 8 (PIR) | — | 15 min |
| **Total** | **~150 lines** | **~2h 15m** |

---

## NTT Speculative Syntax

```
;; Decomposition request as a lattice value
:lattice :set DecompRequest
  :merge set-union
  :bot   empty-set

;; The decomp-request cell
:cell decomp-requests : (Set DecompRequest)
  :lattice :set DecompRequest

;; Value stratum propagator (fire function)
:propagator sre-subtype-check
  :reads  [cell-a cell-b]
  :writes [cell-a cell-b decomp-requests]  ;; may emit request
  :monotone  ;; value-only writes

;; Topology stratum handler (between BSP rounds)
:stratum topology
  :reads  [decomp-requests]
  :creates [sub-cells sub-propagators]  ;; topology changes
  :sequential  ;; not parallelizable
```

---

## Principles Alignment

| Principle | How This Design Serves It |
|-----------|--------------------------|
| **Propagator-Only** | Decomposition requests ARE cell values on the network. No side-channel. |
| **Data Orientation** | Requests are data (structs in a set cell), not imperative side effects. |
| **Correct-by-Construction** | CALM guard enforces the invariant structurally. BSP can't silently drop topology. |
| **Decomplection** | Value propagation and topology construction are separated into distinct strata. |
| **Completeness** | We fix the root cause (stratified topology) rather than working around it (reverting BSP). |
