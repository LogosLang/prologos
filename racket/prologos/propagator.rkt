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

(require "champ.rkt"
         "performance-counters.rkt"
         racket/future)   ;; for future, touch, processor-count

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
 ;; Propagator operations
 net-add-propagator
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
 ;; TMS cells — Track 4 Phase 1 (assumption-tagged values)
 (struct-out tms-cell-value)
 tms-cell-value?      ;; re-export predicate for external pattern matching
 tms-read
 tms-write
 tms-commit
 merge-tms-cell
 make-tms-merge
 net-new-tms-cell
 ;; TMS speculation stack — Track 4 Phase 1
 ;; Lives in propagator.rkt (not elab-speculation-bridge.rkt) to avoid
 ;; circular dependency: metavar-store.rkt needs it for TMS-aware reads.
 current-speculation-stack
 ;; Track 8 C5a: Global BSP scheduler override for A/B benchmarking
 current-use-bsp-scheduler?
 ;; CALM topology guard: #t during BSP fire rounds
 current-bsp-fire-round?
 ;; Raw cell read (bypasses TMS unwrapping) — for commit/provenance
 net-cell-read-raw
 ;; Track 6 Phase 2+3: Network-wide TMS commit
 net-commit-assumption
 ;; Track 6 Phase 4: TMS retraction
 tms-retract
 net-retract-assumption
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
;; dependents: champ-root (set of prop-id → #t) — propagators to fire on change
(struct prop-cell (value dependents) #:transparent)

;; Propagator — monotone function, immutable.
;; inputs: list of cell-id (cells this propagator reads)
;; outputs: list of cell-id (cells this propagator may write)
;; fire-fn: (prop-network → prop-network) — pure state transformer
(struct propagator (inputs outputs fire-fn) #:transparent)

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
                       cell-decomps pair-decomps cell-dirs)
  #:transparent)
(struct prop-network (hot warm cold) #:transparent)

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

;; Create an empty propagator network.
;; fuel: maximum number of propagator firings before run-to-quiescence stops.
(define (make-prop-network [fuel 1000000])
  (prop-network
   (prop-net-hot '() fuel)           ;; hot: worklist, fuel
   (prop-net-warm champ-empty #f)    ;; warm: cells, contradiction
   (prop-net-cold champ-empty        ;; cold: merge-fns
                  champ-empty        ;;   contradiction-fns
                  champ-empty        ;;   widen-fns
                  champ-empty        ;;   propagators
                  0                  ;;   next-cell-id
                  0                  ;;   next-prop-id
                  champ-empty        ;;   cell-decomps
                  champ-empty        ;;   pair-decomps
                  champ-empty)))     ;;   cell-dirs

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
(define (net-new-cell net initial-value merge-fn [contradicts? #f])
  ;; PAR Track 1 D.3: net-new-cell is CALM-safe during BSP fire rounds.
  ;; Cells without dependents don't affect scheduling topology.
  ;; New cells are captured structurally via next-cell-id comparison
  ;; in fire-and-collect-writes.
  (perf-inc-cell-alloc!)  ;; Track 7 Phase 0b
  (define id (cell-id (prop-network-next-cell-id net)))
  (define cell (prop-cell initial-value champ-empty))
  (define h (cell-id-hash id))
  (define net*
    (struct-copy prop-network net
      [warm (struct-copy prop-net-warm (prop-network-warm net)
              [cells (champ-insert (prop-network-cells net) h id cell)])]
      [cold (struct-copy prop-net-cold (prop-network-cold net)
              [merge-fns (champ-insert (prop-network-merge-fns net) h id merge-fn)]
              [next-cell-id (+ 1 (prop-network-next-cell-id net))])]))
  (values
   (if contradicts?
       (struct-copy prop-network net*
         [cold (struct-copy prop-net-cold (prop-network-cold net*)
                 [contradiction-fns
                  (champ-insert (prop-network-contradiction-fns net*)
                                h id contradicts?)])])
       net*)
   id))

;; Create a new descending cell (starts at top, refines downward via meet).
;; top-value: the lattice top (initial value)
;; meet-fn: (old-val new-val -> met-val) — the lattice meet (used as merge-fn)
;; contradicts?: optional (val -> Bool) — for descending, typically (lambda (v) (eq? v bot))
;; Returns: (values new-network cell-id)
(define (net-new-cell-desc net top-value meet-fn [contradicts? #f])
  (perf-inc-cell-alloc!)  ;; Track 7 Phase 0b
  (define id (cell-id (prop-network-next-cell-id net)))
  (define cell (prop-cell top-value champ-empty))
  (define h (cell-id-hash id))
  (define net*
    (struct-copy prop-network net
      [warm (struct-copy prop-net-warm (prop-network-warm net)
              [cells (champ-insert (prop-network-cells net) h id cell)])]
      [cold (struct-copy prop-net-cold (prop-network-cold net)
              [merge-fns (champ-insert (prop-network-merge-fns net) h id meet-fn)]
              [cell-dirs (champ-insert (prop-network-cell-dirs net) h id 'descending)]
              [next-cell-id (+ 1 (prop-network-next-cell-id net))])]))
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
  ;; Build transient CHAMPs from current persistent maps
  (define t-cells (champ-transient (prop-network-cells net)))
  (define t-merge (champ-transient (prop-network-merge-fns net)))
  (define t-contra (champ-transient (prop-network-contradiction-fns net)))
  (define has-contra? #f)
  ;; Allocate all cells into transients
  (define ids
    (for/list ([spec (in-list specs)]
               [i (in-naturals start-id)])
      (perf-inc-cell-alloc!)
      (define id (cell-id i))
      (define h (cell-id-hash id))
      (define initial-value (car spec))
      (define merge-fn (cadr spec))
      (define cell (prop-cell initial-value champ-empty))
      (tchamp-insert! t-cells h id cell)
      (tchamp-insert! t-merge h id merge-fn)
      (when (and (pair? (cddr spec)) (caddr spec))
        (set! has-contra? #t)
        (tchamp-insert! t-contra h id (caddr spec)))
      id))
  ;; Freeze all transients at once
  (define new-net
    (struct-copy prop-network net
      [warm (struct-copy prop-net-warm (prop-network-warm net)
              [cells (tchamp-freeze t-cells)])]
      [cold (if has-contra?
                (struct-copy prop-net-cold (prop-network-cold net)
                  [merge-fns (tchamp-freeze t-merge)]
                  [contradiction-fns (tchamp-freeze t-contra)]
                  [next-cell-id (+ start-id n)])
                (struct-copy prop-net-cold (prop-network-cold net)
                  [merge-fns (tchamp-freeze t-merge)]
                  [next-cell-id (+ start-id n)]))]))
  (values new-net ids))

;; Query a cell's direction. Returns 'ascending (default) or 'descending.
(define (net-cell-direction net cid)
  (define dir (champ-lookup (prop-network-cell-dirs net)
                             (cell-id-hash cid) cid))
  (if (eq? dir 'none) 'ascending dir))

;; Read a cell's current value.
;; Track 4 Phase 2: TMS-transparent. If the cell holds a tms-cell-value,
;; automatically applies tms-read with the current speculation stack.
;; At depth 0, this returns base directly (one null? check).
;; Errors on unknown cell-id.
(define (net-cell-read net cid)
  (define cell (champ-lookup (prop-network-cells net)
                              (cell-id-hash cid) cid))
  (if (eq? cell 'none)
      (error 'net-cell-read "unknown cell: ~a" cid)
      (let ([v (prop-cell-value cell)])
        (if (tms-cell-value? v)
            (tms-read v (current-speculation-stack))
            v))))

;; Read a cell's raw value without TMS unwrapping.
;; Used for commit operations and provenance inspection where
;; the full tms-cell-value tree is needed.
(define (net-cell-read-raw net cid)
  (define cell (champ-lookup (prop-network-cells net)
                              (cell-id-hash cid) cid))
  (if (eq? cell 'none)
      (error 'net-cell-read-raw "unknown cell: ~a" cid)
      (prop-cell-value cell)))

;; Write a value to a cell: computes merge-fn(old, new).
;; Track 4 Phase 2: TMS-transparent. If the cell holds a tms-cell-value and
;; the new value is NOT a tms-cell-value (i.e., a plain domain value from a
;; propagator or solve-meta!), wraps it via tms-write at the current speculation
;; depth. This allows all existing code to write plain values to TMS cells.
;; If the merged value equals the old value, returns the network unchanged.
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
  ;; TMS-transparent write: wrap plain values into TMS tree structure
  (define actual-new-val
    (cond
      [(and (tms-cell-value? old-val) (not (tms-cell-value? new-val)))
       ;; Plain value → insert at current speculation depth in the tree
       (tms-write old-val (current-speculation-stack) new-val)]
      [else new-val]))
  (define merged (merge-fn old-val actual-new-val))
  (if (or (eq? merged old-val) (equal? merged old-val))
      net  ;; No change — return same network (critical for termination)
      (let* (;; B2f Phase 0: count writes that actually change the CHAMP
             [cc (current-quiescence-change-counter)]
             [_ (when cc (set-box! cc (add1 (unbox cc))))]
             [new-cell (struct-copy prop-cell cell [value merged])]
             [new-cells (champ-insert cells h cid new-cell)]
             ;; Enqueue dependents
             [deps (champ-keys (prop-cell-dependents cell))]
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
;; TMS Cells — Track 4 Phase 1
;; ========================================
;;
;; Assumption-tagged cell values for speculation. A TMS cell stores a
;; recursive CHAMP tree mirroring the nesting structure of speculation.
;;
;; At depth 0 (no active speculation), reads return `base` directly —
;; single null? check, no overhead. During speculation, reads navigate
;; the tree via the speculation stack (O(d) CHAMP lookups, d = depth).
;;
;; Design reference: docs/tracking/2026-03-16_TRACK4_ATMS_SPECULATION.md §3.2

;; The recursive tree node for TMS cell values.
;; base: unconditional value (always visible at depth 0)
;; branches: hasheq assumption-id → (value | tms-cell-value)
;;   If a branch value is itself a tms-cell-value, that means the
;;   assumption's speculation had sub-speculations (nesting).
;;   If it's a plain value, it's a leaf.
(struct tms-cell-value (base branches) #:transparent)

;; Sentinel for TMS cell initial state (distinguishable from user bots).
;; Used as the base value for TMS cells created during speculation nesting.
(define tms-bot 'tms-bot)

;; Read a TMS cell value under the current speculation stack.
;; stack: (listof assumption-id) — current speculation nesting, outermost first
;; Returns: the value visible under the current worldview.
;;
;; At depth 0 (stack = '()), returns base directly.
;; At depth d, follows the stack through branches, falling back to base
;; at each level if no write exists for that assumption.
(define (tms-read cell-val stack)
  (cond
    [(not (tms-cell-value? cell-val)) cell-val]  ;; non-TMS cell — pass through
    [(null? stack) (tms-cell-value-base cell-val)]
    [else
     (define branch (hash-ref (tms-cell-value-branches cell-val)
                              (car stack) #f))
     (cond
       [(not branch) (tms-read cell-val (cdr stack))]   ;; no write at this depth → try outer hypothesis
       [(tms-cell-value? branch) (tms-read branch (cdr stack))]  ;; recurse into sub-tree
       ;; Leaf value — but if there are deeper stack entries, we still return
       ;; the leaf (it was written at this depth, deeper speculation hasn't overridden)
       [else branch])]))

;; Write a value into a TMS cell at the current speculation depth.
;; stack: (listof assumption-id) — current speculation nesting, outermost first
;; value: the value to write
;; Returns: updated tms-cell-value with the value inserted at the correct depth.
;;
;; At depth 0 (stack = '()), updates base (unconditional write).
;; At depth d, performs nested CHAMP insert following the stack.
;; O(d) nested CHAMP updates, each creating new nodes with structural sharing.
(define (tms-write cell-val stack value)
  (cond
    [(null? stack)
     ;; Unconditional write — update base
     (struct-copy tms-cell-value cell-val [base value])]
    [(null? (cdr stack))
     ;; Leaf of stack — insert/update in branches
     (struct-copy tms-cell-value cell-val
       [branches (hash-set (tms-cell-value-branches cell-val)
                           (car stack) value)])]
    [else
     ;; Deeper — recurse into existing branch or create new sub-tree
     (define existing (hash-ref (tms-cell-value-branches cell-val)
                                (car stack)
                                #f))
     (define sub-tree
       (cond
         [(tms-cell-value? existing) existing]
         [existing (tms-cell-value existing (hasheq))]  ;; promote leaf to sub-tree
         [else (tms-cell-value tms-bot (hasheq))]))      ;; fresh sub-tree
     (struct-copy tms-cell-value cell-val
       [branches (hash-set (tms-cell-value-branches cell-val)
                           (car stack)
                           (tms-write sub-tree (cdr stack) value))])]))

;; Commit a speculation: promote the speculative value to base.
;; assumption-id: the assumption being committed
;; Returns: updated tms-cell-value with base updated.
;;
;; The branch entry {H → V} remains for provenance — records that V
;; came from speculation H. Base is updated to V so depth-0 reads
;; see the committed value directly.
(define (tms-commit cell-val assumption-id)
  (cond
    [(not (tms-cell-value? cell-val)) cell-val]
    [else
     (define branch-val (hash-ref (tms-cell-value-branches cell-val)
                                  assumption-id #f))
     (cond
       [(not branch-val) cell-val]  ;; no write under this assumption — nothing to commit
       [(tms-cell-value? branch-val)
        ;; Sub-tree: flatten — merge sub-tree's contents into outer cell.
        ;; The sub-tree has its own base and branches. Committing means:
        ;; - If sub-tree base is not tms-bot, promote it to outer base
        ;; - Merge sub-tree branches into outer branches (sub-tree wins on conflict)
        ;; - Remove the committed assumption's branch entry
        ;; This handles nested speculation correctly: inner writes that nested
        ;; under outer hypotheses get lifted to become direct outer branches.
        (define sub-base (tms-cell-value-base branch-val))
        (define new-base
          (if (eq? sub-base tms-bot)
              (tms-cell-value-base cell-val)   ;; keep outer base
              sub-base))                        ;; promote sub-tree's base
        (define outer-branches-sans-committed
          (hash-remove (tms-cell-value-branches cell-val) assumption-id))
        (define new-branches
          (for/fold ([acc outer-branches-sans-committed])
                    ([(k v) (in-hash (tms-cell-value-branches branch-val))])
            (hash-set acc k v)))
        (tms-cell-value new-base new-branches)]
       [else
        ;; Leaf value: promote to base
        (struct-copy tms-cell-value cell-val
          [base branch-val])])]))

;; Track 6 Phase 2+3: Commit an assumption across all TMS cells in the network.
;; For each cell whose value is a tms-cell-value, applies tms-commit to promote
;; the assumption's branch value to the base. Non-TMS cells are unaffected.
;; Returns the updated network.
(define (net-commit-assumption net assumption-id)
  (define cells (prop-network-cells net))
  (define new-cells
    (champ-fold cells
      (lambda (cid cell acc)
        (define v (prop-cell-value cell))
        (if (tms-cell-value? v)
            (let ([committed (tms-commit v assumption-id)])
              (if (eq? committed v)
                  acc  ;; no change
                  (champ-insert acc (cell-id-hash cid) cid
                                (struct-copy prop-cell cell [value committed]))))
            acc))
      cells))
  (struct-copy prop-network net
    [warm (struct-copy prop-net-warm (prop-network-warm net)
            [cells new-cells])]))

;; Track 6 Phase 4: Retract an assumption from a TMS cell value.
;; Removes the branch for assumption-id, reverting to the state before
;; writes under that assumption. If the cell has nested sub-trees,
;; the entire sub-tree rooted at assumption-id is removed.
;; Returns: updated tms-cell-value with the assumption's branch removed.
(define (tms-retract cell-val assumption-id)
  (cond
    [(not (tms-cell-value? cell-val)) cell-val]
    [else
     (define branches (tms-cell-value-branches cell-val))
     (define new-branches (hash-remove branches assumption-id))
     (if (eq? branches new-branches)
         cell-val  ;; no branch for this assumption — nothing to retract
         (struct-copy tms-cell-value cell-val [branches new-branches]))]))

;; Track 6 Phase 4: Retract an assumption across all TMS cells in the network.
;; For each cell whose value is a tms-cell-value, applies tms-retract to remove
;; the assumption's branch. Non-TMS cells are unaffected.
;; Returns the updated network.
(define (net-retract-assumption net assumption-id)
  (define cells (prop-network-cells net))
  (define new-cells
    (champ-fold cells
      (lambda (cid cell acc)
        (define v (prop-cell-value cell))
        (if (tms-cell-value? v)
            (let ([retracted (tms-retract v assumption-id)])
              (if (eq? retracted v)
                  acc  ;; no change
                  (champ-insert acc (cell-id-hash cid) cid
                                (struct-copy prop-cell cell [value retracted]))))
            acc))
      cells))
  (struct-copy prop-network net
    [warm (struct-copy prop-net-warm (prop-network-warm net)
            [cells new-cells])]))

;; Merge two TMS cell values (recursive tree merge).
;; Per-branch: latest write wins (same assumption can't produce two
;; different values at the same depth). Cross-branch: tree preserves both.
;; Base merge uses identity semantics (new base wins) — for domain-aware
;; merging, use make-tms-merge with a domain merge function.
(define (merge-tms-cell old new)
  (cond
    [(eq? old 'infra-bot) new]
    [(eq? new 'infra-bot) old]
    [(and (tms-cell-value? old) (tms-cell-value? new))
     ;; Merge trees: union branches, recurse on shared keys
     (define merged-branches
       (for/fold ([acc (tms-cell-value-branches old)])
                 ([(k v) (in-hash (tms-cell-value-branches new))])
         (define existing (hash-ref acc k #f))
         (hash-set acc k
           (cond
             [(not existing) v]
             [(and (tms-cell-value? existing) (tms-cell-value? v))
              (merge-tms-cell existing v)]  ;; recursive merge
             [else v]))))  ;; leaf: latest write wins
     (tms-cell-value (tms-cell-value-base new) merged-branches)]
    ;; If old is tms-cell-value but new isn't (or vice versa), new wins
    [else new]))

;; Create a TMS merge function that applies a domain merge at base/leaf level.
;; domain-merge: (old-val new-val → merged-val) — the underlying lattice join.
;; Returns a merge function suitable for use as a cell's merge-fn.
;;
;; This is essential for cells where the domain merge can detect contradictions
;; (e.g., type-lattice-merge produces type-top when types conflict).
(define (make-tms-merge domain-merge)
  (define (tms-merge old new)
    (cond
      [(eq? old 'infra-bot) new]
      [(eq? new 'infra-bot) old]
      [(and (tms-cell-value? old) (tms-cell-value? new))
       ;; Merge bases using domain merge
       (define merged-base (domain-merge (tms-cell-value-base old)
                                         (tms-cell-value-base new)))
       ;; Merge branches: union, recurse on shared keys
       (define merged-branches
         (for/fold ([acc (tms-cell-value-branches old)])
                   ([(k v) (in-hash (tms-cell-value-branches new))])
           (define existing (hash-ref acc k #f))
           (hash-set acc k
             (cond
               [(not existing) v]
               [(and (tms-cell-value? existing) (tms-cell-value? v))
                (tms-merge existing v)]  ;; recursive merge
               [else v]))))  ;; leaf: latest write wins
       (tms-cell-value merged-base merged-branches)]
      [else new]))
  tms-merge)

;; Create a new TMS cell in the network.
;; initial-value: the starting lattice value (e.g., type-bot)
;; domain-merge: optional domain merge function for base/leaf values.
;;   If provided, uses make-tms-merge to create a domain-aware TMS merge.
;;   If #f, uses merge-tms-cell (new base wins, no domain merge).
;; contradicts?: optional contradiction predicate (applied to base value after merge)
;; Returns: (values new-network cell-id)
;;
;; The cell is initialized with (tms-cell-value initial-value (hasheq)).
(define (net-new-tms-cell net initial-value [domain-merge #f] [contradicts? #f])
  (define tms-merge-fn
    (if domain-merge
        (make-tms-merge domain-merge)
        merge-tms-cell))
  (define tms-contradicts?
    (and contradicts?
         (lambda (v)
           (if (tms-cell-value? v)
               (contradicts? (tms-cell-value-base v))
               (contradicts? v)))))
  (net-new-cell net
                (tms-cell-value initial-value (hasheq))
                tms-merge-fn
                tms-contradicts?))

;; ========================================
;; TMS Speculation Stack
;; ========================================

;; The current speculation nesting, outermost first.
;; '() = not speculating (depth 0).
;; Pushed on speculation entry (parameterize), popped automatically on exit.
;; Used by tms-read/tms-write to navigate the recursive CHAMP tree.
;;
;; Lives here (not in elab-speculation-bridge.rkt) to avoid circular deps:
;; metavar-store.rkt needs this for TMS-aware reads, but
;; elab-speculation-bridge.rkt depends on metavar-store.rkt.
(define current-speculation-stack (make-parameter '()))

;; Track 8 C5a: Global scheduler override.
;; When #t, ALL run-to-quiescence calls use BSP scheduling instead of Gauss-Seidel.
;; This is the correct level for a full A/B comparison — it catches every quiescence
;; invocation (unify.rkt, elab-speculation.rkt, bridges, tabling, not just metavar-store).
(define current-use-bsp-scheduler? (make-parameter #f))

;; CALM topology guard: when #t, fire functions must not modify network topology.
;; net-add-propagator and net-new-cell will error during BSP fire rounds.
;; Topology changes require stratum boundaries (stratification).
(define current-bsp-fire-round? (make-parameter #f))

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
(define (net-add-propagator net input-ids output-ids fire-fn)
  ;; CALM topology guard: dynamic topology violates order-independence.
  (when (current-bsp-fire-round?)
    (error 'net-add-propagator
           "CALM violation: cannot add propagators during BSP fire round. ~
            Topology changes require stratum boundaries."))
  (define pid (prop-id (prop-network-next-prop-id net)))
  (define prop (propagator input-ids output-ids fire-fn))
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
          (let ([new-deps (champ-insert (prop-cell-dependents cell)
                                         ph pid #t)])
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
     ;; Schedule initial firing
     [hot (struct-copy prop-net-hot (prop-network-hot net)
            [worklist (cons pid (prop-network-worklist net))])])
   pid))

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
             (let ([net* ((propagator-fire-fn prop) net)])
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
           (let ([net* ((propagator-fire-fn prop) net)])
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
(struct fire-result (value-writes new-cells) #:transparent)

(define (fire-and-collect-writes snapshot-net pid)
  (define prop (champ-lookup (prop-network-propagators snapshot-net)
                              (prop-id-hash pid) pid))
  (when (eq? prop 'none)
    (error 'fire-and-collect-writes "unknown propagator: ~a" pid))
  (define snapshot-next-id (prop-network-next-cell-id snapshot-net))
  ;; Fire propagator against snapshot (with CALM topology guard)
  (define result-net
    (parameterize ([current-bsp-fire-round? #t])
      ((propagator-fire-fn prop) snapshot-net)))
  (define result-next-id (prop-network-next-cell-id result-net))
  ;; Diff output cells: extract (cell-id . new-value) for changed cells
  (define value-writes
    (for/fold ([writes '()])
              ([cid (in-list (propagator-outputs prop))])
      (define old (net-cell-read snapshot-net cid))
      (define new (net-cell-read result-net cid))
      (if (equal? old new)
          writes
          (cons (cons cid new) writes))))
  ;; PAR Track 1 D.3: Capture new cells via next-cell-id comparison.
  ;; Cells with ids in [snapshot-next-id .. result-next-id) were created
  ;; by the fire function. Extract them from result-net.
  (define new-cells
    (if (= snapshot-next-id result-next-id)
        '()  ;; No new cells — common case, zero overhead
        (for/list ([i (in-range snapshot-next-id result-next-id)])
          (define cid (cell-id i))
          (define cell (champ-lookup (prop-network-cells result-net)
                                     (cell-id-hash cid) cid))
          (define merge-fn (champ-lookup (prop-network-merge-fns result-net)
                                         (cell-id-hash cid) cid))
          (define contra-fn (champ-lookup (prop-network-contradiction-fns result-net)
                                          (cell-id-hash cid) cid))
          (define widen-fn (champ-lookup (prop-network-widen-fns result-net)
                                         (cell-id-hash cid) cid))
          (define cell-dir (champ-lookup (prop-network-cell-dirs result-net)
                                         (cell-id-hash cid) cid))
          (list cid cell merge-fn contra-fn widen-fn cell-dir))))
  (fire-result value-writes new-cells))

;; Apply collected writes from all propagators to a network.
;; net-cell-write handles merge, dependent enqueuing, and contradiction.
;; Multiple writes to the same cell from different propagators are fine —
;; lattice join is commutative and associative, so order doesn't matter.
;; PAR Track 1 D.3: also applies new cells from fire-result structs.
(define (bulk-merge-writes net all-results)
  (for/fold ([net net])
            ([result (in-list all-results)])
    ;; Handle both old-style write lists and new fire-result structs
    (define-values (writes new-cells)
      (if (fire-result? result)
          (values (fire-result-value-writes result)
                  (fire-result-new-cells result))
          (values result '())))
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
    (for/fold ([n net-with-cells])
              ([w (in-list writes)])
      (net-cell-write n (car w) (cdr w)))))

;; Fire all propagators sequentially against the same snapshot.
;; Returns a list of write-lists, one per propagator.
(define (sequential-fire-all snapshot-net pids)
  (map (lambda (pid) (fire-and-collect-writes snapshot-net pid))
       pids))

;; BSP run-to-quiescence: fire all worklist propagators per round.
;; executor: (snapshot-net pids → (listof (listof (cons cell-id value))))
;; Defaults to sequential-fire-all. Use make-parallel-fire-all for parallelism.
;; When current-bsp-observer is set, emits a bsp-round record after each round.
(define (run-to-quiescence-bsp net #:executor [executor sequential-fire-all])
  (define observer (current-bsp-observer))
  (let loop ([net net] [round-number 0])
    (cond
      ;; Already contradicted — stop
      [(prop-network-contradiction net) net]
      ;; Fuel exhausted — stop
      [(<= (prop-network-fuel net) 0) net]
      ;; Worklist empty — quiescent (fixed point reached)
      [(null? (prop-network-worklist net)) net]
      ;; Fire all worklist propagators in one BSP round
      [else
       (let* (;; 1. Deduplicate worklist
              [pids (dedup-pids (prop-network-worklist net))]
              [n (length pids)]
              ;; 2. Clear worklist and decrease fuel
              [snapshot (struct-copy prop-network net
                          [hot (struct-copy prop-net-hot (prop-network-hot net)
                                 [worklist '()]
                                 [fuel (- (prop-network-fuel net) n)])])]
              ;; 3. Fire all propagators against snapshot
              [all-writes (executor snapshot pids)]
              ;; 4. Bulk-merge writes into snapshot
              [merged (bulk-merge-writes snapshot all-writes)])
         ;; 5. Notify observer if present (zero cost when #f)
         (when observer
           (define diffs
             (for/fold ([acc '()])
                       ([writes (in-list all-writes)]
                        [pid (in-list pids)])
               (for/fold ([acc acc])
                         ([w (in-list writes)])
                 (cons (cell-diff (car w)
                                  (net-cell-read snapshot (car w))
                                  (cdr w)
                                  pid)
                       acc))))
           (observer (bsp-round round-number merged (reverse diffs) pids
                                (prop-network-contradiction merged) '())))
         (loop merged (add1 round-number)))])))

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
        (let* ([futures
                (map (lambda (pid)
                       (future
                        (lambda ()
                          (fire-and-collect-writes snapshot-net pid))))
                     pids)]
               [results (map touch futures)])
          results))))

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
                            widen-fn narrow-fn [contradicts? #f])
  (define-values (net1 cid) (net-new-cell net initial-value merge-fn contradicts?))
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
  ;; Track 4 Phase 2: TMS-transparent write (same pattern as net-cell-write)
  (define actual-new-val
    (cond
      [(and (tms-cell-value? old-val) (not (tms-cell-value? new-val)))
       (tms-write old-val (current-speculation-stack) new-val)]
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
           (let* ([result-net ((propagator-fire-fn prop) net*)]
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
                  [result-net ((propagator-fire-fn prop) snapshot)]
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
