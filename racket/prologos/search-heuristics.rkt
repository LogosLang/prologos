#lang racket/base

;;;
;;; search-heuristics.rkt — Configurable Search Heuristics for Narrowing
;;;
;;; Provides orthogonal search configuration for the narrowing DFS:
;;;   1. Value ordering: which constructor to try first at each DT branch
;;;   2. Search mode: how many solutions to find (all, first, at-most-N)
;;;   3. Iterative deepening: progressive fuel increase for depth-bounded search
;;;
;;; Pure leaf module — no project dependencies.
;;;
;;; Phase 3b of FL Narrowing implementation.
;;;

(require racket/match
         racket/list)

(provide
 ;; Config struct
 (struct-out narrow-search-config)
 default-narrow-search-config
 current-narrow-search-config
 ;; Value ordering
 reorder-dt-children
 ;; Bounded enumeration
 bounded-append-map
 ;; Iterative deepening
 iterative-deepening-search
 ;; Solver bridge
 narrow-config-from-solver
 ;; Solution limit management
 make-solution-counter
 solution-counter-remaining
 solution-counter-decrement!
 solution-counter-exhausted?)

;; ========================================
;; Search configuration
;; ========================================

;; narrow-search-config:
;;   value-order: 'source-order | 'indomain-min | 'indomain-max | 'random
;;   search-mode: 'all | 'first | (list 'at-most n)
;;   iterative?: #t for iterative deepening, #f for fixed fuel
(struct narrow-search-config (value-order search-mode iterative?) #:transparent)

(define default-narrow-search-config
  (narrow-search-config 'source-order 'all #f))

(define current-narrow-search-config
  (make-parameter default-narrow-search-config))

;; ========================================
;; Value ordering
;; ========================================

;; reorder-dt-children : (listof (cons ctor-name . dt-node)) × symbol
;;                       → (listof (cons ctor-name . dt-node))
;;
;; Reorder DT branch children based on value-order strategy.
;; Exempt (dt-exempt) nodes are always placed LAST, regardless of ordering.
;; The exempt-pred parameter is a predicate on the cdr (tree node).
(define (reorder-dt-children children value-order exempt-pred)
  (case value-order
    [(source-order indomain-min)
     ;; source-order and indomain-min both use the natural DT order.
     ;; For Nat, the DT order is (zero suc) which is already min-first.
     children]
    [(indomain-max)
     ;; Reverse non-exempt children; exempt nodes stay at end.
     (define-values (non-exempt exempt)
       (partition (lambda (c) (not (exempt-pred (cdr c)))) children))
     (append (reverse non-exempt) exempt)]
    [(random)
     ;; Shuffle non-exempt children; exempt nodes stay at end.
     (define-values (non-exempt exempt)
       (partition (lambda (c) (not (exempt-pred (cdr c)))) children))
     (append (shuffle non-exempt) exempt)]
    [else children]))

;; ========================================
;; Solution limit via mutable box
;; ========================================

;; A solution counter tracks how many more solutions to collect.
;; 'unlimited means no limit (search-mode = 'all).
;; A box containing a natural number counts down.
(define (make-solution-counter search-mode)
  (match search-mode
    ['all 'unlimited]
    ['first (box 1)]
    [(list 'at-most n) (box n)]
    [_ 'unlimited]))

(define (solution-counter-remaining counter)
  (match counter
    ['unlimited +inf.0]
    [(box n) n]))

(define (solution-counter-decrement! counter [by 1])
  (match counter
    ['unlimited (void)]
    [(? box?)
     (set-box! counter (max 0 (- (unbox counter) by)))]))

(define (solution-counter-exhausted? counter)
  (match counter
    ['unlimited #f]
    [(box n) (<= n 0)]))

;; ========================================
;; Bounded append-map
;; ========================================

;; bounded-append-map : (a → (listof b)) × (listof a) × solution-counter
;;                      → (listof b)
;;
;; Like append-map, but stops early when the solution counter is exhausted.
;; Each call to f may produce multiple results; those results are accumulated
;; and the counter is decremented by the count of results found.
(define (bounded-append-map f lst counter)
  (cond
    [(or (null? lst) (solution-counter-exhausted? counter))
     '()]
    [else
     (define results (f (car lst)))
     ;; Truncate results to remaining count when limited
     (define remaining (solution-counter-remaining counter))
     (define capped
       (if (> (length results) remaining)
           (take results (inexact->exact (floor remaining)))
           results))
     (solution-counter-decrement! counter (length capped))
     (append capped (bounded-append-map f (cdr lst) counter))]))

;; ========================================
;; Iterative deepening
;; ========================================

;; iterative-deepening-search :
;;   (nat → (listof hasheq)) × nat → (listof hasheq)
;;
;; Calls search-fn with progressively increasing fuel:
;; 1, 2, 4, 8, 16, ... up to max-fuel.
;; Returns the first non-empty result set.
;; If all levels return empty, returns '().
(define (iterative-deepening-search search-fn max-fuel)
  (let loop ([fuel 1])
    (cond
      [(> fuel max-fuel) '()]
      [else
       (define results (search-fn fuel))
       (if (pair? results)
           results
           (loop (min (* fuel 2) (+ max-fuel 1))))])))
;; Note: (min (* fuel 2) (+ max-fuel 1)) ensures the last iteration
;; uses exactly max-fuel+1 to trigger the (> fuel max-fuel) exit
;; when fuel doubles past max-fuel.

;; ========================================
;; Solver config bridge
;; ========================================

;; narrow-config-from-solver : solver-config-like → narrow-search-config
;;
;; Extract narrowing search config from a solver config.
;; solver-config is opaque here — we use duck-typing via a getter function.
;; Accepts a function (key default) → value, matching solver-config-get.
(define (narrow-config-from-solver get-fn)
  (narrow-search-config
   (get-fn 'narrow-value-order 'source-order)
   (get-fn 'narrow-search 'all)
   (get-fn 'narrow-iterative #f)))
