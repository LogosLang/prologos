#lang racket/base

;;;
;;; bench-attribute-record.rkt
;;; PPN 4C Phase 1E Pre-0 — attribute-record substrate microbenches
;;;
;;; PURPOSE: durable measurement harness for the attribute-record access substrate.
;;; Covers that-read / that-write API, compound-cell-component-* helpers, and
;;; meta-domain-solution dispatch. Survives Phase 1E close as the permanent
;;; bench file for the attribute-record substrate; Track 4D's Phases F/G
;;; (adding :whnf, :reduce, :surface facets) inherit the same harness.
;;;
;;; TIER STRUCTURE (per Tropical Quantale Addendum Pre-0 pattern, M+A+E+R+S):
;;;
;;;   M-tier — current baselines (THIS FILE, INITIAL DRAFT)
;;;     M1: that-read :type at surface position
;;;     M2: that-read :term at surface position
;;;     M3: that-read absent facet at surface position
;;;     M4: that-write :type at surface position
;;;     M5: compound-cell-component-ref direct call (universe cell)
;;;     M6: compound-cell-component-write direct call (universe cell)
;;;     M7: meta-domain-solution 'type id full dispatch
;;;     M8: prop-meta-id->cell-id lookup
;;;
;;;   A-tier — Option J-A vs J-C alternatives (PENDING — added post-M-tier review)
;;;   E-tier — edge cases (worldview-tagged, unsolved, cross-facet) (PENDING)
;;;   R-tier — realistic workload distributions (PENDING)
;;;   S-tier — semantic-axis parity (PENDING)
;;;
;;; CROSS-REFERENCES:
;;;   - docs/tracking/2026-04-21_PPN_4C_PHASE_9_DESIGN.md §7.6.16 (Phase 1E design)
;;;   - data/benchmarks/tropical-pre0-baseline-2026-04-26.txt (retired M1 baseline ≈ 26 ns)
;;;   - benchmarks/micro/bench-tropical-fuel.rkt (harness pattern source)
;;;   - benchmarks/micro/bench-meta-lifecycle.rkt (with-elab-env pattern source)
;;;
;;; Usage:
;;;   "/Applications/Racket v9.0/bin/racket" \
;;;     racket/prologos/benchmarks/micro/bench-attribute-record.rkt
;;;

(require racket/list
         racket/format
         "../../syntax.rkt"
         "../../typing-propagators.rkt"
         "../../metavar-store.rkt"
         "../../elaborator-network.rkt"
         "../../meta-universe.rkt"
         "../../propagator.rkt"
         "../../type-lattice.rkt"
         "../../classify-inhabit.rkt"
         "../../driver.rkt"
         "../../namespace.rkt"
         "../../tests/test-support.rkt")

;; ============================================================
;; TIMING INFRASTRUCTURE (mirrors bench-tropical-fuel.rkt)
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
;; ELABORATION ENV HELPER (mirrors bench-meta-lifecycle.rkt)
;; ============================================================

(define (with-elab-env thunk)
  (parameterize ([current-module-registry prelude-module-registry])
    (with-fresh-meta-env
      (thunk))))

;; ============================================================
;; FIXTURES — surface attribute-map (no metas)
;; ============================================================
;;
;; Surface-only fixture: a fresh prop-network with an attribute-map cell
;; populated at N surface positions (gensyms), each with :type facet only.
;; Mirrors the dominant production access pattern (literal/constructor
;; typing rules populate :type facet at the expression position).

(define (make-surface-fixture [N 100])
  (define net0 (make-prop-network))
  (define-values (net1 cid) (net-new-cell net0 (hasheq) attribute-map-merge-fn))
  ;; Populate N positions with :type = (expr-Int)
  (define positions
    (for/list ([_ (in-range N)]) (gensym 'pos)))
  (define net-final
    (for/fold ([net net1]) ([pos (in-list positions)])
      (that-write net cid pos ':type (expr-Int))))
  (values net-final cid positions))

;; ============================================================
;; SECTION 1: M1–M4 — that-* API on surface positions
;; ============================================================

(displayln "")
(displayln "============================================================")
(displayln "SECTION 1: M1–M4 — that-* API on surface positions")
(displayln "============================================================")
(displayln "")
(displayln "  Fixture: 100 surface positions, each with :type=(expr-Int)")

(define-values (s1-net s1-cid s1-positions) (make-surface-fixture 100))
(define s1-am (net-cell-read s1-net s1-cid))
(define s1-pos (car s1-positions))
(define s1-absent-pos (gensym 'absent))  ; never written

;; M1: that-read :type at populated surface position (the hot path)
(define m1
  (bench-ns "M1  (that-read am pos :type) populated" 50000
            (that-read s1-am s1-pos ':type)))

;; M2: that-read :term at populated surface position
;; (:term routes to :type facet's INHABITANT layer via magic-keyword dispatch)
;; At a surface position with only classifier written, :term returns 'bot
(define m2
  (bench-ns "M2  (that-read am pos :term) populated :type only" 50000
            (that-read s1-am s1-pos ':term)))

;; M3: that-read absent facet (position never written)
(define m3
  (bench-ns "M3  (that-read am absent-pos :type) returns facet-bot" 50000
            (that-read s1-am s1-absent-pos ':type)))

;; M4: that-write :type at surface position (allocates the per-call hasheq delta)
;; Note: net-cell-write merges via attribute-map-merge-fn; we measure the
;; full write path including the per-call (hasheq pos (hasheq :type ...))
;; allocation, the merge invocation, and the cell write itself.
(define m4
  (bench-ns "M4  (that-write net cid pos :type expr) full path" 20000
            (that-write s1-net s1-cid s1-pos ':type (expr-Int))))

;; ============================================================
;; SECTION 2: M5–M6 — compound-cell-component-* direct calls (universe cell)
;; ============================================================

(displayln "")
(displayln "============================================================")
(displayln "SECTION 2: M5–M6 — compound-cell-component-* (universe cell)")
(displayln "============================================================")
(displayln "")
(displayln "  Fixture: full elab env, 100 type metas, half solved to (expr-Int)")

;; M5: compound-cell-component-ref direct call at populated meta-id
;; M6: compound-cell-component-write direct call

(with-elab-env
  (lambda ()
    ;; Create 100 metas, solve half. init-meta-universes! fires lazily on first
    ;; fresh-meta call (per S2.e-i Option C-4); universe cells are populated.
    (define metas
      (for/list ([i (in-range 100)])
        (fresh-meta '() (expr-Int) 'bench)))
    ;; Solve every other meta
    (for ([m (in-list metas)] [i (in-naturals)])
      (when (even? i)
        (solve-meta! (expr-meta-id m) (expr-Int))))
    ;; Pick representatives
    (define solved-meta (car metas))                  ; metas[0] solved
    (define unsolved-meta (cadr metas))               ; metas[1] unsolved
    (define solved-id (expr-meta-id solved-meta))
    (define unsolved-id (expr-meta-id unsolved-meta))
    (define type-universe-cid (current-type-meta-universe-cell-id))
    (define net-box (current-prop-net-box))
    (define enet (unbox net-box))

    (define m5a
      (bench-ns "M5a (compound-cell-component-ref enet cid solved-id) → solution" 50000
                (compound-cell-component-ref enet type-universe-cid solved-id)))

    (define m5b
      (bench-ns "M5b (compound-cell-component-ref enet cid unsolved-id) → infra-bot/#f" 50000
                (compound-cell-component-ref enet type-universe-cid unsolved-id)))

    (define m6
      (bench-ns "M6  (compound-cell-component-write enet cid id (expr-Int))" 20000
                (compound-cell-component-write enet type-universe-cid solved-id (expr-Int))))

    (void m5a m5b m6)))

;; ============================================================
;; SECTION 3: M7–M8 — meta-domain dispatch + id-map lookup
;; ============================================================

(displayln "")
(displayln "============================================================")
(displayln "SECTION 3: M7–M8 — meta-domain-solution + prop-meta-id->cell-id")
(displayln "============================================================")
(displayln "")
(displayln "  Fixture: full elab env, type meta solved + unsolved")

(with-elab-env
  (lambda ()
    (define m-solved (fresh-meta '() (expr-Int) 'bench))
    (define m-unsolved (fresh-meta '() (expr-Int) 'bench))
    (solve-meta! (expr-meta-id m-solved) (expr-Int))
    (define solved-id (expr-meta-id m-solved))
    (define unsolved-id (expr-meta-id m-unsolved))

    ;; M7: meta-solution full dispatch (the typed shim delegates to
    ;; meta-domain-solution 'type id internally — post-Move-B+ path)
    (define m7a
      (bench-ns "M7a (meta-solution solved-id) → expr-Int" 50000
                (meta-solution solved-id)))

    (define m7b
      (bench-ns "M7b (meta-solution unsolved-id) → #f" 50000
                (meta-solution unsolved-id)))

    ;; M8: prop-meta-id->cell-id lookup (id-map walk)
    (define m8a
      (bench-ns "M8a (prop-meta-id->cell-id solved-id) → universe-cid" 50000
                (prop-meta-id->cell-id solved-id)))

    (define m8b
      (bench-ns "M8b (prop-meta-id->cell-id unsolved-id) → universe-cid" 50000
                (prop-meta-id->cell-id unsolved-id)))

    (void m7a m7b m8a m8b)))

;; ============================================================
;; SECTION 4: Memory profile — that-write allocation per call
;; ============================================================

(displayln "")
(displayln "============================================================")
(displayln "SECTION 4: that-write allocation profile")
(displayln "============================================================")

(define-values (s4-net s4-cid s4-positions) (make-surface-fixture 100))
(define s4-pos (car s4-positions))

;; 10000 writes — measure allocation pressure
(bench-mem "M4.mem 10000 that-write :type calls" 10
           (for ([_ (in-range 10000)])
             (that-write s4-net s4-cid s4-pos ':type (expr-Int))))

;; ============================================================
;; SUMMARY
;; ============================================================

(displayln "")
(displayln "============================================================")
(displayln "Phase 1E Pre-0 M-tier baselines captured. Compare to:")
(displayln "  - Retired bench-ppn-track4c.rkt M1a: 26 ns/call (2026-04-17 PRE0)")
(displayln "  - §7.6.16.4 perf constraint targets")
(displayln "")
(displayln "Next: A-tier benches for J-A vs J-C comparison + position synthesis variants")
(displayln "============================================================")
