#lang racket/base

;;;
;;; Tests for WFLE Phase 5: Three-Valued Tabling Extension
;;; Verifies: wf-table-register, wf-table-add, wf-table-answers,
;;;           wf-all-mode-merge, wf-table-complete, wf-table-certainty,
;;;           integration with propagator network.
;;;

(require rackunit
         "../tabling.rkt"
         "../propagator.rkt")

;; ========================================
;; 1. wf-table-register
;; ========================================

(test-case "wf-tabling/register: creates table with 'unknown initial certainty"
  (define ts (table-store-empty))
  (define-values (ts2 cid) (wf-table-register ts 'p))
  (check-equal? (wf-table-certainty ts2 'p) 'unknown)
  (check-equal? (wf-table-answers ts2 'p) '()))

(test-case "wf-tabling/register: entry is a wf-table-entry"
  (define ts (table-store-empty))
  (define-values (ts2 cid) (wf-table-register ts 'q))
  (define entry (hash-ref (table-store-tables ts2) 'q))
  (check-true (wf-table-entry? entry))
  (check-equal? (table-entry-status entry) 'active)
  (check-equal? (table-entry-answer-mode entry) 'all))

;; ========================================
;; 2. wf-table-add and wf-table-answers
;; ========================================

(test-case "wf-tabling/add: stores answer with 'definite certainty"
  (define ts (table-store-empty))
  (define-values (ts2 cid) (wf-table-register ts 'p))
  (define ts3 (wf-table-add ts2 'p "hello" 'definite))
  (define answers (wf-table-answers ts3 'p))
  (check-equal? (length answers) 1)
  (check-equal? (caar answers) "hello")
  (check-equal? (cdar answers) 'definite))

(test-case "wf-tabling/add: stores answer with 'unknown certainty"
  (define ts (table-store-empty))
  (define-values (ts2 cid) (wf-table-register ts 'p))
  (define ts3 (wf-table-add ts2 'p "maybe" 'unknown))
  (define answers (wf-table-answers ts3 'p))
  (check-equal? (length answers) 1)
  (check-equal? (caar answers) "maybe")
  (check-equal? (cdar answers) 'unknown))

(test-case "wf-tabling/add: multiple answers with mixed certainties"
  (define ts (table-store-empty))
  (define-values (ts2 cid) (wf-table-register ts 'p))
  (define ts3 (wf-table-add ts2 'p "a" 'definite))
  (define ts4 (wf-table-add ts3 'p "b" 'unknown))
  (define answers (wf-table-answers ts4 'p))
  (check-equal? (length answers) 2))

;; ========================================
;; 3. wf-all-mode-merge
;; ========================================

(test-case "wf-tabling/merge: deduplicates by answer, keeps 'definite over 'unknown"
  (define old (list (cons "a" 'unknown)))
  (define new (list (cons "a" 'definite)))
  (define merged (wf-all-mode-merge old new))
  (check-equal? (length merged) 1)
  (check-equal? (cdar merged) 'definite))

(test-case "wf-tabling/merge: different answers preserved"
  (define old (list (cons "x" 'definite)))
  (define new (list (cons "y" 'unknown)))
  (define merged (wf-all-mode-merge old new))
  (check-equal? (length merged) 2))

(test-case "wf-tabling/merge: same answer different certainties, definite wins"
  (define entries (list (cons 5 'unknown) (cons 5 'definite) (cons 6 'unknown)))
  (define merged (wf-all-mode-merge '() entries))
  (check-equal? (length merged) 2)
  (define five-entry (assoc 5 merged))
  (check-not-false five-entry)
  (check-equal? (cdr five-entry) 'definite)
  (define six-entry (assoc 6 merged))
  (check-not-false six-entry)
  (check-equal? (cdr six-entry) 'unknown))

(test-case "wf-tabling/merge: empty lists"
  (check-equal? (wf-all-mode-merge '() '()) '()))

;; ========================================
;; 4. wf-table-complete and wf-table-certainty
;; ========================================

(test-case "wf-tabling/complete: marks table as complete with certainty"
  (define ts (table-store-empty))
  (define-values (ts2 cid) (wf-table-register ts 'p))
  (define ts3 (wf-table-complete ts2 'p 'definite))
  (check-true (table-complete? ts3 'p))
  (check-equal? (wf-table-certainty ts3 'p) 'definite))

(test-case "wf-tabling/complete: unknown completion"
  (define ts (table-store-empty))
  (define-values (ts2 cid) (wf-table-register ts 'q))
  (define ts3 (wf-table-complete ts2 'q 'unknown))
  (check-true (table-complete? ts3 'q))
  (check-equal? (wf-table-certainty ts3 'q) 'unknown))

(test-case "wf-tabling/certainty: returns #f for non-wf-table-entry"
  (define ts (table-store-empty))
  (define-values (ts2 cid) (table-register ts 'r 'all))
  (check-false (wf-table-certainty ts2 'r)))

(test-case "wf-tabling/certainty: returns #f for missing table"
  (define ts (table-store-empty))
  (check-false (wf-table-certainty ts 'nonexistent)))

;; ========================================
;; 5. Integration with propagator network
;; ========================================

(test-case "wf-tabling/integration: run-to-quiescence with wf-table"
  (define ts (table-store-empty))
  (define-values (ts2 cid) (wf-table-register ts 'p))
  (define ts3 (wf-table-add ts2 'p "a" 'definite))
  (define ts4 (wf-table-add ts3 'p "b" 'unknown))
  (define ts5 (table-run ts4))
  (define answers (wf-table-answers ts5 'p))
  (check-equal? (length answers) 2))

(test-case "wf-tabling/integration: definite supersedes unknown after merge via cell write"
  ;; Write unknown first, then definite for same answer — cell merge should resolve
  (define ts (table-store-empty))
  (define-values (ts2 cid) (wf-table-register ts 'p))
  (define ts3 (wf-table-add ts2 'p "x" 'unknown))
  (define ts4 (wf-table-add ts3 'p "x" 'definite))
  (define answers (wf-table-answers ts4 'p))
  (define x-entry (assoc "x" answers))
  (check-not-false x-entry)
  (check-equal? (cdr x-entry) 'definite))

(test-case "wf-tabling/integration: wf-table coexists with regular table"
  (define ts (table-store-empty))
  (define-values (ts2 cid1) (table-register ts 'regular 'all))
  (define-values (ts3 cid2) (wf-table-register ts2 'wf-pred))
  (define ts4 (table-add ts3 'regular "plain"))
  (define ts5 (wf-table-add ts4 'wf-pred "tagged" 'definite))
  ;; Regular table returns plain answers
  (define reg-answers (table-answers ts5 'regular))
  (check-equal? (length reg-answers) 1)
  (check-equal? (car reg-answers) "plain")
  ;; WF table returns (answer . certainty) pairs
  (define wf-answers (wf-table-answers ts5 'wf-pred))
  (check-equal? (length wf-answers) 1)
  (check-equal? (caar wf-answers) "tagged")
  (check-equal? (cdar wf-answers) 'definite))
