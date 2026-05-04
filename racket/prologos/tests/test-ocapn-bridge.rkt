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

;; ========================================
;; Phase 12 — outbound resolution → wire bytes
;; ========================================

(define (extract-value-bytes s)
  (define m (regexp-match #px"^(\".*\") : String$" s))
  (unless m
    (error 'extract-value-bytes "couldn't extract bytes from: ~s" s))
  (read (open-input-string (cadr m))))

(test-case "bridge/outbound-deliver-bytes builds canonical op:deliver record"
  ;; pid=0, args="hi" should produce <op:deliver <desc:answer 0> "hi" false false>
  (define got
    (extract-value-bytes
     (run-last
      "(eval (outbound-deliver-bytes zero (syrup-string \"hi\")))")))
  (define expected
    (extract-value-bytes
     (run-last
      "(eval (encode-record \"op:deliver\"
                              (cons (syrup-tagged \"desc:answer\" (syrup-nat zero))
                                (cons (syrup-string \"hi\")
                                  (cons (syrup-bool false)
                                    (cons (syrup-bool false) nil))))))")))
  (check-equal? got expected))

(test-case "bridge/outbound-from-resolution unresolved -> none"
  (check-contains
   (run-last "(eval (outbound-from-resolution zero fresh))")
   "none"))

(test-case "bridge/outbound-from-resolution fulfilled -> some bytes"
  (check-contains
   (run-last
    "(eval (outbound-from-resolution
              zero
              (fulfill (syrup-string \"hi\") fresh)))")
   "some"))

(test-case "bridge/full round-trip — incoming deliver, drain, extract outbound bytes"
  ;; Apply Phase 11's incoming op-deliver → vat resolves promise →
  ;; Phase 12's outbound-from-resolution → bytes.
  ;;
  ;; Setup: actor at id 0, promise at id 1. Send op-deliver target=0
  ;; args="hi" ap=Some 1. After drain, lookup-promise 1 returns
  ;; some pst-fulfilled (syrup-string "hi"). Then outbound-from-
  ;; resolution returns the wire bytes.
  ;;
  ;; Asserts: bytes equal what `outbound-deliver-bytes 1 (syrup-string "hi")`
  ;; would produce.
  (define got
    (extract-value-bytes
     (run-last
      "(eval (let (sa  (vat-spawn-actor beh-echo syrup-null empty-vat)
                    pa  (fresh-promise (alloc-vat sa))
                    v1  (incoming-captp-op (op-deliver (alloc-id sa)
                                                       (syrup-string \"hi\")
                                                       (some Nat (alloc-id pa))
                                                       (none Nat))
                                            (alloc-vat pa))
                    v2  (drain (suc (suc (suc (suc (suc zero))))) v1)
                    pst (unwrap-or fresh
                                    (lookup-promise (alloc-id pa) v2)))
                (unwrap-or \"NO-OUTBOUND\"
                            (outbound-from-resolution (alloc-id pa) pst))))")))
  (define expected
    (extract-value-bytes
     (run-last
      "(eval (outbound-deliver-bytes (suc zero) (syrup-string \"hi\")))")))
  (check-equal? got expected))

;; ========================================
;; Phase 14 — state-aware dispatcher (op:listen, op:gc-*)
;; ========================================
;;
;; The simple `incoming-captp-op` was no-op for op:listen and
;; op:gc-*. The state-aware variant `captp-incoming-with-state`
;; carries a `BridgeState` and updates it for each of these.

(test-case "bridge/captp-incoming-with-state op:listen registers listener"
  ;; After an op:listen 7 13, the bridge state should contain a
  ;; listener for target=7 resolver=13. The vat is unchanged.
  ;; List `length` returns Nat (1N for a single listener).
  (check-contains
   (run-last
    "(eval (let (step (captp-incoming-with-state
                          (op-listen (suc (suc (suc (suc (suc (suc (suc zero))))))) ;; 7
                                     (suc (suc (suc (suc (suc (suc (suc (suc (suc (suc (suc (suc (suc zero)))))))))))))) ;; 13
                          empty-vat
                          bridge-state-empty)
                    listeners (bs-listeners (bridge-step-state step)))
              (length listeners)))")
   "1N"))

(test-case "bridge/captp-incoming-with-state op:gc-export records request"
  (check-contains
   (run-last
    "(eval (let (step (captp-incoming-with-state
                          (op-gc-export (suc (suc zero)) (suc zero))
                          empty-vat
                          bridge-state-empty)
                    es (bs-gc-exports (bridge-step-state step)))
              (length es)))")
   "1N"))

(test-case "bridge/captp-incoming-with-state op:gc-answer records request"
  (check-contains
   (run-last
    "(eval (let (step (captp-incoming-with-state
                          (op-gc-answer (suc zero))
                          empty-vat
                          bridge-state-empty)
                    as (bs-gc-answers (bridge-step-state step)))
              (length as)))")
   "1N"))

(test-case "bridge/captp-incoming-with-state op:deliver routes to vat queue"
  ;; Vat queue should grow; bridge state unchanged.
  (check-contains
   (run-last
    "(eval (let (sa   (vat-spawn-actor beh-echo syrup-null empty-vat)
                  step (captp-incoming-with-state
                          (op-deliver (alloc-id sa) (syrup-string \"hi\") (none Nat) (none Nat))
                          (alloc-vat sa)
                          bridge-state-empty))
              (queue-length (bridge-step-vat step))))")
   "1N"))

;; ========================================
;; Phase 15 — session question-table mapping
;; ========================================

(test-case "bridge/dispatch-deliver allocates fresh local promise and records mapping"
  ;; Wire side specifies answer-pos=42 (a position in the peer's
  ;; question table). Locally we have an empty vat — no promise
  ;; at id 42. The bridge should allocate a local promise (will
  ;; be id 0 in the empty vat) and record (42→0) in the question
  ;; table.
  (check-contains
   (run-last
    "(eval (let (sa   (vat-spawn-actor beh-echo syrup-null empty-vat)
                  step (captp-incoming-with-state
                          (op-deliver (alloc-id sa)
                                      (syrup-string \"hi\")
                                      (some Nat (suc (suc (suc (suc (suc (suc (suc (suc (suc zero)))))))))) ;; remote=9 (chosen by peer)
                                      (none Nat))
                          (alloc-vat sa)
                          bridge-state-empty)
                  qs (bs-questions (bridge-step-state step)))
              (length qs)))")
   "1N"))

(test-case "bridge/dispatch-deliver re-uses existing question-table entry"
  ;; Same op:deliver with remote=9 sent twice — second one
  ;; should reuse the local promise; question table size stays 1.
  (check-contains
   (run-last
    "(eval (let (sa    (vat-spawn-actor beh-echo syrup-null empty-vat)
                  step1 (captp-incoming-with-state
                            (op-deliver (alloc-id sa)
                                        (syrup-string \"hi-1\")
                                        (some Nat (suc (suc (suc zero))))
                                        (none Nat))
                            (alloc-vat sa)
                            bridge-state-empty)
                  step2 (captp-incoming-with-state
                            (op-deliver (alloc-id sa)
                                        (syrup-string \"hi-2\")
                                        (some Nat (suc (suc (suc zero))))
                                        (none Nat))
                            (bridge-step-vat step1)
                            (bridge-step-state step1))
                  qs (bs-questions (bridge-step-state step2)))
              (length qs)))")
   "1N"))

(test-case "bridge/dispatch-deliver with answer-pos=none doesn't touch question table"
  (check-contains
   (run-last
    "(eval (let (sa   (vat-spawn-actor beh-echo syrup-null empty-vat)
                  step (captp-incoming-with-state
                          (op-deliver (alloc-id sa)
                                      (syrup-string \"hi\")
                                      (none Nat)
                                      (none Nat))
                          (alloc-vat sa)
                          bridge-state-empty)
                  qs (bs-questions (bridge-step-state step)))
              (length qs)))")
   "0N"))

;; ========================================
;; Phase 16 — wire-OUT pump (auto-emit bytes on resolution)
;; ========================================

(test-case "bridge/pump-outbound emits bytes when a question's promise is fulfilled"
  ;; End-to-end: incoming op-deliver allocates local promise via
  ;; question table. Drain the vat → echo actor resolves it.
  ;; pump-outbound walks the question table and produces bytes
  ;; targeting the REMOTE answer-pos.
  ;;
  ;; Asserts: result bytes list has length 1.
  (check-contains
   (run-last
    "(eval (let (sa    (vat-spawn-actor beh-echo syrup-null empty-vat)
                  step  (captp-incoming-with-state
                            (op-deliver (alloc-id sa)
                                        (syrup-string \"hi\")
                                        (some Nat (suc (suc (suc (suc (suc (suc zero))))))) ;; remote=6
                                        (none Nat))
                            (alloc-vat sa)
                            bridge-state-empty)
                  v2    (drain (suc (suc (suc (suc (suc zero))))) (bridge-step-vat step))
                  pr    (pump-outbound v2 (bridge-step-state step) nil))
              (length (pump-result-bytes pr))))")
   "1N"))

(test-case "bridge/pump-outbound is idempotent — second call after re-pump emits nothing new"
  ;; Same setup; first pump emits the bytes and returns
  ;; emitted=[local]. Second pump with that emitted list returns
  ;; bytes=nil.
  (check-contains
   (run-last
    "(eval (let (sa     (vat-spawn-actor beh-echo syrup-null empty-vat)
                  step   (captp-incoming-with-state
                             (op-deliver (alloc-id sa)
                                         (syrup-string \"hi\")
                                         (some Nat (suc (suc (suc zero))))
                                         (none Nat))
                             (alloc-vat sa)
                             bridge-state-empty)
                  v2     (drain (suc (suc (suc (suc (suc zero))))) (bridge-step-vat step))
                  pr1    (pump-outbound v2 (bridge-step-state step) nil)
                  pr2    (pump-outbound v2 (bridge-step-state step)
                                         (pump-result-emitted pr1)))
              (length (pump-result-bytes pr2))))")
   "0N"))

(test-case "bridge/pump-outbound returns empty if no promises resolved"
  ;; Question table has an entry but the promise is still
  ;; unresolved (we DIDN'T drain).
  (check-contains
   (run-last
    "(eval (let (sa    (vat-spawn-actor beh-echo syrup-null empty-vat)
                  step  (captp-incoming-with-state
                            (op-deliver (alloc-id sa)
                                        (syrup-string \"hi\")
                                        (some Nat (suc (suc (suc zero))))
                                        (none Nat))
                            (alloc-vat sa)
                            bridge-state-empty)
                  pr    (pump-outbound (bridge-step-vat step)
                                        (bridge-step-state step)
                                        nil))
              (length (pump-result-bytes pr))))")
   "0N"))

(test-case "bridge/pump-outbound bytes target the REMOTE answer-pos, not local pid"
  ;; Remote=6 in our test. The local promise gets allocated at
  ;; whatever fresh-promise gives (id 1 in this vat with one
  ;; spawned actor). The OUTBOUND bytes should target REMOTE=6
  ;; in `<op:deliver <desc:answer 6> ...>`, NOT local=1.
  (define got
    (extract-value-bytes
     (run-last
      "(eval (let (sa    (vat-spawn-actor beh-echo syrup-null empty-vat)
                    step  (captp-incoming-with-state
                              (op-deliver (alloc-id sa)
                                          (syrup-string \"hi\")
                                          (some Nat (suc (suc (suc (suc (suc (suc zero))))))) ;; remote=6
                                          (none Nat))
                              (alloc-vat sa)
                              bridge-state-empty)
                    v2    (drain (suc (suc (suc (suc (suc zero))))) (bridge-step-vat step))
                    pr    (pump-outbound v2 (bridge-step-state step) nil))
                (first-bytes-or-default \"NO-BYTES\" (pump-result-bytes pr))))")))
  (define expected
    (extract-value-bytes
     (run-last
      "(eval (outbound-deliver-bytes (suc (suc (suc (suc (suc (suc zero)))))) (syrup-string \"hi\")))")))
  (check-equal? got expected))

;; ========================================
;; Phase 17 — Error type for broken promises
;; ========================================

(test-case "bridge/outbound-from-resolution broken -> some <Error r>-bytes"
  ;; Broken promise should now yield bytes (was `none` in Phase 12).
  ;; Bytes target the local pid as <op:deliver <desc:answer N> <Error r> false false>.
  ;; (Construct broken state via `pst-broken` directly; `break` from
  ;; promise.prologos collides with `data::list::break-helper` in the
  ;; sexp-mode resolver.)
  (check-contains
   (run-last
    "(eval (outbound-from-resolution
              zero
              (pst-broken (syrup-string \"oops\"))))")
   "some"))

(test-case "bridge/outbound-from-resolution broken bytes contain <Error wrapper"
  (define got
    (extract-value-bytes
     (run-last
      "(eval (unwrap-or \"NO-BYTES\"
                          (outbound-from-resolution
                            zero
                            (pst-broken (syrup-string \"oops\")))))")))
  (define expected
    (extract-value-bytes
     (run-last
      "(eval (encode-record \"op:deliver\"
                              (cons (syrup-tagged \"desc:answer\" (syrup-nat zero))
                                (cons (syrup-tagged \"Error\" (syrup-string \"oops\"))
                                  (cons (syrup-bool false)
                                    (cons (syrup-bool false) nil))))))")))
  (check-equal? got expected))

(test-case "bridge/wrap-error wraps a SyrupValue in <Error _> tagged record"
  ;; (wrap-error "oops") should equal (syrup-tagged "Error" "oops").
  ;; Verify by encoding both and comparing bytes.
  (define got
    (extract-value-bytes
     (run-last "(eval (encode (wrap-error (syrup-string \"oops\"))))")))
  (define expected
    (extract-value-bytes
     (run-last "(eval (encode (syrup-tagged \"Error\" (syrup-string \"oops\"))))")))
  (check-equal? got expected))
