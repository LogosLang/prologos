#lang racket/base

;;;
;;; test-solver-parity.rkt — DFS↔ATMS Parity Regression Suite
;;;
;;; Phase T-c: Permanent regression tests ensuring DFS and ATMS strategies
;;; produce identical results for the same queries. Each test case exercises
;;; a specific divergence class identified during Phase T-a investigation.
;;;
;;; Structure: manual stores → stratified-solve-goal with both strategy
;;; overrides → set-equal? comparison on results.
;;;

(require rackunit
         racket/set
         "../solver.rkt"
         "../relations.rkt"
         "../stratified-eval.rkt"
         "../syntax.rkt")

;; ========================================
;; Helpers
;; ========================================

;; Build a relation store from specs.
;; Each spec: (name arity facts clauses)
;; facts: list of (list val ...) — one per fact row
;; clauses: list of (list goal-desc ...) — one per clause body
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

(define cfg-dfs (make-solver-config (hasheq 'strategy 'depth-first)))
(define cfg-atms (make-solver-config (hasheq 'strategy 'atms)))

;; Run a query under both strategies, return (values dfs-results atms-results).
;; Both use stratified semantics. The strategy override forces the execution path.
(define (parity-query store goal-name query-vars [goal-args '()])
  (parameterize ([current-relation-store store]
                 [current-relation-store-version 0]
                 [current-strata-cache #f])
    (define dfs
      (parameterize ([current-solver-strategy-override 'depth-first])
        (stratified-solve-goal cfg-dfs store goal-name goal-args query-vars)))
    (define atms
      (parameterize ([current-solver-strategy-override 'atms])
        (stratified-solve-goal cfg-atms store goal-name goal-args query-vars)))
    (values dfs atms)))

;; Normalize a result hasheq: for unresolved variables (value is a symbol,
;; not a string/number/boolean), replace with the query var name itself.
;; DFS returns unresolved vars as the query var name (X0→X0).
;; ATMS may return them as gensym'd internal names (X0→X0_g1025).
;; Both mean "unresolved" — normalize to the query var name for comparison.
(define (normalize-result result query-vars)
  (for/hasheq ([(k v) (in-hash result)])
    (values k (if (and (symbol? v) (not (memq v query-vars)))
                  k  ;; unresolved: normalize to query var name
                  v))))

;; Assert set-equal results between DFS and ATMS.
;; Normalizes unresolved vars, converts to sets for order-independent comparison.
(define (check-parity store goal-name query-vars [msg ""] [goal-args '()])
  (define-values (dfs atms) (parity-query store goal-name query-vars goal-args))
  (define dfs-norm (map (lambda (r) (normalize-result r query-vars)) dfs))
  (define atms-norm (map (lambda (r) (normalize-result r query-vars)) atms))
  (define dfs-set (list->set dfs-norm))
  (define atms-set (list->set atms-norm))
  (check-equal? dfs-set atms-set
                (format "~a: DFS ~a results vs ATMS ~a results"
                        msg (length dfs) (length atms))))

;; ========================================
;; 1. Tier 1: Fact-only queries (trivially identical)
;; ========================================

(test-case "parity/fact-single: single fact, one query var"
  (define store (build-store (list 'color 1 '(("red") ("blue") ("green")) '())))
  (check-parity store 'color '(X0) "single-fact"))

(test-case "parity/fact-multi-arg: 2-arity facts"
  (define store
    (build-store (list 'edge 2 '(("a" "b") ("b" "c") ("c" "a")) '())))
  (check-parity store 'edge '(X0 X1) "multi-arg facts"))

(test-case "parity/fact-bound-arg: fact query with bound argument"
  (define store
    (build-store (list 'parent 2 '(("alice" "bob") ("alice" "carol") ("dave" "eve")) '())))
  (check-parity store 'parent '(X1) "bound arg" '("alice" X1)))

;; ========================================
;; 2. Single clause, no NAF
;; ========================================

(test-case "parity/clause-simple: single clause with positive body"
  (define store
    (build-store
     (list 'base 1 '(("x") ("y")) '())
     (list 'derived 1 '()
           (list (list (goal-desc 'app (list 'base '(X0))))))))
  (check-parity store 'derived '(X0) "simple clause"))

;; ========================================
;; 3. Multi-clause (ATMS parallel PU branching)
;; ========================================

(test-case "parity/multi-clause: multiple clauses, same relation"
  (define store
    (build-store
     (list 'a 1 '(("x")) '())
     (list 'b 1 '(("y")) '())
     (list 'either 1 '()
           (list (list (goal-desc 'app (list 'a '(X0))))
                 (list (goal-desc 'app (list 'b '(X0))))))))
  (check-parity store 'either '(X0) "multi-clause"))

;; ========================================
;; 4. NAF with ground args
;; ========================================

(test-case "parity/naf-ground-succeeds: not(P) where P is not provable"
  ;; bad has fact ("evil"). not(bad("alice")) should succeed.
  (define inner-bad (expr-goal-app 'bad (list "alice")))
  (define store
    (build-store
     (list 'bad 1 '(("evil")) '())
     (list 'ok 0 '() (list (list (goal-desc 'not (list inner-bad)))))))
  (check-parity store 'ok '() "naf-ground-succeeds"))

(test-case "parity/naf-ground-fails: not(P) where P is provable"
  ;; bad has fact ("evil"). not(bad("evil")) should fail.
  (define inner-bad (expr-goal-app 'bad (list "evil")))
  (define store
    (build-store
     (list 'bad 1 '(("evil")) '())
     (list 'fails 0 '() (list (list (goal-desc 'not (list inner-bad)))))))
  (check-parity store 'fails '() "naf-ground-fails"))

;; ========================================
;; 5. Multi-strata NAF chains
;; ========================================

(test-case "parity/naf-2-strata: a :- not b. b."
  ;; b is true → not b fails → a has 0 results
  (define inner-b (expr-goal-app 'b '()))
  (define store
    (build-store
     (list 'b 0 '(()) '())
     (list 'a 0 '() (list (list (goal-desc 'not (list inner-b)))))))
  (check-parity store 'a '() "2-strata"))

(test-case "parity/naf-3-strata: c :- not b. b :- not a. a."
  ;; a=true, b=false (not a fails), c=true (not b succeeds)
  (define inner-a (expr-goal-app 'a '()))
  (define inner-b (expr-goal-app 'b '()))
  (define store
    (build-store
     (list 'a 0 '(()) '())
     (list 'b 0 '() (list (list (goal-desc 'not (list inner-a)))))
     (list 'c 0 '() (list (list (goal-desc 'not (list inner-b)))))))
  (check-parity store 'c '() "3-strata")
  ;; Also verify the count
  (define-values (dfs atms) (parity-query store 'c '()))
  (check-equal? (length dfs) 1 "c should have 1 result")
  (check-equal? (length atms) 1 "c should have 1 result (ATMS)"))

;; ========================================
;; 6. Guard goals
;; ========================================

(test-case "parity/guard-succeeds: guard(true) passes"
  (define store
    (build-store
     (list 'guarded 0 '()
           (list (list (goal-desc 'guard (list #t)))))))
  (check-parity store 'guarded '() "guard-succeeds"))

;; ========================================
;; 7. Mixed positive + NAF (safe-edge pattern)
;; ========================================

(test-case "parity/mixed-positive-naf: edge(x,y), not(edge(y,x))"
  ;; safe-edge: has positive goal (binds vars) + NAF (filters)
  (define inner-edge-yx (expr-goal-app 'edge (list 'X1 'X0)))
  (define store
    (build-store
     (list 'edge 2 '(("a" "b") ("b" "c")) '())
     (list 'safe-edge 2 '()
           (list (list (goal-desc 'app (list 'edge '(X0 X1)))
                       (goal-desc 'not (list inner-edge-yx)))))))
  (check-parity store 'safe-edge '(X0 X1) "mixed-positive-naf")
  ;; Verify count
  (define-values (dfs atms) (parity-query store 'safe-edge '(X0 X1)))
  (check-equal? (length dfs) 2 "safe-edge should have 2 results")
  (check-equal? (length atms) 2 "safe-edge should have 2 results (ATMS)"))

;; ========================================
;; 8. Gating-only body (NAF as entire clause body)
;; ========================================

(test-case "parity/gating-only-0-arity: c :- not(bad)"
  ;; 0-arity, body is only NAF, inner goal fails → NAF succeeds
  (define inner-bad (expr-goal-app 'bad '()))
  (define store
    (build-store
     (list 'bad 0 '() '())  ;; defined but no facts
     (list 'ok 0 '() (list (list (goal-desc 'not (list inner-bad)))))))
  (check-parity store 'ok '() "gating-only-0-arity")
  (define-values (dfs atms) (parity-query store 'ok '()))
  (check-equal? (length dfs) 1 "gating-only 0-arity should succeed"))

(test-case "parity/gating-only-with-vars: check-ok(x) :- not(bad(val))"
  ;; N-arity, body is only NAF, query has free var
  (define inner-bad (expr-goal-app 'bad (list "alice")))
  (define store
    (build-store
     (list 'bad 1 '(("evil")) '())
     (list 'check-ok 1 '()
           (list (list (goal-desc 'not (list inner-bad)))))))
  (check-parity store 'check-ok '(X0) "gating-only-with-vars"))

;; ========================================
;; 9. Undefined relation in NAF target (should error in both)
;; ========================================

(test-case "parity/undefined-naf-target: both strategies error"
  (define inner-missing (expr-goal-app 'missing '()))
  (define store
    (build-store
     (list 'a 0 '()
           (list (list (goal-desc 'not (list inner-missing)))))))
  (parameterize ([current-relation-store store]
                 [current-relation-store-version 0]
                 [current-strata-cache #f])
    ;; DFS should error
    (check-exn exn:fail?
      (lambda ()
        (parameterize ([current-solver-strategy-override 'depth-first])
          (stratified-solve-goal cfg-dfs store 'a '() '()))))
    ;; ATMS should also error (Phase T-a fix)
    (check-exn exn:fail?
      (lambda ()
        (parameterize ([current-solver-strategy-override 'atms])
          (stratified-solve-goal cfg-atms store 'a '() '()))))))

;; ========================================
;; 10. Multi-fact with bound argument narrowing
;; ========================================

(test-case "parity/narrowing: bound arg narrows fact rows"
  (define store
    (build-store
     (list 'fact8 1
           '(("a") ("b") ("c") ("d") ("e") ("f") ("g") ("h"))
           '())))
  ;; Query all
  (check-parity store 'fact8 '(X0) "all-facts")
  (define-values (dfs atms) (parity-query store 'fact8 '(X0)))
  (check-equal? (length dfs) 8)
  ;; Query with bound arg
  (check-parity store 'fact8 '() "bound-fact" '("c"))
  (define-values (dfs2 atms2) (parity-query store 'fact8 '() '("c")))
  (check-equal? (length dfs2) 1))
