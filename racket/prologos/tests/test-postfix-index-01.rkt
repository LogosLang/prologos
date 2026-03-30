#lang racket/base

;;;
;;; Tests for postfix bracket indexing: reader-level tests
;;;
;;; Validates that the WS reader correctly detects adjacency and emits
;;; $postfix-index sentinels for xs[0] but not xs [0].
;;;

(require rackunit
         "../parse-reader.rkt")

;; ========================================
;; A. Adjacency detection — sentinel emission
;; ========================================

(test-case "reader: xs[0] adjacent → $postfix-index sentinel"
  (define result (read-all-forms-string "xs[0]"))
  (check-equal? result '((xs ($postfix-index 0)))))

(test-case "reader: xs [0] spaced → application (no sentinel)"
  (define result (read-all-forms-string "xs [0]"))
  (check-equal? result '((xs (0)))))

(test-case "reader: xs[0][1] chained → two sentinels"
  (define result (read-all-forms-string "xs[0][1]"))
  (check-equal? result '((xs ($postfix-index 0) ($postfix-index 1)))))

(test-case "reader: xs[0].field mixed with dot-access"
  (define result (read-all-forms-string "xs[0].field"))
  (check-equal? result '((xs ($postfix-index 0) ($dot-access field)))))

(test-case "reader: m[:key] keyword index"
  (define result (read-all-forms-string "m[:key]"))
  (check-equal? result '((m ($postfix-index :key)))))

(test-case "reader: xs[f x] expression index"
  (define result (read-all-forms-string "xs[f x]"))
  (check-equal? result '((xs ($postfix-index (f x))))))

;; ========================================
;; B. Inside bracket forms
;; ========================================

(test-case "reader: [f xs[0]] postfix inside brackets"
  (define result (read-all-forms-string "[f xs[0]]"))
  (check-equal? result '((f xs ($postfix-index 0)))))

(test-case "reader: [xs[0] ys[1]] multiple postfix in bracket"
  (define result (read-all-forms-string "[xs[0] ys[1]]"))
  (check-equal? result '((xs ($postfix-index 0) ys ($postfix-index 1)))))

;; ========================================
;; C. Edge cases
;; ========================================

(test-case "reader: [0] standalone bracket is just grouping"
  (define result (read-all-forms-string "[0]"))
  (check-equal? result '((0))))

(test-case "reader: xs[0].name[1] full chain"
  (define result (read-all-forms-string "xs[0].name[1]"))
  (check-equal? result '((xs ($postfix-index 0) ($dot-access name) ($postfix-index 1)))))

(test-case "reader: xs[0][1][2] triple chained"
  (define result (read-all-forms-string "xs[0][1][2]"))
  (check-equal? result '((xs ($postfix-index 0) ($postfix-index 1) ($postfix-index 2)))))
