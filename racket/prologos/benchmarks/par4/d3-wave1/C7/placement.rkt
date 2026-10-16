#lang racket/base
;; C7 probe: does D.2's placement rule ("a fire runs on the executor that owns its first output",
;; round-robin by cell id) leave the parallelism the K>1 models assume (fire time / min(width, K))?
;; Per BSP round (observer, counts only): width; distinct first-output cells; under RR ownership at
;; K ∈ {4,8,16}, the largest number of the round's fires sharing one home executor.
;; Effective parallelism of a round = width / max-fires-on-one-home (an upper bound: equal fire cost).
;; Aggregates are weighted by fires, over rounds of width >= 2 and >= 8.
(require racket/port racket/list
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt")
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/champ.rkt"))
(define root "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/")
(define fname (or (getenv "C7_FILE") "constraints-adversarial.prologos"))
(define (run-file f)
  (parameterize ([current-output-port (open-output-nowhere)]
                 [current-error-port (open-output-nowhere)]
                 [current-pnet-write-enabled? #f]
                 [current-parallel-executor #f])
    (process-file f)))
(void (run-file (string-append root "benchmarks/par4/preload-empty.prologos")))

(define rows '()) ; (width distinct-first-outputs (K . maxhome) ...)
(define wide-merge (make-hash)) ; merge-fn name of first output, fires in rounds >= 8 wide
(define Ks '(4 8 16))
(define (observe r)
  (define snap (bsp-round-network-snapshot r))
  (define props (prop-network-propagators snap))
  (define firsts
    (for*/list ([pid (in-list (bsp-round-propagators-fired r))]
                [p (in-value (champ-lookup props (prop-id-hash pid) pid))]
                #:unless (eq? p 'none))
      (define outs (propagator-outputs p))
      (cons (if (pair? outs) (cell-id-n (car outs)) -1) (equal-hash-code pid))))
  (define w (length firsts))
  (when (>= w 8)
    (for* ([pid (in-list (bsp-round-propagators-fired r))]
           [p (in-value (champ-lookup props (prop-id-hash pid) pid))]
           #:unless (eq? p 'none)
           #:when (pair? (propagator-outputs p)))
      (define c (car (propagator-outputs p)))
      (define f (champ-lookup (prop-network-merge-fns snap) (cell-id-hash c) c))
      (hash-update! wide-merge (format "~a" (if (procedure? f) (or (object-name f) "anon") f)) add1 0)))
  (when (> w 0)
    (set! rows (cons (list* w (length (remove-duplicates (map car firsts)))
                            (for/list ([K Ks])
                              (define h (make-hasheqv)) (define g (make-hasheqv))
                              (for ([c firsts]) (hash-update! h (modulo (max (car c) 0) K) add1 0)
                                                (hash-update! g (modulo (cdr c) K) add1 0))
                              (list K (apply max (hash-values h)) (apply max (hash-values g)))))
                     rows))))
(parameterize ([current-bsp-observer observe])
  (void (run-file (string-append root "benchmarks/comparative/" fname))))

(define (agg minw)
  (define rs (filter (λ (r) (>= (car r) minw)) rows))
  (define fires (apply + (map car rs)))
  (printf "  rounds width>=~a: ~a rounds, ~a fires, distinct first outputs ~a (~a% of fires)\n"
          minw (length rs) fires (apply + (map cadr rs))
          (if (zero? fires) 0 (round (* 100.0 (/ (apply + (map cadr rs)) fires)))))
  (for ([K Ks])
    (define span-placed (for/sum ([r rs]) (cadr (assv K (cddr r)))))       ; Σ max fires on one home
    (define span-pid (for/sum ([r rs]) (caddr (assv K (cddr r)))))         ; POWER ROW: home by propagator-id hash
    (define span-model (for/sum ([r rs]) (ceiling (/ (car r) (min (car r) K))))) ; Σ ceil(width / min(width,K))
    (printf "    K=~a: model (width/min(width,K)) parallelism ~a  | placed by first-output owner ~a  | power row: placed by propagator-id hash ~a\n"
            K (if (zero? span-model) 0 (/ (round (* 100.0 (/ fires span-model))) 100))
            (if (zero? span-placed) 0 (/ (round (* 100.0 (/ fires span-placed))) 100))
            (if (zero? span-pid) 0 (/ (round (* 100.0 (/ fires span-pid))) 100)))))
(printf "file ~a: ~a observed rounds\n" fname (length rows))
(agg 2)
(agg 8)
(printf "  first-output merge in rounds >= 8 wide (fires): ~a\n" (sort (hash->list wide-merge) > #:key cdr))
