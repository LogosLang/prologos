#lang racket/base
;;;
;;; test-champ-diff.rkt
;;; Unit tests for champ-diff (the eq?-pruned CHAMP structural diff).
;;;
;;; Standalone scheduler O(network-diff) optimization, sub-phase S-a
;;; (docs/tracking/2026-06-03_SCHEDULER_ODIFF_OPTIMIZATION.md §7).
;;;
;;; The spine is a PERMANENT differential oracle (S.2 (i)): a ~12-line naive
;;; full-scan model (mirroring the old fire-and-collect-writes folds — champ-
;;; fold/hash + champ-lookup) that champ-diff must match on randomized inputs.
;;; Plus targeted edge cases the grounding-audit flagged as uncovered:
;;; forced collision nodes, namespaced high-bit keys (the adversarial D-S.1
;;; finding: ids agreeing on the low 35 hash bits collide), dependents-only
;;; changes (caller-supplied same?), the no-change eq? fast path, and a
;;; deep/wide O(changed) sanity check.

(require rackunit
         racket/set
         (only-in "../champ.rkt"
                  champ-empty champ-insert champ-lookup champ-diff
                  champ-fold/hash champ-size))

;; ---- The naive oracle: fold result, classify each key by lookup in snap.
;; This is exactly the shape of the production folds champ-diff replaces.
(define (naive-diff snap result same?)
  (define res
    (champ-fold/hash result
      (lambda (h k v acc)
        (define sv (champ-lookup snap h k))
        (define changed (car acc))
        (define new (cdr acc))
        (cond
          [(eq? sv 'none) (cons changed (cons (cons k v) new))]
          [(or (eq? sv v) (same? sv v)) acc]
          [else (cons (cons (cons k v) changed) new)]))
      (cons '() '())))
  (values (car res) (cdr res)))

;; Compare a diff fn's output as (changed-set . new-set) — order-independent.
(define (as-sets f snap result same?)
  (define-values (c n) (f snap result same?))
  (cons (list->set c) (list->set n)))

(define (check-diff= snap result same? [msg ""])
  (check-equal? (as-sets champ-diff snap result same?)
                (as-sets naive-diff snap result same?)
                msg))

(define (build hkvs)
  (for/fold ([m champ-empty]) ([t (in-list hkvs)])
    (champ-insert m (car t) (cadr t) (caddr t))))

;; ============================================================
;; 1. Differential oracle — randomized monotone-growth pairs
;; ============================================================
;; hash = (modulo key hashmod): small hashmod forces many collision nodes;
;; large hashmod exercises the ordinary trie. result = snap + M inserts.

(random-seed 8675309)  ;; reproducible

(define (rand-trial K M hashmod keymax)
  (define (rand-entry)
    (define key (random keymax))
    (list (modulo key hashmod) key (random 1000)))
  (define snap (build (for/list ([_ (in-range K)]) (rand-entry))))
  (define result
    (for/fold ([m snap]) ([_ (in-range M)])
      (define e (rand-entry))
      (champ-insert m (car e) (cadr e) (caddr e))))
  (check-diff= snap result equal?
               (format "rand K=~a M=~a hashmod=~a keymax=~a" K M hashmod keymax)))

(test-case "differential oracle — ordinary trie (hash=key, no forced collisions)"
  (for ([_ (in-range 150)])
    (rand-trial (random 60) (random 20) 1000000 1000000)))

(test-case "differential oracle — heavy collisions (hashmod 4, keys 0..200)"
  (for ([_ (in-range 150)])
    (rand-trial (random 80) (random 25) 4 200)))

(test-case "differential oracle — mixed (hashmod 64, keys 0..500)"
  (for ([_ (in-range 150)])
    (rand-trial (random 120) (random 40) 64 500)))

;; ============================================================
;; 2. No-change — result eq? snap → empty diff (the fast path)
;; ============================================================

(test-case "no-change: diff of a map against itself is empty"
  (define m (build '((1 a 10) (2 b 20) (3 c 30))))
  (define-values (c n) (champ-diff m m equal?))
  (check-equal? c '())
  (check-equal? n '()))

(test-case "no-change: re-inserting an eq? value yields the same root → empty"
  (define v (box 'shared))
  (define m (build (list (list 1 'a v))))
  (define m2 (champ-insert m 1 'a v))  ;; same eq? value → champ-insert returns same root
  (check-eq? m m2)
  (define-values (c n) (champ-diff m m2 equal?))
  (check-equal? c '())
  (check-equal? n '()))

;; ============================================================
;; 3. Forced collision nodes (two distinct keys, identical hash)
;; ============================================================

(test-case "collision node: new key in a collision is reported as new"
  (define snap (build '((7 k1 v1) (7 k2 v2))))   ;; same hash 7 → collision node
  (define result (champ-insert snap 7 'k3 'v3))
  (check-diff= snap result equal? "add k3 to collision")
  (define-values (c n) (champ-diff snap result equal?))
  (check-equal? c '())
  (check-equal? (list->set n) (set (cons 'k3 'v3))))

(test-case "collision node: changed value in a collision is reported as changed"
  (define snap (build '((7 k1 v1) (7 k2 v2))))
  (define result (champ-insert snap 7 'k1 'v1*))
  (check-diff= snap result equal? "change k1 in collision")
  (define-values (c n) (champ-diff snap result equal?))
  (check-equal? (list->set c) (set (cons 'k1 'v1*)))
  (check-equal? n '()))

(test-case "collision node: diff against itself is empty"
  (define m (build '((7 k1 v1) (7 k2 v2) (7 k3 v3))))
  (define-values (c n) (champ-diff m m equal?))
  (check-equal? c '())
  (check-equal? n '()))

;; ============================================================
;; 4. Namespaced high-bit keys (the D-S.1 adversarial finding)
;; ============================================================
;; The trie indexes on the low 35 hash bits only (MAX-DEPTH 7 x 5). cell-ids
;; (ns<<32)|local with ns>=8 occupy bits >=35, so two ids agreeing on the low
;; 35 bits collide. hash 0 and 2^35 have identical low 35 bits → collision.

(test-case "namespaced ids agreeing on low 35 bits land in a collision; diff is correct"
  (define h-big (expt 2 35))
  (define snap (build (list (list 0 'k0 'v0) (list h-big 'kBig 'vBig))))
  (check-equal? (champ-size snap) 2)           ;; both present despite same low-35-bits
  (define result (champ-insert snap h-big 'kBig2 'vBig2))
  (check-diff= snap result equal? "add another high-bit key")
  ;; change the low-bits-zero key
  (define result2 (champ-insert snap 0 'k0 'v0*))
  (check-diff= snap result2 equal? "change low key sharing the collision")
  (define-values (c n) (champ-diff snap result2 equal?))
  (check-equal? (list->set c) (set (cons 'k0 'v0*))))

;; ============================================================
;; 5. Dependents-only change — caller-supplied same? (the cells-map case)
;; ============================================================
;; Values are (cons real-value tag); same? compares only real-value. A changed
;; tag with unchanged real-value must NOT be reported (mirrors a prop-cell whose
;; dependents changed but whose VALUE did not).

(define (val-same? a b) (equal? (car a) (car b)))

(test-case "dependents-only change (tag differs, value same) is NOT reported"
  (define snap (build (list (list 1 'k (cons 'v 'tagA)))))
  (define result (champ-insert snap 1 'k (cons 'v 'tagB)))  ;; same value, new tag
  (define-values (c n) (champ-diff snap result val-same?))
  (check-equal? c '() "value unchanged under same? → not changed")
  (check-equal? n '()))

(test-case "real value change IS reported under the same predicate"
  (define snap (build (list (list 1 'k (cons 'v 'tagA)))))
  (define result (champ-insert snap 1 'k (cons 'w 'tagA)))  ;; value changed
  (define-values (c n) (champ-diff snap result val-same?))
  (check-equal? (list->set c) (set (cons 'k (cons 'w 'tagA))))
  (check-equal? n '()))

;; ============================================================
;; 6. Deep/wide — O(changed), not O(N)
;; ============================================================

(test-case "large map: diff reports only the changed/new keys (O(changed))"
  (define snap (build (for/list ([i (in-range 500)]) (list i i (* i 10)))))
  ;; result: 3 new keys + 2 changed values
  (define result
    (let* ([m snap]
           [m (champ-insert m 500 500 5000)]    ;; new
           [m (champ-insert m 501 501 5010)]    ;; new
           [m (champ-insert m 502 502 5020)]    ;; new
           [m (champ-insert m 10 10 -1)]        ;; changed
           [m (champ-insert m 250 250 -2)])     ;; changed
      m))
  (check-diff= snap result equal? "500-entry map, 5 deltas")
  (define-values (c n) (champ-diff snap result equal?))
  (check-equal? (list->set c) (set (cons 10 -1) (cons 250 -2)))
  (check-equal? (list->set n) (set (cons 500 5000) (cons 501 5010) (cons 502 5020)))
  (check-equal? (+ (length c) (length n)) 5))   ;; exactly the deltas, nothing else
