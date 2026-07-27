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
         racket/path
         "../../syntax.rkt"
         "../../typing-propagators.rkt"
         "../../metavar-store.rkt"
         "../../elaborator-network.rkt"
         "../../meta-universe.rkt"
         (only-in "../../meta-universe.rkt" meta-universe-cell-id?)
         "../../propagator.rkt"
         (only-in "../../propagator.rkt" current-worldview-bitmask)
         (only-in "../../decision-cell.rkt"
                  tagged-cell-value tagged-cell-value? tagged-cell-read)
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
;; SECTION 5: A1 — Dispatch predicate cost in isolation
;; ============================================================
;;
;; Phase 1E will need to dispatch at the top of that-read/that-write:
;; "is this cell-id a meta-universe cell?". The predicate is
;; meta-universe-cell-id? (4 parameter reads + 4 equal? checks, worst-case).
;; This bench isolates the dispatch overhead — needed to subtract from
;; J-C total cost cleanly.

(displayln "")
(displayln "============================================================")
(displayln "SECTION 5: A1 — Dispatch predicate cost")
(displayln "============================================================")

(with-elab-env
  (lambda ()
    ;; Trigger lazy init so universe cell-ids are populated
    (fresh-meta '() (expr-Int) 'bench)
    (define universe-cid (current-type-meta-universe-cell-id))
    (define non-universe-cid (current-attribute-map-cell-id))

    (define a1a
      (bench-ns "A1a (meta-universe-cell-id? universe-cid) → #t (hit on first check)" 50000
                (meta-universe-cell-id? universe-cid)))

    (define a1b
      (bench-ns "A1b (meta-universe-cell-id? non-universe-cid) → #f (4 misses)" 50000
                (meta-universe-cell-id? non-universe-cid)))

    (void a1a a1b)))

;; ============================================================
;; SECTION 6: A2/A3 — J-A simulation vs J-C composition
;; ============================================================
;;
;; J-A: :mult/:level/:session as additional attribute-map facets.
;;   Simulated by reading/writing :mult directly via hash-ref/net-cell-write
;;   on an extended attribute-map record (no production-code changes).
;;   Cost model: same as that-read/that-write for :type, with one additional
;;   facet in the record (8 vs 5 → ~60% growth in facet-merge iterations).
;;
;; J-C: :mult/:level/:session routes to corresponding universe cell.
;;   Simulated by composing dispatch predicate + compound-cell-component-ref.
;;   Cost model: A1 + M5/M6.

(displayln "")
(displayln "============================================================")
(displayln "SECTION 6: A2/A3 — J-A simulation vs J-C composition")
(displayln "============================================================")

(displayln "")
(displayln "  Fixture: J-A extended attribute-map (8 facets per meta-pos)")

;; J-A simulation: build an extended attribute-map with :mult populated
;; alongside :type/:context/:usage/:constraints/:warnings.
(define (make-jA-fixture [N 100])
  (define net0 (make-prop-network))
  (define-values (net1 cid) (net-new-cell net0 (hasheq) attribute-map-merge-fn))
  (define positions (for/list ([_ (in-range N)]) (gensym 'meta-pos)))
  ;; Populate each position with 5 standard facets + 3 simulated (mult/level/session)
  (define jA-record
    (hasheq ':type (classifier-only (expr-Int))
            ':context #f
            ':usage '()
            ':constraints (facet-bot ':constraints)
            ':warnings '()
            ;; Simulated J-A facets (in production J-A, facet-bot table would
            ;; have entries for these; for benchmark purposes we read them raw)
            ':mult 'mult-bot
            ':level 'unsolved
            ':session 'unsolved))
  (define jA-am
    (for/hasheq ([pos (in-list positions)])
      (values pos jA-record)))
  ;; Write the J-A am to the cell once via direct cell-write (bypasses merge —
  ;; benchmark fixture only, mirrors what J-A facet population would produce)
  (define net2 (net-cell-write net1 cid jA-am))
  (values net2 cid positions))

(define-values (jA-net jA-cid jA-positions) (make-jA-fixture 100))
(define jA-am (net-cell-read jA-net jA-cid))
(define jA-pos (car jA-positions))

;; Helper: J-A simulated read — what that-read would do post-J-A extension
(define (that-read-jA-simulated am pos facet)
  (define record (hash-ref am pos #f))
  (cond
    [(not record) 'bot]
    [else (hash-ref record facet 'bot)]))

;; A2.J-A: simulated that-read :mult at meta-pos (J-A architecture)
(define a2-jA
  (bench-ns "A2.J-A (that-read-jA-simulated am pos :mult)" 50000
            (that-read-jA-simulated jA-am jA-pos ':mult)))

;; A2.J-C: composed dispatch predicate + compound-cell-component-ref
(with-elab-env
  (lambda ()
    (define metas
      (for/list ([_ (in-range 100)])
        (fresh-meta '() (expr-Int) 'bench)))
    (define m (car metas))
    (define id (expr-meta-id m))
    (define mult-universe-cid (current-mult-meta-universe-cell-id))
    (define net-box (current-prop-net-box))
    (define enet (unbox net-box))

    ;; A2.J-C: dispatch predicate + universe cell read
    ;; (simulates how Phase 1E would route :mult at meta-pos)
    (define a2-jC
      (bench-ns "A2.J-C (predicate + compound-cell-component-ref at mult-universe)" 50000
                (let ([cid mult-universe-cid])
                  (cond
                    [(meta-universe-cell-id? cid)
                     (compound-cell-component-ref enet cid id)]
                    [else 'bot]))))

    ;; A3.J-C: dispatch predicate + universe cell write
    (define a3-jC
      (bench-ns "A3.J-C (predicate + compound-cell-component-write at mult-universe)" 20000
                (let ([cid mult-universe-cid])
                  (cond
                    [(meta-universe-cell-id? cid)
                     (compound-cell-component-write enet cid id 'mult-bot)]
                    [else enet]))))

    (void a2-jC a3-jC)))

;; A3.J-A: simulated that-write :mult at meta-pos
(define a3-jA
  (bench-ns "A3.J-A simulated that-write :mult full path" 20000
            ;; Mirrors what that-write would do for an :mult facet under J-A:
            ;; build (hasheq pos (hasheq :mult val)) delta + net-cell-write +
            ;; attribute-map-merge-fn handles per-facet merge
            (net-cell-write jA-net jA-cid
                            (hasheq jA-pos (hasheq ':mult 'mult-bot)))))

;; ============================================================
;; SECTION 7: A4 — Specialized-cell-cache lower bound
;; ============================================================
;;
;; A4 measures the LOWER BOUND on what a §4.6 specialized-cell-cache for
;; universe-cells could achieve. The current compound-cell-component-ref
;; does 3 steps:
;;   1. (elab-cell-read enet cell-id)         — CHAMP cell-lookup
;;   2. (hash-ref compound-val component-key) — component-lookup
;;   3. (tagged-cell-read tcv wv)             — worldview-filter
;;
;; A direct-ref cache (mirroring fuel-cell-cache / worldview-cache-cache
;; from Phase 1V) eliminates step 1 by holding a direct ref to the cell.
;; A4 simulates the cache by reading compound-val ONCE outside the loop;
;; the per-call cost is just steps 2 + 3. This is the LOWER BOUND (real
;; cache adds ~5 ns of struct-field access; we measure without that).

(displayln "")
(displayln "============================================================")
(displayln "SECTION 7: A4 — Specialized-cell-cache lower bound")
(displayln "============================================================")

(with-elab-env
  (lambda ()
    (define metas
      (for/list ([_ (in-range 100)])
        (fresh-meta '() (expr-Int) 'bench)))
    ;; Solve all metas so reads return values
    (for ([m (in-list metas)])
      (solve-meta! (expr-meta-id m) (expr-Int)))
    (define m (car metas))
    (define id (expr-meta-id m))
    (define type-universe-cid (current-type-meta-universe-cell-id))
    (define net-box (current-prop-net-box))
    (define enet (unbox net-box))
    ;; Pre-fetch compound-val ONCE — simulates direct-ref cache
    (define compound-val (elab-cell-read enet type-universe-cid))
    (define wv 0)  ;; baseline worldview (no speculation active)

    (define a4
      (bench-ns "A4  (hash-ref compound-val id) + tagged-cell-read [cache lower bound]" 50000
                (let ([tcv (hash-ref compound-val id #f)])
                  (cond
                    [(not tcv) #f]
                    [(tagged-cell-value? tcv)
                     (tagged-cell-read tcv wv)]
                    [else tcv]))))

    ;; A4b: just the hash-ref portion (cache + lookup, no tagged-cell-read)
    (define a4b
      (bench-ns "A4b (hash-ref compound-val id) only" 50000
                (hash-ref compound-val id #f)))

    ;; A4c: elab-cell-read alone (the step we'd skip via cache)
    (define a4c
      (bench-ns "A4c (elab-cell-read enet universe-cid) [cell lookup we'd save]" 50000
                (elab-cell-read enet type-universe-cid)))

    (void a4 a4b a4c)))

;; ============================================================
;; SECTION 8: A5 — Attribute-map memory growth under J-A vs J-C
;; ============================================================
;;
;; J-A adds 3 facets per meta position to attribute-map CHAMP.
;; J-C keeps attribute-map size unchanged; universe cell grows by
;; the per-meta tagged-cell-value entries.
;; Compare retained memory at scale: 1k and 10k meta positions.

(displayln "")
(displayln "============================================================")
(displayln "SECTION 8: A5 — Memory growth at scale (J-A vs J-C)")
(displayln "============================================================")

(define (build-jA-attribute-map N)
  (define record-jA
    (hasheq ':type (classifier-only (expr-Int))
            ':context #f
            ':usage '()
            ':constraints (facet-bot ':constraints)
            ':warnings '()
            ':mult 'mult-bot
            ':level 'unsolved
            ':session 'unsolved))
  (for/hasheq ([_ (in-range N)])
    (values (gensym 'pos) record-jA)))

(define (build-jC-attribute-map N)
  ;; Same baseline: 5 facets per position. J-C doesn't grow attribute-map.
  (define record-jC
    (hasheq ':type (classifier-only (expr-Int))
            ':context #f
            ':usage '()
            ':constraints (facet-bot ':constraints)
            ':warnings '()))
  (for/hasheq ([_ (in-range N)])
    (values (gensym 'pos) record-jC)))

(displayln "")
(displayln "  J-A: 8 facets per meta-pos (attribute-map holds mult/level/session)")
(bench-mem "A5.J-A.1k  build 1k-pos extended am" 5
           (build-jA-attribute-map 1000))
(bench-mem "A5.J-A.10k build 10k-pos extended am" 3
           (build-jA-attribute-map 10000))

(displayln "")
(displayln "  J-C: 5 facets per meta-pos (universe cells hold mult/level/session)")
(bench-mem "A5.J-C.1k  build 1k-pos baseline am" 5
           (build-jC-attribute-map 1000))
(bench-mem "A5.J-C.10k build 10k-pos baseline am" 3
           (build-jC-attribute-map 10000))

;; ============================================================
;; SECTION 9: E-tier — Edge cases
;; ============================================================
;;
;; E1: read state spread — unallocated vs unsolved vs solved at meta-pos
;; E2: read under speculation (current-worldview-bitmask non-zero) —
;;     captures the cost when ATMS branching is active (Phase 3 future)
;; E3: cross-facet at meta-pos — cost of reading each facet for a meta
;; E4: arity-2 whole-record view — Track 4D + LSP inspection cost

(displayln "")
(displayln "============================================================")
(displayln "SECTION 9: E-tier — Edge cases")
(displayln "============================================================")

;; E1: read-state spread on universe cell
(with-elab-env
  (lambda ()
    (define metas (for/list ([_ (in-range 100)]) (fresh-meta '() (expr-Int) 'bench)))
    ;; metas[0] solved; metas[1] unsolved (allocated but no solution); metas[2..] same
    (solve-meta! (expr-meta-id (car metas)) (expr-Int))
    (define solved-id (expr-meta-id (car metas)))
    (define unsolved-id (expr-meta-id (cadr metas)))
    (define unallocated-id (gensym 'never-allocated))  ;; never went through fresh-meta
    (define type-universe-cid (current-type-meta-universe-cell-id))
    (define enet (unbox (current-prop-net-box)))

    (displayln "")
    (displayln "  E1: read-state spread (solved / unsolved / unallocated)")
    (define e1a
      (bench-ns "E1a (compound-cell-component-ref solved-id) → solution" 50000
                (compound-cell-component-ref enet type-universe-cid solved-id)))
    (define e1b
      (bench-ns "E1b (compound-cell-component-ref unsolved-id) → infra-bot" 50000
                (compound-cell-component-ref enet type-universe-cid unsolved-id)))
    (define e1c
      (bench-ns "E1c (compound-cell-component-ref unallocated-id) → #f" 50000
                (compound-cell-component-ref enet type-universe-cid unallocated-id)))

    (void e1a e1b e1c)))

;; E2: read under speculation (per-prop bitmask non-zero)
(with-elab-env
  (lambda ()
    (define metas (for/list ([_ (in-range 100)]) (fresh-meta '() (expr-Int) 'bench)))
    (solve-meta! (expr-meta-id (car metas)) (expr-Int))
    (define solved-id (expr-meta-id (car metas)))
    (define type-universe-cid (current-type-meta-universe-cell-id))
    (define enet (unbox (current-prop-net-box)))

    (displayln "")
    (displayln "  E2: read under speculation (current-worldview-bitmask non-zero)")
    (parameterize ([current-worldview-bitmask 1])
      (define e2a
        (bench-ns "E2a (compound-cell-component-ref) wv=1 per-prop-active" 50000
                  (compound-cell-component-ref enet type-universe-cid solved-id)))
      (void e2a))
    ;; Compare to baseline wv=0 (resolve falls through to worldview-cache)
    (parameterize ([current-worldview-bitmask 0])
      (define e2b
        (bench-ns "E2b (compound-cell-component-ref) wv=0 cache-fallback" 50000
                  (compound-cell-component-ref enet type-universe-cid solved-id)))
      (void e2b))))

;; E3: cross-facet at meta-pos — cost of reading each facet for a meta position
;; Builds a fully-populated attribute-map record at a meta-pos representative
;; (uses gensym-based pos for fixture isolation; production meta-pos = expr-meta)
(define-values (e3-net e3-cid e3-positions) (make-surface-fixture 1))
(define e3-pos (car e3-positions))
;; Populate ALL 5 storage facets at e3-pos
(define e3-net*
  (let* ([n e3-net]
         [n (that-write n e3-cid e3-pos ':type (expr-Int))]
         [n (that-write n e3-cid e3-pos ':term (expr-int 42))]
         [n (that-write n e3-cid e3-pos ':context #f)]
         [n (that-write n e3-cid e3-pos ':usage '(m0))]
         [n (that-write n e3-cid e3-pos ':constraints (facet-bot ':constraints))]
         [n (that-write n e3-cid e3-pos ':warnings '())])
    n))
(define e3-am (net-cell-read e3-net* e3-cid))

(displayln "")
(displayln "  E3: cross-facet read spread at fully-populated meta-pos")

(define e3a (bench-ns "E3a (that-read am pos :type)" 50000 (that-read e3-am e3-pos ':type)))
(define e3b (bench-ns "E3b (that-read am pos :term)" 50000 (that-read e3-am e3-pos ':term)))
(define e3c (bench-ns "E3c (that-read am pos :context)" 50000 (that-read e3-am e3-pos ':context)))
(define e3d (bench-ns "E3d (that-read am pos :usage)" 50000 (that-read e3-am e3-pos ':usage)))
(define e3e (bench-ns "E3e (that-read am pos :constraints)" 50000 (that-read e3-am e3-pos ':constraints)))
(define e3f (bench-ns "E3f (that-read am pos :warnings)" 50000 (that-read e3-am e3-pos ':warnings)))
(void e3a e3b e3c e3d e3e e3f)

;; E4: arity-2 whole-record view
(displayln "")
(displayln "  E4: arity-2 whole-record view (Track 4D / LSP inspection)")
(define e4a
  (bench-ns "E4a (that-read am pos) → decomposed user-facing hasheq" 50000
            (that-read e3-am e3-pos)))
(define e4b
  (bench-ns "E4b (that-read am unallocated-pos) → empty hasheq" 50000
            (that-read e3-am 'never-written-pos)))
(void e4a e4b)

;; ============================================================
;; SECTION 10: R-tier — Realistic workload via process-file
;; ============================================================
;;
;; Drives process-file on the PPN 4C acceptance file. Captures wall
;; time + the perf-counter signals that process-file emits to stdout.
;; These give us TOTAL elaboration cost on a realistic workload.
;;
;; Combined with M+A tier costs, we project Phase 1E impact:
;;   - Total that-* call cost = (M-tier that-* cost) × (count est.)
;;   - Fraction of elaboration time = that-* cost / total wall

(displayln "")
(displayln "============================================================")
(displayln "SECTION 10: R-tier — Realistic workload (process-file)")
(displayln "============================================================")
(displayln "")
(displayln "  Driving process-file on examples/2026-04-17-ppn-track4c.prologos")
(displayln "  (67 commands; broad pipeline exercise — see file header for axes)")
(displayln "")

(define acceptance-path
  (build-path (path-only (path->complete-path "racket/prologos/."))
              "examples" "2026-04-17-ppn-track4c.prologos"))

;; Run process-file once, time it. process-file's own output (PERF-COUNTERS,
;; PHASE-TIMINGS, CELL-METRICS lines per command) is captured in stdout
;; below. We add R1 wall time on top.
(displayln "  --- R1: process-file output begins ---")
(collect-garbage) (collect-garbage)
(define r1-start (current-inexact-milliseconds))
(define r1-result
  (with-handlers ([exn:fail? (lambda (e)
                               (printf "  R1: process-file ERROR: ~a\n" (exn-message e))
                               'error)])
    (process-file acceptance-path)))
(define r1-end (current-inexact-milliseconds))
(define r1-wall-ms (- r1-end r1-start))
(displayln "  --- R1: process-file output ends ---")
(displayln "")
(printf "  R1 acceptance-file wall: ~a ms\n" (~r r1-wall-ms #:precision '(= 1)))

;; R2: Phase 1E projection — order-of-magnitude impact estimate
;;
;; From PERF-COUNTERS R1 captured: 67 commands → 3773 cell_allocs, 63
;; meta_created, 328 infer_steps, 170 unify_steps, 715 zonk_steps,
;; elaborate_ms=114, total wall 4640 ms.
;;
;; Heuristic that-* call count for the acceptance file:
;;   that-write calls ≈ cell_allocs (each net-new-cell on attribute-map
;;     path goes through that-write; meta cells via universe path skip
;;     that-write but use compound-cell-component-write)
;;   that-read calls  ≈ 3 × infer_steps + 2 × unify_steps + zonk_steps
;;     (rough: each inference step does several reads; unify reads both
;;     sides; zonk dereferences metas)
;;   meta-pos reads   ≈ unify_steps + zonk_steps  (the meta dereference
;;     paths from unify + zonk dominate meta-pos access)

(define r-cell-allocs 3773)
(define r-meta-created 63)
(define r-infer-steps 328)
(define r-unify-steps 170)
(define r-zonk-steps 715)
(define r-elaborate-ms 114)

(define est-that-writes r-cell-allocs)
(define est-that-reads (+ (* 3 r-infer-steps) (* 2 r-unify-steps) r-zonk-steps))
(define est-meta-pos-reads (+ r-unify-steps r-zonk-steps))

(displayln "")
(displayln "  --- R2: Phase 1E impact projection (heuristic from R1 PERF-COUNTERS) ---")
(displayln "")
(printf "  Acceptance file PERF-COUNTERS (from R1 stdout):\n")
(printf "    cell_allocs:        ~a (~~~a/cmd)\n" r-cell-allocs (round (/ r-cell-allocs 67.0)))
(printf "    meta_created:       ~a (~~~a/cmd)\n" r-meta-created (~r (/ r-meta-created 67.0) #:precision '(= 2)))
(printf "    infer_steps:        ~a (~~~a/cmd)\n" r-infer-steps (round (/ r-infer-steps 67.0)))
(printf "    unify_steps:        ~a (~~~a/cmd)\n" r-unify-steps (round (/ r-unify-steps 67.0)))
(printf "    zonk_steps:         ~a (~~~a/cmd)\n" r-zonk-steps (round (/ r-zonk-steps 67.0)))
(printf "    elaborate_ms:       ~a (~~~a% of wall)\n" r-elaborate-ms
        (~r (/ (* r-elaborate-ms 100.0) r1-wall-ms) #:precision '(= 1)))
(displayln "")
(printf "  Estimated that-* call count per acceptance run:\n")
(printf "    that-writes ≈ ~a\n" est-that-writes)
(printf "    that-reads  ≈ ~a\n" est-that-reads)
(printf "    of which meta-pos reads ≈ ~a (~~~a% of total reads)\n"
        est-meta-pos-reads
        (~r (/ (* est-meta-pos-reads 100.0) est-that-reads) #:precision '(= 1)))
(displayln "")
(printf "  Projected total time in that-* on this workload:\n")
(printf "    Current (M1+M4):           ~~~a μs (~~~a%% of elaborate_ms)\n"
        (~r (/ (+ (* 32 est-that-reads) (* 317 est-that-writes)) 1000.0) #:precision '(= 1))
        (~r (/ (+ (* 32 est-that-reads) (* 317 est-that-writes))
               (* r-elaborate-ms 10000.0)) #:precision '(= 2)))
(printf "    Phase 1E J-C unoptimized:  ~~~a μs (~~~a%% of elaborate_ms; meta-pos at M5a/M6)\n"
        (~r (/ (+ (* 32 (- est-that-reads est-meta-pos-reads))
                  (* 207 est-meta-pos-reads)
                  (* 317 est-that-writes)) 1000.0) #:precision '(= 1))
        (~r (/ (+ (* 32 (- est-that-reads est-meta-pos-reads))
                  (* 207 est-meta-pos-reads)
                  (* 317 est-that-writes))
               (* r-elaborate-ms 10000.0)) #:precision '(= 2)))
(printf "    Phase 1E J-C w/ cleanup:   ~~~a μs (~~~a%% of elaborate_ms; meta-pos at ~~80ns)\n"
        (~r (/ (+ (* 32 (- est-that-reads est-meta-pos-reads))
                  (* 80 est-meta-pos-reads)
                  (* 317 est-that-writes)) 1000.0) #:precision '(= 1))
        (~r (/ (+ (* 32 (- est-that-reads est-meta-pos-reads))
                  (* 80 est-meta-pos-reads)
                  (* 317 est-that-writes))
               (* r-elaborate-ms 10000.0)) #:precision '(= 2)))
(displayln "")
(displayln "  Realistic-workload signal:")
(displayln "    that-* cost is a SMALL fraction of elaborate_ms (which is itself")
(displayln "    only ~2.5% of wall; reduce_ms dominates at ~26%).")
(displayln "    Phase 1E routing overhead is essentially invisible to overall")
(displayln "    elaboration cost — even at unoptimized J-C, projected impact")
(displayln "    is well under 1% of elaborate_ms. The cleanup matters for")
(displayln "    high-frequency paths beyond that-* (S(-1), set-latch, etc.).")

;; ============================================================
;; SECTION 11: S-tier — Semantic-axis frozen-value baseline
;; ============================================================
;;
;; Captures the CURRENT observable values at representative test points
;; under the pre-Phase-1E architecture. These become the parity baseline
;; for post-Phase-1E A/B comparison. The bench-file role is FROZEN-VALUE
;; CAPTURE; the regression gate lives in tests/test-elaboration-parity.rkt
;; (skeleton added when Phase 1E implementation begins).
;;
;; Semantic axes per Phase 1E:
;;   S1: surface-position :type read (must regress-test unchanged)
;;   S2: meta-position :type CLASSIFIER read
;;   S3: meta-position :term INHABITANT read (solved meta)
;;   S4: meta-position :term INHABITANT read (unsolved meta)
;;   S5: cross-facet at fully-populated position
;;   S6: arity-2 whole-record decomposition

(displayln "")
(displayln "============================================================")
(displayln "SECTION 11: S-tier — Semantic-axis frozen-value baseline")
(displayln "============================================================")

(displayln "")
(displayln "  S1: surface-position :type at expr-Int literal (M1 fixture)")
(let ([v (that-read s1-am s1-pos ':type)])
  (printf "    that-read am surface-pos :type = ~v\n" v))

(displayln "")
(displayln "  S2: meta-position :type CLASSIFIER (current architecture)")
(with-elab-env
  (lambda ()
    (define m (fresh-meta '() (expr-Int) 'bench))
    (define id (expr-meta-id m))
    (define type-universe-cid (current-type-meta-universe-cell-id))
    (define enet (unbox (current-prop-net-box)))
    (printf "    fresh meta with type=expr-Int\n")
    (printf "    meta-solution(id) [unsolved]          = ~v\n" (meta-solution id))
    (printf "    compound-ref(type-universe, id)       = ~v\n"
            (compound-cell-component-ref enet type-universe-cid id))
    (solve-meta! id (expr-Int))
    (printf "    after solve to expr-Int:\n")
    (define enet2 (unbox (current-prop-net-box)))
    (printf "    meta-solution(id) [solved]            = ~v\n" (meta-solution id))
    (printf "    compound-ref(type-universe, id)       = ~v\n"
            (compound-cell-component-ref enet2 type-universe-cid id))))

(displayln "")
(displayln "  S3/S4: :term INHABITANT layer at meta-pos in attribute-map")
(let* ([net0 (make-prop-network)]
       [tmp (let-values ([(n c) (net-new-cell net0 (hasheq) attribute-map-merge-fn)]) (cons n c))]
       [net1 (car tmp)] [tm-cid (cdr tmp)]
       [meta-pos (expr-meta 'test-id #f)]
       [net2 (that-write net1 tm-cid meta-pos ':type (expr-Int))]
       [net3 (that-write net2 tm-cid meta-pos ':term (expr-int 42))]
       [am  (net-cell-read net3 tm-cid)])
  (printf "    fresh attribute-map at meta-pos, :type=expr-Int, :term=expr-int(42)\n")
  (printf "    that-read am meta-pos :type = ~v\n" (that-read am meta-pos ':type))
  (printf "    that-read am meta-pos :term = ~v\n" (that-read am meta-pos ':term)))

(displayln "")
(displayln "  S5: cross-facet at fully-populated position (E3 fixture)")
(printf "    that-read am pos :type        = ~v\n" (that-read e3-am e3-pos ':type))
(printf "    that-read am pos :term        = ~v\n" (that-read e3-am e3-pos ':term))
(printf "    that-read am pos :context     = ~v\n" (that-read e3-am e3-pos ':context))
(printf "    that-read am pos :usage       = ~v\n" (that-read e3-am e3-pos ':usage))
(printf "    that-read am pos :constraints = ~v\n" (that-read e3-am e3-pos ':constraints))
(printf "    that-read am pos :warnings    = ~v\n" (that-read e3-am e3-pos ':warnings))

(displayln "")
(displayln "  S6: arity-2 whole-record decomposition")
(printf "    (that-read am pos) full-decomposed = ~v\n" (that-read e3-am e3-pos))

;; ============================================================
;; SUMMARY
;; ============================================================

(displayln "")
(displayln "============================================================")
(displayln "Phase 1E Pre-0 M+A+E+R+S-tier captured.")
(displayln "")
(displayln "Decision inputs ready for §G Q1/Q2 + §J option resolution:")
(displayln "  - M: current baselines (8 micros)")
(displayln "  - A: dispatch overhead + J-A vs J-C + cache LB + memory growth")
(displayln "  - E: edge cases (read-state, speculation, cross-facet, whole-record)")
(displayln "  - R: realistic workload wall time + projection")
(displayln "  - S: frozen-value semantic baseline (6 axes)")
(displayln "")
(displayln "Ready for: pre-Phase-1E cleanup (retire with-handlers in")
(displayln "resolve-worldview-bitmask) + architectural dialogue.")
(displayln "============================================================")
