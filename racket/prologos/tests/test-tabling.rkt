#lang racket/base

;;;
;;; Tests for tabling.rkt — SLG-Style Memoization (Racket level)
;;; Phase 6a: table-store construction, registration, add, answers,
;;; freeze, complete?, run, lookup
;;;

(require racket/list
         rackunit
         "../tabling.rkt"
         "../propagator.rkt")

;; ========================================
;; Construction
;; ========================================

(test-case "table-store-empty: creates empty store"
  (define ts (table-store-empty))
  (check-true (table-store? ts))
  (check-true (prop-network? (table-store-network ts)))
  (check-equal? (hash-count (table-store-tables ts)) 0))

(test-case "table-store-empty: wraps provided network"
  (define net (make-prop-network 5000))
  (define ts (table-store-empty net))
  (check-equal? (prop-network-fuel (table-store-network ts)) 5000))

;; ========================================
;; Registration
;; ========================================

(test-case "table-register: creates table entry"
  (define-values (ts cid) (table-register (table-store-empty) 'ancestor 'all))
  (check-true (table-store? ts))
  (check-true (cell-id? cid))
  (check-equal? (hash-count (table-store-tables ts)) 1)
  (define entry (hash-ref (table-store-tables ts) 'ancestor))
  (check-equal? (table-entry-name entry) 'ancestor)
  (check-equal? (table-entry-answer-mode entry) 'all)
  (check-equal? (table-entry-status entry) 'active))

(test-case "table-register: multiple tables"
  (define ts0 (table-store-empty))
  (define-values (ts1 _c1) (table-register ts0 'ancestor 'all))
  (define-values (ts2 _c2) (table-register ts1 'parent 'all))
  (check-equal? (hash-count (table-store-tables ts2)) 2))

;; ========================================
;; Add + Answers
;; ========================================

(test-case "table-add: single answer"
  (define-values (ts _cid) (table-register (table-store-empty) 'p 'all))
  (define ts2 (table-add ts 'p 'alice))
  (check-equal? (table-answers ts2 'p) '(alice)))

(test-case "table-add: multiple answers accumulate"
  (define-values (ts _cid) (table-register (table-store-empty) 'p 'all))
  (define ts2 (table-add (table-add ts 'p 'alice) 'p 'bob))
  (define answers (sort (table-answers ts2 'p) symbol<?))
  (check-equal? answers '(alice bob)))

(test-case "table-add: deduplication"
  (define-values (ts _cid) (table-register (table-store-empty) 'p 'all))
  (define ts2 (table-add (table-add (table-add ts 'p 'alice) 'p 'bob) 'p 'alice))
  (define answers (sort (table-answers ts2 'p) symbol<?))
  (check-equal? answers '(alice bob)
                "duplicate 'alice removed by set-merge"))

(test-case "table-answers: empty table"
  (define-values (ts _cid) (table-register (table-store-empty) 'p 'all))
  (check-equal? (table-answers ts 'p) '()))

;; ========================================
;; Lookup
;; ========================================

(test-case "table-lookup: answer present"
  (define-values (ts _cid) (table-register (table-store-empty) 'p 'all))
  (define ts2 (table-add ts 'p 'alice))
  (check-true (table-lookup ts2 'p 'alice)))

(test-case "table-lookup: answer absent"
  (define-values (ts _cid) (table-register (table-store-empty) 'p 'all))
  (define ts2 (table-add ts 'p 'alice))
  (check-false (table-lookup ts2 'p 'bob)))

(test-case "table-lookup: empty table"
  (define-values (ts _cid) (table-register (table-store-empty) 'p 'all))
  (check-false (table-lookup ts 'p 'anything)))

;; ========================================
;; Freeze + Complete?
;; ========================================

(test-case "table-complete?: active table is not complete"
  (define-values (ts _cid) (table-register (table-store-empty) 'p 'all))
  (check-false (table-complete? ts 'p)))

(test-case "table-freeze + table-complete?"
  (define-values (ts _cid) (table-register (table-store-empty) 'p 'all))
  (define ts2 (table-freeze ts 'p))
  (check-true (table-complete? ts2 'p)))

(test-case "table-complete?: nonexistent table"
  (check-false (table-complete? (table-store-empty) 'nonexistent)))

;; ========================================
;; Run (quiescence)
;; ========================================

(test-case "table-run: empty network reaches quiescence"
  (define ts (table-store-empty))
  (define ts2 (table-run ts))
  (check-true (table-store? ts2)))

(test-case "table-run: propagator writes to table cell"
  ;; Set up: register table, create a propagator that writes answers
  (define ts0 (table-store-empty))
  (define-values (ts1 cid) (table-register ts0 'p 'all))
  ;; Add a propagator that writes 'fact1 to the table cell
  ;; We need a source cell to trigger the propagator
  (define net (table-store-network ts1))
  (define-values (net2 src-cid) (net-new-cell net 0 max))
  (define-values (net3 _pid)
    (net-add-propagator net2 (list src-cid) (list cid)
      (lambda (net)
        (net-cell-write net cid (list 'fact1)))))
  ;; Trigger by writing to source cell
  (define net4 (net-cell-write net3 src-cid 1))
  (define ts2 (struct-copy table-store ts1 [network net4]))
  (define ts3 (table-run ts2))
  (check-equal? (table-answers ts3 'p) '(fact1)))

;; ========================================
;; First answer mode
;; ========================================

(test-case "first mode: only first answer kept"
  (define-values (ts _cid) (table-register (table-store-empty) 'p 'first))
  (define ts2 (table-add (table-add ts 'p 'first-answer) 'p 'second-answer))
  (check-equal? (table-answers ts2 'p) '(first-answer)
                "second answer ignored in first mode"))

;; ========================================
;; Persistence
;; ========================================

(test-case "persistence: old table-store unchanged"
  (define-values (ts1 _cid) (table-register (table-store-empty) 'p 'all))
  (define ts2 (table-add ts1 'p 'alice))
  ;; ts1 should still have empty table
  (check-equal? (table-answers ts1 'p) '()
                "original store unchanged")
  (check-equal? (table-answers ts2 'p) '(alice)))

;; ========================================
;; Multiple independent tables
;; ========================================

(test-case "independent tables: answers don't cross"
  (define ts0 (table-store-empty))
  (define-values (ts1 _c1) (table-register ts0 'parent 'all))
  (define-values (ts2 _c2) (table-register ts1 'ancestor 'all))
  (define ts3 (table-add (table-add ts2 'parent 'alice) 'ancestor 'bob))
  (check-equal? (table-answers ts3 'parent) '(alice))
  (check-equal? (table-answers ts3 'ancestor) '(bob)))

;; ========================================
;; Performance
;; ========================================

(test-case "performance: 100 answers with deduplication"
  (define-values (ts _cid) (table-register (table-store-empty) 'p 'all))
  ;; Add 100 answers (some duplicates)
  (define ts2
    (for/fold ([ts ts])
              ([i (in-range 100)])
      (table-add ts 'p (modulo i 50))))  ;; 50 unique, each added twice
  (define answers (table-answers ts2 'p))
  (check-equal? (length answers) 50
                "50 unique answers after deduplication"))
