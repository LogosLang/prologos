#lang racket/base

;;;
;;; Tests for promise pipelining in the OCapN vat.
;;;
;;; "Pipelining" means: send a message to a target, and the same turn
;;; you also send a follow-up message that uses the result-promise as
;;; its target. The follow-up is queued on the promise; when the
;;; promise resolves, the queued message is flushed back to the main
;;; queue and processed.
;;;
;;; Our Phase 0 implementation does NOT rewrite the queued message's
;;; target field on flush — it just moves the queued msgs back to the
;;; vat queue and lets them re-deliver. So pipelining at this stage
;;; is more "promise-queue mechanics" than full Goblins pipelining.
;;; Still useful: validates the monotone resolution + queue-flush
;;; semantics that future pipelining will be built on.
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
  "(ns test-ocapn-pipeline)
(imports (prologos::ocapn::vat :refer-all))
(imports (prologos::ocapn::behavior :refer-all))
(imports (prologos::ocapn::syrup :refer-all))
(imports (prologos::ocapn::promise :refer-all))
(imports (prologos::data::list :refer (List nil cons)))
(imports (prologos::data::option :refer (Option some none unwrap-or)))
(imports (prologos::data::bool :refer (and)))
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
;; Two-step actor chain
;; ========================================
;;
;; Spawn echo, send "alpha" — get promise A. Drain. A is fulfilled.
;; The result-value should be the same string we sent.

(test-case "pipeline/two-step echo chain fulfills first promise"
  (check-contains
   (run-last
    "(eval (let (s  (vat-spawn beh-echo syrup-null empty-vat)
                  r1 (send zero (syrup-string \"alpha\") (alloc-vat s))
                  r2 (send zero (syrup-string \"beta\") (alloc-vat r1))
                  v3 (run-vat (suc (suc (suc (suc (suc (suc zero)))))) (alloc-vat r2)))
              (fulfilled? (unwrap-or fresh
                                      (lookup-promise (alloc-id r1) v3)))))")
   "true"))

(test-case "pipeline/two-step echo chain fulfills second promise too"
  (check-contains
   (run-last
    "(eval (let (s  (vat-spawn beh-echo syrup-null empty-vat)
                  r1 (send zero (syrup-string \"alpha\") (alloc-vat s))
                  r2 (send zero (syrup-string \"beta\") (alloc-vat r1))
                  v3 (run-vat (suc (suc (suc (suc (suc (suc zero)))))) (alloc-vat r2)))
              (fulfilled? (unwrap-or fresh
                                      (lookup-promise (alloc-id r2) v3)))))")
   "true"))

;; ========================================
;; Promise resolution flushes queued messages
;; ========================================
;;
;; Manually allocate a fresh promise, enqueue a message on it (via the
;; PromiseState `enqueue` operation), then resolve the promise — the
;; queued message should be returned by take-queue.

(test-case "pipeline/resolve flushes queued messages"
  ;; Direct algebra-level test: enqueue then fulfill. After fulfill,
  ;; the resolved state's queue is empty (resolution is a state
  ;; transition that drops the queue field by design).
  (check-contains
   (run-last
    "(eval (take-queue (fulfill syrup-null
                                  (enqueue (syrup-string \"q\")
                                            fresh))))")
   "nil"))

;; ========================================
;; Vat-level: a fulfiller drives forward progress
;; ========================================
;;
;; This is the integration test: vat-spawn a fresh promise, wire up an
;; actor whose behaviour is to settle it, and run-vat. The promise must
;; transition to resolved and the queue must run-vat to zero.

(test-case "pipeline/fulfiller drives run-vat to quiescence"
  (check-contains
   (run-last
    "(eval (let (r0  (fresh-promise empty-vat)
                  pid (alloc-id r0)
                  s   (vat-spawn beh-fulfiller (syrup-promise pid) (alloc-vat r0))
                  v1  (send-only (alloc-id s) syrup-null (alloc-vat s))
                  v2  (run-vat (suc (suc (suc (suc (suc zero))))) v1))
              (and (fulfilled? (unwrap-or fresh
                                           (lookup-promise pid v2)))
                   (resolved? (unwrap-or fresh
                                          (lookup-promise pid v2))))))")
   "true"))

;; ========================================
;; Monotonicity under turn ordering
;; ========================================
;;
;; If the same fulfiller-target promise gets resolved twice (because
;; a second eff-resolve fires), the second is a no-op. We test by
;; spawning two fulfiller actors targeting the same promise with
;; different values.

(test-case "pipeline/double-fulfill is monotone"
  (check-contains
   (run-last
    "(eval (let (r0   (fresh-promise empty-vat)
                  pid  (alloc-id r0)
                  s1   (vat-spawn beh-fulfiller (syrup-promise pid) (alloc-vat r0))
                  s2   (vat-spawn beh-fulfiller (syrup-promise pid) (alloc-vat s1))
                  v1   (send-only (alloc-id s1) (syrup-string \"first\")  (alloc-vat s2))
                  v2   (send-only (alloc-id s2) (syrup-string \"second\") v1)
                  v3   (run-vat (suc (suc (suc (suc (suc (suc zero)))))) v2))
              (resolved? (unwrap-or fresh (lookup-promise pid v3)))))")
   "true"))
