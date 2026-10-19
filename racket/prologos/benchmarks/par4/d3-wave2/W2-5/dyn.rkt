#lang racket/base
;; W2-5 dynamic probe (PAR 4 D.3 wave 2, CL-13): ambient parameter state under injected executors.
;; No rebuild: everything goes through current-parallel-executor (propagator.rkt:3675).
;;
;; usage: racket dyn.rkt <census-params.tsv> <leg> <file.prologos> [<file2.prologos>]
;;   leg ∈ seq | fresh | prod | persist | persistcap
;;   seq        : sequential-fire-all on the calling (main) thread
;;   fresh      : ONE fresh `thread #:pool 'own` per BSP round runs sequential-fire-all for the
;;                whole round (today's per-round thread semantics, without chunking)
;;   prod       : production make-parallel-thread-fire-all (driver.rkt:567), uninstrumented
;;   persist    : ONE `thread #:pool 'own` created at harness start (after module load, before
;;                any process-file), reused for every round (D.2 §6.7 persistent executor)
;;   persistcap : same thread; each job runs under call-with-parameterization of the
;;                submitting thread's (current-parameterization) (C6-2 / CL-13 interim fix)
;; Instruments (all legs except prod): before the fires of a round, every production parameter
;; (all 219 from the census) is read on the executor thread and compared (eq?) with the value the
;; submitting thread sees -> STALE count per parameter; after the fires, compared with the
;; pre-fire value on the executor thread -> ASSIGNED-IN-FIRE count per parameter (a direct
;; assignment made by a fire; lost when the fire ran on a per-round thread).
;; Re-entrancy: an executor call made while an executor job is running on the same thread
;; (a nested run-to-quiescence inside a fire) is counted and run inline.
;; Output: one line "RESULT <i>: <string>" per process-file result, then "STATS ..." lines.
(require racket/list racket/string racket/port racket/file)
(define ROOT "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/")
(define driver-mod (list 'file (string-append ROOT "driver.rkt")))
(define prop-mod (list 'file (string-append ROOT "propagator.rkt")))
(define errors-mod (list 'file (string-append ROOT "errors.rkt")))
(define process-file (dynamic-require driver-mod 'process-file))
(define current-parallel-executor (dynamic-require prop-mod 'current-parallel-executor))
(define sequential-fire-all (dynamic-require prop-mod 'sequential-fire-all))
(define make-parallel-thread-fire-all (dynamic-require prop-mod 'make-parallel-thread-fire-all))
(define prologos-error? (dynamic-require errors-mod 'prologos-error?))
(define prologos-error-message (dynamic-require errors-mod 'prologos-error-message))

(define args (current-command-line-arguments))
(define tsv (vector-ref args 0))
(define leg (string->symbol (vector-ref args 1)))
(define files (for/list ([i (in-range 2 (vector-length args))]) (vector-ref args i)))

;; ---- all production parameters, as objects
(define PARAMS
  (for/fold ([acc '()] #:result (reverse acc))
            ([ln (in-list (cdr (file->lines tsv)))])
    (define cols (string-split ln "\t" #:trim? #f))
    (define name (string->symbol (car cols)))
    (define mod (car (string-split (cadr cols) ":")))
    (define mp (list 'file (string-append ROOT mod)))
    (define v
      (with-handlers ([exn:fail? (lambda (e)
                                   (with-handlers ([exn:fail? (lambda (e2) #f)])
                                     (parameterize ([current-namespace (module->namespace mp)])
                                       (namespace-variable-value name #t))))])
        (dynamic-require mp name)))
    (if (parameter? v) (cons (cons name v) acc) acc)))
(define NP (length PARAMS))
(define PVEC (list->vector (map cdr PARAMS)))
(define PNAMES (list->vector (map car PARAMS)))
(define (snapshot) (for/vector #:length NP ([p (in-vector PVEC)]) (p)))

;; ---- counters
(define stale-eq (make-vector NP 0))     ; rounds where executor-thread value not eq? to submitter's
(define stale-equal (make-vector NP 0))  ; ... and not equal?
(define assigned (make-vector NP 0))     ; rounds whose fires changed the executor thread's value
(define stale-example (make-vector NP #f))
(define rounds 0) (define fires 0) (define reentrant 0) (define wide-rounds 0)
(define (short v) (let ([s (format "~s" v)]) (if (> (string-length s) 70) (string-append (substring s 0 70) "…") s)))
(define (compare-pre! main-snap exec-snap)
  (for ([i (in-range NP)])
    (define a (vector-ref main-snap i)) (define b (vector-ref exec-snap i))
    (unless (eq? a b)
      (vector-set! stale-eq i (add1 (vector-ref stale-eq i)))
      (unless (equal? a b)
        (vector-set! stale-equal i (add1 (vector-ref stale-equal i)))
        (unless (vector-ref stale-example i)
          (vector-set! stale-example i (format "submitter=~a executor=~a" (short a) (short b))))))))
(define (compare-post! pre post)
  (for ([i (in-range NP)])
    (unless (eq? (vector-ref pre i) (vector-ref post i))
      (vector-set! assigned i (add1 (vector-ref assigned i))))))

;; one instrumented job: runs ON the executor thread
(define (instrumented-job main-snap snap pids)
  (define pre (snapshot))
  (when main-snap (compare-pre! main-snap pre))
  (define r (sequential-fire-all snap pids))
  (compare-post! pre (snapshot))
  r)

(define in-job (make-thread-cell #f #f))   ; non-preserved: #t only on the thread running a job

(define (count-round! pids)
  (set! rounds (add1 rounds))
  (set! fires (+ fires (length pids)))
  (when (>= (length pids) 8) (set! wide-rounds (add1 wide-rounds))))

(define (run-on-new-thread thunk)
  (define ch (make-channel))
  (thread #:pool 'own
          (lambda ()
            (channel-put ch (with-handlers ([(lambda (e) #t) (lambda (e) (cons 'exn e))])
                              (cons 'ok (thunk))))))
  (define r (sync/timeout 120 ch))
  (cond [(not r) (error 'dyn "executor thread did not answer in 120 s (dead thread / deadlock)")]
        [(eq? (car r) 'exn) (raise (cdr r))]
        [else (cdr r)]))

;; ---- persistent executor thread (created NOW: after module load, before any process-file)
(define job-box (box #f))
(define job-sema (make-semaphore 0))
(define persist-thread
  (and (memq leg '(persist persistcap))
       (thread #:pool 'own
               (lambda ()
                 (let loop ()
                   (semaphore-wait job-sema)
                   (define j (unbox job-box))
                   (set-box! job-box #f)
                   ((car j))
                   (loop))))))
(define (run-on-persist thunk)
  (define ch (make-channel))
  (set-box! job-box (list (lambda ()
                            (channel-put ch (with-handlers ([(lambda (e) #t) (lambda (e) (cons 'exn e))])
                                              (cons 'ok (thunk))))))
                          )
  (semaphore-post job-sema)
  (define r (sync/timeout 120 ch))
  (cond [(not r) (error 'dyn "persistent executor did not answer in 120 s")]
        [(eq? (car r) 'exn) (raise (cdr r))]
        [else (cdr r)]))

(define (make-exec)
  (case leg
    [(seq)
     (lambda (snap pids)
       (count-round! pids)
       (if (thread-cell-ref in-job)
           (begin (set! reentrant (add1 reentrant)) (sequential-fire-all snap pids))
           (begin (thread-cell-set! in-job #t)
                  (begin0 (instrumented-job #f snap pids) (thread-cell-set! in-job #f)))))]
    [(fresh)
     (lambda (snap pids)
       (count-round! pids)
       (when (thread-cell-ref in-job) (set! reentrant (add1 reentrant)))
       (define main-snap (snapshot))
       (run-on-new-thread (lambda () (thread-cell-set! in-job #t) (instrumented-job main-snap snap pids))))]
    [(wvpoison)
     ;; POWER ROW: fresh thread per round whose worker runs the fires with current-worldview-bitmask
     ;; deliberately wrong (bit 60). Results must differ wherever fires read the ambient worldview.
     (define cwb (dynamic-require prop-mod 'current-worldview-bitmask))
     (lambda (snap pids)
       (count-round! pids)
       (define main-snap (snapshot))
       (run-on-new-thread (lambda () (thread-cell-set! in-job #t)
                            (parameterize ([cwb (arithmetic-shift 1 60)]) (instrumented-job #f snap pids)))))]
    [(prod)
     (define p (make-parallel-thread-fire-all))
     (lambda (snap pids) (count-round! pids) (p snap pids))]
    [(persist persistcap)
     (lambda (snap pids)
       (count-round! pids)
       (cond
         [(eq? (current-thread) persist-thread)
          ;; nested run-to-quiescence inside a fire running on the persistent thread
          (set! reentrant (add1 reentrant))
          (sequential-fire-all snap pids)]
         [else
          (define main-snap (snapshot))
          (define paramz (current-parameterization))
          (run-on-persist
           (if (eq? leg 'persistcap)
               (lambda () (call-with-parameterization paramz (lambda () (instrumented-job main-snap snap pids))))
               (lambda () (instrumented-job main-snap snap pids))))]))]
    [else (error 'dyn "unknown leg ~a" leg)]))

(define exec (make-exec))
(define (result->string r)
  (cond [(prologos-error? r) (format "ERROR: ~a" (prologos-error-message r))]
        [(string? r) r]
        [else (format "~a" r)]))

;; optional instruments that fires ASSIGN (W25_SUBTYPE=1) or MUTATE (W25_PERF=1)
(define subtype-mod (list 'file (string-append ROOT "subtype-predicate.rkt")))
(define pc-mod (list 'file (string-append ROOT "performance-counters.rkt")))
(define current-subtype-check-count (dynamic-require subtype-mod 'current-subtype-check-count))
(define global-subtype-total
  (parameterize ([current-namespace (module->namespace subtype-mod)]) (namespace-variable-value 'global-subtype-total #t)))
(define current-perf-counters (dynamic-require pc-mod 'current-perf-counters))
(define perf-counters (dynamic-require pc-mod 'perf-counters))
(define perf-counters->hasheq (dynamic-require pc-mod 'perf-counters->hasheq))
(when (getenv "W25_SUBTYPE") (current-subtype-check-count (cons 0 0)))
(define pc (and (getenv "W25_PERF")
                (apply perf-counters (build-list (procedure-arity perf-counters) (lambda (_) 0)))))
(when pc (current-perf-counters pc))
(define t0 (current-inexact-milliseconds))
(for ([f (in-list files)] [fi (in-naturals)])
  (define results
    (with-handlers ([(lambda (e) #t)
                     (lambda (e) (list (format "HARNESS-EXCEPTION: ~a" (if (exn? e) (exn-message e) e))))])
      (parameterize ([current-parallel-executor exec]
                     [current-output-port (open-output-nowhere)])
        (process-file f))))
  (for ([r (in-list results)] [i (in-naturals)])
    (printf "RESULT ~a.~a: ~a\n" fi i (string-replace (result->string r) "\n" "\\n"))))
(printf "STATS leg=~a files=~a params=~a rounds=~a wide-rounds(>=8)=~a fires=~a reentrant=~a ms=~a\n"
        leg (length files) NP rounds wide-rounds fires reentrant (round (- (current-inexact-milliseconds) t0)))
(for ([i (in-range NP)])
  (when (or (positive? (vector-ref stale-eq i)) (positive? (vector-ref assigned i)))
    (printf "PARAM ~a stale-eq=~a stale-equal=~a assigned-in-fire=~a ~a\n"
            (vector-ref PNAMES i) (vector-ref stale-eq i) (vector-ref stale-equal i)
            (vector-ref assigned i) (or (vector-ref stale-example i) ""))))
(when (getenv "W25_SUBTYPE")
  (printf "SUBTYPE main-thread (current-subtype-check-count)=~s global-subtype-total=~a\n"
          (current-subtype-check-count) (unbox global-subtype-total)))
(when pc
  (define h (perf-counters->hasheq pc))
  (printf "PERF ~a\n" (string-join (for/list ([k (in-list (sort (hash-keys h) symbol<?))]) (format "~a=~a" k (hash-ref h k))) " ")))
(when persist-thread (kill-thread persist-thread))
