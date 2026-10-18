#lang racket/base
;; W2-5 dynamic probe 2 (PAR 4 D.3 wave 2, CL-13): PER-FIRE thread differential.
;; For every BSP round, the round's pids are fired three times against the SAME snapshot:
;;   R1 on the submitting (main) thread, R2 on the main thread again (determinism control),
;;   RX on the executor thread under test. The round continues with R1, so the run is the
;;   sequential run and divergences do not cascade.
;; A fire is THREAD-DIVERGENT when RX_i ≠ R1_i (equal?) while R2_i = R1_i.
;; usage: racket dyn2.rkt <leg> <file.prologos>
;;   leg ∈ fresh | persist | persistcap   (thread semantics as in dyn.rkt)
(require racket/list racket/string racket/port)
(define ROOT "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/")
(define (dr m n) (dynamic-require (list 'file (string-append ROOT m)) n))
(define process-file (dr "driver.rkt" 'process-file))
(define current-parallel-executor (dr "propagator.rkt" 'current-parallel-executor))
(define fire-and-collect-writes (dr "propagator.rkt" 'fire-and-collect-writes))
(require (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
                  prop-network-propagators prop-id-hash propagator-fire-fn propagator-srcloc)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/champ.rkt")
                  champ-lookup))
(define prologos-error? (dr "errors.rkt" 'prologos-error?))
(define prologos-error-message (dr "errors.rkt" 'prologos-error-message))

(define leg (string->symbol (vector-ref (current-command-line-arguments) 0)))
(define file (vector-ref (current-command-line-arguments) 1))

(define (fire-all snap pids)
  ;; per-fire, exceptions captured as values so one raising fire does not hide the others
  (for/list ([pid (in-list pids)] [idx (in-naturals 1)])
    (with-handlers ([(lambda (e) #t) (lambda (e) (list 'EXN (if (exn? e) (exn-message e) e)))])
      (fire-and-collect-writes snap pid idx))))

(define job-box (box #f))
(define job-sema (make-semaphore 0))
(define persist-thread
  (and (memq leg '(persist persistcap))
       (thread #:pool 'own (lambda () (let loop () (semaphore-wait job-sema)
                                        (define j (unbox job-box)) (set-box! job-box #f) (j) (loop))))))
(define (on-executor thunk)
  (define ch (make-channel))
  (define (job) (channel-put ch (with-handlers ([(lambda (e) #t) (lambda (e) (cons 'exn e))]) (cons 'ok (thunk)))))
  (case leg
    [(fresh) (thread #:pool 'own job)]
    [else (set-box! job-box job) (semaphore-post job-sema)])
  (define r (sync/timeout 120 ch))
  (cond [(not r) (error 'dyn2 "executor did not answer")]
        [(eq? (car r) 'exn) (raise (cdr r))]
        [else (cdr r)]))

(define rounds 0) (define nfires 0) (define ctrl-div 0) (define thread-div 0) (define reentrant 0)
(define by-fn (make-hash))   ; fire-fn name -> count of thread-divergent fires
(define examples (make-hash))
(define (fn-name snap pid)
  (define p (champ-lookup (prop-network-propagators snap) (prop-id-hash pid) pid))
  (if (eq? p 'none) "?"
      (format "~a" (or (object-name (propagator-fire-fn p)) "anon"))))
;; first differing path between two values (hash keys / struct fields / list indices)
(define (first-diff a b [path '()] [depth 0])
  (cond
    [(equal? a b) #f]
    [(> depth 12) (list (reverse path) a b)]
    [(and (hash? a) (hash? b))
     (or (for/or ([(k v) (in-hash a)])
           (if (hash-has-key? b k) (first-diff v (hash-ref b k) (cons k path) (add1 depth))
               (list (reverse (cons k path)) v 'MISSING)))
         (for/or ([(k v) (in-hash b)]) (and (not (hash-has-key? a k)) (list (reverse (cons k path)) 'MISSING v))))]
    [(and (pair? a) (pair? b))
     (or (first-diff (car a) (car b) (cons 'car path) (add1 depth)) (first-diff (cdr a) (cdr b) (cons 'cdr path) (add1 depth)))]
    [(and (struct? a) (struct? b))
     (define va (struct->vector a)) (define vb (struct->vector b))
     (if (= (vector-length va) (vector-length vb))
         (for/or ([x (in-vector va)] [y (in-vector vb)] [i (in-naturals)])
           (first-diff x y (cons (format "~a.~a" (vector-ref va 0) i) path) (add1 depth)))
         (list (reverse path) a b))]
    [else (list (reverse path) a b)]))
(define (short v) (let ([s (format "~s" v)]) (if (> (string-length s) 160) (string-append (substring s 0 160) "…") s)))

(define (exec snap pids)
  (cond
    [(and persist-thread (eq? (current-thread) persist-thread))
     (set! reentrant (add1 reentrant))
     (fire-all snap pids)]
    [else
     (set! rounds (add1 rounds))
     (set! nfires (+ nfires (length pids)))
     (define paramz (current-parameterization))
     (define RX (on-executor (if (eq? leg 'persistcap)
                                 (lambda () (call-with-parameterization paramz (lambda () (fire-all snap pids))))
                                 (lambda () (fire-all snap pids)))))
     (define R1 (fire-all snap pids))
     (define R2 (fire-all snap pids))
     (for ([pid (in-list pids)] [x (in-list RX)] [a (in-list R1)] [b (in-list R2)])
       (cond
         [(not (equal? a b)) (set! ctrl-div (add1 ctrl-div))]
         [(not (equal? a x))
          (set! thread-div (add1 thread-div))
          (define nm (fn-name snap pid))
          (hash-update! by-fn nm add1 0)
          (unless (hash-ref examples nm #f)
            (define fd (first-diff a x))
            (hash-set! examples nm (format "first-diff path=~a main=~a executor=~a"
                                           (short (car fd)) (short (cadr fd)) (short (caddr fd)))))]))
     ;; propagate any main-thread exception exactly as sequential-fire-all would
     (for ([a (in-list R1)]) (when (and (pair? a) (eq? (car a) 'EXN)) (error 'fire (cadr a))))
     R1]))

(define results
  (with-handlers ([(lambda (e) #t) (lambda (e) (list (format "HARNESS-EXCEPTION: ~a" (if (exn? e) (exn-message e) e))))])
    (parameterize ([current-parallel-executor exec] [current-output-port (open-output-nowhere)])
      (process-file file))))
(for ([r (in-list results)] [i (in-naturals)])
  (printf "RESULT ~a: ~a\n" i (string-replace (cond [(prologos-error? r) (format "ERROR: ~a" (prologos-error-message r))]
                                                    [(string? r) r] [else (format "~a" r)]) "\n" "\\n")))
(printf "STATS2 leg=~a rounds=~a fires=~a control-divergent=~a thread-divergent=~a reentrant=~a\n"
        leg rounds nfires ctrl-div thread-div reentrant)
(for ([(k v) (in-hash by-fn)])
  (printf "DIVFN ~a count=~a example: ~a\n" k v (hash-ref examples k)))
(when persist-thread (kill-thread persist-thread))
