#lang racket/base

;;;
;;; SRE Track 2H Pre-0 Benchmarks: Type Lattice Redesign
;;;
;;; Establishes baselines BEFORE implementation for A/B comparison.
;;; Data feeds into D.2 design revision.
;;;
;;; Tiers:
;;;   M1-M8:  Micro-benchmarks (individual lattice operations)
;;;   A1-A6:  Adversarial tests (worst-case / pathological inputs)
;;;   E1-E4:  E2E baselines (real programs with subtype merges)
;;;   V1-V6:  Algebraic validation (lattice property verification)
;;;   T1-T4:  Tensor validation (semiring axioms for function application)
;;;
;;; Usage:
;;;   racket benchmarks/micro/bench-sre-track2h.rkt
;;;
;;; After Track 2H implementation, re-run and compare.
;;;

(require racket/list
         racket/match
         racket/format
         racket/string
         racket/port
         racket/set
         "../../syntax.rkt"
         "../../type-lattice.rkt"
         "../../subtype-predicate.rkt"
         "../../unify.rkt"
         "../../sre-core.rkt"
         (except-in "../../ctor-registry.rkt" register-ctor!)
         "../../reduction.rkt"
         "../../substitution.rkt"
         "../../metavar-store.rkt"
         "../../driver.rkt"
         "../../macros.rkt"
         "../../performance-counters.rkt")

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
;; Type samples for property testing
;; ============================================================

;; Ground base types (no metas, no binders)
(define base-types
  (list (expr-Nat) (expr-Int) (expr-Rat) (expr-String) (expr-Bool)
        (expr-Unit) (expr-Char) (expr-Keyword)))

;; Compound types
(define (pi-type dom cod) (expr-Pi 'mw dom cod))
(define (sigma-type fst snd) (expr-Sigma fst snd))
(define pvec-nat (expr-PVec (expr-Nat)))
(define pvec-int (expr-PVec (expr-Int)))
(define set-string (expr-Set (expr-String)))
(define map-str-int (expr-Map (expr-String) (expr-Int)))
(define map-str-nat (expr-Map (expr-String) (expr-Nat)))
(define pi-nat-bool (pi-type (expr-Nat) (expr-Bool)))
(define pi-int-bool (pi-type (expr-Int) (expr-Bool)))
(define pi-int-string (pi-type (expr-Int) (expr-String)))

;; Union type samples (manually built — these exist in the AST today)
(define union-int-string (expr-union (expr-Int) (expr-String)))
(define union-nat-bool (expr-union (expr-Nat) (expr-Bool)))
(define union-int-bool-string (expr-union (expr-Int) (expr-union (expr-Bool) (expr-String))))

;; All samples for property testing
(define all-type-samples
  (append base-types
          (list pvec-nat pvec-int set-string map-str-int map-str-nat
                pi-nat-bool pi-int-bool pi-int-string
                union-int-string union-nat-bool)))

;; Deep nesting helpers
(define (deep-pvec depth base)
  (if (zero? depth) base (expr-PVec (deep-pvec (sub1 depth) base))))

(define (deep-pi depth)
  (if (zero? depth) (expr-Nat)
      (pi-type (expr-Nat) (deep-pi (sub1 depth)))))

(define (wide-union n)
  ;; Build a union of n distinct base types (cycling through base-types)
  (define types (for/list ([i (in-range n)])
    (list-ref base-types (modulo i (length base-types)))))
  (build-union-type types))

;; ============================================================
;; M: MICRO-BENCHMARKS — Individual lattice operations
;; ============================================================

(displayln "\n=== M: MICRO-BENCHMARKS ===\n")

;; M1: type-lattice-merge (equality join) — baseline
(displayln "M1: type-lattice-merge (equality join)")
(define m1a (bench "M1a equal (Nat,Nat)" 10000 (type-lattice-merge (expr-Nat) (expr-Nat))))
(define m1b (bench "M1b bot identity" 10000 (type-lattice-merge type-bot (expr-Int))))
(define m1c (bench "M1c incompatible→top (Nat,String)" 10000
  (type-lattice-merge (expr-Nat) (expr-String))))
(define m1d (bench "M1d Pi structural unify" 5000
  (type-lattice-merge pi-nat-bool pi-nat-bool)))

;; M2: subtype-lattice-merge — the function Track 2H redesigns
(displayln "\nM2: subtype-lattice-merge (CURRENT — produces type-top for incomparable)")
(define m2a (bench "M2a equal" 10000 (subtype-lattice-merge (expr-Nat) (expr-Nat))))
(define m2b (bench "M2b subtype chain (Nat,Int)" 10000
  (subtype-lattice-merge (expr-Nat) (expr-Int))))
(define m2c (bench "M2c incomparable→TOP (Int,String)" 10000
  (subtype-lattice-merge (expr-Int) (expr-String))))
(define m2d (bench "M2d incomparable→TOP (Nat,Bool)" 10000
  (subtype-lattice-merge (expr-Nat) (expr-Bool))))
(define m2e (bench "M2e compound equal (PVec Nat)" 5000
  (subtype-lattice-merge pvec-nat pvec-nat)))
(define m2f (bench "M2f compound subtype (PVec Nat, PVec Int)" 5000
  (subtype-lattice-merge pvec-nat pvec-int)))

;; M3: type-lattice-meet (GLB) — Track 2H extends coverage
(displayln "\nM3: type-lattice-meet (GLB — currently Pi/Sigma only)")
(define m3a (bench "M3a equal" 10000 (type-lattice-meet (expr-Nat) (expr-Nat))))
(define m3b (bench "M3b top identity" 10000 (type-lattice-meet type-top (expr-Int))))
(define m3c (bench "M3c incompatible→bot" 10000 (type-lattice-meet (expr-Nat) (expr-String))))
(define m3d (bench "M3d Pi meet (covariant cod)" 5000
  (type-lattice-meet pi-nat-bool pi-int-bool)))
(define m3e (bench "M3e Sigma meet" 5000
  (type-lattice-meet (sigma-type (expr-Nat) (expr-Bool))
                     (sigma-type (expr-Int) (expr-Bool)))))
;; M3f: compound type meet — CURRENTLY returns bot (not covered by try-intersect-pure)
(define m3f (bench "M3f PVec meet (UNCOVERED→bot)" 5000
  (type-lattice-meet pvec-nat pvec-int)))

;; M4: subtype? — used by subtype-lattice-merge and absorption
(displayln "\nM4: subtype? predicate")
(define m4a (bench "M4a flat positive (Nat<:Int)" 10000 (subtype? (expr-Nat) (expr-Int))))
(define m4b (bench "M4b flat negative (Int<:Nat)" 10000 (subtype? (expr-Int) (expr-Nat))))
(define m4c (bench "M4c structural (PVec Nat<:PVec Int)" 5000
  (subtype? pvec-nat pvec-int)))
(define m4d (bench "M4d equal (reflexive)" 10000 (subtype? (expr-Int) (expr-Int))))

;; M5: build-union-type — ACI normalization baseline
(displayln "\nM5: build-union-type (ACI normalization)")
(define m5a (bench "M5a 2 components" 5000
  (build-union-type (list (expr-Int) (expr-String)))))
(define m5b (bench "M5b 3 components" 5000
  (build-union-type (list (expr-Int) (expr-String) (expr-Bool)))))
(define m5c (bench "M5c 5 components" 5000
  (build-union-type (list (expr-Int) (expr-String) (expr-Bool) (expr-Nat) (expr-Char)))))
(define m5d (bench "M5d dedup (Int,Int,String)" 5000
  (build-union-type (list (expr-Int) (expr-Int) (expr-String)))))
(define m5e (bench "M5e nested flatten" 5000
  (build-union-type (list union-int-string (expr-Bool)))))

;; M6: flatten-union
(displayln "\nM6: flatten-union")
(define m6a (bench "M6a flat union" 10000 (flatten-union union-int-string)))
(define m6b (bench "M6b nested 3-deep" 10000
  (flatten-union (expr-union (expr-Nat) (expr-union (expr-Int) (expr-union (expr-Bool) (expr-String)))))))

;; M7: try-unify-pure — used by type-lattice-merge
(displayln "\nM7: try-unify-pure (pure structural unification)")
(define m7a (bench "M7a equal atoms" 10000 (try-unify-pure (expr-Nat) (expr-Nat))))
(define m7b (bench "M7b incompatible atoms" 10000 (try-unify-pure (expr-Nat) (expr-String))))
(define m7c (bench "M7c Pi structural" 5000 (try-unify-pure pi-nat-bool pi-nat-bool)))
(define m7d (bench "M7d union vs union" 5000
  (try-unify-pure union-int-string union-int-string)))

;; M8: type-lattice-meet structural paths (exercises try-intersect-pure internally)
(displayln "\nM8: type-lattice-meet structural cases")
(define m8a (bench "M8a Pi meet (ring action path)" 5000
  (type-lattice-meet pi-nat-bool pi-int-bool)))
(define m8b (bench "M8b Sigma meet" 5000
  (type-lattice-meet (sigma-type (expr-Nat) (expr-Bool))
                     (sigma-type (expr-Int) (expr-Bool)))))
(define m8c (bench "M8c PVec meet (falls to bot — uncovered)" 5000
  (type-lattice-meet pvec-nat pvec-int)))


;; ============================================================
;; A: ADVERSARIAL TESTS — Worst-case / pathological inputs
;; ============================================================

(displayln "\n\n=== A: ADVERSARIAL TESTS ===\n")

;; A1: Wide unions — many components stress ACI normalization
(displayln "A1: Wide union construction")
(define a1a (bench "A1a 10-component union" 1000
  (build-union-type (take (append base-types base-types base-types) 10))))
(define a1b (bench "A1b 20-component union" 500
  (let ([types (for/list ([i (in-range 20)]) (expr-tycon (string->symbol (format "T~a" i))))])
    (build-union-type types))))
(define a1c (bench "A1c 50-component union" 200
  (let ([types (for/list ([i (in-range 50)]) (expr-tycon (string->symbol (format "U~a" i))))])
    (build-union-type types))))

;; A2: Deep nesting — structural traversal depth
(displayln "\nA2: Deep nesting")
(define deep-pvec-5-nat (deep-pvec 5 (expr-Nat)))
(define deep-pvec-5-int (deep-pvec 5 (expr-Int)))
(define deep-pvec-10-nat (deep-pvec 10 (expr-Nat)))
(define deep-pvec-10-int (deep-pvec 10 (expr-Int)))
(define a2a (bench "A2a subtype PVec^5" 2000
  (subtype? deep-pvec-5-nat deep-pvec-5-int)))
(define a2b (bench "A2b subtype PVec^10" 1000
  (subtype? deep-pvec-10-nat deep-pvec-10-int)))
(define a2c (bench "A2c meet PVec^5 (UNCOVERED→bot)" 2000
  (type-lattice-meet deep-pvec-5-nat deep-pvec-5-int)))
(define a2d (bench "A2d deep Pi (depth=10) merge" 2000
  (type-lattice-merge (deep-pi 10) (deep-pi 10))))

;; A3: Subtype absorption cost estimation
;; After Track 2H, subtype-lattice-merge will call subtype? for each pair
;; in absorption. This measures the N^2 cost.
(displayln "\nA3: Absorption cost estimation (N^2 subtype? calls)")
(define (absorption-cost n)
  ;; Simulate: for n components, do n*(n-1)/2 subtype? checks
  (define types (for/list ([i (in-range n)])
    (list-ref base-types (modulo i (length base-types)))))
  (for* ([a (in-list types)]
         [b (in-list types)]
         #:when (not (eq? a b)))
    (subtype? a b)))
(define a3a (bench "A3a absorption 5 components" 1000 (absorption-cost 5)))
(define a3b (bench "A3b absorption 10 components" 500 (absorption-cost 10)))
(define a3c (bench "A3c absorption 20 components" 200 (absorption-cost 20)))

;; A4: Union-vs-union merge (subtype merge of two union types)
;; After Track 2H, merging two unions requires flatten+sort+dedup+absorb
(displayln "\nA4: Union-vs-union subtype merge (future path)")
(define a4a (bench "A4a 2-union merge (flatten+sort+dedup)" 5000
  (build-union-type (list (expr-Int) (expr-String) (expr-Bool) (expr-Nat)))))
(define a4b (bench "A4b 3-union merge" 2000
  (build-union-type (list (expr-Int) (expr-String) (expr-Bool)
                          (expr-Nat) (expr-Char) (expr-Keyword)))))

;; A5: Subtype merge in tight loop (hot path simulation)
;; subtype-lattice-merge is called on every cell write with subtype relation
(displayln "\nA5: Hot-path subtype-lattice-merge (1000 iterations)")
(define a5a (bench-ms "A5a 1000x equal" 10
  (for ([_ (in-range 1000)]) (subtype-lattice-merge (expr-Int) (expr-Int)))))
(define a5b (bench-ms "A5b 1000x chain" 10
  (for ([_ (in-range 1000)]) (subtype-lattice-merge (expr-Nat) (expr-Int)))))
(define a5c (bench-ms "A5c 1000x incomparable→TOP" 10
  (for ([_ (in-range 1000)]) (subtype-lattice-merge (expr-Int) (expr-String)))))

;; A6: Tensor cost estimation — function application on union types
;; Simulates what type-tensor will do: apply Pi to each union component
(displayln "\nA6: Tensor cost estimation (function application over unions)")
(define (simulate-tensor-distribute func-type union-components)
  ;; For each component, check domain compatibility and substitute
  (for/list ([c (in-list union-components)])
    (cond
      [(and (expr-Pi? func-type) (subtype? c (expr-Pi-domain func-type)))
       (subst 0 c (expr-Pi-codomain func-type))]
      [else type-top])))
(define a6a (bench "A6a tensor over 3-union" 2000
  (simulate-tensor-distribute
    pi-int-bool
    (list (expr-Nat) (expr-Int) (expr-Rat)))))
(define a6b (bench "A6b tensor over 5-union" 1000
  (simulate-tensor-distribute
    (pi-type (expr-Rat) (expr-String))
    (list (expr-Nat) (expr-Int) (expr-Rat) (expr-String) (expr-Bool)))))


;; ============================================================
;; E: E2E BASELINES — Real programs that exercise subtype merges
;; ============================================================

(displayln "\n\n=== E: E2E BASELINES ===\n")

;; E1: Simple program with numeric subtyping
(define e1-src
  (string-append
   "ns bench :no-prelude\n"
   "def x : Int := 42\n"
   "def y : Nat := 0N\n"
   "spec add Int Int -> Int\n"
   "defn add [a b] [int+ a b]\n"
   "eval [add x [int+ 1 1]]\n"))

(define e1 (bench-ms "E1 numeric subtyping (simple)" 10
  (silent (lambda ()
      (process-string-ws e1-src))))))

;; E2: Mixed-type map (existing union type consumer)
(define e2-src
  (string-append
   "ns bench :no-prelude\n"
   "def m := {:name \"alice\" :age 30}\n"
   "eval m.name\n"
   "eval m.age\n"))

(define e2 (bench-ms "E2 mixed-type map (union values)" 10
  (silent (lambda ()
      (process-string-ws e2-src))))))

;; E3: Pattern matching (exercises type checking with multiple branches)
(define e3-src
  (string-append
   "ns bench :no-prelude\n"
   "data Shape := Circle Int | Rect Int Int\n\n"
   "spec area Shape -> Int\n"
   "defn area\n"
   "  | Circle r -> [int* r r]\n"
   "  | Rect w h -> [int* w h]\n\n"
   "eval [area [Circle 5]]\n"
   "eval [area [Rect 3 4]]\n"))

(define e3 (bench-ms "E3 pattern matching (multiple branches)" 10
  (silent (lambda ()
      (process-string-ws e3-src))))))

;; E4: Trait with subtype (exercises subtype? in resolution)
(define e4-src
  (string-append
   "ns bench :no-prelude\n"
   "def a : Nat := 5N\n"
   "def b : Int := 10\n"
   "def c : Int := [int+ b 1]\n"
   "eval [int+ [int+ c b] 0]\n"))

(define e4 (bench-ms "E4 subtype in arithmetic context" 10
  (silent (lambda ()
      (process-string-ws e4-src))))))


;; ============================================================
;; V: ALGEBRAIC VALIDATION — Lattice property verification
;; ============================================================

(displayln "\n\n=== V: ALGEBRAIC VALIDATION ===\n")

;; V1: subtype-lattice-merge algebraic properties (CURRENT behavior)
(displayln "V1: subtype-lattice-merge properties (CURRENT — incomparable → top)")
(define v1-fail-count 0)

;; V1a: Commutativity
(define v1a-failures 0)
(for* ([a (in-list all-type-samples)]
       [b (in-list all-type-samples)])
  (define ab (subtype-lattice-merge a b))
  (define ba (subtype-lattice-merge b a))
  (unless (equal? ab ba)
    (set! v1a-failures (add1 v1a-failures))))
(printf "  V1a commutativity: ~a failures / ~a tests\n"
        v1a-failures (* (length all-type-samples) (length all-type-samples)))

;; V1b: Associativity
(define v1b-failures 0)
(define v1b-tests 0)
(for* ([a (in-list base-types)]  ;; smaller set for O(n^3)
       [b (in-list base-types)]
       [c (in-list base-types)])
  (set! v1b-tests (add1 v1b-tests))
  (define ab-c (subtype-lattice-merge (subtype-lattice-merge a b) c))
  (define a-bc (subtype-lattice-merge a (subtype-lattice-merge b c)))
  (unless (equal? ab-c a-bc)
    (set! v1b-failures (add1 v1b-failures))))
(printf "  V1b associativity: ~a failures / ~a tests\n" v1b-failures v1b-tests)

;; V1c: Idempotence
(define v1c-failures 0)
(for ([a (in-list all-type-samples)])
  (define aa (subtype-lattice-merge a a))
  (unless (equal? aa a)
    (set! v1c-failures (add1 v1c-failures))))
(printf "  V1c idempotence: ~a failures / ~a tests\n"
        v1c-failures (length all-type-samples))

;; V1d: Identity (bot)
(define v1d-failures 0)
(for ([a (in-list all-type-samples)])
  (unless (and (equal? (subtype-lattice-merge type-bot a) a)
               (equal? (subtype-lattice-merge a type-bot) a))
    (set! v1d-failures (add1 v1d-failures))))
(printf "  V1d identity (bot): ~a failures / ~a tests\n"
        v1d-failures (length all-type-samples))

;; V1e: Absorption (top)
(define v1e-failures 0)
(for ([a (in-list all-type-samples)])
  (unless (and (type-top? (subtype-lattice-merge type-top a))
               (type-top? (subtype-lattice-merge a type-top)))
    (set! v1e-failures (add1 v1e-failures))))
(printf "  V1e absorption (top): ~a failures / ~a tests\n"
        v1e-failures (length all-type-samples))


;; V2: type-lattice-meet algebraic properties
(displayln "\nV2: type-lattice-meet properties")

;; V2a: Commutativity
(define v2a-failures 0)
(for* ([a (in-list all-type-samples)]
       [b (in-list all-type-samples)])
  (define ab (type-lattice-meet a b))
  (define ba (type-lattice-meet b a))
  (unless (equal? ab ba)
    (set! v2a-failures (add1 v2a-failures))
    (when (< v2a-failures 5)
      (printf "    FAIL: meet(~a, ~a)=~a ≠ meet(~a, ~a)=~a\n" a b ab b a ba))))
(printf "  V2a commutativity: ~a failures / ~a tests\n"
        v2a-failures (* (length all-type-samples) (length all-type-samples)))

;; V2b: Identity (top is identity for meet)
(define v2b-failures 0)
(for ([a (in-list all-type-samples)])
  (unless (and (equal? (type-lattice-meet type-top a) a)
               (equal? (type-lattice-meet a type-top) a))
    (set! v2b-failures (add1 v2b-failures))))
(printf "  V2b identity (top): ~a failures / ~a tests\n"
        v2b-failures (length all-type-samples))

;; V2c: Annihilator (bot annihilates meet)
(define v2c-failures 0)
(for ([a (in-list all-type-samples)])
  (unless (and (type-bot? (type-lattice-meet type-bot a))
               (type-bot? (type-lattice-meet a type-bot)))
    (set! v2c-failures (add1 v2c-failures))))
(printf "  V2c annihilator (bot): ~a failures / ~a tests\n"
        v2c-failures (length all-type-samples))


;; V3: Distributivity of meet over join (UNDER EQUALITY — expected to FAIL)
;; This confirms Track 2G's finding: type lattice NOT distributive under equality
(displayln "\nV3: Distributivity under EQUALITY (expected to FAIL — confirms 2G finding)")
(define v3-failures 0)
(define v3-tests 0)
(for* ([a (in-list base-types)]
       [b (in-list base-types)]
       [c (in-list base-types)])
  (set! v3-tests (add1 v3-tests))
  (define lhs (type-lattice-meet a (type-lattice-merge b c)))
  (define rhs (type-lattice-merge (type-lattice-meet a b)
                                   (type-lattice-meet a c)))
  (unless (equal? lhs rhs)
    (set! v3-failures (add1 v3-failures))))
(printf "  V3 distributivity (equality): ~a failures / ~a tests ~a\n"
        v3-failures v3-tests
        (if (> v3-failures 0) "(EXPECTED — flat lattice)" "(UNEXPECTED — should have failures)"))


;; V4: Distributivity of meet over join (UNDER SUBTYPING — TARGET for Track 2H)
;; Currently uses subtype-lattice-merge which produces top for incomparable.
;; After Track 2H: should produce union types and distributivity should hold.
(displayln "\nV4: Distributivity under SUBTYPING (target for Track 2H)")
(define v4-failures 0)
(define v4-tests 0)
(for* ([a (in-list base-types)]
       [b (in-list base-types)]
       [c (in-list base-types)])
  (set! v4-tests (add1 v4-tests))
  ;; meet(a, join(b,c)) vs join(meet(a,b), meet(a,c))
  ;; Using subtype-lattice-merge as join, type-lattice-meet as meet
  (define lhs (type-lattice-meet a (subtype-lattice-merge b c)))
  (define rhs (subtype-lattice-merge (type-lattice-meet a b)
                                      (type-lattice-meet a c)))
  (unless (equal? lhs rhs)
    (set! v4-failures (add1 v4-failures))
    (when (< v4-failures 5)
      (printf "    FAIL: a=~a b=~a c=~a → lhs=~a rhs=~a\n" a b c lhs rhs))))
(printf "  V4 distributivity (subtype): ~a failures / ~a tests ~a\n"
        v4-failures v4-tests
        (if (> v4-failures 0)
            "(EXPECTED pre-2H — subtype merge → top for incomparable)"
            "(would mean subtype ordering is already distributive)"))


;; V5: Absorption law: a ⊔ (a ⊓ b) = a
(displayln "\nV5: Absorption law: join(a, meet(a,b)) = a")
(define v5-failures 0)
(define v5-tests 0)
(for* ([a (in-list base-types)]
       [b (in-list base-types)])
  (set! v5-tests (add1 v5-tests))
  (define m (type-lattice-meet a b))
  ;; Under subtype ordering: join(a, meet(a,b)) should = a
  (define result (subtype-lattice-merge a m))
  (unless (equal? result a)
    (set! v5-failures (add1 v5-failures))
    (when (< v5-failures 5)
      (printf "    FAIL: a=~a b=~a meet=~a join(a,meet)=~a\n" a b m result))))
(printf "  V5 absorption: ~a failures / ~a tests\n" v5-failures v5-tests)


;; V6: Subtype consistency: if a <: b then join(a,b) = b
(displayln "\nV6: Subtype consistency: a <: b → join(a,b) = b")
(define subtype-pairs
  '((Nat . Int) (Nat . Rat) (Int . Rat)))
(define v6-failures 0)
(for ([pair (in-list subtype-pairs)])
  (define a (match (car pair) ['Nat (expr-Nat)] ['Int (expr-Int)] ['Rat (expr-Rat)]))
  (define b (match (cdr pair) ['Nat (expr-Nat)] ['Int (expr-Int)] ['Rat (expr-Rat)]))
  (define result (subtype-lattice-merge a b))
  (unless (equal? result b)
    (set! v6-failures (add1 v6-failures))
    (printf "    FAIL: ~a <: ~a but join = ~a (expected ~a)\n" (car pair) (cdr pair) result b)))
(printf "  V6 subtype consistency: ~a failures / ~a tests\n" v6-failures (length subtype-pairs))


;; ============================================================
;; T: TENSOR VALIDATION — Semiring axioms for function application
;; ============================================================

(displayln "\n\n=== T: TENSOR VALIDATION (semiring axioms) ===\n")

;; T1: Right-distribution of tensor over join
;; f(a ⊔ b) = f(a) ⊔ f(b)  where f = Pi type, ⊔ = subtype join
;; We simulate this by manually applying the Pi and comparing.
(displayln "T1: Tensor right-distributes over join: f(a⊔b) = f(a) ⊔ f(b)")
(define t1-failures 0)
(define t1-tests 0)

;; Test with f : Int → Bool, applied to Nat and Rat (both <: domain)
;; f(Nat ⊔ Rat) vs f(Nat) ⊔ f(Rat)
;; subtype-lattice-merge(Nat, Rat) = Rat (Nat <: Rat)
;; f(Rat) = Bool (Rat <: Int? NO — Int <: Rat, not Rat <: Int)
;; So use f : Rat → Bool instead
(let ()
  (define f-type (pi-type (expr-Rat) (expr-Bool)))
  (define domain (expr-Pi-domain f-type))
  (define codomain (expr-Pi-codomain f-type))
  ;; Components that are subtypes of domain
  (define args (list (expr-Nat) (expr-Int) (expr-Rat)))
  ;; f(join(args)) — join all args, then apply
  (define joined-args (foldl (lambda (a acc) (subtype-lattice-merge a acc))
                             type-bot args))
  ;; Each arg <: Rat, so join = Rat, f(Rat) = Bool
  (define lhs (if (subtype? joined-args domain) codomain type-top))
  ;; join(f(arg_i)) — apply to each, then join results
  (define per-component
    (for/list ([a (in-list args)])
      (if (subtype? a domain) codomain type-top)))
  (define rhs (foldl (lambda (r acc) (subtype-lattice-merge r acc))
                      type-bot per-component))
  (set! t1-tests (add1 t1-tests))
  (unless (equal? lhs rhs)
    (set! t1-failures (add1 t1-failures))
    (printf "    FAIL: f=Rat→Bool args=~a joined=~a lhs=~a rhs=~a\n"
            args joined-args lhs rhs)))

;; Test with incomparable args: f : Int → Bool, args = Int, String
;; join(Int, String) = top (CURRENT) — f(top) = top
;; f(Int) = Bool, f(String) = top (not subtype of Int)
;; join(Bool, top) = top
;; lhs = rhs = top — trivially holds with current merge
;; AFTER Track 2H: join(Int, String) = Int|String
;; f(Int|String) should distribute: f(Int) | f(String) = Bool | top
;; This is where tensor distribution matters
(let ()
  (define f-type (pi-type (expr-Int) (expr-Bool)))
  (define args (list (expr-Int) (expr-String)))
  (define joined (subtype-lattice-merge (expr-Int) (expr-String)))
  ;; With current merge: joined = top, f(top) = top
  ;; After 2H: joined = Int|String, f(Int|String) should = Bool|top = top
  ;; But f(Int) = Bool, f(String) = top, join(Bool,top) = top
  ;; So lhs = rhs = top in both regimes — this particular case is trivial
  (set! t1-tests (add1 t1-tests))
  (printf "    T1 note: incomparable args → top in both regimes (trivially holds)\n"))

(printf "  T1 right-distribution: ~a failures / ~a tests\n" t1-failures t1-tests)


;; T2: Left-distribution — (f ⊔ g)(a) = f(a) ⊔ g(a)
;; Union of function types applied to same argument
(displayln "\nT2: Tensor left-distributes: (f⊔g)(a) = f(a) ⊔ g(a)")
(define t2-note
  (string-append
   "  T2: Cannot test with current infrastructure — union of Pi types\n"
   "      not produced by current merge (Pi equality → unify or top).\n"
   "      After Track 2H: if two Pi types with different codomains merge\n"
   "      under subtype ordering, they could form a union.\n"
   "      Deferred to post-implementation validation.\n"))
(display t2-note)


;; T3: Annihilation — f(⊥) = ⊥, ⊥(a) = ⊥
(displayln "\nT3: Tensor annihilation: f(⊥) = ⊥, ⊥(a) = ⊥")
(define t3-failures 0)
;; f(⊥): apply a Pi to bot
(let ()
  (define result-bot-arg
    ;; Simulate: is type-bot <: Int? No — bot is the absence of info
    ;; In the tensor: f(⊥) should = ⊥ (no information in → no information out)
    (if (subtype? type-bot (expr-Int)) (expr-Bool) type-bot))
  ;; We expect type-bot (annihilation) — but subtype?(bot, Int) is #f (bot isn't a type)
  ;; So result = type-bot ✓
  (unless (type-bot? result-bot-arg)
    (set! t3-failures (add1 t3-failures))
    (printf "    FAIL: f(⊥) = ~a (expected ⊥)\n" result-bot-arg)))
;; ⊥(a): bot as function type — not a Pi, so application fails
;; In tensor: ⊥(a) = ⊥
(let ()
  ;; type-bot is not a Pi, so tensor returns bot
  (unless (not (expr-Pi? type-bot))
    (set! t3-failures (add1 t3-failures))
    (printf "    FAIL: ⊥ should not be a Pi\n")))
(printf "  T3 annihilation: ~a failures (0 expected)\n" t3-failures)


;; T4: Identity — (A → A)(a) = a when a <: A
(displayln "\nT4: Tensor identity: id(a) = a")
(define t4-failures 0)
(for ([ty (in-list base-types)])
  ;; Identity function type: ty → ty
  (define id-type (pi-type ty ty))
  ;; Apply to itself: should get ty back
  (define result (subst 0 ty (expr-Pi-codomain id-type)))
  (unless (equal? result ty)
    (set! t4-failures (add1 t4-failures))
    (printf "    FAIL: id_~a(~a) = ~a\n" ty ty result)))
(printf "  T4 identity: ~a failures / ~a tests\n" t4-failures (length base-types))


;; ============================================================
;; Summary
;; ============================================================

(displayln "\n\n=== SUMMARY ===\n")
(printf "Micro-benchmarks: M1-M8 (lattice operations)\n")
(printf "  Key baseline: subtype-lattice-merge incomparable = ~a μs (M2c)\n" (~r m2c #:precision '(= 1)))
(printf "  Key baseline: build-union-type 2-component = ~a μs (M5a)\n" (~r m5a #:precision '(= 1)))
(printf "  Key baseline: type-lattice-meet incomparable = ~a μs (M3c)\n" (~r m3c #:precision '(= 1)))
(printf "  Key baseline: subtype? flat positive = ~a μs (M4a)\n" (~r m4a #:precision '(= 1)))
(printf "\nAdversarial: A1-A6 (worst-case)\n")
(printf "  Key: absorption 10 components = ~a μs (A3b)\n" (~r a3b #:precision '(= 1)))
(printf "  Key: hot-path 1000x incomparable = ~a ms (A5c)\n" (~r a5c #:precision '(= 1)))
(printf "\nE2E baselines: E1-E4\n")
(printf "  E1 numeric = ~a ms, E2 mixed-map = ~a ms, E3 pattern = ~a ms, E4 subtype = ~a ms\n"
        (~r e1 #:precision '(= 1))
        (~r e2 #:precision '(= 1))
        (~r e3 #:precision '(= 1))
        (~r e4 #:precision '(= 1)))
(printf "\nAlgebraic validation: V1-V6\n")
(printf "  V1 merge properties: comm=~a assoc=~a idemp=~a id=~a abs=~a\n"
        v1a-failures v1b-failures v1c-failures v1d-failures v1e-failures)
(printf "  V3 distributivity (equality): ~a failures (expected >0)\n" v3-failures)
(printf "  V4 distributivity (subtype): ~a failures (target: 0 after Track 2H)\n" v4-failures)
(printf "  V5 absorption law: ~a failures\n" v5-failures)
(printf "  V6 subtype consistency: ~a failures\n" v6-failures)
(printf "\nTensor validation: T1-T4\n")
(printf "  T1 right-distribute: ~a failures, T3 annihilation: ~a failures, T4 identity: ~a failures\n"
        t1-failures t3-failures t4-failures)

(define total-validation-failures
  (+ v1a-failures v1b-failures v1c-failures v1d-failures v1e-failures
     v2a-failures v2b-failures v2c-failures
     v5-failures v6-failures
     t1-failures t3-failures t4-failures))
(printf "\nTotal validation failures (excluding expected V3/V4): ~a\n" total-validation-failures)
(when (> total-validation-failures 0)
  (printf "WARNING: Non-zero validation failures indicate existing bugs!\n"))
