#lang racket/base

;;;
;;; union-find.rkt — Persistent Union-Find (Disjoint Sets)
;;;
;;; A persistent union-find data structure following Conchon & Filliâtre 2007.
;;; Uses path splitting (not path compression) to maintain persistence.
;;; All operations are pure: they take a store and return a new store.
;;; The old store is never modified (structural sharing via hasheq).
;;;
;;; This is Racket-level infrastructure with no dependency on Prologos
;;; syntax or type system. Node values are opaque Racket values.
;;;
;;; Design reference: docs/tracking/2026-02-24_LOGIC_ENGINE_DESIGN.org §4
;;;

(provide
 ;; Core structs
 (struct-out uf-store)
 (struct-out uf-node)
 ;; Construction
 uf-empty
 uf-make-set
 ;; Query
 uf-find
 uf-value
 uf-has-id?
 uf-size
 uf-same-set?
 ;; Mutation (returns new store)
 uf-union)

;; ========================================
;; Core structs
;; ========================================

;; A persistent store: maps id (exact non-negative integer) → uf-node
(struct uf-store (nodes) #:transparent)

;; A node in the union-find forest
;; parent: id of parent (self = root)
;; rank: natural number for union-by-rank
;; value: optional payload (for unification: the term)
(struct uf-node (parent rank value) #:transparent)

;; ========================================
;; Construction
;; ========================================

;; Create empty union-find store
(define (uf-empty)
  (uf-store (hasheq)))

;; Add a new singleton set with the given id and value.
;; parent=self, rank=0.
;; If id already exists, overwrites it (caller should check uf-has-id? first).
(define (uf-make-set store id value)
  (uf-store
   (hash-set (uf-store-nodes store) id
             (uf-node id 0 value))))

;; ========================================
;; Query: find
;; ========================================

;; Find the root of id's set, with path splitting.
;; Path splitting: each node on the find path has its parent set to
;; its grandparent. This provides O(log n) amortized complexity while
;; preserving persistence (each split creates a new store version).
;;
;; Returns (values root-id updated-store).
;; The updated store has path-split nodes for future faster lookups.
;; If id not found, raises an error.
(define (uf-find store id)
  (define nodes (uf-store-nodes store))
  (unless (hash-has-key? nodes id)
    (error 'uf-find "id ~a not found in union-find store" id))
  ;; Iterative path splitting
  (let loop ([current id] [nodes nodes])
    (define node (hash-ref nodes current))
    (define parent (uf-node-parent node))
    (cond
      ;; Root: parent is self
      [(= parent current)
       (values current (uf-store nodes))]
      ;; One step from root: just return root
      [else
       (define parent-node (hash-ref nodes parent))
       (define grandparent (uf-node-parent parent-node))
       (cond
         [(= grandparent parent)
          ;; Parent is root — done
          (values parent (uf-store nodes))]
         [else
          ;; Path split: point current to grandparent
          (define updated-node (uf-node grandparent (uf-node-rank node) (uf-node-value node)))
          (define nodes* (hash-set nodes current updated-node))
          (loop grandparent nodes*)])])))

;; ========================================
;; Query: value
;; ========================================

;; Get the value stored at id's root.
;; Returns (values value updated-store).
;; Path splitting is performed during the find.
(define (uf-value store id)
  (define-values (root store*) (uf-find store id))
  (define node (hash-ref (uf-store-nodes store*) root))
  (values (uf-node-value node) store*))

;; ========================================
;; Query: membership and size
;; ========================================

;; Check if id exists in the store
(define (uf-has-id? store id)
  (hash-has-key? (uf-store-nodes store) id))

;; Number of elements in the store
(define (uf-size store)
  (hash-count (uf-store-nodes store)))

;; Check if two ids are in the same set
;; Returns (values same? updated-store)
(define (uf-same-set? store id1 id2)
  (define-values (root1 store1) (uf-find store id1))
  (define-values (root2 store2) (uf-find store1 id2))
  (values (= root1 root2) store2))

;; ========================================
;; Mutation: union
;; ========================================

;; Union the sets containing id1 and id2.
;; Uses union-by-rank: the shallower tree is attached under the deeper root.
;; If merge-fn is provided, it combines the values of the two roots:
;;   (merge-fn root-value1 root-value2) → merged-value
;; If merge-fn is #f (default), the surviving root keeps its original value.
;;
;; Returns updated store.
;; If id1 and id2 are already in the same set, returns store unchanged
;; (after path splitting from the finds).
(define (uf-union store id1 id2 [merge-fn #f])
  (define-values (root1 store1) (uf-find store id1))
  (define-values (root2 store2) (uf-find store1 id2))
  (cond
    [(= root1 root2) store2]  ;; Already in same set
    [else
     (define nodes (uf-store-nodes store2))
     (define node1 (hash-ref nodes root1))
     (define node2 (hash-ref nodes root2))
     (define rank1 (uf-node-rank node1))
     (define rank2 (uf-node-rank node2))
     ;; Compute merged value if merge-fn provided
     (define merged-val
       (if merge-fn
           (merge-fn (uf-node-value node1) (uf-node-value node2))
           #f))  ;; sentinel; we'll pick the surviving root's value below
     (cond
       ;; root1 has lower rank: attach root1 under root2
       [(< rank1 rank2)
        (define val2 (if merge-fn merged-val (uf-node-value node2)))
        (define nodes*
          (hash-set (hash-set nodes root1 (uf-node root2 rank1 (uf-node-value node1)))
                    root2 (uf-node root2 rank2 val2)))
        (uf-store nodes*)]
       ;; root2 has lower rank: attach root2 under root1
       [(> rank1 rank2)
        (define val1 (if merge-fn merged-val (uf-node-value node1)))
        (define nodes*
          (hash-set (hash-set nodes root2 (uf-node root1 rank2 (uf-node-value node2)))
                    root1 (uf-node root1 rank1 val1)))
        (uf-store nodes*)]
       ;; Equal ranks: attach root2 under root1, increment root1's rank
       [else
        (define val1 (if merge-fn merged-val (uf-node-value node1)))
        (define nodes*
          (hash-set (hash-set nodes root2 (uf-node root1 rank2 (uf-node-value node2)))
                    root1 (uf-node root1 (+ rank1 1) val1)))
        (uf-store nodes*)])]))
