#lang racket/base

;; ========================================================================
;; PPN 4C Phase 3d-bench: Residuation fire-function — lazy vs eager
;; ========================================================================
;;
;; Per D.3 §6.2 verification plan:
;;
;;   Before Phase 3 commits to the lazy implementation:
;;   3. A/B micro-benchmark comparing lazy vs eager (always-check-on-cross-tag).
;;      If eager overhead is <5%, eager's simplicity may win; if ≥10%, lazy's
;;      trigger refinement is worth the additional logic.
;;
;; Phase 3c-iii shipped the EAGER variant: subtype? runs on every propagator
;; fire when both tag layers are populated. This benchmark measures whether
;; a LAZY variant (skip subtype? if inputs unchanged since last check) offers
;; meaningful overhead reduction.
;;
;; Methodology:
;;   - Microbench the fire-function body directly (bypass propagator scheduler
;;     overhead — we're isolating the residuation check cost).
;;   - Eager: runs subtype? on every call.
;;   - Lazy: closure-cache last-seen (classifier . inhabitant); skip subtype?
;;     if pair matches cache. First call populates; subsequent unchanged calls
;;     hit cache. (Closure state here is SCAFFOLDING for measurement; if lazy
;;     wins the §6.2 threshold, production lazy uses a companion cell per
;;     on-network.md Propagator Statelessness rule.)
;;   - Three workloads:
;;     * all-unchanged: 100% cache hits (best case for lazy)
;;     * all-changed: 100% cache misses (worst case for lazy — extra eq? cost)
;;     * half-changed: 50/50 mix (representative)
;;
;; The numbers feed a decision lock: adopt eager (if <5% overhead), defer to
;; lazy (if ≥10%), or accept eager with a note (5-10% gray zone).

(require "../../tools/bench-micro.rkt"
         "../../classify-inhabit.rkt"
         "../../subtype-predicate.rkt"
         "../../syntax.rkt"
         "../../type-lattice.rkt"
         "../../prelude.rkt"  ;; lzero
         racket/list)

;; ========================================
;; Test inputs (representative of meta positions in real elaboration)
;; ========================================

(define test-classifier (expr-Int))
(define test-inhabitant (expr-int 42))

(define test-classifier-type (expr-Type (lzero)))
(define test-inhabitant-type (expr-Nat))

(define test-classifier-bool (expr-Bool))
(define test-inhabitant-bool (expr-true))

;; Pre-built classify-inhabit values for the fire functions to read.
(define ci-both-populated
  (classify-inhabit-value test-classifier test-inhabitant))

(define ci-type-meta
  (classify-inhabit-value test-classifier-type test-inhabitant-type))

(define ci-bool
  (classify-inhabit-value test-classifier-bool test-inhabitant-bool))

;; A mini type-of-expr, mirroring typing-propagators.rkt's version.
(define (type-of-expr-mini e)
  (cond
    [(expr-int? e) (expr-Int)]
    [(expr-nat-val? e) (expr-Nat)]
    [(expr-true? e) (expr-Bool)]
    [(expr-false? e) (expr-Bool)]
    [(expr-Int? e) (expr-Type (lzero))]
    [(expr-Nat? e) (expr-Type (lzero))]
    [(expr-Bool? e) (expr-Type (lzero))]
    [(expr-Type? e) (expr-Type (lzero))]  ;; simplified: lsuc not used in bench
    [else type-bot]))

;; ========================================
;; Eager fire function — mirrors typing-propagators.rkt shape
;; ========================================
;;
;; Signature abstracted: takes the cell value directly (bypass cell read).
;; Returns a SYMBOL: 'compat | 'contradiction. Bench target is the per-call
;; cost of the compatibility check — the cell-read/write wrapping is constant.

(define (fire-eager cinhab)
  (define classifier (classify-inhabit-value-classifier-or-bot cinhab))
  (define inhabitant (classify-inhabit-value-inhabitant-or-bot cinhab))
  (cond
    [(or (eq? classifier 'bot) (eq? inhabitant 'bot)) 'threshold-not-met]
    [(classify-inhabit-contradiction? cinhab) 'already-contradicted]
    [else
     (define inhabitant-type (type-of-expr-mini inhabitant))
     (cond
       [(type-bot? inhabitant-type) 'defer]
       [else
        (cond
          [(subtype? inhabitant-type classifier) 'compat]
          [else 'contradiction])])]))

;; ========================================
;; Lazy fire function — closure-cache last-seen pair
;; ========================================
;;
;; SCAFFOLDING: closure state is used here for bench isolation. Production
;; lazy (if we adopt it) would use a companion cell. Cache-hit path skips
;; type-of-expr + subtype? entirely — just an eq?+eq? on last-seen.

(define (make-fire-lazy)
  (define last-classifier #f)
  (define last-inhabitant #f)
  (define last-result #f)
  (lambda (cinhab)
    (define classifier (classify-inhabit-value-classifier-or-bot cinhab))
    (define inhabitant (classify-inhabit-value-inhabitant-or-bot cinhab))
    (cond
      [(or (eq? classifier 'bot) (eq? inhabitant 'bot)) 'threshold-not-met]
      [(classify-inhabit-contradiction? cinhab) 'already-contradicted]
      ;; Cache hit: inputs unchanged since last call
      [(and (eq? classifier last-classifier)
            (eq? inhabitant last-inhabitant)) last-result]
      [else
       (define inhabitant-type (type-of-expr-mini inhabitant))
       (define result
         (cond
           [(type-bot? inhabitant-type) 'defer]
           [else
            (cond
              [(subtype? inhabitant-type classifier) 'compat]
              [else 'contradiction])]))
       (set! last-classifier classifier)
       (set! last-inhabitant inhabitant)
       (set! last-result result)
       result])))

;; ========================================
;; Workload scenarios
;; ========================================
;;
;; Each workload constructs a list of N cinhab values to feed to the fire
;; function. The bench macro measures per-call cost.

(define N 100000)

;; All-unchanged: fire on the same cinhab N times. Best case for lazy.
(define workload-all-unchanged
  (for/list ([_ (in-range N)]) ci-both-populated))

;; All-changed: alternate between three distinct cinhabs. Worst case for
;; lazy — cache always misses; extra eq?+eq? on top of subtype?.
(define workload-all-changed
  (for/list ([i (in-range N)])
    (case (modulo i 3)
      [(0) ci-both-populated]
      [(1) ci-type-meta]
      [(2) ci-bool])))

;; Half-changed: alternate between two cinhabs; lazy hits every other call.
(define workload-half-changed
  (for/list ([i (in-range N)])
    (if (even? i) ci-both-populated ci-type-meta)))

;; ========================================
;; Benchmarks
;; ========================================

(define (run-workload fire-fn workload)
  (for ([cinhab (in-list workload)])
    (fire-fn cinhab)))

;; EAGER

(define b-eager-all-unchanged
  (bench "eager / all-unchanged"
    (run-workload fire-eager workload-all-unchanged)))

(define b-eager-all-changed
  (bench "eager / all-changed"
    (run-workload fire-eager workload-all-changed)))

(define b-eager-half-changed
  (bench "eager / half-changed"
    (run-workload fire-eager workload-half-changed)))

;; LAZY (closure-cached)

(define b-lazy-all-unchanged
  (bench "lazy / all-unchanged"
    (run-workload (make-fire-lazy) workload-all-unchanged)))

(define b-lazy-all-changed
  (bench "lazy / all-changed"
    (run-workload (make-fire-lazy) workload-all-changed)))

(define b-lazy-half-changed
  (bench "lazy / half-changed"
    (run-workload (make-fire-lazy) workload-half-changed)))

;; ========================================
;; Report + decision analysis
;; ========================================

(define all-results
  (list b-eager-all-unchanged
        b-eager-all-changed
        b-eager-half-changed
        b-lazy-all-unchanged
        b-lazy-all-changed
        b-lazy-half-changed))

(print-bench-summary all-results)

;; Decision analysis: compute overhead of eager vs lazy per workload.
;; §6.2 threshold: <5% → adopt eager; ≥10% → adopt lazy; 5-10% → gray zone.
(define (median-ms br)
  (hash-ref (bench-result-stats br) 'median_ms))

(define (overhead-pct eager lazy)
  ;; Lazy is the baseline; eager overhead = (eager - lazy) / lazy * 100
  ;; Positive = eager slower; negative = eager faster
  (define e (median-ms eager))
  (define l (median-ms lazy))
  (if (zero? l) 0.0 (* 100.0 (/ (- e l) l))))

(define (pad-str v n)
  (define s (if (string? v) v (format "~a" v)))
  (define diff (- n (string-length s)))
  (if (positive? diff) (string-append s (make-string diff #\space)) s))

(printf "\n=== Phase 3d-bench decision analysis ===\n")
(printf "§6.2 thresholds: <5%% eager overhead → adopt eager; ≥10%% → adopt lazy\n")
(printf "Median per-workload timing (ms for ~a fire-fn calls)\n\n" N)
(printf "Workload           Eager(ms)    Lazy(ms)     Overhead    Decision\n")
(for ([w (in-list '(all-unchanged all-changed half-changed))]
      [e (in-list (list b-eager-all-unchanged b-eager-all-changed b-eager-half-changed))]
      [l (in-list (list b-lazy-all-unchanged b-lazy-all-changed b-lazy-half-changed))])
  (define pct (overhead-pct e l))
  (define decision
    (cond [(< pct 5.0) "adopt EAGER"]
          [(>= pct 10.0) "adopt LAZY"]
          [else "gray zone"]))
  (printf "  ~a  ~a   ~a   ~a%%   ~a\n"
          (pad-str w 18)
          (pad-str (real->decimal-string (median-ms e) 2) 10)
          (pad-str (real->decimal-string (median-ms l) 2) 10)
          (pad-str (real->decimal-string pct 1) 8)
          decision))
