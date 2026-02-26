#lang racket/base

;;;
;;; Tests for Phase 7 Relational Language — type-level integration
;;; Covers: type formation, infer, check, QTT, substitution, pretty-print, elaboration
;;;

(require racket/string
         rackunit
         "../syntax.rkt"
         "../prelude.rkt"
         "../substitution.rkt"
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../pretty-print.rkt"
         "../qtt.rkt"
         "../global-env.rkt"
         "../elaborator.rkt"
         "../surface-syntax.rkt"
         "../source-location.rkt"
         "../errors.rkt"
         "../solver.rkt")

;; ========================================
;; Type formation: type constructors
;; ========================================

(test-case "Solver type formation"
  (check-equal? (tc:infer ctx-empty (expr-solver-type))
                (expr-Type (lzero))
                "Solver : Type 0")
  (check-true (tc:is-type ctx-empty (expr-solver-type))
              "Solver is a type"))

(test-case "Goal type formation"
  (check-equal? (tc:infer ctx-empty (expr-goal-type))
                (expr-Type (lzero))
                "Goal : Type 0")
  (check-true (tc:is-type ctx-empty (expr-goal-type))
              "Goal is a type"))

(test-case "DerivationTree type formation"
  (check-equal? (tc:infer ctx-empty (expr-derivation-type))
                (expr-Type (lzero))
                "DerivationTree : Type 0")
  (check-true (tc:is-type ctx-empty (expr-derivation-type))
              "DerivationTree is a type"))

(test-case "Answer type formation (bare)"
  (check-equal? (tc:infer ctx-empty (expr-answer-type #f))
                (expr-Type (lzero))
                "Answer : Type 0"))

(test-case "Answer type formation (parameterized)"
  (check-equal? (tc:infer ctx-empty (expr-answer-type (expr-Int)))
                (expr-Type (lzero))
                "(Answer Int) : Type 0"))

(test-case "Relation type formation"
  (check-equal? (tc:infer ctx-empty (expr-relation-type '()))
                (expr-Type (lzero))
                "Relation type : Type 0"))

(test-case "Schema type formation"
  (check-equal? (tc:infer ctx-empty (expr-schema-type 'Person))
                (expr-Type (lzero))
                "(Schema Person) : Type 0"))

;; ========================================
;; Runtime wrapper: solver-config
;; ========================================

(test-case "solver-config check against Solver"
  (check-true (tc:check ctx-empty
                (expr-solver-config (make-solver-config))
                (expr-solver-type))
              "solver-config checks against Solver"))

(test-case "solver-config infer → Solver"
  (check-equal? (tc:infer ctx-empty
                  (expr-solver-config (make-solver-config)))
                (expr-solver-type)
                "solver-config infers as Solver"))

;; ========================================
;; Operation type inference
;; ========================================

(test-case "solve infers as hole (type-unsafe)"
  (check-equal? (tc:infer ctx-empty
                  (expr-solve (expr-goal-type)))
                (expr-hole)))

(test-case "solve-one infers as hole (type-unsafe)"
  (check-equal? (tc:infer ctx-empty
                  (expr-solve-one (expr-goal-type)))
                (expr-hole)))

(test-case "solve-with infers as hole"
  (check-equal? (tc:infer ctx-empty
                  (expr-solve-with (expr-solver-config (make-solver-config))
                                   #f
                                   (expr-goal-type)))
                (expr-hole)))

(test-case "explain infers as hole (type-unsafe)"
  (check-equal? (tc:infer ctx-empty
                  (expr-explain (expr-goal-type)))
                (expr-hole)))

(test-case "explain-with infers as hole"
  (check-equal? (tc:infer ctx-empty
                  (expr-explain-with (expr-solver-config (make-solver-config))
                                     #f
                                     (expr-goal-type)))
                (expr-hole)))

(test-case "clause infers as Goal"
  (check-equal? (tc:infer ctx-empty
                  (expr-clause '()))
                (expr-goal-type)))

(test-case "fact-block infers as Goal"
  (check-equal? (tc:infer ctx-empty
                  (expr-fact-block '()))
                (expr-goal-type)))

(test-case "goal-app infers as Goal"
  (check-equal? (tc:infer ctx-empty
                  (expr-goal-app 'parent '()))
                (expr-goal-type)))

(test-case "unify-goal infers as Goal"
  (check-equal? (tc:infer ctx-empty
                  (expr-unify-goal (expr-true) (expr-true)))
                (expr-goal-type)))

(test-case "is-goal infers as Goal"
  (check-equal? (tc:infer ctx-empty
                  (expr-is-goal (expr-true) (expr-true)))
                (expr-goal-type)))

(test-case "not-goal infers as Goal"
  (check-equal? (tc:infer ctx-empty
                  (expr-not-goal (expr-goal-type)))
                (expr-goal-type)))

(test-case "cut infers as Goal"
  (check-equal? (tc:infer ctx-empty (expr-cut))
                (expr-goal-type)))

(test-case "guard infers as Goal"
  (check-equal? (tc:infer ctx-empty
                  (expr-guard (expr-true) (expr-cut)))
                (expr-goal-type)))

(test-case "defr infers as hole (type-unsafe)"
  (check-equal? (tc:infer ctx-empty
                  (expr-defr 'test #f '()))
                (expr-hole)))

(test-case "rel infers as hole (type-unsafe)"
  (check-equal? (tc:infer ctx-empty
                  (expr-rel '() '()))
                (expr-hole)))

(test-case "schema infers as schema-type"
  (check-equal? (tc:infer ctx-empty
                  (expr-schema 'Person '()))
                (expr-schema-type 'Person)))

;; ========================================
;; QTT inferQ
;; ========================================

(test-case "QTT: Solver type has zero usage"
  (check-equal? (inferQ ctx-empty (expr-solver-type))
                (tu (expr-Type (lzero)) '())))

(test-case "QTT: Goal type has zero usage"
  (check-equal? (inferQ ctx-empty (expr-goal-type))
                (tu (expr-Type (lzero)) '())))

(test-case "QTT: DerivationTree type has zero usage"
  (check-equal? (inferQ ctx-empty (expr-derivation-type))
                (tu (expr-Type (lzero)) '())))

(test-case "QTT: cut has zero usage"
  (check-equal? (inferQ ctx-empty (expr-cut))
                (tu (expr-goal-type) '())))

(test-case "QTT: solver-config wrapper has zero usage"
  (check-equal? (inferQ ctx-empty (expr-solver-config (make-solver-config)))
                (tu (expr-solver-type) '())))

;; ========================================
;; Substitution round-trip
;; ========================================

(test-case "shift on Solver type constructor"
  (check-equal? (shift 1 0 (expr-solver-type)) (expr-solver-type)))

(test-case "shift on Goal type constructor"
  (check-equal? (shift 1 0 (expr-goal-type)) (expr-goal-type)))

(test-case "shift on DerivationTree type constructor"
  (check-equal? (shift 1 0 (expr-derivation-type)) (expr-derivation-type)))

(test-case "shift on cut"
  (check-equal? (shift 1 0 (expr-cut)) (expr-cut)))

(test-case "shift on solve recurses into goal"
  (let ([e (expr-solve (expr-bvar 0))])
    (check-equal? (shift 1 0 e)
                  (expr-solve (expr-bvar 1)))))

(test-case "shift on explain-with recurses into fields"
  (let ([e (expr-explain-with (expr-bvar 0) #f (expr-bvar 1))])
    (check-equal? (shift 1 0 e)
                  (expr-explain-with (expr-bvar 1) #f (expr-bvar 2)))))

(test-case "subst on solve-with recurses into fields"
  (let ([e (expr-solve-with (expr-bvar 0) #f (expr-bvar 1))])
    (check-equal? (subst 0 (expr-solver-type) e)
                  (expr-solve-with (expr-solver-type) #f (expr-bvar 0)))))

;; ========================================
;; Pretty-print
;; ========================================

(test-case "pp-expr: Solver"
  (check-equal? (pp-expr (expr-solver-type) '()) "Solver"))

(test-case "pp-expr: Goal"
  (check-equal? (pp-expr (expr-goal-type) '()) "Goal"))

(test-case "pp-expr: DerivationTree"
  (check-equal? (pp-expr (expr-derivation-type) '()) "DerivationTree"))

(test-case "pp-expr: solve"
  (check-true (string-contains?
               (pp-expr (expr-solve (expr-goal-type)) '())
               "solve")))

(test-case "pp-expr: explain"
  (check-true (string-contains?
               (pp-expr (expr-explain (expr-goal-type)) '())
               "explain")))

(test-case "pp-expr: defr"
  (check-true (string-contains?
               (pp-expr (expr-defr 'parent #f '()) '())
               "defr")))

;; ========================================
;; Elaboration: surf-* → expr-*
;; ========================================

(test-case "elaborate: solver-type"
  (define result (elaborate (surf-solver-type srcloc-unknown)))
  (check-true (expr-solver-type? result)))

(test-case "elaborate: goal-type"
  (define result (elaborate (surf-goal-type srcloc-unknown)))
  (check-true (expr-goal-type? result)))

(test-case "elaborate: derivation-type"
  (define result (elaborate (surf-derivation-type srcloc-unknown)))
  (check-true (expr-derivation-type? result)))

(test-case "elaborate: answer-type (bare)"
  (define result (elaborate (surf-answer-type #f srcloc-unknown)))
  (check-true (expr-answer-type? result))
  (check-false (expr-answer-type-val-type result)))

(test-case "elaborate: answer-type (parameterized)"
  (define result (elaborate (surf-answer-type (surf-int-type srcloc-unknown) srcloc-unknown)))
  (check-true (expr-answer-type? result))
  (check-true (expr-Int? (expr-answer-type-val-type result))))

(test-case "elaborate: solve — unbound vars become free query variables"
  (define result (elaborate (surf-solve (surf-var 'x srcloc-unknown) srcloc-unknown)))
  ;; x is unbound but solve enables relational-fallback: x becomes expr-logic-var
  (check-true (expr-solve? result))
  (check-true (expr-logic-var? (expr-solve-goal result)))
  (check-equal? (expr-logic-var-name (expr-solve-goal result)) 'x)
  (check-equal? (expr-logic-var-mode (expr-solve-goal result)) 'free))

(test-case "elaborate: clause (empty)"
  (define result (elaborate (surf-clause '() srcloc-unknown)))
  (check-true (expr-clause? result))
  (check-equal? (expr-clause-goals result) '()))

(test-case "elaborate: facts (empty)"
  (define result (elaborate (surf-facts '() srcloc-unknown)))
  (check-true (expr-fact-block? result))
  (check-equal? (expr-fact-block-rows result) '()))

(test-case "elaborate: goal-app (no args)"
  (define result (elaborate (surf-goal-app 'parent '() srcloc-unknown)))
  (check-true (expr-goal-app? result))
  (check-equal? (expr-goal-app-name result) 'parent)
  (check-equal? (expr-goal-app-args result) '()))

(test-case "elaborate: unify with literals"
  (define result (elaborate (surf-unify (surf-true srcloc-unknown)
                                        (surf-false srcloc-unknown)
                                        srcloc-unknown)))
  (check-true (expr-unify-goal? result))
  (check-true (expr-true? (expr-unify-goal-lhs result)))
  (check-true (expr-false? (expr-unify-goal-rhs result))))

(test-case "elaborate: defr (empty variants)"
  (define result (elaborate (surf-defr 'test #f '() srcloc-unknown)))
  (check-true (expr-defr? result))
  (check-equal? (expr-defr-name result) 'test)
  (check-false (expr-defr-schema result))
  (check-equal? (expr-defr-variants result) '()))

(test-case "elaborate: rel (empty)"
  (define result (elaborate (surf-rel '() '() srcloc-unknown)))
  (check-true (expr-rel? result))
  (check-equal? (expr-rel-params result) '())
  (check-equal? (expr-rel-clauses result) '()))

;; ========================================
;; Reduction: structural self-values
;; ========================================

(test-case "whnf: Solver type is self-value"
  (check-equal? (whnf (expr-solver-type)) (expr-solver-type)))

(test-case "whnf: Goal type is self-value"
  (check-equal? (whnf (expr-goal-type)) (expr-goal-type)))

(test-case "whnf: cut is self-value"
  (check-equal? (whnf (expr-cut)) (expr-cut)))

(test-case "whnf: defr is self-value"
  (check-equal? (whnf (expr-defr 'test #f '()))
                (expr-defr 'test #f '())))

(test-case "whnf: solve is self-value"
  (check-equal? (whnf (expr-solve (expr-goal-type)))
                (expr-solve (expr-goal-type))))

(test-case "nf: solver-type is self-value"
  (check-equal? (nf (expr-solver-type)) (expr-solver-type)))

(test-case "nf: solve recurses into goal"
  (check-equal? (nf (expr-solve (expr-goal-type)))
                (expr-solve (expr-goal-type))))
