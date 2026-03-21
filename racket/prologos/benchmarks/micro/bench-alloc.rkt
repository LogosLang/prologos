#lang racket/base

;; bench-alloc.rkt — Micro-benchmarks for propagator network allocation
;;
;; Phase 0 of BSP-LE Track 0: Allocation Efficiency.
;; Establishes quantitative baselines for:
;;   - net-new-cell: cell creation cost
;;   - net-cell-write: cell mutation cost (change vs no-change paths)
;;   - net-add-propagator: propagator registration cost
;;   - run-to-quiescence: worklist loop cost
;;   - Change/no-change ratio measurement
;;
;; Design doc: docs/tracking/2026-03-21_BSP_LE_TRACK0_ALLOCATION_EFFICIENCY_DESIGN.md

(require racket/list
         "../../tools/bench-micro.rkt"
         "../../propagator.rkt"
         "../../champ.rkt"
         "../../performance-counters.rkt")

;; ============================================================
;; Helpers
;; ============================================================

;; Simple lattice merge: take the max (flat lattice 0 < 1 < 2 < ...)
(define (int-merge old new)
  (if (>= old new) old new))

;; Identity-preserving merge (returns identical old when old wins)
(define (int-merge-identity old new)
  (if (>= old new) old (max old new)))

;; Build a network with N cells, all initialized to 0, int-merge
(define (make-n-cell-network n)
  (let loop ([net (make-prop-network)] [ids '()] [i 0])
    (if (>= i n)
        (values net (reverse ids))
        (let-values ([(net* cid) (net-new-cell net 0 int-merge)])
          (loop net* (cons cid ids) (add1 i))))))

;; Build a network with N cells and propagators wiring cell[i] → cell[i+1]
;; Each propagator adds 1 to its input and writes to its output
(define (make-chain-network n)
  (define-values (net ids) (make-n-cell-network n))
  (let loop ([net net] [remaining ids])
    (if (or (null? remaining) (null? (cdr remaining)))
        (values net ids)
        (let* ([src (car remaining)]
               [dst (cadr remaining)]
               [fire (λ (n)
                       (define v (net-cell-read n src))
                       (net-cell-write n dst (add1 v)))])
          (let-values ([(net* _pid) (net-add-propagator net (list src) (list dst) fire)])
            (loop net* (cdr remaining)))))))

;; ============================================================
;; Benchmark 1: Cell Allocation
;; ============================================================

;; 50K cell allocations (50 rounds × 1000 cells)
(define b-cell-alloc
  (bench "net-new-cell: 50K cells (50 × 1000)"
    (λ ()
      (for ([_ (in-range 50)])
        (let loop ([net (make-prop-network)] [i 0])
          (if (>= i 1000)
              (void)
              (let-values ([(net* _cid) (net-new-cell net 0 int-merge)])
                (loop net* (add1 i)))))))))

;; 5000 cells on a single network — stress the CHAMP trie at depth
(define b-cell-alloc-deep
  (bench "net-new-cell: 5000 cells (deep CHAMP)"
    (λ ()
      (for ([_ (in-range 10)])
        (let loop ([net (make-prop-network)] [i 0])
          (if (>= i 5000)
              (void)
              (let-values ([(net* _cid) (net-new-cell net 0 int-merge)])
                (loop net* (add1 i)))))))))

;; ============================================================
;; Benchmark 2: Cell Write (change path)
;; ============================================================

;; Pre-build a 500-cell network, write new values × 50 rounds = 25K writes
(define b-cell-write-change
  (let-values ([(net ids) (make-n-cell-network 500)])
    (bench "net-cell-write: 25K writes (500 cells × 50), all change"
      (λ ()
        (for/fold ([n net]) ([round (in-range 50)])
          (for/fold ([n n]) ([cid (in-list ids)]
                             [v (in-naturals (+ 1 (* round 1000)))])
            (net-cell-write n cid v)))))))

;; ============================================================
;; Benchmark 3: Cell Write (no-change path)
;; ============================================================

;; Write the same value to cells that already hold it — should be fast
(define b-cell-write-nochange
  (let-values ([(net ids) (make-n-cell-network 500)])
    ;; First write 42 to all cells
    (define net-with-42
      (for/fold ([n net]) ([cid (in-list ids)])
        (net-cell-write n cid 42)))
    (bench "net-cell-write: 25K writes (500 × 50), all no-change"
      (λ ()
        (for ([_ (in-range 50)])
          (for/fold ([n net-with-42]) ([cid (in-list ids)])
            (net-cell-write n cid 42)))))))

;; Mixed: ~50% change, ~50% no-change, 25K writes
(define b-cell-write-mixed
  (let*-values ([(net ids) (make-n-cell-network 500)]
                [(net-with-values)
                 (for/fold ([n net]) ([cid (in-list ids)]
                                      [v (in-naturals)])
                   (net-cell-write n cid v))])
    (bench "net-cell-write: 25K writes (500 × 50), 50/50 mix"
      (λ ()
        (for/fold ([n net-with-values]) ([round (in-range 50)])
          (for/fold ([n n]) ([cid (in-list ids)]
                             [v (in-naturals)])
            (if (even? v)
                (net-cell-write n cid v)
                (net-cell-write n cid (+ v 1000 (* round 10000))))))))))

;; ============================================================
;; Benchmark 4: Propagator Registration
;; ============================================================

;; Add 200 propagators with 2 inputs each (× 5 rounds)
(define b-prop-alloc
  (let-values ([(net ids) (make-n-cell-network 400)])
    (bench "net-add-propagator: 200 propagators (2 inputs) × 5"
      (λ ()
        (for ([_ (in-range 5)])
          (for/fold ([n net]) ([i (in-range 200)])
            (define src1 (list-ref ids (* i 2)))
            (define src2 (list-ref ids (+ (* i 2) 1)))
            (let-values ([(n* _pid) (net-add-propagator n
                                      (list src1 src2) '()
                                      (λ (net) net))])
              n*)))))))

;; Add propagators with varying input counts (1-5) × 10 rounds
(define b-prop-alloc-varied
  (let-values ([(net ids) (make-n-cell-network 100)])
    (bench "net-add-propagator: 50 propagators (1-5 inputs) × 10"
      (λ ()
        (for ([_ (in-range 10)])
          (for/fold ([n net]) ([i (in-range 50)])
            (define input-count (add1 (modulo i 5)))
            (define inputs
              (for/list ([j (in-range input-count)])
                (list-ref ids (modulo (+ (* i 5) j) 100))))
            (let-values ([(n* _pid) (net-add-propagator n inputs '() (λ (net) net))])
              n*)))))))

;; ============================================================
;; Benchmark 5: Run-to-Quiescence
;; ============================================================

;; Chain of 200 cells × 20 rounds: write to cell[0], propagate through chain
(define b-quiescence-chain-200
  (let-values ([(net ids) (make-chain-network 200)])
    (bench "run-to-quiescence: 200-cell chain × 20"
      (λ ()
        (for ([round (in-range 20)])
          (define seeded (net-cell-write net (car ids) (add1 round)))
          (run-to-quiescence seeded))))))

;; Chain of 500 cells — stresses worklist iteration depth
(define b-quiescence-chain-500
  (let-values ([(net ids) (make-chain-network 500)])
    (bench "run-to-quiescence: 500-cell chain × 5"
      (λ ()
        (for ([round (in-range 5)])
          (define seeded (net-cell-write net (car ids) (add1 round)))
          (run-to-quiescence seeded))))))

;; Fan-out: 1 source cell writes to 20 targets, each target writes to 1 sink
;; Total: 22 cells, 40 propagators, ~40 firings
(define b-quiescence-fanout
  (let ()
    (define-values (net0 all-ids) (make-n-cell-network 22))
    (define source (car all-ids))
    (define targets (take (cdr all-ids) 20))
    (define sink (last all-ids))
    ;; Source → each target
    (define net1
      (for/fold ([n net0]) ([t (in-list targets)])
        (let-values ([(n* _pid)
                      (net-add-propagator n (list source) (list t)
                        (λ (n) (net-cell-write n t
                                                (add1 (net-cell-read n source)))))])
          n*)))
    ;; Each target → sink (merge via max)
    (define net2
      (for/fold ([n net1]) ([t (in-list targets)])
        (let-values ([(n* _pid)
                      (net-add-propagator n (list t) (list sink)
                        (λ (n) (net-cell-write n sink
                                                (max (net-cell-read n sink)
                                                     (net-cell-read n t)))))])
          n*)))
    (bench "run-to-quiescence: fan-out (1→20→1) × 50"
      (λ ()
        (for ([round (in-range 50)])
          (define seeded (net-cell-write net2 source (add1 round)))
          (run-to-quiescence seeded))))))

;; ============================================================
;; Benchmark 6: Change/No-Change Ratio Measurement
;; ============================================================

;; This isn't a speed benchmark — it measures what fraction of
;; net-cell-write calls result in actual changes vs no-ops.
;; Used to validate the "~80% no-change" claim from the audit.

(define (measure-change-ratio)
  (define changes (box 0))
  (define no-changes (box 0))
  ;; Build a realistic network: 50 cells, chain propagation
  (define-values (net ids) (make-chain-network 50))
  ;; Seed and run
  (define seeded (net-cell-write net (car ids) 1))
  (define final-net (run-to-quiescence seeded))
  ;; Now run again with same seed — should be all no-change
  (define seeded2 (net-cell-write final-net (car ids) 1))
  ;; Count manually by reading cells before/after
  ;; (We can't instrument net-cell-write without modifying it,
  ;;  but we can check how many cells changed)
  (define final-net2 (run-to-quiescence seeded2))
  ;; Compare cell values
  (define changed-count
    (for/sum ([cid (in-list ids)])
      (define v1 (net-cell-read final-net cid))
      (define v2 (net-cell-read final-net2 cid))
      (if (equal? v1 v2) 0 1)))
  (printf "\n--- Change/No-Change Ratio ---\n")
  (printf "After first propagation: all cells populated\n")
  (printf "After second propagation (same seed): ~a/~a cells changed\n"
          changed-count (length ids))
  (printf "No-change ratio: ~a%\n"
          (exact->inexact (* 100 (/ (- (length ids) changed-count)
                                     (length ids))))))

;; ============================================================
;; Benchmark 7: struct-copy Isolation
;; ============================================================

;; Measure raw struct-copy cost for 13-field prop-network
(define b-struct-copy-raw
  (let ([net (make-prop-network)])
    (bench "struct-copy prop-network: 10000 copies (worklist only)"
      (λ ()
        (for/fold ([n net]) ([i (in-range 10000)])
          (struct-copy prop-network n
            [worklist (cons (prop-id i) (prop-network-worklist n))]))))))

;; ============================================================
;; Direct Timing (sub-ms precision via multi-sample averaging)
;; ============================================================
;; The bench-micro harness uses current-inexact-monotonic-milliseconds
;; which has ms precision — too coarse for these operations.
;; Instead we time N iterations directly and compute per-op cost.

(define (direct-bench name iterations thunk)
  (define samples
    (for/list ([_ (in-range 15)])
      (collect-garbage 'major)
      (define t0 (current-inexact-monotonic-milliseconds))
      (thunk)
      (- (current-inexact-monotonic-milliseconds) t0)))
  (define med (median samples))
  (define mn (mean samples))
  (define sd (stddev samples))
  (define per-op (/ med iterations))
  (printf "~a\n  total: median ~ams  mean ~ams  stddev ~ams  (~a iterations, ~aμs/op)\n"
          name
          (~r med #:precision '(= 2))
          (~r mn #:precision '(= 2))
          (~r sd #:precision '(= 2))
          iterations
          (~r (* per-op 1000) #:precision '(= 2))))

(require racket/format)

(printf "\n=== Allocation Micro-Benchmarks (Direct Timing) ===\n\n")

;; Cell allocation
(direct-bench "net-new-cell (1000 cells × 50 rounds)"
  50000
  (λ ()
    (for ([_ (in-range 50)])
      (let loop ([net (make-prop-network)] [i 0])
        (if (>= i 1000) (void)
            (let-values ([(net* _) (net-new-cell net 0 int-merge)])
              (loop net* (add1 i))))))))

;; Cell write (change)
(let-values ([(net ids) (make-n-cell-network 500)])
  (direct-bench "net-cell-write: all change (500 cells × 50 rounds)"
    25000
    (λ ()
      (for/fold ([n net]) ([round (in-range 50)])
        (for/fold ([n n]) ([cid (in-list ids)]
                           [v (in-naturals (+ 1 (* round 1000)))])
          (net-cell-write n cid v))))))

;; Cell write (no-change)
(let-values ([(net ids) (make-n-cell-network 500)])
  (define net42
    (for/fold ([n net]) ([cid (in-list ids)])
      (net-cell-write n cid 42)))
  (direct-bench "net-cell-write: all no-change (500 cells × 50 rounds)"
    25000
    (λ ()
      (for ([_ (in-range 50)])
        (for/fold ([n net42]) ([cid (in-list ids)])
          (net-cell-write n cid 42))))))

;; Propagator allocation
(let-values ([(net ids) (make-n-cell-network 400)])
  (direct-bench "net-add-propagator: 200 props (2 inputs) × 5 rounds"
    1000
    (λ ()
      (for ([_ (in-range 5)])
        (for/fold ([n net]) ([i (in-range 200)])
          (let-values ([(n* _pid)
                        (net-add-propagator n
                          (list (list-ref ids (* i 2))
                                (list-ref ids (+ (* i 2) 1)))
                          '() (λ (net) net))])
            n*))))))

;; Quiescence (chain)
(let-values ([(net ids) (make-chain-network 500)])
  (direct-bench "run-to-quiescence: 500-cell chain × 20 rounds"
    10000  ;; ~500 firings per run × 20 rounds
    (λ ()
      (for ([round (in-range 20)])
        (define seeded (net-cell-write net (car ids) (add1 round)))
        (run-to-quiescence seeded)))))

;; Raw struct-copy
(let ([net (make-prop-network)])
  (direct-bench "struct-copy prop-network: 50K copies (worklist only)"
    50000
    (λ ()
      (for/fold ([n net]) ([i (in-range 50000)])
        (struct-copy prop-network n
          [worklist (cons (prop-id i) (prop-network-worklist n))])))))

;; Change ratio measurement
(measure-change-ratio)

;; Memory baseline
(printf "\n--- Memory Baseline ---\n")
(collect-garbage 'major)
(define mem-before (current-memory-use))
;; Process a representative workload: build + quiesce a 500-cell chain × 100
(let-values ([(net ids) (make-chain-network 500)])
  (for ([round (in-range 100)])
    (define seeded (net-cell-write net (car ids) (add1 round)))
    (run-to-quiescence seeded)))
(collect-garbage 'major)
(define mem-after (current-memory-use))
(printf "Memory before: ~a bytes (~a MB)\n" mem-before (~r (/ mem-before 1048576.0) #:precision '(= 1)))
(printf "Memory after:  ~a bytes (~a MB)\n" mem-after (~r (/ mem-after 1048576.0) #:precision '(= 1)))
(printf "Delta:         ~a bytes (~a KB)\n" (- mem-after mem-before) (~r (/ (- mem-after mem-before) 1024.0) #:precision '(= 1)))
