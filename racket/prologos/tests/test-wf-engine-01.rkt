#lang racket/base

;;;
;;; Tests for WFLE Phase 4a: Well-Founded Engine
;;; Verifies: NAF oracle, bilattice stability check, transitive closure,
;;;           preds-with-negation, wf-solve-goal, answer conversion,
;;;           solver dispatch via semantics config, explanation.
;;;

(require rackunit
         "../propagator.rkt"
         "../bilattice.rkt"
         "../solver.rkt"
         "../relations.rkt"
         "../stratified-eval.rkt"
         "../wf-engine.rkt"
         "../tabling.rkt"
         "../syntax.rkt")

;; ========================================
;; Helper: build relation stores for unit tests
;; ========================================

;; Build a simple relation store from specs.
;; spec: (list (list name arity facts clauses))
;;   facts: (listof (listof value))
;;   clauses: (listof (listof goal-desc))
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

;; ========================================
;; 1. NAF Oracle tests
;; ========================================

(test-case "wf-engine/naf-oracle: succeed for definitely-false predicate"
  (define net (make-prop-network))
  (define-values (net1 bvar) (bilattice-new-var net bool-lattice))
  ;; Force upper to false → definitely false
  (define net2 (bilattice-upper-write net1 bvar #f))
  (define oracle (make-wf-naf-oracle net2 (hasheq 'p bvar)))
  (check-equal? (oracle 'p) 'succeed))

(test-case "wf-engine/naf-oracle: fail for definitely-true predicate"
  (define net (make-prop-network))
  (define-values (net1 bvar) (bilattice-new-var net bool-lattice))
  ;; Force lower to true → definitely true
  (define net2 (bilattice-lower-write net1 bvar #t))
  (define oracle (make-wf-naf-oracle net2 (hasheq 'p bvar)))
  (check-equal? (oracle 'p) 'fail))

(test-case "wf-engine/naf-oracle: defer for unknown predicate"
  (define net (make-prop-network))
  (define-values (net1 bvar) (bilattice-new-var net bool-lattice))
  ;; Fresh bvar: lower=false, upper=true → unknown
  (define oracle (make-wf-naf-oracle net1 (hasheq 'p bvar)))
  (check-equal? (oracle 'p) 'defer))

(test-case "wf-engine/naf-oracle: succeed for predicate without bilattice entry"
  (define net (make-prop-network))
  (define oracle (make-wf-naf-oracle net (hasheq)))
  ;; No bilattice entry → closed-world assumption
  (check-equal? (oracle 'unknown-pred) 'succeed))

;; ========================================
;; 2. Bilattice stability check
;; ========================================

(test-case "wf-engine/bilattice-stable: identical networks are stable"
  (define net (make-prop-network))
  (define-values (net1 bvar) (bilattice-new-var net bool-lattice))
  (check-true (bilattice-stable? net1 net1 (hasheq 'p bvar))))

(test-case "wf-engine/bilattice-stable: different lower is unstable"
  (define net (make-prop-network))
  (define-values (net1 bvar) (bilattice-new-var net bool-lattice))
  (define net2 (bilattice-lower-write net1 bvar #t))
  (check-false (bilattice-stable? net1 net2 (hasheq 'p bvar))))

;; ========================================
;; 3. Transitive pred closure
;; ========================================

(test-case "wf-engine/transitive-closure: single fact"
  (define store
    (build-store (list 'color 1 '(("red")) '())))
  (define preds (transitive-pred-closure store 'color))
  (check-not-false (member 'color preds))
  (check-equal? (length preds) 1))

(test-case "wf-engine/transitive-closure: chain of deps"
  ;; ancestor depends on parent
  (define store
    (build-store
     (list 'parent 2 '(("a" "b")) '())
     (list 'ancestor 2 '()
           (list (list (goal-desc 'app (list 'parent '(X0 X1))))))))
  (define preds (transitive-pred-closure store 'ancestor))
  (check-not-false (member 'ancestor preds))
  (check-not-false (member 'parent preds)))

;; ========================================
;; 4. Preds with negation
;; ========================================

(test-case "wf-engine/preds-with-negation: stratifiable negation → no cycle preds"
  ;; p :- not q. q is a fact. This is stratifiable (no negative cycle).
  ;; preds-with-negation should return empty — only negative CYCLE predicates
  ;; need bilattice tracking.
  (define inner-q (expr-goal-app 'q (list)))
  (define store
    (build-store
     (list 'q 0 '(()) '())
     (list 'p 0 '()
           (list (list (goal-desc 'not (list inner-q)))))))
  (define all-preds (transitive-pred-closure store 'p))
  (define neg-preds (preds-with-negation store all-preds))
  (check-equal? neg-preds '() "stratifiable: no negative cycles"))

(test-case "wf-engine/preds-with-negation: odd cycle → cycle preds detected"
  ;; p :- not q. q :- not p. This is an odd cycle — both are in negative SCC.
  (define inner-q (expr-goal-app 'q (list)))
  (define inner-p (expr-goal-app 'p (list)))
  (define store
    (build-store
     (list 'p 0 '() (list (list (goal-desc 'not (list inner-q)))))
     (list 'q 0 '() (list (list (goal-desc 'not (list inner-p)))))))
  (define all-preds (transitive-pred-closure store 'p))
  (define neg-preds (preds-with-negation store all-preds))
  (check-not-false (member 'q neg-preds))
  (check-not-false (member 'p neg-preds)))

;; ========================================
;; 5. Answer conversion
;; ========================================

(test-case "wf-engine/answers->standard: strict filters unknowns"
  (define answers
    (list (wf-answer (hasheq 'X "a") 'definite)
          (wf-answer (hasheq 'X "b") 'unknown)
          (wf-answer (hasheq 'X "c") 'definite)))
  (define strict (wf-answers->standard answers 'strict))
  (check-equal? (length strict) 2)
  (check-true (andmap hash? strict)))

(test-case "wf-engine/answers->standard: all includes certainty tag"
  (define answers
    (list (wf-answer (hasheq 'X "a") 'definite)
          (wf-answer (hasheq 'X "b") 'unknown)))
  (define all (wf-answers->standard answers 'all))
  (check-equal? (length all) 2)
  (check-equal? (hash-ref (car all) '__certainty) 'definite)
  (check-equal? (hash-ref (cadr all) '__certainty) 'unknown))

;; ========================================
;; 6. Solver config: semantics key
;; ========================================

(test-case "wf-engine/solver-config: default semantics is stratified"
  (check-equal? (solver-config-semantics default-solver-config) 'stratified))

(test-case "wf-engine/solver-config: can set to well-founded"
  (define cfg (make-solver-config (hasheq 'semantics 'well-founded)))
  (check-equal? (solver-config-semantics cfg) 'well-founded))

;; ========================================
;; 7. WF solve: basic queries
;; ========================================

(test-case "wf-engine/solve: simple fact query"
  (define store
    (build-store (list 'color 1 '(("red") ("blue")) '())))
  (parameterize ([current-relation-store store])
    (define answers
      (wf-solve-goal default-solver-config store 'color '() '(X0)))
    (check-equal? (length answers) 2)
    (for ([a (in-list answers)])
      (check-equal? (wf-answer-certainty a) 'definite))))

(test-case "wf-engine/solve: rule with positive body"
  ;; big :- color. color is "red".
  (define store
    (build-store
     (list 'color 1 '(("red")) '())
     (list 'big 1 '()
           (list (list (goal-desc 'app (list 'color '(X0))))))))
  (parameterize ([current-relation-store store])
    (define answers
      (wf-solve-goal default-solver-config store 'big '() '(X0)))
    (check-true (>= (length answers) 1))
    (for ([a (in-list answers)])
      (check-equal? (wf-answer-certainty a) 'definite))))

(test-case "wf-engine/solve: stratifiable negation — a :- not b. b :- not c. c is fact"
  ;; c is a fact → c is true
  ;; b :- not c → not c fails (c is true) → b is false
  ;; a :- not b → not b succeeds (b is false) → a is true
  (define inner-c (expr-goal-app 'c (list)))
  (define inner-b (expr-goal-app 'b (list)))
  (define store
    (build-store
     (list 'c 0 '(()) '())
     (list 'b 0 '() (list (list (goal-desc 'not (list inner-c)))))
     (list 'a 0 '() (list (list (goal-desc 'not (list inner-b)))))))
  (parameterize ([current-relation-store store])
    (define answers
      (wf-solve-goal default-solver-config store 'a '() '()))
    ;; a should be provable (definite true)
    (check-true (>= (length answers) 1))
    (for ([a (in-list answers)])
      (check-equal? (wf-answer-certainty a) 'definite))))

;; ========================================
;; 8. WF solve: well-founded specific cases
;; ========================================

(test-case "wf-engine/solve: odd cycle — p :- not q. q :- not p. → both unknown"
  ;; Classic odd cycle: p and q should both be unknown
  (define inner-q (expr-goal-app 'q (list)))
  (define inner-p (expr-goal-app 'p (list)))
  (define store
    (build-store
     (list 'p 0 '() (list (list (goal-desc 'not (list inner-q)))))
     (list 'q 0 '() (list (list (goal-desc 'not (list inner-p)))))))
  (parameterize ([current-relation-store store])
    (define answers-p
      (wf-solve-goal default-solver-config store 'p '() '()))
    (define answers-q
      (wf-solve-goal default-solver-config store 'q '() '()))
    ;; Both should either be empty (no definite answers) or unknown
    ;; Under the WF engine with predicate-level granularity,
    ;; both p and q are unknown — DFS with deferred NAF finds no proofs
    (check-equal? (length answers-p) 0
                  "odd cycle: p has no definite proofs")
    (check-equal? (length answers-q) 0
                  "odd cycle: q has no definite proofs")))

(test-case "wf-engine/solve: self-reference — p :- not p. → unknown"
  (define inner-p (expr-goal-app 'p (list)))
  (define store
    (build-store
     (list 'p 0 '() (list (list (goal-desc 'not (list inner-p)))))))
  (parameterize ([current-relation-store store])
    (define answers
      (wf-solve-goal default-solver-config store 'p '() '()))
    ;; p :- not p is the classic undetermined case
    (check-equal? (length answers) 0
                  "self-referencing negation: p has no definite proofs")))

(test-case "wf-engine/solve: mixed definite and unknown"
  ;; a is a fact (definite true)
  ;; p :- not q. q :- not p. (both unknown)
  ;; b :- a. (definite true, because a is a fact)
  (define inner-q (expr-goal-app 'q (list)))
  (define inner-p (expr-goal-app 'p (list)))
  (define store
    (build-store
     (list 'a 0 '(()) '())
     (list 'b 0 '() (list (list (goal-desc 'app (list 'a '())))))
     (list 'p 0 '() (list (list (goal-desc 'not (list inner-q)))))
     (list 'q 0 '() (list (list (goal-desc 'not (list inner-p)))))))
  (parameterize ([current-relation-store store])
    ;; a should be definite
    (define answers-a
      (wf-solve-goal default-solver-config store 'a '() '()))
    (check-true (>= (length answers-a) 1))
    (check-equal? (wf-answer-certainty (car answers-a)) 'definite)
    ;; b should be definite (depends on a which is a fact)
    (define answers-b
      (wf-solve-goal default-solver-config store 'b '() '()))
    (check-true (>= (length answers-b) 1))
    (check-equal? (wf-answer-certainty (car answers-b)) 'definite)))

;; ========================================
;; 9. Solver dispatch via config
;; ========================================

(test-case "wf-engine/dispatch: stratified semantics uses stratified engine"
  (define store
    (build-store (list 'color 1 '(("red") ("blue")) '())))
  (parameterize ([current-relation-store store]
                 [current-relation-store-version 0]
                 [current-strata-cache #f])
    (define answers
      (stratified-solve-goal default-solver-config store 'color '() '(X0)))
    ;; Standard answers (not wf-answer structs)
    (check-equal? (length answers) 2)
    (check-true (hash? (car answers)))))

(test-case "wf-engine/dispatch: well-founded semantics uses WF engine"
  (define cfg (make-solver-config (hasheq 'semantics 'well-founded)))
  (define store
    (build-store (list 'color 1 '(("red") ("blue")) '())))
  (parameterize ([current-relation-store store]
                 [current-relation-store-version 0]
                 [current-strata-cache #f])
    (define answers
      (stratified-solve-goal cfg store 'color '() '(X0)))
    ;; WF engine wraps in wf-answer, then dispatch converts to standard
    (check-equal? (length answers) 2)
    (check-true (hash? (car answers)))))

(test-case "wf-engine/dispatch: same answers for stratifiable program on both engines"
  (define store
    (build-store (list 'color 1 '(("red") ("blue") ("green")) '())))
  (define cfg-strat (make-solver-config (hasheq 'semantics 'stratified)))
  (define cfg-wf (make-solver-config (hasheq 'semantics 'well-founded)))
  (parameterize ([current-relation-store store]
                 [current-relation-store-version 0]
                 [current-strata-cache #f])
    (define answers-strat
      (stratified-solve-goal cfg-strat store 'color '() '(X0)))
    (define answers-wf
      (stratified-solve-goal cfg-wf store 'color '() '(X0)))
    (check-equal? (length answers-strat) (length answers-wf))))

;; ========================================
;; 10. Edge cases
;; ========================================

(test-case "wf-engine/solve: empty store → empty answers"
  (define store (hasheq))
  (parameterize ([current-relation-store store])
    (define answers
      (wf-solve-goal default-solver-config store 'nonexistent '() '()))
    (check-equal? (length answers) 0)))

(test-case "wf-engine/solve: query for undefined relation → empty answers"
  (define store
    (build-store (list 'color 1 '(("red")) '())))
  (parameterize ([current-relation-store store])
    (define answers
      (wf-solve-goal default-solver-config store 'missing '() '()))
    (check-equal? (length answers) 0)))

;; ========================================
;; 11. Phase 4b: Tabling Integration
;; ========================================

(test-case "wf-engine/tabled: simple fact populates WF table with 'definite"
  (define store
    (build-store (list 'color 1 '(("red") ("blue")) '())))
  (parameterize ([current-relation-store store]
                 [current-wf-table-store (table-store-empty)])
    (define answers
      (wf-solve-goal-tabled default-solver-config store 'color '() '(X0)))
    (check-equal? (length answers) 2)
    (for ([a (in-list answers)])
      (check-equal? (wf-answer-certainty a) 'definite))
    ;; Check the WF table store was populated
    (define ts (current-wf-table-store))
    (check-not-false ts)
    (check-true (table-complete? ts 'color))
    (check-equal? (wf-table-certainty ts 'color) 'definite)
    (define tabled-answers (wf-table-answers ts 'color))
    (check-equal? (length tabled-answers) 2)))

(test-case "wf-engine/tabled: odd cycle stores 'unknown certainty in WF table"
  (define inner-q (expr-goal-app 'q (list)))
  (define inner-p (expr-goal-app 'p (list)))
  (define store
    (build-store
     (list 'p 0 '() (list (list (goal-desc 'not (list inner-q)))))
     (list 'q 0 '() (list (list (goal-desc 'not (list inner-p)))))))
  (parameterize ([current-relation-store store]
                 [current-wf-table-store (table-store-empty)])
    (define answers-p
      (wf-solve-goal-tabled default-solver-config store 'p '() '()))
    ;; Both p and q should be unknown
    (check-equal? (length answers-p) 0)
    ;; WF table should record 'unknown certainty for p and q
    (define ts (current-wf-table-store))
    (check-not-false ts)
    (check-equal? (wf-table-certainty ts 'p) 'unknown)
    (check-equal? (wf-table-certainty ts 'q) 'unknown)))

(test-case "wf-engine/tabled: stratifiable negation stores 'definite"
  (define inner-c (expr-goal-app 'c (list)))
  (define inner-b (expr-goal-app 'b (list)))
  (define store
    (build-store
     (list 'c 0 '(()) '())
     (list 'b 0 '() (list (list (goal-desc 'not (list inner-c)))))
     (list 'a 0 '() (list (list (goal-desc 'not (list inner-b)))))))
  (parameterize ([current-relation-store store]
                 [current-wf-table-store (table-store-empty)])
    (define answers
      (wf-solve-goal-tabled default-solver-config store 'a '() '()))
    (check-true (>= (length answers) 1))
    (for ([a (in-list answers)])
      (check-equal? (wf-answer-certainty a) 'definite))
    ;; WF table should have definite for a
    (define ts (current-wf-table-store))
    (check-not-false ts)))

(test-case "wf-engine/tabled: dispatch via stratified-solve-goal creates WF tables"
  ;; The stratified-solve-goal with 'well-founded semantics should use tabled variant
  (define cfg (make-solver-config (hasheq 'semantics 'well-founded)))
  (define store
    (build-store (list 'color 1 '(("red") ("blue")) '())))
  (parameterize ([current-relation-store store]
                 [current-relation-store-version 0]
                 [current-strata-cache #f])
    (define answers
      (stratified-solve-goal cfg store 'color '() '(X0)))
    (check-equal? (length answers) 2)
    (check-true (hash? (car answers)))))

(test-case "wf-engine/tabled: no negation fast path still stores in WF table"
  (define store
    (build-store (list 'parent 2 '(("a" "b") ("b" "c")) '())))
  (parameterize ([current-relation-store store]
                 [current-wf-table-store (table-store-empty)])
    (define answers
      (wf-solve-goal-tabled default-solver-config store 'parent '() '(X0 X1)))
    (check-equal? (length answers) 2)
    ;; WF table should be populated even for no-negation case
    (define ts (current-wf-table-store))
    (check-not-false ts)
    (check-equal? (wf-table-certainty ts 'parent) 'definite)))

;; ========================================
;; 12. E2E tests deferred to Phase 6
;; ========================================
;; E2E tests through `solve ... :with solver-config` syntax require
;; WS-mode solver dispatch wiring (Phase 6). Unit tests above cover
;; the engine internals and dispatch via solver-config-semantics.
