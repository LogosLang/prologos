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
         racket/set
         "propagator.rkt"
         "type-lattice.rkt"
         (only-in "sre-core.rkt" sre-equality make-sre-domain register-domain!)  ;; PAR Track 1: for request emission; Phase 1e-β-i: meta-solve domain
         (only-in "merge-fn-registry.rkt" register-merge-fn!/lattice)  ;; Phase 1e-β-i: Tier 2 linkage
         "mult-lattice.rkt"
         "prelude.rkt"       ;; P5c: mult-meta? for Pi mult extraction
         "champ.rkt"
         "syntax.rkt"
         "ctor-registry.rkt"        ;; PUnify Phase 1: descriptor-driven decomposition
         "elab-network-types.rkt")  ;; Track 8 B2: struct defs extracted to break cycle

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
 elab-cell-replace  ;; Track 7 post-fix: bypass merge for S(-1) retraction
 elab-cell-info-ref
 ;; Constraints
 elab-add-unify-constraint
 make-unify-propagator
 make-structural-unify-propagator  ;; Phase 4c-b
 ;; Phase 4c-b: Structural decomposition
 type-constructor-tag
 ;; Solving
 elab-solve
 extract-contradiction-info
 ;; Queries
 elab-cell-solved?
 elab-cell-read-or
 elab-all-cells
 elab-unsolved-cells
 elab-contradicted-cells
 ;; Phase 1a: Infrastructure cell creation (for propagator-first migration)
 elab-new-infra-cell
 ;; Track 6 Phase 1a: id-map update
 elab-network-id-map-set
 ;; Track 6 Phase 5a: meta-info update
 elab-network-meta-info-set
 ;; Track 6 Phase 6: Network reset for persistent cells
 reset-elab-network-command-state
 ;; P5b: Multiplicity cells
 elab-fresh-mult-cell
 ;; Track 8 A3d: Mult bridge callback + α/γ functions
 current-structural-mult-bridge
 type->mult-alpha
 mult->type-gamma
 elab-mult-cell-read
 elab-mult-cell-write
 ;; Track 4 Phase 3: Level and session cells
 elab-fresh-level-cell
 elab-fresh-sess-cell
 ;; P5c: Cross-domain bridge (type ↔ multiplicity)
 elab-add-type-mult-bridge
 ;; Phase 4c: Structural decomposition support
 current-structural-meta-lookup
 ;; PUnify Phase 3: sub-cell creation for Pi decomposition
 identify-sub-cell)

;; ========================================
;; Structs
;; ========================================

;; Track 8 Phase B2: Struct definitions (elab-cell-info, elab-network,
;; contradiction-info) and field updaters (elab-network-id-map-set,
;; elab-network-meta-info-set) extracted to elab-network-types.rkt.
;; Imported above and re-exported via (struct-out ...) in the provide block.

;; ========================================
;; Network Lifecycle
;; ========================================

;; Track 8 B2: make-elaboration-network and reset-elab-network-command-state
;; are now defined in elab-network-types.rkt and imported above.

;; ========================================
;; Cell Operations
;; ========================================

;; Allocate a meta as a cell on the network.
;; Track 4 Phase 2: Creates a TMS cell for assumption-tagged speculation.
;; At depth 0, TMS-transparent read/write in net-cell-read/write provides
;; identical behavior to the previous monotonic cell.
;; Returns (values elab-network* cell-id).
(define (elab-fresh-meta enet ctx type source)
  (define net (elab-network-prop-net enet))
  (define-values (net* cid)
    (net-new-tms-cell net type-bot type-lattice-merge type-lattice-contradicts?))
  (define info (elab-cell-info ctx type source))
  (define h (cell-id-hash cid))
  (values
   (elab-network
    net*
    (champ-insert (elab-network-cell-info enet) h cid info)
    (+ 1 (elab-network-next-meta-id enet))
    (elab-network-id-map enet)
    (elab-network-meta-info enet))
   cid))

;; Read a cell's current type value.
;; Track 8 B2c: elab-cell-read, elab-cell-write, elab-cell-replace,
;; elab-new-infra-cell, elab-cell-info-ref moved to elab-network-types.rkt.
;; Imported above and re-exported in the provide block.

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
;; Phase 7b: Fast path — if both cells are fully ground (no unsolved metas),
;; eagerly merge and skip propagator creation entirely.
;; Phase 4c-b: When either cell has unsolved metas, fall through to slow path
;; so structural decomposition can connect meta-cells to their positions.
(define (elab-add-unify-constraint enet cell-a cell-b)
  (define va (elab-cell-read enet cell-a))
  (define vb (elab-cell-read enet cell-b))
  (cond
    ;; Fast path: both cells ground AND no unsolved metas — merge eagerly
    [(and (not (type-bot? va)) (not (type-bot? vb))
          (not (type-top? va)) (not (type-top? vb))
          (not (has-unsolved-meta? va)) (not (has-unsolved-meta? vb)))
     (define merged (type-lattice-merge va vb))
     (define enet* (elab-cell-write (elab-cell-write enet cell-a merged) cell-b merged))
     (values enet* #f)]
    ;; Standard path: create structural bidirectional propagator
    [else
     (define-values (net* pid)
       (net-add-propagator
        (elab-network-prop-net enet)
        (list cell-a cell-b)    ;; inputs
        (list cell-a cell-b)    ;; outputs (bidirectional)
        (make-structural-unify-propagator cell-a cell-b)))
     (values
      (elab-network net*
                    (elab-network-cell-info enet)
                    (elab-network-next-meta-id enet)
                    (elab-network-id-map enet)
                    (elab-network-meta-info enet))
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
                  (elab-network-next-meta-id enet)
                  (elab-network-id-map enet)
                  (elab-network-meta-info enet)))
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

;; Track 8 Phase A3d: Callback for wiring mult bridges from decompose-pi.
;; (prop-network type-cell-id mult-val → prop-network)
;; Set by driver.rkt. When a Pi is decomposed and its multiplicity is a mult-meta,
;; this callback looks up the mult cell-id from the id-map and creates a
;; cross-domain bridge between the type cell and the mult cell.
(define current-structural-mult-bridge (make-parameter #f))

;; ========================================
;; Phase 4c-b: Structural Decomposition (Pi + app)
;; ========================================
;;
;; Radul/Sussman constructor/accessor pattern: compound partial information
;; decomposes into sub-cells. When a unify propagator detects both cells have
;; compound values with the same head constructor (e.g., Pi vs Pi), it lazily
;; creates sub-cells and sub-propagators for the components.
;;
;; Information flow:
;;   Downward: decompose compound cell → create/identify sub-cells
;;   Lateral: sub-cell ↔ sub-cell unify propagators transfer information
;;   Upward: reconstructor propagators rebuild compound type → write to parent
;;
;; Key mechanism: bare metas (expr-meta id) reuse the meta's existing
;; propagator cell, directly connecting the meta to its structural position.
;; This enables metas to be solved through sub-cell propagation.
;;
;; Monotonicity: sub-cells use type-lattice-merge (monotone join).
;; Termination: decomposition registries prevent duplicates; type depth bounded.
;; Speculation: registries are CHAMP fields in prop-network, captured by
;; save-meta-state → restore-meta-state! discards speculative sub-cells.

;; Classify expression by head constructor.
;; Returns a symbol tag for decomp-registry, or #f for atoms/non-compound.
;; PUnify Phase 1: driven by the constructor descriptor registry.
(define (type-constructor-tag e)
  (cond
    [(type-bot? e) #f]
    [(type-top? e) #f]
    [else
     (define desc (ctor-tag-for-value e))
     (and desc
          (eq? (ctor-desc-domain desc) 'type)
          (ctor-desc-tag desc))]))

;; Create or reuse a sub-cell for a decomposed component expression.
;; - Bare meta (expr-meta id): reuse the meta's existing propagator cell
;; - type-bot: fresh bot cell (no information yet)
;; - Ground/compound: fresh cell initialized to the expression value
;; Returns (values net* cell-id).
(define (identify-sub-cell net expr)
  (define meta-lookup (current-structural-meta-lookup))
  (cond
    ;; Bare meta → reuse existing propagator cell
    [(and meta-lookup (expr-meta? expr))
     (define cid (meta-lookup expr))
     (if cid
         (values net cid)
         ;; Meta not mapped (shouldn't happen in practice) → fresh bot cell
         (net-new-cell net type-bot type-lattice-merge type-lattice-contradicts?))]
    ;; type-bot → fresh bot cell
    [(type-bot? expr)
     (net-new-cell net type-bot type-lattice-merge type-lattice-contradicts?)]
    ;; Non-meta → fresh cell initialized to expression value
    [else
     (net-new-cell net expr type-lattice-merge type-lattice-contradicts?)]))

;; Get or create sub-cells for a cell's structural components.
;; Checks decomp registry first — if cell already decomposed, reuse sub-cells.
;; Otherwise, create sub-cells for each component and register.
;; Returns (values net* sub-cell-ids).
(define (get-or-create-sub-cells net cell-id tag components)
  (define existing (net-cell-decomp-lookup net cell-id))
  (cond
    [(not (eq? existing 'none))
     ;; Already decomposed — reuse existing sub-cells
     (values net (cdr existing))]
    [else
     ;; Create sub-cells for each component
     (define-values (net* sub-ids-rev)
       (for/fold ([n net] [ids '()])
                 ([comp (in-list components)])
         (define-values (n* cid) (identify-sub-cell n comp))
         (values n* (cons cid ids))))
     (define sub-ids (reverse sub-ids-rev))
     ;; Register in decomp registry
     (define net** (net-cell-decomp-insert net* cell-id tag sub-ids))
     (values net** sub-ids)]))

;; Pi reconstructor: reads domain and codomain sub-cells, rebuilds Pi.
;; If either sub-cell is bot, waits (no-op). If either is top, propagates
;; contradiction to parent. Otherwise, writes Pi(mult, dom, cod) to parent.
(define (make-pi-reconstructor parent-cell mult dom-cell cod-cell)
  (lambda (net)
    (define dom-val (net-cell-read net dom-cell))
    (define cod-val (net-cell-read net cod-cell))
    (cond
      ;; Either sub-cell unsolved → wait for more information
      [(or (type-bot? dom-val) (type-bot? cod-val)) net]
      ;; Either contradicted → propagate to parent
      [(or (type-top? dom-val) (type-top? cod-val))
       (net-cell-write net parent-cell type-top)]
      ;; Both solved → reconstruct and write to parent
      [else
       (net-cell-write net parent-cell (expr-Pi mult dom-val cod-val))])))

;; App reconstructor: reads func and arg sub-cells, rebuilds app.
(define (make-app-reconstructor parent-cell func-cell arg-cell)
  (lambda (net)
    (define func-val (net-cell-read net func-cell))
    (define arg-val (net-cell-read net arg-cell))
    (cond
      [(or (type-bot? func-val) (type-bot? arg-val)) net]
      [(or (type-top? func-val) (type-top? arg-val))
       (net-cell-write net parent-cell type-top)]
      [else
       (net-cell-write net parent-cell (expr-app func-val arg-val))])))

;; Decompose a Pi constraint: create sub-cells, sub-propagators, reconstructors.
;; va/vb are the original per-side values (for component extraction).
;; unified is the merged result (used as fallback for bot sides).
(define (decompose-pi net cell-a cell-b va vb unified pair-key)
  ;; Per-side Pi sources: use original value if Pi, else unified
  (define src-a (if (expr-Pi? va) va unified))
  (define src-b (if (expr-Pi? vb) vb unified))
  ;; Extract multiplicity for each side's reconstructor
  (define mult-a (expr-Pi-mult src-a))
  (define mult-b (expr-Pi-mult src-b))
  ;; Extract domain/codomain components
  (define dom-a-expr (expr-Pi-domain src-a))
  (define cod-a-expr (expr-Pi-codomain src-a))
  (define dom-b-expr (expr-Pi-domain src-b))
  (define cod-b-expr (expr-Pi-codomain src-b))
  ;; Get or create sub-cells for each side
  (define-values (net1 subs-a)
    (get-or-create-sub-cells net cell-a 'Pi (list dom-a-expr cod-a-expr)))
  (define dom-a (car subs-a))
  (define cod-a (cadr subs-a))
  (define-values (net2 subs-b)
    (get-or-create-sub-cells net1 cell-b 'Pi (list dom-b-expr cod-b-expr)))
  (define dom-b (car subs-b))
  (define cod-b (cadr subs-b))
  ;; Create sub-propagators (skip if same cell — e.g., both sides share meta)
  (define-values (net3 _pid1)
    (if (equal? dom-a dom-b)
        (values net2 #f)
        (net-add-propagator net2
          (list dom-a dom-b) (list dom-a dom-b)
          (make-structural-unify-propagator dom-a dom-b))))
  (define-values (net4 _pid2)
    (if (equal? cod-a cod-b)
        (values net3 #f)
        (net-add-propagator net3
          (list cod-a cod-b) (list cod-a cod-b)
          (make-structural-unify-propagator cod-a cod-b))))
  ;; Create reconstructors: sub-cells → parent cell
  (define-values (net5 _pid3)
    (net-add-propagator net4
      (list dom-a cod-a) (list cell-a)
      (make-pi-reconstructor cell-a mult-a dom-a cod-a)))
  (define-values (net6 _pid4)
    (net-add-propagator net5
      (list dom-b cod-b) (list cell-b)
      (make-pi-reconstructor cell-b mult-b dom-b cod-b)))
  ;; Track 8 Phase A3d: Wire cross-domain mult bridges.
  ;; If either Pi has a mult-meta, create an α/γ bridge between the parent
  ;; type cell and the corresponding mult cell. When the type cell's Pi is
  ;; solved with a concrete multiplicity, the bridge propagates it to the mult cell.
  ;; Note: this module does NOT import metavar-store.rkt (circular dep).
  ;; We use the current-mult-bridge-callback to wire bridges from the prop-net level.
  (define bridge-fn (current-structural-mult-bridge))
  (define net7
    (if (not bridge-fn)
        net6  ;; no bridge callback installed (test context) — skip
        (for/fold ([n net6])
                  ([type-cell (list cell-a cell-b)]
                   [mult-val (list mult-a mult-b)])
          (if (mult-meta? mult-val)
              (bridge-fn n type-cell mult-val)
              n))))  ;; concrete mult — no bridge needed
  ;; Register pair as decomposed
  (net-pair-decomp-insert net7 pair-key))

;; Decompose an app constraint: same pattern as Pi with func/arg components.
(define (decompose-app net cell-a cell-b va vb unified pair-key)
  (define src-a (if (expr-app? va) va unified))
  (define src-b (if (expr-app? vb) vb unified))
  (define func-a-expr (expr-app-func src-a))
  (define arg-a-expr (expr-app-arg src-a))
  (define func-b-expr (expr-app-func src-b))
  (define arg-b-expr (expr-app-arg src-b))
  (define-values (net1 subs-a)
    (get-or-create-sub-cells net cell-a 'app (list func-a-expr arg-a-expr)))
  (define func-a (car subs-a))
  (define arg-a (cadr subs-a))
  (define-values (net2 subs-b)
    (get-or-create-sub-cells net1 cell-b 'app (list func-b-expr arg-b-expr)))
  (define func-b (car subs-b))
  (define arg-b (cadr subs-b))
  (define-values (net3 _pid1)
    (if (equal? func-a func-b)
        (values net2 #f)
        (net-add-propagator net2
          (list func-a func-b) (list func-a func-b)
          (make-structural-unify-propagator func-a func-b))))
  (define-values (net4 _pid2)
    (if (equal? arg-a arg-b)
        (values net3 #f)
        (net-add-propagator net3
          (list arg-a arg-b) (list arg-a arg-b)
          (make-structural-unify-propagator arg-a arg-b))))
  (define-values (net5 _pid3)
    (net-add-propagator net4
      (list func-a arg-a) (list cell-a)
      (make-app-reconstructor cell-a func-a arg-a)))
  (define-values (net6 _pid4)
    (net-add-propagator net5
      (list func-b arg-b) (list cell-b)
      (make-app-reconstructor cell-b func-b arg-b)))
  (net-pair-decomp-insert net6 pair-key))

;; ========================================
;; Phase 4c-c: Extended Constructor Decomposers
;; ========================================
;;
;; Same pattern as Pi/app: extract components, create sub-cells,
;; wire sub-propagators and reconstructors, register pair.
;; Multiplicities for Pi and lam are handled by the imperative unify-mult
;; path (already works). Sub-cells for mult are deferred.

;; --- Sigma(fst-type, snd-type) — 2 sub-cells ---

(define (make-sigma-reconstructor parent-cell fst-cell snd-cell)
  (lambda (net)
    (define fst-val (net-cell-read net fst-cell))
    (define snd-val (net-cell-read net snd-cell))
    (cond
      [(or (type-bot? fst-val) (type-bot? snd-val)) net]
      [(or (type-top? fst-val) (type-top? snd-val))
       (net-cell-write net parent-cell type-top)]
      [else
       (net-cell-write net parent-cell (expr-Sigma fst-val snd-val))])))

(define (decompose-sigma net cell-a cell-b va vb unified pair-key)
  (define src-a (if (expr-Sigma? va) va unified))
  (define src-b (if (expr-Sigma? vb) vb unified))
  (define-values (net1 subs-a)
    (get-or-create-sub-cells net cell-a 'Sigma
      (list (expr-Sigma-fst-type src-a) (expr-Sigma-snd-type src-a))))
  (define-values (net2 subs-b)
    (get-or-create-sub-cells net1 cell-b 'Sigma
      (list (expr-Sigma-fst-type src-b) (expr-Sigma-snd-type src-b))))
  (define fst-a (car subs-a)) (define snd-a (cadr subs-a))
  (define fst-b (car subs-b)) (define snd-b (cadr subs-b))
  ;; Sub-propagators
  (define-values (net3 _p1)
    (if (equal? fst-a fst-b) (values net2 #f)
        (net-add-propagator net2 (list fst-a fst-b) (list fst-a fst-b)
          (make-structural-unify-propagator fst-a fst-b))))
  (define-values (net4 _p2)
    (if (equal? snd-a snd-b) (values net3 #f)
        (net-add-propagator net3 (list snd-a snd-b) (list snd-a snd-b)
          (make-structural-unify-propagator snd-a snd-b))))
  ;; Reconstructors
  (define-values (net5 _p3)
    (net-add-propagator net4 (list fst-a snd-a) (list cell-a)
      (make-sigma-reconstructor cell-a fst-a snd-a)))
  (define-values (net6 _p4)
    (net-add-propagator net5 (list fst-b snd-b) (list cell-b)
      (make-sigma-reconstructor cell-b fst-b snd-b)))
  (net-pair-decomp-insert net6 pair-key))

;; --- Eq(type, lhs, rhs) — 3 sub-cells ---

(define (make-eq-reconstructor parent-cell type-cell lhs-cell rhs-cell)
  (lambda (net)
    (define tv (net-cell-read net type-cell))
    (define lv (net-cell-read net lhs-cell))
    (define rv (net-cell-read net rhs-cell))
    (cond
      [(or (type-bot? tv) (type-bot? lv) (type-bot? rv)) net]
      [(or (type-top? tv) (type-top? lv) (type-top? rv))
       (net-cell-write net parent-cell type-top)]
      [else
       (net-cell-write net parent-cell (expr-Eq tv lv rv))])))

(define (decompose-eq net cell-a cell-b va vb unified pair-key)
  (define src-a (if (expr-Eq? va) va unified))
  (define src-b (if (expr-Eq? vb) vb unified))
  (define-values (net1 subs-a)
    (get-or-create-sub-cells net cell-a 'Eq
      (list (expr-Eq-type src-a) (expr-Eq-lhs src-a) (expr-Eq-rhs src-a))))
  (define-values (net2 subs-b)
    (get-or-create-sub-cells net1 cell-b 'Eq
      (list (expr-Eq-type src-b) (expr-Eq-lhs src-b) (expr-Eq-rhs src-b))))
  (define type-a (car subs-a)) (define lhs-a (cadr subs-a)) (define rhs-a (caddr subs-a))
  (define type-b (car subs-b)) (define lhs-b (cadr subs-b)) (define rhs-b (caddr subs-b))
  ;; 3 sub-propagators
  (define-values (net3 _p1)
    (if (equal? type-a type-b) (values net2 #f)
        (net-add-propagator net2 (list type-a type-b) (list type-a type-b)
          (make-structural-unify-propagator type-a type-b))))
  (define-values (net4 _p2)
    (if (equal? lhs-a lhs-b) (values net3 #f)
        (net-add-propagator net3 (list lhs-a lhs-b) (list lhs-a lhs-b)
          (make-structural-unify-propagator lhs-a lhs-b))))
  (define-values (net5 _p3)
    (if (equal? rhs-a rhs-b) (values net4 #f)
        (net-add-propagator net4 (list rhs-a rhs-b) (list rhs-a rhs-b)
          (make-structural-unify-propagator rhs-a rhs-b))))
  ;; Reconstructors
  (define-values (net6 _p4)
    (net-add-propagator net5 (list type-a lhs-a rhs-a) (list cell-a)
      (make-eq-reconstructor cell-a type-a lhs-a rhs-a)))
  (define-values (net7 _p5)
    (net-add-propagator net6 (list type-b lhs-b rhs-b) (list cell-b)
      (make-eq-reconstructor cell-b type-b lhs-b rhs-b)))
  (net-pair-decomp-insert net7 pair-key))

;; --- Vec(elem-type, length) — 2 sub-cells ---

(define (make-vec-reconstructor parent-cell elem-cell len-cell)
  (lambda (net)
    (define ev (net-cell-read net elem-cell))
    (define lv (net-cell-read net len-cell))
    (cond
      [(or (type-bot? ev) (type-bot? lv)) net]
      [(or (type-top? ev) (type-top? lv))
       (net-cell-write net parent-cell type-top)]
      [else
       (net-cell-write net parent-cell (expr-Vec ev lv))])))

(define (decompose-vec net cell-a cell-b va vb unified pair-key)
  (define src-a (if (expr-Vec? va) va unified))
  (define src-b (if (expr-Vec? vb) vb unified))
  (define-values (net1 subs-a)
    (get-or-create-sub-cells net cell-a 'Vec
      (list (expr-Vec-elem-type src-a) (expr-Vec-length src-a))))
  (define-values (net2 subs-b)
    (get-or-create-sub-cells net1 cell-b 'Vec
      (list (expr-Vec-elem-type src-b) (expr-Vec-length src-b))))
  (define elem-a (car subs-a)) (define len-a (cadr subs-a))
  (define elem-b (car subs-b)) (define len-b (cadr subs-b))
  (define-values (net3 _p1)
    (if (equal? elem-a elem-b) (values net2 #f)
        (net-add-propagator net2 (list elem-a elem-b) (list elem-a elem-b)
          (make-structural-unify-propagator elem-a elem-b))))
  (define-values (net4 _p2)
    (if (equal? len-a len-b) (values net3 #f)
        (net-add-propagator net3 (list len-a len-b) (list len-a len-b)
          (make-structural-unify-propagator len-a len-b))))
  (define-values (net5 _p3)
    (net-add-propagator net4 (list elem-a len-a) (list cell-a)
      (make-vec-reconstructor cell-a elem-a len-a)))
  (define-values (net6 _p4)
    (net-add-propagator net5 (list elem-b len-b) (list cell-b)
      (make-vec-reconstructor cell-b elem-b len-b)))
  (net-pair-decomp-insert net6 pair-key))

;; --- PVec(elem-type) — 1 sub-cell ---

(define (make-1-reconstructor parent-cell sub-cell ctor)
  (lambda (net)
    (define sv (net-cell-read net sub-cell))
    (cond
      [(type-bot? sv) net]
      [(type-top? sv) (net-cell-write net parent-cell type-top)]
      [else (net-cell-write net parent-cell (ctor sv))])))

(define (decompose-1 net cell-a cell-b va vb unified pair-key tag pred? accessor ctor)
  (define src-a (if (pred? va) va unified))
  (define src-b (if (pred? vb) vb unified))
  (define-values (net1 subs-a)
    (get-or-create-sub-cells net cell-a tag (list (accessor src-a))))
  (define-values (net2 subs-b)
    (get-or-create-sub-cells net1 cell-b tag (list (accessor src-b))))
  (define sub-a (car subs-a))
  (define sub-b (car subs-b))
  (define-values (net3 _p1)
    (if (equal? sub-a sub-b) (values net2 #f)
        (net-add-propagator net2 (list sub-a sub-b) (list sub-a sub-b)
          (make-structural-unify-propagator sub-a sub-b))))
  (define-values (net4 _p2)
    (net-add-propagator net3 (list sub-a) (list cell-a)
      (make-1-reconstructor cell-a sub-a ctor)))
  (define-values (net5 _p3)
    (net-add-propagator net4 (list sub-b) (list cell-b)
      (make-1-reconstructor cell-b sub-b ctor)))
  (net-pair-decomp-insert net5 pair-key))

;; --- Map(k-type, v-type) — 2 sub-cells ---

(define (make-map-reconstructor parent-cell k-cell v-cell)
  (lambda (net)
    (define kv (net-cell-read net k-cell))
    (define vv (net-cell-read net v-cell))
    (cond
      [(or (type-bot? kv) (type-bot? vv)) net]
      [(or (type-top? kv) (type-top? vv))
       (net-cell-write net parent-cell type-top)]
      [else
       (net-cell-write net parent-cell (expr-Map kv vv))])))

(define (decompose-map net cell-a cell-b va vb unified pair-key)
  (define src-a (if (expr-Map? va) va unified))
  (define src-b (if (expr-Map? vb) vb unified))
  (define-values (net1 subs-a)
    (get-or-create-sub-cells net cell-a 'Map
      (list (expr-Map-k-type src-a) (expr-Map-v-type src-a))))
  (define-values (net2 subs-b)
    (get-or-create-sub-cells net1 cell-b 'Map
      (list (expr-Map-k-type src-b) (expr-Map-v-type src-b))))
  (define k-a (car subs-a)) (define v-a (cadr subs-a))
  (define k-b (car subs-b)) (define v-b (cadr subs-b))
  (define-values (net3 _p1)
    (if (equal? k-a k-b) (values net2 #f)
        (net-add-propagator net2 (list k-a k-b) (list k-a k-b)
          (make-structural-unify-propagator k-a k-b))))
  (define-values (net4 _p2)
    (if (equal? v-a v-b) (values net3 #f)
        (net-add-propagator net3 (list v-a v-b) (list v-a v-b)
          (make-structural-unify-propagator v-a v-b))))
  (define-values (net5 _p3)
    (net-add-propagator net4 (list k-a v-a) (list cell-a)
      (make-map-reconstructor cell-a k-a v-a)))
  (define-values (net6 _p4)
    (net-add-propagator net5 (list k-b v-b) (list cell-b)
      (make-map-reconstructor cell-b k-b v-b)))
  (net-pair-decomp-insert net6 pair-key))

;; --- pair(fst, snd) — 2 sub-cells ---

(define (make-pair-reconstructor parent-cell fst-cell snd-cell)
  (lambda (net)
    (define fv (net-cell-read net fst-cell))
    (define sv (net-cell-read net snd-cell))
    (cond
      [(or (type-bot? fv) (type-bot? sv)) net]
      [(or (type-top? fv) (type-top? sv))
       (net-cell-write net parent-cell type-top)]
      [else
       (net-cell-write net parent-cell (expr-pair fv sv))])))

(define (decompose-pair net cell-a cell-b va vb unified pair-key)
  (define src-a (if (expr-pair? va) va unified))
  (define src-b (if (expr-pair? vb) vb unified))
  (define-values (net1 subs-a)
    (get-or-create-sub-cells net cell-a 'pair
      (list (expr-pair-fst src-a) (expr-pair-snd src-a))))
  (define-values (net2 subs-b)
    (get-or-create-sub-cells net1 cell-b 'pair
      (list (expr-pair-fst src-b) (expr-pair-snd src-b))))
  (define fst-a (car subs-a)) (define snd-a (cadr subs-a))
  (define fst-b (car subs-b)) (define snd-b (cadr subs-b))
  (define-values (net3 _p1)
    (if (equal? fst-a fst-b) (values net2 #f)
        (net-add-propagator net2 (list fst-a fst-b) (list fst-a fst-b)
          (make-structural-unify-propagator fst-a fst-b))))
  (define-values (net4 _p2)
    (if (equal? snd-a snd-b) (values net3 #f)
        (net-add-propagator net3 (list snd-a snd-b) (list snd-a snd-b)
          (make-structural-unify-propagator snd-a snd-b))))
  (define-values (net5 _p3)
    (net-add-propagator net4 (list fst-a snd-a) (list cell-a)
      (make-pair-reconstructor cell-a fst-a snd-a)))
  (define-values (net6 _p4)
    (net-add-propagator net5 (list fst-b snd-b) (list cell-b)
      (make-pair-reconstructor cell-b fst-b snd-b)))
  (net-pair-decomp-insert net6 pair-key))

;; --- lam(mult, type, body) — 2 sub-cells (type + body; mult via imperative path) ---

(define (make-lam-reconstructor parent-cell mult type-cell body-cell)
  (lambda (net)
    (define tv (net-cell-read net type-cell))
    (define bv (net-cell-read net body-cell))
    (cond
      [(or (type-bot? tv) (type-bot? bv)) net]
      [(or (type-top? tv) (type-top? bv))
       (net-cell-write net parent-cell type-top)]
      [else
       (net-cell-write net parent-cell (expr-lam mult tv bv))])))

(define (decompose-lam net cell-a cell-b va vb unified pair-key)
  (define src-a (if (expr-lam? va) va unified))
  (define src-b (if (expr-lam? vb) vb unified))
  (define mult-a (expr-lam-mult src-a))
  (define mult-b (expr-lam-mult src-b))
  (define-values (net1 subs-a)
    (get-or-create-sub-cells net cell-a 'lam
      (list (expr-lam-type src-a) (expr-lam-body src-a))))
  (define-values (net2 subs-b)
    (get-or-create-sub-cells net1 cell-b 'lam
      (list (expr-lam-type src-b) (expr-lam-body src-b))))
  (define type-a (car subs-a)) (define body-a (cadr subs-a))
  (define type-b (car subs-b)) (define body-b (cadr subs-b))
  (define-values (net3 _p1)
    (if (equal? type-a type-b) (values net2 #f)
        (net-add-propagator net2 (list type-a type-b) (list type-a type-b)
          (make-structural-unify-propagator type-a type-b))))
  (define-values (net4 _p2)
    (if (equal? body-a body-b) (values net3 #f)
        (net-add-propagator net3 (list body-a body-b) (list body-a body-b)
          (make-structural-unify-propagator body-a body-b))))
  (define-values (net5 _p3)
    (net-add-propagator net4 (list type-a body-a) (list cell-a)
      (make-lam-reconstructor cell-a mult-a type-a body-a)))
  (define-values (net6 _p4)
    (net-add-propagator net5 (list type-b body-b) (list cell-b)
      (make-lam-reconstructor cell-b mult-b type-b body-b)))
  (net-pair-decomp-insert net6 pair-key))

;; ========================================
;; PUnify Phase 1: Generic descriptor-driven decomposition
;; ========================================

;; Generic reconstructor: reads all sub-cells and rebuilds via descriptor.
;; Works for any registered type constructor with binder-depth 0.
;; Termination: Level 1 (Tarski). Fires when sub-cells change; reconstructed
;; value = desc.reconstruct-fn(sub-values). If all sub-values unchanged,
;; net-cell-write is a no-op. Finite cells = finite firings.
(define (make-generic-reconstructor parent-cell sub-cells desc)
  (lambda (net)
    (define vals (map (λ (sc) (net-cell-read net sc)) sub-cells))
    (cond
      [(ormap type-bot? vals) net]  ;; wait for more info
      [(ormap type-top? vals)
       (net-cell-write net parent-cell type-top)]
      [else
       (net-cell-write net parent-cell
                       ((ctor-desc-reconstruct-fn desc) vals))])))

;; Generic decompose for registered type constructors with binder-depth 0.
;; Replaces per-tag decompose-app, decompose-eq, decompose-vec, decompose-map,
;; decompose-pair, decompose-1 (for PVec/Set/suc) with a single descriptor-driven
;; implementation. Pi/Sigma/lam keep their existing decomposers (binder + mult handling).
(define (decompose-generic net cell-a cell-b va vb unified pair-key desc)
  (define tag (ctor-desc-tag desc))
  (define recog (ctor-desc-recognizer-fn desc))
  (define extract (ctor-desc-extract-fn desc))
  ;; Per-side sources: use original value if it matches, else unified
  (define src-a (if (recog va) va unified))
  (define src-b (if (recog vb) vb unified))
  ;; Extract components
  (define comps-a (extract src-a))
  (define comps-b (extract src-b))
  ;; Get or create sub-cells for each side
  (define-values (net1 subs-a) (get-or-create-sub-cells net cell-a tag comps-a))
  (define-values (net2 subs-b) (get-or-create-sub-cells net1 cell-b tag comps-b))
  ;; Add structural-unify propagators for each component pair
  (define net3
    (for/fold ([n net2])
              ([sa (in-list subs-a)]
               [sb (in-list subs-b)])
      (if (equal? sa sb)
          n
          (let-values ([(n* _pid) (net-add-propagator n
                                    (list sa sb) (list sa sb)
                                    (make-structural-unify-propagator sa sb))])
            n*))))
  ;; Add generic reconstructors for each side
  (define-values (net4 _p1)
    (net-add-propagator net3 subs-a (list cell-a)
      (make-generic-reconstructor cell-a subs-a desc)))
  (define-values (net5 _p2)
    (net-add-propagator net4 subs-b (list cell-b)
      (make-generic-reconstructor cell-b subs-b desc)))
  ;; Register pair as decomposed
  (net-pair-decomp-insert net5 pair-key))

;; Dispatch to constructor-specific decomposer if unified value is compound.
;; Checks pair-decomps registry to avoid duplicate decomposition.
;; PUnify Phase 1: simple no-binder types (app, Eq, Vec, Fin, pair, PVec, Set,
;; Map, suc) use generic descriptor-driven decompose. Pi/Sigma/lam retain
;; their existing decomposers for binder + mult handling.
(define (maybe-decompose net cell-a cell-b va vb unified)
  (define tag (type-constructor-tag unified))
  (cond
    [(not tag) net]  ;; Not a compound type — nothing to decompose
    [else
     (define pair-key (decomp-key cell-a cell-b))
     ;; PAR Track 1 D.4: dual-path BSP/DFS
     (if (current-bsp-fire-round?)
         ;; BSP: emit decomposition request to elaborator topology cell
         ;; (A1: per-subsystem cell, was shared decomp-request-cell-id)
         (net-cell-write net elaborator-topology-cell-id
                         (set (sre-decomp-request pair-key
                                                  #f  ;; no SRE domain — elaborator path
                                                  cell-a cell-b
                                                  sre-equality  ;; equality relation
                                                  '())))
         ;; DFS: decompose inline (unchanged)
         (cond
           [(net-pair-decomp? net pair-key) net]
           [else
            (case tag
              [(Pi)    (decompose-pi    net cell-a cell-b va vb unified pair-key)]
              [(Sigma) (decompose-sigma net cell-a cell-b va vb unified pair-key)]
              [(lam)   (decompose-lam   net cell-a cell-b va vb unified pair-key)]
              [else
               (define desc (lookup-ctor-desc tag #:domain 'type))
               (if (and desc (= (ctor-desc-binder-depth desc) 0))
                   (decompose-generic net cell-a cell-b va vb unified pair-key desc)
                   net)])]))]))

;; Structural unify propagator: replacement for make-unify-propagator.
;; Same merge logic, but after writing unified values, triggers structural
;; decomposition for compound types. Sub-propagators are also structural
;; (recursive), enabling decomposition at any nesting depth.
;;
;; Termination: decomp registries prevent duplicate work; type-lattice-merge
;; monotonicity + net-cell-write no-change guard prevent infinite loops;
;; reconstructor writes same compound as parent → no change → terminate.
(define (make-structural-unify-propagator cell-a cell-b)
  (lambda (net)
    (define va (net-cell-read net cell-a))
    (define vb (net-cell-read net cell-b))
    (cond
      ;; Both bot: nothing to propagate
      [(and (type-bot? va) (type-bot? vb)) net]
      ;; One bot: propagate the known value, then try decomposition
      [(type-bot? va)
       (let ([net* (net-cell-write net cell-a vb)])
         (maybe-decompose net* cell-a cell-b va vb vb))]
      [(type-bot? vb)
       (let ([net* (net-cell-write net cell-b va)])
         (maybe-decompose net* cell-a cell-b va vb va))]
      ;; Both have values: compute lattice join
      [else
       (define unified (type-lattice-merge va vb))
       (if (type-top? unified)
           ;; Contradiction: signal via type-top write
           (net-cell-write net cell-a type-top)
           ;; Compatible: write unified to both, then decompose
           (let* ([net* (net-cell-write net cell-a unified)]
                  [net** (net-cell-write net* cell-b unified)])
             (maybe-decompose net** cell-a cell-b va vb unified)))])))

;; ========================================
;; P5b: Multiplicity Cells
;; ========================================
;;
;; Multiplicity cells use the mult-lattice (mult-bot/m0/m1/mw/mult-top).
;; These are separate from type cells but live on the same prop-network.
;; Cross-domain propagators (P5c) will bridge type cells and mult cells.

;; Allocate a mult cell on the network. Returns (values elab-network* cell-id).
;; Track 4 Phase 3: Now creates a TMS cell (paralleling type metas).
(define (elab-fresh-mult-cell enet source)
  (define net (elab-network-prop-net enet))
  (define-values (net* cid)
    (net-new-tms-cell net mult-bot mult-lattice-merge mult-lattice-contradicts?))
  (define info (elab-cell-info '() #f source))
  (define h (cell-id-hash cid))
  (values
   (elab-network
    net*
    (champ-insert (elab-network-cell-info enet) h cid info)
    (+ 1 (elab-network-next-meta-id enet))
    (elab-network-id-map enet)
    (elab-network-meta-info enet))
   cid))

;; Read a mult cell's current value.
(define (elab-mult-cell-read enet cid)
  (net-cell-read (elab-network-prop-net enet) cid))

;; Write a multiplicity value to a cell (lattice join via mult-lattice-merge).
(define (elab-mult-cell-write enet cid val)
  (elab-network
   (net-cell-write (elab-network-prop-net enet) cid val)
   (elab-network-cell-info enet)
   (elab-network-next-meta-id enet)
   (elab-network-id-map enet)
   (elab-network-meta-info enet)))

;; ========================================
;; Track 4 Phase 3: Level and Session Cells
;; ========================================
;;
;; Per-meta TMS cells for level and session metavariables, paralleling
;; type metas (Phase 2) and mult metas (P5b, now TMS).
;; PPN 4C Phase 1e-β-i (2026-04-20): identity-or-error semantics.
;; Once a meta is solved, a subsequent solve to a DIFFERENT value is a
;; double-solve-with-inconsistency BUG — not legitimate replace. Former
;; local merge-last-write-wins silently absorbed such bugs; replaced
;; with merge-meta-solve-identity which returns a contradiction sentinel
;; recognized by the 'meta-solve SRE domain's #:contradicts? predicate.
;; Initial value is 'unsolved (bot); 'meta-solve-contradiction is top.

;; Identity-or-error merge for level/session/mult metas.
;;   'unsolved (bot) ⊔ value = value (monotone solve)
;;   value ⊔ value (equal?) = value (identity)
;;   value1 ⊔ value2 (not equal?) = 'meta-solve-contradiction (top)
(define (merge-meta-solve-identity old new)
  (cond
    [(eq? old 'unsolved) new]
    [(eq? new 'unsolved) old]
    [(eq? old 'meta-solve-contradiction) old]  ;; top absorbs
    [(eq? new 'meta-solve-contradiction) new]
    [(equal? old new) old]  ;; same-value: identity
    [else 'meta-solve-contradiction]))

(define (meta-solve-contradiction? v)
  (eq? v 'meta-solve-contradiction))

;; Register as SRE 'meta-solve domain (Tier 1 + Tier 2).
(define meta-solve-sre-domain
  (make-sre-domain
   #:name 'meta-solve
   #:merge-registry (lambda (r)
                      (case r
                        [(equality) merge-meta-solve-identity]
                        [else (error 'meta-solve-merge "no merge: ~a" r)]))
   #:contradicts? meta-solve-contradiction?
   #:bot? (lambda (v) (eq? v 'unsolved))
   #:bot-value 'unsolved))
(register-domain! meta-solve-sre-domain)
(register-merge-fn!/lattice merge-meta-solve-identity #:for-domain 'meta-solve)

;; Allocate a level cell on the network. Returns (values elab-network* cell-id).
(define (elab-fresh-level-cell enet source)
  (define net (elab-network-prop-net enet))
  (define-values (net* cid)
    (net-new-tms-cell net 'unsolved merge-meta-solve-identity))
  (define info (elab-cell-info '() #f source))
  (define h (cell-id-hash cid))
  (values
   (elab-network
    net*
    (champ-insert (elab-network-cell-info enet) h cid info)
    (+ 1 (elab-network-next-meta-id enet))
    (elab-network-id-map enet)
    (elab-network-meta-info enet))
   cid))

;; Allocate a session cell on the network. Returns (values elab-network* cell-id).
(define (elab-fresh-sess-cell enet source)
  (define net (elab-network-prop-net enet))
  (define-values (net* cid)
    (net-new-tms-cell net 'unsolved merge-meta-solve-identity))
  (define info (elab-cell-info '() #f source))
  (define h (cell-id-hash cid))
  (values
   (elab-network
    net*
    (champ-insert (elab-network-cell-info enet) h cid info)
    (+ 1 (elab-network-next-meta-id enet))
    (elab-network-id-map enet)
    (elab-network-meta-info enet))
   cid))

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
    (elab-network-next-meta-id enet)
    (elab-network-id-map enet)
    (elab-network-meta-info enet))
   pid-alpha
   pid-gamma))

;; ========================================================================
;; PAR Track 1: Elaborator-network topology handler (self-registering)
;; ========================================================================
;; Handles sre-decomp-request with domain=#f (elaborator path, not SRE).
;; Calls the same decomposition functions as the DFS maybe-decompose path.
;; A1 (BSP-LE 2B addendum, 2026-04-16): migrated to per-subsystem stratum
;; handler on elaborator-topology-cell-id (was shared decomp-request-cell).
(register-stratum-handler!
 elaborator-topology-cell-id
 (lambda (net req-set)
   (for/fold ([n net]) ([req (in-set req-set)])
     (cond
       [(net-pair-decomp? n (sre-decomp-request-pair-key req)) n]
       [else
        (define pair-key (sre-decomp-request-pair-key req))
        (define cell-a (sre-decomp-request-cell-a req))
        (define cell-b (sre-decomp-request-cell-b req))
        (define va (net-cell-read n cell-a))
        (define vb (net-cell-read n cell-b))
        (define unified (type-lattice-merge va vb))
        (cond
          [(type-top? unified) (net-cell-write n cell-a type-top)]
          [else
           (define tag (type-constructor-tag unified))
           (cond
             [(not tag) n]
             [else
              (case tag
                [(Pi)    (decompose-pi    n cell-a cell-b va vb unified pair-key)]
                [(Sigma) (decompose-sigma n cell-a cell-b va vb unified pair-key)]
                [(lam)   (decompose-lam   n cell-a cell-b va vb unified pair-key)]
                [else
                 (define desc (lookup-ctor-desc tag #:domain 'type))
                 (if (and desc (= (ctor-desc-binder-depth desc) 0))
                     (decompose-generic n cell-a cell-b va vb unified pair-key desc)
                     n)])])])])))
 #:tier 'topology
 #:reset-value (set))
