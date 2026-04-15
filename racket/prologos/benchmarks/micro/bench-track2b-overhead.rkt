#lang racket/base

;; bench-track2b-overhead.rkt — Decompose the 24.5x ATMS overhead
;;
;; For a single-fact query, the ATMS solver takes 23.5us vs DFS 0.96us.
;; This benchmark isolates each component of solve-goal-propagator
;; to identify where the time goes.
;;
;; Pipeline: make-prop-network → make-solver-context (7 cells + 1 propagator)
;;           → build-var-env (1 cell) → net-new-cell (answer acc)
;;           → install-goal-propagator → run-to-quiescence → read results
;;
;; Run: racket benchmarks/micro/bench-track2b-overhead.rkt

(require "../../tools/bench-micro.rkt"
         "../../propagator.rkt"
         "../../atms.rkt"
         "../../decision-cell.rkt"
         "../../relations.rkt"
         "../../solver.rkt"
         "../../syntax.rkt")

;; ============================================================
;; Setup: same single-fact relation as S7
;; ============================================================

(define simple-rel
  (relation-info 'simple 1
    (list (variant-info
           (list (param-info 'x 'free))
           '()
           (list (fact-row (list 42)))))
    #f #f))

(define simple-store (relation-register (make-relation-store) simple-rel))

(define atms-config (make-solver-config (hasheq 'strategy 'atms)))
(define dfs-config (make-solver-config (hasheq 'strategy 'depth-first)))

;; ============================================================
;; Step 1: Network creation
;; ============================================================

(bench "step1: make-prop-network x10000"
  (for ([_ (in-range 10000)])
    (make-prop-network 1000000)))

;; ============================================================
;; Step 2: make-solver-context (7 cells + worldview projection propagator)
;; ============================================================

(bench "step2: make-solver-context x5000"
  (for ([_ (in-range 5000)])
    (define net0 (make-prop-network 1000000))
    (make-solver-context net0)))

;; Step 2 MINUS step 1 = solver-context allocation cost

;; ============================================================
;; Step 3: build-var-env (1 scope cell + env hasheq)
;; ============================================================

(bench "step3: build-var-env x10000"
  (for ([_ (in-range 10000)])
    (define net0 (make-prop-network))
    (build-var-env net0 '(x))))

;; ============================================================
;; Step 4: Answer accumulator cell
;; ============================================================

(bench "step4: net-new-cell (answer acc) x10000"
  (for ([_ (in-range 10000)])
    (define net0 (make-prop-network))
    (net-new-cell net0 '() (lambda (a b) (append a b)))))

;; ============================================================
;; Step 5: install-goal-propagator (goal installation)
;; ============================================================
;; This includes: relation lookup, clause/fact dispatch, cell allocation
;; for clause params, propagator installation for goals.

(bench "step5: install-goal-propagator x2000"
  (for ([_ (in-range 2000)])
    (define net0 (make-prop-network 1000000))
    ;; Phase R1: write store and config to well-known cells
    (define net0a (net-cell-write net0 relation-store-cell-id simple-store))
    (define net0b (net-cell-write net0a config-cell-id atms-config))
    (define-values (net-ctx ctx) (make-solver-context net0b))
    (define-values (net1 query-env) (build-var-env net-ctx '(x)))
    (define-values (net2 answer-cid) (net-new-cell net1 '() (lambda (a b) (append a b))))
    (define top-goal (goal-desc 'app (list 'simple '(x))))
    (install-goal-propagator net2 top-goal query-env answer-cid ctx)))

;; ============================================================
;; Step 6: run-to-quiescence (BSP scheduling)
;; ============================================================
;; Measure quiescence AFTER goal installation (worklist has items)

(bench "step6: run-to-quiescence (with installed goal) x2000"
  (for ([_ (in-range 2000)])
    (define net0 (make-prop-network 1000000))
    (define net0a (net-cell-write net0 relation-store-cell-id simple-store))
    (define net0b (net-cell-write net0a config-cell-id atms-config))
    (define-values (net-ctx ctx) (make-solver-context net0b))
    (define-values (net1 query-env) (build-var-env net-ctx '(x)))
    (define-values (net2 answer-cid) (net-new-cell net1 '() (lambda (a b) (append a b))))
    (define top-goal (goal-desc 'app (list 'simple '(x))))
    (define net3 (install-goal-propagator net2 top-goal query-env answer-cid ctx))
    (run-to-quiescence net3)))

;; ============================================================
;; Step 7: Result extraction (read scope cells, build hasheq)
;; ============================================================
;; We need a completed network to read from

(define (make-completed-net)
  (define net0 (make-prop-network 1000000))
  (define net0a (net-cell-write net0 relation-store-cell-id simple-store))
  (define net0b (net-cell-write net0a config-cell-id atms-config))
  (define-values (net-ctx ctx) (make-solver-context net0b))
  (define-values (net1 query-env) (build-var-env net-ctx '(x)))
  (define-values (net2 answer-cid) (net-new-cell net1 '() (lambda (a b) (append a b))))
  (define top-goal (goal-desc 'app (list 'simple '(x))))
  (define net3 (install-goal-propagator net2 top-goal query-env answer-cid ctx))
  (define net4 (run-to-quiescence net3))
  (values net4 query-env))

(define-values (completed-net completed-env) (make-completed-net))
(define completed-ref (hash-ref completed-env 'x))
(define completed-scope-cid (car completed-ref))  ;; scope-ref = (cons cell-id var-name)

(bench "step7: read results x10000"
  (for ([_ (in-range 10000)])
    (define scope-raw (net-cell-read-raw completed-net completed-scope-cid))
    (define sc-val (net-cell-read completed-net completed-scope-cid))
    (for/hasheq ([qv (in-list '(x))])
      (define val (if (scope-cell? sc-val) (scope-cell-ref sc-val qv) 'bot))
      (values qv val))))

;; ============================================================
;; Full pipeline (for comparison — should match S7 results)
;; ============================================================

(bench "full-pipeline: ATMS single-fact x2000"
  (for ([_ (in-range 2000)])
    (solve-goal-propagator atms-config simple-store 'simple '(x) '(x))))

(bench "full-pipeline: DFS single-fact x2000"
  (for ([_ (in-range 2000)])
    (solve-goal dfs-config simple-store 'simple '(x) '(x))))

;; ============================================================
;; Optimization candidates: pre-allocated network + context
;; ============================================================
;; What if we reuse the solver-context across queries?
;; (Not currently possible — each solve creates fresh context)

(define pre-net (make-prop-network 1000000))
(define-values (pre-net-ctx pre-ctx) (make-solver-context pre-net))

;; Phase R1: pre-allocated context also needs store/config cells
(define pre-net-r1 (net-cell-write (net-cell-write pre-net relation-store-cell-id simple-store)
                                    config-cell-id atms-config))
(define-values (pre-net-ctx-r1 pre-ctx-r1) (make-solver-context pre-net-r1))

(bench "reuse-ctx: build-var-env + install + quiesce x2000"
  (for ([_ (in-range 2000)])
    ;; Start from pre-allocated context (skip steps 1-2)
    (define-values (net1 query-env) (build-var-env pre-net-ctx-r1 '(x)))
    (define-values (net2 answer-cid) (net-new-cell net1 '() (lambda (a b) (append a b))))
    (define top-goal (goal-desc 'app (list 'simple '(x))))
    (define net3 (install-goal-propagator net2 top-goal query-env answer-cid pre-ctx-r1))
    (run-to-quiescence net3)))
