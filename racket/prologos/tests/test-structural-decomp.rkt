#lang racket/base

;;;
;;; test-structural-decomp.rkt — Tests for Phase 4c-b structural decomposition
;;;
;;; Validates the Radul/Sussman constructor/accessor pattern:
;;; compound types decompose into sub-cells connected by sub-propagators,
;;; enabling metas embedded in compound types to be solved through the network.
;;;
;;; NOTE: current-lattice-meta-solution-fn must be set for has-unsolved-meta?
;;; to detect metas. Without it, the fast path in elab-add-unify-constraint
;;; fires for ALL non-bot/non-top values, bypassing structural decomposition.
;;;
;;; NOTE: Parent cells may still contain (expr-meta id) references after solving.
;;; This is expected: try-unify-pure preserves the first side's structure.
;;; Meta references are resolved during the zonking phase (not here).
;;; The key assertion is that meta CELLS are solved to concrete values.
;;;

(require rackunit
         rackunit/text-ui
         "../syntax.rkt"
         "../type-lattice.rkt"
         "../propagator.rkt"
         "../elaborator-network.rkt")

;; ========================================
;; Test Helpers
;; ========================================

;; Create a meta-lookup callback from a hash mapping meta-id → cell-id.
(define (make-test-meta-lookup meta-map)
  (lambda (e)
    (and (expr-meta? e)
         (hash-ref meta-map (expr-meta-id e) #f))))

;; All-unsolved meta solution function.
;; Returns #f for any meta-id → all metas treated as unsolved.
;; This enables has-unsolved-meta? to detect metas in compound types.
(define (unsolved-meta-solution-fn id) #f)

;; Run the network to quiescence and return the updated elab-network.
;; Asserts no contradiction (use solve-expect-error for error cases).
(define (solve-ok enet)
  (define-values (status enet*) (elab-solve enet))
  (check-eq? status 'ok (format "Expected 'ok but got ~a" status))
  enet*)

;; Run the network and expect a contradiction.
(define (solve-expect-error enet)
  (define-values (status info) (elab-solve enet))
  (check-eq? status 'error "Expected contradiction")
  info)

;; ========================================
;; type-constructor-tag
;; ========================================

(define tag-tests
  (test-suite
   "type-constructor-tag"

   (test-case "Pi → 'Pi"
     (check-eq? (type-constructor-tag (expr-Pi 'm1 (expr-Nat) (expr-Bool))) 'Pi))

   (test-case "app → 'app"
     (check-eq? (type-constructor-tag (expr-app (expr-fvar 'f) (expr-Nat))) 'app))

   (test-case "atoms → #f"
     (check-false (type-constructor-tag (expr-Nat)))
     (check-false (type-constructor-tag (expr-Bool)))
     (check-false (type-constructor-tag (expr-Type 0)))
     (check-false (type-constructor-tag (expr-meta 42))))

   (test-case "type-bot/top → #f"
     (check-false (type-constructor-tag type-bot))
     (check-false (type-constructor-tag type-top)))))

;; ========================================
;; Pi Decomposition: Ground Components
;; ========================================

(define pi-ground-tests
  (test-suite
   "Pi decomposition: ground components"

   (test-case "Pi(Nat,Bool) = Pi(Nat,Bool) → both cells agree"
     (define enet0 (make-elaboration-network))
     (define-values (enet1 cell-a) (elab-fresh-meta enet0 '() #f "cell-a"))
     (define-values (enet2 cell-b) (elab-fresh-meta enet1 '() #f "cell-b"))
     (define pi-nat-bool (expr-Pi 'm1 (expr-Nat) (expr-Bool)))
     (define enet3 (elab-cell-write enet2 cell-a pi-nat-bool))
     (define enet4 (elab-cell-write enet3 cell-b pi-nat-bool))
     (parameterize ([current-structural-meta-lookup (make-test-meta-lookup (hash))]
                    [current-lattice-meta-solution-fn unsolved-meta-solution-fn])
       (define-values (enet5 _pid) (elab-add-unify-constraint enet4 cell-a cell-b))
       (define enet6 (solve-ok enet5))
       (check-equal? (elab-cell-read enet6 cell-a) pi-nat-bool)
       (check-equal? (elab-cell-read enet6 cell-b) pi-nat-bool)))

   (test-case "Pi(Nat,Bool) vs Pi(Nat,Nat) → contradiction"
     (define enet0 (make-elaboration-network))
     (define-values (enet1 cell-a) (elab-fresh-meta enet0 '() #f "cell-a"))
     (define-values (enet2 cell-b) (elab-fresh-meta enet1 '() #f "cell-b"))
     (define enet3 (elab-cell-write enet2 cell-a (expr-Pi 'm1 (expr-Nat) (expr-Bool))))
     (define enet4 (elab-cell-write enet3 cell-b (expr-Pi 'm1 (expr-Nat) (expr-Nat))))
     (parameterize ([current-structural-meta-lookup (make-test-meta-lookup (hash))]
                    [current-lattice-meta-solution-fn unsolved-meta-solution-fn])
       (define-values (enet5 _pid) (elab-add-unify-constraint enet4 cell-a cell-b))
       (solve-expect-error enet5)))

   (test-case "Pi(Nat,Bool) vs bot → bot cell gets Pi value"
     (define enet0 (make-elaboration-network))
     (define-values (enet1 cell-a) (elab-fresh-meta enet0 '() #f "cell-a"))
     (define-values (enet2 cell-b) (elab-fresh-meta enet1 '() #f "cell-b"))
     (define pi-val (expr-Pi 'm1 (expr-Nat) (expr-Bool)))
     (define enet3 (elab-cell-write enet2 cell-a pi-val))
     ;; cell-b stays at bot
     (parameterize ([current-structural-meta-lookup (make-test-meta-lookup (hash))]
                    [current-lattice-meta-solution-fn unsolved-meta-solution-fn])
       (define-values (enet4 _pid) (elab-add-unify-constraint enet3 cell-a cell-b))
       (define enet5 (solve-ok enet4))
       (check-equal? (elab-cell-read enet5 cell-b) pi-val)))))

;; ========================================
;; Pi Decomposition: Meta Components
;; ========================================

(define pi-meta-tests
  (test-suite
   "Pi decomposition: meta components"

   (test-case "Pi(Nat, ?M) = Pi(Nat, Bool) → ?M solved to Bool"
     (define enet0 (make-elaboration-network))
     ;; Create meta cell for ?M
     (define-values (enet1 meta-M-cell) (elab-fresh-meta enet0 '() #f "meta-M"))
     (define M-id (cell-id-n meta-M-cell))
     ;; Create constraint cells
     (define-values (enet2 cell-a) (elab-fresh-meta enet1 '() #f "cell-a"))
     (define-values (enet3 cell-b) (elab-fresh-meta enet2 '() #f "cell-b"))
     ;; Write compound types
     (define enet4 (elab-cell-write enet3 cell-a (expr-Pi 'm1 (expr-Nat) (expr-meta M-id))))
     (define enet5 (elab-cell-write enet4 cell-b (expr-Pi 'm1 (expr-Nat) (expr-Bool))))
     (parameterize ([current-structural-meta-lookup
                     (make-test-meta-lookup (hash M-id meta-M-cell))]
                    [current-lattice-meta-solution-fn unsolved-meta-solution-fn])
       (define-values (enet6 _pid) (elab-add-unify-constraint enet5 cell-a cell-b))
       (define enet7 (solve-ok enet6))
       ;; ?M's cell should be solved to Bool
       (check-equal? (elab-cell-read enet7 meta-M-cell) (expr-Bool))))

   (test-case "Pi(?N, Bool) = Pi(Nat, ?M) → both metas solved"
     (define enet0 (make-elaboration-network))
     (define-values (enet1 meta-M-cell) (elab-fresh-meta enet0 '() #f "meta-M"))
     (define-values (enet2 meta-N-cell) (elab-fresh-meta enet1 '() #f "meta-N"))
     (define M-id (cell-id-n meta-M-cell))
     (define N-id (cell-id-n meta-N-cell))
     (define-values (enet3 cell-a) (elab-fresh-meta enet2 '() #f "cell-a"))
     (define-values (enet4 cell-b) (elab-fresh-meta enet3 '() #f "cell-b"))
     (define enet5 (elab-cell-write enet4 cell-a
                     (expr-Pi 'm1 (expr-meta N-id) (expr-Bool))))
     (define enet6 (elab-cell-write enet5 cell-b
                     (expr-Pi 'm1 (expr-Nat) (expr-meta M-id))))
     (parameterize ([current-structural-meta-lookup
                     (make-test-meta-lookup (hash M-id meta-M-cell
                                                  N-id meta-N-cell))]
                    [current-lattice-meta-solution-fn unsolved-meta-solution-fn])
       (define-values (enet7 _pid) (elab-add-unify-constraint enet6 cell-a cell-b))
       (define enet8 (solve-ok enet7))
       (check-equal? (elab-cell-read enet8 meta-N-cell) (expr-Nat))
       (check-equal? (elab-cell-read enet8 meta-M-cell) (expr-Bool))))

   (test-case "Pi(?N, ?M) = Pi(Nat, Bool) → both metas solved"
     (define enet0 (make-elaboration-network))
     (define-values (enet1 meta-M-cell) (elab-fresh-meta enet0 '() #f "meta-M"))
     (define-values (enet2 meta-N-cell) (elab-fresh-meta enet1 '() #f "meta-N"))
     (define M-id (cell-id-n meta-M-cell))
     (define N-id (cell-id-n meta-N-cell))
     (define-values (enet3 cell-a) (elab-fresh-meta enet2 '() #f "cell-a"))
     (define-values (enet4 cell-b) (elab-fresh-meta enet3 '() #f "cell-b"))
     (define enet5 (elab-cell-write enet4 cell-a
                     (expr-Pi 'm1 (expr-meta N-id) (expr-meta M-id))))
     (define enet6 (elab-cell-write enet5 cell-b
                     (expr-Pi 'm1 (expr-Nat) (expr-Bool))))
     (parameterize ([current-structural-meta-lookup
                     (make-test-meta-lookup (hash M-id meta-M-cell
                                                  N-id meta-N-cell))]
                    [current-lattice-meta-solution-fn unsolved-meta-solution-fn])
       (define-values (enet7 _pid) (elab-add-unify-constraint enet6 cell-a cell-b))
       (define enet8 (solve-ok enet7))
       (check-equal? (elab-cell-read enet8 meta-N-cell) (expr-Nat))
       (check-equal? (elab-cell-read enet8 meta-M-cell) (expr-Bool))))

   (test-case "Pi(Nat, ?M) vs bot → decompose, ?M stays bot"
     ;; When one side is bot and the other has metas, decompose but don't solve
     (define enet0 (make-elaboration-network))
     (define-values (enet1 meta-M-cell) (elab-fresh-meta enet0 '() #f "meta-M"))
     (define M-id (cell-id-n meta-M-cell))
     (define-values (enet2 cell-a) (elab-fresh-meta enet1 '() #f "cell-a"))
     (define-values (enet3 cell-b) (elab-fresh-meta enet2 '() #f "cell-b"))
     (define enet4 (elab-cell-write enet3 cell-a
                     (expr-Pi 'm1 (expr-Nat) (expr-meta M-id))))
     ;; cell-b stays bot
     (parameterize ([current-structural-meta-lookup
                     (make-test-meta-lookup (hash M-id meta-M-cell))]
                    [current-lattice-meta-solution-fn unsolved-meta-solution-fn])
       (define-values (enet5 _pid) (elab-add-unify-constraint enet4 cell-a cell-b))
       (define enet6 (solve-ok enet5))
       ;; cell-b got the Pi value from cell-a
       (check-equal? (elab-cell-read enet6 cell-b)
                     (expr-Pi 'm1 (expr-Nat) (expr-meta M-id)))
       ;; ?M is still unsolved (no contradicting info)
       (check-true (type-bot? (elab-cell-read enet6 meta-M-cell)))))))

;; ========================================
;; Three-Way Pi Chain (Transitive Resolution)
;; ========================================

(define pi-chain-tests
  (test-suite
   "Three-way Pi chain: transitive resolution"

   (test-case "A=B, B=C: domain enters A, codomain enters C → metas resolved"
     ;; Cell A: Pi(m1, Nat, ?M)    — domain known
     ;; Cell B: Pi(m1, ?N, ?K)     — completely unknown
     ;; Cell C: Pi(m1, ?P, Bool)   — codomain known
     ;; Constraints: A=B, B=C
     ;; Expected: ?N=Nat, ?K=Bool, ?M=Bool, ?P=Nat
     (define enet0 (make-elaboration-network))
     (define-values (enet1 meta-M) (elab-fresh-meta enet0 '() #f "M"))
     (define-values (enet2 meta-N) (elab-fresh-meta enet1 '() #f "N"))
     (define-values (enet3 meta-K) (elab-fresh-meta enet2 '() #f "K"))
     (define-values (enet4 meta-P) (elab-fresh-meta enet3 '() #f "P"))
     (define M-id (cell-id-n meta-M))
     (define N-id (cell-id-n meta-N))
     (define K-id (cell-id-n meta-K))
     (define P-id (cell-id-n meta-P))
     (define-values (enet5 cell-a) (elab-fresh-meta enet4 '() #f "cell-a"))
     (define-values (enet6 cell-b) (elab-fresh-meta enet5 '() #f "cell-b"))
     (define-values (enet7 cell-c) (elab-fresh-meta enet6 '() #f "cell-c"))
     ;; Write compound types
     (define enet8 (elab-cell-write enet7 cell-a
                     (expr-Pi 'm1 (expr-Nat) (expr-meta M-id))))
     (define enet9 (elab-cell-write enet8 cell-b
                     (expr-Pi 'm1 (expr-meta N-id) (expr-meta K-id))))
     (define enet10 (elab-cell-write enet9 cell-c
                      (expr-Pi 'm1 (expr-meta P-id) (expr-Bool))))
     (parameterize ([current-structural-meta-lookup
                     (make-test-meta-lookup
                       (hash M-id meta-M N-id meta-N K-id meta-K P-id meta-P))]
                    [current-lattice-meta-solution-fn unsolved-meta-solution-fn])
       ;; Add constraints A=B, B=C
       (define-values (enet11 _p1) (elab-add-unify-constraint enet10 cell-a cell-b))
       (define-values (enet12 _p2) (elab-add-unify-constraint enet11 cell-b cell-c))
       (define enet13 (solve-ok enet12))
       ;; All metas should be solved through sub-cell propagation
       (check-equal? (elab-cell-read enet13 meta-N) (expr-Nat)
                     "?N should be Nat (from cell-a's domain)")
       (check-equal? (elab-cell-read enet13 meta-K) (expr-Bool)
                     "?K should be Bool (from cell-c's codomain)")
       (check-equal? (elab-cell-read enet13 meta-M) (expr-Bool)
                     "?M should be Bool (from cell-c's codomain)")
       (check-equal? (elab-cell-read enet13 meta-P) (expr-Nat)
                     "?P should be Nat (from cell-a's domain)")))))

;; ========================================
;; App Decomposition
;; ========================================

(define app-tests
  (test-suite
   "App decomposition"

   (test-case "app(f, Nat) = app(f, Nat) → ground match"
     (define enet0 (make-elaboration-network))
     (define-values (enet1 cell-a) (elab-fresh-meta enet0 '() #f "cell-a"))
     (define-values (enet2 cell-b) (elab-fresh-meta enet1 '() #f "cell-b"))
     (define app-val (expr-app (expr-fvar 'f) (expr-Nat)))
     (define enet3 (elab-cell-write enet2 cell-a app-val))
     (define enet4 (elab-cell-write enet3 cell-b app-val))
     (parameterize ([current-structural-meta-lookup (make-test-meta-lookup (hash))]
                    [current-lattice-meta-solution-fn unsolved-meta-solution-fn])
       (define-values (enet5 _pid) (elab-add-unify-constraint enet4 cell-a cell-b))
       (define enet6 (solve-ok enet5))
       (check-equal? (elab-cell-read enet6 cell-a) app-val)
       (check-equal? (elab-cell-read enet6 cell-b) app-val)))

   (test-case "app(?F, Nat) = app(g, ?A) → metas solved"
     (define enet0 (make-elaboration-network))
     (define-values (enet1 meta-F) (elab-fresh-meta enet0 '() #f "F"))
     (define-values (enet2 meta-A) (elab-fresh-meta enet1 '() #f "A"))
     (define F-id (cell-id-n meta-F))
     (define A-id (cell-id-n meta-A))
     (define-values (enet3 cell-a) (elab-fresh-meta enet2 '() #f "cell-a"))
     (define-values (enet4 cell-b) (elab-fresh-meta enet3 '() #f "cell-b"))
     (define enet5 (elab-cell-write enet4 cell-a
                     (expr-app (expr-meta F-id) (expr-Nat))))
     (define enet6 (elab-cell-write enet5 cell-b
                     (expr-app (expr-fvar 'g) (expr-meta A-id))))
     (parameterize ([current-structural-meta-lookup
                     (make-test-meta-lookup (hash F-id meta-F A-id meta-A))]
                    [current-lattice-meta-solution-fn unsolved-meta-solution-fn])
       (define-values (enet7 _pid) (elab-add-unify-constraint enet6 cell-a cell-b))
       (define enet8 (solve-ok enet7))
       (check-equal? (elab-cell-read enet8 meta-F) (expr-fvar 'g))
       (check-equal? (elab-cell-read enet8 meta-A) (expr-Nat))))

   (test-case "app(f, Nat) vs app(f, Bool) → contradiction"
     (define enet0 (make-elaboration-network))
     (define-values (enet1 cell-a) (elab-fresh-meta enet0 '() #f "cell-a"))
     (define-values (enet2 cell-b) (elab-fresh-meta enet1 '() #f "cell-b"))
     (define enet3 (elab-cell-write enet2 cell-a
                     (expr-app (expr-fvar 'f) (expr-Nat))))
     (define enet4 (elab-cell-write enet3 cell-b
                     (expr-app (expr-fvar 'f) (expr-Bool))))
     (parameterize ([current-structural-meta-lookup (make-test-meta-lookup (hash))]
                    [current-lattice-meta-solution-fn unsolved-meta-solution-fn])
       (define-values (enet5 _pid) (elab-add-unify-constraint enet4 cell-a cell-b))
       (solve-expect-error enet5)))))

;; ========================================
;; Mixed: Pi with App in Domain
;; ========================================

(define mixed-tests
  (test-suite
   "Mixed decomposition: Pi with app in domain"

   (test-case "Pi(app(f,Nat), Bool) = Pi(app(f,?A), ?M) → nested resolution"
     (define enet0 (make-elaboration-network))
     (define-values (enet1 meta-A) (elab-fresh-meta enet0 '() #f "A"))
     (define-values (enet2 meta-M) (elab-fresh-meta enet1 '() #f "M"))
     (define A-id (cell-id-n meta-A))
     (define M-id (cell-id-n meta-M))
     (define-values (enet3 cell-a) (elab-fresh-meta enet2 '() #f "cell-a"))
     (define-values (enet4 cell-b) (elab-fresh-meta enet3 '() #f "cell-b"))
     (define enet5 (elab-cell-write enet4 cell-a
                     (expr-Pi 'm1 (expr-app (expr-fvar 'f) (expr-Nat)) (expr-Bool))))
     (define enet6 (elab-cell-write enet5 cell-b
                     (expr-Pi 'm1 (expr-app (expr-fvar 'f) (expr-meta A-id)) (expr-meta M-id))))
     (parameterize ([current-structural-meta-lookup
                     (make-test-meta-lookup (hash A-id meta-A M-id meta-M))]
                    [current-lattice-meta-solution-fn unsolved-meta-solution-fn])
       (define-values (enet7 _pid) (elab-add-unify-constraint enet6 cell-a cell-b))
       (define enet8 (solve-ok enet7))
       ;; ?A should be Nat (from domain's arg position via nested app decomp)
       (check-equal? (elab-cell-read enet8 meta-A) (expr-Nat))
       ;; ?M should be Bool (from codomain position)
       (check-equal? (elab-cell-read enet8 meta-M) (expr-Bool))))))

;; ========================================
;; Registry Behavior
;; ========================================

(define registry-tests
  (test-suite
   "Registry behavior"

   (test-case "Duplicate constraint on same pair → no duplicate decomposition"
     ;; Adding the same unify constraint twice should not create duplicate sub-cells
     (define enet0 (make-elaboration-network))
     (define-values (enet1 meta-M) (elab-fresh-meta enet0 '() #f "M"))
     (define M-id (cell-id-n meta-M))
     (define-values (enet2 cell-a) (elab-fresh-meta enet1 '() #f "cell-a"))
     (define-values (enet3 cell-b) (elab-fresh-meta enet2 '() #f "cell-b"))
     (define enet4 (elab-cell-write enet3 cell-a
                     (expr-Pi 'm1 (expr-Nat) (expr-meta M-id))))
     (define enet5 (elab-cell-write enet4 cell-b
                     (expr-Pi 'm1 (expr-Nat) (expr-Bool))))
     (parameterize ([current-structural-meta-lookup
                     (make-test-meta-lookup (hash M-id meta-M))]
                    [current-lattice-meta-solution-fn unsolved-meta-solution-fn])
       (define-values (enet6 _p1) (elab-add-unify-constraint enet5 cell-a cell-b))
       ;; Add same constraint again (different propagator, but same pair)
       (define-values (enet7 _p2) (elab-add-unify-constraint enet6 cell-a cell-b))
       ;; Should still solve correctly — decomposition deduped by pair-decomps registry
       (define enet8 (solve-ok enet7))
       (check-equal? (elab-cell-read enet8 meta-M) (expr-Bool))))

   (test-case "Cell reuse across constraints"
     ;; Cell A constrained with B AND C; sub-cells from A should be reused
     (define enet0 (make-elaboration-network))
     (define-values (enet1 meta-M) (elab-fresh-meta enet0 '() #f "M"))
     (define-values (enet2 meta-N) (elab-fresh-meta enet1 '() #f "N"))
     (define M-id (cell-id-n meta-M))
     (define N-id (cell-id-n meta-N))
     (define-values (enet3 cell-a) (elab-fresh-meta enet2 '() #f "cell-a"))
     (define-values (enet4 cell-b) (elab-fresh-meta enet3 '() #f "cell-b"))
     (define-values (enet5 cell-c) (elab-fresh-meta enet4 '() #f "cell-c"))
     ;; cell-a: Pi(m1, Nat, ?M)
     ;; cell-b: Pi(m1, ?N, Bool)
     ;; cell-c: Pi(m1, Nat, Bool)
     (define enet6 (elab-cell-write enet5 cell-a
                     (expr-Pi 'm1 (expr-Nat) (expr-meta M-id))))
     (define enet7 (elab-cell-write enet6 cell-b
                     (expr-Pi 'm1 (expr-meta N-id) (expr-Bool))))
     (define enet8 (elab-cell-write enet7 cell-c
                     (expr-Pi 'm1 (expr-Nat) (expr-Bool))))
     (parameterize ([current-structural-meta-lookup
                     (make-test-meta-lookup (hash M-id meta-M N-id meta-N))]
                    [current-lattice-meta-solution-fn unsolved-meta-solution-fn])
       ;; Constrain A=B and A=C
       (define-values (enet9 _p1) (elab-add-unify-constraint enet8 cell-a cell-b))
       (define-values (enet10 _p2) (elab-add-unify-constraint enet9 cell-a cell-c))
       (define enet11 (solve-ok enet10))
       ;; Both metas solved
       (check-equal? (elab-cell-read enet11 meta-M) (expr-Bool))
       (check-equal? (elab-cell-read enet11 meta-N) (expr-Nat))))))

;; ========================================
;; Dependent Codomain (bvar)
;; ========================================

(define dependent-tests
  (test-suite
   "Dependent codomain with bvar"

   (test-case "Pi(m1, Nat, bvar(0)) = Pi(m1, Nat, bvar(0)) → ok"
     ;; Dependent return type (identity pattern): codomains match structurally
     (define enet0 (make-elaboration-network))
     (define-values (enet1 cell-a) (elab-fresh-meta enet0 '() #f "cell-a"))
     (define-values (enet2 cell-b) (elab-fresh-meta enet1 '() #f "cell-b"))
     (define pi-dep (expr-Pi 'm1 (expr-Nat) (expr-bvar 0)))
     (define enet3 (elab-cell-write enet2 cell-a pi-dep))
     (define enet4 (elab-cell-write enet3 cell-b pi-dep))
     (parameterize ([current-structural-meta-lookup (make-test-meta-lookup (hash))]
                    [current-lattice-meta-solution-fn unsolved-meta-solution-fn])
       (define-values (enet5 _pid) (elab-add-unify-constraint enet4 cell-a cell-b))
       (define enet6 (solve-ok enet5))
       (check-equal? (elab-cell-read enet6 cell-a) pi-dep)
       (check-equal? (elab-cell-read enet6 cell-b) pi-dep)))

   (test-case "Pi(m1, Nat, bvar(0)) vs Pi(m1, Nat, Bool) → contradiction"
     ;; Dependent vs non-dependent codomain: structurally different
     (define enet0 (make-elaboration-network))
     (define-values (enet1 cell-a) (elab-fresh-meta enet0 '() #f "cell-a"))
     (define-values (enet2 cell-b) (elab-fresh-meta enet1 '() #f "cell-b"))
     (define enet3 (elab-cell-write enet2 cell-a (expr-Pi 'm1 (expr-Nat) (expr-bvar 0))))
     (define enet4 (elab-cell-write enet3 cell-b (expr-Pi 'm1 (expr-Nat) (expr-Bool))))
     (parameterize ([current-structural-meta-lookup (make-test-meta-lookup (hash))]
                    [current-lattice-meta-solution-fn unsolved-meta-solution-fn])
       (define-values (enet5 _pid) (elab-add-unify-constraint enet4 cell-a cell-b))
       (solve-expect-error enet5)))))

;; ========================================
;; Contradiction Propagation from Sub-Cells
;; ========================================

(define contradiction-tests
  (test-suite
   "Contradiction propagation from sub-cells"

   (test-case "Pi(Nat, ?M): ?M pre-solved to Bool, constrained with Pi(Nat, Nat) → contradiction"
     ;; Pre-solve ?M to Bool, then constrain with Pi(Nat, Nat)
     ;; The sub-cell for ?M (= Bool) vs Nat sub-cell → contradiction
     (define enet0 (make-elaboration-network))
     (define-values (enet1 meta-M) (elab-fresh-meta enet0 '() #f "M"))
     (define M-id (cell-id-n meta-M))
     ;; Pre-solve ?M to Bool
     (define enet2 (elab-cell-write enet1 meta-M (expr-Bool)))
     (define-values (enet3 cell-a) (elab-fresh-meta enet2 '() #f "cell-a"))
     (define-values (enet4 cell-b) (elab-fresh-meta enet3 '() #f "cell-b"))
     (define enet5 (elab-cell-write enet4 cell-a
                     (expr-Pi 'm1 (expr-Nat) (expr-meta M-id))))
     (define enet6 (elab-cell-write enet5 cell-b
                     (expr-Pi 'm1 (expr-Nat) (expr-Nat))))
     (parameterize ([current-structural-meta-lookup
                     (make-test-meta-lookup (hash M-id meta-M))]
                    [current-lattice-meta-solution-fn unsolved-meta-solution-fn])
       (define-values (enet7 _pid) (elab-add-unify-constraint enet6 cell-a cell-b))
       ;; ?M cell holds Bool; sub-propagator unifies Bool with Nat → contradiction
       (solve-expect-error enet7)))))

;; ========================================
;; Reconstructor Tests
;; ========================================

(define reconstructor-tests
  (test-suite
   "Reconstructor propagators"

   (test-case "Sub-cells solved → meta cells hold concrete values"
     ;; Main assertion: meta CELLS are solved. Parent cells may still have
     ;; meta references (resolved during zonking, not by propagation).
     (define enet0 (make-elaboration-network))
     (define-values (enet1 meta-M) (elab-fresh-meta enet0 '() #f "M"))
     (define-values (enet2 meta-N) (elab-fresh-meta enet1 '() #f "N"))
     (define M-id (cell-id-n meta-M))
     (define N-id (cell-id-n meta-N))
     (define-values (enet3 cell-a) (elab-fresh-meta enet2 '() #f "cell-a"))
     (define-values (enet4 cell-b) (elab-fresh-meta enet3 '() #f "cell-b"))
     ;; Cell A: Pi(m1, ?N, ?M), Cell B: Pi(m1, Nat, Bool)
     (define enet5 (elab-cell-write enet4 cell-a
                     (expr-Pi 'm1 (expr-meta N-id) (expr-meta M-id))))
     (define enet6 (elab-cell-write enet5 cell-b
                     (expr-Pi 'm1 (expr-Nat) (expr-Bool))))
     (parameterize ([current-structural-meta-lookup
                     (make-test-meta-lookup (hash M-id meta-M N-id meta-N))]
                    [current-lattice-meta-solution-fn unsolved-meta-solution-fn])
       (define-values (enet7 _pid) (elab-add-unify-constraint enet6 cell-a cell-b))
       (define enet8 (solve-ok enet7))
       ;; Meta cells are solved to concrete values
       (check-equal? (elab-cell-read enet8 meta-N) (expr-Nat))
       (check-equal? (elab-cell-read enet8 meta-M) (expr-Bool))
       ;; Cell B (ground) stays at its original value
       (check-equal? (elab-cell-read enet8 cell-b)
                     (expr-Pi 'm1 (expr-Nat) (expr-Bool)))))))

;; ========================================
;; Fast Path Refinement Tests
;; ========================================

(define fast-path-tests
  (test-suite
   "Fast path: ground-only optimization"

   (test-case "Both fully ground → fast path (no propagator created)"
     ;; Ground Pi = Ground Pi: fast path merges eagerly
     (define enet0 (make-elaboration-network))
     (define-values (enet1 cell-a) (elab-fresh-meta enet0 '() #f "cell-a"))
     (define-values (enet2 cell-b) (elab-fresh-meta enet1 '() #f "cell-b"))
     (define pi-val (expr-Pi 'm1 (expr-Nat) (expr-Bool)))
     (define enet3 (elab-cell-write enet2 cell-a pi-val))
     (define enet4 (elab-cell-write enet3 cell-b pi-val))
     (parameterize ([current-structural-meta-lookup (make-test-meta-lookup (hash))]
                    [current-lattice-meta-solution-fn unsolved-meta-solution-fn])
       (define-values (enet5 pid) (elab-add-unify-constraint enet4 cell-a cell-b))
       ;; Fast path returns #f for pid
       (check-false pid)
       (check-equal? (elab-cell-read enet5 cell-a) pi-val)
       (check-equal? (elab-cell-read enet5 cell-b) pi-val)))

   (test-case "Values with metas → slow path (propagator created)"
     ;; Pi with meta: should NOT use fast path, should create propagator
     (define enet0 (make-elaboration-network))
     (define-values (enet1 meta-M) (elab-fresh-meta enet0 '() #f "M"))
     (define M-id (cell-id-n meta-M))
     (define-values (enet2 cell-a) (elab-fresh-meta enet1 '() #f "cell-a"))
     (define-values (enet3 cell-b) (elab-fresh-meta enet2 '() #f "cell-b"))
     (define enet4 (elab-cell-write enet3 cell-a
                     (expr-Pi 'm1 (expr-Nat) (expr-meta M-id))))
     (define enet5 (elab-cell-write enet4 cell-b
                     (expr-Pi 'm1 (expr-Nat) (expr-Bool))))
     (parameterize ([current-structural-meta-lookup
                     (make-test-meta-lookup (hash M-id meta-M))]
                    [current-lattice-meta-solution-fn unsolved-meta-solution-fn])
       (define-values (enet6 pid) (elab-add-unify-constraint enet5 cell-a cell-b))
       ;; Slow path: propagator created
       (check-not-false pid)))))

;; ========================================
;; Run All
;; ========================================

(run-tests
 (test-suite
  "Phase 4c-b: Structural Decomposition"
  tag-tests
  pi-ground-tests
  pi-meta-tests
  pi-chain-tests
  app-tests
  mixed-tests
  registry-tests
  dependent-tests
  contradiction-tests
  reconstructor-tests
  fast-path-tests)
 'verbose)
