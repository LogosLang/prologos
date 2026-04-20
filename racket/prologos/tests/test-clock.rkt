#lang racket/base

;;;
;;; test-clock.rkt — PPN 4C Phase 1e-β-iii tests for clock.rkt primitive
;;;

(require rackunit
         "../propagator.rkt"
         "../clock.rkt")

;; ============================================================
;; Timestamp ops
;; ============================================================

(test-case "timestamp<? strict lex compare: counter dominates"
  (check-true (timestamp<? (timestamp 1 0) (timestamp 2 0)))
  (check-true (timestamp<? (timestamp 1 999) (timestamp 2 0)))
  (check-false (timestamp<? (timestamp 2 0) (timestamp 1 0))))

(test-case "timestamp<? equal counter — pid breaks tie"
  (check-true (timestamp<? (timestamp 5 0) (timestamp 5 1)))
  (check-false (timestamp<? (timestamp 5 1) (timestamp 5 0)))
  (check-false (timestamp<? (timestamp 5 0) (timestamp 5 0))))

(test-case "timestamp=? equality"
  (check-true (timestamp=? (timestamp 5 0) (timestamp 5 0)))
  (check-false (timestamp=? (timestamp 5 0) (timestamp 5 1)))
  (check-false (timestamp=? (timestamp 5 0) (timestamp 6 0))))

;; ============================================================
;; Fresh timestamp (reads + increments clock cell)
;; ============================================================

(test-case "fresh-timestamp reads + increments clock"
  (define net0 (make-prop-network))
  (define-values (net1 clock-cid) (net-allocate-clock-cell net0))
  (check-equal? (net-cell-read net1 clock-cid) 0)
  (define-values (net2 ts1) (fresh-timestamp net1 clock-cid))
  (check-equal? (timestamp-counter ts1) 1)
  (check-equal? (timestamp-pid ts1) 0)  ;; default process-id
  (check-equal? (net-cell-read net2 clock-cid) 1)
  (define-values (net3 ts2) (fresh-timestamp net2 clock-cid))
  (check-equal? (timestamp-counter ts2) 2)
  (check-true (timestamp<? ts1 ts2)))

(test-case "fresh-timestamp respects current-process-id"
  (define net0 (make-prop-network))
  (define-values (net1 clock-cid) (net-allocate-clock-cell net0))
  (parameterize ([current-process-id 7])
    (define-values (_net ts) (fresh-timestamp net1 clock-cid))
    (check-equal? (timestamp-pid ts) 7)))

;; ============================================================
;; net-allocate-clock-cell sets current-clock-cell-id parameter
;; ============================================================

(test-case "net-allocate-clock-cell sets current-clock-cell-id"
  (parameterize ([current-clock-cell-id #f])
    (define net0 (make-prop-network))
    (define-values (_net cid) (net-allocate-clock-cell net0))
    (check-equal? (current-clock-cell-id) cid)))

;; ============================================================
;; merge-by-timestamp-max
;; ============================================================

(test-case "merge-by-timestamp-max: bot handling"
  (define tv (timestamped-value (timestamp 1 0) 'hello))
  (check-equal? (merge-by-timestamp-max 'infra-bot tv) tv)
  (check-equal? (merge-by-timestamp-max tv 'infra-bot) tv))

(test-case "merge-by-timestamp-max: newer timestamp wins"
  (define tv1 (timestamped-value (timestamp 1 0) 'old-value))
  (define tv2 (timestamped-value (timestamp 2 0) 'new-value))
  (check-equal? (merge-by-timestamp-max tv1 tv2) tv2)
  (check-equal? (merge-by-timestamp-max tv2 tv1) tv2))  ;; commutative in terms of "newer wins"

(test-case "merge-by-timestamp-max: equal ts equal payload = identity"
  (define tv (timestamped-value (timestamp 5 0) 'same))
  (check-equal? (merge-by-timestamp-max tv tv) tv))

(test-case "merge-by-timestamp-max: equal ts different payload = contradiction"
  (define tv1 (timestamped-value (timestamp 5 0) 'value-A))
  (define tv2 (timestamped-value (timestamp 5 0) 'value-B))
  (check-true (timestamp-contradiction? (merge-by-timestamp-max tv1 tv2))))

(test-case "merge-by-timestamp-max: contradiction absorbs"
  (define tv (timestamped-value (timestamp 1 0) 'hello))
  (check-true (timestamp-contradiction? (merge-by-timestamp-max 'timestamp-contradiction tv)))
  (check-true (timestamp-contradiction? (merge-by-timestamp-max tv 'timestamp-contradiction))))

(test-case "merge-by-timestamp-max: pid breaks tie at equal counter"
  (define tv-a (timestamped-value (timestamp 5 0) 'a))
  (define tv-b (timestamped-value (timestamp 5 1) 'b))
  (check-equal? (merge-by-timestamp-max tv-a tv-b) tv-b))  ;; higher pid wins

;; ============================================================
;; net-new-timestamped-cell + net-write-timestamped + net-read
;; ============================================================

(test-case "net-new-timestamped-cell: initial value wrapped + clock advanced"
  (define net0 (make-prop-network))
  (define-values (net1 clock-cid) (net-allocate-clock-cell net0))
  (define-values (net2 cid) (net-new-timestamped-cell net1 clock-cid 'initial))
  (define tv (net-cell-read net2 cid))
  (check-true (timestamped-value? tv))
  (check-equal? (timestamped-value-payload tv) 'initial)
  (check-equal? (timestamp-counter (timestamped-value-ts tv)) 1))  ;; clock advanced

(test-case "net-write-timestamped: newer write wins"
  (define net0 (make-prop-network))
  (define-values (net1 clock-cid) (net-allocate-clock-cell net0))
  (define-values (net2 cid) (net-new-timestamped-cell net1 clock-cid 'first))
  (define net3 (net-write-timestamped net2 clock-cid cid 'second))
  (check-equal? (net-read-timestamped-payload net3 cid) 'second))

(test-case "net-read-timestamped-payload: unwraps to payload"
  (define net0 (make-prop-network))
  (define-values (net1 clock-cid) (net-allocate-clock-cell net0))
  (define-values (net2 cid) (net-new-timestamped-cell net1 clock-cid 42))
  (check-equal? (net-read-timestamped-payload net2 cid) 42))

(test-case "net-read-timestamped: returns the full timestamped-value"
  (define net0 (make-prop-network))
  (define-values (net1 clock-cid) (net-allocate-clock-cell net0))
  (define-values (net2 cid) (net-new-timestamped-cell net1 clock-cid 'x))
  (define tv (net-read-timestamped net2 cid))
  (check-true (timestamped-value? tv))
  (check-equal? (timestamped-value-payload tv) 'x))

;; ============================================================
;; Multi-cell ordering via shared clock
;; ============================================================

(test-case "multi-cell: timestamps order writes across cells globally"
  (define net0 (make-prop-network))
  (define-values (net1 clock-cid) (net-allocate-clock-cell net0))
  (define-values (net2 cid-a) (net-new-timestamped-cell net1 clock-cid 'a-init))
  (define-values (net3 cid-b) (net-new-timestamped-cell net2 clock-cid 'b-init))
  (define ts-a (timestamped-value-ts (net-cell-read net3 cid-a)))
  (define ts-b (timestamped-value-ts (net-cell-read net3 cid-b)))
  (check-true (timestamp<? ts-a ts-b)))  ;; cid-b allocated after cid-a → higher ts
