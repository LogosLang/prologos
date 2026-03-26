#lang racket/base

;; ========================================================================
;; PM Track 10B: Foundation Cleanup + Zonk Elimination — Micro-Benchmarks
;; ========================================================================
;;
;; Measures the costs that Track 10B aims to reduce or eliminate:
;;   A. Foundation costs (with-fresh-meta-env, make-prop-network, CHAMP fallback)
;;   B. Zonk hot-path costs (ground, solved, at-depth, session)
;;   C. Adversarial tests (GC pressure, deep trees, dead code)
;;   D. Aggregate suite instrumentation (process-string phase timing)
;;
;; Run from racket/prologos/:
;;   "/Applications/Racket v9.0/bin/racket" benchmarks/micro/bench-track10b-foundation.rkt

(require racket/match
         racket/list
         "../../syntax.rkt"
         "../../metavar-store.rkt"
         "../../propagator.rkt"
         "../../elab-network-types.rkt"
         "../../elaborator-network.rkt"
         "../../zonk.rkt"
         "../../reduction.rkt"
         "../../champ.rkt"
         "../../driver.rkt"
         "../../namespace.rkt"
         "../../performance-counters.rkt"
         "../../tests/test-support.rkt")

;; ========================================
;; Bench macro
;; ========================================

(define-syntax-rule (bench label iters body ...)
  (let ()
    (collect-garbage) (collect-garbage)
    (define start (current-inexact-milliseconds))
    (for ([_ (in-range iters)])
      body ...)
    (define elapsed (- (current-inexact-milliseconds) start))
    (printf "  ~a: ~a ns/call (~a calls, ~a ms total)\n"
            label
            (exact->inexact (/ (* elapsed 1000000) iters))
            iters
            (exact->inexact elapsed))))

;; ========================================
;; Helper: elab env (full driver infrastructure)
;; ========================================

(define (with-elab-env thunk)
  (parameterize ([current-module-registry prelude-module-registry])
    (with-fresh-meta-env
      (thunk))))

;; Accumulator for summary comparisons
(define summary-data (make-hasheq))
(define (record! key ns/call)
  (hash-set! summary-data key ns/call))

;; ========================================================================
;; A. WS-A: Foundation Costs
;; ========================================================================

(printf "\n========================================================================\n")
(printf "A. WS-A: Foundation Costs\n")
(printf "========================================================================\n")

;; --- A1: make-prop-network (empty, no cells) ---
(printf "\n--- A1: make-prop-network (empty, no cells) ---\n")
(let ()
  (collect-garbage) (collect-garbage)
  (define N 10000)
  (define start (current-inexact-milliseconds))
  (for ([_ (in-range N)])
    (make-prop-network))
  (define elapsed (- (current-inexact-milliseconds) start))
  (define ns/call (exact->inexact (/ (* elapsed 1000000) N)))
  (printf "  make-prop-network: ~a ns/call (~a calls, ~a ms total)\n"
          ns/call N (exact->inexact elapsed))
  (record! 'A1-make-prop-network ns/call))

;; --- A2: 277 sequential make-prop-network (simulating one suite run) ---
(printf "\n--- A2: 277 sequential make-prop-network (suite simulation) ---\n")
(let ()
  (define BATCHES 10)
  (define PER-BATCH 277)
  (collect-garbage) (collect-garbage)
  (define start (current-inexact-milliseconds))
  (for ([_ (in-range BATCHES)])
    (for ([_ (in-range PER-BATCH)])
      (make-prop-network)))
  (define elapsed (- (current-inexact-milliseconds) start))
  (define total-calls (* BATCHES PER-BATCH))
  (define ns/call (exact->inexact (/ (* elapsed 1000000) total-calls)))
  (define ms/batch (exact->inexact (/ elapsed BATCHES)))
  (printf "  per-call: ~a ns/call (~a total calls)\n" ns/call total-calls)
  (printf "  per-batch (277 calls): ~a ms/batch (~a batches, ~a ms total)\n"
          ms/batch BATCHES (exact->inexact elapsed))
  (record! 'A2-per-call ns/call))

;; --- A3: CHAMP fallback check cost ---
(printf "\n--- A3: CHAMP fallback check cost ---\n")
(let ()
  (define N 100000)
  ;; Case 1: box is #f (no fallback needed)
  (let ([b (box #f)])
    (bench "fallback check (box #f — fast path)" N
      (and (unbox b) (unbox b))))

  ;; Case 2: box holds a CHAMP (fallback active)
  (let ([b (box champ-empty)])
    (bench "fallback check (box champ — slow path)" N
      (and (unbox b) (unbox b))))

  ;; Record approximate ns/call for comparison (use box #f case)
  (collect-garbage) (collect-garbage)
  (let ([b (box #f)])
    (define start (current-inexact-milliseconds))
    (for ([_ (in-range N)])
      (and (unbox b) (unbox b)))
    (define elapsed (- (current-inexact-milliseconds) start))
    (record! 'A3-fallback-check (exact->inexact (/ (* elapsed 1000000) N)))))

;; --- A4: zonk-final on a real expression ---
(printf "\n--- A4: zonk-final on real expression ---\n")
(with-handlers ([exn:fail?
                 (lambda (e)
                   (printf "  SKIPPED: zonk-final real expr — ~a\n"
                           (exn-message e)))])
  (with-elab-env
    (lambda ()
      ;; Create a representative expression: Pi with a solved meta
      (define m (fresh-meta '() (expr-Int) 'bench))
      (solve-meta! (expr-meta-id m) (expr-Int))
      (define test-expr (expr-Pi 'mw m (expr-Bool)))
      (define N 1000)
      (collect-garbage) (collect-garbage)
      (define start (current-inexact-milliseconds))
      (for ([_ (in-range N)])
        (zonk-final test-expr))
      (define elapsed (- (current-inexact-milliseconds) start))
      (define ns/call (exact->inexact (/ (* elapsed 1000000) N)))
      (printf "  zonk-final (Pi ?X Bool, ?X=Int): ~a ns/call (~a calls, ~a ms total)\n"
              ns/call N (exact->inexact elapsed))
      (record! 'A4-zonk-final ns/call))))

;; --- A5: freeze comparison ---
;; Note: zonk.rkt exports zonk, zonk-ctx, zonk-final, zonk-at-depth.
;; There is no standalone "freeze" function in zonk.rkt. expr-table-freeze
;; is an AST node, not a function. SKIPPED.
(printf "\n--- A5: freeze ---\n")
(printf "  SKIPPED: No standalone 'freeze' function exported from zonk.rkt.\n")
(printf "  (expr-table-freeze is an AST node, not a zonk variant.)\n")

;; --- A6: prop-meta-id->cell-id lookup frequency ---
(printf "\n--- A6: prop-meta-id->cell-id lookup cost ---\n")
(with-handlers ([exn:fail?
                 (lambda (e)
                   (printf "  SKIPPED: prop-meta-id->cell-id — ~a\n"
                           (exn-message e)))])
  (with-elab-env
    (lambda ()
      ;; Create 10 metas, solve them
      (define metas
        (for/list ([_ (in-range 10)])
          (define m (fresh-meta '() (expr-Int) 'bench))
          (solve-meta! (expr-meta-id m) (expr-Int))
          m))
      (define ids (map expr-meta-id metas))
      (define N 10000)
      ;; Time prop-meta-id->cell-id across all 10 ids
      (collect-garbage) (collect-garbage)
      (define start (current-inexact-milliseconds))
      (for ([_ (in-range N)])
        (for ([id (in-list ids)])
          (prop-meta-id->cell-id id)))
      (define elapsed (- (current-inexact-milliseconds) start))
      (define total-lookups (* N 10))
      (define ns/call (exact->inexact (/ (* elapsed 1000000) total-lookups)))
      (printf "  prop-meta-id->cell-id: ~a ns/call (~a lookups, ~a ms total)\n"
              ns/call total-lookups (exact->inexact elapsed))
      (record! 'A6-id-map-lookup ns/call)

      ;; Compare: direct cell-id from expr-meta (the fast path that eliminates id-map)
      (define cell-ids (map expr-meta-cell-id metas))
      (collect-garbage) (collect-garbage)
      (define start2 (current-inexact-milliseconds))
      (for ([_ (in-range N)])
        (for ([cid (in-list cell-ids)])
          cid))  ; direct access — no lookup
      (define elapsed2 (- (current-inexact-milliseconds) start2))
      (define ns/call2 (exact->inexact (/ (* elapsed2 1000000) total-lookups)))
      (printf "  direct cell-id access (no lookup): ~a ns/call (~a accesses)\n"
              ns/call2 total-lookups)
      (printf "  Savings per lookup: ~a ns\n"
              (exact->inexact (- ns/call ns/call2))))))


;; ========================================================================
;; B. WS-B: Zonk Hot Path Costs
;; ========================================================================

(printf "\n========================================================================\n")
(printf "B. WS-B: Zonk Hot Path Costs\n")
(printf "========================================================================\n")

;; --- B1: zonk on ground expression ---
(printf "\n--- B1: zonk on ground expression (Pi Int Bool) ---\n")
(with-elab-env
  (lambda ()
    (define ground-expr (expr-Pi 'mw (expr-Int) (expr-Bool)))
    (define N 10000)
    (collect-garbage) (collect-garbage)
    (define start (current-inexact-milliseconds))
    (for ([_ (in-range N)])
      (zonk ground-expr))
    (define elapsed (- (current-inexact-milliseconds) start))
    (define ns/call (exact->inexact (/ (* elapsed 1000000) N)))
    (printf "  zonk ground (Pi Int Bool): ~a ns/call (~a calls, ~a ms total)\n"
            ns/call N (exact->inexact elapsed))
    (record! 'B1-zonk-ground ns/call)))

;; --- B2: zonk with 1 solved meta ---
(printf "\n--- B2: zonk with 1 solved meta (Pi ?X Bool, ?X=Int) ---\n")
(with-elab-env
  (lambda ()
    (define m (fresh-meta '() (expr-Int) 'bench))
    (solve-meta! (expr-meta-id m) (expr-Int))
    (define test-expr (expr-Pi 'mw m (expr-Bool)))
    (define N 10000)
    (collect-garbage) (collect-garbage)
    (define start (current-inexact-milliseconds))
    (for ([_ (in-range N)])
      (zonk test-expr))
    (define elapsed (- (current-inexact-milliseconds) start))
    (define ns/call (exact->inexact (/ (* elapsed 1000000) N)))
    (printf "  zonk 1 meta (Pi ?X Bool): ~a ns/call (~a calls, ~a ms total)\n"
            ns/call N (exact->inexact elapsed))
    (record! 'B2-zonk-1meta ns/call)))

;; --- B3: zonk-at-depth 0 on same expression ---
(printf "\n--- B3: zonk-at-depth 0 (same expression as B2) ---\n")
(with-elab-env
  (lambda ()
    (define m (fresh-meta '() (expr-Int) 'bench))
    (solve-meta! (expr-meta-id m) (expr-Int))
    (define test-expr (expr-Pi 'mw m (expr-Bool)))
    (define N 10000)
    (collect-garbage) (collect-garbage)
    (define start (current-inexact-milliseconds))
    (for ([_ (in-range N)])
      (zonk-at-depth 0 test-expr))
    (define elapsed (- (current-inexact-milliseconds) start))
    (define ns/call (exact->inexact (/ (* elapsed 1000000) N)))
    (printf "  zonk-at-depth 0 (Pi ?X Bool): ~a ns/call (~a calls, ~a ms total)\n"
            ns/call N (exact->inexact elapsed))
    (record! 'B3-zonk-at-depth-0 ns/call)))

;; --- B4: zonk-at-depth 1 on Pi codomain with solved meta ---
(printf "\n--- B4: zonk-at-depth 1 (Pi codomain with meta) ---\n")
(with-elab-env
  (lambda ()
    (define m (fresh-meta '() (expr-Int) 'bench))
    (solve-meta! (expr-meta-id m) (expr-Int))
    ;; Pi(Int, Pi(?X, Bool)) — meta is in codomain at depth 1
    (define test-expr (expr-Pi 'mw (expr-Int)
                               (expr-Pi 'mw m (expr-Bool))))
    (define N 5000)
    (collect-garbage) (collect-garbage)
    (define start (current-inexact-milliseconds))
    (for ([_ (in-range N)])
      (zonk-at-depth 1 test-expr))
    (define elapsed (- (current-inexact-milliseconds) start))
    (define ns/call (exact->inexact (/ (* elapsed 1000000) N)))
    (printf "  zonk-at-depth 1 (Pi Int (Pi ?X Bool)): ~a ns/call (~a calls, ~a ms total)\n"
            ns/call N (exact->inexact elapsed))
    (record! 'B4-zonk-at-depth-1 ns/call)))

;; --- B5: zonk-session ---
;; zonk-session is internal to typing-sessions.rkt (not exported via provide).
(printf "\n--- B5: zonk-session ---\n")
(printf "  SKIPPED: zonk-session is not exported from typing-sessions.rkt.\n")
(printf "  It is an internal function used within session type checking.\n")


;; ========================================================================
;; C. Adversarial Tests
;; ========================================================================

(printf "\n========================================================================\n")
(printf "C. Adversarial Tests\n")
(printf "========================================================================\n")

;; --- C1: 277 with-fresh-meta-env + make-prop-network (GC pressure) ---
(printf "\n--- C1: 277 with-fresh-meta-env (full pattern, GC measurement) ---\n")
(let ()
  (define ITERS 5)
  (define PER-ITER 277)
  (collect-garbage) (collect-garbage)
  (define gc-before (current-gc-milliseconds))
  (define start (current-inexact-milliseconds))
  (for ([_ (in-range ITERS)])
    (for ([_ (in-range PER-ITER)])
      (parameterize ([current-module-registry prelude-module-registry])
        (with-fresh-meta-env
          ;; Simulate minimal command work: create a meta, solve it
          (define m (fresh-meta '() (expr-Int) 'bench))
          (solve-meta! (expr-meta-id m) (expr-Int))
          (void)))))
  (define elapsed (- (current-inexact-milliseconds) start))
  (define gc-after (current-gc-milliseconds))
  (define gc-elapsed (- gc-after gc-before))
  (define total (exact->inexact (* ITERS PER-ITER)))
  (printf "  Total: ~a ms for ~a with-fresh-meta-env calls (~a batches of ~a)\n"
          (exact->inexact elapsed) (inexact->exact total) ITERS PER-ITER)
  (printf "  Per-call: ~a ms\n" (exact->inexact (/ elapsed total)))
  (printf "  GC time: ~a ms (~a% of total)\n"
          gc-elapsed
          (if (> elapsed 0)
              (exact->inexact (round (* 100 (/ gc-elapsed elapsed))))
              0))
  (record! 'C1-full-env-ns/call
           (exact->inexact (/ (* elapsed 1000000) total))))

;; --- C2: Deep expression tree zonk (10-level nested Pi with metas) ---
(printf "\n--- C2: Deep expression tree zonk (10-level Pi, metas at each level) ---\n")
(with-handlers ([exn:fail?
                 (lambda (e)
                   (printf "  SKIPPED: deep tree zonk — ~a\n" (exn-message e)))])
  (with-elab-env
    (lambda ()
      ;; Build a 10-level nested Pi with a solved meta at each level
      (define (make-deep-pi depth)
        (if (= depth 0)
            (expr-Int)
            (let ([m (fresh-meta '() (expr-Int) 'bench)])
              (solve-meta! (expr-meta-id m) (expr-Int))
              (expr-Pi 'mw m (make-deep-pi (- depth 1))))))
      (define deep-expr (make-deep-pi 10))
      (define N 500)
      (collect-garbage) (collect-garbage)
      (define start (current-inexact-milliseconds))
      (for ([_ (in-range N)])
        (zonk deep-expr))
      (define elapsed (- (current-inexact-milliseconds) start))
      (define ns/call (exact->inexact (/ (* elapsed 1000000) N)))
      (printf "  zonk deep 10-level Pi (10 metas): ~a ns/call (~a calls, ~a ms total)\n"
              ns/call N (exact->inexact elapsed))
      (record! 'C2-deep-zonk ns/call))))

;; --- C3: cell-id path vs id-map path comparison ---
(printf "\n--- C3: cell-id fast path vs id-map path for meta-solution ---\n")
(with-handlers ([exn:fail?
                 (lambda (e)
                   (printf "  SKIPPED: cell-id vs id-map — ~a\n" (exn-message e)))])
  (with-elab-env
    (lambda ()
      ;; Create metas and solve them
      (define metas
        (for/list ([_ (in-range 10)])
          (define m (fresh-meta '() (expr-Int) 'bench))
          (solve-meta! (expr-meta-id m) (expr-Int))
          m))
      (define ids (map expr-meta-id metas))
      (define cell-ids (map expr-meta-cell-id metas))
      (define N 50000)

      ;; Path A: meta-solution (goes through id-map -> cell-id -> cell read)
      (collect-garbage) (collect-garbage)
      (define start-a (current-inexact-milliseconds))
      (for ([_ (in-range N)])
        (for ([id (in-list ids)])
          (meta-solution id)))
      (define elapsed-a (- (current-inexact-milliseconds) start-a))
      (define total-ops (* N 10))
      (define ns-a (exact->inexact (/ (* elapsed-a 1000000) total-ops)))
      (printf "  meta-solution (id-map path): ~a ns/call (~a ops)\n"
              ns-a total-ops)

      ;; Path B: meta-solution/cell-id (direct cell-id, skips id-map)
      (collect-garbage) (collect-garbage)
      (define start-b (current-inexact-milliseconds))
      (for ([_ (in-range N)])
        (for ([id (in-list ids)]
              [cid (in-list cell-ids)])
          (meta-solution/cell-id cid id)))
      (define elapsed-b (- (current-inexact-milliseconds) start-b))
      (define ns-b (exact->inexact (/ (* elapsed-b 1000000) total-ops)))
      (printf "  meta-solution/cell-id (direct): ~a ns/call (~a ops)\n"
              ns-b total-ops)
      (printf "  Savings per call: ~a ns (~a%)\n"
              (exact->inexact (- ns-a ns-b))
              (if (> ns-a 0)
                  (exact->inexact (round (* 100 (/ (- ns-a ns-b) ns-a))))
                  0))
      ;; ~39% savings = ~95ns per meta-solution call eliminated from id-map
      (record! 'C3-id-map-path ns-a)
      (record! 'C3-cell-id-path ns-b))))


;; ========================================================================
;; D. Aggregate Suite Instrumentation
;; ========================================================================

(printf "\n========================================================================\n")
(printf "D. Aggregate Suite Instrumentation\n")
(printf "========================================================================\n")

;; --- D1: process-string simple definition ---
(printf "\n--- D1: process-string (simple polymorphic def) ---\n")
(with-handlers ([exn:fail?
                 (lambda (e)
                   (printf "  SKIPPED: process-string — ~a\n" (exn-message e)))])
  (let ()
    (define N 5)
    (define timings '())
    (for ([i (in-range N)])
      (collect-garbage) (collect-garbage)
      (define start (current-inexact-milliseconds))
      (parameterize ([current-module-registry prelude-module-registry])
        (with-fresh-meta-env
          (process-string "(ns bench-d1)\n(def id {A : Type} [a : A] a)")))
      (define elapsed (- (current-inexact-milliseconds) start))
      (set! timings (cons elapsed timings)))
    (define avg (exact->inexact (/ (apply + timings) N)))
    (printf "  process-string (id: {A}[a] a): avg ~a ms over ~a runs\n" avg N)
    (printf "  Individual runs: ~a\n"
            (map (lambda (t) (exact->inexact (round t))) (reverse timings)))
    (record! 'D1-process-string-ms avg)))

;; --- D2: process-string complex definition (trait-constrained) ---
(printf "\n--- D2: process-string (trait-constrained def) ---\n")
(with-handlers ([exn:fail?
                 (lambda (e)
                   (printf "  SKIPPED: process-string complex — ~a\n" (exn-message e)))])
  (let ()
    (define N 5)
    (define program
      (string-append
       "(ns bench-d2)\n"
       "(def double {A : Type} {_ : Add A} [x : A] (add x x))\n"
       "(def triple {A : Type} {_ : Add A} [x : A] (add x (add x x)))\n"
       "(def quad {A : Type} {_ : Mul A} {_ : FromInt A} [x : A] (mul x (from-int 4)))"))
    (define timings '())
    (for ([i (in-range N)])
      (collect-garbage) (collect-garbage)
      (define start (current-inexact-milliseconds))
      (parameterize ([current-module-registry prelude-module-registry])
        (with-fresh-meta-env
          (process-string program)))
      (define elapsed (- (current-inexact-milliseconds) start))
      (set! timings (cons elapsed timings)))
    (define avg (exact->inexact (/ (apply + timings) N)))
    (printf "  process-string (3 trait defs): avg ~a ms over ~a runs\n" avg N)
    (printf "  Individual runs: ~a\n"
            (map (lambda (t) (exact->inexact (round t))) (reverse timings)))
    (record! 'D2-process-string-complex-ms avg)))


;; ========================================================================
;; Summary: Comparisons
;; ========================================================================

(printf "\n========================================================================\n")
(printf "SUMMARY: Key Comparisons for Track 10B\n")
(printf "========================================================================\n")

(define (get key) (hash-ref summary-data key #f))

;; Comparison 1: make-prop-network cost vs saved fallback-check cost
(printf "\n--- make-prop-network vs fallback check ---\n")
(let ([a1 (get 'A1-make-prop-network)]
      [a3 (get 'A3-fallback-check)])
  (if (and a1 a3)
      (begin
        (printf "  make-prop-network: ~a ns/call\n" a1)
        (printf "  fallback check:    ~a ns/call\n" a3)
        (printf "  Ratio: make-prop-network is ~ax the fallback check\n"
                (exact->inexact (round (/ a1 (max a3 0.001)))))
        (printf "  Interpretation: If fallback checks happen >>277 times per suite run,\n")
        (printf "    eliminating them saves more than the network creation overhead.\n"))
      (printf "  (incomplete data — some benchmarks skipped)\n")))

;; Comparison 2: zonk-final vs zonk (no freeze available)
(printf "\n--- zonk-final vs zonk ---\n")
(let ([a4 (get 'A4-zonk-final)]
      [b2 (get 'B2-zonk-1meta)])
  (if (and a4 b2)
      (begin
        (printf "  zonk-final: ~a ns/call\n" a4)
        (printf "  zonk:       ~a ns/call\n" b2)
        (printf "  Overhead of zonk-final over zonk: ~a ns (~a%)\n"
                (exact->inexact (- a4 b2))
                (if (> b2 0)
                    (exact->inexact (round (* 100 (/ (- a4 b2) b2))))
                    0)))
      (printf "  (incomplete data — some benchmarks skipped)\n")))

;; Comparison 3: zonk vs zonk-at-depth 0
(printf "\n--- zonk vs zonk-at-depth 0 ---\n")
(let ([b2 (get 'B2-zonk-1meta)]
      [b3 (get 'B3-zonk-at-depth-0)])
  (if (and b2 b3)
      (begin
        (printf "  zonk:            ~a ns/call\n" b2)
        (printf "  zonk-at-depth 0: ~a ns/call\n" b3)
        (printf "  Overhead of at-depth: ~a ns (~a%)\n"
                (exact->inexact (- b3 b2))
                (if (> b2 0)
                    (exact->inexact (round (* 100 (/ (- b3 b2) b2))))
                    0)))
      (printf "  (incomplete data — some benchmarks skipped)\n")))

;; Comparison 4: cell-id fast path savings
(printf "\n--- cell-id fast path vs id-map path ---\n")
(let ([id-map (get 'C3-id-map-path)]
      [cell-id (get 'C3-cell-id-path)])
  (if (and id-map cell-id)
      (begin
        (printf "  id-map path:  ~a ns/call\n" id-map)
        (printf "  cell-id path: ~a ns/call\n" cell-id)
        (printf "  Savings: ~a ns/call (~a%)\n"
                (exact->inexact (- id-map cell-id))
                (if (> id-map 0)
                    (exact->inexact (round (* 100 (/ (- id-map cell-id) id-map))))
                    0)))
      (printf "  (incomplete data — some benchmarks skipped)\n")))

;; Estimated suite impact
(printf "\n--- Estimated suite impact ---\n")
(let ([env-ns (get 'C1-full-env-ns/call)]
      [d1 (get 'D1-process-string-ms)]
      [d2 (get 'D2-process-string-complex-ms)])
  (when env-ns
    (printf "  with-fresh-meta-env cost: ~a ns/call (~a ms/call)\n"
            env-ns (exact->inexact (/ env-ns 1000000))))
  (when d1
    (printf "  Simple def (process-string): ~a ms avg\n" d1))
  (when d2
    (printf "  Complex def (3 trait defs): ~a ms avg\n" d2))
  (printf "  277 test files × env creation cost = baseline overhead.\n")
  (printf "  Track 10B target: reduce zonk + fallback + id-map overhead.\n"))

(printf "\n========================================================================\n")
(printf "Done.\n")
