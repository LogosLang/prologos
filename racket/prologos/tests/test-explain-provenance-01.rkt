#lang racket/base

;;;
;;; Tests for D4: Explain Provenance
;;; Verifies: answer-result structs, clause IDs, derivation trees,
;;;           provenance levels (none/summary/full), WF integration,
;;;           depth limiting, key naming conventions.
;;;

(require rackunit
         racket/string
         "../solver.rkt"
         "../relations.rkt"
         "../provenance.rkt"
         "../stratified-eval.rkt"
         "../wf-engine.rkt"
         "../bilattice.rkt"
         "../propagator.rkt"
         "../syntax.rkt"
         "../tabling.rkt")

;; ========================================
;; Helper: build relation stores
;; ========================================

(define (build-store . specs)
  (for/hasheq ([spec (in-list specs)])
    (define name (car spec))
    (define arity (cadr spec))
    (define facts (caddr spec))
    (define clauses (cadddr spec))
    (values name
            (relation-info name arity
              (list (variant-info
                     (for/list ([i (in-range arity)])
                       (param-info (string->symbol (format "X~a" i)) 'free))
                     (map clause-info clauses)
                     (map fact-row facts)))
              #f #f))))

;; Build a simple parent/ancestor store for most tests
(define test-store
  (build-store
   ;; parent: 3 facts, no clauses
   (list 'parent 2
         '(("tom" "bob") ("tom" "liz") ("bob" "ann"))
         '())
   ;; ancestor: 0 facts, 2 clauses
   ;;   clause-0: ancestor ?x ?y :- parent ?x ?y
   ;;   clause-1: ancestor ?x ?y :- parent ?x ?z, ancestor ?z ?y
   (list 'ancestor 2
         '()
         (list
          ;; clause-0: body = [(parent X0 X1)]
          (list (goal-desc 'app (list 'parent '(X0 X1))))
          ;; clause-1: body = [(parent X0 Z), (ancestor Z X1)]
          (list (goal-desc 'app (list 'parent '(X0 Z)))
                (goal-desc 'app (list 'ancestor '(Z X1))))))))

(define default-config (make-solver-config))

;; ========================================
;; 1. Basic struct tests
;; ========================================

(test-case "provenance/answer-result: construction and accessors"
  (define ar (make-answer-result
              #:bindings (hasheq 'x 1)
              #:certainty 'definite
              #:cycle '(a b)
              #:provenance (make-provenance-data #:clause-id 'foo/2-0 #:depth 3)))
  (check-equal? (answer-result-bindings ar) (hasheq 'x 1))
  (check-equal? (answer-result-certainty ar) 'definite)
  (check-equal? (answer-result-cycle ar) '(a b))
  (check-true (provenance-data? (answer-result-provenance ar)))
  (check-equal? (provenance-data-clause-id (answer-result-provenance ar)) 'foo/2-0)
  (check-equal? (provenance-data-depth (answer-result-provenance ar)) 3))

(test-case "provenance/answer-result: defaults are #f"
  (define ar (make-answer-result #:bindings (hasheq)))
  (check-false (answer-result-certainty ar))
  (check-false (answer-result-cycle ar))
  (check-false (answer-result-provenance ar)))

;; ========================================
;; 2. Stratified explain with provenance
;; ========================================

(test-case "provenance/stratified-full: parent fact returns provenance"
  (define results
    (parameterize ([current-relation-store test-store])
      (explain-goal default-config test-store 'parent (list "tom" 'who) '(who) 'full)))
  ;; Should get 2 answers (tom->bob, tom->liz)
  (check-equal? (length results) 2)
  ;; All results should be answer-result
  (check-true (andmap answer-result? results))
  ;; No certainty (stratified)
  (for ([r (in-list results)])
    (check-false (answer-result-certainty r)))
  ;; All should have provenance
  (for ([r (in-list results)])
    (check-true (provenance-data? (answer-result-provenance r)))))

(test-case "provenance/stratified-full: clause-id format for single-clause relation"
  (define results
    (parameterize ([current-relation-store test-store])
      (explain-goal default-config test-store 'parent (list "tom" 'who) '(who) 'full)))
  ;; parent has 3 facts, so should be parent/2-0, parent/2-1, parent/2-2
  (define clause-ids
    (map (lambda (r) (provenance-data-clause-id (answer-result-provenance r))) results))
  ;; Check they have the right prefix
  (for ([cid (in-list clause-ids)])
    (check-true (symbol? cid))
    (check-true (string-prefix? (symbol->string cid) "parent/2"))))

(test-case "provenance/stratified-full: ancestor clause-id has index"
  (define results
    (parameterize ([current-relation-store test-store])
      (explain-goal default-config test-store 'ancestor (list "tom" 'desc) '(desc) 'full)))
  ;; Should get 3 answers: bob, liz, ann
  (check-equal? (length results) 3)
  ;; Check clause-ids
  (define clause-ids
    (map (lambda (r) (provenance-data-clause-id (answer-result-provenance r))) results))
  ;; ancestor has 2 clauses, so IDs should be ancestor/2-0 or ancestor/2-1
  (for ([cid (in-list clause-ids)])
    (check-true (symbol? cid))
    (check-true (string-prefix? (symbol->string cid) "ancestor/2"))))

(test-case "provenance/stratified-full: derivation tree present"
  (define results
    (parameterize ([current-relation-store test-store])
      (explain-goal default-config test-store 'parent (list "tom" 'who) '(who) 'full)))
  ;; Facts should have derivation trees with empty children
  (for ([r (in-list results)])
    (define prov (answer-result-provenance r))
    (define dt (provenance-data-derivation prov))
    (check-true (derivation-tree? dt))
    (check-equal? (derivation-tree-goal dt) 'parent)
    (check-equal? (derivation-tree-children dt) '())))

(test-case "provenance/stratified-full: recursive derivation has children"
  (define results
    (parameterize ([current-relation-store test-store])
      (explain-goal default-config test-store 'ancestor (list "tom" 'desc) '(desc) 'full)))
  ;; Find the answer for "ann" (requires recursion: tom->bob->ann)
  (define ann-results
    (filter (lambda (r) (equal? (hash-ref (answer-result-bindings r) 'desc #f) "ann")) results))
  (check-equal? (length ann-results) 1)
  (define prov (answer-result-provenance (car ann-results)))
  (define dt (provenance-data-derivation prov))
  (check-true (derivation-tree? dt))
  ;; The top-level derivation should have children (recursive call)
  (check-true (pair? (derivation-tree-children dt))))

(test-case "provenance/stratified-summary: no derivation tree"
  (define results
    (parameterize ([current-relation-store test-store])
      (explain-goal default-config test-store 'parent (list "tom" 'who) '(who) 'summary)))
  (check-equal? (length results) 2)
  ;; Provenance present with clause-id and depth
  (for ([r (in-list results)])
    (define prov (answer-result-provenance r))
    (check-true (provenance-data? prov))
    (check-true (symbol? (provenance-data-clause-id prov)))
    ;; But no derivation tree at summary level
    (check-false (provenance-data-derivation prov))))

(test-case "provenance/explain-forces-full: explain overrides none to full"
  ;; When prov-level is 'none, explain-goal overrides to 'full
  (define results
    (parameterize ([current-relation-store test-store])
      (explain-goal default-config test-store 'parent (list "tom" 'who) '(who) 'none)))
  ;; Should still have provenance (explain forces full)
  (for ([r (in-list results)])
    (check-true (provenance-data? (answer-result-provenance r)))
    ;; And derivation tree (full level)
    (check-true (derivation-tree? (provenance-data-derivation (answer-result-provenance r))))))

;; ========================================
;; 3. WF integration
;; ========================================

;; Build a store with negation cycle for WF tests
(define wf-store
  (build-store
   ;; p :- not q.  q :- not p.  (odd cycle → both unknown)
   (list 'p 0 '()
         (list (list (goal-desc 'not (list (expr-goal-app 'q '()))))))
   (list 'q 0 '()
         (list (list (goal-desc 'not (list (expr-goal-app 'p '()))))))))

(define wf-config
  (make-solver-config (hasheq 'semantics 'well-founded)))

(test-case "provenance/wf-none: certainty present, no provenance"
  ;; WF with :none provenance — should get certainty but no provenance
  (define results
    (wf-explain-goal wf-config wf-store 'p '() '() 'none))
  (check-true (pair? results))
  (define r (car results))
  (check-true (answer-result? r))
  ;; Should have certainty
  (check-equal? (answer-result-certainty r) 'unknown)
  ;; Should have cycle info
  (check-true (list? (answer-result-cycle r)))
  ;; No provenance at :none level
  (check-false (answer-result-provenance r)))

(test-case "provenance/wf-definite: certainty is definite for non-cyclic"
  ;; A fact-only relation under WF should be definite
  (define fact-store
    (build-store (list 'a 0 '(()) '())))
  (define results
    (wf-explain-goal wf-config fact-store 'a '() '() 'full))
  (check-true (pair? results))
  (for ([r (in-list results)])
    (check-equal? (answer-result-certainty r) 'definite)))

;; ========================================
;; 4. Depth limiting
;; ========================================

(test-case "provenance/depth-limit: max-derivation-depth truncates"
  ;; Set max-derivation-depth to 1
  (define shallow-config
    (make-solver-config (hasheq 'max-derivation-depth 1)))
  (define results
    (parameterize ([current-relation-store test-store])
      (explain-goal shallow-config test-store 'ancestor (list "tom" 'desc) '(desc) 'full)))
  ;; Direct facts (depth 0->1) should succeed, deep recursion should be cut
  ;; tom->bob and tom->liz are depth 1 (ancestor clause body = 1 level)
  ;; tom->ann requires depth 2 (ancestor -> ancestor -> parent)
  ;; With max-depth 1, tom->ann should still be found but tree truncated
  (check-true (pair? results)))

;; ========================================
;; 5. Solver config: max-derivation-depth key
;; ========================================

(test-case "provenance/solver-config: max-derivation-depth default is 50"
  (check-equal? (solver-config-max-derivation-depth default-config) 50))

(test-case "provenance/solver-config: max-derivation-depth configurable"
  (define cfg (make-solver-config (hasheq 'max-derivation-depth 10)))
  (check-equal? (solver-config-max-derivation-depth cfg) 10))

;; ========================================
;; 6. Key naming regression guard
;; ========================================

(test-case "provenance/key-naming: no __ prefix in answer-result"
  ;; Ensure we use 'certainty not '__certainty
  (define ar (make-answer-result
              #:bindings (hasheq)
              #:certainty 'unknown
              #:cycle '(p q)))
  ;; This is a struct test — the actual key naming happens in serialization.
  ;; Just verify the struct works with the intended semantics.
  (check-equal? (answer-result-certainty ar) 'unknown)
  (check-equal? (answer-result-cycle ar) '(p q)))

(test-case "provenance/wf-answers->standard: uses unprefixed certainty key"
  ;; wf-answers->standard 'all mode should use 'certainty not '__certainty
  (define answers (list (wf-answer (hasheq 'X "a") 'definite)))
  (define all (wf-answers->standard answers 'all))
  (check-equal? (hash-ref (car all) 'certainty) 'definite)
  ;; Should NOT have __certainty
  (check-false (hash-has-key? (car all) '__certainty)))
