#lang racket/base

;;;
;;; bench-tropical-fuel.rkt
;;; PPN 4C Tropical Quantale Addendum D.4 — Phase 1C-vi production microbenches
;;;
;;; PURPOSE: production-context measurement of the tropical-fuel cell-API + algebra
;;; under D.4 cell-as-canonical (post-1C-iv-b retirement). This file is the
;;; CANONICAL HOME for post-D.4 tropical-fuel microbenches; bench-ppn-track4c.rkt
;;; is a retirement stub pointing here (closes F5 mini-audit finding per §10.0.7).
;;;
;;; Distinct from bench-specialized-cell-spike.rkt (which is THROWAWAY spike code
;;; per §13.6 design intent): this file measures PRODUCTION primitives
;;; (make-prop-network, net-cell-read/write, fuel-cell-id) and ships in the
;;; benchmark suite as the long-term home for fuel-related measurements.
;;;
;;; MEASUREMENTS (per §10.0.7 δ2 + ε1 + η1 resolutions):
;;;
;;;   Allocation verification (D-1B-ii-3 per Phase 1V scope item #4):
;;;     - Per-decrement allocation: bench-mem on N=10000 fuel decrements
;;;     - Target: 0-allocation per write under fixnum on-write-check
;;;     - GC profile: bench-gc on 5×100k decrements
;;;     - Target: ZERO major-GC at 100k (matches R3 baseline)
;;;
;;;   Per-cycle production cost (A/B/C report's C measurements):
;;;     - Variant A round-entry batch cost (parallel BSP main loop pattern)
;;;     - Variant B per-fire local-var cost (sequential scheduler pattern)
;;;     - Cell-read cost at fast path
;;;     - Cell-write cost at fast path (no threshold crossing)
;;;
;;;   M10 — Residuation operator (read-time pure function) cost (per §9.10)
;;;   M11 — Tropical tensor (a + b) cost (per §9.10)
;;;   M12 — SRE domain registration overhead (per §9.10)
;;;   R4  — Cell layout cost (compound vs flat tagged-cell-value; per §9.10)
;;;
;;; CROSS-REFERENCES:
;;;   - bench-ppn-track4c.rkt — retirement stub points here
;;;   - bench-specialized-cell-spike.rkt — throwaway spike (§13.6); not production
;;;   - data/benchmarks/tropical-pre0-baseline-2026-04-26.txt — A baseline
;;;   - data/benchmarks/tropical-spike-d4-2026-05-14.txt — B reference (§13.6)
;;;   - data/benchmarks/tropical-spike-d4-option13-2026-05-15.txt — Option 13 spike
;;;   - design doc §10.0.7 + §13.7 — A/B/C report scope
;;;
;;; Usage:
;;;   "/Applications/Racket v9.0/bin/racket" \
;;;     racket/prologos/benchmarks/micro/bench-tropical-fuel.rkt
;;;

(require racket/list
         racket/format
         "../../tropical-fuel.rkt"
         (only-in "../../propagator.rkt"
                  make-prop-network
                  net-cell-read
                  net-cell-write
                  net-cell-reset
                  fuel-cell-id
                  fuel-budget-cell-id
                  init-fuel-local-var!
                  flush-fuel-local-var!)
         (only-in "../../sre-core.rkt"
                  lookup-domain))

;; ============================================================
;; TIMING INFRASTRUCTURE
;; (mirrors bench-specialized-cell-spike.rkt patterns per D-1C-vi-4 mitigation:
;;  "model after bench-specialized-cell-spike.rkt's patterns; uses same bench-mem
;;  /bench-gc macros; cross-check with 1B-iv test fixtures")
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
;; FIXTURE: production prop-network with fuel-cell-id (11) + fuel-budget-cell-id (12)
;; ============================================================

(define (fresh-net [fuel 1000000])
  (make-prop-network fuel))

;; ============================================================
;; SECTION 1: M10 — Residuation operator cost (per §9.10)
;; ============================================================

(displayln "")
(displayln "============================================================")
(displayln "SECTION 1: M10 — Residuation operator cost (pure function)")
(displayln "============================================================")

(define m10-1
  (bench-ns "M10.1 (tropical-left-residual 0 0)" 50000
            (tropical-left-residual 0 0)))

(define m10-2
  (bench-ns "M10.2 (tropical-left-residual 5 10)" 50000
            (tropical-left-residual 5 10)))

(define m10-3
  (bench-ns "M10.3 (tropical-left-residual 10 5) overspend" 50000
            (tropical-left-residual 10 5)))

(define m10-4
  (bench-ns "M10.4 (tropical-left-residual 5 +inf.0)" 50000
            (tropical-left-residual 5 +inf.0)))

(define m10-5
  (bench-ns "M10.5 (tropical-left-residual +inf.0 5) vacuous" 50000
            (tropical-left-residual +inf.0 5)))

;; ============================================================
;; SECTION 2: M11 — Tropical tensor (a + b) cost (per §9.10)
;; ============================================================

(displayln "")
(displayln "============================================================")
(displayln "SECTION 2: M11 — Tropical tensor (cost composition)")
(displayln "============================================================")

(define m11-1
  (bench-ns "M11.1 (tropical-fuel-tensor 3 5) small fixnum" 50000
            (tropical-fuel-tensor 3 5)))

(define m11-2
  (bench-ns "M11.2 (tropical-fuel-tensor 0 5) identity" 50000
            (tropical-fuel-tensor 0 5)))

(define m11-3
  (bench-ns "M11.3 (tropical-fuel-tensor +inf.0 5) absorbing" 50000
            (tropical-fuel-tensor +inf.0 5)))

;; ============================================================
;; SECTION 3: M12 — SRE domain registration overhead (per §9.10)
;; ============================================================

(displayln "")
(displayln "============================================================")
(displayln "SECTION 3: M12 — SRE domain registration / lookup overhead")
(displayln "============================================================")

;; Registration is one-time at module load. We measure REGISTRATION here
;; via tropical-fuel-sre-domain lookup cost (the proxy for "is the registration
;; lookup machinery cheap"); the one-time registration cost is captured
;; by module load time which is not benchable in this form.

(define m12-1
  (bench-ns "M12.1 (lookup-domain 'tropical-fuel)" 50000
            (lookup-domain 'tropical-fuel)))

;; M12 alloc check: lookup should not allocate
(define m12-mem
  (bench-mem "M12.mem 10000 lookups alloc+retain" 10
             (for ([_ (in-range 10000)])
               (lookup-domain 'tropical-fuel))))

;; ============================================================
;; SECTION 4: Production cell-API costs (C measurements for A/B/C report)
;; ============================================================

(displayln "")
(displayln "============================================================")
(displayln "SECTION 4: Production cell-API costs (C measurements)")
(displayln "============================================================")

(define c-net (fresh-net 1000000))

;; C-M13: Cell-read at fast path (replaces Pre-0 M13 prop-network-fuel macro
;; access; A baseline = 6 ns)
(define c-m13
  (bench-ns "C-M13 (net-cell-read net fuel-cell-id)" 50000
            (net-cell-read c-net fuel-cell-id)))

;; C-M7: Cell-write at fast path, no threshold crossing
;; (replaces Pre-0 M7 struct-copy decrement; A baseline = 24 ns)
;; Note: this measures the COST of net-cell-write itself; the result is a NEW
;; net (immutable interface), but the underlying mutable-counter storage means
;; the per-call cost is dominated by the dispatch + check, not by allocation.
(define c-m7
  (bench-ns "C-M7 (net-cell-write net fuel-cell-id n) fast path" 50000
            (net-cell-write c-net fuel-cell-id 999999)))

;; C-M8: Check-site via net-cell-read + (<= ...) test
;; (replaces Pre-0 M8 inline check; A baseline = 6 ns)
;; Under D.4: check sites use net-contradiction? OR direct cell-read + comparison
;; depending on context; this measures the cell-read variant
(define c-m8
  (bench-ns "C-M8 cell-read + (<= remaining 0) check" 50000
            (<= (net-cell-read c-net fuel-cell-id) 0)))

;; ============================================================
;; SECTION 4.5: Option 13 deferred-write AMORTIZED cost (production-context)
;; (matches §13.6.A spike's W3-O13 amortized-per-fire pattern; gives
;;  apples-to-apples comparison with the §13.6.A spike result of 2.16 ns/cycle)
;; ============================================================

(displayln "")
(displayln "============================================================")
(displayln "SECTION 4.5: Option 13 deferred-write AMORTIZED cost")
(displayln "(production-context Variant A + Variant B simulations)")
(displayln "Target: amortized per-fire ≤ 5 ns/cycle at N=100 (§13.7 1B-ii gate)")
(displayln "Spike reference: §13.6.A W3-O13a.2 = 2.16 ns/cycle (MOCK)")
(displayln "============================================================")

;; -------- Variant A — parallel BSP main loop pattern --------
;; ONE net-cell-write per BSP round; N "fires" represented as no-op work between
;; (in real production this is propagator firing — variable cost; not amortized here).
;; This measures the FUEL-INFRASTRUCTURE OVERHEAD of Variant A's deferred-write.

(define (variant-a-round-simulation net N)
  ;; Simulate one BSP round: 1 cell-write at round entry; N "fires" (no-ops).
  (define new-fuel (- (net-cell-read net fuel-cell-id) N))
  (define net+fuel (net-cell-write net fuel-cell-id new-fuel))
  ;; N "fires" — represented as no-op work (real fires are variable cost).
  (for ([_ (in-range N)]) (void))
  net+fuel)

(define va-N100
  (bench-ns "C-Var-A.1 round of N=100: 1 cell-write + N no-op fires" 500
            (variant-a-round-simulation c-net 100)))

(define va-N1000
  (bench-ns "C-Var-A.2 round of N=1000: 1 cell-write + N no-op fires" 50
            (variant-a-round-simulation c-net 1000)))

(define va-per-fire-100 (/ va-N100 100.0))
(define va-per-fire-1000 (/ va-N1000 1000.0))

(printf "\n")
(printf "  Variant A amortized per-fire:\n")
(printf "    N=100:   ~a ns/cycle\n" (~r va-per-fire-100 #:precision '(= 2)))
(printf "    N=1000:  ~a ns/cycle\n" (~r va-per-fire-1000 #:precision '(= 2)))

;; -------- Variant B — sequential scheduler pattern --------
;; init-fuel-local-var! + N set-box! decrements + flush-fuel-local-var!
;; This uses the REAL PRODUCTION helpers from propagator.rkt (the spike used MOCKs).

(define (variant-b-phase-simulation net N)
  ;; Simulate one sequential phase: init helper + N box decrements + flush helper
  (define local-fuel (init-fuel-local-var! net))
  (for ([_ (in-range N)])
    (set-box! local-fuel (sub1 (unbox local-fuel))))
  (flush-fuel-local-var! net local-fuel))

(define vb-N100
  (bench-ns "C-Var-B.1 phase of N=100: init + N decrements + flush" 500
            (variant-b-phase-simulation c-net 100)))

(define vb-N1000
  (bench-ns "C-Var-B.2 phase of N=1000: init + N decrements + flush" 50
            (variant-b-phase-simulation c-net 1000)))

(define vb-per-fire-100 (/ vb-N100 100.0))
(define vb-per-fire-1000 (/ vb-N1000 1000.0))

(printf "\n")
(printf "  Variant B amortized per-fire (uses REAL production helpers):\n")
(printf "    N=100:   ~a ns/cycle\n" (~r vb-per-fire-100 #:precision '(= 2)))
(printf "    N=1000:  ~a ns/cycle\n" (~r vb-per-fire-1000 #:precision '(= 2)))

;; ============================================================
;; SECTION 5: Allocation verification (D-1B-ii-3 per §11.3 Phase 1V item #4)
;; ============================================================

(displayln "")
(displayln "============================================================")
(displayln "SECTION 5: Allocation verification (D-1B-ii-3 / Phase 1V item #4)")
(displayln "Target: 0-allocation per write under fixnum on-write-check")
(displayln "============================================================")

;; ALLOC-1: 10000 fuel decrements via net-cell-write fast path
;; Verifies the on-write-check closure ((<= new 0)) is allocation-free.
;; Pre-0 A7.2 baseline (struct-copy decrements at 10k): wall=0.116 ms; alloc=625.2 KB
;; D.4 target: significantly lower allocation (ideally 0 per call beyond fixnum boxing)
(define alloc-1
  (bench-mem "ALLOC-1 10000 fuel decrements alloc+retain" 10
             (let loop ([net (fresh-net 1000000)] [i 0])
               (cond
                 [(= i 10000) net]
                 [else (loop (net-cell-write net fuel-cell-id (- 1000000 i))
                             (+ i 1))]))))

;; ALLOC-2: per-decrement allocation rate at 100k
;; Pre-0 A7.3 baseline: wall=1.171 ms; alloc=6251.0 KB; 62.5 bytes/dec
;; D.4 target: dramatically lower bytes/dec (specialized cell fast path)
(define alloc-2
  (bench-mem "ALLOC-2 100000 fuel decrements alloc+retain" 5
             (let loop ([net (fresh-net 1000000)] [i 0])
               (cond
                 [(= i 100000) net]
                 [else (loop (net-cell-write net fuel-cell-id (- 1000000 i))
                             (+ i 1))]))))

;; ============================================================
;; SECTION 6: GC profile (matches R3 baseline; D-1B-ii-3 GC dimension)
;; ============================================================

(displayln "")
(displayln "============================================================")
(displayln "SECTION 6: GC profile (R3-equivalent; target: ZERO major-GC at 100k)")
(displayln "============================================================")

;; GC-1: 100k decrements GC profile (matches Pre-0 R3.1 baseline pattern)
;; Pre-0 R3.1: wall=1.183 ms; gc=0.000 ms (0.0%)
;; D.4 target: matches baseline (ZERO major-GC; minor-GC bounded)
(define gc-1
  (bench-gc "GC-1 100k fuel decrements GC profile" 5
            (let loop ([net (fresh-net 1000000)] [i 0])
              (cond
                [(= i 100000) net]
                [else (loop (net-cell-write net fuel-cell-id (- 1000000 i))
                            (+ i 1))]))))

;; ============================================================
;; SECTION 7: A7-equivalent — high-frequency decrement scaling
;; (production C for A/B/C report; A baseline = Pre-0 A7.1/A7.2/A7.3)
;; ============================================================

(displayln "")
(displayln "============================================================")
(displayln "SECTION 7: A7-equivalent — high-frequency decrement scaling")
(displayln "============================================================")

(define a7-1
  (bench-mem "C-A7.1 1000 decrements (Pre-0: 62.7 bytes/dec)" 50
             (let loop ([net (fresh-net 1000000)] [i 0])
               (cond
                 [(= i 1000) net]
                 [else (loop (net-cell-write net fuel-cell-id (- 1000000 i))
                             (+ i 1))]))))

(define a7-2
  (bench-mem "C-A7.2 10000 decrements (Pre-0: 62.5 bytes/dec)" 20
             (let loop ([net (fresh-net 1000000)] [i 0])
               (cond
                 [(= i 10000) net]
                 [else (loop (net-cell-write net fuel-cell-id (- 1000000 i))
                             (+ i 1))]))))

(define a7-3
  (bench-mem "C-A7.3 100000 decrements (Pre-0: 62.5 bytes/dec)" 5
             (let loop ([net (fresh-net 1000000)] [i 0])
               (cond
                 [(= i 100000) net]
                 [else (loop (net-cell-write net fuel-cell-id (- 1000000 i))
                             (+ i 1))]))))

;; ============================================================
;; SECTION 8: R4 — Cell layout cost (compound vs flat tagged-cell-value)
;; ============================================================

(displayln "")
(displayln "============================================================")
(displayln "SECTION 8: R4 — Cell layout cost (specialized cell representation)")
(displayln "============================================================")

;; R4-1: Per-cell base memory (fresh prop-network with 2 fuel cells)
;; Captures the cost of constructing a fresh prop-network including:
;; - Base prop-network struct
;; - 2 registered specialized fuel cells (cell-id 11/12)
;; - Cell-meta entries
;; - On-write-check closures
(define r4-1
  (bench-mem "R4.1 make-prop-network fresh allocation" 50
             (fresh-net 1000000)))

;; R4-2: 500 fresh prop-network allocations
;; Captures linear scaling of fuel-cell registration
(define r4-2
  (bench-mem "R4.2 500 fresh prop-network allocations" 5
             (let loop ([nets '()] [i 0])
               (cond
                 [(= i 500) nets]
                 [else (loop (cons (fresh-net 1000) nets) (+ i 1))]))))

;; ============================================================
;; SUMMARY
;; ============================================================

(displayln "")
(displayln "============================================================")
(displayln "SUMMARY (1C-vi production C measurements)")
(displayln "============================================================")
(displayln "")
(displayln "Algebra primitives (read-time pure functions):")
(printf "  M10 residuation operator       ~a ns/call (boundary case)\n"
        (~r m10-1 #:precision '(= 1)))
(printf "  M11 tropical tensor            ~a ns/call (3 cases)\n"
        (~r m11-1 #:precision '(= 1)))
(printf "  M12 SRE domain lookup          ~a ns/call\n"
        (~r m12-1 #:precision '(= 1)))
(displayln "")
(displayln "Cell-API per-call cost (single net-cell-write/read; informational):")
(printf "  C-M7 cell-write per-call       ~a ns/call  (A: 24 ns struct-copy; B ref §13.6: 6.4 ns mock)\n"
        (~r c-m7 #:precision '(= 1)))
(printf "  C-M8 check-site per-call       ~a ns/call  (A: 6 ns inline check)\n"
        (~r c-m8 #:precision '(= 1)))
(printf "  C-M13 cell-read per-call       ~a ns/call  (A: 6 ns macro; B ref §13.6: 0.8 ns mock)\n"
        (~r c-m13 #:precision '(= 1)))
(displayln "")
(displayln "Option 13 deferred-write AMORTIZED cost (apples-to-apples with §13.6.A spike):")
(printf "  C-Var-A round amortized N=100  ~a ns/cycle (parallel BSP; 1 cell-write/round)\n"
        (~r va-per-fire-100 #:precision '(= 2)))
(printf "  C-Var-A round amortized N=1000 ~a ns/cycle\n"
        (~r va-per-fire-1000 #:precision '(= 2)))
(printf "  C-Var-B phase amortized N=100  ~a ns/cycle (sequential; init+N×box+flush)\n"
        (~r vb-per-fire-100 #:precision '(= 2)))
(printf "  C-Var-B phase amortized N=1000 ~a ns/cycle\n"
        (~r vb-per-fire-1000 #:precision '(= 2)))
(displayln "  Spike reference: §13.6.A W3-O13a.2 = 2.16 ns/cycle (MOCK; CHAMP-free dispatch)")
(displayln "  Production overhead = amortized - 2.16 ns (CHAMP cell-meta lookup; immutable interface)")
(displayln "")
(displayln "Allocation + GC:")
(printf "ALLOC-1 10k decrements       alloc=~a KB  (Pre-0 A7.2: 625.2 KB)\n"
        (~r (/ (vector-ref alloc-1 1) 1024.0) #:precision '(= 1)))
(printf "ALLOC-2 100k decrements      alloc=~a KB  (Pre-0 A7.3: 6251.0 KB)\n"
        (~r (/ (vector-ref alloc-2 1) 1024.0) #:precision '(= 1)))
(printf "GC-1 100k decrements         gc=~a ms     (Pre-0 R3.1: 0.000 ms)\n"
        (~r (vector-ref gc-1 1) #:precision '(= 3)))
(displayln "")
(displayln "Cross-references:")
(displayln "  A baseline:  data/benchmarks/tropical-pre0-baseline-2026-04-26.txt")
(displayln "  B reference: data/benchmarks/tropical-spike-d4-2026-05-14.txt")
(displayln "  Option 13:   data/benchmarks/tropical-spike-d4-option13-2026-05-15.txt")
(displayln "  Design:      docs/tracking/2026-04-26_PPN_4C_TROPICAL_QUANTALE_ADDENDUM_DESIGN.md")
(displayln "               §10.0.7 (1C-vi mini-design+audit), §13.7 (per-phase measurement plan)")
(displayln "")
(displayln "(Production C measurements complete. A/B/C report follows in 1C-vi commit 2.)")
