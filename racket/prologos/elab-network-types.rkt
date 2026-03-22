#lang racket/base

;;;
;;; elab-network-types.rkt — Elab-Network Struct Definitions
;;;
;;; Track 8 Phase B2: Extracted from elaborator-network.rkt to break the
;;; transitive dependency cycle:
;;;   cell-ops → elaborator-network → type-lattice → reduction → metavar-store → cell-ops
;;;
;;; This module provides ONLY struct definitions and basic field accessors.
;;; No dependencies on type-lattice, reduction, metavar-store, or any module
;;; that transitively depends on them.
;;;
;;; Both cell-ops.rkt and elaborator-network.rkt import this module.
;;; metavar-store.rkt imports cell-ops.rkt which imports this module.
;;; No cycle.
;;;

(require "propagator.rkt"
         "champ.rkt")

(provide
 ;; Elab-network struct + accessors
 (struct-out elab-network)
 (struct-out elab-cell-info)
 (struct-out contradiction-info)
 ;; Functional field updates
 elab-network-id-map-set
 elab-network-meta-info-set
 ;; Network construction (no type-lattice dependency)
 make-elaboration-network
 ;; Network reset for command lifecycle
 reset-elab-network-command-state
 ;; Track 8 B2c: Cell operations (no type-lattice dependency)
 elab-cell-read
 elab-cell-write
 elab-cell-replace
 elab-new-infra-cell
 elab-cell-info-ref)

;; ========================================
;; Struct Definitions
;; ========================================

;; Metadata about a propagator cell's role in type inference.
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
   next-meta-id  ;; Nat — deterministic counter
   id-map        ;; champ-root : meta-id (gensym) → cell-id
   meta-info)    ;; champ-root : meta-id (gensym) → meta-info
  #:transparent)

;; Contradiction details for error reporting.
(struct contradiction-info
  (cell-id       ;; cell-id that first contradicted
   cell-meta     ;; elab-cell-info or 'none
   value)        ;; the contradictory cell value (type-top)
  #:transparent)

;; ========================================
;; Functional Field Updates
;; ========================================

(define (elab-network-id-map-set enet new-id-map)
  (struct-copy elab-network enet [id-map new-id-map]))

(define (elab-network-meta-info-set enet new-meta-info)
  (struct-copy elab-network enet [meta-info new-meta-info]))

;; ========================================
;; Network Construction
;; ========================================

;; Create an empty elaboration network.
;; No dependency on type-lattice — just wraps a prop-network with empty CHAMPs.
(define (make-elaboration-network [fuel 1000000])
  (elab-network
   (make-prop-network fuel)
   champ-empty    ;; cell-info
   0              ;; next-meta-id
   champ-empty    ;; id-map
   champ-empty))  ;; meta-info

;; Reset command-scoped state while preserving persistent cells.
;; Clears propagators, worklist, fuel, contradiction, decomp registries.
;; Preserves: cells (persistent + fresh), cell-info, next-meta-id, id-map, meta-info.
(define (reset-elab-network-command-state enet [fuel 1000000])
  (define pnet (elab-network-prop-net enet))
  (define clean-pnet
    (struct-copy prop-network pnet
      [hot (prop-net-hot '() fuel)]
      [warm (struct-copy prop-net-warm (prop-network-warm pnet)
              [contradiction #f])]
      [cold (struct-copy prop-net-cold (prop-network-cold pnet)
              [propagators champ-empty]
              [next-prop-id 0]
              [cell-decomps champ-empty]
              [pair-decomps champ-empty])]))
  (elab-network clean-pnet
   (elab-network-cell-info enet)
   (elab-network-next-meta-id enet)
   (elab-network-id-map enet)
   (elab-network-meta-info enet)))

;; ========================================
;; Cell Operations (Track 8 B2c)
;; ========================================
;; These have NO type-lattice dependency — pure prop-network + struct operations.
;; Extracted from elaborator-network.rkt to break callback dependency.

;; Read a cell's current type value.
(define (elab-cell-read enet cid)
  (net-cell-read (elab-network-prop-net enet) cid))

;; Write a type value to a cell (lattice join via merge-fn).
;; Preserves eq? identity when the write produces no change.
(define (elab-cell-write enet cid val)
  (define pnet (elab-network-prop-net enet))
  (define pnet* (net-cell-write pnet cid val))
  (if (eq? pnet* pnet)
      enet
      (elab-network pnet*
       (elab-network-cell-info enet)
       (elab-network-next-meta-id enet)
       (elab-network-id-map enet)
       (elab-network-meta-info enet))))

;; Replace a cell's value directly, bypassing merge.
;; Used by S(-1) retraction.
(define (elab-cell-replace enet cid val)
  (define pnet (elab-network-prop-net enet))
  (define pnet* (net-cell-replace pnet cid val))
  (if (eq? pnet* pnet)
      enet
      (elab-network pnet*
       (elab-network-cell-info enet)
       (elab-network-next-meta-id enet)
       (elab-network-id-map enet)
       (elab-network-meta-info enet))))

;; Create an infrastructure cell (not a metavariable — no cell-info or meta counter).
(define (elab-new-infra-cell enet initial-value merge-fn)
  (define net (elab-network-prop-net enet))
  (define-values (net* cid) (net-new-cell net initial-value merge-fn))
  (values
   (elab-network net* (elab-network-cell-info enet) (elab-network-next-meta-id enet)
                 (elab-network-id-map enet) (elab-network-meta-info enet))
   cid))

;; Retrieve cell metadata, or 'none if unknown.
(define (elab-cell-info-ref enet cid)
  (champ-lookup (elab-network-cell-info enet) (cell-id-hash cid) cid))
