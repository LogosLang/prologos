#lang racket/base

;;;
;;; Phase 21 — promise pipelining via target-aware delivery.
;;;
;;; `pipeline-deliver target args v` routes to:
;;;   - actor table if target is an actor (current send-only)
;;;   - promise's pending list if target is an unresolved promise
;;;   - drops if neither
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
  "(ns test-ocapn-pipelining)
(imports (prologos::ocapn::core :refer-all))
(imports (prologos::ocapn::pipelining :refer-all))
(imports (prologos::data::list :refer (List nil cons)))
(imports (prologos::data::option :refer (Option some none unwrap-or)))
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

(test-case "pipeline-deliver to an unresolved promise queues the message"
  ;; Spawn echo, allocate promise, pipeline-deliver to the promise.
  ;; queue-length(vat) should be 0 (msg went to promise's queue).
  ;; promise-queue-length should be 1.
  (check-contains
   (run-last
    "(eval (let (sa  (vat-spawn-actor beh-echo syrup-null empty-vat)
                  pa  (fresh-promise (alloc-vat sa))
                  v1  (pipeline-deliver (alloc-id pa)
                                        (syrup-string \"queued\")
                                        (alloc-vat pa)))
              (promise-queue-length (alloc-id pa) v1)))")
   "1N"))

(test-case "pipeline-deliver to an actor enqueues in vat queue (not promise)"
  ;; pipeline-deliver should fall through to send-only when target
  ;; is an actor. queue-length(vat) goes to 1.
  (check-contains
   (run-last
    "(eval (let (sa  (vat-spawn-actor beh-echo syrup-null empty-vat)
                  v1  (pipeline-deliver (alloc-id sa)
                                        (syrup-string \"normal\")
                                        (alloc-vat sa)))
              (queue-length v1)))")
   "1N"))

(test-case "pipeline-deliver to a missing target drops"
  (check-contains
   (run-last
    "(eval (queue-length (pipeline-deliver
                            (suc (suc (suc (suc zero))))
                            (syrup-string \"none\")
                            empty-vat)))")
   "0N"))

(test-case "pipeline-deliver to an already-fulfilled promise drops"
  (check-contains
   (run-last
    "(eval (let (sa  (vat-spawn-actor beh-echo syrup-null empty-vat)
                  pa  (fresh-promise (alloc-vat sa))
                  v1  (resolve-promise (alloc-id pa) (syrup-string \"done\")
                                       (alloc-vat pa))
                  v2  (pipeline-deliver (alloc-id pa)
                                        (syrup-string \"too-late\")
                                        v1))
              (promise-queue-length (alloc-id pa) v2)))")
   "0N"))
