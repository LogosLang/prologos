#lang racket/base
;;; benchmarks/par4/p0-profile.rkt — PAR 4 Pre-0 harness (D.1 §9).
;;;
;;; ONE .prologos file per process (the scratch-run.sh discipline: peak heap bounded by
;;; one file). A corpus sweep is a SHELL loop over files — see p0-sweep.sh.
;;;
;;;   racket benchmarks/par4/p0-profile.rkt MODE FILE.prologos
;;;
;;; prints exactly one line "P0:{json}" on stdout. MODE:
;;;   stats    — every BSP round (width = propagators fired, fire-ms, merge-ms, writes),
;;;              every OUTERMOST elaborator quiescence call (wall, bytes, fires, rounds),
;;;              forks, total wall/bytes/GC; Amdahl + K-bound models (P0-6, A-9).
;;;              Overhead: one box push per round, two clock reads per call.
;;;   census   — BSP observer ON (costly: not a timing mode). Every write classified by
;;;              the written cell's merge-fn, the new value's kind, tagged-entry count
;;;              (P0-1/A-13); dynamic cut locality of every fire under round-robin and
;;;              block-64 ownership at K=8 (P0-3/A-8); static census + connected
;;;              components of the largest network snapshot (hub conjecture, Q4).
;;;   profile  — sampling profiler (1 ms); inclusive/self ms of the scheduler's functions
;;;              and the top self-time functions (Amdahl attribution).
;;;
;;; Scheduler is chosen by PROLOGOS_SCHEDULER (bsp | seq | seq-shuffle) — read by
;;; propagator.rkt at load (PAR 4 P0 knob). Requires are RELATIVE (testing.md:39).
(require racket/list racket/math racket/port json
         (only-in profile profile-thunk)
         (only-in profile/analyzer profile-nodes node-id node-total node-self
                  profile-total-time profile-sample-number)
         (only-in "../../driver.rkt" process-file current-use-pnet-cache? current-pnet-write-enabled?)
         (only-in "../../propagator.rkt"
                  current-bsp-round-stats current-bsp-observer
                  bsp-round-network-snapshot bsp-round-propagators-fired bsp-round-cell-diffs
                  cell-diff-cell-id cell-diff-new-value
                  prop-network-merge-fns prop-network-propagators prop-network-cells
                  propagator-outputs propagator-inputs prop-cell-value
                  cell-id-hash prop-id-hash cell-id-n
                  par4-scheduler-mode par4-fork-count par4-midrun-topology)
         (only-in "../../champ.rkt" champ-lookup champ-size champ-fold)
         (only-in "../../metavar-store.rkt" current-quiescence-scheduler)
         (only-in "../../decision-cell.rkt" tagged-cell-value? tagged-cell-value-entries)
         (only-in "../../stratified-eval.rkt" par4-solve-routes))

(define-values (mode file)
  (let ([a (current-command-line-arguments)])
    (unless (= (vector-length a) 2) (error 'p0-profile "usage: MODE FILE"))
    (values (string->symbol (vector-ref a 0)) (vector-ref a 1))))

(define (now) (current-inexact-monotonic-milliseconds))
(define (bytes-now) (current-memory-use 'cumulative))
(define (r3 x) (if (real? x) (/ (round (* 1000 (exact->inexact x))) 1000.0) x))

;; histogram helpers --------------------------------------------------------------------
(define (bucket-of x edges)               ; edges ascending upper bounds; last = +inf
  (let loop ([i 0] [es edges])
    (cond [(null? es) i] [(<= x (car es)) i] [else (loop (add1 i) (cdr es))])))
(define (hist xs edges [weight (λ (x) 1)])
  (define v (make-vector (add1 (length edges)) 0))
  (for ([x (in-list xs)])
    (define b (bucket-of x edges))
    (vector-set! v b (+ (vector-ref v b) (weight x))))
  (for/list ([c (in-vector v)]) (r3 c)))
(define (pctl xs p)
  (if (null? xs) 0 (let ([s (sort xs <)]) (list-ref s (min (sub1 (length s)) (exact-floor (* p (length s))))))))

;; P0_NO_PNET=1 → elaborate every imported module from SOURCE (cold-cache workflow: what
;; happens after ANY compiler change makes every .pnet infrastructure-stale). Writes are
;; disabled too, so the run never mutates the shared cache.
(define no-pnet? (equal? (getenv "P0_NO_PNET") "1"))
(define (run-file* f)
  (parameterize ([current-output-port (open-output-nowhere)]
                 [current-use-pnet-cache? (not no-pnet?)]
                 [current-pnet-write-enabled? (not no-pnet?)])
    (process-file f)))
(define (run-file!) (run-file* file))
;; P0_PRELOAD=<file> → process that file first, UNTIMED and unobserved, so the measured run
;; sees an in-process module cache (what batch workers and the LSP see): the measured
;; number is the file's WORK, not prelude loading (which is ~90 % of a cold-process run).
(let ([pre (getenv "P0_PRELOAD")])
  (when (and pre (not (equal? pre "")))
    (run-file* pre)))

;; ─────────────────────────────────────────────────────────────────────────── stats ──
(define (do-stats)
  (define rounds (box '()))                ; (list n fire-ms merge-ms writes deferred)
  (define calls '())                       ; (list wall bytes fires rounds)
  (define depth 0)
  (define orig (current-quiescence-scheduler))
  (define (wrapped pnet)
    (cond
      [(> depth 0) (orig pnet)]
      [else
       (set! depth 1)
       (define r0 (length (unbox rounds)))
       (define b0 (bytes-now)) (define t0 (now))
       (define res (dynamic-wind void (λ () (orig pnet)) (λ () (set! depth 0))))
       (define t1 (now)) (define b1 (bytes-now))
       (define new (let ([l (unbox rounds)]) (take l (- (length l) r0))))
       (set! calls (cons (list (- t1 t0) (- b1 b0) (for/sum ([r new]) (car r)) (length new))
                         calls))
       res]))
  (define f0 (unbox par4-fork-count))
  (define mt0 (for/vector ([x (in-vector par4-midrun-topology)]) x))
  (define routes0 (hash-copy par4-solve-routes))
  (define g0 (current-gc-milliseconds))
  (define b0 (bytes-now)) (define t0 (now))
  (parameterize ([current-bsp-round-stats rounds]
                 [current-quiescence-scheduler wrapped])
    (run-file!))
  (define total-ms (- (now) t0))
  (define total-bytes (- (bytes-now) b0))
  (define gc-ms (- (current-gc-milliseconds) g0))
  (define rs (unbox rounds))
  (define widths (map car rs))
  (define fire-ms (for/sum ([r rs]) (cadr r)))
  (define merge-ms (for/sum ([r rs]) (caddr r)))
  (define fires (apply + widths))
  (define w-edges '(1 3 7 15 63))          ; buckets: 1 | 2-3 | 4-7 | 8-15 | 16-63 | 64+
  ;; K-bound model (BSP, today's per-fire cost): round time = fire/min(n,K) + merge
  ;; + L (1 µs dispatch+barrier, MEASURED contention §4). Lower bound on parallel S0 time.
  (define (s0-par K #:L [L 0.001])
    (for/sum ([r rs]) (+ (/ (cadr r) (min (car r) K)) (caddr r) L)))
  (define s0-seq (+ fire-ms merge-ms))
  (define c-walls (map car calls))
  (define c-fires (map caddr calls))
  (define c-edges '(0 1 5 20 100 1000))   ; fires per call: 0|1|2-5|6-20|21-100|101-1000|1001+
  (hasheq
   'file file 'mode "stats" 'scheduler (symbol->string par4-scheduler-mode) 'no_pnet no-pnet?
   'preload (or (getenv "P0_PRELOAD") "")
   'total_ms (r3 total-ms) 'total_mb (r3 (/ total-bytes 1e6)) 'gc_ms gc-ms
   'bytes_per_us (r3 (/ total-bytes (* 1000 total-ms)))
   'forks (- (unbox par4-fork-count) f0)
   'midrun_props (- (vector-ref par4-midrun-topology 0) (vector-ref mt0 0))
   'midrun_cells (- (vector-ref par4-midrun-topology 1) (vector-ref mt0 1))
   'midrun_rounds (- (vector-ref par4-midrun-topology 2) (vector-ref mt0 2))
   'solve_routes (for/hasheq ([(k v) par4-solve-routes]) (values k (- v (hash-ref routes0 k 0))))
   'bsp_rounds (length rs) 'bsp_fires fires 'bsp_writes (for/sum ([r rs]) (cadddr r))
   'bsp_fire_ms (r3 fire-ms) 'bsp_merge_ms (r3 merge-ms)
   's0_share (r3 (if (> total-ms 0) (/ s0-seq total-ms) 0))
   'width_p50 (pctl widths 0.5) 'width_p90 (pctl widths 0.9) 'width_max (if (null? widths) 0 (apply max widths))
   'width_hist_rounds (hist widths w-edges)
   'width_hist_fire_ms (let ([v (make-vector 6 0)])
                         (for ([r rs]) (define b (bucket-of (car r) w-edges))
                           (vector-set! v b (+ (vector-ref v b) (cadr r))))
                         (map r3 (vector->list v)))
   'us_per_fire (r3 (if (> fires 0) (/ (* 1000 fire-ms) fires) 0))
   'us_per_round_merge (r3 (if (pair? rs) (/ (* 1000 merge-ms) (length rs)) 0))
   'model_s0_par_ms (for/hasheq ([K '(2 4 8 16)]) (values (string->symbol (format "K~a" K)) (r3 (s0-par K))))
   'model_e2e_speedup (for/hasheq ([K '(2 4 8 16)])
                        (values (string->symbol (format "K~a" K))
                                (r3 (/ total-ms (+ (- total-ms s0-seq) (s0-par K))))))
   'model_e2e_speedup_no_merge_K8 ; H-S removes the merge phase
   (r3 (/ total-ms (+ (- total-ms s0-seq) (for/sum ([r rs]) (+ (/ (cadr r) (min (car r) 8)) 0.001)))))
   'model_e2e_bound_s0_free (r3 (if (> total-ms s0-seq) (/ total-ms (- total-ms s0-seq)) +inf.0))
   'elab_calls (length calls)
   'elab_call_ms (r3 (apply + c-walls))
   'elab_call_mb (r3 (/ (apply + (map cadr calls)) 1e6))
   'elab_call_wall_p50_us (r3 (* 1000 (pctl c-walls 0.5)))
   'elab_call_wall_p90_us (r3 (* 1000 (pctl c-walls 0.9)))
   'elab_call_wall_max_ms (r3 (if (null? c-walls) 0 (apply max c-walls)))
   'elab_call_fires_hist (hist c-fires c-edges)
   'elab_call_fires_hist_ms (let ([v (make-vector 7 0)])
                              (for ([c calls]) (define b (bucket-of (caddr c) c-edges))
                                (vector-set! v b (+ (vector-ref v b) (car c))))
                              (map r3 (vector->list v)))
   'elab_calls_under_10us (length (filter (λ (w) (< w 0.010)) c-walls))))

;; ────────────────────────────────────────────────────────────────────────── census ──
(define (kind-of v)
  (cond [(fixnum? v) 'fixnum] [(boolean? v) 'boolean] [(symbol? v) 'symbol]
        [(null? v) 'null] [(pair? v) 'list] [(hash? v) 'hash] [(string? v) 'string]
        [(tagged-cell-value? v) 'tagged] [(number? v) 'number] [(vector? v) 'vector]
        [(struct? v) (let ([n (vector-ref (struct->vector v) 0)])
                       (string->symbol (regexp-replace #rx"^struct:" (symbol->string n) "")))]
        [(procedure? v) 'procedure]
        [else (let ([n (vector-ref (struct->vector v) 0)])   ; opaque struct
                (string->symbol (regexp-replace #rx"^struct:" (symbol->string n) "")))]))
(define (fn-name f) (let ([n (and (procedure? f) (object-name f))]) (if n (symbol->string n) "anon")))
(define (merge-fn-of snap cid)
  (define mf (champ-lookup (prop-network-merge-fns snap) (cell-id-hash cid) cid))
  (if (eq? mf 'none) "none" (fn-name mf)))
(define (inc! h k [d 1]) (hash-set! h k (+ d (hash-ref h k 0))))
(define (top h [n 25]) (for/list ([p (in-list (take (sort (hash->list h) > #:key cdr) (min n (hash-count h))))])
                         (list (format "~a" (car p)) (cdr p))))

(define (do-census)
  (define K 8)
  (define writes-by-merge (make-hash))
  (define writes-by-kind (make-hash))
  (define tagged-entries (make-hash))         ; entries-count → writes
  (define widths '())
  (define n-rounds 0)
  ;; dynamic cut locality (every fire, its own round's snapshot)
  (define cut (make-hash))                    ; scheme → (vector fires-with-foreign-write out-edges foreign-out in-edges foreign-in fires)
  (define (owner scheme c) (case scheme
                             [(rr) (modulo (cell-id-n c) K)]
                             [(block64) (modulo (quotient (cell-id-n c) 64) K)]))
  (define largest #f) (define largest-n -1)
  (define (observe r)
    (set! n-rounds (add1 n-rounds))
    (define snap (bsp-round-network-snapshot r))
    (define fired (bsp-round-propagators-fired r))
    (set! widths (cons (length fired) widths))
    (for ([d (in-list (bsp-round-cell-diffs r))])
      (define cid (cell-diff-cell-id d))
      (inc! writes-by-merge (merge-fn-of snap cid))
      (define v (cell-diff-new-value d))
      (inc! writes-by-kind (kind-of v))
      (when (tagged-cell-value? v)
        (inc! tagged-entries (length (tagged-cell-value-entries v)))))
    (define props (prop-network-propagators snap))
    (for ([pid (in-list fired)])
      (define p (champ-lookup props (prop-id-hash pid) pid))
      (unless (eq? p 'none)
        (define outs (propagator-outputs p)) (define ins (propagator-inputs p))
        (for ([scheme '(rr block64)])
          (define acc (hash-ref! cut scheme (λ () (make-vector 6 0))))
          (define home (cond [(pair? outs) (owner scheme (car outs))]
                             [(pair? ins) (owner scheme (car ins))] [else 0]))
          (define fo (for/sum ([c outs]) (if (= (owner scheme c) home) 0 1)))
          (define fi (for/sum ([c ins]) (if (= (owner scheme c) home) 0 1)))
          (vector-set! acc 0 (+ (vector-ref acc 0) (if (> fo 0) 1 0)))
          (vector-set! acc 1 (+ (vector-ref acc 1) (length outs)))
          (vector-set! acc 2 (+ (vector-ref acc 2) fo))
          (vector-set! acc 3 (+ (vector-ref acc 3) (length ins)))
          (vector-set! acc 4 (+ (vector-ref acc 4) fi))
          (vector-set! acc 5 (+ (vector-ref acc 5) 1)))))
    (define sz (champ-size (prop-network-cells snap)))
    (when (> sz largest-n) (set! largest-n sz) (set! largest snap)))
  (define f0 (unbox par4-fork-count))
  (parameterize ([current-bsp-observer observe]) (run-file!))
  ;; static census + connected components on the largest snapshot
  (define static
    (if (not largest) (hasheq)
        (let ()
          (define cells (prop-network-cells largest))
          (define by-merge (make-hash)) (define by-kind (make-hash))
          (define deg (make-hash))                      ; cell-n → #propagators touching
          (champ-fold cells (λ (cid cell acc)
                              (inc! by-merge (merge-fn-of largest cid))
                              (inc! by-kind (kind-of (prop-cell-value cell))) acc) (void))
          ;; union-find over cells joined by propagators
          (define parent (make-hasheqv))
          (define (find x) (let ([p (hash-ref parent x x)]) (if (= p x) x (let ([r (find p)]) (hash-set! parent x r) r))))
          (define (union! a b) (let ([ra (find a)] [rb (find b)]) (unless (= ra rb) (hash-set! parent ra rb))))
          (define plist '())
          (champ-fold (prop-network-propagators largest)
                      (λ (pid p acc)
                        (define cs (map cell-id-n (append (propagator-inputs p) (propagator-outputs p))))
                        (for ([c cs]) (inc! deg c))
                        (set! plist (cons cs plist)) acc) (void))
          (define (components hub?)
            (set! parent (make-hasheqv))
            (for ([cs plist])
              (define cs* (filter (λ (c) (not (hub? c))) cs))
              (when (pair? cs*) (for ([c (cdr cs*)]) (union! (car cs*) c))))
            (define sizes (make-hash))
            (champ-fold cells (λ (cid cell acc) (unless (hub? (cell-id-n cid)) (inc! sizes (find (cell-id-n cid)))) acc) (void))
            (define ss (sort (hash-values sizes) >))
            (define tot (apply + ss))
            (hasheq 'components (length ss) 'largest (if (null? ss) 0 (car ss))
                    'largest_share (r3 (if (> tot 0) (/ (car ss) tot) 0))
                    'top5 (take ss (min 5 (length ss)))))
          (define degs (sort (hash->list deg) > #:key cdr))
          (hasheq 'cells (champ-size cells)
                  'propagators (champ-size (prop-network-propagators largest))
                  'cells_by_merge (top by-merge) 'cells_by_kind (top by-kind 15)
                  'hub_cells_top10 (for/list ([p (take degs (min 10 (length degs)))]) (list (car p) (cdr p)))
                  'cc_all (components (λ (c) #f))
                  'cc_without_degree_ge_64 (components (λ (c) (>= (hash-ref deg c 0) 64)))
                  'cc_without_degree_ge_16 (components (λ (c) (>= (hash-ref deg c 0) 16)))))))
  (hasheq 'file file 'mode "census" 'scheduler (symbol->string par4-scheduler-mode)
          'rounds n-rounds 'forks (- (unbox par4-fork-count) f0)
          'writes (apply + (hash-values writes-by-merge))
          'writes_by_merge (top writes-by-merge 30)
          'writes_by_kind (top writes-by-kind 20)
          'tagged_entries_hist (for/list ([p (sort (hash->list tagged-entries) < #:key car)]) (list (car p) (cdr p)))
          'cut_K8 (for/hasheq ([(s v) cut])
                    (values s (hasheq 'fires (vector-ref v 5)
                                      'fires_with_foreign_write_share (r3 (/ (vector-ref v 0) (max 1 (vector-ref v 5))))
                                      'foreign_out_edge_share (r3 (/ (vector-ref v 2) (max 1 (vector-ref v 1))))
                                      'foreign_in_edge_share (r3 (/ (vector-ref v 4) (max 1 (vector-ref v 3))))
                                      'outs_per_fire (r3 (/ (vector-ref v 1) (max 1 (vector-ref v 5))))
                                      'ins_per_fire (r3 (/ (vector-ref v 3) (max 1 (vector-ref v 5)))))))
          'largest_network static))

;; ───────────────────────────────────────────────────────────────────────── profile ──
(define watch '("run-to-quiescence" "run-to-quiescence-bsp" "run-to-quiescence-drain"
                "run-to-quiescence-inner" "fire-and-collect-writes" "bulk-merge-writes"
                "sequential-fire-all" "fire-propagator" "net-cell-write" "net-cell-write/slow-path"
                "net-cell-read" "fork-prop-network" "champ-insert" "champ-lookup" "champ-diff"
                "net-new-cell" "net-add-propagator" "process-command" "process-file"
                "elaborate" "infer" "check" "unify" "zonk" "whnf" "nf"))
(define (do-profile)
  (define captured #f)
  (define g0 (current-gc-milliseconds)) (define t0 (now))
  ;; P0_REPEAT=n runs the file n times inside ONE profile (more samples on short files).
  (define reps (or (string->number (or (getenv "P0_REPEAT") "1")) 1))
  (profile-thunk (λ () (for ([_ reps]) (run-file!))) #:delay 0.001 #:render (λ (p o) (set! captured p)))
  (define total-ms (- (now) t0))
  (define nodes (profile-nodes captured))
  (define (nm n) (format "~a" (or (node-id n) "?")))
  (define by-name (make-hash))
  (for ([n nodes]) (hash-update! by-name (nm n) (λ (v) (list (+ (car v) (node-total n)) (+ (cadr v) (node-self n)))) '(0 0)))
  (define pt (profile-total-time captured))
  (define (ms x) (r3 (exact->inexact x)))
  (hasheq 'file file 'mode "profile" 'scheduler (symbol->string par4-scheduler-mode)
          'wall_ms (r3 total-ms) 'gc_ms (- (current-gc-milliseconds) g0)
          'profile_total_ms (ms pt) 'samples (profile-sample-number captured)
          'watch (for/hasheq ([w watch] #:when (hash-ref by-name w #f))
                   (define v (hash-ref by-name w))
                   (values (string->symbol w) (hasheq 'incl_ms (ms (car v)) 'self_ms (ms (cadr v))
                                                      'incl_share (r3 (/ (car v) (max 1 pt))))))
          'reps reps
          'top_incl (for/list ([p (take (sort (hash->list by-name) > #:key cadr) (min 45 (hash-count by-name)))])
                      (list (car p) (ms (cadr p)) (r3 (/ (cadr p) (max 1 pt)))))
          'top_self (for/list ([p (take (sort (hash->list by-name) > #:key caddr) (min 25 (hash-count by-name)))])
                      (list (car p) (ms (caddr p)) (r3 (/ (caddr p) (max 1 pt)))))))

(define result
  (case mode
    [(stats) (do-stats)] [(census) (do-census)] [(profile) (do-profile)]
    [else (error 'p0-profile "unknown mode ~a" mode)]))
(printf "P0:~a\n" (jsexpr->string result))
