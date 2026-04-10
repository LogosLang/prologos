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
 bit->mask    ;; Phase 5.6: exported for solver-assume
 popcount
 hamming-distance
 hasse-adjacent?
 subcube-member?

 ;; === Tagged Cell Values (Phase 4: replaces TMS tree) ===
 (struct-out tagged-cell-value)
 tagged-cell-value?
 tagged-cell-read
 tagged-cell-write
 tagged-cell-merge
 make-tagged-merge  ;; domain-aware merge wrapper (analogous to make-tms-merge)

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
 counter-merge

 ;; === Compound Decisions Cell (Phase 5.2) ===
 (struct-out decisions-state)
 decisions-state?
 decisions-state-empty
 decisions-state-merge
 decisions-state-add-component
 decisions-state-narrow-component
 decisions-state-component-ref
 decisions-state-component-keys

 ;; === Compound Scope Cell (Phase 8.1) ===
 (struct-out scope-cell)
 scope-cell?
 scope-cell-empty
 scope-cell-merge
 scope-cell-ref
 scope-cell-set
 scope-cell-keys
 scope-cell-bindings
 scope-cell-bot  ;; sentinel for unbound variables

 ;; === Compound Commitments Cell (Phase 5.3) ===
 (struct-out commitments-state)
 commitments-state?
 commitments-state-empty
 commitments-state-merge
 commitments-state-add-nogood
 commitments-state-component-ref
 commitments-state-component-keys
 commitments-state-write-position)


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
;; Tagged Cell Values (Phase 4: replaces TMS tree)
;; ============================================================
;; A tagged-cell-value holds a base value + a list of bitmask-tagged
;; speculative entries. Reads filter entries by the current worldview
;; bitmask — most-specific match (highest popcount subset of worldview).
;; Writes under a non-zero worldview append a tagged entry.
;;
;; Replaces the recursive tms-cell-value tree:
;;   tms-cell-value (ordered stack, O(depth) walk) → RETIRED
;;   tagged-cell-value (unordered bitmask, O(K) filter, each O(1)) → NEW
;;
;; Commit = worldview includes assumption → tagged entry visible. Nothing to do.
;; Retract = assumption eliminated → tagged entry invisible. Nothing to do.
;; Both emerge from decision cell information flow.
;;
;; base: the unconditional value (worldview = 0, always visible)
;; entries: (listof (cons bitmask value)) — speculative writes
;;   Each entry: (cons worldview-bitmask-at-write-time value)
;;   Monotone: entries only accumulate (append)
;;   Monotone: entries only accumulate (append)
(struct tagged-cell-value (base entries) #:transparent)

;; Read: find the most-specific entries whose bitmask is a subset of worldview W.
;; Most-specific = highest popcount (most assumptions committed).
;; If multiple entries match at the same specificity, MERGE them via domain-merge.
;; If no entry matches: return base.
;; worldview-bitmask: the current worldview (from worldview cache cell)
;; domain-merge: optional merge function for same-specificity entries.
;;   When #f (default), returns the first match (backward compat).
;;   When provided, merges all matching entries at max specificity.
;;   This is essential for union type speculation where BOTH branches succeed
;;   and their results must be joined (e.g., Nat ∪ Bool → Type 0).
(define (tagged-cell-read tcv worldview-bitmask [domain-merge #f])
  (cond
    [(not (tagged-cell-value? tcv)) tcv]  ;; plain value — pass through
    [(zero? worldview-bitmask)
     ;; No speculation active — return base directly (Tier 1 fast path)
     (tagged-cell-value-base tcv)]
    [else
     ;; Collect matching entries grouped by specificity (popcount)
     (define best-bits 0)
     (define best-vals '())  ;; list of values at max specificity
     (for ([entry (in-list (tagged-cell-value-entries tcv))])
       (define entry-bm (car entry))
       (define entry-val (cdr entry))
       (when (= (bitwise-and entry-bm worldview-bitmask) entry-bm)
         (define pc (popcount entry-bm))
         (cond
           [(> pc best-bits)
            (set! best-bits pc)
            (set! best-vals (list entry-val))]
           [(= pc best-bits)
            (set! best-vals (cons entry-val best-vals))])))
     (cond
       [(null? best-vals) (tagged-cell-value-base tcv)]
       [(null? (cdr best-vals)) (car best-vals)]  ;; single match
       [(not domain-merge) (car best-vals)]  ;; no merge fn → first match (compat)
       [else
        ;; Multiple matches at same specificity → merge all
        (for/fold ([acc (car best-vals)])
                  ([v (in-list (cdr best-vals))])
          (domain-merge acc v))])]))

;; Write: if worldview is non-zero, append a tagged entry.
;; If worldview is zero, update the base.
;; Returns a new tagged-cell-value.
(define (tagged-cell-write tcv worldview-bitmask new-val)
  (cond
    [(not (tagged-cell-value? tcv))
     ;; Plain value being written under speculation for the first time.
     ;; Wrap it: old value becomes base, new write is a tagged entry.
     (if (zero? worldview-bitmask)
         new-val  ;; no speculation — plain write
         (tagged-cell-value tcv (list (cons worldview-bitmask new-val))))]
    [(zero? worldview-bitmask)
     ;; Unconditional write — update base
     (struct-copy tagged-cell-value tcv [base new-val])]
    [else
     ;; Speculative write — append tagged entry
     (struct-copy tagged-cell-value tcv
       [entries (cons (cons worldview-bitmask new-val)
                      (tagged-cell-value-entries tcv))])]))

;; Merge: union entries from both sides. Base merges via the caller's merge-fn.
;; The caller (net-cell-write) applies the cell's registered merge-fn to the
;; overall value. For tagged-cell-value, the merge unions entry lists.
(define (tagged-cell-merge old new)
  (cond
    [(and (tagged-cell-value? old) (tagged-cell-value? new))
     (tagged-cell-value
      (tagged-cell-value-base new)  ;; newer base wins (or caller merges)
      ;; NEW entries first — later writes win at same specificity
      (append (tagged-cell-value-entries new)
              (tagged-cell-value-entries old)))]
    [(tagged-cell-value? old)
     ;; New is plain — treat as base update
     (struct-copy tagged-cell-value old [base new])]
    [(tagged-cell-value? new) new]  ;; old is plain, new is tagged
    [else new]))  ;; both plain

;; Create a tagged-cell merge function that applies a domain merge at base level.
;; domain-merge: (old-val new-val → merged-val) — the underlying lattice join.
;; Returns a merge function suitable for use as a cell's merge-fn.
;; Analogous to make-tms-merge for TMS cells.
;;
;; For tagged-cell-values: merges bases with domain-merge, unions entry lists.
;; For plain values: delegates to domain-merge directly.
(define (make-tagged-merge domain-merge)
  (lambda (old new)
    (cond
      [(eq? old 'infra-bot) new]
      [(eq? new 'infra-bot) old]
      [(and (tagged-cell-value? old) (tagged-cell-value? new))
       (tagged-cell-value
        (domain-merge (tagged-cell-value-base old)
                      (tagged-cell-value-base new))
        ;; NEW entries first — later writes appear earlier in the list.
        ;; tagged-cell-read uses strict > for popcount, so the first match
        ;; at max specificity wins. Newest write = first in list = returned.
        (append (tagged-cell-value-entries new)
                (tagged-cell-value-entries old)))]
      [(tagged-cell-value? old)
       (struct-copy tagged-cell-value old
         [base (domain-merge (tagged-cell-value-base old) new)])]
      [(tagged-cell-value? new)
       (struct-copy tagged-cell-value new
         [base (domain-merge old (tagged-cell-value-base new))])]
      [else (domain-merge old new)])))


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


;; ============================================================
;; Compound Decisions Cell (Phase 5.2)
;; ============================================================
;; ONE cell holds ALL decision state, component-indexed by group-id.
;; The merge maintains a derived bitmask (OR of committed assumptions'
;; bit positions) — the merge IS the fan-in aggregation. No propagators
;; needed for worldview derivation.
;;
;; components: hasheq group-id → decision-domain-value
;; bitmask: exact-nonneg-integer — derived, recomputed by merge
;; aid->int: (assumption-id → integer) — extracts bit position from assumption.
;;   Stored in the struct so the merge function can compute bitmasks
;;   without importing atms.rkt (pure leaf preservation).
;;
;; Design reference: D.10, §2.6b, §5.2

(struct decisions-state (components bitmask aid->int) #:transparent)

;; Create empty decisions state. aid->int is the function that extracts
;; an integer bit position from an assumption-id value.
(define (decisions-state-empty aid->int)
  (decisions-state (hasheq) 0 aid->int))

;; Recompute bitmask from all components. O(M) for M groups, each O(1).
(define (recompute-bitmask components aid->int)
  (for/fold ([bm 0]) ([(_gid dv) (in-hash components)])
    (cond
      [(decision-committed? dv)
       (define aid (decision-committed-assumption dv))
       (bitwise-ior bm (bit->mask (aid->int aid)))]
      [else bm])))

;; Merge: per-component decision-domain-merge, then recompute bitmask.
;; Handles both same-struct merges and infra-bot initial values.
(define (decisions-state-merge old new)
  (cond
    [(eq? old 'infra-bot) new]
    [(eq? new 'infra-bot) old]
    [(and (decisions-state? old) (decisions-state? new))
     (define aid->int (decisions-state-aid->int new))
     ;; Merge component maps: union keys, per-key decision-domain-merge
     (define old-comps (decisions-state-components old))
     (define new-comps (decisions-state-components new))
     (define merged
       (for/fold ([acc old-comps]) ([(gid dv) (in-hash new-comps)])
         (define existing (hash-ref acc gid #f))
         (if existing
             (hash-set acc gid (decision-domain-merge existing dv))
             (hash-set acc gid dv))))
     (define bm (recompute-bitmask merged aid->int))
     (decisions-state merged bm aid->int)]
    [else new]))

;; Add a component (group-id → decision-domain-value) to the compound cell.
;; Returns updated decisions-state.
(define (decisions-state-add-component ds group-id decision-val)
  (define comps (hash-set (decisions-state-components ds) group-id decision-val))
  (define bm (recompute-bitmask comps (decisions-state-aid->int ds)))
  (decisions-state comps bm (decisions-state-aid->int ds)))

;; Narrow a component by excluding an assumption. Returns updated decisions-state.
(define (decisions-state-narrow-component ds group-id excluded-aid)
  (define comps (decisions-state-components ds))
  (define current (hash-ref comps group-id #f))
  (if current
      (let* ([narrowed (decision-domain-narrow current excluded-aid)]
             [new-comps (hash-set comps group-id narrowed)]
             [bm (recompute-bitmask new-comps (decisions-state-aid->int ds))])
        (decisions-state new-comps bm (decisions-state-aid->int ds)))
      ds))  ;; unknown group — no-op

;; Read a single component's decision value.
(define (decisions-state-component-ref ds group-id [default #f])
  (hash-ref (decisions-state-components ds) group-id default))

;; List all component group-ids.
(define (decisions-state-component-keys ds)
  (hash-keys (decisions-state-components ds)))


;; ============================================================
;; Compound Commitments Cell (Phase 5.3)
;; ============================================================
;; ONE cell holds ALL per-nogood commitment tracking, component-indexed
;; by nogood-id. Each component is a commitment-value (hasheq group → #f/aid).
;; K nogoods → 1 compound cell (not K separate cells).
;;
;; The merge dispatches to commitment-merge per-component.
;; Component-indexed propagators (narrower, contradiction detector) watch
;; their specific nogood-id via component-paths.
;;
;; Design reference: D.10, §5.3

(struct commitments-state (components) #:transparent)

;; Create empty commitments state.
(define (commitments-state-empty)
  (commitments-state (hasheq)))

;; Merge: per-component commitment-merge, union keys.
(define (commitments-state-merge old new)
  (cond
    [(eq? old 'infra-bot) new]
    [(eq? new 'infra-bot) old]
    [(and (commitments-state? old) (commitments-state? new))
     (define old-comps (commitments-state-components old))
     (define new-comps (commitments-state-components new))
     (define merged
       (for/fold ([acc old-comps]) ([(nid cv) (in-hash new-comps)])
         (define existing (hash-ref acc nid #f))
         (if existing
             (hash-set acc nid (commitment-merge existing cv))
             (hash-set acc nid cv))))
     (commitments-state merged)]
    [else new]))

;; Add a new nogood's commitment tracking. groups = (listof group-id).
;; Returns updated commitments-state with a fresh commitment (all #f) for nogood-id.
(define (commitments-state-add-nogood cs nogood-id groups)
  (commitments-state
   (hash-set (commitments-state-components cs) nogood-id
             (commitment-initial groups))))

;; Read a single nogood's commitment value.
(define (commitments-state-component-ref cs nogood-id [default #f])
  (hash-ref (commitments-state-components cs) nogood-id default))

;; List all nogood-ids.
(define (commitments-state-component-keys cs)
  (hash-keys (commitments-state-components cs)))

;; Write a commitment position for a specific nogood.
;; nogood-id: which nogood's commitment to update
;; group-id: which group position within that commitment
;; aid: the assumption-id to commit at that position
;; Returns updated commitments-state.
(define (commitments-state-write-position cs nogood-id group-id aid)
  (define comps (commitments-state-components cs))
  (define cv (hash-ref comps nogood-id #f))
  (if cv
      (commitments-state
       (hash-set comps nogood-id
                 (commitment-merge cv (hasheq group-id aid))))
      cs))  ;; unknown nogood — no-op


;; ============================================================
;; Compound Scope Cell (Phase 8.1)
;; ============================================================
;; A scope cell holds all variables for one clause instantiation
;; (or query scope) as a single compound value on the network.
;;
;; Value: hasheq var-name → value (or scope-cell-bot for unbound)
;; Merge: per-key join. Unbound + value = value. Value + value = last-write.
;;
;; One cell per scope instead of N cells per variable.
;; Component-indexed propagators watch specific variables via component-paths.
;;
;; Table entries ARE scope cells — the table cell holds a set of scope values.
;; Consumer matching is structural comparison of scope values.
;;
;; SRE: the scope cell IS a substitution. Unification writes to specific
;; components. The merge handles per-variable composition. The scope cell
;; is a product lattice: Var₁ × Var₂ × ... × Varₙ where each component
;; is a flat lattice (⊥ → value → ⊤ for conflict).
;;
;; Design reference: D.12, §8.1

;; Sentinel for unbound variables in scope cells.
(define scope-cell-bot 'scope-cell-bot)

;; The compound scope cell value.
;; bindings: hasheq var-name → value (scope-cell-bot for unbound)
(struct scope-cell (bindings) #:transparent)

;; Create an empty scope cell.
(define (scope-cell-empty)
  (scope-cell (hasheq)))

;; Create a scope cell with variables initialized to bot.
;; var-names: (listof symbol)
(define (scope-cell-with-vars var-names)
  (scope-cell (for/hasheq ([v (in-list var-names)])
                (values v scope-cell-bot))))

;; Merge: per-key join. For each variable:
;;   bot + x = x (unbound gains value)
;;   x + bot = x (keep existing)
;;   x + y = y (last-write-wins for non-bot)
;; New keys from either side are included (union of variable sets).
(define (scope-cell-merge old new)
  (cond
    [(eq? old 'infra-bot) new]
    [(eq? new 'infra-bot) old]
    [(and (scope-cell? old) (scope-cell? new))
     (define old-b (scope-cell-bindings old))
     (define new-b (scope-cell-bindings new))
     ;; Union keys, per-key merge
     (define merged
       (for/fold ([acc old-b]) ([(k v) (in-hash new-b)])
         (define existing (hash-ref acc k scope-cell-bot))
         (hash-set acc k
           (cond
             [(eq? existing scope-cell-bot) v]
             [(eq? v scope-cell-bot) existing]
             [else v]))))  ;; both non-bot: new wins
     (scope-cell merged)]
    [else new]))

;; Read a variable from a scope cell.
(define (scope-cell-ref sc var-name [default scope-cell-bot])
  (if (scope-cell? sc)
      (hash-ref (scope-cell-bindings sc) var-name default)
      default))

;; Write a variable in a scope cell. Returns new scope-cell.
(define (scope-cell-set sc var-name value)
  (if (scope-cell? sc)
      (scope-cell (hash-set (scope-cell-bindings sc) var-name value))
      (scope-cell (hasheq var-name value))))

;; List all variable names.
(define (scope-cell-keys sc)
  (if (scope-cell? sc)
      (hash-keys (scope-cell-bindings sc))
      '()))

;; Get the full bindings hasheq.
(define (scope-cell-bindings-ref sc)
  (if (scope-cell? sc)
      (scope-cell-bindings sc)
      (hasheq)))
