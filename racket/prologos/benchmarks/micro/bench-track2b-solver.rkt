#lang racket/base

;; bench-track2b-solver.rkt — BSP-LE Track 2B Phase 0b: Solver Micro-Benchmarks
;;
;; Measures infrastructure costs for open design questions:
;;
;;   S1: Fact-row PU overhead at N=1,2,4,8,16,32
;;       (tagged-cell-value writes + reads vs direct logic-var-write)
;;   S2: Decision-cell narrowing cost (clause selection mechanism)
;;   S3: fork-prop-network + run-to-quiescence cost (NAF baseline)
;;   S4: Thread spawn overhead (async NAF cost model)
;;   S5: Gray code vs sequential CHAMP structural sharing
;;   S6: Discrimination map lookup cost
;;
;; Run: racket benchmarks/micro/bench-track2b-solver.rkt

(require "../../tools/bench-micro.rkt"
         "../../propagator.rkt"
         "../../decision-cell.rkt"
         "../../relations.rkt"
         "../../solver.rkt"
         "../../syntax.rkt"
         racket/list)

;; ============================================================
;; Helpers
;; ============================================================

;; Build a network with N cells and one propagator per cell
(define (make-solver-net n-cells)
  (for/fold ([net (make-prop-network)])
            ([i (in-range n-cells)])
    (define-values (net2 _cid)
      (net-new-cell net 'bot (lambda (a b) b)))
    net2))

;; Build a relation-info with N fact rows
(define (make-n-fact-relation name n-facts n-args)
  (define rows
    (for/list ([i (in-range n-facts)])
      (fact-row (for/list ([j (in-range n-args)])
                  (+ (* i 100) j)))))
  (relation-info name n-args
    (list (variant-info
           (for/list ([j (in-range n-args)])
             (param-info (string->symbol (format "x~a" j)) 'free))
           '()    ;; no clauses
           rows))
    #f #f))

;; Build a relation-info with N clauses (each unifies x to a distinct value)
(define (make-n-clause-relation name n-clauses)
  (define clauses
    (for/list ([i (in-range n-clauses)])
      (clause-info
       (list (goal-desc 'unify (list 'x i))))))
  (relation-info name 1
    (list (variant-info
           (list (param-info 'x 'free))
           clauses
           '()))   ;; no facts
    #f #f))

;; Build a simple relation store
(define (make-store . rels)
  (for/fold ([s (make-relation-store)])
            ([r (in-list rels)])
    (relation-register s r)))

;; Build a solver config
(define test-config
  (make-solver-config (hasheq 'strategy 'atms)))

;; ============================================================
;; S1: Fact-Row Scaling — Current (last-write-wins) Cost
;; ============================================================
;; Measures how much solve-goal-propagator costs as N grows with
;; the CURRENT (unfixed) fact handling. This is our baseline.

(define fact1-rel (make-n-fact-relation 'f1 1 1))
(define fact2-rel (make-n-fact-relation 'f2 2 1))
(define fact4-rel (make-n-fact-relation 'f4 4 1))
(define fact8-rel (make-n-fact-relation 'f8 8 1))
(define fact16-rel (make-n-fact-relation 'f16 16 1))
(define fact32-rel (make-n-fact-relation 'f32 32 1))

(define (bench-fact-query rel name)
  (define store (make-store rel))
  (bench (format "solve ~a facts (current) x1000" name)
    (for ([_ (in-range 1000)])
      (solve-goal-propagator test-config store
                             (relation-info-name rel)
                             (list 'x)
                             '(x)))))

(bench-fact-query fact1-rel "N=1")
(bench-fact-query fact2-rel "N=2")
(bench-fact-query fact4-rel "N=4")
(bench-fact-query fact8-rel "N=8")
(bench-fact-query fact16-rel "N=16")
(bench-fact-query fact32-rel "N=32")

;; ============================================================
;; S2: Decision-Cell Operations — Clause Selection Cost Model
;; ============================================================
;; These measure the COMPONENTS of clause decision-cell narrowing.

;; Clause narrowing simulation: hasheq filtering (the core operation)
;; This is what the argument-watching propagator does: given N clause indices,
;; filter to only those matching the bound argument.

(define clause-set-4 (for/hasheq ([i 4]) (values i #t)))
(define clause-set-8 (for/hasheq ([i 8]) (values i #t)))
(define clause-set-16 (for/hasheq ([i 16]) (values i #t)))
(define clause-set-32 (for/hasheq ([i 32]) (values i #t)))

(define (narrow-clause-set cs keep-indices)
  (for/hasheq ([(k v) (in-hash cs)]
               #:when (hash-has-key? keep-indices k))
    (values k v)))

(define keep-1 (hasheq 2 #t))
(define keep-2 (hasheq 3 #t 7 #t))
(define keep-4 (hasheq 2 #t 5 #t 11 #t 14 #t))
(define keep-8 (hasheq 1 #t 4 #t 7 #t 10 #t 15 #t 20 #t 25 #t 30 #t))

(bench "narrow 4→1 clause x100000"
  (for ([_ (in-range 100000)])
    (narrow-clause-set clause-set-4 keep-1)))

(bench "narrow 8→2 clauses x100000"
  (for ([_ (in-range 100000)])
    (narrow-clause-set clause-set-8 keep-2)))

(bench "narrow 16→4 clauses x50000"
  (for ([_ (in-range 50000)])
    (narrow-clause-set clause-set-16 keep-4)))

(bench "narrow 32→8 clauses x20000"
  (for ([_ (in-range 20000)])
    (narrow-clause-set clause-set-32 keep-8)))

;; ============================================================
;; S3: fork-prop-network + run-to-quiescence (NAF Baseline)
;; ============================================================
;; Measures the cost components of NAF evaluation.

;; Fork cost (should be O(1) — two struct allocations)
(define base-net-10 (make-solver-net 10))
(define base-net-50 (make-solver-net 50))

(bench "fork-prop-network (10 cells) x20000"
  (for ([_ (in-range 20000)])
    (fork-prop-network base-net-10)))

(bench "fork-prop-network (50 cells) x20000"
  (for ([_ (in-range 20000)])
    (fork-prop-network base-net-50)))

;; Quiescence on empty forked network (pure scheduler overhead)
(bench "run-to-quiescence on forked (10 cells, empty) x5000"
  (for ([_ (in-range 5000)])
    (run-to-quiescence (fork-prop-network base-net-10))))

;; Gauss-Seidel vs BSP on same forked network
(bench "run-to-quiescence-GS on forked (10 cells) x5000"
  (for ([_ (in-range 5000)])
    (parameterize ([current-use-bsp-scheduler? #f])
      (run-to-quiescence (fork-prop-network base-net-10)))))

(bench "run-to-quiescence-BSP on forked (10 cells) x5000"
  (for ([_ (in-range 5000)])
    (parameterize ([current-use-bsp-scheduler? #t])
      (run-to-quiescence (fork-prop-network base-net-10)))))

;; ============================================================
;; S4: Thread Spawn Overhead (Async NAF Cost Model)
;; ============================================================
;; Measures the overhead of spawning a thread for async NAF.

(bench "thread spawn+join (no-op) x5000"
  (for ([_ (in-range 5000)])
    (define ch (make-channel))
    (thread (lambda () (channel-put ch 'done)))
    (channel-get ch)))

(bench "thread spawn+join (fork+quiesce) x2000"
  (for ([_ (in-range 2000)])
    (define ch (make-channel))
    (thread (lambda ()
              (define net (fork-prop-network base-net-10))
              (define net* (run-to-quiescence net))
              (channel-put ch net*)))
    (channel-get ch)))

;; Compare: sync fork+quiesce (no thread) — the baseline
(bench "sync fork+quiesce (no thread) x2000"
  (for ([_ (in-range 2000)])
    (define net (fork-prop-network base-net-10))
    (run-to-quiescence net)))

;; ============================================================
;; S5: Tagged-Cell-Value Operations at Scale
;; ============================================================
;; Measures tagged-cell-read/write at varying N entries (fact-row PU
;; creates N tagged entries per cell).

(define (make-tagged-n n)
  (for/fold ([tv (tagged-cell-value 'base '())])
            ([i (in-range n)])
    (tagged-cell-write tv (expt 2 i) (format "val-~a" i))))

(define tagged-4 (make-tagged-n 4))
(define tagged-8 (make-tagged-n 8))
(define tagged-16 (make-tagged-n 16))
(define tagged-32 (make-tagged-n 32))

;; Read at max specificity (worst case: scan all entries)
(define bitmask-all-4 (sub1 (expt 2 4)))    ;; 0b1111
(define bitmask-all-8 (sub1 (expt 2 8)))    ;; 0b11111111
(define bitmask-all-16 (sub1 (expt 2 16)))  ;; 16 bits
(define bitmask-all-32 (sub1 (expt 2 32)))  ;; 32 bits

(bench "tagged-cell-read N=4 entries x100000"
  (for ([_ (in-range 100000)])
    (tagged-cell-read tagged-4 bitmask-all-4)))

(bench "tagged-cell-read N=8 entries x100000"
  (for ([_ (in-range 100000)])
    (tagged-cell-read tagged-8 bitmask-all-8)))

(bench "tagged-cell-read N=16 entries x50000"
  (for ([_ (in-range 50000)])
    (tagged-cell-read tagged-16 bitmask-all-16)))

(bench "tagged-cell-read N=32 entries x20000"
  (for ([_ (in-range 20000)])
    (tagged-cell-read tagged-32 bitmask-all-32)))

;; Write cost (append to entries list)
(bench "tagged-cell-write to N=4 x100000"
  (for ([_ (in-range 100000)])
    (tagged-cell-write tagged-4 (expt 2 4) 'new-val)))

(bench "tagged-cell-write to N=16 x50000"
  (for ([_ (in-range 50000)])
    (tagged-cell-write tagged-16 (expt 2 16) 'new-val)))

;; ============================================================
;; S6: Discrimination Map Lookup
;; ============================================================
;; Simulates the cost of looking up which clauses match a given
;; value at a given position.

;; Build a discrimination map: position 0 → {val → [clause-indices]}
(define (make-discrim-map n)
  (for/fold ([m (hasheq)])
            ([i (in-range n)])
    (hash-set m i (list i))))

(define discrim-4 (make-discrim-map 4))
(define discrim-8 (make-discrim-map 8))
(define discrim-16 (make-discrim-map 16))
(define discrim-32 (make-discrim-map 32))

(bench "discrim-map lookup (N=4 entries) x500000"
  (for ([_ (in-range 500000)])
    (hash-ref discrim-4 2 #f)))

(bench "discrim-map lookup (N=32 entries) x500000"
  (for ([_ (in-range 500000)])
    (hash-ref discrim-32 16 #f)))

;; ============================================================
;; S7: Full Solver Pipeline — DFS vs Propagator
;; ============================================================
;; End-to-end comparison on simple relations.

(define dfs-config
  (make-solver-config (hasheq 'strategy 'depth-first)))
(define atms-config
  (make-solver-config (hasheq 'strategy 'atms)))

;; Single-fact relation (Tier 1)
(define simple-rel
  (relation-info 'simple 1
    (list (variant-info
           (list (param-info 'x 'free))
           '()
           (list (fact-row (list 42)))))
    #f #f))

(define simple-store (make-store simple-rel))

(bench "DFS: single fact query x2000"
  (for ([_ (in-range 2000)])
    (solve-goal dfs-config simple-store 'simple (list 'x) '(x))))

(bench "ATMS: single fact query x2000"
  (for ([_ (in-range 2000)])
    (solve-goal-propagator atms-config simple-store 'simple (list 'x) '(x))))

;; Multi-clause relation (Tier 2)
(define choice3-rel (make-n-clause-relation 'choice3 3))
(define choice3-store (make-store choice3-rel))

(bench "DFS: 3-clause query x1000"
  (for ([_ (in-range 1000)])
    (solve-goal dfs-config choice3-store 'choice3 (list 'x) '(x))))

(bench "ATMS: 3-clause query x1000"
  (for ([_ (in-range 1000)])
    (solve-goal-propagator atms-config choice3-store 'choice3 (list 'x) '(x))))

;; 8-fact relation (scaling)
(define fact8-store (make-store fact8-rel))

(bench "DFS: 8-fact query x1000"
  (for ([_ (in-range 1000)])
    (solve-goal dfs-config fact8-store 'f8 (list 'x) '(x))))

(bench "ATMS: 8-fact query x1000"
  (for ([_ (in-range 1000)])
    (solve-goal-propagator atms-config fact8-store 'f8 (list 'x) '(x))))
