#lang racket/base
;; W2-5 power rows for the dyn.rkt instruments (constructed, on the real propagator.rkt network):
;;  P1  a fire that DIRECTLY ASSIGNS a production parameter (current-subtype-check-count, the
;;      parameter bump-subtype-count! assigns at subtype-predicate.rkt:77): does the main thread
;;      see the assignment after quiescence, under (a) sequential-fire-all, (b) a fresh parallel
;;      thread per round, (c) the production make-parallel-thread-fire-all (>= 8 fires/round)?
;;  P2  a fire that READS a parameter assigned directly by the main thread AFTER a persistent
;;      executor thread was created: (a) plain persistent thread, (b) persistent thread running
;;      the job under call-with-parameterization of the submitter's parameterization, (c) the same
;;      with the parameter bound by parameterize instead of assigned.
;;  P3  read-modify-write on a shared box from fires (global-subtype-total pattern,
;;      subtype-predicate.rkt:81) under the production executor: lost updates?
(require racket/list
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/subtype-predicate.rkt")
                  current-subtype-check-count))

(define (flat-merge old new) new)
;; K source cells each feeding one propagator that writes its own output cell; all fire in round 1.
(define (build K fire-body)
  (define-values (net srcs outs)
    (for/fold ([net (make-prop-network)] [srcs '()] [outs '()]) ([i (in-range K)])
      (define-values (n1 s) (net-new-cell net 0 (lambda (a b) (max a b))))
      (define-values (n2 o) (net-new-cell n1 0 (lambda (a b) (max a b))))
      (values n2 (cons s srcs) (cons o outs))))
  (for/fold ([net net]) ([s (in-list srcs)] [o (in-list outs)])
    (define-values (n pid)
      (net-add-propagator net (list s) (list o)
                          (lambda (n) (fire-body) (net-cell-write n o (add1 (net-cell-read n s))))))
    n))

(define (fresh-exec snap pids)
  (define ch (make-channel))
  (thread #:pool 'own (lambda () (channel-put ch (sequential-fire-all snap pids))))
  (channel-get ch))

;; ---- P1
(define (p1 label exec)
  (current-subtype-check-count (cons 0 0))
  (define net (build 16 (lambda () (current-subtype-check-count
                                    (cons (add1 (car (current-subtype-check-count))) 0)))))
  (parameterize ([current-parallel-executor exec]) (run-to-quiescence net))
  (printf "P1 ~a: main thread sees (current-subtype-check-count) = ~s after 16 fires that each assign it\n"
          label (current-subtype-check-count)))
(p1 "sequential-fire-all       " sequential-fire-all)
(p1 "fresh thread per round    " fresh-exec)
(p1 "make-parallel-thread-fire-all" (make-parallel-thread-fire-all))

;; ---- P2
(define probe-param (make-parameter 'at-load))
(define job (box #f)) (define sema (make-semaphore 0))
(define persist (thread #:pool 'own (lambda () (let loop () (semaphore-wait sema) ((unbox job)) (loop)))))
(define (persist-exec capture?)
  (lambda (snap pids)
    (define ch (make-channel)) (define pz (current-parameterization))
    (set-box! job (lambda () (channel-put ch (if capture?
                                                 (call-with-parameterization pz (lambda () (sequential-fire-all snap pids)))
                                                 (sequential-fire-all snap pids)))))
    (semaphore-post sema)
    (channel-get ch)))
(define seen (box '()))
(define (p2 label exec)
  (set-box! seen '())
  (define net (build 2 (lambda () (set-box! seen (cons (probe-param) (unbox seen))))))
  (parameterize ([current-parallel-executor exec]) (run-to-quiescence net))
  (printf "P2 ~a: main sees ~s; fires saw ~s\n" label (probe-param) (remove-duplicates (unbox seen))))
(probe-param 'assigned-by-main-after-executor-creation)   ; direct assignment, like reset-meta-store!
(p2 "(a) persistent, no capture          " (persist-exec #f))
(p2 "(b) persistent, captured paramz      " (persist-exec #t))
(parameterize ([probe-param 'parameterized-by-main])
  (p2 "(c) persistent, captured, parameterize" (persist-exec #t)))
(p2 "(d) fresh thread per round           " fresh-exec)

;; ---- P3: shared box read-modify-write from fires, production executor, 64 fires x 2000 increments
(define shared (box 0))
(define (p3 label exec)
  (set-box! shared 0)
  (define net (build 64 (lambda () (for ([i (in-range 2000)]) (set-box! shared (add1 (unbox shared)))))))
  (parameterize ([current-parallel-executor exec]) (run-to-quiescence net))
  (printf "P3 ~a: shared box = ~a (expected ~a)\n" label (unbox shared) (* 64 2000)))
(p3 "sequential-fire-all          " sequential-fire-all)
(for ([i 3]) (p3 "make-parallel-thread-fire-all" (make-parallel-thread-fire-all)))
(kill-thread persist)

;; ---- P4: re-entrancy instrument power (dyn.rkt / dyn3.rkt count an executor call made while an
;; executor job is running on the same thread): fires that run a nested run-to-quiescence.
(define nested 0)
(define in-job (make-thread-cell #f #f))
(define (counting-exec snap pids)
  (if (thread-cell-ref in-job)
      (begin (set! nested (add1 nested)) (sequential-fire-all snap pids))
      (begin (thread-cell-set! in-job #t) (begin0 (sequential-fire-all snap pids) (thread-cell-set! in-job #f)))))
;; the inner network is built OUTSIDE the fire: make-prop-network inside a BSP fire trips
;; 'fuel-cell-id allocation drift' because current-cell-id-namespace is bound per fire (:2885).
(define inner (build 2 void))
(define net4 (build 3 (lambda () (run-to-quiescence inner))))
(parameterize ([current-parallel-executor counting-exec]) (run-to-quiescence net4))
(printf "P4 nested executor calls from 3 fires that each run an inner quiescence: ~a (expect >= 3)\n" nested)
