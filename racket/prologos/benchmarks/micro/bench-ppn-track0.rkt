#lang racket/base

;;;
;;; bench-ppn-track0.rkt — Microbenchmarks for PPN Track 0: Parse Domain Lattice Design
;;;
;;; Measures infrastructure capacity at parse-domain scale (20K-500K cells),
;;; lattice merge operations, current pipeline baselines, quiescence scaling,
;;; and ATMS operations. Run from racket/prologos/:
;;;
;;;   "/Applications/Racket v9.0/bin/racket" benchmarks/micro/bench-ppn-track0.rkt
;;;

(require "../../propagator.rkt"
         "../../champ.rkt"
         "../../infra-cell.rkt"
         "../../type-lattice.rkt"
         "../../syntax.rkt"
         "../../elab-network-types.rkt"
         "../../elab-speculation-bridge.rkt"
         "../../atms.rkt"
         "../../driver.rkt"
         "../../macros.rkt"
         "../../reader.rkt"
         "../../tests/test-support.rkt"
         racket/set)

;; ============================================================
;; Bench macro — inline timing (no dependency on bench-micro.rkt)
;; ============================================================

(define-syntax-rule (bench label iters body ...)
  (let ()
    (collect-garbage) (collect-garbage)
    (define start (current-inexact-milliseconds))
    (for ([bench-i (in-range iters)])
      body ...)
    (define elapsed (- (current-inexact-milliseconds) start))
    (printf "  ~a: ~a ns/call (~a calls, ~a ms total)\n"
            label
            (exact->inexact (/ (* elapsed 1000000) iters))
            iters
            (exact->inexact elapsed))))

;; Simple merge function for parse-domain cells: set-once (flat lattice)
(define (merge-set-once old new)
  (cond
    [(eq? old 'bot) new]
    [(eq? new 'bot) old]
    [(equal? old new) old]
    [else 'top]))

;; ============================================================
;; A. Infrastructure Capacity (CHAMP at parse scale)
;; ============================================================

(printf "\n=== A. Infrastructure Capacity (CHAMP at parse scale) ===\n\n")

;; A1: Create 20,000 cells
(printf "--- A1: 20K cell creation ---\n")
(define net-20k
  (with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)) #f)])
    (collect-garbage) (collect-garbage)
    (define start (current-inexact-milliseconds))
    (define net0 (make-prop-network 10000000))
    (define net-final
      (for/fold ([net net0]) ([i (in-range 20000)])
        (define-values (net* _cid) (net-new-cell net 'bot merge-set-once))
        net*))
    (define elapsed (- (current-inexact-milliseconds) start))
    (printf "  20K cells: ~a ns/cell (~a ms total)\n"
            (exact->inexact (/ (* elapsed 1000000) 20000))
            (exact->inexact elapsed))
    net-final))

;; Collect cell-ids from the 20K network for later use
(define cell-ids-20k
  (if net-20k
      (for/list ([i (in-range 20000)])
        (cell-id i))
      '()))

;; A2: Create 100,000 cells
(printf "\n--- A2: 100K cell creation ---\n")
(define net-100k
  (with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)) #f)])
    (collect-garbage) (collect-garbage)
    (define start (current-inexact-milliseconds))
    (define net0 (make-prop-network 10000000))
    (define net-final
      (for/fold ([net net0]) ([i (in-range 100000)])
        (define-values (net* _cid) (net-new-cell net 'bot merge-set-once))
        net*))
    (define elapsed (- (current-inexact-milliseconds) start))
    (printf "  100K cells: ~a ns/cell (~a ms total)\n"
            (exact->inexact (/ (* elapsed 1000000) 100000))
            (exact->inexact elapsed))
    net-final))

;; A3: Create 500,000 cells (with timeout guard)
(printf "\n--- A3: 500K cell creation ---\n")
(define net-500k
  (with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)) #f)])
    (collect-garbage) (collect-garbage)
    (define start (current-inexact-milliseconds))
    (define net0 (make-prop-network 10000000))
    (define net-final
      (for/fold ([net net0]) ([i (in-range 500000)])
        ;; Timeout guard: bail after 60s
        (when (and (zero? (modulo i 50000))
                   (> (- (current-inexact-milliseconds) start) 60000))
          (error 'timeout "500K cell creation exceeded 60s at ~a cells" i))
        (define-values (net* _cid) (net-new-cell net 'bot merge-set-once))
        net*))
    (define elapsed (- (current-inexact-milliseconds) start))
    (printf "  500K cells: ~a ns/cell (~a ms total)\n"
            (exact->inexact (/ (* elapsed 1000000) 500000))
            (exact->inexact elapsed))
    net-final))

;; A4: Random cell lookup at each scale
(printf "\n--- A4: Random cell lookup ---\n")

(define (bench-random-reads label net n-cells n-reads)
  (with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED (~a): ~a\n" label (exn-message e)))])
    (when net
      (define rand-ids (for/vector ([_ (in-range n-reads)])
                         (cell-id (random n-cells))))
      (collect-garbage) (collect-garbage)
      (define start (current-inexact-milliseconds))
      (for ([i (in-range n-reads)])
        (net-cell-read net (vector-ref rand-ids i)))
      (define elapsed (- (current-inexact-milliseconds) start))
      (printf "  ~a (~a reads): ~a ns/read (~a ms total)\n"
              label n-reads
              (exact->inexact (/ (* elapsed 1000000) n-reads))
              (exact->inexact elapsed)))))

(bench-random-reads "20K cells" net-20k 20000 10000)
(bench-random-reads "100K cells" net-100k 100000 10000)
(when net-500k
  (bench-random-reads "500K cells" net-500k 500000 10000))

;; A5: Memory consumption
(printf "\n--- A5: Memory consumption (bytes/cell) ---\n")

(define (bench-memory label n-cells)
  (with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED (~a): ~a\n" label (exn-message e)))])
    (collect-garbage) (collect-garbage) (collect-garbage)
    (define mem-before (current-memory-use))
    (define net0 (make-prop-network 10000000))
    (define net-final
      (for/fold ([net net0]) ([i (in-range n-cells)])
        (define-values (net* _cid) (net-new-cell net 'bot merge-set-once))
        net*))
    ;; Force retention
    (void (prop-network-cells net-final))
    (collect-garbage) (collect-garbage)
    (define mem-after (current-memory-use))
    (define delta (- mem-after mem-before))
    (printf "  ~a (~a cells): ~a bytes total, ~a bytes/cell\n"
            label n-cells delta
            (exact->inexact (/ delta n-cells)))))

(bench-memory "20K" 20000)
(bench-memory "100K" 100000)

;; A6: GC pressure
(printf "\n--- A6: GC pressure during cell creation ---\n")

(define (bench-gc-pressure label n-cells)
  (with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED (~a): ~a\n" label (exn-message e)))])
    (collect-garbage) (collect-garbage) (collect-garbage)
    (define gc-before (current-gc-milliseconds))
    (define net0 (make-prop-network 10000000))
    (define net-final
      (for/fold ([net net0]) ([i (in-range n-cells)])
        (define-values (net* _cid) (net-new-cell net 'bot merge-set-once))
        net*))
    (void (prop-network-cells net-final))
    (define gc-after (current-gc-milliseconds))
    (printf "  ~a (~a cells): ~a ms GC time\n"
            label n-cells (- gc-after gc-before))))

(bench-gc-pressure "20K" 20000)
(bench-gc-pressure "100K" 100000)

;; A7: 4-tuple key lookup simulation (Earley item keys)
(printf "\n--- A7: 4-tuple key lookup simulation ---\n")

;; Flat hasheq approach: (list prod dot origin span-end) -> cell-id
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (define flat-table
    (for/hasheq ([i (in-range 20000)])
      (define key (vector (modulo i 100) (modulo i 20) (quotient i 200) i))
      (values key (cell-id i))))
  ;; Pre-generate lookup keys
  (define lookup-keys
    (for/vector ([_ (in-range 10000)])
      (define i (random 20000))
      (vector (modulo i 100) (modulo i 20) (quotient i 200) i)))

  (define flat-idx (box 0))
  (bench "flat hasheq 4-tuple lookup" 10000
    (hash-ref flat-table (vector-ref lookup-keys (unbox flat-idx)) #f)
    (set-box! flat-idx (modulo (+ 1 (unbox flat-idx)) 10000))))

;; Nested hasheq approach: prod -> (dot -> (origin -> cell-id))
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED (nested): ~a\n" (exn-message e)))])
  (define nested-table (make-hasheq))
  (for ([i (in-range 20000)])
    (define prod (modulo i 100))
    (define dot (modulo i 20))
    (define origin (quotient i 200))
    (define by-prod (hash-ref nested-table prod (lambda () (make-hasheq))))
    (define by-dot (hash-ref by-prod dot (lambda () (make-hasheq))))
    (hash-set! by-dot origin (cell-id i))
    (hash-set! by-prod dot by-dot)
    (hash-set! nested-table prod by-prod))

  (define nested-keys
    (for/vector ([_ (in-range 10000)])
      (define i (random 20000))
      (vector (modulo i 100) (modulo i 20) (quotient i 200))))

  (define nest-idx (box 0))
  (bench "nested hasheq 3-level lookup" 10000
    (define k (vector-ref nested-keys (unbox nest-idx)))
    (define t1 (hash-ref nested-table (vector-ref k 0) #f))
    (when t1
      (define t2 (hash-ref t1 (vector-ref k 1) #f))
      (when t2
        (hash-ref t2 (vector-ref k 2) #f)))
    (set-box! nest-idx (modulo (+ 1 (unbox nest-idx)) 10000))))


;; ============================================================
;; B. Lattice Merge Operations
;; ============================================================

(printf "\n=== B. Lattice Merge Operations ===\n\n")

;; B1: Set-once write (flat lattice)
(printf "--- B1: Set-once write (bot -> value) ---\n")
(bench "set-once write" 100000
  (define net0 (make-prop-network))
  (define-values (net1 cid) (net-new-cell net0 'bot merge-set-once))
  (net-cell-write net1 cid (expr-Int)))

;; B2: Set union (small) — 3-element seteq
(printf "\n--- B2: Set union (small, 3 elements) ---\n")
(let ()
  (define s1 (seteq 'a 'b 'c))
  (define s2 (seteq 'c 'd 'e))
  (bench "seteq union (3 elem)" 100000
    (set-union s1 s2)))

;; B3: Set union (large) — 50-element seteq
(printf "\n--- B3: Set union (large, 50 elements) ---\n")
(let ()
  (define s1 (for/seteq ([i (in-range 50)]) i))
  (define s2 (for/seteq ([i (in-range 25 75)]) i))
  (bench "seteq union (50 elem)" 10000
    (set-union s1 s2)))

;; B4: Derivation-node struct construction (vector simulation)
(printf "\n--- B4: Derivation-node vector construction ---\n")
(bench "derivation-node vector" 100000
  (vector 'struct:derivation-node 'item-placeholder '() 0 0))

;; B5: SPPF sharing check (hash lookup for derivation dedup)
(printf "\n--- B5: SPPF sharing check (hash lookup in 1K derivations) ---\n")
(let ()
  (define derivation-table
    (for/hasheq ([i (in-range 1000)])
      (values (vector 'deriv i (modulo i 50) (quotient i 20)) #t)))
  (define lookup-keys
    (for/vector ([_ (in-range 100000)])
      (define i (random 1000))
      (vector 'deriv i (modulo i 50) (quotient i 20))))

  (define sppf-idx (box 0))
  (bench "SPPF hash lookup (1K derivations)" 100000
    (hash-ref derivation-table (vector-ref lookup-keys (unbox sppf-idx)) #f)
    (set-box! sppf-idx (modulo (+ 1 (unbox sppf-idx)) 100000))))


;; ============================================================
;; C. Current Pipeline Baselines (per-form costs)
;; ============================================================

(printf "\n=== C. Current Pipeline Baselines ===\n\n")

(define test-ws-source
  "def x : Int := 42\ndef y : Bool := true\nspec f Int -> Int\ndefn f [x] [int+ x 1]")

;; C1: Reader time
(printf "--- C1: WS reader time ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (bench "read-all-forms-string (4 forms)" 100
    (read-all-forms-string test-ws-source))
  (let ()
    (define forms (read-all-forms-string test-ws-source))
    (printf "  Forms read: ~a, per-form cost = total/~a\n"
            (length forms) (length forms))))

;; C2: Preparse time
(printf "\n--- C2: Preparse time ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (define raw-forms (read-all-forms-string test-ws-source))
  (define stxs (map (lambda (d) (datum->syntax #f d)) raw-forms))
  (bench "preparse-expand-all (4 forms)" 100
    (preparse-expand-all stxs)))

;; C3: Full pipeline per-form (with prelude)
(printf "\n--- C3: Full pipeline per-form ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  ;; Measure prelude load time separately
  (collect-garbage) (collect-garbage)
  (define prelude-start (current-inexact-milliseconds))
  (for ([_ (in-range 5)])
    (process-string "(ns bench-prelude)"))
  (define prelude-elapsed (- (current-inexact-milliseconds) prelude-start))
  (printf "  Prelude load: ~a ms/call (~a calls)\n"
          (exact->inexact (/ prelude-elapsed 5)) 5)

  ;; Measure single def with prelude
  (collect-garbage) (collect-garbage)
  (define pipeline-start (current-inexact-milliseconds))
  (for ([_ (in-range 20)])
    (process-string "(ns bench-c3)\n(def x : Int := 42)"))
  (define pipeline-elapsed (- (current-inexact-milliseconds) pipeline-start))
  (printf "  Full pipeline (ns+def): ~a ms/call (~a calls)\n"
          (exact->inexact (/ pipeline-elapsed 20)) 20)
  (printf "  Estimated per-form (minus prelude): ~a ms\n"
          (exact->inexact (- (/ pipeline-elapsed 20) (/ prelude-elapsed 5)))))

;; C4: Pipeline breakdown (reader -> preparse -> full)
(printf "\n--- C4: Pipeline stage breakdown ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (define single-form "def x : Int := 42")

  ;; Stage 1: Read
  (collect-garbage)
  (define read-start (current-inexact-milliseconds))
  (for ([_ (in-range 500)])
    (read-all-forms-string single-form))
  (define read-elapsed (- (current-inexact-milliseconds) read-start))

  ;; Stage 2: Preparse
  (define raw (read-all-forms-string single-form))
  (define stxs (map (lambda (d) (datum->syntax #f d)) raw))
  (collect-garbage)
  (define preparse-start (current-inexact-milliseconds))
  (for ([_ (in-range 500)])
    (preparse-expand-all stxs))
  (define preparse-elapsed (- (current-inexact-milliseconds) preparse-start))

  ;; Stage 3: Full pipeline (includes read + preparse + elaborate + type-check)
  (collect-garbage)
  (define full-start (current-inexact-milliseconds))
  (for ([_ (in-range 100)])
    (process-string-ws single-form))
  (define full-elapsed (- (current-inexact-milliseconds) full-start))

  (define read-per (/ read-elapsed 500))
  (define preparse-per (/ preparse-elapsed 500))
  (define full-per (/ full-elapsed 100))

  (printf "  Read:     ~a ms/form (~a%)\n"
          (exact->inexact read-per)
          (exact->inexact (* 100 (/ read-per full-per))))
  (printf "  Preparse: ~a ms/form (~a%)\n"
          (exact->inexact preparse-per)
          (exact->inexact (* 100 (/ preparse-per full-per))))
  (printf "  Full:     ~a ms/form (100%)\n"
          (exact->inexact full-per))
  (printf "  Elab+TC:  ~a ms/form (~a%)\n"
          (exact->inexact (- full-per read-per preparse-per))
          (exact->inexact (* 100 (/ (- full-per read-per preparse-per) full-per)))))


;; ============================================================
;; D. Quiescence Scaling
;; ============================================================

(printf "\n=== D. Quiescence Scaling ===\n\n")

;; Helper: build a network with N cells and N identity propagators (cell_i -> cell_{i+N})
(define (make-identity-chain-network n-pairs)
  (define net0 (make-prop-network (* n-pairs 100)))
  ;; Create 2N cells (N source, N target)
  (define-values (net-cells src-ids tgt-ids)
    (for/fold ([net net0] [srcs '()] [tgts '()])
              ([i (in-range n-pairs)])
      (define-values (net1 src) (net-new-cell net 'bot merge-set-once))
      (define-values (net2 tgt) (net-new-cell net1 'bot merge-set-once))
      (values net2 (cons src srcs) (cons tgt tgts))))
  (define src-vec (list->vector (reverse src-ids)))
  (define tgt-vec (list->vector (reverse tgt-ids)))
  ;; Add N identity propagators: read src_i, write to tgt_i
  (define net-with-props
    (for/fold ([net net-cells]) ([i (in-range n-pairs)])
      (define src (vector-ref src-vec i))
      (define tgt (vector-ref tgt-vec i))
      (define-values (net* _pid)
        (net-add-propagator net (list src) (list tgt)
          (lambda (n)
            (define v (net-cell-read n src))
            (if (eq? v 'bot) n (net-cell-write n tgt v)))))
      net*))
  ;; Run initial quiescence (propagators fire once, see bot, no-op)
  (define net-quiesced (run-to-quiescence net-with-props))
  (values net-quiesced src-vec tgt-vec))

;; D1: 100 cells + 100 propagators
(printf "--- D1: 100 cells + 100 identity propagators ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (define-values (net100 srcs100 _tgts100) (make-identity-chain-network 100))
  (bench "quiesce 100 pairs (write src_0)" 100
    (define net* (net-cell-write net100 (vector-ref srcs100 0) 'token))
    (run-to-quiescence net*)))

;; D2: 1,000 cells + 1,000 propagators
(printf "\n--- D2: 1K cells + 1K identity propagators ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (define-values (net1k srcs1k _tgts1k) (make-identity-chain-network 1000))
  (bench "quiesce 1K pairs (write src_0)" 10
    (define net* (net-cell-write net1k (vector-ref srcs1k 0) 'token))
    (run-to-quiescence net*)))

;; D3: 10,000 cells + 10,000 propagators
(printf "\n--- D3: 10K cells + 10K identity propagators ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (define-values (net10k srcs10k _tgts10k) (make-identity-chain-network 10000))
  (bench "quiesce 10K pairs (write src_0)" 3
    (define net* (net-cell-write net10k (vector-ref srcs10k 0) 'token))
    (run-to-quiescence net*)))

;; D4: Fan-out pattern (1 source -> 10 targets)
(printf "\n--- D4: Fan-out (1 source -> 10 targets) ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (define net-fan0 (make-prop-network 100000))
  (define-values (net-fan1 fan-src) (net-new-cell net-fan0 'bot merge-set-once))
  (define-values (net-fan2 fan-tgts)
    (for/fold ([net net-fan1] [tgts '()])
              ([i (in-range 10)])
      (define-values (net* tgt) (net-new-cell net 'bot merge-set-once))
      (values net* (cons tgt tgts))))
  (define net-fan3
    (for/fold ([net net-fan2]) ([tgt (in-list fan-tgts)])
      (define-values (net* _pid)
        (net-add-propagator net (list fan-src) (list tgt)
          (lambda (n)
            (define v (net-cell-read n fan-src))
            (if (eq? v 'bot) n (net-cell-write n tgt v)))))
      net*))
  (define net-fan-q (run-to-quiescence net-fan3))
  (bench "fan-out 1->10 (write source, quiesce)" 1000
    (define net* (net-cell-write net-fan-q fan-src 'token))
    (run-to-quiescence net*)))

;; D5: Chain pattern (cell_0 -> prop -> cell_1 -> prop -> ... -> cell_N)
(printf "\n--- D5: Chain pattern ---\n")

(define (make-chain-network chain-len)
  (define net0 (make-prop-network (* chain-len 10)))
  ;; Create chain-len+1 cells
  (define-values (net-cells chain-ids)
    (for/fold ([net net0] [ids '()])
              ([i (in-range (+ chain-len 1))])
      (define-values (net* cid) (net-new-cell net 'bot merge-set-once))
      (values net* (cons cid ids))))
  (define id-vec (list->vector (reverse chain-ids)))
  ;; Add chain-len propagators: cell_i -> cell_{i+1}
  (define net-with-props
    (for/fold ([net net-cells]) ([i (in-range chain-len)])
      (define src (vector-ref id-vec i))
      (define tgt (vector-ref id-vec (+ i 1)))
      (define-values (net* _pid)
        (net-add-propagator net (list src) (list tgt)
          (lambda (n)
            (define v (net-cell-read n src))
            (if (eq? v 'bot) n (net-cell-write n tgt v)))))
      net*))
  (define net-q (run-to-quiescence net-with-props))
  (values net-q (vector-ref id-vec 0)))

(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED (chain 100): ~a\n" (exn-message e)))])
  (define-values (net-chain100 chain100-src) (make-chain-network 100))
  (bench "chain len=100 (write cell_0, quiesce)" 100
    (define net* (net-cell-write net-chain100 chain100-src 'token))
    (run-to-quiescence net*)))

(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED (chain 1000): ~a\n" (exn-message e)))])
  (define-values (net-chain1k chain1k-src) (make-chain-network 1000))
  (bench "chain len=1000 (write cell_0, quiesce)" 10
    (define net* (net-cell-write net-chain1k chain1k-src 'token))
    (run-to-quiescence net*)))


;; ============================================================
;; E. ATMS Operations
;; ============================================================

(printf "\n=== E. ATMS Operations ===\n\n")

;; E1: Create ATMS assumption
(printf "--- E1: ATMS assumption creation ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (bench "atms-assume" 10000
    (define a0 (atms-empty))
    (define-values (a1 aid1) (atms-assume a0 'h1 'value1))
    (void a1 aid1)))

;; E2: Tag a cell write with an assumption (TMS-tagged entry)
(printf "\n--- E2: ATMS cell write (TMS-tagged) ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (define a0-e2 (atms-empty))
  (define-values (a1-e2 aid-e2) (atms-assume a0-e2 'h1 'val))
  (bench "atms-write-cell (with assumption)" 10000
    (atms-write-cell a1-e2 'cell-key (expr-Int)
                     (hasheq aid-e2 #t))))

;; E3: Create 2 ATMS branches (ambiguous parse simulation)
(printf "\n--- E3: ATMS 2-branch ambiguity ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (bench "atms-amb 2 alternatives" 1000
    (define a0 (atms-empty))
    (define-values (_a _hyps) (atms-amb a0 (list 'parse-A 'parse-B)))
    (void)))

;; E4: Retract an assumption
(printf "\n--- E4: ATMS retraction ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  ;; Pre-build the ATMS with 2 alternatives
  (define a0-e4 (atms-empty))
  (define-values (a-amb hyp-ids) (atms-amb a0-e4 (list 'parse-A 'parse-B)))
  (define first-hyp (car hyp-ids))
  (bench "atms-retract (1 assumption)" 1000
    (atms-retract a-amb first-hyp)))


;; ============================================================
;; Summary
;; ============================================================

(printf "\n=== Summary ===\n\n")

;; Cell creation rate comparison
(when (and net-20k net-100k)
  (printf "Cell creation scaling:\n")
  (printf "  See A1 vs A2 ns/cell for 20K vs 100K comparison\n")
  (printf "  Sub-linear degradation indicates CHAMP path sharing.\n")
  (printf "  Super-linear indicates tree rebalancing pressure.\n\n"))

;; Quiescence scaling
(printf "Quiescence scaling:\n")
(printf "  Compare D1 (100 pairs), D2 (1K pairs), D3 (10K pairs).\n")
(printf "  Linear: O(N) firings. Super-linear: scheduling overhead dominates.\n\n")

;; Parse domain feasibility
(printf "Parse domain feasibility check:\n")
(printf "  A typical Earley parse of a 1000-token input creates ~~50K-100K items.\n")
(printf "  Each item = 1 cell. Merge = set-once (flat lattice).\n")
(printf "  If A2 (100K cells) completes in < 1s, infrastructure capacity is sufficient.\n")
(printf "  If quiescence at 10K props (D3) completes in < 100ms, propagation is viable.\n\n")

(printf "Done.\n")
