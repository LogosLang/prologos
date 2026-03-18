#lang racket/base

;;;
;;; Tests for Phase 3b: Configurable Search Heuristics
;;; Tests search-heuristics.rkt (config, value ordering, bounded enumeration,
;;; iterative deepening) and integration with narrowing.rkt search modes.
;;;

(require rackunit
         racket/list
         racket/path
         "../search-heuristics.rkt"
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
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    (process-string "(ns test-search-heuristics)")
    (values (current-global-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-bundle-registry))))

;; Helper: make a peano Nat from integer
(define (peano n)
  (if (zero? n) (expr-zero) (expr-suc (peano (- n 1)))))

;; Helper: run narrowing with a specific search config
(define (run-with-config func-name args target var-names config)
  (parameterize ([current-global-env shared-global-env]
                 [current-narrow-search-config config])
    (run-narrowing-search func-name args target var-names)))

;; ========================================
;; A. Config construction
;; ========================================

(test-case "config/default"
  (define cfg default-narrow-search-config)
  (check-equal? (narrow-search-config-value-order cfg) 'source-order)
  (check-equal? (narrow-search-config-search-mode cfg) 'all)
  (check-false  (narrow-search-config-iterative? cfg)))

(test-case "config/custom"
  (define cfg (narrow-search-config 'indomain-max 'first #t))
  (check-equal? (narrow-search-config-value-order cfg) 'indomain-max)
  (check-equal? (narrow-search-config-search-mode cfg) 'first)
  (check-true   (narrow-search-config-iterative? cfg)))

(test-case "config/at-most"
  (define cfg (narrow-search-config 'source-order '(at-most 5) #f))
  (check-equal? (narrow-search-config-search-mode cfg) '(at-most 5)))

(test-case "config/parameter"
  (check-equal? (narrow-search-config-value-order (current-narrow-search-config))
                'source-order)
  (parameterize ([current-narrow-search-config
                  (narrow-search-config 'random 'first #f)])
    (check-equal? (narrow-search-config-value-order (current-narrow-search-config))
                  'random)))

;; ========================================
;; B. Value ordering
;; ========================================

;; Simulate DT children as (ctor-name . tree) pairs
(define fake-children
  (list (cons 'zero (dt-rule (expr-zero)))
        (cons 'suc  (dt-rule (expr-zero)))
        (cons 'exempt (dt-exempt))))

(test-case "value-order/source-order: identity"
  (define result (reorder-dt-children fake-children 'source-order dt-exempt?))
  (check-equal? (map car result) '(zero suc exempt)))

(test-case "value-order/indomain-min: same as source"
  (define result (reorder-dt-children fake-children 'indomain-min dt-exempt?))
  (check-equal? (map car result) '(zero suc exempt)))

(test-case "value-order/indomain-max: reverse non-exempt"
  (define result (reorder-dt-children fake-children 'indomain-max dt-exempt?))
  ;; non-exempt reversed: suc zero, exempt stays last
  (check-equal? (map car result) '(suc zero exempt)))

(test-case "value-order/random: exempt stays last"
  ;; Run multiple times; exempt must always be last
  (for ([_ (in-range 10)])
    (define result (reorder-dt-children fake-children 'random dt-exempt?))
    (check-equal? (length result) 3)
    (check-equal? (car (last result)) 'exempt)))

(test-case "value-order/no-exempt: all reorderable"
  (define children-no-exempt
    (list (cons 'a (dt-rule (expr-zero)))
          (cons 'b (dt-rule (expr-zero)))
          (cons 'c (dt-rule (expr-zero)))))
  (define result (reorder-dt-children children-no-exempt 'indomain-max dt-exempt?))
  (check-equal? (map car result) '(c b a)))

(test-case "value-order/empty: returns empty"
  (check-equal? (reorder-dt-children '() 'indomain-max dt-exempt?) '()))

(test-case "value-order/unknown: passthrough"
  (define result (reorder-dt-children fake-children 'unknown-strategy dt-exempt?))
  (check-equal? (map car result) '(zero suc exempt)))

;; ========================================
;; C. Solution counter
;; ========================================

(test-case "counter/unlimited"
  (define c (make-solution-counter 'all))
  (check-equal? c 'unlimited)
  (check-equal? (solution-counter-remaining c) +inf.0)
  (check-false (solution-counter-exhausted? c))
  (solution-counter-decrement! c)
  (check-false (solution-counter-exhausted? c)))

(test-case "counter/first"
  (define c (make-solution-counter 'first))
  (check-equal? (solution-counter-remaining c) 1)
  (check-false (solution-counter-exhausted? c))
  (solution-counter-decrement! c)
  (check-true (solution-counter-exhausted? c)))

(test-case "counter/at-most-3"
  (define c (make-solution-counter '(at-most 3)))
  (check-equal? (solution-counter-remaining c) 3)
  (solution-counter-decrement! c 2)
  (check-equal? (solution-counter-remaining c) 1)
  (check-false (solution-counter-exhausted? c))
  (solution-counter-decrement! c)
  (check-true (solution-counter-exhausted? c)))

(test-case "counter/at-most-0"
  (define c (make-solution-counter '(at-most 0)))
  (check-true (solution-counter-exhausted? c)))

;; ========================================
;; D. Bounded append-map
;; ========================================

(test-case "bounded-append-map/unlimited"
  (define c (make-solution-counter 'all))
  (define result (bounded-append-map (lambda (x) (list (* x 10))) '(1 2 3) c))
  (check-equal? result '(10 20 30)))

(test-case "bounded-append-map/limit-1"
  (define c (make-solution-counter 'first))
  (define result (bounded-append-map (lambda (x) (list (* x 10))) '(1 2 3) c))
  (check-equal? result '(10)))

(test-case "bounded-append-map/limit-2"
  (define c (make-solution-counter '(at-most 2)))
  (define result (bounded-append-map (lambda (x) (list (* x 10))) '(1 2 3) c))
  (check-equal? result '(10 20)))

(test-case "bounded-append-map/multi-result"
  ;; Each call produces 2 results; limit is 3
  (define c (make-solution-counter '(at-most 3)))
  (define result (bounded-append-map (lambda (x) (list x (- x))) '(1 2 3) c))
  ;; First call produces (1 -1), counter goes from 3 to 1
  ;; Second call produces (2 -2) but truncated to 1 (remaining=1), counter → 0
  ;; Third call skipped because counter exhausted
  (check-equal? result '(1 -1 2)))

(test-case "bounded-append-map/empty-list"
  (define c (make-solution-counter 'first))
  (check-equal? (bounded-append-map (lambda (x) (list x)) '() c) '()))

(test-case "bounded-append-map/empty-results"
  (define c (make-solution-counter '(at-most 5)))
  (define result (bounded-append-map (lambda (x) '()) '(1 2 3) c))
  (check-equal? result '()))

;; ========================================
;; E. Iterative deepening
;; ========================================

(test-case "iterative-deepening/finds-at-min-depth"
  ;; Returns results only when fuel >= 3
  (define (search-fn fuel)
    (if (>= fuel 3) '(solution) '()))
  (define result (iterative-deepening-search search-fn 100))
  (check-equal? result '(solution)))

(test-case "iterative-deepening/fuel-progression"
  ;; Track which fuels are tried
  (define tried '())
  (define (search-fn fuel)
    (set! tried (cons fuel tried))
    (if (>= fuel 5) '(found) '()))
  (define result (iterative-deepening-search search-fn 100))
  ;; Should try 1, 2, 4, 8 (finds at 8)
  (check-equal? result '(found))
  (check-not-false (member 1 tried))
  (check-not-false (member 2 tried))
  (check-not-false (member 4 tried)))

(test-case "iterative-deepening/max-fuel-cap"
  ;; Never finds solution → returns empty
  (define (search-fn fuel) '())
  (define result (iterative-deepening-search search-fn 10))
  (check-equal? result '()))

(test-case "iterative-deepening/immediate"
  ;; Found at fuel=1
  (define (search-fn fuel) '(found))
  (define result (iterative-deepening-search search-fn 100))
  (check-equal? result '(found)))

;; ========================================
;; F. Solver config bridge
;; ========================================

(test-case "solver-bridge/defaults"
  (define cfg (narrow-config-from-solver
               (lambda (key default) default)))
  (check-equal? (narrow-search-config-value-order cfg) 'source-order)
  (check-equal? (narrow-search-config-search-mode cfg) 'all)
  (check-false  (narrow-search-config-iterative? cfg)))

(test-case "solver-bridge/custom"
  (define cfg (narrow-config-from-solver
               (lambda (key default)
                 (case key
                   [(narrow-value-order) 'indomain-max]
                   [(narrow-search) 'first]
                   [(narrow-iterative) #t]
                   [else default]))))
  (check-equal? (narrow-search-config-value-order cfg) 'indomain-max)
  (check-equal? (narrow-search-config-search-mode cfg) 'first)
  (check-true   (narrow-search-config-iterative? cfg)))

;; ========================================
;; G. Integration: value ordering
;; ========================================

(test-case "integration/source-order: add ?x ?y = 3 → 4 solutions"
  (define sols
    (run-with-config
     'prologos::data::nat::add
     (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
     (peano 3) '(x y)
     (narrow-search-config 'source-order 'all #f)))
  (check-equal? (length sols) 4))

(test-case "integration/indomain-max: add ?x ?y = 3 → 4 solutions"
  (define sols
    (run-with-config
     'prologos::data::nat::add
     (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
     (peano 3) '(x y)
     (narrow-search-config 'indomain-max 'all #f)))
  ;; Same count, different order
  (check-equal? (length sols) 4))

(test-case "integration/indomain-max: different solution order"
  (define sols-source
    (run-with-config
     'prologos::data::nat::add
     (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
     (peano 3) '(x y)
     (narrow-search-config 'source-order 'all #f)))
  (define sols-max
    (run-with-config
     'prologos::data::nat::add
     (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
     (peano 3) '(x y)
     (narrow-search-config 'indomain-max 'all #f)))
  ;; Same solution count but different order
  (check-equal? (length sols-source) (length sols-max))
  ;; First solutions should differ (DT branches on y: source-order starts
  ;; y=zero, indomain-max starts y=suc)
  (define first-y-source (hash-ref (car sols-source) 'y))
  (define first-y-max (hash-ref (car sols-max) 'y))
  (check-true (expr-zero? first-y-source))
  (check-true (expr-suc? first-y-max)))

(test-case "integration/not: ordering irrelevant for Bool"
  (define sols
    (run-with-config
     'prologos::data::bool::not
     (list (expr-logic-var 'b 'free))
     (expr-true) '(b)
     (narrow-search-config 'indomain-max 'all #f)))
  (check-equal? (length sols) 1)
  (check-true (expr-false? (hash-ref (car sols) 'b))))

;; ========================================
;; H. Integration: search modes
;; ========================================

(test-case "integration/first: add ?x ?y = 10 → 1 solution"
  (define sols
    (run-with-config
     'prologos::data::nat::add
     (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
     (peano 10) '(x y)
     (narrow-search-config 'source-order 'first #f)))
  (check-equal? (length sols) 1))

(test-case "integration/at-most-3: add ?x ?y = 10 → 3 solutions"
  (define sols
    (run-with-config
     'prologos::data::nat::add
     (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
     (peano 10) '(x y)
     (narrow-search-config 'source-order '(at-most 3) #f)))
  (check-equal? (length sols) 3))

(test-case "integration/all: add ?x ?y = 10 → 11 solutions"
  (define sols
    (run-with-config
     'prologos::data::nat::add
     (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
     (peano 10) '(x y)
     (narrow-search-config 'source-order 'all #f)))
  (check-equal? (length sols) 11))

(test-case "integration/first: add ?x ?y = 0 → 1 (only 1 exists)"
  (define sols
    (run-with-config
     'prologos::data::nat::add
     (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
     (peano 0) '(x y)
     (narrow-search-config 'source-order 'first #f)))
  (check-equal? (length sols) 1))

(test-case "integration/at-most-5: add ?x ?y = 3 → 4 (fewer than limit)"
  (define sols
    (run-with-config
     'prologos::data::nat::add
     (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
     (peano 3) '(x y)
     (narrow-search-config 'source-order '(at-most 5) #f)))
  ;; Only 4 solutions exist, so at-most-5 returns 4
  (check-equal? (length sols) 4))

(test-case "integration/first+indomain-max: add ?x ?y = 5"
  ;; First solution with indomain-max should have y=suc(...) not zero
  ;; (DT branches on y, reversed order means suc tried first)
  (define sols
    (run-with-config
     'prologos::data::nat::add
     (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
     (peano 5) '(x y)
     (narrow-search-config 'indomain-max 'first #f)))
  (check-equal? (length sols) 1)
  ;; With max-first ordering, first y should be suc (not zero)
  (check-true (expr-suc? (hash-ref (car sols) 'y))))

;; ========================================
;; I. Integration: iterative deepening
;; ========================================

(test-case "integration/iterative: add ?x ?y = 3 → 4 solutions"
  (define sols
    (run-with-config
     'prologos::data::nat::add
     (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
     (peano 3) '(x y)
     (narrow-search-config 'source-order 'all #t)))
  ;; Iterative deepening should find same solutions (possibly at different depths)
  (check-equal? (length sols) 4))

(test-case "integration/iterative+first: add ?x ?y = 10 → 1"
  (define sols
    (run-with-config
     'prologos::data::nat::add
     (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
     (peano 10) '(x y)
     (narrow-search-config 'source-order 'first #t)))
  (check-equal? (length sols) 1))

(test-case "integration/iterative: not ?b = true"
  (define sols
    (run-with-config
     'prologos::data::bool::not
     (list (expr-logic-var 'b 'free))
     (expr-true) '(b)
     (narrow-search-config 'source-order 'all #t)))
  (check-equal? (length sols) 1))

;; ========================================
;; J. Default config preserves existing behavior
;; ========================================

(test-case "integration/default-config: same as before"
  ;; Default config (source-order, all, no iterative) should match
  ;; the original non-configurable behavior exactly
  (parameterize ([current-global-env shared-global-env])
    (define sols-default
      (run-narrowing-search
       'prologos::data::nat::add
       (list (expr-logic-var 'x 'free) (expr-logic-var 'y 'free))
       (peano 5) '(x y)))
    (check-equal? (length sols-default) 6)))
