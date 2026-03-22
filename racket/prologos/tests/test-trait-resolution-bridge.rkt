#lang racket/base

;;;
;;; Track 8 Phase C0: Bridge Convergence Prototype
;;;
;;; Validates that the cross-domain bridge pattern converges for nested
;;; trait resolution before committing to C1-C6. Tests depth 1/2/3
;;; chain resolution and measures propagator firing count.
;;;
;;; This is a Racket-level test (no Prologos syntax), using the same
;;; domain simulation pattern as test-cross-domain-propagator.rkt.
;;;

(require rackunit
         racket/list
         "../propagator.rkt"
         "../champ.rkt"
         "../performance-counters.rkt")

;; ========================================
;; Domain: Simulated Type and Dict Lattices
;; ========================================

;; Type domain: symbols represent types, #f = bot (unsolved), 'top = contradiction
;; Merge: first non-bot wins (monotone — bot < concrete < top)
(define (type-merge old new)
  (cond
    [(eq? old #f) new]
    [(eq? new #f) old]
    [(equal? old new) old]
    [else 'top]))  ;; contradiction

(define (type-contradicts? val) (eq? val 'top))

;; Dict domain: symbols represent resolved dicts, #f = unresolved
;; Same merge semantics as type
(define dict-merge type-merge)
(define dict-contradicts? type-contradicts?)

;; ========================================
;; Simulated Impl Registry
;; ========================================

;; Maps (trait-name . constructor-name) -> dict-symbol
;; Simulates: impl Eq Nat -> 'eq-nat-dict, impl Indexed PVec -> 'indexed-pvec-dict, etc.
(define *impl-registry*
  (make-hash
   '(((Eq . Nat)         . eq-nat-dict)
     ((Eq . Bool)        . eq-bool-dict)
     ((Indexed . PVec)   . indexed-pvec-dict)
     ((Seq . List)       . seq-list-dict)
     ((Seq . PVec)       . seq-pvec-dict)
     ((Foldable . List)  . foldable-list-dict)
     ((Foldable . PVec)  . foldable-pvec-dict)
     ((Functor . List)   . functor-list-dict)
     ((Functor . PVec)   . functor-pvec-dict)
     ;; Depth-3: Iterable depends on Seq, which depends on Foldable
     ((Iterable . List)  . iterable-list-dict)
     ((Iterable . PVec)  . iterable-pvec-dict))))

(define (lookup-impl trait-name constructor-name)
  (hash-ref *impl-registry* (cons trait-name constructor-name) #f))

;; Extract constructor from a compound type symbol
;; 'PVec-Int -> 'PVec, 'List-Nat -> 'List, 'Nat -> 'Nat
(define (extract-constructor type-val)
  (cond
    [(eq? type-val #f) #f]
    [(eq? type-val 'top) #f]
    [else
     (define s (symbol->string type-val))
     (define dash (regexp-match-positions #rx"-" s))
     (if dash
         (string->symbol (substring s 0 (caar dash)))
         type-val)]))

;; ========================================
;; Bridge Alpha Function Factory
;; ========================================

;; Creates a trait-resolve-alpha: type-val -> dict-val
;; This is the function that Part C will use in production.
(define (make-trait-resolve-alpha trait-name)
  (lambda (type-val)
    (cond
      [(eq? type-val #f) #f]       ;; type not yet solved → dict unresolved
      [(eq? type-val 'top) 'top]   ;; type contradiction → dict contradiction
      [else
       (define ctor (extract-constructor type-val))
       (define impl (lookup-impl trait-name ctor))
       (or impl #f)])))            ;; resolved dict or still unresolved

;; Gamma: no reverse flow (unidirectional bridge)
(define (no-reverse-gamma _) #f)

;; ========================================
;; Bridge Constructor (following session-type-bridge pattern)
;; ========================================

(define (add-trait-resolution-bridge net type-cell trait-name)
  ;; Create dict cell
  (define-values (net1 dict-cell)
    (net-new-cell net #f dict-merge dict-contradicts?))
  ;; Wire: type cell → dict cell via cross-domain bridge
  (define-values (net2 _pid-alpha _pid-gamma)
    (net-add-cross-domain-propagator net1 type-cell dict-cell
      (make-trait-resolve-alpha trait-name)
      no-reverse-gamma))
  (values net2 dict-cell))

;; ========================================
;; Fuel Measurement Helper
;; ========================================

(define (firings-used net-before net-after)
  (- (prop-network-fuel net-before)
     (prop-network-fuel net-after)))

;; ========================================
;; §A — Depth 1: Single Trait Resolution
;; ========================================

(test-case "C0-A1: depth-1 — Eq Nat resolves immediately"
  (define net0 (make-prop-network 200))
  ;; Type cell for ?C (unsolved)
  (define-values (net1 type-cell)
    (net-new-cell net0 #f type-merge type-contradicts?))
  ;; Wire Eq bridge: watches type-cell, writes to dict-cell
  (define-values (net2 dict-cell)
    (add-trait-resolution-bridge net1 type-cell 'Eq))
  ;; Solve ?C = Nat
  (define net3 (net-cell-write net2 type-cell 'Nat))
  (define result (run-to-quiescence net3))
  ;; Dict should be resolved
  (check-equal? (net-cell-read result dict-cell) 'eq-nat-dict)
  ;; Fuel: should converge quickly (< 10 firings)
  (define used (firings-used net3 result))
  (check-true (< used 10)
    (format "depth-1 used ~a firings (threshold: 10)" used)))

(test-case "C0-A2: depth-1 — Indexed PVec-Int resolves via constructor extraction"
  (define net0 (make-prop-network 200))
  (define-values (net1 type-cell)
    (net-new-cell net0 #f type-merge type-contradicts?))
  (define-values (net2 dict-cell)
    (add-trait-resolution-bridge net1 type-cell 'Indexed))
  ;; Solve ?C = PVec-Int (compound type → constructor PVec)
  (define net3 (net-cell-write net2 type-cell 'PVec-Int))
  (define result (run-to-quiescence net3))
  (check-equal? (net-cell-read result dict-cell) 'indexed-pvec-dict)
  (check-true (< (firings-used net3 result) 10)))

(test-case "C0-A3: depth-1 — unsolved type leaves dict unresolved"
  (define net0 (make-prop-network 200))
  (define-values (net1 type-cell)
    (net-new-cell net0 #f type-merge type-contradicts?))
  (define-values (net2 dict-cell)
    (add-trait-resolution-bridge net1 type-cell 'Eq))
  ;; Don't solve the type → dict stays unresolved
  (define result (run-to-quiescence net2))
  (check-equal? (net-cell-read result dict-cell) #f))

(test-case "C0-A4: depth-1 — no matching impl leaves dict unresolved"
  (define net0 (make-prop-network 200))
  (define-values (net1 type-cell)
    (net-new-cell net0 #f type-merge type-contradicts?))
  (define-values (net2 dict-cell)
    (add-trait-resolution-bridge net1 type-cell 'Eq))
  ;; Solve to a type with no Eq impl
  (define net3 (net-cell-write net2 type-cell 'Function))
  (define result (run-to-quiescence net3))
  (check-equal? (net-cell-read result dict-cell) #f))

;; ========================================
;; §B — Depth 2: Chained Trait Resolution
;; ========================================
;; Scenario: Resolving Seq ?C triggers needing Foldable for the same constructor
;; Implementation: type-cell → Seq bridge → seq-dict-cell
;;                 type-cell → Foldable bridge → foldable-dict-cell
;; Both resolve from the same type cell grounding.

(test-case "C0-B1: depth-2 — Seq + Foldable resolve from same type grounding"
  (define net0 (make-prop-network 200))
  (define-values (net1 type-cell)
    (net-new-cell net0 #f type-merge type-contradicts?))
  ;; Wire both trait bridges
  (define-values (net2 seq-dict-cell)
    (add-trait-resolution-bridge net1 type-cell 'Seq))
  (define-values (net3 foldable-dict-cell)
    (add-trait-resolution-bridge net2 type-cell 'Foldable))
  ;; Solve ?C = List
  (define net4 (net-cell-write net3 type-cell 'List))
  (define result (run-to-quiescence net4))
  ;; Both dicts should resolve
  (check-equal? (net-cell-read result seq-dict-cell) 'seq-list-dict)
  (check-equal? (net-cell-read result foldable-dict-cell) 'foldable-list-dict)
  (define used (firings-used net4 result))
  (check-true (< used 20)
    (format "depth-2 (parallel) used ~a firings (threshold: 20)" used)))

;; Depth-2 with dependency chain: resolving outer constraint produces
;; a value that triggers an inner constraint's type cell.
(test-case "C0-B2: depth-2 — cascading resolution via feedback"
  (define net0 (make-prop-network 200))
  ;; Outer type cell: ?C (will become List)
  (define-values (net1 outer-type-cell)
    (net-new-cell net0 #f type-merge type-contradicts?))
  ;; Inner type cell: ?A (will be set by a propagator that depends on outer-dict)
  (define-values (net2 inner-type-cell)
    (net-new-cell net1 #f type-merge type-contradicts?))
  ;; Outer: Seq ?C → seq-dict-cell
  (define-values (net3 seq-dict-cell)
    (add-trait-resolution-bridge net2 outer-type-cell 'Seq))
  ;; Inner: Eq ?A → eq-dict-cell (depends on inner-type-cell)
  (define-values (net4 eq-dict-cell)
    (add-trait-resolution-bridge net3 inner-type-cell 'Eq))
  ;; Feedback propagator: when seq-dict resolves, set inner-type to Nat
  ;; (simulates: "resolving Seq List means the element type Nat needs Eq")
  (define-values (net5 _feedback-pid)
    (net-add-propagator net4
      (list seq-dict-cell) (list inner-type-cell)
      (lambda (net)
        (define dict-val (net-cell-read net seq-dict-cell))
        (if (and dict-val (not (eq? dict-val 'top)))
            (net-cell-write net inner-type-cell 'Nat)
            net))))
  ;; Solve outer: ?C = List
  (define net6 (net-cell-write net5 outer-type-cell 'List))
  (define result (run-to-quiescence net6))
  ;; Outer resolved
  (check-equal? (net-cell-read result seq-dict-cell) 'seq-list-dict)
  ;; Inner resolved via feedback chain
  (check-equal? (net-cell-read result inner-type-cell) 'Nat)
  (check-equal? (net-cell-read result eq-dict-cell) 'eq-nat-dict)
  (define used (firings-used net6 result))
  (check-true (< used 20)
    (format "depth-2 (cascading) used ~a firings (threshold: 20)" used)))

;; ========================================
;; §C — Depth 3: Three Levels of Dependent Resolution
;; ========================================
;; Scenario: Iterable ?C → needs Seq ?C → needs Foldable ?C
;; Plus: the element type resolves Eq
;; All within a single quiescence pass.

(test-case "C0-C1: depth-3 — three-level cascading resolution"
  (define net0 (make-prop-network 500))
  ;; Level 0: outer type cell (?C)
  (define-values (net1 outer-type)
    (net-new-cell net0 #f type-merge type-contradicts?))
  ;; Level 1: Iterable bridge
  (define-values (net2 iterable-dict)
    (add-trait-resolution-bridge net1 outer-type 'Iterable))
  ;; Level 2: Seq bridge (same type cell — parallel resolution)
  (define-values (net3 seq-dict)
    (add-trait-resolution-bridge net2 outer-type 'Seq))
  ;; Level 3: Foldable bridge (same type cell — parallel resolution)
  (define-values (net4 foldable-dict)
    (add-trait-resolution-bridge net3 outer-type 'Foldable))
  ;; Level 3+: Element type needs Eq (cascading via feedback)
  (define-values (net5 elem-type)
    (net-new-cell net4 #f type-merge type-contradicts?))
  (define-values (net6 eq-dict)
    (add-trait-resolution-bridge net5 elem-type 'Eq))
  ;; Feedback: when iterable-dict resolves, set element type to Nat
  (define-values (net7 _fp)
    (net-add-propagator net6
      (list iterable-dict) (list elem-type)
      (lambda (net)
        (define d (net-cell-read net iterable-dict))
        (if (and d (not (eq? d 'top)))
            (net-cell-write net elem-type 'Nat)
            net))))
  ;; Solve: ?C = PVec
  (define net8 (net-cell-write net7 outer-type 'PVec))
  (define result (run-to-quiescence net8))
  ;; All four dicts resolved
  (check-equal? (net-cell-read result iterable-dict) 'iterable-pvec-dict)
  (check-equal? (net-cell-read result seq-dict) 'seq-pvec-dict)
  (check-equal? (net-cell-read result foldable-dict) 'foldable-pvec-dict)
  (check-equal? (net-cell-read result elem-type) 'Nat)
  (check-equal? (net-cell-read result eq-dict) 'eq-nat-dict)
  (define used (firings-used net8 result))
  (check-true (< used 50)
    (format "depth-3 used ~a firings (threshold: 50)" used)))

;; ========================================
;; §D — Multiple Independent Constraints
;; ========================================
;; Scenario: Multiple type cells resolve independently, each triggering
;; its own trait bridge. Verifies no cross-contamination.

(test-case "C0-D1: multiple independent type cells with different trait bridges"
  (define net0 (make-prop-network 200))
  ;; Type cell 1: ?A, needs Eq
  (define-values (net1 type1)
    (net-new-cell net0 #f type-merge type-contradicts?))
  (define-values (net2 dict1)
    (add-trait-resolution-bridge net1 type1 'Eq))
  ;; Type cell 2: ?B, needs Seq
  (define-values (net3 type2)
    (net-new-cell net2 #f type-merge type-contradicts?))
  (define-values (net4 dict2)
    (add-trait-resolution-bridge net3 type2 'Seq))
  ;; Solve both
  (define net5 (net-cell-write (net-cell-write net4 type1 'Bool) type2 'PVec))
  (define result (run-to-quiescence net5))
  (check-equal? (net-cell-read result dict1) 'eq-bool-dict)
  (check-equal? (net-cell-read result dict2) 'seq-pvec-dict))

;; ========================================
;; §E — Convergence Under Delayed Grounding
;; ========================================
;; Type cell starts unsolved, bridge is wired, then type cell
;; is solved in a later "phase" (second write after first quiescence).

(test-case "C0-E1: delayed grounding — bridge fires on later write"
  (define net0 (make-prop-network 200))
  (define-values (net1 type-cell)
    (net-new-cell net0 #f type-merge type-contradicts?))
  (define-values (net2 dict-cell)
    (add-trait-resolution-bridge net1 type-cell 'Functor))
  ;; First quiescence: nothing to resolve
  (define net3 (run-to-quiescence net2))
  (check-equal? (net-cell-read net3 dict-cell) #f)
  ;; Later: solve the type
  (define net4 (net-cell-write net3 type-cell 'List))
  (define result (run-to-quiescence net4))
  (check-equal? (net-cell-read result dict-cell) 'functor-list-dict))

;; ========================================
;; §F — Fuel Safety
;; ========================================
;; Even a pathological feedback loop terminates via fuel exhaustion.

(test-case "C0-F1: pathological feedback terminates via fuel"
  (define net0 (make-prop-network 50))  ;; low fuel
  (define-values (net1 cell-a)
    (net-new-cell net0 0 + #f))  ;; additive merge: always changes
  (define-values (net2 cell-b)
    (net-new-cell net1 0 + #f))
  ;; Circular: a writes 1 to b, b writes 1 to a (divergent)
  (define-values (net3 _p1)
    (net-add-propagator net2
      (list cell-a) (list cell-b)
      (lambda (net) (net-cell-write net cell-b 1))))
  (define-values (net4 _p2)
    (net-add-propagator net3
      (list cell-b) (list cell-a)
      (lambda (net) (net-cell-write net cell-a 1))))
  ;; Trigger
  (define net5 (net-cell-write net4 cell-a 1))
  (define result (run-to-quiescence net5))
  ;; Should exhaust fuel, not hang
  (check-equal? (prop-network-fuel result) 0))
