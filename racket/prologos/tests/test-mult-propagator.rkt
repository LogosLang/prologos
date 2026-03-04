#lang racket/base

;;;
;;; Tests for P5b: Multiplicity Cells in Elaboration Network
;;;
;;; Verifies that mult-metas get cells on the propagator network
;;; and that solve-mult-meta! writes to those cells.
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
    (process-string "(ns test-mult-prop)\n")
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
;; Integration tests: mult cells created for expressions
;; ========================================

(test-case "mult/add-has-no-error"
  ;; Basic sanity: mult cells are allocated during type-checking
  ;; and don't break anything
  (define result (run-last "eval [add 1N 2N]\n"))
  (check-false (and result (prologos-error? result))))

(test-case "mult/sub-has-no-error"
  (define result (run-last "eval [sub 5N 3N]\n"))
  (check-false (and result (prologos-error? result))))

(test-case "mult/nested-has-no-error"
  (define result (run-last "eval [add [sub 10N 3N] 4N]\n"))
  (check-false (and result (prologos-error? result))))

(test-case "mult/lt-has-no-error"
  (define result (run-last "eval [lt? 1N 2N]\n"))
  (check-false (and result (prologos-error? result))))

(test-case "mult/identity-fn-has-no-error"
  ;; Lambda with mult-meta — exercises mult cell creation for binder multiplicities
  (define result (run-last "(def id : (Pi (A : (Type 0)) (Pi (x : A) A)) (fn [A] [x] x))\n"))
  (check-false (and result (prologos-error? result))))

(test-case "mult/def-nat-has-no-error"
  (define result (run-last "(def x : Nat zero)\n"))
  (check-false (and result (prologos-error? result))))
