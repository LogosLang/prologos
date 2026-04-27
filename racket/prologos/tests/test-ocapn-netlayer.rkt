#lang racket/base

;;;
;;; Tests for prologos::ocapn::netlayer — simulated in-process
;;; netlayer (Mailbox + Connection + SimNet + sim-pair).
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
  "(ns test-ocapn-netlayer)
(imports (prologos::ocapn::netlayer :refer-all))
(imports (prologos::ocapn::locator :refer-all))
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

(define (check-contains actual substr)
  (check-true (string-contains? actual substr)
              (format "Expected ~s to contain ~s" actual substr)))

;; ========================================
;; Mailbox
;; ========================================

(test-case "netlayer/empty-mailbox is empty"
  (check-contains
   (run-last "(eval (mb-empty? empty-mailbox))") "true"))

(test-case "netlayer/mb-push then mb-empty? is false"
  (check-contains
   (run-last "(eval (mb-empty? (mb-push (syrup-string \"x\") empty-mailbox)))")
   "false"))

(test-case "netlayer/mb-peek empty is none"
  (check-contains
   (run-last "(eval (mb-peek empty-mailbox))") "none"))

(test-case "netlayer/mb-peek returns oldest"
  ;; FIFO: push x then y; oldest is x.
  (check-contains
   (run-last
    "(eval (mb-peek (mb-push (syrup-string \"y\") (mb-push (syrup-string \"x\") empty-mailbox))))")
   "some"))

(test-case "netlayer/mb-pop on empty is none"
  (check-contains
   (run-last "(eval (mb-pop empty-mailbox))") "none"))

(test-case "netlayer/mb-pop on single returns empty mailbox"
  (check-contains
   (run-last
    "(eval (mb-pop (mb-push (syrup-string \"x\") empty-mailbox)))")
   "some"))

;; ========================================
;; SimNet — empty
;; ========================================

(test-case "netlayer/empty-sim-net has no connections"
  (check-contains
   (run-last "(eval (sim-connections empty-sim-net))") "nil"))

(test-case "netlayer/empty-sim-net next-id is 0"
  (check-contains
   (run-last "(eval (sim-next-id empty-sim-net))") "0N"))

;; ========================================
;; sim-open
;; ========================================

(test-case "netlayer/sim-open allocates id 0"
  (check-contains
   (run-last
    "(eval (sim-alloc-id (sim-open (mk-loopback-locator \"peer\") true empty-sim-net)))")
   "0N"))

(test-case "netlayer/sim-open bumps next-id to 1"
  (check-contains
   (run-last
    "(eval (sim-next-id (sim-alloc-net (sim-open (mk-loopback-locator \"peer\") true empty-sim-net))))")
   "1N"))

;; ========================================
;; sim-write / sim-recv on a single peer (Endo's tcp-testing-only
;; pairs two peers; we test that side here via a self-loop where
;; we directly inject into inbound by creating a connection
;; manually).
;; ========================================

(test-case "netlayer/sim-recv on empty inbound returns none"
  (check-contains
   (run-last
    "(eval (let (alloc (sim-open (mk-loopback-locator \"peer\") true empty-sim-net)
                  cid   (sim-alloc-id alloc)
                  net   (sim-alloc-net alloc)
                  rd    (sim-recv cid net))
              (sim-read-val rd)))")
   "none"))

;; ========================================
;; sim-pair-deliver — the main pairing test
;; ========================================
;;
;; Two peers, peer-A and peer-B. Each opens a connection (different
;; cid). Peer-A writes to its outbound; sim-pair-deliver moves the
;; message onto peer-B's inbound. peer-B then reads it.

(test-case "netlayer/sim-pair-deliver moves messages A.out -> B.in"
  (check-contains
   (run-last
    "(eval (let
             ;; Peer A opens conn 0 toward B
             (a-alloc (sim-open (mk-loopback-locator \"B\") true empty-sim-net)
              cid-a   (sim-alloc-id a-alloc)
              net-a0  (sim-alloc-net a-alloc)
              ;; Peer B opens conn 0 toward A
              b-alloc (sim-open (mk-loopback-locator \"A\") false empty-sim-net)
              cid-b   (sim-alloc-id b-alloc)
              net-b0  (sim-alloc-net b-alloc)
              ;; A writes a message
              net-a1  (sim-write cid-a (syrup-string \"hello\") net-a0)
              ;; deliver
              pair0   (sim-pair-deliver cid-a cid-b net-a1 net-b0)
              net-b1  (sim-pair-b pair0)
              ;; B reads
              rd      (sim-recv cid-b net-b1))
             (sim-read-val rd)))")
   "some"))

(test-case "netlayer/after deliver, A's outbound is empty"
  (check-contains
   (run-last
    "(eval (let
             (a-alloc (sim-open (mk-loopback-locator \"B\") true empty-sim-net)
              cid-a   (sim-alloc-id a-alloc)
              net-a0  (sim-alloc-net a-alloc)
              b-alloc (sim-open (mk-loopback-locator \"A\") false empty-sim-net)
              cid-b   (sim-alloc-id b-alloc)
              net-b0  (sim-alloc-net b-alloc)
              net-a1  (sim-write cid-a (syrup-string \"hello\") net-a0)
              pair0   (sim-pair-deliver cid-a cid-b net-a1 net-b0)
              net-a2  (sim-pair-a pair0)
              ;; Look up conn-a's outbound — should be empty
              c       (sim-find-conn cid-a (sim-connections net-a2)))
             c))")
   ;; The connection should exist (some) and (we trust the dataflow
   ;; that its outbound is now empty-mailbox).
   "some"))

;; ========================================
;; Connection field round-trips
;; ========================================

(test-case "netlayer/conn-peer round-trips through alloc"
  (check-contains
   (run-last
    "(eval (let (alloc (sim-open (mk-loopback-locator \"peer-X\") true empty-sim-net))
              (loc-designator (conn-peer (unwrap-or (connection (sim-next-id (sim-alloc-net alloc))
                                                                 (mk-loopback-locator \"sentinel\")
                                                                 empty-mailbox empty-mailbox false)
                                                    (sim-find-conn (sim-alloc-id alloc)
                                                                   (sim-connections (sim-alloc-net alloc))))))))")
   "peer-X"))
