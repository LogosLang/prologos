#lang racket/base

;;;
;;; session-type-bridge.rkt — Cross-Domain Bridge: Session ↔ Type
;;;
;;; Connects session lattice cells to type lattice cells via the Galois
;;; connection pattern (α/γ), enabling message type checking through
;;; the propagator network.
;;;
;;; S4 (session-propagators.rkt) validates protocol SHAPE (send/recv sequence,
;;; duality, deadlock). This module adds message TYPE validation: when a session
;;; cell has sess-send(A, S), a bridged type cell receives A. After quiescence,
;;; collected type constraints can be checked against expression types.
;;;
;;; Architecture:
;;;   α (session → type): extracts message type from session cell
;;;   γ (type → session): no-op (returns sess-bot — identity under session-lattice-merge)
;;;   Effectively unidirectional: session info flows to type domain.
;;;   Bidirectional flow for dependent sessions (dsend/drecv) is designed into
;;;   the architecture but deferred to S4e+.
;;;
;;; Design reference: docs/tracking/2026-03-03_SESSION_TYPE_DESIGN.md
;;;   §15.6 (Cross-Domain Bridges), §15.7 (Dependent Session ↔ Type Interaction)
;;;
;;; Pattern reference:
;;;   - cap-type-bridge.rkt — Type ↔ Capability via α/γ
;;;   - elaborator-network.rkt P5c — Type ↔ Multiplicity via α/γ
;;;

(require racket/match
         racket/list
         racket/string
         "propagator.rkt"
         "sessions.rkt"
         "session-lattice.rkt"
         "session-propagators.rkt"
         "type-lattice.rkt"
         "processes.rkt"
         "errors.rkt"
         "source-location.rkt"
         "pretty-print.rkt")

(provide
 ;; α/γ functions (for testing and composition)
 send-type-alpha
 recv-type-alpha
 type-to-session-gamma
 ;; Bridge construction
 add-send-type-bridge
 add-recv-type-bridge
 ;; Constraint records
 (struct-out msg-type-constraint)
 (struct-out msg-type-error)
 ;; Extended compilation
 compile-proc-with-type-bridges
 ;; Type-aware checker
 check-session-with-types
 check-type-constraints)

;; ========================================
;; α Functions: Session → Type Extraction
;; ========================================
;;
;; Each α function extracts the message type from a specific session shape.
;; Following the P5c pattern where type->mult-alpha extracts Pi multiplicity.
;;
;; Monotonicity:
;;   sess-bot → type-bot (no info)
;;   sess-send(A, S) → A (concrete type)
;;   sess-top → type-top (contradiction propagates)

;; α for Send: extracts message type from sess-send / sess-dsend
(define (send-type-alpha sess-val)
  (cond
    [(sess-bot? sess-val) type-bot]
    [(sess-top? sess-val) type-top]
    [(sess-send? sess-val)  (sess-send-type sess-val)]
    [(sess-dsend? sess-val) (sess-dsend-type sess-val)]
    [else type-bot]))

;; α for Recv: extracts message type from sess-recv / sess-drecv
(define (recv-type-alpha sess-val)
  (cond
    [(sess-bot? sess-val) type-bot]
    [(sess-top? sess-val) type-top]
    [(sess-recv? sess-val)  (sess-recv-type sess-val)]
    [(sess-drecv? sess-val) (sess-drecv-type sess-val)]
    [else type-bot]))

;; ========================================
;; γ Function: Type → Session (No-op)
;; ========================================
;;
;; Returns sess-bot — identity under session-lattice-merge.
;; Writing sess-bot to a session cell: merge(current, sess-bot) = current.
;; No change → no re-propagation → no infinite loop.
;;
;; Following P5c pattern where mult->type-gamma returns type-bot.

(define (type-to-session-gamma _type-val) sess-bot)

;; ========================================
;; Bridge Construction
;; ========================================
;;
;; Creates a type-lattice cell and wires it to a session cell via
;; net-add-cross-domain-propagator (α/γ pair).
;; Returns (values net type-cell-id).

;; Create a type cell bridged to a session cell for Send message type.
(define (add-send-type-bridge net sess-cell)
  (define-values (net1 type-cell)
    (net-new-cell net type-bot type-lattice-merge type-lattice-contradicts?))
  (define-values (net2 _pid-alpha _pid-gamma)
    (net-add-cross-domain-propagator net1 sess-cell type-cell
      send-type-alpha type-to-session-gamma))
  (values net2 type-cell))

;; Create a type cell bridged to a session cell for Recv message type.
(define (add-recv-type-bridge net sess-cell)
  (define-values (net1 type-cell)
    (net-new-cell net type-bot type-lattice-merge type-lattice-contradicts?))
  (define-values (net2 _pid-alpha _pid-gamma)
    (net-add-cross-domain-propagator net1 sess-cell type-cell
      recv-type-alpha type-to-session-gamma))
  (values net2 type-cell))

;; ========================================
;; Constraint Records
;; ========================================

;; Records a type constraint from a process operation.
;; After quiescence, the caller checks that the expression conforms to the
;; expected type (read from type-cell).
(struct msg-type-constraint
  (channel         ;; symbol — channel name
   direction       ;; 'send or 'recv
   type-cell       ;; cell-id — holds expected message type (from session)
   expression)     ;; any — the process expression (from proc-send/proc-recv)
  #:transparent)

;; Returned when a message type constraint fails.
(struct msg-type-error
  (channel         ;; symbol
   direction       ;; 'send or 'recv
   message)        ;; string — human-readable error
  #:transparent)

;; ========================================
;; Extended Process Compilation
;; ========================================
;;
;; Like compile-proc-to-network but also creates message type cells
;; and collects type constraints. Preserves backward compatibility by
;; being a separate function (does not change compile-proc-to-network's
;; return arity).
;;
;; Returns (values net trace (listof msg-type-constraint))

(define (compile-proc-with-type-bridges net proc channel-cells
                                        [trace (hasheq)] [constraints '()])
  (match proc
    ;; ---- Stop: all channels must be at End ----
    [(proc-stop)
     (define net*
       (for/fold ([n net]) ([(_chan cid) (in-hash channel-cells)])
         (add-stop-prop n cid)))
     (define trace*
       (for/fold ([t trace]) ([(chan cid) (in-hash channel-cells)])
         (trace-add t cid (session-op 'stop chan
                            (format "process stops (expects ~a at end)" chan)))))
     (values net* trace* constraints)]

    ;; ---- Send: constrain channel to Send, create type bridge ----
    [(proc-send expr chan cont)
     (define chan-cid (hash-ref channel-cells chan #f))
     (if (not chan-cid)
         (values net trace constraints)
         (let*-values
           ([(net1 cont-cid) (add-send-prop net chan-cid)]
            [(net2 type-cid) (add-send-type-bridge net1 chan-cid)])
           (define constraints*
             (cons (msg-type-constraint chan 'send type-cid expr) constraints))
           (define trace*
             (trace-add
              (trace-add trace chan-cid
                (session-op 'send chan (format "process sends on ~a" chan)))
              cont-cid
              (session-op 'send chan (format "continuation after send on ~a" chan))))
           (compile-proc-with-type-bridges net2 cont
             (hash-set channel-cells chan cont-cid) trace* constraints*)))]

    ;; ---- Recv: constrain channel to Recv, create type bridge ----
    [(proc-recv chan _type cont)
     (define chan-cid (hash-ref channel-cells chan #f))
     (if (not chan-cid)
         (values net trace constraints)
         (let*-values
           ([(net1 cont-cid) (add-recv-prop net chan-cid)]
            [(net2 type-cid) (add-recv-type-bridge net1 chan-cid)])
           (define constraints*
             (cons (msg-type-constraint chan 'recv type-cid _type) constraints))
           (define trace*
             (trace-add
              (trace-add trace chan-cid
                (session-op 'recv chan (format "process receives from ~a" chan)))
              cont-cid
              (session-op 'recv chan (format "continuation after recv on ~a" chan))))
           (compile-proc-with-type-bridges net2 cont
             (hash-set channel-cells chan cont-cid) trace* constraints*)))]

    ;; ---- Select: constrain to Choice, select label, continue ----
    [(proc-sel chan label cont)
     (define chan-cid (hash-ref channel-cells chan #f))
     (if (not chan-cid)
         (values net trace constraints)
         (let-values ([(net* cont-cid) (add-select-prop net chan-cid label)])
           (define trace*
             (trace-add
              (trace-add trace chan-cid
                (session-op 'select chan
                  (format "process selects label '~a on ~a" label chan)))
              cont-cid
              (session-op 'select chan
                (format "continuation after select '~a on ~a" label chan))))
           (compile-proc-with-type-bridges net* cont
             (hash-set channel-cells chan cont-cid) trace* constraints)))]

    ;; ---- Case/Offer: constrain to Offer, compile each branch ----
    [(proc-case chan proc-branches)
     (define chan-cid (hash-ref channel-cells chan #f))
     (if (not chan-cid)
         (values net trace constraints)
         (let* ([labels (map car proc-branches)])
           (define-values (n bc) (add-offer-prop net chan-cid labels))
           (define trace*
             (trace-add trace chan-cid
               (session-op 'offer chan
                 (format "process offers branches ~a on ~a"
                   (string-join (map (lambda (l) (format "'~a" l)) labels) ", ")
                   chan))))
           (define trace-with-branches
             (for/fold ([t trace*]) ([b (in-list bc)])
               (trace-add t (cdr b)
                 (session-op 'offer chan
                   (format "branch '~a of offer on ~a" (car b) chan)))))
           (for/fold ([net-acc n] [trace-acc trace-with-branches] [c-acc constraints])
                     ([pb (in-list proc-branches)])
             (define lbl (car pb))
             (define p (cdr pb))
             (define cont-cid (cdr (assq lbl bc)))
             (compile-proc-with-type-bridges net-acc p
               (hash-set channel-cells chan cont-cid) trace-acc c-acc))))]

    ;; ---- New: create paired channel cells with duality ----
    [(proc-new session-ty (proc-par p1 p2))
     (define-values (net1 cell-a) (make-session-cell net))
     (define-values (net2 cell-b) (make-session-cell net1))
     (define net3 (add-duality-prop net2 cell-a cell-b))
     (define trace*
       (trace-add
        (trace-add trace cell-a
          (session-op 'new 'ch "channel endpoint A (proc-new)"))
        cell-b
        (session-op 'dual 'ch "channel endpoint B (dual of A)")))
     (define-values (net4 trace** constraints1)
       (compile-proc-with-type-bridges net3 p1
         (hash-set channel-cells 'ch cell-a) trace* constraints))
     (compile-proc-with-type-bridges net4 p2
       (hash-set channel-cells 'ch cell-b) trace** constraints1)]

    ;; ---- Par: split channels ----
    [(proc-par p1 p2)
     (define-values (net* trace* c1)
       (compile-proc-with-type-bridges net p1 channel-cells trace constraints))
     (compile-proc-with-type-bridges net* p2 channel-cells trace* c1)]

    ;; ---- Link: add duality constraint ----
    [(proc-link c1 c2)
     (define c1-cid (hash-ref channel-cells c1 #f))
     (define c2-cid (hash-ref channel-cells c2 #f))
     (if (and c1-cid c2-cid)
         (let ([net* (add-duality-prop net c1-cid c2-cid)])
           (define trace*
             (trace-add
              (trace-add trace c1-cid
                (session-op 'dual c1 (format "linked ~a ↔ ~a (duality)" c1 c2)))
              c2-cid
              (session-op 'dual c2 (format "linked ~a ↔ ~a (duality)" c2 c1))))
           (values net* trace* constraints))
         (values net trace constraints))]

    ;; ---- S5b: Boundary operations ----
    [(proc-open path session-type _cap-type cont)
     (define-values (net1 cell) (make-session-cell net))
     (define trace*
       (trace-add trace cell
         (session-op 'open 'ch (format "opened channel with session type (open)"))))
     (compile-proc-with-type-bridges net1 cont
       (hash-set channel-cells 'ch cell) trace* constraints)]

    [(proc-connect addr session-type _cap-type cont)
     (define-values (net1 cell) (make-session-cell net))
     (define trace*
       (trace-add trace cell
         (session-op 'connect 'ch (format "connected channel with session type (connect)"))))
     (compile-proc-with-type-bridges net1 cont
       (hash-set channel-cells 'ch cell) trace* constraints)]

    [(proc-listen port session-type _cap-type cont)
     (define-values (net1 cell) (make-session-cell net))
     (define trace*
       (trace-add trace cell
         (session-op 'listen 'ch (format "listening channel with session type (listen)"))))
     (compile-proc-with-type-bridges net1 cont
       (hash-set channel-cells 'ch cell) trace* constraints)]

    ;; ---- Fallback ----
    [_ (values net trace constraints)]))

;; ========================================
;; Type Constraint Checking
;; ========================================

;; Check each message type constraint against a type-check function.
;; type-check-fn: (expression expected-type) → boolean
;; Returns 'ok or a msg-type-error.
(define (check-type-constraints net constraints type-check-fn)
  (for/fold ([result 'ok])
            ([c (in-list (reverse constraints))]
             #:break (not (eq? result 'ok)))
    (define expected-type (net-cell-read net (msg-type-constraint-type-cell c)))
    (cond
      [(type-bot? expected-type) result]  ;; no type info yet, skip
      [(type-top? expected-type)
       (msg-type-error (msg-type-constraint-channel c)
                       (msg-type-constraint-direction c)
                       "Message type contradiction in session")]
      [(type-check-fn (msg-type-constraint-expression c) expected-type) result]
      [else
       (msg-type-error (msg-type-constraint-channel c)
                       (msg-type-constraint-direction c)
                       (format "Expected ~a but expression has wrong type"
                         (pp-expr expected-type '())))])))

;; ========================================
;; Type-Aware Session Checker
;; ========================================
;;
;; check-session-with-types: the propagator-based checker with message type
;; checking support. Three modes:
;;   1. type-check-fn = #f → query mode: returns constraints for external use
;;   2. type-check-fn = procedure → check mode: validates message types
;;   3. Falls through to check-session-completeness for deadlock detection
;;
;; Returns:
;;   'ok — protocol AND types match
;;   (cons 'ok-with-constraints constraints) — query mode, protocol ok
;;   session-protocol-error — protocol violation
;;   msg-type-error — message type mismatch

(define (check-session-with-types proc session-type [type-check-fn #f])
  ;; 1. Create empty network
  (define net0 (make-prop-network))
  ;; 2. Create root session cell
  (define-values (net1 self-cell) (make-session-cell net0 session-type))
  ;; 3. Initialize trace
  (define init-trace
    (hasheq self-cell
      (list (session-op 'init 'self
              (format "session type declared as ~a" (pp-session session-type))))))
  ;; 4. Compile with type bridges
  (define channel-cells (hasheq 'self self-cell))
  (define-values (net2 trace constraints)
    (compile-proc-with-type-bridges net1 proc channel-cells init-trace))
  ;; 5. Run to quiescence
  (define net3 (run-to-quiescence net2))
  ;; 6. Check session contradictions first
  (define contradiction-cell (prop-network-contradiction net3))
  (cond
    [contradiction-cell
     (build-session-error net3 trace contradiction-cell session-type)]
    [else
     ;; 7. Check session completeness
     (define completeness (check-session-completeness net3 trace))
     (cond
       [(not (eq? completeness 'ok)) completeness]
       ;; 8. Check type constraints if function provided
       [type-check-fn
        (check-type-constraints net3 constraints type-check-fn)]
       ;; 9. Query mode: return ok with constraints
       [else
        (cons 'ok-with-constraints (reverse constraints))])]))
