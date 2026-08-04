#lang racket/base

;;; test-ordered-map.rkt — the persistent ordered map backend (2026-08-04)
;;;
;;; DEFERRED.md § Collections: SortedMap / SortedSet were "blocked on backend
;;; infrastructure not yet built". This is that backend.
;;;
;;; Two properties are the whole point, and a naive test of neither would fail
;;; against a sorted assoc list — which is what makes them the load-bearing
;;; cases here:
;;;
;;;   BALANCE     — the reason to write a tree at all. Sorted insertion is the
;;;                 adversarial input for an unbalanced BST (it degenerates to a
;;;                 list, depth n). Asserted as a depth bound, not by eyeballing
;;;                 shape.
;;;   PERSISTENCE — the reason not to bridge Racket's `data/skip-list`, which is
;;;                 mutable. An old handle must be UNCHANGED by later writes.

(require rackunit
         racket/list
         "../ordered-map.rkt")

(define (om* . pairs) (om-from-list pairs <))

;; Actual tree depth, for the balance assertions.
(define (depth t)
  (if (om-empty? t)
      0
      (+ 1 (max (depth (om-node-left t)) (depth (om-node-right t))))))

;; ---- basics ---------------------------------------------------------------

(test-case "om: empty"
  (check-true (om-empty? om-empty))
  (check-equal? (om-count om-empty) 0)
  (check-equal? (om-to-list om-empty) '())
  (check-false (om-min om-empty))
  (check-false (om-ref om-empty < 1)))

(test-case "om: set / ref / has-key?"
  (define t (om* '(2 . "b") '(1 . "a") '(3 . "c")))
  (check-equal? (om-count t) 3)
  (check-equal? (om-ref t < 1) "a")
  (check-equal? (om-ref t < 2) "b")
  (check-equal? (om-ref t < 3) "c")
  (check-true (om-has-key? t < 2))
  (check-false (om-has-key? t < 9))
  (check-equal? (om-ref t < 9 'missing) 'missing))

(test-case "om: iteration is ASCENDING regardless of insert order"
  ;; the property an unordered map (champ) cannot give, which is why this
  ;; structure exists alongside it
  (define t (om-from-list '((5 . e) (1 . a) (4 . d) (2 . b) (3 . c)) <))
  (check-equal? (om-keys t) '(1 2 3 4 5))
  (check-equal? (om-values t) '(a b c d e)))

(test-case "om: overwrite is right-priority, and replaces the whole entry"
  (define t (om-set (om* '(1 . "first")) < 1 "second"))
  (check-equal? (om-ref t < 1) "second")
  (check-equal? (om-count t) 1 "overwrite must not grow the tree"))

(test-case "om: min / max"
  (define t (om-from-list '((5 . e) (1 . a) (3 . c)) <))
  (check-equal? (om-min t) '(1 . a))
  (check-equal? (om-max t) '(5 . e)))

;; ---- removal --------------------------------------------------------------

(test-case "om: remove — leaf, one child, two children, absent"
  (define t (om-from-list (for/list ([i (in-range 1 8)]) (cons i i)) <))
  (check-equal? (om-count t) 7)
  ;; absent key is a no-op, not an error
  (check-equal? (om-keys (om-remove t < 99)) '(1 2 3 4 5 6 7))
  ;; every key removable, and the rest survives in order
  (for ([k (in-range 1 8)])
    (define t* (om-remove t < k))
    (check-equal? (om-count t*) 6 (format "removing ~a" k))
    (check-equal? (om-keys t*) (remove k '(1 2 3 4 5 6 7)) (format "removing ~a" k))
    (check-false (om-has-key? t* < k) (format "removing ~a" k))))

(test-case "om: remove everything, in both orders, lands at empty"
  (define ks (range 1 21))
  (define t (om-from-list (map (lambda (k) (cons k k)) ks) <))
  (check-true (om-empty? (for/fold ([t t]) ([k (in-list ks)]) (om-remove t < k))))
  (check-true (om-empty? (for/fold ([t t]) ([k (in-list (reverse ks))]) (om-remove t < k)))))

;; ---- the two load-bearing properties ---------------------------------------

(test-case "om ⭐ BALANCE: sorted insertion does not degenerate to a list"
  ;; The adversarial input. An unbalanced BST built from ascending keys has
  ;; depth n; a weight-balanced tree stays O(log n). Without this assertion the
  ;; structure could be a linked list and every other test here would pass.
  (define n 1000)
  (define t (om-from-list (for/list ([i (in-range n)]) (cons i i)) <))
  (check-equal? (om-count t) n)
  ;; Adams' bound with DELTA=3 is comfortably under 3*log2(n); assert a bound
  ;; that a degenerate tree (depth 1000) cannot possibly meet.
  (define d (depth t))
  (check-true (< d 40) (format "depth ~a for n=~a — the tree is not balancing" d n))
  ;; and it is still correct, not merely shallow
  (check-equal? (om-keys t) (range n)))

(test-case "om ⭐ BALANCE: descending insertion too (the mirror case)"
  (define n 1000)
  (define t (om-from-list (for/list ([i (in-range n)]) (cons (- n i) i)) <))
  (define d (depth t))
  (check-true (< d 40) (format "depth ~a for n=~a on descending insert" d n))
  (check-equal? (om-keys t) (range 1 (add1 n))))

(test-case "om ⭐ BALANCE survives deletion (rebalance on the way out too)"
  ;; Removing half the keys in order is the shape that un-balances a tree whose
  ;; delete path forgets to rebalance — a bug insert-only tests cannot see.
  (define n 500)
  (define full (om-from-list (for/list ([i (in-range n)]) (cons i i)) <))
  (define half (for/fold ([t full]) ([i (in-range 0 n 2)]) (om-remove t < i)))
  (check-equal? (om-count half) (/ n 2))
  (define d (depth half))
  (check-true (< d 40) (format "depth ~a after deleting half" d))
  (check-equal? (om-keys half) (for/list ([i (in-range 1 n 2)]) i)))

(test-case "om ⭐ PERSISTENCE: an old handle is unchanged by later writes"
  ;; The reason this is hand-written instead of bridged to data/skip-list, which
  ;; is mutable. If this fails the structure has no advantage over copying.
  (define t0 (om* '(1 . "a") '(2 . "b")))
  (define t1 (om-set t0 < 3 "c"))
  (define t2 (om-remove t1 < 1))
  (check-equal? (om-keys t0) '(1 2) "t0 changed under an insert into its child")
  (check-equal? (om-keys t1) '(1 2 3) "t1 changed under a remove from its child")
  (check-equal? (om-keys t2) '(2 3))
  ;; values too, not just shape
  (check-equal? (om-ref t0 < 1) "a")
  (check-false (om-ref t2 < 1)))

(test-case "om: PERSISTENCE across a long chain of versions"
  ;; every intermediate version stays valid and distinct
  (define versions
    (for/fold ([acc (list om-empty)]) ([i (in-range 50)])
      (cons (om-set (car acc) < i i) acc)))
  (for ([v (in-list versions)] [i (in-naturals)])
    ;; versions are newest-first: the k-th from the front has 50-k entries
    (check-equal? (om-count v) (- 50 i) (format "version ~a" i))))

;; ---- ordering is the caller's ----------------------------------------------

(test-case "om: the order relation is supplied, not baked in"
  ;; Deliberate: how an `Ord` dictionary threads through at the Prologos level
  ;; is an owner API decision this backend does not pre-empt. Same keys, reverse
  ;; comparator, reversed iteration.
  (define pairs '((1 . a) (2 . b) (3 . c)))
  (check-equal? (om-keys (om-from-list pairs <)) '(1 2 3))
  (check-equal? (om-keys (om-from-list pairs >)) '(3 2 1)))

(test-case "om: string keys with string<? work as well as numbers"
  (define t (om-from-list '(("pear" . 2) ("apple" . 1) ("fig" . 3)) string<?))
  (check-equal? (om-keys t) '("apple" "fig" "pear"))
  (check-equal? (om-ref t string<? "fig") 3))

;; ---- fold ------------------------------------------------------------------

(test-case "om: fold visits in ascending key order"
  (define t (om-from-list '((3 . c) (1 . a) (2 . b)) <))
  (check-equal? (reverse (om-fold t (lambda (k _v acc) (cons k acc)) '()))
                '(1 2 3)))

;; ---- differential oracle ---------------------------------------------------

(test-case "om ⭐ differential: agrees with a sorted assoc list over random ops"
  ;; The tree's answers must match the obvious-but-slow model on a long mixed
  ;; run. This is what catches a rotation that loses or duplicates an entry —
  ;; the failure mode the balance tests cannot see, because a corrupted tree can
  ;; still be shallow.
  (define ops
    ;; deterministic pseudo-random: a fixed LCG, so a failure is reproducible
    (let loop ([x 12345] [n 0] [acc '()])
      (if (= n 600)
          (reverse acc)
          (let* ([x* (modulo (+ (* 1103515245 x) 12345) 2147483648)]
                 [k (modulo x* 50)]
                 [ins? (even? (quotient x* 50))])
            (loop x* (add1 n) (cons (cons ins? k) acc))))))
  (define-values (tree model)
    (for/fold ([t om-empty] [m '()]) ([op (in-list ops)])
      (define k (cdr op))
      (if (car op)
          (values (om-set t < k (* k 10))
                  (sort (cons (cons k (* k 10)) (filter (lambda (p) (not (= (car p) k))) m))
                        < #:key car))
          (values (om-remove t < k)
                  (filter (lambda (p) (not (= (car p) k))) m)))))
  (check-equal? (om-to-list tree) model)
  (check-equal? (om-count tree) (length model))
  (check-true (< (depth tree) 40) "stayed balanced across the mixed run"))
