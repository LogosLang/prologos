#lang racket/base

;;;
;;; CHAMP — Compressed Hash Array Mapped Prefix-tree
;;;
;;; A persistent hash trie for Map and Set in Prologos.
;;; Two bitmaps (datamap, nodemap) + packed content vector.
;;; Data entries at front, child nodes at back.
;;; 5-bit hash segments per level (32 buckets per node).
;;;

(provide champ-empty
         champ-empty?
         champ-lookup
         champ-insert
         champ-delete
         champ-size
         champ-has-key?
         champ-fold
         champ-fold/hash
         champ-keys
         champ-vals
         champ-entries
         champ-equal?
         champ-insert-join
         ;; Transient builder
         (struct-out tchamp-root)
         champ-transient
         tchamp-insert!
         tchamp-delete!
         tchamp-freeze
         tchamp-size*
         tchamp-lookup)

(require racket/vector)

;; ========================================
;; Structs
;; ========================================

;; A CHAMP node: datamap and nodemap are 32-bit bitmasks.
;; content is a vector: data entries at front, child champ-nodes at back.
;; Data entries are 3-vectors: #(hash key value), storing the caller-provided
;; hash so sub-node promotion doesn't need to re-derive it.
(struct champ-node (datamap nodemap content) #:transparent)

;; Data entry accessors
(define (de-hash entry) (vector-ref entry 0))
(define (de-key entry) (vector-ref entry 1))
(define (de-val entry) (vector-ref entry 2))
(define (make-de hash key val) (vector hash key val))

;; Collision node: stores all (key . value) pairs with identical hash.
(struct champ-collision (hash entries) #:transparent)

;; Root wrapper with cached size.
(struct champ-root (node size) #:transparent)

;; ========================================
;; Constants and helpers
;; ========================================

(define BITS-PER-LEVEL 5)
(define BUCKET-COUNT 32) ; 2^5
(define MASK #b11111)
(define MAX-DEPTH 7) ; 32 / 5 = 6.4, so 7 levels max

;; Population count (number of 1-bits in a 32-bit integer)
(define (popcount x)
  (let* ([x (- x (bitwise-and (arithmetic-shift x -1) #x55555555))]
         [x (+ (bitwise-and x #x33333333)
               (bitwise-and (arithmetic-shift x -2) #x33333333))]
         [x (bitwise-and (+ x (arithmetic-shift x -4)) #x0f0f0f0f)]
         [x (+ x (arithmetic-shift x -8))]
         [x (+ x (arithmetic-shift x -16))])
    (bitwise-and x #x3f)))

;; Extract 5-bit hash segment at given level
(define (hash-segment hash level)
  (bitwise-and (arithmetic-shift hash (- (* level BITS-PER-LEVEL))) MASK))

;; Bit position for a segment
(define (segment-bit segment)
  (arithmetic-shift 1 segment))

;; Data index in content vector for a given bit
(define (data-index datamap bit)
  (popcount (bitwise-and datamap (- bit 1))))

;; Node index in content vector for a given bit
(define (node-index datamap nodemap bit)
  (+ (popcount datamap)
     (popcount (bitwise-and nodemap (- bit 1)))))

;; ========================================
;; Empty CHAMP
;; ========================================

(define empty-node (champ-node 0 0 #()))

(define champ-empty (champ-root empty-node 0))

(define (champ-empty? m)
  (zero? (champ-root-size m)))

;; ========================================
;; Lookup
;; ========================================

(define (champ-lookup root hash key)
  (node-lookup (champ-root-node root) hash key 0))

(define (node-lookup node hash key level)
  (cond
    [(champ-collision? node)
     (collision-lookup node key)]
    [else
     (define seg (hash-segment hash level))
     (define bit (segment-bit seg))
     (define dm (champ-node-datamap node))
     (define nm (champ-node-nodemap node))
     (define arr (champ-node-content node))
     (cond
       ;; Data entry at this position
       [(not (zero? (bitwise-and dm bit)))
        (define idx (data-index dm bit))
        (define entry (vector-ref arr idx))
        (if (equal? (de-key entry) key)
            (de-val entry)
            'none)]
       ;; Child node at this position
       [(not (zero? (bitwise-and nm bit)))
        (define idx (node-index dm nm bit))
        (define child (vector-ref arr idx))
        (node-lookup child hash key (+ level 1))]
       ;; Empty
       [else 'none])]))

(define (collision-lookup coll key)
  (define entries (champ-collision-entries coll))
  (let loop ([es entries])
    (cond
      [(null? es) 'none]
      [(equal? (caar es) key) (cdar es)]
      [else (loop (cdr es))])))

;; ========================================
;; Insert
;; ========================================

(define (champ-insert root hash key val)
  (define-values (new-node added?)
    (node-insert (champ-root-node root) hash key val 0))
  (champ-root new-node (+ (champ-root-size root) (if added? 1 0))))

(define (node-insert node hash key val level)
  (cond
    [(champ-collision? node)
     (collision-insert node hash key val)]
    [else
     (define seg (hash-segment hash level))
     (define bit (segment-bit seg))
     (define dm (champ-node-datamap node))
     (define nm (champ-node-nodemap node))
     (define arr (champ-node-content node))
     (cond
       ;; Data entry exists at this position
       [(not (zero? (bitwise-and dm bit)))
        (define idx (data-index dm bit))
        (define entry (vector-ref arr idx))
        (define existing-key (de-key entry))
        (cond
          ;; Same key: update value
          [(equal? existing-key key)
           (define new-arr (vector-copy arr))
           (vector-set! new-arr idx (make-de hash key val))
           (values (champ-node dm nm new-arr) #f)]
          ;; Different key: create sub-node or collision
          [else
           (define existing-hash (de-hash entry))  ;; USE STORED HASH (was: equal-hash-code)
           (define sub-node (merge-two existing-hash existing-key (de-val entry)
                                       hash key val (+ level 1)))
           ;; Remove data entry, add node entry
           (define new-dm (bitwise-and dm (bitwise-not bit)))
           (define new-nm (bitwise-ior nm bit))
           (define new-arr (vec-remove-insert-node arr idx
                                                    (data-index new-dm bit)
                                                    (node-index new-dm new-nm bit)
                                                    sub-node
                                                    dm))
           (values (champ-node new-dm new-nm new-arr) #t)])]
       ;; Child node exists at this position
       [(not (zero? (bitwise-and nm bit)))
        (define idx (node-index dm nm bit))
        (define child (vector-ref arr idx))
        (define-values (new-child added?) (node-insert child hash key val (+ level 1)))
        (define new-arr (vector-copy arr))
        (vector-set! new-arr idx new-child)
        (values (champ-node dm nm new-arr) added?)]
       ;; Empty: add data entry
       [else
        (define new-dm (bitwise-ior dm bit))
        (define idx (data-index new-dm bit))
        (define new-arr (vec-insert arr idx (make-de hash key val)))
        (values (champ-node new-dm nm new-arr) #t)])]))

;; Merge two key-value pairs into a sub-node (or collision node)
(define (merge-two hash1 key1 val1 hash2 key2 val2 level)
  (cond
    [(>= level MAX-DEPTH)
     ;; Full hash collision: store as collision node
     (champ-collision hash1 (list (cons key1 val1) (cons key2 val2)))]
    [else
     (define seg1 (hash-segment hash1 level))
     (define seg2 (hash-segment hash2 level))
     (define bit1 (segment-bit seg1))
     (define bit2 (segment-bit seg2))
     (cond
       [(= seg1 seg2)
        ;; Same segment: recurse deeper
        (define child (merge-two hash1 key1 val1 hash2 key2 val2 (+ level 1)))
        (champ-node 0 bit1 (vector child))]
       [else
        ;; Different segments: two data entries
        (if (< seg1 seg2)
            (champ-node (bitwise-ior bit1 bit2) 0
                        (vector (make-de hash1 key1 val1) (make-de hash2 key2 val2)))
            (champ-node (bitwise-ior bit1 bit2) 0
                        (vector (make-de hash2 key2 val2) (make-de hash1 key1 val1))))])]))

(define (collision-insert coll hash key val)
  (define entries (champ-collision-entries coll))
  (let loop ([es entries] [acc '()])
    (cond
      [(null? es)
       ;; Key not found: add new entry
       (values (champ-collision hash (cons (cons key val) entries)) #t)]
      [(equal? (caar es) key)
       ;; Key found: update
       (values (champ-collision hash
                 (append (reverse acc) (cons (cons key val) (cdr es))))
               #f)]
      [else (loop (cdr es) (cons (car es) acc))])))

;; ========================================
;; Delete
;; ========================================

(define (champ-delete root hash key)
  (define-values (new-node removed?)
    (node-delete (champ-root-node root) hash key 0))
  (champ-root (or new-node empty-node)
              (- (champ-root-size root) (if removed? 1 0))))

(define (node-delete node hash key level)
  (cond
    [(champ-collision? node)
     (collision-delete node key)]
    [else
     (define seg (hash-segment hash level))
     (define bit (segment-bit seg))
     (define dm (champ-node-datamap node))
     (define nm (champ-node-nodemap node))
     (define arr (champ-node-content node))
     (cond
       ;; Data entry at this position
       [(not (zero? (bitwise-and dm bit)))
        (define idx (data-index dm bit))
        (define entry (vector-ref arr idx))
        (cond
          [(equal? (de-key entry) key)
           ;; Found: remove data entry
           (define new-dm (bitwise-and dm (bitwise-not bit)))
           (define new-arr (vec-remove arr idx))
           (if (and (zero? new-dm) (zero? nm))
               (values #f #t) ; node becomes empty
               (values (champ-node new-dm nm new-arr) #t))]
          [else (values node #f)])]
       ;; Child node at this position
       [(not (zero? (bitwise-and nm bit)))
        (define idx (node-index dm nm bit))
        (define child (vector-ref arr idx))
        (define-values (new-child removed?) (node-delete child hash key (+ level 1)))
        (cond
          [(not removed?) (values node #f)]
          [(not new-child)
           ;; Child became empty: remove node entry
           (define new-nm (bitwise-and nm (bitwise-not bit)))
           (define new-arr (vec-remove arr idx))
           (if (and (zero? dm) (zero? new-nm))
               (values #f #t)
               (values (champ-node dm new-nm new-arr) #t))]
          ;; Child is a single-entry node: inline it as data
          [(and (champ-node? new-child)
                (= (popcount (champ-node-datamap new-child)) 1)
                (zero? (champ-node-nodemap new-child)))
           (define entry (vector-ref (champ-node-content new-child) 0))
           ;; Replace node with data entry
           (define new-nm (bitwise-and nm (bitwise-not bit)))
           (define new-dm (bitwise-ior dm bit))
           ;; Remove old node, insert data at correct position
           (define arr-without-node (vec-remove arr idx))
           (define data-idx (data-index new-dm bit))
           (define new-arr (vec-insert arr-without-node data-idx entry))
           (values (champ-node new-dm new-nm new-arr) #t)]
          [else
           ;; Child still has entries: update in place
           (define new-arr (vector-copy arr))
           (vector-set! new-arr idx new-child)
           (values (champ-node dm nm new-arr) #t)])]
       ;; Not found
       [else (values node #f)])]))

(define (collision-delete coll key)
  (define entries (champ-collision-entries coll))
  (define new-entries (filter (lambda (e) (not (equal? (car e) key))) entries))
  (cond
    [(= (length new-entries) (length entries))
     (values coll #f)]
    [(= (length new-entries) 1)
     ;; Single entry left: promote to regular node is handled by caller
     ;; For simplicity, keep as collision with one entry (still works)
     (values (champ-collision (champ-collision-hash coll) new-entries) #t)]
    [else
     (values (champ-collision (champ-collision-hash coll) new-entries) #t)]))

;; ========================================
;; Size / has-key?
;; ========================================

(define (champ-size m)
  (champ-root-size m))

(define (champ-has-key? root hash key)
  (not (eq? 'none (champ-lookup root hash key))))

;; ========================================
;; Fold / traversal
;; ========================================

(define (champ-fold root f init)
  (node-fold (champ-root-node root) f init))

;; champ-fold/hash : root (hash key val acc → acc) init → acc
;; Like champ-fold but exposes the stored hash for each entry.
;; Enables correct cross-map operations when custom hash functions are used.
(define (champ-fold/hash root f init)
  (node-fold/hash (champ-root-node root) f init))

(define (node-fold node f acc)
  (cond
    [(champ-collision? node)
     (foldl (lambda (entry a) (f (car entry) (cdr entry) a))
            acc (champ-collision-entries node))]
    [else
     (define dm (champ-node-datamap node))
     (define nm (champ-node-nodemap node))
     (define arr (champ-node-content node))
     (define data-count (popcount dm))
     (define node-count (popcount nm))
     ;; Fold over data entries
     (define acc2
       (let loop ([i 0] [a acc])
         (if (>= i data-count)
             a
             (let ([entry (vector-ref arr i)])
               (loop (+ i 1) (f (de-key entry) (de-val entry) a))))))
     ;; Fold over child nodes
     (let loop ([i 0] [a acc2])
       (if (>= i node-count)
           a
           (let ([child (vector-ref arr (+ data-count i))])
             (loop (+ i 1) (node-fold child f a)))))]))

(define (node-fold/hash node f acc)
  (cond
    [(champ-collision? node)
     ;; Collision nodes store the shared hash once
     (define h (champ-collision-hash node))
     (foldl (lambda (entry a) (f h (car entry) (cdr entry) a))
            acc (champ-collision-entries node))]
    [else
     (define dm (champ-node-datamap node))
     (define nm (champ-node-nodemap node))
     (define arr (champ-node-content node))
     (define data-count (popcount dm))
     (define node-count (popcount nm))
     ;; Fold over data entries (hash stored in each entry)
     (define acc2
       (let loop ([i 0] [a acc])
         (if (>= i data-count)
             a
             (let ([entry (vector-ref arr i)])
               (loop (+ i 1) (f (de-hash entry) (de-key entry) (de-val entry) a))))))
     ;; Fold over child nodes
     (let loop ([i 0] [a acc2])
       (if (>= i node-count)
           a
           (let ([child (vector-ref arr (+ data-count i))])
             (loop (+ i 1) (node-fold/hash child f a)))))]))

(define (champ-keys root)
  (champ-fold root (lambda (k v acc) (cons k acc)) '()))

(define (champ-vals root)
  (champ-fold root (lambda (k v acc) (cons v acc)) '()))

(define (champ-entries root)
  (champ-fold root (lambda (k v acc) (cons (cons k v) acc)) '()))

;; ========================================
;; Equality
;; ========================================

;; Uses champ-fold/hash to look up keys in map b using the STORED hash,
;; not equal-hash-code. This is correct even when maps were created with
;; custom hash functions (e.g., the propagator network's cell-id-hash).
(define (champ-equal? a b)
  (and (= (champ-root-size a) (champ-root-size b))
       (champ-fold/hash a
                        (lambda (h k v ok?)
                          (and ok?
                               (let ([v2 (champ-lookup b h k)])
                                 (and (not (eq? v2 'none))
                                      (equal? v v2)))))
                        #t)))

;; ========================================
;; Lattice-aware insert (join on collision)
;; ========================================

;; champ-insert-join : champ-root hash key val (val val → val) → champ-root
;; Insert with join-on-collision: if key already exists, apply join-fn
;; to merge existing and new values. If key is absent, insert directly.
;; This is the foundation for lattice-compatible persistent maps —
;; the propagator network's cell map uses this for monotonic merge.
(define (champ-insert-join root hash key val join-fn)
  (let ([existing (champ-lookup root hash key)])
    (if (eq? existing 'none)
        (champ-insert root hash key val)
        (champ-insert root hash key (join-fn existing val)))))

;; ========================================
;; Vector helpers
;; ========================================

;; Insert val at index idx into vector, shifting later elements right
(define (vec-insert vec idx val)
  (define len (vector-length vec))
  (define new (make-vector (+ len 1)))
  (let loop ([i 0])
    (when (< i idx)
      (vector-set! new i (vector-ref vec i))
      (loop (+ i 1))))
  (vector-set! new idx val)
  (let loop ([i idx])
    (when (< i len)
      (vector-set! new (+ i 1) (vector-ref vec i))
      (loop (+ i 1))))
  new)

;; Remove element at index idx from vector
(define (vec-remove vec idx)
  (define len (vector-length vec))
  (define new (make-vector (- len 1)))
  (let loop ([i 0])
    (when (< i idx)
      (vector-set! new i (vector-ref vec i))
      (loop (+ i 1))))
  (let loop ([i (+ idx 1)])
    (when (< i len)
      (vector-set! new (- i 1) (vector-ref vec i))
      (loop (+ i 1))))
  new)

;; Remove data entry at old-data-idx, then insert node at node-idx position
;; Used when converting a data entry to a sub-node during insert
(define (vec-remove-insert-node arr old-data-idx _new-data-idx node-idx sub-node old-dm)
  ;; Remove the data entry first
  (define arr2 (vec-remove arr old-data-idx))
  ;; Now insert the node. After removing data entry, node positions shift.
  ;; The node-idx was computed with the NEW bitmaps, but relative to the
  ;; array AFTER removal. Recompute: nodes sit after all data entries.
  ;; new data count = popcount(old-dm) - 1 (we removed one data)
  ;; node position in arr2 = data-count-new + popcount(nm-bits-before-bit)
  ;; But node-idx was already computed with new-dm and new-nm, so it accounts
  ;; for the reduced data count. We just need to adjust for the removal offset.
  (define data-count-old (popcount old-dm))
  ;; After removing data entry at old-data-idx, the node insertion point is:
  ;; node-idx was computed using new datamap (one fewer data bit), so
  ;; it's already correct relative to the new array layout.
  ;; However, we need to clamp to valid range.
  (define clamped-idx (min node-idx (vector-length arr2)))
  (vec-insert arr2 clamped-idx sub-node))

;; ========================================
;; Transient Builder — Mutable hash table
;; ========================================
;; A transient CHAMP uses a Racket mutable hash table for O(1) amortized
;; insert/delete. Freezing rebuilds the persistent CHAMP from hash entries.
;; This is simpler than Clojure's owner-id approach but achieves O(n) total
;; for batch construction. The owner-id optimization can be added later.
;;
;; The hash table stores key → (cons stored-hash val), preserving the
;; caller-provided hash so tchamp-freeze can reconstruct the CHAMP with
;; the correct hash function (not just equal-hash-code).

(struct tchamp-root (entries size) #:mutable #:transparent)
;; entries: mutable Racket hash table, key → (cons hash val)
;; size:    element count (tracked separately for O(1) access)

;; champ-transient : champ-root -> tchamp-root
;; Create a transient from a persistent map.
;; Uses champ-fold/hash to preserve the stored hash per entry.
(define (champ-transient root)
  (define ht (make-hash))
  (champ-fold/hash root (lambda (h k v _) (hash-set! ht k (cons h v))) (void))
  (tchamp-root ht (champ-root-size root)))

;; tchamp-insert! : tchamp-root hash key val -> tchamp-root
;; Insert or update a key. Returns the same tchamp-root.
(define (tchamp-insert! troot hash key val)
  (define ht (tchamp-root-entries troot))
  (unless (hash-has-key? ht key)
    (set-tchamp-root-size! troot (+ (tchamp-root-size troot) 1)))
  (hash-set! ht key (cons hash val))
  troot)

;; tchamp-delete! : tchamp-root hash key -> tchamp-root
;; Delete a key. Returns the same tchamp-root.
(define (tchamp-delete! troot hash key)
  (define ht (tchamp-root-entries troot))
  (when (hash-has-key? ht key)
    (set-tchamp-root-size! troot (- (tchamp-root-size troot) 1)))
  (hash-remove! ht key)
  troot)

;; tchamp-freeze : tchamp-root -> champ-root
;; Freeze the transient into a persistent map.
;; Uses the stored hash per entry, not equal-hash-code.
(define (tchamp-freeze troot)
  (define ht (tchamp-root-entries troot))
  (for/fold ([m champ-empty])
            ([(k hv) (in-hash ht)])
    (champ-insert m (car hv) k (cdr hv))))

;; tchamp-size* : tchamp-root -> exact-nonneg-integer
(define (tchamp-size* troot)
  (tchamp-root-size troot))

;; tchamp-lookup : tchamp-root hash key -> val or 'none
(define (tchamp-lookup troot hash key)
  (define entry (hash-ref (tchamp-root-entries troot) key #f))
  (if entry (cdr entry) 'none))

;; ========================================
;; Module tests
;; ========================================

(module+ test
  (require rackunit)

  (test-case "champ: empty map"
    (check-true (champ-empty? champ-empty))
    (check-equal? (champ-size champ-empty) 0)
    (check-equal? (champ-lookup champ-empty 42 'foo) 'none))

  (test-case "champ: single insert and lookup"
    (define m (champ-insert champ-empty (equal-hash-code 'a) 'a 1))
    (check-equal? (champ-size m) 1)
    (check-equal? (champ-lookup m (equal-hash-code 'a) 'a) 1)
    (check-equal? (champ-lookup m (equal-hash-code 'b) 'b) 'none))

  (test-case "champ: multiple inserts"
    (define m0 champ-empty)
    (define m1 (champ-insert m0 (equal-hash-code 'a) 'a 1))
    (define m2 (champ-insert m1 (equal-hash-code 'b) 'b 2))
    (define m3 (champ-insert m2 (equal-hash-code 'c) 'c 3))
    (check-equal? (champ-size m3) 3)
    (check-equal? (champ-lookup m3 (equal-hash-code 'a) 'a) 1)
    (check-equal? (champ-lookup m3 (equal-hash-code 'b) 'b) 2)
    (check-equal? (champ-lookup m3 (equal-hash-code 'c) 'c) 3))

  (test-case "champ: update existing key"
    (define m1 (champ-insert champ-empty (equal-hash-code 'a) 'a 1))
    (define m2 (champ-insert m1 (equal-hash-code 'a) 'a 99))
    (check-equal? (champ-size m2) 1)
    (check-equal? (champ-lookup m2 (equal-hash-code 'a) 'a) 99))

  (test-case "champ: delete"
    (define m1 (champ-insert champ-empty (equal-hash-code 'a) 'a 1))
    (define m2 (champ-insert m1 (equal-hash-code 'b) 'b 2))
    (define m3 (champ-delete m2 (equal-hash-code 'a) 'a))
    (check-equal? (champ-size m3) 1)
    (check-equal? (champ-lookup m3 (equal-hash-code 'a) 'a) 'none)
    (check-equal? (champ-lookup m3 (equal-hash-code 'b) 'b) 2))

  (test-case "champ: delete non-existent key"
    (define m1 (champ-insert champ-empty (equal-hash-code 'a) 'a 1))
    (define m2 (champ-delete m1 (equal-hash-code 'z) 'z))
    (check-equal? (champ-size m2) 1)
    (check-equal? (champ-lookup m2 (equal-hash-code 'a) 'a) 1))

  (test-case "champ: has-key?"
    (define m (champ-insert champ-empty (equal-hash-code 'x) 'x 42))
    (check-true (champ-has-key? m (equal-hash-code 'x) 'x))
    (check-false (champ-has-key? m (equal-hash-code 'y) 'y)))

  (test-case "champ: fold, keys, vals, entries"
    (define m0 champ-empty)
    (define m1 (champ-insert m0 (equal-hash-code 'a) 'a 1))
    (define m2 (champ-insert m1 (equal-hash-code 'b) 'b 2))
    (define m3 (champ-insert m2 (equal-hash-code 'c) 'c 3))
    ;; fold: sum of values
    (check-equal? (champ-fold m3 (lambda (k v acc) (+ v acc)) 0) 6)
    ;; keys (order may vary, so sort)
    (check-equal? (sort (champ-keys m3) symbol<?) '(a b c))
    ;; vals (sort for comparison)
    (check-equal? (sort (champ-vals m3) <) '(1 2 3))
    ;; entries
    (check-equal? (length (champ-entries m3)) 3))

  (test-case "champ: persistence (old map unaffected)"
    (define m1 (champ-insert champ-empty (equal-hash-code 'a) 'a 1))
    (define m2 (champ-insert m1 (equal-hash-code 'b) 'b 2))
    ;; m1 should still have only 'a
    (check-equal? (champ-size m1) 1)
    (check-equal? (champ-lookup m1 (equal-hash-code 'b) 'b) 'none))

  (test-case "champ: many keys (stress test)"
    (define m
      (for/fold ([m champ-empty])
                ([i (in-range 100)])
        (champ-insert m (equal-hash-code i) i (* i i))))
    (check-equal? (champ-size m) 100)
    (for ([i (in-range 100)])
      (check-equal? (champ-lookup m (equal-hash-code i) i) (* i i))))

  (test-case "champ: 1500 keys (scaling stress test)"
    ;; Regression: custom hash functions (not equal-hash-code) used to lose
    ;; entries during data-to-node promotion because merge-two re-derived the
    ;; hash via equal-hash-code instead of using the caller-provided hash.
    (define m
      (for/fold ([m champ-empty])
                ([i (in-range 1500)])
        (champ-insert m i i (* i i))))  ;; hash = i (custom, not equal-hash-code)
    (check-equal? (champ-size m) 1500)
    (for ([i (in-range 1500)])
      (check-not-equal? (champ-lookup m i i) 'none
                         (format "lookup failed for key ~a" i))
      (check-equal? (champ-lookup m i i) (* i i))))

  (test-case "champ: struct keys with custom hash (propagator pattern)"
    ;; Simulates how propagator.rkt uses CHAMP: cell-id structs with
    ;; cell-id-hash (= integer n) rather than equal-hash-code.
    (struct test-id (n) #:transparent)
    (define (test-id-hash tid) (test-id-n tid))
    (define m
      (for/fold ([m champ-empty])
                ([i (in-range 1500)])
        (define tid (test-id i))
        (champ-insert m (test-id-hash tid) tid (* i i))))
    (check-equal? (champ-size m) 1500)
    (for ([i (in-range 1500)])
      (define tid (test-id i))
      (check-not-equal? (champ-lookup m (test-id-hash tid) tid) 'none
                         (format "lookup failed for test-id ~a" i))))

  (test-case "champ: equality"
    (define m1 (champ-insert (champ-insert champ-empty
                               (equal-hash-code 'a) 'a 1)
                             (equal-hash-code 'b) 'b 2))
    (define m2 (champ-insert (champ-insert champ-empty
                               (equal-hash-code 'b) 'b 2)
                             (equal-hash-code 'a) 'a 1))
    (check-true (champ-equal? m1 m2))
    (check-false (champ-equal? m1 champ-empty)))

  ;; ---- Transient builder tests ----

  (test-case "tchamp: empty roundtrip"
    (let* ([t (champ-transient champ-empty)]
           [m (tchamp-freeze t)])
      (check-true (champ-empty? m))))

  (test-case "tchamp: insert and freeze"
    (let ([t (champ-transient champ-empty)])
      (tchamp-insert! t (equal-hash-code 'a) 'a 1)
      (tchamp-insert! t (equal-hash-code 'b) 'b 2)
      (tchamp-insert! t (equal-hash-code 'c) 'c 3)
      (let ([m (tchamp-freeze t)])
        (check-equal? (champ-size m) 3)
        (check-equal? (champ-lookup m (equal-hash-code 'a) 'a) 1)
        (check-equal? (champ-lookup m (equal-hash-code 'b) 'b) 2)
        (check-equal? (champ-lookup m (equal-hash-code 'c) 'c) 3))))

  (test-case "tchamp: from non-empty persistent"
    (let* ([m0 (champ-insert champ-empty (equal-hash-code 'x) 'x 10)]
           [t  (champ-transient m0)])
      (tchamp-insert! t (equal-hash-code 'y) 'y 20)
      (let ([m1 (tchamp-freeze t)])
        (check-equal? (champ-size m1) 2)
        (check-equal? (champ-lookup m1 (equal-hash-code 'x) 'x) 10)
        (check-equal? (champ-lookup m1 (equal-hash-code 'y) 'y) 20)
        ;; Original unmodified
        (check-equal? (champ-size m0) 1))))

  (test-case "tchamp: delete in transient"
    (let* ([m0 (champ-insert (champ-insert champ-empty
                                (equal-hash-code 'a) 'a 1)
                              (equal-hash-code 'b) 'b 2)]
           [t  (champ-transient m0)])
      (tchamp-delete! t (equal-hash-code 'a) 'a)
      (let ([m1 (tchamp-freeze t)])
        (check-equal? (champ-size m1) 1)
        (check-equal? (champ-lookup m1 (equal-hash-code 'a) 'a) 'none)
        (check-equal? (champ-lookup m1 (equal-hash-code 'b) 'b) 2))))

  (test-case "tchamp: update existing key"
    (let ([t (champ-transient champ-empty)])
      (tchamp-insert! t (equal-hash-code 'a) 'a 1)
      (tchamp-insert! t (equal-hash-code 'a) 'a 99)
      (let ([m (tchamp-freeze t)])
        (check-equal? (champ-size m) 1)
        (check-equal? (champ-lookup m (equal-hash-code 'a) 'a) 99))))

  (test-case "tchamp: size tracking"
    (let ([t (champ-transient champ-empty)])
      (check-equal? (tchamp-size* t) 0)
      (tchamp-insert! t (equal-hash-code 'a) 'a 1)
      (check-equal? (tchamp-size* t) 1)
      (tchamp-insert! t (equal-hash-code 'b) 'b 2)
      (check-equal? (tchamp-size* t) 2)
      (tchamp-delete! t (equal-hash-code 'a) 'a)
      (check-equal? (tchamp-size* t) 1)))

  (test-case "tchamp: lookup in transient"
    (let ([t (champ-transient champ-empty)])
      (tchamp-insert! t (equal-hash-code 'a) 'a 42)
      (check-equal? (tchamp-lookup t (equal-hash-code 'a) 'a) 42)
      (check-equal? (tchamp-lookup t (equal-hash-code 'z) 'z) 'none)))

  (test-case "tchamp: 100 entries"
    (let ([t (champ-transient champ-empty)])
      (for ([i (in-range 100)])
        (tchamp-insert! t (equal-hash-code i) i (* i i)))
      (let ([m (tchamp-freeze t)])
        (check-equal? (champ-size m) 100)
        (for ([i (in-range 100)])
          (check-equal? (champ-lookup m (equal-hash-code i) i) (* i i))))))

  ;; ---- champ-insert-join tests ----

  (test-case "champ-insert-join: insert new key (no collision)"
    (define m (champ-insert-join champ-empty (equal-hash-code 'a) 'a 10 +))
    (check-equal? (champ-size m) 1)
    (check-equal? (champ-lookup m (equal-hash-code 'a) 'a) 10))

  (test-case "champ-insert-join: join on existing key"
    (define m1 (champ-insert champ-empty (equal-hash-code 'a) 'a 10))
    (define m2 (champ-insert-join m1 (equal-hash-code 'a) 'a 5 +))
    (check-equal? (champ-size m2) 1)
    (check-equal? (champ-lookup m2 (equal-hash-code 'a) 'a) 15))

  (test-case "champ-insert-join: join preserves other keys"
    (define m1 (champ-insert (champ-insert champ-empty
                                (equal-hash-code 'a) 'a 10)
                              (equal-hash-code 'b) 'b 20))
    (define m2 (champ-insert-join m1 (equal-hash-code 'a) 'a 5 +))
    (check-equal? (champ-size m2) 2)
    (check-equal? (champ-lookup m2 (equal-hash-code 'a) 'a) 15)
    (check-equal? (champ-lookup m2 (equal-hash-code 'b) 'b) 20))

  (test-case "champ-insert-join: max as join-fn (lattice-like)"
    (define m1 (champ-insert champ-empty (equal-hash-code 'x) 'x 3))
    ;; Join with max: 3 and 7 → 7
    (define m2 (champ-insert-join m1 (equal-hash-code 'x) 'x 7 max))
    (check-equal? (champ-lookup m2 (equal-hash-code 'x) 'x) 7)
    ;; Join with max: 7 and 2 → 7 (no change in value, but new map)
    (define m3 (champ-insert-join m2 (equal-hash-code 'x) 'x 2 max))
    (check-equal? (champ-lookup m3 (equal-hash-code 'x) 'x) 7))

  (test-case "champ-insert-join: set-union as join-fn"
    (define (set-union a b) (append a b))
    (define m1 (champ-insert champ-empty (equal-hash-code 'k) 'k '(1 2)))
    (define m2 (champ-insert-join m1 (equal-hash-code 'k) 'k '(3 4) set-union))
    (check-equal? (champ-lookup m2 (equal-hash-code 'k) 'k) '(1 2 3 4)))

  (test-case "champ-insert-join: persistence (old map unaffected)"
    (define m1 (champ-insert champ-empty (equal-hash-code 'a) 'a 10))
    (define m2 (champ-insert-join m1 (equal-hash-code 'a) 'a 5 +))
    ;; m1 should be unchanged
    (check-equal? (champ-lookup m1 (equal-hash-code 'a) 'a) 10)
    (check-equal? (champ-lookup m2 (equal-hash-code 'a) 'a) 15))

  ;; ---- Custom hash function correctness tests ----

  (test-case "champ-equal?: custom hash maps"
    ;; Two maps built with custom hashes (integer directly), different insertion order
    (define m1 (champ-insert (champ-insert champ-empty 10 'a 1) 20 'b 2))
    (define m2 (champ-insert (champ-insert champ-empty 20 'b 2) 10 'a 1))
    (check-true (champ-equal? m1 m2)))

  (test-case "champ-fold/hash: exposes stored hash"
    (define m (champ-insert (champ-insert champ-empty 42 'x 1) 99 'y 2))
    (define entries
      (champ-fold/hash m (lambda (h k v acc) (cons (list h k v) acc)) '()))
    (check-equal? (length entries) 2)
    ;; Both stored hashes should be the originals (42, 99)
    (define hashes (sort (map car entries) <))
    (check-equal? hashes '(42 99)))

  (test-case "tchamp: custom hash roundtrip"
    ;; Build a map with custom integer hashes, roundtrip through transient,
    ;; verify lookups still work with the original hashes.
    (define m0
      (for/fold ([m champ-empty])
                ([i (in-range 200)])
        (champ-insert m (* i 7) i (* i i))))  ;; hash = i*7 (custom)
    (check-equal? (champ-size m0) 200)
    ;; Roundtrip
    (define t (champ-transient m0))
    (check-equal? (tchamp-size* t) 200)
    (define m1 (tchamp-freeze t))
    (check-equal? (champ-size m1) 200)
    ;; All entries findable with original hashes
    (for ([i (in-range 200)])
      (check-equal? (champ-lookup m1 (* i 7) i) (* i i)
                    (format "roundtrip lookup failed for key ~a" i))))

  (test-case "tchamp: custom hash insert in transient"
    ;; Start with custom-hash map, insert via transient, freeze and check
    (define m0 (champ-insert champ-empty 42 'a 1))
    (define t (champ-transient m0))
    (tchamp-insert! t 99 'b 2)  ;; custom hash 99
    (define m1 (tchamp-freeze t))
    (check-equal? (champ-size m1) 2)
    (check-equal? (champ-lookup m1 42 'a) 1)
    (check-equal? (champ-lookup m1 99 'b) 2))
)
