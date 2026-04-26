#lang racket/base

;;;
;;; Tests for Phase 3c: Global Constraints + BB Optimization
;;; Tests global-constraints.rkt (all-different, element, cumulative),
;;; bb-optimization.rkt (branch-and-bound), interval-remove in
;;; interval-domain.rkt, and integration with narrowing DFS.
;;;

(require rackunit
         racket/list
         racket/path
         "../global-constraints.rkt"
         "../bb-optimization.rkt"
         "../interval-domain.rkt"
         "../search-heuristics.rkt"
         "../solver.rkt"
         "../narrowing.rkt"
         "../definitional-tree.rkt"
         "../macros.rkt"
         "../syntax.rkt"
         "../prelude.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../trait-resolution.rkt")

;; ========================================
;; Shared Fixture (for integration tests)
;; ========================================

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-bundle-reg)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    (process-string "(ns test-global-constraints)")
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-bundle-registry))))

;; Helper: make a peano Nat from integer
(define (peano n)
  (if (zero? n) (expr-zero) (expr-suc (peano (- n 1)))))

;; Helper: run narrowing with constraints
(define (run-with-constraints func-name args target var-names constraints
                              [bb #f])
  (parameterize ([current-prelude-env shared-global-env]
                 [current-narrow-search-config default-narrow-search-config]
                 [current-narrow-constraints constraints]
                 [current-bb-state bb])
    (run-narrowing-search func-name args target var-names)))

;; Helper: extract nat value from solution map
(define (sol-nat sol var)
  (expr->nat-val (hash-ref sol var)))

;; ========================================
;; A. interval-remove
;; ========================================

(test-case "interval-remove/lo-boundary"
  (define iv (interval 3 10))
  (define result (interval-remove iv 3))
  (check-equal? (interval-lo result) 4)
  (check-equal? (interval-hi result) 10))

(test-case "interval-remove/hi-boundary"
  (define iv (interval 3 10))
  (define result (interval-remove iv 10))
  (check-equal? (interval-lo result) 3)
  (check-equal? (interval-hi result) 9))

(test-case "interval-remove/interior-no-change"
  (define iv (interval 3 10))
  (define result (interval-remove iv 5))
  ;; Interior removal doesn't change interval (bound consistency only)
  (check-equal? (interval-lo result) 3)
  (check-equal? (interval-hi result) 10))

(test-case "interval-remove/outside-no-change"
  (define iv (interval 3 10))
  (define result (interval-remove iv 15))
  (check-equal? (interval-lo result) 3)
  (check-equal? (interval-hi result) 10))

(test-case "interval-remove/singleton-becomes-empty"
  (define iv (interval 5 5))
  (define result (interval-remove iv 5))
  (check-true (interval-contradiction? result)))

(test-case "interval-remove/empty-stays-empty"
  (define iv interval-empty)
  (define result (interval-remove iv 5))
  (check-true (interval-contradiction? result)))

;; ========================================
;; B. Constraint construction
;; ========================================

(test-case "constraint/all-different-construction"
  (define c (narrow-constraint 'all-different '(x y z) #f))
  (check-equal? (narrow-constraint-kind c) 'all-different)
  (check-equal? (narrow-constraint-vars c) '(x y z))
  (check-false (narrow-constraint-data c)))

(test-case "constraint/element-construction"
  (define xs (list (peano 1) (peano 2) (peano 3)))
  (define c (narrow-constraint 'element '(i v) (list xs)))
  (check-equal? (narrow-constraint-kind c) 'element)
  (check-equal? (narrow-constraint-vars c) '(i v)))

(test-case "constraint/cumulative-construction"
  (define c (narrow-constraint 'cumulative '(s1 s2)
              (list '(2 3) '(1 1) 2)))
  (check-equal? (narrow-constraint-kind c) 'cumulative))

;; ========================================
;; C. Variable resolution helpers
;; ========================================

(test-case "resolve-var/unbound"
  (check-false (resolve-var (hasheq) 'x)))

(test-case "resolve-var/direct-binding"
  (define subst (hasheq 'x (expr-zero)))
  (check-true (expr-zero? (resolve-var subst 'x))))

(test-case "resolve-var/chain"
  (define subst (hasheq 'x (expr-logic-var 'y 'free)
                        'y (peano 3)))
  (define val (resolve-var subst 'x))
  (check-equal? (expr->nat-val val) 3))

(test-case "expr->nat-val/peano"
  (check-equal? (expr->nat-val (peano 0)) 0)
  (check-equal? (expr->nat-val (peano 5)) 5)
  (check-false (expr->nat-val (expr-true))))

;; ========================================
;; D. all-different forward-checking
;; ========================================

(test-case "all-different/no-bound-vars"
  (define c (narrow-constraint 'all-different '(x y z) #f))
  (define result (forward-check (hasheq) (list c) (hasheq)))
  (check-not-false result)
  ;; Constraint still active (not yet satisfied)
  (check-equal? (length (cadr result)) 1))

(test-case "all-different/one-bound-no-conflict"
  (define c (narrow-constraint 'all-different '(x y z) #f))
  (define subst (hasheq 'x (peano 1)))
  (define result (forward-check subst (list c) (hasheq)))
  (check-not-false result))

(test-case "all-different/two-bound-no-conflict"
  (define c (narrow-constraint 'all-different '(x y z) #f))
  (define subst (hasheq 'x (peano 1) 'y (peano 2)))
  (define result (forward-check subst (list c) (hasheq)))
  (check-not-false result))

(test-case "all-different/two-bound-conflict"
  (define c (narrow-constraint 'all-different '(x y z) #f))
  (define subst (hasheq 'x (peano 3) 'y (peano 3)))
  (define result (forward-check subst (list c) (hasheq)))
  (check-false result))

(test-case "all-different/all-bound-distinct-satisfied"
  (define c (narrow-constraint 'all-different '(x y z) #f))
  (define subst (hasheq 'x (peano 1) 'y (peano 2) 'z (peano 3)))
  (define result (forward-check subst (list c) (hasheq)))
  (check-not-false result)
  ;; Constraint should be satisfied (removed from active list)
  (check-equal? (length (cadr result)) 0))

(test-case "all-different/all-bound-duplicate-contradiction"
  (define c (narrow-constraint 'all-different '(x y z) #f))
  (define subst (hasheq 'x (peano 1) 'y (peano 2) 'z (peano 1)))
  (define result (forward-check subst (list c) (hasheq)))
  (check-false result))

(test-case "all-different/boundary-pruning"
  ;; x=0, y has interval [0,5]. After all-different, y's interval should become [1,5]
  (define c (narrow-constraint 'all-different '(x y) #f))
  (define subst (hasheq 'x (peano 0)))
  (define ivs (hasheq 'y (interval 0 5)))
  (define result (forward-check subst (list c) ivs))
  (check-not-false result)
  (define new-ivs (caddr result))
  (define y-iv (hash-ref new-ivs 'y))
  (check-equal? (interval-lo y-iv) 1)
  (check-equal? (interval-hi y-iv) 5))

(test-case "all-different/hi-boundary-pruning"
  ;; x=5, y has interval [0,5]. After all-different, y's interval should become [0,4]
  (define c (narrow-constraint 'all-different '(x y) #f))
  (define subst (hasheq 'x (peano 5)))
  (define ivs (hasheq 'y (interval 0 5)))
  (define result (forward-check subst (list c) ivs))
  (check-not-false result)
  (define new-ivs (caddr result))
  (define y-iv (hash-ref new-ivs 'y))
  (check-equal? (interval-lo y-iv) 0)
  (check-equal? (interval-hi y-iv) 4))

(test-case "all-different/singleton-domain-contradiction"
  ;; x=5, y has interval [5,5]. After all-different, y's interval is empty
  (define c (narrow-constraint 'all-different '(x y) #f))
  (define subst (hasheq 'x (peano 5)))
  (define ivs (hasheq 'y (interval 5 5)))
  (define result (forward-check subst (list c) ivs))
  (check-false result))

;; ========================================
;; E. element forward-checking
;; ========================================

(test-case "element/neither-bound"
  (define xs (list (peano 10) (peano 20) (peano 30)))
  (define c (narrow-constraint 'element '(i v) (list xs)))
  (define result (forward-check (hasheq) (list c) (hasheq)))
  (check-not-false result)
  (check-equal? (length (cadr result)) 1))

(test-case "element/index-bound-valid"
  (define xs (list (peano 10) (peano 20) (peano 30)))
  (define c (narrow-constraint 'element '(i v) (list xs)))
  (define subst (hasheq 'i (peano 1)))
  (define result (forward-check subst (list c) (hasheq)))
  (check-not-false result))

(test-case "element/index-bound-out-of-bounds"
  (define xs (list (peano 10) (peano 20) (peano 30)))
  (define c (narrow-constraint 'element '(i v) (list xs)))
  (define subst (hasheq 'i (peano 5)))
  (define result (forward-check subst (list c) (hasheq)))
  (check-false result))

(test-case "element/both-bound-consistent"
  (define xs (list (peano 10) (peano 20) (peano 30)))
  (define c (narrow-constraint 'element '(i v) (list xs)))
  (define subst (hasheq 'i (peano 1) 'v (peano 20)))
  (define result (forward-check subst (list c) (hasheq)))
  (check-not-false result)
  ;; Should be satisfied (removed)
  (check-equal? (length (cadr result)) 0))

(test-case "element/both-bound-inconsistent"
  (define xs (list (peano 10) (peano 20) (peano 30)))
  (define c (narrow-constraint 'element '(i v) (list xs)))
  (define subst (hasheq 'i (peano 1) 'v (peano 99)))
  (define result (forward-check subst (list c) (hasheq)))
  (check-false result))

(test-case "element/value-bound-constrains-index"
  (define xs (list (peano 10) (peano 20) (peano 10)))
  (define c (narrow-constraint 'element '(i v) (list xs)))
  (define subst (hasheq 'v (peano 10)))
  (define ivs (hasheq 'i (interval 0 2)))
  (define result (forward-check subst (list c) ivs))
  (check-not-false result)
  ;; i should be constrained to [0, 2] (indices 0 and 2 match)
  (define new-ivs (caddr result))
  (define i-iv (hash-ref new-ivs 'i))
  (check-equal? (interval-lo i-iv) 0)
  (check-equal? (interval-hi i-iv) 2))

(test-case "element/value-not-in-list"
  (define xs (list (peano 10) (peano 20) (peano 30)))
  (define c (narrow-constraint 'element '(i v) (list xs)))
  (define subst (hasheq 'v (peano 99)))
  (define result (forward-check subst (list c) (hasheq)))
  (check-false result))

;; ========================================
;; F. cumulative forward-checking
;; ========================================

(test-case "cumulative/no-bound-tasks"
  (define c (narrow-constraint 'cumulative '(s1 s2)
              (list '(2 3) '(1 1) 2)))
  (define result (forward-check (hasheq) (list c) (hasheq)))
  (check-not-false result)
  (check-equal? (length (cadr result)) 1))

(test-case "cumulative/single-task-within-capacity"
  (define c (narrow-constraint 'cumulative '(s1)
              (list '(3) '(1) 2)))
  (define subst (hasheq 's1 (peano 0)))
  (define result (forward-check subst (list c) (hasheq)))
  (check-not-false result))

(test-case "cumulative/two-non-overlapping-ok"
  ;; task1: start=0, dur=2, res=2
  ;; task2: start=3, dur=2, res=2
  ;; capacity=2: no overlap, ok
  (define c (narrow-constraint 'cumulative '(s1 s2)
              (list '(2 2) '(2 2) 2)))
  (define subst (hasheq 's1 (peano 0) 's2 (peano 3)))
  (define result (forward-check subst (list c) (hasheq)))
  (check-not-false result))

(test-case "cumulative/two-overlapping-exceed-capacity"
  ;; task1: start=0, dur=3, res=2
  ;; task2: start=1, dur=3, res=2
  ;; capacity=3: at t=1,2 load=4 > 3
  (define c (narrow-constraint 'cumulative '(s1 s2)
              (list '(3 3) '(2 2) 3)))
  (define subst (hasheq 's1 (peano 0) 's2 (peano 1)))
  (define result (forward-check subst (list c) (hasheq)))
  (check-false result))

(test-case "cumulative/two-overlapping-within-capacity"
  ;; task1: start=0, dur=2, res=1
  ;; task2: start=1, dur=2, res=1
  ;; capacity=2: at t=1 load=2 <= 2, ok
  (define c (narrow-constraint 'cumulative '(s1 s2)
              (list '(2 2) '(1 1) 2)))
  (define subst (hasheq 's1 (peano 0) 's2 (peano 1)))
  (define result (forward-check subst (list c) (hasheq)))
  (check-not-false result))

;; ========================================
;; G. BB-min unit tests
;; ========================================

(test-case "bb/initial-bound-infinity"
  (define bb (make-bb-state 'cost))
  (check-equal? (bb-current-bound bb) +inf.0))

(test-case "bb/update-bound"
  (define bb (make-bb-state 'cost))
  (bb-update-bound! bb (hasheq 'cost (peano 10)))
  (check-equal? (bb-current-bound bb) 10))

(test-case "bb/update-bound-only-improves"
  (define bb (make-bb-state 'cost))
  (bb-update-bound! bb (hasheq 'cost (peano 5)))
  (bb-update-bound! bb (hasheq 'cost (peano 10)))
  ;; Should still be 5 (only improves)
  (check-equal? (bb-current-bound bb) 5))

(test-case "bb/should-prune-no-bound"
  (define bb (make-bb-state 'cost))
  ;; No solution found yet, shouldn't prune
  (check-false (bb-should-prune? bb (hasheq 'cost (interval 0 100)))))

(test-case "bb/should-prune-lower-bound-exceeds"
  (define bb (make-bb-state 'cost))
  (bb-update-bound! bb (hasheq 'cost (peano 5)))
  ;; Cost interval [6, 100]: lower bound 6 >= best 5 → prune
  (check-true (bb-should-prune? bb (hasheq 'cost (interval 6 100)))))

(test-case "bb/should-not-prune-when-possible"
  (define bb (make-bb-state 'cost))
  (bb-update-bound! bb (hasheq 'cost (peano 5)))
  ;; Cost interval [3, 100]: lower bound 3 < best 5 → don't prune
  (check-false (bb-should-prune? bb (hasheq 'cost (interval 3 100)))))

(test-case "bb/filter-optimal"
  (define bb (make-bb-state 'cost))
  (bb-update-bound! bb (hasheq 'cost (peano 3)))
  (define solutions
    (list (hasheq 'x (peano 1) 'cost (peano 5))
          (hasheq 'x (peano 2) 'cost (peano 3))
          (hasheq 'x (peano 3) 'cost (peano 3))))
  (define filtered (bb-filter-optimal solutions bb))
  (check-equal? (length filtered) 2))

(test-case "bb/extract-cost-value"
  (check-equal? (extract-cost-value (hasheq 'cost (peano 7)) 'cost) 7)
  (check-false (extract-cost-value (hasheq 'x (peano 1)) 'cost)))

;; ========================================
;; H. Integration: all-different + narrowing
;; ========================================

(test-case "integration/add-no-constraints"
  ;; [add ?x ?y] = 4N without constraints → 5 solutions (0+4, 1+3, 2+2, 3+1, 4+0)
  (define sols (run-with-constraints
                'add
                (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
                (peano 4)
                '(x y)
                '()))
  (check-equal? (length sols) 5))

(test-case "integration/add-all-different"
  ;; [add ?x ?y] = 4N with all-different [?x ?y] → 4 solutions (excludes x=y=2)
  (define c (narrow-constraint 'all-different '(x y) #f))
  (define sols (run-with-constraints
                'add
                (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
                (peano 4)
                '(x y)
                (list c)))
  (check-equal? (length sols) 4)
  ;; Verify x=2,y=2 is NOT in the solutions
  (check-false
   (for/or ([sol (in-list sols)])
     (and (equal? (sol-nat sol 'x) 2)
          (equal? (sol-nat sol 'y) 2)))))

(test-case "integration/add-all-different-zero"
  ;; [add ?x ?y] = 0N with all-different [?x ?y] → 0 solutions
  ;; Only solution without constraint is x=0,y=0, but all-different excludes it
  (define c (narrow-constraint 'all-different '(x y) #f))
  (define sols (run-with-constraints
                'add
                (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
                (peano 0)
                '(x y)
                (list c)))
  (check-equal? (length sols) 0))

(test-case "integration/add-all-different-small"
  ;; [add ?x ?y] = 2N with all-different → 2 solutions (0+2, 2+0), excludes 1+1
  (define c (narrow-constraint 'all-different '(x y) #f))
  (define sols (run-with-constraints
                'add
                (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
                (peano 2)
                '(x y)
                (list c)))
  (check-equal? (length sols) 2))

;; ========================================
;; I. Integration: BB-min + narrowing
;; ========================================

(test-case "integration/bb-min-basic"
  ;; [add ?x ?y] = 3N → solutions: (0,3) (1,2) (2,1) (3,0)
  ;; The add function doesn't produce a "cost" in these solutions directly,
  ;; but we can test that BB filtering works on post-search solutions.
  (define bb (make-bb-state 'x))
  (define sols (run-with-constraints
                'add
                (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
                (peano 3)
                '(x y)
                '()
                bb))
  ;; BB minimizes x: best x=0, should filter to only x=0 solution
  (check-equal? (length sols) 1)
  (check-equal? (sol-nat (car sols) 'x) 0))

;; ========================================
;; J. Solver config keys
;; ========================================

(test-case "solver-config/narrow-constraints-default"
  (define cfg (make-solver-config))
  (check-equal? (solver-config-narrow-constraints cfg) '())
  (check-false (solver-config-narrow-minimize cfg)))

(test-case "solver-config/narrow-constraints-override"
  (define cfg (make-solver-config (hasheq 'narrow-constraints '(test)
                                          'narrow-minimize 'cost)))
  (check-equal? (solver-config-narrow-constraints cfg) '(test))
  (check-equal? (solver-config-narrow-minimize cfg) 'cost))
