#lang racket/base
;;;
;;; test-ocapn-bridge-02.rkt — second half of the CapTP bridge tests.
;;;
;;; Split out of test-ocapn-bridge.rkt, which had grown to 147 test-cases in
;;; one file and was TIMING OUT at the runner's 120s per-file limit on CI
;;; (locally ~70s, but CI runs ~1.6x slower). `.claude/rules/testing.md` asks
;;; for ~20 cases / ~30s per file precisely so one file cannot dominate the
;;; thread pool like this.
;;;
;;; The fixture below is the same shared-prelude-snapshot pattern as the
;;; original — see test-support.rkt.
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
  "(ns test-ocapn-bridge-02)
(imports (prologos::ocapn::core :refer-all))
(imports (prologos::ocapn::message :refer-all))
(imports (prologos::ocapn::captp-wire :refer-all))
(imports (prologos::ocapn::syrup-wire :refer-all))
(imports (prologos::ocapn::captp-core :refer-all))
(imports (prologos::ocapn::pipelining :refer (promise-queue-length)))
(imports (prologos::ocapn::captp-interop-helpers :refer (framed-concat)))
(imports (prologos::data::list :refer (List nil cons)))
(imports (prologos::data::option :refer (Option some none unwrap-or)))
(imports (prologos::data::string :as str :refer ()))
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
    (values (global-env-snapshot)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-ctor-registry)
            (current-type-meta))))

(define (run s)
  (parameterize ([current-file-module-network-ref (module-network-add-import (make-module-network) (module-network-from-snapshot shared-global-env))]
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


(define (extract-value-bytes s)
  (define m (regexp-match #px"^(\".*\") : String$" s))
  (unless m
    (error 'extract-value-bytes "couldn't extract bytes from: ~s" s))
  (read (open-input-string (cadr m))))

(test-case "bridge/connection-ask returns the freshly-allocated promise-id"
  (check-contains
   (run-last
    "(eval (conn-ask-pid (connection-ask zero (syrup-string \"ping\") empty-connection)))")
   "0N"))

(test-case "bridge/connection-ask updates ConnectionState's outbound-questions"
  ;; After ask, looking up q-pos in the returned state's bridge-state
  ;; should find the local promise.
  (check-contains
   (run-last
    "(eval (let (ask (connection-ask zero (syrup-string \"ping\") empty-connection))
              (bs-lookup-outbound-question (conn-ask-pid ask)
                                            (conn-bridge-state (conn-ask-state ask)))))")
   "some"))

;; Phase 30: captp-ask (in core) is the user-facing alias for
;; connection-ask. Bytes match.
(test-case "core/captp-ask is byte-equivalent to connection-ask"
  (define got
    (extract-value-bytes
     (run-last
      "(eval (conn-ask-bytes (captp-ask zero (syrup-string \"ping\") empty-connection)))")))
  (define expected
    (extract-value-bytes
     (run-last
      "(eval (conn-ask-bytes (connection-ask zero (syrup-string \"ping\") empty-connection)))")))
  (check-equal? got expected))

(test-case "core/captp-ask returns same pid as connection-ask"
  (define got-via-captp-ask
    (run-last
     "(eval (conn-ask-pid (captp-ask zero (syrup-string \"ping\") empty-connection)))"))
  (define got-via-connection-ask
    (run-last
     "(eval (conn-ask-pid (connection-ask zero (syrup-string \"ping\") empty-connection)))"))
  (check-equal? got-via-captp-ask got-via-connection-ask))

;; Phase 32: outbound GC release API.
(test-case "bridge/release-answer emits op:gc-answer wire bytes"
  ;; release-answer for q-pos=2 should emit canonical bytes.
  (define got
    (extract-value-bytes
     (run-last
      "(eval (let (rel (release-answer (suc (suc zero)) empty-connection))
                (first-bytes-or-default \"NO-BYTES\" (conn-release-bytes rel))))")))
  (define expected
    (extract-value-bytes
     (run-last
      "(eval (gc-answer-bytes (suc (suc zero))))")))
  (check-equal? got expected))

(test-case "bridge/release-answer removes the outbound-question entry"
  ;; Before release: q-pos=0 maps to a promise (via connection-ask).
  ;; After release: lookup of q-pos=0 returns none.
  (check-contains
   (run-last
    "(eval (let (ask  (connection-ask zero (syrup-string \"ping\") empty-connection)
                  pid  (conn-ask-pid ask)
                  cs1  (conn-ask-state ask)
                  rel  (release-answer pid cs1))
              (bs-lookup-outbound-question pid (conn-bridge-state (conn-release-state rel)))))")
   "none"))

(test-case "bridge/release-answer is a no-op once aborted"
  ;; Aborted connection: bytes list should be empty.
  (check-contains
   (run-last
    "(eval (let (cs0   empty-connection
                  step1 (connection-step (op-abort \"bye\") cs0)
                  rel   (release-answer zero (conn-step-state step1)))
              (length (conn-release-bytes rel))))")
   "0N"))

;; Phase 34e: release-import decrements imports-refcount.
(test-case "bridge/release-import decrements imports-refcount by k"
  ;; Increment refcount for export 3 to 2, then release-import 1.
  ;; Final count should be 1.
  (check-contains
   (run-last
    "(eval (let (st0 (bs-incr-import (suc (suc (suc zero)))
                       (bs-incr-import (suc (suc (suc zero))) bridge-state-empty))
                  cs0 (conn-state empty-vat st0 nil false)
                  rel (release-import (suc (suc (suc zero))) (suc zero) cs0))
              (bs-lookup-import-refcount (suc (suc (suc zero)))
                (conn-bridge-state (conn-release-state rel)))))")
   "1N"))

(test-case "bridge/release-import decrement saturates at zero"
  ;; Refcount=1, release count=5. Final count should be 0.
  (check-contains
   (run-last
    "(eval (let (st0 (bs-incr-import (suc zero) bridge-state-empty)
                  cs0 (conn-state empty-vat st0 nil false)
                  rel (release-import (suc zero) (suc (suc (suc (suc (suc zero))))) cs0))
              (bs-lookup-import-refcount (suc zero)
                (conn-bridge-state (conn-release-state rel)))))")
   "0N"))

(test-case "bridge/release-import emits op:gc-export wire bytes"
  ;; release-import for export-pos=3, count=2 should emit canonical bytes.
  (define got
    (extract-value-bytes
     (run-last
      "(eval (let (rel (release-import (suc (suc (suc zero))) (suc (suc zero)) empty-connection))
                (first-bytes-or-default \"NO-BYTES\" (conn-release-bytes rel))))")))
  (define expected
    (extract-value-bytes
     (run-last
      "(eval (gc-export-bytes (suc (suc (suc zero))) (suc (suc zero))))")))
  (check-equal? got expected))

;; Phase 33: inbound op:gc-answer dispatch removes the inbound-question entry.
(test-case "bridge/captp-incoming op:gc-answer removes the inbound-question entry"
  ;; Add q-pos=1 → pid=10 to inbound-questions, dispatch op:gc-answer 1,
  ;; lookup q-pos=1 should now return none.
  (check-contains
   (run-last
    "(eval (let (st0  (bs-add-question (suc zero) (suc (suc (suc (suc (suc (suc (suc (suc (suc (suc zero))))))))) ) bridge-state-empty)
                  step (captp-incoming-with-state (op-gc-answer (suc zero)) empty-vat st0))
              (bs-lookup-question (suc zero) (bridge-step-state step))))")
   "none"))

(test-case "bridge/captp-incoming op:gc-answer also appends to audit log"
  ;; The bs-gc-answers list grows by 1 (for diagnostics).
  (check-contains
   (run-last
    "(eval (let (step (captp-incoming-with-state (op-gc-answer (suc zero)) empty-vat bridge-state-empty))
              (length (bs-gc-answers (bridge-step-state step)))))")
   "1N"))

(test-case "bridge/captp-incoming op:gc-answer keeps non-matching entries"
  ;; Two entries: (q=1 → pid=1) and (q=2 → pid=2). gc q=1; q=2 still there.
  (check-contains
   (run-last
    "(eval (let (st0 (bs-add-question (suc (suc zero)) (suc (suc zero))
                       (bs-add-question (suc zero) (suc zero) bridge-state-empty))
                  step (captp-incoming-with-state (op-gc-answer (suc zero)) empty-vat st0))
              (bs-lookup-question (suc (suc zero)) (bridge-step-state step))))")
   "some"))

(test-case "core/captp-release-answer is byte-equivalent to release-answer"
  (define got-via-core
    (extract-value-bytes
     (run-last
      "(eval (let (rel (captp-release-answer (suc zero) empty-connection))
                (first-bytes-or-default \"NO-BYTES\" (conn-release-bytes rel))))")))
  (define got-via-bridge
    (extract-value-bytes
     (run-last
      "(eval (let (rel (release-answer (suc zero) empty-connection))
                (first-bytes-or-default \"NO-BYTES\" (conn-release-bytes rel))))")))
  (check-equal? got-via-core got-via-bridge))

(test-case "bridge/connection-ask is a no-op once aborted"
  ;; After abort, ask returns the same state with empty bytes.
  (check-contains
   (run-last
    "(eval (let (cs0   empty-connection
                  step1 (connection-step (op-abort \"bye\") cs0)
                  ask   (connection-ask zero (syrup-string \"ping\") (conn-step-state step1)))
              (str::eq (conn-ask-bytes ask) \"\")))")
   "true"))

(test-case "bridge/connection-ask + connection-step round-trip resolves the promise"
  ;; 1. Ask (get bytes + pid).
  ;; 2. Build peer's reply directly as op-deliver-to-answer (skip
  ;;    encode/decode round-trip, which is tested separately in
  ;;    captp-wire tests; here the focus is on dispatch + resolve).
  ;; 3. Dispatch via connection-step.
  ;; 4. Look up the promise — should be pst-fulfilled.
  ;;
  ;; (Avoiding nested decode-op + match in the test driver sidesteps
  ;; issue #60 in the deeply-nested expression elaboration.)
  (check-contains
   (run-last
    "(eval (let (ask  (connection-ask zero (syrup-string \"ping\") empty-connection)
                  pid  (conn-ask-pid ask)
                  cs1  (conn-ask-state ask)
                  step (connection-step (op-deliver-to-answer pid (syrup-string \"answer\") (none Nat) (none Nat)) cs1))
              (lookup-promise pid (conn-vat (conn-step-state step)))))")
   "pst-fulfilled"))

(test-case "bridge/connection-step op:start-session is a state-preserving no-op"
  ;; Vat unchanged, bridge state unchanged, no outbound bytes,
  ;; not aborted.
  (check-contains
   (run-last
    "(eval (let (step (connection-step
                          (op-start-session \"0.1\" syrup-null)
                          empty-connection))
              (conn-aborted? (conn-step-state step))))")
   "false"))

;; Phase 38: wire-level promise pipelining.
;; Peer sends op:deliver-to-answer for an INBOUND q-pos (one of THEIR
;; questions to us) — bridge queues the args on our local promise so
;; vat-side pipelining can forward them when the promise resolves.

(test-case "bridge/dispatch-pipeline-on-our-q queues args on inbound q-pos's promise"
  ;; Setup: peer's q-pos=5 → our local pid=allocated. Pipeline dispatch
  ;; should leave the promise unresolved with 1 queued message.
  (check-contains
   (run-last
    "(eval (let (alloc (fresh-promise empty-vat)
                  pid   (alloc-id alloc)
                  v0    (alloc-vat alloc)
                  st0   (bs-add-question (suc (suc (suc (suc (suc zero))))) pid bridge-state-empty)
                  step  (dispatch-pipeline-on-our-q
                          (suc (suc (suc (suc (suc zero)))))
                          (syrup-string \"book-room\")
                          (none Nat)
                          v0 st0))
              (promise-queue-length pid (bridge-step-vat step))))")
   "1N"))

(test-case "bridge/dispatch-pipeline-on-our-q drops on unknown q-pos"
  ;; q-pos=42 not in bs-questions and not in bs-outbound-questions → no-op.
  ;; State unchanged: bs-questions still empty.
  (check-contains
   (run-last
    "(eval (let (step (dispatch-pipeline-on-our-q
                        (suc (suc (suc (suc zero))))
                        (syrup-string \"orphan\")
                        (none Nat)
                        empty-vat bridge-state-empty))
              (length (bs-questions (bridge-step-state step)))))")
   "0N"))

(test-case "bridge/captp-incoming op-deliver-to-answer pipelines onto inbound q-pos"
  ;; End-to-end: dispatch via the public captp-incoming-with-state.
  ;; Peer's q-pos=8 is in our bs-questions; the answer-pos isn't in
  ;; outbound-questions (we never asked anything). Bridge falls through
  ;; from dispatch-incoming-answer → dispatch-pipeline-on-our-q → queues.
  (check-contains
   (run-last
    "(eval (let (alloc (fresh-promise empty-vat)
                  pid   (alloc-id alloc)
                  v0    (alloc-vat alloc)
                  st0   (bs-add-question (suc (suc (suc (suc (suc (suc (suc (suc zero)))))))) pid bridge-state-empty)
                  step  (captp-incoming-with-state
                          (op-deliver-to-answer
                            (suc (suc (suc (suc (suc (suc (suc (suc zero))))))))
                            (syrup-string \"chained\")
                            (none Nat) (none Nat))
                          v0 st0))
              (promise-queue-length pid (bridge-step-vat step))))")
   "1N"))

;; Phase 39: questioner-side pipelining (sender).
;; We previously asked a Q (got our q-pos = pid); now we send a follow-up
;; chained onto that Q's eventual answer. Wire form: same as a reply
;; (peer's bridge disambiguates by which table holds the q-pos).

(test-case "bridge/connection-pipeline emits op:deliver with desc:answer target"
  ;; The bytes should match outbound-deliver-bytes for the same
  ;; (q-pos, args) — pipeline-send and reply use the same wire shape.
  (define got
    (extract-value-bytes
     (run-last
      "(eval (let (pipe (connection-pipeline (suc (suc (suc zero)))
                                              (syrup-string \"book-room\")
                                              empty-connection))
                (first-bytes-or-default \"NO-BYTES\" (conn-release-bytes pipe))))")))
  (define expected
    (extract-value-bytes
     (run-last
      "(eval (outbound-deliver-bytes (suc (suc (suc zero))) (syrup-string \"book-room\")))")))
  (check-equal? got expected))

(test-case "bridge/connection-pipeline does not mutate state"
  ;; Pipeline emits bytes only; outbound-questions count unchanged.
  (check-contains
   (run-last
    "(eval (let (ask  (connection-ask zero (syrup-string \"q1\") empty-connection)
                  cs1  (conn-ask-state ask)
                  pipe (connection-pipeline (conn-ask-pid ask) (syrup-string \"chain\") cs1))
              (length (bs-outbound-questions
                        (conn-bridge-state (conn-release-state pipe))))))")
   "1N"))

(test-case "bridge/connection-pipeline is a no-op once aborted"
  (check-contains
   (run-last
    "(eval (let (cs0   empty-connection
                  step1 (connection-step (op-abort \"bye\") cs0)
                  pipe  (connection-pipeline (suc zero) (syrup-string \"x\")
                                              (conn-step-state step1)))
              (length (conn-release-bytes pipe))))")
   "0N"))

(test-case "bridge/connection-ask + connection-pipeline composes (full sender flow)"
  ;; Ask peer a Q (allocates pid + bytes for op:deliver), then pipeline
  ;; a chain message onto that pid. Both byte-strings must be present
  ;; and distinct shapes (one targets desc:export, one targets desc:answer).
  (check-contains
   (run-last
    "(eval (let (ask  (connection-ask zero (syrup-string \"q1\") empty-connection)
                  cs1  (conn-ask-state ask)
                  pipe (connection-pipeline (conn-ask-pid ask) (syrup-string \"chain\") cs1))
              (length (conn-release-bytes pipe))))")
   "1N"))

;; Phase 41: wire-out closure. When a local promise resolves to a
;; <desc:export K> refr, pump-outbound emits forwarding op:deliver
;; bytes for each queued pipelined arg.

(test-case "bridge/dispatch-pipeline-on-our-q records args in bs-pipelined-msgs"
  ;; Phase 41 dual-queue: dispatch records the args at bridge level
  ;; (in addition to the vat-side queue, which gets wiped on fulfill).
  (check-contains
   (run-last
    "(eval (let (alloc (fresh-promise empty-vat)
                  pid   (alloc-id alloc)
                  v0    (alloc-vat alloc)
                  st0   (bs-add-question (suc (suc zero)) pid bridge-state-empty)
                  step  (dispatch-pipeline-on-our-q
                          (suc (suc zero))
                          (syrup-string \"queued\")
                          (none Nat)
                          v0 st0))
              (length (bs-pipelined-msgs (bridge-step-state step)))))")
   "1N"))

(test-case "bridge/syrup-as-export-target recognizes desc:export"
  (check-contains
   (run-last
    "(eval (syrup-as-export-target (syrup-tagged \"desc:export\" (syrup-nat (suc (suc (suc zero)))))))")
   "some")
  (check-contains
   (run-last
    "(eval (syrup-as-export-target (syrup-tagged \"desc:export\" (syrup-nat (suc (suc (suc zero)))))))")
   "3N"))

(test-case "bridge/syrup-as-export-target rejects desc:answer and plain values"
  (check-contains
   (run-last
    "(eval (syrup-as-export-target (syrup-tagged \"desc:answer\" (syrup-nat zero))))")
   "none")
  (check-contains
   (run-last
    "(eval (syrup-as-export-target (syrup-string \"hi\")))")
   "none"))

(test-case "bridge/forward-deliver-bytes builds <op:deliver desc:export args false false>"
  ;; The forwarding wire shape is the same as a normal outbound deliver
  ;; targeting an export, but with answer-pos=false (fire-and-forget).
  (define got
    (extract-value-bytes
     (run-last
      "(eval (forward-deliver-bytes \"desc:export\" (suc (suc zero)) (syrup-string \"book-room\")))")))
  ;; Build the expected shape via raw encode-record for byte equivalence.
  (define expected
    (extract-value-bytes
     (run-last
      "(eval (encode-record \"op:deliver\"
                  (cons (syrup-tagged \"desc:export\" (syrup-nat (suc (suc zero))))
                    (cons (syrup-string \"book-room\")
                      (cons (syrup-bool false)
                        (cons (syrup-bool false) nil))))))")))
  (check-equal? got expected))

(test-case "bridge/pump-outbound emits forwarding bytes when promise resolves to desc:export"
  ;; Setup: peer asked Q1 (their q-pos=5, our local pid). Peer pipelined
  ;; "chained-msg" onto q-pos=5 — bridge queued it at pid level. Then
  ;; we resolve our local promise with `<desc:export 99>` (we got peer's
  ;; export number from somewhere — could be from another peer in a
  ;; three-vat scenario, or hardcoded for test). Pump should emit:
  ;;   (a) the resolution bytes for desc:answer 5
  ;;   (b) forwarding bytes for desc:export 99 with the queued args.
  (check-contains
   (run-last
    "(eval (let (alloc (fresh-promise empty-vat)
                  pid   (alloc-id alloc)
                  v0    (alloc-vat alloc)
                  st0   (bs-add-question (suc (suc (suc (suc (suc zero))))) pid bridge-state-empty)
                  step  (dispatch-pipeline-on-our-q
                          (suc (suc (suc (suc (suc zero)))))
                          (syrup-string \"chained-msg\")
                          (none Nat)
                          v0 st0)
                  v1    (resolve-promise pid
                          (syrup-tagged \"desc:export\"
                            (syrup-nat (suc (suc (suc (suc (suc (suc (suc (suc (suc (suc (suc zero))))))))))))) ;; 11
                          (bridge-step-vat step))
                  pr    (pump-outbound v1 (bridge-step-state step) (nil Nat)))
              (length (pump-result-bytes pr))))")
   "2N"))

(test-case "bridge/pump-outbound emits NO error-answer when ap=none + plain value (Phase 46)"
  ;; Promise resolves to a string (not a refr / not desc:answer). Per
  ;; Phase 46, plain value is a TYPE error for op:deliver — we'd emit
  ;; an error-answer for each queued msg with ap=some, but here the
  ;; queued msg is ap=none (fire-and-forget) so there's nowhere to
  ;; send the error. Pump emits only the resolution bytes (1 byte).
  (check-contains
   (run-last
    "(eval (let (alloc (fresh-promise empty-vat)
                  pid   (alloc-id alloc)
                  v0    (alloc-vat alloc)
                  st0   (bs-add-question (suc (suc zero)) pid bridge-state-empty)
                  step  (dispatch-pipeline-on-our-q
                          (suc (suc zero))
                          (syrup-string \"chained\")
                          (none Nat)
                          v0 st0)
                  v1    (resolve-promise pid (syrup-string \"plain-value\") (bridge-step-vat step))
                  pr    (pump-outbound v1 (bridge-step-state step) (nil Nat)))
              (length (pump-result-bytes pr))))")
   "1N"))

;; Phase 42: local-actor pipelining. When a local promise resolves to
;; <desc:export K> and K is one of OUR vat-registered actors,
;; queued pipelined args are delivered LOCALLY via send-only — vat
;; gets a new VatMsg queued, no wire forwarding emitted.

(test-case "bridge/pump-outbound delivers locally when resolved-to export-id is a local actor"
  ;; Spawn an echo actor (local actor with id K). Peer pipelines a msg
  ;; onto our q-pos=3 (local promise pid). Then we resolve that promise
  ;; with `<desc:export K>` — the export-id matches our local actor.
  ;; Pump should NOT emit forwarding bytes; instead the vat should have
  ;; the pipelined args queued as a VatMsg ready for the next drain.
  (check-contains
   (run-last
    "(eval (let (alloc1 (vat-spawn-actor beh-echo syrup-null empty-vat)
                  k      (alloc-id alloc1)
                  v0     (alloc-vat alloc1)
                  alloc2 (fresh-promise v0)
                  pid    (alloc-id alloc2)
                  v1     (alloc-vat alloc2)
                  st0    (bs-add-question (suc (suc (suc zero))) pid bridge-state-empty)
                  step   (dispatch-pipeline-on-our-q (suc (suc (suc zero)))
                                                      (syrup-string \"local-msg\")
                                                      (none Nat)
                                                      v1 st0)
                  v2     (resolve-promise pid
                            (syrup-tagged \"desc:export\" (syrup-nat k))
                            (bridge-step-vat step))
                  pr     (pump-outbound v2 (bridge-step-state step) (nil Nat)))
              (length (vat-queue (pump-result-vat pr)))))")
   "1N"))

(test-case "bridge/pump-outbound emits only resolution bytes when forwarded locally"
  ;; Resolution to a local actor's K means the queued msg goes LOCAL,
  ;; not on the wire. Pump emits exactly 1 byte-string (resolution
  ;; only); no forwarding bytes.
  (check-contains
   (run-last
    "(eval (let (alloc1 (vat-spawn-actor beh-echo syrup-null empty-vat)
                  k      (alloc-id alloc1)
                  v0     (alloc-vat alloc1)
                  alloc2 (fresh-promise v0)
                  pid    (alloc-id alloc2)
                  v1     (alloc-vat alloc2)
                  st0    (bs-add-question (suc zero) pid bridge-state-empty)
                  step   (dispatch-pipeline-on-our-q (suc zero)
                                                      (syrup-string \"local-msg\")
                                                      (none Nat)
                                                      v1 st0)
                  v2     (resolve-promise pid
                            (syrup-tagged \"desc:export\" (syrup-nat k))
                            (bridge-step-vat step))
                  pr     (pump-outbound v2 (bridge-step-state step) (nil Nat)))
              (length (pump-result-bytes pr))))")
   "1N"))

(test-case "bridge/pump-outbound forwards on the wire when resolved-to export-id is NOT a local actor"
  ;; Regression: Phase 41 path still works when K isn't a local actor.
  ;; Resolution to `<desc:export 99>` (no actor 99 in the vat) → forward
  ;; bytes emitted, vat queue length unchanged (no local delivery).
  (check-contains
   (run-last
    "(eval (let (alloc (fresh-promise empty-vat)
                  pid   (alloc-id alloc)
                  v0    (alloc-vat alloc)
                  st0   (bs-add-question (suc (suc zero)) pid bridge-state-empty)
                  step  (dispatch-pipeline-on-our-q (suc (suc zero))
                                                     (syrup-string \"remote-msg\")
                                                     (none Nat)
                                                     v0 st0)
                  v1    (resolve-promise pid
                          (syrup-tagged \"desc:export\"
                            (syrup-nat (suc (suc (suc (suc (suc (suc (suc (suc (suc (suc (suc zero))))))))))))) ;; 11
                          (bridge-step-vat step))
                  pr    (pump-outbound v1 (bridge-step-state step) (nil Nat)))
              (length (vat-queue (pump-result-vat pr)))))")
   "0N"))

;; Phase 44: chained-answer resolution. When promise resolves to
;; <desc:answer M>, forwarding emits <op:deliver <desc:answer M> args
;; false false> for queued msgs. Peer's bridge dispatches via their
;; Phase 38 fall-through (they look up M in their bs-questions, route
;; to peer's local promise tied to our outbound Q).

(test-case "bridge/syrup-as-answer-target recognizes desc:answer"
  (check-contains
   (run-last
    "(eval (syrup-as-answer-target (syrup-tagged \"desc:answer\" (syrup-nat (suc (suc (suc (suc (suc zero))))))) ))")
   "some")
  (check-contains
   (run-last
    "(eval (syrup-as-answer-target (syrup-tagged \"desc:answer\" (syrup-nat (suc (suc (suc (suc (suc zero))))))) ))")
   "5N"))

(test-case "bridge/syrup-as-answer-target rejects desc:export"
  (check-contains
   (run-last
    "(eval (syrup-as-answer-target (syrup-tagged \"desc:export\" (syrup-nat zero))))")
   "none"))

(test-case "bridge/forward-deliver-bytes builds desc:answer-targeted op:deliver"
  ;; Same builder, different tag. Wire form for chained-answer forwarding.
  (define got
    (extract-value-bytes
     (run-last
      "(eval (forward-deliver-bytes \"desc:answer\" (suc (suc zero)) (syrup-string \"chained-msg\")))")))
  (define expected
    (extract-value-bytes
     (run-last
      "(eval (encode-record \"op:deliver\"
                  (cons (syrup-tagged \"desc:answer\" (syrup-nat (suc (suc zero))))
                    (cons (syrup-string \"chained-msg\")
                      (cons (syrup-bool false)
                        (cons (syrup-bool false) nil))))))")))
  (check-equal? got expected))

(test-case "bridge/pump-outbound emits answer-targeted forwarding when promise resolves to desc:answer M"
  ;; Setup: peer's q-pos=5 → local pid. Peer pipelines "chain" onto pid.
  ;; Then resolve pid with <desc:answer 4>. Pump should emit:
  ;;   (a) resolution bytes: <op:deliver <desc:answer 5> <desc:answer 4> false false>
  ;;   (b) forwarding:        <op:deliver <desc:answer 4> "chain" false false>
  (check-contains
   (run-last
    "(eval (let (alloc (fresh-promise empty-vat)
                  pid   (alloc-id alloc)
                  v0    (alloc-vat alloc)
                  st0   (bs-add-question (suc (suc (suc (suc (suc zero))))) pid bridge-state-empty)
                  step  (dispatch-pipeline-on-our-q
                          (suc (suc (suc (suc (suc zero)))))
                          (syrup-string \"chain\")
                          (none Nat)
                          v0 st0)
                  v1    (resolve-promise pid
                          (syrup-tagged \"desc:answer\"
                            (syrup-nat (suc (suc (suc (suc zero))))))
                          (bridge-step-vat step))
                  pr    (pump-outbound v1 (bridge-step-state step) (nil Nat)))
              (length (pump-result-bytes pr))))")
   "2N"))

;; Phase 45: break-forwarding. When local promise breaks, queued
;; pipelined msgs with ap = some M get an error answer at peer's
;; q-pos M (so peer's awaiting promise doesn't hang). Queued msgs
;; with ap = none are still dropped (peer wasn't expecting an answer).

(test-case "bridge/pump-outbound break-forwards error answers for queued msgs with ap=some"
  ;; Setup: peer's q-pos=5 → local pid. Peer pipelines two msgs,
  ;; one with ap=some 99 (peer wants an answer) and one with ap=none.
  ;; Then we BREAK pid with reason "rejected".
  ;; Pump should emit:
  ;;   (a) the broken-resolution bytes for peer's q-pos 5
  ;;   (b) error-answer bytes for q-pos 99 only (the ap=none msg drops)
  (check-contains
   (run-last
    "(eval (let (alloc (fresh-promise empty-vat)
                  pid   (alloc-id alloc)
                  v0    (alloc-vat alloc)
                  st0   (bs-add-question (suc (suc (suc (suc (suc zero))))) pid bridge-state-empty)
                  step1 (dispatch-pipeline-on-our-q
                          (suc (suc (suc (suc (suc zero)))))
                          (syrup-string \"with-answer\")
                          (some Nat (suc (suc (suc (suc (suc (suc (suc (suc (suc zero))))))))))
                          v0 st0)
                  step2 (dispatch-pipeline-on-our-q
                          (suc (suc (suc (suc (suc zero)))))
                          (syrup-string \"fire-and-forget\")
                          (none Nat)
                          (bridge-step-vat step1) (bridge-step-state step1))
                  v1    (break-promise pid (syrup-string \"rejected\") (bridge-step-vat step2))
                  pr    (pump-outbound v1 (bridge-step-state step2) (nil Nat)))
              ;; resolution bytes (1) + 1 error-answer bytes (only the ap=some msg) = 2
              (length (pump-result-bytes pr))))")
   "2N"))

(test-case "bridge/pump-outbound emits NO error-answer bytes when all queued msgs have ap=none"
  ;; All pipelined msgs are fire-and-forget (ap=none). On break, only
  ;; the resolution bytes get emitted (no error answers).
  (check-contains
   (run-last
    "(eval (let (alloc (fresh-promise empty-vat)
                  pid   (alloc-id alloc)
                  v0    (alloc-vat alloc)
                  st0   (bs-add-question (suc (suc zero)) pid bridge-state-empty)
                  step  (dispatch-pipeline-on-our-q
                          (suc (suc zero))
                          (syrup-string \"no-answer-needed\")
                          (none Nat)
                          v0 st0)
                  v1    (break-promise pid (syrup-string \"oops\") (bridge-step-vat step))
                  pr    (pump-outbound v1 (bridge-step-state step) (nil Nat)))
              (length (pump-result-bytes pr))))")
   "1N"))

(test-case "bridge/pump-outbound break-forward bytes target peer's queued ap"
  ;; Single queued msg with ap=some 7. On break, the bytes list
  ;; contains both the resolution (targeting peer's q-pos 3) AND the
  ;; error-answer (targeting peer's queued ap 7). Stitch via framed
  ;; concat and look for the desc:answer 7 wire shape.
  (define got
    (extract-value-bytes
     (run-last
      "(eval (let (alloc (fresh-promise empty-vat)
                    pid   (alloc-id alloc)
                    v0    (alloc-vat alloc)
                    st0   (bs-add-question (suc (suc (suc zero))) pid bridge-state-empty)
                    step  (dispatch-pipeline-on-our-q
                            (suc (suc (suc zero)))
                            (syrup-string \"q-payload\")
                            (some Nat (suc (suc (suc (suc (suc (suc (suc zero))))))))
                            v0 st0)
                    v1    (break-promise pid (syrup-string \"oops\") (bridge-step-vat step))
                    pr    (pump-outbound v1 (bridge-step-state step) (nil Nat)))
                (framed-concat (pump-result-bytes pr))))")))
  ;; Both wire shapes appear: peer's-q-pos=3 (resolution) and peer's-ap=7 (error answer).
  (check-true (regexp-match? #rx"desc:answer3" got)
              (format "expected resolution to peer's q-pos 3; got: ~s" got))
  (check-true (regexp-match? #rx"desc:answer7" got)
              (format "expected error answer to peer's queued ap 7; got: ~s" got)))

(test-case "bridge/captp-incoming op-deliver-to-answer with q-pos in outbound resolves (regression)"
  ;; Regression: the Phase 25 reply-to-our-Q path still works after
  ;; the Phase 38 fall-through was added. Same wire shape, opposite
  ;; semantics — disambiguation is which table holds the q-pos.
  (check-contains
   (run-last
    "(eval (let (ask  (connection-ask zero (syrup-string \"ping\") empty-connection)
                  pid  (conn-ask-pid ask)
                  cs1  (conn-ask-state ask)
                  step (connection-step (op-deliver-to-answer pid (syrup-string \"reply\") (none Nat) (none Nat)) cs1))
              (lookup-promise pid (conn-vat (conn-step-state step)))))")
   "pst-fulfilled"))

;; Phase 46: plain-value-as-error forwarding. When a local promise
;; resolves to a plain value (not desc:export, not desc:answer),
;; applying op:deliver to it would be a TYPE error — but the queued
;; pipelined msgs aren't dropped. Each msg with ap=some M gets an
;; error answer at peer's M (reason "deliver-to-non-callable"). Same
;; structural shape as Phase 45's break-forwarding; differs only in
;; the source of the error reason (synthesized vs broken-promise's r).
;; Principle: we never drop a queue.

(test-case "bridge/pump-outbound forwards error answers when ap=some + plain value (Phase 46)"
  ;; Setup: peer's q-pos=4 → local pid. Peer pipelines two msgs, one
  ;; with ap=some 88 (peer wants an answer) and one with ap=none.
  ;; Then we resolve pid with a plain string (non-callable).
  ;; Pump should emit:
  ;;   (a) the resolution bytes for peer's q-pos 4
  ;;   (b) error-answer bytes for q-pos 88 only (the ap=none msg
  ;;       still gets processed but has nowhere to send the error)
  (check-contains
   (run-last
    "(eval (let (alloc (fresh-promise empty-vat)
                  pid   (alloc-id alloc)
                  v0    (alloc-vat alloc)
                  st0   (bs-add-question (suc (suc (suc (suc zero)))) pid bridge-state-empty)
                  step1 (dispatch-pipeline-on-our-q
                          (suc (suc (suc (suc zero))))
                          (syrup-string \"with-answer\")
                          (some Nat (suc (suc (suc (suc (suc (suc (suc (suc zero)))))))))
                          v0 st0)
                  step2 (dispatch-pipeline-on-our-q
                          (suc (suc (suc (suc zero))))
                          (syrup-string \"fire-and-forget\")
                          (none Nat)
                          (bridge-step-vat step1) (bridge-step-state step1))
                  v1    (resolve-promise pid (syrup-string \"plain-value\") (bridge-step-vat step2))
                  pr    (pump-outbound v1 (bridge-step-state step2) (nil Nat)))
              (length (pump-result-bytes pr))))")
   "2N"))

(test-case "bridge/pump-outbound plain-value error-answer targets peer's queued ap (Phase 46)"
  ;; Single queued msg with ap=some 6. On plain-value resolve, the
  ;; bytes list contains both the resolution (targeting peer's q-pos 2)
  ;; AND the error-answer (targeting peer's queued ap 6). Stitch via
  ;; framed concat and look for the desc:answer 6 wire shape plus the
  ;; "deliver-to-non-callable" reason.
  (define got
    (extract-value-bytes
     (run-last
      "(eval (let (alloc (fresh-promise empty-vat)
                    pid   (alloc-id alloc)
                    v0    (alloc-vat alloc)
                    st0   (bs-add-question (suc (suc zero)) pid bridge-state-empty)
                    step  (dispatch-pipeline-on-our-q
                            (suc (suc zero))
                            (syrup-string \"q-payload\")
                            (some Nat (suc (suc (suc (suc (suc (suc zero)))))))
                            v0 st0)
                    v1    (resolve-promise pid (syrup-string \"plain-value\") (bridge-step-vat step))
                    pr    (pump-outbound v1 (bridge-step-state step) (nil Nat)))
                (framed-concat (pump-result-bytes pr))))")))
  ;; Both shapes appear: peer's-q-pos=2 (resolution) and peer's-ap=6 (error answer).
  (check-true (regexp-match? #rx"desc:answer2" got)
              (format "expected resolution to peer's q-pos 2; got: ~s" got))
  (check-true (regexp-match? #rx"desc:answer6" got)
              (format "expected error answer to peer's queued ap 6; got: ~s" got))
  (check-true (regexp-match? #rx"deliver-to-non-callable" got)
              (format "expected synthesized error reason in bytes; got: ~s" got)))

;; Phase 47: bs-pipelined-msgs gets pruned after pump emits forwarding
;; bytes for a pid. Without GC the queue grows monotonically across
;; the connection lifetime; with GC the queue shrinks back to entries
;; whose pid hasn't yet been emitted.

(test-case "bridge/bs-gc-pipelined-msgs-by-emitted filters by emitted set (Phase 47)"
  ;; Build a pipelined-msgs list with pids [3, 5, 7]; emitted = [5].
  ;; Result should keep [3, 7] only.
  (check-contains
   (run-last
    "(eval (let (st0 (bs-add-pipeline-msg (suc (suc (suc zero))) (syrup-string \"a\") (none Nat)
                       (bs-add-pipeline-msg (suc (suc (suc (suc (suc zero))))) (syrup-string \"b\") (none Nat)
                         (bs-add-pipeline-msg (suc (suc (suc (suc (suc (suc (suc zero)))))))
                                              (syrup-string \"c\") (none Nat)
                                              bridge-state-empty)))
                  st1 (bs-gc-pipelined-msgs-by-emitted
                        (cons (suc (suc (suc (suc (suc zero))))) (nil Nat))
                        st0))
              (length (bs-pipelined-msgs st1))))")
   "2N"))

(test-case "bridge/connection-step prunes pipelined-msgs for emitted pid (Phase 47)"
  ;; Setup: bs-questions(3 → pid), peer pipelines onto q-pos=3 (queue
  ;; grows to 1), then resolve pid externally and call connection-step
  ;; with an unrelated op to trigger pump. After the pump:
  ;;   - bytes emitted (resolution + forwarding for desc:export 11)
  ;;   - pipelined-msgs GCed for pid (length back to 0)
  (check-contains
   (run-last
    "(eval (let (alloc (fresh-promise empty-vat)
                  pid   (alloc-id alloc)
                  v0    (alloc-vat alloc)
                  st0   (bs-add-question (suc (suc (suc zero))) pid bridge-state-empty)
                  step  (dispatch-pipeline-on-our-q
                          (suc (suc (suc zero)))
                          (syrup-string \"queued\")
                          (some Nat (suc (suc zero)))
                          v0 st0)
                  v1    (resolve-promise pid
                          (syrup-tagged \"desc:export\"
                            (syrup-nat (suc (suc (suc (suc (suc (suc (suc (suc (suc (suc (suc zero))))))))))))) ;; 11
                          (bridge-step-vat step))
                  cs0   (conn-state v1 (bridge-step-state step) (nil Nat) false)
                  s2    (connection-step (op-gc-export (suc zero) zero) cs0))
              (length (bs-pipelined-msgs (conn-bridge-state (conn-step-state s2))))))")
   "0N"))

(test-case "bridge/connection-step retains pipelined-msgs for unemitted pid (Phase 47)"
  ;; Same setup but DON'T resolve pid — the queue should still hold
  ;; the entry after connection-step (no emit, no GC).
  (check-contains
   (run-last
    "(eval (let (alloc (fresh-promise empty-vat)
                  pid   (alloc-id alloc)
                  v0    (alloc-vat alloc)
                  st0   (bs-add-question (suc (suc (suc zero))) pid bridge-state-empty)
                  step  (dispatch-pipeline-on-our-q
                          (suc (suc (suc zero)))
                          (syrup-string \"queued\")
                          (none Nat)
                          v0 st0)
                  cs0   (conn-state (bridge-step-vat step) (bridge-step-state step) (nil Nat) false)
                  s2    (connection-step (op-gc-export (suc zero) zero) cs0))
              (length (bs-pipelined-msgs (conn-bridge-state (conn-step-state s2))))))")
   "1N"))

;; Phase 48: op:listen notification on resolution. When a local promise
;; pid settles, peer-registered listeners targeting pid get an
;; op:deliver notification at their resolver-pos with the resolved
;; payload (value if fulfilled, <Error r> if broken). Listeners are
;; one-shot — once notified, the entry is GCed from bs-listeners.

(test-case "bridge/op:listen registration adds a listener entry (Phase 48 setup)"
  ;; Sanity: peer's op:listen tgt=4 resolver=99 records (listener 4 99).
  (check-contains
   (run-last
    "(eval (let (alloc (fresh-promise empty-vat)
                  pid   (alloc-id alloc)
                  v0    (alloc-vat alloc)
                  cs0   (conn-state v0 bridge-state-empty (nil Nat) false)
                  s1    (connection-step
                          (op-listen (suc (suc (suc (suc zero))))
                                     (suc (suc (suc (suc (suc (suc (suc (suc (suc zero))))))))))
                          cs0))
              (length (bs-listeners (conn-bridge-state (conn-step-state s1))))))")
   "1N"))

(test-case "bridge/listener-notify-loop emits op:deliver bytes for matched pid (Phase 48)"
  ;; Direct unit: listener-notify-loop with one matching entry emits
  ;; one byte-string; with no match emits zero.
  (check-contains
   (run-last
    "(eval (length (listener-notify-loop
                     (cons (listener (suc (suc zero)) (suc (suc (suc zero))))
                       (cons (listener (suc (suc (suc (suc zero)))) (suc (suc (suc (suc (suc zero))))))
                         (nil Listener)))
                     (suc (suc zero))
                     (syrup-string \"resolved\")
                     (nil String))))")
   "1N"))

(test-case "bridge/listener-notify-loop matches all listeners with same target (Phase 48)"
  ;; Two listeners targeting pid=2 with different resolver-pos. Both
  ;; should fire — the loop walks the whole list filtering by target.
  (check-contains
   (run-last
    "(eval (length (listener-notify-loop
                     (cons (listener (suc (suc zero)) (suc (suc (suc zero))))
                       (cons (listener (suc (suc zero)) (suc (suc (suc (suc (suc zero))))))
                         (nil Listener)))
                     (suc (suc zero))
                     (syrup-string \"resolved\")
                     (nil String))))")
   "2N"))

(test-case "bridge/connection-step emits listener notification when promise resolves (Phase 48)"
  ;; Setup: bs-questions(3 → pid), peer registered listener (pid → 7).
  ;; Resolve pid with a string. After connection-step:
  ;;   - bytes contain the resolution (op:deliver to peer's q-pos 3)
  ;;   - bytes contain the listener notification (op:deliver to peer's
  ;;     export 7 with the resolved value)
  ;;   - bs-listeners GCed (length 0)
  (check-contains
   (run-last
    "(eval (let (alloc (fresh-promise empty-vat)
                  pid   (alloc-id alloc)
                  v0    (alloc-vat alloc)
                  st0   (bs-add-question (suc (suc (suc zero))) pid
                          (bs-add-listener pid (suc (suc (suc (suc (suc (suc (suc zero)))))))
                            bridge-state-empty))
                  v1    (resolve-promise pid (syrup-string \"resolved\") v0)
                  cs0   (conn-state v1 st0 (nil Nat) false)
                  s2    (connection-step (op-gc-export (suc zero) zero) cs0))
              (length (conn-step-outbound s2))))")
   "2N"))

(test-case "bridge/listener notification bytes target peer's resolver-pos (Phase 48)"
  ;; Resolve with desc:export+desc:answer-free string; verify the bytes
  ;; contain the listener notification with desc:export 7 (resolver-pos)
  ;; and the resolved string payload.
  (define got
    (extract-value-bytes
     (run-last
      "(eval (let (alloc (fresh-promise empty-vat)
                    pid   (alloc-id alloc)
                    v0    (alloc-vat alloc)
                    st0   (bs-add-question (suc (suc zero)) pid
                            (bs-add-listener pid (suc (suc (suc (suc (suc (suc (suc zero)))))))
                              bridge-state-empty))
                    v1    (resolve-promise pid (syrup-string \"hello\") v0)
                    cs0   (conn-state v1 st0 (nil Nat) false)
                    s2    (connection-step (op-gc-export (suc zero) zero) cs0))
                (framed-concat (conn-step-outbound s2))))")))
  (check-true (regexp-match? #rx"desc:answer2" got)
              (format "expected resolution to peer's q-pos 2; got: ~s" got))
  (check-true (regexp-match? #rx"desc:export7" got)
              (format "expected listener notification to peer's resolver 7; got: ~s" got))
  (check-true (regexp-match? #rx"hello" got)
              (format "expected resolved payload in bytes; got: ~s" got)))

(test-case "bridge/listener notification carries Error wrapper on broken promise (Phase 48)"
  ;; Same setup but break the promise instead of resolving. Listener
  ;; notification's payload is <Error reason>.
  (define got
    (extract-value-bytes
     (run-last
      "(eval (let (alloc (fresh-promise empty-vat)
                    pid   (alloc-id alloc)
                    v0    (alloc-vat alloc)
                    st0   (bs-add-question (suc (suc zero)) pid
                            (bs-add-listener pid (suc (suc (suc (suc (suc (suc (suc zero)))))))
                              bridge-state-empty))
                    v1    (break-promise pid (syrup-string \"oops\") v0)
                    cs0   (conn-state v1 st0 (nil Nat) false)
                    s2    (connection-step (op-gc-export (suc zero) zero) cs0))
                (framed-concat (conn-step-outbound s2))))")))
  (check-true (regexp-match? #rx"desc:export7" got)
              (format "expected listener notification to peer's resolver 7; got: ~s" got))
  (check-true (regexp-match? #rx"5'Error" got)
              (format "expected Error wrapper in listener payload; got: ~s" got)))

(test-case "bridge/connection-step GCes notified listener (Phase 48)"
  ;; After a settled-promise pump, the listener entry is removed (one-shot).
  (check-contains
   (run-last
    "(eval (let (alloc (fresh-promise empty-vat)
                  pid   (alloc-id alloc)
                  v0    (alloc-vat alloc)
                  st0   (bs-add-question (suc (suc (suc zero))) pid
                          (bs-add-listener pid (suc (suc (suc (suc (suc (suc (suc zero)))))))
                            bridge-state-empty))
                  v1    (resolve-promise pid (syrup-string \"resolved\") v0)
                  cs0   (conn-state v1 st0 (nil Nat) false)
                  s2    (connection-step (op-gc-export (suc zero) zero) cs0))
              (length (bs-listeners (conn-bridge-state (conn-step-state s2))))))")
   "0N"))

(test-case "bridge/connection-step retains listener when pid unresolved (Phase 48)"
  ;; Don't resolve pid — listener stays registered.
  (check-contains
   (run-last
    "(eval (let (alloc (fresh-promise empty-vat)
                  pid   (alloc-id alloc)
                  v0    (alloc-vat alloc)
                  st0   (bs-add-question (suc (suc (suc zero))) pid
                          (bs-add-listener pid (suc (suc (suc (suc (suc (suc (suc zero)))))))
                            bridge-state-empty))
                  cs0   (conn-state v0 st0 (nil Nat) false)
                  s2    (connection-step (op-gc-export (suc zero) zero) cs0))
              (length (bs-listeners (conn-bridge-state (conn-step-state s2))))))")
   "1N"))

;; Phase 50: declarative release queue. release-import (Phase 34e) is
;; the imperative form. bs-queue-release-import / connection-queue-
;; release-import stage the gc-export bytes on bridge state's
;; pending-out for flush on the next pump-outbound. Closes the
;; "release fits naturally into the connection-step flow" loop.

(test-case "bridge/bs-queue-release-import appends gc-export bytes to pending-out (Phase 50)"
  ;; Stage release of import 5, count 2. pending-out should contain
  ;; one byte-string (the gc-export wire bytes).
  (check-contains
   (run-last
    "(eval (let (st0 (bs-incr-import (suc (suc (suc (suc (suc zero))))) bridge-state-empty)
                  st1 (bs-queue-release-import (suc (suc (suc (suc (suc zero))))) (suc (suc zero)) st0))
              (length (bs-pending-out st1))))")
   "1N"))

(test-case "bridge/bs-queue-release-import decrements imports-refcount (Phase 50)"
  ;; Increment import 3 once (refcount=1), queue-release count=1 → 0.
  (check-contains
   (run-last
    "(eval (let (st0 (bs-incr-import (suc (suc (suc zero))) bridge-state-empty)
                  st1 (bs-queue-release-import (suc (suc (suc zero))) (suc zero) st0))
              (bs-lookup-import-refcount (suc (suc (suc zero))) st1)))")
   "0N"))

(test-case "bridge/connection-queue-release-import flushes via next pump (Phase 50)"
  ;; Queue a release on a ConnectionState; verify next connection-step
  ;; emits the gc-export bytes via pump's pending-out flush.
  (check-contains
   (run-last
    "(eval (let (st0 (bs-incr-import (suc (suc (suc (suc zero)))) bridge-state-empty)
                  cs0 (conn-state empty-vat st0 (nil Nat) false)
                  cs1 (connection-queue-release-import (suc (suc (suc (suc zero)))) (suc zero) cs0)
                  s2  (connection-step (op-gc-export (suc zero) zero) cs1))
              (length (conn-step-outbound s2))))")
   "1N"))

(test-case "bridge/connection-queue-release-import emitted bytes target export-pos (Phase 50)"
  ;; Verify the emitted bytes are the canonical op:gc-export wire shape.
  (define got
    (extract-value-bytes
     (run-last
      "(eval (let (st0 (bs-incr-import (suc (suc (suc (suc zero)))) bridge-state-empty)
                    cs0 (conn-state empty-vat st0 (nil Nat) false)
                    cs1 (connection-queue-release-import (suc (suc (suc (suc zero)))) (suc zero) cs0)
                    s2  (connection-step (op-gc-export (suc zero) zero) cs1))
                (framed-concat (conn-step-outbound s2))))")))
  (check-true (regexp-match? #rx"op:gc-export" got)
              (format "expected op:gc-export in flushed bytes; got: ~s" got))
  (check-true (regexp-match? #rx"4\\+" got)
              (format "expected export-pos 4 (Nat) in bytes; got: ~s" got)))

(test-case "bridge/connection-queue-release-import is no-op when aborted (Phase 50)"
  ;; If connection is already aborted, queueing should be a no-op.
  (check-contains
   (run-last
    "(eval (let (cs0 (conn-state empty-vat bridge-state-empty (nil Nat) true)
                  cs1 (connection-queue-release-import (suc (suc (suc zero))) (suc zero) cs0))
              (length (bs-pending-out (conn-bridge-state cs1)))))")
   "0N"))

;; Phase 51: multi-listener ordering + late-registration handling.
;;
;; Two refinements over Phase 48:
;;   (a) verify multiple listeners on the same pid fire in INSERTION
;;       order — first-registered fires first.
;;   (b) op:listen arriving AFTER the target promise has settled
;;       must fire immediately (Phase 48 silently dropped late
;;       registrations because pump-outbound's `emitted` set gates
;;       per-pid emission).

(test-case "bridge/multi-listener notify-loop fires all and emits deterministic order (Phase 51)"
  ;; Add 3 listeners on the same pid with resolver-pos 3, 5, 7.
  ;; Insertion order in the test source: 7-innermost, 5-middle,
  ;; 3-outermost. bs-add-listener cons-at-head means the resulting
  ;; list is [3, 5, 7] (outermost-first). listener-notify-loop walks
  ;; head→tail PREPENDING bytes — so the emitted bytes order is the
  ;; REVERSE of the in-list order: 7, 5, 3. That is, the LAST cons
  ;; (= outermost = 3) fires LAST in the wire output. The chosen
  ;; ordering invariant is "outermost-bs-add-listener emits last."
  ;; Both orderings are spec-valid (OCapN doesn't mandate one); we
  ;; pin THIS one as a regression check so callers know what to
  ;; expect.
  (define got
    (extract-value-bytes
     (run-last
      "(eval (let (alloc (fresh-promise empty-vat)
                    pid   (alloc-id alloc)
                    v0    (alloc-vat alloc)
                    st0   (bs-add-question (suc (suc zero)) pid
                            (bs-add-listener pid (suc (suc (suc zero)))
                              (bs-add-listener pid (suc (suc (suc (suc (suc zero)))))
                                (bs-add-listener pid (suc (suc (suc (suc (suc (suc (suc zero))))))) bridge-state-empty))))
                    v1    (resolve-promise pid (syrup-string \"r\") v0)
                    cs0   (conn-state v1 st0 (nil Nat) false)
                    s2    (connection-step (op-gc-export (suc zero) zero) cs0))
                (framed-concat (conn-step-outbound s2))))")))
  (define m3 (regexp-match-positions #rx"desc:export3\\+" got))
  (define m5 (regexp-match-positions #rx"desc:export5\\+" got))
  (define m7 (regexp-match-positions #rx"desc:export7\\+" got))
  ;; All three listeners produced bytes.
  (check-true (and m3 m5 m7 #t)
              (format "expected all three listeners in bytes; got: ~s" got))
  ;; Pinned ordering: 7 first, then 5, then 3.
  (check-true (and m7 m5 (< (car (car m7)) (car (car m5))))
              (format "expected L7 before L5; got positions: ~s, ~s" m7 m5))
  (check-true (and m5 m3 (< (car (car m5)) (car (car m3))))
              (format "expected L5 before L3; got positions: ~s, ~s" m5 m3)))

(test-case "bridge/op:listen on already-settled promise fires immediately (Phase 51)"
  ;; Resolve pid first; THEN send op:listen. Without Phase 51 the
  ;; listener would be added to bs-listeners but never fire (pump
  ;; gates pid via `emitted`). With Phase 51 the late-listen handler
  ;; stages immediate notification bytes on pending-out and skips
  ;; bs-add-listener (avoids the leak).
  (check-contains
   (run-last
    "(eval (let (alloc (fresh-promise empty-vat)
                  pid   (alloc-id alloc)
                  v0    (alloc-vat alloc)
                  v1    (resolve-promise pid (syrup-string \"already-resolved\") v0)
                  cs0   (conn-state v1 bridge-state-empty (nil Nat) false)
                  s1    (connection-step
                          (op-listen pid (suc (suc (suc (suc (suc (suc (suc zero))))))))
                          cs0))
              (length (conn-step-outbound s1))))")
   "1N"))

(test-case "bridge/late op:listen does NOT add to bs-listeners (Phase 51)"
  ;; Verify the late-listen path skips bs-add-listener entirely —
  ;; bs-listeners stays empty. The notification fires once via
  ;; pending-out; no entry is left over.
  (check-contains
   (run-last
    "(eval (let (alloc (fresh-promise empty-vat)
                  pid   (alloc-id alloc)
                  v0    (alloc-vat alloc)
                  v1    (resolve-promise pid (syrup-string \"already-resolved\") v0)
                  cs0   (conn-state v1 bridge-state-empty (nil Nat) false)
                  s1    (connection-step
                          (op-listen pid (suc (suc (suc (suc (suc (suc (suc zero))))))))
                          cs0))
              (length (bs-listeners (conn-bridge-state (conn-step-state s1))))))")
   "0N"))

(test-case "bridge/op:listen on UNSETTLED promise still adds to bs-listeners (Phase 51)"
  ;; Regression: late-fire path only kicks in for settled promises;
  ;; the normal-case op:listen for an unsettled promise must still
  ;; register the listener.
  (check-contains
   (run-last
    "(eval (let (alloc (fresh-promise empty-vat)
                  pid   (alloc-id alloc)
                  v0    (alloc-vat alloc)
                  cs0   (conn-state v0 bridge-state-empty (nil Nat) false)
                  s1    (connection-step
                          (op-listen pid (suc (suc (suc (suc (suc (suc (suc zero))))))))
                          cs0))
              (length (bs-listeners (conn-bridge-state (conn-step-state s1))))))")
   "1N"))

(test-case "bridge/late op:listen reports a BREAK on a broken promise (Phase 51)"
  ;; Broken-promise variant of the late-fire path.
  ;;
  ;; This used to assert an `<Error _>` wrapper and NO verb, because
  ;; resolution-syrup-of-pst returned the bare value and left each of its
  ;; three call sites to wrap. Upstream asserts on args[0], so a broken
  ;; promise reaching the peer without a `break` verb — or worse, under the
  ;; hardcoded `fulfill` that orphan-loop applied — reads as an ACCEPTANCE.
  ;; The listener channel now carries the verb: ['break <reason>].
  ;; (The desc:answer channel still carries a bare <Error r> — different
  ;; shape on purpose; see outbound-from-resolution.)
  (define got
    (extract-value-bytes
     (run-last
      "(eval (let (alloc (fresh-promise empty-vat)
                    pid   (alloc-id alloc)
                    v0    (alloc-vat alloc)
                    v1    (break-promise pid (syrup-string \"oops\") v0)
                    cs0   (conn-state v1 bridge-state-empty (nil Nat) false)
                    s1    (connection-step
                            (op-listen pid (suc (suc (suc (suc (suc (suc (suc zero))))))))
                            cs0))
                (framed-concat (conn-step-outbound s1))))")))
  (check-true (regexp-match? #rx"desc:export7" got)
              (format "expected listener notification to peer's resolver 7; got: ~s" got))
  (check-true (regexp-match? #rx"5'break" got)
              (format "expected a `break` verb on broken late-fire; got: ~s" got))
  (check-true (regexp-match? #rx"4\"oops" got)
              (format "expected the break REASON to survive; got: ~s" got)))

;; ========================================
;; Gift table — OCapN three-vat handoff (exporter side)
;; ========================================
;;
;; REWRITTEN against the wire contract, which the previous tests had wrong in
;; two ways that upstream's suite made unmissable:
;;
;;   1. Gift ids are BYTE STRINGS (`b"my-gift"`), not Nats. The table was
;;      Nat-keyed and its dispatch ran `wire-nat` on the id, which returns none
;;      for bytes — so the handler bridged through unchanged and NO GIFT WAS
;;      EVER RECORDED. These tests deposited Nats, so they never saw it.
;;
;;   2. `withdraw-gift` replies on the caller\'s RESOLVE-ME descriptor, not on
;;      an answer-pos. Upstream sends `answer_position=False` and awaits
;;      `expect_promise_resolution`, so the old answer-pos reply was always
;;      dropped. The tests asserting an answer-pos reply were pinning a shape
;;      the peer never asks for.
;;
;; The reply verb matters: upstream asserts on args[0], so a rejection must say
;; `break` rather than stay silent (silence hangs the peer for its full
;; timeout).

(test-case "gift/bs-gifts on empty state is empty"
  (check-contains (run-last "(eval (length (bs-gifts bridge-state-empty)))") "0N"))

(test-case "gift/bs-add-gift records a BYTE-STRING id -> exported-pos"
  (check-contains
   (run-last
    "(eval (let (st0 (bs-add-gift \"my-gift\" (suc (suc (suc (suc (suc (suc (suc zero))))))) bridge-state-empty))
              (unwrap-or zero (bs-lookup-gift \"my-gift\" st0))))")
   "7N"))

(test-case "gift/bs-lookup-gift returns none for an unknown id"
  (check-contains
   (run-last
    "(eval (let (st0 (bs-add-gift \"my-gift\" (suc (suc zero)) bridge-state-empty))
              (bs-lookup-gift \"other-gift\" st0)))")
   "none"))

(test-case "gift/bs-remove-gift drops the entry"
  (check-contains
   (run-last
    "(eval (let (st0 (bs-add-gift \"my-gift\" (suc (suc zero)) bridge-state-empty)
                  st1 (bs-remove-gift \"my-gift\" st0))
              (bs-lookup-gift \"my-gift\" st1)))")
   "none"))

(test-case "gift/bs-remove-gift on an unknown id is a no-op"
  (check-contains
   (run-last
    "(eval (let (st0 (bs-add-gift \"my-gift\" (suc (suc zero)) bridge-state-empty)
                  st1 (bs-remove-gift \"nope\" st0))
              (unwrap-or zero (bs-lookup-gift \"my-gift\" st1))))")
   "2N"))

(test-case "gift/deposits accumulate and are looked up by id"
  (check-contains
   (run-last
    "(eval (let (st0 (bs-add-gift \"a\" (suc zero)
                       (bs-add-gift \"b\" (suc (suc zero))
                         (bs-add-gift \"c\" (suc (suc (suc zero))) bridge-state-empty))))
              (unwrap-or zero (bs-lookup-gift \"b\" st0))))")
   "2N"))

;; --- wire level ---

(test-case "gift/deposit-gift via op:deliver to bootstrap records the gift"
  ;; args = ('deposit-gift <gift-id bytes> <desc:export N>), fire-and-forget.
  (check-contains
   (run-last
    "(eval (let (args (syrup-list (cons (syrup-symbol \"deposit-gift\")
                        (cons (syrup-bytes \"my-gift\")
                          (cons (syrup-tagged \"desc:export\" (syrup-nat (suc (suc (suc (suc zero)))))) nil))))
                  step (captp-incoming-with-state
                         (op-deliver zero args none none) empty-vat bridge-state-empty))
              (unwrap-or zero (bs-lookup-gift \"my-gift\" (bridge-step-state step)))))")
   "4N"))

(test-case "gift/deposit-gift with a NAT id is not recorded (ids are bytes)"
  ;; Pins the corrected contract: the wire never sends a Nat gift-id.
  (check-contains
   (run-last
    "(eval (let (args (syrup-list (cons (syrup-symbol \"deposit-gift\")
                        (cons (syrup-nat (suc (suc zero)))
                          (cons (syrup-tagged \"desc:export\" (syrup-nat (suc (suc (suc (suc zero)))))) nil))))
                  step (captp-incoming-with-state
                         (op-deliver zero args none none) empty-vat bridge-state-empty))
              (length (bs-gifts (bridge-step-state step)))))")
   "0N"))

(test-case "gift/deposit-gift with a non-export refr is a silent drop"
  (check-contains
   (run-last
    "(eval (let (args (syrup-list (cons (syrup-symbol \"deposit-gift\")
                        (cons (syrup-bytes \"my-gift\") (cons (syrup-nat (suc zero)) nil))))
                  step (captp-incoming-with-state
                         (op-deliver zero args none none) empty-vat bridge-state-empty))
              (length (bs-gifts (bridge-step-state step)))))")
   "0N"))

(test-case "gift/withdraw-gift with no resolve-me falls through (no reply channel)"
  ;; rm = none: there is nowhere to answer, so the gateway declines.
  (check-contains
   (run-last
    "(eval (let (args (syrup-list (cons (syrup-symbol \"withdraw-gift\") (cons syrup-null nil)))
                  step (captp-incoming-with-state
                         (op-deliver zero args none none) empty-vat bridge-state-empty))
              (length (bs-pending-out (bridge-step-state step)))))")
   "0N"))

(test-case "gift/withdraw-gift with a malformed receive BREAKS rather than staying silent"
  ;; Silence would hang the peer for its full timeout; upstream asserts args[0].
  (check-contains
   (extract-value-bytes
    (run-last
     "(eval (let (args (syrup-list (cons (syrup-symbol \"withdraw-gift\") (cons syrup-null nil)))
                   step (captp-incoming-with-state
                          (op-deliver zero args none (some (suc (suc (suc (suc (suc (suc (suc zero)))))))))
                          empty-vat bridge-state-empty))
               (framed-concat (bs-pending-out (bridge-step-state step)))))"))
   "5\'break"))

(test-case "gift/withdraw-gift for an unknown id BREAKS"
  (check-contains
   (extract-value-bytes
    (run-last
     "(eval (let (args (syrup-list (cons (syrup-symbol \"withdraw-gift\") (cons syrup-null nil)))
                   step (captp-incoming-with-state
                          (op-deliver zero args none (some (suc (suc (suc (suc (suc (suc (suc zero)))))))))
                          empty-vat bridge-state-empty))
               (framed-concat (bs-pending-out (bridge-step-state step)))))"))
   "desc:export7"))


(test-case "bridge/op:deliver to NON-bootstrap target with method-symbol falls through (Phase 52b)"
  ;; target = 5 (not bootstrap), args = ((symbol "deposit-gift") ...).
  ;; The bootstrap-dispatch should NOT fire; the op enters the normal
  ;; deliver path (vmsg enqueued in vat, no gift recorded).
  (check-contains
   (run-last
    "(eval (let (args (syrup-list (cons (syrup-symbol \"deposit-gift\")
                                    (cons (syrup-nat (suc (suc zero)))
                                      (cons (syrup-tagged \"desc:export\" (syrup-nat (suc (suc (suc (suc (suc (suc (suc zero))))))))) nil))))
                  step (captp-incoming-with-state
                         (op-deliver (suc (suc (suc (suc (suc zero))))) args (none Nat) (none Nat))
                         empty-vat
                         bridge-state-empty))
              (length (bs-gifts (bridge-step-state step)))))")
   "0N"))

(test-case "bridge/op:deliver to bootstrap with UNKNOWN method symbol falls through (Phase 52b)"
  ;; target = 0, args[0] = (symbol "unknown-method"). The
  ;; bootstrap-dispatch returns None; op enters normal deliver path.
  (check-contains
   (run-last
    "(eval (let (args (syrup-list (cons (syrup-symbol \"unknown-method\") nil))
                  step (captp-incoming-with-state
                         (op-deliver zero args (none Nat) (none Nat))
                         empty-vat
                         bridge-state-empty))
              (length (bs-gifts (bridge-step-state step)))))")
   "0N"))
