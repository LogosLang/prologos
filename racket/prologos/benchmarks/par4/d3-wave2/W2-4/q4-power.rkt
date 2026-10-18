#lang racket/base
;; W2-4 Q4 power row: the outer-round instrument of w24-run.rkt (observer records linked by the fuel cell +
;; wrapped stratum handlers marking "produced S0 work") applied to C8's topology-discovery chain
;; (d3-wave1/C8/probe-outer-cap.rkt). For a chain of depth N the run needs N-1 outer iterations after the first.
(require racket/set json
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt"))
(define R "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/")
;; ---- instrument (same logic as w24-run.rkt)
(define runs (make-hash)) (define pending (make-hash)) (define run-max (make-hasheqv)) (define next-run 0)
(define (outer-observe r)
  (define net (bsp-round-network-snapshot r))
  (define n (length (bsp-round-propagators-fired r)))
  (define f-out (net-cell-read net fuel-cell-id)) (define f-in (+ f-out n))
  (cond
    [(zero? (bsp-round-round-number r))
     (define cont (hash-ref pending f-in #f))
     (hash-remove! pending f-in)
     (define rec (if cont (mcons (mcar cont) (add1 (mcdr cont))) (begin0 (mcons next-run 0) (set! next-run (add1 next-run)))))
     (hash-remove! runs f-in) (hash-set! runs f-out rec)
     (hash-set! run-max (mcar rec) (max (mcdr rec) (hash-ref run-max (mcar rec) 0)))]
    [else (define rec (hash-ref runs f-in #f))
          (when rec (hash-remove! runs f-in) (hash-set! runs f-out rec))]))
(define sh (eval 'stratum-handlers (module->namespace (string->path (string-append R "propagator.rkt")))))
(set-box! sh (for/list ([e (unbox sh)])
               (define f (cadr e))
               (list* (car e) (lambda (net pend)
                                (define F (net-cell-read net fuel-cell-id))
                                (define rec (or (hash-ref runs F #f) (begin0 (mcons next-run 0) (set! next-run (add1 next-run)))))
                                (define out (f net pend))
                                (when (pair? (prop-network-worklist out)) (hash-set! pending F rec))
                                out)
                      (cddr e))))
;; ---- C8's chain, verbatim construction
(define (run-chain N)
  (define net0 (make-prop-network))
  (define-values (net1 seed) (net-new-cell net0 0 (lambda (a b) (max a b))))
  (define-values (net2 depth-cell) (net-new-cell net1 0 (lambda (a b) (max a b))))
  (define (make-level d)
    (lambda (net)
      (define n1 (net-cell-write net depth-cell d))
      (if (< d N)
          (net-cell-write n1 constraint-propagators-topology-cell-id
                          (set (callback-topology-request
                                (lambda (n) (let-values ([(n* pid) (net-add-propagator n (list seed) (list depth-cell constraint-propagators-topology-cell-id) (make-level (add1 d)))]) n*))
                                (cons 'c8-level (cons (cell-id (+ 1000 d)) (cell-id (+ 2000 d)))))))
          n1)))
  (define-values (net3 pid0) (net-add-propagator net2 (list seed) (list depth-cell constraint-propagators-topology-cell-id) (make-level 1)))
  (define net4 (net-cell-write net3 seed 1))
  (hash-clear! runs) (hash-clear! pending) (hash-clear! run-max)
  (define res (with-handlers ([exn:fail? (lambda (e) (format "ERROR: ~a" (exn-message e)))])
                (define out (parameterize ([current-bsp-observer outer-observe]) (run-to-quiescence-bsp net4)))
                (format "ok depth ~a" (net-cell-read out depth-cell))))
  (printf "N=~a  ~a  | instrument: runs ~a, max outer-round ~a\n" N res (hash-count run-max) (apply max 0 (hash-values run-max))))
(for ([N '(1 5 11 12 15 22 23)]) (run-chain N))
