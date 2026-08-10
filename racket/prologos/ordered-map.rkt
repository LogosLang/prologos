#lang racket/base

;;; ordered-map.rkt — a PERSISTENT ordered map (weight-balanced tree).
;;;
;;; The backend DEFERRED.md § Collections names as missing for SortedMap /
;;; SortedSet. Written rather than bridged, deliberately:
;;;
;;;   Racket ships ordered dictionaries — `data/skip-list`, `data/splay-tree` —
;;;   and both are MUTABLE. Prologos collections are persistent, so a functional
;;;   `sorted-assoc` over a mutable backend has to copy per operation: O(n) per
;;;   insert, worse than the sorted assoc list it would replace. The
;;;   distribution has no persistent ordered dictionary, and this tree's own
;;;   persistent structures (champ.rkt, rrb.rkt) are UNORDERED. So the bridge
;;;   shortcut that closed Numerics Phase 4 and String 4a-4d does not apply
;;;   here, and this is the same class of hand-written work as CHAMP and RRB.
;;;
;;; Weight-balanced (Adams / Nievergelt-Reingold) rather than red-black: the
;;; balance invariant is a SIZE ratio, so every node already carries the subtree
;;; count that `om-count` and rank/select need, and rebalancing is two rotations
;;; expressed over that same field. A red-black tree would need a separate size
;;; field for the same queries and gives nothing back here.
;;;
;;; Ordering is by a caller-supplied `<?` on keys. It is NOT baked in, because
;;; the Prologos-level question — how an `Ord` dictionary threads through, and
;;; whether SortedMap joins the `Seq` protocol — is an owner API decision this
;;; module deliberately does not pre-empt. This is the backend only.
;;;
;;; DELTA and RATIO are the standard Adams constants. DELTA bounds how lopsided
;;; a node may be before rebalancing; RATIO decides single vs double rotation.
;;; (3, 2) is the pair Adams proves keeps the tree within O(log n) — do not
;;; tune them casually; the proof, not taste, is what picks them.

(require racket/match)

(provide om-empty
         om-empty?
         om-count
         om-set
         om-ref
         om-has-key?
         om-remove
         om-to-list
         om-keys
         om-values
         om-min
         om-max
         om-fold
         om-from-list
         (struct-out om-node))

;; A node carries its own subtree SIZE — the balance invariant is a size ratio,
;; so this is load-bearing, not a cached convenience.
(struct om-node (key val size left right) #:transparent)

;; The empty map is #f, not a sentinel struct: it makes the leaf test a cheap
;; `not` and keeps `om-node?` an exact "is this an interior node" predicate.
(define om-empty #f)
(define (om-empty? t) (not t))

(define (om-count t) (if t (om-node-size t) 0))

(define DELTA 3)
(define RATIO 2)

(define (mk k v l r)
  (om-node k v (+ 1 (om-count l) (om-count r)) l r))

;; ---- rotations -------------------------------------------------------------

(define (single-l k v l r)
  (mk (om-node-key r) (om-node-val r)
      (mk k v l (om-node-left r))
      (om-node-right r)))

(define (single-r k v l r)
  (mk (om-node-key l) (om-node-val l)
      (om-node-left l)
      (mk k v (om-node-right l) r)))

(define (double-l k v l r)
  (define rl (om-node-left r))
  (mk (om-node-key rl) (om-node-val rl)
      (mk k v l (om-node-left rl))
      (mk (om-node-key r) (om-node-val r) (om-node-right rl) (om-node-right r))))

(define (double-r k v l r)
  (define lr (om-node-right l))
  (mk (om-node-key lr) (om-node-val lr)
      (mk (om-node-key l) (om-node-val l) (om-node-left l) (om-node-left lr))
      (mk k v (om-node-right lr) r)))

;; Rebuild a node whose subtrees are each balanced but which may itself be one
;; insert/delete out of balance. The only shape this handles.
(define (balance k v l r)
  (define ln (om-count l))
  (define rn (om-count r))
  (cond
    [(<= (+ ln rn) 1) (mk k v l r)]
    [(> rn (* DELTA ln))
     (if (< (om-count (om-node-left r)) (* RATIO (om-count (om-node-right r))))
         (single-l k v l r)
         (double-l k v l r))]
    [(> ln (* DELTA rn))
     (if (< (om-count (om-node-right l)) (* RATIO (om-count (om-node-left l))))
         (single-r k v l r)
         (double-r k v l r))]
    [else (mk k v l r)]))

;; ---- core operations -------------------------------------------------------

;; Insert or overwrite. Right-priority on an existing key, matching `map-assoc`.
(define (om-set t <? k v)
  (cond
    [(not t) (mk k v #f #f)]
    [(<? k (om-node-key t))
     (balance (om-node-key t) (om-node-val t)
              (om-set (om-node-left t) <? k v) (om-node-right t))]
    [(<? (om-node-key t) k)
     (balance (om-node-key t) (om-node-val t)
              (om-node-left t) (om-set (om-node-right t) <? k v))]
    ;; neither less — equal under this order, so overwrite in place. The KEY is
    ;; replaced too, not just the value: two keys equal under `<?` need not be
    ;; `equal?`, and last-write-wins has to mean the whole entry or lookups can
    ;; return a key the caller never inserted.
    [else (om-node k v (om-node-size t) (om-node-left t) (om-node-right t))]))

(define (om-ref t <? k [default #f])
  (let loop ([t t])
    (cond
      [(not t) default]
      [(<? k (om-node-key t)) (loop (om-node-left t))]
      [(<? (om-node-key t) k) (loop (om-node-right t))]
      [else (om-node-val t)])))

(define (om-has-key? t <? k)
  (let loop ([t t])
    (cond
      [(not t) #f]
      [(<? k (om-node-key t)) (loop (om-node-left t))]
      [(<? (om-node-key t) k) (loop (om-node-right t))]
      [else #t])))

(define (om-min t)
  (and t (let loop ([t t])
           (if (om-node-left t) (loop (om-node-left t))
               (cons (om-node-key t) (om-node-val t))))))

(define (om-max t)
  (and t (let loop ([t t])
           (if (om-node-right t) (loop (om-node-right t))
               (cons (om-node-key t) (om-node-val t))))))

;; Delete the minimum, returning (values min-pair rest). Used by om-remove for
;; the two-child case.
(define (delete-min t)
  (cond
    [(not (om-node-left t)) (values (cons (om-node-key t) (om-node-val t))
                                    (om-node-right t))]
    [else
     (define-values (m rest) (delete-min (om-node-left t)))
     (values m (balance (om-node-key t) (om-node-val t) rest (om-node-right t)))]))

(define (om-remove t <? k)
  (cond
    [(not t) #f]
    [(<? k (om-node-key t))
     (balance (om-node-key t) (om-node-val t)
              (om-remove (om-node-left t) <? k) (om-node-right t))]
    [(<? (om-node-key t) k)
     (balance (om-node-key t) (om-node-val t)
              (om-node-left t) (om-remove (om-node-right t) <? k))]
    [else
     (define l (om-node-left t))
     (define r (om-node-right t))
     (cond
       [(not l) r]
       [(not r) l]
       [else
        ;; Standard two-child delete: lift the successor. `balance` is enough
        ;; because removing one element can only put this node one step out.
        (define-values (succ rest) (delete-min r))
        (balance (car succ) (cdr succ) l rest)])]))

;; ---- traversal -------------------------------------------------------------

;; In-order fold: f is (key val acc -> acc), applied smallest key first.
(define (om-fold t f acc)
  (let loop ([t t] [acc acc])
    (if (not t)
        acc
        (loop (om-node-right t)
              (f (om-node-key t) (om-node-val t)
                 (loop (om-node-left t) acc))))))

;; Ascending association list.
(define (om-to-list t)
  (reverse (om-fold t (lambda (k v acc) (cons (cons k v) acc)) '())))

(define (om-keys t) (map car (om-to-list t)))
(define (om-values t) (map cdr (om-to-list t)))

(define (om-from-list pairs <?)
  (for/fold ([t om-empty]) ([p (in-list pairs)])
    (om-set t <? (car p) (cdr p))))
