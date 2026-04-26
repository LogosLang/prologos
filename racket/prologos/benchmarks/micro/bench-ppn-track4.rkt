#lang racket/base

;;;
;;; PPN Track 4 Pre-0 Benchmarks: Elaboration as Attribute Evaluation
;;;
;;; Establishes baselines BEFORE implementation for A/B comparison.
;;; Measures the current imperative elaboration pipeline that Track 4 replaces.
;;;
;;; Tiers:
;;;   M1-M9:  Micro-benchmarks (individual operation costs)
;;;   A1-A6:  Adversarial tests (worst-case inputs)
;;;   E1-E6:  E2E baselines (real programs through full pipeline)
;;;   V1-V4:  Validation (correctness reference points)
;;;
;;; Usage:
;;;   racket benchmarks/micro/bench-ppn-track4.rkt
;;;

(require racket/list
         racket/match
         racket/format
         racket/string
         racket/port
         "../../syntax.rkt"
         "../../type-lattice.rkt"
         "../../subtype-predicate.rkt"
         "../../union-types.rkt"
         "../../unify.rkt"
         "../../metavar-store.rkt"
         "../../elaborator-network.rkt"
         "../../elab-network-types.rkt"
         "../../reduction.rkt"
         "../../substitution.rkt"
         "../../performance-counters.rkt"
         "../../propagator.rkt"
         "../../typing-core.rkt"
         "../../driver.rkt")

;; ============================================================
;; Timing infrastructure
;; ============================================================

(define-syntax-rule (bench label N-val body)
  (let ()
    (for ([_ (in-range 100)]) body)  ;; warmup
    (define N N-val)
    (collect-garbage)
    (collect-garbage)
    (define start (current-inexact-milliseconds))
    (for ([_ (in-range N)]) body)
    (define end (current-inexact-milliseconds))
    (define mean-us (* 1000.0 (/ (- end start) N)))
    (printf "  ~a: ~a μs/call (~a calls)\n" label (~r mean-us #:precision '(= 3)) N)
    mean-us))

(define-syntax-rule (bench-ms label runs body)
  (let ()
    (for ([_ (in-range 3)]) body)  ;; warmup
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
    (define avg (/ (apply + times) (length times)))
    (printf "  ~a: median=~a ms  mean=~a ms  min=~a  max=~a  (n=~a)\n"
            label
            (~r med #:precision '(= 3))
            (~r avg #:precision '(= 3))
            (~r mn #:precision '(= 3))
            (~r mx #:precision '(= 3))
            runs)
    med))

(define (silent thunk)
  (with-output-to-string
    (lambda ()
      (parameterize ([current-error-port (current-output-port)])
        (thunk)))))

;; ============================================================
;; Helpers
;; ============================================================

(define (with-fresh thunk)
  (with-fresh-meta-env
    (parameterize ([current-reduction-fuel (box 10000)])
      (thunk))))

;; ============================================================
;; M: MICRO-BENCHMARKS — Individual operation costs
;; ============================================================

(displayln "\n=== M: MICRO-BENCHMARKS ===\n")

;; M1: infer on simple expressions
(displayln "M1: infer cost per expression type")
(define m1a (bench "M1a infer Nat literal" 5000
  (with-fresh (λ () (infer '() (expr-Nat))))))
(define m1b (bench "M1b infer Int literal" 5000
  (with-fresh (λ () (infer '() (expr-int 42))))))
(define m1c (bench "M1c infer app (int+ 1 2)" 2000
  (with-fresh (λ () (infer '() (expr-int-add (expr-int 1) (expr-int 2)))))))
(define m1d (bench "M1d infer Pi type" 2000
  (with-fresh (λ () (infer '() (expr-Pi 'mw (expr-Nat) (expr-Bool)))))))

;; M2: check cost
(displayln "\nM2: check cost")
(define m2a (bench "M2a check 42 : Int" 5000
  (with-fresh (λ () (check '() (expr-int 42) (expr-Int))))))
(define m2b (bench "M2b check Nat : Type" 5000
  (with-fresh (λ () (check '() (expr-Nat) (expr-Type 0))))))

;; M3: unify cost
(displayln "\nM3: unify cost")
(define m3a (bench "M3a unify equal (Nat, Nat)" 5000
  (with-fresh (λ () (unify '() (expr-Nat) (expr-Nat))))))
(define m3b (bench "M3b unify Pi structural" 2000
  (with-fresh (λ () (unify '() (expr-Pi 'mw (expr-Nat) (expr-Bool))
                               (expr-Pi 'mw (expr-Nat) (expr-Bool)))))))
(define m3c (bench "M3c unify meta solve" 2000
  (with-fresh
    (λ ()
      (define m (fresh-meta '() (expr-Type 0) 'bench))
      (unify '() m (expr-Nat))))))

;; M4: meta operations
(displayln "\nM4: meta-variable operations")
(define m4a (bench "M4a fresh-meta" 5000
  (with-fresh (λ () (fresh-meta '() (expr-Type 0) 'bench)))))
(define m4b (bench "M4b solve-meta!" 2000
  (with-fresh
    (λ ()
      (define m (fresh-meta '() (expr-Type 0) 'bench))
      (solve-meta! (expr-meta-id m) (expr-Nat))))))

;; M5: save/restore-meta-state (speculation cost)
(displayln "\nM5: speculation (save/restore-meta-state)")
(define m5a (bench "M5a save-meta-state" 5000
  (with-fresh
    (λ ()
      (fresh-meta '() (expr-Type 0) 'setup)  ;; have something to save
      (save-meta-state)))))
(define m5b (bench "M5b restore-meta-state!" 2000
  (with-fresh
    (λ ()
      (fresh-meta '() (expr-Type 0) 'setup)
      (define saved (save-meta-state))
      (fresh-meta '() (expr-Type 0) 'extra)  ;; dirty the state
      (restore-meta-state! saved)))))
(define m5c (bench "M5c save + dirty + restore cycle" 2000
  (with-fresh
    (λ ()
      (fresh-meta '() (expr-Type 0) 'setup)
      (define saved (save-meta-state))
      (for ([_ (in-range 5)]) (fresh-meta '() (expr-Type 0) 'dirty))
      (restore-meta-state! saved)))))

;; M6: type-tensor-core (the propagator fire function)
(displayln "\nM6: type-tensor-core (Track 2H)")
(define m6a (bench "M6a tensor (Int→Bool) Int" 5000
  (type-tensor-core (expr-Pi 'mw (expr-Int) (expr-Bool)) (expr-Int))))
(define m6b (bench "M6b tensor (Int→Bool) String → bot" 5000
  (type-tensor-core (expr-Pi 'mw (expr-Int) (expr-Bool)) (expr-String))))

;; M7: elab-network cell operations
(displayln "\nM7: elab-network cell operations")
(define base-enet (make-elaboration-network))
(define m7a (bench "M7a elab-fresh-meta" 2000
  (elab-fresh-meta base-enet '() (expr-Type 0) 'bench)))
(define-values (enet1 cid1) (elab-fresh-meta base-enet '() (expr-Type 0) 'bench))
(define m7b (bench "M7b elab-cell-write" 5000
  (elab-cell-write enet1 cid1 (expr-Nat))))
(define m7c (bench "M7c elab-cell-read" 10000
  (elab-cell-read enet1 cid1)))

;; M8: elab-network cell creation throughput
(displayln "\nM8: elab-network throughput")
(define m8a (bench "M8a make-elaboration-network" 2000
  (make-elaboration-network)))
(define m8b (bench "M8b 10 elab-fresh-meta on fresh network" 1000
  (let loop ([enet (make-elaboration-network)] [n 10])
    (if (zero? n) enet
        (let-values ([(e* _) (elab-fresh-meta enet '() (expr-Type 0) 'bench)])
          (loop e* (sub1 n)))))))

;; M9: resolution-related cost (use process-string-ws for realistic measurement)
(displayln "\nM9: resolution overhead (measured via E2E)")
(printf "  M9: Resolution cost measured indirectly via E1-E6 phase timings.\n")
(printf "  M9: Typical: 0 constraint retries for simple programs (audit §4).\n")


;; ============================================================
;; A: ADVERSARIAL TESTS — Worst-case inputs
;; ============================================================

(displayln "\n\n=== A: ADVERSARIAL TESTS ===\n")

;; A1: Deep nesting
(displayln "A1: Deep nesting (application chains)")
(define (deep-app depth)
  ;; Build: (int+ (int+ (int+ ... 1 2) 3) 4)
  (if (zero? depth)
      (expr-int 1)
      (expr-int-add (deep-app (sub1 depth)) (expr-int 2))))

(define a1a (bench-ms "A1a infer depth-5 app chain" 10
  (with-fresh (λ () (infer '() (deep-app 5))))))
(define a1b (bench-ms "A1b infer depth-10 app chain" 10
  (with-fresh (λ () (infer '() (deep-app 10))))))
(define a1c (bench-ms "A1c infer depth-20 app chain" 10
  (with-fresh (λ () (infer '() (deep-app 20))))))

;; A2: Many metas
(displayln "\nA2: Many metas (polymorphic inference)")
(define a2a (bench-ms "A2a 5 fresh-meta + solve cycle" 10
  (with-fresh
    (λ ()
      (for ([_ (in-range 5)])
        (define m (fresh-meta '() (expr-Type 0) 'bench))
        (solve-meta! (expr-meta-id m) (expr-Nat)))))))
(define a2b (bench-ms "A2b 20 fresh-meta + solve cycle" 10
  (with-fresh
    (λ ()
      (for ([_ (in-range 20)])
        (define m (fresh-meta '() (expr-Type 0) 'bench))
        (solve-meta! (expr-meta-id m) (expr-Nat)))))))

;; A3: Speculation pressure
(displayln "\nA3: Speculation pressure (save/restore cycles)")
(define a3a (bench-ms "A3a 5 speculation cycles" 10
  (with-fresh
    (λ ()
      (for ([_ (in-range 5)])
        (define s (save-meta-state))
        (fresh-meta '() (expr-Type 0) 'spec)
        (restore-meta-state! s))))))
(define a3b (bench-ms "A3b 20 speculation cycles" 10
  (with-fresh
    (λ ()
      (for ([_ (in-range 20)])
        (define s (save-meta-state))
        (for ([_ (in-range 3)]) (fresh-meta '() (expr-Type 0) 'spec))
        (restore-meta-state! s))))))

;; A4: Cell allocation pressure
(displayln "\nA4: Cell allocation (elab-network)")
(define a4a (bench-ms "A4a 50 elab-fresh-meta" 10
  (let loop ([enet base-enet] [n 50])
    (if (zero? n) enet
        (let-values ([(enet* _) (elab-fresh-meta enet '() (expr-Type 0) 'bench)])
          (loop enet* (sub1 n)))))))
(define a4b (bench-ms "A4b 100 elab-fresh-meta" 10
  (let loop ([enet base-enet] [n 100])
    (if (zero? n) enet
        (let-values ([(enet* _) (elab-fresh-meta enet '() (expr-Type 0) 'bench)])
          (loop enet* (sub1 n)))))))


;; ============================================================
;; E: E2E BASELINES — Real programs through full pipeline
;; ============================================================

(displayln "\n\n=== E: E2E BASELINES ===\n")

(define e1-src
  (string-append
   "ns bench-e1 :no-prelude\n"
   "def x : Int := 42\n"
   "def y : Int := [int+ x 1]\n"
   "eval y\n"))

(define e2-src
  (string-append
   "ns bench-e2 :no-prelude\n"
   "data Color := Red | Green | Blue\n\n"
   "spec show Color -> Int\n"
   "defn show\n"
   "  | Red   -> 1\n"
   "  | Green -> 2\n"
   "  | Blue  -> 3\n\n"
   "eval [show Red]\n"))

(define e3-src
  (string-append
   "ns bench-e3 :no-prelude\n"
   "def m := {:name \"alice\" :age 30}\n"
   "eval m.name\n"
   "eval m.age\n"))

(define e4-src
  (string-append
   "ns bench-e4\n"
   "def xs := '[1N 2N 3N]\n"
   "eval [map [fn [x : Nat] [add x 1N]] xs]\n"))

(define e5-src
  (string-append
   "ns bench-e5\n"
   "eval [+ 1 2]\n"
   "eval [+ 3N 4N]\n"
   "eval [* 2 [+ 3 4]]\n"))

(define e6-src
  (string-append
   "ns bench-e6\n"
   "spec fib Int -> Int\n"
   "defn fib\n"
   "  | 0 -> 0\n"
   "  | 1 -> 1\n"
   "  | n -> [int+ [fib [int- n 1]] [fib [int- n 2]]]\n"
   "eval [fib 10]\n"))

(define e1 (bench-ms "E1 simple (def+spec+eval, no metas)" 10
  (silent (lambda ()
      (process-string-ws e1-src))))))

(define e2 (bench-ms "E2 pattern matching (data+defn arms)" 10
  (silent (lambda ()
      (process-string-ws e2-src))))))

(define e3 (bench-ms "E3 mixed-type maps (union speculation)" 10
  (silent (lambda ()
      (process-string-ws e3-src))))))

(define e4 (bench-ms "E4 list + map (polymorphic, prelude)" 10
  (silent (lambda ()
      (process-string-ws e4-src))))))

(define e5 (bench-ms "E5 generic arithmetic (trait dispatch)" 10
  (silent (lambda ()
      (process-string-ws e5-src))))))

(define e6 (bench-ms "E6 recursive function (fib)" 10
  (silent (lambda ()
      (process-string-ws e6-src))))))


;; ============================================================
;; V: VALIDATION — Correctness reference points
;; ============================================================

(displayln "\n\n=== V: VALIDATION ===\n")

;; V1: infer produces correct types
(displayln "V1: infer correctness")
(define v1-failures 0)
(with-fresh
  (λ ()
    ;; Nat literal → Nat type
    (define t1 (infer '() (expr-Nat)))
    (unless (equal? t1 (expr-Type 0))
      (set! v1-failures (add1 v1-failures))
      (printf "  V1a FAIL: infer(Nat) = ~a (expected Type 0)\n" t1))
    ;; Int literal → Int type
    (define t2 (infer '() (expr-int 42)))
    (unless (equal? t2 (expr-Int))
      (set! v1-failures (add1 v1-failures))
      (printf "  V1b FAIL: infer(42) = ~a (expected Int)\n" t2))
    ;; Int + Int → Int
    (define t3 (infer '() (expr-int-add (expr-int 1) (expr-int 2))))
    (unless (equal? t3 (expr-Int))
      (set! v1-failures (add1 v1-failures))
      (printf "  V1c FAIL: infer(1+2) = ~a (expected Int)\n" t3))))
(printf "  V1 infer correctness: ~a failures\n" v1-failures)

;; V2: meta-solving produces correct solutions
(displayln "\nV2: meta-solving correctness")
(define v2-failures 0)
(with-fresh
  (λ ()
    (define m (fresh-meta '() (expr-Type 0) 'bench))
    (unify '() m (expr-Nat))
    (define sol (meta-solution (expr-meta-id m)))
    (unless (equal? sol (expr-Nat))
      (set! v2-failures (add1 v2-failures))
      (printf "  V2a FAIL: meta solved to ~a (expected Nat)\n" sol))))
(printf "  V2 meta-solving: ~a failures\n" v2-failures)

;; V3: speculation produces correct rollback
(displayln "\nV3: speculation correctness")
(define v3-failures 0)
(with-fresh
  (λ ()
    (define m (fresh-meta '() (expr-Type 0) 'bench))
    (define saved (save-meta-state))
    ;; Speculatively solve the meta
    (solve-meta! (expr-meta-id m) (expr-Int))
    ;; Restore
    (restore-meta-state! saved)
    ;; Meta should be unsolved again
    (define sol-after (meta-solution (expr-meta-id m)))
    (when sol-after
      (set! v3-failures (add1 v3-failures))
      (printf "  V3a FAIL: meta still solved after restore: ~a\n" sol-after))))
(printf "  V3 speculation rollback: ~a failures\n" v3-failures)

;; V4: tensor produces correct types
(displayln "\nV4: tensor correctness (Track 2H)")
(define v4-failures 0)
(let ()
  (define result (type-tensor-core (expr-Pi 'mw (expr-Int) (expr-Bool)) (expr-Int)))
  (unless (equal? result (expr-Bool))
    (set! v4-failures (add1 v4-failures))
    (printf "  V4a FAIL: tensor(Int→Bool, Int) = ~a (expected Bool)\n" result))
  (define result2 (type-tensor-core (expr-Pi 'mw (expr-Int) (expr-Bool)) (expr-String)))
  (unless (type-bot? result2)
    (set! v4-failures (add1 v4-failures))
    (printf "  V4b FAIL: tensor(Int→Bool, String) = ~a (expected bot)\n" result2)))
(printf "  V4 tensor correctness: ~a failures\n" v4-failures)


;; ============================================================
;; SUMMARY
;; ============================================================

(displayln "\n\n=== SUMMARY ===\n")
(printf "Micro-benchmarks: M1-M9\n")
(printf "  Key: infer(literal) = ~a μs (M1b)\n" (~r m1b #:precision '(= 1)))
(printf "  Key: infer(app) = ~a μs (M1c)\n" (~r m1c #:precision '(= 1)))
(printf "  Key: check(lit:type) = ~a μs (M2a)\n" (~r m2a #:precision '(= 1)))
(printf "  Key: unify(equal) = ~a μs (M3a)\n" (~r m3a #:precision '(= 1)))
(printf "  Key: save-meta-state = ~a μs (M5a)\n" (~r m5a #:precision '(= 1)))
(printf "  Key: restore-meta-state! = ~a μs (M5b)\n" (~r m5b #:precision '(= 1)))
(printf "  Key: type-tensor-core = ~a μs (M6a)\n" (~r m6a #:precision '(= 1)))
(printf "  Key: elab-fresh-meta = ~a μs (M7a)\n" (~r m7a #:precision '(= 1)))
(printf "  Key: net-new-cell = ~a μs (M8a)\n" (~r m8a #:precision '(= 1)))
(printf "\nAdversarial: A1-A4\n")
(printf "  Key: depth-20 app chain = ~a ms (A1c)\n" (~r a1c #:precision '(= 1)))
(printf "  Key: 20 meta+solve = ~a ms (A2b)\n" (~r a2b #:precision '(= 1)))
(printf "  Key: 20 speculation cycles = ~a ms (A3b)\n" (~r a3b #:precision '(= 1)))
(printf "  Key: 100 elab-fresh-meta = ~a ms (A4b)\n" (~r a4b #:precision '(= 1)))
(printf "\nE2E: E1-E6\n")
(printf "  E1=~a ms  E2=~a ms  E3=~a ms\n"
        (~r e1 #:precision '(= 1))
        (~r e2 #:precision '(= 1))
        (~r e3 #:precision '(= 1)))
(printf "  E4=~a ms  E5=~a ms  E6=~a ms\n"
        (~r e4 #:precision '(= 1))
        (~r e5 #:precision '(= 1))
        (~r e6 #:precision '(= 1)))
(printf "\nValidation: V1-V4\n")
(printf "  V1 infer: ~a failures  V2 meta: ~a failures\n" v1-failures v2-failures)
(printf "  V3 speculation: ~a failures  V4 tensor: ~a failures\n" v3-failures v4-failures)

(define total-failures (+ v1-failures v2-failures v3-failures v4-failures))
(printf "\nTotal validation failures: ~a\n" total-failures)
(when (> total-failures 0)
  (printf "WARNING: Non-zero validation failures!\n"))
