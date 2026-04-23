#lang racket/base

;;;
;;; test-type-lattice.rkt — Tests for the type lattice merge function
;;;
;;; Tests lattice axioms, structural unification via merge, try-unify-pure,
;;; and PropNetwork integration.
;;;

(require rackunit
         rackunit/text-ui
         "../prelude.rkt"
         "../syntax.rkt"
         "../type-lattice.rkt"
         "../propagator.rkt"
         "../champ.rkt")

;; ========================================
;; Lattice axioms
;; ========================================

(define lattice-axiom-tests
  (test-suite
   "Lattice axioms"

   (test-case "merge(bot, bot) = bot"
     (check-equal? (type-lattice-merge type-bot type-bot) type-bot))

   (test-case "merge(bot, Nat) = Nat [identity]"
     (check-equal? (type-lattice-merge type-bot (expr-Nat)) (expr-Nat)))

   (test-case "merge(Nat, bot) = Nat [commutative identity]"
     (check-equal? (type-lattice-merge (expr-Nat) type-bot) (expr-Nat)))

   (test-case "merge(Nat, Nat) = Nat [idempotent]"
     (check-equal? (type-lattice-merge (expr-Nat) (expr-Nat)) (expr-Nat)))

   (test-case "merge(Nat, Bool) = Bool | Nat [set-union semantics, T-3 Commit B]"
     ;; PPN 4C Path T-3 Commit B: structurally-incompatible concrete types
     ;; produce the union (Role A accumulate), not type-top. Sorted by
     ;; union-sort-key ("0:Bool" < "0:Nat").
     (check-equal? (type-lattice-merge (expr-Nat) (expr-Bool))
                   (expr-union (expr-Bool) (expr-Nat))))

   (test-case "merge(top, anything) = top [absorbing]"
     (check-equal? (type-lattice-merge type-top (expr-Nat)) type-top)
     (check-equal? (type-lattice-merge (expr-Bool) type-top) type-top)
     (check-equal? (type-lattice-merge type-top type-top) type-top))))

;; ========================================
;; Structural unification via merge
;; ========================================

(define structural-tests
  (test-suite
   "Structural unification via merge"

   (test-case "Pi Nat Bool = Pi Nat Bool"
     (define pi1 (expr-Pi 'mw (expr-Nat) (expr-Bool)))
     (define pi2 (expr-Pi 'mw (expr-Nat) (expr-Bool)))
     (define result (type-lattice-merge pi1 pi2))
     ;; Should succeed (equal? fast path)
     (check-not-equal? result type-top)
     (check-true (expr-Pi? result)))

   (test-case "Sigma Nat Bool = Sigma Nat Bool"
     (define s1 (expr-Sigma (expr-Nat) (expr-Bool)))
     (define s2 (expr-Sigma (expr-Nat) (expr-Bool)))
     (define result (type-lattice-merge s1 s2))
     (check-not-equal? result type-top)
     (check-true (expr-Sigma? result)))

   (test-case "Pi Nat Bool vs Pi Nat Int = union [T-3 Commit B: codomain mismatch → union]"
     (define pi1 (expr-Pi 'mw (expr-Nat) (expr-Bool)))
     (define pi2 (expr-Pi 'mw (expr-Nat) (expr-Int)))
     ;; PPN 4C Path T-3 Commit B: structurally-incompatible Pis → union.
     ;; Sorted by union-sort-key: "3:Pi:0:Nat:0:Bool" < "3:Pi:0:Nat:0:Int" (B<I).
     (check-equal? (type-lattice-merge pi1 pi2)
                   (expr-union pi1 pi2)))

   (test-case "List Nat = List Nat [via app decomposition]"
     ;; (List Nat) = (app (tycon List) Nat)
     (define t1 (expr-app (expr-tycon 'List) (expr-Nat)))
     (define t2 (expr-app (expr-tycon 'List) (expr-Nat)))
     (define result (type-lattice-merge t1 t2))
     (check-not-equal? result type-top)
     (check-true (expr-app? result)))

   (test-case "List Nat vs List Bool = union [T-3 Commit B: arg mismatch → union]"
     (define t1 (expr-app (expr-tycon 'List) (expr-Nat)))
     (define t2 (expr-app (expr-tycon 'List) (expr-Bool)))
     ;; PPN 4C Path T-3 Commit B: structurally-incompatible apps → union.
     ;; Both apps have sort-key "4:app" (no component subkey); stable sort
     ;; preserves input order [t1, t2].
     (check-equal? (type-lattice-merge t1 t2)
                   (expr-union t1 t2)))

   (test-case "suc zero = suc zero"
     (define t1 (expr-suc (expr-zero)))
     (define t2 (expr-suc (expr-zero)))
     (define result (type-lattice-merge t1 t2))
     (check-not-equal? result type-top)
     (check-true (expr-suc? result))
     (check-true (expr-zero? (expr-suc-pred result))))

   (test-case "Type lzero = Type lzero"
     (define t1 (expr-Type 'lzero))
     (define t2 (expr-Type 'lzero))
     (define result (type-lattice-merge t1 t2))
     (check-not-equal? result type-top)
     (check-true (expr-Type? result)))

   (test-case "Eq Nat zero zero = Eq Nat zero zero"
     (define t1 (expr-Eq (expr-Nat) (expr-zero) (expr-zero)))
     (define t2 (expr-Eq (expr-Nat) (expr-zero) (expr-zero)))
     (define result (type-lattice-merge t1 t2))
     (check-not-equal? result type-top)
     (check-true (expr-Eq? result)))))

;; ========================================
;; try-unify-pure directly
;; ========================================

(define pure-unify-tests
  (test-suite
   "try-unify-pure"

   (test-case "Ground types unify: Nat = Nat"
     (check-equal? (try-unify-pure (expr-Nat) (expr-Nat)) (expr-Nat)))

   (test-case "Ground types fail: Nat ≠ Bool"
     (check-false (try-unify-pure (expr-Nat) (expr-Bool))))

   (test-case "Meta encountered → returns concrete side (P-U4b)"
     ;; P-U4b: unsolved meta ⊔ concrete = concrete (monotone lattice merge)
     (check-equal? (try-unify-pure (expr-meta 'x #f) (expr-Nat)) (expr-Nat))
     (check-equal? (try-unify-pure (expr-Nat) (expr-meta 'y #f)) (expr-Nat)))

   (test-case "Nested structure: Pi(Pi(Nat,Bool), Int)"
     (define inner (expr-Pi 'mw (expr-Nat) (expr-Bool)))
     (define t1 (expr-Pi 'mw inner (expr-Int)))
     (define t2 (expr-Pi 'mw inner (expr-Int)))
     (define result (try-unify-pure t1 t2))
     (check-true (expr-Pi? result))
     (check-true (expr-Pi? (expr-Pi-domain result))))

   (test-case "pair: pair(zero, true) = pair(zero, true)"
     (define t1 (expr-pair (expr-zero) (expr-true)))
     (define t2 (expr-pair (expr-zero) (expr-true)))
     (define result (try-unify-pure t1 t2))
     (check-true (expr-pair? result)))

   (test-case "pair mismatch: pair(zero, true) ≠ pair(zero, false)"
     (check-false (try-unify-pure
                    (expr-pair (expr-zero) (expr-true))
                    (expr-pair (expr-zero) (expr-false)))))

   (test-case "Vec: Vec Nat zero = Vec Nat zero"
     (define t1 (expr-Vec (expr-Nat) (expr-zero)))
     (define t2 (expr-Vec (expr-Nat) (expr-zero)))
     (define result (try-unify-pure t1 t2))
     (check-true (expr-Vec? result)))

   (test-case "Map: Map Nat Bool = Map Nat Bool"
     (define t1 (expr-Map (expr-Nat) (expr-Bool)))
     (define t2 (expr-Map (expr-Nat) (expr-Bool)))
     (define result (try-unify-pure t1 t2))
     (check-true (expr-Map? result)))))

;; ========================================
;; PropNetwork integration
;; ========================================

(define propnet-integration-tests
  (test-suite
   "PropNetwork integration"

   (test-case "Two cells with same value: no contradiction"
     (define net0 (make-prop-network))
     (define-values (net1 cid1) (net-new-cell net0 type-bot type-lattice-merge type-lattice-contradicts?))
     (define-values (net2 cid2) (net-new-cell net1 type-bot type-lattice-merge type-lattice-contradicts?))
     ;; Write Nat to both
     (define net3 (net-cell-write net2 cid1 (expr-Nat)))
     (define net4 (net-cell-write net3 cid2 (expr-Nat)))
     ;; Both should read Nat
     (check-equal? (net-cell-read net4 cid1) (expr-Nat))
     (check-equal? (net-cell-read net4 cid2) (expr-Nat))
     ;; No contradiction
     (check-false (net-contradiction? net4)))

   (test-case "Incompatible writes under type-lattice-merge (Role A): Nat then Bool → union [T-3 Commit B]"
     ;; PPN 4C Path T-3 Commit B: type-lattice-merge is Role A (accumulate).
     ;; Structurally-incompatible writes produce the union, NOT type-top.
     ;; No contradiction fires for Role A cells on type mismatch.
     (define net0 (make-prop-network))
     (define-values (net1 cid) (net-new-cell net0 type-bot type-lattice-merge type-lattice-contradicts?))
     ;; Write Nat
     (define net2 (net-cell-write net1 cid (expr-Nat)))
     (check-equal? (net-cell-read net2 cid) (expr-Nat))
     ;; Write Bool → union (Role A accumulate semantics)
     (define net3 (net-cell-write net2 cid (expr-Bool)))
     (check-equal? (net-cell-read net3 cid)
                   (expr-union (expr-Bool) (expr-Nat)))
     ;; No contradiction — cell holds a valid union value
     (check-false (net-contradiction? net3)))

   (test-case "Role B cell: Nat then Bool → type-top contradiction [T-3 equality enforcement]"
     ;; Role B cells (equality enforcement) use type-unify-or-top as merge-fn.
     ;; Incompatible writes produce type-top → contradicts? fires.
     ;; Covers classify-inhabit, cap-type-bridge, session-type-bridge pattern.
     (define net0 (make-prop-network))
     (define-values (net1 cid)
       (net-new-cell net0 type-bot type-unify-or-top type-lattice-contradicts?))
     (define net2 (net-cell-write net1 cid (expr-Nat)))
     (check-equal? (net-cell-read net2 cid) (expr-Nat))
     (define net3 (net-cell-write net2 cid (expr-Bool)))
     (check-true (net-contradiction? net3)))))

;; ========================================
;; Phase E1: Meta-following via callback
;; ========================================

(define phase-e1-tests
  (test-suite
   "Phase E1: Meta-following + unsolved-meta guard"

   (test-case "try-unify-pure follows solved meta (LHS)"
     ;; Simulate: meta 'a is solved to Nat
     (parameterize ([current-lattice-meta-solution-fn
                     (lambda (id) (if (eq? id 'a) (expr-Nat) #f))])
       ;; (expr-meta 'a #f) should unify with Nat → Nat
       (check-equal? (try-unify-pure (expr-meta 'a #f) (expr-Nat)) (expr-Nat))))

   (test-case "try-unify-pure follows solved meta (RHS)"
     (parameterize ([current-lattice-meta-solution-fn
                     (lambda (id) (if (eq? id 'b) (expr-Bool) #f))])
       (check-equal? (try-unify-pure (expr-Nat) (expr-meta 'b #f)) #f)  ;; Nat ≠ Bool
       (check-equal? (try-unify-pure (expr-Bool) (expr-meta 'b #f)) (expr-Bool))))

   (test-case "try-unify-pure returns concrete side for unsolved meta (P-U4b)"
     (parameterize ([current-lattice-meta-solution-fn
                     (lambda (id) #f)])  ;; All unsolved
       ;; P-U4b: unsolved meta → return the other (concrete) side
       (check-equal? (try-unify-pure (expr-meta 'x #f) (expr-Nat)) (expr-Nat))
       (check-equal? (try-unify-pure (expr-Nat) (expr-meta 'y #f)) (expr-Nat))))

   (test-case "try-unify-pure follows solved meta inside structure"
     ;; Meta 'a solved to Nat; try to unify (List ?a) with (List Nat)
     (parameterize ([current-lattice-meta-solution-fn
                     (lambda (id) (if (eq? id 'a) (expr-Nat) #f))])
       (define t1 (expr-app (expr-tycon 'List) (expr-meta 'a #f)))
       (define t2 (expr-app (expr-tycon 'List) (expr-Nat)))
       (define result (try-unify-pure t1 t2))
       (check-true (expr-app? result))
       (check-equal? (expr-app-arg result) (expr-Nat))))

   (test-case "merge: unsolved meta avoids false contradiction"
     ;; If one side has an unsolved meta, merge should return the
     ;; more concrete side instead of type-top
     (parameterize ([current-lattice-meta-solution-fn
                     (lambda (id) #f)])  ;; All unsolved
       (define result (type-lattice-merge (expr-meta 'x #f) (expr-Nat)))
       ;; Should NOT be type-top — should be Nat (the concrete side)
       (check-equal? result (expr-Nat))))

   (test-case "merge: unsolved meta on RHS avoids false contradiction"
     (parameterize ([current-lattice-meta-solution-fn
                     (lambda (id) #f)])
       (define result (type-lattice-merge (expr-Nat) (expr-meta 'y #f)))
       (check-equal? result (expr-Nat))))

   (test-case "merge: solved meta enables proper merge"
     ;; Meta 'a solved to Nat → merge(Nat, ?a) = Nat
     (parameterize ([current-lattice-meta-solution-fn
                     (lambda (id) (if (eq? id 'a) (expr-Nat) #f))])
       (define result (type-lattice-merge (expr-Nat) (expr-meta 'a #f)))
       (check-equal? result (expr-Nat))))

   (test-case "merge: solved meta with mismatch = union [T-3 Commit B: set-union semantics]"
     ;; Meta 'a solved to Bool → merge(Nat, ?a) = Bool | Nat.
     ;; PPN 4C Path T-3 Commit B: solved meta is followed via callback.
     ;; When both sides resolve to concrete incompatible types (Nat vs Bool),
     ;; Role A type-lattice-merge produces the union. Role B callers use
     ;; type-unify-or-top for equality enforcement.
     (parameterize ([current-lattice-meta-solution-fn
                     (lambda (id) (if (eq? id 'a) (expr-Bool) #f))])
       (define result (type-lattice-merge (expr-Nat) (expr-meta 'a #f)))
       (check-equal? result (expr-union (expr-Bool) (expr-Nat))))
     ;; Role B equivalent: type-unify-or-top preserves type-top for equality checks
     (parameterize ([current-lattice-meta-solution-fn
                     (lambda (id) (if (eq? id 'a) (expr-Bool) #f))])
       (define result (type-unify-or-top (expr-Nat) (expr-meta 'a #f)))
       (check-equal? result type-top)))

   (test-case "try-unify-pure follows solved mult-meta in Pi"
     ;; Pi with mult-meta that's solved to 'mw
     (parameterize ([current-lattice-meta-solution-fn
                     (lambda (id) (if (eq? id 'm1) 'mw #f))])
       (define pi1 (expr-Pi (mult-meta 'm1) (expr-Nat) (expr-Bool)))
       (define pi2 (expr-Pi 'mw (expr-Nat) (expr-Bool)))
       (define result (try-unify-pure pi1 pi2))
       (check-true (expr-Pi? result))
       (check-equal? (expr-Pi-mult result) 'mw)))

   (test-case "has-unsolved-meta? detects unsolved"
     (parameterize ([current-lattice-meta-solution-fn
                     (lambda (id) #f)])
       (check-true (has-unsolved-meta? (expr-meta 'x #f)))
       (check-true (has-unsolved-meta? (expr-app (expr-tycon 'List) (expr-meta 'x #f))))
       (check-false (has-unsolved-meta? (expr-Nat)))
       (check-false (has-unsolved-meta? (expr-Pi 'mw (expr-Nat) (expr-Bool))))))

   (test-case "has-unsolved-meta? respects solved"
     (parameterize ([current-lattice-meta-solution-fn
                     (lambda (id) (if (eq? id 'a) (expr-Nat) #f))])
       ;; 'a is solved → not unsolved
       (check-false (has-unsolved-meta? (expr-meta 'a #f)))
       ;; 'b is unsolved → has unsolved
       (check-true (has-unsolved-meta? (expr-meta 'b #f)))))))

;; ========================================
;; Run all tests
;; ========================================

(run-tests lattice-axiom-tests)
(run-tests structural-tests)
(run-tests pure-unify-tests)
(run-tests propnet-integration-tests)
(run-tests phase-e1-tests)
