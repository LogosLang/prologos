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
                shared-param-impl-reg
                shared-ctor-reg
                shared-type-meta)
  (parameterize ([current-file-module-network-ref (make-module-network)]
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
    (values (current-file-module-network-ref)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-ctor-registry)
            (current-type-meta))))

(define (run s)
  (parameterize ([current-file-module-network-ref shared-global-env]
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
    "(eval (step-behavior beh-echo syrup-null (syrup-string \"hi\") zero))")
   "ActStep"))

(test-case "behavior/step-behavior dispatches counter"
  (check-contains
   (run-last
    "(eval (step-behavior beh-counter (syrup-nat zero)
                            (syrup-tagged \"inc\" syrup-null) zero))")
   "ActStep"))

;; ========================================
;; Phase 59b part 3: the greeter's outbound send
;; ========================================
;;
;; Two independent bugs made the upstream `test_send_deliver_no_answer_or_
;; response` HANG (not fail) with the server emitting `62 in / 0 out`. Both
;; are silent: no error, no diagnostic, just no bytes. Pin both.

;; Bug 1 — a descriptor's table position arrives as a Syrup POSITIVE INTEGER
;; (`<18'desc:import-object1+>` — note the `+`), so it decodes to `syrup-int`,
;; NOT `syrup-nat`. `nat-payload` accepted only `syrup-nat` and mapped
;; `syrup-int` to none, so the greeter found no target in the descriptor it
;; had just been handed: right tag, length-1 list, and still none.
(test-case "behavior/nat-payload accepts a wire INTEGER position (not just nat)"
  (check-contains
   (run-last "(eval (unwrap-or 99N (nat-payload (syrup-int 1))))")
   "1N")
  ;; nat spelling still works
  (check-contains
   (run-last "(eval (unwrap-or 99N (nat-payload (syrup-nat 1N))))")
   "1N")
  ;; a NEGATIVE integer is not a table position — wire-nat's guard holds
  (check-contains
   (run-last "(eval (unwrap-or 99N (nat-payload (syrup-int -1))))")
   "99N"))

(test-case "behavior/refr-id-of reads an int-payload desc:import-object"
  (check-contains
   (run-last
    "(eval (unwrap-or 99N (refr-id-of (syrup-tagged \"desc:import-object\" (syrup-int 1)))))")
   "1N"))

(test-case "behavior/first-refr-in finds the descriptor in the wire arg list"
  ;; This is the exact shape upstream delivers to the greeter.
  (check-contains
   (run-last
    "(eval (unwrap-or 99N (first-refr-in (cons (syrup-tagged \"desc:import-object\" (syrup-int 1)) nil))))")
   "1N"))

;; Bug 2 — the greeter's reply target is the PEER's export position, drawn
;; from a different counter than our local actor ids and colliding with them
;; freely. `eff-send-only` would route it through the local actor table; the
;; upstream test delivers `desc:import-object 1` to a greeter that itself sits
;; at local actor id 1, so the reply went back to the greeter. The effect must
;; name the namespace: `eff-send-remote`.
(test-case "behavior/greeter emits a REMOTE send, not a local one"
  ;; eff-send-remote's selector position is the peer's export id.
  (check-contains
   (run-last
    "(eval (step-effects (step-behavior beh-greeter (syrup-string \"Hello\")
                                        (syrup-list (cons (syrup-tagged \"desc:import-object\" (syrup-int 1)) nil)) zero)))")
   "eff-send-remote"))

(test-case "behavior/greeter with no refr in args emits no effects"
  (check-contains
   (run-last
    "(eval (step-effects (step-behavior beh-greeter (syrup-string \"Hello\")
                                        (syrup-list nil) zero)))")
   "nil"))

;; ========================================
;; Phase 59b part 4: the promise RESOLVER
;; ========================================
;;
;; Upstream's promise-resolver object hands out a (vow, resolver) pair; the
;; peer then settles the vow by messaging the resolver with ['fulfill v] or
;; ['break r]. beh-fulfiller cannot serve that role — it resolves with the
;; WHOLE message, so a fulfil came back as ['fulfill ['fulfill ok]] and, worse,
;; a BREAK came back as a FULFILL whose value happened to be ['break oh-no]:
;; the outcome inverted. beh-resolver reads the verb.

(test-case "behavior/resolver fulfils with the PAYLOAD, not the whole message"
  (check-contains
   (run-last
    "(eval (step-effects (step-behavior beh-resolver (syrup-promise 6N)
                          (syrup-list (cons (syrup-symbol \"fulfill\")
                                       (cons (syrup-symbol \"ok\") nil))) zero)))")
   "eff-resolve"))

(test-case "behavior/resolver BREAKS on a break verb (does not resolve)"
  (define effs
    (run-last
     "(eval (step-effects (step-behavior beh-resolver (syrup-promise 6N)
                           (syrup-list (cons (syrup-symbol \"break\")
                                        (cons (syrup-symbol \"oh-no\") nil))) zero)))"))
  (check-contains effs "eff-break")
  (check-false (string-contains? effs "eff-resolve")
               "a break must NOT emit a resolve — that inversion was the bug"))

(test-case "behavior/resolver ignores a non-list message"
  (check-contains
   (run-last
    "(eval (step-effects (step-behavior beh-resolver (syrup-promise 6N) syrup-null zero)))")
   "nil"))

(test-case "behavior/resolver ignores an unknown verb by resolving with the payload"
  ;; Anything that is not `break` settles as a fulfil — the permissive
  ;; direction, matching how the peer only ever sends the two verbs.
  (check-contains
   (run-last
    "(eval (step-effects (step-behavior beh-resolver (syrup-promise 6N)
                          (syrup-list (cons (syrup-symbol \"fulfill\") nil)) zero)))")
   "eff-resolve"))
