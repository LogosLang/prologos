#lang racket/base

;;;
;;; Tests for WFLE Phase 6: Error Handling and Edge Cases
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

;; ========================================
;; 1. Empty store
;; ========================================

(test-case "wf-errors/empty-store: empty results, no error"
  (define store (hasheq))
  (parameterize ([current-relation-store store])
    (define answers
      (wf-solve-goal default-solver-config store 'nonexistent '() '()))
    (check-equal? (length answers) 0)))

;; ========================================
;; 2. Missing relation
;; ========================================

(test-case "wf-errors/missing-relation: graceful handling"
  (define store
    (build-store (list 'color 1 '(("red")) '())))
  (parameterize ([current-relation-store store])
    (define answers
      (wf-solve-goal default-solver-config store 'missing '() '()))
    (check-equal? (length answers) 0)))

;; ========================================
;; 3. Negation of missing relation
;; ========================================

(test-case "wf-errors/negation-of-missing: not missing → succeeds (closed world)"
  (define inner-missing (expr-goal-app 'missing (list)))
  (define store
    (build-store
     (list 'p 0 '() (list (list (goal-desc 'not (list inner-missing)))))))
  (parameterize ([current-relation-store store])
    (define answers
      (wf-solve-goal default-solver-config store 'p '() '()))
    ;; missing is not defined → closed world → false → not missing succeeds
    (check-true (>= (length answers) 1))))

;; ========================================
;; 4. WF config creation
;; ========================================

(test-case "wf-errors/config: well-founded config is valid"
  (define cfg (make-solver-config (hasheq 'semantics 'well-founded)))
  (check-equal? (solver-config-semantics cfg) 'well-founded))

(test-case "wf-errors/config: default config is stratified"
  (check-equal? (solver-config-semantics default-solver-config) 'stratified))

;; ========================================
;; 5. Large convergence
;; ========================================

(test-case "wf-errors/convergence: 10-predicate chain converges"
  ;; p0 :- not p1. p1 :- not p2. ... p8 :- not p9. p9.
  ;; Even-length chain: alternating true/false
  (define specs
    (append
     (for/list ([i (in-range 9)])
       (define inner (expr-goal-app (string->symbol (format "p~a" (add1 i))) (list)))
       (list (string->symbol (format "p~a" i)) 0 '()
             (list (list (goal-desc 'not (list inner))))))
     (list (list 'p9 0 '(()) '()))))
  (define store (apply build-store specs))
  (parameterize ([current-relation-store store])
    ;; p9=true, p8=false, p7=true, p6=false, ..., p0=false (10 is even length)
    (define answers-p9 (wf-solve-goal default-solver-config store 'p9 '() '()))
    (check-true (>= (length answers-p9) 1) "p9 is a fact")
    ;; p0 should have a definite status (chain is stratifiable)
    (define answers-p0 (wf-solve-goal default-solver-config store 'p0 '() '()))
    ;; p0 :- not p1. p1 :- not p2. ... With 10 predicates, p0 = false (even chain from true)
    (check-equal? (length answers-p0) 0 "p0: even chain length from true → false")))
