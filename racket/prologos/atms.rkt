#lang racket/base

;;;
;;; atms.rkt — Persistent Assumption-Based Truth Maintenance System (ATMS)
;;;
;;; A persistent ATMS following de Kleer 1986, implemented as a pure value.
;;; All operations are pure: they take an ATMS and return a new ATMS.
;;; The old ATMS is never modified (structural sharing via hasheq).
;;;
;;; Key concepts:
;;;   - Assumption: a hypothetical premise with a name and datum
;;;   - Supported value: a value tagged with the set of assumptions that justify it
;;;   - TMS cell: holds multiple contingent values (each with different support)
;;;   - Worldview (believed): the set of currently believed assumptions
;;;   - Nogood: a set of assumptions known to be mutually inconsistent
;;;   - amb: creates a choice point with mutually exclusive alternatives
;;;
;;; This is Racket-level infrastructure with no dependency on Prologos
;;; syntax or type system. The ATMS wraps a PropNetwork for computation.
;;;
;;; Design reference: docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org §5
;;;

(require "propagator.rkt")

(provide
 ;; Core structs
 (struct-out assumption-id)
 (struct-out assumption)
 (struct-out supported-value)
 (struct-out tms-cell)
 (struct-out atms)
 ;; Construction
 atms-empty
 ;; Assumption management
 atms-assume
 atms-retract
 ;; Nogood management
 atms-add-nogood
 atms-consistent?
 ;; Worldview
 atms-with-worldview
 ;; Choice points
 atms-amb
 ;; TMS cell operations
 atms-read-cell
 atms-write-cell
 ;; Solving
 atms-solve-all
 ;; Helpers
 assumption-id-hash
 hash-subset?)

;; ========================================
;; Core structs
;; ========================================

;; Identity type for assumptions (Nat wrapper, like cell-id/prop-id)
(struct assumption-id (n) #:transparent)

;; An assumption (hypothetical premise)
;; name: symbol or keyword (for display/debugging)
;; datum: the value this assumption asserts (opaque Racket value)
(struct assumption (name datum) #:transparent)

;; A value tagged with its justification (support set)
;; value: any Racket value (the lattice/data value)
;; support: hasheq assumption-id → #t (the assumptions that justify this value)
(struct supported-value (value support) #:transparent)

;; A TMS cell: holds multiple contingent values
;; values: list of supported-value (newest first)
;; dependents: hasheq prop-id → #t (propagators watching this cell)
(struct tms-cell (values dependents) #:transparent)

;; The persistent ATMS
;; network: prop-network (underlying computation engine)
;; assumptions: hasheq assumption-id → assumption
;; nogoods: list of hasheq (each is assumption-id → #t, a bad assumption set)
;; tms-cells: hasheq cell-id → tms-cell
;; next-assumption: Nat (monotonic counter for fresh IDs)
;; believed: hasheq assumption-id → #t (current worldview)
;; amb-groups: list of (list assumption-id) — one group per amb call
(struct atms
  (network assumptions nogoods tms-cells next-assumption believed amb-groups)
  #:transparent)

;; ========================================
;; Helpers
;; ========================================

;; Identity hash for assumption-ids (same pattern as cell-id-hash)
(define (assumption-id-hash aid)
  (assumption-id-n aid))

;; Check if all keys in small-hash exist in big-hash (set subset)
(define (hash-subset? small big)
  (for/and ([(k _) (in-hash small)])
    (hash-has-key? big k)))

;; Cartesian product of a list of lists
;; (cartesian-product '((a b) (1 2))) → '((a 1) (a 2) (b 1) (b 2))
(define (cartesian-product lists)
  (cond
    [(null? lists) '(())]
    [else
     (define first-list (car lists))
     (define rest-products (cartesian-product (cdr lists)))
     (for*/list ([x (in-list first-list)]
                 [rest (in-list rest-products)])
       (cons x rest))]))

;; Convert a list of assumption-ids to a hasheq set
(define (aids->set aids)
  (for/hasheq ([aid (in-list aids)])
    (values aid #t)))

;; ========================================
;; Construction
;; ========================================

;; Create an empty ATMS, optionally wrapping a PropNetwork.
(define (atms-empty [network #f])
  (atms (or network (make-prop-network))
        (hasheq)    ;; assumptions
        '()         ;; nogoods
        (hasheq)    ;; tms-cells
        0           ;; next-assumption
        (hasheq)    ;; believed
        '()))       ;; amb-groups

;; ========================================
;; Assumption management
;; ========================================

;; Create a new assumption. Returns (values new-atms assumption-id).
;; The assumption is automatically added to the believed set.
(define (atms-assume a name datum)
  (define aid (assumption-id (atms-next-assumption a)))
  (define asn (assumption name datum))
  (values
   (struct-copy atms a
     [assumptions (hash-set (atms-assumptions a) aid asn)]
     [next-assumption (+ 1 (atms-next-assumption a))]
     [believed (hash-set (atms-believed a) aid #t)])
   aid))

;; Retract an assumption: remove from believed set.
;; The assumption still exists in the assumptions map (for history/nogoods).
(define (atms-retract a aid)
  (struct-copy atms a
    [believed (hash-remove (atms-believed a) aid)]))

;; ========================================
;; Nogood management
;; ========================================

;; Record a nogood: a set of assumptions known to be inconsistent.
;; nogood-set: hasheq assumption-id → #t
(define (atms-add-nogood a nogood-set)
  (struct-copy atms a
    [nogoods (cons nogood-set (atms-nogoods a))]))

;; Check if an assumption set is consistent (avoids all nogoods).
;; assumption-set: hasheq assumption-id → #t
(define (atms-consistent? a assumption-set)
  (not (for/or ([ng (in-list (atms-nogoods a))])
         (hash-subset? ng assumption-set))))

;; ========================================
;; Worldview management
;; ========================================

;; Switch worldview: returns new ATMS with different believed set.
;; new-believed: hasheq assumption-id → #t
(define (atms-with-worldview a new-believed)
  (struct-copy atms a [believed new-believed]))

;; ========================================
;; Choice points (amb)
;; ========================================

;; Create a choice point with n alternatives.
;; Each alternative gets a fresh assumption. Mutual exclusion nogoods
;; are recorded for every pair of alternatives.
;;
;; Returns (values new-atms (list assumption-id ...))
;; The assumption-ids correspond 1:1 with the alternatives.
(define (atms-amb a alternatives)
  ;; 1. Create fresh assumptions, one per alternative
  (define-values (a* hyps-rev)
    (for/fold ([a a] [hs '()])
              ([alt (in-list alternatives)]
               [i (in-naturals)])
      (define-values (a2 hid) (atms-assume a (string->symbol (format "h~a" i)) alt))
      (values a2 (cons hid hs))))
  (define hyps (reverse hyps-rev))
  ;; 2. Record mutual exclusion: every pair of hypotheses is a nogood
  (define a**
    (for*/fold ([a a*])
               ([i (in-range (length hyps))]
                [j (in-range (+ i 1) (length hyps))])
      (define h1 (list-ref hyps i))
      (define h2 (list-ref hyps j))
      (atms-add-nogood a (hasheq h1 #t h2 #t))))
  ;; 3. Record amb group for solve-all enumeration
  (define a***
    (struct-copy atms a**
      [amb-groups (append (atms-amb-groups a**) (list hyps))]))
  (values a*** hyps))

;; ========================================
;; TMS cell operations
;; ========================================

;; Read the value from a TMS cell under the current worldview.
;; Finds the first supported value whose support ⊆ believed.
;; Returns 'bot if no compatible value exists.
;; cell-key: any hashable key (typically a cell-id)
(define (atms-read-cell a cell-key)
  (define tc (hash-ref (atms-tms-cells a) cell-key #f))
  (if (not tc)
      'bot
      (let loop ([svs (tms-cell-values tc)])
        (cond
          [(null? svs) 'bot]
          [(hash-subset? (supported-value-support (car svs)) (atms-believed a))
           (supported-value-value (car svs))]
          [else (loop (cdr svs))]))))

;; Write a supported value to a TMS cell.
;; value: the data value
;; support: hasheq assumption-id → #t
;; cell-key: any hashable key (typically a cell-id)
(define (atms-write-cell a cell-key value support)
  (define sv (supported-value value support))
  (define tc (hash-ref (atms-tms-cells a) cell-key
                       (tms-cell '() (hasheq))))
  (define tc* (struct-copy tms-cell tc
                [values (cons sv (tms-cell-values tc))]))
  (struct-copy atms a
    [tms-cells (hash-set (atms-tms-cells a) cell-key tc*)]))

;; ========================================
;; Solving
;; ========================================

;; Enumerate all consistent worldviews from amb groups and collect
;; the goal cell's value under each.
;;
;; Algorithm:
;;   1. Compute Cartesian product of amb-groups (one assumption per group)
;;   2. Filter for consistency (no nogood subset of the worldview)
;;   3. For each consistent worldview, read the goal cell's value
;;   4. Collect distinct answers (deduplicated)
;;
;; Returns a list of distinct values (possibly empty).
(define (atms-solve-all a goal-cell-key)
  (define groups (atms-amb-groups a))
  (cond
    [(null? groups)
     ;; No amb: just read the cell under current worldview
     (define val (atms-read-cell a goal-cell-key))
     (if (eq? val 'bot) '() (list val))]
    [else
     ;; Enumerate all combinations
     (define combos (cartesian-product groups))
     (define answers
       (for/fold ([acc '()])
                 ([combo (in-list combos)])
         (define believed (aids->set combo))
         (if (atms-consistent? a believed)
             (let* ([a* (atms-with-worldview a believed)]
                    [val (atms-read-cell a* goal-cell-key)])
               (if (or (eq? val 'bot) (member val acc))
                   acc
                   (cons val acc)))
             acc)))
     (reverse answers)]))
