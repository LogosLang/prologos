#lang racket/base

;;;
;;; prop-observatory.rkt — Propagator Network Observatory
;;;
;;; General-purpose observability for all propagator networks across all
;;; subsystems: type inference, session types, capability inference,
;;; narrowing, user networks, and future subsystems.
;;;
;;; Core types:
;;;   cell-meta      — Subsystem-agnostic cell metadata
;;;   net-capture    — Snapshot of a network at quiescence
;;;   cross-net-link — Semantic reference between cells in different networks
;;;   observatory    — Session-level container of all captures
;;;
;;; Capture protocol:
;;;   current-observatory — Parameter (#f = off, observatory = on)
;;;   capture-network     — Wraps run-to-quiescence with capture
;;;
;;; Design reference: docs/tracking/2026-03-12_PROPAGATOR_OBSERVATORY.md
;;;

(require "champ.rkt"
         "propagator.rkt")

(provide
 ;; Core data types
 (struct-out cell-meta)
 (struct-out net-capture)
 (struct-out cross-net-link)
 ;; Observatory (opaque — use accessors)
 make-observatory
 current-observatory
 observatory-captures
 observatory-links
 observatory-metadata
 observatory-register-capture!
 observatory-register-link!
 observatory-next-sequence!
 observatory-last-capture-for-subsystem
 ;; Capture protocol
 capture-network
 ;; Cell-meta builder helper
 build-cell-metas-from-network)

;; ========================================
;; Core Data Types
;; ========================================

;; Subsystem-agnostic cell metadata.
;; Replaces elab-cell-info for observatory purposes — generic across all subsystems.
;;   subsystem:  symbol — 'type-inference, 'session, 'capability, 'user, ...
;;   label:      string — human-readable name ("meta-42", "self", "cap:foo")
;;   source-loc: srcloc | #f
;;   domain:     symbol — 'type, 'session-protocol, 'capability-set, 'lattice, ...
;;   extra:      hasheq — subsystem-specific data
(struct cell-meta (subsystem label source-loc domain extra) #:transparent)

;; Snapshot of a single network at quiescence.
;;   id:              symbol — unique per capture (named gensym, e.g., session-cap-123)
;;   subsystem:       symbol — which subsystem produced this
;;   label:           string — human-readable ("session:greeter", "elab:def-factorial")
;;   network:         prop-network — immutable snapshot at quiescence
;;   cell-metas:      champ (cell-id → cell-meta) — metadata per cell
;;   trace:           prop-trace | #f — BSP round trace if tracing was on
;;   status:          symbol — 'complete | 'exception
;;   status-detail:   string | #f — exception message if status = 'exception
;;   timestamp-ms:    real — (current-inexact-milliseconds) at capture time
;;   sequence-number: nat — monotonic within observatory, for unambiguous ordering
;;   parent-id:       symbol | #f — for hierarchical captures (strict tree)
(struct net-capture
  (id subsystem label network cell-metas trace
   status status-detail timestamp-ms sequence-number parent-id)
  #:transparent)

;; Semantic reference between cells in different networks.
;;   from-capture-id: symbol — source capture's id
;;   from-cell-id:    cell-id — source cell
;;   to-capture-id:   symbol — target capture's id
;;   to-cell-id:      cell-id — target cell
;;   relation:        symbol — 'type-of, 'constrains, 'derived-from, ...
(struct cross-net-link
  (from-capture-id from-cell-id to-capture-id to-cell-id relation)
  #:transparent)

;; ========================================
;; Observatory
;; ========================================

;; Session-level container for all captures and cross-network links.
;; Mutable during accumulation (box-of-list), effectively frozen after elaboration.
;; Internal representation — use accessors, not struct-out.
(struct observatory-state
  (captures-box     ;; box of (listof net-capture), newest first
   links-box        ;; box of (listof cross-net-link), newest first
   sequence-box     ;; box of nat, monotonic counter
   metadata)        ;; hasheq — session-level metadata (file uri, etc.)
  #:transparent)

;; Parameter: #f when observatory is off (zero cost), observatory-state when on.
(define current-observatory (make-parameter #f))

;; Create a fresh observatory.
(define (make-observatory [metadata (hasheq)])
  (observatory-state (box '())
                     (box '())
                     (box 0)
                     metadata))

;; Read captures (reversed to chronological order).
(define (observatory-captures obs)
  (reverse (unbox (observatory-state-captures-box obs))))

;; Read links (reversed to chronological order).
(define (observatory-links obs)
  (reverse (unbox (observatory-state-links-box obs))))

;; Read metadata.
(define (observatory-metadata obs)
  (observatory-state-metadata obs))

;; Register a capture (append to front of list).
(define (observatory-register-capture! obs cap)
  (define box (observatory-state-captures-box obs))
  (set-box! box (cons cap (unbox box))))

;; Register a cross-network link.
(define (observatory-register-link! obs link)
  (define box (observatory-state-links-box obs))
  (set-box! box (cons link (unbox box))))

;; Get next sequence number (monotonic, auto-incrementing).
(define (observatory-next-sequence! obs)
  (define box (observatory-state-sequence-box obs))
  (define n (unbox box))
  (set-box! box (add1 n))
  n)

;; Find the most recent capture for a given subsystem.
;; Returns net-capture or #f.
(define (observatory-last-capture-for-subsystem obs subsystem)
  (for/first ([cap (in-list (unbox (observatory-state-captures-box obs)))]
              #:when (eq? (net-capture-subsystem cap) subsystem))
    cap))

;; ========================================
;; Capture Protocol
;; ========================================

;; Wraps run-to-quiescence with observatory capture.
;; When observatory is off (#f), just calls run-to-quiescence directly.
;; When on, captures the network at quiescence and registers it.
;;
;; Returns: prop-network (same as run-to-quiescence)
;;
;; Exception safety: if run-to-quiescence raises, the capture is still
;; registered with status='exception, then the exception is re-raised.
(define (capture-network net subsystem label cell-metas
                         #:parent [parent-id #f]
                         #:trace? [trace? #t])
  (define obs (current-observatory))
  (cond
    [(not obs)
     ;; Observatory off — zero-cost passthrough
     (run-to-quiescence net)]
    [else
     (define cap-id (gensym (string->symbol (format "~a-cap-" subsystem))))
     (define seq (observatory-next-sequence! obs))
     (define ts (current-inexact-milliseconds))
     ;; Install BSP observer if tracing requested
     (define-values (observer-fn get-rounds-fn)
       (if trace?
           (make-trace-accumulator)
           (values #f #f)))
     ;; Run with possible exception capture
     (define result-net #f)
     (define status 'complete)
     (define status-detail #f)
     (with-handlers ([exn:fail?
                      (lambda (e)
                        (set! status 'exception)
                        (set! status-detail (exn-message e))
                        ;; Register the partial capture, then re-raise
                        (define trace
                          (and get-rounds-fn
                               (prop-trace net (get-rounds-fn)
                                           (or result-net net)
                                           (hasheq 'status "exception"))))
                        (observatory-register-capture!
                         obs
                         (net-capture cap-id subsystem label
                                      (or result-net net)
                                      cell-metas trace
                                      status status-detail
                                      ts seq parent-id))
                        (raise e))])
       (set! result-net
             (parameterize ([current-bsp-observer
                             (or observer-fn (current-bsp-observer))])
               (run-to-quiescence net)))
       ;; Build trace from accumulated rounds
       (define trace
         (and get-rounds-fn
              (prop-trace net (get-rounds-fn) result-net
                          (hasheq 'subsystem (symbol->string subsystem)
                                  'label label))))
       ;; Register the capture
       (observatory-register-capture!
        obs
        (net-capture cap-id subsystem label
                     result-net cell-metas trace
                     status status-detail
                     ts seq parent-id))
       result-net)]))

;; ========================================
;; Cell-Meta Builder Helper
;; ========================================

;; Build cell-metas from a prop-network by walking all cells.
;; Produces synthetic labels ("cell-0", "cell-1", ...) and subsystem/domain as given.
;; Useful for user networks and subsystems without rich per-cell metadata.
(define (build-cell-metas-from-network net subsystem domain
                                        #:source-loc [source-loc #f])
  (define cells-champ (prop-network-cells net))
  (define cell-ids (champ-keys cells-champ))
  (for/fold ([cm champ-empty])
            ([cid (in-list cell-ids)])
    (champ-insert cm (cell-id-hash cid) cid
                  (cell-meta subsystem
                          (format "cell-~a" (cell-id-n cid))
                          source-loc
                          domain
                          (hasheq)))))
