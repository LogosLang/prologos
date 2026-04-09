#lang racket/base

;;;
;;; test-elab-speculation.rkt — Tests for ATMS-backed speculative elaboration
;;;
;;; Tests construction, binary speculation (union pattern), map widening,
;;; multi-way speculation, nested speculation, and persistence/error reporting.
;;;
;;; Phase 4 of the type inference refactoring.
;;;

(require rackunit
         rackunit/text-ui
         "../prelude.rkt"
         "../syntax.rkt"
         "../type-lattice.rkt"
         "../propagator.rkt"
         "../elaborator-network.rkt"
         "../atms.rkt"
         "../elab-speculation.rkt")

;; ========================================
;; Test Helpers
;; ========================================

;; Extract nogoods list from a solver-state (replaces old atms-nogoods field accessor).
(define (solver-state-nogoods ss)
  (define ng-list (net-cell-read-raw (solver-state-net ss)
                                      (solver-context-nogoods-cid (solver-state-ctx ss))))
  (if (list? ng-list) ng-list '()))

;; Create a try-fn that writes a value to a cell.
(define (make-write-fn cid val)
  (lambda (enet) (elab-cell-write enet cid val)))

;; Create a try-fn that writes contradictory values to a cell.
(define (make-contradict-fn cid val1 val2)
  (lambda (enet)
    (define enet* (elab-cell-write enet cid val1))
    (elab-cell-write enet* cid val2)))

;; Create a try-fn that adds a unification constraint between two cells.
(define (make-unify-fn cid-a cid-b)
  (lambda (enet)
    (define-values (enet* _pid) (elab-add-unify-constraint enet cid-a cid-b))
    enet*))

;; Create a base network with N fresh cells (all at type-bot).
;; Returns (values elab-network (listof cell-id)).
(define (make-test-network n)
  (let loop ([enet (make-elaboration-network)]
             [cids '()]
             [i 0])
    (if (>= i n)
        (values enet (reverse cids))
        (let-values ([(enet* cid) (elab-fresh-meta enet '() (expr-Type (lzero)) (format "cell-~a" i))])
          (loop enet* (cons cid cids) (+ i 1))))))

;; ========================================
;; Suite 1: Construction
;; ========================================

(define construction-tests
  (test-suite
   "Construction"

   (test-case "speculation-begin with 2 labels creates 2 pending branches"
     (define enet (make-elaboration-network))
     (define spec (speculation-begin enet '("left" "right")))
     (check-equal? (speculation-branch-count spec) 2)
     (check-eq? (speculation-branch-status spec 0) 'pending)
     (check-eq? (speculation-branch-status spec 1) 'pending))

   (test-case "speculation-begin with 3 labels creates 3 branches + mutual exclusion"
     (define enet (make-elaboration-network))
     (define spec (speculation-begin enet '("a" "b" "c")))
     (check-equal? (speculation-branch-count spec) 3)
     ;; ATMS should have 3 mutual exclusion nogoods (C(3,2) = 3 pairs)
     (define a (speculation-atms spec))
     (check-equal? (length (solver-state-nogoods a)) 3))

   (test-case "each branch forks from the same base elab-network"
     (define-values (enet cids) (make-test-network 2))
     (define cid0 (car cids))
     ;; Write a value to base
     (define enet* (elab-cell-write enet cid0 (expr-Nat)))
     (define spec (speculation-begin enet* '("left" "right")))
     ;; Both branches should see the written value
     (define left-enet (speculation-branch-enet spec 0))
     (define right-enet (speculation-branch-enet spec 1))
     (check-equal? (elab-cell-read left-enet cid0) (expr-Nat))
     (check-equal? (elab-cell-read right-enet cid0) (expr-Nat)))))

;; ========================================
;; Suite 2: Binary Speculation — Union Pattern
;; ========================================

(define binary-tests
  (test-suite
   "Binary speculation (union pattern)"

   (test-case "both branches succeed — first wins"
     (define-values (enet cids) (make-test-network 1))
     (define cid (car cids))
     (define result
       (speculate-first-success enet
         (list (make-write-fn cid (expr-Nat))
               (make-write-fn cid (expr-Bool)))
         '("union-left" "union-right")))
     (check-eq? (speculation-result-status result) 'ok)
     (check-equal? (speculation-result-winner-index result) 0)
     ;; Winner's network has Nat
     (check-equal? (elab-cell-read (speculation-result-enet result) cid) (expr-Nat)))

   (test-case "left fails, right succeeds — right wins"
     (define-values (enet cids) (make-test-network 1))
     (define cid (car cids))
     (define result
       (speculate-first-success enet
         (list (make-contradict-fn cid (expr-Nat) (expr-Bool))
               (make-write-fn cid (expr-Bool)))
         '("union-left" "union-right")))
     (check-eq? (speculation-result-status result) 'ok)
     (check-equal? (speculation-result-winner-index result) 1)
     ;; Winner's network has Bool
     (check-equal? (elab-cell-read (speculation-result-enet result) cid) (expr-Bool))
     ;; One nogood from the failed branch
     (check-equal? (length (speculation-result-nogoods result)) 1)
     (check-equal? (nogood-info-branch-label (car (speculation-result-nogoods result)))
                   "union-left"))

   (test-case "both fail — all-failed with 2 nogoods"
     (define-values (enet cids) (make-test-network 1))
     (define cid (car cids))
     (define result
       (speculate-first-success enet
         (list (make-contradict-fn cid (expr-Nat) (expr-Bool))
               (make-contradict-fn cid (expr-Nat) (expr-Bool)))
         '("left" "right")))
     (check-eq? (speculation-result-status result) 'all-failed)
     (check-false (speculation-result-enet result))
     (check-false (speculation-result-winner-index result))
     (check-equal? (length (speculation-result-nogoods result)) 2))

   (test-case "short-circuit: first success stops trying"
     ;; Use a mutable counter to detect if second try-fn is called
     (define-values (enet cids) (make-test-network 1))
     (define cid (car cids))
     (define call-count (box 0))
     (define (counting-fn enet)
       (set-box! call-count (+ 1 (unbox call-count)))
       (elab-cell-write enet cid (expr-Bool)))
     (define result
       (speculate-first-success enet
         (list (make-write-fn cid (expr-Nat))
               counting-fn)
         '("first" "second")))
     (check-eq? (speculation-result-status result) 'ok)
     (check-equal? (speculation-result-winner-index result) 0)
     ;; Second function should not have been called
     (check-equal? (unbox call-count) 0))))

;; ========================================
;; Suite 3: Map Value Widening Pattern
;; ========================================

(define widening-tests
  (test-suite
   "Map value widening pattern"

   (test-case "value fits existing type — ok, no widening needed"
     (define-values (enet cids) (make-test-network 1))
     (define cid (car cids))
     ;; Pre-write Nat to the cell
     (define enet* (elab-cell-write enet cid (expr-Nat)))
     (define result
       (speculate-first-success enet*
         ;; Branch 0: write Nat (compatible with existing Nat)
         ;; Branch 1: would widen — not needed
         (list (make-write-fn cid (expr-Nat))
               (make-write-fn cid (expr-Bool)))
         '("fits" "widen")))
     (check-eq? (speculation-result-status result) 'ok)
     (check-equal? (speculation-result-winner-index result) 0))

   (test-case "value doesn't fit — contradiction on fit branch"
     (define-values (enet cids) (make-test-network 1))
     (define cid (car cids))
     ;; Pre-write Nat to the cell
     (define enet* (elab-cell-write enet cid (expr-Nat)))
     (define result
       (speculate-first-success enet*
         ;; Branch 0: write Bool (contradicts Nat)
         ;; Branch 1: widen (write Nat — compatible)
         (list (make-write-fn cid (expr-Bool))
               (make-write-fn cid (expr-Nat)))
         '("fits" "widen")))
     (check-eq? (speculation-result-status result) 'ok)
     (check-equal? (speculation-result-winner-index result) 1))

   (test-case "contradiction info preserved for error messages"
     (define-values (enet cids) (make-test-network 1))
     (define cid (car cids))
     (define enet* (elab-cell-write enet cid (expr-Nat)))
     (define result
       (speculate-first-success enet*
         (list (make-write-fn cid (expr-Bool))
               (make-write-fn cid (expr-Nat)))
         '("fails" "succeeds")))
     (define ngs (speculation-result-nogoods result))
     (check-equal? (length ngs) 1)
     (define ng (car ngs))
     (check-equal? (nogood-info-branch-index ng) 0)
     (check-equal? (nogood-info-branch-label ng) "fails")
     ;; Contradiction info should be present
     (check-true (contradiction-info? (nogood-info-contradiction ng))))))

;; ========================================
;; Suite 4: Multi-way Speculation — Union Map-Get Pattern
;; ========================================

(define multiway-tests
  (test-suite
   "Multi-way speculation (union map-get)"

   (test-case "3-way: 1 of 3 succeeds"
     (define-values (enet cids) (make-test-network 1))
     (define cid (car cids))
     (define result
       (speculate-first-success enet
         (list (make-contradict-fn cid (expr-Nat) (expr-Bool))
               (make-contradict-fn cid (expr-Nat) (expr-Bool))
               (make-write-fn cid (expr-Nat)))
         '("comp-0" "comp-1" "comp-2")))
     (check-eq? (speculation-result-status result) 'ok)
     (check-equal? (speculation-result-winner-index result) 2)
     (check-equal? (length (speculation-result-nogoods result)) 2))

   (test-case "3-way: all fail — all-failed with 3 nogoods"
     (define-values (enet cids) (make-test-network 1))
     (define cid (car cids))
     (define result
       (speculate-first-success enet
         (list (make-contradict-fn cid (expr-Nat) (expr-Bool))
               (make-contradict-fn cid (expr-Nat) (expr-Bool))
               (make-contradict-fn cid (expr-Nat) (expr-Bool)))
         '("a" "b" "c")))
     (check-eq? (speculation-result-status result) 'all-failed)
     (check-equal? (length (speculation-result-nogoods result)) 3))))

;; ========================================
;; Suite 5: Nested Speculation
;; ========================================

(define nested-tests
  (test-suite
   "Nested speculation"

   (test-case "inner speculation within outer branch resolves correctly"
     (define-values (enet cids) (make-test-network 2))
     (define cid0 (car cids))
     (define cid1 (cadr cids))
     ;; Outer: try writing Nat to cid0
     ;; Inner (within outer branch 0): try writing Nat vs Bool to cid1
     (define (outer-branch-0 enet)
       (define enet* (elab-cell-write enet cid0 (expr-Nat)))
       ;; Nested speculation on cid1
       (define inner-result
         (speculate-first-success enet*
           (list (make-contradict-fn cid1 (expr-Nat) (expr-Bool))
                 (make-write-fn cid1 (expr-Bool)))
           '("inner-left" "inner-right")))
       (if (eq? (speculation-result-status inner-result) 'ok)
           (speculation-result-enet inner-result)
           enet*))
     (define result
       (speculate-first-success enet
         (list outer-branch-0
               (make-write-fn cid0 (expr-Bool)))
         '("outer-left" "outer-right")))
     (check-eq? (speculation-result-status result) 'ok)
     (check-equal? (speculation-result-winner-index result) 0)
     ;; Outer branch 0 succeeded; inner selected Bool for cid1
     (define winner-enet (speculation-result-enet result))
     (check-equal? (elab-cell-read winner-enet cid0) (expr-Nat))
     (check-equal? (elab-cell-read winner-enet cid1) (expr-Bool)))

   (test-case "inner failure doesn't invalidate outer branch"
     (define-values (enet cids) (make-test-network 2))
     (define cid0 (car cids))
     (define cid1 (cadr cids))
     ;; Inner speculation fails completely, but outer branch still succeeds
     ;; (outer try-fn writes to cid0 only, ignores inner failure)
     (define (outer-with-failed-inner enet)
       (define enet* (elab-cell-write enet cid0 (expr-Nat)))
       (define inner-result
         (speculate-first-success enet*
           (list (make-contradict-fn cid1 (expr-Nat) (expr-Bool))
                 (make-contradict-fn cid1 (expr-Nat) (expr-Bool)))
           '("inner-a" "inner-b")))
       ;; Inner failed, but we still return the outer network (cid0 = Nat)
       enet*)
     (define result
       (speculate-first-success enet
         (list outer-with-failed-inner
               (make-write-fn cid0 (expr-Bool)))
         '("outer-a" "outer-b")))
     (check-eq? (speculation-result-status result) 'ok)
     (check-equal? (speculation-result-winner-index result) 0)
     (check-equal? (elab-cell-read (speculation-result-enet result) cid0) (expr-Nat)))

   (test-case "ATMS tracks hypotheses from both levels independently"
     (define-values (enet cids) (make-test-network 1))
     (define cid (car cids))
     ;; Outer speculation
     (define spec-outer (speculation-begin enet '("outer-a" "outer-b")))
     (define a-outer (speculation-atms spec-outer))
     ;; Inner speculation (separate ATMS)
     (define spec-inner (speculation-begin enet '("inner-x" "inner-y")))
     (define a-inner (speculation-atms spec-inner))
     ;; Each ATMS has independent nogoods
     (check-equal? (length (solver-state-nogoods a-outer)) 1)  ;; C(2,2) = 1
     (check-equal? (length (solver-state-nogoods a-inner)) 1)
     ;; Both have 2 branches
     (check-equal? (speculation-branch-count spec-outer) 2)
     (check-equal? (speculation-branch-count spec-inner) 2))))

;; ========================================
;; Suite 6: Persistence + Error Reporting
;; ========================================

(define persistence-tests
  (test-suite
   "Persistence and error reporting"

   (test-case "base elab-network unchanged after speculation"
     (define-values (enet cids) (make-test-network 1))
     (define cid (car cids))
     (define result
       (speculate-first-success enet
         (list (make-write-fn cid (expr-Nat))
               (make-write-fn cid (expr-Bool)))
         '("a" "b")))
     ;; Base network should still have bot (unchanged)
     (check-true (type-bot? (elab-cell-read enet cid)))
     ;; Winner has Nat
     (check-equal? (elab-cell-read (speculation-result-enet result) cid) (expr-Nat)))

   (test-case "nogood-info has correct branch labels and indices"
     (define-values (enet cids) (make-test-network 1))
     (define cid (car cids))
     (define result
       (speculate-first-success enet
         (list (make-contradict-fn cid (expr-Nat) (expr-Bool))
               (make-contradict-fn cid (expr-Nat) (expr-Bool))
               (make-write-fn cid (expr-Nat)))
         '("alpha" "beta" "gamma")))
     (define ngs (speculation-result-nogoods result))
     (check-equal? (length ngs) 2)
     (check-equal? (nogood-info-branch-index (car ngs)) 0)
     (check-equal? (nogood-info-branch-label (car ngs)) "alpha")
     (check-equal? (nogood-info-branch-index (cadr ngs)) 1)
     (check-equal? (nogood-info-branch-label (cadr ngs)) "beta"))

   (test-case "contradiction-info from failed branch has cell details"
     (define-values (enet cids) (make-test-network 1))
     (define cid (car cids))
     (define result
       (speculate-first-success enet
         (list (make-contradict-fn cid (expr-Nat) (expr-Bool))
               (make-write-fn cid (expr-Nat)))
         '("fail" "ok")))
     (define ngs (speculation-result-nogoods result))
     (check-equal? (length ngs) 1)
     (define ci (nogood-info-contradiction (car ngs)))
     (check-true (contradiction-info? ci))
     (check-true (cell-id? (contradiction-info-cell-id ci))))))

;; ========================================
;; Run all suites
;; ========================================

(run-tests construction-tests)
(run-tests binary-tests)
(run-tests widening-tests)
(run-tests multiway-tests)
(run-tests nested-tests)
(run-tests persistence-tests)
