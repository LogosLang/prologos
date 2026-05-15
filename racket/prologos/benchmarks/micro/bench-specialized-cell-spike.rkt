#lang racket/base

;;;
;;; bench-specialized-cell-spike.rkt
;;; PPN 4C Tropical Quantale Addendum D.4 — §13.6 Pre-0 spike
;;;
;;; PURPOSE: directly measure specialized cell-write cost vs struct-copy baseline.
;;; This is the FALSIFICATION TEST for the D.4 architectural reframing.
;;;
;;; The D.3 hybrid pivot rests on a Pre-0 R-19 EXTRAPOLATION ("full cell-migration
;;; would trigger major GC at 100k decrements") that was never directly measured for
;;; an optimized cell mechanism. D.4 §4.6 proposes a specialized cell type framework
;;; (`:tier 'hot` + `:storage 'monotone-counter` + `:fires-on 'threshold-crossing` +
;;; `:on-write-check`) that should provide a fast-path without `tagged-cell-value`
;;; allocation. This spike measures whether that framework actually closes the gap.
;;;
;;; TARGETS (per design doc §13.6):
;;;   W1: Specialized cell-write (no-spec, no threshold) ≤ 30 ns/call
;;;       (within ~25% of M7 baseline 24 ns/call)
;;;   W2: Specialized cell-write (threshold crossing detected) ≤ 200 ns/call
;;;       (rare event; contradiction-write ceremony allowed)
;;;   W3: GC profile at 100k decrements: ZERO major-GC
;;;       (matches R3 baseline 0.00 ms / 0.0%)
;;;   W4: Specialized cell-read ≤ 15 ns/call
;;;       (within ~50% of M13 baseline 6 ns; cell-API has indirection)
;;;   W5: Specialized cell-write under speculation (tagged-cell-value) — reference only
;;;       (existing BSP-LE 2B + ATMS benchmarks confirm ~500-1000 ns/call)
;;;
;;; DECISION CRITERIA:
;;;   PASS:  W1 ≤ 30  +  W4 ≤ 15  +  (W1+W4) ≤ 45  +  W3 = ZERO major-GC  →  D.4 canonical
;;;   FAIL:  W1 > 60  OR  (W1+W4) > 60  OR  W3 > 0 major-GC               →  D.3 hybrid stays
;;;   MIXED: cell-write fast but GC-pressured (or vice-versa)              →  re-design
;;;
;;; THROWAWAY: this file will be deleted (D.4 PASS) or marked falsified (D.4 FAIL)
;;; post-spike per design doc §13.6.
;;;
;;; Usage:
;;;   "/Applications/Racket v9.0/bin/racket" \
;;;     racket/prologos/benchmarks/micro/bench-specialized-cell-spike.rkt
;;;

(require racket/list
         racket/format)

;; ============================================================
;; MOCK: minimal "specialized cell" implementation
;; ============================================================

;; A specialized monotone-counter cell: a struct with mutable fuel-cost field.
;; Under no-speculation, "cell-write" mutates the field directly (no tagged-cell-value).
;; The threshold check (on-write predicate) runs INLINE during cell-write.
;; Fire-on-threshold-crossing: only "notify" (mock counter increment) when crossing;
;; most writes bypass propagator-fire ceremony entirely.
;;
;; This mirrors §4.6's specialized cell type framework dispatch under the
;; hot+monotone-counter path, without the full cell-meta lookup machinery
;; (which would add ~5-10 ns dispatch overhead in practice).

(struct mock-net
  ([fuel-cost #:mutable]
   fuel-budget
   [crossing-count #:mutable])
  #:transparent)

;; Specialized cell-write FAST PATH
;; - Inline threshold check (replaces separate threshold propagator)
;; - On threshold crossing: increment count + mutate (rare; <0.001% per design)
;; - Else: direct mutation, no propagator-fire ceremony (fire-on 'threshold-crossing)
(define (specialized-cell-write-fast net new-cost)
  (define budget (mock-net-fuel-budget net))
  (cond
    [(>= new-cost budget)
     ;; Threshold crossed — contradiction path (rare)
     (set-mock-net-fuel-cost! net new-cost)
     (set-mock-net-crossing-count! net (+ 1 (mock-net-crossing-count net)))]
    [else
     ;; Fast path: direct mutation, no notification
     (set-mock-net-fuel-cost! net new-cost)]))

;; Specialized cell-read (direct struct-field access)
(define (specialized-cell-read net)
  (mock-net-fuel-cost net))

;; ============================================================
;; BASELINE REFERENCE: struct-copy prop-net-cold (Pre-0 M7)
;; ============================================================

;; Mirror the prop-net-cold structure layout for stability-check baseline.
;; Functional/immutable: struct-copy creates new struct per call.
(struct mock-cold
  (fuel other1 other2 other3 other4 other5)
  #:transparent)

(define (struct-copy-decrement-baseline net n)
  (struct-copy mock-cold net [fuel (- (mock-cold-fuel net) n)]))

;; ============================================================
;; DISPATCH-OVERHEAD MOCK
;; ============================================================
;;
;; The fast-path measurement (W1) skips the cell-meta dispatch the real
;; implementation would need: cell-id → cell-meta lookup, tier/storage check,
;; under-speculation check. This mock adds that overhead so we have a
;; realistic upper bound for what the framework will cost in production.

;; Pre-allocated cell-meta indexed by cell-id (vector-based, matches likely
;; production representation; vector-ref is ~1 ns).
(define cell-meta-vec (make-vector 16 #f))
(define meta-fuel-cost (vector 'hot 'monotone-counter 'threshold-crossing #t))
(vector-set! cell-meta-vec 11 meta-fuel-cost)  ;; cell-id 11 = fuel-cost-cell per §4.3

;; Specialized cell-write WITH dispatch overhead (representative upper bound)
;; - Looks up cell-meta via vector-ref
;; - Checks tier (would be 'eq? compare in real)
;; - Checks under-speculation (mocked as fixnum compare against 0)
;; - Then enters the fast path
(define under-speculation-flag 0)  ;; 0 = not under speculation
(define (specialized-cell-write-with-dispatch net cell-id new-cost)
  (define meta (vector-ref cell-meta-vec cell-id))
  (cond
    [(and meta
          (eq? (vector-ref meta 0) 'hot)
          (eq? (vector-ref meta 1) 'monotone-counter)
          (= under-speculation-flag 0))
     ;; FAST PATH dispatch — enter mutation+check path
     (specialized-cell-write-fast net new-cost)]
    [else
     ;; SLOW PATH (would call general net-cell-write in production)
     (specialized-cell-write-fast net new-cost)]))

;; ============================================================
;; TIMING INFRASTRUCTURE
;; (mirrors bench-ppn-track4c.rkt patterns: warmup, collect-garbage, median-of-N)
;; ============================================================

(define-syntax-rule (bench-ns label N-val body)
  (let ()
    (for ([_ (in-range 100)]) body)            ; warmup
    (define N N-val)
    (collect-garbage) (collect-garbage)
    (define start (current-inexact-milliseconds))
    (for ([_ (in-range N)]) body)
    (define end (current-inexact-milliseconds))
    (define mean-ns (* 1000000.0 (/ (- end start) N)))
    (printf "  ~a: ~a ns/call (~a calls)\n"
            label (~r mean-ns #:precision '(= 1)) N)
    mean-ns))

(define-syntax-rule (bench-gc label runs body)
  (let ()
    (for ([_ (in-range 3)]) body)              ; warmup
    (define results
      (for/list ([_ (in-range runs)])
        (collect-garbage) (collect-garbage)
        (define gc-before (current-gc-milliseconds))
        (define start (current-inexact-milliseconds))
        body
        (define end (current-inexact-milliseconds))
        (define gc-after (current-gc-milliseconds))
        (vector (- end start) (- gc-after gc-before))))
    (define wall-times (for/list ([r results]) (vector-ref r 0)))
    (define gc-times (for/list ([r results]) (vector-ref r 1)))
    (define (med xs) (list-ref (sort xs <) (quotient (length xs) 2)))
    (define gc-pct (* 100.0 (/ (med gc-times) (max 0.001 (med wall-times)))))
    (printf "  ~a: wall=~a ms  gc=~a ms (~a%)  (n=~a)\n"
            label
            (~r (med wall-times) #:precision '(= 3))
            (~r (med gc-times) #:precision '(= 3))
            (~r gc-pct #:precision '(= 1))
            runs)
    (vector (med wall-times) (med gc-times))))

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
        (vector (- end start)
                (- mem-after mem-before)
                (- retained-after retained-before))))
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

;; ============================================================
;; SPIKE: §13.6 W1-W5 MEASUREMENTS
;; ============================================================

(printf "\n=== §13.6 Pre-0 SPIKE: Specialized Cell Type Framework Falsification Test ===\n\n")

(printf "Reference Pre-0 baselines (2026-04-26; tropical-pre0-baseline-2026-04-26.txt):\n")
(printf "  M7  struct-copy decrement:           24 ns/call  →  W1 target ≤ 30 ns\n")
(printf "  M13 prop-network-fuel access:         6 ns/call  →  W4 target ≤ 15 ns\n")
(printf "  R3  100k decrement GC profile:        0.00 ms / 0.0%%  →  W3 target = 0 major-GC\n")
(printf "  A7.3 100k decrement memory:           6251 KB alloc, -0.3 KB retain\n\n")

;; Setup: large budget to avoid threshold crossing during W1 measurements
;; W1 iterates 50000 × n; max n=10000 → 5e8; we use 1e10 for safety margin
(define spike-budget 10000000000) ; 1e10
(define spike-net (mock-net 0 spike-budget 0))

;; ----------------------------------------
;; W1: Specialized cell-write FAST PATH (no-speculation, no threshold crossing)
;; ----------------------------------------
(printf "W1: Specialized cell-write FAST PATH (no-spec, no threshold crossing)\n")

;; W1.1 — n=1 (typical decrement; matches M7.1 pattern)
(set-mock-net-fuel-cost! spike-net 0)
(set-mock-net-crossing-count! spike-net 0)
(define w1-1
  (bench-ns "W1.1 specialized-cell-write n=1 (no crossing)" 50000
    (specialized-cell-write-fast spike-net (+ (mock-net-fuel-cost spike-net) 1))))

;; W1.2 — n=100 (batched decrement; matches M7.2 pattern)
(set-mock-net-fuel-cost! spike-net 0)
(set-mock-net-crossing-count! spike-net 0)
(define w1-2
  (bench-ns "W1.2 specialized-cell-write n=100 (no crossing)" 50000
    (specialized-cell-write-fast spike-net (+ (mock-net-fuel-cost spike-net) 100))))

;; W1.3 — n=10000 (large step; matches M7.3 pattern)
(set-mock-net-fuel-cost! spike-net 0)
(set-mock-net-crossing-count! spike-net 0)
(define w1-3
  (bench-ns "W1.3 specialized-cell-write n=10000 (no crossing)" 50000
    (specialized-cell-write-fast spike-net (+ (mock-net-fuel-cost spike-net) 10000))))

(printf "  W1 crossing-count verification (should be 0): ~a\n"
        (mock-net-crossing-count spike-net))

;; W1+ : Specialized cell-write WITH dispatch overhead (realistic upper bound)
;; This adds the cell-meta lookup + tier check + under-speculation check that
;; the production implementation will need. Provides a more honest estimate.
(printf "\n")
(printf "W1+: Specialized cell-write WITH dispatch overhead (realistic upper bound)\n")
(set-mock-net-fuel-cost! spike-net 0)
(define w1+1
  (bench-ns "W1+.1 specialized-cell-write WITH dispatch n=1" 50000
    (specialized-cell-write-with-dispatch spike-net 11
      (+ (mock-net-fuel-cost spike-net) 1))))
(printf "\n")

;; ----------------------------------------
;; W2: Specialized cell-write THRESHOLD CROSSING path (rare event)
;; ----------------------------------------
(printf "W2: Specialized cell-write THRESHOLD CROSSING (rare event)\n")

;; Setup: cost just below budget; each write crosses
;; Each iteration: reset to (budget - 1), write budget — crosses!
;; Includes the reset cost (~5 ns), so this is upper-bound for crossing
(define small-spike-net (mock-net 0 1000 0))
(define w2-1
  (bench-ns "W2.1 specialized-cell-write (threshold crossing; includes reset)" 50000
    (begin
      (set-mock-net-fuel-cost! small-spike-net 999)
      (specialized-cell-write-fast small-spike-net 1000))))

(printf "  W2 crossing-count verification (should be 50000): ~a\n"
        (mock-net-crossing-count small-spike-net))
(printf "\n")

;; ----------------------------------------
;; W3: GC profile at 100k decrements (memory-as-PRIMARY signal)
;; ----------------------------------------
(printf "W3: Specialized cell-write GC profile (100k decrements)\n")

;; Allocate fresh net per run; run the 100k-decrement loop
(define w3-1
  (bench-gc "W3.1 specialized-cell-write 100k decrements GC profile" 5
    (let ([net (mock-net 0 spike-budget 0)])
      (for ([_ (in-range 100000)])
        (specialized-cell-write-fast net (+ (mock-net-fuel-cost net) 1))))))

;; W3.2: allocation/retention profile at 100k decrements
(define w3-2
  (bench-mem "W3.2 specialized-cell-write 100k decrements alloc/retain" 10
    (let ([net (mock-net 0 spike-budget 0)])
      (for ([_ (in-range 100000)])
        (specialized-cell-write-fast net (+ (mock-net-fuel-cost net) 1))))))

(printf "\n")

;; ----------------------------------------
;; W4: Specialized cell-read cost
;; ----------------------------------------
(printf "W4: Specialized cell-read (direct field access)\n")

(set-mock-net-fuel-cost! spike-net 12345)
(define w4-1
  (bench-ns "W4.1 specialized-cell-read" 50000
    (specialized-cell-read spike-net)))

(printf "\n")

;; ----------------------------------------
;; W5: Speculation fallback — reference only
;; ----------------------------------------
(printf "W5: Specialized cell-write under speculation (tagged-cell-value fallback)\n")
(printf "  REFERENCE-ONLY: under D.4 the fast path falls through to existing generic\n")
(printf "  cell-write under speculation. Prior BSP-LE 2B + ATMS benchmarks establish\n")
(printf "  generic cell-write at ~~500-1000 ns/call under speculation worldview.\n")
(printf "  Not re-measured here (would require full prop-network integration).\n")
(printf "  Per D.3.EC MG2: multi-worldview cell-write deferred to Phase 3A measurement.\n")
(printf "\n")

;; ----------------------------------------
;; BASELINE REFERENCE: struct-copy stability check
;; ----------------------------------------
;; NOTE: in this spike's simplified setting, B.M7 measures only the cost of
;; a single struct-copy on a 6-field flat struct, NOT the nested struct-copy
;; pattern of the real Pre-0 M7 (which traverses prop-network → prop-net-hot).
;; To defeat JIT dead-code elimination of the unused struct result, we capture
;; via mutable box. Even so, this baseline is NOT directly comparable to Pre-0 M7;
;; it's a context-stability anchor for the W1 spike measurement.
(printf "BASELINE STABILITY CHECK: simplified struct-copy in same context\n")
(printf "  Pre-0 M7 (nested prop-network + prop-net-hot struct-copy): 24 ns/call\n")
(printf "  This B.M7: single flat struct-copy with result captured (different shape;\n")
(printf "             primary purpose is context-stability anchor, not direct compare).\n")

(define base-cold (mock-cold 1000000 0 0 0 0 0))
;; Capture result in a mutable box to defeat dead-code elimination
(define b-m7-box (box base-cold))
(define b-m7-1
  (bench-ns "B.M7.1 struct-copy decrement n=1 (result captured)" 50000
    (set-box! b-m7-box (struct-copy-decrement-baseline base-cold 1))))

;; Also: a NESTED struct-copy that more faithfully mirrors real M7
(struct mock-network (hot warm cold) #:transparent)
(struct mock-hot (fuel) #:transparent)
(define mock-base-net
  (mock-network (mock-hot 1000000) (mock-cold 0 0 0 0 0 0) (mock-cold 0 0 0 0 0 0)))
(define b-m7-nested-box (box mock-base-net))
(define b-m7-nested
  (bench-ns "B.M7.2 NESTED struct-copy (mirrors real M7 pattern; result captured)" 50000
    (set-box! b-m7-nested-box
              (struct-copy mock-network mock-base-net
                [hot (struct-copy mock-hot (mock-network-hot mock-base-net)
                       [fuel (sub1 (mock-hot-fuel (mock-network-hot mock-base-net)))])]))))

(printf "\n")

;; ============================================================
;; §13.6.A OPTION 13 DEFERRED-WRITE SPIKE
;; ============================================================
;;
;; The Option 13 pattern (from D.4 §10.3.A):
;; - BSP scheduler reads cell at round entry → local-var (box)
;; - Per fire: inline local-var decrement + threshold check (~2 ns target)
;; - At round exit: flush local-var to cell (~6 ns)
;; - On exhaustion (rare): immediate flush + contradiction
;;
;; The measurements compare:
;; - Function-call variant (general; matches §10.3.A pseudocode)
;; - Macro-inline variant (Option 14; if savings ≥ 1 ns/cycle apply per §10.4)

(printf "=== §13.6.A OPTION 13 DEFERRED-WRITE SPIKE ===\n\n")

;; Local-var scheduler-scratch
(define local-fuel-cost-O13 (box 0))

;; Function-call variant of per-fire (general; ~3-4 ns expected)
(define (option13-per-fire-fn budget)
  (define new-cost (+ (unbox local-fuel-cost-O13) 1))
  (set-box! local-fuel-cost-O13 new-cost)
  (when (>= new-cost budget) 'crossed))

;; Macro-inline variant (Option 14 specialization; ~2 ns expected)
(define-syntax-rule (option13-per-fire-inline budget)
  (let ([new-cost (+ (unbox local-fuel-cost-O13) 1)])
    (set-box! local-fuel-cost-O13 new-cost)
    (when (>= new-cost budget) 'crossed)))

;; Round-boundary cell-read (entry)
(define (option13-round-entry net)
  (set-box! local-fuel-cost-O13 (specialized-cell-read net)))

;; Round-boundary cell-write (exit)
(define (option13-round-exit net)
  (specialized-cell-write-fast net (unbox local-fuel-cost-O13)))

;; Simulate a full BSP round of N fires (function-call variant)
(define (simulate-round-of-N-fn N net)
  (option13-round-entry net)
  (for ([_ (in-range N)])
    (option13-per-fire-fn spike-budget))
  (option13-round-exit net))

;; Simulate a full BSP round of N fires (macro-inline variant)
(define-syntax-rule (simulate-round-of-N-inline N net)
  (begin
    (option13-round-entry net)
    (for ([_ (in-range N)])
      (option13-per-fire-inline spike-budget))
    (option13-round-exit net)))

;; ----------------------------------------
;; W1-O13: Per-fire local-var decrement + threshold check
;; ----------------------------------------
(printf "W1-O13: Per-fire local-var decrement + threshold check\n")
(printf "  Target: <= 5 ns/call (estimate: 2-4 ns)\n")

;; W1-O13a: function-call variant
(set-box! local-fuel-cost-O13 0)
(define w1-o13a
  (bench-ns "W1-O13a function-call per-fire" 50000
    (option13-per-fire-fn spike-budget)))

;; W1-O13b: macro-inline variant
(set-box! local-fuel-cost-O13 0)
(define w1-o13b
  (bench-ns "W1-O13b macro-inline per-fire" 50000
    (option13-per-fire-inline spike-budget)))

(printf "\n")

;; ----------------------------------------
;; W2a-O13: Per-round cell-read at entry
;; ----------------------------------------
(printf "W2a-O13: Per-round cell-read at entry\n")
(printf "  Target: ≤ 15 ns/call\n")

(set-mock-net-fuel-cost! spike-net 12345)
(define w2a-o13
  (bench-ns "W2a-O13.1 cell-read at round entry" 50000
    (option13-round-entry spike-net)))

(printf "\n")

;; ----------------------------------------
;; W2b-O13: Per-round cell-write at exit
;; ----------------------------------------
(printf "W2b-O13: Per-round cell-write at exit\n")
(printf "  Target: ≤ 15 ns/call (using specialized cell-write fast path)\n")

(set-mock-net-fuel-cost! spike-net 0)
(set-box! local-fuel-cost-O13 100)  ;; representative final-round value
(define w2b-o13
  (bench-ns "W2b-O13.1 cell-write at round exit" 50000
    (option13-round-exit spike-net)))

(printf "\n")

;; ----------------------------------------
;; W3-O13: Amortized per-fire cost across BSP round of N fires
;; ----------------------------------------
(printf "W3-O13: Amortized per-fire cost across round of N fires\n")
(printf "  Target: ≤ 3 ns/cycle at N=100\n")
(printf "  Compares function-call (W3-O13a) vs macro-inline (W3-O13b) variants\n")

;; W3-O13a: function-call variant, multiple N
(define w3-o13a-10
  (bench-ns "W3-O13a.1 function-call: N=10 fires/round" 5000
    (simulate-round-of-N-fn 10 spike-net)))
(define w3-o13a-100
  (bench-ns "W3-O13a.2 function-call: N=100 fires/round" 500
    (simulate-round-of-N-fn 100 spike-net)))
(define w3-o13a-1000
  (bench-ns "W3-O13a.3 function-call: N=1000 fires/round" 50
    (simulate-round-of-N-fn 1000 spike-net)))

;; W3-O13b: macro-inline variant, multiple N
(define w3-o13b-10
  (bench-ns "W3-O13b.1 macro-inline: N=10 fires/round" 5000
    (simulate-round-of-N-inline 10 spike-net)))
(define w3-o13b-100
  (bench-ns "W3-O13b.2 macro-inline: N=100 fires/round" 500
    (simulate-round-of-N-inline 100 spike-net)))
(define w3-o13b-1000
  (bench-ns "W3-O13b.3 macro-inline: N=1000 fires/round" 50
    (simulate-round-of-N-inline 1000 spike-net)))

;; Convert to per-fire (bench-ns measures per-call where each call = one round of N fires)
(define w3-o13a-10-per-fire (/ w3-o13a-10 10.0))
(define w3-o13a-100-per-fire (/ w3-o13a-100 100.0))
(define w3-o13a-1000-per-fire (/ w3-o13a-1000 1000.0))
(define w3-o13b-10-per-fire (/ w3-o13b-10 10.0))
(define w3-o13b-100-per-fire (/ w3-o13b-100 100.0))
(define w3-o13b-1000-per-fire (/ w3-o13b-1000 1000.0))

(printf "\n")
(printf "  W3-O13a function-call amortized per-fire:\n")
(printf "    N=10:    ~a ns/cycle\n" (~r w3-o13a-10-per-fire #:precision '(= 2)))
(printf "    N=100:   ~a ns/cycle\n" (~r w3-o13a-100-per-fire #:precision '(= 2)))
(printf "    N=1000:  ~a ns/cycle\n" (~r w3-o13a-1000-per-fire #:precision '(= 2)))
(printf "  W3-O13b macro-inline amortized per-fire:\n")
(printf "    N=10:    ~a ns/cycle\n" (~r w3-o13b-10-per-fire #:precision '(= 2)))
(printf "    N=100:   ~a ns/cycle\n" (~r w3-o13b-100-per-fire #:precision '(= 2)))
(printf "    N=1000:  ~a ns/cycle\n" (~r w3-o13b-1000-per-fire #:precision '(= 2)))
(printf "\n")

;; ----------------------------------------
;; W4-O13: Exhaustion-path cost
;; ----------------------------------------
(printf "W4-O13: Exhaustion-path cost (flush + contradiction-write)\n")
(printf "  Target: ≤ 50 ns/call (rare; once per workload typically)\n")

;; Setup: small-budget cell so write triggers on-write check
;; Each iteration: reset cost to 0; set local-var to budget; flush triggers crossing
(define exhaustion-spike-net (mock-net 0 1000 0))
(define w4-o13
  (bench-ns "W4-O13.1 exhaustion flush + contradiction" 10000
    (begin
      (set-mock-net-fuel-cost! exhaustion-spike-net 0)
      (set-box! local-fuel-cost-O13 1001)
      (specialized-cell-write-fast exhaustion-spike-net
                                   (unbox local-fuel-cost-O13)))))

(printf "  W4-O13 crossing-count verification (should be 10100): ~a\n"
        (mock-net-crossing-count exhaustion-spike-net))
(printf "\n")

;; ============================================================
;; §13.6.A DECISION EVALUATION
;; ============================================================

(printf "=== §13.6.A OPTION 13 DECISION EVALUATION ===\n\n")

(printf "  W1-O13a function-call per-fire:           ~a ns/call\n"
        (~r w1-o13a #:precision '(= 1)))
(printf "  W1-O13b macro-inline per-fire:            ~a ns/call\n"
        (~r w1-o13b #:precision '(= 1)))
(printf "  W2a-O13 round-entry cell-read:            ~a ns/call\n"
        (~r w2a-o13 #:precision '(= 1)))
(printf "  W2b-O13 round-exit cell-write:            ~a ns/call\n"
        (~r w2b-o13 #:precision '(= 1)))
(printf "  W3-O13a function-call amortized N=100:    ~a ns/cycle\n"
        (~r w3-o13a-100-per-fire #:precision '(= 2)))
(printf "  W3-O13b macro-inline amortized N=100:     ~a ns/cycle\n"
        (~r w3-o13b-100-per-fire #:precision '(= 2)))
(printf "  W4-O13 exhaustion flush + contradiction:  ~a ns/call\n"
        (~r w4-o13 #:precision '(= 1)))

(printf "\n  Targets per §13.6.A:\n")
(define tO13-1a (<= w1-o13a 5))
(define tO13-1b (<= w1-o13b 5))
(define tO13-2a (<= w2a-o13 15))
(define tO13-2b (<= w2b-o13 15))
(define tO13-3a (<= w3-o13a-100-per-fire 3))
(define tO13-3b (<= w3-o13b-100-per-fire 3))
(define tO13-4 (<= w4-o13 50))

(printf "    W1-O13a (fn-call) ≤ 5 ns:        ~a (~a)\n"
        (if tO13-1a "✓ PASS" "✗ FAIL")
        (~r w1-o13a #:precision '(= 1)))
(printf "    W1-O13b (macro) ≤ 5 ns:          ~a (~a)\n"
        (if tO13-1b "✓ PASS" "✗ FAIL")
        (~r w1-o13b #:precision '(= 1)))
(printf "    W2a-O13 ≤ 15 ns:                  ~a (~a)\n"
        (if tO13-2a "✓ PASS" "✗ FAIL")
        (~r w2a-o13 #:precision '(= 1)))
(printf "    W2b-O13 ≤ 15 ns:                  ~a (~a)\n"
        (if tO13-2b "✓ PASS" "✗ FAIL")
        (~r w2b-o13 #:precision '(= 1)))
(printf "    W3-O13a N=100 ≤ 3 ns:             ~a (~a)\n"
        (if tO13-3a "✓ PASS" "✗ FAIL")
        (~r w3-o13a-100-per-fire #:precision '(= 2)))
(printf "    W3-O13b N=100 ≤ 3 ns:             ~a (~a)\n"
        (if tO13-3b "✓ PASS" "✗ FAIL")
        (~r w3-o13b-100-per-fire #:precision '(= 2)))
(printf "    W4-O13 ≤ 50 ns:                   ~a (~a)\n"
        (if tO13-4 "✓ PASS" "✗ FAIL")
        (~r w4-o13 #:precision '(= 1)))

;; A/B/C comparison
(printf "\n  A/B/C COMPARISON:\n")
(printf "    A (current native struct-copy; B.M7.2):       ~a ns/cycle\n"
        (~r b-m7-nested #:precision '(= 1)))
(printf "    B (D.4 per-fire cell-write w/ dispatch; W1+): ~a ns/cycle\n"
        (~r w1+1 #:precision '(= 1)))
(printf "    C-fn (Option 13 function-call N=100):         ~a ns/cycle\n"
        (~r w3-o13a-100-per-fire #:precision '(= 2)))
(printf "    C-macro (Option 13 + Option 14 macro N=100):  ~a ns/cycle\n"
        (~r w3-o13b-100-per-fire #:precision '(= 2)))

;; Option 14 specialization decision: macro saves ≥ 1 ns/cycle vs fn-call
(define option14-savings (- w3-o13a-100-per-fire w3-o13b-100-per-fire))
(printf "\n  Option 14 specialization (macro vs fn-call savings at N=100): ~a ns/cycle\n"
        (~r option14-savings #:precision '(= 2)))
(printf "    ~a\n"
        (cond
          [(>= option14-savings 1.0) "→ APPLY Option 14 macro specialization (savings ≥ 1 ns/cycle)"]
          [(>= option14-savings 0.5) "→ INVESTIGATE Option 14 (savings 0.5-1 ns/cycle; marginal)"]
          [else                       "→ SKIP Option 14 (savings < 0.5 ns/cycle; not worth complexity)"]))

;; Overall decision per §13.6.A criteria
;; PASS:  W1-O13 ≤ 5 ns + W3-O13 ≤ 3 ns at N=100 + amortized ≤ B (D.4 per-fire 6.4 ns)
;; FAIL:  W1-O13 > 10 ns OR amortized > B
;; MIXED: in between
(define o13-best-w1 (min w1-o13a w1-o13b))
(define o13-best-amortized (min w3-o13a-100-per-fire w3-o13b-100-per-fire))

(define o13-pass? (and (<= o13-best-w1 5)
                       (<= o13-best-amortized 3)
                       (< o13-best-amortized w1+1)))  ;; better than D.4 per-fire
(define o13-fail? (or (> o13-best-w1 10)
                      (> o13-best-amortized w1+1)))

(printf "\n=== §13.6.A DECISION: ")
(cond
  [o13-pass?
   (printf "✓ PASS\n")
   (printf "    → Option 13 canonical for Phase 1C\n")
   (printf "    → BSP fire sites migrate to deferred-write pattern\n")
   (printf "    → D.4 per-fire pattern (Option Y) NOT implemented; reference only\n")]
  [o13-fail?
   (printf "✗ FAIL\n")
   (printf "    → Fall back to D.4 per-fire pattern (Option Y)\n")
   (printf "    → §13.6 spike already validated Option Y; Phase 1C uses per-fire net-cell-write\n")
   (printf "    → Option 13 explored but falsified\n")]
  [else
   (printf "⚠ MIXED\n")
   (printf "    → Per-fire fast but amortized higher than expected, or vice-versa\n")
   (printf "    → Investigate before Phase 1C-ii commits\n")])
(printf "=== END §13.6.A SPIKE ===\n\n")

;; ============================================================
;; DECISION EVALUATION (§13.6 — kept for the original spike)
;; ============================================================

(printf "=== DECISION EVALUATION ===\n\n")

;; Aggregate W1 across n variants (representative average)
(define w1-avg (/ (+ w1-1 w1-2 w1-3) 3.0))
(define w4-val w4-1)
(define cycle (+ w1-avg w4-val))

;; W3 GC measurement
(define w3-gc-ms (vector-ref w3-1 1))
(define w3-major-gc? (> w3-gc-ms 0.001))  ; threshold for "any major-GC observed"

;; W3 memory profile
(define w3-alloc-kb (/ (vector-ref w3-2 1) 1024.0))
(define w3-retain-kb (/ (vector-ref w3-2 2) 1024.0))

(printf "  W1  specialized cell-write FAST PATH (avg):          ~a ns/call\n"
        (~r w1-avg #:precision '(= 1)))
(printf "  W1+ specialized cell-write WITH dispatch overhead:   ~a ns/call (realistic upper bound)\n"
        (~r w1+1 #:precision '(= 1)))
(printf "  W2  specialized cell-write THRESHOLD CROSSING:       ~a ns/call\n"
        (~r w2-1 #:precision '(= 1)))
(printf "  W3  GC time during 5×100k decrements:                ~a ms (major-GC = ~a)\n"
        (~r w3-gc-ms #:precision '(= 3))
        (if w3-major-gc? "YES" "NO"))
(printf "  W3  alloc / retain (10×100k decrements):             ~a KB / ~a KB\n"
        (~r w3-alloc-kb #:precision '(= 1))
        (~r w3-retain-kb #:precision '(= 1)))
(printf "  W4  specialized cell-read:                           ~a ns/call\n"
        (~r w4-val #:precision '(= 1)))
(printf "  W1+ + W4 per-decrement cycle (realistic):            ~a ns\n"
        (~r (+ w1+1 w4-val) #:precision '(= 1)))
(printf "  B.M7.1 single struct-copy (result captured):         ~a ns/call\n"
        (~r b-m7-1 #:precision '(= 1)))
(printf "  B.M7.2 NESTED struct-copy (mirrors real M7):         ~a ns/call (Pre-0 M7: 24 ns)\n"
        (~r b-m7-nested #:precision '(= 1)))

(printf "\n  Targets per §13.6 (evaluated against W1+ realistic upper bound):\n")
(define realistic-cycle (+ w1+1 w4-val))
(define t1 (<= w1+1 30))
(define t2 (<= w2-1 200))
(define t3 (not w3-major-gc?))
(define t4 (<= w4-val 15))
(define t5 (<= realistic-cycle 45))
(printf "    W1+ ≤ 30 ns (with dispatch): ~a (~a)\n"
        (if t1 "✓ PASS" "✗ FAIL")
        (~r w1+1 #:precision '(= 1)))
(printf "    W2 ≤ 200 ns:                 ~a (~a)\n"
        (if t2 "✓ PASS" "✗ FAIL")
        (~r w2-1 #:precision '(= 1)))
(printf "    W3 zero major-GC:            ~a (~a ms)\n"
        (if t3 "✓ PASS" "✗ FAIL")
        (~r w3-gc-ms #:precision '(= 3)))
(printf "    W4 ≤ 15 ns:                  ~a (~a)\n"
        (if t4 "✓ PASS" "✗ FAIL")
        (~r w4-val #:precision '(= 1)))
(printf "    W1+W4 ≤ 45 ns (realistic):   ~a (~a)\n"
        (if t5 "✓ PASS" "✗ FAIL")
        (~r realistic-cycle #:precision '(= 1)))

;; Decision logic per §13.6 (uses W1+ with dispatch overhead for realistic eval)
(define pass? (and t1 t3 t4 t5))
(define fail? (or (> w1+1 60) (> realistic-cycle 60) w3-major-gc?))

(printf "\n=== DECISION: ")
(cond
  [pass?
   (printf "✓ PASS\n")
   (printf "    → D.4 canonical (specialized cell type framework feasible)\n")
   (printf "    → D.3 hybrid pivot retires before shipping\n")
   (printf "    → Issue #55 + DEFERRED.md entry close as \"superseded by D.4\"\n")]
  [fail?
   (printf "✗ FAIL\n")
   (printf "    → D.3 hybrid pivot remains canonical\n")
   (printf "    → Mark §4.6 + §13.6 + D.4 Revision Summary as \"explored-falsified\"\n")
   (printf "    → Issue #55 stays active; DEFERRED.md entry preserved\n")]
  [else
   (printf "⚠ MIXED\n")
   (printf "    → Re-design required\n")
   (printf "    → Cell-write fast but GC-pressured (or vice-versa)\n")
   (printf "    → Investigate sub-options (object pooling, alternative storage)\n")])
(printf "=== END SPIKE ===\n\n")
