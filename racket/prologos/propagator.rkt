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
         racket/future)   ;; for future, touch, processor-count

(provide
 ;; Identity types
 (struct-out cell-id)
 (struct-out prop-id)
 ;; Core structs
 (struct-out prop-cell)
 (struct-out propagator)
 (struct-out prop-network)
 ;; Hash helpers (for CHAMP keying)
 cell-id-hash
 prop-id-hash
 ;; Network construction
 make-prop-network
 ;; Cell operations
 net-new-cell
 net-cell-read
 net-cell-write
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
 net-fuel-remaining)

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
(struct prop-network
  (cells
   propagators
   worklist
   next-cell-id
   next-prop-id
   fuel
   contradiction
   merge-fns
   contradiction-fns)
  #:transparent)

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
  (prop-network champ-empty    ;; cells
                champ-empty    ;; propagators
                '()            ;; worklist
                0              ;; next-cell-id
                0              ;; next-prop-id
                fuel           ;; fuel
                #f             ;; no contradiction
                champ-empty    ;; merge-fns
                champ-empty))  ;; contradiction-fns

;; ========================================
;; Cell Operations
;; ========================================

;; Add a new cell to the network.
;; initial-value: the starting lattice value (typically bot)
;; merge-fn: (old-val new-val → merged-val) — the lattice join
;; contradicts?: optional (val → Bool) predicate for contradiction detection
;; Returns: (values new-network cell-id)
(define (net-new-cell net initial-value merge-fn [contradicts? #f])
  (define id (cell-id (prop-network-next-cell-id net)))
  (define cell (prop-cell initial-value champ-empty))
  (define h (cell-id-hash id))
  (define net*
    (struct-copy prop-network net
      [cells (champ-insert (prop-network-cells net) h id cell)]
      [merge-fns (champ-insert (prop-network-merge-fns net) h id merge-fn)]
      [next-cell-id (+ 1 (prop-network-next-cell-id net))]))
  (values
   (if contradicts?
       (struct-copy prop-network net*
         [contradiction-fns
          (champ-insert (prop-network-contradiction-fns net*)
                        h id contradicts?)])
       net*)
   id))

;; Read a cell's current value.
;; Errors on unknown cell-id.
(define (net-cell-read net cid)
  (define cell (champ-lookup (prop-network-cells net)
                              (cell-id-hash cid) cid))
  (if (eq? cell 'none)
      (error 'net-cell-read "unknown cell: ~a" cid)
      (prop-cell-value cell)))

;; Write a value to a cell: computes merge-fn(old, new).
;; If the merged value equals the old value, returns the network unchanged.
;; Otherwise: updates the cell, enqueues dependent propagators, and
;; optionally checks the contradiction predicate.
(define (net-cell-write net cid new-val)
  (define cells (prop-network-cells net))
  (define h (cell-id-hash cid))
  (define cell (champ-lookup cells h cid))
  (when (eq? cell 'none)
    (error 'net-cell-write "unknown cell: ~a" cid))
  (define merge-fn
    (champ-lookup (prop-network-merge-fns net) h cid))
  (define old-val (prop-cell-value cell))
  (define merged (merge-fn old-val new-val))
  (if (equal? merged old-val)
      net  ;; No change — return same network (critical for termination)
      (let* ([new-cell (struct-copy prop-cell cell [value merged])]
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
                     [cells new-cells]
                     [worklist new-wl])])
        (if contradicted?
            (struct-copy prop-network net* [contradiction cid])
            net*))))

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
  (define pid (prop-id (prop-network-next-prop-id net)))
  (define prop (propagator input-ids output-ids fire-fn))
  (define ph (prop-id-hash pid))
  ;; Register pid as dependent of each input cell
  (define new-cells
    (for/fold ([cells (prop-network-cells net)])
              ([cid (in-list input-ids)])
      (define ch (cell-id-hash cid))
      (define cell (champ-lookup cells ch cid))
      (if (eq? cell 'none)
          cells  ;; unknown cell — skip (defensive)
          (let ([new-deps (champ-insert (prop-cell-dependents cell)
                                         ph pid #t)])
            (champ-insert cells ch cid
                          (struct-copy prop-cell cell
                            [dependents new-deps]))))))
  (values
   (struct-copy prop-network net
     [cells new-cells]
     [propagators (champ-insert (prop-network-propagators net) ph pid prop)]
     [next-prop-id (+ 1 (prop-network-next-prop-id net))]
     ;; Schedule initial firing
     [worklist (cons pid (prop-network-worklist net))])
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
(define (run-to-quiescence net)
  (cond
    ;; Already contradicted — stop
    [(prop-network-contradiction net) net]
    ;; Fuel exhausted — stop
    [(<= (prop-network-fuel net) 0) net]
    ;; Worklist empty — quiescent (fixed point reached)
    [(null? (prop-network-worklist net)) net]
    ;; Fire next propagator
    [else
     (let* ([pid (car (prop-network-worklist net))]
            [rest (cdr (prop-network-worklist net))]
            [net* (struct-copy prop-network net
                    [worklist rest]
                    [fuel (sub1 (prop-network-fuel net))])]
            [prop (champ-lookup (prop-network-propagators net*)
                                (prop-id-hash pid) pid)])
       (if (eq? prop 'none)
           ;; Propagator removed or unknown — skip
           (run-to-quiescence net*)
           ;; Fire: pure function from network to network
           (run-to-quiescence ((propagator-fire-fn prop) net*))))]))

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
(define (fire-and-collect-writes snapshot-net pid)
  (define prop (champ-lookup (prop-network-propagators snapshot-net)
                              (prop-id-hash pid) pid))
  (when (eq? prop 'none)
    (error 'fire-and-collect-writes "unknown propagator: ~a" pid))
  ;; Fire propagator against snapshot
  (define result-net ((propagator-fire-fn prop) snapshot-net))
  ;; Diff output cells: extract (cell-id . new-value) for changed cells
  (for/fold ([writes '()])
            ([cid (in-list (propagator-outputs prop))])
    (define old (net-cell-read snapshot-net cid))
    (define new (net-cell-read result-net cid))
    (if (equal? old new)
        writes
        (cons (cons cid new) writes))))

;; Apply collected writes from all propagators to a network.
;; net-cell-write handles merge, dependent enqueuing, and contradiction.
;; Multiple writes to the same cell from different propagators are fine —
;; lattice join is commutative and associative, so order doesn't matter.
(define (bulk-merge-writes net all-writes)
  (for/fold ([net net])
            ([writes (in-list all-writes)])
    (for/fold ([net net])
              ([w (in-list writes)])
      (net-cell-write net (car w) (cdr w)))))

;; Fire all propagators sequentially against the same snapshot.
;; Returns a list of write-lists, one per propagator.
(define (sequential-fire-all snapshot-net pids)
  (map (lambda (pid) (fire-and-collect-writes snapshot-net pid))
       pids))

;; BSP run-to-quiescence: fire all worklist propagators per round.
;; executor: (snapshot-net pids → (listof (listof (cons cell-id value))))
;; Defaults to sequential-fire-all. Use make-parallel-fire-all for parallelism.
(define (run-to-quiescence-bsp net #:executor [executor sequential-fire-all])
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
                       [worklist '()]
                       [fuel (- (prop-network-fuel net) n)])]
            ;; 3. Fire all propagators against snapshot
            [all-writes (executor snapshot pids)]
            ;; 4. Bulk-merge writes into snapshot
            [merged (bulk-merge-writes snapshot all-writes)])
       (run-to-quiescence-bsp merged #:executor executor))]))

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
