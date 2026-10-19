#lang racket/base
;; W2-10 probe 2 — where does a fire's OUTPUT go, per executor shape, when the caller redirects ports
;; the way the LSP does (lsp/server.rkt:536-543: current-output-port := open-output-nowhere because stdout
;; IS the JSON-RPC channel)? "proto" stands for the LSP's real stdout. A persistent worker is created
;; once, before the elaboration (D.2 §6.7 shape); thread-per-round is driver.rkt:567's executor.
;; Power row: the sequential executor must leave "proto" clean.
(require racket/port
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))

(define proto (open-output-string))          ; the LSP's JSON-RPC stdout

(define (make-persistent-exec)
  (define job-ch (make-channel))
  (thread #:pool 'own
    (λ () (let loop () (define job (channel-get job-ch)) ((car job) ((cdr job))) (loop))))
  (λ (snap pids)
    (define reply (make-channel))
    (channel-put job-ch (cons (λ (r) (channel-put reply r))
                              (λ () (for/list ([p (in-list pids)]) (fire-and-collect-writes snap p)))))
    (channel-get reply)))

(define (build n)
  (define n0 (make-prop-network 100000))
  (define-values (n1 s) (net-new-cell n0 0 (λ (a b) (max a b))))
  (define net
    (for/fold ([net n1]) ([i (in-range n)])
      (define-values (net* c) (net-new-cell net 0 (λ (a b) (max a b))))
      (let-values ([(n** _) (net-add-propagator net* (list s) (list c)
                               (λ (nw) (define v (net-cell-read nw s))
                                  (cond [(zero? v) nw]
                                        [else (when (= i 0) (display "LEAK" (current-output-port)))
                                              (net-cell-write nw c v)])))])
        n**)))
  (values net s))

(define (leg name make-exec n)
  (define before (string-length (get-output-string proto)))
  (define exec (parameterize ([current-output-port proto]) (make-exec)))   ; executor born under the real stdout
  (define-values (net s) (build n))
  (define base (run-to-quiescence-bsp net #:executor exec))
  (parameterize ([current-output-port (open-output-nowhere)])             ; the LSP's elaboration scope
    (void (run-to-quiescence-bsp (net-cell-write base s 1) #:executor exec)))
  (define leaked (substring (get-output-string proto) before))
  (printf "~a N=~a: bytes written into the protocol stream: ~a ~s\n" name n (string-length leaked) leaked))

(leg 'sequential (λ () sequential-fire-all) 12)
(leg 'thread-per-round (λ () (make-parallel-thread-fire-all)) 12)
(leg 'persistent-worker make-persistent-exec 12)
(leg 'persistent-worker make-persistent-exec 2)
