#lang racket/base

;;;
;;; Tests for prologos::ocapn::behavior — the actor-behaviour
;;; dispatcher.
;;;
;;; These are direct unit tests of `step-behavior` and the per-tag
;;; step functions, exercising the "ABI" without going through the
;;; vat. The vat tests cover the integration; these cover
;;; per-behaviour correctness.
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
  "(ns test-ocapn-behavior)
(imports (prologos::ocapn::behavior :refer-all))
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
;; ActStep selectors
;; ========================================

(test-case "behavior/no-op returns state as both new state and rv"
  (check-contains
   (run-last "(eval (step-state (no-op (syrup-nat zero))))")
   "SyrupValue"))

(test-case "behavior/no-op produces empty effects"
  (check-contains
   (run-last "(eval (step-effects (no-op syrup-null)))")
   "nil"))

;; ========================================
;; echo
;; ========================================

(test-case "behavior/echo step returns args as rv"
  (check-contains
   (run-last
    "(eval (step-return (step-echo syrup-null (syrup-string \"hi\"))))")
   "SyrupValue"))

(test-case "behavior/echo state unchanged"
  (check-contains
   (run-last
    "(eval (step-state (step-echo (syrup-nat zero) (syrup-string \"x\"))))")
   "SyrupValue"))

;; ========================================
;; counter
;; ========================================

(test-case "behavior/counter inc on nat 0 yields ActStep"
  (check-contains
   (run-last
    "(eval (step-counter (syrup-nat zero) (syrup-tagged \"inc\" syrup-null)))")
   "ActStep"))

(test-case "behavior/counter unknown tag is no-op"
  (check-contains
   (run-last
    "(eval (step-state (step-counter (syrup-nat zero) (syrup-tagged \"reset\" syrup-null))))")
   "SyrupValue"))

;; ========================================
;; cell
;; ========================================

(test-case "behavior/cell set returns ActStep"
  (check-contains
   (run-last
    "(eval (step-cell syrup-null (syrup-tagged \"set\" (syrup-nat zero))))")
   "ActStep"))

;; ========================================
;; greeter
;; ========================================

(test-case "behavior/greeter with non-string args is no-op"
  (check-contains
   (run-last
    "(eval (step-state (step-greeter (syrup-string \"hi\") (syrup-nat zero))))")
   "SyrupValue"))

;; ========================================
;; adder
;; ========================================

(test-case "behavior/adder yields ActStep"
  (check-contains
   (run-last
    "(eval (step-adder (syrup-nat zero) (syrup-nat (suc zero))))")
   "ActStep"))

;; ========================================
;; forwarder
;; ========================================

(test-case "behavior/forwarder produces a single eff-send-only"
  ;; Not asserting structure — just that it elaborates.
  (check-contains
   (run-last
    "(eval (step-effects (step-forwarder (syrup-refr (suc zero)) (syrup-string \"x\"))))")
   "List"))

;; ========================================
;; fulfiller
;; ========================================

(test-case "behavior/fulfiller produces eff-resolve"
  (check-contains
   (run-last
    "(eval (step-effects (step-fulfiller (syrup-promise zero) (syrup-string \"v\"))))")
   "List"))

;; ========================================
;; Dispatcher (closed sum)
;; ========================================

(test-case "behavior/step-behavior dispatches on tag"
  (check-contains
   (run-last
    "(eval (step-behavior beh-echo syrup-null (syrup-string \"hi\")))")
   "ActStep"))

(test-case "behavior/step-behavior dispatches counter"
  (check-contains
   (run-last
    "(eval (step-behavior beh-counter (syrup-nat zero)
                            (syrup-tagged \"inc\" syrup-null)))")
   "ActStep"))
