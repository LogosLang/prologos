#lang racket/base

;; bench-track10-module-loading.rkt — Micro-benchmarks for PM Track 10: Module Loading on Network
;;
;; Measures the overhead of the key operations that Track 10 targets:
;;   A. Parameterize overhead (41-binding teardown, 15-binding run-ns-last, nested chains)
;;   B. Cache-hit costs (load-module cache path, env-snapshot import loop, registry propagation)
;;   C. CHAMP fork operations (structural sharing, read-through, write-in-child, deep chains)
;;   D. Prelude end-to-end (full ns bench, per-module breakdown)
;;   E. Isolation verification (CHAMP correctness assertion, fork-discard cycles)
;;   F. Memory (prelude-scale CHAMP, incremental fork cost)
;;   G. Batch worker comparison (run-ns-last state restoration)

(require racket/list
         racket/port
         racket/format
         "../../champ.rkt"
         "../../propagator.rkt"
         "../../driver.rkt"
         "../../namespace.rkt"
         "../../metavar-store.rkt"
         "../../global-env.rkt"
         "../../macros.rkt"
         "../../warnings.rkt"
         "../../global-constraints.rkt"
         "../../tests/test-support.rkt")

;; ============================================================
;; Bench helper macro
;; ============================================================

(define-syntax-rule (bench label iters body ...)
  (let ()
    (collect-garbage)
    (collect-garbage)
    (define start (current-inexact-milliseconds))
    (for ([_ (in-range iters)])
      body ...)
    (define elapsed (- (current-inexact-milliseconds) start))
    (printf "  ~a: ~a ns/call (~a calls, ~a ms total)\n"
            label
            (~r (exact->inexact (/ (* elapsed 1000000) iters)) #:precision '(= 1))
            iters
            (~r elapsed #:precision '(= 2)))))

;; Variant that returns (values elapsed-ms per-call-ns) for downstream use
(define-syntax-rule (bench/v label iters body ...)
  (let ()
    (collect-garbage)
    (collect-garbage)
    (define start (current-inexact-milliseconds))
    (for ([_ (in-range iters)])
      body ...)
    (define elapsed (- (current-inexact-milliseconds) start))
    (define per-call-ns (exact->inexact (/ (* elapsed 1000000) iters)))
    (printf "  ~a: ~a ns/call (~a calls, ~a ms total)\n"
            label per-call-ns iters
            (~r elapsed #:precision '(= 2)))
    (values elapsed per-call-ns)))

;; ============================================================
;; Category A: Parameterize Overhead
;; ============================================================

(printf "\n=== A. Parameterize Overhead ===\n\n")

;; A1: 41-binding parameterize (simulates full process-command setup)
(let ()
  (define p0  (make-parameter #f)) (define p1  (make-parameter #f))
  (define p2  (make-parameter #f)) (define p3  (make-parameter #f))
  (define p4  (make-parameter #f)) (define p5  (make-parameter #f))
  (define p6  (make-parameter #f)) (define p7  (make-parameter #f))
  (define p8  (make-parameter #f)) (define p9  (make-parameter #f))
  (define p10 (make-parameter #f)) (define p11 (make-parameter #f))
  (define p12 (make-parameter #f)) (define p13 (make-parameter #f))
  (define p14 (make-parameter #f)) (define p15 (make-parameter #f))
  (define p16 (make-parameter #f)) (define p17 (make-parameter #f))
  (define p18 (make-parameter #f)) (define p19 (make-parameter #f))
  (define p20 (make-parameter #f)) (define p21 (make-parameter #f))
  (define p22 (make-parameter #f)) (define p23 (make-parameter #f))
  (define p24 (make-parameter #f)) (define p25 (make-parameter #f))
  (define p26 (make-parameter #f)) (define p27 (make-parameter #f))
  (define p28 (make-parameter #f)) (define p29 (make-parameter #f))
  (define p30 (make-parameter #f)) (define p31 (make-parameter #f))
  (define p32 (make-parameter #f)) (define p33 (make-parameter #f))
  (define p34 (make-parameter #f)) (define p35 (make-parameter #f))
  (define p36 (make-parameter #f)) (define p37 (make-parameter #f))
  (define p38 (make-parameter #f)) (define p39 (make-parameter #f))
  (define p40 (make-parameter #f))
  (bench "A1: parameterize 41 bindings (static, empty body)" 10000
    (parameterize ([p0  1] [p1  1] [p2  1] [p3  1] [p4  1]
                   [p5  1] [p6  1] [p7  1] [p8  1] [p9  1]
                   [p10 1] [p11 1] [p12 1] [p13 1] [p14 1]
                   [p15 1] [p16 1] [p17 1] [p18 1] [p19 1]
                   [p20 1] [p21 1] [p22 1] [p23 1] [p24 1]
                   [p25 1] [p26 1] [p27 1] [p28 1] [p29 1]
                   [p30 1] [p31 1] [p32 1] [p33 1] [p34 1]
                   [p35 1] [p36 1] [p37 1] [p38 1] [p39 1]
                   [p40 1])
      (void))))

;; A2: 15-binding parameterize (run-ns-last pattern)
(let ()
  (define ps (for/list ([i (in-range 15)]) (make-parameter #f)))
  (define p0  (list-ref ps 0))  (define p1  (list-ref ps 1))
  (define p2  (list-ref ps 2))  (define p3  (list-ref ps 3))
  (define p4  (list-ref ps 4))  (define p5  (list-ref ps 5))
  (define p6  (list-ref ps 6))  (define p7  (list-ref ps 7))
  (define p8  (list-ref ps 8))  (define p9  (list-ref ps 9))
  (define p10 (list-ref ps 10)) (define p11 (list-ref ps 11))
  (define p12 (list-ref ps 12)) (define p13 (list-ref ps 13))
  (define p14 (list-ref ps 14))
  (bench "A2: parameterize 15 bindings (run-ns-last scale)" 10000
    (parameterize ([p0  1] [p1  1] [p2  1] [p3  1] [p4  1]
                   [p5  1] [p6  1] [p7  1] [p8  1] [p9  1]
                   [p10 1] [p11 1] [p12 1] [p13 1] [p14 1])
      (void))))

;; A3: 63 nested parameterize (each with 5 bindings) — cache-hit prelude import chain
(let ()
  ;; 63 groups × 5 params = 315 total parameters
  (define all-ps (for/list ([i (in-range 315)]) (make-parameter #f)))
  ;; Build a thunk that nests 63 parameterize forms, each binding 5 params
  (define thunk
    (for/fold ([f (lambda () (void))])
              ([group (in-range 63)])
      (define offset (* group 5))
      (define g0 (list-ref all-ps (+ offset 0)))
      (define g1 (list-ref all-ps (+ offset 1)))
      (define g2 (list-ref all-ps (+ offset 2)))
      (define g3 (list-ref all-ps (+ offset 3)))
      (define g4 (list-ref all-ps (+ offset 4)))
      (lambda ()
        (parameterize ([g0 1] [g1 1] [g2 1] [g3 1] [g4 1])
          (f)))))
  (bench "A3: 63 nested parameterize (5 bindings each)" 100
    (thunk)))

;; ============================================================
;; Category B: Cache-Hit Costs
;; ============================================================

(printf "\n=== B. Cache-Hit Costs ===\n\n")

;; B1: load-module cache hit
;; First, we need to get a module that's already loaded.
;; prelude-module-registry has many modules; we pick one.
(let ()
  (define mod-keys
    (for/list ([(k v) (in-hash prelude-module-registry)])
      k))
  (define test-mod (if (pair? mod-keys) (car mod-keys) #f))
  (when test-mod
    (bench "B1: lookup-module cache hit (already-loaded module)" 1000
      (parameterize ([current-module-registry prelude-module-registry])
        (define result (lookup-module test-mod))
        (void result)))))

;; B2: Hash-set loop for env-snapshot import (50-entry hasheq)
(let ()
  (define source-env
    (for/hasheq ([i (in-range 50)])
      (values (string->symbol (format "name~a" i))
              (vector i 'type 'value))))
  (bench "B2: hash-set loop: 50-entry env-snapshot import" 10000
    (define target
      (for/fold ([h (hasheq)]) ([(k v) (in-hash source-env)])
        (hash-set h k v)))
    (void target)))

;; B3: 7 hash-union operations (simulating registry propagation)
(let ()
  (define base (for/hasheq ([i (in-range 20)]) (values i (* i i))))
  (define overlays
    (for/list ([j (in-range 7)])
      (for/hasheq ([i (in-range 5)])
        (values (+ (* j 100) i) i))))
  (bench "B3: 7 hash-union operations (registry propagation)" 10000
    (define result
      (for/fold ([acc base]) ([ov (in-list overlays)])
        (for/fold ([a acc]) ([(k v) (in-hash ov)])
          (hash-set a k v))))
    (void result)))

;; ============================================================
;; Category C: CHAMP Fork Operations
;; ============================================================

(printf "\n=== C. CHAMP Fork Operations ===\n\n")

;; Helper: build a CHAMP with N entries
(define (make-champ n)
  (for/fold ([m champ-empty]) ([i (in-range n)])
    (champ-insert m i i (* i i))))

;; C1: Fork a 100-entry CHAMP (insert 1 new entry for structural sharing)
(let ()
  (define parent (make-champ 100))
  (bench "C1: CHAMP fork (100 entries, insert 1 new)" 10000
    (define child (champ-insert parent 999 999 999))
    (void child)))

;; C2: Fork a 5000-entry CHAMP (insert 1 new entry)
(let ()
  (define parent (make-champ 5000))
  (bench "C2: CHAMP fork (5000 entries, insert 1 new)" 1000
    (define child (champ-insert parent 99999 99999 99999))
    (void child)))

;; C3: Read-through: parent 100 entries, child = parent + 1 new, read parent entry from child
(let ()
  (define parent (make-champ 100))
  (define child (champ-insert parent 999 999 999))
  (bench "C3: CHAMP read-through (child reads parent entry)" 50000
    (define v (champ-lookup child 50 50))
    (void v)))

;; C4: Write in child: fork + insert 10 entries
(let ()
  (define parent (make-champ 100))
  (bench "C4: CHAMP fork + insert 10 in child" 10000
    (define child
      (for/fold ([m (champ-insert parent 1000 1000 1000)])
                ([i (in-range 10)])
        (champ-insert m (+ 2000 i) (+ 2000 i) (* i i))))
    (void child)))

;; C5: 4-deep fork chain, each adding 5 entries, read from deepest
(let ()
  (define parent (make-champ 100))
  (bench "C5: 4-deep CHAMP fork chain (5 entries each), read deepest" 1000
    (define child1
      (for/fold ([m parent]) ([i (in-range 5)])
        (champ-insert m (+ 1000 i) (+ 1000 i) i)))
    (define child2
      (for/fold ([m child1]) ([i (in-range 5)])
        (champ-insert m (+ 2000 i) (+ 2000 i) i)))
    (define child3
      (for/fold ([m child2]) ([i (in-range 5)])
        (champ-insert m (+ 3000 i) (+ 3000 i) i)))
    (define child4
      (for/fold ([m child3]) ([i (in-range 5)])
        (champ-insert m (+ 4000 i) (+ 4000 i) i)))
    ;; Read an original parent entry from the deepest child
    (define v (champ-lookup child4 50 50))
    (void v)))

;; ============================================================
;; Category D: Prelude End-to-End
;; ============================================================

(printf "\n=== D. Prelude End-to-End ===\n\n")

;; D2 runs FIRST to get per-module timing before D1 warms caches further.
;; D2: Per-module timing breakdown — instrument individual module loads
;; We use the keys from prelude-module-registry to identify modules that
;; were loaded during prelude caching, then re-load them from scratch.
(let ()
  (printf "  D2: Per-module timing breakdown (loading from scratch):\n")
  (define prelude-modules
    (for/list ([(k v) (in-hash prelude-module-registry)]) k))
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-definition-cells-content (hasheq)]
                 [current-definition-dependencies (hasheq)]
                 [current-cross-module-deps '()]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)]
                 [current-capability-registry (current-capability-registry)]
                 [current-prop-net-box              #f]
                 [current-persistent-registry-net-box #f]
                 [current-prelude-env-prop-net-box   #f]
                 [current-ns-prop-net-box           #f]
                 [current-definition-cell-ids       (hasheq)]
                 [current-module-registry-cell-id   #f]
                 [current-ns-context-cell-id        #f]
                 [current-defn-param-names-cell-id  #f])
    (install-module-loader!)
    ;; Sort module names for consistent output
    (define sorted-modules (sort prelude-modules symbol<?))
    (define total-ms 0.0)
    (define timings '())
    (for ([mod-sym (in-list sorted-modules)])
      (unless (module-loaded? mod-sym)
        (collect-garbage)
        (define t0 (current-inexact-milliseconds))
        (with-output-to-string
          (lambda ()
            (parameterize ([current-error-port (current-output-port)])
              (with-handlers ([exn:fail? (lambda (e)
                                           (printf "    [ERR] ~a: ~a\n" mod-sym (exn-message e)))])
                (load-module mod-sym)))))
        (define dt (- (current-inexact-milliseconds) t0))
        (set! total-ms (+ total-ms dt))
        (set! timings (cons (cons mod-sym dt) timings))))
    ;; Print all modules sorted by load time (slowest first)
    (define sorted-timings (sort timings > #:key cdr))
    (for ([entry (in-list sorted-timings)])
      (printf "    ~a: ~a ms\n"
              (car entry) (~r (cdr entry) #:precision '(= 1))))
    (printf "    --- total per-module load time: ~a ms (~a modules) ---\n"
            (~r total-ms #:precision '(= 1))
            (length sorted-modules))))

;; D1: Full (process-string "(ns bench)") — expensive, few iterations
(let ()
  (bench "D1: process-string \"(ns bench)\" (full prelude)" 3
    (parameterize ([current-prelude-env (hasheq)]
                   [current-module-definitions-content (hasheq)]
                   [current-definition-cells-content (hasheq)]
                   [current-definition-dependencies (hasheq)]
                   [current-cross-module-deps '()]
                   [current-ns-context #f]
                   [current-module-registry (hasheq)]
                   [current-lib-paths (list prelude-lib-dir)]
                   [current-preparse-registry (current-preparse-registry)]
                   [current-trait-registry (current-trait-registry)]
                   [current-impl-registry (current-impl-registry)]
                   [current-param-impl-registry (current-param-impl-registry)]
                   [current-capability-registry (current-capability-registry)]
                   [current-prop-net-box              #f]
                   [current-persistent-registry-net-box #f]
                   [current-prelude-env-prop-net-box   #f]
                   [current-ns-prop-net-box           #f]
                   [current-definition-cell-ids       (hasheq)]
                   [current-module-registry-cell-id   #f]
                   [current-ns-context-cell-id        #f]
                   [current-defn-param-names-cell-id  #f])
      (install-module-loader!)
      (with-output-to-string
        (lambda ()
          (parameterize ([current-error-port (current-output-port)])
            (process-string "(ns bench)\n")))))))

;; ============================================================
;; Category E: Isolation Verification
;; ============================================================

(printf "\n=== E. Isolation Verification ===\n\n")

;; E1: CHAMP isolation correctness assertion
(let ()
  (define parent (make-champ 100))
  (define child (champ-insert parent 999 999 42))
  ;; Modify child further
  (define child2 (champ-insert child 998 998 99))
  (define child3 (champ-delete child2 50 50))
  ;; Verify parent is unmodified
  (define parent-50 (champ-lookup parent 50 50))
  (define parent-999 (champ-lookup parent 999 999))
  (define child3-50 (champ-lookup child3 50 50))
  (printf "  E1: CHAMP isolation correctness:\n")
  (printf "    parent has key 50?    ~a (expect: 2500)\n" parent-50)
  (printf "    parent has key 999?   ~a (expect: 'none — not in parent)\n" parent-999)
  (printf "    child3 has key 50?    ~a (expect: 'none — deleted in child3)\n" child3-50)
  (printf "    child3 has key 999?   ~a (expect: 42)\n" (champ-lookup child3 999 999))
  (printf "    child3 has key 998?   ~a (expect: 99)\n" (champ-lookup child3 998 998))
  (define ok? (and (equal? parent-50 2500)
                   (equal? parent-999 'none)
                   (equal? child3-50 'none)
                   (equal? (champ-lookup child3 999 999) 42)
                   (equal? (champ-lookup child3 998 998) 99)))
  (printf "    PASS: ~a\n" ok?))

;; E2: 100 sequential fork → insert 50 → discard cycles
(let ()
  (define parent (make-champ 200))
  (printf "  E2: 100 fork → insert 50 → discard cycles (3 iterations):\n")
  (for ([iter (in-range 3)])
    (collect-garbage)
    (collect-garbage)
    (define gc-before (current-gc-milliseconds))
    (define t0 (current-inexact-milliseconds))
    (for ([cycle (in-range 100)])
      (define child
        (for/fold ([m (champ-insert parent (+ 10000 cycle) (+ 10000 cycle) cycle)])
                  ([i (in-range 50)])
          (champ-insert m (+ 20000 (* cycle 100) i)
                        (+ 20000 (* cycle 100) i) i)))
      (void child))  ;; discard
    (define elapsed (- (current-inexact-milliseconds) t0))
    (define gc-after (current-gc-milliseconds))
    (printf "    iter ~a: ~a ms total, ~a ms GC\n"
            iter
            (~r elapsed #:precision '(= 2))
            (- gc-after gc-before))))

;; ============================================================
;; Category F: Memory
;; ============================================================

(printf "\n=== F. Memory ===\n\n")

;; F1: CHAMP with 5000 entries (prelude-scale)
(let ()
  (collect-garbage 'major)
  (collect-garbage 'major)
  (define mem-before (current-memory-use))
  (define big-champ (make-champ 5000))
  ;; Keep it alive through the measurement
  (collect-garbage 'major)
  (define mem-after (current-memory-use))
  (define delta (- mem-after mem-before))
  (printf "  F1: 5000-entry CHAMP memory:\n")
  (printf "    before: ~a bytes (~a KB)\n" mem-before (~r (/ mem-before 1024.0) #:precision '(= 1)))
  (printf "    after:  ~a bytes (~a KB)\n" mem-after (~r (/ mem-after 1024.0) #:precision '(= 1)))
  (printf "    delta:  ~a bytes (~a KB)\n" delta (~r (/ delta 1024.0) #:precision '(= 1)))
  (printf "    per-entry: ~a bytes\n" (~r (/ delta 5000.0) #:precision '(= 1)))
  ;; Keep alive
  (void (champ-size big-champ)))

;; F2: Fork from 5000-entry CHAMP, measure incremental memory
(let ()
  (define big-champ (make-champ 5000))
  (collect-garbage 'major)
  (collect-garbage 'major)
  (define mem-before (current-memory-use))
  (define forked (champ-insert big-champ 99999 99999 42))
  (collect-garbage 'major)
  (define mem-after (current-memory-use))
  (define delta (- mem-after mem-before))
  (printf "  F2: Fork from 5000-entry CHAMP (insert 1 entry):\n")
  (printf "    incremental delta: ~a bytes\n" delta)
  (printf "    (structural sharing means most nodes are reused)\n")
  ;; Keep alive
  (void (champ-size forked))
  (void (champ-size big-champ)))

;; ============================================================
;; Category G: Batch Worker Comparison
;; ============================================================

(printf "\n=== G. Batch Worker Comparison ===\n\n")

;; G1: Time to restore state from prelude-module-registry (run-ns-last pattern)
(let ()
  (bench "G1: run-ns-last state restoration (parameterize + install-module-loader!)" 100
    (parameterize ([current-prelude-env (hasheq)]
                   [current-module-definitions-content (hasheq)]
                   [current-definition-cells-content (hasheq)]
                   [current-definition-dependencies (hasheq)]
                   [current-cross-module-deps '()]
                   [current-ns-context #f]
                   [current-module-registry prelude-module-registry]
                   [current-lib-paths (list prelude-lib-dir)]
                   [current-preparse-registry prelude-preparse-registry]
                   [current-trait-registry prelude-trait-registry]
                   [current-impl-registry prelude-impl-registry]
                   [current-param-impl-registry prelude-param-impl-registry]
                   [current-prop-net-box              #f]
                   [current-persistent-registry-net-box prelude-persistent-registry-net-box]
                   [current-prelude-env-prop-net-box   #f]
                   [current-ns-prop-net-box           #f]
                   [current-definition-cell-ids       (hasheq)]
                   [current-module-registry-cell-id   #f]
                   [current-ns-context-cell-id        #f]
                   [current-defn-param-names-cell-id  #f])
      (install-module-loader!)
      (void))))

(printf "\n=== Benchmarks complete ===\n")
