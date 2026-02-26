#lang racket/base

;;;
;;; Tests for relational language parsing (Phase 7)
;;; Sub-phase 7c: parse-defr, parse-rel, solve/explain, type constructors
;;;

(require rackunit
         "../parser.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt")

;; Helper: parse an s-expression string, return the surface AST
(define (p str) (parse-string str))

;; ========================================
;; Type constructors — bare atoms
;; ========================================

(test-case "parse Solver type atom"
  (define result (p "(check Solver : (Type 0))"))
  ;; The check form wraps the expression
  (check-true (surf-check? result))
  (check-true (surf-solver-type? (surf-check-expr result))))

(test-case "parse Goal type atom"
  (define result (p "(check Goal : (Type 0))"))
  (check-true (surf-check? result))
  (check-true (surf-goal-type? (surf-check-expr result))))

(test-case "parse DerivationTree type atom"
  (define result (p "(check DerivationTree : (Type 0))"))
  (check-true (surf-check? result))
  (check-true (surf-derivation-type? (surf-check-expr result))))

(test-case "parse Answer type atom — bare"
  (define result (p "(check Answer : (Type 0))"))
  (check-true (surf-check? result))
  (check-true (surf-answer-type? (surf-check-expr result)))
  (check-false (surf-answer-type-val-type (surf-check-expr result))))

(test-case "parse Answer type atom — parameterized"
  (define result (p "(eval (Answer Int))"))
  (check-true (surf-eval? result))
  (define inner (surf-eval-expr result))
  (check-true (surf-answer-type? inner))
  (check-true (surf-int-type? (surf-answer-type-val-type inner))))

;; ========================================
;; solve / solve-one / explain
;; ========================================

(test-case "parse (solve expr) — basic"
  (define result (p "(eval (solve x))"))
  (check-true (surf-eval? result))
  (define inner (surf-eval-expr result))
  (check-true (surf-solve? inner))
  (check-true (surf-var? (surf-solve-goal inner))))

(test-case "parse solve — arity error"
  ;; Errors propagate up — the whole form becomes an error
  (define result (p "(eval (solve))"))
  (check-true (prologos-error? result)))

(test-case "parse (solve-one expr)"
  (define result (p "(eval (solve-one (parent x y)))"))
  (check-true (surf-eval? result))
  ;; solve-one reuses surf-solve
  (define inner (surf-eval-expr result))
  (check-true (surf-solve? inner)))

(test-case "parse (explain expr)"
  (define result (p "(eval (explain (parent x y)))"))
  (check-true (surf-eval? result))
  (define inner (surf-eval-expr result))
  (check-true (surf-explain? inner)))

(test-case "parse (solve-with solver (goal))"
  (define result (p "(eval (solve-with my-solver (parent x y)))"))
  (check-true (surf-eval? result))
  (define inner (surf-eval-expr result))
  (check-true (surf-solve-with? inner))
  ;; solver should be the first arg
  (check-true (surf-var? (surf-solve-with-solver inner)))
  ;; no overrides
  (check-false (surf-solve-with-overrides inner))
  ;; goal is now a relational goal-app (not surf-app, since solve-with parses goals relationally)
  (check-true (surf-goal-app? (surf-solve-with-goal inner))))

(test-case "parse (explain-with solver (goal))"
  (define result (p "(eval (explain-with debug (parent x y)))"))
  (check-true (surf-eval? result))
  (define inner (surf-eval-expr result))
  (check-true (surf-explain-with? inner))
  (check-true (surf-var? (surf-explain-with-solver inner)))
  (check-false (surf-explain-with-overrides inner)))

;; ========================================
;; defr — single-arity
;; ========================================

(test-case "parse defr — single-arity with fact block"
  (define result (p "(defr parent [?x ?y] || \"alice\" \"bob\")"))
  (check-true (surf-defr? result))
  (check-equal? (surf-defr-name result) 'parent)
  (check-false (surf-defr-schema result))
  (define variants (surf-defr-variants result))
  (check-equal? (length variants) 1)
  (define v (car variants))
  (check-true (surf-defr-variant? v))
  ;; Params should have mode annotations extracted
  (define params (surf-defr-variant-params v))
  (check-equal? (length params) 2)
  ;; ?x → (x . free)
  (check-equal? (car (car params)) 'x)
  (check-equal? (cdr (car params)) 'free)
  (check-equal? (car (cadr params)) 'y)
  (check-equal? (cdr (cadr params)) 'free)
  ;; Body should contain a facts block
  (define body (surf-defr-variant-body v))
  (check-equal? (length body) 1)
  (check-true (surf-facts? (car body))))

(test-case "parse defr — single-arity with clause"
  (define result (p "(defr ancestor [?x ?y] &> (parent x y))"))
  (check-true (surf-defr? result))
  (check-equal? (surf-defr-name result) 'ancestor)
  (define v (car (surf-defr-variants result)))
  (define body (surf-defr-variant-body v))
  (check-equal? (length body) 1)
  (check-true (surf-clause? (car body))))

(test-case "parse defr — bare goals (no sentinel)"
  ;; Without &> or ||, goals are treated as implicit clause
  (define result (p "(defr test-rel [x y] (some-goal x y))"))
  (check-true (surf-defr? result))
  (define v (car (surf-defr-variants result)))
  (define body (surf-defr-variant-body v))
  (check-equal? (length body) 1)
  (check-true (surf-clause? (car body))))

(test-case "parse defr — mode annotations"
  (define result (p "(defr lookup [+key -val] &> (table key val))"))
  (check-true (surf-defr? result))
  (define params (surf-defr-variant-params (car (surf-defr-variants result))))
  ;; +key → (key . in)
  (check-equal? (car (car params)) 'key)
  (check-equal? (cdr (car params)) 'in)
  ;; -val → (val . out)
  (check-equal? (car (cadr params)) 'val)
  (check-equal? (cdr (cadr params)) 'out))

(test-case "parse defr — bare params (no mode)"
  (define result (p "(defr simple [a b] &> (rel1 a b))"))
  (check-true (surf-defr? result))
  (define params (surf-defr-variant-params (car (surf-defr-variants result))))
  ;; bare a → (a . #f)
  (check-equal? (car (car params)) 'a)
  (check-false (cdr (car params))))

;; ========================================
;; rel — anonymous relation
;; ========================================

(test-case "parse rel — anonymous with clause"
  (define result (p "(eval (rel [?x] &> (some-goal x)))"))
  (check-true (surf-eval? result))
  (define inner (surf-eval-expr result))
  (check-true (surf-rel? inner))
  (define params (surf-rel-params inner))
  (check-equal? (length params) 1)
  (check-equal? (car (car params)) 'x)
  (check-equal? (cdr (car params)) 'free))

(test-case "parse rel — anonymous with facts"
  (define result (p "(eval (rel [?x ?y] || \"a\" \"b\"))"))
  (check-true (surf-eval? result))
  (define inner (surf-eval-expr result))
  (check-true (surf-rel? inner))
  (define clauses (surf-rel-clauses inner))
  (check-equal? (length clauses) 1)
  (check-true (surf-facts? (car clauses))))

;; ========================================
;; solver / schema — pre-parse forms
;; ========================================

(test-case "parse solver — error (should be pre-expanded)"
  (define result (p "(solver my-solver :execution :parallel)"))
  (check-true (prologos-error? result)))

(test-case "parse schema — error (should be pre-expanded)"
  (define result (p "(schema Person :name String :age Nat)"))
  (check-true (prologos-error? result)))

;; ========================================
;; Relational goal context — goals inside clauses
;; ========================================

(test-case "parse defr clause goals → surf-goal-app"
  ;; Goals inside &> clauses should be surf-goal-app, not surf-app
  (define result (p "(defr ancestor [?x ?y] &> (parent x y))"))
  (check-true (surf-defr? result))
  (define clause (car (surf-defr-variant-body (car (surf-defr-variants result)))))
  (check-true (surf-clause? clause))
  (define goals (surf-clause-goals clause))
  (check-equal? (length goals) 1)
  (define goal (car goals))
  (check-true (surf-goal-app? goal))
  (check-equal? (surf-goal-app-name goal) 'parent)
  (check-equal? (length (surf-goal-app-args goal)) 2)
  ;; Args should be surf-var (logic variable references)
  (check-true (surf-var? (car (surf-goal-app-args goal))))
  (check-true (surf-var? (cadr (surf-goal-app-args goal)))))

(test-case "parse defr clause conjunction → multiple surf-goal-app"
  (define result (p "(defr ancestor [?x ?y] &> (parent x z) (ancestor z y))"))
  (define clause (car (surf-defr-variant-body (car (surf-defr-variants result)))))
  (define goals (surf-clause-goals clause))
  (check-equal? (length goals) 2)
  (check-true (surf-goal-app? (car goals)))
  (check-equal? (surf-goal-app-name (car goals)) 'parent)
  (check-true (surf-goal-app? (cadr goals)))
  (check-equal? (surf-goal-app-name (cadr goals)) 'ancestor))

(test-case "parse (= x y) in relational context → surf-unify"
  (define result (p "(defr test-rel [?x ?y] &> (= x y))"))
  (define clause (car (surf-defr-variant-body (car (surf-defr-variants result)))))
  (define goals (surf-clause-goals clause))
  (check-equal? (length goals) 1)
  (check-true (surf-unify? (car goals))))

(test-case "parse (is var [expr]) in relational context → surf-is"
  (define result (p "(defr test-rel [?x ?y ?z] &> (is z (+ x y)))"))
  (define clause (car (surf-defr-variant-body (car (surf-defr-variants result)))))
  (define goals (surf-clause-goals clause))
  (check-equal? (length goals) 1)
  (check-true (surf-is? (car goals))))

(test-case "parse (not (goal)) in relational context → surf-not"
  (define result (p "(defr test-rel [?x] &> (not (bad x)))"))
  (define clause (car (surf-defr-variant-body (car (surf-defr-variants result)))))
  (define goals (surf-clause-goals clause))
  (check-equal? (length goals) 1)
  (check-true (surf-not? (car goals)))
  ;; Inner goal should be surf-goal-app
  (check-true (surf-goal-app? (surf-not-goal (car goals)))))

(test-case "parse (solve (goal)) → surf-solve with surf-goal-app inside"
  (define result (p "(eval (solve (parent x y)))"))
  (define inner (surf-eval-expr result))
  (check-true (surf-solve? inner))
  (define goal (surf-solve-goal inner))
  (check-true (surf-goal-app? goal))
  (check-equal? (surf-goal-app-name goal) 'parent))

(test-case "parse (= x y) outside relational context → surf-app (generic equality)"
  ;; Outside relational context, = is a generic equality operator
  (define result (p "(eval (= a b))"))
  (define inner (surf-eval-expr result))
  ;; Should be a function application, not surf-unify
  (check-true (surf-app? inner)))

;; ========================================
;; Error cases
;; ========================================

(test-case "parse defr — missing name"
  ;; (defr) with no args
  (define result (p "(defr)"))
  (check-true (prologos-error? result)))

(test-case "parse solve-with — too few args"
  ;; Errors propagate up — the whole form becomes an error
  (define result (p "(eval (solve-with x))"))
  (check-true (prologos-error? result)))
