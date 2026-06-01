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
                  net-cell-write
                  ;; Audit-driven additions (2026-05-26 session):
                  net-add-propagator
                  run-to-quiescence
                  compound-cell-component-ref/pnet
                  compound-cell-component-write/pnet)
         (only-in "../../specialized-cells.rkt"
                  net-register-specialized-cell)
         (only-in "../../infra-cell.rkt"
                  merge-hasheq-replace)
         ;; Production-faithful Variant A — uses real global-env-lookup-type
         ;; (per audit finding 1: bench's variant-a-lookup-realistic is OPTIMISTIC
         ;; vs production; omits Layer 3 + dep-recording + current-elaborating-name)
         (only-in "../../global-env.rkt"
                  current-elaborating-name
                  current-definition-dependencies
                  current-cross-module-deps
                  global-env-lookup-type))

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

;; ============================================================
;; PRODUCTION-FAITHFUL VARIANT A — NEUTRALIZED (PPN 4C Addendum 4A.c-iii-e-2)
;; ============================================================
;; This section modeled the now-RETIRED 3-layer param path
;; (current-definition-cells-content → current-module-definitions-content →
;; current-prelude-env) that global-env-lookup-type read pre-4A.b. Those 3
;; params are retired at 4A.c-iii-e-2; global-env-lookup-type now resolves via
;; the per-file module-network-ref cascade, so the Variant-A measurement is
;; obsolete as written. Removed here to keep the bench compiling after the
;; param retirement. Full rework (model the mnr-cascade lookup path) is deferred
;; to 4A.d (bench re-run).

;; ============================================================
;; VARIANT C — Single compound cell + compound-cell-component-{ref,write}/pnet
;; ============================================================
;; Audit finding 10 (2026-05-26): C uses compound-cell-component-ref/pnet which
;; is 3-unwrap (cell-read + hash-ref + tagged-cell-read) vs B's 2-unwrap
;; (cell-read + hash-ref). The §18 audit assumption "C ≅ B for reads" is
;; based on read-path counting; this measures whether tagged-cell-value wrap/
;; unwrap is free under wv=0 (no speculation, default case).

(define (variant-c-setup N)
  (define net (make-prop-network 1000000))
  (define-values (net1 cid)
    (net-register-specialized-cell net (hasheq) merge-hasheq-replace
      #:tier 'warm #:storage 'general #:fires-on 'any-change))
  (define names (gen-names N))
  (define net2 (for/fold ([n net1]) ([nm names] [i (in-naturals)])
                 (compound-cell-component-write/pnet n cid nm (gen-entry i))))
  (values names net2 cid))

(define (variant-c-lookup net cid name)
  (compound-cell-component-ref/pnet net cid name))

(printf "\n=== W1/W2/W3 — VARIANT C READ MEASUREMENT ===\n")
(printf "(compound cell + component-paths; read via compound-cell-component-ref/pnet)\n")

(for ([N (in-list '(10 50 200))])
  (printf "\n--- Workload N=~a forms ---\n" N)

  (define-values (c-names c-net c-cid) (variant-c-setup N))
  (define c-mid (list-ref c-names (quotient N 2)))

  (bench-ns (format "C.read N=~a (cell-read + hash-ref + tagged-cell-read)" N) 100000
            (variant-c-lookup c-net c-cid c-mid)))

(printf "\n=== VARIANT C SETUP-TIME MEASUREMENT ===\n")
(for ([N (in-list '(10 50 200))])
  (printf "\n--- Workload N=~a forms setup ---\n" N)
  (bench-ns (format "C.setup N=~a (1 cell-register + N compound-writes)" N) 1000
            (variant-c-setup N)))

(printf "\n=== VARIANT C MEMORY (N=100) ===\n\n")
(bench-mem "C.mem N=100 (1 compound cell)" 10
           (variant-c-setup 100))

;; ============================================================
;; W4 LIGHT — WAKE PRECISION MEASUREMENT (B vs C vs D)
;; ============================================================
;; Discriminating measurement (per §18.12.9 W4 light): install ONE propagator
;; watching name X; write to N-1 OTHER names; count fires.
;;
;; Expected (per audit finding 4 + audit's compound-paths semantics):
;;   B: N-1 fires (whole-cell wake — propagator dependent on cell with no
;;      component-paths declaration; every write to the cell wakes it)
;;   C: 0 fires (propagator declares :component-paths (list (cons cid X));
;;      compound-cell-component-write to other-name emits change-set with
;;      key=other-name; filter skips this propagator)
;;   D: 0 fires (propagator dependent on watch-name's per-name cell only;
;;      writes to OTHER per-name cells don't enqueue this propagator)
;;
;; Measurement methodology: drive run-to-quiescence between EACH write to
;; ensure per-write fires are individually counted (BSP would otherwise
;; coalesce multiple writes within one round into one fire).
;;
;; NB: wake-counter is a measurement-only side-effect box (violates the
;; "Design Invariant: Propagator Statelessness" principle deliberately as
;; an observation instrument; production propagators never do this).

(define wake-count (box 0))
(define (make-wake-fire-fn)
  (lambda (net)
    (set-box! wake-count (add1 (unbox wake-count)))
    net))

(printf "\n=== W4 LIGHT — WAKE PRECISION ===\n")
(printf "(1 propagator watching name X; N-1 writes to OTHER names; quiesce after each)\n")
(printf "(expected — B: N-1 fires; C: 0 fires; D: 0 fires)\n")

(for ([N (in-list '(10 50))])
  (printf "\n--- Workload N=~a env entries; ~a other-name writes ---\n" N (- N 1))

  (define names (gen-names N))
  (define watch-name (list-ref names (quotient N 2)))
  (define other-names (remove watch-name names))

  ;; -------- Variant B --------
  (let ()
    (define-values (b-names b-net b-cid) (variant-b-setup N))
    ;; Install propagator watching env cell (no component-paths → whole-cell wake)
    (define-values (b-net1 _b-pid)
      (net-add-propagator b-net (list b-cid) '() (make-wake-fire-fn)))
    ;; Drive initial quiescence (drain install-time fire)
    (define b-net2 (run-to-quiescence b-net1))
    (set-box! wake-count 0)
    ;; N-1 writes, quiesce after each
    (define b-net-final
      (for/fold ([n b-net2]) ([nm (in-list other-names)] [i (in-naturals)])
        (run-to-quiescence (net-cell-write n b-cid (hasheq nm (gen-entry (+ i 10000)))))))
    (printf "  B.wakes: ~a fires for ~a writes  (whole-cell wake)\n"
            (unbox wake-count) (length other-names)))

  ;; -------- Variant C --------
  (let ()
    (define-values (c-names c-net c-cid) (variant-c-setup N))
    ;; Install propagator with :component-paths declaring watch-name only
    (define-values (c-net1 _c-pid)
      (net-add-propagator c-net (list c-cid) '() (make-wake-fire-fn)
        #:component-paths (list (cons c-cid watch-name))))
    (define c-net2 (run-to-quiescence c-net1))
    (set-box! wake-count 0)
    (define c-net-final
      (for/fold ([n c-net2]) ([nm (in-list other-names)] [i (in-naturals)])
        (run-to-quiescence
         (compound-cell-component-write/pnet n c-cid nm (gen-entry (+ i 10000))))))
    (printf "  C.wakes: ~a fires for ~a writes  (component-paths X-only)\n"
            (unbox wake-count) (length other-names)))

  ;; -------- Variant D --------
  (let ()
    (define-values (d-names d-net d-reg-cid) (variant-d-setup N))
    ;; Read registry to find watch-name's per-name cell-id + propagator install
    (define registry (net-cell-read d-net d-reg-cid))
    (define watch-cid (hash-ref registry watch-name))
    (define-values (d-net1 _d-pid)
      (net-add-propagator d-net (list watch-cid) '() (make-wake-fire-fn)))
    (define d-net2 (run-to-quiescence d-net1))
    (set-box! wake-count 0)
    (define d-net-final
      (for/fold ([n d-net2]) ([nm (in-list other-names)] [i (in-naturals)])
        (define other-cid (hash-ref registry nm))
        (run-to-quiescence (net-cell-write n other-cid (gen-entry (+ i 10000))))))
    (printf "  D.wakes: ~a fires for ~a writes  (per-name cells)\n"
            (unbox wake-count) (length other-names))))

(printf "\n=== END OF MEASUREMENT ===\n")
(printf "Per §18.12.3 criteria-as-guidance: review measurements together;\n")
(printf "decide variant aligned with principles, not strict pass/fail gates.\n")
(printf "Extended 2026-05-26 (post-audit): production-faithful A + Variant C + W4 light.\n\n")
