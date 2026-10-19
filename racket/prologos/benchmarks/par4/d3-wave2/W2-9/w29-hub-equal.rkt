#lang racket/base
;;; C10 probe (PAR 4 D.3 wave 1, critic C10 value & scope). Read-only on the repo.
;;; ONE .prologos file per process:  racket hub-probe.rkt FILE.prologos
;;; Measures, under today's BSP (the production scheduler), with the BSP observer:
;;;  (1) load balance of D.2 §6.7's ownership rule (home = owner of first declared output,
;;;      round-robin by cell id, K = 8): fires per executor, busiest executor's share;
;;;  (2) the hub: which cell receives most writes, its merge, share of fires whose outputs include it;
;;;  (3) attribute-map writes: map size N (positions) vs changed positions per round-level write;
;;;  (4) pu-value-diff cost on the REAL captured (old,new) pairs vs a delta-keyed diff
;;;      (only the positions the merge touched) and vs the merge of the delta itself;
;;;  (5) quiescence write/change counters (all net-cell-write attempts / changes, in-fire + bulk).
;;; W2-9 copy (adapted from d3-wave1/C10/hub-probe.rkt, unchanged otherwise): adds the cost of the CHANGE CHECK
;;; net-cell-write performs on every write, (or (eq? merged old) (equal? merged old)) at propagator.rkt:2029, on the
;;; real merged maps: merged = attribute-map-merge-fn(old, delta). DIRECT keeps this check; a keyed check compares
;;; only the delta's keys.
(require racket/list racket/math racket/port json
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt")
                  process-file current-use-pnet-cache? current-pnet-write-enabled?)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
                  current-bsp-observer
                  bsp-round-network-snapshot bsp-round-propagators-fired bsp-round-cell-diffs
                  cell-diff-cell-id cell-diff-new-value cell-diff-old-value
                  prop-network-merge-fns prop-network-propagators prop-network-cells
                  propagator-outputs propagator-inputs prop-cell-value
                  cell-id-hash prop-id-hash cell-id-n
                  pu-value-diff
                  current-quiescence-write-counter current-quiescence-change-counter)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/champ.rkt")
                  champ-lookup)
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/typing-propagators.rkt")
                  attribute-map-merge-fn))

(define file (vector-ref (current-command-line-arguments) 0))
(define preload "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/benchmarks/par4/preload-empty.prologos")
(define (run-file* f)
  (parameterize ([current-output-port (open-output-nowhere)]
                 [current-use-pnet-cache? #t]
                 [current-pnet-write-enabled? #f])   ; never write the shared cache
    (process-file f)))
(run-file* preload)

(define K 8)
(define (owner c) (modulo (cell-id-n c) K))
(define (fn-name f) (let ([n (and (procedure? f) (object-name f))]) (if n (symbol->string n) "anon")))
(define (merge-fn-of snap cid)
  (define mf (champ-lookup (prop-network-merge-fns snap) (cell-id-hash cid) cid))
  (if (eq? mf 'none) "none" (fn-name mf)))
(define (inc! h k [d 1]) (hash-set! h k (+ d (hash-ref h k 0))))

(define fires-per-exec (make-vector K 0))
(define fires-total 0)
(define fires-by-first-out (make-hash))   ; cell-n -> fires
(define fires-touching (make-hash))       ; cell-n -> fires whose outputs include it
(define writes-by-cell (make-hash))       ; cell-n -> round-level writes
(define merge-of-cell (make-hash))
(define am-sizes '())                     ; N per attribute-map round-level write
(define am-changed '())                   ; changed paths per write
(define pairs '())                        ; captured (old . new) attribute-map pairs
(define max-pairs 600)

(define (observe r)
  (define snap (bsp-round-network-snapshot r))
  (define props (prop-network-propagators snap))
  (for ([pid (in-list (bsp-round-propagators-fired r))])
    (define p (champ-lookup props (prop-id-hash pid) pid))
    (unless (eq? p 'none)
      (define outs (propagator-outputs p)) (define ins (propagator-inputs p))
      (define home (cond [(pair? outs) (owner (car outs))] [(pair? ins) (owner (car ins))] [else 0]))
      (vector-set! fires-per-exec home (add1 (vector-ref fires-per-exec home)))
      (set! fires-total (add1 fires-total))
      (when (pair? outs) (inc! fires-by-first-out (cell-id-n (car outs))))
      (for ([c (remove-duplicates (map cell-id-n outs))]) (inc! fires-touching c))))
  (for ([d (in-list (bsp-round-cell-diffs r))])
    (define cid (cell-diff-cell-id d))
    (define mname (merge-fn-of snap cid))
    (inc! writes-by-cell (cell-id-n cid))
    (hash-set! merge-of-cell (cell-id-n cid) mname)
    (when (equal? mname "attribute-map-merge-fn")
      ;; cell-diff-old-value = the round's pre-fire snapshot value (propagator.rkt observer block);
      ;; bsp-round-network-snapshot is the POST-round network, so it must not be used as `old`.
      (define old (cell-diff-old-value d))
      (define new (cell-diff-new-value d))
      (when (and (hash? old) (hash? new))
        (set! am-sizes (cons (hash-count new) am-sizes))
        (define ch (pu-value-diff old new))
        (set! am-changed (cons (if ch (length ch) -1) am-changed))
        (when (< (length pairs) max-pairs) (set! pairs (cons (cons old new) pairs)))))))

(define wc (box 0)) (define cc (box 0))
(define t0 (current-inexact-monotonic-milliseconds))
(parameterize ([current-bsp-observer observe]
               [current-quiescence-write-counter wc]
               [current-quiescence-change-counter cc])
  (run-file* file))
(define run-ms (- (current-inexact-monotonic-milliseconds) t0))

;; ---- timing on captured real pairs (outside the run) ----
;; delta keys = positions whose record is not eq? in new vs old (what a pointwise merge touches)
(define (delta-keys old new)
  (for/list ([(k v) (in-hash new)] #:unless (eq? v (hash-ref old k 'c10-absent))) k))
(define prepared
  (for/list ([p (in-list pairs)])
    (define old (car p)) (define new (cdr p))
    (define ks (delta-keys old new))
    (define delta (for/hasheq ([k ks]) (values k (hash-ref new k))))
    (vector old new ks delta)))
;; delta-keyed diff: same output shape as pu-value-diff, examining only delta's keys
(define (keyed-diff old new ks)
  (for/fold ([changed '()]) ([k (in-list ks)])
    (define v (hash-ref new k))
    (define old-v (hash-ref old k 'pu-diff-absent))
    (cond
      [(or (eq? v old-v) (equal? v old-v)) changed]
      [(and (hash? v) (hash? old-v))
       (define c1 (for/fold ([c changed]) ([(fk fv) (in-hash v)])
                    (define ofv (hash-ref old-v fk 'pu-diff-absent))
                    (if (or (eq? fv ofv) (equal? fv ofv)) c (cons (cons k fk) c))))
       (for/fold ([c c1]) ([(fk _) (in-hash old-v)]) (if (hash-has-key? v fk) c (cons (cons k fk) c)))]
      [(hash? v) (for/fold ([c changed]) ([(fk _) (in-hash v)]) (cons (cons k fk) c))]
      [else (cons k changed)])))
;; equivalence check (power: must agree as sets on every captured pair)
(define (canon l) (sort (map (λ (x) (format "~s" x)) (or l '())) string<?))
(define mismatches
  (for/sum ([v (in-list prepared)])
    (if (equal? (canon (pu-value-diff (vector-ref v 0) (vector-ref v 1)))
                (canon (keyed-diff (vector-ref v 0) (vector-ref v 1) (vector-ref v 2))))
        0 1)))
;; first mismatch, for diagnosis
(define first-mismatch
  (for/first ([v (in-list prepared)]
              #:unless (equal? (canon (pu-value-diff (vector-ref v 0) (vector-ref v 1)))
                               (canon (keyed-diff (vector-ref v 0) (vector-ref v 1) (vector-ref v 2)))))
    (list (format "full=~s" (pu-value-diff (vector-ref v 0) (vector-ref v 1)))
          (format "keyed=~s" (keyed-diff (vector-ref v 0) (vector-ref v 1) (vector-ref v 2)))
          (format "old-count=~a new-count=~a ks=~s" (hash-count (vector-ref v 0)) (hash-count (vector-ref v 1)) (vector-ref v 2)))))
;; power check of the comparison itself: a deliberately wrong keyed diff (drop the first key) must mismatch
(define power-mismatches
  (for/sum ([v (in-list prepared)] #:when (pair? (vector-ref v 2)))
    (if (equal? (canon (pu-value-diff (vector-ref v 0) (vector-ref v 1)))
                (canon (keyed-diff (vector-ref v 0) (vector-ref v 1) (cdr (vector-ref v 2)))))
        0 1)))
(define REPS 200)
(define (time-ns thunk)
  (collect-garbage 'minor)
  (define t (current-inexact-monotonic-milliseconds))
  (for ([_ (in-range REPS)]) (thunk))
  (/ (* 1e6 (- (current-inexact-monotonic-milliseconds) t)) REPS (max 1 (length prepared))))
(define full-ns (time-ns (λ () (for ([v (in-list prepared)]) (pu-value-diff (vector-ref v 0) (vector-ref v 1))))))
(define keyed-ns (time-ns (λ () (for ([v (in-list prepared)]) (keyed-diff (vector-ref v 0) (vector-ref v 1) (vector-ref v 2))))))
(define merge-delta-ns (time-ns (λ () (for ([v (in-list prepared)]) (attribute-map-merge-fn (vector-ref v 0) (vector-ref v 3))))))
(define merged-list (for/list ([v (in-list prepared)]) (attribute-map-merge-fn (vector-ref v 0) (vector-ref v 3))))
(define equal-check-ns (time-ns (λ () (for ([v (in-list prepared)] [m (in-list merged-list)]) (or (eq? m (vector-ref v 0)) (equal? m (vector-ref v 0)))))))
(define keyed-check-ns (time-ns (λ () (for ([v (in-list prepared)] [m (in-list merged-list)])
                                         (for/or ([k (in-list (vector-ref v 2))]) (not (equal? (hash-ref m k #f) (hash-ref (vector-ref v 0) k #f))))))))
(define check-agree (for/sum ([v (in-list prepared)] [m (in-list merged-list)])
                      (if (eq? (not (equal? m (vector-ref v 0)))
                               (for/or ([k (in-list (vector-ref v 2))]) (not (equal? (hash-ref m k #f) (hash-ref (vector-ref v 0) k #f)))))
                           1 0)))
(define merge-full-ns (time-ns (λ () (for ([v (in-list prepared)]) (attribute-map-merge-fn (vector-ref v 0) (vector-ref v 1))))))

(define (top h n) (take (sort (hash->list h) > #:key cdr) (min n (hash-count h))))
(define (pctl xs p) (if (null? xs) 0 (let ([s (sort xs <)]) (list-ref s (min (sub1 (length s)) (exact-floor (* p (length s))))))))
(define (r3 x) (/ (round (* 1000 (exact->inexact x))) 1000.0))
(define busiest (apply max (vector->list fires-per-exec)))
(printf "C10:~a\n"
  (jsexpr->string
   (hasheq 'file file 'run_ms (r3 run-ms)
           'fires fires-total
           'fires_per_exec_K8_rr (vector->list fires-per-exec)
           'busiest_exec_share (r3 (/ busiest (max 1 fires-total)))
           'parallelism_bound_K8 (r3 (/ fires-total (max 1 busiest)))
           'top_first_out_cells (for/list ([p (top fires-by-first-out 4)]) (list (car p) (cdr p) (hash-ref merge-of-cell (car p) "?")))
           'top_fires_touching (for/list ([p (top fires-touching 4)]) (list (car p) (cdr p) (r3 (/ (cdr p) (max 1 fires-total))) (hash-ref merge-of-cell (car p) "?")))
           'round_writes_top_cells (for/list ([p (top writes-by-cell 4)]) (list (car p) (cdr p) (hash-ref merge-of-cell (car p) "?")))
           'round_writes_total (apply + (hash-values writes-by-cell))
           'am_writes (length am-sizes)
           'am_N_p50 (pctl am-sizes 0.5) 'am_N_p90 (pctl am-sizes 0.9) 'am_N_max (if (null? am-sizes) 0 (apply max am-sizes))
           'am_changed_paths_p50 (pctl am-changed 0.5) 'am_changed_paths_p90 (pctl am-changed 0.9)
           'quiescence_write_attempts (unbox wc) 'quiescence_changes (unbox cc)
           'pairs_timed (length prepared)
           'keyed_vs_full_mismatches mismatches 'first_mismatch (or first-mismatch "none")
           'power_wrong_keyed_mismatches power-mismatches
           'ns_per_call_pu_value_diff_full (r3 full-ns)
           'ns_per_call_keyed_diff (r3 keyed-ns)
           'ns_per_call_merge_delta (r3 merge-delta-ns)
           'ns_per_call_merge_fullmap (r3 merge-full-ns)
           'ns_per_call_change_check_equal (r3 equal-check-ns)
           'ns_per_call_change_check_keyed (r3 keyed-check-ns)
           'change_check_keyed_agrees_with_equal (list check-agree (length prepared)))))
