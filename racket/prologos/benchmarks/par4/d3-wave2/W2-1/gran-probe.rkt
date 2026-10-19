#lang racket/base
;;; W2-1 granularity probe (PAR 4 D.3 wave 2).  Read-only on the repo.  ONE .prologos file per process:
;;;   racket gran-probe.rkt FILE.prologos OUT.json [TIMING-REPS]
;;; Thread executor OFF: every BSP round runs through an injected SEQUENTIAL executor
;;; (same calls as sequential-fire-all, propagator.rkt:3295), which times each fire.
;;;  rep A (analysis): per fire -> run/round (observer), pid, declared inputs (+ declared component paths from the
;;;        dependents entry), declared outputs (+ merge facts), the units each value-write CHANGED (pu-value-diff of
;;;        snapshot vs fire result: (position . facet) for the attribute map, key for flat compound cells, whole cell
;;;        otherwise), fire time.
;;;  reps T1..Tn (timing only, no observer): per-fire time + GC ms, and the pid sequence (checked against rep A).
;;; Free parameters: TIMING-REPS (default 5). K is applied later in the analysis (K in {4,8,16}).
;;; "fire time" = wall of fire-and-collect-writes (fire + BSP's per-fire collect: output equal?, champ-diff).
(require racket/list racket/port racket/string json
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt")
                  process-file current-use-pnet-cache? current-pnet-write-enabled?)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
                  current-parallel-executor current-bsp-observer bsp-round-round-number
                  fire-and-collect-writes net-cell-read-raw
                  prop-network-propagators prop-network-cells prop-network-merge-fns prop-network-contradiction-fns
                  prop-network-next-prop-id prop-network-next-cell-id
                  propagator-inputs propagator-outputs propagator-flags PROP-FIRE-ONCE
                  prop-cell-dependents dependent-entry? dependent-entry-paths
                  cell-id-n cell-id-hash prop-id-n prop-id-hash pu-value-diff)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/champ.rkt")
                  champ-lookup)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/meta-universe.rkt")
                  current-type-universe-merge current-type-meta-universe-cell-id))

(define args (current-command-line-arguments))
(define the-file (vector-ref args 0))
(define out-path (vector-ref args 1))
(define TREPS (if (> (vector-length args) 2) (string->number (vector-ref args 2)) 5))
(define preload "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/benchmarks/par4/preload-empty.prologos")

(define real-err (current-error-port))
(define (run-file* f)
  ;; parity-adversarial raises `solve: Depth limit exceeded (100)` out of process-file under the PRODUCTION
  ;; executor too (control-raise.rkt), so the probe records the raise and keeps the fires observed before it.
  (with-handlers ([exn:fail? (λ (e) (fprintf real-err "W2-1 probe: exception in ~a: ~a\n" f (exn-message e))
                                (set! raised (exn-message e)))])
    (run-file** f)))
(define raised #f)
(define (run-file** f)
  (parameterize ([current-output-port (open-output-nowhere)]
                 [current-error-port (open-output-nowhere)]
                 [current-use-pnet-cache? #t]
                 [current-pnet-write-enabled? #f])
    (void (process-file f))))
(run-file* preload)

(define (fn-name f)
  (cond [(procedure? f) (let ([n (object-name f)]) (if n (format "~a" n) "anon"))]
        [(eq? f 'none) "none"]
        [else (format "~a" f)]))

;; ---------------- unit encoding ----------------
(define key-index (make-hasheqv))           ; position / compound key (eq/eqv identity) -> small int
(define (kidx k) (hash-ref! key-index k (λ () (hash-count key-index))))
(define (path->unit cn p)                   ; a changed path or a declared path on cell cn
  (cond [(and (pair? p) (symbol? (cdr p))) (format "a~a:~a:~a" cn (kidx (car p)) (cdr p))] ; (position . facet)
        [else (format "a~a:~a:*" cn (kidx p))]))                                              ; flat key
;; whole-cell unit
(define (cell-unit cn) (format "c~a" cn))

(define (cell-facts snap cid)
  (define h (cell-id-hash cid))
  (define mf (champ-lookup (prop-network-merge-fns snap) h cid))
  (define cf (champ-lookup (prop-network-contradiction-fns snap) h cid))
  (define mname (fn-name mf))
  (define cname (fn-name cf))
  (define tum (current-type-universe-merge))
  (define tuc (current-type-meta-universe-cell-id))
  (define am? (equal? mname "attribute-map-merge-fn"))
  (define type-cell?
    (or (member mname '("type-unify-or-top" "type-lattice-merge"))
        (and (procedure? mf) (eq? mf tum))
        (and tuc (= (cell-id-n cid) (cell-id-n tuc)))
        (string-contains? cname "elaborator-network.rkt")))
  (hasheq 'n (cell-id-n cid) 'merge mname 'contra cname 'am am? 'type (and type-cell? #t)))

;; ---------------- rep A: analysis ----------------
(define fires '())           ; list of hasheq, reversed
(define pending '())         ; stack of executor-call records awaiting the observer
(define call-idx 0)
(define depth 0)
(define run-id -1)
(define seqA '())            ; pid-n sequence

(define (analysis-exec snap pids)
  (set! depth (add1 depth))
  (define my-call call-idx)
  (set! call-idx (add1 call-idx))
  (define props (prop-network-propagators snap))
  (define recs '())
  (define results
    (for/list ([pid (in-list pids)] [idx (in-naturals 1)])
      (define p (champ-lookup props (prop-id-hash pid) pid))
      (define t0 (current-inexact-monotonic-milliseconds))
      (define r (fire-and-collect-writes snap pid idx))
      (define t1 (current-inexact-monotonic-milliseconds))
      (set! seqA (cons (prop-id-n pid) seqA))
      (define rv (struct->vector r)) ; #(struct:fire-result value-writes new-cells new-propagators contradiction undeclared)
      (define vw (vector-ref rv 1))
      (define uw (vector-ref rv 5))
      (define (write-units w)
        (define cid (car w))
        (define cn (cell-id-n cid))
        (define old (with-handlers ([exn:fail? (λ (e) 'absent)]) (net-cell-read-raw snap cid)))
        (define d (if (eq? old 'absent) #f (pu-value-diff old (cdr w))))
        ;; ESTIMATE input: the cost of one full pu-value-diff of this (old,new) pair (min of 5), which an in-fire
        ;; net-cell-write on a component-watched cell pays per write (propagator.rkt:2042-2072)
        (define dms
          (if (or (eq? old 'absent) (not (hash? old))) 0.0
              (for/fold ([m +inf.0]) ([_ (in-range 5)])
                (define a (current-inexact-monotonic-milliseconds))
                (pu-value-diff old (cdr w))
                (min m (- (current-inexact-monotonic-milliseconds) a)))))
        (hasheq 'cell (cell-facts snap cid)
                'diff_ms dms
                'map_size (if (hash? (cdr w)) (hash-count (cdr w)) -1)
                'units (if (and (list? d) (pair? d)) (for/list ([q (in-list d)]) (path->unit cn q)) (list (cell-unit cn)))))
      (define ins
        (if (eq? p 'none) '()
            (for/list ([c (in-list (propagator-inputs p))])
              (define cell (champ-lookup (prop-network-cells snap) (cell-id-hash c) c))
              (define e (if (eq? cell 'none) 'none (champ-lookup (prop-cell-dependents cell) (prop-id-hash pid) pid)))
              (define paths (and (dependent-entry? e) (dependent-entry-paths e)))
              (hasheq 'n (cell-id-n c)
                      'units (if (and (list? paths) (pair? paths))
                                 (for/list ([q (in-list paths)]) (path->unit (cell-id-n c) q))
                                 (list (cell-unit (cell-id-n c))))))))
      (set! recs
            (cons (hasheq 'pid (prop-id-n pid)
                          'npid (prop-network-next-prop-id snap)
                          'ncid (prop-network-next-cell-id snap)
                          'tuc (let ([c (current-type-meta-universe-cell-id)]) (if c (cell-id-n c) #f))
                          'idx idx
                          'depth depth
                          'ms (- t1 t0)
                          'fire_once (and (not (eq? p 'none)) (not (zero? (bitwise-and (propagator-flags p) PROP-FIRE-ONCE))))
                          'outs (if (eq? p 'none) '() (for/list ([c (in-list (propagator-outputs p))]) (cell-facts snap c)))
                          'ins ins
                          'writes (for/list ([w (in-list vw)]) (write-units w))
                          'undeclared (for/list ([w (in-list uw)]) (write-units w))
                          'new_cells (length (vector-ref rv 2))
                          'new_props (length (vector-ref rv 3))
                          'contradiction (and (vector-ref rv 4) #t))
                  recs))
      r))
  (set! pending (cons (cons my-call (reverse recs)) pending))
  (set! depth (sub1 depth))
  results)

(define (observe r)
  (define rn (bsp-round-round-number r))
  (when (null? pending) (error 'observe "observer without pending executor record"))
  (define top (car pending))
  (set! pending (cdr pending))
  (when (zero? rn) (set! run-id (add1 run-id)))
  (for ([f (in-list (cdr top))])
    (set! fires (cons (hash-set* f 'run run-id 'round rn 'call (car top)) fires))))

(collect-garbage)
(define tA0 (current-inexact-monotonic-milliseconds))
(parameterize ([current-parallel-executor analysis-exec]
               [current-bsp-observer observe])
  (run-file* the-file))
(define wallA (- (current-inexact-monotonic-milliseconds) tA0))
(define unobserved (for/sum ([p pending]) (length (cdr p))))
(define seqA* (reverse seqA))

;; ---------------- timing reps ----------------
(define (timing-rep)
  (define ts '()) (define gcs '()) (define seq '())
  (define (timing-exec snap pids)
    (for/list ([pid (in-list pids)] [idx (in-naturals 1)])
      (define g0 (current-gc-milliseconds))
      (define t0 (current-inexact-monotonic-milliseconds))
      (define r (fire-and-collect-writes snap pid idx))
      (define t1 (current-inexact-monotonic-milliseconds))
      (define g1 (current-gc-milliseconds))
      (set! ts (cons (- t1 t0) ts)) (set! gcs (cons (- g1 g0) gcs)) (set! seq (cons (prop-id-n pid) seq))
      r))
  (collect-garbage)
  (define t0 (current-inexact-monotonic-milliseconds))
  (define gc0 (current-gc-milliseconds))
  (parameterize ([current-parallel-executor timing-exec])
    (run-file* the-file))
  (list (- (current-inexact-monotonic-milliseconds) t0) (- (current-gc-milliseconds) gc0)
        (reverse ts) (reverse gcs) (reverse seq)))
(define reps (for/list ([i (in-range TREPS)]) (timing-rep)))

(define out
  (hasheq 'file the-file
          'timing_reps TREPS
          'wall_ms_A wallA
          'unobserved_fires unobserved
          'raised (or raised #f)
          'rep_wall_ms (map first reps)
          'rep_gc_ms (map second reps)
          'rep_seq_match (for/list ([r reps]) (equal? (fifth r) seqA*))
          'rep_ms (map third reps)
          'rep_gc_fire (map fourth reps)
          'fires (reverse fires)))
(call-with-output-file out-path #:exists 'replace (λ (o) (write-json out o)))
(printf "W2-1 ~a: fires ~a runs ~a unobserved ~a wallA ~a reps-wall ~a seq-match ~a\n"
        the-file (length fires) (add1 run-id) unobserved (round wallA)
        (map (λ (r) (round (first r))) reps) (for/list ([r reps]) (equal? (fifth r) seqA*)))
