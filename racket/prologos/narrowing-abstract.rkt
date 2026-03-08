#lang racket/base

;;;
;;; NARROWING ABSTRACT INTERPRETATION
;;; Phase 2a: Galois connection between Prologos terms and the interval
;;; abstract domain, plus known function interval abstractions.
;;;
;;; Provides:
;;;   - term->interval: extract an interval from a (possibly partial) term
;;;   - integer->peano: convert an exact integer to a suc/zero chain
;;;   - interval->peano-or-false: singleton → concrete term, else #f
;;;   - compute-arg-intervals: derive interval bounds for function arguments
;;;     given the function name and target value
;;;
;;; DEPENDENCIES: interval-domain.rkt, syntax.rkt, definitional-tree.rkt
;;;

(require racket/match
         "interval-domain.rkt"
         "definitional-tree.rkt"
         "syntax.rkt")

(provide
 ;; Galois connection
 term->interval
 integer->peano
 interval->peano-or-false
 ;; Function abstractions
 compute-arg-intervals
 ;; Re-export for convenience
 nat-type-name?
 type-initial-interval)

;; ========================================
;; Alpha: Term → Interval
;; ========================================

;; term->interval : expr → interval
;; Extract an interval from a Prologos expression.
;; Ground Nat terms yield a singleton; partial terms yield wider intervals.
(define (term->interval expr)
  (match expr
    [(expr-zero) (interval 0 0)]
    [(expr-suc sub)
     (define sub-iv (term->interval sub))
     (interval-add sub-iv (interval 1 1))]
    [(expr-nat-val n) (interval n n)]
    [(expr-int n) (interval n n)]
    [(expr-logic-var _ _) interval-nat-full]
    ;; Partially applied suc chain with var at bottom:
    ;; e.g. suc(suc(?x)) → [2, +inf)
    [_ interval-nat-full]))

;; ========================================
;; Gamma: Interval → Term
;; ========================================

;; integer->peano : exact-nonneg-integer → expr
;; Convert an exact non-negative integer to Peano representation.
(define (integer->peano n)
  (if (zero? n) (expr-zero) (expr-suc (integer->peano (- n 1)))))

;; interval->peano-or-false : interval → (or/c expr #f)
;; If the interval is a singleton [n,n], return the Peano term for n.
;; Otherwise return #f.
(define (interval->peano-or-false iv)
  (cond
    [(and (interval-singleton? iv)
          (exact-integer? (interval-lo iv))
          (>= (interval-lo iv) 0))
     (integer->peano (interval-lo iv))]
    [else #f]))

;; ========================================
;; Known function interval abstractions
;; ========================================

;; Each abstraction: (lambda (arg-intervals target-interval) → (listof interval))
;; Given the intervals for the function arguments and the target (return value),
;; computes narrowed intervals for each argument.

;; add(x, y) = z → use interval-add-constraint
(define (abstract-add args target)
  (cond
    [(< (length args) 2) #f]
    [else
     (define ix (car args))
     (define iy (cadr args))
     (define-values (nx ny _nz) (interval-add-constraint ix iy target))
     ;; Clamp to Nat range
     (list (interval-clamp-nat nx)
           (interval-clamp-nat ny))]))

;; sub(x, y) = z → use interval-sub-constraint
(define (abstract-sub args target)
  (cond
    [(< (length args) 2) #f]
    [else
     (define ix (car args))
     (define iy (cadr args))
     (define-values (nx ny _nz) (interval-sub-constraint ix iy target))
     (list (interval-clamp-nat nx)
           (interval-clamp-nat ny))]))

;; mul(x, y) = z → use interval-mul-constraint
(define (abstract-mul args target)
  (cond
    [(< (length args) 2) #f]
    [else
     (define ix (car args))
     (define iy (cadr args))
     (define-values (nx ny _nz) (interval-mul-constraint ix iy target))
     (list (interval-clamp-nat nx)
           (interval-clamp-nat ny))]))

;; Registry of known function abstractions.
;; Maps short-name symbol → abstraction function.
(define known-abstractions
  (hasheq 'add abstract-add
          'sub abstract-sub
          'mul abstract-mul))

;; ========================================
;; Compute argument intervals
;; ========================================

;; compute-arg-intervals : symbol × (listof expr) × expr → (or/c (listof interval) #f)
;; Given a function name, its argument expressions, and the target (return value),
;; compute interval bounds for each argument.
;; Returns #f if no interval abstraction is available for this function.
(define (compute-arg-intervals func-name arg-exprs target-expr)
  (define short (ctor-short-name func-name))
  (define abstraction (hash-ref known-abstractions short #f))
  (cond
    [abstraction
     (define arg-ivs (map term->interval arg-exprs))
     (define target-iv (term->interval target-expr))
     (abstraction arg-ivs target-iv)]
    [else #f]))
