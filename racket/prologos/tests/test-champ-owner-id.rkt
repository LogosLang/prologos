#lang racket/base

;;;
;;; CHAMP Performance Track — Acceptance Tests
;;;
;;; Sections match the Phase progression:
;;;   A: Persistent baseline (Phase 0 — should pass immediately)
;;;   B: Value-only update identity (uncomment at Phase 3)
;;;   C: Owner-ID transient operations (uncomment at Phase 5)
;;;   D: Mixed persistent + transient interleaving (uncomment at Phase 5)
;;;   E: Freeze invariant (uncomment at Phase 6)
;;;   F: Post-freeze copy semantics (uncomment at Phase 6)
;;;

(require rackunit
         racket/list
         "../champ.rkt")

;; ========================================
;; §A — Persistent Baseline (Phase 0)
;; ========================================
;; These establish correctness of existing operations as a regression canary.

(define (make-test-map n)
  ;; Build a CHAMP with N sequential integer keys
  (for/fold ([m champ-empty]) ([i (in-range n)])
    (champ-insert m i i (* i i))))

(test-case "A1: insert + lookup round-trip"
  (define m (make-test-map 100))
  (check-equal? (champ-size m) 100)
  (for ([i (in-range 100)])
    (check-equal? (champ-lookup m i i) (* i i))))

(test-case "A2: value update preserves size"
  (define m (make-test-map 50))
  (define m2 (champ-insert m 25 25 999))
  (check-equal? (champ-size m2) 50)
  (check-equal? (champ-lookup m2 25 25) 999)
  ;; Original unchanged
  (check-equal? (champ-lookup m 25 25) (* 25 25)))

(test-case "A3: delete"
  (define m (make-test-map 50))
  (define m2 (champ-delete m 25 25))
  (check-equal? (champ-size m2) 49)
  (check-equal? (champ-lookup m2 25 25) 'none)
  ;; Others unchanged
  (check-equal? (champ-lookup m2 0 0) 0)
  (check-equal? (champ-lookup m2 49 49) (* 49 49)))

(test-case "A4: insert-join (merge on collision)"
  (define (sum-merge old new) (+ old new))
  (define m (champ-insert champ-empty 42 'k 10))
  (define m2 (champ-insert-join m 42 'k 5 sum-merge))
  (check-equal? (champ-lookup m2 42 'k) 15))

(test-case "A5: large map (1000 entries, depth 2-3)"
  (define m (make-test-map 1000))
  (check-equal? (champ-size m) 1000)
  ;; Spot checks
  (check-equal? (champ-lookup m 0 0) 0)
  (check-equal? (champ-lookup m 500 500) 250000)
  (check-equal? (champ-lookup m 999 999) 998001))

(test-case "A6: fold, keys, vals"
  (define m (make-test-map 10))
  (check-equal? (champ-fold m (lambda (k v acc) (+ v acc)) 0)
                (for/sum ([i (in-range 10)]) (* i i)))
  (check-equal? (length (champ-keys m)) 10)
  (check-equal? (length (champ-vals m)) 10))

(test-case "A7: eq?-identity — same-pointer insert returns same root node"
  ;; This validates the existing persistent behavior before Phase 3 adds
  ;; the value-only fast path at the node level.
  ;; Currently: value update always copies, so root node is NOT eq? even
  ;; if value is the same. After Phase 3: root node IS eq? on same value.
  (define m (champ-insert champ-empty 42 'k 10))
  (define m2 (champ-insert m 42 'k 10))  ;; same key, same value
  ;; Before Phase 3: m2 is NOT eq? to m (content vector copied)
  ;; After Phase 3: m2 IS eq? to m (fast path returns same node)
  ;; For now, just verify correctness — not identity.
  (check-equal? (champ-lookup m2 42 'k) 10)
  (check-equal? (champ-size m2) 1))

(test-case "A8: existing transient (hash-table-based) round-trip"
  (define m (make-test-map 50))
  (define t (champ-transient m))
  (tchamp-insert! t 100 100 9999)
  (define m2 (tchamp-freeze t))
  (check-equal? (champ-size m2) 51)
  (check-equal? (champ-lookup m2 100 100) 9999)
  ;; Original unchanged
  (check-equal? (champ-size m) 50))

;; ========================================
;; §B — Value-Only Update Identity (Phase 3)
;; ========================================
;; Uncomment after Phase 3 implements value-only fast path.

;; (test-case "B1: same-value insert returns eq? node"
;;   (define m (champ-insert champ-empty 42 'k 10))
;;   (define m2 (champ-insert m 42 'k 10))
;;   (check-eq? m m2 "value-only update should return identical root"))

;; (test-case "B2: different-value insert returns new node"
;;   (define m (champ-insert champ-empty 42 'k 10))
;;   (define m2 (champ-insert m 42 'k 20))
;;   (check-not-eq? m m2)
;;   (check-equal? (champ-lookup m2 42 'k) 20))

;; (test-case "B3: chain of same-value updates all return eq?"
;;   (define m (make-test-map 100))
;;   ;; Re-insert every key with the same value
;;   (define m2
;;     (for/fold ([acc m]) ([i (in-range 100)])
;;       (champ-insert acc i i (* i i))))
;;   (check-eq? m m2 "100 same-value updates should return identical root"))

;; ========================================
;; §C — Owner-ID Transient Operations (Phase 5)
;; ========================================
;; Uncomment after Phase 5 implements owner-ID transients.

;; (test-case "C1: owner-ID transient insert + freeze"
;;   (define m (make-test-map 50))
;;   (define-values (node edit size) (champ-transient-owned m))
;;   ;; Insert 10 new keys
;;   (define size-box (box size))
;;   (define final-node
;;     (for/fold ([n node]) ([i (in-range 50 60)])
;;       (define-values (n* added?) (tchamp-insert-owned! n size-box i i (* i i) edit))
;;       (when added? (set-box! size-box (add1 (unbox size-box))))
;;       n*))
;;   (define m2 (tchamp-freeze-owned final-node (unbox size-box) edit))
;;   (check-equal? (champ-size m2) 60)
;;   (check-equal? (champ-lookup m2 55 55) (* 55 55))
;;   ;; Original unchanged
;;   (check-equal? (champ-size m) 50))

;; (test-case "C2: owner-ID transient delete"
;;   (define m (make-test-map 50))
;;   (define-values (node edit size) (champ-transient-owned m))
;;   (define size-box (box size))
;;   (define-values (n* removed?) (tchamp-delete-owned! node size-box 25 25 edit))
;;   (when removed? (set-box! size-box (sub1 (unbox size-box))))
;;   (define m2 (tchamp-freeze-owned n* (unbox size-box) edit))
;;   (check-equal? (champ-size m2) 49)
;;   (check-equal? (champ-lookup m2 25 25) 'none))

;; (test-case "C3: owner-ID transient insert-join"
;;   (define (sum-merge old new) (+ old new))
;;   (define m (champ-insert champ-empty 42 'k 10))
;;   (define-values (node edit size) (champ-transient-owned m))
;;   (define size-box (box size))
;;   (define-values (n* added?) (tchamp-insert-join-owned! node size-box 42 'k 5 sum-merge edit))
;;   (define m2 (tchamp-freeze-owned n* (unbox size-box) edit))
;;   (check-equal? (champ-lookup m2 42 'k) 15))

;; ========================================
;; §D — Mixed Persistent + Transient (Phase 5)
;; ========================================

;; (test-case "D1: two concurrent transients don't interfere"
;;   (define m (make-test-map 50))
;;   (define-values (n1 e1 s1) (champ-transient-owned m))
;;   (define-values (n2 e2 s2) (champ-transient-owned m))
;;   ;; Insert different keys into each
;;   (define sb1 (box s1))
;;   (define sb2 (box s2))
;;   (define-values (n1* _) (tchamp-insert-owned! n1 sb1 100 100 'a e1))
;;   (define-values (n2* __) (tchamp-insert-owned! n2 sb2 200 200 'b e2))
;;   (define m1 (tchamp-freeze-owned n1* (add1 (unbox sb1)) e1))
;;   (define m2 (tchamp-freeze-owned n2* (add1 (unbox sb2)) e2))
;;   ;; Each has its own insert but not the other's
;;   (check-equal? (champ-lookup m1 100 100) 'a)
;;   (check-equal? (champ-lookup m1 200 200) 'none)
;;   (check-equal? (champ-lookup m2 200 200) 'b)
;;   (check-equal? (champ-lookup m2 100 100) 'none))

;; ========================================
;; §E — Freeze Invariant (Phase 6)
;; ========================================

;; (test-case "E1: after freeze, no node has active edit"
;;   (define m (make-test-map 50))
;;   (define-values (node edit size) (champ-transient-owned m))
;;   (define sb (box size))
;;   ;; Modify several paths
;;   (define n*
;;     (for/fold ([n node]) ([i (in-range 50 60)])
;;       (define-values (n** _) (tchamp-insert-owned! n sb i i (* i i) edit))
;;       n**))
;;   (define frozen (tchamp-freeze-owned n* (unbox sb) edit))
;;   ;; Walk all nodes and verify no edit field matches any active token
;;   (check-true (champ-all-persistent? frozen)
;;               "all nodes should have edit=#f after freeze"))

;; ========================================
;; §F — Post-Freeze Copy Semantics (Phase 6)
;; ========================================

;; (test-case "F1: post-freeze transient on frozen map copies, not mutates"
;;   (define m (make-test-map 50))
;;   (define-values (n1 e1 s1) (champ-transient-owned m))
;;   (define sb1 (box s1))
;;   (define-values (n1* _) (tchamp-insert-owned! n1 sb1 100 100 'first e1))
;;   (define frozen (tchamp-freeze-owned n1* (add1 s1) e1))
;;   ;; Now create a NEW transient from the frozen map
;;   (define-values (n2 e2 s2) (champ-transient-owned frozen))
;;   (define sb2 (box s2))
;;   (define-values (n2* __) (tchamp-insert-owned! n2 sb2 200 200 'second e2))
;;   (define frozen2 (tchamp-freeze-owned n2* (add1 s2) e2))
;;   ;; frozen should NOT see the second insert
;;   (check-equal? (champ-lookup frozen 200 200) 'none)
;;   (check-equal? (champ-lookup frozen2 200 200) 'second))
