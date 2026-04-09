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

(require "propagator.rkt"
         "decision-cell.rkt")  ;; Phase 5.6: compound cells

(provide
 ;; Core structs
 (struct-out assumption-id)
 (struct-out assumption)
 (struct-out supported-value)
 (struct-out tms-cell)
 (struct-out atms)              ;; DEPRECATED — Phase 5.6: use solver-context
 ;; Construction
 atms-empty                     ;; DEPRECATED — Phase 5.6: use make-solver-context
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
 ;; Explanation / derivation chains
 (struct-out nogood-explanation)
 atms-explain-hypothesis
 atms-explain
 ;; GDE-2: Minimal diagnoses
 atms-minimal-diagnoses
 atms-conflict-graph
 ;; Helpers
 assumption-id-hash
 hash-subset?

 ;; ============================================================
 ;; Phase 5.6: Solver Context (replaces atms struct)
 ;; ============================================================
 ;; A phone book of cell-ids — metadata about WHERE cells are,
 ;; not WHAT they hold. The cells are on the prop-network.
 ;; No second source of truth (P4 self-critique resolution).
 (struct-out solver-context)
 make-solver-context
 ;; Cell-based operations (take solver-context + net, return net)
 solver-assume
 solver-retract
 solver-add-nogood
 solver-amb
 solver-consistent?
 ;; Query functions (read-only, correctly off-network)
 solver-explain-hypothesis
 solver-explain
 ;; Convenience wrapper: solver-state = solver-context + prop-network
 ;; Mirrors the old atms calling convention for easy migration.
 (struct-out solver-state)
 make-solver-state
 solver-state-assume
 solver-state-retract
 solver-state-add-nogood
 solver-state-amb
 solver-state-solve-all
 solver-state-read-cell
 solver-state-write-cell
 solver-state-consistent?
 solver-state-with-worldview
 solver-state-explain-hypothesis
 solver-state-explain
 solver-state-assumptions
 solver-state-minimal-diagnoses)

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

;; ========================================
;; Explanation / derivation chains
;; ========================================

;; A nogood explanation: the nogood set and metadata for the conflicting assumptions.
;; nogood-set: hasheq assumption-id → #t
;; conflicting-assumptions: (listof (cons assumption-id assumption))
;;   — the OTHER assumptions in the nogood (excluding the queried hypothesis)
(struct nogood-explanation (nogood-set conflicting-assumptions) #:transparent)

;; Given an ATMS and a hypothesis-id, return all nogoods containing that hypothesis.
;; For each matching nogood, resolves the conflicting assumptions (all assumptions
;; in the nogood other than the queried one) with their metadata.
;; Returns: (listof nogood-explanation)
(define (atms-explain-hypothesis a hypothesis-id)
  (for/list ([ng (in-list (atms-nogoods a))]
             #:when (hash-has-key? ng hypothesis-id))
    (define others
      (for/list ([(aid _) (in-hash ng)]
                 #:when (not (equal? aid hypothesis-id)))
        (cons aid (hash-ref (atms-assumptions a) aid #f))))
    (nogood-explanation ng others)))

;; Return all nogoods that are violated under the current believed set.
;; Each violated nogood is returned as a nogood-explanation with full
;; assumption metadata for all members.
;; Returns: (listof nogood-explanation)
(define (atms-explain a)
  (for/list ([ng (in-list (atms-nogoods a))]
             #:when (hash-subset? ng (atms-believed a)))
    (define members
      (for/list ([(aid _) (in-hash ng)])
        (cons aid (hash-ref (atms-assumptions a) aid #f))))
    (nogood-explanation ng members)))

;; ========================================
;; GDE-2: Minimal diagnoses (hitting-set)
;; ========================================

;; A diagnosis is a set of assumptions whose retraction resolves all conflicts.
;; A MINIMAL diagnosis is one where no proper subset also resolves all conflicts.
;;
;; Algorithm: greedy hitting-set (de Kleer & Williams 1987, simplified).
;; For each violated nogood, we must retract at least one assumption from it.
;; This is the classic minimum hitting-set problem (NP-hard in general, but
;; our nogoods are small — typically 2-3 assumptions — so greedy works well).
;;
;; Phase 0: Greedy approach — iteratively pick the assumption that appears
;; in the most unhit nogoods. This gives a good (often minimal) diagnosis.
;;
;; Returns: (listof hasheq) — each hasheq is assumption-id → #t (a diagnosis).
;; Currently returns a single greedy diagnosis. Future: enumerate all minimal.
(define (atms-minimal-diagnoses a)
  (define violated
    (for/list ([ng (in-list (atms-nogoods a))]
               #:when (hash-subset? ng (atms-believed a)))
      ng))
  (cond
    [(null? violated) '()]  ;; No conflicts → no diagnosis needed
    [else
     ;; Greedy hitting set: pick assumption in most nogoods
     (define diagnosis (greedy-hitting-set violated))
     (if (hash-empty? diagnosis) '() (list diagnosis))]))

;; Greedy hitting-set: repeatedly pick the assumption appearing in the most
;; unhit nogoods until all nogoods are hit.
;; Returns: hasheq assumption-id → #t (the hitting set)
(define (greedy-hitting-set nogoods)
  (let loop ([remaining nogoods] [diagnosis (hasheq)])
    (cond
      [(null? remaining) diagnosis]
      [else
       ;; Count occurrences of each assumption across remaining nogoods
       (define counts (make-hasheq))
       (for ([ng (in-list remaining)])
         (for ([(aid _) (in-hash ng)])
           (hash-set! counts aid (+ 1 (hash-ref counts aid 0)))))
       ;; Pick the assumption with the highest count
       (define-values (best-aid _best-count)
         (for/fold ([best #f] [best-count 0])
                   ([(aid count) (in-hash counts)])
           (if (> count best-count)
               (values aid count)
               (values best best-count))))
       (cond
         [(not best-aid) diagnosis]  ;; shouldn't happen if remaining is non-empty
         [else
          ;; Remove all nogoods containing best-aid
          (define new-remaining
            (for/list ([ng (in-list remaining)]
                       #:when (not (hash-has-key? ng best-aid)))
              ng))
          (loop new-remaining (hash-set diagnosis best-aid #t))])])))

;; Return the conflict graph: assumptions participating in violated nogoods.
;; Returns: hasheq assumption-id → (listof hasheq)
;;   Each key is an assumption-id that appears in at least one violated nogood.
;;   Each value is the list of violated nogoods containing that assumption.
(define (atms-conflict-graph a)
  (define violated
    (for/list ([ng (in-list (atms-nogoods a))]
               #:when (hash-subset? ng (atms-believed a)))
      ng))
  (define graph (make-hasheq))
  (for ([ng (in-list violated)])
    (for ([(aid _) (in-hash ng)])
      (hash-set! graph aid (cons ng (hash-ref graph aid '())))))
  ;; Convert to immutable
  (for/hasheq ([(aid ngs) (in-hash graph)])
    (values aid (reverse ngs))))


;; ========================================
;; Phase 5.6: Solver Context
;; ========================================
;;
;; Replaces the atms struct. A phone book of cell-ids — metadata about
;; WHERE the cells are, not WHAT they hold. The cells live on the
;; prop-network. Operations take (solver-context, network) and return
;; an updated network.
;;
;; No second source of truth: the solver-context is IMMUTABLE after
;; creation. All state changes go through cell writes on the network.
;;
;; Design reference: D.10, §2.6, §5.6

;; The solver-context: cell-ids for all solver state.
;; decisions-cid: compound decisions cell (decisions-state, §5.2)
;; commitments-cid: compound commitments cell (commitments-state, §5.3)
;; assumptions-cid: assumptions accumulator cell (hasheq aid → assumption)
;; nogoods-cid: nogood accumulator cell (set of nogood sets)
;; counter-cid: assumption counter cell (nat, max merge)
;; All immutable after creation. State flows through the network.
(struct solver-context
  (decisions-cid commitments-cid assumptions-cid nogoods-cid counter-cid)
  #:transparent)

;; Create a solver context: allocate all cells on the network,
;; install the worldview projection propagator.
;; Returns: (values new-network solver-context)
(define (make-solver-context net)
  ;; 1. Compound decisions cell
  (define-values (net1 dec-cid)
    (net-new-cell net
                  (decisions-state-empty assumption-id-n)
                  decisions-state-merge))
  ;; 2. Compound commitments cell
  (define-values (net2 com-cid)
    (net-new-cell net1
                  (commitments-state-empty)
                  commitments-state-merge))
  ;; 3. Assumptions accumulator (hasheq, set-union merge)
  (define-values (net3 asn-cid)
    (net-new-cell net2 (hasheq) assumptions-merge))
  ;; 4. Nogoods accumulator (nogood lattice)
  (define-values (net4 ng-cid)
    (net-new-cell net3 nogood-empty nogood-merge))
  ;; 5. Counter (nat, max merge)
  (define-values (net5 cnt-cid)
    (net-new-cell net4 0 counter-merge))
  ;; 6. Install worldview projection: decisions → worldview cache cell-id 1
  (define-values (net6 _proj-pid)
    (install-worldview-projection net5 dec-cid))
  ;; Return network with all cells allocated + solver-context phone book
  (values net6 (solver-context dec-cid com-cid asn-cid ng-cid cnt-cid)))

;; ========================================
;; Solver operations (cell-based)
;; ========================================

;; Create a new assumption. Writes to assumptions-cell + counter-cell.
;; Creates a trivial decision cell component {h} for the assumption.
;; Returns: (values new-network assumption-id)
(define (solver-assume ctx net name datum)
  (define cnt-cid (solver-context-counter-cid ctx))
  ;; Read current counter, create assumption-id
  (define n (net-cell-read net cnt-cid))
  (define aid (assumption-id n))
  (define asn (assumption name datum))
  ;; Write: increment counter
  (define net1 (net-cell-write net cnt-cid (+ n 1)))
  ;; Write: add to assumptions accumulator
  (define net2 (net-cell-write net1 (solver-context-assumptions-cid ctx)
                               (assumptions-add (hasheq) aid asn)))
  ;; Write: add trivial decision component {h} to compound decisions cell
  (define dec-cid (solver-context-decisions-cid ctx))
  (define ds (net-cell-read-raw net2 dec-cid))
  (define net3 (net-cell-write net2 dec-cid
                               (decisions-state-add-component
                                ds aid
                                (decision-from-alternatives
                                 (list aid)
                                 (bit->mask (assumption-id-n aid))
                                 (list (assumption-id-n aid))))))
  (values net3 aid))

;; Retract an assumption: narrow its decision cell component to exclude it.
;; Returns: new-network
(define (solver-retract ctx net aid)
  (define dec-cid (solver-context-decisions-cid ctx))
  (define ds (net-cell-read-raw net dec-cid))
  (net-cell-write net dec-cid
                  (decisions-state-narrow-component ds aid aid)))

;; Record a nogood. Writes to the nogoods accumulator cell.
;; nogood-set: hasheq assumption-id → #t
;; Returns: new-network
(define (solver-add-nogood ctx net nogood-set)
  (net-cell-write net (solver-context-nogoods-cid ctx)
                  (nogood-add nogood-empty nogood-set)))

;; Create a choice point with N alternatives.
;; Creates N assumptions, adds them as components of the compound decisions cell,
;; records pairwise mutual-exclusion nogoods.
;; Returns: (values new-network (listof assumption-id))
(define (solver-amb ctx net alternatives)
  ;; 1. Create fresh assumptions, one per alternative
  (define-values (net1 hyps-rev)
    (for/fold ([n net] [hs '()])
              ([alt (in-list alternatives)]
               [i (in-naturals)])
      (define-values (n2 hid) (solver-assume ctx n (string->symbol (format "h~a" i)) alt))
      (values n2 (cons hid hs))))
  (define hyps (reverse hyps-rev))
  ;; 2. Record mutual exclusion: every pair of hypotheses is a nogood
  (define net2
    (for*/fold ([n net1])
               ([i (in-range (length hyps))]
                [j (in-range (+ i 1) (length hyps))])
      (solver-add-nogood ctx n (hasheq (list-ref hyps i) #t
                                        (list-ref hyps j) #t))))
  (values net2 hyps))

;; Check consistency: are all decision cell components non-empty?
;; Reads compound decisions cell components directly (no fan-in propagator).
;; Returns: boolean
(define (solver-consistent? ctx net)
  (define dec-cid (solver-context-decisions-cid ctx))
  (define ds (net-cell-read-raw net dec-cid))
  (if (decisions-state? ds)
      (for/and ([(_gid dv) (in-hash (decisions-state-components ds))])
        (not (decision-top? dv)))
      #t))

;; ========================================
;; Solver query functions (read-only)
;; ========================================

;; Explain a hypothesis: return all nogoods containing it.
;; Returns: (listof nogood-explanation)
(define (solver-explain-hypothesis ctx net hypothesis-id)
  (define ng-list (net-cell-read-raw net (solver-context-nogoods-cid ctx)))
  (define assumptions-raw (net-cell-read-raw net (solver-context-assumptions-cid ctx)))
  (for/list ([ng (in-list (if (list? ng-list) ng-list '()))]
             #:when (hash-has-key? ng hypothesis-id))
    (define others
      (for/list ([(aid _) (in-hash ng)]
                 #:when (not (equal? aid hypothesis-id)))
        (cons aid (hash-ref assumptions-raw aid #f))))
    (nogood-explanation ng others)))

;; Explain: return all nogoods violated under current worldview.
;; Reads compound decisions cell for the current committed assumptions.
;; Returns: (listof nogood-explanation)
(define (solver-explain ctx net)
  (define ng-list (net-cell-read-raw net (solver-context-nogoods-cid ctx)))
  (define assumptions-raw (net-cell-read-raw net (solver-context-assumptions-cid ctx)))
  (define dec-cid (solver-context-decisions-cid ctx))
  (define ds (net-cell-read-raw net dec-cid))
  ;; Build believed set from committed decisions
  (define believed
    (if (decisions-state? ds)
        (for/fold ([acc (hasheq)]) ([(_gid dv) (in-hash (decisions-state-components ds))])
          (if (decision-committed? dv)
              (hash-set acc (decision-committed-assumption dv) #t)
              acc))
        (hasheq)))
  (for/list ([ng (in-list (if (list? ng-list) ng-list '()))]
             #:when (hash-subset? ng believed))
    (define members
      (for/list ([(aid _) (in-hash ng)])
        (cons aid (hash-ref assumptions-raw aid #f))))
    (nogood-explanation ng members)))


;; ========================================
;; Solver State: solver-context + network pair
;; ========================================
;;
;; Convenience wrapper that mirrors the old atms calling convention
;; (take state, return state) for easy migration. The solver-state
;; is what gets stored in expr-atms-store — it replaces the atms struct.
;;
;; ctx: solver-context (immutable phone book)
;; net: prop-network (the computation substrate, evolves with each operation)

(struct solver-state (ctx net) #:transparent)

;; Create a solver-state from a prop-network.
;; Allocates solver cells and installs the worldview projection.
(define (make-solver-state net)
  (define-values (net* ctx) (make-solver-context net))
  (solver-state ctx net*))

;; Assume: returns (values new-solver-state assumption-id)
(define (solver-state-assume ss name datum)
  (define-values (net* aid) (solver-assume (solver-state-ctx ss) (solver-state-net ss) name datum))
  (values (solver-state (solver-state-ctx ss) net*) aid))

;; Retract: returns new-solver-state
(define (solver-state-retract ss aid)
  (define net* (solver-retract (solver-state-ctx ss) (solver-state-net ss) aid))
  (solver-state (solver-state-ctx ss) net*))

;; Add nogood: returns new-solver-state
(define (solver-state-add-nogood ss nogood-set)
  (define net* (solver-add-nogood (solver-state-ctx ss) (solver-state-net ss) nogood-set))
  (solver-state (solver-state-ctx ss) net*))

;; Amb: returns (values new-solver-state (listof assumption-id))
(define (solver-state-amb ss alternatives)
  (define-values (net* hyps) (solver-amb (solver-state-ctx ss) (solver-state-net ss) alternatives))
  (values (solver-state (solver-state-ctx ss) net*) hyps))

;; Consistent?: returns boolean
(define (solver-state-consistent? ss assumption-set)
  (define ng-list (net-cell-read-raw (solver-state-net ss)
                                      (solver-context-nogoods-cid (solver-state-ctx ss))))
  (not (for/or ([ng (in-list (if (list? ng-list) ng-list '()))])
         (hash-subset? ng assumption-set))))

;; With-worldview: for each assumption-id in new-believed that has a decision
;; component, leave it as-is. For assumptions NOT in new-believed, narrow their
;; component to exclude them. Returns: new-solver-state
(define (solver-state-with-worldview ss new-believed)
  (define ctx (solver-state-ctx ss))
  (define net (solver-state-net ss))
  (define dec-cid (solver-context-decisions-cid ctx))
  (define ds (net-cell-read-raw net dec-cid))
  (if (decisions-state? ds)
      (let ([updated-ds
             (for/fold ([acc ds]) ([(gid dv) (in-hash (decisions-state-components ds))])
               (define aid (decision-committed-assumption dv))
               (cond
                 [(not aid) acc]  ;; multi-alternative group — leave as-is
                 [(hash-has-key? new-believed aid) acc]  ;; still believed — no change
                 [else (decisions-state-narrow-component acc gid aid)]))])
        (solver-state ctx (net-cell-write net dec-cid updated-ds)))
      ss))

;; Read cell: read a prop-network cell under the current worldview.
(define (solver-state-read-cell ss cell-key)
  (net-cell-read (solver-state-net ss) cell-key))

;; Write cell: write to a prop-network cell. Returns: new-solver-state
(define (solver-state-write-cell ss cell-key value)
  (solver-state (solver-state-ctx ss)
                (net-cell-write (solver-state-net ss) cell-key value)))

;; Solve-all: enumerate consistent worldviews and collect goal cell values.
;; Returns: (listof value) — distinct answers.
(define (solver-state-solve-all ss goal-cell-key)
  (define ctx (solver-state-ctx ss))
  (define net (solver-state-net ss))
  (define dec-cid (solver-context-decisions-cid ctx))
  (define ds (net-cell-read-raw net dec-cid))
  (cond
    [(not (decisions-state? ds)) '()]
    [else
     ;; Collect amb groups: components with >1 alternative
     (define groups
       (for/list ([(_gid dv) (in-hash (decisions-state-components ds))]
                  #:when (decision-set? dv))
         (hash-keys (decision-set-alternatives dv))))
     (cond
       [(null? groups)
        (define val (net-cell-read net goal-cell-key))
        (if (eq? val 'bot) '() (list val))]
       [else
        (define combos (cartesian-product groups))
        (define answers
          (for/fold ([acc '()])
                    ([combo (in-list combos)])
            (define believed (aids->set combo))
            (if (solver-state-consistent? ss believed)
                (let* ([ss* (solver-state-with-worldview ss believed)]
                       [val (solver-state-read-cell ss* goal-cell-key)])
                  (if (or (eq? val 'bot) (member val acc))
                      acc
                      (cons val acc)))
                acc)))
        (reverse answers)])]))

;; Explain-hypothesis wrapper
(define (solver-state-explain-hypothesis ss hypothesis-id)
  (solver-explain-hypothesis (solver-state-ctx ss) (solver-state-net ss) hypothesis-id))

;; Explain wrapper
(define (solver-state-explain ss)
  (solver-explain (solver-state-ctx ss) (solver-state-net ss)))

;; Read assumptions map (for typing-errors.rkt and pretty-print.rkt)
(define (solver-state-assumptions ss)
  (net-cell-read-raw (solver-state-net ss)
                     (solver-context-assumptions-cid (solver-state-ctx ss))))

;; Minimal diagnoses (delegates to greedy algorithm)
;; TODO: Replace with tropical semiring CSP when available
(define (solver-state-minimal-diagnoses ss)
  (define ng-list (net-cell-read-raw (solver-state-net ss)
                                      (solver-context-nogoods-cid (solver-state-ctx ss))))
  (define dec-cid (solver-context-decisions-cid (solver-state-ctx ss)))
  (define ds (net-cell-read-raw (solver-state-net ss) dec-cid))
  (define believed
    (if (decisions-state? ds)
        (for/fold ([acc (hasheq)]) ([(_gid dv) (in-hash (decisions-state-components ds))])
          (if (decision-committed? dv)
              (hash-set acc (decision-committed-assumption dv) #t)
              acc))
        (hasheq)))
  (define violated
    (for/list ([ng (in-list (if (list? ng-list) ng-list '()))]
               #:when (hash-subset? ng believed))
      ng))
  (cond
    [(null? violated) '()]
    [else
     (define diagnosis (greedy-hitting-set violated))
     (if (hash-empty? diagnosis) '() (list diagnosis))]))
