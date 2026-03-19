#lang racket/base

;; bench-type-unify.rkt — Comprehensive type-level unification micro-benchmarks
;;
;; Establishes baselines for PUnify (propagator-based unification).
;; Each benchmark measures a specific unification primitive that PUnify will
;; replace or modify. The classification distribution from profile-unify.rkt
;; guides the selection:
;;
;;   level:      36%  — universe level lattice (PUnify: no change, must not regress)
;;   flex-rigid: 24%  — meta solution (PUnify: cell write replaces solve-flex-rigid)
;;   pi:         18%  — Pi decomposition (PUnify: tree unfold replaces decompose-pi)
;;   ok:         14%  — structural equality (PUnify: CHAMP eq? replaces AST equal?)
;;   binder:      6%  — Sigma/lam decomposition (PUnify: tree unfold)
;;   sub:         3%  — app rigid-rigid (PUnify: children comparison)
;;
;; Run: racket benchmarks/micro/bench-type-unify.rkt

(require "../../tools/bench-micro.rkt"
         "../../syntax.rkt"
         "../../unify.rkt"
         "../../metavar-store.rkt"
         "../../reduction.rkt"
         "../../zonk.rkt"
         "../../performance-counters.rkt"
         "../../driver.rkt"
         racket/list)

;; ============================================================
;; Helpers: type constructors
;; ============================================================

;; Deeply nested Pi: (Nat -> (Nat -> ... -> Nat))
(define (deep-pi depth)
  (if (zero? depth)
      (expr-Nat)
      (expr-Pi 'mw (expr-Nat) (deep-pi (sub1 depth)))))

;; Pi with meta in domain: (? -> Nat)
(define (pi-with-meta-domain ctx)
  (define m (fresh-meta ctx (expr-Type 0) 'bench-dom))
  (expr-Pi 'mw m (expr-Nat)))

;; Pi with meta in codomain: (Nat -> ?)
(define (pi-with-meta-codomain ctx)
  (define m (fresh-meta ctx (expr-Type 0) 'bench-cod))
  (expr-Pi 'mw (expr-Nat) m))

;; Deeply nested application: (((f Nat) Nat) ... Nat)
(define (deep-app depth base)
  (if (zero? depth)
      base
      (expr-app (deep-app (sub1 depth) base) (expr-Nat))))

;; Sigma type: Σ(x : A). B
(define (make-sigma a b)
  (expr-Sigma a b))

;; Nested Sigma: Σ(x : Nat). Σ(y : Nat). ... Nat
(define (deep-sigma depth)
  (if (zero? depth)
      (expr-Nat)
      (make-sigma (expr-Nat) (deep-sigma (sub1 depth)))))

;; Wide Pi: (A₁ -> A₂ -> ... -> Aₙ -> Nat) with distinct ground types
(define (wide-pi width)
  (if (zero? width)
      (expr-Nat)
      (expr-Pi 'mw (expr-Nat) (wide-pi (sub1 width)))))

;; Application chain: ((tycon arg₁) arg₂) ... argₙ
(define (app-chain tycon args)
  (foldl (λ (arg acc) (expr-app acc arg)) tycon args))

;; Fresh stores for each benchmark iteration
(define (with-fresh-stores thunk)
  (with-fresh-meta-env
    (parameterize ([current-reduction-fuel (box 10000)])
      (thunk))))

;; ============================================================
;; Section 1: Structural Equality (ok classification, 14%)
;; ============================================================
;; PUnify: CHAMP pointer equality replaces AST equal?

(define b-ok-nat
  (bench "ok: identical Nat x5000"
    (with-fresh-stores
      (λ () (for ([_ (in-range 5000)])
              (unify '() (expr-Nat) (expr-Nat)))))))

(define b-ok-deep-pi
  (let ([ty (deep-pi 20)])
    (bench "ok: identical deep Pi (d=20) x500"
      (with-fresh-stores
        (λ () (for ([_ (in-range 500)])
                (unify '() ty ty)))))))

(define b-ok-deep-pi-50
  (let ([ty (deep-pi 50)])
    (bench "ok: identical deep Pi (d=50) x100"
      (with-fresh-stores
        (λ () (for ([_ (in-range 100)])
                (unify '() ty ty)))))))

;; ============================================================
;; Section 2: Flex-Rigid — Meta Solution (24%)
;; ============================================================
;; PUnify: bot cell → write value. Includes occurs check.

(define b-flex-rigid-simple
  (bench "flex-rigid: ?m = Nat x1000"
    (with-fresh-stores
      (λ ()
        (for ([_ (in-range 1000)])
          (with-fresh-meta-env
            (define m (fresh-meta '() (expr-Type 0) 'bench))
            (unify '() m (expr-Nat))))))))

(define b-flex-rigid-pi
  (bench "flex-rigid: ?m = Pi(Nat,Nat) x500"
    (with-fresh-stores
      (λ ()
        (let ([target (expr-Pi 'mw (expr-Nat) (expr-Nat))])
          (for ([_ (in-range 500)])
            (with-fresh-meta-env
              (define m (fresh-meta '() (expr-Type 0) 'bench))
              (unify '() m target))))))))

(define b-flex-rigid-deep-pi
  (bench "flex-rigid: ?m = deep Pi (d=10) x200"
    (with-fresh-stores
      (λ ()
        (let ([target (deep-pi 10)])
          (for ([_ (in-range 200)])
            (with-fresh-meta-env
              (define m (fresh-meta '() (expr-Type 0) 'bench))
              (unify '() m target))))))))

(define b-flex-rigid-app
  (bench "flex-rigid: ?m = App(List, Nat) x500"
    (with-fresh-stores
      (λ ()
        (let ([target (expr-app (expr-tycon 'List) (expr-Nat))])
          (for ([_ (in-range 500)])
            (with-fresh-meta-env
              (define m (fresh-meta '() (expr-Type 0) 'bench))
              (unify '() m target))))))))

;; Multiple metas in one pass — simulates elaboration of polymorphic application
(define b-flex-rigid-multi
  (bench "flex-rigid: 10 metas in sequence x100"
    (with-fresh-stores
      (λ ()
        (for ([_ (in-range 100)])
          (with-fresh-meta-env
            (for ([i (in-range 10)])
              (define m (fresh-meta '() (expr-Type 0) 'bench))
              (unify '() m (expr-Nat)))))))))

;; ============================================================
;; Section 3: Pi Decomposition (18%)
;; ============================================================
;; PUnify: tree unfold — each Pi child becomes a cell.
;; Currently: decompose-pi creates sub-cells + wires propagators.

(define b-pi-shallow
  (bench "pi: (Nat→Nat) vs (Nat→Nat) x1000"
    (with-fresh-stores
      (λ ()
        (let ([a (expr-Pi 'mw (expr-Nat) (expr-Nat))]
              [b (expr-Pi 'mw (expr-Nat) (expr-Nat))])
          (for ([_ (in-range 1000)])
            (unify '() a b)))))))

(define b-pi-decompose-10
  (let ([a (deep-pi 10)]
        [b (deep-pi 10)])
    (bench "pi: decompose d=10 (distinct objs) x500"
      (with-fresh-stores
        (λ () (for ([_ (in-range 500)])
                (unify '() a b)))))))

(define b-pi-decompose-20
  (let ([a (deep-pi 20)]
        [b (deep-pi 20)])
    (bench "pi: decompose d=20 (distinct objs) x200"
      (with-fresh-stores
        (λ () (for ([_ (in-range 200)])
                (unify '() a b)))))))

;; Pi with meta in domain — forces flex-rigid inside decomposition
(define b-pi-meta-domain
  (bench "pi: meta in domain (?→Nat) vs (Nat→Nat) x500"
    (with-fresh-stores
      (λ ()
        (let ([target (expr-Pi 'mw (expr-Nat) (expr-Nat))])
          (for ([_ (in-range 500)])
            (with-fresh-meta-env
              (define src (pi-with-meta-domain '()))
              (unify '() src target))))))))

;; Wide Pi — many arguments
(define b-pi-wide-20
  (let ([a (wide-pi 20)]
        [b (wide-pi 20)])
    (bench "pi: wide w=20 x200"
      (with-fresh-stores
        (λ () (for ([_ (in-range 200)])
                (unify '() a b)))))))

;; ============================================================
;; Section 4: Binder Decomposition — Sigma/Lam (6%)
;; ============================================================

(define b-sigma-shallow
  (bench "sigma: Σ(Nat,Nat) vs Σ(Nat,Nat) x1000"
    (with-fresh-stores
      (λ ()
        (let ([a (make-sigma (expr-Nat) (expr-Nat))]
              [b (make-sigma (expr-Nat) (expr-Nat))])
          (for ([_ (in-range 1000)])
            (unify '() a b)))))))

(define b-sigma-deep-10
  (let ([a (deep-sigma 10)]
        [b (deep-sigma 10)])
    (bench "sigma: deep d=10 x500"
      (with-fresh-stores
        (λ () (for ([_ (in-range 500)])
                (unify '() a b)))))))

(define b-lam-identical
  (bench "lam: identical λ(Nat,body) x1000"
    (with-fresh-stores
      (λ ()
        (let ([a (expr-lam 'mw (expr-Nat) (expr-bvar 0))]
              [b (expr-lam 'mw (expr-Nat) (expr-bvar 0))])
          (for ([_ (in-range 1000)])
            (unify '() a b)))))))

;; ============================================================
;; Section 5: App Rigid-Rigid — Sub-goal Decomposition (3%)
;; ============================================================

(define b-app-simple
  (bench "app: (List Nat) vs (List Nat) x1000"
    (with-fresh-stores
      (λ ()
        (let ([a (expr-app (expr-tycon 'List) (expr-Nat))]
              [b (expr-app (expr-tycon 'List) (expr-Nat))])
          (for ([_ (in-range 1000)])
            (unify '() a b)))))))

(define b-app-deep-5
  (bench "app: deep app chain d=5 x500"
    (with-fresh-stores
      (λ ()
        (let ([a (deep-app 5 (expr-tycon 'F))]
              [b (deep-app 5 (expr-tycon 'F))])
          (for ([_ (in-range 500)])
            (unify '() a b)))))))

(define b-app-mismatch
  (bench "app: (List Nat) vs (List Bool) FAIL x1000"
    (with-fresh-stores
      (λ ()
        (let ([a (expr-app (expr-tycon 'List) (expr-Nat))]
              [b (expr-app (expr-tycon 'List) (expr-Bool))])
          (for ([_ (in-range 1000)])
            (unify '() a b)))))))

;; ============================================================
;; Section 6: Universe Level (36%)
;; ============================================================
;; PUnify: must not regress. Level unification is separate lattice.

(define b-level-same
  (bench "level: Type 0 vs Type 0 x5000"
    (with-fresh-stores
      (λ () (for ([_ (in-range 5000)])
              (unify '() (expr-Type 0) (expr-Type 0)))))))

(define b-level-different
  (bench "level: Type 0 vs Type 1 x5000"
    (with-fresh-stores
      (λ () (for ([_ (in-range 5000)])
              (unify '() (expr-Type 0) (expr-Type 1)))))))

;; ============================================================
;; Section 7: Conv/Mismatch — Failure Detection (1%)
;; ============================================================

(define b-conv-ground
  (bench "conv: Nat vs Bool FAIL x2000"
    (with-fresh-stores
      (λ () (for ([_ (in-range 2000)])
              (unify '() (expr-Nat) (expr-Bool)))))))

(define b-conv-tycon
  (bench "conv: List vs Map FAIL x2000"
    (with-fresh-stores
      (λ () (for ([_ (in-range 2000)])
              (unify '() (expr-tycon 'List) (expr-tycon 'Map)))))))

;; ============================================================
;; Section 8: Zonk — Tree Traversal (PUnify: cell-tree read)
;; ============================================================

(define b-zonk-ground
  (let ([ty (deep-pi 20)])
    (bench "zonk: ground deep Pi d=20 x500"
      (with-fresh-stores
        (λ () (for ([_ (in-range 500)])
                (zonk-final ty)))))))

(define b-zonk-with-metas
  (bench "zonk: Pi with 5 solved metas x200"
    (with-fresh-stores
      (λ ()
        (for ([_ (in-range 200)])
          (with-fresh-meta-env
            ;; Create and solve metas, then zonk the type containing them
            (define m1 (fresh-meta '() (expr-Type 0) 'z1))
            (define m2 (fresh-meta '() (expr-Type 0) 'z2))
            (define m3 (fresh-meta '() (expr-Type 0) 'z3))
            (define m4 (fresh-meta '() (expr-Type 0) 'z4))
            (define m5 (fresh-meta '() (expr-Type 0) 'z5))
            (unify '() m1 (expr-Nat))
            (unify '() m2 (expr-Bool))
            (unify '() m3 (expr-Nat))
            (unify '() m4 (expr-Bool))
            (unify '() m5 (expr-Nat))
            (zonk-final
              (expr-Pi 'mw m1
                (expr-Pi 'mw m2
                  (expr-Pi 'mw m3
                    (expr-Pi 'mw m4 m5)))))))))))

;; ============================================================
;; Section 9: Combined Patterns — Real-World Scenarios
;; ============================================================

;; Polymorphic function application: infer ?A, ?B from applying f : A -> B -> C
(define b-poly-app
  (bench "combined: poly app (?A→?B→Nat) vs (Nat→Bool→Nat) x200"
    (with-fresh-stores
      (λ ()
        (let ([target (expr-Pi 'mw (expr-Nat) (expr-Pi 'mw (expr-Bool) (expr-Nat)))])
          (for ([_ (in-range 200)])
            (with-fresh-meta-env
              (define ma (fresh-meta '() (expr-Type 0) 'a))
              (define mb (fresh-meta '() (expr-Type 0) 'b))
              (define src (expr-Pi 'mw ma (expr-Pi 'mw mb (expr-Nat))))
              (unify '() src target))))))))

;; Chain of meta solutions: ?a = ?b, ?b = ?c, ?c = Nat
(define b-meta-chain
  (bench "combined: meta chain ?a=?b=?c=Nat x500"
    (with-fresh-stores
      (λ ()
        (for ([_ (in-range 500)])
          (with-fresh-meta-env
            (define ma (fresh-meta '() (expr-Type 0) 'a))
            (define mb (fresh-meta '() (expr-Type 0) 'b))
            (define mc (fresh-meta '() (expr-Type 0) 'c))
            (unify '() ma mb)
            (unify '() mb mc)
            (unify '() mc (expr-Nat))))))))

;; Occurs check stress: unify ?m with a type containing ?m
;; (Should fail — this is the negative case PUnify handles via cycle detection)
(define b-occurs-check
  (bench "combined: occurs check ?m = Pi(?m,Nat) FAIL x500"
    (with-fresh-stores
      (λ ()
        (for ([_ (in-range 500)])
          (with-fresh-meta-env
            (define m (fresh-meta '() (expr-Type 0) 'occ))
            (unify '() m (expr-Pi 'mw m (expr-Nat)))))))))

;; Deep occurs: meta nested deeper
(define b-occurs-deep
  (bench "combined: deep occurs ?m = Pi(Nat,Pi(Nat,Pi(?m,Nat))) FAIL x500"
    (with-fresh-stores
      (λ ()
        (for ([_ (in-range 500)])
          (with-fresh-meta-env
            (define m (fresh-meta '() (expr-Type 0) 'occ))
            (unify '() m
              (expr-Pi 'mw (expr-Nat)
                (expr-Pi 'mw (expr-Nat)
                  (expr-Pi 'mw m (expr-Nat)))))))))))

;; ============================================================
;; Run all
;; ============================================================

(define all-results
  (list
   ;; S1: ok (structural equality)
   b-ok-nat b-ok-deep-pi b-ok-deep-pi-50
   ;; S2: flex-rigid (meta solution)
   b-flex-rigid-simple b-flex-rigid-pi b-flex-rigid-deep-pi
   b-flex-rigid-app b-flex-rigid-multi
   ;; S3: pi decomposition
   b-pi-shallow b-pi-decompose-10 b-pi-decompose-20
   b-pi-meta-domain b-pi-wide-20
   ;; S4: binder (sigma/lam)
   b-sigma-shallow b-sigma-deep-10 b-lam-identical
   ;; S5: app rigid-rigid
   b-app-simple b-app-deep-5 b-app-mismatch
   ;; S6: universe level
   b-level-same b-level-different
   ;; S7: conv/mismatch
   b-conv-ground b-conv-tycon
   ;; S8: zonk
   b-zonk-ground b-zonk-with-metas
   ;; S9: combined
   b-poly-app b-meta-chain b-occurs-check b-occurs-deep))

(print-bench-summary all-results)
