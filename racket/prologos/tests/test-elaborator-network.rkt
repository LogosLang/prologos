#lang racket/base

;;;
;;; test-elaborator-network.rkt — Tests for the elaborator-network bridge
;;;
;;; Tests network creation, cell operations, unification propagators,
;;; solve/contradiction, and helper queries.
;;;

(require rackunit
         rackunit/text-ui
         "../syntax.rkt"
         "../type-lattice.rkt"
         "../propagator.rkt"
         "../elaborator-network.rkt")

;; ========================================
;; Network Creation
;; ========================================

(define creation-tests
  (test-suite
   "Network creation"

   (test-case "make-elaboration-network: creates empty"
     (define enet (make-elaboration-network))
     (check-true (elab-network? enet))
     (check-false (net-contradiction? (elab-network-prop-net enet)))
     (check-equal? (elab-all-cells enet) '()))

   (test-case "make-elaboration-network: custom fuel"
     (define enet (make-elaboration-network 500))
     (check-equal? (net-fuel-remaining (elab-network-prop-net enet)) 500))

   (test-case "elab-fresh-meta: allocates cell at bot"
     (define enet0 (make-elaboration-network))
     (define-values (enet1 cid) (elab-fresh-meta enet0 '() (expr-Nat) "test source"))
     ;; Cell reads as type-bot
     (check-true (type-bot? (elab-cell-read enet1 cid)))
     ;; Cell info is stored
     (define info (elab-cell-info-ref enet1 cid))
     (check-true (elab-cell-info? info))
     (check-equal? (elab-cell-info-ctx info) '())
     (check-equal? (elab-cell-info-type info) (expr-Nat))
     (check-equal? (elab-cell-info-source info) "test source"))))

;; ========================================
;; Cell Operations
;; ========================================

(define cell-ops-tests
  (test-suite
   "Cell operations"

   (test-case "elab-cell-write: write Nat to bot cell"
     (define enet0 (make-elaboration-network))
     (define-values (enet1 cid) (elab-fresh-meta enet0 '() (expr-Nat) "test"))
     (define enet2 (elab-cell-write enet1 cid (expr-Nat)))
     (check-equal? (elab-cell-read enet2 cid) (expr-Nat)))

   (test-case "elab-cell-write: idempotent"
     (define enet0 (make-elaboration-network))
     (define-values (enet1 cid) (elab-fresh-meta enet0 '() (expr-Nat) "test"))
     (define enet2 (elab-cell-write enet1 cid (expr-Nat)))
     (define enet3 (elab-cell-write enet2 cid (expr-Nat)))
     (check-equal? (elab-cell-read enet3 cid) (expr-Nat))
     (check-false (net-contradiction? (elab-network-prop-net enet3))))

   (test-case "elab-cell-write: contradictory values"
     (define enet0 (make-elaboration-network))
     (define-values (enet1 cid) (elab-fresh-meta enet0 '() (expr-Nat) "test"))
     (define enet2 (elab-cell-write enet1 cid (expr-Nat)))
     (define enet3 (elab-cell-write enet2 cid (expr-Bool)))
     (check-true (net-contradiction? (elab-network-prop-net enet3))))

   (test-case "elab-cell-info-ref: returns stored metadata"
     (define enet0 (make-elaboration-network))
     (define ctx (list (cons (expr-Nat) 'mw)))
     (define-values (enet1 cid)
       (elab-fresh-meta enet0 ctx (expr-Bool) "provenance-info"))
     (define info (elab-cell-info-ref enet1 cid))
     (check-equal? (elab-cell-info-ctx info) ctx)
     (check-equal? (elab-cell-info-type info) (expr-Bool))
     (check-equal? (elab-cell-info-source info) "provenance-info"))))

;; ========================================
;; Unification Propagator
;; ========================================

(define unify-propagator-tests
  (test-suite
   "Unification propagator"

   (test-case "unify bot-bot: no-op"
     (define enet0 (make-elaboration-network))
     (define-values (enet1 cid-a) (elab-fresh-meta enet0 '() (expr-Nat) "a"))
     (define-values (enet2 cid-b) (elab-fresh-meta enet1 '() (expr-Nat) "b"))
     (define-values (enet3 _pid) (elab-add-unify-constraint enet2 cid-a cid-b))
     (define-values (status enet4) (elab-solve enet3))
     (check-equal? status 'ok)
     ;; Both still bot — no information to propagate
     (check-true (type-bot? (elab-cell-read enet4 cid-a)))
     (check-true (type-bot? (elab-cell-read enet4 cid-b))))

   (test-case "unify bot-Nat: propagates Nat to bot cell"
     (define enet0 (make-elaboration-network))
     (define-values (enet1 cid-a) (elab-fresh-meta enet0 '() (expr-Nat) "a"))
     (define-values (enet2 cid-b) (elab-fresh-meta enet1 '() (expr-Nat) "b"))
     ;; Write Nat to cell-b before adding constraint
     (define enet3 (elab-cell-write enet2 cid-b (expr-Nat)))
     (define-values (enet4 _pid) (elab-add-unify-constraint enet3 cid-a cid-b))
     (define-values (status enet5) (elab-solve enet4))
     (check-equal? status 'ok)
     ;; Cell-a should now have Nat (propagated from cell-b)
     (check-equal? (elab-cell-read enet5 cid-a) (expr-Nat))
     (check-equal? (elab-cell-read enet5 cid-b) (expr-Nat)))

   (test-case "unify Nat-bot: symmetric propagation"
     (define enet0 (make-elaboration-network))
     (define-values (enet1 cid-a) (elab-fresh-meta enet0 '() (expr-Nat) "a"))
     (define-values (enet2 cid-b) (elab-fresh-meta enet1 '() (expr-Nat) "b"))
     ;; Write Nat to cell-a
     (define enet3 (elab-cell-write enet2 cid-a (expr-Nat)))
     (define-values (enet4 _pid) (elab-add-unify-constraint enet3 cid-a cid-b))
     (define-values (status enet5) (elab-solve enet4))
     (check-equal? status 'ok)
     ;; Cell-b should now have Nat (propagated from cell-a)
     (check-equal? (elab-cell-read enet5 cid-b) (expr-Nat)))

   (test-case "unify Nat-Nat: compatible"
     (define enet0 (make-elaboration-network))
     (define-values (enet1 cid-a) (elab-fresh-meta enet0 '() (expr-Nat) "a"))
     (define-values (enet2 cid-b) (elab-fresh-meta enet1 '() (expr-Nat) "b"))
     (define enet3 (elab-cell-write enet2 cid-a (expr-Nat)))
     (define enet4 (elab-cell-write enet3 cid-b (expr-Nat)))
     (define-values (enet5 _pid) (elab-add-unify-constraint enet4 cid-a cid-b))
     (define-values (status enet6) (elab-solve enet5))
     (check-equal? status 'ok)
     (check-equal? (elab-cell-read enet6 cid-a) (expr-Nat))
     (check-equal? (elab-cell-read enet6 cid-b) (expr-Nat)))

   (test-case "unify Nat-Bool: contradiction"
     (define enet0 (make-elaboration-network))
     (define-values (enet1 cid-a) (elab-fresh-meta enet0 '() (expr-Nat) "a"))
     (define-values (enet2 cid-b) (elab-fresh-meta enet1 '() (expr-Bool) "b"))
     (define enet3 (elab-cell-write enet2 cid-a (expr-Nat)))
     (define enet4 (elab-cell-write enet3 cid-b (expr-Bool)))
     (define-values (enet5 _pid) (elab-add-unify-constraint enet4 cid-a cid-b))
     (define-values (status result) (elab-solve enet5))
     (check-equal? status 'error)
     (check-true (contradiction-info? result))
     (check-true (cell-id? (contradiction-info-cell-id result))))

   (test-case "unify Pi types: structural"
     (define enet0 (make-elaboration-network))
     (define pi-type (expr-Pi 'mw (expr-Nat) (expr-Bool)))
     (define-values (enet1 cid-a) (elab-fresh-meta enet0 '() pi-type "a"))
     (define-values (enet2 cid-b) (elab-fresh-meta enet1 '() pi-type "b"))
     (define enet3 (elab-cell-write enet2 cid-a pi-type))
     (define enet4 (elab-cell-write enet3 cid-b pi-type))
     (define-values (enet5 _pid) (elab-add-unify-constraint enet4 cid-a cid-b))
     (define-values (status enet6) (elab-solve enet5))
     (check-equal? status 'ok)
     (check-true (expr-Pi? (elab-cell-read enet6 cid-a)))
     (check-true (expr-Pi? (elab-cell-read enet6 cid-b))))

   (test-case "transitive chain: A=B, B=C, write to A"
     (define enet0 (make-elaboration-network))
     (define-values (enet1 cid-a) (elab-fresh-meta enet0 '() (expr-Nat) "a"))
     (define-values (enet2 cid-b) (elab-fresh-meta enet1 '() (expr-Nat) "b"))
     (define-values (enet3 cid-c) (elab-fresh-meta enet2 '() (expr-Nat) "c"))
     ;; Add constraints: A=B, B=C
     (define-values (enet4 _p1) (elab-add-unify-constraint enet3 cid-a cid-b))
     (define-values (enet5 _p2) (elab-add-unify-constraint enet4 cid-b cid-c))
     ;; Write Nat to A
     (define enet6 (elab-cell-write enet5 cid-a (expr-Nat)))
     ;; Solve: Nat should propagate A→B→C
     (define-values (status enet7) (elab-solve enet6))
     (check-equal? status 'ok)
     (check-equal? (elab-cell-read enet7 cid-a) (expr-Nat))
     (check-equal? (elab-cell-read enet7 cid-b) (expr-Nat))
     (check-equal? (elab-cell-read enet7 cid-c) (expr-Nat)))))

;; ========================================
;; elab-solve
;; ========================================

(define solve-tests
  (test-suite
   "elab-solve"

   (test-case "elab-solve: quiescent ok"
     (define enet0 (make-elaboration-network))
     (define-values (enet1 cid) (elab-fresh-meta enet0 '() (expr-Nat) "test"))
     (define-values (status enet2) (elab-solve enet1))
     (check-equal? status 'ok))

   (test-case "elab-solve: contradiction error with info"
     (define enet0 (make-elaboration-network))
     (define-values (enet1 cid-a) (elab-fresh-meta enet0 '() (expr-Nat) "source-a"))
     (define-values (enet2 cid-b) (elab-fresh-meta enet1 '() (expr-Bool) "source-b"))
     (define enet3 (elab-cell-write enet2 cid-a (expr-Nat)))
     (define enet4 (elab-cell-write enet3 cid-b (expr-Bool)))
     (define-values (enet5 _pid) (elab-add-unify-constraint enet4 cid-a cid-b))
     (define-values (status result) (elab-solve enet5))
     (check-equal? status 'error)
     (check-true (contradiction-info? result))
     (check-true (type-top? (contradiction-info-value result))))

   (test-case "elab-solve: multi-cell chain solve"
     (define enet0 (make-elaboration-network))
     (define-values (enet1 cid-a) (elab-fresh-meta enet0 '() (expr-Int) "a"))
     (define-values (enet2 cid-b) (elab-fresh-meta enet1 '() (expr-Int) "b"))
     (define-values (enet3 cid-c) (elab-fresh-meta enet2 '() (expr-Int) "c"))
     ;; Chain: A=B, B=C
     (define-values (enet4 _p1) (elab-add-unify-constraint enet3 cid-a cid-b))
     (define-values (enet5 _p2) (elab-add-unify-constraint enet4 cid-b cid-c))
     ;; Write Int to C
     (define enet6 (elab-cell-write enet5 cid-c (expr-Int)))
     (define-values (status enet7) (elab-solve enet6))
     (check-equal? status 'ok)
     ;; Int should propagate C→B→A
     (check-equal? (elab-cell-read enet7 cid-a) (expr-Int))
     (check-equal? (elab-cell-read enet7 cid-b) (expr-Int))
     (check-equal? (elab-cell-read enet7 cid-c) (expr-Int)))))

;; ========================================
;; Helper Queries
;; ========================================

(define query-tests
  (test-suite
   "Helper queries"

   (test-case "elab-cell-solved?"
     (define enet0 (make-elaboration-network))
     (define-values (enet1 cid) (elab-fresh-meta enet0 '() (expr-Nat) "test"))
     ;; Fresh cell: not solved
     (check-false (elab-cell-solved? enet1 cid))
     ;; After write: solved
     (define enet2 (elab-cell-write enet1 cid (expr-Nat)))
     (check-true (elab-cell-solved? enet2 cid))
     ;; After contradiction: not solved
     (define enet3 (elab-cell-write enet2 cid (expr-Bool)))
     (check-false (elab-cell-solved? enet3 cid)))

   (test-case "elab-cell-read-or"
     (define enet0 (make-elaboration-network))
     (define-values (enet1 cid) (elab-fresh-meta enet0 '() (expr-Nat) "test"))
     ;; Bot cell with default
     (check-equal? (elab-cell-read-or enet1 cid (expr-Unit)) (expr-Unit))
     ;; After write: returns actual value
     (define enet2 (elab-cell-write enet1 cid (expr-Nat)))
     (check-equal? (elab-cell-read-or enet2 cid (expr-Unit)) (expr-Nat)))

   (test-case "elab-unsolved-cells"
     (define enet0 (make-elaboration-network))
     (define-values (enet1 cid-a) (elab-fresh-meta enet0 '() (expr-Nat) "a"))
     (define-values (enet2 cid-b) (elab-fresh-meta enet1 '() (expr-Bool) "b"))
     (define-values (enet3 cid-c) (elab-fresh-meta enet2 '() (expr-Int) "c"))
     ;; All three unsolved
     (check-equal? (length (elab-unsolved-cells enet3)) 3)
     ;; Write to two
     (define enet4 (elab-cell-write enet3 cid-a (expr-Nat)))
     (define enet5 (elab-cell-write enet4 cid-b (expr-Bool)))
     ;; Only cid-c unsolved
     (define unsolved (elab-unsolved-cells enet5))
     (check-equal? (length unsolved) 1)
     (check-equal? (car unsolved) cid-c))))

;; ========================================
;; Structural Propagation
;; ========================================

(define structural-tests
  (test-suite
   "Structural propagation"

   (test-case "Pi unification through network"
     (define enet0 (make-elaboration-network))
     (define pi-type (expr-Pi 'mw (expr-Nat) (expr-Bool)))
     (define-values (enet1 cid-a) (elab-fresh-meta enet0 '() pi-type "a"))
     (define-values (enet2 cid-b) (elab-fresh-meta enet1 '() pi-type "b"))
     ;; Write Pi to cell-a, leave cell-b at bot, add constraint
     (define enet3 (elab-cell-write enet2 cid-a pi-type))
     (define-values (enet4 _pid) (elab-add-unify-constraint enet3 cid-a cid-b))
     (define-values (status enet5) (elab-solve enet4))
     (check-equal? status 'ok)
     ;; Cell-b should now hold the Pi type
     (check-true (expr-Pi? (elab-cell-read enet5 cid-b)))
     (check-equal? (elab-cell-read enet5 cid-b) pi-type))

   (test-case "app decomposition: (List Nat) = (List Nat)"
     (define enet0 (make-elaboration-network))
     (define list-nat (expr-app (expr-tycon 'List) (expr-Nat)))
     (define-values (enet1 cid-a) (elab-fresh-meta enet0 '() list-nat "a"))
     (define-values (enet2 cid-b) (elab-fresh-meta enet1 '() list-nat "b"))
     (define enet3 (elab-cell-write enet2 cid-a list-nat))
     (define enet4 (elab-cell-write enet3 cid-b list-nat))
     (define-values (enet5 _pid) (elab-add-unify-constraint enet4 cid-a cid-b))
     (define-values (status enet6) (elab-solve enet5))
     (check-equal? status 'ok)
     (check-true (expr-app? (elab-cell-read enet6 cid-a))))))

;; ========================================
;; Run all tests
;; ========================================

(run-tests creation-tests)
(run-tests cell-ops-tests)
(run-tests unify-propagator-tests)
(run-tests solve-tests)
(run-tests query-tests)
(run-tests structural-tests)
