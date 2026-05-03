#lang racket/base

;;;
;;; Tests for prologos::ocapn::syrup — Syrup abstract value model.
;;; Validates each constructor parses, each predicate decides correctly,
;;; and each selector projects to the right Option.
;;;

(require rackunit
         racket/list
         racket/string
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../multi-dispatch.rkt")

(define shared-preamble
  "(ns test-ocapn-syrup)
(imports (prologos::ocapn::syrup :refer-all))
(imports (prologos::data::list :refer (List nil cons)))
(imports (prologos::data::option :refer (Option some none)))
")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-ctor-reg
                shared-type-meta)
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
            (current-param-impl-registry)
            (current-ctor-registry)
            (current-type-meta))))

(define (run s)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-ctor-registry shared-ctor-reg]
                 [current-type-meta shared-type-meta])
    (process-string s)))

(define (run-last s) (last (run s)))

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))

;; ========================================
;; Constructors elaborate
;; ========================================

(test-case "syrup/null elaborates"
  (check-contains
   (run-last "(eval syrup-null)")
   "SyrupValue"))

(test-case "syrup/bool true elaborates"
  (check-contains
   (run-last "(eval (syrup-bool true))")
   "SyrupValue"))

(test-case "syrup/nat 0 elaborates"
  (check-contains
   (run-last "(eval (syrup-nat zero))")
   "SyrupValue"))

(test-case "syrup/string elaborates"
  (check-contains
   (run-last "(eval (syrup-string \"hi\"))")
   "SyrupValue"))

(test-case "syrup/symbol elaborates"
  (check-contains
   (run-last "(eval (syrup-symbol \"op:deliver\"))")
   "SyrupValue"))

(test-case "syrup/refr elaborates"
  (check-contains
   (run-last "(eval (syrup-refr (suc (suc zero))))")
   "SyrupValue"))

(test-case "syrup/promise elaborates"
  (check-contains
   (run-last "(eval (syrup-promise zero))")
   "SyrupValue"))

;; ========================================
;; Predicates
;; ========================================

(test-case "syrup/null? on syrup-null"
  (check-contains
   (run-last "(eval (null? syrup-null))")
   "true"))

(test-case "syrup/null? on a refr is false"
  (check-contains
   (run-last "(eval (null? (syrup-refr zero)))")
   "false"))

(test-case "syrup/refr? on a refr is true"
  (check-contains
   (run-last "(eval (refr? (syrup-refr zero)))")
   "true"))

(test-case "syrup/refr? on a promise is false"
  (check-contains
   (run-last "(eval (refr? (syrup-promise zero)))")
   "false"))

(test-case "syrup/promise? on a promise is true"
  (check-contains
   (run-last "(eval (promise? (syrup-promise zero)))")
   "true"))

(test-case "syrup/tagged? on a tagged value is true"
  (check-contains
   (run-last "(eval (tagged? (syrup-tagged \"set\" syrup-null)))")
   "true"))

(test-case "syrup/tagged? on a non-tagged is false"
  (check-contains
   (run-last "(eval (tagged? syrup-null))")
   "false"))

;; ========================================
;; Selectors
;; ========================================

(test-case "syrup/get-nat on a syrup-nat returns some"
  (check-contains
   (run-last "(eval (get-nat (syrup-nat (suc (suc zero)))))")
   "some"))

(test-case "syrup/get-nat on a syrup-string returns none"
  (check-contains
   (run-last "(eval (get-nat (syrup-string \"x\")))")
   "none"))

(test-case "syrup/get-tag on a tagged returns some"
  (check-contains
   (run-last "(eval (get-tag (syrup-tagged \"op:deliver\" syrup-null)))")
   "some"))

(test-case "syrup/get-tag on a non-tagged returns none"
  (check-contains
   (run-last "(eval (get-tag syrup-null))")
   "none"))

(test-case "syrup/get-refr on a refr returns some"
  (check-contains
   (run-last "(eval (get-refr (syrup-refr zero)))")
   "some"))

(test-case "syrup/get-promise on a promise returns some"
  (check-contains
   (run-last "(eval (get-promise (syrup-promise zero)))")
   "some"))

;; ========================================
;; Convenience: mk-tagged / mk-record
;; ========================================

(test-case "syrup/mk-tagged builds a tagged value"
  (check-contains
   (run-last "(eval (tagged? (mk-tagged \"op:listen\" syrup-null)))")
   "true"))

(test-case "syrup/mk-record builds a tagged with a list payload"
  (check-contains
   (run-last "(eval (tagged? (mk-record \"op:gc-export\" nil)))")
   "true"))
