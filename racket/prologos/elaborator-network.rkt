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
(define (type-constructor-tag e)
  (cond
    [(type-bot? e) #f]
    [(type-top? e) #f]
    [(expr-Pi? e) 'Pi]
    [(expr-app? e) 'app]
    ;; Phase 4c-c will add: Sigma, Eq, Vec, PVec, Set, Map, pair, suc, lam
    [else #f]))

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
  ;; Register pair as decomposed
  (net-pair-decomp-insert net6 pair-key))

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

;; Dispatch to constructor-specific decomposer if unified value is compound.
;; Checks pair-decomps registry to avoid duplicate decomposition.
(define (maybe-decompose net cell-a cell-b va vb unified)
  (define tag (type-constructor-tag unified))
  (cond
    [(not tag) net]  ;; Not a compound type — nothing to decompose
    [else
     (define pair-key (decomp-key cell-a cell-b))
     (cond
       [(net-pair-decomp? net pair-key) net]  ;; Already decomposed for this pair
       [else
        (case tag
          [(Pi)  (decompose-pi  net cell-a cell-b va vb unified pair-key)]
          [(app) (decompose-app net cell-a cell-b va vb unified pair-key)]
          ;; Phase 4c-c: Sigma, Eq, Vec, PVec, Set, Map, pair, suc, lam
          [else net])])]))

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
