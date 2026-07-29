#lang racket/base

;;;
;;; Tests for prologos::ocapn::vat — local vat (event-loop core).
;;;
;;; Validates vat-spawn, send/send-only, step-vat, run-vat, and the
;;; per-actor behaviour dispatch via step-behavior. Each behaviour
;;; tag (cell, counter, greeter, echo, adder, forwarder, fulfiller)
;;; gets at least one round-trip test exercising its dispatch path.
;;;
;;; Sexp-mode `let` uses the multi-binding flat-pair form:
;;;     (let (a A b B c C) body)
;;; bindings are SEQUENTIAL — `b` may reference `a`. See macros.rkt
;;; let-bindings->nested-fn (foldr over bindings).
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
  "(ns test-ocapn-vat)
(imports (prologos::ocapn::vat :refer-all))
(imports (prologos::ocapn::behavior :refer-all))
(imports (prologos::ocapn::syrup :refer-all))
(imports (prologos::ocapn::promise :refer-all))
(imports (prologos::data::list :refer (List nil cons)))
(imports (prologos::data::option :refer (Option some none unwrap-or)))
(imports (prologos::data::nat :refer (add)))
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
;; Empty vat
;; ========================================

(test-case "vat/empty-vat has no actors"
  (check-contains
   (run-last "(eval (vat-actors empty-vat))") "nil"))

(test-case "vat/empty-vat has no promises"
  (check-contains
   (run-last "(eval (vat-promises empty-vat))") "nil"))

(test-case "vat/empty-vat has empty queue"
  (check-contains
   (run-last "(eval (vat-queue empty-vat))") "nil"))

(test-case "vat/empty-vat next-id is zero"
  (check-contains
   (run-last "(eval (vat-next-id empty-vat))") "0N"))

;; ========================================
;; vat-spawn
;; ========================================

(test-case "vat/vat-spawn echo bumps next-id"
  (check-contains
   (run-last
    "(eval (vat-next-id (alloc-vat (vat-spawn beh-echo syrup-null empty-vat))))")
   "1N"))

(test-case "vat/vat-spawn echo allocates id 0"
  (check-contains
   (run-last
    "(eval (alloc-id (vat-spawn beh-echo syrup-null empty-vat)))")
   "0N"))

(test-case "vat/vat-spawn twice yields ids 0 and 1"
  (check-contains
   (run-last
    "(eval (alloc-id (vat-spawn beh-echo syrup-null
                       (alloc-vat (vat-spawn beh-echo syrup-null empty-vat)))))")
   "1N"))

(test-case "vat/lookup-actor finds spawned actor"
  (check-contains
   (run-last
    "(eval (lookup-actor zero (alloc-vat (vat-spawn beh-echo syrup-null empty-vat))))")
   "some"))

(test-case "vat/lookup-actor on missing id returns none"
  (check-contains
   (run-last
    "(eval (lookup-actor (suc zero) (alloc-vat (vat-spawn beh-echo syrup-null empty-vat))))")
   "none"))

;; ========================================
;; send / send-only
;; ========================================

(test-case "vat/send-only enqueues a message"
  (check-contains
   (run-last
    "(eval (queue-length (send-only zero syrup-null
                                     (alloc-vat (vat-spawn beh-echo syrup-null empty-vat)))))")
   "1N"))

(test-case "vat/send allocates a fresh promise (id = 1 since 0 is the actor)"
  (check-contains
   (run-last
    "(eval (alloc-id (send zero syrup-null
                       (alloc-vat (vat-spawn beh-echo syrup-null empty-vat)))))")
   "1N"))

(test-case "vat/send creates an unresolved promise"
  (check-contains
   (run-last
    "(eval (let (v0 (alloc-vat (vat-spawn beh-echo syrup-null empty-vat))
                  r  (send zero syrup-null v0))
              (unresolved? (unwrap-or fresh
                                       (lookup-promise (alloc-id r) (alloc-vat r))))))")
   "true"))

;; ========================================
;; step-vat: empty queue -> none
;; ========================================

(test-case "vat/step-vat on empty queue returns none"
  (check-contains
   (run-last "(eval (step-vat empty-vat))") "none"))

;; ========================================
;; echo end-to-end
;; ========================================

(test-case "vat/echo end-to-end fulfills answer-promise"
  (check-contains
   (run-last
    "(eval (let (s  (vat-spawn beh-echo syrup-null empty-vat)
                  r  (send zero (syrup-string \"hi\") (alloc-vat s))
                  v2 (run-vat (suc (suc (suc (suc (suc zero))))) (alloc-vat r)))
              (fulfilled? (unwrap-or fresh
                                      (lookup-promise (alloc-id r) v2)))))")
   "true"))

;; ========================================
;; counter end-to-end
;; ========================================

(test-case "vat/counter inc fulfills its result-promise"
  (check-contains
   (run-last
    "(eval (let (s  (vat-spawn beh-counter (syrup-nat zero) empty-vat)
                  r  (send zero (syrup-tagged \"inc\" syrup-null) (alloc-vat s))
                  v2 (run-vat (suc (suc (suc (suc (suc zero))))) (alloc-vat r)))
              (fulfilled? (unwrap-or fresh
                                      (lookup-promise (alloc-id r) v2)))))")
   "true"))

(test-case "vat/counter increment twice updates state"
  (check-contains
   (run-last
    "(eval (let (s  (vat-spawn beh-counter (syrup-nat zero) empty-vat)
                  v1 (send-only zero (syrup-tagged \"inc\" syrup-null) (alloc-vat s))
                  v2 (send-only zero (syrup-tagged \"inc\" syrup-null) v1)
                  v3 (run-vat (suc (suc (suc (suc (suc zero))))) v2))
              (lookup-actor zero v3)))")
   "some"))

;; ========================================
;; greeter end-to-end
;; ========================================

(test-case "vat/greeter resolves greeting+name"
  (check-contains
   (run-last
    "(eval (let (s  (vat-spawn beh-greeter (syrup-string \"hello\") empty-vat)
                  r  (send zero (syrup-string \"world\") (alloc-vat s))
                  v2 (run-vat (suc (suc (suc (suc (suc zero))))) (alloc-vat r)))
              (fulfilled? (unwrap-or fresh
                                      (lookup-promise (alloc-id r) v2)))))")
   "true"))

;; ========================================
;; cell get/set
;; ========================================

(test-case "vat/cell set then get fulfills get-promise"
  (check-contains
   (run-last
    "(eval (let (s   (vat-spawn beh-cell syrup-null empty-vat)
                  v1  (send-only zero
                                  (syrup-tagged \"set\" (syrup-nat (suc (suc zero))))
                                  (alloc-vat s))
                  r2  (send zero (syrup-tagged \"get\" syrup-null) v1)
                  v3  (run-vat (suc (suc (suc (suc (suc zero))))) (alloc-vat r2)))
              (fulfilled? (unwrap-or fresh
                                      (lookup-promise (alloc-id r2) v3)))))")
   "true"))

;; ========================================
;; fulfiller settles a promise from inside an actor
;; ========================================

(test-case "vat/fulfiller settles its target promise"
  (check-contains
   (run-last
    "(eval (let (r0  (fresh-promise empty-vat)
                  pid (alloc-id r0)
                  s   (vat-spawn beh-fulfiller (syrup-promise pid) (alloc-vat r0))
                  v1  (send-only (alloc-id s) (syrup-string \"hello\") (alloc-vat s))
                  v2  (run-vat (suc (suc (suc (suc (suc zero))))) v1))
              (fulfilled? (unwrap-or fresh
                                      (lookup-promise pid v2)))))")
   "true"))

;; ========================================
;; forwarder routes to a target
;; ========================================

(test-case "vat/forwarder drains queue to zero"
  (check-contains
   (run-last
    "(eval (let (s1  (vat-spawn beh-echo syrup-null empty-vat)
                  s2  (vat-spawn beh-forwarder (syrup-refr (alloc-id s1)) (alloc-vat s1))
                  v1  (send-only (alloc-id s2) (syrup-string \"hi\") (alloc-vat s2))
                  v2  (run-vat (suc (suc (suc (suc (suc zero))))) v1))
              (queue-length v2)))")
   "0N"))

;; ========================================
;; adder accumulates
;; ========================================

(test-case "vat/adder accumulates state across two sends"
  (check-contains
   (run-last
    "(eval (let (s   (vat-spawn beh-adder (syrup-nat zero) empty-vat)
                  v1  (send-only zero (syrup-nat (suc (suc zero))) (alloc-vat s))
                  v2  (send-only zero (syrup-nat (suc (suc (suc zero)))) v1)
                  v3  (run-vat (suc (suc (suc (suc (suc zero))))) v2))
              (lookup-actor zero v3)))")
   "some"))

;; ========================================
;; eff-connect
;; ========================================
;;
;; A behaviour is pure and cannot open a socket, which is why the gifter
;; and receiver roles live in Racket at all (gaps doc §0.2). `eff-connect`
;; is the first of the three primitives that changes: the behaviour says
;; what it wants, the vat records it, the driver drains it between steps --
;; the same shape `eff-send-remote` already uses one layer out.

(test-case "vat/eff-connect records a dial request without performing it"
  (check-contains
   (run-last
    "(eval (length (vat-dials (apply-effect (eff-connect \"<15'ocapn-sturdyref>\") empty-vat))))")
   "1N"))

(test-case "vat/a fresh vat has no pending dials"
  (check-contains
   (run-last "(eval (length (vat-dials empty-vat)))") "0N"))

(test-case "vat/clear-dials drops them, so a later step does not re-dial"
  (check-contains
   (run-last
    "(eval (length (vat-dials (clear-dials (apply-effect (eff-connect \"x\") empty-vat)))))")
   "0N"))

(test-case "vat/dials accumulate in request order"
  (check-contains
   (run-last
    "(eval (length (vat-dials (apply-effect (eff-connect \"b\") (apply-effect (eff-connect \"a\") empty-vat)))))")
   "2N"))

(test-case "vat/the sturdyref enlivener asks to connect, and only for a sturdyref"
  ;; The label is gated because this is what makes us open an outbound TCP
  ;; connection on peer-chosen bytes.
  (check-contains
   (run-last
    "(eval (length (step-effects (step-behavior beh-sturdyref-enlivener syrup-null (syrup-list (cons (syrup-tagged \"ocapn-sturdyref\" (syrup-string \"loc\")) nil)) zero))))")
   "1N")
  (check-contains
   (run-last
    "(eval (length (step-effects (step-behavior beh-sturdyref-enlivener syrup-null (syrup-list (cons (syrup-tagged \"not-a-sturdyref\" (syrup-string \"loc\")) nil)) zero))))")
   "0N"))

(test-case "vat/a pending step leaves the answer promise unresolved"
  ;; `act-step-pending` is what lets a behaviour say "I have acted; the answer
  ;; comes from somewhere else". Without it every ActStep answered, so the
  ;; sturdyref enlivener could not exist as an actor at all -- it would settle
  ;; the peer's promise with an invented value and beat the real reply.
  (check-contains
   (run-last
    "(eval (let (sa (vat-spawn beh-sturdyref-enlivener syrup-null empty-vat)
                  pa (fresh-promise (alloc-vat sa))
                  v1 (enqueue-msg (vmsg-deliver (alloc-id sa)
                                     (syrup-list (cons (syrup-tagged \"ocapn-sturdyref\" (syrup-string \"loc\")) nil))
                                     (some Nat (alloc-id pa)))
                                  (alloc-vat pa))
                  v2 (run-vat (suc (suc (suc zero))) v1))
              (fulfilled? (unwrap-or fresh (lookup-promise (alloc-id pa) v2)))))")
   "false"))

(test-case "vat/an ordinary step still settles its answer promise"
  ;; The control: if pending were the default, every answer would hang.
  (check-contains
   (run-last
    "(eval (let (sa (vat-spawn beh-echo syrup-null empty-vat)
                  pa (fresh-promise (alloc-vat sa))
                  v1 (enqueue-msg (vmsg-deliver (alloc-id sa) (syrup-string \"hi\")
                                     (some Nat (alloc-id pa)))
                                  (alloc-vat pa))
                  v2 (run-vat (suc (suc (suc zero))) v1))
              (fulfilled? (unwrap-or fresh (lookup-promise (alloc-id pa) v2)))))")
   "true"))
