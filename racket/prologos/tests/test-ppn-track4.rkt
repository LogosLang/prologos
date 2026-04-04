#lang racket/base

;;; test-ppn-track4.rkt — PPN Track 4: Elaboration as Attribute Evaluation
;;;
;;; Tests for Track 4 propagator-native infrastructure.
;;; D.4 redo: tests verify actual propagator firings on the network,
;;; not function-call dispatch.

(require rackunit
         rackunit/text-ui
         racket/set
         prologos/propagator
         prologos/champ
         prologos/typing-propagators
         prologos/syntax
         prologos/prelude
         prologos/type-lattice
         prologos/surface-rewrite)

;; ============================================================
;; Phase 1a: Component-indexed propagator firing
;; ============================================================

(define phase-1a-tests
  (test-suite
   "Phase 1a: component-indexed propagator firing"

   (test-case "pu-value-diff: identical hasheqs → empty diff"
     (define m (hasheq 'a 1 'b 2))
     (check-equal? (pu-value-diff m m) '()))

   (test-case "pu-value-diff: one key changed"
     (define old (hasheq 'a 1 'b 2 'c 3))
     (define new (hasheq 'a 1 'b 99 'c 3))
     (define diff (pu-value-diff old new))
     (check-equal? (sort diff symbol<?) '(b)))

   (test-case "pu-value-diff: non-hash values → #f (all changed)"
     (check-false (pu-value-diff 42 43)))

   (test-case "component-indexed propagator: only fires on watched component"
     (define fire-count (box 0))
     (define net0 (make-prop-network))
     (define-values (net1 cid)
       (net-new-cell net0 (hasheq 'a 0 'b 0)
                     (lambda (old new)
                       (for/hasheq ([(k v) (in-hash new)])
                         (values k (max v (hash-ref old k 0)))))))
     (define-values (net2 pid)
       (net-add-propagator net1
                           (list cid) '()
                           (lambda (net)
                             (set-box! fire-count (add1 (unbox fire-count)))
                             net)
                           #:component-paths (list (cons cid 'a))))
     (define net2q (run-to-quiescence net2))
     (set-box! fire-count 0)
     ;; Write to 'b — propagator watching 'a should NOT fire
     (define net3 (run-to-quiescence
                   (net-cell-write net2q cid (hasheq 'a 0 'b 99))))
     (check-equal? (unbox fire-count) 0)
     ;; Write to 'a — propagator SHOULD fire
     (set-box! fire-count 0)
     (define net4 (run-to-quiescence
                   (net-cell-write net3 cid (hasheq 'a 42 'b 99))))
     (check-equal? (unbox fire-count) 1))
   ))

;; ============================================================
;; Phase 1c: Context lattice
;; ============================================================

(define phase-1c-tests
  (test-suite
   "Phase 1c: context lattice"

   (test-case "context-empty-value is empty"
     (check-equal? (context-cell-value-bindings context-empty-value) '())
     (check-equal? (context-cell-value-depth context-empty-value) 0))

   (test-case "context-extend-value adds binding"
     (define ctx1 (context-extend-value context-empty-value (expr-Nat) 'mw))
     (check-equal? (context-cell-value-depth ctx1) 1))

   (test-case "context-lookup-type: de Bruijn indexing"
     (define ctx (context-extend-value
                  (context-extend-value context-empty-value (expr-Nat) 'mw)
                  (expr-Int) 'm1))
     (check-equal? (context-lookup-type ctx 0) (expr-Int))
     (check-equal? (context-lookup-type ctx 1) (expr-Nat))
     (check-pred expr-error? (context-lookup-type ctx 2)))
   ))

;; ============================================================
;; Phase 2 (D.4): Propagator-native typing — Network Reality Check
;; ============================================================

(define phase-2-network-tests
  (test-suite
   "Phase 2 D.4: propagator-native typing on the network"

   (test-case "literal propagator: writes type to type-map via net-cell-write"
     ;; Create a network with a typing cell (plain hasheq)
     (define net0 (make-prop-network))
     (define-values (net1 tm-cid)
       (net-new-cell net0 (hasheq) type-map-merge-fn))
     ;; Install a literal propagator for an int expression
     (define int-expr (expr-int 42))
     (define-values (net2 _pid)
       (net-add-propagator net1 (list tm-cid) (list tm-cid)
                           (make-literal-fire-fn tm-cid int-expr (expr-Int))))
     ;; Run to quiescence — propagator fires and writes Int to type-map
     (define net3 (run-to-quiescence net2))
     ;; Read result from the type-map cell
     (define tm (net-cell-read net3 tm-cid))
     (define result-type (hash-ref tm int-expr type-bot))
     ;; Network Reality Check: result comes from cell read after propagator firing
     (check-equal? result-type (expr-Int)))

   (test-case "universe propagator: Type(0) → Type(1)"
     (define net0 (make-prop-network))
     (define-values (net1 tm-cid)
       (net-new-cell net0 (hasheq) type-map-merge-fn))
     (define type-expr (expr-Type (lzero)))
     (define-values (net2 _pid)
       (net-add-propagator net1 (list tm-cid) (list tm-cid)
                           (make-universe-fire-fn tm-cid type-expr (lzero))))
     (define net3 (run-to-quiescence net2))
     (define tm (net-cell-read net3 tm-cid))
     (check-equal? (hash-ref tm type-expr type-bot) (expr-Type (lsuc (lzero)))))

   (test-case "app propagator: tensor fires when func + arg types available"
     (define net0 (make-prop-network))
     (define func-e (expr-fvar 'f))
     (define arg-e (expr-int 42))
     (define app-e (expr-app func-e arg-e))
     ;; Create typing cell pre-populated with func and arg types
     (define-values (net1 tm-cid)
       (net-new-cell net0
                     (hasheq func-e (expr-Pi 'mw (expr-Int) (expr-Bool))
                             arg-e (expr-Int))
                     type-map-merge-fn))
     ;; Install app propagator
     (define-values (net2 _pid)
       (net-add-propagator net1 (list tm-cid) (list tm-cid)
                           (make-app-fire-fn tm-cid app-e func-e arg-e)
                           #:component-paths
                           (list (cons tm-cid func-e)
                                 (cons tm-cid arg-e))))
     (define net3 (run-to-quiescence net2))
     (define tm (net-cell-read net3 tm-cid))
     ;; tensor(Pi(mw, Int, Bool), Int) = Bool (via subst)
     (check-equal? (hash-ref tm app-e type-bot) (expr-Bool)))

   (test-case "infer-on-network: literal expression"
     (define net0 (make-prop-network))
     (define e (expr-int 42))
     (define-values (net1 result-type)
       (infer-on-network net0 e context-empty-value))
     ;; Network Reality Check: result comes from cell read after quiescence
     (check-equal? result-type (expr-Int)))

   (test-case "infer-on-network: Type(0) → Type(1)"
     (define net0 (make-prop-network))
     (define-values (net1 result-type)
       (infer-on-network net0 (expr-Type (lzero)) context-empty-value))
     (check-equal? result-type (expr-Type (lsuc (lzero)))))

   (test-case "app propagator: fires after both inputs written"
     ;; Test the app propagator in isolation with manual writes
     (define net0 (make-prop-network))
     (define func-e (expr-fvar 'f))
     (define arg-e (expr-int 1))
     (define app-e (expr-app func-e arg-e))
     ;; Create typing cell
     (define-values (net1 tm-cid)
       (net-new-cell net0 (hasheq) type-map-merge-fn))
     ;; Install ONLY the app propagator (not sub-expression propagators)
     (define-values (net2 _pid)
       (net-add-propagator net1 (list tm-cid) (list tm-cid)
                           (make-app-fire-fn tm-cid app-e func-e arg-e)
                           #:component-paths
                           (list (cons tm-cid func-e)
                                 (cons tm-cid arg-e))))
     ;; Drain initial fire (inputs are ⊥, propagator is a no-op)
     (define net2q (run-to-quiescence net2))
     ;; Write func type
     (define net3 (net-cell-write net2q tm-cid
                    (hasheq func-e (expr-Pi 'mw (expr-Int) (expr-Int)))))
     ;; Write arg type — this should trigger the app propagator
     (define net4 (net-cell-write net3 tm-cid (hasheq arg-e (expr-Int))))
     (define net5 (run-to-quiescence net4))
     (define tm (net-cell-read net5 tm-cid))
     ;; tensor(Pi(mw,Int,Int), Int) = Int
     (check-equal? (hash-ref tm app-e type-bot) (expr-Int)))
   ))

;; ============================================================
;; Phase 4b-i: Fan-in meta-readiness
;; ============================================================

(define phase-4b-tests
  (test-suite
   "Phase 4b-i: fan-in meta-readiness"

   (test-case "empty readiness: all solved"
     (check-true (meta-readiness-all-solved? meta-readiness-empty)))

   (test-case "register + solve: tracks correctly"
     (define rv (meta-readiness-register
                 (meta-readiness-register meta-readiness-empty 'a 'type)
                 'b 'level))
     (check-false (meta-readiness-all-solved? rv))
     (define rv2 (meta-readiness-solve (meta-readiness-solve rv 'a) 'b))
     (check-true (meta-readiness-all-solved? rv2)))

   (test-case "merge: set-union on registered and solved"
     (define rv1 (meta-readiness-solve
                  (meta-readiness-register meta-readiness-empty 'a 'type) 'a))
     (define rv2 (meta-readiness-register meta-readiness-empty 'b 'level))
     (define merged (meta-readiness-merge rv1 rv2))
     (check-equal? (length (meta-readiness-unsolved merged)) 1))
   ))

;; ============================================================
;; Phase 6: Constraint lattice
;; ============================================================

(define phase-6-tests
  (test-suite
   "Phase 6: constraint lattice"

   (test-case "join: pending ⊔ resolved = resolved"
     (define r (constraint-resolved 'eq-int))
     (check-true (constraint-resolved? (constraint-cell-merge constraint-pending r))))

   (test-case "join: resolved(A) ⊔ resolved(B) = contradicted"
     (check-true (constraint-contradicted?
                  (constraint-cell-merge (constraint-resolved 'a) (constraint-resolved 'b)))))

   (test-case "meet: contradicted ⊓ X = X"
     (define r (constraint-resolved 'eq-int))
     (check-equal? (constraint-cell-meet constraint-contradicted r) r))
   ))

;; ============================================================
;; Run
;; ============================================================

(run-tests phase-1a-tests)
(run-tests phase-1c-tests)
(run-tests phase-2-network-tests)
(run-tests phase-4b-tests)
(run-tests phase-6-tests)
