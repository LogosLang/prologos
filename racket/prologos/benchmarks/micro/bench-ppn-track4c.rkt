#lang racket/base

;;;
;;; PPN Track 4C Pre-0 Benchmarks: Elaboration Completely On-Network
;;;
;;; Establishes baselines BEFORE implementation for A/B comparison after 4C lands.
;;; Measures CURRENT 4B behavior along the 9 design axes.
;;;
;;; Tiers (modeled on bench-ppn-track4.rkt):
;;;   M1-M6:  Micro-benchmarks — per-operation costs touching 4C axes
;;;   A1-A4:  Adversarial tests — exercises that stress the 9 axes
;;;   E1-E6:  E2E baselines — realistic programs through full pipeline
;;;   V1-V3:  Validation — correctness reference points for parity harness
;;;
;;; Usage:
;;;   racket racket/prologos/benchmarks/micro/bench-ppn-track4c.rkt
;;;

(require racket/list
         racket/match
         racket/format
         racket/string
         racket/port
         "../../syntax.rkt"
         "../../type-lattice.rkt"
         "../../unify.rkt"
         "../../metavar-store.rkt"
         "../../elaborator-network.rkt"
         "../../performance-counters.rkt"
         "../../propagator.rkt"
         "../../reduction.rkt"
         "../../typing-core.rkt"
         "../../typing-propagators.rkt"
         "../../driver.rkt")

;; ============================================================
;; Timing infrastructure (borrowed from bench-ppn-track4.rkt)
;; ============================================================

(define-syntax-rule (bench label N-val body)
  (let ()
    (for ([_ (in-range 100)]) body)
    (define N N-val)
    (collect-garbage) (collect-garbage)
    (define start (current-inexact-milliseconds))
    (for ([_ (in-range N)]) body)
    (define end (current-inexact-milliseconds))
    (define mean-us (* 1000.0 (/ (- end start) N)))
    (printf "  ~a: ~a μs/call (~a calls)\n" label (~r mean-us #:precision '(= 3)) N)
    mean-us))

(define-syntax-rule (bench-ms label runs body)
  (let ()
    (for ([_ (in-range 3)]) body)
    (define times
      (for/list ([_ (in-range runs)])
        (collect-garbage)
        (define start (current-inexact-milliseconds))
        body
        (define end (current-inexact-milliseconds))
        (- end start)))
    (define sorted (sort times <))
    (define med (list-ref sorted (quotient (length sorted) 2)))
    (define mn (apply min times))
    (define mx (apply max times))
    (printf "  ~a: median=~a ms  min=~a  max=~a  (n=~a)\n"
            label (~r med #:precision '(= 3))
            (~r mn #:precision '(= 3)) (~r mx #:precision '(= 3)) runs)
    med))

;; bench-mem: wall-clock + memory (allocation bytes, post-GC retained bytes, GC count)
;; Per DESIGN_METHODOLOGY.org "Measure before, during, AND after — and include memory cost"
(define-syntax-rule (bench-mem label runs body)
  (let ()
    (for ([_ (in-range 3)]) body)
    (define results
      (for/list ([_ (in-range runs)])
        (collect-garbage) (collect-garbage)
        (define mem-before (current-memory-use 'cumulative))
        (define retained-before (current-memory-use))
        (define start (current-inexact-milliseconds))
        body
        (define end (current-inexact-milliseconds))
        (define mem-after (current-memory-use 'cumulative))
        (collect-garbage)
        (define retained-after (current-memory-use))
        (vector (- end start)                     ;; wall-clock ms
                (- mem-after mem-before)           ;; allocated bytes
                (- retained-after retained-before)))) ;; retention delta bytes
    (define wall-times (for/list ([r results]) (vector-ref r 0)))
    (define alloc-bytes (for/list ([r results]) (vector-ref r 1)))
    (define retain-bytes (for/list ([r results]) (vector-ref r 2)))
    (define (med xs) (list-ref (sort xs <) (quotient (length xs) 2)))
    (printf "  ~a: wall=~a ms  alloc=~a KB  retain=~a KB  (n=~a)\n"
            label
            (~r (med wall-times) #:precision '(= 3))
            (~r (/ (med alloc-bytes) 1024.0) #:precision '(= 1))
            (~r (/ (med retain-bytes) 1024.0) #:precision '(= 1))
            runs)
    (vector (med wall-times) (med alloc-bytes) (med retain-bytes))))

(define (silent thunk)
  (with-output-to-string
    (lambda ()
      (parameterize ([current-error-port (current-output-port)])
        (thunk)))))

(define (with-fresh thunk)
  (with-fresh-meta-env
    (parameterize ([current-reduction-fuel (box 10000)])
      (thunk))))

;; ============================================================
;; M: MICRO-BENCHMARKS — Per-operation costs relevant to 4C
;; ============================================================

(displayln "\n=== M: MICRO-BENCHMARKS (per-operation baseline) ===\n")

;; M1: that-read/write on attribute-map (4C's per-facet access primitive)
(displayln "M1: attribute-map facet access (4C hot path)")
(define sample-map
  (hasheq 0 (hasheq ':type (expr-Nat)
                    ':context #f
                    ':usage '()
                    ':constraints #f
                    ':warnings '())))
(define m1a (bench "M1a that-read :type" 20000
  (that-read sample-map 0 ':type)))
(define m1b (bench "M1b that-read absent facet" 20000
  (that-read sample-map 0 ':term)))
;; that-write requires a net context; skip direct bench, covered in M3.

;; M2: CHAMP meta-info access (the store 4C retires)
(displayln "\nM2: meta-info CHAMP access (retirement target — Axis 2)")
(define m2a (bench "M2a fresh-meta (baseline)" 5000
  (with-fresh (λ () (fresh-meta '() (expr-Type 0) 'bench)))))
(define m2b (bench "M2b solve-meta! (writes CHAMP + cell)" 2000
  (with-fresh
    (λ ()
      (define m (fresh-meta '() (expr-Type 0) 'bench))
      (solve-meta! (expr-meta-id m) (expr-Nat))))))
(define m2c (bench "M2c meta-solution read (CHAMP read)" 5000
  (with-fresh
    (λ ()
      (define m (fresh-meta '() (expr-Type 0) 'bench))
      (solve-meta! (expr-meta-id m) (expr-Nat))
      (meta-solution (expr-meta-id m))))))

;; M3: infer on core forms (baseline for Axis 3 aspect coverage)
(displayln "\nM3: infer on core AST kinds (Axis 3 aspect-coverage baseline)")
(define m3a (bench "M3a infer lam" 2000
  (with-fresh (λ ()
    (infer '() (expr-lam 'mw (expr-Nat) (expr-bvar 0)))))))
(define m3b (bench "M3b infer app" 2000
  (with-fresh (λ ()
    (define f (expr-lam 'mw (expr-Nat) (expr-bvar 0)))
    (infer '() (expr-app f (expr-nat-val 3)))))))
(define m3c (bench "M3c infer Pi" 2000
  (with-fresh (λ ()
    (infer '() (expr-Pi 'mw (expr-Nat) (expr-Bool)))))))

;; ============================================================
;; M7-M13: PRE-0 BASELINES FOR TROPICAL FUEL SUBSTRATE
;; Per docs/tracking/2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md §3
;; Each test has hypothesis (HYP) + decision rule (DR).
;; Pre-impl baselines measure CURRENT counter-based fuel; post-impl
;; comparison runs after Phase 1B+1C land via bench-ab.rkt --ref.
;; ============================================================

(displayln "\n\n=== M7-M13: TROPICAL FUEL SUBSTRATE BASELINES (Pre-0) ===\n")

;; Pre-allocate a network for fuel-related ops
(define mfuel-net (make-prop-network 1000000))

;; M7: Counter decrement cost (baseline for post-impl tropical-fuel-merge)
;; Pattern: (struct-copy prop-network ... [hot (struct-copy prop-net-hot ... [fuel ...])])
;; Per BSP-LE Track 0 hot/warm/cold split: fuel lives in prop-net-hot (frequently mutated)
;; Mirrors the actual decrement at propagator.rkt:2382-2384 (BSP scheduler snapshot pattern)
;; HYP: cell-write within 50% of struct-copy cost (~1.5x at worst); both O(1) per call
;; DR: if cell-write > 2x struct-copy → reconsider canonical instance approach (revisit Q-A2)
(displayln "M7: counter decrement cost (baseline for post-impl tropical-fuel-merge)")
(define m7-1 (bench "M7.1 struct-copy decrement n=1" 50000
  (struct-copy prop-network mfuel-net
    [hot (struct-copy prop-net-hot (prop-network-hot mfuel-net)
           [fuel (sub1 (prop-net-hot-fuel (prop-network-hot mfuel-net)))])])))
(define m7-100 (bench "M7.2 struct-copy decrement n=100" 50000
  (struct-copy prop-network mfuel-net
    [hot (struct-copy prop-net-hot (prop-network-hot mfuel-net)
           [fuel (- (prop-net-hot-fuel (prop-network-hot mfuel-net)) 100)])])))
(define m7-10000 (bench "M7.3 struct-copy decrement n=10000" 50000
  (struct-copy prop-network mfuel-net
    [hot (struct-copy prop-net-hot (prop-network-hot mfuel-net)
           [fuel (- (prop-net-hot-fuel (prop-network-hot mfuel-net)) 10000)])])))

;; M7-mem: Memory-axis measurement for decrement (ties into R1 per-decrement allocation rate)
;; HYP: ~200-300 bytes/decrement (struct-copy of prop-net-hot + prop-network); cell-write 1.25-2x baseline
;; DR: if post-impl > 5x → object pooling for tagged-cell-value entries
(define m7-mem (bench-mem "M7.mem 10000 decrements alloc+retain" 10
  (let loop ([net mfuel-net] [n 10000])
    (if (zero? n) net
      (loop (struct-copy prop-network net
              [hot (struct-copy prop-net-hot (prop-network-hot net)
                     [fuel (sub1 (prop-net-hot-fuel (prop-network-hot net)))])])
            (sub1 n))))))

;; M8: Inline (<= fuel 0) check cost (baseline for post-impl threshold propagator)
;; Mirrors actual check sites at propagator.rkt:1817, 2366, 2373, 2992, 3045, 3132, 3135, 3142
;; HYP: post-impl threshold propagator within 30% of inline check at no-trigger case
;; DR: if no-trigger wall > 100% of inline check → reconsider threshold approach (inline check fast-path)
(displayln "\nM8: inline fuel check cost (baseline for post-impl threshold propagator)")
(define m8-not-exhausted (bench "M8.1 inline (<= fuel 0) not-exhausted" 50000
  (<= (prop-network-fuel mfuel-net) 0)))
;; Boundary case via synthetic net with fuel=0
(define m8-net-boundary
  (struct-copy prop-network mfuel-net
    [hot (struct-copy prop-net-hot (prop-network-hot mfuel-net) [fuel 0])]))
(define m8-at-boundary (bench "M8.2 inline (<= fuel 0) at-boundary" 50000
  (<= (prop-network-fuel m8-net-boundary) 0)))
(define m8-net-exhausted
  (struct-copy prop-network mfuel-net
    [hot (struct-copy prop-net-hot (prop-network-hot mfuel-net) [fuel -10])]))
(define m8-exhausted (bench "M8.3 inline (<= fuel 0) exhausted" 50000
  (<= (prop-network-fuel m8-net-exhausted) 0)))

;; M9: net-new-cell baseline (per-consumer fuel cell allocation cost)
;; HYP: O(1) per cell; ~200-500 bytes per cell allocation; linear with N
;; DR: if non-O(1) → reconsider per-consumer feasibility; if mem > 1KB/cell → investigate layout
(displayln "\nM9: net-new-cell allocation cost (baseline for per-consumer fuel cell allocation)")
(define identity-merge (lambda (a b) a))
(define m9-1 (bench-mem "M9.1 net-new-cell N=1" 200
  (let-values ([(net cid) (net-new-cell (make-prop-network 1000000) 0 identity-merge)])
    (void))))
(define m9-5 (bench-mem "M9.2 net-new-cell N=5 sequential" 100
  (let loop ([net (make-prop-network 1000000)] [n 5])
    (if (zero? n) net
      (let-values ([(net2 cid) (net-new-cell net 0 identity-merge)])
        (loop net2 (sub1 n)))))))
(define m9-50 (bench-mem "M9.3 net-new-cell N=50 sequential" 50
  (let loop ([net (make-prop-network 1000000)] [n 50])
    (if (zero? n) net
      (let-values ([(net2 cid) (net-new-cell net 0 identity-merge)])
        (loop net2 (sub1 n)))))))
(define m9-500 (bench-mem "M9.4 net-new-cell N=500 sequential" 20
  (let loop ([net (make-prop-network 1000000)] [n 500])
    (if (zero? n) net
      (let-values ([(net2 cid) (net-new-cell net 0 identity-merge)])
        (loop net2 (sub1 n)))))))

;; M10: residuation operator — N/A pre-impl (tropical-left-residual doesn't exist)
;; Will be measured post-Phase-1B in bench-tropical-fuel.rkt
(displayln "\nM10: residuation operator — N/A pre-impl (deferred to post-Phase-1B run)")

;; M11: integer add cost (baseline for tropical tensor +)
;; HYP: ~5-10 ns/call (single arithmetic op); 0 alloc for fixnum cases
;; DR: if wall > 50 ns → investigate Racket + for relevant numeric domain
;; If memory non-zero for fixnum case → choose representation more carefully (Q-1B-2)
(displayln "\nM11: integer add cost (baseline for tropical tensor)")
(define m11-fixnum (bench "M11.1 small fixnum + small fixnum" 50000
  (+ 5 10)))
(define m11-large (bench "M11.2 large fixnum + small fixnum" 50000
  (+ 1000000 5)))
(define m11-inf (bench "M11.3 +inf.0 + finite (overflow propagation)" 50000
  (+ +inf.0 5)))

;; M12: SRE domain registration overhead — N/A pre-impl (no new domain to register)
;; Will be measured post-Phase-1B by timing tropical-fuel-sre-domain registration
(displayln "\nM12: SRE domain registration — N/A pre-impl (deferred to post-Phase-1B run)")

;; M13: prop-network-fuel access (baseline for post-impl net-cell-read of fuel cell)
;; HYP: cell-read 6-10x slower than struct-field access (constant factor; per BSP-LE 0 ~30-50 ns)
;; DR: if cell-read > 100 ns → pre-resolved cell-id cache
(displayln "\nM13: prop-network-fuel access (baseline for post-impl cell-read)")
(define m13-1 (bench "M13.1 prop-network-fuel access (struct-field)" 50000
  (prop-network-fuel mfuel-net)))

;; ============================================================
;; A: ADVERSARIAL TESTS — Stress the 9 axes
;; ============================================================

(displayln "\n\n=== A: ADVERSARIAL TESTS (per-axis stress) ===\n")

;; A1: type-meta with concrete solution (Axis 5 :type/:term split baseline)
(displayln "A1: type-variable meta with concrete solution (Axis 5)")
(define a1a (bench-mem "A1a 10 metas solve to same type" 10
  (with-fresh (λ ()
    (for ([_ (in-range 10)])
      (define m (fresh-meta '() (expr-Type 0) 'bench))
      (unify '() m (expr-Nat)))))))
(define a1b (bench-mem "A1b 20 metas solve to different types" 10
  (with-fresh (λ ()
    (for ([i (in-range 20)])
      (define m (fresh-meta '() (expr-Type 0) 'bench))
      (unify '() m (if (even? i) (expr-Nat) (expr-Int))))))))

;; A2: speculation cycles (Axis 5 + Phase 8 baseline — ATMS branching cost)
(displayln "\nA2: speculation cycles (Phase 8 union-type ATMS baseline)")
(define a2a (bench-mem "A2a 10 spec cycles, no branching" 10
  (with-fresh (λ ()
    (for ([_ (in-range 10)])
      (define s (save-meta-state))
      (fresh-meta '() (expr-Type 0) 'spec)
      (restore-meta-state! s))))))
(define a2b (bench-mem "A2b 10 spec cycles, 3 metas each (branching sim)" 10
  (with-fresh (λ ()
    (for ([_ (in-range 10)])
      (define s (save-meta-state))
      (for ([_ (in-range 3)])
        (fresh-meta '() (expr-Type 0) 'spec))
      (restore-meta-state! s))))))

;; ============================================================
;; A5-A12: TROPICAL FUEL ADVERSARIAL BASELINES (Pre-0)
;; Per docs/tracking/2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md §4
;; Each test has hypothesis (HYP) + decision rule (DR).
;; Pre-impl baselines stress current counter-based fuel + adjacent
;; mechanisms (save/restore, sequential per-consumer counters);
;; post-impl re-run via bench-ab.rkt --ref establishes A/B comparison.
;; ============================================================

(displayln "\n\n=== A5-A12: TROPICAL FUEL ADVERSARIAL BASELINES (Pre-0) ===\n")

;; A5: Cost-bounded vs flat fuel exhaustion (semantic axis)
;; Counter is cost-blind — exhausts at N steps regardless of per-step cost.
;; Post-impl tropical fuel cell exhausts at accumulated cost == budget.
;; Pre-impl: measure counter-decrement loop cost (cost distribution irrelevant).
;; Workload: 80% cost 1, 15% cost 10, 5% cost 1000 (realistic non-uniform profile).
;; HYP: pre-impl exhausts at exactly N=budget steps regardless of cost distribution.
;; DR: post-impl must exhaust at correct cost-aware step count; bug if wrong.
(displayln "A5: cost-bounded vs flat fuel exhaustion (semantic axis)")
(define (a5-mixed-cost-step i)
  ;; Cost at step i (post-impl will use; pre-impl ignores).
  (cond
    [(< (modulo i 20) 16) 1]      ;; 80% cheap
    [(< (modulo i 20) 19) 10]     ;; 15% medium
    [else 1000]))                  ;; 5% expensive
(define a5-pre (bench-ms "A5.1 pre-impl counter loop 1000 mixed-cost steps" 10
  (let loop ([net mfuel-net] [i 0])
    (if (>= i 1000) net
      (loop (struct-copy prop-network net
              [hot (struct-copy prop-net-hot (prop-network-hot net)
                     [fuel (sub1 (prop-net-hot-fuel (prop-network-hot net)))])])
            (add1 i))))))
(define a5-total-cost-1000
  (for/sum ([i (in-range 1000)]) (a5-mixed-cost-step i)))
(printf "  A5.1.note: total cost over 1000 mixed-cost steps = ~a (pre-impl exhausts at 1000 step-count regardless)\n"
        a5-total-cost-1000)

;; A6: Deep dependency chain (Phase 3C UC1 forward-capture)
;; Pre-impl: simulate dep-graph walk via list iteration; measure per-N.
;; Post-impl: residuation walks the propagator dependency graph backward from
;; contradicted fuel cell, summing per-step costs via `tropical-left-residual`.
;; HYP: walk cost O(N) for chain depth N; for N=200, < 100 μs.
;; DR: if walk > 1ms for N=200 → reconsider Phase 3C UC1 (lazy walk vs eager).
(displayln "\nA6: deep dependency chain (Phase 3C UC1 forward-capture)")
(define (a6-make-dep-chain N)
  (for/list ([i (in-range N)]) (cons i (modulo i 10))))
(define a6-chain-10 (a6-make-dep-chain 10))
(define a6-chain-50 (a6-make-dep-chain 50))
(define a6-chain-200 (a6-make-dep-chain 200))
(define a6-walk-10 (bench "A6.1 walk N=10 chain (sum costs)" 50000
  (for/sum ([entry (in-list a6-chain-10)]) (cdr entry))))
(define a6-walk-50 (bench "A6.2 walk N=50 chain (sum costs)" 20000
  (for/sum ([entry (in-list a6-chain-50)]) (cdr entry))))
(define a6-walk-200 (bench "A6.3 walk N=200 chain (sum costs)" 5000
  (for/sum ([entry (in-list a6-chain-200)]) (cdr entry))))
(define a6-mem-200 (bench-mem "A6.mem N=200 chain construction + walk" 100
  (let ([chain (a6-make-dep-chain 200)])
    (for/sum ([entry (in-list chain)]) (cdr entry)))))

;; A7: High-frequency decrement (memory pressure — primary signal)
;; Pre-impl: bounded retention (struct-copy GC'd between iterations).
;; Post-impl: tagged-cell-value entry per worldview accumulates;
;; under no-speculation (canonical fuel cell), should be similar bounded retention.
;; HYP: post-impl alloc within 1.25-2x pre-impl (per Finding 1: 62.5 bytes/dec baseline);
;; comparable GC count under no-speculation.
;; DR: if alloc > 5x → object pool; if GC > 3x → investigate retention pattern.
(displayln "\nA7: high-frequency decrement (fuel exhaustion under load — memory PRIMARY)")
(define a7-1k (bench-mem "A7.1 1000 decrements alloc+retain" 50
  (let loop ([net mfuel-net] [n 1000])
    (if (zero? n) net
      (loop (struct-copy prop-network net
              [hot (struct-copy prop-net-hot (prop-network-hot net)
                     [fuel (sub1 (prop-net-hot-fuel (prop-network-hot net)))])])
            (sub1 n))))))
(define a7-10k (bench-mem "A7.2 10000 decrements alloc+retain" 20
  (let loop ([net mfuel-net] [n 10000])
    (if (zero? n) net
      (loop (struct-copy prop-network net
              [hot (struct-copy prop-net-hot (prop-network-hot net)
                     [fuel (sub1 (prop-net-hot-fuel (prop-network-hot net)))])])
            (sub1 n))))))
(define a7-100k (bench-mem "A7.3 100000 decrements alloc+retain" 5
  (let loop ([net mfuel-net] [n 100000])
    (if (zero? n) net
      (loop (struct-copy prop-network net
              [hot (struct-copy prop-net-hot (prop-network-hot net)
                     [fuel (sub1 (prop-net-hot-fuel (prop-network-hot net)))])])
            (sub1 n))))))

;; A8: Multi-consumer concurrent (10 consumers × 1000 decrements each — sequential)
;; Pre-impl: each "consumer" has its own prop-network with its own counter; sequential.
;; Post-impl: each consumer allocates its own tropical fuel cell via the primitive.
;; HYP: O(N × M) wall for N consumers × M decrements (linear);
;; memory = O(N) cell allocation + O(N × M) cumulative decrements.
;; DR: if non-linear scaling → investigate per-consumer pollution OR cross-consumer
;; state interference; if memory > predicted → investigate per-consumer overhead (M9 baseline).
(displayln "\nA8: multi-consumer concurrent (10×1000 decrements — sequential composition)")
(define a8-mc (bench-mem "A8.1 10 consumers × 1000 decrements each" 20
  (for/list ([_ (in-range 10)])
    (let loop ([net (make-prop-network 10000)] [n 1000])
      (if (zero? n) net
        (loop (struct-copy prop-network net
                [hot (struct-copy prop-net-hot (prop-network-hot net)
                       [fuel (sub1 (prop-net-hot-fuel (prop-network-hot net)))])])
              (sub1 n)))))))

;; A9: Speculation rollback cost (write-tagged-then-rollback — 100 cycles)
;; Pre-impl: save-meta-state + meta-write + restore-meta-state! per cycle.
;; This is the elab-net snapshot mechanism (off-network state for fuel; counter
;; restored from snapshot). Phase 1C migration via tagged-cell-value worldview.
;; HYP: post-impl significantly faster (worldview-narrow O(1) vs snapshot restore O(N) cells);
;; less retention (per-worldview slice vs full snapshot).
;; DR: if memory leaks under repeated rollback → S(-1) tagged-cell-value cleanup bug
;; coordination needed between Phase 1B/1C + S(-1) stratum.
(displayln "\nA9: speculation rollback cost (100 write-tagged-then-rollback cycles)")
(define a9-100 (bench-mem "A9.1 100 spec cycles (save + write + restore)" 20
  (with-fresh (λ ()
    (for ([_ (in-range 100)])
      (define s (save-meta-state))
      (define m (fresh-meta '() (expr-Type 0) 'spec))
      (solve-meta! (expr-meta-id m) (expr-Nat))
      (restore-meta-state! s))))))

;; A10: Branch fork explosion (5-way fork — Phase 3A per-branch fuel forward-capture)
;; Pre-impl: simulate 5 branches via 5 sequential counters; measure cumulative.
;; Post-impl: per-branch tropical fuel cell allocated per union component;
;; threshold per branch; branch-local residuation walks per-branch dep chain on contradiction.
;; HYP: O(B × M) wall for B branches × M decrements; memory O(B) cell + O(B × M) tagged
;; entries during speculation; collapses to O(1) cell + O(M) entries after resolution.
;; DR: if retention after resolution > O(M) → retracted branch state leaks
;; (S(-1) stratum cleanup needs Phase 3A coordination).
(displayln "\nA10: branch fork explosion (5-way × 100 decrements per branch)")
(define a10-5-way (bench-mem "A10.1 5-way fork × 100 decrements per branch" 30
  (for/list ([_ (in-range 5)])
    (let loop ([net (make-prop-network 1000)] [n 100])
      (if (zero? n) net
        (loop (struct-copy prop-network net
                [hot (struct-copy prop-net-hot (prop-network-hot net)
                       [fuel (sub1 (prop-net-hot-fuel (prop-network-hot net)))])])
              (sub1 n)))))))

;; A11: Pathological cost patterns
;; HYP: pre-impl exhausts at exactly N=budget steps for ALL sub-tests (cost-blind);
;; post-impl exhausts at correct cost-aware point per sub-test.
;; DR: bug in cost accumulation if post-impl exhausts incorrectly;
;; pathological alloc patterns indicate merge-fn bug.
(displayln "\nA11: pathological cost patterns")
;; A11.1: single huge cost (1 step × cost 1000000) — pre-impl: 1 decrement
(define a11-huge (bench "A11.1 single huge cost (pre-impl: 1 dec)" 50000
  (struct-copy prop-network mfuel-net
    [hot (struct-copy prop-net-hot (prop-network-hot mfuel-net)
           [fuel (- (prop-net-hot-fuel (prop-network-hot mfuel-net)) 1)])])))
;; A11.2: many tiny costs (10000 steps × cost 1) — pre-impl: 10000 decrements
(define a11-tiny (bench-ms "A11.2 many tiny costs 10000 steps × 1" 20
  (let loop ([net mfuel-net] [n 10000])
    (if (zero? n) net
      (loop (struct-copy prop-network net
              [hot (struct-copy prop-net-hot (prop-network-hot net)
                     [fuel (sub1 (prop-net-hot-fuel (prop-network-hot net)))])])
            (sub1 n))))))
;; A11.3: alternating (1000 steps; 50% cost 0, 50% cost 2) — pre-impl: 1000 decrements
(define a11-alt (bench-ms "A11.3 alternating cost (1000 steps)" 50
  (let loop ([net mfuel-net] [i 0])
    (if (>= i 1000) net
      (loop (struct-copy prop-network net
              [hot (struct-copy prop-net-hot (prop-network-hot net)
                     [fuel (sub1 (prop-net-hot-fuel (prop-network-hot net)))])])
            (add1 i))))))
;; A11.4: monotonically increasing (step i costs i; budget 1000) — pre-impl: 1000 decrements
;; Post-impl: would exhaust at step ~44 (sum 1+2+...+44 ≈ 990).
(define a11-mono (bench-ms "A11.4 monotonically increasing cost (1000 steps)" 50
  (let loop ([net mfuel-net] [i 0])
    (if (>= i 1000) net
      (loop (struct-copy prop-network net
              [hot (struct-copy prop-net-hot (prop-network-hot net)
                     [fuel (sub1 (prop-net-hot-fuel (prop-network-hot net)))])])
            (add1 i))))))

;; A12: residuation operator boundary algebra — N/A pre-impl
;; (tropical-left-residual doesn't exist; will be measured post-Phase-1B
;;  via bench-tropical-fuel.rkt + tests/test-tropical-fuel.rkt unit tests)
(displayln "\nA12: residuation boundary algebra — N/A pre-impl (deferred to post-Phase-1B run)")

;; ============================================================
;; E: E2E BASELINES — Realistic programs
;; ============================================================

(displayln "\n\n=== E: E2E BASELINES (full pipeline) ===\n")

;; E1: simple program — no metas, no traits (baseline floor)
(define e1-src
  "ns bench-4c-e1 :no-prelude\ndef x : Int := 42\ndef y : Int := [int+ x 1]\neval y\n")

;; E2: parametric trait resolution (Axis 1 — current bridge path)
(define e2-src
  "ns bench-4c-e2\ndef xs := '[1N 2N 3N]\neval [head xs]\n")

;; E3: polymorphic identity with concrete solution (Axis 5 — :type/:term baseline)
(define e3-src
  (string-append
   "ns bench-4c-e3 :no-prelude\n"
   "spec id {A : Type} A -> A\n"
   "defn id [x] x\n"
   "eval [id 3N]\n"))

;; E4: multi-arg generic arithmetic (cross-family — Axis 6 coercion path)
(define e4-src
  "ns bench-4c-e4\neval [+ 1 2]\neval [+ 3N 4N]\n")

(define e1 (bench-mem "E1 simple (no metas)" 10
                  (silent (lambda () (process-string-ws e1-src)))))
(define e2 (bench-mem "E2 parametric Seqable (Axis 1 bridge)" 10
                  (silent (lambda () (process-string-ws e2-src)))))
(define e3 (bench-mem "E3 polymorphic id (Axis 5 :type/:term)" 10
                  (silent (lambda () (process-string-ws e3-src)))))
(define e4 (bench-mem "E4 generic arithmetic (Axis 6)" 10
                  (silent (lambda () (process-string-ws e4-src)))))

;; ============================================================
;; E7-E9: TROPICAL FUEL E2E BASELINES (Pre-0)
;; Per docs/tracking/2026-04-26_TROPICAL_ADDENDUM_PRE0_PLAN.md §7
;; Each test has hypothesis (HYP) + decision rule (DR).
;; Pre-impl baselines run current counter-based fuel through realistic
;; full-pipeline workloads; post-impl re-run via bench-ab.rkt --ref.
;; ============================================================

(displayln "\n\n=== E7-E9: TROPICAL FUEL E2E BASELINES (Pre-0) ===\n")

;; E7: Realistic elaboration with fuel tracking (probe file as workload)
;; HYP: post-impl wall within 5% of pre-impl; memory within 10%; cell_allocs delta +N for canonical fuel cells (bounded constant)
;; DR: if wall regression > 10% → investigate hot-path overhead at decrement sites
;;     if memory regression > 20% → investigate retention semantics
;;     if cell_allocs delta > 10 → unexpected cell allocation; investigate
(displayln "E7: realistic elaboration with fuel tracking (probe file 28 expressions)")
(define e7-probe-path "examples/2026-04-22-1A-iii-probe.prologos")
(define e7-src
  (call-with-input-file e7-probe-path port->string))
(define e7 (bench-mem "E7.1 probe full file (realistic elaboration profile)" 5
  (silent (lambda () (process-string-ws e7-src)))))

;; E8: Deep type-inference workload (high decrement rate via 50-deep id composition)
;; HYP: stress the decrement path; expect ~5-15% regression but bounded (per Finding 11 hybrid pivot empirically reinforced)
;; DR: if regression > 25% → revisit threshold propagator architecture
;;     (maybe inline check at decrement site as fast-path — already proposed via M-tier Finding 2 hybrid pivot)
(displayln "\nE8: deep type-inference workload (50-deep polymorphic id composition)")
(define (e8-make-deep-id-src depth)
  (string-append
   "ns bench-4c-e8 :no-prelude\n"
   "spec id {A : Type} A -> A\n"
   "defn id [x] x\n"
   "eval "
   (apply string-append
          (for/list ([_ (in-range depth)]) "[id "))
   "3N"
   (apply string-append
          (for/list ([_ (in-range depth)]) "]"))
   "\n"))
(define e8-src (e8-make-deep-id-src 50))
(define e8 (bench-mem "E8.1 50-deep id composition" 5
  (silent (lambda () (process-string-ws e8-src)))))

;; E9: Cost-bounded elaboration scenario (Phase 3C UC2 forward-capture)
;; Pre-impl: simulate Phase 3C UC2 via moderately complex polymorphic program
;; HYP: cost-bounded elaboration is feasible with current substrate; Phase 3C consumer can implement cleanly
;; DR: if hypothesis fails → revisit Phase 3C UC2 design (D.1 §9.7); might need additional substrate
;; Hand-instrumented (not full Phase 3C); demonstrates pattern works under Phase 1B substrate
(displayln "\nE9: cost-bounded elaboration scenario (Phase 3C UC2 forward-capture)")
(define e9-src
  (string-append
   "ns bench-4c-e9 :no-prelude\n"
   "spec id {A : Type} A -> A\n"
   "defn id [x] x\n"
   "spec compose {A B C : Type} [B -> C] -> [A -> B] -> A -> C\n"
   "defn compose [f g x] [f [g x]]\n"
   "def f1 := [compose id id]\n"
   "def f2 := [compose f1 f1]\n"
   "def f3 := [compose f2 f2]\n"
   "eval [f3 5N]\n"))
(define e9 (bench-mem "E9.1 cost-bounded elaboration scenario" 5
  (silent (lambda () (process-string-ws e9-src)))))

;; ============================================================
;; V: VALIDATION — Correctness reference for parity harness
;; ============================================================

(displayln "\n\n=== V: VALIDATION (parity reference points) ===\n")

(define v-failures 0)

;; V1: infer produces correct type for literals
(with-fresh (λ ()
  (define t (infer '() (expr-Nat)))
  (unless (equal? t (expr-Type 0))
    (set! v-failures (add1 v-failures))
    (printf "  V1a FAIL: infer Nat = ~a\n" t))))

;; V2: solve-meta! + meta-solution round-trip (CHAMP authoritative today)
(with-fresh (λ ()
  (define m (fresh-meta '() (expr-Type 0) 'bench))
  (solve-meta! (expr-meta-id m) (expr-Int))
  (unless (equal? (meta-solution (expr-meta-id m)) (expr-Int))
    (set! v-failures (add1 v-failures))
    (printf "  V2 FAIL: round-trip\n"))))

;; V3: speculation rollback (baseline for cell-based TMS comparison)
(with-fresh (λ ()
  (define m (fresh-meta '() (expr-Type 0) 'bench))
  (define saved (save-meta-state))
  (solve-meta! (expr-meta-id m) (expr-Int))
  (restore-meta-state! saved)
  (when (meta-solution (expr-meta-id m))
    (set! v-failures (add1 v-failures))
    (printf "  V3 FAIL: meta still solved after restore\n"))))

(printf "  V-total: ~a failures\n" v-failures)

;; ============================================================
;; Summary
;; ============================================================

(displayln "\n\n=== SUMMARY ===\n")

(define (fmt-mem v)
  ;; v is (vector wall-ms alloc-bytes retain-bytes)
  (format "~a ms / ~a KB alloc / ~a KB retain"
          (~r (vector-ref v 0) #:precision '(= 2))
          (~r (/ (vector-ref v 1) 1024.0) #:precision '(= 1))
          (~r (/ (vector-ref v 2) 1024.0) #:precision '(= 1))))

(printf "M1 attribute-map facet access:       ~a / ~a μs  (that-read :type / :absent)\n"
        (~r m1a #:precision '(= 2)) (~r m1b #:precision '(= 2)))
(printf "M2 CHAMP meta-info access:           fresh=~a  solve=~a  read=~a μs\n"
        (~r m2a #:precision '(= 2)) (~r m2b #:precision '(= 2)) (~r m2c #:precision '(= 2)))
(printf "M3 infer core forms:                 lam=~a  app=~a  Pi=~a μs\n"
        (~r m3a #:precision '(= 2)) (~r m3b #:precision '(= 2)) (~r m3c #:precision '(= 2)))
(printf "M7 counter decrement (struct-copy):  n=1: ~a  n=100: ~a  n=10000: ~a μs\n"
        (~r m7-1 #:precision '(= 3)) (~r m7-100 #:precision '(= 3)) (~r m7-10000 #:precision '(= 3)))
(printf "M7.mem 10000 decrements:             ~a\n" (fmt-mem m7-mem))
(printf "M8 inline (<= fuel 0) check:         not-exh: ~a  boundary: ~a  exh: ~a μs\n"
        (~r m8-not-exhausted #:precision '(= 3)) (~r m8-at-boundary #:precision '(= 3)) (~r m8-exhausted #:precision '(= 3)))
(printf "M9 net-new-cell allocation:          N=1: ~a\n" (fmt-mem m9-1))
(printf "M9 net-new-cell allocation:          N=5: ~a\n" (fmt-mem m9-5))
(printf "M9 net-new-cell allocation:          N=50: ~a\n" (fmt-mem m9-50))
(printf "M9 net-new-cell allocation:          N=500: ~a\n" (fmt-mem m9-500))
(printf "M11 integer add cost:                fixnum: ~a  large: ~a  +inf.0: ~a μs\n"
        (~r m11-fixnum #:precision '(= 3)) (~r m11-large #:precision '(= 3)) (~r m11-inf #:precision '(= 3)))
(printf "M13 prop-network-fuel access:        ~a μs\n" (~r m13-1 #:precision '(= 3)))
(printf "A1a type-meta 10-same solve:         ~a\n" (fmt-mem a1a))
(printf "A1b type-meta 20-different solve:    ~a\n" (fmt-mem a1b))
(printf "A2a 10 spec cycles (no branching):   ~a\n" (fmt-mem a2a))
(printf "A2b 10 spec cycles (3 metas each):   ~a\n" (fmt-mem a2b))
(printf "A5 cost-bounded loop (1000 steps):   ~a ms (cost-blind pre-impl; total cost = ~a)\n"
        (~r a5-pre #:precision '(= 3)) a5-total-cost-1000)
(printf "A6 dep-chain walk:                   N=10: ~a  N=50: ~a  N=200: ~a μs\n"
        (~r a6-walk-10 #:precision '(= 3)) (~r a6-walk-50 #:precision '(= 3)) (~r a6-walk-200 #:precision '(= 3)))
(printf "A6.mem N=200 chain construction:     ~a\n" (fmt-mem a6-mem-200))
(printf "A7 high-freq decrement N=1000:       ~a\n" (fmt-mem a7-1k))
(printf "A7 high-freq decrement N=10000:      ~a\n" (fmt-mem a7-10k))
(printf "A7 high-freq decrement N=100000:     ~a\n" (fmt-mem a7-100k))
(printf "A8 multi-consumer 10×1000:           ~a\n" (fmt-mem a8-mc))
(printf "A9 100 spec cycles (save+write+restore): ~a\n" (fmt-mem a9-100))
(printf "A10 5-way fork × 100/branch:         ~a\n" (fmt-mem a10-5-way))
(printf "A11.1 single huge cost (1 dec):      ~a μs/call\n" (~r a11-huge #:precision '(= 3)))
(printf "A11.2 many tiny costs (10k steps):   ~a ms\n" (~r a11-tiny #:precision '(= 3)))
(printf "A11.3 alternating cost (1000 steps): ~a ms\n" (~r a11-alt #:precision '(= 3)))
(printf "A11.4 monotonic cost (1000 steps):   ~a ms\n" (~r a11-mono #:precision '(= 3)))
(printf "E1 simple (no metas):                ~a\n" (fmt-mem e1))
(printf "E2 parametric Seqable (Axis 1):      ~a\n" (fmt-mem e2))
(printf "E3 polymorphic id (Axis 5):          ~a\n" (fmt-mem e3))
(printf "E4 generic arithmetic (Axis 6):      ~a\n" (fmt-mem e4))
(printf "E7 probe (realistic):                ~a\n" (fmt-mem e7))
(printf "E8 50-deep id composition:           ~a\n" (fmt-mem e8))
(printf "E9 cost-bounded elaboration:         ~a\n" (fmt-mem e9))
(printf "V correctness:                       ~a failures\n" v-failures)

(displayln "\n(Baselines captured. Re-run after 4C phases land for A/B comparison.)")
