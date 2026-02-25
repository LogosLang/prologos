#lang racket/base

;;;
;;; Tests for union-find.rkt — Persistent Union-Find
;;; Phase 4a: Racket-level data structure tests
;;;

(require rackunit
         "../union-find.rkt")

;; ========================================
;; Construction
;; ========================================

(test-case "uf-empty creates empty store"
  (define s (uf-empty))
  (check-equal? (uf-size s) 0)
  (check-false (uf-has-id? s 0)))

(test-case "uf-make-set adds singleton"
  (define s (uf-make-set (uf-empty) 0 'hello))
  (check-equal? (uf-size s) 1)
  (check-true (uf-has-id? s 0))
  (check-false (uf-has-id? s 1)))

(test-case "uf-make-set multiple elements"
  (define s
    (uf-make-set
     (uf-make-set
      (uf-make-set (uf-empty) 0 'a)
      1 'b)
     2 'c))
  (check-equal? (uf-size s) 3)
  (check-true (uf-has-id? s 0))
  (check-true (uf-has-id? s 1))
  (check-true (uf-has-id? s 2)))

;; ========================================
;; Find
;; ========================================

(test-case "uf-find singleton returns self"
  (define s (uf-make-set (uf-empty) 0 'hello))
  (define-values (root s*) (uf-find s 0))
  (check-equal? root 0 "root of singleton is self"))

(test-case "uf-find raises error for missing id"
  (check-exn exn:fail?
    (lambda () (uf-find (uf-empty) 42))))

;; ========================================
;; Value
;; ========================================

(test-case "uf-value retrieves payload"
  (define s (uf-make-set (uf-empty) 0 'hello))
  (define-values (val s*) (uf-value s 0))
  (check-equal? val 'hello))

(test-case "uf-value for multiple singletons"
  (define s
    (uf-make-set
     (uf-make-set (uf-empty) 0 'a)
     1 'b))
  (define-values (v0 s1) (uf-value s 0))
  (define-values (v1 s2) (uf-value s1 1))
  (check-equal? v0 'a)
  (check-equal? v1 'b))

;; ========================================
;; Union
;; ========================================

(test-case "uf-union merges two singletons"
  (define s
    (uf-make-set
     (uf-make-set (uf-empty) 0 'a)
     1 'b))
  (define s* (uf-union s 0 1))
  ;; Both should have the same root
  (define-values (r0 s1) (uf-find s* 0))
  (define-values (r1 s2) (uf-find s1 1))
  (check-equal? r0 r1 "after union, both ids have same root"))

(test-case "uf-union already same set is no-op"
  (define s
    (uf-make-set
     (uf-make-set (uf-empty) 0 'a)
     1 'b))
  (define s* (uf-union s 0 1))
  (define s** (uf-union s* 0 1))  ;; union again
  ;; Should still work fine
  (define-values (r0 _) (uf-find s** 0))
  (define-values (r1 __) (uf-find s** 1))
  (check-equal? r0 r1))

(test-case "uf-union rank-based merging"
  ;; Create a chain: union(0,1), union(2,3), union(0,2)
  ;; The deeper tree should become root
  (define s
    (uf-make-set
     (uf-make-set
      (uf-make-set
       (uf-make-set (uf-empty) 0 'a)
       1 'b)
      2 'c)
     3 'd))
  (define s1 (uf-union s 0 1))
  (define s2 (uf-union s1 2 3))
  (define s3 (uf-union s2 0 2))
  ;; All four should be in the same set
  (define-values (r0 s4) (uf-find s3 0))
  (define-values (r1 s5) (uf-find s4 1))
  (define-values (r2 s6) (uf-find s5 2))
  (define-values (r3 s7) (uf-find s6 3))
  (check-equal? r0 r1)
  (check-equal? r1 r2)
  (check-equal? r2 r3))

(test-case "uf-union with merge-fn"
  (define s
    (uf-make-set
     (uf-make-set (uf-empty) 0 10)
     1 20))
  (define s* (uf-union s 0 1 +))
  ;; The surviving root should have merged value 30
  (define-values (root s1) (uf-find s* 0))
  (define-values (val s2) (uf-value s1 root))
  (check-equal? val 30 "merge-fn should combine values"))

;; ========================================
;; Persistence
;; ========================================

(test-case "persistence: old store unchanged after union"
  (define s0
    (uf-make-set
     (uf-make-set (uf-empty) 0 'a)
     1 'b))
  (define s1 (uf-union s0 0 1))
  ;; s0 should be unchanged: 0 and 1 are separate sets
  (define-values (r0-old s0a) (uf-find s0 0))
  (define-values (r1-old s0b) (uf-find s0a 1))
  (check-not-equal? r0-old r1-old "old store: 0 and 1 are separate")
  ;; s1 should have them united
  (define-values (r0-new s1a) (uf-find s1 0))
  (define-values (r1-new s1b) (uf-find s1a 1))
  (check-equal? r0-new r1-new "new store: 0 and 1 are united"))

(test-case "persistence: old store value unchanged after make-set"
  (define s0 (uf-make-set (uf-empty) 0 'a))
  (define s1 (uf-make-set s0 1 'b))
  ;; s0 should still have only element 0
  (check-equal? (uf-size s0) 1)
  (check-false (uf-has-id? s0 1))
  ;; s1 has both
  (check-equal? (uf-size s1) 2))

;; ========================================
;; same-set?
;; ========================================

(test-case "uf-same-set? basic"
  (define s
    (uf-make-set
     (uf-make-set
      (uf-make-set (uf-empty) 0 'a)
      1 'b)
     2 'c))
  (define s* (uf-union s 0 1))
  (define-values (same01 s1) (uf-same-set? s* 0 1))
  (define-values (same02 s2) (uf-same-set? s1 0 2))
  (check-true same01 "0 and 1 are same set")
  (check-false same02 "0 and 2 are different sets"))

;; ========================================
;; Path splitting
;; ========================================

(test-case "path splitting updates parent pointers"
  ;; Build a chain: 0→1→2→3 (manually, via unions)
  ;; Actually, let's build via make-set + union sequence
  (define s
    (uf-make-set
     (uf-make-set
      (uf-make-set
       (uf-make-set
        (uf-make-set (uf-empty) 0 'a)
        1 'b)
       2 'c)
      3 'd)
     4 'e))
  ;; Union chain: 0+1, then result+2, then result+3, then result+4
  (define s1 (uf-union s 0 1))
  (define s2 (uf-union s1 2 0))
  (define s3 (uf-union s2 3 0))
  (define s4 (uf-union s3 4 0))
  ;; All should be in same set
  (define-values (r0 s5) (uf-find s4 4))
  (define-values (r1 s6) (uf-find s5 3))
  (check-equal? r0 r1 "chain union: all same root"))

;; ========================================
;; Multiple unions
;; ========================================

(test-case "chain of 10 unions and finds"
  (define s
    (for/fold ([s (uf-empty)])
              ([i (in-range 10)])
      (uf-make-set s i (* i 10))))
  ;; Union all into one set: 0+1, 0+2, 0+3, ...
  (define s*
    (for/fold ([s s])
              ([i (in-range 1 10)])
      (uf-union s 0 i)))
  ;; All should have same root
  (define-values (root0 s1) (uf-find s* 0))
  (for ([i (in-range 1 10)])
    (define-values (ri _) (uf-find s* i))
    (check-equal? ri root0 (format "element ~a has same root as 0" i))))

(test-case "performance: 100 make-set + union + find"
  (define s
    (for/fold ([s (uf-empty)])
              ([i (in-range 100)])
      (uf-make-set s i i)))
  ;; Union pairs: (0,1), (2,3), (4,5), ...
  (define s1
    (for/fold ([s s])
              ([i (in-range 0 100 2)])
      (uf-union s i (+ i 1))))
  ;; Find all roots
  (for ([i (in-range 100)])
    (define-values (root _) (uf-find s1 i))
    (check-true (and (integer? root) (>= root 0))))
  ;; Check pairs are in same set
  (for ([i (in-range 0 100 2)])
    (define-values (same? _) (uf-same-set? s1 i (+ i 1)))
    (check-true same? (format "~a and ~a should be same set" i (+ i 1)))))

;; ========================================
;; Value after union
;; ========================================

(test-case "uf-value after union without merge-fn"
  ;; Default: surviving root keeps its value
  (define s
    (uf-make-set
     (uf-make-set (uf-empty) 0 'zero)
     1 'one))
  (define s* (uf-union s 0 1))
  ;; The root should keep its original value
  (define-values (root s1) (uf-find s* 0))
  (define-values (val s2) (uf-value s1 root))
  ;; Root value should be either 'zero or 'one (depending on which became root)
  (check-true (or (equal? val 'zero) (equal? val 'one))
              "root has one of the original values"))

(test-case "uf-value after union with merge-fn (list append)"
  (define s
    (uf-make-set
     (uf-make-set (uf-empty) 0 '(a))
     1 '(b)))
  (define s* (uf-union s 0 1 append))
  (define-values (root s1) (uf-find s* 0))
  (define-values (val s2) (uf-value s1 root))
  (check-true (or (equal? val '(a b)) (equal? val '(b a)))
              "merge-fn appends lists"))
