#lang racket/base

;; ========================================================================
;; PM Track 8F Pre-0: Comprehensive Meta-Variable Lifecycle Benchmarks
;; ========================================================================
;;
;; Measures the complete meta-variable lifecycle to inform the metas-as-cells
;; design. Covers: creation, solve, read, zonk, and adversarial cases.
;;
;; Key discovery to validate: meta-solution ALREADY reads from cells (line 1963
;; of metavar-store.rkt). The CHAMP path is fallback-only. But the cell read
;; goes through champ-lookup-worldview on the id-map + elab-cell-read on the
;; cell CHAMP. Is this already fast enough, or do we need a cheaper path?

(require racket/match
         racket/list
         "../../syntax.rkt"
         "../../metavar-store.rkt"
         "../../elaborator-network.rkt"
         "../../elab-network-types.rkt"
         "../../propagator.rkt"
         "../../type-lattice.rkt"
         "../../zonk.rkt"
         "../../driver.rkt"
         "../../namespace.rkt"
         "../../tests/test-support.rkt")

;; ========================================
;; Setup: create an elaboration environment with network
;; ========================================

;; We need the full driver infrastructure for cells to work.
;; Use the test-support pattern: load prelude once, reuse env.

(define (with-elab-env thunk)
  (parameterize ([current-module-registry prelude-module-registry])
    (with-fresh-meta-env
      (thunk))))

;; ========================================
;; A. Isolated operation costs
;; ========================================

(define (bench label thunk n)
  (collect-garbage)
  (collect-garbage)
  (define t0 (current-inexact-monotonic-milliseconds))
  (for ([_ (in-range n)])
    (thunk))
  (define elapsed-us (* (- (current-inexact-monotonic-milliseconds) t0) 1000))
  (define per-call-ns (* (/ elapsed-us n) 1000))
  (printf "  ~a: ~a ns/call (~a calls)\n" label (exact->inexact (round per-call-ns)) n))

(printf "\n=== PM Track 8F Pre-0: Meta-Variable Lifecycle Benchmarks ===\n")

;; --- A1: fresh-meta creation cost ---
(printf "\n--- A1: fresh-meta creation ---\n")
(define N-create 10000)
(with-elab-env
  (lambda ()
    (bench "fresh-meta (with network)"
           (lambda ()
             (fresh-meta '() (expr-Int) 'bench))
           N-create)))

;; --- A2: solve-meta! cost ---
(printf "\n--- A2: solve-meta! ---\n")
(define N-solve 5000)
(with-elab-env
  (lambda ()
    ;; Create metas first, then solve them
    (define metas
      (for/list ([_ (in-range N-solve)])
        (fresh-meta '() (expr-Int) 'bench)))
    (bench "solve-meta! (with network + resolution)"
           (let ([i 0])
             (lambda ()
               (when (< i N-solve)
                 (define m (list-ref metas i))
                 (solve-meta! (expr-meta-id m) (expr-Int))
                 (set! i (add1 i)))))
           N-solve)))

;; --- A3: meta-solution read cost ---
(printf "\n--- A3: meta-solution read ---\n")
(define N-read 50000)
(with-elab-env
  (lambda ()
    ;; Create and solve a meta, then read it repeatedly
    (define m (fresh-meta '() (expr-Int) 'bench))
    (solve-meta! (expr-meta-id m) (expr-Int))
    (define id (expr-meta-id m))
    (bench "meta-solution (solved, cell path)"
           (lambda () (meta-solution id))
           N-read)
    ;; Also read an unsolved meta
    (define m2 (fresh-meta '() (expr-Int) 'bench))
    (define id2 (expr-meta-id m2))
    (bench "meta-solution (unsolved, cell path)"
           (lambda () (meta-solution id2))
           N-read)))

;; --- A3b: meta-solution/cell-id (PM 8F fast path) ---
(printf "\n--- A3b: meta-solution/cell-id (fast path) ---\n")
(with-elab-env
  (lambda ()
    (define m (fresh-meta '() (expr-Int) 'bench))
    (define id (expr-meta-id m))
    (define cell-id (expr-meta-cell-id m))
    (solve-meta! id (expr-Int))
    (bench "meta-solution/cell-id (solved, direct cell)"
           (lambda () (meta-solution/cell-id cell-id id))
           N-read)
    (define m2 (fresh-meta '() (expr-Int) 'bench))
    (define id2 (expr-meta-id m2))
    (define cell-id2 (expr-meta-cell-id m2))
    (bench "meta-solution/cell-id (unsolved, direct cell)"
           (lambda () (meta-solution/cell-id cell-id2 id2))
           N-read)))

;; --- A4: prop-meta-id->cell-id cost ---
(printf "\n--- A4: prop-meta-id->cell-id ---\n")
(with-elab-env
  (lambda ()
    (define m (fresh-meta '() (expr-Int) 'bench))
    (define id (expr-meta-id m))
    (bench "prop-meta-id->cell-id"
           (lambda () (prop-meta-id->cell-id id))
           N-read)))

;; --- A5: raw cell read cost (net-cell-read) ---
(printf "\n--- A5: raw cell read ---\n")
(with-elab-env
  (lambda ()
    (define m (fresh-meta '() (expr-Int) 'bench))
    (solve-meta! (expr-meta-id m) (expr-Int))
    (define cid (prop-meta-id->cell-id (expr-meta-id m)))
    (define net-box (current-prop-net-box))
    (bench "elab-cell-read (direct)"
           (lambda ()
             (elab-cell-read (unbox net-box) cid))
           N-read)
    ;; Also measure the unbox cost separately
    (bench "unbox net-box"
           (lambda () (unbox net-box))
           N-read)))

;; ========================================
;; B. Zonk costs on representative expressions
;; ========================================

(printf "\n--- B: zonk costs ---\n")
(define N-zonk 10000)

;; B1: Ground expression (no metas) — measures "unnecessary" zonk overhead
(bench "zonk ground (Pi Int Bool)"
       (lambda () (zonk (expr-Pi 'mw (expr-Int) (expr-Bool))))
       N-zonk)

;; B2: Expression with 1 solved meta
(with-elab-env
  (lambda ()
    (define m1 (fresh-meta '() (expr-Int) 'bench))
    (solve-meta! (expr-meta-id m1) (expr-Int))
    (define test-expr (expr-Pi 'mw m1 (expr-Bool)))
    (bench "zonk 1 solved meta (Pi ?X Bool, ?X=Int)"
           (lambda () (zonk test-expr))
           N-zonk)))

;; B3: Expression with 5 solved metas
(with-elab-env
  (lambda ()
    (define ms
      (for/list ([_ (in-range 5)])
        (define m (fresh-meta '() (expr-Int) 'bench))
        (solve-meta! (expr-meta-id m) (expr-Int))
        m))
    (define test-expr
      (expr-Pi 'mw (list-ref ms 0)
               (expr-Pi 'mw (list-ref ms 1)
                        (expr-Pi 'mw (list-ref ms 2)
                                 (expr-app (list-ref ms 3) (list-ref ms 4))))))
    (bench "zonk 5 solved metas (nested Pi + app)"
           (lambda () (zonk test-expr))
           N-zonk)))

;; B4: Deep expression (10-level Pi, metas at leaves)
(with-elab-env
  (lambda ()
    (define (make-deep-meta-pi depth)
      (if (= depth 0)
          (let ([m (fresh-meta '() (expr-Int) 'bench)])
            (solve-meta! (expr-meta-id m) (expr-Int))
            m)
          (expr-Pi 'mw (make-deep-meta-pi (- depth 1))
                   (make-deep-meta-pi (- depth 1)))))
    (define test-expr (make-deep-meta-pi 5))  ;; 2^5 = 32 metas
    (bench "zonk deep (5-level Pi tree, 32 metas)"
           (lambda () (zonk test-expr))
           (quotient N-zonk 10))))

;; B5: zonk-at-depth vs zonk comparison
(with-elab-env
  (lambda ()
    (define m (fresh-meta '() (expr-Int) 'bench))
    (solve-meta! (expr-meta-id m) (expr-Int))
    (define test-expr (expr-Pi 'mw m (expr-Bool)))
    (bench "zonk-at-depth 0 (same as zonk)"
           (lambda () (zonk-at-depth 0 test-expr))
           N-zonk)
    (bench "zonk-at-depth 3 (under 3 binders)"
           (lambda () (zonk-at-depth 3 test-expr))
           N-zonk)))

;; B6: zonk-final (includes default-metas)
(with-elab-env
  (lambda ()
    (define m (fresh-meta '() (expr-Int) 'bench))
    (solve-meta! (expr-meta-id m) (expr-Int))
    ;; Also create some unsolved level/mult metas
    (define test-expr (expr-Pi 'mw m (expr-Bool)))
    (bench "zonk-final (solved meta + defaults)"
           (lambda () (zonk-final test-expr))
           N-zonk)))

;; ========================================
;; C. Adversarial tests
;; ========================================

(printf "\n--- C: adversarial ---\n")

;; C1: 100 metas in one expression
(with-elab-env
  (lambda ()
    (define ms
      (for/list ([_ (in-range 100)])
        (define m (fresh-meta '() (expr-Int) 'bench))
        (solve-meta! (expr-meta-id m) (expr-Int))
        m))
    ;; Build a left-leaning app chain: (app (app (app ... m0) m1) m2)
    (define test-expr
      (for/fold ([e (car ms)]) ([m (cdr ms)])
        (expr-app e m)))
    (bench "zonk 100-meta app chain"
           (lambda () (zonk test-expr))
           1000)))

;; C2: Deep meta chain (meta→meta→meta→...→ground)
(with-elab-env
  (lambda ()
    ;; Create a chain: m1 solved to m2, m2 solved to m3, ... m10 solved to Int
    (define chain-metas
      (for/list ([_ (in-range 10)])
        (fresh-meta '() (expr-Int) 'bench)))
    ;; Solve chain: m_i → m_{i+1}
    (for ([i (in-range 9)])
      (solve-meta! (expr-meta-id (list-ref chain-metas i))
                   (list-ref chain-metas (+ i 1))))
    ;; Final: m_10 → Int
    (solve-meta! (expr-meta-id (list-ref chain-metas 9)) (expr-Int))
    ;; Zonk the first meta — must follow 10-deep chain
    (define test-expr (car chain-metas))
    (bench "zonk 10-deep meta chain (meta→meta→...→Int)"
           (lambda () (zonk test-expr))
           N-zonk)))

;; C3: Large expression with few metas (measures wasted tree walking)
(with-elab-env
  (lambda ()
    (define m (fresh-meta '() (expr-Int) 'bench))
    (solve-meta! (expr-meta-id m) (expr-Int))
    ;; Build a large ground expression with 1 meta at the deepest leaf
    (define (make-large depth)
      (if (= depth 0) m
          (expr-Pi 'mw (expr-Pi 'mw (expr-Int) (expr-Bool))
                   (make-large (- depth 1)))))
    (define test-expr (make-large 10))
    (bench "zonk large expr with 1 meta at depth 10"
           (lambda () (zonk test-expr))
           (quotient N-zonk 5))))

;; C4: bvar-containing solution probe (Phase 2 critical risk)
(printf "\n--- C4: bvar-in-cell risk probe ---\n")
(with-elab-env
  (lambda ()
    ;; Create a meta and solve it with a bvar-containing expression
    (define m (fresh-meta '() (expr-Int) 'bench))
    (define id (expr-meta-id m))
    ;; Solve with an expression containing bvar 0
    (solve-meta! id (expr-bvar 0))
    ;; Read from cell
    (define cid (prop-meta-id->cell-id id))
    (define net-box (current-prop-net-box))
    (define cell-val (elab-cell-read (unbox net-box) cid))
    (printf "  bvar-solution cell value: ~a\n" cell-val)
    (printf "  contains bvar? ~a\n" (expr-bvar? cell-val))
    (printf "  bvar index: ~a\n" (if (expr-bvar? cell-val) (expr-bvar-index cell-val) "N/A"))
    ;; Now test: what does meta-solution return?
    (define sol (meta-solution id))
    (printf "  meta-solution: ~a\n" sol)
    ;; Read at different "depths" — if this were a real scenario, the
    ;; bvar(0) at depth 1 should be bvar(1), but cell reads don't shift.
    (printf "  RISK: cell value is bvar(0) regardless of read depth!\n")
    (printf "  This confirms the Phase 2 bvar risk.\n")))

;; ========================================
;; D. Frequency estimation (single-command sample)
;; ========================================

(printf "\n--- D: frequency estimation ---\n")
;; Process a simple command and count meta operations
;; We'd need perf counters for this — check if they exist
(printf "  (Frequency counters require instrumented run via process-string)\n")
(printf "  Use perf-counter infrastructure from performance-counters.rkt\n")
(printf "  Existing: perf-meta-created-count, perf-unify-count\n")

;; ========================================
;; E. PPN 4C Addendum Step 2 A/B: compound-cell vs per-cell access
;; ========================================
;;
;; Measures the core tradeoff for the PU refactor:
;;   per-cell  — current state (each meta has its own cell)
;;   compound  — Step 2 state (one compound cell per domain; metas as
;;               components keyed by meta-id in a hasheq)
;;
;; Validates §5 hypotheses in 2026-04-23_STEP2_BASELINE.md:
;;   - Meta-read may slightly regress (hash-ref + tagged-cell-read vs direct cell-read)
;;   - Compound write should be competitive or faster than per-cell write
;;     (hasheq-insert into existing compound cell vs net-new-cell allocation)
;;
;; These micros can be run PRE- and POST- Step 2 migration for direct A/B.

(require "../../decision-cell.rkt"  ;; compound-tagged-merge, tagged-cell-value
         "../../type-lattice.rkt"   ;; type-unify-or-top, type-bot
         "../../meta-universe.rkt") ;; compound-cell-component-ref

(printf "\n--- E: PPN 4C Step 2 A/B compound-vs-per-cell ---\n")

;; E1: Compound-tagged-merge cost — hasheq pointwise merge with per-component tagged merge.
;; Synthesize two hasheqs with N overlapping meta-id keys; measure merge cost.
(define N-merge 1000)
(define merge-fn (compound-tagged-merge type-unify-or-top))

(for ([N (in-list '(10 50 100 500))])
  (define (mk-hasheq n)
    (for/fold ([h (hasheq)]) ([i (in-range n)])
      (hash-set h i (tagged-cell-value (expr-Int) '()))))
  (define h1 (mk-hasheq N))
  (define h2 (mk-hasheq N))
  (collect-garbage) (collect-garbage)
  (define t0 (current-inexact-monotonic-milliseconds))
  (for ([_ (in-range N-merge)]) (merge-fn h1 h2))
  (define elapsed-us (* (- (current-inexact-monotonic-milliseconds) t0) 1000))
  (define per-call-ns (* (/ elapsed-us N-merge) 1000))
  (printf "  compound-tagged-merge (~a overlapping keys): ~a ns/call\n"
          N (exact->inexact (round per-call-ns))))

;; E2: hash-ref into compound-cell value (simulates compound-cell-component-ref's hot path).
(printf "  --- E2: hash-ref into compound-cell value (component access hot path) ---\n")
(for ([N (in-list '(10 50 100 500))])
  (define h (for/fold ([h (hasheq)]) ([i (in-range N)])
              (hash-set h i (tagged-cell-value (expr-Int) '()))))
  ;; Pick a middle key to lookup; access repeatedly
  (define k (quotient N 2))
  (collect-garbage) (collect-garbage)
  (define N-iter 100000)
  (define t0 (current-inexact-monotonic-milliseconds))
  (for ([_ (in-range N-iter)]) (hash-ref h k #f))
  (define elapsed-us (* (- (current-inexact-monotonic-milliseconds) t0) 1000))
  (define per-call-ns (* (/ elapsed-us N-iter) 1000))
  (printf "  hash-ref into ~a-key hasheq: ~a ns/call\n"
          N (exact->inexact (round per-call-ns))))

;; E3: hash-set into compound-cell value (simulates per-component write).
(printf "  --- E3: hash-set into compound-cell value (component write) ---\n")
(for ([N (in-list '(10 50 100 500))])
  (define h (for/fold ([h (hasheq)]) ([i (in-range N)])
              (hash-set h i (tagged-cell-value (expr-Int) '()))))
  (define new-val (tagged-cell-value (expr-Bool) '()))
  (collect-garbage) (collect-garbage)
  (define N-iter 50000)
  (define t0 (current-inexact-monotonic-milliseconds))
  (for ([_ (in-range N-iter)]) (hash-set h (quotient N 2) new-val))
  (define elapsed-us (* (- (current-inexact-monotonic-milliseconds) t0) 1000))
  (define per-call-ns (* (/ elapsed-us N-iter) 1000))
  (printf "  hash-set into ~a-key hasheq (overwrite existing): ~a ns/call\n"
          N (exact->inexact (round per-call-ns))))

;; E4: compound-cell-component-ref (the full helper including elab-cell-read).
;; Uses the real helper function against an initialized universe cell.
(printf "  --- E4: compound-cell-component-ref full helper (includes elab-cell-read) ---\n")
(with-elab-env
  (lambda ()
    ;; Initialize meta universes on the current network
    (define net-box (current-prop-net-box))
    (when net-box
      (define enet (unbox net-box))
      (define enet* (init-meta-universes! enet))
      (set-box! net-box enet*)
      ;; Now populate the type-meta-universe with some metas
      (for ([N-metas (in-list '(10 50 100 500))])
        (define enet-current (unbox net-box))
        (define type-cid (current-type-meta-universe-cell-id))
        ;; Build a hasheq with N-metas entries
        (define compound-val
          (for/fold ([h (hasheq)]) ([i (in-range N-metas)])
            (hash-set h i (tagged-cell-value (expr-Int) '()))))
        ;; Write it to the universe cell
        (define enet-with-data (elab-cell-write enet-current type-cid compound-val))
        (set-box! net-box enet-with-data)
        ;; Now benchmark reading a component
        (define key (quotient N-metas 2))
        (collect-garbage) (collect-garbage)
        (define N-iter 50000)
        (define t0 (current-inexact-monotonic-milliseconds))
        (for ([_ (in-range N-iter)])
          (compound-cell-component-ref (unbox net-box) type-cid key))
        (define elapsed-us (* (- (current-inexact-monotonic-milliseconds) t0) 1000))
        (define per-call-ns (* (/ elapsed-us N-iter) 1000))
        (printf "  compound-cell-component-ref (universe with ~a metas): ~a ns/call\n"
                N-metas (exact->inexact (round per-call-ns)))))))

;; E5: Baseline — direct elab-cell-read cost (for comparison with E4).
;; This is the "per-cell" baseline: reading from a dedicated per-meta cell.
(printf "  --- E5: baseline elab-cell-read on a dedicated meta cell (pre-Step-2 path) ---\n")
(with-elab-env
  (lambda ()
    (define m (fresh-meta '() (expr-Int) 'bench))
    (define cid (prop-meta-id->cell-id (expr-meta-id m)))
    (define net-box (current-prop-net-box))
    (collect-garbage) (collect-garbage)
    (define N-iter 50000)
    (define t0 (current-inexact-monotonic-milliseconds))
    (for ([_ (in-range N-iter)]) (elab-cell-read (unbox net-box) cid))
    (define elapsed-us (* (- (current-inexact-monotonic-milliseconds) t0) 1000))
    (define per-call-ns (* (/ elapsed-us N-iter) 1000))
    (printf "  elab-cell-read (per-meta cell): ~a ns/call\n"
            (exact->inexact (round per-call-ns)))))

(printf "\n  NOTE: E4 ≥ E5 is EXPECTED. compound-cell-component-ref adds\n")
(printf "        hash-ref to the elab-cell-read cost. The tradeoff: E4's path\n")
(printf "        uses ONE cell for N metas; E5's path uses N cells. Allocation\n")
(printf "        cost (not measured here) dominates in real workloads.\n")

(printf "\n=== Done ===\n")
