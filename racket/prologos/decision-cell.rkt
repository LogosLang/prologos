#lang racket/base

;;;
;;; decision-cell.rkt — Decision domain lattice for ATMS solver
;;;
;;; BSP-LE Track 2 Phase 1: Pure lattice operations for decision cells.
;;; Follows constraint-cell.rkt convention (Critical 1.1):
;;;   bot = unconstrained (all alternatives viable)
;;;   top = contradicted (no alternatives left)
;;;   merge = set-intersection (narrowing)
;;;
;;; A decision cell tracks which alternatives survive at a choice point.
;;; Each `atms-amb` call creates one group-level decision cell on the
;;; outer network. Alternatives = constructors (SRE structural lattice).
;;; Nogoods narrow decision cells by eliminating alternatives.
;;;
;;; Lattice structure:
;;;
;;;   decision-bot               (⊥, all alternatives viable — unconstrained)
;;;        ↓
;;;   decision-set S             (partially narrowed — S ⊆ alternatives)
;;;        ↓
;;;   decision-one h             (fully committed — single alternative)
;;;        ↓
;;;   decision-top               (⊤, contradiction — no alternatives left)
;;;
;;; Merge (= narrowing) = set intersection:
;;;   bot ⊔ S = S
;;;   S1 ⊔ S2 = S1 ∩ S2
;;;   {h} = one h (singleton optimization)
;;;   {} = top (empty = contradiction)
;;;
;;; Also provides: nogood lattice (set of sets, union merge),
;;; assumptions accumulator (set, union merge), counter (nat, max merge).
;;;
;;; PURE LEAF — requires only racket/base. No project dependencies.
;;; Cell creation happens in the consumer (solver infrastructure),
;;; not here. This module defines lattice VALUES and OPERATIONS only.
;;;
;;; Design reference:
;;;   docs/tracking/2026-04-07_BSP_LE_TRACK2_DESIGN.md §2.5a, §2.6
;;;   constraint-cell.rkt (convention model)
;;;

(provide
 ;; === Decision Domain Lattice ===
 ;; Sentinels
 decision-bot decision-top
 decision-bot? decision-top?
 ;; Structs
 (struct-out decision-set)
 (struct-out decision-one)
 ;; Merge & contradiction
 decision-domain-merge
 decision-domain-contradicts?
 ;; Constructors
 decision-from-alternatives
 ;; Queries
 decision-committed?
 decision-committed-assumption
 decision-alternatives
 decision-domain-narrow
 ;; Debug
 decision->datum
 ;; Hasse diagram operations (bitmask-based, O(1))
 decision-bitmask
 aids->bitmask
 popcount
 hamming-distance
 hasse-adjacent?
 subcube-member?

 ;; === Commitment Cell ===
 commitment-initial
 commitment-merge
 commitment-contradicts?
 commitment-filled-count
 commitment-provenance
 commitment-remaining-group
 ;; === Nogood Install Request ===
 (struct-out nogood-install-request)

 ;; === Nogood Lattice ===
 nogood-empty
 nogood-merge
 nogood-add
 nogood-member?

 ;; === Assumptions Accumulator ===
 assumptions-empty
 assumptions-merge
 assumptions-add

 ;; === Counter (Monotone Nat) ===
 counter-merge)


;; ============================================================
;; Decision Domain Lattice
;; ============================================================

;; Sentinel values
(define decision-bot 'decision-bot)
(define decision-top 'decision-top)

(define (decision-bot? v) (eq? v 'decision-bot))
(define (decision-top? v) (eq? v 'decision-top))

;; Multiple alternatives remain (partially narrowed).
;; alternatives: hasheq assumption-id → #t
;; bitmask: exact-nonneg-integer — bit i = 1 iff assumption-id i is viable
;;   Additive field for O(1) Hasse diagram operations (Q6).
;;   Derived from alternatives at creation; maintained through merge/narrow.
;; Invariant: (hash-count alternatives) >= 2
(struct decision-set (alternatives bitmask) #:transparent)

;; Single alternative (fully committed — singleton).
;; assumption: the surviving assumption-id
(struct decision-one (assumption) #:transparent)

;; ============================================================
;; Constructor: from a list of assumption-ids
;; ============================================================
;; Normalizes to the appropriate lattice value:
;;   0 alternatives → decision-top
;;   1 alternative  → decision-one
;;   N alternatives → decision-set
;; Optional bitmask: if provided, used directly. If #f, computed from
;; aid-integers (a list of integer bit positions, one per alternative).
;; Callers that have assumption-id structs extract integers via assumption-id-n.
;; This keeps decision-cell.rkt as a pure leaf (no atms.rkt dependency).
(define (decision-from-alternatives aids [bitmask #f] [aid-integers #f])
  (cond
    [(null? aids) decision-top]
    [(null? (cdr aids)) (decision-one (car aids))]
    [else
     (define mask (or bitmask
                      (if aid-integers
                          (aids->bitmask aid-integers)
                          0)))  ;; 0 = bitmask unknown (backward compat)
     (decision-set (for/hasheq ([a (in-list aids)])
                     (values a #t))
                   mask)]))

;; ============================================================
;; Merge (= constraint-cell convention: set intersection = narrowing)
;; ============================================================
;; Following constraint-cell.rkt pattern exactly:
;;   bot ⊔ x = x  (unconstrained meets anything = that thing)
;;   x ⊔ bot = x
;;   top ⊔ x = top (contradiction absorbs)
;;   x ⊔ top = top
;;   one(a) ⊔ one(a) = one(a)  (same = keep)
;;   one(a) ⊔ one(b) = top     (different singletons = contradiction)
;;   set(S) ⊔ set(T) = normalize(S ∩ T)
;;   set(S) ⊔ one(a) = one(a) if a ∈ S, else top
;;   one(a) ⊔ set(S) = one(a) if a ∈ S, else top
(define (decision-domain-merge old new)
  (cond
    ;; Identity: bot ⊔ x = x
    [(decision-bot? old) new]
    [(decision-bot? new) old]
    ;; Absorbing: top ⊔ x = top
    [(decision-top? old) decision-top]
    [(decision-top? new) decision-top]
    ;; one ⊔ one
    [(and (decision-one? old) (decision-one? new))
     (if (equal? (decision-one-assumption old) (decision-one-assumption new))
         old  ;; same singleton
         decision-top)]  ;; different singletons = contradiction
    ;; set ⊔ set
    [(and (decision-set? old) (decision-set? new))
     (define s1 (decision-set-alternatives old))
     (define s2 (decision-set-alternatives new))
     ;; Intersection: keep only keys present in both
     (define intersection
       (for/hasheq ([(k _) (in-hash s1)]
                    #:when (hash-has-key? s2 k))
         (values k #t)))
     ;; Bitmask: AND of bitmasks = intersection (O(1))
     (define mask (bitwise-and (decision-set-bitmask old)
                               (decision-set-bitmask new)))
     (normalize-decision intersection mask)]
    ;; set ⊔ one: keep the one if it's in the set
    [(and (decision-set? old) (decision-one? new))
     (if (hash-has-key? (decision-set-alternatives old) (decision-one-assumption new))
         new
         decision-top)]
    ;; one ⊔ set: keep the one if it's in the set
    [(and (decision-one? old) (decision-set? new))
     (if (hash-has-key? (decision-set-alternatives new) (decision-one-assumption old))
         old
         decision-top)]
    ;; Fallback (shouldn't reach here)
    [else decision-top]))

;; Normalize a hasheq set to the appropriate lattice value.
;; bitmask: the pre-computed bitmask for these alternatives.
;; If 0 (unknown), the bitmask is unavailable (backward compat).
(define (normalize-decision alternatives [bitmask 0])
  (define count (hash-count alternatives))
  (cond
    [(= count 0) decision-top]
    [(= count 1)
     (define pos (hash-iterate-first alternatives))
     (decision-one (hash-iterate-key alternatives pos))]
    [else (decision-set alternatives bitmask)]))

;; Contradiction predicate (for net-new-cell contradicts? parameter)
(define (decision-domain-contradicts? v)
  (decision-top? v))

;; ============================================================
;; Queries
;; ============================================================

;; Is this decision committed (singleton)?
(define (decision-committed? v)
  (decision-one? v))

;; Extract the committed assumption-id (or #f)
(define (decision-committed-assumption v)
  (if (decision-one? v)
      (decision-one-assumption v)
      #f))

;; Extract the current set of viable alternatives as a list
(define (decision-alternatives v)
  (cond
    [(decision-bot? v) '()]  ;; bot = we don't know the alternatives yet
    [(decision-top? v) '()]  ;; top = no alternatives
    [(decision-one? v) (list (decision-one-assumption v))]
    [(decision-set? v) (hash-keys (decision-set-alternatives v))]
    [else '()]))

;; Narrow: remove a specific alternative from the domain.
;; excluded-bit: optional integer bit position for the excluded assumption.
;;   When provided, the bitmask is updated precisely (clear one bit, O(1)).
;;   When #f, the bitmask may be stale (has extra bit) — callers needing
;;   precise bitmask should provide the bit. Pure leaf: no assumption-id-n here.
;; Returns the new decision value.
(define (decision-domain-narrow v excluded-aid [excluded-bit #f])
  (cond
    [(decision-bot? v) v]
    [(decision-top? v) v]
    [(decision-one? v)
     (if (equal? (decision-one-assumption v) excluded-aid)
         decision-top
         v)]
    [(decision-set? v)
     (define remaining (hash-remove (decision-set-alternatives v) excluded-aid))
     (define old-mask (decision-set-bitmask v))
     (define new-mask
       (if excluded-bit
           (bitwise-and old-mask (bitwise-not (bit->mask excluded-bit)))
           old-mask))  ;; stale if bit not provided
     (normalize-decision remaining new-mask)]
    [else v]))

;; Debug: convert to a datum for display
(define (decision->datum v)
  (cond
    [(decision-bot? v) 'decision-bot]
    [(decision-top? v) 'decision-top]
    [(decision-one? v) `(decision-one ,(decision-one-assumption v))]
    [(decision-set? v) `(decision-set ,(hash-keys (decision-set-alternatives v)))]
    [else v]))


;; ============================================================
;; Hasse Diagram Operations (D.7: hypercube structure, SRE Q6)
;; ============================================================
;; The decision domain's Hasse diagram IS a (dual) hypercube Q_n.
;; These operations exploit the bitmask representation for O(1)
;; parallel compute structure queries. See CRITIQUE_METHODOLOGY.org
;; SRE Lattice Lens Q6 and the hypercube research addendum.

;; Convert an integer bit position to a single-bit mask.
(define (bit->mask n)
  (arithmetic-shift 1 n))

;; Compute bitmask from a list of integer bit positions.
;; Callers extract the integer from assumption-id via assumption-id-n.
;; decision-cell.rkt stays a pure leaf — no atms.rkt dependency.
(define (aids->bitmask aid-integers)
  (for/fold ([mask 0]) ([n (in-list aid-integers)])
    (bitwise-ior mask (bit->mask n))))

;; Extract the bitmask from any decision value.
;; bot → 0 (unknown alternatives)
;; top → 0 (empty domain)
;; one(h) → needs bit position; use optional aid->int accessor or return 0
;; set(S, bitmask) → the stored bitmask
;; aid->int: optional (assumption-id → integer) function for decision-one.
;;   Callers with access to assumption-id-n pass it here.
;;   Pure leaf: decision-cell.rkt can't import atms.rkt.
(define (decision-bitmask v [aid->int #f])
  (cond
    [(decision-bot? v) 0]
    [(decision-top? v) 0]
    [(decision-one? v)
     (if aid->int
         (bit->mask (aid->int (decision-one-assumption v)))
         0)]  ;; no accessor → bitmask unavailable for singletons
    [(decision-set? v) (decision-set-bitmask v)]
    [else 0]))

;; Population count: number of set bits.
;; Uses Kernighan's trick: O(set bits), not O(total bits).
(define (popcount n)
  (let loop ([n n] [count 0])
    (if (zero? n) count
        (loop (bitwise-and n (sub1 n)) (add1 count)))))

;; Hamming distance: number of differing bits between two bitmasks.
;; This IS the metric on the Hasse diagram of the Boolean lattice.
(define (hamming-distance a b)
  (popcount (bitwise-xor a b)))

;; Hasse adjacency: two elements are adjacent iff they differ in exactly one bit.
(define (hasse-adjacent? a b)
  (= 1 (popcount (bitwise-xor a b))))

;; Subcube membership: is worldview `wv` in the subcube defined by nogood `ng`?
;; True iff every bit in `ng` is also set in `wv` (ng ⊆ wv as sets).
;; O(1) — single AND + comparison.
(define (subcube-member? wv-bitmask ng-bitmask)
  (= (bitwise-and wv-bitmask ng-bitmask) ng-bitmask))


;; ============================================================
;; Commitment Cell (Phase 3: per-nogood structural unification)
;; ============================================================
;; A commitment cell tracks how much of a nogood pattern has been
;; matched against decision state. One compound cell per nogood,
;; component-indexed by group.
;;
;; Value: hasheq { group-id → #f | assumption-id }
;;   #f = group not yet committed to its nogood member
;;   assumption-id = group committed — carries the identity (provenance)
;;
;; Merge: per-position OR (once set, stays set)
;; Contradiction: all positions non-#f (full pattern match = nogood realized)
;; The cell value IS the provenance — no separate gathering.

;; Create initial commitment value for a nogood.
;; groups: (listof group-id)
;; Returns: hasheq with all positions at #f.
(define (commitment-initial groups)
  (for/hasheq ([g (in-list groups)])
    (values g #f)))

;; Merge: per-position OR. Once a position becomes non-#f, it stays.
(define (commitment-merge old new)
  (for/hasheq ([(g _) (in-hash old)])
    (values g (or (hash-ref new g #f) (hash-ref old g #f)))))

;; Contradiction: all positions non-#f.
(define (commitment-contradicts? v)
  (and (for/and ([(g val) (in-hash v)])
         val)
       #t))

;; How many positions are committed (non-#f)?
(define (commitment-filled-count v)
  (for/sum ([(g val) (in-hash v)])
    (if val 1 0)))

;; Extract the provenance: the set of assumption-ids from committed positions.
;; Returns: (listof assumption-id) — only the non-#f values.
(define (commitment-provenance v)
  (for/list ([(g val) (in-hash v)]
             #:when val)
    val))

;; Find the remaining uncommitted group (the one with #f).
;; Returns: group-id or #f if none remain (all committed = contradiction).
(define (commitment-remaining-group v)
  (for/first ([(g val) (in-hash v)]
              #:when (not val))
    g))


;; ============================================================
;; Nogood Install Request (Phase 3: topology descriptor)
;; ============================================================
;; Data-driven topology request — NOT a callback.
;; Written to the topology-request cell. The topology stratum
;; pattern-matches on this struct and installs per-nogood infrastructure.
(struct nogood-install-request
  (nogood-set       ;; hasheq of assumption-id → #t (the nogood)
   group-entries)   ;; (listof (list group-id cell-id nogood-member-aid))
  #:transparent)


;; ============================================================
;; Nogood Lattice
;; ============================================================
;; A nogood set is a set of nogoods, where each nogood is a hasheq
;; of assumption-ids. The lattice is P(P(AssumptionId)) under set-union.
;; Monotone: nogoods only accumulate.

;; Empty nogood set
(define nogood-empty '())

;; Merge: append (functionally equivalent to set-union for unique nogoods)
;; Uses list representation for simplicity — nogoods are typically small (< 100).
(define (nogood-merge old new)
  (cond
    [(null? old) new]
    [(null? new) old]
    [else (append old new)]))

;; Add a single nogood
(define (nogood-add ngs nogood-set)
  (cons nogood-set ngs))

;; Check if a specific assumption set contains any nogood as a subset
(define (nogood-member? ngs assumption-set)
  (for/or ([ng (in-list ngs)])
    (for/and ([(k _) (in-hash ng)])
      (hash-has-key? assumption-set k))))


;; ============================================================
;; Assumptions Accumulator
;; ============================================================
;; P(Assumption) under set-union. Monotone: assumptions only added.
;; Uses hasheq: assumption-id → assumption struct.

(define assumptions-empty (hasheq))

;; Merge: hash-union (keeps both sides, newer wins on collision — shouldn't happen)
(define (assumptions-merge old new)
  (cond
    [(eq? old assumptions-empty) new]
    [(eq? new assumptions-empty) old]
    [else
     (for/fold ([acc old]) ([(k v) (in-hash new)])
       (hash-set acc k v))]))

;; Add a single assumption
(define (assumptions-add store aid assumption)
  (hash-set store aid assumption))


;; ============================================================
;; Counter (Monotone Nat)
;; ============================================================
;; Merge = max. Written ONLY at topology stratum (sequential) to
;; prevent concurrent ID collision (2.3 from external critique).

(define (counter-merge old new)
  (max old new))
