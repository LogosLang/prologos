#lang racket/base

;;;
;;; Tests for atms.rkt — Persistent ATMS
;;; Phase 5a: Racket-level data structure tests
;;;

(require rackunit
         "../atms.rkt"
         "../propagator.rkt")

;; ========================================
;; Construction
;; ========================================

(test-case "atms-empty creates empty ATMS"
  (define a (atms-empty))
  (check-equal? (atms-next-assumption a) 0)
  (check-equal? (hash-count (atms-assumptions a)) 0)
  (check-equal? (hash-count (atms-believed a)) 0)
  (check-equal? (atms-nogoods a) '())
  (check-equal? (atms-amb-groups a) '()))

(test-case "atms-empty wraps provided network"
  (define net (make-prop-network 500))
  (define a (atms-empty net))
  (check-eq? (atms-network a) net))

;; ========================================
;; Assumption management
;; ========================================

(test-case "atms-assume creates assumption and adds to believed"
  (define a (atms-empty))
  (define-values (a* aid) (atms-assume a 'h0 'hello))
  (check-equal? (assumption-id-n aid) 0)
  (check-equal? (atms-next-assumption a*) 1)
  (check-true (hash-has-key? (atms-assumptions a*) aid))
  (check-true (hash-has-key? (atms-believed a*) aid))
  (define asn (hash-ref (atms-assumptions a*) aid))
  (check-equal? (assumption-name asn) 'h0)
  (check-equal? (assumption-datum asn) 'hello))

(test-case "atms-assume monotonic counter"
  (define a (atms-empty))
  (define-values (a1 aid1) (atms-assume a 'h0 'a))
  (define-values (a2 aid2) (atms-assume a1 'h1 'b))
  (check-equal? (assumption-id-n aid1) 0)
  (check-equal? (assumption-id-n aid2) 1))

(test-case "atms-retract removes from believed"
  (define-values (a aid) (atms-assume (atms-empty) 'h0 'a))
  (check-true (hash-has-key? (atms-believed a) aid))
  (define a* (atms-retract a aid))
  (check-false (hash-has-key? (atms-believed a*) aid))
  ;; Assumption still exists in map
  (check-true (hash-has-key? (atms-assumptions a*) aid)))

;; ========================================
;; Nogood management
;; ========================================

(test-case "atms-add-nogood records nogood"
  (define-values (a0 h0) (atms-assume (atms-empty) 'h0 'a))
  (define-values (a1 h1) (atms-assume a0 'h1 'b))
  (define ng (hasheq h0 #t h1 #t))
  (define a* (atms-add-nogood a1 ng))
  (check-equal? (length (atms-nogoods a*)) 1))

(test-case "atms-consistent? returns #t when no nogood violated"
  (define-values (a0 h0) (atms-assume (atms-empty) 'h0 'a))
  (define-values (a1 h1) (atms-assume a0 'h1 'b))
  ;; No nogoods yet — everything consistent
  (check-true (atms-consistent? a1 (hasheq h0 #t h1 #t))))

(test-case "atms-consistent? returns #f when nogood subset of set"
  (define-values (a0 h0) (atms-assume (atms-empty) 'h0 'a))
  (define-values (a1 h1) (atms-assume a0 'h1 'b))
  (define-values (a2 h2) (atms-assume a1 'h2 'c))
  ;; Record {h0, h1} as nogood
  (define a* (atms-add-nogood a2 (hasheq h0 #t h1 #t)))
  ;; {h0, h1} is inconsistent
  (check-false (atms-consistent? a* (hasheq h0 #t h1 #t)))
  ;; {h0, h1, h2} is also inconsistent (superset of nogood)
  (check-false (atms-consistent? a* (hasheq h0 #t h1 #t h2 #t)))
  ;; {h0, h2} is fine
  (check-true (atms-consistent? a* (hasheq h0 #t h2 #t)))
  ;; {h0} alone is fine
  (check-true (atms-consistent? a* (hasheq h0 #t))))

;; ========================================
;; Worldview management
;; ========================================

(test-case "atms-with-worldview switches believed set"
  (define-values (a0 h0) (atms-assume (atms-empty) 'h0 'a))
  (define-values (a1 h1) (atms-assume a0 'h1 'b))
  ;; Both believed initially
  (check-true (hash-has-key? (atms-believed a1) h0))
  (check-true (hash-has-key? (atms-believed a1) h1))
  ;; Switch to only h0
  (define a* (atms-with-worldview a1 (hasheq h0 #t)))
  (check-true (hash-has-key? (atms-believed a*) h0))
  (check-false (hash-has-key? (atms-believed a*) h1)))

;; ========================================
;; Persistence
;; ========================================

(test-case "persistence: old ATMS unchanged after assume"
  (define a0 (atms-empty))
  (define-values (a1 aid) (atms-assume a0 'h0 'a))
  ;; a0 should still be empty
  (check-equal? (atms-next-assumption a0) 0)
  (check-equal? (hash-count (atms-assumptions a0)) 0))

(test-case "persistence: old ATMS unchanged after nogood"
  (define-values (a0 h0) (atms-assume (atms-empty) 'h0 'a))
  (define-values (a1 h1) (atms-assume a0 'h1 'b))
  (define a2 (atms-add-nogood a1 (hasheq h0 #t h1 #t)))
  ;; a1 should have no nogoods
  (check-equal? (atms-nogoods a1) '())
  ;; a2 should have one
  (check-equal? (length (atms-nogoods a2)) 1))

;; ========================================
;; Choice points (amb)
;; ========================================

(test-case "atms-amb creates assumptions with mutual exclusion"
  (define-values (a hyps) (atms-amb (atms-empty) '(a b c)))
  (check-equal? (length hyps) 3)
  ;; 3 alternatives → C(3,2) = 3 pairwise nogoods
  (check-equal? (length (atms-nogoods a)) 3)
  ;; All three assumed
  (for ([h (in-list hyps)])
    (check-true (hash-has-key? (atms-assumptions a) h)))
  ;; All three believed
  (for ([h (in-list hyps)])
    (check-true (hash-has-key? (atms-believed a) h)))
  ;; One amb group recorded
  (check-equal? (length (atms-amb-groups a)) 1)
  (check-equal? (atms-amb-groups a) (list hyps)))

(test-case "atms-amb mutual exclusion prevents believing two alternatives"
  (define-values (a hyps) (atms-amb (atms-empty) '(x y)))
  (define h0 (car hyps))
  (define h1 (cadr hyps))
  ;; {h0, h1} should be inconsistent
  (check-false (atms-consistent? a (hasheq h0 #t h1 #t)))
  ;; Each alone is consistent
  (check-true (atms-consistent? a (hasheq h0 #t)))
  (check-true (atms-consistent? a (hasheq h1 #t))))

;; ========================================
;; TMS cell operations
;; ========================================

(test-case "atms-write-cell + atms-read-cell round-trip"
  (define-values (a0 h0) (atms-assume (atms-empty) 'h0 'ignored))
  (define a1 (atms-write-cell a0 'my-cell 42 (hasheq h0 #t)))
  ;; h0 is believed, so we should see 42
  (check-equal? (atms-read-cell a1 'my-cell) 42))

(test-case "atms-read-cell returns bot for missing cell"
  (check-equal? (atms-read-cell (atms-empty) 'no-such-cell) 'bot))

(test-case "atms-read-cell filters by worldview"
  (define-values (a0 h0) (atms-assume (atms-empty) 'h0 'ignored))
  (define-values (a1 h1) (atms-assume a0 'h1 'ignored))
  ;; Write two values with different support
  (define a2 (atms-write-cell a1 'c 'val-h0 (hasheq h0 #t)))
  (define a3 (atms-write-cell a2 'c 'val-h1 (hasheq h1 #t)))
  ;; Under worldview {h0}: see val-h0
  (define a-wv0 (atms-with-worldview a3 (hasheq h0 #t)))
  (check-equal? (atms-read-cell a-wv0 'c) 'val-h0)
  ;; Under worldview {h1}: see val-h1
  (define a-wv1 (atms-with-worldview a3 (hasheq h1 #t)))
  (check-equal? (atms-read-cell a-wv1 'c) 'val-h1)
  ;; Under worldview {h0, h1}: see newest (val-h1, written last)
  (check-equal? (atms-read-cell a3 'c) 'val-h1))

(test-case "atms-read-cell returns bot when no compatible value"
  (define-values (a0 h0) (atms-assume (atms-empty) 'h0 'ignored))
  (define-values (a1 h1) (atms-assume a0 'h1 'ignored))
  ;; Write value supported by h0
  (define a2 (atms-write-cell a1 'c 'val (hasheq h0 #t)))
  ;; Under worldview {h1 only}: no compatible value
  (define a-wv (atms-with-worldview a2 (hasheq h1 #t)))
  (check-equal? (atms-read-cell a-wv 'c) 'bot))

(test-case "atms-write-cell unconditional value (empty support)"
  ;; A value with empty support is always visible
  (define a0 (atms-write-cell (atms-empty) 'c 'always (hasheq)))
  (check-equal? (atms-read-cell a0 'c) 'always))

;; ========================================
;; Solving
;; ========================================

(test-case "atms-solve-all: single amb returns all alternatives"
  (define-values (a0 hyps) (atms-amb (atms-empty) '(x y z)))
  ;; Write each alternative's datum to a TMS cell under its assumption
  (define a1
    (for/fold ([a a0])
              ([h (in-list hyps)]
               [alt (in-list '(x y z))])
      (atms-write-cell a 'goal alt (hasheq h #t))))
  (define answers (atms-solve-all a1 'goal))
  (check-equal? (length answers) 3)
  (check-not-false (member 'x answers))
  (check-not-false (member 'y answers))
  (check-not-false (member 'z answers)))

(test-case "atms-solve-all: two ambs produce Cartesian product"
  (define-values (a0 hyps1) (atms-amb (atms-empty) '(a b)))
  (define-values (a1 hyps2) (atms-amb a0 '(1 2)))
  ;; Write combined values
  (define a2
    (for*/fold ([a a1])
               ([h1 (in-list hyps1)]
                [h2 (in-list hyps2)]
                [v1 (in-list '(a b))]
                [v2 (in-list '(1 2))]
                #:when (and (eq? (assumption-datum (hash-ref (atms-assumptions a1) h1)) v1)
                            (eq? (assumption-datum (hash-ref (atms-assumptions a1) h2)) v2)))
      (atms-write-cell a 'goal (list v1 v2) (hasheq h1 #t h2 #t))))
  (define answers (atms-solve-all a2 'goal))
  ;; 2 × 2 = 4 combinations, all consistent (no cross-group nogoods)
  (check-equal? (length answers) 4))

(test-case "atms-solve-all: nogoods prune inconsistent worldviews"
  (define-values (a0 hyps) (atms-amb (atms-empty) '(x y z)))
  ;; Write alternatives
  (define a1
    (for/fold ([a a0])
              ([h (in-list hyps)]
               [alt (in-list '(x y z))])
      (atms-write-cell a 'goal alt (hasheq h #t))))
  ;; Add an extra nogood that eliminates one alternative
  ;; (Pretend we learned that the first hypothesis alone is inconsistent)
  (define a2 (atms-add-nogood a1 (hasheq (car hyps) #t)))
  (define answers (atms-solve-all a2 'goal))
  ;; Only 2 alternatives survive
  (check-equal? (length answers) 2)
  (check-false (member 'x answers))
  (check-not-false (member 'y answers))
  (check-not-false (member 'z answers)))

(test-case "atms-solve-all: no amb returns single value"
  ;; No amb groups → just read under current worldview
  (define a (atms-write-cell (atms-empty) 'c 'hello (hasheq)))
  (check-equal? (atms-solve-all a 'c) '(hello)))

(test-case "atms-solve-all: deduplicates answers"
  (define-values (a0 hyps) (atms-amb (atms-empty) '(same same-too)))
  ;; Both alternatives map to the same value
  (define a1
    (for/fold ([a a0])
              ([h (in-list hyps)])
      (atms-write-cell a 'goal 'same-value (hasheq h #t))))
  (define answers (atms-solve-all a1 'goal))
  ;; Should deduplicate
  (check-equal? (length answers) 1)
  (check-equal? (car answers) 'same-value))

;; ========================================
;; Helpers
;; ========================================

(test-case "hash-subset? basic"
  (check-true (hash-subset? (hasheq) (hasheq 'a #t)))
  (check-true (hash-subset? (hasheq 'a #t) (hasheq 'a #t 'b #t)))
  (check-false (hash-subset? (hasheq 'a #t 'b #t) (hasheq 'a #t)))
  (check-true (hash-subset? (hasheq) (hasheq))))

(test-case "assumption-id-hash returns n"
  (check-equal? (assumption-id-hash (assumption-id 42)) 42))

;; ========================================
;; Explanation / derivation chains (E3a)
;; ========================================

(test-case "atms-explain-hypothesis: returns nogoods containing hypothesis"
  (define-values (a0 h0) (atms-assume (atms-empty) 'h0 'a))
  (define-values (a1 h1) (atms-assume a0 'h1 'b))
  (define-values (a2 h2) (atms-assume a1 'h2 'c))
  ;; Record {h0, h1} and {h0, h2} as nogoods
  (define a3 (atms-add-nogood a2 (hasheq h0 #t h1 #t)))
  (define a4 (atms-add-nogood a3 (hasheq h0 #t h2 #t)))
  ;; h0 appears in both nogoods
  (define exps (atms-explain-hypothesis a4 h0))
  (check-equal? (length exps) 2)
  ;; h1 appears in only one
  (check-equal? (length (atms-explain-hypothesis a4 h1)) 1)
  ;; h2 appears in only one
  (check-equal? (length (atms-explain-hypothesis a4 h2)) 1))

(test-case "atms-explain-hypothesis: conflicting-assumptions excludes queried hypothesis"
  (define-values (a0 h0) (atms-assume (atms-empty) 'h0 'a))
  (define-values (a1 h1) (atms-assume a0 'h1 'b))
  (define a2 (atms-add-nogood a1 (hasheq h0 #t h1 #t)))
  (define exps (atms-explain-hypothesis a2 h0))
  (check-equal? (length exps) 1)
  (define exp (car exps))
  ;; conflicting-assumptions should have only h1, not h0
  (define others (nogood-explanation-conflicting-assumptions exp))
  (check-equal? (length others) 1)
  (check-equal? (car (car others)) h1)
  (check-equal? (assumption-name (cdr (car others))) 'h1))

(test-case "atms-explain-hypothesis: empty for hypothesis not in any nogood"
  (define-values (a0 h0) (atms-assume (atms-empty) 'h0 'a))
  (define-values (a1 h1) (atms-assume a0 'h1 'b))
  ;; No nogoods
  (check-equal? (atms-explain-hypothesis a1 h0) '())
  ;; Nogood involving only h0
  (define a2 (atms-add-nogood a1 (hasheq h0 #t)))
  (check-equal? (atms-explain-hypothesis a2 h1) '()))

(test-case "atms-explain: returns violated nogoods under believed set"
  (define-values (a0 h0) (atms-assume (atms-empty) 'h0 'a))
  (define-values (a1 h1) (atms-assume a0 'h1 'b))
  (define-values (a2 h2) (atms-assume a1 'h2 'c))
  ;; Both h0,h1 believed; record {h0,h1} as nogood
  (define a3 (atms-add-nogood a2 (hasheq h0 #t h1 #t)))
  ;; Under full believed set {h0,h1,h2}: one violation
  (define violations (atms-explain a3))
  (check-equal? (length violations) 1)
  ;; After retracting h1: no violations
  (define a4 (atms-retract a3 h1))
  (check-equal? (length (atms-explain a4)) 0))

(test-case "atms-explain: empty when no nogoods violated"
  (define-values (a0 h0) (atms-assume (atms-empty) 'h0 'a))
  (define-values (a1 h1) (atms-assume a0 'h1 'b))
  (check-equal? (atms-explain a1) '()))

(test-case "atms-explain: members include all assumptions in nogood"
  (define-values (a0 h0) (atms-assume (atms-empty) 'h0 'a))
  (define-values (a1 h1) (atms-assume a0 'h1 'b))
  (define a2 (atms-add-nogood a1 (hasheq h0 #t h1 #t)))
  (define violations (atms-explain a2))
  (check-equal? (length violations) 1)
  (define members (nogood-explanation-conflicting-assumptions (car violations)))
  ;; atms-explain returns ALL members (not just "others" like explain-hypothesis)
  (check-equal? (length members) 2))

;; ========================================
;; Performance
;; ========================================

(test-case "performance: 10-alternative amb + solve-all"
  (define alts (for/list ([i (in-range 10)]) (* i 10)))
  (define-values (a0 hyps) (atms-amb (atms-empty) alts))
  ;; Write each alternative
  (define a1
    (for/fold ([a a0])
              ([h (in-list hyps)]
               [alt (in-list alts)])
      (atms-write-cell a 'goal alt (hasheq h #t))))
  (define answers (atms-solve-all a1 'goal))
  (check-equal? (length answers) 10))
