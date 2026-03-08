#lang racket/base

;;;
;;; CONFLUENCE ANALYSIS
;;; Phase 2c of FL Narrowing: classify functions by confluence properties.
;;;
;;; A function is confluent if all valid narrowing evaluation orders produce
;;; the same result. Confluent functions support needed narrowing (optimal
;;; strategy); non-confluent functions require basic narrowing (complete but
;;; potentially redundant).
;;;
;;; The analysis works on definitional trees:
;;;   - No dt-or nodes → automatically confluent (fast path)
;;;   - dt-or nodes present → extract critical pairs, check joinability
;;;
;;; A critical pair arises when two branches of a dt-or can both fire for
;;; the same input. The pair is joinable if both branches produce the same
;;; result (checked via structural equality of subtrees).
;;;
;;; DEPENDENCIES: definitional-tree.rkt, syntax.rkt
;;; (No dependency on reduction.rkt — uses structural comparison to avoid
;;; circular dependency: reduction.rkt → narrowing.rkt → confluence-analysis.rkt)
;;;

(require racket/match
         racket/list
         "definitional-tree.rkt"
         "syntax.rkt")

(provide
 ;; Structs
 (struct-out critical-pair)
 (struct-out confluence-result)
 ;; Core analysis
 analyze-confluence
 ;; Helpers (exported for testing)
 extract-or-rules
 collect-all-or-groups
 compute-critical-pairs
 branches-joinable?
 extract-leaf-rules
 extract-representative-rhs
 ;; Registry
 current-confluence-registry
 lookup-confluence
 register-confluence!)

;; ========================================
;; Structs
;; ========================================

;; A critical pair: two branches of a dt-or that overlap.
;; branch1-idx, branch2-idx: 0-based indices into the dt-or's branch list
;; rhs1, rhs2: representative RHS from each branch (first leaf rule)
;; joinable?: whether structural comparison deems them equivalent
(struct critical-pair (branch1-idx branch2-idx rhs1 rhs2 joinable?) #:transparent)

;; Result of confluence analysis.
;; class: 'confluent | 'non-confluent | 'unknown
;; critical-pairs: all computed critical pairs (empty for fast-path confluent)
(struct confluence-result (class critical-pairs) #:transparent)

;; ========================================
;; Registry (caches analysis results per function)
;; ========================================

(define current-confluence-registry (make-parameter (hasheq)))

(define (register-confluence! name result)
  (current-confluence-registry
   (hash-set (current-confluence-registry) name result)))

(define (lookup-confluence name)
  (hash-ref (current-confluence-registry) name #f))

;; ========================================
;; Core analysis
;; ========================================

;; analyze-confluence : (or/c dt-branch? dt-or? dt-rule? dt-exempt? #f) → confluence-result
;; Analyze a definitional tree for confluence.
(define (analyze-confluence tree)
  (cond
    ;; No tree → unknown
    [(not tree)
     (confluence-result 'unknown '())]
    ;; Single rule or exempt → trivially confluent
    [(dt-rule? tree)
     (confluence-result 'confluent '())]
    [(dt-exempt? tree)
     (confluence-result 'confluent '())]
    ;; Fast path: no Or nodes anywhere → confluent
    ;; Covers add, not, append, map, filter, and vast majority of functions
    [(not (def-tree-has-or? tree))
     (confluence-result 'confluent '())]
    ;; Slow path: collect and analyze critical pairs from dt-or nodes
    [else
     (define all-pairs (collect-critical-pairs tree))
     (define non-joinable
       (filter (lambda (cp) (not (critical-pair-joinable? cp))) all-pairs))
     (cond
       [(null? non-joinable)
        (confluence-result 'confluent all-pairs)]
       [else
        (confluence-result 'non-confluent all-pairs)])]))

;; ========================================
;; Critical pair collection
;; ========================================

;; collect-critical-pairs : tree → (listof critical-pair)
;; Walk the entire tree, collecting critical pairs from all dt-or nodes.
(define (collect-critical-pairs tree)
  (match tree
    [(dt-or branches)
     ;; Critical pairs from this or-node
     (define local-pairs (compute-critical-pairs branches))
     ;; Plus pairs from nested or-nodes within branches
     (define sub-pairs (append-map collect-critical-pairs branches))
     (append local-pairs sub-pairs)]
    [(dt-branch _ _ children)
     (append-map
      (lambda (pair) (collect-critical-pairs (cdr pair)))
      children)]
    [(dt-rule _) '()]
    [(dt-exempt) '()]))

;; compute-critical-pairs : (listof tree) → (listof critical-pair)
;; For each pair of branches (i < j), create a critical pair and check joinability.
(define (compute-critical-pairs branches)
  (define n (length branches))
  (for*/list ([i (in-range n)]
              [j (in-range (+ i 1) n)])
    (define b1 (list-ref branches i))
    (define b2 (list-ref branches j))
    (define rhs1 (extract-representative-rhs b1))
    (define rhs2 (extract-representative-rhs b2))
    (define joinable (branches-joinable? b1 b2))
    (critical-pair i j rhs1 rhs2 joinable)))

;; ========================================
;; Or-group extraction
;; ========================================

;; extract-or-rules : tree → (listof (list nat tree))
;; Extract branches from a dt-or node with their indices.
;; Returns empty for non-dt-or nodes.
(define (extract-or-rules tree)
  (match tree
    [(dt-or branches)
     (for/list ([b (in-list branches)]
                [i (in-naturals)])
       (list i b))]
    [_ '()]))

;; collect-all-or-groups : tree → (listof (listof tree))
;; Collect all dt-or branch groups from the entire tree.
(define (collect-all-or-groups tree)
  (match tree
    [(dt-or branches)
     (cons branches
           (append-map collect-all-or-groups branches))]
    [(dt-branch _ _ children)
     (append-map
      (lambda (p) (collect-all-or-groups (cdr p)))
      children)]
    [(dt-rule _) '()]
    [(dt-exempt) '()]))

;; ========================================
;; Joinability checking
;; ========================================

;; branches-joinable? : tree × tree → boolean
;; Structural comparison: two subtrees are joinable if they have identical
;; structure and leaf expressions. Conservative: returns #f when unsure.
(define (branches-joinable? b1 b2)
  (match* (b1 b2)
    ;; Both rules: joinable iff RHS structurally equal
    [((dt-rule rhs1) (dt-rule rhs2))
     (equal? rhs1 rhs2)]

    ;; Both branches at same position: compare children pairwise
    [((dt-branch pos1 _ children1) (dt-branch pos2 _ children2))
     (and (= pos1 pos2)
          (= (length children1) (length children2))
          ;; Sort by ctor-name for order-independent comparison
          (let ([sorted1 (sort children1 symbol<? #:key car)]
                [sorted2 (sort children2 symbol<? #:key car)])
            (for/and ([c1 (in-list sorted1)]
                      [c2 (in-list sorted2)])
              (and (eq? (car c1) (car c2))
                   (branches-joinable? (cdr c1) (cdr c2))))))]

    ;; Both or: pairwise joinable
    [((dt-or bs1) (dt-or bs2))
     (and (= (length bs1) (length bs2))
          (for/and ([x (in-list bs1)]
                    [y (in-list bs2)])
            (branches-joinable? x y)))]

    ;; Both exempt: trivially joinable (both fail)
    [((dt-exempt) (dt-exempt)) #t]

    ;; Mismatched structure: conservative non-joinable
    [(_ _) #f]))

;; symbol<? : symbol × symbol → boolean
(define (symbol<? a b)
  (string<? (symbol->string a) (symbol->string b)))

;; ========================================
;; Leaf rule extraction
;; ========================================

;; extract-representative-rhs : tree → (or/c expr? #f)
;; First dt-rule leaf found (depth-first).
(define (extract-representative-rhs tree)
  (match tree
    [(dt-rule rhs) rhs]
    [(dt-branch _ _ children)
     (let loop ([cs children])
       (cond
         [(null? cs) #f]
         [else
          (or (extract-representative-rhs (cdar cs))
              (loop (cdr cs)))]))]
    [(dt-or branches)
     (let loop ([bs branches])
       (cond
         [(null? bs) #f]
         [else
          (or (extract-representative-rhs (car bs))
              (loop (cdr bs)))]))]
    [(dt-exempt) #f]))

;; extract-leaf-rules : tree → (listof expr)
;; Collect all dt-rule RHS expressions from the tree.
(define (extract-leaf-rules tree)
  (match tree
    [(dt-rule rhs) (list rhs)]
    [(dt-branch _ _ children)
     (append-map (lambda (p) (extract-leaf-rules (cdr p))) children)]
    [(dt-or branches)
     (append-map extract-leaf-rules branches)]
    [(dt-exempt) '()]))
