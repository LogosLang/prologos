#lang racket/base

;;;
;;; bb-optimization.rkt — Branch-and-Bound Optimization for Narrowing
;;;
;;; Provides branch-and-bound (BB-min) optimization for the narrowing DFS.
;;; Maintains a global cost bound (mutable box) shared across all DFS branches.
;;; During search, branches whose cost lower bound exceeds the current best
;;; are pruned. When a complete solution is found, the bound is tightened.
;;;
;;; Phase 3c of FL Narrowing implementation.
;;;

(require racket/match
         "interval-domain.rkt"
         "syntax.rkt")

(provide
 ;; BB state
 (struct-out bb-state)
 current-bb-state
 make-bb-state
 ;; Cost operations
 bb-should-prune?
 bb-update-bound!
 bb-current-bound
 ;; Solution filtering
 bb-filter-optimal
 ;; Helpers
 extract-cost-value)

;; ========================================
;; BB state
;; ========================================

;; bb-state: branch-and-bound optimization state
;;   cost-bound: (box number) — best cost found so far (+inf.0 initially)
;;   cost-var: symbol — name of the cost variable to minimize
(struct bb-state (cost-bound cost-var) #:transparent)

;; Parameter: set to #f when no optimization, or a bb-state when active.
(define current-bb-state (make-parameter #f))

;; Create a fresh BB state for minimizing a cost variable.
(define (make-bb-state cost-var-name)
  (bb-state (box +inf.0) cost-var-name))

;; ========================================
;; Pruning
;; ========================================

;; bb-should-prune? : bb-state × hasheq → boolean
;;
;; Should we prune the current branch?
;; Check if the cost variable's interval lower bound >= current best cost.
;; intervals: hasheq of var-name → interval
(define (bb-should-prune? bb intervals)
  (define cost-var (bb-state-cost-var bb))
  (define best (unbox (bb-state-cost-bound bb)))
  (define cost-iv (hash-ref intervals cost-var #f))
  (cond
    [(not cost-iv) #f]  ;; no interval info → can't prune
    [(eqv? best +inf.0) #f]  ;; no solution found yet → can't prune
    [else
     (define lo (interval-lo cost-iv))
     (and (exact-integer? lo) (>= lo best))]))

;; ========================================
;; Bound update
;; ========================================

;; bb-update-bound! : bb-state × hasheq → void
;;
;; After finding a complete solution, update the cost bound if the
;; solution's cost is better (lower) than the current best.
;; subst: the solution substitution
(define (bb-update-bound! bb subst)
  (define cost-var (bb-state-cost-var bb))
  (define cost-val (hash-ref subst cost-var #f))
  (when cost-val
    (define cost-nat (expr->nat-val-bb cost-val))
    (when (and cost-nat (< cost-nat (unbox (bb-state-cost-bound bb))))
      (set-box! (bb-state-cost-bound bb) cost-nat))))

;; bb-current-bound : bb-state → number
;; Get the current best cost.
(define (bb-current-bound bb)
  (unbox (bb-state-cost-bound bb)))

;; ========================================
;; Solution filtering
;; ========================================

;; bb-filter-optimal : (listof hasheq) × bb-state → (listof hasheq)
;;
;; From a list of solutions, keep only those with optimal (minimum) cost.
(define (bb-filter-optimal solutions bb)
  (define cost-var (bb-state-cost-var bb))
  (define best (unbox (bb-state-cost-bound bb)))
  (cond
    [(eqv? best +inf.0) solutions]  ;; no bound → return all
    [else
     (filter
      (lambda (sol)
        (define cost-val (hash-ref sol cost-var #f))
        (cond
          [(not cost-val) #f]
          [else
           (define cost-nat (expr->nat-val-bb cost-val))
           (and cost-nat (= cost-nat best))]))
      solutions)]))

;; ========================================
;; Cost extraction helper
;; ========================================

;; extract-cost-value : hasheq × symbol → exact-nonneg-integer | #f
;; Extract the cost variable's value from a solution substitution.
(define (extract-cost-value subst cost-var)
  (define val (hash-ref subst cost-var #f))
  (and val (expr->nat-val-bb val)))

;; expr->nat-val-bb : expr → exact-nonneg-integer | #f
;; Convert a Prologos expression to a natural number.
;; Handles Peano (zero/suc), nat-val, and int literals.
(define (expr->nat-val-bb expr)
  (match expr
    [(expr-zero) 0]
    [(expr-nat-val n) n]
    [(expr-int n) (and (>= n 0) n)]
    [(expr-suc sub)
     (define sub-val (expr->nat-val-bb sub))
     (and sub-val (+ sub-val 1))]
    ;; Resolve through logic vars (follow chain)
    [(expr-logic-var _ _) #f]
    [_ #f]))
