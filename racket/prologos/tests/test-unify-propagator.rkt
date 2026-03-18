#lang racket/base

;;;
;;; Tests for P1-G2/G3: Propagator-Aware Unification (unify*)
;;;
;;; Verifies that unify* has identical behavior to unify for structural
;;; cases, and correctly detects network contradictions.
;;;

(require rackunit
         racket/list
         "test-support.rkt"
         "../syntax.rkt"
         "../macros.rkt"
         "../errors.rkt"
         "../prelude.rkt"
         "../metavar-store.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../unify.rkt"
         "../elaborator-network.rkt"
         "../mult-lattice.rkt"
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
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
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
    (process-string "(ns test-unify-prop)\n")
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-preparse-registry)
            (current-capability-registry))))

(define (run code)
  (parameterize ([current-prelude-env shared-global-env]
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
;; P1-G2: Integration tests — unify* parity with unify
;; ========================================
;; These run through the full driver pipeline which uses unify (not unify* yet).
;; We verify the infrastructure doesn't break anything.

(test-case "g2/add-works-with-propagator-infra"
  ;; Trait resolution + unification through propagator network
  (define result (run-last "eval [add 1N 2N]\n"))
  (check-false (and result (prologos-error? result))))

(test-case "g2/nested-fn-app-no-error"
  (define result (run-last "eval [add [sub 10N 3N] 4N]\n"))
  (check-false (and result (prologos-error? result))))

(test-case "g2/polymorphic-id-no-error"
  (define result (run-last "(def id : (Pi (A : (Type 0)) (Pi (x : A) A)) (fn [A] [x] x))\n"))
  (check-false (and result (prologos-error? result))))

(test-case "g2/type-mismatch-detected"
  ;; Nat function applied to Bool should produce a type error
  (define result (run-last "(the Nat (fn [x] x))\n"))
  (check-true (and result (prologos-error? result))))

;; ========================================
;; P1-G2: Direct unify* tests — structural cases
;; ========================================
;; These test unify* directly with hand-constructed terms.

(test-case "g2/unify*-identical-types"
  ;; Same type on both sides → #t
  (define result
    (parameterize ([current-prelude-env shared-global-env]
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
      (unify* '() (expr-fvar 'Nat) (expr-fvar 'Nat))))
  (check-equal? result #t))

(test-case "g2/unify*-incompatible-types"
  ;; Different base types → #f
  (define result
    (parameterize ([current-prelude-env shared-global-env]
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
      (unify* '() (expr-fvar 'Nat) (expr-fvar 'Bool))))
  (check-equal? result #f))

(test-case "g2/unify*-pi-structural-match"
  ;; Same Pi type → #t
  (define pi-a (expr-Pi 'mw (expr-fvar 'Nat) (expr-fvar 'Bool)))
  (define pi-b (expr-Pi 'mw (expr-fvar 'Nat) (expr-fvar 'Bool)))
  (define result
    (parameterize ([current-prelude-env shared-global-env]
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
      (unify* '() pi-a pi-b)))
  (check-equal? result #t))

(test-case "g2/unify*-pi-domain-mismatch"
  ;; Pi types with different domains → #f
  (define pi-a (expr-Pi 'mw (expr-fvar 'Nat) (expr-fvar 'Bool)))
  (define pi-b (expr-Pi 'mw (expr-fvar 'Bool) (expr-fvar 'Bool)))
  (define result
    (parameterize ([current-prelude-env shared-global-env]
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
      (unify* '() pi-a pi-b)))
  (check-equal? result #f))

(test-case "g2/unify*-ok-helper"
  ;; unify*-ok? is same as unify-ok? for structural cases
  (check-true (unify*-ok? #t))
  (check-true (unify*-ok? 'postponed))
  (check-false (unify*-ok? #f)))

;; ========================================
;; P1-G3: Meta-bearing upgrade tests
;; ========================================
;; Verify that unify* correctly handles metavariable-bearing terms
;; and that the propagator network participates in resolution.

(test-case "g3/meta-vs-concrete-succeeds"
  ;; Bare meta unified with concrete type → #t (meta gets solved)
  (define result
    (parameterize ([current-prelude-env shared-global-env]
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
      ;; fresh-meta returns (expr-meta id) — use directly
      (define meta-expr (fresh-meta '() #f "test-g3-meta"))
      (unify* '() meta-expr (expr-fvar 'Nat))))
  (check-equal? result #t))

(test-case "g3/meta-vs-meta-succeeds"
  ;; Two bare unsolved metas → flex-flex: one solved to other → #t
  (define result
    (parameterize ([current-prelude-env shared-global-env]
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
      (define me1 (fresh-meta '() #f "test-g3-m1"))
      (define me2 (fresh-meta '() #f "test-g3-m2"))
      (unify* '() me1 me2)))
  ;; flex-flex with bare metas: one gets solved to the other → #t
  (check-equal? result #t))

(test-case "g3/meta-in-pi-domain-succeeds"
  ;; Pi with meta domain vs Pi with concrete domain → #t (meta solved)
  (define result
    (parameterize ([current-prelude-env shared-global-env]
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
      (define me (fresh-meta '() #f "test-g3-dom"))
      (define pi-a (expr-Pi 'mw me (expr-fvar 'Bool)))
      (define pi-b (expr-Pi 'mw (expr-fvar 'Nat) (expr-fvar 'Bool)))
      (unify* '() pi-a pi-b)))
  (check-equal? result #t))

(test-case "g3/integration-polymorphic-app"
  ;; Full integration: polymorphic function application exercises meta solving
  (define result (run-last "eval [add 1N 2N]\n"))
  (check-false (and result (prologos-error? result))))

(test-case "g3/integration-type-annotation"
  ;; Type annotation forces unification of declared vs inferred types
  (define result (run-last "(the Nat (the Nat zero))\n"))
  (check-false (and result (prologos-error? result))))
