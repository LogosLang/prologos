#lang racket/base

;;;
;;; elaborator-network.rkt — Bridge between elaborator and propagator network
;;;
;;; Wraps the PropNetwork API with type-inference-specific semantics:
;;; - Metavariables become cells on a propagator network
;;; - Unification constraints become bidirectional propagators
;;; - Solving runs the network to quiescence
;;;
;;; CRITICAL: This module does NOT depend on metavar-store.rkt. The
;;; elaboration network is pure — all operations return new elab-network
;;; values (structural sharing via CHAMP).
;;;
;;; Phase 2 of the type inference refactoring.
;;; Design reference: docs/tracking/2026-02-25_TYPE_INFERENCE_ON_LOGIC_ENGINE_DESIGN.md §3.2-3.3, §5.2
;;;

(require racket/list
         "propagator.rkt"
         "type-lattice.rkt"
         "champ.rkt"
         "syntax.rkt")

(provide
 ;; Core structs
 (struct-out elab-network)
 (struct-out elab-cell-info)
 (struct-out contradiction-info)
 ;; Network lifecycle
 make-elaboration-network
 ;; Cell operations
 elab-fresh-meta
 elab-cell-read
 elab-cell-write
 elab-cell-info-ref
 ;; Constraints
 elab-add-unify-constraint
 make-unify-propagator
 ;; Solving
 elab-solve
 extract-contradiction-info
 ;; Queries
 elab-cell-solved?
 elab-cell-read-or
 elab-all-cells
 elab-unsolved-cells
 elab-contradicted-cells)

;; ========================================
;; Structs
;; ========================================

;; Per-cell metadata: typing context, expected type, and provenance.
;; Replaces meta-info from metavar-store.rkt for propagator cells.
(struct elab-cell-info
  (ctx          ;; typing context at creation (list of (cons type mult))
   type         ;; expected type of this cell's solution (Expr)
   source)      ;; any — debug/provenance info (string, srcloc, etc.)
  #:transparent)

;; An elaboration network: prop-network + type-inference metadata.
;; Pure value — all operations return new elab-network values.
(struct elab-network
  (prop-net      ;; prop-network (the underlying propagator network)
   cell-info     ;; champ-root : cell-id → elab-cell-info
   next-meta-id) ;; Nat — deterministic counter (reserved for Phase 3 naming)
  #:transparent)

;; Contradiction details for error reporting.
(struct contradiction-info
  (cell-id       ;; cell-id that first contradicted
   cell-meta     ;; elab-cell-info or 'none
   value)        ;; the contradictory cell value (type-top)
  #:transparent)

;; ========================================
;; Network Lifecycle
;; ========================================

;; Create a fresh elaboration network.
(define (make-elaboration-network [fuel 1000000])
  (elab-network (make-prop-network fuel) champ-empty 0))

;; ========================================
;; Cell Operations
;; ========================================

;; Allocate a meta as a cell on the network.
;; Returns (values elab-network* cell-id).
(define (elab-fresh-meta enet ctx type source)
  (define net (elab-network-prop-net enet))
  (define-values (net* cid)
    (net-new-cell net type-bot type-lattice-merge type-lattice-contradicts?))
  (define info (elab-cell-info ctx type source))
  (define h (cell-id-hash cid))
  (values
   (elab-network
    net*
    (champ-insert (elab-network-cell-info enet) h cid info)
    (+ 1 (elab-network-next-meta-id enet)))
   cid))

;; Read a cell's current type value.
(define (elab-cell-read enet cid)
  (net-cell-read (elab-network-prop-net enet) cid))

;; Write a type value to a cell (lattice join via merge-fn).
(define (elab-cell-write enet cid val)
  (elab-network
   (net-cell-write (elab-network-prop-net enet) cid val)
   (elab-network-cell-info enet)
   (elab-network-next-meta-id enet)))

;; Retrieve cell metadata, or 'none if unknown.
(define (elab-cell-info-ref enet cid)
  (champ-lookup (elab-network-cell-info enet) (cell-id-hash cid) cid))

;; ========================================
;; Unification Propagator
;; ========================================
;;
;; A bidirectional propagator: both cell-a and cell-b are inputs AND outputs.
;; When either changes, the propagator fires and writes the unified result to both.
;;
;; Behavior on fire:
;;   1. Both bot: no-op (nothing known yet)
;;   2. One bot, other concrete: write concrete to the bot cell
;;   3. Both concrete, compatible: write unified result to both
;;   4. Both concrete, incompatible: write type-top (contradiction)
;;
;; Termination: guaranteed by net-cell-write's "no change → return same
;; network" guard (propagator.rkt line 175). Bidirectional propagators are
;; enqueued on their own outputs, but the second firing sees merged == old-val
;; and returns unchanged, terminating the loop.

(define (make-unify-propagator cell-a cell-b)
  (lambda (net)
    (define va (net-cell-read net cell-a))
    (define vb (net-cell-read net cell-b))
    (cond
      ;; Both bot: nothing to propagate
      [(and (type-bot? va) (type-bot? vb)) net]
      ;; One bot: propagate the known value
      [(type-bot? va) (net-cell-write net cell-a vb)]
      [(type-bot? vb) (net-cell-write net cell-b va)]
      ;; Both have values: compute lattice join
      [else
       (define unified (type-lattice-merge va vb))
       (if (type-top? unified)
           ;; Contradiction: signal via type-top write
           (net-cell-write net cell-a type-top)
           ;; Compatible: write unified to both cells
           (let ([net* (net-cell-write net cell-a unified)])
             (net-cell-write net* cell-b unified)))])))

;; Add a unification constraint: cells A and B must unify.
;; Returns (values elab-network* prop-id).
(define (elab-add-unify-constraint enet cell-a cell-b)
  (define-values (net* pid)
    (net-add-propagator
     (elab-network-prop-net enet)
     (list cell-a cell-b)    ;; inputs
     (list cell-a cell-b)    ;; outputs (bidirectional)
     (make-unify-propagator cell-a cell-b)))
  (values
   (elab-network net*
                 (elab-network-cell-info enet)
                 (elab-network-next-meta-id enet))
   pid))

;; ========================================
;; Solving
;; ========================================

;; Run the network to quiescence and check for contradictions.
;; Returns (values 'ok elab-network*) or (values 'error contradiction-info).
(define (elab-solve enet)
  (define net* (run-to-quiescence (elab-network-prop-net enet)))
  (define enet*
    (elab-network net*
                  (elab-network-cell-info enet)
                  (elab-network-next-meta-id enet)))
  (if (net-contradiction? net*)
      (values 'error (extract-contradiction-info enet*))
      (values 'ok enet*)))

;; Extract contradiction details from a contradicted network.
(define (extract-contradiction-info enet)
  (define net (elab-network-prop-net enet))
  (define cid (prop-network-contradiction net))
  (cond
    [cid
     (define meta (elab-cell-info-ref enet cid))
     (define val (net-cell-read net cid))
     (contradiction-info cid meta val)]
    [else #f]))

;; ========================================
;; Queries
;; ========================================

;; Is this cell solved (neither bot nor top)?
(define (elab-cell-solved? enet cid)
  (define v (elab-cell-read enet cid))
  (and (not (type-bot? v)) (not (type-top? v))))

;; Read cell value, defaulting bot to a given fallback.
;; The "zonk" equivalent: unsolved metas get default types.
(define (elab-cell-read-or enet cid default)
  (define v (elab-cell-read enet cid))
  (if (type-bot? v) default v))

;; All cell-ids in the network (from the cell-info registry).
(define (elab-all-cells enet)
  (champ-keys (elab-network-cell-info enet)))

;; All unsolved (bot) cells.
(define (elab-unsolved-cells enet)
  (filter (lambda (cid) (type-bot? (elab-cell-read enet cid)))
          (elab-all-cells enet)))

;; All contradicted cells. Currently at most one (the first contradiction
;; detected). Phase 5 will extend prop-network to collect all contradictions.
(define (elab-contradicted-cells enet)
  (define cid (prop-network-contradiction (elab-network-prop-net enet)))
  (if cid (list cid) '()))
