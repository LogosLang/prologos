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
                  (process-string-ws e1-src))))))
(define e2 (bench-mem "E2 parametric Seqable (Axis 1 bridge)" 10
                  (process-string-ws e2-src))))))
(define e3 (bench-mem "E3 polymorphic id (Axis 5 :type/:term)" 10
                  (process-string-ws e3-src))))))
(define e4 (bench-mem "E4 generic arithmetic (Axis 6)" 10
                  (process-string-ws e4-src))))))

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

(printf "M1 attribute-map facet access:       ~a / ~a μs  (that-read :type / :absent)\n"
        (~r m1a #:precision '(= 2)) (~r m1b #:precision '(= 2)))
(printf "M2 CHAMP meta-info access:           fresh=~a  solve=~a  read=~a μs\n"
        (~r m2a #:precision '(= 2)) (~r m2b #:precision '(= 2)) (~r m2c #:precision '(= 2)))
(printf "M3 infer core forms:                 lam=~a  app=~a  Pi=~a μs\n"
        (~r m3a #:precision '(= 2)) (~r m3b #:precision '(= 2)) (~r m3c #:precision '(= 2)))
(define (fmt-mem v)
  ;; v is (vector wall-ms alloc-bytes retain-bytes)
  (format "~a ms / ~a KB alloc / ~a KB retain"
          (~r (vector-ref v 0) #:precision '(= 2))
          (~r (/ (vector-ref v 1) 1024.0) #:precision '(= 1))
          (~r (/ (vector-ref v 2) 1024.0) #:precision '(= 1))))
(printf "A1a type-meta 10-same solve:         ~a\n" (fmt-mem a1a))
(printf "A1b type-meta 20-different solve:    ~a\n" (fmt-mem a1b))
(printf "A2a 10 spec cycles (no branching):   ~a\n" (fmt-mem a2a))
(printf "A2b 10 spec cycles (3 metas each):   ~a\n" (fmt-mem a2b))
(printf "E1 simple (no metas):                ~a\n" (fmt-mem e1))
(printf "E2 parametric Seqable (Axis 1):      ~a\n" (fmt-mem e2))
(printf "E3 polymorphic id (Axis 5):          ~a\n" (fmt-mem e3))
(printf "E4 generic arithmetic (Axis 6):      ~a\n" (fmt-mem e4))
(printf "V correctness:                       ~a failures\n" v-failures)

(displayln "\n(Baselines captured. Re-run after 4C phases land for A/B comparison.)")
