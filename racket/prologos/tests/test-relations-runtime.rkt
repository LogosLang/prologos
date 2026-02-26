#lang racket/base

;;;
;;; Tests for relations.rkt — Relation Registry and Execution
;;; Phase 7a: registration, lookup, basic solve, explain
;;;

(require rackunit
         "../relations.rkt"
         "../solver.rkt"
         "../provenance.rkt")

;; ========================================
;; Relation store
;; ========================================

(test-case "make-relation-store: creates empty store"
  (define store (make-relation-store))
  (check-equal? (hash-count store) 0))

(test-case "relation-register: adds relation to store"
  (define store (make-relation-store))
  (define rel (relation-info 'parent #f
                (list (variant-info
                       (list (param-info 'x 'free) (param-info 'y 'free))
                       '()
                       (list (fact-row '("alice" "bob"))
                             (fact-row '("bob" "carol")))))
                #f #t))
  (define store2 (relation-register store rel))
  (check-equal? (length (relation-store-names store2)) 1)
  (check-not-false (relation-lookup store2 'parent)))

(test-case "relation-lookup: returns #f for missing"
  (define store (make-relation-store))
  (check-false (relation-lookup store 'nonexistent)))

(test-case "relation-register: multiple relations"
  (define store (make-relation-store))
  (define rel1 (relation-info 'parent #f
                  (list (variant-info
                         (list (param-info 'x 'free) (param-info 'y 'free))
                         '() (list (fact-row '("a" "b")))))
                  #f #t))
  (define rel2 (relation-info 'ancestor #f
                  (list (variant-info
                         (list (param-info 'x 'free) (param-info 'y 'free))
                         '() '()))
                  #f #t))
  (define store2 (relation-register (relation-register store rel1) rel2))
  (check-equal? (length (relation-store-names store2)) 2))

;; ========================================
;; Core structs
;; ========================================

(test-case "param-info: construction"
  (define p (param-info 'x 'in))
  (check-equal? (param-info-name p) 'x)
  (check-equal? (param-info-mode p) 'in))

(test-case "variant-info: construction"
  (define v (variant-info
             (list (param-info 'x 'free))
             (list (clause-info (list (goal-desc 'app '(parent x y)))))
             (list (fact-row '("alice" "bob")))))
  (check-equal? (length (variant-info-params v)) 1)
  (check-equal? (length (variant-info-clauses v)) 1)
  (check-equal? (length (variant-info-facts v)) 1))

(test-case "fact-row: construction"
  (define fr (fact-row '("alice" "bob")))
  (check-equal? (fact-row-terms fr) '("alice" "bob")))

(test-case "goal-desc: construction"
  (define g (goal-desc 'unify '(x y)))
  (check-equal? (goal-desc-kind g) 'unify)
  (check-equal? (goal-desc-args g) '(x y)))

;; ========================================
;; Solve — basic fact queries
;; ========================================

(test-case "solve-goal: basic fact query returns answers"
  (define store (make-relation-store))
  (define rel (relation-info 'parent #f
                (list (variant-info
                       (list (param-info 'x 'free) (param-info 'y 'free))
                       '()
                       (list (fact-row '("alice" "bob"))
                             (fact-row '("bob" "carol"))
                             (fact-row '("bob" "dave")))))
                #f #t))
  (define store2 (relation-register store rel))
  (define config (make-solver-config))
  (define answers (solve-goal config store2 'parent '() '(x y)))
  (check-true (list? answers))
  (check-equal? (length answers) 3))

(test-case "solve-goal: query projects named variables"
  (define store (make-relation-store))
  (define rel (relation-info 'parent #f
                (list (variant-info
                       (list (param-info 'x 'free) (param-info 'y 'free))
                       '()
                       (list (fact-row '("alice" "bob")))))
                #f #t))
  (define store2 (relation-register store rel))
  (define config (make-solver-config))
  (define answers (solve-goal config store2 'parent '() '(x y)))
  (check-equal? (length answers) 1)
  (define a (car answers))
  (check-equal? (hash-ref a 'x) "alice")
  (check-equal? (hash-ref a 'y) "bob"))

(test-case "solve-goal: unknown relation raises error"
  (define store (make-relation-store))
  (define config (make-solver-config))
  (check-exn exn:fail?
    (lambda () (solve-goal config store 'nonexistent '() '()))))

(test-case "solve-goal: empty relation returns empty"
  (define store (make-relation-store))
  (define rel (relation-info 'empty-rel #f
                (list (variant-info
                       (list (param-info 'x 'free))
                       '() '()))  ;; no facts, no clauses
                #f #t))
  (define store2 (relation-register store rel))
  (define config (make-solver-config))
  (define answers (solve-goal config store2 'empty-rel '() '(x)))
  (check-equal? (length answers) 0))

(test-case "solve-goal: partial variable projection"
  (define store (make-relation-store))
  (define rel (relation-info 'parent #f
                (list (variant-info
                       (list (param-info 'x 'free) (param-info 'y 'free))
                       '()
                       (list (fact-row '("alice" "bob")))))
                #f #t))
  (define store2 (relation-register store rel))
  (define config (make-solver-config))
  ;; Only project 'y
  (define answers (solve-goal config store2 'parent '() '(y)))
  (check-equal? (length answers) 1)
  (define a (car answers))
  (check-false (hash-has-key? a 'x))
  (check-equal? (hash-ref a 'y) "bob"))

;; ========================================
;; Explain — basic fact queries with provenance
;; ========================================

(test-case "explain-goal: returns answer-records"
  (define store (make-relation-store))
  (define rel (relation-info 'parent #f
                (list (variant-info
                       (list (param-info 'x 'free) (param-info 'y 'free))
                       '()
                       (list (fact-row '("alice" "bob")))))
                #f #t))
  (define store2 (relation-register store rel))
  (define config (make-solver-config))
  (define answers (explain-goal config store2 'parent '() '(x y) 'full))
  (check-equal? (length answers) 1)
  (check-true (answer-record? (car answers)))
  (check-equal? (hash-ref (answer-record-bindings (car answers)) 'x) "alice"))

(test-case "explain-goal: promotes 'none to 'full"
  ;; Even with 'none, explain should still return answer-records
  (define store (make-relation-store))
  (define rel (relation-info 'test #f
                (list (variant-info
                       (list (param-info 'x 'free))
                       '()
                       (list (fact-row '(42)))))
                #f #t))
  (define store2 (relation-register store rel))
  (define config (make-solver-config))
  (define answers (explain-goal config store2 'test '() '(x) 'none))
  (check-equal? (length answers) 1)
  (check-true (answer-record? (car answers))))
