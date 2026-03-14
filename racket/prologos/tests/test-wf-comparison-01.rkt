#lang racket/base

;;;
;;; Tests for WFLE Phase 6: Stratified vs Well-Founded Comparison
;;; Validates that both engines agree on stratifiable programs.
;;;

(require rackunit
         "../solver.rkt"
         "../relations.rkt"
         "../stratified-eval.rkt"
         "../wf-engine.rkt"
         "../syntax.rkt")

;; ========================================
;; Helper
;; ========================================

(define (build-store . specs)
  (for/hasheq ([spec (in-list specs)])
    (define name (car spec))
    (define arity (cadr spec))
    (define facts (caddr spec))
    (define clauses (cadddr spec))
    (values name
            (relation-info name arity
              (list (variant-info
                     (for/list ([i (in-range arity)])
                       (param-info (string->symbol (format "X~a" i)) 'free))
                     (map clause-info clauses)
                     (map fact-row facts)))
              #f #f))))

(define cfg-strat (make-solver-config (hasheq 'semantics 'stratified)))
(define cfg-wf (make-solver-config (hasheq 'semantics 'well-founded)))

(define (compare-engines store goal-name query-vars)
  (parameterize ([current-relation-store store]
                 [current-relation-store-version 0]
                 [current-strata-cache #f])
    (define strat-answers
      (stratified-solve-goal cfg-strat store goal-name '() query-vars))
    (define wf-answers
      (stratified-solve-goal cfg-wf store goal-name '() query-vars))
    (values strat-answers wf-answers)))

;; ========================================
;; 1. Pure positive program
;; ========================================

(test-case "wf-comparison/positive: same answers for pure fact query"
  (define store
    (build-store (list 'color 1 '(("red") ("blue") ("green")) '())))
  (define-values (strat wf) (compare-engines store 'color '(X0)))
  (check-equal? (length strat) (length wf))
  (check-equal? (length strat) 3))

;; ========================================
;; 2. Positive rule chain
;; ========================================

(test-case "wf-comparison/rule-chain: same answers for positive rule"
  (define store
    (build-store
     (list 'base 1 '(("x") ("y")) '())
     (list 'derived 1 '()
           (list (list (goal-desc 'app (list 'base '(X0))))))))
  (define-values (strat wf) (compare-engines store 'derived '(X0)))
  (check-equal? (length strat) (length wf))
  (check-equal? (length strat) 2))

;; ========================================
;; 3. Stratifiable with 2 strata
;; ========================================

(test-case "wf-comparison/2-strata: a :- not b. b."
  (define inner-b (expr-goal-app 'b (list)))
  (define store
    (build-store
     (list 'b 0 '(()) '())
     (list 'a 0 '() (list (list (goal-desc 'not (list inner-b)))))))
  (define-values (strat wf) (compare-engines store 'a '()))
  ;; b is true → not b fails → a has no proofs
  (check-equal? (length strat) (length wf))
  (check-equal? (length strat) 0))

;; ========================================
;; 4. Stratifiable: a :- not b. (b undefined)
;; ========================================

(test-case "wf-comparison/undefined-neg-target: WF handles, stratified errors"
  ;; b is not defined in the store. WF engine handles this via closed-world
  ;; assumption. Stratified engine errors because solve-goal requires the
  ;; relation to exist. This is a case where WF is strictly more robust.
  (define inner-b (expr-goal-app 'b (list)))
  (define store
    (build-store
     (list 'a 0 '() (list (list (goal-desc 'not (list inner-b)))))))
  (parameterize ([current-relation-store store]
                 [current-relation-store-version 0]
                 [current-strata-cache #f])
    ;; WF handles undefined target gracefully
    (define wf-answers
      (stratified-solve-goal cfg-wf store 'a '() '()))
    (check-equal? (length wf-answers) 1)
    ;; Stratified engine errors on undefined relation
    (check-exn exn:fail?
      (lambda ()
        (stratified-solve-goal cfg-strat store 'a '() '())))))

;; ========================================
;; 5. 3-stratum chain
;; ========================================

(test-case "wf-comparison/3-strata: c :- not b. b :- not a. a."
  (define inner-a (expr-goal-app 'a (list)))
  (define inner-b (expr-goal-app 'b (list)))
  (define store
    (build-store
     (list 'a 0 '(()) '())
     (list 'b 0 '() (list (list (goal-desc 'not (list inner-a)))))
     (list 'c 0 '() (list (list (goal-desc 'not (list inner-b)))))))
  ;; a=true, b=false (not a fails), c=true (not b succeeds)
  (define-values (strat-a wf-a) (compare-engines store 'a '()))
  (check-equal? (length strat-a) (length wf-a))
  (define-values (strat-c wf-c) (compare-engines store 'c '()))
  (check-equal? (length strat-c) (length wf-c))
  (check-equal? (length strat-c) 1))

;; ========================================
;; 6. Empty store
;; ========================================

(test-case "wf-comparison/empty: WF handles empty store, stratified errors"
  (define store (hasheq))
  (parameterize ([current-relation-store store]
                 [current-relation-store-version 0]
                 [current-strata-cache #f])
    ;; WF engine handles missing relations gracefully
    (define wf
      (stratified-solve-goal cfg-wf store 'missing '() '()))
    (check-equal? (length wf) 0)
    ;; Stratified engine errors on unknown relation
    (check-exn exn:fail?
      (lambda ()
        (stratified-solve-goal cfg-strat store 'missing '() '())))))

;; ========================================
;; 7. Multiple facts
;; ========================================

(test-case "wf-comparison/multi-fact: same count for multiple facts"
  (define store
    (build-store (list 'item 1 '(("apple") ("banana") ("cherry") ("date") ("elderberry")) '())))
  (define-values (strat wf) (compare-engines store 'item '(X0)))
  (check-equal? (length strat) (length wf))
  (check-equal? (length strat) 5))

;; ========================================
;; 8. WF-only: odd cycle (stratified would reject)
;; ========================================

(test-case "wf-comparison/wf-only: WF handles odd cycle that stratified can't"
  ;; This test verifies that WF produces empty (unknown) results for odd cycles
  ;; while stratified would either error or produce incorrect results.
  (define inner-q (expr-goal-app 'q (list)))
  (define inner-p (expr-goal-app 'p (list)))
  (define store
    (build-store
     (list 'p 0 '() (list (list (goal-desc 'not (list inner-q)))))
     (list 'q 0 '() (list (list (goal-desc 'not (list inner-p)))))))
  (parameterize ([current-relation-store store]
                 [current-relation-store-version 0]
                 [current-strata-cache #f])
    ;; WF engine handles this gracefully
    (define wf-answers
      (stratified-solve-goal cfg-wf store 'p '() '()))
    (check-equal? (length wf-answers) 0 "WF: odd cycle → no definite answers")))

;; ========================================
;; 9. Answer format consistency
;; ========================================

(test-case "wf-comparison/format: both engines return hasheq answers"
  (define store
    (build-store (list 'color 1 '(("red") ("blue")) '())))
  (define-values (strat wf) (compare-engines store 'color '(X0)))
  (check-true (hash? (car strat)))
  (check-true (hash? (car wf))))

;; ========================================
;; 10. Default solver config is stratified
;; ========================================

(test-case "wf-comparison/default-config: default semantics is stratified"
  (check-equal? (solver-config-semantics default-solver-config) 'stratified))
