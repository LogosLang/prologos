#lang racket/base
;; W2-10 probe 1 — what does the USER see when a fire raises a Racket exception?
;; One round of N propagators reading one source cell s; exactly one fire raises when s > 0.
;; Executors: sequential-fire-all, the production thread-per-round executor (driver.rkt:567,
;; make-parallel-thread-fire-all, threshold 8), and a persistent-worker executor (one thread created
;; once, before the run, standing in for D.2 §6.7's "created once per process, parked between solves").
;; Outcome per leg: 'raised <msg> | 'HUNG (no result within 8 s) | 'ok.
;; Also: where the raising thread's error text went (the error port is parameterized to a string
;; port inside the run, as the LSP parameterizes it to open-output-nowhere, lsp/server.rkt:538).
;; Power rows: no raising fire (must be 'ok everywhere); N below the threshold (thread exec = sequential).
(require racket/port racket/future
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))

(define (build n raiser?)
  (define n0 (make-prop-network 100000))
  (define-values (n1 s) (net-new-cell n0 0 (λ (a b) (max a b))))
  (define-values (net outs)
    (for/fold ([net n1] [outs '()]) ([i (in-range n)])
      (define-values (net* c) (net-new-cell net 0 (λ (a b) (max a b))))
      (values net* (cons c outs))))
  (define installed
    (for/fold ([net net]) ([c (in-list (reverse outs))] [i (in-naturals)])
      (define (fire nw)
        (define v (net-cell-read nw s))
        (cond [(zero? v) nw]
              [(and raiser? (= i (quotient n 2)))
               (error 'fire "internal fault in propagator ~a" i)]
              [else (net-cell-write nw c v)]))
      (let-values ([(n* _) (net-add-propagator net (list s) (list c) fire)]) n*)))
  (values installed s))

;; persistent worker: created BEFORE the run (outside the run's parameterize), reused by every round.
;; A fresh one per leg so that a worker killed by one leg cannot hang the next leg.
(define (make-persistent-exec)
  (define job-ch (make-channel))
  (thread #:pool 'own
    (λ ()
      (let loop ()
        (define job (channel-get job-ch))
        ((car job) ((cdr job)))
        (loop))))
  (λ (snap pids)
    (define reply (make-channel))
    (channel-put job-ch (cons (λ (r) (channel-put reply r))
                              (λ () (for/list ([p (in-list pids)]) (fire-and-collect-writes snap p)))))
    (channel-get reply)))

(define (run-leg exec n raiser?)
  (define-values (net s) (build n raiser?))
  (define base (run-to-quiescence-bsp net #:executor exec))
  (define kicked (net-cell-write base s 1))
  (define errport (open-output-string))
  (define result-ch (make-channel))
  (define runner
    (thread (λ ()
              (channel-put result-ch
                (with-handlers ([exn:fail? (λ (e) (list 'raised (exn-message e)))])
                  (parameterize ([current-error-port errport])
                    (run-to-quiescence-bsp kicked #:executor exec))
                  (list 'ok))))))
  (define r (sync/timeout 8 result-ch))
  (unless r (kill-thread runner))
  (list (or r '(HUNG)) (let ([t (get-output-string errport)])
                         (if (string=? t "") "<error port empty>"
                             (car (regexp-split #rx"\n" t))))))

(define legs (list (cons 'sequential (λ () sequential-fire-all))
                   (cons 'thread-per-round (λ () (make-parallel-thread-fire-all)))
                   (cons 'persistent-worker make-persistent-exec)))
(printf "processor-count ~a\n" (processor-count))
(for* ([n '(4 12)] [raiser? '(#f #t)] [leg (in-list legs)])
  (define r (run-leg ((cdr leg)) n raiser?))
  (printf "N=~a raiser=~a ~a: ~s | error port: ~a\n" n raiser? (car leg) (car r) (cadr r)))
