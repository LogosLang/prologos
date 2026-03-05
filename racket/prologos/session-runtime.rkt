#lang racket/base

;;;
;;; session-runtime.rkt — Runtime infrastructure for session type execution
;;;
;;; Channel cells for message passing between processes via propagator networks.
;;; This is the RUNTIME layer (S7) — distinct from session-propagators.rkt (S4)
;;; which is the COMPILE-TIME type checking layer.
;;;
;;; S4 cells hold session type fragments; S7 cells hold actual runtime values
;;; (messages, labels). Both share the same propagator.rkt persistent network API.
;;;
;;; Design reference: docs/tracking/2026-03-03_SESSION_TYPE_DESIGN.md
;;;   §10 (Execution Model), §10.6 (Choice as Cell-Write)
;;;

(require "propagator.rkt"
         "sessions.rkt"
         "session-lattice.rkt")

(provide
 ;; Structs
 (struct-out channel-endpoint)
 (struct-out channel-pair)
 (struct-out runtime-network)
 ;; Message lattice
 msg-bot msg-top msg-bot? msg-top?
 msg-lattice-merge
 msg-lattice-contradicts?
 ;; Choice lattice
 choice-bot choice-top choice-bot? choice-top?
 choice-lattice-merge
 choice-lattice-contradicts?
 ;; Network lifecycle
 make-runtime-network
 ;; Channel operations
 rt-new-channel-pair
 rt-register-channel
 rt-lookup-channel
 ;; Session advancement
 rt-fresh-session-cell
 rt-add-session-advance
 ;; Network operations
 rt-run-to-quiescence
 rt-contradiction?
 rt-cell-read
 rt-cell-write)

;; ========================================
;; Message Lattice (flat: bot → value → top)
;; ========================================
;;
;; Messages are write-once per protocol step (design doc §10.2).
;; A second distinct write to the same message cell is a contradiction.

(define msg-bot 'msg-bot)
(define msg-top 'msg-top)

(define (msg-bot? v) (eq? v 'msg-bot))
(define (msg-top? v) (eq? v 'msg-top))

(define (msg-lattice-merge old new)
  (cond
    [(msg-bot? old) new]
    [(msg-bot? new) old]
    [(msg-top? old) msg-top]
    [(msg-top? new) msg-top]
    [(equal? old new) old]
    [else msg-top]))

(define (msg-lattice-contradicts? v) (msg-top? v))

;; ========================================
;; Choice Lattice (flat keyword: bot → :label → top)
;; ========================================
;;
;; Choice cells resolve internal/external choice (design doc §10.6).
;; select writes :label; offer watches partner's choice cell.
;; A second distinct label write is a contradiction (non-determinism).

(define choice-bot 'choice-bot)
(define choice-top 'choice-top)

(define (choice-bot? v) (eq? v 'choice-bot))
(define (choice-top? v) (eq? v 'choice-top))

(define (choice-lattice-merge old new)
  (cond
    [(choice-bot? old) new]
    [(choice-bot? new) old]
    [(choice-top? old) choice-top]
    [(choice-top? new) choice-top]
    [(equal? old new) old]
    [else choice-top]))

(define (choice-lattice-contradicts? v) (choice-top? v))

;; ========================================
;; Structs
;; ========================================

;; A channel endpoint: one side of a bidirectional communication channel.
;; Each endpoint has 4 cells in the propagator network:
;;   msg-out:  process writes outgoing messages here
;;   msg-in:   process reads incoming messages here
;;   session:  current session state (tracks protocol progress)
;;   choice:   for internal/external choice resolution
;;
;; A channel PAIR consists of two endpoints, cross-wired:
;;   A.msg-out → propagator → B.msg-in
;;   B.msg-out → propagator → A.msg-in
(struct channel-endpoint
  (msg-out-cell    ;; cell-id
   msg-in-cell     ;; cell-id
   session-cell    ;; cell-id
   choice-cell)    ;; cell-id
  #:transparent)

;; A channel pair: two cross-wired endpoints.
;; ep-a: the "positive" / initiator endpoint
;; ep-b: the "negative" / responder endpoint (dual session)
(struct channel-pair (ep-a ep-b) #:transparent)

;; Runtime session network: prop-network + channel metadata.
;; Pure value — all operations return new runtime-network values.
;; Follows the elab-network pattern (elaborator-network.rkt).
(struct runtime-network
  (prop-net        ;; prop-network
   channel-info    ;; hasheq : symbol → channel-endpoint
   next-chan-id)   ;; Nat — deterministic counter
  #:transparent)

;; ========================================
;; Runtime Network Lifecycle
;; ========================================

(define (make-runtime-network [fuel 1000000])
  (runtime-network (make-prop-network fuel) (hasheq) 0))

;; Register a named channel endpoint in the runtime network.
(define (rt-register-channel rnet name endpoint)
  (runtime-network
   (runtime-network-prop-net rnet)
   (hash-set (runtime-network-channel-info rnet) name endpoint)
   (runtime-network-next-chan-id rnet)))

;; Look up a channel endpoint by name.
(define (rt-lookup-channel rnet name)
  (hash-ref (runtime-network-channel-info rnet) name #f))

;; Run the runtime network to quiescence.
(define (rt-run-to-quiescence rnet)
  (runtime-network
   (run-to-quiescence (runtime-network-prop-net rnet))
   (runtime-network-channel-info rnet)
   (runtime-network-next-chan-id rnet)))

;; Check if the runtime network hit a contradiction.
(define (rt-contradiction? rnet)
  (net-contradiction? (runtime-network-prop-net rnet)))

;; Read a cell value in the runtime network.
(define (rt-cell-read rnet cid)
  (net-cell-read (runtime-network-prop-net rnet) cid))

;; Write a cell value in the runtime network (via lattice merge).
(define (rt-cell-write rnet cid val)
  (runtime-network
   (net-cell-write (runtime-network-prop-net rnet) cid val)
   (runtime-network-channel-info rnet)
   (runtime-network-next-chan-id rnet)))

;; ========================================
;; Channel Pair Creation
;; ========================================

;; Create a channel pair with cross-wired endpoints.
;; session-type: the session type for endpoint A (B gets dual).
;;
;; Allocates 8 cells (4 per endpoint) and creates 2 cross-wiring propagators:
;;   A.msg-out → B.msg-in, B.msg-out → A.msg-in
;;
;; Session cells: A initialized with session-type, B with (dual session-type).
;; Choice cells: NOT cross-wired — the offer propagator (S7b) directly
;;   watches the partner's choice cell-id per design doc §10.6.
;;
;; Returns (values runtime-network* channel-pair)
(define (rt-new-channel-pair rnet session-type)
  (define net (runtime-network-prop-net rnet))

  ;; --- Endpoint A cells ---
  (define-values (net1 a-out)
    (net-new-cell net msg-bot msg-lattice-merge msg-lattice-contradicts?))
  (define-values (net2 a-in)
    (net-new-cell net1 msg-bot msg-lattice-merge msg-lattice-contradicts?))
  (define-values (net3 a-sess)
    (net-new-cell net2 session-type session-lattice-merge session-lattice-contradicts?))
  (define-values (net4 a-choice)
    (net-new-cell net3 choice-bot choice-lattice-merge choice-lattice-contradicts?))

  ;; --- Endpoint B cells ---
  (define-values (net5 b-out)
    (net-new-cell net4 msg-bot msg-lattice-merge msg-lattice-contradicts?))
  (define-values (net6 b-in)
    (net-new-cell net5 msg-bot msg-lattice-merge msg-lattice-contradicts?))
  (define dual-session (dual session-type))
  (define-values (net7 b-sess)
    (net-new-cell net6 dual-session session-lattice-merge session-lattice-contradicts?))
  (define-values (net8 b-choice)
    (net-new-cell net7 choice-bot choice-lattice-merge choice-lattice-contradicts?))

  ;; --- Cross-wiring propagators ---
  ;; A.msg-out → B.msg-in: when A writes, B receives
  (define-values (net9 _p1)
    (net-add-propagator net8 (list a-out) (list b-in)
      (lambda (n)
        (define v (net-cell-read n a-out))
        (if (msg-bot? v) n
            (net-cell-write n b-in v)))))

  ;; B.msg-out → A.msg-in: when B writes, A receives
  (define-values (net10 _p2)
    (net-add-propagator net9 (list b-out) (list a-in)
      (lambda (n)
        (define v (net-cell-read n b-out))
        (if (msg-bot? v) n
            (net-cell-write n a-in v)))))

  ;; --- Build structs ---
  (define ep-a (channel-endpoint a-out a-in a-sess a-choice))
  (define ep-b (channel-endpoint b-out b-in b-sess b-choice))
  (define pair (channel-pair ep-a ep-b))

  (values
   (runtime-network net10
                    (runtime-network-channel-info rnet)
                    (runtime-network-next-chan-id rnet))
   pair))

;; ========================================
;; Session Advancement
;; ========================================

;; Create a fresh session state cell (for use in session advancement chains).
;; Returns (values prop-network cell-id).
(define (rt-fresh-session-cell net initial-session)
  (net-new-cell net initial-session session-lattice-merge session-lattice-contradicts?))

;; Create a propagator that advances session state from current to next cell.
;;
;; Watches current-cell. When it has a concrete session type:
;;   - If sess-mu: unfolds first, then re-checks
;;   - If matches expected-shape?: writes (extract-cont value) to next-cell
;;   - If wrong shape: writes sess-top to current-cell (protocol violation)
;;
;; This mirrors session-propagators.rkt's add-send-prop / add-recv-prop pattern
;; but is parameterized for reuse across Send, Recv, etc.
;;
;; Returns (values prop-network prop-id).
(define (rt-add-session-advance net current-cell next-cell expected-shape? extract-cont)
  (net-add-propagator net
    (list current-cell) (list next-cell)
    (lambda (n)
      (define raw-sess (net-cell-read n current-cell))
      ;; Unfold recursive sessions before checking shape
      (define sess (if (sess-mu? raw-sess) (unfold-session raw-sess) raw-sess))
      (cond
        [(sess-bot? sess) n]   ;; No info yet, wait
        [(sess-top? sess) n]   ;; Already contradicted
        [(expected-shape? sess)
         (net-cell-write n next-cell (extract-cont sess))]
        ;; Wrong shape → protocol violation
        [else (net-cell-write n current-cell sess-top)]))))
