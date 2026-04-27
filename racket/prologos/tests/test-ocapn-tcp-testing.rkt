#lang racket/base

;;;
;;; Tests for prologos::ocapn::tcp-testing — the tcp-testing-only
;;; netlayer. Mirrors Endo's tcp-test-only.js shape.
;;;
;;; These tests do REAL TCP on 127.0.0.1. We pick a high random
;;; port, start a listener in one Racket thread, dial from another,
;;; exchange one line, and tear down.
;;;
;;; The Prologos library wraps `tcp-listen`/`tcp-accept`/`tcp-connect`
;;; etc. and tags them `:requires (NetCap)`. The tests below use the
;;; FFI directly so we don't need to model NetCap propagation; the
;;; goal is to validate that the FFI works AND the Prologos surface
;;; loads cleanly.
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
         "../multi-dispatch.rkt"
         "../tcp-ffi.rkt")

;; ========================================
;; Prologos surface elaborates
;; ========================================
;;
;; Just load the module. If anything in tcp-testing.prologos breaks
;; the parser or elaborator, the import will throw.

(define shared-preamble
  "(ns test-ocapn-tcp-testing)
(imports (prologos::ocapn::tcp-testing :refer-all))
(imports (prologos::ocapn::locator :refer-all))
(imports (prologos::core::capabilities :refer (NetCap)))
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

(test-case "tcp-testing module loads"
  ;; If the (define-values ... (parameterize ... (process-string preamble))) above
  ;; threw, this test would never run. Reaching here proves the surface
  ;; (foreign declarations + typed wrappers + dial) elaborated.
  (check-true #t))

;; ========================================
;; FFI loopback round-trip
;; ========================================
;;
;; Direct exercise of the FFI that the netlayer wraps. Use a fixed
;; high port (18763) to avoid system port conflicts; rerun cleans up.

(define test-port 18763)

(test-case "tcp-testing/loopback echo end-to-end"
  (tcp-table-clear!)
  (define server-id (tcp-listen test-port))
  (define server-thread
    (thread
      (lambda ()
        (define conn (tcp-accept server-id))
        (tcp-recv-line-ret conn)
        (define received (tcp-recv-cached conn))
        (tcp-send-line conn (string-append "echo:" received))
        (tcp-close conn))))
  (define client (tcp-connect "127.0.0.1" test-port))
  (tcp-send-line client "hello")
  (tcp-recv-line-ret client)
  (define got (tcp-recv-cached client))
  (tcp-close client)
  (thread-wait server-thread)
  (tcp-close server-id)
  (check-equal? got "echo:hello"))

(test-case "tcp-testing/multiple messages on one connection"
  ;; The framing is line-oriented, so multiple sends/recvs should
  ;; all work.
  (tcp-table-clear!)
  (define server-id (tcp-listen (+ test-port 1)))
  (define server-thread
    (thread
      (lambda ()
        (define conn (tcp-accept server-id))
        (for ([_ (in-range 3)])
          (tcp-recv-line-ret conn)
          (define line (tcp-recv-cached conn))
          (tcp-send-line conn (string-append "ack:" line)))
        (tcp-close conn))))
  (define client (tcp-connect "127.0.0.1" (+ test-port 1)))
  (define received '())
  (for ([msg '("one" "two" "three")])
    (tcp-send-line client msg)
    (tcp-recv-line-ret client)
    (set! received (cons (tcp-recv-cached client) received)))
  (tcp-close client)
  (thread-wait server-thread)
  (tcp-close server-id)
  (check-equal? (reverse received)
                '("ack:one" "ack:two" "ack:three")))

(test-case "tcp-testing/two clients can connect to one server"
  (tcp-table-clear!)
  (define server-id (tcp-listen (+ test-port 2)))
  (define server-thread
    (thread
      (lambda ()
        (for ([_ (in-range 2)])
          (define conn (tcp-accept server-id))
          (tcp-recv-line-ret conn)
          (tcp-send-line conn (tcp-recv-cached conn))
          (tcp-close conn)))))
  (define c1 (tcp-connect "127.0.0.1" (+ test-port 2)))
  (tcp-send-line c1 "alpha")
  (tcp-recv-line-ret c1)
  (define got1 (tcp-recv-cached c1))
  (tcp-close c1)
  (define c2 (tcp-connect "127.0.0.1" (+ test-port 2)))
  (tcp-send-line c2 "beta")
  (tcp-recv-line-ret c2)
  (define got2 (tcp-recv-cached c2))
  (tcp-close c2)
  (thread-wait server-thread)
  (tcp-close server-id)
  (check-equal? got1 "alpha")
  (check-equal? got2 "beta"))

(test-case "tcp-testing/handle table cleans up after close"
  (tcp-table-clear!)
  (define server-id (tcp-listen (+ test-port 3)))
  (check-equal? (tcp-table-size) 1)
  (tcp-close server-id)
  (check-equal? (tcp-table-size) 0))
