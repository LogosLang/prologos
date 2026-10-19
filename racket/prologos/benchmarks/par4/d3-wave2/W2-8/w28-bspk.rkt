#lang racket/base
;;; W2-8 probe 2: REAL K > 1 on S0, no rebuild — round-synchronous "BSP-K" executors injected through
;;; current-parallel-executor (propagator.rkt:3675), A/B against the sequential executor, interleaved.
;;;   racket w28-bspk.rkt TARGET REPS
;;;   TARGET = a .prologos path (process-file, prelude preloaded), or micro:<name> (w28-micro.rkt builders,
;;;            copied verbatim from benchmarks/micro/bench-parallel-demos.rkt; run-to-quiescence).
;;;
;;; Legs (every executor returns results IN PID ORDER with the same namespace idx as sequential-fire-all,
;;; so bulk-merge-writes applies them in the same canonical order => the run is deterministic at every K):
;;;   seq     sequential-fire-all (the parameter #f)
;;;   prod    (make-parallel-thread-fire-all) — production (driver.rkt:567): fresh 'own OS thread per chunk per round
;;;   poolK   one (make-parallel-thread-pool K) created once; per round of width >= MIN, K fresh Racket threads
;;;           #:pool pool (OS threads reused; thread creation inherits the creator's parameters exactly as prod),
;;;           placement DYNAMIC: each grabs the next index from a box-cas! counter
;;;   parkK   K-1 persistent #:pool 'own workers created once, parked on semaphores between rounds, + the caller;
;;;           the round's parameterization is captured and installed with call-with-parameterization (CL-13 interim);
;;;           dynamic placement as above
;;;   drop    POWER ROW for the equivalence check: sequential, but the first productive result of every round
;;;           is replaced by an empty write list — must be flagged as different
;;; current-tree-reduce-threshold is #f in EVERY leg (O-9 deletes the tree path; at HEAD its default 256 sends
;;; rounds >= 256 wide through green-thread pair reduction, DEFERRED 150).
;;; Free parameters: K (4, 8), MIN = 8 (rounds narrower than MIN run sequentially, as prod's threshold).
;;; Reported per leg: median over REPS of run wall, S0 fire-ms, S0 merge-ms (current-bsp-round-stats), and
;;; whether the output (process-file's RESULT LIST printed with ~s — a bare process-file prints nothing —
;;; or every cell value for micro) equals seq's on every rep, and
;;; whether the per-round (width, value-write count) sequence equals seq's (stdout alone had NO power on the heavy
;;; files: the drop leg printed identical output).
(require racket/list racket/port racket/math racket/string json racket/future
         racket/unsafe/ops
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt")
                  process-file current-use-pnet-cache? current-pnet-write-enabled?)
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/champ.rkt")
                  champ-lookup champ-fold)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/errors.rkt")
                  prologos-error? prologos-error-message)
         (file "/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-8/w28-micro.rkt"))
;; Canonicalization: meta numbering (?metaNNN) depends on process history, and so does WHICH missing instance
;; type-adversarial reports at its results 23/25 (Buildable vs Seqable, period-3 pattern over consecutive runs in one
;; process under BOTH the sequential and the production executor — w28-tadiff.rkt). Both are normalized.
(define (canon-line s)
  (regexp-replace* #rx"No instance of (Buildable|Seqable)" (regexp-replace* #rx"\\?meta[0-9]+" s "?meta#") "No instance of <B|S>"))
;; tools/run-file.rkt:33-37's result->string (what scratch-run.sh prints)
(define (result->string r)
  (cond [(prologos-error? r) (format "ERROR: ~a" (prologos-error-message r))]
        [(string? r) r]
        [else (format "~a" r)]))

(define ROOT "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/")
(define args (current-command-line-arguments))
(define target (vector-ref args 0))
(define REPS (string->number (vector-ref args 1)))
(define MIN 8)
(define micro? (regexp-match? #rx"^micro:" target))

;; ---------------- executors ----------------
(define (fr-writes r)
  (cond [(list? r) r]
        [else (define v (struct->vector r))
              (if (eq? (vector-ref v 0) 'struct:fire-result) (vector-ref v 1) '())]))

(define main-thread (current-thread))
(define off-main (box 0)) (define on-main (box 0))   ; fires executed off / on the calling thread, in wide rounds
(define (bump! b) (let loop () (define c (unbox b)) (unless (box-cas! b c (add1 c)) (loop))))
(define (grab-loop! ctr n snap pv res)
  (let loop ()
    (define i (unbox ctr))
    (when (< i n)
      (if (box-cas! ctr i (add1 i))
          (begin (vector-set! res i (fire-and-collect-writes snap (vector-ref pv i) (add1 i)))
                 (bump! (if (eq? (current-thread) main-thread) on-main off-main))
                 (loop))
          (loop)))))

(define (make-pool-exec K)
  (define pool (make-parallel-thread-pool K))
  (lambda (snap pids)
    (define n (length pids))
    (if (< n MIN)
        (sequential-fire-all snap pids)
        (let* ([pv (list->vector pids)] [res (make-vector n #f)] [ctr (box 0)]
               [ths (for/list ([k (in-range (min K n))])
                      (thread #:pool pool (lambda () (grab-loop! ctr n snap pv res))))])
          (for-each thread-wait ths)
          (vector->list res)))))

(define (make-park-exec K)
  ;; K-1 workers; job box holds (vector snap pv res ctr pz done-box) for the current round
  (define job (box #f))
  (define sems (for/list ([k (in-range (sub1 K))]) (make-semaphore 0)))
  (for ([s (in-list sems)])
    (thread #:pool 'own
            (lambda ()
              (let loop ()
                (semaphore-wait s)
                (define j (unbox job))
                (call-with-parameterization (vector-ref j 4)
                  (lambda () (grab-loop! (vector-ref j 3) (vector-length (vector-ref j 1)) (vector-ref j 0) (vector-ref j 1) (vector-ref j 2))))
                (let inc () (define d (vector-ref j 5)) (define c (unbox d)) (unless (box-cas! d c (add1 c)) (inc)))
                (loop)))))
  (lambda (snap pids)
    (define n (length pids))
    (if (< n MIN)
        (sequential-fire-all snap pids)
        (let* ([pv (list->vector pids)] [res (make-vector n #f)] [ctr (box 0)] [done (box 0)]
               [j (vector snap pv res ctr (current-parameterization) done)])
          (set-box! job j)
          (memory-order-release)
          (for ([s (in-list sems)]) (semaphore-post s))
          (grab-loop! ctr n snap pv res)                       ; the caller works too
          (let spin () (memory-order-acquire) (unless (= (unbox done) (sub1 K)) (spin)))
          (vector->list res)))))

(define (drop-exec snap pids)
  (define rs (sequential-fire-all snap pids))
  (let loop ([rs rs] [dropped? #f])
    (cond [(null? rs) '()]
          [(and (not dropped?) (pair? (fr-writes (car rs)))) (cons '() (loop (cdr rs) #t))]
          [else (cons (car rs) (loop (cdr rs) dropped?))])))

(define legs
  (list (cons "seq" #f)
        (cons "prod" (make-parallel-thread-fire-all))
        (cons "pool4" (make-pool-exec 4))
        (cons "pool8" (make-pool-exec 8))
        (cons "park4" (make-park-exec 4))
        (cons "park8" (make-park-exec 8))
        (cons "drop" drop-exec)))

;; ---------------- one run ----------------
(define micro-net (and micro? (let-values ([(net _) (build-micro (substring target 6))]) net)))
(define (canon-net net)
  ;; every cell's value, by cell id
  (sort (champ-fold (prop-network-cells net) (lambda (k c acc) (cons (cons (cell-id-n k) (prop-cell-value c)) acc)) '())
        < #:key car))
(define (run-file* f out)
  (parameterize ([current-output-port out]
                 [current-error-port (open-output-nowhere)]
                 [current-use-pnet-cache? #t]
                 [current-pnet-write-enabled? #f])
    (process-file f)))
(unless micro? (run-file* (string-append ROOT "benchmarks/par4/preload-empty.prologos") (open-output-nowhere)))

(define (run-once exec)
  (set-box! off-main 0) (set-box! on-main 0)
  (define stats (box '()))
  (collect-garbage)
  (define out (open-output-string))
  (define t0 (current-inexact-monotonic-milliseconds))
  (define result
    (parameterize ([current-parallel-executor exec] [current-bsp-round-stats stats]
                   [current-tree-reduce-threshold #f])   ; O-9: the tree path is deleted (DEFERRED 150); off in every leg
      (if micro? (run-to-quiescence micro-net) (run-file* target out))))
  (define wall (- (current-inexact-monotonic-milliseconds) t0))
  (define rs (unbox stats))
  (vector wall (for/sum ([r rs]) (cadr r)) (for/sum ([r rs]) (caddr r)) (length rs)
          (length (filter (λ (r) (>= (car r) MIN)) rs))
          (if micro? (canon-net result) (map canon-line (map result->string result)))
          (reverse (map (λ (r) (list (car r) (cadddr r))) rs))
          (cons (unbox off-main) (unbox on-main))))   ; per-round (width, value-write count) in order

;; warm-up: one run per leg
(for ([l (in-list legs)]) (run-once (cdr l)))
(define reference-run (run-once #f))
(define reference (vector-ref reference-run 5))
(define reference-fp (vector-ref reference-run 6))
(define samples (make-hash))   ; leg -> list of vectors
(for ([rep (in-range REPS)])
  (define order (let ([k (modulo rep (length legs))]) (append (drop legs k) (take legs k))))  ; rotate
  (for ([l (in-list order)])
    (hash-update! samples (car l) (λ (xs) (cons (run-once (cdr l)) xs)) '())))
(define (med xs) (let ([s (sort xs <)]) (list-ref s (quotient (length s) 2))))
(define (r3 x) (/ (round (* 1000 (exact->inexact x))) 1000.0))
(define seq-s0 (med (map (λ (v) (+ (vector-ref v 1) (vector-ref v 2))) (hash-ref samples "seq"))))
(define seq-fire (med (map (λ (v) (vector-ref v 1)) (hash-ref samples "seq"))))
(printf "W28BSPK:~a\n"
  (jsexpr->string
   (hasheq 'target target 'reps REPS 'MIN MIN 'cores (processor-count)
           'legs
           (for/list ([l (in-list legs)])
             (define vs (hash-ref samples (car l)))
             (define fire (med (map (λ (v) (vector-ref v 1)) vs)))
             (define merge (med (map (λ (v) (vector-ref v 2)) vs)))
             (define s0 (med (map (λ (v) (+ (vector-ref v 1) (vector-ref v 2))) vs)))
             (hasheq 'leg (car l)
                     'wall_ms_med (r3 (med (map (λ (v) (vector-ref v 0)) vs)))
                     'wall_ms_range (list (r3 (apply min (map (λ (v) (vector-ref v 0)) vs))) (r3 (apply max (map (λ (v) (vector-ref v 0)) vs))))
                     'fire_ms_med (r3 fire) 'merge_ms_med (r3 merge) 's0_ms_med (r3 s0)
                     's0_ms_range (list (r3 (apply min (map (λ (v) (+ (vector-ref v 1) (vector-ref v 2))) vs)))
                                        (r3 (apply max (map (λ (v) (+ (vector-ref v 1) (vector-ref v 2))) vs))))
                     's0_speedup_vs_seq (r3 (/ seq-s0 (max 1e-9 s0)))
                     'fire_speedup_vs_seq (r3 (/ seq-fire (max 1e-9 fire)))
                     'rounds (vector-ref (car vs) 3) 'rounds_ge_MIN (vector-ref (car vs) 4)
                     'output_equal_seq_all_reps (for/and ([v vs]) (equal? (vector-ref v 5) reference))
                     'round_fingerprint_equal_seq_all_reps (for/and ([v vs]) (equal? (vector-ref v 6) reference-fp))
                     'wide_fires_off_caller_thread (car (vector-ref (car vs) 7)) 'wide_fires_on_caller_thread (cdr (vector-ref (car vs) 7)))))))
