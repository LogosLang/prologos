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
         "mult-lattice.rkt"
         "prelude.rkt"       ;; P5c: mult-meta? for Pi mult extraction
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
 elab-contradicted-cells
 ;; P5b: Multiplicity cells
 elab-fresh-mult-cell
 elab-mult-cell-read
 elab-mult-cell-write
 ;; P5c: Cross-domain bridge (type ↔ multiplicity)
 elab-add-type-mult-bridge
 ;; Phase 4c: Structural decomposition support
 current-structural-meta-lookup)

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
;; Phase 7b: Fast path — if both cells already have concrete values,
;; eagerly merge and skip propagator creation entirely.
(define (elab-add-unify-constraint enet cell-a cell-b)
  (define va (elab-cell-read enet cell-a))
  (define vb (elab-cell-read enet cell-b))
  (cond
    ;; Fast path: both cells already ground — merge eagerly, skip propagator
    [(and (not (type-bot? va)) (not (type-bot? vb))
          (not (type-top? va)) (not (type-top? vb)))
     (define merged (type-lattice-merge va vb))
     (define enet* (elab-cell-write (elab-cell-write enet cell-a merged) cell-b merged))
     (values enet* #f)]
    ;; Standard path: create bidirectional propagator
    [else
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
      pid)]))

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

;; ========================================
;; Phase 4c: Structural Decomposition Support
;; ========================================
;;
;; Callback for identifying meta cells during structural decomposition.
;; When a compound type (e.g., Pi(Nat, ?M)) is decomposed, the sub-cell for
;; ?M should reuse the meta's existing propagator cell. This callback maps
;; (expr-meta id) → cell-id (or #f for non-metas / unmapped metas).
;; Set by driver.rkt to break circular dependency with metavar-store.rkt.
(define current-structural-meta-lookup (make-parameter #f))

;; ========================================
;; P5b: Multiplicity Cells
;; ========================================
;;
;; Multiplicity cells use the mult-lattice (mult-bot/m0/m1/mw/mult-top).
;; These are separate from type cells but live on the same prop-network.
;; Cross-domain propagators (P5c) will bridge type cells and mult cells.

;; Allocate a mult cell on the network. Returns (values elab-network* cell-id).
(define (elab-fresh-mult-cell enet source)
  (define net (elab-network-prop-net enet))
  (define-values (net* cid)
    (net-new-cell net mult-bot mult-lattice-merge mult-lattice-contradicts?))
  (define info (elab-cell-info '() #f source))
  (define h (cell-id-hash cid))
  (values
   (elab-network
    net*
    (champ-insert (elab-network-cell-info enet) h cid info)
    (+ 1 (elab-network-next-meta-id enet)))
   cid))

;; Read a mult cell's current value.
(define (elab-mult-cell-read enet cid)
  (net-cell-read (elab-network-prop-net enet) cid))

;; Write a multiplicity value to a cell (lattice join via mult-lattice-merge).
(define (elab-mult-cell-write enet cid val)
  (elab-network
   (net-cell-write (elab-network-prop-net enet) cid val)
   (elab-network-cell-info enet)
   (elab-network-next-meta-id enet)))

;; ========================================
;; P5c: Cross-Domain Bridge (Type ↔ Multiplicity)
;; ========================================
;;
;; Connects a type cell to a mult cell via a cross-domain propagator pair.
;; When the type cell receives a Pi type, the alpha propagator extracts the
;; binder multiplicity and writes it to the mult cell. The gamma direction
;; is a no-op (deferred — future work may embed mult info back into types).
;;
;; This enables information to flow from type inference into multiplicity
;; inference: if unification reveals a type is (Pi :m1 A B), the mult cell
;; immediately learns m1 without waiting for QTT checking.

;; Alpha: extract multiplicity from a type cell value.
;; - type-bot → mult-bot (no info yet)
;; - type-top → mult-top (contradiction propagates)
;; - (expr-Pi m _ _) where m ∈ {m0, m1, mw} → m
;; - (expr-Pi (mult-meta _) _ _) → mult-bot (unsolved)
;; - other type → mult-bot (not a Pi, no mult to extract)
(define (type->mult-alpha type-val)
  (cond
    [(type-bot? type-val) mult-bot]
    [(type-top? type-val) mult-top]
    [(expr-Pi? type-val)
     (define m (expr-Pi-mult type-val))
     (cond
       [(memq m '(m0 m1 mw)) m]
       [(mult-meta? m) mult-bot]
       [else mult-bot])]
    [else mult-bot]))

;; Gamma: no-op — returns the current type cell value unchanged.
;; Future work (P5c-gamma) may reconstruct Pi types with solved mults.
(define (mult->type-gamma _mult-val)
  ;; Identity on the type cell: gamma returns type-bot to avoid
  ;; writing to the type cell (bot ⊔ x = x, no change).
  type-bot)

;; Add a cross-domain propagator pair bridging a type cell and a mult cell.
;; Returns (values elab-network* pid-alpha pid-gamma).
(define (elab-add-type-mult-bridge enet type-cell-id mult-cell-id)
  (define net (elab-network-prop-net enet))
  (define-values (net* pid-alpha pid-gamma)
    (net-add-cross-domain-propagator net
      type-cell-id mult-cell-id
      type->mult-alpha
      mult->type-gamma))
  (values
   (elab-network
    net*
    (elab-network-cell-info enet)
    (elab-network-next-meta-id enet))
   pid-alpha
   pid-gamma))
