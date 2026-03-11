#lang racket/base

;;;
;;; Tests for postfix bracket indexing: preparse rewrite tests
;;;
;;; Validates that rewrite-dot-access (unified access sentinel handler)
;;; correctly rewrites $postfix-index sentinels to (get ...) forms,
;;; including mixed chains with $dot-access and $nil-dot-access.
;;;

(require rackunit
         "../macros.rkt")

;; ========================================
;; A. Basic postfix-index rewriting
;; ========================================

(test-case "rewrite: basic postfix-index → get"
  (check-equal?
   (rewrite-dot-access '(xs ($postfix-index 0)))
   '(get xs 0)))

(test-case "rewrite: keyword postfix-index → get"
  (check-equal?
   (rewrite-dot-access '(m ($postfix-index :key)))
   '(get m :key)))

(test-case "rewrite: expression postfix-index → get"
  (check-equal?
   (rewrite-dot-access '(m ($postfix-index (f x))))
   '(get m (f x))))

;; ========================================
;; B. Chained postfix-index
;; ========================================

(test-case "rewrite: chained postfix-index → nested get"
  (check-equal?
   (rewrite-dot-access '(xs ($postfix-index 0) ($postfix-index 1)))
   '(get (get xs 0) 1)))

(test-case "rewrite: triple chained → deeply nested get"
  (check-equal?
   (rewrite-dot-access '(xs ($postfix-index 0) ($postfix-index 1) ($postfix-index 2)))
   '(get (get (get xs 0) 1) 2)))

;; ========================================
;; C. Mixed with dot-access
;; ========================================

(test-case "rewrite: postfix-index then dot-access"
  (check-equal?
   (rewrite-dot-access '(xs ($postfix-index 0) ($dot-access field)))
   '(map-get (get xs 0) :field)))

(test-case "rewrite: dot-access then postfix-index"
  (check-equal?
   (rewrite-dot-access '(m ($dot-access items) ($postfix-index 0)))
   '(get (map-get m :items) 0)))

(test-case "rewrite: full path algebra chain"
  (check-equal?
   (rewrite-dot-access '(data ($postfix-index 0) ($dot-access users) ($postfix-index 1) ($dot-access name)))
   '(map-get (get (map-get (get data 0) :users) 1) :name)))

;; ========================================
;; D. Mixed with nil-dot-access
;; ========================================

(test-case "rewrite: nil-dot-access then postfix-index"
  (check-equal?
   (rewrite-dot-access '(m ($nil-dot-access field) ($postfix-index 0)))
   '(get (nil-safe-get m :field) 0)))

(test-case "rewrite: postfix-index then nil-dot-access"
  (check-equal?
   (rewrite-dot-access '(xs ($postfix-index 0) ($nil-dot-access field)))
   '(nil-safe-get (get xs 0) :field)))

;; ========================================
;; E. In larger forms
;; ========================================

(test-case "rewrite: postfix-index in larger form"
  (check-equal?
   (rewrite-dot-access '(f xs ($postfix-index 0) y))
   '(f (get xs 0) y)))

(test-case "rewrite: no sentinels → passthrough"
  (check-equal?
   (rewrite-dot-access '(f x y))
   '(f x y)))
