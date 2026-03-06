#lang racket/base

;;;
;;; EFFECT POSITION LATTICE
;;; Data structures and operations for tracking causal effect positions
;;; in the Architecture A+D implementation.
;;;
;;; The effect position lattice tracks where in the causal timeline
;;; an effect sits. Positions are derived from session type advancement
;;; (the alpha direction of the Galois connection: Session → EffectPosition).
;;;
;;; See: docs/tracking/2026-03-07_ARCHITECTURE_AD_IMPLEMENTATION_DESIGN.org §5
;;;

(require racket/match
         racket/list
         racket/set
         "sessions.rkt")

(provide
 ;; Sentinels
 eff-bot eff-top eff-bot? eff-top?
 ;; Position types
 (struct-out eff-pos)
 (struct-out eff-vec)
 ;; Ordering types
 (struct-out eff-edge)
 (struct-out eff-ordering)
 ;; Session depth
 session-steps session-steps-to
 ;; Position comparison
 eff-pos-compare
 ;; Ordering operations
 eff-ordering-empty eff-ordering-add-edge eff-ordering-merge
 eff-ordering-transitive-closure eff-ordering-has-cycle? eff-ordering-contradicts?
 eff-ordering-linearize
 ;; Merge functions (for propagator cells)
 eff-pos-merge eff-ordering-cell-merge
 ;; Effect descriptors (AD-A2)
 (struct-out eff-open)
 (struct-out eff-write)
 (struct-out eff-read)
 (struct-out eff-close)
 effect-desc? effect-desc-channel effect-desc-position
 ;; Effect accumulator
 (struct-out effect-set)
 effect-set-empty effect-set-add effect-set-merge effect-set-count)


;; ========================================
;; Sentinels
;; ========================================

(define eff-bot 'eff-bot)
(define eff-top 'eff-top)
(define (eff-bot? x) (eq? x 'eff-bot))
(define (eff-top? x) (eq? x 'eff-top))


;; ========================================
;; Position Types
;; ========================================

;; A concrete position: channel identifier + depth in session chain.
;; For session !String . ?Int . end:
;;   depth 0 = the !String step
;;   depth 1 = the ?Int step
;;   depth 2 = end
(struct eff-pos (channel depth) #:transparent)

;; A vector position: composite "where are we now" across all channels.
;; Used by the session-effect bridge to track runtime progress.
;; positions: hasheq channel-symbol → Nat
(struct eff-vec (positions) #:transparent)


;; ========================================
;; Ordering Types
;; ========================================

;; Ordering edge: (source-pos, target-pos) meaning source happens-before target.
(struct eff-edge (source target) #:transparent)

;; Ordering accumulator: set of ordering edges (monotone via set-union).
(struct eff-ordering (edges) #:transparent)


;; ========================================
;; Session Depth Computation
;; ========================================

;; Count total communication steps in a session type.
;; Each send/recv/dsend/drecv/async-send/async-recv is one step.
;; Choice/offer count as one step for the branch point.
;; Recursive sessions (sess-mu) are unfolded before counting.
(define (session-steps sess)
  (match sess
    [(sess-send _ cont)       (add1 (session-steps cont))]
    [(sess-recv _ cont)       (add1 (session-steps cont))]
    [(sess-dsend _ cont)      (add1 (session-steps cont))]
    [(sess-drecv _ cont)      (add1 (session-steps cont))]
    [(sess-async-send _ cont) (add1 (session-steps cont))]
    [(sess-async-recv _ cont) (add1 (session-steps cont))]
    [(sess-choice branches)
     (if (null? branches)
         0
         (add1 (apply max (map (λ (b) (session-steps (cdr b))) branches))))]
    [(sess-offer branches)
     (if (null? branches)
         0
         (add1 (apply max (map (λ (b) (session-steps (cdr b))) branches))))]
    [(sess-mu _body)          (session-steps (unfold-session sess))]
    [(sess-end)               0]
    [_ 0]))  ;; sess-meta, sess-svar, sess-branch-error → 0

;; Count steps from full-session to reach current-session.
;; Returns the depth (number of steps already consumed).
;;
;; Algorithm: walk full-session step by step, counting until we reach
;; a suffix that matches current-session (via equal?).
;; Returns #f if current-session is not a suffix of full-session.
(define (session-steps-to full-session current-session)
  (cond
    [(equal? full-session current-session) 0]
    [else
     (match full-session
       [(sess-send _ cont)
        (let ([r (session-steps-to cont current-session)])
          (and r (add1 r)))]
       [(sess-recv _ cont)
        (let ([r (session-steps-to cont current-session)])
          (and r (add1 r)))]
       [(sess-dsend _ cont)
        (let ([r (session-steps-to cont current-session)])
          (and r (add1 r)))]
       [(sess-drecv _ cont)
        (let ([r (session-steps-to cont current-session)])
          (and r (add1 r)))]
       [(sess-async-send _ cont)
        (let ([r (session-steps-to cont current-session)])
          (and r (add1 r)))]
       [(sess-async-recv _ cont)
        (let ([r (session-steps-to cont current-session)])
          (and r (add1 r)))]
       [(sess-mu _body)
        (session-steps-to (unfold-session full-session) current-session)]
       ;; For choice/offer, check each branch (they diverge)
       [(sess-choice branches)
        (for/or ([b (in-list branches)])
          (let ([r (session-steps-to (cdr b) current-session)])
            (and r (add1 r))))]
       [(sess-offer branches)
        (for/or ([b (in-list branches)])
          (let ([r (session-steps-to (cdr b) current-session)])
            (and r (add1 r))))]
       [_ #f])]))


;; ========================================
;; Position Comparison
;; ========================================

;; Compare two effect positions.
;; Returns: 'less | 'greater | 'equal | 'concurrent
;; Same channel: total order by depth.
;; Different channels: concurrent (incomparable).
(define (eff-pos-compare p1 p2)
  (cond
    [(and (eff-pos? p1) (eff-pos? p2))
     (if (eq? (eff-pos-channel p1) (eff-pos-channel p2))
         (cond [(< (eff-pos-depth p1) (eff-pos-depth p2)) 'less]
               [(> (eff-pos-depth p1) (eff-pos-depth p2)) 'greater]
               [else 'equal])
         'concurrent)]
    [else 'concurrent]))


;; ========================================
;; Lattice Merge Functions
;; ========================================

;; Merge for effect position cells (flat lattice: bot → concrete → top).
;; Two concrete positions on the same channel: keep higher depth (monotone).
;; Different channels: contradiction (top) — a cell tracks one channel's position.
(define (eff-pos-merge old new)
  (cond
    [(eff-bot? old) new]
    [(eff-bot? new) old]
    [(eff-top? old) eff-top]
    [(eff-top? new) eff-top]
    [(equal? old new) old]
    [(and (eff-pos? old) (eff-pos? new)
          (eq? (eff-pos-channel old) (eff-pos-channel new)))
     ;; Same channel: take higher depth (monotone)
     (if (>= (eff-pos-depth new) (eff-pos-depth old)) new old)]
    [else eff-top]))  ;; Different channels in same cell → contradiction

;; Merge for ordering cells (set-union of edges, monotone).
(define (eff-ordering-cell-merge old new)
  (cond
    [(eff-bot? old) new]
    [(eff-bot? new) old]
    [(eff-top? old) eff-top]
    [(eff-top? new) eff-top]
    [(and (eff-ordering? old) (eff-ordering? new))
     (eff-ordering-merge old new)]
    [else eff-top]))


;; ========================================
;; Ordering Operations
;; ========================================

(define eff-ordering-empty (eff-ordering '()))

(define (eff-ordering-add-edge ordering edge)
  (if (member edge (eff-ordering-edges ordering))
      ordering  ;; Already present — idempotent
      (eff-ordering (cons edge (eff-ordering-edges ordering)))))

;; Merge two orderings: set-union of edges (monotone).
(define (eff-ordering-merge o1 o2)
  (eff-ordering (remove-duplicates
                 (append (eff-ordering-edges o1)
                         (eff-ordering-edges o2)))))

;; Transitive closure: for each pair (a < b) and (b < c), derive (a < c).
;; Repeat until fixed point.
(define (eff-ordering-transitive-closure ordering)
  (define edges (eff-ordering-edges ordering))
  (define (step current-edges)
    (define new-edges
      (for*/fold ([acc current-edges])
                 ([e1 (in-list current-edges)]
                  [e2 (in-list current-edges)]
                  #:when (equal? (eff-edge-target e1) (eff-edge-source e2)))
        (define new-edge (eff-edge (eff-edge-source e1) (eff-edge-target e2)))
        (if (member new-edge acc) acc (cons new-edge acc))))
    (if (= (length new-edges) (length current-edges))
        (eff-ordering new-edges)  ;; fixed point
        (step new-edges)))
  (step edges))

;; Cycle detection: if transitive closure contains (a < a), it's a deadlock.
(define (eff-ordering-has-cycle? ordering)
  (define closed (eff-ordering-transitive-closure ordering))
  (for/or ([edge (in-list (eff-ordering-edges closed))])
    (equal? (eff-edge-source edge) (eff-edge-target edge))))

;; An ordering with a cycle is a contradiction: deadlock = compile-time error.
(define (eff-ordering-contradicts? ordering)
  (eff-ordering-has-cycle? ordering))


;; ========================================
;; Effect Linearization (Topological Sort)
;; ========================================

;; Linearize effect positions according to ordering edges.
;; Uses Kahn's algorithm (BFS-based topological sort).
;; Concurrent effects get deterministic tiebreak: sort by channel name, then depth.
;;
;; positions: list of eff-pos
;; ordering: eff-ordering
;; Returns: list of eff-pos in execution order, or #f if cycle detected.
(define (eff-ordering-linearize positions ordering)
  (define edges (eff-ordering-edges ordering))
  ;; Build adjacency and in-degree
  (define adj (make-hasheq))   ;; pos → list of pos
  (define indeg (make-hash))   ;; pos → Nat (uses equal? keys)
  ;; Initialize
  (for ([p (in-list positions)])
    (hash-set! indeg p (hash-ref indeg p 0)))
  ;; Populate from edges (only for positions in the input set)
  (define pos-set (list->set positions))
  (for ([e (in-list edges)])
    (define src (eff-edge-source e))
    (define tgt (eff-edge-target e))
    (when (and (set-member? pos-set src) (set-member? pos-set tgt))
      (hash-update! adj src (λ (lst) (cons tgt lst)) '())
      (hash-update! indeg tgt add1 0)))
  ;; Collect nodes with in-degree 0, sorted for determinism
  (define (sort-positions ps)
    (sort ps
          (λ (a b)
            (cond
              [(symbol<? (eff-pos-channel a) (eff-pos-channel b)) #t]
              [(symbol<? (eff-pos-channel b) (eff-pos-channel a)) #f]
              [else (< (eff-pos-depth a) (eff-pos-depth b))]))))
  ;; Kahn's algorithm
  (let loop ([queue (sort-positions
                      (filter (λ (p) (= 0 (hash-ref indeg p 0))) positions))]
             [result '()])
    (cond
      [(null? queue)
       (if (= (length result) (length positions))
           (reverse result)
           #f)]  ;; Cycle — not all positions emitted
      [else
       (define node (car queue))
       (define rest-queue (cdr queue))
       ;; Decrease in-degree for neighbors
       (define neighbors (hash-ref adj node '()))
       (for ([n (in-list neighbors)])
         (hash-update! indeg n sub1))
       ;; Collect newly zero-degree nodes
       (define new-zeros
         (sort-positions
           (filter (λ (n) (= 0 (hash-ref indeg n 0)))
                   neighbors)))
       (loop (sort-positions (append rest-queue new-zeros))
             (cons node result))])))

;; Helper: symbol comparison
(define (symbol<? a b)
  (string<? (symbol->string a) (symbol->string b)))


;; ========================================
;; Effect Descriptors (AD-A2)
;; ========================================

;; Sum-type effect descriptors: each kind has exactly the fields it needs.
(struct eff-open  (channel position path mode) #:transparent)   ;; mode: 'read | 'write | 'append
(struct eff-write (channel position value) #:transparent)       ;; value: Prologos expr
(struct eff-read  (channel position) #:transparent)             ;; reads from port
(struct eff-close (channel position) #:transparent)             ;; closes port

;; Predicate for any effect descriptor
(define (effect-desc? x)
  (or (eff-open? x) (eff-write? x) (eff-read? x) (eff-close? x)))

;; Extract channel from any effect descriptor
(define (effect-desc-channel eff)
  (cond [(eff-open? eff)  (eff-open-channel eff)]
        [(eff-write? eff) (eff-write-channel eff)]
        [(eff-read? eff)  (eff-read-channel eff)]
        [(eff-close? eff) (eff-close-channel eff)]
        [else (error 'effect-desc-channel "not an effect descriptor: ~v" eff)]))

;; Extract position from any effect descriptor
(define (effect-desc-position eff)
  (cond [(eff-open? eff)  (eff-open-position eff)]
        [(eff-write? eff) (eff-write-position eff)]
        [(eff-read? eff)  (eff-read-position eff)]
        [(eff-close? eff) (eff-close-position eff)]
        [else (error 'effect-desc-position "not an effect descriptor: ~v" eff)]))

;; Effect accumulator: set of effect descriptors (monotone via append/union).
(struct effect-set (effects) #:transparent)

(define effect-set-empty (effect-set '()))

(define (effect-set-add es desc)
  (effect-set (cons desc (effect-set-effects es))))

(define (effect-set-merge es1 es2)
  (effect-set (remove-duplicates
               (append (effect-set-effects es1)
                       (effect-set-effects es2)))))

(define (effect-set-count es)
  (length (effect-set-effects es)))
