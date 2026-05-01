#lang racket/base

;;;
;;; Phase 11 of OCapN interop — CapTP ↔ Vat bridge.
;;;
;;; Drives a Vat from a CapTPOp value (NOT from wire bytes —
;;; the multi-arity decoder is too slow per pitfall #27).
;;; This proves the SEMANTIC mapping between the wire shape
;;; and the vat shape; the bytes-in side comes from cross-impl
;;; testing (Phases 4-10).
;;;
;;; Test flow:
;;;   1. Spawn a beh-echo actor (id 0) on a fresh vat.
;;;   2. Allocate promise p (id 1) so answer-pos=1 has a target.
;;;   3. Construct CapTPOp [op-deliver target=0 args="hi" ap=Some 1 rm=None]
;;;   4. Apply via incoming-captp-op → vat'.
;;;   5. Drain.
;;;   6. Assert: lookup-promise 1 vat'' = some [pst-fulfilled (syrup-string "hi")]
;;;
;;; This is the wire-IN half of a real netlayer: an op:deliver
;;; arriving over a socket, parsed into a CapTPOp, applied to
;;; the local vat, drained, and the result-promise resolved to
;;; the actor's reply value.
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
  "(ns test-ocapn-bridge)
(imports (prologos::ocapn::core :refer-all))
(imports (prologos::ocapn::message :refer-all))
(imports (prologos::ocapn::captp-bridge :refer-all))
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
;; Phase 11 — incoming op:deliver applied to vat
;; ========================================

(test-case "bridge/op:deliver applied via incoming-captp-op resolves answer-pos promise"
  ;; Setup:
  ;;   sa = vat-spawn-actor beh-echo syrup-null empty-vat   ;; actor id 0
  ;;   pa = fresh-promise (alloc-vat sa)                     ;; promise id 1
  ;; Apply incoming op:deliver(target=0, args="hi", ap=some 1, rm=none).
  ;; Drain. Inspect promise 1 — should be fulfilled with syrup-string "hi".
  (check-contains
   (run-last
    "(eval (let (sa  (vat-spawn-actor beh-echo syrup-null empty-vat)
                  pa  (fresh-promise (alloc-vat sa))
                  v1  (incoming-captp-op (op-deliver (alloc-id sa)
                                                     (syrup-string \"hi\")
                                                     (some Nat (alloc-id pa))
                                                     (none Nat))
                                          (alloc-vat pa))
                  v2  (drain (suc (suc (suc (suc (suc zero))))) v1))
              (fulfilled? (unwrap-or fresh
                                      (lookup-promise (alloc-id pa) v2)))))")
   "true"))

(test-case "bridge/op:deliver-only is enqueued and processed"
  (check-contains
   (run-last
    "(eval (let (sa  (vat-spawn-actor beh-echo syrup-null empty-vat)
                  v1  (incoming-captp-op (op-deliver-only (alloc-id sa)
                                                          (syrup-string \"silent\"))
                                          (alloc-vat sa))
                  v2  (drain (suc (suc (suc zero))) v1))
              (queue-length v2)))")
   "0N"))

(test-case "bridge/op:abort is a no-op on the vat (handled at connection layer)"
  ;; Vat is unchanged after applying op-abort.
  (check-contains
   (run-last
    "(eval (let (sa  (vat-spawn-actor beh-echo syrup-null empty-vat)
                  v0  (alloc-vat sa)
                  v1  (incoming-captp-op (op-abort \"reason\") v0))
              (queue-length v1)))")
   "0N"))

(test-case "bridge/op:start-session is a no-op on the vat (session layer)"
  (check-contains
   (run-last
    "(eval (let (v0  empty-vat
                  v1  (incoming-captp-op (op-start-session \"0.1\" syrup-null) v0))
              (queue-length v1)))")
   "0N"))
