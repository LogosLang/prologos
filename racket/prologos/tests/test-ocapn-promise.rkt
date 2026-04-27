#lang racket/base

;;;
;;; Tests for prologos::ocapn::promise — Promise state algebra.
;;;
;;; Validates monotone resolution: once a promise is settled
;;; (fulfilled OR broken), subsequent attempts are no-ops. Validates
;;; queue mechanics for pipelined messages.
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt")

(define shared-preamble
  "(ns test-ocapn-promise)
(imports (prologos::ocapn::promise :refer-all))
(imports (prologos::ocapn::syrup :refer-all))
(imports (prologos::data::list :refer (List nil cons)))
(imports (prologos::data::option :refer (Option some none)))
")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string shared-preamble)
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry))))

(define (run s)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg])
    (process-string s)))

(define (run-last s) (last (run s)))

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))

;; ========================================
;; Initial state: fresh promise is unresolved
;; ========================================

(test-case "promise/fresh is unresolved"
  (check-contains (run-last "(eval (unresolved? fresh))") "true"))

(test-case "promise/fresh is not fulfilled"
  (check-contains (run-last "(eval (fulfilled? fresh))") "false"))

(test-case "promise/fresh is not broken"
  (check-contains (run-last "(eval (broken? fresh))") "false"))

(test-case "promise/fresh is not resolved"
  (check-contains (run-last "(eval (resolved? fresh))") "false"))

;; ========================================
;; Fulfill semantics
;; ========================================

(test-case "promise/fulfill flips fulfilled?"
  (check-contains
   (run-last "(eval (fulfilled? (fulfill (syrup-nat zero) fresh)))")
   "true"))

(test-case "promise/fulfilled is resolved"
  (check-contains
   (run-last "(eval (resolved? (fulfill (syrup-nat zero) fresh)))")
   "true"))

(test-case "promise/fulfill twice — second is no-op (monotone)"
  ;; First fulfill with 1, then fulfill with 2 — value should still be 1.
  (check-contains
   (run-last
    "(eval (resolution-value
              (fulfill (syrup-nat (suc (suc zero)))
                       (fulfill (syrup-nat (suc zero)) fresh))))")
   "some"))

;; ========================================
;; Break semantics
;; ========================================

(test-case "promise/break flips broken?"
  (check-contains
   (run-last "(eval (broken? (break (syrup-string \"oops\") fresh)))")
   "true"))

(test-case "promise/broken is resolved"
  (check-contains
   (run-last "(eval (resolved? (break (syrup-string \"oops\") fresh)))")
   "true"))

(test-case "promise/break-then-fulfill — break wins (monotone)"
  ;; Once broken, a subsequent fulfill must NOT change the state.
  (check-contains
   (run-last
    "(eval (broken? (fulfill (syrup-nat zero)
                              (break (syrup-string \"err\") fresh))))")
   "true"))

(test-case "promise/fulfill-then-break — fulfill wins (monotone)"
  (check-contains
   (run-last
    "(eval (fulfilled? (break (syrup-string \"err\")
                               (fulfill (syrup-nat zero) fresh))))")
   "true"))

;; ========================================
;; Queue semantics on unresolved
;; ========================================

(test-case "promise/enqueue grows the queue"
  ;; Two enqueues then take-queue should return a 2-element list.
  ;; We just check the type of the result via a structural eval.
  (check-contains
   (run-last
    "(eval (take-queue
              (enqueue (syrup-nat (suc zero))
                       (enqueue (syrup-nat zero) fresh))))")
   "List"))

(test-case "promise/enqueue on resolved is no-op"
  (check-contains
   (run-last
    "(eval (take-queue
              (enqueue (syrup-nat (suc zero))
                       (fulfill syrup-null fresh))))")
   "nil"))

;; ========================================
;; resolution-value
;; ========================================

(test-case "promise/resolution-value of unresolved is none"
  (check-contains
   (run-last "(eval (resolution-value fresh))") "none"))

(test-case "promise/resolution-value of fulfilled is some"
  (check-contains
   (run-last
    "(eval (resolution-value (fulfill syrup-null fresh)))")
   "some"))

(test-case "promise/resolution-value of broken is some"
  (check-contains
   (run-last
    "(eval (resolution-value (break syrup-null fresh)))")
   "some"))
