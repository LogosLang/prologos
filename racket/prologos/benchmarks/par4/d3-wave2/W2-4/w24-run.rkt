#lang racket/base
;; W2-4 harness (PAR 4 D.3 wave 2, production-defect settler). Read-only on the repository; no rebuild.
;; ONE .prologos file per process:   racket w24-run.rkt FILE.prologos
;; Prints one "i: result" line per command (run-file.rkt's format) and one "W24 {json}" summary line.
;; process-file itself prints PERF-COUNTERS / PROVENANCE-STATS / CELL-METRICS on stderr.
;;
;; Environment knobs (all instruments are injected through exported parameters or the stratum-handler box):
;;   STRAT  = auto (default: no override) | dfs | atms   -> current-solver-strategy-override
;;   EXEC   = prod (default: the driver's thread executor) | seq (sequential-fire-all)
;;   OUTER  = 1  : observer + wrapped stratum handlers -> max strata outer-round per BSP run
;;   NONFIX = 1  : generic non-fixpoint detector at every observed S0 quiescence (all propagators re-fired on the
;;                 round's result network) and at every executor entry (propagators NOT on the round's worklist
;;                 re-fired on the snapshot); fires run sandboxed (copied boxes, counters off, observer off)
;;   RACE   = 1  : chaperone current-prop-net-box / current-persistent-registry-net-box for the duration of each
;;                 executor call; count unbox/set-box! by thread and detect lost updates (a set-box! whose
;;                 thread did not read the value it overwrites)
;;   ROUTES = 1  : par4-enable-counters!; print solve routes (tier1 | dfs | atms) and fork count
(require racket/list racket/port racket/string racket/path racket/vector json
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt")
                  process-file)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/errors.rkt")
                  prologos-error? prologos-error-message)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
                  current-bsp-observer current-parallel-executor sequential-fire-all fire-and-collect-writes
                  bsp-round-round-number bsp-round-network-snapshot bsp-round-propagators-fired
                  prop-network-propagators prop-network-worklist prop-network-cells
                  propagator-flags propagator-outputs propagator-inputs
                  prop-id-n prop-id-hash cell-id-n net-cell-read fuel-cell-id relation-store-cell-id
                  par4-enable-counters! par4-fork-count)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/champ.rkt")
                  champ-fold champ-lookup)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/metavar-store.rkt")
                  current-prop-net-box current-persistent-registry-net-box)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/performance-counters.rkt")
                  current-perf-counters
                  set-perf-counters-unify-steps! set-perf-counters-reduce-steps! set-perf-counters-elaborate-steps! set-perf-counters-infer-steps! set-perf-counters-trait-resolve-steps! set-perf-counters-meta-created! set-perf-counters-meta-solved! set-perf-counters-constraint-count! set-perf-counters-constraint-retries! set-perf-counters-solver-backtracks! set-perf-counters-solver-unifies! set-perf-counters-zonk-steps! set-perf-counters-resolution-cycles! set-perf-counters-prop-firings! set-perf-counters-cell-allocs! set-perf-counters-prop-allocs! set-perf-counters-inert-dependent-skips! set-perf-counters-solver-row-scans! set-perf-counters-solver-col-compares!)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/stratified-eval.rkt")
                  current-solver-strategy-override par4-solve-routes))

(define R "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/")
(define file (vector-ref (current-command-line-arguments) 0))
(define (env k [d #f]) (or (getenv k) d))
(define strat (env "STRAT" "auto"))
(define exec-mode (env "EXEC" "prod"))
(define outer? (equal? (env "OUTER") "1"))
(define nonfix? (equal? (env "NONFIX") "1"))
(define race? (equal? (env "RACE") "1"))
(define perfchap? (equal? (env "PERFCHAP") "1"))
(define routes? (equal? (env "ROUTES") "1"))
(define main-thread (current-thread))
(define summary (make-hasheq))
(define (inc! k [d 1]) (hash-set! summary k (+ d (hash-ref summary k 0))))

;; ---------------------------------------------------------------- non-fixpoint detector
(define (fr-field r i) (vector-ref (struct->vector r) i))   ; fire-result is #:transparent
;; fire-result fields: 1 value-writes 2 new-cells 3 new-propagators 4 contradiction 5 undeclared-writes
(define (sandboxed thunk)
  (define nb (current-prop-net-box))
  (define rb (current-persistent-registry-net-box))
  (parameterize ([current-prop-net-box (and nb (box (unbox nb)))]
                 [current-persistent-registry-net-box (and rb (box (unbox rb)))]
                 [current-perf-counters #f]
                 [current-bsp-observer #f])
    (thunk)))
;; Re-fire every propagator of `net` (except those in `skip`) once against `net`; return the list of
;; (pid-n . changed-cell-ns) whose fire would change a cell (value-write or undeclared write) or contradict.
(define (nonfix-pids net [skip '()])
  (define skipset (for/hasheqv ([p (in-list skip)]) (values (prop-id-n p) #t)))
  (define pids (champ-fold (prop-network-propagators net) (lambda (k v acc) (cons k acc)) '()))
  (sandboxed
   (lambda ()
     (for/fold ([acc '()]) ([pid (in-list pids)] #:unless (hash-ref skipset (prop-id-n pid) #f))
       (define r (with-handlers ([exn:fail? (lambda (e) (inc! 'nonfix_fire_exn) #f)])
                   (fire-and-collect-writes net pid 0)))
       (cond
         [(not r) acc]
         [else
          (define vw (fr-field r 1)) (define uw (fr-field r 5)) (define con (fr-field r 4))
          (if (or (pair? vw) (pair? uw) con)
              (cons (list (prop-id-n pid) (map (lambda (w) (cell-id-n (car w))) (append vw uw)) (and con #t)
                          (let ([p (champ-lookup (prop-network-propagators net) (prop-id-hash pid) pid)])
                            (if (eq? p 'none) '? (propagator-flags p))))
                    acc)
              acc)])))))
(define (solver-net? net)
  (let ([v (net-cell-read net relation-store-cell-id)]) (and (hash? v) (positive? (hash-count v)))))
(define nonfix-all? (equal? (env "NONFIX_ALL") "1"))
(define (check-net? net) (or nonfix-all? (solver-net? net)))
(define nonfix-examples '())
(define (record-nonfix! where net bad)
  (inc! (string->symbol (format "nonfix_~a_points" where)))
  (when (pair? bad)
    (inc! (string->symbol (format "nonfix_~a_flagged_points" where)))
    (inc! (string->symbol (format "nonfix_~a_flagged_props" where)) (length bad))
    (when (< (length nonfix-examples) 6)
      (set! nonfix-examples (cons (list where (if (solver-net? net) "solver" "other") (take bad (min 3 (length bad)))) nonfix-examples)))))

;; ---------------------------------------------------------------- outer-round tracking (observer + handlers)
;; A run is a chain of observer records linked by the fuel cell: a round's input fuel = its output fuel + |pids|
;; (the round writes fuel := fuel - n into its snapshot, and the merge does not write fuel). A round-0 record
;; continues a run only if a wrapped stratum handler just produced S0 work on a network with that fuel.
(define runs (make-hash))          ; out-fuel -> (mcons run-id outer)
(define pending (make-hash))       ; fuel -> #t  (handler produced S0 work on a net with this fuel)
(define run-max (make-hasheqv))    ; run-id -> max outer
(define next-run 0)
(define (outer-observe r)
  (define net (bsp-round-network-snapshot r))
  (define n (length (bsp-round-propagators-fired r)))
  (define f-out (net-cell-read net fuel-cell-id))
  (define f-in (+ f-out n))
  (define rn (bsp-round-round-number r))
  (cond
    [(zero? rn)
     (define cont (hash-ref pending f-in #f))   ; the run record captured when the handler was entered
     (hash-remove! pending f-in)
     (when cont (inc! 'outer_continuations))
     (define rec (if cont
                     (mcons (mcar cont) (add1 (mcdr cont)))
                     (begin0 (mcons next-run 0) (set! next-run (add1 next-run)))))
     (hash-remove! runs f-in)
     (hash-set! runs f-out rec)
     (hash-set! run-max (mcar rec) (max (mcdr rec) (hash-ref run-max (mcar rec) 0)))]
    [else
     (define rec (hash-ref runs f-in #f))
     (cond [rec (hash-remove! runs f-in) (hash-set! runs f-out rec)]
           [else (inc! 'outer_unlinked_rounds)
                 (hash-set! runs f-out (begin0 (mcons next-run 0) (set! next-run (add1 next-run))))])]))
(define (wrap-handlers!)
  (define ns (module->namespace (string->path (string-append R "propagator.rkt"))))
  (define sh (eval 'stratum-handlers ns))
  (define worklist-of (lambda (n) (prop-network-worklist n)))
  (set-box! sh
            (for/list ([e (in-list (unbox sh))])
              (define f (cadr e))
              (list* (car e)
                     (lambda (net pend)
                       ;; capture the owning run BEFORE the handler runs: nested runs on forks that share this
                       ;; fuel value would otherwise clobber the fuel-keyed link
                       (define F (net-cell-read net fuel-cell-id))
                       (define rec (or (hash-ref runs F #f) (begin0 (mcons next-run 0) (set! next-run (add1 next-run)))))
                       (define out (f net pend))
                       (inc! 'handler_calls)
                       (when (pair? (worklist-of out))
                         (inc! 'handler_produced_s0)
                         (hash-set! pending F rec))
                       out)
                     (cddr e)))))

;; ---------------------------------------------------------------- race instrument
(define ev-box (box '()))   ; lock-free event list: (kind thread-class box-name round)
(define (push-ev! e) (let loop () (define old (unbox ev-box)) (unless (box-cas! ev-box old (cons e old)) (loop))))
(define round-no 0)
(define (instrument-box b name)
  (and b
       (let ([seen (make-thread-cell #f #f)])
         (chaperone-box b
                        (lambda (bx v) (thread-cell-set! seen v)
                          (push-ev! (vector 'unbox (if (eq? (current-thread) main-thread) 'main 'worker) name round-no (eq-hash-code (current-thread)) #f))
                          v)
                        (lambda (bx v)
                          (define before (unbox b))
                          (define lost? (not (eq? before (thread-cell-ref seen))))
                          (push-ev! (vector 'set (if (eq? (current-thread) main-thread) 'main 'worker) name round-no (eq-hash-code (current-thread)) lost?))
                          (thread-cell-set! seen v)
                          v)))))


;; ---------------------------------------------------------------- perf-counter chaperone (PERFCHAP=1)
;; Counts every perf-counter mutation made DURING an executor call, by thread class, so that a PERF-COUNTERS
;; comparison between executors has a denominator (how many increments the fires made off the main thread).
(define pc-main (box 0)) (define pc-worker (box 0)) (define pc-lost 0)
(define (cas-inc! b) (let loop () (define o (unbox b)) (unless (box-cas! b o (add1 o)) (loop))))
(define pc-fields (make-hasheq))
(define (chaperone-pc pc)
  (and pc
       (chaperone-struct pc
         set-perf-counters-unify-steps! (lambda (s v) (cas-inc! (if (eq? (current-thread) main-thread) pc-main pc-worker)) (unless (eq? (current-thread) main-thread) (hash-set! pc-fields 'unify-steps #t)) v)
         set-perf-counters-reduce-steps! (lambda (s v) (cas-inc! (if (eq? (current-thread) main-thread) pc-main pc-worker)) (unless (eq? (current-thread) main-thread) (hash-set! pc-fields 'reduce-steps #t)) v)
         set-perf-counters-elaborate-steps! (lambda (s v) (cas-inc! (if (eq? (current-thread) main-thread) pc-main pc-worker)) (unless (eq? (current-thread) main-thread) (hash-set! pc-fields 'elaborate-steps #t)) v)
         set-perf-counters-infer-steps! (lambda (s v) (cas-inc! (if (eq? (current-thread) main-thread) pc-main pc-worker)) (unless (eq? (current-thread) main-thread) (hash-set! pc-fields 'infer-steps #t)) v)
         set-perf-counters-trait-resolve-steps! (lambda (s v) (cas-inc! (if (eq? (current-thread) main-thread) pc-main pc-worker)) (unless (eq? (current-thread) main-thread) (hash-set! pc-fields 'trait-resolve-steps #t)) v)
         set-perf-counters-meta-created! (lambda (s v) (cas-inc! (if (eq? (current-thread) main-thread) pc-main pc-worker)) (unless (eq? (current-thread) main-thread) (hash-set! pc-fields 'meta-created #t)) v)
         set-perf-counters-meta-solved! (lambda (s v) (cas-inc! (if (eq? (current-thread) main-thread) pc-main pc-worker)) (unless (eq? (current-thread) main-thread) (hash-set! pc-fields 'meta-solved #t)) v)
         set-perf-counters-constraint-count! (lambda (s v) (cas-inc! (if (eq? (current-thread) main-thread) pc-main pc-worker)) (unless (eq? (current-thread) main-thread) (hash-set! pc-fields 'constraint-count #t)) v)
         set-perf-counters-constraint-retries! (lambda (s v) (cas-inc! (if (eq? (current-thread) main-thread) pc-main pc-worker)) (unless (eq? (current-thread) main-thread) (hash-set! pc-fields 'constraint-retries #t)) v)
         set-perf-counters-solver-backtracks! (lambda (s v) (cas-inc! (if (eq? (current-thread) main-thread) pc-main pc-worker)) (unless (eq? (current-thread) main-thread) (hash-set! pc-fields 'solver-backtracks #t)) v)
         set-perf-counters-solver-unifies! (lambda (s v) (cas-inc! (if (eq? (current-thread) main-thread) pc-main pc-worker)) (unless (eq? (current-thread) main-thread) (hash-set! pc-fields 'solver-unifies #t)) v)
         set-perf-counters-zonk-steps! (lambda (s v) (cas-inc! (if (eq? (current-thread) main-thread) pc-main pc-worker)) (unless (eq? (current-thread) main-thread) (hash-set! pc-fields 'zonk-steps #t)) v)
         set-perf-counters-resolution-cycles! (lambda (s v) (cas-inc! (if (eq? (current-thread) main-thread) pc-main pc-worker)) (unless (eq? (current-thread) main-thread) (hash-set! pc-fields 'resolution-cycles #t)) v)
         set-perf-counters-prop-firings! (lambda (s v) (cas-inc! (if (eq? (current-thread) main-thread) pc-main pc-worker)) (unless (eq? (current-thread) main-thread) (hash-set! pc-fields 'prop-firings #t)) v)
         set-perf-counters-cell-allocs! (lambda (s v) (cas-inc! (if (eq? (current-thread) main-thread) pc-main pc-worker)) (unless (eq? (current-thread) main-thread) (hash-set! pc-fields 'cell-allocs #t)) v)
         set-perf-counters-prop-allocs! (lambda (s v) (cas-inc! (if (eq? (current-thread) main-thread) pc-main pc-worker)) (unless (eq? (current-thread) main-thread) (hash-set! pc-fields 'prop-allocs #t)) v)
         set-perf-counters-inert-dependent-skips! (lambda (s v) (cas-inc! (if (eq? (current-thread) main-thread) pc-main pc-worker)) (unless (eq? (current-thread) main-thread) (hash-set! pc-fields 'inert-dependent-skips #t)) v)
         set-perf-counters-solver-row-scans! (lambda (s v) (cas-inc! (if (eq? (current-thread) main-thread) pc-main pc-worker)) (unless (eq? (current-thread) main-thread) (hash-set! pc-fields 'solver-row-scans #t)) v)
         set-perf-counters-solver-col-compares! (lambda (s v) (cas-inc! (if (eq? (current-thread) main-thread) pc-main pc-worker)) (unless (eq? (current-thread) main-thread) (hash-set! pc-fields 'solver-col-compares #t)) v))))

;; ---------------------------------------------------------------- executor wrapper
(define base-exec (if (equal? exec-mode "seq") sequential-fire-all (current-parallel-executor)))
(define (wrapped-exec snap pids)
  (set! round-no (add1 round-no))
  (unless (eq? (current-thread) main-thread) (inc! 'exec_calls_off_main_thread))
  (inc! 'exec_rounds) (inc! 'exec_fires (length pids))
  (when (>= (length pids) 8) (inc! 'exec_wide_rounds))
  (when (and nonfix? (check-net? snap))
    (record-nonfix! 'entry snap (nonfix-pids snap pids)))
  (define (go) (if perfchap?
                   (let* ([pc (current-perf-counters)]
                          [before (and pc (vector-copy (struct->vector pc)))]
                          [att0 (+ (unbox pc-main) (unbox pc-worker))]
                          [r (parameterize ([current-perf-counters (chaperone-pc pc)]) (base-exec snap pids))])
                     (when pc
                       ;; exact attempts (CAS-counted by the chaperone) vs the field deltas actually stored
                       (define after (struct->vector pc))
                       (define stored (for/sum ([i (in-range 1 (vector-length after))]) (- (vector-ref after i) (vector-ref before i))))
                       (define attempts (- (+ (unbox pc-main) (unbox pc-worker)) att0))
                       (set! pc-lost (+ pc-lost (- attempts stored))))
                     r)
                   (base-exec snap pids)))
  (if race?
      (parameterize ([current-prop-net-box (instrument-box (current-prop-net-box) 'prop-net-box)]
                     [current-persistent-registry-net-box (instrument-box (current-persistent-registry-net-box) 'registry-net-box)])
        (go))
      (go)))

(define (observer r)
  (unless (eq? (current-thread) main-thread) (inc! 'observer_calls_off_main_thread))
  (when outer? (outer-observe r))
  (when nonfix?
    (define net (bsp-round-network-snapshot r))
    (when (and (null? (prop-network-worklist net)) (check-net? net))  ; end of an inner loop = S0 quiescence
      (record-nonfix! 'quiescence net (nonfix-pids net)))))

;; ---------------------------------------------------------------- run
(when outer? (wrap-handlers!))
(when routes? (par4-enable-counters!))
(define override (case strat [("dfs") 'depth-first] [("atms") 'atms] [else #f]))
(define t0 (current-inexact-monotonic-milliseconds))
(define results
  (parameterize ([current-solver-strategy-override override]
                 [current-parallel-executor wrapped-exec]
                 [current-bsp-observer (and (or outer? nonfix?) observer)])
    (process-file file)))
(define wall (- (current-inexact-monotonic-milliseconds) t0))
(define (result->string r)
  (cond [(prologos-error? r) (format "ERROR: ~a" (prologos-error-message r))]
        [(string? r) r]
        [else (format "~a" r)]))
(for ([r (in-list results)] [i (in-naturals)]) (printf "~a: ~a\n" i (result->string r)))
(printf "\n--- ~a errors ---\n" (for/sum ([r (in-list results)]) (if (prologos-error? r) 1 0)))
(when outer?
  (define ms (hash-values run-max))
  (hash-set! summary 'outer_runs (length ms))
  (hash-set! summary 'outer_max (if (null? ms) 0 (apply max ms)))
  (hash-set! summary 'outer_hist (for/hash ([(k v) (in-hash (for/fold ([h (hasheqv)]) ([m ms]) (hash-update h m add1 0)))])
                                   (values (string->symbol (number->string k)) v))))
(when race?
  (define evs (unbox ev-box))
  (for ([e (in-list evs)])
    (inc! (string->symbol (format "race_~a_~a_~a" (vector-ref e 0) (vector-ref e 1) (vector-ref e 2))))
    (when (vector-ref e 5) (inc! (string->symbol (format "race_LOST_~a_~a" (vector-ref e 1) (vector-ref e 2))))))
  ;; rounds in which >= 2 distinct worker threads set the same box
  (define by-round (make-hash))
  (for ([e (in-list evs)] #:when (and (eq? (vector-ref e 0) 'set) (eq? (vector-ref e 1) 'worker)))
    (hash-update! by-round (cons (vector-ref e 3) (vector-ref e 2)) (lambda (s) (if (memv (vector-ref e 4) s) s (cons (vector-ref e 4) s))) '()))
  (hash-set! summary 'race_rounds_multi_worker_set (for/sum ([(k v) (in-hash by-round)]) (if (>= (length v) 2) 1 0)))
  (hash-set! summary 'race_rounds_any_worker_set (hash-count by-round)))
(when routes?
  (hash-set! summary 'routes (for/hash ([(k v) (in-hash par4-solve-routes)]) (values k v)))
  (hash-set! summary 'forks (unbox par4-fork-count)))
(when perfchap?
  (hash-set! summary 'perf_incs_in_exec_main (unbox pc-main))
  (hash-set! summary 'perf_incs_in_exec_worker (unbox pc-worker))
  (hash-set! summary 'perf_incs_LOST_in_exec pc-lost)
  (hash-set! summary 'perf_fields_worker (format "~a" (hash-keys pc-fields))))
(when nonfix? (hash-set! summary 'nonfix_examples (format "~s" (reverse nonfix-examples))))
(hash-set! summary 'strat strat) (hash-set! summary 'exec exec-mode) (hash-set! summary 'wall_ms (round wall))
(hash-set! summary 'file (path->string (file-name-from-path file)))
(printf "W24 ~a\n" (jsexpr->string summary))
