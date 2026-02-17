#lang racket/base

;; ========================================
;; rrb.rkt — Persistent Vector Trie (RRB-Tree)
;; ========================================
;; A persistent indexed collection backed by a shift-based radix trie
;; with tail optimization. Branching factor 32 (5-bit shifts).
;;
;; Standard Clojure/Scala-style persistent vector:
;; - O(1) amortized push/pop via tail buffer
;; - O(log32 n) get/set via radix indexing
;; - O(n) concat/slice (naive rebuild; true RRB relaxed balancing deferred)
;;
;; This module is self-contained — no dependency on any Prologos module.

(require racket/vector)

(provide rrb-empty
         rrb-empty?
         rrb-size
         rrb-get
         rrb-set
         rrb-push
         rrb-pop
         rrb-concat
         rrb-slice
         rrb-fold
         rrb-to-list
         rrb-from-list
         rrb-equal?
         rrb-root?)

;; ========================================
;; Constants
;; ========================================

(define BITS 5)
(define WIDTH 32)          ; 2^5
(define MASK #b11111)      ; WIDTH - 1

;; ========================================
;; Node structures
;; ========================================

;; Internal trie node: vector of children (either rrb-node or rrb-leaf)
(struct rrb-node (children) #:transparent)

;; Leaf node: vector of values (up to WIDTH elements)
(struct rrb-leaf (values) #:transparent)

;; Root wrapper: cached metadata for O(1) access
;; - node: the trie root (rrb-node or rrb-leaf), or #f if count <= WIDTH
;; - count: total number of elements
;; - shift: tree depth * BITS (0 when everything fits in tail)
;; - tail: vector of the last <= WIDTH elements (tail optimization)
(struct rrb-root (node count shift tail) #:transparent)

;; ========================================
;; Empty vector
;; ========================================

(define rrb-empty (rrb-root #f 0 0 #()))

(define (rrb-empty? r)
  (zero? (rrb-root-count r)))

(define (rrb-size r)
  (rrb-root-count r))

;; ========================================
;; Internal helpers
;; ========================================

;; The offset where the tail begins
(define (tail-offset r)
  (let ([cnt (rrb-root-count r)])
    (if (< cnt WIDTH)
        0
        ;; Tail starts after the trie portion. The trie holds
        ;; (cnt - tail-length) elements, aligned to the last full WIDTH boundary.
        (bitwise-and (- cnt 1) (bitwise-not MASK)))))

;; Navigate the trie to find the leaf array containing idx.
;; Only called when idx < (tail-offset r), i.e., idx is in the trie (not tail).
(define (get-leaf-array node shift idx)
  (if (zero? shift)
      ;; We're at a leaf
      (rrb-leaf-values node)
      ;; Navigate to the appropriate child
      (let ([child-idx (bitwise-and (arithmetic-shift idx (- shift)) MASK)])
        (get-leaf-array (vector-ref (rrb-node-children node) child-idx)
                        (- shift BITS)
                        idx))))

;; ========================================
;; rrb-get — O(log32 n) indexed access
;; ========================================

(define (rrb-get r idx)
  (when (or (< idx 0) (>= idx (rrb-root-count r)))
    (error 'rrb-get "index ~a out of bounds for size ~a" idx (rrb-root-count r)))
  (let ([to (tail-offset r)])
    (if (>= idx to)
        ;; In the tail
        (vector-ref (rrb-root-tail r) (- idx to))
        ;; In the trie
        (let ([arr (get-leaf-array (rrb-root-node r) (rrb-root-shift r) idx)])
          (vector-ref arr (bitwise-and idx MASK))))))

;; ========================================
;; rrb-set — O(log32 n) persistent update
;; ========================================

(define (rrb-set r idx val)
  (when (or (< idx 0) (>= idx (rrb-root-count r)))
    (error 'rrb-set "index ~a out of bounds for size ~a" idx (rrb-root-count r)))
  (let ([to (tail-offset r)])
    (if (>= idx to)
        ;; Update in the tail
        (let ([new-tail (vector-copy (rrb-root-tail r))])
          (vector-set! new-tail (- idx to) val)
          (rrb-root (rrb-root-node r) (rrb-root-count r) (rrb-root-shift r) new-tail))
        ;; Update in the trie — path copy
        (rrb-root (set-in-trie (rrb-root-node r) (rrb-root-shift r) idx val)
                  (rrb-root-count r)
                  (rrb-root-shift r)
                  (rrb-root-tail r)))))

(define (set-in-trie node shift idx val)
  (if (zero? shift)
      ;; At leaf level
      (let ([new-arr (vector-copy (rrb-leaf-values node))])
        (vector-set! new-arr (bitwise-and idx MASK) val)
        (rrb-leaf new-arr))
      ;; At internal node
      (let* ([child-idx (bitwise-and (arithmetic-shift idx (- shift)) MASK)]
             [child (vector-ref (rrb-node-children node) child-idx)]
             [new-child (set-in-trie child (- shift BITS) idx val)]
             [new-children (vector-copy (rrb-node-children node))])
        (vector-set! new-children child-idx new-child)
        (rrb-node new-children))))

;; ========================================
;; rrb-push — O(1) amortized append
;; ========================================

(define (rrb-push r val)
  (let ([cnt (rrb-root-count r)]
        [tail (rrb-root-tail r)])
    (if (< (vector-length tail) WIDTH)
        ;; Room in the tail — just append
        (let ([new-tail (vector-append tail (vector val))])
          (rrb-root (rrb-root-node r) (+ cnt 1) (rrb-root-shift r) new-tail))
        ;; Tail is full — push it into the trie as a new leaf, start new tail
        (let* ([tail-node (rrb-leaf tail)]
               [shift (rrb-root-shift r)]
               [root-node (rrb-root-node r)])
          (cond
            ;; No trie yet — the current tail becomes the first leaf, wrapped in a node
            [(not root-node)
             (rrb-root (rrb-node (vector tail-node)) (+ cnt 1) BITS (vector val))]
            ;; Trie is full at current depth — grow a new root level
            [(> cnt (arithmetic-shift 1 (+ shift BITS)))
             (let ([new-root (rrb-node (vector root-node (new-path shift tail-node)))])
               (rrb-root new-root (+ cnt 1) (+ shift BITS) (vector val)))]
            ;; Room in trie — push tail-node down
            [else
             (let ([new-root (push-tail cnt shift root-node tail-node)])
               (rrb-root new-root (+ cnt 1) shift (vector val)))])))))

;; Create a path from the root level down to the given leaf node.
;; Each level has a single-child internal node.
(define (new-path shift leaf-node)
  (if (zero? shift)
      leaf-node
      (rrb-node (vector (new-path (- shift BITS) leaf-node)))))

;; Push a leaf node into the trie at the correct position.
;; cnt is the count BEFORE the push (used to compute the index).
(define (push-tail cnt shift parent leaf-node)
  (let ([child-idx (bitwise-and (arithmetic-shift (- cnt 1) (- shift)) MASK)])
    (if (= shift BITS)
        ;; One level above leaves — insert the leaf directly
        (if parent
            (let ([new-children (vector-append (rrb-node-children parent)
                                               (vector leaf-node))])
              (rrb-node new-children))
            (rrb-node (vector leaf-node)))
        ;; Higher level — recurse into the correct child
        (if parent
            (let* ([children (rrb-node-children parent)]
                   [n (vector-length children)])
              (if (> n child-idx)
                  ;; Child exists — recurse
                  (let* ([existing-child (vector-ref children child-idx)]
                         [updated-child (push-tail cnt (- shift BITS) existing-child leaf-node)]
                         [new-children (vector-copy children)])
                    (vector-set! new-children child-idx updated-child)
                    (rrb-node new-children))
                  ;; Need new child path
                  (let ([new-children (vector-append children
                                                     (vector (new-path (- shift BITS) leaf-node)))])
                    (rrb-node new-children))))
            ;; No parent — create path
            (rrb-node (vector (new-path (- shift BITS) leaf-node)))))))

;; ========================================
;; rrb-pop — O(1) amortized remove last
;; ========================================

(define (rrb-pop r)
  (let ([cnt (rrb-root-count r)])
    (when (zero? cnt)
      (error 'rrb-pop "cannot pop from empty vector"))
    (cond
      ;; Single element — return empty
      [(= cnt 1) rrb-empty]
      ;; More than one element in tail — just shrink it
      [(> (vector-length (rrb-root-tail r)) 1)
       (let ([new-tail (vector-copy (rrb-root-tail r)
                                    0
                                    (- (vector-length (rrb-root-tail r)) 1))])
         (rrb-root (rrb-root-node r) (- cnt 1) (rrb-root-shift r) new-tail))]
      ;; Tail has exactly 1 element — need to pop the rightmost leaf from trie as new tail
      [else
       (let ([new-tail (pop-tail-from-trie r)])
         (let* ([new-root (remove-rightmost-leaf (rrb-root-node r) (rrb-root-shift r))]
                [shift (rrb-root-shift r)])
           ;; If root node has only one child after removal and shift > BITS, lower the root
           (cond
             [(not new-root)
              ;; Trie is now empty — everything in new tail
              (rrb-root #f (- cnt 1) 0 new-tail)]
             [(and (> shift BITS)
                   (rrb-node? new-root)
                   (= (vector-length (rrb-node-children new-root)) 1))
              ;; Lower the root level
              (rrb-root (vector-ref (rrb-node-children new-root) 0)
                        (- cnt 1) (- shift BITS) new-tail)]
             [else
              (rrb-root new-root (- cnt 1) shift new-tail)])))])))

;; Get the rightmost leaf array from the trie (will become the new tail)
(define (pop-tail-from-trie r)
  (let ([idx (- (rrb-root-count r) 2)])  ; index of the last element in the trie
    (if (< idx (tail-offset r))
        ;; The element is in the trie
        (get-leaf-array (rrb-root-node r) (rrb-root-shift r)
                        ;; Get the leaf array that contains the last trie element
                        (bitwise-and idx (bitwise-not MASK)))
        ;; Edge case: if tail-offset equals count-1, the last trie leaf is at tail-offset - 1
        ;; Actually this shouldn't happen when tail-len = 1 and count > 1
        ;; Just get the rightmost leaf from the trie
        (rightmost-leaf-values (rrb-root-node r) (rrb-root-shift r)))))

(define (rightmost-leaf-values node shift)
  (if (zero? shift)
      (rrb-leaf-values node)
      (let* ([children (rrb-node-children node)]
             [last-child (vector-ref children (- (vector-length children) 1))])
        (rightmost-leaf-values last-child (- shift BITS)))))

;; Remove the rightmost leaf from the trie, returning a new trie node (or #f if empty)
(define (remove-rightmost-leaf node shift)
  (if (= shift BITS)
      ;; One level above leaves — remove the last child
      (let ([children (rrb-node-children node)])
        (if (= (vector-length children) 1)
            #f  ; this node is now empty
            (rrb-node (vector-copy children 0 (- (vector-length children) 1)))))
      ;; Higher level — recurse into rightmost child
      (let* ([children (rrb-node-children node)]
             [last-idx (- (vector-length children) 1)]
             [updated (remove-rightmost-leaf (vector-ref children last-idx) (- shift BITS))])
        (if updated
            ;; Child still exists after removal
            (let ([new-children (vector-copy children)])
              (vector-set! new-children last-idx updated)
              (rrb-node new-children))
            ;; Child was removed entirely
            (if (zero? last-idx)
                #f
                (rrb-node (vector-copy children 0 last-idx)))))))

;; ========================================
;; rrb-concat — O(n) naive rebuild
;; ========================================

(define (rrb-concat r1 r2)
  (rrb-fold r2 (lambda (val acc) (rrb-push acc val)) r1))

;; ========================================
;; rrb-slice — O(n) naive rebuild
;; ========================================

;; Returns elements from index lo (inclusive) to hi (exclusive)
(define (rrb-slice r lo hi)
  (let ([cnt (rrb-root-count r)])
    (let ([lo* (max 0 lo)]
          [hi* (min cnt hi)])
      (if (>= lo* hi*)
          rrb-empty
          (let loop ([i lo*] [acc rrb-empty])
            (if (>= i hi*)
                acc
                (loop (+ i 1) (rrb-push acc (rrb-get r i)))))))))

;; ========================================
;; rrb-fold — left fold in index order
;; ========================================

(define (rrb-fold r f init)
  (let ([cnt (rrb-root-count r)])
    (if (zero? cnt)
        init
        (let ([to (tail-offset r)])
          ;; Fold over trie portion
          (define acc1
            (if (and (rrb-root-node r) (> to 0))
                (fold-node (rrb-root-node r) (rrb-root-shift r) f init)
                init))
          ;; Fold over tail
          (let loop ([i 0] [acc acc1])
            (if (>= i (vector-length (rrb-root-tail r)))
                acc
                (loop (+ i 1) (f (vector-ref (rrb-root-tail r) i) acc))))))))

(define (fold-node node shift f acc)
  (if (zero? shift)
      ;; Leaf node
      (let ([vals (rrb-leaf-values node)])
        (let loop ([i 0] [a acc])
          (if (>= i (vector-length vals))
              a
              (loop (+ i 1) (f (vector-ref vals i) a)))))
      ;; Internal node
      (let ([children (rrb-node-children node)])
        (let loop ([i 0] [a acc])
          (if (>= i (vector-length children))
              a
              (loop (+ i 1) (fold-node (vector-ref children i) (- shift BITS) f a)))))))

;; ========================================
;; rrb-to-list / rrb-from-list
;; ========================================

(define (rrb-to-list r)
  (reverse (rrb-fold r (lambda (v acc) (cons v acc)) '())))

(define (rrb-from-list lst)
  (let loop ([l lst] [acc rrb-empty])
    (if (null? l)
        acc
        (loop (cdr l) (rrb-push acc (car l))))))

;; ========================================
;; rrb-equal? — element-wise comparison
;; ========================================

(define (rrb-equal? r1 r2 [elem-equal? equal?])
  (let ([cnt1 (rrb-root-count r1)]
        [cnt2 (rrb-root-count r2)])
    (if (not (= cnt1 cnt2))
        #f
        (let loop ([i 0])
          (if (>= i cnt1)
              #t
              (if (elem-equal? (rrb-get r1 i) (rrb-get r2 i))
                  (loop (+ i 1))
                  #f))))))

;; ========================================
;; Tests
;; ========================================

(module+ test
  (require rackunit)

  (test-case "empty vector"
    (check-true (rrb-empty? rrb-empty))
    (check-equal? (rrb-size rrb-empty) 0))

  (test-case "push and get single element"
    (let ([v (rrb-push rrb-empty 42)])
      (check-false (rrb-empty? v))
      (check-equal? (rrb-size v) 1)
      (check-equal? (rrb-get v 0) 42)))

  (test-case "push multiple elements"
    (let ([v (rrb-from-list '(10 20 30 40 50))])
      (check-equal? (rrb-size v) 5)
      (check-equal? (rrb-get v 0) 10)
      (check-equal? (rrb-get v 2) 30)
      (check-equal? (rrb-get v 4) 50)))

  (test-case "persistent update"
    (let* ([v1 (rrb-from-list '(1 2 3))]
           [v2 (rrb-set v1 1 99)])
      (check-equal? (rrb-get v1 1) 2)    ;; original unchanged
      (check-equal? (rrb-get v2 1) 99)   ;; new version updated
      (check-equal? (rrb-size v2) 3)))

  (test-case "pop"
    (let* ([v1 (rrb-from-list '(1 2 3))]
           [v2 (rrb-pop v1)])
      (check-equal? (rrb-size v2) 2)
      (check-equal? (rrb-get v2 0) 1)
      (check-equal? (rrb-get v2 1) 2)
      ;; Original unchanged
      (check-equal? (rrb-size v1) 3)
      (check-equal? (rrb-get v1 2) 3)))

  (test-case "pop to empty"
    (let* ([v1 (rrb-push rrb-empty 42)]
           [v2 (rrb-pop v1)])
      (check-true (rrb-empty? v2))
      (check-exn exn:fail? (lambda () (rrb-pop rrb-empty)))))

  (test-case "concat"
    (let* ([v1 (rrb-from-list '(1 2 3))]
           [v2 (rrb-from-list '(4 5 6))]
           [v3 (rrb-concat v1 v2)])
      (check-equal? (rrb-size v3) 6)
      (check-equal? (rrb-to-list v3) '(1 2 3 4 5 6))))

  (test-case "slice"
    (let* ([v (rrb-from-list '(0 1 2 3 4 5 6 7 8 9))]
           [s (rrb-slice v 3 7)])
      (check-equal? (rrb-size s) 4)
      (check-equal? (rrb-to-list s) '(3 4 5 6))))

  (test-case "fold"
    (let ([v (rrb-from-list '(1 2 3 4 5))])
      (check-equal? (rrb-fold v + 0) 15)
      (check-equal? (rrb-fold v cons '()) '(5 4 3 2 1))))

  (test-case "to-list and from-list round-trip"
    (let* ([lst '(a b c d e)]
           [v (rrb-from-list lst)])
      (check-equal? (rrb-to-list v) lst)))

  (test-case "equal?"
    (let ([v1 (rrb-from-list '(1 2 3))]
          [v2 (rrb-from-list '(1 2 3))]
          [v3 (rrb-from-list '(1 2 4))])
      (check-true (rrb-equal? v1 v2))
      (check-false (rrb-equal? v1 v3))
      (check-false (rrb-equal? v1 rrb-empty))))

  (test-case "out-of-bounds errors"
    (let ([v (rrb-from-list '(1 2 3))])
      (check-exn exn:fail? (lambda () (rrb-get v -1)))
      (check-exn exn:fail? (lambda () (rrb-get v 3)))
      (check-exn exn:fail? (lambda () (rrb-set v 5 99)))))

  (test-case "stress: 100 elements"
    (let ([v (rrb-from-list (for/list ([i 100]) i))])
      (check-equal? (rrb-size v) 100)
      (for ([i 100])
        (check-equal? (rrb-get v i) i))
      ;; Update middle element
      (let ([v2 (rrb-set v 50 999)])
        (check-equal? (rrb-get v2 50) 999)
        (check-equal? (rrb-get v 50) 50))))

  (test-case "stress: 1000 elements with push/pop"
    (let ([v (rrb-from-list (for/list ([i 1000]) i))])
      (check-equal? (rrb-size v) 1000)
      (check-equal? (rrb-get v 0) 0)
      (check-equal? (rrb-get v 999) 999)
      ;; Pop 500 elements
      (let loop ([v v] [n 500])
        (if (zero? n) (check-equal? (rrb-size v) 500)
            (loop (rrb-pop v) (- n 1))))))

  (test-case "stress: 2000 elements across trie levels"
    ;; 2000 elements requires multiple trie levels (32^1 = 32, 32^2 = 1024)
    (let ([v (rrb-from-list (for/list ([i 2000]) (* i 10)))])
      (check-equal? (rrb-size v) 2000)
      (check-equal? (rrb-get v 0) 0)
      (check-equal? (rrb-get v 1999) 19990)
      (check-equal? (rrb-get v 1000) 10000)))
)
