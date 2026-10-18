#lang racket/base
;;; W2-8 probe 1 (PAR 4 D.3 wave 2, defender of K > 1). Adapted from C10's hub-probe.rkt and C7's placement.rkt.
;;; Read-only on the repo. ONE .prologos file per process:  racket w28-share.rkt FILE.prologos
;;;
;;; Thread executor OFF: BSP's fire executor is a TIMING SEQUENTIAL executor (same calls as
;;; sequential-fire-all: fire-and-collect-writes snap pid idx, idx from 1), injected through
;;; current-parallel-executor (propagator.rkt:3675).  Per fire it records wall time (dt) and
;;; allocated bytes ((current-memory-use 'cumulative) delta).
;;;
;;; Free parameters:
;;;   K ∈ {4, 8, 16}  executors.
;;;   MIN = 8         a round narrower than MIN runs on one executor in the BSP-K rows
;;;                   (the production thread executor's threshold, propagator.rkt:3691).
;;; Home rules (who runs a fire):
;;;   cell : D.2 §6.7 — owner of the first declared output cell, round-robin by cell id (mod K).
;;;   comp : owner of the first COMPONENT the fire writes (cell, position, facet) for hash-valued
;;;          cells (keys of the delta: positions / facets not eq? to the snapshot's), else the cell;
;;;          an unproductive fire is homed on its first declared input component path, else on its
;;;          first output cell.  Owner = equal-hash-code(component) mod K.
;;;   pid  : POWER ROW — round-robin by propagator id (prop-id-n mod K).
;;;   lpt  : dynamic placement (greedy longest-processing-time per round) — what a shared work
;;;          queue achieves; an upper bound for any static home rule.
;;; Metrics:
;;;   busiest share  = max over executors of (that executor's total) / (run total), by count and time.
;;;   eff. parallelism per round = Σ_r W_r / Σ_r max_e W_{r,e}  (W = count, or time).
;;;   BSP-K model    = Σ_r T_r / Σ_r span_r, span_r = T_r if width < MIN else max_e T_{r,e};
;;;                    S0 model = (F + M) / (F_par + M) with the merge phase M kept serial.
(require racket/list racket/port racket/math json racket/string
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/driver.rkt")
                  process-file current-use-pnet-cache? current-pnet-write-enabled?)
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/champ.rkt")
                  champ-lookup)
         (file "/Users/avanti/.hermes/profiles/logos-language-designer/cache/scratch/d3w2/W2-8/w28-micro.rkt"))

(define ROOT "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/")
(define file (vector-ref (current-command-line-arguments) 0))
(define (run-file* f)
  (parameterize ([current-output-port (open-output-nowhere)]
                 [current-error-port (open-output-nowhere)]
                 [current-use-pnet-cache? #t]
                 [current-pnet-write-enabled? #f])
    (process-file f)))
(void (run-file* (string-append ROOT "benchmarks/par4/preload-empty.prologos")))

(define Ks '(4 8 16))
(define MIN 8)

;; ---- the timing sequential executor ----
(define round-recs '())   ; list of (cons snap (list (vector pid dt bytes result)))
(define (timing-exec snap pids)
  (define recs
    (for/list ([pid (in-list pids)] [idx (in-naturals 1)])
      (define b0 (current-memory-use 'cumulative))
      (define t0 (current-inexact-monotonic-milliseconds))
      (define r (fire-and-collect-writes snap pid idx))
      (define t1 (current-inexact-monotonic-milliseconds))
      (define b1 (current-memory-use 'cumulative))
      (vector pid (- t1 t0) (- b1 b0) r)))
  (set! round-recs (cons (cons snap recs) round-recs))
  (for/list ([v (in-list recs)]) (vector-ref v 3)))

(define stats (box '()))
(define obs-rounds '())   ; round-number per BSP round, in order (observer runs after the executor)
(define (observe r) (set! obs-rounds (cons (bsp-round-round-number r) obs-rounds)))
(collect-garbage)
(define t-start (current-inexact-monotonic-milliseconds))
(parameterize ([current-parallel-executor timing-exec]
               [current-bsp-round-stats stats]
               [current-bsp-observer observe])
  (if (regexp-match? #rx"^micro:" file)
      (let-values ([(net _) (build-micro (substring file 6))]) (void (run-to-quiescence net)))
      (void (run-file* file))))
(define run-ms (- (current-inexact-monotonic-milliseconds) t-start))
(define rounds (reverse round-recs))
(define merge-ms (for/sum ([s (in-list (unbox stats))]) (caddr s)))

;; ---- optional ESTIMATE (W28_EST=1): subtract the in-fire whole-map protocol cost that P2-lite removes ----
;; Per productive fire, for each value write (cid . new) whose old and new values are hashes:
;;   2 x equal?(old,new)  [fire-and-collect-writes :2902 value-writes compare + champ-diff same? :2924]
;;   + pu-value-diff(old,new) if the cell's merge is attribute-map-merge-fn [net-cell-write slow path :2073]
;; timed AFTER the run on the captured values (warm caches => an UNDER-estimate of the in-situ cost, so the
;; residual work is over-estimated: conservative for any parallelism derived from it).
(define EST? (equal? (getenv "W28_EST") "1"))
(define protocol-subtracted 0.0)
(define (time-ms thunk)
  (thunk)
  (define t0 (current-inexact-monotonic-milliseconds))
  (for ([_ (in-range 10)]) (thunk))
  (/ (- (current-inexact-monotonic-milliseconds) t0) 10.0))
(define (merge-name0 snap cid)
  (define mf (champ-lookup (prop-network-merge-fns snap) (cell-id-hash cid) cid))
  (if (and (procedure? mf) (object-name mf)) (format "~a" (object-name mf)) "anon"))
(when EST?
  (for* ([rr (in-list rounds)] [v (in-list (cdr rr))])
    (define snap (car rr))
    (define r (vector-ref v 3))
    (define ws (cond [(list? r) r] [else (let ([x (struct->vector r)]) (if (eq? (vector-ref x 0) 'struct:fire-result) (vector-ref x 1) '()))]))
    (define c
      (for/sum ([w (in-list ws)])
        (define old (net-cell-read-raw snap (car w))) (define new (cdr w))
        (if (and (hash? old) (hash? new))
            (+ (* 2 (time-ms (λ () (equal? old new))))
               (if (equal? (merge-name0 snap (car w)) "attribute-map-merge-fn") (time-ms (λ () (pu-value-diff old new))) 0.0))
            0.0)))
    (define dt (vector-ref v 1))
    (define dt* (max (min dt 0.0002) (- dt c)))   ; floor 0.2 us
    (set! protocol-subtracted (+ protocol-subtracted (- dt dt*)))
    (vector-set! v 1 dt*)))
;; ---- per-fire classification ----
(define (fn-name f) (let ([n (and (procedure? f) (object-name f))]) (if n (format "~a" n) "anon")))
(define (merge-name snap cid)
  (define mf (champ-lookup (prop-network-merge-fns snap) (cell-id-hash cid) cid))
  (if (eq? mf 'none) "none" (fn-name mf)))
(define (key<? a b) (< (equal-hash-code a) (equal-hash-code b)))
;; components written by one value write (cid . new) against the snapshot
(define (written-components snap cid new)
  (define old (net-cell-read-raw snap cid))
  (cond
    [(and (hash? old) (hash? new))
     (define poss (sort (for/list ([(k v) (in-hash new)] #:unless (eq? v (hash-ref old k 'w28-absent))) k) key<?))
     (apply append
            (for/list ([p (in-list poss)])
              (define nv (hash-ref new p)) (define ov (hash-ref old p 'w28-absent))
              (if (and (hash? nv) (hash? ov))
                  (let ([fs (sort (for/list ([(f v) (in-hash nv)] #:unless (eq? v (hash-ref ov f 'w28-absent))) f) key<?)])
                    (if (null? fs) (list (list (cell-id-n cid) p '*)) (for/list ([f fs]) (list (cell-id-n cid) p f))))
                  (list (list (cell-id-n cid) p '*)))))]
    [else (list (list (cell-id-n cid)))]))
(define (declared-input-path snap pid prop)
  (for/or ([cid (in-list (propagator-inputs prop))])
    (define cell (champ-lookup (prop-network-cells snap) (cell-id-hash cid) cid))
    (and (not (eq? cell 'none))
         (let ([e (champ-lookup (prop-cell-dependents cell) (prop-id-hash pid) pid)])
           (and (dependent-entry? e)
                (let ([ps (dependent-entry-paths e)])
                  (and (list? ps)
                       (for/or ([p (in-list ps)])
                         (and p (let ([q (if (and (pair? p) (cell-id? (car p))) (cdr p) p)])
                                  (if (pair? q) (list (cell-id-n cid) (car q) (cdr q)) (list (cell-id-n cid) q))))))))))))

;; fire-result is not exported, but it is #:transparent (propagator.rkt:2874): field 1 = value-writes
(define (fr-writes r)
  (cond [(list? r) r]
        [else (define v (struct->vector r))
              (if (eq? (vector-ref v 0) 'struct:fire-result) (vector-ref v 1) '())]))
;; fire rows: (vector round dt bytes cell-owner-n comp-key pid-n type? hub? productive?)
(define hub-writes (make-hash))  ; cell-n -> productive-write count, to identify the hub
(define fire-rows
  (for*/list ([(rr ri) (in-parallel rounds (in-naturals))]
              [snap (in-value (car rr))]
              [v (in-list (cdr rr))])
    (define pid (vector-ref v 0))
    (define prop (champ-lookup (prop-network-propagators snap) (prop-id-hash pid) pid))
    (define outs (if (eq? prop 'none) '() (propagator-outputs prop)))
    (define ins (if (eq? prop 'none) '() (propagator-inputs prop)))
    (define res (vector-ref v 3))
    (define writes (fr-writes res))
    ;; first written output in declared order
    (define first-w (for/or ([c (in-list outs)]) (assoc c writes)))
    (define comps (if first-w (written-components snap (car first-w) (cdr first-w)) '()))
    (define all-comps (apply append (for/list ([w (in-list writes)]) (written-components snap (car w) (cdr w)))))
    (for ([w (in-list writes)]) (hash-update! hub-writes (cell-id-n (car w)) add1 0))
    (define comp-key
      (cond [(pair? comps) (car comps)]
            [(and (not (eq? prop 'none)) (declared-input-path snap pid prop)) => values]
            [(pair? outs) (list (cell-id-n (car outs)))]
            [(pair? ins) (list (cell-id-n (car ins)))]
            [else (list -1)]))
    (define type?
      (or (for/or ([c (in-list all-comps)]) (and (= (length c) 3) (eq? (caddr c) ':type)))
          (for/or ([w (in-list writes)]) (regexp-match? #rx"type" (merge-name snap (car w))))))
    (vector ri (vector-ref v 1) (vector-ref v 2)
            (cond [(pair? outs) (cell-id-n (car outs))] [(pair? ins) (cell-id-n (car ins))] [else 0])
            comp-key
            (if (eq? prop 'none) 0 (prop-id-n pid))
            type?
            (pair? writes)
            (if (pair? outs) (cell-id-n (car outs)) -1))))

(define n-fires (length fire-rows))
(define F (for/sum ([r (in-list fire-rows)]) (vector-ref r 1)))
(define B (for/sum ([r (in-list fire-rows)]) (vector-ref r 2)))
(define hub-cell (if (zero? (hash-count hub-writes)) -1 (car (argmax cdr (hash->list hub-writes)))))
(define hub-first (filter (λ (r) (= (vector-ref r 8) hub-cell)) fire-rows))
(define type-rows (filter (λ (r) (vector-ref r 6)) fire-rows))

(define (owner rule K r)
  (case rule
    [(cell) (modulo (vector-ref r 3) K)]
    [(comp) (modulo (equal-hash-code (vector-ref r 4)) K)]
    [(pid) (modulo (vector-ref r 5) K)]))
(define by-round (for/fold ([h (hasheqv)]) ([r (in-list fire-rows)]) (hash-update h (vector-ref r 0) (λ (l) (cons r l)) '())))
(define (lpt-span K ts)
  (define loads (make-vector K 0.0))
  (for ([t (in-list (sort ts >))])
    (define i (for/fold ([best 0]) ([j (in-range 1 K)]) (if (< (vector-ref loads j) (vector-ref loads best)) j best)))
    (vector-set! loads i (+ t (vector-ref loads i))))
  (for/fold ([m 0.0]) ([x (in-vector loads)]) (max m x)))
(define (metrics rule K)
  (define cnt (make-vector K 0)) (define tim (make-vector K 0.0))
  (for ([r (in-list fire-rows)] #:unless (eq? rule 'lpt))
    (define o (owner rule K r))
    (vector-set! cnt o (add1 (vector-ref cnt o))) (vector-set! tim o (+ (vector-ref r 1) (vector-ref tim o))))
  (define-values (sw sc st sT sbsp)
    (for/fold ([sw 0] [sc 0] [st 0.0] [sT 0.0] [sbsp 0.0]) ([(ri rs) (in-hash by-round)])
      (define w (length rs)) (define T (for/sum ([r rs]) (vector-ref r 1)))
      (define-values (mc mt)
        (if (eq? rule 'lpt)
            (values (ceiling (/ w K)) (lpt-span K (map (λ (r) (vector-ref r 1)) rs)))
            (let ([c (make-hasheqv)] [t (make-hasheqv)])
              (for ([r rs]) (define o (owner rule K r))
                (hash-update! c o add1 0) (hash-update! t o (λ (x) (+ x (vector-ref r 1))) 0.0))
              (values (apply max (hash-values c)) (apply max (hash-values t))))))
      (values (+ sw w) (+ sc mc) (+ st mt) (+ sT T) (+ sbsp (if (< w MIN) T mt)))))
  (define (r3 x) (/ (round (* 1000 (exact->inexact x))) 1000.0))
  (hasheq 'rule (symbol->string rule) 'K K
          'busiest_share_count (if (eq? rule 'lpt) 'null (r3 (/ (apply max (vector->list cnt)) (max 1 n-fires))))
          'busiest_share_time (if (eq? rule 'lpt) 'null (r3 (/ (apply max (vector->list tim)) (max 1e-9 F))))
          'effpar_count (r3 (/ sw (max 1 sc)))
          'effpar_time (r3 (/ sT (max 1e-9 st)))
          'bspk_fire_speedup (r3 (/ sT (max 1e-9 sbsp)))
          'bspk_s0_speedup (r3 (/ (+ sT merge-ms) (max 1e-9 (+ sbsp merge-ms))))))

(define (r3 x) (/ (round (* 1000 (exact->inexact x))) 1000.0))
;; ---- dependency DAG over BSP rounds (estimate of DIRECT's critical path) ----
(define rnums (list->vector (reverse obs-rounds)))
(unless (= (vector-length rnums) (length rounds)) (error 'w28 "observer/executor round mismatch ~a ~a" (vector-length rnums) (length rounds)))
;; per fire: written components (all) and read spec
(define (read-spec snap pid prop)
  ;; list of (cid-n . paths) ; paths = #f means whole cell
  (for/list ([cid (in-list (propagator-inputs prop))])
    (define cell (champ-lookup (prop-network-cells snap) (cell-id-hash cid) cid))
    (define e (and (not (eq? cell 'none)) (champ-lookup (prop-cell-dependents cell) (prop-id-hash pid) pid)))
    (define ps (and (dependent-entry? e) (dependent-entry-paths e)))
    (cons (cell-id-n cid)
          (and (list? ps) (pair? (filter values ps))
               (for/list ([p (in-list ps)] #:when p)
                 (if (and (pair? p) (cell-id? (car p))) (cdr p) p))))))
(define (reads? spec comp)
  ;; comp = (cid) | (cid pos facet)
  (for/or ([s (in-list spec)])
    (and (= (car s) (car comp))
         (or (not (cdr s)) (null? (cdr comp))
             (for/or ([p (in-list (cdr s))])
               (define ppos (if (pair? p) (car p) p))
               (define pfac (if (pair? p) (cdr p) '*))
               (and (equal? ppos (cadr comp))
                    (or (eq? pfac '*) (eq? (caddr comp) '*) (equal? pfac (caddr comp)))))))))
(define round-fires   ; vector of lists of (vector dt comps spec)
  (for/vector ([rr (in-list rounds)])
    (define snap (car rr))
    (for/list ([v (in-list (cdr rr))])
      (define pid (vector-ref v 0))
      (define prop (champ-lookup (prop-network-propagators snap) (prop-id-hash pid) pid))
      (define writes (fr-writes (vector-ref v 3)))
      (vector (vector-ref v 1)
              (apply append (for/list ([w (in-list writes)]) (written-components snap (car w) (cdr w))))
              (if (eq? prop 'none) '() (read-spec snap pid prop))))))
(define-values (segT segCPc segCPo fallbacks edges)
  (let loop ([i 0] [prev #f] [prev-fin #f] [curT 0.0] [cpc 0.0] [cpo 0.0] [Ts '()] [CPc '()] [CPo '()] [fb 0] [ed 0])
    (cond
      [(= i (vector-length round-fires))
       (values (reverse (cons curT Ts)) (reverse (cons cpc CPc)) (reverse (cons cpo CPo)) fb ed)]
      [else
       (define rn (vector-ref rnums i))
       (define fs (vector-ref round-fires i))
       (define new-seg? (or (zero? rn) (not prev)))
       (define-values (Ts* CPc* CPo* curT0 cpc0 cpo0)
         (if (and new-seg? prev) (values (cons curT Ts) (cons cpc CPc) (cons cpo CPo) 0.0 0.0 0.0)
             (values Ts CPc CPo curT cpc cpo)))
       (define prev-max-c (if (or new-seg? (not prev-fin)) 0.0 (for/fold ([m 0.0]) ([x (in-list prev-fin)]) (max m (car x)))))
       (define-values (fins fb* ed*)
         (for/fold ([acc '()] [fb fb] [ed ed]) ([f (in-list fs)])
           (define dt (vector-ref f 0))
           (cond
             [new-seg? (values (cons (cons dt dt) acc) fb ed)]
             [else
              (define preds (for/list ([pf (in-list prev-fin)] [g (in-list prev)]
                                       #:when (for/or ([c (in-list (vector-ref g 1))]) (reads? (vector-ref f 2) c)))
                              pf))
              (if (null? preds)
                  (values (cons (cons (+ dt prev-max-c) dt) acc) (add1 fb) ed)
                  (values (cons (cons (+ dt (apply max (map car preds))) (+ dt (apply max (map cdr preds)))) acc)
                          fb (+ ed (length preds))))])))
       (define fins* (reverse fins))
       (loop (add1 i) fs fins* (+ curT0 (for/sum ([f fs]) (vector-ref f 0)))
             (max cpc0 (for/fold ([m 0.0]) ([x fins*]) (max m (car x))))
             (max cpo0 (for/fold ([m 0.0]) ([x fins*]) (max m (cdr x))))
             Ts* CPc* CPo* fb* ed*)])))
(define (direct-bound K cps)
  (/ (apply + segT) (max 1e-9 (for/sum ([T segT] [cp cps]) (max cp (/ T K))))))
;; fire-time distribution
(define dts (sort (map (λ (r) (vector-ref r 1)) fire-rows) >))
(define (topshare frac) (/ (apply + (take dts (max 1 (exact-ceiling (* frac (length dts)))))) (max 1e-9 F)))
(define (pct p) (if (null? dts) 0 (list-ref (reverse dts) (min (sub1 (length dts)) (exact-floor (* p (length dts)))))))
(printf "W28DAG:~a\n"
  (jsexpr->string
   (hasheq 'file (let-values ([(b n d) (split-path file)]) (path->string n))
           'est (if EST? "p2lite-residual" "as-is") 'protocol_subtracted_ms (r3 protocol-subtracted)
           'lpt_bspk_fire (for/list ([K Ks]) (list K (hash-ref (metrics 'lpt K) 'bspk_fire_speedup)))
           'comp_effpar_time (for/list ([K Ks]) (list K (hash-ref (metrics 'comp K) 'effpar_time)))
           'cell_effpar_time (for/list ([K Ks]) (list K (hash-ref (metrics 'cell K) 'effpar_time)))
           'fires n-fires 'fire_ms (r3 F) 'merge_ms (r3 merge-ms)
           'segments (length segT) 'pred_fallbacks fallbacks 'edges edges
           'cp_conservative_ms (r3 (apply + segCPc)) 'cp_optimistic_ms (r3 (apply + segCPo))
           'bsp_round_span_ms (r3 (for/sum ([(ri rs) (in-hash by-round)]) (apply max (map (λ (r) (vector-ref r 1)) rs))))
           'direct_bound_cons (for/list ([K Ks]) (list K (r3 (direct-bound K segCPc))))
           'direct_bound_opt (for/list ([K Ks]) (list K (r3 (direct-bound K segCPo))))
           ;; ESTIMATE: all S0 runs (segments) of the file in ONE run, segments mutually independent (an upper bound:
           ;; a later top-level command may need an earlier one's inferred type)
           'batched_independent_bound (for/list ([K Ks]) (list K (r3 (/ (apply + segT) (max 1e-9 (max (apply max (cons 0.0 segCPc)) (/ (apply + segT) K)))))))
           'segment_T_max_ms (r3 (apply max (cons 0.0 segT))) 'segment_CP_max_ms (r3 (apply max (cons 0.0 segCPc)))
           'dt_us_p50 (r3 (* 1000 (pct 0.5))) 'dt_us_p90 (r3 (* 1000 (pct 0.9))) 'dt_us_p99 (r3 (* 1000 (pct 0.99)))
           'dt_us_max (r3 (* 1000 (if (null? dts) 0 (car dts))))
           'top1pct_time_share (r3 (topshare 0.01)) 'top10pct_time_share (r3 (topshare 0.10))
           'productive_hub_time_share (r3 (/ (for/sum ([r fire-rows] #:when (and (vector-ref r 7) (= (vector-ref r 8) hub-cell))) (vector-ref r 1)) (max 1e-9 F)))
           'unproductive_time_share (r3 (/ (for/sum ([r fire-rows] #:unless (vector-ref r 7)) (vector-ref r 1)) (max 1e-9 F))))))
