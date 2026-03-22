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
         ;; Transient builder (hash-table-based, legacy)
         (struct-out tchamp-root)
         champ-transient
         tchamp-insert!
         tchamp-delete!
         tchamp-freeze
         tchamp-size*
         tchamp-lookup
         ;; Owner-ID transient (Phase 5: in-place mutation with ownership tracking)
         champ-transient-owned
         tchamp-insert-owned!
         tchamp-delete-owned!
         tchamp-insert-join-owned!
         tchamp-freeze-owned
         champ-all-persistent?)

(require racket/vector)

;; ========================================
;; Structs
;; ========================================

;; A CHAMP node: datamap and nodemap are 32-bit bitmasks.
;; content is a vector: data entries at front, child champ-nodes at back.
;; Data entries are 3-vectors: #(hash key value), storing the caller-provided
;; hash so sub-node promotion doesn't need to re-derive it.
;; edit: #f for persistent (shared) nodes; a gensym for owned (transient) nodes.
;; CHAMP Performance Phase 4: edit field enables owner-ID transient operations.
(struct champ-node (datamap nodemap content edit) #:transparent)

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

(define empty-node (champ-node 0 0 #() #f))

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
        (define ek (de-key entry))
        (if (or (eq? ek key) (equal? ek key))
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
      [(let ([ek (caar es)]) (or (eq? ek key) (equal? ek key))) (cdar es)]
      [else (loop (cdr es))])))

;; ========================================
;; Insert
;; ========================================

(define (champ-insert root hash key val)
  (define old-node (champ-root-node root))
  (define-values (new-node added?)
    (node-insert old-node hash key val 0))
  ;; CHAMP Performance Phase 3: if node unchanged (eq?), return same root.
  (if (eq? new-node old-node)
      root
      (champ-root new-node (+ (champ-root-size root) (if added? 1 0)))))

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
          [(or (eq? existing-key key) (equal? existing-key key))
           ;; CHAMP Performance Phase 3: value-only fast path.
           ;; If new value is eq? to existing, return same node — zero allocation.
           ;; Compounds with BSP-LE Track 0 Phase 2 (merge identity): the entire
           ;; chain merge→champ-insert→net-cell-write short-circuits on no-change.
           (define existing-val (de-val entry))
           (if (eq? val existing-val)
               (values node #f)  ;; same value — return identical node
               (let ([new-arr (vector-copy arr)])
                 (vector-set! new-arr idx (make-de hash key val))
                 (values (champ-node dm nm new-arr #f) #f)))]
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
           (values (champ-node new-dm new-nm new-arr #f) #t)])]
       ;; Child node exists at this position
       [(not (zero? (bitwise-and nm bit)))
        (define idx (node-index dm nm bit))
        (define child (vector-ref arr idx))
        (define-values (new-child added?) (node-insert child hash key val (+ level 1)))
        ;; Phase 3: if child unchanged, return same node — no vector copy needed
        (if (eq? new-child child)
            (values node #f)
            (let ([new-arr (vector-copy arr)])
              (vector-set! new-arr idx new-child)
              (values (champ-node dm nm new-arr #f) added?)))]
       ;; Empty: add data entry
       [else
        (define new-dm (bitwise-ior dm bit))
        (define idx (data-index new-dm bit))
        (define new-arr (vec-insert arr idx (make-de hash key val)))
        (values (champ-node new-dm nm new-arr #f) #t)])]))

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
        (champ-node 0 bit1 (vector child) #f)]
       [else
        ;; Different segments: two data entries
        (if (< seg1 seg2)
            (champ-node (bitwise-ior bit1 bit2) 0
                        (vector (make-de hash1 key1 val1) (make-de hash2 key2 val2)) #f)
            (champ-node (bitwise-ior bit1 bit2) 0
                        (vector (make-de hash2 key2 val2) (make-de hash1 key1 val1)) #f))])]))

(define (collision-insert coll hash key val)
  (define entries (champ-collision-entries coll))
  (let loop ([es entries] [acc '()])
    (cond
      [(null? es)
       ;; Key not found: add new entry
       (values (champ-collision hash (cons (cons key val) entries)) #t)]
      [(let ([ek (caar es)]) (or (eq? ek key) (equal? ek key)))
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
          [(or (eq? (de-key entry) key) (equal? (de-key entry) key))
           ;; Found: remove data entry
           (define new-dm (bitwise-and dm (bitwise-not bit)))
           (define new-arr (vec-remove arr idx))
           (if (and (zero? new-dm) (zero? nm))
               (values #f #t) ; node becomes empty
               (values (champ-node new-dm nm new-arr #f) #t))]
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
               (values (champ-node dm new-nm new-arr #f) #t))]
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
           (values (champ-node new-dm new-nm new-arr #f) #t)]
          [else
           ;; Child still has entries: update in place
           (define new-arr (vector-copy arr))
           (vector-set! new-arr idx new-child)
           (values (champ-node dm nm new-arr #f) #t)])]
       ;; Not found
       [else (values node #f)])]))

(define (collision-delete coll key)
  (define entries (champ-collision-entries coll))
  (define new-entries (filter (lambda (e) (let ([ek (car e)]) (not (or (eq? ek key) (equal? ek key))))) entries))
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

;; CHAMP Performance Phase 1: vector-copy! for array operations.
;; Replaces manual element-by-element loops with bulk copy (maps to memcpy
;; for homogeneous regions). Same semantics, better constant factor.

;; Insert val at index idx into vector, shifting later elements right
(define (vec-insert vec idx val)
  (define len (vector-length vec))
  (define new (make-vector (+ len 1)))
  (when (> idx 0)
    (vector-copy! new 0 vec 0 idx))         ;; copy prefix [0, idx)
  (vector-set! new idx val)
  (when (< idx len)
    (vector-copy! new (+ idx 1) vec idx))   ;; copy suffix [idx, len) → [idx+1, len+1)
  new)

;; Remove element at index idx from vector
(define (vec-remove vec idx)
  (define len (vector-length vec))
  (define new (make-vector (- len 1)))
  (when (> idx 0)
    (vector-copy! new 0 vec 0 idx))         ;; copy prefix [0, idx)
  (when (< (+ idx 1) len)
    (vector-copy! new idx vec (+ idx 1)))   ;; copy suffix [idx+1, len) → [idx, len-1)
  new)

;; Remove data entry at old-data-idx, then insert node at node-idx position.
;; Fused: single allocation instead of two (remove + insert were separate).
;; Used when converting a data entry to a sub-node during insert.
(define (vec-remove-insert-node arr old-data-idx _new-data-idx node-idx sub-node old-dm)
  ;; The result has the same length as arr (remove one data, add one node).
  ;; But positions shift: data entries at front, node entries at back.
  ;; node-idx was computed with the NEW bitmaps, accounting for the removed
  ;; data entry. We need to produce the correct layout in one pass.
  (define len (vector-length arr))
  ;; Step 1: remove data entry → intermediate of length len-1
  ;; Step 2: insert node at clamped-idx → final of length len
  ;; Fused: allocate final directly.
  (define clamped-idx
    (min node-idx (- len 1)))  ;; clamp to range of intermediate (len-1)
  (define new (make-vector len))
  ;; Copy prefix before removed data entry
  (when (> old-data-idx 0)
    (vector-copy! new 0 arr 0 old-data-idx))
  ;; Copy middle: between removed entry and insertion point
  ;; After removing old-data-idx, elements shift left. We need to figure out
  ;; which elements go where relative to the insertion point.
  ;; Simpler approach: build intermediate via vec-remove, then vec-insert.
  ;; The vectors are small (typically 4-16 elements), so the extra allocation
  ;; is negligible. The vector-copy! in vec-remove and vec-insert already
  ;; provides the speedup over manual loops.
  (define arr2 (vec-remove arr old-data-idx))
  (define final-idx (min clamped-idx (vector-length arr2)))
  ;; Copy from arr2 into new via insert pattern
  (when (> final-idx 0)
    (vector-copy! new 0 arr2 0 final-idx))
  (vector-set! new final-idx sub-node)
  (when (< final-idx (vector-length arr2))
    (vector-copy! new (+ final-idx 1) arr2 final-idx))
  new)

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
;; Owner-ID Transient (CHAMP Performance Phase 5)
;; ========================================
;;
;; In-place mutation with ownership tracking. Each node's `edit` field
;; is either #f (persistent/shared) or a gensym (owned by a specific
;; transient). Owned nodes are mutated in place; shared nodes are
;; path-copied and stamped with the current edit token.
;;
;; Key invariant: a persistent reference must never observe a mutation
;; made through a transient. This is guaranteed by:
;; 1. Edit tokens are gensyms — globally unique, never recycled.
;; 2. Persistent nodes have edit=#f, which never matches any gensym.
;; 3. Freeze clears edit on ALL owned nodes on ALL reachable paths.

;; Create an owned transient from a persistent map.
;; Returns: (values root-node edit-token size)
;; No conversion — the trie itself IS the transient. The root node's
;; edit is #f (persistent); first insert will path-copy it and stamp
;; with the edit token. Subsequent inserts to the same path mutate in place.
;;
;; CRITICAL: The returned root node must NOT be wrapped in champ-root
;; and exposed as a persistent value while the transient is active.
(define (champ-transient-owned root)
  (define edit (gensym 'champ-edit))
  (values (champ-root-node root) edit (champ-root-size root)))

;; Ensure a node is owned: if shared, path-copy and stamp with edit.
(define (ensure-owned node edit)
  (if (eq? (champ-node-edit node) edit)
      node  ;; already owned
      (champ-node (champ-node-datamap node)
                   (champ-node-nodemap node)
                   (vector-copy (champ-node-content node))
                   edit)))

;; Owner-ID transient insert.
;; size-box: (box nat) — updated when a new key is added.
;; Returns: (values node added?)
(define (tchamp-insert-owned! node size-box hash key val edit)
  (tnode-insert! node hash key val 0 edit size-box))

(define (tnode-insert! node hash key val level edit size-box)
  (cond
    [(champ-collision? node)
     ;; Collision nodes: fall back to persistent insert (rare path)
     (collision-insert node hash key val)]
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
        (define existing-key (de-key entry))
        (cond
          ;; Same key: update value
          [(or (eq? existing-key key) (equal? existing-key key))
           (define existing-val (de-val entry))
           (cond
             [(eq? val existing-val)
              ;; Same value — no mutation needed
              (values node #f)]
             [else
              ;; Different value — mutate in place if owned
              (define owned (ensure-owned node edit))
              (define oarr (champ-node-content owned))
              (vector-set! oarr idx (make-de hash key val))
              (values owned #f)])]
          ;; Different key: create sub-node
          [else
           (define existing-hash (de-hash entry))
           (define sub-node (merge-two existing-hash existing-key (de-val entry)
                                       hash key val (+ level 1)))
           ;; Remove data entry, add node entry
           (define new-dm (bitwise-and dm (bitwise-not bit)))
           (define new-nm (bitwise-ior nm bit))
           (define owned (ensure-owned node edit))
           (define oarr (champ-node-content owned))
           ;; Need to restructure: remove data at idx, insert node at new position
           ;; Since we're owned, we can rebuild the content vector in place
           (define new-arr (vec-remove-insert-node oarr idx
                                                    (data-index new-dm bit)
                                                    (node-index new-dm new-nm bit)
                                                    sub-node
                                                    dm))
           (set-box! size-box (add1 (unbox size-box)))
           (values (champ-node new-dm new-nm new-arr edit) #t)])]
       ;; Child node at this position
       [(not (zero? (bitwise-and nm bit)))
        (define idx (node-index dm nm bit))
        (define child (vector-ref arr idx))
        (define-values (new-child added?) (tnode-insert! child hash key val (+ level 1) edit size-box))
        (if (eq? new-child child)
            (values node #f)
            (let ([owned (ensure-owned node edit)])
              (vector-set! (champ-node-content owned) idx new-child)
              (values owned added?)))]
       ;; Empty: add data entry
       [else
        (define owned (ensure-owned node edit))
        (define new-dm (bitwise-ior dm bit))
        (define idx (data-index new-dm bit))
        (define new-arr (vec-insert (champ-node-content owned) idx (make-de hash key val)))
        (set-box! size-box (add1 (unbox size-box)))
        (values (champ-node new-dm nm new-arr edit) #t)])]))

;; Owner-ID transient delete.
;; size-box: (box nat) — updated when a key is removed.
;; Returns: (values node removed?)
(define (tchamp-delete-owned! node size-box hash key edit)
  (tnode-delete! node hash key 0 edit size-box))

(define (tnode-delete! node hash key level edit size-box)
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
       [(not (zero? (bitwise-and dm bit)))
        (define idx (data-index dm bit))
        (define entry (vector-ref arr idx))
        (cond
          [(or (eq? (de-key entry) key) (equal? (de-key entry) key))
           (define new-dm (bitwise-and dm (bitwise-not bit)))
           (if (and (zero? new-dm) (zero? nm))
               (begin (set-box! size-box (sub1 (unbox size-box)))
                      (values #f #t))
               (let* ([owned (ensure-owned node edit)]
                      [new-arr (vec-remove (champ-node-content owned) idx)])
                 (set-box! size-box (sub1 (unbox size-box)))
                 (values (champ-node new-dm nm new-arr edit) #t)))]
          [else (values node #f)])]
       [(not (zero? (bitwise-and nm bit)))
        (define idx (node-index dm nm bit))
        (define child (vector-ref arr idx))
        (define-values (new-child removed?) (tnode-delete! child hash key (+ level 1) edit size-box))
        (cond
          [(not removed?) (values node #f)]
          [(not new-child)
           (define new-nm (bitwise-and nm (bitwise-not bit)))
           (if (and (zero? dm) (zero? new-nm))
               (values #f #t)
               (let* ([owned (ensure-owned node edit)]
                      [new-arr (vec-remove (champ-node-content owned) idx)])
                 (values (champ-node dm new-nm new-arr edit) #t)))]
          [else
           (define owned (ensure-owned node edit))
           (vector-set! (champ-node-content owned) idx new-child)
           (values owned #t)])]
       [else (values node #f)])]))

;; Owner-ID transient insert-join (merge on collision).
;; join-fn: (old-val new-val → merged-val)
;; Returns: (values node added?)
(define (tchamp-insert-join-owned! node size-box hash key val join-fn edit)
  (tnode-insert-join! node hash key val join-fn 0 edit size-box))

(define (tnode-insert-join! node hash key val join-fn level edit size-box)
  (cond
    [(champ-collision? node)
     ;; Fall back to persistent for collision nodes (rare)
     (define entries (champ-collision-entries node))
     (let loop ([es entries] [acc '()])
       (cond
         [(null? es)
          (set-box! size-box (add1 (unbox size-box)))
          (values (champ-collision hash (cons (cons key val) entries)) #t)]
         [(let ([ek (caar es)]) (or (eq? ek key) (equal? ek key)))
          (values (champ-collision hash
                    (append (reverse acc) (cons (cons key (join-fn (cdar es) val)) (cdr es))))
                  #f)]
         [else (loop (cdr es) (cons (car es) acc))]))]
    [else
     (define seg (hash-segment hash level))
     (define bit (segment-bit seg))
     (define dm (champ-node-datamap node))
     (define nm (champ-node-nodemap node))
     (define arr (champ-node-content node))
     (cond
       [(not (zero? (bitwise-and dm bit)))
        (define idx (data-index dm bit))
        (define entry (vector-ref arr idx))
        (define existing-key (de-key entry))
        (cond
          [(or (eq? existing-key key) (equal? existing-key key))
           (define merged (join-fn (de-val entry) val))
           (define existing-val (de-val entry))
           (if (eq? merged existing-val)
               (values node #f)
               (let ([owned (ensure-owned node edit)])
                 (vector-set! (champ-node-content owned) idx (make-de hash key merged))
                 (values owned #f)))]
          [else
           ;; Different key at same position: promote to sub-node
           (define existing-hash (de-hash entry))
           (define sub-node (merge-two existing-hash existing-key (de-val entry)
                                       hash key val (+ level 1)))
           (define new-dm (bitwise-and dm (bitwise-not bit)))
           (define new-nm (bitwise-ior nm bit))
           (define new-arr (vec-remove-insert-node arr idx
                                                    (data-index new-dm bit)
                                                    (node-index new-dm new-nm bit)
                                                    sub-node dm))
           (set-box! size-box (add1 (unbox size-box)))
           (values (champ-node new-dm new-nm new-arr edit) #t)])]
       [(not (zero? (bitwise-and nm bit)))
        (define idx (node-index dm nm bit))
        (define child (vector-ref arr idx))
        (define-values (new-child added?)
          (tnode-insert-join! child hash key val join-fn (+ level 1) edit size-box))
        (if (eq? new-child child)
            (values node #f)
            (let ([owned (ensure-owned node edit)])
              (vector-set! (champ-node-content owned) idx new-child)
              (values owned added?)))]
       [else
        (define owned (ensure-owned node edit))
        (define new-dm (bitwise-ior dm bit))
        (define idx (data-index new-dm bit))
        (define new-arr (vec-insert (champ-node-content owned) idx (make-de hash key val)))
        (set-box! size-box (add1 (unbox size-box)))
        (values (champ-node new-dm nm new-arr edit) #t)])]))

;; ========================================
;; Owner-ID Freeze (CHAMP Performance Phase 6)
;; ========================================
;;
;; Walk the trie and clear edit on all owned nodes. O(modified nodes).
;; After freeze, all reachable nodes have edit=#f — the trie is fully persistent.

(define (tchamp-freeze-owned node size edit)
  (champ-root (freeze-node node edit) size))

(define (freeze-node node edit)
  (cond
    [(champ-collision? node) node]  ;; collision nodes have no edit field
    [(not (eq? (champ-node-edit node) edit))
     node]  ;; shared — already persistent, skip
    [else
     ;; Owned — clear edit, recurse into children
     (define arr (champ-node-content node))
     (define nm (champ-node-nodemap node))
     (define dm (champ-node-datamap node))
     (define new-arr
       (if (zero? nm)
           arr  ;; no children — just clear edit on this node
           (let ([copy (vector-copy arr)])
             (define data-count (popcount dm))
             (define total-count (vector-length arr))
             (for ([i (in-range data-count total-count)])
               (define child (vector-ref arr i))
               (when (and (champ-node? child)
                          (eq? (champ-node-edit child) edit))
                 (vector-set! copy i (freeze-node child edit))))
             copy)))
     (champ-node (champ-node-datamap node)
                  (champ-node-nodemap node)
                  new-arr
                  #f)]))  ;; clear edit → persistent

;; Invariant checker: verify all nodes in a champ-root have edit=#f.
;; Used by acceptance tests (§E) to verify freeze completeness.
(define (champ-all-persistent? root)
  (node-all-persistent? (champ-root-node root)))

(define (node-all-persistent? node)
  (cond
    [(champ-collision? node) #t]
    [(not (eq? (champ-node-edit node) #f)) #f]
    [else
     (define arr (champ-node-content node))
     (define dm (champ-node-datamap node))
     (define data-count (popcount dm))
     (for/and ([i (in-range data-count (vector-length arr))])
       (define child (vector-ref arr i))
       (if (champ-node? child)
           (node-all-persistent? child)
           #t))]))

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
