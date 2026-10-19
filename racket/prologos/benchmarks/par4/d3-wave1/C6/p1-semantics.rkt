#lang racket/base
;; C6 probe 1 — semantics of parallel threads (no timing is evidence here).
;; Q1: does `thread #:pool 'own` exist and run in parallel?  Q3: what is inherited
;; (parameters, marks)?  Persistent executors and direct parameter assignment.
;; Prompts delimit mark reads.  What happens to an exception in a parallel thread.
(require racket/future racket/unsafe/ops racket/fixnum)

(printf "version ~a  vm ~a  arch ~a  machine-os ~a\n" (version) (system-type 'vm) (system-type 'arch) (system-type 'os*))
(printf "futures-enabled? ~a  processor-count ~a\n" (futures-enabled?) (processor-count))

;; ---- Q1: parallelism check by CPU time vs wall (2 threads of fixnum work) ----
(define (spin-work n) (let loop ([i 0] [a 0]) (if (fx= i n) a (loop (fx+ i 1) (fxand (fx+ a i) #xFFFFF)))))
(define N 200000000)
(define (run-k k)
  (collect-garbage)
  (define t0 (current-inexact-milliseconds))
  (define c0 (current-process-milliseconds))
  (define ths (for/list ([i k]) (thread #:pool 'own #:keep 'results (lambda () (spin-work (quotient N k))))))
  (for-each thread-wait ths)
  (list k (round (- (current-inexact-milliseconds) t0)) (- (current-process-milliseconds) c0)))
(printf "Q1 parallel check (k wall-ms process-cpu-ms), same total work:\n  ~a\n  ~a\n" (run-k 1) (run-k 2))

;; ---- Q3a: parameter inherited, mark not ----
(define p (make-parameter 'root))
(define k (make-continuation-mark-key 'fire-ctx))
(define (in-thread pool thunk)
  (define t (if pool (thread #:pool pool #:keep 'results thunk) (thread #:keep 'results thunk)))
  (thread-wait t))
(define q3a
  (parameterize ([p 'set-by-creator])
    (with-continuation-mark k 'mark-by-creator
      (list (list 'creator: (p) (continuation-mark-set-first #f k))
            (list 'coroutine-child: (in-thread #f (lambda () (list (p) (continuation-mark-set-first #f k)))))
            (list 'parallel-child: (in-thread 'own (lambda () (list (p) (continuation-mark-set-first #f k)))))))))
(printf "Q3a (param mark) per context: ~s\n" q3a)

;; ---- Q3b: persistent executor (created once) vs later solves ----
(define job (box #f))      ; thunk to run
(define result (box 'none))
(define stop (box #f))
(define q (make-parameter 'q-at-load))
(define exec
  (parameterize ([q 'q-at-executor-creation])
    (thread #:pool 'own
            (lambda ()
              (let loop ()
                (unless (unbox stop)
                  (define j (unbox job))
                  (cond [j (set-box! job #f) (set-box! result (j)) (loop)]
                        [else (loop)])))))))
(define (submit! thunk)
  (set-box! result 'none)
  (memory-order-release)
  (set-box! job thunk)
  (let wait () (if (eq? (unbox result) 'none) (wait) (begin (memory-order-acquire) (unbox result)))))
;; (i) main's current value under no parameterize
(printf "Q3b main sees ~s\n" (q))
(printf "Q3b executor reads (q) plainly: ~s\n" (submit! (lambda () (q))))
;; (ii) main assigns q directly (as driver.rkt:3350 does with registries)
(q 'q-assigned-directly-by-main)
(printf "Q3b after main's direct assignment, main sees ~s; executor sees ~s\n" (q) (submit! (lambda () (q))))
;; (iii) executor runs the job under main's captured parameterization
(define par-main (current-parameterization))
(printf "Q3b executor under call-with-parameterization(main's): ~s\n"
        (submit! (lambda () (call-with-parameterization par-main (lambda () (q))))))
;; (iv) a parameterize in main, captured
(define par-pz (parameterize ([q 'q-parameterized-by-solve]) (current-parameterization)))
(printf "Q3b executor under captured parameterize: ~s\n"
        (submit! (lambda () (call-with-parameterization par-pz (lambda () (q))))))
;; (v) a mutable value reached through a parameter is shared, not copied
(define bx-param (make-parameter (box 0)))
(define shared-box (bx-param))
(submit! (lambda () (set-box! (bx-param) 42) 'ok))
(printf "Q3b box reached via inherited parameter: same object? ~a, main now reads ~a\n"
        (eq? shared-box (bx-param)) (unbox (bx-param)))

;; ---- Q3c: a default-tag prompt hides a mark but not a parameter ----
(define q3c
  (parameterize ([p 'param-outside-prompt])
    (with-continuation-mark k 'mark-outside-prompt
      (call-with-continuation-prompt
       (lambda ()
         (list (p) (continuation-mark-set-first #f k)
               ;; reading with a never-installed private tag sees through the default prompt
               (continuation-mark-set-first #f k #f (make-continuation-prompt-tag 'private))))))))
(printf "Q3c inside a default prompt: param=~s mark(default tag)=~s mark(private tag)=~s\n"
        (car q3c) (cadr q3c) (caddr q3c))

;; ---- exception raised inside a parallel thread ----
(define ex-done (box #f))
(define t-ex (thread #:pool 'own
                     (lambda ()
                       (with-continuation-mark k 'srcloc-of-fire
                         (begin (car '()) (set-box! ex-done #t))))))
(sync/timeout 2 t-ex)
(printf "EXC: thread-dead? ~a  done-flag ~a  (a spinner waiting on done-flag would wait forever)\n"
        (thread-dead? t-ex) (unbox ex-done))
;; caught and transported as a value, keeping the raise-point marks
(define ex-slot (box #f))
(define t-ex2 (thread #:pool 'own
                      (lambda ()
                        (with-handlers ([(lambda (e) #t)
                                         (lambda (e) (set-box! ex-slot e))])
                          (with-continuation-mark k 'srcloc-of-fire (car '()))))))
(thread-wait t-ex2)
(define e (unbox ex-slot))
(printf "EXC transported: exn? ~a  mark at raise point via exn marks: ~s\n"
        (exn? e) (continuation-mark-set-first (exn-continuation-marks e) k))

(set-box! stop #t)
(sync/timeout 2 exec)
(printf "done\n")
