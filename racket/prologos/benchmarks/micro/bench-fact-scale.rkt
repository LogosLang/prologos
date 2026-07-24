#lang racket/base

;; bench-fact-scale.rkt — Fact-relation SCALE benchmark (Rel T1 Aspect D, D.2.c)
;;
;; The Phase-0 instrument from the Aspect D research artifact
;; (docs/research/2026-07-23_FACT_REPRESENTATION_QUERY_OPTIMIZATION.md §8):
;; prior to this file, every published solver number was measured on tables
;; ≤16 rows — 16× below the :auto DFS↔ATMS dispatch threshold (256), i.e. in
;; the regime where a linear scan is optimal by construction. This benchmark
;; measures the scan ladder ACROSS the threshold, with the ENGINE PINNED
;; per case (never :auto), so the DFS↔ATMS crossover is measured, not assumed.
;;
;; Two tiers:
;;   1. WALL-CLOCK ladder (bench-micro statistical harness) — ambient-sensitive;
;;      compare across runs only via interleaved A/B or worktree-pinned baseline
;;      (per .claude/rules/testing.md § bench A/B).
;;   2. DETERMINISTIC COUNTER table — solver_row_scans / solver_col_compares /
;;      solver_unifies / solver_backtracks per (engine × query-shape × N).
;;      Exact and ambient-immune; the primary A/B instrument (D.2.b counters).
;;
;; Engine pinning:
;;   DFS  = solve-goal            (the recursive scan engine — where ~all real
;;                                 queries run today)
;;   ATMS = solve-goal-propagator — with a TWO-VARIANT store. Verified during
;;          D.2.c: for a SINGLE-variant facts-only relation, NO query shape
;;          reaches the Tier-2 network through this entry — var-bearing
;;          queries are absorbed by the tier-1 fast path (relations.rkt
;;          `tier-1 check ... fallback`), and all-ground queries are
;;          DELEGATED TO DFS (`[(null? query-vars) (solve-goal ...)]`).
;;          The on-network fact path is unreachable BY CONSTRUCTION for pure
;;          fact tables — a sharper form of the artifact §3.4 finding.
;;          Splitting facts across two variants defeats tier-1's
;;          single-variant guard and pins genuine Tier-2 (assumptions +
;;          worldview bits per row; the mask goes BIGNUM past 62 rows).
;;          Measured (D.2.c probe): Tier-2 enum 0.97ms@10 / 4.6ms@100 /
;;          28ms@250 / 389ms@1000 — superlinear; ladder capped at 1000.
;;
;; Query shapes (artifact §8): ground-key point lookup (LAST row = worst case),
;; all-free enumeration, all-ground boolean membership (hit + miss).
;; Join / recursion / NAF shapes live in the E2E .prologos tier
;; (tools/gen-fact-corpus.rkt + benchmarks/comparative/solve-scale.prologos).
;;
;; Run:  racket benchmarks/micro/bench-fact-scale.rkt            (from racket/prologos/)
;;       FACT_SCALE_MAX=100000 racket benchmarks/micro/bench-fact-scale.rkt
;;         (default max 10000 keeps a full run ≈1-2 min; 100000 for the
;;          artifact-§2.5 extrapolation check)

(require "../../tools/bench-micro.rkt"
         "../../relations.rkt"
         "../../solver.rkt"
         "../../performance-counters.rkt")

;; ============================================================
;; Store construction
;; ============================================================

;; Rows: (i, sym_i, i*7) — first column dense integer key (index-friendly),
;; second boxed symbol (the realistic case), third derived int.
(define (scale-facts lo hi)
  (for/list ([i (in-range lo hi)])
    (fact-row (list i (string->symbol (format "v~a" i)) (* 7 i)))))

(define scale-params
  (list (param-info 'k 'free) (param-info 's 'free) (param-info 'w 'free)))

(define (make-scale-store n-rows)
  (relation-register (make-relation-store)
    (relation-info 'data 3
      (list (variant-info scale-params '() (scale-facts 0 n-rows)))
      #f #f)))

;; Two-variant split of the same rows — defeats tier-1's single-variant guard
;; so var-bearing queries reach the genuine Tier-2 network (see header).
(define (make-scale-store-2v n-rows)
  (define half (quotient n-rows 2))
  (relation-register (make-relation-store)
    (relation-info 'data 3
      (list (variant-info scale-params '() (scale-facts 0 half))
            (variant-info scale-params '() (scale-facts half n-rows)))
      #f #f)))

(define cfg default-solver-config)

;; The ladder. 250/260 bracket the :auto threshold (solver.rkt:76, 256) —
;; irrelevant here (engines are pinned) but kept so E2E comparisons line up.
(define max-n
  (let ([env (getenv "FACT_SCALE_MAX")])
    (if env (string->number env) 10000)))
(define dfs-ladder  (filter (lambda (n) (<= n max-n)) '(10 100 250 260 1000 10000 100000)))
(define atms-ladder (filter (lambda (n) (<= n (min max-n 1000))) '(10 100 250 260 1000)))

;; Per-N iteration counts sized to keep each bench sample in the ms range.
(define (iters-for n base)
  (max 1 (quotient base n)))

;; ============================================================
;; Query shapes (engine-parameterized)
;; ============================================================

;; Ground-key point lookup, LAST row (worst case for a scan; the missing
;; early-exit means even a first-row hit scans everything on Tier-1, but
;; last-row is worst for DFS too).
(define (q-point solve store n)
  (solve cfg store 'data (list (sub1 n) 's 'w) '(s w)))

;; All-free enumeration.
(define (q-enum solve store)
  (solve cfg store 'data '() '(k s w)))

;; All-ground membership — hit (last row) and miss.
(define (q-member-hit solve store n)
  (solve cfg store 'data (list (sub1 n) (string->symbol (format "v~a" (sub1 n))) (* 7 (sub1 n))) '()))
(define (q-member-miss solve store)
  (solve cfg store 'data (list -1 'nope -7) '()))

;; ============================================================
;; Tier 1: wall-clock ladder
;; ============================================================

(define (run-wall-ladder engine-name solve ladder
                         #:make-store [make-store make-scale-store]
                         #:point-base [point-base 20000]
                         #:enum-base [enum-base 2000]
                         #:member? [member? #t])
  (for/list ([n (in-list ladder)])
    (define store (make-store n))
    (define point-iters (iters-for n point-base))
    (define enum-iters  (iters-for n enum-base))
    (append
     (list
      (bench (format "~a point-last  N=~a x~a" engine-name n point-iters)
        (for ([_ (in-range point-iters)]) (q-point solve store n)))
      (bench (format "~a enum-all    N=~a x~a" engine-name n enum-iters)
        (for ([_ (in-range enum-iters)]) (q-enum solve store))))
     (if member?
         (list
          (bench (format "~a member-hit  N=~a x~a" engine-name n point-iters)
            (for ([_ (in-range point-iters)]) (q-member-hit solve store n))))
         '()))))

;; ============================================================
;; Tier 2: deterministic counter table (the ambient-immune instrument)
;; ============================================================

(define (counter-row engine-name shape-name thunk)
  (define-values (_ pc) (with-perf-counters (thunk)))
  (printf "~a | ~a | rows=~a cols=~a unifies=~a backtracks=~a cells=~a props=~a\n"
          engine-name shape-name
          (perf-counters-solver-row-scans pc)
          (perf-counters-solver-col-compares pc)
          (perf-counters-solver-unifies pc)
          (perf-counters-solver-backtracks pc)
          (perf-counters-cell-allocs pc)
          (perf-counters-prop-allocs pc)))

(define (run-counter-table)
  (displayln "\n=== Deterministic counters: one query per (engine × shape × N) ===")
  (displayln "engine | shape N | counters (exact, ambient-immune)")
  (for ([n (in-list dfs-ladder)])
    (define store (make-scale-store n))
    (counter-row "DFS " (format "point-last  N=~a" n) (lambda () (q-point solve-goal store n)))
    (counter-row "DFS " (format "enum-all    N=~a" n) (lambda () (q-enum solve-goal store)))
    (counter-row "DFS " (format "member-hit  N=~a" n) (lambda () (q-member-hit solve-goal store n)))
    (counter-row "DFS " (format "member-miss N=~a" n) (lambda () (q-member-miss solve-goal store))))
  (for ([n (in-list atms-ladder)])
    (define store (make-scale-store-2v n))
    (counter-row "ATMS" (format "point-last  N=~a" n) (lambda () (q-point solve-goal-propagator store n)))
    (counter-row "ATMS" (format "enum-all    N=~a" n) (lambda () (q-enum solve-goal-propagator store))))
  ;; Reference rows: the SINGLE-variant store through the ATMS entry — served
  ;; entirely by tier-1 (rows=N, cols=N+2, cells=0, props=0), demonstrating the
  ;; tier-1 shield that makes Tier-2 unreachable for pure fact tables.
  (for ([n (in-list '(100 1000))])
    (define store (make-scale-store n))
    (counter-row "T1* " (format "point-last  N=~a (1-variant via ATMS entry)" n)
                 (lambda () (q-point solve-goal-propagator store n)))))

;; ============================================================
;; Main
;; ============================================================

(displayln "=== bench-fact-scale: DFS wall ladder (pinned solve-goal) ===")
(define dfs-results (run-wall-ladder "DFS " solve-goal dfs-ladder))
(for ([group (in-list dfs-results)]) (print-bench-summary group))

(displayln "\n=== bench-fact-scale: Tier-2/ATMS wall ladder (2-variant store; capped at 1000; member delegates to DFS so omitted — see header) ===")
;; Low iteration bases: Tier-2 enum is superlinear (≈389ms/query at N=1000).
(define atms-results
  (run-wall-ladder "ATMS" solve-goal-propagator atms-ladder
                   #:make-store make-scale-store-2v
                   #:point-base 2000 #:enum-base 100 #:member? #f))
(for ([group (in-list atms-results)]) (print-bench-summary group))

(run-counter-table)
