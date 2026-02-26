#lang racket/base

;;;
;;; Tests for provenance.rkt — Answer Records and Derivation Trees
;;; Phase 7a: answer construction, derivation trees, depth calculation
;;;

(require rackunit
         "../provenance.rkt")

;; ========================================
;; Answer construction
;; ========================================

(test-case "make-answer: minimal (bindings only)"
  (define a (make-answer #:bindings (hasheq 'x 42)))
  (check-true (answer-record? a))
  (check-equal? (answer-record-bindings a) (hasheq 'x 42))
  (check-false (answer-record-derivation a))
  (check-false (answer-record-clause-id a))
  (check-equal? (answer-record-depth a) 0)
  (check-false (answer-record-support a)))

(test-case "make-answer: with derivation and clause-id"
  (define tree (make-derivation 'parent '("alice" "bob") 'fact-1 '()))
  (define a (make-answer #:bindings (hasheq 'who "bob")
                         #:derivation tree
                         #:clause-id 'clause-1
                         #:depth 1))
  (check-equal? (answer-record-clause-id a) 'clause-1)
  (check-equal? (answer-record-depth a) 1)
  (check-true (derivation-tree? (answer-record-derivation a))))

(test-case "answer-bindings-map: extracts bindings"
  (define a (make-answer #:bindings (hasheq 'x 1 'y 2)))
  (check-equal? (answer-bindings-map a) (hasheq 'x 1 'y 2)))

;; ========================================
;; Derivation trees
;; ========================================

(test-case "make-derivation: leaf node"
  (define tree (make-derivation 'parent '("alice" "bob") 'fact-row-0 '()))
  (check-true (derivation-tree? tree))
  (check-equal? (derivation-tree-goal tree) 'parent)
  (check-equal? (derivation-tree-args tree) '("alice" "bob"))
  (check-equal? (derivation-tree-rule tree) 'fact-row-0)
  (check-equal? (derivation-tree-children tree) '()))

(test-case "derivation-depth: leaf = 0"
  (define tree (make-derivation 'parent '("a" "b") 'fact '()))
  (check-equal? (derivation-depth tree) 0))

(test-case "derivation-depth: one level deep"
  (define child (make-derivation 'parent '("a" "b") 'fact '()))
  (define tree (make-derivation 'ancestor '("a" "b") 'clause-1 (list child)))
  (check-equal? (derivation-depth tree) 1))

(test-case "derivation-depth: two levels deep"
  (define leaf (make-derivation 'parent '("b" "c") 'fact '()))
  (define mid (make-derivation 'ancestor '("a" "c") 'clause-2 (list leaf)))
  (define root (make-derivation 'ancestor '("a" "d") 'clause-2 (list mid)))
  (check-equal? (derivation-depth root) 2))

(test-case "derivation-depth: #f returns 0"
  (check-equal? (derivation-depth #f) 0))
