#lang racket/base

;;;
;;; bilattice.rkt — Bilattice Variables for Well-Founded Semantics
;;;
;;; Pairs ascending and descending propagator cells into bilattice variables
;;; that provide three-valued reading (true / false / unknown / contradiction).
;;;
;;; A bilattice variable wraps two cells in the propagator network:
;;;   lower (ascending): starts at bot, rises via join — accumulates evidence FOR
;;;   upper (descending): starts at top, falls via meet — eliminates evidence AGAINST
;;;
;;; At quiescence, the gap [lower, upper] yields the approximation:
;;;   lower = upper → exact (definitely true or definitely false)
;;;   lower < upper → unknown (gap remains)
;;;   lower > upper → contradiction (impossible)
;;;
;;; Design reference: docs/tracking/2026-03-14_WFLE_IMPLEMENTATION.md Phase 2
;;;

(require racket/list
         "propagator.rkt")

(provide
 ;; Lattice descriptors
 (struct-out lattice-desc)
 bool-lattice
 make-set-lattice
 ;; Bilattice variables
 (struct-out bilattice-var)
 bilattice-new-var
 ;; Reading
 bilattice-read
 bilattice-read-bool
 ;; Writing
 bilattice-lower-write
 bilattice-upper-write
 ;; Consistency
 bilattice-add-consistency-propagator)

;; ========================================
;; Lattice Descriptors
;; ========================================

;; A lattice descriptor — provides the operations needed to construct
;; and read bilattice variables over lattice L.
;;
;; bot: L — bottom element (initial value for ascending cell)
;; top: L — top element (initial value for descending cell)
;; join: (L L -> L) — least upper bound (merge for ascending cell)
;; meet: (L L -> L) — greatest lower bound (merge for descending cell)
;; leq: (L L -> Bool) — lattice ordering
(struct lattice-desc (bot top join meet leq) #:transparent)

;; The Boolean lattice: {false, true} with false < true.
;; Used for standard logic programming (well-founded semantics over ground atoms).
(define bool-lattice
  (lattice-desc
   #f                          ;; bot = false
   #t                          ;; top = true
   (lambda (a b) (or a b))     ;; join = disjunction
   (lambda (a b) (and a b))    ;; meet = conjunction
   (lambda (a b)               ;; leq: false <= true
     (or (not a) b))))

;; The set-lattice over a universe U: P(U) with subset ordering.
;; bot = empty, top = U, join = union, meet = intersection.
;; Requires providing the universe set for top.
(define (make-set-lattice universe)
  (lattice-desc
   '()                                                    ;; bot = empty
   universe                                               ;; top = full universe
   (lambda (a b) (remove-duplicates (append a b)))        ;; join = union
   (lambda (a b) (filter (lambda (x) (member x b)) a))   ;; meet = intersection
   (lambda (a b)                                          ;; leq = subset
     (and (andmap (lambda (x) (member x b)) a) #t))))


;; ========================================
;; Bilattice Variables
;; ========================================

;; A bilattice variable: paired ascending + descending cells.
;; lower-cid: cell-id — ascending cell (starts at bot, rises via join)
;; upper-cid: cell-id — descending cell (starts at top, falls via meet)
;; lattice: lattice-desc — provides the base lattice operations
(struct bilattice-var (lower-cid upper-cid lattice) #:transparent)

;; Create a new bilattice variable in the network.
;; #:consistency-check? — when #t, adds a consistency propagator
;;   (lower <= upper). Default #f for Boolean lattice (invariant
;;   maintained by construction); #t for non-Boolean or during testing.
;; Returns: (values new-network bilattice-var)
(define (bilattice-new-var net lat #:consistency-check? [check? #f])
  ;; Create ascending (lower) cell — starts at bot
  (define-values (net1 lower-cid)
    (net-new-cell net
                  (lattice-desc-bot lat)
                  (lattice-desc-join lat)))
  ;; Create descending (upper) cell — starts at top
  (define-values (net2 upper-cid)
    (net-new-cell-desc net1
                       (lattice-desc-top lat)
                       (lattice-desc-meet lat)))
  (define bvar (bilattice-var lower-cid upper-cid lat))
  (define net3 (if check?
                   (let-values ([(n _pid) (bilattice-add-consistency-propagator net2 bvar)])
                     n)
                   net2))
  (values net3 bvar))

;; ========================================
;; Reading
;; ========================================

;; Read a bilattice variable's approximation state.
;; Returns: (list 'exact value) | (list 'approx lower upper) | 'contradiction
;;
;; For the Boolean bilattice:
;;   (true, true)   -> (list 'exact #t)      — definitely true
;;   (false, false)  -> (list 'exact #f)      — definitely false
;;   (false, true)   -> (list 'approx #f #t)  — unknown (gap remains)
;;   (true, false)   -> 'contradiction        — impossible
(define (bilattice-read net bvar)
  (define lo (net-cell-read net (bilattice-var-lower-cid bvar)))
  (define hi (net-cell-read net (bilattice-var-upper-cid bvar)))
  (define leq (lattice-desc-leq (bilattice-var-lattice bvar)))
  (cond
    [(equal? lo hi) (list 'exact lo)]
    [(leq lo hi) (list 'approx lo hi)]
    [else 'contradiction]))

;; Convenience for the Boolean bilattice (the common case for logic programming).
;; Returns: 'true | 'false | 'unknown | 'contradiction
(define (bilattice-read-bool net bvar)
  (define result (bilattice-read net bvar))
  (cond
    [(eq? result 'contradiction) 'contradiction]
    [(eq? (car result) 'exact) (if (cadr result) 'true 'false)]
    [else 'unknown]))

;; ========================================
;; Writing
;; ========================================

;; Write to the lower (ascending) cell of a bilattice variable.
;; The cell's merge-fn (join) handles monotonicity.
(define (bilattice-lower-write net bvar val)
  (net-cell-write net (bilattice-var-lower-cid bvar) val))

;; Write to the upper (descending) cell of a bilattice variable.
;; The cell's merge-fn (meet) handles monotonicity.
(define (bilattice-upper-write net bvar val)
  (net-cell-write net (bilattice-var-upper-cid bvar) val))

;; ========================================
;; Consistency
;; ========================================

;; Add a consistency propagator that enforces lower <= upper.
;; If lower > upper, sets contradiction.
;; Returns: (values new-network prop-id)
(define (bilattice-add-consistency-propagator net bvar)
  (define lower-cid (bilattice-var-lower-cid bvar))
  (define upper-cid (bilattice-var-upper-cid bvar))
  (define leq (lattice-desc-leq (bilattice-var-lattice bvar)))
  (net-add-propagator net
    (list lower-cid upper-cid)  ;; inputs
    '()                          ;; no outputs (side-effect: contradiction)
    (lambda (n)
      (define lo (net-cell-read n lower-cid))
      (define hi (net-cell-read n upper-cid))
      (if (leq lo hi)
          n  ;; consistent — no action
          (struct-copy prop-network n
            [contradiction lower-cid])))))
