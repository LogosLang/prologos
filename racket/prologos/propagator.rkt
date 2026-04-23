#lang racket/base

;;;
;;; propagator.rkt — Persistent Propagator Network
;;;
;;; A persistent, immutable propagator network backed by CHAMP maps.
;;; All operations are pure: they take a network and return a new network.
;;; The old network is never modified (structural sharing via CHAMP).
;;;
;;; This is Racket-level infrastructure with no dependency on Prologos
;;; syntax or type system. Cell values are opaque Racket values.
;;;
;;; Design reference: docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.md §2
;;;
;;; PAR Track 1 CALM Contract:
;;; Fire functions are pure state transformers: (prop-network → prop-network).
;;; During BSP fire rounds (current-bsp-fire-round? = #t):
;;;   - net-cell-read: allowed (reads from snapshot)
;;;   - net-cell-write: allowed (value writes captured by CHAMP diff)
;;;   - net-new-cell: allowed (captured via next-cell-id comparison)
;;;   - net-add-propagator: allowed but DEFERRED (not on worklist until
;;;     next BSP round; captured via next-prop-id comparison)
;;; The BSP infrastructure handles all structural changes transparently.
;;; No module needs explicit BSP awareness — the infrastructure is the
;;; enforcement point.
;;;
;;; Known BSP limitation: non-idempotent merge functions (e.g., list-append)
;;; may double-merge values due to snapshot vs canonical divergence. Use
;;; DFS wrapper for tests that rely on non-idempotent merges.
;;;
;;; Known BSP limitation: meta-solving via imperative state
;;; (current-meta-info box) doesn't propagate through BSP's snapshot
;;; isolation. Will resolve when elaboration moves onto the network.
;;;

(require "champ.rkt"
         "performance-counters.rkt"
         "decision-cell.rkt"  ;; BSP-LE Track 2: commitment cell + nogood lattice
         "merge-fn-registry.rkt"  ;; PPN 4C Phase 1c: Tier 3 domain inheritance
         "source-location.rkt"  ;; PPN 4C Phase 1.5: current-source-loc for on-network srcloc
         racket/future         ;; for future, touch, processor-count
         racket/set            ;; PAR Track 1: set-union for decomp-request cell
         racket/async-channel  ;; Phase 2d: buffered channel for streaming results
         racket/list     ;; PAR Track 2: split-at for chunk partitioning
         racket/hash)    ;; BSP-LE Track 2 Phase 3: hash-union for commitment merge

(provide
 ;; Identity types
 (struct-out cell-id)
 (struct-out prop-id)
 ;; Core structs
 (struct-out prop-cell)
 (struct-out propagator)
 ;; Network struct — split into hot/warm/cold inner structs (BSP-LE Track 0 Phase 3b)
 (struct-out prop-net-hot)
 (struct-out prop-net-warm)
 (struct-out prop-net-cold)
 (struct-out prop-network)
 ;; Compatibility accessors — zero-cost macros preserving old API
 prop-network-cells
 prop-network-propagators
 prop-network-worklist
 prop-network-next-cell-id
 prop-network-next-prop-id
 prop-network-fuel
 prop-network-contradiction
 prop-network-merge-fns
 prop-network-contradiction-fns
 prop-network-widen-fns
 prop-network-cell-decomps
 prop-network-pair-decomps
 prop-network-cell-dirs
 prop-network-cell-domains  ;; PPN 4C Phase 1c: Tier 3 domain inheritance
 lookup-cell-domain          ;; PPN 4C Phase 1c: cell-id → domain-name-symbol or #f
 current-domain-classification-lookup  ;; PPN 4C Phase 1f: callback for structural enforcement
 enforce-component-paths!   ;; PPN 4C Phase 1f: structural-cell component-paths enforcement
 ;; Hash helpers (for CHAMP keying)
 cell-id-hash
 prop-id-hash
 ;; Network construction
 make-prop-network
 fork-prop-network
 ;; Cell operations
 net-new-cell
 net-new-cells-batch  ;; Phase 4: batch cell registration
 net-cell-read
 net-cell-write
 net-cell-replace  ;; Track 7 post-fix: bypass merge for S(-1) retraction
 net-remove-propagator-from-dependents  ;; Track 4B P2: remove ONE propagator from cell dependents
 net-clear-dependents  ;; Track 4B Phase 6b P3: remove all dependents from a cell
 ;; Propagator operations
 net-add-propagator
 net-add-fire-once-propagator     ;; BSP-LE Track 2 Phase 5: general fire-once with flag-guard
 net-add-broadcast-propagator     ;; BSP-LE Track 2 Phase 1B: ONE propagator, N items, scheduler-decomposable
 fire-propagator                  ;; PPN 4C Phase 1.5: scheduler fire helper — parameterizes current-source-loc
 net-add-parallel-map-propagator  ;; BSP-LE Track 2 Phase 1A: (DEPRECATED — use broadcast)
 ;; Broadcast profile
 (struct-out broadcast-profile)
 ;; BSP-LE Track 2 Phase 2: assumption-tagged dependents
 (struct-out dependent-entry)
 make-branch-pu
 ;; BSP-LE Track 2 Phase 5.4: worldview projection propagator
 install-worldview-projection
 ;; PPN Track 4 Phase 1a: component-indexed firing
 pu-value-diff
 filter-dependents-by-paths
 ;; Threshold propagators (Phase 2.5b)
 make-threshold-fire-fn
 make-barrier-fire-fn
 net-add-threshold
 net-add-barrier
 ;; Scheduler: Gauss-Seidel (sequential)
 run-to-quiescence
 ;; Scheduler: BSP / Jacobi (parallel-ready) (Phase 2.5a)
 run-to-quiescence-bsp
 fire-and-collect-writes
 bulk-merge-writes
 sequential-fire-all
 ;; Parallel executor (Phase 2.5c)
 make-parallel-fire-all
 ;; Convenience queries
 net-contradiction?
 net-quiescent?
 net-fuel-remaining
 ;; Descending cells (WFLE Phase 1)
 net-new-cell-desc
 net-cell-direction
 ;; Widening support (Phase 6a)
 net-set-widen-point
 net-widen-point?
 net-new-cell-widen
 net-cell-write-widen
 run-to-quiescence-widen
 ;; Cross-domain propagation (Phase 6c)
 net-add-cross-domain-propagator
 ;; Structural decomposition registries (Phase 4c)
 net-cell-decomp-lookup
 net-cell-decomp-insert
 net-pair-decomp?
 net-pair-decomp-insert
 decomp-key
 decomp-key-hash
 ;; TMS cells — Track 4 Phase 1 — RETIRED 2026-04-22 (PPN 4C 1A-iii-a-wide Step 1).
 ;; BSP-LE 2/2B's tagged-cell-value substrate superseded TMS entirely for speculation.
 ;; Last consumer (elab-fresh-meta type meta cells) migrated in S1.a.
 ;; current-speculation-stack parameter retired in S1.d.
 ;; Phase 6+7: Per-propagator worldview bitmask for concurrent clause execution.
 ;; Each clause's fire function sets this before executing. net-cell-write reads
 ;; it for tagged-cell-value tagging. Enables M clauses' propagators on the SAME
 ;; network with distinct bitmask tags. 0 = no per-propagator override (use cache cell).
 current-worldview-bitmask
 wrap-with-worldview
 ;; Track 8 C5a: Global BSP scheduler override for A/B benchmarking
 current-use-bsp-scheduler?
 ;; CALM topology guard: #t during BSP fire rounds
 current-bsp-fire-round?
 ;; PAR Track 1: Decomposition request protocol
 (struct-out sre-decomp-request)
 (struct-out narrowing-branch-request)
 (struct-out narrowing-rule-request)
 decomp-request-merge
 decomp-request-cell-id
 net-cell-reset
 (struct-out callback-topology-request)
 ;; PAR Track 2 R1: BSP round statistics
 current-bsp-round-stats
 make-bsp-stats-accumulator
 ;; PAR Track 2 R2: Parallel thread executor
 make-parallel-thread-fire-all
 current-parallel-executor
 ;; BSP-LE Track 2 Phase 4: worldview cache cell-id (for external consumers)
 worldview-cache-cell-id
 ;; BSP-LE Track 2B Phase R1: well-known cell-ids for relation store and config
 relation-store-cell-id
 config-cell-id
 ;; BSP-LE Track 2B Phase R4: NAF-pending cell + stratum infrastructure
 naf-pending-cell-id
 naf-pending-merge
 register-stratum-handler!
 stratum-handlers
 ;; PPN 4C Phase 3c-iii: classify-inhabit residuation request cell + merge.
 classify-inhabit-request-cell-id
 classify-inhabit-request-merge
 ;; BSP-LE Track 2B Addendum A1: per-subsystem topology cells + shared merge
 constraint-propagators-topology-cell-id
 elaborator-topology-cell-id
 narrowing-topology-cell-id
 sre-topology-cell-id
 topology-request-merge
 ;; Phase 5a: propagator flags + fire-once as scheduler concept
 PROP-FIRE-ONCE
 PROP-EMPTY-INPUTS
 ;; BSP-LE Track 2B Phase 2b: parallel tree-reduce merge
 current-cell-id-namespace
 current-tree-reduce-threshold
 merge-fire-results
 tree-reduce-fire-results
 ;; BSP-LE Track 2B Phase 2c: semaphore-based worker pool
 pool-config-cell-id
 current-worker-pool
 make-worker-pool
 pool-dispatch
 pool-dispatch-async
 pool-handle-next!
 pool-handle-collect-all!
 make-pool-executor
 make-streaming-executor
 worker-pool-shutdown!
 ;; BSP-LE Track 2 Phase 5.9b: promote cell to tagged-cell-value
 promote-cell-to-tagged
 ;; Raw cell read (bypasses TMS unwrapping — now effectively identical to
 ;; net-cell-read's non-speculation path; kept for explicit provenance intent)
 net-cell-read-raw
 ;; net-commit-assumption, tms-retract, net-retract-assumption RETIRED 2026-04-22
 ;; (PPN 4C 1A-iii-a-wide Step 1 S1.c). TMS-era commit/retract APIs obsoleted
 ;; by tagged-cell-value + worldview-cache bitmask mechanism.
 ;; Trace data types (Visualization Phase 0)
 (struct-out bsp-round)
 (struct-out cell-diff)
 (struct-out atms-event)
 (struct-out atms-event:assume)
 (struct-out atms-event:retract)
 (struct-out atms-event:nogood)
 (struct-out prop-trace)
 ;; Trace capture (Visualization Phase 1)
 current-bsp-observer
 make-trace-accumulator
 ;; B2f Phase 0: Quiescence cell-write instrumentation
 current-quiescence-write-counter
 current-quiescence-change-counter)

;; ========================================
;; Structs
;; ========================================

;; Identity types — deterministic Nat counters (no gensym).
;; Monotonic within a network, making networks deterministic and serializable.
(struct cell-id (n) #:transparent)
(struct prop-id (n) #:transparent)

;; Propagator cell — immutable.
;; value: any Racket value (lattice element; starts at bot)
;; dependents: champ-root (prop-id → dependent-entry)
;;   PPN Track 4 Phase 1a: component-indexed propagator firing
;;   BSP-LE Track 2 Phase 2: assumption-tagged dependents (emergent dissolution)
(struct prop-cell (value dependents) #:transparent)

;; BSP-LE Track 2 Phase 2: Dependent entry with component-path + assumption tag.
;; paths: #f | symbol | (listof component-path-or-#f)
;;   #f = fire on ANY change (default, backward compat)
;;   symbol/list = fire only when matching PU component changes
;; assumption-id: #f | assumption-id
;;   #f = always active (parent propagator, default)
;;   assumption-id = active only while this assumption is in its decision cell's domain
;;   When not viable: scheduler skips this dependent (emergent dissolution)
;; decision-cell-id: #f | cell-id
;;   The decision cell to read for viability checking (on-network, not parameter).
;;   When assumption-id is set, decision-cell-id MUST be set (the cell that governs
;;   this assumption's viability). filter-dependents-by-paths reads this cell
;;   directly from the network — no ambient parameter needed.
(struct dependent-entry (paths assumption-id decision-cell-id) #:transparent)

;; Propagator — monotone function, immutable.
;; inputs: list of cell-id (cells this propagator reads)
;; outputs: list of cell-id (cells this propagator may write)
;; fire-fn: (prop-network → prop-network) — pure state transformer
;; broadcast-profile: #f (default) | broadcast-profile struct
;;   When set, the scheduler can decompose this propagator's work
;;   into N independent tasks for parallel execution.
;; Phase 5a: flags field for scheduler-level propagator properties.
;; Bit 0 (PROP-FIRE-ONCE = 1): scheduler implements once-semantics + self-clearing
;; Bit 1 (PROP-EMPTY-INPUTS = 2): eligible for direct-fire (no snapshot needed)
(define PROP-FIRE-ONCE 1)
(define PROP-EMPTY-INPUTS 2)

;; PPN 4C Phase 1.5: srcloc field added for on-network source-location tracking.
;; The scheduler's fire-propagator wrapper parameterizes current-source-loc from
;; this field, so fire functions remain stateless (read the parameter, don't
;; capture srcloc in closure).
(struct propagator (inputs outputs fire-fn broadcast-profile flags srcloc) #:transparent)

;; PPN 4C Phase 1.5: scheduler fire-wrapping helper.
;; Invokes the propagator's fire function under `current-source-loc`
;; parameterized to the propagator's srcloc field. This keeps fire
;; functions stateless — they read (current-source-loc) at emit points
;; rather than capturing srcloc in a closure. The parameter value is
;; DERIVED from on-network state (propagator struct srcloc field), not
;; external scaffolding.
(define (fire-propagator prop net)
  (parameterize ([current-source-loc (propagator-srcloc prop)])
    ((propagator-fire-fn prop) net)))

;; BSP-LE Track 2 Phase 1B: Broadcast profile metadata.
;; Enables the scheduler to recognize and decompose data-indexed
;; parallel work within a single propagator.
;;
;; items: (listof any) — the data elements to process in parallel
;; item-fn: (any (listof value) → result-or-#f) — pure function per item.
;;          Takes: one item + the list of input cell values (read once, shared).
;;          Returns: a result value, or #f if this item produces nothing.
;; merge-fn: (any any → any) — accumulation function for results.
;;           Must be ACI (associative, commutative, idempotent) for BSP correctness.
(struct broadcast-profile (items item-fn merge-fn) #:transparent)

;; The Network as Value — all state in one immutable struct.
;; cells: champ-root : cell-id → prop-cell
;; propagators: champ-root : prop-id → propagator
;; worklist: list of prop-id (ephemeral; empty at quiescence)
;; next-cell-id: Nat — monotonic counter for cell ids
;; next-prop-id: Nat — monotonic counter for propagator ids
;; fuel: Nat — step limit to prevent runaway
;; contradiction: #f | cell-id — first contradiction encountered
;; merge-fns: champ-root : cell-id → (val val → val)
;; contradiction-fns: champ-root : cell-id → (val → Bool)
;; widen-fns: champ-root : cell-id → (cons widen-fn narrow-fn)
;;   where widen-fn : (old new → widened), narrow-fn : (old new → narrowed)
;;   Only cells designated as widening points have entries. (Phase 6a)
;; cell-decomps: champ-root : cell-id → (cons constructor-tag (listof cell-id))
;;   Per-cell sub-cell assignments for structural decomposition. (Phase 4c)
;; pair-decomps: champ-root : (cons cell-id cell-id) → #t
;;   Per-pair dedup: prevents duplicate sub-propagators between the same pair. (Phase 4c)
;; cell-dirs: champ-root : cell-id → 'ascending | 'descending
;;   Direction registry for cells. Absent entries default to 'ascending. (WFLE Phase 1)
;; BSP-LE Track 0 Phase 3b: Split prop-network into hot/warm/cold inner structs.
;; Hot: mutated every worklist iteration (worklist, fuel)
;; Warm: mutated per cell-write (cells, contradiction)
;; Cold: mutated only at allocation/setup time (all other fields)
(struct prop-net-hot (worklist fuel) #:transparent)
(struct prop-net-warm (cells contradiction) #:transparent)
(struct prop-net-cold (merge-fns contradiction-fns widen-fns
                       propagators next-cell-id next-prop-id
                       cell-decomps pair-decomps cell-dirs
                       cell-domains)  ;; PPN 4C Phase 1c: Tier 3 domain inheritance (cell-id → domain-name-symbol)
  #:transparent)
(struct prop-network (hot warm cold) #:transparent)

;; PAR Track 1: Decomposition request structs.
;; Fire functions emit these as values to the decomp-request cell.
;; The topology stratum processes them between BSP rounds.
;; Variant structs — each carries exactly its fields (D.2 revision).

;; SRE decomposition request (subtype, equality, duality)
(struct sre-decomp-request
  (pair-key    ;; decomp guard key (dedup)
   domain      ;; SRE domain struct (opaque to propagator.rkt)
   cell-a      ;; cell-id
   cell-b      ;; cell-id
   relation    ;; sre-relation (opaque)
   ctor-chain) ;; (listof symbol) — recursive type occurs check (§4.1)
  #:transparent)

;; Narrowing branch request: install child subtree propagators
(struct narrowing-branch-request
  (pair-key    ;; dedup
   tree        ;; dt-node (opaque — child subtree to install)
   arg-cells   ;; (listof cell-id)
   result-cell ;; cell-id
   bindings)   ;; (listof cell-id)
  #:transparent)

;; Narrowing rule request: evaluate RHS, create cells, write result
(struct narrowing-rule-request
  (pair-key    ;; dedup
   rhs         ;; expr (opaque — the RHS expression)
   bindings    ;; (listof cell-id) — binding cells to read
   result-cell) ;; cell-id — where to write the final term
  #:transparent)

;; Generic callback topology request: for fire functions that call opaque
;; install callbacks (e.g., constraint-propagators install-fn).
;; The topology stratum calls the callback outside the BSP fire round.
(struct callback-topology-request
  (callback    ;; (prop-network → prop-network) — the topology-creating function
   pair-key)   ;; dedup key
  #:transparent)

;; Decomp-request cell merge: set-union. Bot: empty set.
;; Lifecycle: fire functions add requests (monotone). Topology stratum
;; clears by writing empty set (non-monotone, permitted outside BSP).
(define (decomp-request-merge old new)
  (set-union old new))

;; Well-known cell-id for the decomp-request cell.
;; Convention: cell-id 0 in every network is the request cell.
(define decomp-request-cell-id (cell-id 0))

;; Stable accessor macros — zero-cost (compile-time inlined).
;; Public API for reading prop-network fields. Decouples consumers from
;; the hot/warm/cold inner struct layout. 18 files use these accessors.
(define-syntax-rule (prop-network-worklist net)
  (prop-net-hot-worklist (prop-network-hot net)))
(define-syntax-rule (prop-network-fuel net)
  (prop-net-hot-fuel (prop-network-hot net)))
(define-syntax-rule (prop-network-cells net)
  (prop-net-warm-cells (prop-network-warm net)))
(define-syntax-rule (prop-network-contradiction net)
  (prop-net-warm-contradiction (prop-network-warm net)))
(define-syntax-rule (prop-network-merge-fns net)
  (prop-net-cold-merge-fns (prop-network-cold net)))
(define-syntax-rule (prop-network-contradiction-fns net)
  (prop-net-cold-contradiction-fns (prop-network-cold net)))
(define-syntax-rule (prop-network-widen-fns net)
  (prop-net-cold-widen-fns (prop-network-cold net)))
(define-syntax-rule (prop-network-propagators net)
  (prop-net-cold-propagators (prop-network-cold net)))
(define-syntax-rule (prop-network-next-cell-id net)
  (prop-net-cold-next-cell-id (prop-network-cold net)))
(define-syntax-rule (prop-network-next-prop-id net)
  (prop-net-cold-next-prop-id (prop-network-cold net)))
(define-syntax-rule (prop-network-cell-decomps net)
  (prop-net-cold-cell-decomps (prop-network-cold net)))
(define-syntax-rule (prop-network-pair-decomps net)
  (prop-net-cold-pair-decomps (prop-network-cold net)))
(define-syntax-rule (prop-network-cell-dirs net)
  (prop-net-cold-cell-dirs (prop-network-cold net)))
;; PPN 4C Phase 1c: Tier 3 domain inheritance — cell-id → domain-name-symbol
(define-syntax-rule (prop-network-cell-domains net)
  (prop-net-cold-cell-domains (prop-network-cold net)))

;; ========================================
;; Trace Data Types (Visualization Phase 0)
;; ========================================

;; Per-cell change record within a BSP round — pure data.
;; source-propagator: which propagator wrote this change
(struct cell-diff (cell-id old-value new-value source-propagator) #:transparent)

;; ATMS events that occur during a BSP round (non-monotonic operations).
;; Base struct + three variants for assume, retract, nogood.
(struct atms-event () #:transparent)
(struct atms-event:assume atms-event (cell-id assumption-label) #:transparent)
(struct atms-event:retract atms-event (cell-id assumption-label reason) #:transparent)
(struct atms-event:nogood atms-event (nogood-set explanation) #:transparent)

;; A single BSP round's record — pure data, no side effects.
;; network-snapshot: immutable CHAMP snapshot at round end
;; cell-diffs: (listof cell-diff) — what changed this round
;; propagators-fired: (listof prop-id) — which propagators executed
;; contradiction: #f | cell-id — contradiction detected this round
;; atms-events: (listof atms-event) — assumption/retraction/nogood events
(struct bsp-round
  (round-number network-snapshot cell-diffs propagators-fired contradiction atms-events)
  #:transparent)

;; The complete trace of an elaboration run — pure data.
;; initial-network: prop-network state before first round
;; rounds: (listof bsp-round) in chronological order
;; final-network: prop-network at quiescence
;; metadata: hasheq of elaboration context (file, timestamp, fuel-used, etc.)
(struct prop-trace (initial-network rounds final-network metadata) #:transparent)

;; ========================================
;; Trace Capture (Visualization Phase 1)
;; ========================================

;; Observer callback: (bsp-round → void). #f = no observer = zero cost.
;; The scheduler calls this at the end of each BSP round with a bsp-round record.
;; What happens to the record is the caller's concern (accumulate, stream, filter).
(define current-bsp-observer (make-parameter #f))

;; PAR Track 2 R1: BSP round statistics accumulator.
;; When set, the BSP inner loop records per-round stats:
;;   (list worklist-size fire-time-ms merge-time-ms write-count deferred-prop-count)
;; Zero overhead when #f (default).
(define current-bsp-round-stats (make-parameter #f))

(define (make-bsp-stats-accumulator)
  (define stats (box '()))
  (values
   stats
   (lambda () (reverse (unbox stats)))))

;; Convenience: create an accumulating observer + getter pair.
;; Returns (values observer-fn get-rounds-fn).
;; observer-fn: (bsp-round → void) — pass to current-bsp-observer
;; get-rounds-fn: (→ (listof bsp-round)) — call after quiescence
(define (make-trace-accumulator)
  (define rounds (box '()))
  (define counter (box 0))
  (values
   (lambda (round)
     (define n (unbox counter))
     (set-box! counter (add1 n))
     ;; Re-stamp round-number so it auto-increments across scheduler calls
     (set-box! rounds (cons (struct-copy bsp-round round [round-number n])
                            (unbox rounds))))
   (lambda () (reverse (unbox rounds)))))

;; ========================================
;; Hash Helpers
;; ========================================

;; Use the integer directly as hash — cell-id and prop-id wrap Nats,
;; so the Nat itself is a perfect hash (unique, deterministic).
(define (cell-id-hash cid) (cell-id-n cid))
(define (prop-id-hash pid) (prop-id-n pid))

;; ========================================
;; Network Construction
;; ========================================

;; Well-known cell-id for the worldview bitmask cache.
;; Convention: cell-id 1 in every network. Holds the current worldview bitmask.
;; Derived from decision cells via fan-in (OR of committed assumptions).
;; net-cell-read uses this for O(1) bitmask-tagged value filtering.
(define worldview-cache-cell-id (cell-id 1))

;; BSP-LE Track 2B Phase R1: well-known cell-ids for solver data.
;; Cell-id 2: relation store (hasheq relation-name → relation-info).
;; Merge: hash-union (monotone accumulation, CALM-safe).
;; Written once at query start; in self-hosted compiler, written by defr processing.
;; Component-indexed by relation name: goal-installation propagators declare
;; #:component-paths (list (cons relation-store-cell-id goal-name)).
(define relation-store-cell-id (cell-id 2))
(define (relation-store-merge old new)
  (if (hash? old)
      (if (hash? new)
          (for/fold ([acc old]) ([(k v) (in-hash new)])
            (hash-set acc k v))
          old)
      new))

;; Cell-id 3: solver config (solver-config struct).
;; Merge: first-write-wins (constant after initialization).
(define config-cell-id (cell-id 3))
(define (config-merge old new) old)  ;; first-write-wins: keep old value

;; BSP-LE Track 2B Phase R4: cell-id 4 = NAF-pending (S1 request accumulator).
;; Carrier: hasheq naf-aid → registration-info.
;; Merge: hash-union (NAF registrations accumulate monotonically).
;; Read by: S1 NAF handler after S0 quiesces.
;; Same pattern as decomp-request-cell for topology stratum.
(define naf-pending-cell-id (cell-id 4))
(define (naf-pending-merge old new)
  (if (hash? old)
      (if (hash? new)
          (for/fold ([acc old]) ([(k v) (in-hash new)])
            (hash-set acc k v))
          old)
      new))

;; BSP-LE Track 2B Addendum A1: Per-subsystem topology request cells.
;; Each subsystem's topology handler gets its own request cell with SET-valued
;; carrier and set-union merge. Replaces the legacy shared decomp-request-cell
;; approach where 4 subsystems wrote to cell-id 0 and dispatched via try-each
;; handler chain (imperative dispatch). Now: one cell ↔ one handler, uniform
;; stratum iteration.
;;
;; NOTE: hard-coded cell-IDs are a known debt. A future track may explore
;; dynamic cell-ID allocation for strata (see BSP-LE Master "Open Questions" #6
;; cell-metadata-driven scheduling). For now, 6-9 is the natural contiguous
;; allocation after the 6 well-known cells (0-5).
(define constraint-propagators-topology-cell-id (cell-id 6))
(define elaborator-topology-cell-id (cell-id 7))
(define narrowing-topology-cell-id (cell-id 8))
(define sre-topology-cell-id (cell-id 9))
;; PPN 4C Phase 3c-iii: cell-id 10 = classify-inhabit residuation request.
;; Carrier: hasheq (cell-id × position) → narrowing-info.
;; Merge: hash-union (requests accumulate monotonically per-round).
;; Read by: classify-inhabit stratum handler (in typing-propagators.rkt)
;; after S0 quiesces. Handler processes pending narrowing / contradiction
;; actions per §6.15.8 Q2. Phase 9 joint design item (§6.15.6): narrowing
;; requests gain worldview assumption-id overlay later.
(define classify-inhabit-request-cell-id (cell-id 10))
(define (classify-inhabit-request-merge old new)
  (if (hash? old)
      (if (hash? new)
          (for/fold ([acc old]) ([(k v) (in-hash new)])
            (hash-set acc k v))
          old)
      new))
;; Shared merge for all topology request cells: SET-valued, set-union.
(define (topology-request-merge old new)
  (set-union old new))

;; Worldview cache merge: replacement (D.10).
;; The projection propagator writes the complete recomputed bitmask from
;; the compound decisions cell's merge-maintained field. Replacement (not ior)
;; handles retraction correctly — removed bits disappear when the projection
;; writes a bitmask without them. Equality check prevents spurious change
;; propagation when the bitmask hasn't actually changed.
(define (worldview-cache-merge old new)
  (if (= old new) old new))

;; BSP-LE Track 2 Phase 5.4: Install a projection propagator that watches
;; a compound decisions cell and writes the bitmask field to the worldview
;; cache cell (cell-id 1). O(1) per fire: extract struct field, write integer.
;;
;; decisions-cid: cell-id of the compound decisions cell (decisions-state)
;; Returns: (values new-network prop-id)
;;
;; NOT fire-once — fires on every compound cell change (bitmask evolves
;; as decisions commit). But lightweight: one field extraction, one write.
;; The worldview cache merge (equality check) prevents spurious propagation
;; when the bitmask hasn't actually changed.
(define (install-worldview-projection net decisions-cid)
  (define wv-cid worldview-cache-cell-id)
  (define fire-fn
    (lambda (n)
      (define raw (net-cell-read-raw n decisions-cid))
      (define bm (if (decisions-state? raw)
                     (decisions-state-bitmask raw)
                     0))
      (net-cell-write n wv-cid bm)))
  (net-add-propagator net (list decisions-cid) (list wv-cid) fire-fn))

;; Create an empty propagator network.
;; fuel: maximum number of propagator firings before run-to-quiescence stops.
(define (make-prop-network [fuel 1000000])
  ;; PAR Track 1: cell-id 0 is the decomp-request cell (well-known convention).
  ;; Pre-allocated with empty set as initial value and set-union as merge.
  (define req-cid decomp-request-cell-id)
  (define req-h (cell-id-hash req-cid))
  (define req-cell (prop-cell (set) champ-empty))  ;; empty set, no dependents
  ;; BSP-LE Track 2 Phase 4: cell-id 1 is the worldview bitmask cache.
  ;; Pre-allocated with 0 (no speculation) and bitwise-ior as merge.
  (define wv-cid worldview-cache-cell-id)
  (define wv-h (cell-id-hash wv-cid))
  (define wv-cell (prop-cell 0 champ-empty))  ;; 0 = no assumptions, no dependents
  ;; BSP-LE Track 2B Phase R1: cell-id 2 = relation store, cell-id 3 = config.
  ;; Pre-allocated with bot values. Written by solve-goal-propagator at query start.
  (define rs-cid relation-store-cell-id)
  (define rs-h (cell-id-hash rs-cid))
  (define rs-cell (prop-cell (hasheq) champ-empty))  ;; empty store, no dependents
  (define cfg-cid config-cell-id)
  (define cfg-h (cell-id-hash cfg-cid))
  (define cfg-cell (prop-cell #f champ-empty))  ;; #f = no config yet, no dependents
  ;; BSP-LE Track 2B Phase R4: cell-id 4 = NAF-pending (S1 request accumulator).
  (define naf-cid naf-pending-cell-id)
  (define naf-h (cell-id-hash naf-cid))
  (define naf-cell (prop-cell (hasheq) champ-empty))  ;; empty registry, no dependents
  ;; Phase 2c: cell-id 5 = pool configuration.
  (define pc-cid pool-config-cell-id)
  (define pc-h (cell-id-hash pc-cid))
  (define pc-cell (prop-cell #f champ-empty))  ;; #f = no pool config yet
  ;; A1: cells 6-9 = per-subsystem topology request cells.
  ;; All SET-valued with set-union merge; initial value empty set.
  (define cp-cid constraint-propagators-topology-cell-id)
  (define cp-h  (cell-id-hash cp-cid))
  (define cp-cell (prop-cell (set) champ-empty))
  (define elab-cid elaborator-topology-cell-id)
  (define elab-h  (cell-id-hash elab-cid))
  (define elab-cell (prop-cell (set) champ-empty))
  (define narr-cid narrowing-topology-cell-id)
  (define narr-h  (cell-id-hash narr-cid))
  (define narr-cell (prop-cell (set) champ-empty))
  (define sre-cid sre-topology-cell-id)
  (define sre-h  (cell-id-hash sre-cid))
  (define sre-cell (prop-cell (set) champ-empty))
  ;; PPN 4C Phase 3c-iii: cell-id 10 = classify-inhabit residuation request.
  (define cir-cid classify-inhabit-request-cell-id)
  (define cir-h (cell-id-hash cir-cid))
  (define cir-cell (prop-cell (hasheq) champ-empty))  ;; empty hasheq, no dependents
  (prop-network
   (prop-net-hot '() fuel)
   (prop-net-warm (for/fold ([acc champ-empty])
                            ([pair (in-list (list (cons req-h (cons req-cid req-cell))
                                                  (cons wv-h (cons wv-cid wv-cell))
                                                  (cons rs-h (cons rs-cid rs-cell))
                                                  (cons cfg-h (cons cfg-cid cfg-cell))
                                                  (cons naf-h (cons naf-cid naf-cell))
                                                  (cons pc-h (cons pc-cid pc-cell))
                                                  (cons cp-h (cons cp-cid cp-cell))
                                                  (cons elab-h (cons elab-cid elab-cell))
                                                  (cons narr-h (cons narr-cid narr-cell))
                                                  (cons sre-h (cons sre-cid sre-cell))
                                                  (cons cir-h (cons cir-cid cir-cell))))])
                    (champ-insert acc (car pair) (cadr pair) (cddr pair)))
                  #f)
   (prop-net-cold (for/fold ([acc champ-empty])
                            ([pair (in-list (list (cons req-h (cons req-cid decomp-request-merge))
                                                  (cons wv-h (cons wv-cid worldview-cache-merge))
                                                  (cons rs-h (cons rs-cid relation-store-merge))
                                                  (cons cfg-h (cons cfg-cid config-merge))
                                                  (cons naf-h (cons naf-cid naf-pending-merge))
                                                  (cons pc-h (cons pc-cid pool-config-merge))
                                                  (cons cp-h (cons cp-cid topology-request-merge))
                                                  (cons elab-h (cons elab-cid topology-request-merge))
                                                  (cons narr-h (cons narr-cid topology-request-merge))
                                                  (cons sre-h (cons sre-cid topology-request-merge))
                                                  (cons cir-h (cons cir-cid classify-inhabit-request-merge))))])
                    (champ-insert acc (car pair) (cadr pair) (cddr pair)))
                  champ-empty        ;;   contradiction-fns
                  champ-empty        ;;   widen-fns
                  champ-empty        ;;   propagators
                  11                 ;;   next-cell-id (0-5 well-known; 6-9 topology; 10 classify-inhabit request)
                  0                  ;;   next-prop-id
                  champ-empty        ;;   cell-decomps
                  champ-empty        ;;   pair-decomps
                  champ-empty        ;;   cell-dirs
                  champ-empty)))     ;;   cell-domains (PPN 4C Phase 1c)

;; Track 10 Phase 3: Fork a prop-network for subnetwork isolation.
;; Shares all CHAMP fields (cells, propagators, registries) via structural sharing.
;; Resets hot state (worklist, fuel) and contradiction.
;; O(1): two struct allocations. All data shared until child writes (CoW).
(define (fork-prop-network net [fuel 1000000])
  (prop-network
   (prop-net-hot '() fuel)                              ;; fresh worklist + fuel
   (prop-net-warm (prop-network-cells net) #f)          ;; shared cells, no contradiction
   (prop-network-cold net)))                            ;; shared: merge-fns, propagators, etc.

;; Track 10 Phase 3b: Ergonomic fork macro for test isolation.
;;
;; with-forked-network: fork the network in a given box parameter,
;; execute body with the forked network, discard on exit.
;; The parent network is unmodified (CHAMP structural sharing).
;; NOTE: Takes the box PARAMETER as first argument (not a value) to
;; avoid circular dependency — propagator.rkt can't import metavar-store.rkt.
;; Usage: (with-forked-network current-prop-net-box body ...)
(provide with-forked-network)
(define-syntax-rule (with-forked-network box-param body ...)
  (let* ([parent-box (box-param)]
         [parent-net (and parent-box (unbox parent-box))])
    (if parent-net
        ;; Parent has a network: fork it (CHAMP structural sharing)
        (let ([child-box (box (fork-prop-network parent-net))])
          (parameterize ([box-param child-box])
            body ...))
        ;; No parent network: keep #f, let process-command create its own
        (parameterize ([box-param #f])
          body ...))))

;; ========================================
;; Cell Operations
;; ========================================

;; Add a new cell to the network.
;; initial-value: the starting lattice value (typically bot)
;; merge-fn: (old-val new-val → merged-val) — the lattice join
;; contradicts?: optional (val → Bool) predicate for contradiction detection
;; Returns: (values new-network cell-id)
;; PPN 4C Phase 1c: Tier 3 domain inheritance.
;; #:domain overrides inheritance. Default #f → inherit via
;; lookup-merge-fn-domain. Unknown merge-fn stays unclassified (#f).
;; Phase 1f consumes via lookup-cell-domain to drive structural enforcement.
(define (net-new-cell net initial-value merge-fn
                      [contradicts? #f]
                      #:domain [explicit-domain #f])
  ;; PAR Track 1 D.3: net-new-cell is CALM-safe during BSP fire rounds.
  ;; Cells without dependents don't affect scheduling topology.
  ;; Phase 2b: during parallel BSP fire, cell-ids are namespaced by propagator
  ;; index to avoid collision. Namespace 0 = sequential (construction-time).
  (perf-inc-cell-alloc!)  ;; Track 7 Phase 0b
  (define ns (current-cell-id-namespace))
  (define local-id (prop-network-next-cell-id net))
  (define id (cell-id (if (zero? ns) local-id
                          (+ (arithmetic-shift ns 32) local-id))))
  (define cell (prop-cell initial-value champ-empty))
  (define h (cell-id-hash id))
  ;; Tier 3 domain resolution: override else inherited from merge-fn else #f
  (define resolved-domain
    (or explicit-domain (lookup-merge-fn-domain merge-fn)))
  (define net*
    (struct-copy prop-network net
      [warm (struct-copy prop-net-warm (prop-network-warm net)
              [cells (champ-insert (prop-network-cells net) h id cell)])]
      [cold (struct-copy prop-net-cold (prop-network-cold net)
              [merge-fns (champ-insert (prop-network-merge-fns net) h id merge-fn)]
              [next-cell-id (+ 1 (prop-network-next-cell-id net))]
              [cell-domains (if resolved-domain
                                (champ-insert (prop-network-cell-domains net)
                                              h id resolved-domain)
                                (prop-network-cell-domains net))])]))
  (values
   (if contradicts?
       (struct-copy prop-network net*
         [cold (struct-copy prop-net-cold (prop-network-cold net*)
                 [contradiction-fns
                  (champ-insert (prop-network-contradiction-fns net*)
                                h id contradicts?)])])
       net*)
   id))

;; PPN 4C Phase 1c: lookup cell's resolved domain (from override or inheritance).
;; Returns domain-name symbol or #f for unclassified cells.
;; Phase 1f uses this at net-add-propagator time to drive structural enforcement.
(define (lookup-cell-domain net cid)
  (define h (cell-id-hash cid))
  (define result (champ-lookup (prop-network-cell-domains net) h cid))
  (if (eq? result 'none) #f result))

;; PPN 4C Phase 1f (2026-04-20): classification-lookup callback parameter.
;; A module that can import both propagator.rkt and sre-core.rkt
;; (e.g., infra-cell-sre-registrations.rkt) wires this at load time.
;; Function signature: (domain-name → 'structural | 'value | 'unclassified | #f).
;; #f = parameter unset (no enforcement). 'unclassified = domain exists but
;; unclassified. 'structural/'value = classified; structural triggers
;; :component-paths enforcement.
(define current-domain-classification-lookup (make-parameter #f))

;; PPN 4C Phase 1f: enforce :component-paths for structural-domain cells.
;; Error-level: hard. Skips unclassified / value domains (progressive rollout).
(define (enforce-component-paths! net input-ids component-paths)
  (define lookup (current-domain-classification-lookup))
  (when lookup  ;; skip if no classification wiring yet
    (for ([cid (in-list input-ids)])
      (define domain-name (lookup-cell-domain net cid))
      (when domain-name
        (define classification (lookup domain-name))
        (when (eq? classification 'structural)
          ;; Check if :component-paths declares any path for this cell
          (define declared?
            (for/or ([pair (in-list component-paths)])
              (equal? (car pair) cid)))
          (unless declared?
            (error 'net-add-propagator
                   (string-append
                    "Propagator reading structural-domain cell ~a "
                    "(domain '~a) must declare :component-paths for it. "
                    "Structural cells require component-path specification "
                    "to avoid firing on unrelated component changes "
                    "(Correct-by-Construction, PPN 4C Phase 1f).")
                   cid domain-name)))))))

;; Create a new descending cell (starts at top, refines downward via meet).
;; top-value: the lattice top (initial value)
;; meet-fn: (old-val new-val -> met-val) — the lattice meet (used as merge-fn)
;; contradicts?: optional (val -> Bool) — for descending, typically (lambda (v) (eq? v bot))
;; Returns: (values new-network cell-id)
(define (net-new-cell-desc net top-value meet-fn
                            [contradicts? #f]
                            #:domain [explicit-domain #f])
  (perf-inc-cell-alloc!)  ;; Track 7 Phase 0b
  (define ns (current-cell-id-namespace))
  (define local-id (prop-network-next-cell-id net))
  (define id (cell-id (if (zero? ns) local-id
                          (+ (arithmetic-shift ns 32) local-id))))
  (define cell (prop-cell top-value champ-empty))
  (define h (cell-id-hash id))
  ;; PPN 4C Phase 1c: Tier 3 domain inheritance (meet-fn functions as merge-fn for lookup).
  (define resolved-domain
    (or explicit-domain (lookup-merge-fn-domain meet-fn)))
  (define net*
    (struct-copy prop-network net
      [warm (struct-copy prop-net-warm (prop-network-warm net)
              [cells (champ-insert (prop-network-cells net) h id cell)])]
      [cold (struct-copy prop-net-cold (prop-network-cold net)
              [merge-fns (champ-insert (prop-network-merge-fns net) h id meet-fn)]
              [cell-dirs (champ-insert (prop-network-cell-dirs net) h id 'descending)]
              [next-cell-id (+ 1 (prop-network-next-cell-id net))]
              [cell-domains (if resolved-domain
                                (champ-insert (prop-network-cell-domains net)
                                              h id resolved-domain)
                                (prop-network-cell-domains net))])]))
  (values
   (if contradicts?
       (struct-copy prop-network net*
         [cold (struct-copy prop-net-cold (prop-network-cold net*)
                 [contradiction-fns
                  (champ-insert (prop-network-contradiction-fns net*)
                                h id contradicts?)])])
       net*)
   id))

;; BSP-LE Track 0 Phase 4: Batch cell registration.
;; Allocate N cells at once using transient CHAMP builders, producing one
;; persistent network update instead of N sequential updates.
;; specs: (listof (list initial-value merge-fn)) or
;;        (listof (list initial-value merge-fn contradicts?))
;; Returns: (values new-network (listof cell-id))
;; Cell IDs are allocated as a contiguous range [start, start+N).
(define (net-new-cells-batch net specs)
  (define n (length specs))
  (if (zero? n)
      (values net '())
      (net-new-cells-batch-inner net specs n)))

(define (net-new-cells-batch-inner net specs n)
  (define start-id (prop-network-next-cell-id net))
  (define ns (current-cell-id-namespace))
  ;; Build transient CHAMPs from current persistent maps
  (define t-cells (champ-transient (prop-network-cells net)))
  (define t-merge (champ-transient (prop-network-merge-fns net)))
  (define t-contra (champ-transient (prop-network-contradiction-fns net)))
  ;; PPN 4C Phase 1c: Tier 3 domain inheritance for batch-allocated cells.
  ;; Batch spec format does not currently carry an override; inheritance only.
  ;; Future override support: extend spec to (list init merge-fn contradicts? domain).
  (define t-domains (champ-transient (prop-network-cell-domains net)))
  (define has-contra? #f)
  (define has-domain? #f)
  ;; Allocate all cells into transients
  (define ids
    (for/list ([spec (in-list specs)]
               [i (in-naturals start-id)])
      (perf-inc-cell-alloc!)
      ;; Phase 2b: namespaced cell-id during parallel fire
      (define id (cell-id (if (zero? ns) i (+ (arithmetic-shift ns 32) i))))
      (define h (cell-id-hash id))
      (define initial-value (car spec))
      (define merge-fn (cadr spec))
      (define cell (prop-cell initial-value champ-empty))
      (tchamp-insert! t-cells h id cell)
      (tchamp-insert! t-merge h id merge-fn)
      (when (and (pair? (cddr spec)) (caddr spec))
        (set! has-contra? #t)
        (tchamp-insert! t-contra h id (caddr spec)))
      ;; Tier 3 inheritance: lookup merge-fn's registered domain, if any
      (define inherited-domain (lookup-merge-fn-domain merge-fn))
      (when inherited-domain
        (set! has-domain? #t)
        (tchamp-insert! t-domains h id inherited-domain))
      id))
  ;; Freeze all transients at once
  (define new-net
    (struct-copy prop-network net
      [warm (struct-copy prop-net-warm (prop-network-warm net)
              [cells (tchamp-freeze t-cells)])]
      [cold (cond
              [(and has-contra? has-domain?)
               (struct-copy prop-net-cold (prop-network-cold net)
                 [merge-fns (tchamp-freeze t-merge)]
                 [contradiction-fns (tchamp-freeze t-contra)]
                 [cell-domains (tchamp-freeze t-domains)]
                 [next-cell-id (+ start-id n)])]
              [has-contra?
               (struct-copy prop-net-cold (prop-network-cold net)
                 [merge-fns (tchamp-freeze t-merge)]
                 [contradiction-fns (tchamp-freeze t-contra)]
                 [next-cell-id (+ start-id n)])]
              [has-domain?
               (struct-copy prop-net-cold (prop-network-cold net)
                 [merge-fns (tchamp-freeze t-merge)]
                 [cell-domains (tchamp-freeze t-domains)]
                 [next-cell-id (+ start-id n)])]
              [else
               (struct-copy prop-net-cold (prop-network-cold net)
                 [merge-fns (tchamp-freeze t-merge)]
                 [next-cell-id (+ start-id n)])])]))
  (values new-net ids))

;; Query a cell's direction. Returns 'ascending (default) or 'descending.
(define (net-cell-direction net cid)
  (define dir (champ-lookup (prop-network-cell-dirs net)
                             (cell-id-hash cid) cid))
  (if (eq? dir 'none) 'ascending dir))

;; Read a cell's current value.
;; BSP-LE Track 2 Phase 4: tagged-cell-value aware. If the cell holds a
;; tagged-cell-value, reads the worldview cache cell for the current bitmask
;; and filters entries via O(K) bitmask subset checks.
;; Falls back to TMS-transparent read for backward compatibility during migration.
;; Errors on unknown cell-id.
(define (net-cell-read net cid)
  (define cell (champ-lookup (prop-network-cells net)
                              (cell-id-hash cid) cid))
  (if (eq? cell 'none)
      (error 'net-cell-read "unknown cell: ~a" cid)
      (let ([v (prop-cell-value cell)])
        (cond
          [(tagged-cell-value? v)
           ;; Determine worldview bitmask for filtering.
           ;; Per-propagator bitmask (current-worldview-bitmask) takes priority —
           ;; enables concurrent clause propagators to read their own tagged entries,
           ;; not entries from sibling clauses. Without this, all propagators sharing
           ;; a network would see the same (cache cell) bitmask, destroying isolation.
           ;; Fallback: worldview cache cell (for network-wide worldview).
           (define per-prop-wv (current-worldview-bitmask))
           (define wv-bitmask
             (if (not (zero? per-prop-wv))
                 per-prop-wv
                 (let ([wv-cell (champ-lookup (prop-network-cells net)
                                              (cell-id-hash worldview-cache-cell-id)
                                              worldview-cache-cell-id)])
                   (if (eq? wv-cell 'none) 0 (prop-cell-value wv-cell)))))
           ;; Phase 11: extract domain merge from cell's merge-fn for
           ;; same-specificity entry merging (e.g., union type Nat+Bool→Type 0).
           ;; The merge-fn is make-tagged-merge(domain-merge). When called with
           ;; two plain values, it delegates to domain-merge. We use this as the
           ;; domain-merge callback for tagged-cell-read.
           (define h (cell-id-hash cid))
           (define merge-fn-raw (champ-lookup (prop-network-merge-fns net) h cid))
           (define domain-merge
             (if (eq? merge-fn-raw 'none)
                 #f
                 ;; The merge-fn handles tagged-cell-values at the outer level.
                 ;; For plain values, it delegates to domain-merge. We can use it
                 ;; directly as the merge for same-specificity entries.
                 merge-fn-raw))
           (tagged-cell-read v wv-bitmask domain-merge)]
          ;; PPN 4C 1A-iii-a-wide Step 1 S1.b (2026-04-22): TMS fallback RETIRED.
          ;; S1.a migrated elab-fresh-meta (last TMS consumer) to tagged-cell-value.
          ;; No live consumers of tms-cell-value remain in production; branch is dead.
          ;; TMS API retired in S1.c; current-speculation-stack in S1.d.
          [else v]))))

;; Read a cell's raw value without TMS unwrapping.
;; Used for commit operations and provenance inspection where
;; the full tms-cell-value tree is needed.
(define (net-cell-read-raw net cid)
  (define cell (champ-lookup (prop-network-cells net)
                              (cell-id-hash cid) cid))
  (if (eq? cell 'none)
      (error 'net-cell-read-raw "unknown cell: ~a" cid)
      (prop-cell-value cell)))

;; PPN Track 4B Phase 1: compute which component paths changed between
;; old and new values. Returns a list of changed paths, or #f meaning
;; "everything changed" (non-structured values, or structural mismatch).
;;
;; For NESTED hasheq values (attribute maps: position → (hasheq facet → value)),
;; produces COMPOUND paths: (cons position facet) for each changed facet.
;; This enables precise component-indexed firing: a typing propagator watching
;; (pos . :type) doesn't fire when (pos . :context) changes.
;;
;; For FLAT hasheq values (legacy type-maps), produces position keys as before.
;; For all other values, returns #f (all dependents fire).
(define (pu-value-diff old-val new-val)
  (cond
    ;; Both are hasheq → diff per key, with nested record support
    [(and (hash? old-val) (immutable? old-val)
          (hash? new-val) (immutable? new-val))
     (define changed '())
     ;; Keys in new that differ from old (changed or added)
     (for ([(k v) (in-hash new-val)])
       (define old-v (hash-ref old-val k 'pu-diff-absent))
       (unless (or (eq? v old-v) (equal? v old-v))
         ;; Track 4B Phase 1: if BOTH values are hasheq (nested record),
         ;; diff the inner record and emit compound (position . facet) paths.
         (if (and (hash? v) (immutable? v)
                  (hash? old-v) (immutable? old-v))
             ;; Nested: emit (position . facet) for each changed facet
             (begin
               (for ([(fk fv) (in-hash v)])
                 (define old-fv (hash-ref old-v fk 'pu-diff-absent))
                 (unless (or (eq? fv old-fv) (equal? fv old-fv))
                   (set! changed (cons (cons k fk) changed))))
               ;; Facets in old missing from new (removed)
               (for ([(fk _fv) (in-hash old-v)])
                 (unless (hash-has-key? v fk)
                   (set! changed (cons (cons k fk) changed)))))
             ;; Flat (or new record, old absent): emit position key
             ;; For new nested records, emit all facets as changed
             (if (and (hash? v) (immutable? v)
                      (eq? old-v 'pu-diff-absent))
                 (for ([(fk _fv) (in-hash v)])
                   (set! changed (cons (cons k fk) changed)))
                 (set! changed (cons k changed))))))
     ;; Keys in old missing from new (removed)
     (for ([(k _v) (in-hash old-val)])
       (unless (hash-has-key? new-val k)
         (set! changed (cons k changed))))
     (if (null? changed) '() changed)]
    ;; Non-structured or type mismatch → everything changed
    [else #f]))

;; PPN Track 4 Phase 1a: filter dependent prop-ids by component paths.
;; PPN Track 4B Phase 0a: multi-path support — each dependent stores a
;; LIST of paths, not a single path. A propagator fires if ANY of its
;; watched paths intersects the changed set.
;; BSP-LE Track 2 Phase 2: dependent entries are now dependent-entry structs
;; with paths + assumption-id + decision-cell-id. The assumption check
;; reads the decision cell ON-NETWORK (no parameter) to skip inert dependents.
;; deps-champ: prop-id → dependent-entry
;; changed-paths: list of changed path keys, or #f meaning "all changed"
;; net: prop-network — for on-network viability reads
;; Returns: list of prop-id to enqueue.
(define (filter-dependents-by-paths deps-champ changed-paths [net #f])
  (cond
    ;; Fast path: all changed + no assumption-tagged dependents → enqueue all
    [(and (not changed-paths) (not net))
     (champ-keys deps-champ)]
    ;; Specific filtering needed
    [else
     (define changed-set (or changed-paths #f))
     (champ-fold
      deps-champ
      (lambda (pid entry acc)
        (define paths (if (dependent-entry? entry) (dependent-entry-paths entry) entry))
        (define aid (if (dependent-entry? entry) (dependent-entry-assumption-id entry) #f))
        (define dcid (if (dependent-entry? entry) (dependent-entry-decision-cell-id entry) #f))
        (cond
          ;; BSP-LE Track 2: on-network assumption viability check (emergent dissolution)
          ;; Read the decision cell DIRECTLY from the network — no parameter.
          [(and aid dcid net)
           (define decision-val (net-cell-read net dcid))
           (define viable?
             (cond
               [(decision-bot? decision-val) #t]  ;; unconstrained = all viable
               [(decision-top? decision-val) #f]  ;; contradicted = none viable
               [(decision-one? decision-val)
                (equal? (decision-one-assumption decision-val) aid)]
               [(decision-set? decision-val)
                (hash-has-key? (decision-set-alternatives decision-val) aid)]
               [else #t]))  ;; unknown format = assume viable (defensive)
           (if viable?
               ;; Viable: continue with path filtering below
               (cond
                 [(not changed-set) (cons pid acc)]
                 [(not paths) (cons pid acc)]
                 [(and (list? paths) (memq #f paths)) (cons pid acc)]
                 [(and (list? paths)
                       (for/or ([p (in-list paths)]) (member p changed-set)))
                  (cons pid acc)]
                 [(member paths changed-set) (cons pid acc)]
                 [else acc])
               ;; Not viable: skip (inert)
               (begin (perf-inc-inert-dependent-skip!) acc))]
          ;; No assumption tag — standard path filtering
          ;; All changed + no path filtering → enqueue
          [(not changed-set) (cons pid acc)]
          ;; Nothing changed → skip
          [(null? changed-set) acc]
          ;; Single #f (legacy) or list containing #f → watch all, always fire
          [(not paths) (cons pid acc)]
          [(and (list? paths) (memq #f paths)) (cons pid acc)]
          ;; List of paths: fire if ANY path is in the changed set
          [(and (list? paths)
                (for/or ([p (in-list paths)])
                  (member p changed-set)))
           (cons pid acc)]
          ;; Legacy single path (non-list): fire if in changed set
          [(member paths changed-set) (cons pid acc)]
          ;; None matched → skip
          [else acc]))
      '())]))

;; Write a value to a cell: computes merge-fn(old, new).
;; Track 4 Phase 2: TMS-transparent. If the cell holds a tms-cell-value and
;; the new value is NOT a tms-cell-value (i.e., a plain domain value from a
;; propagator or solve-meta!), wraps it via tms-write at the current speculation
;; depth. This allows all existing code to write plain values to TMS cells.
;; If the merged value equals the old value, returns the network unchanged.
;; PAR Track 1: Direct cell value replacement (no merge, no dependent enqueue).
;; Used by the topology stratum to clear the decomp-request cell.
;; This is a NON-MONOTONE operation — only permitted outside BSP fire rounds.
(define (net-cell-reset net cid new-val)
  (define cells (prop-network-cells net))
  (define h (cell-id-hash cid))
  (define cell (champ-lookup cells h cid))
  (when (eq? cell 'none)
    (error 'net-cell-reset "unknown cell: ~a" cid))
  (define new-cell (prop-cell new-val (prop-cell-dependents cell)))
  (struct-copy prop-network net
    [warm (struct-copy prop-net-warm (prop-network-warm net)
            [cells (champ-insert cells h cid new-cell)])]))

;; BSP-LE Track 2 Phase 5.9b: Promote a cell to tagged-cell-value.
;; The current value becomes the base; entries start empty.
;; Must be called BEFORE speculative writes under a non-zero worldview.
;; No-op if the cell already holds a tagged-cell-value.
(define (promote-cell-to-tagged net cid)
  (define val (net-cell-read-raw net cid))
  (if (tagged-cell-value? val)
      net  ;; already tagged — no-op
      ;; Reset value to tagged-cell-value AND update merge function to
      ;; make-tagged-merge. Without this, the original merge function (e.g.,
      ;; logic-var-merge) doesn't understand tagged-cell-value structure
      ;; and would destroy entries on merge.
      (let* ([old-merge (champ-lookup (prop-network-merge-fns net)
                                       (cell-id-hash cid) cid)]
             [domain-merge (if (eq? old-merge 'none) (lambda (o n) n) old-merge)]
             [new-merge (make-tagged-merge domain-merge)]
             [net1 (net-cell-reset net cid (tagged-cell-value val '()))]
             [h (cell-id-hash cid)])
        (struct-copy prop-network net1
          [cold (struct-copy prop-net-cold (prop-network-cold net1)
                  [merge-fns (champ-insert (prop-network-merge-fns net1) h cid new-merge)])]))))

;; Track 4B P2: Remove ONE propagator from a cell's dependents.
;; Used by fire-once self-cleaning propagators after producing output.
;; The propagator is removed from the dependents CHAMP — it won't be
;; scheduled on future writes to this cell.
;; Non-monotone — runs in the topology stratum via callback-topology-request.
(define (net-remove-propagator-from-dependents net pid cid)
  (define cells (prop-network-cells net))
  (define h (cell-id-hash cid))
  (define cell (champ-lookup cells h cid))
  (if (eq? cell 'none)
      net  ;; unknown cell — no-op
      (let* ([deps (prop-cell-dependents cell)]
             [ph (prop-id-hash pid)]
             [new-deps (champ-delete deps ph pid)]
             [new-cell (prop-cell (prop-cell-value cell) new-deps)])
        (struct-copy prop-network net
          [warm (struct-copy prop-net-warm (prop-network-warm net)
                  [cells (champ-insert cells h cid new-cell)])]))))

;; Track 4B Phase 6b P3: Clear all dependents from a cell.
;; The cell RETAINS its value — only the dependents CHAMP is emptied.
;; Used after per-command quiescence to remove inert propagators.
;; This keeps the attribute-map cell's values (computed types persist)
;; while ensuring the next command starts with zero scheduling overhead.
;; Non-monotone operation — call only outside quiescence.
(define (net-clear-dependents net cid)
  (define cells (prop-network-cells net))
  (define h (cell-id-hash cid))
  (define cell (champ-lookup cells h cid))
  (if (eq? cell 'none)
      net  ;; unknown cell — no-op (defensive)
      (let ([new-cell (prop-cell (prop-cell-value cell) champ-empty)])
        (struct-copy prop-network net
          [warm (struct-copy prop-net-warm (prop-network-warm net)
                  [cells (champ-insert cells h cid new-cell)])]))))

;; Otherwise: updates the cell, enqueues dependent propagators, and
;; optionally checks the contradiction predicate.
(define (net-cell-write net cid new-val)
  (define cells (prop-network-cells net))
  (define h (cell-id-hash cid))
  (define cell (champ-lookup cells h cid))
  (when (eq? cell 'none)
    (error 'net-cell-write "unknown cell: ~a" cid))
  ;; B2f Phase 0: count every write attempt
  (define wc (current-quiescence-write-counter))
  (when wc (set-box! wc (add1 (unbox wc))))
  (define merge-fn
    (champ-lookup (prop-network-merge-fns net) h cid))
  (define old-val (prop-cell-value cell))
  ;; BSP-LE Track 2 Phase 4: tagged-cell-value write.
  ;; If old value is tagged-cell-value and new is plain, wrap with worldview bitmask.
  ;; Falls back to TMS wrapping for legacy cells during migration.
  (define actual-new-val
    (cond
      [(and (tagged-cell-value? old-val) (not (tagged-cell-value? new-val)))
       ;; Determine worldview bitmask for tagging.
       ;; Phase 6+7: per-propagator bitmask (current-worldview-bitmask) takes priority.
       ;; This enables concurrent clause propagators on the same network — each fire
       ;; function sets its own bitmask via wrap-with-worldview. BSP fires them
       ;; concurrently, each sees its own bitmask, writes are tagged distinctly.
       ;; Fallback: read worldview cache cell (for network-wide worldview, e.g.,
       ;; elab-speculation-bridge sequential speculation).
       (define per-prop-wv (current-worldview-bitmask))
       (define wv-bitmask
         (if (not (zero? per-prop-wv))
             per-prop-wv
             (let ([wv-cell (champ-lookup cells
                                          (cell-id-hash worldview-cache-cell-id)
                                          worldview-cache-cell-id)])
               (if (eq? wv-cell 'none) 0 (prop-cell-value wv-cell)))))
       ;; Wrap as a DELTA tagged-cell-value (base=new-val, entry if worldview non-zero).
       ;; The merge function combines old+delta correctly without entry duplication.
       (if (zero? wv-bitmask)
           (tagged-cell-value new-val '())  ;; unconditional write → update base
           (tagged-cell-value (tagged-cell-value-base old-val)
                              (list (cons wv-bitmask new-val))))]
      ;; PPN 4C 1A-iii-a-wide Step 1 S1.b (2026-04-22): TMS fallback RETIRED
      ;; (net-cell-write). See net-cell-read branch for full retirement rationale.
      [else new-val]))
  (define merged (merge-fn old-val actual-new-val))
  (if (or (eq? merged old-val) (equal? merged old-val))
      net  ;; No change — return same network (critical for termination)
      (let* (;; B2f Phase 0: count writes that actually change the CHAMP
             [cc (current-quiescence-change-counter)]
             [_ (when cc (set-box! cc (add1 (unbox cc))))]
             [new-cell (struct-copy prop-cell cell [value merged])]
             [new-cells (champ-insert cells h cid new-cell)]
             ;; Enqueue dependents — PPN Track 4 Phase 1a: component-indexed filtering.
             ;; If any dependent has a component-path (not #f), compute PU-diff
             ;; and only enqueue dependents whose path intersects the diff.
             ;; If ALL dependents have path=#f, fast path: enqueue all (no diff needed).
             [deps-champ (prop-cell-dependents cell)]
             ;; PPN Track 4B Phase 0a: paths are now lists or #f.
             ;; has-component-paths? if any dependent has a non-#f paths value
             ;; containing at least one non-#f path.
             ;; BSP-LE Track 2 Phase 2: extract paths from dependent-entry structs
            [deps (let ([has-component-paths?
                          (champ-fold deps-champ
                                      (lambda (_k entry found?)
                                        (define paths (if (dependent-entry? entry)
                                                          (dependent-entry-paths entry)
                                                          entry))
                                        (or found?
                                            (and paths
                                                 (list? paths)
                                                 (for/or ([p (in-list paths)]) p))))
                                      #f)]
                        ;; Check if any dependent has an assumption tag
                        [has-assumptions?
                          (champ-fold deps-champ
                                      (lambda (_k entry found?)
                                        (or found?
                                            (and (dependent-entry? entry)
                                                 (dependent-entry-assumption-id entry))))
                                      #f)])
                     (if (or has-component-paths? has-assumptions?)
                         ;; Slow path: compute diff, filter dependents (+ on-network assumption check)
                         (let ([changed (if has-component-paths?
                                            (pu-value-diff old-val merged)
                                            #f)])
                           (filter-dependents-by-paths deps-champ changed
                                                       (if has-assumptions? net #f)))
                         ;; Fast path: no component paths, no assumptions → enqueue all
                         (champ-keys deps-champ)))]
             [new-wl (append deps (prop-network-worklist net))]
             ;; Check contradiction
             [cfn (champ-lookup (prop-network-contradiction-fns net) h cid)]
             [contradicted?
              (and (not (eq? cfn 'none))   ;; cell has a contradicts? fn
                   (cfn merged))]          ;; the merged value is contradictory
             [net* (struct-copy prop-network net
                     [warm (struct-copy prop-net-warm (prop-network-warm net)
                             [cells new-cells])]
                     [hot (struct-copy prop-net-hot (prop-network-hot net)
                            [worklist new-wl])])])
        (if contradicted?
            (struct-copy prop-network net*
              [warm (struct-copy prop-net-warm (prop-network-warm net*)
                      [contradiction cid])])
            net*))))

;; Replace a cell's value directly, bypassing the merge function.
;; Used by S(-1) retraction to write cleaned values to monotone cells.
;; Retraction is a non-monotone operation — stratification makes it safe
;; (S(-1) fires before S0; S0 reaches a new fixpoint afterwards).
;; Semantics: identical to net-cell-write except no merge-fn application.
;; Still enqueues dependents, checks contradiction, and returns unchanged
;; network if new-val equals old (termination guarantee).
;; No TMS wrapping — retraction operates on raw accumulated cell values.
(define (net-cell-replace net cid new-val)
  (define cells (prop-network-cells net))
  (define h (cell-id-hash cid))
  (define cell (champ-lookup cells h cid))
  (when (eq? cell 'none)
    (error 'net-cell-replace "unknown cell: ~a" cid))
  (define old-val (prop-cell-value cell))
  (if (equal? new-val old-val)
      net  ;; No change — return same network
      (let* ([new-cell (struct-copy prop-cell cell [value new-val])]
             [new-cells (champ-insert cells h cid new-cell)]
             [deps (champ-keys (prop-cell-dependents cell))]
             [new-wl (append deps (prop-network-worklist net))]
             [cfn (champ-lookup (prop-network-contradiction-fns net) h cid)]
             [contradicted?
              (and (not (eq? cfn 'none))
                   (cfn new-val))]
             [net* (struct-copy prop-network net
                     [warm (struct-copy prop-net-warm (prop-network-warm net)
                             [cells new-cells])]
                     [hot (struct-copy prop-net-hot (prop-network-hot net)
                            [worklist new-wl])])])
        (if contradicted?
            (struct-copy prop-network net*
              [warm (struct-copy prop-net-warm (prop-network-warm net*)
                      [contradiction cid])])
            net*))))

;; ========================================
;; TMS Speculation Stack — RETIRED 2026-04-22 (PPN 4C 1A-iii-a-wide Step 1 S1.d)
;; ========================================
;; current-speculation-stack parameter removed. TMS mechanism retired (S1.a-c);
;; speculation-tagging now flows exclusively through current-worldview-bitmask +
;; worldview-cache-cell-id + tagged-cell-value substrate (BSP-LE 2/2B).

;; Phase 6+7: Per-propagator worldview bitmask.
;; When non-zero, net-cell-write uses this bitmask for tagged-cell-value tagging
;; instead of reading the worldview cache cell. This enables concurrent clause
;; propagators on the SAME network: each fire function sets its clause's bitmask,
;; BSP fires them concurrently, writes are tagged distinctly.
;; 0 = no override → net-cell-write reads worldview cache cell as before.
(define current-worldview-bitmask (make-parameter 0))

;; Wrap a fire function to set current-worldview-bitmask before executing.
;; bit-position: integer — the assumption's bit position.
;; Returns a new fire function that parameterizes the bitmask.
(define (wrap-with-worldview fire-fn bit-position)
  (define bitmask (arithmetic-shift 1 bit-position))
  (lambda (net)
    (parameterize ([current-worldview-bitmask bitmask])
      (fire-fn net))))

;; Track 8 C5a: Global scheduler override.
;; When #t, ALL run-to-quiescence calls use BSP scheduling instead of Gauss-Seidel.
;; This is the correct level for a full A/B comparison — it catches every quiescence
;; invocation (unify.rkt, elab-speculation.rkt, bridges, tabling, not just metavar-store).
(define current-use-bsp-scheduler? (make-parameter #t))  ;; PAR Track 1 Phase 5: BSP is the default

;; CALM topology guard: when #t, fire functions must not modify network topology.
;; net-add-propagator and net-new-cell will error during BSP fire rounds.
;; Topology changes require stratum boundaries (stratification).
(define current-bsp-fire-round? (make-parameter #f))

;; BSP-LE Track 2 Phase 2 CORRECTION: current-assumption-viable? REMOVED.
;; Viability is checked ON-NETWORK by reading the decision cell directly
;; in filter-dependents-by-paths. The dependent-entry carries the
;; decision-cell-id — no ambient parameter needed.

;; BSP-LE Track 2B Phase 2c: cell-id 5 = pool configuration.
;; On-network configuration for the BSP worker pool.
;; Carrier: hasheq with keys 'worker-count, 'merge-threshold, 'status.
;; Merge: first-write-wins (configured once per session).
;; Phase 0: written at first BSP round. Self-hosting: on elab-network.
(define pool-config-cell-id (cell-id 5))
(define (pool-config-merge old new) old)  ;; first-write-wins

;; BSP-LE Track 2B Phase 2b: Per-propagator cell-id namespace for parallel fire.
;; During BSP parallel fire, each propagator gets a unique namespace (its worklist
;; index). Cell allocations use high-bit encoding: (prop-index << 32) | local-counter.
;; Avoids cell-id collision when propagators fire in parallel against the same snapshot.
;; 0 = no namespace (construction-time allocation uses sequential next-cell-id).
(define current-cell-id-namespace (make-parameter 0))

;; Phase 2b: Tree-reduce merge threshold. When worklist size >= threshold,
;; use hypercube tree-reduce instead of sequential for/fold for bulk-merge-writes.
;; #f = always sequential (disabled). 0 = always tree-reduce.
;; Phase 2c benchmark: pool executor crossover at N≈256 for fire+merge pipeline.
;; At N=256: pool 1.2x faster. At N=512: pool 1.6x faster. Below 256: sequential wins.
;; Thread-based (Phase 2b) was 9-10x slower at all N. Pool eliminates thread creation
;; overhead but retains dispatch cost (chunk build + semaphore + result collect ~60-140us).
(define current-tree-reduce-threshold (make-parameter 256))

;; B2f Phase 0: Per-quiescence cell-write instrumentation.
;; When non-#f, these are boxes that net-cell-write increments.
;; - write-counter: every net-cell-write call
;; - change-counter: only calls that actually modify the CHAMP (non-eq? merge result)
(define current-quiescence-write-counter (make-parameter #f))
(define current-quiescence-change-counter (make-parameter #f))

;; ========================================
;; Propagator Operations
;; ========================================

;; Add a propagator to the network.
;; input-ids: list of cell-id (cells this propagator reads)
;; output-ids: list of cell-id (cells this propagator may write)
;; fire-fn: (prop-network → prop-network) — pure state transformer
;; Returns: (values new-network prop-id)
;;
;; The propagator is registered as a dependent of each input cell,
;; and scheduled for initial firing on the worklist.
;; PPN Track 4 Phase 1a: #:component-paths is an optional assoc list
;; of (cell-id . path) pairs declaring which PU component a propagator
;; watches for each input cell. If omitted (or a cell-id is not in the
;; assoc), the propagator watches the entire cell (path = #f, backward compat).
;; BSP-LE Track 2 Phase 2: #:assumption is an optional assumption-id.
;; When set, the dependent entry is tagged — the scheduler skips it when
;; the assumption is no longer viable (emergent branch dissolution).
;; Path values are arbitrary keys (symbols, integers, etc.) that correspond
;; to keys in a hasheq PU value. The component path is stored in the cell's
;; dependent set: prop-id → path-or-#f.
(define (net-add-propagator net input-ids output-ids fire-fn
                            #:component-paths [component-paths '()]
                            #:assumption [assumption-id #f]
                            #:decision-cell [decision-cell-id #f]
                            #:flags [flags 0]
                            #:srcloc [srcloc #f])  ;; PPN 4C Phase 1.5: on-network srcloc
  ;; PPN 4C Phase 1f (2026-04-20): structural-enforcement check.
  ;; For each input cell whose domain is classified 'structural, require
  ;; :component-paths declared for that cell. Unclassified domains skip
  ;; (progressive rollout). Value domains skip by definition.
  (enforce-component-paths! net input-ids component-paths)
  ;; PAR Track 1: During BSP fire rounds, propagator creation is allowed
  ;; but the new propagator is NOT scheduled on the worklist. It exists
  ;; in the result-net's propagator CHAMP. fire-and-collect-writes captures
  ;; it via next-prop-id comparison. The topology stratum applies new
  ;; propagators to the canonical network and schedules them.
  (define pid (prop-id (prop-network-next-prop-id net)))
  (define prop (propagator input-ids output-ids fire-fn #f flags srcloc))
  (define ph (prop-id-hash pid))
  ;; CHAMP Performance Phase 7: Owner-ID transient for dependency registration.
  ;; BSP-LE Track 0 Phase 5 attempted hash-table transient here and regressed 44%.
  ;; Owner-ID transients are O(modified paths), making this viable for N=2-3 inputs.
  (define-values (cells-node cells-edit cells-size)
    (champ-transient-owned (prop-network-cells net)))
  (define sb (box cells-size))
  (define final-node
    (for/fold ([cn cells-node]) ([cid (in-list input-ids)])
      (define ch (cell-id-hash cid))
      (define cell (champ-lookup (prop-network-cells net) ch cid))
      (if (eq? cell 'none)
          cn  ;; unknown cell — skip (defensive)
          ;; PPN Track 4B Phase 0a: collect ALL matching paths for this cell-id.
          ;; A propagator may watch multiple component paths on the same cell
          ;; (e.g., app propagator watching both func-pos and arg-pos).
          ;; The old code used `assoc` which found only the first match.
          (let* ([paths (let ([matches (filter (lambda (pair) (equal? cid (car pair)))
                                              component-paths)])
                          (if (null? matches)
                              #f  ;; no paths declared for this cell → watch all
                              (map cdr matches)))]
                 [entry (dependent-entry paths assumption-id decision-cell-id)]
                 [new-deps (champ-insert (prop-cell-dependents cell)
                                          ph pid entry)])
            (define-values (cn* _)
              (tchamp-insert-owned! cn sb ch cid
                                    (struct-copy prop-cell cell
                                      [dependents new-deps])
                                    cells-edit))
            cn*))))
  (define new-cells (tchamp-freeze-owned final-node (unbox sb) cells-edit))
  (values
   (struct-copy prop-network net
     [warm (struct-copy prop-net-warm (prop-network-warm net)
             [cells new-cells])]
     [cold (struct-copy prop-net-cold (prop-network-cold net)
             [propagators (champ-insert (prop-network-propagators net) ph pid prop)]
             [next-prop-id (+ 1 (prop-network-next-prop-id net))])]
     ;; Schedule initial firing — but NOT during BSP fire rounds.
     ;; During BSP, new propagators are deferred to the topology stratum.
     [hot (if (current-bsp-fire-round?)
              (prop-network-hot net)  ;; Don't modify worklist during BSP
              (struct-copy prop-net-hot (prop-network-hot net)
                [worklist (cons pid (prop-network-worklist net))]))])
   pid))

;; ========================================
;; Fire-Once Propagator (BSP-LE Track 2 Phase 5, moved from typing-propagators.rkt)
;; ========================================
;;
;; Phase 5a: Fire-once as a scheduler-level concept.
;; PROP-FIRE-ONCE flag enables scheduler-level once-semantics:
;; - Fired-set: skip already-fired propagators at worklist dedup (zero cost)
;; - Self-clearing: remove from dependents after fire (no future enqueuing)
;; - Tier 1 detection: all fire-once + empty-inputs → single-pass flush
;; Empty inputs → PROP-EMPTY-INPUTS (eligible for direct-fire, no snapshot).
;; No closure wrapper — the scheduler handles all fire-once semantics.
;;
;; General pattern for propagators that produce output exactly once:
;; nogood narrowers, contradiction detectors, type-writes, ground unify (R3),
;; fact-row writes (R2), guard evaluators (Phase 3).
(define (net-add-fire-once-propagator net inputs outputs fire-fn
                                      [_watched-cid #f]  ;; legacy positional param (ignored)
                                      #:component-paths [cpaths '()]
                                      #:assumption [assumption-id #f]
                                      #:decision-cell [decision-cell-id #f]
                                      #:srcloc [srcloc #f])  ;; PPN 4C Phase 1.5
  ;; Flags: scheduler implements fire-once. No closure wrapper.
  (define flags (bitwise-ior PROP-FIRE-ONCE
                             (if (null? inputs) PROP-EMPTY-INPUTS 0)))
  (define-values (net* pid)
    (net-add-propagator net inputs outputs fire-fn
                        #:component-paths cpaths
                        #:assumption assumption-id
                        #:decision-cell decision-cell-id
                        #:flags flags
                        #:srcloc srcloc))
  (values net* pid))

;; ========================================
;; Branch PU (BSP-LE Track 2 Phase 2)
;; ========================================
;;
;; Creates a branch Pocket Universe by forking the parent network.
;; CHAMP structural sharing: branch starts as reference to parent's cells/propagators.
;; Branch-local writes diverge at the write point; parent is unmodified.
;;
;; Phase 6a (D.11): Each PU gets its own worldview via eager cache write.
;; The fork's worldview cache cell (cell-id 1) is set to the branch's
;; assumption bitmask. All cell writes in the fork are auto-tagged with
;; this bitmask. Net-cell-read in the fork returns entries matching
;; this branch's worldview. Commit/retract emergent from filtering.
;;
;; Propagators installed on the branch use #:assumption to tag their dependent
;; entries. The scheduler's filter-dependents-by-paths checks viability — when
;; the assumption is eliminated from the decision cell, the branch's propagators
;; become invisible (emergent dissolution, no explicit pu-drop).
;; bit-position: integer — the assumption's bit position for worldview bitmask.
;;   Callers with assumption-id structs pass (assumption-id-n aid).
;;   #f = no worldview initialization (legacy, backward compat with Phase 2 tests).
(define (make-branch-pu parent-net assumption-id [bit-position #f])
  (define forked (fork-prop-network parent-net))
  (if bit-position
      ;; Eager worldview: set fork's cache to this branch's assumption bit.
      ;; All cell writes in the fork are auto-tagged with this bitmask.
      (let ([bitmask (arithmetic-shift 1 bit-position)])
        (values (net-cell-write forked worldview-cache-cell-id bitmask) assumption-id))
      ;; Legacy: no worldview initialization (Phase 2 tests don't use tagged cells)
      (values forked assumption-id)))

;; A1 (BSP-LE 2B addendum, 2026-04-16): `install-per-nogood-infrastructure`
;; deleted as dead code. It was only called by the nogood-install-request
;; topology handler, which itself had zero producers (struct defined but no
;; constructor calls). BSP-LE Track 2 Phase 3 designed per-nogood infrastructure
;; but the producer path was never wired up (nogoods are instead written
;; directly via `nogood-add` from ATMS S1 handlers). Removed as A1 audit finding.

;; ========================================
;; Broadcast Propagator (BSP-LE Track 2 Phase 1B)
;; ========================================
;;
;; Installs ONE propagator that processes N items internally.
;; ONE fire, ONE diff, ONE merge — constant infrastructure overhead.
;;
;; The fire function: reads input cells ONCE (shared), processes ALL items
;; via item-fn, merges results, writes ONE value to the output cell.
;; The broadcast-profile metadata enables the scheduler to decompose
;; the N items across parallel threads when N exceeds the threshold.
;;
;; A/B data: broadcast is 2.3× faster at N=3, 75.6× at N=100 vs
;; N-propagator model. Infrastructure overhead is constant (~2.7μs),
;; not linear in N.
;;
;; This IS a polynomial functor: fan-out depends on `items` (data-indexed).
;; The broadcast-profile carries the arity for scheduler decomposition.
;;
;; net: prop-network
;; input-cids: (listof cell-id) — cells the propagator reads
;; output-cid: cell-id — accumulator cell for merged results
;; items: (listof any) — data elements to process (e.g., clauses)
;; item-fn: (any (listof value) → result-or-#f) — pure function per item
;; result-merge-fn: (any any → any) — merge for results (typically append/set-union)
;; Returns: (values new-network prop-id)
;;
;; Precondition (3.2): input cells should be stable (resolved, non-bot)
;; before the broadcast fires. Results accumulate monotonically.
(define (net-add-broadcast-propagator net input-cids output-cid
                                      items item-fn result-merge-fn
                                      #:component-paths [component-paths '()]
                                      #:assumption [assumption-id #f]
                                      #:decision-cell [decision-cell-id #f]
                                      #:srcloc [srcloc #f])  ;; PPN 4C Phase 1.5
  (define profile (broadcast-profile items item-fn result-merge-fn))
  (define fire-fn
    (lambda (net)
      ;; Read inputs ONCE — shared across all items
      (define input-values
        (for/list ([cid (in-list input-cids)])
          (net-cell-read net cid)))
      ;; Process all items — each is independent
      ;; Today: sequential loop. The broadcast-profile metadata enables
      ;; the scheduler to decompose this into parallel chunks.
      (define results
        (for/fold ([acc '()])
                  ([item (in-list items)])
          (define result (item-fn item input-values))
          (if result
              (result-merge-fn acc result)
              acc)))
      ;; ONE write with merged results
      (if (null? results)
          net
          (net-cell-write net output-cid results))))
  ;; Install ONE propagator with the broadcast profile
  (define pid (prop-id (prop-network-next-prop-id net)))
  (define prop (propagator input-cids (list output-cid) fire-fn profile 0 srcloc))
  (define ph (prop-id-hash pid))
  ;; Register propagator + dependencies (same as net-add-propagator but with profile)
  ;; BSP-LE Track 2 Phase 5.1b: component-paths + assumption + decision-cell support.
  ;; Same dependent-entry construction as net-add-propagator.
  (define-values (cells-node cells-edit cells-size)
    (champ-transient-owned (prop-network-cells net)))
  (define sb (box cells-size))
  (define final-node
    (for/fold ([cn cells-node]) ([cid (in-list input-cids)])
      (define ch (cell-id-hash cid))
      (define cell (champ-lookup (prop-network-cells net) ch cid))
      (if (eq? cell 'none) cn
          (let* ([paths (let ([matches (filter (lambda (pair) (equal? cid (car pair)))
                                              component-paths)])
                          (if (null? matches)
                              #f  ;; no paths declared for this cell → watch all
                              (map cdr matches)))]
                 [new-deps (champ-insert (prop-cell-dependents cell) ph pid
                                         (dependent-entry paths assumption-id decision-cell-id))])
            (define-values (cn* _)
              (tchamp-insert-owned! cn sb ch cid
                                    (struct-copy prop-cell cell [dependents new-deps])
                                    cells-edit))
            cn*))))
  (define new-cells (tchamp-freeze-owned final-node (unbox sb) cells-edit))
  (values
   (struct-copy prop-network net
     [warm (struct-copy prop-net-warm (prop-network-warm net)
             [cells new-cells])]
     [cold (struct-copy prop-net-cold (prop-network-cold net)
             [propagators (champ-insert (prop-network-propagators net) ph pid prop)]
             [next-prop-id (+ 1 (prop-network-next-prop-id net))])]
     [hot (if (current-bsp-fire-round?)
              (prop-network-hot net)
              (struct-copy prop-net-hot (prop-network-hot net)
                [worklist (cons pid (prop-network-worklist net))]))])
   pid))

;; ========================================
;; Parallel-Map Propagator (Phase 1A — DEPRECATED, use broadcast)
;; ========================================
;; Retained for backward compatibility with Phase 1A tests.
;; Installs N separate propagators. Use net-add-broadcast-propagator instead.
(define (net-add-parallel-map-propagator net input-cids output-cid
                                         items make-fire-fn)
  (for/fold ([n net] [pids '()])
            ([item (in-list items)])
    (define fire-fn (make-fire-fn item))
    (define-values (n* pid)
      (net-add-propagator n input-cids (list output-cid) fire-fn))
    (values n* (cons pid pids))))

;; ========================================
;; Threshold Propagators (Phase 2.5b)
;; ========================================

;; Create a fire-fn that only executes body-fn when the watched cell's
;; value satisfies the threshold? predicate. When the threshold is not
;; met, returns net unchanged (no-op).
;;
;; threshold?: (value → Bool) — typically (lambda (v) (leq? threshold-val v))
;; body-fn:   (prop-network → prop-network) — the actual propagator logic
;;
;; For monotonic lattices, once the threshold is met it stays met,
;; so the body fires at most once after the threshold crossing.
(define (make-threshold-fire-fn watched-cid threshold? body-fn)
  (lambda (net)
    (define val (net-cell-read net watched-cid))
    (if (threshold? val)
        (body-fn net)
        net)))

;; Create a fire-fn that only executes body-fn when ALL conditions
;; are satisfied. Each condition is (cons cell-id predicate).
;;
;; conditions: (listof (cons cell-id (value → Bool)))
;; body-fn:    (prop-network → prop-network)
;;
;; Used for multi-input gates: "fire only when A >= 3 AND B is non-empty".
(define (make-barrier-fire-fn conditions body-fn)
  (lambda (net)
    (if (for/and ([c (in-list conditions)])
          ((cdr c) (net-cell-read net (car c))))
        (body-fn net)
        net)))

;; Add a threshold propagator: watches watched-cid for a condition,
;; with additional input/output ids for the body propagator.
;; The watched cell is automatically included in input-ids.
;; Returns: (values new-network prop-id)
(define (net-add-threshold net watched-cid threshold?
                           input-ids output-ids body-fn)
  (define all-inputs
    (if (member watched-cid input-ids)
        input-ids
        (cons watched-cid input-ids)))
  (net-add-propagator net all-inputs output-ids
    (make-threshold-fire-fn watched-cid threshold? body-fn)))

;; Add a barrier propagator: fires body-fn only when all conditions met.
;; Condition cell-ids are automatically included in input-ids.
;; conditions: (listof (cons cell-id (value → Bool)))
;; Returns: (values new-network prop-id)
(define (net-add-barrier net conditions extra-input-ids output-ids body-fn)
  (define condition-cids (map car conditions))
  ;; Merge condition cell-ids with extra input-ids (dedup via CHAMP)
  (define all-inputs
    (let loop ([todo (append condition-cids extra-input-ids)]
               [seen champ-empty]
               [acc '()])
      (cond
        [(null? todo) (reverse acc)]
        [else
         (define cid (car todo))
         (define h (cell-id-hash cid))
         (if (champ-has-key? seen h cid)
             (loop (cdr todo) seen acc)
             (loop (cdr todo)
                   (champ-insert seen h cid #t)
                   (cons cid acc)))])))
  (net-add-propagator net all-inputs output-ids
    (make-barrier-fire-fn conditions body-fn)))

;; ========================================
;; Scheduler: Gauss-Seidel (Sequential)
;; ========================================

;; Run the network to quiescence (fixed point).
;; Pure tail-recursive loop that fires propagators from the worklist.
;; Stops when: (1) contradiction detected, (2) fuel exhausted, or
;; (3) worklist empty (quiescence reached).
;;
;; When current-bsp-observer is set, emits one bsp-round per quiescence
;; call summarizing all propagator firings and cell diffs from initial
;; to final state.
(define (run-to-quiescence net)
  ;; Track 8 C5a: global BSP override for full A/B benchmarking.
  ;; Redirects ALL quiescence calls (unify, speculation, bridges, etc.) to BSP.
  (if (current-use-bsp-scheduler?)
      (run-to-quiescence-bsp net)
      (let ([observer (current-bsp-observer)])
        (if (not observer)
            ;; Fast path: no tracing overhead
            (run-to-quiescence-inner net)
            ;; Traced path: capture diffs between initial and final state
            (let* ([initial net]
                   [result (run-to-quiescence-inner/traced net)]
                   [final (car result)]
                   [fired-pids (cdr result)])
              (when (pair? fired-pids)
                ;; Compute cell diffs by comparing initial vs final cell values
                (define cell-ids (champ-keys (prop-network-cells final)))
                (define diffs
                  (for/fold ([acc '()])
                            ([cid (in-list cell-ids)])
                    (define old-cell (champ-lookup (prop-network-cells initial)
                                                  (cell-id-hash cid) cid))
                    (define new-cell (champ-lookup (prop-network-cells final)
                                                  (cell-id-hash cid) cid))
                    (cond
                      [(eq? old-cell 'none) ;; new cell — diff from bot
                       (cons (cell-diff cid 'bot (prop-cell-value new-cell)
                                        (if (pair? fired-pids) (car fired-pids) (prop-id 0)))
                             acc)]
                      [(eq? new-cell 'none) acc] ;; shouldn't happen
                      [(equal? (prop-cell-value old-cell) (prop-cell-value new-cell)) acc]
                      [else
                       (cons (cell-diff cid (prop-cell-value old-cell) (prop-cell-value new-cell)
                                        (if (pair? fired-pids) (car fired-pids) (prop-id 0)))
                             acc)])))
                (observer (bsp-round 0 final (reverse diffs) fired-pids
                                     (prop-network-contradiction final) '())))
              final)))))

;; Inner loop: no tracing.
;; BSP-LE Track 0 Phase 3c: mutable worklist/fuel drain pattern.
;; Strip hot fields into mutable boxes before the loop. Propagator fire
;; functions write new dependents to the network's worklist via net-cell-write;
;; we drain those into the mutable box after each fire. Zero struct-copy
;; per iteration for worklist/fuel management.
(define (run-to-quiescence-inner net)
  ;; Fast path: nothing to do — return same object (eq? identity).
  (cond
    [(prop-network-contradiction net) net]
    [(<= (prop-network-fuel net) 0) net]
    [(null? (prop-network-worklist net)) net]
    [else (run-to-quiescence-drain net)]))

;; Mutable drain loop — only entered when there IS work to do.
(define (run-to-quiescence-drain net)
  (define wl (box (prop-network-worklist net)))
  (define remaining-fuel (box (prop-network-fuel net)))
  ;; B2f Phase 0: cell-write instrumentation
  (define write-count (box 0))
  (define change-count (box 0))
  ;; Strip worklist/fuel from network — propagators see an empty worklist.
  ;; net-cell-write appends new dependents to the network's own worklist field;
  ;; we drain those into the box after each fire.
  (define net0 (struct-copy prop-network net
                 [hot (prop-net-hot '() 0)]))
  (define (finalize n)
    ;; B2f Phase 0: emit stats if non-trivial
    (define wc (unbox write-count))
    (define cc (unbox change-count))
    (when (> wc 0)
      (perf-record-quiescence-writes! wc cc))
    ;; Reconstitute the hot fields from the mutable boxes.
    (struct-copy prop-network n
      [hot (prop-net-hot (unbox wl) (unbox remaining-fuel))]))
  (parameterize ([current-quiescence-write-counter write-count]
                 [current-quiescence-change-counter change-count])
    (let loop ([net net0])
      (cond
        [(prop-network-contradiction net) (finalize net)]
        [(<= (unbox remaining-fuel) 0) (finalize net)]
        [(null? (unbox wl)) (finalize net)]
        [else
         (define pid (car (unbox wl)))
         (set-box! wl (cdr (unbox wl)))
         (set-box! remaining-fuel (sub1 (unbox remaining-fuel)))
         (define prop (champ-lookup (prop-network-propagators net)
                                     (prop-id-hash pid) pid))
         (if (eq? prop 'none)
             (loop net)
             (let ([net* (fire-propagator prop net)])  ;; PPN 4C Phase 1.5: wraps with current-source-loc
               (perf-inc-prop-firing!)  ;; Track 7 Phase 0b
               ;; Drain: fire fn may have added to net*'s worklist via net-cell-write.
               ;; Move those new entries into our mutable box.
               (define new-wl-entries (prop-network-worklist net*))
               (unless (null? new-wl-entries)
                 (set-box! wl (append new-wl-entries (unbox wl))))
               ;; Clear net*'s worklist so it doesn't accumulate across iterations.
               (loop (struct-copy prop-network net*
                       [hot (prop-net-hot '() 0)]))))]))))

;; Inner loop with tracing: returns (cons final-net fired-pids-list).
;; Same mutable worklist/fuel drain pattern as run-to-quiescence-inner.
(define (run-to-quiescence-inner/traced net)
  (define wl (box (prop-network-worklist net)))
  (define remaining-fuel (box (prop-network-fuel net)))
  (define net0 (struct-copy prop-network net
                 [hot (prop-net-hot '() 0)]))
  (define (finalize n fired)
    (cons (struct-copy prop-network n
            [hot (prop-net-hot (unbox wl) (unbox remaining-fuel))])
          (reverse fired)))
  (let loop ([net net0] [fired '()])
    (cond
      [(prop-network-contradiction net) (finalize net fired)]
      [(<= (unbox remaining-fuel) 0) (finalize net fired)]
      [(null? (unbox wl)) (finalize net fired)]
      [else
       (define pid (car (unbox wl)))
       (set-box! wl (cdr (unbox wl)))
       (set-box! remaining-fuel (sub1 (unbox remaining-fuel)))
       (define prop (champ-lookup (prop-network-propagators net)
                                   (prop-id-hash pid) pid))
       (if (eq? prop 'none)
           (loop net fired)
           (let ([net* (fire-propagator prop net)])  ;; PPN 4C Phase 1.5
             (define new-wl-entries (prop-network-worklist net*))
             (unless (null? new-wl-entries)
               (set-box! wl (append new-wl-entries (unbox wl))))
             (loop (struct-copy prop-network net*
                     [hot (prop-net-hot '() 0)])
                   (cons pid fired))))])))

;; ========================================
;; Scheduler: BSP / Jacobi (Parallel-Ready) (Phase 2.5a)
;; ========================================
;;
;; Bulk-Synchronous Parallel scheduler:
;;   Round k: fire ALL worklist propagators against snapshot(k-1)
;;   Collect writes by diffing output cells
;;   Bulk-merge all writes into snapshot(k-1) → snapshot(k)
;;
;; Same fixpoint as Gauss-Seidel, guaranteed by:
;;   - Lattice join is commutative and associative
;;   - All propagators are monotone
;;   - CALM theorem: monotone + commutative merge = confluent
;;
;; Tradeoff vs Gauss-Seidel:
;;   - May need more rounds for chains (Jacobi: N rounds for chain of N)
;;   - Each round is embarrassingly parallel
;;   - No intermediate-state dependencies between propagators in same round
;;
;; Executor parameter: sequential-fire-all (default) or make-parallel-fire-all
;; Contract: fire-fns MUST be pure for parallel execution.
;;           Propagator outputs list MUST be complete (BSP only diffs listed outputs).

;; Deduplicate prop-ids using CHAMP as a set (no racket/list dependency).
(define (dedup-pids pids)
  (let loop ([todo pids]
             [seen champ-empty]
             [acc '()])
    (cond
      [(null? todo) (reverse acc)]
      [else
       (define pid (car todo))
       (define h (prop-id-hash pid))
       (if (champ-has-key? seen h pid)
           (loop (cdr todo) seen acc)
           (loop (cdr todo)
                 (champ-insert seen h pid #t)
                 (cons pid acc)))])))

;; Fire a single propagator against snapshot-net, return list of
;; (cell-id . new-merged-value) pairs for output cells that changed.
;; Does NOT carry over worklist mutations — purely observational.
;;
;; Contract: outputs must be complete. Writes to unlisted cells are
;; invisible in BSP mode.
;; PAR Track 1 D.3: fire-result bundles value writes AND new cells.
;; New cells are captured structurally via next-cell-id comparison.
(struct fire-result (value-writes new-cells new-propagators contradiction undeclared-writes) #:transparent)

(define (fire-and-collect-writes snapshot-net pid [namespace-idx 0])
  (define prop (champ-lookup (prop-network-propagators snapshot-net)
                              (prop-id-hash pid) pid))
  (when (eq? prop 'none)
    (error 'fire-and-collect-writes "unknown propagator: ~a" pid))
  (define snapshot-next-id (prop-network-next-cell-id snapshot-net))
  ;; Fire propagator against snapshot (with CALM topology guard).
  ;; Phase 2b: set cell-id namespace for parallel-safe cell allocation.
  (define result-net
    (parameterize ([current-bsp-fire-round? #t]
                   [current-cell-id-namespace namespace-idx])
      (fire-propagator prop snapshot-net)))  ;; PPN 4C Phase 1.5
  (define result-next-id (prop-network-next-cell-id result-net))
  ;; Diff output cells for value writes (correct delta for merge-based cells).
  ;; A1: previously added decomp-request-cell-id unconditionally as a catch-all
  ;; for topology writes. No longer needed — topology cells are each propagator's
  ;; declared output, and undeclared-writes (below) catches any leaked writes.
  (define output-cids (propagator-outputs prop))
  ;; Phase 6+7 fix: use net-cell-read-raw for diffing (not net-cell-read).
  ;; net-cell-read applies worldview filtering (tagged-cell-value bitmask).
  ;; After the fire function returns, current-worldview-bitmask is 0,
  ;; making tagged entries invisible to the diff. Raw read sees the full
  ;; tagged-cell-value including entries — the diff captures the actual change.
  (define value-writes
    (for/fold ([writes '()])
              ([cid (in-list output-cids)])
      (define old (net-cell-read-raw snapshot-net cid))
      (define new (net-cell-read-raw result-net cid))
      (if (equal? old new)
          writes
          (cons (cons cid new) writes))))
  ;; Also check for undeclared writes (e.g., contradiction writes to input cells).
  ;; These are captured as direct-set operations (bypass merge in bulk-merge-writes)
  ;; to avoid double-merging with non-idempotent merge functions like append.
  (define undeclared-writes
    (let ([snap-cells (prop-network-cells snapshot-net)]
          [result-cells (prop-network-cells result-net)]
          [output-set (for/hasheq ([cid (in-list output-cids)]) (values cid #t))])
      (if (eq? snap-cells result-cells)
          '()
          (champ-fold/hash
           result-cells
           (lambda (h cid cell acc)
             (cond
               [(hash-has-key? output-set cid) acc]  ;; Already in value-writes
               [(< (cell-id-n cid) snapshot-next-id) ;; Existing cell, not new
                (let ([old-cell (champ-lookup snap-cells h cid)])
                  (if (eq? old-cell 'none)
                      acc
                      (let ([old-val (prop-cell-value old-cell)]
                            [new-val (prop-cell-value cell)])
                        (if (equal? old-val new-val)
                            acc
                            (cons (cons cid new-val) acc)))))]
               [else acc]))
           '()))))  ;; Phase 2b: Capture new cells via CHAMP diff (replaces range-based scan).
  ;; With per-propagator cell-id namespaces, range scanning doesn't work —
  ;; namespaced IDs are sparse. CHAMP diff finds cells in result not in snapshot.
  ;; O(new cells) via structural comparison of persistent hash-array-mapped tries.
  (define new-cells
    (let ([snap-cells (prop-network-cells snapshot-net)]
          [result-cells (prop-network-cells result-net)])
      (if (eq? snap-cells result-cells)
          '()  ;; No new cells — common case, zero overhead (same CHAMP node)
          (champ-fold/hash
           result-cells
           (lambda (h cid cell acc)
             (if (not (eq? 'none (champ-lookup snap-cells h cid)))
                 acc  ;; Cell existed in snapshot — not new
                 ;; New cell: extract merge-fn, contra-fn, widen-fn, cell-dir
                 (let ([merge-fn (champ-lookup (prop-network-merge-fns result-net) h cid)]
                       [contra-fn (champ-lookup (prop-network-contradiction-fns result-net) h cid)]
                       [widen-fn (champ-lookup (prop-network-widen-fns result-net) h cid)]
                       [cell-dir (champ-lookup (prop-network-cell-dirs result-net) h cid)])
                   (cons (list cid cell merge-fn contra-fn widen-fn cell-dir) acc))))
           '()))))
  ;; PAR Track 1: Capture new propagators via next-prop-id comparison.
  ;; Propagators created during BSP are NOT on the worklist (deferred).
  ;; The topology stratum adds them to the canonical network and schedules them.
  (define snapshot-next-prop-id (prop-network-next-prop-id snapshot-net))
  (define result-next-prop-id (prop-network-next-prop-id result-net))
  (define new-propagators
    (if (= snapshot-next-prop-id result-next-prop-id)
        '()
        (for/list ([i (in-range snapshot-next-prop-id result-next-prop-id)])
          (define pid (prop-id i))
          (define prop (champ-lookup (prop-network-propagators result-net)
                                     (prop-id-hash pid) pid))
          (list pid prop))))
  ;; Capture contradiction if result-net has one that snapshot didn't
  (define new-contradiction
    (and (prop-network-contradiction result-net)
         (not (prop-network-contradiction snapshot-net))
         (prop-network-contradiction result-net)))
  (fire-result value-writes new-cells new-propagators new-contradiction undeclared-writes))

;; Apply collected writes from all propagators to a network.
;; net-cell-write handles merge, dependent enqueuing, and contradiction.
;; Multiple writes to the same cell from different propagators are fine —
;; lattice join is commutative and associative, so order doesn't matter.
;; PAR Track 1 D.3: also applies new cells from fire-result structs.
(define (bulk-merge-writes net all-results)
  (for/fold ([net net])
            ([result (in-list all-results)])
    ;; Handle both old-style write lists and new fire-result structs
    (define-values (writes new-cells new-props contradiction undecl-writes)
      (if (fire-result? result)
          (values (fire-result-value-writes result)
                  (fire-result-new-cells result)
                  (fire-result-new-propagators result)
                  (fire-result-contradiction result)
                  (fire-result-undeclared-writes result))
          (values result '() '() #f '())))
    ;; Apply new cells first (they may be referenced by value writes)
    (define net-with-cells
      (for/fold ([n net])
                ([cell-spec (in-list new-cells)])
        (define cid (car cell-spec))
        (define cell (cadr cell-spec))
        (define merge-fn (caddr cell-spec))
        (define contra-fn (cadddr cell-spec))
        (define widen-fn (list-ref cell-spec 4))
        (define cell-dir (list-ref cell-spec 5))
        (define h (cell-id-hash cid))
        ;; Only add if cell doesn't already exist (idempotent)
        (if (not (eq? 'none (champ-lookup (prop-network-cells n) h cid)))
            n  ;; Cell already exists (from another propagator in same round)
            (let* ([cells* (champ-insert (prop-network-cells n) h cid cell)]
                   [merges* (champ-insert (prop-network-merge-fns n) h cid merge-fn)]
                   [contras* (if (eq? contra-fn 'none)
                                 (prop-network-contradiction-fns n)
                                 (champ-insert (prop-network-contradiction-fns n) h cid contra-fn))]
                   [widens* (if (eq? widen-fn 'none)
                                (prop-network-widen-fns n)
                                (champ-insert (prop-network-widen-fns n) h cid widen-fn))]
                   [dirs* (if (eq? cell-dir 'none)
                              (prop-network-cell-dirs n)
                              (champ-insert (prop-network-cell-dirs n) h cid cell-dir))])
              (struct-copy prop-network n
                [warm (struct-copy prop-net-warm (prop-network-warm n)
                        [cells cells*])]
                [cold (struct-copy prop-net-cold (prop-network-cold n)
                        [merge-fns merges*]
                        [contradiction-fns contras*]
                        [widen-fns widens*]
                        [cell-dirs dirs*]
                        [next-cell-id (max (prop-network-next-cell-id n)
                                           (+ (cell-id-n cid) 1))])])))))
    ;; Then apply value writes
    (define net-with-values
      (for/fold ([n net-with-cells])
                ([w (in-list writes)])
        (net-cell-write n (car w) (cdr w))))
    ;; Apply undeclared writes (e.g., contradiction writes to input cells).
    ;; These use net-cell-reset + manual dependent enqueue to avoid double-merge.
    (define net-with-undeclared
      (for/fold ([n net-with-values])
                ([w (in-list undecl-writes)])
        (define cid (car w))
        (define new-val (cdr w))
        (define h (cell-id-hash cid))
        (define cell (champ-lookup (prop-network-cells n) h cid))
        (if (eq? cell 'none) n
            (let* ([old-val (prop-cell-value cell)]
                   ;; Skip if no change
                   [_ (if (equal? old-val new-val) (void) (void))])
              (if (equal? old-val new-val) n
                  (let* ([new-cell (struct-copy prop-cell cell [value new-val])]
                         [new-cells (champ-insert (prop-network-cells n) h cid new-cell)]
                         [deps (champ-keys (prop-cell-dependents cell))]
                         [new-wl (append deps (prop-network-worklist n))]
                         ;; Check contradiction
                         [cfn (champ-lookup (prop-network-contradiction-fns n) h cid)]
                         [contradicted? (and (not (eq? cfn 'none)) (cfn new-val))])
                    (struct-copy prop-network n
                      [warm (struct-copy prop-net-warm (prop-network-warm n)
                              [cells new-cells]
                              [contradiction (or (prop-network-contradiction n)
                                                 (and contradicted? cid))])]
                      [hot (struct-copy prop-net-hot (prop-network-hot n)
                             [worklist new-wl])])))))))
    ;; Apply direct contradiction if fire function set it via struct-copy
    (define net-with-contradiction
      (if (and contradiction (not (prop-network-contradiction net-with-undeclared)))
          (struct-copy prop-network net-with-undeclared
            [warm (struct-copy prop-net-warm (prop-network-warm net-with-undeclared)
                    [contradiction contradiction])])
          net-with-undeclared))
    ;; New propagators are NOT applied here — they're collected and
    ;; applied by the topology stratum via net-add-propagator (which
    ;; handles dependency registration correctly).
    net-with-contradiction))

;; Collect all deferred propagators from fire results.
;; Returns list of (list input-ids output-ids fire-fn) specs.
(define (collect-deferred-propagators all-results)
  (for*/list ([result (in-list all-results)]
              #:when (fire-result? result)
              [prop-spec (in-list (fire-result-new-propagators result))]
              #:when (and (pair? prop-spec) (cadr prop-spec) (not (eq? (cadr prop-spec) 'none))))
    (define prop (cadr prop-spec))
    (list (propagator-inputs prop) (propagator-outputs prop) (propagator-fire-fn prop))))


;; ========================================
;; Phase 2b: Pairwise Write-Set Combination (Hypercube All-Reduce)
;; ========================================
;;
;; Combines two fire-results into one merged fire-result.
;; The combined result has the same effect as applying both sequentially.
;; Cell merge functions are associative+commutative → order doesn't matter.
;; This is the pairwise merge operation in the hypercube all-reduce tree.

(define (merge-fire-results a b)
  (cond
    [(not (fire-result? a)) b]
    [(not (fire-result? b)) a]
    [else
     (fire-result
      ;; Value writes: concatenate (merge fns handle ordering)
      (append (fire-result-value-writes a) (fire-result-value-writes b))
      ;; New cells: concatenate (namespaced IDs prevent collision)
      (append (fire-result-new-cells a) (fire-result-new-cells b))
      ;; New propagators: concatenate
      (append (fire-result-new-propagators a) (fire-result-new-propagators b))
      ;; Contradiction: first non-#f wins
      (or (fire-result-contradiction a) (fire-result-contradiction b))
      ;; Undeclared writes: concatenate
      (append (fire-result-undeclared-writes a) (fire-result-undeclared-writes b)))]))

;; Tree-reduce T fire-results via pairwise combination.
;; log₂(T) rounds, each round T/2 independent merges.
;; Phase 0: sequential tree recursion. Self-hosted: parallel pairwise.
;; Parallel version: each pairwise merge in a round runs on a separate thread.
;; Returns: single merged fire-result (or #f for empty input).
(define (tree-reduce-fire-results results [parallel? #f])
  (cond
    [(null? results) #f]
    [(null? (cdr results)) (car results)]
    [else
     (if parallel?
         ;; Parallel: pairwise merges via threads
         (let loop ([rs results])
           (cond
             [(null? (cdr rs)) (car rs)]
             [else
              ;; Pair up, merge in parallel
              (define pairs (pair-up rs))
              (define merged
                (map (lambda (pair)
                       (if (cdr pair)
                           (let ([ch (make-channel)])
                             (thread (lambda ()
                                       (channel-put ch (merge-fire-results (car pair) (cdr pair)))))
                             ch)
                           (car pair)))  ;; odd element — pass through
                     pairs))
              ;; Collect results from threads
              (define collected
                (map (lambda (m)
                       (if (channel? m) (channel-get m) m))
                     merged))
              (loop collected)]))
         ;; Sequential: recursive pairwise
         (let loop ([rs results])
           (cond
             [(null? (cdr rs)) (car rs)]
             [else
              (define pairs (pair-up rs))
              (define merged
                (map (lambda (pair)
                       (if (cdr pair)
                           (merge-fire-results (car pair) (cdr pair))
                           (car pair)))
                     pairs))
              (loop merged)])))]))

;; Helper: pair up a list into (cons a b) pairs. Odd-length: last element paired with #f.
(define (pair-up lst)
  (cond
    [(null? lst) '()]
    [(null? (cdr lst)) (list (cons (car lst) #f))]
    [else (cons (cons (car lst) (cadr lst))
                (pair-up (cddr lst)))]))

;; Fire all propagators sequentially against the same snapshot.
;; Returns a list of fire-results, one per propagator.
;; Phase 2b: each propagator gets a namespace index for parallel-safe cell allocation.
(define (sequential-fire-all snapshot-net pids)
  (for/list ([pid (in-list pids)]
             [idx (in-naturals 1)])  ;; namespace 1+ (0 = construction-time)
    (fire-and-collect-writes snapshot-net pid idx)))

;; A1 (BSP-LE 2B addendum, 2026-04-16): `register-topology-handler!` and its
;; try-each handler chain infrastructure (topology-handlers box,
;; process-topology-request, special-cased shared-cell BSP iteration) retired.
;; All topology handlers migrated to per-subsystem stratum handlers on their
;; own request cells (cell-IDs 6-9), registered via register-stratum-handler!
;; with :tier 'topology. BSP outer loop's tiered processing handles them
;; uniformly with other strata. See stratification.md for the general pattern.

;; BSP-LE Track 2B Phase R4 + A1: General stratum handler infrastructure.
;; Each stratum is a (list request-cell-id handler-fn tier) entry.
;;   request-cell-id: well-known cell-id; handler reads cell value, resets to init
;;   handler-fn: (prop-network cell-value) → prop-network
;;     Receives the network and the request cell's current value (set or hasheq
;;     depending on the stratum's cell type). Returns updated network.
;;   tier: 'topology (mutates network structure — runs FIRST after S0 quiesces)
;;       | 'value    (computes/validates values — runs after topology tier)
;;
;; BSP outer loop: S0 → topology-tier strata → (S0 restart if new worklist) →
;; value-tier strata → (S0 restart if new worklist) → fixpoint.
;;
;; A1: topology tier exists because topology changes (new cells, new propagators)
;; must be observable by subsequent strata. Value tier (S1 NAF, etc.) runs after
;; topology is stable so its fork sees the complete network.
(define stratum-handlers (box '()))

(define (register-stratum-handler! request-cell-id handler-fn
                                   #:tier [tier 'value]
                                   #:reset-value [reset-value (hasheq)])
  (unless (memq tier '(topology value))
    (error 'register-stratum-handler! "tier must be 'topology or 'value, got ~a" tier))
  (set-box! stratum-handlers
            (append (unbox stratum-handlers)
                    (list (list request-cell-id handler-fn tier reset-value)))))

;; Accessors for stratum-handler entries.
(define (stratum-handler-cell-id    entry) (car entry))
(define (stratum-handler-fn         entry) (cadr entry))
(define (stratum-handler-tier       entry) (caddr entry))
(define (stratum-handler-reset-val  entry) (cadddr entry))

;; PAR Track 1: Built-in topology handler for callback-topology-request.
;; Calls the opaque callback outside BSP fire rounds.
;; A1 (BSP-LE 2B addendum, 2026-04-16): migrated from register-topology-handler!
;; (legacy try-each chain on shared decomp-request-cell) to register-stratum-handler!
;; with :tier 'topology and its own subsystem cell (cell-id 6).
(register-stratum-handler!
 constraint-propagators-topology-cell-id
 (lambda (net req-set)
   (for/fold ([n net]) ([req (in-set req-set)])
     (cond
       [(net-pair-decomp? n (callback-topology-request-pair-key req))
        n]  ;; Already processed — dedup
       [else
        (define pair-key (callback-topology-request-pair-key req))
        (define n* ((callback-topology-request-callback req) n))
        (net-pair-decomp-insert n* pair-key)])))
 #:tier 'topology
 #:reset-value (set))

;; A1 (BSP-LE 2B addendum, 2026-04-16): nogood-install-request handler deleted.
;; The struct, export, handler registration, and install-per-nogood-infrastructure
;; function were all dead code — nogood-install-request had a defined struct and
;; handler but ZERO constructor calls (ZERO producers) across the codebase. This
;; was designed but never wired up during BSP-LE Track 2 Phase 3. Removed as A1
;; audit finding; no behavioral change.

;; BSP run-to-quiescence: two-fixpoint loop (D.4 stratified topology).
;; Outer loop: alternates value stratum (BSP rounds) and topology stratum.
;; Inner loop: standard BSP — fire all worklist propagators per round.
;; executor: (snapshot-net pids → (listof fire-result | write-list))
;; Phase 2c: pool executor auto-selected when current-worker-pool is set.
;; Phase 2d investigation: streaming executor did not improve crossover due to
;; Racket inter-thread communication overhead. Sync pool remains the best path.
(define (run-to-quiescence-bsp net #:executor [executor (or (current-parallel-executor)
                                                             (let ([pool (current-worker-pool)])
                                                               (and pool (make-pool-executor pool)))
                                                             sequential-fire-all)])
  (define observer (current-bsp-observer))

  ;; Phase 5a: Tier detection.
  ;; Worldview cache == 0 means no assumptions allocated → Tier 1 (deterministic).
  ;; Tier 1: single-pass flush (fire all propagators directly, no BSP ceremony).
  (define worldview (net-cell-read net worldview-cache-cell-id))
  (cond
    [(and (zero? worldview)
          (pair? (prop-network-worklist net))
          (not (prop-network-contradiction net))
          (> (prop-network-fuel net) 0)
          ;; No pending NAF/stratum requests
          (let ([naf-p (net-cell-read net naf-pending-cell-id)])
            (or (not naf-p) (and (hash? naf-p) (hash-empty? naf-p))))
          ;; ALL worklist propagators must be fire-once AND have empty inputs.
          ;; If any has inputs, it may depend on other propagators → needs BSP loop.
          (for/and ([pid (in-list (prop-network-worklist net))])
            (define prop (champ-lookup (prop-network-propagators net)
                                       (prop-id-hash pid) pid))
            (and (not (eq? prop 'none))
                 (= (bitwise-and (propagator-flags prop)
                                 (bitwise-ior PROP-FIRE-ONCE PROP-EMPTY-INPUTS))
                    (bitwise-ior PROP-FIRE-ONCE PROP-EMPTY-INPUTS)))))
     ;; TIER 1: single-pass flush. All propagators are fire-once with empty inputs.
     ;; No speculation, no branching, no NAF, no inter-propagator dependencies.
     ;; Fire all worklist propagators directly on canonical. One pass.
     ;; No snapshot, no dedup, no topology, no strata.
     (define result
       (for/fold ([n net])
                 ([pid (in-list (prop-network-worklist net))])
         (define prop (champ-lookup (prop-network-propagators n)
                                    (prop-id-hash pid) pid))
         (if (eq? prop 'none) n
             (fire-propagator prop n))))  ;; PPN 4C Phase 1.5
     ;; Clear worklist after flush
     (struct-copy prop-network result
       [hot (struct-copy prop-net-hot (prop-network-hot result)
              [worklist '()])])]

    [else
     ;; TIER 2 (or empty worklist): full BSP with optimizations.
     ;; Phase 5a: fired-set for self-clearing fire-once propagators.
     (let ([fired-set (make-hasheq)])
      ;; Outer loop: value stratum → topology stratum → repeat
      (let outer-loop ([net net] [outer-round 0])
       (cond
         [(prop-network-contradiction net) net]
         [(<= (prop-network-fuel net) 0) net]
         [else
          ;; VALUE STRATUM: BSP inner loop with fire-once optimization
          (define value-result
            (let inner-loop ([net net] [round-number 0])
              (cond
                [(prop-network-contradiction net) net]
                [(<= (prop-network-fuel net) 0) net]
                [(null? (prop-network-worklist net)) net]
             [else
              (let* ([raw-pids (dedup-pids (prop-network-worklist net))]
                     ;; Phase 5a: filter out already-fired fire-once propagators
                     [pids (filter (lambda (pid) (not (hash-has-key? fired-set pid)))
                                   raw-pids)]
                     [n (length pids)]
                     [snapshot (struct-copy prop-network net
                                 [hot (struct-copy prop-net-hot (prop-network-hot net)
                                        [worklist '()]
                                        [fuel (- (prop-network-fuel net) n)])])]
                     ;; R1: time fire phase
                     [t-fire-start (current-inexact-monotonic-milliseconds)]
                     [all-writes (executor snapshot pids)]
                     [t-fire-end (current-inexact-monotonic-milliseconds)]
                     ;; R1: time merge phase
                     ;; Phase 2b: tree-reduce for large worklists (hypercube all-reduce).
                     ;; Below threshold: sequential bulk-merge-writes (for/fold).
                     ;; Above threshold: tree-reduce combines write-sets pairwise,
                     ;; then applies the combined result in one pass.
                     [t-merge-start t-fire-end]
                     [tree-threshold (current-tree-reduce-threshold)]
                     [merged (if (and tree-threshold (>= n tree-threshold))
                                 (let ([combined (tree-reduce-fire-results all-writes #t)])
                                   (if combined
                                       (bulk-merge-writes snapshot (list combined))
                                       snapshot))
                                 (bulk-merge-writes snapshot all-writes))]
                     [t-merge-end (current-inexact-monotonic-milliseconds)]
                     ;; Apply deferred propagators
                     [deferred-props (collect-deferred-propagators all-writes)]
                     [merged-with-props
                      (for/fold ([n merged])
                                ([spec (in-list deferred-props)])
                        (let-values ([(n* _pid) (net-add-propagator n (car spec) (cadr spec) (caddr spec))])
                          n*))]
                     ;; Phase 5a: mark fire-once propagators as fired + self-clear.
                     ;; Check each fired pid: if PROP-FIRE-ONCE flag set and fire produced
                     ;; a change, add to fired-set and remove from dependents.
                     [merged-self-cleared
                      (for/fold ([n merged-with-props])
                                ([pid (in-list pids)]
                                 [result (in-list all-writes)])
                        (define prop (champ-lookup (prop-network-propagators n)
                                                    (prop-id-hash pid) pid))
                        (cond
                          [(eq? prop 'none) n]
                          [(zero? (bitwise-and (propagator-flags prop) PROP-FIRE-ONCE)) n]
                          [(and (fire-result? result)
                                (or (pair? (fire-result-value-writes result))
                                    (pair? (fire-result-new-cells result))))
                           ;; Fire-once propagator produced output → mark fired + self-clear
                           (hash-set! fired-set pid #t)
                           ;; Remove from input cells' dependents (no future enqueuing)
                           (for/fold ([net n])
                                     ([cid (in-list (propagator-inputs prop))])
                             (net-remove-propagator-from-dependents net pid cid))]
                          [else n]))]
                     ;; R1: record stats if accumulator is active
                     [_ (let ([stats-box (current-bsp-round-stats)])
                          (when stats-box
                            (define write-count
                              (for/sum ([r (in-list all-writes)])
                                (length (if (fire-result? r) (fire-result-value-writes r) r))))
                            (set-box! stats-box
                              (cons (list n
                                          (- t-fire-end t-fire-start)
                                          (- t-merge-end t-merge-start)
                                          write-count
                                          (length deferred-props))
                                    (unbox stats-box)))))])
                ;; Observer notification
                (when observer
                  (define writes-for-observer
                    (for/list ([result (in-list all-writes)])
                      (if (fire-result? result) (fire-result-value-writes result) result)))
                  (define diffs
                    (for/fold ([acc '()])
                              ([writes (in-list writes-for-observer)]
                               [pid (in-list pids)])
                      (for/fold ([acc acc])
                                ([w (in-list writes)])
                        (cons (cell-diff (car w)
                                         (net-cell-read snapshot (car w))
                                         (cdr w)
                                         pid)
                              acc))))
                  (observer (bsp-round round-number merged-self-cleared (reverse diffs) pids
                                       (prop-network-contradiction merged-self-cleared) '())))
                (inner-loop merged-self-cleared (add1 round-number)))])))
          ;; TIERED STRATUM PROCESSING (A1 unified approach):
          ;;   1. Legacy topology stratum (decomp-request-cell, try-each chain) — will be retired in A1.5
          ;;   2. Topology-tier stratum handlers (per-subsystem cells; new A1 mechanism)
          ;;   3. Value-tier stratum handlers (S1 NAF, future strata)
          ;; Any tier producing S0 worklist → outer-loop restart from S0.
       (cond
         [(prop-network-contradiction value-result) value-result]
         [else
          ;; Shared stratum-processing helper (DRY across tiers + legacy).
          (define (process-tier net tier-predicate)
            (let process ([net net]
                          [remaining (filter tier-predicate (unbox stratum-handlers))])
              (cond
                [(null? remaining) net]
                [(prop-network-contradiction net) net]
                [else
                 (define entry (car remaining))
                 (define req-cid (stratum-handler-cell-id entry))
                 (define handler-fn (stratum-handler-fn entry))
                 (define reset-val (stratum-handler-reset-val entry))
                 (define pending (net-cell-read net req-cid))
                 (cond
                   [(or (not pending)
                        (and (hash? pending) (hash-empty? pending))
                        (and (set? pending) (set-empty? pending)))
                    (process net (cdr remaining))]
                   [else
                    (define processed (handler-fn net pending))
                    (define cleared (net-cell-reset processed req-cid reset-val))
                    (if (pair? (prop-network-worklist cleared))
                        ;; Produced S0 work — return to outer-loop
                        (begin
                          (when (> outer-round 20)
                            (error 'run-to-quiescence-bsp
                                   "stratum handlers: >20 outer iterations — possible infinite loop"))
                          cleared)
                        (process cleared (cdr remaining)))])])))
          ;; 1. Topology-tier strata (A1: per-subsystem cells)
          (define after-topo-tier
            (process-tier value-result
                          (lambda (e) (eq? (stratum-handler-tier e) 'topology))))
          (cond
            [(and (pair? (prop-network-worklist after-topo-tier))
                  (not (eq? after-topo-tier value-result)))
             (when (> outer-round 20)
               (error 'run-to-quiescence-bsp
                      "topology tier: >20 outer iterations — possible infinite loop"))
             (outer-loop after-topo-tier (add1 outer-round))]
            [else
             ;; 2. Value-tier strata (S1 NAF, etc.)
             (define after-value-tier
               (process-tier after-topo-tier
                             (lambda (e) (eq? (stratum-handler-tier e) 'value))))
             (cond
               [(and (pair? (prop-network-worklist after-value-tier))
                     (not (eq? after-value-tier after-topo-tier)))
                (outer-loop after-value-tier (add1 outer-round))]
               [else after-value-tier])])])])))]))

;; ========================================
;; Parallel Executor (Phase 2.5c)
;; ========================================

;; Create a parallel executor using Racket futures.
;; CHAMP operations are pure struct/vector operations → future-safe.
;; Falls back to sequential-fire-all when worklist size < threshold.
;;
;; Contract: fire-fns MUST be pure (no mutation, no I/O) for correct
;; parallel execution. Non-pure fire-fns produce non-deterministic results.
(define (make-parallel-fire-all [threshold 4])
  (lambda (snapshot-net pids)
    (if (< (length pids) threshold)
        ;; Below threshold: sequential (avoid future creation overhead)
        (sequential-fire-all snapshot-net pids)
        ;; Above threshold: parallel via Racket futures
        ;; Phase 2b: each propagator gets a namespace index
        (let* ([futures
                (for/list ([pid (in-list pids)]
                           [idx (in-naturals 1)])
                  (future
                   (lambda ()
                     (fire-and-collect-writes snapshot-net pid idx))))]
               [results (map touch futures)])
          results))))

;; PAR Track 2 R2: Parallel executor parameter.
;; When set, BSP uses this executor instead of sequential-fire-all.
;; Set to (make-parallel-thread-fire-all) for true parallelism.
(define current-parallel-executor (make-parameter #f))

;; PAR Track 2 R2: Parallel Thread Executor
;; Uses Racket 9 parallel threads (#:pool 'own) for true parallelism.
;; Unlike futures, parallel threads support allocation, parameters,
;; and mutable hash table operations — no blocking restrictions.
;;
;; Architecture:
;;   1. Partition worklist into K chunks (K = core count)
;;   2. Fire each chunk on a parallel thread
;;   3. Each thread runs sequential-fire-all on its chunk
;;   4. Join all threads, concatenate results
;;   5. bulk-merge-writes processes all results (sequential)
;;
;; Correctness: BSP snapshot isolation guarantees order-independence.
;; All threads see the same snapshot. Results are merged commutatively.
(define (make-parallel-thread-fire-all [min-parallel 8])
  (define ncores (processor-count))
  (lambda (snapshot-net pids)
    (define n (length pids))
    (if (< n min-parallel)
        ;; Below threshold: sequential (avoid thread overhead)
        (sequential-fire-all snapshot-net pids)
        ;; Above threshold: parallel via Racket 9 parallel threads
        (let* ([chunk-size (max 1 (quotient n ncores))]
               [chunks (let loop ([remaining pids] [acc '()])
                         (if (null? remaining) (reverse acc)
                             (let-values ([(chunk rest) (split-at remaining (min chunk-size (length remaining)))])
                               (loop rest (cons chunk acc)))))]
               ;; Fire each chunk on a parallel thread
               ;; Phase 2b: each propagator gets a namespace index (global across chunks)
               [chunk-start-indices
                (let loop ([chunks chunks] [start 1] [acc '()])
                  (if (null? chunks) (reverse acc)
                      (loop (cdr chunks) (+ start (length (car chunks)))
                            (cons start acc))))]
               [result-channels
                (for/list ([chunk (in-list chunks)]
                           [start-idx (in-list chunk-start-indices)])
                  (define ch (make-channel))
                  (thread #:pool 'own
                    (lambda ()
                      (define results
                        (for/list ([pid (in-list chunk)]
                                   [idx (in-naturals start-idx)])
                          (fire-and-collect-writes snapshot-net pid idx)))
                      (channel-put ch results)))
                  ch)]
               ;; Join all threads by reading from channels
               [all-results
                (apply append
                       (for/list ([ch (in-list result-channels)])
                         (channel-get ch)))])
          all-results))))

;; ========================================
;; Phase 2c: Semaphore-Based Worker Pool
;; ========================================
;;
;; General BSP parallelism infrastructure. Persistent K worker threads
;; dispatched via semaphores (~0.01us vs ~3.6us thread creation).
;; Closure-as-module: each work item is a closure capturing its context.
;; Pool config on-network (cell-id 5). Execution substrate: Racket threads.
;;
;; Drop-in replacement for make-parallel-thread-fire-all via the
;; (snapshot-net pids → results) executor interface.

;; Global worker pool parameter. When set, BSP uses pool dispatch for
;; worklists >= threshold. Lazily initialized on first use.
(define current-worker-pool (make-parameter #f))

(struct worker-pool
  (workers          ;; (vectorof thread?)
   work-sems        ;; (vectorof semaphore) — post to wake worker i
   done-sems        ;; (vectorof semaphore) — worker i posts when done
   work-slots       ;; (vectorof box) — work-slot[i] = thunk to execute
   result-slots     ;; (vectorof box) — result-slot[i] = result from worker i
   result-channel   ;; channel — Phase 2d: shared result channel (completion-order streaming)
   k                ;; integer — number of workers
   shutdown-box)    ;; (box boolean) — set to #t to stop workers
  #:transparent)

;; Create a persistent worker pool with K workers.
;; Phase 2c hybrid spin-wait: workers spin-check their work-slot (exponential
;; backoff window), fall back to semaphore-wait on miss. Self-tuning:
;; spin window grows on hit (dispatch arrived during spin), shrinks on miss.
;; Futex-inspired: fast userspace spin, kernel sleep as fallback.
;; K defaults to processor-count. Workers are Racket OS threads (#:pool 'own).
(define SPIN-MIN 10)       ;; ~0.01us — floor during idle
(define SPIN-MAX 10000)    ;; ~10us — ceiling during active computation
(define SPIN-INITIAL 100)  ;; ~0.1us — conservative start

(define (make-worker-pool [k (processor-count)])
  (define work-sems (for/vector ([_ (in-range k)]) (make-semaphore 0)))
  (define done-sems (for/vector ([_ (in-range k)]) (make-semaphore 0)))
  (define work-slots (for/vector ([_ (in-range k)]) (box #f)))
  (define result-slots (for/vector ([_ (in-range k)]) (box #f)))
  (define result-ch (make-async-channel))  ;; Phase 2d: buffered result channel (puts don't block)
  (define shutdown (box #f))
  (define workers
    (for/vector ([i (in-range k)])
      (thread #:pool 'own
        (lambda ()
          (define my-work-slot (vector-ref work-slots i))
          (define my-work-sem (vector-ref work-sems i))
          (define my-result-slot (vector-ref result-slots i))
          (define my-done-sem (vector-ref done-sems i))
          (let loop ([spin-window SPIN-INITIAL])
            (unless (unbox shutdown)
              ;; Phase 1: Spin-check work-slot for non-#f value.
              (define thunk
                (let spin ([remaining spin-window])
                  (cond
                    [(zero? remaining) #f]
                    [else
                     (define v (unbox my-work-slot))
                     (if v v (spin (sub1 remaining)))])))
              (cond
                [thunk
                 ;; HIT: caught dispatch during spin.
                 (semaphore-try-wait? my-work-sem)
                 (set-box! my-work-slot #f)
                 (define result (thunk))
                 (set-box! my-result-slot result)
                 ;; Phase 2d: write to shared channel (streaming) AND done-sem (sync compat)
                 (async-channel-put result-ch (cons i result))
                 (semaphore-post my-done-sem)
                 (loop (min (* spin-window 2) SPIN-MAX))]
                [else
                 ;; MISS: spin exhausted, sleep on semaphore.
                 (semaphore-wait my-work-sem)
                 (unless (unbox shutdown)
                   (define work (unbox my-work-slot))
                   (set-box! my-work-slot #f)
                   (define result (if work (work) #f))
                   (set-box! my-result-slot result)
                   (async-channel-put result-ch (cons i result))
                   (semaphore-post my-done-sem)
                   (loop (max (quotient spin-window 2) SPIN-MIN)))])))))))
  (worker-pool workers work-sems done-sems work-slots result-slots result-ch k shutdown))

;; Dispatch K thunks to the pool and collect results.
;; thunks: (listof (or/c procedure? #f)) — #f slots produce #f result.
;; Returns: (listof any) — one result per thunk, in order.
(define (pool-dispatch pool thunks)
  (define k (worker-pool-k pool))
  (define n (length thunks))
  (define actual-k (min k n))
  ;; Write thunks to work slots
  (for ([thunk (in-list thunks)]
        [i (in-naturals)])
    (when (< i actual-k)
      (set-box! (vector-ref (worker-pool-work-slots pool) i) thunk)))
  ;; Post work semaphores (workers wake)
  (for ([i (in-range actual-k)])
    (semaphore-post (vector-ref (worker-pool-work-sems pool) i)))
  ;; Wait for all workers to complete
  (for ([i (in-range actual-k)])
    (semaphore-wait (vector-ref (worker-pool-done-sems pool) i)))
  ;; Read results
  (for/list ([i (in-range actual-k)])
    (unbox (vector-ref (worker-pool-result-slots pool) i))))

;; Phase 2d: Async pool dispatch with streaming results.
;; Returns a pool-handle. Use pool-handle-next! to get results in completion order.
(struct pool-handle (pool actual-k remaining-indices) #:mutable #:transparent)

(define (pool-dispatch-async pool thunks)
  (define k (worker-pool-k pool))
  (define n (length thunks))
  (define actual-k (min k n))
  ;; Drain any leftover results from previous dispatches (sync or warmup)
  (let drain ()
    (when (async-channel-try-get (worker-pool-result-channel pool))
      (drain)))
  ;; Write thunks to work slots
  (for ([thunk (in-list thunks)]
        [i (in-naturals)])
    (when (< i actual-k)
      (set-box! (vector-ref (worker-pool-work-slots pool) i) thunk)))
  ;; Post work semaphores (workers wake or spin-catch)
  (for ([i (in-range actual-k)])
    (semaphore-post (vector-ref (worker-pool-work-sems pool) i)))
  ;; Return handle — results streamed via pool-handle-next!
  (pool-handle pool actual-k (for/list ([i (in-range actual-k)]) i)))

;; Get the next completing result in completion order (first to finish → first returned).
;; Phase 2d: reads from shared result channel (~1.5us per read vs sync event dispatch).
;; Workers write (cons worker-index result) to the channel as they complete.
;; Returns the fire-result from the first worker to complete.
;; Mutates the handle to remove the completed worker from remaining.
(define (pool-handle-next! handle)
  (define pool (pool-handle-pool handle))
  (define remaining (pool-handle-remaining-indices handle))
  (cond
    [(null? remaining) #f]  ;; all results collected
    [else
     ;; Phase 2d: spin-poll done-semaphores directly (no channel, no sync).
     ;; Try each remaining worker's done-sem. First to succeed = first completed.
     ;; Spin if none ready yet (workers are actively computing).
     ;; Cost: O(K) semaphore-try-wait? per scan. Much cheaper than channel/sync.
     (define-values (done-idx result)
       (let scan ()
         (let check ([idxs remaining])
           (cond
             [(null? idxs) (scan)]  ;; none ready, spin again
             [(semaphore-try-wait? (vector-ref (worker-pool-done-sems pool) (car idxs)))
              ;; This worker completed
              (values (car idxs) (unbox (vector-ref (worker-pool-result-slots pool) (car idxs))))]
             [else (check (cdr idxs))]))))
     ;; Remove from remaining
     (set-pool-handle-remaining-indices! handle
       (filter (lambda (i) (not (= i done-idx))) remaining))
     result]))

;; Collect all remaining results from a handle (convenience).
(define (pool-handle-collect-all! handle)
  (let loop ([results '()])
    (define r (pool-handle-next! handle))
    (if r (loop (cons r results)) (reverse results))))

;; Create an executor using the worker pool.
;; Drop-in replacement for make-parallel-thread-fire-all.
;; Contract: (snapshot-net pids → (listof fire-result))
(define (make-pool-executor pool [min-parallel 8])
  (define k (worker-pool-k pool))
  (lambda (snapshot-net pids)
    (define n (length pids))
    (if (< n min-parallel)
        ;; Below threshold: sequential (avoid dispatch overhead for trivial worklists)
        (sequential-fire-all snapshot-net pids)
        ;; Above threshold: dispatch chunks to pool workers
        (let* ([chunk-size (max 1 (quotient n k))]
               [chunks (let loop ([remaining pids] [idx 1] [acc '()])
                         (if (null? remaining) (reverse acc)
                             (let-values ([(chunk rest) (split-at remaining
                                                          (min chunk-size (length remaining)))])
                               (loop rest (+ idx (length chunk))
                                     (cons (cons idx chunk) acc)))))]
               ;; Build closure-as-module per chunk:
               ;; each closure captures snapshot + chunk + namespace index range
               [thunks
                (for/list ([chunk-pair (in-list chunks)])
                  (define start-idx (car chunk-pair))
                  (define chunk (cdr chunk-pair))
                  (lambda ()
                    (for/list ([pid (in-list chunk)]
                               [idx (in-naturals start-idx)])
                      (fire-and-collect-writes snapshot-net pid idx))))]
               ;; Dispatch to pool
               [chunk-results (pool-dispatch pool thunks)])
          ;; Concatenate chunk results
          (apply append chunk-results)))))

;; Phase 2d: Streaming BSP executor.
;; Fires propagators via async pool dispatch, merges results as they stream in
;; via completion-order tree-reduce. Fire and merge phases overlap — workers
;; alternate between fire and merge work. No synchronous barrier.
;; Contract: (snapshot-net pids → (listof fire-result))
;; Returns a SINGLE merged fire-result (as a one-element list for bulk-merge-writes compat).
(define (make-streaming-executor pool [min-parallel 8])
  (define k (worker-pool-k pool))
  (lambda (snapshot-net pids)
    (define n (length pids))
    (if (< n min-parallel)
        ;; Below threshold: sequential
        (sequential-fire-all snapshot-net pids)
        ;; Above threshold: streaming fire + completion-order tree-reduce merge
        (let* ([chunk-size (max 1 (quotient n k))]
               [chunks (let loop ([remaining pids] [idx 1] [acc '()])
                         (if (null? remaining) (reverse acc)
                             (let-values ([(chunk rest) (split-at remaining
                                                          (min chunk-size (length remaining)))])
                               (loop rest (+ idx (length chunk))
                                     (cons (cons idx chunk) acc)))))]
               ;; Build fire thunks (closure-as-module)
               [fire-thunks
                (for/list ([chunk-pair (in-list chunks)])
                  (define start-idx (car chunk-pair))
                  (define chunk (cdr chunk-pair))
                  (lambda ()
                    (for/list ([pid (in-list chunk)]
                               [idx (in-naturals start-idx)])
                      (fire-and-collect-writes snapshot-net pid idx))))]
               ;; Dispatch all fire thunks asynchronously
               [handle (pool-dispatch-async pool fire-thunks)])
          ;; Stream results and tree-reduce merge as they arrive.
          ;; Pair results in completion order. Dispatch pairwise merges to pool.
          ;; Returns list of all fire-results (flattened from chunks).
          (define all-fire-results
            (let collect-loop ([remaining-count (length fire-thunks)] [acc '()])
              (if (zero? remaining-count)
                  (apply append (reverse acc))
                  (let ([chunk-results (pool-handle-next! handle)])
                    (collect-loop (sub1 remaining-count)
                                 (cons (if (list? chunk-results) chunk-results
                                           (list chunk-results))
                                       acc))))))
          ;; Apply tree-reduce to the collected results
          ;; (completion-order collection already provides overlap with fire phase)
          (define combined (tree-reduce-fire-results all-fire-results #f))
          (if combined (list combined) all-fire-results)))))

;; Shutdown the worker pool (release threads).
(define (worker-pool-shutdown! pool)
  (set-box! (worker-pool-shutdown-box pool) #t)
  (for ([i (in-range (worker-pool-k pool))])
    (semaphore-post (vector-ref (worker-pool-work-sems pool) i))))

;; ========================================
;; Convenience Queries
;; ========================================

;; Has the network encountered a contradiction?
(define (net-contradiction? net)
  (and (prop-network-contradiction net) #t))

;; Is the network quiescent (worklist empty)?
(define (net-quiescent? net)
  (null? (prop-network-worklist net)))

;; How much fuel remains?
(define (net-fuel-remaining net)
  (prop-network-fuel net))

;; ========================================
;; Widening Support (Phase 6a)
;; ========================================
;;
;; For lattices with infinite ascending chains, standard fixpoint iteration
;; may not terminate. Widening over-approximates at designated "widening
;; point" cells to force convergence; narrowing then recovers precision.
;;
;; Strategy: two-phase iteration.
;;   Phase 1 (widen): run propagation normally, but at widening-point cells,
;;     replace merge with widen(old, merged) when value changes.
;;   Phase 2 (narrow): once widen phase is quiescent, switch to narrow phase
;;     where widening-point cells use narrow(old, merged) instead.
;;   Repeat until narrow phase produces no changes.

;; Mark a cell as a widening point.
;; widen-fn: (old-val new-val → widened-val) — over-approximate for convergence
;; narrow-fn: (old-val new-val → narrowed-val) — recover precision
;; Returns updated network.
(define (net-set-widen-point net cid widen-fn narrow-fn)
  (define h (cell-id-hash cid))
  (struct-copy prop-network net
    [cold (struct-copy prop-net-cold (prop-network-cold net)
            [widen-fns (champ-insert (prop-network-widen-fns net)
                                     h cid (cons widen-fn narrow-fn))])]))

;; Check if a cell is a widening point.
(define (net-widen-point? net cid)
  (not (eq? 'none
             (champ-lookup (prop-network-widen-fns net)
                           (cell-id-hash cid) cid))))

;; Create a cell AND mark it as a widening point in one step.
;; Convenience combining net-new-cell + net-set-widen-point.
;; Returns: (values new-network cell-id)
(define (net-new-cell-widen net initial-value merge-fn
                            widen-fn narrow-fn [contradicts? #f]
                            #:domain [explicit-domain #f])
  ;; PPN 4C Phase 1c: pass-through to net-new-cell which handles Tier 3 domain inheritance.
  (define-values (net1 cid)
    (net-new-cell net initial-value merge-fn contradicts? #:domain explicit-domain))
  (values (net-set-widen-point net1 cid widen-fn narrow-fn) cid))

;; Write to a cell with widening: if the cell is a widening point,
;; applies widen(old, merged) instead of just merge(old, new).
;; For non-widening cells, behaves identically to net-cell-write.
(define (net-cell-write-widen net cid new-val)
  (define cells (prop-network-cells net))
  (define h (cell-id-hash cid))
  (define cell (champ-lookup cells h cid))
  (when (eq? cell 'none)
    (error 'net-cell-write-widen "unknown cell: ~a" cid))
  ;; B2f Phase 0: count every write attempt
  (define wc (current-quiescence-write-counter))
  (when wc (set-box! wc (add1 (unbox wc))))
  (define merge-fn
    (champ-lookup (prop-network-merge-fns net) h cid))
  (define old-val (prop-cell-value cell))
  ;; BSP-LE Track 2 Phase 4: tagged-cell-value write (same pattern as net-cell-write)
  (define actual-new-val
    (cond
      [(and (tagged-cell-value? old-val) (not (tagged-cell-value? new-val)))
       ;; Same per-propagator bitmask logic as net-cell-write
       (define per-prop-wv (current-worldview-bitmask))
       (define wv-bitmask
         (if (not (zero? per-prop-wv))
             per-prop-wv
             (let ([wv-cell (champ-lookup cells
                                          (cell-id-hash worldview-cache-cell-id)
                                          worldview-cache-cell-id)])
               (if (eq? wv-cell 'none) 0 (prop-cell-value wv-cell)))))
       (if (zero? wv-bitmask)
           (tagged-cell-value new-val '())
           (tagged-cell-value (tagged-cell-value-base old-val)
                              (list (cons wv-bitmask new-val))))]
      ;; PPN 4C 1A-iii-a-wide Step 1 S1.b (2026-04-22): TMS fallback RETIRED
      ;; (net-cell-write-widen). See net-cell-read branch for full retirement rationale.
      [else new-val]))
  (define merged (merge-fn old-val actual-new-val))
  ;; If cell is a widening point, apply widen to the merged result
  (define widen-entry (champ-lookup (prop-network-widen-fns net) h cid))
  (define final-val
    (if (eq? widen-entry 'none)
        merged
        ((car widen-entry) old-val merged)))
  (if (or (eq? final-val old-val) (equal? final-val old-val))
      net  ;; No change — critical for termination
      (let* (;; B2f Phase 0: count writes that actually change the CHAMP
             [cc (current-quiescence-change-counter)]
             [_ (when cc (set-box! cc (add1 (unbox cc))))]
             [new-cell (struct-copy prop-cell cell [value final-val])]
             [new-cells (champ-insert cells h cid new-cell)]
             [deps (champ-keys (prop-cell-dependents cell))]
             [new-wl (append deps (prop-network-worklist net))]
             [cfn (champ-lookup (prop-network-contradiction-fns net) h cid)]
             [contradicted?
              (and (not (eq? cfn 'none))
                   (cfn final-val))]
             [net* (struct-copy prop-network net
                     [warm (struct-copy prop-net-warm (prop-network-warm net)
                             [cells new-cells])]
                     [hot (struct-copy prop-net-hot (prop-network-hot net)
                            [worklist new-wl])])])
        (if contradicted?
            (struct-copy prop-network net*
              [warm (struct-copy prop-net-warm (prop-network-warm net*)
                      [contradiction cid])])
            net*))))

;; Internal: run one phase of widening fixpoint iteration.
;; Uses net-cell-write-widen instead of net-cell-write for propagator output.
;; Returns network at quiescence (or contradiction/fuel exhaustion).
(define (run-widen-phase net)
  (cond
    [(prop-network-contradiction net) net]
    [(<= (prop-network-fuel net) 0) net]
    [(null? (prop-network-worklist net)) net]
    [else
     (let* ([pid (car (prop-network-worklist net))]
            [rest (cdr (prop-network-worklist net))]
            [net* (struct-copy prop-network net
                    [hot (struct-copy prop-net-hot (prop-network-hot net)
                           [worklist rest]
                           [fuel (sub1 (prop-network-fuel net))])])]
            [prop (champ-lookup (prop-network-propagators net*)
                                (prop-id-hash pid) pid)])
       (if (eq? prop 'none)
           (run-widen-phase net*)
           ;; Fire propagator, but capture writes and apply via net-cell-write-widen
           (let* ([result-net (fire-propagator prop net*)]  ;; PPN 4C Phase 1.5
                  ;; Diff output cells to find changes
                  [writes (for/fold ([ws '()])
                                    ([cid (in-list (propagator-outputs prop))])
                            (let ([old (net-cell-read net* cid)]
                                  [new (net-cell-read result-net cid)])
                              (if (equal? old new)
                                  ws
                                  (cons (cons cid new) ws))))]
                  ;; Apply writes via widening-aware writer
                  [net** (for/fold ([n net*])
                                   ([w (in-list writes)])
                           (net-cell-write-widen n (car w) (cdr w)))])
             (run-widen-phase net**))))]))

;; Internal: create a snapshot for narrow-phase firing.
;; Widening-point cells get a passthrough merge: (lambda (old new) new)
;; so the propagator's net-cell-write captures the raw transfer function output
;; rather than the monotone merge (which would hide values below old).
(define (make-narrow-snapshot net)
  (define wfns (prop-network-widen-fns net))
  (define mfns (prop-network-merge-fns net))
  ;; Replace merge-fn for each widening-point cell with passthrough
  (define new-mfns
    (for/fold ([m mfns])
              ([cid (in-list (champ-keys wfns))])
      (define h (cell-id-hash cid))
      (champ-insert m h cid (lambda (old new) new))))
  (struct-copy prop-network net
    [cold (struct-copy prop-net-cold (prop-network-cold net)
            [merge-fns new-mfns])]))

;; Internal: run one phase of narrowing iteration.
;; Strategy: fire propagators against a snapshot where widening-point cells
;; have passthrough merge, so we capture the raw transfer function output.
;; Then apply narrow(old, raw_new) at widening points.
(define (run-narrow-phase net)
  (cond
    [(prop-network-contradiction net) net]
    [(<= (prop-network-fuel net) 0) net]
    [(null? (prop-network-worklist net)) net]
    [else
     (let* ([pid (car (prop-network-worklist net))]
            [rest (cdr (prop-network-worklist net))]
            [net* (struct-copy prop-network net
                    [hot (struct-copy prop-net-hot (prop-network-hot net)
                           [worklist rest]
                           [fuel (sub1 (prop-network-fuel net))])])]
            [prop (champ-lookup (prop-network-propagators net*)
                                (prop-id-hash pid) pid)])
       (if (eq? prop 'none)
           (run-narrow-phase net*)
           ;; Fire propagator against a snapshot with passthrough merge for widen cells
           (let* ([snapshot (make-narrow-snapshot net*)]
                  [result-net (fire-propagator prop snapshot)]  ;; PPN 4C Phase 1.5
                  ;; Diff output cells — snapshot has passthrough merge, so
                  ;; we see the raw transfer function output
                  [writes (for/fold ([ws '()])
                                    ([cid (in-list (propagator-outputs prop))])
                            (let ([old (net-cell-read net* cid)]
                                  [new (net-cell-read result-net cid)])
                              (if (equal? old new)
                                  ws
                                  (cons (cons cid new) ws))))]
                  ;; Apply writes: at widen-points use narrow-fn, otherwise merge
                  [net** (for/fold ([n net*])
                                   ([w (in-list writes)])
                           (let* ([cid (car w)]
                                  [new-val (cdr w)]
                                  [h (cell-id-hash cid)]
                                  [wentry (champ-lookup
                                           (prop-network-widen-fns n) h cid)])
                             (if (eq? wentry 'none)
                                 ;; Normal cell: use standard write
                                 (net-cell-write n cid new-val)
                                 ;; Widening point: apply narrow(old, raw_new)
                                 (let* ([cell (champ-lookup
                                               (prop-network-cells n) h cid)]
                                        [old-val (prop-cell-value cell)]
                                        [narrowed ((cdr wentry) old-val new-val)])
                                   (if (equal? narrowed old-val)
                                       n
                                       (let* ([new-cell
                                               (struct-copy prop-cell cell
                                                 [value narrowed])]
                                              [new-cells
                                               (champ-insert
                                                (prop-network-cells n)
                                                h cid new-cell)]
                                              [deps (champ-keys
                                                     (prop-cell-dependents cell))]
                                              [new-wl
                                               (append deps
                                                       (prop-network-worklist n))]
                                              [cfn (champ-lookup
                                                    (prop-network-contradiction-fns n)
                                                    h cid)]
                                              [contradicted?
                                               (and (not (eq? cfn 'none))
                                                    (cfn narrowed))]
                                              [n* (struct-copy prop-network n
                                                    [warm (struct-copy prop-net-warm (prop-network-warm n)
                                                            [cells new-cells])]
                                                    [hot (struct-copy prop-net-hot (prop-network-hot n)
                                                           [worklist new-wl])])])
                                         (if contradicted?
                                             (struct-copy prop-network n*
                                               [warm (struct-copy prop-net-warm (prop-network-warm n*)
                                                       [contradiction cid])])
                                             n*)))))))])
             (run-narrow-phase net**))))]))

;; Run the network to quiescence with widening/narrowing.
;;
;; Two-phase strategy:
;;   1. Run widen phase: propagate normally, apply widen at widening points.
;;      This over-approximates but guarantees convergence.
;;   2. Run narrow phase: propagate normally, apply narrow at widening points.
;;      This recovers precision lost to widening.
;;   3. Repeat narrow phase until no further changes (or max-rounds reached).
;;
;; If there are no widening points, behaves identically to run-to-quiescence.
(define (run-to-quiescence-widen net #:max-rounds [max-rounds 100])
  ;; Phase 1: widen to quiescence
  (define widened (run-widen-phase net))
  (when (or (prop-network-contradiction widened)
            (<= (prop-network-fuel widened) 0))
    (void))  ;; early exit conditions handled by return below
  (if (or (prop-network-contradiction widened)
          (<= (prop-network-fuel widened) 0))
      widened
      ;; Phase 2: narrowing iterations
      (let loop ([net widened] [rounds 0])
        (cond
          [(>= rounds max-rounds) net]
          [(prop-network-contradiction net) net]
          [(<= (prop-network-fuel net) 0) net]
          [else
           ;; Re-fire all propagators to see if narrowing produces changes
           ;; Schedule all propagators that have widening-point outputs
           (define all-prop-ids
             (champ-keys (prop-network-propagators net)))
           (define net-with-wl
             (struct-copy prop-network net
               [hot (struct-copy prop-net-hot (prop-network-hot net)
                      [worklist all-prop-ids])]))
           (define narrowed (run-narrow-phase net-with-wl))
           ;; Check if narrowing changed anything by comparing cell values
           (if (equal? (prop-network-cells narrowed)
                       (prop-network-cells net))
               narrowed  ;; No change — converged
               (loop narrowed (+ rounds 1)))]))))

;; ========================================
;; Structural Decomposition Registries (Phase 4c)
;; ========================================
;;
;; Support for structural decomposition propagators. When a unify propagator
;; detects both cells have compound values with the same head constructor
;; (e.g., Pi vs Pi), it decomposes into sub-cells + sub-propagators.
;;
;; Two registries prevent duplicate work:
;;   cell-decomps: per-cell sub-cell assignments (reused across constraints)
;;   pair-decomps: per-pair dedup (prevents duplicate sub-propagators)

;; Canonical key for a cell pair: (cons smaller-id larger-id) by cell-id-n.
;; SRE Track 1: optional relation-name distinguishes equality/subtype/duality
;; decompositions of the same cell pair (different relations produce different
;; sub-cell propagators — symmetric vs directional).
(define (decomp-key cid-a cid-b [relation-name #f])
  (define base
    (if (<= (cell-id-n cid-a) (cell-id-n cid-b))
        (cons cid-a cid-b)
        (cons cid-b cid-a)))
  (if relation-name
      (cons relation-name base)
      base))

;; Hash for decomp keys: combine the two cell-id hashes.
;; SRE Track 1: handles both 2-element (cons cid cid) and 3-element
;; (cons relation-name (cons cid cid)) keys.
(define (decomp-key-hash key)
  (define pair (if (symbol? (car key)) (cdr key) key))
  (define base-hash
    (bitwise-xor (cell-id-hash (car pair))
                 (* 31 (+ 1 (cell-id-hash (cdr pair))))))
  (if (symbol? (car key))
      (bitwise-xor base-hash (eq-hash-code (car key)))
      base-hash))

;; Look up per-cell sub-cell assignments.
;; Returns (cons constructor-tag (listof cell-id)) or 'none.
(define (net-cell-decomp-lookup net cid)
  (champ-lookup (prop-network-cell-decomps net) (cell-id-hash cid) cid))

;; Register per-cell sub-cell assignments.
;; tag: symbol (e.g., 'Pi, 'app, 'Sigma)
;; sub-cells: (listof cell-id)
(define (net-cell-decomp-insert net cid tag sub-cells)
  (struct-copy prop-network net
    [cold (struct-copy prop-net-cold (prop-network-cold net)
            [cell-decomps
             (champ-insert (prop-network-cell-decomps net)
                           (cell-id-hash cid) cid
                           (cons tag sub-cells))])]))

;; Check if a cell pair has already been decomposed.
(define (net-pair-decomp? net key)
  (not (eq? 'none (champ-lookup (prop-network-pair-decomps net)
                                 (decomp-key-hash key) key))))

;; Register a cell pair as decomposed.
(define (net-pair-decomp-insert net key)
  (struct-copy prop-network net
    [cold (struct-copy prop-net-cold (prop-network-cold net)
            [pair-decomps
             (champ-insert (prop-network-pair-decomps net)
                           (decomp-key-hash key) key #t)])]))

;; ========================================
;; Cross-Domain Propagation (Phase 6c)
;; ========================================

;; Create TWO unidirectional propagators connecting a concrete-domain cell
;; and an abstract-domain cell via α/γ functions:
;;
;;   1. c-cell changes → write alpha(c-val) to a-cell
;;   2. a-cell changes → write gamma(a-val) to c-cell
;;
;; Returns: (values new-network pid-alpha pid-gamma)
;;
;; Termination is guaranteed by net-cell-write's no-change guard:
;; if alpha(c) = a-cell's current value, no change → no propagation.
;; Requires alpha and gamma to be monotone.
(define (net-add-cross-domain-propagator net c-cell a-cell alpha-fn gamma-fn)
  ;; Propagator 1: C → A (abstraction direction)
  (define-values (net1 pid-alpha)
    (net-add-propagator net
      (list c-cell) (list a-cell)
      (lambda (net)
        (define c-val (net-cell-read net c-cell))
        (net-cell-write net a-cell (alpha-fn c-val)))))
  ;; Propagator 2: A → C (concretization direction)
  (define-values (net2 pid-gamma)
    (net-add-propagator net1
      (list a-cell) (list c-cell)
      (lambda (net)
        (define a-val (net-cell-read net a-cell))
        (net-cell-write net c-cell (gamma-fn a-val)))))
  (values net2 pid-alpha pid-gamma))
