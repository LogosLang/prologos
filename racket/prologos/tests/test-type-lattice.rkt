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

   (test-case "merge(Nat, Bool) = top [contradiction]"
     (check-equal? (type-lattice-merge (expr-Nat) (expr-Bool)) type-top))

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

   (test-case "Pi Nat Bool vs Pi Nat Int = top [codomain mismatch]"
     (define pi1 (expr-Pi 'mw (expr-Nat) (expr-Bool)))
     (define pi2 (expr-Pi 'mw (expr-Nat) (expr-Int)))
     (check-equal? (type-lattice-merge pi1 pi2) type-top))

   (test-case "List Nat = List Nat [via app decomposition]"
     ;; (List Nat) = (app (tycon List) Nat)
     (define t1 (expr-app (expr-tycon 'List) (expr-Nat)))
     (define t2 (expr-app (expr-tycon 'List) (expr-Nat)))
     (define result (type-lattice-merge t1 t2))
     (check-not-equal? result type-top)
     (check-true (expr-app? result)))

   (test-case "List Nat vs List Bool = top"
     (define t1 (expr-app (expr-tycon 'List) (expr-Nat)))
     (define t2 (expr-app (expr-tycon 'List) (expr-Bool)))
     (check-equal? (type-lattice-merge t1 t2) type-top))

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
     (check-equal? (try-unify-pure (expr-meta 'x) (expr-Nat)) (expr-Nat))
     (check-equal? (try-unify-pure (expr-Nat) (expr-meta 'y)) (expr-Nat)))

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

   (test-case "Contradictory writes: Nat then Bool → contradiction"
     (define net0 (make-prop-network))
     (define-values (net1 cid) (net-new-cell net0 type-bot type-lattice-merge type-lattice-contradicts?))
     ;; Write Nat
     (define net2 (net-cell-write net1 cid (expr-Nat)))
     (check-equal? (net-cell-read net2 cid) (expr-Nat))
     ;; Write Bool → contradiction
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
       ;; (expr-meta 'a) should unify with Nat → Nat
       (check-equal? (try-unify-pure (expr-meta 'a) (expr-Nat)) (expr-Nat))))

   (test-case "try-unify-pure follows solved meta (RHS)"
     (parameterize ([current-lattice-meta-solution-fn
                     (lambda (id) (if (eq? id 'b) (expr-Bool) #f))])
       (check-equal? (try-unify-pure (expr-Nat) (expr-meta 'b)) #f)  ;; Nat ≠ Bool
       (check-equal? (try-unify-pure (expr-Bool) (expr-meta 'b)) (expr-Bool))))

   (test-case "try-unify-pure returns concrete side for unsolved meta (P-U4b)"
     (parameterize ([current-lattice-meta-solution-fn
                     (lambda (id) #f)])  ;; All unsolved
       ;; P-U4b: unsolved meta → return the other (concrete) side
       (check-equal? (try-unify-pure (expr-meta 'x) (expr-Nat)) (expr-Nat))
       (check-equal? (try-unify-pure (expr-Nat) (expr-meta 'y)) (expr-Nat))))

   (test-case "try-unify-pure follows solved meta inside structure"
     ;; Meta 'a solved to Nat; try to unify (List ?a) with (List Nat)
     (parameterize ([current-lattice-meta-solution-fn
                     (lambda (id) (if (eq? id 'a) (expr-Nat) #f))])
       (define t1 (expr-app (expr-tycon 'List) (expr-meta 'a)))
       (define t2 (expr-app (expr-tycon 'List) (expr-Nat)))
       (define result (try-unify-pure t1 t2))
       (check-true (expr-app? result))
       (check-equal? (expr-app-arg result) (expr-Nat))))

   (test-case "merge: unsolved meta avoids false contradiction"
     ;; If one side has an unsolved meta, merge should return the
     ;; more concrete side instead of type-top
     (parameterize ([current-lattice-meta-solution-fn
                     (lambda (id) #f)])  ;; All unsolved
       (define result (type-lattice-merge (expr-meta 'x) (expr-Nat)))
       ;; Should NOT be type-top — should be Nat (the concrete side)
       (check-equal? result (expr-Nat))))

   (test-case "merge: unsolved meta on RHS avoids false contradiction"
     (parameterize ([current-lattice-meta-solution-fn
                     (lambda (id) #f)])
       (define result (type-lattice-merge (expr-Nat) (expr-meta 'y)))
       (check-equal? result (expr-Nat))))

   (test-case "merge: solved meta enables proper merge"
     ;; Meta 'a solved to Nat → merge(Nat, ?a) = Nat
     (parameterize ([current-lattice-meta-solution-fn
                     (lambda (id) (if (eq? id 'a) (expr-Nat) #f))])
       (define result (type-lattice-merge (expr-Nat) (expr-meta 'a)))
       (check-equal? result (expr-Nat))))

   (test-case "merge: solved meta with mismatch = top"
     ;; Meta 'a solved to Bool → merge(Nat, ?a) = top
     (parameterize ([current-lattice-meta-solution-fn
                     (lambda (id) (if (eq? id 'a) (expr-Bool) #f))])
       (define result (type-lattice-merge (expr-Nat) (expr-meta 'a)))
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
       (check-true (has-unsolved-meta? (expr-meta 'x)))
       (check-true (has-unsolved-meta? (expr-app (expr-tycon 'List) (expr-meta 'x))))
       (check-false (has-unsolved-meta? (expr-Nat)))
       (check-false (has-unsolved-meta? (expr-Pi 'mw (expr-Nat) (expr-Bool))))))

   (test-case "has-unsolved-meta? respects solved"
     (parameterize ([current-lattice-meta-solution-fn
                     (lambda (id) (if (eq? id 'a) (expr-Nat) #f))])
       ;; 'a is solved → not unsolved
       (check-false (has-unsolved-meta? (expr-meta 'a)))
       ;; 'b is unsolved → has unsolved
       (check-true (has-unsolved-meta? (expr-meta 'b)))))))

;; ========================================
;; Run all tests
;; ========================================

(run-tests lattice-axiom-tests)
(run-tests structural-tests)
(run-tests pure-unify-tests)
(run-tests propnet-integration-tests)
(run-tests phase-e1-tests)
