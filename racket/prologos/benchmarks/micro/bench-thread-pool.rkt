#lang racket/base

;; bench-thread-pool.rkt — Thread Pool vs Per-Round Thread Creation
;;
;; Measures the overhead components of parallel execution to identify
;; what can be optimized to lower the crossover point:
;;
;;   T1: Thread create+join cost (current approach: 3.6us)
;;   T2: Channel send+receive cost (pool communication)
;;   T3: Semaphore signal+wait cost (lighter synchronization)
;;   T4: Thread pool prototype (amortized thread creation)
;;   T5: Thread pool at varying N (scaling comparison)
;;
;; The hypothesis: a persistent thread pool replaces per-round thread
;; creation (3.6us) with per-round channel communication (~0.1-0.5us),
;; dropping the crossover from N=128 to N≈16.

(require "../../tools/bench-micro.rkt"
         "../../propagator.rkt"
         racket/list)

;; ============================================================
;; T1: Baseline — thread create+join (current approach)
;; ============================================================

(bench "T1: thread create+join x5000"
  (for ([_ (in-range 5000)])
    (define ch (make-channel))
    (thread (lambda () (channel-put ch 42)))
    (channel-get ch)))

;; Multiple threads (simulating K=4 workers)
(bench "T1: 4 threads create+join x2000"
  (for ([_ (in-range 2000)])
    (define chs
      (for/list ([_ (in-range 4)])
        (define ch (make-channel))
        (thread (lambda () (channel-put ch 42)))
        ch))
    (for ([ch (in-list chs)]) (channel-get ch))))

(bench "T1: 8 threads create+join x1000"
  (for ([_ (in-range 1000)])
    (define chs
      (for/list ([_ (in-range 8)])
        (define ch (make-channel))
        (thread (lambda () (channel-put ch 42)))
        ch))
    (for ([ch (in-list chs)]) (channel-get ch))))

;; ============================================================
;; T2: Channel send+receive (pool communication overhead)
;; ============================================================

;; Pre-create a thread that echoes back
(define echo-in (make-channel))
(define echo-out (make-channel))
(thread (lambda ()
          (let loop ()
            (define val (channel-get echo-in))
            (unless (eq? val 'stop)
              (channel-put echo-out val)
              (loop)))))

(bench "T2: channel round-trip (persistent thread) x50000"
  (for ([_ (in-range 50000)])
    (channel-put echo-in 42)
    (channel-get echo-out)))

;; 4 persistent echo threads
(define echo-pairs
  (for/list ([_ (in-range 4)])
    (define in (make-channel))
    (define out (make-channel))
    (thread (lambda ()
              (let loop ()
                (define val (channel-get in))
                (unless (eq? val 'stop)
                  (channel-put out val)
                  (loop)))))
    (cons in out)))

(bench "T2: 4 channel round-trips (persistent threads) x10000"
  (for ([_ (in-range 10000)])
    (for ([pair (in-list echo-pairs)])
      (channel-put (car pair) 42))
    (for ([pair (in-list echo-pairs)])
      (channel-get (cdr pair)))))

;; ============================================================
;; T3: Semaphore signal+wait (lighter synchronization)
;; ============================================================

(bench "T3: semaphore post+wait x100000"
  (define sema (make-semaphore 0))
  (for ([_ (in-range 100000)])
    (semaphore-post sema)
    (semaphore-wait sema)))

;; ============================================================
;; T4: Thread pool prototype
;; ============================================================

;; A simple persistent thread pool: K workers wait on a shared work
;; channel, execute work items, signal completion on a result channel.

(struct thread-pool (work-ch result-ch workers) #:transparent)

(define (make-thread-pool k)
  (define work-ch (make-channel))
  (define result-ch (make-channel))
  (define workers
    (for/list ([i (in-range k)])
      (thread (lambda ()
                (let loop ()
                  (define work-item (channel-get work-ch))
                  (cond
                    [(eq? work-item 'shutdown) (void)]
                    [else
                     (define result ((cdr work-item)))  ;; execute the thunk
                     (channel-put result-ch (cons (car work-item) result))
                     (loop)]))))))
  (thread-pool work-ch result-ch workers))

(define (pool-submit pool id thunk)
  (channel-put (thread-pool-work-ch pool) (cons id thunk)))

(define (pool-collect pool n)
  (for/list ([_ (in-range n)])
    (channel-get (thread-pool-result-ch pool))))

(define (pool-shutdown pool)
  (for ([_ (in-list (thread-pool-workers pool))])
    (channel-put (thread-pool-work-ch pool) 'shutdown)))

;; Pool with 4 workers
(define pool4 (make-thread-pool 4))

;; No-op work items
(bench "T4: pool dispatch 4 items (no-op) x5000"
  (for ([_ (in-range 5000)])
    (for ([i (in-range 4)])
      (pool-submit pool4 i (lambda () 42)))
    (pool-collect pool4 4)))

;; Light work items
(bench "T4: pool dispatch 4 items (light work) x5000"
  (for ([_ (in-range 5000)])
    (for ([i (in-range 4)])
      (pool-submit pool4 i (lambda ()
                             (hash-ref (hasheq 'a 1 'b 2 'c 3) 'b))))
    (pool-collect pool4 4)))

;; Pool with 8 workers
(define pool8 (make-thread-pool 8))

(bench "T4: pool dispatch 8 items (no-op) x2000"
  (for ([_ (in-range 2000)])
    (for ([i (in-range 8)])
      (pool-submit pool8 i (lambda () 42)))
    (pool-collect pool8 8)))

;; ============================================================
;; T5: Pool vs fresh-threads at varying N
;; ============================================================
;; Same workload as bench-parallel-scaling, but with pool

(define (make-work-items n)
  (for/list ([i (in-range n)])
    (lambda ()
      (for/fold ([acc 0]) ([j (in-range 10)])
        (+ acc (* j j))))))

;; Pool scaling
(define pool-scale (make-thread-pool 8))

(define (run-pool-workload pool n work-items)
  (for ([i (in-range n)]
        [work (in-list work-items)])
    (pool-submit pool i work))
  (pool-collect pool n))

(define work-16 (make-work-items 16))
(define work-32 (make-work-items 32))
(define work-64 (make-work-items 64))
(define work-128 (make-work-items 128))

(bench "T5: pool N=16 (medium work) x2000"
  (for ([_ (in-range 2000)])
    (run-pool-workload pool-scale 16 work-16)))

(bench "T5: pool N=32 (medium work) x1000"
  (for ([_ (in-range 1000)])
    (run-pool-workload pool-scale 32 work-32)))

(bench "T5: pool N=64 (medium work) x500"
  (for ([_ (in-range 500)])
    (run-pool-workload pool-scale 64 work-64)))

(bench "T5: pool N=128 (medium work) x200"
  (for ([_ (in-range 200)])
    (run-pool-workload pool-scale 128 work-128)))

;; For comparison: sequential at same N
(define (run-sequential-workload n work-items)
  (for/list ([work (in-list work-items)])
    (work)))

(bench "T5: sequential N=16 (medium work) x2000"
  (for ([_ (in-range 2000)])
    (run-sequential-workload 16 work-16)))

(bench "T5: sequential N=32 (medium work) x1000"
  (for ([_ (in-range 1000)])
    (run-sequential-workload 32 work-32)))

(bench "T5: sequential N=64 (medium work) x500"
  (for ([_ (in-range 500)])
    (run-sequential-workload 64 work-64)))

(bench "T5: sequential N=128 (medium work) x200"
  (for ([_ (in-range 200)])
    (run-sequential-workload 128 work-128)))

;; Cleanup
(pool-shutdown pool4)
(pool-shutdown pool8)
(pool-shutdown pool-scale)
(channel-put echo-in 'stop)
(for ([pair (in-list echo-pairs)])
  (channel-put (car pair) 'stop))
