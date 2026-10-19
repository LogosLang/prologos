#lang racket/base
;; W2-4 Q2: run ONE test file with the production executor wrapped so that, during every executor call,
;; current-prop-net-box / current-persistent-registry-net-box are chaperoned. Counts unbox / set-box! by
;; thread class and lost updates (a set-box! whose thread did not read the value it overwrites).
;; Note: test files may parameterize these boxes themselves; the chaperone is installed per executor call,
;; over whatever box is current at that moment.
(require rackunit/log json
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt") process-file)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
                  current-parallel-executor sequential-fire-all)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/metavar-store.rkt")
                  current-prop-net-box current-persistent-registry-net-box))
(define f (simplify-path (path->complete-path (vector-ref (current-command-line-arguments) 0))))
(define main-thread (current-thread))
(define ev (box '()))
(define (push! e) (let loop () (define o (unbox ev)) (unless (box-cas! ev o (cons e o)) (loop))))
(define round-no 0)
(define (chap b name)
  (and b (let ([seen (make-thread-cell #f #f)])
           (chaperone-box b
             (lambda (bx v) (thread-cell-set! seen v) (push! (vector 'unbox (if (eq? (current-thread) main-thread) 'main 'worker) name round-no #f #f)) v)
             (lambda (bx v)
               (define lost? (not (eq? (unbox b) (thread-cell-ref seen))))
               (push! (vector 'set (if (eq? (current-thread) main-thread) 'main 'worker) name round-no (eq-hash-code (current-thread)) lost?))
               (thread-cell-set! seen v) v)))))
(define base (if (equal? (getenv "EXEC") "seq") sequential-fire-all (current-parallel-executor)))
(define wide 0)
(define (wrapped snap pids)
  (set! round-no (add1 round-no))
  (when (>= (length pids) 8) (set! wide (add1 wide)))
  (parameterize ([current-prop-net-box (chap (current-prop-net-box) 'prop-net-box)]
                 [current-persistent-registry-net-box (chap (current-persistent-registry-net-box) 'registry-net-box)])
    (base snap pids)))
(define sub `(submod (file ,(path->string f)) test))
(parameterize ([current-parallel-executor wrapped])
  (with-handlers ([exn:fail? (lambda (e) (eprintf "W24-TEST-RAISE: ~a\n" (exn-message e)))])
    (if (module-declared? sub #t) (dynamic-require sub #f) (dynamic-require `(file ,(path->string f)) #f))))
(test-log #:display? #t #:exit? #f)
(define tally (make-hash))
(for ([e (unbox ev)])
  (hash-update! tally (format "~a_~a_~a" (vector-ref e 0) (vector-ref e 1) (vector-ref e 2)) add1 0)
  (when (vector-ref e 5) (hash-update! tally (format "LOST_~a_~a" (vector-ref e 1) (vector-ref e 2)) add1 0)))
(define worker-set-rounds (make-hash))
(for ([e (unbox ev)] #:when (and (eq? (vector-ref e 0) 'set) (eq? (vector-ref e 1) 'worker)))
  (hash-update! worker-set-rounds (vector-ref e 3) (lambda (s) (if (memv (vector-ref e 4) s) s (cons (vector-ref e 4) s))) '()))
(printf "W24T ~a\n" (jsexpr->string (hash-set* (for/hasheq ([(k v) (in-hash tally)]) (values (string->symbol k) v))
                                           'rounds round-no 'wide_rounds wide
                                           'rounds_with_worker_set (hash-count worker-set-rounds)
                                           'rounds_with_2plus_worker_threads_setting (for/sum ([(k v) (in-hash worker-set-rounds)]) (if (>= (length v) 2) 1 0)))))
