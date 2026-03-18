#lang racket/base

;;;
;;; test-unify-cell-driven.rkt — P-U2a: Cell-driven unification tests
;;;
;;; Tests that the propagator-backed unification engine correctly:
;;; 1. Detects contradictions via cell writes + quiescence (solve-flex-rigid)
;;; 2. Upgrades 'postponed → #t when quiescence resolves constraints (solve-flex-app)
;;; 3. Preserves correctness for basic meta solving through the cell path
;;;
;;; These tests exercise the full driver pipeline (with propagator network)
;;; rather than bare with-fresh-meta-env (which has no network).
;;;

(require racket/list
         racket/port
         rackunit
         "test-support.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../metavar-store.rkt"
         "../driver.rkt"
         "../global-env.rkt"
         "../errors.rkt")

;; ========================================
;; Test Helpers
;; ========================================

;; Run without prelude, suppress stderr, return all results.
(define (run-simple s)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-error-port (open-output-nowhere)])
    (process-string s)))

;; Run with prelude, suppress stderr, return last result.
(define (run-ns s)
  (parameterize ([current-error-port (open-output-nowhere)])
    (run-ns-last s)))

;; ========================================
;; Suite 1: Basic meta solving through cells
;; ========================================

(test-case "cell-driven: implicit arg solved via cell path"
  ;; The identity function's implicit type arg is solved via unification
  ;; which goes through solve-meta! → cell write → quiescence.
  (define result (run-ns "(ns test) (def id : <{A : Type} -> (a : A) -> A> [fn [x] x]) [id 0N]"))
  (check-false (prologos-error? result)))

(test-case "cell-driven: type mismatch detected after meta solve"
  ;; Annotated def with wrong type — solve-meta! for implicit arg
  ;; succeeds but the overall check fails.
  (define result (last (run-simple "(def x : Nat true)")))
  (check-true (prologos-error? result)))

(test-case "cell-driven: Pi unification solves domain + codomain metas"
  ;; Two Pi types with metas should unify, solving both domain and codomain.
  (define result (run-ns "(ns test) (def f : <(x : Nat) -> Nat> [fn [x] x]) [f 0N]"))
  (check-false (prologos-error? result)))

;; ========================================
;; Suite 2: Contradiction detection (P-U2a)
;; ========================================

(test-case "cell-driven: annotated def contradiction detected"
  ;; (def x : Nat true) — Bool vs Nat triggers contradiction
  ;; after meta solving inside the type checker.
  (define result (last (run-simple "(def x : Nat true)")))
  (check-true (type-mismatch-error? result)))

(test-case "cell-driven: union exhaustion contradiction"
  ;; No branch of the union matches — each solve attempt leads to contradiction.
  (define result (last (run-simple "(def x <Nat | Bool> \"hello\")")))
  (check-true (union-exhaustion-error? result)))

(test-case "cell-driven: multi-def no false contradiction"
  ;; Multiple successful defs should not trigger false contradictions.
  (define results (run-simple "(def x : Nat 0N) (def y : Bool true)"))
  (check-false (ormap prologos-error? results)))

(test-case "cell-driven: nested function types no false contradiction"
  ;; Multi-arg function: uncurried form with Prologos semantics.
  ;; (fn [x y] body) is multi-arg, not curried Nat→Nat→Nat.
  (define result (run-ns "(ns test) [add 1N 2N]"))
  (check-false (prologos-error? result)))

;; ========================================
;; Suite 3: Constraint postponement + resolution
;; ========================================

(test-case "cell-driven: postponed constraint resolved by later solve"
  ;; When an implicit arg can't be solved immediately but a later
  ;; unification provides the needed info, the constraint should resolve.
  (define result (run-ns "(ns test) (def id : <{A : Type} -> (a : A) -> A> [fn [x] x]) (def x : Nat [id 0N])"))
  (check-false (prologos-error? result)))

(test-case "cell-driven: list cons with implicit type arg"
  ;; List cons requires solving implicit type arg from the element type.
  (define result (run-ns "(ns test) (def xs : [List Nat] [cons 1N [cons 2N nil]])"))
  (check-false (prologos-error? result)))

;; ========================================
;; Suite 4: Regression — existing patterns still work
;; ========================================

(test-case "cell-driven: check command still works"
  (define result (last (run-simple "(check 0N : Nat)")))
  (check-equal? result "OK"))

(test-case "cell-driven: check command failure still reports"
  (define result (last (run-simple "(check true : Nat)")))
  (check-true (prologos-error? result)))

(test-case "cell-driven: unannotated def inference"
  (define result (last (run-simple "(def x 0N)")))
  (check-false (prologos-error? result)))

(test-case "cell-driven: higher-order function with metas"
  (define result (run-ns "(ns test) (def apply : <{A B : Type} -> (f : <(a : A) -> B>) -> (a : A) -> B> [fn [f x] [f x]]) [apply [fn [x] [add x 1N]] 5N]"))
  (check-false (prologos-error? result)))
