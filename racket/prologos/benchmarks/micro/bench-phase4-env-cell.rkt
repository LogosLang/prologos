#lang racket/base

;;;
;;; bench-phase4-env-cell.rkt
;;; PPN 4C addendum Phase 4A.0 — Pre-0 microbench for env-cell variant comparison
;;;
;;; PURPOSE: measurement-driven selection of env-cell architecture for Phase 4A
;;; (current-prelude-env migration / flip-the-read-path). Per addendum §18.12
;;; Pre-0 plan + audit refinements (2026-05-26 session).
;;;
;;; VARIANTS (per §18.12.1 + audit refinements):
;;;   A — Status quo: parameter hash (current-prelude-env), realistic 2-layer dispatch
;;;   B — Single specialized §4.6 warm+general cell, hash-union merge
;;;   D — Two-level: registry specialized cell + per-name binding cells
;;;
;;; (Variant C — single cell + component-paths — measures identically to B for
;;;  read-only workloads per audit Q-Bench5 finding 4; deferred to W4 propagator-
;;;  coupled measurement when component-paths' per-key firing precision matters.)
;;;
;;; WORKLOADS:
;;;   W1 — N=10 forms, sequential lookups (small file)
;;;   W2 — N=50 forms, sequential lookups (mid file)
;;;   W3 — N=200 forms, sequential lookups (large library)
;;;   W5 — Memory: cells allocated + retained bytes (via bench-mem)
;;;
;;; (W4 — mutual recursion residuation — needs ~40-60 LoC propagator install
;;;  harness; deferred to follow-up bench per §18.12.3 W4 correctness-gate-deferral.)
;;;
;;; SETUP-TIME measurement included per audit Q-Bench5 finding 5 — Variant D
;;; allocates N+1 cells; setup cost matters for Phase 4's add+lookup balance.
;;;
;;; HONEST FRAMING (per §18.10.3 audit refinement):
;;;   The §4.6 framework's fast-path applies to 'hot + 'monotone-counter cells
;;;   only. All env-cell variants are 'warm + 'general → slow-path. The framework
;;;   provides organizational discipline (cell-meta declaration) but NOT fast-path
;;;   perf gain for our variants. Variant ranking competes on cell-layer
;;;   architecture (mega-cell vs two-level vs hash-shape), not on §4.6 dispatch.
;;;
;;; CRITERIA AS GUIDANCE (user refinement 2026-05-26):
;;;   §18.12.3 criteria are guidance for collaborative review aligned with
;;;   principles, NOT strict gates. This bench produces measurements; decision is
;;;   dialogue-driven.
;;;
;;; CROSS-REFERENCES:
;;;   - addendum §18.12 — Pre-0 microbench plan
;;;   - addendum §18.10.3 — perf characteristics
;;;   - bench-tropical-fuel.rkt:71-135 — bench-ns/mem macros (verbatim template)
;;;   - bench-meta-lifecycle.rkt:467-557 — N-variant comparison template
;;;   - global-env.rkt:192-213 — Variant A baseline lookup shape
;;;
;;; USAGE:
;;;   "/Applications/Racket v9.0/bin/racket" \
;;;     racket/prologos/benchmarks/micro/bench-phase4-env-cell.rkt
;;;

(require racket/list
         racket/format
         (only-in "../../propagator.rkt"
                  make-prop-network
                  net-cell-read
                  net-cell-write)
         (only-in "../../specialized-cells.rkt"
                  net-register-specialized-cell)
         (only-in "../../infra-cell.rkt"
                  merge-hasheq-replace))

;; ============================================================
;; TIMING INFRASTRUCTURE
;; (verbatim from bench-tropical-fuel.rkt:71-135 per audit Q-Bench1)
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
;; FIXTURES
;; ============================================================

;; Synthetic name + entry generators. Names are interned symbols (cheap eq?).
;; Entries are cons-pair of type-symbol + value (mirrors global-env entries
;; per global-env.rkt:248 `(cons type value)` shape).

(define (gen-names N)
  (for/list ([i (in-range N)]) (string->symbol (format "name-~a" i))))

(define (gen-entry i) (cons 'Int-type i))

;; Per-name cell merge function (Variant D): replace semantics.
;; Mirrors merge-replace at global-env.rkt:121, 354 — last-write-wins on cell.
(define (replace-merge old new) new)

;; ============================================================
;; VARIANT A — Status quo: parameter hash + realistic 2-layer dispatch
;; ============================================================
;; Realistic baseline per audit Q-Bench3: global-env-lookup-type reads through
;; 2 layers (definition-cells-content + prelude-env fallback). Captures
;; parameter-read overhead via parameterize wrapper at measurement time.

(define current-bench-layer-1 (make-parameter (hasheq)))
(define current-bench-layer-2 (make-parameter (hasheq)))

(define (variant-a-setup N)
  (define names (gen-names N))
  (define env (for/fold ([h (hasheq)]) ([n names] [i (in-naturals)])
                (hash-set h n (gen-entry i))))
  ;; Track 7 dual-write: same data in both layers (production behavior)
  (values names env env))

(define (variant-a-lookup-realistic name)
  ;; Mirrors global-env-lookup-type's 2-layer dispatch shape
  (or (hash-ref (current-bench-layer-1) name #f)
      (hash-ref (current-bench-layer-2) name #f)))

;; ============================================================
;; VARIANT B — Single specialized §4.6 warm+general cell
;; ============================================================
;; One cell holds entire name→entry hasheq. Read = cell-read + hash-ref.
;; Cell is 'warm + 'general → slow-path (§4.6 fast-path inapplicable per
;; audit Q-Bench5 finding 3).

(define (variant-b-setup N)
  (define net (make-prop-network 1000000))
  (define-values (net1 cid)
    (net-register-specialized-cell net (hasheq) merge-hasheq-replace
      #:tier 'warm #:storage 'general #:fires-on 'any-change))
  (define names (gen-names N))
  (define net2 (for/fold ([n net1]) ([nm names] [i (in-naturals)])
                 (net-cell-write n cid (hasheq nm (gen-entry i)))))
  (values names net2 cid))

(define (variant-b-lookup net cid name)
  (hash-ref (net-cell-read net cid) name #f))

;; ============================================================
;; VARIANT D — Two-level: registry cell + per-name binding cells
;; ============================================================
;; Mirrors Track 7 Phase 7d per-name cell pattern (global-env.rkt:107-124,
;; 345-360) but lifts the name→cell-id registry to a cell (today it's a
;; Racket parameter). Each name has its own specialized 'warm + 'general
;; cell. Read = registry cell-read + hash-ref + per-name cell-read.

(define (variant-d-setup N)
  (define net (make-prop-network 1000000))
  (define-values (net1 reg-cid)
    (net-register-specialized-cell net (hasheq) merge-hasheq-replace
      #:tier 'warm #:storage 'general #:fires-on 'any-change))
  (define names (gen-names N))
  (define-values (final-net registry)
    (for/fold ([n net1] [reg (hasheq)]) ([nm names] [i (in-naturals)])
      (define-values (n2 name-cid)
        (net-register-specialized-cell n (gen-entry i) replace-merge
          #:tier 'warm #:storage 'general #:fires-on 'any-change))
      (values n2 (hash-set reg nm name-cid))))
  (define net3 (net-cell-write final-net reg-cid registry))
  (values names net3 reg-cid))

(define (variant-d-lookup net reg-cid name)
  (define reg (net-cell-read net reg-cid))
  (define name-cid (hash-ref reg name #f))
  (and name-cid (net-cell-read net name-cid)))

;; ============================================================
;; W1/W2/W3 — READ MEASUREMENT (sequential lookups; mid-name)
;; ============================================================

(printf "\n=== W1/W2/W3 — READ MEASUREMENT ===\n")
(printf "(measuring lookup of name at index N/2; 100k iterations/measurement)\n")

(for ([N (in-list '(10 50 200))])
  (printf "\n--- Workload N=~a forms ---\n" N)

  ;; Variant A — realistic 2-layer dispatch under parameterize
  (define-values (a-names a-l1 a-l2) (variant-a-setup N))
  (define a-mid (list-ref a-names (quotient N 2)))
  (parameterize ([current-bench-layer-1 a-l1]
                 [current-bench-layer-2 a-l2])
    (bench-ns (format "A.read N=~a (2× parameter-ref + hash-ref)" N) 100000
              (variant-a-lookup-realistic a-mid)))

  ;; Variant B — single cell + hash-ref
  (define-values (b-names b-net b-cid) (variant-b-setup N))
  (define b-mid (list-ref b-names (quotient N 2)))
  (bench-ns (format "B.read N=~a (cell-read + hash-ref)" N) 100000
            (variant-b-lookup b-net b-cid b-mid))

  ;; Variant D — two-level: registry cell-read + hash-ref + per-name cell-read
  (define-values (d-names d-net d-reg-cid) (variant-d-setup N))
  (define d-mid (list-ref d-names (quotient N 2)))
  (bench-ns (format "D.read N=~a (2× cell-read + hash-ref)" N) 100000
            (variant-d-lookup d-net d-reg-cid d-mid)))

;; ============================================================
;; W1/W2/W3 — SETUP-TIME MEASUREMENT
;; ============================================================
;; Per audit Q-Bench5 finding 5: Variant D allocates N+1 cells; setup cost
;; matters for Phase 4's add+lookup balance during file loading.

(printf "\n=== W1/W2/W3 — SETUP-TIME MEASUREMENT ===\n")
(printf "(measuring construction of N-form env from scratch; 1000 iterations)\n")

(for ([N (in-list '(10 50 200))])
  (printf "\n--- Workload N=~a forms setup ---\n" N)

  (bench-ns (format "A.setup N=~a (parameter hash fold)" N) 1000
            (variant-a-setup N))

  (bench-ns (format "B.setup N=~a (1 cell-register + N cell-writes)" N) 1000
            (variant-b-setup N))

  (bench-ns (format "D.setup N=~a (1+N cell-registers + 1 reg-write)" N) 1000
            (variant-d-setup N)))

;; ============================================================
;; W5 — MEMORY: allocated + retained bytes
;; ============================================================

(printf "\n=== W5 — MEMORY (alloc + retain for N=100 setup) ===\n")
(printf "(median of 10 runs; retained measured post-GC)\n\n")

(bench-mem "A.mem N=100 (parameter hash)" 10
           (variant-a-setup 100))

(bench-mem "B.mem N=100 (1 cell + hasheq value)" 10
           (variant-b-setup 100))

(bench-mem "D.mem N=100 (1+N cells + registry)" 10
           (variant-d-setup 100))

(printf "\n=== END OF MEASUREMENT ===\n")
(printf "Per §18.12.3 criteria-as-guidance: review measurements together;\n")
(printf "decide variant aligned with principles, not strict pass/fail gates.\n\n")
