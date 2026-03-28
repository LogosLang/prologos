#lang racket/base

;; bench-parallel-stress.rkt — PAR Track 2: Parallel executor stress tests
;;
;; Exercises the parallel thread executor under adversarial conditions:
;; 1. Contention: many propagators writing to the SAME cell
;; 2. Fan-out: one cell triggers N independent propagators
;; 3. Deep chain: linear dependency depth N
;; 4. Diamond: fan-out that reconverges
;; 5. Contradiction race: two propagators detect contradiction simultaneously
;; 6. Scaling: vary propagator count, measure speedup
;;
;; Each test verifies correctness (same result parallel vs sequential)
;; and measures wall time for both.

(require "../../propagator.rkt"
         "../../tools/bench-micro.rkt"
         racket/list
         racket/format)

;; ============================================================
;; Helpers
;; ============================================================

;; Simple merge: max (monotone, idempotent, commutative, associative)
(define (max-merge old new) (max old new))

;; Sum merge: add (monotone for non-negative, commutative, associative)
;; WARNING: not idempotent. Using for correctness check, not for production.
(define (sum-merge old new) (+ old new))

;; Build network, run with both executors, compare results
(define (compare-executors label net cell-ids)
  ;; Sequential
  (define seq-result
    (parameterize ([current-parallel-executor #f])
      (run-to-quiescence net)))
  ;; Parallel
  (define par-result
    (parameterize ([current-parallel-executor (make-parallel-thread-fire-all 2)])
      (run-to-quiescence net)))
  ;; Compare cell values
  (define mismatches
    (for/list ([cid (in-list cell-ids)]
               #:when (not (equal? (net-cell-read seq-result cid)
                                   (net-cell-read par-result cid))))
      (list cid (net-cell-read seq-result cid) (net-cell-read par-result cid))))
  ;; Compare contradictions
  (define seq-contra (prop-network-contradiction seq-result))
  (define par-contra (prop-network-contradiction par-result))
  (define contra-match?
    (cond [(and seq-contra par-contra) #t]   ;; both have contradiction
          [(and (not seq-contra) (not par-contra)) #t]  ;; neither
          [else #f]))

  (printf "  ~a: " label)
  (if (and (null? mismatches) contra-match?)
      (printf "PASS (~a cells checked)\n" (length cell-ids))
      (begin
        (printf "FAIL\n")
        (when (pair? mismatches)
          (printf "    mismatches: ~a\n" mismatches))
        (unless contra-match?
          (printf "    contradiction: seq=~a par=~a\n" seq-contra par-contra))))
  (null? mismatches))

;; Time a quiescence call
(define (time-quiescence net executor-param)
  (define t0 (current-inexact-monotonic-milliseconds))
  (define result
    (parameterize ([current-parallel-executor executor-param])
      (run-to-quiescence net)))
  (define t1 (current-inexact-monotonic-milliseconds))
  (values result (- t1 t0)))

;; ============================================================
;; Test 1: Contention — N propagators write to ONE cell
;; ============================================================

(define (test-contention n)
  (define net0 (make-prop-network))
  ;; Source cells: each gets a value
  (define-values (net1 src-ids)
    (for/fold ([net net0] [ids '()]) ([i (in-range n)])
      (let-values ([(net* cid) (net-new-cell net 0 max-merge)])
        (values net* (cons cid ids)))))
  (define src-ids-rev (reverse src-ids))
  ;; Target cell: all propagators write to this
  (define-values (net2 target-id) (net-new-cell net1 0 max-merge))
  ;; N propagators: each reads its source, writes source+1 to target
  (define net3
    (for/fold ([net net2]) ([src-cid (in-list src-ids-rev)] [i (in-naturals)])
      (let-values ([(net* _pid)
                    (net-add-propagator net (list src-cid) (list target-id)
                      (lambda (n)
                        (define v (net-cell-read n src-cid))
                        (net-cell-write n target-id (+ v 1))))])
        net*)))
  ;; Seed all source cells with different values
  (define net4
    (for/fold ([net net3]) ([src-cid (in-list src-ids-rev)] [i (in-naturals)])
      (net-cell-write net src-cid (* i 10))))
  ;; All cell-ids to check
  (define all-ids (cons target-id src-ids-rev))
  (compare-executors (format "contention N=~a" n) net4 all-ids))

;; ============================================================
;; Test 2: Fan-out — 1 cell triggers N independent propagators
;; ============================================================

(define (test-fanout n)
  (define net0 (make-prop-network))
  ;; Source cell
  (define-values (net1 src-id) (net-new-cell net0 0 max-merge))
  ;; N output cells
  (define-values (net2 out-ids)
    (for/fold ([net net1] [ids '()]) ([i (in-range n)])
      (let-values ([(net* cid) (net-new-cell net 0 max-merge)])
        (values net* (cons cid ids)))))
  (define out-ids-rev (reverse out-ids))
  ;; N propagators: each reads source, writes source*i to its output
  (define net3
    (for/fold ([net net2]) ([out-cid (in-list out-ids-rev)] [i (in-naturals)])
      (let-values ([(net* _pid)
                    (net-add-propagator net (list src-id) (list out-cid)
                      (let ([multiplier (+ i 1)])
                        (lambda (n)
                          (define v (net-cell-read n src-id))
                          (net-cell-write n out-cid (* v multiplier)))))])
        net*)))
  ;; Seed source
  (define net4 (net-cell-write net3 src-id 42))
  (define all-ids (cons src-id out-ids-rev))
  (compare-executors (format "fan-out N=~a" n) net4 all-ids))

;; ============================================================
;; Test 3: Deep chain — linear dependency depth N
;; ============================================================

(define (test-chain n)
  (define net0 (make-prop-network))
  ;; N+1 cells in a chain
  (define-values (net1 chain-ids)
    (for/fold ([net net0] [ids '()]) ([i (in-range (+ n 1))])
      (let-values ([(net* cid) (net-new-cell net 0 max-merge)])
        (values net* (cons cid ids)))))
  (define chain-ids-rev (reverse chain-ids))
  ;; N propagators: cell[i] → cell[i+1] (add 1)
  (define net2
    (for/fold ([net net1]) ([i (in-range n)])
      (let* ([in-cid (list-ref chain-ids-rev i)]
             [out-cid (list-ref chain-ids-rev (+ i 1))])
        (let-values ([(net* _pid)
                      (net-add-propagator net (list in-cid) (list out-cid)
                        (lambda (n)
                          (define v (net-cell-read n in-cid))
                          (net-cell-write n out-cid (+ v 1))))])
          net*))))
  ;; Seed first cell
  (define net3 (net-cell-write net2 (car chain-ids-rev) 100))
  (compare-executors (format "chain N=~a" n) net3 chain-ids-rev))

;; ============================================================
;; Test 4: Diamond — fan-out that reconverges
;; ============================================================

(define (test-diamond width)
  (define net0 (make-prop-network))
  ;; Source cell
  (define-values (net1 src-id) (net-new-cell net0 0 max-merge))
  ;; Middle cells (fan-out)
  (define-values (net2 mid-ids)
    (for/fold ([net net1] [ids '()]) ([i (in-range width)])
      (let-values ([(net* cid) (net-new-cell net 0 max-merge)])
        (values net* (cons cid ids)))))
  (define mid-ids-rev (reverse mid-ids))
  ;; Sink cell (reconverge)
  (define-values (net3 sink-id) (net-new-cell net2 0 max-merge))
  ;; Fan-out: src → each mid (multiply by i+1)
  (define net4
    (for/fold ([net net3]) ([mid-cid (in-list mid-ids-rev)] [i (in-naturals)])
      (let-values ([(net* _pid)
                    (net-add-propagator net (list src-id) (list mid-cid)
                      (let ([mult (+ i 1)])
                        (lambda (n)
                          (define v (net-cell-read n src-id))
                          (net-cell-write n mid-cid (* v mult)))))])
        net*)))
  ;; Reconverge: each mid → sink (max merge handles it)
  (define net5
    (for/fold ([net net4]) ([mid-cid (in-list mid-ids-rev)])
      (let-values ([(net* _pid)
                    (net-add-propagator net (list mid-cid) (list sink-id)
                      (lambda (n)
                        (define v (net-cell-read n mid-cid))
                        (net-cell-write n sink-id v)))])
        net*)))
  ;; Seed
  (define net6 (net-cell-write net5 src-id 7))
  (define all-ids (cons src-id (cons sink-id mid-ids-rev)))
  (compare-executors (format "diamond W=~a" width) net6 all-ids))

;; ============================================================
;; Test 5: Contradiction race — two propagators detect simultaneously
;; ============================================================

(define (test-contradiction-race)
  (define net0 (make-prop-network))
  ;; Two cells with contradiction detection
  (define-values (net1 cell-a)
    (net-new-cell net0 0 max-merge (lambda (v) (> v 100))))
  (define-values (net2 cell-b)
    (net-new-cell net1 0 max-merge (lambda (v) (> v 100))))
  ;; Two propagators: each writes 200 to its cell (triggering contradiction)
  (define-values (net3 _pid1)
    (net-add-propagator net2 (list cell-a) (list cell-a)
      (lambda (n)
        (net-cell-write n cell-a 200))))
  (define-values (net4 _pid2)
    (net-add-propagator net3 (list cell-b) (list cell-b)
      (lambda (n)
        (net-cell-write n cell-b 200))))
  ;; Seed both
  (define net5 (net-cell-write (net-cell-write net4 cell-a 1) cell-b 1))
  (compare-executors "contradiction-race" net5 (list cell-a cell-b)))

;; ============================================================
;; Test 6: Scaling — measure speedup at various N
;; ============================================================

(define (test-scaling)
  (printf "\n  Scaling test (fan-out, wall time):\n")
  (printf "  ~a ~a ~a ~a ~a\n" (~a "N" #:width 6) (~a "seq(ms)" #:width 10)
          (~a "par(ms)" #:width 10) (~a "speedup" #:width 8) (~a "status" #:width 8))
  (printf "  ~a\n" (make-string 48 #\-))
  (for ([n (in-list '(10 50 100 200 500))])
    ;; Build fan-out network
    (define net0 (make-prop-network))
    (define-values (net1 src-id) (net-new-cell net0 0 max-merge))
    (define-values (net2 out-ids)
      (for/fold ([net net1] [ids '()]) ([i (in-range n)])
        (let-values ([(net* cid) (net-new-cell net 0 max-merge)])
          (values net* (cons cid ids)))))
    (define net3
      (for/fold ([net net2]) ([out-cid (in-list (reverse out-ids))] [i (in-naturals)])
        (let-values ([(net* _pid)
                      (net-add-propagator net (list src-id) (list out-cid)
                        (let ([mult (+ i 1)])
                          ;; Add some compute work per propagator
                          (lambda (n)
                            (define v (net-cell-read n src-id))
                            ;; Simulate work: 100 iterations
                            (define result
                              (for/fold ([acc (* v mult)]) ([_ (in-range 100)])
                                (+ acc 1)))
                            (net-cell-write n out-cid result))))])
          net*)))
    (define net4 (net-cell-write net3 src-id 1))

    ;; Time sequential (3 runs, take median)
    (define seq-times
      (for/list ([_ (in-range 3)])
        (collect-garbage 'major)
        (let-values ([(_ t) (time-quiescence net4 #f)]) t)))
    (define seq-med (list-ref (sort seq-times <) 1))

    ;; Time parallel (3 runs, take median)
    (define par-times
      (for/list ([_ (in-range 3)])
        (collect-garbage 'major)
        (let-values ([(_ t) (time-quiescence net4 (make-parallel-thread-fire-all 2))]) t)))
    (define par-med (list-ref (sort par-times <) 1))

    (define speedup (if (zero? par-med) 999.0 (/ seq-med par-med)))

    ;; Verify correctness
    (define-values (seq-net _) (time-quiescence net4 #f))
    (define-values (par-net __) (time-quiescence net4 (make-parallel-thread-fire-all 2)))
    (define correct?
      (andmap (lambda (cid) (equal? (net-cell-read seq-net cid) (net-cell-read par-net cid)))
              (reverse out-ids)))

    (printf "  ~a ~a ~a ~a ~a\n"
            (~a n #:width 6)
            (~a (~r seq-med #:precision '(= 2)) #:width 10)
            (~a (~r par-med #:precision '(= 2)) #:width 10)
            (~a (~r speedup #:precision '(= 2)) #:width 8)
            (~a (if correct? "PASS" "FAIL") #:width 8))))

;; Formatting helper
(define (~a v #:width [w 0])
  (define s (format "~a" v))
  (if (>= (string-length s) w) s
      (string-append s (make-string (- w (string-length s)) #\space))))

;; ============================================================
;; Run all tests
;; ============================================================

(printf "═══ PAR Track 2: Parallel Executor Stress Tests ═══\n\n")
(printf "Correctness tests (parallel vs sequential):\n")

(test-contention 10)
(test-contention 50)
(test-contention 200)
(test-fanout 10)
(test-fanout 50)
(test-fanout 200)
(test-chain 10)
(test-chain 50)
(test-chain 100)
(test-diamond 10)
(test-diamond 50)
(test-diamond 200)
(test-contradiction-race)

(test-scaling)

(printf "\nDone.\n")
