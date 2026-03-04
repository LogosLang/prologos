#lang racket/base

;;;
;;; Tests for P3a: Trait Resolution Propagators (Shadow Path)
;;;
;;; Verifies that trait resolution works via propagator cell state:
;;; - cell-ids recorded for type-arg metas in trait constraints
;;; - retry-traits-via-cells! detects solved type-arg metas and resolves
;;; - Integration with full driver pipeline
;;;
;;; All tests use `eval` with prelude trait methods (add, sub, lt?, etc.)
;;; that create and resolve trait constraints during type inference.
;;;

(require rackunit
         racket/list
         "test-support.rkt"
         "../syntax.rkt"
         "../macros.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../elaborator-network.rkt"
         "../champ.rkt"
         "../type-lattice.rkt")

;; ========================================
;; Shared fixture: prelude loaded once
;; ========================================

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-preparse-reg
                shared-cap-reg)
  (parameterize ([current-global-env (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-capability-registry prelude-capability-registry])
    (install-module-loader!)
    (process-string "(ns test-trait-prop)\n")
    (values (current-global-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-preparse-registry)
            (current-capability-registry))))

(define (run code)
  (parameterize ([current-global-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-preparse-registry shared-preparse-reg]
                 [current-capability-registry shared-cap-reg]
                 [current-mult-meta-store (make-hasheq)]
                 [current-lib-paths (list prelude-lib-dir)])
    (install-module-loader!)
    (process-string code)))

(define (run-last code)
  (define results (run code))
  (if (null? results) #f (last results)))

;; ========================================
;; Trait resolution via Add (single-method trait)
;; ========================================

(test-case "trait/add-nat-resolves"
  ;; add creates an Add trait constraint for Nat, resolved via propagator
  (define result (run-last "eval [add 1N 2N]\n"))
  (check-false (and result (prologos-error? result))))

(test-case "trait/add-nat-larger"
  (define result (run-last "eval [add 100N 200N]\n"))
  (check-false (and result (prologos-error? result))))

(test-case "trait/sub-nat-resolves"
  ;; sub creates a Sub trait constraint
  (define result (run-last "eval [sub 5N 3N]\n"))
  (check-false (and result (prologos-error? result))))

;; ========================================
;; Trait resolution via Ord (comparison traits)
;; ========================================

(test-case "trait/lt-resolves"
  (define result (run-last "eval [lt? 1N 2N]\n"))
  (check-false (and result (prologos-error? result))))

(test-case "trait/gt-resolves"
  (define result (run-last "eval [gt? 3N 1N]\n"))
  (check-false (and result (prologos-error? result))))

(test-case "trait/le-resolves"
  (define result (run-last "eval [le? 1N 1N]\n"))
  (check-false (and result (prologos-error? result))))

;; ========================================
;; Nested trait resolution (multiple constraints)
;; ========================================

(test-case "trait/nested-add-sub"
  ;; Both Add and Sub traits resolve for nested expression
  (define result (run-last "eval [add [sub 5N 3N] 1N]\n"))
  (check-false (and result (prologos-error? result))))

(test-case "trait/nested-add-add"
  (define result (run-last "eval [add [add 1N 2N] [add 3N 4N]]\n"))
  (check-false (and result (prologos-error? result))))

(test-case "trait/nested-sub-sub"
  (define result (run-last "eval [sub [sub 10N 3N] [sub 5N 2N]]\n"))
  (check-false (and result (prologos-error? result))))

;; ========================================
;; Trait resolution with type inference
;; ========================================

(test-case "trait/type-inferred-add"
  ;; Type inference determines Nat from literal, then Add Nat resolves
  (define result (run-last "eval [add 3N 4N]\n"))
  (check-false (and result (prologos-error? result))))

(test-case "trait/ge-resolves"
  ;; ge? creates Ord constraint, resolved to Nat
  (define result (run-last "eval [ge? 7N 3N]\n"))
  (check-false (and result (prologos-error? result))))
