#lang racket/base

;;;
;;; INTERVAL ABSTRACT DOMAIN
;;; Phase 2a of FL Narrowing: interval constraint domain for bounding
;;; numeric constructor enumeration during narrowing search.
;;;
;;; Provides an interval lattice [lo, hi] with:
;;;   - Lattice operations (merge = intersection, contradiction detection)
;;;   - Interval arithmetic (add, sub, mul, negate)
;;;   - Constraint propagators (x+y=z, x-y=z, x*y=z — narrow all three)
;;;   - Domain utilities (split, singleton?, size, contains?)
;;;
;;; Bounds are exact integers or +inf.0/-inf.0 for unbounded ranges.
;;; No project dependencies — pure leaf module.
;;;

(require racket/match)

(provide
 ;; Struct
 (struct-out interval)
 ;; Constants
 interval-nat-full
 interval-posint-full
 interval-int-full
 interval-empty
 ;; Type mapping
 type-initial-interval
 nat-type-name?
 ;; Lattice
 interval-merge
 interval-contradiction?
 ;; Predicates
 interval-singleton?
 interval-finite?
 interval-size
 interval-contains?
 ;; Arithmetic
 interval-add
 interval-sub
 interval-mul
 interval-negate
 interval-clamp-nat
 ;; Search
 interval-split
 ;; Constraint propagators
 interval-add-constraint
 interval-sub-constraint
 interval-mul-constraint)

;; ========================================
;; Struct
;; ========================================

;; An interval [lo, hi] representing a set of integers.
;; lo, hi: exact-integer or +inf.0 / -inf.0
;; Invariant: lo > hi means contradiction (empty set).
(struct interval (lo hi) #:transparent)

;; ========================================
;; Constants
;; ========================================

(define interval-nat-full    (interval 0 +inf.0))       ;; [0, +∞)
(define interval-posint-full (interval 1 +inf.0))       ;; [1, +∞)
(define interval-int-full    (interval -inf.0 +inf.0))  ;; (-∞, +∞)
(define interval-empty       (interval 1 0))             ;; contradiction

;; ========================================
;; Type mapping
;; ========================================

;; type-initial-interval : symbol → interval
;; Map a Prologos type-name to its initial (unconstrained) interval.
(define (type-initial-interval type-name)
  (case type-name
    [(Nat prologos::data::nat::Nat)    interval-nat-full]
    [(PosInt prologos::data::nat::PosInt) interval-posint-full]
    [(Int prologos::data::int::Int)    interval-int-full]
    [else interval-int-full]))

;; nat-type-name? : symbol → boolean
;; Is this a numeric type that benefits from interval analysis?
(define (nat-type-name? type-name)
  (memq type-name '(Nat PosInt Int
                     prologos::data::nat::Nat
                     prologos::data::nat::PosInt
                     prologos::data::int::Int)))

;; ========================================
;; Lattice operations
;; ========================================

;; interval-merge : interval × interval → interval
;; Intersection of two intervals (lattice meet).
;; [max(lo1, lo2), min(hi1, hi2)]
(define (interval-merge a b)
  (interval (ext-max (interval-lo a) (interval-lo b))
            (ext-min (interval-hi a) (interval-hi b))))

;; interval-contradiction? : interval → boolean
;; An interval is contradictory if lo > hi (empty set).
(define (interval-contradiction? iv)
  (ext> (interval-lo iv) (interval-hi iv)))

;; ========================================
;; Predicates
;; ========================================

;; interval-singleton? : interval → boolean
;; True if the interval contains exactly one value.
(define (interval-singleton? iv)
  (and (exact-integer? (interval-lo iv))
       (exact-integer? (interval-hi iv))
       (= (interval-lo iv) (interval-hi iv))))

;; interval-finite? : interval → boolean
;; True if both bounds are finite integers.
(define (interval-finite? iv)
  (and (exact-integer? (interval-lo iv))
       (exact-integer? (interval-hi iv))))

;; interval-size : interval → (or/c exact-nonneg-integer? #f)
;; Number of integers in the interval, or #f if infinite.
(define (interval-size iv)
  (cond
    [(interval-contradiction? iv) 0]
    [(interval-finite? iv)
     (+ (- (interval-hi iv) (interval-lo iv)) 1)]
    [else #f]))

;; interval-contains? : interval × exact-integer → boolean
(define (interval-contains? iv n)
  (and (ext>= n (interval-lo iv))
       (ext<= n (interval-hi iv))))

;; ========================================
;; Arithmetic
;; ========================================

;; interval-add : interval × interval → interval
;; [a,b] + [c,d] = [a+c, b+d]
(define (interval-add a b)
  (interval (ext+ (interval-lo a) (interval-lo b))
            (ext+ (interval-hi a) (interval-hi b))))

;; interval-sub : interval × interval → interval
;; [a,b] - [c,d] = [a-d, b-c]
(define (interval-sub a b)
  (interval (ext- (interval-lo a) (interval-hi b))
            (ext- (interval-hi a) (interval-lo b))))

;; interval-negate : interval → interval
;; -[a,b] = [-b, -a]
(define (interval-negate iv)
  (interval (ext-negate (interval-hi iv))
            (ext-negate (interval-lo iv))))

;; interval-mul : interval × interval → interval
;; [a,b] × [c,d] = [min(ac,ad,bc,bd), max(ac,ad,bc,bd)]
(define (interval-mul a b)
  (define products
    (list (ext* (interval-lo a) (interval-lo b))
          (ext* (interval-lo a) (interval-hi b))
          (ext* (interval-hi a) (interval-lo b))
          (ext* (interval-hi a) (interval-hi b))))
  (interval (ext-min-list products)
            (ext-max-list products)))

;; interval-clamp-nat : interval → interval
;; Intersect with [0, +∞) to ensure Nat range.
(define (interval-clamp-nat iv)
  (interval-merge iv interval-nat-full))

;; ========================================
;; Search: splitting
;; ========================================

;; interval-split : interval → (values interval interval)
;; Split [lo, hi] into [lo, mid] and [mid+1, hi].
;; Requires: finite, non-singleton interval.
;; For infinite intervals, clamps to a reasonable bound first.
(define (interval-split iv)
  (define lo (interval-lo iv))
  (define hi (interval-hi iv))
  ;; Clamp infinite bounds for splitting
  (define elo (if (exact-integer? lo) lo 0))
  (define ehi (if (exact-integer? hi) hi (+ elo 100)))
  (define mid (quotient (+ elo ehi) 2))
  (values (interval elo mid)
          (interval (+ mid 1) ehi)))

;; ========================================
;; Constraint propagators
;; ========================================

;; interval-add-constraint : interval × interval × interval
;;                           → (values interval interval interval)
;; Given x + y = z, narrow all three:
;;   x' = ix ∩ (iz - iy)
;;   y' = iy ∩ (iz - ix)
;;   z' = iz ∩ (ix + iy)
(define (interval-add-constraint ix iy iz)
  (values (interval-merge ix (interval-sub iz iy))
          (interval-merge iy (interval-sub iz ix))
          (interval-merge iz (interval-add ix iy))))

;; interval-sub-constraint : interval × interval × interval
;;                           → (values interval interval interval)
;; Given x - y = z, narrow all three:
;;   x = z + y  →  x' = ix ∩ (iz + iy)
;;   y = x - z  →  y' = iy ∩ (ix - iz)
;;   z = x - y  →  z' = iz ∩ (ix - iy)
(define (interval-sub-constraint ix iy iz)
  (values (interval-merge ix (interval-add iz iy))
          (interval-merge iy (interval-sub ix iz))
          (interval-merge iz (interval-sub ix iy))))

;; interval-mul-constraint : interval × interval × interval
;;                           → (values interval interval interval)
;; Given x * y = z, narrow all three.
;; Division-based narrowing for x and y when z is known.
(define (interval-mul-constraint ix iy iz)
  ;; z' = iz ∩ (ix * iy)
  (define new-iz (interval-merge iz (interval-mul ix iy)))
  ;; x' = ix ∩ (iz / iy) — only when iy doesn't span zero
  (define new-ix
    (cond
      [(and (not (interval-contains? iy 0))
            (interval-finite? iy) (interval-finite? new-iz))
       (interval-merge ix (interval-div-approx new-iz iy))]
      [else ix]))
  ;; y' = iy ∩ (iz / ix) — only when ix doesn't span zero
  (define new-iy
    (cond
      [(and (not (interval-contains? new-ix 0))
            (interval-finite? new-ix) (interval-finite? new-iz))
       (interval-merge iy (interval-div-approx new-iz new-ix))]
      [else iy]))
  (values new-ix new-iy new-iz))

;; ========================================
;; Extended arithmetic helpers
;; ========================================

;; Arithmetic on extended integers (exact-integer or +inf.0 / -inf.0).

(define (ext+ a b)
  (cond
    [(and (exact-integer? a) (exact-integer? b)) (+ a b)]
    ;; inf + (-inf) = indeterminate, use wider bound
    [(and (eqv? a +inf.0) (eqv? b -inf.0)) +inf.0]
    [(and (eqv? a -inf.0) (eqv? b +inf.0)) -inf.0]
    [(or (eqv? a +inf.0) (eqv? b +inf.0)) +inf.0]
    [(or (eqv? a -inf.0) (eqv? b -inf.0)) -inf.0]
    [(exact-integer? a) b]
    [else a]))

(define (ext- a b)
  (ext+ a (ext-negate b)))

(define (ext-negate a)
  (cond
    [(exact-integer? a) (- a)]
    [(eqv? a +inf.0) -inf.0]
    [(eqv? a -inf.0) +inf.0]
    [else a]))

(define (ext* a b)
  ;; Handle 0 * inf = 0 (for interval arithmetic convention)
  (cond
    [(or (eqv? a 0) (eqv? b 0)) 0]
    [(and (exact-integer? a) (exact-integer? b)) (* a b)]
    ;; Sign-based infinity multiplication
    [(and (ext-positive? a) (ext-positive? b)) +inf.0]
    [(and (ext-negative? a) (ext-negative? b)) +inf.0]
    [(or (and (ext-positive? a) (ext-negative? b))
         (and (ext-negative? a) (ext-positive? b))) -inf.0]
    [else 0]))

(define (ext-positive? a)
  (cond [(exact-integer? a) (> a 0)]
        [(eqv? a +inf.0) #t]
        [else #f]))

(define (ext-negative? a)
  (cond [(exact-integer? a) (< a 0)]
        [(eqv? a -inf.0) #t]
        [else #f]))

(define (ext> a b)
  (cond
    [(and (exact-integer? a) (exact-integer? b)) (> a b)]
    [(eqv? a +inf.0) (not (eqv? b +inf.0))]
    [(eqv? b -inf.0) (not (eqv? a -inf.0))]
    [(eqv? a -inf.0) #f]
    [(eqv? b +inf.0) #f]
    [else #f]))

(define (ext>= a b)
  (or (equal? a b) (ext> a b)))

(define (ext<= a b)
  (ext>= b a))

(define (ext-max a b)
  (if (ext> a b) a b))

(define (ext-min a b)
  (if (ext> a b) b a))

(define (ext-min-list lst)
  (foldl ext-min (car lst) (cdr lst)))

(define (ext-max-list lst)
  (foldl ext-max (car lst) (cdr lst)))

;; Approximate integer division for interval bounds.
;; [a,b] / [c,d] where c,d don't span zero.
(define (interval-div-approx num den)
  (define lo-n (interval-lo num))
  (define hi-n (interval-hi num))
  (define lo-d (interval-lo den))
  (define hi-d (interval-hi den))
  (define candidates
    (list (safe-div lo-n lo-d)
          (safe-div lo-n hi-d)
          (safe-div hi-n lo-d)
          (safe-div hi-n hi-d)))
  (define finite-candidates (filter exact-integer? candidates))
  (cond
    [(null? finite-candidates) (interval -inf.0 +inf.0)]
    [else
     (interval (apply min finite-candidates)
               (apply max finite-candidates))]))

(define (safe-div a b)
  (cond
    [(eqv? b 0) +inf.0]
    [(and (exact-integer? a) (exact-integer? b))
     ;; Use floor division for lo, ceiling for hi
     (quotient a b)]
    [else +inf.0]))
