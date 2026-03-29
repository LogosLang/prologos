#lang racket/base

;;; bench-sre-track2f.rkt — SRE Track 2F Pre-0 Benchmarks
;;;
;;; Measures current dispatch overhead to establish baselines before
;;; algebraic foundation refactoring.
;;;
;;; M1-M6: Micro-benchmarks (mechanism-level)
;;; A1-A4: Adversarial tests (path-level stress)

(require racket/format
         racket/list
         racket/set
         "../../sre-core.rkt"
         "../../ctor-registry.rkt"
         "../../propagator.rkt"
         "../../syntax.rkt"
         "../../type-lattice.rkt"
         "../../subtype-predicate.rkt"
         "../../unify.rkt"
         "../../elaborator-network.rkt"
         "../../driver.rkt")

;; ============================================================
;; Bench macro: warmup + measured iterations, report mean μs
;; ============================================================

(define-syntax-rule (bench label N-val body)
  (let ()
    (for ([_ (in-range 100)]) body)  ;; warmup
    (define N N-val)
    (collect-garbage)
    (define start (current-inexact-milliseconds))
    (for ([_ (in-range N)]) body)
    (define end (current-inexact-milliseconds))
    (define mean-us (* 1000.0 (/ (- end start) N)))
    (printf "~a: ~a μs/call (~a calls)\n" label (~r mean-us #:precision '(= 3)) N)))

;; ============================================================
;; Setup: get concrete descriptors and relations
;; ============================================================

(define pi-desc (lookup-ctor-desc 'Pi #:domain 'type))
(define pvec-desc (lookup-ctor-desc 'PVec #:domain 'type))
(define sigma-desc (lookup-ctor-desc 'Sigma #:domain 'type))
(define send-desc (lookup-ctor-desc 'sess-send #:domain 'session))

;; A pre-built hash table for comparison against closures
(define subtype-variance-table
  (hash '+ 'subtype  '- 'subtype-reverse  '= 'equality  'ø 'phantom))

(define duality-variance-table
  (hash 'd 'duality  't 'equality  '= 'equality  'ø 'phantom))

;; A property set for comparison against eq?
(define antitone-props (seteq 'antitone 'involutive))
(define monotone-props (seteq 'order-preserving))

(displayln "=== SRE Track 2F Pre-0 Benchmarks ===")
(displayln "")

;; ============================================================
;; M1: Sub-relation derivation — closure vs hash-ref
;; ============================================================

(displayln "--- M1: Sub-relation derivation ---")

;; Current: closure call
(bench "M1a closure (subtype, covariant)"
  100000
  ((sre-relation-sub-relation-fn sre-subtype)
   sre-subtype pi-desc 2 'type))  ;; codomain, covariant → subtype

(bench "M1b closure (subtype, contravariant)"
  100000
  ((sre-relation-sub-relation-fn sre-subtype)
   sre-subtype pi-desc 1 'type))  ;; domain, contravariant → subtype-reverse

(bench "M1c closure (subtype, invariant)"
  100000
  ((sre-relation-sub-relation-fn sre-subtype)
   sre-subtype pi-desc 0 'type))  ;; mult, invariant → equality

;; Proposed: hash-ref
(bench "M1d hash-ref (covariant)"
  100000
  (hash-ref subtype-variance-table
            (list-ref (ctor-desc-component-variances pi-desc) 2)))

(bench "M1e hash-ref (contravariant)"
  100000
  (hash-ref subtype-variance-table
            (list-ref (ctor-desc-component-variances pi-desc) 1)))

(bench "M1f hash-ref (invariant)"
  100000
  (hash-ref subtype-variance-table
            (list-ref (ctor-desc-component-variances pi-desc) 0)))

(newline)

;; ============================================================
;; M2: Propagator dispatch — case vs field access
;; ============================================================

(displayln "--- M2: Propagator dispatch ---")

;; Current: case dispatch (simulated — the actual case is inside a function)
(bench "M2a case dispatch (symbol)"
  100000
  (case (sre-relation-name sre-subtype)
    [(equality) 'eq]
    [(subtype subtype-reverse) 'sub]
    [(duality) 'dual]
    [(phantom) 'phantom]
    [else 'unknown]))

;; Proposed: struct field access (simulated — field would hold the constructor)
;; Using a hash as proxy for the struct-field lookup
(define kind-ctor-table
  (hash 'equality 'eq-ctor  'subtype 'sub-ctor  'subtype-reverse 'sub-ctor
        'duality 'dual-ctor  'phantom 'phantom-ctor))

(bench "M2b hash-ref dispatch"
  100000
  (hash-ref kind-ctor-table (sre-relation-name sre-subtype)))

;; Direct struct field access (the actual proposed mechanism)
;; Simulated with a vector-ref since we don't have the struct yet
(define kind-vec (vector 'eq-ctor 'sub-ctor 'sub-ctor 'dual-ctor 'phantom-ctor))
(bench "M2c vector-ref dispatch (struct field proxy)"
  100000
  (vector-ref kind-vec 1))

(newline)

;; ============================================================
;; M3: Property check — eq? vs set-member?
;; ============================================================

(displayln "--- M3: Property check ---")

(bench "M3a eq? (current — is duality?)"
  100000
  (eq? (sre-relation-name sre-duality) 'duality))

(bench "M3b eq? (current — is NOT duality?)"
  100000
  (eq? (sre-relation-name sre-subtype) 'duality))

(bench "M3c set-member? seteq (proposed — antitone?)"
  100000
  (set-member? antitone-props 'antitone))

(bench "M3d set-member? seteq (proposed — NOT antitone?)"
  100000
  (set-member? monotone-props 'antitone))

(newline)

;; ============================================================
;; M4: Merge registry — case vs hash-ref
;; ============================================================

(displayln "--- M4: Merge registry ---")

;; Current: case (simulated from the type-merge-registry pattern)
(bench "M4a case merge lookup"
  100000
  (case 'equality
    [(equality) 'type-merge]
    [(subtype subtype-reverse) 'subtype-merge]
    [else #f]))

(define merge-hash (hash 'equality 'type-merge 'subtype 'subtype-merge
                         'subtype-reverse 'subtype-merge 'duality 'session-merge))

(bench "M4b hash-ref merge lookup"
  100000
  (hash-ref merge-hash 'equality))

(newline)

;; ============================================================
;; M5: Full decomposition path (equality + subtype)
;; ============================================================

(displayln "--- M5: Full decomposition (type domain) ---")

;; PVec Int =? PVec Nat → decompose to sub-cells
(bench "M5a subtype? PVec Nat <: PVec Int"
  10000
  (subtype? (expr-PVec (expr-Nat)) (expr-PVec (expr-Int))))

;; Nested: PVec(PVec Nat) <: PVec(PVec Int)
(bench "M5b subtype? PVec(PVec Nat) <: PVec(PVec Int)"
  10000
  (subtype? (expr-PVec (expr-PVec (expr-Nat)))
            (expr-PVec (expr-PVec (expr-Int)))))

;; Pi with variance: (Int -> Nat) <: (Nat -> Int)
(bench "M5c subtype? Pi (Int->Nat) <: (Nat->Int)"
  10000
  (subtype? (expr-Pi 'mw (expr-Int) (expr-Nat))
            (expr-Pi 'mw (expr-Nat) (expr-Int))))

(newline)

;; ============================================================
;; M6: Duality decomposition path (session domain)
;; ============================================================

(displayln "--- M6: Session duality ---")

;; Simple duality: dual(Send Int End) = Recv Int End
(bench "M6a session decl Send(Int,End)"
  1000
  (process-string "ns t :no-prelude\nsession S\n  ! Int -> end"))

;; Nested duality
(bench "M6b session decl Send(Int,Send(Bool,End))"
  1000
  (process-string "ns t :no-prelude\nsession S\n  ! Int -> ! Bool -> end"))

(newline)

;; ============================================================
;; A1: Deep nesting — subtype stress
;; ============================================================

(displayln "--- A1: Deep nesting (subtype) ---")

(bench "A1a depth-1: PVec Nat <: PVec Int"
  10000
  (subtype? (expr-PVec (expr-Nat)) (expr-PVec (expr-Int))))

(bench "A1b depth-2: PVec(PVec) <: PVec(PVec)"
  10000
  (subtype? (expr-PVec (expr-PVec (expr-Nat)))
            (expr-PVec (expr-PVec (expr-Int)))))

(bench "A1c depth-3: PVec(PVec(PVec))"
  10000
  (subtype? (expr-PVec (expr-PVec (expr-PVec (expr-Nat))))
            (expr-PVec (expr-PVec (expr-PVec (expr-Int))))))

(bench "A1d depth-4: PVec(PVec(PVec(PVec)))"
  5000
  (subtype? (expr-PVec (expr-PVec (expr-PVec (expr-PVec (expr-Nat)))))
            (expr-PVec (expr-PVec (expr-PVec (expr-PVec (expr-Int)))))))

(newline)

;; ============================================================
;; A2: Wide decomposition — equality
;; ============================================================

(displayln "--- A2: Wide decomposition (Pi arity-3) ---")

(bench "A2a Pi equality (3 components)"
  10000
  (subtype? (expr-Pi 'mw (expr-Nat) (expr-Int))
            (expr-Pi 'mw (expr-Nat) (expr-Int))))

;; Nested Pi: (A -> B -> C) <: (A -> B -> C)
(bench "A2b nested Pi (6 components)"
  5000
  (subtype? (expr-Pi 'mw (expr-Nat) (expr-Pi 'mw (expr-Int) (expr-Nat)))
            (expr-Pi 'mw (expr-Nat) (expr-Pi 'mw (expr-Int) (expr-Nat)))))

(newline)

;; ============================================================
;; A3: Session duality — deep nesting
;; ============================================================

(displayln "--- A3: Deep session duality ---")

(bench "A3a 2-deep session"
  500
  (process-string "ns t :no-prelude\nsession S\n  ! Int -> ? Bool -> end"))

(bench "A3b 4-deep session"
  200
  (process-string "ns t :no-prelude\nsession S\n  ! Int -> ? Bool -> ! String -> ? Nat -> end"))

(newline)

;; ============================================================
;; A4: Mixed relations in one program
;; ============================================================

(displayln "--- A4: Mixed relations (e2e) ---")

(bench "A4a mixed: equality + subtype + session"
  100
  (process-string
   (string-append
    "ns t :no-prelude\n"
    "def x : Int := 42\n"                    ;; equality
    "session S\n  ! Int -> end\n"             ;; duality
    )))

(newline)
(displayln "=== Pre-0 baselines complete ===")
