#lang racket/base

;;;
;;; Tests for prologos::ocapn::message — CapTP op:* values.
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
  "(ns test-ocapn-message)
(imports (prologos::ocapn::message :refer-all))
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
;; Constructors elaborate
;; ========================================

(test-case "message/op-abort elaborates"
  (check-contains
   (run-last "(eval (op-abort \"shutdown\"))")
   "CapTPOp"))

(test-case "message/op-deliver elaborates"
  (check-contains
   (run-last
    "(eval (op-deliver zero syrup-null (some zero) (some zero)))")
   "CapTPOp"))

(test-case "message/op-deliver-only elaborates"
  (check-contains
   (run-last "(eval (op-deliver-only zero syrup-null))")
   "CapTPOp"))

(test-case "message/op-listen elaborates"
  (check-contains
   (run-last "(eval (op-listen zero (suc zero)))")
   "CapTPOp"))

(test-case "message/op-gc-export elaborates"
  (check-contains
   (run-last "(eval (op-gc-export zero (suc zero)))")
   "CapTPOp"))

;; ========================================
;; Predicates
;; ========================================

(test-case "message/deliver? on op-deliver is true"
  (check-contains
   (run-last
    "(eval (deliver? (op-deliver zero syrup-null (some zero) (some zero))))")
   "true"))

(test-case "message/deliver? on op-abort is false"
  (check-contains
   (run-last "(eval (deliver? (op-abort \"x\")))")
   "false"))

(test-case "message/deliver-only? on op-deliver-only is true"
  (check-contains
   (run-last "(eval (deliver-only? (op-deliver-only zero syrup-null)))")
   "true"))

(test-case "message/listen? on op-listen is true"
  (check-contains
   (run-last "(eval (listen? (op-listen zero (suc zero))))")
   "true"))

(test-case "message/abort? on op-abort is true"
  (check-contains
   (run-last "(eval (abort? (op-abort \"bye\")))")
   "true"))

;; ========================================
;; Selectors
;; ========================================

(test-case "message/deliver-target on op-deliver returns some"
  (check-contains
   (run-last
    "(eval (deliver-target (op-deliver (suc zero) syrup-null (some zero) (some zero))))")
   "some"))

(test-case "message/deliver-target on op-abort returns none"
  (check-contains
   (run-last "(eval (deliver-target (op-abort \"bye\")))")
   "none"))

(test-case "message/deliver-args on op-deliver-only returns some"
  (check-contains
   (run-last
    "(eval (deliver-args (op-deliver-only zero syrup-null)))")
   "some"))

(test-case "message/deliver-answer-pos none on deliver-only"
  (check-contains
   (run-last
    "(eval (deliver-answer-pos (op-deliver-only zero syrup-null)))")
   "none"))

(test-case "message/deliver-answer-pos some on op-deliver"
  (check-contains
   (run-last
    "(eval (deliver-answer-pos (op-deliver zero syrup-null (some (suc zero)) none)))")
   "some"))

(test-case "message/deliver-resolver none when builder uses no resolver"
  (check-contains
   (run-last
    "(eval (deliver-resolver (mk-deliver-no-resolver zero syrup-null (suc zero))))")
   "none"))

(test-case "message/deliver-resolver some when builder uses resolver"
  (check-contains
   (run-last
    "(eval (deliver-resolver (mk-deliver zero syrup-null (suc zero) (suc (suc zero)))))")
   "some"))

;; ========================================
;; Smart constructors
;; ========================================

(test-case "message/mk-deliver-only round-trips"
  (check-contains
   (run-last
    "(eval (deliver-only? (mk-deliver-only zero syrup-null)))")
   "true"))

(test-case "message/mk-deliver round-trips"
  (check-contains
   (run-last
    "(eval (deliver? (mk-deliver zero syrup-null (suc zero) (suc (suc zero)))))")
   "true"))
